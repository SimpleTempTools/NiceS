package NS::TPool::NQWrite;
use strict;
use warnings;

use Carp;
use YAML::XS;

use Digest::MD5;
use Sys::Hostname;

use threads;
use Thread::Queue;


use Time::HiRes qw/time/;

use IO::Socket;
use IO::Select;

use Data::Dumper;

sub new
{
    my ( $class, %this ) = @_;

    map{ confess "undef $_" unless $this{$_} } qw( server group );
   
    my $timeout = 30;
    $this{sock} = my $sock = IO::Socket::INET->new(
        Blocking => 0, Timeout => $timeout,
        Proto => 'tcp', Type => SOCK_STREAM,
        PeerAddr => $this{server},
    );

    die "socket:[addr:$this{server}] $!\n" unless $sock;
    return bless \%this, ref $class || $class;
}

sub run
{
    my ( $this, $index ) = shift;
    my( $group, $sock ) = @$this{qw( group sock )};

    $sock->send( $group );

    while( <> )
    {
        next unless my $in = $_;
        chomp $in;
        $sock->send( $in );
    }
}

1;
