package NS::VSSH::OCMD::History;
use strict;
use warnings;
use Carp;

our @HISTORY;

sub new
{
    my ( $this, %this ) = @_;

    my ( $user, $path ) = @this{qw( user path )};

    my $history = sprintf "%s/%s.history", $path || '/tmp' , $user || 'unkown';

    confess "tie history fail: $history $!" unless tie @HISTORY, 'Tie::File', $history;

    bless +{}, ref $this || $this;
}

sub push
{
    my ( $this, @name ) = @_;
    push @HISTORY, @name;
}

sub list
{
    @HISTORY;;
}

1;
