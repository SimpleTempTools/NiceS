package NS::Collector::Stat::IFace;

use strict;
use warnings;
use Carp;
use POSIX;

use Data::Dumper;

my $isvm;
BEGIN{
    $isvm = `dmidecode` =~ /No SMBIOS nor DMI entry point found, sorry\./ ? 1 : 0;
};


sub co
{
    my ( $this, @stat ) = shift;

    push @stat, [ qw( IFACE speed ) ];
    return \@stat if $isvm;
    my %eth = map { split /\s+/, $_, 2 } `ifconfig | grep ^eth`;

    for my $iface ( keys %eth )
    {
        my $info = `ethtool $iface | grep Speed`;
        push @stat, [ $iface, $info && $info =~ /:\s(\d+)\D+/ ? $1 : -1 ];
    }

    return \@stat;
}

1;
