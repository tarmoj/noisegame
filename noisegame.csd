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
ksmps = 4

seed 0

; MACROS:
#define COUNT4LONG #10#
#define STARTLEVEL #0.5#
#define BASEFREQ #55#
#define BUFLEN #0.3#

opcode TableMax_i, i, ii ; returns maximum value of the table 
	itable, iIgnoreSign xin ; if iIgnoreSign > 0, take absolute values ( from -0.75 and 0.5, max is 0.75 )
	imax  tab_i 0, itable
	imax = (iIgnoreSign > 0 ) ? abs(imax) : imax
	index = 1	
label:
	ivalue tab_i index, itable
	ivalue = (iIgnoreSign > 0 ) ? abs(ivalue) : ivalue
	if (ivalue>imax) then
		imax = ivalue
	endif
	loop_lt index, 1, ftlen(itable)-1, label
	xout imax	
endop 

opcode NormalizeTable, 0, iii 
	isourceTable, idestTable, ilimit xin ; ilimit - in dbfs (like -6)
	imax TableMax_i isourceTable, 1
	ilimit ampdbfs ilimit
	iscale = (imax==0) ? 1 : ilimit/imax ; check against div with 0
	;print ilimit, iscale
	index = 0
label:
	ivalue tab_i index, isourceTable
	;ivalue *= iscale
	tabw_i ivalue*iscale, index, idestTable
	loop_lt index, 1, ftlen(isourceTable)-1, label
endop


;; GLOBALS:

gkLevel init $STARTLEVEL
gkFilterPlaying init 0
gaL init 0
gaR init 0
giMaxTesters init 10
giFilterStart init 20 ; after how many noisesounds filter activates
giBufferStart init 4*giFilterStart-2
giNoiseCounter init 1
gkEndLevel init 1

;; CHANNELS:
chn_k "counter",2
chn_k "count",1 ; if 1 count
chn_k "level",3
chn_k "filter",1
chn_k "buffer",1
chn_k "display", 2
chn_k "lowgain",3
chn_k "highgain",3
chn_k "keepTesting",1

;;TABLES:
giFreqStorage ftgen 10,0,1024, 7, 0, 1024, 0 ; empty table to store here frequencies by the pan positions
giBuffer ftgen 0,0,sr, 2,0
giNormalizedBuffer  ftgen 0,0,sr, 2,0
giWindow ftgen 0,0, 1024, 9, 0.5, 1, 0		; half of a sine wave
	


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
	
	if (chnget:i("keepTesting")>0) then 
		schedule "tester", inextTime, random:i(0.5,5);, imynumber 
	endif
	turnoff

endin



;schedule "noise_",0,7, 100,2000,  0.5,    0.01,   0.02, 1,     0.02, 0.2,   0.6,0.3,  0.2, 1,    1,0

