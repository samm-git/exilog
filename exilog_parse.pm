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

package exilog_parse;
use strict;
use exilog_util;
use Digest::MD5 qw( md5_base64 );

use Data::Dumper;

BEGIN {
  use Exporter;
  use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

  $VERSION     = 0.1;
  @ISA         = qw(Exporter);
  @EXPORT      = qw(
                      &parse_message_line
                      &parse_reject_line
                      &date_to_stamp
                      &stamp_to_date
                   );

  %EXPORT_TAGS = ();
  @EXPORT_OK   = qw();
}

sub _parse_error {
  my $subj = shift || "";
  my $h = shift || {};

  $subj = _parse_delivery($subj,$h);

  m/()()/;
  if ($subj =~ / host ([^ ]+?) \[([0-9.]+?)\]\:/) {
    $h->{host_addr} = $2;
    $h->{host_dns} = $1;
  };
  $subj =~ s/^[ :]+//;
  $subj =~ s/ +$//;
  $h->{errmsg} = $subj if ($subj);

  return $subj;
};


sub _parse_deferral {
  my $subj = shift || "";
  my $h = shift || {};

  $subj = _parse_delivery($subj,$h);

  if ($subj =~ / host ([^ ]+?) \[([0-9.]+?)\]\:/) {
    $h->{host_addr} = $2;
    $h->{host_dns} = $1;
  };
  $subj =~ s/^[ :]+//;
  $subj =~ s/ +$//;
  $h->{errmsg} = $subj if ($subj);

  return $subj;
};


