use Mojolicious::Lite; # strict and warnings
use Test::More 0.98;
BEGIN {
  plan skip_all => 'TEST_REDIS=redis://localhost' unless $ENV{TEST_REDIS};
  $ENV{MOJO_MODE}    = 'testing';
  $ENV{MOJO_REACTOR} = 'Mojo::Reactor::Poll';
}
use Test::Mojo;
use Mojo::Redis;
use GraphQL::Type::Scalar qw($String);
use JSON::MaybeXS ();

my $redis = Mojo::Redis->new($ENV{TEST_REDIS});
plugin GraphQL => {
  convert => [
    'MojoPubSub',
    {
      username => $String->non_null,
      message => $String->non_null,
    },
    $redis->pubsub,
  ],
};
my $t = Test::Mojo->new;

my $true = JSON::MaybeXS::true;
subtest 'status' => sub {
  $t->post_ok('/graphql', json => {
    query => '{ status }',
  })->json_is({ data => { status => $true } })
    ->or(sub { diag explain $t->tx->res->body })
    ;
};

my @messages = (
  { channel => "testing", message => "yo", username => "bob" },
  { channel => "other", message => "hi", username => "bill" },
);
subtest 'publish' => sub {
  $t->post_ok('/graphql', json => {
    query => <<'EOF',
mutation m($messages: [PubSubMessageInput!]!) {
  publish(input: $messages)
}
EOF
    variables => { messages => \@messages },
  })->json_like('/data/publish' => qr/\d/)
    ->or(sub { diag explain $t->tx->res->body })
    ;
};

done_testing;
