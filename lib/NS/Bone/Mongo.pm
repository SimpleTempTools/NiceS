package NS::Bone::Mongo;
use strict;
use warnings;

use NS::Util::Logger qw(verbose info warning error debug);
use Sys::Hostname;
use MongoDB;

use base qw(NS::Bone);

our $THIS = 'mongo';
our %DEFAULT = ( addr => 'mongodb://localhost' );

sub ini
{
    my ($this, $db, $host) = splice @_, 0, 3;
    return unless $db;
    $host ||= hostname;           

    for(keys %{ $this->{$db} })
    {
        $this->{conn} = $this->{$db}->{$_} and last if $host =~ /$_/;
    }
    die 'can not find mongo server' unless $this->{conn};
    $this->{conn}->{database} = $db;
    $this->conn;
}
sub conn
{
    my $this = shift;
    MongoDB->connect( $this->{conn}{addr} || $DEFAULT{addr} );
}

1;
