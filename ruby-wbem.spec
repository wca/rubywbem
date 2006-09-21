%{!?ruby_sitelib: %define ruby_sitelib %(ruby -rrbconfig -e "puts Config::CONFIG['sitelibdir']")}

Summary: RubyWBEM is a pure-Ruby library for performing operations using the WBEM management protocol
Name: ruby-wbem
Version: 0.1
Release: 1
License: GPL
Group: Systems Management/Base
URL: http://rubyforge.org/projects/rubywbem
Source0: %{name}-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArchitectures: noarch

Requires: ruby >= 1.8.1
Requires: ruby(abi) = 1.8
BuildRequires: ruby >= 1.8.1
BuildRequires: ruby-devel
Provides: ruby(wbem)

%description
RubyWBEM is a pure-Ruby library for performing CIM operations over
HTTP using the WBEM management protocol. RubyWBEM originated as a
direct port of pyWbem (http://pywbem.sourceforge.net).

%prep
%setup -q

%build

%install
rm -rf $RPM_BUILD_ROOT
mkdir %{buildroot}

%{__install} -d -m0755 %{buildroot}%{ruby_sitelib}
%{__install} -d -m0755 %{buildroot}%{ruby_sitelib}/wbem

%{__install} -p -m0644 lib/wbem/*.rb %{buildroot}%{ruby_sitelib}/wbem
%{__install} -p -m0644 lib/wbem.rb %{buildroot}%{ruby_sitelib}

%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(-,root,root,-)
%{ruby_sitelib}/wbem
%{ruby_sitelib}/wbem.rb
%doc AUTHORS CHANGELOG LICENSE README


%changelog
* Wed Sep 20 2006  <sseago@localhost.localdomain> - 
- Initial build.

