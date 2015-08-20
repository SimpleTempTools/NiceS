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

use NS::Hermes;

use NS::Util::OptConf;
use NS::VSSH::OCMD::Help;
use NS::VSSH::OCMD::History;

$|++;

my $option = NS::Util::OptConf->load();

sub new
{
    my ( $this, %self ) = @_;
    map{ die "$_ undef." unless $self{$_} }qw( hostdb config user );

    $self{help} = NS::VSSH::OCMD::Help->new();
    $self{history} = NS::VSSH::OCMD::History->new( 
        user => $self{user}, path => $self{config}{tmppath}
     );
    bless \%self, ref $this || $this;
}

sub run
{
    my ( $this, $exec ) = @_;
    my ( $type, @argv ) = split /\s+/, $exec;

    $this->{help}->head( $type );

    my @e = $type eq '.list' ? $this->list( @argv )
      : $type eq '.info' ? $this->info( @argv ) 
      : $type eq '.dump' ? $this->dump( @argv ) 
      : $type eq '.use' ? $this->use( @argv )
      : $type eq '.cleardb' ? $this->cleardb( @argv )
      : $type eq '.sort' ? $this->sort( @argv )->list()
      : $type eq '.config' ? $this->config( @argv )
      : $type eq '.clear' ? $this->clear( @argv )
      : $type eq '.history' ? $this->history( @argv )
      : $type eq '.debug' ? $this->debug( @argv )
      : $type eq '.sudo' ? $this->sudo( @argv )
      : $type eq '.unsudo' ? $this->unsudo( @argv )
      : $type eq '.rsync' ? $this->rsync( @argv )
      : $type eq '.mcmd' ? $this->mcmd( $exec ) ##exec
      : $type eq '.expect' ? $this->expect( $exec ) ##exec
      : ( $type eq '.add' || $type eq '.del' ) ? $this->node( $type, @argv )->list()
    : $this->help( @argv );

    $this->{help}->tail( $type );

    return ( grep{ $type eq $_ }qw( .rsync .mcmd .expect ) ) ? @e : ();
}


sub list
{
    my $this = shift;
    map{ print $_, "\n"; }$this->{hostdb}->load();
    return $this;
}

sub dump
{
    my $this = shift;
    print NS::Hermes->new()->load( [ $this->{hostdb}->load() ] )->dump ,"\n";
    return $this;
}

sub use
{
    my ( $this, $use ) = @_;
    printf "use: %s\n", $this->{hostdb}->use( $use );
}

sub cleardb
{
    my ( $this, @db ) = @_;
    map{ $this->{hostdb}->clear($_);print "delete: $_\n"; }
        @db ? @db : $this->{hostdb}->use();
    return $this;
}

sub info
{
    my $this = shift;
    print "Host DB:\n";
    my $range = NS::Hermes->new();
    map { 
        my @node = $this->{hostdb}->load( $_ );
        printf "  $_:\n    count: %s\n    hosts:%s\n",
            scalar @node, $range->load( \@node )->dump;
    }sort $this->{hostdb}->list();
 
    return $this;
}

sub sort
{
    my ( $this, $sort ) = @_;
    $this->{hostdb}->sort( $sort );
    return $this;
}

sub config
{
    my ( $this, $cmd ) = @_;
    my ( $k, $v ) = $cmd ? $cmd =~ /^([^=]+)=([\w\/]+)\s*$/ : ();

    unless( $k )
    {
        my $config = $this->{config};
        while( my ( $n1, $v1 ) = each %$config )
        {
            if ( ref $v1 eq 'HASH' )
            {
                 while( my ( $n2, $v2 ) = each %$v1 )
                 {
                     print "$n1.$n2=$v2\n";
                 }

            }
            else { print "$n1=$v1\n"; }
        }
    }
    else
    {
         if( $k =~ /^([^.]+)\.(.+)$/ )
         {

             my ( $a, $b ) = ( $1, $2 );
             if( $this->{config}{$a}{$b} 
                 && $this->{config}{$a}{$b} =~ /^\d+$/
                 && $v && $v !~ /^\d+$/ 
             )
             { warn "$v no a number.\n"; return; }

             $this->{config}{$a}{$b} = $v;
             print "$a:$b=$v\n";
         }
         else
         {
             if( $this->{config}{$k} 
                 && $this->{config}{$k} =~ /^\d+$/ 
                 && $v && $v !~ /^\d+$/
             )
             { warn "$v no a number.\n"; return; }

             $this->{config}{$k} = $v;
             print "$k=$v\n";
         }
    }
}

