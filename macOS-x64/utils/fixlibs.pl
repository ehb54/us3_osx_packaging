#!/usr/bin/perl

$notes = "usage: $0 lib ...

check load name of libs and fix if needed

";

die $notes if !@ARGV;

use File::Basename;

for my $lib ( @ARGV ) {
    $lib =~ s/\/$//;

    die "$lib doesn't appear to be a dylib (should be named .dylib)\n" if $lib !~ /\.dylib/;

    
    my $f = $lib;

    die "$f does not exist\n" if !-e $f;

    print "$f\n";

    ## otool analysis
    my $cmds;

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
        if ( $d =~ /^\@rpath\/(Qt|qwt\.|lib\/)/ ) {
            next;
        }

        print "$ba dep $d\n";

        if ( $d =~ /\.framework/ ) {
            my $bd = $d;
            $bd =~ s/^(\@rpath\/|\@executable_path\/|\.\.\/)+//g;
            $bd =~ s/Frameworks\/Frameworks/Frameworks/;
            print "$d\n-->\@rpath/$bd\n";
            $cmds .= "install_name_tool -change $d \@rpath/$bd $f\n";
            next;
        }

        if ( $d =~ /^(\/opt|lib|\/usr\/local|\/User|\@rpath\/lib|\@executable_path)/ ) {
            my $bd = basename( $d );
            $bd =~ s/Frameworks\/Frameworks/Frameworks/;
            $cmds .= "install_name_tool -change $d \@rpath/lib/$bd $f\n";
            next;
        }

        die "don't know what to do [$d] " . basename( $d ) . "\n";
    }

    $cmds .= "codesign -fs - $f\n";
    print $cmds;
    print `$cmds`;
}
