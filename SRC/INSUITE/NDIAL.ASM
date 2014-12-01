; Telephone dialer for InterNestor Suite

;========================

	;--- NestorDial - Marcador telefonico
	;    Por Konami Man, 7-2002
	;    Uso: NDIAL <numero> [/p] [/s] [/c:comando_comando_...]
	;         /p: Usar ATDT en vez de ATDT
	;         /s: Mostrar envios y respuestas del modem
	;         /c: Comandos adicionales para el modem
	;             antes de marcar el numero

	;En 0.2: Use de las variable NDIAL_CONNECT y USEINSERROR


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

;Funciones del DOS

_CONOUT:	equ	#02
_DIRIO:	equ	#06
_STROUT:	equ	#09
_CONST:	equ	#0B
_TERM:	equ	#62
_OPEN:	equ	#43
_CLOSE:	equ	#45
_READ:	equ	#48
_PARSE:	equ	#5B
_CHKCHR:	equ	#5D
_EXPLAIN:	equ	#66
_GENV:	equ	#6B
_SENV:	equ	#6C



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
	ld	de,BUFNUM
	call	EXTPAR
	jr	nc,HAYPARS

TERMINFO:	print	INFO_S
	jp	TERMOK

HAYPARS:	;

	;--- Comprueba si la variable USEINSERROR existe,
	;    en caso contrario no comprueba INSERROR

	ld	c,_GENV
	ld	hl,USEINSERR_S
	ld	de,BUFPAR
	ld	b,255
	call	5

	ld	a,(BUFPAR)
	or	a
	jr	z,NOERROR

	;--- Comprueba si la variable INSERROR existe,
	;    en ese caso termina

	ld	c,_GENV
	ld	hl,INSERR_S
	ld	de,BUFPAR
	ld	b,255
	call	5

	ld	a,(BUFPAR)
	or	a
	jr	z,NOERROR

	;Muestra "error returned by program tal"

	print	ERRETBY_S
	ld	c,_GENV
	ld	hl,INSERRP_S
	ld	de,BUFPAR2
	ld	b,255
	call	5

	ld	a,(BUFPAR2)
	or	a
	ld	de,UNK_S
	jr	z,OK_UNK
	ld	de,BUFPAR2
OK_UNK:	call	PRINTZ

	;Imprime el error y termina

	print	DOSPUN_S
	ld	de,BUFPAR
	call	PRINTZ

	print	TORESET_S

	jp	TERMOK
NOERROR:	;

	;--- Comprueba que el driver FOSSIL este instalado

	call	GetFossil
	jr	z,OKFOS

	ld	de,NOFOS_S
	jp	TERMERR
OKFOS:	;

	;--- Comprueba si NestorMan esta instalado.
	;    En ese caso, comprueba si INS esta instalado,
	;    y en ese caso lo pausa.

	xor	a	;NestorMan instalado?
	nesman	1
	or	a
	jr	z,OKNMAN

	nesman	32	;INS instalado?
	or	a
	jr	z,OKNMAN
	ld	a,(ix)
	ld	(INSSTAT),a

	ld	(ix),0	;Pausa INS

OKNMAN:	call	F_Init
	call	F_Flush_Buf

	;--- Copia a BUFCOM al menos ATZ y ATE0
	;    (si hay un parametro "c", se copiaran mas comandos)

	ld	hl,ATZ_S
	ld	de,BUFCOM
	ld	bc,10	;"ATZ",0,"ATE0",0,0
	ldir

	;--- Comprueba los parametros adicionales

	ld	a,2
PAR_LOOP:	push	af
	ld	de,BUFPAR
	call	EXTPAR
	jr	c,OK_PARS	;No hay mas parametros?
	ld	a,b
	ld	(LONPAR),a

	ld	a,(BUFPAR)	;Si el primer char no es "/", error
	cp	"/"
	ld	de,INVPAR_S
	jp	nz,TERMERR

	ld	a,(BUFPAR+1)	;Decide accion segun el parametro
	or	%00100000
	cp	"p"
	jr	z,PAR_P
	cp	"s"
	jr	z,PAR_S
	cp	"c"
	jr	z,PAR_C

	ld	de,INVPAR_S
	jp	TERMERR

	;Parametro "p"

PAR_P:	ld	a,"P"
	ld	(DIALCOM+3),a
	jr	NEXTPAR

	;Parametro "s"

PAR_S:	ld	a,#FF
	ld	(SHOW),a
	jr	NEXTPAR

	;Parametro "c"

