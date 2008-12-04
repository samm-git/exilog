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

package exilog_cgi_html;
use exilog_config;
use exilog_util;
use CGI;
use strict;
use Data::Dumper;

BEGIN {
  use Exporter;
  use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

  $VERSION     = 0.1;
  @ISA         = qw(Exporter);
  @EXPORT      = qw(
                      &render_message
                      &render_reject
                      &render_queue
                      &render_header
                      &render_server
                      &render_queue_table
                      $q
                   );

  %EXPORT_TAGS = ();
  @EXPORT_OK   = qw();

  use vars qw( $q );
}

$q = new CGI;

# Renders server statistics
# $stats->{ID}->{order}
#              ->{desc}
#              ->{icon}
#              ->{text}

sub render_server {
  my $server = shift;
  my $num_queued = shift;
  my $h24_stats = shift;
  my $last_update = shift;

  $q->div({-class=>"top_spacer"},
    $q->table({-class=>"stats", -cellspacing=>1, -cellpadding=>2, -border=>0},
      $q->Tr(
        $q->td({-rowspan=>2,-class=>"table_stats",-style=>"width: 300px;"},
          $q->table({-cellpadding=>0, -cellspacing=>0, -border=>0},
            $q->Tr(
              $q->td({-class=>"large_icon"},
                $q->img({-src=>$config->{web}->{webroot}."icons/server_normal.png",-border=>0})
              ),
              $q->td({-class=>"large_text"},
                $server
              )
            ),
            $q->Tr(
               $q->td('', ''),
               $q->td('', 'last update: '. $last_update),
            )
          )
        ),
        $q->td({-class=>"table_stats"},
          $q->table({-cellpadding=>0, -cellspacing=>0, -border=>0, -width=>"1%"},
            $q->Tr(
              $q->td({-rowspan=>2,-class=>"large_icon"},
                $q->img({-src=>$config->{web}->{webroot}."icons/queue_normal.png",-border=>0,-title=>"Queue Status"})
              ),
              $q->td({-rowspan=>2,-class=>"large_icon"},
                "<b>Queue Status</b>"
              ),
              $q->td({-class=>"stats"},
                _item( { 'icon' => $config->{web}->{webroot}."icons/queued.png" },
                       { 
                         #'link' => { 'tab' => 'queues' },
                         'text' => ($num_queued->{deferred}+$num_queued->{frozen})." queued (".($num_queued->{deferred_bounce}+$num_queued->{frozen_bounce})." bounces)" } )

              ),
              $q->td({-class=>"stats"},
                ( $num_queued->{deferred} ?
                   _item( { 'icon' => $config->{web}->{webroot}."icons/deferred.png" },
                          { 'text' => $num_queued->{deferred}." deferred (".$num_queued->{deferred_bounce}." bounces)" } )
                :
                  "&nbsp;"
                )
              )
            ),
            $q->Tr(
              $q->td({-class=>"stats"},
                ( $num_queued->{frozen} ?
                   _item( { 'icon' => $config->{web}->{webroot}."icons/frozen.png" },
                          { 'text' => $num_queued->{frozen}." frozen (".$num_queued->{frozen_bounce}." bounces)" } )
                :
                  "&nbsp;"
                )
              )
            )
          )
        )
      ),
      $q->Tr(
        $q->td({-class=>"table_stats"},
          $q->table({-cellpadding=>0, -cellspacing=>0, -border=>0, -width=>"1%"},
            $q->Tr(
              $q->td({-rowspan=>2,-class=>"large_icon"},
                $q->img({-src=>$config->{web}->{webroot}."icons/stats_h24.png",-border=>0,-title=>"Usage Statistics"})
              ),
              $q->td({-rowspan=>2,-class=>"large_icon"},
                "<b>Last 24h stats</b>"
              ),
              $q->td({-class=>"stats"},
                _item( { 'icon' => $config->{web}->{webroot}."icons/arrival.png", 'title' => "Arrivals" },
                       { 'text' => $h24_stats->{arrivals}." arrivals" } )
              ),
              $q->td({-class=>"stats"},
                _item( { 'icon' => $config->{web}->{webroot}."icons/size.png", 'title' => "Average message size" },
                       { 'text' => "Average message size: ".human_size($h24_stats->{avg_msg_size}) } )
              )
            ),
            $q->Tr(
              $q->td({-class=>"stats"},
                  _item( { 'icon' => $config->{web}->{webroot}."icons/delivery.png" },
                         { 'text' => $h24_stats->{deliveries}." deliveries" } )
              ),
              $q->td({-class=>"stats"},
                  _item( { 'icon' => $config->{web}->{webroot}."icons/error.png" },
                         { 'text' => $h24_stats->{errors}." errors" } )
              )
            )
          )
        )
      )
    )
  );

};


# Renders messages and post-DATA rejects.

