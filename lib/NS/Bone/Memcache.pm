package NS::Bone::Memcache;

use strict;
use warnings;

use base qw(NS::Bone);

use Cache::Memcached;
use Data::Dumper;

our $THIS = 'memcache';
my $single;

sub ini
{
    my $this = shift;
    $this->_conn;
}
sub ping 
{
    my $h = $single->stats('misc') if $single;
    $h ||= {};
    keys %$h > 0;
 }

sub conn
{
    my $this = shift;
    Cache::Memcached->new(%$this);
}
sub _conn
{
    my $this = shift;
    $single = $this->conn unless $single && $single->stats('misc');
    $this;
}

sub _keys
{
    my( $this, $slab, @keys ) = @_;
    my ($hash, $value) = $single->stats("cachedump $slab 0");
    ( $value )= map{values %$_ }map{ values %$_ }values %$hash;
    $value =~ s/ITEM (.+?) /push @keys, $1/ge;
    return wantarray ? @keys : \@keys;
}
sub _slabs
{
    my( $this, %slabs ) = @_;

    my ($hash, $value) = $single->stats('slabs');
    ( $value )= map{values %$_ }map{ values %$_ }values %$hash;
    $value =~ s/STAT (\d+)\:/$slabs{$1}=1/ge;
    return wantarray ? keys %slabs : [ keys %slabs ];
}

sub keys
{
    my ($this, $pat, $reg) = @_;
    $reg = qr/$pat/;
    $this->_conn();
    my @keys =grep{ $_ =~ $reg } map{ $this->_keys($_) }($this->_slabs) ;
}

sub _join_first { join("", splice @_, 0, 2), @_ }

my %prefix = 
(
    get =>  \&_join_first,
    add =>  \&_join_first,
    set =>  \&_join_first,
    incr => \&_join_first,
    decr => \&_join_first,
    delete => \&_join_first,
    get_multi => sub{my $prefix = shift; map{ $prefix.$_ }@_},
);

sub AUTOLOAD
{
    return if our $AUTOLOAD =~ /::DESTROY$/;

    my ($this,$class) = shift;
    $class = ref $this;

    my( $func ) = $AUTOLOAD =~ /^$class\:\:(.+)$/;
    return unless $func;

    my( $method, @prefix, $prefix ) = split /_/, $func;
    
    $this->_conn();

    $prefix = join $NS::Bone::option{delimiter} || ':', (@prefix,"");

    return $this->keys("^$prefix.*") if $method eq 'keys';
    $method = "flush_all" if $method eq 'flush';
    $method = 'get_multi' if $method eq 'mget';
    $prefix{$method} ? $single->$method( $prefix{$method}->( $prefix, @_ ) )
                   : $single->$method( @_ );
}
1
