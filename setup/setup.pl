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

$arch = `uname -m`;
chomp $arch;
if ( $arch eq "arm64" ) {
    # apple silicon
    $minosx                     = "11.0";
    $postgress_install_location = '/opt/homebrew/opt/postgresql@14';
} else {
    # intel
    $minosx                     = "10.13";
    $postgress_install_location = '/usr/local/opt/postgresql@14';
}

## these versions can be a moving target

$xquartz_release        = "XQuartz-2.8.2";
$xquartz_url            = "https://github.com/XQuartz/XQuartz/releases/download/$xquartz_release/$xquartz_release.dmg";

$xcode_version          = "12.5.1"; ## qt might work with 13.4.1
$xcode_version_for_cpan = "14.3.1"; ## could be determined from perl version and a lookup hash

$zstd_release           = "v1.5.6";
$zstd_git               = "https://github.com/facebook/zstd.git";

$openssl_release        = "1.1.1w";
$openssl_dir            = "openssl-$openssl_release";
$openssl_url            = "https://www.openssl.org/source/old/1.1.1/$openssl_dir.tar.gz";

$mysql_version          = "8.0.37";
$mysql_release          = "mysql-boost-$mysql_version";
$mysql_dir              = "mysql-$mysql_version";
$mysql_url              = "https://cdn.mysql.com//Downloads/MySQL-8.0/mysql-$mysql_version.zip";
 
$python2_url            = "https://www.python.org/ftp/python/2.7.18/python-2.7.18-macosx10.9.pkg";

$qt_version             = "$qt_major_version.$qt_minor_version";
$qtfile                 = "$src_dir/qt-everywhere-opensource-src-$qt_version.tar.xz";
$qtsrcname              = "qt-everywhere-src-$qt_version";
$qtsrcdir               = "$src_dir/$qtsrcname";
$qtshadow               = "$qtsrcdir/shadow-build";
$qtinstalldir           = "$src_dir/qt-$qt_version";

$qwtfile                = "$src_dir/qwt-$qwt_version.tar.bz2";
$qwtsrcdir              = "$src_dir/qt-$qt_version-qwt-$qwt_version";

$us_mods                = "$scriptdir/../mods/osx_templates";

## end developer config

require "$scriptdir/utility.pm";

initopts(
    "all",            "",          "setup everything except --sshd, --us & --us_update", 0
    ,"brew",          "",          "install brew", 0
    ,"brewpackages",  "",          "install brew packages", 0
    ,"xquartz",       "",          "install xquartz ($xquartz_release)", 0
    ,"xcode",         "",          "download xcode versions $xcode_version & $xcode_version_for_cpan [for perl modules] N.B. will require APPLE ID", 0
    ,"zstd",          "",          "build zstd-$zstd_release from source", 0
    ,"openssl",       "",          "build openssl-$openssl_release from source", 0
    ,"mysql",         "",          "build $mysql_release from source", 0
    ,"python2",       "",          "download and install python2, Qt seems to need it for building pdfs", 0
    ,"doxygen",       "",          "install doxygen and cpanm AppConfig Template to allow doc building", 0
    ,"qt",            "",          "download and build qt", 0
    ,"qwt",           "",          "download and build qwt", 0
    ,"git",           "repo",      "use specified repo instead of default $us_git", 1
    ,"us",            "branch",    "branch download and setup ultrascan", 1
    ,"us_update",     "branch",    "update existing branch,", 1
    ,"procs",         "n",         "set number of processors (default $nprocs)", 1
    ,"help",          "",          "print help", 0
    ,"frameworks",    "branch",    "temp install frameworks help", 1
    );

$notes = "usage: $0 options

installs needed components for building us3

Note: minimum OSX release support by these builds is $minosx

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
    ,"aria2"
    ,"xcodesorg/made/xcodes"
    ,"llvm"
    ,"pkg-config"
    ,"cpanminus"
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
        run_cmd( $cmd );
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

