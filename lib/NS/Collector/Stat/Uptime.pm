package NS::Collector::Stat::Uptime;

use strict;
use warnings;
use Carp;
use POSIX;

use Data::Dumper;

sub co
{
    my ( $this, @stat ) = shift;

    push @stat, [ qw( UPTIME time uptime idle )];
    push @stat, [ 'value', time, split /\s+/, `cat /proc/uptime`  ];

    return \@stat;
}

1;
