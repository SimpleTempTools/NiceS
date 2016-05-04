package NS::Collector::Sock::Ring;

use warnings;
use strict;
use Carp;

use threads;
use Thread::Queue;
use Socket;
use IO::Select;

use NS::Util::Sysrw;
use YAML::XS;
use Thread::Semaphore;

use threads::shared;

our ( $DATA, $MUTEX, $RING ) 
    = ( Thread::Queue->new, Thread::Semaphore->new(), 300 );
use base 'NS::Collector::Sock';

our %EXC = ( TEST => 1, PS => 1 );
sub push
{
    my @data = @_;
    my $time = POSIX::strftime( "%Y-%m-%d_%H:%M:%S", localtime );
    @data = splice @data, 0, $RING if @data > $RING;

    $MUTEX->down();
    my $del = $DATA->pending + @data - $RING;
    if( $del > 0 )
    {
        warn "sock ring delete: $del\n";
        $DATA->dequeue( $del );
    }

    @data = map{ YAML::XS::Dump [$_,$time] } grep{ ! $EXC{$_->[0][0]} }@data;
    $DATA->enqueue( @data ) if @data;
    $MUTEX->up();
}

sub _server
{
    my ( $this, $socket ) = @_;
    $MUTEX->down();
    my $count = $DATA->pending;
    my @data = grep{ref $_} map{eval{ YAML::XS::Load $_}} $count ? $DATA->dequeue($count) : ();
    $MUTEX->up();
    NS::Util::Sysrw->write( $socket, YAML::XS::Dump \@data );
}

1;
