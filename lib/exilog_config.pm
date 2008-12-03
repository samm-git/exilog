#!/usr/bin/perl
#
# This file is part of the exilog suite.
# 
# http://duncanthrax.net/exilog/
#
# (c) Tom Kistner 2004
#
# See LICENSE for licensing information.
#

package exilog_config;
use strict;

use FindBin;
use FindBin qw($RealBin);
use lib "$RealBin/";


BEGIN {
  use Exporter;
  use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

  # set the version for version checking
  $VERSION     = 0.1;
  @ISA         = qw(Exporter);
  @EXPORT      = qw(
                      $config
                      $version
                   );

  %EXPORT_TAGS = ();

  # your exported package globals go here,
  # as well as any optionally exported functions
  @EXPORT_OK   = qw();
  
  use vars qw( $config $version );
}

$version = "0.5";

$config = _read_ph("$RealBin/exilog.conf");

unless ($config) {
  print STDERR "($$) [exilog_config] Can't parse configuration file.\n";
  exit(0);
};

sub _read_ph {
  my $file = shift;
  
  open(PH,"< $file");
  undef $/;
  my $tmp = (eval(<PH>));
  print STDERR "Eval Error: ".$@."\n" if ($@);
  $/ = "\n";
  close(PH);
  
  return $tmp;
};

1;
