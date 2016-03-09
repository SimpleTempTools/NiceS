package NS::Bone::Kafka;
use strict;
use warnings;

use base qw(NS::Bone);

use Kafka qw( $DEFAULT_MAX_BYTES $DEFAULT_MAX_NUMBER_OF_OFFSETS $RECEIVE_LATEST_OFFSET $COMPRESSION_SNAPPY);
use Kafka::Connection;
use Kafka::Producer;
use Kafka::Consumer;

use NS::Bone::Memcache;

use Data::Dumper;

our $THIS = 'kafka';

=head1 NAME

NS::Bone::Kafka. - NS Kafka Singleton

=head1 SYNOPSIS

my $topic = "collect";

my $kaf = NS::Bone::Kafka->new( $topic );

my $offset = $kaf->offset_last;

my $messages = $kaf->fetch($offset);

$kaf->send( message );

=cut


my ($single, $consumer, $producer);
sub ini 
{ 
    my ($this, $topic) = @_;
    $this->{topic} = $topic if $topic;
    $this->_conn;
    return $this;
}
sub _conn
{
    my $this = shift;
    $single = Kafka::Connection->new( %$this ) unless $single;
    $consumer = Kafka::Consumer->new( Connection => $single ) unless $consumer;
    $producer = Kafka::Producer->new( Connection => $single ) unless $producer;
}
sub ping 
{ 
    my ($this, $ret) = shift; 
    eval{$ret = $single->get_metadata('foo')};
    !$@ && $ret && ref $ret eq 'HASH';
}

my %eval = 
(
    offset_last => 
    [
        sub {
            my ($this, $topic) = shift;
            $topic = shift||$this->{topic};
            $consumer->offsets( $topic, 0, $RECEIVE_LATEST_OFFSET, $DEFAULT_MAX_NUMBER_OF_OFFSETS);
        },
        sub{
            my $o = shift;
            return $o->[0] if $o && ref $o eq 'ARRAY';
        }
    ],
    fetch => 
    [
        sub{
            my($this, $offset) = @_;
            $consumer->fetch( $this->{topic}, 0, $offset, $DEFAULT_MAX_BYTES);
        },
        sub{shift}
    ],
    'send' =>
    [
        sub{
            my($this, $value) = @_;
            $producer->send( $this->{topic}, 0, $value );
        },
        sub{1}
    ]

);

sub _eval
{
    my($this, $stub, $ret) = splice @_, 0, 2;
    my($eval, $grep) = @$stub;
    $this->_conn();
    eval{ $ret = $eval->($this, @_) }; 
    if($@)
    {
        undef $single;
        undef $consumer;
        undef $producer;
        warn $@;
        return;
    }
    $grep->($ret);
}

sub offset_last { my $this = shift; $this->_eval( $eval{'offset_last'}, @_ ) }
sub fetch { my $this = shift; $this->_eval( $eval{'fetch'}, @_ ) }
sub send { my $this = shift; $this->_eval( $eval{'send'}, @_ ) }

sub loop
{
    my ($this, $sub, %opt) = @_;

    die "sub need to be a subroutine" unless $sub && ref $sub eq 'CODE';

    my ($mem, $offset) = NS::Bone::Memcache->new();

    $offset = $this->offset_last or die "can't get $this->{topic} last offset";
    while(1)
    {
        my($last, $messages, $old_offset) = $this->offset_last;
        $messages = $this->fetch($offset);
        $old_offset = $offset;

        $mem->set($opt{mem_offset}, $offset, 120) if $opt{mem_offset} && $mem;

        print STDERR "last:$last offset:$offset delay:", $last - $offset, "\n" if $opt{verbose};

        $offset += 1 unless $messages;
        foreach my $message ( @$messages )
        {
            $offset = $message->next_offset;
            next unless $message->valid;

            $sub->($message->payload);
        }


    }
}

1;