# install xquartz
if ( $opts{xquartz}{set} || $opts{all}{set} ) {
    print line('=');
    print "install xquartz\n";
    print line('=');
    my $cmd = 
        "cd $src_dir"
        . " && wget -O xquartz.dmg $xquartz_url"
        . " && hdiutil attach xquartz.dmg"
        . " && sudo installer -verbose -pkg /Volumes/$xquartz_release/XQuartz.pkg -target /"
        . " && hdiutil detach /Volumes/$xquartz_release"
        . " && rm xquartz.dmg"
        ; 
    my $res = run_cmd( $cmd, true );
    error_exit( sprintf( "ERROR: failed [%d] $cmd", run_cmd_last_error() ) ) if run_cmd_last_error();
    print "NOTICE: *** system must be rebooted for XQuartz to work properly ***";
}

# install xcode
if ( $opts{xcode}{set} || $opts{all}{set} ) {
    print line('=');
    print "install xcode $xcode_version\n";
    print line('=');
    {
        my $cmd = "sudo xcodes install $xcode_version";
        print run_cmd( $cmd );
    }
    {
        my $cmd = "sudo xcodes install $xcode_version_for_cpan";
        print run_cmd( $cmd, true );
    }
}

# install zstd
if ( $opts{zstd}{set} || $opts{all}{set} ) {
    print line('=');
    print "build zstd\n";
    print line('=');
    my $cmd = 
        "xcodes select $xcode_version"
        . " && cd $src_dir"
        . " && git clone $zstd_git zstd-$zstd_release"
        . " && cd zstd-$zstd_release"
        . " && git checkout tags/$zstd_release"
        . " && sed -i '' '14s/^/CFLAGS   += -mmacosx-version-min=$minosx\\nCPPFLAGS += -mmacosx-version-min=$minosx\\n/' Makefile"
        . " && sed -i '' '14s/^/CFLAGS   += -mmacosx-version-min=$minosx\\nCPPFLAGS += -mmacosx-version-min=$minosx\\n/' lib/Makefile"
        . " && make -j $nprocs"
        . " && make install" 
        ;
    my $res = run_cmd( $cmd, true );
    error_exit( sprintf( "ERROR: failed [%d] $cmd", run_cmd_last_error() ) ) if run_cmd_last_error();
}

# install openssl
if ( $opts{openssl}{set} || $opts{all}{set} ) {
    print line('=');
    print "build openssl \n";
    print line('=');
    my $cmd = 
        "xcodes select $xcode_version"
        . " && cd $src_dir"
        . " && wget -O $openssl_dir.tar.gz $openssl_url"
        . " && tar zxf $openssl_dir.tar.gz"
        . " && rm $openssl_dir.tar.gz"
        . " && cd $openssl_dir"
        . " && perl ./Configure --prefix=$src_dir/openssl -no-ssl3 no-ssl3-method darwin64-$arch-cc enable-ec_nistp_64_gcc_128"
        . " && sed -i '' 's/^\\(CFLAGS=.*\$\\)/\\1 -mmacosx-version-min=$minosx/' Makefile"
        . " && make -j $nprocs"
        . " && make install"
        ;
    my $res = run_cmd( $cmd, true );
    error_exit( sprintf( "ERROR: failed [%d] $cmd", run_cmd_last_error() ) ) if run_cmd_last_error();
}

