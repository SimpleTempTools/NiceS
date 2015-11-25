package NS::Collector::Jobs;
use strict;
use warnings;

use Carp;
use YAML::XS;

use Digest::MD5;
use Sys::Hostname;

use threads;
use Thread::Queue;

use NS::Collector::Push;
use NS::Collector::Sock;
use NS::Collector::Stat::Backup;

use Time::HiRes qw( time sleep alarm stat );

use Data::Dumper;

sub new
{
    my ( $class, %this ) = @_;

    map{ confess "no $_\n" unless $this{$_} && -d $this{$_} }
        qw( conf code logs data );
   
    NS::Collector::Sock->new( path => "$this{data}/output.sock" )->run();

    $NS::Collector::Stat::Backup::path = "$this{data}/backup";

    $this{config} = eval{ YAML::XS::LoadFile "$this{conf}/config" };
    confess "load config fail:$@\n" if $@;

    $this{md5} = Digest::MD5->new->add( YAML::XS::Dump $this{config} )->hexdigest;

    return bless \%this, ref $class || $class;
}

sub run
{
    my ( $this, $index ) = shift;

    my $queue = Thread::Queue->new;
    $SIG{ALRM} = sub{ die "code timeout."; };

    my $config = $this->{config};
    my $conf   = $config->{conf};
    my $push   = NS::Collector::Push->new( %{$config->{'push'}} ) if $config->{'push'};

    threads::async
    { 
        while( sleep 10 )
        {
            my $conf = eval{  YAML::XS::LoadFile "$this->{conf}/config" };
            if( $@ ){ warn "load config fail. exit(1).\n"; exit 1 };

            my $curr =  Digest::MD5->new->add( YAML::XS::Dump $conf )->hexdigest;
            if ( $curr ne $this->{md5} )
            {  warn "conf file has changed. exit(1).\n"; exit 1; }
        }
    }->detach;

    threads::async
    { 
        my $index = `ls -tr $this->{logs}/output.* |tail -n 1` =~ /\/output\.(\d+)\n$/ 
                    ? $1 : 0;

        while( 1 )
        {
            if (( stat "$this->{data}/output" )[9] > time - 90 )
            {
                $index = 1 if ++$index > 1024;
                system "cp '$this->{data}/output' '$this->{logs}/output.$index'";
                sleep 600;
            }
            else { sleep 30; }
        }
    }->detach;

    map{
        threads::async
        {
            print "init $_\n";
            my $conf = $conf->{$_};
            my ( $interval, $timeout, $code, $param, $i ) 
                = @$conf{qw( interval timeout code param )};

            $interval ||= 60; $timeout ||= $interval;

            $code = do "$this->{code}/$config->{conf}{$_}{code}";
            unless( $code && ref $code eq 'CODE' )
            {
                warn "load code fail: $_\n";
                exit 1;
            }

            while(1)
            {
                printf "do $_ (%d)...\n", ++ $i;
                my $time = time;
                eval
                {
                    alarm $timeout;
                    my $data = &$code( %$param );
                    $queue->enqueue( 'data', $_, YAML::XS::Dump $data );
                    alarm 0;
                };
                alarm 0;
                $queue->enqueue( 'code', $_, 
                    YAML::XS::Dump [ time - $time, $time, $@ ||'' ] 
                );

                sleep $interval;
            }
        }->detach;
    }keys %$conf;

    my ( $time, %data ) = time;

    my $prev = 0;
    while( 1 )
    {
        printf "do(%d)...\n", ++ $index;
        
        while( $queue->pending )
        {
            my ( $type, $name, $data ) = $queue->dequeue( 3 );
            $data{$type}{$name} = YAML::XS::Load $data;
        }

        my $uptime = $data{'collector'}{uptime} = time - $time;
        my $curr = int( $uptime / 60 );
        if ( $curr > $prev )
        {
            $prev = $curr;

            $data{'collector'}{cfgtime} = time - ( stat "$this->{conf}/config" )[9];
            my ( @t, @collector ) = qw( uptime cfgtime);
            push my @coll, [ 'TASK', @t ];
            push @coll, [ 'value', map{ $data{'collector'}{$_} }@t ];
            push my @code, [ qw( TASK usetime last err ) ];
            map
            {
                push @code, [ $_, @{$data{'code'}{$_}}];
            }sort keys %{$data{'code'}};

            push @collector, \@coll, \@code;
            $data{data}{collector} = \@collector;
            eval{ 
                YAML::XS::DumpFile "$this->{data}/.output", $data{data};
                $push->push( $data{data} ) if $push;
                $NS::Collector::Sock::DATA = YAML::XS::Dump $data{data};
            };
            
            system "mv '$this->{data}/.output' '$this->{data}/output'";
        }
        sleep 3;
    }
}

1;
