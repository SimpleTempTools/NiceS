package NS::Poros::Client;

=head1 NAME

NS::Poros::Client

=head1 SYNOPSIS

 use NS::Poros::Client;

 my %proxy_config = ( );
 my $client = NS::Poros::Client->new( [ 'node1:13148', 'node2:13148' ] )
                  ->proxy( 'proxy/config/path' );

 my %result = $client->run( timeout => 300, input => '' ); 

=cut
use strict;
use warnings;

use Carp;
use YAML::XS;
use File::Spec;
use File::Basename;
use FindBin qw( $RealBin );
use YAML::XS;

use NS::MIO::TCP;
use NS::Poros::Query;

our %RUN = ( 
    user => 'root', max => 128, timeout => 300,
    'proxy-timeout' => 86400, 'proxy-max' => 32
);

sub new
{
    my $class = shift;
    bless +{ node => \@_ }, ref $class || $class;
}

sub proxy
{
    my ( $this, $conf ) = @_;

    return $this unless $conf && $this->{node} && ref $this->{node} eq 'ARRAY';

    $conf = eval{ YAML::XS::LoadFile $conf };
    confess "load proxy file fail: $@\n" if $@;

    my %conf = map{ $_->[0] => $_->[1] }@$conf;

    my %proxy;
    for my $node ( @{$this->{node} } )
    {
        map{
            if( $node =~ /$_->[0]/ ) 
            {
                push( @{$proxy{$_->[0]}}, $node );
                next;
            }
        }@$conf;
    }

    my %node;
    while( my ( $k, $n ) = each %proxy )
    {
        for( my $i = 0; @$n; $i++ )
        {
            $i = 0 if $i >= @{$conf{$k}};
            push @{$node{$conf{$k}->[$i]}}, shift @$n;
        }
    }

    $this->{node} = \%node;
    return $this;
}

sub run
{
    my ( $this, %run, %result ) = ( shift, %RUN, @_ );

    return unless my $node = $this->{node};

    if( ref $node eq 'ARRAY' )
    {
        $run{input} = NS::Poros::Query->dump( $run{input} ) if $run{input};
        %result = NS::MIO::TCP->new( @$node )
            ->run( map{ $_ => $run{$_}  }qw( user timeout max port input verbose ) );
        return %result;
    }

    my ( %input, %check );
    while( my ( $proxy, $n ) = each %$node )
    {
        
        $input{$proxy} = NS::Poros::Query->dump( 
            +{ 
               proxy => { 
                   node => $n,
                   run => +{ map{ $_ => $run{$_}  }qw( user timeout max port input )}
                }, 
               code => 'proxy' 
             } 
        );
        map{ $check{$_} = 1 }@$n;
    }

    my %r = NS::MIO::TCP->new( keys %$node )
        ->run( input => \%input, verbose => $run{verbose} ? 'proxy' : undef,
               map{ $_ => $run{"proxy-$_"} }qw( timeout max ) );

    my ( $error, $mesg ) = @r{qw( error mesg )};
    if( $error )
    {
        while( my ( $m, $n ) = each %$error )
        {
            my @node = map{@$_}@$node{@$n};
            push @{$result{error}{"[ns proxy error]: $m\n"}}, @node;
            map{ delete $check{$_} } @node;
        }
    }

    if( $mesg )
    {
         while( my ( $m, $n ) = each %$mesg )
        {
            my @node = map{@$_}@$node{@$n};
            map{ delete $check{$_} } @node;

            my $stat = $1 if $m =~ s/--- (\d+)$//;

            my ( $error, $mc ) = ( ! defined $stat )
                ? "[ns proxy no return]"
                : $stat ? "[ns proxy exit: $stat]" : undef;

            unless ( $error )
            {
                $mc = eval{ YAML::XS::Load ( $m ) };
                $error = "[ns proxy mesg no hash]: $@" if $@;
            }

            if( $error )
            {
                push @{$result{error}{"$error\n"}}, @node;
                next;
            }

            while( my ( $t, $v ) = each %$mc )
            {
                while( my ( $msg, $no ) = each %$v )
                {
                    push @{$result{$t}{$msg}}, @$no;
                }
            }
        }
    }   


    push @{$result{error}{"[ns proxy error]: no run\n"}}, keys %check if %check;
    return %result;
}

1;
