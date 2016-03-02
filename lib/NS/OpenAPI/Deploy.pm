package NS::OpenAPI::Deploy;
use strict;
use warnings;
use Carp;

use JSON;
use LWP::UserAgent;

use base qw( NS::OpenAPI );

our %URI =
(
    list => '/openapi/deploy/list',
    conf => '/openapi/deploy/conf',
);

sub list
{
    my $self = shift;
    $self->get( $URI{list} );
}

sub get_conf
{
    my ( $self, $name ) = @_;
    $self->get( "$URI{conf}/get/$name" );
}

1;
