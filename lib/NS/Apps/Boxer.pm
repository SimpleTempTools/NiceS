package NS::Apps::Boxer;

use strict;
use warnings;

use Carp;
use YAML::XS;
use NS::Apps::Route;

use Data::Dumper;
use Sys::Hostname;
use NS::Apps::Boxer::PP;

use NS::Apps::Boxer::Stage;
use NS::Apps::Boxer::Update;
our $interactive = 0;

sub new
{
    my ( $class, %self ) = @_;

    map{ confess "$_ undef.\n" unless $self{$_} }qw( conf node );

    my $idc = ( split /\./, $self{node} )[2];
    $idc = 'default' unless $idc && -e "$self{conf}/route/$idc";

    $self{route} = NS::Apps::Route->new( "$self{conf}/route/$idc" );

    bless \%self, ref $class || $class;
}

my %job =
(
    help => sub{
  print qq(
  boxer>help
  push\tpush data to depot.ex: push appname:appversion /tmp/localpath.
  pull\tpush data from depot.ex: push appname:appversion /tmp/localpath.
  depot\tshow depot.

  package\tshow package info.
  \t\tboxer>package    : show outline
  \t\tboxer>package foo: show foo info

  status\tshow status.
  \t\tboxer>status         : show outline
  \t\tboxer>status foo     : show foo status
  \t\tboxer>status foo:001 : show foo status about version 001

  history\tshow history.
  \t\tboxer>history    : show all history
  \t\tboxer>package foo: show history for foo

  lock\t lock the package version

  );

                   return;
                },
    depot => sub{
                   print shift->{route}->get( uri => 'boxer/depot' ) || return 'get info error.';
                   return;
                },

    'package' => sub{
                       my ( $this, %param ) = @_;
                       print $this->{route}->get( 
                                 uri => 'boxer/package',
                                 name => $param{opt1}
                            ) || return 'get info error.';
                       return;
                    },
 
    'history' => sub{
                   my ( $this, %param ) = @_;
                   print $this->{route}->get( 
                             uri => 'boxer/history',
                             name => $param{opt1}
                        ) || return 'get info error.';
                   return;
              },

   'status' => sub{
                   my ( $this, %param ) = @_;
                   my ( $name, $version ) = @param{qw( name version )};
                   $name ||= $param{opt1};

                   print $this->{route}->get(
                       uri => 'boxer/status',
                       name => $name,
                       version => $version 
                   ) || return 'get info error.';
                   return;
              },
 

    'push' => sub{
                   my ( $this, %param ) = @_;

                   my $pp = eval{ NS::Apps::Boxer::PP->new( 
                                  %param, %$this, path => $param{opt2} );
                              };
                   return "param syntax error: $@\n" if $@;

                   eval{ $pp->run( job => $param{job} ) };
                   return $@;
              },


    'stage' => sub{
                   my ( $this, %param ) = @_;

                   my $stage = eval{
                       NS::Apps::Boxer::Stage->new(
                           %$this, %param, version => $param{version} || $param{opt1} )
                   };
                   return "param syntax error: $@\n" if $@;
                   eval{ $stage->stage() };
                   return $@;
              },
 
    'update' => sub{
                   my ( $this, %param ) = @_;

                   my $update = eval{ 
                       NS::Apps::Boxer::Update->new(
                         %$this, %param, version => $param{version} || $param{opt1})
                   };
                   return "param syntax error: $@\n" if $@;
                   eval{ $update->update() };
                   return $@;
              },
 
    'lock' => sub{
                   my ( $this, %param ) = @_;
                   my ( $name, $version ) =
                       map{ $param{$_} ? $param{$_} : return 'param syntax error.' }
                           qw( name version );

                   printf "lock: name:$name; version:$version; %s\n",
                       $this->{route}->get( 
                           uri => 'boxer/lock',
                           name => $name,
                           version => $version,
                           force => $param{force} ? 1: 0
                       );
                   return;
              },
 
);

$job{'pull'} = $job{'push'};

sub do
{
    my $this = shift;
    my ( $job, $param ) = split /\s+/, shift||'help', 2;
    $job = 'help' unless $job{$job};
    my $error = &{$job{$job}}( $this, job => $job ,param( $param ) );

    $error ? $interactive
    ? print "ERROR: $error\n" 
    : die "FAIL: $error\n" : print "\n";
}

sub syscmd
{
    my $this = shift;
    warn join " ", "boxer:", join( ' && ', @_ ), "\n"
        if $this->{verbose};
    return system( @_ ) ? die "boxer ERROR" : $this;
}

sub param
{
    my ( $param, %param ) = shift;
    return () unless defined $param;   

    $param{force} = ( $param =~ s/\bforce\b//  )? 1: 0;
    my $i = 1;
    map{ $param{"opt$i"} = $_; $i ++ }split /\s+/, $param;

        ( $param{name}, $param{version} ) = ( $1, $2 )
    if ( $param{opt1} && $param{opt1} =~ /^([^:]+):(.+)$/ );

    return %param;
}

1;
__END__
