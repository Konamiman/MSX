;Mapped memory listing tool for DOS 2.
;Needs NUMTOASC.ASM appended at the end.

;============================
	
	;Sacadero de la memoria para DOS 2 
	;Por Konami Man, 26-5-96 
	;Necesita NUMTOASC al final 

	;La salida por pantalla ser tal que asi (ejemplo): 

; Memorytestator - by Konami Man, 26-5-1996
;
; Mappers found: 2
;
;          Slot             Total           Reserved             Free
;          ----             -----           --------             ----
;
;            2              1024K                32K             992K
;          3-2               128K               128K               0K
;
;          All              1136K               160K             996K
;
;  Ramdisk size: 128K
;  MemMan version: 2.42
;  TPA end address: #D706 - TPA size is 53K

	; Macros y EQUs 

jri:	macro	@a
	jr	z,@a
	endm

jrni:	macro	@a
	jr	nz,@a
	endm

jrmn:	macro	@a
	jr	c,@a
	endm

jrmy:	macro	@a
	jr	z,$+4
	jr	nc,$+4
	endm

jrmni:	macro	@a
	jr	c,$+4
	jr	z,@a
	endm

jrmyi:	macro	@a
	jr	nc,@a
	endm

DIRIO:	equ	#06
CONOUT:	equ	#02
TERM:	equ	#62
READ:	equ	#48
WRITE:	equ	#49
REDIR:	equ	#70
STROUT:	equ	#09
DOSVER:	equ	#6F
RAMD:	equ	#68
EXTBIO:	equ	#FFCA

	org	#100

	; *** Comprobacion de la version del DOS y presentacion

MEM:	ld	c,DOSVER
	call	5
	ld	a,b
	cp	2
	jrmyi	OKDOS2

	ld	c,STROUT	;Terminamos si no hay DOS 2
	ld	de,STR11
	jp	5

OKDOS2:	ld	c,WRITE	;Sacamos presentacion
	ld	b,1
	ld	de,STR1
	ld	hl,(STR1LEN)
	call	5

	; *** Obtencion de la tabla del mapeador 

	ld	de,#0401
	call	EXTBIO
	push	hl
	pop	ix
	ld	iy,_SLOT

	; *** Calculo del numero de mapeadores 

	ld	e,0
	ld	bc,8
	push	ix
OTROMAP:	ld	a,(ix)
	or	a
	jr	z,OKNUMAP
	inc	e
	add	ix,bc
	jr	OTROMAP
OKNUMAP:	pop	ix
	ld	a,e
	ld	(NUMMAP),a

	ld	d,0	;Convertimos a ASCII 
	ld	hl,_NUMMAP
	ld	b,2
	ld	c," "
	ld	a,%11000
	call	NUMTOASC

	ld	c,WRITE	;Sacamos numero de mapeadores 
	ld	b,1
	ld	de,STR10
	ld	hl,(STR10LEN)
	call	5

	ld	c,WRITE	;Sacamos linea de indice  
	ld	b,1
	ld	de,STR2
	ld	hl,(STR2LEN)
	call	5

	; *** Bucle de salida de los datos 

	; Slot 

BUCDAT:	ld	a,(ix)
	or	a
	jp	z,NOMASLOT
	bit	7,a
	jr	nz,EXPSLOT

NOEXP:	add	a,"0"	;Slot no expandido 
	ld	(iy+2),a
	ld	a," "
	ld	(iy),a
	ld	(iy+1),a
	jr	OKSLOT

EXPSLOT:	push	af	;Slot expandido 
	and	%11
	add	"0"
	ld	(iy),a
	ld	a,"-"
	ld	(iy+1),a
	pop	af
	and	%1100
	srl	a
	srl	a
	add	"0"
	ld	(iy+2),a
OKSLOT:	; 

	; Memoria total 

	ld	a,(ix+1)
	ld	d,0	;Multiplicamos el no. de segmentos por 1024 
	ld	e,a
	ld	b,4
MULTI:	sla	e
	rl	d
	djnz	MULTI

	ld	hl,(TOTAL)	;Aadimos a la cantidad de memoria total 
	add	hl,de
	ld	(TOTAL),hl

	ld	hl,_TOTAL	;Transformamos numero a ASCII 
	ld	b,5
	ld	c," "
	ld	a,%11000
	call	NUMTOASC

	; Memoria ocupada 

	ld	a,(ix+3)
	ld	b,a
	ld	a,(ix+4)
	add	a,b
	ld	d,0	;Multiplicamos el no. de segmentos por 1024  
	ld	e,a
	ld	b,4
MULTI2:	sla	e
	rl	d
	djnz	MULTI2

	ld	hl,(OCUP)	;Aadimos a la cantidad de memoria total 
	add	hl,de
	ld	(OCUP),hl

	ld	hl,_OCUP	;Transformamos numero a ASCII 
	ld	b,5
	ld	c," "
	ld	a,%11000
	call	NUMTOASC

	; Libre 

	ld	a,(ix+2)
	ld	d,0	;Multiplicamos el no. de segmentos por 1024 
	ld	e,a
	ld	b,4
MULTI3:	sla	e
	rl	d
	djnz	MULTI3

	ld	hl,(LIBRE)	;Aadimos a la cantidad de memoria total 
	add	hl,de
	ld	(LIBRE),hl

	ld	hl,_LIBRE	;Transformamos numero a ASCII 
	ld	b,5
	ld	c," "
	ld	a,%11000
	call	NUMTOASC

	; Sacamos cadena de datos de ese mapeador y volvemos a empezar 

	ld	c,WRITE
	ld	b,1
	ld	de,STR3
	ld	hl,(STR3LEN)
	call	5

	ld	bc,8	;Apuntamos al siguiente mapeador 
	add	ix,bc
	jp	BUCDAT

	; *** Sacamos datos totales de la memoria 

