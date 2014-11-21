;Code to execute code in the LPE-Z380 card.

;==========================

	;--- zexe: ejecuta codigo en el Z380
	;    Version 1.0, por Konami Man, 3-2000

	org	#100

;--------------
;--- Macros ---
;--------------

Z380ST:	equ	#4010
ZDIR:	equ	#4011
ZVAL:	equ	#4015
ZDIR_M:	equ	#4016
ZBLON:	equ	#4018
ZLONG:	equ	#401A

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
	call	5

	ld	a,1
	ld	de,BUF
	call	EXTPAR
	jr	nc,OKPAR

NOPAR:	ld	de,USG_S
	jp	FINSTR

OKPAR:	call	BUSZ
	jp	OKBUSZ

PRES_S:	db	13,10,"LPE-Z380 code executor 1.0 - by Konami Man, 13-3-2000",13,10,13,10,"$"
USG_S:	db	"USAGE:   zexe <start address>",13,10
	db	"         Start address: 4 hex digits",13,10
	db	"         (code must be placed on the first 64K space)",13,10,13,10
	db	"Example: zexe 0A00",13,10,"$"


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

ZTEST:	LD	HL,TXDIR
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
	LD	A,(ZSLOT)	;Conecta Z380
	LD	H,&H40
	CALL	&H24
	RET
;
ISZ380:	DB	0	;0=Z380 NO ENCONTRADO, 255=Z380 ENCONTRADO
ZSLOT:	DB	0	;SUBSLOT/SLOT DONDE SE ENCONTRO EL Z380
TXDIR:	EQU	&H4020	;DIRECCION DONDE SE BUSCA EL TEXTO
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
	call	5


	;************************
	;*** EXTRAE DIRECCION ***
	;************************

	ld	a,1
	ld	de,BUF
	call	EXTPAR

	ld	ix,BUF
	call	EXTDIR2
	or	a
	jr	z,OKPAR1
	ld	(ZDIR),de

FININVP:	ld	de,INVP_S
	jp	FINSTR

INVP_S:	db	"ERROR: Invalid parameter.",13,10,"$"
OKPAR1:	;


	;***************************************
	;*** ESPERA A QUE EL Z380 ESTE LISTO ***
	;***************************************

	ld	a,(Z380ST)
	or	a
	jr	z,OKFREE

	ld	de,WAIT_S
	ld	c,9
	call	5

OKFREE:	ld	a,(Z380ST)
	or	a
	jr	nz,WAFREE
	jr	OKFREE

WAIT_S:	db	"Waiting for Z380 to be free...",13,10,"$"
EXE_S:	db	"Now Z380 is executing code...",13,10,"$"


	;*****************************************
	;*** EJECUTA CODIGO Y CUENTA EL TIEMPO ***
	;*****************************************

	ld	de,EXE_S
	ld	c,9
	call	5

	ld	de,0

	ld	a,3
	LD	(Z380ST),A	;ESCRIBE CODIGO COMANDO (1..254)

ZWAI2:	halt
	inc	de	;Contador del tiempo

	call	c,TOOLONG

	LD	A,(Z380ST)	;ESPERA A QUE Z380 ACABE (=0)
	AND	A
	JR	NZ,ZWAI2

	jr	OKEXE

TOOLONG:	ld	a,-1	;Mas de 65536 ints? No muestra tiempo.
	ld	(OVERF),a
	ret
OKEXE:	;


	;***********************************************
	;*** CONVIERTE TIEMPO A CADENA, Y LO MUESTRA ***
	;***********************************************


	ld	a,(OVERF)
	or	a
	jr	nz,OKTIME

	ld	hl,TIME_S
	ld	bc,#0532
	xor	a
	call	NUMTOASC

	ld	a,13
	ld	(TIME_S2),a

OKTIME:	ld	de,DONE_S
	ld	c,9
	call	5

	ld	c,0
	jp	5	;FIN

DONE_S:	db	"Done.",13,10
TIME_S2:	db	"$",10,"Execution time: "
TIME_S:	db	"      x 1/50 sec.",13,10,"$"


;--------------------------------------------------------------------------
;--------------------------------------------------------------------------
;--------------------------------------------------------------------------

	;Rutinas varias

