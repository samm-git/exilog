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

package exilog_cgi_messages;
use strict;
use exilog_config;
use exilog_cgi_html;
use exilog_cgi_param;
use exilog_sql;
use exilog_util;
use Net::Netmask;
use Time::Local;

use Data::Dumper;

BEGIN {
  use Exporter;
  use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

  # set the version for version checking
  $VERSION     = 0.1;
  @ISA         = qw(Exporter);
  @EXPORT      = qw(
                      &messages
                   );

  %EXPORT_TAGS = ();

  # your exported package globals go here,
  # as well as any optionally exported functions
  @EXPORT_OK   = qw();
}

sub _select_all {
  # All tables
  my @tables = ( 'deliveries','errors','unknown','deferrals','messages','rejects','queue' );
  # Only server and timestamp as criteria.
  # Since these are present on every table
  # the queries are all the same ...
  my $criteria = { 'timestamp' => (edt($param,'tr') ? _make_tr() : undef),
                   'server' => (edt($param,'sr') ? $param->{'sr'} : undef ) };

  my @results = ();
  foreach my $table (@tables) {
    next unless (ina($param->{'qw'},$table));
    push @results, @{ sql_select( $table, [ 'server','message_id','timestamp' ], $criteria ) };
  };
  return \@results;
};

sub _select_ident {
  if (!edt($param,'qs')) {
    return [];
  }
  my $criteria = { 'timestamp' => (edt($param,'tr') ? _make_tr() : undef),
                   'server' => (edt($param,'sr') ? $param->{'sr'} : undef ),
                   'host_ident' => dos2sql($param->{'qs'}) };
  # Only messages table
  return sql_select( 'messages', [ 'server','message_id','timestamp' ], $criteria );
};

sub _select_msgid {
  if (!edt($param,'qs')) {
    return [];
  }
  # Only messages table
  return sql_select( 'messages', [ 'server','message_id','timestamp' ], { 'msgid' => dos2sql($param->{'qs'}) } );
};

sub _select_message_id {
  if (!edt($param,'qs')) {
    return [];
  }

  my @results = ();
  my @tables = ( 'deliveries','errors','unknown','deferrals','messages','rejects','queue' );
  my $criteria = { 'message_id' =>  dos2sql($param->{'qs'}) };
  foreach my $table (@tables) {
    push @results, @{ sql_select( $table, [ 'server','message_id','timestamp' ], $criteria ) };
  };

  # check bounce parent field too
  push @results, @{ sql_select( 'messages', [ 'server','message_id','timestamp' ],
                                 { 'bounce_parent' =>  dos2sql($param->{'qs'}) } ) };

  return \@results;
};

sub _select_addr {
  my $p = shift || 'all';

  if (!edt($param,'qs')) {
    return [];
  }

  my @queries;
  push @queries, { 'table' => 'messages',
                 'criteria' => { 'mailfrom' => dos2sql($param->{'qs'}) } },
                 { 'table' => 'rejects',
                 'criteria' => { 'mailfrom' => dos2sql($param->{'qs'}) } }
    if (($p eq 'sender') || ($p eq 'all'));

  push @queries, { 'table' => 'rejects',
                   'criteria' => { 'rcpt' => dos2sql($param->{'qs'}) } },
                 { 'table' => 'deliveries',
                   'criteria' => { 'rcpt' => dos2sql($param->{'qs'}) } },
                 { 'table' => 'deliveries',
                   'criteria' => { 'rcpt_final' => dos2sql($param->{'qs'}) } },
                 { 'table' => 'deferrals',
                   'criteria' => { 'rcpt' => dos2sql($param->{'qs'}) } },
                 { 'table' => 'deferrals',
                   'criteria' => { 'rcpt_final' => dos2sql($param->{'qs'}) } },
                 { 'table' => 'errors',
                   'criteria' => { 'rcpt' => dos2sql($param->{'qs'}) } },
                 { 'table' => 'errors',
                   'criteria' => { 'rcpt_final' => dos2sql($param->{'qs'}) } }
    if (($p eq 'rcpt') || ($p eq 'all'));


  my @results = ();
  foreach my $query (@queries) {
    next unless (ina($param->{'qw'},$query->{table}));
    # add standard criteria
    $query->{criteria}->{'timestamp'} = (edt($param,'tr') ? _make_tr() : undef);
    $query->{criteria}->{'server'} = (edt($param,'sr') ? $param->{'sr'} : undef );
    push @results, @{ sql_select( $query->{table}, [ 'server','message_id','timestamp' ], $query->{criteria} ) };
  };

  return \@results;
};


