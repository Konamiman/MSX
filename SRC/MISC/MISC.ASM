;Miscellaneous routines of all kind.

;====================

;                ***** RUTINAS VARIAS *****
;
;               /// Por Konami Man, 1996 \\\

	org	#100

;
;
; ------------------
; --- Constantes ---
; ------------------

SI:	equ	1
NO:	equ	0

CALSLT:	EQU	#001C	;Llama a una subrutina en un slot 
EXPTBL:	EQU	#FCC1	;Tabla de expansion de los slots  
NEWPAD:	EQU	#01AD	;(SUBROM) Lectura del raton 
EXBRSA:	EQU	#FAF8	;Slot de la SUB-ROM  
XSAVE:	EQU	#FAFE	;Offset X del raton 
YSAVE:	EQU	#FB00	;Offset Y del raton 

;--------------
;--- Macros ---
;--------------

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

; ---------------------
; ----- Variables -----
; ---------------------
;
; -----------------------
; --- Tablas de salto ---
; -----------------------

;--- Rutinas aritmeticas

DIVISION:	jp	_DIVISION	;Division de 16 bits   
COMP:	jp	_COMP	;Compara HL y DE en complemento a 2  

;--- Entrada/Salida

GMOUSE:	jp	_GMOUSE	;Lectura del raton  
RDPSG:	jp	_RDPSG	;Lectura de un registro del PSG  
WRPSG:	jp	_WRPSG	;Escritura en un registro del PSG  
BIOS:	jp	_BIOS	;Llamada a una subrutina BIOS 
SUBBIOS:	jp	_SUBBIOS	;Llamada a una subrutina SUB-BIOS 

;--- Manipulacion de cadenas

NUMTOASC:	jp	_NUMTOASC	;Conversion de un entero en cadena ASCII
EXTPAR:	jp	_EXTPAR	;Extraccion de un par. de linea comando
CONVHOR:	jp	_CONVHOR	;Conversion de una hora a cadena ASCII
CONVDAT:	jp	_CONVDAT	;Conversion de una fecha a una cadena ASCII
EXTNUM:	jp	_EXTNUM	;Conversion de un numero en cadena ASCII
INSTR:	jp	_INSTR	;Busqueda de una cadena incluida en otra

;-------------------
;----- Rutinas -----
;-------------------

; Formato de la cabecera de las rutinas:

; --- NOMBRE: La etiqueta que identifica la rutina.
;       Explicacion de la funcion de la rutina.
;     ENTRADA:   Incluye los registros a cargar y las acciones a realizar
;                antes de llamar a la rutina.
;     SALIDA:    Incluye los datos devueltos en registros
;                y las acciones realizadas no explicadas tras el nombre.
;     REGISTROS: Registros modificados por la rutina. No incluye los de salida.
;     LLAMADAS:  Subrutinas llamadas por la rutina.
;     VARIABLES: Variables y constantes externas a la rutina usadas por esta
;                y/o por alguna de las subrutinas llamadas.



;--- NOMBRE: DIVID
;      Division 16 bits por 16 bits
;    ENTRADA:   HL = dividendo
;               DE = divisor
;    SALIDA:    DE = cociente
;               BC = resto
;    REGISTROS: BC
;    LLAMADAS:  -
;    VARIABLES: -

_DIVISION:	push	hl,af
	ld	a,h
	ld	c,l

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

	ld	d,a
	ld	e,c
	ld	b,h
	ld	c,l
	pop	af,hl
	ret

;--- NOMBRE: COMP
;      Comparacion de HL con DE (16 bits en complemento a 2)
;    ENTRADA:   HL, DE = numeros a comparar
;    SALIDA:     C, NZ si HL > DE
;               NC,  Z si HL = DE
;               NC, NZ si HL < DE
;    REGISTROS: -
;    VARIABLES: -
;    LLAMADAS:  -

_COMP:	push	hl
	or	a
	sbc	hl,de
	pop	hl
	jp	p,HMAYD
HMEND:	scf
	ccf
	ret
HMAYD:	scf
	ret

;--- NOMBRE: GMOUSE
;      Lectura del raton a traves de la SUB-ROM
;    ENTRADA:   A = puerto del raton a leer
;    SALIDA:    H = desplazamiento X
;               L = desplazamiento Y
;               D = #FF si se ha pulsado el boton 1, 0 si no
;               E = #FF si se ha pulsado el boton 2, 0 si no
;               A = #FF si se ha pulsado algun boton, 0 si no (A = D or E)
;    REGISTROS: BC, IX, IY
;    LLAMADAS:  CALSLT, RDPSG, WRPSG
;    VARIABLES: EXBRSA, NEWPAD, XSAVE, YSAVE, NEWPAD