sub render_message {
  my $h = shift;    # main message context

  # Subclass list with references to HTML generation code.
  my $subclasses = { 'rejects' => \&_reject_html,
                     'deferrals' => \&_deferral_html,
                     'errors' => \&_error_html,
                     'deliveries' => \&_delivery_html,
                     'unknown' => \&_unknown_html,
                     'queue' => \&_queue_html };

  my $sort_pref = { 'rejects' => 5,
                    'deferrals' => 4,
                    'errors' => 3,
                    'deliveries' => 6,
                    'unknown' => 2,
                    'queue' => 1 };

  my @dde = (); # holds list of subclass hashrefs
                # --->{html} (HTML code generated by )
                #  \->{timestamp} (timestamp for sorting later)

  # Now loop through the subclass list and call HTML
  # generation code for each entry in all subclasses.
  # Push the stuff onto dde where we can sort it later.
  # Remember the timestamp of each entry so we can sort
  # by it later to display the message events in the
  # right order.
  foreach my $subclass (keys %{ $subclasses }) {
    foreach my $obj (@{ $h->{$subclass} }) {
      my $tmp = {};
      $tmp->{timestamp} = $obj->{timestamp};
      $tmp->{sort_pref} = $sort_pref->{$subclass};
      # pass in "master sort" timestamp too
      $tmp->{html} = &{$subclasses->{$subclass}}($obj,$h->{sort_timestamp});
      push @dde, $tmp;
    };
  };

  $q->div({-class=>"top_spacer"},
    $q->table({-class=>"message", -cellspacing=>1, -cellpadding=>2, -border=>0},
      _titlebar_html($h),
      (exists($h->{mailfrom}) ? _message_html($h) : ""),
      eval {
        my $event_html = "";
        foreach my $event (sort by_event_order @dde) {
          $event_html .= $event->{html};
        };
        $event_html;
      }
    )
  );
};
sub by_event_order {
  if ($a->{timestamp} == $b->{timestamp}) {
    ($a->{sort_pref} <=> $b->{sort_pref});
  }
  else {
    ($a->{timestamp} <=> $b->{timestamp});
  };
};


# This function is used to render pre-DATA rejects.
# Since those don't have any other associated events
# it is useless to go through all other tables like
# _render_message does.

sub render_reject {
  my $h = shift;
  $q->div({-class=>"top_spacer"},
    $q->table({-class=>"message", -cellspacing=>1, -cellpadding=>2, -border=>0},
      _titlebar_html($h).
      _reject_html($h,$h->{timestamp})
    )
  );
};


# renders a small "page header"

sub render_header {
  my $text = shift || "";

  $q->div({-class=>"top_spacer"},
    $q->table({-class=>"header", -cellspacing=>1, -cellpadding=>2, -border=>0},
      $q->Tr(
        $q->td({-class=>"header"},
          $text
        )
      )
    )
  );
}



sub _titlebar_html {
  my $h = shift || {};

  my $actions = [ 0, 'deliver' ];
  unless (ina($config->{web}->{restricted_users}, $main::user)) {
    if ($h->{mailfrom} ne '<>') {
      push @{$actions}, 'cancel';
    }
    push @{$actions}, 'delete';
  }
  
  $q->Tr(
    $q->td({-class=>"table_titlebar"},
      $q->table({-cellpadding=>0,-cellspacing=>0, -border=>0},
        $q->Tr(
          $q->td({-class=>"message_wide"},
            _item( { 'text' => $h->{server} },
                   ( (edv($h,'message_id') && ($h->{message_id} =~ /^.{6}\-.{6}-.{2}$/) ) ?
                                            { 'text' => '&middot;' } : undef ),
                   ( (edv($h,'message_id') && ($h->{message_id} =~ /^.{6}\-.{6}-.{2}$/) ) ?
                                            { 'link' => { 'tab' => 'messages',
                                                          'tr' => '0',
                                                          'qt' => 'message_id',
                                                          'qs' => $h->{message_id} },
                                              'text' => $h->{message_id} } : undef ),
                   ( edv($h,'msgid') ? { 'text' => '&middot;' } : undef ),
                   ( edv($h,'msgid') ? ({ 'link' => { 'tab' => 'messages',
                                                      'qt' => 'msgid',
                                                      'tr' => '0',
                                                      'qs' => $h->{msgid} },
                                          'text' => "Track MSGID"  }) : undef ),
                   ( (edv($h,'queue') &&
                     defined(@{$h->{queue}}[0])) ? { 'text' => '&middot;' } : undef ),
                   ( (edv($h,'queue') &&
                     defined(@{$h->{queue}}[0])) ? { 'html' =>

                        $q->div({ -id=>'ac_'.$h->{server}.'_'.$h->{'message_id'}.'_div',
                                  -style=>"margin:0; padding:0; border:0; width: 110px; color: red;" },
                          $q->popup_menu({ -values => $actions,
                                           -default => 0,
                                           -onChange=>"javascript:message_action('$h->{server}','$h->{message_id}',this,'ac_$h->{server}_$h->{message_id}_div');",
                                           -labels => { 0 => ':: Select action ::',
                                                              'deliver' => 'Force delivery',
                                                              'cancel' => 'Cancel (bounce)',
                                                              'delete' => 'Delete' },
                                           -override => 1 } )
                        )

                                                   } : undef ) )
          ),
          (exists($h->{size}) ?
          $q->td({-class=>"message"},
            _item( { 'icon' => $config->{web}->{webroot}."icons/size.png" },
                   { 'text' => human_size($h->{size})} )
          ) : ""),
          (exists($h->{completed}) ?
          $q->td({-class=>"message"},
            _item( { 'icon' => $config->{web}->{webroot}."icons/stopwatch.png"},
                   { 'text' => _timespan((defined($h->{completed}) ? $h->{completed} : time()) - $h->{timestamp} ) } )
          ) : "")
        )
      )
    )
  );
};