sub _select_host {
  my $p = shift || 'all';

  if (!edt($param,'qs')) {
    return [];
  }

  my @queries;
  if ($param->{'qs'} =~ /^[0-9A-Fa-f.:]+$/) {
    # IPv4 or IPv6 address
    push @queries, { 'table' => 'messages',
                     'criteria' => { 'host_addr' => dos2sql($param->{'qs'}) } },
                   { 'table' => 'rejects',
                     'criteria' => { 'host_addr' => dos2sql($param->{'qs'}) } }
      if (($p eq 'incoming') || ($p eq 'all'));

    push @queries, { 'table' => 'deliveries',
                     'criteria' => { 'host_addr' => dos2sql($param->{'qs'}) } },
                   { 'table' => 'deferrals',
                     'criteria' => { 'host_addr' => dos2sql($param->{'qs'}) } },
                   { 'table' => 'errors',
                     'criteria' => { 'host_addr' => dos2sql($param->{'qs'}) } },
                   { 'table' => 'unknown',
                     'criteria' => { 'line' => '%'.dos2sql($param->{'qs'}).'%' } }
      if (($p eq 'outgoing') || ($p eq 'all'));

  }
  elsif ($param->{'qs'} =~ /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,2}$/) {
    # check if we can make a valid Net::Netmask object out of this
    my $block = new2 Net::Netmask($param->{'qs'});

    if (!defined($block)) {
      return "Invalid CIDR specification";
    };

    # Network specification
    push @queries, { 'table' => 'messages' },
                   { 'table' => 'rejects' }
      if (($p eq 'incoming') || ($p eq 'all'));

    push @queries, { 'table' => 'deliveries' },
                   { 'table' => 'deferrals' },
                   { 'table' => 'errors' }
      if (($p eq 'outgoing') || ($p eq 'all'));

    my @results = ();
    foreach my $query (@queries) {
      next unless (ina($param->{'qw'},$query->{table}));
      # add standard criteria
      $query->{criteria}->{'timestamp'} = (edt($param,'tr') ? _make_tr() : undef);
      $query->{criteria}->{'server'} = (edt($param,'sr') ? $param->{'sr'} : undef );
      push @results, @{ sql_select( $query->{table}, [ 'server','message_id','timestamp','host_addr' ], $query->{criteria} ) };
    };

    # now weed out those that don't match the CIDR specification
    my @valid = ();
    foreach my $result (@results) {
      if ($block->match($result->{host_addr})) {
        delete $result->{host_addr};
        push @valid, $result;
      };
    };

    return \@valid;
  }
  else {
    # assume hostname
    my $prefix_wc = "";
    my $suffix_wc = "";
    $prefix_wc = '%' if ($param->{'qs'} !~ /^\%/);
    $suffix_wc = '%' if ($param->{'qs'} !~ /\%$/);

    push @queries, { 'table' => 'messages',
                     'criteria' => { 'host_helo' => dos2sql($param->{'qs'}) } },
                   { 'table' => 'messages',
                     'criteria' => { 'host_rdns' => dos2sql($param->{'qs'}) } },
                   { 'table' => 'rejects',
                     'criteria' => { 'host_helo' => dos2sql($param->{'qs'}) } },
                   { 'table' => 'rejects',
                     'criteria' => { 'host_rdns' => dos2sql($param->{'qs'}) } }
      if (($p eq 'incoming') || ($p eq 'all'));

    push @queries, { 'table' => 'deliveries',
                     'criteria' => { 'host_dns' => dos2sql($param->{'qs'}) } },
                   { 'table' => 'deferrals',
                     'criteria' => { 'host_dns' => dos2sql($param->{'qs'}) } },
                   { 'table' => 'errors',
                     'criteria' => { 'host_dns' => dos2sql($param->{'qs'}) } },
                   { 'table' => 'unknown',
                     # the blank makes sure that we do not match domains in addresses
                     'criteria' => { 'line' => $prefix_wc.' '.dos2sql($param->{'qs'}).$suffix_wc } }
      if (($p eq 'outgoing') || ($p eq 'all'));
  };

  my @results = ();
  foreach my $query (@queries) {
    next unless (ina($param->{'qw'},$query->{table}));
    # add standard criteria
    $query->{criteria}->{'timestamp'} = (edt($param,'tr') ? _make_tr() : undef);
    $query->{criteria}->{'server'} = (edt($param,'sr') ? $param->{'sr'} : undef );
    push @results, @{ sql_select( $query->{table}, [ 'server','message_id','timestamp' ], $query->{criteria} ) };
  };

  return \@results;
};



