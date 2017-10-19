# Exilog - Central logging and reporting tool for Exim

| Tag | Value |
| - | - |
| Author | Tom Kistner <tom@duncanthrax.net> |
| Version | 0.5.1 |
| License | GPLv2 |

## Introduction

Exilog is a tool to centralize and visualize Exim logs
across multiple Exim servers. It is used in addition to
Exim's standard or syslog logging. It does not require
changing Exim or its logging style (In fact you don't
even need to restart your Exim(s) to install Exilog).

Exilog is SQL-based and requires

* A SQL Server (mysql and postgres are supported)
* An HTTP Server with CGI support (Apache comes to mind)
* Perl with
  * DBD/DBI SQL Database modules for the selected database.
  * Net::Netmask module
  You can get these modules via CPAN, but there is a good
  chance that your OS distribution has precompiled packages
  available.
* A modern browser (recent Mozilla, Firefox, IE5/6, Safari)

## Target Audience

Postmasters who want to be able to troubleshoot email
delivery across their Exim installations, no matter if
used as relays or backend IMAP and POP toasters.

Postmasters who want to offload support grungework to
staff who is less proficient with grep, sed and awk.

## Features

Search for addresses, hosts (names and IP addresses),
messages IDs and ident strings.

Filter by event types: Arrivals, Deliveries, Deferrals,
Errors, Rejects and messages that are still on-queue.

Message actions: Force delivery, cancel and delete.

Filter by time range, servers and server groups.

See basic host statistics, message sizes, message transfer
times.

Point-and-click on message IDs, IP addresses, hostnames to
get different filtering results.

Track messages across servers by header message ID.

## Installation

An Exilog installation consist of four parts:

1. The database holding the log information.
1. The web interface.
1. The agents on the Exim servers.
1. Database cleanup (via Cron)

These parts can reside on different machines, or all be
on the same machine. For best results, the database and
web interface should be on the same physical box, however.

### 1. Installing the database

Select if you want to use MySQL or Postgres. MySQL is
somehow preferred since its default case insensitivy
is better suited for the job.

Create a database using the respective SQL scripts from
/doc. For postgres, you might have to slightly edit the
script to change the 'exilog' user name (or create the
'exilog' user first).

If necessary, create a database user that has
full rights on the new database.

Make sure the database is reachable by TCP/IP from each
of your Exim servers.

### 2. Installing the Web Interface

Untar the exilog distribution somewhere where your HTTP
server can reach it (/var/www/localhost/htdocs/exilog ...
you get the idea).

Rename the exilog.conf-example file to exilog.conf and
edit it. It is fully commented. Then return to this document.

exilog\_cgi.pl is the web interface. Set it up as
DirectoryIndex if you like.

Optionally, set up access controls. You should also deny
read access to exilog.conf from HTTP clients.

Open your browser and open exilog\_cgi.pl. If you see
the "Messages" tab you are fine.

If you want to restrict access to the web interface, set
up basic authentication (possibly via .htaccess/.htpasswd).

Now we need to feed some data into the database.

### 3. Installing the Exim server agent(s)

You'll need to deploy one Exilog agent on each exim server
you run.

For each server, untar the Exilog distribution somewhere,
overwrite the vanilla exilog.conf with the one you edited
in step 2, then open it and tweak the "agent" section to
match the server you are installing it on. Also tweak the
SQL section to include host and port definitions of your SQL
server so the agent knows where to connect to.

Then run exilog\_agent.pl as root. You might want to include
a start/stop procedure for the agent in your Exim rc file.

You can also run the agent as a non-root user if that UID

* Can read Exim's logs.
* Write the configured agent log file.
* Is a trusted user in Exim.

Of course root can do all that without further configuration
tweaks. Using Exim's own effective UID is also possible.

Sending SIGTERM to the agent parent process will make it
cleanly quit, including all of its children.

When the agent is started, it will pump the current log file
into the database (this can take a while), then tail it. It
will automatically detect log rotation and re-open the file
if necessary.

### 4. Setting up the database cleanup script

Set up exilog\_cleanup.pl to run daily via cron. This will
typically reside on the database or web host. Remember to
set the "cleanup->cutoff" parameter in exilog.conf to the
number of days worth of data you want to keep in the database.

## Usage

That should be pretty straightforward. One detail is important:

When searching for addresses and hostnames, you must use SQL
wildcards when only specifying a substring:

| Wildcard | Description |
| - | - |
| % | Matches any string of zero or more characters |
| \_ | Matches any one character |

Example: You want to find all mails with addresses that contain
'joe', so you'd search for '%joe%'.

## Credits

* Tom Kistner <tom@duncanthrax.net> June 2005
