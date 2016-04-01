package openapi_at;
use Dancer ':syntax';
use Data::Dumper;
use NS::Bone::Mysql;
use Sys::Hostname;
use JSON;
use Dancer qw(session debug);
use FindBin qw( $RealBin );

our $VERSION = '0.1';

my ( $mysql, $do, $data, $hostname, %allowip ); 
BEGIN{ 
    sub query
    {
        my $sth = $mysql->prepare( shift );
        $sth->execute();
        $sth->fetchall_arrayref;
    }
    sub execute
    {
        my $sth = $mysql->prepare( shift );
        $sth->execute();
    }

    $mysql = NS::Bone::Mysql->new('openapi_at'); 
    ( $do, $data ) = map{ "$RealBin/../$_" }qw( code/at.do data/at );
    $hostname = Sys::Hostname::hostname;
    my $allowip  = eval{ query( "select ip from allow" ) };
    map{ $allowip{$_->[0]} = 1; }@$allowip;

    die "no allowip" unless keys %allowip;
};

my @col = qw( ip user channel task slave use stat code callback );

sub check
{
    my %param = @_;
    return grep{ $_ !~/^[\/=\w _\.:-]+$/ }map{ ref $_ ? @$_: ( $_ ) }values %param;
}

sub checkenv
{
    my $env = shift;
    die "110 fail" unless  my $remoteip = $env->{'HTTP_X_REAL_IP'} || $env->{REMOTE_ADDR};
    die "code: 110" unless $allowip{ $remoteip};
}

set serializer => 'JSON';

any '/readme' => sub { template 'openapi_at'; };
any '/debug' => sub { 
    my $active = eval{ 
      query(
        "select * from at where id>( select max(id) from at ) 
            -200 and `stat` like 'pid:%' order by id desc"
      ) 
    };
    my $all = eval{ 
      query( 
        "select * from at where id>( select max(id) from at ) -100 order by id desc"
      ) 
    };
 
    template 'openapi_at_debug', +{ active => $active, all => $all }; 
};

any '/chatroom' => sub { 
    my $user = params()->{user};
    session user => $user;
    template 'openapi_at_chatroom', +{}; 
};

any '/code' => sub {
    my $param = params();
    die "format error\n" if check( %$param );
    
    my $r = eval{ 
        execute( "update at set `code`='$param->{code}' where id=$param->{id}" );
    };

    return +{ stat => '', info => '', data => $r };
};

any '/stat' => sub {
    my $param = params();
    die "format error\n" if check( %$param );
    
    my $r = eval{ 
      execute( 
        "update at set `stat`='$param->{stat}' where id=$param->{id} and `stat` != 'done'"
      ); 
   };

    return +{ stat => '', info => '', data => $r };
};

any '/cbstat' => sub {
    my $param = params();
    die "format error\n" if check( %$param );
    
    my $r = eval{ 
      execute(
        "update at set `cbstat`='$param->{cbstat}' where id=$param->{id} and `stat` != ''"
      );
    };

    return +{ stat => '', info => '', data => $r };
};


any '/use' => sub {
    my $param = params();
    die "format error\n" if check( %$param );
    
    my $r = eval{ 
      execute( "update at set `use`='$param->{use}' where id=$param->{id}" ); 
    };

    return +{ stat => '', info => '', data => $r };
};