instr noise_ 	
	idur = p3
	ifreqLower =  p4 
	ifreqHigher = p5
	iband = ifreqHigher-ifreqLower	
	if (chnget:i("count")>0) then ; coun only when checkbox checked
		giNoiseCounter += 1
		if (active("play_buffer")<1 && giNoiseCounter%5==0 ) then ; store to buffer only when play_buffer is not playing, otherwise new sound may appear in the long sound
			schedule "record2",0,1, ifreqLower+iband/2 ; forward center frequency					
		endif
	endif
	chnset giNoiseCounter, "counter"
	
	if (giNoiseCounter%giFilterStart==0) then
		schedule "filter", 0, 6
	endif
	
	
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
	itablesize = 4096 ; perhaps can be also smaller
	
	ipanindex = int(ipan*(ftlen(giFreqStorage)-1))
	tabw_i ifreqLower+iband/2, ipanindex, giFreqStorage ; store the frequency by the pan point at the beginning
	
	itable ftgentmp 0,0, itablesize, 7,  iamp0, itime1*itablesize, iamp1, itime2*itablesize, iamp2, itime3*itablesize, iamp3, itime4*itablesize,iamp4 ; create table from given envelope points
	
	;adeclick linenr 1, 0.05, 0.1,0.001
	adeclick linen 1,0.05,p3,0.1
	aenvelope  poscil3 1,  1/p3, itable  ; read envelope
	anoise  pinkish adeclick*aenvelope
	kcenterFreq init  ifreqLower+iband/2
	kband init iband
	if (iuse4freq > 0 ) then
		if (ifreqEnvInversed>0) then
			kindex line 1,p3,0
		else
			kindex line 0,p3,1
		endif
		kenv2 table3 kindex, itable, 1
		;kenv2 *= adeclick ; for any case
		idownlimit = (ifreqLower + iband/2)*0.5 ; octave down from center
		iuplimit = (ifreqLower + iband/2)*2 ; octave up
		kcenterFreq =  idownlimit +  kenv2*(iuplimit-idownlimit) ; move centerfreq according to envelope
		
	endif
	
	;khighFreq = kcenterFreq+iband/2
	;klowFreq = kcenterFreq-iband/2
	khighFreq limit kcenterFreq+iband/2, 22, 19000
	klowFreq limit  kcenterFreq-iband/2, 20, 18000
	alp butterlp anoise, khighFreq
	;alp butterlp alp, khighFreq ; twice to get better cutoff
	afiltered butterhp alp, klowFreq
	;afiltered butterhp afiltered, klowFreq
	
	;afiltered butterbp anoise, kcenterFreq, kfreq/4
	
	if (rms(afiltered)>1) then ; for security
		turnoff 
	endif
	
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
	if (active:i("play_buffer")>0 || active:i("filter")>1) then ; work only when buffer playback is not active
		turnoff
	endif
	prints "FILTER"
	index = 0
	istartfreq = 0
	until (index>= ftlen(giFreqStorage)-1 || istartfreq>0) do ; find first frequency not 0
		istartfreq tab_i index, giFreqStorage
		index += 1
	od  
	istartfreq limit istartfreq, 0, 13000 ; somehow explodes if that higher
	print istartfreq
	if istartfreq==0 then ; no frequencies in the table - no sound playing
		turnoff
	endif
	gkFilterPlaying = 1 ; set flag to sound_out to dim its level
	kfreq init 0
	
	kcutoff init istartfreq ; 0?
	kindex  linseg 0,p3,ftlen(giFreqStorage) ; if just line, continues to rise during release phase
	kfreq tab kindex, giFreqStorage
	if(kfreq!=0) then
		kcutoff = kfreq	
		; scale to harmonics series:
		;kcutoff = $BASEFREQ* (int(kcutoff/$BASEFREQ)+1)
	endif
	;printk2 kcutoff

	
	kcutoff port kcutoff,0.02, istartfreq
	kcutoff limit kcutoff, 50, 14000 ; does it help?	
	ain = (gaL+gaR)/2
	aenv madsr 0.1,0,1,0.2;linenr 1,0.1,0.2, 0.01

	abp butterbp ain, kcutoff, kcutoff/16 ; bring it out
	afiltered  rezzy abp, kcutoff, 99, 1

	afitlered balance afiltered, ain ; for any case

	kpan line 0,p3,1
	kfilterLevel port chnget:k("filter"), 0.02
	aL, aR pan2 afiltered*40*aenv*gkLevel*kfilterLevel, kpan ; TODO: port for filter
	
	
		
	
	if (rms(aL)>1 || rms(aR)>1) then
	 turnoff
	endif
	
	if (kcutoff>0) then
		aL limit aL, - 0.9, 0.9 ; for any case
		aR limit aL, - 0.9, 0.9
		outs aL, aR
	endif
	
	if (release()==1) then ; unset flag for sound_out
		gkFilterPlaying = 0
	endif	
	
	
	;schedule "filter", i(gkNexttime), random:i(4,8)
	;print i(gkNexttime)
endin

instr record ; record and mix filtered sound to buffer - NOT USED NOW
	;setksmps 1
	aenv linenr 0.5,0.01,0.01, 0.01 ; new singal somewhat softer
	 
	asig = gaFiltered*aenv
	;out asig
	
	;andx wrap a(timeinstk()), 0, ftlen(giBuffer)
	andx line 0, p3, p3*sr
	tablew   asig*0.1+tab(andx,giBuffer), andx,giBuffer ;(asig+tab(andx,giBuffer))*0.9 ,andx,giBuffer
	; TODO: miks siin *0.1?
	;gaFiltered = 0
