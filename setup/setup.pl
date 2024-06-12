#!/usr/bin/perl

## user configuration

$qt_major_version = "5.15";
$qt_minor_version = "14";
$qwt_version      = "6.1.6";
$src_dir          = "$ENV{HOME}/src";  ## where qt qwt etc will be compiled
$nprocs           = `sysctl -n hw.ncpu` + 1;
$debug            = 1; ## primarily prints commands as they are run
$us_git           = "https://github.com/ehb54/ultrascan3";
$us_base          = $ENV{HOME};        ## base path for ultrascan downloads
$us_prefix        = "ultrascan3";      ## directory name prefix for ultrascan clones

## end user configuration

use File::Basename;
use Cwd 'abs_path';
$scriptdir =  dirname( abs_path( __FILE__ ) );

## developer config... if these are changed, it may break some assumptions
$xcode_version = "12.5.1";

$qt_version    = "$qt_major_version.$qt_minor_version";
$qtfile        = "$src_dir/qt-everywhere-opensource-src-$qt_version.tar.xz";
$qtsrcname     = "qt-everywhere-src-$qt_version";
$qtsrcdir      = "$src_dir/$qtsrcname";
$qtshadow      = "$qtsrcdir/shadow-build";
$qtinstalldir  = "$src_dir/qt-$qt_version";

$qwtfile       = "$src_dir/qwt-$qwt_version.tar.bz2";
$qwtsrcdir     = "$src_dir/qt-$qt_version-qwt-$qwt_version";

$us_mods       = "$scriptdir/../mods/win10-mingw64-templates";

## end developer config

require "$scriptdir/utility.pm";

initopts(
    "all",            "",          "setup everything except --sshd, --us & --us_update", 0
    ,"brew",          "",          "install brew", 0
    ,"brewpackages",  "",          "install brew packages", 0
    ,"xcode",         "",          "download xcode version $xcode_version (will require APPLE ID", 0
    ,"git",           "repo",      "use specified repo instead of default $us_git", 1
    ,"qt",            "",          "download and build qt", 0
    ,"qwt",           "",          "download and build qwt", 0
    ,"us",            "branch",    "branch download and setup ultrascan", 1
    ,"us_update",     "branch",    "update existing branch,", 1
    ,"procs",         "n",         "set number of processors (default $nprocs)", 1
    ,"help",          "",          "print help", 0
    );

$notes = "usage: $0 options

installs needed components for building us3

" . descopts() . "\n";

procopts();
if ( @ARGV ) {
    error_exit( "unrecognized command line option(s) : " . join( ' ', @ARGV ) . "\n---\n$notes" );
}

if ( !$opts_count || $opts{help}{set} ) {
    print $notes;
    exit;
}

if ( $opts{procs}{set} ) {
    $nprocs = $opts{procs}{args}[0];
    print "using $nprocs processors for makes\n";
}

@pkgs = (
    "emacs"
    ,"htop"
    ,"wget"
    ,"postgresql"
    ,"nodejs"
    ,"cmake"
    ,"xcodesorg/made/xcodes"
    );

## setup $src_dir

mkdir $src_dir if !-d $src_dir;
die "$src_dir does not exist as a directory\n" if !-d $src_dir;

# install brew
if ( $opts{brew}{set} || $opts{all}{set} ) {
    print line('=');
    print "install brew\n";
    print line('=');
    my $cmd = 'which brew';
    my $res = run_cmd( $cmd, true );
    if ( !run_cmd_last_error() ) {
        print "brew already apparently installed\n";
    } else {
        print "installing brew, this make take awhile & also ask you for a password\n";
        my $cmd = '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"';
        my $res = run_cmd( $cmd, true );
        error_exit( sprintf( "ERROR: failed [%d] $cmd", run_cmd_last_error() ) ) if run_cmd_last_error();
    }
}

# install brewpackages
if ( $opts{brewpackages}{set} || $opts{all}{set} ) {
    print line('=');
    print "install brew packages\n";
    print line('=');
    
    for my $p ( @pkgs ) {
        my $cmd = "brew install ";
        $cmd .= $p;

        print line();
        my $res = run_cmd( $cmd, true );
        print "$res\n";
        error_exit( sprintf( "ERROR: failed [%d] $cmd", run_cmd_last_error() ) ) if run_cmd_last_error();
    }
}

# install xcode
if ( $opts{xcode}{set} || $opts{all}{set} ) {
    print line('=');
    print "install xcode $xcode_version\n";
    print line('=');
    my $cmd = "xcodes install $xcode_version";
    my $res = run_cmd( $cmd, true );
    error_exit( sprintf( "ERROR: failed [%d] $cmd", run_cmd_last_error() ) ) if run_cmd_last_error();
}