sub _message_html {
  my $h = shift || {};

  $q->Tr(
    $q->td({-class=>"table_arrival"},
      $q->table({-cellpadding=>0,-cellspacing=>0, -border=>0},
        $q->Tr(
          $q->td({-rowspan=>2,-valign=>"top",-align=>"center",-class=>"large_icon"},
            ( ($h->{proto} =~ /local/i) ?
                # local
                $q->img({-src=>$config->{web}->{webroot}."icons/arrival_local.png",-border=>0,-title=>uc($h->{proto})." | ".$h->{user}})
              :
                ( ( ($h->{proto} eq "asmtp") || ($h->{proto} =~ /a$/) ) ?
                  ( defined($h->{tls_cipher}) ?
                    # Auth w/ TLS
                    $q->img({-src=>$config->{web}->{webroot}."icons/arrival_tls_auth.png",-border=>0,-title=>uc($h->{proto})." | ".$h->{user}." | ".$h->{tls_cipher}})
                  :
                    # Auth w/o TLS
                    $q->img({-src=>$config->{web}->{webroot}."icons/arrival_auth.png",-border=>0,-title=>uc($h->{proto})." | ".$h->{user}})
                  )
                :
                  ( defined($h->{tls_cipher}) ?
                    # TLS
                    $q->img({-src=>$config->{web}->{webroot}."icons/arrival_tls.png",-border=>0,-title=>uc($h->{proto})." | ".$h->{tls_cipher}})
                  :
                    # nothing special
                    $q->img({-src=>$config->{web}->{webroot}."icons/arrival_normal.png",-border=>0,-title=>uc($h->{proto})})
                  )
                )
            )
          ),
          $q->td(
            _item( { 'style' => "font-weight: bold;",
                     ( ($h->{mailfrom} eq '<>') ?
                       ( (defined($h->{bounce_parent}) ?
                         ('link' => { 'tab' => 'messages',
                                      'tr' => '0',
                                      'qt' => 'message_id',
                                      'qs' => $h->{bounce_parent} })
                         : () ),
                        'text' => "Bounce".
                         (defined($h->{bounce_parent}) ?
                           " of ".$h->{bounce_parent}
                         :
                           ""
                         )
                       )
                     :
                       ('link' => { 'tab' => 'messages',
                                    'tr' => '0',
                                    'qt' => 'addr-all',
                                    'qs' => $h->{mailfrom} },
                        'text' => $h->{mailfrom})
                     ) }
                 )
          )
        ),
        $q->Tr(
          $q->td(
            _item( { 'style' => (($h->{timestamp} == $h->{sort_timestamp}) ? "text-decoration: underline;" : undef) , 'text' => stamp_to_date($h->{timestamp}) },
                   (defined($h->{host_addr}) ? (
                    { 'icon' => $config->{web}->{webroot}."icons/server.png" },
                    { 'link' => { 'tab' => 'messages',
                                  'tr' => '0',
                                  'qt' => 'host-all',
                                  'qs' => $h->{host_addr} },
                      'text' => $h->{host_addr} },
                    (edt($h,'host_rdns') ?
                      ( { 'icon' => $config->{web}->{webroot}."icons/dns.png" },
                        { 'link' => { 'tab' => 'messages',
                                      'tr' => '0',
                                      'qt' => 'host-all',
                                      'qs' => $h->{host_rdns} },
                          'text' => $h->{host_rdns} } )
                    :
                      ()
                    ),
                    (edt($h,'host_helo') ?
                      ( { 'icon' => $config->{web}->{webroot}."icons/helo.png" },
                        { 'link' => { 'tab' => 'messages',
                                      'tr' => '0',
                                      'qt' => 'host-all',
                                      'qs' => $h->{host_helo} },
                          'text' => $h->{host_helo} } )
                    :
                      ()
                    ),
                    (defined($h->{host_ident}) ? (
                     { 'icon' => $config->{web}->{webroot}."icons/ident.png" },
                     { 'link' => { 'tab' => 'messages',
                                   'tr' => '0',
                                   'qt' => 'ident',
                                   'qs' => $h->{host_ident} },
                       'text' => $h->{host_ident} } )
                    : () )
                   )
                   : () ) )
          )
        )
      )
    )
  );
};

