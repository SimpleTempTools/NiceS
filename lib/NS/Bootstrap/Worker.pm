package NS::Bootstrap::Worker;
use strict;
use warnings;
use Carp;

use Fcntl;
use IPC::Open3;
use IO::Select;
use Symbol qw(gensym);
use Time::HiRes qw/time/;
use Time::TAI64 qw/unixtai64n/;

use NS::Util::ProcLock;

my %RUN =( size => 10000, keep => 5 );

sub new
{
    my ( $class, %this ) = @_;
    map{ 
        confess "$_ undef" unless $this{$_};
        mkdir $this{$_} unless -d $this{$_};
    }qw( logs exec lock );
    bless \%this, ref $class || $class;
}

sub run
{
    my ( $this, %run ) = @_;
    my ( $logs, $exec, $lock ) = @$this{qw( logs exec lock )};

    confess "name undef" unless my $name = $run{name};

    my $plock = NS::Util::ProcLock->new( "$lock/$name.lock" );
    return if $plock->check();

    return if fork();
    exit if fork;

    $plock->lock();

    $0 = "nices.bootstrap.worker.$name";

    our ( $logf, $logH ) = ( "$logs/current" );

    my($wtr, $rdr, $err);
    $err = gensym;
    our $pid = IPC::Open3::open3( $wtr, $rdr, $err, "$exec/$name" );
    map{ _nonblock($_) }( $rdr, $err );
    my $ios = IO::Select->new( $rdr, $err );

    $SIG{'CHLD'} = sub { exit; };
    $SIG{USR1} = sub { confess "open log: $!" unless open $logH, ">>$logf"; };
    $SIG{TERM} = sub { unlink "$lock/$name.lock"; kill 'TERM', $pid; exit;};
    $SIG{INT} = sub { unlink "$lock/$name.lock"; kill 'INT', $pid; exit;};

    confess "open log: $!" unless open $logH, ">>$logf";
    $logH->autoflush;

    print $logH unixtai64n(time), " [$name] ". '[start]', "\n";

    my %info = ( $rdr => "[info]", $err => '[error]' );
    while(1)
    {
        for my $h ( $ios->can_read() )
        { 
            my $rv = <$h>;
            next unless $rv;
            print $logH unixtai64n(time), " [$name] ". $info{$h}||'[warn]',' ', $rv;
        }
    }
    exit;
}

sub _nonblock {
  my $fh = shift;
  my $flags = fcntl($fh, F_GETFL, 0)
        or croak "Can't get flags for filehandle $fh: $!";
  fcntl($fh, F_SETFL, $flags | O_NONBLOCK)
        or croak "Can't make filehandle $fh nonblocking: $!";
}

1;
