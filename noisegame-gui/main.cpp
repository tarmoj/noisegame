#include "noisewindow.h"
#include <QApplication>

int main(int argc, char *argv[])
{
    QApplication a(argc, argv);
    NoiseWindow w;
    w.show();

    return a.exec();
}
