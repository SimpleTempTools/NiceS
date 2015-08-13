package NS::VSSH::OCMD;

use strict;
use warnings;
use Carp;
use Tie::File;
use Data::Dumper;
use Cwd 'abs_path';
use Term::ANSIColor qw(:constants :pushpop );
$Term::ANSIColor::AUTORESET = 1;
use Term::ReadPassword;


use NS::VSSH::Constants;
$|++;

our $BTLEN = $NS::VSSH::Constants::BTLEN;
our %HELP = %NS::VSSH::Constants::HELP;

my $option = NS::Util::OptConf->load();

our %OCMD = (
    '.list' => sub
               {
                   my $vssh = shift;
                   map{
                       $vssh->{block}{$vssh->{group}}{$_}
                           ? print BOLD  RED "#$_" : print $_;
                       print "\n"; 
                   }@{$vssh->{host}{$vssh->{group}}};
               },
    '.dump' => sub
               {
                   my $vssh = shift;
                   my ( $hosts, $block ) = map{ $vssh->{$_}{$vssh->{group}} }qw( host block );
                   my $range = NS::Hermes->new();
                   print $range->load( $hosts )->dump ,"\n";
                   if( %$block )
                   {
                       print "block:";
                       print BOLD  RED $range->load( 
                                            [ grep{ $block->{$_} }$range->load( $hosts )->list ] 
                                       )->dump;
                       print "\n";
                   }
               },
    '.use' => sub
               {
                   my ( $vssh, %param ) = @_;
                   my ( undef, $grp, $err ) = split /\s+/, $param{cmd};
                   $vssh->help( '.use' ) if $err;
                   $grp ||= 'base';

                   $vssh->{group} = $grp;
                   $vssh->{host}{$grp}  ||= [];
                   $vssh->{block}{$grp} ||= {};
               },
 
    '.tmp' => sub
               {
                   my $vssh = shift;
                   $vssh->{group} = 'tmp';
                   $vssh->{host}{tmp}  = [];
                   $vssh->{block}{tmp} = {};
                   $vssh->dumpdb();
               },
 
    '.clearspace' => sub
               {
                   my ( $vssh, %param ) = @_;
                   my @name = split /\s+/, $param{cmd};
                   shift @name;

                   @name = sort keys %{$vssh->{host}} if grep{ $_ eq '*' }@name;

                   push @name, $vssh->{group} unless @name;

                   map
                   {
                       print "delete: $_\n";
                       delete $vssh->{host}{$_};
                       delete $vssh->{block}{$_};
                   }@name;

                   $vssh->{host}{$vssh->{group}} ||= [];
                   $vssh->{block}{$vssh->{group}} ||= +{};
                   $vssh->dumpdb();
               },
 
    '.save' => sub
               {
                   my ( $vssh, %param ) = @_;
                   my @group = split /\s+/, $param{cmd};
                   shift @group;
                   my $grp = shift @group;
                   $grp ||= 'base';

                   my $count = scalar @{$vssh->{host}{$vssh->{group}}};
                   if( @group )
                   {
                       map {unless($_ =~ /^\d+%?$/){ $vssh->help('.save');return;}}@group;
                       map{ delete $vssh->{host}{$_} if /$grp=g/ }keys %{$vssh->{host}};
                           
                       my $block = $vssh->{block}{$vssh->{group}};
                       push my @node, 
                           grep{!$block->{$_}}@{$vssh->{host}{$vssh->{group}}};

                       if( %$block )
                       {
                           
                           printf "[WARN] Block:";
                           print NS::Hermes->new()->load(
                               [ grep{$block->{$_}}@{$vssh->{host}{$vssh->{group}}}]
                             )->dump;
                           print "\n";
                       }

                       for( my $i = 0; @node; $i++ )
                       {
                           my $index = $i >= @group ? scalar @group -1 : $i;
                           my $c = $group[$index];
                           
                           $c = $count * $c / 100 if $c =~ s/%$//;
                           push @{$vssh->{host}{"$grp=g$i"}}, splice @node, 0, $c;
                           printf "$grp=g$i: %d\n", scalar @{$vssh->{host}{"$grp=g$i"}};
                       }
                       return;
                   }

                   if( $grp eq $vssh->{group} )
                   {
                       print "you in the namespace: $grp. do nothing\n";
                       return;
                   }

                   $vssh->{host}{$grp} = [];                   
                   push @{$vssh->{host}{$grp}}, @{$vssh->{host}{$vssh->{group}}};
                   print "save to $grp, host count $count\n";
                   $vssh->dumpdb();
               },
    '.info' => sub
               {
                   my ( $vssh, %param ) = @_;

                   print join ' | ', ( map{ "$_: $vssh->{$_}" }qw( max timeout user )), "\n";
                   printf "sudo: %s\n", $vssh->{sudo} || 'no sudo';
                   print '-' x ( $BTLEN * 2 + 6 ), "\n";
                   print "Host Namespace:\n";
                   my $range = NS::Hermes->new();
                   map
                   {
                       printf "  name:%s\n    count: %d\n    hosts:%s\n",
                           $_, 
                           scalar $range->load( $vssh->{host}{$_})->list,
                           $range->load( $vssh->{host}{$_})->dump;
                   }sort keys %{$vssh->{host}};
               },
 
    '.load' => sub
               {
                   my ( $vssh, %param, @hosts ) = @_;
                   my ( $file ) = $param{cmd} =~ /^\.load\s+(.+)\s*$/;

                   if( $file )
                   {
                       unless( -f $file ) { print "$file: No such file\n";return; }
                       eval{ confess "$file: $!" unless tie @hosts, 'Tie::File', $file; };
                       if( $@ ) { print "file $file error: $@"; return; }
                   }
                   else
                   {

                       print "Please enter your machine list, to the end of END\n";
                       my $END = $/; $/ = 'END';
                       my $host = <STDIN>;
                       $/ = $END;

                       $host =~ s/END$//;
                       print "LOADING ...\n";
                       @hosts = split "\n", $host;
                   }
 
                   my ( %node, %temp ) = map{ $_ => 1 }@{$vssh->{host}{$vssh->{group}}};
                   for my $line ( @hosts )
                   {
                       $line =~ s/#.*$//; $line =~ s/^\s+//; $line =~ s/\s+$//;
                       next unless length $line;
                       map{
                           if( $node{$_} || $temp{$_} )
                           {
                                print BOLD RED $_;
                                print "\n";
                           }
                           else
                           {
                               print BOLD GREEN $_;
                               print "\n";
                               push @{$vssh->{host}{$vssh->{group}}}, $_;
                               $temp{$_} = 1;
                           }
           
                       }split /\s+/, $line;
                   }
                   $vssh->dumpdb();
               },
 
     '.sort' => sub
               {
                   my ( $vssh, %param ) = @_;
                   my ( $sort ) = $param{cmd} =~ /^\.sort\s+(\d+)\s*$/;
                   if( $sort )
                   {
                       my %node = map{ 
                           my @ex = $_ =~ /(\d+)/g;
                           $_ => $ex[$sort -1] || 0;
                       }@{$vssh->{host}{$vssh->{group}}};

                       $vssh->{host}{$vssh->{group}}
                           = [ sort{ $node{$a} <=> $node{$b} }keys %node];
                   }
                   else
                   {
                       $vssh->{host}{$vssh->{group}}
                           = [ sort @{$vssh->{host}{$vssh->{group}}} ];
                   }
                   map{print "$_\n";}@{$vssh->{host}{$vssh->{group}}};
                   $vssh->dumpdb();
               },

     '.max' => sub {
                       my ( $vssh, %param ) = @_;
                       my ( $max ) = $param{cmd} =~ /^\.max\s+(\d+)\s*$/;
                       if( $max )
                       {
                           $vssh->{max} = $max;
                           print "set max: $max\n";
                           return;
                       }
                       $vssh->help( '.max' );
                   },

     '.user' => sub {
                       my ( $vssh, %param ) = @_;
                       my ( $user ) = $param{cmd} =~ /^\.user\s+(\w+)\s*$/;
                       if( $user )
                       {
                           $vssh->{user} = $user;
                           do{ $ENV{PASSWD} = read_password( "$user\'s password: "); }while( ! $ENV{PASSWD} );
                           print "set user: $user\n";
                           return;
                       }
                       $vssh->help( '.user' );
                   },

     '.password' => sub {
                       do{ $ENV{PASSWD} = read_password( "password: "); }while( ! $ENV{PASSWD} );
                   },

     '.timeout' => sub {
                       my ( $vssh, %param ) = @_;
                       my ( $timeout ) = $param{cmd} =~ /^\.timeout\s+(\d+)\s*$/;
                       if( $timeout )
                       {
                           $vssh->{timeout} = $timeout;
                           print "set timeout: $timeout\n";
                           return;
                       }
                       $vssh->help( '.timeout' );
                   },

     '.quiet' => sub { my $vssh = shift; $vssh->{quiet} = 1; },
     '.verbose' => sub { my $vssh = shift; $vssh->{quiet} = 0; },
     '.clear' => sub { system 'clear' },
     '.history' => sub 
               {
                   my $i = 0;
                   map{ print "  $i  $_\n"; $i++; }@NS::VSSH::HISTORY;
               },

     '.sudo' => sub
               {
                   my ( $vssh, %param ) = @_;
                   my ( $sudo ) = $param{cmd} =~ /^\.sudo\s+(\w+)\s*$/;
                   my $u = $vssh->{sudo} = $sudo || 'root';
                   print "set sudo: $u\n";
               },

     '.unsudo' => sub
               {
                   my $vssh = shift;
                   $vssh->{sudo} = '';
                   print "set sudo: nusudo\n";
               },
     '.local' => sub
               {
                   my ( $vssh, %param ) = @_;
                   $param{cmd} =~ s/^\.local\s*//;
                   system "$param{cmd}";
               },
     '.tty' => sub
               {
                   my ( $vssh, %param ) = @_;
                   my $pty = ( split /\s+/, $param{cmd} )[1];

                   $vssh->{pty} = 0 if $pty && $pty eq 'OFF';
                   $vssh->{pty} = 1 if $pty && $pty eq 'ON';

                   printf "set tty: %s\n", $vssh->{pty} ? 'ON' : 'OFF';
               },
 
     '.debug' => sub
               {
                   my ( $vssh, %param ) = @_;
                   if( $param{cmd} =~ /^\.debug\s+on$/ )
                   {
                       $ENV{QVSSH_DEBUG} = 1;
                   }
                   elsif( $param{cmd} =~ /^\.debug\s+off$/ )
                   {
                       $ENV{QVSSH_DEBUG} = 0;
                   }
                   else
                   {
                       YAML::XS::DumpFile \*STDOUT, shift;
                   }
               },

     '.lock' => sub
               {
                   my ( $vssh, %param ) = @_;
                   my $user = $vssh->{user};
                   print "$user locked.\n";

                   while(1){ 
                       last if $ENV{PASSWD} eq read_password("$user\'s password: ");
                   }
                   print $NS::VSSH::Constants::WELCOME, "\n";
               },

    '.add' => sub
               {
                   my ( $vssh, %param ) = @_;
                   my @add = split ' ', $param{cmd};
                   shift @add;
                   return unless @add;

                   my $cluster = NS::Hermes->new( $option->dump( 'range' ) );
                   my $range = NS::Hermes->new();

                   map{ s/^['"]//; s/['"]$//; $range->add( $cluster->load( $_ ) )}@add;

                   my %node = map{ $_ => 1 }@{$vssh->{host}{$vssh->{group}}};
                   map{ 
                       if( $node{$_} )
                       {
                            print BOLD RED $_;
                            print "\n";
                       }
                       else
                       {
                           print BOLD GREEN $_;
                           print "\n";
                           push @{$vssh->{host}{$vssh->{group}}}, $_;
                       }
                   }$range->list;
                   $vssh->dumpdb();
               },
     '.del' => sub
               {
                   my ( $vssh, %param ) = @_;
                   my @add = split ' ', $param{cmd};
                   shift @add;
                   return unless @add;

                   my $cluster = NS::Hermes->new( $option->dump( 'range' ) );
                   my $range = NS::Hermes->new();
                   map{ s/^['"]//; s/['"]$//;$range->add( $cluster->load( $_ ) ) }@add;

                   my %node = map{ $_ => 1 }@{$vssh->{host}{$vssh->{group}}};
                   for my $node ( $range->list )
                   {
                       if( $node{$node} )
                       {
                            print BOLD GREEN $node;
                            print "\n";
                            my $i = 0;
                            map{ 
                                splice @{$vssh->{host}{$vssh->{group}}}, $i, 1 if $_ eq $node;
                                $i ++; 
                            }@{$vssh->{host}{$vssh->{group}}};
                       }
                       else
                       {
                           print BOLD RED $node;
                           print "\n";
                       }
                   }
                   $vssh->dumpdb();
               },

      '.filter' => sub
               {
                   my ( $vssh, %param ) = @_;

                   my @filter = split /\s+/, $param{cmd};
                   shift @filter;
                   unless( @filter )
                   {
                       $vssh->help( '.filter' );
                       return;
                   } 

                   my $range = NS::Hermes->new();
                   my $host = $vssh->{host}{$vssh->{group}};
                   my $c = scalar $range->load( $host )->list;
                   print "=" x $BTLEN, "  HOST: $c ", "=" x $BTLEN, "\n";
                   printf "%s\n", $range->load( $host )->dump;
                   
                   my %node = map{ $_ => 1 }$range->load( $host )->list;

                   map{
                       my $filter = $_;
                       $filter =~ s/^\+//;
                       my $del = $filter =~ s/^-// ? 1 : 0;
                       my %N;
                       if( $filter =~ /^\// && $filter =~ /\/$/ )
                       {
                           $filter =~ s/^\///; $filter =~ s/\/$//;
                           %N = map{ $_ => 1 } grep{ $_ =~ /$filter/ } keys %node;
                       }
                       else
                       {
                           %N = map{ $_ => 1 } $range->load( $filter )->list;
                       }

                       if( $del )
                       {
		           map{ delete $node{$_} if $N{$_} }keys %node;
                       }
                       else
                       {
		           map{ delete $node{$_} unless $N{$_} }keys %node;
                       }
                   }@filter;

                   $c = scalar $range->load( [keys %node] )->list;
                   print "=" x $BTLEN, " FILTER: $c", "=" x $BTLEN, "\n";
                   printf "%s\n", $range->load( [keys %node] )->dump;
               },
     '.block' => sub
               {
                   my ( $vssh, %param ) = @_;
                   my @block = split ' ', $param{cmd};

                   shift @block;
                   return unless @block;

                   if( $block[0] eq 'clear' )
                   {
                       $vssh->{block}{$vssh->{group}} = {};
                       print "host namespace $vssh->{group} block clear.\n";
                       return;
                   }

                   my $cluster = NS::Hermes->new( $option->dump( 'range' ) );
                   my $range = NS::Hermes->new();
                   map{ s/^['"]//; s/['"]$//;$range->add($cluster->load( $_) ) }@block;

                   my ( %lock, %block );
                   map{ $_ =~s/^\*// ? $lock{$_} = 1 : $block{$_} = 1; }$range->list;

                   if( %lock )
                   {
                       $vssh->{block}{$vssh->{group}} = {};
                       map{ 
                           $vssh->{block}{$vssh->{group}}{$_} = 1 unless $lock{$_};
                       }@{$vssh->{host}{$vssh->{group}}};
                   }else
                   {
                        map{
                            $vssh->{block}{$vssh->{group}}{$_} = 1;
                        }keys  %block; 
                   }

                   map{ 
                       if( $vssh->{block}{$vssh->{group}}{$_} )
                       {
                            print BOLD RED "#$_";
                       }
                       else
                       {
                            print BOLD GREEN "$_";
                       }
                       print "\n";
                   }@{$vssh->{host}{$vssh->{group}}};
                   $vssh->dumpdb();
               },
 
    '.help' => sub
               {
                   my $hp = sub 
                   { 
                       my ( $k, $d ) = @_;
                       print BOLD BRIGHT_YELLOW $k; 
                       print ' ' x ( 12 - length $k );
                       my @d = split /\\n/, $d;
                       printf "  %s\n", shift @d if @d;
                       map{print ' ' x 16 , $_, "\n"}@d;
                   };
                   my $mhp = sub
                   {
                       map{ &$hp( $_, $HELP{$_}) }@_;
                       print "\n";
                   };
                   my $title = sub
                   {
                       my $t = shift;
                       my $l = int (( 50 - length $t ) / 2);
                       my $r = 50 - $l - length $t;
                       print '*' x $l , " $t ", '*' x $r, "\n";
                   };
                   map{ &$hp( $_, $HELP{$_}) }qw( .help );
                   &$title( 'host Ctrl' );
                   &$mhp( qw( .add .del .load .sort .block .filter ));

                   &$title( 'namespace' );
                   &$mhp( qw( .use .save .tmp .clearspace ));

                   &$title( 'user auth' );
                   &$mhp( qw( .sudo .unsudo .user .password ));

                   &$title( 'run Opt' );
                   &$mhp( '.tty ON|OFF', '.timeout', '.max','.quiet', '.verbose' );

                   &$title( 'show info' );
                   &$mhp( qw( .list .dump  .info ));

                   &$title( 'local cmd' );
                   &$mhp( qw( .rsync .mcmd .local ));

                   &$title( 'term' );
                   &$mhp( qw( .history .lock .clear ));
               },
);

sub ocmd
{
    my ( $vssh, %param ) = @_;

    my $key = ( split / /, $param{cmd} )[0];
    $key = '.help' unless $OCMD{$key};

    print PUSHCOLOR RED ON_GREEN  "#" x $BTLEN, " $key ", "#" x $BTLEN;
    print "\n";

    &{$OCMD{$key}}( @_ );

    print PUSHCOLOR RED ON_GREEN  "-" x ( $BTLEN * 2 + 2  + length $key );
    print "\n";
}



1;