sub messages {

  _print_Messages_selector();
  
  # Check CGI input for event selection.
  # We need at least a query type ('qt'),
  # otherwise we only display the selector.
  my $selected = [];
  if (edt($param,'qt')) {
    # Call event selection function for this query type.
    _print_progress_bar("Collecting message IDs ...");
    # cut off parameter part (separated with dash)
    my ($function,$parameter) = split /\-/, $param->{'qt'};
    no strict "refs";
    $selected = &{ "_select_".$function }($parameter);
    if (ref($selected) ne 'ARRAY') {
      # error
      _update_progress_bar($selected);
      return;
    };
  }
  else {
    # no query type ('qt'), just return
    return;
  };

  # Now we have a set of selected messages in an array:
  #
  # [0]-->{server}
  #    |->{timestamp}
  #    \->{message_id}
  # [1]-->{server}
  #    |->{timestamp}
  #    \->{message_id}
  # ...

  # Perform dupe check. We may have a lot of duplicate IDs
  # in the list. It is faster to weed them out this way ...
  _update_progress_bar("Performing dupe check ...");
  my $dupe = {};
  my @duped = ();
  foreach my $message (@{ $selected }) {
    if (exists($dupe->{$message->{server}}->{$message->{message_id}})) {
      # Make sure we use the largest timestamp we can find
      if ($dupe->{$message->{server}}->{$message->{message_id}}->{timestamp} < $message->{timestamp}) {
        $dupe->{$message->{server}}->{$message->{message_id}}->{timestamp} = $message->{timestamp};
      };
      next;
    };
    $dupe->{$message->{server}}->{$message->{message_id}} = $message;
    push @duped, $message;
  };
  undef $dupe;
  undef $selected;

  if ((scalar @duped) == 0) {
    _update_progress_bar("No matching events found.");
   return;
  };

  if (((scalar @duped) > 500) && ($param->{'sm'} !~ /^Confirm/)) {
    _update_progress_bar("Warning: ".(scalar @duped)." messages/events found. Narrow down your selection or submit the query again.");
    print '
      <script language="Javascript">
        document.forms[0].sm.value = "Confirm Query";
      </script>
    ';
    return;
  };

  # Initialize stats counters
  my $stats = {
    'num_messages' => { 'desc' => "Messages",
                        'order' => 1,
                        'num' => 0 },
    'num_rejects' => { 'desc' => "Rejects",
                       'order' => 5,
                       'num' => 0 },
    'num_deliveries' => { 'desc' => "Deliveries",
                          'order' => 2,
                          'num' => 0 },
    'num_errors' => { 'desc' => "Errors",
                      'order' => 3,
                      'num' => 0 },
    'total_turnover' => { 'desc' => "Total Turnover",
                          'order' => 4,
                          'size' => 0 }
    };

  # Now we need to build the complete message set.
  # This requires a large number of SELECTs.
  _update_progress_bar("Sorting ...");
  my $c = 0;
  foreach my $message (sort { $b->{timestamp} <=> $a->{timestamp} } @duped) {

    # Update the progress bar every 50 entries
    if (($c % 50) == 0) {
      _update_progress_bar("Grabbing event data (".$c." of ".scalar @duped." events done) ...");
    };
    $c++;

    # Remove timestamp, we'll re-add it later for marking
    # the "sort" timestamp.
    my $sort_timestamp = $message->{timestamp};
    delete $message->{timestamp};

    # Check the message ID.
    if ($message->{message_id} !~ /^.{6}\-.{6}\-.{2}$/) {
      # This is a pre-DATA reject/warning.
      # Render it as a reject.
      my $complete = @{ sql_select( 'rejects', ['*'], $message ) }[0];
      $complete->{sort_timestamp} = $sort_timestamp;
      print render_reject($complete);
      $stats->{num_rejects}->{num}++;
    }
    else {
      # Try to grab complete arrival ('messages' table)
      my $complete = @{ sql_select( 'messages', ['*'], $message ) }[0];

      # If there is an arrival, this set has a "real"
      # message ID. Scan other tables for events.
      if (defined($complete)) {
        $complete->{rejects} = sql_select( 'rejects', ['*'], $message );
        $complete->{deliveries} = sql_select( 'deliveries', ['*'], $message );
        $complete->{errors} = sql_select( 'errors', ['*'], $message );
        $complete->{deferrals} = sql_select( 'deferrals', ['*'], $message );
        $complete->{unknown} = sql_select( 'unknown', ['*'], $message );
        $complete->{queue} = sql_select( 'queue', ['*'],  $message );
        $complete->{sort_timestamp} = $sort_timestamp;
        print render_message($complete);
        $stats->{num_messages}->{num}++;
        $stats->{total_turnover}->{size} += $complete->{size};
        $stats->{num_rejects}->{num} += (scalar @{ $complete->{rejects} });
        $stats->{num_deliveries}->{num} += (scalar @{ $complete->{deliveries} });
        $stats->{total_turnover}->{size} += ($complete->{size} * (scalar @{ $complete->{deliveries} }));
        $stats->{num_errors}->{num} += (scalar @{ $complete->{errors} });
      }
      # If there is no associated arrival, this is either
      # a POST-DATA reject (in rejects table) or another
      # post-DATA warning (in unknown table). Since both
      # can occur, we render this as a message.
      else {
        $complete->{server} = $message->{server};
        $complete->{message_id} = $message->{message_id};
        $complete->{rejects} = sql_select( 'rejects', ['*'], $message );
        $complete->{unknown} = sql_select( 'unknown', ['*'], $message );
        $complete->{sort_timestamp} = $sort_timestamp;
        print render_message($complete);
        $stats->{num_rejects}->{num}++;
      };
    };
  };

  _update_progress_bar(_render_stats($stats));
};


