package NS::DeployX::Conf;

=head1 NAME

NS::Deploy::Conf - Load/Inspect maintenance configs

=head1 SYNOPSIS

 use NS::Deploy::Conf;

 my $conf = NS::Deploy::Conf->new( $name )->dump( \%macro );

=cut
use strict;
use warnings;

use Data::Dumper;

use Carp;
use YAML::XS;
use Tie::File;

=head1 CONFIGURATION

YAML file that defines sets of maintenance parameters index by names.
Each set defines the following parameters:

 target : targets of maintenance, to be devided into batches.
 maint : name of maintainance code.
 batch : name of batch code.
 param : ( optional ) parameters of batch code.

=cut
#our @PARAM = qw( target maint batch );

our %COL = 
( 
    main => [ qw( target batch sort each test code macro stat ) ],
    conf => [ qw( title global check redo retry repeat delay sleep code exec goon fix ) ]
);

sub new
{
    my ( $class, $name, $conn ) = splice @_;
   
    my ( $main, $conf ) = map{ 
       $conn->exe( sprintf "select %s from resources_deploy_$_ where name='$name'", join ',', map{"`$_`"}@{$COL{$_}} );
    }qw( main conf );

    confess "get main error" unless $main && @$main == 1; 
    confess "get conf error" unless $conf && @$conf >= 1; 

    return bless +{ main => $main->[0], conf => $conf }, ref $class || $class;
}

sub dump
{
    my $this = shift;
    print Dumper $this;

    my ( $main, $conf ) = @$this{qw( main conf )};
    my %COL = map{
        my $t = $_;
        $t => +{ map{ $COL{$t}[$_] => $_ }0.. @{$COL{$t}} -1 }
    }qw( main conf );

    my %macro;
    if ( my $macro = $main->[$COL{main}{macro} ] )
    {
        map{ $macro{$1} = $2 if $_ =~ /^([^=]+)=(.+)$/}split ';', $macro;

        print Dumper \%macro;
        while ( my ( $k, $v ) = each %macro )
        {
            map{ map{ $_ =~ s/\$env{$k}/$v/g }@$_}(@$conf, $main);
        }
    }

    my %main = map{ $_ => $main->[$COL{main}{$_}] }keys %{$COL{main}};
    my @conf = map{ my $c = $_;+{map{ $_ => $c->[$COL{conf}{$_}] }keys %{$COL{conf}}} }@$conf;
    
    return \%main, \@conf;
}

1;