PAR_C:	ld	a,(BUFPAR+2)
	cp	":"
	ld	de,INVPAR_S
	jp	nz,TERMERR

	ld	hl,BUFPAR+3
	ld	de,BUFCOM+9
	ld	a,(LONPAR)
	dec	a
	dec	a
	;dec     a
	;inc     a
	ld	c,a
	ld	b,0
	ldir
	xor	a
	ld	(de),a	;Anyade un 0 extra al final

	ld	hl,BUFCOM+10	;Copia los comandos en BUFCOM,
PAR_C_LOOP:	ld	a,(hl)	;cada uno acabado en 0, tras
	or	a	;ATZ y ATE0
	jr	z,NEXTPAR

	cp	"_"
	jr	nz,PAR_C_LEND
	xor	a
	ld	(hl),a

PAR_C_LEND:	inc	hl
	jr	PAR_C_LOOP

	;Siguiente parametro

NEXTPAR:	pop	af
	inc	a
	jr	PAR_LOOP

OK_PARS:	pop	af

	;--- Obtiene la cadena "NDIAL_CONNECT" a CONNECT_S

	ld	hl,CONNENV_S
	ld	de,CONNECT_S
	ld	b,16
	ld	c,_GENV
	call	5

	ld	a,(CONNECT_S)
	or	a
	jr	nz,OK_CONNENV
	ld	a,"C"
	ld	(CONNECT_S),a
OK_CONNENV:	;

	;--- Envia los comandos de inicializacion al modem

	print	PRESS_S
	print	CURON_S

	ld	hl,BUFCOM
INIT_LOOP:	ld	a,(hl)
	or	a
	jr	z,OK_INITMOD
	call	SENDCOM
	push	hl
	call	WAITCODE
	pop	hl
	jr	INIT_LOOP
OK_INITMOD:	;

	;--- Si el primer caracter del numero es ".",
	;    no se marca el numero

	ld	a,(BUFNUM)
	cp	"."
	jr	nz,OKNUM1

	print	NODIAL_S
	jp	TERMOK
OKNUM1:	;

	;--- Marca el numero y espera CONNECT u otra respuesta

	print	DIALING_S	;Imprime "dialing"
	ld	de,BUFNUM
	call	PRINTZ
	print	PUNTOS_S

	ld	hl,DIALCOM	;Marca numero
	call	SENDCOM

	ld	a,#FF	;La respuesta se mostrara
	ld	(SHOW),a	;en cualquier caso

	call	WAITREPLY	;Espera respuesta

	ld	hl,BUFPAR	;Incluye "CONNECT"?
	xor	a
	ld	de,CONNECT_S
	ld	bc,0
	or	a
	call	INSTR

	ld	a,b	;Respuesta CONNECT
	or	a
	jp	nz,TERMOK

	ld	hl,BUFPAR	;Otra respuesta
	ld	de,ERRDIAL_S2
	ld	bc,63
	ldir

	ld	a,#FF
	ld	(INDIAL),a
	ld	de,ERRDIAL_S
	jp	TERMERR



;******************************
;***                        ***
;***   RUTINAS AUXILIARES   ***
;***                        ***
;******************************

;--- CHK_KEY: Comprueba si hay alguna tecla pulsada,
;             en ese caso termina el programa

CHK_KEY:	ld	c,_DIRIO
	ld	e,#FF
	call	5
	or	a
	ret	z

	ld	a,"A"
	call	F_RS_Out
	ld	de,ABORT_S
	jp	TERMERR


;--- SENDCOM: Envia un comando al modem
;             Entrada: HL = Puntero al comando, acabado en 0
;             Salida:  HL = Puntero tras el comando
;             Se imrpime el comando por pantalla si SHOW=#FF

SENDCOM:	ld	a,(hl)
	or	a	;Si el caracter es 0,
	jr	nz,SENDC_OK	;lo sustituye por 13
	ld	a,13
SENDC_OK:	push	hl,af
	call	F_RS_Out	;Envia caracter al modem

	ld	a,(SHOW)	;Imprime caracter enviado
	or	a	;si SHOW=#FF
	jr	z,SENDC_OK2
	pop	af
	push	af
	ld	c,_CONOUT
	ld	e,a
	call	5
SENDC_OK2:	;

	pop	af,hl	;Si no era 13, enviar siguiente
	inc	hl
	cp	13
	ret	z
	jr	SENDCOM


;--- WAITCODE: Espera una cadena OK o ERROR,
;              si es OK vuelve, si es ERROR termina el programa

WAITCODE:	call	WAITREPLY

KK:	ld	hl,BUFPAR	;Busca OK
	xor	a
	ld	de,OK_S
	ld	bc,0	;Caracter terminacion: 0
	or	a
	call	INSTR
	ld	a,b
	or	a
	ret	nz

	ld	hl,BUFPAR	;Busca ERROR
	xor	a
	ld	de,ERROR_S
	ld	bc,0	;Caracter terminacion: 0
	or	a
	call	INSTR
	ld	a,b
	or	a
	jr	z,WAITCODE

	ld	de,ERRINIT_S
	jp	TERMERR


