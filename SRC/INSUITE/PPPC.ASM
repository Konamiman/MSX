; Control program for the PPP module of InterNestor Suite

;===================================

	;--- Conectador de Internestor Suite 0.4
	;    Uso: pppc o [user password]
	;         pppc v [user password]
	;         pppc c
	;         pppc s
	;         pppc f[:file] [r]
	;         pppc k <tipo> <offset>
	;              tipo: 0=cte PPP
	;                    1=var PPP
	;                    2=cte IP
	;                    3=var IP

	;En 0.4: Uso de USEINSERROR


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

	;--- Llamadas al modulo PPP

MOD_TABLES:	equ	#8021
MOD_NETSTAT:	equ	#8024
MOD_OPEN:	equ	#8012
MOD_CLOSE:	equ	#8015
NETWORK_STATUS:	equ	#8024

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

ENASLT:	equ	#0024
TIME:	equ	#FC9E

;--- Offsets de las ctes/variables de NestorPPP

AUTH_STATUS:	equ	38
AUTH_PROTO:	equ	39
LCP_MSG_LEN:	equ	57
IPCP_MSG_LEN:	equ	58
XAP_MSG_LEN:	equ	59
NEG_DNS_PRIM:	equ	59
NEG_DNS_SEC:	equ	60
CLOSE_ERROR:	equ	65
IP_LOCAL:	equ	63
IP_REMOTE:	equ	67
DNS_PRIM:	equ	71
DNS_SEC:	equ	75
USER_LEN:	equ	79
PASSWORD_LEN:	equ	80
OPENED:	equ	96
LAST_OPCLOSE:	equ	98
IPCP_TERM_RCV:	equ	115
LCP_TERM_RCV:	equ	116


;--- Macros para leer/escribir ctes/vars

READ_CTE_B:	macro	@dir	;Devuelve valor en A
	ld	hl,(CTES_DIR)
	ld	bc,@dir
	add	hl,bc
	ld	a,(hl)
	endm

READ_CTE_W:	macro	@dir	;Devuelve valor en DE
	ld	hl,(CTES_DIR)
	ld	bc,@dir
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	endm

READ_VAR_B:	macro	@dir	;Devuelve valor en A
	ld	hl,(VARS_DIR)
	ld	bc,@dir
	add	hl,bc
	ld	a,(hl)
	endm

READ_VAR_W:	macro	@dir	;Devuelve valor en DE
	ld	hl,(VARS_DIR)
	ld	bc,@dir
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	endm

WRITE_CTE_B:	macro	@dir	;Escribe A
	ld	hl,(CTES_DIR)
	ld	bc,@dir
	add	hl,bc
	ld	(hl),a
	endm

WRITE_CTE_W:	macro	@dir	;Escribe DE
	ld	hl,(CTES_DIR)
	ld	bc,@dir
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
	endm

WRITE_VAR_B:	macro	@dir	;Escribe A
	ld	hl,(VARS_DIR)
	ld	bc,@dir
	add	hl,bc
	ld	(hl)a
	endm

WRITE_VAR_W:	macro	@dir	;Escribe DE
	ld	hl,(VARS_DIR)
	ld	bc,@dir
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
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
	ld	de,BUFPAR
	call	EXTPAR
	jr	nc,HAYPARS

TERMINFO:	print	INFO_S
	jp	TERMOK2

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

	;--- Comprueba que NestorMan este instalado, si no
	;    devuelve un error y termina

	xor	a
	nesman	1
	or	a
	jr	nz,OKNMAN1

	ld	de,NONMAN_S	;Esta instalado?
	jp	TERMERR

OKNMAN1:	ld	hl,#0201
	ex	de,hl
	call	COMP
	jr	c,OKNMAN2

	ld	de,BADNMAN_S	;Es al menos version 1.2?
	jp	TERMERR
OKNMAN2:	;

	;--- Comprueba que InterNestor este instalado, si no
	;    devuelve un error y termina

	nesman	32
	ld	(INS_SLOT),a
	or	a
	jr	nz,OKINS

	ld	de,NOINS_S
	jp	TERMERR

OKINS:	ld	(INS_SLOT),a
	push	de
	ld	a,b
	nesman	3
	ld	a,c
	ld	(INS_SEG2),a	;Obtiene segmentos de PPP e IP
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

	;--- Conecta el segmento de NestorIP en pagina 1

	ld	a,(INS_SLOT)
	ld	h,#80
	call	ENASLT
	ei

	call	SWITCH_IP

	;--- Obtiene las dirs de las tablas de ctes y vars de IP

	xor	a
	call	MOD_TABLES	;Direccion de la tabla de ctes
	ld	(CTES_DIR3),hl
	ld	(CTES_LEN3),bc
	ld	a,1
	call	MOD_TABLES
	ld	(CDEF_DIR3),hl	;Direccion de las ctes por defecto
	ld	a,2
	call	MOD_TABLES
	ld	(VARS_DIR3),hl	;Direccion de las variables

	;--- Conecta el segmento de NestorPPP en pagina 1

	call	SWITCH_PPP

	;--- Obtiene las dirs de las tablas de ctes y vars de PPP

	xor	a
	call	MOD_TABLES	;Direccion de la tabla de ctes
	ld	(CTES_DIR2),hl
	ld	(CTES_LEN2),bc
	ld	a,1
	call	MOD_TABLES
	ld	(CDEF_DIR2),hl	;Direccion de las ctes por defecto
	ld	a,2
	call	MOD_TABLES
	ld	(VARS_DIR2),hl	;Direccion de las variables
	ld	a,4
	call	MOD_TABLES
	ld	(BUFERS_DIR),hl	;Direccion de los buferes user+pass
	ld	a,3
	call	MOD_TABLES
	ld	(MSGS_DIR),hl	;Direccion de los buferes de mensajes

	ld	hl,CTES_DIR2	;Para que reconozca las variables
	ld	de,CTES_DIR
	ld	bc,8
	ldir

	;--- Comprueba la opcion y salta a la rutina adecuada

	ld	a,1
	ld	de,BUFPAR
	call	EXTPAR
	ld	a,(BUFPAR)
	or	%00100000
	cp	"o"
	jr	z,OPCION_O
	cp	"c"
	jp	z,OPCION_C
	cp	"s"
	jp	z,OPCION_S
	cp	"v"
	jp	z,OPCION_V
	cp	"i"
	jp	z,OPCION_I
	cp	"f"
	jp	z,OPCION_F
	cp	"k"
	jp	z,OPCION_K

OPDESC:	ld	de,INVOPT_S
	jp	TERMERR	;Opcion desconocida?


;------------------
;---  Apertura  ---
;------------------

OPCION_O:	call	_OPCION_O
	jp	TERMOK

	;--- Si ya esta abierto no se puede volver a abrir

_OPCION_O:	READ_VAR_B OPENED
	or	a
	jr	z,NOOPYET

	ld	de,YAOPEN_S
	jp	TERMERR

	;--- Establece las ctes a su valor por defecto

NOOPYET:	;xor     a
	;call    MOD_TABLES
	;push    hl
	;ld      a,1
	;call    MOD_TABLES
	;pop     de
	;ldir

	;--- Establece nombre

	ld	a,2
	ld	de,BUFPAR
	call	EXTPAR
	jr	c,OPO_1

	ld	a,b
	WRITE_CTE_B USER_LEN

	ld	c,a
	ld	b,0
	ld	hl,BUFPAR
	ld	de,(BUFERS_DIR)	;Copia nombre de usuario
	ldir

	print	NAMEOK_S
