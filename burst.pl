#!/usr/bin/perl
use strict;
use Getopt::Std;
use File::Basename;

# Name:         burst (Build Unaided Rules Source Tool)
# Version:      1.3.0
# Release:      1
# License:      Open Source
# Group:        System
# Source:       N/A
# URL:          http://lateralblast.com.au/
# Distribution: Solaris
# Vendor:       UNIX
# Packager:     Richard Spindler <richard@lateralblast.com.au>
# Description:  Solaris package creation tool

# Changes       1.0.0 Tuesday, 13 November 2012  3:50:45 AM EST
#               Initial commit to github
#               1.0.1 Tue 13 Nov 2012 14:43:13 EST
#               Cleaned up code
#               1.0.2 Tue Jan 22 15:28:41 EST 2013
#               Fixed error with code
#               1.0.3 Sun Jan 27 14:32:51 EST 2013
#               A lot of updates including using DESTDIR
#               1.0.4 Sun Jan 27 15:19:05 EST 2013
#               Added postinstall and preremove scripts for setoolkit and orca
#               1.0.5 Mon Jan 28 18:20:42 EST 2013
#               Added server manifest for orcallator
#               1.0.6 Tue 29 Jan 2013 21:32:41 EST
#               Added support for wget and perl
#               1.0.7 Wed Jan 30 08:15:38 EST 2013
#               Added support for openssh and openssl
#               1.0.8 Wed Jan 30 17:53:27 EST 2013
#               Added code to download source and fixed openssl compilation
#               1.0.9 Sun Feb 10 14:58:12 EST 2013
#               Added support for john
#               1.1.0 Sun Feb 10 15:04:52 EST 2013
#               Updated package naming
#               1.1.1 Fri 22 Feb 2013 11:58:24 EST
#               Initial Linux support
#               1.1.2 Fri Feb 22 15:04:22 EST 2013
#               Added support for john rpm
#               1.1.3 Sat Feb 23 10:44:33 EST 2013
#               Added support for bash syslog rpm
#               1.1.4 Sat Feb 23 17:01:18 EST 2013
#               Cleaned up debug mode code
#               1.1.5 Sun Feb 24 14:03:28 EST 2013
#               Fixed bash-syslog RPM creatch
#               1.1.6 Tuesday,  5 March 2013  7:59:10 PM EST
#               Added GNU patch
#               1.1.7 Tuesday,  5 March 2013  8:54:22 PM EST
#               Added additional version detection code
#               1.1.8 Tuesday,  5 March 2013 10:50:02 PM EST
#               Added zlib
#               1.1.9 Tuesday,  5 March 2013 11:04:24 PM EST
#               Updated OpenSSL to 1.0.1e
#               1.2.0 Wednesday,  6 March 2013 12:07:31 AM EST
#               Fixed OpenSSH
#               1.2.1 Wednesday,  6 March 2013 12:20:27 AM EST
#               Fixed Configure flag
#               1.2.2 Wednesday,  6 March 2013 12:55:23 AM EST
#               Added HPN ssh support
#               1.2.3 Wed  6 Mar 2013 16:11:45 EST
#               Updated wget
#               1.2.4 Wed  6 Mar 2013 16:30:27 EST
#               Replaced tar with gtar to fix checksum errors
#               1.2.5 Wed  6 Mar 2013 17:53:30 EST
#               Fixed id resolution
#               1.2.6 Thu  7 Mar 2013 08:55:33 EST
#               Improved source version detection
#               1.2.7 Thu  7 Mar 2013 10:23:05 EST
#               Added package dependancies
#               1.2.8 Thu  7 Mar 2013 15:48:03 EST
#               Added support for multiple dependancies
#               1.2.9 Wed 11 Sep 2013 13:42:29 EST
#               Added support for creating RSA SecurID PAM package 
#               1.3.0 Wed 11 Sep 2013 14:03:52 EST
#               Added sdconf.rec and sd_pam.conf to RSA package

# This script creates solaris packages from a source package or directory (TBD)
# Source packages are fetched into a source directory, unpacked, compiled
# and installed into a temporary directory. Then a solaris package is created
#
# Special non standard packages:
# bsl           - bash with syslog support
#
# The script creates the following working directories:
# BASE/src      - Where the source tar is put or copied to and unpacked
# BASE/ins      - Where the package is installed into
# BASE/spool    - Where the package is spooled into
# BASE/trans    - Where the spool is transformed into a package
# BASE/pkg      - Where the filnal package is put
# BASE/scripts  - Where package scripts can be placed
#
# The script will check in BASE/scripts for PACKAGENAME.SCRIPT
# Where PACKAGENAME is the name of the package, eg orca
# and SCRIPT is the name of the script, eg preinstall, postinstall
# preremove, etc
#
# If the package name and version are not given it will try to determine
# them from the source file name, and vice versa, if no source name is 
# give it will try to determine the source file name from the given
# version and name and see if it is present in the BASE/src directory
#
# For example if given:
# -n setoolkit -v 3.5.1
# The script will look for setoolkit-3.5.1.[tar,tar.gz,tgz,bz2,etc] in BASE/src
#
# For example if given:
# -s setoolkit-3.5.1.[tar,tar.gz,tgz]
# The script will determine the package name is setoolkit 
# and the version is 3.5.1
#
# Similarly if not given a Solaris package name (-p switch) the script
# will deduce the Solaris Package name from the source name
# for example setoolkit will be packages as OSSsetoolkit 
# If the release of the OS the package is being built on is less than 5.9
# the package name will be truncated to 7 letters so it is compatible
#
# This script will try to make use of the make DESTDIR command to install
# into an alternate directory so a package can be created, but not affect
# the configure script
#
# If the package does not support DESTDIR then you will need to add special
# handling, eg post handling of the Makefile
#

# If you want HPN patch applied set this variable to 1
my $hpnssh=1;

# Set directory owner user and group
# Default for /usr seems to be root:sys

my $dir_user="root";
my $dir_group="sys";
my $user_name;

my $script_name="burst";
my %option=();
my $source_file_name;
my $source_dir_name;
my $tar_dir_name;
my $maintainer_email="richard\@lateralblast.com.au";
my $top_install_dir="/usr/local";
my $pkg_base_name="LTRL";
my $real_install_dir;
my $work_dir="";
my $cc_bin=`which gcc`;
my $vendor_string="Lateral Blast";
my $log_file;
my $os_name=`uname`;
my $os_arch=`uname -p`;
my $options="Ba:b:c:d:e:f:i:l:n:p:r:s:u:v:w:hCD:V";

if ($#ARGV == -1) {
  print_usage();
}
else {
  getopts($options,\%option);
}

# IF given -h print help

if ($option{'h'}) {
  print_usage();
  exit;
}

if ($option{'C'}) {
  check_env();
  exit;
}

if ($option{'D'}) {
  $log_file=$option{'D'};
  if (-e "$log_file") {
    system("rm $log_file");
    system("touch $log_file");
  }
  open LOG_FILE,">$log_file";
}

if ($option{'V'}) {
  print_version();
  exit;
}

sub print_usage {
  print "\n";
  print "Usage:\n";
  print "$script_name -[$options]\n"; 
  print "\n";
  print "-h: Display help\n";
  print "-w: Working (base) directory\n"; 
  print "-n: Source name\n";
  print "-p: Package name\n";
  print "-s: Source file\n";
  print "-a: Architecture (eg sparc)\n";
  print "-b: Base package name (eg SUNW)\n";
  print "-c: Category (default is application)\n";
  print "-e: Email address of package maintainer\n";
  print "-i: Install base dir (eg /usr/local)\n";
  print "-D: Verbose output (debug)\n";
  print "-B: Create a package from a binary install (eg SecurID PAM Agent)\n";
  print "\n";
  print "Example:\n";
  print "$script_name -d /tmp/$script_name -s /tmp/setoolkit-3.5.1.tar -p $pkg_base_name";
  print "\n";
  #print "\n";
  return;
}

sub print_version {
  my $script_version=get_script_version();
  print "$script_version\n"
}

sub get_script_version {
  my $script_version=`cat $0 |grep '^# Version' |awk '{print \$3}'`;
  chomp($script_version);
  return($script_version);
}

# Call the functions to build a package

check_env();
if ($os_name=~/SunOS/) {
	if (!$option{'B'}) {
	  extract_source();
		compile_source();
	}
  create_spool();
  create_trans();
  create_pkg();
}
if ($os_name=~/Linux/) {
  create_spec();
  create_rpm();
}

# Function: check_env
# This function checks that enough detail has been given to build a package
# As previously discussed it will try to determine package name and version
# from the name of the source file if those have not been given explicitly
# This code needs cleaning up

