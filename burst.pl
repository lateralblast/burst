#!/usr/bin/perl

# Name:         burst (Build Unaided Rapid Source Tool)
# Version:      1.4.3
# Release:      1
# License:      CC-BA (Creative Commons By Attrbution)
#               http://creativecommons.org/licenses/by/4.0/legalcode
# Group:        System
# Source:       N/A
# URL:          http://lateralblast.com.au/
# Distribution: Solaris
# Vendor:       UNIX
# Packager:     Richard Spindler <richard@lateralblast.com.au>
# Description:  Solaris package creation tool

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

use strict;
use Getopt::Std;
use File::Basename;

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
my $os_ver=`uname -r`;
my $options="BPa:b:c:d:e:f:i:l:n:p:r:s:u:v:w:hCD:R:V";

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
  print "-P: Publih IPS to a repository (default is /export/repo/burst)\n";
  print "-R: Repository URL (required to publish IPS to a specific repository)\n";
  print "\n";
  print "Example:\n";
  print "$script_name -d /tmp/$script_name -s /tmp/setoolkit-3.5.1.tar -p BLAHse";
  print "\n";
  print "\n";
  return;
}

sub print_version {
  my $script_version=get_script_version();
  print "$script_version\n";
  return;
}

sub get_script_version {
  my $script_version=`cat $0 |grep '^# Version' |awk '{print \$3}'`;
  chomp($script_version);
  return($script_version);
}

# Routing to create ZFS pool

