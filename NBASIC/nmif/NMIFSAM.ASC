'********************************************************************
'***  NestorMIF use sample program
'***  By Konami Man, 12-1999
'***
'***  This file can be converted to MSX-BASIC using NestorPreTer
'***
'***
'***  File ALLNBAS.ASC must be used as external macros file:
'***
'***  NPR NBMIFSAM /MAC:ALLNBAS
'***
'***  This file contains all the NestorBASIC functions
'***  defined as macros
'********************************************************************

@remon
'nmifsam.bas
@remoff

'This program loads NestorBASIC and NestorMIF, next loads a MIF file to RAM, 
and next decompresses it.

'NOTE: Remember that if you have not enough available memory to load the 
whole MIF file, you will get error -1 while loading it, or error -2 while 
decompressing it.

'If you have only 128K RAM and DOS 1, you can decompress only MIF files 
smaller than 32K. If you have only 128K RAM and DOS 2, you can't use 
NestorMIF.


'*************************************
'*                                   *
'*  CONSTANTS, VARIABLES AND MACROS  *
'*                                   *
'*************************************

'-----------------
'--  Constants  --
'-----------------

@define TRUE -1
@define FALSE 0
@define YES @TRUE
@define NO  @FALSE

@define MIF_FILE "kyoko_8.mif"           'The MIF file to decompress
@define CM_FILE "nmif.bin"              'NestorMIF program file

@define REQ_SEGS 7		'If there is less than REQ_SEGS segments
				'available, an error message will be shown

@define CM_SEG 5		'Segment where NestorMIF will be loaded
@define CM_DIR 0		'Address where NestorMIF will be loaded
				'MUST BE 0!!

@define MIF_SEG 6		'First seg. where the MIF file will be load
@define MIF_DIR 0		'Address where the MIF file will be loaded


'-----------------
'--  Variables  --
'-----------------

'All variables are centralized in an array d(),
'which is created after loading NestorBASIC,
'except loop counters

@define NUM_VARS 9	'The number of variables

@define NUM_SEGS d(0)
@define FHANDLE d(1)
@define SCREEN d(2)
@define INTERLACED d(3)
@define BORDER d(4)
@define READ_ADD d(5)
@define READ_SIZE d(6)
@define FIRST_ROW d(7)
@define COLUMN d(8)

@define ERROR e
@define LOOP l


'--------------
'--  Macros  --
'--------------

'Remember that all macros for NestorBASIC functions are defined in 
ALLNBAS.ASC

@macro CHK_ERR gosub ~CHK_ERR


'*************************
'*                       *
'*  LOAD OF NESTORBASIC  *
'*                       *
'*************************


~START: maxfiles=0:			'This saves about 250 bytes
	keyoff: screen 0: width 80:
	?"--- Loading NestorBASIC... ---": ?:
	bload"nbpatch.bin",r:   'DON'T FORGET THIS !!!
	bload"nbasic.bin",r:
	defint @ERROR:
	@ERROR= 0:
	if p(0) >4 then
		~LOADOK 	'No error if P(0) is at least 5
	else
		?"ERROR: ";

'*** Error? Then show error message and finish

~	if p(0)=0 then
		?"No mapped memory or only 64K!":
		end

~	if p(0)=1 then
		?"Disk error when loading NestorBASIC!":
		end

~	if p(0)=2 then
		?"No free segments!":
		end

~	if p(0)=3 then
		?"NestorBASIC was already installed.":
		@NB_INFO:
		goto ~ALR_LOAD

~	if p(0)=4 then
		?"Unknown error.":
		end

'*** Jump here if NestorBASIC has been loaded successfully.

~LOADOK:	?"NestorBASIC loaded OK!":
		?"Available segments:"; p(0): ?

'*** Jump here if NestorBASIC was already loaded.

~ALR_LOAD

'*** Check if we have at least REQ_SEGS segments, else finish.

~	defint d: dim d(@NUM_VARS):	'Create dara array
	if p(0)< @REQ_SEGS then
		?"ERROR: ­Not enough free segments!":
		?"I have"; p(0) ;" segments and I need at least";
		@REQ_SEGS; "segments.":
		@FINISH
	else
		@NUM_SEGS=p(0)


'*********************
'*                   *
'*  DATA FILES LOAD  *
'*                   *
'*********************

_turbo on (p(), d(), @ERROR)
dim f$(1): defint @LOOP: @LOOP= 0


'-------------------------------------------
'--  Loads NestorMIF into segment CM_SEG  --
'-------------------------------------------

~	@FILE0= @CM_FILE:	'Open file
	@F_OPEN: @CHK_ERR:
	'@FHANDLE= p(0):

	p(2)= @CM_SEG:	    'Read file
	p(3)= @CM_DIR:
	p(4)= &H4000:
	@F_READ: @CHK_ERR:

	'p(0)= @FHANDLE:        'Close file
	@F_CLOSE: @CHK_ERR


'-------------------------------------------
'--  Reads MIF file into segment MIF_SEG  --
'-------------------------------------------

~	@FILE0= @MIF_FILE:	 'Open file
	@F_OPEN: @CHK_ERR:
	@FHANDLE= p(0):

'Now reads file into consecutive segments. The procedure to do it is:

