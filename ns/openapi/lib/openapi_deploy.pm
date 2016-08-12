package openapi_deploy;
use Dancer ':syntax';
use JSON;
use FindBin qw( $RealBin );
use File::Basename;
use YAML::XS;
use NS::Hermes;
use NS::Bone::Redis;
use NS::OpenAPI::DeployVersion;

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
    my @data;
    if( my $user = params()->{user} )
    {
        if( $user !~ /^[a-zA-Z0-9\._\-]+$/ )
        {
            return +{ 
                stat =>  $JSON::false, 
                info => 'user name format error' 
            };
        }
        else
        {
             @data =  map{ $_ =~ s/\.$user//;  basename $_ } glob "$ROOT/*/\.$user";
        }
    }
    else
    {
        @data = map{ basename $_ } glob "$ROOT/*";
    }

    return +{ stat =>  $JSON::true, data => \@data };
};

any '/mon' => sub { return 'ok'; };

any '/create' => sub {
    my $name = params()->{name};
    die "format error\n" unless $name && $name =~ /^[\.\w_:-]+$/;

    return +{ 
        stat =>  system( "mkdir -p '$ROOT/$name'/{main,conf,logs,shot,snap,myid}" ) 
            ? $JSON::false : $JSON::true,
    };
};

any '/:name/' => sub {
    my $param = params();
    my ( $name ) = @$param{qw( name )};
    die "format error\n" unless $name =~ /^[\.\w_:-]+$/;
    my ( $path, %r, $err, %version ) = "$ROOT/$name";
    for my $type ( qw( main conf ) )
    {
        for( grep{ -f $_ } glob "$path/$type/*" )
        {
            my $name = basename $_;
            $r{$type}{$name} = eval{ YAML::XS::LoadFile $_ };
            if( $@ ) { $err = "load $type/$name err: $@";next; }
            my $s = YAML::XS::Dump $r{$type}{$name};
            push @{$r{macro}{$type}{$name}},map{ $version{$_} = 1; $_ } $s =~ /\$macro{([\-\.\w_]+)}/g;
        }
    }

    
    if( my @vp = map{ $_ =~ s/^version_pkg_//; $_ } grep{ /^version_pkg_.+/ }keys %version )
    {
        my $v = NS::OpenAPI::DeployVersion->new( )->version( @vp );
        map{ $r{macro_info}{"version_pkg_$_"} = $v->{$_} }keys %$v;
    }
    for my $m( keys %{$r{macro}{main}} )
    {
        for my $c ( keys %{$r{macro}{conf}} )
        {
            push @{$r{macro}{mix}{"${m}:$c"}}, @{$r{macro}{main}{$m}}, @{$r{macro}{conf}{$c}};
        }
    }
    map{ delete $r{macro}{$_}; }qw( main conf );
    for my $m ( keys %{$r{macro}{mix}} )
    {
        my %t = map{$_ => 1}@{$r{macro}{mix}{$m}};
        $r{macro}{mix}{$m} = [sort keys %t ];
    }

    return  $err ? +{ stat => $JSON::false, info => $err }: 
                   +{ stat => $JSON::true,  data => \%r };

};


any '/:name/:type' => sub {
    my $param = params();
    my ( $name, $type ) = @$param{qw( name type )};
    die "format error\n" unless $name =~ /^[\.\w_:-]+$/
                         && grep{ $_ eq $type }qw( mark info main conf );

    my $path = "$ROOT/$name/$type";
    if( $type eq 'main' || $type eq 'conf' )
    {
        my ( %r, $err );
        map{
            $r{basename $_} = eval{ YAML::XS::LoadFile $_; };
            $err = $@ if $@;
        }grep{ -f $_ }glob "$path/*";
        return $err ? +{ stat => $JSON::false, info => $err}
                    : +{ stat => $JSON::true,  data => \%r };
    }
    else
    {
        if( $param->{data} )
        {
            eval{ YAML::XS::DumpFile $path, $param->{data}; };

            return  $@ ? +{ stat => $JSON::false, info => $@ }: 
                         +{ stat => $JSON::true,  info => '' };
        }
        else
        {
            my $data = -f $path ? eval{ YAML::XS::LoadFile $path; } : +{};

            return  $@ ? +{ stat => $JSON::false, info => $@ }: 
                         +{ stat => $JSON::true,  data => $data };
        }
    }
};

any '/:name/:type/' => sub {
    my $param = params();

    my ( $name, $type ) = @$param{qw( name type )};
    die "format error\n" unless $name =~ /^[\.\w_:-]+$/ && grep{ $_ eq $type }
        qw( main conf logs shot myid );

    return +{ 
        stat =>  $JSON::true,
        data => [ map{ basename $_ } glob "$ROOT/$name/$type/*" ]
    };
};

any '/:name/myid/:myid' => sub {
    my $param = params();

    my ( $name, $myid ) = @$param{qw( name myid )};
    die "format error\n" unless $myid =~ /^[\.\w_: -]+$/;

    my $file = "$ROOT/$name/myid/$myid";
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

any '/:name/locallog/:myid' => sub {
    my $param = params();

    my ( $name, $myid ) = @$param{qw( name myid )};
    die "format error\n" unless $myid =~ /^[\.\w_: -]+$/;

    my $file = "$ROOT/$name/myid/$myid";

    if( -f $file )
    {
        my $node = eval{ YAML::XS::LoadFile $file; };
        if( $node && ! ref $node )
        {
            if( $param->{path} )
            { 
                my $ROOT = "/home/s/ops/logs/deployx";
                return +{ stat => $JSON::true, info => "$node:$ROOT/$name.$myid" };
            }
            else
            {
                redirect "/openapi/deploy_locallog/$node/$name/locallog/$myid";
            }
        }
        else
        {
            return +{ stat => $JSON::false, info => "myid format err in file" };
        }

    }
    else
    {
        return +{ stat => $JSON::false, info => "no find the myid" };
    }
};

any '/:name/kill/:myid' => sub {
    my $param = params();

    my ( $name, $myid ) = @$param{qw( name myid )};
    die "format error\n" unless $myid =~ /^[\.\w_: -]+$/;

    my $file = "$ROOT/$name/myid/$myid";

    if( -f $file )
    {
        my $node = eval{ YAML::XS::LoadFile $file; };
        if( $node && ! ref $node )
        {
            redirect "/openapi/deploy_locallog/$node/$name/kill";
        }
        else
        {
            return +{ stat => $JSON::false, info => "myid format err in file" };
        }

    }
    else
    {
        return +{ stat => $JSON::false, info => "no find the myid" };
    }
};



any '/:name/sc/:mark' => sub {
    my $param = params();

    my $mark = $param->{mark};
    die "format error\n" unless $mark =~ /^[\.\w_: -]+$/;

    my ( %r, $err );
    if( $param->{data} )
    {
        eval{
            my $redis = NS::Bone::Redis->new();
            $redis->hmset( "deploy:sc:$mark", %{$param->{data}} );
        };
    }
    else
    {
        eval{
            my $redis = NS::Bone::Redis->new();
            %r = $redis->hgetall( "deploy:sc:$mark" );
        };
    }
    return $err ? +{ stat => $JSON::false, data => \%r, info => $err }: 
                  +{ stat => $JSON::true,  data => \%r, info => 1 };
};


any '/:name/:type/:task' => sub {
    my $param = params();

    my ( $name, $type, $task ) = @$param{qw( name type task )};
    die "format error\n" unless $name =~ /^[\.\w_:-]+$/ && $task =~ /^[\.\w_:-]+$/ 
                                     && grep{ $_ eq $type }qw( main conf logs logs_s );

    if( $type eq 'logs_s' )
    {
        my $file = "$ROOT/$name/logs/$task";
        my $data = -f $file ? eval{ YAML::XS::LoadFile $file; } : +{};
        if( $@ || ref $data ne 'HASH' )
        {
            return +{ stat => $JSON::false, info => $@ };
        }
        else
        {
            my $todo = $data->{todo};
            my ( $title, $step ) = @$todo;

            if( $title &&  $step )
            {
                my %r;
                eval{
                    my $redis = NS::Bone::Redis->new();
                    %r = $redis->hgetall( "deploy:sc:name:$name:mark:$task:title:$title:step:$step" );
                };
 
                map{ $data->{succ}{$title}{$_} = $r{$_} }keys %r;
            }
            if( $param->{h} )
            {
                my $cache = $data;
                $data = '';

               my $range = NS::Hermes->new();
               for ( 0 .. @{$cache->{step}} - 1  )
               {
                    my $step = $cache->{step}[$_];
                    my @succ = ( $cache->{succ}{$step} ) ? keys %{$cache->{succ}{$step}} : ();
                    $data .= sprintf "%s : $step:\t[%s]:%s\n", $cache->{glob}[$_] ? 'Glob ' : 'Batch',
                        ,scalar $range->load( \@succ )->list(), $range->load( \@succ )->dump;
               }
       
               $data .= "\n\n";
               for my $node ( @{$cache->{node}} )
               {
                   $data .= sprintf "[%s]:%s\n", 
                       scalar $range->load( $node )->list(), $range->load( $node )->dump;
               }

            }

            return  $@ ? +{ stat => $JSON::false, info => $@ }: 
                         +{ stat => $JSON::true,  data => $data };
        }

    }
    else
    {
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
    }
};

any '/:name/snap/:date/:info' => sub {
    my $param = params();

    my ( $name, $date, $info ) = @$param{qw( name date info )};
    die "format error\n" unless $name =~ /^[\.\w_:-]+$/ && $date =~ /^[\.\w_:-]+$/ 
                                     && grep{ $_ eq $info }qw( main conf );

    my $path = "$ROOT/$name/snap/$date";
    my $file = "$path/$info";
    if( $param->{data} )
    {
        mkdir $path unless -d $path;
        eval{ YAML::XS::DumpFile $file, $param->{data}; } unless -f $file;

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

any '/:name/macro/:main/:conf/' => sub {
    my $param = params();

    my ( $name, $main, $conf ) = @$param{qw( name main conf )};
    die "format error\n" unless $name =~ /^[\.\w_:-]+$/ && $name =~ /^\w+$/ && $conf =~ /^\w+$/;
    my ( @macro, $err );
        
    for my $file ( "$ROOT/$name/main/$main", "$ROOT/$name/conf/$conf" )
    {
        unless ( -f $file ) { $err = "no file:$file"; next; } 
        my $d = eval{ YAML::XS::LoadFile $file };
        if( $@ ){ $err = "load file fail:$@"; next}

        my $s = YAML::XS::Dump $d;
        push @macro, $s =~ /\$macro{([\w_]+)}/g
    }

    my %macro = map{ $_ => 1}@macro;
    return  $err ? +{ stat => $JSON::false, info => $err }: 
                   +{ stat => $JSON::true,  data => [ sort keys %macro] };
};


any '/:name/shot/:id/:type/' => sub {
    my $param = params();

    my ( $name, $id, $type ) = @$param{qw( name id type )};
    die "format error\n" unless $name =~ /^[\.\w_:-]+$/ && $id =~ /^\d+$/ && grep{ $_ eq $type }
        qw( main conf );

    return +{ 
        stat =>  $JSON::true,
        data => [ map{ basename $_ } glob "$ROOT/$name/shot/$id/$type/*" ]
    };
};


any '/:name/shot/:id/:type/:task' => sub {
    my $param = params();

    my ( $name, $id, $type, $task ) = @$param{qw( name id type task )};
    die "format error\n" unless $name =~ /^[\.\w_:-]+$/ && $task =~ /^[\.\w_:-]+$/ && $id =~ /^\d+$/
                                     && grep{ $_ eq $type }qw( main conf );

    my $file = "$ROOT/$name/shot/$id/$type/$task";
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
