package NS::Collector::Stat::Exec;

use strict;
use warnings;
use Carp;
use POSIX;

sub co
{
    my ( $this, @exec, @stat, %exec ) = @_;

    push @stat, [ 'EXEC', 'exit', 'stdout' ];

    map{ $exec{$1} = 1 if $_ =~ /^{EXEC}{([^}]+)}/ }@exec;

    for my $exec ( keys %exec )
    {
        my $stdout = `$exec`;
        my $exit = $? == -1 ? -1 : $? >> 8;
        push @stat, [ $exec, $exit, $stdout||'' ];
    }

    return \@stat;
}

1;
