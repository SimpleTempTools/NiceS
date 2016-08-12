package NS::OpenAPI::AppsDeploy;
use strict;
use warnings;
use Carp;

use JSON;
use LWP::UserAgent;

use base qw( NS::OpenAPI );

our $URI = "/openapi/appsdeploy";

sub list
{
    shift->get( "$URI/list/" );
}

sub dump
{
    my ( $self, $node ) = @_;
    $self->get( "$URI/$node" );
}

1;
