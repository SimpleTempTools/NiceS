package NS::OpenAPI::Logs;
use strict;
use warnings;
use Carp;

use JSON;
use LWP::UserAgent;
use MIME::Base64;
use Sys::Hostname;

use base qw( NS::OpenAPI );

our $URI = "/openapi/logs";

sub put
{
    my ( $self, %param ) = @_;
    $param{node} = sprintf "host=%s:exec=%s:pid=%s", hostname, $0, $$;
    $param{info} = encode_base64( $param{info} );
    $self->post( "$URI/put", %param );
}

1;
