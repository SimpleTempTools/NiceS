package NS::Collector::Parse;
use NS::Util::Logger qw(debug verbose info warning error);

use POSIX;
use YAML::XS;
use Data::Dumper;

our %MAP = 
(
    TEST => '_parse_test',
    LOAD => '_parse_pair',
    UPTIME => '_parse_uptime',
    IO => '_parse_pair',
    MEM => '_parse_pair',
    VERSION => '_parse_pair',
    FILE => '_parse_pair',
    CPU => '_parse_pair',       #only get 'all'
);

sub new
{
    my ($class, $raw, %hash) = splice @_, 0, 2;

    my $msg; eval{$msg = YAML::XS::Load $raw};
    $msg = [] unless $msg && ref $msg eq 'ARRAY';

    for(@$msg)
    {
        exists $_->[0] && exists $_->[0]->[0] or next;
        push @{ $hash{ $_->[0]->[0] } }, $_;
    }
    bless \%hash, $class;
}

sub parse
{
    my($this, $key) = @_;
    $MAP{$key}->( $this->{$key} );
}


my %TEST_KEY = 
(
   'cond'    =>  0 ,
   'stat'    =>  10,
   'group'   =>  11,
   'warning' =>  12,
   'info'    =>  13,
);
sub _parse_test
{
    my ($msg, %err) = shift;

    map
    {
        my $msg = $_;
        my ($cond, $group, $info) = map{ $msg->[ $TEST_KEY{$_} ] }qw( cond group info );
        push @{ $err{$group} }, sprintf "%s (%s)", $cond, $info;
    }
    grep{$_->[ $TEST_KEY{'stat'} ] eq 'err'}
    grep{$_ && $_->[0] ne 'TEST'}map{@$_}@$msg;

    wantarray ? %err : \%err;
}

sub _parse_uptime
{
    my ($msg, %time) = shift;
    my @msg = map{ @$_ }@$msg;
    for(0 .. @{$msg[0]}-1)
    {
        my($k, $v) = ($msg[0]->[$_], $msg[1]->[$_]);
        $time{$k} = $v;
    }
    delete $time{UPTIME};
    $time{human} = POSIX::strftime( "%Y-%m-%d %H:%M", localtime( $time{'time'} || time ) );
    wantarray ? %time : \%time;
}
sub _parse_pair
{
    my ($msg, %ret) = shift;
    my (@msg, @ret) = grep{scalar @{$_->[1]} > 1}@$msg;

    @ret = @{ shift @msg };

    for(1 .. @{$ret[0]}-1)
    {
        my($k, $v) = ($ret[0]->[$_], $ret[1]->[$_]);
        $ret{$k} = $v;
    }
    wantarray ? %ret : \%ret;

}
1;
