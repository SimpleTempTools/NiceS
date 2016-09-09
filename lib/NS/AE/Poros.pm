package NS::AE::Poros;
use NS::AE::Connect;
use AnyEvent::Handle;
use NS::Poros::Query;
use NS::Util::Logger qw(verbose info warning error debug);
use Data::Dumper;

use strict;
use warnings;


sub invoke
{
    my($host, $port, $query, $cb_suc, $cb_err, $condvar) = @_;
    my($handle, $buf);
    my $err = sub
    {
        my ($hdl, $fatal, $msg) = @_;
        warning "invoke error $host:$port",$msg;
        $cb_err->($msg) if $cb_err;
        $hdl->destroy if $hdl;
        $condvar->end if $condvar;
    };
    NS::AE::Connect::connect($host, $port,
        sub{
            $handle = shift;
            $handle->on_eof(sub{
                $cb_suc->($buf) if $cb_suc;
                $handle->destroy;
                $condvar->end if $condvar; 
            });
            $handle->push_write( $query );
            $handle->push_shutdown;
            $handle->on_read (sub { $buf .= $_[0]->rbuf; $_[0]->rbuf = ""; });
        },
        $err
    );
}
1;