any '/do' => sub {
    my $param = params();
    my %env = %{request->env};
    die "param format error\n" if check( %$param );

    checkenv( request->env );

    $param->{ip} = $env{'HTTP_X_REAL_IP'} || 'unkown' unless $param->{ip};
    map{ $param->{$_}  ||= 'unkown' }qw( user channel );
    $param->{slave} = $hostname;

    my ( $code ) = split /\s+/, $param->{task};

    die "$code code format error" unless $code =~ /^\w+$/;
    
    my $auth = eval{
        query( 
          "select `user`,`code` from auth where ( `user`='$param->{user}' and `code` = '$code' )
          or ( `user`='$param->{user}' and `code` = '*' ) or ( `user`='*' and `code` = '$code' )" 
        );
    };
    unless( $auth && @$auth > 0 )
    {
        return $param->{raw} ? 'Permission denied'
             : +{ stat => $JSON::false, info => 'Permission denied' };
    }


    my $r = eval{ execute( sprintf "insert into at (%s) values (%s)", 
      join( ',',map{"`$_`"}@col),
        join( ',',map{ defined $_ ? $_ eq 'now' ? 'now()' : "'$_'": "''" }
        @$param{@col}) 
      );
      query( 'select LAST_INSERT_ID()' );
    };

    my ($stat, $info, $data ) = ( $JSON::false, "slave=$hostname", '' );
    if( $@ ) { $info = $@ }
    elsif( $r->[0][0] !~ /^\d+$/ ) { $info = 'last insert id error'; }
    else
    {
        my $task = $param->{task};
        unless( $task && $task =~ /^[\.=a-z0-9_ -]+$/ )
        {
            $info = "task format error: $param->{task}";
        }
        else
        {
             my $callback = $param->{callback} || 'null';
             die "callback format error" unless $callback =~ /^[:\.\/\w]+$/; 
             $data = $r->[0][0] unless $info .= `$do $r->[0][0] $callback $param->{channel} $task 2>&1 </dev/null`||'';
             $stat = $JSON::true;
        }
    }

    return $param->{raw} ? $r->[0][0] ? $r->[0][0] : 'fail'  :  +{ stat => $stat, info => $info, data => $data };
};

any '/stat/:id' => sub {
    my $id = params()->{id};
    die "format err" unless $id =~ /^\d+$/;

    my $r = eval{ query( 
        "select `stat` from at where id=$id"
    )};

    return $r->[0][0] ||= 'unkown';
};

any '/slave/:id' => sub {
    my $id = params()->{id};
    die "format err" unless $id =~ /^\d+$/;
    my $r = eval{ query( 
        "select `slave` from at where id=$id"
    ) };

    return $r->[0][0] ||= 'unkown';
};


any '/result/:id' => sub {
    my $id = params()->{id};
    die "format err" unless $id =~ /^\d+$/;
    my $r = eval{ query( 
        "select slave from at where id=$id"
    )};

    redirect "/openapi/at/result/$r->[0][0]/$id";
};

any '/result/:slave/:id' => sub {
    my ( $slave, $id, $raw ) = map{ params()->{$_} }qw( slave id raw );
    return +{ stat => $JSON::false, info => "slave error $hostname" } if $slave ne $hostname;
    return +{ stat => $JSON::false, info => 'null' } unless $id && $id =~ /^\d+$/ && -f "$data/$id";

    my $out = `cat '$data/$id'`||'';
    
    return $raw ? $out : +{ stat => $JSON::true,  data => $out };
};

any '/kill/:id' => sub {
    my $id = params()->{id};
    die "id err" unless $id =~ /^\d+$/;

    my $r = eval{ query( "select slave,`stat` from at where id=$id" ) };

    die "search slave err" unless $r && @$r > 0;
    my ( $slave, $stat ) = @{$r->[0]};
    $stat =~ s/^pid://;
    redirect "/openapi/at/kill/$slave/$stat/$id";
};

any '/kill/:slave/:pid/:id' => sub {
    checkenv( request->env );
    my ( $slave, $pid, $id ) = map{ params()->{$_} }qw( slave pid id );
    return +{ stat => $JSON::false, info => "slave err" } if $slave ne $hostname;

    return +{ stat => $JSON::false, info => "format err" }
        unless $id && $id =~ /^\d+$/ && $pid && $pid =~ /^\d+$/;

    my $cmdline = `cat /proc/$pid/cmdline`;

    return +{ stat => $JSON::false, info => "kill cmdline no match" } 
        unless $cmdline && $cmdline eq "at.do=$id";
    kill 9, $pid;

    my $r = eval{ 
      execute( sprintf "update at set `stat`='killed' where id='$id'" )
    };
    return +{ stat => $JSON::true, data => 'killed' };
};

true;
