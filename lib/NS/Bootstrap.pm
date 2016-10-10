package NS::Bootstrap;
use strict;
use warnings;
use Carp;
use YAML::XS;

use File::Basename;
use NS::Util::ProcLock;
use NS::Bootstrap::Worker;
use POSIX qw( :sys_wait_h );

my %RUN =( size => 10000000, keep => 5 );
our %time;

sub new
{
    my ( $class, %this ) = @_;
    map{ 
        confess "$_ undef" unless $this{$_};
        system "mkdir -p '$this{$_}'" unless -d $this{$_};
    }qw( logs exec lock );
    bless \%this, ref $class || $class;
}

sub run
{
    my ( $this, %run ) = @_;

    our ( $logs, $exec, $lock ) = @$this{qw( logs exec lock )};
    my $proclock = NS::Util::ProcLock->new( "$lock/lock" );
   
    if ( my $pid = $proclock->check() )
    {
        print "master locked by $pid.\n" if $ENV{NS_DEBUG};
        exit;
    }
   
    $proclock->lock();
    $0 = 'nices.bootstrap.master';

    my $i = 590;
    $SIG{'CHLD'} = sub { 1 while waitpid(-1, WNOHANG) > 0; };

    $SIG{KILL} = $SIG{INT} = $SIG{TERM} = sub { 
        unlink "$lock/lock";

        my %name; map{ $name{"$_.lock"} = 1 }map{ basename $_ } glob "$exec/*";  

        for( map{ basename $_ }glob "$lock/*.lock" )  
        {
            unlink "$lock/$_" unless $name{$_};
        }
        exit;
    };

    my $worker = NS::Bootstrap::Worker->new( %$this );

    while( $i++ )
    {
        sleep 6;
        my @name = map{ basename $_ }glob "$exec/*";

        unless( $i % 3 )
        {
            if( my $size= ( stat "$logs/current" )[7] )
            {
                if( $size > $RUN{size} )
                {
                    my $num = $this->_num();
                    system "mv '$logs/current' '$logs/log.$num'";
	            map{ $this->kill( $_ ) }@name;
                }
            }
            else { map{ $this->kill( $_ ) }@name; }
        }
        unless( $i % 600 )
        {
            map{ $this->kill( $_ ) }@name;
        }
        for my $name ( @name )
        {
            $worker->run( name => $name )
        }
    }
    return $this;
}

sub _num
{
    my ( $logs, %time )= shift->{logs};
    for my $num ( 1 .. $RUN{keep} )
    {
       return $num unless $time{$num} = ( stat "$logs/log.$num" )[10];
    }
    return ( sort{ $time{$a} <=> $time{$b} } keys %time )[0];
}

sub kill
{
    my ( $this, $name, $SIGNAL ) = @_;
    my $lock = $this->{lock};

    my $plock = NS::Util::ProcLock->new( "$lock/$name.lock" );
    return unless my  $pid = $plock->check();
    return unless $pid =~ /^\d+$/;
    return unless my $cmdline = `cat '/proc/$pid/cmdline'`;
    chomp $cmdline;
    return unless $cmdline eq "nices.bootstrap.worker.$name";

    $SIGNAL ||= 'USR1';
    kill $SIGNAL, $pid;
}
1;
