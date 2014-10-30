<CsoundSynthesizer>
<CsOptions>
;-odac -+rtaudio=alsa
-odac:system:playback_ -+rtaudio=jack 
-d
</CsOptions>
<CsInstruments>

sr = 44100
nchnls = 2
0dbfs = 1
ksmps = 32

seed 0

; MACROS:
#define COUNT4LONG #10#
#define STARTLEVEL #0.5#
#define BASEFREQ #55#
#define BUFLEN #0.3#

; GLOBALS:

gkLevel init $STARTLEVEL
gaL init 0
gaR init 0
giMaxTesters init 10
giFilterStart init 20 ; after how many noisesounds filter activates
giBufferStart init 4*giFilterStart-2
giNoiseCounter init 1

;CHANNELS:
chn_k "counter",2
chn_k "count",1 ; if 1 count

;TABLES:
giFreqStorage ftgen 10,0,1024, 7, 0, 1024, 0 ; empty table to store here frequencies by the pan positions
giBuffer ftgen 0,0,sr, 2,0


;schedule "start_tester", 0,0,giMaxTesters
instr start_tester
	imaxinstances = p4
	index = 0
	looplabel:
	schedule "tester", random:i(0,imaxinstances/3), random:i(0.1,5) ;, index
	loop_lt index, 1, imaxinstances, looplabel
endin


;schedule "tester", 0,3,0
instr tester
	idur = p3

	ifreqIndex=rnd(0.5); was 0.9
	ifreqLower  pow 10, ifreqIndex* 3 + 1.30102996; calculate in logartimich scale: 0..1 -> 20..20000
	ifreqHigher  pow 10, (random:i(ifreqIndex,0.8)* 3 + 1.30102996)
	
	ipan = rnd(1) 
	iamp0 = rnd(1) ; first amp, all together 5 points, 4 sections of time
	itime1 = rnd(0.4) ; should be given as percentage of the duration
	iamp1 = rnd(1)
	itime2 = rnd(0.4)
	iamp2 = rnd(1)
	itime3 = (1-itime1-itime2)/random:i(1,4) ; 1 - the whole duration
	iamp3 = rnd(1)
	itime4 = 1-itime1-itime2-itime3
	iamp4 = rnd(1); last amp
	iuse4freq = int(rnd(1.99)) ; if > 0 use the envelope also for freq from iFreqLower to ifreqHigher
	ifreqEnvInversed = int(rnd(1.99))
	
	inextTime random idur/2, 10
	;inextTime random 20, 40
	
	
	;print ifreqLower,	ifreqHigher, ipan, iamp0, itime1, iamp1, itime2, iamp2, itime3, iamp3, itime4, iamp4, iuse4freq,  ifreqEnvInversed
	schedule "noise_",0,idur, ifreqLower,	ifreqHigher, ipan, iamp0, itime1, iamp1, itime2, iamp2, itime3, iamp3, itime4, iamp4, iuse4freq,  ifreqEnvInversed
	;print inextTime
	schedule "tester", inextTime, random:i(0.5,5);, imynumber 
	turnoff

endin


;schedule "noise_",0,7, 100,2000,  0.5,    0.01,   0.02, 1,     0.02, 0.2,   0.6,0.3,  0.2, 1,    1,0

instr noise_ , 10
	idur = p3
	ifreqLower =  p4 
	ifreqHigher = p5
	iband = ifreqHigher-ifreqLower
	

	if (chnget:i("count")>0) then ; coun only when checkbox checked
		giNoiseCounter += 1
		if (active("play_buffer")<1)then ; store to buffer only when play_buffer is not playing, otherwise new sound may appear in the long sound
			schedule "record2",0,1, ifreqLower+iband/2 ; forward center frequency					
		endif
		
		
	endif
	chnset giNoiseCounter, "counter"
	if (giNoiseCounter%giFilterStart==0) then
		schedule "filter", 0, 4
	endif
	; start playBuffer
