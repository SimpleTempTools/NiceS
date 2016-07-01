package NS::OpenAPI;
use strict;
use warnings;
use Carp;

use JSON;
use LWP::UserAgent;
use NS::Util::OptConf;
use URI::Escape;
use NS::OpenAPI::Logs;

my $addr; BEGIN{ $addr = NS::Util::OptConf->load()->dump('openapi')->{addr}; };

sub new 
{
    my ( $class, %self ) = splice @_;

    $self{addr} = $ENV{nices_openapi_addr} || $addr;
    confess "openapi addr undef" unless $self{addr};

    $self{ua} = my $ua = LWP::UserAgent->new();
    $ua->agent('Mozilla/9 [en] (Centos; Linux)');
    $ua->timeout( 10 );
    $ua->default_header ( 'Cache-control' => 'no-cache', 'Pragma' => 'no-cache' );

    bless \%self, ref $class || $class;
}

sub _get
{
    my ( $self, $uri ) = @_;

#    $uri = URI::Escape::uri_escape( $uri );

    $uri =~ s/ /%20/g;
    my $res = $self->{ua}->get( "$self->{addr}$uri" );
    print "get $self->{addr}$uri\n" if $ENV{NS_DEBUG};
    my $cont = $res->content;
    return +{ stat => JSON::false, info => $res->content } unless $res->is_success;

    my $data = eval{JSON::from_json $cont};
    return $@ ? +{ stat => JSON::false, info => $@ } : $data;
}

sub get
{
    my $self = shift;

    my ( $uri ) = @_;
    if( $ENV{NS_OpenAPI_Retry} )
    {
        my $logs = NS::OpenAPI::Logs->new();
        while( 1 )
        {
            my $res = $self->_get( @_ );
            return $res->{data} if $res->{stat};
            my $error = "openapi $uri err: $res->{info}";
            warn "$error\n";
            $logs->put( type=> 'ERROR', info => $error );
            sleep 3;
        }
    }
    else
    {
        my $res = $self->_get( @_ );
        $res->{stat} ? $res->{data} : die "openapi $uri err: $res->{info}\n";
    }
}

sub _post
{
    my ( $self, $uri, %form ) = @_;

    $uri =~ s/ /%20/g;
    print "post $self->{addr}$uri\n" if $ENV{NS_DEBUG};
    my $res = $self->{ua}->post( "$self->{addr}$uri", 
          Content => JSON::to_json(\%form), 'Content-Type' => 'application/json' );
    my $cont = $res->content;
    return +{ stat => JSON::false, info => $res->content } unless $res->is_success;

    my $data = eval{JSON::from_json $cont};
    return $@ ? +{ stat => JSON::false, info => $@ } : $data;

}

sub post
{
    my $self = shift;

    my ( $uri ) = @_;
    if( $ENV{NS_OpenAPI_Retry} )
    {
        my $logs = NS::OpenAPI::Logs->new();
        while( 1 )
        {
            my $res = $self->_post( @_ );
            return $res->{data} if $res->{stat};
            my $error = "openapi $uri err: $res->{info}";
            warn "$error\n";
            $logs->put( type=> 'ERROR', info => $error );
            sleep 3;
        }
    }
    else
    {
        my $res = $self->_post( @_ );
        $res->{stat} ? $res->{data} : die "openapi $uri err $res->{info}\n";
    }

}

1;
