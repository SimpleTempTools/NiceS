package NS::VSSH::VMIO;

use warnings;
use strict;

use YAML::XS;
use Net::SSH::Perl;
use Term::ReadPassword;
use Expect;

our $ssh = 'ssh';
our $scp = 'scp';

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
                    sprintf( "$scp '$tmppath/$id.todo' %s$node:$exec 1>/dev/null",
                        $user ? "$user@" : '' ),
                    sprintf( "$ssh -o StrictHostKeyChecking=no -c blowfish %s %s $node %s '%s;%s;%s'", 
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
                   sprintf( "$ssh -o StrictHostKeyChecking=no -c blowfish %s %s $node %s '%s;%s'",
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

            print "$stat\n" if $ENV{nsdebug};

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
                  ? ( '', "$stdout", $status ) : ( $stdout ||'' , '' , $status );
        
            YAML::XS::DumpFile $output, \%result;
        },
  

    expect => sub
        {
            my %param = @_;
            map{ die "$_ undef" unless $param{$_} }qw( node id config exec user );

            my ( $node, $id, $config, $passwd, $user, $exec,  %result )
                = @param{qw( node id config passwd user exec )};
        
            my ( $tmppath, $timeout, $sudo, $tty, $askpass )
                = @$config{qw( tmppath timeout sudo tty askpass )};
            $0 = "vssh vmio rsync $node";

            my $output = "$tmppath/$id.$node";
            local $SIG{ALRM} = sub { die 'timeout' };
        
            open STDOUT, '>',  $output;
            open STDERR, '>&', STDOUT;
        
            $timeout = 5 unless $timeout && $timeout >= 5;

            $exec =~ s/\{\}/$node/;

            my $exp = Expect->new();
            $exp->spawn( $exec );
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
        
            my @stdout = `cat $output` if -f $output;
            my $stdout = join '', @stdout;
        
            ( $result{stdout}, $result{stderr}, $result{'exit'} )
                = ( $stat && $stat =~ /exited with status 0\b/ )
                      ? ( $stdout , '' , 0 )
                      : ( '', "$stdout", 1 );
        
            YAML::XS::DumpFile $output, \%result;
        },
        

    'mcmd' => sub
        {
            my %param = @_;
            map{ die "$_ undef" unless $param{$_} }qw( node id config exec user );

            my ( $node, $id, $config, $passwd, $user, $exec,  %result )
                = @param{qw( node id config passwd user exec )};

            my ( $tmppath, $timeout, $sudo, $tty, $askpass )
                = @$config{qw( tmppath timeout sudo tty askpass )};
            $0 = "vssh vmio ssh $node";

            my $output = "$tmppath/$id.$node";
            local $SIG{ALRM} = sub { die 'timeout' };
 
            $timeout = 5 unless $timeout && $timeout >= 5;

            open STDOUT, '>',  $output;
            open STDERR, '>&', STDOUT;

            my $status = 0;
            eval{
                alarm $timeout;
        
                $exec =~ s/\{\}/$node/g;
                system $exec;

                if( $? == -1 )
                {
                    print "failed to execute: $!\n";
                    $status = 1;
                }
                elsif( $? & 127 )
                {
                    printf "child died with signal %d, %s coredump\n",
                        ( $? & 127 ), ( $? & 128 ) ? 'with' : 'without';
                    $status = 1;
                }
                elsif( my $exit = $? >> 8 )
                {
                    print "child exited with value $exit\n";
                    $status = $exit;
                }
                
                alarm 0;
            };

            my @stdout = `cat $output` if -f $output;
            my $stdout = join '', @stdout;
        
            ( $result{stdout}, $result{stderr}, $result{'exit'} )
                = $status ? ( '', $stdout, $status ) : ( $stdout , '' , 0 );
        
            YAML::XS::DumpFile $output, \%result;
        }

);

$vmio{rsync} = $vmio{expect};

1;
