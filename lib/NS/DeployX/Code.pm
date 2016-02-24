package NS::DeployX::Code;
use strict;
use warnings;
use Carp;

use Data::Dumper;

sub new
{
    my ( $class, $path, $conf, %code ) = splice @_, 0, 3;

    confess "no code path" unless $path;
    confess "no code conf" unless $conf &&  ref $conf eq 'ARRAY';

    for ( @$conf )
    {
        my $name = $_->{code};
        $code{$name} = do "$path/$name";
        confess "load code $name error: $@" if $@;

        confess "$path/$name not CODE" if ref $code{$name} ne 'CODE';
    }

    bless \%code, ref $class || $class;
}

sub run
{
    my ( $this, $name,  %param ) = @_;
    &{$this->{$name}}( %param );
    
}
1;
