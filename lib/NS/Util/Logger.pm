package NS::Util::Logger;

=head1 NAME

Util::Logger - thread safe logger

=head1 SYNOPSIS

 use Util::Logger;

 my $log = Util::Logger->new( $handle );

 $log->info( 'foo', 'bar' );
 $log->info( 'foo', 'bar' );

=cut
use warnings;

use Vulcan::Logger;
use base Exporter;
our @EXPORT_OK = qw( debug verbose info warning error );


my (%level, $logger) = (debug => -2, verbose => -1, info => 0, warning => 1, error => 2);

sub ini{ $logger = Vulcan::Logger->new(@_); }

sub debug{ _say(caller, 'debug', @_) };
sub verbose{ _say(caller, 'verbose', @_) };
sub info{ _say(caller, 'info', @_) };
sub warning{ _say(caller, 'warning', @_) };
sub error{ _say(caller, 'error', @_) };

sub _say
{
    NS::Util::Logger::ini unless $logger;

    my($package, $filename, $line, $level, @str, $l) = @_;
    $l = $level{ $ENV{NS_LOG_LEVEL} } if $ENV{NS_LOG_LEVEL};

    $l ||= $level{'info'};

    return unless $level{$level} >= $l;

    $logger->say('[%s][%s:%s]: %s', $level, $package, $line, join(' ', grep{$_}@str) );
}

1;
