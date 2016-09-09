package NS::AE::Connect;
use AnyEvent::Socket;
use AnyEvent::Handle;

use NS::Util::Socket;
use NS::Util::Logger qw(verbose info warning error debug);
use Data::Dumper;
use warnings;
use strict;

my %ERROR = 
(
    0 => "request granted",
    1 => "general failure",
    2 => "connection not allowed by ruleset",
    3 => "network unreachable",
    4 => "host unreachable",
    5 => "connection refused by destination host",
    6 => "TTL expired",
    7 => "command not supported / protocol error",
    8 => "address type not supported",
);
our $TIMEOUT = 40;

sub connect
{
    my($host, $port, $cb_suc, $cb_err) = @_;  

    my $proxy = NS::Util::Socket->new();
    my $socks = $proxy->string($host);
    my($phost, $pport);

    unless($socks)
    {
        debug "connect direct $host:$port";
        my $hdl; $hdl = new AnyEvent::Handle
        ( 
            connect    => [$host => $port], 
            timeout    => $TIMEOUT,
            on_timeout => sub{  $cb_err->(shift, 0, 'read/write timeout'); $hdl->destroy },
            on_error   => sub{  $cb_err->(@_); $hdl->destroy },
        );
        $cb_suc->( $hdl );
        debug "callback over $host:$port";
        return;
    }

    $cb_err->(undef, undef, "$socks parse error") and return unless ($phost, $pport) = $socks =~ /(.+):(.+)/;   

    debug "socks proxy: $phost:$pport";

    tcp_connect $phost => $pport, sub{
        my $fh = shift;
        unless($fh)
        {
            $cb_err->(undef, undef, "connect $phost $pport error");
            return; 
        }
        my $handle;$handle = new AnyEvent::Handle
        (
            fh         => $fh,
            timeout    => $TIMEOUT,
            on_timeout => sub{  $cb_err->(shift, 0, 'read/write timeout'); $handle->destroy },
            on_error   => sub{  $cb_err->(@_); $handle->destroy },
        );

        #socks5 ipv4 connect hand shake

        $handle->push_write(pack("CCC", 5, 1, 0));
        $handle->push_read(chunk => 2, sub {
            my($ver, $method) = unpack "CC", $_[1];

            debug "ver:", $ver;
            debug "method:", $method;

            $cb_err->(undef, undef, "socks proxy error") and return unless $ver == 5 && $method == 0;
            my $cmd;
            $cmd .= pack("CCCC", 5, 1, 0, 3);
            $cmd .= pack("C", length $host);
            $cmd .= $host;
            $cmd .= pack("n", $port);

            debug "$host|$port";

            $handle->push_write($cmd);
            $handle->push_read(chunk=>10, sub{
                my($ver, $reply, $rsv, $atyp, $ip, $port) = unpack "CCCCa4n", $_[1];
                debug "ver:", $ver, "reply:", $reply, "atyp:", $atyp, "ip:", $ip, "port:", $port;
                unless($ver == 5 && $reply == 0 && $atyp == 1)
                {
                    $cb_err->(undef, undef, "socks proxy error($ERROR{$reply})");
                    return ;
                }
                debug "hand shake suc!";
                $cb_suc->($handle);
            })
        });
    };
}
1;
