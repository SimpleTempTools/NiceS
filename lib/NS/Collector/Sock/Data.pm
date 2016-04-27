package NS::Collector::Sock::Data;

use warnings;
use strict;
use Carp;

use threads;
use Thread::Queue;
use Socket;
use IO::Select;

use NS::Util::Sysrw;
use YAML::XS;

use threads::shared;

our $DATA:shared;
use base 'NS::Collector::Sock';


sub _server
{
    my ( $this, $socket ) = @_;
    NS::Util::Sysrw->write( $socket, $DATA || '---' );
}

1;
