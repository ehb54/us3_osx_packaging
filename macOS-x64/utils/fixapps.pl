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

    die "Error: $a/Contents/Frameworks is a directory\n" if -e "$a/Contents/Frameworks" && !-l "$a/Contents/Frameworks";
    die "Error: $a/Contents/platforms is a directory\n" if -e "$a/Contents/MacOS/platforms" && !-l "$a/Contents/MacOS/platforms";

    $cmds .= "ln -sf ../../../Frameworks $a/Contents/\n";
    $cmds .= "ln -sf ../../../../plugins/platforms $a/Contents/MacOS/platforms\n";
        
    ## otool analysis

    my $f = "$a/Contents/MacOS/$ba";
    $f =~ s/\.app$//;
    die "$f does not exist\n" if !-e $f;
    
    my @deps = `otool -L $f | sed 1d | awk '{ print \$1 }'`;
    grep chomp, @deps; 

    for ( my $i = 0; $i < @deps; ++$i ) {

        my $d = $deps[$i];

        if ( $d =~ /^\/System\/Library\/Frameworks/ ) {
            next;
        }
        if ( $d =~ /^\/usr\/lib\// ) {
            next;
        }
        if ( $d =~ /^\@rpath\/(Qt|qwt\.|lib\/)/ ) {
            next;
        }

        print "$ba dep $d $duse\n";

        if ( $d =~ /\.framework/ ) {
            my $dnew = $d;
            $dnew =~ s/^.*\/Frameworks\///;
            $cmds .= "install_name_tool -change $d \@rpath/$dnew $f\n";
            next;
        }

        if ( $d =~ /^(\/opt|lib|\/usr\/local|\/Users|\@rpath\/lib)/ ) {
            my $bd = basename( $d );
            $cmds .= "install_name_tool -change $d \@rpath/lib/$bd $f\n";
            next;
        }

        die "don't know what to do with '$d'\n";
    }

    print $cmds;

    print `$cmds`;
}
