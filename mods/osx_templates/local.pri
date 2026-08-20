# Profile include file for local use
#  Copy file to local.pri and change variables to match your installation

DEBUGORRELEASE  = release 

macx {
    QMAKE_MACOSX_DEPLOYMENT_TARGET = __minosx__
    BUILDBASE   = $us3
    QWTPATH     = __qwtsrcdir__
    #  QWTLIB      = -L$$QWTPATH/lib -lqwt
    CONFIG      += c++14
    CONFIG      += x86_64
    DEFINES     += MAC OSX
    INCLUDEPATH += $$QWTPATH/src
    INCLUDEPATH += ../qwtplot3d/include
    INCLUDEPATH += ../../qwtplot3d/include
    INCLUDEPATH += __openssldir__/include
    INCLUDEPATH += ../Frameworks/QtCore.framework/Headers
    INCLUDEPATH += ../Frameworks/QtGui.framework/Headers
    INCLUDEPATH += ../Frameworks/QtOpenGL.framework/Headers
    INCLUDEPATH += ../Frameworks/QtSvg.framework/Headers
    INCLUDEPATH += ../Frameworks/QtXml.framework/Headers
    INCLUDEPATH += ../../Frameworks/QtCore.framework/Headers
    INCLUDEPATH += ../../Frameworks/QtGui.framework/Headers
    INCLUDEPATH += ../../Frameworks/QtOpenGL.framework/Headers
    INCLUDEPATH += ../../Frameworks/QtSvg.framework/Headers
    INCLUDEPATH += ../../Frameworks/QtXml.framework/Headers
    # libGLU lives under Versions/A/Libraries: the framework carries no
    # top-level Libraries symlink, so the shorter path never resolved and
    # XQuartz's /usr/X11R6/lib was silently satisfying gui.pri's -lGLU.
    LIBS        += -L/System/Library/Frameworks/OpenGL.framework/Versions/A/Libraries
    LIBS        += -lssl -lcrypto
    !equals(TARGET, qwtplot3d): LIBS += -lqwtplot3d
    LIBS        += -framework QtOpenGL
    LIBS        += -L__openssldir__
    LIBS        += $$QWTPATH/lib/qwt.framework/qwt
    MYSQLPATH   = __mysqldir__
    INCLUDEPATH += $$MYSQLPATH/include
    MYSQLDIR    = $$MYSQLPATH/lib
    INCLUDEPATH += __libarchivedir__/include
    LIBS        += -L__libarchivedir__/lib -larchive
}
