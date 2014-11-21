	;--- FILE MANAGEMENT ROUTINES
	;    For DOS 1 and DOS 2
	;    By Konami Man, 3-97


;-----================================-----
;-----===== MACROS AND CONSTANTS =====-----
;-----================================-----

;--- User-definable parameters

;"DOS" constant indicates the DOS version supported:

;DOS=1 -> Works under DOS 1 and DOS 2, but using DOS 1 methods (FCBs).
;         Directories, attributes and other DOS 2 features are not supported.
;         Routines size: 985 + 38 * MAXFILES bytes
;DOS=2 -> Works only under DOS 2.
;         Routines size: 375 bytes
;DOS=12-> Works under DOS 1 and DOS 2, using the appropriate methods for
;         each operating system. Larger code but the most efficient one.
;         Routines size: 1292 + 38 * MAXFILES bytes

DOS:	equ	12

;"MAXFILES" constant indicates the maximum number of simultaneously opened
;files under DOS 1. Not used when DOS constant is 2.

MAXFILES:	equ	3

;"DOSENTRY" constant must be #0005 when using these routines in MSX-DOS
;environment, and #F37D when using them in MSX Disk BASIC environment.

DOSENTRY:	equ	#0005

;"START" constants defines the starting address of the routines.
;If set to zero, no ORG directive will be used (useful when appending
;these routines in the middle of any other code).

START:	equ	0

;--- DOS functions

_FOPEN:	equ	#0F
_FCLOSE:	equ	#10
_SFIRST:	equ	#11
_SNEXT:	equ	#12
_FDEL:	equ	#13
_FMAKE:	equ	#16
_FREN:	equ	#17
_SETDTA:	equ	#1A	; ^
_WRBLK:	equ	#26	; |
_RDBLK:	equ	#27	; +-- DOS 1

_FFIRST:	equ	#40	; +-- DOS 2
_FNEXT:	equ	#41	; |
_OPEN:	equ	#43	; V
_CREATE:	equ	#44
_CLOSE:	equ	#45
_READ:	equ	#48
_WRITE:	equ	#49
_SEEK:	equ	#4A
_DELETE:	equ	#4D
_RENAME:	equ	#4E
_DOSVER:	equ	#6F

;--- Other constants

ENYEMAY:	equ	165
ENYEMIN:	equ	164
LONBUF:	equ	70	;Generic buffer size (min. 69 bytes)

;--- Macros

doscall:	macro	@function
	ld	c,@function
	call	DOSENTRY
	endm

;--- Start

	if	START<>0
	org	START
	endif



;-----===================================-----
;-----===== VARIABLES AND DATA AREA =====-----
;-----===================================-----

NUMFILES:	db	0	;Number of currently opened files
BUFFER:	ds	LONBUF	;Generic buffer for all routines

;FCBs AREA. Each opened file needs 37 bytes for its FCB on DOS 1.
;An extra byte is used for indicate if the FCB is being used.
;This area is not needed under DOS 2.

	if	DOS<>2

FCBS:	ds	38*MAXFILES

	endif



;-----=========================-----
;-----===== ROUTINES LIST =====-----
;-----=========================-----

;--- Auxiliary routines

;CLBUF:     Clears generic buffer
;MIN2MAY:   Converts a character to uppercase
;CHKDOS2:   Checks the DOS version
;CONVNAME:  Converts a filename from/to FCB format

;--- User routines

;DIR:       Seacrh a file and show information about it
;REN:       Rename file
;CREATE:    Create file
;DEL:       Delete file
;OPEN:      Open file
;CLOSE:     Close file
;READ:      Read from file
;WRITE:     Write to file
;SEEK:      Move file pointer



;-----==============================-----
;-----===== AUXILIARY ROUTINES =====-----
;-----==============================-----

;--- NAME: CLBUF
;      Clears generic buffer
;    INPUT:     -
;    OUTPUT:    -
;    REGISTERS: -
;    CALLS TO:  -
;    VARIABLES: BUFFER, LONBUF

