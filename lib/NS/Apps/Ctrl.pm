package NS::Apps::Ctrl;

use strict;
use warnings;

use Carp;
use YAML::XS;
use NS::Apps::Route;

sub new
{
    my ( $class, %self ) = @_;

    map{ confess "$_ undef.\n" unless $self{$_} }qw( conf node );

    my $idc = ( split /\./, $self{node} )[2];
    $idc = 'default' unless $idc && -e "$self{conf}/route/$idc";

    $self{route} = NS::Apps::Route->new( "$self{conf}/route/$idc" );


    $self{macro}{idc} = $idc unless $self{macro}{idc};
    
    die "$self{node} apps undef.\n" unless
        $self{apps} = eval{ YAML::XS::Load $self{route}->get( node => $self{node}) };
    
    bless \%self, ref $class || $class;
}

sub do
{
    my ( $this, %param ) = @_;
    my ( $apps, $route, $macro ) = @$this{qw( apps route macro )};

    my ( @apps, $app ) = keys %$apps;

    unless( $param{apps} )
    {
        @apps == 1 ? $app = $apps[0]:
        @apps ? die sprintf "please select: | %s |\n", join ' | ', sort @apps 
              : die "no undef apps\n";
        
    }
    elsif( $param{apps} =~ /^\// && $param{apps} =~ /\/$/ )
    {
        $param{apps} =~ s/^\///;$param{apps} =~ s/\/$//;
        my @m = grep{ $_ =~ /$param{apps}/ }@apps;
        @m == 1 ? $app = $m[0]:
        @m ? die sprintf "match too more: | %s |\n", join ' | ', sort @m 
              : die "no match apps /$param{apps}/\n";
    }
    else
    {
        ( $param{force} || grep{ $param{apps} eq $_ }@apps )
            ? $app = $param{apps} : die "no select one app.\n";
    }

    die "get $app\'s config fail.\n"
        unless my $conf = $route->get( apps => $app );

    map{ $conf =~ s/\$env{$_}/$macro->{$_}/g; }keys %$macro;

    my $user = ( getpwuid $< )[0];
    $conf =~ s/sudo\s+-u\s+$user\s+-H\s+([^-])/$1/g;
    $conf =~ s/sudo\s+-u\s+$user\s+([^-])/$1/g;

    my $config = eval{ YAML::XS::Load $conf };
    die "load $app\'s config to yaml fail:$@\n" if $@;
    die "$app\'s config no HASH\n" unless $config && ref $config eq 'HASH';

    unless( $param{ctrl} && @{$param{ctrl}} )
    {
       YAML::XS::DumpFile \*STDOUT, $config;
       return;
    }

    for my $c ( @{$param{ctrl}} )
    {
        unless( $config->{$c} )
        {
            warn "WARN: $c undo. undef in config.\n"; next;
        }
        map{ 
            $this->syscmd( $c => $_ );
        }ref $config->{$c} eq 'ARRAY' ? @{$config->{$c}} : $config->{$c};
    }
}

sub syscmd
{
    my ( $this, $type ) = splice @_, 0, 2;
    warn join " ", "apps[$type]:", @_, "\n" if $this->{verbose};
    return system( @_ ) ? die "run $type ERROR" : $this;
}

1;
__END__
