package NS::DeployX::Cache;

use strict;
use warnings;
use Carp;
use POSIX;
use File::Spec;
use Sys::Hostname;

use NS::OpenAPI::Deploy;

sub new
{
    my ( $class, $name ) = splice @_;

    my $self = bless +{ 
        name => $name,
        oapi => NS::OpenAPI::Deploy->new( name => $name )
    }, ref $class || $class;

    $self->_mark( +{ curr => $self->{mark} = POSIX::strftime( "%Y-%m-%d_%H:%M:%S", localtime )} ) 
        unless $self->{mark} = $self->_mark();

    return $self;
}

sub _mark
{
    my ( $this, $mark ) = @_;
    $mark ? $this->{oapi}->mark( $mark ) : $this->{oapi}->mark()->{curr};
}

sub cache
{
    my ( $this, $data ) = @_;
    $data ? $this->{oapi}->logs( $this->{mark}, $data ) : $this->{oapi}->logs( $this->{mark} );
}

sub clear
{
    shift->{oapi}->mark( +{} );
}

1;
