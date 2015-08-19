package NS::VSSH;

use strict;
use warnings;
use Carp;
use Expect;
use Tie::File;
use Fcntl qw( :flock );
use POSIX qw( :sys_wait_h );
use Cwd 'abs_path';
use Tie::File;

use NS::VSSH::Comp;
use NS::VSSH::OCMD;
use NS::VSSH::VMIO;
use NS::VSSH::HostDB;

use NS::VSSH::OCMD::Help;

use Term::ANSIColor qw(:constants :pushpop );
$Term::ANSIColor::AUTORESET = 1;


use Data::Dumper;

$|++;

my ( $procbol, @procbol ) = ( 0,'-','\\','|','/' );
my ( @DANGER, @kill, $RUNABL )  = qw( rm remove init reboot );

sub new
{
    my ( $class, %self ) =  @_;

    map{ confess "$_ undef" unless $self{$_}; }qw( host user );
    my %host = map{ $_ => 1 }@{delete $self{host}};


    $self{config} = +{ 
        sudo => '',
        askpass => { '[Pp]assword' => 'PASSWD' },
        tmppath => '/tmp',
        sshSafeModel => 1,
        tty => 1,
        max => +{ ssh => 128, rsync => 3, mcmd => 128, expect => 128 },
        timeout => 300,
        quiet => 1,
    };

    $self{hostdb} = NS::VSSH::HostDB->new( 
        name => 'base', path => $self{hostdb}
    )->clear()->add( keys %host );

    $self{ocmd} = NS::VSSH::OCMD->new( 
        hostdb => $self{hostdb},
        config => $self{config},
        user => $self{user},
    );

    $self{help} = NS::VSSH::OCMD::Help->new();

    bless \%self, ref $class || $class;
}

sub _comp
{
    my $self = shift;
    my ( $config, $user, $hostdb ) = @$self{qw( config user hostdb )};
    my $sudo = $config->{sudo};

    my $prompt = sprintf "%s@%s[%d] sh%s", 
        $sudo || $user, $hostdb->use(),
        scalar $hostdb->load(),
        ( ( $sudo && $sudo eq 'root' ) || $user eq 'root' ) ? '#':'$';

    my $tc = NS::VSSH::Comp->new( 
        'clear'  => qr/\cl/, 
        'reverse'  => qr/\cr/, 
        'wipe'  => qr/\cw/, 
         prompt => $prompt ,  
         choices => [ $self->{help}->list() ],
         up       => qr/\x1b\[[A]/,
         down     => qr/\x1b\[[B]/,
         left     => qr/\x1b\[[D]/,
         right    => qr/\x1b\[[C]/,
         quit     => qr/[\cc]/, 
    );
    my ( $cmd, $danger ) = $tc->complete();
    return $cmd unless $danger;

    while( 1 )
    {
        print "$cmd [y/n]:";
        my $in = <STDIN>;
        next unless $in;
        return $cmd if $in eq "y\n";
        return undef if $in eq "n\n";
    }
}

sub run
{
    my ( $self, %busy ) = shift;
 
    $SIG{INT} = $SIG{TERM} = sub
    {
        kill 9, keys %busy;
        push @kill, values %busy;
        print STDERR "killed\n";

        $RUNABL = 0;
    };

    $self->{ocmd}->welcome()->run( '.info' );

    while ( 1 )
    {
        next unless my $cmd = $self->_comp();
        $self->{ocmd}->sethistory( $cmd );
        exit if $cmd eq 'exit' || $cmd eq 'quit' ||  $cmd eq 'logout';

        my ( $RUNABL, $typeio , $max ) = 1;
        @kill = ();
        
        if( $cmd =~ /^\.[a-z]/ )
        {
            ( $typeio, $cmd ) = $self->{ocmd}->run( $cmd ); 
            next unless $typeio && $cmd;
        }
        else{ $typeio = 'ssh'; };

        next if ( grep{ $cmd =~ /$_/ }@DANGER ) && ! $self->{help}->yesno();

        my $key = 'vssh.'.$self->{user}.'.'.time.'.'.$$.'.'.rand 20;
        my $job = sprintf "%s/%s", $self->{config}{tmppath}, $key;

        %busy = ();
        my ( @node, %re  ) =  $self->{hostdb}->load();

        unless( @node ) { print "No host.\n"; next; }
        my ( $rcount, $icount, $hcount )  = ( 0, 0, scalar @node );
           
        if( $typeio eq 'ssh' && $self->{config}{sshSafeModel} )
        {
            die "tie $job.todo fail: $!!" unless tie my @exec, 'Tie::File', "$job.todo";
            push @exec, '#!/bin/bash', $cmd;
            untie @exec;
        }

        unless( $max = $self->{config}{max}{$typeio} )
        {
            print "config.max.$typeio=0\n";
            next;
        }

        do{
            while ( $RUNABL && @node && keys %busy < $max )
            {
                $rcount ++;
                my $node = shift @node;

                $self->{config}{quiet}
                   ? procbol( $rcount, $icount,  $hcount )
                   : print "-" x 16, $node, "-" x 16, "[$rcount]#\n";


                if ( my $pid = fork() ) { $busy{$pid} = $node; next }
                 
                $SIG{INT} = $SIG{TERM} = sub
                { 
                    YAML::XS::DumpFile "$job.$node", +{ stderr => "killed", 'exit' => 1 }
                        if $job && $node;
                    exit 1;
                };
  
                eval
                {
                     $NS::VSSH::VMIO::vmio{$typeio}( 
                         id => $key,
                         node => $node, 
                         'exec' => $cmd,
                         user => $self->{user},
                         config => $self->{config},
                         passwd => $NS::VSSH::Auth::passwd,
                     )
                };

                YAML::XS::DumpFile "$job.$node", 
                    +{ stderr => "vssh code err:$@", 'exit' => 1 } if $@;
                exit 0;
            }

            for ( keys %busy )
            {
                my $pid = waitpid( -1, WNOHANG );
                next if $pid <= 0;
                my $node =  delete $busy{$pid};
                next unless $node;

                my $out = eval{ YAML::XS::LoadFile "$job.$node" };
                unlink "$job.$node";
                my $error = 'ERROR: Load output fail.' if $@;
                
                $error = 'ERROR: exit undef on ouput file.', 
                    if ! $error && ! defined $out->{'exit'};
    
                $out = +{ stderr => "vssh.io: $error", 'exit' => 1 } if $error;
    
                $icount ++;
                unless( $self->{config}{quiet} )
                {
                    print "#" x 16;
                    $out->{'exit'}
                        ? print BOLD  RED   $node
                        : print BOLD  GREEN $node;
                    print "#" x 16, "[$icount/$hcount]#\n";
                    YAML::XS::DumpFile \*STDOUT, $out;
                }
                else
                {
		    procbol( $rcount, $icount,  $hcount );
                }

                push @{$re{ YAML::XS::Dump $out }}, $node;
            }
        }while $RUNABL && ( @node || %busy );
    
        unlink "$job.todo";

        push @{$re{"---\nexit: 1\nstderr: no run\n"}}, @node if @node;
#        push @{$re{"---\nexit: 1\nstderr: killed\n"}}, @kill if @kill;

        $self->{help}->result( %re );
    }
}

sub procbol
{
   my ( $rcount, $icount, $hcount ) = @_;
   printf "\r running ... $procbol[$procbol] [run:$rcount] [running:%4d]  [finish: $icount / $hcount]", $rcount - $icount; 
   $procbol = ( $procbol >= 3 ) ? 0 : $procbol +1;
}

1;