sub _deferral_html {
  my $deferral = shift || {};
  my $sort_timestamp = shift || 0;

  $q->Tr(
    $q->td({-class=>"table_deferral"},
      $q->table({-cellpadding=>0,-cellspacing=>0, -border=>0},
        $q->Tr(
          $q->td({-rowspan=>3,-valign=>"top",-align=>"center",-class=>"large_icon"},
            ( defined($deferral->{tls_cipher}) ?
              # w/ TLS
              $q->img({-src=>$config->{web}->{webroot}."icons/deferral_tls.png",-border=>0,-title=>$deferral->{tls_cipher}})
            :
              # w/o TLS
              $q->img({-src=>$config->{web}->{webroot}."icons/deferral_normal.png",-border=>0})
            )
          ),
          $q->td(
            _item( { 'style' => "font-weight: bold;",
                     'link' => { 'tab' => 'messages',
                                 'tr' => '0',
                                 'qt' => 'addr-all',
                                 'qs' => $deferral->{rcpt} },
                     'text' => $deferral->{rcpt} },
                     (edt($deferral,'rcpt_intermediate') ?
                         ({ 'text' => '-> '.$deferral->{rcpt_intermediate} })
                       :
                         ()
                     ),
                     ((lc($deferral->{rcpt}) ne lc($deferral->{rcpt_final})) ?
                         ({ 'link' => { 'tab' => 'messages',
                                        'tr' => '0',
                                        'qt' => 'addr-all',
                                        'qs' => $deferral->{rcpt_final} },
                            'text' => '-> '.$deferral->{rcpt_final} })
                       :
                         ()
                     )
                   )
          )
        ),
        $q->Tr(
          $q->td(
            _item( { 'style' => (($deferral->{timestamp} == $sort_timestamp) ? "text-decoration: underline;" : undef) , 'text' => stamp_to_date($deferral->{timestamp}) },
                   { 'icon' => $config->{web}->{webroot}."icons/router_transport.png" },
                   { 'text' => $deferral->{router}.
                   ( defined($deferral->{transport}) ?
                     "->".$deferral->{transport}.(defined($deferral->{shadow_transport}) ? " [".$deferral->{shadow_transport}."]" : "")
                   :
                     "") },
                   ( defined($deferral->{host_addr}) ?
                    ( { 'icon' => $config->{web}->{webroot}."icons/server.png" },
                      { 'link' => { 'tab' => 'messages',
                                    'tr' => '0',
                                    'qt' => 'host-all',
                                    'qs' => $deferral->{host_addr} },
                        'text' => $deferral->{host_addr} },
                      { 'icon' => $config->{web}->{webroot}."icons/dns.png" },
                      { 'link' => { 'tab' => 'messages',
                                    'tr' => '0',
                                    'qt' => 'host-all',
                                    'qs' => $deferral->{host_dns} },
                        'text' => $deferral->{host_dns} } )
                   :
                      ()
                   ) )
          )
        ),
        $q->Tr(
          $q->td(
            _item( { 'icon' => $config->{web}->{webroot}."icons/errmsg.png" },
                   { 'text' => $deferral->{errmsg} } )
          )
        )
      )
    )
  );
};

