package NS::Util::Merge;

use warnings;
use strict;
use Carp;
use Tie::File;

use Data::Dumper;

sub new
{
    my ( $class, %this ) = @_;
    my ( $file, $delimiter ) = @this{qw( file delimiter )};
    $delimiter = "+";
    die "file undef.\n" unless $file && -e $file;
    bless +{ file => _load( $file ) }, ref $class || $class;
}

sub merge
{
    my ( $this, @file, %change ) = @_;
    my $master = $this->{file};
    my ( $TITLE, $CONT ) = @$master{qw( title cont )};

    for ( @file )
    {
        my $file = _load( $_, [ keys %{$master->{title}{name}} ] );
        die "title no match on $_\n" unless keys %{$file->{title}{name}};

        my ( $title, $cont ) = @$file{qw( title cont )};

        for my $c ( @$cont )
        {
            my %mm;
            map{ 
                $mm{$_} = $c->[$title->{name}{$_}] if defined $c->[$title->{name}{$_}] 
            }keys %{$title->{name}};

            for my $I ( 0 .. @$CONT -1 )
            {
                my ( $C, %MM ) = $CONT->[$I];
                map{ $MM{$_} = $C->[$TITLE->{name}{$_}] if defined $C->[$TITLE->{name}{$_}] }keys %{$TITLE->{name}};

                if( grep{ $mm{$_} && $MM{$_} && $mm{$_} eq $MM{$_} }keys %mm )
                {
                    map{ $MM{$_} = $mm{$_} if defined $mm{$_} }keys %mm;
                    $CONT->[$I] = [ map{$MM{$TITLE->{id}{$_}}} 0 .. keys( %{$TITLE->{name}} )-1 ];
                    $change{$I}++;
                }
               
            }
        }
    }
   
    return +{ title => $TITLE->{id}, cont => $CONT, change => \%change };
}

sub _load
{
    my ( $file, $match ) = @_;

    die "tie $file fail: $!!" unless tie my @cont, 'Tie::File', $file;
    die "no title in $file\n" if @cont < 1;

    my ( $i, %title, @cc ) = 0;

    my %match = $match ? map{ $_=> 1 }@$match : ();
    for my $c ( split /[\s\t]+/, $cont[0] )
    {
        if( ( $match && $match{$c} ) || ! $match )
        {
            $title{id}{$i} = $c;
            $title{name}{$c} = $i;
        }
        $i++;
    }
    map { push @cc, [ split /[\s\t]+/, $cont[$_] ]; }1 .. @cont -1;

    return +{ title => \%title, cont => \@cc }
}
1;

