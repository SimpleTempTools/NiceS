#!/usr/bin/env perl
my $perl = $ENV{PERL_PATH} || $^X;
my $nices = $perl;$nices =~ s/\/perl\/bin\/perl$//;
exec "$perl Makefile.PL && make && make install nices=$nices && make clean";
