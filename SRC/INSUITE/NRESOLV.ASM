; Resolver tool for InterNestor Suite, retrieves information from a DNS server

;===============================================

	;--- NestorResolver 0.2.1
	;    Uso: NRESOLV <server> [Q<qtype>] [C<class>] [R]

	.label	20

;******************************
;***                        ***
;***   MACROS, CONSTANTES   ***
;***                        ***
;******************************

FAKE_END:	equ	0

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

_CONOUT:	equ	#02
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
IP_TABLES:	equ	#8021
IP_CREATE_PROT:	equ	#8024

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



;**************************
;***                    ***
;***   INICIALIZACION   ***
;***                    ***
;**************************

	org	#100


;----------------------------------
;---  Comprobaciones iniciales  ---
;----------------------------------

	;--- Comprueba si hay parametros. Si no, muestra
	;    ayuda y termina

	ld	(SAVESP),sp

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

OKNMAN1:	ld	hl,#0201
	ex	de,hl
	call	COMP
	jr	c,OKNMAN2

	print	BADNMAN_S	;Es al menos version 1.21?
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

	;--- Obtencion de los parametros

	;Primer parametro: nombre del servidor

	ld	a,1
	ld	de,BUFER
	call	EXTPAR

	;Extrae los demas parametros

	ld	a,2
BUC_PAR:	push	af
	ld	de,BUFER+256
	call	EXTPAR
	jp	c,OK_PARS

	ld	a,(BUFER+256)
	or	%00100000
	ld	hl,PAR_QTYPE
	cp	"q"
	jr	z,PAR_QC
	ld	hl,PAR_QCLASS
	cp	"c"
	jr	z,PAR_QC
	cp	"r"
	jr	z,PAR_R
	cp	"i"
	jr	z,PAR_I

BADPAR:	print	INVPAR_S
	jp	TERMINFO

PAR_QC:	push	hl	;QTYPE o CLASS
	ld	hl,BUFER+257
	ld	a,(hl)
	cp	"*"
	ld	bc,255
	jr	z,ESASTE
	call	EXTNUM
	jr	c,BADPAR
	or	a
	jr	nz,BADPAR
	ld	a,e
	or	a
	jr	nz,BADPAR
ESASTE:	pop	hl
	ld	(hl),c
	inc	hl
	ld	(hl),b

NEXT_PAR:	pop	af
	inc	a
	jr	BUC_PAR

PAR_R:	ld	a,#FF	;Recursion
	ld	(PAR_RECUR),a
	jr	NEXT_PAR

PAR_I:	ld	hl,BUFER+257	;Direccion IP del DNS
	ld	c,b
	ld	b,0
	add	hl,bc
	dec	hl
	ld	(hl),"."

	ld	de,IP_REMOTE
	ld	hl,BUFER+257
	ld	b,4

IPLOOP:	push	bc,de
	ld	a,(hl)
	cp	"*"
	ld	bc,255
	jr	z,ESASTE
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

	ld	a,#FF
	ld	(IP_FLAG),a
	jr	NEXT_PAR

ERRIP:	print	INVPAR_S
	jp	TERMINFO
IPOK:	;

OK_PARS:	pop	af

	;Compone paquete segun servidor, QTYPE, QCLASS y R

	ld	ix,QUERY_SERV	;Anyade el nombre al final
	ld	hl,BUFER	;del paquete UDP
	call	GET_SERV

	ld	hl,(PAR_QTYPE)	;Despues, anyade campos
	ld	(ix),h	;QTYPE y QCLASS
	ld	(ix+1),l
	ld	hl,(PAR_QCLASS)
	ld	(ix+2),h
	ld	(ix+3),l
	ld	(ix+4),0	;Para que calcule bien el checksum UDP

	push	ix	;Establece las longitudes IP y UDP
	pop	hl
	ld	bc,UDP_START-4
	or	a
	sbc	hl,bc
	ld	a,h
	ld	(UDP_LENGTH),a
	ld	a,l
	ld	(UDP_LENGTH+1),a
	ld	bc,8
	add	hl,bc
	ld	(IP_LENGTH),hl

	ld	a,(PAR_RECUR)
	or	a
	jr	z,OK_PAR_R
	ld	hl,DNS_FLAGS
	set	0,(hl)
OK_PAR_R:	;

	;--- Obtiene rutinas del mapeador

	ld	de,#0402	;Obtiene rutinas del mapeador
	call	#FFCA
	ld	de,ALL_SEG
	ld	bc,#30
	ldir

	;--- Conecta el segmento de NestorPPP en pagina 1

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

	;--- Obtiene IPs desde el nivel inferior (PPP)

	xor	a	;Obtiene IPs
	call	PPP_IPS
	ld	a,h
	ld	(IP_LOCAL),a
	ld	a,l
	ld	(IP_LOCAL+1),a
	ld	a,d
	ld	(IP_LOCAL+2),a
	ld	a,e
	ld	(IP_LOCAL+3),a

	ld	a,(IP_FLAG)
	or	a
	jr	nz,OK_SETIPS
	ld	a,2	;Obtiene IP del DNS 1
	call	PPP_IPS
	ld	a,h
	ld	(IP_REMOTE),a
	ld	a,l
	ld	(IP_REMOTE+1),a
	ld	a,d
	ld	(IP_REMOTE+2),a
	ld	a,e
	ld	(IP_REMOTE+3),a

	ld	ix,IP_REMOTE
	ld	a,(ix)
	or	(ix+1)
	or	(ix+2)
	or	(ix+3)
	jr	nz,OK_SETIPS

	print	NOIPNEG_S
	jp	TERMOK

