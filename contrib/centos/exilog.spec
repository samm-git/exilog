Name:	exilog
Version:	0.5.1
Release:	1
Summary:	exilog 
Group:		Application/Exilog	
License:	GPL
Source0:	exilog-0.5.1-1.tar.gz
Source1:	exilog.init
Source2:	exilog.http.conf
Source3:	exilog.logrotate
BuildArch:	x86_64
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}
Requires:	perl-CGI perl-Net-Netmask httpd mysql-server

%description
Exilog exim log analizator daemon

%prep
%setup -q -n %{name}-%{version}-%{release}
cp %{SOURCE1} exilog.init
cp %{SOURCE2} exilog.http.conf
cp %{SOURCE3} exilog.logrotate

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/usr/lib/%{name}
mkdir -p $RPM_BUILD_ROOT/usr/lib/%{name}/cgi-bin
mkdir -p $RPM_BUILD_ROOT/etc/%{name}
mkdir -p $RPM_BUILD_ROOT/usr/sbin
mkdir -p $RPM_BUILD_ROOT/etc/rc.d/init.d
mkdir -p $RPM_BUILD_ROOT/srv/www/exilog
mkdir -p $RPM_BUILD_ROOT/srv/www/exilog/icons
mkdir -p $RPM_BUILD_ROOT/etc/httpd/conf.d
mkdir -p $RPM_BUILD_ROOT/var/run/exilog
mkdir -p $RPM_BUILD_ROOT/etc/logrotate.d
install -m640 conf/exilog.conf-example $RPM_BUILD_ROOT/etc/%{name}/exilog.conf
install -m644 lib/exilog_config.pm	$RPM_BUILD_ROOT/usr/lib/%{name}/
install -m644 lib/exilog_parse.pm	$RPM_BUILD_ROOT/usr/lib/%{name}/
install -m644 lib/exilog_sql.pm	$RPM_BUILD_ROOT/usr/lib/%{name}/
install -m644 lib/exilog_util.pm	$RPM_BUILD_ROOT/usr/lib/%{name}/
install -m644 cgi/exilog_cgi_html.pm	$RPM_BUILD_ROOT/usr/lib/%{name}/cgi-bin/
install -m644 cgi/exilog_cgi_messages.pm	$RPM_BUILD_ROOT/usr/lib/%{name}/cgi-bin/
install -m644 cgi/exilog_cgi_param.pm	$RPM_BUILD_ROOT/usr/lib/%{name}/cgi-bin/
install -m644 cgi/exilog_cgi_queues.pm	$RPM_BUILD_ROOT/usr/lib/%{name}/cgi-bin/
install -m644 cgi/exilog_cgi_servers.pm	$RPM_BUILD_ROOT/usr/lib/%{name}/cgi-bin/
install -m755 cgi/exilog_cgi.pl	$RPM_BUILD_ROOT/srv/www/exilog/
install -m755 agent/exilog_agent.pl	$RPM_BUILD_ROOT/usr/sbin/
install -m755 agent/exilog_cleanup.pl	$RPM_BUILD_ROOT/usr/sbin/
install -m755 exilog.init	$RPM_BUILD_ROOT/etc/rc.d/init.d/exilog
install -m644 htdocs/icons/*	$RPM_BUILD_ROOT/srv/www/exilog/icons/
install -m644 htdocs/exilog_jscript.js	$RPM_BUILD_ROOT/srv/www/exilog/
install -m644 htdocs/exilog_stylesheet.css	$RPM_BUILD_ROOT/srv/www/exilog/
install -m644 exilog.http.conf	$RPM_BUILD_ROOT/etc/httpd/conf.d/exilog.conf
install -m644 exilog.logrotate	$RPM_BUILD_ROOT/etc/logrotate.d/exilog
sed -i -e "s|/usr/lib/cgi-bin/exilog|/usr/lib/exilog/cgi-bin|" $RPM_BUILD_ROOT/srv/www/exilog/exilog_cgi.pl
sed -i -e "s|'/var/log/exim4/mainlog'|'/var/log/exim/main.log'|" $RPM_BUILD_ROOT/etc/exilog/exilog.conf
sed -i -e "s|'queue' => '/var/spool/exim4'|'queue' => '/var/spool/exim'|" $RPM_BUILD_ROOT/etc/exilog/exilog.conf
sed -i -e "s|'webroot' => '/exilog'|'webroot' => ''|" $RPM_BUILD_ROOT/etc/exilog/exilog.conf

%files
%defattr(-,root,root)
/usr/lib/%{name}/exilog_config.pm
/usr/lib/%{name}/exilog_parse.pm
/usr/lib/%{name}/exilog_sql.pm
/usr/lib/%{name}/exilog_util.pm
%attr(640,apache,root) %config(noreplace) /etc/%{name}/exilog.conf
%doc doc/Changelog doc/exilog.txt doc/mysql-db-script.sql doc/pgsql-db-script.sql
/usr/sbin/exilog_agent.pl
/usr/sbin/exilog_cleanup.pl
/etc/rc.d/init.d/exilog
/etc/logrotate.d/exilog
/usr/lib/exilog/cgi-bin/exilog_cgi_html.pm
/usr/lib/exilog/cgi-bin/exilog_cgi_messages.pm
/usr/lib/exilog/cgi-bin/exilog_cgi_param.pm
/usr/lib/exilog/cgi-bin/exilog_cgi_queues.pm
/usr/lib/exilog/cgi-bin/exilog_cgi_servers.pm
/srv/www/exilog/icons/*
/srv/www/exilog/exilog_jscript.js
/srv/www/exilog/exilog_stylesheet.css
/srv/www/exilog/exilog_cgi.pl
/etc/httpd/conf.d/exilog.conf
%dir /var/run/exilog

%clean
rm -rf $RPM_BUILD_ROOT