CLBUF:	push	hl,de,bc
	ld	hl,BUFFER
	ld	de,BUFFER+1
	ld	bc,LONBUF-1
	ld	(hl),0
	ldir
	pop	bc,de,hl
	ret


;--- NAME: MIN2MAY
;      Converts a character to upper case
;    INPUT:     A = Character
;    OUTPUT:    A = Character uppercased if it was lower case,
;                   unchanged otherwise
;    REGISTERS: F
;    CALLS TO:  -
;    VARIABLES: ENYEMIN, ENYEMAY

MIN2MAY:	cp	ENYEMIN
	jp	nz,NOENYE
	ld	a,ENYEMAY
	ret
NOENYE:	cp	"a"
	ret	c
	cp	"z"+1
	ret	nc
	and	%11011111
	ret


	if	DOS<>1

;--- NAME: CHKDOS2
;      Obtains MSX-DOS version
;    INPUT:     -
;    OUTPUT:    Cy = 1 -> MSX-DOS 1.x or MSX-DOS 2.1x
;               Cy = 0 -> MSX-DOS 2.20 or higher
;    REGISTERS: F
;    CALLS TO:  -
;    VARIABLES: -

CHKDOS2:	ld	(ATEMP),a
	ld	a,(DV)	;If DV=0, DOS version has not been
	cp	2	;checked yet.
	jp	z,CD2END2	;Si DV=1 -> DOS 1 or DOS 2.1
	or	a	;Si DV=2 -> DOS 2.20 or higher
	scf
	jp	nz,CD2END2

	push	bc,de,hl	;Checks DOS version and sets DV.
	doscall	_DOSVER
	ld	a,b
	cp	2
	ld	a,1
	jp	c,CD2END
	ld	a,c
	cp	2
	ld	a,1
	jp	c,CD2END
	ld	a,2

CD2END:	ld	(DV),a
	pop	hl,de,bc
	jp	CHKDOS2

CD2END2:	ld	a,(ATEMP)
	ret

DV:	db	0
ATEMP:	db	0

	endif


	if	DOS<>2

;--- NAME: CONVNAME
;      Converts a filename from/to FCB format
;      Does NOT check for invalid characters in the filename
;    INPUT:      HL = Source string
;                     FCB format:     12 characteres, without dot
;                                     (padded with spaces if necessary)
;                                     The first character is the drive number
;                                     (0: default, 1: A, 2: B, etc)
;                     Normal format:  Finished with 0, maximum 14 characters
;                                     Starting with a drive letter and ":",
;                                     otherwise the default drive 0 is assumed
;                DE = Destination string (ditto)
;                Cy = 0 -> Convert normal format to FCB format
;                Cy = 1 -> Convert FCB format to normal format
;     OUTPUT:    B  = Destination string length
;                     FCB format: always 12
;                     Normal format: does not include the termination 0
;     REGISTERS: AF, C
;     CALLS TO:  MIN2MAY
;     VARIABLES: -

;Formats example:
; 1,"FILE     EXT"  --> FCB format
; "a:file.ext",0    --> Normal format

CONVNAME:	push	de,hl
	jp	c,FCB2NOR
	xor	a
	ld	(EXTFLG),a
	jp	NOR2FCB
ENDCONV:	pop	hl,de
	ret

;--- Normal to FCB format conversion

NOR2FCB:	push	de,hl,de	;Fill name zone with spaces
	pop	hl
	inc	de
	ld	a," "
	ld	(hl),a
	ld	bc,11
	ldir
	pop	hl,de
	xor	a
	ld	(de),a	;Set drive to 0

	inc	hl	;Check if drive letter has been
	ld	a,(hl)	;specified, if so, convert to the
	cp	":"	;appropriate drive number.
	jp	nz,NOUN1
	dec	hl
	ld	a,(hl)
	call	MIN2MAY
	sub	"A"-1
	ld	(de),a
	inc	hl
	inc	hl
	inc	hl

