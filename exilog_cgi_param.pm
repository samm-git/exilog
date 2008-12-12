#!/usr/bin/perl -w
#
# This file is part of the exilog suite.
#
# http://duncanthrax.net/exilog/
#
# (c) Tom Kistner 2004
#
# See LICENSE for licensing information.
#

package exilog_cgi_param;
use strict;
use exilog_cgi_html;
use exilog_config;

use Data::Dumper;

BEGIN {
  use Exporter;
  use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

  $VERSION     = 0.1;
  @ISA         = qw(Exporter);
  @EXPORT      = qw(
                      $param
                   );

  %EXPORT_TAGS = ();
  @EXPORT_OK   = qw();

  use vars qw( $param );
}

$param = _init_cgi_params();

sub _init_cgi_params {
  my $param = {};

  foreach ($q->param) {
    my @test = $q->param($_);

    if ((scalar @test) > 1) {
      $param->{$_} = \@test;
    }
    else {
      $param->{$_} = $test[0];
    };
  };

  # defaults
  my $defaults = {
    'tab' => 'messages',
    'qw' => [ 'messages',
              'errors',
              'deliveries',
              'deferrals',
              'rejects',
              'queue' ],
    'ss' => '-all',
    'tr' => '-10m',
    #'qt' => 'all',
    'qs' => "",
    'sr' => [ keys %{ $config->{servers} } ]
  };

  foreach (keys %{ $defaults }) {
    $param->{$_} = $defaults->{$_} unless exists($param->{$_});
  };
  return $param;
};


1;
