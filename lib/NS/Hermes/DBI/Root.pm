package NS::Hermes::DBI::Root;

=head1 NAME

NS::Hermes::DBI::Root - DB interface to NS::Hermes root data

=head1 SYNOPSIS

 use NS::Hermes::DBI::Root;

 my $db = NS::Hermes::DBI::Root->new( '/database/file' );

=cut
use strict;
use warnings;

=head1 METHODS

See NS::Util::SQLiteDB.

=cut
use base qw( NS::Util::SQLiteDB );

=head1 DATABASE

A SQLITE db has tables of I<two> columns:

 key : node name
 value : info associated with node

=cut
sub define
{
    key => 'TEXT NOT NULL PRIMARY KEY',
    value => 'BLOB',
};

1;
