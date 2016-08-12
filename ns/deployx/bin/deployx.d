#!/home/s/ops/perl/bin/perl
use strict;
use warnings;
use POSIX;
use Sys::Hostname;
use FindBin qw( $RealBin );

use NS::Util::OptConf;
use NS::OpenAPI::Deploy;
use NS::OpenAPI::UMesg;

$| ++;
$NS::Util::OptConf::THIS = 'deployx';

my @argv = @ARGV;
my %o = NS::Util::OptConf->load()->get( qw( check unlog main=s conf=s myid=s user=s ) )->dump();

unless( $o{myid} )
{
    $o{myid} = POSIX::strftime( "%Y-%m-%d_%H:%M:%S", localtime );
    push @argv, '--myid', $o{myid};
}

my $name = shift;
my $openapi = NS::OpenAPI::Deploy->new( name => $name );
my $umesg   = NS::OpenAPI::UMesg->new();

open( my $LOG, ">> $o{logs}/$name.$o{myid}" ) || die( "can't open logfile:  $!" );
sub pp { print @_;print $LOG @_; }

$openapi->myid( $o{myid} => hostname );
$umesg->deploymesg( symbol => $o{myid}, deploy =>$name, info => "$name:$o{myid} start" );
$umesg->deploystat( name =>$name,  mark => $o{myid}, stat => 'running' );

my ( $exec, $error, $done )= sprintf "$RealBin/deployx %s", join ' ', @argv;

$ENV{DEPLOYD} = 1;

my %code =
(
    110 => 'already running',
    111 => 'old myid still running',
    112 => 'deploy killed',
    113 => 'title redef',
    114 => 'load code error',
    115 => 'load conf error',
);

while( 1 )
{
    for( 1 .. 9 )
    {
        warn "$exec\n";
        system $exec;
    
        if( $? == -1 )
        {
            pp( "failed to execute: $!\n" );
        }
        elsif ( $? & 127 )
        {
            pp( sprintf "child died with signal %d, %s coredump\n",
                ( $? & 127 ), ( $? & 128 ) ? 'with' : 'without' );
        }
    
        my $exit = $? >> 8;
        pp( "exit: $exit\n" );

        unless( $exit )
        { 
            $done = 1; 
            last;
        }
        elsif( $error = $code{$exit} )
        {
            $done = 1;
            last;
        }

        sleep 0.5;
    }

    last if $done;
    pp( "after 15 seconds, deployx.d tries to wake up deployx" );
    sleep 15;
}

pp( "$error\n" ) if $error;

$umesg->deploystat( name =>$name,  mark => $o{myid}, stat => $error ? 'error': 'done' );

$umesg->deploymesg( 
    symbol => $o{myid}, 
    deploy =>$name, 
    info => sprintf "$name:$o{myid} %s", $error || 'finish'
);

close $LOG;
