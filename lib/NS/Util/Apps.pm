package NS::Util::Apps;

use strict;
use warnings;

use Carp;
use YAML::XS;
use NS::Apps::Route;

sub new
{
    my ( $class, %self ) = @_;
    confess "data undef.\n" unless $self{data};
    bless \%self, ref $class || $class;
}

sub do
{
    my ( $this, %param ) = @_;
    my $data = $this->{data};
    my $user = ( getpwuid $< )[0];
    my ( $macro, $apps, $ctrl ) = @param{qw( macro apps ctrl )};

    for my $apps ( @$apps )
    {
        my @match;
        if( my ( $h, $a ) = $apps =~ m#(.*)/(.*)# )
        {
            @match = grep{ 
                         $h && $a ? $_ eq $apps : $h ? $_ =~ m#^$h/# : $_ =~ m#/$a$#
                     }keys %$data; 
        }
        else
        {
            @match = grep{ $_ =~ m#$apps# }keys %$data;
        }

        my ( $app ) = @match;
        @match == 0 ? die "$apps no match\n"
                    : @match ==1 
                        ? print "$apps -> $app\n"
                        : die sprintf "$apps match conflict %s\n", join ':', @match;;

        my $conf = $data->{$app}{ctrl};
        my %macro = ( %$macro, %{$data->{$app}{macro}});
        unless( @$ctrl )
        {
            print YAML::XS::Dump $data->{$app};
        }
        else
        {
            for my $ctrl ( @$ctrl )
            {
                die "no find $ctrl\n" unless my $cmd = $conf->{$ctrl};
    
                $cmd = [ $cmd ] unless ref $cmd;
                for my $cmd ( @$cmd )
                {
                    map{ $cmd =~ s/\$macro{$_}/$macro{$_}/g; }keys %macro;
                    my @bad = $cmd =~ /\$macro{(\w+)}/g;
                    if( @bad )
                    {
                        my %bad = map{$_=>1}@bad;
                        die sprintf "No replacement %s\n", join ':', map{"\$macro{$_}"}keys %bad;
                    }

                    $cmd =~ s/sudo\s+-u\s+$user\s+-H\s+([^-])/$1/g;
                    $cmd =~ s/sudo\s+-u\s+$user\s+([^-])/$1/g;
                    $this->syscmd( $ctrl => $cmd );
                }
            }
        }
    }
}

sub syscmd
{
    my ( $this, $ctrl ) = splice @_, 0, 2;

    my $show = join " ", "[$ctrl]:", @_;
    print( "$show\n" ) and return if $this->{print};

    warn "$show\n" if $this->{verbose};
    return system( @_ ) ? die "run $ctrl ERROR" : $this;
}

1;
__END__