sub _make_tr {

  my $str = $q->param('tr') || 0;
  
  unless ($str eq 'custom') {
    my $unit = chop $str;
    my $now = time();
    my $units = { '0' => 0,
    	            'm' => 60,
                  'h' => 3600,
                  'd' => 86400 };
    my $then = $now + $units->{$unit}*$str;
    unless ($now == $then) { # The "unlimited" case
    	$param->{'tds'} = stamp_to_date($then,1);
    	$param->{'tde'} = stamp_to_date($now,1);
  	}
    return $then;
  }
  else {
    $param->{'tds'} =~ s/ +$//;
    $param->{'tds'} =~ s/^ +//;
    $param->{'tde'} =~ s/ +$//;
    $param->{'tde'} =~ s/^ +//;

    my ($sd,$st) = split / +/, $param->{'tds'};
    my ($ed,$et) = split / +/, $param->{'tde'};

		if (!$st && $sd =~ /\:/) {
			$st = $sd;
			$sd = '';
		}
		if (!$et && $ed =~ /\:/) {
			$et = $ed;
			$ed = '';
		}

    $ed = $sd unless($ed);

		my $fsd = _parse_date($sd, $st || '00:00:00');
		my $fed = _parse_date($ed, $et || '23:59:59');

		$param->{'tds'} = stamp_to_date($fsd);
		$param->{'tde'} = stamp_to_date($fed);

    return $fsd." ".$fed;
  }
}


sub _parse_date {
  my $d = shift;
  my $t = shift;

	my ($dn,$tn) = split / /, stamp_to_date(time,1);
	my ($year,$month,$day) = split /\-/, $dn;
	my ($hour,$minute,$second) = split /\:/, $tn;
	
  if ($d =~ /^([0-9]{4})\-([0-9]{2})\-([0-9]{2})$/) {
    $year = $1;
    $month = $2;
    $day = $3;
  }
  elsif ($d =~ /^([0-9]{2})\-([0-9]{2})$/) {
    $month = $1;
    $day = $2;
  }
  
  if ($t =~ /^([0-9]{2})\:([0-9]{2})\:([0-9]{2})$/) {
    $hour = $1;
    $minute = $2;
    $second = $3;
  }
  elsif ($t =~ /^([0-9]{2})\:([0-9]{2})$/) {
    $hour = $1;
    $minute = $2;
  } 

  return date_to_stamp($year.'-'.$month.'-'.$day, $hour.':'.$minute.':'.$second);
}

