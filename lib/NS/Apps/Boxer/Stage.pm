package NS::Apps::Boxer::Stage;
use strict;
use warnings;

use Carp;
use YAML::XS;
use NS::Apps::Route;

use Data::Dumper;
use Sys::Hostname;

sub new
{
    my ( $class, %self ) = @_;

    map{ die "$_ undef.\n" unless $self{$_} }qw( name route );

    bless \%self, ref $class || $class;
}

sub stage
{
    my $this = shift;
    my ( $name, $version, $route, $force ) = @$this{qw( name version route force )};


    my $update = eval{ YAML::XS::Load $route->get( boxer => $name ) };
    die 'get update info fail.' unless $update && ref $update eq 'HASH';


    $update->{version} = $version if defined $version;
    YAML::XS::DumpFile \*STDOUT, $update;

    map{ die "$_ undef.\n" unless $update->{$_} }
        qw( LocalPath LocalLink version Depot );

    my $goto   = $update->{version} =~ s/^goto@// ? 1 : 0;
    my $rollback = $update->{version} =~ s/^rb@// ? 1 : 0;

    $update->{version} =~ s/\@todo.*/\@todo/;

    die 'version syntax error.' unless length $update->{version};

    my $package = "$update->{LocalPath}/$update->{version}";

    my $loadpackage =
        sprintf "%s rsync -av '$update->{Depot}/$update->{version}' '$update->{LocalPath}/'",
           $update->{RSYNC_PASSWORD} ? "RSYNC_PASSWORD=$update->{RSYNC_PASSWORD}" :'';

    if( $goto )
    {
        $package =~ s/\.tar.gz$|\.tar$//;
         die "no data $package" unless -e $package;
    }
    elsif( $update->{version} =~ /\@inc$|\@patch$/ )
    {
        if( $rollback )
        {
            my $rb = "$update->{LocalLink}/.tmp4deploy/$update->{version}";
            die "no data:$rb\n" unless -e $rb;
        }
        else
        {
            $this->syscmd( $loadpackage ) if ( $force || ! -e $package );
        }
    }
    elsif( $update->{version} =~ /\@todo$/ )
    {
        my $pack = $package;
        my $opt = $pack =~ s/\.tar\.gz\@todo$/\@todo/
                      ? 'z' ? $pack =~ s/\.tar\@todo$/\@todo/ : '' : undef;

        return unless ( $force || ! -e $pack );

        $this->syscmd( $loadpackage );
        map{ $this->syscmd( $_) }
            ( "mkdir -p '$pack'",  "tar -${opt}xvf '$package' -C '$pack'", "rm -f '$package'" )
                if defined $opt;
    }
    else
    {
        my $pack = $package;
        my $opt = $pack =~ s/\.tar\.gz$// ? 'z' ? $pack =~ s/\.tar$// : '' : undef;

        if( $rollback )
        {
            die "no data:$pack\@rb\n" unless -f "$pack\@rb";
            my $rb = eval{ YAML::XS::LoadFile "$pack\@rb"; };
            die "load $pack\@rb fail:$@\n" if $@;

            die "$pack\@rb syntax error.\n"
                unless $rb && ref $rb eq 'HASH' && $rb->{'link'} ;
            die "$rb->{'link'}: No such directory.\n" unless -e $rb->{'link'};
            print "stage $pack\@rb --> $rb->{'link'}\n"
        }
        else
        {

            return unless ( $force || ! -e $pack );

            $this->syscmd( $loadpackage );
           
            map{ $this->syscmd( $_) }
                ( "mkdir -p '$pack'", "tar -${opt}xvf '$package' -C '$pack'", "rm -f '$package'")
                    if defined $opt;
            print "stage $pack\n"
        }

    }
}

sub syscmd
{
    my $this = shift;
    warn join " ", "boxer:", join( ' && ', @_ ), "\n"
        if $this->{verbose};
    return system( @_ ) ? die "boxer ERROR" : $this;
}

1;
__END__
