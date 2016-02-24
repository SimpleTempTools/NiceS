package NS::DeployX;
use strict;
use warnings;

use Carp;
use POSIX;
use YAML::XS;

use Data::Dumper;

use NS::DeployX::Conf;
use NS::DeployX::Code;
use NS::DeployX::Ctrl;
use NS::DeployX::Jobs;

use NS::DeployX::Cache;

use NS::DeployX::Lock;
use NS::DeployX::Ctrl;
use NS::Hermes;
use NS::Util::DBConn;

sub new 
{
    my ( $class, %self ) = splice @_;

    my $name = $self{name};
    my ( $main, $conf ) = NS::DeployX::Conf->new( $name, $self{conn} )->dump();

    bless +{ 
        name => $name,
        main => $main, 
        conf => $conf, 

        code => NS::DeployX::Code->new( $self{code} => [ @$conf, $main ] ),
        conn => $self{conn}
#        ctrl => NS::DeployX::Ctrl->new( $name => "$self{ctrl}" ),
#
#        cache => "$self{cache}/$name",
#        global => [  map{ $_->{global} ? 1 : 0 }@$maint ],
    }, ref $class || $class;
}

sub run
{

    my $self = shift;
    my ( $name, $main, $conf, $code, $conn ) =  @$self{ qw( name main conf code conn ) };

    my $lock = NS::DeployX::Lock->new( $name => $conn );
    print Dumper $lock;
    unless( $lock->lock() )
    {
        printf "$name is already running in proc: %s\n", join ':',$lock->check();
        exit 1;
    }

    $SIG{TERM} = $SIG{INT} = sub
    {
        $lock->unlock();
        print "deploy: killed.\n";
        exit 1;
    };


    my $ctrl = NS::DeployX::Ctrl->new( $name => $conn );
#    my $cache = NS::DeployX::Cache->new( $name => $conn );


print Dumper $main;
    my @batch = &{$code->{$main->{code}}}( map{ $_ => $main->{$_} }qw( target batch sort each test ) );
print Dumper \@batch;

print Dumper $conf;

my $cache;
    $cache->{step} = [ map{ $_->{title} }@$conf ];
    $cache->{glob} = [ map{ $_->{global}||0 }@$conf ];
print Dumper $cache;
#    my @batch = 
#
#    my @batch;
#    if( -e $cache_path )
#    {
#        $cache  = NS::DeployX::Cache->load( $cache_path, $maint );
#
#        @batch = @{$cache->{node}};
#        
#        $ctrl->pause( 'error', 'init', 'cache', 'load cache ok' );
#        print "[WARN] load info from cache,you need to manually resume.\n";
#    }
#    else
#    {
#        my $batch = $conf->{batch};
#        @batch = $code->run( 
#            $batch->{code}, param => $batch->{param}, cache => $cache
#        );
#        $cache->{node} = \@batch;
#        
#        system sprintf "ln -fsn '%s' '%s'",
#            POSIX::strftime( "$name.%Y-%m-%d_%H:%M:%S", localtime ), $cache_path;
#    }
#
#    $ctrl->pause( 'error', 'init', 'batch', 'node is null' ) unless @batch;
#
#    sleep 3 while $ctrl->stuck( 'init' );
#
#    my ( $i, $index, @job ) = ( 0, 0 );
#    
#    for ( @$global )
#    {
#        push @{$job[$index]}, $i ++;
#        $index ++ if $_ == 1 || ( $global->[$i] && $global->[$i] == 1 );
#    }
#    
#    my ( @node, @jobs, @index );
#    for my $job ( @job )
#    {
#        push @node,  $global->[$job->[0]] == 1 ? \@batch : @batch;
#        my $len = $global->[$job->[0]] == 1 ? 1: scalar @batch;
#        map{ push @jobs, $job;  push @index, $_; } 1 .. $len;
#    }
#
#    
#    $cache->{step} = [ map{ $_->{title} }@$maint ];
#    $cache->{glob} = [ map{ $_->{global}||0 }@$maint ];
#
#    YAML::XS::DumpFile $cache_path, $cache;
#
#
#    my $range = NS::Hermes->new();
#    for my $id ( 0 .. @jobs -1 )
#    {
#        for my $j ( @{$jobs[$id]} )
#        {
#
#             my ( $title, $step ) = ( $maint->[$j]{title}, $index[$id]);
#
#             $cache->{todo} = [ $title, $step];
#             $cache->{time}{$title}{$step } 
#                 = POSIX::strftime( "%T", localtime );
#             YAML::XS::DumpFile $cache_path, $cache;
#
#
#             if(  $cache->{done}{$title}{$step} )
#             {
#                 print 'x' x 75, "\n";
#                 print "skip|title:$title step:$step\n";
#                 print 'x' x 75, "\n";
#                 next;
#             }
#            
#             my %succ = 
#             NS::DeployX::Jobs->new( 
#                 name => $name,
#                 step => $step,
#                 conf => $maint->[$j], 
#                 ctrl => $ctrl,
#                 code => $code->{$maint->[$j]->{code}},
#                 cache => $cache,
#             )->run( @{$node[$id]} );
#
#             map{ $cache->{succ}{$maint->[$j]{title}}{$_} = $succ{$_} }keys %succ;
#
#             printf "succ[%d]:%s\n"
#                 ,scalar $range->load( [ keys %succ ] )->list
#                 , $range->load( [ keys %succ ] )->dump;
#
#             $cache->{done}{$title}{$step} = 1;
#             $cache->{todo} = [];
#             YAML::XS::DumpFile $cache_path, $cache;
#        }
#    }
#
#    unlink $cache_path;
#

    $ctrl->clear();
    $lock->unlock();
    return 0;
}

1;
