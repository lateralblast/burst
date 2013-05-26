burst
=====

A Packaging tool for Solaris and Linux (RPMs).

The script will try to guess the package name and version information from the source tar ball name.

Usage
-----

    burst [-w WORK_DIR] [-n SRC_PKG_NAME] [-p SOL_PKG_NAME] [-v PKG_VER] [-h]

    -h: Display help
    -w: Working (base) directory
    -p: Package name
    -s: Source file
    -a: Architecture (eg sparc)
    -b: Base package name (eg SUNW)
    -c: Category (default is application)
    -e: Email address of package maintainer
    -i: Install base dir (eg /usr/local)
    -D: Verbose output (debug)

Example
-------
  
Create a setoolkit package, let script determine version information, and set package name to PKGse:
  
    burst -d /tmp/burst -s /tmp/setoolkit-3.5.1.tar -p PKGse;

