package NS::Hermes::DBI::Cache;

=head1 NAME

NS::Hermes::DBI::Cache - DB interface to NS::Hermes cache data

=head1 SYNOPSIS

 use NS::Hermes::DBI::Cache;

 my $db = NS::Hermes::DBI::Cache->new( '/database/file' );

 $db->select( 'node', name => [ 1, 'foo' ] );

=cut
use strict;
use warnings;

=head1 METHODS

See NS::Util::SQLiteDB.

=cut
use base qw( NS::Util::SQLiteDB );

=head1 DATABASE

A SQLITE db has a I<hermes> table of I<four> columns:

 name : cluster name
 attr : table name
 node : node name
 info : info associated with node

=cut
our $TABLE  = 'hermes';

sub define
{
    name => 'TEXT NOT NULL',
    attr => 'TEXT NOT NULL',
    node => 'TEXT NOT NULL',
    info => 'BLOB',
};


=head3 insert( @record ) 

Insert @record into $table.

=cut
sub insert
{
    my $self = shift;
    $self->SUPER::insert( $TABLE, @_ );
}

=head3 select( $column, %query ) 

Select $column from $table.

=cut
sub select
{
    my $self = shift;
    $self->SUPER::select( $TABLE, @_ );
}

=head3 delete( %query ) 

Delete records from $table.

=cut
sub delete
{
    my $self = shift;
    $self->SUPER::delete( $TABLE, @_ );
}

1;
