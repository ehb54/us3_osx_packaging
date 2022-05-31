#!/usr/bin/perl


$notes = "usage: $0 files

runs otool -L and extracts LC_VERSION_MIN_MAXOSX info

";


die $notes if !@ARGV;

while ( $f = shift @ARGV ) {
    die "$f not found\n" if !-e $f;
    my $cmd = "otool -l $f";
    my @res = `$cmd`;

    my $found;

    for ( my $i = 0; $i < @res; ++$i ) {
        my $l = $res[$i];
        if ( $l =~ /cmd (LC_VERSION_MIN_MACOSX|LC_BUILD_VERSION)/ ) {
            my $found;
            for ( ; $i < @res; ++$i ) {
                $l = $res[$i];
                if ( $l =~ /(version|minos)/ ) {
                    $found = 1;
                    print "$f $l";
                    last;
                }
                last if $l =~ /Load command/;
            }
            print "$f no version found\n" if !$found;
            last;
        }
    }
}
            
        
        
    