;	if (giNoiseCounter%giBufferStart==0) then
;		schedule "play_buffer", 0, 8
;	endif
	
	
	ipan = p6 
	iamp0 = p7 ; first amp, all together 5 points, 4 sections of time
	itime1 = p8; should be given as percentage of the duration
	iamp1 = p9
	itime2 = p10
	iamp2 = p11
	itime3 = p12
	iamp3 = p13
	itime4 = p14
	iamp4 = p15 ; last amp
	iuse4freq = p16 ; if > 0 use the envelope also for freq from iFreqLower to ifreqHigher to be used by instr filter
	ifreqEnvInversed = p17
	itablesize = 2048
	
	ipanindex = int(ipan*ftlen(giFreqStorage))
	tabw_i ifreqLower+iband/2, ipanindex, giFreqStorage ; store the frequency by the pan point at the beginning
	
	itable ftgentmp 0,0, itablesize, 7,  iamp0, itime1*itablesize, iamp1, itime2*itablesize, iamp2, itime3*itablesize, iamp3, itime4*itablesize,iamp4
	
	adeclick linen 1, 0.05, idur, 0.1
	aenvelope  oscili 1,  1/p3, itable  ;linseg  iamp0, itime1, iamp1, itime2, iamp2, itime3, iamp3, itime4,iamp4
	anoise  pinkish adeclick*aenvelope
	kfreq init  ifreqLower+iband/2
	kband init iband
	if (iuse4freq > 0 ) then
		if (ifreqEnvInversed>0) then
			kindex line 1,p3,0
		else
			kindex line 0,p3,1
		endif
		kenv2 tablei kindex, itable, 1
		kfreq =  ifreqLower + iband*kenv2 ; TODO
		kfreq limit kfreq, 20+iband/2,20000-iband/2
		;printk2 kfreq
	endif
	;alp butterlp anoise, kfreq
	;afiltered butterhp alp, ifreqLower
	afiltered butterbp anoise, kfreq, kfreq/4
	
	aL, aR pan2 afiltered, ipan
	gaL += aL
	gaR += aR
	;outs aL, aR
	if (release()==1) then
		kindex = ipanindex	
		tabw 0, ipanindex, giFreqStorage ; erase the freq value in note end
	endif
	
endin

gaFiltered init 0
gkNexttime init 20 ; first time the filter is called, the the interval is reduced with every call
;schedule "filter", 0, 5
; start from button
instr filter 
	icheck active "play_buffer" 
	print icheck
	if (active:i("play_buffer")>0 || active:i("filter")>1) then ; work only when buffer playback is not active
		turnoff
	endif
	prints "FILTER"
	index = 0
	istartfreq = 0
	until (index>= ftlen(giFreqStorage)-1 || istartfreq>0) do
		istartfreq tab_i index, giFreqStorage
		index += 1
	od  
	print istartfreq
	if istartfreq==0 then ; no frequencies in the table - no sound playing
		turnoff
	endif
	kfreq init 0
	kcutoff init istartfreq ; 0?
	kindex  line 0,p3,ftlen(giFreqStorage)
	kfreq tab kindex, giFreqStorage
	if(kfreq!=0) then
		kcutoff = kfreq	
		; scale to harmonics series:
		;kcutoff = $BASEFREQ* (int(kcutoff/$BASEFREQ)+1)
	endif
	;printk2 kcutoff

	
	kcutoff port kcutoff,0.02, istartfreq	
	ain = (gaL+gaR)/2
	aenv linen 1,0.1,p3,0.5
	gkLevel = $STARTLEVEL*(1-aenv*0.95) ; bad - bump in the beginning, if other filter is playing.
	;outvalue "level", gkLevel
	abp butterbp ain, kcutoff, kcutoff/16 ; bring it out
	afiltered  rezzy abp, kcutoff, 100, 1

	afitlered balance afiltered, ain ; for any case
	
	;afiltered clip afiltered, 0, 0.8

