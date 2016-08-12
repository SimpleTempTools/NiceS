package openapi;
use Dancer ':syntax';
use Data::Dumper;
use NS::Util::OptConf;
use JSON;

our $VERSION = '0.1';

#load_app 'openapi', prefix => '/openapi/deploy', settints => {};

set serializer => 'JSON';

any '/readme' => sub {
    template 'openapi';
};

#any '/test' => sub { return 'any'; };
get '/test' => sub { return 'get'; };
put '/test' => sub { return 'put'; };
post '/test' => sub { return 'post'; };

true;
