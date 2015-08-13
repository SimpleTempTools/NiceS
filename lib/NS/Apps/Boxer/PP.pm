package NS::Apps::Boxer::PP;

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

    map{ die "$_ undef.\n" unless $self{$_} }qw( name version path route user );
    $self{path} =~ s/\/*$//;
    
    $self{path} = readlink $self{path} if -l $self{path};

    die "$self{path}: No such file or directory.\n"
        unless -f $self{path} || -d $self{path};

    bless \%self, ref $class || $class;
}

sub run
{
    my ( $this, %param ) = @_;
    my ( $name, $version, $path, $route, $user )
         = @$this{qw( name version path route user )};

    print "name:\t$name\nvers:\t$version\npush:\t$path\n";

    my $package = eval{ YAML::XS::Load
        $route->get( uri => 'boxer/package', name => $name )
    };
    die "get package $name info fail.\n" unless $package && ref $package eq 'HASH';


    my $Depot = eval{ YAML::XS::Load $route->get( uri => 'boxer/depot' ) };
    die "get depot info fail." unless $Depot && ref $Depot eq 'HASH';

    die "$user no Authorized.\n"
        unless(
            $package->{Authorized}
            && ref $package->{Authorized} eq 'ARRAY'
            && grep{$_ eq $user}@{$package->{Authorized}}
        );


    die "Depot unkown.\n"
         unless( $package->{Depot} && ref  $package->{Depot} eq 'ARRAY' );



    my %depot = map{ $_ => 1 }@{$package->{Depot}};
    for my $depot ( keys %depot )
    {
        print "depot: $depot\n";
        my $conf = $Depot->{$depot};

        unless ( $conf ) { print "depot $depot undef.\n"; next; }
        unless( $conf->{'push'} ) { print "depot addr undef.\n"; next; }

        my $pw = $conf->{RSYNC_PASSWORD} ? "RSYNC_PASSWORD=$conf->{RSYNC_PASSWORD}" :'';
        my $stat  = ( $param{job} && $param{job} eq 'pull' )
            ? $this->_pull( depot => $depot, conf => $conf, pw => $pw )
            : $this->_push( depot => $depot, conf => $conf, pw => $pw );

        last if $stat && $stat eq 'success';
    }
}

sub _pull
{
        my ( $this, %param ) = @_;
        my ( $depot, $conf, $pw ) = @param{ qw( depot conf pw ) };

        my ( $name, $version, $path, $route, $user )
             = @$this{qw( name version path route user )};

        my $rsync = "$pw rsync -av '$conf->{'push'}/$name/$version' '$path/'";

        print "$rsync\n" if $this->{verbose};
        return system( $rsync ) ? 'fail' : 'success';
}

sub _push
{
        my ( $this, %param ) = @_;
        my ( $depot, $conf, $pw ) = @param{ qw( depot conf pw ) };

        my ( $name, $version, $path, $route, $user )
             = @$this{qw( name version path route user )};

        $this->_history( sprintf "$user from %s push $name:$version to depot $depot", hostname );
        
        my $rsync = sprintf "$pw rsync -av '$path%s' '$conf->{'push'}/$name/$version%s'",
                ( -f $path ) ? ( '', '' ) : ( '/', '/' );

        print "$rsync\n" if $this->{verbose};
        my $stat = system( $rsync ) ? 'fail': 'success';

        $this->_history( "$user push $name:$version to depot $depot $stat" );

        return if $stat eq 'fail';
        my %sto = (
                uri => 'boxer/recoder', recoder => 'status', name => $name,
                version => $version, depot => $depot,
        );

        if( $conf->{stored} )
        {
            my %stored = map{ $_ => 1 }split /:/, $conf->{stored};
            map {
                printf "mark $_ to $depot %s\n", $route->get(
                    %sto, stored => $_, status => 'WaitingForSync'
                ) ||'unkown';
            }keys %stored;

            printf "mark self to $depot %s\n", $route->get(
                %sto, stored => 'self', status => 'WaitingForStored'
            ) ||'unkown';
        }
        else
        {
            printf "mark self to $depot %s\n", $route->get(
                %sto, stored => 'self', status => 'HasBeenSync'
            ) || 'unkown';
        }
}

sub _history
{
    my $this = shift;
    my ( $name, $route ) = @$this{qw( name route )};

    $route->get(
        uri => 'boxer/recoder', recoder => 'history',
        name => $name, type => 'push', info => shift
    );
}

1;
__END__
