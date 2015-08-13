package NS::VSSH::CheckPw;

use warnings;
use strict;

use YAML::XS;
use Net::SSH::Perl;
use Term::ReadPassword;
use Expect;
use NS::VSSH::Constants;

sub check
{
    my ( $user, $passwd, $status ) = splice @_, 0, 2;
    return unless $user && $passwd;
    local $SIG{ALRM} = sub { die 'timeout' };
    eval{
        alarm 5;

        my $exp = Expect->new();
        $exp->spawn( "ssh -l $user 127.0.0.1 date" );
        ( undef, $status ) = $exp->expect
            (
                3,
                [ qr/(yes\/no)/ => sub { $exp->send( "yes\n" ); exp_continue; } ],
                [ qr/[Pp]assword/ => sub { $exp->send( "$passwd\n" ); exp_continue; } ],
                [ qr/[Pp]ermission denied/ => sub { $exp->send( "$passwd\n" );$status =1;return; } ],
            );

        $status = ( $status && $status =~ /exited with status 0/ ) ? 0 : 1;
        $exp->hard_close();
        alarm 0;
    };
    $status = 1 if $@;

    return $status ? 0 : 1;

}

1;
