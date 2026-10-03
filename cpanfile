# burst.pl only uses core modules, which are normally already installed.
# If any are missing, burst.pl installs them itself with cpanm or cpan at startup.
# Pragmas and modules used: strict, Getopt::Std, File::Basename

requires 'perl', '5.006';
requires 'Getopt::Std';
requires 'File::Basename';
