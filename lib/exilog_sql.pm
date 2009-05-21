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

package exilog_sql;
use strict;
use DBI;
use exilog_config;
use exilog_util;

use Data::Dumper;

BEGIN {
  use Exporter;
  use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

  # set the version for version checking
  $VERSION     = 0.1;
  @ISA         = qw(Exporter);
  @EXPORT      = qw(
                      &reconnect
                      &sql_select
                      &sql_delete
                      &sql_optimize
                      &sql_count
                      &sql_update_heartbeat
                      &sql_queue_add
                      &sql_queue_update
                      &sql_queue_delete
                      &sql_queue_set_action
                      &sql_queue_clear_action
                      &write_message
                   );

  %EXPORT_TAGS = ();

  # your exported package globals go here,
  # as well as any optionally exported functions
  @EXPORT_OK   = qw();
}


# open DB connection
my $dbh = DBI->connect($config->{sql}->{DBI}, $config->{sql}->{user}, $config->{sql}->{pass});
unless (defined($dbh) && $dbh) {
  print STDERR "[exilog_sql] Can't open exilog database.\n";
  exit(255);
};

sub reconnect {
  my $conditional = shift || 0;
  if ($conditional) {
    return 1 if ($dbh->ping);
  };
  eval {
    $dbh->disconnect() if (defined($dbh));
  };
  $dbh = 0;
  $dbh = DBI->connect($config->{sql}->{DBI}, $config->{sql}->{user}, $config->{sql}->{pass});
  unless (defined($dbh) && $dbh) {
    print STDERR "[exilog_sql] Can't open exilog database.\n";
    return 0;
  };
  return 1;
};


# --------------------------------------------------------------------------
# Generic Stubs, these are just frontends that call the backend-specific
# SQL subroutines for each database type.
sub write_message {
  no strict "refs";
  return &{ "_".$config->{sql}->{type}."_write_message" }(@_);
};

sub sql_select {
  no strict "refs";
  return &{ "_".$config->{sql}->{type}."_sql_select" }(@_);
};

sub sql_delete {
  no strict "refs";
  return &{ "_".$config->{sql}->{type}."_sql_delete" }(@_);
};

sub sql_optimize {
  no strict "refs";
  return &{ "_".$config->{sql}->{type}."_sql_optimize" }(@_);
};

sub sql_update_heartbeat {
  no strict "refs";
  return &{ "_".$config->{sql}->{type}."_sql_update_heartbeat" }(@_);
};

sub sql_queue_add {
  no strict "refs";
  return &{ "_".$config->{sql}->{type}."_sql_queue_add" }(@_);
};

sub sql_queue_update {
  no strict "refs";
  return &{ "_".$config->{sql}->{type}."_sql_queue_update" }(@_);
};

sub sql_queue_delete {
  no strict "refs";
  return &{ "_".$config->{sql}->{type}."_sql_queue_delete" }(@_);
};

sub sql_queue_set_action {
  no strict "refs";
  return &{ "_".$config->{sql}->{type}."_sql_queue_set_action" }(@_);
};

sub sql_queue_clear_action {
  no strict "refs";
  return &{ "_".$config->{sql}->{type}."_sql_queue_clear_action" }(@_);
};

sub sql_count {
  no strict "refs";
  return &{ "_".$config->{sql}->{type}."_sql_count" }(@_);
};
# --------------------------------------------------------------------------


# --------------------------------------------------------------------------
# PostgreSQL functions
sub _pgsql_sql_count {
  my $where = shift;
  my $criteria = shift || {};

  my $sql = "SELECT ".
            "COUNT(*) ".
            "FROM ".$where.
            ((scalar keys %{ $criteria } ) ? " "._build_WHERE($criteria) : "" );

  my $sh = $dbh->prepare($sql);
  $sh->execute;
  my $tmp = $sh->fetchrow_arrayref();
  return @{$tmp}[0];
};

# Postgres has no REPLACE command so the best thing to do is
# check to see if there exists any heartbeat record before
# attempting to UPDATE one. If it's not there, lets INSERT one.
sub _pgsql_sql_update_heartbeat {
  my $now = time();
  my $existing_beat = $dbh->do("SELECT timestamp from heartbeats WHERE server = '". $config->{agent}->{server} ."'");

  if ($existing_beat != '1') {
      $dbh->do("INSERT INTO heartbeats(timestamp, server) VALUES('". $now ."', '". $config->{agent}->{server} ."')");
     }
      else
     {
      $dbh->do("UPDATE heartbeats SET timestamp = '". $now ."' WHERE server = '". $config->{agent}->{server} ."'");
     }
};

