package openapi_deploy;
use Dancer ':syntax';
use JSON;
use FindBin qw( $RealBin );
use File::Basename;
use YAML::XS;

our $VERSION = '0.1';
our $ROOT; 
BEGIN{ 
    $ROOT = "$RealBin/../data/openapi_deploy";
    system "mdkir -p '$ROOT'" unless -d $ROOT;
};

set serializer => 'JSON';

any '/readme' => sub {
    template 'openapi_deploy';
};

any '/list' => sub {
    return +{ 
        stat =>  $JSON::true, 
        data => [ map{ basename $_ } glob "$ROOT/*" ] 
    };
};

any '/create' => sub {
    my $name = params()->{name};
    die "format error\n" unless $name && $name =~ /^[\w_:-]+$/;

    return +{ 
        stat =>  system( "mkdir -p '$ROOT/$name'/{conf,logs}" ) 
            ? $JSON::false : $JSON::true,
    };
};

any '/:name/:type' => sub {
    my $param = params();
    my ( $name, $type ) = @$param{qw( name type )};
    die "format error\n" unless $name =~ /^[\w_:-]+$/ && grep{ $_ eq $type }qw( main mark info );

    my $file = "$ROOT/$name/$type";

    if( $param->{data} )
    {
        eval{ YAML::XS::DumpFile $file, $param->{data}; };

        return  $@ ? +{ stat => $JSON::false, info => $@ }: 
                     +{ stat => $JSON::true,  info => '' };
    }
    else
    {
        my $data = -f $file ? eval{ YAML::XS::LoadFile $file; } : +{};

        return  $@ ? +{ stat => $JSON::false, info => $@ }: 
                     +{ stat => $JSON::true,  data => $data };
    }
};

any '/:name/:type/' => sub {
    my $param = params();

    my ( $name, $type ) = @$param{qw( name type )};
    die "format error\n" unless $name =~ /^[\w_:-]+$/ && grep{ $_ eq $type }qw( conf logs );

    return +{ 
        stat =>  $JSON::true,
        data => [ map{ basename $_ } glob "$ROOT/$name/$type/*" ]
    };
};


any '/:name/:type/:task' => sub {
    my $param = params();

    my ( $name, $type, $task ) = @$param{qw( name type task )};
    die "format error\n" unless $name =~ /^[\w_:-]+$/ && $task =~ /^[\w_:-]+$/ 
                                     && grep{ $_ eq $type }qw( conf logs );

    my $file = "$ROOT/$name/$type/$task";
    if( $param->{data} )
    {
        eval{ YAML::XS::DumpFile $file, $param->{data}; };

        return  $@ ? +{ stat => $JSON::false, info => $@ }: 
                     +{ stat => $JSON::true,  info => '' };
    }
    else
    {
        my $data = -f $file ? eval{ YAML::XS::LoadFile $file; } : +{};

        return  $@ ? +{ stat => $JSON::false, info => $@ }: 
                     +{ stat => $JSON::true,  data => $data };
    }
};

true;
