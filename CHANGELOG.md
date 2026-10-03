# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.7.4] - 2026-10-03

- Added a compile-time check that installs missing perl modules (Getopt::Std, File::Basename) with cpanm or cpan

## [1.7.3] - 2026-10-03

- Added a README status section noting that recent changes need testing

## [1.7.2] - 2026-10-03

- Cleaned up README formatting and added a support development section

## [1.7.1] - 2026-10-03

- Fixed usage and README missing the -d, -f, -l, -r, -u, -v, -C and -V options, and unclear -D and -R descriptions

## [1.7.0] - 2026-10-03

- Fixed usage and README examples using -d (description) instead of -w (work directory) and corrected the Publish typo

## [1.6.9] - 2026-10-03

- Fixed package specific scripts being copied where pkgmk could not find them, and duplicate prototype entries

## [1.6.8] - 2026-10-03

- Fixed ignored command and file open failures; build, packaging and publish failures now stop the script

## [1.6.7] - 2026-10-03

- Fixed unquoted paths in shell commands by rejecting unsafe characters in option values

## [1.6.6] - 2026-10-03

- Fixed archive detection for GNU/POSIX tar files and unsupported archives now stop with an error

## [1.6.5] - 2026-10-03

- Fixed rm -rf of the source directory when a tarball's first entry is ./

## [1.6.4] - 2026-10-03

- Fixed cd failures falling through to rm -rf and other commands by chaining with && instead of ;

## [1.6.3] - 2026-10-03

- Fixed -C exiting silently; it now checks the environment without requiring a source and reports missing information

## [1.6.2] - 2026-10-03

- Fixed running with no arguments creating work directories after printing usage

## [1.6.1] - 2026-10-03

- Fixed incorrect find instructions printed for the RSA package

## [1.6.0] - 2026-10-03

- Fixed SMF repository port variable not being used

## [1.5.9] - 2026-10-03

- Fixed hardcoded x86 OpenSSL target and 64 bit Perl flags on other architectures

## [1.5.8] - 2026-10-03

- Fixed VENDOR missing from the generated pkginfo

## [1.5.7] - 2026-10-03

- Fixed sources file only being found in the current directory; it is now read from the script directory first and a missing file is reported

## [1.5.6] - 2026-10-03

- Fixed bsl version lookup by matching bash in the sources file

## [1.5.5] - 2026-10-03

- Fixed sources URLs keeping a trailing newline, which caused the source to be downloaded on every run; orca snapshot URLs now match

## [1.5.4] - 2026-10-03

- Fixed source name and version parsing for names with extra dashes, orca snapshots and .tar.bz2/.tbz2 files; extension removal is now anchored

## [1.5.3] - 2026-10-03

- Fixed -s source file being copied to a missing src directory on Linux; it now goes to SOURCES

## [1.5.2] - 2026-10-03

- Fixed ZFS dataset path creating invalid rpool//path names

## [1.5.1] - 2026-10-03

- Fixed escaping of the SYSLOG_HISTORY sed pattern in the RPM spec

## [1.5.0] - 2026-10-03

- Fixed orca server SMF stop method killing sshd

## [1.4.9] - 2026-10-03

- Fixed syntax errors in generated bsl postinstall and preremove scripts

## [1.4.8] - 2026-10-03

- Fixed RPM summary and URL being overwritten for every package; summary now defaults to the package name

## [1.4.7] - 2026-10-03

- Fixed swapped and misplaced RPM scriptlets for bsl and rsa packages

## [1.4.6] - 2026-10-03

- Fixed infinite recursion in source file lookup when the download fails

## [1.4.5] - 2026-10-03

- Fixed IPS mog file arch string assignment so variant.arch is written

## [1.4.4] - 2026-10-03

- Fixed IPS manifest sed rewriting path=etc to path=usr

## [1.4.3] - 2014-01-13

- Added symlink support to RPM build find

## [1.4.2] - 2013-12-25

- Moved sources to an external file so it can be maintained easier

## [1.4.1] - 2013-12-24

- Fixed ruby dependency for IPS package manifest

## [1.4.0] - 2013-12-21

- Added support for ruby packages

## [1.3.9] - 2013-12-21

- Cleaned up code and added intial Solaris 11 IPS package support

## [1.3.8] - 2013-11-06

- Fixed formatting

## [1.3.7] - 2013-10-09

- Fixed post install script for RSA on Solaris

## [1.3.6] - 2013-09-12

- Moved changelog into a separate file

## [1.3.5] - 2013-09-12

- Added prerun and post to RSA SPEC file creation

## [1.3.4] - 2013-09-12

- Added post install script for RSA Solaris package

## [1.3.3] - 2013-09-12

- Improved RSA package creation on Solaris

## [1.3.2] - 2013-09-12

- Updated SPEC file creation

## [1.3.1] - 2013-09-11

- Fixed package creation for RSA

## [1.3.0] - 2013-09-11

- Added sdconf.rec and sd_pam.conf to RSA package

## [1.2.9] - 2013-09-11

- Added support for creating RSA SecurID PAM package

## [1.2.8] - 2013-03-07

- Added support for multiple dependancies

## [1.2.7] - 2013-03-07

- Added package dependancies

## [1.2.6] - 2013-03-07

- Improved source version detection

## [1.2.5] - 2013-03-06

- Fixed id resolution

## [1.2.4] - 2013-03-06

- Replaced tar with gtar to fix checksum errors

## [1.2.3] - 2013-03-06

- Updated wget

## [1.2.2] - 2013-03-06

- Added HPN ssh support

## [1.2.1] - 2013-03-06

- Fixed Configure flag

## [1.2.0] - 2013-03-06

- Fixed OpenSSH

## [1.1.9] - 2013-03-05

- Updated OpenSSL to 1.0.1e

## [1.1.8] - 2013-03-05

- Added zlib

## [1.1.7] - 2013-03-05

- Added additional version detection code

## [1.1.6] - 2013-03-05

- Added GNU patch

## [1.1.5] - 2013-02-24

- Fixed bash-syslog RPM creatch

## [1.1.4] - 2013-02-23

- Cleaned up debug mode code

## [1.1.3] - 2013-02-23

- Added support for bash syslog rpm

## [1.1.2] - 2013-02-22

- Added support for john rpm

## [1.1.1] - 2013-02-22

- Initial Linux support

## [1.1.0] - 2013-02-10

- Updated package naming

## [1.0.9] - 2013-02-10

- Added support for john

## [1.0.8] - 2013-01-30

- Added code to download source and fixed openssl compilation

## [1.0.7] - 2013-01-30

- Added support for openssh and openssl

## [1.0.6] - 2013-01-29

- Added support for wget and perl

## [1.0.5] - 2013-01-28

- Added server manifest for orcallator

## [1.0.4] - 2013-01-27

- Added postinstall and preremove scripts for setoolkit and orca

## [1.0.3] - 2013-01-27

- A lot of updates including using DESTDIR

## [1.0.2] - 2013-01-22

- Fixed error with code

## [1.0.1] - 2012-11-13

- Cleaned up code

## [1.0.0] - 2012-11-13

- Initial commit to github