sub _pgsql_sql_queue_delete {
  my $spool_path = shift;

  $dbh->do("DELETE FROM queue WHERE spool_path=".$dbh->quote($spool_path));
};

sub _pgsql_sql_queue_update {
  my $hdr = shift;

  return unless (ref($hdr) eq 'HASH');

  my $server = $hdr->{server};
  my $message_id = $hdr->{message_id};
  delete $hdr->{server};
  delete $hdr->{message_id};

  # PostgreSQL is case sensitive by default. Nice feature,
  # but it complicates our life tremendously.
  # Since we want to keep indexes working, the columns in
  # this list are lowercased before they are inserted. Sigh.
  my @lowercase = ( 'mailfrom', 'recipients_delivered', 'recipients_pending' );
  foreach my $col (@lowercase) {
    $hdr->{$col} = lc($hdr->{$col}) if (edt($hdr,$col));
  };

  my @tmp;
  foreach my $item (keys %{ $hdr }) {
    push @tmp, $item.'='.$dbh->quote($hdr->{$item});
  };

  $dbh->do("UPDATE queue SET ".join(",",@tmp).
           " WHERE message_id=".$dbh->quote($message_id).
           " AND server=".$dbh->quote($server));
};

sub _pgsql_sql_queue_add {
  my $hdr = shift;

  return unless (ref($hdr) eq 'HASH');

  # PostgreSQL is case sensitive by default. Nice feature,
  # but it complicates our life tremendously.
  # Since we want to keep indexes working, the columns in
  # this list are lowercased before they are inserted. Sigh.
  my @lowercase = ( 'mailfrom', 'recipients_delivered', 'recipients_pending' );
  foreach my $col (@lowercase) {
    $hdr->{$col} = lc($hdr->{$col}) if (edt($hdr,$col));
  };

  my @fields = sort {$a cmp $b} keys(%{$hdr});
  my @vals = ();
  foreach (@fields) {
    push @vals, $dbh->quote($hdr->{$_});
  };

  $dbh->do("INSERT INTO queue (".join(',',@fields).") VALUES(".join(',',@vals).")");
};

sub _pgsql_sql_queue_set_action {
  my $server = shift;
  my $message_id = shift;
  my $action = shift;

  $dbh->do("UPDATE queue SET action=".$dbh->quote($action).
           " WHERE server=".$dbh->quote($server).
           " AND message_id=".$dbh->quote($message_id));
};

sub _pgsql_sql_queue_clear_action {
  my $server = shift;
  my $message_id = shift;

  $dbh->do("UPDATE queue SET action=NULL WHERE server=".$dbh->quote($server).
           " AND message_id=".$dbh->quote($message_id));
};

sub _pgsql_sql_optimize {
  return 1; #postgres doesn't need to do anything as long as autovaccum is on
};

sub _pgsql_sql_delete {
  my $where = shift || "nothing";
  my $criteria = shift || {};

  my $sql = "DELETE FROM ".$where.
            ((scalar keys %{ $criteria } ) ? " "._build_WHERE($criteria) : "" );

  my $sh = $dbh->prepare($sql);
  my $num = $sh->execute;
  $sh->finish;

  return (($num eq '0E0') ? 0 : $num);
};

sub _pgsql_sql_select {
  my $where = shift;
  my @what = @{ (shift || [ "*" ]) };
  my $criteria = shift || {};
  my $order_by = shift || "";
  my $order_direction = shift || "DESC";
  my $limit_min = shift;
  my $limit_max = shift;
  my $distinct = shift;

  my $sql = "SELECT ".
            (defined($distinct) ? "DISTINCT " : "").
            join(", ", @what).
            " FROM ".$where.
            ((scalar keys %{ $criteria } ) ? " "._build_WHERE($criteria) : "" ).
            ($order_by ? " ORDER BY ".$order_by." ".$order_direction : "").
            (defined($limit_min) ? " LIMIT ".$limit_min : "").
            (defined($limit_max) ? ",".$limit_max : "");

  return _fetch_multirow($where, $sql);
};

