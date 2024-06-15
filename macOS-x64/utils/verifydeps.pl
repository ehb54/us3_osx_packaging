#!/usr/bin/perl

$notes = "usage: $0 args

list dependencies of given arguments

";

die $notes if !@ARGV;

use File::Basename;

for my $f ( @ARGV ) {

    print "-"x80 . "\n";
    print "$f\n";
    print "-"x80 . "\n";

    ## otool analysis

    my @deps = `otool -L $f | sed 1,2d | awk '{ print \$1 }'`;
    grep chomp, @deps; 

    print join( "\n", @deps );
    print "\n";
}
