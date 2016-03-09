package NS::Bone::Zookeeper;
use strict;
use warnings;

use base qw(NS::Bone ZooKeeper);
use YAML::XS;
use File::Spec;

use Data::Dumper;

our $THIS = 'zookeeper';

sub ini
{
    my($this, %param) = @_;
    $this->{zk} = $param{zk} if %param && $param{zk};
    $this->{zk} ||= $NS::Bone::option{zk};
    $this->ZooKeeper::new( hosts => $this->{zk}, buffer_length => 20480 );
}
sub ping
{
    my ($this, $stat) = shift;
    eval{$stat = $this->exists('/')};
    return !$@ && $stat && ref $stat eq 'HASH';
}

sub get_raw
{

    my($this, $path) = splice @_, 0, 2;
    $path =~ s/\/*$//;
    my($ret, $stat) = $this->SUPER::get($path, @_);
    wantarray ? ($ret, $stat) : $ret;
}
sub get
{
    my $this = shift;
    my($ret, $stat) = $this->get_raw(@_);
    $ret = eval{YAML::XS::Load $ret}||{};
    wantarray ? ($ret, $stat) : $ret;
}

sub set
{
    my ($this, $path, $value) = splice @_, 0, 3;
    $path =~ s/\/*$//;
    $this->mkpath($path) unless $this->exists($path);
    eval{ $this->SUPER::set($path, YAML::XS::Dump($value), @_) };
    $@ ?  (warn "set $path error: $@\n") && 0 : 1;
}

sub mkpath
{
    my($this, $path) = splice @_, 0, 2;
    my @a = split '/', $path;
    for( 1 ... (scalar @a - 2) )
    {
        my $p = join '/', @a[0..$_];
        $this->create($p) unless $this->exists($p);
    }
    $this->create($path, @_);
}

sub leaf
{
    my($this, $path, @ret) = splice @_, 0, 2;
    my @path = $this->_ls($path);
    for(@path)
    {
        my @p = $this->_ls($_);
        push @ret, $_ and next unless @p;
        push @ret, $this->leaf($_);  
    }
    return @ret;
}

sub _ls
{
    my($this, $path) = @_;
    my @child;eval{ @child = $this->get_children($path) };
    warn $@ if $@;
    map{ File::Spec->join($path, $_) }@child;
}
1;
