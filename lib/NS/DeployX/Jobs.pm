package NS::DeployX::Jobs;
use strict;
use warnings;

use Carp;
use AnyEvent;
use NS::Hermes;
use Time::HiRes qw( time );

use threads;
use Thread::Queue;

our %CONF = ( redo => 0, retry => 0, timeout => 0, goon => '100%', max => 0, sleep => 30 );

sub new
{
    my ( $class, %self ) = splice @_;

    map{
        unless( defined $self{$_} )
        {
             print "no $_\n";
             exit 115;
        }
    }qw( name step conf ctrl code cache cachedb );
    
    bless \%self, ref $class || $class;
}

sub run
{
    my ( $this, @node ) = @_;

    @node = map{ @$_ }@node if ref $node[0] eq 'ARRAY';
    my %node = map{ $_ => 1 }@node;

    my ( $name, $step, $conf, $ctrl, $code, $cache, $cachedb, $myid, $user )
        = @$this{qw( name step conf ctrl code cache cachedb myid user )};

    map { $conf->{$_} = $CONF{$_} unless defined $conf->{$_} }keys %CONF;
    my ( $redo, $retry, $title, $delay, $sleep, $repeat, $timeout, $grep, $fix, $goon, $max ) 
        = @$conf{qw( redo retry title delay sleep repeat timeout grep fix goon max )};

    $goon = ( $goon * scalar @node ) / 100 if $goon =~ s/%$//;

    print '#' x 28, POSIX::strftime( "%F_%T", localtime ), '#' x 28, "\n";
    printf "$title\n";

    my ( $range, %succ, %tryfix ) = NS::Hermes->new();

    my $sc = sub
    {
        my ( $node, $stat ) = @_;
        $cachedb->sc( $node, $stat ? "1": "0" );
    };

    my $rx = sub
    {
        scalar $range->load( \@_ )->list(),
        $range->load( \@_ )->dump();
    };

    for my $i ( 0 .. $redo )
    {
        my $t = $tryfix{$i} ? 'tryfix' : $i ? "redo #$i" : 'do';
        printf "$t ...\n" unless $t eq 'do';
 
        my ( $try, $error ) = ( $tryfix{$i} ? $tryfix{$i} -1 : $retry );
        for my $j ( 0 .. $try )
        {
            if( $tryfix{$i} )
            {
                my @o = $ctrl->stuck( $title, $step );

                if( my @exit = grep{ $_->[2] eq 'exit' }@o )
                {
                   printf "deploy exit by user: %s\n", join ':', map{ $_->[5]}@exit;
                   kill 10, $$;
                }
                last unless @o;

                printf "try fix %s\n", $j +1;
            }
            else
            {
                print "retry $j\n" if $j;
                _stuck( $ctrl, $title, $step );
            }

            %succ = () if $repeat;
            my %excluded = map{ $_ => 1 }@{$ctrl->excluded()};

            my @ex = grep{ $excluded{$_} }@node;
            my @su = grep{ $succ{$_} }@node;
            my @gr = grep{ ! $cache->{succ}{$grep}{$_} }@node if $grep;

            printf "Already exclude[%s]: %s\n", &$rx( @ex ) if @ex;
            printf "Already successful[%s]: %s\n", &$rx( @su ) if @su;
            printf "grep from $grep exclude[%s]: %s\n", &$rx( @gr ) if $grep && @gr;

            my @node = grep{ ! $succ{$_} }grep{ ! $excluded{$_} }@node;
            @node = grep{ $cache->{succ}{$grep}{$_} }@node if $grep;

            last if ! @node && $tryfix{$i};
           

            printf "node[%s]: %s\n", &$rx( @node );
        
            sleep $delay if $delay && print "delay $delay sec ...\n";
    
            my %s;
            &$sc( map{ $_ => 0 }@node ) if @node;
            unless( $max )
            {
                eval{
                    alarm $timeout;
                    %s = &$code
                    (
                        param => $conf->{param},
                        batch => \@node,
                        title => $title,
                        name => $name,
                        myid => $myid,
                        step => $step,
                        user => $user,
                        sc => $sc,
                    );
                   alarm 0;
                } if @node;
                alarm 0;
                $error = $@ || '';
            }
            else
            {
                 my @conn = map { Thread::Queue->new } 0 .. 1;
                 my %node = map{$_ => 1 }@node;
                 $conn[0]->enqueue( @node );
                 my $m = ( $max > scalar @node ) ? scalar @node: $max;
                 map
                 {
                     threads::async
                     {
                         while ( my $node = $conn[0]->dequeue() )
                         {
                             my $stat = &$code(
                                 param => $conf->{param},
                                 title => $title,
                                 node => $node,
                                 name => $name,
                                 myid => $myid,
                                 step => $step,
                                 user => $user,
                             );
                             print "$node => $stat\n";
                             &$sc( $node, $stat );
                             $conn[1]->enqueue( $node, $stat );
                         }
                     }->detach()
                 } 1 .. $m;

                 while ( 1 )
                 {
                     while ( $conn[1]->pending )
                     {
                         my ( $node, $stat ) = $conn[1]->dequeue( 2 );
                         delete $node{$node};
                         $s{$node} = 1 if $stat;
                     }
                     sleep 0.3;
                     last unless %node;
                 }
                 $error = '';
            }


            map{ $succ{$_} = $s{$_} }grep{ $node{$_} }keys %s;

            $error = sprintf( "goon: $goon succ: %s %s", scalar keys %succ, $error ? "err:$error":'' )
                if keys %succ < $goon;


            sleep $sleep if $sleep && print "sleep $sleep sec ...\n";
            last unless $error;
            printf "$error%s",  $error =~ /\n/ ? '' : "\n";
 
        }

        $ctrl->resume( $title, $step ) if $tryfix{$i} && !$error;

        last unless $error;

        if( $error !~ /^[\/\w _\.:-]*$/ )
        {
            $error =~ s/[^\/^a-z^A-Z^0-9^ ^_^\.^:^-]/*/g;
            $error = "error evil:$error";
        }

        $ctrl->pause( 'error', $title, $step, $error ) unless $tryfix{$i};

        redo if ! $tryfix{$i} && ( $tryfix{$i} = $fix );
        _stuck( $ctrl, $title, $step );

    }

    printf "succ[%d]:%s\nfail[%s]:%s\n", &$rx( keys %succ ) , &$rx( grep{ ! $succ{$_} }@node );

    return %succ;
}

sub _stuck
{
    my ( $ctrl, @stuck ) = @_;
    return unless $ctrl->stuck( @stuck );

    printf "stuck\n";
    sleep 3;
    while( my @o = $ctrl->stuck( @stuck ) )
    {
       if( my @exit = grep{ $_->[2] eq 'exit' }@o )
       {
          printf "deploy exit by user: %s\n", join ':', map{ $_->[5] }@exit;
          kill 10, $$;
       }
       sleep 3; 
    }
}
#sub _stuck
#{
#    my ( $ctrl, @stuck ) = @_;
#    return unless $ctrl->stuck( @stuck );
#
#    printf "stuck.%s\n", POSIX::strftime( "%F_%T", localtime );
#    print "#" x 60, "\n";
#    my @x = ([1,20,1,3],[1,60,4,1],[2,120,10,1]);
#    my ( $i, $x, $t ) = ( 0, 0, time );
#    sleep 2;
#    while( my @o = $ctrl->stuck( @stuck ) )
#    {
#       if( my @exit = grep{ $_->[2] eq 'exit' }@o )
#       {
#          printf "deploy exit by user: %s\n", join ':', map{ $_->[5]}@exit;
#          kill 10, $$;
#       }
#
#       $i++;
#       if( $x < 3 )
#       {
#           print '#' x $x[$x][3] unless $i % $x[$x][0];
#           unless( $i % $x[$x][1] ) { $i = 0; print " $x[$x][2](min)\n"; $x ++; }
#       }
#       else
#       {
#           print '#' unless $i % 5;
#           unless( $i % 300 )
#           {
#               my $min = int( ( time - $t ) / 60 );
#               $min > 60 ? printf( " %.2d:%.2d\n", int( $min/60 ), $min%60 ) 
#                         : print( " $min(min)\n" );
#           }
#       }
#       sleep 3; 
#    }
#    printf "resume.%s\n", POSIX::strftime( "%F_%T", localtime );
#    print "#" x 60, "\n";
#}

1;
