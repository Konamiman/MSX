; InterNestor Lite for ObsoNET
; (superseded by InterNestor Lite for UNAPI)

; This is the transient part (installer + configurator).
; Assemble the transient and the resident part,
; then concatenate both binaries and name the file INL.COM

;=========================================================

	;--- Instalador y control de InterNestor Lite para ObsoNET 1.02
	;    Empezado el 23/8/2004
	;    >>> Comprobar dirs de variables y de TCBs!!!

	;Uso:
	;inl i [/s:<segmento>] [<comandos>]  -  instalar
	;* Al instalarse, si existe INL.CFG, lo aplica
	;  como si se ejecutara "inl f"
	;inl u [<comandos>]  -  desinstalar
	;inl p  -  pausar
	;inl r  -  reanudar
	;inl s  -  status conexion de red y direcciones IP
	;inl v  -  muestra variables de configuracion
	;inl d  -  establecer parametros por defecto
	;inl o <num>  -  configurar optimizaciones de checksum
	;inl f [<filename>]  -  configurar varios parametros desde un fichero de texto

	;inl ip i  -  inicializa IPs a 0.0.0.0
	;inl ip l x.x.x.x  -  establece IP local
	;inl ip m x.x.x.x  -  establece mascara de red
	;inl ip g x.x.x.x  -  establece gateway por defecto
	;inl ip p x.x.x.x  -  establece IP DNS 1
	;inl ip s x.x.x.x  -  establece IP DNS 2
	;inl ip e 0|1  -  responder PINGs si/no
	;inl ip t val  -  establece TTL
	;inl ip o val  -  establece TOS
	;inl ip z val  -  tamanyo PINGs
	;inl ip d val  -  vector DHCP

	;inl tcp s [<conexion>]  -  informacion de estado TCP
	;inl tcp c <conexion>  -  cierra conexion TCP
	;inl tcp a <conexion>  -  aborta conexion TCP

	;inl dns r <hostname> [<ip dns>]  -  resolucion DNS

	;inl eth h  -  muestra direccion hardware
	;inl eth f 0|1  -  enviar tramas Ethernet 2 o IEEE802.3
	;inl eth c 0|1  -  comprobar red cada 10 segs o no
	;inl eth r  -  resetear la ObsoNET

	;inl arp t <timeout>h|m  -  establece timeout ARP        
	;inl arp s  -  muestra la cache ARP
	;inl arp c  -  limpia la cache ARP
	;inl arp a <IP> <hardware>  -  anyade entrada ARP
	;inl arp d <IP>  -  borra entrada ARP

	;inl rou s  -  muestra la tabla de rutas
	;inl rou c  -  limpia la tabla de rutas
	;inl rou a <red> <mascara> <router> -  anyade entrada en la tabla de rutas
	;inl rou d <red> <mascara> -  borra entrada de la tabla de rutas


	;* Uso de pag. 3 (zona cassette):
	;#F400 = "IN"
	;#F402 = Seg 1
	;#F403 = Seg 2
	;#F404 = Dir bufer en p. 3


;*****************************
;***                       ***
;***  MACROS Y CONSTANTES  ***
;***                       ***
;*****************************

FLASH:	equ	1	;0 si se usa ObsoNET sin FLASH

	.label	20

USETIMI:	equ	1
MAXFILES:	equ	1

ENYEMAY:	equ	165
ENYEMIN:	equ	164

;P3_ID:	equ	#F400
;P3_SEG1:	equ	#F402
;P3_SEG2:	equ	#F403
;P3_P3DIR:	equ	#F404

RES_SEG1:	equ	#7FF0
RES_SEG2:	equ	#7FF1

;--- Funciones del DOS

;* DOS 1

_TERM0:	equ	#00
_CONOUT:	equ	#02
_DIRIO:	equ	#06
_STROUT:	equ	#09
_FOPEN:	equ	#0F
_FCLOSE:	equ	#10
_SETDTA:	equ	#1A
_WRBLK:	equ	#26
_RDBLK:	equ	#27
_GDATE:	equ	#2A
_GTIME:	equ	#2C


;* DOS 2

_OPEN:	equ	#43
_CLOSE:	equ	#45
_READ:	equ	#48
_WRITE:	equ	#49
_PARSE:	equ	#5B
_DEFAB:	equ	#63
_EXPLAIN:	equ	#66
_TERM:	equ	#62
_GENV:	equ	#6B
_DOSVER:	equ	#6F

;--- Variables del sistema, ganchos y rutinas BIOS

ENDTPA:	equ	#0006
ENASLT:	equ	#0024
RDSLT:	equ	#000C	;A=PEEK(Slot A, Dir HL)
CALSLT:	equ	#001C	;CALL Slot IYh, Dir IX
GETCPU:	equ	#0183	;A=0 si modo Z80

HIMSAV:	equ	#F349
SYSTIMER:	equ	#FC9E
EXPTBL:	equ	#FCC1
H_TIMI:	equ	#FD9F
EXTBIO:	equ	#FFCA

RTL_RESET:	equ	#7FCD	;Inicializacion de ObsoNET
GET_HWAD:	equ	#7FC7

;--- Macros

print:	macro	@s
	ld	de,@s
	ld	c,_STROUT
	call	5
	endm

dummy:	macro
	endm

;--- Constantes del segmento de datos

BUFPAR:	equ	#C000
PARBUF:	equ	#C000
;PARBUF2:      equ     PARBUF+128

ARP_ENTRIES:	equ	32
ROUTE_ENTRIES:	equ	16
ARP_CACHE:	equ	#A000-16*ARP_ENTRIES
ROUTE_TABLE:	equ	ARP_CACHE-16*ROUTE_ENTRIES

BUF_IPLOCAL:	equ	#8000	;IP local (4 bytes)
BUF_IPDNS1:	equ	#8004	;IP DNS 1 (4 bytes)
BUF_IPDNS2:	equ	#8008	;IP DNS 2 (4 bytes)
REPLYECHO:	equ	#800C	;Responder PINGs si/no
TTL:	equ	#800D	;TTL para datagramas salientes
TOS:	equ	#800E
CHKVECT:	equ	#800F	;Vector de optimizaciones checksum
			;       (&B 0 0 0 ICMP UDP TCP IP PPP)
PING_SIZE:	equ	#8010

OBSLOT:	equ	#8012
HWAD:	equ	#8013
SUBNET_MASK:	equ	#8019
DEFGW:	equ	#801D
ARP_TOUT:	equ	#8021
ARP_TOUT_SECS:	equ	#8025
FRAME_TYPE:	equ	#8029
CHECK_NET:	equ	#802A
DHCP_VECT:	equ	#802B
DHCP_VECT_O:	equ	#802D
DHCP_STATE:	equ	#802F
NETSTAT_TIMER:	equ	#8031

DHCP_XID:	equ	#8033

TCBS:	equ	#83BC

;--- Funciones del segmento de codigo

VERS_PAUSE:	equ	#402A
GET_VAR:	equ	#402D
SET_VAR:	equ	#4030
COPY_DATA:	equ	#4033
IP_STRING:	equ	#4036

DNS_Q:	equ	#405D
DNS_R:	equ	#4060
TCP_CLOSE:	equ	#4066
TCP_ABORT:	equ	#4069
TCP_STATUS:	equ	#4072
WAIT_INT:	equ	#4081
NETWORK_STATE:	equ	#4084

ONET_INFO:	equ	#4087
ETH2ASCII:	equ	#408A
ASCII2ETH:	equ	#408D


;************************
;***                  ***
;***  INICIALIZACION  ***
;***                  ***
;************************

	org	#100

	dummy
	dummy
	dummy
	dummy
	dummy
	dummy
	dummy
	dummy
	dummy
	dummy
	dummy
	dummy
	dummy
	dummy
	dummy
	dummy

	if	FLASH=0
	dummy
	endif

;--- Impresion del mensaje inicial

	print	INIT_S

;--- Obtencion de la tabla de rutinas de soporte del mapeador de memoria
;    en caso de usar DOS 2

	;ld	c,_DOSVER	;DOS 2?
	;call	5
	;or	a
	;jr	nz,NODOS2
	;ld	a,b
	;cp	2
	;jr	c,NODOS2

	ld	de,#0402
	xor	a
	call	EXTBIO
	or	a
	jr	z,NODOS2
	ld	a,#FF
	ld	(DOS2),a
	ld	de,_ALL_SEG
	ld	bc,#30
	ldir
	ld	de,AB_HANDLER
	ld	c,_DEFAB
	call	5
