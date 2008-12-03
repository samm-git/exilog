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

package exilog_cgi_servers;
use exilog_config;
use exilog_cgi_html;
use exilog_cgi_param;
use exilog_sql;
use exilog_util;
use strict;

BEGIN {
  use Exporter;
  use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

  # set the version for version checking
  $VERSION     = 0.1;
  @ISA         = qw(Exporter);
  @EXPORT      = qw(
                      &servers
                   );

  %EXPORT_TAGS = ();

  # your exported package globals go here,
  # as well as any optionally exported functions
  @EXPORT_OK   = qw();
}


sub _get_num_queued {
  my $server = shift;
  my $h = {};

  $h->{queued} = sql_count('queue',{ 'server' => $server });

  $h->{frozen} = sql_count('queue',{ 'server' => $server,
                                     'frozen' => '1' } );

  $h->{frozen_bounce} = sql_count('queue',{ 'server' => $server,
                                            'mailfrom' => '<>',
                                            'frozen' => '1' } );

  my $tmp = sql_count('queue',{ 'server' => $server,
                                'mailfrom' => '<>' } );

  $h->{deferred} = $h->{queued} - $h->{frozen};
  $h->{deferred_bounce} = $tmp - $h->{frozen_bounce};

  return $h;
}

sub _get_h24_stats {
  my $server = shift;
  my $now = time();
  my $h = {};

  $h->{arrivals} = int( sql_count( 'messages',
                                   { 'server' => $server,
                                     'timestamp' => $now-86400 } ) / 1 );

  $h->{deliveries} = int( sql_count( 'deliveries',
                                     { 'server' => $server,
                                       'timestamp' => $now-86400 } ) / 1 );

  $h->{errors} = int( sql_count( 'errors',
                                 { 'server' => $server,
                                   'timestamp' => $now-86400 } ) / 1 );

  my $sizes = sql_select( 'messages', [ 'size' ], { 'server' => $server,
                                                    'timestamp' => $now-86400 } );

  my $total = 0;
  foreach (@{ $sizes }) { $total+=$_->{size}; };
  if ((scalar @{ $sizes }) > 0) {
    $h->{avg_msg_size} = int($total/(scalar @{ $sizes }));
  }
  else {
    $h->{avg_msg_size} = 0;
  };

  return $h;
}

sub servers {

  #print $q->div({-style=>"font-size: 28px; font-weight: bold;"},"Basic statictics for all servers");

  foreach my $server (sort {$a cmp $b} keys %{ $config->{servers} }) {
    print render_server($server,_get_num_queued($server),_get_h24_stats($server));
  };
}

1;
