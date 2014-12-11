	;--- UNAPI implementations lister v1.1
	;    By Konamiman, 2/2010
	;
	;    Usage: apilist <implementation identifier>|*

;*******************
;***  CONSTANTS  ***
;*******************

;--- System variables and routines

_TERM0:		equ	#00
_CONOUT:	equ	#02
_STROUT:	equ	#09

RDSLT:	equ	#000C	;A=PEEK(Slot A, Addr HL)
CALSLT:	equ	#001C	;CALL Slot IYh, Addr IX
ARG:	equ	#F847
EXTBIO:	equ	#FFCA


;**********************
;***  MAIN PROGTAM  ***
;**********************

	org	#100

	;--- Show welcome message

	ld	de,WELCOME_S
	ld	c,_STROUT
	call	5

	;--- Put a 0 at the end of the command line
	;    (needed when running DOS 1)

	ld	hl,(#0080)
	ld	h,0
	ld	bc,#0081
	add	hl,bc
	ld	(hl),0

	;--- Search the parameter (skip spaces in command line)

	ld	hl,#80
SRCHPAR:
	inc	hl
	ld	a,(hl)
	cp	" "
	jr	z,SRCHPAR
	or	a
	jr	nz,GETPAR

	;--- No parameters: show usage information
	;    and terminate

	ld	de,USAGE_S
	ld	c,_STROUT
	call	5
	ld	c,_TERM0
	jp	5

	;--- Copy the parameter to ARG

GETPAR:	ld	de,ARG
	ld	a,(hl)
	cp	"*"
	jr	z,SPECLESS
	ld	bc,15
	ldir
SPECLESS:
	ex	de,hl
	ld	(hl),0	;To prevent paramater >15 chars

	;--- Get number of installed implementations

	ld	de,#2222
	xor	a
	ld	b,0
	call	EXTBIO
	ld	a,b
	ld	(NUM_IMP),a

	;--- Print the number of installed implementations

	ld	de,FOUND_S	;Print "Found"
	ld	c,_STROUT
	call	5

	ld	a,(NUM_IMP)
	ld	ix,TEMP	;Print the number
	call	BYTE2ASC
	ld	(ix),"$"
	ld	de,TEMP
	ld	c,_STROUT
	call	5

	ld	a,(ARG)
	or	a
	jr	z,SPECLESS2

	;> No specificationless application

	ld	de,IMPLEMS_S	;Print "implementations of the"
	ld	c,_STROUT
	call	5

	ld	hl,ARG	;Print the API identifier
PRINTID:
	ld	a,(hl)
	or	a
	jr	z,OKPRINTID
	call	TOUPPER
	ld	e,a
	ld	c,_CONOUT
	push	hl
	call	5
	pop	hl
	inc	hl
	jr	PRINTID
OKPRINTID:

	ld	de,API_S	;Print "API"
	ld	c,_STROUT
	call	5
	jr	OK_PRNUM

	;> Specificationless application

SPECLESS2:
	ld	de,SPECLESS_S
	ld	c,_STROUT
	call	5
OK_PRNUM:

	;--- If no implementations found,
	;    print a dot and terminate; otherwise
	;    print a colon and continue

	ld	a,(NUM_IMP)
	or	a
	jr	nz,NOZEROIMP

	ld	de,DOT_S
	ld	c,_STROUT
	call	5
	ld	c,_TERM0
	jp	5

NOZEROIMP:
	ld	de,COLON_S
	ld	c,_STROUT
	call	5

	;--- Obtain the address of the RAM helper.
	;    If not installed, the address will be 0,
	;    but we will not call it anyway since
	;    there will be no RAM implementations.

	ld	de,#2222
	ld	hl,0
	ld	a,#FF
	call	EXTBIO
	ld	(RAM_HELPER),hl

	;>>> Here begins a loop for all implementations

MAIN_LOOP:

	;--- Obtain location of the current implementation

	ld	a,(CUR_IMP)
	ld	de,#2222
	call	EXTBIO
	ld	(IMP_SLOT),a
	ld	a,b
	ld	(IMP_SEG),a
	ld	(IMP_ENTRY),hl

	;--- Build code to read the implementation name

	ld	a,(IMP_ENTRY+1)
	and	%10000000
	jr	z,BLDCODE2	;Page 3 implemenation:
	ld	a,#7E		;code for "ld a,(hl)"
	ld	(READ_CODE),a
	jr	OKBLDCODE

BLDCODE2:
	ld	a,#CD	;code for "call"
	ld	(READ_CODE),a
	ld	a,(IMP_SEG)
	ld	hl,RDSLT	;ROM implem: call to RDSLT
	cp	#FF
	jr	z,BLDCODE3
	ld	hl,(RAM_HELPER)
	inc	hl
	inc	hl
	inc	hl	;RAM implem: call to RAM helper
BLDCODE3:
	ld	(READ_CODE+1),hl
OKBLDCODE:

	;--- Call function 0 to obtain name and version

	xor	a
	call	EXE_UNAPI
	push	bc	;Save version number

	;--- Print the implementation name

	ld	a,(IMP_SEG)
	ld	b,a
	ld	a,(IMP_SLOT)
NAME_LOOP:
	push	af
	push	bc
	push	hl
READ_CODE:
	nop		;Will be "ld a,hl", "call RDLT" or "call HELPER+3"
	nop
	nop
	or	a
	jr	z,NAME_END
	ld	e,a
	ld	c,_CONOUT
	call	5
	pop	hl
	pop	bc
	pop	af
	inc	hl
	jr	NAME_LOOP

NAME_END:
	pop	hl
	pop	bc
	pop	af

	;--- Now print the implementation version

	ld	ix,TEMP+2
	ld	(ix-2)," "
	ld	(ix-1),"v"

	pop	bc
	push	bc
	ld	a,b
	call	BYTE2ASC	;Main version number

	ld	(ix),"."
	inc	ix

	pop	bc
	ld	a,c
	call	BYTE2ASC	;Secondary version number

	ld	(ix),"$"
	ld	de,TEMP
	ld	c,_STROUT
	call	5

	;--- Print the implementation location

	ld	de,ON_S
	ld	c,_STROUT
	call	5

	;* Location is page 3: simply print "page 3"

	ld	a,(IMP_ENTRY+1)
	and	%10000000
	jr	z,NOPAGE3

	ld	de,PAGE3_S
	ld	c,_STROUT
	call	5
	jr	PRNAME_END
NOPAGE3:
	;* RAM or ROM: print slot number

	ld	de,SLOT_S
	ld	c,_STROUT
	call	5

	ld	ix,TEMP
	ld	a,(IMP_SLOT)	;Build main slot number
	and	%00000011
	add	"0"
	ld	(ix),a
	inc	ix

	ld	a,(IMP_SLOT)
	bit	7,a
	jr	z,BLDSLOT_END

	ld	(ix),"-"	;If expanded, build subslot number
	inc	ix
	rrca
	rrca
	and	%00000011
	add	"0"
	ld	(ix),a
	inc	ix

BLDSLOT_END:	ld	(ix),"$"
	ld	de,TEMP
	ld	c,_STROUT
	call	5

	;* RAM: print segment number

	ld	a,(IMP_SEG)
	cp	#FF
	jr	z,PRNAME_END

	ld	ix,TEMP
	call	BYTE2ASC
	ld	(ix),"$"

	ld	de,SEG_S
	ld	c,_STROUT
	call	5
	ld	de,TEMP
	ld	c,_STROUT
	call	5
PRNAME_END:

	;--- Go for the next implementation, if any

	ld	de,CRLF_S
	ld	c,_STROUT
	call	5

	ld	a,(NUM_IMP)
	ld	b,a
	ld	a,(CUR_IMP)
	cp	b
	ld	c,_TERM0	;Terminate if no more implementations
	jp	z,5

	inc	a
	ld	(CUR_IMP),a
	jp	MAIN_LOOP


;*********************
;***  SUBROUTINES  ***
;*********************

;--- Convert a 1-byte number to an unterminated ASCII string
;    Input:  A  = Number to convert
;            IX = Destination address for the string
;    Output: IX points after the string
;    Modifies: AF, C

BYTE2ASC:	cp	10
	jr	c,B2A_1D
	cp	100
	jr	c,B2A_2D
	cp	200
	jr	c,B2A_1XX
	jr	B2A_2XX

	;--- One digit

B2A_1D:	add	"0"
	ld	(ix),a
	inc	ix
	ret

	;--- Two digits

B2A_2D:	ld	c,"0"
B2A_2D2:	inc	c
	sub	10
	cp	10
	jr	nc,B2A_2D2

	ld	(ix),c
	inc	ix
	jr	B2A_1D

	;--- Between 100 and 199

B2A_1XX:	ld	(ix),"1"
	sub	100
B2A_XXX:	inc	ix
	cp	10
	jr	nc,B2A_2D	;If 1XY with X>0
	ld	(ix),"0"	;If 10Y
	inc	ix
	jr	B2A_1D

	;--- Between 200 and 255

B2A_2XX:	ld	(ix),"2"
	sub	200
	jr	B2A_XXX


;--- Execute a function on an UNAPI implementation

EXE_UNAPI:
	push	af
	ld	ix,(IMP_ENTRY)
	ld	a,ixh
	and	%10000000
	jr	z,EXEUNAP2

	pop	af
	jp	(ix)	;Direct call to page 3

EXEUNAP2:
	ld	a,(IMP_SEG)
	cp	#FF
	jr	nz,EXEUNAP3

	ld	iy,(IMP_SLOT-1)
	ld	ix,(IMP_ENTRY)
	pop	af
	jp	CALSLT	;Call to ROM

EXEUNAP3:	ld	a,(IMP_SLOT)
	ld	iyh,a
	ld	a,(IMP_SEG)
	ld	iyl,a
	pop	af
	ld	ix,(RAM_HELPER)
	push	ix
	ld	ix,(IMP_ENTRY)	;Call to segment
	ret


;--- Convert a character to upper-case if it is a lower-case letter

TOUPPER:
	cp	"a"
	ret	c
	cp	"z"+1
	ret	nc
	and	#DF
	ret


;**************************
;***  DATA AND STRINGS  ***
;**************************

NUM_IMP:	db	0	;Number of implementations found
CUR_IMP:	db	1	;Index of the current implementation
IMP_SLOT:	db	0	;Slot of the current implementation
IMP_SEG:	db	0	;Segment of the current implementation
IMP_ENTRY:	dw	0	;Entry point of the current imp.
RAM_HELPER:	dw	0	;Address of the RAM helper


WELCOME_S:
	db	"UNAPI implementations lister 1.1",13,10
	db	"(c) 2010 by Konamiman",13,10
	db	13,10
	db	"$"

USAGE_S:
	db	"Usage: APILIST <implementation identifier>|*",13,10
	db	"       use * to list specificationless applications.",13,10,"$"

FOUND_S:
	db	"Found $"
IMPLEMS_S:
	db	" implementation(s) of the $"
API_S:	db	" API$"
SPECLESS_S:
	db	" specificationless applications$"
COLON_S:
	db	":",13,10,13,10,"$"
DOT_S:	db	"."
CRLF_S:	db	13,10,"$"

ON_S:	db	" on $"
PAGE3_S:
	db	"page 3$"
SLOT_S:	db	"slot $"
SEG_S:	db	", segment $"

TEMP:	;For temporary data
