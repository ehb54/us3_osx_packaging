# Profile include file for local use
#  Copy file to local.pri and change variables to match your installation

# ---- user configuration area ----
# **** make sure the following variables are set for your system ***

# uncomment exactly one of these:
# DEBUGORRELEASE = debug
DEBUGORRELEASE = release

QMAKE_CFLAGS += -Wno-deprecated -Wno-deprecated-declarations -Wno-unused-result
QMAKE_CXXFLAGS += -Wno-deprecated -Wno-deprecated-declarations -Wno-unused-result

# path of US3 source base
US3PATH       = 

# path of US3_SOMO source base
US3SOMOPATH   = __ultrascandir__/us_somo

# path of the QT 
QTPATH        = __qtinstalldir__
QWTPATH       = __qwtsrcdir__

# for windows also define the MINGWPATH
MINGWPATH     =

# ---- these below might need to be modified in unusual circumstances ----
QWT3DPATH     = $$US3PATH/qwtplot3d
# define this if you are not using qwtplot3d as the qwtplot3d lib for linux & osx
QWT3DLIBNAME  = 

# ---- probably should not be changed

count( QWT3DLIBNAME, 0 ) {
   QWT3DLIBNAME = qwtplot3d
}

CONFIG     += qt thread warn
contains( DEBUGORRELEASE, debug ) {
   CONFIG    += debug
} else {
   CONFIG    += release
}

INCLUDEPATH  += $$US3SOMOPATH/develop/include
INCLUDEPATH  += $$QTPATH/include
# some qwt5 have libraries in src/ some in include/; having extra (possibly non-existant) include paths is not a problem
INCLUDEPATH  += $$QWTPATH/include $$QWTPATH/src
INCLUDEPATH  += $$QWT3DPATH/include

# ---- system specific definitions
include ( uname.pri )


# OSX also reports UNIX
contains( DEFINES, "OSX" ) {
} else {
    unix {
      # Local flags
      #QMAKE_CXXFLAGS_DEBUG += -pg
      #QMAKE_LFLAGS_DEBUG += -pg
    
      #If you want your compiles to do a globus run on bcf, uncomment the following lines:
      # Be sure to add the environment variable MAKEFLAGS=-j44
      #QMAKE_CXX  = g++
      #QMAKE_CC   = g++
      #QMAKE_MOC  = $(QTDIR)/bin/moc
      #QMAKE_UIC  = $(QTDIR)/bin/uic
      #QMAKE_LINK = g++
    
# these should really be in qmake.conf 
      QMAKE_CXXFLAGS_RELEASE = -O3
      QMAKE_CFLAGS_RELEASE   = -O3
   }
}

win32 {

  DEFINES      += MINGW
  VER         = 10

  # QWT3D is right for libraries, but gui apps need ../$$QWT3D
  # due to us3 directory structure

  QWT3D       = ../qwtplot3d
  OPENSSL     = C:/utils/openssl
  MYSQLPATH   = C:/utils/mysql
  MYSQLDIR    = $$MYSQLPATH/lib
  QTMYSQLPATH = C:/utils/Qt/5.4.1/plugins/sqldrivers
  QMAKESPEC   = $$QTPATH/mkspecs/win32-g++
  QTMAKESPEC  = $$QMAKESPEC
  MINGWDIR    = C:/mingw64/x86_64-w64-mingw32
  
  contains( DEBUGORRELEASE, debug ) {
    QWTLIB      = $$QWTPATH/lib/libqwtd.a
    MYSQLLIB    = $$MYSQLDIR/libmysqld.lib
  } else {
    QWTLIB      = $$QWTPATH/lib/libqwt.a
    MYSQLLIB    = $$MYSQLDIR/libmysql.lib
    INCLUDEPATH += c:/mingw64/opt/include
  }
  ##LIBS        += $$MYSQLLIB
  LIBS        += -L$$MYSQLDIR -lmysql
  LIBS        += -lpsapi

  #  __LCC__ is needed on W32 to make mysql headers include the right W32 includes
  ##DEFINES    += __LCC__
  DEFINES    += __WIN64__
  LIBS        += -L$$QWTPATH/lib -lqwt
}

macx {
##  CONFIG      += x86_64 x86 app_bundle
#  QMAKE_CFLAGS += -std=c++11
#  QMAKE_CXXFLAGS += -std=gnu++11
   QMAKE_MACOSX_DEPLOYMENT_TARGET = __minosx__
   CONFIG += c++11
message( "macx" );
  CONFIG      *= x86_64
  DEFINES     += MAC OSX
  INCLUDEPATH += /System/Libraries/Frameworks/OpenGL.framework/Headers
  INCLUDEPATH += $QTPATH/include
  INCLUDEPATH += /usr/X11R6/include
  INCLUDEPATH += /usr/X11R6/include/GL
  LIBS        += -L/System/Library/Frameworks/OpenGL.framework/Libraries
#  LIBS        += -L$$US3PATH/lib
#  LIBS        += -l$$QWT3DLIBNAME
  LIBS        += -framework QtOpenGL
  LIBS        += $$QWTPATH/lib/qwt.framework/qwt
#  X11LIB       = -L/usr/X11R6/lib -lXau -lX11
#   QMAKE_LFLAGS += -dynamiclib
}

QT += network
QT += svg
QT += widgets
QT += printsupport
QT += multimedia
LIBS *= -lz