; was: store piece of every freq to table	
;gaFiltered = afiltered*8 ; lose the local varaibale later
;	if (changed(kfreq)==1 && kfreq>0) then ; trigger recording to buffer
;		turnoff2 "record", 0, 1
;		;schedkwhen kfreq, 0.01, 0, "record", 0, $BUFLEN 
;		event "i","record",0,$BUFLEN
;	endif
	
	kpan line 0,p3,1
	aL, aR pan2 afiltered*8*aenv, kpan
	if (kcutoff>0) then
		outs aL, aR
	endif
	
	;schedule "filter", i(gkNexttime), random:i(4,8)
	;print i(gkNexttime)
endin

instr record ; record and mix filtered sound to buffer
	;setksmps 1
	aenv linenr 0.5,0.01,0.01, 0.01 ; new singal somewhat softer
	asig = gaFiltered*aenv
	;out asig
	
	;andx wrap a(timeinstk()), 0, ftlen(giBuffer)
	andx line 0, p3, p3*sr
	tablew   asig*0.1+tab(andx,giBuffer), andx,giBuffer ;(asig+tab(andx,giBuffer))*0.9 ,andx,giBuffer
	;gaFiltered = 0
endin

; schedule "record2", 0, 1, 100
instr record2 ; record resonantfiltered band from given cutoff frequency
	p3 = 0.5 ; wahtever duration given, record 0.5 sec
	icutoff = p4
	
	anoise  pinkish 0.5
	abp butterbp anoise, icutoff, icutoff/16 ; bring it out
	afiltered  rezzy abp, icutoff, 60, 1
	aenv linen 1,0.01,p3, 0.01
	aout = afiltered * aenv
	;outs aout, aout
	
	andx line 0, p3, p3*sr
	tablew   (aout+tab(andx,giBuffer))*0.9 ,andx,giBuffer ; TODO - the buffere gets softer with every recording. Rather add everything up and scale later
endin

instr scheduleBufPlay ; p3 should be duration of the piece, say 6 minutes or so
	chnset 1,"count"
	krate line 1/30, p3, 1/60 ; slower and slower
	ktrig metro krate, 0.01
	schedkwhen ktrig, 0, 0, "play_buffer", 0, 0.25*1/krate

endin

;schedule "play_buffer",0,30
instr play_buffer
	turnoff2 "filter",0,1
	iWindow ftgenonce 0,0, 1024, 9, 0.5, 1, 0		; half of a sine wave
	
	ktime line 0, p3, 0.1
	; ktime = 1/(p3/$BUFLEN)
	;ktime oscil 0.1, 1/3, -1
	;ktime += 0.2 
	aenv linen 1,0.1,p3,0.5
	gkLevel = $STARTLEVEL*(1-aenv*0.95)
	;asig temposcal 1/(p3/$BUFLEN) , 1, 1, giBuffer, 1
	
	ktimewarp init p3/$BUFLEN ;line 0, p3, 2.7	;length of "fox.wav"
	kresample init 1		;do not change pitch
	ibeg = 0			;start at beginning
	iwsize = 4410			;window size in samples with
	irandw = 882			;bandwidth of a random number generator
	itimemode = 0			;1- ktimewarp is "time" pointer; 0 - scale
	ioverlap = 15 ; või 2 või 5
	
	asig sndwarp aenv/4, ktimewarp, kresample, giBuffer, ibeg, iwsize, irandw, ioverlap, iWindow, itimemode
	     outs asig, asig

	 
	outs asig*aenv,asig*aenv	
endin

alwayson "sound_out"
instr sound_out
	;iUpDown ftgenonce 0, 0, 512, -5, 20, 256, 8,256, 20 ; exponential curve for calling inst filter back
	;kindex phasor 1/180 ; full cycle in 3 minute
	;gkNexttime tab kindex, iUpDown,1 ; there must be better way to do it - calculate the values in "filter" before recursion
	
	
	outs gaL*gkLevel, gaR*gkLevel
	gaL = 0
	gaR = 0
	gaFiltered = 0
endin

;alwayson "softnoise" ; - for streaming
instr softnoise ; just to fill streaming servers buffer
	a1 = rnd(0.001)
	outs a1, a1
endin


</CsInstruments>
<CsScore>
</CsScore>
</CsoundSynthesizer>








