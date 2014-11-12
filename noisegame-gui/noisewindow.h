#ifndef NOISEWINDOW_H
#define NOISEWINDOW_H

#include <QMainWindow>
#include "csengine.h"
#include "wsserver.h"

namespace Ui {
class NoiseWindow;
}

class NoiseWindow : public QMainWindow
{
    Q_OBJECT

public:
    explicit NoiseWindow(QWidget *parent = 0);
    ~NoiseWindow();

public slots:
    void setClientsCount(int clientsCount);
    void setCounter(int counter);

private slots:
    void on_filterButton_clicked();

    void on_playBufferButton_clicked();


    void on_testerButton_clicked();

    void on_stopButton_clicked();

    void newEvent(QString event);

    void on_countCheckBox_stateChanged(int arg1);

private:
    Ui::NoiseWindow *ui;
    CsEngine *cs;
    WsServer *wsServer;
    long eventCounter;
};

#endif // NOISEWINDOW_H
