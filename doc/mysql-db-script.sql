# phpMyAdmin MySQL-Dump
# version 2.3.2
# http://www.phpmyadmin.net/ (download page)
#
# Host: localhost
# Erstellungszeit: 02. Juni 2005 um 15:40
# Server Version: 3.23.47
# PHP-Version: 4.1.2
# Datenbank: `exilog`
# --------------------------------------------------------

#
# Tabellenstruktur für Tabelle `deferrals`
#

CREATE TABLE `deferrals` (
  `server` varchar(32) NOT NULL default '',
  `message_id` varchar(23) binary NOT NULL default '',
  `timestamp` bigint(20) NOT NULL default '0',
  `rcpt` varchar(200) NOT NULL default '',
  `rcpt_intermediate` varchar(200) default NULL,
  `rcpt_final` varchar(200) NOT NULL default '',
  `host_addr` varchar(39) default NULL,
  `host_dns` varchar(255) default NULL,
  `tls_cipher` varchar(128) default NULL,
  `router` varchar(128) default NULL,
  `transport` varchar(128) default NULL,
  `shadow_transport` varchar(128) default NULL,
  `errmsg` blob,
  PRIMARY KEY  (`server`,`message_id`,`timestamp`,`rcpt`,`rcpt_final`),
  KEY `rcpt` (`rcpt`),
  KEY `rcpt_final` (`rcpt_final`),
  KEY `server` (`server`),
  KEY `message_id` (`message_id`),
  KEY `timestamp` (`timestamp`),
  KEY `host_addr` (`host_addr`)
) TYPE=MyISAM;
# --------------------------------------------------------

#
# Tabellenstruktur für Tabelle `deliveries`
#

CREATE TABLE `deliveries` (
  `server` varchar(32) NOT NULL default '',
  `message_id` varchar(23) binary NOT NULL default '',
  `timestamp` bigint(20) NOT NULL default '0',
  `rcpt` varchar(200) NOT NULL default '',
  `rcpt_intermediate` varchar(200) default NULL,
  `rcpt_final` varchar(200) NOT NULL default '',
  `host_addr` varchar(39) default NULL,
  `host_dns` varchar(255) default NULL,
  `tls_cipher` varchar(128) default NULL,
  `router` varchar(128) default NULL,
  `transport` varchar(128) default NULL,
  `shadow_transport` varchar(128) default NULL,
  PRIMARY KEY  (`server`,`message_id`,`timestamp`,`rcpt`,`rcpt_final`),
  KEY `rcpt` (`rcpt`),
  KEY `rcpt_final` (`rcpt_final`),
  KEY `host_dns` (`host_dns`),
  KEY `timestamp` (`timestamp`),
  KEY `server` (`server`),
  KEY `message_id` (`message_id`),
  KEY `host_addr` (`host_addr`)
) TYPE=MyISAM;
# --------------------------------------------------------

#
# Tabellenstruktur für Tabelle `errors`
#

CREATE TABLE `errors` (
  `server` varchar(32) NOT NULL default '',
  `message_id` varchar(23) binary NOT NULL default '',
  `timestamp` bigint(20) NOT NULL default '0',
  `rcpt` varchar(200) NOT NULL default '',
  `rcpt_intermediate` varchar(200) default NULL,
  `rcpt_final` varchar(200) NOT NULL default '',
  `host_addr` varchar(39) default NULL,
  `host_dns` varchar(255) default NULL,
  `tls_cipher` varchar(128) default NULL,
  `router` varchar(128) default NULL,
  `transport` varchar(128) default NULL,
  `shadow_transport` varchar(128) default NULL,
  `errmsg` blob,
  PRIMARY KEY  (`server`,`message_id`,`timestamp`,`rcpt`,`rcpt_final`),
  KEY `timestamp` (`timestamp`),
  KEY `server` (`server`),
  KEY `rcpt` (`rcpt`),
  KEY `host_addr` (`host_addr`),
  KEY `message_id` (`message_id`),
  KEY `rcpt_final` (`rcpt_final`)
) TYPE=MyISAM;
# --------------------------------------------------------

#
# Tabellenstruktur für Tabelle `messages`
#

CREATE TABLE `messages` (
  `server` varchar(32) NOT NULL default '',
  `message_id` varchar(23) binary NOT NULL default '',
  `timestamp` bigint(20) default NULL,
  `msgid` varchar(255) default NULL,
  `completed` bigint(20) default NULL,
  `mailfrom` varchar(255) default NULL,
  `host_addr` varchar(39) default NULL,
  `host_rdns` varchar(255) default NULL,
  `host_ident` varchar(255) default NULL,
  `host_helo` varchar(255) default NULL,
  `proto` varchar(32) default NULL,
  `size` bigint(20) default NULL,
  `tls_cipher` varchar(128) default NULL,
  `user` varchar(128) default NULL,
  `bounce_parent` varchar(16) default NULL,
  PRIMARY KEY  (`server`,`message_id`),
  KEY `msgid` (`msgid`),
  KEY `user` (`user`),
  KEY `timestamp` (`timestamp`),
  KEY `host_addr` (`host_addr`),
  KEY `message_id` (`message_id`),
  KEY `bounce_parent` (`bounce_parent`),
  KEY `mailfrom` (`mailfrom`),
  KEY `server` (`server`),
  KEY `host_dns` (`host_rdns`)
) TYPE=MyISAM;
# --------------------------------------------------------

#
# Tabellenstruktur für Tabelle `queue`
#

CREATE TABLE `queue` (
  `server` varchar(32) NOT NULL default '',
  `message_id` varchar(23) binary NOT NULL default '',
  `mailfrom` varchar(255) NOT NULL default '',
  `timestamp` bigint(20) NOT NULL default '0',
  `num_dsn` int(11) NOT NULL default '0',
  `frozen` bigint(20) default NULL,
  `recipients_delivered` blob,
  `recipients_pending` blob,
  `spool_path` varchar(64) NOT NULL default '',
  `subject` varchar(255) default NULL,
  `msgid` varchar(255) default NULL,
  `headers` blob NOT NULL,
  `action` varchar(64) default NULL,
  PRIMARY KEY  (`server`,`message_id`),
  KEY `spool_path` (`spool_path`),
  KEY `mailfrom` (`mailfrom`),
  KEY `message_id` (`message_id`),
  KEY `server` (`server`),
  KEY `timestamp` (`timestamp`),
  KEY `frozen` (`frozen`),
  KEY `msgid` (`msgid`),
  KEY `action` (`action`)
) TYPE=MyISAM;
# --------------------------------------------------------

#
# Tabellenstruktur für Tabelle `rejects`
#

CREATE TABLE `rejects` (
  `server` varchar(32) NOT NULL default '',
  `message_id` varchar(23) binary default NULL,
  `timestamp` bigint(20) NOT NULL default '0',
  `host_addr` varchar(39) NOT NULL default '',
  `host_rdns` varchar(255) NOT NULL default '',
  `host_ident` varchar(255) default NULL,
  `host_helo` varchar(255) default NULL,
  `mailfrom` varchar(255) default NULL,
  `rcpt` varchar(255) default NULL,
  `errmsg` varchar(255) NOT NULL default '',
  UNIQUE KEY `rejects_unique` (`server`,`timestamp`,`host_addr`,`errmsg`),
  KEY `message_id` (`message_id`),
  KEY `server` (`server`),
  KEY `timestamp` (`timestamp`),
  KEY `host_addr` (`host_addr`),
  KEY `mailfrom` (`mailfrom`),
  KEY `rcpt` (`rcpt`),
  KEY `host_dns` (`host_rdns`)
) TYPE=MyISAM;
# --------------------------------------------------------

#
# Tabellenstruktur für Tabelle `unknown`
#

CREATE TABLE `unknown` (
  `server` varchar(32) NOT NULL default '',
  `message_id` varchar(23) binary NOT NULL default '',
  `timestamp` bigint(20) NOT NULL default '0',
  `line` varchar(255) NOT NULL default '',
  PRIMARY KEY  (`server`,`message_id`,`timestamp`,`line`),
  KEY `server` (`server`),
  KEY `message_id` (`message_id`),
  KEY `timestamp` (`timestamp`)
) TYPE=MyISAM;

--
-- Table structure for table `heartbeats`
--

CREATE TABLE IF NOT EXISTS `heartbeats` (
  `server` varchar(32) NOT NULL,
  `timestamp` bigint(20) default NULL,
  PRIMARY KEY  (`server`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
