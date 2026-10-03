![BURST](https://raw.githubusercontent.com/lateralblast/burst/master/burst.jpg)

# BURST

Build Unaided Rapid Source Tool

## Introduction

A packaging tool for Solaris (PKG and IPS) and Linux (RPM).

BURST builds a package from a source tarball. It will try to guess the package name and version from the tarball name.

## Status

> [!WARNING]
> Versions 1.4.4 to 1.7.5 contain a large number of bug fixes and robustness changes that have **not been tested**.
> They were made by reviewing the code. Only syntax checks (`perl -c`) and a few isolated checks were run, with no real builds on Solaris or Linux.

Please test before relying on it, especially:

- Solaris PKG and IPS builds, including publishing to a repository (`-P`)
- RPM builds on Linux, including the generated spec file scriptlets for `bsl` and `rsa`
- Source download and version detection from the `sources` file
- The new option validation, which rejects paths and names containing spaces or shell characters
- The new failure handling, which stops the script when a build or packaging command fails

If something that used to work now fails, check [CHANGELOG.md](CHANGELOG.md) for what changed and please report it.

## License

This software is licensed under CC BY-NC-SA 4.0 (Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International).
See the [LICENSE](LICENSE) file or <https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode>.

## Usage

```
burst -[BPa:b:c:d:e:f:i:l:n:p:r:s:u:v:w:hCD:R:V]

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
-D: Verbose output (debug), also written to the given log file
-d: Package description (used as the RPM summary)
-f: Source URL (used as the RPM Source0)
-l: License (default is GPL)
-r: OS release (eg 10 for Solaris 10, default is detected)
-u: Project URL (used as the RPM URL)
-v: Source version
-C: Check the environment and exit
-V: Display script version
-B: Create a package from a binary install (eg SecurID PAM Agent)
-P: Publish IPS to a repository (default is /export/repo/burst)
-R: Repository path or URL (required to publish IPS to a specific repository)
```

## Features

### Sources file

If the source URL is in the `sources` file, BURST will determine the information it needs, such as the package version, from the URL.
The `sources` file is read from the script directory first, then the current directory.

An example `sources` file entry:

```
$ cat sources
http://ftp.gnu.org/gnu/patch/patch-2.7.1.tar.gz
```

If the package has a valid entry in the `sources` file, all that is needed is the package name, eg:

```
$ burst -n patch
```

### IPS repository

If the script is run on Solaris 11 it can create an IPS repository and publish packages into it, eg:

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

## Example

Create a setoolkit package, let the script determine the version information, and set the package name to PKGse:

```
$ burst -w /tmp/burst -s /tmp/setoolkit-3.5.1.tar -p PKGse
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Support development

If you find this tool useful, you can help support its development:

[![Support on Ko-fi](https://img.shields.io/badge/Ko--fi-Support%20development-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/richardatlateralblast)

Fund me here: <https://ko-fi.com/richardatlateralblast>
