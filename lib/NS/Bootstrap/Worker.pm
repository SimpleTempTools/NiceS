package NS::Bootstrap::Worker;
use strict;
use warnings;
use Carp;

use Fcntl;
use IPC::Open3;
use IO::Select;
use Symbol qw(gensym);
use Time::HiRes qw/time sleep/;
use Time::TAI64 qw/unixtai64n/;

use NS::Util::ProcLock;
use NS::Bootstrap;

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

    $NS::Bootstrap::time{$name} ||= 1;
    return if $NS::Bootstrap::time{$name} + 60 > time;
    $NS::Bootstrap::time{$name} = time;

    return if fork();
    exit if fork;

    exit if $plock->check();
    $plock->lock();

    $0 = "nices.bootstrap.worker.$name";

    our ( $logf, $logH ) = ( "$logs/current" );

    my($wtr, $rdr, $err, $mix );

    if( -f "$exec/$name" )
    {
        my @cont;
        map{ chomp $_;$_ =~ s/#.*//g; push @cont, $_ if $_; }`cat '$exec/$name'`;
        my $mark = pop @cont;
        $mix = 1 if $mark && $mark =~ /^\s*exec.+2>&1\s*$/;
    }

    $err = gensym;
    our $pid = IPC::Open3::open3( $wtr, $rdr, $err, "$exec/$name" );

    $SIG{'CHLD'} = sub { exit; };
    $SIG{USR1} = sub { confess "open log: $!" unless open $logH, ">>$logf"; };
    $SIG{TERM} = sub { unlink "$lock/$name.lock"; kill 'TERM', $pid; exit;};
    $SIG{INT} = sub { unlink "$lock/$name.lock"; kill 'INT', $pid; exit;};

    confess "open log: $!" unless open $logH, ">>$logf";
    $logH->autoflush;

    print $logH unixtai64n(time), " [$name] ". '[start]', "\n";

    if( $mix )
    {
        while(1)
        {
            while( <$rdr> )
            {
                unless( $_ ){ sleep 0.5; next; }
                print $logH unixtai64n(time), " [$name] [mix] ", $_;
            }
            sleep 6;
        }
    }
    else
    {
        #map{ _nonblock($_) }( $rdr, $err );
        my %info = ( $rdr => "[info]", $err => '[error]' );
        my $ios = IO::Select->new( $rdr, $err );
        while(1)
        {
            for my $h ( $ios->can_read() )
            { 
                my $rv = <$h>;
                unless( $rv ){ sleep 0.5; next; }
                print $logH unixtai64n(time), " [$name] ". $info{$h}||'[warn]',' ', $rv;
            }
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