sub check_env {

  my $home_dir=`echo \$HOME`;
  my @dir_names; 
  my $dir_name;
  my $pam_lib;

  chomp($cc_bin);
  chomp($home_dir);
  if ($os_name=~/SunOS/) {
    if ($cc_bin!~/cc/) {
      if (-e "/usr/local/bin/gcc") {
        $cc_bin="/usr/local/bin/gcc";
      }
      else {
        if (-e "/usr/sfw/bin/gcc") {
          $cc_bin="/usr/sfw/bin/gcc";
        }
        else {
          if (-e "/opt/sfw/bin/gcc") {
            $cc_bin="/opt/sfw/bin/gcc";
          }
        }
      }
    }
    @dir_names=('src','ins','spool','trans','pkg','scripts');
  }
  if (!$option{'l'}) {
    # If no license information assume GPL
    $option{'l'}="GPL";
  }
  if ($os_name=~/Linux/) {
    @dir_names=('SOURCES','RPMS','SRPMS','SPECS','BUILD');
  }
  if (!$option{'e'}) {
    $option{'e'}=$maintainer_email;
  }
  if (!$option{'i'}) {
    # If real_install_dir not set at top of script, set it
    if ($real_install_dir!~/[a-z]/) {
      $real_install_dir=$top_install_dir;
    }
  }
  else {
    # if -i used, set real_install_dir from command line
    $real_install_dir=$option{'i'};
  }
	if ($option{'B'}) {
		$real_install_dir="/";
	}
  print "Setting package install directory to: $real_install_dir\n";
  if (!$option{'a'}) {
    # If the architecture is not specified, get it
    $option{'a'}=`uname -p`;
    chomp($option{'a'});
  }
  if (!$option{'r'}) {
    # If the OS version is not specified, get it
    if ($os_name=~/SunOS/) {
      $option{'r'}=`uname -r |cut -f2 -d"."`;
    }
    if ($os_name=~/Linux/) {
      if ( -e "/etc/redhat-release" ) {
        $option{'r'}=`cat /etc/redhat-release |awk '{print \$3}'`
      }
    }
    chomp($option{'r'});
  }
  if (!$option{'c'}) {
    # IF category not set, set it
    $option{'c'}="Application";
  }
  if (!$option{'b'}) {
    if ($pkg_base_name!~/[A-z]/) {
      print "Package base name (eg SUNW) not set\n";
      exit;
    }
  }
  else {
    $pkg_base_name=$option{'b'};
  }
  if (!$option{'i'}) {
    # If real_install_dir not set at top of script, set it
    if ($real_install_dir!~/[a-z]/) {
      $real_install_dir=$top_install_dir;
    }
  }
  else {
    # if -i used, set real_install_dir from command line
    $real_install_dir=$option{'i'};
  }
  print "Setting package base name to $pkg_base_name\n";
  if (!$option{'w'}) {
    if ($work_dir!~/[a-z]/) {
      # If the work directory has not been given via -w
      # and has not been set at the top of the script
      # set it to tmp under the users home directory
      if ($os_name=~/SunOS/) {
        $user_name=`id |awk '{print \$1}' |cut -f2 -d"(" |cut -f1 -d")"`;
        chomp($user_name);
        if ($user_name=~/root/) {
          # If root user, use /tmp
          # It's not recommended to run this as root
          $work_dir="/tmp/$script_name";
        }
        else {
          if ($os_name=~/SunOS/) {
            $work_dir="$home_dir/$script_name";
          }
        }
      }
      else {
        if ($os_name=~/Linux/) {
          $work_dir="$home_dir/rpmbuild"
        }
      }
    }
  }
  else {
    # If given -w set work_dir from command line
    $work_dir=$option{'w'};
  }
  print "Setting Work directory to: $work_dir\n";
  foreach $dir_name (@dir_names) {
    if (! -e "$work_dir/$dir_name") {
      print "Creating directory $work_dir/$dir_name...\n";
      system("mkdir -p $work_dir/$dir_name");
    }
  }
  if (!$option{'s'}) {
		if ($option{'n'}=~/rsa/) {
			if ($os_name=~/SunOS/) {
				$pam_lib="/usr/lib/security/sparcv9/pam_securid.so";
				if (! -e "$pam_lib") {
					print "RSA SecurID PAM Agent is not installed\n";
					print "Install agent and re-run script\n";
					exit;
				}
				else {
					$option{'v'}=`strings $pam_lib |grep 'API Version' |awk '{print \$5"."\$6"."\$7}'`;
					chomp($option{'v'});
					$option{'v'}=~s/ //g;
					$option{'v'}=~s/_/./g;
					$option{'v'}=~s/\[//g;
					$option{'v'}=~s/\]//g;
				}
			}
		}
    if (($option{'n'})&&(!$option{'v'})) {
      get_source_version();
      determine_source_file_name();
    }
    if ((!$option{'n'})||(!$option{'v'})) {
      # If the source file, version and name have not been given 
      # exit as there is not enough information to continue
      if (!$option{'C'}) {
        print "You must either specify the source file and/or the package name and version\n";
      }
      exit;
    }
    else {
      # If not given a source file name, try to determine it
      # from other information given, eg -n and -v
      # If the source file does not exist then exit
			if (!$option{'B'}) {
	      determine_source_file_name();
	      if ($option{'s'}!~/[0-9]/) {
	        exit;
	      }
			}
			else {
				if (!$option{'c'}) {
					$option{'c'}="Application";
				}
			}
    }
 	} 
  else {
    if (!-e "$option{'s'}") {
			
      # If the source file given via -s does not exist
      # then try to guess it via -v and -n
      # If the source file does not exist then exit
      if (($option{'n'})&&($option{'v'})) {
        determine_source_file_name();
        if ($option{'s'}!~/[0-9]/) {
          exit;
        }
      }
      else {
        print "Source file $option{'s'} does not exist\n";
        exit;
      }
    }
    else {
      if ((!$option{'n'})||(!$option{'v'})) {
        ($source_file_name,$source_dir_name)=fileparse($option{'s'});
        if ($source_file_name!~/\-/) {
          if ((!$option{'p'})||(!$option{'v'})) {
            print "Sourcefile $source_file_name does not appear a standardly named source file and the name and version have not been given\n"; 
            exit;
          }
        }
        else {
          ($option{'n'},$option{'v'})=split('\-',$source_file_name);
          $option{'v'}=~s/\.tar\.gz//g;
          $option{'v'}=~s/\.tar//g;
          $option{'v'}=~s/\.tgz//g;
        }
      }
    }
    ($source_file_name,$source_dir_name)=fileparse($option{'s'});
    if (!-e "$work_dir/src/$source_file_name") {
      system("cp $option{'s'} $work_dir/src/$source_file_name");
    }
    $option{'s'}="$work_dir/src/$source_file_name";
  }
  if ((!$option{'n'})||(!$option{'v'})) {
    ($source_file_name,$source_dir_name)=fileparse($option{'s'});
    if ($source_file_name!~/\-/) {
      if ((!$option{'p'})||(!$option{'v'})) {
        print "Sourcefile $source_file_name does not appear a standardly named source file and the name and version have not been given\n"; 
        exit;
      }
    }
    else {
			if (!$option{'B'}) {
	      ($option{'n'},$option{'v'})=split('\-',$source_file_name);
	      $option{'v'}=~s/\.tar\.gz//g;
	      $option{'v'}=~s/\.tar//g;
	      $option{'v'}=~s/\.tgz//g;
			}
    }
  }
  if (!$option{'p'}) {
    $option{'p'}="$pkg_base_name$option{'n'}";
  }
  if ($os_name=~/SunOS/) {
    # Fix package name to it is something sensible
    if ($option{'n'}=~/openssl|openssh/) {
      $option{'p'}=~s/open//;
    }
    if ($option{'n'}=~/rubygems/) {
      $option{'p'}=~s/ruby//;
    }
    if ($option{'r'}=~/6|7|8|9/) {
      if (length($option{'p'}) > 7) {
        $option{'p'}=substr($option{'p'},0,7);
      }
    }
  }
  print_debug("","short");
  print_debug("Work dir:       $work_dir","short");
	if (!$option{'B'}) {
  	print_debug("Source file:    $option{'s'}","short");
  	print_debug("Source name:    $option{'n'}","short");
	  print_debug("Source version: $option{'v'}","short");
	}
  print_debug("Package name:   $option{'p'}","short");
  if (!$option{'e'}) {
    if ($maintainer_email!~/[a-z]/) {
      $option{'e'}="";
    }
  }
  check_deps();
  return;
}

sub remove_extensions {
  my @extensions; 
  my $counter=0;
  my $file_name=$_[0];
  my $extension;
  
  $extensions[$counter]=".tgz"; $counter++;
  $extensions[$counter]=".tar.gz"; $counter++;
  $extensions[$counter]=".tar.bz2"; $counter++;
  $extensions[$counter]=".tbz2"; $counter++;
  $extensions[$counter]=".tar"; $counter++;
  foreach $extension (@extensions) {
    $file_name=~s/$extension//g;
  }
  return($file_name);
}

sub determine_source_file_name {

  my @extensions; 
  my $record; 
  my $counter;
  my $file_name_base; 
  my $src_dir;

  if ($os_name=~/SunOS/) {
    $src_dir="$work_dir/src";
  }
  if ($os_name=~/Linux/) {
    $src_dir="$work_dir/SOURCES"
  }
  $file_name_base="$src_dir/$option{'n'}-$option{'v'}";

  $extensions[0]="tar";
  $extensions[1]="tgz";
  $extensions[2]="tar.gz";
  $extensions[3]="tar.bz2";
  $extensions[4]="tbz2";
  if ($option{'n'}=~/bsl/) {
    # Add handling for bash with syslog support
    $file_name_base=~s/bsl/bash/g;
  }
  if ($option{'n'}=~/orca/) {
    # Add handling for orca snapshots
    if ($option{'v'}!~/0\.2/) {
      $file_name_base=~s/orca-/orca-snapshot-r/g;
    }
  }
  for ($counter=0; $counter<@extensions; $counter++) {
    if ($option{"D"}) {
      print "Seeing if $file_name_base.$extensions[$counter] exists\n"; 
    }
    if (-e "$file_name_base.$extensions[$counter]") {
      $option{'s'}="$file_name_base.$extensions[$counter]";
      return;
    }
  }
  print "Source file not found\n";
  print "Attempting to fetch source\n";
  get_source_file();
  determine_source_file_name();
  return;
}

