package NS::Util::AppsCheck;

use strict;
use warnings;

use Carp;
use YAML::XS;
use FindBin qw( $RealBin );

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
                    : @match == 1 
                        ? $this->{verbose} ? print "$apps -> $app\n" : 1
                        : die sprintf "$apps match conflict %s\n", join ':', @match;

       for my $check ( @{$data->{$app}{ctrl} })
       {
           my ( $code, $param ) = @$check{qw( code param )};
           die "$app code undef\n" unless $code;
           $code = "$RealBin/../util/code/apps.check/$code";
           my $c = do $code;
           die "load code $code eror\n" unless $c && ref $c eq 'CODE';
           &$c( param => $param, verbose => $this->{verbose}, node => $param{node} );
       }
    }
    print "AppsCheck: $param{node} => OK\n";
}

1;
__END__
