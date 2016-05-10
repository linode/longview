Name:     linode-longview
Version:  1.1
Release:  5
Summary:  Linode Longview Agent
License:  GPLv2+
BuildArch: noarch

Requires: perl(Crypt::SSLeay),perl(DBD::mysql)
Obsoletes: longview

%description
The Linode Longview data collection agent

%prep
http_fetch() {
	mkdir -p `dirname $2`
	if command -v wget >/dev/null 2>&1; then
		wget -q -4 -O $2 $1 || { 
			echo >&2 "Failed to fetch $1. Aborting install.";
			exit 1;
		}
	elif command -v curl >/dev/null 2>&1; then
		curl -sf4L $1 > $2 || { 
			echo >&2 "Failed to fetch $1. Aborting install.";
			exit 1;
		}
	else
		echo "Unable to find curl or wget, can not fetch needed files"
		exit 1
	fi
}
[ -e $OLDPWD/Extras/lib/perl5/Linux/Distribution.pm  ] || http_fetch http://cpansearch.perl.org/src/CHORNY/Linux-Distribution-0.23/lib/Linux/Distribution.pm $OLDPWD/Extras/lib/perl5/Linux/Distribution.pm
[ -e $OLDPWD/Extras/lib/perl5/Try/Tiny.pm ] || http_fetch http://cpansearch.perl.org/src/ETHER/Try-Tiny-0.24/lib/Try/Tiny.pm $OLDPWD/Extras/lib/perl5/Try/Tiny.pm

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/opt/linode/longview/lib/perl5/
mkdir -p %{buildroot}/opt/linode/longview/Linode/Longview/DataGetter/Packages/
mkdir -p %{buildroot}/opt/linode/longview/Extras/
mkdir -p %{buildroot}/etc/init.d/
mkdir -p %{buildroot}/etc/linode/longview.d
cp $OLDPWD/Extras/init/longview.centos.sh %{buildroot}/etc/init.d/longview
cp -r $OLDPWD/Extras/lib/perl5/* %{buildroot}/opt/linode/longview/lib/perl5/
cp -r $OLDPWD/Linode %{buildroot}/opt/linode/longview/
cp $OLDPWD/Extras/Modules/Packages/YUM.pm %{buildroot}/opt/linode/longview/Linode/Longview/DataGetter/Packages/YUM.pm
cp $OLDPWD/Extras/app-report.pl %{buildroot}/opt/linode/longview/Extras/app-report.pl
cp $OLDPWD/Extras/conf/* %{buildroot}/etc/linode/longview.d/

%files
/etc/init.d/longview
/opt/linode/longview/lib/perl5/Linux/Distribution.pm
/opt/linode/longview/lib/perl5/Try/Tiny.pm
/opt/linode/longview/Linode/Longview.pl
/opt/linode/longview/Linode/Longview/*.pm
/opt/linode/longview/Linode/Longview/DataGetter/*.pm
/opt/linode/longview/Linode/Longview/DataGetter/Applications/*.pm
/opt/linode/longview/Linode/Longview/DataGetter/Packages/YUM.pm
%config %attr(640,root,root) /etc/linode/longview.d/*.conf
/opt/linode/longview/Extras/app-report.pl

%post
if [ $1 -eq 1 ] ; then 
    # Initial installation 
    service longview start || :
    chkconfig --add longview
    chkconfig --level 35 longview on
fi
chmod -R o-rwx /etc/linode/longview.d/

%preun
if [ $1 -eq 0 ] ; then
    # Package removal, not upgrade
    service longview stop || :
    chkconfig --del longview
fi

%postun
/bin/systemctl daemon-reload >/dev/null 2>&1 || :
if [ $1 -ge 1 ] ; then
    # Package upgrade, not uninstall
    service longview restart || :
fi
