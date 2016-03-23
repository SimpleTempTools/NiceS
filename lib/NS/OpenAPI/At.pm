package NS::OpenAPI::At;
use strict;
use warnings;
use Carp;

use JSON;
use Sys::Hostname;

use base qw( NS::OpenAPI );

our $URI = '/openapi/at';

sub done
{
    my $self = shift;
    my $data = $self->_get( sprintf "$URI/done?id=$self->{id}&how=%s", shift );
    return $data->{stat};
}

1;
