package NS::DeployX::Lock;

=head1 NAME

NS::Util::ProcLock - Advisory lock using a regular file

=head1 SYNOPSIS

 use NS::Util::ProcLock;

 my $lock = NS::Util::ProcLock->new( '/lock/file' );

 if ( my $pid = $lock->check() )
 {
     print "Locked by $pid.\n";
 }

 $lock->lock();
 
=cut
use strict;
use warnings;
use Carp;
use File::Spec;
use Sys::Hostname;

sub new
{
    my ( $class, $name, $conn ) = splice @_;

use Data::Dumper;
print Dumper $name;
    bless +{ name => $name, conn => $conn }, ref $class || $class;
}

=head1 METHODS

=head3 check()

Returns PID of owner, undef if not locked.

=cut

sub check
{
    my $self = shift;
    my ( $name, $conn ) = @$self{qw( name conn )};
    my $r = $conn->exe( "select `host`,`pid` from resources_deploy_lock where name='$name'" );
    return ( $r && ref $r eq 'ARRAY' ) ? @{$r->[0]} : undef;
}

=head3 lock()

Attempts to acquire lock. Returns pid if successful, undef otherwise.

=cut
sub lock
{
    my $self = shift;
    my ( $name, $conn ) = @$self{qw( name conn )};
    eval{ $conn->do( 
        sprintf "insert into resources_deploy_lock (`name`,`host`,`pid`) values('$name','%s','$$')", hostname );
    };
    
    return $@ ? 0 : 1;
}

sub unlock
{
    my $self = shift;
    my ( $name, $conn ) = @$self{qw( name conn )};
    $conn->do( 
        sprintf "delete from resources_deploy_lock where name='$name' and host='%s'", hostname );
}


 
1;
