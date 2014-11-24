; InterNestor Lite for ObsoNET
; (superseded by InterNestor Lite for UNAPI)

; This is the resident part.
; Assemble the transient and the resident part,
; then concatenate both binaries and name the file INL.COM

;=========================================================

	;--- InterNestor Lite para ObsoNET 1.01
	;    Basado en InterNestor Lite para PPP+Fossil 0.4
	;    v1.0 Empezado el 29/6/2004
	;         (pero hecho casi todo el 23/8/2004)
	;    v1.02 Hecho 7/4/2005:
	;          - Reconoce paquetes Host Unreachable
	;            y cierra la conexion TCP asociada si la hay.
	;          - Anyadido el codigo 7 de causa de cierre
	;            de conexion TCP: "Destino inaccesible".

;*****************************
;***                       ***
;***  MACROS Y CONSTANTES  ***
;***                       ***
;*****************************

	.label	20

;*** MANUAL_MAC=1 para establecer la MAC a mano,
;               0 para leerla de la EEPROM
;    (se aplica solo si FLASH=0)

MANUAL_MAC:	equ	0

MANUAL_MAC0:	equ	#58	;"X"
MANUAL_MAC1:	equ	#53	;"S"
MANUAL_MAC2:	equ	#4D	;"M"
MANUAL_MAC3:	equ	0
MANUAL_MAC4:	equ	0
MANUAL_MAC5:	equ	34

;--- Version de INL

INL_VERSION1:	equ	1
INL_VERSION2:	equ	0
INL_VERSION3:	equ	2

;--- Puerto UDP para el resolver

DNS_PORT:	equ	#FFFE

;--- Variables de la zona de punteros (INL version <1.0)

;P3_ID:	equ	#F400
;P3_SEG1:	equ	#F402
;P3_SEG2:	equ	#F403
;P3_P3DIR:	equ	#F400

P3_SEG1:	equ	#7FF0
P3_SEG2:	equ	#7FF1


;--- Rutinas de la BIOS de ObsoNET

SEND_STATUS:	equ	#7FAF	;Estado del envio de un paquete
_SEND_PACKET:	equ	#7FB2	;Envia un paquete
_GET_PACKET:	equ	#7FB5	;Obtiene un paquete recibido
GET_INSTAT:	equ	#7FB8	;Comprueba si hay paquetes recibidos
CONF_MCAST:	equ	#7FBB	;Configura la direccion de multicast
CONF_RX:	equ	#7FBE	;Configura los parametros de recepcion
CARD_ONOFF:	equ	#7FC1	;Activa o desactiva la tarjeta
GET_NETSTAT:	equ	#7FC4	;Obtener el estado de la red (disponible o no)
GET_HWAD:	equ	#7FC7	;Obtener la direccion de la tarjeta
GET_VERS:	equ	#7FCA	;Obtener la version de la ROM
RTL_RESET:	equ	#7FCD	;Resetear la tarjeta

;--- Macro para llamar a una rutina de la BIOS de ObsoNET

obsonet:	macro	@d

	ld	iy,(OBSLOT-1)
	ld	ix,@d
	di
	call	CALSLT
	ei

	endm

;--- Valores iniciales de los temporizadores TCP

ACK_DELAY_V:	equ	6	;ACK retardado: 0.1 segundos
RTO_V:	equ	3	;Retransmisiones: 3 segundos
ZWP_V:	equ	10	;Prueba de ventana cero: 10 segundos
SEND_TOUT_V:	equ	30	;Envio de datos no PUSH: 0.5 segundos
UTOUT_DEF:	equ	3*60	;Temporizador de usuario por defecto: 3 minutos

;--- Estados TCP

CLOSED:	equ	0
LISTEN:	equ	1
SYN.SENT:	equ	2
SYN.RECEIVED:	equ	3
ESTABLISHED:	equ	4
FIN.WAIT.1:	equ	5
FIN.WAIT.2:	equ	6
CLOSE.WAIT:	equ	7
CLOSING:	equ	8
LAST.ACK:	equ	9
TIME.WAIT:	equ	10	;No usado (se pasa a CLOSED directamente)

;--- Tipos de mensajes DHCP

DHCPDISCOVER:	equ	1
DHCPOFFER:	equ	2
DHCPREQUEST:	equ	3
DHCPDECLINE:	equ	4
DHCPACK:	equ	5
DHCPNAK:	equ	6
DHCPRELEASE:	equ	7
DHCPINFORM:	equ	8

;--- Estados del automata DHCP

INIT:	equ	0
SELECTING:	equ	1
REQUESTING:	equ	2
BOUND:	equ	3
RENEWING:	equ	4
REBINDING:	equ	5
INFORMING:	equ	6	;Al enviar DHCPINFORM
CONFIGURED:	equ	7	;Tras recibir un ACK de DHCPINFORM

;--- Tamanyo tablas ARP y enrutamiento

ARP_ENTRIES:	equ	32
ROUTE_ENTRIES:	equ	16

;--- Variables y rutinas del sistema

RDSLT:	equ	#000C
WRSLT:	equ	#0014
CALSLT:	equ	#001C
ENASLT:	equ	#0024
EXPTBL:	equ	#FCC1
SYSTIMER:	equ	#FC9E


;************************
;***                  ***
;***  TABLA DE SALTO  ***
;***                  ***
;************************

	org	#4000

	;--- Interrupcion del reloj

	jp	TIME_INT

	;--- Manejo de slots y segmentos.
	;    Los JP 0 son establecidos por el programa instalador
	;    y apuntan a codigo situado en pag. 3

LDIRP3:	jp	0	;Conecta slot H, seg L en pag 1, y copia IX->IY lon BC
PUT_P1:	jp	0
GET_P1:	jp	0
PUT_P2:	jp	0
GET_P2:	jp	0
GETSLOT1:	jp	0
PUTSLOT1:	jp	0
GETSLOT2:	jp	_GETSLOT2
PUTSLOT2:	jp	_PUTSLOT2

	;--- Acceso al RS232. No se usan.

RS_IN:	ret
	ret
	ret
RS_OUT:	ret
	ret
	ret

RS_IN_STAT:	ret
	ret
	ret
RS_OUT_STAT:	ret
	ret
	ret

	;--- General, configuracion y codificaciones

VERS_PAUSE:	jp	_VERS_PAUSE
GET_VAR:	jp	_GET_VAR
SET_VAR:	jp	_SET_VAR
COPY_DATA:	jp	_COPY_DATA
IP_STRING:	jp	_IP_STRING
USER_MD5:	jp	_USER_MD5
USER_CHKSUM:	jp	_USER_CHKSUM
USER_B64INIT:	jp	B64_INIT
USER_B64ENC:	jp	_USER_B64ENC
USER_B64DEC:	jp	_USER_B64DEC

	;--- PPP, no se usan

SEND_MODEM:	ret
	ret
	ret
PPP_OPEN:	ret
	ret
	ret
PPP_CLOSE:	ret
	ret
	ret

	;--- ICMP

SEND_ECHO:	jp	_SEND_ECHO
RCV_ECHO:	jp	_RCV_ECHO

	;--- UDP

UDP_SEND:	jp	_UDP_SEND
UDP_RCV:	jp	_UDP_RCV

	;--- Resolver

DNS_Q:	jp	_DNS_Q
DNS_R:	jp	_DNS_R

	;--- TCP

TCP_OPEN:	jp	_TCP_OPEN
TCP_CLOSE:	jp	_TCP_CLOSE
TCP_ABORT:	jp	_TCP_ABORT
TCP_SEND:	jp	_TCP_SEND
TCP_RCV:	jp	_TCP_RCV
TCP_STATUS:	jp	_TCP_STATUS
TCP_FLUSH:	jp	_TCP_FLUSH

	;--- Envio y recepcion "raw" (como conyo se traduce eso??)
	;    Ya lo se! "En bruto".

RAW_SEND:	jp	_RAW_SEND
RAW_CONTROL:	jp	_RAW_CONTROL
RAW_RCV:	jp	_RAW_RCV

	;--- Otras

WAIT_INT:	jp	_WAIT_INT
NETWORK_STATE:	jp	_NETWORK_STATE

	;--- ObsoNET

ONET_INFO:	jp	_ONET_INFO
ETH2ASCII:	jp	_ETH2ASCII
ASCII2ETH:	jp	_ASCII2ETH
MASK2BITS:	jp	_MASK2BITS
BITS2MASK:	jp	_BITS2MASK
ARP_ROUTE:	jp	_ARP_ROUTE


;********************************
;***                          ***
;***  INTERRUPCION DEL RELOJ  ***
;***                          ***
;********************************

