#!/usr/bin/perl

$notes = "usage: $0 (list|update)

finds all libs of everything in bin, Frameworks, lib
and lists

update will copy needd libraries if found

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

$scriptpath = dirname(__FILE__);
$minosprog = "$scriptpath/minlibversion.pl";
die "$minosprog missing\n" if !-e $minosprog;
die "$minosprog not executable\n" if !-x $minosprog;

$installerpath = `cd $scriptpath && pwd -P | perl -pe 's/\\/[^\\/]+\$//'`;

## exclude XQuartz software for lib check errors
@xquartz =
    (
     "bin/rasmol"
    );

%xquartzmap = map { $_ => 1 } @xquartz;

## get apps

@apps = `find bin -type f`;

## prune apps

@apps = grep !/\.(lproj|plist)\s*$/, @apps;
@apps = grep !/(PkgInfo|icns|\.DS_Store)$/, @apps;
@apps = grep !/(win64|linux64|manual\.q)/, @apps;

## get libs

@libs = `find lib -type f`;

## get frameworks

### die if frameworks have Headers
{
    my @fheaders = `find Frameworks -type d -name Headers`;
    die "ERROR: Frameworks have Headers, remove before continuing\n" if @fheaders;
}

@frames = `find Frameworks -type f`;
@frames = grep !/\.(prl|plist)\s*$/, @frames;
@frames = grep !/Versions/, @frames;

push @all, @apps, @libs, @frames;

# print join '', @all;

grep chomp, @all;