sub check_deps {
  my @dep_list; 
  my $counter=0;
  my $record; 
  my $dep; 
  my $package;
  my $pkg_check; 
  my @new_dep_list;
  
  $dep_list[$counter]="ruby,yaml:readline:libffi"; $counter++;
  $dep_list[$counter]="ssh,ssl"; $counter++;
  
  foreach $record (@dep_list) {
    ($package,$dep)=split(",",$record);
    if ($option{'n'}=~/$package/) {
      if ($dep=~/:/) {
        @new_dep_list=split(/:/,$dep);
        foreach $dep (@new_dep_list) {
          $dep="$pkg_base_name$dep";
          if ($os_name=~/SunOS/) {
            $pkg_check=`pkginfo -l $dep |grep PKGINST |awk '{print \$2}'`;
            if ($pkg_check!~/$pkg_base_name/) {
              print "Required package $dep not installed.\n";
              exit;
            }
          }
        }
      }
      else {
        $dep="$pkg_base_name$dep";
        if ($os_name=~/SunOS/) {
          $pkg_check=`pkginfo -l $dep |grep PKGINST |awk '{print \$2}'`;
          if ($pkg_check!~/$pkg_base_name/) {
            print "Required package $dep not installed.\n";
            exit;
          }
        }
      }
    }
  }

}

sub populate_source_list {
  
  my @source_list; 
  my $counter=0;
  my $package_name=$option{'n'};

  if ($package_name=~/bsl/) {
    $package_name="bash";
  }
  $source_list[$counter]="http://mirror.internode.on.net/pub/OpenBSD/OpenSSH/portable/openssh-6.1p1.tar.gz"; $counter++;
  $source_list[$counter]="http://www.openssl.org/source/openssl-1.0.1e.tar.gz"; $counter++;
  $source_list[$counter]="http://www.orcaware.com/orca/pub/snapshots/orca-snapshot-r557.tar.bz2"; $counter++;
  $source_list[$counter]="http://downloads.sourceforge.net/project/setoolkit/SE%20Toolkit/SE%20Toolkit%203.5.1/setoolkit-3.5.1.tar.gz"; $counter++;
  $source_list[$counter]="http://www.cpan.org/src/5.0/perl-5.16.2.tar.gz"; $counter++;
  $source_list[$counter]="ftp://ftp.gnu.org/gnu/bash/bash-4.2.tar.gz"; $counter++;
  $source_list[$counter]="http://www.openwall.com/john/g/john-1.7.9.tar.gz"; $counter++;
  $source_list[$counter]="http://ftp.gnu.org/gnu/patch/patch-2.7.1.tar.gz"; $counter++;
  $source_list[$counter]="http://ftp.gnu.org/gnu/diffutils/diffutils-3.2.tar.gz"; $counter++;
  $source_list[$counter]="http://zlib.net/zlib-1.2.7.tar.gz"; $counter++;
  $source_list[$counter]="http://www.sudo.ws/sudo/dist/sudo-1.8.6p7.tar.gz"; $counter++;
  $source_list[$counter]="ftp://ftp.gnu.org/gnu/wget/wget-1.14.tar.gz"; $counter++;
  $source_list[$counter]="ftp://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.3-p392.tar.bz2"; $counter++;
  $source_list[$counter]="http://production.cf.rubygems.org/rubygems/rubygems-2.0.2.tgz"; $counter++;
  $source_list[$counter]="http://pyyaml.org/download/libyaml/yaml-0.1.4.tar.gz"; $counter++;
  $source_list[$counter]="ftp://ftp.gnu.org/gnu/readline/readline-6.2.tar.gz"; $counter++;
  $source_list[$counter]="ftp://ftp.gnu.org/gnu/gdbm/gdbm-1.10.tar.gz"; $counter++;
  $source_list[$counter]="http://downloads.puppetlabs.com/puppet/puppet-3.1.0.tar.gz"; $counter++;
  $source_list[$counter]="http://downloads.puppetlabs.com/facter/facter-1.6.17.tar.gz"; $counter++;
  $source_list[$counter]="ftp://sourceware.org/pub/libffi/libffi-3.0.12.tar.gz"; $counter++;
  #$source_list[$counter]=""; $counter++;

  return @source_list;
}

sub get_source_version {
  
  my @source_list; 
  my $counter=0;
  my $source_url; 
  my $header;

  @source_list=populate_source_list();
  foreach $source_url (@source_list) {
    if ($source_url=~/$option{'n'}/) {
      $header=basename($source_url);
      ($header,$option{'v'})=split("$option{'n'}-",$header);
      $option{'v'}=remove_extensions($option{'v'});
      print "Setting package version to $option{'v'}\n";
      return;
    }
  }
  return;
}

sub get_source_file {
  
  my @source_list; 
  my $counter=0;
  my $source_url; 
  my $command; 
  my $src_dir; 
  my $wget_test;
  
  if ($os_name=~/SunOS/) {
    $src_dir="$work_dir/src";
  }
  if ($os_name=~/Linux/) {
    $src_dir="$work_dir/SOURCES"
  } 
  @source_list=populate_source_list();
  foreach $source_url (@source_list) {
    if ($source_url=~/$option{'n'}-$option{'v'}/) {
      $wget_test=`which wget`;
      if ($wget_test!~/no wget/) {
        $command="cd $src_dir ; wget $source_url";
        print_debug("Executing: $command","long");
        system("$command");
      }
      else {
        print "No wget found\n";
      }
    }
  }
  return;
}

sub extract_source {

  my $file_type; 
  my $command;
  
  determine_source_dir_name();
  
  if ($source_dir_name!~/src\/$/) {
    $command="rm -rf $source_dir_name";
    print_debug("Executing: $command","long");
    system("$command");
  }
  if (-e "$option{'s'}") {
    $file_type=`file $option{'s'}`;
    chomp($file_type);
    if ($file_type=~/USTAR tar archive/) {
      $command="cd $work_dir/src ; /usr/sfw/bin/gtar -xf $option{'s'}";
    }
    if ($file_type=~/gzip compressed data/) {
      $command="cd $work_dir/src ; gzcat $option{'s'} | /usr/sfw/bin/gtar -xf -";
    }
    if ($file_type=~/bzip2 compressed data/) {
      $command="cd $work_dir/src ; bzcat $option{'s'} | /usr/sfw/bin/gtar -xf -";
    }
    system("$command");
    print_debug("Executing: $command","long");
  }
  else {
    print "Source file $option{'s'} does not exist\n";
    exit;
  }
  return;
}

sub determine_source_dir_name {

  my $dir_name=`/usr/sfw/bin/gtar -tf $option{'s'} |head -1`;
  my @values=split("/",$dir_name);
  my $conf_string;

  $source_dir_name="$work_dir/src/$values[0]";
  chomp($source_dir_name);
  return;
}

sub search_conf_list {

  my @commands; 
  my $counter=0;
  my $command; 
  my $record;
  my $package; 
  my $conf_string;
  
  $commands[$counter]="wget,CC=\"cc\" ; export CC ; ./configure --prefix=$real_install_dir --with-ssl=openssl --with-libssl-prefix=$real_install_dir"; $counter++;
  $commands[$counter]="openssl,CC=\"cc\" ; export CC ; ./Configure --prefix=$real_install_dir --openssldir=$real_install_dir zlib-dynamic threads shared solaris-x86-cc"; $counter++;
  $commands[$counter]="sudo,CC=\"cc\" ; export CC ; ./configure --prefix=$real_install_dir --enable-pam"; $counter++;
  if ($os_name=~/SunOS/) {
    if ($option{'n'}=~/orca|setoolkit/) {
      if ($option{'n'}=~/orca/) {
        $conf_string="--prefix=$real_install_dir --with-rrd-dir=/var/orca/rrd --with-html-dir=/var/orca/html --with-var-dir=/var/orca --build=$option{'a'}-sun-solaris2.$option{'r'} --radius_db=off";
        $commands[$counter]="orca,ORCA_CONFIGURE_COMMAND_LINE=\"$conf_string\" ; export ORCA_CONFIGURE_COMMAND_LINE ; PATH=\"\$PATH:/usr/ccs/bin\" ; export PATH ; CC=\"$cc_bin\" ; export CC ; ./configure $conf_string"; $counter++;
      }
      if ($option{'n'}=~/setoolkit/) {
        $commands[$counter]="setoolkit,CC=\"CC\" ; export CC ; ./configure --prefix=$real_install_dir --with-se-include-dir=$real_install_dir/include --with-se-examples-dir=$real_install_dir/examples"; $counter++;
      }
    }
    $commands[$counter]="perl,CC=\"gcc\" ; export CC ; ./Configure -des -Dusethreads -Dcc=\"gcc -m32\" -Dprefix=$real_install_dir -Dusedttrace -Dusefaststdio -Duseshrplib -Dusevfork -Dless=less -Duse64bitall -Duse64bitint -Dpager=more"; $counter++;
    if ($option{'r'}!~/9|10|11/) {
      $commands[$counter]="ssh,CFLAGS=\"\$CFLAGS -I$real_install_dir/include\" ; export CFLAGS ; CC=cc ; export CC ; ./configure --prefix=$real_install_dir --with-zlib --with-solaris-contracts --with-solaris-projects --with-tcp-wrappers=$real_install_dir --with-ssl-dir=$real_install_dir --with-privsep-user=sshd --with-md5-passwords --with-xauth=/usr/openwin/bin/xauth --with-mantype=man --with-pid-dir=/var/run --with-pam --with-audit=bsm --enable-shared"; $counter++;
    }
    else {
      $commands[$counter]="openssh,CFLAGS=\"\$CFLAGS -I$real_install_dir/include -I/usr/sfw/include\" ; export CFLAGS ; CC=cc ; export CC ; ./configure --prefix=$real_install_dir --with-zlib --with-solaris-contracts --with-solaris-projects --with-tcp-wrappers=/usr/sfw --with-ssl-dir=$real_install_dir --with-privsep-user=sshd --with-md5-passwords --with-xauth=/usr/openwin/bin/xauth --with-mantype=man --with-pid-dir=/var/run --with-pam --with-audit=bsm --enable-shared"; $counter++;
    }
    $commands[$counter]="ruby,CC=cc ; export CC ; ./configure --prefix=$real_install_dir --enable-shared"
  }
  foreach $command (@commands) {
    ($package,$command)=split(",",$command);
    if ($package=~/^$option{'n'}$/) {
      return($command);
    }
  }
  $command="LD_LIBRARY_PATH=\"\$LD_LIBRARY_PATH:$real_install_dir/lib\" ; export LD_LIBRARY_PATH; CFLAGS=\"\$CFLAGS -I$real_install_dir/include\" ; export CFLAGS ; CC=cc ; export CC ; ./configure --prefix=$real_install_dir --enable-shared";
  return($command);
}