NOUN1:	inc	de
	dec	hl
	xor	a	;Loop for the name
	ld	(EXTFLG),a
	ld	b,8
	call	N2FBUC

	ld	a,(EXTFLG)	;If we reached the end, do not
	or	a	;process extension
	jp	nz,ENDCONV
	ld	a,#FF
	ld	(EXTFLG),a
	ld	b,3	;Loop for the extension
	call	N2FBUC
	ld	b,12
	jp	ENDCONV
;                                   ;The first 8 or 3 characters are written
N2FBUC:	ld	a,(hl)	;uppercased, unless a 0 (string end),
	inc	hl	;a dot (name end) or an asterisk
	cp	"*"	;(which is replaced with "?"s)
	jp	z,AFND1	;is found.
	cp	"."
	jp	z,PFND1
	or	a
	jp	z,EFND1
	call	MIN2MAY
	ld	(de),a
	inc	de
	djnz	N2FBUC

PASASOB:	ld	a,(EXTFLG)	;If it is the extension,
	or	a	;nothing to skip.
	ret	nz

	ld	a,(hl)	;Skips unused characters (over 8
	inc	hl	;or 3) in the filename.
	or	a
	jp	z,EFND1
	cp	"."
	jp	nz,PASASOB
	ret

	;Asterisk found

AFND1:	ld	a,"?"	;Fills with "?" until completing
AFND11:	ld	(DE),a	;8 or 3 characteres
	inc	DE
	djnz	AFND11
	jp	PASASOB

	;Dot found

PFND1:	ld	a,(EXTFLG)
	or	a
	jp	nz,EFND1
	ld	a,b
	cp	8	;If starts with a dot,
	dec	hl	;assumes "*.<ext>"
	jp	z,AFND1
	inc	hl
	ld	a," "	;Fills with " " until completing
PFND11:	ld	(DE),a	;8 or 3 characters
	inc	de
	djnz	PFND11
	ret

EFND1:	ld	a,1
	ld	(EXTFLG),a
	ret

EXTFLG:	db	0	;#FF when processing extension,
;                                   ;1 when the string end is reached

;--- FCB to normal format conversion

FCB2NOR:	push	de
	ld	a,(hl)
	or	a
	jp	z,NOUN2
	add	"A"-1
	ld	(de),a
	inc	de
	ld	a,":"
	ld	(de),a
	inc	de

NOUN2:	inc	hl
	ld	b,8	;Copy characters unchanged until
F2NBUC:	ld	a,(hl)	;we've copied 8 characters
	inc	hl	;or a space is found...
	cp	" "
	jp	z,SPFND
	ld	(de),a
	inc	de
	djnz	F2NBUC
	ld	a,"."
	ld	(de),a
	inc	de
	jp	F2NEXT

SPFND:	ld	a,"."	;...then we add a dot, and skip
	ld	(de),a	;unused character until we found
	inc	de	;the extension.
SFBUC:	ld	a,(hl)
	inc	hl
	djnz	SFBUC
	dec	hl

F2NEXT:	ld	b,3	;Copy extension characters unchanged
F2NEX2:	ld	a,(hl)	;until 3 characters have been copied,
	inc	hl	;or until a space is found.
	cp	" "
	jp	z,F2NEND
	ld	(de),a
	inc	de
	djnz	F2NEX2

F2NEND:	dec	de	;If no extension, supress dot.
	ld	a,(de)
	cp	"."
	jp	z,NOPUN
	inc	de
NOPUN:	xor	a
	ld	(de),a

	ex	de,hl	;Obtains the string length.
	pop	de
	or	a
	sbc	hl,de
	ld	b,l
	jp	ENDCONV

	endif



;-----=========================-----
;-----===== USER ROUTINES =====-----
;-----=========================-----

