#-------------------------------------------------
#
# Project created by QtCreator 2014-10-09T19:07:16
#
# noise-server - websocket server for sound game "Noise game"
# Copyright: Tarmo Johannes 2014 tarmo@otsakool.edu.ee
# License: GPL v 2
#-------------------------------------------------

QT       += core gui websockets network

greaterThan(QT_MAJOR_VERSION, 4): QT += widgets

TARGET = noisegame-gui
TEMPLATE = app
INCLUDEPATH += /home/tarmo/src/cs6/include/ # not necessary if Csound6 is installed in default folder


SOURCES += main.cpp\
        noisewindow.cpp \
    wsserver.cpp \
    csengine.cpp

HEADERS  += noisewindow.h \
    wsserver.h \
    csengine.h

FORMS    += noisewindow.ui

LIBS += -L/home/tarmo/src/cs6/lib -lcsound64 -lsndfile  -ldl -lpthread -lcsnd6