if ( $opts{qt}{set} || $opts{all}{set} ) {
    print line('=');
    print "processing qt\n";
    print line('=');

    ## download qt

    if ( -e $qtfile ) {
        warn "NOTICE: $qtfile exists, not downloading again. Remove if you want a fresh download\n";
    } else {
        $cmd = "cd $src_dir && wget https://download.qt.io/archive/qt/$qt_major_version/$qt_version/single/qt-everywhere-opensource-src-$qt_version.tar.xz";
        print run_cmd( $cmd );
    }

    ## extract qt
    if ( -d $qtsrcdir ) {
        warn "NOTICE: $qtsrcdir exists, not extracting again. Remove if you want a fresh extract\n";
    } else {
        $cmd = "cd $src_dir && tar Jxf $qtfile";
        print run_cmd( $cmd );
    }
    
    ## make shadow

    if ( -d $qtshadow ) {
        $cmd = "rm -fr $qtshadow";
        warn "NOTICE: removing old qt $qtshadow";
        run_cmd( $cmd );
    }

    mkdir $qtshadow;
    die "could not create directory $qtshadow\n" if !-d $qtshadow;

    ## remove d3d12 because https://aur.archlinux.org/cgit/aur.git/tree/0003-Disable-d3d12-requiring-fxc.exe.patch?h=mingw-w64-qt5-declarative

    $cmd = "sed -i 's/^qtConfig\(d3d12/# qtConfig\(d3d12/' $qtsrcdir/qtdeclarative/src/plugins/scenegraph/scenegraph.pro";
    run_cmd( $cmd );

    ## remove wmf / compile error issue 
    $cmd = "sed -i 's/^\\s*qtConfig(wmf/# qtConfig(wmf/' $qtsrcdir/qtmultimedia/src/plugins/plugins.pro";
    run_cmd( $cmd );

    ## configure qt

    $cmd = "cd $qtshadow && MAKEFLAGS=-j$nprocs ../configure -prefix $qtinstalldir -release -opensource -confirm-license -nomake tests -nomake examples -system-proxies -D QT_SHAREDMEMORY -D QT_SYSTEMSEMAPHORE -no-icu -platform win32-g++ -plugin-sql-mysql MYSQL_INCDIR=/mingw64/include/mariadb MYSQL_LIBDIR=/mingw64/lib -openssl-linked -opengl desktop -plugin-sql-psql PSQL_LIBDIR=/mingw64/lib PSQL_INCDIR=/mingw64/include/postgresql > ../last_configure.stdout 2> ../last_configure.stderr";

    print run_cmd( $cmd );

    ## make qt
    # export MSYS2_ARG_CONV_EXCL='*'  only needed to build all or a specific pkg?

    $cmd = "cd $qtshadow && MSYS2_ARG_CONV_EXCL='*' make -j$nprocs -k > ../build.stdout 2> ../build.stderr";
    print run_cmd( $cmd, true, 3 );
    error_exit( sprintf( "ERROR: failed [%d] $cmd", run_cmd_last_error() ) ) if run_cmd_last_error();

    ### make install

    $cmd = "cd $qtshadow && make -j1 -k install > ../install.stdout 2> ../install.stderr";
    print run_cmd( $cmd );

    ### make & install qtdatavis3d
    my $cmd = "cd $qtshadow && cp -rp ../qtdatavis3d .";
    print run_cmd( $cmd );

    my $cmd = "(cd $qtshadow/qtdatavis3d/src && $qtinstalldir/bin/qmake && make -j$nprocs) > $qtsrcdir/build_datavis.stdout 2> $qtsrcdir/build_datavis.stderr";
    print run_cmd( $cmd );

    my $cmd = "(cd $qtshadow/qtdatavis3d && $qtinstalldir/bin/qmake && make -j$nprocs && make -j1 install) >> $qtsrcdir/build_datavis.stdout 2>> $qtsrcdir/build_datavis.stderr";
    print run_cmd( $cmd );
}

if ( $opts{qwt}{set} || $opts{all}{set} ) {
    print line('=');
    print "processing qwt\n";
    print line('=');

    ## download qwt
    if ( -e $qwtfile ) {
        warn "NOTICE: $qwtfile exists, not downloading again. Remove if you want a fresh download\n";
    } else {
        ## possible alternative source
        ## https://sourceforge.net/project/qwt/files/qwt/$qwt_version/qwt-$qwt_version.tar.bz2/download
        ## https://gigenet.dl.sourceforge.net/project/qwt/qwt/$qwt_version/qwt-$qwt_version.tar.bz2
        ## https://versaweb.dl.sourceforge.net/project/qwt/qwt/$qwt_version/qwt-$qwt_version.tar.bz2
        my $cmd = "cd $src_dir && wget --no-check-certificate https://versaweb.dl.sourceforge.net/project/qwt/qwt/$qwt_version/qwt-$qwt_version.tar.bz2";
        print run_cmd( $cmd );
    }

    ## extract qwt
    if ( -d $qwtsrcdir ) {
        warn "NOTICE: $qwtsrcdir exists, not extracting again. Remove if you want a fresh extract\n";
    } else {
        $cmd = "cd $src_dir && mkdir $qwtsrcdir && tar jxf $qwtfile -C $qwtsrcdir --strip-components=1";
        print run_cmd( $cmd );
    }

    ## make qwt

    my $cmd = "cd $qwtsrcdir && $qtinstalldir/bin/qmake && make -j$nprocs > build.stdout 2> build.stderr";
    print run_cmd( $cmd );
}

if ( $opts{git}{set} ) {
    $us_git = $opts{git}{args}[0];
    print "git repo now $us_git\n";
}

if ( $opts{us}{set} ) {
    print line('=');
    print "processing us\n";
    print line('=');

    error_exit( "$us_mods does not exist" ) if !-d $us_mods;
    
    my $branch = $opts{us}{args}[0];
    my $us_dir = "$us_base/$us_prefix-$branch";

    error_exit( "$us_dir exists, remove or rename" ) if -d $us_dir || -f $us_dir;

    print "UltraScan will be cloned in $us_dir\n";

    my $cmd = "git clone -b $branch $us_git $us_dir";
    print run_cmd( $cmd );

    ## copy over $us_mods
    
    run_cmd( "mkdir $us_dir/bin" );
    
    my $sedline;
    ## build up sed replacements
    {
        my @sedlines;
        push @sedlines, "s/__nprocs__/$nprocs/g";
        
        {
            my $us_dir_sed = $us_dir;
            $us_dir_sed =~ s/\//\\\//g;
            push @sedlines, "s/__ultrascandir__/$us_dir_sed/g";
        }
        {
            my $qtinstalldir_sed = $qtinstalldir;
            $qtinstalldir_sed =~ s/\//\\\//g;
            push @sedlines, "s/__qtinstalldir__/$qtinstalldir_sed/g";
        }
        {
            my $qwtsrcdir_sed = $qwtsrcdir;
            $qwtsrcdir_sed =~ s/\//\\\//g;
            push @sedlines, "s/__qwtsrcdir__/$qwtsrcdir_sed/g";
        }
        $sedline = join ';', @sedlines;
    }
        
    my @files = `cd $us_mods && find * -type f | grep -v \\~`;
    grep chomp, @files;
    for my $f ( @files ) {
        print "file $f\n";
        push @cmds, "sed '$sedline' $us_mods/$f > $us_dir/$f";
    }

    my $binbase = "$scriptdir/../bin";
    error_exit( "$binbase does not exist" ) if !-d $binbase;

    my @bins = `cd $binbase && find * -type f | grep -v \\~`;
    grep chomp, @bins;
    for $f ( @bins ) {
        print "file $f\n";
        push @cmds, "cp $binbase/$f $us_dir/bin/";
    }

    for my $cmd ( @cmds ) {
        run_cmd( $cmd );
    }
    
    ## configure & build ultrascan?
    ## setup qt5env
}

if ( $opts{us_update}{set} ) {
    print line('=');
    print "processing us\n";
    print line('=');

    error_exit( "$us_mods does not exist" ) if !-d $us_mods;
    
    my $branch = $opts{us_update}{args}[0];
    my $us_dir = "$us_base/$us_prefix-$branch";

    error_exit( "$us_dir does is not directory" ) if !-d $us_dir;

    ## copy over $us_mods
    
    error_exit( "$us_dir/bin is not a directory. You should probably remove $us_dir and start over as a new branch" ) if !-d "$us_dir/bin";
    
    my $sedline;
    ## build up sed replacements
    {
        my @sedlines;
        push @sedlines, "s/__nprocs__/$nprocs/g";
        
        {
            my $us_dir_sed = $us_dir;
            $us_dir_sed =~ s/\//\\\//g;
            push @sedlines, "s/__ultrascandir__/$us_dir_sed/g";
        }
        {
            my $qtinstalldir_sed = $qtinstalldir;
            $qtinstalldir_sed =~ s/\//\\\//g;
            push @sedlines, "s/__qtinstalldir__/$qtinstalldir_sed/g";
        }
        {
            my $qwtsrcdir_sed = $qwtsrcdir;
            $qwtsrcdir_sed =~ s/\//\\\//g;
            push @sedlines, "s/__qwtsrcdir__/$qwtsrcdir_sed/g";
        }
        $sedline = join ';', @sedlines;
    }
        
    my @files = `cd $us_mods && find * -type f | grep -v \\~`;
    grep chomp, @files;
    for my $f ( @files ) {
        print "file $f\n";
        push @cmds, "sed '$sedline' $us_mods/$f > $us_dir/$f";
    }

    my $binbase = "$scriptdir/../bin";
    error_exit( "$binbase does not exist" ) if !-d $binbase;

    my @bins = `cd $binbase && find * -type f | grep -v \\~`;
    grep chomp, @bins;
    for $f ( @bins ) {
        print "file $f\n";
        push @cmds, "cp $binbase/$f $us_dir/bin/";
    }

    for my $cmd ( @cmds ) {
        run_cmd( $cmd );
    }
    
    # clean up any somo Makefiles

    my @makefiles = `find $us_dir/us_somo -name "Makefile*"`;
    grep chomp, @makefiles;
    if ( @makefiles ) {
        my $cmd = "rm " . ( join ' ', @makefiles );
        run_cmd( $cmd );
    }

    ## configure & build ultrascan?
    ## setup qt5env
}
