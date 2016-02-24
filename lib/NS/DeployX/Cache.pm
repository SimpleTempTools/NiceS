package NS::DeployX::Cache;

use strict;
use warnings;
use Carp;
use File::Spec;
use Sys::Hostname;

our $TABLE='resources_deploy_cache';

sub new
{
    my ( $class, $name, $conn ) = splice @_;

    bless +{ name => $name, conn => $conn }, ref $class || $class;
}


sub clear
{
    my $self = shift;
    my ( $name, $conn ) = @$self{qw( name conn )};
    $conn->do( "delete from $TABLE where name='$name'" );
}

 
1;