sub compile_source {

  my @commands; 
  my $command;
  my $ins_dir="$work_dir/ins";
  my $src_dir="$work_dir/src";
  my $conf_string; 
  my $counter=0;
  my @files; 
  my $file; 
  my $se_version;
  my $ins_pkg_dir="$ins_dir$real_install_dir";
  my $patch_file; 
  my $config_flag=0;
  
  # Reminder:
  # ins_dir = Root of work directory, eg /export/home/user/burst/ins
  # This is the directory that DESTDIR will be give to simulate installing into /
  # ins_pkg_dir is the package specific directory, eg /export/home/user/burst/ins/usr/local
  # This would be used to simulate /use/local under DESTDIR
  # Out of politeness it would be good to direct configs to $ins_pkg_dir/etc (/usr/local/etc)
  # rather than $ins_dir/etc (/etc) so the package keeps things away from the system
  # as much as possible

  determine_source_dir_name();
  if ($option{'n'}=~/openssh/) {
    if ($hpnssh eq 1) {
      $patch_file="$src_dir/openssh-6.1p1-hpn13v14.diff";
      if (! -e "$patch_file") {
        if (-e "$patch_file.gz") {
          system("cd $src_dir ; gzip -d $patch_file.gz");
        }
      }
      if ( -e "$patch_file") {
        $commands[$counter]="gpatch < $patch_file"; $counter++;
      }
      else {
        print "Download HPN patch and put it in $src_dir\n";
        exit;
      }
    }
  }
  $commands[$counter]=search_conf_list(); $counter++;
  if ($option{'n'}=~/bsl/) {
    $commands[$counter]="cp config-top.h config-top.h.orig"; $counter++;
    $commands[$counter]="cat config-top.h.orig |sed 's,/\\* #define SYSLOG_HISTORY \\*/,#define SYSLOG_HISTORY,' > config-top.h"; $counter++;
    $commands[$counter]="rm config-top.h.orig"; $counter++;
  }
  $commands[$counter]="make clean"; $counter++;
  if ($option{'n'}=~/john/) {
    if ($option{'a'}=~/i386/ ) {
      $commands[$counter]="cd src ; make solaris-x86-any-gcc"; $counter++;
    }
    else {
      $commands[$counter]="cd src ; make solaris-sparc-gcc"; $counter++;
    }
  }
  else {
    $commands[$counter]="LD_LIBRARY_PATH=\"\$LD_LIBRARY_PATH:$real_install_dir/lib\" ; export LD_LIBRARY_PATH; CFLAGS=\"\$CFLAGS -I$real_install_dir/include\" ; export CFLAGS ; CC=cc ; export CC ; make all"; $counter++;
  }
  $commands[$counter]="cd $ins_dir ; rm -rf *"; $counter++;
  if ($option{'n'}=~/openssl/) {
    $commands[$counter]="make INSTALL_PREFIX=$ins_dir install"; $counter++;
  }
  else {
    if ($option{'n'}=~/john/) {
      $commands[$counter]="mkdir -p $ins_pkg_dir/bin"; $counter++;
      $commands[$counter]="(cd run ; /usr/sfw/bin/gtar -cpf - . )|(cd $ins_pkg_dir/bin ; /usr/sfw/bin/gtar -xpf - )"; $counter++;
    }
    else {
      $commands[$counter]="make DESTDIR=$ins_dir install"; $counter++;
    }
  }
  if ($option{'n'}=~/setoolkit/) {
    $commands[$counter]="cp $ins_pkg_dir/bin/se $ins_pkg_dir/bin/se.orig"; $counter++;
    $commands[$counter]="cat $ins_pkg_dir/bin/se.orig |sed 's,^ARCH.*,ARCH=\"\",' > $ins_pkg_dir/bin/se"; $counter++;
    $commands[$counter]="rm $ins_pkg_dir/bin/se.orig"; $counter++;
    if ($option{'r'}=~/6/) {
      $se_version="3.2.1"
    }
    if ($option{'r'}=~/7|8/) {
      $se_version="3.3.1"
    }
    if ($option{'r'}=~/9|10/) {
      $se_version="3.4"
    }
    $commands[$counter]="cp $ins_pkg_dir/bin/se $ins_pkg_dir/bin/se.orig"; $counter++;
    $commands[$counter]="cat $ins_pkg_dir/bin/se.orig |sed 's,SEINCLUDE=\"\$TOP\"/include.*,SEINCLUDE=\"\$TOP\"/include:$real_install_dir/lib/SE/$se_version,' > $ins_pkg_dir/bin/se"; $counter++;
    $commands[$counter]="rm $ins_pkg_dir/bin/se.orig"; $counter++;
  }
  if ($option{'n'}=~/openssh/) {
    $commands[$counter]="cp $ins_pkg_dir/etc/sshd_config $ins_pkg_dir/etc/sshd_config.orig"; $counter++;
    $commands[$counter]="cat $ins_pkg_dir/etc/sshd_config.orig |sed 's,^#UsePAM no.*,UsePAM yes,' > $ins_pkg_dir/etc/sshd_config"; $counter++;
    $commands[$counter]="rm $ins_pkg_dir/etc/sshd_config.orig"; $counter++;
  }
  if ($option{'n'}=~/orca/) {
    # If GNU tools are installed the configure script finds them
    # Replace them with the standard tools in the orca scripts
    $commands[$counter]="cp $ins_pkg_dir/bin/start_orca_services $ins_pkg_dir/bin/start_orca_services.orig"; $counter++;
    $commands[$counter]="cat $ins_pkg_dir/bin/start_orca_services.orig |sed 's,^\$CAT=.*,\$CAT=/bin/cat,' > $ins_pkg_dir/bin/start_orca_services"; $counter++;
    $commands[$counter]="rm $ins_pkg_dir/bin/start_orca_services.orig"; $counter++;
    
    $commands[$counter]="cp $ins_pkg_dir/bin/start_orca_services $ins_pkg_dir/bin/start_orca_services.orig"; $counter++;
    $commands[$counter]="cat $ins_pkg_dir/bin/start_orca_services.orig |sed 's,^\$ECHO=.*,\$ECHO=/bin/echo,' > $ins_pkg_dir/bin/start_orca_services"; $counter++;
    $commands[$counter]="rm $ins_pkg_dir/bin/start_orca_services.orig"; $counter++;
     
    $commands[$counter]="cp $ins_pkg_dir/bin/start_orca_services $ins_pkg_dir/bin/start_orca_services.orig"; $counter++;
    $commands[$counter]="cat $ins_pkg_dir/bin/start_orca_services.orig |sed 's,^\$TOUCH=.*,\$TOUCH=/bin/touch,' > $ins_pkg_dir/bin/start_orca_services"; $counter++;
    $commands[$counter]="rm $ins_pkg_dir/bin/start_orca_services.orig"; $counter++; 
    
    # Fix up location of SE
    
    $commands[$counter]="cp $ins_pkg_dir/bin/start_orcallator $ins_pkg_dir/bin/start_orcallator.orig"; $counter++;
    $commands[$counter]="cat $ins_pkg_dir/bin/start_orcallator.orig |sed 's,^SE=.*,SE=$real_install_dir/bin/se,' > $ins_pkg_dir/bin/start_orcallator"; $counter++;
    $commands[$counter]="rm $ins_pkg_dir/bin/start_orcallator.orig"; $counter++;
    
    $commands[$counter]="cp $ins_pkg_dir/bin/start_orcallator $ins_pkg_dir/bin/start_orcallator.orig"; $counter++;
    $commands[$counter]="cat $ins_pkg_dir/bin/start_orcallator.orig |sed 's,\$libdir/orcallator,$real_install_dir/share/setoolkit/orcallator/orcallator,' > $ins_pkg_dir/bin/start_orcallator"; $counter++;
    $commands[$counter]="rm $ins_pkg_dir/bin/start_orcallator.orig"; $counter++;
    
    # Fix configuration files
    
    $commands[$counter]="cp $ins_pkg_dir/etc/orca_services.cfg $ins_pkg_dir/etc/orca_services.cfg.orig"; $counter++;
    $commands[$counter]="cat $ins_pkg_dir/etc/orca_services.cfg.orig |sed 's,$real_install_dir/orca,/var/orca,' > $ins_pkg_dir/etc/orca_services.cfg"; $counter++;
    $commands[$counter]="rm $ins_pkg_dir/etc/orca_services.cfg.orig"; $counter++;
    
    $commands[$counter]="cp $ins_pkg_dir/etc/orca_services.cfg $ins_pkg_dir/etc/orca_services.cfg.orig"; $counter++;
    $commands[$counter]="cat $ins_pkg_dir/etc/orca_services.cfg.orig |sed 's,/var/orca/var,/var/orca,' > $ins_pkg_dir/etc/orca_services.cfg"; $counter++;
    $commands[$counter]="rm $ins_pkg_dir/etc/orca_services.cfg.orig"; $counter++;
    
    $commands[$counter]="cp $ins_pkg_dir/etc/orcallator.cfg $ins_pkg_dir/etc/orcallator.cfg.orig"; $counter++;
    $commands[$counter]="cat $ins_pkg_dir/etc/orcallator.cfg.orig |sed 's,$real_install_dir/orca,/var/orca,' > $ins_pkg_dir/etc/orcallator.cfg"; $counter++;
    $commands[$counter]="rm $ins_pkg_dir/etc/orcallator.cfg.orig"; $counter++;
    
    $commands[$counter]="cp $ins_pkg_dir/etc/orcallator.cfg $ins_pkg_dir/etc/orcallator.cfg.orig"; $counter++;
    $commands[$counter]="cat $ins_pkg_dir/etc/orcallator.cfg.orig |sed 's,/var/orca/var,/var/orca,' > $ins_pkg_dir/etc/orcallator.cfg"; $counter++;
    $commands[$counter]="rm $ins_pkg_dir/etc/orcallator.cfg.orig"; $counter++;
    
    $commands[$counter]="cp $ins_pkg_dir/etc/orcallator.cfg $ins_pkg_dir/etc/orcallator.cfg.orig"; $counter++;
    $commands[$counter]="cat $ins_pkg_dir/etc/orcallator.cfg.orig |sed 's,/orcallator\$,,' > $ins_pkg_dir/etc/orcallator.cfg"; $counter++;
    $commands[$counter]="rm $ins_pkg_dir/etc/orcallator.cfg.orig"; $counter++;
    
    $commands[$counter]="cp $ins_pkg_dir/etc/procallator.cfg $ins_pkg_dir/etc/procallator.cfg.orig"; $counter++;
    $commands[$counter]="cat $ins_pkg_dir/etc/procallator.cfg.orig |sed 's,$real_install_dir/orca,/var,' > $ins_pkg_dir/etc/procallator.cfg"; $counter++;
    $commands[$counter]="rm $ins_pkg_dir/etc/procallator.cfg.orig"; $counter++;
    
    $commands[$counter]="cp $ins_pkg_dir/etc/procallator.cfg $ins_pkg_dir/etc/procallator.cfg.orig"; $counter++;
    $commands[$counter]="cat $ins_pkg_dir/etc/procallator.cfg.orig |sed 's,/var/orca/var,/var/orca,' > $ins_pkg_dir/etc/procallator.cfg"; $counter++;
    $commands[$counter]="rm $ins_pkg_dir/etc/procallator.cfg.orig"; $counter++;
    
    $commands[$counter]="cp $ins_pkg_dir/etc/winallator.cfg $ins_pkg_dir/etc/winallator.cfg.orig"; $counter++;
    $commands[$counter]="cat $ins_pkg_dir/etc/winallator.cfg.orig |sed 's,$real_install_dir/orca,/var,' > $ins_pkg_dir/etc/winallator.cfg"; $counter++;
    $commands[$counter]="rm $ins_pkg_dir/etc/winallator.cfg.orig"; $counter++;
    
    $commands[$counter]="cp $ins_pkg_dir/etc/winallator.cfg $ins_pkg_dir/etc/winallator.cfg.orig"; $counter++;
    $commands[$counter]="cat $ins_pkg_dir/etc/winallator.cfg.orig |sed 's,/var/orca/var,/var/orca,' > $ins_pkg_dir/etc/winallator.cfg"; $counter++;
    $commands[$counter]="rm $ins_pkg_dir/etc/winallator.cfg.orig"; $counter++;
    
    $commands[$counter]="cp $ins_pkg_dir/bin/orca_services_running $ins_pkg_dir/bin/orca_services_running.orig"; $counter++;
    $commands[$counter]="cat $ins_pkg_dir/bin/orca_services_running.orig |sed 's,$real_install_dir/orca/var,/var/orca,' > $ins_pkg_dir/bin/orca_services_running"; $counter++;
    $commands[$counter]="rm $ins_pkg_dir/bin/orca_services_running.orig"; $counter++;
    
    $commands[$counter]="cp $ins_pkg_dir/bin/orcallator_running $ins_pkg_dir/bin/orcallator_running.orig"; $counter++;
    $commands[$counter]="cat $ins_pkg_dir/bin/orcallator_running.orig |sed 's,$real_install_dir/orca/var/orcallator,/var/orca,' > $ins_pkg_dir/bin/orcallator_running"; $counter++;
    $commands[$counter]="rm $ins_pkg_dir/bin/orcallator_running.orig"; $counter++;
    
    $commands[$counter]="cp $ins_pkg_dir/bin/start_orca_services $ins_pkg_dir/bin/start_orca_services.orig"; $counter++;
    $commands[$counter]="cat $ins_pkg_dir/bin/start_orca_services.orig |sed 's,$real_install_dir/orca/var,/var/orca,' > $ins_pkg_dir/bin/start_orca_services"; $counter++;
    $commands[$counter]="rm $ins_pkg_dir/bin/start_orca_services.orig"; $counter++;
    
    $commands[$counter]="cp $ins_pkg_dir/bin/start_orcallator $ins_pkg_dir/bin/start_orcallator.orig"; $counter++;
    $commands[$counter]="cat $ins_pkg_dir/bin/start_orcallator.orig |sed 's,$real_install_dir/orca/var/orcallator,/var/orca,' > $ins_pkg_dir/bin/start_orcallator"; $counter++;
    $commands[$counter]="rm $ins_pkg_dir/bin/start_orcallator.orig"; $counter++;
  }
  #if ($option{'n'}=~/ruby/) {
  #  $commands[$counter]="GEM_HOME=\"$ins_pkg_dir/lib/ruby/gems/1.9.1\" ; export GEM_HOME ; $ins_pkg_dir/bin/gem update"; $counter++;
  #  $commands[$counter]="GEM_HOME=\"$ins_pkg_dir/lib/ruby/gems/1.9.1\" ; export GEM_HOME ; $ins_pkg_dir/bin/gem install puppet"; $counter++;
  #  $commands[$counter]="GEM_HOME=\"$ins_pkg_dir/lib/ruby/gems/1.9.1\" ; export GEM_HOME ; $ins_pkg_dir/bin/gem install vagrant"; $counter++;
  #}
  if (-e "$source_dir_name") {
    if ($option{'n'}=~/orca/) {
      # Fix up problem with handling $@ in orca configure script
      if ( -e "$source_dir_name/configure") {
        system ("cd $source_dir_name ; cp ./configure ./configure.old ; cat ./configure |sed 's/^ORCA_CONFIGURE_COMMAND_LINE/#&/g' > ./configure.new ; cat ./configure.new > ./configure");
        system ("cd $source_dir_name ; $command");
      }
    }
    print_debug("Executing: cd $source_dir_name","long");
    foreach $command (@commands) {
      print_debug("Executing: $command","short");
      system ("cd $source_dir_name ; $command");
    }
  }
  else {
    print "Source file $option{'s'} does not exist\n";
    exit;
  }
  return;
}

