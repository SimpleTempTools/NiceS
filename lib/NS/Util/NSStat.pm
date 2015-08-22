package NS::Util::NSStat;

use strict;
use warnings;
use Carp;

use  NS::Util::OptConf;
use YAML::XS;
use File::Basename;
use Data::Dumper;
use POSIX;
use Tie::File;

use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;

use constant effective => 180;

binmode STDOUT, ':utf8';

our $stat;
BEGIN {
    $stat = NS::Util::OptConf->load()->dump('ns')->{stat};

    die "stat undef" unless $stat;
    mkdir $stat unless $stat;
};

sub new
{
    my ( $class, %self ) = splice @_;

    bless \%self, ref $class || $class;
}

sub write
{
    my ( $this, $type, $mesg ) = @_;
    return unless ( my $name = $this->{name} ) && $type;
    
    warn "[$type]: $mesg\n";
    eval{
        warn "tie stat fail.\n" unless tie my @err , 'Tie::File', "$stat/$name.$type";
        @err = ( $mesg );
    };
    warn "error: $@\n" if $@;
}

sub watch
{
    my $this = shift;
    my ( $stat, $interval, $effective ) = @$this{qw( stat interval effective )};
    $effective ||= effective;
    
    my $conf = eval{ 
        YAML::XS::LoadFile sprintf "%s/ns.stat", 
            NS::Util::OptConf->load()->dump('util')->{conf}
    };

    do
    {
        system 'clear';
        my %stat = map{ $_ => ( stat $_ )[10]} glob "$stat/*.stat";

        map
        {
             my $name = basename $_;
             $name =~ s/\.stat$//;
             my  $effe = $conf->{$name}{effe} || $effective;

             printf "%s : ", POSIX::strftime( "%Y-%m-%d_%H:%M:%S", localtime( $stat{$_} ) ),

             my $status = `cat $_`; $status =~ s/\n//g;

             print "status(";
             $status ? ( print BOLD RED $status ) : ( printf BOLD GREEN $status );
             print ") ";

             my $time = time - $stat{$_};
             $time > $effe ? ( print BOLD RED $time ) : ( printf BOLD GREEN $time );
             print "(s): $name\n";
             my $error = $status || $time > $effe ? 1: 0;

             $_ =~ s/\.stat$/\.error/;

             for( glob "$_*" )
             {
                 my $t = ( stat $_ )[10];
                 next if $t < time - $effe;
                 my $n = $_ =~ /(error\d*)$/ ? $1 : basename $_;
                 printf "  $n: %s(s)\n    ", time - $t;
               
                 my $cont = `cat $_`;
                 $cont =~ s/\n/\n    /;
                 print "$cont\n";
                 $error = 1;
             }

             print BOLD RED "desc: $conf->{$name}{desc}\n" if $conf->{$name}{desc} && $error;

        }sort{ $stat{$a} <=> $stat{$b} }keys %stat;

    }while( $interval && sleep $interval );
}

1;
