package NS::Apollo;
use strict;
use warnings;
use Carp;
use YAML::XS;

my $LEN = 65;

sub new
{
    my ( $class, %this ) = @_;
    map{ confess "$_ undef" unless $this{$_} }qw( conf code );
    bless \%this, ref $class || $class;
}

sub run
{
    my $this = shift;

    $this->{'stat'} = +{};
    $this->{'jobs'} = my $conf = eval{ YAML::XS::LoadFile $this->{conf} };
    if( $@ ){ print "[ERROR] load conf fail: $@\n"; return $this; }

    ( grep{!$_}map{$this->do(0,$_)}sort keys %$conf )
    ? warn "FAIL\n" : warn "OK\n";

    print "#" x $LEN, "\n";
    return $this;
}

sub do
{
    my ( $this, $deep, $name ) = @_;

    my $dd = sprintf " " x (4*$deep);
    print $dd,"=" x (($LEN-4*$deep)>0?($LEN-4*$deep):0), "\n";
    printf "%sapollo: $name\n", $dd;
    
    return $this->say( $dd, "stat", $name, $this->{'stat'}{$name} )
        if defined $this->{'stat'}{$name};

    my $conf = $this->{jobs}{$name};
    return $this->say( $dd, "load conf", $name, 0 )
        unless $conf && ref $conf eq 'HASH';

    my ( $apollo, $code, $param )
        = @$conf{qw( apollo code param )};

    map{ 
        return $this->say( $dd, "son", $name, 0 )
            unless $this->do( $deep +1, $_ )
    }@$apollo if $apollo && ref $apollo eq 'ARRAY';

    my $jobs = do "$this->{code}/$code" if $code;
    return say( $dd, "load code", 0 )
        unless ref $jobs eq 'CODE';

    my %param = ( 
        param => $param,
        say => sub{ printf "${dd}%s.\n", shift; } 
    );

    map{ 
        return 1 if $this->say($dd,$_,$name,&$jobs(%param,task =>$_))
    }qw( check apollo );
    return 0;
}

sub say
{
    my ( $this, $dd , $info, $name, $stat ) = @_;
    printf "${dd}$info %s.\n", $stat ? 'ok' : 'fail';
    return $this->{'stat'}{$name} = $stat;
}

1;
