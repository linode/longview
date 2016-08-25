Name:     linode-longview
Version:  1.1
Release:  5
Summary:  Linode Longview Agent
License:  GPLv2+
BuildArch: noarch
Source: https://github.com/linode/longview/archive/v%{version}.%{release}.tar.gz

Requires: perl-LWP-Protocol-https,perl-DBD-MySQL

BuildRequires: systemd-units
Requires(post): systemd-units
Requires(preun): systemd-units
Requires(postun): systemd-units

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
echo $OLDPWD
rm -rf %{buildroot}
mkdir -p %{buildroot}/opt/linode/longview/lib/perl5/
mkdir -p %{buildroot}%{_unitdir}
mkdir -p %{buildroot}/etc/linode/longview.d
mkdir -p %{buildroot}/opt/linode/longview/Linode/Longview/DataGetter/Packages
mkdir -p %{buildroot}/opt/linode/longview/Extras/
cp $OLDPWD/Extras/init/longview.service %{buildroot}%{_unitdir}/longview.service
cp -r $OLDPWD/Extras/lib/perl5/* %{buildroot}/opt/linode/longview/lib/perl5/
cp -r $OLDPWD/Linode %{buildroot}/opt/linode/longview/
cp $OLDPWD/Extras/app-report.pl %{buildroot}/opt/linode/longview/Extras/app-report.pl
cp $OLDPWD/Extras/Modules/Packages/YUM.pm %{buildroot}/opt/linode/longview/Linode/Longview/DataGetter/Packages/YUM.pm
cp $OLDPWD/Extras/conf/* %{buildroot}/etc/linode/longview.d/

%files
%{_unitdir}/longview.service
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
    /bin/systemctl daemon-reload >/dev/null 2>&1 || :
    /bin/systemctl enable longview.service >/dev/null 2>&1 || :
fi

%preun
if [ $1 -eq 0 ] ; then
    # Package removal, not upgrade
    /bin/systemctl --no-reload disable longview.service > /dev/null 2>&1 || :
    /bin/systemctl stop longview.service > /dev/null 2>&1 || :
fi

%postun
/bin/systemctl daemon-reload >/dev/null 2>&1 || :
if [ $1 -ge 1 ] ; then
    # Package upgrade, not uninstall
    /bin/systemctl try-restart longview.service >/dev/null 2>&1 || :
fi
