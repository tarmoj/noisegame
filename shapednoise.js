
function ShapedNoise() {
  try {
    // Fix up for prefixing
    window.AudioContext = window.AudioContext||window.webkitAudioContext;
    context = new AudioContext();
  }
  catch(e) {
    alert('Web Audio API is not supported in this browser');
    return;
  }
  
  
  // for compatibility
	if (!context.createGain)
	context.createGain = context.createGainNode;
	if (!context.createDelay)
	context.createDelay = context.createDelayNode;
	if (!context.createScriptProcessor)
	context.createScriptProcessor = context.createJavaScriptNode;
	
  this.amplitude = [0,1,0.5,0.5,0];; // envelope's nodes' amplitudes in 0..1
	this.timeSlice = [0,0.25,0.5,0.75,1];  // last should be always 1
	// duration of the segmentsnrelation to whole duration. First value always 0
	this.duration = 4;
	this.centerFreq = 400; // values for the bandbass filter
	this.band = 100;
	this.env4freq = false; // wether to use envelope also fro frequency
	this.inversed = false; // if to read the envelope from end to beginning for frequency
	this.pan = 0.5;
}


ShapedNoise.prototype.setFrequencies = function(lower,higher) {
	this.lowerFreq = lower;
	this.higherFreq = higher;
	this.band = higher-lower;
	this.centerFreq = lower + this.band/2;
}



ShapedNoise.prototype.play = function() {
  this.noise = context.createPinkNoise(); //custon class, see below
  this.gainNode = context.createGain();
  this.panner = context.createPanner();
  this.panner.panningModel = 'equalpower';
  var panning = this.pan*2-1 ; // to scale -1..1
  this.panner.setPosition(panning,0,1-Math.abs(panning));
  
  this.filter = context.createBiquadFilter();
  this.filter.type = "bandpass";
  this.filter.frequency.value = this.centerFreq;
  this.filter.Q.value = this.centerFreq/this.band;
  //console.log(this.filter.frequency.value, this.filter.Q.value);
  
  this.noise.connect(this.gainNode);
  this.gainNode.connect(this.filter);
  this.filter.connect(this.panner);
  this.panner.connect(context.destination);
 
  this.envelope(this.duration, this.gainNode.gain, 0, 0.6);
  this.gainNode.gain.linearRampToValueAtTime(0, context.currentTime+ this.duration+0.1 ); // declick? but what if freq?

  

 
  if (this.env4freq) {
	  this.filter.Q.value = 4; // relatively narrow to hear the change
	  this.envelope(this.duration, this.filter.frequency, this.lowerFreq,this.higherFreq, this.inversed );
  }
  
};


ShapedNoise.prototype.stop = function() {  // k as on üldse vajalik?
	console.log("stop");
	this.noise.disconnect();
	this.gainNode.disconnect();
};


// ramps to envelope values in array amplitude[] on times in array timeSlice[]
ShapedNoise.prototype.envelope = function(duration, parameter,startvalue, endvalue, inversed) {
	console.log(startvalue, endvalue, inversed);
	var now = context.currentTime;
	//parameter.cancelScheduledValues(time); // is it necessary
	var time = 0;
	for (var i=0;i<5;i++) {
		
		//
		if (!inversed) {
			time = this.timeSlice[i] * duration;// += this.timeSlice[i]; // sum the time from time slices in array -  KONTROLLI, kuidas NOISEGAME'i kood kas vahed või ajahetked
			parameter.linearRampToValueAtTime( startvalue+this.amplitude[i]*(endvalue-startvalue), now+time);
			//console.log(now+time, this.amplitude[i]);
		} else { // inversed envelope
			time = (1-this.timeSlice[4-i]) * duration;
			//console.log(time, this.amplitude[4-i]);
			parameter.linearRampToValueAtTime( startvalue+this.amplitude[4-i]*(endvalue-startvalue), now+time);
		}
	}
};


//code of noise taken from: https://github.com/zacharydenton/noise.js
//thanks to Zach Denton
(function(AudioContext) {
	AudioContext.prototype.createPinkNoise = function(bufferSize) {
		bufferSize = bufferSize || 4096;
		var b0, b1, b2, b3, b4, b5, b6;
		b0 = b1 = b2 = b3 = b4 = b5 = b6 = 0.0;
		var node = this.createScriptProcessor(bufferSize, 1, 1);
		node.onaudioprocess = function(e) {
			var output = e.outputBuffer.getChannelData(0);
			for (var i = 0; i < bufferSize; i++) {
				var white = Math.random() * 2 - 1;
				b0 = 0.99886 * b0 + white * 0.0555179;
				b1 = 0.99332 * b1 + white * 0.0750759;
				b2 = 0.96900 * b2 + white * 0.1538520;
				b3 = 0.86650 * b3 + white * 0.3104856;
				b4 = 0.55000 * b4 + white * 0.5329522;
				b5 = -0.7616 * b5 - white * 0.0168980;
				output[i] = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362;
				output[i] *= 0.11; // (roughly) compensate for gain
				b6 = white * 0.115926;
			}
		}
		return node;
	};	
})(window.AudioContext || window.webkitAudioContext);

