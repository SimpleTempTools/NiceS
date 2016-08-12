package openapi_appsdeploy;
use Dancer ':syntax';
use JSON;
use FindBin qw( $RealBin );
use YAML::XS;

use Data::Dumper;
use File::Basename;

our $VERSION = '0.1';
our $ROOT = "$RealBin/../data/openapi_appsdeploy";

set serializer => 'JSON';

any '/readme' => sub {
    template 'openapi_appsdeploy';
};

any '/mon' => sub { return 'ok'; };

any '/list/' => sub {
    return +{ stat =>  $JSON::true, data => [ map{ basename $_ }glob "$ROOT/*"] };
};


any '/:node' => sub {
    my $node = params()->{node};
    return +{ stat =>  $JSON::false, info => 'node format error' }
        unless $node =~ /^[a-zA-Z0-9_\.-]+$/;

    return +{ stat =>  $JSON::false, info => "$node undef" } unless -e "$ROOT/$node";

    my %data;
    $data{ctrl} = eval{ YAML::XS::LoadFile  "$ROOT/$node" };
    return +{ stat =>  $JSON::false, info => "load $node error:$@" } if $@;
    $data{macro}{name} = $node;
    return +{ stat =>  $JSON::true, data => \%data };
};

true;