'We try to read as much data as we can (as much as there is enough room in 
the segment). After reading, we look how many bytes we could read. If we 
could read all the data we tried to, it means that the end of the file has 
not reached yet, so there is still data to read. Then we repeat the read, but 
this time in the next segment.

	@LOOP= @MIF_SEG:
	@READ_ADD= @MIF_DIR:
	@READ_SIZE= 16384 - @MIF_DIR

~READ_LOOP:  p(0)= @FHANDLE:
	p(2)= @LOOP:	'This is the destination segment
	p(3)= @READ_ADD:
	p(4)= @READ_SIZE:
	p(6)= @NO:
	@F_READ:
	@CHK_ERR:
	if p(7)= @READ_SIZE then	'p(7) is the data we could read
		@LOOP= @LOOP + 1:
		@READ_ADD= 0:		'From the second iteration, we
		@READ_SIZE= 16384:	'read always a whole segment
		goto ~READ_LOOP

~	p(0)= @FHANDLE:        'Close file
	@F_CLOSE: @CHK_ERR


'***************************************
'*                                     *
'*  SHOWS INFORMATION ABOUT THE IMAGE  *
'*                                     *
'***************************************

~	p(2)= 1:	'Execute NestorMIF subfunction 1
	p(3)= @MIF_SEG:
	p(4)= @MIF_DIR:
	gosub ~CALL_MIF:

	@SCREEN= p(6):
	@INTERLACED= p(7):
	@BORDER= p(8):

	?"File: "; @FILE0:
	?"Screen:"; @SCREEN:
	?"Interlaced: ";:
	  if @INTERLACED then ?"YES" else ?"NO"
~	?"Border color:"; @BORDER:
	?"Palette:": ?:
	if @SCREEN= 8 or @SCREEN= 12 then
		?"None.":
		goto ~OK_PAL

	'--- This loop shows palette data

~	@COLUMN= 0: @FIRST_ROW= csrlin:
	for @LOOP= 0 to 15:
		p(2)= 1:
		p(3)= @MIF_SEG:
		p(4)= @MIF_DIR:
		p(5)= @LOOP:	'This is the color number

		gosub ~CALL_MIF:

		locate @COLUMN, csrlin:
		? hex$(@LOOP); "= (";
		  hex$(p(9)); "," ;
		  hex$(p(10)); "," ;
		  hex$(p(11)); ")":

	if @LOOP= 7 then @COLUMN= 15: locate @COLUMN, @FIRST_ROW

~	next @LOOP

~OK_PAL:

~	?:?"Press any key to decompress..."

~	if inkey$="" then ~~


'*********************************
'*                               *
'*  SET SCREEN MODE AND PALETTE  *
'*                               *
'*********************************

	'--- Set screen mode

'Since we are inside of a Turbo-block, we can't do just
'screen @SCREEN,,,,,-@INTERLACED

~	if @SCREEN< 9 then screen @SCREEN else
	if @SCREEN= 11 then
		screen 8:
		vdp(26) = 24 else
	if @SCREEN= 12 then
		screen 8:
		vdp(26) = 8

	'--- Set interlaced mode

~	if @INTERLACED then
		vdp(10) = vdp(10) or 12:
		set page 1,1:cls

	'--- Set border color and make color 0 not transparent,
	'    also disable sprites

~	color ,, @BORDER: cls:
	vdp(9) = vdp(9) or 32:		'Color 0 not transparent
	vdp(9) = vdp(9) or 2		'Disable sprites

	'--- Now restores palette

~	p(2)= 2:
	p(3)= @MIF_SEG:
	p(4)= @MIF_DIR:
	gosub ~CALL_MIF


'***************************
'*                         *
'*  GRAPHIC DECOMPRESSION  *
'*                         *
'***************************

~	p(2)= 3:
	p(3)= @MIF_SEG:
	p(4)= @MIF_DIR:
	p(5)= 0:		'Destination VRAM block and address
	p(6)= 0:		'Remember that it is ignored if the image
	gosub ~CALL_MIF:	'is interlaced
	if p(7)<>0 then p(8)=0: end	'Error?

~	if inkey$="" then ~~ else end   'Waits for key pressing and ends


'*****************
'*               *
'*  SUBROUTINES  *
'*               *
'*****************

'----------------------------
'--  NestorMIF call entry  --
'----------------------------

~CALL_MIF: p(0)= @CM_SEG:
	p(1)= @CM_DIR:
	@MC_EXE:
	return


'---------------------------
'--  Disk error checking  --
'---------------------------

'--- If there is any error other than "End of file" when accessing disk,
'    finishes; else returns.

~CHK_ERR:
	if (@ERROR<>0 and @ERROR<>1 and @ERROR<>199) then
		p(8) = @ERROR: p(7)= 0:
		end
	else
		return


'***************
'*             *
'*  FINISHING  *
'*             *
'***************

'Shows error code (if any), and uninstalls NestorBASIC.

_turbo off

~	screen 0,,,,,0:
	if p(8)<>0 then beep: ?"Error"; p(8); "when reading file!!"
	else
	if p(7)<>0 then beep: ?"Error"; p(7); "when decompressing!!"
	else
	?"Success! 8-)"

@FINISH