OPO_1:	;

	;--- Establece password

	ld	a,3
	ld	de,BUFPAR
	call	EXTPAR
	jr	c,OPO_2

	ld	a,b
	WRITE_CTE_B PASSWORD_LEN

	ld	c,a
	ld	b,0
	ld	hl,BUFPAR
	ld	de,(BUFERS_DIR)	;Copia nombre de usuario
	inc	d
	ldir

	print	PASSOK_S
OPO_2:	;

	;--- Establece OPENED

	call	MOD_OPEN

	print	CONOP_S
	ret


;----------------------------
;---  Apertura "verbose"  ---
;----------------------------

OPCION_V:	nesman	32
	ld	a,(ix)
	or	a
	jr	nz,OKVERB

	ld	de,NOVERB_S
	jp	TERMERR

OKVERB:	call	_OPCION_O
	print	PRESS_S

	ei
WA:	READ_VAR_B LAST_OPCLOSE	;Espera a que NestorPPP
	or	a	;haya reconocido la apertura
	jr	z,WA

	;--- Llama al trazador de estados

TRC_LOOP:	call	TRACER

	;--- Si se pulsa una tecla, termina

	ld	e,#FF
	ld	c,_DIRIO
	call	5
	or	a
	jp	nz,TERMOK

	;--- Si la conexion se cierra, termina

	READ_VAR_B OPENED
	or	a
	jr	nz,NOCLOSE

	call	TRACER
	print	CLOSE_S
	READ_VAR_B CLOSE_ERROR
	ld	de,CLOSE_S1
	cp	1
	jr	z,ISCLOSE3
	ld	de,CLOSE_S2
	cp	2
	jr	z,ISCLOSE3
	ld	de,CLOSE_S3
	cp	3
	jr	z,ISCLOSE3
	ld	de,CLOSE_S4
	cp	4
	jr	z,ISCLOSE3
	ld	de,CLOSE_S5
	cp	5
	jr	z,ISCLOSE3
	ld	de,CLOSE_SX
ISCLOSE3:	ld	c,_STROUT
	call	5
	jp	TERMOK
NOCLOSE:	;

	;--- Si se entra en estado de red, termina

	call	NETWORK_STATUS
	cp	3
	jr	nz,TRC_LOOP
	call	TRACER
	jp	TERMOK

	;--- Si no, vuelve al trazador

	jr	TRC_LOOP


;----------------
;---  Cierre  ---
;----------------

OPCION_C:	;

	call	MOD_CLOSE

	print	CONCLOS_S
	jp	TERMOK


;----------------
;---  Estado  ---
;----------------

OPCION_S:	;

	READ_VAR_B OPENED
	or	a	;Comprueba OPEN
	jr	z,ISCLOSE

	;--- Abierto: muestra estado

ISOPEN:	print	ISOPEN_S
	call	MOD_NETSTAT	;Llama a NETWORK_STATUS
	or	a
	ld	de,NET0_S
	jr	z,ISOPEN_2
	dec	a
	ld	de,NET1_S
	jr	z,ISOPEN_2
	dec	a
	ld	de,NET2_S
	jr	z,ISOPEN_2
	dec	a
	ld	de,NET3_S
	jr	z,ISOPEN_2
	ld	de,NETX_S
ISOPEN_2:	ld	c,_STROUT
	call	5
	jr	STATUS2

	;--- Cerrado: muestra causa

ISCLOSE:	print	ISCLOSE_S
	READ_VAR_B CLOSE_ERROR
	ld	de,CLOSE_S1
	cp	1
	jr	z,ISCLOSE2
	ld	de,CLOSE_S2
	cp	2
	jr	z,ISCLOSE2
	ld	de,CLOSE_S3
	cp	3
	jr	z,ISCLOSE2
	ld	de,CLOSE_S4
	cp	4
	jr	z,ISCLOSE2
	ld	de,CLOSE_S5
	cp	5
	jr	z,ISCLOSE2
	ld	de,CLOSE_S6
	cp	6
	jr	z,ISCLOSE2
	ld	de,CLOSE_SX
ISCLOSE2:	ld	c,_STROUT
	call	5

	;--- Muestra el mensaje de autentificacion si hay

STATUS2:	READ_VAR_B AUTH_STATUS
	cp	2	;Se ha recibido mensaje de
	jr	c,STATUS3	;autentificacion?

	ld	de,AUTHOKR_S
	cp	2
	jr	z,STATUS21	;Imprime "auth ok rcv"
	ld	de,AUTHBADR_S	;o "auth bad rcv"
STATUS21:	ld	c,_STROUT
	call	5

	READ_VAR_B XAP_MSG_LEN
	or	a
	jr	nz,STATUS20

	print	NOM_S	;No tenia mensaje?
	jp	STATUS3

STATUS20:	print	SIM_S	;Imprime mensaje
	READ_VAR_B XAP_MSG_LEN
	ld	c,a
	ld	b,0
	ld	hl,(MSGS_DIR)
	inc	h
	inc	h
	ld	de,BUFPAR
	ldir
	ex	de,hl
	ld	(hl),"$"
	print	BUFPAR

	;--- Muestra el mensaje de terminacion de IP si hay

STATUS3:	READ_VAR_B IPCP_TERM_RCV
	or	a
	jr	z,STATUS4

	READ_VAR_B IPCP_MSG_LEN
	or	a
	jr	nz,STATUS30

	print	IPTNOM_S	;No tenia mensaje?
	jr	STATUS4

STATUS30:	print	IPTMSG_S
	READ_VAR_B IPCP_MSG_LEN
	ld	c,a
	ld	b,0
	ld	hl,(MSGS_DIR)
	inc	h
	ld	de,BUFPAR
	ldir
	ex	de,hl
	ld	(hl),"$"
	print	BUFPAR

	;--- Muestra el mensaje de terminacion de LCP si hay

STATUS4:	READ_VAR_B LCP_TERM_RCV
	or	a
	jp	z,TERMOK

	READ_VAR_B LCP_MSG_LEN
	or	a
	jr	nz,STATUS40

	print	LCPTNOM_S	;No tenia mensaje?
	jp	TERMOK

STATUS40:	print	LCPTMSG_S
	READ_VAR_B LCP_MSG_LEN
	ld	c,a
	ld	b,0
	ld	hl,(MSGS_DIR)
	ld	de,BUFPAR
	ldir
	ex	de,hl
	ld	(hl),"$"
	print	BUFPAR

	jp	TERMOK


;-------------
;---  IPs  ---
;-------------

OPCION_I:	call	_OPCION_I
	jp	TERMOK

_OPCION_I:	ld	de,LOCALIP_S	;Esta en forma de subrutina
	ld	c,9	;para poder ser usada por el
	call	5	;trazador de estados
	ld	ix,(CTES_DIR)
	ld	bc,IP_LOCAL
	add	ix,bc
	call	SHOWIP
	ld	de,REMOTEIP_S
	ld	c,9
	call	5
	ld	ix,(CTES_DIR)
	ld	bc,IP_REMOTE
	add	ix,bc
	call	SHOWIP

	;Muestra los DNS