sub _pgsql_write_message {
  my $server = shift || 'default';
  my $h = shift;
  my $rc = 0;

  # PostgreSQL is case sensitive by default. Nice feature,
  # but it complicates our life tremendously.
  # Since we want to keep indexes working, the columns in
  # this list are lowercased before they are inserted. Sigh.
  my @lowercase = ( 'mailfrom', 'rcpt', 'rcpt_final', 'host_dns', 'host_helo', 'host_rdns' );
  foreach my $col (@lowercase) {
    $h->{data}->{$col} = lc($h->{data}->{$col}) if (edt($h->{data},$col));
  };

  # Special case: we only need to UPDATE the 'completed' field
  # in the messages table.
  if ( ($h->{table} eq 'messages') && (exists($h->{data}->{completed})) ) {
    my $rc = $dbh->do("UPDATE messages SET completed=".$dbh->quote($h->{data}->{completed}).
                      " WHERE message_id=".$dbh->quote($h->{data}->{message_id}).
                      " AND server=".$dbh->quote($server));
    if (defined($rc)) {
      return 1;
    }
    else {
      # error
      return 0;
    };
  }
  else {
    my @fields = sort {$a cmp $b} keys(%{$h->{data}});
    my @vals = ( $dbh->quote($server) );
    foreach (@fields) {
      push @vals, $dbh->quote(substr($h->{data}->{$_},0,255));
    };
    unshift @fields, 'server';

    my $sql = "INSERT INTO ".$h->{table}.' ("'.join('","',@fields).'") VALUES('.join(',',@vals).")";
    my $rc = $dbh->do($sql);

    if (defined($rc)) {
      return 1;
    }
    else {
      return 2 if ($dbh->errstr =~ /duplicate/i);
      print STDERR "SQL Error (code ".$dbh->err.") on '$h->{table}' with query: $sql\n";
      return 0;
    };
  };
};


# --------------------------------------------------------------------------
# MySQL functions
sub _mysql_sql_count {
  my $where = shift;
  my $criteria = shift || {};

  my $sql = "SELECT ".
            "COUNT(*) ".
            "FROM ".$where.
            ((scalar keys %{ $criteria } ) ? " "._build_WHERE($criteria) : "" );

  my $sh = $dbh->prepare($sql);
  $sh->execute;
  my $tmp = $sh->fetchrow_arrayref();
  return @{$tmp}[0];
};

sub _mysql_sql_update_heartbeat {
  my $now = time();

  $dbh->do("REPLACE heartbeats SET server='". $config->{agent}->{server} ."', timestamp='". $now ."'");
};

sub _mysql_sql_queue_delete {
  my $spool_path = shift;

  $dbh->do("DELETE FROM queue WHERE spool_path=".$dbh->quote($spool_path));
};

sub _mysql_sql_queue_update {
  my $hdr = shift;

  return unless (ref($hdr) eq 'HASH');

  my $server = $hdr->{server};
  my $message_id = $hdr->{message_id};
  delete $hdr->{server};
  delete $hdr->{message_id};

  my @tmp;
  foreach my $item (keys %{ $hdr }) {
    push @tmp, $item.'='.$dbh->quote($hdr->{$item});
  };

  $dbh->do("UPDATE queue SET ".join(",",@tmp).
           " WHERE message_id=".$dbh->quote($message_id).
           " AND server=".$dbh->quote($server));
};

sub _mysql_sql_queue_add {
  my $hdr = shift;

  return unless (ref($hdr) eq 'HASH');

  my @fields = sort {$a cmp $b} keys(%{$hdr});
  my @vals = ();
  foreach (@fields) {
    push @vals, $dbh->quote($hdr->{$_});
  };

  $dbh->do("INSERT INTO queue (".join(',',@fields).") VALUES(".join(',',@vals).")");
};

sub _mysql_sql_queue_set_action {
  my $server = shift;
  my $message_id = shift;
  my $action = shift;

  $dbh->do("UPDATE queue SET action=".$dbh->quote($action).
           " WHERE server=".$dbh->quote($server).
           " AND message_id=".$dbh->quote($message_id));
};

sub _mysql_sql_queue_clear_action {
  my $server = shift;
  my $message_id = shift;
  
  $dbh->do("UPDATE queue SET action=NULL WHERE server=".$dbh->quote($server).
           " AND message_id=".$dbh->quote($message_id));
};


sub _mysql_sql_optimize {
  my $where = shift || "nothing";

  my $sql = "OPTIMIZE TABLE ".$where;
  my $sh = $dbh->prepare($sql);
  $sh->execute;
  $sh->finish;

  return 1;
};

