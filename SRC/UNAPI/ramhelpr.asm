	;--- MSX-UNAPI standalone RAM helper installer
	;    By Konami Man, 2-2010
	;
	;    Usage: ramhelpr [i|f] [command[&command[&...]]]
	;      i: Install only if no RAM helper is already installed
	;      f: Force install, even if the same or other helper is already installed
	;      command: command to be invoked after the install process.
	;               If using COMMAND 2.41, multiple commands can be specified,
	;               separated by &.
	;
	;    Optional improvements (up to you):
	;
	;    - Add code for uninstallation.
	;
	;    * Version 1.1 copies the contents of the SHELL environment item
	;      to the PROGRAM environment item.
	;      This is needed because the SHELL item value becomes RAMHELPR.COM,
	;      and this leads to "Wrong version of COMMAND" errors.


;*******************
;***  CONSTANTS  ***
;*******************

;--- System variables and routines

_TERM0:	equ	#00
_STROUT:	equ	#09
_GENV:	equ	#6B
_SENV:	equ	#6C

ENDTPA:	equ	#0006
RDSLT:	equ	#000C
CALSLT:	equ	#001C
ENASLT:	equ	#0024
RAMSLOT1:	equ	#F342
RAMSLOT3:	equ	#F344
HIMSAV:	equ	#F349
EXPTBL:	equ	#FCC1
EXTBIO:	equ	#FFCA


