package NS::OpenAPI::At;
use strict;
use warnings;
use Carp;

use JSON;
use Sys::Hostname;

use base qw( NS::OpenAPI );

our $URI = '/openapi/at';

sub code
{
    my $self = shift;
    my $data = $self->_get( sprintf "$URI/code?id=$self->{id}&code=%s", shift );
    return $data->{stat};
}

sub use
{
    my $self = shift;
    my $data = $self->_get( sprintf "$URI/use?id=$self->{id}&use=%s", shift );
    return $data->{stat};
}

sub stat
{
    my $self = shift;
    my $data = $self->_get( sprintf "$URI/stat?id=$self->{id}&stat=%s", shift );
    return $data->{stat};
}

sub cbstat
{
    my $self = shift;
    my $data = $self->_get( sprintf "$URI/cbstat?id=$self->{id}&cbstat=%s", shift );
    return $data->{stat};
}


1;
