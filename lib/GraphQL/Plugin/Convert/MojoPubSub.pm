package GraphQL::Plugin::Convert::MojoPubSub;
use strict;
use warnings;
use GraphQL::Schema;
use GraphQL::Debug qw(_debug);
use DateTime;
use GraphQL::Type::Scalar qw($Boolean $String);
use GraphQL::Type::Object;
use GraphQL::Type::InputObject;

our $VERSION = "0.01";
use constant DEBUG => $ENV{GRAPHQL_DEBUG};

my ($DateTime) = grep $_->name eq 'DateTime', GraphQL::Plugin::Type->registered;

sub to_graphql {
  my ($class, $fieldspec, $pubsub) = @_;
  $fieldspec = { map +($_ => { type => $fieldspec->{$_} }), keys %$fieldspec };
  my $input_fields = {
    channel => { type => $String->non_null },
    %$fieldspec,
  };
  DEBUG and _debug('MojoPubSub.input', $input_fields);
  my $output_fields = {
    channel => { type => $String->non_null },
    dateTime => { type => $DateTime->non_null },
    %$fieldspec,
  };
  DEBUG and _debug('MojoPubSub.output', $output_fields);
  my $schema = GraphQL::Schema->new(
    query => GraphQL::Type::Object->new(
      name => 'Query',
      fields => { status => { type => $Boolean->non_null } },
    ),
    mutation => GraphQL::Type::Object->new(
      name => 'Mutation',
      fields => { publish => {
        type => $DateTime->non_null,
        args => { input => { type => GraphQL::Type::InputObject->new(
          name => 'PubSubMessageInput',
          fields => $input_fields,
        )->non_null->list->non_null } },
      } },
    ),
    subscription => GraphQL::Type::Object->new(
      name => 'Subscription',
      fields => { subscribe => {
        type => GraphQL::Type::Object->new(
          name => 'PubSubMessage',
          fields => $output_fields,
        )->non_null,
        args => { channels => { type => $String->non_null->list } },
      } },
    ),
  );
  +{
    schema => $schema,
    root_value => $pubsub,
  };
}

=encoding utf-8

=head1 NAME

GraphQL::Plugin::Convert::MojoPubSub - convert a Mojo PubSub server to GraphQL schema

=begin markdown

# PROJECT STATUS

| OS      |  Build status |
|:-------:|--------------:|
| Linux   | [![Build Status](https://travis-ci.org/graphql-perl/GraphQL-Plugin-Convert-MojoPubSub.svg?branch=master)](https://travis-ci.org/graphql-perl/GraphQL-Plugin-Convert-MojoPubSub) |

[![CPAN version](https://badge.fury.io/pl/GraphQL-Plugin-Convert-MojoPubSub.svg)](https://metacpan.org/pod/GraphQL::Plugin::Convert::MojoPubSub) [![Coverage Status](https://coveralls.io/repos/github/graphql-perl/GraphQL-Plugin-Convert-MojoPubSub/badge.svg?branch=master)](https://coveralls.io/github/graphql-perl/GraphQL-Plugin-Convert-MojoPubSub?branch=master)

=end markdown

=head1 SYNOPSIS

  use GraphQL::Plugin::Convert::MojoPubSub;
  use GraphQL::Type::Scalar qw($String);
  my $pg = Mojo::Pg->new('postgresql://postgres@/test');
  my $converted = GraphQL::Plugin::Convert::MojoPubSub->to_graphql(
    {
      username => $String->non_null,
      message => $String->non_null,
    },
    $pg->pubsub,
  );
  print $converted->{schema}->to_doc;

=head1 DESCRIPTION

This module implements the L<GraphQL::Plugin::Convert> API to convert
a Mojo pub-sub server (currently either L<Mojo::Pg::PubSub> or
L<Mojo::Redis::PubSub>) to L<GraphQL::Schema> with publish/subscribe
functionality.

=head1 ARGUMENTS

To the C<to_graphql> method:

=over

=item *

a hash-ref of field-names to L<GraphQL::Type> objects. These must be
both input and output types, so only scalars or enums. This allows you
to pass in programmatically-created scalars or enums.

This will be used to construct the C<fields> arguments for the
L<GraphQL::Type::InputObject> and L<GraphQL::Type::Object> which are
the input and output of the mutation and subscription respectively.

=item *

an object compatible with L<Mojo::Redis::PubSub>.

=back

Note the output type will have a C<dateTime> field added to it with type
non-null C<DateTime>. Both input and output types will have a non-null
C<channel> C<String> added.

E.g. for this input (implementing a trivial chat system):

  {
    username => $String->non_null,
    message => $String->non_null,
  }

The schema will look like:

  scalar DateTime

  input PubSubMessageInput {
    channel: String!
    username: String!
    message: String!
  }

  type PubSubMessage {
    channel: String!
    username: String!
    message: String!
    dateTime: DateTime!
  }

  type Query {
    status: Boolean!
  }

  type Mutation {
    publish(input: [PubSubMessageInput!]!): DateTime!
  }

  type Subscription {
    subscribe(channels: [String!]): PubSubMessage!
  }

The C<subscribe> field takes a list of channels to subscribe to. If the
list is null, all channels will be subscribed to - a "firehose".

=head1 DEBUGGING

To debug, set environment variable C<GRAPHQL_DEBUG> to a true value.

=head1 AUTHOR

Ed J, C<< <etj at cpan.org> >>

=head1 LICENSE

Copyright (C) Ed J

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
