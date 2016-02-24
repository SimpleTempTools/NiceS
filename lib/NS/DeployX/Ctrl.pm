package NS::DeployX::Ctrl;

use strict;
use warnings;
use Carp;
use File::Spec;
use Sys::Hostname;

our $TABLE='resources_deploy_ctrl';

sub new
{
    my ( $class, $name, $conn ) = splice @_;

    bless +{ name => $name, conn => $conn }, ref $class || $class;
}


=head1 METHODS

=head3 pause( $job, $stage, $stop, $ctrl = 'pause' )

Insert a record that cause stuck.

=cut

sub pause
{
    my ( $self, @info ) = @_;
    my ( $name, $conn ) = @$self{qw( name conn )};
    splice @info,0,0, 'pause' if @info == 3;
    $conn->do( sprintf "insert into $TABLE (`name`,`ctrl`,`step`,`node`,`info`) values ( '$name','%s','%s','%s','%s')", @info );

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
    my ( $name, $conn ) = @$self{qw( name conn )};
    my @where = ( "ctrl!='exclude'", "name='$name'" );
    push @where, "step='$step'" if $step;
    push @where, "node='$node'" if $node;
    my $r = $conn->exe( 
        sprintf "select * from $TABLE where %s", join ' and ', @where );

    return scalar @$r;
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
    my ( $name, $conn ) = @$self{qw( name conn )};
    my @where = ( "ctrl!='exclude'", "name='$name'" );
    push @where, "step='$step'" if $step;
    push @where, "node='$node'" if $node;
    my $r = $conn->exe( 
        sprintf "delete from $TABLE where %s", join ' and ', @where );

    return scalar @$r;
}


=head3 exclude( $node, $info )

Exclude $node with a $info.

=cut
sub exclude
{
    my $self = shift;
    my ( $name, $conn ) = @$self{qw( name conn )};

    map{ $conn->do( "insert into $TABLE (`name`,`ctrl`,`step`,`node`,`info`) values('$name','exclude','any','any','$_')" ) }@_;
}


=head3 excluded()

Return ARRAY ref of excluded nodes.

=cut
sub excluded
{
    my $self = shift;
    my ( $name, $conn ) = @$self{qw( name conn )};
    my $exc = $conn->exe( "select info from $TABLE where name='$name' and ctrl='exclude'" );
    return [ map { @$_ } @$exc ];
}


=head3 clear()

clear all records. 

=cut
sub clear
{
    my $self = shift;
    my ( $name, $conn ) = @$self{qw( name conn )};
    $conn->do( "delete from $TABLE where name='$name'" );
}

 
1;
