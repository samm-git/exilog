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

use FindBin;
use FindBin qw($RealBin);
use lib "$RealBin/";

use exilog_config;
use exilog_util;
use POSIX qw( setsid );

use Data::Dumper;

my $foreground = 0;
$foreground = 1 if (defined($ARGV[0]) && ($ARGV[0] eq '-f'));


unless ($foreground) {

  # open log file
  open(LOG,"> $config->{agent}->{log}")
  or die "($$) [exilog_agent] Can't open log file $config->{agent}->{log}.\n";

  print LOG scalar localtime()." ($$) [exilog_agent] Starting.\n";

  # fork master process and get rid of the controlling terminal
  my $rc = fork();
  if (defined($rc)) {
    # parent returns
    if ($rc) {
      print "($$) [exilog_agent] Detaching from terminal, output goes to $config->{agent}->{log}.\n";
      exit(0);
    };
  }
  else {
    print "($$) [exilog_agent] Can't fork!\n";
    exit(255);
  };

  setsid();

  # dup STDOUT/ERR
  open(STDIN, "< /dev/null");
  open(STDOUT, ">&LOG");
  open(STDERR, ">&LOG");
}

$0 = "[exilog_agent]" unless ( edt($config->{agent},'use_pretty_names') &&
                               ($config->{agent}->{use_pretty_names} eq 'no') );

if (exists($config->{agent}->{pidfile})) {
  open(PID, "> $config->{agent}->{pidfile}")
    or die "($$) [exilog_agent] Can't open pid-file $config->{agent}->{pidfile}.\n";
  print PID $$;
  close(PID);
}

my @children = ();

# spawn file tailers
foreach my $logfile (@{ $config->{agent}->{logs} }) {
  push @children, _tail($logfile);
};

# spawn queue sync
push @children, _queue_sync($config->{agent}->{queue});

# spawn queue action child
push @children, _queue_actions($config->{agent}->{exim});

# set up signal handlers
$SIG{'HUP'} = \&_terminate;
$SIG{'INT'} = \&_terminate;
$SIG{'TERM'} = \&_terminate;
sub _terminate {
  kill 15, @children;
  close(LOG);
  unlink($config->{agent}->{pidfile}) if (exists($config->{agent}->{pidfile}));
  exit(0);
};

# parent process goes to sleep
while (1) { sleep 10; };


sub _queue_actions {
  my $exim = shift;
  
  # fork
  my $rc = fork();
  if (defined($rc)) {
    # parent returns
    if ($rc) {
      print STDERR "($$) [exilog_agent] spawned queue actions process.\n";
      return $rc;
    };
  }
  else {
    print STDERR "($$) [exilog_agent:_queue_actions] Can't fork!\n";
    exit(255);
  };

  $0 = "[exilog_agent:_queue_actions] " unless ( edt($config->{agent},'use_pretty_names') &&
                                                 ($config->{agent}->{use_pretty_names} eq 'no') );

  # open own DB connection
  use exilog_sql;
  reconnect();

  # set up warning handler
  local $SIG{__WARN__} = sub { print STDERR "($$) [exilog_agent:_queue_actions] ".scalar localtime()." ".$_[0] };
  local $SIG{__DIE__}  = sub { print STDERR "($$) [exilog_agent:_queue_actions] ".scalar localtime()." ".$_[0] };

  for (;;) {
    # conditional reconnect
    reconnect(1);
    
    my $deliver = sql_select('queue',
                             [ 'message_id' ],
                             { 'server' => $config->{agent}->{server},
                             'action' => 'deliver' } );
                             
    my $cancel= sql_select('queue',
                           [ 'message_id' ],
                           { 'server' => $config->{agent}->{server},
                           'action' => 'cancel' } );                         
                           
    my $delete = sql_select('queue',
                            [ 'message_id' ],
                            { 'server' => $config->{agent}->{server},
                            'action' => 'delete' } );                       

    foreach (@{$deliver}) {
      system("$exim -Mt $_->{message_id}");
      system("$exim -Mc $_->{message_id} &");
      sql_queue_clear_action($config->{agent}->{server},$_->{message_id});
    }

    foreach (@{$cancel}) {
      system("$exim -Mg $_->{message_id} &");
      sql_queue_clear_action($config->{agent}->{server},$_->{message_id});
    }
    
    foreach (@{$delete}) {
      system("$exim -Mrm $_->{message_id} &");
      sql_queue_clear_action($config->{agent}->{server},$_->{message_id});
    }
    
    sleep 5;
  };
};


