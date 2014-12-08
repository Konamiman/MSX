;This tool saves the LPE-Z380 memory contents to a file

;===================================

	;--- z2f: Graba un fichero desde la memoria del Z380
	;    Version 1.0, por Konami Man, 3-2000

	org	#100

;--------------
;--- Macros ---
;--------------

Z380ST:	equ	#4010
ZDIR:	equ	#4011
ZVAL:	equ	#4015
ZDIR_M:	equ	#4017
ZBLON:	equ	#4019
ZLONG:	equ	#401B
BLKDIR:	equ	#401D
BLKLON:	equ	#401F

W_BUF:	equ	#8000

; Saltos relativos condicionados

jri:	macro	@a	;A = x
	jr	z,@a
	endm

jrni:	macro	@a	;A <> x
	jr	nz,@a
	endm

jrmn:	macro	@a	;A < x
	jr	c,@a
	endm

jrmy:	macro	@a	;A > x
	jr	z,$+4
	jr	nc,@a
	endm

jrmni:	macro	@a	;A <= x
	jr	c,@a
	jr	z,@a
	endm

jrmyi:	macro	@a	;A >= x
	jr	nc,@a
	endm

; Saltos absolutos condicionados

jpi:	macro	@a	;A = x
	jp	z,@a
	endm

jpni:	macro	@a	;A <> x
	jp	nz,@a
	endm

jpmn:	macro	@a	;A < x
	jp	c,@a
	endm

jpmy:	macro	@a	;A > x
	jr	z,$+5
	jp	nc,@a
	endm

jpmni:	macro	@a	;A <= x
	jr	c,@a
	jp	z,@a
	endm

jpmyi:	macro	@a	;A >=x
	jp	nc,@a
	endm

;--------------------------------------------------------------------------
;--------------------------------------------------------------------------
;--------------------------------------------------------------------------

	;********************
	;*** PRESENTACION ***
	;********************

INIT:	ld	de,PRES_S
	ld	c,9
	call	DOSF

	ld	a,1
	ld	de,BUF
	call	EXTPAR
	jr	nc,OKPAR

NOPAR:	ld	de,USG_S
	jp	FINSTR

OKPAR:	;call    BUSZ
	;ld      a,(ISZ380)
	;or      a
	;jp      nz,OKBUSZ
	;ld      hl,#4030
	;ld      (TXDIR),hl
	call	BUSZ
	jp	OKBUSZ

PRES_S:	db	13,10,"LPE-Z380 RAM to file saver 1.01 - by Konami Man, 12-3-2000",13,10,13,10,"$"
USG_S:	db	"USAGE:   z2f <filename> <source_ad> <size>|F [H <begin_ad> [<end_ad>]]",13,10
	db	"         Source address: 8 hex digits.",13,10
	db	"         Size: 8 hex digits, or F.",13,10
	db	"               When F is specified, ZSFIZE environment item will be used",13,10
	db	"               (only when DOS 2 is present).",13,10
	db	"         H: includes BLOAD header with the specified begin address (4 hex dig).",13,10
	db	"         Header end address: 4 hex digits. By default, it is begin ad. + size",13,10
	db	"                             (&HFFFF is used if begin ad. + size > 65535).",13,10,13,10
	db	"NOTE: ZFSIZE item is created by F2Z.COM (file to Z380 RAM transfer utility).",13,10,13,10
	db	"Example: z2f c:\soft\results.dat 00200000 0001FFFF H A000 A0FF",13,10
	db	"         z2f copied.txt 00010000 f",13,10,"$"


	;*********************
	;*** BUSCA EL Z380 ***
	;*********************

BUSZ:	XOR	A
	LD	(ISZ380),A

	LD	HL,&HFCCA
	LD	B,4

ZLP2:	PUSH	BC	;Bucle slot primario
	LD	B,4

ZLP1:	PUSH	BC	;Bucle slot expandido
	PUSH	AF
	PUSH	HL

	SET	7,A	;Slot expandido
	LD	(ZSLOT),A

	LD	H,&H40	;Conecta slot
	CALL	&H24

	POP	HL	;HL = Atributos slot
	PUSH	HL

	LD	A,(HL)	;Hacer el test si tiene CALLs
	CP	&H20
	CALL	Z,ZTEST
	JP	Z,ZFND

	POP	HL
	POP	AF
	ADD	A,4	;Siguiente subslot
	AND	&H0F

	INC	HL	;Apunta a atrib. del siguiente subslot
	INC	HL
	INC	HL
	INC	HL

	POP	BC	;Siguiente subslot
	DJNZ	ZLP1

	ADD	A,1	;Siguiente slot primario
	AND	&H03
	POP	BC
	DJNZ	ZLP2

	JP	SETBAS

ZTEST:	LD	HL,(TXDIR)
	LD	DE,Z380TX
	LD	B,TXLN
ZLP:	LD	A,(DE)
	CP	(HL)
	RET	NZ
	INC	HL
	INC	DE
	DJNZ	ZLP
	CP	A
	RET
ZFND:	;==
	POP	HL
	POP	AF
	POP	BC
	POP	BC
	LD	A,255
	LD	(ISZ380),A
	;COMPRUEBA SI EL SLOT ES EXPANDIDO O NO
	LD	A,(ZSLOT)
	LD	C,A
	AND	&B00001100
	RRCA
	RRCA
	LD	E,A
	LD	D,0
	LD	HL,&HFCC1
	ADD	HL,DE
	BIT	7,(HL)
	JR	NZ,SIEXP
	LD	A,C
	AND	&B00000011	;NO ES EXPANDIDO, LUEGO QUITA BITS SOBRANTES
	LD	(ZSLOT),A
SIEXP:	;
SETBAS:	;
SETZSLOT:	LD	A,(ZSLOT)	;Conecta Z380
	LD	H,&H40
	CALL	&H24
	RET
;
ISZ380:	DB	0	;0=Z380 NO ENCONTRADO, 255=Z380 ENCONTRADO
ZSLOT:	DB	0	;SUBSLOT/SLOT DONDE SE ENCONTRO EL Z380
TXDIR:	dw	&H4030	;DIRECCION DONDE SE BUSCA EL TEXTO
Z380TX:	DB	"LPE-Z380"	;TEXTO A BUSCAR
TXLN:	EQU	8	;LONGITUD DEL TEXTO A BUSCAR


	;--- Si no hay Z380, error

OKBUSZ:	ld	a,(ISZ380)
	or	a
	jr	nz,OKBUSZ2

	ld	de,NOZ_S
	jp	FINSTR

NOZ_S:	db	"ERROR: LPE-Z380 not found.",13,10,"$"
SIZ_S:	db	"LPE-Z380 found.",13,10,"$"

OKBUSZ2:	ld	de,SIZ_S
	ld	c,9
	call	DOSF


	;***************************************
	;*** ESPERA A QUE EL Z380 ESTE LISTO ***
	;***************************************

	ld	a,(Z380ST)
	or	a
	jp	z,OKFREE

	ld	de,WAIT_S
	ld	c,9
	call	DOSF

WAFREE:	ld	c,#B	;Console status
	call	5
	or	a
	ld	de,ABORT_S
	jp	nz,ABORT

	call	SETZSLOT

	ld	a,(Z380ST)
	or	a
	jr	nz,WAFREE
	jr	OKFREE

WAIT_S:	db	"Waiting for Z380 to be free... (press any key to abort)",13,10,"$"
OKFREE:	;


	;*******************************************
	;*** EXTRAE NOMBRE DE FICHERO, Y LO CREA ***
	;*******************************************

	ld	a,1
	ld	de,BUF
	call	EXTPAR

	ld	de,BUF	;Crea fichero
	call	CREATE
	or	a
	jr	nz,ERRFCR

	ld	de,BUF	;Lo abre
	call	OPEN
	or	a
	jr	z,OKFCREA

ERRFCR:	ld	de,ERRFIL_S
	jp	FINSTR

ERRFIL_S:	db	"ERROR when creating file.",13,10,"$"

OKFCREA:	ld	a,b
	ld	(FH),a


	;*****************************************
	;*** EXTRAE EL RESTO DE LOS PARAMETROS ***
	;*****************************************

	;--- Direccion inicial

	ld	a,2
	ld	de,BUF
	call	EXTPAR
	jr	c,FININVP

	ld	ix,BUF
	call	EXTDIR
	ld	(DIR_INI),de
	ld	(DIR_INI+2),hl
	or	a
	jr	z,OKPAR1

FININVP:	ld	de,INVP_S
	jp	FINSTR

INVP_S:	db	"ERROR: Invalid parameters.",13,10,"$"
OKPAR1:	;

	;--- Longitud

	ld	a,3
	ld	de,BUF
	call	EXTPAR
	jr	c,FININVP

	call	CHKDOS2
	jr	c,NOCHKF

CHKF:	ld	a,(BUF)	;Bajo DOS 2, miramos si es F
	and	%11011111
	cp	"F"
	jr	nz,NOCHKF

GETITEM:	ld	hl,VARNAME_S
	ld	de,BUF
	ld	bc,#FF6B	;Get env. item
	call	DOSF
	;ld      a,(BUF)
	;or      a
	;jr      z,INVITERR

	ld	ix,BUF	;DOS 1 o no es F: extraemos numero
	call	EXTDIR
	or	a
	jr	z,OKPAR2

INVITERR:	ld	de,INVIT_S
	jp	FINSTR
INVIT_S:	db	"ERROR: Environment item ZFSIZE is invalid or undefined.",13,10,"$"
VARNAME_S:	db	"ZFSIZE",0

NOCHKF:	ld	ix,BUF	;DOS 1 o no es F: extraemos numero
	call	EXTDIR
	or	a
	jp	nz,FININVP

OKPAR2:	ld	(SIZE),de
	ld	(SIZE+2),hl

	;--- H

	ld	a,4	;Si no hay mas parametros, no se
	ld	de,BUF	;crea cabecera BLOAD
	call	EXTPAR
	jp	c,OKALLPARS

	ld	a,#FE
	ld	(HAYHEAD),a

	ld	a,(BUF)	;Error si el cuarto parametro no es H
	and	%11011111
	cp	"H"
	jp	nz,FININVP

	;--- Dir. inicial cabecera

	ld	a,5
	ld	de,BUF
	call	EXTPAR
	jp	c,FININVP

	ld	ix,BUF
	call	EXTDIR2
	or	a
	jp	nz,FININVP

	ld	(H_INI),de
	ld	(H_EXE),de	;Ejecucion=inicio

	;--- Dir. final cabecera

	ld	a,6	;Si hay dir. final, se extrae
	ld	de,BUF
	call	EXTPAR
	jr	c,CALCHFIN

	ld	ix,BUF
	call	EXTDIR2
	or	a
	jp	nz,FININVP
	ld	(H_FIN),de
	jr	OKALLPARS

CALCHFIN:	ld	hl,(SIZE+2)	;Si no hay dir. final, se calcula
	ld	a,h
	or	l
	jr	nz,FIN_FFFF	;Si tamanyio > 64K, dir. fin. = #FFFF

	ld	hl,(SIZE)	;Si tamanyio + dir. inicial > 64k, idem
	ld	de,(H_INI)
	add	hl,de
	jr	c,FIN_FFFF

	ld	(H_FIN),hl	;Si no, fin = inicio + tamanyio
FIN_FFFF:	;
OKALLPARS:	;


	;************************************************
	;***  ESTABLECE AREA DE TRANSFERENCIA MAXIMA  ***
	;************************************************

	ld	hl,0
	ld	(ZDIR_M),hl
	ld	a,8
	ld	(Z380ST),a


	;**************************************************************
	;*** LEE RAM Z380 Y TRANSFIERE AL FICHERO EN BLOQUES DE 16K ***
	;**************************************************************

	ld	de,TRANS_S
	ld	c,9
	call	DOSF
	jr	TRNS
TRANS_S:	db	"Transferring data...",13,10,"$"
TRNS:	;

	;--- Hay cabecera? Escribirla en el fichero

	ld	a,(HAYHEAD)
	or	a
	jr	z,NOSAVEH

	ld	de,HAYHEAD
	ld	a,(FH)
	ld	b,a
	ld	hl,7
	call	WRITE
	and	#FE	;or      a
	jp	nz,WRERR
NOSAVEH:	;

	;--- Bucle de trasnferencia

	ld	hl,DIR_INI	;Dir. inicial a biport
	ld	de,ZDIR
	ld	bc,4
	ldir

W_LOOP:	ld	hl,#4000	;Queda mas de 16K por transferir?
	push	hl
	ld	hl,(SIZE)
	ld	de,(SIZE+2)
	ld	a,d
	or	e
	jr	nz,BIGSIZE

	ld	a,h
	and	%11000000
	jr	nz,BIGSIZE

	ex	(sp),hl
BIGSIZE:	pop	hl	;Long. a transf. = 16K o lo que quede
	ld	(TMPSIZE),hl

	ld	(ZLONG),hl	;Long. transf. a biport
	ld	de,W_BUF
	ld	(ZDIR_M),de

	call	DO_GET	;Cogemos datos

	ld	a,(FH)
	ld	b,a	;Escribimos en el fichero
	ld	de,W_BUF
	ld	hl,(TMPSIZE)
	call	WRITE
	and	#FE	;or            a (Salta error 1)
	jp	nz,WRERR

	ld	hl,(TMPSIZE)	;Si hemos transferido menos de 16K,
	ld	a,h	;ye hemos acabado
	cp	#40
	jp	nz,TODOFIN

	ld	hl,(SIZE)
	ld	de,#4000	;Restamos 16K al tamanyio total
	or	a
	sbc	hl,de
	ld	(SIZE),hl
	ld	hl,(SIZE+2)
	ld	de,0
	sbc	hl,de
	ld	(SIZE+2),hl

	ld	hl,(DIR_INI)	;Sumamos 16K a la dir. inicial Z380
	ld	de,#4000
	add	hl,de
	ld	(ZDIR),hl
	ld	(DIR_INI),hl
	ld	hl,(DIR_INI+2)
	ld	de,0
	adc	hl,de
	ld	(ZDIR+2),hl
	ld	(DIR_INI+2),hl

	jr	W_LOOP	;Repetimos


	;*************************************
	;*** FIN: CIERRA FICHERO Y TERMINA ***
	;*************************************

TODOFIN:	ld	de,DONE_S

FINSTR:	ld	c,9
	call	DOSF

	ld	a,(FH)	;Cerramos fichero si hemos llegado a
	cp	255	;abrirlo
	ld	b,a
	call	nz,CLOSE

	ld	a,(#F342)	;Restauramos RAM en pagina 1
	ld	h,#40
	call	#24

	ld	c,0	;FIN
	jp	5

ABORT:	push	de
	ld	c,8	;Get abort character
	call	5
	pop	de
	jr	FINSTR

DOSF:	call	5
	push	af,bc,de,hl
	call	SETZSLOT
	pop	hl,de,bc,af
	ret

DONE_S:	db	"Done.",13,10,"$"
ABORT_S:	db	"Aborted! Data not transferred.",13,10,"$"


;--------------------------------------------------------------------------
;--------------------------------------------------------------------------
;--------------------------------------------------------------------------

	;--- RUTINAS PARA MANEJAR FICHEROS
	;    Compatibles DOS 1 y DOS 2
	;    Por Konami Man, 3-97


;-----===== MACROS Y CONSTANTES =====-----

;--- Parametros definibles por el usuario

;La constante DOS indica la version de sistema operativo soportada:

;DOS=1 -> Funcionamiento en DOS 1 y DOS 2, pero usando metodos de DOS 1 (FCBs).
;         No soporta subdirectorios, atributos ni otras caracteristicas DOS 2.
;         Longitud de las rutinas:  985 + 38 * MAXFILES bytes
;DOS=2 -> Funcionamiento solo en DOS 2.
;         Longitud de las rutinas:  375 bytes
;DOS=12-> Funcionamiento en DOS 1 y DOS 2, usando los metodos propios de cada
;         sistema operativo. Es la opcion mas eficiente.
;         Longitud de las rutinas: 1292 + 38 * MAXFILES bytes

DOS:	equ	12

;La constante MAXFILES indica el numero maximo de ficheros abiertos
;simultaneamente, asi como el tamanyo de la zona de FCBS (38 * MAXFILES).
;La zona de FCBS no es necesaria en DOS 2.

MAXFILES:	equ	1

;La constante DOSENTRY ha de valer #0005 si se van a usar las rutinas desde
;MSX-DOS, y #F37D si se van a usar desde MSX Disk BASIC.

DOSENTRY:	equ	DOSF	;#0005

;PREUBAS=1 hara que se ensamblen las rutinas de prueba.

PREUBAS:	equ	0

;START es la direccion de inicio de las rutinas.
;Si no van a ser ensambladas por separado, poner START=0
;y la directiva ORG sera ignorada.

START:	equ	0

;--- Funciones del DOS

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

;--- Otras constantes

ENYEMAY:	equ	165
ENYEMIN:	equ	164
LONBUF:	equ	70	;Longitud del bufer generico (minimo 69)

;--- Macros

doscall:	macro	@function
	ld	c,@function
	call	DOSENTRY
	endm

;--- Inicio

	if	START<>0
	org	START
	endif

	if	PREUBAS=1
	ld	sp,#D500
	jp	PREUBA9	;Cambiar por la prueba deseada
	endif

;-----===== VARIABLES Y ZONAS DE DATOS =====-----

NUMFILES:	db	0	;Numero de ficheros abiertos 
BUFFER:	ds	LONBUF	;Bufer generico para las rutinas

;ESPACIO PARA FCBs. Cada fichero abierto necesita 37 bytes para el FCB.
;Ademas se usa uno mas para indicar si cada FCB esta en uso.
;Este espacio no es necesario en DOS 2.

	if	DOS<>2

FCBS:	ds	38*MAXFILES

	endif


;-----===== DIRECTORIO DE RUTINAS =====-----

;--- Rutinas auxiliares

;CLBUF:     Limpia el bufer generico
;MIN2MAY:   Convierte un caracter a mayuscula
;CHKDOS2:   Comprueba la version del DOS
;CONVNAME:  Convierte un nombre de fichero de/a formato FCB

;--- Rutinas de usuario

;DIR:       Busca un fichero y muestra informacion sobre el mismo
;REN:       Renombra un fichero
;CREATE:    Crea un fichero
;DEL:       Borra un fichero
;OPEN:      Abre un fichero
;CLOSE:     Cierra un fichero abierto
;READ:      Lee de un fichero abierto
;WRITE:     Escribe en un fichero abierto
;SEEK:      Mueve el puntero de un fichero abierto


;-----===== RUTINAS DE PRUEBA =====-----

	if	PREUBAS=1

PREUBA:	ld	sp,#d500	;Prueba de conversion de nombre
	ld	hl,PBA
	ld	de,#1000
	;scf
	or	a
	;call    CONVNAME
	nop
	nop
;PBA:       db      2,"MAGOMUCHOCG"
PBA:	db	"d:RaMoN.rIbAs",0

PREUBA2:	ld	de,PBA2	;Prueba de busqueda de ficheros
	ld	ix,#1000
	ld	a,0
BUCPBA:	call	DIR
	ld	a,1
	jp	BUCPBA

PBA2:	db	"*.asc",0

PREUBA3:	ld	de,PBA3	;Prueba de renombrado de ficheros
	ld	hl,PBA4
	call	REN
	nop
	nop
	nop

PBA3:	db	"file.uno",0
PBA4:	db	"file!.dos",0

PREUBA4:	ld	de,PBA5	;Prueba de borrado de ficheros
	call	DEL
	nop
	nop

PBA5:	db	"pabor.rar",0

PREUBA5:	ld	de,PBA6
	call	CREATE
	nop
	nop

PBA6:	db	"cread.me!",0

PREUBA6:	ld	de,PBA10	;Prueba de apertura y cerradura
	call	OPEN	;Debe devolver A<>0 (no existe)
	ld	de,PBA7
	call	OPEN	;Debe devolver A=0, B=1
	ld	de,PBA8
	call	OPEN	;Debe devolver A=0, B=2
	ld	de,PBA9
	call	OPEN	;Debe devolver A=0, B=3
	ld	de,PBA8
	call	OPEN	;Debe devolver A=1 (MAXFILES=3)

	ld	b,0
	call	CLOSE	;Debe devolver A=1
	ld	b,4
	call	CLOSE	;Debe devolver A=1
	ld	b,3
	call	CLOSE	;Debe devolver A=0
	ld	b,3
	call	CLOSE	;Debe devolver A=2
	ld	de,PBA8
	call	OPEN	;Debe devolver A=0, B=1
	nop
	nop

PBA7:	db	"file.uno",0
PBA8:	db	"file!.dos",0
PBA9:	db	"file!!.tre",0
PBA10:	db	"noexis.te",0

PREUBA7:	ld	de,PBA7	;Prueba de lectura de un fichero
	call	OPEN
	ld	hl,5
	ld	de,#1000
	call	READ
	ld	hl,9
	ld	de,#1100
	call	READ
	ld	hl,200
	ld	de,#1200
	call	READ

	call	CLOSE
	nop
	nop

PREUBA8:	ld	de,PBA8	;Prueba de escritura en un fichero
	call	OPEN
	ld	hl,10
	ld	de,PBA11
	call	WRITE
	call	CLOSE
	nop
	nop

PBA11:	db	"34 veces!!!!!"

PREUBA9:	ld	de,PBA7
	call	OPEN
	ld	de,0
	ld	hl,10	;Desplazamiento de 10
	ld	a,1
	call	SEEK
	ld	de,#1000
	ld	hl,20
	call	READ
	ld	de,#FFFF
	ld	hl,#FFFB	;Desplazamiento de -5
	ld	a,1
	call	SEEK
	ld	de,#1100
	ld	hl,20
	call	READ
	ld	de,#FFFF
	ld	hl,#FFF0	;Desplazamiento de -16 respecto al final
	ld	a,2
	call	SEEK
	ld	de,#1200
	ld	hl,20
	call	READ
	call	CLOSE
	nop
	nop

	endif


;-----===== RUTINAS AUXILIARES =====-----

;--- NOMBRE: CLBUF
;      Limpia el buffer generico
;    ENTRADA:   -
;    SALIDA:    -
;    REGISTROS: -
;    LLAMADAS:  -
;    VARIABLES: BUFFER, LONBUF

CLBUF:	push	hl,de,bc
	ld	hl,BUFFER
	ld	de,BUFFER+1
	ld	bc,LONBUF-1
	ld	(hl),0
	ldir
	pop	bc,de,hl
	ret


;--- NOMBRE: MIN2MAY
;      Convierte un caracter a mayuscula
;    ENTRADA:   A = Caracter
;    SALIDA:    A = Caracter en mayuscula si era minuscula,
;                   inalterado si no
;    REGISTROS: F
;    LLAMADAS:  -
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

;--- NOMBRE: CHKDOS2
;      Obtiene la version de MSX-DOS
;    ENTRADA:   -
;    SALIDA:    Cy = 1 -> MSX-DOS 1.x o MSX-DOS 2.1x
;               Cy = 0 -> MSX-DOS 2.20 o superior
;    REGISTROS: F
;    LLAMADAS:  -
;    VARIABLES: -

CHKDOS2:	ld	(ATEMP),a
	ld	a,(DV)	;Si DV=0, aun no se ha comprobado
	cp	2	;la version del DOS.
	jp	z,CD2END2	;Si DV=1 -> DOS 1 o DOS 2.1
	or	a	;Si DV=2 -> DOS 2.20 o superior
	scf
	jp	nz,CD2END2

	push	bc,de,hl	;Comprueba la version del DOS
	doscall	_DOSVER	;y establece DV.
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

;--- NOMBRE: CONVNAME
;      Convierte un nombre de fichero de/a formato FCB
;      NO comprueba caracteres invalidos en el nombre del fichero
;    ENTRADA:    HL = Cadena de origen
;                     Formato FCB:    12 caracteres, sin punto
;                                     (los sobrantes se rellenan con espacios)
;                                     El primero es la unidad
;                                     (0: defecto, 1: A, 2: B, etc)
;                     Formato normal: Acabada en 0, maximo 14 caracteres
;                                     Comienza con la unidad y ":"
;                                     si no es la idem por defecto (la 0)
;                DE = Cadena de destino (idem)
;                Cy = 0 -> Formato normal a FCB
;                Cy = 1 -> Formato FCB a normal
;     SALIDA:    B  = Longitud de la cadena de destino
;                     Formato FCB: siempre 12
;                     Formato normal: no incluye el 0 final
;     REGISTROS: AF, C
;     LLAMADAS:  MIN2MAY
;     VARIABLES: -

CONVNAME:	push	de,hl
	jp	c,FCB2NOR
	xor	a
	ld	(EXTFLG),a
	jp	NOR2FCB
ENDCONV:	pop	hl,de
	ret

;--- Conversion nombre normal a nombre FCB

NOR2FCB:	push	de,hl,de	;Rellena de espacios la zona del nombre
	pop	hl
	inc	de
	ld	a," "
	ld	(hl),a
	ld	bc,11
	ldir
	pop	hl,de
	xor	a
	ld	(de),a	;Pone a 0 la unidad

	inc	hl	;Comprueba si se ha especificado unidad.
	ld	a,(hl)	;Si es asi, la convierte al numero
	cp	":"	;de unidad correspondiente.
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
	xor	a	;Bucle para el nombre
	ld	(EXTFLG),a
	ld	b,8
	call	N2FBUC

	ld	a,(EXTFLG)	;Si se ha llegado al final, no procesa
	or	a	;la extension
	jp	nz,ENDCONV
	ld	a,#FF
	ld	(EXTFLG),a
	ld	b,3	;Bucle para la extension
	call	N2FBUC
	ld	b,12
	jp	ENDCONV
;                                   ;Pasa sin convertir los 8 o 3 primeros
N2FBUC:	ld	a,(hl)	;caracteres, a no ser que encuentre
	inc	hl
	cp	"*"	;un 0 (fin de cadena),
	jp	z,AFND1	;un punto (fin de nombre),
	cp	"."	;o un asterisco (que convierte en "?")
	jp	z,PFND1
	or	a
	jp	z,EFND1
	call	MIN2MAY
	ld	(de),a
	inc	de
	djnz	N2FBUC

PASASOB:	ld	a,(EXTFLG)	;Si es la extension no hay nada que pasar
	or	a
	ret	nz

	ld	a,(hl)	;Pasa caracteres sobrantes (mas alla de 8
	inc	hl	;o 3) en el nombre del fichero
	or	a
	jp	z,EFND1
	cp	"."
	jp	nz,PASASOB
	ret

AFND1:	ld	a,"?"	;Rellena de "?" hasta completar
AFND11:	ld	(DE),a	;8 o 3 caracteres
	inc	DE
	djnz	AFND11
	jp	PASASOB

PFND1:	ld	a,(EXTFLG)
	or	a
	jp	nz,EFND1
	ld	a,b
	cp	8	;Si el punto esta al principio,
	dec	hl
	jp	z,AFND1	;interpreta "*.<ext>"
	inc	hl
	ld	a," "	;Rellena de " " hasta completar
PFND11:	ld	(DE),a	;8 o 3 caracteres
	inc	de
	djnz	PFND11
	ret

EFND1:	ld	a,1
	ld	(EXTFLG),a
	ret

EXTFLG:	db	0	;#FF cuando se procesa la extension, 
;                                   ;1 cuando se ha llegado al final

;--- Conversion nombre FCB a nombre normal

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
	ld	b,8	;Vamos copiando el nombre tal cual
F2NBUC:	ld	a,(hl)	;hasta que pasamos ocho caracteres
	inc	hl	;o encontramos un espacio...
	cp	" "
	jp	z,SPFND
	ld	(de),a
	inc	de
	djnz	F2NBUC
	ld	a,"."
	ld	(de),a
	inc	de
	jp	F2NEXT

SPFND:	ld	a,"."	;...entonces ponemos el punto,
	ld	(de),a	;y pasamos los espacios sobrantes
	inc	de	;hasta llegar a la extension.
SFBUC:	ld	a,(hl)
	inc	hl
	djnz	SFBUC
	dec	hl

F2NEXT:	ld	b,3	;Copiamos la extension hasta haber
F2NEX2:	ld	a,(hl)	;copiado tres caracteres,
	inc	hl	;o hasta encontrar un espacio.
	cp	" "
	jp	z,F2NEND
	ld	(de),a
	inc	de
	djnz	F2NEX2

F2NEND:	dec	de	;Si no hay extension, suprimimos el punto.
	ld	a,(de)
	cp	"."
	jp	z,NOPUN
	inc	de
NOPUN:	xor	a
	ld	(de),a

	ex	de,hl	;Obtencion de la longitud de la cadena.
	pop	de
	or	a
	sbc	hl,de
	ld	b,l
	jp	ENDCONV

	endif


;-----===== RUTINAS DE USUARIO =====-----

;--- NOMBRE: DIR
;      Busca un fichero
;      Siempre se debe ejecutar primero con A=0
;      Para buscar los siguientes, el bufer generico no debe ser modificado
;    ENTRADA:    DE = Nombre del fichero (puede contener comodines), con fin 0
;                IX = Puntero a una zona vacia de 26 bytes
;                B  = Atributos de busqueda (ignorado si DOS 1)
;                A  = 0 -> Buscar primero
;                A  = 1 -> Buscar siguientes
;    SALIDA:     A  = 0 -> Fichero encontrado
;                A <> 0 -> Fichero no encontrado
;                IX+0          -> #FF (fanzine propio del DOS 2)
;                IX+1  a IX+13 -> Nombre del fichero
;                IX+14         -> Byte de atributos
;                IX+15 y IX+16 -> Hora de modificacion
;                IX+17 y IX+18 -> Fecha de modificacion
;                IX+19 y IX+20 -> Cluster inicial
;                IX+21 a IX+24 -> Longitud del fichero
;                IX+25         -> Unidad logica
;     REGISTROS: F
;     LLAMADAS:  CONVNAME, CHKDOS2
;     VARIABLES: BUFFER, DOSENTRY, doscall, _SETDTA, _SFIND, _SNEXT,
;                _FFIND, _FNEXT

OFBUF1:	equ	38

DIR:	if	DOS=12

	call	CHKDOS2
	jp	nc,DIR2

	endif

	;--- DIR: Version DOS 1

	if	DOS<>2

DIR1:	push	bc,de,hl,iy,ix,af
	call	CLBUF
	ex	de,hl
	ld	de,BUFFER	;Pasamos el nombre normal de (DE)
	or	a	;a nombre FCB en BUFFER.
	call	CONVNAME

	ld	de,BUFFER+OFBUF1	;Ponemos el area de transferencia
	doscall	_SETDTA	;en el buffer, tras el FCB del fichero
;                                   ;a buscar.
	ld	de,BUFFER
	pop	af
	and	1
	ld	c,_SFIRST
	add	c
	ld	c,a
	call	DOSENTRY
	or	a	;Terminamos con A=#FF si no se encuentra.
	jp	nz,ENDFF1

	ld	a,(BUFFER+OFBUF1)	;Guardamos la unidad del FCB
	ld	(ULO1),a	;en ULO1, y la ponemos a 0
	xor	a	;para poder convertirla a nombre normal
	ld	(BUFFER+OFBUF1),a	;sin unidad.
	ld	iy,BUFFER+OFBUF1

	push	iy
	pop	hl	;HL = Entrada de directorio del fichero
	pop	de	;(comenzando con la unidad a 0 y el nombre).
	push	de	;DE = IX de la entrada (buffer del usuario).
	ld	a,#FF
	ld	(de),a	;Primer byte a #FF para igualarlo al DOS 2.
	inc	de
	scf		;Copiamos nombre en formato normal
	call	CONVNAME	;al buffer del usuario.

	pop	ix	;IX = buffer de usuario.
	ld	a,(iy+12)	;Copiamos byte de atributos.
	ld	(ix+14),a

	push	iy
	pop	hl
	ld	bc,23	;HL = Entrada de directorio apuntando a
	add	hl,bc	;la hora de creacion.

	push	ix
	pop	de
	ld	bc,15	;DE = Buffer del usuario apuntando a
	ex	de,hl	;la posicion +15.
	add	hl,bc
	ex	de,hl

	ld	bc,10	;Copiamos fecha,hora,cluster inicial
	ldir		;y longitud a la vez.

	ld	a,(ULO1)	;Copiamos unidad logica.
	ld	(ix+25),a

	xor	a	;Terminamos sin error.
	push	ix
ENDFF1:	pop	ix,iy,hl,de,bc
	ret

ULO1:	db	0

	endif

	;--- DIR: Version DOS 2

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


;--- NOMBRE: REN
;      Renombra un fichero
;    ENTRADA:   DE = Nombre del fichero
;               HL = Nuevo nombre del fichero (puede contener comodines)
;    SALIDA:    A  = 0 -> Fichero renombrado
;               A <> 0 -> Error
;    REGISTROS: F
;    LLAMADAS:  CHKDOS2, CONVNAME
;    VARIABLES: BUFFER, _FREN, _RENAME, DOSENTRY, doscall

REN:	if	DOS=12

	call	CHKDOS2
	jp	nc,REN2

	endif

	;--- REN: Version DOS 1 

	if	DOS<>2

REN1:	push	bc,de,hl,ix,iy
	call	CLBUF

	push	hl
	ex	de,hl	;HL = Nombre antiguo 
	ld	de,BUFFER
	or	a
	call	CONVNAME

	pop	hl	;HL = Nombre nuevo 
	ld	de,BUFFER+16
	or	a
	call	CONVNAME
	ld	de,BUFFER

	doscall	_FREN
	pop	iy,ix,hl,de,bc
	ret

	endif


;--- NOMBRE: CREATE
;      Crea un fichero pero NO lo deja abierto
;      !CUIDADU! Si ya existe ese fichero, lo borra y crea uno nuevo
;    ENTRADA:   DE = Nombre del fichero
;    SALIDA:    A  = 0 -> Fichero creado
;               A <> 0 -> Error
;    REGISTROS: F
;    LLAMADAS:  CONVNAME, CHKDOS2
;    VARIABLES: doscall, _FMAKE, _FCLOSE, _CREATE, _CLOSE, BUFFER

CREATE:	if	DOS=12

	call	CHKDOS2
	jp	nc,CREA2

	endif

	;--- CREATE: Version DOS 1

	if	DOS<>2

CREA1:	push	bc,de,hl,ix,iy
	call	CLBUF
	ex	de,hl	;HL = Nombre del fichero 
	ld	de,BUFFER
	or	a
	call	CONVNAME
	ex	de,hl
	ld	de,BUFFER
	push	de
	doscall	_FMAKE	;Crea el fichero y lo cierra
	pop	de
	or	a
	jp	nz,CR1END
	doscall	_FCLOSE
	xor	a
CR1END:	pop	iy,ix,hl,de,bc
	ret

	endif

	;--- CREATE: Version DOS 2

	if	DOS<>1

CREA2:	push	bc,de,hl
	xor	a
	ld	b,0	;Si el fichero ya existe, lo borra.
	doscall	_CREATE	;Crea el fichero y lo cierra
	or	a	;si no hay error.
	jp	nz,CR2END
	doscall	_CLOSE
	xor	a
CR2END:	pop	hl,de,bc
	ret

	endif

	;--- REN: Version DOS 2

	if	DOS<>1

REN2:	push	hl,de,bc
	doscall	_RENAME
	pop	bc,de,hl
	ret

	endif


;--- NOMBRE: DEL
;      Borra un fichero
;      EL FICHERO NO DEBE ESTAR ABIERTO
;    ENTRADA:   DE = Nombre del fichero
;    SALIDA:    A  = 0 -> Fichero borrado
;               A <> 0 -> Error
;    REGISTROS: F
;    LLAMADAS:  CONVNAME, CHKDOS2
;    VARIABLES: doscall, _FDEL, _DELETE, BUFFER

DEL:	if	DOS=12

	call	CHKDOS2
	jp	nc,DEL2

	endif

	;--- DEL: Version DOS 1

	if	DOS<>2

DEL1:	push	bc,de,hl,ix,iy
	call	CLBUF
	ex	de,hl	;HL = Nombre del fichero
	ld	de,BUFFER
	or	a
	call	CONVNAME
	ex	de,hl
	ld	de,BUFFER
	doscall	_FDEL
	pop	iy,ix,hl,de,bc
	ret

	endif

	;--- DEL: Version DOS 2

	if	DOS<>1

DEL2:	push	bc,de,hl
	doscall	_DELETE
	pop	hl,de,bc
	ret

	endif


;--- NOMBRE: OPEN
;      Abre un fichero
;    ENTRADA:   DE = Fichero a abrir
;    SALIDA:    A  = 0 -> Error
;               A <> 0 -> Error
;                         DOS 1: A=1 -> demasiados ficheros abiertos
;               B  = Numero asociado al fichero
;                    (no tiene nada que ver con el numero de ficheros abiertos)
;    REGISTROS: F, C
;    LLAMADAS:  CHKDOS2, CONVNAME
;    VARIABLES: DOS, doscall, NUMFILES, MAXFILES, _FOPEN, _OPEN, FCBS

OPEN:	if	DOS=12

	call	CHKDOS2
	jp	nc,OPEN2

	endif

	;--- OPEN: Version DOS 1

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
OP1BUC1:	ld	a,(hl)	;Buscamos, en todos los FCBs,
	or	a	;alguno que este libre.
	jp	z,FCBFND
	add	hl,de
	djnz	OP1BUC1
	ld	a,1
	jp	OP1END

FCBFND:	push	hl	;Limpiamos FCB
	pop	de
	push	de
	inc	de
	ld	bc,37
	ld	(hl),0
	ldir

	pop	de
	inc	de
	pop	hl	;Pasamos el nombre del fichero al FCB
	or	a
	call	CONVNAME

	push	de
	doscall	_FOPEN
	pop	ix
	or	a	;Terminamos si hay error
	jp	nz,OP1END

	ld	a,1
	ld	(ix+14),a	;Ponemos a 1 "record size"
	xor	a
	ld	(ix+15),a
	ld	(ix+33),a	;Ponemos a 0 "random record"
	ld	(ix+34),a
	ld	(ix+35),a
	ld	(ix+36),a

	ld	a,#FF	;Marcamos el FCB como usado
	ld	(ix-1),a

	ld	a,(NUMFILES)	;Incrementamos el numero
	inc	a	;de ficheros abiertos y
	ld	(NUMFILES),a	;devolvemos en A el numero de este
	ld	b,a
	xor	a

OP1END:	pop	iy,ix,de,hl
	ret

	endif

	;--- OPEN: Version DOS 2

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


;--- NOMBRE: CLOSE
;      Cierra un fichero
;    ENTRADA:   B  = Numero de fichero
;    SALIDA:    A  = 0 -> Fichero cerrado
;               A <> 0 -> Error
;    REGISTROS: F
;    LLAMADAS:  CHKDOS2
;    VARIABLES: BUFFER, FCBS, doscall, DOS, MAXFILES, NUMFILES, _FCLOSE, _CLOSE

CLOSE:	if	DOS=12

	call	CHKDOS2
	jp	nc,CLOSE2

	endif

	;--- CLOSE: Version DOS 1

	if	DOS<>2

CLOSE1:	ld	a,b	;Error si B>MAXFILES
	cp	MAXFILES+1	;o B=0.
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
CL1BUC1:	add	hl,de	;HL = Zona en FCBS del fichero B
	djnz	CL1BUC1

	ld	a,(hl)	;Error si el fichero no esta abierto
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
	xor	a	;Marcamos el FCB como libre
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


;--- NOMBRE: READ
;      Lee de un fichero abierto
;    ENTRADA:   B  = Numero de fichero
;               DE = Direccion del bufer
;               HL = Numero de bytes a leer
;    SALIDA:    A  = 0 -> No hay error
;               A <> 0 -> Error
;                         Se considera error no haber podido leer
;                         todos los bytes requeridos, es decir,
;                         HL a la entrada <> HL a la salida.
;                         Este error tiene el codigo A=1
;                         tanto en DOS 1 como en DOS 2.
;               HL = Numero de bytes leidos
;    REGISTROS: F
;    LLAMADAS:  CHKDOS2, RW1, RW2
;    VARIABLES: BUFFER, FCBS, DOESNTRY, DOS, MAXFILES, NUMFILES, _RDBLK,
;               _READ, _SETDTA, RWCODE

READ:	if	DOS=12

	call	CHKDOS2
	jp	nc,READ2

	endif

	;--- READ: Version DOS 1 

	if	DOS<>2

READ1:	ld	a,_RDBLK
	ld	(RWCODE),a
	jp	RW1

	endif

	;--- READ: Version DOS 2 

	if	DOS<>1

READ2:	ld	a,_READ
	ld	(RWCODE),a
	jp	RW2

	endif


;--- NOMBRE: WRITE
;      Escribe en un fichero abierto
;    ENTRADA:   B  = Numero de fichero
;               DE = Direccion del bufer
;               HL = Numero de bytes a escribir
;    SALIDA:    A  = 0 -> No hay error
;               A <> 0 -> Error
;                         Se considera error no haber podido escribir
;                         todos los bytes requeridos, es decir,
;                         HL a la entrada <> HL a la salida.
;                         Este error tiene el codigo A=1
;                         tanto en DOS 1 como en DOS 2.
;               HL = Numero de bytes escritos
;    REGISTROS: F
;    LLAMADAS:  CHKDOS2, RW1, RW2
;    VARIABLES: BUFFER, FCBS, DOSENTRY, DOS, MAXFILES, NUMFILES, _WRBLK,
;               _WRITE, _SETDTA, RWCODE

WRITE:	if	DOS=12

	call	CHKDOS2
	jp	nc,WRITE2

	endif

	;--- WRITE: Version DOS 1

	if	DOS<>2

WRITE1:	ld	a,_WRBLK
	ld	(RWCODE),a
	jp	RW1

	endif

	;--- WRITE: Version DOS 2

	if	DOS<>1

WRITE2:	ld	a,_WRITE
	ld	(RWCODE),a
	jp	RW2

	endif


;--- RW: Rutina generica de lectura/escritura

	;--- RW: Version DOS 1

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
RW1BUC1:	add	hl,de	;HL = Zona en FCBS del fichero B
	djnz	RW1BUC1
	ld	a,(hl)	;A = Identificador de fichero abierto
	ex	(sp),hl
	push	hl

	or	a	;Error si el fichero no esta abierto
	ld	a,2
	jp	z,ENDRW11

	pop	de
	doscall	_SETDTA
	pop	de,hl
	inc	de
	ld	a,(RWCODE)	;Leemos el codigo de lectura o escritura
	ld	c,a
	call	DOSENTRY	;y ejecutamos la llamada

ENDRW1:	pop	iy,ix,de,bc
	ret
ENDRW11:	pop	bc,bc,bc
	jp	ENDRW1

	endif

	;--- RW: Version DOS 2

	if	DOS<>1

RW2:	push	bc,de,hl
	ld	a,(RWCODE)	;Leemos el codigo de lectura o escritura
	ld	c,a
	call	DOSENTRY
	pop	de
	or	a
	jp	nz,ENDRW2
	push	hl

	sbc	hl,de	;HL = bytes leidos, DE = bytes requeridos
	ld	a,h	;Si HL=DE, no hay error
	or	l	;Si HL<>DE, error 1
	ld	a,0
	pop	hl
	jp	z,ENDRW2
	ld	a,1

ENDRW2:	pop	de,bc
	ret

	endif

RWCODE:	db	0	;Codigo de la funcion de lectura/escritura


;--- NOMBRE: SEEK
;      Mueve el puntero de un fichero
;      La primera posicion es la 0
;    ENTRADA:   B  = Numero de fichero
;               A  = Metodo de desplazamiento:
;                    A = 0 -> Relativo al principio del fichero
;                    A = 1 -> Relativo a la posicion actual
;                    A = 2 -> Relativo al final del fichero
;               DE:HL  = Desplazamiento en complemento a dos
;    SALIDA:    A  = 0 -> No hay error
;               A <> 0 -> Error
;               DE:HL  = Nuevo puntero
;    * Para obtener la posicion del puntero sin modificarla,
;      ejecutar con A = 1 y DE:HL=0.
;    * Para obtener la longitud del fichero,
;      ejecutar con A = 2 y DE:HL=0.
;    REGISTROS:  F
;    LLAMADAS:   CHKDOS2
;    VARIABLES:  MAXFILES, NUMFILES, doscall, _SEEK, BUFFER

SEEK:	if	DOS=12

	ld	(BUFFER),a
	call	CHKDOS2
	ld	a,(BUFFER)
	jp	nc,SEEK2

	endif

	;--- SEEK: Version DOS 1

	if	DOS<>2

SEEK1:	ld	(BUFFER),a
	ld	a,b	;Error si B>MAXFILES
	cp	MAXFILES+1	;o B=0. 
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
SK1BUC1:	add	hl,de	;HL = Zona en FCBS del fichero B
	djnz	SK1BUC1

	ld	a,(hl)	;Error si el fichero no esta abierto 
	or	a
	ld	a,2
	jp	z,ENDSK11

	push	hl
	pop	ix
	inc	ix	;IX = FCB del fichero

	ld	a,(BUFFER)
	or	a	;Obtenemos metodo, y acabamos con error
	jp	z,METODO0	;si es >2
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
	ld	d,(ix+36)	;DE:HL = Puntero actual
	jp	OKMETOD

METODO2:	ld	l,(ix+16)
	ld	h,(ix+17)
	ld	e,(ix+18)
	ld	d,(ix+19)	;DE:HL = Longitud del fichero

OKMETOD:	pop	bc
	add	hl,bc
	pop	bc
	ex	de,hl
	adc	hl,bc	;DE:HL = Nuevo puntero
	ex	de,hl
	xor	a

	ld	(ix+33),l	;Actualizamos puntero
	ld	(ix+34),h
	ld	(ix+35),e
	ld	(ix+36),d

ENDSK1:	pop	iy,ix,bc
	ret
ENDSK11:	pop	bc,bc
	jp	ENDSK1

	endif

	;--- SEEK: Version DOS 2

	if	DOS<>1

SEEK2:	push	bc
	doscall	_SEEK
	pop	bc
	ret

	endif


;--------------------------------------------------------------------------
;--------------------------------------------------------------------------
;--------------------------------------------------------------------------

	;Rutinas varias

;--- NOMBRE: EXTPAR
;      Extraccion de un parametro de la linea de comando
;    ENTRADA:   A  = Parametro a extraer (el primero es el 1)
;               DE = Buffer para dejar el parametro
;    SALIDA:    A  = Numero de parametros
;               CY = 1 -> No existe ese parametro
;                         B indefinido, buffer inalterado
;               CY = 0 -> B = Longitud del parametro (no incluye el 0)
;                         Parametro a partir de DE, acabado en 0
;    REGISTROS: -
;    LLAMADAS:  -
;    VARIABLES: Macros JR

EXTPAR:	or	a	;Volvemos con error si A = 0
	scf
	ret	z

	ld	b,a
	ld	a,(#80)	;Volvemos con error si no hay parametros  
	or	a
	scf
	ret	z
	ld	a,b

	push	hl,de,ix
	ld	ix,0	;IXl: Numero de parametros    
	ld	ixh,a	;IXh: Parametro a extraer    
	ld	hl,#81

PASASPC:	ld	a,(hl)	;Vamos pasando espacios    
	or	a
	jr	z,ENDPNUM
	cp	" "
	inc	hl
	jri	PASASPC

	inc	ix
PASAPAR:	ld	a,(hl)	;Vamos pasando el parametro    
	or	a
	jr	z,ENDPNUM
	cp	" "
	inc	hl
	jri	PASASPC
	jr	PASAPAR

ENDPNUM:	ld	a,ixh	;Error si se el parametro a extraer    
	cp	ixl	;es mayor que el numero de parametros    
	jrmy	EXTPERR	;existentes    

	ld	hl,#81
	ld	b,1	;B = parametro actual    
PASAP2:	ld	a,(hl)	;Pasamos espacios hasta dar    
	cp	" "	;con el siguiente parametro    
	inc	hl
	jri	PASAP2

	ld	a,ixh	;Si es el que buscamos lo extraemos.    
	cp	B	;Si no ...    
	jri	PUTINDE0

	inc	B
PASAP3:	ld	a,(hl)	;... lo pasamos y volvemos a PAPAP2    
	cp	" "
	inc	hl
	jrni	PASAP3
	jr	PASAP2

PUTINDE0:	ld	b,0
	dec	hl
PUTINDE:	inc	b
	ld	a,(hl)
	cp	" "
	jri	ENDPUT
	or	a
	jr	z,ENDPUT
	ld	(de),a	;Ponemos el parametro a partir de (DE)    
	inc	de
	inc	hl
	jr	PUTINDE

ENDPUT:	xor	a
	ld	(de),a
	dec	b

	ld	a,ixl
	or	a
	jr	FINEXTP
EXTPERR:	scf
FINEXTP:	pop	ix,de,hl
	ret


;--- EXTDIR2: Como EXTDIR para direcciones de 16 bits, resultado de DE

EXTDIR2:	ld	a,(ix+3)
	call	HEX2NUM2
	ld	e,a

	ld	a,(ix+2)
	call	HEX2NUM2
	sla	a
	sla	a
	sla	a
	sla	a
	or	e
	ld	e,a

	ld	a,(ix+1)
	call	HEX2NUM2
	ld	d,a

	ld	a,(ix+0)
	call	HEX2NUM2
	sla	a
	sla	a
	sla	a
	sla	a
	or	d
	ld	d,a

	jr	EXTDFIN


;--- NOMBRE:  EXTDIR
;      Extrae una direccion de 32 bits en hexadecimal
;    ENTRADA: IX = Inicio de la cadena
;    SALIDA:  HLDE = Numero de 32 bits
;             A = Caracteres invalidos o cadena demasiado larga si <>0

EXTDIR:	ld	a,(ix+7)
	call	HEX2NUM2
	ld	e,a

	ld	a,(ix+6)
	call	HEX2NUM2
	sla	a
	sla	a
	sla	a
	sla	a
	or	e
	ld	e,a

	ld	a,(ix+5)
	call	HEX2NUM2
	ld	d,a

	ld	a,(ix+4)
	call	HEX2NUM2
	sla	a
	sla	a
	sla	a
	sla	a
	or	d
	ld	d,a

	ld	a,(ix+3)
	call	HEX2NUM2
	ld	l,a

	ld	a,(ix+2)
	call	HEX2NUM2
	sla	a
	sla	a
	sla	a
	sla	a
	or	l
	ld	l,a

	ld	a,(ix+1)
	call	HEX2NUM2
	ld	h,a

	ld	a,(ix+0)
	call	HEX2NUM2
	sla	a
	sla	a
	sla	a
	sla	a
	or	h
	ld	h,a

	ld	a,(ix+8)
EXTDFIN2:	cp	" "
	jr	z,EXTD_OK
	cp	9
	jr	z,EXTD_OK
	cp	13
	jr	z,EXTD_OK
	or	a
	jr	z,EXTD_OK
	jr	EXTD_ER2

EXTD_OK:	xor	a
	ret
EXTDFIN:	ld	a,(ix+4)
	jr	EXTDFIN2

HEX2NUM2:	call	HEX2NUM
	cp	255
	jr	z,EXTD_ERR
	ret
EXTD_ERR:	pop	de
EXTD_ER2:	ld	a,255
	ret

	;--- Hexadecimal a numero en A (255 = invalido)

HEX2NUM:	push	hl,de
	ld	hl,"FA"
	call	RANGE
	jr	z,ESLETRA
	ld	hl,"fa"
	call	RANGE
	jr	z,ESLETMIN
	ld	hl,"90"
	call	RANGE
	jr	nz,H2N_ERR

ESNUM:	sub	"0"
	pop	de,hl
	ret

ESLETMIN:	and	%11011111
ESLETRA:	sub	"A"
	add	10
	pop	de,hl
	ret

H2N_ERR:	ld	a,255
	pop	de,hl
	ret


;--- NOMBRE: RANGE
;      Comprueba que un byte esta dentro de un rango
;    ENTRADA:    H = Valor superior del rango (inclusive)
;                L = Valor inferior del rango (inclusive)
;                A = Byte
;    SALIDA:     Z = 1 Si esta dentro del rango (Cy = ?)
;                Cy= 1 si esta por encima del rango (Z = 0)
;                Cy= 0 si esta por debajo del rango (Z = 0)

RANGE:	cp	l	;Menor?
	ccf
	ret	nc

	cp	h	;Mayor?
	jr	z,R_H
	ccf
	ret	c

R_H:	push	bc	;=H?
	ld	b,a
	xor	a
	ld	a,b
	pop	bc
	ret


;--- NOMBRE:  DIRTOHEX
;      Transforma un numero de 32 bits en una cadena hexadecimal
;    ENTRADA: HLDE = Numero
;             IX = Destino para la cadena

DIRTOHEX:	push	hl
	ld	a,h
	call	BYTOHEX
	ld	(ix+0),h
	ld	(ix+1),l
	pop	hl

	ld	a,l
	call	BYTOHEX
	ld	(ix+2),h
	ld	(ix+3),l

	ld	a,d
	call	BYTOHEX
	ld	(ix+4),h
	ld	(ix+5),l

	ld	a,e
	call	BYTOHEX
	ld	(ix+6),h
	ld	(ix+7),l

	ret

	;--- Transforma el byte A en hexa. en HL

BYTOHEX:	push	af
	call	BYTOH1
	ld	l,a
	pop	af
	sra	a
	sra	a
	sra	a
	sra	a
	call	BYTOH1
	ld	h,a
	ret

BYTOH1:	and	%1111
	cp	10
	jrmn	BTHMEN10

	sub	10
	add	"A"
	ret
BTHMEN10:	add	"0"
	ret


Z380:	;== MANDA COMANDO (A) A Z380 Y ESPERA CONCLUSION
	PUSH	AF
ZWAIT:	LD	A,(Z380ST)	;ESPERA A QUE Z380 LIBRE (=0)
	AND	A
	JR	NZ,ZWAIT
	POP	AF
	LD	(Z380ST),A	;ESCRIBE CODIGO COMANDO (1..254)
ZWAI2:	LD	A,(Z380ST)	;ESPERA A QUE Z380 ACABE (=0)
	AND	A
	JR	NZ,ZWAI2
	RET

	;--- GET

DO_GET:	LD	DE,(ZLONG)	;Comprueba si quedan datos a transferir
	LD	A,D
	OR	E
	RET	Z

	CALL	DEC_LON
	LD	(ZBLON),BC
	LD	A,4	;#4: TRAER DE Z380 (INIT=ZDIR_3,ZBLON) A &H4300
	CALL	Z380	; EL Z380 ACTUALIZA ZDIR_3=ZDIR_3+ZBLON

	;Copia de FREDIR a ZDIR_M

	PUSH	HL
	LD	DE,(ZDIR_M)
	LD	HL,(BLKDIR)
	LDIR
	LD	(ZDIR_M),DE
	POP	HL

	JR	DO_GET


DEC_LON:	PUSH	HL
	LD	HL,(ZLONG)
	LD	BC,(BLKLON)
	AND	A
	SBC	HL,BC
	JR	NC,CZP1
	LD	HL,0
	LD	BC,(ZLONG)
CZP1:	LD	(ZLONG),HL
	POP	HL
	RET

WRERR:	ld	de,WRERR_S
	jp	FINSTR
WRERR_S:	db	"ERROR when writing in file.",13,10,"$"

FH:	db	255
TMPSIZE:	dw	0
DIR_INI:	ds	4
SIZE:	ds	4
HAYHEAD:	db	0
H_INI:	dw	0
H_FIN:	dw	#FFFF
H_EXE:	dw	0
BUF:	;
