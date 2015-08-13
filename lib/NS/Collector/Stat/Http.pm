package NS::Collector::Stat::Http;

use strict;
use warnings;
use Carp;
use POSIX;

use LWP::UserAgent;

use Data::Dumper;

#retry:3:time:3|host:lvscheck.xitong.nices.net:http://localhost:8080

my %option = ( 'time' => 5, retry => 1 );

sub co
{
    my ( $this, @http, @stat, %http ) = shift;

    map{ $http{$1} = 1 if $_ =~ /^{HTTP}{([^}]+)}/ }@_;

    push @http, [ 'HTTP', 'code', 'is_success', 'status_line', 'cont' ];

    for ( keys %http )
    {
        my %opt = trans( $_ );

        my ( $url, $retry, $res )  =  map{ delete $opt{$_} }qw( url retry );

        my $ua = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0 } );
        $ua->agent('Mozilla/9 [en] (Centos; Linux)');
        
        $ua->timeout( $opt{time} );

        $ua->default_header ( 'Cache-control' => 'no-cache', 'Pragma' => 'no-cache', %opt );

        for( 1 .. $retry )
        {
            $res = $ua->get( $url );
            last if $res->is_success;
        }
        my $cont = $res->is_success ? $res->content : '';
        push @http, [ $_, $res->code, $res->is_success, $res->status_line, $cont ];

    }

    return \@http;
}

sub trans
{
    my ( $url, %opt ) = shift;
    if( $url =~ /^(.*)http(.+)/ )
    {
       %opt = split /:/, $1;
       $opt{url} = "http$2";
    }
    else { $opt{url} = "http://$url" }

    map{ $opt{$_} = $option{$_} unless $opt{$_} }keys %option;

    $opt{Host} = $opt{host} if $opt{host};
    return %opt;
}

1;