NODOS2:	;

	ld	a,(#F344)
	ld	b,a
	ld	a,(#F342)
	cp	b
	jr	nz,NOCHANGE
	ld	a,#C3
	ld	(DOS),a	;Cambia CALL por JP
NOCHANGE:	;


;--- Extraccion del primer parametro,
;    si no hay ninguno, muestra info y termina

	ld	a,1
	ld	de,BUFPAR
	call	EXTPAR
	jr	nc,OKPAR1

	print	INFO_S
	jp	FIN
OKPAR1:	;

;--- Comprobamos si INL ya esta instalado

	;ld	hl,(P3_ID)
	;ld	de,"NI"
	;call	COMP
	;jr	z,YESINST

	xor	a
	ld	de,#2203
	call	EXTBIO
	or	a
	jr	nz,YESINST

	;--- No esta instalado: si el parametro no es "I", error

NOTINST:
	ld	a,(BUFPAR)
	or	#20
	ld	h,a
	ld	a,(BUFPAR+1)
	ld	l,a
	ld	de,#6900	;"i" seguido de 0
	call	COMP
	jr	z,OKPAR2

	print	NOTINS_S
	jp	FIN

	;--- Esta instalado: si el parametro es "I", error

YESINST:
	ld	a,b	;Guarda info de segs y dir. P. 3
	ld	(SEG1),a
	ld	a,c
	ld	(SEG2),a
	ld	(P3DIR),hl

	ld	a,(BUFPAR)
	or	#20
	cp	"i"
	jr	nz,OKPAR2
	ld	a,(BUFPAR+1)
	or	a
	jr	nz,OKPAR2

	print	YESINS_S
	jp	FIN
OKPAR2:	;

	;--- Segun el primer parametro (y quiza el segundo),
	;    saltamos a la parte adecuada del programa

PROC_PARAMS:
	ld	a,(BUFPAR+1)
	or	a
	jr	z,SIMPLEPAR
	ld	a,(BUFPAR)
	or	#20
	cp	"t"
	jp	z,TCPPAR
	cp	"d"
	jp	z,DNSPAR
	cp	"g"
	jp	z,GETPAR
	cp	"s"
	jp	z,SETPAR
	cp	"i"
	jp	z,IPPAR
	cp	"e"
	jp	z,ETHPAR
	cp	"a"
	jp	z,ARPPAR
	cp	"r"
	jp	z,ROUPAR

UNKPAR:	print	UNKPAR_S
	jp	FIN

	;--- Parametro simple

SIMPLEPAR:
	ld	a,(BUFPAR)
	or	#20
	cp	"i"
	jp	z,PAR_SIM_I
	cp	"u"
	jp	z,PAR_SIM_U
	cp	"p"
	jp	z,PAR_SIM_P
	cp	"r"
	jp	z,PAR_SIM_R
	cp	"s"
	jp	z,PAR_SIM_S
	cp	"d"
	jp	z,PAR_SIM_D
	cp	"o"
	jp	z,PAR_SIM_O
	cp	"v"
	jp	z,PAR_SIM_V
	cp	"f"
	jp	z,PAR_SIM_F
	jr	UNKPAR

	;--- Parametro TCP

TCPPAR:	ld	a,(IS_FILE)
	or	a
	jp	nz,NOFILE

	ld	a,2
	ld	de,BUFPAR
	call	EXTPAR
	jp	c,MISSPAR

	ld	a,(BUFPAR)
	or	#20
	cp	"s"
	jp	z,PAR_TCP_S
	cp	"c"
	jp	z,PAR_TCP_C
	cp	"a"
	jp	z,PAR_TCP_A
	jp	UNKPAR

	;--- Parametro DNS

DNSPAR:	ld	a,(IS_FILE)
	or	a
	jp	nz,NOFILE

	ld	a,2
	ld	de,BUFPAR
	call	EXTPAR
	jp	c,MISSPAR

	ld	a,(BUFPAR)
	or	#20
	cp	"r"
	jp	z,PAR_DNS_R
	jp	UNKPAR

	;--- Parametro IP
IPPAR:
	ld	a,2
	ld	de,BUFPAR
	call	EXTPAR
	jp	c,MISSPAR

	ld	a,(BUFPAR)
	or	#20
	cp	"i"
	jp	z,PAR_IP_I
	cp	"l"
	jp	z,PAR_IP_L
	cp	"p"
	jp	z,PAR_IP_P
	cp	"s"
	jp	z,PAR_IP_S
	cp	"n"
	jp	z,PAR_IP_N
	cp	"e"
	jp	z,PAR_IP_E
	cp	"t"
	jp	z,PAR_IP_T
	cp	"o"
	jp	z,PAR_IP_O
	cp	"z"
	jp	z,PAR_IP_Z
	cp	"g"
	jp	z,PAR_IP_G
	cp	"m"
	jp	z,PAR_IP_M
	cp	"d"
	jp	z,PAR_IP_D
	jp	UNKPAR

	;--- Parametro Ethernet
ETHPAR:
	ld	a,2
	ld	de,BUFPAR
	call	EXTPAR
	jp	c,MISSPAR

	ld	a,(BUFPAR)
	or	#20
	cp	"h"
	jp	z,PAR_ETH_H
	cp	"f"
	jp	z,PAR_ETH_F
	cp	"c"
	jp	z,PAR_ETH_C
	cp	"r"
	jp	z,PAR_ETH_R
	jp	UNKPAR

	;--- Parametro ARP
ARPPAR:
	ld	a,2
	ld	de,BUFPAR
	call	EXTPAR
	jp	c,MISSPAR

	ld	a,(BUFPAR)
	or	#20
	cp	"t"
	jp	z,PAR_ARP_T
	cp	"s"
	jp	z,PAR_ARP_S
	cp	"c"
	jp	z,PAR_ARP_C
	cp	"a"
	jp	z,PAR_ARP_A
	cp	"d"
	jp	z,PAR_ARP_D
	jp	UNKPAR

	;--- Parametro de la tabla de enrutamiento
ROUPAR:
	ld	a,2
	ld	de,BUFPAR
	call	EXTPAR
	jp	c,MISSPAR

	ld	a,(BUFPAR)
	or	#20
	cp	"s"
	jp	z,PAR_ROU_S
	cp	"c"
	jp	z,PAR_ROU_C
	cp	"a"
	jp	z,PAR_ROU_A
	cp	"d"
	jp	z,PAR_ROU_D
	jp	UNKPAR


;--- Parametros no implementados aun

GETPAR:
SETPAR:

	print	NOTIMP_S
	jp	FIN
NOTIMP_S:	db	"*** Not implemented yet.$"

;--- Cadenas de la parte de inicializacion

INIT_S:	db	"InterNestor Lite for ObsoNET 1.02: TCP/IP stack for MSX-DOS",13,10
	if	USETIMI=0 then
	db	"*** NO TIMER!!",13,10
	endif
	db	"By Konami Man, 4/2005",13,10,13,10,"$"

INFO_S:	db	"Frequently used options:",13,10,13,10

	db	"INL I [/s:<seg>] [<command>]",13,10
	db	"Install InterNestor Lite.",13,10,13,10

	db	"INL U [<command>]",13,10
	db	"Uninstall InterNestor Lite.",13,10,13,10

	db	"INL IP D 0|63",13,10
	db	"Turn off/on the usage of DHCP for configuration.",13,10,13,10

	db	"INL IP L|M|G|P|S <IP address>",13,10
	db	"Set up the local IP address/subnet mask/default gateway/",13,10
	db	"primary DNS server/secondary DNS server.",13,10,13,10

	db	"INL S|V",13,10
	db	"Show InterNestor Lite status/configuration variables.",13,10,13,10

	db	"See the INL user's manual for more details.",13,10,"$"

NOTINS_S:	db	"*** InterNestor Lite is not installed",13,10,"$"
YESINS_S:	db	"*** InterNestor Lite is already installed",13,10,"$"
BADTPAT_S:	db	"*** Error: TPA pages are located at more than one slot.",13,10
	db	"    Reboot in DOS 2 mode or remove external mappers and try again.",13,10,"$"
SRCHOBSO_S:	db	"Searching the ObsoNET card... $"
NOOBSO_S:	db	"ERROR!",13,10,13,10,"*** ObsoNET card not found. InterNestor Lite not installed.",13,10,"$"
NOBIOS_S:	db	"*** The card has not a valid BIOS. InterNestor Lite not installed.",13,10,"$"
FOUND_S:	db	"OK, found at slot "
SLOT_S:	db	"0  ",13,10,13,10,"$"



;*********************
;***               ***
;***  INSTALACION  ***
;***               ***
;*********************

PAR_SIM_I:	ld	a,(IS_FILE)
	or	a
	jp	nz,NOFILE

	;--- Comprobamos que hay suficiente TPA (#0006 >= #C200)

	ld	a,(ENDTPA+1)
	cp	#C2
	jr	nc,OKTPA

	print	NOTPA_S
	jp	FIN
OKTPA:	;

	;--- Comprobamos si la TPA es como toca

	ld	a,(#F344)
	ld	b,a
	ld	a,(#F342)
	cp	b
	jr	z,OKTPATYPE

	print	BADTPAT_S
	jp	FIN
OKTPATYPE:	;

	ld	hl,#80	;Guarda linea de comandos (por si se carga INL.CFG)
	ld	de,PARBUF2
	ld	bc,128
	ldir

	;--- Buscamos la ObsoNET

	print	SRCHOBSO_S
	call	SRCHOBSO
	push	af
	pop	bc
	cp	#FF
	jr	nz,SRCHOBSO_1

	;* No encontrada

	print	NOOBSO_S
	jp	FIN

	;* Encontrada, guardamos y mostramos slot

SRCHOBSO_1:	ld	(_OBSLOT),a
	push	bc

	ld	c,a
	and	%11
	add	"0"	;Prepara cadena informativa, slot primario...
	ld	(SLOT_S),a
	bit	7,c
	jr	z,NOEXPSLT

	ld	a,"-"	;...y subslot si es necesario
	ld	(SLOT_S+1),a
	ld	a,c
	rrca
	rrca
	and	%11
	add	"0"
	ld	(SLOT_S+2),a
NOEXPSLT:

	print	FOUND_S

	;* Comprobamos si tiene BIOS

	pop	bc

	if	FLASH=1

	bit	0,c
	jr	nz,BIOS_OK

	print	NOBIOS_S
	jp	FIN
BIOS_OK:

	;--- Inicializamos la ObsoNET

	ld	a,(_OBSLOT)
	ld	h,#40
	call	ENASLT

	call	RTL_RESET
	call	GET_HWAD	;Obtiene MAC
	ld	(_HWAD),hl
	ld	(_HWAD+2),de
	ld	(_HWAD+4),bc

	endif

	ld	a,(#F342)	;Restauramos RAM en pag. 1
	ld	h,#40
	call	ENASLT


	;================================
	;===  Seleccion de segmentos  ===
	;================================

	;--- Comprueba si se ha especificado opcion /s

	ld	a,2
	ld	de,BUFPAR
	call	EXTPAR
	jr	c,AUTOSEG
	ld	a,(BUFPAR)
	cp	"/"
	jr	nz,AUTOSEG

	ld	a,(BUFPAR+1)
	or	#20
	cp	"s"
	jr	nz,BADSEG
	ld	a,(BUFPAR+2)
	cp	":"
	jr	nz,BADSEG
	ld	a,(BUFPAR+3)
	or	a
	jr	nz,MANSEG

BADSEG:	print	INVPAR_S
	jp	FIN

	;--- Seleccion manual: extrae el numero de segmento

MANSEG:	ld	a,3
	ld	(NEXTPAR),a
	ld	hl,BUFPAR+3
	call	EXTNUM8
	jr	c,BADSEG
	ld	(SEG1),a
	inc	a
	ld	(SEG2),a
	jr	OKSELSEG

	;--- Seleccion automatica: DOS 1 o DOS 2?

AUTOSEG:	ld	a,2
	ld	(NEXTPAR),a
	ld	a,(DOS2)
	or	a
	jr	nz,RESEGDOS2

	;--- DOS 1: Comprobamos cuanta memoria hay,
	;    si no hay al menos 128K terminamos con error,
	;    en caso contrario seleccionamos el ultimo
	;    segmento y el penultimo

RESEGDOS1:	ld	de,#B000
	call	MEMTEST1

	cp	2	;No hay RAM mapeada?
	jr	nc,OKTEST1_1
	print	NOMAP_S
	jp	FIN

OKTEST1_1:	cp	6	;No hay al menos 96K?
	jr	nc,OKTEST1_2
	print	MAP64_S
	jp	FIN

OKTEST1_2:	dec	a
	ld	(SEG2),a
	dec	a
	ld	(SEG1),a
	jr	OKSELSEG

	;--- DOS 2: Comprobamos si hay al menos dos segmentos
	;    libres en el mapeador primario, si los hay los reservamos,
	;    si no mostramos error

RESEGDOS2:	ld	de,#0401
	call	EXTBIO
	inc	hl
	inc	hl
	ld	a,(hl)	;Cuantos segmentos libres?
	cp	2	;Menos de 2: error
	jr	nc,FRESEGS_OK

	print	NOFREE_S
	jp	FIN

FRESEGS_OK:
	ld	b,0	;Reserva 2 segmentos en modo sistema
	ld	a,1
	call	_ALL_SEG
	ld	(SEG1),a
	ld	b,0
	ld	a,1
	call	_ALL_SEG
	ld	(SEG2),a
OKSELSEG:

	;===========================================================
	;===  Copia e inicializacion del codigo y las variables  ===
	;===========================================================

	;--- Copia el codigo a pagina 2 temporalmente,
	;    conecta el segmento de codigo en pagina 1,
	;    y copia el codigo a su segmento

	ld	hl,INL_CODE
	ld	de,#8000
	ld	bc,16384
	ldir

	ld	hl,(SEG1)
	ld	(RES_SEG1+#4000),hl

	ld	a,(SEG1)
	call	_PUT_P1

	ld	hl,#8000
	ld	de,#4000
	ld	bc,16384
	ldir

	ld	a,#FF
	ld	(IS_FILE_INS),a

	;--- Establecimiento de la zona de cassette

	;ld	hl,"NI"
	;ld	(P3_ID),hl
	;ld	a,(SEG1)
	;ld	(P3_SEG1),a
	;ld	a,(SEG2)
	;ld	(P3_SEG2),a

	;--- PRUEBAS: Inicializa ObsoNET

RESET_INL:

	if	FLASH=0

	ld	a,(_OBSLOT)
	ld	h,#80
	call	ENASLT

	call	#401E	;INIT_RTL
	call	#4021
	ld	(_HWAD),hl
	ld	(_HWAD+2),de
	ld	(_HWAD+4),bc

	ld	a,(#F343)
	ld	h,#80
	call	ENASLT

	endif

	if	FLASH=1

	ld	a,(_OBSLOT)
	ld	h,#40
	call	ENASLT

	call	RTL_RESET
	call	GET_HWAD	;Obtiene MAC
	ld	(_HWAD),hl
	ld	(_HWAD+2),de
	ld	(_HWAD+4),bc

	ld	a,(#F342)
	ld	h,#40
	call	ENASLT

	endif

	;--- Conecta el seg. de datos en pag. 2 y lo inicializa

	ld	a,(SEG2)
	call	_PUT_P2

	call	INIT_VARS
	ld	a,(_OBSLOT)
	ld	(OBSLOT),a

	ld	hl,_HWAD
	ld	de,HWAD
	ld	bc,6
	ldir

	;--- Obtencion de las variables de entorno de inicializacion

	ld	a,(DOS2)
	or	a
	jp	z,ENV_OK

	;* IPs

	ld	hl,ENV_IP
	ld	de,BUF_IPLOCAL
	call	DO_ENV_IP

	ld	hl,ENV_MASK
	ld	de,SUBNET_MASK
	call	DO_ENV_IP

	ld	hl,ENV_GW
	ld	de,DEFGW
	call	DO_ENV_IP

	ld	hl,ENV_DNS1
	ld	de,BUF_IPDNS1
	call	DO_ENV_IP

	ld	hl,ENV_DNS2
	ld	de,BUF_IPDNS2
	call	DO_ENV_IP

	;* Vector DHCP

	ld	hl,ENV_DHCP
	ld	de,PARBUF
	ld	b,6
	ld	c,_GENV
	call	DOS

	ld	a,(PARBUF)
	or	a
	jr	z,ENV_OK
	ld	hl,PARBUF
	call	EXTNUM8
	jr	c,ENV_OK

	ld	(DHCP_VECT),a
	jr	ENV_OK

	;* Subrutina que extrae la IP de la variable apuntada por HL,
	;  y la guarda en DE

DO_ENV_IP:	push	de
	ld	b,16
	ld	de,PARBUF+3
	ld	c,_GENV
	call	DOS
	pop	de
	ld	a,(PARBUF)
	or	a
	ret	z
	push	de

	call	PARSE_IP
	pop	de
	ret	c
	ld	hl,PARSED_IP
	ld	bc,4
	ldir

	ret

	;* Variables que se examinaran

ENV_IP:	db	"INL_IP",0
ENV_MASK:	db	"INL_MASK",0
ENV_GW:	db	"INL_GW",0
ENV_DNS1:	db	"INL_DNS_P",0
ENV_DNS2:	db	"INL_DNS_S",0
ENV_DHCP:	db	"INL_DHCP",0

ENV_OK:

	;--- Lectura de INL.CFG, si existe

	xor	a
	ld	(FCBS),a	;Necesario en DOS 1

	;* Nombre del fichero: en DOS 1 usa INL.CFG tal cual,
	;  en DOS 2 usa INL.CFG en el directorio de INL.COM

	ld	de,BUFPAR
	ld	a,(DOS2)
	or	a
	jr	z,READINI_OK1

	ld	hl,PROGRAM_S	;DOS 2: Obtiene variable PROGRAM...
	;ld	de,BUFPAR
	ld	b,128
	ld	c,_GENV
	call	DOS

	ld	de,BUFPAR	;...y de ahi obtiene el puntero
	ld	bc,_PARSE	;al nombre del fichero
	call	DOS
	ex	de,hl

READINI_OK1:	ld	hl,INLCFG_S
	ld	bc,8
	ldir

	;* Intenta abrir el fichero

	ld	de,BUFPAR
	call	OPEN
	or	a
	jr	nz,READINI_END
	ld	a,b
	ld	(FH),a

	;* Establece IS_FILE y salta a FIN, lo cual causara
	;  que se procese el primer parametro

	ld	a,#FF
	ld	(IS_FILE),a
	jp	FIN

	;* Al terminar, saltara aqui

READINI_END:	ld	a,(IS_FILE_INS)	;Por si era INL D
	or	a
	jr	nz,READINI_END2

	xor	a
	ld	(IS_FILE),a
	jp	FIN

READINI_END2:	ld	a,1	;Restaura TPA en pag. 2
	call	_PUT_P2


	;====================================================================
	;===  Reserva de espacio en pag. 3 y copia de la rutina de salto  ===
	;====================================================================

	;--- Modificacion de la zona de trabajo del cassette
	;    y establecimiento del nuevo HIMSAV

	;ld	hl,"NI"
	;ld	(P3_ID),hl
	;ld	a,(SEG1)
	;ld	(P3_SEG1),a
	;ld	a,(SEG2)
	;ld	(P3_SEG2),a

	ld	hl,(HIMSAV)
	push	hl
	ld	bc,P3_END0022-P3_START0022
	or	a
	sbc	hl,bc
	ld	(HIMSAV),hl
	ld	(P3DIR),hl

	;--- Preparacion de la parte en pag. 3

	pop	hl
	ld	(OLDHIM0022),hl
	ld	(OLDHIM0023),hl

	ld		a,(DOS2)
	or	a
	jr	z,NODOS2P3
	ld	hl,_PUT_P1	;Copiamos entrada a GET_P1
	ld	de,PUT_P10022
	ld	bc,4*3
	push	hl,bc
	ldir
	pop	bc,hl
	ld	de,PUT_P10023
	ldir
NODOS2P3:	;

	;Modifica codigo segun slot principal

	ld	a,(#F344)
	and	%11	;A = %xxxxxxSS

	ld	b,a
	add	#C5
	ld	(FCCX10022+1),a
	ld	(FCCX10023+1),a
	ld	(FCCX20022+1),a
	ld	(FCCX20023+1),a
	ld	a,b

	sla	a
	sla	a	;A = %xxxxSSxx
	ld	b,a
	sla	a
	sla	a	;A = %xxSSxxxx
	or	b	;A = %xxSSSSxx
	ld	(ORMASK10022+1),a
	ld	(ORMASK10023+1),a

	;Modifica codigo segun subslot

	ld	a,(#F344)
	and	%1100	;A = %xxxxBBxx
	ld	b,a
	sla	a
	sla	a	;A = %xxBBxxxx
	or	b	;A = %xxBBBBxx
	ld	(ORMASK20022+1),a
	ld	(ORMASK20023+1),a

	;Modifica codigo segun SEG1, SEG2, P3DIR

	ld	a,(SEG1)
	ld	(P3_SEG10022+1),a
	ld	(P3_SEG10023+1),a
	ld	a,(SEG2)
	ld	(P3_SEG20022+1),a
	ld	(P3_SEG20023+1),a
	ld	hl,(P3DIR)
	ld	(P3_P3DIR0022+1),hl
	ld	(P3_P3DIR0023+1),hl

	;Guardamos antiguo H_TIMI

	ld	hl,H_TIMI
	ld	de,OLDTIME0022
	ld	bc,5
	push	hl,bc
	ldir
	pop	bc,hl
	ld	de,OLDTIME0023
	ldir

	;Guardamos antiguo EXTBIO

	ld	hl,EXTBIO
	ld	de,OLDEXT0022
	ld	bc,5
	push	hl,bc
	ldir
	pop	bc,hl
	ld	de,OLDEXT0023
	ldir

	;--- Copia de la parte residente en pag. 3:
	;    primero la copia temporalmente a #B000

	ld	ix,(P3DIR)
	ld	iy,#B000
	ld	hl,RESCODE1
	ld	de,RESCODE2
	ld	bc,P3_END0022-P3_START0022
	call	REUBICA

	;--- Copia las entradas de pag. 3 para manejo de slots y segs,
	;    asi como las entradas Fossil de rs_in a rs_out_stat

	ld	hl,#B000	;Copia entradas pag. 3
	ld	bc,12
	add	hl,bc
	ld	de,#4003
	ld	bc,7*3
	ldir

	ld	a,2	;Restaura TPA en pag. 1
	call	_PUT_P1

	;--- Copiamos la ultima parte a #8000 y saltamos al BASIC.
	;    El salto al BASIC ejecutara un USR hacia la rutina
	;    final, que copiara la parte residente a su posicion
	;    definitiva en pagina 3 y establecera el gancho H_TIMI.

	;ld      hl,LAST_INST
	;ld      de,#8000
	;ld      bc,#1000
	;ldir

	print	HAVEFUN_S

	;jp      #8000


	;--- Fin de la instalacion, salto al BASIC y _SYSTEM

	ld	hl,PARBUF2
	ld	de,#80	;Recupera linea de comandos
	ld	bc,128	;(por si se ha autocargado INL.CFG)
	ldir

	xor	a
	ld	(BUFPAR),a
	ld	a,(NEXTPAR)
	ld	de,BUFPAR
	call	EXTPAR
	ld	hl,BUFPAR
	or	a
	jp	CALSYS


	;=====================================
	;===  Parte residente en pagina 3  ===
	;=====================================

	;Para pausar INL:
	;BASE = WPEEK(P3DIR)
	;POKE BASE a BASE+2,0

	;Para restaurar INL:
	;POKE BASE,#C3
	;WPOKE BASE+1,WPEEK(BASE+8)

PARTP3:	macro

P3_START@sym:	;

	;--- Destino de la int. de reloj

	call	NEXTTIME@sym
OLDTIME@sym:	ds	5
	dw	NEXTTIME@sym	;BASE+8
OLDHIM@sym:	dw	0	;BASE+10, antigua dir. fin TPA

	;--- Tabla de salto que sera copiada al segmento de
	;    codigo de INL en la dir. #4003

	jp	LDIRP3@sym	;BASE+12
PUT_P1@sym:	out	(#FD),a	;ATENCION: esto funciona
	ret		;                ;porque in/out+ret
GET_P1@sym:	in	a,(#FD)	;ocupa exactamente 3 byte
	ret		;                ;(como el JP que se copiara
PUT_P2@sym:	out	(#FE),a	;cuando se use DOS 2)
	ret
GET_P2@sym:	in	a,(#FE)
	ret
	jp	GETSLOT1@sym
	jp	PUTSLOT1@sym
;                 jp      GETSLOT2@sym
;                 jp      PUTSLOT2@sym

	;--- BIOS extendida

OLDEXT@sym:	ds	5	;BASE+33: Antiguo gancho

NEWEXT@sym:	push	af	;BASE+48: Nuevo gancho
	ld	a,d
	cp	34
	jr	nz,ENDEXT@sym
	ld	a,e
	cp	3
	jr	nz,ENDEXT@sym

	pop	af
	ld	a,1
P3_SEG1@sym:	ld	b,0	;Segmento de codigo
P3_SEG2@sym:	ld	c,0	;Segmento de datos
P3_P3DIR@sym:	ld	hl,0	;Dir. pag. 3
	ret

ENDEXT@sym:	pop	af
	jr	OLDEXT@sym

	;--- Nueva rutina de interrupcion

NEXTTIME@sym:	;

	;--- Obtiene slot y segmento en pags. 1 y 2 y los guarda,
	;    de paso conecta slot y seg de INS

	di

	in	a,(#A8)
	ld	b,a
	and	%11000011	;Pag. 1 y 2
ORMASK1@sym:	or	%00111100
	out	(#A8),a

	ld	a,(-1)
	cpl
	ld	c,a
	and	%11000011
ORMASK2@sym:	or	%00000000
	ld	(-1),a
FCCX1@sym:	ld	(#FCC8),a

	push	bc
	call	GET_P1@sym
	ld	d,a
	call	GET_P2@sym
	ld	e,a
	push	de

	ld	a,(P3_SEG1@sym+1)
	call	PUT_P1@sym
	ld	a,(P3_SEG2@sym+1)
	call	PUT_P2@sym
	ei

	;--- Llama a la rutina de interrupcion

	call	#4000

	;--- Restaura slot y segmento en pags. 1 y 2

	di
	pop	de

	ld	a,d
	call	PUT_P1@sym
	ld	a,e
	call	PUT_P2@sym

	pop	bc
	ld	a,c
	ld	(-1),a
FCCX2@sym:	ld	(#FCC8),a

	ld	a,b
	out	(#A8),a

	ei
	ret

;--- Subrutina LDIRP3: Conecta el slot L, segmento H en pagina 1,
;    hace un LDIR de IX a IY longitud BC, y restaura INL en pagina 1

LDIRP3@sym:	push	ix,iy,bc,hl
	di
	call	GET_P1@sym
	ld	(SAVESEG@sym),a
	call	GETSLOT1@sym
	ld	(SAVESLOT@sym),a
	ld	b,a
	pop	hl
	push	hl
	ld	a,l
	ld	(SLOTLDIR@sym),a
	call	PUTSLOT1@sym
	ei
	pop	af
	call	PUT_P1@sym
	pop	bc,de,hl
	ldir
	ld	a,(SLOTLDIR@sym)
	ld	b,a
	ld	a,(SAVESLOT@sym)
	call	PUTSLOT1@sym
	ei
	ld	a,(SAVESEG@sym)
	call	PUT_P1@sym
	ret

SLOTLDIR@sym:	db	0
SAVESLOT@sym:	db	0
SAVESEG@sym:	db	0

;--- Subrutina para la obtencion del slot conectado en pagina 1

GETSLOT1@sym:	di
	exx
	in	a,(#A8)
	ld	e,a
	and	%00001100
	sra	a
	sra	a
	ld	c,a	;C = Slot
	ld	b,0
	ld	hl,EXPTBL
	add	hl,bc
	bit	7,(hl)
	jr	z,NOEXP1@sym
EXP1@sym:	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	and	%00001100
	or	c
	or	#80
	ld	c,a
NOEXP1@sym:	ld	a,c
	exx
	ei
	ret

;--- Subrutina para la conexion del slot A en pag. 1 si es distinto de B

PUTSLOT1@sym:	cp	b
	ret	z
	ld	h,#40
	call	ENASLT
	ei
	ret

;--- Subrutina para la obtencion del slot conectado en pagina 2

;GETSLOT2@sym:	di
;	exx
;	in	a,(#A8)
;	ld	e,a
;	and	%00110000
;	sra	a
;	sra	a
;	sra	a
;	sra	a
;	ld	c,a	;C = Slot
;	ld	b,0
;	ld	hl,EXPTBL
;	add	hl,bc
;	bit	7,(hl)
;	jr	z,NOEXP2@sym
;EXP2@sym:	inc	hl
;	inc	hl
;	inc	hl
;	inc	hl
;	ld	a,(hl)
;	and	%00110000
;	sra	a
;	sra	a
;	or	c
;	or	#80
;	ld	c,a
;NOEXP2@sym:	ld	a,c
;	exx
;	ret

;--- Subrutina para la conexion del slot A en pag. 2 si es distinto de B

;PUTSLOT2@sym:	cp	b
;	ret	z
;	ld	h,#80
;	call	ENASLT
;	ei
;	ret
;NEWSP@sym:        ;

P3_END@sym:	;                        ;Fin de la parte residente en pagina 3

	endm

RESCODE1:	PARTP3
RESCODE2:	PARTP3


;--- Cadenas de la parte de instalacion

NOTPA_S:	db	"*** Too small TPA (end of TPA must be at least #C200).",13,10
	db	"InterNestor Lite not installed.",13,10,"$"
NOMAP_S:	db	"*** No mapped RAM found. InterNestor Lite not installed.",13,10,"$"
MAP64_S:	db	"*** Only 64K mapped RAM found. InterNestor Lite not installed.",13,10,"$"
NOFREE_S:	db	"*** No free segments on primary mapper. InterNestor Lite not installed.",13,10,"$"
HAVEFUN_S:	db	"InterNestor Lite has been installed. Have fun! (^^)/",13,10,"$"


;************************
;***                  ***
;***  DESINSTALACION  ***
;***                  ***
;************************

PAR_SIM_U:	ld	a,(IS_FILE)
	or	a
	jp	nz,NOFILE

	;--- Comprobamos si realmente se puede desinstalar

	if	USETIMI=1

	ld	hl,(P3DIR)
	ld	de,(HIMSAV)
	call	COMP
	jr	z,OKCANUN

	print	CANTUN_S
	jp	FIN
OKCANUN:	;

	endif

	;--- Borra zona cassette

	;xor	a
	;ld	(P3_ID),a
	;ld	(P3_ID+1),a

	;--- Restauramos la interrupcion del reloj original

	if	USETIMI=1 then

	di
	ld	hl,(P3DIR)
	inc	hl
	inc	hl
	inc	hl
	ld	de,H_TIMI
	ld	bc,5
	ldir
	ei

	endif

	;--- Restauramos EXTBIO original

	di
	ld	hl,(P3DIR)
	ld	bc,33
	add	hl,bc
	ld	de,EXTBIO
	ld	bc,5
	ldir
	ei

	;--- Liberamos los segmentos si estamos en DOS 2

	ld	a,(DOS2)
	or	a
	jr	z,NOFRE

	ld	a,(#F344)
	ld	b,a
	ld	a,(SEG1)
	call	_FRE_SEG
	ld	a,(#F344)
	ld	b,a
	ld	a,(SEG2)
	call	_FRE_SEG
NOFRE:	;

	;--- Restauramos la direccion original de HIMSAV

	ld	hl,(P3DIR)
	ld	bc,10
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(HIMSAV),hl

	;--- Mostramos aviso, y saltamos a BASIC+_SYSTEM

	print	OKUNINS_S
	xor	a
	ld	(BUFPAR),a
	ld	a,2
	ld	de,BUFPAR
	call	EXTPAR
	ld	hl,BUFPAR
	scf
	jp	CALSYS

	;--- Cadenas de la parte de desinstalacisn

CANTUN_S:	db	"*** Other resident programs were installed after InterNestor Lite.",13,10
		db	"    Uninstall these programs first, then retry uninstalling InterNestor Lite.",13,10,"$"
OKUNINS_S:	db	"InterNestor Lite has been uninstalled. Please come back later.",13,10,"$"


;************************************
;***  PARAMETROS NO CUALIFICADOS  ***
;************************************

	;====================================
	;===  P: Pausa y R: Reactivacion  ===
	;====================================

PAR_SIM_P:	ld	b,1
	jr	PAR_SIM_PR

PAR_SIM_R:	ld	b,2

PAR_SIM_PR:	ld	a,(IS_FILE)
	or	a
	jp	nz,NOFILE

	ld	a,(SEG1)
	call	_PUT_P1

	ld	a,b
	call	VERS_PAUSE
	push	af
	print	HASBEEN_S
	pop	af
	cp	1
	ld	c,_STROUT
	ld	de,PAUSED_S
	jr	z,PARPR2
	ld	de,ACTIVATED_S
PARPR2:	call	DOS

	ld	a,2
	call	_PUT_P1

	jp	FIN

HASBEEN_S:	db	"InterNestor Lite has been $"
PAUSED_S:	db	"paused",13,10,"$"
ACTIVATED_S:	db	"activated",13,10,"$"


	;===================
	;===  S: Estado  ===
	;===================

PAR_SIM_S:	ld	a,(SEG1)
	call	_PUT_P1
	ld	a,(SEG2)
	call	_PUT_P2

	;--- Activo o pausado

	print	ISINS_S
	xor	a
	call	VERS_PAUSE
	ld	c,_STROUT
	ld	de,ACTIVE_S
	cp	2
	jr	z,PARSIMS_2
	ld		de,PAUSED2_S
PARSIMS_2:	call	DOS

	;--- Estado red

	print	NETSTAT_S
	call	NETWORK_STATE
	ld	c,_STROUT
	ld	de,NETSTAT0_S
	or	a
	jr	z,PARSIMS_3
	ld	de,NETSTAT1_S
	dec	a
	jr	z,PARSIMS_3
	ld	de,NETSTAT2_S
	dec	a
	jr	z,PARSIMS_3
	ld	de,NETSTAT3_S
	dec	a
	jr	z,PARSIMS_3
	ld	de,NETSTATX_S
PARSIMS_3:	call	DOS

	;--- Direcciones IP

	print	IPLOCIS_S
	ld	hl,(BUF_IPLOCAL)
	ld	de,(BUF_IPLOCAL+2)
	ld	a,"$"
	ld	ix,IPBUF
	call	IP_STRING
	print	IPBUF

	print	SUBNET_S
	ld	hl,(SUBNET_MASK)
	ld	de,(SUBNET_MASK+2)
	ld	a,"$"
	ld	ix,IPBUF
	call	IP_STRING
	print	IPBUF

	print	DEFGW_S
	ld	hl,(DEFGW)
	ld	de,(DEFGW+2)
	ld	a,"$"
	ld	ix,IPBUF
	call	IP_STRING
	print	IPBUF

	print	IPDNS1IS_S
	ld	hl,(BUF_IPDNS1)
	ld	de,(BUF_IPDNS1+2)
	ld	a,"$"
	ld	ix,IPBUF
	call	IP_STRING
	print	IPBUF

	print	IPDNS2IS_S
	ld	hl,(BUF_IPDNS2)
	ld	de,(BUF_IPDNS2+2)
	ld	a,"$"
	ld	ix,IPBUF
	call	IP_STRING
	print	IPBUF

	;--- Estado automata DHCP

	ld	a,(DHCP_VECT)
	or	a
	jp	z,FIN

	print	DHCPSTAT_S
	ld	a,(DHCP_STATE)
	inc	a
	ld	b,a
	ld	de,DHCPSTATES_T
	call	GET_STRING
	ld	c,_STROUT
	call	DOS
	print	NEWLINE_S

	;--- Fin

	jp	FIN

	;--- Cadenas

ISINS_S:	db	"InterNestor Lite is installed and $"
ACTIVE_S:	db	"ACTIVE",13,10,13,10,"$"
PAUSED2_S:	db	"PAUSED",13,10,13,10,"$"

NETSTAT_S:	db	"Network state is: $"
NETSTAT0_S:	db	"OFF",13,10,13,10,"$"
NETSTAT1_S:	db	"Initializing",13,10,13,10,"$"
NETSTAT2_S:	db	"ON",13,10,13,10,"$"
NETSTAT3_S:	db	"Closing",13,10,13,10,"$"
NETSTATX_S:	db	"Unknown!"
TWONL_S:	db	13,10
NEWLINE_S:	db	13,10,"$"

IPLOCIS_S:	db	"Local IP address: $"
SUBNET_S:	db	13,10,"Subnet mask: $"
DEFGW_S:	db	13,10,"Default gateway: $"
IPDNS1IS_S:	db	13,10,"Primary DNS address: $"
IPDNS2IS_S:	db	13,10,"Secondary DNS address: $"
DHCPSTAT_S:	db	13,10,10,"DHCP automaton state: $"

DHCPSTATES_T:	db	1,"INIT$"
	db	2,"SELECTING$"
	db	3,"REQUESTING$"
	db	4,"BOUND (network ready)$"
	db	5,"RENEWING$"
	db	6,"REBINDING$"
	db	7,"INFORMING$"
	db	8,"CONFIGURED (network ready)$"
	db	0

IPBUF:	ds	16


	;======================
	;===  V: Variables  ===
	;======================

PAR_SIM_V:	ld	a,(SEG2)
	call	_PUT_P2

	;--- Otros parametros

	ld	hl,VARS_TABLE

SIMV_LOOP:	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	a,d
	or	e
	jp	z,SIMV_OK1

	push	hl
	ld	c,_STROUT
	call	DOS
	pop	hl

	ld	a,(hl)	;A=Tipo de valor
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)	;DE=Dir del valor
	inc	hl

	dec	a	;Tipo 1: byte
	jr	z,SIMV_1B
	dec	a	;Tipo 2: word
	jr	z,SIMV_2B
	dec	a	;Tipo 3: ON/OFF
	jr	z,SIMV_ONOFF

	;--- Es una cadena (tipo 4)

	ld	a,(de)
	or	a
	jr	nz,NOEMPS
	ld	de,EMPTY_S
NOEMPS:	push	hl
	call	PRINTZ
	print	NEWLINE_S
	pop	hl
	jr	SIMV_LOOP

	;--- Es ON_OFF

SIMV_ONOFF:	ld	a,(de)
	or	a
	ld	de,ON_S
	jr		nz,SIMV2
	ld	de,OFF_S
SIMV2:	push	hl
	ld	c,_STROUT
	call	DOS
	pop	hl
	jr	SIMV_LOOP

	;--- Es 1 byte

SIMV_1B:	ld	a,(de)
	ld	e,a
	ld	d,0
	jr	SIMV_12B

	;--- Es 2 bytes

SIMV_2B:	ld	a,(de)
	ld	c,a
	inc	de
	ld	a,(de)
	ld	e,c
	ld	d,a

SIMV_12B:	push	hl
	ld	hl,PARBUF
	ld	b,1
	ld	a,%1000
	call	NUMTOASC
	print	PARBUF
	print	NEWLINE_S
	pop	hl
	jr	SIMV_LOOP

	;--- Timeout ARP

SIMV_OK1:	print	VARARPT_S
	ld	de,(ARP_TOUT_SECS)
	ld	a,d
	or	e
	jr	z,SIMV_OK2

	print	MORE18_S
	jp	FIN
SIMV_OK2:

	ld	a,(ARP_TOUT_SECS+2)
	ld	d,a
	ld	a,(ARP_TOUT_SECS+3)
	ld	e,a
	ld	hl,PARBUF
	ld	b,1
	ld	a,%1000
	call	NUMTOASC
	print	PARBUF
	print	SECONDS_S

	jp	FIN

	;--- Tabla de variables

VARS_TABLE:
	dw	VARPINGECHO_S
	db	3
	dw	REPLYECHO

	dw	VARTTL_S
	db	1
	dw	TTL

	dw	VARTOS_S
	db	1
	dw	TOS

	dw	VARCHK_S
	db	1
	dw	CHKVECT

	dw	VARPSIZE_S
	db	2
	dw	PING_SIZE

	dw	VARFTYPE_S
	db	3
	dw	FRAME_TYPE

	dw	VARCNET_S
	db	3
	dw	CHECK_NET

	dw	VARDHCP_S
	db	2
	dw	DHCP_VECT

	dw	VARDHCPO_S
	db	2
	dw	DHCP_VECT_O

	dw	0

	;--- Cadenas

EMPTY_S:	db	"(empty)",0
ON_S:	db	"ON",13,10,"$"
OFF_S:	db	"OFF",13,10,"$"
VARPINGECHO_S:	db	"Reply incoming PINGs (ICMP echo requests): $"
VARTTL_S:	db	"TTL for outgoing datagrams: $"
VARTOS_S:	db	"TOS for outgoing datagrams: $"
VARCHK_S:	db	"Checksum calculations vector: $"
VARPSIZE_S:	db	"Size of outgoing PINGs in bytes (data part): $"
VARFTYPE_S:	db	"Send frames with IEEE802.3 encapsulation: $"
VARCNET_S:	db	"Check network state every 10 seconds: $"
VARDHCP_S:	db	"Requested DHCP parameters vector: $"
VARDHCPO_S:	db	"Obtained DHCP parameters vector: $"

VARARPT_S:	db	"ARP cache timeout: $"
MORE18_S:	db	"more than 18 hours",13,10,"$"
SECONDS_S:	db	" seconds",13,10,"$"


	;==================
	;===  D: Reset  ===
	;==================

PAR_SIM_D:	ld	a,(SEG2)
	call	_PUT_P2
	ld	a,(SEG1)
	call	_PUT_P1

	ld	a,(OBSLOT)
	ld	(_OBSLOT),a

	print	RESOK_S

	jp	RESET_INL	;FIN

RESOK_S:	db	"InterNestor Lite has been reset.",13,10,13,10,"$"


	;===========================
	;===  O: Optimizaciones  ===
	;===========================

PAR_SIM_O:	ld	a,(SEG2)
	call	_PUT_P2

	ld	a,2
	ld	de,PARBUF+3
	call	EXTPAR
	jp	c,MISSPAR

	ld	a,1
	ld	hl,CHKVECT
	call	SET_PARAM
	jp	c,INVPAR

	print	PARSETOK_S
	jp	FIN


	;=====================================
	;===  F: Fichero de configuracion  ===
	;=====================================

PAR_SIM_F:	ld	a,(IS_FILE)	;Para evitar lectura recursiva
	or	a
	jp	nz,NOFILE

	xor	a
	ld	(FCBS),a	;Necesario en DOS 1

	;--- Extrae el nombre del fichero

	ld	a,2
	ld	de,BUFPAR
	call	EXTPAR
	jr	nc,SIMF_OKFNAME

	;* Nombre no presente: en DOS 1 usa INL.CFG tal cual,
	;  en DOS 2 usa INL.CFG en el directorio de INL.COM

	ld	de,BUFPAR
	ld	a,(DOS2)
	or	a
	jr	z,SIMF_SETNAME

	ld	hl,PROGRAM_S	;DOS 2: Obtiene variable PROGRAM...
	ld	de,BUFPAR
	ld	b,128
	ld	c,_GENV
	call	DOS

	ld	de,BUFPAR	;...y de ahi obtiene el puntero
	ld	bc,_PARSE	;al nombre del fichero
	call	DOS
	ex	de,hl

SIMF_SETNAME:	ld	hl,INLCFG_S
	ld	bc,8
	ldir
SIMF_OKFNAME:

	;*** Intenta abrir el fichero

	ld	de,BUFPAR
	call	OPEN
	or	a
	jr	z,SIMF_OPENOK
	ld	b,a

	ld	a,(DOS2)	;Error en DOS 1: muestra "No puedo abrir el fichero"
	or	a
	jp	z,FNOTF

	ld	de,PARBUF
	ld	c,_EXPLAIN
	call	DOS
	print	AST_S
	ld	de,PARBUF
	call	PRINTZ
	ld	c,_TERM0	;Error en DOS 2: muestra el error adecuado
	jp	5

SIMF_OPENOK:	ld	a,b
	ld	(FH),a

	;*** Establece IS_FILE y salta a FIN, lo cual causara
	;    que se procese el primer parametro

	ld	a,#FF
	ld	(IS_FILE),a
	jp	FIN


;***********************
;***  PARAMETROS IP  ***
;***********************

	;==============================
	;===  IP I: Inicializa IPs  ===
	;==============================

PAR_IP_I:	ld	a,(SEG2)
	call	_PUT_P2

	ld	hl,BUF_IPLOCAL
	ld	de,BUF_IPLOCAL+1
	ld	(hl),0
	ld	bc,15
	ldir

	ld	hl,SUBNET_MASK
	ld	de,SUBNET_MASK+1
	ld	(hl),0
	ld	bc,7
	ldir

	print	IPRESET_S
	jp	FIN

IPRESET_S:	db	"All IP addresses have been reset to 0.0.0.0",13,10,"$"


	;======================================
	;===  IP L, P, S, N, E, T, O, G, M  ===
	;======================================

PAR_IP_L:
PAR_IP_P:
PAR_IP_S:
PAR_IP_N:
PAR_IP_E:
PAR_IP_T:
PAR_IP_O:
PAR_IP_Z:
PAR_IP_G:
PAR_IP_M:
PAR_IP_D:
	and	223	;A mayusculas

PARS_IP:	push	af
	xor	a
	ld	(PARBUF+3),a

	ld	a,(SEG2)
	call	_PUT_P2

	ld	a,3
	ld	de,PARBUF+3
	call	EXTPAR

	pop	af
	call	FIND_PARAM
	jp	c,INVPAR

	call	SET_PARAM
	jp	c,INVPAR

	print	PARSETOK_S

	jp	FIN

PARSETOK_S:	db	"The specified parameter has been modified",13,10,"$"


;************************
;***  PARAMETROS DNS  ***
;************************

	;====================================================
	;===  DNS R: Resolucion de un nombre de servidor  ===
	;====================================================

	;--- Obtiene el nombre a resolver, devuelve error
	;    si no se ha especificado

PAR_DNS_R:	ld	a,3
	ld	de,BUFPAR
	call	EXTPAR
	jp	c,MISSPAR

	;--- Conecta segmento de INL y llama a DNS_Q

	ld	a,(SEG1)
	call	_PUT_P1

	print	RESOLVING_S

	ld	hl,BUFPAR
	xor	a
	call	DNS_Q

	ld	b,a
	jr	c,DNSQ_ERR

	;--- Espera a que la consulta termine,
	;    si se pulsa una tecla mientras, termina

DNSQ_WAIT:	call	WAIT_INT
	ld	a,1
	call	DNS_R

	;* Error?

	ld	b,a
	cp	3
	jr	z,DNSR_ERR

	;* Consulta finalizada? Muestra resultado y termina

	cp	2
	jr	nz,DNSQ_WAIT2

	ld	ix,RESOLVIP_S
	ld	a,"$"
	call	IP_STRING

	print	RESOLVOK_S
	jp	FIN

	;* Comprueba si se ha pulsado una tecla

DNSQ_WAIT2:	ld	e,#FF
	ld	c,_DIRIO
	call	DOS
	or	a
	jr	z,DNSQ_WAIT

	ld	a,1	;Si se ha cancelado,
	call	DNS_Q	;aborta la consulta
	jp	FIN

	;--- Rutina de error comun para DNS_Q y DNS_R
	;    Entrada: DE=Tabla de errores, B=Codigo de error

DNSQ_ERR:	ld	de,DNSQERRS_T
	jr	DNSQR_ERR

DNSR_ERR:	ld	de,DNSRERRS_T

DNSQR_ERR:	push	de,bc

	;* Imprime "ERROR <codigo>: "

	ld	ix,RESOLVERRC_S
	call	BYTE2ASC
	ld	(ix),":"
	ld	(ix+1)," "
	ld	(ix+2),"$"
	print	RESOLVERR_S

	;* Obtiene la cadena de error y la imprime

	pop	bc,de
	call	GET_STRING
	ld	c,_STROUT
	call	DOS

	jp	FIN

	;--- Cadenas

RESOLVING_S:	db	"Resolving host name...",13,10,"$"
RESOLVERR_S:	db	"ERROR "
RESOLVERRC_S:	ds	6	;Deja espacio para "<codigo>: $"
RESOLVOK_S:	db	"OK, host IP address is: "
RESOLVIP_S:	ds	16	;Espacio para "xxx.xxx.xxx.xxx$"

DNSQERRS_T:	db	1,"Not connected to Internet$"
	db	4,"No DNS servers available$"
	db	0

DNSRERRS_T:	db	1,"Query format error$"
	db	2,"Server failure$"
	db	3,"Name error (this host name does not exist)$"
	db	4,"Query type not implemented by the server$"
	db	5,"Query refused by the server$"
	db	16,"Server(s) not responding to queries$"
	db	17,"Total operation timeout expired$"
	db	19,"Internet connection lost$"
	db	20,"Dead-end reply (not containing answers nor redirections)$"
	db	21,"Truncated reply$"
	db	0


;************************
;***  PARAMETROS TCP  ***
;************************

	;====================================================
	;===  TCP S: Muestra el estado de conexiones TCP  ===
	;====================================================

PAR_TCP_S:	ld	a,(SEG1)
	call	_PUT_P1
	ld	a,(SEG2)
	call	_PUT_P2

	;* Comprueba conexion a la red

	call	NETWORK_STATE
	cp	2
	jr	z,TCPS_OKINET
	print	TCPNOINET_S
	jp	FIN
TCPS_OKINET:

	;* Extrae numero de conexion si lo hay

	ld	a,3
	ld	de,BUFPAR
	call	EXTPAR
	jr	nc,TCPS_ONE

	;* Muestra informacion de todas las conexiones

	xor	a
TCPS_LOOP:	push	af
	call	SHOW_TCP_INFO
	pop	af
	inc	a
	cp	4
	jr	c,TCPS_LOOP
	jp	FIN

	;* Muestra informacion de la conexion especificada,
	;  si el numero de conexion pasado es correcto

TCPS_ONE:	ld	a,(BUFPAR+1)
	or	a
	jr	nz,TCPS_ERR

	ld	a,(BUFPAR)
	sub	"0"
	cp	4
	jr	nc,TCPS_ERR

	call	SHOW_TCP_INFO
	jp	FIN

TCPS_ERR:	print	INVTCPE_S
	jp	FIN


	;--- Subrutina que muestra informacion de la conexion A

SHOW_TCP_INFO:	ld	(CONNUM),a
	add	"0"
	ld	(CONNUM2_S),a
	print	CONNUM_S

	;* Muestra estado

	ld	a,(CONNUM)
	call	TCP_STATUS
	jr	nc,TCPINFO_OK1
	print	TCPNOINET_S	;El error solo puede ser "No hay conexion a la red"
	jp	FIN
TCPINFO_OK1:

	ld	(TCB_POINTER),ix
	ld	c,a	;C = Estado
	ld	a,b
	ld	(CLOSE_CAUSE),a

	ld	de,TCPSTAT_T
	ld	b,c
	push	bc
	inc	b
	call	GET_STRING
	ld	c,_STROUT
	call	DOS
	print	NEWLINE_S

	pop	bc
	ld	a,b
	or	a
	jr	nz,TCP_NOCLOSED

	;* Conexion cerrada: muestra causa y termina

	print	CLCAUSE_S
	ld	de,TCPCLOSE_T
	ld	a,(CLOSE_CAUSE)
	ld	b,a
	inc	b
	call	GET_STRING
	ld	c,_STROUT
	call	DOS
	print	NEWLINE_S
	ret

	;* Conexion abierta: muestra puerto local

TCP_NOCLOSED:	ld	ix,(TCB_POINTER)
	ld	e,(ix+7)
	ld	d,(ix+8)
	ld	hl,BUFPAR
	ld	b,1
	ld	a,%1000
	call	NUMTOASC
	print	LOCPORT_S
	print	BUFPAR
	print	NEWLINE_S

	;* Muestra socket remoto

	print	REMPORT_S	;Puerto remoto
	ld	ix,(TCB_POINTER)
	ld	e,(ix+5)
	ld	d,(ix+6)
	ld	hl,BUFPAR
	ld	b,1
	ld	a,%1000
	call	NUMTOASC
	print	BUFPAR
	print	NEWLINE_S

	print	REMIP_S	;IP remota
	ld	ix,(TCB_POINTER)
	ld	l,(ix+1)
	ld	h,(ix+2)
	ld	e,(ix+3)
	ld	d,(ix+4)
	ld	ix,BUFPAR
	ld	a,"$"
	call	IP_STRING
	print	BUFPAR
	print	NEWLINE_S

	ret

	;--- Variables

CLOSE_CAUSE:	db	0
CONNUM:	db	0
TCB_POINTER:	dw	0

	;--- Cadenas

INVTCPE_S:	db	"*** Invalid TCP connection number$"
TCPNOINET_S:	db	"*** Not connected to Internet$"
CONNUM_S:	db	13,10,"> Connection "
CONNUM2_S:	db	"0 - State: $"
REMIP_S:	db	"  Remote IP: $"
REMPORT_S:	db	"  Remote port: $"
LOCPORT_S:	db	"  Local port: $"
CLCAUSE_S:	db	"  Close cause: $"


TCPSTAT_T:	db	1,"CLOSED$"
	db	2,"LISTEN$"
	db	3,"SYN-SENT$"
	db	4,"SYN-RECEIVED$"
	db	5,"ESTABLISHED$"
	db	6,"FIN-WAIT-1$"
	db	7,"FIN-WAIT-2$"
	db	8,"CLOSE-WAIT$"
	db	9,"CLOSING$"
	db	10,"LAST-ACK$"
	db	11,"TIME-WAIT$"
	db	0

TCPCLOSE_T:	db	1,"Connection never used$"
	db	2,"Local CLOSE call$"
	db	3,"Local ABORT call$"
	db	4,"Remote RST received$"
	db	5,"User timeout expired$"
	db	6,"Connection establishment timeout expired$"
	db	7,"Internet connection lost$"
	db	8,"Destination host unreachable$"
	db	0


	;=================================================
	;===  TCP C/A: Cierra/aborta una conexion TCP  ===
	;=================================================


PAR_TCP_C:	ld	hl,TCP_CLOSE
	ld	de,TCP_CLOSED_S
	jr	PAR_TCP_CA

PAR_TCP_A:	ld	hl,TCP_ABORT
	ld	de,TCP_ABORTED_S
	;jr      PAR_TCP_CA


	;*** Codigo comun para TCP C y TCP A
	;    Entrada: HL = Rutina a llamar, TCP_CLOSE o TCP_ABORT
	;             DE = Cadena "closed" o "aborted"

PAR_TCP_CA:	ld	(TCP_CA_RUT),hl
	ld	(TCP_CA_STR),de

	ld	a,(SEG1)
	call	_PUT_P1

	;* Extrae numero de conexion

	ld	a,3	;Existe el parametro?
	ld	de,BUFPAR
	call	EXTPAR
	jp	c,MISSPAR

	ld	hl,BUFPAR	;Es un numero?
	call	EXTNUM8
	jr	nc,TCPCA_OK1

	print	INVTCPE_S
	jp	FIN
TCPCA_OK1:

	;* Ejecuta la rutina adecuada

	ld	hl,TCPCA_NEXT
	push	hl
	ld	hl,(TCP_CA_RUT)
	jp	(hl)
TCPCA_NEXT:	jr	c,TCPCA_ERR

	print	TCPCA_OK_S	;Imprime cadena de exito
	ld	de,(TCP_CA_STR)
	ld	c,_STROUT
	call	DOS
	jp	FIN
TCPCA_ERR:

	;* Si hubo error, imprime la cadena adecuada

	ld	de,TCPCAERR_T
	ld	b,a
	call	GET_STRING
	ld	c,_STROUT
	call	DOS
	jp	FIN

	;--- Variables

TCP_CA_RUT:	dw	0
TCP_CA_STR:	dw	0

	;--- Cadenas

TCPCA_OK_S:	db	"The specified connection has been $"
TCP_CLOSED_S:	db	"closed.$"
TCP_ABORTED_S:	db	"aborted.$"

TCPCAERR_T:	db	1,"*** Invalid TCP connection number$"
	db	2,"*** The specified connection is closed$"
	db	0


;*****************************
;***  PARAMETROS ETHERNET  ***
;*****************************

	;===========================================
	;===  ETH H: Muestra direccion hardware  ===
	;===========================================

PAR_ETH_H:	ld	a,(SEG1)
	call	_PUT_P1

	call	ONET_INFO
	ld	ix,HWADD_BUF
	ld	a,1
	call	ETH2ASCII

	print	HWADD_S
	jp	FIN

HWADD_S:	db	"ObsoNET hardware address: "
HWADD_BUF:	ds	17
	db	13,10,"$"


	;=================================================
	;===  ETH F: Establece tipo de trama a enviar  ===
	;=================================================

PAR_ETH_F:	ld	a,(SEG2)
	call	_PUT_P2

	ld	de,PARBUF
	ld	a,3
	call	EXTPAR
	jp	c,MISSPAR

	ld	hl,PARBUF
	call	EXTNUM8
	jp	c,INVPAR
	or	a
	jr	z,ETHH_OK
	cp	1
	jp	nz,INVPAR
	ld	a,#FF

ETHH_OK:	ld	(FRAME_TYPE),a
	print	PARSETOK_S
	jp	FIN


	;================================================
	;===  ETH C: Establece comprobar la red o no  ===
	;================================================

PAR_ETH_C:	ld	a,(SEG2)
	call	_PUT_P2

	ld	de,PARBUF
	ld	a,3
	call	EXTPAR
	jp	c,MISSPAR

	ld	hl,PARBUF
	call	EXTNUM8
	jp	c,INVPAR
	or	a
	jr	z,ETHC_OK
	cp	1
	jp	nz,INVPAR
	ld	a,#FF

ETHC_OK:	ld	(CHECK_NET),a
	print	PARSETOK_S
	jp	FIN


	;========================================
	;===  ETH R: Reinicializa la ObsoNET  ===
	;========================================

PAR_ETH_R:	ld	a,(SEG2)
	call	_PUT_P2
	ld	a,(SEG1)
	call	_PUT_P1

	if	FLASH=0

	ld	a,(OBSLOT)
	ld	h,#80
	call	ENASLT

	call	#401E
	call	#4021
	push	hl,de,bc

	ld	a,(#F343)
	ld	h,#80
	call	ENASLT

	endif

	if	FLASH=1

	ld	a,(OBSLOT)
	ld	h,#40
	call	ENASLT

	call	RTL_RESET
	call	GET_HWAD
	push	hl,de,bc

	ld	a,(#F342)
	ld	h,#40
	call	ENASLT

	endif

	ld	a,(SEG2)
	call	_PUT_P2

	pop	bc,de,hl
	ld	(HWAD),hl
	ld	(HWAD+2),de
	ld	(HWAD+4),bc

	print	OBRESET_S
	jp	FIN

OBRESET_S:	db	"ObsoNET card has been reset.",13,10,"$"


;************************
;***  PARAMETROS ARP  ***
;************************

	;======================================
	;===  ARP T: Establece timeout ARP  ===
	;======================================

PAR_ARP_T:	ld	a,(SEG2)
	call	_PUT_P2

	;* Extrae timeout

	ld	a,3	;Existe el parametro?
	ld	de,BUFPAR
	call	EXTPAR
	jp	c,MISSPAR

	ld	hl,BUFPAR
	call	EXTNUM
	jp	c,INVPAR
	ld	a,b
	ld	(ETHT_NUM+2),a
	or	c
	jp	z,INVPAR
	ld	a,c
	ld	(ETHT_NUM+3),a
	push	bc
	pop	hl

	ld	a,e
	or	#20
	cp	"s"
	jr	z,ETH_T_S
	cp	"m"
	jr	z,ETH_T_M
	cp	"h"
	jp	nz,INVPAR

	;--- Horas (hasta 18)

ETH_T_H:	ld	de,19
	call	COMP	;NC si HL<DE
	jp	c,INVPAR

	ld	ix,ETHT_NUM
	call	POR60_32	;Minutos
	call	POR60_32	;Segundos
	jr	ETH_T_S

	;--- Minutos (hasta 1080)

ETH_T_M:	ld	de,1081
	call	COMP
	jp	c,INVPAR

	ld	ix,ETHT_NUM
	call	POR60_32	;Segundos

	;--- Segundos

ETH_T_S:	ld	hl,ETHT_NUM
	ld	de,ARP_TOUT_SECS
	ld	bc,4
	ldir

	ld	ix,ETHT_NUM
	call	POR60_32	;1/60 segundos
	ld	hl,ETHT_NUM
	ld	de,ARP_TOUT
	ld	bc,4
	ldir

	print	PARSETOK_S
	jp	FIN

ETHT_NUM:	ds	4


	;==================================
	;===  ARP S: Muestra cache ARP  ===
	;==================================

PAR_ARP_S:	ld	a,(SEG2)
	call	_PUT_P2
	ld	a,(SEG1)
	call	_PUT_P1

	print	ARPHEAD_S

	;--- Bucle para todas las entradas ARP

	ld	ix,ARP_CACHE
	ld	b,ARP_ENTRIES
ARPS_LOOP:	push	bc

	;* Entrada en uso?

	ld	a,(ix)
	or	a
	jr	z,ARPS_NEXT

	;* Limpia bufer

	ld	hl,ARPIP_B
	ld	de,ARPIP_B+1
	ld	bc,18+24+7-1
	ld	(hl),32
	ldir

	;* Establece IP

	ld	l,(ix+7)
	ld	h,(ix+8)
	ld	e,(ix+9)
	ld	d,(ix+10)
	push	ix
	ld	ix,ARPIP_B
	ld	a," "
	call	IP_STRING
	pop	ix

	;* Establece dir hw, a no ser que este en resolucion

	ld	a,(ix)
	cp	3
	jr	nz,NOARPRSLV

	ld	hl,RESOLVINGA_S
	ld	de,ARPHW_B
	ld	bc,11
	ldir
	jr	OK_ARPS_HW
NOARPRSLV:

	ld	l,(ix+1)
	ld	h,(ix+2)
	ld	e,(ix+3)
	ld	d,(ix+4)
	ld	c,(ix+5)
	ld	b,(ix+6)
	ld	a,1
	push	ix
	ld	ix,ARPHW_B
	call	ETH2ASCII
	pop	ix
OK_ARPS_HW:

	;* Establece tipo

	ld	hl,STATIC_S
	ld	a,(ix)
	cp	1
	jr	z,OK_ARPS_TYPE
	ld	hl,DINAMIC_S
OK_ARPS_TYPE:	ld	de,ARPTYPE_B
	ld	bc,7
	ldir

	;* Imprime entrada y pasa a la siguiente si quedan

	print	ARPIP_B

ARPS_NEXT:	ld	bc,16
	add	ix,bc
	pop	bc
	dec	b
	jp	nz,ARPS_LOOP

	jp	FIN

	;--- Cadenas

ARPHEAD_S:	db	"IP address        Hardware address        Type",13,10
	db	"----------        ----------------        ----",13,10,"$"
ARPIP_B:	ds	18
ARPHW_B:	ds	24
ARPTYPE_B:	ds	7
	db	13,10,"$"
STATIC_S:	db	"static "
DINAMIC_S:	db	"dynamic"
RESOLVINGA_S:	db	"(resolving)"


	;================================
	;===  ARP C: Borra cache ARP  ===
	;================================

PAR_ARP_C:	ld	a,(SEG2)
	call	_PUT_P2

	ld	hl,ARP_CACHE
	ld	de,ARP_CACHE+1
	ld	bc,ARP_ENTRIES*16-1
	ld	(hl),0
	ldir

	print	ARPCLEAR_S
	jp	FIN

ARPCLEAR_S:	db	"The ARP table has been cleared.",13,10,"$"


	;===================================
	;===  ARP A: Anyade entrada ARP  ===
	;===================================

PAR_ARP_A:	ld	a,(SEG2)
	call	_PUT_P2
	ld	a,(SEG1)
	call	_PUT_P1

	;* Extrae parametros

	ld	a,3	;Dir IP
	ld	de,BUFPAR
	call	EXTPAR
	jp	c,MISSPAR

	ld	hl,BUFPAR	;La interpreta
	ld	a,2
	call	DNS_Q
	jp	c,INVPAR
	ld	(ARPA_IP),hl
	ld	(ARPA_IP+2),de

	ld	a,4	;Dir hardware
	ld	de,BUFPAR
	call	EXTPAR
	jp	c,MISSPAR

	ld	hl,BUFPAR	;La interpreta
	call	ASCII2ETH
	jp	c,INVPAR
	ld	(ARPA_HW),hl
	ld	(ARPA_HW+2),de
	ld	(ARPA_HW+4),bc

	;--- Primero comprueba si existe una entrada para esa IP,
	;    en ese caso la actualiza

	ld	ix,ARP_CACHE
	ld	b,ARP_ENTRIES
ARPA_LOOP1:	push	bc
	ld	a,(ix)
	or	a
	jr	z,ARPA_NEXT1

	push	ix	;Coinciden las IPs?
	pop	hl
	ld	bc,7
	add	hl,bc
	ld	de,ARPA_IP
	call	EQUAL32
	jr	nz,ARPA_NEXT1

	push	ix
	pop	de
	ld	hl,ARPA_HW-1
	ld	bc,11
	ldir

	print	ARPAUP_S
	pop	bc
	jp	FIN

ARPA_NEXT1:	ld	bc,16
	add	ix,bc
	pop	bc
	djnz	ARPA_LOOP1

	;--- Busca una entrada libre

	ld	ix,ARP_CACHE
	ld	b,ARP_ENTRIES
	ld	h,0
	ld	de,0
ARPA_LOOP2:	push	bc
	inc	h
	ld	a,(ix)
	or	a
	jr	nz,ARPA_NEXT2

	dec	h
	ld	a,d
	or	e
	jr	nz,ARPA_NEXT2
	push	ix
	pop	de
ARPA_NEXT2:	ld	bc,16
	add	ix,bc
	pop	bc
	djnz	ARPA_LOOP2

	;* Aqui, H contiene el num de entradas ocupadas,
	;  y DE la dir de la entrada libre si se ha encontrado.
	;  Mostramos error si hay ARP_ENTRIES-2 entradas ocupadas.

	ld	a,h
	cp	ARP_ENTRIES-2
	jr	c,ARPA_OK1

	print	ARPAFULL_S
	jp	FIN
ARPA_OK1:

	;* Anyade la entrada y termina

	ld	hl,ARPA_HW-1
	ld	bc,11
	ldir

	print	ARPAADDED_S
	jp	FIN


	;--- Cadenas y buferes

ARPAUP_S:	db	"The ARP entry has been updated.",13,10,"$"
ARPAFULL_S:	db	"*** ERROR: The ARP cache is full.",13,10,"$"
ARPAADDED_S:	db	"The ARP entry has been added.",13,10,"$"
	db	1
ARPA_HW:	ds	6
ARPA_IP:	ds	4


	;==================================
	;===  ARP D: Borra entrada ARP  ===
	;==================================

PAR_ARP_D:	ld	a,(SEG2)
	call	_PUT_P2
	ld	a,(SEG1)
	call	_PUT_P1

	;* Extrae parametro

	ld	a,3	;Dir IP
	ld	de,BUFPAR
	call	EXTPAR
	jp	c,MISSPAR

	ld	hl,BUFPAR	;La interpreta
	ld	a,2
	call	DNS_Q
	jp	c,INVPAR
	ld	(ARPA_IP),hl
	ld	(ARPA_IP+2),de

	;* Busca la entrada

	ld	ix,ARP_CACHE
	ld	b,ARP_ENTRIES
ARPD_LOOP1:	push	bc
	ld	a,(ix)
	or	a
	jr	z,ARPD_NEXT1

	push	ix	;Coinciden las IPs?
	pop	hl
	ld	bc,7
	add	hl,bc
	ld	de,ARPA_IP
	call	EQUAL32
	jr	nz,ARPD_NEXT1

	ld	(ix),0	;Si: la borra y termina
	print	ARPDELETED_S
	pop	bc
	jp	FIN

ARPD_NEXT1:	ld	bc,16
	add	ix,bc
	pop	bc
	djnz	ARPD_LOOP1

	;* No encontrada

	print	ARPD_NOTF_S
	jp	FIN

	;--- Cadenas

ARPDELETED_S:	db	"The specified ARP entry has been deleted.",13,10,"$"
ARPD_NOTF_S:	db	"*** ERROR: ARP entry not found.",13,10,"$"


;*********************************
;***  PARAMETROS ENRUTAMIENTO  ***
;*********************************

	;===========================================
	;===  ROU S: Muestra tabla enrutamiento  ===
	;===========================================

PAR_ROU_S:	ld	a,(SEG2)
	call	_PUT_P2
	ld	a,(SEG1)
	call	_PUT_P1

	print	ROUHEAD_S

	;--- Bucle para todas las entradas de enrutamiento

	ld	ix,ROUTE_TABLE
	ld	b,ROUTE_ENTRIES
ROUS_LOOP:	push	bc

	;* Entrada en uso?

	ld	a,(ix)
	or	a
	jr	z,ROUS_NEXT

	;* Limpia bufer

	ld	hl,ROUNET_B
	ld	de,ROUNET_B+1
	ld	bc,20+20+20-1
	ld	(hl)," "
	ldir

	;* Establece red

	ld	l,(ix+1)
	ld	h,(ix+2)
	ld	e,(ix+3)
	ld	d,(ix+4)
	push	ix
	ld	ix,ROUNET_B
	ld	a," "
	call	IP_STRING
	pop	ix

	;* Establece mascara

	ld	l,(ix+5)
	ld	h,(ix+6)
	ld	e,(ix+7)
	ld	d,(ix+8)
	push	ix
	ld	ix,ROUMASK_B
	ld	a," "
	call	IP_STRING
	pop	ix

	;* Establece router

	ld	l,(ix+9)
	ld	h,(ix+10)
	ld	e,(ix+11)
	ld	d,(ix+12)
	push	ix
	ld	ix,ROUROU_B
	ld	a," "
	call	IP_STRING
	pop	ix

	;* Imprime entrada y pasa a la siguiente si quedan

	print	ROUNET_B

ROUS_NEXT:	ld	bc,16
	add	ix,bc
	pop	bc
	djnz	ROUS_LOOP

	jp	FIN

	;--- Cadenas

ROUHEAD_S:	db	"Network             Mask                Router ",13,10
	db	"-------             ----                ------",13,10,"$"
ROUNET_B:	ds	20
ROUMASK_B:	ds	20
ROUROU_B:	ds	20
	db	13,10,"$"


	;=========================================
	;===  ROU C: Borra tabla enrutamiento  ===
	;=========================================

PAR_ROU_C:	ld	a,(SEG2)
	call	_PUT_P2

	ld	hl,ROUTE_TABLE
	ld	de,ROUTE_TABLE+1
	ld	bc,ROUTE_ENTRIES*16-1
	ld	(hl),0
	ldir

	print	ROUCLEAR_S
	jp	FIN

ROUCLEAR_S:	db	"The routing table has been cleared.",13,10,"$"


	;============================================
	;===  ROU A: Anyade entrada enrutamiento  ===
	;============================================

PAR_ROU_A:	ld	a,(SEG2)
	call	_PUT_P2
	ld	a,(SEG1)
	call	_PUT_P1

	;* Extrae parametros

	ld	a,3	;Red
	ld	de,BUFPAR
	call	EXTPAR
	jp	c,MISSPAR

	ld	hl,BUFPAR	;La interpreta
	ld	a,2
	call	DNS_Q
	jp	c,INVPAR
	ld	(ROUA_NET),hl
	ld	(ROUA_NET+2),de

	ld	a,4	;Mascara
	ld	de,BUFPAR
	call	EXTPAR
	jp	c,MISSPAR

	ld	hl,BUFPAR	;La interpreta
	ld	a,2
	call	DNS_Q
	jp	c,INVPAR
	ld	(ROUA_MASK),hl
	ld	(ROUA_MASK+2),de

	ld	a,5	;Router
	ld	de,BUFPAR
	call	EXTPAR
	jp	c,MISSPAR

	ld	hl,BUFPAR	;La interpreta
	ld	a,2
	call	DNS_Q
	jp	c,INVPAR
	ld	(ROUA_ROU),hl
	ld	(ROUA_ROU+2),de

	;--- Primero comprueba si existe esa entrada,
	;    en ese caso la actualiza

	ld	ix,ROUTE_TABLE
	ld	b,ROUTE_ENTRIES
ROUA_LOOP1:	push	bc
	ld	a,(ix)
	or	a
	jr	z,ROUA_NEXT1

	push	ix	;Coinciden las IPs?
	pop	hl
	inc	hl
	ld	de,ROUA_NET
	call	EQUAL64
	jr	nz,ROUA_NEXT1

	push	ix
	pop	de
	inc	de
	ld	hl,ROUA_NET
	ld	bc,12
	ldir

	print	ROUAUP_S
	pop	bc
	jp	FIN

ROUA_NEXT1:	ld	bc,16
	add	ix,bc
	pop	bc
	djnz	ROUA_LOOP1

	;--- Busca una entrada libre

	ld	ix,ROUTE_TABLE
	ld	b,ROUTE_ENTRIES
ROUA_LOOP2:	push	bc
	ld	a,(ix)
	or	a
	jr	nz,ROUA_NEXT2

	push	ix
	pop	de
	ld	hl,ROUA_NET-1
	ld	bc,13
	ldir

	print	ROUAADDED_S
	pop	bc
	jp	FIN

ROUA_NEXT2:	ld	bc,16
	add	ix,bc
	pop	bc
	djnz	ROUA_LOOP2

	;* Tabla llena: avisa y termina

	print	ROUAFULL_S
	jp	FIN

	;--- Cadenas y buferes

ROUAUP_S:	db	"The routing entry has been updated.",13,10,"$"
ROUAFULL_S:	db	"*** ERROR: The routing table is full.",13,10,"$"
ROUAADDED_S:	db	"The routing entry has been added.",13,10,"$"
	db	1
ROUA_NET:	ds	4
ROUA_MASK:	ds	4
ROUA_ROU:	ds	4


	;===========================================
	;===  ROU D: Borra entrada enrutamiento  ===
	;===========================================

PAR_ROU_D:	ld	a,(SEG2)
	call	_PUT_P2
	ld	a,(SEG1)
	call	_PUT_P1

	;* Extrae parametros

	ld	a,3	;Red
	ld	de,BUFPAR
	call	EXTPAR
	jp	c,MISSPAR

	ld	hl,BUFPAR	;La interpreta
	ld	a,2
	call	DNS_Q
	jp	c,INVPAR
	ld	(ROUA_NET),hl
	ld	(ROUA_NET+2),de

	ld	a,4	;Mascara
	ld	de,BUFPAR
	call	EXTPAR
	jp	c,MISSPAR

	ld	hl,BUFPAR	;La interpreta
	ld	a,2
	call	DNS_Q
	jp	c,INVPAR
	ld	(ROUA_MASK),hl
	ld	(ROUA_MASK+2),de

	;--- Comprueba si existe esa entrada,
	;    en ese caso la borra

	ld	ix,ROUTE_TABLE
	ld	b,ROUTE_ENTRIES
ROUD_LOOP1:	push	bc
	ld	a,(ix)
	or	a
	jr	z,ROUD_NEXT1

	push	ix	;Coinciden las IPs?
	pop	hl
	inc	hl
	ld	de,ROUA_NET
	call	EQUAL64
	jr	nz,ROUD_NEXT1

	ld	(ix),0
	print	ROUDELETED_S
	pop	bc
	jp	FIN

ROUD_NEXT1:	ld	bc,16
	add	ix,bc
	pop	bc
	dec	b
	jr	nz,ROUD_LOOP1

	;--- Entrada no encontrada

	print	ROUDNOTF_S
	jp	FIN

	;--- Cadenas

ROUDELETED_S:	db	"The specified routing entry has been deleted.",13,10,"$"
ROUDNOTF_S:	db	"*** ERROR: Routing entry not found.",13,10,"$"


;********************
;***              ***
;***  SUBRUTINAS  ***
;***              ***
;********************

;--- Compara (HL) y (DE) de 32 bits, devuelve Z=1 si son iguales

EQUAL32:	ld	b,4
EQUAL32L:	ld	a,(de)
	cp	(hl)
	ret	nz
	inc	hl
	inc	de
	djnz	EQUAL32L
	ret

EQUAL64:	call	EQUAL32
	ret	nz
	jp	EQUAL32


;--- Fin del programa. En modo lectura de fichero, lee la siguiente opcion.

FIN:	ld	a,(IS_FILE)
	or	a
	jr	z,FIN_REAL

	;* Lectura de fichero: intenta leer parametro

	call	READ_LINE
	ld	a,(#80)
	or	a
	jr	z,FIN_REAL	;No se ha podido leer nada?

	;* Imprime el parametro y salta al codigo del principio del programa
	;  para que sea procesado como si fuera de la linea de comandos

	ld	de,#82
	call	PRINTZ	;Imprime "<parametro>: "
	ld	e,":"
	ld	c,_CONOUT
	call	DOS
	ld	e," "
	ld	c,_CONOUT
	call	DOS

	ld	a,1
	ld	de,BUFPAR
	call	EXTPAR

	jp	PROC_PARAMS

	;* Finalizacion real del programa, o continuacion con la instalacion

FIN_REAL:	ld	a,(IS_FILE_INS)
	or	a
	jr	z,FIN_REAL2
	print	NEWLINE_S
	jp	READINI_END
FIN_REAL2:

	ld	a,(#F342)
	ld	h,#40
	call	ENASLT

	ld	a,(DOS2)
	or	a
	ld	de,0
	ld	c,_DEFAB
	call	nz,DOS

	ld	a,(FH)
	cp	#FF
	ld	b,a
	call	nz,CLOSE

	ld	a,2
	call	_PUT_P1
	ld	a,1
	call	_PUT_P2
	ld	c,_TERM0
	jp	5


DOS:	call	5	;Se cambiara por JP 5 si DOS 2
	push	af,bc,de,hl,ix,iy
	ld	a,(#F344)
	ld	h,#40
	call	ENASLT
	pop	iy,ix,hl,de,bc,af
	ret


AB_HANDLER:	pop	hl	;Para evitar salir con CTRL-STOP
	ret


;--- PRINTZ: Imprime una cadena acabada en "0", mas un salto de linea
;            Entrada: DE = Cadena

PRINTZ:	ld	a,(de)
	or	a
	ret	z
	push	de
	ld	e,a
	ld	c,2
	call	DOS
	pop	de
	inc	de
	jr	PRINTZ


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
;    Modifica: Todos

EXTNUM16:	call	EXTNUM
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
;    Modifica: Todos

EXTNUM8:	call	EXTNUM
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
;               DE = Bufer para dejar el parametro
;    SALIDA:    A  = Numero de parametros
;               CY = 1 -> No existe ese parametro
;                         B indefinido, bufer inalterado
;               CY = 0 -> B = Longitud del parametro (no incluye el 0)
;                         Parametro a partir de DE, acabado en 0
;    REGISTROS: -
;    LLAMADAS:  -

EXTPAR:	or	a	;Volvemos con error si A = 0
	scf
	ret	z

	ld	b,a
	ld	a,(#80)	;Volvemos con error si no hay parametros
	or	a
	scf
	ret	z
	ld	a,b

	push	af,hl
	ld	a,(#80)
	ld	c,a	;Ponemos un 0 al final
	ld	b,0
	ld	hl,#81
	add	hl,bc
	ld	(hl),0
	pop	hl,af

	push	hl,de,ix
	ld	ix,0	;IXl: Numero de parametros    
	ld	ixh,a	;IXh: Parametro a extraer    
	ld	hl,#81

PASASPC:	ld	a,(hl)	;Vamos pasando espacios    
	or	a
	jr	z,ENDPNUM
	cp	" "
	inc	hl
	jr	z,PASASPC

	inc	ix
PASAPAR:	ld	a,(hl)	;Vamos pasando el parametro    
	or	a
	jr	z,ENDPNUM
	cp	" "
	inc	hl
	jr	z,PASASPC
	jr	PASAPAR

ENDPNUM:	ld	a,ixh	;Error si se el parametro a extraer    
	dec	a	;(anyadido para quitar el jrmy)
	cp	ixl	;es mayor que el numero de parametros    
	jr	nc,EXTPERR
	;jrmy	EXTPERR	;existentes    

	ld	hl,#81
	ld	b,1	;B = parametro actual    
PASAP2:	ld	a,(hl)	;Pasamos espacios hasta dar    
	cp	" "	;con el siguiente parametro    
	inc	hl
	jr	z,PASAP2

	ld	a,ixh	;Si es el que buscamos lo extraemos.    
	cp	B	;Si no ...    
	jr	z,PUTINDE0

	inc	B
PASAP3:	ld	a,(hl)	;... lo pasamos y volvemos a PAPAP2    
	cp	" "
	inc	hl
	jr	nz,PASAP3
	jr	PASAP2

PUTINDE0:	ld	b,0
	dec	hl
PUTINDE:	inc	b
	ld	a,(hl)
	cp	" "
	jr	z,ENDPUT
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


;--- Conversion del numero A en una cadena sin terminacion
;    Deposita la cadena en (IX), y modifica IX para que apunte tras la cadena
;    Modifica C

BYTE2ASC:	cp	10
	jr	c,B2A_1D
	cp	100
	jr	c,B2A_2D
	cp	200
	jr	c,B2A_1XX
	jr	B2A_2XX

	;--- Un digito

B2A_1D:	add	"0"
	ld	(ix),a
	inc	ix
	ret

	;--- Dos digitos

B2A_2D:	ld	c,"0"
B2A_2D2:	inc	c
	sub	10
	cp	10
	jr	nc,B2A_2D2

	ld	(ix),c
	inc	ix
	jr	B2A_1D

	;--- Entre 100 y 199

B2A_1XX:	ld	(ix),"1"
	sub	100
B2A_XXX:	inc	ix
	cp	10
	jr	nc,B2A_2D	;Si es 1XY con X>0
	ld	(ix),"0"	;Si es 10Y
	inc	ix
	jr	B2A_1D

	;--- Entre 200 y 255

B2A_2XX:	ld	(ix),"2"
	sub	200
	jr	B2A_XXX


;--- Test de memoria directo (DOS 1)
;    ENTRADA:   DE = Bufer de 256 bytes que NO puede estar en la pagina 1
;                    ni puede contener la direccion #5000
;                    El mapeador ha de estar conectado en la pagina 1
;    SALIDA:    A  = Numero de segmentos
;                    0 -> El slot no contiene RAM
;                    1 -> El slot contiene RAM no mapeada
;    LLAMADAS:  -
;    REGISTROS: F, HL, BC, DE

MEMTEST1:	ld	a,(#5001)	;Comprobamos si es ROM
	ld	h,a
	cpl
	ld	(#5001),a
	ld	a,(#5001)
	cpl
	ld	(#5001),a
	cpl
	cp	h
	ld	a,0
	ret	z

	ld	hl,#4001
	in	a,(#FD)
	push	af	;A  = Segmento actual en pagina 2    
	push	de	;DE = Bufer    
	ld	b,0

MT1BUC1:	ld	a,b	;Grabamos el primer byte de todas los    
	out	(#FD),a	;segmentos
	ld	a,(hl)
	ld	(de),a
	ld	a,b
	ld	(hl),a
	inc	de
	inc	b
	ld	a,b
	cp	0
	jr	nz,MT1BUC1

	out	(#FD),a
	ld	a,(hl)
	neg
	ld	(NUMSGS),a	;A = Numero de segmentos encontrados   
	ld	b,0	;    (0 para 256)    
	ld	c,a
	pop	de

MT1BUC2:	ld	a,b
	out	(#FD),a	;Restauramos el primer byte de
	ld	a,(de)	;todos los segmentos    
	ld	(hl),a
	inc	de
	inc	b
	ld	a,b
	cp	c
	jr	nz,MT1BUC2

	pop	af	;Restauramos segmento original    
	out	(#FD),a
	ld	a,(NUMSGS)
	cp	1
	jr	z,NOMAP1
	or	a
	ret	nz
	ld	a,#FF
	ret
NOMAP1:	xor	a
	ret

NUMSGS:	db	0


;--- Inicializacion de las variables de INL
;    (se supone que el segmento de variables esta conectado en pagina 2)

INIT_VARS:	ld	hl,#8000	;Primero lo borra todo
	ld	de,#8001
	ld	bc,16383
	ld	(hl),0
	ldir

	ld	a,64
	ld	(TTL),a	;TTL
	ld	a,31
	ld	(CHKVECT),a	;Todos los checksums ON
	ld	a,#FF
	ld	(REPLYECHO),a	;Responder PINGs ON
	ld	hl,64
	ld	(PING_SIZE),hl
	ld	a,#FF	;Comprobar red cada 10 segs
	ld	(CHECK_NET),a
	ld	hl,ARP_TOUT_DEF
	ld	de,ARP_TOUT
	ld	bc,4
	ldir
	ld	hl,ARP_TOUT_DEF2
	ld	de,ARP_TOUT_SECS
	ld	bc,4
	ldir

	ld	hl,60	;Espera 1 segundo
	ld	(NETSTAT_TIMER),hl

	ld	hl,(SYSTIMER)	;Inicializa XID de DHCP
	ld	a,r
	xor	h
	ld	(DHCP_XID),a
	ld	a,r
	xor	l
	ld	(DHCP_XID+1),a
	ld	c,_GTIME
	call	DOS
	ld	a,r
	xor	l
	ld	(DHCP_XID+2),a
	ld	a,r
	xor	d
	ld	(DHCP_XID+3),a

	xor	a	;TCBs en blanco
	ld	(TCBS),a
	ld	(TCBS+256),a
	ld	(TCBS+2*256),a
	ld	(TCBS+3*256),a

	ret

ARP_TOUT_DEF:	db	#00,#00,#46,#50	;5 minutos * 60 segs * 60 ints
ARP_TOUT_DEF2:	db	#00,#00,#01,#2C	;5 minutos * 60 segs


;--- Rutina de salto al BASIC y CALL SYSTEM (a usar al instalar y desinst.)
;    Previamente se copia el comando a ser ejecutado tras el _SYSTEM,
;    a partir de la posicion de la linea de comando entrada en HL.
;    Entrada: Cy=0 para instalar, 1 para desinstalar

CALSYS:	jr	nc,CALSYS2
	ld	a,#C9	;Si desinstalamos, ejecutara RET en "Sigue"
	ld	(Sigue),a

CALSYS2:	ld	ix,ComLine+2

	ld	a,(DOS2)	;DOS 1 o no hay comandos:
	or	a	;se salta la copia de comandos
	jr	z,OKBSC
	ld	a,(hl)
	or	a
	jr	z,OKBSC

	ld	(ix-2),"("
	ld	(ix-1),34

BUCSYSCOM:	ld	a,(hl)	;Buscamos el primer caracter, o el 0
	inc	hl
	or	a
	jr	z,OKBSC
	cp	" "
	jr	z,BUCSYSCOM
	dec	hl

BUCSYS2:	ld	(ix),a	;Copiamos caracteres hasta encontrar
	inc	ix	;el 0
	inc	hl
	ld	a,(hl)
	cp	"&"
	jr	nz,NOANGLUNO
	ld	a,"^"
NOANGLUNO:	or	a
	jr	nz,BUCSYS2

	ld	(ix),34
	ld	(ix+1),")"
	ld	(ix+2),0
OKBSC:	;

	;CALL SYSTEM propiamente dicho

	ld	hl,SystemProg
	ld	de,08000h
	ld	bc,0200h
	ldir
	jp	08000h
SystemProg:	;

	;>>> Atencion: a partir de aqui, se ejecuta en #8000

	;--- Salta al BASIC

	ld	a,(0FCC1h)
	push	af
	ld	h,0
	call	024h
	pop	af
	ld	h,040h
	call	024h
	xor	a
	ld	hl,0F41Fh
	ld	(0F860h),hl
	ld	hl,0F423h
	ld	(0F41Fh),hl
	ld	(hl),a
	ld	hl,0F52Ch
	ld	(0F421h),hl
	ld	(hl),a
	ld	hl,0F42Ch
	ld	(0F862h),hl
	ld	hl,#8030	;OJO !!! (es SysTxT2)
	jp	04601h

SysTxT2:	db	#3A	;:
	db	#97,#DD,#EF	;DEF USR =
	db	#0C
SigueDir:	dw	Sigue-SystemProg+#8000	;Direccion de "Sigue"
	db	#3A,#91,#DD,"(",34,34,")"	;:? USR("")
	db	03Ah,0CAh	;:CALL
	db	"SYSTEM"
ComLine:	db	0
	ds	128	;Espacio para los comandos extra

	;*** Codigo que se ejecutara en el USR (RET si desinst.)

Sigue:	;ld	a,(P3_ID)
	;cp	"I"
	;ret	nz	;Si estamos desinstalando

	;--- Copia la parte residente a pag. 3

	ld	hl,#B000
	ld	de,(P3_P3DIR0022-P3_START0022+#B000+1)	;(P3_P3DIR)
	ld	bc,P3_END0022-P3_START0022
	ldir

	;--- Establecemos el nuevo EXTBIO

	di
	ld	a,#C3
	ld	(EXTBIO),a
	ld	hl,NEWEXT0022-P3_START0022
	ld	bc,(P3_P3DIR0022-P3_START0022+#B000+1)	;(P3_P3DIR)
	add	hl,bc
	ld	(EXTBIO+1),hl
	ei

	;--- Establecemos el nuevo H_TIMI

	if	USETIMI=1 then

	di
	ld	a,#C3
	ld	(H_TIMI),a
	ld	hl,(P3_P3DIR0022-P3_START0022+#B000+1)	;(P3_P3DIR)
	ld	(H_TIMI+1),hl
	ei

	endif

	ret


;--- Subrutina de reubicacion de un codigo
;    Entrada: HL = Primera copia
;             DE = Segunda copia
;             IX = Destino teorico
;             IY = Destino real
;             BC = Longitud

REUBICA:	push	iy,bc,de,hl	;Primero copiamos el codigo tal cual
	push	iy	;(HL a IY, lon. BC)
	pop	de
	ldir
	pop	hl,de

	push	de
	pop	iy	;IY = Segunda copia
	ld	b,h
	ld	c,l
	push	ix
	pop	hl
	or	a
	sbc	hl,bc
	ld	b,h
	ld	c,l	;BC = Distancia a sumar (IX - HL)

	exx
	pop	bc
	exx
	pop	ix	;Originalmente IY

	;En este punto: IX = Destino
	;               IY = Segunda copia
	;               BC = Distancia a sumar (nueva dir - 1a copia)
	;               BC'= Longitud

BUCLE:	ld	a,(ix)
	cp	(iy)
	jr	z,NEXT	;Si no hay diferencias pasamos al siguiente byte

	ld	l,a
	ld	h,(ix+1)	;HL = Dato a cambiar
	add	hl,bc	;HL = Dato cambiado
	ld	(ix),l	;IX = Direccion del dato a cambiar
	ld	(ix+1),h

	call	CHKCOMP
	jr	z,FINREUB	;Si: sacabo!

	inc	ix
	inc	iy
NEXT:	inc	ix	;Siguiente byte a comparar
	inc	iy	;(si hemos sutituido, hay que incrementar dos veces)
	call	CHKCOMP
	jr	nz,BUCLE

FINREUB	ret

CHKCOMP:	exx
	dec	bc	;Decrementamos contador, y si llega a 0
	ld	a,b	;volvemos con Z=1
	or	c
	exx
	ret


;--- GET_STRING: Devuelve una cadena asociada a un numero, o "Unknown".
;    Entrada: DE = Puntero a la tabla de cadenas y numeros, con el formato:
;                  db num,"Cadena$"
;                  db num2,"Cadena2$"
;                  db 0
;             B = Numero asociado
;    Salida:  DE = Cadena

GET_STRING:	ld	a,(de)
	inc	de
	or	a	;No encontramos el codigo: mostramos "Unknown"
	jr	nz,LOOP_REA2

	ld	a,b
	ld	ix,CODEUNK_S
	call	BYTE2ASC
	ld	(ix),")"
	ld	(ix+1),"$"
	ld	de,REAUNK_S
	ret

LOOP_REA2:	cp	b	;Coincide?
	ret	z

LOOP_REA3:	ld	a,(de)	;No: pasa al siguiente
	inc	de
	cp	"$"
	jr	nz,LOOP_REA3
	jr	GET_STRING

REAUNK_S:	db	"Unknown ("
CODEUNK_S:	db	"000)$"


;--- FIND_PARAM: Busca un parametro determinado
;    y devuelve su informacion asociada.
;    Entrada: A=Letra del parametro
;    Salida: A y HL listos para pasar a SET_PARAM
;            Cy=1 si no se encuentra el parametro

FIND_PARAM:	;or	32
	ld	b,a
	ld	hl,PAR_LIST

FINDP_LOOP:	ld	a,(hl)
	or	a
	scf
	ret	z

	cp	b
	inc	hl
	jr	z,FINDP_FOUND
	inc	hl
	inc	hl
	inc	hl
	jr	FINDP_LOOP

FINDP_FOUND:	ld	a,(hl)
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,c

	or	a
	ret

PAR_LIST:
	db	"E",1
	dw	REPLYECHO
	db	"P",4
	dw	BUF_IPDNS1
	db	"T",1
	dw	TTL
	db	"O",1
	dw	TOS
	db	"L",4
	dw	BUF_IPLOCAL
	db	"S",4
	dw	BUF_IPDNS2
	db	"Z",2
	dw	PING_SIZE
	db	"G",4
	dw	DEFGW
	db	"M",4
	dw	SUBNET_MASK
	db	"D",2
	dw	DHCP_VECT
	db	0


;--- SET_PARAM: Establece un parametro de INL con el valor
;    que hay almacenado en PARBUF+3.
;    Entrada: A=1 si es byte, 2 si es word, 4 si es una IP
;             otro: cadena (indica long maxima)
;             HL=Dir donde copiar el parametro
;    Salida:  Cy=1 si parametro invalido
;    Supone que el seg de datos de INS esta en pag. 2

SET_PARAM:	cp	1
	jr	z,SETPARAM_B
	cp	2
	jr	z,SETPARAM_W
	cp	4
	jr	z,SETPARAM_I

	;--- Es una cadena: mide longitud

	ld	b,a	;Tamanyo max+1
	inc	b
	ld	c,-1	;Tamanyo real
	ld	de,PARBUF+2
MIDELON:	inc	de
	inc	c
	ld	a,(de)
	or	a
	jr	nz,MIDELON

	ld	a,c	;Demasiado largo?
	cp	b
	ccf
	ret	c

	ld	b,0
	inc	bc	;Para incluir el 0 final
	ex	de,hl
	ld	hl,PARBUF+3	;Copia parametro
	ldir

	or	a
	ret

	;--- Es 1 byte

SETPARAM_B:	push	hl
	ld	hl,PARBUF+3
	call	EXTNUM8
	pop	hl
	ret	c

	ld	(hl),a
	or	a
	ret

	;--- Es 2 bytes

SETPARAM_W:	push	hl
	ld	hl,PARBUF+3
	call	EXTNUM16
	pop	hl
	ret	c

	ld	(hl),c
	inc	hl
	ld	(hl),b
	or	a
	ret

	;--- Es una IP

SETPARAM_I:	push	hl
	call	PARSE_IP
	pop	de
	ret	c

	ld	hl,PARSED_IP
	ld	bc,4
	ldir

	or	a
	ret


;--- PARSE_IP: Extrae una direccion IP a partir de una cadena
;    Entrada:  Cadena en PARBUF+3, acabada en 0
;    Salida:   Cy=0 y IP en PARSED_IP, o Cy=1 si no es una IP valida
;	En cualquier caso vuelve con la cadena acabada en 0

PARSE_IP:	ld	hl,PARBUF+3
PARSE_IPL:	ld	a,(hl)
	or	a
	jr	z,PARSE_IP2	;Pone punto al final para facilitar procesado
	inc	hl
	jr	PARSE_IPL
PARSE_IP2:	ld	(hl),"."
	ld	(PARSE_IPDIR),hl

	ld	de,PARSED_IP
	ld	hl,PARBUF+3
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

	or	a
	jr	PARSE_IPEND

ERRIP:	pop	de,bc
	scf

PARSE_IPEND:	ld	hl,(PARSE_IPDIR)
	ld	(hl),0
	ret

PARSE_IPDIR:	dw	0
PARSED_IP:	ds	4


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

	;Rutinas de soporte del mapeador

_ALL_SEG:	ds	3
_FRE_SEG:	ds	3
_RD_SEG:	ds	3
_WR_SEG:	ds	3
_CAL_SEG:	ds	3
_CALLS:	ds	3
_PUT_PH:	ds	3
_GET_PH:	ds	3
_PUT_P0:	ds	3
_GET_P0:	ds	3
_PUT_P1:	out	(#FD),a
	ret
_GET_P1:	in	a,(#FD)
	ret
_PUT_P2:	out	(#FE),a
	ret
_GET_P2:	in	a,(#FE)
	ret
_PUT_P3:	ds	3
_GET_P3:	ds	3


;--- POR60_32: Multiplica un numero de 32 bits por 60
;    Entrada: IX = Puntero al numero (big-endian)

POR60_32:	push	ix
	pop	hl
	ld	de,NUMBUF
	ld	bc,4
	ldir

	;* Multiplica por 64

	ld	b,6
	call	MULT32B

	;* Multiplica el original por 4

	push	ix
	ld	ix,NUMBUF
	ld	b,2
	call	MULT32B
	pop	ix

	;* Resta el multiplicado por 4 del multiplicado por 64 y termina

	ld	iy,NUMBUF

	ld	h,(ix+2)
	ld	l,(ix+3)
	ld	d,(iy+2)
	ld	e,(iy+3)
	or	a
	sbc	hl,de
	ld	(ix+2),h
	ld	(ix+3),l

	ld	h,(ix)
	ld	l,(ix+1)
	ld	d,(iy)
	ld	e,(iy+1)
	sbc	hl,de	;Usa el carry de la anterior operacion
	ld	(ix),h
	ld	(ix+1),l

	ret

	;* Rutina generica de multiplicacion de (IX) por 2^B

MULT32B:	ld	d,(ix)
	ld	e,(ix+1)
	ld	h,(ix+2)
	ld	l,(ix+3)

MULT32_LOP:	add	hl,hl
	ex	de,hl
	adc	hl,hl
	ex	de,hl
	djnz	MULT32_LOP

	ld	(ix),d
	ld	(ix+1),e
	ld	(ix+2),h
	ld	(ix+3),l
	ret

NUMBUF:	ds	4


;--- Rutinillas

MISSPAR:	print	MISSPAR_S
	jp	FIN

INVPAR:	print	INVPAR_S
	jp	FIN

NOFILE:	print	NOFILE_S
	jp	FIN

FNOTF:	print	FNOTF_S
	jp	FIN


;===================================
;===  Rutinas de acceso a disco  ===
;===================================

;--- READ_LINE: Lee una linea de texto desde el fichero en FH
;               a #81. Deja la longitud leida en #80.
;    Al final, (#80)=0 si no se ha podido leer nada.

READ_LINE:	xor	a
	ld	(#80),a
	ld	a," "
	ld	(#81),a

	;--- Se salta espacios, tabs, CRLFs iniciales

RL_SKIPINIT:	ld	hl,1	;Lee un caracter
	ld	de,DUMMY
	ld	a,(FH)
	ld	b,a
	call	READ

	ld	a,b
	or	c	;Lo ha podido leer?
	ret	z

	ld	a,(DUMMY)	;Era EOF?
	cp	#1A
	ret	z

	cp	" "
	jr	z,RL_SKIPINIT
	cp	9
	jr	z,RL_SKIPINIT
	cp	10
	jr	z,RL_SKIPINIT
	cp	13
	jr	z,RL_SKIPINIT
	cp	";"	;Comentario: descartar toda la linea
	jr	z,RL_ISCOMM
	cp	"#"	;Comentario
RL_ISCOMM:	push	af
	call	z,SKIP_LINE
	pop	af
	jr	z,RL_SKIPINIT

	;--- Aqui hemos leido ya un caracter correcto.
	;    Lee hasta 125 caracteres mas.

	ld	(#82),a	;Guarda el 1er caracter valido leido
	ld	b,2	;Cuenta el espacio inicial y el caracter ya leido
	ld	de,#83
RL_LOOP:	push	bc,de
	ld	hl,1
	ld	a,(FH)
	ld	b,a
	call	READ
	ld	a,b
	or	c
	pop	de,bc

	jr	z,RL_LOOP_END
	ld	a,(de)
	cp	#1A
	jr	z,RL_LOOP_END
	cp	13
	jr	z,RL_LOOP_END

	inc	de
	inc	b
	ld	a,b
	cp	126
	jr	c,RL_LOOP
	push	bc,de
	call	SKIP_LINE
	pop	de,bc

	;--- Linea completa

RL_LOOP_END:	xor	a
	ld	(de),a
	ld	a,b
	inc	a
	ld	(#80),a	;Longitud en #80
	ret

	;--- Se salta una linea completa
	;    (demasiado larga o comentario)

SKIP_LINE:	ld	hl,1	;Lee un caracter
	ld	de,DUMMY
	ld	a,(FH)
	ld	b,a
	call	READ
	ld	a,b
	or	c
	ret	z

	ld	a,(DUMMY)
	cp	13
	ret	z
	cp	#1A
	ret	z
	jr	SKIP_LINE

DUMMY:	db	0


;--- NOMBRE: MIN2MAY
;      Convierte un caracter a mayuscula
;    ENTRADA:   A = Caracter
;    SALIDA:    A = Caracter en mayuscula si era minuscula,
;                   inalterado si no
;    REGISTROS: F

MIN2MAY:	cp	ENYEMIN
	jp	nz,NOENYE
	ld	a,ENYEMAY
	ret
NOENYE:	cp	"a"
	ret	c
	cp	"z"+1
	ret	nc
	and	%11011111
	ret


;--- NOMBRE: CONVNAME
;      Convierte un nombre de fichero de/a formato FCB
;      NO comprueba caracteres invalidos en el nombre del fichero
;    ENTRADA:    HL = Cadena de origen
;                     Formato FCB:    12 caracteres, sin punto
;                                     (los sobrantes se rellenan con espacios)
;                                     El primero es la unidad
;                                     (0: defecto, 1: A, 2: B, etc)
;                     Formato normal: Acabada en 0, maximo 14 caracteres
;                                     Comienza con la unidad y ":"
;                                     si no es la idem por defecto (la 0)
;                DE = Cadena de destino (idem)
;                Cy = 0 -> Formato normal a FCB
;                Cy = 1 -> Formato FCB a normal
;     SALIDA:    B  = Longitud de la cadena de destino
;                     Formato FCB: siempre 12
;                     Formato normal: no incluye el 0 final
;     REGISTROS: AF, C

CONVNAME:	push	de,hl
	jp	c,FCB2NOR
	xor	a
	ld	(EXTFLG),a
	jp	NOR2FCB
ENDCONV:	pop	hl,de
	ret

;--- Conversion nombre normal a nombre FCB

NOR2FCB:	push	de,hl,de	;Rellena de espacios la zona del nombre
	pop	hl
	inc	de
	ld	a," "
	ld	(hl),a
	ld	bc,11
	ldir
	pop	hl,de
	xor	a
	ld	(de),a	;Pone a 0 la unidad

	inc	hl	;Comprueba si se ha especificado unidad.
	ld	a,(hl)	;Si es asi, la convierte al numero
	cp	":"	;de unidad correspondiente.
	jp	nz,NOUN1
	dec	hl
	ld	a,(hl)
	call	MIN2MAY
	sub	"A"-1
	ld	(de),a
	inc	hl
	inc	hl
	inc	hl

NOUN1:	inc	de
	dec	hl
	xor	a	;Bucle para el nombre
	ld	(EXTFLG),a
	ld	b,8
	call	N2FBUC

	ld	a,(EXTFLG)	;Si se ha llegado al final, no procesa
	or	a	;la extension
	jp	nz,ENDCONV
	ld	a,#FF
	ld	(EXTFLG),a
	ld	b,3	;Bucle para la extension
	call	N2FBUC
	ld	b,12
	jp	ENDCONV
;                                   ;Pasa sin convertir los 8 o 3 primeros
N2FBUC:	ld	a,(hl)	;caracteres, a no ser que encuentre
	inc	hl
	cp	"*"	;un 0 (fin de cadena),
	jp	z,AFND1	;un punto (fin de nombre),
	cp	"."	;o un asterisco (que convierte en "?")
	jp	z,PFND1
	or	a
	jp	z,EFND1
	call	MIN2MAY
	ld	(de),a
	inc	de
	djnz	N2FBUC

PASASOB:	ld	a,(EXTFLG)	;Si es la extension no hay nada que pasar
	or	a
	ret	nz

	ld	a,(hl)	;Pasa caracteres sobrantes (mas alla de 8
	inc	hl	;o 3) en el nombre del fichero
	or	a
	jp	z,EFND1
	cp	"."
	jp	nz,PASASOB
	ret

AFND1:	ld	a,"?"	;Rellena de "?" hasta completar
AFND11:	ld	(DE),a	;8 o 3 caracteres
	inc	DE
	djnz	AFND11
	jp	PASASOB

PFND1:	ld	a,(EXTFLG)
	or	a
	jp	nz,EFND1
	ld	a,b
	cp	8	;Si el punto esta al principio,
	dec	hl
	jp	z,AFND1	;interpreta "*.<ext>"
	inc	hl
	ld	a," "	;Rellena de " " hasta completar
PFND11:	ld	(DE),a	;8 o 3 caracteres
	inc	de
	djnz	PFND11
	ret

EFND1:	ld	a,1
	ld	(EXTFLG),a
	ret

EXTFLG:	db	0	;#FF cuando se procesa la extension, 
;                                   ;1 cuando se ha llegado al final

;--- Conversion nombre FCB a nombre normal

FCB2NOR:	push	de
	ld	a,(hl)
	or	a
	jp	z,NOUN2
	add	"A"-1
	ld	(de),a
	inc	de
	ld	a,":"
	ld	(de),a
	inc	de

NOUN2:	inc	hl
	ld	b,8	;Vamos copiando el nombre tal cual
F2NBUC:	ld	a,(hl)	;hasta que pasamos ocho caracteres
	inc	hl	;o encontramos un espacio...
	cp	" "
	jp	z,SPFND
	ld	(de),a
	inc	de
	djnz	F2NBUC
	ld	a,"."
	ld	(de),a
	inc	de
	jp	F2NEXT

SPFND:	ld	a,"."	;...entonces ponemos el punto,
	ld	(de),a	;y pasamos los espacios sobrantes
	inc	de	;hasta llegar a la extension.
SFBUC:	ld	a,(hl)
	inc	hl
	djnz	SFBUC
	dec	hl

F2NEXT:	ld	b,3	;Copiamos la extension hasta haber
F2NEX2:	ld	a,(hl)	;copiado tres caracteres,
	inc	hl	;o hasta encontrar un espacio.
	cp	" "
	jp	z,F2NEND
	ld	(de),a
	inc	de
	djnz	F2NEX2

F2NEND:	dec	de	;Si no hay extension, suprimimos el punto.
	ld	a,(de)
	cp	"."
	jp	z,NOPUN
	inc	de
NOPUN:	xor	a
	ld	(de),a

	ex	de,hl	;Obtencion de la longitud de la cadena.
	pop	de
	or	a
	sbc	hl,de
	ld	b,l
	jp	ENDCONV

;--- NOMBRE: OPEN
;      Abre un fichero
;    ENTRADA:   DE = Fichero a abrir
;    SALIDA:    A  = 0 -> Error
;               A <> 0 -> Error
;                         DOS 1: A=1 -> demasiados ficheros abiertos
;               B  = Numero asociado al fichero
;                    (no tiene nada que ver con el numero de ficheros abiertos)
;    REGISTROS: F, C

OPEN:	ld	a,(DOS2)
	or	a
	jp	nz,OPEN2

	;--- OPEN: Version DOS 1

OPEN1:	ld	a,(NUMFILES)
	cp	MAXFILES
	ld	a,1
	ret	nc

	push	hl,de,ix,iy
	ld	b,MAXFILES
	ld	hl,FCBS
	push	de
	ld	de,38
OP1BUC1:	ld	a,(hl)	;Buscamos, en todos los FCBs,
	or	a	;alguno que este libre.
	jp	z,FCBFND
	add	hl,de
	djnz	OP1BUC1
	ld	a,1
	jp	OP1END

FCBFND:	push	hl	;Limpiamos FCB
	pop	de
	push	de
	inc	de
	ld	bc,37
	ld	(hl),0
	ldir

	pop	de
	inc	de
	pop	hl	;Pasamos el nombre del fichero al FCB
	or	a
	call	CONVNAME

	push	de
	ld	c,_FOPEN
	call	DOS
	pop	ix
	or	a	;Terminamos si hay error
	jp	nz,OP1END

	ld	a,1
	ld	(ix+14),a	;Ponemos a 1 "record size"
	xor	a
	ld	(ix+15),a
	ld	(ix+33),a	;Ponemos a 0 "random record"
	ld	(ix+34),a
	ld	(ix+35),a
	ld	(ix+36),a

	ld	a,#FF	;Marcamos el FCB como usado
	ld	(ix-1),a

	ld	a,(NUMFILES)	;Incrementamos el numero
	inc	a	;de ficheros abiertos y
	ld	(NUMFILES),a	;devolvemos en A el numero de este
	ld	b,a
	xor	a

OP1END:	pop	iy,ix,de,hl
	ret

	;--- OPEN: Version DOS 2

OPEN2:	push	hl,de
	xor	a
	ld	c,_OPEN
	call	DOS
	or	a
	jp	nz,OP2END
	ld	a,(NUMFILES)
	inc	a
	ld	(NUMFILES),a
	xor	a
OP2END:	pop	de,hl
	ret


;--- NOMBRE: CLOSE
;      Cierra un fichero
;    ENTRADA:   B  = Numero de fichero
;    SALIDA:    A  = 0 -> Fichero cerrado
;               A <> 0 -> Error
;    REGISTROS: F

CLOSE:	ld	a,(DOS2)
	or	a
	jp	nz,CLOSE2

	;--- CLOSE: Version DOS 1

CLOSE1:	ld	a,b	;Error si B>MAXFILES
	cp	MAXFILES+1	;o B=0.
	ld	a,2
	ret	nc
	ld	a,b
	or	a
	ld	a,2
	ret	z

	push	bc,de,hl,ix,iy
	ld	hl,FCBS
	ld	de,38
	or	a
	sbc	hl,de
CL1BUC1:	add	hl,de	;HL = Zona en FCBS del fichero B
	djnz	CL1BUC1

	ld	a,(hl)	;Error si el fichero no esta abierto
	or	a
	ld	a,2
	jp	z,ENDCL1

	inc	hl
	ex	de,hl	;DE = FCB del fichero
	push	de
	ld	c,_FCLOSE
	call	DOS
	pop	ix
	or	a
	jp	nz,ENDCL1

	ld	a,(NUMFILES)
	dec	a
	ld	(NUMFILES),a
	xor	a	;Marcamos el FCB como libre
	ld	(ix-1),a

ENDCL1:	pop	iy,ix,hl,de,bc
	ret

	;--- CLOSE: Version DOS 2

CLOSE2:	push	bc,de,hl
	ld	c,_CLOSE
	call	DOS
	or	a
	jp	nz,ENDCL2
	ld	a,(NUMFILES)
	dec	a
	ld	(NUMFILES),a
	xor	a
ENDCL2:	pop	hl,de,bc
	ret


;--- NOMBRE: READ
;      Lee de un fichero abierto
;    ENTRADA:   B  = Numero de fichero
;               DE = Direccion del bufer
;               HL = Numero de bytes a leer
;    SALIDA:    A  = 0 -> No hay error
;               A <> 0 -> Error
;                         Se considera error no haber podido leer
;                         todos los bytes requeridos, es decir,
;                         HL a la entrada <> HL a la salida.
;                         Este error tiene el codigo A=1
;                         tanto en DOS 1 como en DOS 2.
;               HL = Numero de bytes leidos
;    REGISTROS: F

READ:	ld	a,(DOS2)
	or	a
	jp	nz,READ2

	;--- READ: Version DOS 1 

READ1:	ld	a,_RDBLK
	ld	(RWCODE),a
	jp	RW1

	;--- READ: Version DOS 2 

READ2:	ld	a,_READ
	ld	(RWCODE),a
	jp	RW2


;--- NOMBRE: WRITE
;      Escribe en un fichero abierto
;    ENTRADA:   B  = Numero de fichero
;               DE = Direccion del bufer
;               HL = Numero de bytes a escribir
;    SALIDA:    A  = 0 -> No hay error
;               A <> 0 -> Error
;                         Se considera error no haber podido escribir
;                         todos los bytes requeridos, es decir,
;                         HL a la entrada <> HL a la salida.
;                         Este error tiene el codigo A=1
;                         tanto en DOS 1 como en DOS 2.
;               HL = Numero de bytes escritos
;    REGISTROS: F
;    LLAMADAS:  CHKDOS2, RW1, RW2

WRITE:	ld	a,(DOS2)
	or	a
	jp	nz,WRITE2

	;--- WRITE: Version DOS 1

WRITE1:	ld	a,_WRBLK
	ld	(RWCODE),a
	jp	RW1

	;--- WRITE: Version DOS 2

WRITE2:	ld	a,_WRITE
	ld	(RWCODE),a
	jp	RW2


;--- RW: Rutina generica de lectura/escritura

	;--- RW: Version DOS 1

RW1:	ld	a,b
	cp	MAXFILES+1
	ld	a,1
	ret	nc
	ld	a,b
	or	a
	ld	a,2
	ret	z

	push	bc,de,ix,iy
	push	hl,de
	ld	hl,FCBS
	ld	de,38
	or	a
	sbc	hl,de
RW1BUC1:	add	hl,de	;HL = Zona en FCBS del fichero B
	djnz	RW1BUC1
	ld	a,(hl)	;A = Identificador de fichero abierto
	ex	(sp),hl
	push	hl

	or	a	;Error si el fichero no esta abierto
	ld	a,2
	jp	z,ENDRW11

	pop	de
	ld	c,_SETDTA
	call	DOS
	pop	de,hl
	inc	de
	ld	a,(RWCODE)	;Leemos el codigo de lectura o escritura
	ld	c,a
	call	DOS	;y ejecutamos la llamada

ENDRW1:	pop	iy,ix,de,bc
	ret
ENDRW11:	pop	bc,bc,bc
	jp	ENDRW1

	;--- RW: Version DOS 2

RW2:	;push	bc,de,hl
	ld	a,(RWCODE)	;Leemos el codigo de lectura o escritura
	ld	c,a
	call	DOS
	ret		;*** PRUEBAS: Devuelve el error real, no el 1

	pop	de
	or	a
	jp	nz,ENDRW2
	push	hl

	sbc	hl,de	;HL = bytes leidos, DE = bytes requeridos
	ld	a,h	;Si HL=DE, no hay error
	or	l	;Si HL<>DE, error 1
	ld	a,0
	pop	hl
	jp	z,ENDRW2
	ld	a,1

ENDRW2:	pop	de,bc
	ret

RWCODE:	db	0	;Codigo de la funcion de lectura/escritura


;=====================================
;===  Rutinas para buscar ObsoNET  ===
;=====================================

	;SRCHOBSO - Rutina de bzsqueda de ObsoNET - por Nistor Soriano
	;ObsoNET (c) 2004
	;por Daniel Berdugo (hardware) y Nistor Soriano (software)
	;
	;Entrada: -
	;Salida:  A  = Slot de ObsoNET (#FF si no se encuentra)
	;         Cy = 1 si la ObsoNET tiene BIOS
	;         ObsoNET conectada en pagina 1
	;         (si no se encuentra, zltimo slot disponible conectado)

SRCHOBSO:
	ld	a,#FF	;Inicializa la rutina NEXTSLOT
	ld	(NEXTSL),a

SRCHLOOP:
	call	NEXTSLOT	;Obtiene siguiente slot disponible...
	cp	#FF	;(si no quedan slots, terminar)
	ret	z

	push	af
	ld	h,#40	;...y lo conecta.
	call	ENASLT
	pop	af

	ld	c,a
	call	CHKOBNET	;Comprueba si hay ObsoNET...
	jr	nc,SRCHLOOP	;...y si no, pasa al siguiente slot.

	call	CHKBIOS	;Comprueba si hay BIOS y termina.
	ld	a,c
	ret


;--- Comprobacisn de la presencia de una ObsoNET en la pagina 1.
;    Entrada:  -
;    Salida:   Cy = 1 si en la pagina 1 hay una ObsoNET, 0 si no
;    Modifica: AF, B

CHKOBNET:
	ld	a,(#7FE0)	;Guarda valor para restaurarlo
	ld	b,a	;si no hay una ObsoNET

	xor	a		;Conecta banco 0
	ld	(#7FE0),a

	ld	a,(#7FEA)	;Lee registros 10 y 11 (8019ID0/1),
	cp	#50	;deben devolver #50 y #70 respectivamente
	jr	nz,NO_OBNET
	ld	a,(#7FEB)
	cp	#70
	jr	nz,NO_OBNET

	ld	a,#80		;Conecta banco 2
	ld	(#7FE0),a

	ld	a,(#7FEA)	;Lee registros 10 y 11 (no usados,
	cp	#50	;NO deben devolver #50 y #70)
	scf
	ret	nz
	ld	a,(#7FEB)
	cp	#70
	scf
	ret	nz

NO_OBNET:
	ld	a,b	;No hay ObsoNET: restaura contenido
	ld	(#7FE0),a	;de #7FE0 por si es RAM
	or	a
	ret


;--- Comprobacion de la presencia de BIOS en la ObsoNET de pagina 1.
;    Entrada:  -
;    Salida:   Cy = 1 si hay BIOS, 0 si no
;    Modifica: AF, HL, DE

CHKBIOS:
	ld	a,#C0	;Conecta pagina 0 de la ROM
	ld	(#7FE0),a
	xor	a
	ld	(#7FE2),a

	ld	hl,#7FD0
	ld	de,OBSTRING

CHKBLOOP:	;Bucle de comparacion de cadenas
	ld	a,(de)
	cp	(hl)
	scf
	ccf
	ret	nz

	or	a
	scf
	ret	z

	inc	hl
	inc	de
	jr	CHKBLOOP

OBSTRING:
	db	"ObsoNET",0


;--- Subrutina NEXTSLOT:
;    Devuelve en A el siguiente slot disponible cada vez que es llamada.
;    Cuando ya no quedan slots devuelve #FF.
;    Para incializarla hay que escribir #FF en NEXTSL.
;    Modifica: AF, BC, HL

NEXTSLOT:
	ld	a,(NEXTSL)
	cp	#FF
	jr	nz,NXTSL1
	ld	a,(EXPTBL)	;Primer slot
	and	%10000000
	ld	(NEXTSL),a
	ret

NXTSL1:
	ld	a,(NEXTSL)
	cp	%10001111
	jr	z,NOMORESL	;No hay mas slots?
	cp	%00000011
	jr	z,NOMORESL
	bit	7,a
	jr	nz,SLTEXP

SLTSIMP:
	and	%00000011	;Slot simple
	inc	a
	ld	c,a
	ld	b,0
	ld	hl,EXPTBL
	add	hl,bc
	ld	a,(hl)
	and	%10000000
	or	c
	ld	(NEXTSL),a
	ret

SLTEXP:
	ld	c,a	;Slot expandido
	and	%00001100
	cp	%00001100
	ld	a,c
	jr	z,SLTSIMP
	add	%00000100
	ld	(NEXTSL),a
	ret

NOMORESL:
	ld	a,#FF
	ret

NEXTSL:	db	#FF	;Ultimo slot devuelto


;*** Cadenas

FNOTF_S:	db	"*** Cannot open the specified file",13,10,"$"
NOFILE_S:	db	"*** Cannot execute this command from a configuration file",13,10,"$"
DSKE_S:	db	"*** Disk error",13,10,"$"
AST_S:	db	"*** $"
INLCFG_S:	db	"INL.CFG",0
PROGRAM_S:	db	"PROGRAM",0


;*******************
;***             ***
;***  VARIABLES  ***
;***             ***
;*******************

DOS2:	db	0
SEG1:	db	0
SEG2:	db	0
P3DIR:	dw	0
NEXTPAR:	db	0	;Proximo parametro a extraer
IS_FILE:	db	0	;#FF si leyendo parametros desde un fichero
IS_FILE_INS:	db	0	;idem, pero durante la instalacion
_OBSLOT:	db	0
_HWAD:	ds	6

UNKPAR_S:	db	"*** Unknown parameter",13,10,"$"
MISSPAR_S:	db	"*** Missing parameter(s)",13,10,"$"
INVPAR_S:	db	"*** Invalid parameter(s)",13,10,"$"

NUMFILES:	db	0
FH:	db	#FF

PARBUF2:	ds	128

FCBS:	;

INL_CODE:	;
