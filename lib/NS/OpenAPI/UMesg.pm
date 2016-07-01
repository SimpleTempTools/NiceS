package NS::OpenAPI::UMesg;
use strict;
use warnings;
use Carp;

use JSON;
use LWP::UserAgent;

use base qw( NS::OpenAPI );

our $URI = "/openapi/umesg";

sub deploymesg
{
    my $self = shift;
    #deploy => '', symbol => '', info => ''
    $self->post( "$URI/deploymesg/insert", @_ );
}

sub deploystat
{
    my $self = shift;
    #deploy => '', symbol => '', stat => ''
    if( @_ )
    {
        $self->post( "$URI/deploystat/insert", @_ );
    }
    else
    {
        $self->post( "$URI/deploystat/dump" );
    }
}

1;
