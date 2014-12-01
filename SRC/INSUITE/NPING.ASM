; PING tool for InterNestor Suite

;===================

	;--- NestorPing 0.2
	;    Uso: NPING <dir. ip>

	.label	20

;******************************
;***                        ***
;***   MACROS, CONSTANTES   ***
;***                        ***
;******************************

nesman:	macro	@f
	ld	c,@f
	ld	de,#2202
	call	#FFCA
	endm

print:	macro	@d
	ld	de,@d
	ld	c,_STROUT
	call	5
	endm

_DIRIO:	equ	#06
_STROUT:	equ	#09
_CONST:	equ	#0B
_TERM:	equ	#62

ENASLT:	equ	#0024

	;--- Llamadas al modulo PPP

PPP_QUEUES:	equ	#800C
PPP_IPS:	equ	#8018
PPP_NETSTAT:	equ	#800F

	;--- Llamadas al modulo IP

IP_QUEUES:	equ	#800C
IP_TABLES:	equ	#801E

	org	#100

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



;******************************
;***                        ***
;***   PROGRAMA PRINCIPAL   ***
;***                        ***
;******************************

	org	#100


;----------------------------------
;---  Comprobaciones iniciales  ---
;----------------------------------

	;--- Comprueba si hay parametros. Si no, muestra
	;    ayuda y termina

	print	PRESEN_S

	ld	a,1
	ld	de,BUFER
	call	EXTPAR
	jr	nc,HAYPARS

TERMINFO:	print	INFO_S
	jp	TERMOK2

HAYPARS:	;

	;--- Comprueba que NestorMan este instalado, si no
	;    devuelve un error y termina

	xor	a
	nesman	1
	or	a
	jr	nz,OKNMAN1

	print	NONMAN_S	;Esta instalado?
	print	NEEDNMAN_S
	jp	TERMOK2

OKNMAN1:	ld	hl,#0200
	ex	de,hl
	call	COMP
	jr	c,OKNMAN2

	print	BADNMAN_S	;Es al menos version 1.2?
	print	NEEDNMAN_S
	jp	TERMOK2
OKNMAN2:	;

	;--- Comprueba que InterNestor este instalado, si no
	;    devuelve un error y termina

	nesman	32
	ld	(INS_SLOT),a
	or	a
	jr	nz,OKINS

	print	NOINS_S
	jp	TERMOK2

OKINS:	ld	(INS_SLOT),a
	push	de
	ld	a,b
	nesman	3
	ld	a,c
	ld	(INS_SEG2),a
	pop	de
	ld	a,e
	nesman	3
	ld	a,c
	ld	(INS_SEG3),a

	;--- Obtiene rutinas del mapeador

	ld	de,#0402	;Obtiene rutinas del mapeador
	call	#FFCA
	ld	de,ALL_SEG
	ld	bc,#30
	ldir

	;--- Obtiene la IP desde la linea de parametros

kk:	ld	a,1
	ld	de,BUFER
	call	EXTPAR
	ld	hl,BUFER
	ld	c,b
	ld	b,0
	add	hl,bc
	ld	(hl),"."

	ld	de,IP_REMOTE
	ld	hl,BUFER
	ld	b,4

IPLOOP:	push	bc,de
	call	EXTNUM
	jp	c,ERRIP	;Comprueba que sea un numero
	or	a	;entre 0 y 255 y acabado en 0
	jp	nz,ERRIP
	ld	a,b
	or	a
	jp	nz,ERRIP
	ld	a,e
	cp	"."
	jp	nz,ERRIP

	ld	a,c
	ld	c,d
	ld	b,0
	pop	de
	ld	(de),a
	add	hl,bc
	inc	hl
	inc	de
	pop	bc
	djnz	IPLOOP

	jr	IPOK

ERRIP:	print	INVIP_S
	jp	TERMOK2
IPOK:	;

	;--- Conecta el segmento de NestorPPP en pagina 2

	ld	a,(INS_SLOT)
	ld	h,#80
	call	ENASLT
	ei
	ld	a,(INS_SEG2)
	call	PUT_P2

	;--- Comprueba que haya alguna conexion en curso

	call	PPP_NETSTAT
	jr	c,CONOK

	print	NOCON_S
	jp	TERMOK
