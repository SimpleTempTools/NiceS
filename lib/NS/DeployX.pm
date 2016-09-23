package NS::DeployX;
use strict;
use warnings;

use Carp;
use POSIX;
use YAML::XS;

use Data::Dumper;

use NS::DeployX::Conf;
use NS::DeployX::Code;
use NS::DeployX::Jobs;

use NS::DeployX::Cache;

use NS::Hermes;
use NS::Util::DBConn;
use NS::OpenAPI::Ctrl;
use NS::OpenAPI::Lock;

sub new 
{
    my ( $class, %self ) = splice @_;

    my $name = $self{name};

    $self{main} ||= 'A';
    $self{conf} ||= 'deploy';

    my $info = +{ map{ $_ => $self{$_} }qw(main conf argv) };
    my $cache = NS::DeployX::Cache->new( $name );
    my $mark = $cache->mark();
    my ( $main, $conf ) = 
        $mark ? NS::DeployX::Conf->old( $name, $mark )
              : NS::DeployX::Conf->new( 
                    $name, $self{main} , $self{conf}
                 )->dump( $self{macro } );

    bless +{ 
        user => $self{user},
        name => $name,
        main => $main, 
        conf => $conf, 
        info => $info,
        cache => $cache,
        code => NS::DeployX::Code->new( $self{code} => [ $main, @$conf ] ),
        global => [ map{ $_->{global} ? 1 : 0 }@$conf ]
    }, ref $class || $class;
}

sub run
{

    my ( $self, %run ) = @_;
    my ( $name, $user, $main, $conf, $info, $code, $global ) 
        =  @$self{ qw( name user main conf info code global ) };

    my $lock = NS::OpenAPI::Lock->new( name => $name );

    unless( $lock->lock() )
    {
        printf "$name is already running in proc: %s\n", join ':',$lock->check();
        exit 110;
    }

    $SIG{TERM} = $SIG{INT} = sub
    {
        $lock->unlock();
        print "deploy: killed.\n";
        exit 1;
    };

    my $ctrl = NS::OpenAPI::Ctrl->new( name => $name ),
    my $cachedb = $self->{cache}->rnew( $main, $conf, $run{myid}, $user );
    unless( $cachedb )
    {
        $lock->unlock();
        print "deploy: exit 111.\n";
        exit 111;
    }
    $SIG{USR1} = sub
    {
        $cachedb->clear();
        $ctrl->clear();
        $lock->unlock();
        print "deploy: killed.\n";
        exit 112;
    };


    my @batch;

    my $cache = $cachedb->cache();

    if( keys %$cache )
    {
        @batch = @{$cache->{node}};
        $ctrl->pause( 'error', 'init', 'cache', 'load cache ok' );
        print "[WARN] load info from cache,you need to manually resume.\n";
    }
    else
    {

        @batch = &{$code->{$main->{code}}}( %{$main->{param}}, name => $name );
        $cache->{node} = \@batch;
        $cache->{info} = $info;
    }
    $cachedb->cache( $cache );

    my $blen = scalar @batch;

    $ctrl->pause( 'error', 'init', 'batch', 'node is null' ) unless @batch;
    
    NS::DeployX::Jobs::_stuck( $ctrl, 'init' );

    my ( $i, $index, @job ) = ( 0, 0 );
 
    for ( @$global )
    {
        push @{$job[$index]}, $i ++;
        $index ++ if $_ == 1 || ( $global->[$i] && $global->[$i] == 1 );
    }

    my ( @node, @jobs, @index );
    for my $job ( @job )
    {
        push @node,  $global->[$job->[0]] == 1 ? \@batch : @batch;
        my $len = $global->[$job->[0]] == 1 ? 1: scalar @batch;
        map{ push @jobs, $job;  push @index, $_; } 1 .. $len;
    }

    $cache->{step} = [ map{ $_->{title} }@$conf ];
    $cache->{glob} = [ map{ $_->{global}||0 }@$conf ];

    $cachedb->cache( $cache );

    my $range = NS::Hermes->new();
    my $mark = $cachedb->mark();
    for my $id ( 0 .. @jobs -1 )
    {
        for my $j ( @{$jobs[$id]} )
        {
             my ( $title, $step ) = ( $conf->[$j]{title}, $index[$id]);

             $cache->{todo} = [ $title, $step];

             $cachedb->set_sc( "name:${name}:mark:$mark:title:$title:step:$step" );

             
             $cache->{time}{$title}{$step } 
                 = POSIX::strftime( "%T", localtime );
             $cachedb->cache( $cache );


             if(  $cache->{done}{$title}{$step} )
             {
                 print "skip:$title-$step\n";
                 next;
             }

             my %succ =
             NS::DeployX::Jobs->new(
                 name => $name,
                 user => $user,
                 step => $step,
                 blen => $blen,
                 conf => $conf->[$j],
                 myid => $run{myid},
                 ctrl => $ctrl,
                 code => $code->{$conf->[$j]->{code}},
                 cache => $cache,
                 cachedb => $cachedb,
             )->run( @{$node[$id]} );


             map{ $cache->{succ}{$conf->[$j]{title}}{$_} = $succ{$_} }keys %succ;


             $cache->{done}{$title}{$step} = 1;
             $cache->{todo} = [];

             $cachedb->cache( $cache );
        }
    }

    $ctrl->clear();
    $lock->unlock();
    $cachedb->clear();

    print "OVER~\n";
    return 0;
}

1;