sub _reject_html {
  my $reject = shift || {};
  my $sort_timestamp = shift || 0;

  $q->Tr(
    $q->td({-class=>"table_reject"},
      $q->table({-cellpadding=>0,-cellspacing=>0,-border=>0},
        $q->Tr(
          $q->td({-rowspan=>2,-valign=>"top",-align=>"center",-class=>"large_icon"},
            (edv($reject,'message_id') ?
              # post-DATA
              $q->img({-src=>$config->{web}->{webroot}."icons/reject_postdata.png",-border=>0})
            :
              # pre-DATA
              $q->img({-src=>$config->{web}->{webroot}."icons/reject_predata.png",-border=>0})
            )
          ),
          $q->td(
            _item( (edv($reject,'mailfrom') ?
                     (($reject->{mailfrom} eq '<>') ?
                       { 'style' => "font-weight: bold;",
                         'text' => "Bounce" }
                     :
                       { 'link' => { 'tab' => 'messages',
                                     'tr' => '0',
                                     'qt' => 'addr-all',
                                     'qs' => $reject->{mailfrom} },
                         'style' => "font-weight: bold;",
                         'text' => $reject->{mailfrom} }
                     )
                   :
                     () ),
                   { 'icon' => $config->{web}->{webroot}."icons/server.png" },
                   { 'link' => { 'tab' => 'messages',
                                 'tr' => '0',
                                 'qt' => 'host-all',
                                 'qs' => $reject->{host_addr} },
                     'text' => $reject->{host_addr} },
                   (edt($reject,'host_rdns') ?
                      ( { 'icon' => $config->{web}->{webroot}."icons/dns.png" },
                        { 'link' => { 'tab' => 'messages',
                                      'tr' => '0',
                                      'qt' => 'host-all',
                                      'qs' => $reject->{host_rdns} },
                          'text' => $reject->{host_rdns} } )
                    :
                      ()
                    ),
                    (edt($reject,'host_helo') ?
                      ( { 'icon' => $config->{web}->{webroot}."icons/helo.png" },
                        { 'link' => { 'tab' => 'messages',
                                    'tr' => '0',
                                    'qt' => 'host-all',
                                    'qs' => $reject->{host_helo} },
                          'text' => $reject->{host_helo} } )
                    :
                      ()
                    ),
                   (defined($reject->{host_ident}) ?
                    ( { 'icon' => $config->{web}->{webroot}."icons/ident.png" },
                      { 'link' => { 'tab' => 'messages',
                                    'tr' => '0',
                                    'qt' => 'ident',
                                    'qs' => $reject->{host_ident} },
                        'text' => $reject->{host_ident} } ) : ()
                   ) )
          )
        ),
        $q->Tr(
          $q->td(
            _item( { 'style' => (($reject->{timestamp} == $sort_timestamp) ? "text-decoration: underline;" : undef) , 'text' => stamp_to_date($reject->{timestamp}) },
                   { 'icon' => $config->{web}->{webroot}."icons/errmsg.png" },
                   { 'text' => $reject->{errmsg} } )
          )
        )
      )
    )
  );
};

sub _error_html {
  my $error = shift || {};
  my $sort_timestamp = shift || 0;

  $q->Tr(
    $q->td({-class=>"table_error"},
      $q->table({-cellpadding=>0,-cellspacing=>0, -border=>0},
        $q->Tr(
          $q->td({-rowspan=>3,-valign=>"top",-align=>"center",-class=>"large_icon"},
            ( defined($error->{tls_cipher}) ?
              # w/ TLS
              $q->img({-src=>$config->{web}->{webroot}."icons/error_tls.png",-border=>0,-title=>$error->{tls_cipher}})
            :
              # w/o TLS
              $q->img({-src=>$config->{web}->{webroot}."icons/error_normal.png",-border=>0})
            )
          ),
          $q->td(
            _item( { 'style' => "font-weight: bold;",
                     'link' => { 'tab' => 'messages',
                                 'tr' => '0',
                                 'qt' => 'addr-all',
                                 'qs' => $error->{rcpt} },
                     'text' => $error->{rcpt} },
                     (edt($error,'rcpt_intermediate') ?
                         ({ 'text' => '-> '.$error->{rcpt_intermediate} })
                       :
                         ()
                     ),
                     ((lc($error->{rcpt}) ne lc($error->{rcpt_final})) ?
                         ({ 'link' => { 'tab' => 'messages',
                                        'tr' => '0',
                                        'qt' => 'addr-all',
                                        'qs' => $error->{rcpt_final} },
                            'text' => '-> '.$error->{rcpt_final} })
                       :
                         ()
                     )
                   )
          )
        ),
        $q->Tr(
          $q->td(
            _item( { 'style' => (($error->{timestamp} == $sort_timestamp) ? "text-decoration: underline;" : undef) , 'text' => stamp_to_date($error->{timestamp}) },
                   ( edv($error,'router') ? (
                   { 'icon' => $config->{web}->{webroot}."icons/router_transport.png" },
                   { 'text' => $error->{router}.
                   ( defined($error->{transport}) ?
                     "->".$error->{transport}.(defined($error->{shadow_transport}) ? " [".$error->{shadow_transport}."]" : "")
                   :
                     "") },
                   ( defined($error->{host_addr}) ?
                    ( { 'icon' => $config->{web}->{webroot}."icons/server.png" },
                      { 'link' => { 'tab' => 'messages',
                                    'tr' => '0',
                                    'qt' => 'host-all',
                                    'qs' => $error->{host_addr} },
                        'text' => $error->{host_addr} },
                      { 'icon' => $config->{web}->{webroot}."icons/dns.png" },
                      { 'link' => { 'tab' => 'messages',
                                    'tr' => '0',
                                    'qt' => 'host-all',
                                    'qs' => $error->{host_dns} },
                        'text' => $error->{host_dns} } )
                   :
                      ()
                   ) ) : () ) )
          )
        ),
        $q->Tr(
          $q->td(
            _item( { 'icon' => $config->{web}->{webroot}."icons/errmsg.png" },
                   { 'text' => $error->{errmsg} } )
          )
        )
      )
    )
  );
};

