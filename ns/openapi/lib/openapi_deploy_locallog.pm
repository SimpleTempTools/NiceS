package openapi_deploy_locallog;
use Dancer ':syntax';
use JSON;
use FindBin qw( $RealBin );
use File::Basename;
use Sys::Hostname;
use YAML::XS;
use NS::Bone::Redis;
use NS::OpenAPI::Lock;


our $VERSION = '0.1';
our $ROOT; 
BEGIN{ 
    $ROOT = "/home/s/ops/logs/deployx";
    system( "mkdir -p '$ROOT'" ) unless -d $ROOT;
};

set serializer => 'JSON';

any '/readme' => sub {
    template 'openapi_deploy_locallog';
};

any '/mon' => sub { return 'ok'; };

any '/:name/locallog/:myid' => sub {
    my $param = params();

    my ( $name, $myid ) = @$param{qw( name myid )};
    die "format error\n" unless $myid =~ /^[\w_: -]+$/;

    my $file = "$ROOT/$name.$myid";
    my $data = -f $file ? `cat '$file'` : '';


    return $param->{txt} ? $data : +{ stat => $JSON::true,  data => $data };
 
};

any '/:name/kill' => sub {
    my $name = params()->{name};
    die "format error\n" unless $name =~ /^[\.\w_: -]+$/;
    my $lock = NS::OpenAPI::Lock->new( name => $name )->dump( );
    my $hostname = hostname;

    for( grep{ $_->[0] eq $name }@$lock )
    {
        my ( $host, $pid ) = ( $_->[1], $_->[2] );
        return +{ stat => $JSON::false,  data => "host $host no match $hostname" }
            unless $host eq $hostname;

        my $cmdline = `cat '/proc/$pid/cmdline'`;
        return +{ stat => $JSON::false,  data => "pid cmdline no match deployx" }
            unless $cmdline && $cmdline =~ /deployx/;

        kill 10, $pid;
        return +{ stat => $JSON::true,  info => "kill.$pid" };
    }

    return +{ stat => $JSON::true,  info => 'nokill' };
};

true;
