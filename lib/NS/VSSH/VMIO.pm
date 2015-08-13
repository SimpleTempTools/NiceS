package NS::VSSH::VMIO;

use warnings;
use strict;

use YAML::XS;
use Net::SSH::Perl;
use Term::ReadPassword;
use Expect;
use NS::VSSH::Constants;

our %vmio = 
(
    ssh => sub
        {
            my %param = @_;
            $0 = 'vssh.io';
            map{ die "$_ undef" unless $param{$_} }qw( node input output );

            my ( $node, $input, $output, %result ) = @param{qw( node input output )};
            local $SIG{ALRM} = sub { die 'timeout' };

            eval{
                alarm $input->{timeout};
                map{ die "$_ undef" unless defined $input->{$_} }qw( cmd usr );
        
                my %pty = ( use_pty => 1 ) if $input->{pty};
                my $ssh = Net::SSH::Perl->new( 
                    $node, privileged => '0', %pty,
                    options => [ 'StrictHostKeyChecking no' ],
                );
                $ENV{PASSWD} ? $ssh->login( $input->{usr}, $ENV{PASSWD} ) : die 'ENV{PASSWD} undef';
        
                my ( $sr, $so, @sr, @so );
                $ssh->register_handler( 'stdout', sub {
                        my( $channel, $buffer ) = @_;
                        my $str = $buffer->bytes;
                        print "\n$node [stdout]: $str\n" if $ENV{nsdebug};
                        push @so, $str;
                        if ( $str =~/\b[Pp]assword\b/ ) {
                            print "\n$node: send passwd\n" if $ENV{nsdebug};
                           $channel->send_data( $ENV{PASSWD}."\n" );
                        }
                    });
                $ssh->register_handler( 'stderr', sub {
                        my( $channel, $buffer ) = @_;
                        my $str = $buffer->bytes;
                        print "\n$node [stderr]: $str\n" if $ENV{nsdebug};
                        push @sr, $str;
                        if ( $str =~/\b[Pp]assword\b/ ) {
                            print "\n$node: send passwd\n" if $ENV{nsdebug};
                            $channel->send_data( $ENV{PASSWD}."\n" );
                        }
                    });
                
                ( $so, $sr, $result{'exit'} ) = $ssh->cmd( $input->{cmd} );

                push @so, $so if $so;
                push @sr, $sr if $sr;
                $result{stdout} = join "\n", @so;
                $result{stderr} = join "\n", @sr;

                $result{stdout} =~ s/.*[Pp]assword\s?:[\s\n]*//;
                $result{stderr} =~ s/.*[Pp]assword\s?:[\s\n]*//;

                alarm 0;
            };
            
            if( $@ )
            {
                $@ =~ s/ at \/.+//;
                %result = ( stdout => '', stderr => "$0 error: $@", 'exit' => 1 );
            }
        
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
        

    'local' => sub
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
