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
    $cmds .= "mkdir -p $tdir/$l && rsync -av $l/* $tdir/$l/\n";
}

for $f ( @files ) {
    $cmds .= "cp -pv $f $tdir/\n";
}

for $c ( @postcmds ) {
    $cmds .= "$c\n";
}

print $cmds;
 
print `$cmds`;
