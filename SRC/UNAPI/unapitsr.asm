	;--- Sample MSX-UNAPI specificationless application
	;    By Konami Man, 1-2010
	;
	;    This code implements a simple TSR that makes the CAPS led to blink,
	;    it offers just one functions:
	;       Function 1: Set the blink rate to once every B interrupts.
	;    The code installs on a mapped RAM segment.
	;    The RAM helper must have been previously installed.
	;
	;    To create your own application:
	;    1) In the "Constants" section, modify the application version
	;       constant, as well as MAX_FN.
	;    2) Patch more hooks if necessary, by using the PATCH_HOOK routine.
	;    3) Add the code for appropriately servicing the patched hooks, if necessary.
	;    4) In the "Functions code" section, leave FN_INFO unmodified,
	;       and add your own functions.
	;    5) Add an entry for each function in the "Functions addresses table" section.
	;    6) In the "Data" section, modify the application identifier.
	;
	;    Optional improvements (up to you):
	;    - Install a RAM helper if none is detected.
	;    - Provide a command line option to change the blink rate.
	;    - Let the user choose the install segment in DOS 1.
	;    - Add code for uninstallation.


;*******************
;***  CONSTANTS  ***
;*******************

;--- System variables and routines

_TERM0:	equ	#00
_STROUT:	equ	#09

ENDTPA:	equ	#0006
ENASLT:	equ	#0024
EXTBIO:	equ	#FFCA
ARG:	equ	#F847
H_TIMI:	equ	#FD9F

;--- Application version

ROM_V_P:	equ	1
ROM_V_S:	equ	0

;--- Maximum function number available

;Must be 1 to 254,
;or 0 if no extra functions are provided
MAX_FN:		equ	1


;***************************
;***  INSTALLATION CODE  ***
;***************************

	org	#100

	;--- Show welcome message

	ld	de,WELCOME_S
	ld	c,_STROUT
	call	5

	;--- Locate the RAM helper, terminate with error if not installed

	ld	de,#2222
	ld	hl,0
	ld	a,#FF
	call	EXTBIO
	ld	a,h
	or	l
	jr	nz,HELPER_OK

	ld	de,NOHELPER_S
	ld	c,_STROUT
	call	5
	ld	c,_TERM0
	jp	5
HELPER_OK:
	ld	(HELPER_ADD),hl
	ld	(MAPTAB_ADD),bc

	;--- Check if we are already installed.
	;    Do this by searching all the specificationless
	;    applications installed, and comparing
	;    the implementation name of each one with
	;    our implementation name.

	;* Copy an empty implementation identifier to ARG

	xor	a
	ld	(ARG),a

	;* Obtain the number of installed applications

	ld	de,#2222
	xor	a
	ld	b,0
	call	EXTBIO
	ld	a,b
	or	a
	jr	z,NOT_INST

	;>>> The loop for each installed application
	;    starts here, with A=implementation index

IMPL_LOOP:	push	af

	;* Obtain the slot, segment and entry point
	;  for the application

	ld	de,#2222
	call	EXTBIO
	ld	(ALLOC_SLOT),a
	ld	a,b
	ld	(ALLOC_SEG),a
	ld	(IMPLEM_ENTRY),hl

	;* If the implementation is in page 3
	;  or in ROM, skip it

	ld	a,h
	and	%10000000
	jr	nz,NEXT_IMP
	ld	a,b
	cp	#FF
	jr	z,NEXT_IMP

	;* Call the routine for obtaining
	;  the application information

	ld	a,(ALLOC_SLOT)
	ld	iyh,a
	ld	a,(ALLOC_SEG)
	ld	iyl,a
	ld	ix,(IMPLEM_ENTRY)
	ld	hl,(HELPER_ADD)
	xor	a
	call	CALL_HL	;Returns HL=name address

	;* Compare the name of the application
	;  against our own name

	ld	a,(ALLOC_SEG)
	ld	b,a
	ld	de,APIINFO-SEG_CODE_START+SEG_CODE
	ld	ix,(HELPER_ADD)
	inc	ix
	inc	ix
	inc	ix	;Now IX=helper routine to read from segment
