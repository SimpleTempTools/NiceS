package NS::OpenAPI::Lock;
use strict;
use warnings;
use Carp;

use JSON;
use Sys::Hostname;

use base qw( NS::OpenAPI );

our $URI = '/openapi/lock';

sub dump
{
    my $self = shift;
    $self->get( sprintf "$URI/dump%s", $self->{name} ? "?name=$self->{name}" : '' );
}

#sub check
#{
#    my $self = shift;
#    my $locked = $self->get( "$URI/check/$self->{name}" );
#    $locked ? join(':', map{@$_}@$locked) : undef;
#}
#

sub check { shift->{info}; }

sub lock
{
    my $self = shift;

    my $data = $self->_get( sprintf "$URI/lock/$self->{name}?host=%s&pid=$$", hostname );
    $self->{info} = $data->{info};
    
    return $data->{stat};
}


sub unlock
{
    my $self = shift;
    $self->get( "$URI/unlock/$self->{name}" );
}

1;
