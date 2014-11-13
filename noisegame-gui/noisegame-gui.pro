#-------------------------------------------------
#
# Project created by QtCreator 2014-10-09T19:07:16
#
#-------------------------------------------------

QT       += core gui websockets network

greaterThan(QT_MAJOR_VERSION, 4): QT += widgets

TARGET = noisegame-gui
TEMPLATE = app
INCLUDEPATH += /home/tarmo/src/cs6/include/


SOURCES += main.cpp\
        noisewindow.cpp \
    wsserver.cpp \
    csengine.cpp

HEADERS  += noisewindow.h \
    wsserver.h \
    csengine.h

FORMS    += noisewindow.ui

LIBS += -L/home/tarmo/src/cs6/lib -lcsound64 -lsndfile  -ldl -lpthread -lcsnd6
