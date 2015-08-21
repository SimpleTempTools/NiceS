package NS::Util::Sudo;

=head1 NAME

NS::Util::Sudo - Become a user by setting uid or invoking sudo

=cut
use warnings;
use strict;

use Carp;
use POSIX;

=head1 SYNOPSIS

 use NS::Util::Sudo;

 NS::Util::Sudo->sudo( 'joe' );

=head1 Methods

=head3 sudo( $user )

Become $user ( default root ). 

=cut
sub sudo
{
    my ( $class, $user ) = splice @_;
    my $me = ( getpwuid $< )[0];

    return $user if $me eq ( $user ||= 'root' ) 
        || POSIX::setuid( ( getpwnam $user )[2] );

    warn "$me: need '$user' privilege, invoking sudo.\n";
    confess "exec $0: $!" unless exec 'sudo', '-u', $user, $0, @ARGV;
}

1;
