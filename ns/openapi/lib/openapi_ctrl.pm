package openapi_ctrl;
use Dancer ':syntax';
use Data::Dumper;
use NS::Bone::Mysql;
use JSON;
use NS::OpenAPI::Deploy;

our $VERSION = '0.1';

my $mysql; BEGIN{ $mysql = NS::Bone::Mysql->new('openapi_ctrl'); };
my @col = qw( name ctrl step node info );

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
    return grep{ $_ !~/^[\*\/\w _\.:-]*$/ }map{ ref $_ ? @$_: ( $_ ) }values %param;
}

set serializer => 'JSON';

any '/readme' => sub { template 'openapi_ctrl'; };

any '/mon' => sub {
     eval{ query( sprintf "select count(*) from ctrl" )};
     return $@ ? "ERR:$@" : "ok";
};

any '/pause/:name' => sub {
    my $param = params();
    die "format error\n" if check( %$param );

    my $r = eval{ execute( sprintf "insert into ctrl (%s) values ( %s)", 
                          join( ',',map{"`$_`"}@col),
                          join( ',',map{"'$_'"} @$param{@col}) 
                 )};
    return $@ ? +{ stat => $JSON::false, info => $@ } : 
                +{ stat => $JSON::true,  info => '', data => $r };
};


any '/dump' => sub { stuck(); };

any '/stuck/:name' => sub {
    my $param = params();
    die "format error\n" if check( %$param );
    stuck(%$param);
};

sub stuck
{
    my %param = @_;
    my @where = ( "ctrl!='exclude'" );
    push @where, "name='$param{name}'" if $param{name};
    map{ push @where, "( $_='$param{$_}' or $_='any' )" if $param{$_} }qw( step node );

    my $r = eval{ query( 
                    sprintf "select * from ctrl where %s", join ' and ', @where 
                 )};

    return  +{ stat => $JSON::false, info => $@ } if $@ || ref $r ne 'ARRAY';

    if( my @nouse = map{ $_->[0] }grep{ ! $_->[7] }@$r )
    {
        eval{ 
            execute( 
                sprintf "update ctrl set used='%s' where id in ( %s)",
                    POSIX::strftime( "%Y-%m-%d %H:%M:%S", localtime ),
                    join ',', @nouse
            );
        };
        return  +{ stat => $JSON::false, info => $@ } if $@;
    }
    return +{ stat => $JSON::true,  info => '', data => $r };
}

any '/resume/:name' => sub {
    my $param = params();
    die "format error\n" if check( %$param );

    if( my $user = $param->{user} )
    {
        my $oapi => NS::OpenAPI::Deploy->new( name => $param->{name} );
        my $u = $oapi->mark()->{user};
        return  +{ stat => $JSON::false, info => "user $param->{user} no auth to resume" } 
            unless ( $u && $u eq $user );
    }

    my @where = ( "ctrl!='exclude'", "name='$param->{name}'" );
    map{ push @where, "$_='$param->{$_}'" if $param->{$_} }qw( step node );

    my $r = eval{ execute( sprintf "delete from ctrl where %s", join ' and ', @where )};
    return $@ ? +{ stat => $JSON::false, info => $@ } : 
                +{ stat => $JSON::true,  info => '', data => $r };
};


any '/exclude/:name' => sub {
    my $param = params();
    die "format error\n" if check( %$param );

    my @exclude = ref $param->{exclude} ? @{$param->{exclude}} : ( $param->{exclude} );
    eval{ map{ execute( sprintf "insert into ctrl (%s) values ( '$param->{name}','exclude','any','any','%s' )", join( ',',map{"`$_`"}@col), $_) }@exclude};
    return $@ ? +{ stat => $JSON::false, info => $@ } : 
                +{ stat => $JSON::true,  info => '', data => scalar @exclude };
};


any '/excluded/:name' => sub {
    my $param = params();
    die "format error\n" if check( %$param );

    my $r = eval{ query( 
                    "select info from ctrl where name='$param->{name}' and ctrl='exclude'" 
                 )};
    return $@ ? +{ stat => $JSON::false, info => $@ } : 
                +{ stat => $JSON::true,  info => '', data => $r };
};


any '/clear/:name' => sub {
    my $param = params();
    die "format error\n" if check( %$param );

    my $r = eval{ execute( "delete from ctrl where name='$param->{name}'" )};
    return $@ ? +{ stat => $JSON::false, info => $@ } : 
                +{ stat => $JSON::true,  info => '', data => $r };
};

true;