TIME_INT:

	;--- Establece slot y segmento de variables en pag. 2,
	;    llama a la rutina de interrupcion, y restaura pag. 2
	;    (ahora eso lo hace el codigo de pag. 3)

	;call    GETSLOT2
	;ld      b,a
	;ld      a,(#F344)
	;push    bc
	;call    PUTSLOT2
	;call    GET_P2
	;pop     bc
	;ld      c,a
	;push    bc
	;ld      a,(P3_SEG2)
	;call    PUT_P2
	;pop     bc
	;ld      (I_SEGP2),bc

	;call    _TIME_INT

	;ld      bc,(I_SEGP2)
	;push    bc
	;ld      a,c
	;call    PUT_P2
	;pop     bc
	;ld      a,b
	;ld      bc,(#F344-1)
	;call    PUTSLOT2
	;ret
_TIME_INT:	;

	;--- Si DISABLE_INT esta ON, no hacemos nada;
	;    en caso contrario lo activamos
	;    (esto previene la reentrada de otra interrupcion)

	ld	a,(DISABLE_INT)
	or	a
	ret	nz

	ld	a,#FF
	ld	(DISABLE_INT),a

	ld	a,(OBSLOT)	;Guarda pagina de ROM y conecta la 0
	ld	e,#C0
	ld	hl,#7FE0
	call	WRSLT
	ld	a,(OBSLOT)
	ld	hl,#7FE2
	call	RDSLT
	ld	(OBSOPAGE),a
	ld	a,(OBSLOT)
	ld	e,0
	ld	hl,#7FE2
	call	WRSLT

	call	TIME_INT2

	ld	a,(OBSLOT)	;Restaura pagina de ROM
	ld	e,#C0
	ld	hl,#7FE0
	call	WRSLT
	ld	a,(OBSLOT)
	ld	de,(OBSOPAGE)
	ld	hl,#7FE2
	call	WRSLT

	xor	a
	ld	(DISABLE_INT),a
	ret

OBSOPAGE:	db	0

TIME_INT2:

	;--- Obtiene dir MAC
	;    (por si se ha cambiado externamente)

	;obsonet GET_HWAD
	;ld      (HWAD),hl
	;ld      (HWAD+2),de
	;ld      (HWAD+4),bc


	;=========================================
	;===  Actualizacion de temporizadores  ===
	;=========================================

	;-------------------------------------------
	;---  Temporizador del estado de la red  ---
	;-------------------------------------------

	ld	a,(CHECK_NET)
	or	a
	jr	nz,DO_CHECK_NET

	ld	a,#FF
	ld	(NET_STATE),a
	jr	OK_NETTIMER

DO_CHECK_NET:	ld	hl,(NETSTAT_TIMER)
	dec	hl
	ld	(NETSTAT_TIMER),hl
	ld	a,h
	or	l
	jr	nz,OK_NETTIMER

	obsonet	GET_NETSTAT
	or	a
	jr	z,NETSTAT_0

NETSTAT_1:	ld	a,#FF
	ld	(NET_STATE),a
	jr	NETSTAT_OK

NETSTAT_0:	call	CLOSE_ALL_TCP
	xor	a
	ld	(NET_STATE),a
	ld	(PCAP_STATE),a

NETSTAT_OK:	ld	hl,10*60
	ld	(NETSTAT_TIMER),hl
OK_NETTIMER:


	;----------------------------------------
	;---  Temporizadores de la cache ARP  ---
	;----------------------------------------

	ld	ix,ARP_CACHE
	ld	b,ARP_ENTRIES
CHK_ARP_LOOP:	push	bc

	ld	a,(ix)
	cp	2
	jr	nz,NO_ARP_INUSE

	;* Entrada dinamica en uso:
	;  decrementa temporizador de expiracion de cache;
	;  si llega a 0, borra la entrada

CHK_ARP_TYPE2:	push	ix
	pop	hl
	ld	bc,11
	add	hl,bc
	push	hl,hl
	pop	bc
	call	DEC32
	pop	hl

	ld	de,ZERO32
	call	COMP32
	jr	nz,CHK_ARP_NXT

	;ld	(ix),3	;Pasa a estado 3
	;ld	(ix+11),1	;Pone el temp a 1 para que expire enseguida
	;ld	(ix+12),0	;0 paquetes enviados por ahora
	;jr	CHK_ARP_TYPE3
	ld	(ix),0
	jr	CHK_ARP_NXT

NO_ARP_INUSE:	cp	3
	jr	nz,CHK_ARP_NXT

	;* Entrada dinamica en resolucion:
	;  decrementa temporizador de reenvio (de 1 byte) si no es 0.
	;  Si llega a 0, reenvia un paquete ARP o borra la entrada
	;  si ya se han enviado 3 paquetes.

CHK_ARP_TYPE3:	ld	a,(ix+11)
	dec	a
	ld	(ix+11),a
	jr	nz,CHK_ARP_NXT

	ld	a,(ix+12)	;Si se han enviado ya 5 paquetes...
	cp	5
	jr	c,CHK_ARP_NODEL

	xor	a	;...borrar la entrada
	ld	(ix),a
	jr	CHK_ARP_NXT
CHK_ARP_NODEL:

	inc	a
	ld	(ix+12),a
	ld	a,2*60	;2 segundos entre envios
	ld	(ix+11),a

	ld	l,(ix+7)
	ld	h,(ix+8)
	ld	e,(ix+9)
	ld	d,(ix+10)

	push	ix
;	ld	a,(ix+1)	;Si la dir eth de la entrada es 0,
;	or	(ix+2)	;enviar el paquete a broadcast;
;	or	(ix+3)	;si no, enviar a esa dir eth.
;	ld	bc,ETH_BROAD	;(por simplicidad solo mira los
;	jr	z,SND_ARPRQ	;3 primeros bytes de la dir)
;	push	ix
;	pop	bc
;	inc	bc
	;ld      bc,ETH_BROAD
SND_ARPRQ:	call	SEND_ARP_RQ
	pop	ix

	;* Siguiente entrada, si quedan        

CHK_ARP_NXT:	ld	bc,16
	add	ix,bc
	pop	bc
	djnz	CHK_ARP_LOOP


	;----------------------------------------
	;---  Temporizador del automata DHCP  ---
	;----------------------------------------

	ld	a,(DHCP_VECT)
	or	a
	jp	z,TDHCP_OK

	ld	a,(DHCP_STATE)
	cp	CONFIGURED
	jp	z,TDHCP_OK

	;--- Estado INIT:
	;    Pasa a SELECTING o INFORMING, envia DHCPDISCOVER o DHCPINFORM,
	;    e inicializa el temporizador de retransmision

	ld	a,(DHCP_STATE)
	or	a	;cp INIT
	jr	nz,TDHCP_NOINIT

	call	DHCP_DO_INIT

	ld	a,(DHCP_VECT)	;SELECTING si requerimos IP, si no, INFORMING
	and	1
	jr	z,TDHCP_INIT0

	ld	a,SELECTING
	ld	(DHCP_STATE),a
	ld	a,DHCPDISCOVER
	jr	TDHCP_INIT1

TDHCP_INIT0:	ld	a,INFORMING
	ld	(DHCP_STATE),a
	ld	a,DHCPINFORM

TDHCP_INIT1:	call	SEND_DHCP
	call	DHCP_FIRST

	jp	TDHCP_OK
TDHCP_NOINIT:

	;--- Si el estado no es BOUND o CONFIGURED, actualiza SECS

	cp	BOUND
	jr	z,TDHCP_OKSECS
	cp	CONFIGURED
	jr	z,TDHCP_OKSECS

	ld	a,(DHCP_SECS_T)
	inc	a
	ld	(DHCP_SECS_T),a
	cp	60
	jr	c,TDHCP_OKSECS

	xor	a
	ld	(DHCP_SECS_T),a
	ld	hl,(DHCP_SECS)
	inc	hl
	ld	(DHCP_SECS),hl
TDHCP_OKSECS:

	;--- Actualiza temporizador de reenvios,
	;    y reenvia el paquete adecuado si expira

	ld	a,(DHCP_SNDTIM)
	dec	a
	ld	(DHCP_SNDTIM),a
	jr	nz,TDHCP_OKRETIM

	ld	a,(DHCP_STATE)
	cp	REQUESTING
	jr	nz,TDHCP_OKTRIES
	ld	a,(DHCP_TRIES)	;Si se han hecho 10 intentos
	cp	10	;en estado REQUESTING, volver a INIT
	jp	nc,TDHCP_OK2

TDHCP_OKTRIES:	ld	a,3*60
	ld	(DHCP_SNDTIM),a
	ld	hl,DHCP_TRIES
	inc	(hl)

	;* En estado SELECTING, reenviar DHCPDISCOVER

	ld	a,(DHCP_STATE)
	cp	SELECTING
	jr	nz,TDHCP_NOSEL

	ld	a,DHCPDISCOVER
	call	SEND_DHCP
	jr	TDHCP_OKRETIM
TDHCP_NOSEL:

	;* En estado INFORMING, reenviar DHCPINFORM

	ld	a,(DHCP_STATE)
	cp	INFORMING
	jr	nz,TDHCP_NOINF

	ld	a,DHCPINFORM
	call	SEND_DHCP
	jr	TDHCP_OKRETIM
TDHCP_NOINF:

	;* En estado REQUESTING, REBINDING o RENEWING, reenviar DHCPREQUEST

	cp	BOUND	;Todos los estados que quedan menos BOUND
	jr	z,TDHCP_OKRETIM
	ld	a,DHCPREQUEST
	call	SEND_DHCP
TDHCP_OKRETIM:

	;--- En estado BOUND, REBINDING o RENEWING, decrementar T1, T2 y LEASE.
	;    En estado RENEWING, decrementar T2 y LEASE.
	;    En estado REBINDING, decrementar LEASE.
	;    Sslo se decrementan si no son infinito.

	ld	a,(DHCP_STATE)
	cp	BOUND
	jr	z,TDHCP_DECT1
	cp	RENEWING
	jr	z,TDHCP_DECT2
	cp	REBINDING
	jr	z,TDHCP_DECLS
	jp	TDHCP_OK

TDHCP_DECT1:
	ld	a,(DHCP_T1)
	inc	a
	jr	z,TDHCP_DECT2
	ld	hl,DHCP_T1
	ld	bc,DHCP_T1
	call	DEC32

TDHCP_DECT2:
	ld	a,(DHCP_T2)
	inc	a
	jr	z,TDHCP_DECLS
	ld	hl,DHCP_T2
	ld	bc,DHCP_T2
	call	DEC32

TDHCP_DECLS:
	ld	a,(DHCP_LEASE)
	inc	a
	jr	z,TDHCP_OKDEC
	ld	hl,DHCP_LEASE
	ld	bc,DHCP_LEASE
	call	DEC32
TDHCP_OKDEC:

	;--- En estado BOUND, si T1 expira pasa a RENEWING
	;    y envia DHCPREQUEST, ademas inicializa SECS

	ld	a,(DHCP_STATE)
	cp	BOUND
	jr	nz,TDHCP_NORENEW

	ld	hl,DHCP_T1
	ld	de,ZERO32
	call	COMP32
	jr	nz,TDHCP_OK

	xor	a
	ld	(DHCP_SECS_T),a
	ld	hl,0
	ld	(DHCP_SECS),hl

	ld	a,RENEWING
	ld	(DHCP_STATE),a
	ld	a,DHCPREQUEST
	call	SEND_DHCP
	call	DHCP_FIRST
	jr	TDHCP_OK
TDHCP_NORENEW:

	;--- En estado RENEWING, si T2 expira pasa a REBINDING
	;    y envia DHCPREQUEST

	cp	RENEWING
	jr	nz,TDHCP_NOREBIND

	ld	hl,DHCP_T2
	ld	de,ZERO32
	call	COMP32
	jr	nz,TDHCP_OK

	ld	a,REBINDING
	ld	(DHCP_STATE),a
	ld	a,DHCPREQUEST
	call	SEND_DHCP
	call	DHCP_FIRST
	jr	TDHCP_OK
TDHCP_NOREBIND:

	;--- En estado REBINDING, si LEASE expira pasa a INIT

	cp	REBINDING
	jr	nz,TDHCP_OK

	ld	hl,DHCP_LEASE
	ld	de,ZERO32
	call	COMP32
	jr	nz,TDHCP_OK

TDHCP_OK2:	xor	a	;ld a,INIT
	ld	(DHCP_STATE),a
TDHCP_OK:


	;-------------------------------------------------
	;---  Temporizador de reenvio de paquetes DNS  ---
	;-------------------------------------------------

	ld	a,(DNS_STAT_P)	;Hay consulta en curso?
	cp	1
	jp	nz,END_DNS_TIM

	;* Ha expirado el temporizador total?
	;  En ese caso establecemos error 17

	ld	hl,(DNS_TTOUT)
	ld	a,h
	or	l
	dec	hl
	ld	(DNS_TTOUT),hl
	jr	nz,DNS_NOEXPTOT

	ld	a,3
	ld	(DNS_STAT_P),a
	ld	a,17
	ld	(DNS_STAT_S),a
	jp	END_DNS_TIM
DNS_NOEXPTOT:	;

	;* Ha expirado el temporizador de reenvio?

	ld	a,(DNS_TOUT)
	dec	a
	ld	(DNS_TOUT),a
	jp	nz,END_DNS_TIM

	;Temp. expirado: quedan reenvios?

	ld	a,(DNS_RETRY)
	cp	5
	jr	nz,DNS_RESEND

	;No quedan reenvios:
	;Si era el primario, probamos el secundario si lo hay.

	call	DNS_USE_SEC
	jr	nc,DNS_RESEND

	;No quedan reenvios y no era el DNS primario,
	;o era el primario pero no hay secundario:
	;Error 16

DNS_NOREPLY:	ld	a,3
	ld	(DNS_STAT_P),a
	ld	a,16
	ld	(DNS_STAT_S),a
	jp	END_DNS_TIM

	;* Reenvio de la peticion DNS

	;Composicion del paquete

DNS_RESEND:	ld	hl,(ID_DNS)	;Identificador
	inc	hl
	ld	(OUT_BUFFER+32),hl
	ld	(ID_DNS),hl

	ld	hl,#0001	;Recursion deseada, otros flags a 0
	ld	(OUT_BUFFER+34),hl

	ld	hl,#0100
	ld	(OUT_BUFFER+36),hl	;QDCOUNT
	ld	h,0
	ld	(OUT_BUFFER+38),hl	;ANCOUNT
	ld	(OUT_BUFFER+40),hl	;NSCOUNT
	ld	(OUT_BUFFER+42),hl	;ARCOUNT

	ld	hl,DNS_BUFFER	;Nombre a resolver
	ld	ix,OUT_BUFFER+44
	call	GET_SERV

	ld	(ix),0	;QTYPE y QCLASS
	ld	(ix+1),1	;(inet, dir. IP)
	ld	(ix+2),0
	ld	(ix+3),1

	;Envio del paquete

	inc	ix
	inc	ix
	inc	ix
	inc	ix
	push	ix
	pop	hl
	ld	bc,OUT_BUFFER+32
	or	a
	sbc	hl,bc
	push	hl
	pop	bc	;BC = Longitud paquete

	ld	ix,DNS_PORT
	ld	iy,53
	ld	hl,(DNS_IP)
	ld	de,(DNS_IP+2)
	call	SEND_UDP	;Envia el paquete

	;Actualizacion de variables

	ld	a,3*60
	ld	(DNS_TOUT),a	;Temporizador de reenvios
	ld	a,(DNS_RETRY)
	inc	a
	ld	(DNS_RETRY),a	;Un intento mas

END_DNS_TIM:	;


	;----------------------------------------------
	;---  Temporizadores de las conexiones TCP  ---
	;----------------------------------------------

	ld	a,(NET_STATE)
	or	a
	jr	z,END_TCP_TIM
	xor	a

	;* Bucle para todas las conexiones TCP

TCP_TIM_LOOP:	push	af
	ld	b,a
	call	GET_TCB_DIR
	ld	a,(hl)
	or	a
	jr	z,TCP_TIM_NEXT

	ld	a,b
	call	LOAD_TCB

	;* Temporizador de retransmision

	ld	hl,(RTO_T)
	ld	a,h
	or	l
	jr	z,RTO_TIM_OK
	dec	hl
	ld	(RTO_T),hl
RTO_TIM_OK:	;

	;* Temporizador de envio de ACK

	ld	a,(ACK_DELAY_T)
	or	a
	jr	z,ACK_TIM_OK
	dec	a
	ld	(ACK_DELAY_T),a
ACK_TIM_OK:	;

	;* Temporizador de usuario

	ld	hl,(USER_TOUT)
	ld	a,h
	or	l
	jr	z,USER_TIM_OK
	dec	hl
	ld	(USER_TOUT),hl
USER_TIM_OK:	;

	;* Temporizador de envio de datos no PUSH

	ld	hl,(SEND_TOUT)
	ld	a,h
	or	l
	jr	z,SEND_TOUT_OK
	dec	hl
	ld	(SEND_TOUT),hl
SEND_TOUT_OK:	;

	;* Siguiente conexion

	call	SAVE_TCB
TCP_TIM_NEXT:	pop	af
	inc	a
	cp	4
	jr	c,TCP_TIM_LOOP

END_TCP_TIM:	;

END_TIMERS:	;


	;=========================================================
	;===  Envio de un paquete pendiente de resolucion ARP  ===
	;=========================================================

	;--- Hay paquete pendiente?

	ld	a,(WOUT_BUFFER)
	or	a
	jr	z,SEND_WOUT_OK

	;--- Busca entrada

	ld	de,WOUT_IP	;Hay entrada?
	call	SRCH_ARP
	jr	c,SEND_WOUT_OK

	ld	a,(ix)	;No esta en resolucion?
	cp	3
	jr	z,SEND_WOUT_OK

	;--- Envia paquete

	push	ix
	ld	hl,WOUT_BUFFER
	ld	de,OUT_BUFFER+4
	ld	bc,576
	ldir

	pop	hl
	inc	hl
	ld	de,#0800
	call	SEND_PACKET

	xor	a	;Borra WOUT_BUFFER
	ld	(WOUT_BUFFER),a
SEND_WOUT_OK:


	;==============================================
	;===  Obtencion de un paquete desde la red  ===
	;==============================================

GET_PACKET:	obsonet	GET_INSTAT	;BC=long, HL=Eth-Type o long
	or	a
	jp	z,END_GET_PACK

	;--- Si hay un paquete, la red esta activa

	ld	a,#FF
	ld	(NET_STATE),a
	ld	de,5*60
	ld	(NETSTAT_TIMER),de

	;--- Si el paquete es >576 bytes, descartarlo

	ld	a,b
	and	%11111100
	jp	nz,END_GET_PACK
	ld	a,b
	or	c
	jp	z,END_GET_PACK

	push	hl,bc
	pop	hl

	ld	de,576+22+1	;Prevee cabecera IEEE802.3
	call	COMP	;NC si HL<DE
	pop	hl
	jr	nc,INSIZE_OK

	ld	hl,0	;Demasiado grande: descartarlo
	obsonet	_GET_PACKET
	jp	END_GET_PACK
INSIZE_OK:

	;--- Recogerlo en la direccion adecuada segun su tipo

	ld	de,1501
	call	COMP
	jr	nc,IN_IS_IEEE

	;* Es de tipo Ethernet 2

	ld	hl,IN_BUFFER-10
	obsonet	_GET_PACKET

	ld	(INBUF_SIZE),bc
	jr	IN_GET_OK

	;* Es de tipo IEEE802.3

IN_IS_IEEE:

	ld	hl,IN_BUFFER-18
	obsonet	_GET_PACKET

	push	bc
	pop	hl
	ld	bc,8
	or	a
	sbc	hl,bc
	ld	(INBUF_SIZE),hl

	ld	hl,IN_BUFFER-18+6
	ld	de,IN_BUFFER-10+6
	ld	bc,6
	ldir
	ld	hl,IN_BUFFER-18
	ld	de,IN_BUFFER-10
	ld	bc,6
	ldir
IN_GET_OK:

	;--- Comprueba que la dir HW sea realmente la nuestra
	;    o bien la de broadcast (por si se ha puesto
	;    modo promiscuo accidentalmente)

	ld	hl,HWAD
	ld	de,IN_BUFFER-10
	call	COMP32
	jp	nz,GETP_CHKBRO

	ld	hl,(HWAD+4)
	ld	de,(IN_BUFFER-10+4)
	call	COMP32
	jp	z,OK_GETP_HW

GETP_CHKBRO:	ld	hl,ETH_BROAD
	ld	de,IN_BUFFER-10
	call	COMP32
	jp	nz,END_GET_PACK

	ld	hl,(ETH_BROAD+4)
	ld	de,(IN_BUFFER-10+4)
	call	COMP32
	jp	nz,END_GET_PACK

OK_GETP_HW:	;


	;================================================
	;===  Proceso del paquete recibido:           ===
	;===  Comprobacion del protocolo del paquete  ===
	;================================================

	ld	hl,(IN_BUFFER+2)	;Ether-Type

	;--- Comprueba si el protocolo es conocido,
	;    si lo es salta a la parte adecuada del codigo

	ld	de,#0008
	call	COMP
	jp	z,IS_IP

	ld	de,#0608
	call	COMP
	jp	z,IS_ARP

	;--- Protocolo desconocido: lo ignoramos

	jp	END_GET_PACK


	;==============================
	;===  Paquete ARP recibido  ===
	;==============================

	;Algoritmo segun RFC826, "Packet Reception"

IS_ARP:	;--- Comprueba el hardware y el protocolo

	ld	hl,(IN_BUFFER+4)
	ld	de,#0100
	call	COMP
	jp	nz,END_GET_PACK

	ld	hl,(IN_BUFFER+6)
	ld	de,#0008
	call	COMP
	jp	nz,END_GET_PACK

	;--- Comprueba si el tamanyo de la dir HW es 0: paquete UNARP.
	;    En ese caso busca la entrada y la borra si no es estatica.

	ld	a,(IN_BUFFER+8)
	cp	6
	jr	z,NO_UNARP
	or	a
	jp	nz,END_GET_PACK	;Si no es 0 ni 6, es incorrecto

	ld	de,IN_BUFFER+18	;Busca entrada ARP...
	call	SRCH_ARP
	jp	c,END_GET_PACK

	ld	a,(ix)
	cp	1
	jp	z,END_GET_PACK

	ld	(ix),0	;...y si la encuentra, la borra
	call	END_GET_PACK	;si no es estatica.
NO_UNARP:

	;--- Si la IP de origen es 0, no cachea la direccion
	;    (clientes DHCP comprobando la direccion que se
	;    les acaba de asignar pueden enviar un ARP request
	;    con la IP del enviador a cero)

	ld	a,#FF
	ld	(MERGE_FLAG),a

	ld	hl,IN_BUFFER+18
	ld	de,ZERO32
	call	COMP32
	jr	z,IS_ARP_2

	;--- Comprueba si hay una entrada ARP para esa IP

	xor	a
	ld	(MERGE_FLAG),a

	ld	de,IN_BUFFER+18
	call	SRCH_ARP
	jr	c,NOTINCACHE

	;* Encontrada: actualiza dir MAC

	ld	a,#FF
	ld	(MERGE_FLAG),a

	ld	a,(ix)	;Si es estatica, no hace nada
	cp	1
	jp	z,NOUPTIMER

	push	ix
	pop	de
	inc	de
	ld	hl,IN_BUFFER+12
	ld	bc,6

	ldir
NOUPTIMER:

	;* Actualiza temporizador de expiracion

	ld	(ix),2	;Por si estaba en resolucion
	push	ix
	pop	hl
	ld	bc,11
	add	hl,bc
	ex	de,hl
	ld	hl,ARP_TOUT
	ld	bc,4
	ldir
NOTARPSTAT:
NOTINCACHE:

	;--- Si la IP requerida no es la nuestra, terminar ya

IS_ARP_2:	ld	hl,IN_BUFFER+28
	ld	de,BUF_IPLOCAL
	call	COMP32
	jp	nz,END_GET_PACK

	;--- Si la entrada no estaba en la tabla, anyadirla

	ld	a,(MERGE_FLAG)
	or	a
	jr	nz,OKMERGEARP

	call	GET_FREE_ARP

	ld	(ix),2	;Entrada dinamica

	push	ix	;Copia la MAC y la IP de una sentada
	pop	de
	inc	de
	ld	hl,IN_BUFFER+12
	ld	bc,10
	ldir

	ld	hl,ARP_TOUT	;Establece temp. de expiracion
	ld	bc,4
	ldir
OKMERGEARP:

	;--- Si el paquete era Request, enviar Reply

	ld	a,(IN_BUFFER+11)
	cp	1
	call	z,SEND_ARP_RP

	jp	END_GET_PACK

MERGE_FLAG:	db	0


	;===============================
	;===  Datagrama IP recibido  ===
	;===============================

IS_IP:	;

	;--- Primero comprobamos que llegue al tamanyo minimo:
	;    Eth1 Eth2 Type Cabecera(20)

	ld	hl,(INBUF_SIZE)
	ld	de,34
	call	COMP
	jp	nc,END_GET_PACK

	;--- Guardamos el tamanyo de la cabecera IP en OUT_BUFFER.
	;    Si es <20 bytes, ignoramos el paquete.

	ld	a,(IN_BUFFER+4)
	and	#0F
	cp	5
	jp	c,END_GET_PACK

	sla	a
	sla	a
	ld	l,a
	ld	h,0
	ld	(IP_HEADER_LEN),hl

	;--- Guardamos el tamanyo total del paquete en OUT_BUFFER+2.
	;    Si es >576 bytes, ignoramos el paquete.

	ld	a,(IN_BUFFER+6)
	ld	h,a
	ld	a,(IN_BUFFER+7)
	ld	l,a
	ld	de,577
	call	COMP
	jp	c,END_GET_PACK

	ld	(IP_TOTAL_LEN),hl

	;--- Calcula el checksum de la cabecera

	ld	a,(CHKVECT)
	and	%10
	jr	z,IPCHKSOK

	ld	ix,IN_BUFFER+4
	ld	bc,(IP_HEADER_LEN)
	call	CALC_CHKSUM
	ld	a,d
	or	e
	jp	nz,END_GET_PACK
IPCHKSOK:	;

	;--- Comprueba la direccion IP de destino,
	;    debe ser la nuestra o una de broadcast

	;* Es nuestra IP?

	ld	hl,IN_BUFFER+20
	ld	de,BUF_IPLOCAL
	call	COMP32
	jr	z,OK_IPDEST

	;* Es de broadcast? (Mascara OR dir = todo 1s?)

	ld	hl,SUBNET_MASK
	ld	de,IN_BUFFER+20
	ld	b,4
CHKIPBROAD2:	ld	a,(de)
	or	(hl)
	inc	a
	jp	nz,END_GET_PACK
	inc	hl
	inc	de
	djnz	CHKIPBROAD2
OK_IPDEST:

	;--- Comprobamos si hay que capturar el paquete

	ld	a,(PCAP_STATE)	;Captura solicitada?
	cp	1
	jr	nz,NO_PCAP

	ld	a,(PCAP_PROTO)	;Capturar todos?
	or	a
	jr	z,DO_PCAP

	ld	b,a	;El protocolo coincide?
	ld	a,(IN_BUFFER+13)
	ld	d,a
	cp	b
	jr	z,DO_PCAP
	ld	a,b

	cp	#FF	;Todos menos UDP, TCP e ICMP echo?
	jr	nz,NO_PCAP

	;Comprueba si es UDP, TCP o ICMP echo

	ld	a,d
	cp	6	;TCP
	jr	z,NO_PCAP
	cp	17	;UDP
	jr	z,NO_PCAP
	cp	1	;ICMP
	jr	nz,DO_PCAP

	ld	a,(IN_BUFFER+24)
	or	a	;ECHO Reply?
	jr	z,NO_PCAP
	cp	8	;ECHO request?
	jp	z,NO_PCAP

	;Capturamos el paquete

DO_PCAP:	ld	a,(IN_BUFFER+6)
	ld	b,a
	ld	a,(IN_BUFFER+7)
	ld	c,a
	ld	hl,IN_BUFFER+4
	ld	de,PCAP_BUFFER
	;ld	bc,(IN_BUFFER+2)
	ld	(PCAP_SIZE),bc
	ldir

	ld	a,2
	ld	(PCAP_STATE),a
	jp	END_GET_PACK

NO_PCAP:

	;--- Si el campo de version no tiene 4, ignoramos el datagrama

	ld	a,(IN_BUFFER+4)
	and	#F0
	cp	#40
	jp	nz,END_GET_PACK

	;--- Si es un fragmento de datagrama, lo ignoramos

	ld	hl,(IN_BUFFER+10)
	res	7,l	;Pone a 0 el bit no usado (previene futuras extensiones de IP)
	res	6,l	;Pone a 0 el bit DF. Desde ahora HL solo tiene DF y Frag. Off.
	ld	a,h	;Si MF o Fragment Offset son <>0,
	or	l	;es un fragmento: ignorarlo
	jp	nz,END_GET_PACK

	;--- Si el paquete contiene opciones, las descartamos
	;    (movemos los datos a la posicion IN_BUFFER+24)

	ld	hl,(IP_HEADER_LEN)	;HL = Long cabecera
	ld	de,20
	call	COMP
	jr	z,IPOPTOK

	ld	bc,IN_BUFFER+4
	add	hl,bc	;HL = Inicio de los datos
	ld	de,IN_BUFFER+24
	ld	bc,(IP_TOTAL_LEN)
	ldir

	ld	hl,(IP_TOTAL_LEN)	;Cambia el tamanyo
	ld	de,(IP_HEADER_LEN)	;del paquete para no incluir
	or	a	;las opciones IP
	sbc	hl,de	;HL = Long. sin cabeceras
	ld	de,20
	add	hl,de	;HL = Long. con cabecera sin opciones
	ld	a,h
	ld	(IN_BUFFER+6),a
	ld	a,l
	ld	(IN_BUFFER+7),a
	ld	(IP_TOTAL_LEN),hl
	ld	(IP_HEADER_LEN),de
IPOPTOK:

	;--- Sustituye el campo de tamanyo total del paquete
	;    por el tamanyo de los datos, y en little-endian

	ld	hl,(IP_TOTAL_LEN)
	ld	de,(IP_HEADER_LEN)
	or	a
	sbc	hl,de
	ld	(IN_BUFFER+6),hl

	;--- Decide accion segun protocolo transportado

	ld	a,(IN_BUFFER+13)
	cp	6
	jp	z,IS_TCP
	cp	17
	jp	z,IS_UDP
	cp	1
	jp	z,IS_ICMP

	;jp	END_GET_PACK	;Desconocido: ignoramos

	;Nota: las rutinas IS_xxx terminan siempre con JP END_GET_PACK

END_GET_PACK:	ld	a,(NET_STATE)	;Proceso de las conexiones TCP
	or	a
	ret	z

	jp	DO_TCP_PROCESS	;call

	ret		;*** PRUEBAS

	ld	a,(GOT_TCP)	;Si era TCP, intentamos coger otro
	or	a
	ret	z
	jp	GET_PACKET

GOT_TCP:	db	0


	;===============================
	;===  Mensaje ICMP recibido  ===
	;===============================

IS_ICMP:	;--- Comprueba el checksum

	ld	a,(CHKVECT)
	and	%10000
	jr	z,ICMPCHK_OK

	ld	ix,IN_BUFFER+24
	ld	bc,(IN_BUFFER+6)
	call	CALC_CHKSUM
	ld	a,d
	or	e
	jp	nz,END_GET_PACK
ICMPCHK_OK:	;

	;--- Comprobamos el tipo

	ld	a,(IN_BUFFER+24)
	or	a	;ECHO Reply?
	jr	z,IS_ICMP_EREP
	cp	3
	jp	z,IS_ICMP_HOSTUN
	cp	8	;ECHO request?
	jp	nz,END_GET_PACK	;Otro: lo ignoramos

	;--- ICMP Echo Request: Lo respondemos si REPLYECHO<>0

IS_ICMP_EREQ:	ld	a,(REPLYECHO)
	or	a
	jp	z,END_GET_PACK

	ld	hl,IN_BUFFER+24	;Copiamos el mensaje tal cual en la respuesta
	ld	de,OUT_BUFFER+24
	ld	bc,(IN_BUFFER+6)
	push	bc
	inc	bc	;Para que incluya el 0 de padding
	ldir

	xor	a
	ld	(OUT_BUFFER+24),a	;Cambia el tipo a "Echo reply"
	pop	bc
	ld	hl,0
	ld	(OUT_BUFFER+26),hl	;Borra checksum antiguo
	ld	ix,OUT_BUFFER+24
	call	CALC_CHKSUM
	ld	(OUT_BUFFER+26),de	;Establece nuevo checksum

	ld	hl,(IN_BUFFER+16)	;IP destino = el originador del mensaje
	ld	de,(IN_BUFFER+18)
	ld	bc,(IN_BUFFER+6)	;Longitud
	ld	a,1	;Protocolo = ICMP
	jp	SEND_IP

	;--- ICM Echo Reply: lo encolamos si no hay ya 4 encolados

IS_ICMP_EREP:	ld	a,(ICMPI_PINDEX)
	ld	b,a

	inc	b
	ld	ix,ICMPI_IP0-11
	ld	de,11
BUC_EREP1:	add	ix,de
	djnz	BUC_EREP1	;Ahora IX apunta a la zona de datos adecuada

	ld	a,(ICMPI_PINDEX)
	ld	b,a
	ld	a,(ICMPI_GINDEX)
	cp	b
	jr	nz,EREP_HAYSITIO

	ld	a,(ix)	;Indice GET = Indice PUT:
	or	(ix+1)	;Hay sitio si entrada vacia (IP=0),
	or	(ix+2)	;si no, terminamos.
	or	(ix+3)
	jp	nz,END_GET_PACK
EREP_HAYSITIO:			;

	ld	hl,(IN_BUFFER+16)
	ld	(ix),l
	ld	(ix+1),h
	ld	hl,(IN_BUFFER+18)
	ld	(ix+2),l
	ld	(ix+3),h
	ld	a,(IN_BUFFER+12)	;TTL
	ld	(ix+4),a
	ld	hl,(IN_BUFFER+28)	;Identificador (guardamos en L.E.)
	ld	(ix+5),h
	ld	(ix+6),l
	ld	hl,(IN_BUFFER+30)	;Numero de secuencia (guardamos en L.E.)
	ld	(ix+7),h
	ld	(ix+8),l
	ld	hl,(IN_BUFFER+6)	;Longitud de los datos
	ld	bc,8	;Resta long. cabecera ICMP
	or	a
	sbc	hl,bc
	ld	(ix+9),l
	ld	(ix+10),h

	ld	a,(ICMPI_PINDEX)	;Incrementa indice PUT
	inc	a	;saltando de 3 a 0
	and	%111
	ld	(ICMPI_PINDEX),a

	jp	END_GET_PACK

	;--- ICMP Destination Unreachable: si esta asociado a una
	;    conexion TCP, la abortamos con codigo 7

	;Nota: la cabecera del paquete causante de esta respuesta
	;ICMP esta en IN_BUFFER+32.

IS_ICMP_HOSTUN:	ld	a,(IN_BUFFER+9+32)
	cp	6	;Si el paquete causante no es TCP, ignorarlo
	jp	nz,END_GET_PACK

	ld	hl,(IN_BUFFER+20+28)
	ld	de,(IN_BUFFER+22+28)
	ld	a,(IN_BUFFER+24+28)
	ld	iyh,a
	ld	a,(IN_BUFFER+25+28)
	ld	iyl,a
	ld	a,(IN_BUFFER+26+28)
	ld	ixh,a
	ld	a,(IN_BUFFER+27+28)
	ld	ixl,a
	call	SEARCH_TCP
	cp	#FF	;Conexion asociada inexistente: terminar
	jp	z,END_GET_PACK

	call	LOAD_TCB
	xor	a	;Cierra la conexion con codigo 7
	ld	(TCP_STATE),a
	ld	a,7
	ld	(LAST_CLOSE),a
	call	SAVE_TCB

	jp	END_GET_PACK


	;==============================
	;===  Paquete UDP recibido  ===
	;==============================

IS_UDP:	;--- Comprueba checksum, excepto si CHKVECT dice lo contrario

	ld	a,(CHKVECT)
	and	%1000
	jp	z,OK_UDP_CHKSUM

	;* Para calcular el checksum, componemos la pseudo-cabecera
	;  justo antes de los datos, pisando la cabecera IP.
	;  Pero como el orden de los datos (palabras de 16 bits)
	;  no es importante para el calculo,
	;  aprovechamos que las direcciones IP y el campo de protocolo
	;  ya estan establecidos en la cabecera IP, y asi
	;  solo necesitamos establecer 0 donde estaba el TTL y la longitud UDP
	;  donde estaba el checksum IP.

	xor	a
	ld	(IN_BUFFER+12),a	;Campo TTL
	ld	hl,(IN_BUFFER+28)	;Long. UDP en el campo checksum IP
	ld	(IN_BUFFER+14),hl

	ld	hl,(IN_BUFFER+6)
	ld	bc,12	;Para que incluya pseudo-cabecera
	add	hl,bc
	push	hl
	pop	bc
	ld	ix,IN_BUFFER+12
	call	CALC_CHKSUM
	ld	a,d
	or	e
	jp	nz,END_GET_PACK
OK_UDP_CHKSUM:			;

	;--- Checksum correcto: comprobamos si es una respuesta DNS
	;    o un paquete DHCP, en ese caso se salta al codigo
	;    de procesamiento adecuado

	ld	a,(IN_BUFFER+26)
	ld	h,a
	ld	a,(IN_BUFFER+27)
	ld	l,a

	ld	de,DNS_PORT
	call	COMP
	jp	z,IS_DNS

	ld	de,68
	call	COMP
	jp	z,IS_DHCP

	;--- Comprobamos que se puede almacenar el paquete

	ld	hl,(IN_BUFFER+6)	;Paquete demasiado grande?
	ld	de,548+8+1
	call	COMP
	jp	c,END_GET_PACK

	ld	a,(UDPI_PINDEX)
	ld	b,a

	inc	b
	ld	ix,UDPI_IP0-10
	ld	de,10
BUC_UDP1:	add	ix,de
	djnz	BUC_UDP1	;Ahora IX apunta a la zona de datos adecuada

	ld	a,(UDPI_PINDEX)
	ld	b,a
	ld	a,(UDPI_GINDEX)
	cp	b
	jr	nz,UDPI_HAYSITIO

	ld	a,(ix)	;Indice GET = Indice PUT:
	or	(ix+1)	;Hay sitio si entrada vacia (IP=0),
	or	(ix+2)	;si no, terminamos.
	or	(ix+3)
	jp	nz,END_GET_PACK
UDPI_HAYSITIO:			;

	;--- Almacenamos paquete

	ld	hl,(IN_BUFFER+16)	;IP origen
	ld	(ix),l
	ld	(ix+1),h
	ld	hl,(IN_BUFFER+18)
	ld	(ix+2),l
	ld	(ix+3),h
	ld	hl,(IN_BUFFER+24)	;Puerto origen (little endian)
	ld	(ix+4),h
	ld	(ix+5),l
	ld	hl,(IN_BUFFER+26)	;Puerto destino (little endian)
	ld	(ix+6),h
	ld	(ix+7),l
	ld	hl,(IN_BUFFER+6)	;Longitud datos UDP
	ld	bc,8
	or	a
	sbc	hl,bc
	ld	(ix+8),l
	ld	(ix+9),h

	ld	a,h	;Copia la parte de datos
	or	l	;si no tiene long 0
	jr	z,OK_UDPIDATA

	push	hl
	ld	hl,UDP_BUFFERS-512
	ld	de,512
	ld	a,(UDPI_PINDEX)
	inc	a
	ld	b,a
UDPLEN_LOP1:	add	hl,de
	djnz	UDPLEN_LOP1
	ex	de,hl
	ld	hl,IN_BUFFER+32
	pop	bc
	ldir
OK_UDPIDATA:	;

	ld	hl,UDPI_PINDEX
	call	INC_UDPINDEX	;Actualiza indice para el proximo paquete
	jp	END_GET_PACK


;--- Esta subrutina incrementa UDPI_PINDEX o UDPI_GINDEX (dir pasada en HL).
;    Pasa de 7 a 0, o de 6 a 0 si hay un paquete capturado o pendiente.
;    Modifica: AF, BC, HL

INC_UDPINDEX:	ld	a,(hl)
	inc	a
	and	%111
	ld	(hl),a

	ld	b,a
	ld	a,(PCAP_STATE)
	or	a
	ret	z
	ld	a,b

	cp	7
	ret	nz
	ld	a,6
	ld	(hl),a
	ret


	;==============================
	;===  Paquete DNS recibido  ===
	;==============================

IS_DNS:	;--- Comprueba si hay una peticion en curso
	;    y si coincide el ID con el ultimo enviado,
	;    si no, descarta el paquete

	ld	a,(DNS_STAT_P)
	cp	1
	jp	nz,END_GET_PACK

	ld	hl,(IN_BUFFER+32)
	ld	de,(ID_DNS)
	call	COMP
	jp	nz,END_GET_PACK

	;--- Si la respuesta esta truncada, ponemos error 21
	;    a no ser que podamos reintentar con el DNS secundario.

	ld	a,(IN_BUFFER+34)
	and	%00000010
	jr	z,DNS_NOTRUNC

	call	DNS_USE_SEC
	jp	nc,END_GET_PACK

	ld	a,3
	ld	(DNS_STAT_P),a
	ld	a,21
	ld	(DNS_STAT_S),a
	jp	END_GET_PACK
DNS_NOTRUNC:	;

	;--- Si la respuesta contenia algun error,
	;    lo establecemos, a no ser que podamos reintentar
	;    con el DNS secundario.

	ld	a,(IN_BUFFER+35)
	and	%00001111
	jr	z,DNS_NOERR

	call	DNS_USE_SEC
	jp	nc,END_GET_PACK

	ld	a,3
	ld	(DNS_STAT_P),a
	ld	a,(IN_BUFFER+35)
	and	%00001111
	ld	(DNS_STAT_S),a
	jp	END_GET_PACK
DNS_NOERR:	;

	;--- La respuesta no contiene error.
	;    Comprobamos si contiene alguna respuesta valida.

	ld	ix,IN_BUFFER+32	;Apunta al ppio del paquete DNS

	ld	h,(ix+6)
	ld	l,(ix+7)
	ld	(ANCOUNT),hl	;Numero de respuestas
	ld	h,(ix+8)
	ld	l,(ix+9)
	ld	(NSCOUNT),hl	;Numero de servidores autoritativos
	ld	h,(ix+10)
	ld	l,(ix+11)
	ld	(ARCOUNT),hl	;Numero de secciones adicionales

	ld	ix,IN_BUFFER+44	;IX=Inicio de la pregunta

SKIPQ_LOOP:	ld	a,(ix)	;Se salta la pregunta
	inc	ix	;(campo QNAME)
	or	a	;comprobando si hay compresion
	jr	z,SKIPQ_LOOP3
	bit	7,a
	jr	z,SKIPQ_LOOP
SKIPQ_LOOP2:	inc	ix	;Se salta QTYPE y QCLASS
SKIPQ_LOOP3:	inc	ix	;(mas el segundo byte del puntero
	inc	ix	;si es necesario)
	inc	ix
	inc	ix	;Ahora IX apunta a las respuestas

	;* Comprobamos si se nos da directamente la respuesta

SCAN_FOR_AN:	ld	bc,(ANCOUNT)
	ld	a,b
	or	c
	jr	z,SCAN_FOR_NS
	call	SCAN_DNS_RR
	or	a
	jr	z,SCAN_FOR_NS

	ld	a,2	;Si habia una respuesta valida,
	ld	(DNS_STAT_P),a	;ponemos status=2 y terminamos
	xor	a
	ld	(DNS_STAT_S),a
	jp	END_GET_PACK

	;* Si no, comprobamos si hay IPs de otros servidores
	;  en "Authoritative" o en "Aditional"

SCAN_FOR_NS:	ld	bc,(NSCOUNT)
	ld	a,b
	or	c
	jr	z,SCANNS_FAILED	;Seccion NS vacia?

	call	SCAN_DNS_RR	;Busca IPs de servidores
	or	a	;en "authoritative"
	jp	nz,CHANGE_DNS_IP

	ld	bc,(ARCOUNT)
	ld	a,b
	or	c
	jr	z,SCANNS_FAILED	;Seccion AR vacia?

	call	SCAN_DNS_RR	;Busca IPs de servidores
	or	a	;en "additional"
	jp	nz,CHANGE_DNS_IP

SCANNS_FAILED:	ld	a,3	;Si no hay nada en NS ni AR, error 20
	ld	(DNS_STAT_P),a
	ld	a,20
	ld	(DNS_STAT_S),a
	jp	END_GET_PACK

	;* Se ha encontrado la IP de otro DNS:
	;  Repetimos la consulta usandola

CHANGE_DNS_IP:	ld	hl,DNS_RESULT
	ld	de,DNS_IP	;Establecemos nueva direccion
	ld	bc,4	;del DNS a consultar
	ldir

	ld	hl,(ID_DNS)	;Incrementamos identificador
	inc	hl
	ld	(ID_DNS),hl

	ld	a,3	;Ponemos estado secundario a 3
	ld	(DNS_STAT_S),a
	xor	a	;Inicializamos reintentos
	ld	(DNS_RETRY),a
	inc	a
	ld	(DNS_TOUT),a	;Para que se reenvie inmediatamente

	jp	END_GET_PACK


	;--- Esta subrutina examina la zona a la que apunta IX
	;    y busca un RR del tipo "Direccion IP".
	;    Si lo encuentra, pone la IP en DNS_REPLY
	;    y DNS_RESP_FLAG a #FF (que devuelve en A).
	;    Al final, IX apunta a la siguiente zona.
	;
	;    Entrada: BC = Numero de RRs en la zona.

SCAN_DNS_RR:	xor	a
	ld	(DNS_RESP_FLAG),a

DNS_AN_LOOP:	push	bc
SKIPQ_LOOP4:	ld	a,(ix)	;Se salta el nombre
	inc	ix	;comprobando si esta comprimido
	or	a
	jr	z,SKIPQ_LOOP6
	bit	7,a
	jr	z,SKIPQ_LOOP4
SKIPQ_LOOP5:	inc	ix
SKIPQ_LOOP6:	;

	ld	a,(DNS_RESP_FLAG)	;Si ya hay una respuesta
	or	a	;valida, simplemente se salta
	jr	nz,DNS_AN_LOOP2	;el RR

	;* Comprueba que el tipo sea "Direccion IP"

	ld	h,(ix)	;IX apunta a TYPE
	ld	l,(ix+1)
	ld	de,1
	call	COMP
	jr	nz,DNS_AN_LOOP2

	;* Se ha encontrado respuesta:
	;  se copia a DNS_RESULT

	ld	l,(ix+10)
	ld	h,(ix+11)
	ld	e,(ix+12)
	ld	d,(ix+13)
	ld	(DNS_RESULT),hl
	ld	(DNS_RESULT+2),de

	ld	a,#FF
	ld	(DNS_RESP_FLAG),a

	;* Pasa al siguiente RR

DNS_AN_LOOP2:	ld	bc,10
	add	ix,bc	;Para que apunte a RDATA
	ld	b,(ix-2)
	ld	c,(ix-1)	;BC = RDLENGTH
	add	ix,bc

	;* Si quedan RRs, vuelve a empezar

	pop	bc
	dec	bc
	ld	a,b
	or	c
	jr	nz,DNS_AN_LOOP

	ld	a,(DNS_RESP_FLAG)
	ret

DNS_RESP_FLAG:	db	0	;#FF cuando se encuentra respuesta


	;--- Esta subrutina es llamada cuando se recibe un paquete
	;    DNS erroneo o se consumen todos los reenvios.
	;    Lo que hace es comprobar si el DNS
	;    usado era el primario y hay un secundario disponible.
	;    Si es asi, establece DNS_IP con la direccion
	;    del DNS secundario, pone DNS_STAT_S a 2
	;    y DNS_RETRY a 0 (es decir, lo prepara todo
	;    para repetir la consulta usando el DNS secundario),
	;    y devuelve Cy=0.
	;    En caso contrario, devuelve Cy=1 (error).

DNS_USE_SEC:	ld	a,(DNS_STAT_S)
	cp	1
	scf
	ret	nz	;Si no era el primario

	ld	ix,BUF_IPDNS1
	ld	a,(ix+4)
	or	(ix+5)
	or	(ix+6)
	or	(ix+7)
	scf
	ret	z	;Si era el primario pero no hay sec.

	ld	hl,BUF_IPDNS2	;Establece secundario
	ld	de,DNS_IP	;y reinicia contador de
	ld	bc,4	;reenvios
	ldir
	ld	a,2
	ld	(DNS_STAT_S),a
	xor	a	;De paso pone Cy=0
	ld	(DNS_RETRY),a
	inc	a
	ld	(DNS_TOUT),a	;Para que se repita el envio inmediatamente
	ret


	;===============================
	;===  Paquete DHCP recibido  ===
	;===============================

IS_DHCP:	ld	a,(DHCP_VECT)	;Ignorar si no usamos DHCP
	or	a
	jp	z,END_GET_PACK

	ld	a,(DHCP_STATE)
	cp	CONFIGURED
	jp	z,END_GET_PACK

	;--- Obtiene el tipo del paquete

	ld	a,(IN_BUFFER+32)	;Es BOOTREPLY?
	cp	2
	jp	nz,END_GET_PACK

	ld	hl,IN_BUFFER+36	;El 'xid' coincide?
	ld	de,DHCP_XID
	call	COMP32
	jp	nz,END_GET_PACK

	call	DHCP_GET_TYPE
	cp	DHCPOFFER
	jr	z,IS_DHCP_OFFER
	cp	DHCPACK
	jr	z,IS_DHCP_ACK
	cp	DHCPNAK
	jp	z,IS_DHCP_NAK
	jp	END_GET_PACK	;Otros tipos son ignorados


	;--- Paquete DHCPOFFER

IS_DHCP_OFFER:

	;* Si el estado no es SELECTING, ignorarlo

	ld	a,(DHCP_STATE)
	cp	SELECTING
	jp	nz,END_GET_PACK

	;* Guarda el identificador del servidor

	call	DHCP_GET_SERVER
	jp	c,END_GET_PACK
	ld	de,DHCP_SERVER
	ld	bc,4
	ldir

	;* Guarda el campo 'yiaddr' como la IP ofrecida

	ld	hl,IN_BUFFER+48
	ld	de,DHCP_YIADDR
	ld	bc,4
	ldir

	;* Guarda el 'xid' recibido

	ld	hl,IN_BUFFER+36
	ld	de,DHCP_RCVXID
	ld	bc,4
	ldir

	;* Pasa a estado REQUESTING y envia DHCPREQUEST

	ld	a,REQUESTING
	ld	(DHCP_STATE),a
	ld	a,DHCPREQUEST
	call	SEND_DHCP
	call	DHCP_FIRST
	jp	END_GET_PACK


	;--- Paquete ACK

IS_DHCP_ACK:

	;* Si el estado no es REBINDING, REQUESTING, RENEWING
	;  o INFORMING, ignorarlo

ISDHCPACK2:	cp	REQUESTING
	jr	z,ISDHCPACK3
	cp	RENEWING
	jr	z,ISDHCPACK3
	cp	REBINDING
	jr	z,ISDHCPACK3
	cp	INFORMING
	jp	nz,END_GET_PACK
ISDHCPACK3:

	;* Si el identificador del servidor no coincide con el anterior,
	;  ignorar el mensaje
	;  (Problema: Que pasa si el ACK ha sido recibido en estado REBINDING,
	;  por un servidor distinto al usado anteriormente?
	;  Por eso, nos fiaremos znicamente del XID)

	;call	DHCP_GET_SERVER
	;jp	c,END_GET_PACK
	;ld	de,DHCP_SERVER
	;call	COMP32
	;jp	nz,END_GET_PACK

	;* Inicializa los campos Lease, T1 y T2

	ld	hl,DHCP_T1
	ld	de,DHCP_T1+1
	ld	bc,12-1
	ld	(hl),0
	ldir

	;* Guarda el campo 'yiaddr' como la IP asignada,
	;  a no ser que hubieramos enviado DHCPINFORM

	ld	a,(DHCP_VECT)
	and	1
	jr	z,ISDHCPACK4

	ld	hl,IN_BUFFER+48
	ld	de,BUF_IPLOCAL
	ld	bc,4
	ldir
	ld	a,1
	ld	(DHCP_VECT_O),a
ISDHCPACK4:

	;* Recorre todas las opciones y las procesa

	call	DHCP_INIT_OP

ISDHCPACKL:	call	DHCP_NEXT_OP
	or	a
	jp	z,ISDHCPACKEND	;No quedan opciones?

	;* T1: Lo almacena

	cp	58
	jr	nz,ISDHCPACK_NOT1

	push	ix
	pop	hl
	ld	de,DHCP_T1
	ld	bc,4
	ldir

	ld	ix,DHCP_T1
	call	POR60_32
	jr	ISDHCPACKL
ISDHCPACK_NOT1:

	;* T2: Lo almacena

	cp	59
	jr	nz,ISDHCPACK_NOT2

	push	ix
	pop	hl
	ld	de,DHCP_T2
	ld	bc,4
	ldir

	ld	ix,DHCP_T2
	call	POR60_32
	jr	ISDHCPACKL
ISDHCPACK_NOT2:

	;* Lease: Lo almacena

	cp	51
	jr	nz,ISDHCPACK_NOLS

	push	ix
	pop	hl
	ld	de,DHCP_LEASE
	ld	bc,4
	ldir

	ld	ix,DHCP_LEASE
	call	POR60_32
	jr	ISDHCPACKL
ISDHCPACK_NOLS:

	;* Mascara de subred: la almacena si la habiamos pedido

	cp	1
	jr	nz,ISDHCPACK_NOSB

	ld	a,(DHCP_VECT)
	and	%10	;La habiamos pedido?
	jr	z,ISDHCPACKL

	push	ix
	pop	hl
	ld	de,SUBNET_MASK
	ld	bc,4
	ldir

	ld	a,(DHCP_VECT_O)
	or	%10
	ld	(DHCP_VECT_O),a
	jr	ISDHCPACKL
ISDHCPACK_NOSB:

	;* Gateway por defecto: lo almacena si lo habiamos pedido

	cp	3
	jr	nz,ISDHCPACK_NOGW

	ld	a,(DHCP_VECT)
	and	%100	;La habiamos pedido?
	jr	z,ISDHCPACKL

	push	ix
	pop	hl
	ld	de,DEFGW
	ld	bc,4
	ldir

	ld	a,(DHCP_VECT_O)
	or	%100
	ld	(DHCP_VECT_O),a
	jp	ISDHCPACKL
ISDHCPACK_NOGW:

	;* Servidores DNS: los almacena si los habiamos pedido

	cp	6
	jr	nz,ISDHCPACK_NODN

	ld	a,(DHCP_VECT)
	and	%1000	;Los habiamos pedido?
	jp	z,ISDHCPACKL

	ld	a,(DHCP_VECT_O)
	or	%1000
	ld	(DHCP_VECT_O),a

	push	bc
	push	ix
	pop	hl
	ld	de,BUF_IPDNS1
	ld	bc,4
	ldir

	pop	bc	;Hay mas de un DNS en la opcion?
	ld	a,b
	cp	8
	jp	c,ISDHCPACKL
	ld	de,BUF_IPDNS2
	ld	bc,4
	ldir
	jp	ISDHCPACKL
ISDHCPACK_NODN:

	;* Timeout ARP: lo almacena si lo habiamos pedido

	cp	35
	jr	nz,ISDHCPACK_NOAT

	ld	a,(DHCP_VECT)
	and	%10000	;Lo habiamos pedido?
	jp	z,ISDHCPACKL

	push	ix,ix
	pop	hl
	ld	de,ARP_TOUT
	ld	bc,4
	ldir
	pop	hl
	ld	de,ARP_TOUT_SECS
	ld	bc,4
	ldir
	ld	ix,ARP_TOUT
	call	POR60_32

	ld	a,(DHCP_VECT_O)
	or	%10000
	ld	(DHCP_VECT_O),a
	jp	ISDHCPACKL
ISDHCPACK_NOAT:

	;* Tipo de trama ethernet: lo almacena si lo habiamos pedido

	cp	36
	jr	nz,ISDHCPACK_NOFT

	ld	a,(DHCP_VECT)
	and	%100000	;Lo habiamos pedido?
	jp	z,ISDHCPACKL

	ld	a,(ix)
	or	a
	jr	z,ISDHCPACK_FT
	ld	a,#FF
ISDHCPACK_FT:	ld	(FRAME_TYPE),a

	ld	a,(DHCP_VECT_O)
	or	%100000
	ld	(DHCP_VECT_O),a
	;jp      ISDHCPACKL
ISDHCPACK_NOFT:

	;* Opcion no reconocida: ignorarla

	jp	ISDHCPACKL
ISDHCPACKEND:

	;* Fin de las opciones.
	;  Si estamos en INFORMING, pasar a CONFIGURED y terminar.

	ld	a,(DHCP_STATE)
	cp	INFORMING
	jr	nz,ISDHCPACKEND0

	ld	a,CONFIGURED
	ld	(DHCP_STATE),a
	jp	END_GET_PACK
ISDHCPACKEND0:

	;* Si T1 es 0, establecerlo a lease/2

	ld	hl,DHCP_T1
	ld	de,ZERO32
	call	COMP32
	jr	nz,OKT1NZ

	ld	hl,#FFFF	;Si lease infinito, T1 infinito
	ld	(DHCP_T1),hl
	ld	(DHCP_T1+2),hl
	ld	a,(DHCP_LEASE)
	cp	h
	jr	z,OKT1NZ

	ld	hl,DHCP_LEASE
	ld	de,DHCP_T1
	ld	bc,4
	ldir
	ld	ix,DHCP_T1
	ld	b,1
	call	ENTRE2_32
OKT1NZ:

	;* Si T2 es 0, establecerlo a 0.875*lease ((7/8)*lease)

	ld	hl,DHCP_T2
	ld	de,ZERO32
	call	COMP32
	jr	nz,OKT2NZ

	ld	hl,#FFFF	;Si lease infinito, T2 infinito
	ld	(DHCP_T2),hl
	ld	(DHCP_T2+2),hl
	ld	a,(DHCP_LEASE)
	cp	h
	jr	z,OKT2NZ

	ld	hl,DHCP_LEASE
	ld	de,DHCP_T2
	ld	bc,4
	ldir

	ld	ix,DHCP_T2	;Divide T2 entre 8
	ld	b,3
	call	ENTRE2_32

	ld	hl,DHCP_T2
	ld	de,IN_BUFFER
	ld	bc,4
	ldir

	ld	b,6
T2ISZL:	push	bc	;Multiplica (T2/8) por 7
	ld	hl,IN_BUFFER
	ld	de,DHCP_T2
	ld	bc,DHCP_T2
	call	ADD32
	pop	bc
	djnz	T2ISZL
OKT2NZ:

	;* Fin: pasa a BOUND y termina

	ld	a,BOUND
	ld	(DHCP_STATE),a
	jp	END_GET_PACK


	;--- Paquete NAK

IS_DHCP_NAK:

	;* En estado BOUND, SELECTING, INFORMING o CONFIGURED, ignorarlo

	ld	a,(DHCP_STATE)
	cp	BOUND
	jp	z,END_GET_PACK
	cp	SELECTING
	jp	z,END_GET_PACK
	cp	INFORMING
	jp	z,END_GET_PACK
	cp	CONFIGURED
	jp	z,END_GET_PACK

	;* En otros estados, volver a INIT

	xor	a	;ld     a,INIT
	ld	(DHCP_STATE),a
	jp	END_GET_PACK


	;===============================
	;===  Segmento TCP recibido  ===
	;===============================

IS_TCP:	;--- Comprueba checksum, excepto si CHKVECT dice lo contrario

	ld	a,#FF
	ld	(GOT_TCP),a

	ld	a,(CHKVECT)
	and	%100
	jp	z,OK_TCP_CHKSUM

	;Para el calculo del ckecksum usamos el mismo truco que para UDP
	;(ver IS_UDP)

	xor	a
	ld	(IN_BUFFER+12),a	;Campo TTL
	ld	ix,IN_BUFFER+14
	ld	hl,(IN_BUFFER+6)	;Long. TCP en el campo checksum IP
	ld	(ix),h
	ld	(ix+1),l

	;ld      hl,(IN_BUFFER+6)
	ld	bc,12	;Para que incluya pseudo-cabecera
	add	hl,bc
	push	hl
	pop	bc
	ld	ix,IN_BUFFER+12
	call	CALC_CHKSUM
	ld	a,d
	or	e
	jp	nz,END_GET_PACK
OK_TCP_CHKSUM:			;

	;--- Si el paquete contiene opciones, buscamos MSS;
	;    despues descartamos las demas y
	;    movemos los datos TCP a la posicion IN_BUFFER+44.
	;    Si no hay MSS, asumimos 512.

	ld	de,536
	ld	(RECEIVED_MSS),de

	ld	a,(IN_BUFFER+36)
	and	#F0
	srl	a
	srl	a
	ld	l,a
	ld	h,0	;HL = Tam. cabecera TCP en bytes

	cp	20
	jr	z,TCPOPTOK	;No hay opciones

	push	hl
	ld	a,(IN_BUFFER+37)	;No se molesta en buscar
	and	%10	;la opcion MSS si el seg no tiene SYN
	jr	z,TCP_OP_END2

	;* Busca la opcion MSS

	ld	a,l
	sub	20
	ld	b,a	;B = Tamanyo opciones
	ld	ix,IN_BUFFER+44	;Principio de las opciones

TCP_OP_LOOP:	ld	a,(ix)
	or	a
	jr	z,TCP_OP_END	;Opcion "Fin de opciones"
	inc	ix
	dec	b
	jr	z,TCP_OP_END	;No quedan opciones
	dec	a
	jr	z,TCP_OP_LOOP	;Opcion 1 ("Padding")
	dec	a
	jr	nz,TCP_OP_NEXT	;Opcion 2 (MSS)

	;Opcion MSS encontrada

	ld	h,(ix+1)
	ld	l,(ix+2)
	ld	a,h	;Si anuncia MSS=0,
	or	l	;suponer 1 (que hay mucho listo)
	jr	nz,NO_MSS_0
	ld	hl,1
NO_MSS_0:	ld	(RECEIVED_MSS),hl
	jr	TCP_OP_END	;Ignoramos resto de opciones

	;Otra opcion: la saltamos

TCP_OP_NEXT:	ld	a,(ix)	;Longitud
	dec	a	;No contamos codigo, que ya hemos saltado
TCP_NXT_LOOP:	inc	ix
	dec	b
	dec	a
	jr	nz,TCP_NXT_LOOP

	;Siguiente opcion, si quedan

TCP_OP_NEXT2:	ld	a,b
	cp	4	;Si quedan menos de 4 bytes no puede haber MSS
	jr	nc,TCP_OP_LOOP
TCP_OP_END:

	;* Mueve los datos al principio del segmento

	pop	hl
	push	hl
TCP_OP_END2:	ld	bc,IN_BUFFER+44
	add	hl,bc	;HL = Inicio de los datos
	ld	de,IN_BUFFER+44
	ld	bc,(IP_TOTAL_LEN)
	ldir		;Mueve los datos justo despues de la cabecera
	pop	hl

TCPOPTOK:	push	hl
	pop	bc	;Actualiza tamanyo de los datos
	ld	hl,(IN_BUFFER+6)	;(resta cabecera TCP)
	or	a
	sbc	hl,bc
	ld	(IN_BUFFER+6),hl

	ld	a,(IN_BUFFER+38)	;Cambia la info de ventana para que sea little-endian
	ld	h,a
	ld	a,(IN_BUFFER+39)
	ld	l,a
	ld	(IN_BUFFER+38),hl

	;--- Busca la conexion asociada,
	;    si no existe envia RST y termina

	call	SRCH_TCP_INBUF
	cp	#FF
	jr	nz,TCP_OKEX

	;Si no existe una conexion asociada,
	;y el segmento tiene SYN, busca
	;una conexion en LISTEN sin especificar

	ld	a,(IN_BUFFER+37)	;Tiene SYN?
	and	%10
	jr	z,TCP_NOEX

	call	SEARCH_LISTEN	;Hay conexion adecuada?
	cp	#FF
	jr	z,TCP_NOEX

	call	LOAD_TCB

	ld	hl,IN_BUFFER+16	;Establece IP remota
	ld	de,REMOTE_IP	;con la IP fuente del paquete
	ld	bc,4
	ldir

	ld	hl,(IN_BUFFER+24)	;Establece puertos
	ld	de,(IN_BUFFER+26)	;con los del paquete
	ld	ix,TCB_TEMP	;(puuuuuto big endian!!)
	ld	(ix+5),h
	ld	(ix+6),l
	ld	(ix+7),d
	ld	(ix+8),e

	jr	TCP_OKEX2

	;La conexion no existe

TCP_NOEX:	ld	a,(IN_BUFFER+37)
	bit	2,a
	jp	nz,END_GET_PACK	;Si tiene RST, termina

	and	%10000	;El tipo de RST a enviar depende de si hay ACK
	ld	a,1
	jp	z,TCP_SNDRST
	inc	a
TCP_SNDRST:	call	SEND_RST
	jp	END_GET_PACK

TCP_OKEX:	call	LOAD_TCB
TCP_OKEX2:	;

	;>>> Proceso en estado LISTEN <<<

	ld	a,(TCP_STATE)
	cp	LISTEN
	jp	nz,TCP_NO_LISTEN

	;--- Si tiene RST, lo ignoramos

	ld	a,(IN_BUFFER+37)
	bit	2,a
	jp	nz,END_GET_PACK

	;--- Si tiene ACK, enviamos RST

	bit	4,a
	jr	z,TCP_LST_NOACK
	ld	a,2
	call	SEND_RST
	jp	END_GET_PACK
TCP_LST_NOACK:

	;--- Si NO tiene SYN, lo ignoramos;
	;    en caso contrario lo procesamos

	bit	1,a
	jp	z,END_GET_PACK

	ld	hl,(RECEIVED_MSS)
	ld	(MSS),hl

	ld	hl,IN_BUFFER+28	;Hace RCV_NXT = SEG_SEQ+1
	ld	bc,RCV_NXT
	call	INC32

	ld	hl,IN_BUFFER+28	;Hace IRS = SEG_SEQ
	ld	de,IRS
	ld	bc,4
	ldir

	;> Aqui deberiamos establecer ISS, pero ya esta a 0
	;ld     hl,ZERO32
	;ld     de,ISS
	;ld     bc,4
	;ldir

	ld	hl,ISS	;Hace SND_NXT = ISS+1
	ld	bc,SND_NXT
	call	INC32

	ld	hl,ISS	;Hace SND_UNA = ISS
	ld	de,SND_UNA
	ld	bc,4
	ldir

	ld	hl,ISS	;Prepara segmento para enviar: num. secuencia
	ld	de,OUT_BUFFER+28
	ld	bc,4
	ldir

	ld	hl,RCV_NXT	;Prepara ACK
	ld	de,OUT_BUFFER+32
	ld	bc,4
	ldir

	ld	a,%10010
	ld	(OUT_BUFFER+37),a	;ACK + SYN

	call	SET_TCP_PORTS	;Envia el segmento
	ld	bc,0
	call	SEND_SEGMENT

	ld	a,SYN.RECEIVED	;Actualiza el resto del TCB y termina
	ld	(TCP_STATE),a
	ld	hl,(USER_TOUT_V)
	ld	(USER_TOUT),hl
	ld	a,#FF
	ld	(SYN_SENT_FLAG),a
	ld	hl,RTO_V*60
	ld	(RTO_T),hl

	jp	END_GET_TCP

TCP_NO_LISTEN:

	;>>> Proceso en estado SYN-SENT <<<

	;ld      a,(TCP_STATE)
	cp	SYN.SENT
	jp	nz,TCP_NO_SYNS

	;--- Comprueba ACK:
	;    si SEG_ACK<=ISS o SEG_ACK>SND_NXT, enviar RST
	;    (OK si ISS<SEG_ACK<=SND_NXT)

	ld	a,(IN_BUFFER+37)
	and	%10000
	ld	b,0
	jr	z,TCP_SYNS_OKACK

	ld	de,IN_BUFFER+32	;Error si SEG_ACK<=ISS
	ld	hl,ISS
	call	COMP_SEQ
	jr	c,TCP_SYNS_BADACK

	ld	hl,SND_NXT	;OK si SND_NXT>=SEG_ACK
	ld	de,IN_BUFFER+32
	call	COMP_SEQ
	ld	b,1
	jr	c,TCP_SYNS_OKACK

	;ACK invalido:
	;enviamos un reset a no ser que el segmento ya tenga uno

TCP_SYNS_BADACK:	ld	a,(IN_BUFFER+37)
	and	%100
	ld	a,2
	call	z,SEND_RST
	jp	END_GET_PACK
TCP_SYNS_OKACK:

	;--- Comprueba RST: si esta presente, descarta el
	;    segmento si no habia ACK (B=0);
	;    en caso contrario (B=1) cierra la conexion

	ld	a,(IN_BUFFER+37)
	bit	2,a
	jr	z,TCP_SYNS_OKRST

	bit	0,b
	jp	z,END_GET_PACK
	xor	a
	ld	(TCP_STATE),a
	ld	a,3
	ld	(LAST_CLOSE),a
	jp	END_GET_TCP
TCP_SYNS_OKRST:

	;--- Comprueba SYN

	and	%10	;Descartamos paquete si no hay SYN
	jp	z,END_GET_PACK

	ld	hl,(RECEIVED_MSS)
	ld	(MSS),hl

	ld	hl,IN_BUFFER+28	;Hace RCV_NXT=SEG_SEQ+1
	ld	bc,RCV_NXT
	call	INC32

	ld	hl,IN_BUFFER+28	;Hace IRS=SEG_SEQ
	ld	de,IRS
	ld	bc,4
	ldir

	ld	a,(IN_BUFFER+37)	;Hace SND_UNA=SEG_ACK si habia ACK
	and	%10000
	jr	z,TCP_SYNS_OKACK2
	ld	hl,IN_BUFFER+32
	ld	de,SND_UNA
	ld	bc,4
	ldir
TCP_SYNS_OKACK2:

	ld	de,SND_UNA	;Compara SND_UNA e ISS
	ld	hl,ISS
	call	COMP_SEQ
	jr	c,TCP_SYNS_2

	;Proceso si SND_UNA>ISS

	ld	a,ESTABLISHED
	ld	(TCP_STATE),a
	xor	a
	ld	(SYN_SENT_FLAG),a
	call	SET_WNDWL

	call	SEND_ACK
	jp	END_GET_TCP

	;Proceso si SND_UNA<=ISS

TCP_SYNS_2:	ld	a,SYN.RECEIVED
	ld	(TCP_STATE),a
	ld	a,#12
	call	SEND_SYN
	jp	END_GET_TCP
TCP_NO_SYNS:

	;>>> Comprobacion del numero de secuencia <<<

	call	CHECK_SEQ
	jp	nc,END_GET_TCP	;???

	;>>> Comprobacion de la bandera RST <<<

	ld	a,(IN_BUFFER+37)
	bit	2,a
	jr	z,TCP_NO_RST

	;--- Estado SYN-RECEIVED y la conexion
	;    era pasiva: volver a LISTEN

	call	RET_LISTEN
	jp	c,END_GET_TCP

	;--- Otros estados o conexion activa:
	;    cerrarla

SET_CLOSED:	xor	a
	ld	(TCP_STATE),a
	ld	a,3
	ld	(LAST_CLOSE),a
	jp	END_GET_TCP
TCP_NO_RST:

	;>>> Comprobacion de la bandera SYN <<<

	;ld      a,(IN_BUFFER+37)
	bit	1,a
	jr	z,TCP_NO_SYN

	;--- Estado SYN-RECEIVED y la conexion
	;    era pasiva: enviar RST y volver a LISTEN,
	;    otros estados o conexion activa:
	;    cerrarla

	call	RET_LISTEN
	jp	c,END_GET_TCP
	xor	a
	call	SEND_RST
	jp	SET_CLOSED
TCP_NO_SYN:

	;>>> Comprobacion de ACK <<<

	;--- Si no hay ACK, ignorar segmento

	;ld      a,(IN_BUFFER+37)
	and	%10000
	jp	z,END_GET_PACK

	;--- Estado SYN-RECEIVED:
	;    Si SND.UNA =< SEG.ACK =< SND.NXT, pasar a ESTABLISHED
	;    y llamar a SET_WNDWL. Si no, enviar ACK.

	ld	a,(TCP_STATE)
	cp	SYN.RECEIVED
	jr	nz,TCP_NO_SYNR

	ld	hl,SND_UNA
	ld	bc,IN_BUFFER+32
	ld	de,SND_NXT
	call	RANGE32
	jr	c,OK_ACK_RANGE

	call	SEND_ACK	;ACK no aceptable
	jp	END_GET_TCP

OK_ACK_RANGE:	ld	a,ESTABLISHED	;ACK aceptable
	ld	(TCP_STATE),a
	xor	a
	ld	(SYN_SENT_FLAG),a
	call	SET_WNDWL
	ld	hl,IN_BUFFER+32
	ld	de,SND_UNA
	ld	bc,4
	ldir
	jp	END_GET_TCP
TCP_NO_SYNR:

	;--- Proceso comun para todos los demas estados

	call	PROCESS_ACK
	jp	nc,END_GET_TCP

	;--- FIN_WAIT_1: Si el FIN esta ACKeado, pasar a FIN-WAIT-2

	ld	a,(TCP_STATE)
	cp	FIN.WAIT.1
	jr	nz,TCP_NO_FW1

	ld	a,(FIN_SENT_FLAG)
	or	a
	jr	nz,TCP_NO_FW1

	ld	a,FIN.WAIT.2
	ld	(TCP_STATE),a
	jr	TCP_NO_CLLA
TCP_NO_FW1:

	;--- CLOSING (8) y LAST-ACK (9): Si el FIN esta ACKeado,
	;    cierra la conexion.
	;NOTA: Deberia pasar de CLOSING A TIME-WAIT,
	;      pero no hemos implementado ese estado.

	or	1
	cp	9
	jr	nz,TCP_NO_CLLA

	ld	a,(FIN_SENT_FLAG)
	or	a
	jp	nz,END_GET_TCP

TCP_TO_CLOSED:	xor	a
	ld	(TCP_STATE),a
	ld	a,1
	ld	(LAST_CLOSE),a
	jp	END_GET_TCP
TCP_NO_CLLA:	;       

	;>>> Proceso de los datos del segmento <<<

	;--- Si no estamos en ESTABLISHED (4), FIN_WAIT_1 (5) o FIN_WAIT_2 (6),
	;    ignorar los datos

	ld	a,(TCP_STATE)
	cp	ESTABLISHED
	jp	c,TCP_OK_TXT
	cp	FIN.WAIT.2+1
	jp	nc,TCP_OK_TXT

	;--- Encola los datos y actualiza RCV_NXT

TCP_INSAGAIN:	ld	bc,(IN_BUFFER+6)
	ld	a,b
	or	c
	jr	z,TCP_OK_TXT
	ld	ix,INBUF
	ld	hl,IN_BUFFER+44
	push	bc
	call	RBUF_INSERT
	pop	de
	jr	nc,TCP_INSERT_OK

	ld	bc,(INBUF_FREE)	;Por si hay demasiados datos
	ld	(IN_BUFFER+6),bc
	jr	TCP_INSAGAIN

TCP_INSERT_OK:	ld	hl,RCV_NXT
	ld	bc,RCV_NXT
	call	ADD3216

	;--- Actualiza los datos para el envio del ACK retardado

	ld	hl,(ACK_RCV_NUM)
	ld	a,h
	or	l
	jr	nz,OK_ACK_TIM
	ld	a,ACK_DELAY_V
	ld	(ACK_DELAY_T),a
OK_ACK_TIM:

	ld	bc,(IN_BUFFER+6)
	add	hl,bc
	ld	(ACK_RCV_NUM),hl
TCP_OK_TXT:

	;>>> Proceso del bit FIN <<<

	ld	a,(IN_BUFFER+37)
	and	1
	jr	z,TCP_NO_FIN

	;--- En estado LISTEN o SYN-SENT, ignorar el segmento

	ld	a,(TCP_STATE)
	cp	LISTEN
	jp	z,END_GET_TCP
	cp	SYN.SENT
	jp	z,END_GET_TCP

	;--- Actualizar RCV_NXT y enviar un ACK

	ld	hl,RCV_NXT
	ld	bc,RCV_NXT
	call	INC32
	call	SCHEDULE_ACK	;SEND_ACK

	;--- SYN-RECEIVED y ESTABLISHED: pasar a CLOSE_WAIT

	ld	a,(TCP_STATE)
	cp	ESTABLISHED
	jr	z,TCP_TO_CW
	cp	SYN.RECEIVED
	jr	nz,TCP_NO_CW

TCP_TO_CW:	ld	a,CLOSE.WAIT
	ld	(TCP_STATE),a
	jp	END_GET_TCP
TCP_NO_CW:

	;--- Estado FIN-WAIT-1: Si el FIN esta ACKeado, cerrar la conexion;
	;    en caso contrario pasar a CLOSING

	cp	FIN.WAIT.1
	jr	nz,TCP_NO_FW1_2

	ld	a,(FIN_SENT_FLAG)
	or	a
	jp	z,TCP_TO_CLOSED
	ld	a,CLOSING
	ld	(TCP_STATE),a
	jp	END_GET_TCP
TCP_NO_FW1_2:

	;--- Estado FIN-WAIT-2: Cerrar la conexion

	cp	FIN.WAIT.2
	jp	z,TCP_TO_CLOSED
TCP_NO_FIN:

	;>>> Fin <<<

END_GET_TCP:	call	SAVE_TCB
	jp	END_GET_PACK


	;=======================================
	;===  Proceso de las conexiones TCP  ===
	;=======================================

	;En este proceso se efectuan las acciones pertinentes
	;cuando los temporizadores han expirado,
	;o cuando se han acumulado suficientes datos
	;para enviar o ACKear.
	;Solo se procesa una conexion por interrupcion
	;(se examinan todas por turnos).

DO_TCP_PROCESS:

	;--- Obtiene el numero de la ultima conexion procesada,
	;    lo incrementa, y comprueba si la conexion
	;    correspondiente no esta cerrada.
	;    En ese caso la procesa, si no, prueba con la siguiente.
	;    Si ninguna esta abierta, termina.

	ld	b,4	;Maximo numero de pasos del bucle de busqueda
	ld	a,(LAST_PROC_TCB)
LOOP_TCBS:	inc	a
	and	%11	;Despues de la conexion 3 vuelve a la 0
	ld	c,a
	call	GET_TCB_DIR
	ld	a,(hl)
	or	a	;Esta cerrada?
	ld	a,c
	jr	nz,PROCESS_TCB	;No: procesar conexion:
	djnz	LOOP_TCBS	;Si: probar con la siguiente, si quedan
	ret

PROCESS_TCB:	ld	(LAST_PROC_TCB),a
	call	LOAD_TCB

	;>>> El algoritmo que se sigue es:
	;    - Si hay datos pendientes de retransmision
	;       * Si el timeout de usuario es 0, cerrar la conexion. Fin.
	;       * Si el timeout de retransmision es 0, retransmitir los datos. 
	;         Fin.
	;       * Saltar a la comprobacion de ACK retardado.
	;    - Si hay datos nuevos para enviar
	;       * Si NO se cumple que: hay datos PUSH, o hay al menos MSS bytes 
	;         de datos, o ha expirado el temporizador de envio no PUSH, fin.
	;       * Si la ventana de transmision NO es cero, enviar datos nuevos.
	;         Fin.
	;       * Si ha expirado el temporizador de prueba de ventana cero,
	;         enviar una prueba.
	;       * Fin.
	;    - Si hay pendiente un FIN, enviarlo y pasar a
	;      LAST-ACK si es necesario. Fin.
	;    - Si hay pendiente un ACK retardado
	;      * Si ha expirado el temporizador de envio de ACK,
	;        o hay al menos 512 bytes pendientes de ACK, enviar un ACK.
	;      * Fin.

	;--- Proceso si hay datos pendientes de retransmision:
	;    Si el timeout de usuario es 0, cierra la conexion

	ld	a,(SYN_SENT_FLAG)	;Hay datos a ReTx?
	or	a
	jr	nz,DO_RETX_PEND
	ld	a,(FIN_SENT_FLAG)
	or	a
	jr	nz,DO_RETX_PEND
	ld	hl,(RETX_SIZE)
	ld	a,h
	or	l
	jp	z,NO_RETX_PEND
DO_RETX_PEND:

	ld	hl,(USER_TOUT_V)	;Si el valor inicial del timeout
	inc	hl	;es #FFFF, es "infinito": no comprobarlo
	ld	a,h
	or	l
	jr	z,NO_UTOUT_EXP

	ld	hl,(USER_TOUT)
	ld	a,h
	or	l
	jr	nz,NO_UTOUT_EXP

	xor	a
	call	SEND_RST
	ld	a,(TCP_STATE)
	or	1
	cp	3
	ld	a,4
	jr	nz,TOUT_EXP_2
	inc	a
TOUT_EXP_2:	ld	(LAST_CLOSE),a	;Error 5 si el estado era SYN_xxx, si no, error 4
	xor	a
	ld	(TCP_STATE),a
	jp	END_PROC_TCP
NO_UTOUT_EXP:

	;--- Datos pendientes de envio:
	;    Si el contador de retransmisiones llega a 0,
	;    reenviar; si no, saltar directamente
	;    a la prueba de ACK retardado

	ld	hl,(RTO_T)
	ld	a,h
	or	l
	jp	nz,END_RETX_PEND

	ld	hl,RTO_V*60	;De paso reinicia el temporizador
	ld	(RTO_T),hl

	;* Reenvio de SYN

	ld	a,(SYN_SENT_FLAG)
	or	a
	jr	z,NO_RETX_SYN

	ld	a,(TCP_STATE)	;Con ACK si el estado es SYN-RECEIVED
	cp	SYN.SENT
	ld	a,2
	jr	z,RETX_SYN
	ld	a,#12
RETX_SYN:	call	SEND_SYN
	jp	END_PROC_TCP
NO_RETX_SYN:

	;* Reenvio de FIN

	ld	a,(FIN_SENT_FLAG)
	or	a
	jr	z,NO_RETX_FIN

	ld	a,1
	ld	bc,0
	call	SEND_DATA
	jp	END_PROC_TCP
NO_RETX_FIN:

	;* Reenvio de datos

	ld	ix,OUTBUF
	ld	de,OUT_BUFFER+44
	ld	bc,(RETX_SIZE)
	call	RBUF_PEEK

	ld	hl,(SEND_PUSH_PEND)
	ld	a,h
	or	l
	jr	z,NO_PUSH_1
	ld	a,8
NO_PUSH_1:	call	SEND_DATA
	jp	END_PROC_TCP

NO_RETX_PEND:

	;--- No hay datos para reenviar:
	;    Comprueba si se pueden enviar datos nuevos, se podra si:
	;    - Hay datos PUSH, o
	;    - Hay al menos MSS bytes pendientes, o
	;    - El temporizador de envio es 0

	ld	hl,(OUTBUF_USED)	;Hay datos par enviar?
	ld	a,h
	or	l
	jp	z,NO_NEW_PEND

	ld	de,(SEND_PUSH_PEND)	;Hay datos push?
	ld	a,d
	or	e
	jr	nz,DO_SEND_NEW

	ld	de,(MSS)	;Hay al menos MSS bytes?
	call	COMP
	jr	c,DO_SEND_NEW

	ld	hl,(SEND_TOUT)	;Ha expirado el temporizador de envio?
	ld	a,h
	or	l
	jp	nz,NO_SEND_NEW

	;* Si la ventana de transmision es 0, y el temporizador
	;  de comprobacion ha expirado, envia un ACK
	;  con num. de secuencia SND_NXT-1, y reinicia contador

DO_SEND_NEW:	ld	hl,(SND_WND)
	ld	a,h
	or	l
	jr	nz,DO_SEND_NEW2

	ld	hl,(RTO_T)
	ld	a,h
	or	l
	jp	nz,NO_SEND_NEW

	ld	hl,SND_UNA
	ld	bc,SND_UNA
	call	DEC32
	call	SEND_ACK
	ld	hl,SND_UNA
	ld	bc,SND_UNA
	call	INC32
	ld	hl,SND_UNA
	ld	de,SND_NXT
	ld	bc,4
	ldir
	ld	hl,ZWP_V*60	;Reinicia a 10 segundos
	ld	(RTO_T),hl
	jr	NO_SEND_NEW

	;* Extrae los datos y los envia

DO_SEND_NEW2:	ld	hl,(SND_WND)	;En principio envia el minimo entre
	ld	de,(MSS)	;la ventana de transmision, MSS y 448
	call	COMP
	jr	nc,OK_SND_SIZE
	ex	de,hl
OK_SND_SIZE:	ld	de,448
	call	COMP
	jr	nc,OK_SND_SIZE2
	ex	de,hl
OK_SND_SIZE2:	push	hl
	pop	bc

	ld	ix,OUTBUF
	ld	de,OUT_BUFFER+44
	call	RBUF_PEEK	;Si no hay BC bytes disponibles,
	ld	(RETX_SIZE),bc	;se extraeran tantos como sea posible
	ld	hl,(SEND_PUSH_PEND)
	ld	a,h
	or	l
	jr	z,NO_PUSH_2
	ld	a,8
NO_PUSH_2:	call	SEND_DATA

	ld	hl,RTO_V*60	;Inicializa temporizador de ReTx
	ld	(RTO_T),hl
	ld	hl,(USER_TOUT_V)	;Inicializa temporizador de usuario
	ld	(USER_TOUT),hl
	jr	END_PROC_TCP
NO_NEW_PEND:

	;--- Si esta pendiente un envio de FIN y ya se han enviado todos
	;    los datos, envia un FIN y cambia a estado LAST-ACK
	;    si estabamos en CLOSE-WAIT

	ld	a,(FIN_PENDING)
	or	a
	jr	z,NO_FIN_PEND

	ld	a,(TCP_STATE)
	cp	CLOSE.WAIT
	jr	nz,NO_TO_LACK
	ld	a,LAST.ACK
	ld	(TCP_STATE),a
NO_TO_LACK:

	xor	a
	ld	(FIN_PENDING),a
	ld	a,1
	ld	bc,0
	call	SEND_DATA
	ld	a,#FF
	ld	(FIN_SENT_FLAG),a

	ld	hl,RTO_V*60	;Inicializa temporizador de ReTx
	ld	(RTO_T),hl
	ld	hl,(USER_TOUT_V)	;Inicializa temporizador de usuario
	ld	(USER_TOUT),hl
	jr	END_PROC_TCP
NO_FIN_PEND:
END_RETX_PEND:
NO_SEND_NEW:

	;--- Si no se ha enviado nada en este punto, comprueba
	;    si se ha de enviar un ACK. Se debera enviar si:
	;    - Hay 512 bytes pendientes de ACK, o bien
	;    - Hay bytes pendientes de ACK y el temporizador de envio
	;      de ACK ha expirado

	ld	a,(ACK_PENDING)	;Hay ACK pendiente que no es
	or	a	;por recepcion de datos?
	jr	nz,DO_ACK_PEND

	ld	hl,(ACK_RCV_NUM)	;Hay datos para ACKear?
	ld	a,h
	or	l
	jr	z,NO_ACK_PEND

	ld	a,h	;Hay al menos 512?
	cp	2	;or      a
	jr	nc,DO_ACK_PEND

	ld	a,(ACK_DELAY_T)	;El temporizador ha expirado?
	or	a
	jr	nz,NO_ACK_PEND

DO_ACK_PEND:	call	SEND_ACK
	;jr      END_PROC_TCP
NO_ACK_PEND:

	;--- Fin

END_PROC_TCP:	jp	SAVE_TCB


;********************
;***              ***
;***  SUBRUTINAS  ***
;***              ***
;********************

	;===================================
	;===  Manejo de slots y memoria  ===
	;===================================

;--- GETSLOT2: Devuelve en A el slot conectado en pagina 2

_GETSLOT2:	di
	exx
	in	a,(#A8)
	ld	e,a
	and	%00110000
	sra	a
	sra	a
	sra	a
	sra	a
	ld	c,a	;C = Slot
	ld	b,0
	ld	hl,EXPTBL
	add	hl,bc
	bit	7,(hl)
	jr	z,NOEXP2
EXP2:	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	and	%00110000
	sra	a
	sra	a
	or	c
	or	#80
	ld	c,a
NOEXP2:	ld	a,c
	exx
	ret


;--- PUTLOT2: Conecta el slot A en pagina 2 solo si es distinto de B

_PUTSLOT2:	cp	b
	ret	z
	ld	h,#80
	call	ENASLT
	ei
	ret


;--- SETUP_P2 y RESTORE_P2: Establecen el segmento de variables en pag. 2
;    y restauran el antiguo, respectivamente

SETUP_P2:	push	af
	call	GET_P2
	push	af
	ld	a,(P3_SEG2)
	call	PUT_P2
	pop	af
	ld	(R_SEGP2),a
	pop	af
	ret

RESTORE_P2:	push	af
	ld	a,(R_SEGP2)
	call	PUT_P2
	pop	af
	ret


;--- TPA2SEG: Convierte la direccion TPA pasada en HL
;    en un segmento devuelto en A, y una dir de pag 1 en HL

TPA2SEG:	ld	a,h
	rlca
	rlca
	cpl
	and	3

	res	7,h
	set	6,h
	ret


;--- LDIR_ST: Copia un bloque de datos de TPA al segmento de datos
;    Entrada: HL = Origen
;             DE = Destino (dir de pag 2)
;             BC = Longitud

LDIR_ST:	call	TPA2SEG
	push	hl
	pop	ix	;IX = Dir origen en pag 1

	set	7,d
	res	6,d
LDIR_XX:	push	de
	pop	iy	;IY = Dir destino en pag 2

	ld	hl,(#F344)
	ld	h,a	;H = Segmento TPA, L = Slot
	jp	LDIRP3


;--- LDIR_TS: Copia un bloque de datos del segmento de datos a TPA
;    Entrada: HL = Origen (dir de pag 2)
;             DE = Destino
;             BC = Longitud

LDIR_TS:	ex	de,hl
	call	TPA2SEG
	ex	de,hl
	set	7,h
	res	6,h
	push	hl
	pop	ix	;IX = Dir origen en pag 2

	res	7,d	;IY = Dir destino en pag 1
	set	6,d
	jr	LDIR_XX


	;=========================================
	;===  Rutinas aritmeticas y de cadena  ===
	;=========================================

;--- NOMBRE: COMP
;      Comparacion de HL con DE (16 bits en complemento a 2)
;    ENTRADA:   HL, DE = numeros a comparar
;    SALIDA:     C, NZ si HL > DE
;                C,  Z si HL = DE
;               NC, NZ si HL < DE
;    REGISTROS: -

COMP:	call	_COMP16
	ccf
	ret

_COMP16:	ld	a,h
	sub	d
	ret	nz
	ld	a,l
	sub	e
	ret


;--- Checksum

;Entrada: IX = Direccion, BC = Longitud en bytes
;Admite BC impar sin necesidad de un 0 de relleno

; Compute checksum
;
; On entry:
;             IX -> block to checksum
;             BC = number of halfwords to checksum
;
; On exit:
;             DE = checksum
;             Z set if DE = 0 (i.e. checksum good)
;             A, BC and other flags corrupt

CALC_CHKSUM:	ld	de,0

CALC_CHKSUMP:	bit	0,c
	ld	a,0
	jr	z,CALC_CHKSUMP2
	dec	bc	;Si BC es impar, le resta 1
	ld	a,#FF

CALC_CHKSUMP2:	sra	b	;Convierte BC a words-16
	rr	c
	ld	(CHK_EVEN),a

	push	hl
	ex	de,hl
	push	ix
	or	a
	push	af
	jr	CHK_CHZERO	;Por si BC era 1 y ahora es 0

CALC_CHKLOOP:
	pop	af	; 3N
	ld	e,(ix + 0)	; 5N
	ld	d,(ix + 1)	; 5N
	adc	hl,de	; 4N
	push	af	; 3N
	inc	ix	; 3N
	inc	ix	; 3N
	dec	bc	; 2N
CHK_CHZERO:	ld	a,b	; 1N
	or	c	; 1N
	jr	nz,CALC_CHKLOOP	; 3/2N -> 33N per halfword

	ld	a,(CHK_EVEN)
	or	a
	jr	z,CHK_NOEVEN

	pop	af	;Si longitud impar, tratamos
	ld	e,(ix)	;el ultimo byte de forma especial
	ld	d,0
	adc	hl,de
		push	af

CHK_NOEVEN:	pop	af
	ld	de,1
	adc	hl,de	;add???????
	ex	de,hl

	pop	ix
	pop	hl

	dec	de
	ld	a,d
	cpl
	ld	d,a
	ld	a,e
	cpl
	ld	e,a
	ret

CHK_EVEN:	db	0


;--- MD5 Message-Digest algorithm for Z80 processor
;    Conforming to RFC1321
;    By Nestor Soriano (Konami Man), 27-5-2001
;    http://www.konamiman.com
;    <konamiman@konamiman.com>

	;Input:  HL = Address of message to digest
	;        BC = Length of message in bytes (maximum 8191)
	;Output: HL = Address where calculated digest is stored

	;NOTE: A 72 byte buffer for padding must be placed
	;      IMMEDIATELY AFTER the message (that is, at address HL+BC)
	;For example:
	;      ld hl,MSG
	;      ld bc,18
	;      call MD5
	;      ret
	;MSG:  defb "This is a message!"
	;      defs 72

	;Only messages using complete bytes are supported
	;(that is, the number of bits must be multiple of 8)

	;This source code is for the MSX assembler COMPASS,
	;other assemblers may differ in the macros syntax

	;Some values for testing (taken from RFC1321):

	;MD5 ("") = d41d8cd98f00b204e9800998ecf8427e
	;MD5 ("a") = 0cc175b9c0f1b6a831c399e269772661
	;MD5 ("abc") = 900150983cd24fb0d6963f7d28e17f72
	;MD5 ("message digest") = f96b697d7cb7938d525a2f31aaf161d0
	;MD5 ("abcdefghijklmnopqrstuvwxyz") = c3fcd3d76192e4007dfb496cca67e13b
	;MD5 ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789") =
	;d174ab98d277d9f5a5611c2c9f419d9f
	;MD5 ("123456789012345678901234567890123456789012345678901234567890123456
	;78901234567890") = 57edf4a22be3c955ac49da2e2107b67a


	;--- Macro for 32 bit addition

m_add32:	macro	@a,@b	;Performs (@a) = (@a) + (@b)
	ld	hl,(@a)
	ld	bc,(@b)
	add	hl,bc
	ld	(@a),hl
	ld	hl,(@a+2)
	ld	bc,(@b+2)
	adc	hl,bc
	ld	(@a+2),hl
	endm


	;----------------------
	;---  MAIN PROGRAM  ---
	;----------------------

MD5:	ld	(MSG_PNT),hl
	ld	(MSG_LEN),bc

	;--- Step 1: append padding bits

	add	hl,bc
	ld	(hl),80h	;First adds the mandatory padding "1" bit
	inc	bc
	inc	hl

	ld	a,c
	and	3Fh
	cp	56
	jr	z,OKPAD1	;No more padding necessary if already
	sub	56	;congruent to 56 bytes, modulo 64
	neg
	and	3Fh	;Now A=Number of 0 bytes to add

	ld	b,a	;Adds padding "0" bits
PADLOOP:	ld	(hl),0
	inc	hl
	djnz	PADLOOP
OKPAD1:	;

	;--- Step 2: append length

	push	hl
	ld	hl,(MSG_LEN)
	ld	bc,(MSG_LEN)
	add	hl,bc
	add	hl,hl
	add	hl,hl
	push	hl
	pop	bc	;Now BC = Length of message in bits
	pop	hl
	ld	(hl),c
	inc	hl
	ld	(hl),b	;Appends length to the end of the message
	inc	hl

	ld	b,6	;Since length is 2 bytes long and
PADLOP2:	ld	(hl),0	;8 bytes are required, adds another
	inc	hl	;6 zero bytes
	djnz	PADLOP2

	ld	bc,(MSG_PNT)	;Calculates total message length
	or	a	;in bytes, which is multiple of 64
	sbc	hl,bc

	ld	b,6
PADLOP3:	srl	h	;Calculates the message length
	rr	l	;in blocks of 16 32-bit words
	djnz	PADLOP3	;(that is, divides length by 64)
	ld	(MSG_BLK),hl

	;--- Step 3: initialize buffer

	ld	hl,INIT_ABCD
	ld	de,BUF_A
	ld	bc,16
	ldir

	;--- Step 4: process blocks

	;* Copy current block to buffer X:
	;  No need for that! Message data is read directly,
	;  and value of (MSG_PNT) acts as the starting address of X

	;* Backup A,B,C,D

PBLOCKS:	ld	hl,BUF_A	;Sets buffers AA,BB,CC,DD
	ld	de,BUF_AA
	ld	bc,16
	ldir

	;* Rounds execution

	ld	hl,R_DATA
	ld	(ROUND_PNT),hl
	ld	a,1
	ld	(ROUND_N),a
	ld	(PAR_I),a

	call	ROUND
	call	ROUND
	call	ROUND
	call	ROUND

	;* Adds AA to A, BB to B, CC to C, DD to D

	m_add32	BUF_A,BUF_AA
	m_add32	BUF_B,BUF_BB
	m_add32	BUF_C,BUF_CC
	m_add32	BUF_D,BUF_DD

	;* Continues to next block, if any

	ld	bc,(MSG_BLK)
	dec	bc
	ld	a,b
	or	c
	jr	z,MD5END
	ld	(MSG_BLK),bc

	ld	hl,(MSG_PNT)	;Updates message pointer by adding 64
	ld	bc,64
	add	hl,bc
	ld	(MSG_PNT),hl
	jp	PBLOCKS

	;--- Step 5: output

MD5END:	ld	hl,BUF_A
	ret


	;--------------------------------
	;---  ROUTINES AND FUNCTIONS  ---
	;--------------------------------

	;--- Sets parameters for round execution and executes round;
	;    after each operation exchanges A,B,C,D, and after
	;    the entire round increases ROUND_N

ROUND:	ld	b,16	;There are 16 operations per round

DO_RLOOP:	push	bc
	ld	hl,(ROUND_PNT)
	ld	a,(hl)
	ld	(PAR_K),a	;Sets parameters and executes operation
	inc	hl
	ld	a,(hl)
	ld	(PAR_S),a
	inc	hl
	ld	(ROUND_PNT),hl
	call	ROUND_OP
	call	SH_ABCD	;After each operation A,B,C,D are shifted
	ld	hl,PAR_I	;and PAR_I is increased
	inc	(hl)
	pop	bc
	djnz	DO_RLOOP

	ld	hl,ROUND_N	;After the 16 operations, round number
	inc	(hl)	;is increased
	ret

	;--- SH_ABCD: Transforms ABCD into DABC, DABC into CDAB, CDAB into BCDA,
	;             or BCDA into ABCD

SH_ABCD:	ld	hl,BUF_D+3	;D->temp
	ld	de,RES_FGHI+3
	ld	bc,4
	lddr

	ld	de,BUF_D+3
	ld	c,12	;C->D, B->C, A->B
	lddr

	ld	hl,RES_FGHI+3
	ld	c,4	;temp->A
	lddr

	ret

	;--- Function for ROUND operation execution
	;    Executes  A = B + ((A + F/G/H/I(B,C,D) + X[k] + T[i]) <<< s)
	;              where F,G,H,I is choosen when ROUND_N is 1,2,3,4 respectively
	;    Input:  PAR_K, PAR_S and PAR_I appropriately set
	;            ABCD buffer approriately rotated so it is ABCD,DABC,CDAB or BCDA
	;            ROUND_N set to 1,2,3 or 4
	;    Output: BUF_A with the result of the operation

ROUND_OP:	ld	a,(ROUND_N)	;Calls function F,G,H or I
	ld	hl,FUN_F	;depending on the round number
	dec	a
	jr	z,OKR1
	ld	hl,FUN_G
	dec	a
	jr	z,OKR1
	ld	hl,FUN_H
	dec	a
	jr	z,OKR1
	ld	hl,FUN_I
OKR1:	ld	de,OKR2
	push	de
	jp	(hl)
OKR2:	;

	m_add32	BUF_A,RES_FGHI	;Adds A to the result of F/G/H/I
	;                        ;and stores result on A

	ld	a,(PAR_K)	;Adds X[k] to the previous result
	ld	ix,(MSG_PNT)	;and stores it to A again.
	call	ADD_XT	;Note that actually no X buffer is used.

	ld	a,(PAR_I)	;Adds T[i] to the previous result
	dec	a	;ans stores it to A again
	ld	ix,BUF_T
	call	ADD_XT

	ld	ix,BUF_A	;Shifts s bits A
	ld	a,(PAR_S)
	ld	b,a
	call	SHIFT

	m_add32	BUF_A,BUF_B	;Finally, adds B to A

	ret

ADD_XT:	ld	c,a	;Routine for adding X[k] or T[i] to A
	ld	b,0	;Input: IX=(MSG_PNT) and A=(PAR_K)
	add	ix,bc	;or IX=BUF_T and A=(PAR_I)-1
	add	ix,bc
	add	ix,bc
	add	ix,bc
	ld	l,(ix+0)
	ld	h,(ix+1)
	ld	de,(BUF_A)
	add	hl,de
	ld	(BUF_A),hl
	ld	l,(ix+2)
	ld	h,(ix+3)
	ld	de,(BUF_A+2)
	adc	hl,de
	ld	(BUF_A+2),hl
	ret

	;--- Circular left shifting of a 32 bit word (stored low byte first)
	;    Input: IX = Pointer to the word, B = Positions to shift

SHIFT:	sla	(ix+0)
	rl	(ix+1)
	rl	(ix+2)
	rl	(ix+3)
	jr	nc,SHIFT2
	set	0,(ix+0)
SHIFT2:	djnz	SHIFT
	ret

	;--- Function F

nXaZ:	macro	@n	;Calculates "not(X) and Z"
	ld	a,(ix+@n)	;for the byte @n (0 to 3)
	cpl		;                ;of the 32-bit word
	and	(ix+8+@n)
	ld	(iy+@n),a
	endm

XaYo:	macro	@n	;Calculates "X and Y or nXaZ"
	ld	a,(ix+@n)
	and	(ix+4+@n)
	or	(iy+@n)
	ld	(iy+@n),a
	endm

FUN_F:	call	FUN_SETP

	nXaZ	0
	nXaZ	1
	nXaZ	2
	nXaZ	3

	XaYo	0
	XaYo	1
	XaYo	2
	XaYo	3

	ret

	;--- Function G

nZaY:	macro	@n	;Calculates "not(Z) and Y"
	ld	a,(ix+8+@n)
	cpl
	and	(ix+4+@n)
	ld	(iy+@n),a
	endm

XaZo:	macro	@n	;Calculates "X and Z or nZaY"
	ld	a,(ix+@n)
	and	(ix+8+@n)
	or	(iy+@n)
	ld	(iy+@n),a
	endm

FUN_G:	call	FUN_SETP

	nZaY	0
	nZaY	1
	nZaY	2
	nZaY	3

	XaZo	0
	XaZo	1
	XaZo	2
	XaZo	3

	ret

	;--- Function H

XxYxZ:	macro	@n	;Calculates "X xor Y xor Z"
	ld	a,(ix+@n)
	xor	(ix+4+@n)
	xor	(ix+8+@n)
	ld	(iy+@n),a
	endm

FUN_H:	call	FUN_SETP

	XxYxZ	0
	XxYxZ	1
	XxYxZ	2
	XxYxZ	3

	ret

	;--- Function I

XonZ:	macro	@n	;Calculates "X or (not Z)"
	ld	a,(ix+8+@n)
	cpl
	or	(ix+@n)
	ld	(iy+@n),a
	endm

Yx:	macro	@n	;Calculates "Y xor XonZ"
	ld	a,(ix+4+@n)
	xor	(iy+@n)
	ld	(iy+@n),a
	endm

FUN_I:	call	FUN_SETP

	XonZ	0
	XonZ	1
	XonZ	2
	XonZ	3

	Yx	0
	Yx	1
	Yx	2
	Yx	3

	ret

	;--- Initial pointer setting for functions

FUN_SETP:	ld	ix,PAR_X
	ld	iy,RES_FGHI
	ret


	;-------------------
	;---  DATA AREA  ---
	;-------------------

	;*** Do not modify the buffers order in memory ***

	;--- Data for round execution
	;    Parameter I is omitted, since it is always the one for the
	;    previous operation plus one

R_DATA:
	;* ROUND 1

	defb	0,7
	defb	1,12
	defb	2,17
	defb	3,22
	defb	4,7
	defb	5,12
	defb	6,17
	defb	7,22
	defb	8,7
	defb	9,12
	defb	10,17
	defb	11,22
	defb	12,7
	defb	13,12
	defb	14,17
	defb	15,22

	;* ROUND 2

	defb	1,5
	defb	6,9
	defb	11,14
	defb	0,20
	defb	5,5
	defb	10,9
	defb	15,14
	defb	4,20
	defb	9,5
	defb	14,9
	defb	3,14
	defb	8,20
	defb	13,5
	defb	2,9
	defb	7,14
	defb	12,20

	;* ROUND 3

	defb	5,4
	defb	8,11
	defb	11,16
	defb	14,23
	defb	1,4
	defb	4,11
	defb	7,16
	defb	10,23
	defb	13,4
	defb	0,11
	defb	3,16
	defb	6,23
	defb	9,4
	defb	12,11
	defb	15,16
	defb	2,23

	;* ROUND 4

	defb	0,6
	defb	7,10
	defb	14,15
	defb	5,21
	defb	12,6
	defb	3,10
	defb	10,15
	defb	1,21
	defb	8,6
	defb	15,10
	defb	6,15
	defb	13,21
	defb	4,6
	defb	11,10
	defb	2,15
	defb	9,21

	;--- Result of F/G/H/I functions

RES_FGHI:	defs	4

	;---- Buffers for A,B,C,D,AA,BB,CC,DD

BUF_A:	defs	4
BUF_B:	defs	4
BUF_C:	defs	4
BUF_D:	defs	4
BUF_AA:	defs	4
BUF_BB:	defs	4
BUF_CC:	defs	4
BUF_DD:	defs	4

	;--- Buffers for parameters X,Y,Z to use on functions F,G,H,I
	;    (must be consecutive in memory)
	;    Since these functions are always called with (X,Y,Z)=(B,C,D),
	;    actually no buffers are defined but B,C,D buffers are directly referred

PAR_X:	equ	BUF_B
PAR_Y:	equ	BUF_C
PAR_Z:	equ	BUF_D

	;--- Initial values for BUF_A/B/C/D

INIT_ABCD:	defb	1h,23h,45h,67h
	defb	89h,0ABh,0CDh,0EFh
	defb	0FEh,0DCh,0BAh,98h
	defb	76h,54h,32h,10h

	;--- Some variables

MSG_LEN:	defw	0	;Message length in bytes (without padding)
MSG_BLK:	defw	0	;Message length in blocks of 32-bit words
MSG_PNT:	defw	0	;Pointer to the start of next block
PAR_K:	defb	0	;Parameters k,s,i for round steps
PAR_S:	defb	0
PAR_I:	defb	0
ROUND_N:	defb	0	;Current round number (1 to 4)
ROUND_PNT:	defw	0	;Current round data pointer

	;--- Sinus table for function T

BUF_T:	defw	0A478h,0D76Ah,0B756h,0E8C7h,070DBh,02420h,0CEEEh,0C1BDh
	defw	0FAFh,0F57Ch,0C62Ah,04787h,04613h,0A830h,09501h,0FD46h
	defw	098D8h,06980h,0F7AFh,08B44h,05BB1h,0FFFFh,0D7BEh,0895Ch
	defw	01122h,06B90h,07193h,0FD98h,0438Eh,0A679h,0821h,049B4h
	defw	02562h,0F61Eh,0B340h,0C040h,05A51h,0265Eh,0C7AAh,0E9B6h
	defw	0105Dh,0D62Fh,01453h,0244h,0E681h,0D8A1h,0FBC8h,0E7D3h
	defw	0CDE6h,021E1h,07D6h,0C337h,0D87h,0F4D5h,014EDh,0455Ah
	defw	0E905h,0A9E3h,0A3F8h,0FCEFh,02D9h,0676Fh,04C8Ah,08D2Ah
	defw	03942h,0FFFAh,0F681h,08771h,06122h,06D9Dh,0380Ch,0FDE5h
	defw	0EA44h,0A4BEh,0CFA9h,04BDEh,04B60h,0F6BBh,0BC70h,0BEBFh
	defw	07EC6h,0289Bh,027FAh,0EAA1h,03085h,0D4EFh,01D05h,0488h
	defw	0D039h,0D9D4h,099E5h,0E6DBh,07CF8h,01FA2h,05665h,0C4ACh
	defw	02244h,0F429h,0FF97h,0432Ah,023A7h,0AB94h,0A039h,0FC93h
	defw	059C3h,0655Bh,0CC92h,08F0Ch,0F47Dh,0FFEFh,05DD1h,08584h
	defw	07E4Fh,06FA8h,0E6E0h,0FE2Ch,04314h,0A301h,011A1h,04E08h
	defw	07E82h,0F753h,0F235h,0BD3Ah,0D2BBh,02AD7h,0D391h,0EB86h

	;Note: the sinus table has been generated
	;with the following MSX-BASIC program:

	;1   'Sinus table generator for MD5 algorithm
	;2   'By Nestor Soriano, 27-5-2001
	;10  OPEN"md5sin.asm" FOR OUTPUT AS#1
	;20  PRINT"Generating file..."
	;30  FOR I1=0 TO 15
	;40    PRINT#1,"   defw ";
	;50    FOR I2=0 TO 3
	;60      S=INT((ABS(SIN(I1*4+I2+1)))*2^32)
	;70      SH=INT(S/65536!)
	;80      SL=S-SH*65536!
	;90      PRINT#1,"0";HEX$(SL);"h,0";HEX$(SH);"h";
	;100     IF I2<3 THEN PRINT#1,",";
	;110   NEXT I2:PRINT#1,""
	;120 NEXT I1
	;130 CLOSE#1
	;140 PRINT"Done. Resulting file:"
	;150 COPY"md5sin.asm"TO"con"


;--- PARSE_IP: Extrae una direccion IP a partir de una cadena
;    Entrada:  Cadena en DNS_BUFFER, acabada en 0
;    Salida:   Cy=0 y IP en DNS_RESULT, o Cy=1 si no es una IP valida
;              En cualquier caso vuelve con la cadena acabada en 0

PARSE_IP:	ld	hl,DNS_BUFFER
PARSE_IPL:	ld	a,(hl)
	or	a
	jr	z,PARSE_IP2	;Pone punto al final para facilitar procesado
	inc	hl
	jr	PARSE_IPL
PARSE_IP2:	ld	(hl),"."
	ld	(PARSE_IPDIR),hl

	ld	de,DNS_RESULT
	ld	hl,DNS_BUFFER
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


	;========================================
	;===  Envio de paquetes determinados  ===
	;========================================

;--- Rutina generica de envio de paquetes (a nivel fisico).
;    Asume que la parte de datos del paquete esta en OUT_BUFFER+4.
;    Entrada: HL=Puntero a la dir HW de destino
;             DE=Ether-type

SEND_PACKET:

	;--- Establece Ether-Type

	ld	a,d
	ld	(OUT_BUFFER+2),a
	ld	a,e
	ld	(OUT_BUFFER+3),a

	;--- Obtiene la longitud.
	;    Estara en OUT_BUFFER+6 si es IP,
	;    si es ARP sera 28.

	push	hl

	ld	hl,#0800
	call	COMP
	ld	hl,28
	jr	nz,SEND_PAQ_2

	ld	a,(OUT_BUFFER+6)
	ld	h,a
	ld	a,(OUT_BUFFER+7)
	ld	l,a

	ld	de,576	;Si demasiado grande, reduce a 576
	call	COMP
	jr	nc,SEND_PAQ_2
	ex	de,hl
SEND_PAQ_2:	ex	(sp),hl	;Long. en pila, HL=Dir HW

	;--- Decide tipo de trama a enviar

	ld	a,(FRAME_TYPE)
	or	a
	jr	nz,SEND_IEEE

	;--- Trama de tipo Ethernet 2

SEND_ETH2:
	ld	de,OUT_BUFFER-10	;Dir de destino
	ld	bc,6
	ldir

	ld	hl,HWAD	;Dir de origen
	ld	de,OUT_BUFFER-4
	ld	bc,6
	ldir

	pop	hl	;Actualiza longitud
	ld	bc,14
	add	hl,bc
	push	hl
	pop	bc

	ld	hl,OUT_BUFFER-10

	ld	a,1
	obsonet	_SEND_PACKET
	ret

	;--- Trama de tipo IEEE802.3

SEND_IEEE:
	ld	de,OUT_BUFFER-18	;Dir de destino
	ld	bc,6
	ldir

	ld	hl,HWAD	;Dir de origen
	ld	de,OUT_BUFFER-12
	ld	bc,6
	ldir

	ld	hl,SNAP_HDR	;Cabecera SNAP
	ld	de,OUT_BUFFER-4
	ld	bc,6
	ldir

	pop	hl	;Establece longitud...
	ld	bc,8
	add	hl,bc
	ld	a,h
	ld	(OUT_BUFFER-6),a
	ld	a,l
	ld	(OUT_BUFFER-5),a
	ld	bc,14
	add	hl,bc	;...y la actualiza
	push	hl
	pop	bc

	ld	hl,OUT_BUFFER-18

	ld	a,1
	obsonet	_SEND_PACKET
	ret

SNAP_HDR:	db	170,170,3,0,0,0


;--- Envio de una peticion ARP
;    Entrada: L.H.E.D = Dir que se pregunta
;             BC = Dir de envio (NO! Siempre a broadcast)

SEND_ARP_RQ:	ld	(ARPRQ_IPRCV),hl	;IP destino
	ld	(ARPRQ_IPRCV+2),de

	;ld      hl,ARPRQ_HWRCV  ;MAC destino=0 (desconocida)
	;ld      de,ARPRQ_HWRCV+1
	;ld      (hl),0
	;ld      bc,5
	;ldir

	;push	bc

	ld	hl,BUF_IPLOCAL	;IP origen
	ld	de,ARPRQ_IPSND
	ld	bc,4
	ldir

	ld	hl,HWAD	;MAC origen
	ld	de,ARPRQ_HWSND
	ld	bc,6
	ldir

	ld	hl,ARP_RQ	;Copiamos paquete a OUT_BUFFER
	ld	de,OUT_BUFFER+4
	ld	bc,28
	ldir

	;pop	hl	;Enviamos paquete a la dir adecuada
	ld	hl,ETH_BROAD
	ld	de,#0806
	jp	SEND_PACKET

	;Paquete ARP Request

ARP_RQ:	db	0,1,8,0,6,4,0,1
ARPRQ_HWSND:	ds	6
ARPRQ_IPSND:	ds	4
ARPRQ_HWRCV:	ds	6	;Siempre a 0
ARPRQ_IPRCV:	ds	4

ETH_BROAD:	ds	6,#FF


;--- Envio de un paquete ARP Reply
;    Entrada: ARP Request recibido en IN_BUFFER+4

SEND_ARP_RP:	ld	hl,IN_BUFFER+4	;Copia cabecera,
	ld	de,OUT_BUFFER+4	;cambiando REQUEST por REPLY
	ld	bc,7
	ldir
	ld	a,2
	ld	(de),a
	inc	de

	ld	hl,HWAD	;MAC origen
	;ld	de,OUT_BUFFER+12
	ld	bc,6
	ldir

	ld	hl,BUF_IPLOCAL	;IP origen
	;ld	de,OUT_BUFFER+18
	ld	bc,4
	ldir

	ld	hl,IN_BUFFER+12	;Copia datos de SENDER en RECEIVER
	;ld	de,OUT_BUFFER+22
	ld	bc,10
	ldir

	ld	hl,OUT_BUFFER+22	;Enviamos paquete
	ld	de,#0806
	jp	SEND_PACKET


;--- Rutina generica de envio de datagramas IP.
;    Entrada: L.H.E.D = IP de destino
;             BC = Longitud datos
;             A = Protocolo
;             Datos ya copiados en OUT_BUFFER+24

SEND_IP:	call	PREPARE_IP	;Establece IPs y protocolo

	;> Si se salta aqui: Entrada: BC = Longitud datos

SEND_IP2:	;* Establece longitud

	ld	hl,20
	add	hl,bc
	ld	a,h	;Longitud (datos+cabecera)
	ld	(OUT_BUFFER+6),a
	ld	a,l
	ld	(OUT_BUFFER+7),a

	;* Establece otros parametros

	ld	a,#45	;Version IP + Long cabecera
	ld	(OUT_BUFFER+4),a

	ld	a,(TOS)	;Type Of Service
	ld	(OUT_BUFFER+5),a

	ld	hl,(ID_IP)	;Identificador
	ld	a,h
	ld	(OUT_BUFFER+8),a
	ld	a,l
	ld	(OUT_BUFFER+9),a
	inc	hl
	ld	(ID_IP),hl

	ld	a,(TTL)	;Time To Live
	ld	(OUT_BUFFER+12),a

	;* Calcula checksum

	ld	ix,OUT_BUFFER+4
	ld	bc,20
	call	CALC_CHKSUM
	ld	(OUT_BUFFER+14),de

	;>>> El datagrama esta completo.
	;>>> Ahora hemos de preocuparnos de ARP, enrutamiento, etc.
	;    Entrada: HL=Puntero a la dir IP de envio

SEND_IP_ETH0:	xor	a
	ld	(IS_ROUTER),a

	ld	hl,OUT_BUFFER+20

SEND_IP_ETH:	ld	de,IP_TO_SEND
	ld	bc,4
	ldir

	;--- Si la IP es de broadcast (mascara OR IP = 255.255.255.255),
	;    se envia a la dir HW de broadcast (todo #FFs)

	ld	hl,SUBNET_MASK
	ld	de,IP_TO_SEND
	ld	b,4
CHKIPBROAD:	ld	a,(de)
	or	(hl)
	inc	a
	jr	nz,SEND_IP_NOBRO
	inc	hl
	inc	de
	djnz	CHKIPBROAD

	ld	hl,ETH_BROAD
	ld	de,#0800
	jp	SEND_PACKET
SEND_IP_NOBRO:

	;--- Primero comprobamos si hay una entrada para esa IP
	;    en la cache ARP

	ld	de,IP_TO_SEND
	call	SRCH_ARP
	jr	c,SIPE_NOARP

	;* Si la entrada esta en resolucion, terminar ya

	ld	a,(ix)
	cp	3
	jp	z,COPY_TO_WOUT

	;* Si no, enviar el paquete a esa dir MAC

	push	ix
	pop	hl
	inc	hl
	ld	de,#0800
	jp	SEND_PACKET
SIPE_NOARP:

	;--- Comprobamos si la IP de destino esta en nuestra misma red,
	;    o si la mascara de red es 0.
	;    Si es asi, hacemos envio directo, para lo cual
	;    efectuamos una consulta ARP.

	ld	a,(IS_ROUTER)	;La IP ya es un router:
	or	a	;usa ARP local (estara en la misma subred,
	jr	nz,SI_SAME_SUB	;o si no, confiamos en Proxy-ARP).

	ld	hl,SUBNET_MASK	;Mascara 0: usa ARP local
	ld	de,ZERO32	;confiando en que haya Proxy-ARP.
	call	COMP32
	jr	z,SI_SAME_SUB

	ld	de,IP_TO_SEND
	ld	hl,BUF_IPLOCAL
	ld	ix,SUBNET_MASK
	call	SAME_SUBNET
	jr	nc,NO_SAME_SUB

SI_SAME_SUB:	call	COPY_TO_WOUT
	ld	hl,IP_TO_SEND
	call	NEW_ARP
	ret
NO_SAME_SUB:

	;--- Buscamos en la tabla de enrutamiento

	ld	iy,ROUTE_TABLE
	ld	b,ROUTE_ENTRIES

SRCHROU_LOOP:	push	bc
	ld	a,(iy)
	or	a
	ld	bc,16
	jr	z,SRCHROU_NXT

	push	iy
	pop	hl
	inc	hl	;HL=Dir subred enrutada
	ld	de,IP_TO_SEND	;DE=Dir de envio
	ld	bc,5
	add	iy,bc
	push	iy
	pop	ix	;IX=Mascara
	call	SAME_SUBNET
	ld	bc,11
	jr	nc,SRCHROU_NXT

	pop	bc
	push	iy
	pop	hl
	inc	hl
	inc	hl
	inc	hl
	inc	hl	;HL=Puntero a la dir router a enviar

	ld	a,#FF
	ld	(IS_ROUTER),a
	jp	SEND_IP_ETH	;No hay peligro de bucle infinito,
	;porque ahora la dir SI estara en la misma subred.

SRCHROU_NXT:	add	iy,bc
	pop	bc
	djnz	SRCHROU_LOOP

	;--- No hay entrada de enrutamiento.
	;    Si hay gateway por defecto, lo usa.
	;    Si no, usa ARP local (confia en que haya Proxy-ARP).

	ld	hl,DEFGW
	ld	de,ZERO32
	call	COMP32
	jr	z,SI_SAME_SUB

	ld	a,#FF
	ld	(IS_ROUTER),a
	ld	hl,DEFGW
	jp	SEND_IP_ETH

	;--- Copia el datagrama a WOUT_BUFFER para ser enviado
	;    cuando tengamos la entrada ARP resuelta

COPY_TO_WOUT:	ld	hl,IP_TO_SEND
	ld	de,WOUT_IP
	ld	bc,4
	ldir

	;ld      a,(OUT_BUFFER+6)
	;ld      b,a
	;ld      a,(OUT_BUFFER+7)
	;ld      c,a
	ld	bc,576
	ld	hl,OUT_BUFFER+4
	ld	de,WOUT_BUFFER
	ldir

	ret

IP_TO_SEND:	ds	4
IS_ROUTER:	db	0


;--- PREPARE_IP: Borra la cabecera IP del datagrama de salida,
;    y establece la IP fuente, la IP de destino (L.H.E.D)
;    y el protocolo (A).

PREPARE_IP:	push	hl,de,bc

	ld	hl,OUT_BUFFER+4	;Borra cabecera
	ld	de,OUT_BUFFER+5
	ld	bc,19
	ld	(hl),0
	ldir

	ld	hl,BUF_IPLOCAL	;IP fuente
	ld	de,OUT_BUFFER+16
	ld	bc,4
	ldir

	pop	bc,de,hl
	ld	(OUT_BUFFER+13),a	;Protocolo
	ld	(OUT_BUFFER+20),hl	;IP destino
	ld	(OUT_BUFFER+22),de

	ret


;--- SEND_UDP: Envio de un datagrama UDP.
;    Entrada: L.H.E.D = IP de destino
;	BC = Longitud datos
;	IX = Puerto de origen
;	IY = Puerto de destino
;       Datos ya copiados en OUT_BUFFER+32

SEND_UDP:	ld	a,17
	call	PREPARE_IP	;IPs y protocolo

	push	ix	;Puertos
	pop	hl
	push	iy
	pop	de
	ld	ix,OUT_BUFFER+24
	ld	(ix),h
	ld	(ix+1),l
	ld	(ix+2),d
	ld	(ix+3),e

	ld	hl,8	;Longitud total UDP
	add	hl,bc
	ld	(ix+4),h
	ld	(ix+5),l

	ld	(ix+6),0	;Checksum
	ld	(ix+7),0
	push	hl,hl
	pop	bc
	ld	(ix-10),b
	ld	(ix-9),c	;Longitud UDP en el checksum IP
	ld	hl,12
	add	hl,bc	;Para que incluya pseudo-cabecera
	push	hl
	pop	bc
	ld	ix,OUT_BUFFER+12	;Ver explicacion del truco en IS_UDP
	call	CALC_CHKSUM
	ld	(OUT_BUFFER+30),de

	ld	hl,0	;Deja el checksum IP otra vez a 0
	ld	(OUT_BUFFER+14),hl

	pop	bc
	jp	SEND_IP2


;--- SEND_DHCP: Envia un paquete DHCP del tipo indicado en A

;DHCP_SNDTYPE:    equ     OUT_BUFFER+274   ;Sera la primera opcion

SEND_DHCP:

	;--- Inicializacion comun

	ld	hl,OUT_BUFFER+32	;Limpia el bufer de salida
	ld	de,OUT_BUFFER+32+1
	ld	bc,576-32-1
	ld	(hl),0
	ldir

	ld	(OUT_BUFFER+274),a	;Establece el tipo de mensaje

	ld	hl,#0101	;Cabecera comun ('op' a 'hops')
	ld	(OUT_BUFFER+32),hl
	ld	hl,#0006
	ld	(OUT_BUFFER+34),hl

	;--- 'xid': en DHCPREQUEST en estado SELECTING o REQUESTING,
	;    usar el ultimo recibido; en otros casos, el ultimo enviado mas uno

	ld	b,a
	cp	DHCPREQUEST
	jr	nz,SDHCP_OWNXID

	ld	a,(DHCP_STATE)
	cp	SELECTING
	jr	z,SDHCP_LASTXID
	cp	REQUESTING
	jr	nz,SDHCP_OWNXID

SDHCP_LASTXID:	ld	a,b
	ld	hl,DHCP_RCVXID
	jr	SDHCP_OKXID

SDHCP_OWNXID:	ld	a,b
	ld	hl,DHCP_XID
	ld	bc,DHCP_XID
	push	af
	call	INC32
	pop	af
	ld	hl,DHCP_XID

SDHCP_OKXID:	ld	de,OUT_BUFFER+36
	ld	bc,4
	ldir

	;--- 'secs': en DHCPDECLINE o DHCPRELEASE, 0;
	;    en otros casos, DHCP_SECS
	;    'flags': en DHCPDECLINE o DHCPRELEASE, 0;
	;    en otros casos, #8000

	cp	DHCPDECLINE
	jr	z,SDHCP_OKSECS
	cp	DHCPRELEASE
	jr	z,SDHCP_OKSECS

	ld	hl,(DHCP_SECS)
	ld	b,a
	ld	a,h
	ld	h,l
	ld	l,a
	ld	a,b
	ld	(OUT_BUFFER+40),hl

	ld	hl,#0080
	ld	(OUT_BUFFER+42),hl
SDHCP_OKSECS:

	;--- 'ciadr': direccion IP propia si:
	;    * El paquete es DHCPINFORM o DHCPRELEASE
	;    * El paquete es DHCPREQUEST en BOUND/RENEW/REBIND

	cp	DHCPINFORM
	jr	z,SDHCP_DOCIADR
	cp	DHCPRELEASE
	jr	z,SDHCP_DOCIADR
	cp	DHCPREQUEST
	jr	nz,SDHCP_OKCIADR

	ld	b,a
	ld	a,(DHCP_STATE)
	cp	BOUND
	jr	z,SDHCP_DOCIADR
	cp	RENEWING
	jr	z,SDHCP_DOCIADR
	cp	REBINDING
	ld	a,b
	jr	nz,SDHCP_OKCIADR

SDHCP_DOCIADR:	ld	a,b
	ld	hl,BUF_IPLOCAL
	ld	de,OUT_BUFFER+44
	ld	bc,4
	ldir
SDHCP_OKCIADR:

	;--- 'chaddr': dir hardware

	ld	hl,HWAD
	ld	de,OUT_BUFFER+60
	ld	bc,6
	ldir

	;--- Opciones: primero, cookie magica y opcion "tipo de mensaje"

	ld	hl,DHCP_COOKIE
	ld	de,OUT_BUFFER+268
	ld	bc,6
	ldir

	;--- Resto de opciones: segun tipo de mensaje y DHCP_VECT

	ld	ix,OUT_BUFFER+275	;Puntero para anyadir opciones

	;* 'Requested IP': incluir si el mensaje es DHCPDECLINE,
	;  o si es DHCPREQUEST en estado SELECTING o REQUESTING.
	;  'Server identifier': Como el anterior, pero tambien
	;  si el mensaje es DHCPRELEASE.

	cp	DHCPRELEASE
	jr	z,SDHCP_DOSRVID
	cp	DHCPDECLINE
	jr	z,SDHCP_DOREQIP
	cp	DHCPREQUEST
	jr	nz,SDHCP_OKREQIP

	ld	b,a
	ld	a,(DHCP_STATE)
	cp	SELECTING
	jr	z,SDHCP_DOREQIP
	cp	REQUESTING
	ld	a,b
	jr	nz,SDHCP_OKREQIP

SDHCP_DOREQIP:	ld	a,b
	ld	(ix),50
	ld	(ix+1),4
	push	ix
	pop	de
	inc	de
	inc	de
	ld	hl,DHCP_YIADDR
	ld	bc,4
	ldir
	push	de
	pop	ix

SDHCP_DOSRVID:	ld	(ix),54
	ld	(ix+1),4
	push	ix
	pop	de
	inc	de
	inc	de
	ld	hl,DHCP_SERVER
	ld	bc,4
	ldir
	push	de
	pop	ix
SDHCP_OKREQIP:

	;* 'Parameter request': si no es DHCPDECLINE ni DHCPRELEASE,
	;  y segun DHCP_VECT
	;  'Maximum message size': si no es DHCPDECLINE ni DHCPRELEASE.

	cp	DHCPRELEASE
	jr	z,SDHCP_OKREQOPS
	cp	DHCPDECLINE
	jr	z,SDHCP_OKREQOPS

	ld	(ix),57	;"Maximum message size"
	ld	(ix+1),2
	ld	(ix+2),#02
	ld	(ix+3),#40
	inc	ix
	inc	ix
	inc	ix
	inc	ix

	ld	(ix),55	;"Parameter request list"
	inc	ix
	push	ix
	pop	hl
	inc	ix
	ld	b,0	;Longitud acumulada de la opcion
	ld	a,(DHCP_VECT)

	;Mascara de red

	bit	1,a
	jr	z,SDHCP_OKOPMASK

	ld	(ix),1
	inc	b
	inc	ix
SDHCP_OKOPMASK:

	;Router

	bit	2,a
	jr	z,SDHCP_OKOPROU

	ld	(ix),3
	inc	b
	inc	ix
SDHCP_OKOPROU:

	;Servidores DNS

	bit	3,a
	jr	z,SDHCP_OKOPDNS

	ld	(ix),6
	inc	b
	inc	ix
SDHCP_OKOPDNS:

	;Timeout ARP

	bit	4,a
	jr	z,SDHCP_OKARP

	ld	(ix),35
	inc	b
	inc	ix
SDHCP_OKARP:

	;Tipo de trama ethernet

	bit	5,a
	jr	z,SDHCP_OKFRM

	ld	(ix),36
	inc	b
	inc	ix
SDHCP_OKFRM:

	;Establece campo de longitud de la opcion

	ld	(hl),b
SDHCP_OKREQOPS:

	;--- Paquete completo: calcula tamanyo resultante

	push	ix
	pop	hl
	ld	bc,OUT_BUFFER+32
	or	a
	sbc	hl,bc
	push	hl
	pop	bc

	;--- Direccion IP de destino: si DHCP_SERVER es 0,
	;    o si es DHCPREQUEST en estado REQUESTING o REBINDING,
	;    envio a broadcast; si no, a esa direccion

	ld	a,(OUT_BUFFER+274)
	cp	DHCPREQUEST
	jr	nz,SDHCP_OKIPDEST

	ld	hl,#FFFF
	ld	de,#FFFF
	ld	a,(DHCP_STATE)
	cp	REBINDING
	jr	z,SDHCP_OKSNDIP
	cp	REQUESTING
	jr	z,SDHCP_OKSNDIP

SDHCP_OKIPDEST:	ld	hl,(DHCP_SERVER)
	ld	de,(DHCP_SERVER+2)
	ld	a,h
	or	l
	or	d
	or	e
	jr	nz,SDHCP_OKSNDIP

	dec	hl	;HL,DE=#FFFF (255.255.255.255)
	dec	de
SDHCP_OKSNDIP:

	;--- Fin: envia el paquete por UDP usando los puertos adecuados

	ld	ix,68
	ld	iy,67
	jp	SEND_UDP

DHCP_COOKIE:	db	99,130,83,99,53,1	;Incluye opcion "tipo de mensaje"


	;==========================================
	;===  Rutinas auxiliares para Ethernet  ===
	;==========================================

;--- SRCH_ARP: Busca una entrada en la tabla ARP para la IP dada
;    Entrada: DE=Puntero a dir IP a buscar
;    Salida:  IX=Dir de la entrada
;             Cy=1 si no se encuentra
;    Modifica AF, BC, DE, HL, IX

SRCH_ARP:	ld	ix,ARP_CACHE
	ld	b,ARP_ENTRIES
SRCH_ARP_LOOP:	push	bc

	;* Entrada vacia?

	ld	a,(ix)
	or	a
	jr	z,SRCH_ARP_NXT

	;* Coincide la IP?

	push	ix
	pop	hl
	ld	bc,7
	add	hl,bc
	push	de
	call	COMP32
	pop	de
	jr	nz,SRCH_ARP_NXT

	;* Entrada encontrada

	pop	bc
	or	a
	ret

	;* Siguiente entrada, si quedan

SRCH_ARP_NXT:	ld	bc,16
	add	ix,bc
	pop	bc
	djnz	SRCH_ARP_LOOP

	scf		;No encontrada
	ret


;--- SAME_SUBNET: Comprueba si unas IPs dadas estan en la misma subred.
;    Entrada: DE,HL=IPs a comprobar, IX=Mascara
;    Salida:  Cy=1 si lo estan, 0 si no.
;    Modifica AF, BC, DE, HL, IX

SAME_SUBNET:
	ld	b,4

SAME_SUBLOOP:	ld	a,(hl)
	and	(ix)
	ld	c,a
	ld	a,(de)
	and	(ix)
	cp	c
	scf
	ccf
	ret	nz
	inc	hl
	inc	de
	inc	ix
	djnz	SAME_SUBLOOP
	scf
	ret


;--- GET_FREE_ARP: Obtiene una entrada ARP libre
;    Salida: IX=Dir de la entrada

GET_FREE_ARP:

	;--- Primero busca una entrada que este vacia

	ld	ix,ARP_CACHE
	ld	b,ARP_ENTRIES
FREARP_LOP1:
	ld	a,(ix)
	or	a
	jr	z,FREARP_FOUND

	ld	de,16
	add	ix,de
	djnz	FREARP_LOP1

	;--- No hay entradas vacias.
	;    Busca la entrada dinamica mas cercana a su caducidad.

	ld	hl,#7F
	ld	(FREARP_TIMER),hl
	ld	hl,#FF
	ld	(FREARP_TIMER+2),hl
	ld	hl,0
	ld	(FREARP_DIR),hl
	ld	ix,ARP_CACHE
	ld	b,ARP_ENTRIES
FREARP_LOP2:	push	bc

	;* Comprueba que la entrada sea dinamica en uso

	ld	a,(ix)
	cp	2
	jr	nz,FREARP_NXT2

	;* Compara el ultimo temporizador con el actual,
	;  si el actual es menor, pone su dir en FREARP_DIR

	push	ix
	pop	hl
	ld	bc,11
	add	hl,bc
	ld	de,FREARP_TIMER
	push	hl
	call	COMP32	;NC si (HL)<(DE)
	pop	hl
	jr	c,FREARP_NXT2

	ld	de,FREARP_TIMER
	ld	bc,4
	ldir
	ld	(FREARP_DIR),ix

FREARP_NXT2:	ld	bc,16
	add	ix,bc
	pop	bc
	djnz	FREARP_LOP2

	;* Si no ha encontrado ninguna, devuelve la ultima entrada

	ld	ix,(FREARP_DIR)
	ld	a,ixh
	or	ixl
	jr	nz,FREARP_FOUND

	ld	ix,ARP_CACHE+16*(ARP_ENTRIES-1)
	ret

	;* Entrada encontrada

FREARP_FOUND:	ld	(ix),0
	ret

FREARP_DIR:	ds	2
FREARP_TIMER:	ds	4


;--- NEW_ARP: Crea una nueva entrada ARP dinamica para una IP dada,
;             y envia el primer paquete de peticion.
;    Entrada: HL=Dir de la IP a resolver

NEW_ARP:	push	hl

	;--- Primero busca una entrada que este vacia

	call	GET_FREE_ARP

	;--- Crea la entrada nueva y envia el primer ARP

	pop	iy
	ld	(ix),3
	;ld	(ix+1),0
	;ld	(ix+2),0
	;ld	(ix+3),0
	;ld	(ix+4),0
	;ld	(ix+5),0
	;ld	(ix+6),0
	ld	(ix+11),4*60
	ld	(ix+12),1
	ld	l,(iy)
	ld	h,(iy+1)
	ld	e,(iy+2)
	ld	d,(iy+3)
	ld	(ix+7),l
	ld	(ix+8),h
	ld	(ix+9),e
	ld	(ix+10),d

	;ld	bc,ETH_BROAD
	jp	SEND_ARP_RQ


	;======================================
	;===  Rutinas auxiliares para DHCP  ===
	;======================================

;--- DHCP_DO_INIT: Inicializa el automata en estado INIT

DHCP_DO_INIT:	call	CLOSE_ALL_TCP

	;* Borra todas las variables de DHCP excepto XID

	ld	hl,DHCP_VAR_START+4
	ld	de,DHCP_VAR_START+4+1
	ld	bc,DHCP_VAR_END-DHCP_VAR_START-4-1
	ld	(hl),0
	ldir
	xor	a
	ld	(DHCP_STATE),a
	ld	(DHCP_VECT_O),a

	;* Borra las IPs que sean apropiadas

	ld	a,(DHCP_VECT)
	ld	hl,0

	bit	0,a
	jr	z,DHCP2INIT_1
	ld	(BUF_IPLOCAL),hl
	ld	(BUF_IPLOCAL+2),hl
DHCP2INIT_1:

	bit	1,a
	jr	z,DHCP2INIT_2
	ld	(SUBNET_MASK),hl
	ld	(SUBNET_MASK+2),hl
DHCP2INIT_2:

	bit	2,a
	jr	z,DHCP2INIT_3
	ld	(DEFGW),hl
	ld	(DEFGW+2),hl
DHCP2INIT_3:

	bit	3,a
	jr	z,DHCP2INIT_4
	ld	(BUF_IPDNS1),hl
	ld	(BUF_IPDNS1+2),hl
	ld	(BUF_IPDNS2),hl
	ld	(BUF_IPDNS2+2),hl
DHCP2INIT_4:

	bit	4,a
	jr	z,DHCP2INIT_5
	ld	hl,ARP_TOUT_DEF
	ld	de,ARP_TOUT
	ld	bc,4
	ldir
	ld	hl,ARP_TOUT_DEF2
	ld	de,ARP_TOUT_SECS
	ld	bc,4
	ldir
DHCP2INIT_5:

	bit	5,a
	jr	z,DHCP2INIT_6
	ld	b,a
	xor	a
	ld	(FRAME_TYPE),a
	ld	a,b
DHCP2INIT_6:

	ret

ARP_TOUT_DEF:	db	#00,#00,#46,#50	;5 minutos * 60 segs * 60 ints
ARP_TOUT_DEF2:	db	#00,#00,#01,#2C	;5 minutos * 60 segs


;--- DHCP_NEXT_OP: Devuelve la siguiente opcion DHCP de la siguiente forma:
;    A=Codigo (0=no quedan mas)
;    B=Longitud
;    IX=Puntero a los datos de la opcion
;    Tiene en cuenta el "option overload"
;    Se ha de inicializar con DHCP_INIT_OP

DHCP_INIT_OP:	xor	a
	ld	(DHCP_OP_OVL),a
	ld	ix,IN_BUFFER+272	'campo 'options' tras la cookie
	ld	(DHCP_OP_PNT),ix
	ret

DHCP_NEXT_OP:	ld	ix,(DHCP_OP_PNT)
DHCPNO_LOOP:	ld	(DHCP_OP_PNT),ix
	ld	a,(ix)
	inc	ix	;Ahora IX apunta a la longitud (si op no es 0 o 255)

	;* Opcion 0: Pad

	or	a
	jr	z,DHCPNO_LOOP

	;* Opcion 255: fin, saltar a 'file' o 'sname' si es necesario

	cp	255
	jr	nz,DHCPNO_NOEND

	ld	a,(DHCP_OP_OVL)
	ld	b,a
	or	a
	ld	a,0
	ret	z
	ld	a,b

	bit	0,a
	jr	z,DHCPNO_NOFILE
	and	%10
	ld	(DHCP_OP_OVL),a
	ld	ix,IN_BUFFER+140	;campo 'file'
	jr	DHCPNO_LOOP
DHCPNO_NOFILE:

	xor	a
	ld	(DHCP_OP_OVL),a
	ld	ix,IN_BUFFER+76	;campo 'sname'
	jr	DHCPNO_LOOP
DHCPNO_NOEND:

	;* Opcion 52 (overload): guarda opcion y continua

	cp	52
	jr	nz,DHCPNO_NOOVL

	ld	a,(ix+1)
	and	%11
	ld	(DHCP_OP_OVL),a
	inc	ix
	inc	ix
	jr	DHCPNO_LOOP
DHCPNO_NOOVL:

	;* Otra opcion: devolverla y actualizar puntero

	ld	a,(ix-1)
	ld	b,(ix)
	inc	ix	;Ahora apunta a los datos de la opcion
	push	ix,bc
DHCPNO_NXT:	inc	ix
	djnz	DHCPNO_NXT
	ld	(DHCP_OP_PNT),ix
	pop	bc,ix

	ret

DHCP_OP_OVL:	db	0	;Opcion "Option overload" encontrada
DHCP_OP_PNT:	dw	0	;Puntero a la siguiente opcion a examinar


;--- DHCP_GET_TYPE: Devuelve en A el codigo del mensaje recibido,
;    o 0 si no tiene

DHCP_GET_TYPE:	call	DHCP_INIT_OP
DHCP_GT_LOOP:	call	DHCP_NEXT_OP
	or	a
	ret	z
	cp	53
	jr	nz,DHCP_GT_LOOP
	ld	a,(ix)
	ret


;--- DHCP_GET_SERVER: Devuelve en HL la dir de la opcion 'Server id'
;    o Cy=1 si no se encuentra

DHCP_GET_SERVER:	call	DHCP_INIT_OP
DHCP_GS_LOOP:	call	DHCP_NEXT_OP
	or	a
	scf
	ret	z
	cp	54
	jr	nz,DHCP_GS_LOOP
	push	ix
	pop	hl
	or	a
	ret


;--- DHCP_FIRST: Se ha de llamar cuando se envia un paquete
;    por primera vez tras un cambio de estado

DHCP_FIRST:	ld	a,1
	ld	(DHCP_TRIES),a
	ld	a,3*60
	ld	(DHCP_SNDTIM),a
	ret


	;=====================================
	;===  Rutinas auxiliares para TCP  ===
	;=====================================

;--- SRCH_TCP_INBUF: Busca la conexion TCP asociada
;    al paquete que hay en IN_BUFFER

SRCH_TCP_INBUF:	ld	hl,(IN_BUFFER+16)
	ld	de,(IN_BUFFER+18)
	ld	a,(IN_BUFFER+24)
	ld	ixh,a
	ld	a,(IN_BUFFER+25)
	ld	ixl,a
	ld	a,(IN_BUFFER+26)
	ld	iyh,a
	ld	a,(IN_BUFFER+27)
	ld	iyl,a

;--- SEARCH_TCP: Busca una conexion abierta con los parametros
;    dados de IP remota y puertos.
;    Entrada:   L.H.E.D = IP remota
;               IX = Puerto remoto
;               IY = Puerto local
;    Salida:    A = Num. conexion, 0 a 4 (#FF si no se encuentra)
;    Modifica:  HL, DE, BC

SEARCH_TCP:	ld	(STCP_TEMP),hl	;Guarda los datos pasados
	ld	(STCP_TEMP+2),de	;en una zona temporal
	ld	(STCP_TEMP+4),ix
	ld	(STCP_TEMP+6),iy

	ld	hl,TCBS+96*3
	ld	b,4

	;Bucle para las cuatro conexiones

STCP_LOOP:	ld	a,(hl)	;Esta abierta?
	or	a
	inc	hl
	jr	z,STCP_NEXT

	push	hl,bc
	ld	de,STCP_TEMP
	call	COMP32
	pop	bc,hl
	jr	nz,STCP_NEXT

	push	hl,bc
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	de,STCP_TEMP+4
	call	COMP32
	pop	bc,hl
	jr	nz,STCP_NEXT

	ld	a,b	;Conexion encontrada
	dec	a
	ret

	;Siguiente conexion, si quedan

STCP_NEXT:	dec	hl
	ld	de,96
	or	a
	sbc	hl,de
	djnz	STCP_LOOP
	ld	a,#FF	;Si llegamos aqui es que no quedan mas
	ret

STCP_TEMP:	ds	8


;--- SEARCH_LISTEN: Busca una conexion TCP en estado LISTEN
;    que tenga el socket remoto sin especificar
;    Entrada: -
;    Salida:  A = Conexion, 0 a 3 (#FF si no se encuentra)
;    Modifica:  AF,BC,DE,HL

SEARCH_LISTEN:	ld	hl,TCBS+96*3
	ld	b,4

SLST_LOOP:	ld	a,(hl)
	cp	LISTEN
	jr	nz,SLST_NEXT

	push	hl,bc
	inc	hl
	ld	de,ZERO32
	call	COMP32
	pop	bc,hl
	jr	nz,SLST_NEXT

	ld	a,b	;Conexion encontrada
	dec	a
	ret

	;Siguiente conexion, si quedan

SLST_NEXT:	ld	de,96
	or	a
	sbc	hl,de
	djnz	SLST_LOOP
	ld	a,#FF	;Si llegamos aqui es que no quedan mas
	ret

ZERO32:	db	0,0,0,0


;--- SEARCH_FRTCP: Busca una conexion TCP libre (en estado CLOSED)
;    Entrada:  -
;    Salida:   A = Conexion, 0 a 3 (#FF si no se encuentra)
;    Modifica: AF,HL,DE,BC

SEARCH_FRTCP:	ld	a,(TCBS)
	or	a
	ret	z

	ld	a,(TCBS+96)
	or	a
	ld	a,1
	ret	z

	ld	a,(TCBS+2*96)
	or	a
	ld	a,2
	ret	z

	ld	a,(TCBS+3*96)
	or	a
	ld	a,3
	ret	z

	ld	a,#FF
	ret


;--- LOAD_TCB: Carga el TCB especificado en TCB_TEMP
;    Entrada:  A = Numero de TCB (0 a 3)
;    Modifica: AF,BC,DE,HL

LOAD_TCB:	ld	(CURTCB_NUM),a
	call	GET_TCB_DIR
	ld	de,TCB_TEMP
	ld	bc,TCB_SIZE
	ldir
	ret


;--- SAVE_TCB: Graba TCB_TEMP en el TCB especificado en CURTCB_NUM
;    Entrada:  -
;    Salida:   -
;    Modifica: AF,BC,DE,HL

SAVE_TCB:	ld	a,(CURTCB_NUM)
	call	GET_TCB_DIR
	ex	de,hl
	ld	hl,TCB_TEMP
	ld	bc,TCB_SIZE
	ldir
	ret


;--- GET_TCB_DIR: Obtiene en HL la dir del TCB para la conexion A
;    Modifica: AF, DE

;* Si el TCB mide 96 bytes:

GET_TCB_DIR:	ld	hl,TCBS
	ld	de,96	;128
	inc	a
GET_TCB_DLOOP:	dec	a
	ret	z
	add	hl,de
	jr	GET_TCB_DLOOP

;* Si el TCB mide 256 bytes:

;GET_TCB_DIR:    ld      hl,TCBS
;        add     h
;        ld      h,a
;        ret


;--- TCP_IS_ZERO: Comprueba si el TCB actual tiene 0.0.0.0 en la IP
;    Entrada:  -
;    Salida:   Z=1 si REMOTE_IP es 0.0.0.0
;    Modifica: AF,HL,DE

TCP_IS_ZERO:	ld	hl,(REMOTE_IP)
	ld	de,(REMOTE_IP+2)
	ld	a,h
	or	l
	or	d
	or	e
	ret

;--- SET_TCP_PORTS: Devuelve la IP remota en L.H.E.D,
;    el puerto local en IY, y el remoto en IX

SET_TCP_PORTS:	ld	ix,(REMOTE_PORT)
	ld	iy,(LOCAL_PORT)
	ld	hl,(REMOTE_IP)
	ld	de,(REMOTE_IP+2)
	ret


;--- SEND_SEGMENT: Envio de un segmento TCP.
;    Se supone que la cabecera TCP ya esta establecida
;    en OUT_BUFER+24 (Seq, Ack y banderas),
;    y los datos ya estan copiados en OUT_BUFER+44.
;    Entrada: L.H.E.D = IP de destino
;             IX = Puerto remoto
;             IY = Puerto local
;             BC = Longitud datos

SEND_SEGMENT:	ld	a,6
	call	PREPARE_IP	;IPs y protocolo

	push	ix,iy
	pop	de,hl
	ld	ix,OUT_BUFFER	;IX=Cabecera TCP
	ld	(ix+24),d	;Puerto local
	ld	(ix+25),e
	ld	(ix+26),h	;Puerto remoto
	ld	(ix+27),l
	ld	(ix+36),#50	;Data Offset
	ld	(ix+40),0	;Checksum
	ld	(ix+41),0
	ld	(ix+42),0	;Urgent Pointer
	ld	(ix+43),0

	call	CALC_RCV_WIN
SMALL_WIN:	ld	(ix+38),h
	ld	(ix+39),l
	ld	(LAST_WIN_SENT),hl

	ld	hl,20
	add	hl,bc	;Longitud total TCP

	;* Si tiene SYN, anyadimos opcion MSS al final
	;  (notese que un segmento SYN nunca tiene datos)

	ld	a,(ix+37)
	and	%10
	jr	z,NO_PUT_MSS

	ld	hl,MSS_DATA
	ld	de,OUT_BUFFER+44
	ld	bc,4
	ldir
	ld	hl,24	;Nuevo tamanyo TCP
		ld	(ix+36),#60	;Nueva long. cabecera
NO_PUT_MSS:

	push	hl,hl
	pop	bc
	ld	(ix+14),b
	ld	(ix+15),c	;Longitud TCP en el checksum IP
	ld	hl,12
	add	hl,bc	;Para que incluya pseudo-cabecera
	push	hl
	pop	bc
	ld	ix,OUT_BUFFER+12	;Ver explicacion del truco en IS_UDP
	call	CALC_CHKSUM
	ld	(OUT_BUFFER+40),de

	ld	hl,0	;Deja el checksum IP otra vez a 0
	ld	(OUT_BUFFER+14),hl

	pop	bc
	jp	SEND_IP2

	;Opcion MSS:
	;Anunciamos 512-64, de esta forma evitamos
	;que se pierdan datos cuando llegan varios
	;paquetes seguidos (el bufer del RS232
	;es de solo 512 bytes).

MSS_DATA:	db	2,4,1,#C0	;Opcion MSS=448 (Cod=2, Tam=4, MSS=#01C0)


;--- SEND_SYN: Envia un datagrama TCP con SYN.
;    Entrada: A=#02 para SYN de la forma <SEQ=ISS><CTL=SYN>
;             A=#12 para SYN de la forma <SEQ=ISS><ACK=RCV.NXT><CTL=SYN,ACK>

SEND_SYN:	push	af

	ld	hl,ISS	;Establece numero de secuencia
	ld	de,OUT_BUFFER+28
	ld	bc,4
	ldir

	ld	hl,RCV_NXT	;Establece numero de ACK
	ld	de,OUT_BUFFER+32
	ld	bc,4
	ldir

	pop	af	;Establece banderas de control
	ld	(OUT_BUFFER+37),a

	ld	a,(SYN_SENT_FLAG)
	or	a
	jr	nz,ES_SYN_RETX
	ld	a,#FF	;Actualiza TCB si no es una retransmision
	ld	(SYN_SENT_FLAG),a
	ld	hl,(USER_TOUT_V)
	ld	(USER_TOUT),hl
ES_SYN_RETX:

	call	SET_TCP_PORTS	;Puertos e IP
	ld	bc,0
	jp	SEND_SEGMENT


;--- SEND_RST: Envia un datagrama TCP con RST.
;    Entrada: A=0 para RST de la forma <SEQ=SND.NXT><CTL=RST>
;             A=1 para SYN de la forma <SEQ=0><ACK=SEG.SEQ+SEG.LEN><CTL=RST,ACK>
;             A=2 para SYN de la forma <SEQ=SEG.ACK><CTL=RST>

SEND_RST:	or	a
	jr	z,SEND_RST0
	dec	a
	jr	z,SEND_RST1

	;>>> Forma 2: <SEQ=SEG.ACK><CTL=RST>

SEND_RST2:	ld	hl,IN_BUFFER+32	;Establece numero de secuencia
	ld	de,OUT_BUFFER+28
	ld	bc,4
	ldir

	ld	a,%100	;Establece banderas de control
	ld	(OUT_BUFFER+37),a

	jr	SEND_RST_X

	;>>> Forma 1: <SEQ=0><ACK=SEG.SEQ+SEG.LEN><CTL=RST,ACK>

SEND_RST1:	ld	hl,ZERO32	;Numero de secuencia
	ld	de,OUT_BUFFER+28
	ld	bc,4
	ldir

	call	GET_SEG_LEN	;Numero de ACK
	ex	de,hl
	ld	hl,IN_BUFFER+28
	ld	bc,OUT_BUFFER+32
	call	ADD3216

	ld	a,%10100	;Control
	ld	(OUT_BUFFER+37),a

SEND_RST_X:	ld	hl,(IN_BUFFER+16)	;Puertos e IP desde el segmento llegado
	ld	de,(IN_BUFFER+18)
	ld	a,(IN_BUFFER+24)
	ld	ixh,a
	ld	a,(IN_BUFFER+25)
	ld	ixl,a
	ld	a,(IN_BUFFER+26)
	ld	iyh,a
	ld	a,(IN_BUFFER+27)
	ld	iyl,a
	ld	bc,0
	jp	SEND_SEGMENT

	;>>> Forma 0: <SEQ=SND.NXT><CTL=RST>

SEND_RST0:	ld	hl,SND_NXT	;Numero de secuencia
	ld	de,OUT_BUFFER+28
	ld	bc,4
	ldir

	ld	a,%100	;Establece banderas de control
	ld	(OUT_BUFFER+37),a

	call	SET_TCP_PORTS	;Puertos e IP de la conexion actual
	jp	SEND_SEGMENT


;--- SEND_DATA: Envia un segmento de la forma <SEQ=SND.NXT><ACK=RCV.NXT><CTL=ACK>
;    con la IP y puertos del TCB actual.
;    Entrada: BC=Longitud de los datos (ya copiados en OUT_BUFFER+44)
;             A=0 para datos normales
;               8 para PUSH
;               1 para FIN
;               9 para PUSH+FIN
;    SEND_ACK no envia datos.

SEND_ACK:	ld	bc,0
	xor	a

SEND_DATA:	push	bc,af,bc	;Establece num. de secuencia
	ld	hl,SND_UNA
	ld	de,OUT_BUFFER+28
	ld	bc,4
	ldir

	pop	bc
	ld	a,b
	or	c
	jr	nz,SNDDATA_2

	ld	de,(RETX_SIZE)	;v0.4
	ld	hl,OUT_BUFFER+28
	ld	bc,OUT_BUFFER+28
	call	ADD3216
SNDDATA_2:

	ld	hl,RCV_NXT	;Establece num. de ACK
	ld	de,OUT_BUFFER+32
	ld	bc,4
	ldir

	pop	af
	or	%10000	;Establece bandera ACK
	ld	(OUT_BUFFER+37),a

	pop	de	;Actualiza SND_NXT
	push	de
	bit	0,a
	jr	z,SEND_NO_FIN
	inc	de	;FIN tiene numero de secuencia
	ld	a,#FF
	ld	(FIN_SENT_FLAG),a
SEND_NO_FIN:	ld	hl,SND_UNA
	ld	bc,SND_NXT
	call	ADD3216

	call	SET_TCP_PORTS
	pop	bc
	call	SEND_SEGMENT

	ld	hl,0
	ld	(ACK_RCV_NUM),hl
	xor	a
	ld	(ACK_DELAY_T),a
	ld	(ACK_PENDING),a
	ret


;--- GET_SEG_LEN: Devuelve la longitud de los datos en el segmento entrante
;    Entrada: Segmento en IN_BUFFER
;    Salida:  HL = Longitud incluyendo SYN y FIN
;             BC = Longitud solo de los datos

GET_SEG_LEN:	ld	hl,(IN_BUFFER+6)
	push	hl
	pop	bc
	ld	a,(IN_BUFFER+37)	;%xxxxxxSF
	and	%11
	ret	z	;%00: Devolvemos HL=BC
	inc	hl
	cp	%11	;%01 o %10: Devolvemos HL=BC+1
	ret	nz
	inc	hl	;%11: Devolvemos HL=BC+2
	ret


;--- CALC_RCV_WIN: Devuelve en HL la ventana de recepcion a anunciar
;    - Si el estado es anterior a ESTABLISHED, devuelve 1.
;    - Si INBUF_FREE es >512, devuelve 512.
;    - Si INBUF_FREE es <128, devuelve INBUF_FREE.
;    - En caso contrario, devuelve INBUF_FREE
;      redondeado por defecto a un multiplo de 128.

CALC_RCV_WIN:	;ld      a,(TCP_STATE)
	; cp      ESTABLISHED
	; ld      hl,1
	; ret     c

	ld	hl,(INBUF_FREE)
	;ld      de,512
	;call    COMP
	;jr      nc,GETRCVW_2
	;ex      de,hl
	;ret
;GETRCVW_2:

	ld	de,128
	call	COMP
	ld	a,l
	jr	nc,GETRCVW_3
	and	%10000000
	ld	l,a
GETRCVW_3:

	ret


;--- CHK_TCP_EXIST: Comprueba que una conexion TCP existe
;                   y no esta cerrada
;    Entrada: A = Numero de conexion
;    Salida: Cy=1 y
;            A = 1 si el numero de conexion es invalido (>3)
;                2 si esa conexion esta cerrada
;            Cy=0 y A=0 en caso contrario
;    Modifica: HL

CHK_TCP_EXIST:	ld	h,a

	;--- Comprueba numero de conexion

	and	%11111100
	ld	a,1
	scf
	ret	nz
	ld	a,h

	;--- Comprueba estado de la conexion

	push	de
	call	GET_TCB_DIR
	pop	de
	ld	a,(hl)
	or	a
	ld	a,2
	scf
	ret	z

	;--- No se cumple ninguna de las condiciones de error

	xor	a
	ret


;--- SET_WNDWL: Actualiza SND_WND y SND_WL1/2

SET_WNDWL:	ld	hl,(IN_BUFFER+38)
	ld	(SND_WND),hl

	ld	hl,IN_BUFFER+28
	ld	de,SND_WL1
	ld	bc,4
	ldir

	ld	hl,IN_BUFFER+32
	ld	de,SND_WL2
	ld	bc,4
	ldir

	;ld      a,(PUTEAR)       ;!!!
	;cp      4               ;Pruebas para el mecanismo
	;ret     nc              ;de comprobacion de ventana cero
	;inc     a
	;ld      (PUTEAR),a
	;ld      hl,0
	;ld      (SND_WND),hl

	ret

;PUTEAR:           db      0


;--- RET_LISTEN: Si la conexion actual esta en estado SYN-RECEIVED
;    y era pasiva, vuelve a LISTEN y devuelve Cy=1.
;    Si no, devuelve Cy=0.

RET_LISTEN:	ld	a,(TCP_STATE)
	cp	SYN.RECEIVED
	scf
	ccf
	ret	nz

	ld	a,(PASSIVE_OPEN)
	or	a
	ret	z

	ld	a,LISTEN
	ld	(TCP_STATE),a
	scf
	ret


;--- CHECK_SEQ: Comprueba la validez del numero de secuencia
;    del paquete entrante. Si es valido, devuelve Cy=1.
;    Si no, envia un ACK y devuelve Cy=0.

CHECK_SEQ:

	;--- El segmento sera valido si SEG_SEQ=RCV_NXT
	;    y ademas SEG_LEN<=RCV_WND.

	;ld      hl,RCV_NXT
	;ld      de,(ACK_RCV_NUM)
	;ld      bc,TEMP32_1
	;call    ADD3216

	ld	hl,IN_BUFFER+28
	ld	de,RCV_NXT
	call	COMP_SEQ
	jr	nz,TCP_BAD_SEQ

	;call    GET_SEG_LEN
	;ex      de,hl
	ld	de,(IN_BUFFER+6)
	ld	hl,(INBUF_FREE)
	call	COMP
	ret	c

	;Si no es valido, enviar ACK (a no ser que tenga RST)
	;y terminar

TCP_BAD_SEQ:	ld	a,(IN_BUFFER+37)
	and	%100
	ret	z
	call	SCHEDULE_ACK
	or	a
	ret

	;call    z,SEND_ACK
	;or      a
	;ret


;--- SCHEDULE_ACK: Programa un ACK retardado
;                  aunque no haya datos entrantes pendientes

SCHEDULE_ACK:	ld	hl,(ACK_RCV_NUM)
	ld	a,h
	or	l
	ret	nz
	ld	a,#FF
	ld	(ACK_PENDING),a
	ld	a,ACK_DELAY_V
	ld	(ACK_DELAY_T),a
	ret


;--- PROCESS_ACK: Procesa el ACK de un segmento entrante.
;    Devuelve Cy=1 si hay que continuar el procesamiento del segmento,
;    Cy=0 si no.

PROCESS_ACK:

	;--- Si SND.UNA =< SEG.ACK =< SND.NXT, actualizar ventana

	ld	hl,SND_UNA
	ld	bc,IN_BUFFER+32
	ld	de,SND_NXT
	call	RANGE32
	jr	nc,PROC_ACK_2

	ld	hl,SND_WL1	;Actualizar si SND.WL1 < SEG.SEQ...
	ld	de,IN_BUFFER+28
	call	COMP_SEQ
	jr	nc,PROC_ACK_UW

	jr	nz,PROC_ACK_2	;...o si (SND.WL1 = SEG.SEQ...
	ld	de,IN_BUFFER+32
	ld	hl,SND_WL2
	call	COMP_SEQ	;... y SND.WL2 <= SEG.ACK)
	jr	z,PROC_ACK_UW
	jr	c,PROC_ACK_2

PROC_ACK_UW:	call	SET_WNDWL
PROC_ACK_2:

	;--- Si SEG_ACK>SND_NXT, enviar un ACK
	;    e ignorar el segmento

	ld	a,(SYN_SENT_FLAG)	;v0.4
	ld	b,a
	ld	a,(FIN_SENT_FLAG)
	or	b
	ld	hl,SND_NXT
	jr	nz,PROC_ACK_20

	ld	hl,SND_UNA
	ld	de,(RETX_SIZE)
	ld	bc,TEMP32_1
	call	ADD3216
	ld	hl,TEMP32_1

PROC_ACK_20:	ld	de,IN_BUFFER+32
	call	COMP_SEQ
	jr	c,PROC_ACK_3

	call	SCHEDULE_ACK
	or	a
	ret
PROC_ACK_3:

	;--- Si SEG_ACK<=SND_UNA, ignorar ACK

	ld	hl,SND_UNA	;Comprueba si SND_UNA>=SND_ACK
	ld	de,IN_BUFFER+32
	call	COMP_SEQ
	ret	c

	;--- Si llegamos aqui, SND.UNA < SEG.ACK =< SND.NXT

	;Si FIN estaba enviado, ya esta reconocido: ponemos
	;FIN_SENT_FLAG a 0 y terminamos (ya que no habia mas datos pendientes de ACK)

	ld	a,(FIN_SENT_FLAG)
	or	a
	jr	z,PROC_ACK_4

	xor	a
	ld	(FIN_SENT_FLAG),a
	jr	PROC_ACK_END
PROC_ACK_4:

	;Hay que sacar SEG.ACK-SND.UNA bytes de la cola de ReTx

	ld	de,IN_BUFFER+32
	ld	hl,SND_UNA
	ld	bc,TEMP32_1
	call	SUB32

	ld	a,(TEMP32_1+2)
	ld	h,a
	ld	a,(TEMP32_1+3)
	ld	l,a
	or	h
	jr	z,PROC_ACK_END

	ld	a,(TEMP32_1)
	and	%10000000
	jr	z,PROC_ACK_5
	ex	de,hl
	ld	hl,0
	or	a
	sbc	hl,de	;HL = Bytes a extraer
PROC_ACK_5:
	ld	a,h
	or	l
	jr	z,PROC_ACK_END

	ld	ix,OUTBUF
	ld	de,OUT_BUFFER
	push	hl,hl
	pop	bc
	call	RBUF_EXTRACT

	pop	bc
	ld	hl,(RETX_SIZE)
	or	a
	sbc	hl,bc
	ld	(RETX_SIZE),hl

	;Decrementa el contador de bytes PUSH pendientes

	ld	hl,(SEND_PUSH_PEND)
	or	a
	sbc	hl,bc
	bit	7,h	;Si la resta da un num negativo, usar 0
	jr	z,NO_PUSH_NEG
	ld	hl,0
NO_PUSH_NEG:	ld	(SEND_PUSH_PEND),hl

	;Reinicia el contador de envio no PUSH

	ld	hl,SEND_TOUT_V	;0.5 segundos
	ld	(SEND_TOUT),hl

	;Actualiza SND_UNA y termina

PROC_ACK_END:	ld	hl,IN_BUFFER+32
	ld	de,SND_UNA
	ld	bc,4
	ldir

	scf
	ret


;--- CLOSE_ALL_TCP: Cierra todas las conexiones TCP abiertas
;    con error 6 (conexion a internet perdida)

CLOSE_ALL_TCP:	push	hl,de,bc
	xor	a
CLOSE_TCP_LOOP:	push	af
	call	LOAD_TCB
	ld	a,(TCP_STATE)
	or	a
	jr	z,NEXT_TCP
	xor	a
	ld	(TCP_STATE),a
	ld	a,6
	ld	(LAST_CLOSE),a
	call	SAVE_TCB
NEXT_TCP:	pop	af
	inc	a
	cp	4
	jr	c,CLOSE_TCP_LOOP
	pop	bc,de,hl
	xor	a
	ret


	;======================================================
	;===  Rutinas para el manejo de numeros de 32 bits  ===
	;======================================================

;--- COMP32: Compara dos numeros de 32 bits, modulo 2^32,
;            guardados en big-endian
;    Entrada: HL = Puntero al primer numero
;             DE = Puntero al segundo numero
;    Salida:     C, NZ si (HL) > (DE)
;                C,  Z si (HL) = (DE)
;               NC, NZ si (HL) < (DE)
;    Modifica: HL, DE, AF, HL', DE', AF'

;COMP32 es parte de COMP_SEQ


;--- COMP_SEQ: Compara dos numeros de 32 bits, modulo 2^32,
;              guardados en big-endian; se supone que son
;              numeros de secuencia de TCP
;    Entrada: HL = Puntero al primer numero
;             DE = Puntero al segundo numero
;    Salida:     C, NZ si (HL) > (DE)
;                C,  Z si (HL) = (DE)
;               NC, NZ si (HL) < (DE)
;    Modifica: HL, DE, AF, HL', DE', AF'

;Se divide el espacio de 32 bits en 3 zonas:
;A: &H00000000 - &H3FFFFFFF (primer cuarto)
;B: &H40000000 - &HBFFFFFFF (segundo y tercer cuartos)
;C: &HC0000000 - &HFFFFFFFF (cuarto cuarto)

;Entonces dados dos numeros, se hace una comparacion normal excepto si
;pertenecen a las zonas A y C; numero de zona A > numero de zona C siempre.
;(Se asume que el TCP no puede enviar/recibir 1GByte de datos sin ACK)

COMP_SEQ:	ld	a,(de)	;El caso mas normal es que el
	cp	(hl)	;primer byte coincida, entonces
	jr	z,COMP32	;se salta a comp. normal

	ld	a,(hl)	;(HL) en zona A y (DE) en zona C?
	and	%11000000
	jr	nz,COMP32_1
	ld	a,(de)
	or	%00111111
	inc	a
	jr	nz,COMP32_1

	xor	a	;En ese caso vuelve con
	cp	1	;NZ y C (HL>DE)
	ret

COMP32_1:	ld	a,(de)	;(DE) en zona A y (HL) en zona C?
	and	%11000000
	jr	nz,COMP32
	ld	a,(hl)
	or	%00111111
	inc	a
	jr	nz,COMP32

	inc	a	;En ese caso vuelve con
	ret		;                ;NZ y NC (HL<DE)

COMP32:	call	COMP32_3	;Comparacion normal
	ret	nz
	call	COMP32_3
	ret

	;Esta subrutina compara los dos primeros bytes en la
	;primero llamada, y los dos ultimos en la segunda

COMP32_3:	ld	a,(hl)	;Carga HL' con (HL) y (HL+1)
	ex	af,af	;(primera llamada)
	inc	hl	;o con (HL+2) y (HL+3)
	ld	a,(hl)	;(segunda llamada).
	inc	hl	;Tiene en cuenta que el numero
	exx		;                ;es big-endian.
	ld	l,a
	ex	af,af
	ld	h,a
	exx

	ld	a,(de)	;Carga DE' con (DE) y (DE+1)
	ex	af,af	;(primera llamada)
	inc	de	;o con (DE+2) y (DE+3)
	ld	a,(de)	;(segunda llamada).
	inc	de	;Tiene en cuenta que el numero
	exx		;                ;es big-endian.
	ld	e,a
	ex	af,af
	ld	d,a
	;exx

	;exx
	call	COMP	;Compara HL' y DE'
	exx
	ret


;--- NOMBRE: ADD32
;      Suma dos numeros de 32 bits
;    ENTRADA:  HL, DE = Numeros a sumar
;              BC = Numero de destino
;              Es decir, hace: (BC) = (DE) + (HL)
;    SALIDA:   -
;    MODIFICA: AF

ADD32:	ld	a,#8E	;Codigo de "adc (hl)"
	ld	(ADDSUB_CODE),a
	jr	ADDSUB32


;--- NOMBRE: SUB32
;      Resta dos numeros de 32 bits
;    ENTRADA:  DE = Minuendo
;              HL = Sustraendo
;              BC = Numero de destino
;              Es decir, hace: (BC) = (DE) - (HL)
;    SALIDA:   -
;    MODIFICA: AF

SUB32:	ld	a,#9E	;Codigo de "sbc (hl)"
	ld	(ADDSUB_CODE),a

	;Codigo comun para ADD32 y SUB32

ADDSUB32:	inc	de	;Nos movemos hasta el ultimo
	inc	de	;byte (el numero esta guardado
	inc	de	;en big-endian)
	inc	hl
	inc	hl
	inc	hl
	inc	bc
	inc	bc
	inc	bc

	or	a
	call	ADD32_STEP2	;Sumamos byte por byte,
	call	ADD32_STEP	;del LSB al MSB, arrastrando
	call	ADD32_STEP	;el carry, en 4 pasos

ADD32_STEP:	dec	hl
	dec	de
	dec	bc
ADD32_STEP2:	ld	a,(de)
ADDSUB_CODE:	nop		;                ;Aqui ira "adc (hl)" o "sbc (hl)"
	ld	(bc),a
	ret


;--- NOMBRE: ADD3216
;      Suma un numero de 16 bits a uno de 32
;    ENTRADA:  HL = Numero de 32 bits
;              DE = Numero de 16 bits
;              BC = Numero de destino
;              Es decir, hace: (BC) = DE + (HL)
;    SALIDA:   -
;    MODIFICA: AF

ADD3216:	ld	a,d
	ld	(NUM16BUF+2),a
	ld	a,e
	ld	(NUM16BUF+3),a
	ld	de,NUM16BUF
	jr	ADD32

NUM16BUF:	db	0,0,0,0


;--- NOMBRE: SUB3216
;      Resta un numero de 16 bits a uno de 32
;    ENTRADA:  DE = Minuendo
;              HL = Sustraendo
;              BC = Numero de destino
;              Es decir, hace: (BC) = (DE) - HL
;    SALIDA:   -
;    MODIFICA: AF

SUB3216:	ld	a,h
	ld	(NUM16BUF+2),a
	ld	a,l
	ld	(NUM16BUF+3),a
	ld	hl,NUM16BUF
	jr	SUB32


;--- NOMBRE: INC32
;      Incrementa un numero de 16 bits en una unidad
;    ENTRADA:  HL = Numero a incrementar
;              BC = Numero de destino
;              Es decir, hace: (BC) = (HL) + 1

INC32:	ld	de,NUM1BUF
	jr	ADD32

NUM1BUF:	db	0,0,0,1


;--- NOMBRE: DEC32
;      Decrementa un numero de 16 bits en una unidad
;    ENTRADA:  HL = Numero a decrementar
;              BC = Numero de destino
;              Es decir, hace: (BC) = (HL) - 1

DEC32:	ex	de,hl
	ld	hl,NUM1BUF
	jr	SUB32


;--- NOMBRE: RANGE32
;      Comprueba si un numero de secuencia esta dentro de un determinado rango
;    ENTRADA:  HL = Limite inferior
;              DE = Limite superior
;              BC = Numero
;    SALIDA:   Cy=1 si (HL) <= (BC) <= (DE)
;    MODIFICA: HL, DE, AF, HL', DE', AF'
;

RANGE32:	push	hl,de,bc	;Primero comprueba si
	ex	de,hl	;(BC) < (HL), en ese caso termina
	ld	h,b
	ld	l,c
	call	COMP_SEQ
	pop	bc,de,hl
	ret	nc

RANGE32_2:	ld	h,b
	ld	l,c
	call	COMP_SEQ
	ret	z
	ccf
	ret


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

MULT32B:	;ld	d,(ix)
	;ld	e,(ix+1)
	;ld	h,(ix+2)
	;ld	l,(ix+3)

;MULT32_LOP:	add	hl,hl
;	ex	de,hl
;	adc	hl,hl
;	ex	de,hl
;	djnz	MULT32_LOP

;	ld	(ix),d
;	ld	(ix+1),e
;	ld	(ix+2),h
;	ld	(ix+3),l
;	ret

MULT32_LOP:	sla	(ix+3)
	rl	(ix+2)
	rl	(ix+1)
	rl	(ix)
	djnz	MULT32_LOP
	ret

NUMBUF:	ds	4


;--- ENTRE2_32: Divide un numero de 32 bits entre 2^B
;    Entrada: IX = Numero a dividir

ENTRE2_32:	;ld	d,(ix)
	;ld	e,(ix+1)
	;ld	h,(ix+2)
	;ld	l,(ix+3)

	res	7,(ix)	;Por si acaso
ENTRE2_32L:
	sra	(ix)
	rr	(ix+1)
	rr	(ix+2)
	rr	(ix+3)
	djnz	ENTRE2_32L

			;ld	(ix),d
	;ld	(ix+1),e
	;ld	(ix+2),h
	;ld	(ix+3),l
	ret


	;======================================================
	;===  Rutinas para el manejo de buferes circulares  ===
	;======================================================

;--- Inicializacion de un bufer
;    Entrada:  IX = Dir de la zona de datos del bufer (12 bytes)
;              HL = Dir del bufer de 1024 bytes
;              BC = Tamanyo del bufer
;    Salida:   -
;    Modifica: F, HL, DE, BC

RBUF_INIT:	ld	(TRBUF_BUFADD),hl
	ld	(TRBUF_INPNT),hl
	ld	(TRBUF_OUTPNT),hl
	add	hl,bc
	ld	(TRBUF_ENDADD),hl
	ld	(TRBUF_FREE),bc
	ld	hl,0
	ld	(TRBUF_USED),hl
	call	BUF_SDATA
	ret


;--- Insercion de datos en el bufer
;    Entrada: IX = Zona de datos del bufer
;             HL = Direccion de los datos
;             BC = Longitud de los datos
;    Salida:  Cy = 1 si error (BC>espacio libre)
;    Modifica: AF, DE

RBUF_INSERT:	call	BUF_GDATA

	;--- Se pueden insertar los datos?
	;    (hay suficiente espacio libre?)

	push	hl
	ld	hl,(TRBUF_FREE)
	push	bc
	pop	de
	call	COMP
	pop	hl
	ccf
	ret	c

	push	bc	;Pila=Tam. total

	;--- Comprueba si puede insertar los
	;    datos de un tiron, eso sera posible
	;    si INPNT+BC<=ENDADD

	push	hl
	ld	hl,(TRBUF_INPNT)
	add	hl,bc
	ld	de,(TRBUF_ENDADD)
	ex	de,hl	;HL=ENDADD, DE=INPNT+BC
	call	COMP
	pop	hl
	ld	de,(TRBUF_INPNT)
	jr	c,BUF_IN_DIRECT

	;--- Inserta los primeros ENDADD-INPNT bytes

	; Hace BC=ENDADD-INPNT

	push	hl
	ld	hl,(TRBUF_ENDADD)
	ld	de,(TRBUF_INPNT)
	or	a
	sbc	hl,de

	push	hl
	pop	bc	;BC=ENDADD-INPNT

	pop	hl
	push	bc	;Pila=Tam. total, Tam. 1er bloque

	; Realiza la copia del primer bloque

	ld	de,(TRBUF_INPNT)
	ldir

	; Establece DE a BUFADD,
	; calcula BC como el tamanyo del bloque restante,
	; y salta a la insercion directa

	pop	bc	;BC = Tam. copiado (1er bloque)
	pop	de	;DE = Tamanyo total
	push	de
	push	hl	;Pila=Tam. total, Dir. origen actual

	push	bc
	pop	hl
	ex	de,hl	;HL = Tam. total, DE = Tam. copiado
	or	a
	sbc	hl,de
	push	hl
	pop	bc	;BC = Tamanyo restante a copiar

	pop	hl	;HL = Dir. origen actual; Pila=Tam. total

	ld	de,(TRBUF_BUFADD)

	;--- Insercion del ultimo bloque

BUF_IN_DIRECT:	ldir

	ld	hl,(TRBUF_ENDADD)	;HL=ENDADD, DE=Ultima dir insertada+1
	call	COMP
	jr	nz,NO_ADJ_PNT
	ld	de,(TRBUF_BUFADD)	;Por si la copia ha llegado justo al final
NO_ADJ_PNT:	;

	;--- Ajusta punteros y termina

	ld	(TRBUF_INPNT),de
	pop	bc
	ld	hl,(TRBUF_USED)
	add	hl,bc
	ld	(TRBUF_USED),hl
	ld	hl,(TRBUF_FREE)
	or	a
	sbc	hl,bc
	ld	(TRBUF_FREE),hl

	call	BUF_SDATA
	xor	a
	ret


;--- Extraccion de datos de un bufer
;    Entrada:  IX = Dir de la zona de datos del bufer
;              DE = Dir de destino
;              BC = Num de bytes a extraer
;    Salida:   BC = Num de bytes extraidos
;              Cy=1 si error (0 bytes disponibles)
;    Modifica: AF, HL, DE, BC

RBUF_EXTRACT:	xor	a
	jr	BUF_EXTPEEK


;--- Obtencion de datos de un bufer sin extraerlos
;    Entrada:  IX = Dir de la zona de datos del bufer
;              DE = Dir de destino
;              BC = Num de bytes a extraer
;    Salida:   BC = Num de bytes extraidos
;              Cy=1 si error (0 bytes disponibles)
;    Modifica: AF, HL, DE, BC

RBUF_PEEK:	ld	a,#FF
BUF_EXTPEEK:	ld	(BUF_OUTACTION),a

	call	BUF_GDATA

	;--- Comprobacion de BC

	; Si BC=0, no hace nada y termina

	ld	a,b
	or	c
	ret	z

	; Si no hay datos disponibles, termina con error

	ld	hl,(TRBUF_USED)
	ld	a,h
	or	l
	scf
	ret	z

	; Si BC>Num. de bytes disponibles, lo modifica

	push	de
	push	bc
	pop	hl
	ld	de,(TRBUF_USED)	;HL=Bytes a extraer, DE=Bytes disponibles
	call	COMP
	jr	nc,BEX_NOADJBC
	push	de
	pop	bc
BEX_NOADJBC:	pop	de

	push	bc	;Pila=Tam. a extraer

	;--- Comprueba si puede extraer los
	;    datos de un tiron, eso sera posible
	;    si OUTPNT+BC<=ENDADD

	push	de
	ld	hl,(TRBUF_OUTPNT)
	add	hl,bc
	ld	de,(TRBUF_ENDADD)
	ex	de,hl	;HL=ENDADD, DE=OUTPNT+BC
	call	COMP
	pop	de
	ld	hl,(TRBUF_OUTPNT)
	jr	c,BUF_OUT_DIRECT

	;--- Extrae los primeros ENDADD-OUTPNT bytes

	; Hace BC=ENDADD-OUTPNT

	push	de
	ld	hl,(TRBUF_ENDADD)
	ld	de,(TRBUF_OUTPNT)
	or	a
	sbc	hl,de
	push	hl
	pop	bc
	pop	de
	push	bc	;Tam. 1er bloque

	; Realiza la copia del primer bloque

	ld	hl,(TRBUF_OUTPNT)
	ldir

	; Establece HL a BUFADD,
	; calcula BC como el tamanyo del bloque restante,
	; y salta a la extraccion directa

	pop	bc	;BC = Tam. copiado (1er bloque)
	pop	hl	;HL = Tamanyo total
	push	hl
	push	de	;Pila=Tam. total, Dir. destino actual

	push	bc
	pop	de	;HL = Tam. total, DE = Tam. copiado
	or	a
	sbc	hl,de
	push	hl
	pop	bc	;BC = Tamanyo restante a copiar

	pop	de	;DE = Dir. destino actual; Pila=Tam. total

	ld	hl,(TRBUF_BUFADD)

	;--- Insercion del ultimo bloque

BUF_OUT_DIRECT:	ldir

	ld	de,(TRBUF_ENDADD)	;DE=ENDADD, HL=Ultima dir extraida+1
	call	COMP
	jr	nz,NO_ADJ_PNT2
	ld	hl,(TRBUF_BUFADD)	;Por si la copia ha llegado justo al final
NO_ADJ_PNT2:	;

	;--- Ajusta punteros si es extraccion, y termina

	pop	bc
	ld	a,(BUF_OUTACTION)
	or	a
	ld	a,0
	ret	nz

	ld	(TRBUF_OUTPNT),hl
	ld	hl,(TRBUF_USED)
	or	a
	sbc	hl,bc
	ld	(TRBUF_USED),hl
	ld	hl,(TRBUF_FREE)
	add	hl,bc
	ld	(TRBUF_FREE),hl

	push	bc
	call	BUF_SDATA
	pop	bc
	xor	a
	ret

BUF_OUTACTION:	db	0	;0 para extract, #FF para peek


	;=== Rutinas auxiliares

	;--- Copia una zona de datos de/a un bufer temporal
	;	(apuntado por IX)

BUF_GDATA:	push	hl,de,bc
	push	ix
	pop	hl
	ld	de,TRBUF_USED
	ld	bc,12
	ldir
	pop	bc,de,hl
	ret

BUF_SDATA:	push	ix
	pop	de
	ld	hl,TRBUF_USED
	ld	bc,12
	ldir
	ret



	;---------------------------------
	;---  Zona de datos del bufer  ---
	;---------------------------------

TRBUF_USED:	dw	0
TRBUF_FREE:	dw	0
TRBUF_INPNT:	dw	0
TRBUF_OUTPNT:	dw	0
TRBUF_BUFADD:	dw	0
TRBUF_ENDADD:	dw	0



	;=================================================
	;===  Rutinas para la (de)codificacion Base64  ===
	;=================================================

;* Grafico de la transformacion Base64:
;
;         +--first octet--+-second octet--+--third octet--+
;         |7 6 5 4 3 2 1 0|7 6 5 4 3 2 1 0|7 6 5 4 3 2 1 0| --> Normal
;         +-----------+---+-------+-------+---+-----------+
;         |5 4 3 2 1 0|5 4 3 2 1 0|5 4 3 2 1 0|5 4 3 2 1 0| --> Codificado
;         +--1.index--+--2.index--+--3.index--+--4.index--+

;--- B64_INIT: Inicializa el motor de Base64
;    Entrada:  A=Caracteres entre CRLF (0=No insertar)
;    Modifica: -

B64_INIT:	push	af,hl
	or	a
	jr	z,B64_INIT2

	cp	4
	jr	nc,B64_INIT1
	ld	a,4
B64_INIT1:	sra	a	;Lo convierte a grupos de 4
	sra	a
	and	%00111111

B64_INIT2:	ld	(B64_CRINT),a
	ld	(B64_CRCNT),a
	xor	a
	ld	(B64_TEMPLON),a
	ld	(B64_DEC_FIN),a
	ld	hl,B64_INTEMP
	ld	(B64_DEC_PNT),hl
	ld	hl,0
	ld	(B64_TOTLEN),hl
	ld	(B64_TOTLEN+2),hl
	ld	(B64_INTEMP),hl
	ld	(B64_INTEMP+2),hl

	pop	hl,af
	ret


;--- B64_ENCB: Codifica un grupo de caracteres en B64
;    Tiene en cuenta el estado previo a la entrada,
;    por tanto IX-1 e IX-2 deben estar disponibles;
;    ademas guarda el estado a la salida si no es bloque final
;    Entrada: IX=Dir de origen
;             IY=Dir de destino
;             BC=Longitud
;             Cy=1 si bloque final
;             (B64_CRINT)=Intervalo para insertar CRLF
;             (B64_CRCNT)=Recordado desde la anterior ejecucion
;    Salida:  BC=Longitud resultado
;             IX=IX+BC inicial
;             IY=IY+BC final
;             HL:DE=Longitud de salida acumulada
;    Modifica: AF, BC, DE, HL, IX, IY

B64_ENCB:	ld	a,0
	rla
	ld	(B64_IS_FINAL),a	;1 si es final, 0 si no
	push	iy

	;--- Hay estado previo?

	ld	a,(B64_TEMPLON)
	or	a
	jr	z,B64_ENCLOOP
	cp	2
	jr	z,B64_ENC_PRV2

	;Estado previo de 1 caracter

	ld	a,(B64_INTEMP)
	ld	(ix-1),a
	dec	ix
	inc	bc
	jr	B64_ENCLOOP

	;Estado previo de 2 caracteres

B64_ENC_PRV2:	ld	a,(B64_INTEMP)
	ld	(ix-2),a
	ld	a,(B64_INTEMP+1)
	ld	(ix-1),a
	dec	ix
	dec	ix
	inc	bc
	inc	bc
	;jr      B64_ENCLOOP

B64_ENCLOOP:	ld	a,b
	or	a
	jr	nz,B64ENC_NOFIN
	ld	a,c
	or	a
	jr	z,B64ENC_LAST0
	cp	1
	jr	z,B64ENC_LAST1
	cp	2
	jr	z,B64ENC_LAST2

	;--- Codifica bloque normal

B64ENC_NOFIN:	exx
	call	B64_ENC3
	exx
	dec	bc
	dec	bc
	dec	bc

	;* Hay que insertar CRLF?

	ld	a,(B64_CRCNT)
	or	a
	jr	z,B64_ENCLOOP

	dec	a
	ld	(B64_CRCNT),a
	jr	nz,B64_ENCLOOP

	ld	a,(B64_CRINT)
	ld	(B64_CRCNT),a
	ld	(iy),13
	ld	(iy+1),10
	inc	iy
	inc	iy
	jr	B64_ENCLOOP

	;--- Ultimo bloque, de 1 caracter

B64ENC_LAST1:	ld	a,(B64_IS_FINAL)
	or	a
	jr	z,B64ENC_L1_2

	;* Era bloque final

	call	B64_ENC1
	jr	B64_ENC_END

	;* No era bloque final

B64ENC_L1_2	ld	a,(ix)
	ld	(B64_INTEMP),a
	ld	a,1
	ld	(B64_TEMPLON),a
	inc	ix
	jr	B64_ENC_END

	;--- Ultimo bloque, de 2 caracteres

B64ENC_LAST2:	ld	a,(B64_IS_FINAL)
	or	a
	jr	z,B64_L2_2

	;* Era bloque final

	call	B64_ENC2
	jr	B64_ENC_END

	;* No era bloque final

B64_L2_2:	ld	a,(ix)
	ld	(B64_INTEMP),a
	ld	a,(ix+1)
	ld	(B64_INTEMP+1),a
	ld	a,2
	ld	(B64_TEMPLON),a
	inc	ix
	inc	ix
	jr	B64_ENC_END

	;--- No hay ultimo bloque

B64ENC_LAST0:	xor	a
	ld	(B64_TEMPLON),a

	;--- Fin: calcula long resultante
	;    como IY nuevo - IY antiguo

B64_ENC_END:	pop	bc
	push	iy
	push	iy
	pop	hl
	or	a
	sbc	hl,bc
	push	hl
	pop	bc
	pop	iy

	call	B64_INCTLEN

	xor	a
	ret


;--- B64_ENC3: Codifica un triplete de caracteres en B64
;    Entrada:  IX=Dir del triplete
;              IY=Dir de destino
;    Salida:   IX=IX+3
;              IY=IY+4
;    Modifica: AF, HL, BC

B64_ENC3:	ld	a,(ix)
	sra	a
	sra	a
	and	%00111111
	call	GETB64CHAR
	ld	(iy),a

	ld	a,(ix)
	sla	a
	sla	a
	sla	a
	sla	a
	and	%00110000
	ld	b,a
	ld	a,(ix+1)
	sra	a
	sra	a
	sra	a
	sra	a
	and	%00001111
	or	b
	call	GETB64CHAR
	ld	(iy+1),a

	ld	a,(ix+1)
	sla	a
	sla	a
	and	%00111100
	ld	b,a
	ld	a,(ix+2)
	rlca
	rlca
	and	%00000011
	or	b
	call	GETB64CHAR
	ld	(iy+2),a

	ld	a,(ix+2)
	and	%00111111
	call	GETB64CHAR
	ld	(iy+3),a

	inc	ix
B64_ENCEND2:	inc	ix
B64_ENCEND1:	inc	ix
	inc	iy
	inc	iy
	inc	iy
	inc	iy
	ret


;--- B64_ENC1: Codifica un triplete final de un caracter en B64
;    Entrada:  IX=Dir del triplete
;              IY=Dir de destino
;    Salida:   IX=IX+1
;              IY=IY+4
;    Modifica: AF, HL, BC

B64_ENC1:	ld	a,(ix)
	sra	a
	sra	a
	and	%00111111
	call	GETB64CHAR
	ld	(iy),a

	ld	a,(ix)
	sla	a
	sla	a
	sla	a
	sla	a
	and	%00110000
	call	GETB64CHAR
	ld	(iy+1),a

	ld	(iy+2),"="
	ld	(iy+3),"="
	jr	B64_ENCEND1


;--- B64_ENC2: Codifica un triplete final de dos caracteres en B64
;    Entrada:  IX=Dir del triplete
;              IY=Dir de destino
;    Salida:   IX=IX+2
;              IY=IY+4
;    Modifica: AF, HL, BC

B64_ENC2:	ld	a,(ix)
	sra	a
	sra	a
	and	%00111111
	call	GETB64CHAR
	ld	(iy),a

	ld	a,(ix)
	sla	a
	sla	a
	sla	a
	sla	a
	and	%00110000
	ld	b,a
	ld	a,(ix+1)
	sra	a
	sra	a
	sra	a
	sra	a
	and	%00001111
	or	b
	call	GETB64CHAR
	ld	(iy+1),a

	ld	a,(ix+1)
	sla	a
	sla	a
	and	%00111100
	call	GETB64CHAR
	ld	(iy+2),a

	ld	(iy+3),"="
	jr	B64_ENCEND2



;--- B64_DECB: Decodifica un grupo de caracteres en B64
;    Pasa por alto tabulador, espacio y CRLF;
;    otros caracteres invalidos devuelven error.
;    Tiene en cuenta el estado previo a la entrada,
;    ademas guarda el estado a la salida si no es bloque final
;    Entrada: IX=Dir de origen
;             IY=Dir de destino
;             BC=Longitud
;             Cy=1 si bloque final
;    Salida:  BC=Longitud resultado
;             IX=IX+BC inicial
;             IY=IY+BC final
;             HL:DE=Longitud de salida acumulada
;             Cy=1 si error
;                  A=2: Longitud invalida en bloque no final
;                    3: Caracteres invalidos encontrados
;    Modifica: AF, BC, DE, HL, IX, IY

B64_DECB:	ld	a,0
	rla
	ld	(B64_IS_FINAL),a	;1 si es final, 0 si no
	ld	(B64_DEC_IY),iy

	;--- Bucle principal

B64_DECLOOP:	;* Si ya hay un grupo de 4 caracteres completo,
	;  lo decodifica

	ld	a,(B64_TEMPLON)
	cp	4
	jr	nz,B64_DECLOOP2

	exx
	call	B64_DEC4
	exx
	xor	a
	ld	(B64_TEMPLON),a
	ld	hl,B64_INTEMP
	ld	(B64_DEC_PNT),hl

	ld	a,(B64_TEMPLON+2)
	cp	#FF
	jr	nz,B64_DECLOOP2
	ld	a,(B64_TEMPLON+3)
	cp	#FF
	jr	nz,B64_DECLOOP2
	ld	(B64_DEC_FIN),a
B64_DECLOOP2:	;        

	;* Si no quedan caracteres de entrada, termina

B64_DEC_NEXT:	ld	a,b
	or	c
	jr	z,B64_DEC_END

	;* Obtiene un nuevo caracter a decodificar

	ld	a,(ix)
	inc	ix
	dec	bc

	;* Es caracter a ignorar?

	cp	9	;TAB
	jr	z,B64_DEC_NEXT
	cp	32	;SPC
	jr	z,B64_DEC_NEXT
	cp	13	;CR
	jr	z,B64_DEC_NEXT
	cp	10	;LF
	jr	z,B64_DEC_NEXT

	;Si habia un caracter "=" en el ultimo grupo decodificado,
	;solo pueden quedar caracteres ignorables pendientes;
	;lo contrario es un error

	ld	h,a
	ld	a,(B64_DEC_FIN)
	or	a
	jr	nz,B64_DEC_ER3
	ld	a,h

	;* Si es "=", es erroneo si;
	;  - No es bloque final; o
	;  - No hay al menos 2 caracteres en B64_INTEMP

	cp	"="
	jr	nz,B64_DECLOOP3

	; ld      a,(B64_IS_FINAL)
	; or      a
	; jr      z,B64_DEC_ER3

	ld	a,(B64_TEMPLON)
	cp	2
	jr	c,B64_DEC_ER3

	ld	a,#FF
	jr	B64_DECLOOP4

	;* Intenta decodificar el caracter
	;  y si tiene exito lo guarda

B64_DECLOOP3:	exx
	call	GETB64INDEX
	exx
	jr	nz,B64_DEC_ER3
B64_DECLOOP4:	ld	hl,(B64_DEC_PNT)
	ld	(hl),a
	inc	hl
	ld	(B64_DEC_PNT),hl
	ld	hl,B64_TEMPLON
	inc	(hl)
	jr	B64_DECLOOP

	;--- Fin: si quedan caracteres pendientes
	;    y no era bloque final, error

B64_DEC_END:	ld	bc,(B64_DEC_IY)
	push	iy
	push	iy
	pop	hl
	or	a
	sbc	hl,bc
	push	hl
	pop	bc
	pop	iy

	call	B64_INCTLEN

	ld	a,(B64_IS_FINAL)
	or	a
	ret	z

	ld	a,(B64_TEMPLON)
	or	a
	ret	z

	ld	a,2
	scf
	ret

	;--- Error 3

B64_DEC_ER3:	ld	a,3
	scf
	ret

B64_DEC_IY:	dw	0


;--- B64_DEC4: Decodifica un cuatrete de caracteres en B64
;    Entrada:  Cuatrete en B64_INTEMP, ya desinterpretado
;              (son caracteres 0-63 o #FF para "=")
;              IY=Dir de destino
;    Salida:   IY=IY+1, 2 o 3
;    Modifica: AF, HL, BC

B64_DEC4:	ld	hl,(B64_INTEMP)	;Lee cuatrete en
	ld	de,(B64_INTEMP+2)	;L, H, E, D

	ld	a,l
	sla	a
	sla	a
	and	%11111100
	ld	b,a
	ld	a,h
	sra	a
	sra	a
	sra	a
	sra	a
	and	%00000011
	or	b
	ld	(iy),a

	ld	a,e
	cp	#FF
	jr	z,B64_DEC4_END1

	ld	a,h
	sla	a
	sla	a
	sla	a
	sla	a
	and	%11110000
	ld	b,a
	ld	a,e
	sra	a
	sra	a
	and	%00001111
	or	b
	ld	(iy+1),a

	ld	a,d
	cp	#FF
	jr	z,B64_DEC4_END2

	ld	a,e
	rrca
	rrca
	and	%11000000
	ld	b,a
	ld	a,d
	and	%00111111
	or	b
	ld	(iy+2),a

	inc	iy
B64_DEC4_END2:	inc	iy
B64_DEC4_END1:	inc	iy
	ret


;--- GETB64CHAR: Obtiene un caracter B64 a partir de su indice
;    Entrada:  A=Indice (0-63)
;    Salida:   A=Caracter
;    Modifica: AF, HL, BC

GETB64CHAR:	ld	hl,B64TABLE
	ld	c,a
	ld	b,0
	add	hl,bc
	ld	a,(hl)
	ret


;--- GETB64INDEX: Obtiene el indice de un caracter B64
;    Entrada:  A=Caracter
;    Salida:   A=Indice y Z=1 (A=#FF y Z=0 si no se encuentra)
;    Modifica: AF, HL, BC

GETB64INDEX:	ld	hl,B64TABLE+63
	ld	bc,64
	cpdr
	ld	a,#FF
	ret	nz
	ld	a,c
	ret


;--- B64_INCTLEN: Incrementa el campo B64_TOTLEN por BC
;    Entrada:  BC = Longitud a sumar
;    Salida:   HL:DE = Nuevo valor de B64_TOTLEN
;    Modifica: F, HL, DE

B64_INCTLEN:	ld	hl,(B64_TOTLEN)
	add	hl,bc
	ld	(B64_TOTLEN),hl
	ex	de,hl
	ld	hl,(B64_TOTLEN+2)
	ret	nc
	inc	hl
	ld	(B64_TOTLEN+2),hl
	ret


;--- Variables

B64TABLE:	db	"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	db	"abcdefghijklmnopqrstuvwxyz"
	db	"0123456789+/"
B64_CRINT:	db	0	;Intervalo entre inserciones de CRLF
	;en grupos de 4 (0=no insertar)
B64_CRCNT:	db	0	;Contador para insertar CRLF
B64_INTEMP:	ds	4	;Para guardar temporalmente un cuanto incompleto
B64_TEMPLON:	db	0	;Longitud cuanto incompleto
B64_DEC_PNT:	dw	0	;Puntero para rellenar B64_INTEMP al decodificar Base64
B64_TOTLEN:	ds	4	;Longitud total acumulada de los bloques de salida
B64_IS_FINAL:	db	0
B64_DEC_FIN:	db	0


;****************************
;***                      ***
;***  RUTINAS DE USUARIO  ***
;***                      ***
;****************************


	;====================
	;===  VERS_PAUSE  ===
	;====================

;Devuelve el numero de version de INL, y opcionalmente
;pausa o reactiva INL.
;Entrada: A = 0 para solo devolver informacion
;             1 para pausar INL
;             2 para reactivar INL
;Salida:  A = 1 si INL esta pausado, 2 si esta activo
;         C = Version principal de INL
;         D = Version secundaria
;         E = Revision
;         B = Tipo: 1 = INL para ObsoNET

_VERS_PAUSE:	;ld	ix,(P3_P3DIR)
	push	af
	ld	de,#2203
	call	#FFCA
	pop	af
	push	hl
	pop	ix

	or	a
	jr	z,VERS_PAUSEND

	dec	a
	jr	nz,VERS_PAUSE2

	;--- Pausa

VERS_PAUSE1:	xor	a
	di
	ld	(ix),a
	ld	(ix+1),a
	ld	(ix+2),a
	ei
	jr	VERS_PAUSEND

	;--- Reactivacion

VERS_PAUSE2:	ld	a,#CD
	di
	ld	(ix),a
	ld	a,(ix+8)
	ld	(ix+1),a
	ld	a,(ix+9)
	ld	(ix+2),a
	ei

	;--- Informacion

VERS_PAUSEND:	ld	a,(ix)
	and	1
	inc	a

	ld	bc,INL_VERSION1+256	;Implica B=1
	ld	de,INL_VERSION3+256*INL_VERSION2
	ret


	;=================
	;===  GET_VAR  ===
	;=================

;Lee la variable HL del segmento de variables.
;Devuelve el resultado en A (1 byte) y en DE (2 bytes).
;Preserva HL.

_GET_VAR:	push	hl
	call	SETUP_P2
	set	7,h	;Adapta la dir a la pagina 2
	res	6,h

	ld	a,(hl)
	ld	e,(hl)
	inc	hl
	ld	d,(hl)

	pop	hl
	call	RESTORE_P2
	ret


	;=================
	;===  SET_VAR  ===
	;=================

;Establece la variable HL del segmento de variables.
;Si Cy=0, establece un byte con A; si es 1, establece dos bytes con DE.

_SET_VAR:	push	hl,af,de
	call	SETUP_P2
	set	7,h	;Adapta la dir a la pagina 2
	res	6,h
	pop	de,af

	jr	c,SET2BYTES

SET1BYTE:	ld	(hl),a
	jr	SETVAR2

SET2BYTES:	ld	(hl),e
	inc	hl
	ld	(hl),d

SETVAR2:	pop	hl
	jp	RESTORE_P2


	;===================
	;===  COPY_DATA  ===
	;===================

;Copia un bloque de datos de TPA al seg de datos o viceversa.
;Entrada: HL=Origen, DE=Destino, BC=Longitud
;Cy=0 para transferir Seg->TPA, 1 para TPA->SEG

_COPY_DATA:	call	SETUP_P2
	ld	ix,RESTORE_P2
	push	ix
	jp	c,LDIR_ST
	jp	LDIR_TS


	;===================
	;===  IP_STRING  ===
	;===================

;Convierte una direccion IP a una cadena.
;Entrada: L.H.E.D = Direccion IP
;         IX = Bufer para dejar la cadena (en TPA)
;         A = Caracter de terminacion

_IP_STRING:	push	ix,af
	call	SETUP_P2
	ld	ix,OUT_BUFFER+500

	ld	a,#FF
	ld	(DISABLE_INT),a

	ld	a,l
	call	BYTE2ASC
	ld	(ix),"."
	inc	ix
	ld	a,h
	call	BYTE2ASC
	ld	(ix),"."
	inc	ix
	ld	a,e
	call	BYTE2ASC
	ld	(ix),"."
	inc	ix
	ld	a,d
	call	BYTE2ASC

	pop	af	;Caracter de terminacion
	ld	(ix),a

	push	ix
	pop	hl
	inc	hl	;Calcula longitud resultante
	ld	bc,OUT_BUFFER+500
	or	a
	sbc	hl,bc
	push	hl
	pop	bc

	pop	de	;Copiamos resultado a TPA
	ld	hl,OUT_BUFFER+500
	;ld      bc,16
	call	LDIR_TS

	xor	a
	ld	(DISABLE_INT),a

	jp	RESTORE_P2

;Conversion del numero A en una cadena sin terminacion
;Deposita la cadena en (IX), y modifica IX para que apunte tras la cadena
;Modifica C

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


	;==================
	;===  USER_MD5  ===
	;==================

;Calcula una digestion MD5 de un mensaje hasta 1024 bytes.
;Entrada: HL=Dir mensaje en TPA, DE=Dir destino en TPA (16 bytes), BC=Longitud
;Salida:  Cy=1 si error (mensaje >1024 bytes)

_USER_MD5:	call	SETUP_P2

	ld	a,#FF
	ld	(DISABLE_INT),a

	;Longitud valida?

	push	hl,de,bc
	pop	hl
	push	hl
	ld	de,1025
	call	COMP
	pop	bc,de,hl
	ld	a,1
	jp	c,CALC_MD5_END

	;Copia mensaje a OUT_BUFFER

	push	de,bc
	ld	de,IN_BUFFER
	ld	a,b
	or	c
	call	nz,LDIR_ST

	;Calcula digestion

	pop	bc
	ld	hl,IN_BUFFER
	call	MD5

	;Copia resultado a TPA

	ld	de,IN_BUFFER	;Primero hay que pasarlo
	ld	bc,16	;al seg. de datos
	ldir

	ld	hl,IN_BUFFER
	pop	de
	ld	bc,16
	call	LDIR_TS

	;Termina

	xor	a

CALC_MD5_END:	push	af
	xor	a
	ld	(DISABLE_INT),a
	pop	af

	jp	RESTORE_P2


	;=====================
	;===  USER_CHKSUM  ===
	;=====================

;Calcula el checksum de un paquete de hasta 1024 bytes.
;Entrada: HL=Dir paquete en TPA, BC=Longitud
;Salida:  Cy=1 si error (paquete >1024 bytes o 0)
;         DE=Checksum

_USER_CHKSUM:	call	SETUP_P2

	ld	a,#FF
	ld	(DISABLE_INT),a

	;Longitud valida?

	push	hl,bc
	pop	hl
	push	hl
	ld	de,1025
	call	COMP
	pop	bc,hl
	ld	a,1
	jr	c,USER_CHKS_END
	ld	a,b
	or	c
	ld	a,1
	scf
	jr	z,USER_CHKS_END

	;Copia mensaje a OUT_BUFFER

	push	bc
	ld	de,IN_BUFFER
	call	LDIR_ST

	;Calcula checksum

	pop	bc
	ld	ix,IN_BUFFER
	call	CALC_CHKSUM

	;Termina

	xor	a

USER_CHKS_END:	push	af
	xor	a
	ld	(DISABLE_INT),a
	pop	af

	jp	RESTORE_P2


	;======================
	;===  USER_B64INIT  ===
	;======================

;Inicia una operacion de (de)codificacion Base64
;Entrada: A=Tamanyo de una linea codificada
;Salida:  Todos los registros preservados

;> Se salta directamente a la rutina B64_INIT


	;=====================
	;===  USER_B64ENC  ===
	;=====================

;Codifica un bloque en Base64
;Entrada: IX=Origen en TPA
;         IY=Destino en TPA
;         BC=Tamanyo (0 a 512)
;         Cy=0 para bloque intermedio, 1 para final
;Salida:  IX=IX+BC inicial
;         IY=IY+BC final
;         HL:DE=Tamanyo acumulado de salida
;         BC=Tamanyo de salida
;         Cy=1 y A=1 si BC>512 a la entrada

_USER_B64ENC:	ld	hl,B64_ENCB
	jr	_USER_B64


	;=====================
	;===  USER_B64DEC  ===
	;=====================

;Decodifica un bloque desde Base64
;Entrada: IX=Origen en TPA
;         IY=Destino en TPA
;         BC=Tamanyo (0 a 512)
;         Cy=0 para bloque intermedio, 1 para final
;Salida:  IX=IX+BC inicial
;         IY=IY+BC final
;         HL:DE=Tamanyo acumulado de salida
;         BC=Tamanyo de salida
;         Cy=1 si error:
;              A=1 si BC>512 a la entrada
;              A=2 si longitud invalida en bloque final
;              A=3 si caracteres invalidos encontrados

_USER_B64DEC:	ld	hl,B64_DECB
	;jr      _USER_B64


	;*** Codigo comun para USER_B64ENC y USER_B64DEC
	;    Entrada: HL=Rutina a ejecutar

_USER_B64:	ld	(UB64_RUT+1),hl
	ld	(UB64_SOURCE),ix
	ld	(UB64_DEST),iy
	ld	(UB64_ISIZE),bc

	push	af
	push	bc
	pop	hl
	ld	de,513
	call	COMP
	jr	nc,UB64_OK1

	pop	af
	scf
	ld	a,1
	ret
UB64_OK1:

	call	SETUP_P2
	ld	a,#FF
	ld	(DISABLE_INT),a

	;--- Copia datos de TPA

	ld	hl,(UB64_SOURCE)
	ld	de,OUT_BUFFER
	ld	a,b
	or	c
	call	nz,LDIR_ST

	;--- Realiza la codificacion

	pop	af	;Cy=Bloque intermedio o final
	ld	bc,(UB64_ISIZE)
	ld	ix,OUT_BUFFER
	ld	iy,IN_BUFFER
UB64_RUT:	call	0	;Se establece a B64_ENCB o B64_DECB
	jr	c,UB64_END

	;--- Copia el bloque resultante a TPA

	push	hl,de,bc
	ld	hl,IN_BUFFER
	ld	de,(UB64_DEST)
	ld	a,b
	or	c
	call	nz,LDIR_TS

	;--- Establece variables y termina

	ld	hl,(UB64_SOURCE)
	ld	bc,(UB64_ISIZE)
	add	hl,bc
	push	hl
	pop	ix

	pop	bc
	ld	hl,(UB64_DEST)
	add	hl,bc
	push	hl
	pop	iy

	pop	de,hl	;Tamanyo acumulado
	xor	a
UB64_END:	push	af
	xor	a
	ld	(DISABLE_INT),a
	pop	af
	call	RESTORE_P2
	ret

UB64_SOURCE:	dw	0
UB64_DEST:	dw	0
UB64_ISIZE:	dw	0


	;===================
	;===  SEND_ECHO  ===
	;===================

;Envia un mensaje ICMP Echo Request.
;Entrada: L.H.E.D. = IP de destino
;         A = TTL
;         IX = Identificador
;         IY = Numero de secuencia
;         BC = Longitud de los datos (-1: usar PING_SIZE)
;	Cy = 1 si error (no hay conexion a red)

_SEND_ECHO:	call	SETUP_P2

	push	bc
	ld	b,a
	ld	a,(NET_STATE)
	or	a
	ld	a,b
	pop	bc
	scf
	jp	z,RESTORE_P2

	ex	af,af
	ld	a,#FF
	ld	(DISABLE_INT),a
	ex	af,af

	;--- Compone paquete a enviar

	push	af,hl,de

	ld	hl,#0008	;Tipo y codigo
	ld	(OUT_BUFFER+24),hl
	ld	hl,0
	ld	(OUT_BUFFER+26),hl	;Checksum, de momento 0
	ld	a,ixh
	ld	(OUT_BUFFER+28),a	;Identificador
	ld	a,ixl
	ld	(OUT_BUFFER+29),a
	ld	a,iyh
	ld	(OUT_BUFFER+30),a	;Num. secuencia
	ld	a,iyl
	ld	(OUT_BUFFER+31),a

	inc	bc
	ld	a,b
	or	c
	dec	bc
	jr	nz,NO_PING64

	ld	bc,(PING_SIZE)
NO_PING64:	push	bc
	ld	a,b
	or	c
	jr	z,SECHO_OKDATA

	xor	a
	ld	hl,OUT_BUFFER+32
SECHO_LOOP:	ld	(hl),a	;Compone la parte de datos
	inc	a
	inc	hl
	dec	bc
	ld	d,a
	ld	a,b
	or	c
	ld	a,d
	jr	nz,SECHO_LOOP

SECHO_OKDATA:	pop	bc	;Recupera longitud y suma idem de la cabecera ICMP
	ld	hl,8
	add	hl,bc
	push	hl
	pop	bc
	push	bc
	ld	ix,OUT_BUFFER+24
	call	CALC_CHKSUM
	ld	(OUT_BUFFER+26),de	;Checksum

	;--- Envia paquete IP

	pop	bc,de,hl
	ld	a,(TTL)
	ld	(SAVE_TTL),a
	pop	af
	ld	(TTL),a
	ld	a,1	;Protocolo ICMP

	call	SEND_IP
	ld	a,(SAVE_TTL)
	ld	(TTL),a

	;--- Fin

	xor	a
	ld	(DISABLE_INT),a
	call	RESTORE_P2
	ret

SAVE_TTL:	db	0


	;==================
	;===  RCV_ECHO  ===
	;==================

;Obtiene el mensaje ICMP Echo Reply mas antiguo.
;Salida: L.H.E.D. = IP de origen
;        A = TTL
;        IX = Identificador
;        IY = Numero de secuencia
;        BC = Longitud de los datos
;	Cy = 1 si no hay paquetes disponibles

_RCV_ECHO:	call	SETUP_P2

	ld	a,#FF
	ld	(DISABLE_INT),a

	ld	a,(ICMPI_GINDEX)
	ld	b,a

	inc	b
	ld	ix,ICMPI_IP0-11
	ld	de,11
BUC_EREP2:	add	ix,de
	djnz	BUC_EREP2	;Ahora IX apunta a la zona de datos adecuada

	ld	a,(ICMPI_PINDEX)
	ld	b,a
	ld	a,(ICMPI_GINDEX)
	cp	b
	jr	nz,EREP_HAYECOS

	ld	a,(ix)	;Indice GET = Indice PUT:
	or	(ix+1)	;Hay ecos si entrada no vacia (IP<>0),
	or	(ix+2)	;si no, terminamos con error.
	or	(ix+3)
	scf
	jr	z,END_RCV_ECHO
EREP_HAYECOS:	;

	ld	l,(ix)	;IP origen
	ld	h,(ix+1)
	ld	e,(ix+2)
	ld	d,(ix+3)
	ld	(ix),0	;Pone ceros para liberar la entrada
	ld	(ix+1),0
	ld	(ix+2),0
	ld	(ix+3),0

	ld	a,(ix+4)	;TTL

	ld	c,(ix+9)	;Tamanyo datos
	ld	b,(ix+10)

	exx
	ld	l,(ix+5)	;Identificador
	ld	h,(ix+6)
	ld	e,(ix+7)	;Num. secuencia
	ld	d,(ix+8)

	push	hl,de
	pop	iy,ix
	exx

	ex	af,af	;Incrementa entrada, salta de 7 a 0
	ld	a,(ICMPI_GINDEX)
	inc	a
	and	%111
	ld	(ICMPI_GINDEX),a
	ex	af,af

	or	a	;Fin sin error

END_RCV_ECHO:	push	af
	xor	a
	ld	(DISABLE_INT),a
	call	RESTORE_P2
	pop	af
	ret


	;==================
	;===  UDP_SEND  ===
	;==================

;Envia un paquete UDP
;Entrada: L.H.E.D. = IP de destino
;         IX = Puerto origen
;         IY = Puerto destino
;	BC = Direccion de los datos en TPA
;         AF = Longitud de los datos (hasta 556 bytes)
;Salida:  Cy = 1 si no hay conexion a red o el paquete es demasiado grande

_UDP_SEND:	call	SETUP_P2
	push	af
	ld	a,(NET_STATE)
	or	a
	jr	nz,UDPS_OKNET

UDPS_ERR:	pop	af
	call	RESTORE_P2
	scf
	ret

	;Longitud correcta?

UDPS_OKNET:	ex	(sp),hl	;Ahora, IP en la pila y long en HL
	push	de
	ld	de,549	;Lon. max. datos = 548 bytes
	call	COMP
	pop	de
	jr	c,UDPS_ERR

	ld	a,#FF
	ld	(DISABLE_INT),a

	ld	a,h
	or	l
	jr	z,UDPS_OKCOPY

	;Copia los datos a OUT_BUFFER+32

	push	de,ix,iy,hl	;Quedan en la pila: IP,puertos,long
	push	hl,bc	;Intercambia HL y BC:
	pop	hl,bc	;Ahora HL = Origen en TPA, BC = Longitud
	ld	de,OUT_BUFFER+32
	call	LDIR_ST
	pop	hl,iy,ix,de
UDPS_OKCOPY:

	;Envia el datagrama

	push	hl
	pop	bc	;BC = Long
	pop	hl	;HL y DE = IP
	call	SEND_UDP

	xor	a
	ld	(DISABLE_INT),a

	call	RESTORE_P2
	or	a
	ret


	;=================
	;===  UDP_RCV  ===
	;=================

;Obtiene el mensaje UDP mas antiguo.
;Entrada: HL = Donde dejar el mensaje (0 si no se quiere)
;Salida: L.H.E.D. = IP de origen
;        IX = Puerto origen
;        IY = Puerto destino
;        BC = Longitud de los datos
;        Cy = 1 si no hay paquetes disponibles

_UDP_RCV:	call	SETUP_P2

	ld	a,#FF
	ld	(DISABLE_INT),a

	ld	a,(UDPI_GINDEX)
	ld	b,a

	inc	b
	ld	ix,UDPI_IP0-10
	ld	de,10
BUC_UDP2:	add	ix,de
	djnz	BUC_UDP2	;Ahora IX apunta a la zona de datos adecuada

	ld	a,(UDPI_PINDEX)
	ld	b,a
	ld	a,(UDPI_GINDEX)
	cp	b
	jr	nz,UDP_HAYALGOS

	ld	a,(ix)	;Indice GET = Indice PUT:
	or	(ix+1)	;Hay ecos si entrada no vacia (IP<>0),
	or	(ix+2)	;si no, terminamos con error.
	or	(ix+3)
	scf
	jr	z,END_UDP_RCV
UDP_HAYALGOS:	;

	ld	c,(ix+8)	;Tamanyo datos
	ld	b,(ix+9)
	ld	a,h	;Queremos los datos?
	or	l
	jr	z,UDP_OKGDATA
	ld	a,b	;Hay datos?
	or	c
	jr	z,UDP_OKGDATA

	ex	de,hl	;Copia datos a TPA
	push	de,bc
	ld	hl,UDP_BUFFERS-512
	ld	de,512
	ld	a,(UDPI_GINDEX)
	inc	a
	ld	b,a
UDPLEN_LOP2:	add	hl,de
	djnz	UDPLEN_LOP2
	pop	bc,de
	push	ix,bc
	call	LDIR_TS
	pop	bc,ix

UDP_OKGDATA:	ld	l,(ix)	;IP origen
	ld	h,(ix+1)
	ld	e,(ix+2)
	ld	d,(ix+3)
	ld	(ix),0	;Pone ceros para liberar la entrada
	ld	(ix+1),0
	ld	(ix+2),0
	ld	(ix+3),0

	exx
	ld	l,(ix+4)	;Puerto origen
	ld	h,(ix+5)
	ld	e,(ix+6)	;Puerto destino
	ld	d,(ix+7)

	push	hl,de
	pop	iy,ix
	exx

	push	hl,bc
	ld	hl,UDPI_GINDEX
	call	INC_UDPINDEX	;Incrementa entrada, salta de 7 a 0
	pop	bc,hl

	xor	a	;Fin sin error

END_UDP_RCV:	push	af
	xor	a
	ld	(DISABLE_INT),a
	call	RESTORE_P2
	pop	af
	ret


	;===============
	;===  DNS_Q  ===
	;===============

;Realiza una peticion DNS.
;Entrada: HL = Puntero al nombre a resolver en TPA, acabado en 0 (max 255 chars)
;         A  = Banderas:
;              bit 0: Solo interrumpir consulta en curso
;                     (ignora el resto de banderas y registros)
;              bit 1: NO consultar los DNS
;                     (interpretar el nombre como una IP)
;              bit 2: NO interrumpir una posible consulta ya en curso
;                     (devolver error en ese caso)
;Salida:  Cy=1 y A=error:
;                1: No hay conexion a internet
;                2: Hay una consulta en curso (solo si A:0 establecido)
;                3: No es una IP valida (solo si A:1 establecido)
;                4: No hay DNS negociados
;         Cy=0 y A=resultado:
;                0: OK, consulta en curso (o cancelada)
;                1: OK, el nombre era una IP directa
;         HL, DE: Direccion IP (solo si se devuelve A=1)
;                 con el siguiente formato: L.H.E.D

DNSQ_FLAGS:	equ	#8C58+100	;OUT_BUFFER+100
DNSQ_HL:	equ	#8C58+101	;OUT_BUFFER+101

_DNS_Q:	call	SETUP_P2
	ld	(DNSQ_HL),hl
	ld	(DNSQ_FLAGS),a
	ld	a,(NET_STATE)
	or	a
	jr	nz,DNSQ_OKNET

	call	RESTORE_P2
	scf
	ld	a,1
	ret

DNSQ_OKNET:	ld	a,#FF
	ld	(DISABLE_INT),a

	;--- Solo hay que abortar una consulta existente?

	ld	a,(DNSQ_FLAGS)	;Si A:0=1, abortar consulta
	and	%00000001	;y terminar
	jr	z,DNSQ_NOAB
	ld	a,3
	ld	(DNS_STAT_P),a
	ld	a,18
	ld	(DNS_STAT_S),a
	or	a
	jp	DNSQ_END
DNSQ_NOAB:	;

	;--- Hay una consulta en curso y no hay que abortarla?

	ld	a,(DNSQ_FLAGS)
	and	%00000100
	jr	z,IP_DNSQ2

	ld	a,(DNS_STAT_P)	;Si A:2=1 y existe una consulta en curso,
	cp	1	;devolver error 2
	ld	a,2
	scf
	jp	z,DNSQ_END
IP_DNSQ2:	;

	;--- Obtiene el nombre a resolver,
	;    y primero comprueba si es una IP

	xor	a	;Aborta posible consulta en curso
	ld	(DNS_STAT_P),a
	ld	(DNS_STAT_S),a

	ld	hl,(DNSQ_HL)	;Copia cadena a DNS_BUFFER,
	ld	de,DNS_BUFFER	;solo los primeros 255 bytes
	ld	bc,255
	call	LDIR_ST
	xor	a
	ld	(DNS_BUFFER+255),a

	call	PARSE_IP
	jr	c,IP_DNSQ3

	ld	a,2	;Si era una IP, la devuelve
	ld	(DNS_STAT_P),a	;y establece estado como prim=2, sec=1
	dec	a
	ld	(DNS_STAT_S),a
	or	a
	ld	hl,(DNS_RESULT)
	ld	de,(DNS_RESULT+2)
	or	a
	jp	DNSQ_END

IP_DNSQ3:	ld	a,(DNSQ_FLAGS)	;Si no es una IP valida y se ha especificado
	and	%00000010	;"no consultar DNS", devuelve error 3
	scf
	ld	a,3
	jp	nz,DNSQ_END

	;--- Comprueba que hay algun DNS negociado,
	;    si no lo hay, termina con error 4

	ld	ix,BUF_IPDNS1
	ld	a,(ix)
	or	(ix+1)
	or	(ix+2)
	or	(ix+3)
	or	(ix+4)
	or	(ix+5)
	or	(ix+6)
	or	(ix+7)
	scf
	ld	a,4
	jp	z,DNSQ_END

	;--- Lo deja todo listo para la proxima int

	xor	a
	ld	(DNS_RETRY),a
	inc	a
	ld	(DNS_TOUT),a
	ld	hl,60*60
	ld	(DNS_TTOUT),hl

	ld	a,1
	ld	(DNS_STAT_P),a
	ld	hl,BUF_IPDNS1
	push	hl
	pop	ix
	ld	a,(ix)
	or	(ix+1)
	or	(ix+2)
	or	(ix+3)
	ld	a,1
	jr	nz,DNSQ_NOINC
	ld	hl,BUF_IPDNS2
	inc	a
DNSQ_NOINC:	ld	(DNS_STAT_S),a
	ld	de,DNS_IP
	ld	bc,4
	ldir

	xor	a

	;--- Fin

DNSQ_END:	push	af,hl,de
	xor	a
	ld	(DISABLE_INT),a
	call	RESTORE_P2
	pop	de,hl,af
	ret


	;===============
	;===  DNS_R  ===
	;===============

;Devuelve el estado de una consulta DNS
;Entrada: A  = Banderas:
;              bit 0: Limpiar cualquier resu tado/error existente
;                     despues de la llamada
;                     (excepto si el estado es 1)
;Salida:  A  = Codigo de estado primario
;         B  = Codigo de estado secundario
;         A  = 0: No hay consulta en curso, ni resultado disponible
;              1: Consulta en curso
;                 B=1: Consultando DNS primario
;                 B=2: Consultando DNS secundario
;                 B=3: Consultando otro DNS al que se nos ha redirigido
;              2: Consulta completada, resultado en HL, DE
;                 en formato L.H.E.D
;                 B=0: El nombre no era una IP directa
;                 B=1: El nombre era una IP directa
;              3: Error:
;                 B=1-15: Error devuelto por el DNS
;                 B=16: Alguno de los DNS no ha respondido
;                 (se han enviado DNS_RETRY_V peticiones sin respuesta)
;                 B=17: Timeout total expirado
;                 B=18: Consulta abortada por el usuario
;                 B=19: Se ha perdido la conexion a internet
;                 B=20: La respuesta no contenia REPLY ni AUTHORITATIVE
;                 B=21: La respuesta esta truncada

_DNS_R:	call	SETUP_P2
	ld	c,a

	ld	a,(NET_STATE)	;Si no estamos conectados
	or	a	;pero parece haber una consulta
	jr	nz,DNS_R2	;en curso, establecemos error 19
	ld	a,(DNS_STAT_P)
	cp	1
	jr	nz,DNS_R2
	ld	a,3
	ld	(DNS_STAT_P),a
	ld	a,19
	ld	(DNS_STAT_S),a
DNS_R2:	;

	ld	a,(DNS_STAT_S)
	ld	b,a
	ld	a,(DNS_STAT_P)
	ld	hl,(DNS_RESULT)
	ld	de,(DNS_RESULT+2)
	bit	0,c
	jp	z,RESTORE_P2

	push	af	;A=1 y no hay consulta en curso:
	ld	a,(DNS_STAT_P)	;limpiamos resultado
	cp	1
	jr	z,DNS_R_2
	xor	a
	ld	(DNS_STAT_P),a
	ld	(DNS_STAT_S),a
DNS_R_2:	pop	af

	jp	RESTORE_P2


	;==================
	;===  TCP_OPEN  ===
	;==================

;Abre una conexion TCP nueva.
;Entrada:  A = 0 para activa, 1 para pasiva
;          L.H.E.D = IP remota (0.0.0.0 para pasiva con socket sin especificar)
;          IX = Puerto remoto (ignorado si IP=0.0.0.0) 
;          IY = Puerto local (#FFFF para aleatorio entre 16384 y 32767)
;          BC = Timeout de usuario en segundos
;               (1-1080, 0 para 3 minutos, #FFFF para infinito)
;Salida:   Cy=0 si OK, 1 si error
;          Si OK: A = Numero de conexion
;          Si error: A = Codigo de error:
;             1: Demasiadas conexiones abiertas
;             2: No hay conexion a internet
;             3: Ya existe esa conexion
;             4: Conexion activa con IP=0.0.0.0
;             5: Valor de BC invalido

_TCP_OPEN:	call	SETUP_P2

	;--- Guarda los parametros de entrada en el TCB temporal

	push	af
	ld	a,#FF
	ld	(DISABLE_INT),a
	pop	af
	ld	(PASSIVE_OPEN),a
	ld	(REMOTE_IP),hl
	ld	(REMOTE_IP+2),de
	ld	(REMOTE_PORT),ix
	ld	(LOCAL_PORT),iy

	push	bc
	ld	hl,TCB_TEMP+10	;Limpia el resto del TCB
	ld	de,TCB_TEMP+11
	ld	bc,TCB_SIZE-10-1
	ld	(hl),0
	ldir

	pop	hl	;Timeout de usuario: comprueba valor,
	ld	de,#FFFF	;Si es #FFFF (infinito), lo deja como esta
	call	COMP
	jr	z,UTOUT_OK

	ld	a,h
	or	l
	jr	nz,TCPOP_BCNOZ
	ld	hl,UTOUT_DEF	;3 minutos
TCPOP_BCNOZ:	ld	de,1080
	call	COMP	;Cy si HL>=DE
	jr	nc,TCPOP_OKBC
	ld	a,5
	scf
	jp	TCP_OPEND
TCPOP_OKBC:

	;--- Multiplica el timeout de usuario por 60

	add	hl,hl	;*2
	add	hl,hl	;*4
	push	hl
	add	hl,hl	;*8
	push	hl
	add	hl,hl	;*16
	push	hl
	add	hl,hl	;*32
	pop	bc
	add	hl,bc	;*(32+16)
	pop	bc
	add	hl,bc	;*(32+16+8)
	pop	bc
	add	hl,bc	;*(32+16+8+4) = *60
UTOUT_OK:	ld	(USER_TOUT_V),hl

	;--- Hay conexion a internet?

	ld	a,(NET_STATE)
	or	a
	jr	nz,TCPOP_OKNET

	ld	a,2
	scf
	jp	TCP_OPEND
TCPOP_OKNET:

	;--- Conexion activa con IP cero?

	call	TCP_IS_ZERO
	jr	nz,TCPOP_OKIP

	ld	hl,0	;De paso pone puerto remoto a 0 si la IP es cero
	ld	(REMOTE_PORT),hl

	ld	a,(PASSIVE_OPEN)	;Aqui, la IP es cero
	or	a
	jr	nz,TCPOP_OKIP

	ld	a,4
	scf
	jp	TCP_OPEND
TCPOP_OKIP:

	;--- Hay conexiones libres?

	call	SEARCH_FRTCP
	cp	#FF
	jr	nz,TCPOP_OKFREE

	ld	a,1
	scf
	jp	TCP_OPEND

TCPOP_OKFREE:	ld	(CURTCB_NUM),a	;De paso almacena el numero de conexion

	;--- Si el puerto local es #FFFF, escoge uno aleatoriamente
	;    en el rango 16384-32767 (#4000-#7FFF)

	xor	a
	ld	(RAND_PORT),a
	ld	hl,(LOCAL_PORT)
	ld	de,#FFFF
	call	COMP
	jr	nz,TCPOP_OKPORT

	ld	a,#FF
	ld	(RAND_PORT),a
TCPOP_RNDPORT:	ld	hl,(SYSTIMER)	;Valor del temporizador del sistema
	res	7,h	;Lo transforma al rango adecuado
	set	6,h
	ld	(LOCAL_PORT),hl
TCPOP_OKPORT:

	;--- Comprueba si la conexion existe
	;    (a no ser que la IP remota no este especificada)

	call	TCP_IS_ZERO
	jr	z,TCPOP_OKEX

	ld	hl,(REMOTE_IP)
	ld	de,(REMOTE_IP+2)
	ld	ix,(REMOTE_PORT)
	ld	iy,(LOCAL_PORT)
	call	SEARCH_TCP
	cp	#FF
	jr	z,TCPOP_OKEX

	;La conexion existe: si el puerto era aleatorio
	;escogemos otro; si no, devolvemos error

	ld	a,(RAND_PORT)
	or	a
	jr	nz,TCPOP_RNDPORT

	ld	a,3
	scf
	jr	TCP_OPEND
TCPOP_OKEX:

	;>> En este punto los parametros son validos:
	;>> ya podemos abrir la conexion

	;--- Inicializamos los buferes para datos

	ld	hl,#A000-2048	;Calcula direccion del bufer:
	ld	de,2048	;#A000+2048*num. conexion
	ld	a,(CURTCB_NUM)
	inc	a
	ld	b,a
CURTCB_BUFLOP:	add	hl,de
	djnz	CURTCB_BUFLOP

	push	hl
	ld	bc,1024
	ld	ix,INBUF	;Bufer de datos entrantes
	call	RBUF_INIT

	pop	hl
	ld	bc,1024
	add	hl,bc	;Bufer de datos salientes, 1024 bytes despues
	ld	ix,OUTBUF
	call	RBUF_INIT

	;--- Si es conexion pasiva, entramos en estado LISTEN y fin

	ld	a,(PASSIVE_OPEN)
	or	a
	jr	z,TCPOP_NOPAS

	ld	a,LISTEN
	ld	(TCP_STATE),a
	jr	TCP_OPEND2
TCPOP_NOPAS:

	;--- Activa: envia un segmento con SYN, establece SYN-SENT y termina

	ld	a,2
	call	SEND_SYN
	ld	a,SYN.SENT
	ld	(TCP_STATE),a

	;Set SND.UNA to ISS: no hace falta, ya son los dos 0
	;Set SND.NXT to ISS+1:
	ld	a,1
	ld	(SND_NXT+3),a

	ld	a,RTO_V*60	;Inicializa temporizadores
	ld	(RTO_T),a
	ld	hl,(USER_TOUT_V)
	ld	(USER_TOUT),hl


TCP_OPEND2:	call	SAVE_TCB
	ld	a,(CURTCB_NUM)	;Hay que devolver el num. de conexion
	or	a
TCP_OPEND:	push	af
	xor	a
	ld	(DISABLE_INT),a

	pop	af
	jp	RESTORE_P2

RAND_PORT:	db	0



	;===================
	;===  TCP_CLOSE  ===
	;===================

;Cierra una conexion TCP
;Entrada:  A = Numero de conexion
;Salida:   Cy=1 si error, y A=Codigo:
;             1: Numero de conexion invalido
;             2: Conexion ya cerrada

_TCP_CLOSE:	call	SETUP_P2

	;--- Comprueba condiciones de error

	ld	b,a
	call	CHK_TCP_EXIST
	jp	c,RESTORE_P2

	;--- Carga TCB y actua segun estado de la conexion

	ld	a,#FF
	ld	(DISABLE_INT),a
	ld	a,b

	call	LOAD_TCB
	ld	a,(TCP_STATE)

	;> LISTEN o SYN-SENT (1 o 2): Borra el TCB sin mas

	cp	3
	jr	nc,TCP_CL_1

	xor	a
	ld	(TCP_STATE),a
	ld	a,1
	ld	(LAST_CLOSE),a
	jr	TCP_CL_END
TCP_CL_1:

	;> SYN-RECEIVED o ESTABLISHED (3 o 4): Va a FIN-WAIT-1
	;  y establece FIN_PENDING

	cp	5
	jr	nc,TCP_CL_2

	ld	a,#FF
	ld	(FIN_PENDING),a
	ld	a,FIN.WAIT.1
	ld	(TCP_STATE),a
	xor	a
	ld	(SYN_SENT_FLAG),a
	jr	TCP_CL_PEND
TCP_CL_2:

	;> CLOSE_WAIT: Establece FIN_PENDING

	cp	CLOSE.WAIT
	jr	nz,TCP_CL_END

TCP_CL_PEND:
	ld	a,#FF
	ld	(FIN_PENDING),a

	;> En cualquier otro estado no hace nada y termina

TCP_CL_END:	call	SAVE_TCB

	xor	a
	ld	(DISABLE_INT),a
	jp	RESTORE_P2


	;===================
	;===  TCP_ABORT  ===
	;===================

;Aborta una conexion TCP
;Entrada:  A = Numero de conexion
;Salida:   Cy=1 si error, y A=Codigo:
;             1: Numero de conexion invalido
;             2: Conexion ya cerrada

_TCP_ABORT:	call	SETUP_P2

	ld	b,a
	call	CHK_TCP_EXIST	;Comprueba condicion de error
	jp	c,RESTORE_P2

	ld	a,#FF
	ld	(DISABLE_INT),a
	ld	a,b

	;--- Carga el TCB de la conexion, lo borra,
	;    y envia un RST si estamos en SYN-RECEIVED a CLOSE-WAIT

	call	LOAD_TCB
	ld	a,(TCP_STATE)
	push	af
	xor	a
	ld	(TCP_STATE),a
	ld	a,2
	ld	(LAST_CLOSE),a
	call	SAVE_TCB
	pop	af

	cp	3	;SYN-RECEIVED=3, CLOSE-WAIT=7
	jr	c,TCP_AB_OK
	cp	8
	ld	a,0
	call	c,SEND_RST

TCP_AB_OK:	xor	a
	ld	(DISABLE_INT),a
	jp	RESTORE_P2


	;==================
	;===  TCP_SEND  ===
	;==================

;Envia datos a una conexion TCP
;Entrada:  A = Numero de conexion
;          HL = Direccion de los datos
;          BC = Longitud de los datos
;          Cy=1 para PUSH
;Salida:   Cy=1 si error, y A=Codigo:
;             1: Numero de conexion invalido
;             2: Conexion cerrada
;             3: Conexion en estado invalido para el envio
;             4: Espacio insuficiente para guardar los datos

_TCP_SEND:	call	SETUP_P2

	ld	(TCP_SEND_HL),hl
	ld	(TCP_SEND_BC),bc
	push	af
	pop	de	;D = Num. de conexion
	ld	a,e
	and	1
	ld	(TCP_SEND_CY),a

	;--- Comprueba condiciones de error 1 y 2

	ld	a,d
	call	CHK_TCP_EXIST
	jp	c,RESTORE_P2

	ld	a,#FF
	ld	(DISABLE_INT),a

	;--- Carga el TCB de la conexion y comprueba otros parametros

	ld	a,d
	call	LOAD_TCB

	ld	a,(FIN_PENDING)
	or	a
	jr	nz,TCP_SND_ERR4
	ld	a,(TCP_STATE)	;Comprueba que este ESTABLISHED o CLOSE_WAIT
	cp	ESTABLISHED
	jr	z,TCP_SND_OK1
	cp	CLOSE.WAIT
	jr	z,TCP_SND_OK1

TCP_SND_ERR4:	ld	a,3	;Error si el estado es invalido para el envio
	scf
	jr	TCP_SND_END
TCP_SND_OK1:

	ld	hl,(OUTBUF_USED)
	ld	(TCP_SND_OLDUSED),hl	;Lo usaremos para establecer SEND_TOUT

	ld	de,(TCP_SEND_BC)	;Comprueba que haya espacio suficiente para los datos
	ld	a,d
	or	e
	jr	z,TCP_SND_OK3
	ld	hl,(OUTBUF_FREE)
	call	COMP
	jr	c,TCP_SND_OK2

	ld	a,4	;Error si no hay espacio suficiente para los datos
	scf
	jr	TCP_SND_END
TCP_SND_OK2:

	;--- Obtiene los datos, los encola,
	;    y establece SEND_PUSH_PEND si es necesario

	ld	hl,(TCP_SEND_HL)
	ld	de,IN_BUFFER	;Usa IN_BUFFER+OUT_BUFFER, que es >1024 bytes
	ld	bc,(TCP_SEND_BC)
	call	LDIR_ST

	ld	ix,OUTBUF	;Inserta los datos en el bufer circular
	ld	hl,IN_BUFFER
	ld	bc,(TCP_SEND_BC)
	call	RBUF_INSERT

TCP_SND_OK3:	;Salta aqui si hay 0 bytes a enviar
	ld	a,(TCP_SEND_CY)	;PUSH?
	or	a
	jr	z,TCP_SND_OK4
	ld	hl,(OUTBUF_USED)
	ld	(SEND_PUSH_PEND),hl
TCP_SND_OK4:

	ld	hl,(TCP_SND_OLDUSED)	;Si antes la cola de salida estaba vacia,
	ld	a,h	;iniciamos el contador de 0.5 seg para el envio
	or	l
	jr	nz,TCP_SND_OK5
	ld	hl,SEND_TOUT_V	;0.5 segundos
	ld	(SEND_TOUT),hl
TCP_SND_OK5:

	;--- Restaura estado y termina

	call	SAVE_TCB
	xor	a

TCP_SND_END:	push	af
	xor	a
	ld	(DISABLE_INT),a
	pop	af
	jp	RESTORE_P2

TCP_SEND_HL:	dw	0
TCP_SEND_BC:	dw	0
TCP_SEND_CY:	db	0
TCP_SND_OLDUSED:	dw	0


	;=================
	;===  TCP_RCV  ===
	;=================

;Obtiene datos desde una conexion TCP
;Entrada:  A = Numero de conexion
;          DE = Direccion de destino de los datos
;          BC = Longitud de los datos
;Salida:   Cy=1 si error, y A=Codigo:
;             1: Numero de conexion invalido
;             2: Conexion cerrada
;          BC = Datos extraidos (extrae tantos como puede)
;          Z = 1 si BC=0

_TCP_RCV:	call	SETUP_P2

	;--- Comprueba condiciones de error 1 y 2

	ld	h,a
	push	hl
	call	CHK_TCP_EXIST
	pop	hl
	jr	nc,TCP_RCV2
	ld	bc,0
	jr	TCP_RCV_END
TCP_RCV2:

	ld	a,#FF
	ld	(DISABLE_INT),a

	;--- Carga el TCB de la conexion y comprueba otros parametros

	ld	a,h
	push	de,bc
	call	LOAD_TCB

	;--- Extrae los datos y los copia a TPA

	pop	bc,de
	ld	a,b
	or	c
	jr	z,TCP_RCV_OK2
	push	de
	ld	ix,INBUF
	ld	de,IN_BUFFER	;Usa OUT_BUFFER+IN_BUFFER, que es >1024 bytes
	call	RBUF_EXTRACT
	jr	nc,TCP_RCV_OK1

	pop	de	;Error si no hay datos para extraer
	ld	bc,0
	jr	TCP_RCV_OK2

TCP_RCV_OK1:	ld	hl,IN_BUFFER	;Copia los datos a TPA
	pop	de
	push	bc
	call	LDIR_TS

	;--- Programa un ACK si el valor de ventana a anunciar
	;    es distinto del anunciado la ultima vez

	ld	hl,(ACK_RCV_NUM)	;No es necesario si ya hay un ACK programado
	ld	a,h
	or	l
	jr	nz,RCV_NO_ACK

	call	CALC_RCV_WIN
	ld	de,(LAST_WIN_SENT)
	call	COMP
	jr	z,RCV_NO_ACK

	;* Programa un ACK, para lo cual simula la recepcion
	;  de un byte de datos y activa el temporizador

	call	SCHEDULE_ACK

RCV_NO_ACK:	pop	bc

	;--- Actualiza TCB y termina

TCP_RCV_OK2:	push	bc
	call	SAVE_TCB
	pop	bc
	xor	a

TCP_RCV_END:	push	af
	xor	a
	ld	(DISABLE_INT),a
	pop	hl
	res	6,l	;NZ si L es F
	ld	a,b
	or	c
	jr	nz,TCP_RCV_END2
	set	6,l	;Z si L es F
TCP_RCV_END2:	push	hl
	pop	af
	jp	RESTORE_P2


	;====================
	;===  TCP_STATUS  ===
	;====================

;Obtiene el estado de una conexion TCP
;Entrada:  A = Numero de conexion
;Salida:   Cy=1 si error, y A=Codigo:
;             1: Numero de conexion invalido
;          Cy=0 si OK, y:
;          A = Estado de la conexion
;          HL = Bytes entrantes que pueden ser recolectados
;          DE = Espacio disponible para datos salientes
;          BC = Bytes en la cola de retransmision
;          IX = Direccion del TCB de la conexion
;          (Si A=0, B=LAST_CLOSE)

_TCP_STATUS:	call	SETUP_P2

	;--- Comprueba condiciones de error

	ld	b,a
	ld	a,#FF
	ld	(DISABLE_INT),a
	ld	a,b
	call	CHK_TCP_EXIST
	jr	nc,TCP_STATOK
	cp	2	;El error 2 no es error en este caso
	jp	c,TCP_STAT_END
TCP_STATOK:	;

	;--- Carga el TCB de la conexion, y obtiene parametros

	ld	a,b
	call	LOAD_TCB
	ld	a,(LAST_CLOSE)
	ld	b,a
	ld	a,(TCP_STATE)
	or	a
	jp	z,TCP_STAT_END	;Si esta cerrada, no hay parametros que obtener

	ld	a,(CURTCB_NUM)
	call	GET_TCB_DIR
	push	hl
	pop	ix

	ld	hl,(INBUF_USED)
	ld	de,(OUTBUF_FREE)
	ld	bc,(RETX_SIZE)
	ld	a,(TCP_STATE)

	or	a

TCP_STAT_END:	push	af
	xor	a
	ld	(DISABLE_INT),a
	pop	af
	jp	RESTORE_P2


	;===================
	;===  TCP_FLUSH  ===
	;===================

;Limpia los datos de salida aun no enviados de una conexion TCP
;Entrada:  A = Numero de conexion
;Salida:   Cy=1 si error, y A=Codigo:
;             1: Numero de conexion invalido
;             2: Conexion cerrada
;          Cy=0 y A=0 si OK

_TCP_FLUSH:	call	SETUP_P2

	;--- Comprueba condiciones de error 1 y 2

	ld	b,a
	call	CHK_TCP_EXIST
	jp	c,RESTORE_P2

	ld	a,#FF
	ld	(DISABLE_INT),a

	;--- Carga el TCB de la conexion

	ld	a,b
	call	LOAD_TCB

	;--- Si no hay datos de salida,
	;    o si solo hay datos de retransmision, termina ya

	ld	hl,(OUTBUF_USED)
	ld	a,h
	or	l
	jp	z,TCP_FLUSH_END

	ld	de,(RETX_SIZE)
	call	COMP
	jp	z,TCP_FLUSH_END

	;--- Si hay datos de retransmision,
	;    los guarda para no perderlos al inicializar el bufer

	ld	bc,(RETX_SIZE)
	ld	a,b
	or	c
	jr	z,TCP_FLUSH1

	ld	ix,OUTBUF
	ld	de,IN_BUFFER
	call	RBUF_PEEK
TCP_FLUSH1:	;

	;--- Inicializa el bufer de salida, lo cual borra todo su contenido

	ld	ix,OUTBUF
	ld	hl,(OUTBUF_BUFADD)
	ld	bc,1024
	call	RBUF_INIT

	;--- Si habia datos de retransmision, los vuelve a 
	;    insertar en el bufer

	ld	bc,(RETX_SIZE)
	ld	a,b
	or	c
	jr	z,TCP_FLUSH2

	ld	ix,OUTBUF
	ld	hl,OUT_BUFFER
	call	RBUF_INSERT
TCP_FLUSH2:	;

	;--- Si habia datos PUSH, actualiza SEND_PUSH_PEND

	ld	hl,(SEND_PUSH_PEND)
	ld	a,h
	or	l
	jr	z,TCP_FLUSH3

	ld	hl,(OUTBUF_USED)
	ld	(SEND_PUSH_PEND),hl
TCP_FLUSH3:	;        

	;--- Fin

	call	SAVE_TCB
TCP_FLUSH_END:	xor	a
	ld	(DISABLE_INT),a
	jp	RESTORE_P2


	;==================
	;===  RAW_SEND  ===
	;==================

;Envia un datagrama en bruto
;Entrada:  Cy=0: El datagrama no incluye cabecera IP
;          Cy=1: El datagrama ya incluye la cabecera IP
;          IX=Dir del paquete en TPA
;          BC=Longitud del paquete (hasta 576 si Cy=0, hasta 556 si Cy=1)
;          L.H.E.D=IP de destino (si Cy=0)
;          A=Protocolo de transporte (si Cy=0)
;          IYh=TOS (si Cy=0)
;          IYl=TTL (si Cy=0)
;Salida:   Cy=1 y A=Error:
;            1: No hay conexion a red
;            2: Tamaqo incorrecto pasado en BC

_RAW_SEND:	ld	(RAW_A),a
	ld	a,0
	rla
	ld	(RAW_CY),a

	;--- Comprueba tamanyo de bloque

	push	de,hl
	push	bc
	pop	hl
	ld	a,(RAW_CY)
	or	a
	ld	de,557
	jr	z,RAW_SEND2
	ld	de,577
RAW_SEND2	call	COMP
	jr	nc,RAW_SEND3

	pop	hl,de
	ld	a,2
	scf
	ret
RAW_SEND3:

	;--- Si el tamanyo es 0 y Cy=1, termina

	ld	a,b
	or	c
	jr	nz,RAW_SEND4

	ld	a,(RAW_CY)
	or	a
	jr	z,RAW_SEND4

	pop	hl,de
	xor	a
	ret
RAW_SEND4:	;

	;--- Establece pagina 2

	call	SETUP_P2
	ld	a,#FF
	ld	(DISABLE_INT),a

	;--- Comprueba la conexion a red

	ld	a,(NET_STATE)
	or	a
	jr	nz,RAW_SEND1

	ld	a,1
	scf
	pop	hl,de
	jr	RAW_SEND_END
RAW_SEND1:	;        

	push	bc,iy,ix
	pop	hl

	;--- Copia los datos desde TPA

	ld	a,(RAW_CY)
	or	a
	ld	de,OUT_BUFFER+24
	jr	z,RAW_SEND5
	ld	de,OUT_BUFFER+4
RAW_SEND5:	ld	a,b
	or	c
	call	nz,LDIR_ST
	pop	iy,bc,hl,de

	ld	a,#FF	;Para que no se envie comprimido VJ
	ld	(IS_RAW_DGRAM),a

	;--- Decide accion segun Cy

	ld	a,(RAW_CY)
	or	a
	jr	nz,RAW_SEND_CY

	;--- Envio sin cabecera

	push	hl	;Guarda TTL y TOS actuales
	ld	hl,(TTL)	;(estan consecutivos en memoria)
	ex	(sp),hl

	ld	a,iyh	;Establece TTL y TOS especificados
	ld	(TOS),a
	ld	a,iyl
	ld	(TTL),a

	ld	a,(RAW_A)
	call	SEND_IP	;HL, DE, BC ya estan establecidos

	pop	hl	;Restaura TTL y TOS anteriores
	ld	(TTL),hl

	jr	RAW_SEND_OK

	;--- Envio con cabecera

RAW_SEND_CY:	call	SEND_IP_ETH0

	;--- Fin

RAW_SEND_OK:	xor	a
RAW_SEND_END:	push	af
	xor	a
	ld	(DISABLE_INT),a
	pop	af
	call	RESTORE_P2
	ret

RAW_A:	db	0
RAW_CY:	db	0
IS_RAW_DGRAM:	db	0


	;=====================
	;===  RAW_CONTROL  ===
	;=====================

;Obtiene/establece el estado de la captura de un datagrama plano
;Entrada:  A=0: Obtener estado
;            1: Requerir captura
;            2: Cancelar captura
;          B=Protocolo de transporte a capturar (si A=1)
;            0: Todos
;            #FF: Todos excepto TCP, UDP e ICMP de eco
;Salida:   Cy=1 y A=Error:
;            1: Se requiere captura pero no hay conexion a red
;            2: Valor de A invalido a la entrada
;          A=Estado:
;            0: No se ha requerido captura, o no hay conexion red
;            1: Se ha requerido captura pero no hay datagrama pendiente
;            2: Hay un paquete pendiente
;          BC=Tamaqo del datagrama pendiente (si A=2)
;          D=Protocolo requerido (si A<>0)

_RAW_CONTROL:	cp	3
	ccf
	ld	c,a
	ld	a,2	;Error 2?
	ret	c
	ld	a,c

	push	af
	call	SETUP_P2
	ld	a,#FF
	ld	(DISABLE_INT),a
	pop	af

	;--- Si A=1, y no hay conexion a red, error

	cp	1
	jr	nz,RAW_CONTROL2

	ld	a,(NET_STATE)
	or	a
	ld	a,1
	scf
	jr	z,RAW_CTRL_END
RAW_CONTROL2:

	;--- Solo requerir estado: terminar

	or	a
	jr	z,RAW_CTRL_STAT

	;--- Requerir captura

	cp	1
	jr	nz,RAW_CTRL_CANCEL

	ld	(PCAP_STATE),a
	ld	a,b
	ld	(PCAP_PROTO),a

	ld	a,(UDPI_GINDEX)	;Si hay 8 paquetes UDP pendientes,
	cp	7	;descarta el octavo
	jr	nz,RAW_CONTROL3
	xor	a
	ld	(UDPI_GINDEX),a
RAW_CONTROL3:

	ld	a,(UDPI_PINDEX)
	cp	7
	jr	nz,RAW_CONTROL4
	xor	a
	ld	(UDPI_PINDEX),a
RAW_CONTROL4:

	jr	RAW_CTRL_STAT

	;--- Cancelar captura

RAW_CTRL_CANCEL:	xor	a
	ld	(PCAP_STATE),a

	;--- Estado

RAW_CTRL_STAT:	ld	de,(PCAP_PROTO-1)
	ld	bc,(PCAP_SIZE)
	ld	a,(PCAP_STATE)
	or	a

	;--- Fin

RAW_CTRL_END:	push	af
	xor	a
	ld	(DISABLE_INT),a
	pop	af
	jp	RESTORE_P2


	;=================
	;===  RAW_RCV  ===
	;=================

;Obtencion de un datagrama plano capturado
;Entrada:  HL=Direccion TPA donde depositar el datagrama
;Salida:   Cy=1 y A=Error:
;            1: No hay ningun datagrama capturado
;          A=Longitud de la cabecera IP
;          BC=Longitud total del datagrama
;          DE=Longitud de la parte de datos del datagrama
;          HL=Puntero a los datos en TPA

_RAW_RCV:	call	SETUP_P2
	ld	a,#FF
	ld	(DISABLE_INT),a

	;--- Error si no hay datagrama pendiente

	ld	a,(PCAP_STATE)
	cp	2
	ld	a,1
	scf
	jr	nz,RAW_RCV_END

	;--- Copia el datagrama a TPA

	push	hl
	ex	de,hl
	ld	hl,PCAP_BUFFER
	ld	bc,(PCAP_SIZE)
	ld	a,b
	or	c
	call	nz,LDIR_TS

	;--- Establece los parametros de salida

	xor	a
	ld	(PCAP_STATE),a

	ld	a,(PCAP_BUFFER)
	and	#0F
	sla	a
	sla	a
	ld	c,a
	ld	b,0	;BC=Longitud cabecera

	ld	hl,(PCAP_SIZE)
	or	a
	sbc	hl,bc
	ex	de,hl	;DE=Longitud datos

	pop	hl
	add	hl,bc	;HL=Puntero a los datos en TPA

	ld	a,c	;A=Longitud cabecera
	ld	bc,(PCAP_SIZE)	;BC=Longitud total

	or	a

	;--- Fin

RAW_RCV_END:	push	af
	xor	a
	ld	(DISABLE_INT),a
	pop	af
	jp	RESTORE_P2


	;==================
	;===  WAIT_INT  ===
	;==================

;Espera hasta que haya ocurrido al menos una interrupcion
;desde la ultima vez que se llamo a la rutina.
;Devuelve Cy=1 si ha sido necesario esperar, Cy=0 si no.

_WAIT_INT:	ld	hl,(SYSTIMER)
	ld	de,(LAST_SYSTIM)
	call	COMP
	ld	(LAST_SYSTIM),hl
	scf
	ccf
	ret	nz

WAIT_INT2:	ld	hl,(SYSTIMER)
	call	COMP
	jr	z,WAIT_INT2
	ld	(LAST_SYSTIM),hl
	scf
	ret

LAST_SYSTIM:	dw	0


	;=======================
	;===  NETWORK_STATE  ===
	;=======================

;Devuelve en A el estado de la red:
;0: Cerrada
;1: Inicializando
;2: Abierta
;3: Cerrando

_NETWORK_STATE:	call	SETUP_P2

	ld	a,(CHECK_NET)
	or	a
	jr	nz,NETWORK_STAT2

	obsonet	GET_NETSTAT
	or	a
	jp	z,RESTORE_P2
	ld	a,2
	jp	RESTORE_P2

NETWORK_STAT2:	ld	a,(NET_STATE)
	or	a
	jp	z,RESTORE_P2

	ld	a,2
	jp	RESTORE_P2


	;===================
	;===  ONET_INFO  ===
	;===================

;Devuelve en A el slot de ObsoNET
;y la dir HW en L-H-E-D-C-B.

_ONET_INFO:	call	SETUP_P2
	obsonet	GET_HWAD
	ld	a,(OBSLOT)
	jp	RESTORE_P2


	;===================
	;===  ETH2ASCII  ===
	;===================

;Convierte una dir Ethernet a su equivalente ASCII.
;Entrada: L-H-E-D-C-B = Direccion Ethernet
;         IX = Direccisn TPA de destino
;         A = Banderas:
;             Bit 0: 0 para usar mayusculas hex, 1 para minusculas
;             Bit 1: 0 para usar "-" separador, 1 para usar ":"
;Salida:  -

_ETH2ASCII:	ld	(ETH2ASCBUF),hl
	ld	(ETH2ASCBUF+2),de
	ld	(ETH2ASCBUF+4),bc

	push	ix,af
	call	SETUP_P2
	ld	a,#FF
	ld	(DISABLE_INT),a
	pop	af

	rrca
	rrca
	rrca		;Ahora: bit 5 may/min, bit 6=separador
	ld	d,a
	and	#20
	ld	c,a	;C=#20 para min, 0 para may
	ld	a,d
	and	#40
	ld	d,a	;D=#40 para ":", 0 para "-"

	ld	hl,OUT_BUFFER
	ld	ix,ETH2ASCBUF
	ld	b,6

	;--- Genera la cadena

E2ALOOP:	ld	a,(ix)
	inc	ix
	ld	e,a
	rrca
	rrca
	rrca
	rrca
	call	NIBLE2ASC
	ld	(hl),a
	inc	hl

	ld	a,e
	call	NIBLE2ASC
	ld	(hl),a
	inc	hl

	ld	a,b
	cp	1
	jr	z,E2ALOOP3

	ld	a,d
	or	a
	ld	a,"-"
	jr	z,E2ALOOP2
	ld	a,":"
E2ALOOP2:	ld	(hl),a
	inc	hl

	djnz	E2ALOOP
E2ALOOP3:

	;--- Copia la cadena a TPA

	ld	hl,OUT_BUFFER
	pop	de
	ld	bc,17
	call	LDIR_TS

	xor	a
	ld	(DISABLE_INT),a
	call	RESTORE_P2
	ret

;--- Subrutina que convierte A (nibble bajo) en un caracter

NIBLE2ASC:	and	%1111
	cp	10
	jr	nc,NIB2ASC2

	add	"0"
	ret

NIB2ASC2:	add	"A"-10
	or	c
	ret

ETH2ASCBUF:	ds	6


	;===================
	;===  ASCII2ETH  ===
	;===================

;Convierte una dir Ethernet en ASCII a su equivalente en bytes.
;Entrada: HL = Direccion de la cadena en TPA
;Salida:  L-H-E-D-C-B = Direccion Ethernet resultante
;         Cy = 1 si la cadena es erronea

_ASCII2ETH:	call	SETUP_P2
	ld	a,#FF
	ld	(DISABLE_INT),a

	ld	de,OUT_BUFFER
	ld	bc,17
	call	LDIR_ST

	;--- Interpreta la cadena

	ld	ix,OUT_BUFFER
	ld	hl,ETH2ASCBUF
	ld	b,6

A2ELOOP:	ld	a,(ix)
	call	ASC2NIBLE
	jr	c,A2EEND
	sla	a
	sla	a
	sla	a
	sla	a
	ld	d,a
	inc	ix

	ld	a,(ix)
	call	ASC2NIBLE
	jr	c,A2EEND
	or	d
	ld	(hl),a
	inc	hl
	inc	ix

	ld	a,b
	cp	1
	jr	z,A2ELOOP2

	ld	a,(ix)
	cp	":"
	jr	z,A2ELOOP3
	cp	"-"
	scf
	jr	nz,A2EEND
A2ELOOP3:	inc	ix

	djnz	A2ELOOP
A2ELOOP2:

	or	a

	;--- Fin, devuelve resultados

A2EEND:	push	af
	xor	a
	ld	(DISABLE_INT),a
	call	RESTORE_P2
	pop	af
	ret	c

	ld	hl,(ETH2ASCBUF)
	ld	de,(ETH2ASCBUF+2)
	ld	bc,(ETH2ASCBUF+4)
	ret


;--- Subrutina que interpreta el caracter pasado en A
;    Devuelve A=Digito, Cy=1 si incorrecto

ASC2NIBLE:	cp	"0"
	ret	c
	cp	"9"+1
	jr	nc,ASC2NIBLE2

	;* Es 0-9

	sub	"0"
	or	a
	ret
ASC2NIBLE2:

	;* Puede ser A-F

	or	32	;Convierte a minuscula
	cp	"a"
	ret	c
	cp	"f"+1
	ccf
	ret	c

	sub	"a"-10
	or	a
	ret


	;===================
	;===  MASK2BITS  ===
	;===================

;Convierte una mascara de red a numero de bits.
;(Se para al encontrar un 0)
;Entrada: L.H.E.D = Mascara
;Salida:  A = Bits

_MASK2BITS:	ld	c,0
	call	COUNT_ONES
	ld	a,c
	cp	16
	ret	c

	ex	de,hl
	call	COUNT_ONES
	ld	a,c
	ret

	;--- Cuenta los unos de LH y los suma a C

COUNT_ONES:	ld	b,16
COUNTONES_L:	sla	h
	rl	l
	ret	nc
	inc	c
	djnz	COUNTONES_L
	ret


	;===================
	;===  BITS2MASK  ===
	;===================

;Convierte un numero de bits a mascara de red.
;Entrada: A = Bits
;Salida:  L.H.E.D = Mascara

_BITS2MASK:	ld	hl,0
	ld	de,0

	or	a
	ret	z

	ld	b,a
B2M_LOOP:	scf
	rr	l
	rr	h
	rr	e
	rr	d
	djnz	B2M_LOOP

	ret


	;===================
	;===  ARP_ROUTE  ===
	;===================

;Devuelve direccion y numero de entradas ARP y de enrutamiento
;Entrada: -
;Salida:  IX=Dir tabla ARP
;         IY=Dir tabla enrutamiento
;         B=Numero de entradas en la tabla ARP
;         C=Numero de entradas en la tabla de enrutamiento

_ARP_ROUTE:	ld	ix,ARP_CACHE
	ld	iy,ROUTE_TABLE
	ld	bc,ROUTE_ENTRIES+256*ARP_ENTRIES
	ret


	;================================
	;===  Paquetes prefabricados  ===
	;================================

	;*** Residen en el segmento de codigo y no en el de datos.

	;--- Paquete UNARP (16 bytes)

UNARP_PACKET:	db	0,1,8,0,0,4,0,2
UNARP_IP:	ds	4
	db	255,255,255,255

CODE_END:


;*****************************
;***                       ***
;***  VARIABLES Y BUFERES  ***
;***                       ***
;*****************************

;Aunque se definen aqui para poder ensamblar el programa,
;las variables residen en el segmento de la pagina 2.

	org	#8000

	;========================================================
	;===  Variables y buferes de interes para el usuario  ===
	;========================================================

BUF_IPLOCAL:	ds	4	;IP local (4 bytes)
BUF_IPDNS1:	ds	4	;IP DNS 1 (4 bytes)
BUF_IPDNS2:	ds	4	;IP DNS 2 (4 bytes)
REPLYECHO:	ds	1	;Responder PINGs si/no
TTL:	ds	1	;TTL para datagramas salientes
TOS:	ds	1	;TOS para datagramas salientes
CHKVECT:	ds	1	;Vector de optimizaciones checksum
			;       (&B 0 0 0 ICMP UDP TCP IP PPP)
PING_SIZE:	ds	2	;Tamanyo de la parte de datos
			;de un ICMP echo request (0-512)

;* Variables especificas de ObsoNET/Ethernet

OBSLOT:	ds	1	;Slot de ObsoNET
HWAD:	ds	6	;Direccion de hardware
SUBNET_MASK:	ds	4	;Mascara de subred
DEFGW:	ds	4	;Gateway por defecto
ARP_TOUT:	ds	4	;Timeout de la cache ARP, en 1/60 segundos
ARP_TOUT_SECS:	ds	4	;Idem, en segundos
FRAME_TYPE:	ds	1	;Tipo de la trama a enviar, 0=Eth. 2, 1=IEEE 802.3
CHECK_NET:	ds	1	;#FF para comprobar la red periodicamente
DHCP_VECT:	ds	2	;Vector de parametros a obtener con DHCP:
	;bit 0: Dir IP
	;bit 1: Mascara de red
	;bit 2: Gateway por defecto
	;bit 3: Direcciones DNS
	;bit 4: Timeout cache ARP
	;bit 5: Tipo de trama Ethernet
DHCP_VECT_O:	ds	2	;Parametros realmente obtenidos con DHCP
DHCP_STATE:	ds	1	;Estado DHCP:
	;0: INIT
	;1: SELECTING
	;2: REQUESTING
	;3: BOUND
	;4: RENEWING
	;5: REBINDING
	;6: INFORMING
	;7: CONFIGURED
	;253: Error: No hay servidores
	;254: Error: El servidor no responde

NET_STATE:	ds	1	;Estado de la red, #FF=funcionando
NETSTAT_TIMER:	ds	2	;Temporizador para comprobar el estado de la red


	;================================
	;===  Informacion sobre DHCP  ===
	;================================

DHCP_VAR_START:

DHCP_XID:	ds	4	;Proximo XID a usar
DHCP_SNDTIM:	ds	1	;Temporizador para el proximo envio
DHCP_TRIES:	ds	1	;Paquetes DHCP enviados
DHCP_RCVXID:	ds	4	;XID del ultimo paquete recibido
DHCP_SERVER:	ds	4	;IP del servidor
DHCP_T1:	ds	4	;Temporizador T1
DHCP_T2:	ds	4	;Temporizador T2
DHCP_LEASE:	ds	4	;Lease de la direccion IP
DHCP_SECS:	ds	2	;Segundos desde que se inicio el proceso
DHCP_SECS_T:	ds	1	;Temporizador de 1/60 segs para incrementar SECS
DHCP_YIADDR:	ds	4	;IP ofrecida

DHCP_VAR_END:

	;======================================
	;===  Informacion sobre ICMP y UDP  ===
	;======================================

PACKINFO_START:

	;--- Buferes para informacion sobre paquetes ICMP "echo reply" recibidos (hasta 4)

ICMPI_GINDEX:	ds	1	;Indice de salida (0 a 7)
ICMPI_PINDEX:	ds	1	;Indice de entrada (0 a 7)

ICMPI_IP0:	ds	4	;IP de origen (0.0.0.0 si bufer vacio)
ICMPI_TTL0:	ds	1	;TTL del paquete recibido
ICMPI_ID0:	ds	2	;Identificador
ICMPI_SEQ0:	ds	2	;Numero de secuencia
ICMPI_LEN0:	ds	2	;Longitud de los datos

		ds	11*7	;Otros siete buferes iguales

	;--- Buferes para informacion sobre paquetes UDP recibidos (hasta 8)
	;    Mas adelante estan los buferes para los paquetes

UDPI_GINDEX:	ds	1	;Indice de salida (0 a 7)
UDPI_PINDEX:	ds	1	;Indice de entrada (0 a 7)

UDPI_IP0:	ds	4	;IP de origen (0.0.0.0 si bufer vacio)
UDPI_SPORT0:	ds	2	;Puerto de origen
UDPI_DPORT0:	ds	2	;Puerto de destino
UDPI_LEN0:	ds	2	;Longitud de los datos

		ds	10*7	;Otros siete buferes iguales

PACKINFO_END:	;


	;===========================================================
	;===  Variables para guardar el estado de la paginacion  ===
	;===========================================================

I_SEGP2:	ds	1	;Segmento en pag 2 para la interrupcion
I_SLOT2:	ds	1	;Slot en pag 2 para la interrupcion
R_SEGP2:	ds	1	;Segmento en pag 2 para las rutinas

DISABLE_INT:	ds	1	;#FF si la rutina TIME_INT no puede ejecutarse


	;====================================================
	;===  Identificadores para los paquetes enviados  ===
	;====================================================

ID_IP:	ds	2	;Datagramas IP
ID_DNS:	ds	2	;Paquetes para DNS


	;====================================
	;===  Variables para el resolver  ===
	;====================================

DNS_STAT_P:	ds	1	;Estado actual, primario
DNS_STAT_S:	ds	1	;Estado actual, secundario
DNS_TOUT:	ds	1	;Contador de timeout para el DNS en curso
DNS_TTOUT:	ds	2	;Contador de timeout total
DNS_RETRY:	ds	1	;Contador de ReTx para el DNS en curso
DNS_RESULT:	ds	4	;Resultado devuelto por el DNS
DNS_IP:	ds	4	;IP del servidor usado actualmente
ANCOUNT:	ds	2
ARCOUNT:	ds	2
NSCOUNT:	ds	2
DNS_BUFFER:	ds	256	;Para almacenar el nombre a resolver


	;============================
	;===  Variables para TCP  ===
	;============================

CURTCB_NUM:	ds	1	;TCB cargado en TCB_TEMP
TEMP32_1:	ds	4	;Para operaciones con numeros de 32 bits
LAST_PROC_TCB:	ds	1	;TCB procesado en la ultima int del reloj
RECEIVED_MSS:	ds	2	;Opcion TCP MSS recibida en el segmento actual, o 512


	;===============================================
	;===  Variables para la captura de paquetes  ===
	;===============================================

PCAP_STATE:	ds	1	;0=no capturar, 1=capturar, 2=capturado
PCAP_PROTO:	ds	1	;Proto a capturar, o 0 o #FF
PCAP_SIZE:	ds	2	;Tamanyo del paquete capturado

INBUF_SIZE:	ds	2	;Tamanyo total de la ultima trama recibida
WOUT_SIZE:	ds	2	;Tamanyo del paquete en WOUT_BUFFER

VARS_END:	;


	;==================================================
	;===  Buferes para datos entrantes y salientes  ===
	;==================================================

	;>>> El formato de los paquetes aqui guardados siempre es:

	;#FF #03 Proto_H Proto_L (Informacion) FCS_L FCS_H

	;>>> El orden de los buferes en memoria es:
	;TCB_TEMP
	;TCBS
	;IN_BUFFER
	;OUT_BUFFER
	;UDP_BUFFERS
	;TCP_BUFFERS

	;Se declaran en orden inverso porque si no,
	;al ensamblar da error

	;--- Buferes para datos TCP recibidos y a enviar
	;    (1024 bytes entrantes + 1024 salientes)*4 conexiones

TCP_BUFFERS:	equ	#A000

	;--- Cache ARP y tabla de enrutamiento (32 y 16 entradas, resp.)

ARP_CACHE:	equ	TCP_BUFFERS-16*ARP_ENTRIES
ROUTE_TABLE:	equ	ARP_CACHE-16*ROUTE_ENTRIES

	;--- Buferes para paquetes UDP recibidos:
	;    512 bytes * 8 paquetes,
	;    +64 bytes para guardar un paquete
	;    capturado de 576 bytes

UDP_BUFFERS:	equ	ROUTE_TABLE-(548*8)-64
PCAP_BUFFER:	equ	UDP_BUFFERS+7*548	;Para el paquete capturado

	;--- Bufer para el paquete saliente
	;    Longitud: 576 + 32 para cabecera IEEE802.2 = 608
	;    Los datos empiezan en OUT_BUFFER+4 por compatibilidad
	;    con el codigo de INL para PPP

OUT_BUFFER:	equ	UDP_BUFFERS-580
OUT_BUFSTART:	equ	OUT_BUFFER-28

	;--- Bufer para el paquete entrante

IN_BUFFER:	equ	OUT_BUFSTART-580
IN_BUFSTART:	equ	IN_BUFFER-28

	;--- Bufer para un datagrama pendiente de salida,
	;    a la espera de la resolucion ARP

WOUT_IP:	equ	IN_BUFSTART-4	;PCAP_BUFFER-4

WOUT_BUFFER:	equ	WOUT_IP-576

	;--- Buferes para los TCBs de TCP

TCBS:	equ	WOUT_BUFFER-(96*4)

	;--- Zona para el TCB temporal de una conexion TCP

TCB_TEMP:	equ	TCBS-96

TCP_STATE:	equ	TCB_TEMP	;Estado TCP
REMOTE_IP:	equ	TCP_STATE+1	;IP remota
REMOTE_PORT:	equ	REMOTE_IP+4	;Puerto remoto (Big-Endian)
LOCAL_PORT:	equ	REMOTE_PORT+2	;Puerto remoto (Big-Endian)
PASSIVE_OPEN:	equ	LOCAL_PORT+2	;0/#FF para conexion activa/pasiva

SND_UNA:	equ	PASSIVE_OPEN+1	;Primer numero de secuencia no ACKeado
SND_NXT:	equ	SND_UNA+4	;Proximo numero de secuencia a enviar
SND_WND:	equ	SND_NXT+4	;Ventana de emision anunciada
SND_WL1:	equ	SND_WND+2	;Numero de secuencia usado para la ultima
	;actualizacion de la ventana
SND_WL2:	equ	SND_WL1+4	;Numero de ACK usado para la ultima
	;actualizacion de la ventana
ISS:	equ	SND_WL2+4	;Numero de secuencia de envio inicial

RCV_NXT:	equ	ISS+4	;Proximo numero de secuencia esperado
IRS:	equ	RCV_NXT+4	;Numero de secuencia de recepcion inicial

USER_TOUT_V:	equ	IRS+4	;Valor inicial del timeout de usuario
USER_TOUT:	equ	USER_TOUT_V+2	;Valor actual del timeout de usuario
LAST_CLOSE:	equ	USER_TOUT+2	;Ultimo codigo de error de cierre:
;0: Conexion abierta o nunca usada
;1: CLOSE
;2: ABORT
;3: RST recibido
;4: Timeout de usuario expirado
;5: Timeout de conexion inicial expirado
;6: Conexion a internet perdida
;7: Destino inaccesible (v1.01)

SEND_PUSH_PEND:	equ	LAST_CLOSE+1	;Numero de bytes PUSH a enviar
SEND_TOUT:	equ	SEND_PUSH_PEND+2	;Timeout para enviar los datos
	;cuando no estan PUSHeados
SYN_SENT_FLAG:	equ	SEND_TOUT+2	;#FF si hay SYN enviado sin ACKear
FIN_SENT_FLAG:	equ	SYN_SENT_FLAG+1	;#FF si hay un FIN enviado

RETX_SIZE:	equ	FIN_SENT_FLAG+1	;Tamanyo de la cola de retransmision
RTO_T:	equ	RETX_SIZE+2	;Temporizador de retransmision

ACK_RCV_NUM:	equ	RTO_T+2	;Numero de datos recibidos no ACKeados aun
ACK_DELAY_T:	equ	ACK_RCV_NUM+2	;Temporizador para enviar un ACK (1 byte)

FIN_PENDING:	equ	ACK_DELAY_T+1	;Envio de FIN pendiente pero quedan datos por enviar

LAST_WIN_SENT:	equ	FIN_PENDING+1	;Ultima ventana anunciada

MSS:	equ	LAST_WIN_SENT+2	;Max. tamanyo segmento enviable

ACK_PENDING:	equ	MSS+2	;ACK pendiente que no es por recibir datos nuevos

INBUF:	equ	ACK_PENDING+1
INBUF_USED:	equ	INBUF	;Datos bufer de entrada
INBUF_FREE:	equ	INBUF_USED+2
INBUF_INPNT:	equ	INBUF_FREE+2
INBUF_OUTPNT:	equ	INBUF_INPNT+2
INBUF_BUFADD:	equ	INBUF_OUTPNT+2
INBUF_ENDADD:	equ	INBUF_BUFADD+2

OUTBUF:	equ	INBUF_ENDADD+2
OUTBUF_USED:	equ	OUTBUF	;Datos bufer de salida
OUTBUF_FREE:	equ	OUTBUF_USED+2
OUTBUF_INPNT:	equ	OUTBUF_FREE+2
OUTBUF_OUTPNT:	equ	OUTBUF_INPNT+2
OUTBUF_BUFADD:	equ	OUTBUF_OUTPNT+2
OUTBUF_ENDADD:	equ	OUTBUF_BUFADD+2

TCB_END:	equ	OUTBUF_ENDADD+2
TCB_SIZE:	equ	TCB_END-TCB_TEMP

IP_HEADER_LEN:	equ	OUT_BUFFER
IP_TOTAL_LEN:	equ	OUT_BUFFER+2

