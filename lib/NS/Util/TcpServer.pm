package NS::Util::TcpServer;

use warnings;
use strict;
use Carp;

use threads;
use Thread::Queue;
use Socket;
use IO::Select;

use NS::Util::Sysrw;
use IPC::Open2;
use POSIX ":sys_wait_h";

our %RUN = 
(
    maxcon => 10,
    listen => 10, 
    maxbuf => 2 ** 12,
);

sub new
{
    my ( $class, %this ) = @_;

    my $port = $this{port};
    my $addr = sockaddr_in( $port, INADDR_ANY );

    die "socket: $!" unless socket my $socket, PF_INET, SOCK_STREAM, 0;
    die "setsockopt: $!"
        unless setsockopt $socket, SOL_SOCKET, SO_REUSEADDR, 1;
    die "bind (port $port): $!\n" unless bind $socket, $addr;
    die "listen: $!\n" unless listen $socket, $RUN{listen};

    $this{sock} = $socket;

    die "no file:$this{'exec'}\n" unless $this{'exec'} && -e $this{'exec'};

    bless \%this, ref $class || $class;
}

sub run
{
    my $this = shift @_;
    my %run = ( %RUN, @_);
    return $run{thread} ?  $this->thread( %run ) : $this->proc( %run );
}

sub proc
{
    my ( $this, %run ) = @_;

    my $select = new IO::Select( $this->{sock} );
    my $status = "tcpserver: status: \%s/$run{maxcon}\n";
    printf $status, 0;

    our %pid;
    $SIG{'CHLD'} = sub {
        while((my $pid = waitpid(-1, WNOHANG)) >0)
        {
            delete $pid{$pid};
        }
        printf $status, scalar keys %pid;
    };


    while ( 1 )
    {
        if ( my ( $server, $client ) = $select->can_read( 0.5 ) )
        {
            accept $client, $server;

            if( keys %pid > $run{maxcon} )
            {
                close $client;
                warn "connection limit reached\n";
            }
            elsif( my $pid = fork() )
            {
                $pid{$pid}=1;
                printf $status, scalar keys %pid;
            }
            else
            {
                my $cfileno = fileno $client;
                open my $client, '+<&=', $cfileno;
                $this->_server( $client, _addr( $client ) );
                close $client;
                exit;
            }
        }
    }
}

sub thread
{
    my ( $this, %run ) = @_;

    my $select = new IO::Select( $this->{sock} );
    my @conn = map { Thread::Queue->new } 0 .. 1;
    my $status = "tcpserver: status: \%s/$run{maxcon}\n";
    printf $status, 0;

    map
    {
        threads::async
        {
            while ( my ( $fileno, $ip, $port ) = $conn[0]->dequeue(3) )
            {
                if( open my $client, '+<&=', $fileno )
                {
                    $this->_server( $client, $ip, $port );
                    close $client;
                }

                $conn[1]->enqueue( $fileno );
            }
        }->detach()
    } 1 .. $run{maxcon};


    my %conn;
    while ( 1 )
    {
        while ( my $count = $conn[1]->pending )
        {
            map { delete $conn{$_} } $conn[1]->dequeue( $count );
            printf $status, scalar keys %conn;
        }

        if ( my ( $server, $client ) = $select->can_read( 0.5 ) )
        {
            accept $client, $server;
            my $cfileno = fileno $client;

            if ( $conn[0]->pending > $run{maxcon} )
            {
                close $client;
                warn "connection limit reached\n";
            }
            else
            {
                $conn{$cfileno} = $client;
                printf $status, scalar keys %conn;
                $conn[0]->enqueue( $cfileno,  _addr( $client ) );
            }
        }
    }
}

sub _server
{
    my ( $this, $socket, $ip, $port ) = @_;

    my ( $IN, $OUT, $buffer );

    my $childpid = open2($OUT, $IN, "TCPREMOTEIP=$ip TCPREMOTEPORT=$port $this->{'exec'}" );

    while( NS::Util::Sysrw->read( $socket, $buffer, $RUN{maxbuf} ) )
    {
        print $IN $buffer;
    }
    close( $IN );

    waitpid( $childpid, 1 );

    my @out; while( <$OUT>) { push @out, $_; }

    NS::Util::Sysrw->write( $socket, join '', @out);
}

sub _addr
{
    my $remote_sockaddr = getpeername( shift );
    my $family = sockaddr_family($remote_sockaddr);

    my ( $iport, $iaddr ) = $remote_sockaddr
                            ? ( ($family == AF_INET6) ? sockaddr_in6($remote_sockaddr)
                                                      : sockaddr_in($remote_sockaddr) )
                            : (undef,undef);

    my $loopback = ($family == AF_INET6) ? "::1" : "127.0.0.1";
    my $peeraddr = $loopback;
    if ($iaddr) {
        my ($host_err,$addr, undef) = Socket::getnameinfo($remote_sockaddr,Socket::NI_NUMERICHOST);
        warn ($host_err) if $host_err;
        $peeraddr = $addr || $loopback;
    }
    $peeraddr = '0.0.0.0' unless $peeraddr && $peeraddr =~ /^\d+\.\d+\.\d+\.\d+$/;
    $iport = '0' unless $iport && $iport =~ /^\d+$/;
    return ( $peeraddr, $iport );
}

1;