# Create BASE/ins/[pkginfo,prototype] and produce a spooled package

sub create_spool {

  my $ins_dir="$work_dir/ins";
  my $script_dir="$work_dir/scripts";
  my $ins_pkg_dir="$ins_dir$real_install_dir";
  my $spool_dir="$work_dir/spool";
  my $proto_file="$ins_dir/prototype";
  my $post_file="$ins_dir/postinstall";
  my $info_file="$ins_dir/pkginfo";
  my $pkg_string="PKG=\"$option{'p'}\"";
  my $name_string="NAME=\"$option{'n'}\"";
  my $arch_string="ARCH=\"$option{'a'}\"";
  my $category_string="CATEGORY=\"$option{'c'}\"";
  my $date_string=`date +%Y.%m.%d.%H.%M`;
  my $email_string="EMAIL=\"$option{'e'}\"";
  my $pstamp_string="PSTAMP=\"\"";
  my $classes_string="CLASSES=\"none\"";
  my $basedir_string="BASEDIR=\"/\"";
  my $version_string; 
  my $user_info=`id`;
  my @values=split(" ",$user_info);
  my $user_name=$values[0];
  my $group_name=$values[1];
  my $header; 
  my $init_file;
  my $postinstall_file="$ins_dir/postinstall";
  my $preremove_file="$ins_dir/preremove";
  my @file_contents; 
  my $script_name; 
  my $command;
  my @script_names=('preinstall','postinstall','preremove','postremove','checkinstall');

  # Reminder:
  # ins_dir = Root of work directory, eg /export/home/user/burst/ins
  # This is the directory that DESTDIR will be give to simulate installing into /
  # ins_pkg_dir is the package specific directory, eg /export/home/user/burst/ins/usr/local
  # This would be used to simulate /use/local under DESTDIR
  # Out of politeness it would be good to direct configs to $ins_pkg_dir/etc (/usr/local/etc)
  # rather than $ins_dir/etc (/etc) so the package keeps things away from the system
  # as much as possible
  
  # If there are any package specific scripts copy them into the spool directory

  ($header,$user_name)=split('\(',$user_name);	
  ($header,$group_name)=split('\(',$group_name);	
  $user_name=~s/\)//g;
  $group_name=~s/\)//g;
	if ($option{'B'}) {
		if ($option{'p'}=~/rsa/) {
			if ($user_name!~/root/) {
				if (! -e "$spool_dir/uninstall_pam.sh") {
					print "Execute the following commands as root and re-run scripr:\n";
					print "mkdir -p $spool_dir/opt/pam\n";
					print	"(cd /opt/pam ; tar -cpf - . )|( cd $spool_dir/opt/pam ; tar -xpf - )\n";
					print "find /usr/lib -name \"*securid*\" |cpio -pdm $spool_dir\n";
          print "find /etc -name sd_pam.conf |cpio -pdm $spool_dir\n";
          print "find /var/ace -name sdconf.rec |cpio -pdm $spool_dir\n";
					print "chown -R $user_name $spool_dir\n";
					exit;
				}
			}
			else {
				system("mkdir -p $spool_dir/opt/pam");
				system("chown root:bin $spool_dir/opt/pam");
				system("chmod 400 $spool_dir/opt/pam");
				system("(cd /opt/pam ; tar -cpf - . )|( cd $spool_dir/opt/pam ; tar -xpf - )");
				system("find /usr/lib -name \"*securid*\" |cpio -pdm $spool_dir");
        system("find /etc -name sd_pam.conf |cpio -pdm $spool_dir");
        system("find /var/ace -name sdconf.rec |cpio -pdm $spool_dir");
			}
		}
	}
	else {
	  if ((-e "$spool_dir")&&($spool_dir=~/[A-z]/)) {
	    print "Cleaning up $spool_dir...\n";
	    system("cd $spool_dir ; rm -rf *");
	  }
	}
  $vendor_string="VENDOR=\"$vendor_string\"";	
  chomp($date_string);
  $version_string="VERSION=\"$option{'v'},REV=$date_string\"";
  if ($option{'D'}) {
    print_debug("pkginfo file contents:","long");
    print_debug("$pkg_string","short");
    print_debug("$name_string","short");
    print_debug("$arch_string","short");
    print_debug("$version_string","short");
    print_debug("$vendor_string","short");
    print_debug("$category_string","short");
    print_debug("$email_string","short");
    print_debug("$pstamp_string","short");
    print_debug("$basedir_string","short");
    print_debug("$classes_string","short");
  }
  open PROTO_FILE,">$proto_file";
  print PROTO_FILE "i pkginfo=./pkginfo\n";
  foreach $script_name (@script_names) {
    if (-e "$script_dir/$option{'n'}.$script_name") {
      system("cp $script_dir/$option{'n'}.$script_name $spool_dir/$script_name");
      system("chmod +x $spool_dir/$script_name");
      print PROTO_FILE "i $script_name=./$script_name\n";
    }
  }
  if ($option{'n'}=~/orca|openssh|bsl/) {
    # Add postinstall and preremove scripts to package
    print PROTO_FILE "i postinstall=./postinstall\n";
    print PROTO_FILE "i preremove=./preremove\n";
    open POSTINSTALL_FILE,">$postinstall_file";
    print POSTINSTALL_FILE "#!/bin/sh\n";
    open PREREMOVE_FILE,">$preremove_file";
    print PREREMOVE_FILE "#!/bin/sh\n";
    if ($option{'n'}=~/bsl/) {
      print POSTINSTALL_FILE "# Create log file and fix permisions\n";
      print POSTINSTALL_FILE "touch /var/log/userlog\n";
      print POSTINSTALL_FILE "chmod 600 /var/log/userlog\n";
      print POSTINSTALL_FILE "chown root:sys /var/log/userlog\n";
      print POSTINSTALL_FILE "# Update /etc/shells\n";
      print POSTINSTALL_FILE "if [ -f \"/etc/shells\" ] ; then\n";
      print POSTINSTALL_FILE "  if [ \"`cat /etc/shells | grep '$real_install_dir/bin/bash'`\" != \"$real_install_dir/bin/bash\" ]; then\n";
      print POSTINSTALL_FILE "    echo \"$real_install_dir/bin/bash\" >> /etc/shells\n";
      print POSTINSTALL_FILE "    cp /etc/syslog.conf /etc/syslog.conf.prebsl\n";
      print POSTINSTALL_FILE "  fi\n";
      print POSTINSTALL_FILE "fi\n";
      print POSTINSTALL_FILE "# Update /etc/syslog.conf\n";
      print POSTINSTALL_FILE "if [ -f \"/etc/syslog.conf\" ] ; then\n";
      print POSTINSTALL_FILE "  if [ \"`cat /etc/syslog.conf | awk '{print \$2}' |grep '/var/log/userlog`\" != \"/var/log/userlog\" ]; then\n";
      print POSTINSTALL_FILE "    echo \"user.info\t/var/log/userlog\" >> /etc/syslog.conf\n";
      print POSTINSTALL_FILE "    # Restart syslog.conf\n";
      print POSTINSTALL_FILE "    if [ \"`uname -r`\" != \"5.10\" ]; then\n";
      print POSTINSTALL_FILE "      /etc/init.d/syslog stop ; /etc/init.d/syslog start\n";
      print POSTINSTALL_FILE "    else\n";
      print POSTINSTALL_FILE "      svcadm restart svc:/system/system-log:default\n";
      print POSTINSTALL_FILE "    fi\n";
      print POSTINSTALL_FILE "  fi\n";
      print POSTINSTALL_FILE "fi\n";
      print POSTINSTALL_FILE "# Manage /var/log/userlog\n";
      print POSTINSTALL_FILE "if [ \"`logadm -V |awk '{print \$1}' |grep '/var/log/userlog'`\" != \"/var/log/userlog\" ]; then\n";
      print POSTINSTALL_FILE "  cp /etc/logadm.conf /etc/logadm.conf.prebsl\n";
      print POSTINSTALL_FILE "  logadm -w /var/log/userlog -C 8 -m 600 -g sys -o root\n";
      print POSTINSTALL_FILE "fi\n";
      print PREREMOVE_FILE "# Update /etc/shells\n";
      print PREREMOVE_FILE "if [ -f \"/etc/shells\" ] ; then\n";
      print PREREMOVE_FILE "  if [ \"`cat /etc/shells | grep '$real_install_dir/bin/bash'`\" = \"$real_install_dir/bin/bash\" ]; then\n";
      print PREREMOVE_FILE "    if [ -f \"/etc/shells.prebsl\" ] ; then\n";
      print PREREMOVE_FILE "      rm /etc/shells.prebsl\n";
      print PREREMOVE_FILE "    fi\n";
      print PREREMOVE_FILE "    cat /etc/shells |grep -v '$real_install_dir/bin/bash' > /etc/shells.postbsl\n";
      print PREREMOVE_FILE "    cat /etc/shells.postbsl > /etc/shells\n";
      print PREREMOVE_FILE "    rm /etc/shells.postbsl\n";
      print PREREMOVE_FILE "  fi\n";
      print PREREMOVE_FILE "fi\n";
      print PREREMOVE_FILE "# Update /etc/syslog.conf\n";
      print PREREMOVE_FILE "if [ -f \"/etc/syslog.conf\" ] ; then\n";
      print PREREMOVE_FILE "  if [ \"`cat /etc/syslog.conf | awk '{print \$2|' |grep '/var/log/userlog'`\" = \"/var/log/userlog\" ]; then\n";
      print PREREMOVE_FILE "    if [ -f \"/etc/syslog.conf.prebsl\" ] ; then\n";
      print PREREMOVE_FILE "      rm /etc/syslog.conf.prebsl\n";
      print PREREMOVE_FILE "    fi\n";
      print PREREMOVE_FILE "    cat /etc/syslog.conf |grep -v '/var/log/userlog' > /etc/syslog.conf.postbsl\n";
      print PREREMOVE_FILE "    cat /etc/syslog.conf.postbsl > /etc/syslog.conf\n";
      print PREREMOVE_FILE "    rm /etc/syslog.conf.postbsl\n";
      print PREREMOVE_FILE "    # Restart syslog.conf\n";
      print PREREMOVE_FILE "    if [ \"`uname -r`\" != \"5.10\" ]; then\n";
      print PREREMOVE_FILE "      /etc/init.d/syslog stop ; /etc/init.d/syslog start\n";
      print PREREMOVE_FILE "    else\n";
      print PREREMOVE_FILE "      svcadm restart svc:/system/system-log:default\n";
      print PREREMOVE_FILE "    fi\n";
      print PREREMOVE_FILE "  fi\n";
      print PREREMOVE_FILE "fi\n";
      print PREREMOVE_FILE "# Manage /var/log/userlog\n";
      print PREREMOVE_FILE "if [ \"`logadm -V |awk '{print \$1}' |grep '/var/log/userlog'`\" = \"/var/log/userlog\" ]; then\n";
      print PREREMOVE_FILE "  rm /etc/logadm.conf.prebsl\n";
      print PREREMOVE_FILE "  logadm -r /var/log/userlog\n";
      print PREREMOVE_FILE "fi\n";

    }
    if ($option{'n'}=~/orca/) {
      # Create /var/* in postinstall
      print POSTINSTALL_FILE "mkdir -p /var/$option{'n'}/rrd\n";
      print POSTINSTALL_FILE "mkdir -p /var/$option{'n'}/html\n";
      print POSTINSTALL_FILE "mkdir -p /var/$option{'n'}/`hostname`\n";
      print POSTINSTALL_FILE "ln -s $real_install_dir/lib/SE/3.4 $real_install_dir/lib/SE/3.5.1\n";
      system("mkdir -p $ins_pkg_dir/etc");
    }
    if ($option{'r'}=~/10/) { 
      # If on Solaris 10 create client manifest 
      # and get postinstall script to install it
      if ($option{'n'}=~/orca/) {
        $init_file="$ins_pkg_dir/etc/$option{'n'}-client.xml";
        open INIT_FILE,">$init_file";
        print INIT_FILE "<?xml version=\"1.0\"?>\n";
        print INIT_FILE "<!DOCTYPE service_bundle SYSTEM \"/usr/share/lib/xml/dtd/service_bundle.dtd.1\">\n";
        print INIT_FILE "<service_bundle type='manifest' name='$option{'n'}:client'>";
        print INIT_FILE "<service name='application/$option{'n'}/client' type='service' version='1'>\n";
        print INIT_FILE "<create_default_instance enabled='true' />\n";
        print INIT_FILE "<single_instance />";
        print INIT_FILE "<exec_method type='method' name='start'  exec='$real_install_dir/bin/start_orcallator' timeout_seconds=\"60\" />\n";
        print INIT_FILE "<exec_method type='method' name='stop'  exec='$real_install_dir/bin/stop_orcallator' timeout_seconds=\"60\" />\n";
        print INIT_FILE "</service>\n";
        print INIT_FILE "</service_bundle>\n";
        close INIT_FILE;
      }
      # If on Solaris 10 create server manifest 
      # and get postinstall script to install it
      if ($option{'n'}=~/orca|openssh/) {
        $init_file="$ins_pkg_dir/etc/$option{'n'}-server.xml";
        open INIT_FILE,">$init_file";
        print INIT_FILE "<?xml version=\"1.0\"?>\n";
        print INIT_FILE "<!DOCTYPE service_bundle SYSTEM \"/usr/share/lib/xml/dtd/service_bundle.dtd.1\">\n";
        print INIT_FILE "<service_bundle type='manifest' name='$option{'n'}:server'>";
        print INIT_FILE "<service name='application/$option{'n'}/server' type='service' version='1'>\n";
        print INIT_FILE "<create_default_instance enabled='false' />\n";
        print INIT_FILE "<single_instance />";
        if ($option{'n'}=~/orca/) {
          print INIT_FILE "<exec_method type='method' name='start'  exec='$real_install_dir/bin/orca -daemon -verbose $real_install_dir/etc/orcallator.cfg' timeout_seconds=\"60\" />\n";
        }
        if ($option{'n'}=~/openssh/) {
          print INIT_FILE "<exec_method type='method' name='start'  exec='$real_install_dir/sbin/sshd' timeout_seconds=\"60\" />\n";
        }
        print INIT_FILE "<exec_method type='method' name='stop'  exec='pkill -f $real_install_dir/sbin/sshd' timeout_seconds=\"60\" />\n";
        print INIT_FILE "</service>\n";
        print INIT_FILE "</service_bundle>\n";
        close INIT_FILE;
      }
      if ($option{'n'}=~/orca/) {
        print POSTINSTALL_FILE "svccfg import $real_install_dir/etc/$option{'n'}-client.xml\n";
        print POSTINSTALL_FILE "svcadm enable svc:application/$option{'n'}/client:default\n";
        print PREREMOVE_FILE "svcadm disable svc:application/$option{'n'}/client:default\n";
        print PREREMOVE_FILE "svccfg delete -f svc:application/$option{'n'}/client:default\n";
      }
      if ($option{'n'}=~/orca|openssh/) {
        print POSTINSTALL_FILE "svccfg import $real_install_dir/etc/$option{'n'}-server.xml\n";
        print POSTINSTALL_FILE "svcadm disable svc:application/$option{'n'}/server:default\n";
        print PREREMOVE_FILE "svcadm disable svc:application/$option{'n'}/server:default\n";
        print PREREMOVE_FILE "svccfg delete -f svc:application/$option{'n'}/server:default\n";
      }
    }
    else {
      # If not on Solaris 10 create standard init script 
      # and get postinstall script to install it
      if ($option{'n'}=~/orca|openssh/) {
        $init_file="$ins_pkg_dir/etc/$option{'n'}.init";
        open INIT_FILE,">$init_file";
        print INIT_FILE "#!/bin/sh\n";
        print INIT_FILE "\n";
        print INIT_FILE "case \"\$1\" in\n";
        print INIT_FILE "\tstart)\n";
        if ($option{'n'}=~/orca/) {
          print INIT_FILE "\t\t# Client:\n";
          print INIT_FILE "\t\t$real_install_dir/bin/start_orcallator\n";
          print INIT_FILE "\t\t# Server:\n";
          print INIT_FILE "\t\t# $real_install_dir/bin/orca -daemon -verbose $real_install_dir/etc/orcallator.cfg\n";
        }
        if ($option{'n'}=~/openssh/) {
          print INIT_FILE "\t\t$real_install_dir/sbin/sshd\n";
        }
        print INIT_FILE "\t\t;;\n";
        print INIT_FILE "\tstop)\n";
        if ($option{'n'}=~/orca/) {
          print INIT_FILE "\t\t# Client:\n";
          print INIT_FILE "\t\t$real_install_dir/bin/stop_orcallator\n";
          print INIT_FILE "\t\t# Server:\n";
          print INIT_FILE "\t\t# pkill -f $real_install_dir/bin/orca\n";
        }
        if ($option{'n'}=~/openssh/) {
          print INIT_FILE "\t\t# pkill -f $real_install_dir/sbin/sshd\n";
        }
        print INIT_FILE "\t\t;;\n";
        print INIT_FILE "\t*)\n";
        print INIT_FILE "\t\techo \"usage: \$0 {start|stop}\"\n";
        print INIT_FILE "\t\texit 1\n";
        print INIT_FILE "\t\t;;\n";
        print INIT_FILE "esac\n";
        print INIT_FILE "\n";
        print INIT_FILE "exit 0\n";
        print POSTINSTALL_FILE "cp $real_install_dir/etc/$option{'n'}.init /etc/init.d/$option{'n'}\n";
        print POSTINSTALL_FILE "chmod 755 /etc/init.d/$option{'n'}\n";
        print POSTINSTALL_FILE "chown root:sys /etc/init.d/$option{'n'}\n";
        print POSTINSTALL_FILE "/etc/init.d/$option{'n'} start\n";
        print POSTINSTALL_FILE "ln -s /etc/init.d/$option{'n'} /etc/rc0.d/K01$option{'n'}\n";
        print POSTINSTALL_FILE "ln -s /etc/init.d/$option{'n'} /etc/rc1.d/K01$option{'n'}\n";
        print POSTINSTALL_FILE "ln -s /etc/init.d/$option{'n'} /etc/rc2.d/S99$option{'n'}\n";
        print POSTINSTALL_FILE "ln -s /etc/init.d/$option{'n'} /etc/rc3.d/S99$option{'n'}\n";
        print PREREMOVE_FILE "#!/bin/sh\n";
        print PREREMOVE_FILE "/etc/init.d/$option{'n'} stop\n";
        print PREREMOVE_FILE "rm /etc/init.d/$option{'n'}\n";
        print PREREMOVE_FILE "rm /etc/rc0.d/K01$option{'n'}\n";
        print PREREMOVE_FILE "rm /etc/rc1.d/K01$option{'n'}\n";
        print PREREMOVE_FILE "rm /etc/rc2.d/S99$option{'n'}\n";
        print PREREMOVE_FILE "rm /etc/rc3.d/S99$option{'n'}\n";
        close INIT_FILE;
      }
    }
    if ($option{'n'}=~/orca/) { 
      print PREREMOVE_FILE "rm $real_install_dir/lib/SE/3.5.1\n";
    }
    close POSTINSTALL_FILE;
    close PREREMOVE_FILE;
    if ($option{'n'}=~/orca|openssh/) {
      system("chmod 0755 $init_file");
    }
    if ( -e "$postinstall_file") {
      system("chmod 0755 $postinstall_file");
    }
    if ( -e "$preremove_file") {
      system("chmod 0755 $preremove_file");
    }
    if ($option{'n'}=~/orca|openssh/) {
      print_debug("Contents of $init_file:","long");
      @file_contents=`cat $init_file`;
      print_debug(" @file_contents","short");
    }
    if ( -e "$postinstall_file") {
      print_debug("Contents of $postinstall_file:","long");
      @file_contents=`cat $postinstall_file`;
      print_debug(" @file_contents","short");
    }
    if ( -e "$preremove_file") {
      print_debug("Contents of $preremove_file:","long");
      @file_contents=`cat $preremove_file`;
      print_debug(" @file_contents","short");
    }
  }
  close PROTO_FILE;
  $command="cd $ins_dir ; find . -print |grep -v './pkginfo' |grep -v './prototype' |grep -v './postinstall' |grep -v './preremove' |grep -v './preinstall' |grep -v './postremove' |grep -v './checkinstall' |pkgproto | sed 's/$user_name $group_name/$dir_user $dir_group/g' >> $proto_file";
  print_debug("Executing: $command","long");
  system("$command");
  open INFO_FILE,">$info_file";
  print INFO_FILE "$pkg_string\n";
  print INFO_FILE "$name_string\n";
  print INFO_FILE "$arch_string\n";
  print INFO_FILE "$version_string\n";
  print INFO_FILE "$category_string\n";
  print INFO_FILE "$email_string\n";
  print INFO_FILE "$pstamp_string\n";
  print INFO_FILE "$basedir_string\n";
  print INFO_FILE "$classes_string\n";
  close INFO_FILE;
  return;
}

