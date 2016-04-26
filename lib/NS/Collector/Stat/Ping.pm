package NS::Collector::Stat::Ping;
use Data::Dumper;

our @HEAD = qw(PING min avg max mdev loss);
our @NONE = qw(none none none none none none);
my $REGEX = qr/\{PING\}\{(((w-)?\w+\.?)+)\}/;

sub co 
{
    my ($class, @host, @ret) = shift;
    $_ =~ $REGEX and push @host, $1 for @_;
    push @ret, \@HEAD;
    for my $host(@host)
    {
        push my @status, $host;
        eval
        {
            my (@line, @s) = `ping -c 20 -f $host 2>/dev/null|tail -2`;
            @s = $line[1] =~ /(\d+\.\d+)\/(\d+\.\d+)\/(\d+\.\d+)\/(\d+\.\d+)/;
            push @s, $1 if $line[0] =~ /(\d+)\% packet loss/;
            push @status, @s ? @s : @NONE;
        };
        push @ret, \@status;
    }
    \@ret;
}
1;

