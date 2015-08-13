package NS::Collector::Stat;

use strict;
use warnings;
use Carp;
use POSIX;

use NS::Collector::Stat::Time;
use NS::Collector::Stat::Sar;
use NS::Collector::Stat::DF;
use NS::Collector::Stat::Exec;
use NS::Collector::Stat::Proc;
use NS::Collector::Stat::Call;
use NS::Collector::Stat::Http;
use NS::Collector::Stat::Port;
use NS::Collector::Stat::User;
use NS::Collector::Stat::IFace;
use NS::Collector::Stat::Dmesg;
use NS::Collector::Stat::Uptime;
use NS::Hermes;

use Data::Dumper;

our $REGEX = qr/\{ (\w+) \}\{ ([^}]+) \}\{ ([^}]+) \}/x;
our $REGEY = qr/\{ (\w+) \}\< ([^>]+) \>\{ ([^}]+) \}/x;

my ( $keep, $NAME, %eval ) = ( 9, 'TEST' );
my @statcol =  ( 1 .. $keep, 'stat', 'group', 'warnning' );

my %FIXME = 
(
    PAGE  => [ 'pgpgin/s', 'kbhugfree' ],
    IO    => [ 'tps' ],
    LOAD  => [ 'runq-sz', 'proc/s', 'cswch/s' ],
    MEM   => [ 'frmpg/s', 'kbmemfree' ],
    SWAP  => [ 'kbswpfree', 'pswpin/s' ],
    NFS   => [ 'call/s', 'scall/s' ],
    SOCK  => [ 'totsck' ],
    IP    => [ 'irec/s', 'ihdrerr/s' ],
    ICMP  => [ 'imsg/s', 'ierr/s' ],
    TCP   => [ 'active/s', 'atmptf/s' ],
    UDP   => [ 'idgm/s' ],
    SOCK6 => [ 'tcp6sck' ],
    IP6   => [ 'irec6/s', 'ihdrer6/s' ],
    ICMP6 => [ 'imsg6/s', 'ierr6/s' ],
    UDP6  => [ 'idgm6/s' ],
    FILE  => [ 'dentunusd' ],
);

my %EMXIF = map{ my $t = $_; map{ $_ => $t }@{$FIXME{$t}} } keys %FIXME;

my %BASE = map{ $_ => 1 }qw( IO SWAP DF MEM IFACE UPTIME CPU );

sub new
{
    my ( $class, %self, %todo, $base ) = splice @_;

    $ENV{LANG} = 'en_US.UTF-8';

    if( my $test = $self{test} )
    {
        map{ map{ map{ $todo{$_} = 1 } $_ =~ /({\w+}{[^}]+}{[^}]+})/g;} @$_; }values %$test;
        map{ my $g = $_; map{ $eval{$_}{group} = $g }@{$test->{$g}}}keys %$test;

        map{ $base = 1 if $BASE{$_} }map{ $_ =~ /^{([^}]+)}/ }keys %todo;
    }
    else { $base = 1; }


    my ( @data, %data );
    if( $base )
    {
        push @data, NS::Collector::Stat::Uptime->co();
        push @data, NS::Collector::Stat::IFace->co();
        push @data, NS::Collector::Stat::Dmesg->co();
        push @data, NS::Collector::Stat::Time->co();
        push @data, NS::Collector::Stat::User->co();
        push @data, NS::Collector::Stat::Sar->co();
        push @data, NS::Collector::Stat::DF->co();
    }

    my %test;
    map{ my $t = $_; $test{$t} = [ grep{ /^{$t}/ }keys %todo ] }qw( PROC EXEC CALL HTTP PORT );
    push @data, NS::Collector::Stat::Proc->co( @{$test{PROC}} ) if $base || @{$test{PROC}};
    push @data, NS::Collector::Stat::Exec->co( @{$test{EXEC}} ) if $base || @{$test{EXEC}};
    push @data, NS::Collector::Stat::Call->co( @{$test{CALL}} ) if $base || @{$test{CALL}};
    push @data, NS::Collector::Stat::Http->co( @{$test{HTTP}} ) if $base || @{$test{HTTP}};
    push @data, NS::Collector::Stat::Port->co( @{$test{PORT}} ) if $base || @{$test{PORT}};

    for ( 0 .. $#data )
    {
        my $data = shift @data;
        my $fix = $EMXIF{$data->[0][0]};

        unless( $fix ) { push @data, $data; next; }

        $data{$data->[0][0]} = $data;
    }

    for my $t ( keys %FIXME )
    {
        my @d;
        $d[0][0] = $t; $d[1][0] = 'value';   
        map{ my $i = $_; push @{$d[$i]}, map{ $data{$_} ? @{$data{$_}[$i]}: () }@{$FIXME{$t}} } 0 .. 1;
        push @data, \@d;
    }


    my ( $i, %table, %col, %row ) = ( 0 );
    for my $data ( @data )
    {
        my $col = $data->[0];
        my $j = 0; map{ $col{$i}{$_} = $j ++;}@$col;
        my $k = 0; map{ $row{$i}{$data->[$_][0]} = $k ++;} 0 .. @$data -1;
        push @{$table{$col->[0]}}, $i ++;
    }

    bless +{ data => \@data, table => \%table, col => \%col, row => \%row }, ref $class || $class;
}

