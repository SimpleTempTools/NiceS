package openapi_deployversion;
use Dancer ':syntax';
use JSON;
use FindBin qw( $RealBin );
use Data::Dumper;
use File::Basename;

our $VERSION = '0.1';
our $ROOT = "/home/s/var/hdp/home/cloudops/upload";

set serializer => 'JSON';

any '/readme' => sub {
    template 'openapi_deployversion';
};

any '/mon' => sub { return 'ok'; };

any '/version' => sub {
    return +{ stat => $JSON::false, info => 'name undef' } unless my $name = params()->{name};

    my %name = map{ $_ => 1 }grep{ /^[a-zA-Z0-9_\.]+$/} ref $name ? @$name : ( $name );

    my %re;
    for my $name ( keys %name )
    {
        next unless -d "$ROOT/$name";
        my %time = map{ $_ => (stat $_)[9] }glob "$ROOT/$name/*";
        my @data = sort{ $time{$b} <=> $time{$a} } keys %time;
             
        $re{$name} = [ grep{ $_ ne 'curr' }map{ basename $_ }splice @data, 0, 15 ]
    }

    return +{ stat => $JSON::true, data => \%re };
};

true;