NOMASLOT:	ld	de,(TOTAL)	;Memoria total 
	ld	hl,_TOTAL2
	ld	b,5
	ld	c," "
	ld	a,%11000
	call	NUMTOASC

	ld	de,(OCUP)
	ld	hl,_OCUP2	;Memoria ocupada 
	ld	b,5
	ld	c," "
	ld	a,%11000
	call	NUMTOASC

	ld	de,(LIBRE)
	ld	hl,_LIBRE2	;Memoria libre 
	ld	b,5
	ld	c," "
	ld	a,%11000
	call	NUMTOASC

	ld	c,WRITE
	ld	b,1
	ld	de,STR4
	ld	hl,(STR4LEN)
	call	5

	;*** Sacamos datos del RAMDISK 

	ld	c,RAMD
	ld	b,#ff
	call	5

	ld	a,b
	or	a
	jr	nz,SIRAMD

NORAMD:	ld	c,WRITE	;Cadena "No hay Ramdisk" 
	ld	b,1
	ld	de,STR5
	ld	hl,(STR5LEN)
	call	5
	jp	OKRDISK

SIRAMD:	ld	d,0	;Multiplicamos el no. de segmentos por 1024 
	ld	e,b
	ld	b,4
MULTI4:	sla	e
	rl	d
	djnz	MULTI4

	ld	hl,_RAMD	;Transformamos numero a ASCII 
	ld	b,4
	ld	c," "
	ld	a,%11000
	call	NUMTOASC

	ld	c,WRITE	;Sacamos tamagno del Ramdisk 
	ld	b,1
	ld	de,STR6
	ld	hl,(STR6LEN)
	call	5
OKRDISK:	; 

	;*** Sacamos datos del MEMMAN 

	ld	de,#4D1E
	ld	a,34
	call	EXTBIO
	cp	34+"M"
	jri	SIMM

NOMM:	ld	c,WRITE	;Cadena "No hay RAMDISK" 
	ld	b,1
	ld	de,STR7
	ld	hl,(STR7LEN)
	call	5
	jr	OKMM

SIMM:	ld	a,d	;Componemos version del MemMan 
	add	a,"0"
	ld	(_MMVER),a
	ld	a,e
	add	a,"0"
	ld	(_MMVER+2),a

	ld	c,WRITE	;Sacamos version del MEMMAN 
	ld	b,1
	ld	de,STR8
	ld	hl,(STR8LEN)
	call	5
OKMM:	; 

	;*** Sacamos datos sobre TPA 

	ld	de,(6)
	ld	hl,_TPAEND	;Transformamos numero a ASCII 
	ld	b,6
	ld	c," "
	ld	a,%11010
	call	NUMTOASC

	ld	b,10	;Dividimos por 1024
MULTI5:	srl	d
	rr	e
	djnz	MULTI5

	ld	hl,_TPASIZ	;Transformamos numero a ASCII 
	ld	b,2
	ld	c," "
	ld	a,%11000
	call	NUMTOASC

	ld	c,WRITE	;Sacamos datos de la TPA
	ld	b,1
	ld	de,STR9
	ld	hl,(STR9LEN)
	call	5

	;*** Fin del programa 

	ld	c,TERM
	jp	5

	;*** Zona de datos 

NUMMAP:	db	0
TOTAL:	dw	0
OCUP:	dw	0
LIBRE:	dw	0

STR0:	db	"DOS 2 needed!"
STR1:	db	13,10,"Memorytestator (the judgement byte)"
	db	" - by Konami Man, 26-5-1996",13,10
	db	13,10
STR1LEN:	dw	$-STR1

STR2:	db	"          Slot            Memory           Reserved     "
	db	"       Free",13,10
	db	"          ----            ------           --------     "
	db	"       ----",13,10,13,10
STR2LEN:	dw	$-STR2

STR3:	db	"           "
_SLOT:	ds	15," "
_TOTAL:	db	"     K"
	ds	13," "
_OCUP:	db	"     K"
	ds	10," "
_LIBRE:	db	"     K",13,10
STR3LEN:	dw	$-STR3

STR4:	db	13,10,"Total:     "
_SLOT2:	ds	15," "
_TOTAL2:	db	"     K"
	ds	13," "
_OCUP2:	db	"     K"
	ds	10," "
_LIBRE2:	db	"     K",13,10,13,10
STR4LEN:	dw	$-STR4

STR5:	db	"RAM disk not installed",13,10
STR5LEN:	dw	$-STR5

STR6:	db	"RAM disk size: "
_RAMD:	db	"    K",13,10
STR6LEN:	dw	$-STR6

STR7:	db	"MemMan not installed",13,10
STR7LEN:	dw	$-STR7

STR8:	db	"MemMan version: "
_MMVER:	db	" . ",13,10
STR8LEN:	dw	$-STR8

STR9:	db	"TPA end address: "
_TPAEND:	ds	6," "
	db	" - TPA size is "
_TPASIZ:	db	"  K",13,10
STR9LEN:	dw	$-STR9

STR10:	db	"Mappers found: "
_NUMMAP:	db	"  ",13,10,13,10
STR10LEN:	dw	$-STR10

STR11:	db	13,10,"Memorytestator (the judgement byte)"
	db	" - by Konami Man, 26-5-1996",13,10,13,10
	db	"DOS 2 required!! Hasta la vista, baby!",13,10,"$"