;--- WAITREPLY: Espera una respuesta del modem, la almacena en BUFPAR
;               y la imprime si SHOW=#FF

WAITREPLY:	call	CHK_KEY	;Espera mientras no haya respuesta
	call	F_RS_In_Stat
	jr	z,WAITREPLY

	ld	hl,BUFPAR
WAITR_LOOP:	push	hl
	call	F_RS_In_Stat
	jr	z,WAITR_END
	call	F_RS_In	;Imprime caracter si SHOW=#FF
	push	af
	ld	e,a
	ld	a,(SHOW)
	or	a
	call	z,HALTEA
	jr	z,WAITR_OK1
	ld	c,_CONOUT
	call	5
WAITR_OK1:	pop	af,hl
	ld	(hl),a
	inc	hl
	jr	WAITR_LOOP

WAITR_END:	pop	hl	;No hay mas caracteres:
	ld	(hl),0	;acaba la cadena con 0
	ret		;                ;y termina

HALTEA:	halt		;Sin esto, no funciona en R800 cuando SHOW=0
	ret		;(me lo expliquen...)


;--- PRINTZ: Imprime una cadena acabada en "0", mas un salto de linea
;            Entrada: DE = Cadena

PRINTZ:	push	de
PRINTZL:	ld	a,(de)
	or	a
	jr	z,PRINTZOK
	inc	de
	jr	PRINTZL
PRINTZOK:	ex	de,hl
	ld	(hl),"$"
	pop	de
	push	hl
	ld	c,_STROUT
	call	5
	pop	hl
	ld	(hl),0
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

;--- Terminacion con error:
;    Inserta el nombre del programa en INSERRORP,
;    el error pasado en DE en INSERROR, e imprime este ultimo

TERMERR:	push	de

	ld	hl,PROGRAM_S	;Obtiene variable PROGRAM
	ld	de,BUFPAR
	ld	b,255
	ld	c,_GENV
	call	5

	ld	b,0	;Calcula posicion del ultimo elem.
	ld	de,BUFPAR	;(el nombre del programa)
	ld	c,_PARSE
	call	5

	ex	de,hl	;Establece INSERRORP con el nombre
	ld	hl,INSERRP_S	;del programa
	ld	c,_SENV
	call	5

	pop	de	;Establece INSERROR con la
	push	de	;cadena de error
	ld	hl,INSERR_S
	ld	c,_SENV
	call	5

	ld	a,(INDIAL)
	or	a
	jr	nz,TERMOK

	print	ERRORAST_S
	pop	de	;Imprime la cadena de error
	call	PRINTZ
	print	CRLF_S

TERMOK:	print	CUROFF_S

	ld	a,(INSSTAT)	;Si INS estaba instalado y activo
	or	a	;al principio, lo reactiva
	jr	z,TERMOK2
	nesman	32
	ld	(ix),a

TERMOK2:	ld	bc,#0062	;Termina
	jp	5


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

INSTR:	push	af
	jr	c,NOCASE
SICASE:	ld	a,#FF
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


;***  RUTINAS FOSSIL  ***

; RS232 recognize/caller routine
;
; (p) 1993,1994 Erik Maas
;
; made to use with GEN80 macro assembler from HiSoft's DevPack80 v2.03

; To use this library, first you have to call GetFossil, this routine will
; check whether the fossil is available or not, if it is available, then it
; will adjust the jump table, so you can use this table.
; The return flags of GetFossil can tell you whether the fossil was found or
; not. Z  means the Fossil was found and installed
;      NZ means the Fossil was not found, and therefore NOT installed
;         (so be wise, return to DOS or whatever, do not use the routines)

; The fossil has it marks at the cassette parameter table, I do not believe
; any MSX 2 or turbo-R will use it anymore.... (??????)

; F3FC: "R"     mark 1
; F3FD: "S"     mark 2
; F3FE: LSB     LSB of addres to jump table of fossil driver
; F3FF: MSB     MSB of addres to jump table of fossil driver

