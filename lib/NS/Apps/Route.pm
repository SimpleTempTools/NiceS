package NS::Apps::Route;

use strict;
use warnings;

use Carp;
use YAML::XS;
use File::Basename;
use LWP::UserAgent;
use Sys::Hostname;


sub new
{
    my ( $class, $conf, %self ) = splice @_, 0, 2;
    confess 'conf undef.' unless $conf;
    $self{route} = eval{ YAML::XS::LoadFile $conf };
    confess "load conf $conf error: $@\n" if $@;   
    confess "no ARRAY in $conf\n" unless ref $self{route} eq 'ARRAY';

    bless \%self, ref $class || $class;
}

sub get
{
    my ( $this, %param ) = @_;

    my $uri = delete $param{uri};
    $uri ||= 'apps';
    my $param = join '&', map{ sprintf "$_=%s", $param{$_}||'' }keys %param;
    map
    {
        my $data = _load( sprintf "http://%s/$uri?%s",$_, $param );
	return $data if defined $data;
    }@{$this->{route}};

    return undef;
}

sub _load
{
    my $url = shift;
    print "get: $url\n" if $ENV{nsdebug};
    my $ua = LWP::UserAgent->new;

    $ua->agent('Mozilla/9 [en] (Centos; Linux)');
    $ua->timeout(5);
    $ua->default_header ( 'Cache-control' => 'no-cache', 'Pragma' => 'no-cache');

    my $res = $ua->get( $url );
    return $res->is_success ? $res->content : undef;
}

1;