sub _queue_sync {
  my $queue = shift;

  # fork
  my $rc = fork();
  if (defined($rc)) {
    # parent returns
    if ($rc) {
      print STDERR "($$) [exilog_agent] spawned queue manager process.\n";
      return $rc;
    };
  }
  else {
    print STDERR "($$) [exilog_agent:_queue_manager] Can't fork!\n";
    exit(255);
  };

  $0 = "[exilog_agent:_queue_manager] ($queue) " unless ( edt($config->{agent},'use_pretty_names') &&
                                                          ($config->{agent}->{use_pretty_names} eq 'no') );
  # open own DB connection
  use exilog_sql;
  reconnect();

  # set up warning handler
  local $SIG{__WARN__} = sub { print STDERR "($$) [exilog_agent:_queue_manager] ($queue) ".scalar localtime()." ".$_[0] };
  local $SIG{__DIE__}  = sub { print STDERR "($$) [exilog_agent:_queue_manager] ($queue) ".scalar localtime()." ".$_[0] };

  my $queued = {};
  for (;;) {
    # conditional reconnect
    reconnect(1);

    # build initial file list hash from what we have in the database
    my $tmp = sql_select('queue',
                         [ 'spool_path' ],
                         { 'server' => $config->{agent}->{server} } );

    foreach (@{ $tmp }) {
      next if (exists($queued->{$_->{spool_path}}));
      $queued->{$_->{spool_path}} = 1;
    };

    my ($created,$updated,$removed) = _queue_read($queue,$queued);

    # remove messages from DB that are not on the queue any more
    foreach (@{ $removed }) {
      sql_queue_delete($_);
    };

    # Manage created and updated messages AFTER our delay, so
    # short-lived messages do not clutter up the queue table
    sleep ($config->{agent}->{queue_refresh_delay} || 30);

    # parse created messages and add them to the DB
    foreach (@{ $created }) {
      sql_queue_add(_parse_header($queue,$_));
    };

    # re-parse changes messages and update their db entry
    foreach (@{ $updated }) {
      sql_queue_update(_parse_header($queue,$_));
    };
  };
};

sub _parse_header {
  my $queue = shift;
  my $path = shift;
  my $hdr = {};

  return 0 unless open(THIS,"< $queue/$path");

  $hdr->{spool_path} = $path;
  $hdr->{server} = $config->{agent}->{server};
  $hdr->{message_id} = <THIS>;
  chomp($hdr->{message_id});
  $hdr->{message_id} =~ s/\-H$//;

  <THIS>;
  $hdr->{mailfrom} = <THIS>;
  chomp($hdr->{mailfrom});
  $hdr->{mailfrom} =~ s/^\<//;
  $hdr->{mailfrom} =~ s/\>$//;
  $hdr->{mailfrom} = '<>' unless ($hdr->{mailfrom});

  ($hdr->{timestamp},$hdr->{num_dsn}) = split / +/, <THIS>;
  chomp($hdr->{num_dsn});

  my $line = <THIS>;
  while ($line =~ /^\-/) {
    if ($line =~ /^\-acl/) {
      # swallow ACL variable (those are on extra lines)
      <THIS>;
    };
    if ($line =~ /^\-frozen (.+)$/) {
      $hdr->{frozen} = $1;
      chomp($hdr->{frozen});
    };
    $line = <THIS>;
  };

  chomp($line);
  my $delivered = {};
  while ($line !~ /^[0-9]+$/) {
    if ($line !~ /^XX/) {
      $delivered->{substr($line,3)} = 1;
    };
    $line = <THIS>;
    chomp($line);
  };

  $line = <THIS>;
  chomp($line);
  my @undelivered = ();
  while ($line) {
    my @tmp = split / +/, $line;
    push @undelivered, $tmp[0] unless (exists($delivered->{$tmp[0]}));
    $line = <THIS>;
    chomp($line);
  };

  $hdr->{recipients_delivered} = join(" ",keys %{ $delivered });
  $hdr->{recipients_pending} = join(" ",@undelivered);

  # finally read headers
  $hdr->{headers} = "";
  while(<THIS>) {
    chomp;
    if ($_ =~ /[0-9]{3}  Subject\: (.+)$/i) {
      $hdr->{subject} = $1;
    };
    if ($_ =~ /[0-9]{3}I Message\-ID\: (.+)$/i) {
      $hdr->{msgid} = $1;
      $hdr->{msgid} =~ s/^\<//;
      $hdr->{msgid} =~ s/\>$//;
    }
    if ($_ =~ /^[\t ]/) {
      $hdr->{headers} .= $_."\n";
    }
    else {
      $hdr->{headers} .= substr($_,5)."\n";
    };
  };

  return $hdr;
};

