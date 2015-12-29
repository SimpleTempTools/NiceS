package NS::Collector::Sock;

use warnings;
use strict;
use Carp;

use threads;
use Thread::Queue;
use Socket;
use IO::Select;

use NS::Util::Sysrw;
use YAML::XS;

use threads::shared;

our $DATA:shared;

our %MAX = ( thread => 5,  maxconn => 5 );

sub new
{
    my ( $class, %this ) = @_;

    die "sock path undef" unless my $path = $this{path};
    unlink $path if -r $path;
    my $addr = sockaddr_un( $path );

    die "socket: $!" unless socket my $socket, PF_UNIX, SOCK_STREAM, 0;
    die "setsockopt: $!" unless setsockopt $socket, SOL_SOCKET, SO_REUSEADDR, 1;
    die "bind (path $path): $!\n" unless bind $socket, $addr;
    die "listen: $!\n" unless listen $socket, SOMAXCONN;

    $this{sock} = $socket;

    bless \%this, ref $class || $class;
}

sub run
{
    my $this = shift;

    my $select = new IO::Select( $this->{sock} );
    my @conn = map { Thread::Queue->new } 0 .. 1;
    my $status = "sock: status: \%s/$MAX{thread}\n";
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
    threads::async
    {
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
    
                if ( $conn[0]->pending > $MAX{maxconn} )
                {
                    close $client;
                    warn "connection limit reached\n";
                    next;
                }

                my $cfileno = fileno $client;
                
                $conn{$cfileno} = $client;
                printf $status, scalar keys %conn;
                $conn[0]->enqueue( $cfileno );
            }
        }
    }->detach();
}

sub _server
{
    my ( $this, $socket ) = @_;
    NS::Util::Sysrw->write( $socket, $DATA || '---' );
}

1;
