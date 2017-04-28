;Filesystem driver infrastructure AKA NestorFilesystem
;By Konamiman, 5-2017

;This is the skeleton of a resident program that installs
;in page 3 + one RAM segment and uses the H_BDOS (#F252) hook
;to intercept the file access related MSX-DOS function calls.
;This allows to develop a custom filesystem driver, that is,
;a program that supplies custom implementations for
;file search/open/read/write/create/rename/delete functions.
;
;Search TODO: comments for instructions on how to convert
;this skeleton into a working implementation for your
;device/hardware.
;
;This is a very early version that:
;- Installs the driver on drive G: always
;- Doesn't allow installing more than one driver
;- Implements the file search and current directory functions only
;
;Assemble with Compass or with Sjasm v0.39h
;(https://github.com/Konamiman/Sjasm/releases/tag/v0.39h)
;
;Works on MSX-DOS 2 and Nextor.


;***************************************
;---  BEGIN of macros and constants  ---
;***************************************

IDNES:	equ	22h	;ID for extended BIOS
IDNFS:	equ	4

;Min and max function calls that will be hooked,
;apart from some that will be treated as special cases

MINFN: equ 40h	;_FFIRST
MAXFN: equ 5Ah	;_CHDIR

MAX_PATH_LEN: equ 63

SLASH: equ 5Ch

dos:	macro
	call	5
	endm
	
;*** Hooks and system variables

ENDTPA:	equ	#0006
HIGHMEM:	equ	#F349
EXTBIO:	equ	#FFCA
CALSLT:	equ	#001C
ENASLT:	equ	#0024
EXPTBL:	equ	#FCC1
CUR_DRV:	equ	#F23C

H_BDOS: equ #F252

;*** MSX-DOS functions

_STROUT:	equ	09h
_SELDSK:	equ	0EH
_LOGIN:		equ	18h
_ALLOC:		equ	1Bh
_CURDRV:	equ	19h
_FFIRST:    equ	40h
_FNEXT:     equ	41h
_GETCD:		equ	59h
_CHDIR:		equ	5Ah
_WPATH:		equ	5Eh
_TERM:	equ	62h
_DOSVER:	equ	6Fh

;*** MSX-DOS error codes

__IATTR:    equ 0CFh
__NODIR: equ 0D6h
__NOFIL:	equ 0D7h
__PLONG:	equ 0D8h
__IPATH:	equ	0D9h
__DISK:	equ 0FDh
__IFORM:	equ 0F0h	;Used for testing

;*************************************
;---  END of macros and constants  ---
;*************************************


;****************************
;---  BEGIN of installer  ---
;****************************

	org	#100

	ld	de,PRESENT_s
	ld	c,_STROUT
	dos

;--- Check if DOS 2 or Nextor

	ld	c,_DOSVER
	dos
	ld	a,b
	cp	2
	jr	nc,OKDOS2

NODOS2:	ld	de,NOD2STR
	ld	c,_STROUT
	dos
	ret
NOD2STR:	db	13,10,"*** MSX-DOS 2 required",13,10,"$"
OKDOS2:	;

;--- Check for enough TPA ((#0006) >= #C200)

	ld	a,(ENDTPA+1)
	cp	#C2
	jr	nc,OKTPA

	ld	de,NOTPAS
	ld	c,_STROUT
	dos
	jp	FIN
NOTPAS:	db	13,10,"*** TPA is too small (end of TPA must be at least #C200).",13,10,"$"
OKTPA:	;


;--- Get mapper support routines

	ld	de,#0402
	call	EXTBIO
	ld	a,b	;also set mapper slot for page 3 code
	and	%10001111
	ld	(RESCODE1+11),a
	ld	(RESCODE2+11),a
	ld	de,ALL_SEG
	ld	bc,#30
	ldir

;--- Check if already installed, if so and parameter is U, go to uninstall

	ld	de,IDNFS+256*IDNES
	call	EXTBIO
	cp	IDNES
	jp	z,DESINST

;--- TODO: check if the required hardware/device is present
;    and abort install if not, e.g.

	;call	CHECK_DEVICE
	;jr	nc,OKDEVICE
	;ld	de,NODEVICE
	;ld	c,_STROUT
	;dos
	;jp	FIN
	
;NODEVICE:	db	"*** Device not found!",13,10,"$"	
	
OKDEVICE:
	
;--- So let's install: start by allocating a RAM segment

	ld	b,0
	ld	a,1
	call	ALL_SEG
	jp	nc,OKRESEG
	ld	de,NOFSTR
	ld	c,_STROUT
	dos

FIN:	ld	b,0
	ld	c,_TERM
	dos
	ret

NOFSTR:	db	13,10,"*** No free RAM segments on primary mapper.",13,10,"$"

OKRESEG:	ld	(RESCODE1+12),a
	ld	(RESCODE2+12),a

;--- Backup existing hooks into page 3 code

	di

	ld	hl,H_BDOS
	ld	de,RESCODE1+8
	ld	bc,3
	ldir

	ld	hl,H_BDOS
	ld	de,RESCODE2+8
	ld	bc,3
	ldir

	ld	hl,EXTBIO
	ld	de,RESCODE1+3
	ld	bc,5
	ldir

	ld	hl,EXTBIO
	ld	de,RESCODE2+3
	ld	bc,5
	ldir

;--- Allocate page 3 space and copy page 3 code

	ld	hl,(HIGHMEM)
	ld	(RESCODE1+21),hl
	ld	(RESCODE2+21),hl
	ld	bc,RESCODE2-RESCODE1
	or	a
	sbc	hl,bc
	ld	(HIGHMEM),hl
	ld	(RESCODE1+19),hl
	ld	(RESCODE2+19),hl

	ld	hl,PUT_P1	;PUT_P1 + GET_P1
	push	hl
	ld	de,RESCODE1+13
	ld	bc,6
	ldir
	pop	hl
	ld	de,RESCODE2+13
	ld	bc,6
	ldir

	ld	hl,RESCODE1
	ld	de,RESCODE2
	ld	ix,(RESCODE1+19)
	ld	bc,RESCODE2-RESCODE1
	call	REUBICA

;--- Copy segment code into the allocated segment

	call	GET_P1
	push	af
	ld	a,(RESCODE1+12)
	call	PUT_P1
	ld	hl,PARTRE2
	ld	de,#4000
	ld	bc,PARTRE2!-#4000
	ldir

	pop	af
	call	PUT_P1

;--- Set the new hooks

	di

	ld	hl,(HIGHMEM)
	ld	de,EXTBIO
	ld	bc,5
	ldir

	ld	bc,23-5
	add	hl,bc
	ld	a,0C3h
	ld	(H_BDOS),a
	ld	(H_BDOS+1),hl
	
;--- Install done, do a BASIC + CALL SYSTEM

	ei

	ld	de,INSSTR
	ld	c,_STROUT
	dos
	ld	hl,#0081
	jp	CALSYS

INSSTR:	
	db	"Installed. Have fun!",13,10,"$"

;--- Uninstall if parameter is "U"

DESINST:	ld	hl,#0081
SRCH_U:	ld	a,(hl)
	inc	hl
	cp	32	;Skip spaces
	jr   z,	SRCH_U
	or	a
	jr	nz,CHKU

NODES:
	ld	de,YAINSTR	;0 found: no parameters
	ld	c,_STROUT
	dos
	jp	FIN

YAINSTR:	db	"*** Already installed. Run with U to uninstall.",13,10,"$"

CHKU:	and	%11011111	;If something is found, it must be U
	cp	"U"
	jr	nz,NODES
	ld	(POS2COM),hl	;Save position after "U"

	ld	de,IDNFS+IDNES*256	;Check if current HIGHMEM is the same
	call	EXTBIO	;as HIGHMEM when we were installed,
	ld	de,(HIGHMEM)	;otherwise uninstall is not possible.
	or	a
	sbc	hl,de
	ld	a,h
	or	l
	jp	z,OKHMEM

	ld	de,NOKHMEMS
	ld	c,_STROUT
	dos
	jp	FIN

NOKHMEMS:	db	"*** Other resident program was installed after I was.",13,10
	db	"Please remove it and try again.",13,10,"$"

OKHMEM:	push	ix
	ld	a,c
	call	FRE_SEG

	ld	hl,(HIGHMEM)
	ld	bc,3
	add	hl,bc
	di

	ld	de,EXTBIO
	ld	bc,5
	ldir
	ld	de,H_BDOS
	ld	bc,3
	ldir

	pop	ix
	ld	(HIGHMEM),ix

	ld	de,DESSTR
	ld	c,_STROUT
	dos
	ld	hl,(POS2COM)
	jp	CALSYS

DESSTR:	db	"Uninstalled, please come back!",13,10,"$"
POS2COM:	dw	0

RESTHOOK:	ldir
	ld	bc,5
	ret

	
;--- Code reallocation routine
;    Input: HL = First copy of code
;           DE = Second copy of code
;           IX = Destination address
;           BC = Code length

REUBICA:	push	bc,de,hl	;First copy code unchanged
	push	ix	;(HL->IX, length BC)
	pop	de
	ldir
	pop	hl,de

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

	;In this point: IX = Destination
	;               IY = Second copy
	;               BC = Distance to sum (new address - the copy)
	;               BC'= Length

BUCLE:	ld	a,(ix)
	cp	(iy)
	jr	z,NEXT	;If no differences go to next byte

	ld	l,a
	ld	h,(ix+1)	;HL = Data to change
	add	hl,bc	;HL = Changed data
	ld	(ix),l	;IX = Address of data to change
	ld	(ix+1),h

	call	CHKCOMP
	jr	z,FINREUB

	inc	ix
	inc	iy
NEXT:	inc	ix	;Next byte to compare
	inc	iy	;(if we have replaced, we need to increment by 2)
	call	CHKCOMP
	jr	nz,BUCLE

FINREUB	ret

CHKCOMP:	exx
	dec	bc	;Decrement counter, and if 0
	ld	a,b	;return with Z=1
	or	c
	exx
	ret
	

;--- BASIC + CALL SYSTEM
;    Input: HL = command to be executed after CALL SYSTEM

CALSYS:	ld	ix,SysCom

BUCSYSCOM:	ld	a,(hl)	;Search first character or terminating 0
	inc	hl
	or	a
	jr	z,OKBSC
	cp	" "
	jr	z,BUCSYSCOM
	dec	hl

BUCSYS2:	ld	(ix),a	;Copy characters until we find 0
	inc	ix
	inc	hl
	ld	a,(hl)
	cp	"&"
	jr	nz,NOANGLUNO
	ld	a,"^"
NOANGLUNO:	or	a
	jr	nz,BUCSYS2

	ld	(ix),34
	ld	(ix+1),")"
	ld	(ix+2),0
OKBSC:

	;Do the CALL SYSTEM

	ld	hl,SystemProg
	ld	de,08000h
	ld	bc,0200h
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
	ld	hl,08030h
	jp	04601h

SysTxT:	defb	03Ah,0CAh
	defb	"SYSTEM(",34
SysCom:	db	34,")"
	defb	0,01Ah

	
;--- Mapper support routines

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
PUT_P1:	ds	3
GET_P1:	ds	3
PUT_P2:	ds	3
GET_P2:	ds	3
PUT_P3:	ds	3
GET_P3:	ds	3


;--- Strings

;TODO: Put your thing name here and get some credit!

PRESENT_s:
	db	"Filesystem driver for (YOUR HARDWARE/DEVICE HERE) 1.0",13,10
	db	"By (YOUR NAME HERE) and Konamiman, 5/2017",13,10
	db	13,10
	db	"$"

TEMP:	ds	5


;**************************
;---  END of installer  ---
;**************************


;******************************
;---  BEGIN of page 3 code  ---
;******************************

PARTRES:	macro

INIRES@sym:
NEWBIO@sym:	jp	_NEWBIO@sym	;+0
OLDBIO@sym:	ds	5			;+3
OLDHBDOS@sym:	ds 3		;+8
RESLOT@sym:	db	0			;+11
RESEG@sym:	db	0			;+12
PUT_P1@sym:	jp	#0000		;+13
GET_P1@sym:	jp	#0000		;+16
NEWHM@sym:	dw	0			;+19
OLDHM@sym:	dw	0			;+21

;--- New H_BDOS hook

_NEWBDOS@sym:	;+23
	ex	af,af
	ld	a,c
	cp	_LOGIN
	jr	nz,NOLOGIN@sym
	
	pop	hl
	ld	de,NEXTLOGIN@sym
	push	de
	jp	(hl)
	
NEXTLOGIN@sym:
	set	6,l	;WARNING: This depends on drive letter!
	ret
	
NOLOGIN@sym:
	push  iy

	ld	a,c
	cp	_SELDSK
	jr	z,OKGO@sym
	;cp	_CURDRV
	;jr	z,OKGO@sym
	cp	_ALLOC
	jr	z,OKGO@sym
	cp	_WPATH
	jr	z,OKGO@sym
	cp	MINFN
	jr	c,POPEXRET@sym

	cp	MAXFN+1
	jr	c,OKGO@sym

POPEXRET@sym:
	ex	af,af
	jr	POPRET@sym

OKGO@sym:
	call	GETSLOT1@sym
	push	af
	call	GET_P1@sym
	push	af
	ex	af,af
	push	af,bc,de,hl,ix
	ld	a,(RESLOT@sym)
	ld	h,#40
	call	ENASLT
	ld	a,(RESEG@sym)
	call	PUT_P1@sym
	pop	ix,hl,de,bc,af

	call	DOSENTRY

	ex	af,af
	ld	a,iyl
	or	a
	jp nz,PROCESSED@sym
ENDPROC@sym:
	pop	af
	call	PUT_P1@sym
	ex af,af
	pop	iy
	push	af,bc,de,hl,ix
	ld	a,iyh
	ld	h,#40
	call	ENASLT
	pop	ix,hl,de,bc,af

POPRET@sym:
	pop	iy
	ei
	jp	OLDHBDOS@sym

PROCESSED@sym:
	exx
	pop	de	;segment
	pop	bc	;slot
	pop	hl	;original iy
	pop	iy	;ret from hook

	inc	iy	;skip CALL KBDOS in DOS code
	inc	iy
	inc	iy

	push iy,hl,bc,de
	exx
	jp	ENDPROC@sym


;--- New EXTBIO hook
;    Input:   D = IDNES
;             E = IDNFS
;    Output:  HL= New HIGHMEM
;             IX= Old HIGHMEM
;             B = Slot of allocated segment
;             C = Allocated segment number
;             A = IDNES
;    Modifiess: IX, IY, alternate regs

_NEWBIO@sym:	push	af
	ld	a,d
	cp	IDNES
	jr	nz,NOBIOS@sym
	ld	a,e
	cp	IDNFS
	jr	z,OKBIOS@sym
NOBIOS@sym:	pop	af
	jp	OLDBIO@sym

OKBIOS@sym:	pop	af
	ld	hl,(NEWHM@sym)
	ld	ix,(OLDHM@sym)
	ld	a,(RESLOT@sym)
	ld	b,a
	ld	a,(RESEG@sym)
	ld	c,a
	ld	a,IDNES
	ret

	
;--- Get slot in page 1

GETSLOT1@sym:
	exx
	in	a,(#A8)
	ld	e,a
	and	%00001100
	sra	a
	sra	a
	ld	c,a	;C = Slot
	ld	b,0
	ld	hl,EXPTBL
	add	hl,bc
	bit	7,(hl)
	jr	z,NOEXP@sym
EXP@sym:	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	and	%00001100
	or	c
	or	#80
	ld	c,a
NOEXP@sym:	ld	a,c
	exx
	ret

ENDRES@sym:
	endm

RESCODE1:	PARTRES
RESCODE2:	PARTRES


;******************************
;---  END of page 3 code  ---
;******************************


;*******************************
;---  BEGIN of segment code  ---
;*******************************

PARTRE2:	org	#4000


;---------------------------------------------------------------
;>>>>>>>  HEADER - do NOT change as emulators hook here  <<<<<<<
;---------------------------------------------------------------

	db	"FileSysDriver",0
	db 0,1	;Specification version complied, main+sec

	ds 16
	
JMP_ALLOC:	jp	IMPL_ALLOC
JMP_FFIRST:	jp	IMPL_FFIRST
JMP_FNEXT:	jp	IMPL_FNEXT
JMP_CHDIR:	jp	IMPL_CHDIR
JMP_GETCD:  jp  IMPL_GETCD
JMP_GETVOL: jp  IMPL_GETVOL


;----------------------------------
;>>>>>>>  H_BDOS hook code  <<<<<<<
;----------------------------------
	
DOSENTRY:
	ld iy,DOESNTRY_END
	push iy
	ex	af,af
	ld	a,c

	cp	_SELDSK
	jp	z,DO_SELDSK
	;cp	_CURDRV
	;jp	z,DO_CURDRV
	cp	_ALLOC
	jp	z,DO_ALLOC
	cp	_FFIRST
	jp	z,DO_FFIRST
	cp	_FNEXT
	jp	z,DO_FNEXT
	cp	_GETCD
	jp	z,DO_GETCD
	cp	_CHDIR
	jp  z,DO_CHDIR
	cp  _WPATH
	jp  z,DO_WPATH

	pop iy
DONOTHING:	;Non-hooked function: do nothing
	ld	iy,0
EX_AND_RET:
	ex	af,af
	ret
	
DOESNTRY_END:
	ex af,af
	ld a,iyl
	or a
	jr z,EX_AND_RET

	;In case of disk error (A >= F0h), clear caches

	ex af,af
	exx
	ld d,a
	and 0F0h
	cp 0F0h
	ld a,d
	exx
	ret nz

	ex af,af
	xor a
	ld (CURDIR_IS_CACHED),a
	ld (VOLABEL_IS_CACHED),a
	ex af,af
	ret

	
;-------------------------------------------
;>>>>>>>  DOS function replacements  <<<<<<<
;-------------------------------------------

;These are executed INSTEAD OF the original DOS functions implementations.
;Input/output is similar, but not always identical, to the public API
;(DOS does some processing before calling the hook).

;Code in this section is device/hardware independent,
;so you do NOT need to change it.
	
;They all return IY=0 if the function was not processed
;(so DOS needs to handle it) or IY=1 if the function
;was processed (so DOS must skip it).


;--- SELECT DISK (0EH)
;    Parameters:    C = 0EH (_SELDSK)
;                   E = Drive number.  0=A: 1=B:   etc.
;    Results:       A = Error code
;                   L = Number of drives (1...8)

DO_SELDSK:
	ex	af,af
	ld	a,e
	and	%11111000
	ld	iy,0
	ret	nz	;Bad drive number

	ld	a,(INDRIVE0)	;Setting my drive as current?
	cp	e
	jr	z,SELDSK_ISMINE

	xor	a
	ld	(CUR_IS_MINE),a	;No: CUR_IS_MINE=false and let DOS handle it
	ret

SELDSK_ISMINE:
	ld	a,e
	inc	a
	ld	(CUR_DRV),a
	ld	a,0FFh
	ld	(CUR_IS_MINE),a	;Yes: CUR_IS_MINE=false and DON'T let DOS handle it
	inc	iy				;(since that could cause "Invalid drive" error)
	ld	hl,(0F347h)
	xor	a
	ld	h,a
	ret
		

;--- GET CURRENT DRIVE (19H)
;    Parameters:    C = 19H (_CURDRV)
;    Results:       A = Error code
;                   L = Current drive (0=A: etc)

DO_CURDRV:
	ex	af,af
	ld	a,(CUR_IS_MINE)
	ld	iy,0
	or	a
	ret	z

	ld	hl,(INDRIVE0)
	xor	a
	ld	l,a
	inc	iy
	ret


;--- GET ALLOCATION INFORMATION (1BH)
;    Parameters:    C = 1BH (_ALLOC)
;                   E = drive number (0=default)
;    Results:       A = Error code
;                   C = Sectors/cluster (0FFh if any error)
;                   DE = Total number of clusters
;                   HL = Number of free clusters
;                   IX = Pointer to MSX-DOS 1.0 compatible DPB (NO!)
;                   IY = Pointer to first FAT sector in a page-3 buffer (NO!)

DO_ALLOC:
	ex	af,af
	ld	a,e
	call	ISMYDRIVE
	ld	iy,0
	ret	nz

	call JMP_ALLOC
	ld	iy,1
	ret


;--- FIND FIRST ENTRY (40H)
;    Parameters:   C = 40H (_FFIRST) 
;                 DE = Drive/path/file ASCIIZ string
;                      or fileinfo block pointer
;                 HL = filename ASCIIZ string (only if
;                 DE = fileinfo pointer)
;                 B = Search attributes
;                 IX = Pointer to new fileinfo block
;    Results:      A = Error
;               (IX) = Filled in with matching entry

DO_FFIRST:
	ex	af,af
	xor a
	ld (FIND_STAT),a	;Assume not for me, or error, to start with
	
	ld	a,(de)
	cp	0FFh
	jr	z,FFIRST_FIB
	
	;--- Path/file based search, DE points past the drive if any
	
	push hl
	call DRV_IN_PATH_MINE
	pop hl
	ld	iy,0
	ret	nz
	
	bit 3,b
	jp nz,FFIRST_GETVOL
	
FFIRST_PATH:
	ld hl,FFIRST_BUF
	push de,bc,ix
	call PROCESS
	pop ix,bc,de
	or a
	ret nz
	
	push de
	ld hl,FFIRST_BUF
	ld de,WPATH_BUF
	ld bc,MAX_PATH_LEN+1
	ldir
	pop de
	ld iy,FFIRST_BUF
	push ix
	call	JMP_FFIRST
	pop ix
	ld iy,1
	or a
	jr z,FFIRST_PATH_OK
	
	cp __PLONG
	ret nz
	ld b,a
	ld a,2
	ld (FIND_STAT),a
	ld a,b
	ret
	
FFIRST_PATH_OK:	
	jr FFIRST_END
	
	;--- FIB based search
	
FFIRST_FIB:
	push	de
	pop	iy
	ld	a,(INDRIVE1)
	cp	(iy+25)
	ld a,(iy+14)
	ld	iy,0
	ret	nz
	
	ld c,a
	bit 4,c	;FIB must specify a directory
	ld a,__IATTR
	ret z
	bit 3,c	;FIB can't specify a volume name
	ret nz

	push de,hl
	ld hl,WPATH_BUF
	ld bc,(WPATH_LEN)
	add hl,bc
	ld (hl),SLASH
	inc hl
	ex de,hl ;HL = filename, DE = end of WPATH

	pop hl
	ld a,(hl)
	or a
	jr nz,FFIRST_NOEMP
	ld hl,AST_DOT_AST
FFIRST_NOEMP:	
	push hl
	ld bc,13
	ldir	;append filename to WPATH
	pop hl,de
	
	push ix
	ld iy,WPATH_BUF
	call	JMP_FFIRST
	pop ix
	ld	iy,1
	or a
	ret nz
	
	;--- Common wrapup
	
FFIRST_END:	
	ld d,a
	ld de,WPATH_BUF
	call STRLEN
	ld a,__PLONG
	ret c
	ld a,d
	ld (WPATH_LEN),bc
	
	ld de,WPATH_BUF
	call GLAST
	ld de,WPATH_BUF
	or a
	sbc hl,de
	ld (WPATH_PATH_LEN),hl

FFIRST_END2:	
	ld	a,(INDRIVE1)
	ld (ix+25),a
	ld a,1
	ld (FIND_STAT),a
	dec a
	ld (ix),0FFh
	ld (ix+19),a	;start cluster
	ld (ix+20),a
	ld (ix+26),a	;entry index
	ld (ix+27),a	;entry index
	ret
	
	;--- Get volume label
	
FFIRST_GETVOL:
	push ix
	pop de
	inc de	;DE=destination

	ld a,(VOLABEL_IS_CACHED)
	or a
	jr z,FFIRST_GETVOL2
	
	ld hl,VOLABEL_CACHE
	ld bc,11
	ldir
	or a
	jr FFIRST_GETVOL3
	
FFIRST_GETVOL2:	
	push de,ix
	call JMP_GETVOL
	pop ix,de
	jr c,FFIRST_CACHEVOL
	or a
	ld iy,1
	ret nz
	jr FFIRST_GETVOL3
	
FFIRST_CACHEVOL:	
	ex de,hl
	ld de,VOLABEL_CACHE
	ld bc,11
	ldir
	ld a,0FFh
	ld (VOLABEL_IS_CACHED),a

FFIRST_GETVOL3:	
	ld (ix),0xFF
	ld	a,(INDRIVE1)
	ld (ix+25),a
	ld (ix+14),%1000 ;Volume label attribute

	xor a
	ld iy,1
	ret
	
FFIRST_BUF: ds MAX_PATH_LEN + 1


;--- FIND NEXT ENTRY (41H)
;    Parameters:    C = 41H (_FNEXT) 
;                  IX = Pointer to fileinfo block from
;                       previous find first function.
;    Results:       A = Error
;                (IX) = Filled in with next matching entry

DO_FNEXT:
	ld	a,(INDRIVE1)
	cp	(ix+25)
	ld	iy,0
	ret	nz

	push ix
	call	JMP_FNEXT
	pop ix
	ld	iy,1
	or a
	ret nz
	
	ld l,(ix+26)
	ld h,(ix+27)
	inc hl
	ld (ix+26),l
	ld (ix+27),h
	ret
			

;--- GET CURRENT DIRECTORY (59H)
;    Parameters:    C = 59H (_GETCD) 
;                   B = Drive number (0=current, 1=A: etc)
;                  DE = Pointer to 64 byte buffer
;    Results:       A = Error
;                  DE = Filled in with current path
;                  BC = Length of string in DE

DO_GETCD:
	ex	af,af
	ld	a,b
	call  ISMYDRIVE
	ld	iy,0
	ret	nz
	
DO_GETCD2:
	ld a,(CURDIR_IS_CACHED)
	or a
	jr z,GETCD_NOT_CACHED

	inc iy
	push de
	ld hl,CURDIR
	ld bc,(CURDIR_LEN)
	push bc
	call DO_LDIR
	pop bc
	pop de
	xor a
	ret
	
GETCD_NOT_CACHED:
	push de
	call JMP_GETCD
	pop de
	ld iy,1
	jr c,GETCD_CAN_CACHE
	
	or a
	ret nz
	push de
	call STRLEN
	pop de
	xor a
	ret
	
GETCD_CAN_CACHE:
	push de
	ld h,d
	ld l,e
	ld de,CURDIR
	ld bc,MAX_PATH_LEN+1
	ldir
	
	ld de,CURDIR
	call STRLEN
	ld (CURDIR_LEN),bc
	
	pop de
	ld a,0FFh
	ld (CURDIR_IS_CACHED),a
	cpl
	ret

	
;--- CHANGE CURRENT DIRECTORY (5AH)
;    Parameters:    C = 5AH (_CHDIR) 
;                  DE = Drive/path/file ASCIIZ string
;    Results:       A = Error

DO_CHDIR:
	ex	af,af
	
	call DRV_IN_PATH_MINE
	ld	iy,0
	ret	nz

	ld hl,CHDIR_BUF
	push de
	call PROCESS
	pop de
	ld iy,1
	or a
	ret nz
	
	;If dir ends with \ or \., suppress it
	push de
	ld de,CHDIR_BUF
	call STRLEN
	pop de
	ld ix,CHDIR_BUF
	add ix,bc
	dec ix	;IX points before terminator
	
	ld a,(ix)
	cp 0FFh
	jr z,DO_CHDIR_OK	;Is empty string
	cp "."
	jr nz,DO_CHDIR_NODOT
	ld a,(ix-1)
	cp 0FFh
	ld h,a
	ld a,__NODIR	;"." alone is illegal
	ret z
	ld a,h
	cp SLASH
	jr nz,DO_CHDIR_NODOT
	
	ld (ix),0	;Suppress terminating dot
	dec ix
	ld a,(ix)
DO_CHDIR_NODOT:
	cp SLASH
	jr nz,DO_CHDIR_OK
	ld (ix),0	;Suppress terminating slash
	
	;End of \ or \. processing
	
DO_CHDIR_OK:
CHDIR_DOCACHE:	
	ld a,(CURDIR_IS_CACHED)
	rra
	ld ix,CURDIR
	ld hl,CHDIR_BUF
	call JMP_CHDIR
	ex af,af
	xor a
	ld (CURDIR_IS_CACHED),a
	ex af,af
	ld iy,1
	ret
	
	db 0FFh
CHDIR_BUF: ds MAX_PATH_LEN+1	
	
	
;--- GET WHOLE PATH STRING (5EH)
;    Parameters:    C = 5EH (_WPATH) 
;                  DE = Pointer to 64 byte buffer
;    Results:       A = Error
;                  DE = Filled in with whole path string
;                  HL = Pointer to start of last item	

DO_WPATH:
	ex af,af
	
	ld a,(FIND_STAT)
	or a
	ld iy,0
	ret z
	
	inc iy
	dec a
	ld a,__PLONG
	ret nz
	
	;Last FFIRST/FNEW was for us & successful

	push de
	ld hl,WPATH_BUF
	ld bc,MAX_PATH_LEN+1
	ldir
	
	pop de
	ld h,d
	ld l,e
	ld bc,(WPATH_PATH_LEN)
	add hl,bc
	
	xor a
	ret

	
;------------------------------------
;>>>>>>>  Auxiliary routines  <<<<<<<
;------------------------------------


;--- Check drive in path
;    Input: DE = Pathname, possibly with a drive
;    Output: Z=1 if the drive in path is our assigned drive
;                (or if the path has no drive and default drive is ours)
;            DE=DE+2 if Z=1 and the path had a drive
;    Modifies: H

DRV_IN_PATH_MINE:
	call DRV_IN_PATH
	or a
	jp z,ISMYDRIVE
	
	call ISMYDRIVE
	ret nz
	inc de
	inc de
	ret
	

    ;Return in A the drive in the pathname passed in DE
    ;A: = 1, if no drive in pathanme returns 0 (so default drive)

DRV_IN_PATH:
	ld	a,(de)
	or	a
	ret	z	;Empty string?

	inc	de
	ld	a,(de)
	or	a
	dec	de
	ret z  ;String has only one char?

	cp ":"
	ld a,0
	ret nz  ;Second char in string is not ":"?

	ld a,(de)
	or 32
	sub "a"-1
	ret
	

    ;Is A my drive? (being 0=default drive) Z=1 if yes
    ;Corrupts H

ISMYDRIVE:
	or	a
	jr	z,ISMYDR_DEF

	ld	h,a
	ld	a,(INDRIVE1)
	cp	h
	ld	a,h
	ret

ISMYDR_DEF:
	ld	h,a
	ld	a,(CUR_IS_MINE)
	cpl
	or a
	ld	a,h
	ret
	
	
;--- Get the length of a zero-terminated string
;    Input:  DE = string	
;    Output: BC = length
;            Cy = 1 if length > MAX_PATH_LEN
;    Corrupts AF, DE

STRLEN:
	ld bc,0
STRLEN_L:
	ld a,(de)
	or a
	jr z,STRLEN_END
	inc bc
	inc de
	jr STRLEN_L
	
STRLEN_END:
	ld a,b
	scf
	ret nz
	ld a,c
	cp MAX_PATH_LEN+1
	ccf
	ret

	
;--- In-place uppercase a string
;    Input: DE = string
;    Corrupts AF, DE

TOUPPER:
	ld	a,(de)
	or a
	ret z
	
	cp "a"
	jr	c,TOUP_NEXT
	cp "z"+1
	jr nc,TOUP_NEXT
	
	and 223
	ld (de),a
	
TOUP_NEXT:
	inc de
	jr TOUPPER

	
;--- Expand wildcards of a filename:
;    * in name/extension is converted to a series of ?s
;    If no extension is provided it is assumed to be .*
;    If filename/extension is too long it is truncated
;
;    Input: HL=source, DE=destination
;    Modifies: AF, BC, HL, DE
;
;e.g.:
;ABCD.FG  -->  ABCD.FG
;ABCDEFGHIJK.LMNOP  -->  ABCDEFGH.LMN
;ABC*.D*  -->  ABC?????.D??
;ABCDE    -->  ABCDE.???
;ABCDE.   -->  ABCDE.
;ABC*DE.F*G  -->  ABC?????.F??
;*.*      -->  ????????.???
;(empty)  -->  ????????.???
	
EXPAND:	ld	b,8

	ld	a,(hl)
	or	a
	jr	nz,EXPAND_L1
	ld	hl,EXPA_EMPTY
	ld	bc,13
	ldir
	ret
EXPA_EMPTY:	db	"????????.???",0

	;--- Expand name

EXPAND_L1:
	ld	a,(hl)
	inc	hl
	or	a
	jr	z,EXPAND_END

	cp	"*"
	jr	z,EXPA_GOTASK

	cp	"."
	jr	z,EXPA_GOTDOT

	ld	(de),a
	inc	de
	djnz	EXPAND_L1

	;8 name chars processed already, skip rest

EXPAND_L2:
	ld	a,(hl)
	inc	hl
	or	a
	jr	z,EXPAND_END
	cp	"."
	jr	z,EXPA_GOTDOT
	jr	EXPAND_L2

	;Found asterisk, replace with ?s...

EXPA_GOTASK:
	ld	a,"?"
	ld	(de),a
	inc	de
	djnz	EXPA_GOTASK

	;...and skip everything else before the dot
EXPAND_L3:
	ld	a,(hl)
	inc	hl
	or	a
	jr	z,EXPAND_END
	cp	"."
	jr	z,EXPA_GOTDOT
	jr	EXPAND_L3

	;Found the dot

EXPA_GOTDOT:
	ld	(de),a
	inc	de
EXPA_GOTDOT2:
	ld	b,3

	;Expand extension

EXPAND_L4:
	ld	a,(hl)
	inc	hl
	or	a
	jr	z,EXPAND_END2

	cp	"*"
	jr	z,EXPA_GOTASK2

	ld	(de),a
	inc	de
	djnz	EXPAND_L4

	inc	de
	xor	a
	jr	EXPAND_END2

	;Got asterisk in extension

EXPA_GOTASK2:
	ld	a,"?"
	ld	(de),a
	inc	de
	djnz	EXPA_GOTASK2

	xor	a
	jr	EXPAND_END2

	;No extension specified, assume .*

EXPAND_END:
	ld	a,"."
	ld	(de),a
	inc	de
	ld	a,"?"
	ld	(de),a
	inc	de
	ld	(de),a
	inc	de
	ld	(de),a
	inc	de
	xor	a

	;End of everything

EXPAND_END2:	ld	(de),a
	ret	
	
	
;--- Get the last item of a path/filename string
;    Input:  DE = string
;    Output: HL = path to last item
;    Modifies: AF, DE, B
;
;e.g:
;A:  --> terminator
;A:\ --> terminator
;A:\foo     --> foo
;A:\foo\bar --> bar
;A:foo\bar  --> bar
;foo\bar    --> bar
;(empty)    --> terminator

GLAST:
	ld	a,(de)
	or	a
	jr	z,GLAST_END2
	inc	de
	cp	SLASH
	jr	nz,GLAST_NOSSLASH

	ld	a,(de)
	or	a
	jr	z,GLAST_END2	;just "\" -> no last item
GLAST_NOSSLASH:

	cp	":"
	inc	de
	jr	z,GLAST_DO

	dec	de
	dec	de

	;START HERE (consider current DE = start of string)

GLAST_DO:
	ld	b,0
GLAST_LEN_L:
	ld	a,(de)
	or	a
	jr	z,GLAST_LEN_END
	inc	de
	inc	b
	jr	GLAST_LEN_L

GLAST_LEN_END:	;Now B=string length and DE points to terminator

GLAST_SRCH_L:
	dec	de
	ld	a,(de)
	cp	SLASH
	jr	z,GLAST_END
	cp	":"
	jr	z,GLAST_END
	djnz	GLAST_SRCH_L
	jr	GLAST_END2

GLAST_END:
	inc	de
GLAST_END2:
	ex	de,hl
	ret	
	
	
;--- Do LDIR only if BC <> 0
;    Modifies AF (and HL, DE), makes BC=0

DO_LDIR:
	ld a,b
	or c
	ret z
	ldir
	ret
	
	
;--- Process a pathname:
;    - It is converted to an absolute path
;    - .. and . are appropriately unrolled	
;
;    Input:  DE = string to process (without drive)
;            HL = destination
;    Output: A = Error
;            DE points to terminator
;    Modifies: AF, BC, DE, HL, IX

PROCESS:
	ld	a,(de)
	or	a
	ex de,hl
	jp z,DO_GETCD2

	;Start by generating the full path

	push	de

	ld	de,PROCESS_BUF
	ld	a,(hl)
	cp	SLASH
	inc	hl
	jr	z,PROC_DOCOPY	;Absolute path? Just copy it as is
	dec	hl

	push hl
	ld de,PROCESS_BUF
	call DO_GETCD2
	pop hl
	pop de
	or a
	ret nz
	
	push de,hl
	
	ld ix,PROCESS_BUF
	ld a,b
	or c
	jr z,PROCESS_2
	add ix,bc
	ld (ix),SLASH
	inc ix
PROCESS_2:
	push ix
	pop de
	
	pop hl
		
PROC_DOCOPY:
	ld	bc,MAX_PATH_LEN+1
	ldir

PROC_COPIED:
	pop	de

	;Copy to destination while it's not . or ..
	;IX = source
	;DE = destination
	;B = accumulated output length
	;C = accumulated output length of current item
	;H = length of string before current item

	ld	ix,PROCESS_BUF
	ld	bc,0
	ld	h,0

PROC_LOOP:
	ld	a,b
	cp	MAX_PATH_LEN+1
	ld	a,__PLONG
	ret	nc

	ld	a,(ix)
	cp	"."
	jp	z,PROC_LOOP_DOT
	cp	SLASH
	jp	z,PROC_LOOP_SLASH
	or	a
	jp	z,PROC_LOOP_TERM

PROC_LOOP2:
	ld	(de),a
	inc	b
	inc	c

	inc	de
PROC_LOOP3:
	inc	ix
	jr	PROC_LOOP

	;Found a dot

PROC_LOOP_DOT:
	ld	l,a
	ld	a,c
	or	a
	ld	a,l
	jr	nz,PROC_LOOP2	;Not at the beginning of current item: assume extension

	ld	a,(ix+1)
	or	a
	jr	z,PROC_SDOT_TERM
	cp	SLASH
	jr	z,PROC_SINGLEDOT
	cp	"."
	ld	a,l
	jr	nz,PROC_LOOP2	;".xyz" --> assume extension alone

PROC_DBLDOT:

	;It's a double dot entry

	ld a,b
	or a
	ld a,__NODIR
	ret z
	
	dec	de	;Go to the last char of previous level
	dec	de
	dec b	;For the slash
	dec b
	
PROC_GOBACK:
	ld a,b
	or a ;Start of string reached?
	jr	z,PROC_BACK_END
	ld	a,(de)
	cp	SLASH
	jr	z,PROC_BACK_END
	dec	b
	dec	de
	jr	PROC_GOBACK

PROC_BACK_END2:
	inc	de
PROC_BACK_END:
	inc	ix
	inc	ix
	ld	c,0
	jr	PROC_LOOP

PROC_SINGLEDOT:

	;It's a single dot entry: just ignore it

	inc	ix
	ld	a,(ix+1)	;Followed by terminating slash
	or	a
	jr	z,PROC_LOOP
	inc	ix
	jr	PROC_LOOP

PROC_SDOT_TERM:

	;It's a single dot entry followed by a terminator:
	;just output it

	ld	a,"."
	ld	(de),a
	inc	de
	xor	a
	ld	(de),a
	ret

	;It's a slash

PROC_LOOP_SLASH:
	ld a,b
	or a
	jr nz,PROC_SLASH2	;Is at the beginning? (after "..")

	inc ix
	jr PROC_LOOP
	
PROC_SLASH2:
	inc	ix
	ld	a,(ix)
	or	a	;Slash is the last char?
	jr	nz,PROC_NOSSLASH

	ld (de),a
	inc de
	xor	a
	ld	(de),a
	ret

PROC_NOSSLASH:
	cp	SLASH
	ld	a,__IPATH	;A double slash is illegal
	ret	z

PROC_SLASHNXT:
	ld	a,SLASH
	ld	(de),a
	inc	de
	inc	b
	ld	c,0
	jp	PROC_LOOP

	;It's the string terminator

PROC_LOOP_TERM:
PROC_TERM2:
	xor	a
	ld	(de),a
	ret	
	
	
;--------------------------
;>>>  Buffers and data  <<<
;--------------------------

;Drive in which the filesystem acts (0=A:) 

INDRIVE0:	db	6

;Drive in which the filesystem acts (1=A:)
INDRIVE1:	db	7	

;Is my drive the current drive?
CUR_IS_MINE:	db	0

AST_DOT_AST:	db	"*.*",0

;Is current directory cached?
CURDIR_IS_CACHED: db 0	
	
;Current directory cache
CURDIR:	ds	MAX_PATH_LEN + 1
CURDIR_LEN:	dw 0

;Value to be returned by _WPATH
WPATH_BUF: ds	MAX_PATH_LEN + 1 + 13 ;Leave room in case FFIRST with FIB produces a too long path

;Length of value in WPATH_BUF
WPATH_LEN:	dw 0

;Path to terminator item in WPATH_BUF
WPATH_END_PNT: dw WPATH_BUF

;Length of value in WPATH_BUF except last item (it's DW on purpose)
WPATH_PATH_LEN:	dw 0

;Status of last FFIRST/FNEXT call:
;0: It was not for me, or it was for me and resulted in error (except .PLONG)
;1: It was for me and finished successfully
;2: It was for me and finished with .PLONG
FIND_STAT: db 0

	db SLASH
;Temporary buffer for path/filenames
PATHFILEBUF: ds (MAX_PATH_LEN*2)+1

;Bufer for PROCESS_PATH
PROCESS_BUF:	ds	128

;Is volume label cached?
VOLABEL_IS_CACHED: db 0

;Volume label cache
VOLABEL_CACHE: ds 12
	
	
;-------------------------------------------------
;>>>>>>>  Hardware/device - specific code  <<<<<<<
;-------------------------------------------------

;TODO: Implement these according to how your specific hardware/device works.

;General considerations:

;- All user data buffers (paths, FIBs) will be either in this same segment
;  or in page 3, so don't worry about slot/segment paging.

;- Pathname and FIB buffers are 64 bytes long.

;- Supplied pathnames will never contain a drive letter (if it does originally,
;  the supplied pointers will point past it)

;- All registers that don't return data can be freely modified.

;- The list of possible error codes is not exhaustive, the routines can return
;  any of the error codes defined in "MSX-DOS Program Interface Specification"
;  as they find appripriate.


;--- Get allocation information
;Input:  -
;Output: A = Error code
;        C = Sectors/cluster (0FFh if any error)
;        DE = Total number of clusters
;        HL = Number of free clusters
;Error codes:
;        __DISK: General error accessing the device
;
;NOTE: Don't spend too much time in this routine, since it will eventually
;      be replaced with another one that returns the size directly in KB.

IMPL_ALLOC:
	ld	c,1
	ld	de,0
	ld	hl,0
	xor	a
	ret


;---Find first entry (search files)
;Input:   DE = Drive/path/file ASCIIZ string to search
;              or fileinfo block pointer for the directory
;         HL = filename ASCIIZ string (if DE = fileinfo pointer)
;         IY = full processed path of the file
;         B = Search attributes:
;             bit 1 set: include hidden files in results
;             bit 2 set: include system files in results
;             bit 4 set: include subdirectories in results
;             (regular non-hidden non-system files must be always
;              included in results)
;         IX = Pointer to new fileinfo block
;Output:  A = Error
;         IX preserved
;        (IX) = Filled in with matching entry
;Error codes:
;        __DISK:  General error accessing the device
;        __NOFIL: File not found

;DE will point to an existing fileinfo block if first byte is FFh.
;You can either use DE or DE+HL as supplied by the caller,
;or use IY as generated by PROCESS, or both.

;FIB fields that this routine needs to fill:

; 1..13 - Filename as an ASCIIZ string
;    14 - File attributes byte:
;         bit 0: read-only
;         bit 1: hidden
;         bit 2: system
;         bit 4: directory
;         bit 5: archive
;15..16 - Time of last modification
;17..18 - Date of last modification
;21..24 - File size (little endian)

;How to generate the date/time bytes:

;+15 = ((minute & 7) << 5) | (second / 2)
;+16 = (hour << 3) | (minute >> 3)
;+17 = (month << 5) | day
;+18 = ((year - 1980) << 1) | (month >> 3)

;The fileinfo block is 64 bytes long. You can use the last 32 bytes
;to store whatever information you need for FNEXT.

IMPL_FFIRST:
	ld a,__NOFIL
	ret

	
;--- Find next entry (search files)
;Input:     IX = Pointer to fileinfo block from
;                previous FFIRST or FNEXT function
;Output:    A = Error
;           IX preserved
;           (IX) = Filled in with next matching entry
;Error codes:
;        __DISK:  General error accessing the device
;        __NOFIL: File not found

;FIB fields that this routine needs to fill: same as FFIRST.
;Also, again you can use the last 32 bytes of the FIB freely.

;If this method returns no error, the two-byte value stored
;at FIB+26 (which is set to 0 by FFIRST) will be incremented.
;Thus it will be 0 the first time FNEXT is executed,
;1 the next time, and so on.

IMPL_FNEXT:
	ld	a,__NOFIL
	ret
	

;--- Change current directory
;Input:    DE = Path/file ASCIIZ string
;          Cy = 1 if a cached version of current directory is available
;          IX = Pointer to cached current directory (if Cy = 1)
;          HL = Pointer to full processed directory
;Output:   A  = Error
;Error codes:
;        __DISK:  General error accessing the device
;        __NODIR: Directory not found

;You can use DE as supplied, or HL as generated by PROCESS, or both.

IMPL_CHDIR:
	ld a,__NODIR
	ret
	

;--- Get current directory
;Input:    DE = pointer to 64 byte buffer for copying the current directory
;Output:   A  = Error
;          Cy = 1 if the result can be cached
;		   Cy MUST be 0 if there is an error
;Error codes:
;        __DISK:  General error accessing the device

;The returned string must not start or end with a slash,
;thus the root directory is represented as an empty string.

;The cached value will be discarded if any of these routines
;return a disk error (error code >= F0h) 

IMPL_GETCD:
	xor a
	ld (de),a
	ret
	

;--- Get the volume label
;Input:     DE = pointer to 11 byte buffer for copying the volume label
;Output:    A  = Error code
;           Cy = 1 if volume label can be cached
;Error codes:
;        __DISK:  General error accessing the device
;        __NOFIL: No volume label is available
	
;The cached value will be discarded if any of these routines
;return a disk error (error code >= F0h) 	
	
IMPL_GETVOL:
	ld a,__NOFIL
	ret

	
IMPL_END: ;TODO: verify that IMPL_END is <8000h

PARTRE2!:
