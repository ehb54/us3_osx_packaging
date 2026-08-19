#!/usr/bin/perl

$reqformat = 'application';

$sudo = ""; # sudo should not be needed

$notes = "usage: $0 dir

copies files needed to run to specified dir

dir must contain $reqformat

";

$tdir = shift || die $notes;

$cwd = `pwd`;
chomp $cwd;

die "bad directory $tdir must contain '$reqformat'\n" if $tdir !~ /$reqformat/;

@dirs = (
    "Frameworks"
    ,"plugins"
    ,"lib"
    ,"bin"
    ,"etc"
    ,"somo/demo"
    ,"somo/doc"
    );

@files = (
    "LICENSE.txt"
    );

## patterns kept out of the package.
##
## GRPY and iftci ship in the source tree built for all three platforms, but a
## macOS build can only ever reference the _osx* variants: the suffix is chosen
## at compile time from Q_OS_MAC in us_somo/develop/src/us_container_grpy.cpp
## and us_somo/develop/src/us_hydrodyn_saxs_external.cpp, so the Windows and
## Linux copies are dead weight in a macOS package.
##
## Keep in sync with the non-macOS cleanup in
## macOS-x64/darwin/scripts/preinstall.

@excludes = (
    "*_win64.exe"
    ,"*_linux64"
    );

$excludeopts = join ' ', map { "--exclude='$_'" } @excludes;

@postcmds = (
## some bug in package builder... this seems to fix it
## not since I added assistant?    "cd $tdir/bin && cp -r us.app us3.app"
    );

## step 1 check sanity

if ( -d $tdir ) {
    print "directory exists, removing all contents\n";
    $cmd = "$sudo rm -fr $tdir/*";
    print "$cmd\n";
    sleep 3;
    print `$cmd`;
} else {
    print `mkdir $tdir`;
}
 
for $l ( @dirs ) {
    die "$l does not exist\n" if !-e $l;
}

for $f ( @files ) {
    die "$f does not exist\n" if !-e $f;
}

## rsync each to $tdir

$cmds = '';

for $l ( @dirs ) {
    $cmds .= "mkdir -p $tdir/$l && rsync -av $excludeopts $l/* $tdir/$l/\n";
}

for $f ( @files ) {
    $cmds .= "cp -pv $f $tdir/\n";
}

for $c ( @postcmds ) {
    $cmds .= "$c\n";
}

print $cmds;
 
print `$cmds`;
