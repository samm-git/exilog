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

package exilog_cgi_queues;
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
                      &queues
                   );

  %EXPORT_TAGS = ();

  # your exported package globals go here,
  # as well as any optionally exported functions
  @EXPORT_OK   = qw();
}


sub queues {
  _print_Queue_selector();

  # Return unless the search type is set.
  return unless (edt($param,'q_qt'));

  # Get all data for messages passing the filter settings.
  my $criteria = { 'timestamp' => (edt($param,'q_tr') ? _make_tr() : undef),
                   'server' => (edt($param,'q_sr') ? $param->{'q_sr'} : undef ) };

  my $messages = sql_select('queue',[ '*' ], $criteria);

  my $prefiltered = [];
  foreach my $message (@{ $messages }) {
    next if (!ina($param->{'q_qw'},'frozen') && (edt($message,'frozen')));
    next if (!ina($param->{'q_qw'},'deferred') && (!edt($message,'frozen')));
    next if (!ina($param->{'q_qw'},'bounce') && ($message->{mailfrom} eq '<>'));
    push @{$prefiltered}, $message;
  }

  # Now do the most expensive filtering
  my $regex = dos2rx(($param->{'q_qs'} || '*'));
  my $filtered = [];
  if ($param->{'q_qt'} eq 'addr') {
    MESSAGE: foreach my $message (@{ $prefiltered }) {
      if ($message->{'mailfrom'} =~ /$regex/i) {
        push @{$filtered}, $message;
        next;
      }
      foreach my $addr (split / /, $message->{'recipients_pending'}.' '.$message->{'recipients_delivered'}) {
        if ($addr =~ /$regex/i) {
          push @{$filtered}, $message;
          next MESSAGE;
        }
      }
    }
  }
  elsif ($param->{'q_qt'} eq 'subject') {
    foreach my $message (@{ $prefiltered }) {
      if ($message->{'subject'} =~ /$regex/i) {
        push @{$filtered}, $message;
      }
    }
  }
  elsif ($param->{'q_qt'} eq 'headers') {
    foreach my $message (@{ $prefiltered }) {
      if ($message->{'headers'} =~ /$regex/smi) {
        push @{$filtered}, $message;
      }
    }
  }
  else {
    $filtered = $prefiltered;
  }

  print render_queue_table($filtered);
};


sub _make_tr {
  my $str = $q->param('q_tr') || 0;

  my $unit = chop $str;
  my $now = time();
  my $units = { '0' => 0,
                'm' => 60,
                'h' => 3600,
                'd' => 86400 };
  return '0 '.($now + $units->{$unit}*$str);
}


sub _print_Queue_selector {

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
            $q->popup_menu({ -name=>"q_qt",
                             -id=>"q_qt",
                             -style=>"width: 400px;",
                             -values=>[ 'all',
                                        'addr',
                                        'subject',
                                        'headers'
                                      ],
                             -labels=>{ 'all' => "None - show everything",
                                        'addr' => "Address",
                                        'subject' => "Subject",
                                        'headers' => "Headers"
                                      },
                             -default=>(exists($param->{'q_qt'}) ? ($param->{'q_qt'} || 'all') : 'all'),
                             -onChange=>"javascript:switch_controls(document.getElementById('q_qt').options[document.getElementById('q_qt').selectedIndex].value);",
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
              $q->textfield( { -name=>"q_qs",
                               -style=>"width: 400px;",
                               -value=>(exists($param->{'q_qs'}) ? ($param->{'q_qs'} || '') : ''),
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
             "Status"
           ),
           $q->td({-align=>"left",-style=>"padding:2px 4px 4px 4px;"},
             eval {
                     my @where = ( 'frozen',
                                   'deferred',
                                   'bounce' );

                     my $labels = { 'frozen' => 'Frozen',
                                    'deferred' => 'Deferred',
                                    'bounce' => 'Bounce' };

                     my $html = "";
                     my $num = 0;
                     foreach my $w (@where) {
                       if (($num % 3) == 0) {
                         $html .= '<tr>';
                       }
                       $html .= $q->td({-width=>"1%",-style=>"padding-right: 4px;"},
                                 $q->checkbox( { -name=>"q_qw",
                                                 -label=>"",
                                                  -checked=>(ina($param->{'q_qw'},$w) ? 'checked' : undef),
                                                  -onDblClick=>"javascript:q_qw_off_except(this);",
                                                  -override=>1,
                                                  -value=>$w } )
                                ).
                                $q->td({-style=>"padding-right: 10px;"},
                                  $labels->{$w}
                                );
                       if (($num % 3) == 2) {
                         $html .= '</tr>';
                       }
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
                  }
                  $html .= $q->td({-width=>"1%",-style=>"padding-right: 4px;"},
                            $q->checkbox( { -name=>"q_sr",
                                            -label=>"",
                                            -id=>(edt($config->{servers}->{$server},'group') ? $config->{servers}->{$server}->{group} : "-XXX"),
                                            -checked=>(ina($param->{'q_sr'},$server) ? 'checked' : undef),
                                            -override=>1,
                                            -onDblClick=>"javascript:q_sr_off_except(this);",
                                            -onChange=>"javascript:q_sr_changed();",
                                            -value=>$server } )
                           ).
                           $q->td({-width=>"1%",-style=>"padding-right: 10px;"},
                             $server
                           );
                  if (($num % 4) == 3) {
                    $html .= '<td>&nbsp;</td></tr>';
                  }
                  $num++;
                  if (edt($config->{servers}->{$server},'group')) {
                    $groups->{$config->{servers}->{$server}->{group}} = '{'.$config->{servers}->{$server}->{group}.'}';
                  }
               }
               if (($num % 4) != 0) {
                 $html .= '<td>&nbsp;</td>' x ((4-($num % 4))*2);
                 $html .= '<td>&nbsp;</td></tr>';
               }
               $groups->{'-all'} = 'All servers';
               $groups->{'-custom'} = 'Custom selection';
               $q->table({-border=>0,-cellpadding=>0,-cellspacing=>0,-width=>"1%"},
                 $q->Tr(
                   $q->td({-colspan=>9,-align=>"left",-style=>"padding-bottom: 4px;"},
                     $q->popup_menu({ -name=>"q_ss",
                              -id=>"q_ss",
                              -style=>"width: 400px;",
                              -values=>[ sort {$a cmp $b} keys(%{$groups}) ],
                              -labels=>$groups,
                              -onChange=>"javascript:q_ss_changed();",
                              -default=>(exists($param->{'q_ss'}) ? ($param->{'q_ss'} || '-all') : '-all'),
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
             "Age"
           ),
           $q->td({-align=>"left"},
             $q->popup_menu({ -name=>"q_tr",
                              -id=>"q_tr",
                              -style=>"width: 400px;",
                              -values=>[ '0',
                                         '-5m',
                                         '-1h',
                                         '-12h',
                                         '-1d' ],
                              -labels=>{ '0' => 'Any',
                                         '-5m'  => 'Older than 5 minutes',
                                         '-1h'  => 'Older than 1 hour',
                                         '-12h' => 'Older than 12 hours',
                                         '-1d'  => 'Older than 1 day' },
                              -default=>(exists($param->{'q_tr'}) ? $param->{'q_tr'} : '-5m'),
                              -override=>1})
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
    switch_controls(document.getElementById("q_qt").options[document.getElementById("q_qt").selectedIndex].value);
  </script>
  '
  ."\n";

};

1;

