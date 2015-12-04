package NS::Hermes::Cache;

=head1 NAME

NS::Hermes::Cache - Covert root cluster dbs into cache db

=head1 SYNOPSIS

 use NS::Hermes::Cache;

 my $cache = NS::Hermes::Cache->new
 ( 
     root => '/root/data/dir',
     cache => '/cache/data/dir',
 );

 $cache->make();

=cut
use strict;
use warnings;

use Carp;
use POSIX;
use YAML::XS;
use Digest::MD5;
use File::Spec;
use File::Copy;
use File::Basename;

use NS::Hermes::DBI::Root;
use NS::Hermes::DBI::Cache;

use NS::Util::NSStat;

our %LINK = ( md5 => '.md5', cdb => '.cdb', link => 'current' );

sub new
{
    my ( $class, %path ) = splice @_;

    for my $name ( qw( root cache ) )
    {
        confess "undefined $name" unless my $path = $path{$name};
        $path = readlink $path if -l $path;

        confess "invalid path $path: not a directory" unless -d $path;
        $path{$name} = File::Spec->rel2abs( $path );
    }

    map { $path{$_} = File::Spec->join( $path{cache}, $LINK{$_} ) } keys %LINK;
    bless \%path, ref $class || $class;
}

sub make
{
    my $self = shift;
    my ( $md5, $cdb, $root ) = @$self{ qw( md5 cdb root ) };

    unlink $md5, $cdb unless -f $md5 && -f $cdb; ## start over if either gone

    my $prev = YAML::XS::LoadFile( $md5 ) if -f $md5; ## load previous md5
    $prev = {} unless $prev && ref $prev eq 'HASH';

    my ( $handle, $diff, %curr ); ## connect to cache db
    $cdb = NS::Hermes::DBI::Cache->new( $cdb, $NS::Hermes::DBI::Cache::TABLE );

    for my $cluster ( grep { -f $_ } glob File::Spec->join( $root, '*' ) )
    {
        next unless open( $handle, $cluster ) && binmode $handle;

        my $name = File::Basename::basename( $cluster );
        my $prev = $prev->{$name};

        $curr{$name} = Digest::MD5->new()->addfile( $handle )->hexdigest();
        next if $prev && $prev eq $curr{$name}; ## compare md5, skip if same

        $diff = 1;
        $cdb->delete( name => [ 1, $name ] );   ## delete old
        $cluster = NS::Hermes::DBI::Root->new( $cluster );

        for my $attr ( $cluster->table() )      ## insert new
        {
            warn "$name: $attr\n";
            map { $cdb->insert( $name, $attr, @$_ ) } $cluster->dump( $attr );
        }
    }

    my @name = keys %curr;
    $cdb->delete( name => [ 0, @name ] ); ## delete removed clusters

    if ( $diff || keys %$prev != @name )  ## switch symlink to new cache
    {
        YAML::XS::DumpFile( $self->{md5}, \%curr );
        my $curr = POSIX::strftime( "%Y.%m.%d_%H:%M", localtime );

        unlink( $curr = File::Spec->join( $self->{cache}, $curr ) );
        File::Copy::copy( $self->{cdb}, $curr ) && unlink $self->{link};
        symlink File::Basename::basename( $curr ), $self->{link};
    }
    else
    {
        warn "no change\n";
    }

    NS::Util::NSStat->new( name => 'hermes.service.cache' )->write( 'stat' => '0' );
    return $self;
}

1;