sub _delivery_html {
  my $delivery = shift || {};
  my $sort_timestamp = shift || 0;

  $q->Tr(
    $q->td({-class=>"table_delivery"},
      $q->table({-cellpadding=>0,-cellspacing=>0, -border=>0},
        $q->Tr(
          $q->td({-rowspan=>2,-valign=>"top",-align=>"center",-class=>"large_icon"},
            ( defined($delivery->{tls_cipher}) ?
              # w/ TLS
              $q->img({-src=>$config->{web}->{webroot}."icons/delivery_tls.png",-border=>0,-title=>$delivery->{tls_cipher}})
            :
              # w/o TLS
             $q->img({-src=>$config->{web}->{webroot}."icons/delivery_normal.png",-border=>0})
            )
          ),
          $q->td(
            _item( { 'style' => "font-weight: bold;",
                     'link' => { 'tab' => 'messages',
                                 'tr' => '0',
                                 'qt' => 'addr-all',
                                 'qs' => $delivery->{rcpt} },
                     'text' => $delivery->{rcpt} },
                     (edt($delivery,'rcpt_intermediate') ?
                         ({ 'text' => '-> '.$delivery->{rcpt_intermediate} })
                       :
                         ()
                     ),
                     ((lc($delivery->{rcpt}) ne lc($delivery->{rcpt_final})) ?
                         ({ 'link' => { 'tab' => 'messages',
                                        'tr' => '0',
                                        'qt' => 'addr-all',
                                        'qs' => $delivery->{rcpt_final} },
                            'text' => '-> '.$delivery->{rcpt_final} })
                       :
                         ()
                     )
                   )
          )
        ),
        $q->Tr(
          $q->td(
            _item( { 'style' => (($delivery->{timestamp} == $sort_timestamp) ? "text-decoration: underline;" : undef) , 'text' => stamp_to_date($delivery->{timestamp}) },
                   { 'icon' => $config->{web}->{webroot}."icons/router_transport.png" },
                   { 'text' => $delivery->{router}.
                   ( defined($delivery->{transport}) ?
                     "->".$delivery->{transport}.(defined($delivery->{shadow_transport}) ? " [".$delivery->{shadow_transport}."]" : "")
                   :
                     "") },
                   ( defined($delivery->{host_addr}) ?
                    ( { 'icon' => $config->{web}->{webroot}."icons/server.png" },
                      { 'link' => { 'tab' => 'messages',
                                    'tr' => '0',
                                    'qt' => 'host-all',
                                    'qs' => $delivery->{host_addr} },
                        'text' => $delivery->{host_addr} },
                      { 'icon' => $config->{web}->{webroot}."icons/dns.png" },
                      { 'link' => { 'tab' => 'messages',
                                    'tr' => '0',
                                    'qt' => 'host-all',
                                    'qs' => $delivery->{host_dns} },
                        'text' => $delivery->{host_dns} } )
                   :
                      ()
                   ) )
          )
        )
      )
    )
  );
};

sub _unknown_html {
  my $unknown = shift || {};
  my $sort_timestamp = shift || 0;

  $q->Tr(
    $q->td({-class=>"table_unknown"},
      $q->table({-cellpadding=>0,-cellspacing=>0, -border=>0},
        $q->Tr(
          $q->td({-valign=>"top",-align=>"center",-class=>"large_icon"},
            $q->img({-src=>$config->{web}->{webroot}."icons/unknown.png",-border=>0})
          ),
          $q->td(
            _item( { 'style' => (($unknown->{timestamp} == $sort_timestamp) ? "text-decoration: underline;" : undef) , 'text' => stamp_to_date($unknown->{timestamp}) },
                   { 'text' => $unknown->{line} } )
          )
        )
      )
    )
  );
};

sub _queue_html {
  my $queue = shift || {};
  my $sort_timestamp = shift || 0;

  my @recipients_delivered = split / /, $queue->{recipients_delivered};
  my @recipients_pending = split / /, $queue->{recipients_pending};

  $q->Tr(
    $q->td({-class=>"table_queue"},
      $q->table({-cellpadding=>0,-cellspacing=>0, -border=>0},
        $q->Tr(
          $q->td({-rowspan=>2,-valign=>"top",-align=>"center",-class=>"large_icon"},
            ( edt($queue,'frozen') ?
              # frozen
              $q->img({-src=>$config->{web}->{webroot}."icons/queue_frozen.png",-border=>0,-title=>"Frozen at ".stamp_to_date($queue->{frozen})})
            :
              # normal
              $q->img({-src=>$config->{web}->{webroot}."icons/queue_deferred.png",-border=>0})
            )
          ),
          $q->td(
            _item( { #'style' => "font-family: Arial, Helvetica, Sans-Serif;",
                     'text' => $queue->{subject} } )
          )
        ),
        $q->Tr(
          $q->td(
            _item( { 'icon' => $config->{web}->{webroot}."icons/delivered.png",
                     ( (scalar @recipients_delivered) ?
                       ( 'title' => join("\n",@recipients_delivered) )
                     :
                       ()
                     ) },
                   { 'text' => scalar @recipients_delivered },
                   { 'text' => '&nbsp;' },
                   { 'icon' => $config->{web}->{webroot}."icons/deferred.png",
                     'title' => join("\n",@recipients_pending) },
                   { 'text' => scalar @recipients_pending },
                   { 'text' => '&nbsp;' },
                   { 'icon' => $config->{web}->{webroot}."icons/dsn_warning.png",
                     'title' => "Number of DSNs sent" },
                   { 'text' => $queue->{num_dsn} } )
          )
        )
      )
    )
  );
};

