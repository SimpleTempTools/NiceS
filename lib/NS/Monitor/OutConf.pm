package NS::Monitor::OutConf;
use NS::Hermes;
use NS::Util::OptConf;

use Data::Clone;
use File::Spec;
use File::Basename;
use YAML::XS;
use Sys::Hostname;
use Data::Dumper;

my @need = qw(timeout interval code);
my $DEFAULT = 'default';
our $VERBOSE = 0;

sub new
{
    my ($class, %self, $conf) = @_;

    return if grep{ !exists $self{$_} }qw(conf cluster range single);
    return unless $conf = eval{ YAML::XS::LoadFile $self{conf} } and ref $conf eq 'HASH';

    map{ my $c = $conf->{$_}; delete $conf->{$_} if grep { !exists $c->{$_} } @need }keys %$conf;

    $self{conf} = $conf;

    my $this = bless \%self, $class;
    $this->_ini_range;
    return $this;
}

sub config
{
    my($this, $cluster, $range, $single, %last) = shift;
    $cluster = $this->_cluster(@_);
    $range = $this->_range(@_);
    $single = $this->_single(@_);

    $last{conf} = { %{$cluster->{conf}||{}}, %{$range->{conf}||{}}, %{$single->{conf}||{}} };
    $last{target} = shift @_;

    if($VERBOSE)
    {
        print "clu:", YAML::XS::Dump $cluster ,"\n";
        print "range:", YAML::XS::Dump $range ,"\n";
        print "single:", YAML::XS::Dump $single ,"\n";
        print "last:", YAML::XS::Dump \%last ,"\n";
    }

    return keys %{$last{conf}} ? YAML::XS::Dump \%last : undef;
}
sub _ini_range
{
    my ($this, %range) = shift;
    my $option = NS::Util::OptConf->load();


    for my $dir ( keys %{ $this->{conf} })
    {
        for my $file( glob( File::Spec->join( $this->{range}, $dir, "*") ) )
        {
            next unless -f $file;
            my $r = sprintf "{==%s}", basename $file;
            my $cluster = NS::Hermes->new( $option->dump( 'range' ) );
            my $range = NS::Hermes->new();
            map{
                $range{$dir} ||= {};  
                warn "$_ over write with $file" if exists $range{$dir}->{$_};
                $range{$dir}->{$_} = basename $file;
            } $range->add( $cluster->load( $r ) )->list;
        }
    }
    $this->{range_map} = \%range;
}
sub _load_conf
{
    my @ret;
    for my $file( @_ )
    {
        next unless -f $file;
        my $conf = eval{ YAML::XS::LoadFile $file };
        warn "load conf error: $file" and next unless $conf
            && ref $conf eq 'HASH'
            && !grep{ ref $_ ne 'ARRAY' }values %$conf;
        print "load: $file\n" if $VERBOSE;
        push @ret, $conf;
    }
    return wantarray ? @ret : $ret[0];
}

sub _single
{
    my( $this, $node, $hermes, %single) = splice @_, 0, 3;

    for my $dir ( keys %{ $this->{conf} })
    {
        my $conf = _load_conf( File::Spec->join($this->{single}, $dir, $node) );
        next unless $conf;


        $single{conf}->{$dir} = clone( $this->{conf}->{$dir} );
        $single{conf}->{$dir}->{param}->{test} = $conf;
    }
    return \%single;
}
sub _range
{

    my( $this, $node, $hermes, %range) = splice @_, 0, 3;
    my $range = $this->{range_map}||{};

    for my $dir ( keys %{ $this->{conf} })
    {
        next unless exists $range->{$dir}->{$node};

        my $conf = _load_conf( File::Spec->join($this->{range}, $dir, $range->{$dir}->{$node}) );
        next unless $conf;

        $range{conf}->{$dir} = clone( $this->{conf}->{$dir} );
        $range{conf}->{$dir}->{param}->{test} = $conf;
    }
    return \%range;
}
sub _cluster
{
    my( $this, $node, $hermes, %cluster) = splice @_, 0, 3;
    my @dirs = grep{ -d File::Spec->join( $this->{cluster}, $_ ) } keys %{ $this->{conf} };
    for my $dir (@dirs)
    {
        my($default, @conf, %ret) = map{ File::Spec->join($this->{cluster}, $dir, $_) }( $DEFAULT, @$hermes );
        @conf = _load_conf(@conf) or @conf = _load_conf( $default) or next;

        for my $conf(@conf)
        {
            for my $key(keys %$conf)
            {
                map{ $ret{$key}->{$_} = 1 }@{ $conf->{$key} };
            }
        }
        map{ $ret{$_} = [ sort keys %{ $ret{$_} } ] }keys %ret;
        $cluster{conf}->{$dir} = clone( $this->{conf}->{$dir} );
        $cluster{conf}->{$dir}->{param}->{test} = \%ret;
    }
    return \%cluster;
}

1;