;--- NAME: DIR
;      Search a file
;      The first execution must be done with A=0
;      To "search next", generic buffer must not be modified
;    INPUT:      DE = File name (may contain wildcards), finished with 0
;                IX = Pointer to a 26 byte buffer
;                B  = Search attributes (ignored under DOS 1)
;                A  = 0 -> Search first
;                A  = 1 -> Search next
;    OUTPUT:     A  = 0 -> A file has been found
;                A <> 0 -> No file found
;                IX+0          -> #FF (used internally by DOS 2)
;                IX+1 to IX+13 -> File name
;                IX+14         -> Attributes byte
;                IX+15 y IX+16 -> File time
;                IX+17 y IX+18 -> File date
;                IX+19 y IX+20 -> Start cluster
;                IX+21 a IX+24 -> File length
;                IX+25         -> Logical drive
;     REGISTERS: F
;     CALLS TO:  CONVNAME, CHKDOS2
;     VARIABLES: BUFFER, DOSENTRY, doscall, _SETDTA, _SFIND, _SNEXT,
;                _FFIND, _FNEXT

OFBUF1:	equ	38

DIR:	if	DOS=12

	call	CHKDOS2
	jp	nc,DIR2

	endif

	;--- DIR: DOS 1 version

	if	DOS<>2

DIR1:	push	bc,de,hl,iy,ix,af
	call	CLBUF
	ex	de,hl
	ld	de,BUFFER	;Convert normal file name from (DE)
	or	a	;to FCB file name in BUFFER.
	call	CONVNAME

	ld	de,BUFFER+OFBUF1	;Set disk transfer area to bufFer,
	doscall	_SETDTA	;after FCB of the file to search.

	ld	de,BUFFER
	pop	af
	and	1
	ld	c,_SFIRST
	add	c
	ld	c,a
	call	DOSENTRY
	or	a	;Finish with A=#FF if not found.
	jp	nz,ENDFF1

	ld	a,(BUFFER+OFBUF1)	;Save FCB drive in ULO1, and set
	ld	(ULO1),a	;it to 0 to convert FCB name to
	xor	a	;normal name without drive letter.
	ld	(BUFFER+OFBUF1),a
	ld	iy,BUFFER+OFBUF1

	push	iy
	pop	hl	;HL = Directory entry of the file
	pop	de	;(starting with drive=0 and name)
	push	de	;DE = User buffer (IX at input)
	ld	a,#FF
	ld	(de),a	;First byte to #FF for DOS 2 compatibility
	inc	de
	scf		;Copy name in normal format to user buffer.
	call	CONVNAME

	pop	ix	;IX = user buffer.
	ld	a,(iy+12)	;Copy attributes byte.
	ld	(ix+14),a

	push	iy
	pop	hl
	ld	bc,23	;HL = Pointer to the time field
	add	hl,bc	;on directory entry.

	push	ix
	pop	de
	ld	bc,15	;DE = Pointer to user buffer+15.
	ex	de,hl
	add	hl,bc
	ex	de,hl

	ld	bc,10	;Copy date, time and start cluster
	ldir		;in one shot.

	ld	a,(ULO1)	;Copy logical drive.
	ld	(ix+25),a

	xor	a	;Successful exit.
	push	ix
ENDFF1:	pop	ix,iy,hl,de,bc
	ret

ULO1:	db	0

	endif

	;--- DIR: DOS 2 version

	if	DOS<>1

DIR2:	push	hl,bc,de,ix
	ld	ix,BUFFER
	ld	c,_FFIRST
	and	1
	add	c
	ld	c,a
	call	DOSENTRY
	or	a
	jp	nz,ENDFF2
	push	ix
	pop	hl
	pop	de
	push	de
	ld	bc,26
	ldir
	xor	a
ENDFF2:	pop	ix,de,bc,hl
	ret

	endif


;--- NAME: REN
;      Rename a file
;    INPUT:     DE = File name
;               HL = New file name (may contain wildcards)
;    OUTPUT:    A  = 0 -> Success
;               A <> 0 -> Error
;    REGISTERS: F
;    CALLS TO:  CHKDOS2, CONVNAME
;    VARIABLES: BUFFER, _FREN, _RENAME, DOSENTRY, doscall

