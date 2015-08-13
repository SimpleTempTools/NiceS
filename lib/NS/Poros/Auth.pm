package NS::Poros::Auth;

=head1 NAME

NS::Poros::Auth

=head1 SYNOPSIS

 use NS::Poros::Auth;

 my $sig = NS::Poros::Auth->new( /foo/ca/ )->sign( $mesg );

 NS::Poros::Auth->new( /foo/ca/ )->verify( $sig, $mesg ); 


=cut
use strict;
use warnings;

use Carp;
use YAML::XS;
use File::Spec;
use File::Basename;
use Crypt::PK::RSA;
use FindBin qw( $RealBin );

sub new
{
    my ( $class, $auth, %self ) = splice @_, 0, 2;
    confess "invalid auth dir" unless $auth && -e $auth;
    for my $file ( glob File::Spec->join( $auth, "*" ) )
    {
        my $name = basename $file;
        next if $name =~ /^\./;
        map{ $self{$_}{$name} = $file if $name =~ s/\.$_$// }qw( pub key );
    }

    bless \%self, ref $class || $class;
}

sub sign
{
    my ( $this, $mesg, %sig ) = splice @_, 0, 2;
    confess "no mesg"  unless $mesg;
    map 
    { 
        $sig{$_} = Crypt::PK::RSA->new($this->{key}{$_})->sign_message($mesg) 
    }keys %{$this->{key}};
    return wantarray ? %sig : \%sig;
}

sub verify
{
    my ( $this, $sig, $mesg ) = @_;
    for( keys %{$this->{pub}} )
    { 
        next unless $sig->{$_};
        return 1 if Crypt::PK::RSA->new( $this->{pub}{$_} )->verify_message( $sig->{$_}, $mesg );
    }
    return 0;
}

1;