OK_SETIPS:	;

	;--- Conecta el segmento de NestorIP en pagina 2

	ld	a,(INS_SEG3)
	call	PUT_P2

	;--- Obtiene colas de entrada y salida

	ld	a,17	;Primero crea la cola para UDP
	call	IP_CREATE_PROT

	ld	a,255	;Salida
	call	IP_QUEUES
	ld	(QUEUE_DIR),a
	ld	(QUEUE_DIR+1),hl
	ld	a,17	;Entrada para UDP
	call	IP_QUEUES
	ld	(IN_QUEUE_DIR),a
	ld	(IN_QUEUE_DIR+1),hl

	;--- Envia el primer paquete

kkk:	print	PRESS_S
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
	ld	iy,RECEIVED-1
	nesman	25
	jr	c,KEY

	;--- Paquete recibido: comprueba que sea correcto

	ld	a,(#F343)
	ld	h,#80
	call	ENASLT
	ld	a,1
	call	PUT_P2

	ld	a,(RECEIVED)	;IP version 4?
	and	#F0
	cp	#40
	jr	nz,KEY

	ld	a,(RECEIVED+9)	;Es UDP?
	cp	17
	jr	nz,KEY

	ld	hl,(RECEIVED+12)
	ld	de,(IP_REMOTE)	;IPs correctas?
	call	COMP
	jr	nz,KEY
	ld	hl,(RECEIVED+14)
	ld	de,(IP_REMOTE+2)
	call	COMP
	jr	nz,KEY
	ld	hl,(RECEIVED+16)
	ld	de,(IP_LOCAL)
	call	COMP
	jr	nz,KEY
	ld	hl,(RECEIVED+18)
	ld	de,(IP_LOCAL+2)
	call	COMP
	jr	nz,KEY

	ld	a,(RECEIVED)	;Checksum correcto?
	and	#0F
	ld	l,a
	ld	h,0
	add	hl,hl
	push	hl
	pop	bc
	ld	ix,RECEIVED
	call	CALC_CHKSUM
	jp	nz,KEY

	ld	a,(RECEIVED-1)	;Calcula dir del paquete DNS
	ld	c,a	;(cabecera UDP)
	ld	b,0
	ld	hl,RECEIVED
	add	hl,bc
	push	hl
	pop	ix

	ld	a,(ix+2)	;Puertos correctos?
	cp	34
	jp	nz,KEY
	xor	(ix+3)
	jp	nz,KEY
	ld	a,(ix)
	or	a
	jp	nz,KEY
	ld	a,(ix+1)
	cp	53
	jp	nz,KEY

	ld	bc,8	;Se salta la cabecera UDP
	add	ix,bc

kkkk:	print	RCV_S
	jp	OK_RCV

	;--- Subrutina de envio de un paquete

SEND_PAQ:	push	af
	call	_SEND_PAQ
	pop	af
	ret

	; Prepara paquete

_SEND_PAQ:	ld	hl,IP_REMOTE	;Establece IP de destino
	ld	de,DESTIN_AD
	ld	bc,4
	ldir

	ld	hl,0
	ld	(UDP_CHKSUM),hl
	ld	ix,IP_LOCAL	;Calcula checksum del UDP
	ld	bc,2
	call	CALC_CHKSUM
	dec	de
	ld	ix,IP_REMOTE
	ld	bc,2
	call	CALC_CHKSUMP
	dec	de
	ld	ix,PROTO_17
	ld	bc,1
	call	CALC_CHKSUMP
	dec	de
	ld	ix,UDP_LENGTH
	ld	bc,1
	call	CALC_CHKSUMP
	dec	de
	ld	h,(ix)
	ld	l,(ix+1)
	bit	0,l
	jr	z,OKBITL	;Si longitud impar, sumamos 1
	inc	hl
OKBITL:	srl	h
	rr	l
	push	hl
	pop	bc
	ld	ix,UDP_START
	call	CALC_CHKSUMP
	dec	de
	ld	a,e
	cpl
	ld	(UDP_CHKSUM),a
	ld	a,d
	cpl
	ld	(UDP_CHKSUM+1),a

	ld	ix,UDP_CHKSUM	;Si el checksum es 0, pone -1
	ld	a,(ix)
	or	(ix+1)
	jr	nz,CHKNOES0
	ld	hl,#FFFF
	ld	(UDP_CHKSUM),hl
CHKNOES0:	;

	; Mete paquete en la cola

	ld	ix,(QUEUE_DIR+1)
	ld	b,3
	ld	hl,(IP_LENGTH)
	ld	a,(QUEUE_DIR)
	ld	iy,IP_START
	nesman	24

	;Muestra mensaje

	print	SENT_S
	ret


;*******************************
;***                         ***
;***   MUESTRA INFORMACION   ***
;***                         ***
;*******************************

;IX apunta a la cabecera DNS

OK_RCV:	;

;---------------------------------------------------------
;---  Muestra info sobre recursion y codigos de error  ---
;---------------------------------------------------------

	ld	(OFFSET_ZERO),ix
	ld	a,(ix+3)
	bit	7,a
	ld	de,RECAV_S
	jr	nz,PRINT_REC
	ld	de,RECNOAV_S
PRINT_REC:	ld	c,_STROUT
	call	5

	ld	a,(ix+3)
	and	#0F
	jr	z,NO_RCODE

	push	af
	print	ERCODE_S	;imp. "Error code: "
	pop	af
	push	af
	push	ix
	ld	ix,RCODE_T
	call	PRINT_CODESTR	;imp. mensaje de error
	pop	ix
	print	CODE_S	;imp. " (code "
	pop	af
	ld	l,a
	ld	h,0
	or	a
	call	PRINT_NUM	;imp. numero de codigo
	print	CLOSEPAR_S	;imp. ")"+CR+LF
	print	CRLF_S

NO_RCODE:	bit	1,(ix+2)
	jr	z,NO_TRUNC
	print	TRUNC_S
NO_TRUNC:	;


;-----------------------------
;---  Muestra la pregunta  ---
;-----------------------------

	ld	h,(ix+4)	;Numero de preguntas
	ld	l,(ix+5)

	ld	de,12
	add	ix,de	;IX apunta ahora a las preguntas

	push	hl
	print	NUMQUEST_S	;Muestra numero de entradas
	scf
	pop	hl
	push	hl
	call	PRINT_NUM
	pop	bc

SHOWQ_LOOP:	ld	a,b	;Quedan entradas?
	or	c
	jp	z,OK_SHOWQ

	push	bc
	print	ENTRYN_S	;Muestra num. de entrada actual
	pop	hl
	push	hl
	scf
	call	PRINT_NUM
	print	QNAME_S
	call	PRINT_SERV

	print	QTYPE_S
	ld	h,(ix)
	ld	l,(ix+1)
	push	ix
	ld	ix,QTYPE_T
	call	PRINT_CODESTRX
	pop	ix

	print	QCLASS_S
	ld	h,(ix+2)
	ld	l,(ix+3)
	push	ix
	ld	ix,QCLASS_T
	call	PRINT_CODESTRX
	pop	ix

	inc	ix
	inc	ix
	inc	ix
	inc	ix
	pop	bc
	dec	bc
	jp	SHOWQ_LOOP

OK_SHOWQ:	;jp      TERMOK


;--------------------------------------------------
;---  Muestra las respuestas - bucle principal  ---
;--------------------------------------------------

	push	ix
	ld	ix,(OFFSET_ZERO)
	ld	h,(ix+6)
	ld	l,(ix+7)
	pop	ix
	ld	de,NUMANS_S
	call	SHOW_REPLIES

	push	ix
	ld	ix,(OFFSET_ZERO)
	ld	h,(ix+8)
	ld	l,(ix+9)
	pop	ix
	ld	de,NUMAUTH_S
	call	SHOW_REPLIES

	push	ix
	ld	ix,(OFFSET_ZERO)
	ld	h,(ix+10)
	ld	l,(ix+11)
	pop	ix
	ld	de,NUMADD_S
	call	SHOW_REPLIES

	jp	TERMOK


;-----------------------------------------------
;---  Muestra las respuestas de una seccion  ---
;-----------------------------------------------

;DE = Cadena a imprimir inicialmente
;HL = Numero de entradas en la seccion
;IX Apunta al principio seccion, al final debe apuntar a la siguiente seccion

SHOW_REPLIES:	push	hl
	ld	c,_STROUT	;Imprime cadena inicial
	call	5

	pop	hl
	push	hl	;Imprime numero de entradas
	scf
	call	PRINT_NUM
	pop	bc
	ld	hl,1
	ld	(NUMENT),hl

SHOWREP_LOOP:	ld	a,b	;Bucle para cada entrada
	or	c
	ret	z

	push	bc
	print	ENTRYN_S	;Numero de entrada actual
	ld	hl,(NUMENT)
	scf
	call	PRINT_NUM

	print	NAME_S	;Imp. "NAME: servidor"
	call	PRINT_SERV
	print	TYPE_S
	ld	h,(ix)
	ld	l,(ix+1)
	push	ix
	ld	ix,QTYPE_T	;Imp. "TYPE: tipo"
	call	PRINT_CODESTRX
	pop	ix
	print	CLASS_S
	ld	h,(ix+2)
	ld	l,(ix+3)
	push	ix	;Imp. "CLASS: clase"
	ld	ix,QCLASS_T
	call	PRINT_CODESTRX
	pop	ix
	inc	ix
	inc	ix
	inc	ix
	inc	ix
	print	TTL_S
	scf
	call	PRINT_WORD	;Imp. "TTL: ttl"

	ld	h,(ix)	;HL = Longitud datos
	ld	l,(ix+1)
	inc	ix	;IX = Inicio datos
	inc	ix

	ld	a,(ix-10)	;Si el tipo no es 1 a 16,
	or	a	;es desconocido
	jr	nz,UNKRECORD
	ld	a,(ix-9)
	or	a
	jr	z,UNKRECORD
	cp	22
	jr	nc,UNKRECORD
	dec	a
	ld	l,a	;Ejecuta la rutina adecuada
	ld	h,0	;para el tipo de registro
	add	hl,hl
	ld	bc,RR_TABLE
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	bc,NEXTRECORD
	push	bc
	jp	(hl)

NEXTRECORD:	pop	bc
	dec	bc
	ld	hl,(NUMENT)
	inc	hl
	ld	(NUMENT),hl
	jp	SHOWREP_LOOP

UNKRECORD:	push	hl	;Datos desconocidos: se los salta
	pop	bc
	add	ix,bc
	jr	NEXTRECORD


;------------------------------------------------------
;---  Rutinas para mostrar la info de cada seccion  ---
;------------------------------------------------------

;Entrada: IX = Inicio de la info, HL = longitud
;Salida:  IX = IX+HL

	;--- 1: A

RR_1:	print	ADDRESS_S
	call	SHOWIP
	ret

	;--- 2: NS

RR_2:	print	NSDNAME_S
	call	PRINT_SERV
	ret

	;--- 3: MD

RR_3:	print	MADNAME_S
	call	PRINT_SERV
	ret

	;--- 4: MF

RR_4:	equ	RR_3

	;--- 5: CNAME

RR_5:	print	CNAME_S
	call	PRINT_SERV
	ret

	;--- 6: SOA

RR_6:	print	MNAME_S
	call	PRINT_SERV
	print	RNAME_S
	call	PRINT_MAIL
	print	SERIAL_S
	scf
	call	PRINT_WORD
	print	REFRESH_S
	scf
	call	PRINT_WORD
	print	RETRY_S
	scf
	call	PRINT_WORD
	print	EXPIRE_S
	scf
	call	PRINT_WORD
	print	MINIMUM_S
	scf
	call	PRINT_WORD
	ret

	;--- 7: MB

RR_7:	equ	RR_3

	;--- 8: MG

RR_8:	print	MGNAME_S
	call	PRINT_SERV
	ret

	;--- 9: MR

RR_9:	print	NEWNAME_S
	call	PRINT_SERV
	ret

	;--- 10: NULL

RR_10:	push	hl	;No imprime nada
	pop	bc
	add	ix,bc
	ret

	;--- 11: WKS

RR_11:	push	hl
	print	ADDRESS_S
	print	SHOWIP
	print	PROTOCOL_S
	ld	h,(ix)
	ld	l,(ix+1)
	scf
	call	PRINT_NUM
	print	PORTS_S
	inc	ix
	pop	hl
	ld	bc,6
	or	a
	sbc	hl,bc
	ld	b,l
	call	PRINT_BITMAP
	ret

	;--- 12: PTR

RR_12:	print	PTRDNAME_S
	call	PRINT_SERV
	ret

	;--- 13: Hinfo

RR_13:	print	CPU_S
	call	PRINT_STR
	print	CRLF_S
	print	OS_S
	call	PRINT_STR
	print	CRLF_S
	ret

	;--- 14: MINFO

RR_14:	print	RMAILBX_S
	call	PRINT_SERV
	print	EMAILBX_S
	call	PRINT_SERV
	ret

	;--- 15: MX

RR_15:	print	PREFERENCE_S
	ld	h,(ix)
	ld	l,(ix+1)
	scf
	call	PRINT_NUM
	inc	ix
	inc	ix
	print	EXCHANGE_S
	call	PRINT_SERV
	ret

	;--- 16: TXT

RR_16:	print	TXTDATA_S
	call	PRINT_STR
	print	CRLF_S
	ret

	;--- 17: RP

RR_17:	print	MBOXDNAME_S
	call	PRINT_MAIL
	print	TXTDNAME_S
	call	PRINT_SERV
	ret

	;-- 18: AFSDB

RR_18:	print	SUBTYPE_S
	ld	h,(ix)
	ld	l,(ix+1)
	scf
	call	PRINT_NUM
	inc	ix
	inc	ix
	print	SUBTYPE_S
	call	PRINT_SERV
	ret

	;--- 19: X25

RR_19:	print	PSDNADDRESS_S
	call	PRINT_STR
	print	CRLF_S
	ret

	;--- 20: ISDN

RR_20:	push	hl
	print	ISDNADDRESS_S
	ld	a,(ix)
	push	af
	call	PRINT_STR
	pop	af
	ld	c,a
	ld	b,0
	pop	hl
	or	a
	sbc	hl,bc
	ld	a,h
	or	l
	ret	z
	print	SA_S
	call	PRINT_STR
	ret

	;--- 21: RT

RR_21:	print	PREFERENCE_S
	ld	h,(ix)
	ld	l,(ix+1)
	scf
	call	PRINT_NUM
	inc	ix
	inc	ix
	print	INTERMHOST_S
	call	PRINT_SERV
	ret



;******************************
;***                        ***
;***   RUTINAS AUXILIARES   ***
;***                        ***
;******************************

;--- SHOWIP: Muestra la IP almacenada en IX
;    Salida: IX = IX+4

SHOWIP:	ld	b,4
	ld	hl,BUF_SHOWIP
SHOWIPBUC:	push	bc,ix,hl
	ld	e,(ix)
	ld	d,0
	ld	b,1
	ld	c," "
	xor	a
	call	NUMTOASC
	pop	hl,ix
	inc	ix
	ld	b,0
	add	hl,bc
	ld	(hl),"."
	inc	hl
	pop	bc
	djnz	SHOWIPBUC
	dec	hl
	ld	(hl),13
	inc	hl
	ld	(hl),10
	inc	hl
	ld	(hl),"$"
	ld	de,BUF_SHOWIP
	ld	c,9
	call	5
	ret
BUF_SHOWIP:	ds	34


;--- PRINT_BITMAP: Imprime un mapa de bits WKS en forma de numeros decimales
;                  separados por comas, terminando con CR+LF
;    Entrada: IX = Inicio del bitmap
;             B  = Longitud en bytes (0 es 256)
;    Salida:  IX = Apunta tras el bitmap

PRINT_BITMAP:	ld	hl,0
	xor	a
	ld	(PRBIT_COMA),a

PRINT_BITLOP:	push	bc,ix
	ld	b,8
	ld	a,(ix)

PRINT_BL2:	sla	a
	push	bc,hl,af
	call	COMA_IF_C
	pop	af,hl
	push	hl,af
	ccf
	call	nc,PRINT_NUM
	pop	af,hl,bc
	inc	hl
	djnz	PRINT_BL2

	pop	ix,bc
	inc	ix
	djnz	PRINT_BITLOP
	ld	e,13
	ld	c,_CONOUT
	call	5
	ld	e,10
	ld	c,_CONOUT
	call	5
	ret

	;Imprime ", " si Cy=1

COMA_IF_C:	ret	nc
	ld	a,(PRBIT_COMA)
	or	a
	ld	a,#FF
	ld	(PRBIT_COMA),a
	ret	z
	ld	e,","
	ld	c,_CONOUT
	call	5
	ld	e," "
	ld	c,_CONOUT
	call	5
	ret

PRBIT_COMA:	db	0	;Para no imp. ", " antes de 1er num


;--- PRINT_WORD: Imprime un numero de 32 bits en hexadecimal,
;                almacenado en big-indian
;    Entrada: IX = Numero
;             Cy = 1 para anyadir CR+LF
;    Salida:  IX = IX+4

PRINT_WORD:	push	af
	ld	e,"#"
	ld	c,_CONOUT
	call	5
	ld	d,(ix)
	ld	e,(ix+1)
	call	PRINT_W0
	ld	d,(ix+2)
	ld	e,(ix+3)
	call	PRINT_W0
	inc	ix
	inc	ix
	inc	ix
	inc	ix
	pop	af
	ret	nc
	ld	e,13
	ld	c,_CONOUT
	call	5
	ld	e,10
	ld	c,_CONOUT
	call	5
	ret

PRINT_W0:	push	ix
	ld	hl,BUFER
	ld	bc,#0448
	ld	a,%10001001
	call	NUMTOASC
	ld	de,BUFER
	ld	c,_STROUT
	call	5
	pop	ix
	ret


;--- PRINT_NUM: Imprime el numero HL, anyadiendo CR+LF si Cy=1

PRINT_NUM:	push	ix
	call	_PRINT_NUM
	pop	ix
	ret

_PRINT_NUM:	push	af
	ex	de,hl
	ld	hl,BUFER
	ld	b,1
	ld	a,%1000
	call	NUMTOASC
	ld	de,BUFER
	ld	c,_STROUT
	call	5
	pop	af
	ret	nc
	ld	e,13
	ld	c,_CONOUT
	call	5
	ld	e,10
	ld	c,_CONOUT
	call	5
	ret


;--- PRINT_CODESTRX: Funciona como PRINT_CODESTR pero si el codigo es
;                    desconocido, imprime tambien "(code nn)"+CR+LF
;    Entrada: HL = Codigo (si H> siempre devuelve "unknown")
;             IX =Tabla con este formato:
;                 db codigo,longitud,cadena
;                 db codigo,longitud,cadena
;                 ...
;                 db 0

PRINT_CODESTRX:	push	hl
	ld	a,h
	or	a
	ld	a,l
	jr	z,PRCX0
	xor	a
PRCX0:	call	PRINT_CODESTR
	push	af
	ld	de,CRLF_S
	ld	c,_STROUT
	call	nc,5
	pop	af,hl
	ret	nc
	push	hl
	print	CODE_S
	pop	hl
	or	a
	call	PRINT_NUM
	print	CLOSEPAR_S
	ret


;--- PRINT_CODESTR: Imprime una cadena correspondiente a un codigo numerico
;                   Si el codigo es desconocido, imprime "Unknown"
;                   Devuelve Cy=1 si el codigo era desconocido
;    Entrada: A = Codigo
;             IX =Tabla con este formato:
;                 db codigo,longitud,cadena
;                 db codigo,longitud,cadena
;                 ...
;                 db 0

PRINT_CODESTR:	ld	b,a
	ld	a,(ix)
	or	a
	jr	z,PRCOD_UNK

	cp	b
	ld	a,b
	jr	z,PRCOD_FOUND

PRCOD_NOFOUND:	inc	ix
	ld	c,(ix)
	ld	b,0
	inc	ix
	add	ix,bc
	jr	PRINT_CODESTR

PRCOD_FOUND:	inc	ix
	call	PRINT_STR
	or	a
	ret

PRCOD_UNK:	ld	de,UNK_S
	ld	c,_STROUT
	call	5
	scf
	ret

UNK_S:	db	"Unknown$"


;--- PRINT_STR: Imprime una cadena en formato DNS (long+cadena)
;               usando BUFER como idem
;    Entrada: IX = Dir. cadena
;    Salida:  IX = Dir. tras la cadena

PRINT_STR:	ld	a,(ix)
	ld	b,0
	inc	ix
	or	a
	ret	z
	ld	c,a

	push	ix
	pop	hl
	ld	de,BUFER
	ldir
	push	hl
	pop	ix

	ex	de,hl
	ld	(hl),"$"
	ld	de,BUFER
	ld	c,_STROUT
	call	5
	ret


;--- GET_SERV: Lee un nombre de servidor almacenado con puntos
;              y lo almacena en formato de paquete DNS
;    Entrada:  HL = origen acabado en 0, IX = Destino
;    Salida:   IX apuntando despues de la cadena transformada

GET_SERV:	ld	a,(hl)	;La cadena vacia es un caso especial
	or	a
	jr	nz,GET_SERV0

	ld	(ix),0
	inc	ix
	ret

GET_SERV0:	ld	(GETSERV_PNT),ix
	inc	ix
	ld	b,0
GETSERV_LOP:	ld	a,(hl)	;Va cogiendo caracteres hasta
	inc	hl	;encontrar "." o 0
	cp	"."
	jr	z,GETS_LBELOK
	or	a
	jr	z,GETS_LBELOK
	ld	(ix),a
	inc	ix
	inc	b
	jr	GETSERV_LOP

GETS_LBELOK:	push	ix	;"." o 0: inserta longitud
	ld	ix,(GETSERV_PNT)
	res	7,b
	res	6,b
	ld	(ix),b
	pop	ix

	dec	hl
	ld	a,(hl)
	inc	hl
	or	a
	jr	nz,GET_SERV0
	ld	(ix),0
	inc	ix
	ret

GETSERV_PNT:	dw	0	;Guarda dir. donde poner la longitud


;--- PRINT_MAIL: Como PRINT_SERV pero imprime "@" en vez del primer punto

PRINT_MAIL:	ld	a,#FF
	jr	PRINT_MS

;--- PRINT_SERV: Imprime un nombre de servidor almacenado en formato
;                de paquete DNS, con CR+Lf al final
;    Entrada: IX = Direccion inicial
;             (OFFSET_ZERO) = Direccion de referencia del offset
;                             para direcciones comprimidas
;    Salida:  IX = Direccion tras el paquete

PRINT_SERV:	xor	a

PRINT_MS:	ld	(MAIL_FLAG),a
	xor	a
	ld	(PRSER_COMP_F),a
	ld	(PRSER_DOT),a

PRINT_SERV_0:	ld	a,(ix)
	inc	ix
	or	a
	jr	z,PRSER_END

	and	%11000000	;Esta comprimido?
	cp	%11000000
	jr	z,PRSER_COMP

	ld	a,(PRSER_DOT)
	or	a
	jr	z,NOARROB

	ld	e,"."
	ld	a,(MAIL_FLAG)
	or	a
	ld	a,0
	ld	(MAIL_FLAG),a
	jr	z,NOARROB
	ld	e,"@"
NOARROB:	;

	;                        ;Imprime punto si no es la
	ld	c,_CONOUT	;primera etiqueta
	ld	a,(PRSER_DOT)
	or	a
	ld	a,#FF
	ld	(PRSER_DOT),a
	call	nz,5

	ld	b,(ix-1)
	ld	c,_CONOUT
PRSER_LOP:	ld	e,(ix)
	push	bc
	call	5
	pop	bc
	inc	ix
	djnz	PRSER_LOP
	jr	PRINT_SERV_0

	;Datos comprimidos encontrados

PRSER_COMP:	ld	b,(ix-1)
	ld	c,(ix)
	inc	ix
	res	7,b	;BC=Offset
	res	6,b

	ld	a,(PRSER_COMP_F)	;Si es el primer caso de compresion
	or	a	;encontrado, guardamos la dir final
	jr	nz,PRSER_COMP_2
	ld	(PRSER_IX_FINAL),ix
	ld	a,-1
	ld	(PRSER_COMP_F),a

PRSER_COMP_2:	ld	ix,(OFFSET_ZERO)
	add	ix,bc
	jr	PRINT_SERV_0	;Imprime el nuevo nombre

	;Fin: devuelve el IX apropiado

PRSER_END:	ld	e,13
	ld	c,_CONOUT
	call	5
	ld	e,10
	ld	c,_CONOUT
	call	5

	ld	a,(PRSER_COMP_F)
	or	a	;No habia compersion: devolvemos
	ret	z	;IX tal como estaba
	ld	ix,(PRSER_IX_FINAL)
	ret

PRSER_COMP_F:	db	0
PRSER_DOT:	db	0
PRSER_IX_FINAL:	dw	0

OFFSET_ZERO:	dw	0
MAIL_FLAG:	db	0


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

TERMOK2:	if	FAKE_END=1

	ld	sp,(SAVESP)
	ld	c,1
	call	5
	ret

	else

	ld	bc,#0062
	jp	5

	endif


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

CALC_CHKSUMP:	push	hl
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
QUEUE_DIR:	ds	3
IN_QUEUE_DIR:	ds	3
IP_DNS_1:	ds	4
IP_DNS_2:	ds	4
IP_LOCAL:	ds	4
IP_REMOTE:	ds	4
SEQ:	dw	0
PAR_QTYPE:	dw	1
PAR_QCLASS:	dw	1
PAR_RECUR:	db	0
IP_FLAG:	db	0
NUMENT:	dw	0
SAVESP:	dw	0
IP_LENGTH:	dw	0

;--- Cadenas

PRESEN_S:	db	13,10,"NestorResolver 0.2.1",13,10
	db	"By Konami Man, 10-2001",13,10,10,"$"
INFO_S:	db	"Use: NRESOLV <server name> [I<name server address>] [Q<qtype>] [C<class>] [R]",13,10,10
	db	"<server name>: Name of the server to get information about",13,10
	db	"<name server address>: By default, the primary DNS address",13,10
	db	"                       negotiated in the PPP connection is used",13,10
	db	"<qtype>: Query type, see RFC-1035. Default: 1 (host address)",13,10
	db	"         An asterisk, ",34,"*",34,", may be used meaning value 255",13,10
	db	"<class>: Query class, see RFC-1035. Default: 1 (internet class)",13,10
	db	"         An asterisk, ",34,"*",34,", may be used meaning value 255",13,10
	db	"R: Ask for recursive query, the server may however not support it",13,10,10
	db	"HINT: To get information about an IP address ",34,"a.b.c.d",34,",",13,10
	db	"      use ",34,"d.c.b.a.IN-ADDR.ARPA",34," as <server name>",13,10,"$"
NONMAN_S:	db	"ERROR: NestorMan not installed",13,10,"$"
NOINS_S:	db	"ERROR: InterNestor suite is not installed",13,10,"$"
BADNMAN_S:	db	"ERROR: Invalid NestorMan version!",13,10,"$"
NEEDNMAN_S:	db	"NestorMan version 1.21 or higher is needed.",13,10,"$"
NOCON_S:	db	"ERROR: No PPP opened connection currently",13,10,"$"
PRESS_S:	db	"*** Press ENTER to send additional echo requests",13,10
	db	"*** Press any other key to exit",13,10,10,"$"
NOIPNEG_S:	db	"ERROR: DNS address was not negotiated",13,10
	db	"Specify a DNS address as parameter: I<DNS IP address>",13,10,"$"
SENT_S:	db	"- Sent information request packet",13,10,"$"
RCV_S:	db	"! Response received:",13,10,"$"
INVPAR_S:	db	"ERROR: Invalid parameter",13,10,10,"$"
RECAV_S:	db	13,10,"! Recursive queries available",13,10,10,"$"
RECNOAV_S:	db	13,10,"* Recursive queries NOT available",13,10,10,"$"
NORCODE_S:	db	"No error code returned",13,10,10,"$"
ERCODE_S:	db	"* ERROR returned by server: $"
TRUNC_S:	db	13,10,"* WARNING: This message is truncated",13,10,10,"$"
CODE_S:	db	" (code $"
CLOSEPAR_S:	db	")",13,10,"$"
ENTRYN_S:	db	13,10,"> Entry $"
NUMQUEST_S:	db	">>> QUESTION section - number of entries: $"
NUMANS_S:	db	13,10,">>> ANSWER section - number of entries: $"
NUMAUTH_S:	db	13,10,">>> AUTHORITATIVE section - number of entries: $"
NUMADD_S:	db	13,10,">>> ADDITIONAL section - number of entries: $"
QNAME_S:	db	13,10,"- QNAME: $"
QTYPE_S:	db	"- QTYPE: $"
QCLASS_S:	db	"- QCLASS: $"
NAME_S:	db	13,10,"- Record owner NAME: $"
TYPE_S:	db	"- TYPE: $"
CLASS_S:	db	"- CLASS: $"
TTL_S:	db	"- TTL: $"
RDLENGTH_S:	db	"- RDLENGTH: $"
ADDRESS_S:	db	"- ADDRESS: $"
NSDNAME_S:	DB	"- NSDNAME: $"
MADNAME_S:	DB	"- MADNAME: $"
CNAME_S:	DB	"- CNAME: $"
MNAME_S:	DB	"- MNAME: $"
RNAME_S:	DB	"- RNAME: $"
SERIAL_S:	DB	"- SERIAL: $"
REFRESH_S:	DB	"- REFRESH: $"
RETRY_S:	DB	"- RETRY: $"
EXPIRE_S:	DB	"- EXPIRE: $"
MINIMUM_S:	DB	"- MINIMUM: $"
MGNAME_S:	DB	"- MGNAME: $"
NEWNAME_S:	DB	"- NEWNAME: $"
PROTOCOL_S:	DB	"- PROTOCOL: $"
PORTS_S:	DB	"- PORT: $"
PTRDNAME_S:	DB	"- PTRDNAME: $"
CPU_S:	DB	"- CPU: $"
OS_S:	DB	"- OS: $"
RMAILBX_S:	DB	"- RMAILBX: $"
EMAILBX_S:	DB	"- EMAILBX: $"
PREFERENCE_S:	DB	"- PREFERENCE: $"
EXCHANGE_S:	DB	"- EXCHANGE: $"
TXTDATA_S:	DB	"- TXT-DATA: $"
MBOXDNAME_S:	db	"- MBOX-DNAME: $"
TXTDNAME_S:	db	"- TXT-DNAME: $"
SUBTYPE_S:	db	"- SUBTYPE: $"
HOSTNAME_S:	db	"- HOSTNAME: $"
PSDNADDRESS_S:	db	"- PSDN-ADDRESS: $"
ISDNADDRESS_S:	db	"- ISDN-ADDRESS: $"
SA_S:	db	"- SA-ADDRESS: $"
INTERMHOST_S:	db	"- INTERMEDIATE-HOST: $"
CRLF_S:	db	13,10,"$"
PROTO_17:	db	0,17
UDPL_FOR_CHK:	db	0,0

;--- Tablas de cadenas

RCODE_T:	db	1,18,"Query format error"
	db	2,14,"Server failure"
	db	3,10,"Name error"
	db	4,26,"Query type not implemented"
	db	5,13,"Query refused"
	db	0

QTYPE_T:	db	1,15,"A: Host address"
	db	2,29,"NS: Authoritative name server"
	db	3,20,"MD: Mail destination"
	db	4,18,"MF: Mail forwarder"
	db	5,34,"CNAME: Canonical name for an alias"
	db	6,33,"SOA: Start of a zone of authority"
	db	7,23,"MB: Mailbox domain name"
	db	8,21,"MG: Mail group member"
	db	9,27,"MR: Mail rename domain name"
	db	10,13,"NULL: Null RR"
	db	11,35,"WKS: Well known service description"
	db	12,24,"PTR: Domain name pointer"
	db	13,23,"HINFO: Host information"
	db	14,39,"MINFO: Mailbox or mail list information"
	db	15,17,"MX: Mail exchange"
	db	16,16,"TXT: Text string"
	db	17,22,"RP: Responsible person"
	db	18,29,"AFSDB: AFS data base location"
	db	19,3,"X25"
	db	20,4,"ISDN"
	db	21,17,"RT: Route through"
	db	252,34,"AXFR: Entire zone transfer request"
	db	253,38,"MAILB: Mailbox-related records request"
	db	254,33,"MAILA: Mail agent records request"
	db	255,22,"*: All records request"
	db	0

QCLASS_T:	db	1,8,"Internet"
	db	2,5,"CSNET"
	db	3,5,"CHAOS"
	db	4,6,"Hesiod"
	db	255,22,"*: All classes request"
	db	0

RR_TABLE:	dw	RR_1,RR_2,RR_3,RR_4,RR_5,RR_6,RR_7,RR_8
	dw	RR_9,RR_10,RR_11,RR_12,RR_13,RR_14,RR_15,RR_16
	dw	RR_17,RR_18,RR_19,RR_20,RR_21


;--- Paquete IP

IP_START:	;
DESTIN_AD:	db	0,0,0,0	;IP destino
	db	17	;Protocolo UDP
	db	4,255	;TTL=255
	db	0

	;Aqui empieza el UDP

UDP_START:	db	34,34	;Puerto origen
	db	0,53	;Puerto destino
UDP_LENGTH:	db	0,0	;Longitud UDP en bytes
UDP_CHKSUM:	db	0,0	;Checksum

	;Aqui empieza el paquete DNS

DNS_START:	db	#12,#34	;ID
DNS_FLAGS:	db	0,0	;Flags
	db	0,1	;QDCOUNT
	db	0,0	;ANCOUNT
	db	0,0	;NSCOUNT
	db	0,0	;ARCOUNT

	;Aqui debe ir el nombre del servidor

QUERY_SERV:	;

IP_END:	;

BUFER:	equ	#1000
RECEIVED:	equ	#2000
