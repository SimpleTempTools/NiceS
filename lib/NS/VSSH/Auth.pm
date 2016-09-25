package NS::VSSH::Auth;
use warnings;
use strict;
use Carp;

use Expect;
use YAML::XS;
use Term::ReadPassword;

our $passwd;

sub new
{
    my ( $class, %self ) = @_;
    confess "undef user" unless $self{user};
    bless \%self, ref $class || $class;
}

sub checkpw
{
    my $user = shift->{user};

    return 1 if $passwd = $ENV{PASSWD};

    for( 1 .. shift )
    {
        my $pw = read_password( "$user\'s password: " );

        my $exp = Expect->new();
        $exp->spawn( "ssh -o NumberOfPasswordPrompts=1 -l $user 127.0.0.1 date" );
        
        my @status = $exp->expect
            (
                3,
                [ qr/(yes\/no)/ => sub { $exp->send( "yes\n" ); exp_continue; } ],
                [ qr/[Pp]assword/ => sub { $exp->send( "$pw\n" ); exp_continue; } ],
                [ qr/[Pp]ermission denied/ => sub { $exp->send( "$pw\n" );return; } ],
            );
        $exp->hard_close();

        if( $status[1] && $status[1] =~ /exited with status 0/ )
        {
            $passwd = $pw;
            return 1;
        }
    }
    return 0;
}

sub loadpw
{
    my $user = shift->{user};

    $passwd = $ENV{PASSWD} ||  read_password( "$user\'s password: " );
    return 1;
}
1;
