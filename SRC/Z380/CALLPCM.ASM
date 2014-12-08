;CALL commans for LPE-Z380
;It allows to record/play sounds using the Turbo-R's PCM and the Z380 memory

;==================================================

;--- Ejemplo de expansion de CALL para Z380:
;    CALL ZPCMREC (dir31..16, dir15..0, lon31..16, long15..0, frec)
;    CALL ZPCMPLAY (dir31..16, dir15..0, lon31..16, long15..0, frec)
;
;    Por Konami Man, 22-6-2000


	include	4	;Macros Z380

;****************************
;***  MACROS, CONSTANTES  ***
;****************************

	;--- Direcciones de la biport

Z380ST:	equ	#10
ZDIR_3:	equ	#11
ZVAL:	equ	#15
ZDIR_M:	equ	#17
ZBLON:	equ	#19
ZTLON:	equ	#1B
BLKDIR:	equ	#1D
BLKLON:	equ	#1F
USRDIR:	equ	#21
TRAPFDIR:	equ	#23
TRAPIDIR:	equ	#25
INTFLAG:	equ	#27
SERVSPC:	equ	#28
MEMLON:	equ	#3F
S_C_DIR:	equ	#40
S_JMP:	equ	#42
S_ACTION:	equ	#45

	;--- Direcciones en base frame

ZTERM:	equ	3
ZBIOS:	equ	6
MAXDIR:	equ	9

	;--- Rutinas server

MRBYTE:	equ	#10
MRWORD:	equ	#13
MWBYTE:	equ	#16
MWWORD:	equ	#19
MRPORT:	equ	#1C
MWPORT:	equ	#1F
EXEMSX:	equ	#22
ZTOM:	equ	#25
MTOZ:	equ	#28
MTOP:	equ	#2B
PTOM:	equ	#2E
MRBYT2:	equ	#31
MRWOR2:	equ	#34
MWBYT2:	equ	#37
MWWOR2:	equ	#3A
MRPOR2:	equ	#3D
MWPOR2:	equ	#40
EXEMS2:	equ	#43
ZTOM2:	equ	#46
MTOZ2:	equ	#49
MTOP2:	equ	#4C
PTOM2:	equ	#4F

inf:	macro
	db	#ED,#70
	endm

PMDAC:	equ	#A4
PMCNT:	equ	#A4
PMCNTL:	equ	#A5
PMSTAT:	equ	#A5
SYSTML:	equ	#E6

print:	macro	@p
	ld	a,@p
	call	EXEMS2
	dw	#A2
	ddir	iw.lw
	ld	ix,0
	dw	#4000
	endm

;*****************************
;***  INSTALADOR DEL CALL  ***
;*****************************

	org	#100

	;--- Reserva espacio al final del base frame

	resc	lw
	ld	hl,(MAXDIR)
	subwi	PCMEND - PCMST
	ld	(MAXDIR),hl

	;--- Construye el nuevo gancho

	ld	(NEWHOOK+1),hl

	;--- Guarda el gancho antiguo

	setc	lw
	ld	hl,#FFE8
	ld	de,OLDHOOK
	ld	bc,8
	ldirw		;Se puede usar porque BC es multiplo de 4

	;--- Establece adecuadamente las direcciones fijas

	resc	lw
	ld	hl,TABLA - PCMST
	ld	de,(MAXDIR)
	add	hl,de
	ld	(CHKNAM+1),hl

	ld	hl,CODE1 - PCMST
	add	hl,de
	ld	(SETC1+1),hl

	ld	hl,CODE2 - PCMST
	add	hl,de
	ld	(SETC2+1),hl

	ddir	iw
	ld	de,(S_C_DIR)
	dw	#4000

	ld	hl,RECAD0 - COD1ST
	add	hl,de
	ld	(SETRC0+1),hl

	ld	hl,RECAD1 - COD1ST
	add	hl,de
	ld	(SETRC1+1),hl

	ld	hl,RECAD2 - COD1ST
	add	hl,de
	ld	(SETRC2+1),hl

	ld	hl,RECAD3 - COD1ST
	add	hl,de
	ld	(SETRC3+1),hl

	ld	hl,RECAD4 - COD1ST
	add	hl,de
	ld	(SETRC4+1),hl

	ld	hl,RECAD5 - COD1ST
	add	hl,de
	ld	(SETRC5+1),hl

	ld	hl,RECAD6 - COD1ST
	add	hl,de
	ld	(SETRC6+1),hl

	ld	hl,RECAD7 - COD1ST
	add	hl,de
	ld	(SETRC7+1),hl

	;--- Copia la nueva rutina a la zona reservada

	setc	lw
	ld	hl,PCMST
	ld	de,0
	ddir	w
	ld	de,(MAXDIR)
	ld	bc,PCMEND - PCMST
	ldir

	;--- Copia el nuevo gancho

	ld	hl,NEWHOOK
	ld	de,#FFE8
	ld	bc,8
	ldirw		;Se puede usar porque BC es multiplo de 4

	;--- Termina

	jp	3

	;--- Nuevo gancho

