#!/usr/bin/perl

$notes = "usage: $0 list

finds all libs of everything in bin, Frameworks, lib
and lists

";

$opt = shift || die $notes;

die $notes if $opt !~ /^(update|list)$/;

$update++ if $opt eq 'update';

sub line {
    return '-'x80 . "\n";
}

sub hdrline {
    my $msg = shift;
    return line() . "$msg\n" . line();
}

use File::Basename;

## get apps

@apps = `find bin -type f`;

## prune apps

@apps = grep !/\.(lproj|plist)\s*$/, @apps;
@apps = grep !/PkgInfo$/, @apps;
@apps = grep !/(win64|linux64|manual\.q)/, @apps;

## get libs

@libs = `find lib -type f`;

## get frameworks

@frames = `find Frameworks -type f`;
@frames = grep !/\.(prl|plist)\s*$/, @frames;
@frames = grep !/Versions/, @frames;


push @all, @apps, @libs, @frames;

# print join '', @all;

grep chomp, @all;

for $f ( @all ) {
    my @deps = `otool -L $f | sed 1,2d | awk '{ print \$1 }'`;
    grep chomp, @deps;

    ## catagorize & store deps
    for my $d ( @deps ) {
        if ( $d =~ /^\/System\/Library\/Frameworks/ ) {
            $syslibs{ $d }++;
            next;
        }

        if ( $d =~ /^\@executable_path\// ) {
            my $checkfile = $d;
            $checkfile =~ s/^\@executable_path\/(\.\.\/)*//;
            if ( $checkfile =~ /\.framework/ ) {
                $checkfile = "Frameworks/$checkfile" if $checkfile !~ /^Frameworks\//;
            } elsif ( $checkfile != /^lib\// ) {
                $checkfile = "lib/$checkfile";
            }
            $tochecks{ $checkfile }++;
            $exepaths{ $d }++;
            next;
        }
        if ( $d =~ /^\@rpath\// ) {
            my $checkfile = $d;
            $checkfile =~ s/^\@rpath\/(\.\.\/)*//;
            if ( $checkfile =~ /\.framework/ ) {
                $checkfile = "Frameworks/$checkfile" if $checkfile !~ /^Frameworks\//;
            } elsif ( $checkfile != /^lib\// ) {
                $checkfile = "lib/$checkfile";
            }
            
            $tochecks{ $checkfile }++;
            $rpaths{ $d }++;

            next;
        }
        if ( $d =~ /^\/usr\/lib\// ) {
            $usrlibs{ $d }++;
            next;
        }

        if ( $d =~ /\/.framework/ ) {
            my $checkfile = basename( $d );
            $checkfile = "Frameworks/$checkfile";
            $tochecks{ $checkfile }++;
        } elsif ( $d =~ /\/dylib/ ) {
            my $checkfile = basename( $d );
            $checkfile = "lib/$checkfile";
            $tochecks{ $checkfile }++;
        } elsif ( $d =~ /^\/opt/ ) {
            my $checkfile = basename( $d );
            $checkfile = "lib/$checkfile";
            $tochecks{ $checkfile }++;
            $copyfrom{ $checkfile } = $d;
        } elsif ( $d =~ /^lib[^\/]/ ) {
            my $checkfile = basename( $d );
            $checkfile = "lib/$checkfile";
            $tochecks{ $checkfile }++;
        }            

        $todos{ $d } .= $todos{ $d } ? " $f" : $f;
    }
}
    
print hdrline( "syslibs" );
print join "\n", sort { $a cmp $b } keys %syslibs;
print "\n" if keys %syslibs;

print hdrline( "exepaths" );
print join "\n", sort { $a cmp $b } keys %exepaths;
print "\n" if keys %exepaths;

print hdrline( "rpaths" );
print join "\n", sort { $a cmp $b } keys %rpaths;
print "\n" if keys %rpaths;

print hdrline( "usrlibs" );
print join "\n", sort { $a cmp $b } keys %usrlibs;
print "\n";

print hdrline( "ignores" );
print join "\n", sort { $a cmp $b } keys %ignores;
print "\n" if keys %ignores;

print hdrline( "todos" );
for $d ( sort { $a cmp $b } keys %todos ) {
    print "$d\n    " . $todos{$d} . "\n";
}    

### checks
print hdrline( "checking existence of libraries" );
print hdrline( "tochecks" );

my $cmds;

for $d ( sort { $a cmp $b } keys %tochecks ) {
    if ( -e $d ) {
        print "ok: $d\n";
    } else {
        print "ERROR MISSING LIB: $d - ";
        if ( $copyfrom{ $d } ) {
            print "copy from " .  $copyfrom{ $d };
            $cmds .= "cp " . $copyfrom{ $d } . " $d\n";
        } else {
            print "unknown source";
        }
        print "\n";
    }
}

print hdrline( "cmds" );
print $cmds;

if ( $cmds && $update ) {
    print `$cmds`;
    print "WARNING: rerun until no cmds left\n";
}




