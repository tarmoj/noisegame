//var serverURL = "ws://johannes.homeip.net:8008/ws";
		
		var amplitude = [0,1,0.5,0.5,0];; // envelope's nodes' amplitudes in 0..1
		var timePoint = [0,0.05,0.1,0.75,1]; // duration of the segments in relation to whole duration. First value always 0
		
		function index2LogFreq(index) { // convert index (0..1) to 20.20000 in log scale
			return Math.round(Math.pow(10, (index * 3) + 1.30102996)); // 3 = log(20000)-log(3), 1.301... = log(20)
		}
				
		var upperFreq = index2LogFreq(0.5), lowerFreq = index2LogFreq(0.3);
		
		
		// drawing with KineticJs
		function drawImage(imageObj) { 
		
		var envelope_stage = new Kinetic.Stage({
			container: "envelope_container",
			width: 600,
			height: 300
		});
		
		var envelope_layer = new Kinetic.Layer();
		
		var border_rect = new Kinetic.Rect({
			width: 400-40,
			height: envelope_stage.getHeight()-40,
			x: 20, y:20,
			stroke: 'darkgrey',
			strokeWidth: 3
		});
		envelope_layer.add(border_rect);
		
		var point_rect = new Array();
		var envelope_line;
		var y_values = [0,1,0.5,0.5,0]; // as percentage of an envelope
		var x_values = [0,0.05,0.1,0.75,1]; // as percentage from width (duration)
		
		for (var i=0; i<5; i++) {
			point_rect[i] = new Kinetic.Circle({
				id: i,
				//width: 16,
				//height: 16,
				radius: 20,
				//offsetX: 0,
				//offsetY: 0,
				draggable: true, 
				x: (border_rect.getWidth())*timePoint[i]+border_rect.x(), 
				y: (border_rect.getHeight())*(1-amplitude[i])+border_rect.y(),
				fill: 'yellow',
				stroke: 'red',
				opacity: 0.25,
				strokeWidth: 1, 
				dragBoundFunc: function(pos) {
					var newX=pos.x, newY= pos.y;
					if (pos.y< border_rect.y()) newY = border_rect.y();
					if (pos.y > border_rect.y()+border_rect.getHeight()) newY = border_rect.y()+border_rect.getHeight();
					var id = this.id();
					if (id>0 && id<4) { // check if not going above or under neigbouring point
						if (pos.x<=point_rect[id-1].x()+1) newX = point_rect[id-1].x()+1;
						if (pos.x>=point_rect[id+1].x()-1) newX = point_rect[id+1].x()-1;
					}
					if (id==0 || id==4) 
						newX = this.getAbsolutePosition().x; // only vertical movement
					
					return { x: newX, y: newY };
				}
			});	
			point_rect[i].on("dragmove", function () { 
				//console.log("id: ",this.id());
				envelope_line.points([point_rect[0].x(), point_rect[0].y(), point_rect[1].x(), point_rect[1].y(), point_rect[2].x(), point_rect[2].y(), point_rect[3].x(), point_rect[3].y(), point_rect[4].x(), point_rect[4].y()]); 				
				});
			point_rect[i].on("dragend", function() {
				var id=this.id();
				//console.log(id);
				amplitude[id] = (border_rect.getHeight()+border_rect.y()-point_rect[id].y())/border_rect.getHeight();
				if (id>0 && id<4) {
					timePoint[id] = (point_rect[id].x()-border_rect.x())/border_rect.getWidth(); // timePoint[0] always 0, timePoint[4] always 1
				}
				//console.log("amp: ", amplitude[id]);
				
			});
			//TODO KUSKILE: (drawImage.onLoad? sea parameetrid nag upperFreq ja amplitude[i] vastavalt joonisele või siis object vastavalt väärtusele;
			envelope_layer.add(point_rect[i]);
		}
		//point_rect[0].dragBoundFunc(vertical_move_only);
		
		envelope_line = new Kinetic.Line({
			points: [point_rect[0].x(), point_rect[0].y(), point_rect[1].x(), point_rect[1].y(), point_rect[2].x(), point_rect[2].y(), point_rect[3].x(), point_rect[3].y(), point_rect[4].x(), point_rect[4].y() ],
			stroke: 'red',
			//tension: 1
		});
		
		envelope_layer.add(envelope_line);
		envelope_line.moveToBottom();
		
		var frequency_rect = new Kinetic.Rect( {
			width: 80,
			height: envelope_stage.getHeight()-12,
			x: 420, y:6,
			stroke: 'darkblue',
			fill: 'darkblue',
			strokeWidth: 3
		});
		envelope_layer.add(frequency_rect);
		
		
		var label= [];
		for (var i=0; i<=10; i++) {
			var text =  new Kinetic.Text({ x: 510, y: (1-i/10)*frequency_rect.getHeight(),text: index2LogFreq(i/10)+ ' Hz', fill: 'white'  });
			label.push( text);
			envelope_layer.add(text);
		}
		
		
		var lower_line;
		
		var upper_line = new Kinetic.Line ({
			id: 'upper',
			y: frequency_rect.y()+frequency_rect.getHeight()*0.5,
			//offsetY: 12, // how to bind to strokeWidth
			points: [ frequency_rect.x(), 0, frequency_rect.x()+frequency_rect.getWidth(),0],
			draggable: true,
			dragBoundFunc: function(pos) {
				var newY = pos.y;
				if (pos.y<=frequency_rect.y()) newY = frequency_rect.y();
				if (pos.y>=frequency_rect.getHeight()+frequency_rect.y()) 
					newY =  frequency_rect.getHeight()+frequency_rect.y(); // rect.y - stokewidth
					
				if (this.id() == 'lower' && pos.y<=upper_line.y()+2) newY = upper_line.y()+2;
				if (this.id() == 'upper' && pos.y>=lower_line.y()-2 )newY = lower_line.y()-2;
				return { x: this.getAbsolutePosition().x, y: newY };
			},
			stroke: 'red',
			opacity: 0,
			strokeWidth: 20
			
		});
		
		
		lower_line = upper_line.clone();
		lower_line.setId('lower');
		lower_line.y(frequency_rect.y()+frequency_rect.getHeight()*0.7);
		upper_line.offsetY(upper_line.strokeWidth()/2);
		lower_line.offsetY(-lower_line.strokeWidth()/2);
		
		var band_rect = new Kinetic.Rect ({
			width: frequency_rect.getWidth(),
			height: lower_line.y()-upper_line.y(),
			x: frequency_rect.x(), y:upper_line.y(),
			stroke: 'red',
			fill: 'gold',
			opacity: 0.9,
			draggable: true, 
			dragBoundFunc: function(pos) {
				var newY = pos.y;
				if (pos.y<=frequency_rect.y()) newY = frequency_rect.y();
				if (pos.y>=frequency_rect.getHeight()+frequency_rect.y()-band_rect.getHeight())
					newY =  frequency_rect.getHeight()+frequency_rect.y()-band_rect.getHeight(); // rect.y - stokewidth

				return { x: this.getAbsolutePosition().x, y: newY };
			}
		
		});
		
		band_rect.on("dragmove", function() {
			upper_line.y(band_rect.y());
			lower_line.y(band_rect.y()+band_rect.getHeight());
		});
		
		function setFrequency(type) { 
			if (type=="higher") {
				upperFreq = index2LogFreq( (frequency_rect.getHeight()-upper_line.y()+frequency_rect.y())/ frequency_rect.getHeight());
				console.log("Upper freq: ",upperFreq);
				document.getElementById("higher_freq").innerHTML = upperFreq;
			}
			if (type=="lower") {
				lowerFreq = index2LogFreq((frequency_rect.getHeight()-lower_line.y()+frequency_rect.y()) / frequency_rect.getHeight() );
				console.log("Lower freq: ", lowerFreq);
				document.getElementById("lower_freq").innerHTML = lowerFreq;
			}
			
		}
		
		
		band_rect.on("dragend", function() {
			setFrequency("higher");
			setFrequency("lower");
		});
		
		
		upper_line.on("dragmove", function() {
			band_rect.y(upper_line.y());
			band_rect.height(lower_line.y()-upper_line.y());
		
		});
		
		lower_line.on("dragmove", function() {
			band_rect.height(lower_line.y()-upper_line.y());
		
		});
		
		upper_line.on("dragend", function() {
			setFrequency("higher");
		});
		
		lower_line.on("dragend", function() {
			setFrequency("lower");
		});
		
		
		// TODO: add cursor styling see http://www.w3schools.com/cssref/pr_class_cursor.asp
        upper_line.on('mouseover', function() {
          document.body.style.cursor = 'n-resize';
        });
        upper_line.on('mouseout', function() {
          document.body.style.cursor = 'default';
        });
        lower_line.on('mouseover', function() {
          document.body.style.cursor = 's-resize';
        });
        lower_line.on('mouseout', function() {
          document.body.style.cursor = 'default';
        });
        band_rect.on('mouseover', function() {
          document.body.style.cursor = 'ns-resize';
        });
        band_rect.on('mouseout', function() {
          document.body.style.cursor = 'default';
        })
		
		envelope_layer.add(band_rect);
		envelope_layer.add(upper_line);
		envelope_layer.add(lower_line);
		
		envelope_stage.add(envelope_layer);
		
      }
      var imageObj = new Image();
      imageObj.onload = function() {
        drawImage(this);  };
      imageObj.src = 'cursor.png'; // if I don't use it, how then?

      

	
	
	function sendEvent() {
		var parameters = ['i "noise_" 0'];
		var duration = parseFloat(document.myform.duration.value);
		parameters.push(document.myform.duration.value); //add parameters of the eventString and then join
		parameters.push(lowerFreq);
		parameters.push(upperFreq);
		parameters.push(document.myform.pan.value);
		parameters.push(amplitude[0]);
		parameters.push(timePoint[1]);
		parameters.push(amplitude[1]);
		parameters.push(timePoint[2]-timePoint[1]);
		parameters.push(amplitude[2]);
		parameters.push(timePoint[3]-timePoint[2]);
		parameters.push(amplitude[3]);
		parameters.push(timePoint[4]-timePoint[3]);
		parameters.push(amplitude[4]);
		parameters.push( (document.myform.env4freq.checked) ? 1 : 0 );
		parameters.push( (document.myform.inversed.checked) ? 1 : 0);
		var eventString = parameters.join(" ")
		
		console.log("To be sent: ",eventString)
		doSend(eventString);
		myform.sendButton.disabled = true;
		setTimeout(function(){ myform.sendButton.disabled = false;},2000);
	}
	
// play noise locally ------------------------------------------------------	
	var noise = new ShapedNoise();
	function play() {
		noise.setFrequencies(lowerFreq,upperFreq);
		noise.env4freq = document.myform.env4freq.checked;
		noise.inversed = document.myform.inversed.checked;
		noise.amplitude = amplitude;
		noise.timePoint = timePoint;
		noise.duration = parseFloat(document.myform.duration.value);
		noise.pan = parseFloat(document.myform.pan.value);
		noise.play();
	}
	
  
  // init functions --------------------------------------------------------
		
	
	window.onload = function(){
		var connectButton = document.getElementById("connectButton");
		document.getElementById("lower_freq").innerHTML = lowerFreq;
		document.getElementById("higher_freq").innerHTML = upperFreq;
		document.getElementById("duration_label").innerHTML = document.getElementById("duration").value;
		doConnect(); // init websocket on start; suppose the server is ready
	};