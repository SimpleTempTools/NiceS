package NS::Bone;

use warnings;
use strict;

use NS::Util::OptConf;
use YAML::XS;
use Data::Clone;
use Sys::Hostname;
use POSIX qw(strftime);
use Data::Dumper;
use File::Spec;

$NS::Util::OptConf::THIS = 'bone';

our %option = ( delimiter => ':' );

sub new
{
    my ($class, $self) = shift;
    $class = ref $class if ref $class;

    %option = ( %option, NS::Util::OptConf->load()->dump() );
    my $conf = File::Spec->join( $option{conf}, 'conn' );

    eval{$conf = YAML::XS::LoadFile $conf} and %option = (%option, %$conf);
    no strict;
    $self = bless clone( $option{ ${$class."::THIS"} } ) || {}, $class;
    $self->ini(@_);
}
sub ini{shift};
sub dump
{
    my( $this, $key ) = @_;
    $key ? $option{$key} : wantarray ? %option : \%option;
}
sub notify
{
    return sub
    {
        my (%h, $notify, $cmd, $now);
        $notify = clone( $option{notify} ) or return 0; 
        $cmd = delete $notify->{cmd} or return 0;
        $now = strftime "%m-%d:%H:%M:%S", localtime;
        %h = ( %$notify, host => hostname, 'time' => $now, 'level' => 3,  @_ );
        $cmd =~ s/\$$_/$h{$_}/g for keys %h;
        print "send notify:", $cmd, "\n";
        return not system($cmd);
    }
}
1;