sub stat
{
    my $data = shift->{'data'};

    my @stat = ( [ $NAME, @statcol ] );
    map
    {
        my ( $eval, @s ) = ( $eval{$_}, $_ );
        map{ push @s, defined $eval->{$_} ? $eval->{$_} : '[]' } @statcol;
        push @stat, \@s;
    }keys %eval;
    return [ @$data, \@stat ];
}

sub info
{
    my ( $self, @type ) = @_;
    my ( $table, $col, $row ) = @$self{ qw( table col row ) };
    my $data = $self->stat;

    my $range = NS::Hermes->new();
   
    if( @type )
    {
       my %type = map{ $_ => 1 }@type;
       map{ 
           map{ printf "%s\n",join "\t", @$_; }@$_; print "\n"; }
               grep{ $type{$_->[0][0]}
       }@$data;
       return $self;
    }

    while( my ( $t, $i ) = each %$table )
    {
        printf "$t:\n  col:%s\n  row:%s\n",
            $range->load( [ map{ my $d = $_; grep{ $col->{$d}{$_}}keys %{$col->{$_}}} @$i ] )->dump,
            $t eq 'PS'? 'All the processes ID here':
            $range->load( [ map{ my $d = $_; grep{ $row->{$d}{$_}}keys %{$row->{$_}}} @$i ] )->dump;
    }

    printf "$NAME:\n  col:%s\n  row:%s\n", join( ',', @statcol ), join ',', sort keys %eval;

    return $self;
}

sub eval
{
    my ( $this, @stat, %stat ) = shift;
    if( @_ ) { %eval = (); map{ $eval{$_}{group} = 'undef' }@_; }

    my ( $data, $table, $col, $row ) = @$this{ qw( data table col row ) };

    for my $test ( keys %eval )
    {
        my @tmp;
        unless ( $test =~ /$REGEX/g || $test =~ /$REGEY/g )
        {
            $eval{$test}{'stat'} = 'warn';
            $eval{$test}{warnning} = 'regex syntax err';
            next;
        }

        my ( $eval, $fail ) = $test;

        while ( $eval =~ /$REGEX/g )
        {
            unless( $table->{$1} ) { $fail = 1;last; }
 
            my $t; map{ $t = $_ if $col->{$_}{$3} && $row->{$_}{$2} }@{$table->{$1}};

            unless( defined $t ) { $fail = 1; last; }

            my $c = $col->{$t}{$3};
            my $r = $row->{$t}{$2};

            unless( defined $c && defined $r ) { $fail = 1; last; }

            push @tmp, $data->[$t][$r][$c];

            warn "{$1}{$2}{$3} = $tmp[$#tmp]\n" if -t STDIN;

            $eval =~ s/$REGEX/\$tmp[$#tmp]/;
        }
        
        if( $fail )
        {
            $eval{$test}{warnning} = "no find data {$1}{$2}{$3}";
            $eval{$test}{'stat'} = 'warn';
            next;
        }

        ( $eval{$test}{'err'}, $eval{$test}{'cnt'} ) = ( 1, 1 );
        ( $eval{$test}{'err'}, $eval{$test}{'cnt'} ) = ( $1, $2 )
            if $eval =~ s/<(\d+)\/(\d+)\>\s*$//;

        
        unless( $eval =~ /$REGEY/g  )
        {
            $eval{$test}{0} = eval $eval ? 'err' : 'ok';
            next;
        }

        unless( $table->{$1} ) {
            $eval{$test}{warnning} = "no find data {$1}{$2}{$3}";
            $eval{$test}{'stat'} = 'warn';
            next;
        }
        my $t; map{ $t = $_ if $col->{$_}{$3} }@{$table->{$1}};
        unless( defined $t )
        {
            $eval{$test}{warnning} = "no find data {$1}{$2}{$3}";
            $eval{$test}{'stat'} = 'warn';
            next;
        }

        my $c = $col->{$t}{$3};
        my @r = grep{ $data->[$t][$_][0] =~ /$2/ }1..@{$data->[$t]} -1;
        unless( defined $c && @r ){
            $eval{$test}{warnning} = "no find data {$1}{$2}{$3}";
            $eval{$test}{'stat'} = 'warn';
            next;
        }
        
        $eval{$test}{0} = 'ok';
        map{ 
            my $e = $eval;
            my $tmp = $data->[$t][$_][$c]; 
            warn "{$1}{$data->[$t][$_][0]}{$3} = $tmp\n" if -t STDIN;
            $e =~ s/$REGEY/\$tmp/;

            if( eval $e ) { $eval{$test}{0} = 'err'; next; }
        }@r;
    }

    for( keys %eval )
    {
        my $eval = $eval{$_};
        my ( $err, $cnt ) = map{ $eval->{$_} }qw( err cnt );
        next unless defined $err && $cnt;

        my $k = $keep > $cnt ? $keep : $cnt;
        map{ $eval->{$_} = $eval->{$_-1} if $eval->{$_-1} }reverse 1 .. $k;

        $eval->{'stat'} = 'ok';
        if(  $eval->{0} && $eval->{0} eq 'err' )
        {
            map{
                $err -- if $eval->{$_} && $eval->{$_} eq 'err';
                unless( $err ) { $eval->{'stat'} = 'err';next; }
            }1 .. $cnt;
        }
    }

    return $this;
}

1;