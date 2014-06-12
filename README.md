![alt tag](https://raw.githubusercontent.com/lateralblast/burst/master/burst.jpg)

BURST
=====

Build Unaided Rapid Source Tool

Introduction
------------

A Packaging tool for Solaris (PKG and IPS) and Linux (RPMs).

The script will try to guess the package name and version information from the source tar ball name.

License
-------

This software is licensed as CC-BA (Creative Commons By Attrbution)

http://creativecommons.org/licenses/by/4.0/legalcode

Usage
-----

```
$	burst -[BPa:b:c:d:e:f:i:l:n:p:r:s:u:v:w:hCD:R:V]

-h: Display help
-w: Working (base) directory
-n: Source name
-p: Package name
-s: Source file
-a: Architecture (eg sparc)
-b: Base package name (eg SUNW)
-c: Category (default is application)
-e: Email address of package maintainer
-i: Install base dir (eg /usr/local)
-D: Verbose output (debug)
-B: Create a package from a binary install (eg SecurID PAM Agent)
-P: Publih IPS to a repository (default is /export/repo/burst)
-R: Repository URL (required to publish IPS to a specific repository)
```

Features
--------

If the source URL is in the sources file, it will automatically try to determine all the information required like the package version.

An example sources file entry:

```
$ cat sources
http://ftp.gnu.org/gnu/patch/patch-2.7.1.tar.gz
```

If the package is in the sources file and has a valid entry the script will determine the information from the source URL,
so all that needs to be done is use the package name, eg:

```
$ burst -n patch
```

If the script is run on Solaris 11 it can automatically create an IPS repository and publish the packages into that repository, eg:

```
# burst -n facter -P
Setting package install directory to: /usr/local
Setting Work directory to: /tmp/burst
Setting package version to 1.6.17
Found ruby installer
Removing contents of /tmp/burst/ins
Removing contents of /tmp/burst/spool
pkg://burst/application/facter@1.6.17,1.0:20131224T223518Z
PUBLISHED

# pkg info -g /export/repo/burst -r facter
          Name: application/facter
       Summary: facter 1.6.17
   Description: facter
      Category: Applications/System Utilities
         State: Not installed
     Publisher: burst
       Version: 1.6.17
 Build Release: 1.0
        Branch: None
Packaging Date: December 24, 2013 10:35:18 PM
          Size: 143.96 kB
          FMRI: pkg://burst/application/facter@1.6.17,1.0:20131224T223518Z
```

Example
-------

Create a setoolkit package, let script determine version information, and set package name to PKGse:

```
$ burst -d /tmp/burst -s /tmp/setoolkit-3.5.1.tar -p PKGse
```

