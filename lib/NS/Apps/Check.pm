package NS::Apps::Check;

use strict;
use warnings;

use Carp;
use YAML::XS;
use NS::Apps::Route;

sub new
{
    my ( $class, %self ) = @_;

    map{ confess "$_ undef.\n" unless $self{$_} }qw(  check node host );

    $self{check} = eval { YAML::XS::LoadFile( $apps{check} ) };
    die "load conf fail.\n" 
        unless ! $@ && $self{check} && ref $self{check} eq 'HASH';
    
    bless \%self, ref $class || $class;
}

sub check
{
    my ( $this, @check ) = @_;
    my ( $config, $node, $host ) = @this{qw( check node host )};

    unless( @check )
    {
        my $c = eval{ YAML::XS::LoadFile $node };
        die "load node conf fail\n" unless ! $@ && $c && ref $c eq 'HASH';;

        @check = keys %{$c{$host}} if $c{$host};
    }
    
    for( @check )
    {
        next unless my $conf = $config->{$_};
        for my $c ( ref $conf eq 'ARRAY' ? @$conf : ( $conf ) )
        {
            die "invalid conf: no HASH" if ref $c ne 'HASH';
            $this->_http( %$c ) if $c->{http};
            $this->_port( %$c ) if $c->{port} || $c->{tcp} || $c->{udp};
            $this->_code( %$c ) if $c->{code};
            $this->_dns(  %$c ) if $c->{domain};
            $this->_domain( %$c ) if $c->{dns};
        }
    }
}

sub _dns
{
    my ( $this, %conf ) = @_;
    my @to = __dig( $conf{domain} , $this->{host}, $conf{timeout} );
    printf "to: %s\n", join ',', @to if $this->{verbose};

    @to ? print "$host <> to $conf{domain} :OK\n" : die "$host <> to $conf{domain} :FAIL\n";
}

sub __dig
{
    my ( $domain, $dns, $timeout, @ser ) = splice @_, 0, 3;
    for( 1..2 )
    {
        last if @ser = map{ inet_ntoa( $_ ) }
            Net::DNS::Dig->new( PeerAddr => $dns, Timeout => $timeout || 5 )
                ->for( $domain )->rdata();
    }
    return @ser;
}

sub _domain
{
    my ( $this, %conf ) = @_;
    my @to = __dig( $this->{host}, $conf{dns} , $conf{timeout} );

    printf "to: %s\n", join ',', @to if $this->{verbose};

    @to ? print "$host <> from $conf{dns} :OK\n" : die "$host <> from $conf{dns} :FAIL\n";
}

sub _code
{
    my ( $this, %conf ) = @_;
    my ( $host, $code ) = ( $this->{host}, $conf{code} );

    die "$host <> $code :FAIL [no code]\n" unless -x $code;
    system( "$code $host" ) ? die "$host <> $code :FAIL\n" : print "$host <> $code :OK\n";
}

sub _port
{
    my ( $this, %conf ) = @_;
    my ( $host, $port, $t ) = $this->{host};
    map{ if( $conf{$_} ){ $t = $_; $port = $conf{$_}; } }qw( tcp udp port );

    my $info = sprintf "$host <>$t $port";
    __ioso( "$host:$port", $t eq 'port' ? '' : $t )
        ? print "$info :OK\n" : die "$info :FAIL\n";
}

sub __ioso
{
    my ( $addr, $proto ) = @_;
    return IO::Socket::INET->new(
         PeerAddr => $addr, Blocking => 0,
         Timeout => 10, Type => SOCK_STREAM,
         $proto ? ( Proto => $proto ) : ()
    );
}

sub _http
{
    my ( $this, %conf ) = @_;
    my $host = $this->{host};

    $conf{http} =~ s/{}/$host/g;
    Encode::_utf8_off( $conf{check} ) if defined $conf{check};
    my $info = $conf{check} || '';
    __check_http_conten( %conf )
        ? print "$conf{http} <> $info :OK\n" : die "$conf{http} <> $info :FAIL\n";
}

sub __check_http_conten
{
    my %conf = @_;
    my $content = __ua( %conf );
    print "$content\n" if $content && $verbose;
    ( ( defined $content ) && ( ! defined $conf{check} || $conf{check} eq '' || $content =~ /$conf{check}/ ) )
      ? 1 : 0;
}

sub __ua
{
    my %conf = @_;

    my %opt = $conf{http} =~ /^https/ ? ( ssl_opts => { verify_hostname => 0 } ) :();

    my $ua = LWP::UserAgent->new( %opt );
    $ua->agent('Mozilla/9 [en] (Centos; Linux)');
    $ua->timeout( 10 );
    $ua->default_header ( 
        'Cache-control' => 'no-cache', 'Pragma' => 'no-cache', Host => $conf{Host}
    );
    my $res = $conf->{Content} ? $ua->post( $conf{http},Content => $conf->{Content} ) :
          $conf{from} ? $ua->post( $conf{http}, $conf{from} )
             : $ua->get( $conf{http} );
    $res->is_success ? $res->content : undef;
}




1;
__END__