sub _mysql_sql_delete {
  my $where = shift || "nothing";
  my $criteria = shift || {};

  my $sql = "DELETE FROM ".$where.
            ((scalar keys %{ $criteria } ) ? " "._build_WHERE($criteria) : "" );

  my $sh = $dbh->prepare($sql);
  my $num = $sh->execute;
  $sh->finish;

  return (($num eq '0E0') ? 0 : $num);
};

sub _mysql_sql_select {
  my $where = shift;
  my @what = @{ (shift || [ "*" ]) };
  my $criteria = shift || {};
  my $order_by = shift || "";
  my $order_direction = shift || "DESC";
  my $limit_min = shift;
  my $limit_max = shift;
  my $distinct = shift;

  my $sql = "SELECT ".
            (defined($distinct) ? "DISTINCT " : "").
            join(", ", @what).
            " FROM ".$where.
            ((scalar keys %{ $criteria } ) ? " "._build_WHERE($criteria) : "" ).
            ($order_by ? " ORDER BY ".$order_by." ".$order_direction : "").
            (defined($limit_min) ? " LIMIT ".$limit_min : "").
            (defined($limit_max) ? ",".$limit_max : "");

  return _fetch_multirow($where, $sql);
};

sub _mysql_write_message {
  my $server = shift || 'default';
  my $h = shift;
  my $rc = 0;

  # Special case: we only need to UPDATE the 'completed' field
  # in the messages table.
  if ( ($h->{table} eq 'messages') && (exists($h->{data}->{completed})) ) {
    my $rc = $dbh->do("UPDATE messages SET completed=".$dbh->quote($h->{data}->{completed}).
                      " WHERE message_id=".$dbh->quote($h->{data}->{message_id}).
                      " AND server=".$dbh->quote($server));
    if (defined($rc)) {
      return 1;
    }
    else {
      # error
      return 0;
    };
  }
  else {
    my @fields = sort {$a cmp $b} keys(%{$h->{data}});
    my @vals = ( $dbh->quote($server) );
    foreach (@fields) {
      push @vals, $dbh->quote(substr($h->{data}->{$_},0,255));
    };
    unshift @fields, 'server';

    my $sql = "INSERT INTO ".$h->{table}." (".join(',',@fields).") VALUES(".join(',',@vals).")";
    my $rc = $dbh->do($sql);

    if (defined($rc)) {
      return 1;
    }
    else {
      # error 1062 means "Duplicate key".
      return 2 if ($dbh->err == 1062);
      print STDERR "SQL Error (code ".$dbh->err.") on '$h->{table}' with query: $sql\n";
      return 0;
    };
  };
};


# --------------------------------------------------------------------------
# misc subroutines used across several DB types
sub _fetch_multirow {
  my $table = shift;
  my $sql = shift;
  my $limit = shift || 0;

  my $a = [];
  my $sh = $dbh->prepare($sql);
  $sh->execute;
  while (my $tmp = $sh->fetchrow_hashref) {
    push @{ $a }, $tmp;
    $limit--;
    last if ($limit == 0);
  };
  $sh->finish;

  return $a;
};

sub _build_WHERE {
  my $criteria = shift || {};

  my @set = ();
  foreach my $col (keys %{ $criteria }) {
    next unless(defined($criteria->{$col}));

    if ( ($col eq "timestamp") ||
         ($col eq "completed") ||
         ($col eq "frozen") ||
         ($col eq "size") ) {
      # integer column
      my ($min,$max) = split / /,$criteria->{$col};

      if (defined($min)) {
        # greater than X
        push @set, $col." > ".$min;
      }
      if (defined($max)) {
        # smaller than X
        push @set, $col." < ".$max;
      }
    }
    elsif (ref($criteria->{$col}) eq 'ARRAY') {
      # array ref, use exact string match with OR
      my $str = "( ";
      foreach my $entry (@{ $criteria->{$col} }) {
        $str .= " ".$col." = ".$dbh->quote($entry)." OR";
      };
      chop($str);chop($str);
      $str .= " )";

      push @set, $str;
    }
    else {
      # string column
      if (($criteria->{$col} =~ /\%/) || ($criteria->{$col} =~ /\_/)) {
        # use ILIKE for PGSQL
        if ($config->{sql}->{type} eq 'pgsql') {
          push @set, $col." ILIKE ".$dbh->quote($criteria->{$col});
        }
        else {
          push @set, $col." LIKE ".$dbh->quote($criteria->{$col});
        };
      }
      else {
        push @set, $col." = ".$dbh->quote($criteria->{$col});
      };
    };
  };

  return " WHERE ".join(" AND ", @set);
};


1;
