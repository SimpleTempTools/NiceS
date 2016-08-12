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

    $self->{mark} = $self->_mark();        

    return $self;
}

sub _mark
{
    my ( $this, $mark ) = @_;
    $mark ? $this->{oapi}->mark( $mark ) : $this->{oapi}->mark()->{curr};
}

sub mark { shift->{mark}; }
sub rnew
{
    my ( $this, $main, $conf, $myid, $user ) = @_;
    unless( $this->{mark} )
    {
        $this->_mark( 
            +{ 
                user => $user,
                curr => $this->{mark} = 
                ( $myid && $myid =~ /^\d{4}-\d{2}-\d{2}_\d{2}:\d{2}:\d{2}$/ )
                ? $myid : POSIX::strftime( "%Y-%m-%d_%H:%M:%S", localtime ) } 
        );
        $this->{oapi}->cache( $this->{mark}, 'main', $main );
        $this->{oapi}->cache( $this->{mark}, 'conf', $conf );
    }
    else
    {
        return undef if $myid && $this->{mark} ne $myid;
    }

    return $this;
}

sub set_sc
{
    my $this = shift;
    $this->{sc} = shift;
    $this;
}

sub sc
{
    my ( $this, %data ) = @_;
    $this->{oapi}->sc( $this->{sc}, \%data );
}

sub cache
{
    my ( $this, $data ) = @_;
    $data ? $this->{oapi}->logs( $this->{mark}, $data ) 
          : $this->{oapi}->logs( $this->{mark} );
}

sub clear
{
    shift->{oapi}->mark( +{} );
}

1;
