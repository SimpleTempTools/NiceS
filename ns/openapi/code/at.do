#!/home/s/ops/perl/bin/perl
use FindBin qw( $RealBin );
use Time::HiRes qw( sleep );
use LWP::UserAgent;
use NS::OpenAPI::At;
use threads;

map{ die "at.do ARGV err" unless $ARGV[$_] }0..3;

my ( $id, $callback, $channel, $code, @param ) = @ARGV;
die "argv format error" unless 
     $id =~ /^\d+$/ 
  && $callback =~ /^[:\.\/\w]+$/ 
  && $channel =~ /^[\w_\.]+$/ 
  && $code =~ /^[\w_]+$/;

die "no code" unless -x "$RealBin/at/$code";
map{ die "at.do param error" unless $_ =~ /^[=\w_\.]+$/ }@param;

exit if fork;

my $openapi = NS::OpenAPI::At->new( id => $id );

open (STDOUT, ">$RealBin/../data/at/$id") || die ("open STDOUT failed");
open (STDERR, ">&STDOUT") || die ("open STDERR failed");

my ( $timeout, $time ) = ( 86400, time );
sub usetime
{
    my $use = time - $time;
    return sprintf "%02d:%02d:%02d", 
        reverse map{ my $v = $use % 60; $use = int( $use / 60 ); $v } 0 .. 2;
}

threads::async{
     $openapi->stat( "pid:$$" );
     while(1)
     {
         $openapi->use( usetime() );
         sleep 30;
         last if time - $time > $timeout;
     }
     $openapi->stat( "timeout" );
}->detach();

$0="at.do=$id";

my $stat = system "ATID=$id $RealBin/at/$code @param";
$openapi->use( usetime() );
$openapi->stat( "done" );
$openapi->code( $stat );

if( $callback ne 'null' )
{
    print "callback $callback";
    my $ua = LWP::UserAgent->new();
    $ua->agent('Mozilla/9 [en] (Centos; Linux)');
    $ua->timeout( 10 );

    my $s;
    for( 1..3 )
    {
        my $res =  $ua->post( $callback, 
            id => $id,
            channel => $channel,
            result => `cat "$RealBin/../data/at/$id"`||''
        );

        $s = $res->is_success ? "done" : "fail";
        last if $res->is_success;
    }
    $openapi->cbstat( $s );
}