TRACER_DNS1:	ld	de,PRIMDNS_S
	ld	c,9
	call	5
	ld	ix,DNS_PRIM
	ld	a,(ix)
	or	(ix+1)
	or	(ix+3)
	or	(ix+3)
	;READ_CTE_B NEG_DNS_PRIM
	;or      a
	jr	nz,OKDNS_1
	ld	de,NONEG_S
	ld	c,9
	call	5
	jr	TRACER_DNS2
OKDNS_1:	ld	ix,(CTES_DIR)
	ld	bc,DNS_PRIM
	add	ix,bc
	call	SHOWIP

TRACER_DNS2:	ld	de,SECDNS_S
	ld	c,9
	call	5
	ld	ix,DNS_SEC
	ld	a,(ix)
	or	(ix+1)
	or	(ix+3)
	or	(ix+3)
	;READ_CTE_B NEG_DNS_SEC
	;or      a
	jr	nz,OKDNS_2
	ld	de,NONEG_S
	ld	c,9
	call	5
	jp	TERMOK
OKDNS_2:	ld	ix,(CTES_DIR)
	ld	bc,DNS_SEC
	add	ix,bc
	call	SHOWIP

	ret


;------------------------------------------------
;---  Proceso de un fichero de configuracion  ---
;------------------------------------------------

OPCION_F:	;

	;--- Primero obtiene el nombre del fichero de entrada

	ld	a,1
	ld	de,BUFPAR
	call	EXTPAR
	ld	a,b
	ld	(PARSIZE),a

	ld	a,(BUFPAR+1)
	or	a
	jr	nz,HAYFNAME1

	ld	hl,DEFFILE_S	;Si no hay nombre de fichero,
	ld	de,BUFPAR+2	;toma el nombre por defecto
	ld	bc,16
	ldir
	jr	OK_FNAME

HAYFNAME1:	cp	":"
	ld	de,INVOPT_S
	jp	nz,TERMERR

	ld	c,_PARSE	;Comorueba si el nombre de fichero
	ld	b,0	;tiene extension
	ld	de,BUFPAR+2
	call	5
	bit	4,b
	jr	nz,OK_FNAME

	ld	a,(PARSIZE)	;Si no la tiene, anyade la ext por
	ld	c,a	;defecto
	ld	b,0
	ld	hl,BUFPAR
	add	hl,bc
	ex	de,hl
	ld	hl,DEFEXT_S
	ld	bc,5
	ldir

OK_FNAME:	ld	hl,BUFPAR+2	;Convierte nombre de fichero
UPCS_LOOP:	ld	a,(hl)	;a mayusculas
	or	a
	jr	z,UPCS_END
	ld	e,a
	push	hl
	ld	c,_CHKCHR
	ld	d,0
	call	5
	pop	hl
	ld	(hl),e
	inc	hl
	jr	UPCS_LOOP
UPCS_END:	;

	;--- Comprueba si existe el segundo parametro, R

	ld	a,2
	ld	de,BUFPAR2
	call	EXTPAR
	jr	c,NO_RPAR

	ld	a,(BUFPAR2)
	or	%00100000
	cp	"r"
	ld	de,INVOPT_S
	jp	nz,TERMERR

	ld	a,#FF
	ld	(RESETCTES),a
NO_RPAR:	;

	;--- Abre el fichero y lo lee

	print	OPENING_S	;Primero imprime "opening..."
	ld	de,BUFPAR+2
	call	PRINTZ
	print	PUNTOS_S

	ld	c,_OPEN	;Abre el fichero
	ld	de,BUFPAR+2
	ld	a,1	;Solo lectura
	call	5
	jr	z,OK_OPEN

FILERROR:	ld	b,a	;Error: lo muestra y termina
	ld	de,BUFPAR2
	ld	c,_EXPLAIN
	push	de
	call	5
	pop	de
	jp	TERMERR

OK_OPEN:	push	bc	;Lee hasta MAXFILESIZE bytes
	ld	c,_READ	;y despues cierra el fichero
	ld	de,BUFFILE
	ld	hl,MAXFILESIZE
	call	5
	pop	bc
	push	af,hl
	ld	c,_CLOSE
	call	5
	pop	hl,af	;Error al leer: lo trata como
	cp	#C7
	jr	z,OK_OPEN2	;Si es "End of file" lo ignora
	or	a	;(fichero vacio)
	jr	nz,FILERROR	;error al abrir
OK_OPEN2:	;

	ld	de,MAXFILESIZE	;Si de verdad se han leido
	call	COMP	;MAXFILESIZE bytes significa que el
	jr	nz,OKFSIZE	;fichero es mas grande:
	ld	de,TOOBIGF_S	;entonces muestra error y termina
	jp	TERMERR
OKFSIZE:	;

	ex	de,hl
	ld	hl,BUFFILE
	add	hl,de
	ld	(hl),#1A	;Anyade un EOF al final

	;--- Lee las constantes adecuadas a CTES_PPP y CTES_IP
	;    Si se ha especificado R, lee las ctes por defecto;
	;    si no, lee las ctes actuales
	;    Se ira modificando CTES_PPP y CTES_IP a medida que
	;    se vaya procesando el fichero, y al final
	;    se copiaran estas a los segmentos del PPP e IP

	call	SWITCH_PPP
	ld	a,(RESETCTES)
	or	a
	ld	hl,(CTES_DIR2)
	jr	z,OKSETCTES1
	ld	hl,(CDEF_DIR2)
OKSETCTES1:	ld	de,CTES_PPP
	ld	bc,(CTES_LEN)
	ldir

	call	SWITCH_IP
	ld	a,(RESETCTES)
	or	a
	ld	hl,(CTES_DIR3)
	jr	z,OKSETCTES2
	ld	hl,(CDEF_DIR3)
OKSETCTES2:	ld	de,CTES_IP
	ld	bc,(CTES_LEN)
	ldir

	;--- Procesa el fichero

	print	PROCESS_S
	ld	ix,BUFFILE

	;Obtiene una linea del fichero
	;y compara el nombre con todas las ctes de la tabla
	;hasta que la encuentra o se acaba la tabla

NEXT_FCTE:	call	READLINE
	ld	iy,CTES_TABLE

COMP_FT:	ld	a,(iy)	;Final de la lista?
	or	a	;Entonces no se ha encontrado:
	jp	z,FERR_NAME	;error

	ld	hl,BUFLINE
	xor	a
	push	iy
	pop	de
	ld	bc,0
	scf
	call	INSTR
	ld	a,b
	cp	1
	jr	z,CTE_FND

	;No coincide: pasa a la siguiente cte de la tabla

NEXT_TCTE:	ld	a,(iy)
	inc	iy
	or	a
	jr	nz,NEXT_TCTE
	ld	bc,4
	add	iy,bc
	jr	COMP_FT

	;Encontrado: obtiene direccion del valor en ASCII
	;y de la posicion en la tabla

CTE_FND:	ld	a,(iy)	;Se posiciona tras el nombre
	inc	iy	;de la cte en la tabla
	or	a
	jr	nz,CTE_FND

	ld	a,(iy)	;Obtiene el modulo de la cte:
	cp	2	;Devuelve HL=Puntero a la
	ld	hl,CTES_PPP	;copia de la tabla de ctes
	jr	z,CTE_FND2	;para el modulo adecuado
	cp	3
	ld	hl,CTES_IP
	jr	z,CTE_FND2
	jp	FERR_INT