NEWHOOK:	jp	0
	ds	5


;*************************
;***  CODIGO DEL CALL  ***
;*************************

;Ha de ser reubicable (usar CALR en vez de CALL, y JR en vez de JP)

PCMST:	setc	lw
	ddir	iw
	ld	ix,0
	dw	#4000

	;--- Comprueba que es nuestro CALL, si no, pone (ZVAL)=0
	;    y salta al gancho antiguo

CHKNAM:	ld	hl,0	;<--- Ha de ser establecido al instalar
	ldmr	(ix+ZDIR_3),hl

	ld	a,13	;Reconocedor del nombre
	call	ZBIOS

	ld	a,(ix+ZVAL+1)
	or	a
	jr	nz,OKPCM

NOPCM:	xor	a
	ld	(ix+ZVAL),a
OLDHOOK:	ds	8

TABLA:	db	"ZPCMREC",0
	db	"ZPCMPLAY",0
	db	0

OKPCM:	print	"1"	;Guarda num. de comando
	resc	lw
	push	af

	;--- Extrae parametros y los guarda en la pila

	ld	(ix+ZVAL),1	;Extrae "("
	ld	a,14
	call	ZBIOS

	print	"2"

	ld	(ix+ZVAL),5	;Extrae dir31..16
	ld	a,14
	call	ZBIOS
	ldrm	hl,(ix+ZVAL)
	push	hl

	print	"3"

	ld	(ix+ZVAL),3	;Extrae ","
	ld	a,14
	call	ZBIOS

	print	"4"

	ld	(ix+ZVAL),5	;Extrae dir15..0
	ld	a,14
	call	ZBIOS
	ldrm	hl,(ix+ZVAL)
	push	hl

	print	"5"

	ld	(ix+ZVAL),3	;Extrae ","
	ld	a,14
	call	ZBIOS

	print	"6"

	ld	(ix+ZVAL),5	;Extrae lon31..16
	ld	a,14
	call	ZBIOS
	ldrm	hl,(ix+ZVAL)
	push	hl

	print	"7"

	ld	(ix+ZVAL),3	;Extrae ","
	ld	a,14
	call	ZBIOS

	print	"8"

	ld	(ix+ZVAL),5	;Extrae lon15..0
	ld	a,14
	call	ZBIOS
	ldrm	hl,(ix+ZVAL)
	push	hl

	print	"9"

	ld	(ix+ZVAL),3	;Extrae ","
	ld	a,14
	call	ZBIOS

	print	"A"

	ld	(ix+ZVAL),4	;Extrae frec.
	ld	a,14
	call	ZBIOS
	ldrm	hl,(ix+ZVAL)
	push	hl

	print	"B"

	ld	(ix+ZVAL),2	;Extrae ")"
	ld	a,14
	call	ZBIOS

	print	"C"

	;Ahora el contenido de la pila es:

	;(SP)    = frecuencia
	;(SP+2)  = longitud (32 bits)
	;(SP+6)  = direccion (32 bits)
	;(SP+10) = comando, 1 o 2

	;--- Recupera frecuencia en L, longitud en BC, dir. en DE

	pop	hl
	setc	lw
	pop	bc
	pop	de

	;--- Recupera num. de comando y ejecuta REC o PLAY

	resc	lw
	pop	af
	cp	1
	jr16	z,REC
	jr16	t,PLAY


;----------------
;---  PCMREC  ---
;----------------

	;--- Copia el codigo a biport y empieza a ejecutarlo

REC:	setc	lw
	exx
SETC1:	ld	hl,0
	ldmr	(ix+ZDIR_3),hl
	ld	a,12
	call	ZBIOS
	setc	lw
	exx

	ld	(ix+ZDIR_M),l	;Frecuencia
	ld	(ix+ZVAL+1),0

	ld	a,1	;Comienza la ejecucion
	ld	(ix+S_ACTION),a

	;--- Bucle de grabacion. El protocolo es el siguiente:
	;* Inicialmente, el MSX recoge la frecuencia de ZDIR_M,
	;  y el Z380 ha puesto (ZVAL+1) a 0.
	;* El MSX recoge un dato del DAC, y espera a que (ZVAL+1) valga 0
	;  o -1. Si vale -1, termina.
	;* Cuando (ZVAL+1) vale 0, el MSX pone el dato en (ZVAL), y
	;  pone (ZVAL+1) a 1. Entonces vuelve al paso anterior.
	;* El Z380 espera a que (ZVAL+1) valga 1, entonces recoge el dato
	;  de (ZVAL), y lo guarda.
	;* Si quedan mas datos por obtener, el Z380 pone (ZVAL+1) a 0 y
	;  vuelve al paso anterior; si no, lo pone a -1 y termina.

RECLOOP:	ld	a,(ix+ZVAL+1)
	or	a
	jr	z,RECLOOP

	ld	a,(ix+ZVAL)
	ld	(de),a
	inc	de
	dec	bc
	ldrr	hl,bc	;Hace OR de BCz y BC
	swap	bc	;para comprobar si BCz:BC vale 0
	orw	bc
	swap	bc
	jr	nz,RECLP1

	ld	(ix+ZVAL+1),-1
WREND:	ld	a,(ix+S_ACTION)
	cp	2
	jr	nz,WREND
	ld	(ix+ZVAL),1
	ret

RECLP1:	ld	(ix+ZVAL+1),0
	jr	RECLOOP


	;------------------
	;--- CODIGO MSX ---
	;------------------

CODE1:	dw	COD1END - COD1ST

	;--- Inicializacion de puertos y contador

COD1ST:	ld	a,(ZDIR_M+#4000)
	ld	e,a

	ld	a,%00001100
	out	(PMCNTL),a
	di
	xor	a
	out	(SYSTML),a

	;--- Espera a que sea el momento de obtener muestra

REC1:	in	a,(SYSTML)
	cp	e
	jr	c,REC1
	ld	(#A000),a
	xor	a
	out	(SYSTML),a

	;--- Obtiene dato

	ld	a,%00011100
	out	(PMCNTL),a
	ld	c,PMSTAT

	ld	a,%10000000
	out	(PMDAC),a
	inf
SETRC0:	jp	m,RECAD0
	res	7,a

RECAD0:	set	6,a
	out	(PMDAC),a
	inf
SETRC1:	jp	m,RECAD1
	res	6,a

RECAD1:	set	5,a
	out	(PMDAC),a
	inf
SETRC2:	jp	m,RECAD2
	res	5,a

RECAD2:	set	4,a
	out	(PMDAC),a
	inf
SETRC3:	jp	m,RECAD3
	res	4,a
	jr	RECAD3

ENMEDIO:	jr	REC1

RECAD3:	set	3,a
	out	(PMDAC),a
	inf
SETRC4:	jp	m,RECAD4
	res	3,a

RECAD4:	set	2,a
	out	(PMDAC),a
	inf
SETRC5:	jp	m,RECAD5
	res	2,a

RECAD5:	set	1,a
	out	(PMDAC),a
	inf
SETRC6:	jp	m,RECAD6
	res	1,a

RECAD6:	set	0,a
	out	(PMDAC),a
	inf
SETRC7:	jp	m,RECAD7
	res	0,a

	;--- Guarda dato y repite el bucle

RECAD7:	ld	d,a

BUCREC2:	ld	a,(ZVAL+1+#4000)
	cp	-1
	jr	z,FBREC	;Fin?

	or	a
	jr	nz,BUCREC2	;Esta listo el Z380?

	ld	a,%00001100	;Para que el DAC obtenga otro dato
	out	(PMCNTL),a
	ld	a,d	;Deposita dato y cierra el bucle
	ld	(ZVAL+#4000),a
	ld	a,1
	ld	(ZVAL+#4000+1),a
	jr	ENMEDIO

	;--- No quedan mas datos que obtener: fin

FBREC:	ld	a,%00000011
	out	(PMCNTL),a
	ei
	ret
COD1END:	;


;-----------------
;---  PCMPLAY  ---
;-----------------

	;--- Copia el codigo a biport y empieza a ejecutarlo

PLAY:	setc	lw
	exx
SETC2:	ld	hl,0
	ldmr	(ix+ZDIR_3),hl
	ld	a,12
	call	ZBIOS
	setc	lw
	exx

	ld	(ix+ZDIR_M),l	;Frecuencia
	ld	(ix+ZVAL+1),0

	ld	a,1	;Comienza la ejecucion
	ld	(ix+S_ACTION),a

	;--- Bucle de reproduccion. El protocolo es el siguiente:
	;* Inicialmente, el MSX recoge la frecuencia de ZDIR_M,
	;  y el Z380 ha puesto (ZVAL+1) a 0.
	;* El Z380 espera a que (ZVAL+1) valga 0. Entonces deposita
	;  el dato a reproducir en (ZVAL), y pone (ZVAL+1) a 1.
	;  Si es el ultimo dato, en vez de 1 pone -1 y termina.
	;  Si no, repite.
	;* El MSX espera a que (ZVAL+1) valga 1 o -1. Entonces coge
	;  el dato de (ZVAL) y lo manda al DAC. Si (ZVAL+1) valia -1,
	;  termina. Si no, pone (ZVAL+1) a 0 y repite.

PLAYLOOP:	ld	a,(ix+ZVAL+1)
	or	a
	jr	nz,PLAYLOOP

	ld	a,(de)
	ld	(ix+ZVAL),a
	inc	de
	dec	bc
	ldrr	hl,bc	;Hace OR de BCz y BC
	swap	bc	;para comprobar si BCz:BC vale 0
	orw	bc
	swap	bc
	jr	nz,PLAYLP1

	ld	(ix+ZVAL+1),-1
WPEND:	ld	a,(ix+S_ACTION)
	cp	2
	jr	nz,WPEND
	ld	(ix+ZVAL),1
	ret

PLAYLP1:	ld	(ix+ZVAL+1),1
	jr	PLAYLOOP


	;------------------
	;--- CODIGO MSX ---
	;------------------

CODE2:	dw	COD2END-COD2ST

	;--- Inicializacion de puertos y contador

COD2ST:	ld	a,(ZDIR_M+#4000)
	ld	e,a

	ld	a,%00000011
	out	(PMCNTL),a
	di
	xor	a
	out	(SYSTML),a

	;--- Espera a que haya una muestra disponible

PLAY1:	ld	a,(ZVAL+1+#4000)
	or	a
	jr	z,PLAY1
	cp	-1
	jr	z,FBPLAY	;Fin si no hay mas muestras

	ld	a,(ZVAL+#4000)
	ld	d,a
	xor	a
	ld	(ZVAL+1+#4000),a

	;--- Espera al contador y reproduce muestra

PLAY2:	in	a,(SYSTML)
	cp	e
	jr	c,PLAY2
	xor	a
	out	(SYSTML),a

	ld	a,d
	out	(PMDAC),a
	jr	PLAY1

FBPLAY:	ei
	ret
COD2END:	;

PCMEND:	;