<bsbPanel>
 <label>Widgets</label>
 <objectName/>
 <x>0</x>
 <y>0</y>
 <width>355</width>
 <height>368</height>
 <visible>true</visible>
 <uuid/>
 <bgcolor mode="nobackground">
  <r>255</r>
  <g>255</g>
  <b>255</b>
 </bgcolor>
 <bsbObject version="2" type="BSBGraph">
  <objectName/>
  <x>5</x>
  <y>69</y>
  <width>350</width>
  <height>150</height>
  <uuid>{6f54329b-ba8f-4579-b9c3-a2162d88da73}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <value>0</value>
  <objectName2/>
  <zoomx>1.00000000</zoomx>
  <zoomy>1.00000000</zoomy>
  <dispx>1.00000000</dispx>
  <dispy>1.00000000</dispy>
  <modex>lin</modex>
  <modey>lin</modey>
  <all>true</all>
 </bsbObject>
 <bsbObject version="2" type="BSBButton">
  <objectName>button1</objectName>
  <x>74</x>
  <y>297</y>
  <width>100</width>
  <height>30</height>
  <uuid>{70a7518d-500c-4d82-bc2d-73bf0d126a27}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <type>event</type>
  <pressedValue>1.00000000</pressedValue>
  <stringvalue/>
  <text>Filter</text>
  <image>/</image>
  <eventLine>i "filter" 0 4</eventLine>
  <latch>false</latch>
  <latched>true</latched>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>level</objectName>
  <x>107</x>
  <y>243</y>
  <width>80</width>
  <height>25</height>
  <uuid>{b73fe584-dce8-4533-8a27-19815af089c9}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.307</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBButton">
  <objectName>button3</objectName>
  <x>77</x>
  <y>338</y>
  <width>100</width>
  <height>30</height>
  <uuid>{f74857ad-25a4-420a-8b06-6e0d4f2babb9}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <type>event</type>
  <pressedValue>1.00000000</pressedValue>
  <stringvalue/>
  <text>Play buffer</text>
  <image>/</image>
  <eventLine>i "play_buffer" 0 15</eventLine>
  <latch>false</latch>
  <latched>true</latched>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>counter</objectName>
  <x>201</x>
  <y>243</y>
  <width>80</width>
  <height>25</height>
  <uuid>{ab61ab05-6f15-48aa-affc-ae5bd558cdbe}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>385.000</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBCheckBox">
  <objectName>count</objectName>
  <x>282</x>
  <y>298</y>
  <width>20</width>
  <height>20</height>
  <uuid>{e0ae05ba-1598-4680-966b-313da03a80f2}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <selected>false</selected>
  <label/>
  <pressedValue>1</pressedValue>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>198</x>
  <y>296</y>
  <width>80</width>
  <height>25</height>
  <uuid>{a0baf04b-360e-4a11-85ff-167051f96f93}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Start counting</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBButton">
  <objectName>channel</objectName>
  <x>2</x>
  <y>243</y>
  <width>100</width>
  <height>30</height>
  <uuid>{882def15-ad85-436c-a491-65e65967e234}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <type>event</type>
  <pressedValue>1.00000000</pressedValue>
  <stringvalue/>
  <text>5 testers</text>
  <image>/</image>
  <eventLine>i "start_tester" 0 0 5</eventLine>
  <latch>false</latch>
  <latched>true</latched>
 </bsbObject>
 <bsbObject version="2" type="BSBButton">
  <objectName>button8</objectName>
  <x>219</x>
  <y>348</y>
  <width>100</width>
  <height>30</height>
  <uuid>{3546fa16-557b-4ae8-96eb-39120af44433}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <type>event</type>
  <pressedValue>1.00000000</pressedValue>
  <stringvalue/>
  <text>Start playbuffers</text>
  <image>/</image>
  <eventLine>i1 0 10</eventLine>
  <latch>false</latch>
  <latched>false</latched>
 </bsbObject>
</bsbPanel>
<bsbPresets>
</bsbPresets>
<EventPanel name="" tempo="60.00000000" loop="8.00000000" x="783" y="492" width="655" height="346" visible="false" loopStart="0" loopEnd="0">i "filter" 0 4 1 0 </EventPanel>
