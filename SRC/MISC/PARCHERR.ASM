;This program allows to customize the BASIC error messages.
;See the "DATOS" section for details.

;==================================

	;Personalizador de errores del BASIC
	;Por Nestor Soriano (Konami Man), 3-1999


;*************************************************************************
;*                                                                       *
;*                        MACROS Y CONSTANTES                            *
;*                                                                       *
;*************************************************************************

KSETE:	equ	#F3FC
EXTBIO:	equ	#FFCA

;--- Saltos relativos

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

;--- Saltos absolutos

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
	endm

;--- Funciones del DOS

STROUT:	equ	#09
OPEN:	equ	#43
CLOSE:	equ	#45
READ:	equ	#48
GENV:	equ	#6B
TERM:	equ	#62
DOSVER:	equ	#6F


;*************************************************************************
;*                                                                       *
;*                         PROGRAMA PRINCIPAL                            *
;*                                                                       *
;*************************************************************************

	;--- Presentacion

	ld	de,PRESENT_S
	call	PRINT

	;--- Comprueba DOS 2

	ld	c,DOSVER
	call	5
	or	a
	ret	nz
	ld	a,b
	cp	2
	ld	de,NODOS2_S
	jpmn	ERROR

	;--- Obtiene las rutinas del mapeador

	ld	de,#0402
	call	EXTBIO
	ld	de,ALL_SEG
	ld	bc,#30
	ldir

	ld	hl,(CALLS+1)
	ld	(TOERR+1),hl

	;--- Reserva un segmento & lo conecta en pagina 2

	ld	a,1
	ld	b,0
	call	ALL_SEG
	ld	(RESEG),a
	ld	(TOERR+1),a
	ld	(NEWERR+3),a
	ld	de,NOFREE_S
	jp	c,ERROR

	call	GET_P2
	ld	(SEG_P2),a
	ld	a,(RESEG)
	call	PUT_P2

	ld	hl,#8000
	ld	de,#8001
	ld	bc,#3FFF
	ld	(hl),0
	ldir

	ld	hl,PARCHE
	ld	de,#8000
	ld	bc,ERRTABLE-#8000
	ldir

	;--- Abre el fichero y lo lee

	ld	de,RDFIL_S
	call	PRINT

	ld	a,1
	ld	de,#3000
	call	EXTPAR
	ld	de,USE_S
	jp	c,ERROR

	ld	de,#3000
	ld	c,OPEN
	xor	a
	call	5
	jp	nz,DOSERR
	ld	a,b
	ld	(FH),a

	ld	c,READ
	ld	de,BASEDIR
	ld	hl,16384-(BASEDIR-#8000)
	push	bc
	call	5
	pop	bc
	jp	nz,DOSERR

	ld	c,CLOSE
	call	5
	jp	nz,DOSERR

	ld	a,#FF
	ld	(FH),a

	;******************************************************
	;* PROCESA EL FICHERO Y CONSTRUYE LA TABLA DE ERRORES *
	;******************************************************

	ld	de,PROCFIL_S
	call	PRINT
	ld	ix,BASEDIR

NEXTLINE:	ld	hl,LINEA	;Siguiente linea: incrementa contador
	inc	(hl)

	call	GETCHAR	;Final del fichero?
	jp	z,OKPROC

	cp	13	;Se salta la linea si esta vacia
	jr	z,NEXTLINE

	cp	";"	;Se salta la linea si es un comentario
	jr	nz,NOCOMENT
SKIPCOMENT:	call	GETCHAR
	cp	13
	jr	nz,SKIPCOMENT
	jr	NEXTLINE

NOCOMENT:	dec	ix
	push	ix	;Extrae codigo de error
	pop	hl
	call	EXTNUM	;Error si:
	jp	c,LINERR	;- Numero>65535
	ld	a,b
	or	a
	jp	nz,LINERR	;- Numero>255
	ld	a,d
	or	a
	jp	z,LINERR	;- No es un numero

	ld	e,a
	ld	d,0	;Incrementamos IX hasta despues
	inc	de	;del numero y el caracter de separacion
	add	ix,de
	ld	a,(ix-1)
	cp	13	;Error si no hay mensaje
	jp	z,LINERR
	or	a
	jp	z,OKPROC

	ld	hl,ERRTABLE
	sla	c	;Establece el valor correspondiente
	rl	b	;en ERRTABLE
	add	hl,bc
	push	ix
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d

BUCNEXT:	ld	a,(ix)	;Pasamos a la linea siguiente
	call	GETCHAR
	jp	z,OKPROC
	cp	13
	jr	nz,BUCNEXT
	jp	NEXTLINE

	;**********************************************
	;* MODIFICACION DE LOS GANCHOS Y FINALIZACION *
	;**********************************************

OKPROC:	ld	hl,NEWERR
	ld	de,#FFB1
	ld	bc,5
	ldir

	ld	hl,TOERR
	ld	de,KSETE
	ld	bc,TOERREND-TOERR
	ldir

	ld	a,(SEG_P2)
	call	PUT_P2

	ld	de,INST_S
	call	PRINT
	ld	c,0
	jp	5

NEWERR:	jp	KSETE
	ds	2

TOERR:	ld	a,0
	call	#F224
	call	#8000
	ld	a,1
	call	#F224
	ld	a,#C1
	jp	#411F
TOERREND:	;


;*************************************************************************
;*                                                                       *
;*                           SUBRUTINAS                                  *
;*                                                                       *
;*************************************************************************

PRINT:	ld	c,STROUT
	jp	5

GETCHAR:	ld	a,(ix)	;Coge caracter saltandose el 10
	inc	ix	;Devuelve Z=1 si se llega al final
	cp	10
	jr	z,GETCHAR
	cp	#1A
	ret	z
	or	a
	ret

;--- Terminacion con error

DOSERR:	push	af	;Error del DOS al leer el fichero
	call	CIERRA
	ld	de,ERROR_S
	call	PRINT
	pop	bc
	ld	c,TERM
	jp	#0005

ERROR:	call	CIERRA	;Error general
	push	de
	ld	de,ERROR_S
	call	PRINT
	pop	de
	call	PRINT
	ld	c,0
	jp	5

LINERR:	ld	de,(LINEA)	;Error al procesar el fichero
	ld	hl,LINE_S
	ld	bc,#0500
	xor	a
	call	NUMTOASC
	ld	de,ERRLIN_S
	jr	ERROR

CIERRA:	ld	a,(RESEG)
	or	a
	ld	b,0
	call	nz,FRE_SEG

	ld	a,(SEG_P2)
	or	a
	call	nz,PUT_P2

	ld	a,(FH)
	cp	#FF
	ld	b,a
	ld	c,CLOSE
	call	nz,#0005
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

EXTNUM:	push	hl,ix
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


;--- NAME: EXTPAR
;      Extracts a parameter from command line
;    INPUT:   A  = Parameter number (first is 1)
;             DE = Buffer to put parameter
;    OUTPUT:  A  = Total number of parameter
;             CY = 1 -> The specified parameter does not exist
;                       B undefined, buffer unchanged
;             CY = 0 -> B = Paramter length (not including termination 0)
;                       Parameter from DE, terminated with 0
;    REGISTERS: -
;    CALLS:     -
;    VARIABLES: JR macros

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

;*************************************************************************
;*                                                                       *
;*                              DATOS                                    *
;*                                                                       *
;*************************************************************************

RESEG:	db	0
SEG_P2:	db	0
FH:	db	#FF
LINEA:	dw	0

ERROR_S:	db	27,"J*** ERROR: $"
NOFREE_S:	db	"No free segment on primary mapper!",13,10,"$"
NODOSM_S:	db	"No free memory on the DOS data segment!",13,10,"$"
NODOS2_S:	db	"DOS 2 is required!",13,10,"$"
RDFIL_S:	db	27,"JReading file...",#D,"$"
PROCFIL_S:	db	27,"JProcessing data...",#D,"$"
INST_S:	db	27,"JInstalled!",13,10,"$"
ERRLIN_S:	db	"Invalid data in file (line "
LINE_S:	db	"     )",13,10,"$"
PRESENT_S:	db	13,10,"NestorErrores 1.0 - "
	db	"By Konani Man, 3-1999",13,10,10,"$"
USE_S:	db	#D,"Usage: NERR <errors filename>",13,10,10
	db	"       Errors filename format:",13,10,10
	db	"       ;Comments",13,10
	db	"       0,<text for ",34,"in",34,">",13,10
	db	"       <code>,<text for error with this code>",13,10
	db	"       <code>,<text> ...",13,10,"$"
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


;*************************************************************************
;*                                                                       *
;*                              PARCHE                                   *
;*                                                                       *
;*************************************************************************

ERRLIN:	equ	#F6B3
ERRFLG:	equ	#F414
BASEDIR:	equ	#8400

PARCHE:	org	#8000

;*** NUEVO CODIGO DE ERROR ***

	pop	hl	;CALL    #FFB1
	ld	(RETDIR),hl
	XOR	A
	CALL	#7987
	LD	HL,(#F419)
	LD	A,H
	OR	L
	JR	Z,J4087
	LD	A,(#F41B)
	LD	(HL),A
	LD	HL,#0000
	LD	(#F419),HL
J4087:	EI
	LD	HL,(#F41C)
	LD	(#F6B3),HL
	LD	A,H
	AND	L
	INC	A
	JR	Z,J4096
	LD	(#F6B5),HL
J4096:	LD	BC,D40A4
	JR	J409E
	LD	BC,#411E
J409E:	LD	HL,(#F6B1)
	JP	#62F0
D40A4:	POP	BC
	LD	A,E
	LD	C,E
	LD	(#F414),A
	LD	HL,(#F6AF)
	LD	(#F6B7),HL
	EX	DE,HL
	LD	HL,(#F6B3)
	LD	A,H
	AND	L
	INC	A
	JR	Z,J40C0
	LD	(#F6BE),HL
	EX	DE,HL
	LD	(#F6C0),HL
J40C0:	LD	HL,(#F6B9)
	LD	A,H
	OR	L
	EX	DE,HL
	LD	HL,#F6BB
	JR	Z,J40D3
	AND	(HL)
	JR	NZ,J40D3
	DEC	(HL)
	EX	DE,HL
	JP	#4620
J40D3:	XOR	A
	LD	(HL),A
	LD	E,C
	CALL	#7323
	LD	HL,#3D75
	CALL	#FEFD
	LD	A,E
	CP	#3C
	JR	NC,J40EC
	CP	#32
	JR	NC,J40EE
	CP	#1A
	JR	C,J40F1
J40EC:	LD	A,#2F
J40EE:	SUB	#18
	LD	E,A
J40F1:	CALL	#485D
	INC	HL
	DEC	E
	JR	NZ,J40F1
	PUSH	HL
	LD	HL,(#F6B3)
	EX	(SP),HL
	CALL	#FF02
	PUSH	HL
	CALL	#00D2
	POP	HL
	LD	A,(HL)
	CP	#3F
	JR	NZ,J4110
	POP	HL
	LD	HL,#3D75
	JR	J40EC
J4110:	CALL	SHOWERR	;#6678
	LD	A,#07
	RST	#18
	POP	HL
	LD	A,H
	AND	L
	INC	A
	push	hl
	CALL	NZ,SHOWLINE	;#340A
	pop	hl
	LD	A,#C1
	ld	ix,(RETDIR)
	push	ix
	ret
	;jp      #411F

RETDIR:	dw	0

;*** MUESTRA EL NUEVO MENSAJE DE ERROR ***

SHOWERR:	ld	ix,ERRTABLE
	ld	bc,(ERRFLG-1)
	ld	b,0
	sla	c
	rl	b
	add	ix,bc
	ex	de,hl	;DE = Cadena del error original
	ld	l,(ix)
	ld	h,(ix+1)	;HL = Cadena del error
	ld	a,l
	or	h	;El error no tiene cadena definida?
	jp	nz,PRINTA2

	;--- Error no definido: comprobamos si es "unprintable"

	push	de
	pop	hl	;HL = Cadena del error original
	ld	a,(de)
	cp	"U"
	jp	nz,#6678
	inc	de
	ld	a,(de)
	cp	"n"
	jp	nz,#6678
	inc	de
	ld	a,(de)
	cp	"p"
	jp	nz,#6678

	;--- El error es "Unprintable": comprobamos si hay error 23 def.

	ld	ix,ERRTABLE+23*2
	ld	e,(ix)
	ld	d,(ix+1)
	ld	a,d
	or	e
	jp	z,#6678
	ex	de,hl
	jp	PRINTA2

;*** MUESTRA "EN LINEA" ***

SHOWLINE:	ld	a," "
	call	#A2
	ld	hl,(ERRTABLE)
	ld	a,h
	or	l
	jr	z,OKIN
	ld	hl,IN_S
OKIN:	call	PRINTA2
	ld	a," "
	call	#A2
	jp	#3412

IN_S:	db	"in",13

;*** IMPRIME CADENA EN HL ***

PRINTA2:	ld	a,(hl)
	cp	13
	ret	z
	push	hl
	call	#A2
	pop	hl
	inc	hl
	jr	PRINTA2

ENLINS:	dw	0
ERRTABLE:	dw	0

	;org     #FFB1
	;jp      #c000
