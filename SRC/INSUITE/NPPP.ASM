; PPP module for InterNestor Suite

;=====================

	;--- Modulo PPP para Internestor Suite 0.4
	;    VERSION RESIDENTE
	;    Necesita NestorMan 1.12 y el driver Fossil

	;En 0.2:

	;- Anyadido el CALL DESTR_QUEUES en la rutina de RESET
	;- Anyadida la rutina PPP_MXU
	;- Eliminada la prueba de crear IP_IN_QUEUE
	;- Anyadido el mecanismo de cierre automatico de la conexion
	;  si se envian demasiados ecos sin recibir respuesta

	;En 0.3:

	;- El contador y el temporizador de envio de ecos
	;  se pone a 0 al recibir cualquier paquete

	;En 0.4:
	;- Corregida la parte de PARSE_CONFREQ que propone CHAP
	;- Ahora la recepcion de un "Terminate Request" de IPCP
	;  causa el cierre del enlace si AUTO_CLOSE_TERM=#FF
	;  (antes solo pasaba si el paquete era LCP)
	;- Ahora el automata IPCP no detecta el estado "Up" hasta que
	;  que la autentifcacion ha finalizado

	;Buscar "*** PRUEBAS"

	.label	20

nesman:	macro	@f
	call	#4100+3*@f
	endm

nesmani:	macro	@f
	ld	c,@f
	ld	de,#2202
	call	#FFCA
	endm

	;--- Llamadas al modulo inferior

LOW_INT:	equ	#8009
LOW_QUEUES:	equ	#800C
LOW_CHK_TLU:	equ	#800F
LOW_OPEN:	equ	#8012
LOW_CLOSE:	equ	#8015
LOW_RDY_RCV:	equ	#801B
LOW_BYTE_IN:	equ	#801E

	;--- Llamadas al modulo superior

UP_INT:	equ	#8009
UP_QUEUES:	equ	#800C



;***********************************
;***                             ***
;***   CABECERA IDENTIFICADORA   ***
;***                             ***
;***********************************

	;--- #0000: Texto identificador de 256 caracteres

	org	#100
HEADER:	db	"NestorPPP 0.4 - almost complete but:",13,10
	db	"* Has not support for LQR",13,10
	db	"* Can't negotiate Van Jacobson compression",13,10
	db	"A level 2 module for InterNestor Suite",13,10
	db	"By Konami Man, 7-2002",13,10
	db	#1A
HEAD_END:	;
	ds	256-(HEAD_END-HEADER)

	;--- #0100: Cadena identificadora de 32 caracteres

	db	"NestorPPP 0.3                   "

	;--- #0120: Identificador de modulo de InterNestor Suite

	db	"INESUITE"

	;--- #0128: Version

	db	0,4,0

	;--- #012B: Nivel del modulo

	db	2

	;--- Hasta #200: Reservado para futura expansion

	ds	#200-#012B-1


;**************************
;***                    ***
;***   TABLA DE SALTO   ***
;***                    ***
;**************************

	org	#8003

	;--- Rutinas obligatorias

	jp	PPP_RESET	;#8003: Reset
	jp	PPP_DEINIT	;#8006: Desinicializacion
	jp	PPP_INT	;#8009: Atencion a la interrupcion
	jp	PPP_QUEUES	;#800C: Direcciones de las colas
	jp	PPP_CHK_TLU	;#800F: La capa esta disponible o no
	jp	PPP_OPEN	;#8012: Peticion de apertura de la capa
	jp	PPP_CLOSE	;#8015: Peticion de cierre de la capa
	jp	PPP_IPS	;#8018: Direcciones IP
	jp	PPP_VJ	;#801B: Si se permite compresion VJ
	jp	PPP_MXU	;#801E: Pregunta MTU o MRU

	;--- Rutinas especificas de NestorPPP

	jp	PPP_TABLES	;#8021: Direcciones de las tablas
	jp	NETWORK_STATUS	;#8024: Estado del PPP



;****************************************
;***                                  ***
;***   RUTINAS DE LA TABLA DE SALTO   ***
;***                                  ***
;****************************************

	;--- Reset
	;    Inicializa variables y colas propias
	;    Obtiene el segmento de los modulos inferior y superior

PPP_RESET:	call	INIT_VAR	;Inicializa vars y ctes
	ld	hl,CONS_DEF_VAL
	ld	de,CONS_START
	ld	bc,CONS_END-CONS_START
	ldir
	ld	hl,VAR_ZONE_END
	ld	de,VAR_ZONE_END+1
	ld	bc,VAR_END-VAR_ZONE_END-1
	ld	(hl),0
	ldir
	ld	hl,GHDLC_BUF
	ld	de,GHDLC_BUF+1
	ld	bc,BADHEAD-GHDLC_BUF
	ld	(hl),0
	ldir
	ld	a,1
	ld	(CLOSE_ERROR),a

	ld	de,#0402	;Obtiene rutinas del mapeador
	call	#FFCA
	ld	de,ALL_SEG
	ld	bc,#30
	ldir

	xor	a
	ld	hl,0
	ld	(IP_IN_QUEUE),a	;Desde ahora desconocemos
	ld	(IP_IN_QUEUE+1),hl	;las dirs de las colas externas
	ld	(OUT_QUEUE),a
	ld	(OUT_QUEUE+1),hl

	nesmani	32
	push	de
	ld	a,c
	nesmani	3
	ld	a,c
	ld	(LOWER_SEG),a	;Segmentos modulos inf. y sup.
	pop	de
	ld	a,e
	nesmani	3
	ld	a,c
	ld	(UPPER_SEG),a

	call	DESTR_QUEUES

	ld	ix,LCP_IN_QUEUE	;Inicializa colas
	call	INIT_QUEUE
	jr	c,INIT_Q_ERROR
	ld	ix,IPCP_IN_QUEUE
	call	INIT_QUEUE
	jr	c,INIT_Q_ERROR
	ld	ix,IP_OUT_QUEUE
	call	INIT_QUEUE
	jr	c,INIT_Q_ERROR
	ld	ix,CHAP_IN_QUEUE
	call	INIT_QUEUE
	jr	c,INIT_Q_ERROR

	or	a
	ret

	;Inicializacion de la cola IX, devuelve Cy=1 si error

INIT_QUEUE:	ld	a,(ix)
	ld	l,(ix+1)	;Primero la borra si ya existia
	ld	h,(ix+2)
	ld	(ix),0
	ld	(ix+1),0
	ld	(ix+2),0
	push	ix
	push	hl
	pop	ix
	nesmani	22
	pop	ix

	scf
	push	ix
	nesmani	20
	pop	hl
	ret	c
	ld	(hl),a	;Crea la lista y guarda su direccion
	inc	hl	;si no hay error
	ld	a,ixl
	ld	(hl),a
	inc	hl
	ld	a,ixh
	ld	(hl),a
	or	a
	ret

	;Error: Borra las listas creadas y devuelve Cy=1
	;y HL=Cadena de error

INIT_Q_ERROR:	call	DESTR_QUEUES
	ld	hl,NOMEM_S
	scf
	ret

NOMEM_S:	db	"Could not create queues - out of memory.",13,10,"$"

DESTR_QUEUES:	ld	a,(LCP_IN_QUEUE)
	ld	ix,(LCP_IN_QUEUE+1)
	nesmani	22
	ld	a,(IPCP_IN_QUEUE)
	ld	ix,(IPCP_IN_QUEUE+1)
	nesmani	22
	ld	a,(IP_OUT_QUEUE)
	ld	ix,(IP_OUT_QUEUE+1)
	nesmani	22
	ld	a,(CHAP_IN_QUEUE)
	ld	ix,(CHAP_IN_QUEUE+1)
	nesmani	22
	ld	hl,LCP_IN_QUEUE
	ld	de,LCP_IN_QUEUE+1
	ld	(hl),0
	ld	bc,15-1
	ldir
	ret


	;--- Deinit
	;    Destruye todas las listas

PPP_DEINIT:	call	DESTR_QUEUES
	xor	a
	ld	(LOWER_SEG),a
	ld	(UPPER_SEG),a
	ld	hl,0
	ld	(IP_OUT_QUEUE),a	;Desde ahora desconocemos
	ld	(IP_OUT_QUEUE+1),hl	;las dirs de las colas externas
	ld	(OUT_QUEUE),a
	ld	(OUT_QUEUE+1),hl
	ret


	;--- Queues
	;    Devuelve en A-HL la direccion de la cola segun A:
	;    0: Entrada desde el modulo superior
	;    1: Entrada desde el modulo inferior (no aplicable)
	;    2: Cola del usuario (no aplicable, solo para TCP)
	;    Devuelve Cy=1 si A es incorrecto

PPP_QUEUES:	or	a
	scf
	ret	nz
	ld	a,(IP_OUT_QUEUE)
	ld	hl,(IP_OUT_QUEUE+1)
	or	a
	ret


	;--- Capa disponible
	;    Devuelve Cy=1 si el la capa esta disponible

PPP_CHK_TLU:	ld	a,(THIS_LAYER_ST)
	or	a
	ret	z
	scf
	ret


	;--- Open

PPP_OPEN:	ld	a,#FF
	ld	(OPENED),a
	ret


	;--- Close

PPP_CLOSE:	xor	a
	ld	(OPENED),a
	ld	a,1
	ld	(CLOSE_ERROR),a
	ret


	;--- Direcciones IP
	;    Devuelve en HL-DE la dir IP requerida en A:
	;    0: IP local
	;    1: IP remota
	;    2: DNS primario
	;    3: DNS secundario
	;    Devuelve Cy=1 para A desconocido

PPP_IPS:	or	a
	ld	ix,IP_LOCAL
	jr	z,PPP_IPSOK
	cp	1
	ld	ix,IP_REMOTE
	jr	z,PPP_IPSOK
	cp	2
	ld	ix,DNS_PRIM
	jr	z,PPP_IPSOK
	cp	3
	ld	ix,DNS_SEC
	jr	z,PPP_IPSOK
	scf
	ret

PPP_IPSOK:	ld	h,(ix)
	ld	l,(ix+1)
	ld	d,(ix+2)
	ld	e,(ix+3)
	or	a
	ret

	;--- MXU: Devuelve en HL el MTU, en DE el MRU

PPP_MXU:	ld	hl,(MTU)
	dec	hl
	dec	hl
	dec	hl
	dec	hl
	ld	de,(MRU)
	dec	de
	dec	de
	dec	de
	dec	de
	ret

	;--- Compresion Van Jacobson: devuelve Cy=1 si se permite

PPP_VJ:	or	a	;*** EN PRUEBAS
	ret


	;--- Devuelve en HL la dir de la tabla especificada en A:
	;    (y en BC su longitud)
	;    0: Constantes de configuracion
	;    1: Constantes por defecto
	;    2: Variables de configuracion
	;    3: Buferes de mensajes Terminate/Authentication
	;    4: Buferes para nombre de usuario y password
	;    Devuelve Cy=1 para A desconocido

PPP_TABLES:	or	a
	ld	hl,CONS_START
	ld	bc,CONS_END-CONS_START
	ret	z
	cp	1
	ld	hl,CONS_DEF_VAL
	;ld      bc,CONS_END-CONS_START
	ret	z
	cp	2
	ld	hl,VAR_START
	ld	bc,VAR_END-VAR_START
	ret	z
	cp	3
	ld	hl,LCP_MSG
	ld	bc,256*3
	ret	z
	cp	4
	ld	hl,USER
	ld	bc,256*2
	ret	z
	scf
	ret



;********************************************************
;***                                                  ***
;***  RUTINA DE ATENCION A LA INTERRUPCION DEL RELOJ  ***
;***                                                  ***
;********************************************************

;- Si la autentificacion ha fallado en el anterior paso, simula un Close
;- Llama al automata negociador LCP_AUTOM
;- Si el medio fisico no esta disponible, elimina todos los paquetes de
;  la cola de salida OUT_QUEUE y termina
;- Si no estamos en estado 9, elimina todos los paquetes de las colas
;  IPCP, IP y CHAP
;- Actualiza el Restart Timer si el estado del automata LCP es 4 a 8
;  Si llega a 0, decrementa el contador si no es 0
;- Recibe un paquete:
;  Protocolo desconocido: En estado 9, enviar Protocol Reject
;                         En otros estados, ignorarlo
;  Es LCP:  Meterlo en la cola LCP
;           (si es Discard Request, se ignora)
;  Es IPCP: Meterlo en la cola IPCP si en estado 9 y AUTH_STATUS es 0 o 2,
;           en otro caso, ignorarlo
;  Es IP:   Meterlo en la cola IP si en estado 9 y AUTH_STATUS es 0 o 2
;           y ya se ha negociado direccion IP local,
;           en otro caso, ignorarlo
;  Es PAP:  Si AUTH_POLICY es 0 o #C2, enviar Protocol Reject
;           Si es ACK o NACK, poner AUTH_STATUS a 2 o a 3 (en estado 9)
;           si es Request, enviar ACK directamente
;  Es CHAP: Si AUTH_POLICY es 0 o #C0, enviar Protocol Reject
;           En estado 9, meterlo en la cola CHAP; en otro caso, ignorarlo
;- Llama al automata negociador de IPCP
;- Llama al automata de CHAP si este es el protocolo de autentificacion
;  y estamos en estado 9
;- Si AUTH_STATUS es 1 y el protocolo es PAP, envia nombre+password
;- Llama a la rutina FRAME_OUT que envia un paquete de la cola OUT al m. fisico

PPP_INT:	ld	a,(INT_PERIOD)
	or	a
	jr	z,PPP_INT2
	dec	a
	ld	(INT_PERIOD),a
	jr	PPP_INT_END

PPP_INT2:	ld	a,(INT_PERIOD_V)
	dec	a
	ld	(INT_PERIOD),a

	call	_PPP_INT
	ld	a,(OPENED)
	ld	(LAST_OPCLOSE),a
	ld	a,(CLOSE_PENDING)
	or	a
	jr	z,PPP_INT_END
	ld	a,(CLOSE_ERROR)
	cp	3
	jr	nz,PPP_INT3	;Si la cause dal cierre es "loopback",
	call	FLUSH_ALL	;hay que descartar cualquier
	;                        ;paquete de entrada pendiente
PPP_INT3:	xor	a
	ld	(OPENED),a
	ld	(CLOSE_PENDING),a

	;                        ;Llama a la de la interrupcion
PPP_INT_END:	ld	a,(UPPER_SEG)	;propia, y despues a la del
	or	a	;modulo de nivel superior
	ret	z
	ld	iyh,a
	ld	ix,UP_INT
	call	CAL_SEG
	ret
CLOSE_PENDING:	db	0

_PPP_INT:	;

	;--- Si no conocemos las colas de las capas
	;    superior e inferior, los preguntamos

	ld	a,(OUT_QUEUE)	;Capa inferior
	or	a
	jr	nz,INT_Q_OK1
	xor	a
	ld	ix,LOW_QUEUES
	call	CALL_LOWER
	ld	(OUT_QUEUE),a
	ld	(OUT_QUEUE+1),hl
INT_Q_OK1:	;

	ld	a,(IP_IN_QUEUE)
	or	a
	jr	nz,INT_Q_OK2
	xor	a
	ld	ix,UP_QUEUES
	call	CALL_UPPER
	ld	(IP_IN_QUEUE),a
	ld	(IP_IN_QUEUE+1),hl
INT_Q_OK2:	;

	;--- Si NETWORK_STATUS devuelve 3 pero antes no era 3,
	;    detener el contador total y poner a cero FAIL_CNT

	call	NETWORK_STATUS
	cp	3
	jr	nz,INT_OKIPS
	ld	a,(LAST_NETSTAT)
	cp	3
	jr	z,INT_OKCT

	xor	a
	ld	(TOTAL_TIMER_ON),a
	ld	(FAIL_CNT),a
	jr	INT_OKCT
INT_OKIPS:	;

	;--- Si NETWORK_STATUS no devuelve 3 pero antes era 3,
	;    inicializar y activar contador total

	call	NETWORK_STATUS
	cp	3
	jr	z,INT_OKCT
	ld	a,(LAST_NETSTAT)
	cp	3
	jr	nz,INT_OKCT

	ld	a,-1
	ld	(TOTAL_TIMER_ON),a
	ld	hl,0
	ld	(TOTAL_TIMER),hl
INT_OKCT:	;

	;--- Borra las listas IP, IPCP y CHAP
	;    si LCP no esta en estado 9 pero antes si estaba

	call	NETWORK_STATUS
	or	a
	jr	nz,INT_OKST9
	ld	a,(LAST_NETSTAT)
	or	a
	jr	z,INT_OKST9

	ld	hl,CONS_DEF_VAL
	ld	de,CONS_START
	ld	bc,CONS_END-CONS_START
	ldir
	;ld      hl,VAR_ZONE_END
	;ld      de,VAR_ZONE_END+1
	;ld      bc,VAR_END-VAR_ZONE_END-1
	;ld      (hl),0
	;ldir

	;ld      a,(LCP_AUTOM_STATE)
	;cp      9
	;jr      z,INT_OKST9

	ld	ix,IPCP_IN_QUEUE
	call	FLUSH_QUEUE
	ld	ix,IP_OUT_QUEUE
	call	FLUSH_QUEUE
	ld	ix,IP_IN_QUEUE
	call	FLUSH_QUEUE
	ld	ix,CHAP_IN_QUEUE
	call	FLUSH_QUEUE
INT_OKST9:	;

	;--- Actualiza LAST_NETSTAT con el valor actual

	call	NETWORK_STATUS
	ld	(LAST_NETSTAT),a

	;--- Actualiza contador total

	ld	a,(TOTAL_TIMER_ON)
	or	a
	jr	z,INT_OKTOTTIM

	ld	hl,(TOTAL_TIMER)
	ld	de,(TOTAL_TIMER_V)
	call	COMP
	jr	nz,INT_OKINCTOT
	ld	a,#FF
	ld	(CLOSE_PENDING),a
	ld	a,4
	ld	(CLOSE_ERROR),a
	xor	a
	ld	(TOTAL_TIMER_ON),a
	jr	INT_OKTOTTIM
INT_OKINCTOT:	inc	hl
	ld	(TOTAL_TIMER),hl
INT_OKTOTTIM:	;

	;--- Actualiza contador Echo si LCP en estado 9.
	;    Si llega a 0, envia Echo Request.
	;    Si ya se han enviado ECHO_CLOSE_V sin respuesta,
	;    se cierra la conexion.

	ld	de,(ECHO_CNT_V)	;No hace nada si ECHO_CNT_V
	ld	a,d	;es 0
	or	e
	jr	z,INT_OKECHO

	call	NETWORK_STATUS	;No hace nada si LCP
	cp	3	;no esta en estado 9
	jr	nz,INT_OKECHO

	ld	hl,(ECHO_CNT)	;No hace nada si el contador
	ld	a,h	;no ha llegado a 0
	or	l
	dec	hl
	ld	(ECHO_CNT),hl
	jr	nz,INT_OKECHO

	ld	hl,ECHO_CLOSE	;Comprueba si se han enviado ya
	ld	a,(ECHO_CLOSE_V)	;ECHO_CLOSE_V paquetes
	cp	(hl)
	jr	nz,INT_OKECHO0

	ld	a,#FF	;En ese caso cierra la conexion
	ld	(CLOSE_PENDING),a	;con error 6
	ld	a,6
	ld	(CLOSE_ERROR),a
	jr	INT_OKECHO

INT_OKECHO0:	inc	(hl)	;Inc. contador de ecos enviados
	ld	(ECHO_CNT),de	;Establece contador
	ld	hl,LCP_ID_ER	;Establece ID del paquete
	inc	(hl)
	ld	a,(hl)
	ld	(ECHO_PAQ+1),a
	ld	hl,MAGIC_LOCAL	;Ponemos nuestro magic
	ld	de,ECHO_PAQ+4
	ld	bc,4
	ldir
	ld	hl,ECHO_PAQ	;Enviamos paquete
	ld	bc,0
	call	PUT_XCP
	jr	INT_OKECHO

	db	0,0	;Paquete Echo Request
ECHO_PAQ:	db	9,1,0,18
	ds	4
	db	"Keep-alive"
	db	0,0

INT_OKECHO:	;

	;--- Si ha fallado la autentificacion, se hace un CLOSE
	;    si AUTO_CLOSE_AUTH es #FF

	ld	a,(AUTO_CLOSE_AUTH)
	or	a
	jr	z,INT_OKAUTH

	ld	a,(AUTH_STATUS)
	cp	3
	jr	nz,INT_OKAUTH
	ld	a,#FF
	ld	(CLOSE_PENDING),a
	ld	a,2
	ld	(CLOSE_ERROR),a
INT_OKAUTH:	;

	;--- Actualiza Restart Timer

	ld	a,(LCP_AUTOM_STATE)	;Estado 4 a 8 de LCP?
	cp	9
	jr	nc,INT_OKTIMER1
	cp	4
	jr	c,INT_OKTIMER
	jr	INT_DECTIMER

INT_OKTIMER1:	ld	a,(IPCP_AUTOM_STATE)	;Estado 4 a 8 de IPCP?
	cp	4
	jr	c,INT_OKTIMER
	cp	9
	jr	nc,INT_OKTIMER

