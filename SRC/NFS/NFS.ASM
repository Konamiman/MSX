;NestorFilesystem


;******************************************************
;*                                                    *
;*                 MACROS, CONSTANTES                 *
;*                                                    *
;******************************************************

IDNES:	equ	#22	;ID para la BIOS extendida
IDNFS:	equ	4

;Min and max function calls that will be hooked,
;apart from some that will be treated as special cases

MINFN: equ 40h	;_FFIRST
MAXFN: equ 5Ah	;_CHDIR

dos:	macro
	call	5
	endm

	;*** GANCHOS Y VARIABLES DEL SISTEMA

ENDTPA:	equ	#0006
HIGHMEM:	equ	#F349
H_TIMI:	equ	#FD9F
H_STKE:	equ	#FEDA
EXTBIO:	equ	#FFCA
CALSLT:	equ	#001C
CGPBAS:	equ	#F924	;Actual dir. gen. de caracteres (VRAM)
LDIRMV:	equ	#005C	;Copia de memoria a VRAM
ENASLT:	equ	#0024
KANAST:	equ	#FCAC
NEWKEY:	equ	#FBE5
CAPST:	equ	#FCAB
CHGCAP:	equ	#0132
MODE:	equ	#FAFC
CHPUT:	equ	#00A2
RDSLT:	equ	#000C
WRPSG:	equ	#0093
RDPSG:	equ	#0096
EXPTBL:	equ	#FCC1
SETWRT:	equ	#0053
CUR_DRV:	equ	0F23Ch

H_BDOS: equ #F252

	;*** FUNCIONES DEL DOS

_STROUT:	equ	09h
_CPMVER:	equ	0Ch
_DSKRST:	equ	0DH
_SELDSK:	equ	0EH
_ALLOC:		equ	1Bh
_CURDRV:	equ	19h
_FFIRST:    equ	40h
_FNEXT:     equ	41h
_GETCD:		equ	59h
_CHDIR:		equ	5Ah
_WPATH:		equ	5Eh
_FLUSH:		equ	5FH
_TERM:	equ	62h
_DOSVER:	equ	6Fh

;*** DOS error codes

__DISK:	equ 0FDh
__IFORM:	equ 0F0h	;Used for testing


;******************************************************
;*                                                    *
;*                 INSTALACION                        *
;*                                                    *
;******************************************************

	org	#100

	ld	de,PRESENT_s
	ld	c,_STROUT
	dos

;--- Comprobamos presencia del DOS 2

	ld	c,_DOSVER	;DOS 2?
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

;--- Comprobamos que hay suficiente TPA (#0006 >= #C200)

	ld	a,(ENDTPA+1)
	cp	#C2
	jr	nc,OKTPA

	ld	de,NOTPAS
	ld	c,_STROUT
	dos
	jp	FIN
NOTPAS:	db	13,10,"*** TPA is too small (end of TPA must be at least #C200).",13,10,"$"
OKTPA:	;


;--- Obtencion de la tabla de rutinas de soporte del mapeador de memoria

	ld	de,#0402
	call	EXTBIO
	ld	a,b	;de paso establecemos el slot en la
	and	%10001111	;futura rutina de salto de pag. 3
	ld	(RESCODE1+11),a
	ld	(RESCODE2+11),a
	ld	de,ALL_SEG
	ld	bc,#30
	ldir

;--- Comprobamos si NFS ya esta instalado,
;    en ese caso pasamos a desinstalar si el parametro es "U"

	ld	de,IDNFS+256*IDNES
	call	EXTBIO
	cp	IDNES
	jp	z,DESINST

;--- Comienza la instalacion: reservamos un segmento de RAM

	ld	b,0	;Reservamos un segmento de sistema
	ld	a,1	;en el mapeador primario
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

;--- Copiamos los antiguos ganchos en la futura rutina de salto

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

;--- Reservamos memoria en la pagina 3 para la rutina de salto y la copiamos

	ld	hl,(HIGHMEM)	;Guardamos antiguo HIGHMEM,
	ld	(RESCODE1+21),hl	;y establecemos el nuevo
	ld	(RESCODE2+21),hl
	ld	bc,RESCODE2-RESCODE1
	or	a
	sbc	hl,bc
	ld	(HIGHMEM),hl
	ld	(RESCODE1+19),hl
	ld	(RESCODE2+19),hl

	ld	hl,PUT_P1	;Copiamos entrada a PUT_P1 + GET_P1
	push	hl
	ld	de,RESCODE1+13
	ld	bc,6
	ldir
	pop	hl
	ld	de,RESCODE2+13
	ld	bc,6
	ldir

	ld	hl,RESCODE1	;Copiamos la rutina de salto a pag. 3 !!
	ld	de,RESCODE2
	ld	ix,(RESCODE1+19)
	ld	bc,RESCODE2-RESCODE1
	call	REUBICA

;--- Copiamos la parte residente en el segmento que acabamos de reservar

	call	GET_P1	;Copiamos la parte residente
	push	af	;en el segmento
	ld	a,(RESCODE1+12)
	call	PUT_P1
	ld	hl,PARTRE2
	ld	de,#4000
	ld	bc,PARTRE2!-#4000
	ldir

	pop	af
	call	PUT_P1

;--- Establecemos los nuevos ganchos

	di

	ld	hl,(HIGHMEM)
	ld	de,EXTBIO
	ld	bc,5
	ldir

	ld	bc,23-5
	add	hl,bc
	ld	a,#C3
	ld	(H_BDOS),a
	ld	(H_BDOS+1),hl
	
;--- Finalizacion de la instalacion

	ei

	ld	de,INSSTR
	ld	c,_STROUT
	dos
	ld	hl,#0081
	jp	CALSYS

INSSTR:	
	db	"Installed. Have fun!",13,10,"$"

;--- Desinstalacion si el parametro es "U"

DESINST:	ld	hl,#0081	;Linea de comando: vamos pasando espacios
BUSCAU:	ld	a,(hl)
	inc	hl
	cp	32
	jr   z,	BUSCAU
	or	a
	jr	nz,CHKU

NODES:
	ld	de,YAINSTR	;Si encontramos un 0: no hay parametros
	ld	c,_STROUT
	dos
	jp	FIN

YAINSTR:	db	"*** Already installed. Run with U to uninstall.",13,10,"$"

CHKU:	and	%11011111	;Si encontramos algo tiene que ser "U"
	cp	"U"
	jr	nz,NODES
	ld	(POS2COM),hl	;Guardamos posicion posterior a la "U"

	ld	de,IDNFS+IDNES*256	;Comprobamos que HIGHMEM actual es igual
	call	EXTBIO	;al HIGHMEM cuando instalamos NestAc.
	ld	de,(HIGHMEM)	;Si no, no podemos desinstalar.
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
	ld	a,c	;Liberamos el segmento
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

	ld	de,DESSTR	;Terminamos!
	ld	c,_STROUT
	dos
	ld	hl,(POS2COM)
	jp	CALSYS

DESSTR:	db	"Uninstalled, please come back!",13,10,"$"
POS2COM:	dw	0

RESTHOOK:	ldir
	ld	bc,5
	ret

;--- Subrutina de reubicacion de un codigo
;    Entrada: HL = Primera copia
;             DE = Segunda copia
;             IX = Destino
;             BC = Longitud

REUBICA:	push	bc,de,hl	;Primero copiamos el codigo tal cual
	push	ix	;(HL a IX, lon. BC)
	pop	de
	ldir
	pop	hl,de

	push	de
	pop	iy	;IY = Segunda copia
	ld	b,h
	ld	c,l
	push	ix
	pop	hl
	or	a
	sbc	hl,bc
	ld	b,h
	ld	c,l	;BC = Distancia a sumar (IX - HL)

	exx
	pop	bc
	exx

	;En este punto: IX = Destino
	;               IY = Segunda copia
	;               BC = Distancia a sumar (nueva dir - 1a copia)
	;               BC'= Longitud

BUCLE:	ld	a,(ix)
	cp	(iy)
	jr	z,NEXT	;Si no hay diferencias pasamos al siguiente byte

	ld	l,a
	ld	h,(ix+1)	;HL = Dato a cambiar
	add	hl,bc	;HL = Dato cambiado
	ld	(ix),l	;IX = Direccion del dato a cambiar
	ld	(ix+1),h

	call	CHKCOMP
	jr	z,FINREUB	;Si: sacabo!

	inc	ix
	inc	iy
NEXT:	inc	ix	;Siguiente byte a comparar
	inc	iy	;(si hemos sutituido, hay que incrementar dos veces)
	call	CHKCOMP
	jr	nz,BUCLE

FINREUB	ret

CHKCOMP:	exx
	dec	bc	;Decrementamos contador, y si llega a 0
	ld	a,b	;volvemos con Z=1
	or	c
	exx
	ret

;--- Rutina de salto al BASIC y CALL SYSTEM.
;    Previamente se copia el comando a ser ejecutado tras el _SYSTEM,
;    a partir de la posicion de la linea de comando entrada en HL.

CALSYS:	ld	ix,SysCom

BUCSYSCOM:	ld	a,(hl)	;Buscamos el primer caracter, o el 0
	inc	hl
	or	a
	jr	z,OKBSC
	cp	" "
	jr	z,BUCSYSCOM
	dec	hl

BUCSYS2:	ld	(ix),a	;Copiamos caracteres hasta encontrar
	inc	ix	;el 0
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
OKBSC:	;

	;CALL SYSTEM propiamente dicho

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

;--- Tabla de salto para las rutinas del mapeador

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

PRESENT_s:
	db	"NestorFilesystem 1.0",13,10
	db	"By Konamiman 3/2017",13,10
	db	13,10
	db	"$"

TEMP:	ds	5

;******************************************************
;*                                                    *
;*            PARTE RESIDENTE EN PAG. 3               *
;*                                                    *
;******************************************************

PARTRES:	macro

INIRES@sym:	;
NEWBIO@sym:	jp	_NEWBIO@sym	;+0
OLDBIO@sym:	ds	5			;+3
OLDHBDOS@sym:	ds 3		;+8
RESLOT@sym:	db	0			;+11
RESEG@sym:	db	0			;+12
PUT_P1@sym:	jp	#0000		;+13
GET_P1@sym:	jp	#0000		;+16
NEWHM@sym:	dw	0			;+19
OLDHM@sym:	dw	0			;+21

;--- Nuevo gancho H_BDOS

_NEWBDOS@sym:	;+23
	push  iy

	ex	af,af
	ld	a,c
	cp	_DSKRST
	jr	z,OKGO@sym
	cp	_SELDSK
	jr	z,OKGO@sym
	;cp	_CURDRV
	;jr	z,OKGO@sym
	cp	_ALLOC
	jr	z,OKGO@sym
	cp	_WPATH
	jr	z,OKGO@sym
	cp	_FLUSH
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


;--- Nuevo EXTBIO:
;    Entrada: D = IDNES
;             E = 0
;    Salida:  HL= NewHIGHMEM
;             IX= OldHIGHMEM
;             B = Slot del segmento reservado
;             C = Segmento reservado
;             A = IDNES

_NEWBIO@sym:	push	af	;BIOS extendida. Identificador: IDNES
	ld	a,d	;Modifica IX, IY y alternativos.
	cp	IDNES	;Nunca modifica DE.
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

;--- Subrutina para la obtencion del slot conectado en pagina 2

GETSLOT1@sym:	;di
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

ENDRES@sym:	;                        ;Fin de la parte residente en pagina 3
	endm

RESCODE1:	PARTRES
RESCODE2:	PARTRES


;******************************************************
;*                                                    *
;*          PARTE RESIDENTE EN UN SEGMENTO            *
;*                                                    *
;******************************************************

PARTRE2:	org	#4000	;Se ejecutara en la pagina 1

	db	"NestorFS",0
	ds	16-($-#4000)

JMP_ALLOC:	jp	IMPL_ALLOC
JMP_FFIRST:	jp	IMPL_FFIRST
JMP_FLUSH:	jp	IMPL_FLUSH
JMP_GETCD:	jp	IMPL_GETCD
JMP_CHDIR:	jp	IMPL_CHDIR

INDRIVE0:	db	6	;Drive in which the filesystem acts (0=A:) - TODO: set from command line when installing
CUR_IS_MINE:	db	0	;Is my drive the current drive?
INDRIVE1:	db	7	;Drive in which the filesystem acts (1=A:)


;-----------------
;--- Functions ---
;-----------------

;DISK RESET (0DH)
;Parameters:    C = 0DH (_DSKRST)
;Results:       None

DO_DSKRST:
	ex	af,af
	ld	b,0FFh
	ld	d,0FFh
	jp	DO_FLUSH


;SELECT DISK (0EH)
;Parameters:    C = 0EH (_SELDSK)
;               E = Drive number.  0=A: 1=B:   etc.
;Results:     L=A = Number of drives (1...8)

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
	ld	a,8	;!!! TODO: should be number of drives
	ld	l,a
	ret
	

;GET CURRENT DRIVE (19H)
;Parameters:    C = 19H (_CURDRV)
;Results:     L=A = Current drive (0=A: etc)

DO_CURDRV:
	ex	af,af
	ld	a,(CUR_IS_MINE)
	ld	iy,0
	or	a
	ret	z

	ld	a,(INDRIVE0)
	ld	l,a
	inc	iy
	ret


;GET ALLOCATION INFORMATION (1BH)
;Parameters:    C = 1BH (_ALLOC)
;               E = drive number (0=default)
;Results:       A = Error code
;               C = Sectors/cluster (0FFh if any error)
;               DE = Total number of clusters
;               HL = Number of free clusters
;               IX = Pointer to MSX-DOS 1.0 compatible DPB (NO!)
;               IY = Pointer to first FAT sector in a page-3 buffer (NO!)

DO_ALLOC:
	ex	af,af
	ld	a,e
	call	ISMYDRIVE
	ld	iy,0
	ret	nz

	call JMP_ALLOC
	ld	iy,1
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
	ld	a,h
	ret


;FIND FIRST ENTRY (40H)
;Parameters:    C = 40H (_FFIRST) 
;              DE = Drive/path/file ASCIIZ string
;                   or fileinfo block pointer
;              HL = filename ASCIIZ string (only if
;              DE = fileinfo pointer)
;               B = Search attributes
;              IX = Pointer to new fileinfo block
;Results:       A = Error
;            (IX) = Filled in with matching entry

DO_FFIRST:
	ex	af,af
	ld	a,(de)
	cp	0FFh
	jr	z,FFIRST_FIB

	call DRV_IN_PATH
	or a
	jr	z,FFIRST_CURDRV

	ld	h,a
	ld	a,(INDRIVE1)
	cp	h
	ld	iy,0
	ret	nz

	call	JMP_FFIRST
	ld	iy,1
	ret

FFIRST_CURDRV:
	ld	a,(CUR_IS_MINE)
	or	a
	ld	iy,0
	ret	z
	
	call	JMP_FFIRST
	ld	iy,1
	ret

FFIRST_FIB:
	push	de
	pop	iy
	ld	a,(INDRIVE0)
	cp	(iy+25)
	ld	iy,0
	ret	nz

	call	JMP_FFIRST
	ld	iy,1
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

;Same as DRV_IN_PATH but if not defualt drive
;increment DE by two (so it points past the drive letter)

DRV_IN_PATH_INC:
	call DRV_IN_PATH
	or a
	ret z

	dec de
	dec de
	ret


;GET CURRENT DIRECTORY (59H)
;Parameters:    C = 59H (_GETCD) 
;               B = Drive number (0=current, 1=A: etc)
;              DE = Pointer to 64 byte buffer
;Results:       A = Error
;              DE = Filled in with current path

DO_GETCD:
	ex	af,af
	ld	a,b
	call  ISMYDRIVE
	ld	iy,0
	ret	nz

	call JMP_GETCD
	ld	iy,1
	ret


;CHANGE CURRENT DIRECTORY (5AH)
;Parameters:    C = 5AH (_CHDIR) 
;              DE = Drive/path/file ASCIIZ string
;Results:       A = Error

DO_CHDIR:
	ex	af,af
	call DRV_IN_PATH
	ld b,a
	call ISMYDRIVE
	ld	iy,0
	ret	nz

	ld	a,b
	or	a
	jr	z,CHDIR_OKDRV2
	inc	de
	inc	de

CHDIR_OKDRV2:
	call JMP_CHDIR
	ld	iy,1
	ret


;FLUSH DISK BUFFERS (5FH)
;Parameters:    C = 5FH (_FLUSH) 
;               B = Drive number (0=current, FFH=all)
;               D = 00H => Flush only
;                 = FFH => Flush and invalidate
;Results:       A = Error

DO_FLUSH:
	ex	af,af
	ld	a,b
	cp	0FFh
	jr	z,DO_FLUSH_ALL

	ld	a,b
	call	ISMYDRIVE
	ld	iy,0
	ret	nz

DO_FLUSH_ISMINE:
	call JMP_FLUSH
	ld	iy,1
	xor	a
	ret

DO_FLUSH_ALL:
	push	bc,de
	call JMP_FLUSH
	pop		de,bc
	ld	iy,0
	ret


;--------------------------------
;--- Function implementations ---
;--------------------------------

;Get allocation information
;Input:  -
;Output: A = Error code
;        C = Sectors/cluster (0FFh if any error)
;        DE = Total number of clusters
;        HL = Number of free clusters

IMPL_ALLOC:
	ld	c,2
	ld	de,60000
	ld	hl,34
	xor	a
	ret

	ld	a,__DISK
	ret


;Find first entry
;Input:   DE = Drive/path/file ASCIIZ string or fileinfo block pointer
;         HL = filename ASCIIZ string (only if DE = fileinfo pointer)
;         B = Search attributes
;         IX = Pointer to new fileinfo block
;Output:  A = Error
;        (IX) = Filled in with matching entry

IMPL_FFIRST:
	ld	(ix),0FFh
	ld	(ix+1),"M"
	ld	(ix+2),"O"
	ld	(ix+3),"L"
	ld	(ix+4),"A"
	ld	(ix+5),"!"
	ld	(ix+6),0
	ld	(ix+21),34
	ld	(ix+22),0
	ld	(ix+23),0
	ld	(ix+24),0
	ld	a,(INDRIVE0)
	ld	(ix+25),a

	xor	a
	ret


;Get current directory
;Input:   DE = Pointer to 64 byte buffer
;Output:  A = Error
;         DE preserved

IMPL_GETCD:
	push de
	ld	hl,CURDIR
	ld	bc,64
	ldir
	pop de
	xor a
	ret

	push	de
	pop	ix
	ld	(ix),"U"
	ld	(ix+1),"N"
	ld	(ix+2),"D"
	ld	(ix+3),"I"
	ld	(ix+4),"R"
	ld	(ix+5),0
	xor	a
	ret


;Change current directory
;Input:    DE = Drive/path/file ASCIIZ string
;Output:   A = Error

IMPL_CHDIR:
IMPL_CHDIR2:
	ld	a,(de)
	or	a
	jr	z,IMPLCHDIR_OK
	cp  "\\"
	jr	nz,IMPLCHDIR_OK
	inc	de
	jr	IMPL_CHDIR2

IMPLCHDIR_OK:
	ex de,hl
	ld	de,CURDIR
	ld	bc,64
	ldir

	xor	a
	ret


;Flush buffers
;Input:  D=FFh to also invalidate
;Output: A = error code

IMPL_FLUSH:
	xor	a
	ret

;---------------------
;--- Gancho H_BDOS ---
;---------------------

DOSENTRY:
	ex	af,af
	ld	a,c

	cp	_DSKRST
	jp	z,DO_DSKRST
	cp	_SELDSK
	jp	z,DO_SELDSK
	;cp	_CURDRV
	;jp	z,DO_CURDRV
	cp	_ALLOC
	jp	z,DO_ALLOC
	cp	_FFIRST
	jp	z,DO_FFIRST
	cp	_FLUSH
	jp	z,DO_FLUSH
	cp	_GETCD
	jp	z,DO_GETCD
	cp	_CHDIR
	jp  z,DO_CHDIR

	jp	NOFLUSH


	cp	1Bh	;_ALLOC
	jr	nz,NOALLOC

	ld	a,e
	cp	6
	jp	c,DONOTHING

	ld	c,2	;/2 sec/clus
	ld	de,60000
	ld	hl,34
	ld	ix,0
	
	jp	DONEOK

NOALLOC:
	cp	5Fh
	jr	nz,NOFLUSH

	ld	a,b
	cp	0FFh
	jr	z,DONOTHING
	cp	6
	jr	z,DONOTHING

	jr	DONEOK

NOFLUSH:
	cp	40h		;_FFIRST/_FNEXT
	jr	nz,NOFFIRST

	ld	a,(de)
	cp	0FFh
	jr	z,DONOTHING

	inc	de
	ld	a,(de)
	cp	":"
	dec	de
	jr	z,HASDRIVE

	ld	a,(CUR_IS_MINE)
	or	a
	ld	iy,0
	ret	z
	jr	FFIRSTMINE

HASDRIVE:
	ld	a,(de)
	or	32
	cp	"g"
	jr	nz,DONOTHING
	inc	de
	ld	a,(de)
	dec	de
	cp	":"
	jr	nz,DONOTHING

FFIRSTMINE:
	ld	(ix),0FFh
	ld	(ix+1),"M"
	ld	(ix+2),"O"
	ld	(ix+3),"L"
	ld	(ix+4),"A"
	ld	(ix+5),"!"
	ld	(ix+6),0
	ld	(ix+21),34
	ld	(ix+22),0
	ld	(ix+23),0
	ld	(ix+24),0
	ld	(ix+25),6

	jr	DONEOK

NOFFIRST:
	ld	a,c
	cp	41h
	jr	nz,DONOTHING

	ld	a,(INDRIVE0)
	cp	(ix+25)
	jr	nz,DONOTHING

	ex	af,af
	ld	a,0D7h	;.NOFIL
	ld	iy,1
	ret

DONEOK:
	ex	af,af
	xor	a
	ld	iy,1
	ret

DONOTHING:
	ex	af,af
	ld	iy,0
	ret

CURDIR:	ds	64

PARTRE2!:	;
