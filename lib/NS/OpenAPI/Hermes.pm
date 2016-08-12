package NS::OpenAPI::Hermes;
use strict;
use warnings;
use Carp;

use JSON;
use LWP::UserAgent;

use base qw( NS::OpenAPI );

our $URI = "/openapi/hermes";

sub md5
{
    my $self = shift;
    $self->get( "$URI/cache/data_md5" );
}

sub wget
{
    my ( $self, $file  )= @_;
    system sprintf "wget '$self->{addr}/$URI/cache/data' %s", $file ? "-O $file" : '';
}

1;