NAME_LOOP:	ld	a,(ALLOC_SLOT)
	push	bc
	push	de
	push	hl
	push	ix
	call	CALL_IX
	pop	ix
	pop	hl
	pop	de
	pop	bc
	ld	c,a
	ld	a,(de)
	cp	c
	jr	nz,NEXT_IMP
	or	a
	inc	hl
	inc	de
	jr	nz,NAME_LOOP

	;* The names match: already installed

	ld	de,ALINST_S
	ld	c,_STROUT
	call	5
	ld	c,_TERM0
	jp	5

	;* Names don't match: go to the next application

NEXT_IMP:	pop	af
	dec	a
	jr	nz,IMPL_LOOP

	;* No more application:
	;  continue installation process

NOT_INST:

	;--- Obtain the mapper support routines table, if available

	xor	a
	ld	de,#0402
	call	EXTBIO
	or	a
	jr	nz,ALLOC_DOS2

	;--- DOS 1: Use the last segment on the primary mapper

	ld	hl,(MAPTAB_ADD)
	ld	b,(hl)
	inc	hl
	ld	a,(hl)
	jr	ALLOC_OK

	;--- DOS 2: Allocate a segment using mapper support routines

ALLOC_DOS2:
	ld	a,b
	ld	(PRIM_SLOT),a
	ld	de,ALL_SEG
	ld	bc,15*3
	ldir

	ld	a,(PRIM_SLOT)
	or	%00100000	;Try primary mapper, then try others
	ld	b,a
	ld	a,1		;System segment
	call	ALL_SEG
	jr	nc,ALLOC_OK

	ld	de,NOFREE_S	;Terminate if no free segments available
	ld	c,_STROUT
	call	5
	ld	c,_TERM0
	jp	5

ALLOC_OK:
	ld	(ALLOC_SEG),a
	ld	a,b
	ld	(ALLOC_SLOT),a

	;--- Switch segment, copy code, and setup data

	call	GET_P1		;Backup current segment
	ld	(P1_SEG),a

	ld	a,(ALLOC_SLOT)	;Switch slot and segment
	ld	h,#40
	call	ENASLT
	ld	a,(ALLOC_SEG)
	call	PUT_P1

	ld	hl,#4000	;Clear the segment first
	ld	de,#4001
	ld	bc,#4000-1
	ld	(hl),0
	ldir

	ld	hl,SEG_CODE	;Copy the code to the segment
	ld	de,#4000
	ld	bc,SEG_CODE_END-SEG_CODE_START
	ldir

	ld	hl,(ALLOC_SLOT)	;Setup slot and segment information
	ld	(MY_SLOT),hl

	;* Now backup and patch the EXTBIO and H_TIMI hooks
	;  so that it calls the appropriate jump table entry
	;  on the allocated segment

	ld	hl,EXTBIO
	ld	de,OLD_EXTBIO
	ld	bc,5
	ldir

	ld	hl,H_TIMI
	ld	de,OLD_HTIMI
	ld	bc,5
	ldir

	di
	xor	a
	ld	ix,EXTBIO
	call	PATCH_HOOK
	ld	a,1
	ld	ix,H_TIMI
	call	PATCH_HOOK
	ei

	;--- Restore slot and segment, and terminate

	ld	a,(PRIM_SLOT)
	ld	h,#40
	call	ENASLT
	ld	a,(P1_SEG)
	call	PUT_P1

	ld	de,OK_S
	ld	c,_STROUT
	call	5

	ld	c,_TERM0
	jp	5

	;>>> Other auxiliary code

CALL_IX:	jp	(ix)
CALL_HL:	jp	(hl)


