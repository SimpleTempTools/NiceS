package NS::Bone::Redis;

use strict;
use warnings;

use base qw(NS::Bone);

use Redis;
use Sys::Hostname;
use Data::Dumper;


our $THIS = 'redis';
=head1 NAME

NS::Bone::Redis. - NS Redis Singleton

=head1 SYNOPSIS

my $redis = NS::Bone::Redis->new();

$redis->setex_collect_node("foo", 120, "value");    #redis setex "collect:node:foo" 120 "value"

$redis->mget_foo_bar('a', 'b', 'c');                #redis mget "foo:bar:a" "foo:bar:b" "foo:bar:c"

$redis->mset_collect_cluster( cluster1 => value1, cluster2 => value2, cluster3 => value3);
                                                    #redis mset "collect:cluster:cluster1" => value1 ...

$redis->set_fk('foo', value);

$redis->get_fk('foo');

$redis->keys_collect_node('*')      <=>      $redis->keys('collect:node:*')

my $redis = NS::Bone::Redis->new();           #get ns redis slave through .config

$redis->conn;                                       #return new redis connection

=cut
my( $single, @expire);
sub ini
{
    my ($this, $host, $expire) = splice @_, 0, 2;

    $host = hostname;           
    for(keys %{ $this->{servers} })
    {
        $this->{conn} = $this->{servers}->{$_} and last if $host =~ /$_/;
    }
    die 'can not find redis server' unless $this->{conn};

    @expire = map { [qr/^$_->[0]/, $_->[1]] }@{ $this->{expire} };

    $this->_conn;

    return $this;
}

sub conn
{
    my $this = shift;
    Redis->new( %{$this->{conn}}, debug => 0, reconnect => 60 );
}

sub _conn
{
    my $this = shift;
    $single = Redis->new( %{$this->{conn}}, debug => 0, reconnect => 60 );
}
sub _expire
{
    my ($prefix, $expire) = shift;
    for(@expire)
    {
        #print $prefix. " match ". $_->[0]. "| expire:". $_->[1]. "\n" if $prefix =~ $_->[0];
        $expire = $_->[1] and last if $prefix =~ $_->[0];
    }
    return $expire;
}

my %prefix = 
(
    'keys' => sub{ join "",@_ },
    get => sub{ join "",@_ },
    set => sub{  join("", splice @_, 0, 2), @_ },
    mget => sub{ my $prefix = shift; map{ $prefix.$_ }@_ },
    mset => sub{ my($prefix, %hash) = @_; map{ $prefix.$_ => $hash{$_} }keys %hash; },
    setex => sub
    { 
        my($prefix, $expire) = join "", splice @_, 0, 2; 
        $expire = _expire($prefix);
        unshift @_, $expire if $expire;
        ($prefix, @_);
    },
);

sub AUTOLOAD
{
    return if our $AUTOLOAD =~ /::DESTROY$/;

    my ($this,$class) = shift;
    $class = ref $this;

    my( $func ) = $AUTOLOAD =~ /^$class\:\:(.+)$/;
    return unless $func;

    my( $method, @prefix, $prefix ) = split /_/, $func;
    #$this->_conn() unless $single && $single->ping;

    $prefix = join $NS::Bone::option{delimiter} || ':', (@prefix,"");
    $prefix{$method} ? $single->$method( $prefix{$method}->( $prefix, @_ ) )
                   : $single->$func( @_ );
}


1;
