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

## get apps

@apps = `find bin -type f`;

## prune apps

@apps = grep !/\.(lproj|plist)\s*$/, @apps;
@apps = grep !/PkgInfo$/, @apps;
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

    ## dylibs & frameworks 2nd otool -L line is self-reference, apparently can be ignored
    ### if not then special handling install_name_tool -id will be needed instead of -change

    my $deletelines = $f =~ /(dylib$|\.framework)/ ? "1,2d" : "1d";
    my @deps = `otool -L $f | sed $deletelines | awk '{ print \$1 }'`;

    grep chomp, @deps;

    ## catagorize & store deps
    for my $d ( @deps ) {
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

### being reports


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


if ( $errorsum ) {
    print hdrline( "error summary" );
    print $errorsum;
}

print hdrline( "cmds" );
print $cmds;

if ( $cmds && $update ) {
    print `$cmds`;
    print "WARNING: rerun until no cmds nor ERRORs left\n";
}
