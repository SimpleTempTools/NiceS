package NS::OpenAPI::Apps;
use strict;
use warnings;
use Carp;

use JSON;
use LWP::UserAgent;

use base qw( NS::OpenAPI );

our $URI = "/openapi/apps";


sub dump
{
    my ( $self, $node ) = @_;
    $self->get( "$URI/$node" );
}

1;
