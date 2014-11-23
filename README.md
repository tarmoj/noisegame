Noisegame
=============

Interactive soundgame developed for Participation concerts http://tarmo.uuu.ee/osaluskontserdid/

Languages used:
User interface: written in html5, javascript
Communication between clients and server: websockets
Sound syntehsis: Csound
Main server program (WS-server, Csound-API, GUI): Qt C++

Users need to go to local wifi network, open the user interface (for example nonisegame.html),
give a shape to the sound, determine frequency band for bandpass filter, they can listen to the sound
(using WebAudio functions) and send to the server.

WS server can send the incoming Csound event commands via UDP packets to another computer that runs Csound with --port 
command or start a local csound instance and handle them there.

The Csound engine plays back the sounds from PA, applies in certain moments filters, sums some parts of the sound 
to a buffer and plays prolonged in certain moments.

The Csound file noisegame.csd is best to be run in CsoundQt, if used separately.

Copyright: Tarmo Johannes 2014 tarmo@otsakool.edu.ee
