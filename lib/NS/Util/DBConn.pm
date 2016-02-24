package NS::Util::DBConn;
use strict;
use warnings;

use Carp;
use YAML::XS;
use DBI;

sub new
{
    my ( $class, $conf, %self ) = splice @_, 0, 2;

    confess "conf undef" unless $conf;

    $conf = YAML::XS::LoadFile $conf unless ref $conf;

    $self{conn} = DBI->connect( @$conf );

    bless \%self, ref $class || $class;
}

sub exe
{
    my ( $self, @result ) = shift;

    my $sqr = $self->{conn}->prepare( shift );

    $sqr->execute();
    $sqr->fetchall_arrayref();
}

sub _do
{
    my ( $self, $sql ) = @_;
    print $sql,"\n";
    $self->{conn}->do( $sql );
}
sub do { shift->{conn}->do( shift ); }

sub close { shift->{conn}->disconnect(); }

1;