sub _render_stats {
  my $stats = shift || {};

  my @items = ();
  foreach (sort {$stats->{$a}->{order} <=> $stats->{$b}->{order}} keys %{ $stats }) {
    if (exists($stats->{$_}->{num}) && $stats->{$_}->{num}) {
      push @items, $stats->{$_}->{desc}.": ".$stats->{$_}->{num};
    }
    elsif (exists($stats->{$_}->{size}) && $stats->{$_}->{size}) {
      push @items, $stats->{$_}->{desc}.": ".human_size($stats->{$_}->{size});
    };
  };

  return join("&nbsp;&nbsp;<b>|</b>&nbsp;&nbsp;",@items);
};


sub _print_progress_bar {
  my $str = shift || "";
  print render_header(
    $q->div({-name=>"progress",-id=>"progress", -align=>"center"},
      $str
    )
  );
  print "\n<!-- Block filler follows - ".("xxxx" x 1024)." -->\n";
};


sub _update_progress_bar {
  my $str = shift || "";
  print '
    <script language="JavaScript">
      document.getElementById("progress").innerHTML = "'.$str.'";
    </script>
  ';
  print "\n<!-- Block filler follows - ".("xxxx" x 1024)." -->\n";
};


sub _print_Messages_selector {
	
	_make_tr();

  # Calendar popup DIVs
  print "\n".
  '
  <script language="JavaScript">
    var cal1x = new CalendarPopup("caldiv1x");
    var cal2x = new CalendarPopup("caldiv2x");
  </script>
  '
  ."\n";

  print
  $q->div({-class=>"top_spacer"},
    $q->div({-align=>"left",-style=>"padding: 10px; border: 1px solid black; background: #eeeeee;"},

      $q->table({-cellspacing=>0,-cellpadding=>4,-border=>0},
        $q->Tr(
          $q->td({-align=>"left",-style=>"width: 16px;"},
            $q->img({-src=>$config->{web}->{webroot}."icons/event_type.png"})
          ),
          $q->td({-align=>"left",-style=>"width: 100px;"},
            "Search Type"
          ),
          $q->td({-align=>"left"},
            $q->popup_menu({ -name=>"qt",
                             -id=>"qt",
                             -style=>"width: 400px;",
                             -values=>[ 'all',
                                        'addr-all',
                                        'addr-sender',
                                        'addr-rcpt',
                                        'host-all',
                                        'host-incoming',
                                        'host-outgoing',
                                        'msgid',
                                        'ident',
                                        'message_id' ],
                             -labels=>{ 'all' => "Show everything",
                                        'addr-all' => "Address (All)",
                                        'addr-sender' => "Address (Sender)",
                                        'addr-rcpt' => "Address (Recipient)",
                                        'host-all' => "Host (all)",
                                        'host-incoming' => "Host (incoming)",
                                        'host-outgoing' => "Host (outgoing)",
                                        'msgid' => "Message-ID (Header)",
                                        'ident' => "Ident String (incoming messages)",
                                        'message_id' => "Message-ID (Exim)"
                                      },
                             -default=>(exists($param->{'qt'}) ? ($param->{'qt'} || 'all') : 'all'),
                             -onChange=>"javascript:switch_controls(document.getElementById('qt').options[document.getElementById('qt').selectedIndex].value);",
                             -override=>1})
          )
        )
      )
      .
      $q->span({-id=>"term"},'<!-- Dynamic content target DIV -->').
      $q->div({-id=>"term_hidden",-style=>"visibility: hidden; position: absolute;"},
        $q->table({-cellspacing=>0,-cellpadding=>4,-border=>0},
          $q->Tr(
            $q->td({-align=>"left",-style=>"width: 16px;"},
              $q->img({-src=>$config->{web}->{webroot}."icons/find.png"})
            ),
            $q->td({-align=>"left",-style=>"width: 100px;"},
              "Search Term"
            ),
            $q->td({-align=>"left"},
              $q->textfield( { -name=>"qs",
                               -style=>"width: 400px;",
                               -value=>(exists($param->{'qs'}) ? ($param->{'qs'} || '') : ''),
                               -override=>1 } )
            )
          )
        )
      )
      .
      $q->span({-id=>"events"},'<!-- Dynamic content target DIV -->').
      $q->div({-id=>"events_hidden",-style=>"visibility: hidden; position: absolute;"},
       $q->table({-cellspacing=>0,-cellpadding=>4,-border=>0},
         $q->Tr(
           $q->td({-align=>"left",-valign=>"top",-style=>"width: 16px;"},
             $q->img({-src=>$config->{web}->{webroot}."icons/address.png"})
           ),
           $q->td({-align=>"left",-valign=>"top",-style=>"width: 100px;"},
             "Event types"
           ),
           $q->td({-align=>"left",-style=>"padding:2px 4px 4px 4px;"},
             eval {
                     my @where = ( 'messages',
                                   'errors',
                                   'deliveries',
                                   'deferrals',
                                   'rejects',
                                   'queue'
                                   );

                     my $labels = { 'messages' => 'Arrivals',
                                    'errors' => 'Errors',
                                    'deliveries' => 'Deliveries',
                                    'deferrals' => 'Deferrals',
                                    'rejects' => 'Rejects',
                                    'queue' => 'Queued' };

                     my $html = "";
                     my $num = 0;
                     foreach my $w (@where) {
                      if (($num % 3) == 0) {
                       $html .= '<tr>';
                      };
                      $html .= $q->td({-width=>"1%",-style=>"padding-right: 4px;"},
                                 $q->checkbox( { -name=>"qw",
                                                 -label=>"",
                                                 -checked=>(ina($param->{'qw'},$w) ? 'checked' : undef),
                                                 -onDblClick=>"javascript:qw_off_except(this);",
                                                 -override=>1,
                                                 -value=>$w } )
                               ).
                               $q->td({-style=>"padding-right: 10px;"},
                                 $labels->{$w}
                               );
                       if (($num % 3) == 2) {
                         $html .= '</tr>';
                       };
                       $num++;
                     }
                     $q->table({-border=>0,-cellpadding=>0,-cellspacing=>0,-width=>"1%"},
                       $html
                     );
                   }
           )
         )
       )
      )
      .
      $q->span({-id=>"server"},'<!-- Dynamic content target DIV -->').
      $q->div({-id=>"server_hidden",-style=>"visibility: hidden; position: absolute;"},
        $q->table({-cellspacing=>0,-cellpadding=>4,-border=>0},
          $q->Tr(
            $q->td({-align=>"left",-valign=>"top",-style=>"width: 16px;"},
              $q->img({-src=>$config->{web}->{webroot}."icons/server.png"})
            ),
            $q->td({-align=>"left",-valign=>"top",-style=>"width: 100px;"},
              "Servers"
            ),
            $q->td({-align=>"left"},
              eval {
               my $html ="";
               my $num = 0;
               my $groups = {};
               foreach my $server (sort {$a cmp $b} keys %{ $config->{servers} }) {
                  if (($num % 4) == 0) {
                    $html .= '<tr>';
                  };
                  $html .= $q->td({-width=>"1%",-style=>"padding-right: 4px;"},
                            $q->checkbox( { -name=>"sr",
                                            -label=>"",
                                            -id=>(edt($config->{servers}->{$server},'group') ? $config->{servers}->{$server}->{group} : "-XXX"),
                                            -checked=>(ina($param->{'sr'},$server) ? 'checked' : undef),
                                            -override=>1,
                                            -onDblClick=>"javascript:sr_off_except(this);",
                                            -onChange=>"javascript:sr_changed();",
                                            -value=>$server } )
                           ).
                           $q->td({-width=>"1%",-style=>"padding-right: 10px;"},
                             $server
                           );
                  if (($num % 4) == 3) {
                    $html .= '<td>&nbsp;</td></tr>';
                  };
                  $num++;
                  if (edt($config->{servers}->{$server},'group')) {
                    $groups->{$config->{servers}->{$server}->{group}} = '{'.$config->{servers}->{$server}->{group}.'}';
                  };
               };
               if (($num % 4) != 0) {
                 $html .= '<td>&nbsp;</td>' x ((4-($num % 4))*2);
                 $html .= '<td>&nbsp;</td></tr>';
               };
               $groups->{'-all'} = 'All servers';
               $groups->{'-custom'} = 'Custom selection';
               $q->table({-border=>0,-cellpadding=>0,-cellspacing=>0,-width=>"1%"},
                 $q->Tr(
                   $q->td({-colspan=>9,-align=>"left",-style=>"padding-bottom: 4px;"},
                     $q->popup_menu({ -name=>"ss",
                              -id=>"ss",
                              -style=>"width: 400px;",
                              -values=>[ sort {$a cmp $b} keys(%{$groups}) ],
                              -labels=>$groups,
                              -onChange=>"javascript:ss_changed();",
                              -default=>(exists($param->{'ss'}) ? ($param->{'ss'} || '-all') : '-all'),
                              -override=>1})
                   )
                 ),
                 $html
               );
             }
            )
          )
        )
      )
      .
      $q->span({-id=>"time"},'<!-- Dynamic content target DIV -->').
      $q->div({-id=>"time_hidden",-style=>"visibility: hidden; position: absolute;"},
       $q->table({-cellspacing=>0,-cellpadding=>4,-border=>0},
         $q->Tr(
           $q->td({-align=>"left",-style=>"width: 16px;"},
             $q->img({-src=>$config->{web}->{webroot}."icons/timerange.png"})
           ),
           $q->td({-align=>"left",-style=>"width: 100px;"},
             "Time Range"
           ),
           $q->td({-align=>"left"},
             $q->popup_menu({ -name=>"tr",
                              -id=>"tr",
                              -style=>"width: 125px;",
                              -values=>[ 'custom',
                                         '-1m',
                                         '-5m',
                                         '-10m',
                                         '-30m',
                                         '-1h',
                                         '-6h',
                                         '-12h',
                                         '-1d',
                                         '-2d',
                                         '-3d',
                                         '-7d',
                                         '0' ],
                              -labels=>{ 'custom' => 'Custom',
                                         '-1m'  => 'Last minute',
                                         '-5m'  => 'Last 5 minutes',
                                         '-10m' => 'Last 10 minutes',
                                         '-30m' => 'Last 30 minutes',
                                         '-1h'  => 'Last hour',
                                         '-6h'  => 'Last 6 hours',
                                         '-12h' => 'Last 12 hours',
                                         '-1d'  => 'Last 24 hours',
                                         '-2d'  => 'Last 2 days',
                                         '-3d'  => 'Last 3 days',
                                         '-7d'  => 'Last 7 days',
                                         '0' => 'Unlimited' },
                              -onChange=>"javascript:document.getElementById('tds').value='';document.getElementById('tde').value='';",
                              -default=>(exists($param->{'tr'}) ? $param->{'tr'} : '-1h'),
                              -override=>1})
           ),
           $q->td({-align=>"left",-style=>"padding-right:0px;"},
             $q->input({-name=>"tds",
                        -style=>"width: 105px;",
                        -value=>(exists($param->{'tds'}) ? $param->{'tds'} : ''),
                        -override=>1,
                        -onFocus=>"javascript:document.getElementById('tr').selectedIndex = 0; document.getElementById('tde').value='';",
                        -id=>"tds" }).
             $q->button({ -onClick=>"javascript:document.getElementById('tr').selectedIndex = 0; document.getElementById('tde').value=''; cal1x.select(document.forms[0].tds,'anchor1x','yyyy-MM-dd'); return false;",
                          -name=>"X",
                          -style=>"height: 18px; width: 18px;",
                          -id=>"anchor1x" })."&nbsp;-&nbsp;".
             $q->div({ -id=>'caldiv1x',
                       -style=>"position:absolute;visibility:hidden;background-color:white;background-color:white;" })
           ),
           $q->td({-align=>"left",-style=>"padding-left:0px;"},
             $q->input({-name=>"tde",
                        -style=>"width: 105px;",
                        -value=>(exists($param->{'tde'}) ? $param->{'tde'} : ''),
                        -override=>1,
                        -onFocus=>"javascript:document.getElementById('tr').selectedIndex = 0",
                        -id=>"tde" }).
             $q->button({ -onClick=>"javascript:document.getElementById('tr').selectedIndex = 0; cal2x.select(document.forms[0].tde,'anchor2x','yyyy-MM-dd'); return false;",
                          -name=>"X",
                          -style=>"height: 18px; width: 18px;",
                          -id=>"anchor2x" }).
             $q->div({ -id=>'caldiv2x',
                       -style=>"position:absolute;visibility:hidden;background-color:white;background-color:white;" })
           )
         )
       )
      )
      .
      '<hr>'
      .
      $q->table({-cellspacing=>0,-cellpadding=>4,-border=>0,-align=>"center"},
        $q->Tr(
          $q->td({-align=>"center"},
            $q->submit({-name=>"sm",-value=>"Start Query"})
          )
        )
      )

    )
  );

  print "\n".
  '
  <script language="JavaScript">
    init_controls();
    switch_controls(document.getElementById("qt").options[document.getElementById("qt").selectedIndex].value);
  </script>
  '
  ."\n";
};

1;
