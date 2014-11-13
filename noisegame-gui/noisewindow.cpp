#include "noisewindow.h"
#include "ui_noisewindow.h"

#define COUNT4FILTER 100

NoiseWindow::NoiseWindow(QWidget *parent) :
    QMainWindow(parent),
    ui(new Ui::NoiseWindow)
{
    ui->setupUi(this);
    wsServer = new WsServer(8008);
    eventCounter = 0;
    cs = new CsEngine("noisegame.csd");
    cs->start();

    connect(wsServer, SIGNAL(newConnection(int)), this, SLOT(setClientsCount(int)));
    connect(wsServer, SIGNAL(newEvent(QString)),this, SLOT(newEvent(QString)) );
    connect(cs,SIGNAL(newCounterValue(int)),this,SLOT(setCounter(int)));

    //TODO: see plokki, mis checkboxi xheckides käivitatakse
    initUDP(QHostAddress::LocalHost,6006);
}

NoiseWindow::~NoiseWindow()
{
    delete ui;
}

void NoiseWindow::setClientsCount(int clientsCount)
{
    ui->numberOfClientsLabel->setText(QString::number(clientsCount));
}

void NoiseWindow::setCounter(int counter)
{
    ui->noiseEventsLabel->setText(QString::number(counter));
}

void NoiseWindow::on_filterButton_clicked()
{
    cs->csEvent("i \"filter\" 0 5 "); //TODO - vali, kui pikalt
}

void NoiseWindow::on_playBufferButton_clicked()
{
    cs->csEvent("i \"play_buffer\" 0 10 "); //TODO - vali, kui pikalt
}



void NoiseWindow::on_testerButton_clicked()
{
    cs->csEvent("i \"start_tester\" 0 0 5 ");

}

void NoiseWindow::on_stopButton_clicked()
{
    cs->stop();
}

void NoiseWindow::newEvent(QString event) {
//    if (++eventCounter%COUNT4FILTER==0) {
//       on_filterButton_clicked();
//    } - handled in Csound now
    //ui->noiseEventsLabel->setText(QString::number(eventCounter));
    cs->csEvent(event);
    sendUDPMessage("scoreline_i {i 1 0 1}");
}

void NoiseWindow::on_countCheckBox_stateChanged(int value)
{
    cs->setChannel("count",value);
}

void NoiseWindow::initUDP(QHostAddress host, int port)
{
    udpSocket = new QUdpSocket(this);
    udpSocket->bind(host, port);
}

void NoiseWindow::sendUDPMessage(QString message)
{
    QByteArray data = message.toLocal8Bit().data();
    int retval=udpSocket->writeDatagram(data, QHostAddress::LocalHost, 6006);
    qDebug()<<"Bytes sent: "<<retval;
}