;--- NOMBRE: NUMTOASC
;      Conversion de un entero de 16 bits a una cadena de caracteres
;    ENTRADA:    DE = Numero a convertir
;                HL = Buffer para depositar la cadena
;                B  = Numero total de caracteres de la cadena
;                     sin incluir signos de terminacion
;                C  = Caracter de relleno
;                     El numero se justifica a la derecha, y los
;                     espacios sobrantes se rellenan con el caracter (C).
;                     Si el numero resultante ocupa mas caracteres que
;                     los indicados en B, este registro es ignorado
;                     y la cadena ocupa los caracteres necesarios.
;                     No se cuenta el caracter de terminacion, "$" o 00,
;                     a efectos de longitud.
;                 A = &B ZPRFFTTT
;                     TTT = Formato del numero resultante
;                            0: decimal
;                            1: hexdecimal
;                            2: hexadecimal, comenzando con "&H"
;                            3: hexadecimal, comenzando con "#"
;                            4: hexadecimal, acabado en "H"
;                            5: binario
;                            6: binario, comenzando con "&B"
;                            7: binario, acabado en "B"
;                     R   = Rango del numero
;                            0: 0..65535 (entero sin signo)
;                            1: -32768..32767 (entero en complemento a dos)
;                               Si el formato de salida es binario,
;                               el numero se interpreta como entero de 8 bits
;                               y el rango es 0..255. Es decir, el bit R
;                               y el registro D son ignorados.
;                     FF  = Tipo de finalizacion de la cadena
;                            0: Sin finalizacion especial
;                            1: Adicion de un caracter "$"
;                            2: Adicion de un caracter 00
;                            3: Puesta a 1 del 7o bit del ultimo caracter
;                     P   = Signo "+"
;                            0: No agnadir un signo "+" a los numeros positivos
;                            1: Agnadir un signo "+" a los numeros positivos
;                     Z   = Ceros sobrantes
;                            0: Quitar ceros a la izquierda
;                            1: No quitar ceros a la izquierda
;    SALIDA:    Cadena a partir de (HL)
;               B = Numero de caracteres de la cadena que forman
;                   el numero, incluyendo el signo y el indicador
;                   de tipo si son generados
;               C = Numero de caracteres totales de la cadena
;                   sin contar el "$" o el 00 si son generados
;    REGISTROS: -
;    LLAMADAS:  -
;    VARIABLES: -

NUMTOASC:	push	af,ix,de,hl
	ld	ix,WorkNTOA
	push	af,af
	and	%00000111
	ld	(ix+0),a	;Tipo 
	pop	af
	and	%00011000
	rrca
	rrca
	rrca
	ld	(ix+1),a	;Fin 
	pop	af
	and	%11100000
	rlca
	rlca
	rlca
	ld	(ix+6),a	;Banderas: Z(cero), P(signo +), R(rango) 
	ld	(ix+2),b	;No. caracteres finales 
	ld	(ix+3),c	;Caracter de relleno 
	xor	a
	ld	(ix+4),a	;Longitud total 
	ld	(ix+5),a	;Longitud del numero 
	ld	a,10
	ld	(ix+7),a	;Divisor a 10 
	ld	(ix+13),l	;Buffer pasado por el usuario 
	ld	(ix+14),h
	ld	hl,BufNTOA
	ld	(ix+10),l	;Buffer de la rutina 
	ld	(ix+11),h

ChkTipo:	ld	a,(ix+0)	;Divisor a 2 o a 16, o dejar a 10 
	or	a
	jr	z,ChkBoH
	cp	5
	jp	nc,EsBin
EsHexa:	ld	a,16
	jr	GTipo
EsBin:	ld	a,2
	ld	d,0
	res	0,(ix+6)	;Si es binario esta entre 0 y 255 
GTipo:	ld	(ix+7),a

ChkBoH:	ld	a,(ix+0)	;Comprueba si hay que poner "H" o "B" 
	cp	7	;al final 
	jp	z,PonB
	cp	4
	jr	nz,ChkTip2
PonH:	ld	a,"H"
	jr	PonHoB
PonB:	ld	a,"B"
PonHoB:	ld	(hl),a
	inc	hl
	inc	(ix+4)
	inc	(ix+5)

ChkTip2:	ld	a,d	;Si el numero es 0 nunca se pone signo 
	or	e
	jr	z,NoSgn
	bit	0,(ix+6)	;Comprueba rango   
	jr	z,SgnPos
ChkSgn:	bit	7,d
	jr	z,SgnPos
SgnNeg:	push	hl	;Niega el numero 
	ld	hl,0	;Signo=0:sin signo; 1:+; 2:-   
	xor	a
	sbc	hl,de
	ex	de,hl
	pop	hl
	ld	a,2
	jr	FinSgn
SgnPos:	bit	1,(ix+6)
	jr	z,NoSgn
	ld	a,1
	jr	FinSgn
NoSgn:	xor	a
FinSgn:	ld	(ix+12),a

ChkDoH:	ld	b,4
	xor	a
	cp	(ix+0)
	jp	z,EsDec
	ld	a,4
	cp	(ix+0)
	jp	nc,EsHexa2
EsBin2:	ld	b,8
	jr	EsHexa2
EsDec:	ld	b,5

EsHexa2:	push	de
Divide:	push	bc,hl	;DE/(IX+7)=DE, resto A 
	ld	a,d
	ld	c,e
	ld	d,0
	ld	e,(ix+7)
	ld	hl,0
	ld	b,16
