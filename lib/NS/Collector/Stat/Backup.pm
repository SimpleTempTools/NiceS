package NS::Collector::Stat::Backup;

use strict;
use warnings;
use Carp;
use POSIX;

our $path;
my ( $max, $xxx ) = ( 32, sprintf '0' x 32 );

sub co
{
    my ( $this, @backup, @stat, %backup ) = @_;

    push @stat, [ 'BACKUP', 'md5' ];

    return \@stat unless $path && -d $path;

    map{ $backup{$1} = $2 if $_ =~ /^{BACKUP}{([^}]+)}{(\d+)}/ }@backup;

    for my $backup ( keys %backup )
    {
        my @file = grep{ -f $_ && $_ !~ /\s/ }$backup =~ /\*/ ? glob $backup: $backup;
        my $i = 1;
        for my $file ( @file )
        {
            last if $i++ > $max;

            my $md5 = `md5sum '$file'`;
            next unless $md5 =~ /^(\w{32})\s+$file$/;
            $md5 = $1;
            
            my $dst = $file; $dst =~ s/\//=/g;

            if( -f "$path/$dst=$md5" )
            {
                push @stat, [ $file, $md5 ];
                next;
            }

            if( system "cp '$file' '$path/$dst=$xxx'" )
            {
                warn "backup copy fail: $?\n";
                next;
            }

            my $d = `md5sum '$path/$dst=$xxx'`;
            next unless $d =~ /^(\w{32})\s+$path\/$dst=$xxx$/;
            $d = $1;
            if( system "mv '$path/$dst=$xxx' '$path/$dst=$d'" )
            {
                warn "backup mv fail: $?\n";
                next;
            }

            my $keep = $backup{$backup} || 5;
            my %data = map{ $_ => ( stat $_ )[9] }
                grep{ -f $_ && $_ =~ /^$path\/$dst=\w{32}$/ }glob "$path/$dst*";

            my @data = sort{ $data{$b} <=> $data{$a} } keys %data;
            unlink splice @data, $keep if @data > $keep;

            push @stat, [ $file, $d ] if -f "$path/$dst=$d";
        }
    }

    return \@stat;
}

1;