INT_DECTIMER:	ld	hl,(RST_TIMER)	;Ya es 0?
	ld	a,h
	or	l
	jr	z,INT_OKTIMER

	dec	hl	;No es 0: decrementar
	ld	(RST_TIMER),hl
INT_OKTIMER:	;

	;--- Pone a cero LCP/IPCP_TERM_RCV si es necesario

	;ld      a,(LCP_AUTOM_STATE)
	;cp      9
	;jr      nz,INT_OKLCPTERM
	;xor     a
	;ld      (LCP_TERM_RCV),a
INT_OKLCPTERM:			;

	;ld      a,(IPCP_AUTOM_STATE)
	;cp      9
	;jr      nz,INT_OKIPCPTERM
	;xor     a
	;ld      (IPCP_TERM_RCV),a
INT_OKIPCPTERM:			;

	;--- Recibe paquete y lo encola adecuadamente
	;    o genera respuesta adecuada

	;*** PRUEBAS: Para no coger dos paquetes seguidos

GET_INTERV:	equ	5

INT_GETPAQ:	ld	a,(GET_INTERV_C)
	or	a
	jr	z,INT_GETPAQ2
	dec	a
	ld	(GET_INTERV_C),a
	jp	INT_OKPAQ

GET_INTERV_C:	db	0

INT_GETPAQ2:	ld	hl,GET_BUFER-2

	call	GET_HDLC
	or	a
	jp	nz,INT_OKPAQ

	ld	a,GET_INTERV
	ld	(GET_INTERV_C),a

	xor	a	;Pone a 0 el contador de ecos
	ld	(ECHO_CLOSE),a	;enviados y no respondidos
	ld	hl,(ECHO_CNT_V)
	ld	(ECHO_CNT),hl

	;Escoge accion segun protocolo del paquete

	ld	hl,(GET_BUFER-2)
	ld	de,#21C0
	call	COMP
	jp	z,INT_IS_LCP
	ld	de,#2180
	call	COMP
	jp	z,INT_IS_IPCP
	ld	de,#2100
	call	COMP
	jp	z,INT_IS_IP
	ld	de,#2D00	;Paquete VJ
	call	COMP
	jp	z,INT_IS_IP
	ld	de,#2F00	;Paquete VJ
	call	COMP
	jp	z,INT_IS_IP
	ld	de,#23C0
	call	COMP
	jp	z,INT_IS_PAP
	ld	de,#23C2
	call	COMP
	jp	z,INT_IS_CHAP

	;Paquete de protocolo desconocido:
	;si LCP en estado 9, envia Protocol Reject

	ld	ix,RCVED_UNK
	inc	(ix)

	ld	a,(LCP_AUTOM_STATE)
	cp	9
	jp	nz,INT_OKPAQ

INT_PROTREJ:	ld	hl,GET_BUFER	;Copia paquete a rechazar
	ld	de,PUT_BUFER+6	;como cuerpo del paquete ProtRej
	ld	a,b
	and	%00000111
	ld	b,a
	push	bc
	ldir
	pop	bc

	ld	ix,PUT_BUFER	;Compone cabecera de paquete ProtRej
	ld	(ix),8
	ld	hl,LCP_ID_PX
	inc	(hl)
	ld	a,(hl)
	ld	(ix+1),a
	ld	hl,6
	add	hl,bc	;HL=Long. total paquete ProtRej
	ld	de,(MTU)
	dec	de
	dec	de
	dec	de
	dec	de
	call	COMP
	jr	nc,INT_OKPSIZE	;Comprueba si hay que truncar tamanyo
	ld	hl,(MTU)	;al valor del MTU
INT_OKPSIZE:	ld	(ix+2),h
	ld	(ix+3),l
	ld	de,(GET_BUFER-2)
	ld	(ix+4),e
	ld	(ix+5),d

	ld	hl,PUT_BUFER
	call	PUT_XCP	;Envia paquete ProtRej
	jp	INT_OKPAQ

	;Paquete LCP: lo encola directamente

INT_IS_LCP:	ld	ix,RCVED_LCP
	inc	(ix)
	ld	ix,LCP_IN_QUEUE
	call	ENQUEUE
	jp	INT_OKPAQ

	;Paquete IPCP: Encolarlo si estamos en estado de red
	;(LCP en estado 9 y autentif. completada)

INT_IS_IPCP:	ld	ix,RCVED_IPCP
	inc	(ix)
	call	NETWORK_STATUS
	cp	2
	jp	c,INT_OKPAQ

	ld	ix,IPCP_IN_QUEUE
	call	ENQUEUE
	jp	INT_OKPAQ

	;Paquete IP: Encolarlo si estamos en estado de red
	;(LCP e IPCP en estado 9)

INT_IS_IP:	ld	ix,RCVED_IP
	inc	(ix)
	push	bc
	call	NETWORK_STATUS
	pop	bc
	cp	3
	jp	nz,INT_OKPAQ

	ld	ix,IP_IN_QUEUE
	call	ENQUEUE_PROTO	;Encola con bytes de protocolo
	jp	INT_OKPAQ

	;PAP: Enviar Protocol Reject si AUTH_POLICY es 0 o #C2
	;Si no, modificar AUTH_STATUS adecuadamente
	;O si es peticion de autentificacion, enviamos ACK siempre

INT_IS_PAP:	ld	ix,RCVED_PAP
	inc	(ix)
	call	NETWORK_STATUS	;Ignorar si LCP no esta en estado 9
	or	a
	jp	z,INT_OKPAQ

	ld	a,(AUTH_POLICY)
	or	a
	jp	z,INT_PROTREJ
	cp	#C2
	jp	z,INT_PROTREJ

	ld	a,(AUTH_STATUS)	;Ignorar si ya estamos autentificados
	cp	2
	jp	z,INT_GETPAQ
	or	a
	jp	z,INT_GETPAQ

	ld	a,(GET_BUFER)
	cp	1
	jr	z,INT_PAP_REQ
	cp	2
	jr	z,INT_PAP_ACK
	cp	3
	jr	z,INT_PAP_NAK
	jp	INT_GETPAQ	;Codigo PAP desconocido: ignorar

INT_PAP_REQ:	ld	ix,PUT_BUFER	;Request: enviar ACK siempre
	ld	(ix),1
	ld	a,(GET_BUFER+1)
	ld	(ix+1),a	;Repite el Id del Request
	ld	(ix+2),0
	ld	(ix+3),4
	ld	de,#C023
	ld	hl,PUT_BUFER
	call	PUT_HDLC

INT_PAP_ACK:	ld	a,2
	jr	INT_PAP_AKNAK

INT_PAP_NAK:	ld	a,3

INT_PAP_AKNAK:	ld	(AUTH_STATUS),a
	ld	hl,XAP_MSG_LEN
	ld	de,XAP_MSG
	call	GET_MSG

	jp	INT_GETPAQ

	;CHAP: Enviar Protocol Reject si AUTH_POLICY es 0 o #C0
	;Si no, encolar paquete

INT_IS_CHAP:	ld	ix,RCVED_CHAP
	inc	(ix)
	call	NETWORK_STATUS	;Ignorar si LCP no esta en estado 9
	or	a
	jr	z,INT_OKPAQ

	ld	a,(AUTH_POLICY)
	or	a
	jp	z,INT_PROTREJ
	cp	#C0
	jp	z,INT_PROTREJ

	ld	ix,CHAP_IN_QUEUE
	call	ENQUEUE
	jp	INT_GETPAQ
INT_OKPAQ:	;

	;--- Llama a los automatas LCP e IPCP

	call	LCP_AUTOM
	;call    NETWORK_STATUS
	;cp      2
	;ld      a,(CLOSE_PENDING);*** PRUEBAS
	;ret     nz               ;*** PRUEBAS
	call	IPCP_AUTOM	;call    nc,IPCP_AUTOM

	;--- Llama al automata CHAP si este es el protocolo
	;    y estamos en estado 9

	call	NETWORK_STATUS
	or	a
	jr	z,INT_OKCHAP

	ld	a,(AUTH_PROTO)
	cp	#C2
	call	z,CHAP_AUTOM
INT_OKCHAP:	;
	;ld      a,(CLOSE_PENDING);*** PRUEBAS
	;ret     nz               ;*** PRUEBAS

	;--- Si AUTH_STATUS es 1 y el protocolo es PAP,
	;    envia nombre+password si PAPREQ_CNT es 0

	call	NETWORK_STATUS
	cp	1
	jr	nz,INT_OKAUTHR
	ld	a,(AUTH_PROTO)
	cp	#C0
	jr	nz,INT_OKAUTHR

	ld	hl,PAPREQ_CNT	;Comprueba contador
	dec	(hl)
	ld	a,(hl)
	cp	#FF
	jr	nz,INT_OKAUTHR
	ld	a,(PAPREQ_CNT_V)
	ld	(PAPREQ_CNT),a

	ld	ix,PUT_BUFER	;Compone cabecera + lon. nombre
	ld	hl,LCP_ID_PAP
	inc	(hl)
	ld	a,(hl)
	ld	(ix),1
	ld	(ix+1),a
	ld	a,(USER_LEN)
	ld	(ix+4),a
	ld	l,a
	ld	h,0
	ld	a,(PASSWORD_LEN)
	ld	c,a
	ld	b,0
	add	hl,bc
	ld	bc,6
	add	hl,bc
	ld	(ix+2),h
	ld	(ix+3),l

	ld	hl,USER	;Inserta nombre de usuario
	ld	de,PUT_BUFER+5
	ld	bc,(USER_LEN)
	ld	b,0
	ldir

	ld	a,(PASSWORD_LEN)	;Inserta lon. pass. + password
	ld	(de),a
	inc	de
	ld	hl,PASSWORD
	ld	c,a
	ld	b,0
	ldir

	ld	hl,PUT_BUFER	;Envia paquete
	ld	de,#C023
	ld	bc,0
	call	PUT_HDLC
INT_OKAUTHR:	;

	;--- Borra la lista OUT si no hay capa fisica disponible

	call	LOWER_RDY
	jr	c,INT_OKLOWER

	ld	ix,OUT_QUEUE
	call	FLUSH_QUEUE
	ret
