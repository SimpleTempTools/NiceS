package NS::VSSH;

use strict;
use warnings;
use NS::VSSH::Execute;
use NS::VSSH::Comp;
use NS::VSSH::History;
use NS::VSSH::Print;

$|++;

sub new
{
    my ( $class, %self ) =  @_;

    $self{config} = +{ };

    bless \%self, ref $class || $class;
}

sub run
{
    my ( $this, %busy ) = shift;
 
    my $history = NS::VSSH::History->new();
    my $execute = NS::VSSH::Execute->new( node => $this->{node} );
    my $print = NS::VSSH::Print->new();
    $print->welcome();

    while ( 1 )
    {
	next unless my $cmd = $this->_comp();
        exit if $cmd eq 'exit' || $cmd eq 'quit' ||  $cmd eq 'logout';
   
        my %result = $execute->run( cmd => $cmd );
        $print->result( %result );

        $history->push( $cmd );
    }
}

sub _comp
{
    my $self = shift;
    my $tc = NS::VSSH::Comp->new(
        'clear'  => qr/\cl/,
        'reverse'  => qr/\cr/,
        'wipe'  => qr/\cw/,
         prompt => "nices sh#",
         choices => [ ],
         up       => qr/\x1b\[[A]/,
         down     => qr/\x1b\[[B]/,
         left     => qr/\x1b\[[D]/,
         right    => qr/\x1b\[[C]/,
         quit     => qr/[\cc]/,
    );
    my ( $cmd, $danger ) = $tc->complete();
    return $cmd unless $danger;
    while( 1 )
    {
        print "$cmd [y/n]:";
        my $in = <STDIN>;
        next unless $in;
        return $cmd if $in eq "y\n";
        return undef if $in eq "n\n";
    }
}

1;