;--- This routine patches a hook so that
;    it calls the routine with the specified index
;    in the allocated segment.
;    Input: A  = Routine index, 0 to 63
;           IX = Hook address
;           ALLOC_SEG and ALLOC_SLOT set

PATCH_HOOK:
	push	af
	ld	a,#CD	;Code for "CALL"
	ld	(ix),a
	ld	hl,(HELPER_ADD)
	ld	bc,6
	add	hl,bc	;Now HL points to segment call routine
	ld	(ix+1),l
	ld	(ix+2),h

	ld	hl,(MAPTAB_ADD)
	ld	a,(ALLOC_SLOT)
	ld	d,a
	ld	e,0	;Index on mappers table
SRCHMAP:
	ld	a,(hl)
	cp	d
	jr	z,MAPFND
	inc	hl
	inc	hl	;Next table entry
	inc	e
	jr	SRCHMAP
MAPFND:
	ld	a,e	;A = Index of slot on mappers table
	rrca
	rrca
	and	%11000000
	pop	de	;Retrieve routine index
	or	d
	ld	(ix+3),a

	ld	a,(ALLOC_SEG)
	ld	(ix+4),a
	ret


;****************************************************
;***  DATA AND STRINGS FOR THE INSTALLATION CODE  ***
;****************************************************

	;--- Variables

PRIM_SLOT:	db	0	;Primary mapper slot number
P1_SEG:	db	0		;Segment number for TPA on page 1
ALLOC_SLOT:	db	0	;Slot for the allocated segment
ALLOC_SEG:	db	0	;Allocated segment
HELPER_ADD:	dw	0	;Address of the RAM helper jump table
MAPTAB_ADD:	dw	0	;Address of the RAM helper mappers table
IMPLEM_ENTRY:	dw	0	;Entry point for implementations

	;--- DOS 2 mapper support routines

