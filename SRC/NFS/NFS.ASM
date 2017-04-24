;NestorFilesystem

;TODO:
;Choose drive at startup
;Extra space for FFIRST and FNEXT (with MAX_FIBS and EXTRA_FIB_SIZE constants)
;WPATH
;DSPACE (and infer ALLOC)
;Init/deinit
;Translate/TODOize


;******************************************************
;*                                                    *
;*                 MACROS, CONSTANTES                 *
;*                                                    *
;******************************************************

IDNES:	equ	22h	;ID para la BIOS extendida
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

breakp: macro
	db 0EDh,0
	endm
	
	;*** GANCHOS Y VARIABLES DEL SISTEMA

ENDTPA:	equ	#0006
HIGHMEM:	equ	#F349
H_TIMI:	equ	0FD9Fh
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
_LOGIN:		equ	18h
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

__IATTR:    equ 0CFh
__NODIR: equ 0D6h
__NOFIL:	equ 0D7h
__PLONG:	equ 0D8h
__IPATH:	equ	0D9h
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
	ld	a,0C3h
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
	ex	af,af
	ld	a,c
	cp	_LOGIN
	jr	nz,NOLOGIN@sym
	
	pop	hl
	ld	de,NEXTLOGIN@sym
	push	de
	jp	(hl)
	
NEXTLOGIN@sym:
	set	6,l	;TODO: Depends on drive letter!
	ret
	
NOLOGIN@sym:
	push  iy

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

	db	"FileSysDriver",0
	db 0,1	;Specification version complied

JMP_ALLOC:	jp	IMPL_ALLOC
JMP_FFIRST:	jp	IMPL_FFIRST
JMP_FNEXT:	jp	IMPL_FNEXT
JMP_CHDIR:	jp	IMPL_CHDIR
JMP_GETCD:  jp  IMPL_GETCD
JMP_GETVOL: jp  IMPL_GETVOL

INDRIVE0:	db	6	;Drive in which the filesystem acts (0=A:) - TODO: set from command line when installing
CUR_IS_MINE:	db	0	;Is my drive the current drive?
INDRIVE1:	db	7	;Drive in which the filesystem acts (1=A:)


;-----------------
;--- Functions ---
;-----------------


;SELECT DISK (0EH)
;Parameters:    C = 0EH (_SELDSK)
;               E = Drive number.  0=A: 1=B:   etc.
;Results:       A = Error code
;               L = Number of drives (1...8)

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
	ld	hl,(0F347h)	;!!! TODO: may not include our drive
	xor	a
	ld	h,a
	ret
	

;GET CURRENT DRIVE (19H)
;Parameters:    C = 19H (_CURDRV)
;Results:       A = Error code
;               L = Current drive (0=A: etc)

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
	xor a
	ld (FIND_STAT),a	;Assume not for me, or error, to start with
	
	ld	a,(de)
	cp	0FFh
	jr	z,FFIRST_FIB
	
	;--- Path/file based search, DE points past the drive if any
	
	call DRV_IN_PATH_INC
	push bc,hl
	call ISMYDRIVE
	pop hl,bc
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
	
	ld hl,FFIRST_BUF
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
	ld de,WPATH_BUF
	ld bc,MAX_PATH_LEN+1
	ldir
	
	jr FFIRST_END
	
	;--- FIB based search
	
FFIRST_FIB:
	push	de
	pop	iy
	ld	a,(INDRIVE0)
	cp	(iy+25)
	ld c,(iy+14)
	ld	iy,0
	ret	nz
	
	bit 4,c	;FIB must specify a directory
	ld a,__IATTR
	ret z
	bit 3,c	;FIB can't specify a volume name
	ret nz
	
	push ix
	call	JMP_FFIRST
	pop ix
	ld	iy,1
	or a
	ret nz
	
	ld hl,WPATH_BUF
	ld bc,(WPATH_LEN)
	add hl,bc
	ld (hl),SLASH
	inc hl

FFIRST_FIB_OK1:
	ex de,hl
	push ix
	pop hl
	inc hl
	ld bc,13
	ldir	;append filename to WPATH
	
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
	ld	a,(INDRIVE0)
	ld (ix+25),a
	ld a,1
	ld (FIND_STAT),a
	dec a
	ld (ix),0FFh
	ld (ix+19),a	;start cluster
	ld (ix+20),a
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
	push de
	call JMP_GETVOL
	pop de
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
	ld	a,(INDRIVE0)
	ld (ix+25),a
	ld (ix+14),%1000 ;Volume label attribute

	xor a
	ld iy,1
	ret
	
FFIRST_BUF: ds MAX_PATH_LEN + 1


;FIND NEXT ENTRY (41H)
;Parameters:    C = 41H (_FNEXT) 
;              IX = Pointer to fileinfo block from
;                   previous find first function.
;Results:       A = Error
;            (IX) = Filled in with next matching entry

DO_FNEXT:
	ld	a,(INDRIVE0)
	cp	(ix+25)
	ld	iy,0
	ret	nz

	call	JMP_FNEXT
	ld	iy,1
	ret
			

;GET CURRENT DIRECTORY (59H)
;Parameters:    C = 59H (_GETCD) 
;               B = Drive number (0=current, 1=A: etc)
;              DE = Pointer to 64 byte buffer
;Results:       A = Error
;              DE = Filled in with current path
;              BC = Length of string in DE

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

	
;CHANGE CURRENT DIRECTORY (5AH)
;Parameters:    C = 5AH (_CHDIR) 
;              DE = Drive/path/file ASCIIZ string
;Results:       A = Error

DO_CHDIR:
	ex	af,af
	
	call DRV_IN_PATH_INC
	ld  b,a
	call ISMYDRIVE
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
	
	
;GET WHOLE PATH STRING (5EH)
;Parameters:    C = 5EH (_WPATH) 
;              DE = Pointer to 64 byte buffer
;Results:       A = Error
;              DE = Filled in with whole path string
;              HL = Pointer to start of last item	

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
;Input:   DE = Drive/path/file ASCIIZ string 
;              or fileinfo block pointer for the directory
;         HL = filename ASCIIZ string (if DE = fileinfo pointer)
;         HL = processed path (if DE = pathname)
;         B = Search attributes
;         IX = Pointer to new fileinfo block
;Output:  A = Error
;        (IX) = Filled in with matching entry
;         HL = Pointer to full path of found file (for _WPATH)
;
;Supplied DE, HL and IX will always be in page 3

IMPL_FFIRST:
	;ld	(ix),0FFh
	ld a,(de)
	ld  (ix+1),a
	ld  (ix+2),"-"
	ld	(ix+3),"M"
	ld	(ix+4),"O"
	ld	(ix+5),"L"
	ld	(ix+6),"A"
	ld	(ix+7),"!"
	ld	(ix+8),0
	ld	(ix+14),0
	ld	(ix+21),34
	ld	(ix+22),0
	ld	(ix+23),0
	ld	(ix+24),0
	;ld	a,(INDRIVE0)
	;ld	(ix+25),a

	;search pattern starts with "d" -> simulate a dir
	
	ld a,(de)
	cp 0FFh
	ld a,0
	ret z
	
	ld a,(de)
	or 32
	cp "d"
	ld a,0
	ret nz
	
	ld a,%10000
	ld (ix+14),a
	xor a
	ret

	
;Find next entry
;Input:     IX = Pointer to fileinfo block from
;                previous find first function.
;Output:    A = Error
;           (IX) = Filled in with next matching entry

IMPL_FNEXT:
	ld	a,__NOFIL
	ret
	

;Change current directory
;Input:    DE = Path/file ASCIIZ string
;          Cy = 1 if a cached version is available
;          IX = Pointer to cached version (if Cy = 1)
;          HL = Pointer to processed version
;Output:   A  = Error

IMPL_CHDIR:
	ld de,MYCURDIR
	ld bc,MAX_PATH_LEN+1
	ldir
	xor a
	ret
	

;Get current directory
;Input:    DE = Path/file ASCIIZ string
;Output:   A  = Error
;          Cy = 1 if the result can be cached
;		   Cy MUST be 0 if there is an error

IMPL_GETCD:
	ld hl,MYCURDIR
	ld bc,MAX_PATH_LEN+1
	ldir
	
	xor	a
	;scf
	ret	

MYCURDIR: ds MAX_PATH_LEN+1	
	

;Get volume label
;Input:     DE = 11 byte buffer
;Output:    A  = Error code
;           Cy = 1 if volume label can be cached
	
IMPL_GETVOL:
	ld hl,FAKEVOL
	ld bc,11
	ldir
	
	xor a
	scf
	ret
	
FAKEVOL:	db "THEVOL",0


;---------------------
;--- Gancho H_BDOS ---
;---------------------

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
DONOTHING:
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

	
;--------------------------
;--- Auxiliary routines ---
;--------------------------

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

	inc de
	inc de
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
	
	
;Get the length of a zero-terminated string
;Input:  DE = string	
;Output: BC = length
;        Cy = 1 if length > MAX_PATH_LEN
;Corrupts AF, DE

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

	
;In-place uppercase a string
;Input: DE = string
;Corrupts AF, DE

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

	
;Expand wildcards of a filename:
;* in name/extension is converted to a series of ?s
;If no extension is provided it is assumed to be .*
;If filename/extension is too long it is truncated
;
; Input: HL=source, DE=destination
; Corrupts AF, BC, HL, DE
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
	
	
;Get the last item of a path/filename string
;Input:  DE = string
;Output: HL = path to last item
;Corrupts AF, DE, B
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
	
	
;In: DE = string to process (without drive)
;    HL = destination
;Out: A = Error
;     DE points to terminator
;Changes: AF, BC, DE, HL, IX

PROCESS:
	ld	a,(de)
	or	a
	ex de,hl
	jp z,DO_GETCD2

	;ex	de,hl	;Now HL=source, DE=destination

	;Start by generating the full path

	push	de

	ld	de,PROCESS_BUF
	ld	a,(hl)
	cp	SLASH
	inc	hl
	jr	z,PROC_DOCOPY	;Absolute path? Just copy it as is
	dec	hl

	push hl
	;ex de,hl
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
	;ld de,PROCESS_BUF
		
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
	

;------------------------
;--- Buffers and data ---
;------------------------

AST_DOT_AST:	db	"/*.*"	,0

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



PARTRE2!:	;
