package NS::Poros::Path;

=head1 NAME

NS::Poros::Path - Implements NS::Util::DirConf

=cut
use strict;
use base qw( NS::Util::DirConf );

=head1 CONFIGURATION

A YAML file that defines I<code>, I<run> paths.
Each must be a valid directory or symbolic link.

=cut
sub define { qw( code run ) }

1;