;*****************************
;***  INITIALIZATION CODE  ***
;*****************************

	org	#100

	;--- Show welcome message

	ld	de,WELCOME_S
	ld	c,_STROUT
	call	5

	;--- Copy SHELL environment item to PROGRAM
	;    (in DOS 2 only, nothing happens in DOS 1)

	ld	hl,SHELL_S
	ld	de,#8000
	ld	b,255
	ld	c,_GENV
	call	5

	ld	hl,PROGRAM_S
	ld	de,#8000
	ld	c,_SENV
	call	5

	;--- Put a 0 at the end of the command line
	;    (needed when running DOS 1)

	ld	hl,(#0080)
	ld	h,0
	ld	bc,#0081
	add	hl,bc
	ld	(hl),0

	;--- Search the parameter

	ld	hl,#80
SRCHPAR:
	inc	hl
	ld	a,(hl)
	cp	" "
	jr	z,SRCHPAR
	or	a
	jr	z,SHOWINFO

	or	32
	cp	"f"
	jr	z,PARAM_OK
	cp	"i"
	jr	nz,SHOWINFO

	;Parameter is "i": check if already installed

	push	hl
	ld	a,#FF
	ld	de,#2222
	ld	hl,0
	call	EXTBIO
	ld	a,h
	or	l
	pop	hl
	jr	z,PARAM_OK

	ld	de,ALINST_S
	ld	c,_STROUT
	call	5
	ld	c,_TERM0
	jp	5

	;--- No parameters or invalid parameter:
	;    show usage information and terminate

SHOWINFO:
	ld	de,USAGE_S
	ld	c,_STROUT
	call	5
	ld	c,_TERM0
	jp	5

	;--- Parameters OK: Do install

PARAM_OK:
	inc	hl
NEXT_PARAM:
	ld	a,(hl)
	or	a
	jr	z,DO_INSTALL
	cp	" "
	jr	nz,DO_INSTALL
	inc	hl
	jr	NEXT_PARAM

DO_INSTALL:
	ld	(CMDLINE_PNT),hl


;**************************************
;***  RAM HELPER INSTALLATION CODE  ***
;**************************************

INST_HELPER:
	;--- Check that TPA end address is at least #C2000

	ld	a,(ENDTPA+1)
	cp	#C2
	jr	nc,OK_TPA

	ld	de,NOTPA_S
	ld	c,_STROUT
	call	5
	ld	c,_TERM0
	jp	5
OK_TPA:

	;--- Allocate space on system work area on page 3

	ld	hl,(HIMSAV)
	ld	bc,P3_HEND0001-P3_HSTART0001
	or	a
	sbc	hl,bc
	ld	(HIMSAV),hl

	;--- Prepare the two copies of the page 3 code

	ld	hl,EXTBIO
	ld	de,HOLDEXT0001
	ld	bc,5
	ldir
	ld	hl,EXTBIO
	ld	de,HOLDEXT0002
	ld	bc,5
	ldir

	xor	a	;Get mappers table
	ld	de,#0401
	call	EXTBIO

	or	a
	jp	nz,BUILDP3_DOS2

	;--- Prepare page 3 code, DOS 1 version

BUILDP3_DOS1:
	ld	ix,MAPTAB0001
	ld	iy,MAPTAB0002

	;Setup mappers entry for the primary mapper

	ld	a,(RAMSLOT3)
	ld	h,#40
	call	ENASLT
	ld	de,#3000
	call	MEMTEST1
	cp	5
	jr	nc,OK_PRIMAP

	ld	a,(RAMSLOT1)
	ld	h,#40
	call	ENASLT
	ld	de,NOMAPPER_S
	ld	c,_STROUT
	call	5
	ld	c,_TERM0
	jp	5
OK_PRIMAP:

	ld	ix,MAPTAB0001+2
	ld	iy,MAPTAB0002+2
	dec	a
	ld	(ix-1),a
	ld	(iy-1),a
	ld	a,(RAMSLOT3)
	ld	(ix-2),a
	ld	(iy-2),a

	;Setup mappers entry for other mappers, if any

	ld	b,3
BUILDP3_DOS1_L:
	push	bc
	call	NEXTSLOT
	pop	bc
	cp	#FF
	jp	z,END_BUILD_MAPTAB	;No more mappers

	push	ix
	push	iy
	ld	hl,RAMSLOT3
	cp	(hl)
	jr	z,BUILDP3_DOS1_N

	ld	c,a
	push	bc
	ld	h,#40
	call	ENASLT
	ld	de,#3000
	call	MEMTEST1
	pop	bc
	cp	2
	jr	c,BUILDP3_DOS1_N
	dec	a

	pop	iy
	pop	ix
	ld	(ix),c
	ld	(iy),c
	ld	(ix+1),a
	ld	(iy+1),a
	inc	ix
	inc	ix
	inc	iy
	inc	iy
	djnz	BUILDP3_DOS1_L
	jr	END_BUILD_MAPTAB

BUILDP3_DOS1_N:
	pop	iy
	pop	ix
	jr	BUILDP3_DOS1_L

	;--- Prepare page 3 code, DOS 2 version

BUILDP3_DOS2:
	push	hl

	xor	a	;Get mapper support routines
	ld	de,#0402
	call	EXTBIO
	ld	bc,#1E
	add	hl,bc
	push	hl
	ld	de,PUT_P10001
	ld	bc,6
	ldir
	pop	hl
	ld	de,PUT_P10002
	ld	bc,6
	ldir

	pop	hl
	ld	ix,MAPTAB0001
	ld	iy,MAPTAB0002
	ld	de,7
	ld	b,4

BUILDP3_DOS2_L:
	ld	a,(hl)
	or	a
	jr	z,END_BUILD_MAPTAB

	ld	(ix),a		;Set slot number
	ld	(iy),a
	inc	hl
	inc	ix
	inc	iy

	ld	a,(hl)	;Set maximum segment available
	dec	a
	ld	(ix),a
	ld	(iy),a
	inc	ix
	inc	iy

	add	hl,de		;Next mapper table entry
	djnz	BUILDP3_DOS2_L

END_BUILD_MAPTAB:
	ld	a,(RAMSLOT1)
	ld	h,#40
	call	ENASLT

	;--- Generate the page 3 code for the appropriate address,
	;    but generate it at #B002 temporarily
	;    (we cannot use the allocated page 3 space yet)

	ld	hl,P3_HCODE1
	ld	de,P3_HCODE2
	ld	ix,(HIMSAV)
	ld	iy,#B002
	ld	bc,P3_HEND0001-P3_HSTART0001
	call	REALLOC

	ld	hl,(HIMSAV)
	ld	(#B000),hl

	;--- All done, now we need to jump to BASIC and do _SYSTEM

	ld	de,OK_S
	ld	c,_STROUT
	call	5

	ld	ix,ComLine+2

	ld	a,(#F313)	;DOS 1 or no commands:
	or	a		;do not copy commands
	jr	z,OKBSC
	ld	hl,(CMDLINE_PNT)
	ld	a,(hl)
	or	a
	jr	z,OKBSC

	ld	(ix-2),"("
	ld	(ix-1),34

BUCSYS2:
	ld	(ix),a	;Copy characters until finding 0
	inc	ix
	inc	hl
	ld	a,(hl)
	cp	"&"
	jr	nz,NOAMP
	ld	a,"^"
NOAMP:	or	a
	jr	nz,BUCSYS2

	ld	(ix),34
	ld	(ix+1),")"
	ld	(ix+2),0
OKBSC:

	ld	hl,SystemProg
	ld	de,08000h
	ld	bc,0400h
	ldir
	jp	08000h

SystemProg:
	ld	a,(0FCC1h)
	push	af
	ld	h,0
	call	024h
	pop	af
	ld	h,040h
	call	024h
	xor	a
	ld	hl,0F41Fh
	ld	(0F860h),hl
	ld	hl,0F423h
	ld	(0F41Fh),hl
	ld	(hl),a
	ld	hl,0F52Ch
	ld	(0F421h),hl
	ld	(hl),a
	ld	hl,0F42Ch
	ld	(0F862h),hl
	ld	hl,#8030
	jp	04601h

	;The following is copied to address #8030

SysTxT2:
	db	#3A	;:
	db	#97,#DD,#EF	;DEF USR =
	db	#0C
SigueDir:
	dw	UsrCode-SystemProg+#8000	;Address of "UsrCode"
	db	#3A,#91,#DD,"(",34,34,")"	;:? USR("")
	db	03Ah,0CAh	;:CALL
	db	"SYSTEM"
ComLine:
	db	0
	ds	128	;Space for extra commands

	;>>> This is the code that will be executed by the USR instruction

UsrCode:

	;--- Copy page 3 code to its definitive address

	ld	hl,#B002
	ld	de,(#B000)
	ld	bc,P3_HEND0001-P3_HSTART0001
	ldir

	;--- Setup new EXTBIO hook

	di
	ld	a,#C3
	ld	(EXTBIO),a
	ld	hl,(#B000)
	ld	bc,NEWEXT0001-P3_HSTART0001
	add	hl,bc
	ld	(EXTBIO+1),hl
	ei

	ret


;--- This routine reallocates a piece of code
;    based on two different copies assembled in different locations.
;    Input: HL = Address of first copy
;           DE = Address of second copy
;           IX = Target reallocation address
;           IY = Address where the patched code will be placed
;           BC = Length of code

REALLOC:
	push	iy
	push	bc
	push	de
	push	hl	;First copy code "as is"
	push	iy	;(HL to IY, length BC)
	pop	de
	ldir
	pop	hl
	pop	de

	push	de
	pop	iy	;IY = Second copy
	ld	b,h
	ld	c,l
	push	ix
	pop	hl
	or	a
	sbc	hl,bc
	ld	b,h
	ld	c,l	;BC = Distance to sum (IX - HL)

	exx
	pop	bc
	exx
	pop	ix	;Originally IY

	;At this point: IX = Destination
	;               IY = Second copy
	;               BC = Distance to sum (new dir - 1st copy)
	;               BC'= Length

REALOOP:
	ld	a,(ix)
	cp	(iy)
	jr	z,NEXT	;If no differences, go to next byte

	ld	l,a
	ld	h,(ix+1)	;HL = Data to be changed
	add	hl,bc	;HL = Data changed
	ld	(ix),l	;IX = Address of the data to be changed
	ld	(ix+1),h

	call	CHKCOMP
	jr	z,ENDREALL

	inc	ix
	inc	iy
NEXT:	inc	ix	;Next byte to compare
	inc	iy	;(if we have done substitution, we need to increase twice)
	call	CHKCOMP
	jr	nz,REALOOP

ENDREALL:
	ret

CHKCOMP:
	exx
	dec	bc	;Decrease counter, if it reaches 0,
	ld	a,b	;return with Z=1
	or	c
	exx
	ret


;--- NEXTSLOT:
;    Returns in A the next slot available on the system every time it is called.
;    When no more slots are available it returns #FF.
;    To initialize it, #FF must be written in NEXTSL.
;    Modifies: AF, BC, HL

NEXTSLOT:
		ld	a,(NEXTSL)
		cp	#FF
		jr	nz,NXTSL1
		ld	a,(EXPTBL)	;First slot
		and	%10000000
		ld	(NEXTSL),a
		ret

NXTSL1:
		ld	a,(NEXTSL)
		cp	%10001111
		jr	z,NOMORESLT	;No more slots?
		cp	%00000011
		jr	z,NOMORESLT
		bit	7,a
		jr	nz,SLTEXP

SLTSIMP:
		and	%00000011	;Simple slot
		inc	a
		ld	c,a
		ld	b,0
		ld	hl,EXPTBL
		add	hl,bc
		ld	a,(hl)
		and	%10000000
		or	c
		ld	(NEXTSL),a
		ret

SLTEXP:
		ld	c,a	;Expanded slot
		and	%00001100
		cp	%00001100
		ld	a,c
		jr	z,SLTSIMP
		add	%00000100
		ld	(NEXTSL),a
		ret

NOMORESLT:
		ld	a,#FF
		ret

NEXTSL:
		db	#FF	;Last returned slot


;--- Direct memory test (for DOS 1)
;    INPUT:   DE = 256 byte buffer, it must NOT be in page 1
;             The slot to be tested must be switched on page 1
;    OUTPUT:  A  = Number of available segments, or:
;                  0 -> Error: not a RAM slot
;                  1 -> Error: not mapped RAM
;    MODIFIES: F, HL, BC, DE

MEMTEST1:
	ld	a,(#5001)	;Check if it is actually RAM
	ld	h,a
	cpl
	ld	(#5001),a
	ld	a,(#5001)
	cpl
	ld	(#5001),a
	cpl
	cp	h
	ld	a,0
	ret	z

	ld	hl,#4001	;Test address
	in	a,(#FD)
	push	af	;A  = Current page 2 segment
	push	de	;DE = Buffer
	ld	b,0

	;* Loop for all segment numbers from 0 to 255

MT1BUC1:
	ld	a,b	;Switch segment on page 1
	out	(#FD),a

	ld	a,(hl)
	ld	(de),a 	;Save data on the test address...
	ld	a,b
	ld	(hl),a	;...then write the supposed segment number on test address
	inc	de
	inc	b
	ld	a,b
	cp	0
	jr	nz,MT1BUC1

	;* Negate the value of test address for segment 0:
	;  this is the number of segments found (0 for 256)

	out	(#FD),a
	ld	a,(hl)
	neg
	ld	(NUMSGS),a
	ld	b,0
	ld	c,a
	pop	de

	;* Restore original value of test address for all segments

MT1BUC2:
	ld	a,b
	out	(#FD),a
	ld	a,(de)
	ld	(hl),a
	inc	de
	inc	b
	ld	a,b
	cp	c
	jr	nz,MT1BUC2

	;* Restore original segment on page 1 and return number of segments

	pop	af
	out	(#FD),a
	ld	a,(NUMSGS)
	cp	1	;No mapped RAM?
	jr	z,NOMAP1
	or	a
	ret	nz
	ld	a,#FF	;If 256 segments, return 255
	ret
NOMAP1:	xor	a
	ret

NUMSGS:	db	0


;**************************************
;***  RAM HELPER CODE (for page 3)  ***
;**************************************

;This code is defined as a macro so that it is easy
;to assemble it twice in order to reallocate it.

P3_HCODE:	macro

P3_HSTART@sym:

	;--- Hook and jump table area

HOLDEXT@sym:	ds	5	;Old EXTBIO hook
PUT_P1@sym:	out	(#FD),a	;To be filled with routine PUT_P1 in DOS 2
		ret
GET_P1@sym:	in	a,(#FD)	;To be filled with routine GET_P1 in DOS 2
		ret

CALLRAM@sym:	jp	_CALLRAM@sym
READRAM@sym:	jp	_READRAM@sym
CALLRAM2@sym:	jp	_CALLRAM2@sym

;Mappers table. Each entry consists of: slot + maximum segment number.
;First entry is for the primary mapper.
;Entries with slot number 0 are unused.
MAPTAB@sym:	ds	4*2

	;--- New destination of the EXTBIO hook

NEWEXT@sym:
	push	af
	inc	a
	jr	nz,IGNORE@sym
	ld	a,d
	cp	#22
	jr	nz,IGNORE@sym
	ld	a,e
	cp	#22
	jr	nz,IGNORE@sym

	ld	hl,CALLRAM@sym	;Address of the jump table
	ld	bc,MAPTAB@sym	;Address of mappers table
	pop	af
	ld	a,3		;Num entries in jump table
	ret

IGNORE@sym:
	pop	af
	jr	HOLDEXT@sym

	;Note: all routines corrupt the alternate register set.


	;--- Routine to call code in a RAM segment
	;    Input:
	;    IYh = Slot number
	;    IYl = Segment number
	;    IX = Target routine address (must be a page 1 address)
	;    AF, BC, DE, HL = Parameters for the target routine
	;Output:
	;    AF, BC, DE, HL, IX, IY = Parameters returned from the target
	;    routine

_CALLRAM@sym:
	ex	af,af
	call	GET_P1@sym
	push	af
	ld	a,iyl
	call	PUT_P1@sym
	ex	af,af
	call	CALSLT
	ex	af,af
	pop	af
	call	PUT_P1@sym
	ex	af,af
	ret


	;--- Routine to read a byte from a RAM segment
	;Input:
	;    A = Slot number
	;    B = Segment number
	;    HL = Address to be read from
	;       (higher two bits will be ignored)
	;Output:
	;    A = Data readed from the specified address
	;    BC, DE preserved

_READRAM@sym:
	ex	af,af
	call	GET_P1@sym
	push	af
	ld	a,b
	call	PUT_P1@sym
	res	7,h
	set	6,h
	ex	af,af
	call	RDSLT
	ex	af,af
	pop	af
	call	PUT_P1@sym
	ex	af,af
	ret


	;--- Routine to call code in a RAM segment
	;    (code location specified in the stack)
	;Input:
	;    AF, BC, DE, HL = Parameters for the target routine
	;Output:
	;    AF, BC, DE, HL, IX, IY = Parameters returned from the target
	;    routine
	;Call as:
	;    CALL CALLRAM2
	;
	;CALLRAM2:
	;    CALL <routine address>
	;    DB %MMAAAAAA
	;    DB <segment number>
	;
	;    MM = Slot as the index of the entry in the mapper table.
	;    AAAAAA = Routine address index:
	;             0=#4000, 1=#4003, ..., 63=#40BD

_CALLRAM2@sym:
	exx
	ex	af,af'

	pop	ix
	ld	e,(ix+1)	;Segment number
	ld	d,(ix)	;Slot and entry point number
	dec	ix
	dec	ix
	push	ix
	ld	iyl,e

	ld	a,d
	and	%00111111
	ld	b,a
	add	a,a
	add	b	;A = Address index * 3
	ld	l,a
	ld	h,#40
	push	hl
	pop	ix	;IX = Address to call

	ld	a,d
	and	%11000000
	rlca
	rlca
	rlca		;A = Mapper table index * 2
	ld	l,a
	ld	h,0
	ld	bc,MAPTAB@sym
	add	hl,bc
	ld	a,(hl)	;A = Slot to call
	ld	iyh,a

	ex	af,af'
	exx
	inc	sp
	inc	sp
	jr	_CALLRAM@sym

CALLIX@sym:	jp	(ix)

P3_HEND@sym:

	endm

;These are the two copies of the code above

P3_HCODE1:	P3_HCODE
P3_HCODE2:	P3_HCODE


;*******************************
;***  VARIABLES AND STRINGS  ***
;*******************************

CMDLINE_PNT:	dw	0	;Pointer to command line after the first parameter

SHELL_S:	db	"SHELL",0
PROGRAM_S:	db	"PROGRAM",0

WELCOME_S:
	db	"Standalone UNAPI RAM helper installer 1.1",13,10
	db	"(c) 2010 by Konamiman",13,10
	db	13,10
	db	"$"

USAGE_S:
	;        --------------------------------------------------------------------------------
	db	"Usage: ramhelpr [i|f] [command[&command[&...]]]",13,10
	db	13,10
	db	"    i: Install only if no RAM helper is already installed.",13,10
	db	"    f: Force install, even if the same or other helper is already installed.",13,10
	db	"    command: DOS command to be invoked after the install process (DOS 2 only).",13,10
	db	"    If using COMMAND 2.41, multiple commands can be specified, separated by &.",13,10
	db	13,10
	db	"$"

ALINST_S:
	db	"*** An UNAPI RAM helper is already installed",13,10,"$"

NOMAPPER_S:
	db	"*** ERROR: No mapped RAM found.",13,10,"$"

NOTPA_S:
	db	"*** ERROR: Not enough TPA space",13,10,"$"

OK_S:	db	"Installed. Have fun!",13,10,"$"
