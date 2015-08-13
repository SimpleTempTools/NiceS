package NS::Collector::Stat::Sar;
use strict;
use warnings;
use Carp;
use POSIX;

sub co
{
    local $/ = "\n";

    my ( $interval, $flip, $flop, @data, @stat, $cmd ) = -t STDIN ? 1 : 6;

    eval{
        confess "open: $!" unless open $cmd, "sar -A $interval 1 |";
    };

    return () if $@;
    

    while ( my $line = <$cmd> )
    {
        $flop = $flip if $flip = $line =~ s/^Average:\s+//;
        next unless $flop;

        if ( length $line > 1 ) { push @data, [ split /\s+/, $line ] }
        else { $flop = $flip; push @stat, [ splice @data ] }
    }

    push @stat, [ splice @data ] if @data;

    return @stat;
}

1;
