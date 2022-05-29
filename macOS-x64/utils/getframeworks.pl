#!/usr/bin/perl

$qtdir  = $ENV{QTDIR} || die "environment variable QTDIR must be defined\n";
$qwtdir = $ENV{QWTDIR} || die "environment variable QWTDIR must be defined\n";
$tdir   = "./Frameworks";

$notes = "usage: $0 install

installs required frameworks into $tdir
qt:  $qtdir
qwt: $qwtdir

";


$go = shift || die $notes;
die "unrecognized cmd $go\n" if $go ne 'install';

if ( !-d $tdir ) {
    `mkdir $tdir`;
    die "$tdir is not a directory\n" if !-d $tdir;
}

@frameworks = (
    "$qtdir/lib/QtBluetooth.framework"
    ,"$qtdir/lib/QtBodymovin.framework"
    ,"$qtdir/lib/QtConcurrent.framework"
    ,"$qtdir/lib/QtCore.framework"
    ,"$qtdir/lib/QtDBus.framework"
    ,"$qtdir/lib/QtGamepad.framework"
    ,"$qtdir/lib/QtGui.framework"
    ,"$qtdir/lib/QtHelp.framework"
    ,"$qtdir/lib/QtMacExtras.framework"
    ,"$qtdir/lib/QtMultimedia.framework"
    ,"$qtdir/lib/QtMultimediaQuick.framework"
    ,"$qtdir/lib/QtMultimediaWidgets.framework"
    ,"$qtdir/lib/QtNetwork.framework"
    ,"$qtdir/lib/QtNetworkAuth.framework"
    ,"$qtdir/lib/QtNfc.framework"
    ,"$qtdir/lib/QtOpenGL.framework"
    ,"$qtdir/lib/QtPrintSupport.framework"
    ,"$qtdir/lib/QtPurchasing.framework"
    ,"$qtdir/lib/QtQml.framework"
    ,"$qtdir/lib/QtQmlModels.framework"
    ,"$qtdir/lib/QtQmlWorkerScript.framework"
    ,"$qtdir/lib/QtQuick.framework"
    ,"$qtdir/lib/QtQuick3D.framework"
    ,"$qtdir/lib/QtQuick3DAssetImport.framework"
    ,"$qtdir/lib/QtQuick3DRender.framework"
    ,"$qtdir/lib/QtQuick3DRuntimeRender.framework"
    ,"$qtdir/lib/QtQuick3DUtils.framework"
    ,"$qtdir/lib/QtQuickControls2.framework"
    ,"$qtdir/lib/QtQuickParticles.framework"
    ,"$qtdir/lib/QtQuickShapes.framework"
    ,"$qtdir/lib/QtQuickTemplates2.framework"
    ,"$qtdir/lib/QtQuickTest.framework"
    ,"$qtdir/lib/QtQuickWidgets.framework"
    ,"$qtdir/lib/QtRemoteObjects.framework"
    ,"$qtdir/lib/QtRepParser.framework"
    ,"$qtdir/lib/QtScxml.framework"
    ,"$qtdir/lib/QtSensors.framework"
    ,"$qtdir/lib/QtSerialBus.framework"
    ,"$qtdir/lib/QtSerialPort.framework"
    ,"$qtdir/lib/QtSql.framework"
    ,"$qtdir/lib/QtSvg.framework"
    ,"$qtdir/lib/QtTest.framework"
    ,"$qtdir/lib/QtUiPlugin.framework"
    ,"$qtdir/lib/QtWebChannel.framework"
    ,"$qtdir/lib/QtWebSockets.framework"
    ,"$qtdir/lib/QtWidgets.framework"
    ,"$qtdir/lib/QtXml.framework"
    ,"$qtdir/lib/QtXmlPatterns.framework"
    ,"$qtdir/lib/QtZlib.framework"
    ,"$qwtdir/lib/qwt.framework"
    );

for $f ( @frameworks ) {
    $cmds .= "rsync -av --exclude Headers $f $tdir\n";
}

$cmds .= "rsync -av $qtdir/plugins .";

print $cmds;
print `$cmds`;
