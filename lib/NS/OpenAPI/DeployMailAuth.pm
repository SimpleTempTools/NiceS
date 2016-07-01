package NS::OpenAPI::DeployMailAuth;
use strict;
use warnings;
use Carp;

use JSON;
use Sys::Hostname;

use base qw( NS::OpenAPI );

our $URI = '/openapi/deploymailauth';

sub i
{
    my $self = shift;
    $self->get( sprintf "$URI/i?data=%s", join ',', @_ );
}

sub o
{
    my $self = shift;
    $self->get( sprintf "$URI/o?data=%s", join ',', @_ );
}


1;
