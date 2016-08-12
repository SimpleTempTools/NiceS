package openapi_lock;
use Dancer ':syntax';
use Data::Dumper;
use NS::Bone::Mysql;
use JSON;

our $VERSION = '0.1';
my  $TABLE   = 'openapi_lock';

my $mysql; BEGIN{ $mysql = NS::Bone::Mysql->new('openapi_lock'); };

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
    return join ' ', grep{ $param{$_} !~/^[\w_\.-]+$/ }keys %param;
}

set serializer => 'JSON';

any '/readme' => sub { template 'openapi_lock'; };

any '/mon' => sub {
     eval{ query( sprintf "select count(*) from $TABLE" )};
     return $@ ? "ERR:$@" : "ok";
};

any '/dump' => sub {
    my $param = params();
    die "format error\n" if check( %$param );
    my $r = eval{ query( sprintf "select `name`,`host`,`pid`,`time` from $TABLE %s", $param->{name} ? "where name='$param->{name}'":'' ) };
    return $@ ? +{ stat => $JSON::false, info => $@ } : 
                +{ stat => $JSON::true,  info => '', data => $r };
};


any '/check/:name' => sub {
    my $param = params();
    die "format error\n" if check( %$param );

    my $r = eval{ query( "select `host`,`pid`,`time` from $TABLE where name='$param->{name}'" ) };
    return $@ ?  +{ stat => $JSON::false, info => $@ } : 
                 +{ stat => $JSON::true,  info => '', data => $r };
};

any '/lock/:name' => sub {
    my $param = params();
    die "format error\n" if check( %$param );
   
    my $error ;
    eval{

        my $r = query( "select `host`,`pid`,`time` from $TABLE where name='$param->{name}'" );

        $error = sprintf "%s", join ' ', map{@$_}@$r if @$r;

        execute( 
            sprintf "insert into $TABLE (`name`,`host`,`pid`) values('%s','%s', '%s')", 
                @$param{qw( name host pid )}) unless $error;


    };
    return $error ?  +{ stat => $JSON::false, info => $error }: 
               $@ ?  +{ stat => $JSON::false, info => $@ } 
                  :  +{ stat => $JSON::true,  info => '' };
};

any '/unlock/:name' => sub {
    my $param = params();
    die "format error\n" if check( %$param );

    my $r = eval{ execute( "delete from $TABLE where name='$param->{name}'" ) };
    return $@ ?  +{ stat => $JSON::false, info => $@ } : 
                 +{ stat => $JSON::true,  info => '', data => $r };
};

true;
