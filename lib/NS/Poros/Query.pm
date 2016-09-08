package NS::Poros::Query;

=head1 NAME

NS::Poros::Query - NS::Poros query 

=head1 SYNOPSIS

 use NS::Poros::Query;

 my $query = NS::Poros::Query->dump( \%query ); ## scalar ready for transport

 my $code = NS::Poros::Query->load( $query );

 print $code->yaml();

 my $result = $code->run( code => '/code/dir', run => '/run/dir' );

=cut
use strict;
use warnings;

use Carp;
use POSIX;
use YAML::XS;
use File::Spec;
use File::Basename;
use Compress::Zlib;
use FindBin qw( $RealBin );
use NS::Poros::Auth;
use NS::Util::OptConf;
use NS::Util::ProcLock;

our $CA = 86400;

=head1 METHODS

=head3 dump( $query )

Returns a scalar dumped from input HASH.

=cut
sub dump
{
    my ( $class, $query ) = splice @_;

    confess "invalid query" unless $query
        && ref $query eq 'HASH' && defined $query->{code};

    my %o = NS::Util::OptConf->load()->dump( 'poros' );
    if( $o{'auth'} && -d $o{'auth'} && $query->{code} !~ /^free\./ )
    {
        my $time = time;
        $query->{peri} = join '#', $time - $CA, $time + $CA;
        $query->{auth} = NS::Poros::Auth->new( $o{'auth'} )->sign( YAML::XS::Dump $query );
    }
    
    return Compress::Zlib::compress( YAML::XS::Dump $query );
}

=head3 load( $query )

Inverse of dump().

=cut
sub load
{
    my ( $class, $query, $yaml ) = splice @_;

    die "invalid $query\n" unless
        ( $yaml = Compress::Zlib::uncompress( $query ) )
        && eval { $query = YAML::XS::Load $yaml }
        && ref $query eq 'HASH' && $query->{code};

    my %o = NS::Util::OptConf->load()->dump( 'poros' );
    if( $o{'auth'} && -d $o{'auth'} && $query->{code} !~ /^free\./ )
    {
        my $auth = delete $query->{auth};
        die "auth fail\n" unless NS::Poros::Auth->new(  $o{'auth'} )
        ->verify( $auth, YAML::XS::Dump $query );
        die "peri undef\n" unless my $peri = delete $query->{peri};
        my @peri = split '#', $peri;
        die "peri fail\n" unless $peri[0] < time && time < $peri[1];
    }
    bless { yaml => $yaml, query => $query }, ref $class || $class;
}

=head3 run( %path )

Run code in $path{code}. If code name is postfixed with '.mx',
run code in mutual exclusion mode.

=cut
sub run
{
    my ( $self, %path ) = @_;
    my $query = $self->{query};
    my ( $code, $user ) = @$query{ qw( code user ) };

    die "already running $code\n" if ( $code =~ /\.mx$/ ) && !
        NS::Util::ProcLock->new( File::Spec->join( $path{run}, $code ) )->lock();

    die "invalid code\n" unless
        -f ( $code = File::Spec->join( $path{code}, $code ) )
        && ( $code = do $code ) && ref $code eq 'CODE';

    if ( ! $< && $user && $user ne ( getpwuid $< )[0] )
    {
        die "invalid user $user\n" unless my @pw = getpwnam $user;
        @pw = map { 0 + sprintf '%d', $_ } @pw[2,3];
        POSIX::setgid( $pw[1] ); ## setgid must preceed setuid
        POSIX::setuid( $pw[0] );
    }

    &$code( pdir => File::Basename::dirname( $RealBin ), %$query );
}

=head3 yaml()

Return query in YAML.

=cut
sub yaml
{
    my $self = shift;
    return $self->{yaml};
}

1;
