	;--- NestorCadenas 1.0
	;    Por Konami Man (claro), 8-2000

;****************************
;***  MACROS, CONSTANTES  ***
;****************************

LABEL:	equ	#9F00	;Espacio para la etiqueta a buscar
STRING:	equ	#9F80	;Espacio para la cadena a recuperar

CHKSLE:	equ	#4116
CHKSLV:	equ	#411C
LDIRSS:	equ	#412E


;*****************
;***  POGRAMA  ***
;*****************

	org	#8000

	push	af
	pop	hl
	ld	a,l

	ld	hl,FIN
	push	hl

	cp	1
	jp	z,INIT
	cp	2
	jp	z,SETDIR
	cp	3
	jp	z,SETNAM
	cp	4
	jp	z,GETPNT
	cp	5
	jp	z,GETCAD

FIN:	ld	l,a
	ld	h,0
	push	hl
	pop	af
	ret


;--- INICIALIZACION (subfuncion 1)
;    Copia la primera porcion de 8K o menos al bufer (#A000-#BFFF),
;    y establece adecuadamente las variables
;    Entrada: C  = Segmento
;             DE = Direccion
;    Salida:  A = 1 si no existe el segmento

INIT:	ld	a,c	;Primero comprueba si el segmento existe
	call	CHKSEG
	ld	a,1
	ret	nc
	ld	a,c
	ld	(SEG),a
	ld	(ISEG),a

	bit	5,d	;Rango #2000-#3FFF: porcion=-1,
	ld	a,-1	;Rango #0000-#1FFF: porcion=0
	jr	nz,INI2
	xor	a
INI2:	ld	(PORCION),a
	ld	(IPORCION),a

	set	7,d	;Adecua dir. a rango #8000-#BFFF
	res	6,d
	ld	(DIR),de
	ld	hl,#C000
	or	a
	sbc	hl,de
	push	hl
	pop	bc
	dec	bc	;Hace que la longitud sea <=8K
	res	5,b
	inc	bc
	ld	de,(DIR)
	push	de
	pop	hl
	set	5,d
	ld	(DIR),de
	ld	(IDIR),de
	ld	a,(SEG)
	ld	ixh,a
	ld	a,#FF
	ld	ixl,a
	call	LDIRSS

	xor	a
	ld	(OVF),a
	ret


;--- SETDIR (subfuncion 2)
;    Entrada: C = Segmento
;             DE= Direccion
;    Salida:  A = 1 si no existe el segmento
;                 2 si no esta inicializado

SETDIR:	ld	a,(SEG)
	cp	-1
	ld	a,2
	ret	z

	ld	a,c
	call	CHKSEG
	ld	a,1
	ret	nc
	ld	a,c
	ld	(SEG),a

	set	7,d
	res	6,d
	ld	(DIR),de

	xor	a
	ld	hl,0
	bit	5,d
	jr	z,SETD2
	cpl
	set	5,h
SETD2:	ld	(PORCION),a
	ld	de,#2000
	ld	bc,#2000
	ld	a,(SEG)
	ld	ixh,a
	ld	a,#FF
	ld	ixl,a
	call	LDIRSS

	ld	hl,(DIR)
	set	5,h
	ld	(DIR),hl
	xor	a
	ld	(OVF),a
	ret


;--- SETNAM (subfuncion 3)
;    Salida: A=0: OK
;              1: No existe ese nombre
;              2: No esta inicializado

SETNAM:	ld	a,(ISEG)
	cp	-1
	ld	a,2
	ret	z

	ld	hl,(SEG)	;Guardamos puntero y nos ponemos
	ld	(OLDSEG),hl	;al principio
	ld	hl,(DIR+1)
	ld	(OLDDIR+1),hl

	ld	a,(ISEG)
	ld	c,a
	ld	de,(IDIR)
	res	5,d
	ld	a,(IPORCION)
	or	a
	jr	z,SETN2
	set	5,d
SETN2:	call	SETDIR

	ld	hl,(DIR)
	ld	de,LABEL
SETNLOOP:	ld	a,(hl)
	cp	"~"	;Es una etiqueta?
	jr	nz,SETNEXT

SETNLP2:	push	de
	call	INCPNT	;Si lo es: es nuestra etiqueta?
	pop	de
	jr	c,SETNERR
	ld	a,(de)
	or	a
	jr	nz,SETNLP3
	ld	a,(hl)
	cp	13
	jr	z,SETNOK
	cp	#1A
	jr	z,SETNOK
	jr	SETNEXT
SETNLP3:	cp	(hl)
	jr	nz,SETNEXT
	inc	de
	jr	SETNLP2

SETNEXT:	ld	a,(hl)	;Busca siguiente etiqueta
	cp	13
	jr	z,SETNX2
	cp	#1A
	jr	z,SETNERR
	call	INCPNT
	jr	c,SETNERR
	jr	SETNEXT
SETNX2:	call	INCPNT
	jr	c,SETNERR
	call	INCPNT
	jr	c,SETNERR
	ld	a,(hl)
	cp	#1A
	jr	z,SETNERR
	ld	de,LABEL
	jr	SETNLOOP

SETNOK:	call	INCPNT	;Encontrada: pone el puntero
	jr	c,SETNERR	;tras el RET y termina
	call	INCPNT
	jr	c,SETNERR
	xor	a
	ld	(OVF),a
	ret

SETNERR:	ld	a,(OLDSEG)	;No encontrada: restaura puntero y termina
	ld	c,a
	ld	de,(OLDDIR)
	res	5,d
	ld	a,(OLDPOR)
	or	a
	jr	z,SETNER2
	set	5,d
SETNER2:	call	SETDIR
	ld	a,1
	ret


;--- GETPNT (subfuncion 4)
;    Salida: C = segmento
;            DE= direccion
;            A = 1 si no esta inicializado, 2 si esta desbordado

GETPNT:	ld	a,(SEG)
	cp	-1
	ld	a,1
	ret	z

	ld	a,(OVF)
	cp	-1
	ld	a,2
	ret	z

	ld	a,(SEG)
	ld	c,a
	ld	b,0
	ld	de,(DIR)
	res	7,d
	res	6,d
	res	5,d
	ld	a,(PORCION)
	or	a
	jr	z,GETPN2
	set	5,d
GETPN2:	xor	a
	ret


;--- GETCAD (subfuncion 5)
;    Salida: A = Error al uso

GETCAD:	ld	a,(OVF)
	or	a
	ld	a,7
	jp	nz,GETCE

	ld	a,(SEG)
	cp	-1
	ld	a,5
	jp	z,GETCE

	ld	hl,(DIR)
	ld	de,STRING
	ld	a,(hl)
	cp	#1A
	ld	a,6
	jp	z,GETCE

GC:	ld	de,STRING
	xor	a
	ld	(de),a
	push	de,hl
	call	CHKIGN
	pop	hl,de
	jr	c,GETCLP2	;Ignorar cadena?
	ld	b,0
	xor	a
	ld	(OLDCH),a

	;--- Coge la cadena

BUCGETC:	ld	a,(hl)
	cp	#1A
	jp	z,GETCE3
	cp	13
	jr	z,GETCE01
	cp	"^"
	jr	nz,PUTC

	ld	a,b
	ld	(CONTA),a
	push	de
	call	INCPNT	;Extrae numero
	pop	de
	jp	c,GETCE4
	ld	a,(hl)
	cp	"^"
	jr	z,PUTC
	ld	b,0
EXTNUM:	call	CHKNUM
	jr	nc,OKNUM
	sub	"0"
	ld	c,a
	call	POR10
	ld	a,c
	add	b
	ld	b,a
	push	bc,de
	call	INCPNT
	pop	de,bc
	jp	c,GETCE4
	ld	a,(hl)
	jr	EXTNUM
OKNUM:	cp	"!"
	jr	z,PUTN
	push	bc,de
	call	DECPNT
	pop	de,bc
	jr	c,GETCE4
PUTN:	ld	a,b
	push	af
	ld	a,(CONTA)
	ld	b,a
	pop	af

PUTC:	ld	(de),a
	ld	c,a
	inc	de
	inc	b
	push	bc,de
	call	INCPNT
	pop	de,bc
	jr	c,GETCE4
	ld	a,b
	cp	80
	ld	a,c
	ld	(OLDCH),a
	jr	z,GETCE2
	jr	BUCGETC

	;--- Ignorar linea

GETCLP2:	ld	a,(hl)
	cp	#1A
	jr	z,GETCE2
	cp	13
	jr	z,GETCLP3
	call	INCPNT
	jr	c,GETCE4
	jr	GETCLP2
GETCLP3:	call	INCPNT
	jr	c,GETCE4
	call	INCPNT
	jr	c,GETCE4
	jp	GC

	;--- Codigos de finalizacion

GETCE01:	call	INCPNT
	jr	c,GETCE4
	call	INCPNT
	jr	c,GETCE4
	ld	a,(OLDCH)
	cp	" "
	jr	z,GETCE1
	xor	a
	jr	GETCE
GETCE1:	ld	a,1
	jr	GETCE
GETCE2:	ld	a,(hl)
	cp	13
	jr	z,GETCE01
	cp	" "
	ld	a,2
	jr	nz,GETCE
	ld	a,(hl)
	ld	(OLDCH),a
	push	de
	call	INCPNT
	pop	de
	jr	c,GETCE4
	ld	a,(hl)
	cp	13
	jr	z,GETCE01
	call	DECPNT
	ld	a,2
	jr	GETCE

GETCE3:	ld	a,3
	jr	GETCE
GETCE4:	ld	a,4

GETCE:	push	af
	dec	de
	ld	a,(de)
	cp	" "
	jr	z,GETCEE
	inc	de
GETCEE:	xor	a
	ld	(de),a
	pop	af
	ret


;--- CHKIGN: Comprueba si se ha de ignorar la linea
;            (si empieza por ~ o #)
;            Devuelve Cy=1 si se ha de ignorar
;            Entrada: HL = Puntero

CHKIGN:	ld	a,(hl)
	cp	"~"
	jr	z,CHKIG2
	cp	"#"
	jr	z,CHKIG2
	or	a
	ret

CHKIG2:	push	hl
	call	CHKINIT
	pop	hl
	ret	c

	call	DECPNT
	ret	c
	ld	c,(hl)
	push	bc
	call	INCPNT
	pop	bc
	ld	a,c
	cp	10
	scf
	ret	z
	ccf
	ret


;--- CHKNUM: Devuelve Cy=1 si A es un numero ("0"-"9")

CHKNUM:	cp	"0"
	ccf
	ret	nc
	cp	"9"+1
	ret


;--- POR10: Multiplica B por 10
;           Modifica AF

POR10:	ld	a,b
	sla	a
	sla	a
	sla	a
	add	b
	add	b
	ld	b,a
	ret


;--- CHKSEG: Comprueba si un segmento logico existe (normal o VRAM)
;    Entrada: A=Segmento
;    Devuelve Cy=1 si existe
;    Modifica AF, HL

CHKSEG:	call	CHKSLE
	ret	c
	call	CHKSLV
	ret


;--- NEXTP: Copia la siguiente porcion al bufer y actualiza PORCION, SEG y DIR
;    Devuelve Cy=1 si el siguiente segmento no existe, si no, Cy=0
;    Modifica todos los registros

NEXTP:	ld	a,(PORCION)
	or	a
	jr	z,NEXTP2

	ld	a,(SEG)
	inc	a
	call	CHKSEG
	ccf
	ld	a,-1
	ld	(OVF),a
	ret	c
	ld	a,(SEG)
	inc	a
	ld	(SEG),a

NEXTP2:	ld	a,(PORCION)
	cpl
	ld	(PORCION),a

	ld	hl,0
	or	a
	jr	z,NEXTP3
	set	5,h
NEXTP3:	ld	de,#2000
	ld	bc,#2000
	ld	a,(SEG)
	ld	ixh,a
	ld	a,#FF
	ld	ixl,a
	call	LDIRSS

	ld	hl,#A000
	ld	(DIR),hl
	xor	a
	ld	(OVF),a
	ret


;--- PREVP: Copia la porcion previa al bufer y actualiza PORCION, SEG y DIR
;    Devuelve Cy=1 si el segmento previo no existe (era 0), si no, Cy=0
;    Modifica todos los registros

PREVP:	ld	a,(PORCION)
	or	a
	jr	nz,PREVP2

	ld	a,(SEG)
	or	a
	scf
	ld	a,-1
	ld	(OVF),a
	ret	z
	ld	a,(SEG)
	dec	a
	ld	(SEG),a

PREVP2:	ld	a,(PORCION)
	cpl
	ld	(PORCION),a

	ld	hl,0
	or	a
	jr	z,PREVP3
	set	5,h
PREVP3:	ld	de,#2000
	ld	bc,#2000
	ld	a,(SEG)
	ld	ixh,a
	ld	a,#FF
	ld	ixl,a
	call	LDIRSS

	ld	hl,#A000
	ld	(DIR),hl
	xor	a
	ld	(OVF),a
	ret


;--- INCPNT: Incrementa el puntero y, si es necesario,
;            copia una nueva porcion al bufer.
;    Devuelve Cy=1 si el siguiente segmento no existe, si no, Cy=0
;    Devuelve el nuevo puntero en HL
;    Modifica todos los registros

INCPNT:	ld	hl,(DIR)
	inc	hl
	ld	(DIR),hl
	ld	a,h
	cp	#C0
	scf
	ccf
	ret	nz
	dec	hl
	ld	(DIR),hl

	call	NEXTP
	ld	hl,(DIR)
	ret


;--- DECPNT: Decrementa el puntero y, si es necesario,
;            copia una nueva porcion al bufer.
;    Devuelve Cy=1 si el siguiente segmento no existe, si no, Cy=0
;    Devuelve el nuevo puntero en HL
;    Modifica todos los registros

DECPNT:	ld	hl,(DIR)
	dec	hl
	ld	(DIR),hl
	ld	a,h
	cp	#9F
	scf
	ccf
	ret	nz
	inc	hl
	ld	(DIR),hl

	call	PREVP
	ld	hl,(DIR)
	ret


;--- CHKINIT: Comprueba si el puntero esta al principio
;    Devuelve Cy=1 si esta al principio, 0 si no

CHKINIT:	ld	hl,(ISEG)
	ld	de,(SEG)
	or	a
	sbc	hl,de
	ld	a,h
	or	l
	scf
	ret	z

	ld	hl,(IDIR+1)
	ld	de,(DIR+1)
	or	a
	sbc	hl,de
	ld	a,h
	or	l
	scf
	ret	z
	ccf
	ret


;***********************
;***  ZONA DE DATOS  ***
;***********************

ISEG:	db	-1	;Segmento de inicializacion
IDIR:	dw	0	;Direccion de inicializacion
IPORCION:	db	0
SEG:	db	-1	;Segmento actual
DIR:	dw	0	;Direccion actual
PORCION	db	0	;Porcion de segmento copiada (0:primera, -1:segunda)
OVF:	db	0	;Desbordamiento del puntero
OLDSEG:	db	0
OLDDIR:	dw	0
OLDPOR:	db	0
OLDCH:	db	0
CONTA:	db	0
