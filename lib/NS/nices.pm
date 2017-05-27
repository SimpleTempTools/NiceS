package NS::nices;

use strict;
use warnings;

=head1 NAME

nices - A suite of cluster administration tools and platforms

=cut
our $VERSION = '0.2.9';
our $NiceS;

require 5.000;
require Exporter;
our @EXPORT_OK = qw( $NiceS );
our @ISA = qw(Exporter);

BEGIN{
   my @path;
   for( split /\//,  __FILE__ )
   {
       push @path, $_;
       last if $_ eq 'nices';
   }
   $ENV{NiceSPATH} = $NiceS = @path ? join '/', @path : '/tmp/nices';
};

=head1 MODULES

=head3 Hermes

A cluster information management platform

 Hermes
 Hermes::Range
 Hermes::KeySet
 Hermes::Integer
 Hermes::Cache
 Hermes::Call
 Hermes::DBI::Cache
 Hermes::DBI::Root

=head3 Poros

A plugin execution platform

 Poros
 Poros::Path
 Poros::Query

=head3 Cronos

A scheduler

 Cronos
 Cronos::Period
 Cronos::Policy

=head1 AUTHOR

Lijinfeng, C<< <lijinfeng2011 at github.com> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2015 Lijinfeng.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

=cut

1;