sub clear { system 'clear'; }

sub history
{
     my $this = shift;
     my $i = 0;
     map{ print "  $i  $_\n"; $i++; }$this->{history}->list();
}

sub sethistory
{
    my $this = shift;
    $this->{history}->push( @_ );
}

sub sudo
{
    my ( $this, $sudo ) = @_;
    my $u = $this->{config}{sudo} = $sudo || 'root';
    print "set sudo: $u\n";
}

sub unsudo
{
    my $this = shift;
    $this->{config}{sudo} = '';
    print "set sudo: nusudo\n";
}

sub debug
{
    my ( $this, $switch ) = @_;
    if( $switch && $switch eq 'on' )
    {
        $ENV{nsdebug} = 1;
    }
    elsif( $switch && $switch eq 'off' )
    {
        $ENV{nsdebug} = 0;
    }
    else
    {
        YAML::XS::DumpFile \*STDOUT, $this;
    }
    printf "debug: %s\n", $ENV{nsdebug} ? 'on' : 'off';
    return $this;
}

## add del
sub node
{
    my ( $this, $ch, @add, @host ) = @_;

    unless( @add )
     {
         print "Please enter your machine list, to the end of END\n";
         my $END = $/; $/ = 'END';
         my $host = <STDIN>;
         $/ = $END;
         
         $host =~ s/END$//;
         print "LOADING ...\n";
         @host = split "\n", $host;
     }
     else
     {
         my $cluster = NS::Hermes->new( $option->dump( 'range' ) );
         my $range = NS::Hermes->new();
         map{ s/^['"]//; s/['"]$//; $range->add( $cluster->load( $_ ) )}@add;
         @host = $range->list;
     }

     $ch eq '.add' ? $this->{hostdb}->add( @host ): $this->{hostdb}->del( @host );
     return $this;
}

sub rsync
{
    my ( $this, @rsync ) = @_;
    my ( $src, $dst );
    $src = shift @rsync;

    unless( $src ) { $this->help( 'rsync' ); return; }
    unless( -e $src ){ print BOLD  RED "$src: No such file or directory\n"; return; }

    $dst = ( @rsync && $rsync[0] !~ /^-/ ) ? shift @rsync : $src;


    $src = sprintf "%s%s", abs_path( $src ), $src =~ /\/$/ ? '/' :'' if $src !~ /^\//;
    $dst = sprintf "%s%s", abs_path( $dst ), $dst =~ /\/$/ ? '/' :'' if $dst !~ /^\//;


    if( $src =~ /\s+/ || $dst =~ /\s+/ )
    {
        print BOLD  RED "has \\s+ in the path\n"; return;
    };

    my $opt = join ' ', @rsync;

    print "src: $src\ndst: $dst\nopt: $opt\n";

    my $cmd = "rsync $src $this->{user}\@{}:$dst $opt";
    return $this->{help}->yesno() ? ( 'rsync', $cmd ) : undef;
}

sub mcmd
{
    my ( $this, $exec ) = @_;
    $exec =~ s/^\.mcmd\s*//;
    return ( 'mcmd', $exec );
}

sub expect
{
    my ( $this, $exec ) = @_;
    $exec =~ s/^\.expect\s*//;
    return ( 'expect', $exec );
}

sub help
{
    my $this = shift;
    $this->{help}->help( shift );
    return $this;
}

sub welcome
{
    my $this = shift;
    $this->{help}->welcome();
    return $this;
}