# install mysql
if ( $opts{mysql}{set} || $opts{all}{set} ) {
    print line('=');
    print "build mysql \n";
    print line('=');
    my $cmd = 
        "xcodes select $xcode_version"
        . " && cd $src_dir"
        . " && wget -O $mysql_dir.tar.gz $mysql_url"
        . " && tar xf $mysql_dir.tar.gz"
        . " && rm $mysql_dir.tar.gz"
        . " && cd $mysql_dir"
        . " && cmake . -DCMAKE_INSTALL_PREFIX=$src_dir/mysql-client-$mysql_version -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=Release -DCMAKE_FIND_FRAMEWORK=LAST -DCMAKE_VERBOSE_MAKEFILE=ON -Wno-dev -DBUILD_TESTING=OFF -DCMAKE_OSX_SYSROOT=/Applications/Xcode-12.5.1.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX11.3.sdk -DFORCE_INSOURCE_BUILD=1 -DCOMPILATION_COMMENT=Homebrew -DDEFAULT_CHARSET=utf8mb4 -DDEFAULT_COLLATION=utf8mb4_general_ci -DINSTALL_DOCDIR=share/doc/mysql-client -DINSTALL_INCLUDEDIR=include/mysql -DINSTALL_INFODIR=share/info -DINSTALL_MANDIR=share/man -DINSTALL_MYSQLSHAREDIR=share/mysql -DDOWNLOAD_BOOST=1 -DWITH_BOOST=boost -DWITH_EDITLINE=system -DWITH_FIDO=bundled -DWITH_LIBEVENT=system -DWITH_ZLIB=bundled -DWITH_SSL=yes -DWITH_UNIT_TESTS=OFF -DWITHOUT_SERVER=ON -DOPENSSL_ROOT_DIR=$src_dir/openssl-$openssl_release -DOPENSSL_INCLUDE_DIR=$src_dir/openssl-$openssl_release/include -DOPENSSL_LIBRARY=$src_dir/openssl-$openssl_release/libssl.1.1.dylib -DCRYPTO_LIBRARY=$src_dir/openssl-$openssl_release/libcrypto.1.1.dylib -DCMAKE_CXX_FLAGS='-mmacosx-version-min=$minosx'"
        . " && make -j $nprocs"
        . " && make install"
        ;
    my $res = run_cmd( $cmd, true );
    error_exit( sprintf( "ERROR: failed [%d] $cmd", run_cmd_last_error() ) ) if run_cmd_last_error();
}

# install python2
if ( $opts{python2}{set} || $opts{all}{set} ) {
    print line('=');
    print "install python2\n";
    print line('=');
    my $cmd = 
        "cd $src_dir"
        . " && wget -O python2.pkg $python2_url"
        . " && sudo installer -verbose -pkg python2.pkg -target /"
        . " && rm python2.pkg"
        ; 
    my $res = run_cmd( $cmd, true );
    error_exit( sprintf( "ERROR: failed [%d] $cmd", run_cmd_last_error() ) ) if run_cmd_last_error();
}

# install doxygen, tpage
if ( $opts{doxygen}{set} || $opts{all}{set} ) {
    print line('=');
    print "install doxygen\n";
    print line('=');
    my $cmd = 
        " xcodes select $xcode_version_for_cpan"
        . " && sudo cpanm AppConfig Template"
        . " && brew install Doxygen"
        ; 
    my $res = run_cmd( $cmd, true );
    error_exit( sprintf( "ERROR: failed [%d] $cmd", run_cmd_last_error() ) ) if run_cmd_last_error();
}

