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

use strict;

use lib "/usr/lib/exilog";
use lib "/usr/lib/cgi-bin/exilog";

use exilog_config;
use exilog_util;
use exilog_cgi_html;
use exilog_cgi_param;
use exilog_sql;

# Put user name into global variable
my $user = $ENV{'REMOTE_USER'} || 'anonymous';

# XMLHTTP requests are handled here.
# We only return short result statements
# in text/plain format for those.
if ($param->{'xmlhttp'} == 1) {
  print $q->header(-expires=>'Thursday, 01-Jan-1970 00:00:01 GMT',
                   -Expires=>'now',
                   -Content-Type=>'text/plain',
                   -Cache-Control=>'no-cache',
                   -Cache-Control=>'no-store',
                   -Pragma=>'no-cache');
  print _do_xmlhttp_actions();
  exit(0);
}

_print_cgi_headers();
_print_html_header();
_print_html_tabs();

print '<div class="display" align="center">';
if ($param->{tab} eq 'queues') {
  use exilog_cgi_queues;
  queues();
}
elsif ($param->{tab} eq 'messages') {
  use exilog_cgi_messages;
  messages();
}
elsif ($param->{tab} eq 'servers') {
  use exilog_cgi_servers;
  servers();
};
print '</div>';

_print_html_footer();


# -- Private functions ---------------------------------------------------------

sub _do_xmlhttp_actions {
  # queue actions
  my $valid_actions = [ 'deliver', 'cancel', 'delete' ];
  my $restricted_actions = [ 'cancel', 'delete' ];
  my $action_text = { 'deliver' => 'Forcing', 'cancel' => 'Cancelling', 'delete' => 'Deleting' };  

  if ( ina($valid_actions,$param->{'action'}) &&
       !(ina($restricted_actions,$param->{'action'}) && ina($config->{web}->{restricted_users},$main::user)) ) {
    sql_queue_set_action($param->{'server'},$param->{'message_id'},$param->{'action'});
    return $action_text->{$param->{'action'}};
  }

  return 0;
};


sub _print_cgi_headers {
  print $q->header(-expires=>'Thursday, 01-Jan-1970 00:00:01 GMT',
                   -Expires=>'now',
                   -Cache-Control=>'no-cache',
                   -Cache-Control=>'no-store',
                   -Pragma=>'no-cache');
};


sub _print_html_header {
  print $q->start_html({-title=>"Exilog ".$version,
                        -style=>{-src=>$config->{web}->{webroot}."exilog_stylesheet.css"},
                        -script=>[
                                   {-language=>'JAVASCRIPT',
                                    -src=>$config->{web}->{webroot}."exilog_jscript.js"},
                                   "document.write(getCalendarStyles());"
                                 ],
                        -meta=>{'http-equiv' => 'pragma', 'content' => 'no-cache'}});
  # global "centering" div
  print $q->start_form({-name=>"exilogform",-method=>"GET"});
  print '<div align="center">';
  print '<div align="center" class="body">';
};

sub _print_html_tabs {
  my $tabs = { 'servers' => "Servers",
               'messages' => "Messages",
               'queues' => "Queues",
               'messages' => "Messages" };

  my $html;

  foreach my $tab (sort keys %{ $tabs }) {
    $html .= $q->td({-class=>"tabs_spacer"},"&nbsp;").
             (($param->{"tab"} eq $tab) ?
                $q->td({-class=>"tabs_active"},$tabs->{$tab})
               :
                $q->td({-class=>"tabs_click", -onClick=>"javascript:load_tab('$tab');"},$tabs->{$tab}));
  };

  print $q->table({-class=>"tabs",-cellpadding=>2,-cellspacing=>0},
          $q->Tr(
            $q->td({-align=>"center",-class=>"tabs_static",-style=>"font-size: 16px; font-weight: bold;" }, "Exilog").
            $html.
            $q->td({-class=>"tabs_spacer"},"&nbsp;").
            $q->td({-align=>"center",-class=>"tabs_static",-style=>"font-size: 12px; width: 240px; white-space: nowrap;" }, "&nbsp;&nbsp;Server time".(($config->{web}->{timestamps} eq 'gmt') ? " (GMT)":"").": ".stamp_to_date(time())."&nbsp;&nbsp;")
          )
        );

  print $q->input({-type=>"hidden",-name=>"tab",-id=>"tab",-override=>1,-value=>$param->{"tab"}});
};


sub _print_html_footer {
  print '</div></div>';
  print $q->end_form();
  print $q->end_html();
};
