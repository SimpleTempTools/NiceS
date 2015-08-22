package NS::VSSH::HostDB;

use warnings;
use strict;
use Carp;

use Tie::File;
use File::Basename;
use NS::Hermes;

use constant BASE => 'base';

sub new
{
    my ( $class, %self ) = @_;

    $self{name} ||= BASE;
    $self{cache} = +{};

    bless \%self, ref $class || $class;
}

sub add
{
    my $this = shift;

    my @node = map{ split /\s+/, $_ }@_;
    my ( $cache, $name, $path ) = @$this{qw( cache name path )};

    die "not allow\n" if $name =~ /:/;
    if( $path && $name ne BASE )
    {
        die "tie $path/$name fail: $!\n" unless tie my @curr, 'Tie::File', "$path/$name";
        my %node = map{ $_ => 1 }@curr;
        push  @curr, grep{ ! $node{$_} }@node;
        untie @curr;
    }
    else
    {
        my %node = map{ $_ => 1 }@{$cache->{$name}};
        push @{$cache->{$name}}, grep{ ! $node{$_} }@node;
    }
    return $this;
}

sub del
{
    my $this = shift;

    my ( $cache, $name, $path ) = @$this{qw( cache name path )};
    die "not allow\n" if $name =~ /:/;

    my %node = map{ $_ => 1 }map{ split /\s+/, $_ }@_;

    if( $path && $name ne BASE )
    {
        die "tie $path/$name fail: $!\n" unless tie my @curr, 'Tie::File', "$path/$name";
        @curr = grep{ ! $node{$_} }@curr;
        untie @curr;
    }
    else
    {
        $cache->{$name} = [ grep{ ! $node{$_} }@{$cache->{$name}} ];
    }
}

sub use
{
    my ( $this, $name ) = @_;
    $this->{name} = $name if $name;
    return $this->{name};
}

sub load
{
    my $this = shift;
    my ( $cache, $name, $path, $sub, @node ) = @$this{qw( cache name path )};

    $name = shift if @_;

    ( $name, $sub ) = split /:/, $name, 2;

    if( $path && $name ne BASE )
    {
        die "tie $path/$name fail: $!\n" unless tie @node, 'Tie::File', "$path/$name";
    }
    else
    {
        $cache->{$name} ||= [];
        @node = @{$cache->{$name}};
    }

    @node = grep{ /\w/ }map{ split /\s+/, $_ }@node;

    my ( %o, @o );
    map{ push @o, $_ unless $o{$_}; $o{$_} = 1; }@node;   
    @node = @o;

    return @node unless $sub;

    my @n;
    map{ push @n, $node[$_-1] if defined $node[$_-1]  }
        sort{ $a <=> $b }NS::Hermes->new()->load( $sub )->list();
    
    return @n;
}

sub sort
{
    my ( $this, $sort ) = @_;
    my ( $cache, $name, $path ) = @$this{qw( cache name path )};

    die "not allow\n" if $name =~ /:/;

    my @node = $this->load();
    
    if( $sort )
    {
        my %node = map{ my @ex = $_ =~ /(\d+)/g;$_ => $ex[$sort -1] || 0; }@node;
        @node = sort{ $node{$a} <=> $node{$b} }@node;
    }
    else
    {
        @node = sort @node;
    }

    if( $path && $name ne BASE )
    {
        die "tie $path/$name fail: $!\n" unless tie my @curr, 'Tie::File', "$path/$name";
        @curr = @node;
        untie @curr;
    }
    else
    {
        $cache->{$name} = \@node;
    }

    return @node;
}

sub list
{
    my $this = shift;

    my ( $cache, $path, @list ) = @$this{qw( cache path )};
    if( $path )
    {
        push @list, grep{ $_ ne BASE }map{ basename $_ }grep{ -f $_ }glob "$path/*"
    }
    else
    {
        push @list, grep{ $_ ne BASE } keys %$cache;
    }
    return ( BASE, @list );
}

sub clear
{
    my ( $this, $clear ) = @_;
    my ( $cache, $name, $path ) = @$this{qw( cache name path )};

    die "not allow\n" if $name =~ /:/;

    $clear ||= $name;

    ( $path && $clear ne BASE ) ? unlink "$path/$clear" : delete $cache->{$clear};
    return $this;
}

1;
