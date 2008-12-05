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

use strict;

use lib "/usr/lib/exilog/";

use exilog_config;
use exilog_sql;

$0 = "[exilog_cleanup] $config->{cleanup}->{cutoff} days cutoff";

_cleanup($config->{cleanup}->{cutoff});

sub _cleanup {
  my $days = shift;

  my $now = time();
  my $cutoff_secs = $now - ($days * 86400);

  print STDERR "($$) [exilog_cleanup] Starting, cutoff date is ".scalar gmtime($cutoff_secs)."\n";

  # remove entries that always have server/message-id
  my $messages = sql_select('messages',
                            [ 'message_id', 'server' ],
                            { 'completed' => '0 '.$cutoff_secs },
                            undef,undef,undef,undef);
  print STDERR "($$) [exilog_cleanup] ".(scalar @{ $messages })." messages with completion beyond cutoff date.\n";
  my $num = 0;
  foreach (@{ $messages }) {
    $num += sql_delete('messages', $_);
    $num += sql_delete('deliveries', $_);
    $num += sql_delete('deferrals', $_);
    $num += sql_delete('errors', $_);
    $num += sql_delete('unknown', $_);
  };
  undef $messages;
  print STDERR "($$) [exilog_cleanup] $num records deleted.\n";

  # remove rejects
  print STDERR "($$) [exilog_cleanup] cleaning up rejects table.\n";
  $num = sql_delete('rejects',{ 'timestamp' => '0 '.$cutoff_secs });
  print STDERR "($$) [exilog_cleanup] $num records deleted.\n";

  # optimize tables
  print STDERR "($$) [exilog_cleanup] optimizing tables.\n";
  sql_optimize('messages');
  sql_optimize('deliveries');
  sql_optimize('deferrals');
  sql_optimize('errors');
  sql_optimize('unknown');
  sql_optimize('rejects');

  print STDERR "($$) [exilog_cleanup] Done.\n";
};
