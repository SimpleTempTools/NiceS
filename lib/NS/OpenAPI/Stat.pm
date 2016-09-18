package NS::OpenAPI::Stat;
use strict;
use warnings;
use Carp;

use JSON;
use LWP::UserAgent;

use base qw( NS::OpenAPI );

our $URI = "/openapi/stat";

# group => nices, name => nices, stat => ok
sub set { shift->post( "$URI/stat", @_  ); }

sub dump { shift->get( "$URI/stat" ); }
sub logs { shift->get( "$URI/stat?logs=1" ); }

1;
