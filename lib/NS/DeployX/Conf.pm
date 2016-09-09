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

use NS::OpenAPI::Deploy;

=head1 CONFIGURATION

YAML file that defines sets of maintenance parameters index by names.
Each set defines the following parameters:

 target : targets of maintenance, to be devided into batches.
 maint : name of maintainance code.
 batch : name of batch code.
 param : ( optional ) parameters of batch code.

=cut
#our @PARAM = qw( target maint batch );

#    main => [ qw( target batch sort each test code macro stat ) ],
#    conf => [ qw( title global check redo retry repeat delay sleep code exec goon fix ) ]
#
#
sub new
{
    my ( $class, $name, $m, $c ) = splice @_;
   
    my $openapi = NS::OpenAPI::Deploy->new( name => $name );

    my $main = $openapi->main($m);
    my $conf = $openapi->conf($c);

    return bless +{ main => $main, conf => $conf }, ref $class || $class;
}

sub dump
{
    my ( $this, $macro, %macro ) = splice @_, 0,2;

    my ( $main, $conf ) = map{
        my $s = YAML::XS::Dump $_;
        map { $s =~ s/\$macro\{$_\}/$macro->{$_}/g; } keys %$macro;
        map{ $macro{$_} = 1 }$s =~ /(\$macro\{[\w_]+\})/g;
        my $n = YAML::XS::Load $s;
        $n;
    }@$this{qw( main conf )};

    exit 0 if %macro && printf "macro no replace: %s\n", join ' ', keys %macro;

    my %title;
    map { $title{ $conf->[ $_-1]->{title}||="job.$_"} ++; }1 .. @$conf;
    
    my @redef = grep{ $title{$_} > 1 }keys %title;
    if( @redef )
    {
        printf "title redef: %s\n", join ',', @redef;
        exit 113;
    }
    return $main, $conf;
}

sub old
{
    my ( $class, $name, $mark ) = splice @_;
    my $openapi = NS::OpenAPI::Deploy->new( name => $name );
    return map{ $openapi->cache($mark, $_) }qw( main conf );
}
1;
