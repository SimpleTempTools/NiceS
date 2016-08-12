#!/home/s/ops/perl/bin/perl: deploy/code/m.sync
use strict;
use Data::Dumper;
use NS::Hermes;

return sub
{
    my %param = @_;

    my ( $batch, $param, $sc, $name, $myid, $title ) 
      = @param{qw( batch param sc name myid title )};

    my ( $bash, $regx ) = @$param{qw( bash regx )};
    return () unless $bash && $regx;

    print "=" x 30,"\n";
    my $range = NS::Hermes->new();
    my $node = $range->load( $batch )->dump;
    
    $bash =~ s/__NODE__/$node/g;
    
    my ( %node, %succ ) = ( map{ $_ => 1 }@$batch );
    
    print "bash:$bash\n"; 
    print "regx:$regx\n"; 

    die "open: $!" unless open my $cmd, "$bash |";
    while ( my $line = <$cmd> )
    {
        print $line;
        next unless defined $line && $line =~ /$regx/ && $1;
        $succ{$1} = 1 if $node{$1};
    }

    print "=" x 30,"\n";
    return %succ;
};
