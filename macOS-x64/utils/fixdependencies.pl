#!/usr/bin/perl

$notes = "usage: $0 (list|update|prunelist|prune)

finds all libs of everything in bin, Frameworks, lib
and lists

update will copy needd libraries if found

prunelist reports Frameworks, libs & plugins not referenced by any
packaged program, plus non-macOS binaries in bin (run after 'update' converges)

prune moves them aside into ./pruned (review with prunelist first)

";

$opt = shift || die $notes;

die $notes if $opt !~ /^(update|list|prunelist|prune)$/;

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

## programs to exclude from the macOS package
@excluded_progs = qw(
    us_comproject
    us_comproject_academic
    us_protocoldev
    us_reporter_gmp
    us_audit_trail_gmp
    us_esigner_gmp
);
my $excluded_re = join '|', map { quotemeta($_) . '(?:[.\\/]|$)' } @excluded_progs;

if ( $opt =~ /^prune/ ) {
    do_prune( $opt eq 'prune' );
    exit;
}

## get apps

@apps = `find bin -type f`;

## prune apps

@apps = grep !/\.(lproj|plist)\s*$/, @apps;
@apps = grep !/(PkgInfo|icns|\.DS_Store)$/, @apps;
@apps = grep !/(win64|linux64|manual\.q)/, @apps;
@apps = grep !/$excluded_re/, @apps if @excluded_progs;

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

$revfile   = "programs/us/us_revision.h";
$verfile   = "utils/us_defines.h";
if ( !-e $revfile ) {
    $errorsum .= "ERROR: revision file $revfile is missing\n";
} elsif ( !-e $verfile ) {
    $errorsum .= "ERROR: version file $verfile is missing\n";
} else {
    my $buildnum  = `awk -F'"' '/BUILDNUM/ { print \$2 }' $revfile`;
    chomp $buildnum;
    my $usversion = `awk -F'"' '/US_Version/ { print \$2 }' $verfile`;
    chomp $usversion;
    $rev = "$usversion-build-$buildnum";
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
    my $stagedir = "$installerpath/application";
    my $rmcmds = '';
    for my $p ( @excluded_progs ) {
        $rmcmds .= "rm -rf $stagedir/bin/$p.app $stagedir/bin/$p\n";
    }
    my $cmd = "$scriptpath/makepkgdir.pl $stagedir
${rmcmds}(cd $installerpath && yes n | ./build-macos-x64.sh UltraScan3 $rev && cp target/pkg/UltraScan3-macos-installer-x64-$rev.pkg ~/Downloads/UltraScan3-macos-installer-`uname -m`-$rev.pkg)";
    print "$cmd\n";
}

print hdrline( "cmds" );
print $cmds;

if ( $cmds && $update ) {
    print `$cmds`;
    print "WARNING: rerun until no cmds nor ERRORs left\n";
}


## ------------------------------------------------------------------
## prune support - remove Frameworks, libs & plugins nothing references
## ------------------------------------------------------------------

sub prune_resolve_dep {
    ## map an otool -L dependency to a package-relative node
    ## returns ( type, node ) with type one of system, framework, lib, unknown
    my ( $d ) = @_;
    return ( 'system' ) if $d =~ /^\/System\/Library\//;
    return ( 'system' ) if $d =~ /^\/usr\/lib\//;
    return ( 'framework', "Frameworks/$1" ) if $d =~ /([^\/]+\.framework)/;
    my $b = basename( $d );
    return ( 'lib', "lib/$b" ) if $b =~ /^lib/ || $b =~ /\.dylib$/;
    return ( 'unknown', $d );
}

