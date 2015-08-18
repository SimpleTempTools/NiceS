package NS::VSSH::HostDB;

use warnings;
use strict;
use Carp;

use Tie::File;
use File::Basename;

our $passwd;

sub new
{
    my ( $class, %self ) = @_;

    $self{name} ||= 'base';
    $self{cache} = +{};

    bless \%self, ref $class || $class;
}

sub add
{
    my $this = shift;
    my ( $cache, $name, $path ) = @$this{qw( cache name path )};

    if( $path )
    {
        die "tie $path/$name fail: $!\n" unless tie my @curr, 'Tie::File', "$path/$name";
        my %node = map{ $_ => 1 }@curr;
        push  @curr, grep{ ! $node{$_} }@_;
        untie @curr;
    }
    else
    {
        my %node = map{ $_ => 1 }@{$cache->{$name}};
        push @{$cache->{$name}}, grep{ ! $node{$_} }@_;
    }
}

sub del
{
    my $this = shift;
    my %node = map{ $_ => 1 }@_;

    my ( $cache, $name, $path ) = @$this{qw( cache name path )};

    if( $path )
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
    $this->{name} = $name if $name ;
    return $this->{name};
}

sub load
{
    my $this = shift;
    my ( $cache, $name, $path ) = @$this{qw( cache name path )};

    if( $path )
    {

        die "tie $path/$name fail: $!\n" unless tie my @curr, 'Tie::File', "$path/$name";
        return @curr;
    }
    else
    {
        $cache->{$name} ||= [];
        return @{$cache->{$name}};
    }

}

sub sort
{
    my ( $this, $sort ) = @_;
    my ( $cache, $name, $path ) = @$this{qw( cache name path )};
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
    if( $path )
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

    my ( $cache, $path ) = @$this{qw( cache path )};
    if( $path )
    {
        return map{ basename $_ }glob "$path/*"
    }
    else
    {
        return keys %$cache;
    }
}

sub clear
{
    my ( $this, $clear ) = @_;
    my ( $cache, $name, $path ) = @$this{qw( cache name path )};
    $clear ||= $name;
    $path ? unlink "$path/$clear" : delete $cache->{$clear};
    return $this;
}

1;
