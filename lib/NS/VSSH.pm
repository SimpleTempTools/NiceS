package NS::VSSH;

use strict;
use warnings;
use Carp;
use Expect;
use Tie::File;
use Fcntl qw( :flock );
use POSIX qw( :sys_wait_h );
use FindBin qw( $Script );

use POSIX;
use Data::Dumper;
use NS::VSSH::Comp;
use FindBin qw( $Bin );
use Cwd 'abs_path';
use Term::ANSIColor qw(:constants :pushpop );
$Term::ANSIColor::AUTORESET = 1;
use Term::ReadPassword;

use NS::VSSH::OCMD;
use NS::VSSH::VMIO;
use NS::VSSH::Constants;

$|++;

my $option = NS::Util::OptConf->load();

my %RUN = (
    max => 128,
    timeout => 900,
    history => '.vssh_history',
    hostdb => '.vssh_hostdb'
);

my @DANGER = qw( rm remove init reboot );
my ( $progress_symbol, @progress_symbol ) = ( 0,'-','\\','|','/' );

our $BTLEN = $NS::VSSH::Constants::BTLEN;
our @HISTORY;

my %HELP = %NS::VSSH::Constants::HELP;
our %OCMD = %NS::VSSH::OCMD;
my $RUNABL;
my @kill;

sub new
{
    my ( $class, %self ) =  @_;

    map{ confess "$_ undef" unless $self{$_}; }qw( host user );
    my %host = map{ $_ => 1 }@{delete $self{host}};


    $self{group} = 'base';
    $self{host}{$self{group}} = [ sort keys %host ];
    $self{block}{$self{group}} = +{};

    $self{group} = 'base';
    $self{path} = "/tmp";
    mkdir $self{path} unless -d $self{path};

    $self{history} = $self{user} eq 'root' 
        ? "/root/$RUN{history}" 
        : "/home/$self{user}/$RUN{history}";

    $self{hostdb} = $self{user} eq 'root' 
        ? "/root/$RUN{hostdb}" 
        : "/home/$self{user}/$RUN{hostdb}";

    $self{pty} = 1;
    if( my $hostdb = eval{ YAML::XS::LoadFile $self{hostdb}} )
    {
        map{ $self{$_} = $hostdb->{$_} if $hostdb->{$_} }qw( host block );
    }

    $self{group} = 'base';
    $self{host}{$self{group}} = [];
    $self{host}{$self{group}} = [ sort keys %host ];
    $self{block}{$self{group}} = +{};

    tie @HISTORY, 'Tie::File', $self{history};

    $self{job} = sprintf "%s.%d", $self{user}, $$;
    $self{key} = rand;

    map{ $self{$_} ||= $RUN{$_} }qw( timeout max );

    bless \%self, ref $class || $class;
}