endin

; schedule "record2", 0, 1, 100
instr record2 ; record resonantfiltered band from given cutoff frequency
	p3 = 0.5 ; wahtever duration given, record 0.5 sec
	icutoff = p4
	
	anoise  pinkish 0.5
	abp butterbp anoise, icutoff, icutoff/16 ; bring it out
	icutoff limit icutoff, 100,18000 ; otherwise rezzy may explode
	afiltered  rezzy abp, icutoff, 60, 1
	aenv linen 1,0.01,p3, 0.01
	;aenv linen 1,random:i(0.1,0.45) *p3, p3, p3*random:i(0.1,0.45) ; ma ei tea, kas teeb mingit vahet...
	aout = afiltered * aenv
	;outs aout, aout
	
	andx line 0, p3, p3*sr
	tablew   aout+tab(andx,giBuffer), andx,giBuffer
endin

instr scheduleBufPlay ; p3 should be duration of the piece, say 6 minutes or so
	chnset 1,"count"
	;krate line 1/30, p3, 1/60 ; slower and slower
	irate = 1/40; init 1/30
	; TODO: mingi väljund, kas mitu korda on mängitud, sekundid vms
	kdur line 10, p3, 1/irate*0.6
	ktrig metro irate ;, 0.01
	schedkwhen ktrig, 0, 0, "play_buffer", 0, kdur
	
	if (metro(1)==1) then ; output passed seconds to desplay
		chnset int(timeinsts()),"display"	
	endif
	if (release()==1) then 
		event "i", "fadeout",0, 30 ;fade out main level slowly
	endif 
endin

;schedule "fadeout",0,10
instr fadeout
	schedule "filter", p3*0.3, p3*0.7
	kfade  line i(gkLevel), p3, 0
	chnset kfade, "level"
endin

instr clear_buffer
	index = 0
loophere:
	tabw_i 0, index, giBuffer
	loop_lt index,1,ftlen(giBuffer), loophere	
	
endin

;schedule "play_buffer",0,30
instr play_buffer
	; TO PLAT ALONE: RANDOM GAIN for filters
	;chnset random:i(-10,11),"lowgain"
	;chnset random:i(-10,11),"highgain"
	imax TableMax_i giBuffer, 1
	if (imax==0) then ; quit when the buffer is empty
		turnoff
	endif
	turnoff2 "filter",0,1 ; stop filter, if playing

	NormalizeTable giBuffer, giNormalizedBuffer, -3 ; to -3 db
	
	aenv madsr 0.05,0.1, 0.6, 0.05 ;linen 1,0.01,p3,0.05
	gkFilterPlaying = 1 ; set flag to sound_out to dim its level
	
	;ktimewarp init p3/$BUFLEN ;
	ktimewarp line 0, p3, $BUFLEN	
	kresample init 1		;do not change pitch
	ibeg = 0			;start at beginning
	iwsize = sr/5 ; 44100			;window size in samples with
	irandw = iwsize*0.2 ;882			;bandwidth of a random number generator
	itimemode = 1			;1- ktimewarp is "time" pointer; 0 - scale
	ioverlap = 64 ; the bigger the better but more cpu
	
	asig sndwarp 0.5, ktimewarp, kresample,giNormalizedBuffer, ibeg, iwsize, irandw, ioverlap, giWindow, itimemode
	
	; TODO: port for lowgain , highgain
	alowShelf pareq asig, 600,ampdb(chnget:k("lowgain")), 0.2, 1
	ahighShelf pareq asig, 600,ampdb(chnget:k("highgain")), 0.2, 2 
	
	
	kbufferLevel port chnget:k("buffer"), 0.02
	aout = (alowShelf+ahighShelf+asig*0.1)*0.5 * gkLevel * aenv * kbufferLevel 
	
	kcheck downsamp aout
	if (kcheck>1) then
	 turnoff
	endif
	 
	outs aout,aout
	
	if (release()==1) then ; unset flag for sound_out
		gkFilterPlaying = 0
	endif	
	
endin

