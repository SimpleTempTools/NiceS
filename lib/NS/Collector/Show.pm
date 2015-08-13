package NS::Collector::Show;
use strict;
use warnings;

use Carp;
use YAML::XS;

use Digest::MD5;
use Sys::Hostname;

use threads;
use Thread::Queue;

use Data::Dumper;
use POSIX;

sub new
{
    my ( $class, %this ) = @_;

    map{ confess "no $_\n" unless $this{$_} && -d $this{$_} }qw( logs data );

    return bless \%this, ref $class || $class;
}

sub show
{
    my ( $this, @show ) = @_;
    @show ? $this->hist( @show ): $this->curr();
    return $this;
}

sub curr
{
    my $this = shift;
    my $data = "$this->{data}/output";
    
    unless( -f $data )
    {
        warn "no data\n"; return $this;
    }

    my $time = POSIX::strftime( "%Y-%m-%d_%H:%M:%S", localtime(  (stat $data)[9] ) );

    $data = eval{ YAML::XS::LoadFile $data };
    if( $@ )
    {
        warn "syntax err:$@\n"; return $this;
    }

#    unless ( $data = $data->{data} )
#    {
#        warn "no data in yaml\n";return $this;
#    }

    for( keys %$data )
    {
        my $stat = $data->{$_};
        if( ref $stat ne 'ARRAY' )
        {
            warn "syntax err:$_\n";next;
        }
        map{ map{ printf "$time\t%s\n", join "\t", @$_ }@$_;print "\n"; }@$stat;
        printf "\n%s\n\n", join ',', map{ $_->[0][0] }@$stat;
    }
    
    return $this;
}

sub hist
{
    my $this = shift;
    my $logs = $this->{logs};
    my %show = map{ $_ => 1 }@_;

    my %hist = map{ $_ => ( stat $_ )[9] }grep{ /\/output\.\d+$/ }glob "$logs/output.*";

    map{
        my $time =  POSIX::strftime( "%Y-%m-%d_%H:%M:%S", localtime(  $hist{$_} ) );

        eval{

            my $data = YAML::XS::LoadFile $_;
#            $data = $data->{data};
            for my $stat( values %$data )
            {
                next unless ref $stat eq 'ARRAY';
                map{ my $t = $stat->[$_]; map{ printf "$time\t%s\n", join "\t", @$_;}@$t; }
                grep{ $show{$stat->[$_][0][0]} } 0 .. @$stat -1;
                
            }
        };
        

    }sort{ $hist{$b} <=> $hist{$a} }keys %hist;
    
    return $this;
}

1;
