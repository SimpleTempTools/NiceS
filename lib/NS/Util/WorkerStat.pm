package NS::Util::WorkerStat;
use strict;
use warnings;

use NS::Util::DBConn;

=head1 SYNOPSIS

CREATE TABLE `worker_stat` (
   id int(32) not null primary key auto_increment,
  `attr` varchar(100) DEFAULT NULL,
  `name` varchar(100) DEFAULT NULL,
  `stat` varchar(200) DEFAULT NULL,
  `time` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY `tn` (`attr`,`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8

=cut

sub new
{
    my ( $class, %self ) = @_;

    die "conn undef" unless $self{conn};
    $self{db} =  NS::Util::DBConn->new( $self{conn} );

    bless \%self, ref $class || $class;
}

sub set
{
    my $this = shift;
    
    $this->{db}->do(
        sprintf "replace into worker_stat(`attr`,`name`,`stat`) values('%s','%s','%s')", @_
    );

    return $this;
}

sub dump
{
    shift->{db}->exe( "select * from worker_stat" );
}

sub fail
{
    shift->{db}->exe(
        "select time,name,stat from worker_stat where ( time < (now() - interval 150 second) ) or ( stat != 'ok' )" );
}


1;