alwayson "sound_out"
instr sound_out
	gkLevel chnget "level"
	
	kamp = (gkFilterPlaying==1) ? 0.3 :1
	kamp port kamp, 0.01, 1
	;outvalue "level", kamp
	
	gaL clip gaL, 0, 0.95 ; not to explode
	gaL limit gaL, -1, 1
	gaR clip gaR, 0, 0.95
	gaR limit gaR,-1,1
		
	outs gaL*gkLevel*kamp*gkEndLevel, gaR*gkLevel*kamp*gkEndLevel
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
 <width>358</width>
 <height>563</height>
 <visible>true</visible>
 <uuid/>
 <bgcolor mode="nobackground">
  <r>255</r>
  <g>255</g>
  <b>255</b>
 </bgcolor>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>1</x>
  <y>308</y>
  <width>353</width>
  <height>103</height>
  <uuid>{592b40e3-3d5a-4710-958b-e5b9f7744121}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Testing:</label>
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
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>250</x>
  <y>13</y>
  <width>104</width>
  <height>181</height>
  <uuid>{1b5ed46c-0603-4fd0-b8c3-f36e65bc3a2d}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Filter on buffer</label>
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
  <objectName>button1</objectName>
  <x>125</x>
  <y>337</y>
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
  <latched>false</latched>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>display</objectName>
  <x>107</x>
  <y>252</y>
  <width>80</width>
  <height>25</height>
  <uuid>{b73fe584-dce8-4533-8a27-19815af089c9}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.000</label>
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
  <x>227</x>
  <y>337</y>
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
  <eventLine>i "play_buffer" 0 10</eventLine>
  <latch>false</latch>
  <latched>true</latched>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>counter</objectName>
  <x>107</x>
  <y>212</y>
  <width>80</width>
  <height>25</height>
  <uuid>{ab61ab05-6f15-48aa-affc-ae5bd558cdbe}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>11.000</label>
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
  <x>320</x>
  <y>212</y>
  <width>23</width>
  <height>27</height>
  <uuid>{e0ae05ba-1598-4680-966b-313da03a80f2}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <selected>true</selected>
  <label/>
  <pressedValue>1</pressedValue>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>209</x>
  <y>212</y>
  <width>100</width>
  <height>28</height>
  <uuid>{a0baf04b-360e-4a11-85ff-167051f96f93}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Count for filters</label>
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
  <x>19</x>
  <y>337</y>
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
  <x>208</x>
  <y>246</y>
  <width>138</width>
  <height>52</height>
  <uuid>{3546fa16-557b-4ae8-96eb-39120af44433}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <type>event</type>
  <pressedValue>1.00000000</pressedValue>
  <stringvalue/>
  <text>Start playbuffers</text>
  <image>/</image>
  <eventLine>i "scheduleBufPlay"  0 319</eventLine>
  <latch>false</latch>
  <latched>false</latched>
 </bsbObject>
 <bsbObject version="2" type="BSBVSlider">
  <objectName>level</objectName>
  <x>25</x>
  <y>29</y>
  <width>20</width>
  <height>100</height>
  <uuid>{35ff240e-de17-44f0-a5bd-37a223accafc}</uuid>
  <visible>true</visible>
  <midichan>1</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.19000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>5</x>
  <y>138</y>
  <width>62</width>
  <height>26</height>
  <uuid>{3fcc664d-942f-4d1f-9ba3-85c515ac46e6}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Main level</label>
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
 <bsbObject version="2" type="BSBVSlider">
  <objectName>filter</objectName>
  <x>88</x>
  <y>30</y>
  <width>20</width>
  <height>100</height>
  <uuid>{20a7be8c-f770-41a6-b152-a6ce89d1d916}</uuid>
  <visible>true</visible>
  <midichan>1</midichan>
  <midicc>1</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.70000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>75</x>
  <y>138</y>
  <width>64</width>
  <height>27</height>
  <uuid>{57511ba9-41e2-447a-bbd1-62e59cff0993}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Filter level</label>
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
 <bsbObject version="2" type="BSBVSlider">
  <objectName>buffer</objectName>
  <x>152</x>
  <y>30</y>
  <width>20</width>
  <height>100</height>
  <uuid>{e5e30d9e-d000-4778-b98b-1e1583d02e07}</uuid>
  <visible>true</visible>
  <midichan>1</midichan>
  <midicc>2</midicc>
  <minimum>0.00000000</minimum>
  <maximum>3.00000000</maximum>
  <value>0.66000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>146</x>
  <y>137</y>
  <width>49</width>
  <height>37</height>
  <uuid>{b0e2850d-5344-4ef7-aaf0-4851529ceb51}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Buffer level</label>
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
 <bsbObject version="2" type="BSBVSlider">
  <objectName>lowgain</objectName>
  <x>265</x>
  <y>34</y>
  <width>20</width>
  <height>100</height>
  <uuid>{8fe4676f-6b56-4d12-9354-d0c30d6005ec}</uuid>
  <visible>true</visible>
  <midichan>1</midichan>
  <midicc>6</midicc>
  <minimum>-11.00000000</minimum>
  <maximum>11.00000000</maximum>
  <value>-1.98000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject version="2" type="BSBVSlider">
  <objectName>highgain</objectName>
  <x>301</x>
  <y>34</y>
  <width>20</width>
  <height>100</height>
  <uuid>{3d3b0dc0-c942-47cd-a124-a9847797c2b8}</uuid>
  <visible>true</visible>
  <midichan>1</midichan>
  <midicc>7</midicc>
  <minimum>-11.00000000</minimum>
  <maximum>11.00000000</maximum>
  <value>-3.30000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>258</x>
  <y>139</y>
  <width>38</width>
  <height>38</height>
  <uuid>{62e441bd-4bdd-4646-8f94-cf3b4732ffce}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Low gain</label>
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
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>299</x>
  <y>139</y>
  <width>38</width>
  <height>38</height>
  <uuid>{0dbe4ad0-a992-4570-9e49-7a4d9cc1a445}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>High gain</label>
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
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>1</x>
  <y>212</y>
  <width>98</width>
  <height>31</height>
  <uuid>{5efe64cc-346c-4f38-a518-7c12a8675adb}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Noise events:</label>
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
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>1</x>
  <y>252</y>
  <width>99</width>
  <height>40</height>
  <uuid>{f7ad32e8-dd0f-4686-9f77-885db5625498}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Time (buffers' section):</label>
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
 <bsbObject version="2" type="BSBScope">
  <objectName/>
  <x>8</x>
  <y>413</y>
  <width>350</width>
  <height>150</height>
  <uuid>{48cc1c45-0361-41c6-aa4e-9aca7ca8d930}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <value>-255.00000000</value>
  <type>scope</type>
  <zoomx>2.00000000</zoomx>
  <zoomy>5.00000000</zoomy>
  <dispx>1.00000000</dispx>
  <dispy>1.00000000</dispy>
  <mode>0.00000000</mode>
 </bsbObject>
 <bsbObject version="2" type="BSBCheckBox">
  <objectName>keepTesting</objectName>
  <x>21</x>
  <y>378</y>
  <width>20</width>
  <height>20</height>
  <uuid>{47bec7b1-e38c-4a6a-a457-bd86bf1605c1}</uuid>
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
  <x>51</x>
  <y>377</y>
  <width>124</width>
  <height>25</height>
  <uuid>{78a10703-480f-45e1-90b3-992ebb6ebdbb}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Keep testers playing</label>
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
  <objectName>button25</objectName>
  <x>228</x>
  <y>374</y>
  <width>100</width>
  <height>30</height>
  <uuid>{9efc3cfb-4e90-4a1f-a3ca-60df13d5a8ec}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <type>event</type>
  <pressedValue>1.00000000</pressedValue>
  <stringvalue/>
  <text>Clear buffer</text>
  <image>/</image>
  <eventLine>i "clear_buffer" 0 0</eventLine>
  <latch>false</latch>
  <latched>false</latched>
 </bsbObject>
</bsbPanel>
<bsbPresets>
</bsbPresets>
<EventPanel name="" tempo="60.00000000" loop="8.00000000" x="783" y="492" width="655" height="346" visible="false" loopStart="0" loopEnd="0">i "filter" 0 4 1 0 </EventPanel>