_GMOUSE:	ex	af,af

	ld	a,(EXBRSA)	;Conectamos slot SUB-ROM   
	ld	iyh,a
	ld	ix,NEWPAD

	ex	af,af	;Recuperamos puerto   
	push	af	;Guardamos puerto para GTTRIG   
	sla	a	;Si A=1 => lo transforma en 12   
	or	11	;Si A=2 => lo transforma en 15   
	inc	a

	call	CALSLT	;Pedimos los datos del raton   
	di

RDBOT:	pop	af	;Recuperamos puerto   
	or	a
	rrca
	rrca
	rrca
	and	%01000000
	ex	af,af

	ld	a,15
	call	RDPSG	;Preparamos para leer puerto A o B   
	and	%10001111
	ld	b,a
	ex	af,af
	or	b
	ld	e,a
	ld	a,15
	call	WRPSG

	ld	a,14	;Leemos puerto   
	call	RDPSG

	push	af
	bit	4,a
	ld	a,0
	ld	b,0
	jr	nz,B1NOPUL
B1PUL:	cpl
B1NOPUL:	ld	d,a
	or	b
	ld	b,a

	pop	af
	bit	5,a
	ld	a,0
	jr	nz,B2NOPUL
B2PUL:	cpl
B2NOPUL:	ld	e,a
	or	b
	ld	b,a

COMPREG:	ld	a,(XSAVE)	;HL indica los desplazamientos en X e Y 
	ld	h,a
	ld	a,(YSAVE)
	ld	l,a

	ld	a,b
	ret

;--- NOMBRE: RDPSG
;      Lectura de un puerto del PSG
;    ENTRADA:   A = Puerto
;    SALIDA:    A = Dato
;    REGISTROS: -
;    LLAMADAS:  -
;    VARIABLES: -

