package openapi_logs;
use Dancer ':syntax';
use JSON;
use FindBin qw( $RealBin );
use YAML::XS;
use Data::Dumper;
use MIME::Base64;

our $VERSION = '0.1';

set serializer => 'JSON';

any '/readme' => sub {
    template 'openapi_logs';
};

any '/mon' => sub { return 'ok'; };

any '/put' => sub {
    my $param = params();
    $param->{type} ||= 'INFO';
    $param->{node} ||= 'NULL';

    return +{ stat => $JSON::false, info => 'typeerr' } 
        unless $param->{type} eq 'INFO' || $param->{type} eq 'ERROR';
    return +{ stat => $JSON::false, info => 'noinfo' } unless $param->{info};

    eval{
        info sprintf "[%s] %s %s\n", 
            $param->{type}, $param->{node}, decode_base64($param->{info});
    };
    return  $@ ? +{ stat => $JSON::false, info => $@ }: 
                 +{ stat => $JSON::true,  data => $param };

};

true;
