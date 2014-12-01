; IP module for InterNestor Suite

;====================

	;--- Modulo IP para Internestor Suite
	;    VERSION RESIDENTE 0.3
	;    Necesita NestorMan 1.12

	;* Cambios de 0.3 a 0.2:
	;- Adelantadas 3 bytes las rutinas TABLES y CREATE/DESTR_PROT
	;- Corregida la funcion COMP
	;- Anyadidas las funciones de resolver

	;* A cambiar en 0.4:
	;- Enviar mascara de subred solo si MASK_METHOD=0 (no si
	;  MASK_METHOD=1 y MASK_STATUS=1)
	;- Cuando se reciba "Mask Reply", establecer IP_LOCAL_SUB
	;- Cuando se envia "Mask Reply" como respuesta a "Request",
	;  poner MASK_REP_SENT=#FF (?)
	;- Cuando se reciba "Mask Request", enviar "Reply"
	;  aunque MASK_METHOD sea 0, y NO enviarlo si
	;  MASK_TIMEOUTED=#FF
	;- Cambiar que los mensajes ICMP Query aceptados sean
	;  Echo/Timestamp/Information request
	;- Hacer que el maximo tamanyo de paquete sea 2K, y no MRU
	;  (para los paquetes reensamblados)

PBA_IN:	equ	0	;1 para autogenerar un paquete
	;                        ;de entrada de prueba
PBA_OUT:	equ	0	;1 para autogenerar un paquete
	;                        ;de salida de prueba
IGNORE_CHK_IN:	equ	0	;1 para ignorar el checksum
	;                        de los paquetes entrantes
PBA_FRAG:	equ	0	;1 para generar codigo y paquetes
	;                        ;de prueba para probar fragmentacion

DNS_PORT:	equ	#3434	;Puerto para los paquetes UDP para DNS
	;                        ;(big endian)

nesman:	macro	@f
	call	#4100+3*@f
	endm

nesmani:	macro	@f
	ld	c,@f
	ld	de,#2202
	call	#FFCA
	endm

	;--- Llamadas al modulo inferior

LOW_QUEUES:	equ	#800C
LOW_CHK_TLU:	equ	#800F
LOW_OPEN:	equ	#8012
LOW_CLOSE:	equ	#8015
LOW_IPS:	equ	#8018
LOW_MXU:	equ	#801E

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
HEADER:	db	"NestorIP 0.3 - incomplete:",13,10
	db	"* No options processing",13,10
	db	"  (options are passed as received to the upper level module)",13,10
	db	"A level 3 module for InterNestor Suite",13,10
	db	"By Konami Man, 3-2002",13,10
	db	#1A
HEAD_END:	;
	ds	256-(HEAD_END-HEADER)

	;--- #0100: Cadena identificadora de 32 caracteres

	db	"NestorIP 0.3                    "

	;--- #0120: Identificador de modulo de InterNestor Suite

	db	"INESUITE"

	;--- #0128: Version

	db	0,3,0

	;--- #012B: Nivel del modulo

	db	3

	;--- Hasta #200: Reservado para futura expansion

	ds	#200-#012B-1



;**************************
;***                    ***
;***   TABLA DE SALTO   ***
;***                    ***
;**************************

	org	#8003

	;--- Rutinas obligatorias

	jp	IP_RESET	;#8003: Reset
	jp	IP_DEINIT	;#8006: Desinicializacion
	jp	IP_INT	;#8009: Atencion a la interrupcion
	jp	IP_QUEUES	;#800C: Direcciones de las colas
	ds	18,#C9	;Rellena espacio sobrante con RETs

	;--- Rutinas especificas de NestorIP

	jp	IP_TABLES	;#8021: Dir. de la tablas
	jp	IP_CREATE_PROT	;#8024: Crea cola para prot.
	jp	IP_DESTR_PROT	;#8027: Destruye cola de prot.
	jp	IP_DNS_Q	;#802A: Efectua una peticion DNS
	jp	IP_DNS_S	;#802D:	Devuelve el estado de una peticion DNS


;****************************************
;***                                  ***
;***   RUTINAS DE LA TABLA DE SALTO   ***
;***                                  ***
;****************************************

	;--- Reset
	;    Inicializa variables y colas propias
	;    Obtiene el segmento de los modulos inferior y superior

IP_RESET:	call	INIT_VAR	;Inicializa vars y ctes

	ld	de,#0402	;Obtiene rutinas del mapeador
	call	#FFCA
	ld	de,ALL_SEG
	ld	bc,#30
	ldir

	xor	a
	ld	hl,0
	ld	(IP_OUT_QUEUE),a	;Desde ahora desconocemos
	ld	(IP_OUT_QUEUE+1),hl	;las dirs de las colas externas

	nesmani	32
	push	de
	ld	a,b
	nesmani	3
	ld	a,c
	ld	(LOWER_SEG),a	;Segmentos modulos inf. y sup.
	pop	de
	ld	a,d
	nesmani	3
	ld	a,c
	ld	(UPPER_SEG),a

	call	DESTR_QUEUES

	ld	ix,IP_IN_QUEUE	;Cola de entrada desde mod. inf.
	call	INIT_QUEUE
	jr	c,INIT_Q_ERROR
	ld	ix,PROT_OUT_QUEUE	;Cola de entrada desde mod. sup.
	call	INIT_QUEUE
	jr	c,INIT_Q_ERROR
	ld	a,1
	call	IP_CREATE_PROT	;Cola para el protocolo ICMP (querys)
	jr	c,INIT_Q_ERROR
	ld	ix,FRAG_QUEUE	;Cola para fragmentos pendientes
	call	INIT_QUEUE
	jr	c,INIT_Q_ERROR
	scf
	nesmani	20	;Cola para paquetes DNS
	jr	c,INIT_Q_ERROR
	ld	(DNS_IN_QUEUE),a
	ld	(DNS_IN_QUEUE+1),ix

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

DESTR_QUEUES:	ld	hl,PROT_IN_QUEUES
	ld	b,0
BUC_DES_Q:	push	bc
	ld	b,(hl)
	ld	(hl),0
	inc	hl
	ld	a,(hl)
	ld	(hl),0
	ld	ixl,a
	inc	hl
	ld	a,(hl)
	ld	(hl),0
	ld	ixh,a
	inc	hl
	ld	a,b
	push	hl
	nesmani	22
	pop	hl,bc
	djnz	BUC_DES_Q
	ld	a,(FRAG_QUEUE)
	ld	ix,(FRAG_QUEUE+1)
	nesmani	22
	ld	a,(DNS_IN_QUEUE)
	ld	ix,(DNS_IN_QUEUE+1)
	nesmani	22
	ld	a,0
	ld	(FRAG_QUEUE),a
	ld	(FRAG_QUEUE+1),a
	ld	(FRAG_QUEUE+2),a
	ld	(DNS_IN_QUEUE),a
	ld	(DNS_IN_QUEUE+1),a
	ld	(DNS_IN_QUEUE+2),a
	ret


	;--- Deinit
	;    Destruye todas las listas

IP_DEINIT:	call	DESTR_QUEUES
	xor	a
	ld	(LOWER_SEG),a
	ld	(UPPER_SEG),a
	ld	hl,0
	ld	(IP_OUT_QUEUE),a	;Desde ahora desconocemos
	ld	(IP_OUT_QUEUE+1),hl	;las dirs de las colas externas
	ret


	;--- Queues
	;    Devuelve en A-HL la direccion de la cola segun A:
	;    y en IX la direccion en PROT_IN_TABLES
	;    0: Entrada desde el modulo inferior
	;    255: Entrada desde el modulo superior
	;    Otro numero: Salida para ese protocolo

IP_QUEUES:	ld	l,a	;Calcula IX = PROT_IN_QUEUES + A*3
	ld	h,0
	push	hl
	pop	bc
	add	hl,hl
	add	hl,bc
	ex	de,hl
	ld	ix,PROT_IN_QUEUES
	add	ix,de

	ld	a,(ix)	;Obtiene la dir de la cola
	ld	l,(ix+1)	;para ese protocolo
	ld	h,(ix+2)
	ret


	;--- Devuelve en HL la dir de la tabla especificada en A:
	;    (y en BC su longitud)
	;    0: Constantes de configuracion
	;    1: Constantes por defecto
	;    2: Variables de configuracion
	;    3: Tabla de listas para cada protocolo
	;    Devuelve Cy=1 para A desconocido

IP_TABLES:	or	a
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
	ld	hl,PROT_IN_QUEUES
	ld	bc,256*3
	ret	z
	scf
	ret


	;--- Crea una lista para el protocolo especificado
	;    Devuelve Cy=1 si es 0 o 255 o si no hay memoria

IP_CREATE_PROT:	or	a
	scf
	ret	z
	cp	255
	scf
	ret	z

	call	IP_QUEUES
	ld	(ix),0
	ld	(ix+1),0
	ld	(ix+2),0

	push	ix,hl
	pop	ix
	nesmani	22
	pop	ix

	call	INIT_QUEUE
	ret


	;--- Destruye la lista correspondiente al protocolo A

IP_DESTR_PROT:	call	IP_QUEUES
	ld	(ix),0
	ld	(ix+1),0
	ld	(ix+2),0
	push	hl
	pop	ix
	nesmani	22
	ret


	;--- PETICION DNS
	;    Entrada: HL = Puntero al nombre a resolver, en TPA
	;                  (acabado en 0, 32, 9, 13, 10 o 26)
	;	A  = Banderas:
	;            bit 0: Solo interrumpir consulta en curso
	;                   (ignora el resto de banderas y registros)
	;            bit 1: NO consultar los DNS
	;                   (interpretar el nombre como una IP)
	;            bit 2: NO interrumpir una posible consulta ya en curso
	;                   (devolver error en ese caso)
	;            bit 3: D y E significantes
	;            bit 4: BC significante
	;	D  = Intervalo de retransmision, en segundos
	;            (0: Usar DNS_TOUT_V)
	;	E  = Numero de retransmisiones por cada DNS
	;            (0: Usar DNS_RETRY_V)
	;	BC = Timeout total en segundos (max.1300)
	;            (0: Usar DNS_TTOUT_V)
	;    Salida:  Cy=1 y A=error:
	;             1: No hay conexion a internet
	;             2: Hay una consulta en curso (solo si A:1 establecido)
	;             3: No es una IP valida (solo si A:0 establecido)
	;             4: No hay DNS negociados
	;             5: Valor de BC excesivo
	;	Cy=0 y A=resultado:
	;             0: OK, consulta en curso (o cancelada)
	;             1: OK, el nombre era una IP directa
	;       HL, DE: Direccion IP (solo si se devuelve A=1)
	;		con el siguiente formato: L.H.E.D

IP_DNS_Q:	ld	(DNS_Q_FLAGS),a	;Primero comprueba si hay conexion a internet
	ld	(DNS_HL),hl
	ld	(DNS_DE),de
	ld	(DNS_BC),bc
	ld	ix,LOW_CHK_TLU
	call	CALL_LOWER
	or	a
	ld	a,1
	scf
	ret	z

	;Solo hay que abortar una consulta existente?

	ld	a,(DNS_Q_FLAGS)	;Si A:0=1, abortar consulta
	bit	0,a	;y terminar
	jr	z,DNS_NOAB
	ld	a,3
	ld	(DNS_STAT_P),a
	ld	a,18
	ld	(DNS_STAT_S),a
	jp	IP_DNS_AB
DNS_NOAB:	;

	;Hay una consulta en curso y no hay que abortarla?

	ld	(DNS_Q_FLAGS),a
	bit	2,a
	jr	z,IP_DNSQ2

	ld	a,(DNS_STAT_P)	;Si A:2=1 y existe una consulta en curso,
	cp	1	;devolver error 2
	ld	a,2
	scf
	ret	z
