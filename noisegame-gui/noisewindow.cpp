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
//    useCsound = ui->csoundCheckBox->isChecked();
//    useUdp = ui->udpCheckBox->isChecked();


    connect(wsServer, SIGNAL(newConnection(int)), this, SLOT(setClientsCount(int)));
    connect(wsServer, SIGNAL(newEvent(QString)),this, SLOT(newEvent(QString)) );

    //TODO: see plokki, mis checkboxi xheckides käivitatakse
    //initUDP(QHostAddress::LocalHost,6006);
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
    if (ui->csoundCheckBox->isChecked())
        cs->csEvent("i \"filter\" 0 5 "); //TODO - vali, kui pikalt
}

void NoiseWindow::on_playBufferButton_clicked()
{
    if (ui->csoundCheckBox->isChecked())
        cs->csEvent("i \"play_buffer\" 0 10 "); //TODO - vali, kui pikalt
}



void NoiseWindow::on_testerButton_clicked()
{
    if (ui->csoundCheckBox->isChecked())
        cs->csEvent("i \"start_tester\" 0 0 5 ");

}

void NoiseWindow::on_stopButton_clicked()
{
    if (ui->csoundCheckBox->isChecked())
        cs->stop();
}

void NoiseWindow::newEvent(QString event) {
    ui->noiseEventsLabel->setText(QString::number(++eventCounter));
    if (ui->csoundCheckBox->isChecked())
        cs->csEvent(event);
    if (ui->udpCheckBox->isChecked())
        sendUDPMessage("scoreline_i {{ " + event + " }}");
    qDebug()<<event;
}

void NoiseWindow::on_countCheckBox_stateChanged(int value)
{
    if (ui->csoundCheckBox->isChecked())
        cs->setChannel("count",value);
}

//TODO: levels

//void NoiseWindow::initUDP(QHostAddress host, int port)
//{
//    udpSocket = new QUdpSocket(this);
//    udpSocket->bind(host, port);
//}

void NoiseWindow::sendUDPMessage(QString message)
{
    QByteArray data = message.toLocal8Bit().data();
    QUdpSocket * udpSocket  = new QUdpSocket(this);
    int retval=udpSocket->writeDatagram(data, QHostAddress(ui->ipLineEdit->text()), ui->portSpinBox->value());
    qDebug()<<"Bytes sent: "<<retval;
    udpSocket->close(); // for any case
}


void NoiseWindow::on_csoundCheckBox_toggled(bool checked)
{
    if (checked) {
        cs = new CsEngine("noisegame.csd");
        cs->start();
        cs->setChannel("level",0.4);
        cs->setChannel("filter",0.25);
        cs->setChannel("buffer",0.5);
        //connect(cs,SIGNAL(newCounterValue(int)),this,SLOT(setCounter(int)));

    } else {
        cs->stop();
        cs->deleteLater();
    }
}
