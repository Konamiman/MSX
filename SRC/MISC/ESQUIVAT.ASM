;This is my first and only attempt at developing a game.
;I started it for a 1KByte game contest (MSXDev?) but didn't finish it.

;You just control a spaceship in a fast moving horizontal scrolling screen,
;and must avoid crashing against the scenario. That's all.

;===========================================

	;--- Esquivator
	;    By Konami Man, 3-11-2002


;*********************
;***  MACROS, etc  ***
;*********************

WRTVDP:	equ	#0047
RDVRM:	equ	#004A
SETWRT:	equ	#0053
FILVRM:	equ	#0056
LDIRMV:	equ	#0059
LDIRVM:	equ	#005C
CHGCLR:	equ	#0062
INITXT:	equ	#006C
INIT32:	equ	#006F
BREAKX:	equ	#00B7

T32NAM:	equ	#F3BD
T32CGP:	equ	#F3C1
T32ATR:	equ	#F3C3
T32PAT:	equ	#F3C5
FORCLR:	equ	#F3E9
BAKCLR:	equ	#F3EA
BDRCLR:	equ	#F3EB

H_TIMI:	equ	#FD9F

SCROLL_SPEED:	equ	2	;A menor valor, mayor velocidad


;************************
;***  INICIALIZACION  ***
;************************

	org	#A000

	ld	a,(#FCC1)
	ld	h,0
	call	#24

;--- Screen 1

	call	INIT32
	ld	a,1
	ld	(BAKCLR),a
	ld	(BDRCLR),a
	ld	a,5
	ld	(FORCLR),a
	call	CHGCLR

;--- Inicializa caracteres

	ld	hl,(#F3C1)
	call	SETWRT

	xor	a
	ld	b,8
LOOP_VDP1:	out	(#98),a
	djnz	LOOP_VDP1

	cpl
	ld	b,8
LOOP_VDP2:	out	(#98),a
	djnz	LOOP_VDP2

	ld	b,16
	ld	hl,CHAR_DATA
	ld	c,#98
	otir
	ld	b,16
	ld	hl,CHAR_DATA+15
	otdr

;--- Borra la pantalla

	ld	hl,(T32NAM)
	ld	bc,32*24
	xor	a
	call	FILVRM

;--- Inicializa sprite nave

	ld	a,(#F3E0)
	or	2
	ld	b,a
	ld	c,1	;16x16
	call	WRTVDP

	; ld      hl,#B000
	; ld      de,#B001
	; ld      bc,8*4*4-1
	; ld      (hl),0
	; ldir

	; ld      hl,SPDATA1       ;Compone la forma
	; ld      de,#B000
	; ld      bc,10
	; ldir
	; ld      hl,#FF88
	; ld      (#B000+8*2+4),hl
	; ld      hl,#80F8
	; ld      (#B000+8*2+6),hl
	; ld      hl,#70C0
	; ld      (#B000+8*6+3),hl
	; ld      hl,SPDATA2
	; ld      de,#B000+8*9
	; ld      bc,6
	; ldir
	; ld      hl,#F080
	; ld      (#B000+8*11+3),hl
	; ld      a,#FF
	; ld      (#B000+8*11+5),a
	; ld      hl,SPDATA3
	; ld      de,#B000+8*12+4
	; ld      bc,6
	; ldir
	; ld      hl,#F0FC
	; ld      (#B000+8*14+6),hl

	ld	hl,(T32PAT)	;Forma
	call	SETWRT
	ld	hl,SPRITEDATA
	ld	b,32
	ld	c,#98
	otir

	ld	hl,#1B00+3	;(T32ATR)
	call	SETWRT
	ld	a,15
	out	(#98),a	;Colores
	; ld      hl,#1B00+4*1+3
	; call    SETWRT
	; ld      a,8
	; out     (#98),a
	; ld      hl,#1B00+4*2+3
	; call    SETWRT
	; ld      a,15
	; out     (#98),a
	; ld      hl,#1B00+4*3+3
	; call    SETWRT
	; ld      a,4
	; out     (#98),a


;--- Inicializa gancho del reloj

	ld	hl,H_TIMI
	ld	de,OLD_TIMI
	ld	bc,5
	ldir
	di
	ld	a,#C3
	ld	(H_TIMI),a
	ld	hl,MAIN
	ld	(H_TIMI+1),hl
	ei

	ld	(STACK),sp

;--- Bucle del programa

LOOP:	call	BREAKX
	ei
	jr	nc,LOOP

TODO_FIN:	di
	ld	hl,OLD_TIMI
	ld	de,H_TIMI
	ld	bc,5
	ldir
	ei

	call	INITXT

	ld	sp,(STACK)
	ret


;*************************
;***  BUCLE PRINCIPAL  ***
;*************************

MAIN:	ld	a,(INT_FLAG)
	or	a
	ret	nz

	cpl
	ld	(INT_FLAG),a

	;--- Movimiento de la nave

	ld	a,(#FBE2)
	ld	de,0
CHK_RIGHT:	rla
	jr	c,CHK_DOWN
	inc	d
CHK_DOWN:	rla
	jr	c,CHK_UP
	inc	e
CHK_UP:	rla
	jr	c,CHK_LEFT
	dec	e
CHK_LEFT:	rla
	jr	c,CHK_END
	dec	d
CHK_END:	;

	ld	hl,(SHIP_XY)

	ld	a,d
	add	h
	bit	7,a
	jr	z,X_OK1
	xor	a
	jr	X_OK
X_OK1:	cp	60
	jr	c,X_OK
	ld	a,60
X_OK:	ld	h,a

	ld	a,e
	add	l
	bit	7,a
	jr	z,Y_OK1
	xor	a
	jr	Y_OK
Y_OK1:	cp	45
	jr	c,Y_OK
	ld	a,45
Y_OK:	ld	l,a

	ld	(SHIP_XY),hl
	ex	de,hl
	sla	d
	sla	e
	sla	d
	sla	e
	call	PUTSPRITE

	;--- Scroll de la pantalla

	ld	a,(CONTADOR)
	dec	a
	ld	(CONTADOR),a
	or	a
	jr	nz,NO_SCROLL

	ld	a,SCROLL_SPEED
	ld	(CONTADOR),a

	ld	b,24
	ld	hl,(T32NAM)
	inc	hl
LOOP_SC:	push	bc,hl
	ld	de,#B100
	ld	bc,31
	call	LDIRMV
	pop	de
	push	de
	dec	de
	ld	hl,#B100
	ld	bc,31
	call	LDIRVM
	call	GET_CHAR
	out	(#98),a
	pop	hl
	ld	bc,32
	add	hl,bc
	pop	bc
	djnz	LOOP_SC

NO_SCROLL:	;

	;--- Comprueba si debajo de la nave hay decorado,
	;    en ese caso termina

	ld	de,(SHIP_XY)	;Hay que dividir las coordenadas
	srl	d	;por 8, pero ya se almacenan
	srl	e	;divididas por 4

	ld	l,e
	ld	h,0
	add	hl,hl
	add	hl,hl
	add	hl,hl
	add	hl,hl
	add	hl,hl
	ld	e,d
	ld	d,0
	add	hl,de	;HL = Y*32 + X

	ld	de,(T32NAM)
	add	hl,de

	call	RDVRM	;Los cuatro bloques que hay
	or	a	;bajo la nave han de ser cero
	jr	nz,CHOQUE
	in	a,(#98)
	or	a
	jr	nz,CHOQUE
	ld	bc,32
	add	hl,bc
	call	RDVRM
	or	a
	jr	nz,CHOQUE
	in	a,(#98)
	or	a
	jr	z,FIN_INT

CHOQUE:	di
	ld	hl,OLD_TIMI
	ld	de,H_TIMI
	ld	bc,5
	ldir

	;--- Fin de la interrupcion

FIN_INT:	xor	a
	ld	(INT_FLAG),a
	ret


;*************************
;**  SUBRUTINAS, DATOS  **
;*************************

;--- GET_CHAR: Devuelve un byte nuevo para el scroll

GET_CHAR:	ld	a,(ROW_POINTER)
	cp	24
	jr	nc,NEW_ROW

	;No linea nueva: coge dato de la antigua

GET_CHAR2:	ld	hl,(ROW_POINTER)
	ld	a,(hl)
	inc	hl
	ld	(ROW_POINTER),hl
	ret

	;Linea nueva

NEW_ROW:	ld	a,(REPETIS)
	dec	a
	ld	(REPETIS),a
	jp	nz,NO_ESCAPE4

	ld	a,1
	ld	(REPETIS),a
	ld	hl,(DATA_POINTER)
	ld	a,(hl)
	ld	b,a
	and	%11100000
	cp	%11100000
	jr	nz,NO_ESCAPE

	;Era caracter de escape

	ld	a,b
	and	%00011111
	;jp      z,TODO_FIN       ;Fin?

	cp	2
	jr	z,SET_REPETI

	inc	hl
	ld	a,(hl)
	ld	(REPETIS),a
	inc	hl
	ld	(DATA_POINTER),hl

	ld	hl,#B000	;Linea completamente blanca
	ld	(ROW_POINTER),hl
	ld	de,#B001
	ld	bc,23
	ld	(hl),0
	ldir
	jr	GET_CHAR2

SET_REPETI:	inc	hl
	ld	a,(hl)
	inc	hl
	ld	(REPETIS),a

	;Era linea normal
	;Aqui, HL contiene DATA_POINTER

NO_ESCAPE:	ld	b,3
	ld	de,#B000

NO_ESCAPE2:	push	bc
	ld	a,(hl)
	ld	c,a
	and	%11100000
	rlca
	rlca
	rlca
	inc	hl
	push	hl
	push	de
	pop	hl
	ld	(hl),a
	inc	de
	ld	a,c
	and	%00011111
	dec	a
	jr	z,NO_ESCAPE3
	ld	c,a
	ld	b,0
	ldir
NO_ESCAPE3:	pop	hl

	pop	bc
	djnz	NO_ESCAPE2

	ld	(DATA_POINTER),hl
NO_ESCAPE4:	ld	hl,#B000
	ld	(ROW_POINTER),hl
	jp	GET_CHAR2




;--- Datos del scroll comprimidos
;
;    Cada columna consta de 3 bytes del tipo:
;    %ttt ddddd
;    ttt = tipo de patron:
;          0 = Vacio
;          1 = Lleno
;          2 = Cuesta arriba
;          3 = Cuesta arriba inversa
;          4 = Cuesta abajo
;          5 = Cuesta abajo inversa
;          7 = Escape
;    ddddd = numero de repeticiones
;    Si es escape, ddddd es:
;    0: Fin
;    1: Columna completamente vacia, repeticion segun el byte siguiente
;    2: Repetir la columna situada a continuacion segun el byte siguiente

SCROLL_DATA:	db	%101 00001
	db	%000 10110
	db	%010 00001

	db	%101 00010
	db	%000 10100
	db	%010 00001

	db	226,20
	db	%001 00010
	db	%000 10100
	db	%001 00010

	db	%101 00011
	db	%000 10010
	db	%010 00011

	db	%101 00100
	db	%000 10000
	db	%010 00100

	db	226,5
	db	%001 01010
	db	%000 00100
	db	%001 01010

	db	225,5	;Primera columna
	db	226,3
	db	%000 00101
	db	%001 10010
	db	%001 00001

	db	225,13
	db	226,10
	db	%001 10010	;Segunda columna
	db	%001 00011
	db	%000 00011

	db	225,12


	;Empieza el tunel cuesta arriba

	db	%011 10100
	db	%000 00101
	db	%010 00001

	db	%011 10011
	db	%000 00101
	db	%010 00001

	db	%011 10010
	db	%000 00101
	db	%010 00011

	db	%011 10001
	db	%000 00101
	db	%010 00100

	db	%011 10000
	db	%000 00101
	db	%010 00101

	db	%011 01111
	db	%000 00101
	db	%010 00110

	db	%011 01110
	db	%000 00101
	db	%010 00110


	;db      %111 00000

;--- Subrutinas, datos

STACK:	dw	0
ROW_POINTER:	dw	#B018
DATA_POINTER:	dw	SCROLL_DATA
INT_FLAG:	db	0
CONTADOR:	db	5
LAST_CHAR:	db	0
REPETIS:	db	1

CHAR_DATA:	db	%1
	db	%11
	db	%111
	db	%1111
	db	%11111
	db	%111111
	db	%1111111
	db	%11111111

	db	%11111111
	db	%11111110
	db	%11111100
	db	%11111000
	db	%11110000
	db	%11100000
	db	%11000000
	db	%10000000

SPRITEDATA:	db	#80,#E0,#70,#7F,#7F,#BF,#BF,#BF
	db	#78,#E0,0,0,0,0,0,0
	db	0,0,0,0,#88,#FF,#F8,#80
	db	0,0,0,0,0,0,0,0


	;PUTSPRITE: DE=XY

PUTSPRITE:	ld	hl,(T32ATR)
	call	SETWRT
	ld	a,e
	out	(#98),a
	ld	a,d
	out	(#98),a
	ret

SHIP_XY:	db	20,5

OLD_TIMI:	;


;SPDATA1:          db      #80,#E0,#70,#7F,#7F,#BF,#BF,#BF
;                  db      #78,#E0
;SPDATA2:          db      #80,#e0,#70,#ff,#1f,#01,0,0
;SPDATA3:          db      #e0,#fe,#7f,#3f,#1e,#18


	;db      0,0,0,0,#88,#FF,#F8,#80
	;db      0,0,0,0,0,0,0,0

	;db      0,0,0,0,0,0,0,0
	;db      0,0,0,0,0,0,0,0
	;db      0,0,0,#c0,#70,0,0,0
	;db      0,0,0,0,0,0,0,0

	;db      0,0,0,0,0,0,0,0
	;db      0,0,0,#80,#f0,#ff,0,0
	;db      0,0,0,0,0,0,0,0

	;db      0,0,0,0,#e0,#fe,#7f,#3f
	;db      #1E,#18,0,0,0,0,0,0
	;db      0,0,0,0,0,0,#fc,#f0
	;db      0,0,0,0,0,0,0,0