IP_DNSQ2:	;

	;Obtiene el nombre a resolver,
	;y primero comprueba si es una IP

	call	IP_DNS_AB	;A:2=0, aborta posible consulta en curso

	ld	ix,(DNS_HL)	;Copia cadena a BUFER_DNS
	ld	a,(#8002)
	ld	b,a
	ld	iy,BUFER_IN
	nesmani	15

	call	PARSE_IP
	jr	c,IP_DNSQ3

	ld	a,2	;Si era una IP, la devuelve
	ld	(DNS_STAT_P),a	;y establece estado como prim=2, sec=1
	dec	a
	ld	(DNS_STAT_S),a
	or	a
	ld	hl,(DNS_RESULT)
	ld	de,(DNS_RESULT+2)
	ret

IP_DNSQ3:	ld	a,(DNS_Q_FLAGS)	;Si no es una IP valida y se ha especificado
	bit	1,a	;"no consultar DNS", devuelve error 3
	scf
	ld	a,3
	ret	nz

	;No es una IP directa. Obtiene la direccion de los DNS

	ld	a,2
	ld	ix,LOW_IPS
	call	CALL_LOWER
	ld	a,h
	ld	(DNS_PRIM),a
	ld	a,l
	ld	(DNS_PRIM+1),a
	ld	a,d
	ld	(DNS_PRIM+2),a
	ld	a,e
	ld	(DNS_PRIM+3),a
	ld	a,3
	ld	ix,LOW_IPS
	call	CALL_LOWER
	ld	a,h
	ld	(DNS_SEC),a
	ld	a,l
	ld	(DNS_SEC+1),a
	ld	a,d
	ld	(DNS_SEC+2),a
	ld	a,e
	ld	(DNS_SEC+3),a

	ld	ix,DNS_PRIM	;Si no hay ningun DNS negociado,
	ld	a,(ix)	;devuelve error 4
	or	(ix+1)
	or	(ix+2)
	or	(ix+3)
	or	(ix+4)
	or	(ix+5)
	or	(ix+6)
	or	(ix+7)

	ld	a,4
	scf
	ret	z

	;Establece los parametros de timeouts y ReTx

	ld	hl,DNS_TOUT_V	;En principio establece
	ld	de,DNS_TOUT_NOW	;valores por defecto
	ld	bc,5
	ldir

	ld	a,(DNS_Q_FLAGS)
	bit	3,a
	jr	z,DNS_DE_2
	ld	a,(DNS_DE)	;A=DNS_RETRY
	or	a
	jr	z,DNS_DE_1
	ld	(DNS_RETRY_NOW),a
DNS_DE_1:	;

	ld	a,(DNS_DE+1)	;A=DNS_TOUT en seg.
	or	a
	jr	z,DNS_DE_2
	ld	l,a
	ld	h,0
	call	HLPOR50
	ld	(DNS_TOUT_NOW),hl
DNS_DE_2:	;

	ld	a,(DNS_Q_FLAGS)
	bit	4,a
	jr	z,DNS_BC_OK
	ld	hl,(DNS_BC)	;HL=DNS_TTOUT_NOW en seg.
	ld	a,h
	or	l
	jr	z,DNS_BC_OK

	ld	de,1301
	call	COMP
	ld	a,5
	ret	c
	call	HLPOR50
	ld	(DNS_TTOUT_NOW),hl
DNS_BC_OK:	;

	;Una vez establecidos los *_NOW,
	;establecemos los contadores reales

	ld	hl,DNS_TOUT_NOW
	ld	de,DNS_TOUT
	ld	bc,5
	ldir

	;Construimos el paquete UDP a enviar

	ld	hl,DNS_P
	ld	de,BUFER_DNS
	ld	bc,DNS_P_END-DNS_P
	ldir

	ld	hl,BUFER_IN
	ld	ix,BUFER_DNS+(DNS_P_END-DNS_P)
	call	GET_SERV
	ld	(ix),0	;Anyade QTYPE y QCLASS
	ld	(ix+1),1	;(inet, dir. IP)
	ld	(ix+2),0
	ld	(ix+3),1
	inc	ix
	inc	ix
	inc	ix
	inc	ix
	push	ix
	pop	hl
	ld	bc,BUFER_DNS
	or	a
	sbc	hl,bc
	ld	(DNS_P_SIZE),hl
	ld	bc,8
	or	a
	sbc	hl,bc
	ld	a,h
	ld	(BUFER_DNS+12),a	;Establece campo de tamanyo del
	ld	a,l	;paquete UDP
	ld	(BUFER_DNS+13),a

	;Ahora lo dejamos todo listo para que
	;el paquete se envie en la proxima int:
	;- Ponemos DNS_TOUT a 0
	;  (como si un temporizador previo hubiera expirado)
	;  para que el paquete se envie en la primera int.
	;- Ponemos DNS_STAT_P a 1 y DNS_STAT_S a 1 o a 2
	;  y copiamos DNS_PRIM o DNS_SEC a DNS_P

	ld	ix,DNS_PRIM
	ld	a,(ix)
	or	(ix+1)
	or	(ix+2)
	or	(ix+3)
	ld	a,1
	jr	nz,DNSPOK
	inc	a
	ld	ix,DNS_SEC
DNSPOK:	ld	(DNS_STAT_S),a
	push	ix
	pop	hl
	ld	de,BUFER_DNS
	ld	bc,4
	ldir

	ld	hl,(DNS_IDENTIF)
	inc	hl
	ld	(DNS_IDENTIF),hl
	ld	a,1
	ld	(DNS_STAT_P),a
	ld	hl,0
	ld	(DNS_TOUT),hl
	xor	a
	ret

	;Subrutina de cancelacion de la consulta actual

IP_DNS_AB:	xor	a
	ld	(DNS_STAT_P),a
	ld	(DNS_STAT_S),a
	ld	ix,DNS_IN_QUEUE
	call	FLUSH_QUEUE
	xor	a
	ret

DNS_Q_FLAGS:	db	0
DNS_HL:	dw	0
DNS_DE:	dw	0
DNS_BC:	dw	0


	;--- ESTADO DNS
	;    Entrada: A  = Banderas:
	;             bit 0: Limpiar cualquier resultado/error existente
	;                    despues de la llamada
	;                    (excepto si el estado es 1)
	;    Salida:  A  = Codigo de estado primario
	;             B  = Codigo de estado secundario
	;	A  = 0: No hay consulta en curso, ni resultado disponible
	;            1: Consulta en curso
	;               B=1: Consultando DNS primario
	;               B=2: Consultando DNS secundario
	;               B=3: Consultando otro DNS al que se nos ha redirigido
	;		2: Consulta completada, resultado en HL, DE
	;          en formato L.H.E.D
	;               B=0: El nombre no era una IP directa
	;               B=1: El nombre era una IP directa
	;		3: Error:
	;          B=1-15: Error devuelto por el DNS
	;          B=16: Alguno de los DNS no ha respondido
	;          (se han enviado DNS_RETRY_V peticiones sin respuesta)
	;          B=17: Timeout total expirado
	;          B=18: Consulta abortada por el usuario
	;          B=19: Se ha perdido la conexion a internet
	;          B=20: La respuesta no contenia REPLY ni AUTHORITATIVE
	;          B=21: La respuesta esta truncada

IP_DNS_S:	ld	c,a
	ld	a,(DNS_STAT_S)
	ld	b,a
	ld	a,(DNS_STAT_P)
	ld	hl,(DNS_RESULT)
	ld	de,(DNS_RESULT+2)
	bit	0,c
	ret	z
	push	af
	ld	a,(DNS_STAT_P)
	cp	1
	jr	z,IP_DNS_S2
	xor	a
	ld	(DNS_STAT_P),a
	ld	(DNS_STAT_S),a
IP_DNS_S2:	pop	af
	ret



;********************************************************
;***                                                  ***
;***  RUTINA DE ATENCION A LA INTERRUPCION DEL RELOJ  ***
;***                                                  ***
;********************************************************

;*** 1) Comprueba el estado de la capa inferior y lo compara
;       con el estado en la anterior interrupcion:
;    -- Ahora OFF y antes OFF: Termina
;    -- Ahora OFF y antes ON:  Vacia las colas PROT_OUT_QUEUE y IP_IN_QUEUE
;                              Inicializa vars y ctes
;                              Si hay consulta DNS en curso, establece error 19
;    -- Ahora ON  y antes OFF: Pregunta IP, MRU y MTU
;                              Pregunta IP_OUT_QUEUE
;                              Deduce la mascara de red
;    -- Ahora ON  y antes ON:  No hace nada y salta a 2)

IP_INT:	ld	ix,LOW_CHK_TLU
	call	CALL_LOWER
	ld	d,a
	ld	hl,LOWER_STATUS
	ld	e,(hl)
	ld	(hl),d	;D=Estado actual, E=Estado antiguo

	;--- ON y ON?

	ld	hl,#FFFF	;No hace nada especial
	call	COMP
	jp	z,END_IP_INT_1

	;--- OFF y OFF?

	ld	hl,0	;Termina
	call	COMP
	jp	z,PUTPAQ_END

	;--- ON y OFF?

	ld	hl,#FF00
	call	COMP
	jp	nz,IP_INT_3

	xor	a
	ld	ix,LOW_QUEUES	;Obtiene cola de salida
	call	CALL_LOWER
	ld	(IP_OUT_QUEUE),a
	ld	(IP_OUT_QUEUE+1),hl

	xor	a
	ld	ix,LOW_IPS	;Obtiene IP
	call	CALL_LOWER
	ld	ix,IP_LOCAL
	ld	(ix),h
	ld	(ix+1),l
	ld	(ix+2),d
	ld	(ix+3),e

	ld	a,(ix)	;Compone mascara de red
	ld	ix,NET_MASK	;eliminando los 1s comunes
	ld	iy,SUBNET_MASK	;de SUBNET_MASK
	ld	(ix),255
	ld	(iy),0
	bit	7,a	;0x.x.x.x --> 255.0.0.0
	jr	z,OKNETMASK
	ld	(ix+1),255
	ld	(iy+1),0
	bit	6,a	;10x.x.x.x --> 255.255.0.0
	jr	z,OKNETMASK
	ld	(ix+2),255
	ld	(iy+2),0
	bit	5,a	;110x.x.x.x --> 255.255.255.0
	jr	z,OKNETMASK
	ld	(ix+3),255	;111x.x.x.x --> ERROR, pone la
	ld	(iy+3),0
	jp	PUTPAQ_END	;mascara a 255.255.255.255 y termina
OKNETMASK:	;

	ld	hl,IP_LOCAL	;Calcula la parte de red de
	ld	ix,NET_MASK	;la dir IP local
	ld	de,IP_LOCAL_NET
	call	MASK_ADDRESS

	ld	a,(MASK_METHOD)
	or	a
	jr	nz,IP_INT_2
	ld	hl,IP_LOCAL	;Calcula la parte de subred de
	ld	ix,SUBNET_MASK	;la dir IP local si el metodo
	ld	de,IP_LOCAL_SUB	;de obtencion de la subred es 0
	call	MASK_ADDRESS
IP_INT_2:	;

	ld	ix,LOW_MXU	;Obtiene MTU y MRU
	call	CALL_LOWER
	ld	(MTU),hl
	ld	(MRU),de

	;*** PRUEBA: Encola un paquete con campos opcionales
	;    en PROT_OUT_QUEUE

	if	PBA_OUT=1

	jr	PAQPBA_END