# Run pkgmk to create transfer package

sub create_trans {

  my $ins_dir="$work_dir/ins";
  my $trans_dir="$work_dir/trans";
  my $spool_dir="$work_dir/spool";
  my $proto_file="$ins_dir/prototype";
  my @prototype; 
  my $command;
	my $file_name;

  if ((-e "$trans_dir")&&($trans_dir=~/[A-z]/)) {
    print "Cleaning up $trans_dir...\n";
    system("cd $trans_dir ; rm -rf *");
  }
  $command="cd $ins_dir ; pkgmk -o -r . -d $spool_dir -f $proto_file";
  print_debug("Prototype file contents:","long");
  @prototype=`cat $proto_file`;
	foreach $file_name (@prototype) {
		chomp($file_name);
	  print_debug("$file_name","normal");
	}
  print_debug("Executing: $command","long");
  system("$command");
  return;
}

# Process transfer package into actual package

sub create_pkg {
  
  my $spool_dir="$work_dir/spool";
  my $trans_dir="$work_dir/trans";
  my $pkg_dir="$work_dir/pkg";
  my $pkg_string="$option{'p'}";
  my $hpn_string=$pkg_string;
  my $command; 
  
  if ($hpnssh eq 1) {
    $hpn_string=~s/ssh/hpnssh/g;
    $command="cd $spool_dir ; pkgtrans $spool_dir $pkg_dir/$hpn_string-$option{'v'}-$option{'a'}-sol$option{'r'}.pkg $pkg_string";
  }
  else {
    $command="cd $spool_dir ; pkgtrans $spool_dir $pkg_dir/$pkg_string-$option{'v'}-$option{'a'}-sol$option{'r'}.pkg $pkg_string";
  }
  print_debug("Executing: $command","long");
  system("$command");
  return;
}