ALL_SEG:	ds	3
FRE_SEG:	ds	3
RD_SEG:	ds	3
WR_SEG:	ds	3
CAL_SEG:	ds	3
CALLS:	ds	3
PUT_PH:	ds	3
GET_PH:	ds	3
PUT_P0:	ds	3
GET_P0:	ds	3
PUT_P1:	out	(#FD),a
	ret
GET_P1:	in	a,(#FD)
	ret
PUT_P2:	ds	3
GET_P2:	ds	3
PUT_P3:	ds	3

	;--- Strings

WELCOME_S:
	db	"CAPS blinker - an UNAPI sample specificationless application 1.0",13,10
	db	"(c) 2010 by Konamiman",13,10
	db	13,10
	db	"$"

NOHELPER_S:
	db	"*** ERROR: No UNAPI RAM helper is installed",13,10,"$"

NOMAPPER_S:
	db	"*** ERROR: No mapped RAM found",13,10,"$"

NOFREE_S:
	db	"*** ERROR: Could not allocate any RAM segment",13,10,"$"

OK_S:	db	"Installed. Have fun!",13,10,"$"

ALINST_S:	db	"*** Already installed.",13,10,"$"


;*********************************************
;***  CODE TO BE INSTALLED ON RAM SEGMENT  ***
;*********************************************

SEG_CODE:
	org	#4000
SEG_CODE_START:

	;===================
	;===  Jump table ===
	;===================

	jp	DO_EXTBIO
	jp	DO_HTIMI


	;===============================
	;===  EXTBIO hook execution  ===
	;===============================

DO_EXTBIO:
	push	hl
	push	bc
	push	af
	ld	a,d
	cp	#22
	jr	nz,JUMP_OLD
	cp	e
	jr	nz,JUMP_OLD

	;Check API ID

	ld	a,(ARG)
	or	a
	jr	nz,JUMP_OLD

	;A=255: Jump to old hook

	pop	af
	push	af
	inc	a
	jr	z,JUMP_OLD

	;A=0: B=B+1 and jump to old hook

	pop	af
	pop	bc
	or	a
	jr	nz,DO_EXTBIO2
	inc	b
	pop	hl
	jp	OLD_EXTBIO
DO_EXTBIO2:

	;A=1: Return A=Slot, B=Segment, HL=UNAPI entry address

	dec	a
	jr	nz,DO_EXTBIO3
	pop	hl
	ld	a,(MY_SEG)
	ld	b,a
	ld	a,(MY_SLOT)
	ld	hl,UNAPI_ENTRY
	ret

	;A>1: A=A-1, and jump to old hook

DO_EXTBIO3:	;A=A-1 already done
	pop	hl
	jr	OLD_EXTBIO


	;--- Jump here to execute old EXTBIO code

JUMP_OLD:	;Assumes "push hl,bc,af" done
	pop	af
	pop	bc
	pop	hl

	;Old EXTBIO hook contents is here
	;(it is setup at installation time)

OLD_EXTBIO:
	ds	5


	;===============================
	;===  H_TIMI hook execution  ===
	;===============================

DO_HTIMI:
	ld	a,(CAPS_CNT)
	dec	a
	ld	(CAPS_CNT),a
	or	a
	ret	nz

	ld	a,(BLINK_RATE)
	ld	(CAPS_CNT),a

	ld	a,(CAPS_STATE)
	cpl
	ld	(CAPS_STATE),a
	or	a
	jr	nz,DO_CAPS_ON

DO_CAPS_OFF:
	in	a,(#AA)
	or	%01000000
	jr	DO_CAPS_END

DO_CAPS_ON:
	in	a,(#AA)
	and	%10111111

DO_CAPS_END:
	out	(#AA),a

	;Old H_TIMI hook contents is here
	;(it is setup at installation time)
OLD_HTIMI:
	ds	5


CAPS_STATE:	;Current state, 0=off, 255=on
	db	0

CAPS_CNT:	;Timer interrupts counter, current value
	db	0

BLINK_RATE:	;Blink rate, less is faster
	db	50


	;====================================
	;===  Functions entry point code  ===
	;====================================

UNAPI_ENTRY:
	push	hl
	push	af
	ld	hl,FN_TABLE
	cp	MAX_FN
	jr	z,OK_FNUM
	jr	nc,UNDEFINED

OK_FNUM:
	add	a,a
	push	de
	ld	e,a
	ld	d,0
	add	hl,de
	pop	de

	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a

	pop	af
	ex	(sp),hl
	ret

	;--- Undefined function: return with registers unmodified

UNDEFINED:
	pop	af
	pop	hl
	ret


	;===================================
	;===  Functions addresses table  ===
	;===================================

;--- Routines addresses table

FN_TABLE:
FN_0:	dw	FN_INFO
FN_1:	dw	FN_SETRATE


	;========================
	;===  Functions code  ===
	;========================

;--- Mandatory routine 0: return API information
;    Input:  A  = 0
;    Output: HL = Descriptive string for this implementation, on this slot, zero terminated
;            DE = API version supported, D.E
;                 (always zero for specificationless applications)
;            BC = This implementation version, B.C.
;            A  = 0 and Cy = 0

FN_INFO:
	ld	bc,256*ROM_V_P+ROM_V_S
	ld	de,0
	ld	hl,APIINFO
	xor	a
	ret


;--- Routine 1: set CAPS led blink rate
;    Input:  B = New blink rate, less is faster
;    Output: -

FN_SETRATE:
	ld	a,b
	ld	(BLINK_RATE),a
	ld	a,1
	ld	(CAPS_CNT),a	;Force the new rate to apply right now
	ret


	;============================
	;===  UNAPI related data  ===
	;============================

;This data is setup at installation time

MY_SLOT:	db	0
MY_SEG:	db	0

	;--- Implementation name (up to 63 chars and zero terminated)

APIINFO:
	db	"Konamiman's UNAPI CAPS led blinker",0


SEG_CODE_END:
