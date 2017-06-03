package NS::VSSH::Execute;

use strict;
use warnings;

use NS::Poros::Client;
use NS::Util::OptConf;

$|++;

our %o; BEGIN{ %o = NS::Util::OptConf->load()->dump('poros');};
sub new
{
    my ( $class, %self ) =  @_;
    bless \%self, ref $class || $class;
}

sub run
{
    my ( $this, %param ) = @_;
 
    my %query = ( code => 'exec', argv => [ $param{cmd} ] );

    my $client = NS::Poros::Client->new( map { join ':', $_, $o{port} } @{$this->{node}});
    my %result = $client->run( query => \%query );
    map{ my $k = $_;$k =~ s/:$o{port}$//; $k => $result{$_} }keys %result;
}

1;
