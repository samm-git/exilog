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
use Fcntl ':mode';

use lib "/usr/lib/exilog/";

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

my $cfg_file = "/etc/exilog/exilog.conf";

$version = "0.5.1";

# check file permissions of exilog.conf

my $mode = (stat($cfg_file))[2];
# mask out file type;
$mode = $mode & 07777;
# we care only about others now
$mode = $mode & 0007;

if ( $mode > 0 ) {
  print STDERR "($$) [exilog_config] Attention - $cfg_file is readable by 'others'. Fix file permissions!\n";
  exit(0);
}

if ( ! -e $cfg_file ) {
  print STDERR "($$) [exilog_config] $cfg_file does not exist!\n";
  exit(0);
}

if ( ! -r $cfg_file ) {
  my $username = getpwuid($<);
  print STDERR "($$) [exilog_config] $cfg_file is not readable by user ". $username ."!\n";
  exit(0);
}

$config = _read_ph($cfg_file);

# check if user forgots to add a trailing slash - if so, add it here
if ( $config->{web}->{webroot} !~ /\/$/ ) {
  $config->{web}->{webroot}.="/";
}

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