sub render_queue_table {
  my $messages = shift;
  my $now = time();

  my $rows = "";
  foreach my $message (@{ $messages }) {

    my $actions = [ 0, 'deliver' ];
    unless (ina($config->{web}->{restricted_users}, $main::user)) {
      if ($message->{mailfrom} ne '<>') {
        push @{$actions}, 'cancel';
      }
      push @{$actions}, 'delete';
    }

    my $row_id = $message->{server}.'_'.$message->{message_id};
    my @rcpts_delivered = split / /,$message->{recipients_delivered};
    my @rcpts_pending = split / /,$message->{recipients_pending};
    my $rcpts_html = "";
    foreach my $rcpt (@rcpts_pending) {
      $rcpts_html .=
        _item( { 'icon' => 'icons/deferred.png' },
               { 'text' => $rcpt } );
    }
    foreach my $rcpt (@rcpts_delivered) {
      $rcpts_html .=
        _item( { 'icon' => 'icons/delivered.png' },
               { 'text' => $rcpt } );
    }
    my $headers = $message->{headers};
    $headers =~ s/\&/&amp;/g;
    $headers =~ s/\</&lt;/g;
    $headers =~ s/\>/&gt;/g;

    $rows .=
      $q->Tr(
        $q->td(
          $q->table({-class=>"queue_entry_table",-cellpadding=>2,-cellspacing=>1,-border=>0},
            $q->Tr(
              $q->td({ -class=>"queue",
                       -width=>32,
                       -rowspan=>2},
                ( edt($message,'frozen') ?
                     png("icons/queue_frozen.png",32,32,"Frozen at ".stamp_to_date($message->{frozen}))
                   :
                     png("icons/queue_deferred.png",32,32,"")
                )
              ),
              $q->td({-class=>"queue"},
                _item( { 'icon' => "icons/server.png" },
                       { 'text' => $message->{server} } )
              ),
              $q->td({-class=>"queue", -align=>"center"},
                _item( { 'icon' => "icons/timerange.png" },
                       { 'text' => (edt($message,'timestamp') ?
                                    _timespan($now - $message->{timestamp},2)
                                    :
                                    '?' ) } )
              ),
              $q->td({ -class=>"queue",
                       -width=>"300" },
                _item( { 'icon' => "icons/arrival.png" },
                       { 'text' => _shorten_addr($message->{mailfrom},40) } )
              ),
              $q->td({-class=>"queue",
                      -onMouseOver=>"javascript:document.getElementById('$row_id' + '_rcpts').style.visibility = 'visible';",
                      -onMouseOut=>"javascript:document.getElementById('$row_id' + '_rcpts').style.visibility = 'hidden';" },
                $q->div({-class=>"popup_container"},
                  $q->div({-id=>$row_id.'_rcpts',
                           -class=>"popup",
                           -style=>"width:326px;"},
                     $rcpts_html
                  )
                ).
                _item( { 'icon' => "icons/deferred.png" }, 
                       { 'html' => _shorten_addr($rcpts_pending[0],40).
                                    ( ((scalar @rcpts_pending) + (scalar @rcpts_delivered) > 1) ?
                                    ' (+'.((scalar @rcpts_pending)+(scalar @rcpts_delivered)-1).'&darr;)' : "" ) } )
              )
            ),
            $q->Tr(
              $q->td({ -class=>"queue",
                       -width=>120,
                       -nowrap=>"nowrap",
                       -align=>"center"},
                $message->{message_id}
              ),
              $q->td({ -class=>"queue",
                       -style=>"padding: 0px;",
                       -width=>110,
                       -align=>"center"},
                $q->div({ -id=>'ac_'.$message->{server}.'_'.$message->{'message_id'}.'_div',
                          -style=>"margin:0; padding:0; border:0; width: 110px; color: red;" },
                $q->popup_menu({ -values => $actions,
                                 -style=>"width: 110px;",
                                 -default => 0,
                                 -onChange=>"javascript:message_action('$message->{server}','$message->{message_id}',this,'ac_$message->{server}_$message->{message_id}_div');",
                                 -labels => { 0 => ':: Select action ::',
                                              'deliver' => 'Force delivery',
                                              'cancel' => 'Cancel (bounce)',
                                              'delete' => 'Delete' },
                                 -override => 1 }) )
              ),
              $q->td({-class=>"queue",
                      -onMouseDown=>"javascript:document.getElementById('$row_id' + '_headers').style.visibility = 'visible';",
                      -style=>"font-family: Arial, Helvetica, Sans-Serif;",colspan=>2},
                $q->div({-class=>"popup_container"},
                  $q->div({-id=>$row_id.'_headers',
                           -class=>"popup",
                           -onDblClick=>"javascript:document.getElementById('$row_id' + '_headers').style.visibility = 'hidden';",
                           -style=>"width:635px;"},
                     '<pre style="font-size: 12px;">'.
                     $headers.
                     '</pre>'
                  )
                ).
                _shorten_string($message->{subject},100)
              )
            )
          )
        )
      );
  };

  $q->div({-class=>"top_spacer"},
    $q->table({-class=>"queue_frame_table",-cellpadding=>0,-cellspacing=>0,border=>0},
      $rows
    )
  );
};


