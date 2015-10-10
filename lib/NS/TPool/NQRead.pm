package NS::TPool::NQRead;
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

    if( my $code = $this{code} )
    {
        die "$code: No such file\n" unless -f $code;
        $this{code} = eval{ do $code };
        die "load $code fail\n" unless $this{code} && ref $this{code} eq 'CODE';
    }
    else
    {
        $this{code} = sub{ print Dumper \@_; };
    }

    die "socket:[addr:$this{server}] $!\n" unless $sock;
    return bless \%this, ref $class || $class;
}

sub run
{
    my ( $this, $index ) = shift;
    my( $group, $sock, $code ) = @$this{qw( group sock code )};

    $sock->send( $group );

    my $select = IO::Select->new();
    $select->add( $sock );

    while( 1 )
    {
        $sock->send( "+1\n" );
        my( $fh );
        next unless ( $fh ) = $select->can_read( 0.1 );
        next unless my @node = split /\n/, <$fh>;
        &$code( @node );
    }
}

1;