if ( $opts{qt}{set} || $opts{all}{set} ) {
    print line('=');
    print "processing qt\n";
    print line('=');

    my $cmd = "xcodes select $xcode_version";
    print run_cmd( $cmd );

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

    ## configure qt

    $cmd = "cd $qtshadow && export MAKEFLAGS=-j$nprocs && ../configure -prefix $src_dir/qt-$qt_major_version.$qt_minor_version -release -opensource -confirm-license -nomake tests -nomake examples -plugin-sql-mysql -plugin-sql-psql -openssl-linked -system-proxies -D QT_SHAREDMEMORY -D QT_SYSTEMSEMAPHORE -no-icu OPENSSL_PREFIX=$src_dir/openssl MYSQL_INCDIR=$src_dir/mysql-$mysql_version/include MYSQL_PREFIX=$src_dir/mysql-$mysql_version PSQL_PREFIX=$postgresql_install_location  > ../last_configure.stdout 2> ../last_configure.stderr";

    print run_cmd( $cmd );

    ## make qt

    $cmd = "cd $qtshadow && make -j$nprocs -k > ../build.stdout 2> ../build.stderr";
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

    my $cmd = "xcodes select $xcode_version";
    print run_cmd( $cmd );

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

    my $cmd = "xcodes select $xcode_version";
    print run_cmd( $cmd );

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
        push @sedlines, "s/__minosx__/$minosx/g";

        {
            my $openssl_dir_sed = "$src_dir/$openssl_dir";
            $openssl_dir_sed =~ s/\//\\\//g;
            push @sedlines, "s/__openssldir__/$openssl_dir_sed/g";
        }
        {
            my $mysql_dir_sed = "$src_dir/$mysql_dir";
            $mysql_dir_sed =~ s/\//\\\//g;
            push @sedlines, "s/__mysqldir__/$mysql_dir_sed/g";
        }
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
        if ( $debug >= 2 ) {
            print "---\n";
            print join "\n", @sedlines;
            print "\n---\n";
        }
    }
        
    my @cmds;

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

    ## setup frameworks

    ## setup frameworks

    my @cmds = (
        "mkdir $us_dir/Frameworks; echo 0"
        ,"cd $qtinstalldir/lib && rsync -av --exclude Headers --exclude QtUiPlugin.framework --exclude QtRepParser.framework *framework $us_dir/Frameworks"
        ,"cd $qtinstalldir/bin && rsync -av *Assistant.app $us_dir/bin"
        ,"cd $qtinstalldir && rsync -av plugins $us_dir/"
        ,"cd $qwtsrcdir/lib && rsync -av --exclude Headers *framework $us_dir/Frameworks"
        ,"cp -p $src_dir/$openssl_dir/libssl.1.1.dylib $us_dir/lib"
        ,"cp -p $src_dir/$openssl_dir/libcrypto.1.1.dylib $us_dir/lib"        
        ,"cp -p $src_dir/mysql-client-$mysql_version/lib/libmysqlclient.*.dylib $us_dir/lib"
        ,"cd $us_dir && $scriptdir/../macOS-x64/utils/fixframeworks.pl Frameworks/*.framework"
        );
        
    for my $cmd ( @cmds ) {
        run_cmd( $cmd );
    }
}

if ( $opts{frameworks}{set} ) {
    print line('=');
    print "processing frameworks\n";
    print line('=');

    my $branch = $opts{frameworks}{args}[0];
    my $us_dir = "$us_base/$us_prefix-$branch";

    ## setup frameworks

    my @cmds = (
        "mkdir $us_dir/Frameworks; echo 0"
        ,"cd $qtinstalldir/lib && rsync -av --exclude Headers --exclude QtUiPlugin.framework --exclude QtRepParser.framework *framework $us_dir/Frameworks"
        ,"cd $qtinstalldir/bin && rsync -av *Assistant.app $us_dir/bin"
        ,"cd $qtinstalldir && rsync -av plugins $us_dir/"
        ,"cd $qwtsrcdir/lib && rsync -av --exclude Headers *framework $us_dir/Frameworks"
        ,"cp -p $src_dir/$openssl_dir/libssl.1.1.dylib $us_dir/lib"
        ,"cp -p $src_dir/$openssl_dir/libcrypto.1.1.dylib $us_dir/lib"        
        ,"cp -p $src_dir/mysql-client-$mysql_version/lib/libmysqlclient.*.dylib $us_dir/lib"
        ,"cd $us_dir && $scriptdir/../macOS-x64/utils/fixframeworks.pl Frameworks/*.framework"
        );
        
    for my $cmd ( @cmds ) {
        run_cmd( $cmd );
    }
}

if ( $opts{us_update}{set} ) {
    print line('=');
    print "processing us_update\n";
    print line('=');

    my $cmd = "xcodes select $xcode_version";
    print run_cmd( $cmd );

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
        push @sedlines, "s/__minosx__/$minosx/g";

        {
            my $openssl_dir_sed = "$src_dir/$openssl_dir";
            $openssl_dir_sed =~ s/\//\\\//g;
            push @sedlines, "s/__openssldir__/$openssl_dir_sed/g";
        }
        {
            my $mysql_dir_sed = "$src_dir/$mysql_dir";
            $mysql_dir_sed =~ s/\//\\\//g;
            push @sedlines, "s/__mysqldir__/$mysql_dir_sed/g";
        }
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
        if ( $debug >= 2 ) {
            print "---\n";
            print join "\n", @sedlines;
            print "\n---\n";
        }
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
}
