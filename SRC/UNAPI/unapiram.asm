	;--- Sample RAM implementation of a MSX-UNAPI specification
	;    By Konami Man, 1-2010
	;
	;    This code implements a sample mathematical specification, "SIMPLE_MATH",
	;    which has just two functions:
	;       Function 1: Returns HL = L + E
	;       Function 2: Returns HL = L * E
	;    The code installs on a mapped RAM segment.
	;    The RAM helper must have been previously installed.
	;
	;    To create your own implementation:
	;    1) In the "Constants" section, modify the API version and implementation version
	;       constants, as well as MAX_FN and MAX_IMPFN.
	;    2) In the "Functions code" section, leave FN_INFO unmodified,
	;       and add your own functions.
	;    3) Add an entry for each function in the "Functions addresses table" section.
	;    4) In the "Data" section, modify the specification identifier
	;       and the implementation identifier.
	;
	;    Optional improvements (up to you):
	;    - Install a RAM helper if none is detected.
	;    - Let the user choose the install segment in DOS 1.
	;    - Add code for uninstallation.


;*******************
;***  CONSTANTS  ***
;*******************

;--- System variables and routines

_TERM0:	equ	#00
_STROUT:	equ	#09

ENASLT:	equ	#0024
EXTBIO:	equ	#FFCA
ARG:	equ	#F847

;--- API version and implementation version

API_V_P:	equ	1
API_V_S:	equ	0
ROM_V_P:	equ	1
ROM_V_S:	equ	1

;--- Maximum number of available standard and implementation-specific function numbers

;Must be 0 to 127
MAX_FN:		equ	2

;Must be either zero (if no implementation-specific functions available), or 128 to 254
MAX_IMPFN:	equ	0


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
	;    Do this by searching all the SIMPLE_MATH
	;    implementations installed, and comparing
	;    the implementation name of each one with
	;    our implementation name.

	;* Copy the implementation identifier to ARG

	ld	hl,UNAPI_ID-SEG_CODE_START+SEG_CODE
	ld	de,ARG
	ld	bc,UNAPI_ID_END-UNAPI_ID
	ldir

	;* Obtain the number of installed implementations

	ld	de,#2222
	xor	a
	ld	b,0
	call	EXTBIO
	ld	a,b
	or	a
	jr	z,NOT_INST

	;>>> The loop for each installed implementations
	;    starts here, with A=implementation index

IMPL_LOOP:	push	af

	;* Obtain the slot, segment and entry point
	;  for the implementation

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
	;  the implementation information

	ld	a,(ALLOC_SLOT)
	ld	iyh,a
	ld	a,(ALLOC_SEG)
	ld	iyl,a
	ld	ix,(IMPLEM_ENTRY)
	ld	hl,(HELPER_ADD)
	xor	a
	call	CALL_HL	;Returns HL=name address

	;* Compare the name of the implementation
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

	;* Names don't match: go to the next implementation

NEXT_IMP:	pop	af
	dec	a
	jr	nz,IMPL_LOOP

	;* No more implementations:
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

	;* Now backup and patch the EXTBIO hook
	;  so that it calls address #4000 of the allocated segment

	ld	hl,EXTBIO
	ld	de,OLD_EXTBIO
	ld	bc,5
	ldir

	di
	ld	a,#CD	;Code for "CALL"
	ld	(EXTBIO),a
	ld	hl,(HELPER_ADD)
	ld	bc,6
	add	hl,bc	;Now HL points to segment call routine
	ld	(EXTBIO+1),hl

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
	and	%11000000	;Entry point #4010 = index 0
	ld	(EXTBIO+3),a

	ld	a,(ALLOC_SEG)
	ld	(EXTBIO+4),a
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
	db	"UNAPI Sample RAM implementation 1.0 (SIMPLE_MATH)",13,10
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


	;===============================
	;===  EXTBIO hook execution  ===
	;===============================

	;>>> Note that this code starts exactly at address #4000

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

	ld	hl,UNAPI_ID
	ld	de,ARG
