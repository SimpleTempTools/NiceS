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

our %MAX = 
(
    listen => 50, 
    thread => 1,  
    maxconn => 300, 
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
    die "listen: $!\n" unless listen $socket, $MAX{listen};

    $this{sock} = $socket;

    die "no file:$this{'exec'}\n" unless $this{'exec'} && -e $this{'exec'};

    bless \%this, ref $class || $class;
}

sub run
{
    my $this = shift;

    my $select = new IO::Select( $this->{sock} );
    my @conn = map { Thread::Queue->new } 0 .. 1;
    my $status = "tcpserver: status: \%s/$this->{thread}\n";
    printf $status, 0;

    map
    {
        threads::async
        {
            while ( my $fileno = $conn[0]->dequeue() )
            {
                if( open my $client, '+<&=', $fileno )
                {
                    $this->_server( $client );
                    close $client;
                }

                $conn[1]->enqueue( $fileno );
            }
        }->detach()
    } 1 .. $MAX{thread};

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

            if ( $conn[0]->pending > $MAX{maxconn} )
            {
                close $client;
                warn "connection limit reached\n";
            }
            
            $conn{$cfileno} = $client;
            printf $status, scalar keys %conn;
            $conn[0]->enqueue( $cfileno );
        }
    }
}

sub _server
{
    my ( $this, $socket ) = @_;

    my ( $IN, $OUT, $buffer );
    my $childpid = open2($OUT, $IN, $this->{'exec'} );

    while( NS::Util::Sysrw->read( $socket, $buffer, $MAX{maxbuf} ) )
    {
        print $IN $buffer;
    }
    close( $IN );

    waitpid( $childpid, 1 );

    my @out; while( <$OUT>) { push @out, $_; }

    NS::Util::Sysrw->write( $socket, join '', @out);
}


1;