INT_OKLOWER:	;

	;--- Comprueba si hay algun paquete en la cola IP
	;    de salida y lo mueve a la cola del nivel inferior

	ld	a,(#8002)
	ld	l,a
	ld	a,(IP_OUT_QUEUE)
	ld	ix,(IP_OUT_QUEUE+1)
	ld	b,1
	ld	h,3	;Obtiene y elimina de la cola
	ld	iy,PUT_BUFER-2
	nesman	29
	ret	c	;Termina si no hay paquetes

	ld	hl,PUT_BUFER	;Envia el paquete, que estaba
	dec	bc	;encolado como 2 bytes de
	dec	bc	;protocolo+paquete
	ld	a,(PUT_BUFER-2)
	ld	d,a
	ld	a,(PUT_BUFER-1)
	ld	e,a
	call	PUT_HDLC
	ret



;****************************
;**                        **
;**   AUTOMATA NEGOCIADOR  **
;**                        **
;****************************

;Sirve para LCP e IPCP
;En modo IPCP:
;- AUTOM_IS_LCP vale #FF
;- Los eventos Up y Down son disparados por tls y tlf de LCP
;- Los eventos Open y Close se detectan tras los equivalentes de LCP
;- Solo se aceptan paquetes con codigos 1 a 7
;- Las acciones tls y tlf no hacen nada
;En modo LCP, las acciones tlu y tld no hacen nada

;* NO comprueba transiciones ilegales entre estados
;* Los eventos "Up", "Down", "Open" y "Close" solo se detectan una vez
;  (para detectar un "Up" antes se ha de haber hecho un "Down",
;   lo mismo para "Open" y "Close")
;* Altamente optimizable en cuanto a espacio en la codific. de los estados
;* ATENCION: SCA/SCN siempre debe ejecutarse ANTES que SCR cuando ambas
;            acciones han de realizarse en el mismo paso del automata
;            (porque RCR+/- generan un paquete de respuesta en el mismo
;             bufer que usa SCR, y SCA/SCN asumen que el paquete de respuesta
;             sigue en el bufer)

	;--- Punto de entrada para automata LCP

LCP_AUTOM:	xor	a
	ld	(AUTOM_IS_IPCP),a
	ld	a,(LCP_AUTOM_STATE)
	ld	(AUTOM_STATE),a
	call	AUTOMATON
	ld	a,(AUTOM_STATE)
	ld	(LCP_AUTOM_STATE),a
	ret

	;--- Punto de entrada para automata LCP

IPCP_AUTOM:	ld	a,#FF
	ld	(AUTOM_IS_IPCP),a
	ld	a,(IPCP_AUTOM_STATE)
	ld	(AUTOM_STATE),a
	call	AUTOMATON
	xor	a
	ld	(AUTOM_IS_IPCP),a
	ld	a,(AUTOM_STATE)
	ld	(IPCP_AUTOM_STATE),a
	ret

	;--- Automata comun

AUTOMATON:	ld	a,(AUTOM_STATE)
	or	a
	jr	z,AUTOM_0
	dec	a
	jr	z,AUTOM_1
	dec	a
	jr	z,AUTOM_2
	dec	a
	jp	z,AUTOM_3
	dec	a
	jp	z,AUTOM_4
	dec	a
	jp	z,AUTOM_5
	dec	a
	jp	z,AUTOM_6
	dec	a
	jp	z,AUTOM_7
	dec	a
	jp	z,AUTOM_8
	dec	a
	jp	z,AUTOM_9

	ret		;Estado desconocido?


;---------------------------
;---  Estado 0: Initial  ---
;---------------------------

AUTOM_0:	;

	;--- Recibimos UP?

	call	EV_UP
	jr	nc,LCPAUT0_1

	ld	a,2
	ld	(AUTOM_STATE),a
	ret
LCPAUT0_1:

	;--- Recibimos OPEN?

	call	EV_OPEN
	ret	nc

	call	AC_TLS
	ld	a,1
	ld	(AUTOM_STATE),a
	ret


;----------------------------
;---  Estado 1: Starting  ---
;----------------------------

AUTOM_1:	;

	;--- Recibimos Up?

	call	EV_UP
	jr	nc,LCPAUT1_1

	ld	a,(CUR_PASSIVE_OPEN)
	or	a	;Apertura pasiva:
	jr	z,NOPASOP_1	;saltamos al estado "Stopped"
	ld	a,3	;sin enviar nada
	ld	(AUTOM_STATE),a
	ret

NOPASOP_1:	call	AC_IRC_C
	call	AC_SCR
	ld	a,6
	ld	(AUTOM_STATE),a
	ret
LCPAUT1_1:

	;--- Recibimos close?

	call	EV_CLOSE
	ret	nc

	call	AC_TLF
	xor	a
	ld	(AUTOM_STATE),a
	ret


;--------------------------
;---  Estado 2: Closed  ---
;--------------------------

AUTOM_2:	;

	;--- Recibimos down?

	call	EV_DOWN
	jr	nc,LCPAUT2_1

	xor	a
	ld	(AUTOM_STATE),a
	ret
LCPAUT2_1:	;

	;--- Recibimos open?

	call	EV_OPEN
	jr	nc,LCPAUT2_2

	ld	a,(CUR_PASSIVE_OPEN)
	or	a	;Apertura pasiva:
	jr	z,NOPASOP_2	;saltamos al estado "Stopped"
	ld	a,3	;sin enviar nada
	ld	(AUTOM_STATE),a
	ret

NOPASOP_2:	call	AC_IRC_C
	call	AC_SCR
	ld	a,6
	ld	(AUTOM_STATE),a
	ret
LCPAUT2_2:	;

	;--- Recepcion de un paquete

	call	GET_LCP
	ret	nc

	;--- Es Configure Request OK?

	call	EV_RCR_MAS
	jr	nc,LCPAUT2_3
	call	AC_STA
	ret
LCPAUT2_3:	;

	;--- Es Configure Request BAD?

	call	EV_RCR_MENOS
	jr	nc,LCPAUT2_4
	call	AC_STA
	ret
LCPAUT2_4:	;

	;--- Es Receive Configure Ack?

	call	EV_RCA
	jr	nc,LCPAUT2_5
	call	AC_STA
	ret
LCPAUT2_5:	;

	;--- Es Receive Configure Nak?

	call	EV_RCN
	jr	nc,LCPAUT2_6
	call	AC_STA
	ret
LCPAUT2_6:	;

	;--- Es Receive Terminate Request?

	call	EV_RTR
	jr	nc,LCPAUT2_7
	call	AC_STA
	ret
LCPAUT2_7:	;

	;--- Es Receive Unknown Code?

	call	EV_RUC
	jr	nc,LCPAUT2_8
	call	AC_SCJ
	ret
LCPAUT2_8:	;

	;--- Es Receive Code/Protocol Reject BAD?

	call	EV_RXJ_MENOS
	ret	nc
	call	AC_TLF
	ret


;---------------------------
;---  Estado 3: Stopped  ---
;---------------------------

AUTOM_3:	;

	;--- Recibimos down?

	call	EV_DOWN
	jr	nc,LCPAUT3_1

	call	AC_TLS
	ld	a,1
	ld	(AUTOM_STATE),a
	ret
LCPAUT3_1:	;

	;--- Recibimos Close?

	call	EV_CLOSE
	jr	nc,LCPAUT3_2
	ld	a,2
	ld	(AUTOM_STATE),a
	ret
LCPAUT3_2:	;

	;--- Recepcion de un paquete

	call	GET_LCP
	ret	nc

	;--- Es Configure Request OK?

	call	EV_RCR_MAS
	jr	nc,LCPAUT3_3
	call	AC_IRC_C
	call	AC_SCA
	call	AC_SCR
	ld	a,8
	ld	(AUTOM_STATE),a
	ret
LCPAUT3_3:	;

	;--- Es Configure Request BAD?

	call	EV_RCR_MENOS
	jr	nc,LCPAUT3_4
	call	AC_IRC_C
	call	AC_SCN
	call	AC_SCR
	ld	a,6
	ld	(AUTOM_STATE),a
	ret
LCPAUT3_4:	;

	;--- Es Receive Configure Ack?

	call	EV_RCA
	jr	nc,LCPAUT3_5
	call	AC_STA
	ret
LCPAUT3_5:	;

	;--- Es Receive Configure Nak?

	call	EV_RCN
	jr	nc,LCPAUT3_6
	call	AC_STA
	ret
LCPAUT3_6:	;

	;--- Es Receive Terminate Request?

	call	EV_RTR
	jr	nc,LCPAUT3_7
	call	AC_STA
	ret
LCPAUT3_7:	;

	;--- Es Receive Unknown Code?

	call	EV_RUC
	jr	nc,LCPAUT3_8
	call	AC_SCJ
	ret
LCPAUT3_8:	;

	;--- Es Receive Code/Protocol Reject BAD?

	call	EV_RXJ_MENOS
	ret	nc
	call	AC_TLF
	ret


;-------------------------------------------
;---  Estados 4 y 5: Closing y Stopping  ---
;-------------------------------------------

AUTOM_4:	xor	a
	ld	(LCPAUTOM_4OR5),a
	jr	AUTOM_45

AUTOM_5:	ld	a,1
	ld	(LCPAUTOM_4OR5),a

AUTOM_45:	;

	;--- Recibimos Down?

	call	EV_DOWN
	jr	nc,LCPAUT45_1

	ld	a,(LCPAUTOM_4OR5)
	ld	(AUTOM_STATE),a
	ret
LCPAUT45_1:	;

	;--- Recibimos Open?

	call	EV_OPEN
	jr	nc,LCPAUT45_2

	ld	a,5
	ld	(AUTOM_STATE),a
	ret
LCPAUT45_2:	;

	;--- Recibimos Close?

	call	EV_CLOSE
	jr	nc,LCPAUT45_3

	ld	a,4
	ld	(AUTOM_STATE),a
	ret
LCPAUT45_3:	;

	;--- Recepcion de un paquete

	call	GET_LCP
	jr	nc,NOPAQ_45

	;--- Es Receive Terminate Request?

	call	EV_RTR
	jr	nc,LCPAUT45_6
	call	AC_STA
	ret
LCPAUT45_6	;

	;--- Es Receive Terminate Ack?

	call	EV_RTA
	jr	nc,LCPAUT45_7
	call	AC_TLF
	ld	a,(LCPAUTOM_4OR5)
	add	2
	ld	(AUTOM_STATE),a
	ret
LCPAUT45_7:	;

	;--- Es Receive Unknown Code?

	call	EV_RUC
	jr	nc,LCPAUT45_8
	call	AC_SCJ
	ret
LCPAUT45_8:	;

	;--- Es Receive Code/Protocol Reject BAD?

	call	EV_RXJ_MENOS
	ret	nc

	call	AC_TLF
	ld	a,(LCPAUTOM_4OR5)
	add	2
	ld	(AUTOM_STATE),a
	ret
LCPAUT45_9:	;

	;--- Time Out con contador > 0?

NOPAQ_45:	call	EV_TO_MAS
	jr	nc,LCPAUT45_4

	call	AC_STR
	ret
LCPAUT45_4:	;

	;--- Time Out con contador = 0?

	call	EV_TO_MENOS
	ret	nc

	call	AC_TLF
	ld	a,(LCPAUTOM_4OR5)
	add	2
	ld	(AUTOM_STATE),a
	ret

LCPAUTOM_4OR5:	db	0


;----------------------------
;---  Estado 6: Req-Sent  ---
;----------------------------

AUTOM_6:	;

	;--- Recibimos Down?

	call	EV_DOWN
	jr	nc,LCPAUT6_1

	ld	a,1
	ld	(AUTOM_STATE),a
	ret
LCPAUT6_1:	;

	;--- Recibimos Close?

	call	EV_CLOSE
	jr	nc,LCPAUT6_2

	call	AC_IRC_T
	call	AC_STR
	ld	a,4
	ld	(AUTOM_STATE),a
	ret
LCPAUT6_2:	;

	;--- Recepcion de un paquete

	call	GET_LCP
	jr	nc,NOPAQ_6

	;--- Es Configure Request OK?

	call	EV_RCR_MAS
	jr	nc,LCPAUT6_6
	call	AC_SCA
	ld	a,8
	ld	(AUTOM_STATE),a
	ret
LCPAUT6_6:	;

	;--- Es Configure Request BAD?

	call	EV_RCR_MENOS
	jr	nc,LCPAUT6_7
	call	AC_SCN
	ret
LCPAUT6_7:	;

	;--- Es Receive Configure Ack?

	call	EV_RCA
	jr	nc,LCPAUT6_8
	call	AC_IRC_C
	ld	a,7
	ld	(AUTOM_STATE),a
	ret
LCPAUT6_8:	;

	;--- Es Receive Configure Nak?

	call	EV_RCN
	jr	nc,LCPAUT6_9
	call	AC_IRC_C
	call	AC_SCR
	ret
LCPAUT6_9:	;

	;--- Es Receive Terminate Request?

	call	EV_RTR
	jr	nc,LCPAUT6_10
	call	AC_STA
	ret
LCPAUT6_10:	;

	;--- Es Receive Unknown Code?

	call	EV_RUC
	jr	nc,LCPAUT6_11
	call	AC_SCJ
	ret
LCPAUT6_11:	;

	;--- Es Receive Code/Protocol Reject BAD?

	call	EV_RXJ_MENOS
	ret	nc
	call	AC_TLF
	ld	a,3
	ld	(AUTOM_STATE),a
	ret

	;--- Time Out con contador > 0?

NOPAQ_6:	call	EV_TO_MAS
	jr	nc,LCPAUT6_4

	call	AC_SCR
	ret
LCPAUT6_4:	;

	;--- Time Out con contador = 0?

	call	EV_TO_MENOS
	ret	nc

	call	AC_TLF
	ld	a,3
	ld	(AUTOM_STATE),a
	ret
LCPAUT6_5:	;


;----------------------------
;---  Estado 7: Ack-Rcvd  ---
;----------------------------

AUTOM_7:	;

	;--- Recibimos Down?

	call	EV_DOWN
	jr	nc,LCPAUT7_1

	ld	a,1
	ld	(AUTOM_STATE),a
	ret
LCPAUT7_1:	;

	;--- Recibimos Close?

	call	EV_CLOSE
	jr	nc,LCPAUT7_2

	call	AC_IRC_T
	call	AC_STR
	ld	a,4
	ld	(AUTOM_STATE),a
	ret
LCPAUT7_2:	;

	;--- Recepcion de un paquete

	call	GET_LCP
	jr	nc,NOPAQ_7

	;--- Es Configure Request OK?

	call	EV_RCR_MAS
	jr	nc,LCPAUT7_6
	call	AC_SCA
	call	AC_TLU
	ld	a,9
	ld	(AUTOM_STATE),a
	ret
LCPAUT7_6:	;

	;--- Es Configure Request BAD?

	call	EV_RCR_MENOS
	jr	nc,LCPAUT7_7
	call	AC_SCN
	ret
LCPAUT7_7:	;

	;--- Es Receive Configure Ack o Nak?

	call	EV_RCA
	jr	c,LCPAUT7_8
	call	EV_RCN
	jr	nc,LCPAUT7_9
LCPAUT7_8:	call	AC_SCR
	ld	a,6
	ld	(AUTOM_STATE),a
	ret
LCPAUT7_9:	;

	;--- Es Receive Terminate Request?

	call	EV_RTR
	jr	nc,LCPAUT7_10
	call	AC_STA
	ld	a,6
	ld	(AUTOM_STATE),a
	ret
LCPAUT7_10:	;

	;--- Es Receive Terminate Ack?

	call	EV_RTA
	jr	nc,LCPAUT7_11
	ld	a,6
	ld	(AUTOM_STATE),a
	ret
LCPAUT7_11:	;

	;--- Es Receive Unknown Code?

	call	EV_RUC
	jr	nc,LCPAUT7_12
	call	AC_SCJ
	ret
LCPAUT7_12:	;

	;--- Es Receive Code/Protocol Reject OK?

	call	EV_RXJ_MAS
	jr	nc,LCPAUT7_13
	ld	a,6
	ld	(AUTOM_STATE),a
	ret
LCPAUT7_13:	;

	;--- Es Receive Code/Protocol Reject BAD?

	call	EV_RXJ_MENOS
	ret	nc
	call	AC_TLF
	ld	a,3
	ld	(AUTOM_STATE),a
	ret

	;--- Time Out con contador > 0?

NOPAQ_7:	call	EV_TO_MAS
	jr	nc,LCPAUT7_4

	call	AC_SCR
	ld	a,6
	ld	(AUTOM_STATE),a
	ret
LCPAUT7_4:	;

	;--- Time Out con contador = 0?

	call	EV_TO_MENOS
	ret	nc

	call	AC_TLF
	ld	a,3
	ld	(AUTOM_STATE),a
	ret
LCPAUT7_5:	;


;----------------------------
;---  Estado 8: Ack-Sent  ---
;----------------------------

AUTOM_8:	;

	;--- Recibimos Down?

	call	EV_DOWN
	jr	nc,LCPAUT8_1

	ld	a,1
	ld	(AUTOM_STATE),a
	ret
LCPAUT8_1:	;

	;--- Recibimos Close?

	call	EV_CLOSE
	jr	nc,LCPAUT8_2

	call	AC_IRC_T
	call	AC_STR
	ld	a,4
	ld	(AUTOM_STATE),a
	ret
LCPAUT8_2:	;

	;--- Recepcion de un paquete

	call	GET_LCP
	jr	nc,NOPAQ_8

	;--- Es Configure Request OK?

	call	EV_RCR_MAS
	jr	nc,LCPAUT8_6
	call	AC_SCA
	ret
LCPAUT8_6:	;

	;--- Es Configure Request BAD?

	call	EV_RCR_MENOS
	jr	nc,LCPAUT8_7
	call	AC_SCN
	ld	a,6
	ld	(AUTOM_STATE),a
	ret
LCPAUT8_7:	;

	;--- Es Receive Configure Ack?

	call	EV_RCA
	jr	nc,LCPAUT8_8
	call	AC_IRC_C
	call	AC_TLU
	ld	a,9
	ld	(AUTOM_STATE),a
	ret
LCPAUT8_8:	;

	;--- Es Receive Configure NAK?

	call	EV_RCN
	jr	nc,LCPAUT8_9
	call	AC_IRC_C
	call	AC_SCR
	ret
LCPAUT8_9:	;

	;--- Es Receive Terminate Request?

	call	EV_RTR
	jr	nc,LCPAUT8_10
	call	AC_STA
	ld	a,6
	ld	(AUTOM_STATE),a
	ret
LCPAUT8_10:	;

	;--- Es Receive Unknown Code?

	call	EV_RUC
	jr	nc,LCPAUT8_12
	call	AC_SCJ
	ret
LCPAUT8_12:	;

	;--- Es Receive Code/Protocol Reject BAD?

	call	EV_RXJ_MENOS
	ret	nc
	call	AC_TLF
	ld	a,3
	ld	(AUTOM_STATE),a
	ret

	;--- Time Out con contador > 0?

NOPAQ_8:	call	EV_TO_MAS
	jr	nc,LCPAUT8_4

	call	AC_SCR
	ret
LCPAUT8_4:	;

	;--- Time Out con contador = 0?

	call	EV_TO_MENOS
	ret	nc

	call	AC_TLF
	ld	a,3
	ld	(AUTOM_STATE),a
	ret
LCPAUT8_5:	;


;--------------------------
;---  Estado 9: Opened  ---
;--------------------------

AUTOM_9:	;

	;--- Recibimos Down?

	call	EV_DOWN
	jr	nc,LCPAUT9_1

	call	AC_TLD
	ld	a,1
	ld	(AUTOM_STATE),a
	ret
LCPAUT9_1:	;

	;--- Recibimos Close?

	call	EV_CLOSE
	jr	nc,LCPAUT9_2

	call	AC_TLD
	call	AC_IRC_T
	call	AC_STR
	ld	a,4
	ld	(AUTOM_STATE),a
	ret
LCPAUT9_2:	;

	;--- Recepcion de un paquete

	call	GET_LCP
	ret	nc

	;--- Es Configure Request OK?

	call	EV_RCR_MAS
	jr	nc,LCPAUT9_6
	call	AC_TLD
	call	AC_SCA
	call	AC_SCR
	ld	a,8
	ld	(AUTOM_STATE),a
	ret
LCPAUT9_6:	;

	;--- Es Configure Request BAD?

	call	EV_RCR_MENOS
	jr	nc,LCPAUT9_7
	call	AC_TLD
	call	AC_SCN
	call	AC_SCR
	ld	a,6
	ld	(AUTOM_STATE),a
	ret
LCPAUT9_7:	;

	;--- Es Receive Configure Ack o Nak?

	call	EV_RCA
	jr	c,LCPAUT9_8
	call	EV_RCN
	jr	nc,LCPAUT9_9
LCPAUT9_8:	call	AC_TLD
	call	AC_SCR
	ld	a,6
	ld	(AUTOM_STATE),a
	ret
LCPAUT9_9:	;

	;--- Es Receive Terminate Request?

	call	EV_RTR
	jr	nc,LCPAUT9_10
	call	AC_TLD
	call	AC_ZRC
	call	AC_STA
	ld	a,5
	ld	(AUTOM_STATE),a
	ret
LCPAUT9_10:	;

	;--- Es Receive Terminate Ack?

	call	EV_RTA
	jr	nc,LCPAUT9_11
	call	AC_TLD
	call	AC_SCR
	ld	a,6
	ld	(AUTOM_STATE),a
	ret
LCPAUT9_11:	;

	;--- Es Receive Unknown Code?

	call	EV_RUC
	jr	nc,LCPAUT9_12
	call	AC_SCJ
	ret
LCPAUT9_12:	;

	;--- Es Receive Code/Protocol Reject BAD?

	call	EV_RXJ_MENOS
	jr	nc,LCPAUT9_14
	call	AC_TLD
	call	AC_IRC_T
	call	AC_STR
	ld	a,5
	ld	(AUTOM_STATE),a
	ret
LCPAUT9_14:	;

	;--- Es Receive Echo Request?

	call	EV_RXR
	ret	nc
	call	AC_SER
	ret


;-----------------
;---  EVENTOS  ---
;-----------------

;Devuelve Cy=1 si el evento se produce

	;--- Up

EV_UP:	ld	a,(AUTOM_IS_IPCP)
	or	a
	jr	nz,EV_UP_IPCP

	;Version LCP

	call	LOWER_RDY	;Devuelve Cy=1 solo si estamos UP
	ld	b,#FF	;pero la ultima vez que se comprobo
	jr	c,EV_UP1	;estabamos DOWN
	ld	b,0
EV_UP1:	;

	ld	a,(LAST_UPDOWN)
	cp	b
	ret	z

	ld	a,b
	ld	(LAST_UPDOWN),a

	call	LOWER_RDY
	ret

	;Version IPCP

EV_UP_IPCP:	ld	a,(UP_FOR_IPCP)
	or	a
	ret	z
	ld	a,(AUTH_STATUS)	;Anyadido en 0.4
	cp	1
	ret	z
	xor	a
	ld	(UP_FOR_IPCP),a
	scf
	ret

	;--- Down

EV_DOWN:	ld	a,(AUTOM_IS_IPCP)
	or	a
	jr	nz,EV_DOWN_IPCP

	;Version LCP

	call	LOWER_RDY
	ld	b,0
	jr	c,EV_DOWN1
	ld	b,#FF
EV_DOWN1:	;

	ld	a,(LAST_UPDOWN)
	cp	b
	ret	z

	ld	a,b
	ld	(LAST_UPDOWN),a

	call	LOWER_RDY
	ccf
	ret

	;Version IPCP

EV_DOWN_IPCP:	ld	a,(DOWN_FOR_IPCP)
	or	a
	ret	z
	xor	a
	ld	(DOWN_FOR_IPCP),a
	scf
	ret

	;--- Open

EV_OPEN:	ld	a,(AUTOM_IS_IPCP)
	or	a
	jr	nz,EV_OPEN_IPCP

	;Version LCP

	ld	a,(LAST_OPCLOSE)
	ld	b,a
	ld	a,(OPENED)
	cp	b
	ret	z

	or	a
	ret	z

	call	INIT_VAR	;Inicializa variables al hacer OPEN
	ld	a,#FF
	ld	(OPEN_FOR_IPCP),a
	ld	(TOTAL_TIMER_ON),a
	xor	a
	ld	(CLOSE_ERROR),a
	ld	(ECHO_CLOSE),a
	ld	(FAIL_CNT),a
	ld	(LOOPBACK_CNT),a
	ld	(TIMER_ON),a
	ld	(CLOSE_FOR_IPCP),a
	ld	(LCP_TERM_RCV),a
	ld	(IPCP_TERM_RCV),a
	ld	hl,0	;Inicializa y activa
	ld	(TOTAL_TIMER),hl	;contador total
	ld	a,(PASSIVE_OPEN)
	ld	(CUR_PASSIVE_OPEN),a
	scf
	ret

	;Version IPCP

EV_OPEN_IPCP:	ld	a,(OPEN_FOR_IPCP)
	or	a
	ret	z
	xor	a
	ld	(OPEN_FOR_IPCP),a
	scf
	ret

	;--- Close

EV_CLOSE:	ld	a,(AUTOM_IS_IPCP)
	or	a
	jr	nz,EV_CLOSE_IPCP

	;Version LCP

	ld	a,(LAST_OPCLOSE)
	ld	b,a
	ld	a,(OPENED)
	cp	b
	ret	z

	or	a
	scf
	jr	z,EV_CLOSE2
	ccf
	ret

EV_CLOSE2:	ld	a,-1
	ld	(CLOSE_FOR_IPCP),a
	xor	a
	ld	(OPEN_FOR_IPCP),a
	;ld      ix,LCP_IN_QUEUE
	;call    FLUSH_QUEUE
	ld	ix,OUT_QUEUE
	call	FLUSH_QUEUE
	scf
	ret

	;Version IPCP

EV_CLOSE_IPCP:	ld	a,(CLOSE_FOR_IPCP)
	or	a
	ret	z
	xor	a
	ld	(CLOSE_FOR_IPCP),a
	;ld      ix,IPCP_IN_QUEUE
	;call    FLUSH_QUEUE
	scf
	ret

	;--- Time Out con contador > 0

EV_TO_MAS:	ld	hl,(RST_TIMER)
	ld	a,h
	or	l
	ret	nz

	ld	a,(RST_COUNT)
	or	a
	ret	z

	;dec     a
	;ld      (RST_COUNT),a

	ld	hl,(RST_TIMER_V)	;Reinicializa contador si llega a 0
	ld	(RST_TIMER),hl

	scf
	ret

	;--- Time Out con contador = 0

EV_TO_MENOS:	ld	hl,(RST_TIMER)
	ld	a,h
	or	l
	ret	nz

	ld	a,(RST_COUNT)
	or	a
	scf
	ret	z

	ld	hl,(RST_TIMER_V)	;Reinicializa contador si llega a 0
	ld	(RST_TIMER),hl

	ccf
	ret

	;*** Eventos de recepcion: asumen que hay un
	;    paquete LCP en GET_BUFER
	;    y generan el paquete de respuesta adecuado
	;    en PUT_BUFER (si RCR o RXR)

	;--- Receive Configure Request, correcto

EV_RCR_MAS:	ld	hl,GET_BUFER
	ld	de,PUT_BUFER
	call	PARSE_CONFREQ	;Es correcto si devuelve A=0
	cp	#82
	jr	nz,EV_RCR_MAS2
	ld	a,#FF	;Looped-back? Simular Close
	ld	(CLOSE_PENDING),a
	ld	a,3
	ld	(CLOSE_ERROR),a
	call	FLUSH_ALL
	ret
EV_RCR_MAS2:	or	a
	scf
	ret	z
	or	a
	ret

	;--- Receive Configure Request, incorrecto

EV_RCR_MENOS:	ld	hl,GET_BUFER
	ld	de,PUT_BUFER
	call	PARSE_CONFREQ	;Es incorrecto si devuelve A=1 o 2
	dec	a
	and	%11111110
	scf
	ret	z
	or	a
	ret

	;--- Receive Configure Ack

EV_RCA:	ld	a,(GET_BUFER)	;Cy=0 si no es Configure Ack
	cp	2
	scf
	ccf
	ret	nz

	ld	hl,LCP_ID_CR	;Cy=0 si el Id no coincide con el del
	ld	a,(GET_BUFER+1)	;ultimo Configure Request enviado
	cp	(hl)
	scf
	ccf
	ret	nz

	scf
	ret

	;--- Receive Configure Nak/Rej

EV_RCN:	ld	hl,GET_BUFER	;Es Configure Nak?
	call	PARSE_CONFNAK
	or	a
	jr	z,EV_RCN2

	ld	hl,GET_BUFER	;Es Configure Reject?
	call	PARSE_CONFREJ
	or	a
	ret	nz

EV_RCN2:	ld	hl,LCP_ID_CR	;Cy=0 si el Id no coincide con el del
	ld	a,(GET_BUFER+1)	;ultimo Configure Request enviado
	cp	(hl)
	scf
	ccf
	ret	nz

	scf
	ret

	;--- Receive Terminate Request

EV_RTR:	call	_EV_RTR
	ret	nc
	ld	a,(AUTO_CLOSE_TERM)
	or	a
	scf
	ret	z
	;ld      a,(AUTOM_IS_IPCP)   ;Quitado en 0.4
	;or      a
	;scf
	;ret     nz
	ld	a,#FF	;Cierre automatico
	ld	(CLOSE_PENDING),a	;si AUTO_CLOSE_TERM activado
	ld	a,5	;y es un paquete LCP
	ld	(CLOSE_ERROR),a
	scf
	ret

_EV_RTR:	ld	a,(GET_BUFER)
	cp	5
	scf
	ccf
	ret	nz

	ld	a,(AUTOM_IS_IPCP)
	or	a
	ld	hl,LCP_MSG_LEN
	ld	de,LCP_MSG
	ld	ix,LCP_TERM_RCV
	jr	z,EV_RTR2
	ld	hl,IPCP_MSG_LEN
	ld	de,IPCP_MSG
	ld	ix,IPCP_TERM_RCV
EV_RTR2:	ld	a,#FF
	ld	(ix),a
	call	GET_MSG	;Obtiene el mensaje

	ld	a,(GET_BUFER+1)	;Copia el id para ser usado
	dec	a	;en el proximo Terminate Ack
	ld	(LCP_ID_TA),a
	scf
	ret

	;--- Receive Terminate Ack

EV_RTA:	ld	a,(GET_BUFER)
	cp	6
	scf
	ccf
	ret	nz

	scf
	ret

	;--- Receive Unknown Code

EV_RUC:	ld	a,(AUTOM_IS_IPCP)
	or	a	;Se admiten los codigos
	ld	b,8	;1 a 11 para LCP, 1 a 7 para IPCP
	jr	nz,EV_RUC2
	ld	b,12

EV_RUC2:	ld	a,(GET_BUFER)	;Cy=1 si codigo 0 o mayor que 11
	or	a
	scf
	ret	z
	cp	b
	ccf
	ret	c
	or	a
	ret

	;--- Receive Code/Protocol Reject (permitido)

EV_RXJ_MAS:	ld	a,(GET_BUFER)
	cp	7
	ccf
	ret	nc
	cp	9
	ret	nc
	call	EV_RXJ
	ccf
	ret

	;--- Receive Code/Protocol Reject (catastrofico)

EV_RXJ_MENOS:	ld	a,(GET_BUFER)
	cp	7
	ccf
	ret	nc
	cp	9
	ret	nc
	jp	EV_RXJ

	;--- Comprueba si el Code/Protocol Reject es catastrofico

EV_RXJ:	ld	a,(GET_BUFER)
	cp	7
	jr	nz,EV_RXJ2

	;Code Reject:
	;Catastrofico si el codigo era 1 a 4

	ld	a,(GET_BUFER+4)
	dec	a	;Lo convierte en 0 a 3
	and	%11111100
	scf
	ret	z
	or	a
	ret

	;Protocol Reject:
	;Catastrofico si es LCP, IPCP o IP

EV_RXJ2:	ld	hl,(GET_BUFER+4)
	ld	de,#21C0	;Era LCP?
	call	COMP
	ret	z
	ld	de,#2180	;Era IPCP?
	call	COMP
	ret	z
	ld	de,#2100	;Era IP?
	call	COMP
	ret	z
	or	a
	ret

	;--- Receive Echo/Discard Request/Reply

EV_RXR:	ld	a,(GET_BUFER)
	cp	11	;Discard Request
	jr	z,EV_RXR_D
	cp	10	;Echo Reply
	jr	z,EV_RXR_ER
	cp	9	;Echo Request
	scf
	ccf
	ret	nz

	call	CHK_MAGIC
	jr	c,EV_RXR_D2

	ld	hl,GET_BUFER	;Copia paquete a PUT_BUFER
	ld	de,PUT_BUFER
	ld	a,(GET_BUFER+2)
	and	%00000111
	ld	b,a
	ld	a,(GET_BUFER+3)
	ld	c,a
	ldir

	ld	hl,MAGIC_LOCAL	;Ponemos nuestro Magic Number
	ld	de,PUT_BUFER+4
	ld	bc,4
	ldir

	ld	a,10	;Lo convierte en Echo Reply
	ld	(PUT_BUFER),a

	scf
	ret

	;Echo reply

EV_RXR_ER:	xor	a	;Pone a 0 el contador de ecos
	ld	(ECHO_CLOSE),a	;enviados y no respondidos
	ld	hl,(ECHO_CNT_V)
	ld	(ECHO_CNT),hl

	;Discard Request

EV_RXR_D:	call	CHK_MAGIC	;Si el magic es como el nuestro,
	ret	nc	;genera un Close con error 3
EV_RXR_D2:	ld	a,#FF
	ld	(CLOSE_PENDING),a
	ld	a,3
	ld	(CLOSE_ERROR),a
	call	FLUSH_ALL
	or	a
	ret

	;Comprueba si el Magic recibido es como el nuestro
	;en ese caso devuelve Cy=1

CHK_MAGIC:	ld	hl,(GET_BUFER+4)
	ld	de,(MAGIC_LOCAL)
	call	COMP
	scf
	ccf
	ret	nz
	ld	hl,(GET_BUFER+6)
	ld	de,(MAGIC_LOCAL+2)
	call	COMP
	scf
	ccf
	ret	nz
	ccf
	ret


;------------------
;---  ACCIONES  ---
;------------------

	;--- This-layer-up

AC_TLU:	ld	a,(AUTOM_IS_IPCP)
	or	a
	jr	z,AC_TLU_LCP

	ld	a,#FF
	ld	(THIS_LAYER_ST),a
	ret

AC_TLU_LCP:	ld	a,-1	;LCP: Notifica "Up" a IPCP
	ld	(UP_FOR_IPCP),a
	xor	a
	ld	(DOWN_FOR_IPCP),a
	ret

	;--- This-layer-down

AC_TLD:	ld	a,(AUTOM_IS_IPCP)
	or	a
	jr	z,AC_TLD_LCP

	xor	a
	ld	(THIS_LAYER_ST),a
	ret

AC_TLD_LCP:	ld	a,-1	;LCP: Notifica "Down" a IPCP
	ld	(DOWN_FOR_IPCP),a
	xor	a
	ld	(UP_FOR_IPCP),a
	ret

	;--- This-layer-started

AC_TLS:	ld	a,(AUTOM_IS_IPCP)
	or	a	;No hace nada si automata IPCP
	ret	nz

	call	ASK_LOWER_START
	ret

	;--- This-layer-finished

AC_TLF:	ld	a,(AUTOM_IS_IPCP)
	or	a	;No hace nada si automata IPCP
	ret	nz

	call	ASK_LOWER_END
	ret

	;--- Initialize-restart-count para Max-Terminate

AC_IRC_T:	ld	a,(MAX_TERM_CNT_V)
	jr	AC_IRC

	;--- Initialize-restart-count para Max-Configure

AC_IRC_C:	ld	a,(MAX_CONF_CNT_V)
	jr	AC_IRC

	;--- Zero-restart-count

AC_ZRC:	xor	a

AC_IRC:	ld	(RST_COUNT),a	;Modificar el contador tambien
	ld	hl,(RST_TIMER_V)	;implica establecer el temporizador
	ld	(RST_TIMER),hl
	ret

	;--- Send-configure-request

AC_SCR:	ld	hl,RST_COUNT
	ld	a,(hl)
	or	a
	jr	z,AC_SCR2
	dec	(hl)
AC_SCR2:	ld	hl,LCP_ID_CR	;Incrementa el identificador
	inc	(hl)	;aunque sea una retransmision
	;ld      hl,(RST_TIMER_V)
	;ld      (RST_TIMER),hl
	ld	hl,PUT_BUFER
	call	MAKE_CONFREQ
	ld	hl,PUT_BUFER
	jp	PUT_XCP	;Suponemos que siempre se envia bien

	;--- Send-configure-ack
	;--- Send-configure-nak/rej
	;    (ambas acciones son iguales, ya que al recibir un
	;    paquete ConfReq, se examina y se genera automaticamente
	;    el paquete de respuesta adecuado en PUT_BUFER)

AC_SCA:	xor	a
	ld	(FAIL_CNT),a

	jr	AC_SCAN

AC_SCN:	ld	a,(PUT_BUFER)	;Envio de Reject:
	cp	4	;Se envia directamente
	jr	z,AC_SCAN

	ld	a,(FAIL_CNT)	;Envio de Nak: comprobamos FAIL_CNT
	ld	hl,MAX_FAIL_CNT_V
	cp	(hl)
	jr	nc,AC_SCN3

AC_SCN2:	inc	a	;Si no se ha llegado a Max Failure,
	ld	(FAIL_CNT),a	;se incrementa el FAIL_CNT
	jr	AC_SCAN	;y se envia el Nak previsto

AC_SCN3:	ld	a,4	;Si se supera Max Failure,
	ld	(PUT_BUFER),a	;se envia Reject en vez de Nak

AC_SCAN:	ld	hl,PUT_BUFER
	jp	PUT_XCP	;Suponemos que siempre se envia bien

	;--- Send-terminate-request

AC_STR:	ld	b,5
	ld	hl,LCP_ID_TR
	inc	(hl)	;Siempre incrementa identificador
	ld	a,(LCP_ID_TR)
AC_STR2:	ld	hl,RST_COUNT
	ld	c,a
	ld	a,(hl)
	or	a
	ld	a,c
	jr	z,AC_STR3
	dec	(hl)
AC_STR3:	;ld      hl,(RST_TIMER_V)
	;ld      (RST_TIMER),hl
	ld	ix,PUT_BUFER
	ld	(ix),b	;5 para Req, 6 para Ack
	ld	(ix+1),a
	ld	(ix+2),0
	ld	(ix+3),4
	ld	hl,PUT_BUFER
	jp	PUT_XCP	;Suponemos que siempre se envia bien

	;--- Send-terminate-ack

AC_STA:	ld	b,6
	ld	hl,LCP_ID_TA
	inc	(hl)	;Siempre incrementa identificador
	ld	a,(LCP_ID_TA)
	jr	AC_STR2

	;--- Send-code-reject

AC_SCJ:	ld	hl,LCP_ID_CX	;Siempre incrementa id
	inc	(hl)

	ld	hl,GET_BUFER	;Copia paquete de GET_BUFER
	ld	de,PUT_BUFER+4	;a PUT_BUFER
	ld	a,(GET_BUFER+2)
	and	%00000111
	ld	b,a
	ld	a,(GET_BUFER+3)
	ld	c,a
	ldir

	ld	ix,PUT_BUFER	;Anyade la cabecera de Code Reject
	ld	(ix),7
	ld	a,(LCP_ID_CX)
	ld	(ix+1),a
	inc	bc	;Tamanyo=paquete original+4
	inc	bc
	inc	bc
	inc	bc
	ld	(ix+2),b
	ld	(ix+3),c

	ld	hl,PUT_BUFER
	jp	PUT_XCP	;Suponemos que siempre se envia bien

	;--- Send-echo-reply

AC_SER:	ld	hl,PUT_BUFER
	ld	(hl),10	;Cambia a codigo echo-reply
	jp	PUT_XCP	;Suponemos que siempre se envia bien



;************************************************
;**                                            **
;**   RUTINAS DE ENVIO/RECEPCION DE PAQUETES   **
;**                                            **
;************************************************


;--- PUT_HDLC: Envia un paquete con framing HDLC
;              (lo mete en la cola OUT_QUEUE)
;    Entrada: HL=Direccion, BC=Longitud, DE=Protocolo
;             Si BC=0, se asume que la longitud esta en (HL+2) en big indian
;             Debe tener 2 bytes 0 al final para el FCS
;             y otros dos al principio para el protocolo
;    BYTE_PUT:  ha de ser una rutina que devuelva un byte a ser enviado
;    ESC_O_TAB: mapa de caracteres que hemos de enviar escapados
;               (un byte por caracter, #FF si escapado, 0 si no,
;                el primer byte corresponde al caracter 0)
;    ADDCMP_O: debe ser #FF si el envio de cabeceras HDLC comprimidas
;                  (sin los bytes #FF y 3 iniciales) por nuestra parte
;                  ya ha sido negociado con exito
;    PROTCMP_O: debe ser #FF si el envio del campo de protocolo comprimido
;                   por nuestra parte ya ha sido negociado con exito

PUT_HDLC:	ld	a,b
	or	c
	jr	nz,OKHDLCSIZE
	push	hl
	pop	ix
	ld	b,(ix+2)
	ld	c,(ix+3)
OKHDLCSIZE:	;

	ld	ix,QUEUE_BUFER

	;--- Inserta el protocolo, comprimido si hace falta

	dec	hl	;Inserta byte bajo
	inc	bc
	ld	(hl),e

	ld	a,(PROTCMP_O)	;Decide si se ha de insertar
	cp	#FF	;tambien el byte alto
	jr	nz,PUT_HDLC2
	ld	a,d
	or	a
	jr	z,PUT_HDLC3

PUT_HDLC2:	dec	hl	;Inserta byte alto
	inc	bc
	ld	(hl),d

PUT_HDLC3:	ld	(PHDLC_DIR),hl

	;--- Calcula FCS y lo inserta al final del paquete

	ld	a,(ADDCMP_O)	;Decide FCS inicial
	cp	#FF	;segun si comprimimos dir+control o no
	ld	de,#FFFF
	jr	z,PUT_HDLC4
	ld	de,#3DE3
PUT_HDLC4:	;

	push	hl,bc,ix	;Calcula FCS y lo inserta
	call	CALC_FCS
	pop	ix,bc,hl
	add	hl,bc
	ld	a,e
	cpl
	ld	(hl),a
	inc	hl
	ld	a,d
	cpl
	ld	(hl),a

	inc	bc
	inc	bc
	ld	(PHDLC_LON),bc

	;--- Envia cabecera HDLC

	ld	a,#7E	;Envia flag HDLC y cabecera dir+ctrl
	call	BYTE_PUT	;si no se comprime
	ld	a,(ADDCMP_O)
	cp	2
	jr	z,PUT_HDLC5
	ld	a,#FF
	call	BYTE_PUT
	ld	a,#7D
	call	BYTE_PUT
	ld	a,3 xor #20
	call	BYTE_PUT
PUT_HDLC5:	;

	;--- Bucle de envio de los datos

	ld	bc,(PHDLC_LON)
	ld	hl,(PHDLC_DIR)

PHDLC_LOOP:	ld	a,(hl)
	push	hl,bc
	cp	#7D
	jr	z,PHDLC_LOP1
	cp	#7E
	jr	z,PHDLC_LOP1
	cp	32
	jr	nc,PHDLC_LOP2
	ld	d,a
	ld	c,a
	ld	b,0
	ld	hl,ESC_O_TAB
	add	hl,bc
	ld	a,(hl)
	or	a
	ld	a,d
	jr	z,PHDLC_LOP2
PHDLC_LOP1:	push	af
	ld	a,#7D
	call	BYTE_PUT
	pop	af
	xor	#20
PHDLC_LOP2:	call	BYTE_PUT
	pop	bc,hl
	inc	hl
	dec	bc
	ld	a,b
	or	c
	jr	nz,PHDLC_LOOP

	;--- Envia el flag de finalizacion

	ld	a,#7E
	call	BYTE_PUT

	;--- Todo enviado: encola el paquete

	push	ix
	pop	hl
	ld	bc,QUEUE_BUFER
	or	a
	sbc	hl,bc	;Calcula longitud paquete

	ld	a,(#8002)
	ld	b,a
	ld	a,(OUT_QUEUE)
	ld	ix,(OUT_QUEUE+1)
	set	7,h
	set	6,h
	ld	iy,QUEUE_BUFER
	nesman	28	;Inserta paquete y termina

	ret

	;--- Almacenamiento de byte para posterior encolamiento

BYTE_PUT:	ld	(ix),a
	inc	ix
	ret

	;--- Variables

PHDLC_DIR:	dw	0
PHDLC_LON:	dw	0
PHDLC_PROT:	dw	0


;--- PUT_XCP
;    Envia un paquete LCP/IPCP. Si el codigo es 1 a 7, establece temporalmente
;    la configuracion por defecto para async-map y add/prot-cmp antes
;    de enviarlo; si no, salta directamente a PUT_HDLC.
;    Si el paquete es IPCP, siempre lo envia sin mas.
;    Entrada: HL = Direccion paquete
;             Debe tener 2 bytes 0 al final para el FCS
;             y otros dos al principio para el protocolo
;    Salida:  A = 0:   Paquete enviado OK
;                 #FF: El nivel fisico no esta disponible
;                 #80: No se pueden enviar datos

PUT_XCP:	ld	a,(CLOSE_PENDING)	;No envia nada si se ha
	or	a	;detectado una condicion
	jr	nz,PUT_XCP0	;de "loop-back"
	ld	a,(CLOSE_ERROR)
	cp	3
	ld	a,0
	ret	z

PUT_XCP0:	ld	a,(AUTOM_IS_IPCP)
	or	a
	jr	nz,PUT_IPCP_END

	ld	a,(hl)
	or	a
	jr	z,PUT_LCP_END
	cp	8
	jr	nc,PUT_LCP_END

	;--- Guarda parametros y establece por defecto

	push	hl
	pop	ix

	ld	hl,(ESC_O_TABR)
	push	hl
	ld	hl,(ESC_O_TABR+2)
	push	hl
	ld	hl,(ADDCMP_O)	;ADDCMP_O+PROTCMP_O estan consecutivas
	push	hl

	ld	hl,#FFFF
	ld	(ESC_O_TABR),hl	;Establece config por defecto
	ld	(ESC_O_TABR+2),hl
	inc	hl
	ld	(ADDCMP_O),hl
	ld	hl,ESC_O_TABR
	ld	de,ESC_O_TAB
	call	ASYNC_SET

	;--- Envia paquete y recupera parametros anteriores

	push	ix
	pop	hl
	call	PUT_LCP_END	;Envia el paquete

	pop	hl	;Recupera configuracion
	ld	(ADDCMP_O),hl
	pop	hl
	ld	(ESC_O_TABR+2),hl
	pop	hl
	ld	(ESC_O_TABR),hl

	push	af
	ld	hl,ESC_O_TABR
	ld	de,ESC_O_TAB
	call	ASYNC_SET
	pop	af	;Termina
	ret

	;--- Envio del paquete en HL

PUT_LCP_END:	ld	bc,0	;Paquete LCP
	ld	de,#C021
	jp	PUT_HDLC

PUT_IPCP_END:	ld	bc,0	;Paquete IPCP
	ld	de,#8021
	jp	PUT_HDLC

HDLC_SIZE:	dw	0


;--- GET_HDLC
;--- Rutina de obtencion de un paquete PPP envuelto en una trama HDLC
;--- Por Nestor Soriano (Konami Man), 2-6-2001
;
;    Esta rutina obtiene bytes del nivel fisico y los almacena en un bufer
;hasta encontrar un flag HDLC de finalizacion. Devuelve un error si la trama
;no es correcta (por ejemplo si el FCS es invalido). Si es correcta, devuelve
;la trama PPP recibida (protocolo + informacion + relleno) y su longitud.
;
;    La rutina esta pensada para ejecutarse en una interrupcion del reloj.
;Las variables MAX_BADBYTES y MAX_BAD_REACHED ayudan a controlar que no se
;use demasiado tiempo en la ejecucion de esta rutina.
;
;    * Entrada:
;    LOWER_RDY: ha de ser una rutina que devuelva Cy=1 si el nivel fisico esta
;               disponible, 0 en caso contrario
;    BYTE_IN:   ha de ser una rutina que lea un byte del nivel fisico y lo
;               devuelva en A
;    BYTE_I_RDY:  ha de ser una rutina que devuelva Cy=1 si hay bytes de entrada
;               disponibles desde el nivel fisico, 0 en caso contrario
;               o si el nivel fisico no esta disponible
;    MAX_BADBYTES: numero maximo de bytes correspondientes a tramas erroneas
;                  que deberian cogerse en una misma interrupcion
;    ADDCMP_I: debe ser #FF si el envio de cabeceras HDLC comprimidas
;                  (sin los bytes #FF y 3 iniciales) por parte del host remoto
;                  ya ha sido negociado con exito
;    PROTCMP_I: debe ser #FF si el envio del campo de protocolo comprimido
;                   por parte del host remoto ya ha sido negociado con exito
;    MRU: Maximum Receive Unit, almacenado con exceso 4 para dejar espacio
;         para el protocolo y el FCS
;    ESC_I_TAB: mapa de caracteres que necesitamos recibir escapados
;               (un byte por caracter, #FF si escapado, 0 si no,
;                el primer byte corresponde al caracter 0)
;    HL = Direccion del bufer donde depositar la trama recogida.
;         Si hay un paquete pendiente (bueno o malo), se ignora HL
;         y se usa el bufer de la ejecucion anterior
;
;    * Salida:
;    HL = Direccion de la trama recogida (si no hay error),
;         es el mismo valor especificado en la entrada
;    BC = Longitud de la trama recogida (si no hay error)
;         Incluye protocolo+informacion+relleno pero no el FCS,
;         aunque esta al final de la trama
;    A  = Codigo de error:
;         0 = No hay error, el paquete recibido es correcto
;         #80 = Hay un paquete (a priori correcto) a medio recoger
;               pero de momento no hay mas bytes disponibles
;         #81 = Hay un paquete erroneo a medio recoger
;               (demasiado largo o con la cabecera HDLC incorrecta)
;               pero de momento no hay mas bytes disponibles
;         1 = Trama demasiado pequenya (menos de 3 bytes si el protocolo
;             esta comprimido, menos de 4 si no lo esta)
;         2 = Se han recibido demasiados flags HDLC consecutivos
;             (los flags HDLC se consideran paquetes erroneos de un byte
;              pero solo devuelven error si se sobrepasa MAX_BADBYTES)
;         3 = Cabecera HDLC invalida (la trama empieza con #FF #xx, donde
;             xx no es 3), pero la trama ya se ha recibido entera
;             (en caso contrario el error devuelto es #81)
;         4 = Se ha recibido un codigo de escape seguido de un flag HDLC
;         5 = La trama es mayor que MRU (pero ya se ha recibido entera,
;             en caso contrario el error devuelto es #81)
;         6 = Cabecera HDLC comprimida cuando esa opcion (aun) no se ha
;             negociado con el host remoto
;         7 = Protocolo comprimido cuando esa opcion (aun) no se ha
;             negociado con el host remoto
;         8 = Protocolo mal formado (es de dos bytes y el LSB del segundo
;             no es 0)
;         9 = FCS invalido
;         #FF = El nivel fisico no esta disponible
;    D = 0   si el numero de bytes correspondientes a tramas erroneas recogidos
;            es inferior a MAX_BADBYTES. Entonces deberia intentarse coger otra
;            trama (ejecutar GET_HDLC de nuevo) en la interrupcion en curso.
;        #FF si el numero de bytes correspondientes a tramas erroneas recogidos
;            es igual o superior a MAX_BADBYTES. Entonces no deberia volver
;            a ejecutarse GET_HDLC en la interruopcion en curso.
;            D=#FF siempre cuando A=0 (no hay error).

HDLC_ESC:	equ	#7D
HDLC_FLAG:	equ	#7E


;----------------------------
;---  PROGRAMA PRINCIPAL  ---
;----------------------------

GET_HDLC:	ld	a,(PACK_PEND)	;Paquete pendiente?
	or	a
	jr	nz,GET_PEND
	ld	a,(PACK_BADPEND)
	or	a
	jp	nz,GET_BPEND

;--- Coger paquete nuevo

	ld	(GHDLC_BUF),hl
	ld	(GHDLC_BUF_PNT),hl
	xor	a
	ld	(IN_ESC),a
	ld	(COMPROTO),a
	inc	a
	ld	(IN_HEAD),a
	ld	hl,0
	ld	(BUF_COUNT),hl

;--- Coger paquete pendiente (a priori valido)

GET_PEND:	call	BYTE_I_RDY
	jr	c,GET_PEND3
	call	LOWER_RDY
	jr	c,GET_PEND2
	xor	a
	ld	hl,0
	ld	(PACK_BADBYTES),hl
	ld	(PACK_PEND),a
	ld	(PACK_BADPEND),a
	ld	a,#FF	;Termina si el nivel fisico
	ret		;                ;no esta disponible

GET_PEND2:	ld	a,#FF	;Termina si no hay datos disponibles
	ld	(PACK_PEND),a
	ld	a,#80
	ret

GET_PEND3:	call	BYTE_IN	;Flag de finalizacion?
	cp	HDLC_FLAG
	jp	z,PACK_COMPLETE

	ld	b,a
	ld	a,(IN_ESC)	;Caracter escapado?
	or	a
	ld	a,b
	jr	z,GET_PEND4

	ld	hl,IN_ESC	;Convertir caracter escapado
	ld	(hl),0
	xor	#20
	jp	BYTE_OK

GET_PEND4:	cp	#20
	jr	nc,CHKESC

	ld	hl,ESC_I_TAB
	ld	c,a
	ld	b,0
	add	hl,bc
	ld	a,(hl)	;Hay que descartar el caracter por estar
	or	a	;en la lista de escapados?
	ld	a,c
	jr	nz,GET_PEND

CHKESC:	cp	HDLC_ESC
	jr	nz,BYTE_OK
	ld	hl,IN_ESC
	ld	(hl),1
	jr	GET_PEND

BYTE_OK:	ld	e,a
	ld	hl,IN_HEAD
	ld	a,(hl)	;Deberia ser el primer byte de cabecera?
	ld	(hl),0
	cp	1	;Si es #FF, en efecto lo es; si no,
	jr	nz,INH2	;la cabecera esta comprimida
INH1:	ld	hl,ADDCOMP_I_NOW
	ld	a,e
	cp	#FF
	jr	z,INH11
	ld	(hl),#FF
	jr	BYTE_OK2
INH11:	ld	(hl),0
	ld	a,2
	ld	(IN_HEAD),a
	jr	GET_PEND

INH2:	cp	2	;Deberia ser el segundo byte de cabecera?
	jr	nz,BYTE_OK2	;Si es 3, en efecto lo es; si no,
	ld	a,e	;el paquete es erroneo
	cp	3
	jr	z,GET_PEND
	ld	hl,(PACK_BADBYTES)
	inc	hl
	inc	hl
	ld	(PACK_BADBYTES),hl
	ld	a,#FF
	ld	(PACK_BADPEND),a
	ld	a,3
	ld	(BADHEAD),a
	jp	GET_BPEND

BYTE_OK2:	push	de
	ld	hl,(GHDLC_BUF_PNT)	;Si es el primer byte a coger,
	ld	de,(GHDLC_BUF)	;se refiere al protocolo.
	call	COMP	;Si esta comprimido, insertamos
	pop	de	;nosotros un 0 al principio.
	jr	nz,BYTE_OK3
	bit	0,e
	jr	z,BYTE_OK3
	ld	(hl),0
	inc	hl
	ld	(GHDLC_BUF_PNT),hl
	ld	hl,(BUF_COUNT)
	inc	hl
	ld	(BUF_COUNT),hl
	ld	a,#FF
	ld	(COMPROTO),a

BYTE_OK3:	ld	a,e	;Dato correcto: lo introduce en el bufer
	ld	hl,(GHDLC_BUF_PNT)
	ld	(hl),a	;y actualiza el puntero y el contador
	inc	hl
	ld	(GHDLC_BUF_PNT),hl
	ld	hl,(BUF_COUNT)
	inc	hl
	ld	(BUF_COUNT),hl

	ld	de,(MRU)	;Si se sobrepasa el MRU, el paquete
	dec	hl
	call	COMP	;es demasiado grande. Entonces se
	jp	nc,GET_PEND	;actualiza PACK_BADBYTES y se devuelve
	ld	hl,(PACK_BADBYTES)
	add	hl,de	;el error #81.
	ld	(PACK_BADBYTES),hl
	ld	hl,PACK_BADPEND
	ld	(hl),#FF
	call	SET_MAXBR
	ld	a,5
	ld	(BADHEAD),a
	ld	a,#81
	ret

;--- Se ha cogido un paquete completo

PACK_COMPLETE:	xor	a
	ld	(PACK_PEND),a
	ld	(PACK_BADPEND),a

	ld	hl,(BUF_COUNT)	;Si la longitud del paquete es 0,
	ld	a,h	;es que se ha cogido un paquete vacio.
	or	l	;Entonces se intenta coger otro,
	jr	nz,PCOMPLETE2	;a no ser que ya se hayan cogido
	ld	de,(PACK_BADBYTES)
	inc	de	;demasiados (mas flags que MAX_BADBYTES)
	ld	(PACK_BADBYTES),de
	ld	hl,(MAX_BADBYTES)
	call	COMP
	jp	c,GET_PEND
	call	SET_MAXBR
	ld	a,2
	ret

PCOMPLETE2:	ld	de,3
	ld	hl,(GHDLC_BUF)
	bit	0,(hl)
	jr	nz,PCOMPLETE3
	ld	de,4

PCOMPLETE3:	ld	hl,(BUF_COUNT)	;Si trama menor de 3 bytes y el
	call	COMP	;protocolo esta comprimido, o menor de
	jr	c,OKPSIZE	;4 bytes y no comprimido, error 1

BADPSIZE:	call	ADD_BAD_COUNT
	call	SET_MAXBR
	ld	a,1
	ret
OKPSIZE:	;

	ld	a,(IN_ESC)	;Error si hay secuencia de escape
	or	a	;no balanceada
	jr	z,OKINESC
	call	ADD_BAD_COUNT
	call	SET_MAXBR
	ld	a,4
	ret
OKINESC:	;

	ld	a,(ADDCOMP_I_NOW)	;Comprueba el FCS y devuelve error
	or	a	;9 si es invalido
	ld	de,#FFFF
	jr	nz,DO_FCS
	ld	de,#3DE3	;#3DE3 = FCS de "#FF #03"
DO_FCS:	ld	hl,(GHDLC_BUF)
	ld	bc,(BUF_COUNT)
	ld	a,(COMPROTO)
	or	a
	jr	z,DO_FCS2
	inc	hl
	dec	bc
DO_FCS2:	call	CALC_FCS
	ld	hl,#F0B8	;#F0B8 = FCS de una trama correcta
	call	COMP
	jr	z,OK_FCS
	call	ADD_BAD_COUNT
	call	SET_MAXBR
	ld	a,9
	ret
OK_FCS:	;

	ld	a,(ADDCOMP_I_NOW)
	or	a
	jr	z,OKADDCMP
	ld	a,(ADDCMP_I)
	cp	#FF	;Error si la cabecera HDLC esta comprimida
	jr	z,OKADDCMP	;pero esa opcion no se ha negociado
	call	ADD_BAD_COUNT
	call	SET_MAXBR
	ld	a,6
	ret
OKADDCMP:	;

	ld	a,(COMPROTO)
	or	a
	jr	z,PCOMP1
	ld	a,(PROTCMP_I)
	cp	#FF
	jr	z,PCOMP2
	call	ADD_BAD_COUNT	;Error si el protocolo esta comprimido
	call	SET_MAXBR	;pero esa opcion no se ha negociado
	ld	a,7
	ret
PCOMP1:	inc	hl
	bit	0,(hl)
	jr	nz,PCOMP2
	call	ADD_BAD_COUNT	;Error si el protocolo esta mal formado
	call	SET_MAXBR	;(de 2 bytes pero el segundo no tiene
	ld	a,8	;LSB=0)
	ret
PCOMP2:	;

	ld	hl,(GHDLC_BUF)	;No hay mas errores posibles:
	ld	bc,(BUF_COUNT)	;devolver OK.
	dec	bc	;Se resta 2 al tamanyo para no
	dec	bc	;contar el FCS
	ld	a,#FF
	ld	(MAX_BAD_REACHED),a
	ld	d,a
	xor	a
	ld	hl,0
	ld	(PACK_BADBYTES),hl
	ld	hl,(GHDLC_BUF)
	ret

;--- Coge el resto de un paquete invalido (demasiado largo o con
;    cabecera invalida)

GET_BPEND:	ld	bc,0
	ld	(BUF_COUNT),bc

GET_BP2:	call	BYTE_I_RDY
	jr	c,GET_BP4
	call	LOWER_RDY
	jr	c,GET_BP3
	xor	a
	ld	hl,0
	ld	(PACK_BADBYTES),hl
	ld	(PACK_PEND),a
	ld	(PACK_BADPEND),a
	ld	a,#FF	;Termina si el nivel fisico
	ret		;                ;no esta disponible

GET_BP3:	ld	a,#81	;Termina si no hay datos disponibles
	ret

GET_BP4:	call	BYTE_IN	;Coge dato, y si no es flag de fin
	cp	HDLC_FLAG	;de paquete, comprueba si puede coger
	jr	z,GET_BP5	;mas datos o devolver un error #81
	ld	de,(BUF_COUNT)
	inc	de
	ld	(BUF_COUNT),de
	ld	hl,(MAX_BADBYTES)
	call	COMP
	jr	c,GET_BP2
	call	SET_MAXBR
	ld	a,#81
	ret

GET_BP5:	call	ADD_BAD_COUNT	;Si es flag de fin, devuelve
	xor	a	;error adecuado (3 o 5)
	ld	(PACK_BADPEND),a
	call	SET_MAXBR
	ld	a,(BADHEAD)
	ret


;--------------------
;---  SUBRUTINAS  ---
;--------------------

;--- SET_MAXBR: Pone MAX_BAD_REACHED a #FF si PACK_BADBYTES>=MAX_BADBYTES
;               y pone PACK_BADBYTES a 0; si no, pone MAX_BAD_REACHED a 0.
;               Devuelve MAX_BAD_REACHED en D.

SET_MAXBR:	ld	hl,(PACK_BADBYTES)
	ld	de,(MAX_BADBYTES)
	call	COMP
	jr	nc,RESET_MAXBR
	ld	a,#FF
	ld	(MAX_BAD_REACHED),a
	ld	d,a
	ld	hl,0
	ld	(PACK_BADBYTES),hl
	ret
RESET_MAXBR:	xor	a
	ld	(MAX_BAD_REACHED),a
	ld	d,a
	ret


;--- ADD_BUF_BAD: Suma el valor de BUF_COUNT a PACK_BADBYTES

ADD_BUF_BAD:	ld	hl,(PACK_BADBYTES)
	ld	de,(BUF_COUNT)
	add	hl,de
	ld	(PACK_BADBYTES),hl
	ret


;--- ADD_BAD_COUNT: Suma el valor de BUF_COUNT al de PACK_BADBYTES

ADD_BAD_COUNT:ld	hl,(PACK_BADBYTES)
	ld	de,(BUF_COUNT)
	add	hl,de
	ld	(PACK_BADBYTES),hl
	ret


;--- CALCFCS: Calculo de FCS de 16 bits
;    Entrada: HL = Direccion
;             DE = FCS previo
;             BC = Longitud
;    Salida:  DE = Nuevo FCS (sin complementar)
;    Modifica AF, IX

;Implementa la funcion de C:
;           while   (len--)
;               fcs = (fcs >> 8) ^ fcstab[(fcs ^ *cp++) & #ff] ;
;           return  (fcs)

CALC_FCS:	push	bc	;BC = "len"

	ld	a,(hl)	;A = "*cp"
	inc	hl	;"cp ++"

	xor	e	;A = "fcs ^ *cp"

	ld	c,a
	ld	b,0
	ld	ix,FCSTAB
	add	ix,bc
	add	ix,bc
	ld	c,(ix)
	ld	b,(ix+1)	;BC = "fcstab[(fcs ^ *cp)]"

	ld	e,d
	ld	d,0	;DE = "(fcs >> 8)"

	ld	a,e
	xor	c
	ld	e,a
	ld	d,b	;DE = "(fcs>>8) ^ fcstab[(fcs ^ *cp)]"

	pop	bc
	dec	bc	;"len--"
	ld	a,b
	or	c
	jr	nz,CALC_FCS	;"} while(len)"

	ret

FCSTAB:
	dw	#0000,#1189,#2312,#329b,#4624,#57ad,#6536,#74bf
	dw	#8c48,#9dc1,#af5a,#bed3,#ca6c,#dbe5,#e97e,#f8f7
	dw	#1081,#0108,#3393,#221a,#56a5,#472c,#75b7,#643e
	dw	#9cc9,#8d40,#bfdb,#ae52,#daed,#cb64,#f9ff,#e876
	dw	#2102,#308b,#0210,#1399,#6726,#76af,#4434,#55bd
	dw	#ad4a,#bcc3,#8e58,#9fd1,#eb6e,#fae7,#c87c,#d9f5
	dw	#3183,#200a,#1291,#0318,#77a7,#662e,#54b5,#453c
	dw	#bdcb,#ac42,#9ed9,#8f50,#fbef,#ea66,#d8fd,#c974
	dw	#4204,#538d,#6116,#709f,#0420,#15a9,#2732,#36bb
	dw	#ce4c,#dfc5,#ed5e,#fcd7,#8868,#99e1,#ab7a,#baf3
	dw	#5285,#430c,#7197,#601e,#14a1,#0528,#37b3,#263a
	dw	#decd,#cf44,#fddf,#ec56,#98e9,#8960,#bbfb,#aa72
	dw	#6306,#728f,#4014,#519d,#2522,#34ab,#0630,#17b9
	dw	#ef4e,#fec7,#cc5c,#ddd5,#a96a,#b8e3,#8a78,#9bf1
	dw	#7387,#620e,#5095,#411c,#35a3,#242a,#16b1,#0738
	dw	#ffcf,#ee46,#dcdd,#cd54,#b9eb,#a862,#9af9,#8b70
	dw	#8408,#9581,#a71a,#b693,#c22c,#d3a5,#e13e,#f0b7
	dw	#0840,#19c9,#2b52,#3adb,#4e64,#5fed,#6d76,#7cff
	dw	#9489,#8500,#b79b,#a612,#d2ad,#c324,#f1bf,#e036
	dw	#18c1,#0948,#3bd3,#2a5a,#5ee5,#4f6c,#7df7,#6c7e
	dw	#a50a,#b483,#8618,#9791,#e32e,#f2a7,#c03c,#d1b5
	dw	#2942,#38cb,#0a50,#1bd9,#6f66,#7eef,#4c74,#5dfd
	dw	#b58b,#a402,#9699,#8710,#f3af,#e226,#d0bd,#c134
	dw	#39c3,#284a,#1ad1,#0b58,#7fe7,#6e6e,#5cf5,#4d7c
	dw	#c60c,#d785,#e51e,#f497,#8028,#91a1,#a33a,#b2b3
	dw	#4a44,#5bcd,#6956,#78df,#0c60,#1de9,#2f72,#3efb
	dw	#d68d,#c704,#f59f,#e416,#90a9,#8120,#b3bb,#a232
	dw	#5ac5,#4b4c,#79d7,#685e,#1ce1,#0d68,#3ff3,#2e7a
	dw	#e70e,#f687,#c41c,#d595,#a12a,#b0a3,#8238,#93b1
	dw	#6b46,#7acf,#4854,#59dd,#2d62,#3ceb,#0e70,#1ff9
	dw	#f78f,#e606,#d49d,#c514,#b1ab,#a022,#92b9,#8330
	dw	#7bc7,#6a4e,#58d5,#495c,#3de3,#2c6a,#1ef1,#0f78

	endif


;-------------------
;---  VARIABLES  ---
;-------------------

GHDLC_BUF:	dw	0	;Direccion del bufer de trama
PACK_BADBYTES:dw	0		;Contador de bytes erroneos
MAX_BAD_REACHED:	db	0	;#FF si se supera MAX_BADBYTES
PACK_BADPEND:	db	0	;-1 si hay un paquete erroneo pendiente
PACK_PEND:	db	0	;-1 si hay un paquete erroneo pendiente
GHDLC_BUF_PNT:dw	0		;Puntero del bufer de trama
BUF_COUNT:	dw	0	;Contador de bytes en el bufer de trama
IN_ESC:	db	0	;-1 si el ultimo caracter recogido es ESC
IN_HEAD:	db	0	;1 o 2 si estamos cogiendo la cabecera HDLC
ADDCOMP_I_NOW:	db	0	;-1 si la trama tiene la cabecera comp.
BADHEAD:	db	0	;Error 3 o 5 a devolver por GET_BPEND
COMPROTO:	db	0	;-1 si el protocolo estaba comprimido


;*********************************
;***                           ***
;***   RUTINAS DE CAPA FISICA  ***
;***                           ***
;*********************************

LOWER_RDY:	;push    bc,de,hl,ix,iy
	ld	ix,LOW_CHK_TLU
	call	CALL_LOWER
	;pop     iy,ix,hl,de,bc
	ret

BYTE_IN:	;push    bc,de,hl,ix,iy
	ld	ix,LOW_BYTE_IN
	call	CALL_LOWER
	;pop     iy,ix,hl,de,bc
	ret

BYTE_I_RDY:	;push    bc,de,hl,ix,iy
	ld	ix,LOW_RDY_RCV
	call	CALL_LOWER
	;pop     iy,ix,hl,de,bc
	ret

ASK_LOWER_START:	ld	ix,LOW_OPEN
	jr	CALL_LOWER

ASK_LOWER_END:	ld	ix,LOW_CLOSE
	;jr      CALL_LOWER

CALL_LOWER:	push	af
	ld	a,(LOWER_SEG)
	or	a
	jr	z,CALL_LOW_NO
	ld	iyh,a
	pop	af
	call	CAL_SEG
	ret
CALL_LOW_NO:	pop	af
	ret

CALL_UPPER:	push	af
	ld	a,(UPPER_SEG)
	or	a
	jr	z,CALL_UP_NO
	ld	iyh,a
	pop	af
	call	CAL_SEG
	ret
CALL_UP_NO:	pop	af
	ret



;********************************************
;**                                        **
;**   RUTINAS DE GESTION DE PAQUETES LCP   **
;**                                        **
;********************************************

;--- MAKE_CONFREQ: Construye un paquete Configure Request
;                  en base a las variables de configuracion
;                  (para LCP o IPCP)
;    Entrada: constantes de configuracion establecidas adecuadamente:
;             MRU, ADDCMP_O_NEG, PROTCMP_O_NEG, ESC_I_TABR, LQR_O_NEG,
;             MAGIC_O_NEG, MAX_LQR_TIME
;             Identificador en LCP_ID
;    HL = Direccion del bufer donde dejar el paquete
;    Salida:  Paquete en HL (preservado), BC=Longitud
;             Si el paquete ha de contener un magic number,
;             se genera uno si MAGIC_O es 0, y se pone MAGIC_O a #FF
;             Establece ESC_I_TAB segun ESC_I_TABR

MAKE_CONFREQ:	ld	(MKCR_DIR),hl
	push	hl
	pop	ix
	ld	(ix),1	;Codigo de ConfReq=1
	inc	ix
	ld	a,(LCP_ID_CR)
	ld	(ix),a	;Identificador
	inc	ix
	inc	ix
	inc	ix	;La longitud la pondremos al final
	ld	bc,4	;Longitud minima=4

	ld	a,(AUTOM_IS_IPCP)
	or	a	;Hay que negociar opciones IPCP?
	jp	nz,MAKE_CONFR_IPCP

	;--- MRU: Se negocia si no es 1500

	ld	hl,(MRU)
	ld	de,1504
	call	COMP
	jr	z,MKCFRQ1

	dec	hl	;MRU esta almacenado con exceso 4
	dec	hl
	dec	hl
	dec	hl
	ld	(ix),1	;Codigo de MRU
	ld	(ix+1),4	;Longitud opcion=4
	ld	(ix+2),h	;Establece MRU
	ld	(ix+3),l
	ld	a,4
	call	ADD_IXBC	;Aumenta longitud en 4
MKCFRQ1:	;

	;--- ASYNC_MAP: Se negocia si no es #FFFFFFFF

	push	bc
	ld	hl,ESC_I_TABR
	ld	de,ESC_I_TAB
	call	ASYNC_SET
	pop	bc

	push	ix
	ld	ix,ESC_I_TABR
	ld	a,(ix)
	and	(ix+1)
	and	(ix+2)
	and	(ix+3)
	pop	ix
	inc	a
	jr	z,MKCFRQ2

	ld	(ix),2	;Codigo de Async Map
	ld	(ix+1),6	;Longitud opcion=6
	ld	hl,(ESC_I_TABR)
	ld	de,(ESC_I_TABR+2)
	ld	(ix+2),l
	ld	(ix+3),h
	ld	(ix+4),e
	ld	(ix+5),d
	ld	a,6
	call	ADD_IXBC
MKCFRQ2:	;

	;--- Quality protocol: se negocia si LQR_O_NEG<>0

	jr	MKCFRQ3	;*** EN PRUEBAS: No se negocia nunca

	;ld      a,(LQR_O_NEG)
	or	a
	jr	z,MKCFRQ3

	ld	(ix),4	;Codigo de Quality Protocol
	ld	(ix+1),8	;Longitud opcion=8
	ld	(ix+2),#C0	;Codigo del protocolo LQR=#C025
	ld	(ix+3),#25
	;ld      hl,(MAX_LQR_TIME+2)
	;ld      de,(MAX_LQR_TIME)
	ld	(ix+4),l
	ld	(ix+5),h
	ld	(ix+6),e
	ld	(ix+7),d
	ld	a,8
	call	ADD_IXBC
MKCFRQ3:	;

	;--- Magic Number: se negocia si MAGIC_O_NEG<>0
	;    Si MAGIC_O es #FF, se asume que el numero ya esta
	;    creado en MAGIC_LOCAL; si no, se crea uno nuevo

	ld	a,(MAGIC_O_NEG)
	or	a
	jr	z,MKCFRQ4

	ld	a,(MAGIC_O)	;Hay que crear magic?
	or	a
	jr	nz,MKCFRQ40
	push	bc
	call	MAKE_MAGIC
	pop	bc
	ld	a,#FF
	ld	(MAGIC_O),a

MKCFRQ40:	ld	(ix),5	;Codigo de Magic Number
	ld	(ix+1),6	;Longitud opcion=6
	ld	hl,(MAGIC_LOCAL)
	ld	de,(MAGIC_LOCAL+2)
	ld	(ix+2),l
	ld	(ix+3),h
	ld	(ix+4),e
	ld	(ix+5),d
	ld	a,6
	call	ADD_IXBC
	ld	a,#FF
	ld	(MAGIC_O),a
MKCFRQ4:	;

	;--- Protocol field compression:
	;    Se negocia si PROTCMP_O_NEG<>0

	ld	a,(PROTCMP_O_NEG)
	or	a
	jr	z,MKCFRQ5

	ld	(ix),7	;Codigo de Prot. Field Compression
	ld	(ix+1),2	;Longitud opcion=2
	inc	ix
	inc	ix
	inc	bc
	inc	bc
MKCFRQ5:	;

	;--- Address and control field compression:
	;    Se negocia si ADDCMP_O_NEG<>0

	ld	a,(ADDCMP_O_NEG)
	or	a
	jr	z,MKCFRQ6

	ld	(ix),8	;Codigo de Add. Field Compression
	ld	(ix+1),2	;Longitud opcion=2
	inc	ix
	inc	ix
	inc	bc
	inc	bc
MKCFRQ6:	jr	MAKE_CONF_OK

MAKE_CONFR_IPCP:			;

	;--- Direccion IP local (IPCP)

	ld	hl,(IP_LOCAL)
	ld	de,(IP_LOCAL+2)
	ld	a,3
	call	MAKE_CONF_IP

	;--- Servidores DNS (IPCP)

CHK_NDNSP:	ld	a,(NEG_DNS_PRIM)
	or	a
	jr	z,CHK_NDNSS

	ld	hl,(DNS_PRIM)	;DNS primario
	ld	de,(DNS_PRIM+2)
	ld	a,129
	call	MAKE_CONF_IP

CHK_NDNSS:	ld	a,(NEG_DNS_SEC)
	or	a
	jr	z,MAKE_CONF_OK

	ld	hl,(DNS_SEC)	;DNS secundario
	ld	de,(DNS_SEC+2)
	ld	a,131
	call	MAKE_CONF_IP

	jr	MAKE_CONF_OK

	;Rutina para generar opcion IP/DNS

MAKE_CONF_IP:	ld	(ix),a
	ld	(ix+1),6
	ld	(ix+2),l
	ld	(ix+3),h
	ld	(ix+4),e
	ld	(ix+5),d
	ld	a,6
	call	ADD_IXBC
	ret

	;--- Paquete listo: termina

MAKE_CONF_OK:	ld	hl,(MKCR_DIR)
	push	hl
	pop	ix
	ld	(ix+2),b	;Establece longitud del paquete
	ld	(ix+3),c
	ret

MKCR_DIR:	dw	0

	;--- Rutina para sumar A a IX y a BC

ADD_IXBC:	push	bc
	pop	de
	ld	b,a
ADD_IXBC2:	inc	ix
	inc	de
	djnz	ADD_IXBC2
	push	de
	pop	bc
	ret


;--- PARSE_CONFREQ: Examina un paquete Configure Request recibido
;    y genera un Configure Ack o Nack o Reject,
;    segun las constantes de configuracion.
;    NO anyade opciones nuevas en el caso de generar un Configure Nack.
;
;    Entrada: HL=Paquete ConfReq, DE=Direccion para la respuesta,
;             constantes de configuracion establecidas adecuadamente:
;             ADDCMP_I_NEG, PROTCMP_I_NEG, LQR_I_NEG, AUTH_POLICY,
;             MAGIC_LOCAL, MIN_MTU
;    Salida:  A=Paquete de respuesta generado:
;             0: Configure Ack
;             1: Configure Nack
;             2: Configure Reject
;             #81: Error: no es un paquete Configure Request
;             #82: Error: estamos "looped-back"
;                  (se han recibido LOOPBACK_MAX magic numbers
;                   iguales al nuestro)
;             #83: Error: el campo de longitud del paquete es invalido
;                  (tras examinar una opcion y restar su longitud a la
;                   longitud de paquete restante, se obtiene un
;                   valor negativo)
;             BC=Longitud paquete de respuesta
;             HL,DE preservados
;             Si resulta en ACK, variables de configuracion establecidas
;             adecuadamente
;
;    La rutina tiene cuatro modos de funcionamiento:
;    * Modo ACK: El modo inicial, se mantiene mientras las opciones que
;      vamos examinando sean validas. Las opciones validas se ignoran,
;      si se encuentra una invalida se pasa al modo NACK o al modo Reject
;      y se crea un paquete Nack o Reject con esa opcion.
;    * Modo NACK: Las opciones validas o las que generan un Reject
;      se ignoran. Las que generan un NACK se incluyen en el paquete Nack.
;    * Modo Reject: Las opciones validas o las que generan un NACK
;      se ignoran. Las que generan un Reject se incluyen en el paquete Reject.
;    * Modo Todo ACK: Si tras examinar todas las opciones seguimos en modo ACK,
;      se pasa al modo Todo ACK y se vuelve a ejecutar toda la rutina.
;      En este modo, ya sabiendo que todas las opciones son correctas,
;      se establecen adecuadamente las variables de configuracion
;      y al final se devuelve un paquete Configure Ack, copia del Req original.

PARSE_CONFREQ:	ld	a,(hl)	;Error si no es configure Request
	cp	1
	ld	a,#81
	ret	nz

	xor	a	;Inicialmente, modo ACK
	ld	(PARSE_STAT),a

	ld	(CONFREQ_DIR),hl
	ld	(CONFACK_DIR),de
PARSE_CONFR2:	push	hl	;Salta aqui en el modo Todo Ack
	pop	ix
	push	de
	pop	iy	;IY apunta al paquete de destino
	ld	a,4	;La cabecera la rellenaremos al final
	call	ADD_IY
	ld	b,(ix+2)
	ld	c,(ix+3)
	ld	a,4	;Longitud restante de paquete
	call	ADSUB_IXBC	;a examinar

	;--- Bucle principal
	;    Mientras quede paquete, obtiene el numero de opcion
	;    y salta a la rutina de la idem adecuada.
	;    Si la opcion es desconocida, pasa a modo ConfRej.
	;    IX=Puntero al paquete original (opcion a examinar)
	;    IY=Puntero al paquete NACK o Rej nuevo
	;    BC=Bytes por examinar del paquete original

PARSE_MAIN:	bit	7,b	;Quedan bytes a examinar?
	ld	a,#83	;Error si longitud restante negativa
	ret	nz
	ld	a,b
	or	c
	jp	z,PARSE_END

PARSE_MAIN2:	ld	a,(AUTOM_IS_IPCP)
	or	a
	jr	nz,PARSE_MAIN3

	;Opciones conocidas para LCP

	ld	a,(ix)
	dec	a
	jr	z,PARSE_OP1
	dec	a
	jp	z,PARSE_OP2
	dec	a
	jp	z,PARSE_OP3
	dec	a
	jp	z,PARSE_OP4
	dec	a
	jp	z,PARSE_OP5
	dec	a
	jp	z,PARSE_UNK
	dec	a
	jp	z,PARSE_OP7
	dec	a
	jp	z,PARSE_OP8	;Si pasa de aqui, opcion desconocida
	jr	PARSE_UNK

	;Opciones conocidas para IPCP

PARSE_MAIN3:	ld	a,(ix)
	cp	3
	jp	z,PARSE_OP3_IPCP
	cp	129
	jp	z,PARSE_OP129
	cp	131
	jp	z,PARSE_OP131

	;Salta aqui si la opcion es desconocida

PARSE_UNK:	ld	a,(PARSE_STAT)	;Si estabamos en modo NACK,
	cp	1	;ignorar opciones desconocidas
	jr	z,PAR_M_NEXT

	ld	a,2	;Pasa a modo ConfRej
	ld	(PARSE_STAT),a

PAR_M_COPY:	push	bc	;Copia la opcion incorrecta
	push	ix	;al paquete ConfRej creado
	pop	hl
	push	iy
	pop	de
	ld	c,(ix+1)
	ld	b,0
	ldir
	pop	bc
	push	de
	pop	iy
PAR_M_NEXT:	ld	a,(ix+1)	;Pasa a la siguiente opcion
	call	ADSUB_IXBC

	jr	PARSE_MAIN

	;--- Opcion MRU:
	;    - En modo Reject: ignorarla
	;    - En modo Ack o Nack:
	;    Si es menor de MIN_MTU pasar a Nack y anyadirla al paquete
	;    de respuesta, si no, ignorarla
	;    - En modo Todo Ack: Establecer MTU

PARSE_OP1:	ld	h,(ix+2)
	ld	l,(ix+3)
	ld	de,(MIN_MTU)

	ld	a,(PARSE_STAT)
	dec	a
	jr	z,PAR_OP1_N
	dec	a
	jr	z,PAR_OP1_R
	dec	a
	dec	a
	jr	z,PAR_OP1_T

	;Modo ACK o NACK

PAR_OP1_A:
PAR_OP1_N:	call	COMP	;Si TRU propuesto >= MIN_MTU, OK
	jr	c,PAR_M_NEXT

	ld	a,1	;Si no, pasa a modo NACK
	ld	(PARSE_STAT),a

	ld	(iy),1
	ld	(iy+1),4	;Propone el MTU minimo
	ld	(iy+2),d
	ld	(iy+3),e

	ld	a,4
	call	ADD_IY
	jr	PAR_M_NEXT

	;Modo Reject

PAR_OP1_R:	jr	PAR_M_NEXT

	;Modo Todo Ack

PAR_OP1_T:	inc	hl	;Almacena MTU en exceso 4
	inc	hl
	inc	hl
	inc	hl
	ld	(MTU),hl
	jr	PAR_M_NEXT

	;--- Opcion Async-Char-Map:
	;    - En modo ACK, NACK o Reject: ignorarla
	;    - En modo Todo ACK: establecer ESC_O_TAB y ESC_O_TABR

PARSE_OP2:	ld	a,(PARSE_STAT)
	cp	4
	jr	nz,PAR_M_NEXT

	ld	l,(ix+2)	;Establece ESC_O_TABR
	ld	h,(ix+3)
	ld	e,(ix+4)
	ld	d,(ix+5)
	ld	(ESC_O_TABR),hl
	ld	(ESC_O_TABR+2),de

	push	bc
	ld	hl,ESC_O_TABR
	ld	de,ESC_O_TAB	;Establece ESC_O_TAB
	call	ASYNC_SET
	pop	bc
	jr	PAR_M_NEXT

	;--- Opcion Authentication Protocol:
	;    - En modo ACK:
	;    * Si AUTH_POLICY=3 ignorarla si el proto es PAP o CHAP,
	;    si es otro, pasar a modo NACK y proponer PAP y CHAP
	;    * Si AUTH_POLICY=1 y el proto es PAP, ignorarlo;
	;    si es 2 y el proto es CHAP, ignorarlo; si no,
	;    proponer PAP o CHAP adecuadamente y pasar a modo NACK
	;    * Si AUTH_POLICY=0 pasar a modo Reject
	;    - En modo NACK:
	;    * Si AUTH_POLICY=0 o 3, ignorarlo
	;    * Si AUTH_POLICY=1 y el proto es PAP, ignorarlo;
	;    si es 2 y el proto es CHAP, ignorarlo; si no,
	;    proponer PAP o CHAP adecuadamente
	;    - En modo Reject:
	;    * Si AUTH_POLICY=0, anyadir opcion al paquete reject
	;    * En otro caso, ignorarlo
	;    - En modo Todo Ack: establecer AUTH_STATUS a 1
	;      y el automata se encargara de la negociacion
	;    NOTA: Al proponer un protocolo en un paquete NACK,
	;          el campo de datos de la opcion se queda vacio
	;          (se pone solo tipo+longitud+protocolo)

PARSE_OP3:	ld	a,(PARSE_STAT)
	dec	a
	jr	z,PAR_OP3_N
	dec	a
	jr	z,PAR_OP3_R
	dec	a
	dec	a
	jr	z,PAR_OP3_T

	;Modo ACK

PAR_OP3_A:	ld	a,(AUTH_POLICY)	;Rechazar siempre?
	or	a
	jr	z,PAR_OP3_R

	cp	3	;Aceptar todo?
	jr	nz,PAR_OP3_A2	;Entonces se ignora si es PAP o CHAP
	ld	d,(ix+2)
	ld	e,(ix+3)
	ld	hl,#C023
	call	COMP
	jp	z,PAR_M_NEXT
	ld	hl,#C223
	call	COMP
	jp	z,PAR_M_NEXT

	ld	de,#C023	;Si no, se propone PAP y CHAP
	call	PROP_PROT
	ld	de,#C223
	call	PROP_PROT
	jp	PAR_M_NEXT

PAR_OP3_A2:	ld	e,(ix+3)	;Aceptar solo PAP o CHAP?
	ld	d,a	;Entonces, si nos proponen el que
	ld	a,e	;queremos, ignoramos...
	cp	#23
	jr	nz,PAR_OP3_A3
	ld	a,(ix+2)
	cp	d
	jp	z,PAR_M_NEXT

PAR_OP3_A3:	;ld      d,a              ;...si no, proponemos el opuesto
	ld	e,#23	;(o si nos proponen uno desconocido)
	call	PROP_PROT
	jp	PAR_M_NEXT

	;Modo NACK

PAR_OP3_N:	ld	a,(AUTH_POLICY)	;Si AUTH_POLICY=0 o 3, ignorar;
	or	a	;si no, actuar como en ACK
	jp	z,PAR_M_NEXT
	cp	3
	jp	z,PAR_M_NEXT
	ld	a,(AUTH_POLICY)
	jr	PAR_OP3_A2

	;Modo Reject

PAR_OP3_R:	ld	a,2
	ld	(PARSE_STAT),a
	ld	a,(AUTH_POLICY)
	or	a
	jp	nz,PAR_M_NEXT
	jp	PAR_M_COPY

	;Modo Todo ACK

PAR_OP3_T:	ld	a,1
	ld	(AUTH_STATUS),a
	ld	a,(ix+2)
	ld	(AUTH_PROTO),a
	jp	PAR_M_NEXT

	;Propone protocolo de autentificacion DE y pasa a modo NACK
	;(genera opcion con campo de datos vacio)

PROP_PROT:	ld	(iy),3
	ld	(iy+1),4
	ld	(iy+2),d
	ld	(iy+3),e
	ld	(iy+4),5	;Por si es CHAP
	ld	a,4
	call	ADD_IY
	ld	a,1
	ld	(PARSE_STAT),a
	ld	hl,#C223	;Si es CHAP, la opcion es de
	call	COMP	;5 bytes en vez de 4
	ret	nz
	inc	iy
	inc	(iy-4)	;Anyadido en 0.4
	ret

	;--- Opcion Quality Protocol:
	;*** EN PRUEBAS: Rechazar siempre

PARSE_OP4:	ld	a,(PARSE_STAT)	;Si modo Nack o Todo ACK, ignorar
	cp	1
	jp	z,PAR_M_NEXT
	cp	4
	jp	z,PAR_M_NEXT

	ld	a,2
	ld	(PARSE_STAT),a
	jp	PAR_M_COPY

	;--- Opcion Magic Number:
	;    - Si MAGIC_O_NEG=0: Ignorar (se acepta sin mas)
	;    - Si MAGIC_O_NEG=#FF pero MAGIC_O=0: lo mismo
	;      (no se ha enviado ConfReq previo, luego el "loop-back"
	;       es imposible)
	;      Si no:
	;      Se establece MAYBE_LOOPED a #FF si MAGIC_LOCAL=numero
	;      y se incrementa LOOPED_CNT. Si llega a LOOPED_MAX
	;      se termina con error #82. Si no:
	;    - Modo ACK o Nack: ignorar si MAYBE_LOOPED=0, si no,
	;      pasar a modo NACK proponiendo un nuevo magic number
	;    - Modo reject: ignorar
	;    - Modo Todo Ack: poner MAGIC_I a #FF y copiar numero
	;      a MAGIC_REM

PARSE_OP5:	ld	a,(MAGIC_O_NEG)
	or	a
	jp	z,PAR_M_NEXT
	ld	a,(MAGIC_O)
	or	a
	jp	z,PAR_M_NEXT

	xor	a
	ld	(MAYBE_LOOPED),a

	ld	hl,(MAGIC_LOCAL)	;Compara el numero local con el remoto
	ld	e,(ix+2)
	ld	d,(ix+3)
	call	COMP
	jr	nz,PAR_OP5_1
	ld	hl,(MAGIC_LOCAL+2)
	ld	e,(ix+4)
	ld	d,(ix+5)
	call	COMP
	jr	nz,PAR_OP5_1

	ld	a,(LOOPBACK_CNT)	;Error si se llega a LOOPED_MAX
	inc	a	;comparaciones positivas
	ld	(LOOPBACK_CNT),a
	ld	hl,LOOPBACK_MAX
	cp	(hl)
	ld	a,#82
	ret	nc

	ld	a,#FF
	ld	(MAYBE_LOOPED),a

PAR_OP5_1:	;

	ld	a,(PARSE_STAT)
	dec	a
	jr	z,PAR_OP5_N
	dec	a
	jr	z,PAR_OP5_R
	dec	a
	jr	z,PAR_OP5_T

	;Modo ACK

PAR_OP5_A:
PAR_OP5_N:	ld	a,(MAYBE_LOOPED)
	or	a
	jp	z,PAR_M_NEXT

	push	bc	;Construye nuevo magic number,
	call	MAKE_MAGIC	;pasa a modo NACK,
	pop	bc	;y propone el nuevo magic number
	ld	a,1
	ld	(PARSE_STAT),a
	ld	(iy),5
	ld	(iy+1),6
	ld	hl,(MAGIC_LOCAL)
	ld	de,(MAGIC_LOCAL+2)
	ld	(iy+2),l
	ld	(iy+3),h
	ld	(iy+4),e
	ld	(iy+5),d
	ld	a,6
	call	ADD_IY
	jp	PAR_M_NEXT

	;Modo reject

PAR_OP5_R:	jp	PAR_M_NEXT

	;Modo Todo Ack

PAR_OP5_T:	ld	a,#FF
	ld	(MAGIC_I),a
	ld	l,(ix+2)
	ld	h,(ix+3)
	ld	e,(ix+4)
	ld	d,(ix+5)
	ld	(MAGIC_REM),hl
	ld	(MAGIC_REM+2),de
	ld	a,6
	call	ADD_IY
	jp	PAR_M_NEXT

MAYBE_LOOPED:	db	0

	;--- Opcion Protocol Field Compression
	;    - En modo Ack o Rej:
	;    Si PROTCMP_I_NEG=#FF, ignorarla, si no,
	;    pasar a modo Reject e incluir la opcion en el paquete
	;    - En modo Nack: ignorarla
	;    - En modo Todo Ack: poner PROTCMP_I a #FF

PARSE_OP7:	ld	hl,PROTCMP_I_NEG
	ld	de,PROTCMP_I
	ld	a,7
	jr	PAR_OP78

	;--- Opcion Address and Control Field Compression
	;    - En modo Ack o Rej:
	;    Si ADDCMP_I_NEG=#FF, ignorarla, si no,
	;    pasar a modo Reject e incluir la opcion en el paquete
	;    - En modo Nack: ignorarla
	;    - En modo Todo Ack: poner ADDCMP_I a #FF

PARSE_OP8:	ld	hl,ADDCMP_I_NEG
	ld	de,ADDCMP_I
	ld	a,8
	;jr      PAR_OP78

	;--- Codigo comun para las opciones 7 y 8

PAR_OP78:	ld	(PAR_OP78_OP),a
	ld	a,(PARSE_STAT)
	dec	a
	jr	z,PAR_OP78_N
	dec	a
	jr	z,PAR_OP78_R
	dec	a
	dec	a
	jr	z,PAR_OP78_T

	;Modo ACK o Reject

PAR_OP78_A:
PAR_OP78_R:	ld	a,(hl)
	or	a
	jp	nz,PAR_M_NEXT

	ld	a,2	;Pasa a modo reject
	ld	(PARSE_STAT),a
	ld	a,(PAR_OP78_OP)
	ld	(iy),a
	ld	(iy+1),2
	inc	iy
	inc	iy
	jp	PAR_M_NEXT

	;Modo NACK

PAR_OP78_N:	jp	PAR_M_NEXT

	;Modo Todo Ack

PAR_OP78_T:	ld	a,#FF
	ld	(de),a
	jp	PAR_M_NEXT

PAR_OP78_OP:	db	0	;7 o 8 segun opcion

	;--- Opcion direccion IP (para IPCP)
	;    - Si estamos en modo ACK:
	;      Si es <>0, ignorarla
	;      Si es 0, pasar a modo NAK y proponer IP_REMOTE
	;    - Si estamos en modo NAK:
	;      Si es 0, proponer IP_REMOTE
	;      Si es <>0, ignorarla
	;    - Si estamos en modo Reject: ignorarla
	;    - Si estamos en modo Todo Ack: copiarla en IP_REMOTE
	;    Normalmente deberiamos recibir esta opcion
	;    con un valor distinto de cero (el host conoce su IP)

PARSE_OP3_IPCP:	ld	hl,IP_REMOTE
	ld	(PAR_IPCP_VAR1),hl
	ld	a,3
	ld	(PAR_IPCP_VAR3),a
	jr	PAR_OP_IPCP

	;--- Opcion DNS primario (para IPCP)
	;    - Si estamos en modo ACK:
	;      Si es <>0, ignorarla
	;      Si es 0, pasar a modo NAK y proponer DNS_PRIM
	;    - Si estamos en modo NAK:
	;      Si es 0, proponer DNS_PRIM
	;      Si es <>0, ignorarla
	;    - Si estamos en modo Reject: ignorarla
	;    - Si estamos en modo Todo Ack: copiarla en DNS_PRIM
	;    Normalmente NO deberiamos recibir esta opcion
	;    (la enviaremos nosotros con valor cero)

PARSE_OP129:	ld	hl,DNS_PRIM
	ld	(PAR_IPCP_VAR1),hl
	ld	a,129
	ld	(PAR_IPCP_VAR3),a
	jr	PAR_OP_IPCP

	;--- Opcion DNS secundario (para IPCP)
	;    - Si estamos en modo ACK:
	;      Si es <>0, ignorarla
	;      Si es 0, pasar a modo NAK y proponer DNS_SEC
	;    - Si estamos en modo NAK:
	;      Si es 0, proponer DNS_SEC
	;      Si es <>0, ignorarla
	;    - Si estamos en modo Reject: ignorarla
	;    - Si estamos en modo Todo Ack: copiarla en DNS_SEC
	;    Normalmente NO deberiamos recibir esta opcion
	;    (la enviaremos nosotros con valor cero)

PARSE_OP131:	ld	hl,DNS_SEC
	ld	(PAR_IPCP_VAR1),hl
	ld	a,131
	ld	(PAR_IPCP_VAR3),a
	jr	PAR_OP_IPCP

	;--- Codigo comun para las opciones IP y DNS

PAR_OP_IPCP:	ld	a,(PARSE_STAT)
	cp	2
	jp	z,PAR_M_NEXT	;Modo Reject? Ignorar

	cp	4
	jr	z,PAR_OP_IPCP1

	;Modo ACK o NAK

	ld	a,(ix+2)	;Ignorar si <>0
	or	(ix+3)
	or	(ix+4)
	or	(ix+5)
	jp	nz,PAR_M_NEXT

	ld	a,1	;Pasa a modo NAK
	ld	(PARSE_STAT),a

	ld	a,(PAR_IPCP_VAR3)	;3, 129 o 131
	ld	(iy),a	;Propone nuevo valor
	ld	(iy+1),6
	ld	hl,(PAR_IPCP_VAR1)	;IP_REMOTE o DNS_PRIM/SEC_V
	push	iy
	pop	de	;Establece la opcion
	inc	de	;segun la constante de config.
	inc	de
	push	bc
	ld	bc,4
	ldir
	pop	bc
	ld	a,6
	call	ADD_IY
	jp	PAR_M_NEXT

	;Modo Todo ACK

PAR_OP_IPCP1:	ld	de,(PAR_IPCP_VAR1)	;IP_REMOTE o DNS_PRIM/SEC
	push	ix
	pop	hl	;Establece la variable de config.
	inc	hl	;segun la opcion
	inc	hl
	push	bc
	ld	bc,4
	ldir
	pop	bc

	jp	PAR_M_NEXT

PAR_IPCP_VAR1:	dw	0
;PAR_IPCP_VAR2:    dw      0
PAR_IPCP_VAR3:	db	0

	;--- PARSE_END: Ya se han examinado todas las opciones:
	;    - Si seguimos en modo ACK, volvemos al principio
	;      pero ahora en modo Todo Ack
	;    - Si estabamos en modo Todo Ack,
	;      copia el paquete ConReq al paquete de destino,
	;      le cambia el codigo para que sea ConfAck,
	;      y termina con A=0
	;    - Si estabamos en modo ConfNack o ConfRej,
	;      establece el codigo, identificador y longitud
	;      del paquete de destino, y devuelve A=1 o 2

PARSE_END:	ld	hl,(CONFREQ_DIR)
	ld	de,(CONFACK_DIR)
	ld	a,(PARSE_STAT)
	or	a
	jr	z,PAR_END_0
	dec	a
	jr	z,PAR_END_1
	dec	a
	jr	z,PAR_END_2
	;xor     a
	;ret

	;Modo Todo ACK

PAR_END_4:	push	hl
	pop	ix
	ld	a,(ix+2)
	and	%00000111
	ld	b,a
	ld	c,(ix+3)
	push	hl,de,bc
	ldir
	pop	bc,de,hl
	ld	a,2
	ld	(de),a	;Coambia a ConfAck
	xor	a
	ret

	;Modo Ack

PAR_END_0:	ld	a,4
	ld	(PARSE_STAT),a
	jp	PARSE_CONFR2

	;Modo ConfNack o ConfRej

PAR_END_1:
PAR_END_2:	push	iy
	pop	hl
	or	a
	sbc	hl,de	;Calcula longitud del paquete
	push	de
	pop	ix
	ld	(ix+2),h	;Establece longitud
	ld	(ix+3),l
	push	hl
	ld	a,(PARSE_STAT)
	inc	a
	inc	a
	ld	(ix),a	;Establece codigo (3=Nack,4=Rej)
	ld	hl,(CONFREQ_DIR)
	inc	hl
	ld	a,(hl)
	dec	hl
	ld	(ix+1),a	;Establece id como el del ConfReq

	pop	bc
	ld	a,(PARSE_STAT)
	ret

	;--- Rutina para sumar A a IX y restarlo a BC

ADSUB_IXBC:	push	bc
	pop	de
	ld	b,a
ADSUB_IXBC2:	inc	ix
	dec	de
	djnz	ADSUB_IXBC2
	push	de
	pop	bc
	ret

	;--- Rutina para sumar A a IY

ADD_IY:	push	bc
	ld	b,a
ADD_IYLOOP:	inc	iy
	djnz	ADD_IYLOOP
	pop	bc
	ret

;Modo de funcionamiento de la rutina:
;0: ACK, 1: NACK, 2: ConfRej, 4: Todo ACK

PARSE_STAT:	db	0

;Direcciones de los paquetes de origen y destino

CONFREQ_DIR:	dw	0
CONFACK_DIR:	dw	0


;--- PARSE_CONFNAK: Examina un paquete Configure Nak recibido
;    y establece las constantes/variables de configuracion adecuadamente
;
;    Entrada: HL=direccion del paquete de entrada
;    Salida:  A=0: OK
;             #81: Error: no es un paquete Configure Nak
;    NO -->   #83: Error: el campo de longitud del paquete es invalido
;                  (tras examinar una opcion y restar su longitud a la
;                   longitud de paquete restante, se obtiene un
;                   valor negativo)
;                  pero las ctes/vars han sido establecidas

PARSE_CONFNAK:	ld	a,(hl)	;Error si no es Configure Nak
	cp	3
	ld	a,#81
	ret	nz

	push	hl
	pop	ix
	ld	b,(ix+2)
	ld	c,(ix+3)
	ld	a,4	;Longitud restante de paquete
	call	ADSUB_IXBC	;a examinar

	;--- Bucle principal
	;    Mientras quede paquete, obtiene el numero de opcion
	;    y salta a la rutina de la idem adecuada.
	;    IX=Puntero al paquete original (opcion a examinar)
	;    BC=Bytes por examinar del paquete original

PARNAK_MAIN:	bit	7,b	;Quedan bytes a examinar?
	ld	a,0	;#83            ;Error si longitud restante negativa
	ret	nz
	ld	a,b
	or	c
	ld	a,0
	ret	z

	ld	a,(AUTOM_IS_IPCP)
	or	a
	jr	nz,PARNAK_MAIN3

	;LCP:
	;Solo soporta: MRU, Async-map, Magic-number, y addr/prot compr
	;Las demas opciones son ignoradas
	;(nunca propondremos autentificacion, y en esta version,
	;tampoco protocolo de calidad)

PARNAK_MAIN2:	ld	a,(ix)
	cp	1
	jr	z,PARNAK_OP_1
	cp	2
	jr	z,PARNAK_OP_2
	cp	5
	jr	z,PARNAK_OP_5
	cp	7
	jp	z,PARNAK_OP_7
	cp	8
	jp	z,PARNAK_OP_8
	jr	PARNAK_NEXT

	;IPCP:
	;Solo soporta dir. IP y DNS primario/secundario

PARNAK_MAIN3:	ld	a,(ix)
	cp	3
	jp	z,PARNAK_OP_3
	cp	129
	jp	z,PARNAK_OP_129
	cp	131
	jp	z,PARNAK_OP_131

	;Pasa a la siguiente opcion

PARNAK_NEXT:	ld	a,(ix+1)
	call	ADSUB_IXBC
	jr	PARNAK_MAIN

	;--- MRU: Si nos proponen un numero entre 128 y 2000,
	;    lo establecemos como nuestro MRU para negociar en el
	;    proximo Conf Req. Si no, extablecemos 128 o 2000.

PARNAK_OP_1:	ld	h,(ix+2)
	ld	l,(ix+3)
	ld	de,128
	call	COMP
	jr	nc,PARNAK_OP1_2
	ld	de,2001
	call	COMP
	dec	de
	jr	c,PARNAK_OP1_2
	push	hl
	pop	de
PARNAK_OP1_2:	inc	de	;Almacena nuevo MRU en exceso 4
	inc	de
	inc	de
	inc	de
	ld	(MRU),de
	jr	PARNAK_NEXT

	;--- Async-Set propio: aceptamos el que nos propongan

PARNAK_OP_2:	ld	l,(ix+2)
	ld	h,(ix+3)
	ld	e,(ix+4)
	ld	d,(ix+5)
	ld	(ESC_I_TABR),hl
	ld	(ESC_I_TABR+2),de

	push	bc
	ld	hl,ESC_I_TABR
	ld	de,ESC_I_TAB
	call	ASYNC_SET
	pop	bc
	jr	PARNAK_NEXT

	;--- Magic-number:
	;    Si es igual al que habiamos calculado antes,
	;    calcula uno nuevo.
	;    En caso contrario, simplemente pone LOOPBAK_CNT a 0.

PARNAK_OP_5:	ld	hl,(MAGIC_LOCAL)
	ld	e,(ix+2)
	ld	d,(ix+3)
	call	COMP
	jr	nz,PARNAK_OP5_1
	ld	hl,(MAGIC_LOCAL+2)
	ld	e,(ix+4)
	ld	d,(ix+5)
	call	COMP
	jr	nz,PARNAK_OP5_1

	push	bc
	call	MAKE_MAGIC
	pop	bc
	jr	PARNAK_NEXT

PARNAK_OP5_1:	xor	a
	ld	(LOOPBACK_CNT),a
	jr	PARNAK_NEXT

	;--- Protocol field compression: pone PROTCMP_I_NEG a #FF
	;    para negociarlo en el proximo ConfReq

PARNAK_OP_7:	ld	a,#FF
	ld	(PROTCMP_I_NEG),a
	jr	PARNAK_NEXT

	;--- Address and control compression: pone ADDCMP_I_NEG a #FF
	;    para negociarlo en el proximo ConfReq

PARNAK_OP_8:	ld	a,#FF
	ld	(ADDCMP_I_NEG),a
	jp	PARNAK_NEXT

	;--- Direccion IP (IPCP):
	;    Copia la direccion propuesta a IP_LOCAL

PARNAK_OP_3:	ld	de,IP_LOCAL
	jr	PARNAK_OP_IPCP

	;--- DNS primario (IPCP):
	;    Copia la direccion propuesta a DNS_PRIM

PARNAK_OP_129:	ld	de,DNS_PRIM
	jr	PARNAK_OP_IPCP

	;--- DNS secundario (IPCP):
	;    Copia la direccion propuesta a DNS_SEC

PARNAK_OP_131:	ld	de,DNS_SEC
	;jr      PARNAK_OP_IPCP

	;--- Codigo comun para IP y DNS

PARNAK_OP_IPCP:	push	ix
	pop	hl
	inc	hl
	inc	hl
	push	bc
	ld	bc,4
	ldir
	pop	bc
	jp	PARNAK_NEXT



;--- PARSE_CONFREJ: Examina un paquete Configure Reject recibido
;    y establece las constantes/variables de configuracion adecuadamente
;    (desactiva la negociacion de la opcion, o la establece al valor por def.)
;
;    Entrada: HL=direccion del paquete de entrada
;    Salida:  A=0: OK
;             #81: Error: no es un paquete Configure Reject
;    NO -->   #83: Error: el campo de longitud del paquete es invalido
;                  (tras examinar una opcion y restar su longitud a la
;                   longitud de paquete restante, se obtiene un
;                   valor negativo)
;                  pero las ctes/vars han sido establecidas

PARSE_CONFREJ:	ld	a,(hl)	;Error si no es Configure Reject
	cp	4
	ld	a,#81
	ret	nz

	push	hl
	pop	ix
	ld	b,(ix+2)
	ld	c,(ix+3)
	ld	a,4	;Longitud restante de paquete
	call	ADSUB_IXBC	;a examinar

	;--- Bucle principal
	;    Mientras quede paquete, obtiene el numero de opcion
	;    y salta a la rutina de la idem adecuada.
	;    IX=Puntero al paquete original (opcion a examinar)
	;    BC=Bytes por examinar del paquete original

PARREJ_MAIN:	bit	7,b	;Quedan bytes a examinar?
	ld	a,0	;#83            ;Error si longitud restante negativa
	ret	nz
	ld	a,b
	or	c
	ld	a,0
	ret	z

	;Solo soporta: MRU, Async-map, Magic-number, addr/prot compr
	;y DNS prim/sec
	;Las demas opciones son ignoradas
	;(nunca propondremos autentificacion, y en esta version,
	;tampoco protocolo de calidad)
	;Ignoramos los Reject de dir. IP

	ld	a,(ix)
	cp	1
	jr	z,PARREJ_OP_1
	cp	2
	jr	z,PARREJ_OP_2
	cp	5
	jr	z,PARREJ_OP_5
	cp	7
	jr	z,PARREJ_OP_7
	cp	8
	jr	z,PARREJ_OP_8
	cp	129
	jr	z,PARREJ_OP_129
	cp	131
	jr	z,PARREJ_OP_131

PARREJ_NEXT:	ld	a,(ix+1)
	call	ADSUB_IXBC
	jr	PARREJ_MAIN

	;--- MRU: Establecemos el valor por defecto, 1500 bytes

PARREJ_OP_1:	ld	hl,1504
	ld	(MRU),hl
	jr	PARREJ_NEXT

	;--- Async-Set propio: establecemos el valor por defecto,
	;    #FFFFFFFF

PARREJ_OP_2:	ld	hl,#FFFF
	ld	(ESC_I_TABR),hl
	ld	(ESC_I_TABR+2),hl

	push	bc
	ld	hl,ESC_I_TABR
	ld	de,ESC_I_TAB
	call	ASYNC_SET
	pop	bc
	jr	PARREJ_NEXT

	;--- Magic-number:
	;    Ponemos MAGIC_O y MAGIC_LOCAL a 0

PARREJ_OP_5:	xor	a
	ld	hl,0
	ld	(MAGIC_O),a
	ld	(MAGIC_LOCAL),hl
	ld	(MAGIC_LOCAL+2),hl
	xor	a
	ld	(LOOPBACK_CNT),a
	jr	PARREJ_NEXT

	;--- Protocol field compression: pone PROTCMP_O_NEG a 0
	;    para no negociarlo en el proximo ConfReq

PARREJ_OP_7:	xor	a
	ld	(PROTCMP_O_NEG),a
	jr	PARREJ_NEXT

	;--- Address and control compression: pone ADDCMP_O_NEG a 0
	;    para negociarlo en el proximo ConfReq

PARREJ_OP_8:	xor	a
	ld	(ADDCMP_O_NEG),a
	jr	PARREJ_NEXT

	;--- DNS primario o secundario: pone NEG_DNS_PRIM/SEC a 0
	;    para no negociarlo en el proximo ConfReq

PARREJ_OP_129:	xor	a
	ld	(NEG_DNS_PRIM),a
	jr	PARREJ_NEXT
PARREJ_OP_131:	xor	a
	ld	(NEG_DNS_SEC),a
	jr	PARREJ_NEXT



;****************************
;**                        **
;**   RUTINAS AUXILIARES   **
;**                        **
;****************************

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


;--- FLUSH_ALL: Vacia todas las colas

FLUSH_ALL:	push	af
	ld	ix,LCP_IN_QUEUE
	call	FLUSH_QUEUE
	ld	ix,IPCP_IN_QUEUE
	call	FLUSH_QUEUE
	ld	ix,CHAP_IN_QUEUE
	call	FLUSH_QUEUE
	ld	ix,IP_IN_QUEUE
	call	FLUSH_QUEUE
	ld	ix,OUT_QUEUE
	call	FLUSH_QUEUE
	pop	af
	ret


;--- ASYNC_SET: Convierte un mapa de bytes asincronos de 4 bytes
;    (1 bit por caracter, MSBit=31 1er byte=31) en un mapa de 32 bytes
;    (1 byte por caracter, el primer byte es 0, #FF=enmascarado)
;    Entrada: HL = Dir. del mapa de 4 bytes
;             DE = Dir. donde dejar el mapa de 32 bytes
;    Salida:  Mapa de 32 bytes en (DE)

ASYNC_SET:	push	hl,de

	push	de
	pop	hl
	inc	de	;Primero limpia el bufer de destino
	ld	bc,31
	ld	(hl),0
	ldir

	pop	de,hl
	ex	de,hl
	ld	bc,31
	add	hl,bc	;Ahora HL=destino y DE=origen

	ld	b,4
ASYSET_L1:	ld	a,(de)	;Bucle exterior: trata los 4 bytes
	inc	de
	ld	c,8

ASYSET_L2:	sla	a	;Bucle interior: trata los 8 bits
	jr	nc,OKASY	;de cada byte
	ld	(hl),#FF
OKASY:	dec	hl
	dec	c
	jr	nz,ASYSET_L2

	djnz	ASYSET_L1
	ret


;--- MAKE_MAGIC: Rutina para generar un numero magico
;    Lo deposita en MAGIC_LOCAL

MAKE_MAGIC:	ld	b,4
	ld	hl,MAGIC_LOCAL
MKMGLOOP:	push	bc
	ld	a,r
	ld	d,a
	call	MKMG_WAIT
	ld	a,r
	ld	e,a
	call	MKMG_WAIT
	ld	a,(de)
	xor	d
	xor	e
	ld	d,a
	call	MKMG_WAIT
	ld	a,r
	xor	d
	ld	(hl),a
	inc	hl
	pop	bc
	djnz	MKMGLOOP

	;--- Una vez creado, comprobamos si es 0, en ese caso
	;    lo volvemos a crear

	ld	hl,MAGIC_LOCAL
	ld	a,(hl)
	inc	hl
	or	(hl)
	inc	hl
	or	(hl)
	inc	hl
	or	(hl)
	ret	nz
	jr	MAKE_MAGIC

MKMG_WAIT:	ld	a,r
	ld	b,a
idle:	djnz	idle
	ret


;--- INIT_VAR:
;    Rutina para establecer las vars de configuracion a su valor inicial

INIT_VAR:	ld	hl,1054
	ld	(MTU),hl

	ld	hl,ESC_O_TAB
	ld	de,ESC_O_TAB+1
	ld	bc,35
	ld	(hl),#FF
	ldir

	ld	hl,AUTH_STATUS
	ld	de,AUTH_STATUS+1
	ld	bc,VAR_ZONE_END-AUTH_STATUS-1
	ld	(hl),0
	ldir

	ret


;--- NETWORK_STATUS: Devuelve en A el estado del modulo PPP:
;    0: LCP no esta en estado "Opened"
;    1: LCP esta en estado "Opened" pero la autentificacion
;       no se ha completado aun (o ha sido rechazada)
;    2: LCP esta en estado "Opened" y la autentificacion esta completa
;       (o no se habia solicitado), pero IPCP no esta "Opened"
;    3: LCP e IPCP estan "Opened"

NETWORK_STATUS:	ld	a,(LCP_AUTOM_STATE)
	cp	9
	ld	b,0
	jr	nz,NETSTAT_END

	ld	a,(AUTH_STATUS)
	cp	1
	ld	b,1
	jr	z,NETSTAT_END
	cp	3
	jr	z,NETSTAT_END

	ld	a,(IPCP_AUTOM_STATE)
	cp	9
	ld	b,2
	jr	nz,NETSTAT_END
	ld	b,3

NETSTAT_END:	ld	a,b
	ret


;--- ENQUEUE: Encola el paquete de GET_BUFER en la cola cuyos datos
;             estan en IX, suponiendo que es LCP, IPCP o CHAP

ENQUEUE:	ld	a,(ix)
	ld	l,(ix+1)
	ld	h,(ix+2)
	push	hl
	pop	ix
	ld	c,a
	ld	a,(#8002)
	ld	b,a
	ld	a,(GET_BUFER+2)
	ld	h,a
	ld	a,(GET_BUFER+3)
	ld	l,a
	ld	a,c
	set	7,h
	set	6,h
	ld	iy,GET_BUFER
	nesman	28
	ret

;--- ENQUEUE_PROTO: Encola el paquete de GET_BUFER en la cola cuyos datos
;                   estan en IX.
;                   Asume que antes del paquete hay 2 bytes de cabecera,
;                   y los encola tambien.
;                   BC ha de contener el valor devuelto por GET_HDLC.


ENQUEUE_PROTO:	ld	a,(ix)
	ld	l,(ix+1)
	ld	h,(ix+2)
	push	hl
	pop	ix
	push	bc
	pop	hl
	set	7,h
	set	6,h
	push	af
	ld	a,(#8002)
	ld	b,a
	pop	af
	ld	iy,GET_BUFER-2
	nesman	28
	ret


;--- ENQUEUE_OUT: Encola el paquete de PUT_BUFER en la cola OUT_QUEUE

ENQUEUE_OUT:	ld	a,(#8002)
	ld	b,a
	ld	a,(OUT_QUEUE)
	ld	ix,(OUT_QUEUE+1)
	ld	c,a
	ld	a,(PUT_BUFER+2)
	ld	h,a
	ld	a,(PUT_BUFER+3)
	ld	l,a
	ld	a,c
	set	7,h
	set	6,h
	ld	iy,PUT_BUFER
	nesman	28
	ret


;--- FLUSH_QUEUE: Borra todos los elementos de la cola cuyos datos
;                 estan en IX

FLUSH_QUEUE:	ld	a,(ix)
	ld	l,(ix+1)
	ld	h,(ix+2)
	push	hl
	pop	ix
	push	af,ix

FLUSH_QLOOP:	pop	ix,af
	push	af,ix
	ld	b,1
	ld	h,2
	nesman	25
	jr	nc,FLUSH_QLOOP
	pop	af,ix
	ret


;--- GET_LCP: Obtiene en GET_BUFER un paquete de la cola LCP (o IPCP)
;             Devuelve Cy=0 si no hay paquetes disponibles

GET_LCP:	call	_GET_LCP
	ret	nc	;Si recibe algo,
	ld	a,0	;desactiva el flag de
	ld	(CUR_PASSIVE_OPEN),a	;apertura pasiva
	ret

_GET_LCP:	ld	a,(AUTOM_IS_IPCP)
	or	a
	jr	nz,GET_IPCP
	ld	a,(LCP_IN_QUEUE)
	ld	ix,(LCP_IN_QUEUE+1)
	jr	GET_LCPORIPCP

GET_IPCP:	ld	a,(IPCP_IN_QUEUE)
	ld	ix,(IPCP_IN_QUEUE+1)

GET_LCPORIPCP:	push	af
	ld	a,(#8002)
	ld	l,a
	pop	af
	ld	b,1
	ld	h,3	;Obtiene y elimina de la cola
	ld	iy,GET_BUFER
	nesman	29
	ccf
	ret


;--- GET_MSG: Obtiene el mensaje de texto que viene con un paquete
;             Terminate Request o exito/fallo de PAP/CHAP en GET_BUFER,
;             pone su longitud en (HL) y lo copia en (DE)

GET_MSG:	push	hl
	pop	ix
	ld	a,(GET_BUFER+2)	;Copia el mensaje del paquete
	ld	h,a	;a LCP_MSG o IPCP_MSG
	ld	a,(GET_BUFER+3)	;si tiene longitud >0
	ld	l,a
	ld	bc,4
	or	a
	sbc	hl,bc
	ld	a,h
	or	a
	jr	z,GET_MSG2	;Si lon>255, se toma 255
	ld	hl,255
GET_MSG2:	ld	(ix),l
	ld	a,l
	or	a
	ret	z

	push	hl	;Copia el mensaje
	pop	bc
	ld	hl,GET_BUFER+4
	ldir

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



;*************************
;***                   ***
;***   AUTOMATA CHAP   ***
;***                   ***
;*************************

;- Si recibe un "Challenge", genera el paquete de respuesta
;- Si recibe un "Response", siempre devuelve "Success"
;- Si recibe un "Success", pone AUTH_STATUS a 2
;- Si recibe un "Failure", pone AUTH_STATUS a 3

CHAP_AUTOM:	ld	a,(#8002)
	ld	l,a
	ld	a,(CHAP_IN_QUEUE)
	ld	ix,(CHAP_IN_QUEUE+1)
	ld	b,1
	ld	h,3	;Obtiene y elimina de la cola
	ld	iy,GET_BUFER
	nesman	29
	ret	c	;Termina si no hay paquetes

	ld	a,(GET_BUFER)
	dec	a
	jr	z,CHAP_AUTOM_1
	dec	a
	jr	z,CHAP_AUTOM_2
	dec	a
	jp	z,CHAP_AUTOM_3
	dec	a
	jp	z,CHAP_AUTOM_4
	ret		;Termina si codigo desconocido

	;--- Challenge: genera la respuesta

	;Compone la cadena a digerir en PUT_BUFER

CHAP_AUTOM_1:	ld	a,(GET_BUFER+1)	;Cadena = id...
	ld	(PUT_BUFER),a

	ld	hl,PASSWORD	;...+ secreto...
	ld	de,PUT_BUFER+1
	ld	a,(PASSWORD_LEN)
	ld	b,0
	or	a
	jr	z,CHAP_AUT1_1
	ld	c,a
	ldir
CHAP_AUT1_1:	;

	ld	hl,GET_BUFER+5	;...+ desafio
	ld	a,(GET_BUFER+4)
	ld	c,a
	ld	b,0
	ldir

	push	de	;Calcula la longitud de la cadena
	pop	hl
	ld	bc,PUT_BUFER
	or	a
	sbc	hl,bc
	push	hl
	pop	bc	;BC = Longitud cadena

	;Digiere cadena

	ld	hl,PUT_BUFER
	call	MD5

	;Genera y envia el paquete de respuesta

	push	hl
	ld	a,2	;Compone paquete de respuesta
	ld	(PUT_BUFER),a
	ld	a,(GET_BUFER+1)	;Copia ID del desafio
	ld	(PUT_BUFER+1),a
	ld	a,16	;Longitud cadena generada=16 siempre
	ld	(PUT_BUFER+4),a
	ld	hl,USER	;Copia nombre de usuario
	ld	de,PUT_BUFER+21
	ld	bc,(USER_LEN)
	ld	b,0
	ldir
	ld	hl,(USER_LEN)	;Calcula longitud total del paquete
	ld	h,0
	ld	bc,21
	add	hl,bc
	ld	a,h
	ld	(PUT_BUFER+2),a
	ld	a,l
	ld	(PUT_BUFER+3),a
	pop	hl
	ld	de,PUT_BUFER+5	;Copia cadena generada
	ld	bc,16
	ldir

	jr	SEND_CHAP

	;--- Respuesta: Envia siempre un "Success"

CHAP_AUTOM_2:	ld	a,3
	ld	(PUT_BUFER),a
	ld	a,(GET_BUFER+1)	;Copia Id
	ld	(PUT_BUFER+1),a
	ld	bc,#0400	;Longitud 4 (no hay datos propios)
	ld	(PUT_BUFER+2),a

	jr	SEND_CHAP

	;--- Success: Pone AUTH_STATUS a 2

CHAP_AUTOM_3:	ld	a,2
	jr	CHAP_AUTOM_34

	;--- Failure: Pone AUTH_STATUS a 3

CHAP_AUTOM_4:	ld	a,3

CHAP_AUTOM_34:	ld	(AUTH_STATUS),a
	ld	hl,XAP_MSG_LEN
	ld	de,XAP_MSG
	call	GET_MSG
	ret

	;--- Rutina generica para enviar un paquete CHAP

SEND_CHAP:	ld	hl,PUT_BUFER	;Envia paquete
	ld	de,#C223
	ld	bc,0
	jp	PUT_HDLC



;************************
;***                  ***
;***   ALGORTIMO MD5  ***
;***                  ***
;************************

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

add32:	macro	@a,@b	;Performs (@a) = (@a) + (@b)
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

	add32	BUF_A,BUF_AA
	add32	BUF_B,BUF_BB
	add32	BUF_C,BUF_CC
	add32	BUF_D,BUF_DD

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

	add32	BUF_A,RES_FGHI	;Adds A to the result of F/G/H/I
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

	add32	BUF_A,BUF_B	;Finally, adds B to A

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

	;* ROOUND 2

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



;*************************************
;**                                 **
;**   CONSTANTES DE CONFIGURACION   **
;**                                 **
;*************************************

CONS_START:	;

;*** Estas constantes deben establecerse ANTES de iniciar la
;    comunicacion (en estado "closed")
;    Pueden ser modificadas por el automata LCP
;    si se reciben ConfNak o ConfRej

;MRU: Maximum Receive Unit+4, local

MRU:	dw	1504

;ESC_I_TAB: Tabla de caracteres que hemos de recibir escapados
;Normalmente, ninguno (RS232)

ESC_I_TAB:	ds	32,0	;Version ampliada
ESC_I_TABR:	ds	4,0	;Version reducida

;Reaccion ante una peticion de autentificacion:
;0: Rechazarla siempre y terminar conexion
;#C0: Aceptar/negociar autentificacion mediate PAP unicamente
;#C2: Aceptar/negociar autentificacion mediate CHAP unicamente
;3: Aceptarla siempre sea cual sea el protocolo pedido

AUTH_POLICY:	db	3

;Uso de "magic number" propio
;0: No negociarlo, #FF: Negociarlo

MAGIC_O_NEG:	db	#FF

;ADDCMP_O_NEG, PROTCMP_O_NEG:
;Compresion de direccion+control y protocolo, de salida
;0: No negociar, #FF: Negociar

ADDCMP_O_NEG:	db	#FF
PROTCMP_O_NEG:	db	#FF

;ADDCMP_I_NEG, PROTCMP_I_NEG:
;Compresion de direccion+control y protocolo, de entrada
;0: No aceptar, #FF: Aceptar

ADDCMP_I_NEG:	db	#FF
PROTCMP_I_NEG:	db	#FF

;Minimo valor aceptable del MRU remoto

MIN_MTU:	dw	576

;Numero de recepciones de Magic Number coincidentes
;antes de decidir que estamos en loopback

LOOPBACK_MAX:	db	3

;MAX_BADBYTES: Para uso de GET_HDLC

MAX_BADBYTES:	dw	100

;Temporizador de reinicio, en 1/50 o 1/60 seg

RST_TIMER_V:	dw	170	;3 segundos por defecto

;Temporizador total
;Se pone a 0 y empieza a funcionar al recibir un "Open"
;Se para cuando NETWORK_STATUS devuelve 3 (todo OK)
;Si llega a TOTAL_TIMER_V, se genera un CLOSE

TOTAL_TIMER_V:	dw	3000	;1 minuto por defecto

;Contadores max-terminate, max-configure, max-failure

MAX_TERM_CNT_V:	db	2
MAX_CONF_CNT_V:	db	10
MAX_FAIL_CNT_V:	db	5

;Valor para el contador de envios de PAP request

PAPREQ_CNT_V:	db	50

;Valor del contador de envios Discard Request
;Si es 0, nunca se envian

ECHO_CNT_V:	dw	0

;Negociar direciones DNS, si o no

NEG_DNS_PRIM:	db	#FF
NEG_DNS_SEC:	db	#FF

;Generar automaticamente un CLOSE si falla la autentificacion, si o no

AUTO_CLOSE_AUTH:	db	0

;Generar automaticamente un CLOSE al recibir un Terminate Request

AUTO_CLOSE_TERM:	db	#FF

;Direcciones IP a usar. Si se ponen a cero, se han de negociar con IPCP.
;*** NO modificar el orden en memoria

IP_LOCAL:	ds	4
IP_REMOTE:	ds	4
DNS_PRIM:	ds	4
DNS_SEC:	ds	4

;Longitudes de nombre de usuario y password

USER_LEN:	db	0
PASSWORD_LEN:	db	0

;Apertura pasiva: si es #FF, no se envia ningun ConfReq
;hasta que se reciba alguno

PASSIVE_OPEN:	db	0

;Cada cuantas interrupciones se ejecutara la rutina PPP_INT
;0 se interpreta como 256

INT_PERIOD_V:	db	1

;Numero de ecos a enviar sin recibir respuesta
;antes de cortar la conexion

ECHO_CLOSE_V:	db	3

;Uso de LQR por parte del host remoto
;0: Rechazar si nos lo piden, #FF: Aceptar si nos lo piden

;LQR_I_NEG:        db      0                ;Futuras aplicaciones

;Periodo maximo entre envios de paquetes LQR, x100 seg
;0: Esperar a que nos envien el paquete

;MAX_LQR_TIME:     ds      4                ;Idem
;Valores por defecto de las variables

;Uso de LQR por nuestra parte
;0: Pedirlo, #FF: No pedirlo

;LQR_O_NEG:        db      0

RCVED_LCP:	db	0
RCVED_IPCP:	db	0
RCVED_PAP:	db	0
RCVED_CHAP:	db	0
RCVED_IP:	db	0
RCVED_UNK:	db	0


CONS_END:	;

CONS_DEF_VAL:	dw	1504
	ds	32,0
	ds	4,0
	db	3,#FF,#FF,#FF,#FF,#FF
	dw	576
	db	3
	dw	100
	dw	170
	dw	3000
	db	2,10,5
	db	50
	dw	250	;*** PRUEBAS: Discard/echo cada 5 seg
	db	#FF,#FF
	db	0
	db	#FF
	ds	4
	ds	4
	ds	4
	ds	4
	db	0,0
	db	#00	;*** PRUEBAS: apertura pasiva
	db	1
	db	3
	;db      0
	;db      0
	;ds      4
	db	0
	db	0
	db	0
	db	0
	db	0
	db	0


;************************************
;**                                **
;**   VARIABLES DE CONFIGURACION   **
;**                                **
;************************************

VAR_START:	;

;*** Se establecen adecuadamente al recibir un Configure Ack valido
;    y otros eventos (IPCP, etc)

;Maximum Receive Unit+4, remoto

MTU:	dw	1504

;ESC_O_TAB: Tabla de caracteres que hemos de enviar escapados

ESC_O_TAB:	ds	32,#FF	;Version ampliada
ESC_O_TABR:	ds	4,#FF	;Version reducida

;Estado de la autentificacion
;0: No solicitada, 1: Solicitada (CHAP)
;2: ACK recibido, 3: NACK recibido

AUTH_STATUS:	db	0

;Protocolo de autentificacion negociado:
;#C0: PAP, #C2: CHAP

AUTH_PROTO:	db	0

;Negociacion del uso de Link Quality Protocol, I=Entrada, O=Salida
;0: No negociado o rechazado, #FF: Negociado OK

LQR_I:	db	0
LQR_O:	db	0

;Numeros magicos

MAGIC_LOCAL:	ds	4
MAGIC_REM:	ds	4

;MAGIC_I: #FF si el host remoto ha enviado magic number y se ha aceptado

MAGIC_I:	db	0

;MAGIC_O: #FF si hemos generado un magic number y enviado en algun ConfReq

MAGIC_O:	db	0

;Compresion del protocolo, I=Entrada, O=Salida
;0: No negociado o rechazado, #FF: Negociado OK
;NO MODIFICAR EL ORDEN EN MEMORIA

ADDCMP_O:	db	0
PROTCMP_O:	db	0
ADDCMP_I:	db	0
PROTCMP_I:	db	0

;Bandera de direcciones IP ya negociadas

IP_OK:	db	0

;Mensajes de terminate request, etc de LCP, IPCP y PAP/CHAP

LCP_MSG_LEN:	db	0
IPCP_MSG_LEN:	db	0
XAP_MSG_LEN:	db	0


VAR_ZONE_END:	;*** Hasta aqui, se resetea al hacer un OPEN

;Estado del automata negociador (0 a 9 segun RFC 1661)

AUTOM_STATE:	db	0	;Automata en curso
LCP_AUTOM_STATE:	db	0	;Automata LCP
IPCP_AUTOM_STATE:	db	0	;Automata IPCP

;Estado de esta capa (util para las capas superiores)

THIS_LAYER_ST:	db	0

;Contador de Magic Number coincidentes recibidos

LOOPBACK_CNT:	db	0

;Error que ha causado el "Close":
;0: Estamos en estado "Open"
;1: Close realizado por el usuario
;2: La autentificacion ha fallado
;3: Estamos "looped-back"
;4: Ha expirado el contador total
;5: Se ha recibido un Terminate Request
;6: Se han enviado demasiados ecos sin respuesta

CLOSE_ERROR:	db	0

;El temporizador debe funcionar? (si: #FF, no: 0)

TIMER_ON:	db	0

;Direccion de las colas de entrada y salida

LCP_IN_QUEUE:	ds	3
IPCP_IN_QUEUE:	ds	3
IP_OUT_QUEUE:	ds	3
CHAP_IN_QUEUE:	ds	3
LQR_IN_QUEUE:	ds	3

IP_IN_QUEUE:	ds	3	;Esta cola es del nivel superior
OUT_QUEUE:	ds	3	;Esta cola es del nivel inferior

;Numeros de identificacion de paquete actuales

LCP_ID_CR:	db	0	;Para Configure Request
LCP_ID_TR:	db	0	;Para Terminate Requests
LCP_ID_TA:	db	0	;Para Terminate Ack
LCP_ID_CX:	db	0	;Para Code Reject
LCP_ID_PX:	db	0	;Para Protocol Reject
LCP_ID_ER:	db	0	;Para Echo Request
LCP_ID_DR:	db	0	;Para Discard Request
LCP_ID_PAP:	db	0	;Para paquetes PAP

;OPENED: #FF si se ha hecho un OPEN, 0 si se ha hecho CLOSE

OPENED:	db	0

;LAST_UPDOWN: Respuesta a la ultima comprobacion de UP/DOWN

LAST_UPDOWN:	db	0

;LAST_OPCLOSE: Respuesta a la ultima comprobacion de OPEN/CLOSE

LAST_OPCLOSE:	db	0

;LAST_NETSTAT: Respuesta a la ultima llamada a NETWORK_STATUS

LAST_NETSTAT:	db	0

;Contadores y temporizador

RST_TIMER:	dw	0
RST_COUNT:	db	0

;Temporizador total
;Se pone a 0 y empieza a funcionar al recibir un "Open"
;o cuando se abandona el estado de red (NETWORK_STATUS no devuelve 3)
;Se para cuando NETWORK_STATUS devuelve 3 (todo OK)
;Si llega a TOTAL_TIMER_V, se genera un CLOSE y se para el temporizador

TOTAL_TIMER:	dw	0
TOTAL_TIMER_ON:	db	0	;Debe funcionar?

;Contador de paquetes NAK
;Se pone a 0 al enviar un ConfAck, cuando se abandona el estado de red
;(NETWORK_STATUS no devuelve 3) o al recibir un "Open"
;Se incrementa cada vez que se envia un ConfNak
;Si supera a MAX_FAIL_CNT_V, en vez de ConfNak se envian ConfRej

FAIL_CNT:	db	0

;Contador para enviar paquete PAP request

PAPREQ_CNT:	db	0

;Contador de envio de Discard Request

ECHO_CNT:	dw	0

;Esta variable es #FF cuando el automata funciona en modo IPCP,
;0 en modo LCP

AUTOM_IS_IPCP:	db	0

;Variables usadas para notificar eventos al automata en modo IPCP

UP_FOR_IPCP:	db	0
DOWN_FOR_IPCP:	db	0
OPEN_FOR_IPCP:	db	0
CLOSE_FOR_IPCP:	db	0

;Estas variables se ponen a 1 al recibir un paquete Terminate Request,
;y se ponen a 0 cuando se recibe un OPEN

IPCP_TERM_RCV:	db	0
LCP_TERM_RCV:	db	0

;Segmentos de las capas superior e inferior

UPPER_SEG:	db	0
LOWER_SEG:	db	0

;Contador de interrupciones

INT_PERIOD:	db	0

;Bandera de apertura pasiva, valor actual

CUR_PASSIVE_OPEN:	db	0

;Contador de ecos sin responder

ECHO_CLOSE:	db	0

VAR_END:	;



;*******************
;***             ***
;***   BUFERES   ***
;***             ***
;*******************

BUFERS:	;

;Nombre de usuario y password

USER:	;
PASSWORD:	equ	USER+256

LCP_MSG:	equ	PASSWORD+256
IPCP_MSG:	equ	LCP_MSG+256
XAP_MSG:	equ	IPCP_MSG+256

;Buferes para recibir/enviar paquete

GET_BUFER:	equ	XAP_MSG+256+3
PUT_BUFER:	equ	GET_BUFER+2100
QUEUE_BUFER:	equ	PUT_BUFER+2100
CHAP_BUFER:	equ	QUEUE_BUFER+2100