CTE_FND2:	;

	ld	a,(iy+1)	;Obtiene tipo de valor
	ld	b,(iy+3)	;Obtiene offset en la tabla
	ld	c,(iy+2)
	add	hl,bc	;Obtiene dir. absoluta en la tabla
	ld	(CTE_TABLE_DIR),hl

	push	af
	ld	hl,BUFLINE
CTE_FND3:	ld	a,(hl)
	inc	hl
	cp	" "
	jr	nz,CTE_FND3
	ld	(CTE_LINE_DIR),hl
	pop	af

	or	a
	jp	z,FERR_INT
	dec	a
	jr	z,CTE_TYPE1
	dec	a
	jr	z,CTE_TYPE2
	dec	a
	jr	z,CTE_TYPE3
	dec	a
	jr	z,CTE_TYPE4
	dec	a
	jp	z,CTE_TYPE5
	dec	a
	jp	z,CTE_TYPE6
	jp	FERR_INT

	;* En este punto tenemos:
	;  CTE_TABLE_DIR = Direccion de la cte en la copia
	;  de la tabla adecuada (CTES_PPP o CTES_IP)
	;  CTE_LINE_DIR = Direccion de la cadena con el valor
	;  de la constante en ASCII
	;  IX apunta a la siguiente linea en el fichero,
	;  hay que conservarlo
	;Ahora hay que extraer el valor numerico de la cadena ASCII
	;y escribirlo en la tabla

	;- Typo byte: extrae el numero, ha de ser 0-255

CTE_TYPE1:	ld	hl,(CTE_LINE_DIR)
	call	EXTNUM8
	jp	c,FERR_VALUE
	ld	hl,(CTE_TABLE_DIR)
	ld	(hl),a

	jp	NEXT_FCTE

	;- Typo word: extrae el numero, ha de ser 0-65535

CTE_TYPE2:	ld	hl,(CTE_LINE_DIR)
	call	EXTNUM16
	jp	c,FERR_VALUE
	ld	hl,(CTE_TABLE_DIR)
	ld	(hl),c
	inc	hl
	ld	(hl),b

	jp	NEXT_FCTE

	;- Typo flag: extrae el numero, ha de ser 0-65535
	;  Si no es 0, se interpreta #FF

CTE_TYPE3:	ld	hl,(CTE_LINE_DIR)
	call	EXTNUM16
	jp	c,FERR_VALUE
	ld	hl,(CTE_TABLE_DIR)
	ld	a,b
	or	c
	jr	z,CTE_TYPE30
	ld	a,#FF
CTE_TYPE30:	ld	(hl),a

	jp	NEXT_FCTE

	;--- Tipo direccion IP: extrae la idem

CTE_TYPE4:	ld	hl,(CTE_LINE_DIR)
CTE_TYPE40:	ld	a,(hl)
	inc	hl
	or	a
	jr	nz,CTE_TYPE40	;Anyade un punto al final
	dec	hl
	ld	(DOT_DIR),hl
	ld	(hl),"."
	ld	hl,(CTE_LINE_DIR)

	ld	de,(CTE_TABLE_DIR)
	ld	b,4

IPLOOP:	push	bc,de
	call	EXTNUM
	jp	c,IPERROR	;Comprueba que sea un numero
	or	a	;entre 0 y 255 y acabado en 0
	jp	nz,IPERROR
	ld	a,b
	or	a
	jp	nz,IPERROR
	ld	a,e
	cp	"."
	jp	nz,IPERROR

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

	jp	NEXT_FCTE

IPERROR:	ld	hl,(DOT_DIR)
	ld	(hl),0
	jp	FERR_VALUE

DOT_DIR:	dw	0

	;- Tipo nombre de usuario

CTE_TYPE5:	call	SWITCH_PPP
	ld	de,(BUFERS_DIR)
	ld	hl,(CTE_LINE_DIR)
	ld	b,-1
CTE_TYPE5_L:	ld	a,(hl)
	ld	(de),a
	inc	b
	inc	de
	inc	hl
	or	a
	jr	nz,CTE_TYPE5_L

	ld	a,b
	ld	(CTES_PPP+USER_LEN),a

	jp	NEXT_FCTE

	;- Tipo password

CTE_TYPE6:	call	SWITCH_PPP
	ld	de,(BUFERS_DIR)
	inc	d
	ld	hl,(CTE_LINE_DIR)
	ld	b,-1
CTE_TYPE6_L:	ld	a,(hl)
	ld	(de),a
	inc	b
	inc	de
	inc	hl
	or	a
	jr	nz,CTE_TYPE6_L

	ld	a,b
	ld	(CTES_PPP+PASSWORD_LEN),a
	jp	NEXT_FCTE


	;--- El fichero ya ha sido procesado:
	;    se copian las constantes y termina

FILEPROC_OK:	print	CONFOK_S

	call	SWITCH_PPP
	ld	hl,CTES_PPP
	ld	de,(CTES_DIR2)
	ld	bc,(CTES_LEN2)
	ldir

	call	SWITCH_IP
	ld	hl,CTES_IP
	ld	de,(CTES_DIR3)
	ld	bc,(CTES_LEN3)
	ldir

	jp	TERMOK

	;--- Error al procesar el fichero

FERR_NAME:	ld	de,BADNAME_S
	jr	FERR
FERR_VALUE:	ld	de,BADVALUE_S
	jr	FERR
FERR_INT:	ld	de,INTERR_S

FERR:	push	de
	print	ASTER_S
	ld	de,ERWPROC_S
	call	PRINTZ	;Imprime "error when processing..."
	pop	de	;Imprime el tipo de error
	ld	c,_STROUT
	call	5

	ld	de,(CURLINE)	;Imprime "In line xxx:"
	ld	hl,INLINE_S_NUM
	ld	b,1
	ld	a,%1000
	call	NUMTOASC
	print	INLINE_S
	print	DOSPUN_S

	ld	de,BUFLINE	;Imprime la linea erronea
	call	PRINTZ
	print	CRLF_S

	ld	de,ERWPROC_S
	ld	a,#FF
	ld	(NOPRERR),a
	jp	TERMERR


;------------------------------------
;---  Mesutra variable/constante  ---
;------------------------------------

OPCION_K:	;

	;--- Extrae tipo y conecta el segmento adecuado

	ld	a,2
	ld	de,BUFPAR
	call	EXTPAR
	ld	de,MISPAR_S
	jp	c,TERMERR

	ld	de,UNKTYP_S
	ld	a,(BUFPAR+1)
	or	a
	jp	nz,TERMERR
	ld	a,(BUFPAR)
	sub	"0"
	and	%11111100
	ld	de,UNKTYP_S
	jp	nz,TERMERR

	ld	a,(BUFPAR)
	and	%10
	ld	hl,OP_K2
	push	hl
	or	a
	jp	z,SWITCH_PPP
	jp	SWITCH_IP
OP_K2:	;

	;--- Extrae offset y lo imprime

	ld	a,(BUFPAR)	;Es cte o var?
	and	%11
	ld	(PEEKTYPE),a
	and	%1
	ld	hl,(CTES_DIR)
	jr	z,OP_OK3
	ld	hl,(VARS_DIR)
