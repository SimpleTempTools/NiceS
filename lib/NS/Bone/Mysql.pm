package NS::Bone::Mysql;
use strict;
use warnings;

use NS::Util::Logger qw(verbose info warning error debug);
use Sys::Hostname;
use DBI;
use Dancer::Plugin::Database::Core;

use Data::Dumper;

use base qw(NS::Bone);

our $THIS = 'mysql';
our %DEFAULT = 
(
    driver => 'mysql',
#    database => 'baz',
    host => '127.0.0.1',
    port => 3306,
#    username => 'foo',
#    password => 'bar',
    connection_check_threshold => 30,
    dbi_params => {
        mysql_enable_utf8 => 1,
        RaiseError => 0,
        AutoCommit => 1,
        on_connect_do => ["SET NAMES 'utf8'", "SET CHARACTER SET 'utf8'" ]
    },
    log_queries => 0
);

sub ini
{
    my ($this, $db, $host) = splice @_, 0, 3;
    return unless $db;
    $host ||= hostname;           

    for(keys %{ $this->{$db} })
    {
        $this->{conn} = $this->{$db}->{$_} and last if $host =~ /$_/;
    }
    die 'can not find redis server' unless $this->{conn};
    $this->{conn}->{database} = $db;
    $this->conn;
}
sub conn
{
    my $this = shift;
    my $dbh = Dancer::Plugin::Database::Core::_get_connection( {%DEFAULT, %{ $this->{conn} } },sub{},sub{} );        
    $dbh;
}

1;
