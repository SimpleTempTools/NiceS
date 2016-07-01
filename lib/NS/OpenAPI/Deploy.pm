package NS::OpenAPI::Deploy;
use strict;
use warnings;
use Carp;

use JSON;
use LWP::UserAgent;

use base qw( NS::OpenAPI );

our $URI = "/openapi/deploy";

sub list
{
    my $self = shift;
    $self->get( "$URI/list" );
}

sub create
{
    my ( $self, $name ) = @_;
    $self->get( sprintf "$URI/create?name=%s", $name || $self->{name} );
}

sub mark { shift->_api( 'mark', @_); }
sub info { shift->_api( 'info', @_); }

sub main_list { shift->_api( 'main/', @_); }
sub conf_list { shift->_api( 'conf/', @_); }
sub logs_list { shift->_api( 'logs/', @_); }

sub main
{
    my ( $self, $type ) = splice @_, 0, 2;
    $self->_api( "main/$type", @_);
}

sub conf
{
    my ( $self, $type ) = splice @_, 0, 2;
    $self->_api( "conf/$type", @_);
}

sub logs
{
    my ( $self, $type ) = splice @_, 0, 2;
    $self->_api( "logs/$type", @_ );
}

sub cache
{
    my ( $self, $mark, $type ) = splice @_, 0, 3;
    $self->_api( "snap/$mark/$type", @_ );
}

sub sc
{
    my ( $self, $sc ) = splice @_, 0, 2;
    $self->_api( "sc/$sc", @_ );
}

sub myid
{
    my ( $self, $myid ) = splice @_, 0, 2;
    $self->_api( "myid/$myid", @_ );
}

sub _api
{
    my ( $self, $type, $data ) = @_;
    $self->post( sprintf( "$URI/%s/$type", $self->{name}), $data ? ( data => $data ) :() );
}

1;
