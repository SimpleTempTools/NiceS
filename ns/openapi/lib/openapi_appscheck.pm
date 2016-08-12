package openapi_appscheck;
use Dancer ':syntax';
use JSON;
use FindBin qw( $RealBin );
use File::Basename;
use YAML::XS;
use NS::Hermes;
use NS::Bone::Redis;
use NS::OpenAPI::DeployVersion;
use NS::Hermes::DBI::Cache;
use File::Basename;


use Data::Dumper;
our $VERSION = '0.1';
our $ROOT = "$RealBin/../data/openapi_appscheck";
our $HermesCache;
our $mtime = 0;
BEGIN
{
    $HermesCache = NS::Util::OptConf->load()->get()->dump('hermes')->{cache}."/current";
};

my %cache;

set serializer => 'JSON';

any '/readme' => sub {
    template 'openapi_apps';
};

any '/mon' => sub { return 'ok'; };

any '/:node' => sub {
    my $node = params()->{node};
    return +{ stat =>  $JSON::false, info => 'node format error' }
        unless $node =~ /^[a-zA-Z0-9\.-]+$/;

    return +{ stat =>  $JSON::false, info => 'get hermes cache stat fail' } 
        unless my $mt = ( stat $HermesCache )[9];

    if( $mt > $mtime )
    {

         map
         {
             $cache{$_->[2]}{$_->[0]}{$_->[1]} = $_->[3];
         } NS::Hermes::DBI::Cache->new(
                      $HermesCache, 
                      $NS::Hermes::DBI::Cache::TABLE 
                  )->select( 'name,attr,node,info' );
        $mtime = $mt;
    }


    return  +{ stat =>  $JSON::false, info => 'unfind' } 
        unless my $cache = $cache{$node};

    my %data;
    for my $name ( keys %$cache )
    {
        my @apps = map{ basename $_ } glob "$ROOT/$name/*";
        for my $apps ( @apps )
        {
            $data{"$name/$apps"}{ctrl} = eval{ YAML::XS::LoadFile  "$ROOT/$name/$apps" };
            return +{ stat =>  $JSON::false, info => "load $name/$apps fail:$@" } if $@;
            for my $attr ( sort keys %{$cache{$node}{$name}} )
            {
                map{ $data{"$name/$apps"}{macro}{$_} = $attr; }qw( cluster idc clusterid );
                $data{"$name/$apps"}{macro}{idc} =~ s/\@\d+//;
                $data{"$name/$apps"}{macro}{clusterid} =~ s/\w+\@//;
                $data{"$name/$apps"}{macro}{hostname} = $node;
                $data{"$name/$apps"}{macro}{id} =  $cache{$node}{$name}{$attr};
            }
        }

    }
    return +{ stat =>  $JSON::true, data => \%data };
};


true;