sub _queue_read {
  my $queue = shift;
  my $queued = shift || {};

  my $list = [];
  _find_headers($queue,"input",$list);
  _find_headers($queue,"Finput",$list);

  my $created = [];
  my $updated = [];
  my $seen = {};
  foreach my $entry (@{ $list }) {
    if (exists($queued->{$entry})) {
      $seen->{$entry} = 1;
      # was already there, stat it to see if it was updated
      my $mtime = _mtime($queue."/".$entry);
      if ($mtime > $queued->{$entry}) {
        $queued->{$entry} = $mtime;
        push @{ $updated }, $entry;
      };
    }
    else {
      # new entry, stat it and add it to the list
      $queued->{$entry} = _mtime($queue."/".$entry);
      $seen->{$entry} = 1;
      push @{ $created }, $entry;
    };
  };

  my $removed = [];
  foreach my $entry (keys %{ $queued } ) {
    next if (exists($seen->{$entry}));
    # stale DB entry, delete it
    delete $queued->{$entry};
    push @{ $removed }, $entry;
  };

  return ($created,$updated,$removed);
};

sub _mtime {
  my $path = shift;
  my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
   $atime,$mtime,$ctime,$blksize,$blocks)
    = stat($path);
  return $mtime || 0;
};

sub _find_headers {
  my $base = shift;
  my $subdir = shift;
  my $list = shift;

  return unless (opendir(THIS,$base."/".$subdir));
  my @entries = grep !/^\./, readdir THIS;
  closedir(THIS);

  foreach my $entry (@entries) {
    if (-d $base."/".$subdir."/".$entry) {
      _find_headers($base,$subdir."/".$entry,$list);
    }
    elsif ($entry =~ /\-H$/) {
      push @{ $list }, $subdir."/".$entry;
    }
  };
};


sub _tail {
  my $logfile = shift;

  # check if we can open the log file
  open(LOGFILE,"< $logfile") or do {
    print STDERR "($$) [exilog_agent:_tail] Can't open logfile '$logfile'.\n";
    exit(255);
  };
  close(LOGFILE);

  # fork
  my $rc = fork();
  if (defined($rc)) {
    # parent returns
    if ($rc) {
      print STDERR "($$) [exilog_agent] spawned tail process for '$logfile' ($rc).\n";
      return $rc;
    };
  }
  else {
    print STDERR "($$) [exilog_agent:_tail] Can't fork!\n";
    exit(255);
  };
  
  $0 = "[exilog_agent:_tail] ($logfile)" unless ( edt($config->{agent},'use_pretty_names') &&
                                                ($config->{agent}->{use_pretty_names} eq 'no') );

  # set up warning handler
  local $SIG{__WARN__} =
    sub {
      return if ($_[0] =~ /Duplicate/i);
      print STDERR "($$) [exilog_agent:_tail] ($logfile) ".scalar localtime()." ".$_[0];
    };
  local $SIG{__DIE__} =
    sub {
      return if ($_[0] =~ /Duplicate/i);
      print STDERR "($$) [exilog_agent:_tail] ($logfile) ".scalar localtime()." ".$_[0];
    };

  # open the file
  open(LOGFILE,"< $logfile");

  # import parser, open DB connection
  use exilog_parse;
  use exilog_sql;
  reconnect();

  my $curpos;
  my $fsize = (-s $logfile);
  for (;;) {
    for ($curpos = tell(LOGFILE);
         $_ = <LOGFILE>;
         $curpos = tell(LOGFILE)) {
      my $h = (parse_message_line($_) || parse_reject_line($_));
      if ($h) {
        while (!write_message($config->{agent}->{server}, $h)) {
          # Wait 30 seconds, then reconnect and try again.
          # If the connect works but writing the line does
          # not, assume the line is somehow FUBAR and skip
          # it. If the connect fails, enter 5-minute reconnect
          # loop.
          print STDERR "($$) [exilog_agent:_tail] write_message failed. Retrying in 30 seconds.\n";
          sleep(30);
          if (reconnect()) {
            write_message($config->{agent}->{server}, $h);
            last;
          }
          else {
            while(!reconnect()) {
              print STDERR "($$) [exilog_agent:_tail] Retrying connection to database.\n";
              sleep(300);
            };
          };
        };
      };
    }

    seek(LOGFILE, $curpos, 0);

    # check if file has been rotated
    if (-e $logfile) {
      if ((-s $logfile) < $fsize) {
        # file is smaller than one second ago
        print STDERR "($$) [exilog_agent:_tail] File has been rotated, re-opening.\n";
        close(LOGFILE);
        open(LOGFILE,"< $logfile");
      };
      $fsize = (-s $logfile);
    }

    # be nice to the CPU
    sleep(1);
  }
};

