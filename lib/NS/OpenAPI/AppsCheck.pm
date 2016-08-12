package NS::OpenAPI::AppsCheck;
use strict;
use warnings;
use Carp;

use JSON;
use LWP::UserAgent;

use base qw( NS::OpenAPI );

our $URI = "/openapi/appscheck";


sub dump
{
    my ( $self, $node ) = @_;
    $self->get( "$URI/$node" );
}

1;
