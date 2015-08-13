use strict;
use warnings;
use FindBin qw( $Bin );
use Tie::File;

exit 0 unless my $nices = $ENV{nices};
die "no such path: $nices\n" unless -d $nices;
die "rsync ns to tmp fail.\n" if system "rsync -a ns/ 'ns.i/'";


my $perl = $ENV{PERL_PATH} || $^X;
for my $file ( `find ns.i -type f` )
{
    chomp $file;
    tie my ( @file ), 'Tie::File', $file;

    next unless @file && $file[0] =~ /#![^#]*perl(.*$)/o;
    $file[0] = "#!$perl$1";
    warn "$file\n";
    untie @file;
}

if( my $conf = $ENV{conf} )
{
    die "conf $conf undef.\n" unless -d "conf/$conf";
    die "rsync conf $conf fail.\n" if system "rsync -a 'conf/$conf/' 'ns.i/'";
}

die "rsync ns to '$nices/ns/' fail.\n" if system "rsync -a ns.i/ '$nices/ns/'";

exit 0;