CONOK:	;

	;--- Obtiene la direccion IP local

	xor	a
	call	PPP_IPS
	ld	a,h
	ld	(IP_LOCAL),a
	ld	a,l
	ld	(IP_LOCAL+1),a
	ld	a,d
	ld	(IP_LOCAL+2),a
	ld	a,e
	ld	(IP_LOCAL+3),a

	;--- Conecta el segmento de NestorIP en pagina 2

	ld	a,(INS_SEG3)
	call	PUT_P2

	;--- Obtiene colas de entrada y salida

	ld	a,255	;Salida
	call	IP_QUEUES
	ld	(OUT_QUEUE_DIR),a
	ld	(OUT_QUEUE_DIR+1),hl
	ld	a,1	;Entrada para ICMP
	call	IP_QUEUES
	ld	(IN_QUEUE_DIR),a
	ld	(IN_QUEUE_DIR+1),hl

	;--- Envia el primer paquete

	print	PRESS_S
	call	SEND_PAQ
	jr	KEYOK

	;--- Espera a que se pulse una tecla, o a que llegue
	;    un paquete

KEY:	ld	e,#FF
	ld	c,_DIRIO
	call	5
	cp	13	;Enter: envia un paquete
	call	z,SEND_PAQ	;Otra tecla: termina
	jr	z,KEYOK
	or	a
	jp	nz,TERMOK
KEYOK:	;

	ld	a,(IN_QUEUE_DIR)	;Espera a que llegue un paquete
	ld	ix,(IN_QUEUE_DIR+1)
	ld	b,1
	ld	h,3
	ld	iy,BUFER-1
	nesman	25
	jr	c,KEY

	;--- Paquete recibido: comprueba que sea correcto

	ld	a,(BUFER-1)
	ld	c,a
	ld	b,0
	ld	hl,BUFER
	add	hl,bc	;HL apunta ahora a los datos

	ld	a,(hl)	;Es echo reply?
	or	a
	jr	nz,KEY
	push	hl
	pop	ix

	ld	d,(ix+6)	;Correcto: prepara el num. seq.
	ld	e,(ix+7)
	ld	hl,SEQR_S
	ld	b,1
	ld	a,%1000
	call	NUMTOASC

	ld	a,(BUFER+8)
	ld	e,a
	ld	d,0
	ld	hl,TTL_S
	ld	b,1
	xor	a
	call	NUMTOASC

kkk:	print	RCV_S
	print	ANDTTL_S
	jp	KEY

	;--- Subrutina de envio de un paquete

SEND_PAQ:	push	af
	call	_SEND_PAQ
	pop	af
	ret

	; Prepara paquete

_SEND_PAQ:	ld	hl,IP_REMOTE
	ld	de,DESTIN_AD
	ld	bc,4
	ldir

	ld	a,(SEQ+1)	;Establece num. de secuencia
	ld	(ICMP_SEQ),a
	ld	a,(SEQ)
	ld	(ICMP_SEQ+1),a

	ld	hl,0
	ld	(ICMP_CHKSUM),hl	;Calcula checksum del ICMP
	ld	ix,ICMP_START
	ld	bc,4
	call	CALC_CHKSUM
	dec	de
	ld	a,e
	cpl
	ld	(ICMP_CHKSUM),a
	ld	a,d
	cpl
	ld	(ICMP_CHKSUM+1),a

	; Mete paquete en la cola

	ld	a,(OUT_QUEUE_DIR)
	ld	ix,(OUT_QUEUE_DIR+1)
	ld	b,3
	ld	hl,PAQ_END-PAQ_START
	ld	iy,PAQ_START
	nesman	24

	;Muestra mensaje

	ld	de,(SEQ)
	ld	hl,SEQS_S
	ld	b,1
	xor	a
	call	NUMTOASC
	print	SENT_S

	ld	hl,(SEQ)
	inc	hl
	ld	(SEQ),hl

	ret



;******************************
;***                        ***
;***   RUTINAS AUXILIARES   ***
;***                        ***
;******************************