# -- Private functions -------------------------------------

sub _item {
  my $html = "";

  # Loop through all parts and build the table TDs
  while (scalar @_) {
    my $part = shift @_;
    next unless $part;
    
    my $link = "";
    if (exists($part->{'link'})) {
      # this item has a link
      $link = 'exilog_cgi.pl?';
      foreach my $var (keys %{ $part->{'link'} }) {
        $link .= $var.'='._url_encode($part->{'link'}->{$var}).'&';
      }
      chop($link);
    }

    if (exists($part->{icon})) {
      $html .=
        $q->td({ -class=>"item_icon",
                 -style=>(exists($part->{style}) ? $part->{style} : "")},
          png($part->{icon},16,16,(exists($part->{title}) ? $part->{title} : "" ))
        );
      next;
    }
    elsif (exists($part->{html})) {
      $html .= $q->td({ -class=>"item_text",
                    }, $part->{html});
    }
    elsif (exists($part->{text})) {
      # HTML-quote angle brackets
      $part->{text} =~ s/\>/\&gt\;/g;
      $part->{text} =~ s/\</\&lt\;/g;

      # break long text at colons or blanks
      $part->{text} =~ s/([^<>]{80,}?)([: ])/$1$2\<br\>/g;

      $html .=
        $q->td({-class=>"item_text",
                ($link ? ( -onClick=>"javascript:document.location.href='$link';",
                           -style=>(exists($part->{style}) ? $part->{style} : "")."cursor:pointer;cursor:hand;",
                           -onMouseOver=>"javascript:link_on(this);",
                           -onMouseOut=>"javascript:link_off(this);" )
                : (
                    -style=>(exists($part->{style}) ? $part->{style} : "")
                  ) ) },
          $part->{text}
        );
    };
  };

  # Wrap everything in the surrounding table.
  return
    $q->table({-class=>"item",-cellspacing=>0,-cellpadding=>0,-border=>0},
      $q->Tr(
        $html
      )
    );
};


sub _shorten_addr {
  my $addr = shift;
  my $max = shift;
  return $addr if (length($addr) <= $max);

  my ($localpart,$domain) = split /\@/, $addr, 2;

  if (length($addr) > (int($max/2))) {
    # shorten local part first
    $localpart = substr($localpart,0,int($max/4)).'...';
  };
  # return if that suffices
  return $localpart.'@'.$domain if (length($localpart.'@'.$domain) <= $max);

  # shorten domain
  my @domainparts = split /\./, $domain;
  while ((scalar @domainparts) > 1) {
    shift @domainparts;
    last if (length($localpart.'@'.'...'.join('.',@domainparts)) <= $max);
  };

  return $localpart.'@'.'...'.join('.',@domainparts);
};


sub _shorten_string {
  my $string = shift;
  my $max = shift;
  return $string if (length($string) <= $max);
  return substr($string,0,($max-3)).'...';
};


sub _timespan {
  my $amnt = shift;
  my $cutoff = shift || 999;
  my $str = '';
  my @units = ('wk','d','h','m','s');
  my @quantums = ( (7*24*60*60*1),
                   (  24*60*60*1),
                   (     60*60*1),
                   (        60*1),
                   (           1) );  

  foreach my $quantum (@quantums) {
    if (int($amnt/$quantum) > 0) {
      $str .= int($amnt/$quantum).$units[0]." ";
      $amnt = $amnt%$quantum;
      last unless (--$cutoff);
    }
    shift @units;
    last unless ($amnt);
  }
  # Fall-through default
  $str = '0s' unless ($str);
  return $str;
};

sub _url_encode {
  my $subj = shift;
  $subj =~ s/([^A-Za-z0-9])/sprintf("%%%02x",ord($1))/eg;
  return $subj;
};

1;