sub prune_file_deps {
    ## otool -L deps of one file, self-reference removed
    my ( $f ) = @_;
    my @lines = `otool -L "$f" 2>/dev/null`;
    return if $?;
    shift @lines;
    my $bf = basename( $f );
    my @deps;
    for ( @lines ) {
        chomp;
        s/^\s+//;
        s/\s+\(.*$//;
        next if !length;
        next if basename( $_ ) eq $bf;
        push @deps, $_;
    }
    return @deps;
}

sub prune_du_k {
    my $t = 0;
    for my $p ( @_ ) {
        $t += (split ' ', `du -sk "$p"`)[0];
    }
    return $t;
}

sub do_prune {
    my ( $execute ) = @_;

    for my $d ( qw(bin lib Frameworks plugins) ) {
        die "prune: required directory '$d' missing - run from the build tree\n" if !-d $d;
    }

    ## roots : the apps we actually package

    my @papps = `find bin -type f`;
    grep chomp, @papps;
    @papps = grep !/\.(lproj|plist)$/, @papps;
    @papps = grep !/(PkgInfo|icns|\.DS_Store)$/, @papps;
    @papps = grep !/(win64|linux64|manual\.q)/, @papps;
    @papps = grep !/$excluded_re/, @papps if @excluded_progs;
    @papps = grep { !$xquartzmap{ $_ } } @papps;

    ## frameworks present : node -> binary files inside

    my %fwfiles;
    for my $fw ( `find Frameworks -mindepth 1 -maxdepth 1 -type d -name '*.framework'` ) {
        chomp $fw;
        my @files = `find "$fw" -type f`;
        grep chomp, @files;
        @files = grep !/\.(prl|plist|pak|dat|qm|h)$/, @files;
        $fwfiles{ $fw } = [ @files ];
    }

    ## libs present

    my %libnodes;
    for my $l ( `find lib -mindepth 1 -maxdepth 1 \\( -type f -o -type l \\)` ) {
        chomp $l;
        $libnodes{ $l }++;
    }

    ## dependency edges

    my %edges;     ## node -> { dep node -> count }
    my %unknowns;  ## unresolvable deps, informational

    my $add_edges = sub {
        my ( $node, @files ) = @_;
        for my $f ( @files ) {
            for my $d ( prune_file_deps( $f ) ) {
                my ( $type, $dep ) = prune_resolve_dep( $d );
                next if $type eq 'system';
                if ( $type eq 'unknown' ) {
                    $unknowns{ "$f : $d" }++;
                    next;
                }
                $edges{ $node }{ $dep }++ if $dep ne $node;
            }
        }
    };

    $add_edges->( 'ROOT', @papps );
    $add_edges->( $_, @{ $fwfiles{ $_ } } ) for keys %fwfiles;
    $add_edges->( $_, $_ )                  for keys %libnodes;

    ## transitive closure from the apps
    ## kept lib symlinks also keep their targets

    my %keep;
    my $keep_closure = sub {
        my @queue = @_;
        while ( @queue ) {
            my $n = shift @queue;
            next if $keep{ $n }++;
            push @queue, keys %{ $edges{ $n } };
            if ( $n =~ /^lib\// && -l $n ) {
                my $t = "lib/" . basename( readlink( $n ) );
                push @queue, $t if -e $t;
            }
        }
    };
    $keep_closure->( keys %{ $edges{ 'ROOT' } } );

    ## plugins : qt loads these at runtime, so they can require frameworks
    ## no packaged program links directly (e.g. libqcocoa -> QtDBus)
    ## plugins matching @plugin_required are kept & extend the closure;
    ## all others are kept only if every dependency is present & referenced
    ## libs used only by kept plugins (e.g. sqldrivers -> mysqlclient) are kept

    my @plugin_required = (
        qr{^plugins/platforms/libq(cocoa|minimal|offscreen)\.dylib$}
        ,qr{^plugins/(mediaservice|audio|playlistformats)/}
        );

    my %plugin_prune;
    my %plugin_keptlibs;
    my @plugfiles = `find plugins -type f \\( -name '*.dylib' -o -name '*.so' \\)`;
    grep chomp, @plugfiles;

    my %plugin_isreq;
    for my $p ( @plugfiles ) {
        $plugin_isreq{ $p } = grep { $p =~ $_ } @plugin_required;
    }

    ## pass 1 : required plugins extend the closure

    for my $p ( sort grep { $plugin_isreq{ $_ } } @plugfiles ) {
        for my $d ( prune_file_deps( $p ) ) {
            my ( $type, $dep ) = prune_resolve_dep( $d );
            next if $type eq 'system';
            if ( $type eq 'unknown' ) {
                $unknowns{ "$p : $d" }++;
                next;
            }
            if ( !-e $dep ) {
                $unknowns{ "$p : $dep missing (required plugin)" }++;
                next;
            }
            $plugin_keptlibs{ $dep }++ if !$keep{ $dep };
            $keep_closure->( $dep );
        }
    }

    ## pass 2 : gate the rest

    for my $p ( sort grep { !$plugin_isreq{ $_ } } @plugfiles ) {
        my @reasons;
        my @needlibs;
        for my $d ( prune_file_deps( $p ) ) {
            my ( $type, $dep ) = prune_resolve_dep( $d );
            next if $type eq 'system';
            if ( $type eq 'framework' ) {
                if ( !-d $dep ) {
                    push @reasons, "$dep not packaged";
                } elsif ( !$keep{ $dep } ) {
                    push @reasons, "$dep unused by packaged programs";
                }
            } elsif ( $type eq 'lib' ) {
                if ( !-e $dep ) {
                    push @reasons, "$dep not packaged";
                } else {
                    push @needlibs, $dep;
                }
            } else {
                push @reasons, "unresolvable dependency $d";
            }
        }
        if ( @reasons ) {
            $plugin_prune{ $p } = join '; ', @reasons;
        } else {
            for my $l ( @needlibs ) {
                $plugin_keptlibs{ $l }++ if !$keep{ $l };
                $keep_closure->( $l );
            }
        }
    }

    ## non-macOS prebuilt helper binaries (e.g. GRPY_linux64, iftci_win64.exe)

    my @binprune = `find bin -type f`;
    grep chomp, @binprune;
    @binprune = sort grep { /(linux64|win64|\.exe$)/ } @binprune;

    ## stray symlinks under plugins (e.g. plugins/platforms/platforms
    ## left behind by older fixapps.pl reruns)

    my @plugstray = `find plugins -type l`;
    grep chomp, @plugstray;

    ## prunable sets

    my @fwprune   = sort grep { !$keep{ $_ } } keys %fwfiles;
    ## keep alias symlinks whose target is kept (e.g. libfoo.dylib -> libfoo.1.2.dylib)
    my @libprune  = sort grep {
        !$keep{ $_ }
        && /\.dylib/
        && !( -l $_ && $keep{ "lib/" . basename( readlink( $_ ) ) } )
    } keys %libnodes;
    my @plugprune = sort keys %plugin_prune;

    ## report

    print hdrline( "prune : unresolvable dependencies (informational)" );
    print join( "\n", sort keys %unknowns ) . "\n" if keys %unknowns;

    my @keepmissing = sort grep { !-e $_ } keys %keep;
    if ( @keepmissing ) {
        print hdrline( "prune : WARNING - referenced but missing, did 'update' converge?" );
        print join( "\n", @keepmissing ) . "\n";
    }

    print hdrline( "prune : kept only for plugins" );
    print join( "\n", sort keys %plugin_keptlibs ) . "\n" if keys %plugin_keptlibs;

    print hdrline( "prune : plugins - no packaged program can load these" );
    for my $p ( @plugprune ) {
        print "$p\n    $plugin_prune{ $p }\n";
    }

    print hdrline( "prune : stray symlinks under plugins" );
    print join( "\n", @plugstray ) . "\n" if @plugstray;

    print hdrline( "prune : unreferenced Frameworks" );
    print join( "\n", @fwprune ) . "\n" if @fwprune;

    print hdrline( "prune : unreferenced libs" );
    print join( "\n", @libprune ) . "\n" if @libprune;

    print hdrline( "prune : non-macOS binaries in bin" );
    print join( "\n", @binprune ) . "\n" if @binprune;

    my $totk = prune_du_k( @fwprune, @libprune, @plugprune, @binprune );
    printf "\nprunable : %d frameworks, %d libs, %d plugins, %d bin, %d stray symlinks : %.1f MB\n",
        scalar @fwprune, scalar @libprune, scalar @plugprune, scalar @binprune, scalar @plugstray, $totk / 1024;

    if ( !$execute ) {
        print "rerun with 'prune' to move these into ./pruned\n" if @fwprune + @libprune + @plugprune + @binprune + @plugstray;
        return;
    }

    ## move aside

    print hdrline( "prune : moving into ./pruned" );
    for my $i ( @fwprune, @libprune, @plugprune, @binprune, @plugstray ) {
        my $destdir = "pruned/" . dirname( $i );
        print `mkdir -p "$destdir" && mv -v "$i" "$destdir/"`;
    }
    print `find plugins -mindepth 1 -type d -empty -print -delete`;
    print "done - review ./pruned, it is safe to remove once the package is verified\n";
}