POUT:	ld	a,(#8002)
	ld	b,a
	ld	a,(PROT_OUT_QUEUE)
	ld	ix,(PROT_OUT_QUEUE+1)
	ld	hl,PAQPBA_END-PAQPBA
	set	7,h
	ld	iy,PAQPBA
	nesman	28
	jr	PAQPBA_END

PAQPBA:	db	127,0,0,0
	db	1	;Protocolo
	db	4,134	;TTL
	db	0	;Fin campos opcionales
kkk:	db	8,0,#34,#8D	;ICMP de eco
	db	0,0,0,0
	db	"Esto sun paketeeeeee..."
PAQPBA_END:	db	0

	endif

	;*** PRUEBA: Encola un supuesto paquete entrante
	;    en IP_IN_QUEUE

	if	PBA_IN=1

	ld	a,(#8002)
	ld	b,a
	ld	a,(IP_IN_QUEUE)
	ld	ix,(IP_IN_QUEUE+1)
	ld	hl,PAQPBA2_END-PAQPBA2
	set	7,h
	ld	iy,PAQPBA2
	nesman	28
	jr	PAQPBA2_END

PAQPBA2:	db	#00,#21
	db	#47,0	;Version, TOS
	db	0,52	;Longitud
	db	0,0,0,0	;Id, flags, offset
	db	100,34	;TTL, protocolo
PAQPBA2_C:	db	#EA,#79	;Checksum
	db	5,6,7,8	;Origen
	db	1,2,3,4	;Destino
	db	10,20,30,40,50,0,0,0	;Opciones
	db	"Anda keste paketeee..."
PAQPBA2_END:	;

	endif

	;*** PRUEBA: Encola paquetes fragmentados

	if	PBA_FRAG=1

	jr	PFRAG_END
PFRAG:	ld	ix,PFRAG_PLIST	;Llamar con CALL
PFRAG_LOOP:	ld	l,(ix)
	ld	h,(ix+1)
	inc	ix
	inc	ix
	ld	a,h
	or	l
	ret	z	;jr      z,PFRAG_END

	push	ix
	ld	a,(#8002)
	ld	b,a
	push	hl
	pop	iy
	ld	hl,PFRAG_LEN
	set	7,h
	ld	a,(IP_IN_QUEUE)
	ld	ix,(IP_IN_QUEUE+1)
	nesman	28

	pop	ix
	jr	PFRAG_LOOP

PFRAG_END:	;

	endif

	jr	END_IP_INT_1
IP_INT_3:	;

	;--- OFF y ON

	call	INIT_VAR	;Inicializa vars y ctes
	ld	ix,IP_IN_QUEUE
	call	INIT_QUEUE	;Vacia colas
	ld	ix,PROT_OUT_QUEUE
	call	INIT_QUEUE
	ld	ix,FRAG_QUEUE
	call	INIT_QUEUE
	ld	ix,DNS_IN_QUEUE
	call	INIT_QUEUE

	ld	a,(DNS_STAT_P)
	cp	1
	jr	nz,END_IP_INT_1
	ld	a,3
	ld	(DNS_STAT_P),a
	ld	a,19
	ld	(DNS_STAT_S),a

END_IP_INT_1:	;


;*** 2) Configuracion de la mascara de subred
;    2.1.) Obtencion de la mascara:
;    -- Si MASK_METHOD=0, no hacer nada.
;    -- Si MASK_METHOD=1 y MASK_STATUS=1, no hacer nada.
;    -- Si MASK_METHOD=1 y MASK_STATUS=0, enviar paquete "Mask request"
;       si no se han enviado ya MASK_REQ_NUM paquetes y el temporizador
;       ha llegado al valor MASK_REQ_INT.
;    (Si se recibe "Mask reply", se pondra MASK_STATUS a 1)
;    2.2.) Envio de la mascara, solo en los siguientes casos:
;          - MASK_METHOD=0
;          - MASK_METHOD=1 y MASK_STATUS=1
;    -- Si MASK_REP_AUTH=#FF y MASK_REP_SENT=0,
;       enviar "Mask reply" y poner MASK_REP_SENT=#FF
;    (Si se recibe "Mask request", estamos en uno de los dos casos
;     y MASK_REP_AUTH=#FF, se enviara un "Mask reply")

	;--- Obtencion de la mascara

CONFSUB_1:	ld	a,(MASK_METHOD)	;Si MASK_METHOD=0, no hace nada
	or	a
	jr	z,CONFSUB_2
	ld	a,(MASK_STATUS)	;Si MASK_STATUS<>0, no hace nada
	or	a
	jr	nz,CONFSUB_2

	ld	a,(MASK_REQ_NUM)	;Si ya se han enviado MASK_REQ_NUM
	ld	hl,MASK_REQ_SENT	;paquetes "Mask request",
	cp	(hl)	;no hace nada
	jr	z,CONFSUB_2

	ld	a,(MASK_REQ_SENT)	;Si no se ha enviado ningun
	or	a	;paquete, se envia uno sin esperar
	jr	z,CONFSUB_0

	ld	hl,(MASK_REQ_TIMER)	;Actualiza temporizador
	inc	hl	;    ;de envio de "Mask request",
	ld	(MASK_REQ_TIMER),hl	;y si no ha llegado
	ld	de,(MASK_REQ_INT)	;    ;a MASK_REQ_INT,
	call	COMP	;    ;no hace nada
	jr	nz,CONFSUB_2

CONFSUB_0:	ld	hl,0	;    ;Reinicia temporiz. e incrementa
	ld	(MASK_REQ_TIMER),hl	;contador de "Mask request"
	ld	hl,MASK_REQ_SENT	;    ;enviados
	inc	(hl)

	ld	hl,MASKREQ_P_END-MASKREQ_P
	set	7,h
	ld	a,(#8002)	;Encola paquete "Mask request"
	ld	b,a
	ld	a,(PROT_OUT_QUEUE)
	ld	ix,(PROT_OUT_QUEUE+1)
	ld	iy,MASKREQ_P
	nesman	28

	ld	a,(MASK_REQ_NUM)	;Si ya se han enviado MASK_REQ_NUM
	ld	hl,MASK_REQ_SENT	;paquetes "Mask request",
	cp	(hl)	;pone MASK_TIMEOUTED a #FF
	jr	nz,CONFSUB_2
	ld	a,#FF
	ld	(MASK_TIMEOUTED),a

	;--- Envio automatico de la mascara

CONFSUB_2:	ld	a,(MASK_METHOD)	;MASK_METHOD=0?
	or	a
	jr	z,OK_SNDMASK

	ld	a,(MASK_STATUS)	;MASK_STATUS=1?
	or	a
	jp	z,CONFSUB_END

OK_SNDMASK:	ld	a,(MASK_REP_AUTH)	;Estamos autorizados?
	or	a
	jp	z,CONFSUB_END

	ld	a,(MASK_REP_SENT)	;Hemos enviado ya la mascara?
	or	a
	jr	nz,CONFSUB_END

	ld	hl,IP_BROAD
	ld	de,MASKREP_P	;Direccion de destino: broadcast
	ld	bc,4
	ldir
	ld	a,#FF	;Activa el flag "paq. enviado"
	ld	(MASK_REP_SENT),a

	ld	ix,NET_MASK	;Compone la mascara
	ld	iy,SUBNET_MASK
	ld	a,(ix)
	or	(iy)
	ld	(MASKREP_MASK),a
	ld	a,(ix+1)
	or	(iy+1)
	ld	(MASKREP_MASK+1),a
	ld	a,(ix+2)
	or	(iy+2)
	ld	(MASKREP_MASK+2),a
	ld	a,(ix+3)
	or	(iy+3)
	ld	(MASKREP_MASK+3),a

	ld	hl,0
	ld	(MASKREP_P_CS),hl
	ld	ix,MASKREP_P+6	;Calculo del checksum del paquete
	ld	bc,12	;"Mask reply"
	call	CALC_CHKSUM
	dec	de
	ld	a,e
	cpl
	ld	(MASKREP_P_CS),a
	ld	a,d
	cpl
	ld	(MASKREP_P_CS+1),a

	ld	hl,MASKREP_P_END-MASKREP_P
	set	7,h
	ld	a,(#8002)	;Encola paquete "Mask reply"
	ld	b,a
	ld	a,(PROT_OUT_QUEUE)
	ld	ix,(PROT_OUT_QUEUE+1)
	ld	iy,MASKREP_P
	nesman	28
CONFSUB_END:	;


;*** 3) Tratamiento de un paquete entrante
;    - Si no es un paquete IP puro (primer word = #0021 o #0020), ignorarlo
;    - Si la version del protocolo no es 4, ignorarlo
;    - Si el checksum es invalido, ignorarlo
;    - Direccion de origen:
;      * Si el primer byte es 127, ignorarlo
;      * Si la parte de red o la de host es 255, ignorarlo
;      * Si no es de clase A, B o C, ignorarlo
;    - Direccion de destino:
;      * Si el primer byte es 127, ignorarlo
;      * Si no es de clase A, B o C, ignorarlo
;      * Si no es la nuestra o un broadcast valido, ignorarlo
;      * Si el broadcast es valido pero no era broadcast de enlace, ignorarlo
;        (broadcast de enlace si el LSB del primer word es 0)
;    - Si el "Fragment offset" <>0 o el flag "More fragments" esta a 1,
;      ingorarlo (PRUEBAS! La version definitiva soportara fragmentacion)
;    - Si no existe cola para el protocolo especificado, enviar un
;      mensaje ICMP "Destination unreachable for protocol".
;    - Si no es ICMP, encolar paquete en la cola del protocolo adecuado
;    - Si se trata de un mensaje ICMP "Mask request", enviar "Mask reply"
;      si MASK_REP_AUTH=#FF y estamos en uno de estos casos:
;          * MASK_METHOD=0
;          * MASK_METHOD=1 y, o MASK_STATUS=1, o MASK_TIMEOUTED=#FF
;    - Si se trata de un mensaje ICMP "Mask reply", actualizar SUBNET_MASK
;      y poner MASK_STATUS a 1
;    - Si es un mensaje ICMP de error, encolarlo segun el protocolo
;      correspondiente
;    - Si es un mensaje ICMP "query", encolarlo en la cola de ICMP (prot. 1)
;    - Si es un mensaje ICMP desconocido, ignorarlo
;    ! Los paquetes se encolan tal cual llegan, con dos bytes al principio
;      apuntando a la zona de datos (en little-endian)

	;--- Obtiene paquete

GETPAQ:	ld	a,(#8002)
	ld	l,a
	ld	a,(IP_IN_QUEUE)
	ld	ix,(IP_IN_QUEUE+1)
	ld	b,2
	ld	h,3
	ld	iy,BUFER_IN-2
	nesman	29
	jp	c,GETPAQ_END	;Termina si no hay paquetes
	dec	bc
	dec	bc
	ld	(LAST_P_TSIZE),bc

	;--- Comprueba que sea IP puro (no VJ)

	ld	hl,(BUFER_IN-2)
	set	0,h
	ld	de,#2100
	call	COMP
	jp	nz,GETPAQ_END

	;--- Comprueba version IP

	ld	a,(BUFER_IN)
	and	#F0
	cp	#40
	jp	nz,GETPAQ_END

	;--- Comprueba checksum

	ld	a,(BUFER_IN)
	and	#0F
	ld	l,a
	ld	h,0	;HL=Tamanyo cabecera en words-32
	add	hl,hl
	add	hl,hl	;HL=T. C. en bytes
	ld	(LAST_P_HSIZE),hl

	if	IGNORE_CHK_IN=0

	push	hl
	pop	bc
	ld	ix,BUFER_IN
	call	CALC_CHKSUM
	ld	a,d
	or	e
	jp	nz,GETPAQ_END

	endif

	ld	hl,(LAST_P_TSIZE)	;De paso obtiene la longitud
	ld	bc,(LAST_P_HSIZE)	;de la zona de datos
	or	a
	sbc	hl,bc
	ld	(LAST_P_DSIZE),hl

	;--- Comprueba la direccion de origen

	;Primer byte=127?

	ld	a,(BUFER_IN+12)
	cp	127
	jp	z,GETPAQ_END
GETPAQ_OKSADD1:	;

	;No es de clase A, B, C?

	ld	a,(BUFER_IN+12)
	and	%11100000
	cp	%11100000
	jp	z,GETPAQ_END

	;Es broadcast de algun tipo?

	ld	ix,BUFER_IN+12	;Es broadcast si CHECK_ADD
	call	CHECK_ADD	;devuelve A>3
	ld	b,a
	and	%11111100
	jp	nz,GETPAQ_END
	ld	a,b
	cp	1
	jp	z,GETPAQ_OKSADD2

	;La direccion es 0 y no lo permitimos?

	ld	a,(ZERO_IP_VALID)
	or	a
	jr	nz,GETPAQ_OKSADD2
	ld	a,b
	and	%11
	jp	nz,GETPAQ_END
GETPAQ_OKSADD2:	;

	;--- Comprueba direccion de destino

	;Primer byte=127?

	ld	a,(BUFER_IN+16)
	cp	127
	jp	z,GETPAQ_END
GETPAQ_OKSADD3:	;

	;No es de clase A, B, C?

	ld	a,(BUFER_IN+16)
	and	%11100000
	cp	%11100000
	jp	z,GETPAQ_END

	;Es la nuestra?

	xor	a
	ld	(PAQ_IS_BROAD),a
	ld	ix,BUFER_IN+16
	call	CHECK_ADD
	ld	b,a
	cp	1
	jr	z,GETPAQ_OKDADD

	;Es broadcast tanto de IP como de enlace?

	ld	a,b	;Si CHECK_ADD devuelve A<4
	and	%11111100	;es que no es broadcast
	jp	z,GETPAQ_END

	ld	a,(BUFER_IN+1)	;Broadcast de enlace?
	bit	0,a
	jp	nz,GETPAQ_END
	ld	a,#FF
	ld	(PAQ_IS_BROAD),a
GETPAQ_OKDADD:	;

	;--- Comprueba si el protocolo es UDP y el puerto es DNS_PORT,
	;    en ese caso da el paquete por bueno directamente
	;    y lo encola en DNS_IN_QUEUE

	ld	a,(BUFER_IN+9)	;Comprueba si es UDP
	cp	17
	jr	nz,NO_DNS

kkkk:	ld	ix,BUFER_IN	;Comprueba el checksum UDP
	ld	bc,(LAST_P_HSIZE)
	ld	b,0
	add	ix,bc
	ld	hl,IP_LOCAL
	ld	de,BUFER_IN+12
	ld	bc,(LAST_P_DSIZE)
	call	UDP_CHKSUM
	ld	a,d
	or	e
	jp	nz,GETPAQ_END

	ld	a,(LAST_P_HSIZE)	;Comprueba el puerto
	ld	c,a
	ld	b,0
	ld	hl,BUFER_IN
	add	hl,bc
	inc	hl
	inc	hl
	ld	a,(hl)
	ld	e,a
	inc	hl
	ld	a,(hl)
	ld	d,a
	ld	hl,DNS_PORT
	call	COMP
	jr	nz,NO_DNS

	ld	a,(DNS_STAT_P)	;Ignora el paquete si no hay
	cp	1	;peticion DNS en curso
	jp	nz,GETPAQ_END

	ld	ix,BUFER_IN-2	;Encola el paquete de la misma forma que ENQUEUE_IN
	ld	a,(LAST_P_HSIZE)
	ld	(ix+1),a
	ld	h,(ix+4)
	ld	l,(ix+5)
	inc	hl	;HL=Longitud total en bytes
	push	ix
	pop	iy	;IY=Direccion del paquete
	inc	iy
	set	7,h
	ld	a,(#8002)
	ld	b,a
	ld	a,(DNS_IN_QUEUE)
	ld	ix,(DNS_IN_QUEUE+1)
	nesman	28
	jp	GETPAQ_END
NO_DNS:	;

	;--- Comprueba si existe cola para el protocolo especificado
	;    y si no, envia paquete "Protocol unreachable"

	ld	a,(BUFER_IN+9)
	call	IP_QUEUES
	or	h
	or	l
	jr	nz,GETPAQ_OKPROT

	ld	a,(PAQ_IS_BROAD)	;No envia nada si el paquete
	or	a	;es broadcast
	jp	nz,GETPAQ_END

	ld	ix,BUFER_IN+12	;No envia nada si la direccion
	call	CHECK_ADD	;es 0.0.0.0 o 0,<Host>
	cp	2
	jp	z,GETPAQ_END
	cp	3
	jp	z,GETPAQ_END

	ld	hl,(LAST_P_HSIZE)	;Copia la cabecera del paquete
	ld	bc,8	;problematico+los 8 primeros
	add	hl,bc	;bytes de datos al paquete ICMP
	push	hl
	pop	bc
	ld	hl,BUFER_IN
	ld	de,PROTUN_P_H
	push	bc
	ldir

	pop	hl
	ld	bc,8
	add	hl,bc	;HL=Long. total paquete ICMP
	push	hl,hl
	pop	bc

	ld	de,0
	ld	(PROTUN_P_CS),de
	ld	ix,PROTUN_P+6
	call	CALC_CHKSUM
	dec	de
	ld	a,e
	cpl
	ld	(PROTUN_P_CS),a
	ld	a,d
	cpl
	ld	(PROTUN_P_CS+1),a

	ld	hl,BUFER_IN+12	;Establece dir. de destino
	ld	de,PROTUN_P	;como la de origen
	ld	bc,4
	ldir

	pop	hl
	ld	bc,6
	add	hl,bc	;HL=Long. total incluyendo h. IP
	ld	a,(#8002)	;Encola paquete
	ld	b,a
	ld	a,(PROT_OUT_QUEUE)
	ld	ix,(PROT_OUT_QUEUE+1)
	ld	iy,PROTUN_P
	set	7,h
	nesman	28
GETPAQ_OKPROT:	;

	;--- Si "Fragment offset"<>0 o "More fragments"=1,
	;    salta a la rutina de proceso de fragmentos

	ld	ix,BUFER_IN	;IX=Principio del paquete
	ld	a,(ix+6)	;Offset + MF
	and	%00111111	;Elimina flags innecesarios
	or	(ix+7)
	jp	nz,FRAG_PROCESS

	;--- Si no es ICMP, lo encola adecuadamente y termina

	ld	a,(BUFER_IN+9)
	cp	1
	jr	z,GETPAQ_ICMP
	ld	ix,BUFER_IN-2
	call	ENQUEUE_IN
	jp	GETPAQ_END

	;--- Es ICMP: Calcula checksum y obtiene puntero
	;    al paquete propiamente dicho

GETPAQ_ICMP:	ld	hl,(LAST_P_HSIZE)
	ld	bc,BUFER_IN
	add	hl,bc
	push	hl
	pop	ix	;IX apunta ahora al paquete ICMP
	ld	bc,(LAST_P_DSIZE)

	if	IGNORE_CHK_IN=0

	bit	0,c	;Anyade un 0 si es necesario
	jr	z,OKEVEN2	;para calcular el checksum
	push	ix	;(el num de bytes ha de ser par)
	pop	hl
	add	hl,bc
	ld	(hl),0
	inc	bc
OKEVEN2:	;

	call	CALC_CHKSUM
	ld	a,d
	or	e
	jp	nz,GETPAQ_END	;No hace nada si chksum incorrecto

	endif

	ld	a,(ix)	;A=Tipo de paquete ICMP

	;--- Si es "Mask request", envia respuesta si procede

	cp	17
	jp	nz,GETPAQ_ICMP3

	ld	a,(MASK_REP_AUTH)	;Estamos autorizados a resp.?
	or	a
	jp	nz,GETPAQ_END
	ld	a,(MASK_METHOD)	;MASK_METHOD es 0 (conf. estat.)?
	or	a
	jr	z,OK_ICMP_17
	ld	a,(MASK_STATUS)	;MASK_STATUS es 1 (ya tenemos mask)?
	cp	1
	jr	z,OK_ICMP_17	;Time out de peticion de mascara?
	ld	a,(MASK_TIMEOUTED)
	or	a
	jp	z,GETPAQ_END

OK_ICMP_17:	ld	ix,NET_MASK	;Compone la mascara
	ld	iy,SUBNET_MASK
	ld	a,(ix)
	or	(iy)
	ld	(MASKREP_MASK),a
	ld	a,(ix+1)
	or	(iy+1)
	ld	(MASKREP_MASK+1),a
	ld	a,(ix+2)
	or	(iy+2)
	ld	(MASKREP_MASK+2),a
	ld	a,(ix+3)
	or	(iy+3)
	ld	(MASKREP_MASK+3),a

	ld	hl,BUFER_IN+12
	ld	de,MASKREP_P	;Establece dir de destino
	ld	bc,4
	ldir

	ld	hl,0
	ld	(MASKREP_P_CS),hl
	ld	ix,MASKREP_P+6
	ld	bc,12
	call	CALC_CHKSUM	;Calcula checksum
	dec	de
	ld	a,e
	cpl
	ld	(MASKREP_P_CS),a
	ld	a,d
	cpl
	ld	(MASKREP_P_CS+1),a

	ld	hl,MASKREP_P_END-MASKREP_P
	set	7,h
	ld	a,(#8002)	;Encola paquete "Mask reply"
	ld	b,a
	ld	a,(PROT_OUT_QUEUE)
	ld	ix,(PROT_OUT_QUEUE+1)
	ld	iy,MASKREP_P
	nesman	28

	jp	GETPAQ_END

	;--- Si es "Mask reply", actualiza mascara

GETPAQ_ICMP3:	cp	18
	jr	nz,GETPAQ_ICMP4

	ld	a,(MASK_METHOD)	;Si conf. estatica, ignora paquete
	or	a
	jp	z,GETPAQ_END

	ld	a,1
	ld	(MASK_STATUS),a

	push	ix	;Copia la mascara a SUBNET_MASK
	pop	hl
	ld	bc,8
	add	hl,bc
	ld	de,SUBNET_MASK
	ld	bc,4
	ldir

	ld	de,NET_MASK
	ld	hl,SUBNET_MASK
	ld	b,4
SETSUBM_LOOP:	ld	a,(de)	;Elimina la parte de red
	cpl		;                ;de la mascara de subred
	and	(hl)
	ld	(hl),a
	inc	hl
	inc	de
	djnz	SETSUBM_LOOP

	jp	GETPAQ_END

	;--- Si es un mensaje ICMP de error, encolarlo
	;    segun el protocolo correspondiente

GETPAQ_ICMP4:	cp	3	;Es un mensaje "error"?
	jr	z,GETPAQ_ICMP5
	cp	4
	jr	z,GETPAQ_ICMP5
	cp	5
	jr	z,GETPAQ_ICMP5
	cp	11
	jr	z,GETPAQ_ICMP5
	cp	12
	jr	z,GETPAQ_ICMP5
	jr	GETPAQ_ICMP6

GETPAQ_ICMP5:	ld	a,(ix+8+9)	;En IX+8 empieza la cabecera
	ld	ix,BUFER_IN-2
	call	ENQUEUE_IN2	;del paq. problematico,
	jp	GETPAQ_END	;luego en IX+8+9 esta el prot.

	;--- Si es un mensaje ICMP "Echo request",
	;    se envia "Echo reply"

GETPAQ_ICMP6:	cp	8
	jr	nz,GETPAQ_ICMP7

	ld	a,(IGNORE_ECHO)	;Se ha de ignorar?
	or	a
	jp	nz,GETPAQ_END

	;Compone pseudocabecera como:
	;dir origen
	;1 (protocolo ICMP)
	;4,#FF (TTL=255)
	;0 (fin pseudocabecera)

	ld	hl,BUFER_IN+12
	ld	de,BUFER_COMP
	ld	bc,4
	ldir
	ld	hl,#0401
	ld	(BUFER_COMP+4),hl
	ld	hl,#00FF
	ld	(BUFER_COMP+6),hl

	;Copia la parte de datos

	push	ix
	pop	hl
	ld	de,BUFER_COMP+8
	ld	bc,(LAST_P_DSIZE)
	ldir
	xor	a	;Cambia codigo a "Echo reply"
	ld	(BUFER_COMP+8),a

	;Calcula checksum

	ld	bc,(LAST_P_DSIZE)
	bit	0,c	;Anyade un 0 si es necesario
	jr	z,OKEVEN	;para calcular el chksum
	ex	de,hl	;(el num de bytes ha de ser par)
	ld	(hl),0
	inc	bc
OKEVEN:	;

	ld	hl,0
	ld	(BUFER_COMP+8+2),hl
	ld	ix,BUFER_COMP+8
	call	CALC_CHKSUM
	dec	de
	ld	a,e
	cpl
	ld	(BUFER_COMP+8+2),a
	ld	a,d
	cpl
	ld	(BUFER_COMP+8+3),a

	;Encola el paquete

	ld	hl,(LAST_P_DSIZE)
	ld	bc,8
	add	hl,bc	;Tamanyo=pseudocabecera+datos
	set	7,h
	ld	a,(#8002)
	ld	b,a
	ld	a,(PROT_OUT_QUEUE)
	ld	ix,(PROT_OUT_QUEUE+1)
	ld	iy,BUFER_COMP
	nesman	28

	jr	GETPAQ_END

	;--- Si es un mensaje ICMP "Query", encolarlo
	;    en la cola ICMP; si no, es desconocido: ignorarlo

GETPAQ_ICMP7:	or	a	;Es un mensaje "query"?
	jr	z,GETPAQ_ICMP8
	cp	8
	jr	z,GETPAQ_ICMP8
	cp	15
	jr	z,GETPAQ_ICMP8
	cp	16
	jr	z,GETPAQ_ICMP8
	jr	GETPAQ_END

GETPAQ_ICMP8:	ld	ix,BUFER_IN-2	;Encola paquete
	call	ENQUEUE_IN
GETPAQ_END:	;


;*** 4) Tratamiento de un paquete saliente
;    - Formato de un paquete saliente:
;      * Direccion de destino (4 bytes)
;      * Protocolo (1 byte)
;      * Campos opcionales
;        (en cualquier orden, pero todos tras el prot. y antes de los datos):
;        1 + Byte TOS (por defecto 0)
;        2 (DF OFF) o 3 (DF ON) (por defecto OFF)
;        4 + TTL (por defecto TTL_DEFAULT)
;        5 + Long. opciones + opciones (por def. no hay opciones)
;        6 + Direccion origen (por def. es la nuestra)
;        0 (fin de campos opcionales)
;      * Datos (al final de todo lo anterior)
;    - Componer el paquete con la cabecera, las opciones si hay y los datos
;    - Si el paquete resultante es mayor de 2048 bytes o que MTU, eliminarlo
;    - Si el primer byte de la direccion de destino es 127,
;      enviar paquete a nosotros mismos si hay cola para el protocolo
;    - Poner el paquete en la cola de salida

	;--- Extrae un paquete de PROT_OUT_QUEUE si hay

PUTPAQ:	ld	b,2
	ld	h,3
	ld	a,(#8002)
	ld	l,a
	ld	iy,BUFER_OUT
	ld	a,(PROT_OUT_QUEUE)
	ld	ix,(PROT_OUT_QUEUE+1)
	nesman	29
	jp	c,PUTPAQ_END
	ld	(PUT_P_PSIZE),bc

	;--- Se copia primero una cabecera por defecto
	;    con todos los campos a 0 salvo el TTL y la dir. origen

	ld	hl,BUFER_COMP
	ld	de,BUFER_COMP+1
	ld	bc,19
	ld	(hl),0
	ldir

	ld	a,(TTL_DEFAULT)	;TTL
	ld	(BUFER_COMP+8),a

	ld	hl,IP_LOCAL	;Dir. de origen
	ld	de,BUFER_COMP+12
	ld	bc,4
	ldir

	;--- Establece direccion de destino y protocolo
	;    (si dir es 127.x.x.x, ponemos la nuestra)

	ld	hl,BUFER_OUT
	ld	a,(BUFER_OUT)
	cp	127
	jr	nz,PUTPAQ0
	ld	hl,IP_LOCAL
PUTPAQ0:	ld	de,BUFER_COMP+16
	ld	bc,4
	ldir

	ld	a,(BUFER_OUT+4)	;Protocolo
	ld	(BUFER_COMP+9),a

	;--- Establece los campos opcionales.
	;    Si encuentra un codigo desconocido,
	;    se descarta el paquete.

	ld	ix,BUFER_OUT+5	;Tras el protocolo
	xor	a
	ld	(OPTIONS_LEN),a
	ld	a,20
	ld	(PUT_P_HSIZE),a

OPFIELD_LOOP:	ld	a,(ix)

	;* 0: Fin de campos opcionales

OPFIELD_0:	or	a
	jr	nz,OPFIELD_1

	inc	ix
	jp	OPFIELD_OK

	;* 1: Byte TOS

OPFIELD_1:	cp	1
	jr	nz,OPFIELD_2

	ld	a,(ix+1)
	ld	(BUFER_COMP+1),a
	inc	ix
	inc	ix
	jr	OPFIELD_LOOP

	;* 2: DF OFF - No es necesario hacer nada

OPFIELD_2:	cp	2
	jr	nz,OPFIELD_3

	inc	ix
	jr	OPFIELD_LOOP

	;* 3: DF ON

OPFIELD_3:	cp	3
	jr	nz,OPFIELD_4

	ld	a,%01000000
	ld	(BUFER_COMP+6),a

	inc	ix
	jr	OPFIELD_LOOP

	;* 4: TTL

OPFIELD_4:	cp	4
	jr	nz,OPFIELD_5

	ld	a,(ix+1)
	ld	(BUFER_COMP+8),a
	inc	ix
	inc	ix
	jr	OPFIELD_LOOP

	;* 5: Opciones

OPFIELD_5:	cp	5
	jr	nz,OPFIELD_6

	ld	c,(ix+1)
	ld	b,0
	push	bc
	inc	ix
	inc	ix
	push	ix
	pop	hl
	ld	de,BUFER_COMP+20
	ldir		;                ;Copia opciones tras la cabecera
	pop	bc
	push	bc	;BC = Long. opciones
	ex	de,hl	;HL apunta tras las opciones

OPFIELD_5_LOOP:	ld	a,c	;Anyade relleno si es necesario
	and	%11	;(hasta que long. op. sea 4*N)
	jr	z,OPFIELD_5_OK
	ld	(hl),0
	inc	hl
	inc	bc
	jr	OPFIELD_5_LOOP
OPFIELD_5_OK:	;

	ld	a,c
	ld	(OPTIONS_LEN),a
	add	20
	ld	(PUT_P_HSIZE),a
	pop	bc
	add	ix,bc
	jr	OPFIELD_LOOP

	;* 6: Direccion de origen

OPFIELD_6:	cp	6	;Si no es 6, desconocida->descartar
	jp	nz,PUTPAQ_END

	inc	ix
	push	ix
	pop	hl
	ld	de,BUFER_COMP+12
	ld	bc,4
	ldir

	inc	ix
	inc	ix
	inc	ix
	inc	ix
	jp	OPFIELD_LOOP

	;En este punto, IX apunta a los datos en el paquete
	;original del usuario (dir+prot+campos op.+datos)

OPFIELD_OK:	ld	bc,BUFER_OUT
	push	ix
	pop	hl
	ld	(PUT_P_DPNT),hl	;HL apunta a los datos
	or	a
	sbc	hl,bc	;Ahora HL=Long. dir+prot+campos op.
	push	hl
	pop	bc
	ld	hl,(PUT_P_PSIZE)	;HL = Long. paq. encolado por usuario
	or	a
	sbc	hl,bc	;HL = Long. datos
	ld	(PUT_P_DSIZE),hl
	ld	bc,(PUT_P_HSIZE)
	add	hl,bc
	ld	(PUT_P_TSIZE),hl	;HL = Long. cabecera + datos

	;--- Establece los campos restantes

	;* IHL y Version IP

	ld	a,(PUT_P_HSIZE)
	srl	a
	srl	a
	ld	b,a
	and	%11110000	;Si cabecera>64 bytes, descartar
	jp	nz,PUTPAQ_END
	ld	a,b
	set	6,a	;Version IP = 4
	ld	(BUFER_COMP),a

	;* Longitud total

	ld	hl,(PUT_P_TSIZE)
	ld	a,h
	ld	(BUFER_COMP+2),a
	ld	a,l
	ld	(BUFER_COMP+3),a

	;* Identificacion

	ld	hl,(IP_IDENTIF)
	ld	a,h
	ld	(BUFER_COMP+4),a
	ld	a,l
	ld	(BUFER_COMP+5),a
	inc	hl
	ld	(IP_IDENTIF),hl

	;* Checksum

	ld	ix,BUFER_COMP
	ld	bc,(PUT_P_HSIZE)
	call	CALC_CHKSUM
	dec	de
	ld	a,e
	cpl
	ld	(BUFER_COMP+10),a
	ld	a,d
	cpl
	ld	(BUFER_COMP+11),a

	;* Copia los datos

	ld	hl,BUFER_COMP
	ld	bc,(PUT_P_HSIZE)
	add	hl,bc
	ex	de,hl
	ld	hl,(PUT_P_DPNT)
	ld	bc,(PUT_P_DSIZE)
	ldir

	;--- Comprueba si el paquete es mayor que 2048 bytes o MTU,
	;    en ese caso lo descarta

	ld	hl,(PUT_P_TSIZE)
	ld	de,(MTU)
	inc	de
	call	COMP
	jr	c,PUTPAQ_END
	ld	de,2049
	call	COMP
	jr	c,PUTPAQ_END

	;--- Si la dir es nuestra, nos lo encolamos a nosotros
	;    mismos; si no, lo encolamos en IP_OUT_QUEUE

	ld	ix,BUFER_COMP+16	;Nuestra IP?
	call	CHECK_ADD
	cp	1
	jr	nz,PUTPAQ_ENQ

PUTPAQ_SELF2:	ld	hl,#2100	;Lo encola como si fuera externo
	ld	(BUFER_COMP-2),hl
	ld	hl,(PUT_P_TSIZE)
	inc	hl
	inc	hl
	ld	a,(#8002)
	ld	b,a
	set	7,h
	ld	a,(IP_IN_QUEUE)
	ld	ix,(IP_IN_QUEUE+1)
	ld	iy,BUFER_COMP-2
	nesman	28
	jr	PUTPAQ_END

PUTPAQ_ENQ:	ld	hl,#2100	;Lo encola en IP_OUT_QUEUE
	ld	(BUFER_COMP-2),hl
	ld	a,(#8002)
	ld	b,a
	ld	hl,(PUT_P_TSIZE)
	inc	hl
	inc	hl
	set	7,h
	ld	iy,BUFER_COMP-2
	ld	a,(IP_OUT_QUEUE)
	ld	ix,(IP_OUT_QUEUE+1)
	nesman	28
PUTPAQ_END:	;


;*** 6) Examen de los temporizadores de fragmentacion
;    - Incrementar el contador de todos los paquetes pendientes
;    - Si alguno llega al valor FRAG_TIMEOUT, hay que
;      descartar el paquete y enviar un ICMP "Fragmentation timeout"

	;--- Primero comprueba que realmente haya
	;    buferes de fragmentacion pendientes

FRAG_TEMP_EXP:	ld	a,(NUM_FRAG_PEND)
	or	a
	jp	z,FRAG_TEMP_END

	;--- Para cada bufer decrementa el contador
	;    y comprueba si ha llegado a 0
	;    (se inicializa a FRAG_TIMEOUT al llegar el 1er frag.)
	;    Si ha llegado a 0, se borra el paquete pendiente
	;    y se envia "Fragmentation timeout"

	ld	ix,FRAG_TABLE+2
	ld	a,1
	ld	(CUR_FRAG),a

FRAG_TEMP_LOOP:	ld	l,(ix)	;HL = Valor actual temporizador
	ld	h,(ix+1)	;Si es 0, se ha llegado al final
	ld	a,h	;de la tabla.
	or	l
	jp	z,FRAG_TEMP_END

	dec	hl	;Decrementa contador, y si no
	ld	(ix+0),l	;ha llegado a 0, pasa al siguiente
	ld	(ix+1),h
	ld	a,h
	or	l
	jr	nz,FRAG_TEMP_NEXT

	ld	a,(CUR_FRAG)
	call	FRAG_TEMP_TOUT	;Envia paquete "Fragmentation
	call	DEL_FRAG3	;time out"

FRAG_TEMP_NEXT:	ld	hl,CUR_FRAG	;Siguiente fragmento
	inc	(hl)
	inc	ix
	inc	ix
	jr	FRAG_TEMP_LOOP

	jp	FRAG_TEMP_END

	;--- Subrutina de envio de "Fragmentation timeout"
	;    Entrada: A=Numero de bufer
	;    Debe preservar: IX, A

FRAG_TEMP_TOUT:	push	ix,af
	call	_FRAG_TEMP_TOUT
	pop	af,ix
	ret

_FRAG_TEMP_TOUT:	;* Establece el puntero de la lista y extrae el elemento

	ld	iyl,a	;Establece puntero
	ld	iyh,0
	ld	h,0
	ld	b,5
	ld	a,(FRAG_QUEUE)
	ld	ix,(FRAG_QUEUE+1)
	nesman	23
	jp	c,FRAG_TEMP_END

	ld	a,(#8002)	;Extrae elemento a BUFER_COMP
	ld	l,a	;y al mismo tiempo lo elimina
	ld	a,(FRAG_QUEUE)
	ld	ix,(FRAG_QUEUE+1)
	ld	b,0
	ld	h,3
	ld	iy,BUFER_COMP
	nesman	29

	;* Compone paquete ICMP

	ld	hl,BUFER_COMP+12	;Establece dir. de destino
	ld	de,FRAGTOUT_P	;como la de origen del paquete
	ld	bc,4	;original
	ldir

	ld	a,(BUFER_COMP)	;Copia cabecera al paquete ICMP
	and	#0F	;(es la cabecera IP del primer
	ld	l,a	;fragmento que ha llegado, o del
	ld	h,0	;fragmento con offset 0)
	add	hl,hl
	add	hl,hl
	push	hl
	pop	bc
	push	hl
	pop	ix	;IX = Longitud cabecera
	ld	hl,BUFER_COMP
	ld	de,FRAGTOUT_P_H
	ldir

	ld	a,(BUFER_COMP+6)	;Busca en el bufer los datos
	and	%00011111	;correspondientes a ese fragmento,
	ld	h,a	;basandose en el campo "Offset",
	ld	a,(BUFER_COMP+7)	;y los copia al paquete ICMP
	ld	l,a	;tras la cabecera IP
	add	hl,hl	;(solo los 8 primeros bytes)
	add	hl,hl
	add	hl,hl
	ld	bc,BUFER_COMP+64
	add	hl,bc
	ld	bc,8
	ldir		;DE quedaba establecido tras el LDIR anterior

	push	de	;Calcula y guarda la longitud total
	pop	hl	;del paquete ICMP
	ld	bc,FRAGTOUT_P+6
	or	a
	sbc	hl,bc
	push	hl

	ld	hl,0	;Restaura el checksum del paquete
	ld	(FRAGTOUT_P_H+10),hl	;IP original
	push	ix
	pop	bc
	ld	ix,FRAGTOUT_P_H
	call	CALC_CHKSUM
	dec	de
	ld	a,e
	cpl
	ld	(FRAGTOUT_P_H+10),a
	ld	a,d
	cpl
	ld	(FRAGTOUT_P_H+11),a

	ld	hl,0	;Compone checksum del paq. ICMP
	ld	(FRAGTOUT_P_CS),hl
	ld	ix,FRAGTOUT_P+6
	pop	bc	;Vuelve a guardar tamanyo
	push	bc
	call	CALC_CHKSUM
	dec	de
	ld	a,e
	cpl
	ld	(FRAGTOUT_P_CS),a
	ld	a,d
	cpl
	ld	(FRAGTOUT_P_CS+1),a

	;* Inserta paquete en la cola de salida

	pop	hl
	ld	bc,6
	add	hl,bc
	ld	a,(#8002)
	ld	b,a
	ld	a,(PROT_OUT_QUEUE)
	ld	ix,(PROT_OUT_QUEUE+1)
	set	7,h
	ld	iy,FRAGTOUT_P
	nesman	28

	ret

FRAG_TEMP_END:	jp	END_INT



;*** 7) Tratamiento de un paquete entrante que es un fragmento de paquete
;       (El paquete entrante ha de estar en BUFER_IN)
;    - Si el fragmento corresponde a un paquete nuevo, crea nueva
;      entrada en la cola de paquetes fragmentados
;      (Un paquete se identifica por los campos dir. origen, dir. destino,
;       identificador y protocolo)
;      El paquete se encola en la forma: 64 bytes de cabecera (aunque sea
;      mas pequenya) + MRU bytes para datos.
;      Formato de agujero: 2 bytes "hole.first", 2 bytes "hole.last"
;      2 bytes "prev.hole" y 2 bytes "next.hole"
;      "hole.last"=#7FFF inicialmente
;      "prev/next.hole"=0 para primer/ultimo hole
;      El checksum se usa para apuntar al primer agujero (algoritmo de Clark)
;      El tamanyo total se almacena en la posicion 62 de la cabecera
;      cuando llega el ultimo fragmento (MF=0) - cab. maxima=60 bytes
;    - Coloca el fragmento en su sitio. Si es el fragmento inicial,
;      se sustituye la cabecera antigua por la nueva.
;    - Si el datagrama esta completo, se encola en IP_IN_QUEUE.

FRAG_PROCESS:	ld	a,(BUFER_IN)	;Primero calcula la longitud
	and	#0F	;de la cabecera del fragmento
	rl	a
	rl	a
	ld	(FRAG_H_LEN),a

	;--- Mueve el puntero de la cola FRAG_QUEUE
	;    al primer elemento y recorre todos los elementos
	;    en un bucle

	ld	a,1	;Paquete fragmentado actual=1
	ld	(CUR_FRAG),a	;(el primero de la lista)

	ld	b,1
FRAG_PROC_LOOP1:	ld	a,(FRAG_QUEUE)	;Mueve puntero de la lista
	ld	ix,(FRAG_QUEUE+1)
	nesman	23

	ld	a,b	;Si la lista esta vacia,
	cp	4	;hay que crear un elemento nuevo
	jr	z,FRAG_PROC_NEW

	ld	(CUR_FRAG_FLAG),a	;Guarda estado del puntero

	;--- Extrae elemento y lo compara con el paquete
	;    en BUFER_IN.

	ld	a,(#8002)
	ld	l,a
	ld	iy,BUFER_COMP
	ld	a,(FRAG_QUEUE)
	ld	ix,(FRAG_QUEUE+1)
	ld	b,0
	ld	h,1	;Solo extraer
	nesman	29

	ld	hl,BUFER_COMP+12	;Compara dirs de origen
	ld	de,BUFER_IN+12
	call	COMP_ADD
	jr	nz,FRAG_PROC_NEXT

	ld	hl,BUFER_COMP+16	;Compara dirs de destino
	ld	de,BUFER_IN+16
	call	COMP_ADD
	jr	nz,FRAG_PROC_NEXT

	ld	hl,(BUFER_IN+4)	;Compara ids
	ld	de,(BUFER_COMP+4)
	call	COMP
	jr	nz,FRAG_PROC_NEXT

	ld	a,(BUFER_IN+9)
	ld	hl,BUFER_COMP+9
	cp	(hl)
	jp	z,FRAG_PROC_MATCH

	;--- No coinciden: pasa al siguiente, si hay

FRAG_PROC_NEXT:	ld	hl,CUR_FRAG	;Incrementa num. de paquete actual
	inc	(hl)

	ld	a,(CUR_FRAG_FLAG)	;Si era el ultimo elemento,
	bit	1,a	;hay que crear uno nuevo
	jr	nz,FRAG_PROC_NEW

	ld	b,3	;Pasa al siguiente
	jr	FRAG_PROC_LOOP1

	;--- Crea una entrada nueva con la cabecera del paquete
	;    recibido, y un unico agujero inicial, al final de
	;    la cola FRAG_QUEUE

FRAG_PROC_NEW:	ld	a,(NUM_FRAG_PEND)	;Si ya hay 255 paquetes
	cp	255	;pendientes, lo descarta
	jp	z,FRAG_PROC_END

	ld	hl,2048	;0.4
	;ld      hl,(MRU)         ;Antes de componer paq. nuevo,
	ld	bc,64-1	;llena la zona de ceros
	add	hl,bc
	push	hl
	pop	bc
	ld	hl,BUFER_COMP
	ld	de,BUFER_COMP+1
	ld	(hl),0
	ldir

	ld	a,(FRAG_H_LEN)	;Copia la cabecera
	ld	c,a	;(compone el paquete en BUFER_COMP)
	ld	b,0
	ld	hl,BUFER_IN
	ld	de,BUFER_COMP
	ldir

	ld	hl,BUFER_COMP+64	;Checksum apunta al primer agujero
	ld	(BUFER_COMP+10),hl
	ld	hl,HOLE_INIT	;Crea agujero inicial
	ld	de,BUFER_COMP+64
	ld	bc,8
	ldir

	ld	ix,FRAG_TABLE	;Anyade una entrada nueva en la
	ld	a,(CUR_FRAG)	;tabla de timeouts de fragmentacion
	ld	c,a
	ld	b,0
	add	ix,bc
	add	ix,bc
	ld	hl,(FRAG_TIMEOUT)
	ld	(ix),l
	ld	(ix+1),h
	ld	(ix+2),0
	ld	(ix+3),0

	ld	hl,2048
	;ld      hl,(MRU)         ;Inserta el nuevo elemento
	ld	bc,64	;al final de la cola FRAG_QUEUE
	add	hl,bc
	set	7,h
	set	6,h
	ld	a,(#8002)
	ld	b,a
	ld	iy,BUFER_COMP
	ld	a,(FRAG_QUEUE)
	ld	ix,(FRAG_QUEUE+1)
	nesman	28
	jp	c,FRAG_PROC_END

	ld	a,(FRAG_QUEUE)	;Establece puntero al final
	ld	ix,(FRAG_QUEUE+1)	;de la cola
	ld	b,2
	nesman	23

	ld	hl,NUM_FRAG_PEND	;Incrementa num. de paquetes
	inc	(hl)	;pendientes

	jr	FRAG_PROC_MATCH

HOLE_INIT:	dw	0,#7FFF	;Agujero inicial
	dw	0,0

	;--- El paquete coincide: lo actualiza con la informacion
	;    recibida y lo copia de nuevo a su posicion en FRAG_QUEUE
	;    (En este punto, tanto si se ha creado una entrada nueva
	;    como si no, el puntero de FRAG_QUEUE apunta al elemento
	;    que ha sido extraido a/creado en BUFER_COMP)

FRAG_PROC_MATCH:	ld	a,(BUFER_IN+7)	;Calcula FRAG_FIRST como el valor
	ld	l,a	;del campo "offset"
	ld	a,(BUFER_IN+6)
	and	%00011111
	ld	h,a
	add	hl,hl	;Esta almacenado en unidades
	add	hl,hl	;de 8 bytes
	add	hl,hl
	ld	(FRAG_FIRST),hl

	ld	a,(BUFER_IN+2)	;Calcula FRAG_LAST como
	ld	h,a	;FRAG_FIRST+Long. total-Long. header
	ld	a,(BUFER_IN+3)
	ld	l,a
	ld	a,(FRAG_H_LEN)
	ld	c,a
	ld	b,0
	or	a
	sbc	hl,bc
	ld	(FRAG_LEN),hl	;De paso calcula long. de los datos
	ld	de,(FRAG_FIRST)
	add	hl,de
	dec	hl
	ld	(FRAG_LAST),hl

	ld	a,(BUFER_IN+6)	;Comprueba el bit MF, y si es 0,
	bit	5,a	;establece la long. de la zona de
	jr	nz,FRAG_PROC_MCH0	;datos como FRAG_LAST+1
	;ld      hl,(FRAG_LAST)  ;(long. total del paquete completo)
	inc	hl
	ld	(FRAG_D_LEN),hl
FRAG_PROC_MCH0:	;

	ld	ix,BUFER_COMP+10-6	;IX=Puntero al hole actual
	;(inicialmente el campo checksum, que es un hole ficticio)

	;** Reensamblaje segun el algoritmo de Clark (RFC 815)

	;* Paso 1: Ir al sig. agujero, si no hay mas, goto 8

HOLE_PROC_1:	ld	l,(ix+6)
	ld	h,(ix+7)
	ld	a,h
	or	l
	jp	z,HOLE_PROC_8

	push	hl
	pop	ix

	ld	l,(ix+0)
	ld	h,(ix+1)
	ld	(HOLE_FIRST),hl
	ld	l,(ix+2)
	ld	h,(ix+3)
	ld	(HOLE_LAST),hl

	;* Paso 2: Si FRAG.FIRST>HOLE.LAST, goto 1

HOLE_PROC_2:	ld	de,(FRAG_FIRST)
	ld	hl,(HOLE_LAST)
	call	COMP
	jr	nc,HOLE_PROC_1

	;* Paso 3: Si FRAG.LAST<HOLE.FIRST, goto 1

HOLE_PROC_3:	ld	hl,(FRAG_LAST)
	ld	de,(HOLE_FIRST)
	call	COMP
	jr	nc,HOLE_PROC_1

	;* Paso 4: Borrar hole

HOLE_PROC_4:	ld	l,(ix+4)	;HL=Hole anterior
	ld	h,(ix+5)	;DE=Hole siguiente
	ld	e,(ix+6)
	ld	d,(ix+7)
	ld	(HOLE_PREV),hl
	ld	(HOLE_NEXT),de

	ld	a,h
	or	l
	jr	z,HOLE_PROC4A
	push	hl	;anterior.siguiente=actual.siguiente
	pop	iy	;(solo si el pnt al ant. no es 0)
	ld	(iy+6),e
	ld	(iy+7),d
	jr	HOLE_PROC4B
HOLE_PROC4A:	ld	(BUFER_COMP+10),de	;Si no habia anterior, checksum
HOLE_PROC4B:	;                        ;debe apuntar al siguiente

	ld	a,d
	or	e
	jr	z,HOLE_PROC4C
	push	de	;siguiente.anterior=actual.anterior
	pop	iy	;(solo si el pnt al sig. no es 0)
	ld	(iy+4),l
	ld	(iy+5),h
HOLE_PROC4C:	;

	ld	a,h	;Si anterior=siguiente=0,
	or	l	;significa que solo habia ese hole,
	or	d	;y borrarlo equivale a poner a 0
	or	e	;el puntero al primero (checksum)
	jr	nz,HOLE_PROC_5
	ld	hl,0
	ld	(BUFER_COMP+10),hl

	;* Paso 5: Si FRAG.FIRST>HOLE.FIRST, crea hole nuevo
	;  con NEW_HOLE.FIRST=HOLE.FIRST
	;  y   NEW_HOLE.LAST=FRAG.FIRST-1
	;(El nuevo hole se crea de forma que es el primero)

HOLE_PROC_5:	ld	de,(FRAG_FIRST)
	ld	hl,(HOLE_FIRST)
	call	COMP
	jr	c,HOLE_PROC_6

	ld	bc,(HOLE_FIRST)
	ld	iy,BUFER_COMP+64
	add	iy,bc	;IY=Pnt al nuevo hole
	ld	(iy),c	;NEW_HOLE_FIRST=HOLE_FIRST
	ld	(iy+1),b

	ld	bc,(FRAG_FIRST)
	dec	bc
	ld	(iy+2),c	;NEW_HOLE_LAST=FRAG_FIRST-1
	ld	(iy+3),b

	ld	hl,(BUFER_COMP+10)
	ld	(iy+6),l	;NEW_HOLE_NEXT=Pnt al primero
	ld	(iy+7),h

	ld	hl,(BUFER_COMP+10)
	ld	a,h	;antiguo_primero.previo=nuevo_prim
	or	l	;(excepto si antiguo_primero=0,
	jr	z,HOLE_PROC5A	;es decir, no habia holes)
	ld	bc,4
	add	hl,bc
	push	iy
	pop	bc
	ld	(hl),c
	inc	hl
	ld	(hl),b
HOLE_PROC5A:	;

	push	iy	;Pnt al primero=Pnt al nuevo
	pop	hl
	ld	(BUFER_COMP+10),hl

	ld	(iy+4),0	;NEW_HOLE_PREV=0 (es el primero)
	ld	(iy+5),0

	;* Paso 6: Si FRAG.LAST<HOLE.LAST, y MF=1, crea hole nuevo
	;  con NEW_HOLE.FIRST=FRAG.LAST+1
	;  y   NEW_HOLE.LAST=HOLE.LAST
	;(El nuevo hole se crea de forma que es el primero)

HOLE_PROC_6:	ld	hl,(FRAG_LAST)
	ld	de,(HOLE_LAST)
	call	COMP
	jp	c,HOLE_PROC_7

	ld	a,(BUFER_IN+6)	;Comprueba el bit MF
	bit	5,a
	jp	z,HOLE_PROC_7

	ld	bc,(FRAG_LAST)
	inc	bc
	ld	iy,BUFER_COMP+64
	add	iy,bc	;IY=Pnt al nuevo hole
	ld	(iy),c	;NEW_HOLE_FIRST=FRAG_LAST+1
	ld	(iy+1),b

	ld	bc,(HOLE_LAST)
	ld	(iy+2),c	;NEW_HOLE_LAST=HOLE_LAST
	ld	(iy+3),b

	ld	hl,(BUFER_COMP+10)
	ld	(iy+6),l	;NEW_HOLE_NEXT=Pnt al primero
	ld	(iy+7),h

	ld	hl,(BUFER_COMP+10)
	ld	a,h	;antiguo_primero.previo=nuevo_prim
	or	l	;(excepto si antiguo_primero=0,
	jr	z,HOLE_PROC6A	;es decir, no habia holes)
	ld	bc,4
	add	hl,bc
	push	iy
	pop	bc
	ld	(hl),c
	inc	hl
	ld	(hl),b
HOLE_PROC6A:	;

	push	iy	;Pnt al primero=Pnt al nuevo
	pop	hl
	ld	(BUFER_COMP+10),hl

	ld	(iy+4),0	;NEW_HOLE_PREV=0 (es el primero)
	ld	(iy+5),0

	;* Paso 7: Salta a 1 de nuevo

HOLE_PROC_7:	jp	HOLE_PROC_1

	;* Paso 8a: Copia los datos recibidos al bufer total

HOLE_PROC_8:	;
HOLE_PROC_8A:	ld	hl,BUFER_IN	;Calcula HL=Pnt de origen
	ld	a,(FRAG_H_LEN)
	ld	c,a
	ld	b,0
	add	hl,bc
	push	hl

	ld	hl,(FRAG_FIRST)	;Calcula DE=Pnt de destino
	ld	bc,BUFER_COMP+64
	add	hl,bc
	ex	de,hl
	pop	hl

	ld	bc,(FRAG_LEN)	;Copia los datos del fragmento
	ldir		;                ;al bufer de paquete completo

	;* Paso 8b: Si el fragmento es el primero,
	;  se establece su cabecera como la del paquete completo

HOLE_PROC_8B:	ld	a,(BUFER_IN+7)	;Es el primero si el offset
	ld	h,a	;es 0
	ld	a,(BUFER_IN+6)
	and	%00011111
	or	h
	jr	nz,HOLE_PROC_8C

	ld	hl,(BUFER_COMP+10)	;Guarda pnt al primer hole
	push	hl

	ld	bc,(FRAG_H_LEN)	;Copia cabecera
	ld	hl,BUFER_IN
	ld	de,BUFER_COMP
	ldir

	pop	hl	;Restaura pnt al primer hole
	ld	(BUFER_COMP+10),hl

	;* Paso 8c:
	;  Si quedan mas holes, copia el nuevo paquete
	;  sobre el antiguo en FRAG_QUEUE

HOLE_PROC_8C:	ld	hl,(BUFER_COMP+10)	;Quedan mas holes
	ld	a,h	;si el pnt al 1ero no es 0
	or	l
	jr	z,HOLE_PROC8D

	ld	a,(FRAG_QUEUE)	;Obtiene el puntero al elemento
	ld	ix,(FRAG_QUEUE+1)	;en curso en B-IY
	nesman	21
	ld	de,6
	add	iy,de

	ld	a,(#8002)	;Realiza una transferencia
	ld	ix,BUFER_COMP	;entre segmentos
	ld	hl,2048
	;ld      hl,(MRU)
	ld	de,64
	add	hl,de
	nesman	14

	jp	HOLE_PROC_END

	;* Paso 8d:
	;  Si no quedan mas holes, entrega el paquete
	;  (lo encola en IP_IN_QUEUE) y lo elimina de FRAG_QUEUE

HOLE_PROC8D:	ld	hl,(FRAG_H_LEN)	;Calcula longitud total
	ld	de,(FRAG_D_LEN)	;como cabecera+datos
	add	hl,de
	ld	a,h
	ld	(BUFER_COMP+2),a
	ld	a,l
	ld	(BUFER_COMP+3),a
	ld	(FRAG_T_LEN),hl

	ld	hl,0	;Establece offset y MF como 0
	ld	(BUFER_COMP+6),hl	;(paquete sin fragmentar)

	;ld      hl,0             ;Recalcula checksum
	;ld      (BUFER_COMP+10),hl
	ld	ix,BUFER_COMP
	ld	a,(FRAG_H_LEN)
	ld	c,a
	ld	b,0
	call	CALC_CHKSUM
	dec	de
	ld	a,e
	cpl
	ld	(BUFER_COMP+10),a
	ld	a,d
	cpl
	ld	(BUFER_COMP+11),a

	ld	a,(FRAG_H_LEN)	;Si la cabecera no mide 64 bytes,
	cp	64	;queda espacio vacio entre la cab.
	jr	z,HOLE_PROC8D2	;y los datos: hay que mover los
	ld	hl,BUFER_COMP	;datos hacia atras.
	ld	c,a
	ld	b,0
	add	hl,bc
	ex	de,hl
	ld	hl,BUFER_COMP+64
	ld	bc,(FRAG_D_LEN)
	ldir
HOLE_PROC8D2:	;

	ld	hl,#2100	;Lo encola como si fuera externo
	ld	(BUFER_COMP-2),hl
	ld	hl,(FRAG_T_LEN)
	inc	hl
	inc	hl
	ld	a,(#8002)
	ld	b,a
	set	7,h
	ld	a,(IP_IN_QUEUE)
	ld	ix,(IP_IN_QUEUE+1)
	ld	iy,BUFER_COMP-2
	nesman	28

	ld	a,(CUR_FRAG)	;Borra la entrada de la tabla
	call	DEL_FRAG2	;de frag. y el paq. de FRAG_QUEUE

HOLE_PROC_END:	;
FRAG_PROC_END:	jp	FRAG_TEMP_EXP


;*** 8) Tratamiento de la (posible) peticion DNS en curso
;       - Si DNS_STAT_P no es 1, no hace nada.
;       - Decrementa DNS_TTOUT, y si llega a 0, establece error 17 y fin.
;       - Consulta si hay algun paquete en DNS_IN_QUEUE,
;         cuyo identificador coincida con DNS_IDENTIF.
;         * Si lo hay y contiene un error, se pone en DNS_STAT_S, y fin.
;         * Si lo hay y contiene una respuesta valida,
;           se copia esta a DNS_RESPONSE, se pone DNS_STAT_P a 2, y fin.
;         * Si lo hay y no contiene respuesta, se examina la seccion
;           AUTHORITATIVE, se copia la primera dir encontrada
;           en DNS_P, se pone DNS_STAT_S a 3, se inicializa DNS_RETRY,
;           se pone DNS_TOUT a 0, y se continua.
;         * Si lo hay y no contiene ni respuesta ni AUTHORITATIVE,
;           se pone DNS_STAT_S a 20, y fin.
;       - Se decrementa DNS_TOUT, y si llega a 0:
;         * Si DNS_RETRY>0, se decrementa, reiniciar DNS_TOUT, se vuelve a enviar
;           el paquete que hay en BUFER_DNS, y fin. Si =0, continuar.
;         * Si DNS_STAT_S=2, o 1 pero DNS_SEC=0.0.0.0, DNS_STAT_S=16 y fin.
;         * Si DNS_STAT_S=1 y DNS_SEC<>0.0.0.0, poner DNS_STAT_S=2,
;           copiar DNS_SEC a DNS_P, reiniciar DNS_TOUT y DNS_RETRY,
;           enviar paquete en BUFER_DNS, decrementar DNS_RETRY, y fin.

END_INT:	;

	;--- Primero comprueba si hay alguna consulta en curso

	ld	a,(DNS_STAT_P)
	cp	1
	jp	nz,END_DNS_INT

	;--- Comprueba si el timeout golbal ha expirado

	ld	hl,(DNS_TTOUT)
	dec	hl
	ld	(DNS_TTOUT),hl
	ld	a,h
	or	l
	jr	nz,OK_DNS_TT

	ld	a,3
	ld	(DNS_STAT_P),a
	ld	a,17
	ld	(DNS_STAT_S),a
	jp	END_DNS_INTE
OK_DNS_TT:	;

	;--- Comprueba si hay algun paquete en DNS_IN_QUEUE
	;    con el identificador adecuado
	;    (va cogiendo paquetes hasta encontrar un con el id
	;    adecuado, pues los otros ya no sirven)

DNS_GET_LOOP:	ld	a,(#8002)
	ld	l,a
	ld	a,(DNS_IN_QUEUE)
	ld	ix,(DNS_IN_QUEUE+1)
	ld	iy,BUFER_IN-1
	ld	b,0
	ld	h,3

	nesman	29
	jp	c,DNS_NOPAQ

	ld	a,(BUFER_IN-1)
	ld	c,a
	ld	b,0
	ld	ix,BUFER_IN
	add	ix,bc	;IX=Dir de inicio de UDP
	ld	bc,8
	add	ix,bc	;IX=Dir. de inicio DNS
	ld	h,(ix)
	ld	l,(ix+1)
	ld	de,(DNS_IDENTIF)	;Coinciden los IDs?
	call	COMP
	jr	nz,DNS_GET_LOOP	;No: intentar con otro paquete

	;--- Comprueba si la respuesta contiene un error
	;    o si esta truncada

	ld	a,(ix+3)	;Contiene error?
	and	%1111
	jr	nz,DNS_HAYERR

	ld	a,(ix+2)	;Esta truncada?
	bit	1,a
	jr	z,DNS_NOERROR
	ld	a,21

DNS_HAYERR:	ld	b,a
	ld	a,(DNS_STAT_S)	;Si el generador del error
	cp	1	;era el DNS primario, probamos
	jr	nz,DNS_ERCODE	;con el secundario, si hay
	ld	iy,DNS_SEC
	ld	a,(iy)
	or	(iy+1)
	or	(iy+2)
	or	(iy+3)
	jp	nz,NOMORERETRY

DNS_ERCODE:	ld	a,b
	ld	(DNS_STAT_S),a	;Error: abortar proceso
	ld	a,3	;con el codigo devuelto
	ld	(DNS_STAT_P),a	;y fin
	jp	END_DNS_INTE

	;--- No hay error: comprueba si hay alguna
	;    respuesta valida

DNS_NOERROR:	ld	h,(ix+8)
	ld	l,(ix+9)
	ld	(NSCOUNT),hl
	ld	h,(ix+6)
	ld	l,(ix+7)
	ld	(ANCOUNT),hl
	ld	h,(ix+10)
	ld	l,(ix+11)
	ld	(ARCOUNT),hl

	ld	bc,12
	add	ix,bc	;IX=Inicio de la pregunta

SKIPQ_LOOP:	ld	a,(ix)	;Se salta la pregunta
	inc	ix	;(campo QNAME)
	or	a	;comprobando si hay compresion
	jr	z,SKIPQ_LOOP3
	bit	7,a
	jr	z,SKIPQ_LOOP
SKIPQ_LOOP2:	inc	ix	;Se salta QTYPE y QCLASS
SKIPQ_LOOP3:	inc	ix
	inc	ix
	inc	ix	;Ahora IX apunta a las respuestas
	inc	ix

SCAN_FOR_AN:	ld	bc,(ANCOUNT)
	call	SCAN_DNS_RR
	or	a
	jr	z,SCAN_FOR_NS

	ld	a,2	;Si habia una respuesta valida,
	ld	(DNS_STAT_P),a	;ponemos status=2 y terminamos
	xor	a
	ld	(DNS_STAT_S),a
	jp	END_DNS_INTE

SCAN_FOR_NS:	ld	bc,(NSCOUNT)
	ld	a,b
	or	c
	jr	z,SCAN_FAILED

	call	SCAN_DNS_RR	;Busca IPs de servidores
	or	a	;en "authoritative", y despues
	jp	nz,CHANGE_DNS_IP	;en "additional"
	ld	bc,(ARCOUNT)
	ld	a,b
	or	c
	jr	z,SCAN_FAILED
	call	SCAN_DNS_RR
	or	a
	jp	nz,CHANGE_DNS_IP

SCAN_FAILED:	ld	a,3	;Si no hay nada en NS, error 20
	ld	(DNS_STAT_P),a
	ld	a,20
	ld	(DNS_STAT_S),a
	jp	END_DNS_INTE

CHANGE_DNS_IP:	ld	hl,DNS_RESULT	;Se nos redirecciona a otro DNS:
	ld	de,BUFER_DNS	;Establecemos nueva direccion
	ld	bc,4
	ldir
	ld	hl,(DNS_IDENTIF)	;Incrementamos identificador
	inc	hl
	ld	(DNS_IDENTIF),hl
	ld	a,3	;Ponemos estado secundario a 3
	ld	(DNS_STAT_S),a
	ld	a,(DNS_RETRY_NOW)	;Inicializamos reintentos
	ld	(DNS_RETRY),a
	ld	hl,0	;Contador a 0 para que se
	ld	(DNS_TOUT),hl	;envie inmediatamente

	jr	DNS_NOPAQ

	;--- Esta subrutina examina la zona a la que apunta IX
	;    y busca un RR del tipo "Direccion IP".
	;    Si lo encuentra, pone la IP en DNS_RESPONSE
	;    y DNS_RESP_FLAG a #FF (que devuelve en A).
	;    Al final, IX apunta a la siguiente zona.
	;    Entrada: BC = Numero de RRs en la zona.

SCAN_DNS_RR:	xor	a
	ld	(DNS_RESP_FLAG),a
	ld	a,b
	or	c
	ld	a,0	;Hay al menos un RR?
	ret	z

DNS_AN_LOOP:	push	bc
SKIPQ_LOOP4:	ld	a,(ix)	;Se salta el nombre
	inc	ix	;comprobando si esta comprimido
	or	a
	jr	z,SKIPQ_LOOP6
	bit	7,a
	jr	z,SKIPQ_LOOP4
SKIPQ_LOOP5:	inc	ix	;Se salta QTYPE y QCLASS
SKIPQ_LOOP6:	;

	ld	a,(DNS_RESP_FLAG)	;Si ya hay una respuesta
	or	a	;valida, simplemente se salta
	jr	nz,DNS_AN_LOOP2	;el RR

	ld	h,(ix)
	ld	l,(ix+1)
	ld	de,1
	call	COMP
	jr	nz,DNS_AN_LOOP2

	ld	l,(ix+10)	;Se ha encontrado respuesta:
	ld	h,(ix+11)	;se copia a DNS_RESPONSE,
	ld	e,(ix+12)
	ld	d,(ix+13)
	ld	(DNS_RESULT),hl
	ld	(DNS_RESULT+2),de

	ld	a,#FF
	ld	(DNS_RESP_FLAG),a

DNS_AN_LOOP2:	ld	bc,10	;Se salta el resto de la respuesta
	add	ix,bc
	ld	b,(ix-2)
	ld	c,(ix-1)
	add	ix,bc

	pop	bc
	dec	bc
	ld	a,b
	or	c
	jr	nz,DNS_AN_LOOP
	ld	a,(DNS_RESP_FLAG)
	ret

DNS_RESP_FLAG:	db	0

	;--- Decrementamos DNS_TOUT, y si no llega a 0,
	;    terminamos

DNS_NOPAQ:	ld	hl,(DNS_TOUT)
	push	hl
	pop	bc
	dec	hl
	ld	(DNS_TOUT),hl
	ld	a,b
	or	c
	jp	nz,END_DNS_INT

	;--- DNS_TOUT expirado:
	;    Comprobamos si DNS_RETRY es >0, en ese caso
	;    volvemos a enviar el paquete que hay en BUFER_IN

	ld	a,(DNS_RETRY)
	ld	b,a
	dec	a
	ld	(DNS_RETRY),a
	ld	a,b
	or	a
	jr	z,NOMORERETRY

	;RETRY no agotado: (re)envia paquete

SEND_DNS:	ld	a,(DNS_IDENTIF+1)	;Establecemos identificador DNS
	ld	(BUFER_DNS+16),a
	ld	a,(DNS_IDENTIF)
	ld	(BUFER_DNS+17),a

	ld	hl,0	;Calcula checksum del paquete
	ld	(BUFER_DNS+14),hl	;a enviar
	ld	ix,BUFER_DNS+8
	ld	hl,(DNS_P_SIZE)
	ld	bc,8
	or	a
	sbc	hl,bc
	push	hl
	pop	bc
	ld	hl,IP_LOCAL
	ld	de,BUFER_DNS
	call	UDP_CHKSUM
	dec	de
	ld	a,e
	cpl
	ld	(BUFER_DNS+14),a
	ld	a,d
	cpl
	ld	(BUFER_DNS+15),a

	ld	a,(#8002)	;Lo encola en PROT_OUT_QUEUE
	ld	b,a
	ld	hl,(DNS_P_SIZE)
	set	7,h
	ld	iy,BUFER_DNS
	ld	a,(PROT_OUT_QUEUE)
	ld	ix,(PROT_OUT_QUEUE+1)
	nesman	28

	ld	hl,(DNS_TOUT_NOW)
	ld	(DNS_TOUT),hl
	jr	END_DNS_INT

	;--- DNS_TOUT expirado y DNS_REPLY agotado:
	;    Si DNS_STAT_S=2, o 3, o 1 pero DNS_SEC=0.0.0.0,
	;    error 16 y fin

NOMORERETRY:	ld	a,(DNS_STAT_S)
	cp	1
	jr	nz,DNS_ERR16
	ld	ix,DNS_SEC
	ld	a,(ix)
	or	(ix+1)
	or	(ix+2)
	or	(ix+3)
	jr	z,DNS_ERR16

	;RETRY agotado para el DNS primario, ahora
	;reintentamos con el secundario

	ld	hl,DNS_SEC
	ld	de,BUFER_DNS
	ld	bc,4
	ldir
	ld	hl,(DNS_IDENTIF)	;Incrementamos identificador
	inc	hl
	ld	(DNS_IDENTIF),hl
	ld	a,2	;Ponemos estado secundario a 3
	ld	(DNS_STAT_S),a
	ld	a,(DNS_RETRY_NOW)	;Inicializamos reintentos
	dec	a
	ld	(DNS_RETRY),a
	jp	SEND_DNS

	;Error 16

DNS_ERR16:	ld	a,3
	ld	(DNS_STAT_P),a
	ld	a,16
	ld	(DNS_STAT_S),a
	;jr      END_DNS_INTE

	;--- Terminacion con error (hay que borrar la cola)

END_DNS_INTE:	ld	ix,DNS_IN_QUEUE
	call	FLUSH_QUEUE
END_DNS_INT:	;


;*** 9) Llamada a la interrupcion del modulo superior, y fin

END_INT2:	ld	a,(UPPER_SEG)
	or	a
	ret	z
	ld	iyh,a
	ld	ix,UP_INT
	call	CAL_SEG
	ret



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
	nesmani	25
	jr	nc,FLUSH_QLOOP
	pop	af,ix
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


;--- Inicializacion de variables y ctes

INIT_VAR:	ld	hl,CONS_DEF_VAL
	ld	de,CONS_START
	ld	bc,CONS_END-CONS_START
	ldir
	ld	hl,VAR_START
	ld	de,VAR_START+1
	ld	bc,VAR_ZONE_END-VAR_START-1
	ld	(hl),0
	ldir
	ld	hl,BUFERS
	ld	de,BUFERS+1
	ld	bc,END_BUFERS-BUFERS
	ld	(hl),0
	ldir
	;ld      a,#FF            ;*** PRUEBAS
	;ld      (MASK_METHOD),a
	ret

CALL_LOWER:	push	af
	ld	a,(LOWER_SEG)
	ld	iyh,a
	pop	af
	call	CAL_SEG
	ret

CALL_UPPER:	push	af
	ld	a,(UPPER_SEG)
	ld	iyh,a
	pop	af
	call	CAL_SEG
	ret

;--- Checksum
;    Decrementar y complementar el valor obtenido

;Entrada: IX = Direccion, BC = Longitud en bytes
;ATENCION: Asume que BC es par
;          (siempre lo es para una cabecera IP y para paquetes ICMP)

; Compute checksum
;
; On entry:
;             IX -> block to checksum
;             BC = number of halfwords to checksum
;
; On exit:
;             DE = checksum + 1
;             Z set if DE = 0 (i.e. checksum good)
;             A, BC and other flags corrupt

CALC_CHKSUM:	ld	de,0

CALC_CHKSUMP:	sra	b	;Convierte BC a words-16
	rr	c

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


;--- MASK_ADDRESS: Enmascara una direccion IP
;    Entrada: HL = Puntero a la direccion IP original
;             IX = Puntero a la mascara
;             DE = Puntero a donde dejar la IP enmascarada

MASK_ADDRESS:	ld	b,4
MASKAD_LOOP:	ld	a,(hl)
	and	(ix)
	ld	(de),a
	inc	hl
	inc	de
	inc	ix
	djnz	MASKAD_LOOP
	ret


;--- COMP_ADD: Compara dos direcciones IP
;    Entrada: HL, DE = Punteros a las direcciones
;    Salida:  Z si son iguales

COMP_ADD:	ld	b,4
COMPADD_LOOP:	ld	a,(de)
	xor	(hl)
	ret	nz
	inc	hl
	inc	de
	djnz	COMPADD_LOOP
	ret


;--- Analisis de una direccion IP
;    Examina la dir. IP apuntada por IX y devuelve las siguientes banderas:
;    A: 1 = La dir coincide con la nuestra
;       2 = La dir es 0.0.0.0
;       3 = Tipo 0,<host>
;       4 = La dir es 255.255.255.255
;       5 = Tipo <Nuestra red>,-1
;       6 = Tipo <Nuestra red>,<Nuestra subred>,-1
;       7 = Tipo <Nuestra red>,-1,-1

	;--- Comprueba 1

CHECK_ADD:	push	ix	;Coincide con la nuestra?
	pop	hl	;En ese caso termina ensegudia
	ld	de,IP_LOCAL
	call	COMP_ADD
	ld	a,1
	ret	z

	;--- Comprueba 2

	push	ix	;Es 0.0.0.0?
	pop	hl	;En ese caso termina enseguida
	ld	de,IP_ZERO
	call	COMP_ADD
	ld	a,2
	ret	z

	;--- Comprueba 3

	ld	a,(ix)	;Asume 0,<host> si el primer
	or	a	;byte es 0
	ld	a,3
	ret	z

	;--- Comprueba 4

	push	ix	;Es 255.255.255.255?
	pop	hl	;En ese caso termina enseguida
	ld	de,IP_BROAD
	call	COMP_ADD
	ld	a,4
	ret	z

	;--- Calcula la parte de red de la dir IP remota
	;    asumiendo que es de la misma clase que la nuestra

	push	ix,ix
	pop	hl
	ld	de,IP_REM_TEMP
	ld	ix,NET_MASK
	call	MASK_ADDRESS
	pop	ix

	;--- Comprueba si la red de la IP remota es la misma
	;    que la nuestra, en caso contrario devuelve 0
	;    sin comprobar nada mas

	ld	hl,IP_LOCAL_NET
	ld	de,IP_REM_TEMP
	call	COMP_ADD
	ld	a,0
	ret	nz

	;--- Si la mascara de subred es 0, comprueba 5
	;    y termina (no puede ser 6 ni 7)

	ld	hl,SUBNET_MASK	;Comprueba si la mascara de
	ld	de,IP_ZERO	;subred es 0
	call	COMP_ADD
	jr	nz,CHKADD_6

	push	ix,ix	;Calcula la parte de red
	pop	hl	;de la dir IP remota
	ld	de,IP_REM_TEMP	;en IP_REM_TEMP
	ld	ix,NET_MASK
	call	MASK_ADDRESS
	pop	ix

	ld	hl,IP_LOCAL_NET	;Compara las redes
	ld	de,IP_REM_TEMP	;y devuelve 0 si no son iguales
	call	COMP_ADD
	ld	a,0
	ret	nz

	;En este punto sabemos que la direccion IP remota
	;es de la forma <Nuestra red>,?
	;Entonces si NET_MASK or IP REMOTA=255.255,
	;se cumple 5

	ld	iy,NET_MASK
	ld	a,(ix+1)	;Como sabmeos que la red coincide,
	or	(iy+1)	;podemos ignorar el primer byte
	inc	a
	ld	a,0
	ret	nz
	ld	a,(ix+2)
	or	(iy+2)
	inc	a
	ld	a,0
	ret	nz
	ld	a,(ix+3)
	or	(iy+3)
	inc	a
	ld	a,0
	ret	nz
	ld	a,5
	ret

	;--- Comprueba 6

CHKADD_6:	push	ix,ix	;Calcula la parte de subred
	pop	hl	;de la IP remota
	ld	de,IP_REM_TEMP	;en IP_REM_TEMP
	ld	ix,SUBNET_MASK
	call	MASK_ADDRESS
	pop	ix

	ld	hl,IP_LOCAL_SUB	;Si la subred no coincide,
	ld	de,IP_REM_TEMP	;pasa a comprobar 7
	call	COMP_ADD
	jr	nz,CHKADD_7

	;En este punto sabemos que la direccion IP remota
	;es de la forma <Nuestra red>,<Nuestra subred>,?
	;Entonces si NET_MASK or SUBNET_MASK or IP REMOTA=255.255,
	;se cumple 6

	ld	hl,NET_MASK+1
	ld	iy,SUBNET_MASK
	ld	a,(ix+1)	;Como sabemos que la red coincide,
	or	(hl)	;podemos ignorar el primer byte
	or	(iy+1)
	inc	a
	ld	a,0
	ret	nz
	inc	hl
	ld	a,(ix+2)
	or	(hl)
	or	(iy+2)
	inc	a
	ld	a,0
	ret	nz
	inc	hl
	ld	a,(ix+3)
	or	(hl)
	or	(iy+3)
	inc	a
	ld	a,0
	ret	nz
	ld	a,6
	ret

	;--- Comprueba 7

	;En este punto sabemos que la direccion IP remota
	;es de la forma <Nuestra red>,?,?
	;Entonces si NET_MASK or IP REMOTA=255.255,
	;se cumple 7

CHKADD_7:	ld	iy,NET_MASK
	ld	a,(ix+1)	;Como sabmeos que la red coincide,
	or	(iy+1)	;podemos ignorar el primer byte
	inc	a
	ld	a,0
	ret	nz
	ld	a,(ix+2)
	or	(iy+2)
	inc	a
	ld	a,0
	ret	nz
	ld	a,(ix+3)
	or	(iy+3)
	inc	a
	ld	a,0
	ret	nz
	ld	a,7
	ret

	;--- Datos

IP_REM_TEMP:	db	0,0,0,0
IP_BROAD:	db	255,255,255,255
IP_ZERO:	db	0,0,0,0


;--- Encolamiento de un paquete entrante en la cola
;    del protocolo adecuado
;    Formato de entrada: 2 bytes de protocolo + paquete tal cual
;    Formato de salida: 1 byte apuntando a los datos + paquete tal cual
;    Entrada: IX=Direccion del paquete (incluyendo los 2 bytes de prot.)
;    ATENCION: Sustituye los 2 bytes de protocolo del paquete original
;              por los 2 bytes apuntando a los datos

ENQUEUE_IN:	ld	a,(ix+11)

ENQUEUE_IN2:	push	ix
	call	IP_QUEUES
	pop	ix
	push	af,hl	;Obtiene cola adecuada al protocolo

	ld	a,(LAST_P_HSIZE)
	ld	(ix+1),a	;Guarda long. cab. en little-endian

	ld	h,(ix+4)
	ld	l,(ix+5)
	inc	hl	;HL=Longitud total en bytes
	push	ix
	pop	iy	;IY=Direccion del paquete
	inc	iy
	set	7,h
	ld	a,(#8002)
	ld	b,a
	pop	ix,af
	nesman	28
	ret


;--- DEL_FRAG: Borra el paquete de la posicion A de la cola FRAG_QUEUE,
;    y actualiza FRAG_TABLE y NUM_FRAG_PEND adecuadamente.
;    DEL_FRAG2 no establece primero el puntero de la lista.
;    DEL_FRAG3 unicamente actualiza FRAG_TABLE y NUM_FRAG_PEND.

DEL_FRAG:	push	af
	ld	b,5
	ld	h,0
	ld	iyh,0
	ld	iyl,a
	ld	a,(FRAG_QUEUE)
	ld	ix,(FRAG_QUEUE+1)
	nesman	23
	pop	af

DEL_FRAG2:	push	af
	ld	a,(FRAG_QUEUE)
	ld	ix,(FRAG_QUEUE+1)
	ld	b,0
	ld	h,2
	nesman	29
	pop	af

DEL_FRAG3:	ld	c,a	;Calcula origen y destino
	ld	b,0	;de la zona a mover en FRAG_TABLE:
	ld	hl,FRAG_TABLE	;DE=FRAG_TABLE+A*2 (destino)
	add	hl,bc	;HL=DE+2 (origen)
	add	hl,bc
	push	hl
	pop	de
	inc	hl
	inc	hl

	exx
	ld	c,a
	ld	b,0
	ld	a,(NUM_FRAG_PEND)
	ld	l,a	;Calcula longitud zona a mover:
	ld	h,0	;BC=(NUM_FRAG_PEND-A)*2
	or	a
	sbc	hl,bc
	add	hl,hl
	push	hl
	exx
	pop	bc

	ld	a,b
	or	c
	jr	z,NOLDIR
	ldir
NOLDIR:	ex	de,hl
	ld	(hl),0	;Anyade un fin de lista al final
	inc	hl
	ld	(hl),0

	ld	hl,NUM_FRAG_PEND	;Decrementa num. de frag. pendientes
	dec	(hl)	;y termina
	ret


;--- HLPOR50: Multiplica HL por 50

HLPOR50:	add	hl,hl
	push	hl	;BC=HL*2
	pop	bc
	add	hl,hl
	add	hl,hl
	add	hl,hl
	push	hl	;DE=HL*16
	pop	de
	add	hl,hl	;HL=HL*32
	add	hl,de	;HL=HL*(32+16)
	add	hl,bc	;HL=HL*(32+16+2)=HL*50
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


;--- PARSE_IP: Extrae una direccion IP a partir de una cadena
;    Entrada:  Cadena en BUFER_IN, acabada en 0, 32, 9, 10, 13 o 26
;    Salida:   Cy=0 y IP en DNS_RESULT, o Cy=1 si no es una IP valida
;	En cualquier caso vuelve con la cadena acabada en 0

PARSE_IP:	ld	hl,BUFER_IN
PARSE_IPL:	ld	a,(hl)
	or	a
	jr	z,PARSE_IP2	;Pone punto al final para facilitar procesado
	cp	32
	jr	z,PARSE_IP2
	cp	9
	jr	z,PARSE_IP2
	cp	10
	jr	z,PARSE_IP2
	cp	13
	jr	z,PARSE_IP2
	cp	26
	jr	z,PARSE_IP2
	inc	hl
	jr	PARSE_IPL
PARSE_IP2:	ld	(hl),"."
	ld	(PARSE_IPDIR),hl

	ld	de,DNS_RESULT
	ld	hl,BUFER_IN
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


;--- UDP_CHKSUM: Calcula el checksum de un datagrama UDP
;    Entrada: IX = Datagrama
;             HL = Puntero a una IP (origen o destino)
;             DE = Puntero a la otra IP
;             BC = Longitud
;    Salida:  DE = Checksum

UDP_CHKSUM:	;

	;Calcula el chksum de la pseudo-cabecera
	;Nota: da igual si el dgrama es entrante o saliente,
	;es decir si se calcula primero el chksum de IP_LOCAL
	;o de IP_REMOTE, pues el resultado sera el mismo

	push	ix,bc
	push	de,hl
	pop	ix	;Una IP
	ld	bc,4
	call	CALC_CHKSUM
	dec	de
	pop	ix	;La otra IP
	ld	bc,4
	call	CALC_CHKSUMP
	dec	de
	ld	ix,PROTO_6	;0 - PTCL
	ld	bc,2
	call	CALC_CHKSUMP
	dec	de
	pop	bc
	ld	a,c
	ld	(CHK_TMP+1),a	;Convierte longitud a big-endian
	ld	a,b
	ld	(CHK_TMP),a
	push	bc
	ld	ix,CHK_TMP
	ld	bc,2
	call	CALC_CHKSUMP
	dec	de
	pop	bc

	;Calcula chksum del datagrama

	bit	0,c
	jr	z,OKBITL	;Si longitud impar, sumamos 1
	pop	ix	;y anyadimos un 0 al final
	push	ix
	add	ix,bc
	ld	(ix),0
	inc	bc
	;srl     b
	;rr      c
OKBITL:	pop	ix
	call	CALC_CHKSUMP
	ret

PROTO_6:	db	0,17
CHK_TMP:	dw	0



;*************************************
;**                                 **
;**   CONSTANTES DE CONFIGURACION   **
;**                                 **
;*************************************

CONS_START:	;

;Como averiguar la mascara de subred:
;0: Configuracion estatica o no hay subred
;1: Usar mensajes ICMP "Mask request"

MASK_METHOD:	db	1

;Mascara de red, deducida automaticamente a partir de la direccion local

NET_MASK:	db	0,0,0,0

;Mascara de subred, establecida automaticamente si MASK_METHOD=1

SUBNET_MASK:	db	0,0,0,0

;Las direcciones de origen tipo 0,<host> o 0.0.0.0 son validas?
;#FF=Si

ZERO_IP_VALID:	db	0

;Flag de autorizacion para enviar mensajes ICMP "Mask reply"
;#FF: Autorizado
;Otro: no autorizado

MASK_REP_AUTH:	db	0

;Numero de paquetes "Mask request" a enviar (si MASK_METHOD=2)

MASK_REQ_NUM:	db	10

;Intervalo entre mensajes "Mask request" en 1/50 seg (si MASK_METHOD=2)

MASK_REQ_INT:	dw	150

;Tiempo entre la primera llegada de un fragmento de un paquete
;y el envio de un error "Fragmentation timeout", en 1/50 seg

FRAG_TIMEOUT:	dw	3000	;60 segundos (minimo recomendado)

;TTL por defecto

TTL_DEFAULT:	db	64

;Ignorar paquetes "echo request" entrantes (#FF) o responderlos (0)

IGNORE_ECHO:	db	0

;Constantes para el resolver

DNS_TOUT_V:	dw	5*50	;Intervalo de ReTx por DNS
DNS_TTOUT_V:	dw	60*50	;Timeout total
DNS_RETRY_V:	db	3	;Maximas ReTx por DNS

CONS_END:	;

CONS_DEF_VAL:	db	0
	db	0,0,0,0
	db	0,0,0,0
	db	0
	db	0
	db	10
	dw	150
	dw	3000
	db	64
	db	0
	dw	5*50
	dw	60*50
	db	3


;************************************
;**                                **
;**   VARIABLES DE CONFIGURACION   **
;**                                **
;************************************

VAR_START:	;

;Direccion IP local

IP_LOCAL:	db	0,0,0,0

;Parte de red de la direccion IP local

IP_LOCAL_NET:	db	0,0,0,0

;Parte de subred de la direccion IP local

IP_LOCAL_SUB:	db	0,0,0,0

;Estado de la mascara de subred:
;0: No establecida aun
;1: Establecida a partir de un mensaje "Mask reply"

MASK_STATUS:	db	0

;Flag de envio automatico de un mensaje "Mask reply"
;#FF si se ha enviado

MASK_REP_SENT:	db	0

;Numero de mensajes "Mask request" enviados

MASK_REQ_SENT:	db	0

;Valor del contador de envio de "Mask request"

MASK_REQ_TIMER:	dw	0

;Bandera de timeout de los mensajes "Mask request"
;#FF: ya se han enviado MASK_REQ_NUM mensajes

MASK_TIMEOUTED:	db	0

;Estado de la capa inferior en la anterior interrupcion
;#FF: disponible

LOWER_STATUS:	db	0

;MRU y MTU

MTU:	dw	0
MRU:	dw	0

;Tamanyos Total, de Cabecera y de Datos del ultimo paquete recibido

LAST_P_TSIZE:	dw	0	;Total
LAST_P_HSIZE:	dw	0	;Cabecera
LAST_P_DSIZE:	dw	0	;Datos

;Idem para el paquete saliente a componer

PUT_P_TSIZE:	equ	LAST_P_TSIZE	;Total
PUT_P_HSIZE:	equ	LAST_P_HSIZE	;Cabecera
PUT_P_DSIZE:	equ	LAST_P_DSIZE	;Datos
PUT_P_PSIZE:	dw	0	;Total (como lo encola el usuario)

OPTIONS_LEN:	dw	0	;Longitud opciones paquete a componer
PUT_P_DPNT:	dw	0	;Puntero a los datos en paq d usuario

;Variables usadas al tratar fragmentos

FRAG_T_LEN:	equ	LAST_P_TSIZE	;Tamanyo total
FRAG_H_LEN:	equ	LAST_P_HSIZE	;Tamanyo cabecera
;FRAG_D_LEN:       equ     BUFER_COMP+62    ;Tamanyo datos (definido al final)

CUR_FRAG:	db	0	;Numero de paquete en tratamiento
CUR_FRAG_FLAG:	db	0	;Flags devueltos por NestorMan
	;                        ;al extraer el frag. de la lista

FRAG_FIRST:	dw	0	;Variables para el algoritmo
FRAG_LAST:	dw	0	;de Clark
HOLE_FIRST:	dw	0
HOLE_LAST:	dw	0
HOLE_PREV:	dw	0
HOLE_NEXT:	dw	0

FRAG_LEN:	dw	0

;El ultimo paquete recibido era broadcast?
;Si: #FF

PAQ_IS_BROAD:	db	0

;Numero de paquetes fragmentados pendientes
;y tabla de temporizadores de timeout.
;El lugar en la tabla se corresponde con la posicion del paquete
;pendiente en FRAG_QUEUE

NUM_FRAG_PEND:	db	0
FRAG_TABLE:	ds	256*2
	db	0,0	;Para que siempre encuentre un fin de lista

;Variables para la consulta DNS

DNS_PRIM:	ds	4	;DNS primario
DNS_SEC:	ds	4	;DNS secundario
DNS_STAT_P:	db	0	;Estado actual, primario
DNS_STAT_S:	db	0	;Estado actual, secundario
DNS_TOUT:	dw	0	;Contador de timeout para el DNS en curso
DNS_TTOUT:	dw	0	;Contador de timeout total
DNS_RETRY:	db	0	;Contador de ReTx para el DNS en curso
DNS_TOUT_NOW:	dw	0
DNS_TTOUT_NOW:	dw	0
DNS_RETRY_NOW:	db	0
DNS_RESULT:	ds	4	;Resultado devuelto por el DNS
DNS_P_SIZE:	dw	0	;Tamanyo del paquete DNS en BUFER_DNS
ANCOUNT:	dw	0
ARCOUNT:	dw	0
NSCOUNT:	dw	0

VAR_ZONE_END:	;*** Hasta aqui, se resetea al hacer un OPEN

;Identificador de paquete IP
;Se incrementa con cada paquete enviado

IP_IDENTIF:	dw	0

;Identificador de paquete DNS
;Se incrementa con cada consulta nueva

DNS_IDENTIF:	dw	0

;Segmentos de las capas superior e inferior

UPPER_SEG:	db	0
LOWER_SEG:	db	0

;*** Colas de entrada para cada protocolo
;    El 0 es la entrada desde el modulo inferior (IP_IN_QUEUE)
;    El 255 es la salida desde el modulo superior (PROT_OUT_QUEUE)

FRAG_QUEUE:	ds	3
IP_OUT_QUEUE:	ds	3

PROT_IN_QUEUES:	;
IP_IN_QUEUE:	ds	3
	ds	(256-2)*3
PROT_OUT_QUEUE:	ds	3
DNS_IN_QUEUE:	ds	3

VAR_END:	;



;**********************************
;***                            ***
;***   PAQUETES PREFABRICADOS   ***
;***                            ***
;**********************************

;--- Paquete Mask Request

	;Parte IP

MASKREQ_P:	db	255,255,255,255	;Paquete broadcast
	db	1	;Protocolo ICMP
	db	0	;Fin de campos opcionales

	;Parte ICMP

	db	17	;Codigo de "Mask request"
	db	0	;Codigo
MASKREQ_P_CS:	db	#EE,#FF	;Checksum precalculado
	db	0,0,0,0	;Id. y seq. num., no se usan
	db	0,0,0,0	;mascara vacia
MASKREQ_P_END:	;

;--- Paquete Mask Reply

	;Parte IP

MASKREP_P:	db	0,0,0,0	;Direccion a establecer
	db	1	;Protocolo ICMP
	db	0	;Fin de campos opcionales

	;Parte ICMP

	db	18	;Codigo de "Mask reply"
	db	0	;Codigo
MASKREP_P_CS:	db	0,0	;Checksum a calcular
	db	0,0,0,0	;Id. y seq. num., no se usan
MASKREP_MASK:	db	0,0,0,0	;Mascara a establecer
MASKREP_P_END:	;


;--- Paquete "Protocol unreachable"

	;Parte IP

PROTUN_P:	db	0,0,0,0	;Direccion a especificar
	db	1	;Protocolo ICMP
	db	0	;Fin de campos opcionales

	;Parte ICMP

	db	3	;Codigo de "Destination unreachable"
	db	2	;Codigo de "Protocol unreachable"
PROTUN_P_CS:	db	0,0	;Checksum a calcular
	db	0,0,0,0	;No se usa
PROTUN_P_H:	ds	64+8	;Cabecera + 8 bytes del paq. antiguo
PROTUN_P_END:	db	0


;--- Paquete "Fragmentation timeout"

	;Parte IP

FRAGTOUT_P:	db	0,0,0,0	;Direccion a especificar
	db	1	;Protocolo ICMP
	db	0	;Fin de campos opcionales

	;Parte ICMP

	db	11	;Codigo de "Timeout exceeded"
	db	1	;Codigo de "Fragmentation timeout"
FRAGTOUT_P_CS:	db	0,0	;Checksum a calcular
	db	0,0,0,0	;No se usa
FRAGTOUT_P_H:	ds	64+8	;Cabecera + 8 bytes del paq. antiguo
FRAGTOUT_P_END:	db	0


;--- Paquete DNS

DNS_P:	;
	db	0,0,0,0	;IP destino
	db	17	;Protocolo UDP
	db	4,255	;TTL=255
	db	0

	;Aqui empieza el UDP

DNS_UDP_START:	dw	DNS_PORT	;Puerto origen
	db	0,53	;Puerto destino
DNS_UDP_LENGTH:	db	0,0	;Longitud UDP en bytes
DNS_UDP_CHKSUM:	db	0,0	;Checksum

	;Aqui empieza el paquete DNS

DNS_START:	db	#12,#34	;ID
DNS_FLAGS:	db	1,0	;Flags (pedimos peticion recursiva)
	db	0,1	;QDCOUNT
	db	0,0	;ANCOUNT
	db	0,0	;NSCOUNT
	db	0,0	;ARCOUNT

	;Aqui debe ir el nombre del servidor

QUERY_SERV:	;

DNS_P_END:	;


;*******************
;***             ***
;***   BUFERES   ***
;***             ***
;*******************

BUFERS:	;

BUFER_IN:	equ	BUFERS+2
BUFER_OUT:	equ	BUFER_IN+2100
BUFER_COMP:	equ	BUFER_OUT+2100
BUFER_FRAG:	equ	BUFER_COMP+2100
BUFER_DNS	equ	BUFER_FRAG+2100

END_BUFERS:	equ	BUFER_DNS+512
FRAG_D_LEN:	equ	BUFER_COMP+62	;Tamanyo datos paq. fragmentado

