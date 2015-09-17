package NS::Util::Debug;

use warnings;
use strict;

use Data::Dumper;

sub dump
{
    my $class = shift;
    print Dumper @_ if $ENV{NS_DEBUG};
}

1;
