package NS::DeployX::Code;
use strict;
use warnings;
use Carp;

use Data::Dumper;

sub new
{
    my ( $class, $path, $conf, %code, %path ) = splice @_, 0, 3;

    _die( "no code path" ) unless $path && -d $path;
    _die( "no code conf" ) unless $conf &&  ref $conf eq 'ARRAY';

    map{ $path{$_->{code}} = "$path/$_->{code}"; }@$conf;

    for my $name ( keys %path )
    {
        $code{$name} = do "$path{$name}";
        _die( "load code $name error: $@" ) if $@;
        _die( "$path{$name} not CODE" ) if ref $code{$name} ne 'CODE';
    }

    bless \%code, ref $class || $class;
}

sub run
{
    my ( $this, $name,  %param ) = @_;
    &{$this->{$name}}( %param );
}

sub _die { printf "%s\n", shift; exit 114; }

1;