sub run
{
    my ( $self, %busy, $job ) = shift;
 
    $SIG{INT} = $SIG{TERM} = sub
    {
        kill 9, keys %busy;
        push @kill, values %busy;
        print STDERR "killed\n";

        $RUNABL = 0;
    };

    print $NS::VSSH::Constants::WELCOME;
    $self->NS::VSSH::OCMD::ocmd( cmd => '.info' );

    my $range = NS::Hermes->new( );
    while ( 1 )
    {
        my $typeio = 'ssh';
        my $max = $self->{max};

        @kill = ();
        $RUNABL = 1;
        my $prompt = sprintf "%s@%s[%d] sh%s", 
            $self->{sudo} || $self->{user}, 
            $self->{group},
            scalar $range->load( $self->{host}{$self->{group}} )->list(),
            ( $self->{sudo} && $self->{sudo} eq 'root' ) ? '#':'$';

        my $tc = NS::VSSH::Comp->new( 
            'clear'  => qr/\cl/, 
            'reverse'  => qr/\cr/, 
            'wipe'  => qr/\cw/, 
             prompt => $prompt ,  
             choices => [ keys %HELP ],
             up       => qr/\x1b\[[A]/,
             down     => qr/\x1b\[[B]/,
             left     => qr/\x1b\[[D]/,
             right    => qr/\x1b\[[C]/,
	     quit     => qr/[\cc]/, 
        );
        my ( $cmd, $type ) = $tc->complete();

        next unless $cmd;
      
        next if $type && ! checkcmd( $cmd );

        push @HISTORY, $cmd;
        exit if $cmd eq 'exit' || $cmd eq 'quit' ||  $cmd eq 'logout';
        
        if( $cmd =~ /^\.rsync/ )
        {
             $max = 3;
             my @rsync = split /\s+/, $cmd;
             shift @rsync;

             my ( $src, $dst );
             $src = shift @rsync;
             unless( $src ) { $self->help( '.rsync' ); next; }
             unless( -e $src ){ print BOLD  RED "$src: No such file or directory\n"; next; }

             $dst = ( @rsync && $rsync[0] !~ /^-/ ) ? shift @rsync : $src;


             $src = sprintf "%s%s", abs_path( $src ), $src =~ /\/$/ ? '/' :'' if $src !~ /^\//;
             $dst = sprintf "%s%s", abs_path( $dst ), $dst =~ /\/$/ ? '/' :'' if $dst !~ /^\//;

             if( $src =~ /\s+/ || $dst =~ /\s+/ )
             {
                 print BOLD  RED "has \\s+ in the path\n"; next; 
             };
             my $opt = join ' ', @rsync;
             print "src: $src\ndst: $dst\nopt: $opt\nusr: $self->{user}\nmax: $max\n";
             $cmd = "rsync $src $self->{user}\@{}:$dst $opt";
	     $typeio = 'expect';
             next unless yesno();
        }
        elsif( $cmd =~ /^\.mcmd/ )
        {
             $cmd =~ s/^\.mcmd\s*//;;
	     $typeio = 'local';
             
             if( $cmd !~ /\{\}/ ){ $self->help( '.mcmd' ); next; }
             next unless yesno();
        }
        else
        {
            next if $cmd =~ /^\.[a-z]/ && NS::VSSH::OCMD::ocmd( $self, cmd => $cmd );
        }

      
        my $danger;
        for ( @DANGER )
        {
            if( $cmd =~ /$_/ ) { $danger = yesno() ? 0 : 1; last; }
        };
        next if $danger;

        my $key = time.'.'.$self->{job}.'.'.rand;
        $job = sprintf "%s/%s", $self->{path}, $key;
        mkdir $job;

        if( $cmd =~ /;;/ ) { print "check your cmd\n"; next; }

        $cmd = "sudo -H -u $self->{sudo} $cmd" if $self->{sudo};

        if( $typeio eq 'ssh' && $cmd =~ /^[a-zA-Z0-9\/\- &]+$/ )
        {
            $cmd = sprintf "ssh -o StrictHostKeyChecking=no -c blowfish %s -l $self->{user} {} %s '%s'",
                 ( $self->{pty} ? '-t': '' ), 
                 ( $self->{sudo} ? "sudo -p 'password:' -u root" : ''), 
                 $cmd;
            $typeio ='expect';
        }

        my %input = ( 
            cmd => $cmd, 
            usr => $self->{user}, 
            pty => $self->{pty}, 
            timeout => $self->{timeout} 
        );

        %busy = ();
        my ( @node, %re  ) 
            = grep{ !$self->{block}{$self->{group}}{$_}}
                @{$self->{host}{$self->{group}}};

        my (  $rcount, $icount, $hcount )  = ( 0, 0, scalar @node );
        unless( @node )
        {
            print @{$self->{host}{$self->{group}}} 
                ? "All of your host may have been blocked.\n" : "No host.\n";
            next;
        }
           
        do{
            while ( $RUNABL && @node && keys %busy < $max )
            {
                $rcount ++;
                my $node = shift @node;

                $self->{quiet}
                   ? progress_symbol( $rcount, $icount,  $hcount )
                   : print "-" x 16, $node, "-" x 16, "[$rcount]#\n";

                if ( my $pid = fork() ) { $busy{$pid} = $node; next }
                 
                $SIG{INT} = $SIG{TERM} = sub{ 

                    YAML::XS::DumpFile "$job/$node",
                   +{ 
                         stderr => "killed", 
                         'exit' => 1,
                    } if $job && $node;
                    exit 1;
                };
  
                eval
                {
                     $NS::VSSH::VMIO::vmio{$typeio}( 
                         node => $node, 
                         input => \%input, 
                         output => "$job/$node", 
                     )
                };
                YAML::XS::DumpFile "$job/$node",
                   +{ 
                         stdout => '', 
                         stderr => "system vssh.io error", 
                         'exit' => 1,
                    } if $@;
              
                exit 0;
            }
            for ( keys %busy )
            {
                my $pid = waitpid( -1, WNOHANG );
                next if $pid <= 0;
                my $node =  delete $busy{$pid};
                next unless $node;

                my $out = eval{ YAML::XS::LoadFile "$job/$node" };
                unlink "$job/$node";
                my $error = 'ERROR: Laod' if $@;
                
                $error = 'ERROR: std', if ! $error && ! defined $out->{'exit'};
    
                $out = +{ stderr => "vssh.io: $error", 'exit' => 1 } if $error;
    
                $icount ++;
                unless( $self->{quiet} )
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
		    progress_symbol( $rcount, $icount,  $hcount );
                }

                push @{$re{ YAML::XS::Dump $out }}, $node;
            }
        }while $RUNABL && ( @node || %busy );
    
        rmdir $job;

        print "\n";
        print PUSHCOLOR RED ON_GREEN  "#" x $BTLEN, ' RESULT ', "#" x $BTLEN;
        print "\n";
    
        my $block = $self->{block}{$self->{group}};

        push @{$re{"---\nexit: 1\nstderr: no run"}}, @node if @node;
        push @{$re{"---\nexit: 1\nstderr: killed"}}, @kill if @kill;
        if( %$block )
        {
            map{ 
                push @{$re{"---\nstderr: block\nexit: 1"}}, $_ 
                    if $block->{$_};
            }@{$self->{host}{$self->{group}}};
        }
        print "=" x 68, "\n";
        map{
    
            my $c = YAML::XS::Load $_;
            printf "%s[", $range->load( $re{$_} )->dump;
            my $count = scalar $range->load( $re{$_} )->list;
            $c->{'exit'} ? print BOLD  RED $count : print BOLD GREEN $count;
    
            print "]:\n";
            print BOLD  GREEN "$c->{stdout}\n" if $c->{stdout};
            print BOLD  RED   "$c->{stderr}\n" if $c->{stderr};
            print "=" x 68, "\n";
        }keys %re;
    }
}

sub help
{
    my ( $self, $h ) = @_;
    print $HELP{$h} ? "$HELP{$h}\n" : "invalid option\n";
}

sub dumpdb
{
    my $self = shift;
    my ( $hostdb, $host, $block ) = @$self{qw( hostdb host block )};
    eval{ YAML::XS::DumpFile $hostdb, +{ host => $host, block => $block } };
}

sub yesno
{
    while( 1 )
    {
        print "Are you sure you want to run this command [y/n]:";
        my $in = <STDIN>;
        next unless $in;
        return 1 if $in eq "y\n";
        return 0 if $in eq "n\n";
    }
}

sub checkcmd
{
    my $cmd = shift;
    while( 1 )
    {
        print "$cmd [y/n]:";
        my $in = <STDIN>;
        next unless $in;
        return 1 if $in eq "y\n";
        return 0 if $in eq "n\n";
    }
}
sub progress_symbol
{
   my ( $rcount, $icount, $hcount ) = @_;
   printf "\r running ... $progress_symbol[$progress_symbol] [run:$rcount] [running:%4d]  [finish: $icount / $hcount]", $rcount - $icount; 
   $progress_symbol = ( $progress_symbol >= 3 ) ? 0 : $progress_symbol +1;
}

1;
