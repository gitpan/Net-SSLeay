#
# RPM Spec file for Net-SSLeay on RH7, SuSE and similar
# Run with:
#  cp Net-SSLeay-1.35.tar.gz /usr/src/packages/SOURCES                             
#  rpmbuild -bb Net-SSLeay.spec
#  cp /usr/src/packages/RPMS/i586/Net-SSLeay-1.35-1.i586.rpm .
# On RHEL5:
#  cp Net-SSLeay-1.35.tar.gz /usr/src/redhat/SOURCES/ 
#  rpmbuild -bb Net-SSLeay.spec
#  cp /usr/src/redhat/RPMS/x86_64/Net-SSLeay-1.35-1.x86_64.rpm .
#
# Author: Mike McCauley (mikem@open.com.au)
# Copyright (C) 2001-2008 Open System Consultants
# $Id: Net-SSLeay.spec,v 1.1 2008/11/08 01:49:55 mikem Exp mikem $

Summary: Net-SSLeay precompiled bundle with EAP-FAST extensions
Name: Net-SSLeay
Version: 1.35
Release: 1
#Serial: 13501
#Copyright: OpenSSL group, Sampo Kellomaki, Florian Ragwitz, Mike McCauley
License: OpenSSL and Perl
Group: System/Servers
Source: %{name}-%{version}.tar.gz
URL: http://www.open.com.au/radiator/free-downloads
#Vendor: Open System Consultants Pty. Ltd.
Packager: Open System Consultants, Mike McCauley <mikem@open.com.au>
AutoReqProv: no
Provides: net-ssleay
Requires: perl = 5.8.8
Prefix: /usr

%description
This is a precompiled bundle which includes Net-SSLeay 1.32 + patches prelinked
with OpenSSL 0.9.8e + Jouni Malinen's Session Secret patches.
%prep
%setup

%build
PREFIX=$RPM_BUILD_ROOT perl Makefile.PL
make

%install
make install

%files
# For RHEL5:
#/usr/lib64/perl5/site_perl/5.8.8/x86_64-linux-thread-multi/Net/SSLeay
#/usr/lib64/perl5/site_perl/5.8.8/x86_64-linux-thread-multi/auto/Net/SSLeay
/usr/lib/perl5/site_perl/5.8.8/i586-linux-thread-multi/auto/Net/SSLeay
/usr/lib/perl5/site_perl/5.8.8/i586-linux-thread-multi/Net/SSLeay

%changelog
* Sat Nov  8 2008 Mike McCauley <mikem@open.com.au>
  - Build on OpenSuSE 10.3 32 bit (with GCC4.2)
* Tue Jan  1 2008 Mike McCauley <mikem@open.com.au>
  - Initial build

# This fixes a legacy problem with rpmbuild in RH8:
%undefine __check_files