OP_OK3:	ld	(CTE_VAR_DIR),hl

	ld	a,3
	ld	de,BUFPAR
	call	EXTPAR
	ld	de,MISOFF_S
	jp	c,TERMERR
	ld	c,b
	ld	b,0
	ld	hl,BUFPAR
	add	hl,bc
	push	hl

	ld	hl,BUFPAR	;Convierte offset a numero
	call	EXTNUM16
	ld	de,INVOFF_S
	jp	c,TERMERR
	pop	hl
	ld	(hl),"$"

	push	bc	;Imprime tipo de peticion
	ld	a,(PEEKTYPE)
	ld	de,TYPE0_S
	or	a
	jr	z,OP_K4
	ld	de,TYPE1_S
	dec	a
	jr	z,OP_K4
	ld	de,TYPE2_S
	dec	a
	jr	z,OP_K4
	ld	de,TYPE3_S
OP_K4:	ld	c,_STROUT
	call	5

	print	OFFSET_S	;Imprime offset
	print	BUFPAR
	print	CRLF_S

	pop	bc
	ld	hl,(CTE_VAR_DIR)
	add	hl,bc	;HL = Direccion a PEEKear

	push	hl
	ld	e,(hl)	;Imprime 1 byte, decimal
	ld	d,0
	ld	hl,BYTE_S_NUM
	ld	b,1
	ld	a,%1000
	call	NUMTOASC
	print	BYTE_S
	print	COMA_S
	pop	hl

	push	hl
	ld	e,(hl)	;Imprime 1 byte, hexadecimal
	ld	d,0
	ld	hl,BYTE_S_NUM
	ld	b,2
	ld	c,"0"
	ld	a,%1001
	call	NUMTOASC
	print	BYTE_S_NUM
	pop	hl

	push	hl
	ld	e,(hl)	;Imprime 2 bytes, decimal
	inc	hl
	ld	d,(hl)
	ld	hl,WORD_S_NUM
	ld	b,1
	ld	a,%1000
	call	NUMTOASC
	print	WORD_S
	print	COMA_S
	pop	hl

	push	hl
	ld	e,(hl)	;Imprime 2 bytes, hexadecimal
	inc	hl
	ld	d,(hl)
	ld	hl,WORD_S_NUM
	ld	b,4
	ld	c,"0"
	ld	a,%1001
	call	NUMTOASC
	print	WORD_S_NUM
	pop	hl

	push	hl
	ld	d,(hl)	;Imprime 2 bytes, decimal, big endian
	inc	hl
	ld	e,(hl)
	ld	hl,WBE_S_NUM
	ld	b,1
	ld	a,%1000
	call	NUMTOASC
	print	WBE_S
	print	COMA_S
	pop	hl

	push	hl
	ld	d,(hl)	;Imprime 2 bytes, hexadecimal, big e.
	inc	hl
	ld	e,(hl)
	ld	hl,WBE_S_NUM
	ld	b,4
	ld	c,"0"
	ld	a,%1001
	call	NUMTOASC
	print	WBE_S_NUM
	pop	hl

	jp	TERMOK




;******************************
;***                        ***
;***   RUTINAS AUXILIARES   ***
;***                        ***
;******************************

;--- GETCHAR: Obtiene un caracter del fichero de configuracion
;             El puntero esta en IX y es actualizado
;             Si lee #1A (EOF) salta a FILEPROC_OK

GETCHAR:	ld	a,(ix)
	inc	ix
	cp	#1A
	jp	z,FILEPROC_OK
	cp	13
	jr	nz,GETCHAR2
	push	hl
	ld	hl,(CURLINE)	;Si es CR, incrementa el num de linea
	inc	hl
	ld	(CURLINE),hl
	pop	hl
GETCHAR2:	cp	10	;Si es LF, devuelve CR
	jr	z,GETCHAR
	ret

;--- SKIPSP: Se salta los espacios/tabuladores

SKIPSP:	push	af
SKIPSP2:	call	GETCHAR
	cp	32	;Espacio
	jr	z,SKIPSP2
	cp	9	;Tabulador
	jr	z,SKIPSP2
	dec	ix
	cp	13
	jr	nz,SKIPSP3
	push	hl
	ld	hl,(CURLINE)
	dec	hl
	ld	(CURLINE),hl
	pop	hl
SKIPSP3:	pop	af
	ret

;--- SKIPLINE: Se salta una linea

SKIPLINE:	call	GETCHAR
	cp	13
	jr	nz,SKIPLINE
	ret

;--- READLINE: Lee una linea a BUFLIN
;              Se salta las lineas en blanco, y los comentarios

READLINE:	call	_READLINE	;Si al final habia un espacio,
	dec	hl	;lo suprime
	ld	a,(hl)
	cp	" "
	ret	nz
	ld	(hl),0
	ret

_READLINE:	call	SKIPSP	;Se salta los espacios iniciales
	call	GETCHAR
	cp	";"
	jr	z,READL_REM
	cp	"#"
	jr	z,READL_REM
	cp	13
	jr	z,READL_EMPTY
	ld	hl,BUFLINE
	jr	READL2

READL_LOOP:	call	GETCHAR
READL2:	cp	9	;Sustituye tab por espacio
	jr	nz,READL3
	ld	a,32
READL3:	ld	(hl),a
	inc	hl
	cp	" "
	call	z,SKIPSP
	cp	"#"
	jp	z,READL_REM2
	cp	";"
	jp	z,READL_REM2
	cp	13	;Si es el fin de linea, pone 0
	jr	nz,READL_LOOP
	dec	hl
	ld	(hl),0
	ret

READL_REM:	call	SKIPLINE	;La linea empieza con un comentario
	pop	bc
	jr	READLINE

READL_REM2:	dec	hl	;La linea tiene un comentario
	ld	(hl),0	;dentro: se salta esa parte
	pop	bc
	jp	SKIPLINE

READL_EMPTY:	pop	bc	;La linea esta vacia
	jr	READLINE


	;*** Pruebas de las rutinas para leer el fichero

HAZPBA:	equ	1

	if	HAZPBA=1

PBA:	ld	ix,aki	;Prueba!
ello:	call	READLINE
	jr	ello

aki:	db	"Las ellas de akello",13,10
	db	"  ;Esta se la salta",13,10
	db	"#Esta tambenne",13,10
	db	"   Se   salta  los   espacios",13,10
	db	"Esto lo lee ;esto no!",13,10
	db	"  Esto si #esto tampoco",13,10
	db	13,10
	db	"    ",13,10
	db	"La",9,"proximas",9,"la",9,"siguiente",13,10
	db	"  Esspacioos    para todooos    ",13,10

	endif


;--- SWITCH_PPP: Conecta el segmento de NestorPPP, si no esta ya conectado

SWITCH_PPP:	ld	a,(CUR_SEG)
	cp	2
	ret	z

	ld	a,(INS_SEG2)
	call	PUT_P2
	ld	hl,CTES_DIR2
	ld	de,CTES_DIR
	ld	bc,8
	ldir
	ld	a,2
	ld	(CUR_SEG),a
	ret

;--- SWITCH_IP: Conecta el segmento de NestorIP, si no esta ya conectado

SWITCH_IP:	ld	a,(CUR_SEG)
	cp	3
	ret	z

	ld	a,(INS_SEG3)
	call	PUT_P2
	ld	hl,CTES_DIR3
	ld	de,CTES_DIR
	ld	bc,8
	ldir
	ld	a,3
	ld	(CUR_SEG),a
	ret

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


;--- EXTNUM16: Extrae un numero de 16 bits
;    Entrada:  HL = Dir. cadena ASCII
;    Salida:   BC = Numero
;              Cy=1 si error
;              Preserva DE