REN:	if	DOS=12

	call	CHKDOS2
	jp	nc,REN2

	endif

	;--- REN: DOS 1 version

	if	DOS<>2

REN1:	push	bc,de,hl,ix,iy
	call	CLBUF

	push	hl
	ex	de,hl	;HL = Old name
	ld	de,BUFFER
	or	a
	call	CONVNAME

	pop	hl	;HL = New name
	ld	de,BUFFER+16
	or	a
	call	CONVNAME
	ld	de,BUFFER

	doscall	_FREN
	pop	iy,ix,hl,de,bc
	ret

	endif

	;--- REN: DOS 2 version

	if	DOS<>1

REN2:	push	hl,de,bc
	doscall	_RENAME
	pop	bc,de,hl
	ret

	endif


;--- NAME: CREATE
;      Creates a file but does NOT open it
;      WARNING! If the file already exists, it is deleted
;               and a new one is created
;    INPUT:     DE = File name
;    OUTPUT:    A  = 0 -> Success
;               A <> 0 -> Error
;    REGISTERS: F
;    CALLS TO:  CONVNAME, CHKDOS2
;    VARIABLES: doscall, _FMAKE, _FCLOSE, _CREATE, _CLOSE, BUFFER

CREATE:	if	DOS=12

	call	CHKDOS2
	jp	nc,CREA2

	endif

	;--- CREATE: DOS 1 version

	if	DOS<>2

CREA1:	push	bc,de,hl,ix,iy
	call	CLBUF
	ex	de,hl	;HL = File name
	ld	de,BUFFER
	or	a
	call	CONVNAME
	ex	de,hl
	ld	de,BUFFER
	push	de
	doscall	_FMAKE	;Creates file and closes it
	pop	de
	or	a
	jp	nz,CR1END
	doscall	_FCLOSE
	xor	a
CR1END:	pop	iy,ix,hl,de,bc
	ret

	endif

	;--- CREATE: DOS 1 version

	if	DOS<>1

CREA2:	push	bc,de,hl
	xor	a
	ld	b,0	;If the file exists, deletes it.
	doscall	_CREATE	;Creates file, and closes it
	or	a	;if no error.
	jp	nz,CR2END
	doscall	_CLOSE
	xor	a
CR2END:	pop	hl,de,bc
	ret

	endif


;--- NAME: DEL
;      Delete a file
;      FILE MUST NOT BE OPEN
;    INPUT:     DE = File name
;    OUTPUT:    A  = 0 -> Success
;               A <> 0 -> Error
;    REGISTERS: F
;    CALLS TO:  CONVNAME, CHKDOS2
;    VARIABLES: doscall, _FDEL, _DELETE, BUFFER

DEL:	if	DOS=12

	call	CHKDOS2
	jp	nc,DEL2

	endif

	;--- DEL: DOS 1 version

	if	DOS<>2

DEL1:	push	bc,de,hl,ix,iy
	call	CLBUF
	ex	de,hl	;HL = File name
	ld	de,BUFFER
	or	a
	call	CONVNAME
	ex	de,hl
	ld	de,BUFFER
	doscall	_FDEL
	pop	iy,ix,hl,de,bc
	ret

	endif

	;--- DEL: DOS 2 version

	if	DOS<>1

DEL2:	push	bc,de,hl
	doscall	_DELETE
	pop	hl,de,bc
	ret

	endif


;--- NAME: OPEN
;      Open a file
;    INPUT:     DE = File name
;    OUTPUT:    A  = 0 -> Success
;               A <> 0 -> Error code
;                         DOS 1: A=1 -> too many open files
;                         DOS 2: See DOS 2 manual for error codes
;               B  = File handle (even in DOS 1!)
;    REGISTERS: F, C
;    CALLS TO:  CHKDOS2, CONVNAME
;    VARIABLES: DOS, doscall, NUMFILES, MAXFILES, _FOPEN, _OPEN, FCBS

OPEN:	if	DOS=12

	call	CHKDOS2
	jp	nc,OPEN2

	endif

	;--- OPEN: DOS 1 version

	if	DOS<>2

OPEN1:	ld	a,(NUMFILES)
	cp	MAXFILES
	ld	a,1
	ret	nc

	push	hl,de,ix,iy
	ld	b,MAXFILES
	ld	hl,FCBS
	push	de
	ld	de,38
OP1BUC1:	ld	a,(hl)	;Search an unused FCB in the
	or	a	;FCBs area.
	jp	z,FCBFND
	add	hl,de
	djnz	OP1BUC1
	ld	a,1
	jp	OP1END

FCBFND:	push	hl	;Clears FCB.
	pop	de
	push	de
	inc	de
	ld	bc,37
	ld	(hl),0
	ldir

	pop	de
	inc	de
	pop	hl	;Copy filename to its FCB
	or	a	;in FCB format.
	call	CONVNAME

	push	de
	doscall	_FOPEN
	pop	ix
	or	a	;Finish if error.
	jp	nz,OP1END

	ld	a,1
	ld	(ix+14),a	;Set "record size" to 1
	xor	a
	ld	(ix+15),a
	ld	(ix+33),a	;Set "random record" to 0
	ld	(ix+34),a
	ld	(ix+35),a
	ld	(ix+36),a

	ld	a,#FF	;Mark FCB as used
	ld	(ix-1),a

	ld	a,(NUMFILES)	;Increase the number of opened
	inc	a	;files and return the FCB index
	ld	(NUMFILES),a	;number in A
	ld	b,a
	xor	a

OP1END:	pop	iy,ix,de,hl
	ret

	endif

	;--- OPEN: DOS 2 version

	if	DOS<>1

OPEN2:	push	hl,de
	xor	a
	doscall	_OPEN
	or	a
	jp	nz,OP2END
	ld	a,(NUMFILES)
	inc	a
	ld	(NUMFILES),a
	xor	a
OP2END:	pop	de,hl
	ret

	endif


;--- NAME: CLOSE
;      Close a file
;    INPUT:     B  = File handle
;    OUTPUT:    A  = 0 -> Success
;               A <> 0 -> Error
;                         DOS 1: A=2 -> File not open
;                         DOS 2: See DOS 2 manual for error codes
;    REGISTERS: F
;    CALLS TO:  CHKDOS2
;    VARIABLES: BUFFER, FCBS, doscall, DOS, MAXFILES, NUMFILES, _FCLOSE, _CLOSE

CLOSE:	if	DOS=12

	call	CHKDOS2
	jp	nc,CLOSE2

	endif

	;--- CLOSE: DOS 1 version

	if	DOS<>2

CLOSE1:	ld	a,b	;Error if B>MAXFILES
	cp	MAXFILES+1	;or B=0.
	ld	a,2
	ret	nc
	ld	a,b
	or	a
	ld	a,2
	ret	z

	push	bc,de,hl,ix,iy
	ld	hl,FCBS
	ld	de,38
	or	a
	sbc	hl,de
CL1BUC1:	add	hl,de	;HL = Ponter to file FCB
	djnz	CL1BUC1

	ld	a,(hl)	;Error if file is not open
	or	a
	ld	a,2
	jp	z,ENDCL1

	inc	hl
	ex	de,hl	;DE = FCB del fichero
	push	de
	doscall	_FCLOSE
	pop	ix
	or	a
	jp	nz,ENDCL1

	ld	a,(NUMFILES)
	dec	a
	ld	(NUMFILES),a
	xor	a	;Mark FCB as unused
	ld	(ix-1),a

ENDCL1:	pop	iy,ix,hl,de,bc
	ret

	endif

	;--- CLOSE: Version DOS 2

	if	DOS<>1

