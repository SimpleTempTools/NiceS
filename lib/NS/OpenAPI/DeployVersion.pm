package NS::OpenAPI::DeployVersion;
use strict;
use warnings;
use Carp;

use JSON;
use Sys::Hostname;

use base qw( NS::OpenAPI );

our $URI = '/openapi/deployversion';
our @idc = qw( nices );

sub version
{
    my ( $self, @name ) = @_;
    if( @idc )
    {
        my %version =
        map{ 
            $_ => $self->get( sprintf "$URI/$_/version?%s", join '&',map{"name=$_"} @name );
        }@idc;

        my %h;
        for my $idc ( @idc )
        {
            for my $name ( @name )
            {
                next unless my $version = $version{$idc}{$name};
                for( 0 .. @$version -1 )
                {
                    $h{$name}{$version->[$_]}{idc}{$idc} = 1;
                    $h{$name}{$version->[$_]}{count} = $_;
                }
            }

        }
        my %re;
        for my $name ( @name )
        {
            $re{$name} = [ map{ sprintf "$_(%s)", join ',', keys %{$h{$name}{$_}{idc}} }
                           sort{ $h{$name}{$a}{count} <=> $h{$name}{$b}{count} }
                           keys %{$h{$name}}
                         ];
        }
        return \%re;
    }
    else
    {
        $self->get( sprintf "$URI/version?%s", join '&',map{"name=$_"} @_ );
    }
}

1;
