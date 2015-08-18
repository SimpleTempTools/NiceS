package NS::VSSH::VMIO;

use warnings;
use strict;

use YAML::XS;
use Net::SSH::Perl;
use Term::ReadPassword;
use Expect;

use Data::Dumper;

our %vmio = 
(
    ssh => sub
        {
            my %param = @_;
            map{ die "$_ undef" unless $param{$_} }qw( node id config exec user );

            my ( $node, $id, $config, $passwd, $user, %result )
                = @param{qw( node id config passwd user )};
        
            my ( $tmppath, $timeout, $sudo, $tty, $askpass )
                = @$config{qw( tmppath timeout sudo tty askpass )};
            $0 = "vssh vmio ssh $node";

            my $output = "$tmppath/$id.$node";
            local $SIG{ALRM} = sub { die 'timeout' };
        
            open STDOUT, '>',  $output;
            open STDERR, '>&', STDOUT;
        
            $timeout = 5 unless $timeout && $timeout >= 5;

            my $exec = "$tmppath/$id.exec";
            my @exec = 
                (
                    sprintf( "scp '$tmppath/$id.todo' %s$node:$exec 1>/dev/null 2>&1",
                        $user ? "$user@" : '' ),
                    sprintf( "ssh -o StrictHostKeyChecking=no -c blowfish %s %s $node %s '%s;%s;%s'", 
                        $tty ? $tty == 1 ? "-t" : "-tt" : '',
                        $user ? "-l $user" : '',
                        $sudo ? "sudo -H -u $sudo" : '',
                        "sh $tmppath/$id.exec",
                        'echo "******* status exit $? exit status *******"',
                        "rm -f $tmppath/$id.exec",
                        )
                );

           unless( $config->{sshSafeModel} )
           {
               @exec = (
                   sprintf( "ssh -o StrictHostKeyChecking=no -c blowfish %s %s $node %s '%s;%s'",
                       $tty ? $tty == 1 ? "-t" : "-tt" : '',
                       $user ? "-l $user" : '',
                       $sudo ? "sudo -H -u $sudo" : '',
                       $param{'exec'},
                       'echo "******* status exit $? exit status *******"',
                   )
               );
           }

           my $exp = Expect->new();
           $exp->spawn( join ' && ', @exec );
           my ( undef, $stat ) = $exp->expect
               (
                   $timeout,
                   map
                   {
                       my $k = $_;
                       my $p = $askpass->{$k} eq 'PASSWD' ? $passwd : $askpass->{$k};
                       [ qr/$k/ => sub { $exp->send( "$p\n" ); exp_continue; } ],
                   }keys %$askpass
               );

           $exp->hard_close();

            my @stdout = `cat '$output'` if -f $output;
            map
            {
                $_ =~ s/\w+\@$node\'s //;
                $_ =~ s/[Pp]assword\s?:[\s\n]*//;
                $_ =~ s/$exec: line 2: //;
            }@stdout unless $ENV{nsdebug};

            my $stdout = join '', grep{ 
                $_ !~ /password: $/ && $_ !~ /^Connection to [a-zA-Z0-9\.-]+ closed\./
            }@stdout;

            my $status = $stdout =~ /\*\*\*\*\*\*\* status exit (\d+) exit status \*\*\*\*\*\*\*/
                         ? $1 : 1;

             $stdout =~ s/\*\*\*\*\*\*\* status exit 0 exit status \*\*\*\*\*\*\*//g;
            ( $result{stdout}, $result{stderr}, $result{'exit'} )
                = ( ( $stat && $stat !~ /exited with status 0$/ ) || $status )
                  ? ( '', "$stdout$stat", $status ) : ( $stdout ||'' , '' , $status );
        
            YAML::XS::DumpFile $output, \%result;
        },
  

    expect => sub
        {
            my %param = @_;
            $0 = 'vssh.expect.io';
        
            map{ die "$_ undef" unless $param{$_} }qw( node input output );

            my ( $node, $input, $output, %result, $status ) = @param{qw( node input output )};
        
            local $SIG{ALRM} = sub { die 'timeout' };
        
            open STDOUT, '>',  $output;
            open STDERR, '>&', STDOUT;
        
            my $timeout = $input->{timeout};
            $timeout = 5 if $timeout < 5;

            eval{

                alarm $timeout;
                map{ die "$_ undef" unless defined $input->{$_} }qw( cmd usr );
        
                $input->{cmd} =~ s/\{\}/$node/;
        
                my $exp = Expect->new();
                $exp->spawn( $input->{cmd} );
                ( undef, $status ) = $exp->expect
                    (
                        $timeout - 3,
                        [ qr/\b[Pp]assword\b/ => sub { $exp->send( "$ENV{PASSWD}\n" ); exp_continue; } ],
                    );
        
                $status = ( $status =~ /exited with status 0/ ) ? 0 : 1;
                $exp->hard_close();
                alarm 0;
            };
        
            my @stdout = `cat $output` if -f $output;
            my $stdout = join '', 
                grep{ $_ !~ /password: $/ && $_ !~ /^Connection to [a-zA-Z0-9\.-]+ closed\./ }
                @stdout if @stdout;
        
            ( $result{stdout}, $result{stderr}, $result{'exit'} )
                = ( $@ || $status || ( $stdout && $stdout =~ /Cannot exec/ ) )
                      ? ( '', "$stdout$@", 1 )
                      : ( $stdout , '' , 0 );
        
            $result{stdout} =~ s/\w+\@$node\'s //;
            $result{stderr} =~ s/\w+\@$node\'s //;

            $result{stdout} =~ s/[Pp]assword\s?:[\s\n]*//;
            $result{stderr} =~ s/[Pp]assword\s?:[\s\n]*//;
            YAML::XS::DumpFile $output, \%result;
        },
        

    'mcmd' => sub
        {
            my %param = @_;
            $0 = 'vssh.local.io';
        
            map{ die "$_ undef" unless $param{$_} }qw( node input output );

            my ( $node, $input, $output, %result ) = @param{qw( node input output )};

            local $SIG{ALRM} = sub { die 'timeout' };
        
            my ( $out, $status );
            eval{
                alarm $input->{timeout};
                map{ die "$_ undef" unless defined $input->{$_} }qw( cmd usr );
        
                $input->{cmd} =~ s/\{\}/$node/;
                $out = `$input->{cmd}`;
                $status = $?;
                alarm 0;
            };
        
            ( $result{stdout}, $result{stderr}, $result{'exit'} )
                = ( $@ || $status ) ? ( '', "$out$@", 1 ) : ( $out , '' , 0 );
        
            YAML::XS::DumpFile $output, \%result;
        }

);

1;