for $f ( @all ) {
    ## check first for 'fatal error'
    `otool -L $f 2>/dev/null`;
    if ( $? ) {
        $otoolerrors{ $f }++;
        next;
    }

    ## check minos version

    {
        my $vers = `$minosprog $f | awk '{ print \$3 }'`;
        chomp $vers;
        $minos_versions  { $f } = $vers;
        $minos_count     { $vers }++;
        $minos_usedby    { $vers } .= "$f ";
    }

    ## dylibs & frameworks 2nd otool -L line is self-reference, apparently can be ignored
    ## 20241216 - test for self references and skip now performed later
    ### if not then special handling install_name_tool -id will be needed instead of -change

    my $deletelines = $f =~ /(dylib$|\.framework)/ ? "1,2d" : "1d";
#    print "otool -L $f | sed $deletelines | awk '{ print \$1 }'\n";
    my @deps = `otool -L $f | sed $deletelines | awk '{ print \$1 }'`;

    grep chomp, @deps;

# debug 20240615
#    print '-'x80 . "\n";
#    print "all item '$f'\n";
#    print '-'x80 . "\n";
# end debug

    ## catagorize & store deps
    for my $d ( @deps ) {
# debug 20240615
#        print "checking dep '$d' for allitem '$f' \n";
# end debug
        ## check for self reference & skip
        if ( $d =~ /.*$f$/ ) {
            ## debug 20241216
            # print "skiping self-referential dep '$d' for allitem '$f' \n";
            next;
        }
        if ( $d =~ /^\/System\/Library\/Frameworks/ ) {
            $syslibs{ $d }++;
            next;
        }

        if ( $d =~ /\@executable_path\// ) {
            my $checkfile = $d;
            $checkfile =~ s/^\@executable_path\/(\.\.\/)*//;
            if ( $checkfile =~ /\.framework/ ) {
                $checkfile = "Frameworks/$checkfile" if $checkfile !~ /^Frameworks\//;
            } elsif ( $checkfile != /^lib\// ) {
                $checkfile = "lib/$checkfile";
            }
            $tochecks{ $checkfile }++;
            $exepaths{ $d }++;
            $useexecs{ $d } .= $useexecs{ $d } ? " $f" : $f;
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

        if ( $xquartzmap{ $f } ) {
            $xquartzexcludes{ "$f : $d" }++;
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

# debug 20240615
# die "testing\n";

## extra checks

@extras = (
    "bin/Assistant.app"
    ,"bin/us3_somo.app"
    ,"bin/rasmol"
    ,"bin/manual.qch"
    ,"Frameworks"
    ,"plugins"
    );

for $f ( @extras ) {
    if ( !-e $f ) {
        $missing{ $f }++;
        $errorsum .= "ERROR: $f is missing\n";
    }
}

## check os versions
if ( keys %minos_count > 1 ) {
    $warnings .= "multiple minimum versions found " . ( join ' ', sort { $a <=> $b } keys %minos_count ) . "\n";
    my $count;
    for my $v ( keys %minos_usedby ) {
        $count += $minos_count{$v};
        $warnings .= " version $v - counts $minos_count{$v}\n\t$minos_usedby{$v}\n";
    }
    $warnings .= "total programs found $count\n";
}

$revfile = "programs/us/us_revision.h";
if ( !-e $revfile ) {
    $errorsum .= "ERROR: revision file $revfile is missing\n";
} else {
    $rev = `awk -F\\" '{ print \$2 }' $revfile`;
    chomp $rev;
}

### begin reports

print hdrline( "syslibs" );
print join "\n", sort { $a cmp $b } keys %syslibs;
print "\n" if keys %syslibs;

print hdrline( "exepaths" );
# print join "\n", sort { $a cmp $b } keys %exepaths;
for $d ( sort { $a cmp $b } keys %useexecs ) {
    print "$d\n    " . $useexecs{$d} . "\n";
}    

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

print hdrline( "xquartz excludes" );
print join "\n", sort { $a cmp $b } keys %xquartzexcludes;
print "\n" if keys %xquartzexcludes;

print hdrline( "minimum os version counts" );
for $d ( sort { $a cmp $b } keys %minos_count ) {
    print "$d : " . $minos_count{$d} . "\n";
}
print "\n" if keys %minos_count;

print hdrline( "todos" );
for $d ( sort { $a cmp $b } keys %todos ) {
    print "$d\n    " . $todos{$d} . "\n";
}    
$errorsum .= "WARNING: todos present, must be fixed before packaging\n" if keys %todos;

print hdrline( "missing" );
print join "\n", sort { $a cmp $b } keys %missing;
print "\n" if keys %missing;


### checks
print hdrline( "checking existence of libraries" );
print hdrline( "tochecks" );

my $cmds;

for $d ( sort { $a cmp $b } keys %tochecks ) {
    if ( -e $d ) {
        print "ok: $d\n";
    } else {
        my $err = "ERROR: missing lib: $d - ";
        if ( $copyfrom{ $d } ) {
            $err .= "copy from " .  $copyfrom{ $d };
            $cmds .= "cp " . $copyfrom{ $d } . " $d\n";
        } else {
            $err .= "unknown source";
        }
        print "$err\n";
        $errorsum .= "$err\n";
    }
}

### otool errors
print hdrline( "otoolerrors" );
for $d ( sort { $a cmp $b } keys %otoolerrors ) {
    my $err = "ERROR: otool -L returned an error attempting to list libraries on $d";
    $errorsum .= "$err\n";
    print "$err\n";
}    


if ( $warnings ) {
    print hdrline( "warnings" );
    print $warnings;
}

if ( $errorsum ) {
    print hdrline( "error summary" );
    print $errorsum;
}

if ( $rev && !keys %todos && !$errorsum && !$cmds ) {
    print hdrline( "build package commands" );
    my $cmd = "$scriptpath/makepkgdir.pl $installerpath/application
(cd $installerpath && yes n | ./build-macos-x64.sh UltraScan3 4.0.$rev && cp target/pkg/UltraScan3-macos-installer-x64-4.0.$rev.pkg ~/Downloads/UltraScan3-macos-installer-`uname -m`-4.0.$rev.pkg)";
    print "$cmd\n";
}

print hdrline( "cmds" );
print $cmds;

if ( $cmds && $update ) {
    print `$cmds`;
    print "WARNING: rerun until no cmds nor ERRORs left\n";
}

