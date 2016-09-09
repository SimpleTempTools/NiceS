package NS::AE::SSH;
use NS::AE::Connect;
use AnyEvent::Handle;
use NS::Util::Logger qw(verbose info warning error debug);

use strict;
use warnings;


sub invoke
{
    my($host, $port, $cb_suc, $cb_err, $condvar) = @_;

    my $err = sub
    {
        my($hdl, $fatel, $msg) = @_;
        $cb_err->($msg) if $cb_err;
        $condvar->end if $condvar;
        $hdl->destroy if $hdl;
    }; 
    my $handle;
    NS::AE::Connect::connect($host, $port,
        sub{
            $handle = shift;
            $handle->on_eof($err);
            $handle->push_read(line => sub {
                my ($hdl, $line) = @_;
                $cb_suc->($line) if $cb_suc;
                $condvar->end if $condvar;
                $hdl->destroy if $hdl;
            });
        },
        $err
    );
}


1;