sub create_spec {
  my $spec_dir="$work_dir/SPECS";
  my $spec_file="$spec_dir/$option{'p'}.spec";
  my $arch_string=$os_arch;
  my @file_contents;
  
  print_debug("Creating: $spec_file","long");
  open SPEC_FILE,">$spec_file";
  print SPEC_FILE "Version:\t\t\t\t$option{'v'}\n";
  print SPEC_FILE "Name:\t\t\t\t\t$option{'n'}\n";
  if ($option{'n'}=~/john/) {
    $option{'d'}="John the Ripper is a fast password cracker";
  }
  if ($option{'n'}=~/bsl/) {
    $option{'d'}="Bash compiled with syslog support";
  }
  print SPEC_FILE "Summary:\t\t\t\t$option{'d'}\n";
  print SPEC_FILE "Release:\t\t\t\t1\n";
  print SPEC_FILE "Group:\t\t\t\t\t$option{'c'}\n";
  print SPEC_FILE "Vendor:\t\t\t\t$vendor_string\n";
  print SPEC_FILE "Distribution:\t$pkg_base_name\n";
  print SPEC_FILE "License:\t\t\t\t$option{'l'}\n";
  if ($option{'n'}=~/john/) {
    $option{'u'}="http://www.openwall.com/john/";
    $option{'f'}="http://www.openwall.com/john/g/john-$option{'v'}.tar.gz"
  }
  if ($option{'n'}=~/bsl/) {
    $option{'u'}="http://www.gnu.org/software/bash/";
    $option{'f'}="http://ftp.gnu.org/gnu/bash/bash-$option{'v'}.tar.gz"
  }
  print SPEC_FILE "URL:\t\t\t\t\t\t$option{'u'}\n";
  print SPEC_FILE "Source0:\t\t\t\t$option{'f'}\n";
  if ($option{'n'}=~/bsl/) {
    print SPEC_FILE "Source1:\t\t\t\thttps://raw.github.com/richardatlateralblast/bsl.postinstall/master/bsl.postinstall\n";
    print SPEC_FILE "Source2:\t\t\t\thttps://raw.github.com/richardatlateralblast/bsl.preremove/master/bsl.preremove\n";
  }
  if ($option{'n'}=~/bsl/) {
    print SPEC_FILE "Patch1:\t\t\t\thttps://raw.github.com/richardatlateralblast/bash-4.2-bashhist.c.patch/master/bash-4.2-bashhist.c.patch\n";
  }
  print SPEC_FILE "BuildRoot:\t\t\t%{_tmppath}/%{name}-%{version}-%{release}\n";
  print SPEC_FILE "\n";
  print SPEC_FILE "%description\n";
  print SPEC_FILE "$option{'d'}\n";
  print SPEC_FILE "\n";
  print SPEC_FILE "%prep\n";
  if ($option{'n'}=~/bsl/) {
    print SPEC_FILE "%setup -q -n bash-%{version}\n";
  }
  else {
    print SPEC_FILE "%setup -q -n %{name}-%{version}\n";
  }
  print SPEC_FILE "\n";
  print SPEC_FILE "%build\n";
  if ($option{'n'}=~/john/) {
    $arch_string=~s/_/-/g;
    print SPEC_FILE "cd src ; make linux-$arch_string\n";
  }
  if ($option{'n'}=~/bsl/) {
    print SPEC_FILE "patch -p0 < %{_topdir}/SOURCES/bash-%{version}-bashhist.c.patch\n";
    print SPEC_FILE "./configure --prefix=/opt/%{distribution}\n";
    print SPEC_FILE "sed -i 's,/\* #define SYSLOG_HISTORY \*/,#define SYSLOG_HISTORY,' config-top.h\n";
    print SPEC_FILE "make all\n";
  }
  print SPEC_FILE "\n";
  print SPEC_FILE "%install\n";
  print SPEC_FILE "[ \"%{buildroot}\" != / ] && rm -rf \"%{buildroot}\"\n";
  if ($option{'n'}=~/bsl/) {
    print SPEC_FILE "make DESTDIR=%{buildroot} install\n";
    print SPEC_FILE "mkdir -p %{buildroot}/opt/%{distribution}/etc\n";
    print SPEC_FILE "cp %{_topdir}/SOURCES/$option{'n'}.postinstall %{buildroot}/opt/%{distribution}/etc\n";
    print SPEC_FILE "cp %{_topdir}/SOURCES/$option{'n'}.preremove %{buildroot}/opt/%{distribution}/etc\n";
    print SPEC_FILE "chmod +x %{buildroot}/opt/%{distribution}/etc/$option{'n'}.postinstall\n";
    print SPEC_FILE "chmod +x %{buildroot}/opt/%{distribution}/etc/$option{'n'}.preremove\n";
  }
  if ($option{'n'}=~/john/) {
    print SPEC_FILE "mkdir -p %{buildroot}/opt/%{distribution}/bin\n";
    print SPEC_FILE "( cd %{_topdir}/BUILD/%{name}-%{version}/run ; tar -cpf - . ) | ( cd %{buildroot}/opt/%{distribution}/bin ; tar -xpf - )\n";
  }
  print SPEC_FILE "\n";
  print SPEC_FILE "%files\n";
  print SPEC_FILE "%defattr(-,root,root)\n";
  print SPEC_FILE "/opt/%{distribution}/*\n";
  print SPEC_FILE "\n";
  if ($option{'n'}=~/bsl/) {
    print SPEC_FILE "%post\n";
    print SPEC_FILE "/opt/%{distribution}/etc/$option{'n'}.postinstall\n";
    print SPEC_FILE "/opt/%{distribution}/etc/$option{'n'}preremove\n";
  }
  if ($option{'n'}=~/bsl/) {
    print SPEC_FILE "%preun\n";
    print SPEC_FILE "\n";
    print SPEC_FILE "\n";
  }
  print SPEC_FILE "%changelog\n";
  print SPEC_FILE "\n";
  print_debug("Contents of $spec_file","long");
  @file_contents=`cat $spec_file`;
  print_debug(" @file_contents","long");
  close SPEC_FILE;
  return;
  
}

sub print_debug {
  
  my $string=$_[0];
  my $style=$_[1];
  
  if ($option{'D'}) {
    if ($style!~/[A-z]/) {
      $style="normal";
    }
    if ($style=~/short|normal/) {
      print "$string\n";
      print LOG_FILE "$string\n";
    }
    else {
      print "\n";
      print "$string\n";
      print "\n";
    }
  }
  return;
  
}

sub create_rpm {
  
  my $spec_dir="$work_dir/SPECS";
  my $spec_file="$spec_dir/$option{'p'}.spec";
  my $command="rpmbuild -ba --define \"_topdir $work_dir\" $spec_file";
  
  print_debug("Executing: $command","long");
  system("$command");
  return;
  
}