CLOSE2:	push	bc,de,hl
	doscall	_CLOSE
	or	a
	jp	nz,ENDCL2
	ld	a,(NUMFILES)
	dec	a
	ld	(NUMFILES),a
	xor	a
ENDCL2:	pop	hl,de,bc
	ret

	endif


;--- NAME: READ
;      Read from file
;    INPUT:     B  = File handle
;               DE = Buffer address to read to
;               HL = Number of bytes to read
;    OUTPUT:    A  = 0 -> Success
;               A <> 0 -> Error code
;                         A partial read (the end of file has been reached
;                         before all the desired bytes have been read, that is,
;                         HL at input <> HL at output) is considered
;                         an error, and will return an error code of 1
;                         both in DOS 1 and in DOS 2.
;                         DOS 1: A=2 -> File not open
;                         DOS 2: See DOS 2 manual for error codes
;               HL = Number of bytes actually read
;    REGISTERS: F
;    CALLS TO:  CHKDOS2, RW1, RW2
;    VARIABLES: BUFFER, FCBS, DOESNTRY, DOS, MAXFILES, NUMFILES, _RDBLK,
;               _READ, _SETDTA, RWCODE

READ:	if	DOS=12

	call	CHKDOS2
	jp	nc,READ2

	endif

	;--- READ: DOS 1 version

	if	DOS<>2

READ1:	ld	a,_RDBLK
	ld	(RWCODE),a
	jp	RW1

	endif

	;--- READ: DOS 2 version

	if	DOS<>1

READ2:	ld	a,_READ
	ld	(RWCODE),a
	jp	RW2

	endif


;--- NAME: WRITE
;      Write to file
;    INPUT:     B  = File handle
;               DE = Buffer to write from
;               HL = Number of bytes to erite
;    OUTPUT:    A  = 0 -> Success
;               A <> 0 -> Error code
;                         A partial write (that is, HL at input <> HL
;                         at output) is considered an error, and will
;                         return an error code of 1 both in DOS 1
;                         and in DOS 2.
;                         DOS 1: A=2 -> File not open
;                         DOS 2: See DOS 2 manual for error codes
;               HL = Number of bytes actually wrote
;    REGISTERS: F
;    CALLS TO:  CHKDOS2, RW1, RW2
;    VARIABLES: BUFFER, FCBS, DOSENTRY, DOS, MAXFILES, NUMFILES, _WRBLK,
;               _WRITE, _SETDTA, RWCODE

WRITE:	if	DOS=12

	call	CHKDOS2
	jp	nc,WRITE2

	endif

	;--- WRITE: DOS 1 version

	if	DOS<>2

WRITE1:	ld	a,_WRBLK
	ld	(RWCODE),a
	jp	RW1

	endif

	;--- WRITE: DOS 2 version

	if	DOS<>1

WRITE2:	ld	a,_WRITE
	ld	(RWCODE),a
	jp	RW2

	endif


;--- RW: Common code for reading and writing

	;--- RW: DOS 1 version

	if	DOS<>2

RW1:	ld	a,b
	cp	MAXFILES+1
	ld	a,1
	ret	nc
	ld	a,b
	or	a
	ld	a,2
	ret	z

	push	bc,de,ix,iy
	push	hl,de
	ld	hl,FCBS
	ld	de,38
	or	a
	sbc	hl,de
RW1BUC1:	add	hl,de	;HL = Pointer to file FCB
	djnz	RW1BUC1
	ld	a,(hl)	;A = FCB in use flag
	ex	(sp),hl
	push	hl

	or	a	;Error if file is not open
	ld	a,2	;(FCB not used)
	jp	z,ENDRW11

	pop	de
	doscall	_SETDTA
	pop	de,hl
	inc	de
	ld	a,(RWCODE)	;Execute read or write DOS call
	ld	c,a
	call	DOSENTRY

ENDRW1:	pop	iy,ix,de,bc
	ret
ENDRW11:	pop	bc,bc,bc
	jp	ENDRW1

	endif

	;--- RW: DOS 2 version

	if	DOS<>1