_RDPSG:	out	(#a0),a
	in	a,(#a2)
	ret

;--- NOMBRE: WRPSG
;      Escritura en un puerto del PSG
;    ENTRADA:   A = puerto
;               E = Dato
;    SALIDA:    -
;    REGISTROS: -
;    VARIABLES: -

_WRPSG:	out	(#a0),a
	ld	a,e
	out	(#a1),a
	ret

;--- NOMBRE: BIOS
;      Llamada a una subrutina de la BIOS
;    ENTRADA:   IX = direccion
;    SALIDA:    Depende de la rutina
;    REGISTROS: A, IYh + los modificados por la rutina llamada
;    LLAMADAS:  CALSLT
;    VARIABLES: EXPTBL

_BIOS:	ld	a,(EXPTBL)
	ld	iyh,a
	jp	CALSLT

;--- NOMBRE: SUBBIOS
;      Llamada a una subrutina de la SUB-BIOS
;    ENTRADA:   IX = direccion
;    SALIDA:    Depende de la rutina
;    REGISTORS: A + los modificados por la rutina llamada
;    LLAMDAS:   CALSLT
;    VARIABLES: EXBRSA

_SUBBIOS:	ld	a,(EXBRSA)
	ld	iyh,a
	jp	CALSLT

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

_NUMTOASC:	push	af,ix,de,hl
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
	ld	a,b	;***
	or	a	;*** Faltaba esto!
	jr	z,ToBufUs	;***
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

_EXTPAR:	or	a	;Volvemos con error si A = 0
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

;--- NOMBRE: CONVHOR
;      Conversion de una hora tal como la da la funcion del DOS GET TIME (#2C)
;      en una cadena ASCII de 5 caracteres tipo hh:mm o h:mm
;    ENTRADA:   H  = horas (0..23)
;               L  = minutos (0..59)
;               DE = buffer para depositar la cadena ASCII
;    SALIDA:    Cadena a partir de (DE)
;    REGISTROS: -
;    LLAMADAS:  NUMTOASC
;    VARIABLES: -

_CONVHOR:	push	af,bc,hl,de,hl
	ex	de,hl	;HL=buffer, DE=hora 
	ld	e,d
	ld	d,0
	ld	bc,#0220
	ld	a,%00011000
	push	af
	call	NUMTOASC	;(HL)="HHxxx" 

	inc	hl
	inc	hl
	ld	a,":"
	ld	(hl),a	;(HL)="HH:xx" 
	inc	hl
	pop	af
	pop	de
	ld	d,0
	ld	bc,#0230
	call	NUMTOASC	;(HL)="HH:MM" 

	pop	de,hl,bc,af
	ret

;--- NOMBRE: CONVDAT
;      Convirsion de una fecha tal como la da la funcion del DOS GET DATE (#2A)
;      en una cadena ASCII de 8 caracteres, tipo dd-mm-yy
;    ENTRADA:    HL = agno, 1980..2079
;                D  = mes, 1..12
;                E  = dia, 1..31
;                IX = buffer en el que dejar la cadena convertida
;    SALIDA:     Cadena a partir de (IX)
;                Esta rutina no detecta fechas incorrectas
;    REGISTROS:  -
;    LLAMADAS:   NUMTOASC
;    VARIABLES:  -

_CONVDAT:	push	af,hl,bc,de,de
CONVAGNO:	ex	de,hl	;DE=agno a convertir 
	push	ix
	pop	hl
	inc	hl
	inc	hl
	inc	hl	;HL=inicio buffer+3 
	inc	hl
	ld	b,4
	ld	a,%00011000
	call	NUMTOASC	;(HL)="xxxxAAAA" 
	ld	a,"-"
	inc	hl
	ld	(hl),a	;(HL)="xxxxA-AA" 

CONVMES:	pop	de
	push	de
	ld	e,d
	ld	d,0	;DE=mes a convertir 
	dec	hl
	dec	hl
	ld	bc,#0230
	ld	a,%00011000
	call	NUMTOASC	;(HL)="xxxMM-AA" 
	dec	hl
	ld	a,"-"
	ld	(hl),a	;(HL)="xx-MM-AA" 

CONVDIA:	pop	de
	ld	d,0	;DE=dia a convertir 
	dec	hl
	dec	hl
	ld	bc,#0230
	ld	a,%00011000
	call	NUMTOASC	;(HL)="DD-MM-AA" 

	pop	de,bc,hl,af
	ret

;--- NOMBRE: EXTNUM
;      Extraccion de un numero de 5 digitos almacenado en formato ASCII
;    ENTRADA:    HL = Dir. de comienzo de la cadena ASCII
;    SALIDA:     CY-BC = numero de 17 bits
;                D  = numero de digitos que forman el numero
;                     El numero se considera extraido
;                     al encontrar un caracter no numerico,
;                     o cuando se han extraido cinco digitos.
;                E  = primer caracter incorrecto (o sexto digito)
;                A  = error:
;                     0 => Sin error
;                     1 => El numero tiene mas de 5 digitos.
;                          CY-BC contiene entonces el numero formado por
;                          los cinco primeros digitos
;    REGISTROS:  -
;    LLAMADAS:   -
;    VARIABLES:  -

_EXTNUM:	push	hl,ix
	ld	ix,ACA
	res	0,(ix)
	set	1,(ix)
	ld	bc,0
	ld	de,0
BUSNUM:	ld	a,(hl)	;Salta a FINEXT si el caracter no es 
	ld	e,a	;IXh = ultimo caracter leido por ahora 
	cp	"0"	;un numero, o si es el sexto caracter 
	jr	c,FINEXT
	cp	"9"+1
	jr	nc,FINEXT
	ld	a,d
	cp	5
	jr	z,FINEXT
	call	POR10

SUMA:	push	hl	;BC = BC + A 
	push	bc
	pop	hl
	ld	bc,0
	ld	a,e
	sub	"0"
	ld	c,a
	add	hl,bc
	call	c,BIT17
	push	hl
	pop	bc
	pop	hl

	inc	d
	inc	hl
	jr	BUSNUM

BIT17:	set	0,(ix)
	ret
ACA:	db	0	;b0: num>65535. b1: mas de 5 digitos 

FINEXT:	ld	a,e
	cp	"0"
	call	c,NODESB
	cp	"9"+1
	call	nc,NODESB
	ld	a,(ix)
	pop	ix,hl
	srl	a
	ret

NODESB:	res	1,(ix)
	ret

POR10:	push	de,hl	;BC = BC * 10 
	push	bc
	push	bc
	pop	hl
	pop	de
	ld	b,3
ROTA:	sla	l
	rl	h
	djnz	ROTA
	call	c,BIT17
	add	hl,de
	call	c,BIT17
	add	hl,de
	call	c,BIT17
	push	hl
	pop	bc
	pop	hl,de
	ret

;--- NOMBRE: INSTR
;      Busqueda de una cadena incluida en otra
;    ENTRADA:   HL = Inicio cadena principal
;               * A  = 0 -> DE = Inicio cadena buscada, acabada en #00
;                 A <> 0 -> A  = Caracter buscado
;               * B  = 0 -> C  = Caracter de terminacion de la cadena principal
;                 B <> 0 -> B  = Longitud de la cadena principal
;               * CY = 0 -> Distinguir mayusculas y minusculas
;                 CY = 1 -> No distinguir mayusculas y minusculas
;    SALIDA:    B  = 0 -> Cadena buscada no encontrada, HL inalterado
;               B <> 0 -> Cadena buscada encontrada:
;                         B  = Posicion en la cadena principal
;                         HL = Inicio cadena encontrada
;    REGISTROS: F
;    LLAMADAS:  -
;    VARIABLES: -

_INSTR:	push	af
	jr	c,NOCASE
SICASE:	ld	a,#ff
	ld	(CASEFLAG),a	;CASEFLAG=0: Distingue may/min
	jr	INSTR0
NOCASE:	xor	a
	ld	(CASEFLAG),a	;CASEFLAG=#FF: No distingue
INSTR0:	pop	af

	or	a
	ld	(CHARA),a
	push	af
	ld	a,c
	push	af,ix,de,hl
CHKIFA:	jr	z,NOCHAR
CHARENA:	ld	de,CHARA+1	;Si hemos pasado un caracter en A 
	xor	a	;lo copiamos en nuestro propio bufer 
	ld	(de),a	;y lo buscamos en modo normal 
	dec	de

NOCHAR:	ld	a,b
	or	a
	jr	nz,BNOCERO
BCERO:	push	hl
	ld	b,-1
BUSFIN:	inc	b	;Si B=0, busca el caracter de terminacion 
	ld	a,(hl)	;y coloca en B la longitud de la cadena 
	inc	hl
	cp	c
	jr	nz,BUSFIN
	pop	hl

BNOCERO:	dec	de	;Mientras la comparacion entre (HL) e (IX 
	push	de
	inc	b	;sea positiva, se incrementa HL e IX y se 
	dec	hl
	ld	c,0

COMPA:	inc	hl
	inc	de
	inc	c
	ld	a,(de)
	or	a
	jr	z,FOUND
	call	COMPRUT	;cp      (hl)
	call	nz,RESETDE
	djnz	COMPA
	jr	NOTF

RESETDE:	pop	ix
	pop	de
	push	de
	push	ix
	ld	a,1
	cp	c
	ld	c,0
	ret	z
	dec	hl
	inc	b
	ret

FOUND:	pop	de	;C=numero de caracteres coincidentes+1 
	dec	c
	ld	b,0
	or	a
	sbc	hl,bc	;HL=principio de la cadena hallada 
	pop	de	;DE=principio de la cadena original 
	push	hl	;(pasado a la subrutina en HL) 
	sbc	hl,de
	ld	b,l	;L=principio respecto inicio 
	inc	b
ENDSTR:	pop	hl,de,ix,af
	ld	c,a
	pop	af
	ret

NOTF:	pop	de,hl
	ld	b,0
	push	hl
	jr	ENDSTR

COMPRUT:	push	af	;Compara A con (HL)
	ld	a,(CASEFLAG)	;Solo modifica las banderas
	inc	a	;Si CASENFLAG=#FF, modifica CY
	jr	z,COMPNOD	;aleatoriamente

COMPD:	pop	af	;Comparacion con distincion may/min
	cp	(hl)
	ret	z
CHKENYMAY:	cp	165	;Enye mayuscula
	jr	nz,CHKESMAY
	dec	a
	cp	(hl)
	ld	a,165
	ret
CHKESMAY:	cp	"A"
	jr	c,RETDIST
	cp	"Z"+1
	jr	c,ESMAY

CHKENYMIN:	cp	164	;Enye minuscula
	jr	nz,CHKESMIN
	inc	a
	cp	(hl)
	ld	a,164
	ret
CHKESMIN:	cp	"z"+1
	jr	nc,RETDIST
	cp	"a"
	jr	c,RETDIST
ESMIN:	and	%11011111	;Convertimos a may. y volvemos a comparar
	cp	(hl)
	ret
ESMAY:	or	%00100000	;Convertimos a min. y volvemos a comparar
	cp	(hl)
	ret

COMPNOD:	pop	af	;Comparacion sin distincion may/min
	cp	(hl)
	ret

RETDIST:	or	a	;Vuelve con Z=0
	ret	nz
	inc	a
	or	a
	ld	a,0
	ret

CASEFLAG:	db	0
CHARA:	db	0