LOOP:	ld	a,(de)
	call	TOUPPER
	cp	(hl)
	jr	nz,JUMP_OLD2
	inc	hl
	inc	de
	or	a
	jr	nz,LOOP

	;A=255: Jump to old hook

	pop	af
	push	af
	inc	a
	jr	z,JUMP_OLD2

	;A=0: B=B+1 and jump to old hook

	pop	af
	pop	bc
	or	a
	jr	nz,DO_EXTBIO2
	inc	b
	pop	hl
	ld	de,#2222
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
	ld	de,#2222
	ret

	;A>1: A=A-1, and jump to old hook

DO_EXTBIO3:	;A=A-1 already done
	pop	hl
	ld	de,#2222
	jp	OLD_EXTBIO


	;--- Jump here to execute old EXTBIO code

JUMP_OLD2:
	ld	de,#2222
JUMP_OLD:	;Assumes "push hl,bc,af" done
	pop	af
	pop	bc
	pop	hl

	;Old EXTBIO hook contents is here
	;(it is setup at installation time)

OLD_EXTBIO:
	ds	5


	;====================================
	;===  Functions entry point code  ===
	;====================================

UNAPI_ENTRY:
	push	hl
	push	af
	ld	hl,FN_TABLE
	bit	7,a

	if	MAX_IMPFN >= 128

	jr	z,IS_STANDARD
	ld	hl,IMPFN_TABLE
	and	%01111111
	cp	MAX_IMPFN-128
	jr	z,OK_FNUM
	jr	nc,UNDEFINED
IS_STANDARD:

	else

	jr	nz,UNDEFINED

	endif

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

;--- Standard routines addresses table

FN_TABLE:
FN_0:	dw	FN_INFO
FN_1:	dw	FN_ADD
FN_2:	dw	FN_MULT


;--- Implementation-specific routines addresses table

	if	MAX_IMPFN >= 128

IMPFN_TABLE:
FN_128:	dw	FN_DUMMY

	endif


	;========================
	;===  Functions code  ===
	;========================

;--- Mandatory routine 0: return API information
;    Input:  A  = 0
;    Output: HL = Descriptive string for this implementation, on this slot, zero terminated
;            DE = API version supported, D.E
;            BC = This implementation version, B.C.
;            A  = 0 and Cy = 0

FN_INFO:
	ld	bc,256*ROM_V_P+ROM_V_S
	ld	de,256*API_V_P+API_V_S
	ld	hl,APIINFO
	xor	a
	ret


;--- Sample routine 1: adds two 8-bit numbers
;    Input: E, L = Numbers to add
;    Output: HL = Result

FN_ADD:
	ld	h,0
	ld	d,0
	add	hl,de
	ret


;--- Sample routine 2: multiplies two 8-bit numbers
;    Input: E, L = Numbers to multiply
;    Output: HL = Result

FN_MULT:
	ld	b,e
	ld	e,l
	ld	d,0
	ld	hl,0
MULT_LOOP:
	add	hl,de
	djnz	MULT_LOOP
	ret


	;============================
	;===  Auxiliary routines  ===
	;============================

;--- Convert a character to upper-case if it is a lower-case letter

TOUPPER:
	cp	"a"
	ret	c
	cp	"z"+1
	ret	nc
	and	#DF
	ret


	;============================
	;===  UNAPI related data  ===
	;============================

;This data is setup at installation time

MY_SLOT:	db	0
MY_SEG:	db	0


	;--- Specification identifier (up to 15 chars)

UNAPI_ID:
	db	"SIMPLE_MATH",0
UNAPI_ID_END:

	;--- Implementation name (up to 63 chars and zero terminated)

APIINFO:
	db	"Konamiman's RAM implementation of SIMPLE_MATH UNAPI",0


SEG_CODE_END:
