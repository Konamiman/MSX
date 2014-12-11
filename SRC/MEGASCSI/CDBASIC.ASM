;NestorBASIC extension to control music CD play
;Requires MegaSCSI

;===============================

	;Aborejam si hacemos un algo pa quel
	;Puto pueda reproducir CDs desdel NestorBASIC

	;Por el Konamimancio de siempre, 4-2002

	org	#8400

CALSLT:	equ	#001C
ENASLT:	equ	#0024
RDSLT:	equ	#000C

;*** Punto de llamada (#8400)
;    Entrada: Numero de funcion en P(2)
;    Resto de registros: segun la funcion

START:	ld	(SAVEP2),bc
	ld	(SAVEP3),de
	ld	(SAVEP4),hl

	push	af
	pop	bc
	ld	b,0
	ld	hl,TABLA
	add	hl,bc
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(DIR+1),hl
	ld	bc,(SAVEP2)
	ld	de,(SAVEP3)
	ld	hl,(SAVEP4)
DIR:	jp	0

TABLA:	dw	RETEA
	dw	FUN_1
	dw	FUN_2
	dw	FUN_3
	dw	FUN_4
	dw	FUN_5
	dw	FUN_6
	dw	FUN_7
	dw	FUN_8
	dw	FUN_9


;*** Funciones ***

;--- Funcion 1: Busqueda de un Mega-SCSI y una unidad de CD
;    Devuelve: P(3) = 0
;              P(4) = Slot+subslot del MegaSCSI
;              P(5) = ID del CD
;    Si no se encuentra MegaSCSI o CD: P(3)=0

FUN_1:	ld	(SAVESP),sp
	ld	hl,#FB22
	ld	b,4

BUCSLOT:	push	hl,bc	;Bucle de busqueda de Mega-SCSI
	ld	a,(hl)	;a traves de los cuatro controladores
	or	a
	jr	z,FIN_NOMEGA
	call	CHK_SLOT
	call	nc,CHK_IDBUC
	pop	bc,hl
	inc	hl
	inc	hl
	djnz	BUCSLOT
	jr	FIN_NOMEGA

CHK_IDBUC:	ld	b,8	;Para cada MegaSCSI: busqueda de un CD
BUCID:	push	bc	;a traves de todos los IDs

	ld	a,b	;ID normal -> ID raro para el MegaSCSI
	dec	a
	cpl
	and	7
	ld	(CDID),a
	ld	b,a
	inc	b
	ld	a,%10000000
BUCID2:	rlc	a
	djnz	BUCID2
	ld	(DATOS_SRCH),a
	ld	(DATOS),a

	ld	ix,#7FCC
	ld	a,(hl)
	ld	iyh,a
	ld	a,#C0
	push	hl
	ld	hl,DATOS_SRCH	;Comando INQUIRY para todos los IDs
	call	CALSLT
	pop	hl
	jr	c,ENDBUCID

	ld	a,(DAT)
	cp	5	;Tipo de dispositivo 5 = CD-ROM
	jr	z,CD_FOUND
ENDBUCID:	pop	bc
	djnz	BUCID
RETEA:	ret

FIN_NOMEGA:	ld	de,0
	ld	bc,0
	ld	sp,(SAVESP)
	ret

CD_FOUND:	ld	sp,(SAVESP)
	ld	a,(hl)
	ld	(MEGASLOT),a
	ld	e,a
	ld	d,0
	ld	hl,(CDID)
	ld	h,0
	ld	bc,0
	ret


;--- Funcion 2: Obtiene informacion sobre un CD
;    Entrada: -
;    Salida:  P(3) = Status (0 si OK)
;             P(4) = Numero total de pistas
;             P(5) = Numero de pistas de audio

	;Ejecuta comando SCSI

FUN_2:	ld	hl,READTOC
	call	EJECOM
	ret	c

	;No hay error: calcula numero de pistas

	ld	a,(DATA+2)
	ld	h,a
	ld	a,(DATA+3)
	sub	h
	inc	a
	ld	e,a
	ld	d,0
	ld	(SAVEP2),bc
	ld	(SAVEP3),de

	ld	b,a
	ld	de,0
	ld	hl,DATA+5
FUN2LOOP:	push	bc
	ld	a,(hl)
	bit	2,a
	jr	nz,FUN2_NOAUDIO
	inc	e
FUN2_NOAUDIO:	ld	bc,8
	add	hl,bc
	pop	bc
	djnz	FUN2LOOP

	ex	de,hl
	ld	bc,(SAVEP2)
	ld	de,(SAVEP3)
	or	a
	ret


;--- Funcion 3: Obtiene el estado de la reproduccion
;    Entrada: -
;    Salida:  P(3) = Status (0 si OK)
;             P(4) = Estado:
;                 0: Audio status no soportado o no valido
;                 1: PLAY
;                 2: PAUSE
;                 3: PLAY terminado OK
;                 4: PLAY terminado debido a un error
;                 5: No hay audio status que devolver

	;Ejecuta comando SCSI

FUN_3:	ld	hl,READ_Q
	call	EJECOM
	ret	c

	;No hay error: devuelve estado

	ld	a,(DATA+1)
	and	%00001111
	ld	e,a
	ld	d,0
	or	a
	ret


;--- Funcion 4: Comprueba que una pista sea de audio
;    Entrada: P(3) = Pista a comprobar, empezando por 1
;    Salida:  P(3) = Status (0 si OK, es de audio)
;                    256 si la pista no existe
;                    257 si la pista no es de audio
;             P(4) = Duracion en segundos
;             P(5) = Duracion extra en 1/75 segundos


FUN_4:	xor	a
	ld	(REPRODUCE),a
	jr	FUN_4_5


;--- Funcion 5: Reproduce una pista
;    Entrada: P(3) = Pista a reproducir, empezando por 1
;    Salida:  P(3) = Status (0 si OK)
;                    256 si la pista no existe
;                    257 si la pista no es de audio
;             P(4) = Duracion en segundos
;             P(5) = Duracion extra en 1/75 segundos

FUN_5:	ld	a,#FF
	ld	(REPRODUCE),a

FUN_4_5	dec	bc	;Guarda la pista, empezando por 0
	ld	(PISTA),bc

	;Primero lee el TOC

	call	FUN_2
	ret	c
	ld	(NUMPISTAS),de

	ld	a,d	;Error si no hay pistas
	or	e
	ld	bc,256
	ret	z

	ld	hl,(PISTA)	;Error si no existe esa pista
	ld	de,(NUMPISTAS)
	call	COMP
	ld	bc,256
	ret	c

	;Calcula la direccion del bloque de datos
	;de la pista en el TOC obtenido,
	;y mira el bit "control"

	ld	hl,DATA+5-8
	ld	a,(PISTA)
	ld	b,a
	inc	b
	ld	de,8
FUN4_LOOP:	add	hl,de
	djnz	FUN4_LOOP
	ld	a,(hl)
	bit	2,a
	ld	bc,257
	ret	nz
	inc	hl
	inc	hl
	inc	hl
	push	hl

	;--- Establece dir. de inicio
	;    en el comando

	ld	de,PLAY12+2
	ld	bc,4
	ldir

	;Obtiene la longitud de la pista
	;como la dir de inicio de la siguiente
	;menos la dir de inicio de esta
	;(con la ultima tambien funciona,
	; pues en el TOS se incluye una "pista falsa"
	; que indica donde termina la ultima pista real)

F5_NOULT:	pop	iy
	push	iy
	ld	bc,8
	add	iy,bc
	ex	de,hl
	pop	ix	;IX=Dir esta, IY=Dir siguiente

	ld	l,(iy+3)	;Calcula parte baja
	ld	h,(iy+2)
	ld	c,(ix+3)
	ld	b,(ix+2)
	or	a
	sbc	hl,bc
	ld	a,h
	ld	(PLAY12+8),a
	ld	a,l
	ld	(PLAY12+9),a
	ld	(LONGITUD),hl

	ld	l,(iy+1)	;Calcula parte alta
	ld	h,(iy+0)
	ld	c,(ix+1)
	ld	b,(ix+0)
	sbc	hl,bc
	ld	a,h
	ld	(PLAY12+6),a
	ld	a,l
	ld	(PLAY12+7),a

	;Inicia la reproduccion si era la funcion 5

F5_DOPLAY:	ld	a,(REPRODUCE)
	or	a
	jr	z,F5_NOPLAY
	ld	hl,PLAY12
	call	EJECOM
	ret	c

	;Devuelve la longitud de la pista
	;(solo sera valida si es < 14.5 minutos)

F5_NOPLAY:	ld	hl,(LONGITUD)
	call	DIV75
	ex	de,hl
	ld	l,a
	ld	h,0
	ld	bc,0
	ret


;--- Funcion 6: Para la reproduccion
;    Entrada: -
;    Salida:  P(3) = Status (0 si OK)

	;Reproduce 1 sector para parar la reproduccion

FUN_6:	ld	hl,PLAY12+2
	ld	de,PLAY12+3
	ld	bc,7
	ld	(hl),0
	ldir
	ld	a,1
	ld	(PLAY12+9),a

	ld	hl,PLAY12
	call	EJECOM
	ret


;--- Funcion 7: Pausa/Despausa la reproduccion
;    Entrada: -
;    Salida:  P(3) = Status (0 si OK)
;                    258 si no hay ninguna reproduccion en marcha

FUN_7:	ld	hl,READ_Q
	call	EJECOM
	ret	c

	ld	a,(DATA+1)
	cp	#11
	jr	z,F7_PAUSA
	cp	#12
	jr	z,F7_DESPAUSA

	ld	bc,258
	ret

F7_PAUSA	ld	a,0
	jr	F7_DO
F7_DESPAUSA:	ld	a,1
F7_DO:	ld	(PAUCONT+8),a
	ld	hl,PAUCONT

	call	EJECOM@sym
	ret


;--- Funcion 8: Obtiene la posicion actual de la reproduccion
;    Entrada: -
;    Salida:  P(3) = Status (0 si OK)
;                    258 si no hay ninguna reproduccion en marcha
;             P(4) = Posicion relativa, en segundos
;             P(5) = Posicion extra en 1/75 segundos

FUN_8:	call	FUN_3
	ld	a,b
	or	c
	ret	nz
	ld	a,e
	cp	1
	jr	z,FUN8_OK
	cp	2
	jr	z,FUN8_OK
	ld	bc,258
	ret

FUN8_OK:	ld	hl,READ_Q
	call	EJECOM
	ret	c

	ld	a,(DATA+14)
	ld	h,a
	ld	a,(DATA+15)
	ld	l,a
	call	DIV75
	ex	de,hl
	ld	l,a
	ld	h,0
	ld	bc,0
	ret


;--- Funcion 9: Expulsa el CD
;    Entrada: -
;    Salida:  P(3) = Status (0 si OK)

FUN_9:	ld	hl,EJECT
	call	EJECOM
	ret


;*** Subrutinas ***

;--- Comprobacion de la presencia de un MegaSCSI en un slot
;    Entrada:  A = Slot a comprobar
;    Salida:   Cy = 0 si hay un MegaSCSI
;    Modifica: AF

CHK_SLOT:	;ld      a,(SLOT)
	push	bc,de,hl
	call	SRCHMEGA
	pop	hl,de,bc
	ccf
	ret

SRCHMEGA:	ld	b,8
	ld	c,a
	ld	de,#7FE0
	ld	hl,MEGA_STR

SMS_LOOP:	push	hl,de,bc
	ld	a,c
	ex	de,hl
	call	RDSLT
	pop	bc,de,hl
	xor	(hl)
	ret	nz
	inc	de
	inc	hl
	djnz	SMS_LOOP
	scf
	ret

MEGA_STR:	db	"MEGASCSI"


;--- Ejecuta el comando apuntado por HL
;    Si hay error del MegaSCSI, lo devuelve en BC con offset 128.
;    Si hay error devuelto en "status", lo devuelve en BC.
;    Si no hay error vuelve con BC=0 y Cy=0/

EJECOM:	ld	(COMANDO),hl
	ld	a,#C0
	ld	hl,DATOS
	ld	ix,#7FCC
	ld	iy,(MEGASLOT-1)
	call	CALSLT
	jr	nc,EJECOM2

	or	128	;Error del Mega-SCSI?
	ld	c,a
	ld	b,0
	scf
	ret

EJECOM2:	ld	a,(STATUS)	;Error en STATUS?
	or	a
	ld	bc,0
	ret	z
	ld	c,a
	scf
	ret


;--- NOMBRE: COMP
;      Comparacion de HL con DE (16 bits en complemento a 2)
;    ENTRADA:   HL, DE = numeros a comparar
;    SALIDA:     C, NZ si HL > DE
;                C,  Z si HL = DE
;               NC, NZ si HL < DE
;    REGISTROS: -
;    VARIABLES: -
;    LLAMADAS:  -

COMP:	call	_COMP16
	ccf
	ret

_COMP16:	ld	a,h
	sub	d
	ret	nz
	ld	a,l
	sub	e
	ret


;DIVISION 16 POR 16
;Entrada:  HL=dividendo
;          B=divisor
;Salida:   DE=cociente
;          A=resto

DIVIDE:	ex	de,hl
	ld	a,d
	ld	c,e
	ld	d,0
	ld	e,b

	;Empieza a dividir AC por E

div16:	ld	hl,0
	ld	b,16
loop16:	rl	c
	rla
	adc	hl,hl
	sbc	hl,de
	jr	nc,$+3
	add	hl,de
	ccf
	djnz	loop16
	rl	c
	rla
done:	ld	d,a
	ld	e,c
	ld	a,l
	ret


;--- DIV75: Divide HL por 75
;           Devuelve el resto en A

DIV75:	ld	b,75
	call	DIVIDE
	ex	de,hl
	ret


;*** Zona de datos ***

SAVEP1:	dw	0
SAVEP2:	dw	0
SAVEP3:	dw	0
SAVEP4:	dw	0

MEGASLOT:	db	0
CDID:	db	0
SAVESP:	dw	0

PISTA:	dw	0
NUMPISTAS:	dw	0
STARTDIR:	dw	0
LONGITUD:	dw	0
REPRODUCE:	db	0

;--- CDB para el comando INQUIRY

DATOS_SRCH:	db	0,0
	dw	COM
	dw	DAT
	dw	STA
	dw	MES
COM:	db	#12,0,0,0,1,0
DAT:	db	0
STA:	db	0
MES:	db	0
OKSRCHCD:	;

;--- CDB general

DATOS:	db	0,0
COMANDO:	dw	0
	dw	DATA
	dw	STATUS
	dw	MESSAGE

STATUS:	db	0
MESSAGE:	db	0

;--- Comandos SCSI

READTOC:	db	#43,0,0,0,0,0,0,#04,0,0	;Lee TOC
READ_Q:	db	#42,0,#40,1,0,0,0,#04,0,0	;Lee sub-canal Q
PLAY12:	db	#A5,0,0,0,0,0,0,0,0,0,0,0	;Reproduce pista
PAUCONT:	db	#4B,0,0,0,0,0,0,0,1,0	;Pausa/continuacion
EJECT:	db	#1B,0,0,0,%10,0	;       ;Extraccion

DATA:	;