RW2:	push	bc,de,hl
	ld	a,(RWCODE)	;Execute read or write DOS call
	ld	c,a
	call	DOSENTRY
	pop	de
	or	a
	jp	nz,ENDRW2
	push	hl

	sbc	hl,de	;HL = read bytes, DE = required bytes
	ld	a,h	;If HL=DE, no error
	or	l	;If HL<>DE, error 1
	ld	a,0
	pop	hl
	jp	z,ENDRW2
	ld	a,1

ENDRW2:	pop	de,bc
	ret

	endif

RWCODE:	db	0	;DOS function to call


;--- NAME: SEEK
;      Move file pointer
;      First position is 0
;    INPUT:     B  = File handle
;               A  = Method:
;                    A = 0 -> Relative to the beginning of the file
;                    A = 1 -> Relative to the current position
;                    A = 2 -> Relative to the end of the file
;               DE:HL  = Signed offset (twos complement)
;    OUTPUT:    A  = 0 -> Success
;               A <> 0 -> Error code
;                         DOS 1: A=2 -> File not open
;                                A=3 -> Unknown method
;                         DOS 2: See DOS 2 manual for error codes
;               DE:HL  = New pointer
;    * To obtain current pointer without modify it,
;      execute with A = 1 and DE:HL=0.
;    * To obtain the file length,
;      execute with A = 2 and DE:HL=0.
;    REGISTERS:  F
;    CALLS TO:   CHKDOS2
;    VARIABLES:  MAXFILES, NUMFILES, doscall, _SEEK, BUFFER

SEEK:	if	DOS=12

	ld	(BUFFER),a
	call	CHKDOS2
	ld	a,(BUFFER)
	jp	nc,SEEK2

	endif

	;--- SEEK: DOS 1 version

	if	DOS<>2

SEEK1:	ld	(BUFFER),a
	ld	a,b	;Error if B>MAXFILES
	cp	MAXFILES+1	;or B=0.
	ld	a,2
	ret	nc
	ld	a,b
	or	a
	ld	a,2
	ret	z

	push	bc,ix,iy
	push	de,hl
	ld	hl,FCBS
	ld	de,38
	or	a
	sbc	hl,de
SK1BUC1:	add	hl,de	;HL = Pointer to file FCB
	djnz	SK1BUC1

	ld	a,(hl)	;Error if file is not open
	or	a	;(FCB not used)
	ld	a,2
	jp	z,ENDSK11

	push	hl
	pop	ix
	inc	ix	;IX = Pointer to file FCB

	ld	a,(BUFFER)
	or	a	;Obtain method and finish with error
	jp	z,METODO0	;if >2
	cp	1
	jp	z,METODO1
	cp	2
	jp	z,METODO2
	ld	a,3
	jp	ENDSK11

METODO0:	ld	de,0
	ld	hl,0
	jp	OKMETOD	;DE:HL = 0

METODO1:	ld	l,(ix+33)
	ld	h,(ix+34)
	ld	e,(ix+35)
	ld	d,(ix+36)	;DE:HL = Current pointer
	jp	OKMETOD

METODO2:	ld	l,(ix+16)
	ld	h,(ix+17)
	ld	e,(ix+18)
	ld	d,(ix+19)	;DE:HL = File length

OKMETOD:	pop	bc
	add	hl,bc
	pop	bc
	ex	de,hl
	adc	hl,bc	;DE:HL = New pointer
	ex	de,hl
	xor	a

	ld	(ix+33),l	;Update pointer
	ld	(ix+34),h
	ld	(ix+35),e
	ld	(ix+36),d

ENDSK1:	pop	iy,ix,bc
	ret
ENDSK11:	pop	bc,bc
	jp	ENDSK1

	endif

	;--- SEEK: DOS 2 version

	if	DOS<>1

SEEK2:	push	bc
	doscall	_SEEK
	pop	bc
	ret

	endif
