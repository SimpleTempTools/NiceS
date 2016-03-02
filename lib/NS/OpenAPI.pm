package NS::OpenAPI;
use strict;
use warnings;
use Carp;

use JSON;
use LWP::UserAgent;
use NS::Util::OptConf;

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

    my $res = $self->{ua}->get( "$self->{addr}$uri" );
    my $cont = $res->content;
    return +{ stat => 0, info => $res->content } unless $res->is_success;

    my $data = eval{JSON::from_json $cont};
    return $@ ? +{ stat => 0, info => $@ } : $data;
}

sub get
{
    my $self = shift;
    my $res = $self->_get( @_ );
    $res->{stat} ? $res->{data} : die "openapi $res->{info}";
}

sub _post
{
    my ( $self, $uri, %form ) = @_;

    my $res = $self->{ua}->post( "$self->{addr}$uri", 
          Content => JSON::to_json(\%form), 'Content-Type' => 'application/json' );
    my $cont = $res->content;
    return +{ stat => 0, info => $res->content } unless $res->is_success;

    my $data = eval{JSON::from_json $cont};
    return $@ ? +{ stat => 0, info => $@ } : $data;

}

sub post
{
    my $self = shift;
    my $res = $self->_post( @_ );
    $res->{stat} ? $res->{data} : die "openapi $res->{info}";
}

1;