EXTNUM16:	push	de
	call	_EXTNUM16
	pop	de
	ret

_EXTNUM16:	call	EXTNUM
	ret	c
	or	a
	scf
	ret	nz
	ld	a,e
	or	a
	scf
	ret	nz
	or	a
	ret


;--- EXTNUM8:  Extrae un numero de 8 bits
;    Entrada:  HL = Dir. cadena ASCII
;    Salida:   A = Numero
;              Cy=1 si error
;              Preserva DE

EXTNUM8:	push	de
	call	_EXTNUM8
	pop	de
	ret

_EXTNUM8:	call	EXTNUM
	ret	c
	or	a
	scf
	ret	nz
	ld	a,b
	or	a
	scf
	ret	nz
	ld	a,e
	or	a
	scf
	ret	nz
	ld	a,c
	or	a
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

	pop	de
	ld	a,(NOPRERR)
	or	a
	jr	nz,TERMOK
	push	de

	print	ERRORAST_S
	pop	de	;Imprime la cadena de error
	call	PRINTZ
	print	CRLF_S

TERMOK:	ld	a,(#F343)
	ld	h,#80
	call	ENASLT
	ld	a,1
	call	PUT_P2

TERMOK2:	ld	bc,#0062
	jp	5

NOPRERR:	db	0	;Si es #FF, no se imprime el error


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


;--- SHOWIP: Muestra la IP almacenada en IX

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



;********************************
;***                          ***
;***   TRAZADOR DE CONEXION   ***
;***                          ***
;********************************

TRACER:	;
	;--- Si llega LCP Terminate Request, avisa
	;    y muestra el mensaje en pantalla

TRACER_1:	READ_VAR_B LCP_TERM_RCV
	or	a
	jr	z,TRACER_2
	ld	a,(PPPC_LCPT)
	or	a
	jr	nz,TRACER_2
	ld	a,#FF
	ld	(PPPC_LCPT),a

	READ_VAR_B LCP_MSG_LEN
	or	a
	jr	nz,TRACER_1B

TRACER_1A:	ld	de,LCPRCV_S1	;Sin mensaje
	ld	c,9
	call	5
	jr	TRACER_2

TRACER_1B:	ld	de,LCPRCV_S2	;Con mensaje
	ld	c,9
	call	5
	READ_VAR_B LCP_MSG_LEN
	ld	c,a
	ld	b,0
	ld	hl,(MSGS_DIR)
	ld	de,BUFPAR
	ldir
	ex	de,hl
	ld	(hl),13
	inc	hl
	ld	(hl),10
	inc	hl
	ld	(hl),"$"
	ld	de,BUFPAR
	ld	c,9
	call	5

	;--- Si llega IPCP Terminate Request, avisa
	;    y muestra el mensaje en pantalla

TRACER_2:	READ_VAR_B IPCP_TERM_RCV
	or	a
	jr	z,TRACER_3
	ld	a,(PPPC_IPCPT)
	or	a
	jr	nz,TRACER_3
	ld	a,#FF
	ld	(PPPC_IPCPT),a

	ld	a,(IPCP_MSG_LEN)
	or	a
	jr	nz,TRACER_2B

TRACER_2A:	ld	de,IPCPRCV_S1	;Sin mensaje
	ld	c,9
	call	5
	jr	TRACER_3

TRACER_2B:	ld	de,IPCPRCV_S2	;Con mensaje
	ld	c,9
	call	5
	READ_VAR_B IPCP_MSG_LEN
	ld	c,a
	ld	b,0
	ld	hl,(MSGS_DIR)
	inc	h
	ld	de,BUFPAR
	ldir
	ex	de,hl
	ld	(hl),13
	inc	hl
	ld	(hl),10
	inc	hl
	ld	(hl),"$"
	ld	de,BUFPAR
	ld	c,9
	call	5

	;--- AUTH_STATUS:
	;    Si pasa a 2, muestra "Auth OK"
	;    Si pasa a 3, muestra "Auth BAD"

TRACER_3:	ld	hl,(VARS_DIR)
	ld	bc,AUTH_STATUS
	add	hl,bc
	ld	de,TRACER_OLD_AUTH
	call	TEST_VAR
	cp	b	;Variable no ha cambiado:
	jr	z,TRACER_4	;no hace nada

	ld	hl,XAPOKRCV_S1
	ld	de,XAPOKRCV_S2
	cp	2
	jr	z,TRACER_3C
	ld	hl,XAPBADRCV_S1
	ld	de,XAPBADRCV_S2
	cp	3
	jr	nz,TRACER_4

TRACER_3C:	push	hl
	READ_VAR_B XAP_MSG_LEN	;2 o 3
	pop	hl
	or	a
	jr	nz,TRACER_3B

TRACER_3A:	ex	de,hl	;Sin mensaje
	ld	c,9
	call	5
	jr	TRACER_4

TRACER_3B:	ld	c,9	;Con mensaje
	call	5
	READ_VAR_B XAP_MSG_LEN
	ld	c,a
	ld	b,0
	ld	hl,(MSGS_DIR)
	inc	h
	inc	h
	ld	de,BUFPAR
	ldir
	ex	de,hl
	ld	(hl),13
	inc	hl
	ld	(hl),10
	inc	hl
	ld	(hl),"$"
	ld	de,BUFPAR
	ld	c,9
	call	5

	;--- Si se recibe OPEN, avisa

TRACER_4:	ld	hl,(VARS_DIR)
	ld	bc,OPENED
	add	hl,bc
	ld	de,TRACER_OLDOPEN
	call	TEST_VAR
	cp	b
	jr	z,TRACER_8
	or	a
	jr	z,TRACER_8

	ld	de,OPEN_S
	ld	c,9
	call	5

	;--- NETWORK_STATUS:
	;    Si pasa a 0, imprime "Entering link negotiation"
	;    Si pasa a 1, imprime "Entering authentication"
	;    Si pasa a 2, imprime "Entering IP negotiation"
	;    Si pasa a 3, imprime "Connection OK!"

TRACER_8:	call	NETWORK_STATUS
	ld	c,a
	ld	a,(TRACER_OLDNET)
	ld	b,a
	ld	a,c
	ld	(TRACER_OLDNET),a
	cp	b
	jp	z,TRACER_9

	or	a
	ld	de,ENTERLCP_S
	jr	z,TRACER_8A
	cp	1
	ld	de,ENTERAUTH_S
	jr	z,TRACER_8B
	cp	2
	ld	de,ENTERIPCP_S
	jr	z,TRACER_8A
	cp	3
	ld	de,NETOK_S
	jp	nz,TRACER_9
	ld	c,_STROUT
	call	5

	;Muestra tambien las IPs

	call	_OPCION_I
	jr	TRACER_9

	;Muestra "authenticaating"

TRACER_8A:	ld	c,9
	call	5
	jr	TRACER_9

TRACER_8B:	ld	c,9
	call	5
	READ_VAR_B AUTH_PROTO
	cp	#C0
	ld	de,AUTHPAP_S
	jr	z,TRACER_8C
	cp	#C2
	ld	de,AUTHCHAP_S
	jr	z,TRACER_8C
	ld	de,AUTHUNK_S

TRACER_8C:	ld	c,9
	call	5

TRACER_9:	;

	ret

	;--- TEST_VAR: Devuelve en A el nuevo valor de la
	;    variable HL, y en B el antiguo (guardado en DE)

TEST_VAR:	ld	a,(de)
	ld	b,a
	ld	a,(hl)
	ld	(de),a
	ret

	;--- Variables

TRACER_OLD_AUTH:	db	0
TRACER_OLDOPEN:	db	0
TRACER_OLDLCP:	db	0
TRACER_OLDIPCP:	db	0
TRACER_OLDNET:	db	#FF
PPPC_LCPT:	db	0
PPPC_IPCPT:	db	0

	;--- Cadenas

LCPRCV_S1:	db	"* Link layer termination request received with no message",13,10,"$"
LCPRCV_S2:	db	"* Link layer termination request received with message:",13,10,"$"
IPCPRCV_S1:	db	"* IP layer termination request received with no message",13,10,"$"
IPCPRCV_S2:	db	"* IP layer termination request received with message:",13,10,"$"
XAPOKRCV_S1:	db	"! Authentication succeeded - no message received",13,10,"$"
XAPOKRCV_S2:	db	"! Authentication succeeded with message:",13,10,"$"
XAPBADRCV_S1:	db	"* Authentication failed - no message received",13,10,"$"
XAPBADRCV_S2:	db	"* Authentication failed with message:",13,10,"$"
OPEN_S:	db	"- Connection opened.",13,10,"$"
CLOSE_S:	db	"- Connection closed. Cause: $"
ENTERLCP_S:	db	"- Entering link parameters negotiation phase...",13,10,"$"
ENTERIPCP_S:	db	"- Entering IP parameters negotiation phase...",13,10,"$"
ENTERAUTH_S:	db	"- Entering authentication phase $"
AUTHPAP_S:	db	"via PAP...",13,10,"$"
AUTHCHAP_S:	db	"via CHAP...",13,10,"$"
AUTHUNK_S:	db	"via ???...",13,10,"$"
NETOK_S:	db	"! All negotiations OK. Network state entered.",13,10,"$"
PRESS_S:	db	13,10,"*** Press any key to exit verbose mode",13,10,10,"$"



;****************************
;***                      ***
;***   DATOS, VARIABLES   ***
;***                      ***
;****************************

;--- Constantes a configurar
;    Formato:
;    - Nombre+0
;    - 2 si pertenece al PPP, 3 si al IP
;    - Tipo:
;      1: Byte
;      2: Word
;      3: Flag
;      4: IP
;      5: USER
;      6: PASSWORD
;    - Offset en la tabla

	;Ctes para PPP

CTES_TABLE:	db	"MRU",0
	db	2
	db	2
	dw	0

	db	"ESC_I_TAB",0
	db	2
	db	4
	dw	34

	db	"AUTH_POLICY",0
	db	2
	db	1
	dw	38

	db	"MAGIC_O_NEG",0
	db	2
	db	3
	dw	39

	db	"ADDCMP_O_NEG",0
	db	2
	db	3
	dw	40

	db	"PROTCMP_O_NEG",0
	db	2
	db	3
	dw	41

	db	"ADDCMP_I_NEG",0
	db	2
	db	3
	dw	42

	db	"PROTCMP_I_NEG",0
	db	2
	db	3
	dw	43

	db	"MIN_MTU",0
	db	2
	db	2
	dw	44

	db	"LOOPBACK_MAX",0
	db	2
	db	1
	dw	46

	db	"MAX_BADBYTES",0
	db	2
	db	2
	dw	47

	db	"RST_TIMER",0
	db	2
	db	2
	dw	49

	db	"TOTAL_TIMER",0
	db	2
	db	2
	dw	51

	db	"MAX_TERMINATE",0
	db	2
	db	1
	dw	53

	db	"MAX_CONFIGURE",0
	db	2
	db	1
	dw	54

	db	"MAX_FAILURE",0
	db	2
	db	1
	dw	55

	db	"PAPREQ_TIMER",0
	db	2
	db	1
	dw	56

	db	"ECHO_TIMER",0
	db	2
	db	2
	dw	57

	db	"NEG_DNS_PRIM",0
	db	2
	db	3
	dw	59

	db	"NEG_DNS_SEC",0
	db	2
	db	3
	dw	60

	db	"AUTO_CLOSE_AUTH",0
	db	2
	db	3
	dw	61

	db	"AUTO_CLOSE_TERM",0
	db	2
	db	3
	dw	62

	db	"IP_LOCAL",0
	db	2
	db	4
	dw	63

	db	"IP_REMOTE",0
	db	2
	db	4
	dw	67

	db	"DNS_PRIM",0
	db	2
	db	4
	dw	71

	db	"DNS_SEC",0
	db	2
	db	4
	dw	75

	db	"USER",0
	db	2
	db	5
	dw	0	;Aqui no tiene sentido el offset

	db	"PASSWORD",0
	db	2
	db	6
	dw	0	;Aqui no tiene sentido el offset

	db	"PASSIVE_OPEN",0
	db	2
	db	3
	dw	81

	db	"ECHO_CLOSE",0
	db	2
	db	1
	dw	83

	;Ctes para IP

	db	"MASK_METHOD",0
	db	3
	db	1
	dw	0

	db	"SUBNET_MASK",0
	db	3
	db	4
	dw	5

	db	"ZERO_IP_VALID",0
	db	3
	db	3
	dw	9

	db	"MASK_REP_AUTH",0
	db	3
	db	3
	dw	10

	db	"MASK_REQ_NUM",0
	db	3
	db	1
	dw	11

	db	"MASK_REQ_INT",0
	db	3
	db	2
	dw	12

	db	"FRAG_TIMEOUT",0
	db	3
	db	2
	dw	14

	db	"TTL_DEFAULT",0
	db	3
	db	1
	dw	16

	db	"IGNORE_ECHO",0
	db	3
	db	3
	dw	17

	db	"DNS_TOUT",0
	db	3
	db	2
	dw	18

	db	"DNS_TTOUT",0
	db	3
	db	2
	dw	20

	db	"DNS_RETRY",0
	db	3
	db	1
	dw	22

	db	0	;Fin de la tabla


	;--- Cadenas

PRESEN_S:	db	13,10,"NestorPPP control program 0.3",13,10
	db	"By Konami Man, 12-2001",13,10,10,"$"
INFO_S:	db	"Use:",13,10
	db	"* PPPC O [user [password]]",13,10
	db	"Puts NestorPPP in the opened state,",13,10
	db	"and optionally stablishes the given username and password",13,10,10
	db	"* PPPC V [user [password]]",13,10
	db	"Verbose open, shows information until connection",13,10
	db	"is either completed or aborted",13,10,10
	db	"* PPPC C",13,10
	db	"Puts NestorPPP in the closed state",13,10,10
	db	"* PPPC S",13,10
	db	"Shows the current NestorPPP status",13,10,10
	db	"* PPPC I",13,10
	db	"Shows information about IP addresses",13,10,10
	db	"* PPPC F[:<filename>] [R]",13,10
	db	"Configures PPP and IP constants according with the specified filename",13,10
	db	"- If no filename is specified, PPPC.CFG is assumed",13,10
	db	"- If no filename extension is specified, .CFG is assumed",13,10
	db	"- If R is specified, all constants not included in the configuration file",13,10
	db	"  are reset to their default values",13,10
	db	"- Remember that when an opened connection is closed, all variables are",13,10
	db	"  automatically reset to their default values",13,10
	db	"See the sample file SAMPLE.CFG",13,10
	db	"TIP: To just reset all constants, use ",34,"PPPC F:null R",34,13,10,10
	db	"* PPPC K <type> <offset>",13,10
	db	"Shows the contents of the variable/constant with the specified offset",13,10
	db	"<type>: 0 = PPP module constant",13,10
	db	"        1 = PPP module variable",13,10
	db	"        2 = IP module constant",13,10
	db	"        3 = IP module variable",13,10
	db	"Specify <offset> in decimal",13,10
	db	10
	db	"To enable error checking execute SET USEINSERROR=anything",13,10
	db	"$"

NONMAN_S:	db	"NestorMan not installed!",13,10
	db	"NestorMan version 1.21 or higher is needed.",0
BADNMAN_S:	db	"Invalid NestorMan version!",13,10
	db	"NestorMan version 1.21 or higher is needed.",0
INVOPT_S:	db	"Invalid option",0
NOINS_S:	db	"InterNestor suite is not installed",0
NAMEOK_S:	db	"User name stablished",13,10,"$"
PASSOK_S:	db	"Password stablished",13,10,"$"
CONOP_S:	db	"Connection opened",13,10,"$"
CONCLOS_S:	db	"Connection closed",13,10,"$"
ISOPEN_S:	db	"Connection is OPENED",13,10
	db	"Connection status:",13,10,"$"
ISCLOSE_S:	db	"Connection is CLOSED.",13,10,"Cause: $"
CLOSE_S1:	db	"User close request.",13,10,"$"
CLOSE_S2:	db	"Authentication failed.",13,10,"$"
CLOSE_S3:	db	"Loopback condition detected.",13,10,"$"
CLOSE_S4:	db	"Connection timeout expired.",13,10,"$"
CLOSE_S5:	db	"Remote termination request.",13,10,"$"
CLOSE_S6:	db	"Too many unreplied echoes sent.",13,10,"$"
CLOSE_SX:	db	"Unknown.",13,10,"$"
NET0_S:	db	"Negotiating link parameters",13,10,"$"
NET1_S:	db	"Sending user name and password",13,10,"$"
NET2_S:	db	"Negotiating IP parameters",13,10,"$"
NET3_S:	db	"Network state, data can be carried",13,10,"$"
NETX_S:	db	"Unknown!",13,10,"$"
LOCALIP_S:	db	"Local IP address: $"
REMOTEIP_S:	db	"Remote IP address: $"
PRIMDNS_S:	db	"Primary DNS address: $"
SECDNS_S:	db	"Secondary DNS address: $"
NONEG_S:	db	"Not available",13,10,"$"
AUTHOKR_S:	db	13,10,"* An authentication success packet was received with $"
AUTHBADR_S:	db	13,10,"* An authentication failure packet was received with $"
NOM_S:	db	"no message.$"
SIM_S:	db	"message:",13,10,"$"
IPTNOM_S:	db	13,10,"* An IP layer termination request was received with no message.$"
IPTMSG_S:	db	13,10,"* An IP layer termination request was received with message:",13,10,"$"
LCPTNOM_S:	db	13,10,"* A link layer termination request was received with no message.$"
LCPTMSG_S:	db	13,10,"* A link layer termination request was received with message:",13,10,"$"
YAOPEN_S:	db	"NestorPPP is already in the OPEN state.",13,10
	db	"The current connection must be closed (PPPC C) before opening a new one.",0
NOVERB_S:	db	"InterNestor Suite is currently paused.",13,10
	db	"Verbose connection is not possible if INS is not active (INSINS R).",0
TORESET_S:	db	13,10,10,"To reset error condition, execute ",34,"SET INSERROR=",34,13,10
	db	"To disable error checking, execute ",34,"SET USEINSERROR=",34,13,10,"$"
ERRORAST_S:	db	"*** ERROR: $"
ERRETBY_S:	db	"*** ERROR returned by $"
UNK_S:	db	"unknown program",0
TOOBIGF_S:	db	"Configuration file too big (maximum file size is 22 KByte)",0
ASTER_S:	db	13,10,"* $"
ERWPROC_S:	db	"Error when processing configuration file",0
UNKTYP_S:	db	"Unknown constant/variable type",0
MISPAR_S:	db	"Missing parameters",0
INVOFF_S:	db	"Invalid offset number - must be 0 to 65535",0
MISOFF_S:	db	"Missing parameter - variable offset must be specified",0
BADNAME_S:	db	": unknown/invalid constant name",13,10,"$"
BADVALUE_S:	db	": invalid value",13,10,"$"
INTERR_S:	db	": PPPC internal error, contact author!",13,10,"$"
TYPE0_S:	db	"Type: PPP constant",13,10,"$"
TYPE1_S:	db	"Type: PPP variable",13,10,"$"
TYPE2_S:	db	"Type: IP constant",13,10,"$"
TYPE3_S:	db	"Type: IP variable",13,10,"$"

PROGRAM_S:	db	"PROGRAM",0
INSERR_S:	db	"INSERROR",0
INSERRP_S:	db	"INSERRORP",0
USEINSERR_S:	db	"USEINSERROR",0
DOSPUN_S:	db	":"
CRLF_S:	db	13,10,"$"
DEFFILE_S:	db	"PPPC.CFG",0
DEFEXT_S:	db	".CFG",0
PUNTOS_S:	db	"...",13,10,"$"
OPENING_S:	db	"Opening file $"
PROCESS_S:	db	"Processing file...",13,10,"$"
CONFOK_S:	db	"Configuration OK",13,10,"$"
INLINE_S:	db	"In line "
INLINE_S_NUM:	db	"00000$"
BYTE_S:	db	"Byte: "
BYTE_S_NUM:	db	"00000$"
WORD_S:	db	13,10,"Word: "
WORD_S_NUM:	db	"00000$"
WBE_S:	db	13,10,"Word, big endian: "
WBE_S_NUM:	db	"00000$"
COMA_S:	db	", #$"
OFFSET_S:	db	"Offset: $"

	;--- Variables

INS_SLOT:	db	0
INS_SEG2:	db	0
INS_SEG3:	db	0
CUR_SEG:	dw	0
PARSIZE:	db	0
RESETCTES:	db	0
CURLINE:	dw	0
CTE_TABLE_DIR:	dw	0
CTE_LINE_DIR:	dw	0
PEEKTYPE:	db	0
CTE_VAR_DIR:	dw	0

CTES_DIR:	dw	0	;Datos del segmento conectado
CDEF_DIR:	dw	0
CTES_LEN:	dw	0
VARS_DIR:	dw	0

CTES_DIR2:	dw	0	;Datos de NestorPPP
CDEF_DIR2:	dw	0
CTES_LEN2:	dw	0
VARS_DIR2:	dw	0
BUFERS_DIR:	dw	0
MSGS_DIR:	dw	0

CTES_DIR3:	dw	0	;Datos de NestorIP
CDEF_DIR3:	dw	0
CTES_LEN3:	dw	0
VARS_DIR3:	dw	0

	;--- Buferes

BUFPAR:	;
BUFPAR2:	equ	BUFPAR+256
BUFLINE:	equ	BUFPAR
CTES_PPP:	equ	BUFLINE+256
CTES_IP:	equ	CTES_PPP+128
BUFFILE:	equ	#2800
MAXFILESIZE:	equ	#8000-BUFFILE
