package NS::Util::PI;

use strict;
use warnings;
use Carp;
use threads;
use Thread::Queue;

use Math::BigFloat;
use Data::Dumper;

our %NEW = ( max => 128, accuracy => 500 );
our $VERBOSE;

sub new
{
    my ( $class, %self ) =  ( shift, %NEW, @_ );
    Math::BigFloat->accuracy($self{accuracy} + 64 );
    bless \%self, ref $class || $class;
}

sub run
{
    my $self = shift;
    my ( $max, $accuracy ) = @$self{qw( max accuracy )};

    my $pi = Math::BigFloat->new( '0' );
    my @queue = map { Thread::Queue->new } 0 .. 1;
    
    map{
         threads::async{
             while ( 1 ) {
                 if ( $queue[0]->pending() )
                 {
                     next unless defined 
                         ( my $i= $queue[0]->dequeue());
                     $queue[1]->enqueue( _inc( $i ) );
                 }
             }
         }->detach();
     } 1 .. $max;
    
    map{ $queue[0]->enqueue( $_ ); } 0 .. $accuracy -1;
    
    while ( $accuracy )
    {
        if( $queue[1]->pending() )
        {
            $pi += Math::BigFloat->new( $queue[1]->dequeue( ) );
            warn( "$pi\n" ) if $VERBOSE && !system 'clear';
            $accuracy--;
        }
    }

}

sub _inc
{
    my $i = Math::BigFloat->new( shift );
    $i = 1/(16**$i)*
           (4/(8*$i+1) - 2/(8*$i+4) - 1/(8*$i+5) - 1/(8*$i+6));
    $i->bstr;
}

1;
