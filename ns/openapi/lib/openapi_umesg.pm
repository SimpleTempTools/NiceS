package openapi_umesg;
use Dancer ':syntax';
use Data::Dumper;
use NS::Bone::Mysql;
use JSON;

our $VERSION = '0.1';

my $mysql; BEGIN{ $mysql = NS::Bone::Mysql->new('openapi_umesg'); };

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

sub check
{
    my %param = @_;
    return grep{ $_ !~/^[\/\w _\.:-]*$/ }map{ ref $_ ? @$_: ( $_ ) }values %param;
}

set serializer => 'JSON';

any '/readme' => sub { template 'openapi_deployinfo'; };

any '/mon' => sub {
     eval{ query( sprintf "select count(*) from usermesg" )};
     return $@ ? "ERR:$@" : "ok";
};

any '/usermesg/insert' => sub {
    my $param = params();
    die "format error\n" if check( %$param );

    my $r = eval{ execute( 
        sprintf "insert into usermesg (`mark`,`user`,`info`) values ('1','%s','%s')", 
            @$param{qw( user info)} )};
    return $@ ? +{ stat => $JSON::false, info => $@ } : 
                +{ stat => $JSON::true,  info => '', data => $r };
};

any '/deploystat/insert' => sub {
    my $param = params();
    die "format error\n" if check( %$param );

    my $r = eval{ execute( 
        sprintf "replace into deploystat (`name`,`mark`,`stat`) values ('%s','%s','%s')", 
            @$param{qw( name mark stat )} )};
    return $@ ? +{ stat => $JSON::false, info => $@ } : 
                +{ stat => $JSON::true,  info => '', data => $r };
};

any '/user_deploy/insert' => sub {
    my $param = params();
    die "format error\n" if check( %$param );
    my @col = qw( user deploy symbol );
    my $r = eval{ execute( sprintf "insert into user_deploy (%s) values ( %s)",
                          join( ',',map{"`$_`"}@col),
                          join( ',',map{"'$_'"} @$param{@col})
                 )};
    return $@ ? +{ stat => $JSON::false, info => $@ } :
                +{ stat => $JSON::true,  info => '', data => $r };
};

any '/deploymesg/insert' => sub {
    my $param = params();
    die "format error\n" if check( %$param );
    my $r = eval{ execute( sprintf 
        "insert into usermesg (`user`,`mark`,`info`) select `user`,'1','%s' from user_deploy  where deploy='%s' and symbol='%s'",
        @$param{qw( info deploy symbol)})
                 };
    return  +{ stat => $JSON::false, info => $@ }  if $@;
    unless( $r && $r >0 )
    {
        eval{ execute( sprintf
        "insert into usermesg (`user`,`mark`,`info`) values( 'unkown', '1', '$param->{info}' )" )
                 };
    }
    return $@ ? +{ stat => $JSON::false, info => $@ } :
                +{ stat => $JSON::true,  info => '', data => $r };
};


any '/usermesg/count/:user' => sub {
    my $param = params();
    die "format error\n" if check( %$param );

    my $r = eval{ query( "select count(*) from usermesg where mark='1' and user='$param->{user}'" )};
    return $@ ? +{ stat => $JSON::false, info => $@ } : 
                +{ stat => $JSON::true,  info => '', data => $r->[0][0] };
};

any '/deploystat/dump' => sub {
    my $param = params();
    die "format error\n" if check( %$param );

    my $r = eval{ query( "select name,mark,stat from deploystat as a where 5>( select count(*) from  deploystat where a.name = name and id > a.id ) order by a.id desc" )};
    #my $r = eval{ query( "select `name`,`mark`,`stat` from deploystat" )};
    return $@ ? +{ stat => $JSON::false, info => $@ } : 
                +{ stat => $JSON::true,  info => '', data => $r };
};


true;