sub _parse_delivery {
  my $subj = shift || "";
  my $h = shift || {};


  # When +sender_on_delivery is set, cut away the F=<> part
  $subj =~ s/[PF]\=[^ ]+ //;

  m/()/;

  $subj =~ s/^.+?[\=\-\*][\>\=\*] (.+?)((\: )|( R\=)|( \<)|( \())/$2/;
  $h->{rcpt_final} = $1 if ($1);
  $subj =~ s/^\: //;
  $subj =~ s/^ +//;

  m/()/;
  $subj =~ s/^\((.+?)\) //;
  $h->{rcpt_intermediate} = $1 if ($1);

  m/()/;
  $subj =~ s/^\<(.+?)\> //;
  if ($1) {
    $h->{rcpt} = $1;
  }
  else {
    $h->{rcpt} = $h->{rcpt_final};
  };

  m/()/;
  $subj =~ s/R\=([^ \:]+)//;
  $h->{router} = $1 if ($1);

  m/()/;
  $subj =~ s/ST\=([^ \:]+)//;
  $h->{shadow_transport} = $1 if ($1);

  m/()/;
  $subj =~ s/T\=([^ \:]+)//;
  $h->{transport} = $1 if ($1);

  m/()/;
  $subj =~ s/X\=([^ ]+)//;
  $h->{tls_cipher} = $1 if ($1);

  m/()()/;
  $subj =~ s/H\=([^ ]+) \[(.+?)\]//;
  $h->{host_dns} = $1 if ($1);
  $h->{host_addr} = $2 if ($2);

  return $subj;
};




sub _parse_arrival {
  my $subj = shift || "";
  my $h = shift || {};

  m/()/;
  $subj =~ s/^.+?\<\= (.+?) //;
  $h->{mailfrom} = $1 if ($1);

  m/()()/;
  $subj =~ s/H\=(.+?) ([A-Za-z]\=)/$2/;
  if ($1) {
    my $hstr = $1;
    m/()/;
    $hstr =~ s/\[([0-9.]+)\]$//;
    $h->{host_addr} = $1 if ($1);

    $hstr =~ s/^ +//;
    $hstr =~ s/ +$//;

    m/()/;
    $hstr =~ s/\((.+?)\)$//;
    $h->{host_helo} = $1 if ($1);

    $hstr =~ s/^ +//;
    $hstr =~ s/ +$//;

    # if we have something left over now, it must
    # be a confirmed rdns host name
    $h->{host_rdns} = $hstr if ($hstr);
  }

  m/()/;
  $subj =~ s/P\=([^ ]+)//;
  $h->{proto} = $1 if ($1);
  if ($1 =~ /^local/) {
    # U= contains local user account
    m/()/;
    $subj =~ s/U\=([^ ]+)//;
    $h->{user} = $1 if ($1);
  }
  elsif ( ($1 eq 'asmtp') || ($1 eq 'esmtpa') || ($1 eq 'esmtpsa') ) {
    # fill in both auth user and ident
    m/()/;
    $subj =~ s/A\=([^ ]+)//;
    $h->{user} = $1 if ($1);

    m/()/;
    $subj =~ s/U\=([^ ]+)//;
    $h->{host_ident} = $1 if ($1);
  }
  else {
    # U= contains remote ident
    m/()/;
    $subj =~ s/U\=([^ ]+)//;
    $h->{host_ident} = $1 if ($1);
  };

  m/()/;
  $subj =~ s/S\=([^ ]+)//;
  $h->{size} = $1 if ($1);

  m/()/;
  $subj =~ s/id\=([^ ]+)//;
  $h->{msgid} = $1 if ($1);

  m/()/;
  $subj =~ s/X\=([^ ]+)//;
  $h->{tls_cipher} = $1 if ($1);

  m/()/;
  $subj =~ s/R\=([^ ]+)//;
  $h->{bounce_parent} = $1 if ($1);

  return $subj;
};

sub _parse_reject {
  my $subj = shift;
  my $h = shift;

  m/()()/;
  $subj =~ s/H\=(.+?) \[(.+?)\] //;
  if ($1 && $2) {
    $h->{host_addr} = $2;
    my $hstr = $1;

    $hstr =~ s/^ +//;
    $hstr =~ s/ +$//;

    m/()/;
    $hstr =~ s/\((.+?)\)$//;
    $h->{host_helo} = $1 if ($1);

    $hstr =~ s/^ +//;
    $hstr =~ s/ +$//;

    # if we have something left over now, it must
    # be a confirmed rdns host name
    $h->{host_rdns} = $hstr if ($hstr);
  };

  m/()/;
  $subj =~ s/U\=(.+?) //;
  $h->{host_ident} = $1 if ($1);

  m/()()/;
  $subj =~ s/F\=(\<.*?\>) //;
  $h->{mailfrom} = $1 if ($1);
  if (exists($h->{mailfrom})) {
    unless ($h->{mailfrom} eq '<>') {
      $h->{mailfrom} =~ s/[<>]//g;
    }
  };

  m/()()/;
  $subj =~ m/\<(.+?)\>/;
  if ($1) {
    $h->{rcpt} = $1;
  };

  return $subj;
};


# Parse a reject line
sub parse_reject_line {
  my $subj = shift || "";
  chomp($subj);

  my $h = { 'table' => 'rejects' };

  # There are 2 types of rejects: one without a message ID (pre-DATA)
  # and one with message ID (post-DATA). Try the latter first.

  m/()()()()/;
  $subj =~ m/(\d{4}-\d\d-\d\d) (\d\d:\d\d:\d\d( [-+]\d{4})?) ([A-Za-z0-9]{6}-[A-Za-z0-9]{6}-[A-Za-z0-9]{2}) (H=.*)$/;
  my ($date,$tod,$msgid,$line) = ($1,$2,$4,$5);
  if ($date && $tod && $msgid && $line) {
    # line with message id
    $h->{data}->{message_id} = $msgid;
  }
  else {
    # try format without message id
    m/()()()()/;
    $subj =~ m/(\d{4}-\d\d-\d\d) (\d\d:\d\d:\d\d( [-+]\d{4})?) (H=.*)$/;
    ($date,$tod,$line) = ($1,$2,$4);
    unless ($date && $tod && $line) {
      # unparsable
      return 0;
    };
    # Add custom "Message ID" hash
    $h->{data}->{message_id} = substr(md5_base64($date,$tod,$line),0,16);
  };

  $h->{data}->{timestamp} = date_to_stamp($date,$tod);
  $h->{data}->{errmsg} = substr(_parse_reject($line,$h->{data}),0,255);

  return $h;
};


# Parse line that relates to an actual message.
sub parse_message_line {
  my $subj = shift || "";
  chomp($subj);

  # Exception: do not use "retry time not reached [for any host]".
  # It's just too spammy and gets logged by default.
  return 0 if ($subj =~ /retry time not reached$/);
  return 0 if ($subj =~ /retry time not reached for any host$/);

  # Grab date, time and message id
  $subj =~ m/(\d{4}-\d\d-\d\d) (\d\d:\d\d:\d\d( [-+]\d{4})?) ([A-Za-z0-9]{6}-[A-Za-z0-9]{6}-[A-Za-z0-9]{2}) (([^ ]+).*)$/;
  my ($date,$tod,$msgid,$line,$type) = ($1,$2,$4,$5,$6);
  $line =~ s/^ +// if (defined($line));
  unless ($date && $tod && $msgid && $line && $type) {
    # non-message based line
    return 0;
  };

  # removed fttb, too much overhead
  #my $h = { 'data' => { 'line' => $line, 'message_id' => $msgid } };
  my $h = { 'data' => { 'message_id' => $msgid } };


  if ($type eq '<=') {
    $h->{table} = 'messages';
    $h->{data}->{timestamp} = date_to_stamp($date,$tod);
    _parse_arrival($subj,$h->{data});
  }
  elsif (($type eq '=>') || ($type eq '->') || ($type eq '*>')) {
    $h->{table} = 'deliveries';
    $h->{data}->{timestamp} = date_to_stamp($date,$tod);
    _parse_delivery($subj,$h->{data});
  }
  elsif ($type eq '**') {
    $h->{table} = 'errors';
    $h->{data}->{timestamp} = date_to_stamp($date,$tod);
    _parse_error($subj,$h->{data});
  }
  elsif ($type eq '==') {
    $h->{table} = 'deferrals';
    $h->{data}->{timestamp} = date_to_stamp($date,$tod);
    _parse_deferral($subj,$h->{data});
  }
  elsif ($type eq 'Completed') {
    $h->{table} = 'messages';
    $h->{data}->{completed} = date_to_stamp($date,$tod);
  }
  else {
    if ($line =~ /^H\=.*rejected/) {
      # looks like a reject line after DATA, pass on
      return 0;
    };

    $h->{table} = 'unknown';
    $h->{data}->{timestamp} = date_to_stamp($date,$tod);
    $h->{data}->{line} = substr($line,0,255);
  };

  return $h;
};

1;