GetFossil	ld	a,(#f3fc)	; get first mark of fossil
	cp	"R"	; is it the right one?
	ret	nz	; return if not with NZ flags
	ld	a,(#f3fd)	; get second mark of fossil
	cp	"S"	; is it the right one?
	ret	nz	; return if not with NZ flags

	; now we know the Fossil is installed, just get the addres
	; of the jump table now, and connect it to the program

	ld	hl,(#f3fe)	; get addres of jump table
	ld	de,F_GetVersion	; point to my own table
	ld	bc,21*3	; number of entry's at this moment
	ldir		; make a copy of the table
	call	F_GetVersion
	xor	a	; set Z flags
	ret		; and return to caller

;
; Jump Table to use in ML
;
; This table will be filled in by the GetFossil routine, after that you can
; simply call these addresses in the table
;

F_GetVersion	jp	0	; 0
F_Init	jp	0	; 1
F_DeInit	jp	0	; 2
F_SetBaud	jp	0	; 3
F_Protocol	jp	0	; 4
F_Channel	jp	0	; 5
F_RS_In	jp	0	; 6
F_RS_Out	jp	0	; 7
F_RS_In_Stat	jp	0	; 8
F_RS_Out_Stat	jp	0	; 9
F_DTR	jp	0	; 10
F_RTS	jp	0	; 11
F_Carrier	jp	0	; 12
F_Chars_In_Buf	jp	0	; 13
F_Size_Of_Buf	jp	0	; 14
F_Flush_Buf	jp	0	; 15
F_Fastint	jp	0	; 16
F_Hook38Stat	jp	0	; 17
F_Chput_Hook	jp	0	; 18
F_Keyb_Hook	jp	0	; 19
F_Get_Info	jp	0	; 20



;****************************
;***                      ***
;***   DATOS, VARIABLES   ***
;***                      ***
;****************************

SHOW:	db	0	;#FF para mostrar los comandos del modem
LONPAR:	db	0	;Longitud del parametro extraido
INDIAL:	db	0	;#FF cuando se ha marcado el numero
INSSTAT:	db	0

PRESEN_S:	db	13,10,"NestorDialer 0.2",13,10
	db	"By Konami Man, 7-2002",13,10,10,"$"
INFO_S:	db	"Use:",13,10,10
	db	"NDIAL <number>|. [/p] [/s] [/c:<command>[_<command>]...]",13,10,10
	db	"<number>: Phone number to dial",13,10
	db	"          If ",34,".",34," is specified instead of a number, no dial is",13,10
	db	"          issued but the modem initialization commands are executed",13,10
	db	"/p: Use ATDP command instead of ATDT to dial",13,10
	db	"/s: Show all modem commands and replies",13,10
	db	"/c: Additional commands to send to the modem before dialing",13,10
	db	"    Separate the commands with underscores, ",34,"_",34,13,10
	db	"    By default, only ATZ (modem reset) and ATE0 (supress local echo) are sent",13,10
	db	10
	db	"String returned by modem on success can be set up in environment variable",13,10
	db	"NDIAL_CONNECT (max 16 characters). Default if variable is not set is ",34,"CONNECT",34,13,10
	db	10
	db	"To enable error checking execute SET USEINSERROR=anything",13,10
	db	"$"

PRESS_S:	db	"* Press any key to abort process",13,10,10
	db	"Initializing modem...",13,10,"$"
TORESET_S:	db	13,10,10,"To reset error condition, execute ",34,"SET INSERROR=",34,13,10
	db	"To disable error checking, execute ",34,"SET USEINSERROR=",34,13,10,"$"
NODIAL_S:	db	13,10,"No dial number specified",13,10,"$"
DIALING_S:	db	13,10,"Dialing $"
PUNTOS_S:	db	"...",13,10,"$"

ATZ_S:	db	"ATZ",0
ATE0_S:	db	"ATE0",0,0
OK_S:	db	"OK",13,0
ERROR_S:	db	"ERROR",13,0
CONNECT_S:	db	"CONNECT",0
	ds	9
CONNENV_S:	db	"NDIAL_CONNECT",0

PROGRAM_S:	db	"PROGRAM",0
INSERR_S:	db	"INSERROR",0
INSERRP_S:	db	"INSERRORP",0
USEINSERR_S:	db	"USEINSERROR",0
DOSPUN_S:	db	":"
CRLF_S:	db	13,10,"$"
CURON_S:	db	27,"y5","$"
CUROFF_S:	db	27,"x5","$"

ERRORAST_S:	db	13,10,"*** ERROR: $"
ERRETBY_S:	db	"*** ERROR returned by $"
UNK_S:	db	"unknown program",0
INVPAR_S:	db	"Invalid parameter",0
NOFOS_S:	db	"Fossil driver not installed",0
ERRINIT_S:	db	"Error when initializing modem",0
ABORT_S:	db	"Process aborted by user",0
ERRDIAL_S:	db	"Error when dialing: "
ERRDIAL_S2:	ds	64

DIALCOM:	db	"ATDT"
BUFNUM:	;                        ;Bufer para el numero a marcar
BUFCOM:	equ	BUFCOM+128	;Bufer para los comandos adicionales
BUFPAR:	equ	BUFCOM+128
BUFPAR2:	equ	BUFPAR+256

