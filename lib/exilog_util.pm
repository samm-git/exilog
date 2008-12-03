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

package exilog_util;
use Time::Local;
use POSIX qw( strftime );
use strict;
use exilog_config;

BEGIN {
  use Exporter;
  use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

  # set the version for version checking
  $VERSION     = 0.1;
  @ISA         = qw(Exporter);
  @EXPORT      = qw(
                      &edt
                      &edv
                      &ina
                      &date_to_stamp
                      &stamp_to_date
                      &human_size
                   );

  %EXPORT_TAGS = ();

  # your exported package globals go here,
  # as well as any optionally exported functions
  @EXPORT_OK   = qw();
}


# checks if scalar is in array
sub ina {
  my $aref = shift || [];
  my $str = shift || "";

  unless (ref($aref) eq 'ARRAY') {
    $aref = [ $aref ];
  };

  foreach (@{ $aref }) {
    return 1 if ($_ eq $str);
  };
  return 0;
};


# exists, defined and true (in perl sense)
sub edt {
  my $h = shift;
  my $hkey = shift;
  return 0 unless (ref($h) eq 'HASH');
  return 1 if ( exists($h->{$hkey}) &&
                defined($h->{$hkey}) &&
                $h->{$hkey} );
  return 0;
};


# exists, defined and valid (that is, not empty)
sub edv {
  my $h = shift;
  my $hkey = shift;
  return 0 unless (ref($h) eq 'HASH');
  return 1 if ( exists($h->{$hkey}) &&
                defined($h->{$hkey}) &&
                $h->{$hkey} ne '' );
  return 0;
};


sub date_to_stamp {
  my $date = shift || "";
  my $tod = shift || "00:00:00";
  my ($year,$month,$mday) = split /\-/, $date;
  my ($hour,$minute,$second,$junk) = split /[: ]/, $tod;
  $year-=1900;
  $month--;

	# This is for parsing timestamps that include GMT offsets
  if (edv($junk)) {
    my $hoff = ($junk =~ /[-+](\d\d)\d\d/);
    my $moff = ($junk =~ /[-+]\d\d(\d\d)/);
    if ($junk =~ /\+/) {
      $hour = $hour - $hoff;
      $minute = $minute - $moff;
    }
    else {
      $hour = $hour + $hoff;
      $minute = $minute + $moff;
    }   
  };

  if ($config->{web}->{timestamps} eq 'local') {
    return timelocal($second,$minute,$hour,$mday,$month,$year);
  }
  else {
    return timegm($second,$minute,$hour,$mday,$month,$year);
  };
};


sub stamp_to_date {
  my $stamp = shift;
  my $no_seconds = shift || 0;
  # convert to date/time string
  if ($config->{web}->{timestamps} eq 'local') {
    return ($no_seconds ? strftime("%Y-%m-%d %H:%M",localtime($stamp)) : strftime("%Y-%m-%d %H:%M:%S",localtime($stamp)));
  }
  else {
    return ($no_seconds ? strftime("%Y-%m-%d %H:%M",gmtime($stamp)) : strftime("%Y-%m-%d %H:%M:%S",gmtime($stamp)));
  };
};

sub human_size {
  my $size = shift;
  my @units = ( '', 'k', 'M', 'G' );
  while ( ($size > 9999) && ((scalar @units) > 1) ) {
    shift @units;
    $size = int($size/1024);
  };
  return $size.$units[0];
};


1;