;--- NOMBRE: COMP
;      Comparacion de HL con DE (16 bits en complemento a 2)
;    ENTRADA:   HL, DE = numeros a comparar
;    SALIDA:     C, NZ si HL > DE
;                C,  Z si HL = DE
;               NC, NZ si HL < DE
;    REGISTROS: -
;    VARIABLES: -
;    LLAMADAS:  -

COMP:	push	hl
	or	a
	sbc	hl,de
	pop	hl
	jp	p,HMAYD
HMEND:	scf
	ccf
	ret
HMAYD:	scf
	ret



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

;--- Terminacion OK

TERMOK:	ld	a,(#F343)
	ld	h,#80
	call	ENASLT
	ld	a,1
	call	PUT_P2

TERMOK2:	ld	bc,#0062
	jp	5


;--- Checksum

; Compute checksum
;
; On entry:
;	IX -> block to checksum
;	BC = number of halfwords to checksum
;
; On exit:
;	DE = checksum + 1
;	Z set if DE = 0 (i.e. checksum good)
;	A, BC and other flags corrupt

CALC_CHKSUM:	ld	de,0

	push	hl
	ex	de,hl
	push	ix
	or	a
	push	af

CALC_CHKLOOP:
	pop	af	; 3N
	ld	e,(ix + 0)	; 5N
	ld	d,(ix + 1)	; 5N
	adc	hl,de	; 4N
	push	af	; 3N
	inc	ix	; 3N
	inc	ix	; 3N
	dec	bc	; 2N
	ld	a,b	; 1N
	or	c	; 1N
	jr	nz,CALC_CHKLOOP	; 3/2N -> 33N per halfword

	pop	af
	ld	de,1
	adc	hl,de
	ex	de,hl

	pop	ix
	pop	hl

	ret

;--- Rutinas de acceso al mapeador

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



;****************************
;***                      ***
;***   DATOS, VARIABLES   ***
;***                      ***
;****************************

INS_SLOT:	db	0
INS_SEG2:	db	0
INS_SEG3:	db	0
IN_QUEUE_DIR:	ds	3
OUT_QUEUE_DIR:	ds	3
IP_LOCAL:	ds	4
IP_REMOTE:	ds	4
SEQ:	dw	0

;--- Cadenas

PRESEN_S:	db	13,10,"NestorPing 0.2",13,10
	db	"By Konami Man, 7-2001",13,10,10,"$"
INFO_S:	db	"Use: NPING <IP address>",13,10,"$"
NONMAN_S:	db	"ERROR: NestorMan not installed",13,10,"$"
BADNMAN_S:	db	"ERROR: Invalid NestorMan version!",13,10,"$"
NEEDNMAN_S:	db	"NestorMan version 1.2 or higher is needed.",13,10,"$"
NOINS_S:	db	"ERROR: InterNestor suite is not installed",13,10,"$"
INVIP_S:	db	"ERROR: Invalid IP address. Must be xxx.xxx.xxx.xxx, with 0<=xxx<=255",13,10,"$"
NOCON_S:	db	"ERROR: No PPP opened connection currently",13,10,"$"
PRESS_S:	db	"*** Press ENTER to send additional echo requests",13,10
	db	"*** Press any other key to exit",13,10,10,"$"
SENT_S:	db	"- Sent echo request with sequence number "
SEQS_S:	db	"     ",13,10,"$"
RCV_S:	db	"! Received echo reply with sequence number "
SEQR_S:	db	"     $"
ANDTTL_S:	db	" and TTL="
TTL_S:	db	"     ",13,10,"$"

;--- Paquete ICMP

PAQ_START:	;
DESTIN_AD:	db	0,0,0,0
	db	1
	db	4,255	;TTL=255
	db	0

ICMP_START:	db	8	;Type=echo request
	db	0	;Codigo
ICMP_CHKSUM:	db	0,0	;Checksum ICMP
ICMP_ID:	db	0,0	;Identificador
ICMP_SEQ:	db	0,0	;Num de secuencia
ICMP_END:	;
PAQ_END:	;

	db	0,0
BUFER:	;
