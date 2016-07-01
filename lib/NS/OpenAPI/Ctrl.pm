package NS::OpenAPI::Ctrl;
use strict;
use warnings;
use Carp;

use JSON;
use Sys::Hostname;

use base qw( NS::OpenAPI );

our $URI = '/openapi/ctrl';


=head1 METHODS

=head3 pause( $step, $node, $info ) #ctrl='pause'
=head3 pause( $ctrl, $step, $node, $info )

Insert a record that cause stuck.

=cut

sub pause
{
    my ( $self, @info ) = @_;
    splice @info,0,0, 'pause' if @info == 3;
    $self->get( sprintf "$URI/pause/$self->{name}?ctrl=%s&step=%s&node=%s&info=%s", @info );
}


=head3 stuck( name, step )

Return records that cause @stage to be stuck. Return all records if @stage
is not defined.
stuck( )
stuck( step )
stuck( step, node )

=cut

sub stuck
{
    my ( $self, $step, $node ) = @_;
    @{$self->get( sprintf "$URI/stuck/$self->{name}?step=%s&node=%s", $step ||'', $node ||'' )};
}

=head3 resume( step, node )

Clear records that cause @stage to be stuck. Clear all records if @stage
is not defined.

resume( )
resume( step )
resume( step, node )

=cut

sub resume
{
    my ( $self, $step, $node ) = @_;
    $self->get( sprintf "$URI/resume/$self->{name}?step=%s&node=%s", $step ||'', $node ||'' );
}


=head3 exclude( $node, $info )

Exclude $node with a $info.

=cut

sub exclude
{
    my $self = shift;

    $self->get( sprintf "$URI/exclude/$self->{name}?%s", join '&', map{ "exclude=$_" }@_ );
}

=head3 excluded()

Return ARRAY ref of excluded nodes.

=cut

sub excluded
{
    my $self = shift;
    $self->get( "$URI/excluded/$self->{name}" );
}

=head3 clear()

clear all records. 

=cut
sub clear
{
    my $self = shift;
    $self->get( sprintf "$URI/clear/$self->{name}" );
}


sub dump
{
    my ( $self ) = @_;
    @{$self->get( sprintf "$URI/dump" )};
}

1;