sub create_zpool {
  my $repo_dir=$option{'R'};
  my $zfs_dir;
  my @zfs_dirs;
  my $new_dir;
  my $zpool_name="rpool";

  $repo_dir=~s/^\///g;
  if (! -e "$option{'R'}") {
    print "Creating ZFS filesystem $zpool_name/$repo_dir\n";
    @zfs_dirs=split(/\//,$repo_dir);
    foreach $zfs_dir (@zfs_dirs) {
      $new_dir="$new_dir/$zfs_dir";
      if (! -e "$new_dir") {
        system("zfs create rpool/$new_dir");
      }
    }
  }
  return;
}

# Create SMF service for repo

sub check_smf_service {
  my $repo_name=basename($option{'R'});
  my $repo_check=`svcs -a |grep 'pkg/server' |grep $repo_name`;
  my $repo_port="10085";

  if ($repo_check!~/$repo_name/) {
    system("pkgrepo create $option{'R'}");
    system("pkgrepo set -s $option{'R'} publisher/prefix=$repo_name");
    system("svccfg -s pkg/server add $repo_name");
    system("svccfg -s pkg/server add pkg application");
    system("svccfg -s pkg/server:$repo_name setprop pkg/port=10082");
    system("svccfg -s pkg/server:$repo_name setprop pkg/inst_root=$option{'R'}");
    system("svccfg -s pkg/server:$repo_name setprop pkg/readonly=false");
    system("svccfg -s pkg/server:$repo_name addpg general framework");
    system("svccfg -s pkg/server:$repo_name addpropvalue general/complete astring: $repo_name");
    system("svccfg -s pkg/server:$repo_name addpropvalue general/enabled boolean: true");
    system("svcadm refresh pkg/server:$repo_name");
    system("svcadm enable pkg/server:$repo_name");
  }
  return;
}

# Routine to publish IPS

sub publish_ips {
  my $ins_dir="$work_dir/ins";
  my $spool_dir="$work_dir/spool";
  system("cd $ins_dir ; pkgsend publish -s $option{'R'} -d . $spool_dir/$option{'n'}.p5m.res");
  return;
}

# Call the functions to build a package

check_env();
if ($os_name=~/SunOS/) {
  if (!$option{'B'}) {
    extract_source();
    compile_source();
  }
  if ($os_ver=~/5\.11/) {
    create_mog();
    create_ips();
    if ($option{'P'}) {
      if (!$option{'R'}) {
        $option{'R'}="/export/repo/burst";
        create_zpool();
      }
      check_smf_service();
      publish_ips();
    }
  }
  else {
    create_spool();
    create_trans();
    create_pkg();
  }
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
      }
      else {
        if ($os_arch=~/64/) {
          $pam_lib="/lib64/security/pam_securid.so"
        }
        else {
          $pam_lib="/lib/security/pam_securid.so"
        }
      }
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
    if (($option{'n'})&&(!$option{'v'})) {
      get_source_version();
      determine_source_file_name();
    }
    if ((!$option{'n'})||(!$option{'v'})) {
      # If the source file, version and name have not been given
      # exit as there is not enough information to continue
      if (!$option{'C'}) {
        print "\n";
        print "You must either specify the source file and/or the package name and version\n";
        print "\n";
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
  my $file_name=$_[0];
  my $extension;

  push(@extensions,".tgz");
  push(@extensions,".tar.gz");
  push(@extensions,".tar.bz2");
  push(@extensions,".tbz2");
  push(@extensions,".tar");
  foreach $extension (@extensions) {
    $file_name=~s/$extension//g;
  }
  return($file_name);
}

sub determine_source_file_name {

  my @extensions;
  my $extension;
  my $record;
  my $file_name_base;
  my $src_dir;

  if ($os_name=~/SunOS/) {
    $src_dir="$work_dir/src";
  }
  if ($os_name=~/Linux/) {
    $src_dir="$work_dir/SOURCES"
  }
  $file_name_base="$src_dir/$option{'n'}-$option{'v'}";

  push(@extensions,"tar");
  push(@extensions,"tgz");
  push(@extensions,"tar.gz");
  push(@extensions,"tar.bz2");
  push(@extensions,"tbz2");
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
  foreach $extension (@extensions) {
    if ($option{"D"}) {
      print "Seeing if $file_name_base.$extension exists\n";
    }
    if (-e "$file_name_base.$extension") {
      $option{'s'}="$file_name_base.$extension";
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
  my $record;
  my $dep;
  my $package;
  my $pkg_check;
  my @new_dep_list;

  push(@dep_list,"ruby,yaml:readline:libffi");
  push(@dep_list,"ssh,ssl");

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
  return;
}

sub populate_source_list {

  my @source_list;
  my $package_name=$option{'n'};
  my $sources_file="sources";

  if ($package_name=~/bsl/) {
    $package_name="bash";
  }
  if (-e "$sources_file") {
    @source_list=`cat $sources_file`;
  }
  return @source_list;
}

sub get_source_version {

  my @source_list;
  my $source_url;
  my $header;

  @source_list=populate_source_list();
  foreach $source_url (@source_list) {
    chomp($source_url);
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
  my $source_url;
  my $command;
  my $src_dir;
  my $wget_test;
  my $file_name;

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
        $file_name=basename($source_url);
        if (! -e "$src_dir/$file_name") {
          $command="cd $src_dir ; wget $source_url";
          print_debug("Executing: $command","long");
          system("$command");
        }
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
  my $command;
  my $record;
  my $package;
  my $conf_string;

  push(@commands,"wget,CC=\"cc\" ; export CC ; ./configure --prefix=$real_install_dir --with-ssl=openssl --with-libssl-prefix=$real_install_dir");
  push(@commands,"openssl,CC=\"cc\" ; export CC ; ./Configure --prefix=$real_install_dir --openssldir=$real_install_dir zlib-dynamic threads shared solaris-x86-cc");
  push(@commands,"sudo,CC=\"cc\" ; export CC ; ./configure --prefix=$real_install_dir --enable-pam");
  if ($os_name=~/SunOS/) {
    if ($option{'n'}=~/orca|setoolkit/) {
      if ($option{'n'}=~/orca/) {
        $conf_string="--prefix=$real_install_dir --with-rrd-dir=/var/orca/rrd --with-html-dir=/var/orca/html --with-var-dir=/var/orca --build=$option{'a'}-sun-solaris2.$option{'r'} --radius_db=off";
        push(@commands,"orca,ORCA_CONFIGURE_COMMAND_LINE=\"$conf_string\" ; export ORCA_CONFIGURE_COMMAND_LINE ; PATH=\"\$PATH:/usr/ccs/bin\" ; export PATH ; CC=\"$cc_bin\" ; export CC ; ./configure $conf_string");
      }
      if ($option{'n'}=~/setoolkit/) {
        push(@commands,"setoolkit,CC=\"CC\" ; export CC ; ./configure --prefix=$real_install_dir --with-se-include-dir=$real_install_dir/include --with-se-examples-dir=$real_install_dir/examples");
      }
    }
    push(@commands,"perl,CC=\"gcc\" ; export CC ; ./Configure -des -Dusethreads -Dcc=\"gcc -m32\" -Dprefix=$real_install_dir -Dusedttrace -Dusefaststdio -Duseshrplib -Dusevfork -Dless=less -Duse64bitall -Duse64bitint -Dpager=more");
    if ($option{'r'}!~/9|10|11/) {
      push(@commands,"ssh,CFLAGS=\"\$CFLAGS -I$real_install_dir/include\" ; export CFLAGS ; CC=cc ; export CC ; ./configure --prefix=$real_install_dir --with-zlib --with-solaris-contracts --with-solaris-projects --with-tcp-wrappers=$real_install_dir --with-ssl-dir=$real_install_dir --with-privsep-user=sshd --with-md5-passwords --with-xauth=/usr/openwin/bin/xauth --with-mantype=man --with-pid-dir=/var/run --with-pam --with-audit=bsm --enable-shared");
    }
    else {
      push(@commands,"openssh,CFLAGS=\"\$CFLAGS -I$real_install_dir/include -I/usr/sfw/include\" ; export CFLAGS ; CC=cc ; export CC ; ./configure --prefix=$real_install_dir --with-zlib --with-solaris-contracts --with-solaris-projects --with-tcp-wrappers=/usr/sfw --with-ssl-dir=$real_install_dir --with-privsep-user=sshd --with-md5-passwords --with-xauth=/usr/openwin/bin/xauth --with-mantype=man --with-pid-dir=/var/run --with-pam --with-audit=bsm --enable-shared");
    }
    push(@commands,"ruby,CC=cc ; export CC ; ./configure --prefix=$real_install_dir --enable-shared");
    if ($option{'n'}=~/lftp/) {
      push(@commands,"lftp,CC=cc ; export CC ; ./configure --prefix=$real_install_dir --enable-shared --without-gnutls");
    }
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

# Fix file and directory permissions

sub fix_permissions {
    my $ins_dir="$work_dir/ins";
    my @permissions;
    my $chmod_value;
    my $chown_value;
    my $dir_name;
    my $permission;

    push(@permissions,"0755,root:sys,$ins_dir/usr");
    push(@permissions,"0755,root:sys,$ins_dir/etc");
    push(@permissions,"0755,root:bin,$ins_dir/usr/ruby");
    foreach $permission (@permissions) {
      ($chmod_value,$chown_value,$dir_name)=split(/,/,$permission);
      if (-e "$dir_name") {
        system("chown $chown_value $dir_name");
        system("chmod $chmod_value $dir_name");
      }
    }
    return;
}

sub compile_source {

  my @commands;
  my $command;
  my $ins_dir="$work_dir/ins";
  my $src_dir="$work_dir/src";
  my $spool_dir="$work_dir/spool";
  my $conf_string;
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
  if (-e "$source_dir_name/install.rb") {
    print "Found ruby installer\n";
    if (-e "$ins_dir") {
      if ($ins_dir=~/[A-z]/) {
        print "Removing contents of $ins_dir\n";
        system("rm -rf $ins_dir/*");
      }
    }
    if (-e "$spool_dir") {
      if ($spool_dir=~/[A-z]/) {
        print "Removing contents of $spool_dir\n";
        system("rm -rf $spool_dir/*");
      }
    }
    system("cd $source_dir_name ; ./install.rb --destdir=$ins_dir --full");
    fix_permissions();
    return;
  }
  if ($option{'n'}=~/openssh/) {
    if ($hpnssh eq 1) {
      $patch_file="$src_dir/openssh-6.1p1-hpn13v14.diff";
      if (! -e "$patch_file") {
        if (-e "$patch_file.gz") {
          system("cd $src_dir ; gzip -d $patch_file.gz");
        }
      }
      if ( -e "$patch_file") {
        push(@commands,"gpatch < $patch_file");
      }
      else {
        print "Download HPN patch and put it in $src_dir\n";
        exit;
      }
    }
  }
  $command=search_conf_list();
  push(@commands,$command);
  if ($option{'n'}=~/bsl/) {
    push(@commands,"cp config-top.h config-top.h.orig");
    push(@commands,"cat config-top.h.orig |sed 's,/\\* #define SYSLOG_HISTORY \\*/,#define SYSLOG_HISTORY,' > config-top.h");
    push(@commands,"rm config-top.h.orig");
  }
  push(@commands,"make clean");
  if ($option{'n'}=~/john/) {
    if ($option{'a'}=~/i386/ ) {
      push(@commands,"cd src ; make solaris-x86-any-gcc");
    }
    else {
      push(@commands,"cd src ; make solaris-sparc-gcc");
    }
  }
  else {
    push(@commands,"LD_LIBRARY_PATH=\"\$LD_LIBRARY_PATH:$real_install_dir/lib\" ; export LD_LIBRARY_PATH; CFLAGS=\"\$CFLAGS -I$real_install_dir/include\" ; export CFLAGS ; CC=cc ; export CC ; make all");
  }
  push(@commands,"cd $ins_dir ; rm -rf *");
  if ($option{'n'}=~/openssl/) {
    push(@commands,"make INSTALL_PREFIX=$ins_dir install");
  }
  else {
    if ($option{'n'}=~/john/) {
      push(@commands,"mkdir -p $ins_pkg_dir/bin");
      push(@commands,"(cd run ; /usr/sfw/bin/gtar -cpf - . )|(cd $ins_pkg_dir/bin ; /usr/sfw/bin/gtar -xpf - )");
    }
    else {
      push(@commands,"make DESTDIR=$ins_dir install");
    }
  }
  if ($option{'n'}=~/setoolkit/) {
    push(@commands,"cp $ins_pkg_dir/bin/se $ins_pkg_dir/bin/se.orig");
    push(@commands,"cat $ins_pkg_dir/bin/se.orig |sed 's,^ARCH.*,ARCH=\"\",' > $ins_pkg_dir/bin/se");
    push(@commands,"rm $ins_pkg_dir/bin/se.orig");
    if ($option{'r'}=~/6/) {
      $se_version="3.2.1"
    }
    if ($option{'r'}=~/7|8/) {
      $se_version="3.3.1"
    }
    if ($option{'r'}=~/9|10/) {
      $se_version="3.4"
    }
    push(@commands,"cp $ins_pkg_dir/bin/se $ins_pkg_dir/bin/se.orig");
    push(@commands,"cat $ins_pkg_dir/bin/se.orig |sed 's,SEINCLUDE=\"\$TOP\"/include.*,SEINCLUDE=\"\$TOP\"/include:$real_install_dir/lib/SE/$se_version,' > $ins_pkg_dir/bin/se");
    push(@commands,"rm $ins_pkg_dir/bin/se.orig");
  }
  if ($option{'n'}=~/openssh/) {
    push(@commands,"cp $ins_pkg_dir/etc/sshd_config $ins_pkg_dir/etc/sshd_config.orig");
    push(@commands,"cat $ins_pkg_dir/etc/sshd_config.orig |sed 's,^#UsePAM no.*,UsePAM yes,' > $ins_pkg_dir/etc/sshd_config");
    push(@commands,"rm $ins_pkg_dir/etc/sshd_config.orig");
  }
  if ($option{'n'}=~/orca/) {
    # If GNU tools are installed the configure script finds them
    # Replace them with the standard tools in the orca scripts
    push(@commands,"cp $ins_pkg_dir/bin/start_orca_services $ins_pkg_dir/bin/start_orca_services.orig");
    push(@commands,"cat $ins_pkg_dir/bin/start_orca_services.orig |sed 's,^\$CAT=.*,\$CAT=/bin/cat,' > $ins_pkg_dir/bin/start_orca_services");
    push(@commands,"rm $ins_pkg_dir/bin/start_orca_services.orig");

    push(@commands,"cp $ins_pkg_dir/bin/start_orca_services $ins_pkg_dir/bin/start_orca_services.orig");
    push(@commands,"cat $ins_pkg_dir/bin/start_orca_services.orig |sed 's,^\$ECHO=.*,\$ECHO=/bin/echo,' > $ins_pkg_dir/bin/start_orca_services");
    push(@commands,"rm $ins_pkg_dir/bin/start_orca_services.orig");

    push(@commands,"cp $ins_pkg_dir/bin/start_orca_services $ins_pkg_dir/bin/start_orca_services.orig");
    push(@commands,"cat $ins_pkg_dir/bin/start_orca_services.orig |sed 's,^\$TOUCH=.*,\$TOUCH=/bin/touch,' > $ins_pkg_dir/bin/start_orca_services");
    push(@commands,"rm $ins_pkg_dir/bin/start_orca_services.orig");

    # Fix up location of SE

    push(@commands,"cp $ins_pkg_dir/bin/start_orcallator $ins_pkg_dir/bin/start_orcallator.orig");
    push(@commands,"cat $ins_pkg_dir/bin/start_orcallator.orig |sed 's,^SE=.*,SE=$real_install_dir/bin/se,' > $ins_pkg_dir/bin/start_orcallator");
    push(@commands,"rm $ins_pkg_dir/bin/start_orcallator.orig");

    push(@commands,"cp $ins_pkg_dir/bin/start_orcallator $ins_pkg_dir/bin/start_orcallator.orig");
    push(@commands,"cat $ins_pkg_dir/bin/start_orcallator.orig |sed 's,\$libdir/orcallator,$real_install_dir/share/setoolkit/orcallator/orcallator,' > $ins_pkg_dir/bin/start_orcallator");
    push(@commands,"rm $ins_pkg_dir/bin/start_orcallator.orig");

    # Fix configuration files

    push(@commands,"cp $ins_pkg_dir/etc/orca_services.cfg $ins_pkg_dir/etc/orca_services.cfg.orig");
    push(@commands,"cat $ins_pkg_dir/etc/orca_services.cfg.orig |sed 's,$real_install_dir/orca,/var/orca,' > $ins_pkg_dir/etc/orca_services.cfg");
    push(@commands,"rm $ins_pkg_dir/etc/orca_services.cfg.orig");

    push(@commands,"cp $ins_pkg_dir/etc/orca_services.cfg $ins_pkg_dir/etc/orca_services.cfg.orig");
    push(@commands,"cat $ins_pkg_dir/etc/orca_services.cfg.orig |sed 's,/var/orca/var,/var/orca,' > $ins_pkg_dir/etc/orca_services.cfg");
    push(@commands,"rm $ins_pkg_dir/etc/orca_services.cfg.orig");

    push(@commands,"cp $ins_pkg_dir/etc/orcallator.cfg $ins_pkg_dir/etc/orcallator.cfg.orig");
    push(@commands,"cat $ins_pkg_dir/etc/orcallator.cfg.orig |sed 's,$real_install_dir/orca,/var/orca,' > $ins_pkg_dir/etc/orcallator.cfg");
    push(@commands,"rm $ins_pkg_dir/etc/orcallator.cfg.orig");

    push(@commands,"cp $ins_pkg_dir/etc/orcallator.cfg $ins_pkg_dir/etc/orcallator.cfg.orig");
    push(@commands,"cat $ins_pkg_dir/etc/orcallator.cfg.orig |sed 's,/var/orca/var,/var/orca,' > $ins_pkg_dir/etc/orcallator.cfg");
    push(@commands,"rm $ins_pkg_dir/etc/orcallator.cfg.orig");

    push(@commands,"cp $ins_pkg_dir/etc/orcallator.cfg $ins_pkg_dir/etc/orcallator.cfg.orig");
    push(@commands,"cat $ins_pkg_dir/etc/orcallator.cfg.orig |sed 's,/orcallator\$,,' > $ins_pkg_dir/etc/orcallator.cfg");
    push(@commands,"rm $ins_pkg_dir/etc/orcallator.cfg.orig");

    push(@commands,"cp $ins_pkg_dir/etc/procallator.cfg $ins_pkg_dir/etc/procallator.cfg.orig");
    push(@commands,"cat $ins_pkg_dir/etc/procallator.cfg.orig |sed 's,$real_install_dir/orca,/var,' > $ins_pkg_dir/etc/procallator.cfg");
    push(@commands,"rm $ins_pkg_dir/etc/procallator.cfg.orig");

    push(@commands,"cp $ins_pkg_dir/etc/procallator.cfg $ins_pkg_dir/etc/procallator.cfg.orig");
    push(@commands,"cat $ins_pkg_dir/etc/procallator.cfg.orig |sed 's,/var/orca/var,/var/orca,' > $ins_pkg_dir/etc/procallator.cfg");
    push(@commands,"rm $ins_pkg_dir/etc/procallator.cfg.orig");

    push(@commands,"cp $ins_pkg_dir/etc/winallator.cfg $ins_pkg_dir/etc/winallator.cfg.orig");
    push(@commands,"cat $ins_pkg_dir/etc/winallator.cfg.orig |sed 's,$real_install_dir/orca,/var,' > $ins_pkg_dir/etc/winallator.cfg");
    push(@commands,"rm $ins_pkg_dir/etc/winallator.cfg.orig");

    push(@commands,"cp $ins_pkg_dir/etc/winallator.cfg $ins_pkg_dir/etc/winallator.cfg.orig");
    push(@commands,"cat $ins_pkg_dir/etc/winallator.cfg.orig |sed 's,/var/orca/var,/var/orca,' > $ins_pkg_dir/etc/winallator.cfg");
    push(@commands,"rm $ins_pkg_dir/etc/winallator.cfg.orig");

    push(@commands,"cp $ins_pkg_dir/bin/orca_services_running $ins_pkg_dir/bin/orca_services_running.orig");
    push(@commands,"cat $ins_pkg_dir/bin/orca_services_running.orig |sed 's,$real_install_dir/orca/var,/var/orca,' > $ins_pkg_dir/bin/orca_services_running");
    push(@commands,"rm $ins_pkg_dir/bin/orca_services_running.orig");

    push(@commands,"cp $ins_pkg_dir/bin/orcallator_running $ins_pkg_dir/bin/orcallator_running.orig");
    push(@commands,"cat $ins_pkg_dir/bin/orcallator_running.orig |sed 's,$real_install_dir/orca/var/orcallator,/var/orca,' > $ins_pkg_dir/bin/orcallator_running");
    push(@commands,"rm $ins_pkg_dir/bin/orcallator_running.orig");

    push(@commands,"cp $ins_pkg_dir/bin/start_orca_services $ins_pkg_dir/bin/start_orca_services.orig");
    push(@commands,"cat $ins_pkg_dir/bin/start_orca_services.orig |sed 's,$real_install_dir/orca/var,/var/orca,' > $ins_pkg_dir/bin/start_orca_services");
    push(@commands,"rm $ins_pkg_dir/bin/start_orca_services.orig");

    push(@commands,"cp $ins_pkg_dir/bin/start_orcallator $ins_pkg_dir/bin/start_orcallator.orig");
    push(@commands,"cat $ins_pkg_dir/bin/start_orcallator.orig |sed 's,$real_install_dir/orca/var/orcallator,/var/orca,' > $ins_pkg_dir/bin/start_orcallator");
    push(@commands,"rm $ins_pkg_dir/bin/start_orcallator.orig");
  }
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

# Create mog file for transmogrification

sub create_mog {
  my $spool_dir="$work_dir/spool";
  my $mog_file="$spool_dir/$option{'n'}.mog";
  my $version_string="set name=pkg.fmri value=application/$option{'n'}\@$option{'v'},1.0";
  my $info_string="set name=pkg.description value=\"$option{'n'}\"";
  my $summary_string="set name=pkg.summary value=\"$option{'n'} $option{'v'}\"";
  my $arch_string+"set name=variant.arch value=$option{'a'}";
  my $class_string="set name=info.classification value=\"org.opensolaris.category.2008:Applications/System Utilities\"";

  if ($option{'n'}=~/wget/) {
    $summary_string="set name=pkg.summary value=\"GNU Wget is a free software package for retrieving files using HTTP, HTTPS and FTP\"";
  }
  open MOG_FILE,">$mog_file";
  print MOG_FILE "$version_string\n";
  print MOG_FILE "$info_string\n";
  print MOG_FILE "$summary_string\n";
  print MOG_FILE "$arch_string\n";
  print MOG_FILE "$class_string\n";
  if ($option{'n'}=~/puppet/) {
    print MOG_FILE "depend fmri=pkg://burst/application/facter type=require\n"
  }
  close MOG_FILE;
  return;
}

sub create_ips {
  my @commands;
  my $command;
  my $ins_dir="$work_dir/ins";
  my $spool_dir="$work_dir/spool";
  my $manifest="$spool_dir/$option{'n'}.p5m";
  my $manifest_1="$spool_dir/$option{'n'}.p5m.1";
  my $manifest_2="$spool_dir/$option{'n'}.p5m.2";
  my $mog_file="$spool_dir/$option{'n'}.mog";

  push(@commands,"pkgsend generate . |pkgfmt > $manifest_1");
  push(@commands,"pkgmogrify -DARCH=`uname -p` $manifest_1 $mog_file |pkgfmt > $manifest_2");
  push(@commands,"pkgdepend generate -md  . $manifest_2 |pkgfmt  |sed 's/path=usr owner=root group=bin/path=usr owner=root group=sys/g' |sed 's/path=etc owner=root group=bin/path=usr owner=root group=sys/g' > $manifest");
  push(@commands,"pkgdepend resolve -m $manifest");
  foreach $command (@commands) {
    print_debug("Executing: $command","short");
    system ("cd $ins_dir ; $command");
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
  my $lib_dir;

  # Reminder:
  # ins_dir = Root of work directory, eg /export/home/user/burst/ins
  # This is the directory that DESTDIR will be give to simulate installing into /
  # ins_pkg_dir is the package specific directory, eg /export/home/user/burst/ins/usr/local
  # This would be used to simulate /use/local under DESTDIR
  # Out of politeness it would be good to direct configs to $ins_pkg_dir/etc (/usr/local/etc)
  # rather than $ins_dir/etc (/etc) so the package keeps things away from the system
  # as much as possible

  # If there are any package specific scripts copy them into the spool directory

  if ($os_name=~/SunOS/) {
    $lib_dir="/usr/lib";
  }
  else {
    if ($os_arch=~/64/) {
      $lib_dir="/lib64";
    }
    else {
      $lib_dir="/lib";
    }
  }
  ($header,$user_name)=split('\(',$user_name);
  ($header,$group_name)=split('\(',$group_name);
  $user_name=~s/\)//g;
  $group_name=~s/\)//g;
  if ((-e "$spool_dir")&&($spool_dir=~/[A-z]/)) {
    print "Cleaning up $spool_dir...\n";
    system("cd $spool_dir ; rm -rf *");
  }
  if ($option{'B'}) {
    if ($option{'p'}=~/rsa/) {
      if ($user_name!~/root/) {
        if (! -e "$spool_dir/uninstall_pam.sh") {
          print "Execute the following commands as root and re-run scripr:\n";
          print "mkdir -p $ins_dir/opt/pam\n";
          print "(cd /opt/pam ; tar -cpf - . )|( cd $ins_dir/opt/pam ; tar -xpf - )\n";
          print "find $lib_dir -name \"*securid*\" |cpio -pdm $ins_dir\n";
          print "find /etc -name sd_pam.conf |cpio -pdm $ins_dir\n";
          print "find /var/ace -name sdconf.rec |cpio -pdm $ins_dir\n";
          print "chown -R $user_name $ins_dir\n";
          exit;
        }
      }
      else {
        system("mkdir -p $ins_dir/opt/pam");
        system("chown root:bin $ins_dir/opt/pam");
        system("chmod 400 $ins_dir/opt/pam");
        system("(cd /opt/pam ; tar -cpf - . )|( cd $ins_dir/opt/pam ; tar -xpf - )");
        system("find $lib_dir -name \"*securid*\" |cpio -pdm $ins_dir");
        system("find /etc -name sd_pam.conf |cpio -pdm $ins_dir");
        system("find /var/ace -name sdconf.rec |cpio -pdm $ins_dir");
      }
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
  if ($option{'n'}=~/rsa/) {
    print PROTO_FILE "1 d none opt/pam 0700 root bin\n";
    print PROTO_FILE "1 d none opt/pam/bin 0700 root bin\n";
    print PROTO_FILE "1 d none opt/pam/bin/32bit 0700 root bin\n";
    print PROTO_FILE "1 d none opt/pam/bin/64bit 0700 root bin\n";
    print PROTO_FILE "1 d none opt/pam/doc 0700 root bin\n";
    print PROTO_FILE "1 d none opt/pam/lib 0700 root bin\n";
    print PROTO_FILE "1 d none opt/pam/lib/32bit 0700 root bin\n";
    print PROTO_FILE "1 d none opt/pam/lib/64bit 0700 root bin\n";
    print PROTO_FILE "1 d none var/ace 0755 root sys\n";
  }
  foreach $script_name (@script_names) {
    if (-e "$script_dir/$option{'n'}.$script_name") {
      system("cp $script_dir/$option{'n'}.$script_name $spool_dir/$script_name");
      system("chmod +x $spool_dir/$script_name");
      print PROTO_FILE "i $script_name=./$script_name\n";
    }
  }
  if ($option{'n'}=~/orca|openssh|bsl|rsa/) {
    # Add postinstall and preremove scripts to package
    print PROTO_FILE "i postinstall=./postinstall\n";
    print PROTO_FILE "i preremove=./preremove\n";
    open POSTINSTALL_FILE,">$postinstall_file";
    print POSTINSTALL_FILE "#!/bin/sh\n";
    open PREREMOVE_FILE,">$preremove_file";
    print PREREMOVE_FILE "#!/bin/sh\n";
    if ($option{'n'}=~/rsa/) {
      print PREREMOVE_FILE "rm /var/ace/sdopts.rec\n";
      print PREREMOVE_FILE "rm /var/ace/sdstatus*\n";
      print PREREMOVE_FILE "rm /var/ace/securid\n";
      print POSTINSTALL_FILE "# Create /var/ace/sdopts.rec\n";
      print POSTINSTALL_FILE "host_name=`hostname`\n";
      print POSTINSTALL_FILE "host_ip=`/usr/sbin/host \$host_name |awk '{print \$4}'`\n";
      print POSTINSTALL_FILE "echo \"CLIENT_IP=\$host_ip\" > /var/ace/sdopts.rec\n";
      print POSTINSTALL_FILE "chmod 640 /var/ace/sdopts.rec\n";
      print POSTINSTALL_FILE "chown root:root /var/ace/sdopts.rec\n";
    }
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
  if ($option{'B'}) {
    if ($option{'n'}=~/rsa/) {
      $command="cd $ins_dir ; find . -type f -print |grep -v './pkginfo' |grep -v './prototype' |grep -v './postinstall' |grep -v './preremove' |grep -v './preinstall' |grep -v './postremove' |grep -v './checkinstall' |pkgproto | sed 's/$user_name $group_name/$dir_user $dir_group/g' >> $proto_file";
    }
    else {
      $command="cd $ins_dir ; find . -print |grep -v './pkginfo' |grep -v './prototype' |grep -v './postinstall' |grep -v './preremove' |grep -v './preinstall' |grep -v './postremove' |grep -v './checkinstall' |pkgproto | sed 's/$user_name $group_name/$dir_user $dir_group/g' >> $proto_file";
    }
  }
  else {
    $command="cd $ins_dir ; find . -print |grep -v './pkginfo' |grep -v './prototype' |grep -v './postinstall' |grep -v './preremove' |grep -v './preinstall' |grep -v './postremove' |grep -v './checkinstall' |pkgproto | sed 's/$user_name $group_name/$dir_user $dir_group/g' >> $proto_file";
  }
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
  my $ins_dir;
  my $lib_dir;
  my $file_name;
  my @file_array;

  if ($os_arch=~/64/) {
    $lib_dir="/lib64";
  }
  else {
    $lib_dir="/lib";
  }
  $user_name=`whoami`;
  chomp($user_name);
  $ins_dir="$work_dir/BUILDROOT/$option{'n'}-$option{'v'}-1.$os_arch";
  chomp($ins_dir);
  print_debug("Creating $spec_file","long");
  open SPEC_FILE,">$spec_file";
  print SPEC_FILE "Version:\t$option{'v'}\n";
  print SPEC_FILE "Name:\t\t$option{'n'}\n";
  if ($option{'n'}=~/john/) {
    $option{'d'}="John the Ripper is a fast password cracker";
  }
  if ($option{'n'}=~/bsl/) {
    $option{'d'}="Bash compiled with syslog support";
  }
  if ($option{'n'}) {
   $option{'d'}="RSA SecurID PAM Agent";
   $option{'u'}="http://www.rsa.com";
  }
  print SPEC_FILE "Summary:\t$option{'d'}\n";
  print SPEC_FILE "Release:\t1\n";
  print SPEC_FILE "Group:\t\t$option{'c'}\n";
  print SPEC_FILE "Vendor:\t$vendor_string\n";
  print SPEC_FILE "Distribution:\t$pkg_base_name\n";
  print SPEC_FILE "License:\t$option{'l'}\n";
  if ($option{'n'}=~/john/) {
    $option{'u'}="http://www.openwall.com/john/";
    $option{'f'}="http://www.openwall.com/john/g/john-$option{'v'}.tar.gz"
  }
  if ($option{'n'}=~/bsl/) {
    $option{'u'}="http://www.gnu.org/software/bash/";
    $option{'f'}="http://ftp.gnu.org/gnu/bash/bash-$option{'v'}.tar.gz"
  }
  print SPEC_FILE "URL:\t\t$option{'u'}\n";
  if (!$option{'B'}) {
    print SPEC_FILE "Source0:\t$option{'f'}\n";
    if ($option{'n'}=~/bsl/) {
      print SPEC_FILE "Source1:\thttps://raw.github.com/richardatlateralblast/bsl.postinstall/master/bsl.postinstall\n";
      print SPEC_FILE "Source2:\thttps://raw.github.com/richardatlateralblast/bsl.preremove/master/bsl.preremove\n";
    }
    if ($option{'n'}=~/bsl/) {
      print SPEC_FILE "Patch1:\thttps://raw.github.com/richardatlateralblast/bash-4.2-bashhist.c.patch/master/bash-4.2-bashhist.c.patch\n";
    }
    print SPEC_FILE "BuildRoot:\t%{_tmppath}/%{name}-%{version}-%{release}\n";
  }
  print SPEC_FILE "\n";
  print SPEC_FILE "%description\n";
  print SPEC_FILE "$option{'d'}\n";
  print SPEC_FILE "\n";
  if (!$option{'B'}) {
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
  }
  if ($option{'B'}) {
    if ($option{'n'}=~/rsa/) {
      if ($user_name!~/root/) {
        if (! -e "$ins_dir/uninstall_pam.sh") {
          print "Execute the following commands as root and re-run scripr:\n";
          print "mkdir -p $ins_dir/opt/pam\n";
          print "(cd /opt/pam ; tar -cpf - . )|( cd $ins_dir/opt/pam ; tar -xpf - )\n";
          print "find /opt/pam |cpio -pdm $ins_dir\n";
          print "find /etc -name sd_pam.conf \"*securid*\" |cpio -pdm $ins_dir\n";
          print "find /var/ace -name stdconf.rec \"*securid*\" |cpio -pdm $ins_dir\n";
          print "chown -R $user_name $ins_dir\n";
          exit;
        }
      }
      else {
        system("mkdir -p $ins_dir/opt/pam");
        system("chown root:bin $ins_dir/opt/pam");
        system("chmod 400 $ins_dir/opt/pam");
        system("find /opt/pam |cpio -pdm $ins_dir");
        system("find $lib_dir -name \"*securid*\" |cpio -pdm $ins_dir");
        system("find /etc -name sd_pam.conf |cpio -pdm $ins_dir");
        system("find /var/ace -name sdconf.rec |cpio -pdm $ins_dir");
      }
    }
  }
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
  if ($option{'n'}=~/rsa/) {
    @file_array=`cd $ins_dir ; find . -type f -o -type s |sed 's/^\.//g'`;
    foreach $file_name (@file_array) {
      print SPEC_FILE "$file_name";
    }
  }
  else {
    print SPEC_FILE "/opt/%{distribution}/*\n";
  }
  print SPEC_FILE "\n";
  if ($option{'n'}=~/bsl/) {
    print SPEC_FILE "%post\n";
    print SPEC_FILE "/opt/%{distribution}/etc/$option{'n'}.postinstall\n";
    print SPEC_FILE "/opt/%{distribution}/etc/$option{'n'}.preremove\n";
  }
  if ($option{'n'}=~/bsl/) {
    print SPEC_FILE "%preun\n";
    print SPEC_FILE "\n";
    print SPEC_FILE "\n";
  }
  if ($option{'n'}=~/rsa/) {
    print SPEC_FILE "%post\n";
    print SPEC_FILE "rm /var/ace/sdopts.rec\n";
    print SPEC_FILE "rm /var/ace/sdstatus*\n";
    print SPEC_FILE "rm /var/ace/securid\n";
    print SPEC_FILE "\n";
    print SPEC_FILE "%preun\n";
    print SPEC_FILE "# Create /var/ace/sdopts.rec\n";
    print SPEC_FILE "host_name=`hostname`\n";
    print SPEC_FILE "host_ip=`host \$host_name |awk '{print \$4}'`\n";
    print SPEC_FILE "echo \"CLIENT_IP=\$host_ip\" > /var/ace/sdopts.rec\n";
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
