#!/usr/bin/perl

$notes = "usage: $0 framework ...

check load name of Frameworks and fix if needed

";

die $notes if !@ARGV;

use File::Basename;

for my $framework ( @ARGV ) {
    $framework =~ s/\/$//;

    die "$framework doesn't appear to be a Framework (should be named .framework)\n" if $framework !~ /\.framework$/;

    $fb = basename( $framework );
    $fn = $fb;
    $fn =~ s/\.framework$//;
    
    my $f = "$framework/$fn";

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
            $cmds .= "install_name_tool -change $d \@rpath/$d $f\n";
            next;
        }

        if ( $d =~ /^(\/opt|lib)/ ) {
            my $bd = basename( $d );
            $cmds .= "install_name_tool -change $d \@rpath/lib/$bd $f\n";
            next;
        }

        die "don't know what to do\n";
    }

    print $cmds;

    print `$cmds`;
}
