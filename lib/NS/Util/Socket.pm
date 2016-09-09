package NS::Util::Socket;
use IO::Socket;
use IO::Socket::Socks;
use File::Spec;

use NS::Util::OptConf;
=head1 NAME

Vulcan::Proxy - Make socket throuth socks proxy.

=head1 SYNOPSIS
proxy:
  '\.idcfoo\.': 'localhost:8801'
  '\.idcbar\.': 'localhost:8802'

 use Vulcan::Proxy;
 my $proxy = Vulcan::Proxy->new();

 #'localhost:8802'
 $proxy->string("xxx.idcbar.net");

 #socket throuth 'localhost:8802'
 my $socket = $proxy->tcp( PeerAddr => $node, Blocking => 0, Timeout => $timeout );

=cut

sub new
{
    my $class = shift;
    my %util = NS::Util::OptConf->load()->dump( 'util' );
    my %proxy = NS::Util::OptConf->load(File::Spec->join($util{conf}, 'socks'))->dump('proxy');
    %proxy = map{
        my $reg = eval{qr/$_/};
        ref $reg eq "Regexp" ? ( $reg => $proxy{$_} ) : ()
    }keys %proxy;

    return bless { %proxy }, $class;
}

sub string { _match(@_) }
sub socks { my $str = _match(@_); $str ? "socks://$str" : undef}
sub tcp { _socket('tcp', @_) }
sub udp { _socket('udp', @_) }

sub _match
{
    my($this, $node) = splice @_;
    my($key) = grep{ $node =~ $_ }%$this;
    $key ? $this->{$key} : undef;
}

sub _socket
{
    my($type, $this, %inet, $socket) = @_;
    warn "some of 'PeerAddr Blocking Timeout' are missing" and return
        if grep{ ! exists $inet{$_} } qw(PeerAddr Blocking Timeout);

    my $proxy = $this->string( $inet{PeerAddr} );
    my( $caddr, $cport, %copt) = $inet{PeerAddr} =~ /(.+):(.+)/;
    my( $paddr, $pport ) = $proxy =~ /(.+):(.+)/;

    %copt = $type eq "tcp" ? ( ConnectAddr => $caddr, ConnectPort => $cport) :
            $type eq "udp" ? ( UdpAddr => $caddr, UdpPort => $cport) : ();

    $socket = IO::Socket::Socks->new
    (
        %copt, ProxyAddr => $paddr, ProxyPort => $pport,
        Blocking => $inet{Blocking}, Timeout => $inet{Timeout},

    ) if $proxy && $caddr && $cport && $paddr && $pport && %copt;

    $socket = IO::Socket::INET->new( %inet ) unless $socket;
    return $socket;
}
1;
