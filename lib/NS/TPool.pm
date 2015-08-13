package NS::TPool;
use strict;
use warnings;

use Carp;
use YAML::XS;
use Digest::MD5;
use NS::Util::OptConf;

use Sys::Hostname;
use NS::Hermes;

use threads;
use Thread::Queue;
use Time::HiRes qw( time sleep alarm stat );

use Tie::File;
use Data::Dumper;

use NS::Util::NSStat;

$|++;

sub new
{
    my ( $class, %param ) = @_;
   
    map{ die "$_ undef" unless $param{$_}  }qw( name conf code );

    my $conf = eval{ YAML::XS::LoadFile "$param{conf}/$param{name}" };
    confess "load conf fail: $@\n" if $@;

    map{ die "$_ undef in conf\n" unless $conf->{$_} }qw( batch task interval thread );

    map
    {
        die "$_ code undef" unless $conf->{$_}{code};

        $conf->{$_}{code} = do "$param{code}/$conf->{$_}{code}";

        confess "load $_ code fail:$@" 
            unless  $conf->{$_}{code} && ref  $conf->{$_}{code} eq 'CODE';
    }qw( batch task );

    bless +{ conf => $conf, name => $param{name} }, ref $class || $class;
}

sub run
{
    my $this = shift;
    my ( $conf, $name ) = @$this{ qw( conf name )};
    my ( $task, $interval, $thread, $batch, $timeout ) 
        = @$conf{qw( task interval thread batch timeout )};

    $timeout ||= $interval;
    my $statw = NS::Util::NSStat->new( name => "ns.monitor.pool.$name" );

    my @queue = map{ Thread::Queue->new() } 0 .. 2;

    $SIG{ALRM} = sub{ die "code timeout."; };
    map{
         threads::async{
             while ( 1 ) {
                 my ( $ID, $node ) = $queue[0]->dequeue( 2 );
                 next unless defined $node;
                 print "run: $node\n";
                   
                 my $stat;
                 eval{
                     alarm $timeout;
                     $stat = &{$task->{code}}( 
                         node => $node, param => $task->{param} 
                     );
                     alarm 0;
                 };
                 alarm 0;
                 warn "code error: $node $@\n" if $@;
                 $queue[1]->enqueue( $ID , $stat ? 1 : 0 );
             }
         }->detach();
    } 1 .. $thread;

    threads::async{
        my $last_count = 0;
        
        for ( my $i = 0, my $time = time; $time = time ; $i++  ) {
            my @node = eval{ &{$batch->{code}}( %{$batch->{param}} ) };
    
            
            printf "batch: done. node: %d\n", scalar @node;
            my $pending = $queue[0]->pending();
 
            print "nodeold: $last_count pending: $pending\n";

            if( ( $last_count * 2 ) < $pending )
            {
                $statw->write( 'error' => 'queue too long' );
                sleep $interval;
                next;
            }

            my $timeout = $time + $timeout;
            my @data; map{ push @data, "$_##$i", $_ }@node;
            my @time; map{ push @time, "$_##$i", $timeout }@node;
            $queue[0]->enqueue( @data );
            $queue[2]->enqueue( @time );

            $last_count = @node;
            sleep $interval;
        }
    }->detach();

    my %task;
    for( my $now; $now = time; )
    {
        print "RUN..\n";

        while ( $queue[2]->pending() )
        {
            my ( $task, $time ) = $queue[2]->dequeue_nb( 2 );
            $task{$task} = $time;
        }

        my ( $stat, %fail ) = 0;
        while ( $queue[1]->pending() )
        {
            my ( $task, $stat ) = $queue[1]->dequeue_nb( 2 );
            $fail{$task} = 'fail' unless $stat;
            delete $task{$task};
        }

        my %timeout = map{ $_ => 'timeout' }grep{ $task{$_} < time }keys %task;

        if( %timeout )
        {
            $statw->write( 'error' => sprintf "timeout: %s", scalar keys %timeout );
            print Dumper \%timeout; 
            $stat = 1;
        }
        if( %fail )
        {
            $statw->write( 'error2' => sprintf "fail: %s", scalar keys %fail );
            print Dumper \%fail;
            $stat = 1;
        }
 
        $statw->write( stat => $stat );
	sleep 1;
    }
}

1;