BucDiv:	rl	c
	rla
	adc	hl,hl
	sbc	hl,de
	jr	nc,$+3
	add	hl,de
	ccf
	djnz	BucDiv
	rl	c
	rla
	ld	d,a
	ld	e,c
	ld	a,l
	pop	hl,bc

ChkRest9:	cp	10	;Convierte el resto en caracter 
	jp	nc,EsMay9
EsMen9:	add	a,"0"
	jr	PonEnBuf
EsMay9:	sub	10
	add	a,"A"

PonEnBuf:	ld	(hl),a	;Pone caracter en buffer 
	inc	hl
	inc	(ix+4)
	inc	(ix+5)
	djnz	Divide
	pop	de

ChkECros:	bit	2,(ix+6)	;Comprueba si hay que eliminar ceros 
	jr	nz,ChkAmp
	dec	hl
	ld	b,(ix+5)
	dec	b	;B=no. de digitos a comprobar 
Chk1Cro:	ld	a,(hl)
	cp	"0"
	jr	nz,FinECeros
	dec	hl
	dec	(ix+4)
	dec	(ix+5)
	djnz	Chk1Cro
FinECeros:	inc	hl

ChkAmp:	ld	a,(ix+0)	;Coloca "#", "&H" o "&B" si es necesario 
	cp	2
	jr	z,PonAmpH
	cp	3
	jr	z,PonAlm
	cp	6
	jr	nz,PonSgn
PonAmpB:	ld	a,"B"
	jr	PonAmpHB
PonAlm:	ld	a,"#"
	ld	(hl),a
	inc	hl
	inc	(ix+4)
	inc	(ix+5)
	jr	PonSgn
PonAmpH:	ld	a,"H"
PonAmpHB:	ld	(hl),a
	inc	hl
	ld	a,"&"
	ld	(hl),a
	inc	hl
	inc	(ix+4)
	inc	(ix+4)
	inc	(ix+5)
	inc	(ix+5)

PonSgn:	ld	a,(ix+12)	;Coloca el signo 
	or	a
	jr	z,ChkLon
SgnTipo:	cp	1
	jr	nz,PonNeg
PonPos:	ld	a,"+"
	jr	PonPoN
	jr	ChkLon
PonNeg:	ld	a,"-"
PonPoN	ld	(hl),a
	inc	hl
	inc	(ix+4)
	inc	(ix+5)

ChkLon:	ld	a,(ix+2)	;Pone caracteres de relleno si necesario 
	cp	(ix+4)
	jp	c,Invert
	jr	z,Invert
PonCars:	sub	(ix+4)
	ld	b,a
	ld	a,(ix+3)
Pon1Car:	ld	(hl),a
	inc	hl
	inc	(ix+4)
	djnz	Pon1Car

Invert:	ld	l,(ix+10)
	ld	h,(ix+11)
	xor	a	;Invierte la cadena 
	push	hl
	ld	(ix+8),a
	ld	a,(ix+4)
	dec	a
	ld	e,a
	ld	d,0
	add	hl,de
	ex	de,hl
	pop	hl	;HL=buffer inicial, DE=buffer final 
	ld	a,(ix+4)
	srl	a
	ld	b,a
BucInv:	push	bc
	ld	a,(de)
	ld	b,(hl)
	ex	de,hl
	ld	(de),a
	ld	(hl),b
	ex	de,hl
	inc	hl
	dec	de
	pop	bc
	djnz	BucInv
ToBufUs:	ld	l,(ix+10)
	ld	h,(ix+11)
	ld	e,(ix+13)
	ld	d,(ix+14)
	ld	c,(ix+4)
	ld	b,0
	ldir
	ex	de,hl

ChkFin1:	ld	a,(ix+1)	;Comprueba si ha de acabar en "$" o en 0  
	and	%00000111
	or	a
	jr	z,Fin
	cp	1
	jr	z,PonDolar
	cp	2
	jr	z,PonChr0

PonBit7:	dec	hl
	ld	a,(hl)
	or	%10000000
	ld	(hl),a
	jr	Fin

PonChr0:	xor	a
	jr	PonDo0
PonDolar:	ld	a,"$"
PonDo0:	ld	(hl),a
	inc	(ix+4)

Fin:	ld	b,(ix+5)
	ld	c,(ix+4)
	pop	hl,de,ix,af
	ret

WorkNTOA:	defs	16
BufNTOA:	ds	10


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


;--- NOMBRE:  EXTDIR
;      Extrae una direccion de 16 bits en hexadecimal
;    ENTRADA: IX = Inicio de la cadena
;    SALIDA:  DE = Numero de 16 bits
;             A = Caracteres invalidos o cadena demasiado larga si <>0

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

EXTDFIN:	ld	a,(ix+8)
	cp	" "
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


OVERF:	db	0
