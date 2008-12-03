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
  my $messages = sql_select('queue',[ '*' ]);
  print render_queue_table($messages);
};


sub _print_Queue_selector {

  print
  $q->div({-class=>"top_spacer"},
    $q->div({-align=>"left",-style=>"padding: 10px; border: 1px solid black; background: #eeeeee;"},

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
           }.($@ ? $@ : "")
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
};

1;

