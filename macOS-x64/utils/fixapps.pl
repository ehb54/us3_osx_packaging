#!/usr/bin/perl

$notes = "usage: $0 app ...

remakes symlinks in app for Frameworks & platforms

check load name of app and fix if needed

";

die $notes if !@ARGV;

use File::Basename;

$cmds .= "ln -sf ../lib Frameworks\n";
print $cmds;
print `$cmds`;

for my $a ( @ARGV ) {
    print "$a\n";

    $ba = basename( $a );
    
    my $cmds;

    die "$a doesn't appear to be an app directory (missing Contents/MacOS)\n" if !-d "$a/Contents/MacOS";

    ## symlinks

    $cmds .= "ln -sf ../../../Frameworks $a/Contents/\n";
    $cmds .= "ln -sf ../../../../platforms $a/Contents/MacOS/\n";
        
    ## otool analysis

    my $f = "$a/Contents/MacOS/$ba";
    $f =~ s/\.app$//;
    die "$f does not exist\n" if !-e $f;
    
    my @deps = `otool -L $f | sed 1,2d | awk '{ print \$1 }'`;
    grep chomp, @deps; 

    for ( my $i = 0; $i < @deps; ++$i ) {

        my $d = $deps[$i];

        if ( $d =~ /^\/System\/Library\/Frameworks/ ) {
            next;
        }
        if ( $d =~ /^\/usr\/lib\// ) {
            next;
        }
        if ( $d =~ /^\@rpath\/(Qt|qwt\.|lib)/ ) {
            next;
        }

        print "$ba dep $d\n";

        if ( $d =~ /\.framework/ ) {
            $cmds .= "install_name_tool -change $d \@rpath/$d $f\n";
            next;
        }

        if ( $d =~ /^(\/opt|lib)/ ) {
            my $bd = basename( $d );
            $cmds .= "install_name_tool -change $d \@rpath/lib/$bd $f\n";
            next;
        }

        die "don't know what to do with '$d'\n";
    }

    print $cmds;

    print `$cmds`;
}
