package NS::Collector::Stat::IFace;

use strict;
use warnings;
use Carp;
use POSIX;

use Data::Dumper;

sub co
{
    my ( $this, @stat ) = shift;

    push @stat, [ qw( IFACE speed ) ];
    my %eth = map { split /\s+/, $_, 2 } `ifconfig | grep ^eth`;

    for my $iface ( keys %eth )
    {
        my $info = `ethtool $iface | grep Speed`;
        push @stat, [ $iface, $info && $info =~ /:\s(\d+)\D+/ ? $1 : -1 ];
    }

    return \@stat;
}

1;
