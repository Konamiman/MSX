; TCP module for InterNestor Suite

;=====================
	
	;--- Modulo TCP para Internestor Suite
	;    VERSION RESIDENTE 0.3
	;    Necesita NestorMan 1.21

	;- No examina paquetes ICMP entrantes, ni genera salientes
	;- Ignora las opciones IP
	;- Ignora "security/compartment" y "precedence"
	;- Solo reconoce la opcion TCP de SMSS

	;Cambios en 0.2:

	;- Ahora cuando llega un paquete en SYN-SENT,
	;  se comprueba si SEG_ACK=ISS+1, en vez de SEG_ACK<=ISS
	;  y SEG_ACK>SND_NXT
	;- Se ejecuta SET_RTO cada vez que se envia un SYN
	;  (si no, los SYN nunca se retransmiten)
	;- Se guarda el TCB actual antes de ejecutarse la
	;  rutina de interrupcion si INT_LEVEL=1
	;  (ya que entonces se esta ejecutando SEND o RCV,
	;  que a su vez modifican el TCB)
	;- SEG_PEND_HSIZE era cargado con un valor de
	;  16 bits, cuando en realidad es de 8
	;- Etc...

	;Cambios en 0.3:

	;- Arreglado un fallo en la rutina de retransmision
	;  (al extraer un paquete, se comprobaba el error con
	;  "jr z" en vez de "jr nc")
	;- RETX_MAX cambiado a 5000, RETX_SMAX a 10000
	;- Al retransmitir SYN, ahora no se incluye ACK
	;- Se detiene RTO correctamente cuando no queda
	;  nada para ReTx
	;- Se ReTx correctamente los datos
	;- Inicializa RTO a 150 cuando llega un ACK
	;- Arreglada la rutina SET_WNDWL, que trataba SND_WND
	;  como si fuera de 32 bits cuando es de 16
	;- Arreglada la prueba de ventana cero
	;- Arreglado el calculo del timeout y del RTT
	;- Arreglado RTT_M_SEQ, que era de 2 bytes, ahora es de 4

	.label	20

ALWAYS_INDIR:	equ	0	;1 para que las llamadas a NestorMan
	;                        ;siempre sean indirectas
IGNORE_CHK:	equ	0	;1 para ignorar el checksum
	;                        ;de los paquetes entrantes

NUM_CON_MAX:	equ	8	;Maximo numero de conexiones simult.
MSL_T_MAX:	equ	120*50	;Maximum Segment Lifetime
ECHO_PORT:	equ	#0700	;Puerto del servidor de eco (big e.)

nesman:	macro	@f
	if	ALWAYS_INDIR=1
	ld	c,@f
	ld	de,#2202
	call	#FFCA
	else
	call	#4100+3*@f
	endif
	endm

nesmani:	macro	@f
	ld	c,@f
	ld	de,#2202
	call	#FFCA
	endm

copy32:	macro		;Uso: LD HL,origen: LD DE,destino: copy32
	ld	bc,4
	ldir
	endm

swap_de:	macro
	ld	a,d
	ld	d,e
	ld	e,a
	endm

swap_hl:	macro
	ld	a,h
	ld	h,l
	ld	l,a
	endm


	;--- Llamadas del DOS

_GDATE:	equ	#2A
_GTIME:	equ	#2C

	;--- Llamadas al modulo IP

IP_QUEUES:	equ	#800C
IP_TABLES:	equ	#8021
IP_CREATE_PROT:	equ	#8024
IP_DESTR_PROT:equ	#8027

	;--- Llamadas al modulo de nivel 2

LV2_CHK_TLU:	equ	#800F
LV2_IPS:	equ	#8018
LV2_MXU:	equ	#801E

	;--- Estados de una conexion

CLOSED:	equ	0	;Ficticio
LISTEN:	equ	1
SYN.SENT:	equ	2
SYN.RECEIVED:	equ	3
ESTABLISHED:	equ	4
FIN.WAIT.1:	equ	5
FIN.WAIT.2:	equ	6
CLOSE.WAIT:	equ	7
CLOSING:	equ	8
LAST.ACK:	equ	9
TIME.WAIT:	equ	10

	;--- Bits de control

FIN:	equ	0
SYN:	equ	1
RST:	equ	2
PSH:	equ	3
ACK:	equ	4
URG:	equ	5

	;--- Macro para comprobar los bits de control
	;    ("bit XXX,y" da error si XXX es una etiqueta)

_bit:	macro	@b,@r
	if	@b=0
	bit	0,@r
	endif
	if	@b=1
	bit	1,@r
	endif
	if	@b=2
	bit	2,@r
	endif
	if	@b=3
	bit	3,@r
	endif
	if	@b=4
	bit	4,@r
	endif
	if	@b=5
	bit	5,@r
	endif
	if	@b=6
	bit	6,@r
	endif
	if	@b=7
	bit	7,@r
	endif
	endm

	;--- Macro para establecer los bits de control
	;    ("set XXX,y" da error si XXX es una etiqueta)

_set:	macro	@b,@r
	if	@b=0
	set	0,@r
	endif
	if	@b=1
	set	1,@r
	endif
	if	@b=2
	set	2,@r
	endif
	if	@b=3
	set	3,@r
	endif
	if	@b=4
	set	4,@r
	endif
	if	@b=5
	set	5,@r
	endif
	if	@b=6
	set	6,@r
	endif
	if	@b=7
	set	7,@r
	endif
	endm



;***********************************
;***                             ***
;***   CABECERA IDENTIFICADORA   ***
;***                             ***
;***********************************

	;--- #0000: Texto identificador de 256 caracteres

	org	#1000

HEADER:	db	"NestorTCP 0.3",13,10
	db	"* No IP options/ICMP packets processing",13,10
	db	"A level 4 module for InterNestor Suite",13,10
	db	"By Konami Man, 6-2002",13,10
	db	#1A
HEAD_END:	;
	ds	256-(HEAD_END-HEADER)

	;--- #0100: Cadena identificadora de 32 caracteres

	db	"NestorTCP 0.3                   "

	;--- #0120: Identificador de modulo de InterNestor Suite

	db	"INESUITE"

	;--- #0128: Version

	db	0,3,0

	;--- #012B: Nivel del modulo

	db	4

	;--- Hasta #200: Reservado para futura expansion

	ds	#200-#012B-1



;**************************
;***                    ***
;***   TABLA DE SALTO   ***
;***                    ***
;**************************

	org	#8003

	;--- Rutinas obligatorias

	jp	TCP_RESET	;#8003: Reset
	jp	TCP_DEINIT	;#8006: Desinicializacion
	jp	TCP_INT	;#8009: Atencion a la interrupcion
	jp	TCP_QUEUES	;#800C: Direcciones de las colas
	ds	15,#C9	;Rellena espacio sobrante con RETs

	;--- Rutinas especificas de NestorTCP

	jp	TCP_TABLES	;#801E: Direcciones de las tablas
	jp	TCP_OPEN	;#8021: Abre una conexion
	jp	TCP_CLOSE	;#8024: Cierra una conexion
	jp	TCP_ABORT	;#8027: Aborta una conexion
	jp	TCP_SEND	;#802A: Envia datos
	jp	TCP_RCV	;#802D: Recibe datos
	jp	TCP_STATUS	;#8030: Estado de una conexion
	jp	TCP_FLUSH_OUT	;#8033: Borra colas de datos pend.



;****************************************
;***                                  ***
;***   RUTINAS DE LA TABLA DE SALTO   ***
;***                                  ***
;****************************************

	;--- Reset
	;    Inicializa variables
	;    Obtiene el segmento de los modulos inferior y superior

TCP_RESET:	ld	hl,PROT_OUT_QUEUE
	ld	de,PROT_OUT_QUEUE+1
	ld	(hl),0	;Desde ahora desconocemos
	ld	bc,3*3-1	;las dirs de las colas externas
	ldir

	;xor     a
	;ld      (RCVED),a

	ld	a,(NUM_CON)
	or	a
	jr	z,TCP_RESET2

	ld	b,NUM_CON_MAX	;Aborta las conexiones, si hay
TCP_RES_LOP1:	push	bc
	ld	a,b
	dec	a
	call	TCP_ABORT
	pop	bc
	djnz	TCP_RES_LOP1

TCP_RESET2:	ld	hl,TCB_CON	;Limpia los TCBs
	ld	de,TCB_CON+1
	ld	bc,TCB_SIZE*NUM_CON_MAX-1
	ld	(hl),0
	ldir

	ld	hl,VAR_START	;Inicializa vars y ctes
	ld	de,VAR_START+1
	ld	bc,VAR_END-VAR_START-1
	ld	(hl),0
	ldir
	ld	hl,CONS_DEF_VAL
	ld	de,CONS_START
	ld	bc,CONS_END-CONS_START
	ldir
	ld	hl,1023
	ld	(LAST_LOC_PORT),hl
	ld	a,-1
	ld	(LAST_USED_CON),a
	ld	hl,TCB_CON-TCB_SIZE
	ld	(LAST_USED_TCB),hl

	ld	de,#0402	;Obtiene rutinas del mapeador
	call	#FFCA
	ld	de,ALL_SEG
	ld	bc,#30
	ldir

	nesmani	32
	push	de
	ld	a,b
	nesmani	3
	ld	a,c
	ld	(LV2_SEG),a	;Segmentos modulos IP y nivel 2
	pop	de
	ld	a,e
	nesmani	3
	ld	a,c
	ld	(IP_SEG),a

	;Genera los dos bytes altos del contador de ISS:
	;Byte 3 = hora + 32*dia de la semana
	;Byte 2 = minuto

	;ld      c,_GDATE
	;call    5                ;#F37D
	;and     %111
	;rrc     a
	;rrc     a
	;rrc     a
	;push    af
	;ld      c,_GTIME
	;call    5                ;#F37D
	;pop     af
	;or      h
	;ld      (ISS_T),a
	;ld      a,l
	;ld      (ISS_T+1),a
	;ld      a,d
	;ld      (ISS+2),a
	;ld      a,(#FC9E)
	;ld      (ISS+3),a

	or	a	;Nunca devuelve error
	ret


	;--- Deinit
	;    Aborta todas las conexiones

TCP_DEINIT:	ld	a,#FF
	ld	(DEINITING),a

	ld	a,(NUM_CON)
	or	a
	jp	z,TCP_RESET2

	ld	b,NUM_CON_MAX	;Aborta las conexiones, si hay
TCP_DEIN_LOP1:	push	bc
	ld	a,b
	dec	a
	push	af
	call	LOAD_CON
	pop	af
	call	TCP_DELETE
	pop	bc
	djnz	TCP_DEIN_LOP1

	xor	a
	ld	(IP_SEG),a
	ld	(LV2_SEG),a

	ld	hl,PROT_OUT_QUEUE
	ld	de,PROT_OUT_QUEUE+1
	ld	(hl),0	;Desde ahora desconocemos
	ld	bc,3*3-1	;las dirs de las colas externas
	ldir

	xor	a
	ld	(DEINITING),a
	ret


	;--- Queues
	;    Devuelve siempre Cy=1, pues no hay colas propias
	;    excepto las de las conexiones, que estan en el TCB

TCP_QUEUES:	scf
	ret


	;--- Devuelve en HL la dir de la tabla especificada en A:
	;    (y en BC su longitud)
	;    0: Constantes de configuracion
	;    1: Constantes por defecto
	;    2: Variables de configuracion
	;    3: TCB de la ultima conexion usada (TCB_CUR)
	;    Otro: N+4 = tabla de la conexion N
	;    Devuelve Cy=1 para A desconocido

TCP_TABLES:	or	a
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
	ld	hl,TCB_CUR
	ld	bc,TCB_SIZE
	ret	z
	cp	NUM_CON_MAX+4	;Devuelve error si A>NUM_CON_MAX+3
	ccf
	ret	c
	sub	3
	ld	b,a
	ld	hl,TCB_CON-TCB_SIZE
	ld	de,TCB_SIZE
TCB_TAB_LOP:	add	hl,de	;Calcula la dir del TCB
	djnz	TCB_TAB_LOP
	ld	bc,TCB_SIZE
	or	a
	ret


;---------------------
;---  Rutina OPEN  ---
;---------------------

	;--- OPEN: Abre una conexion TCP
	;    Entrada: HL = Puntero a un pseudo-TCB en TPA
	;    Salida:  Cy=0 y A=num. de conexion, o:
	;             Cy=1 y A=codigo de error:
	;                1: Demasiadas conexiones abiertas
	;                2: No hay conexion a internet
	;                3: Ya existe esa conexion
	;                   y no esta LISTEN
	;                4: Se requiere conexion activa
	;                   pero la IP remota es 0.0.0.0
	;    Formato del pseudo-TCB:
	;      +0: IP remota
	;      +4: Puerto remoto
	;      +6: Puerto local (#FFFF para elegirlo automaticamente)
	;      +8: 0 para conexion activa, 1 para pasiva
	;      +9: Parametros opcionales
	;      0
	;    Los parametros opcionales son:
	;      1+timeout de usuario (def: 5 minutos)
	;        0 significa que no hay tout de usuario
	;     .2+TOS a usar (def: 0)
	;      3+maximo permitido para RETX_EX_MAX
	;      4+maximo permitido para RETX_EX_SMAX
	;      5+tamanyo del bufer de recepcion (def: DEF_RCV_BUF)
	;     .6+valor de ACK_DELAY_MAX (def: 25)
	;      7+valor de ACK_RCV_MAX (def: se calcula 2*SMSS)
	;        0 significa que se calcula 2*SMSS
	;      8+valor maximo de RTO (def: 60 seg)
	;        0 significa que no hay valor maximo
	;      9+RMSS (def: MRU-40)
	;        0 signigica MRU-40
	;     .10+Usar algoritmo de Nagle (#FF) o no (0)
	;         (defecto:#FF)
	;      11+MSL para TIME-WAIT (def: MSL_T_MAX)
	;     (.X = valores de 1 byte, el resto de 2 bytes)

	;- Si no se espcifica el socket remoto (IP remota=0.0.0.0 y
	;  puerto remoto=0), se crea una conexion nueva sin
	;  comprobar si el puerto local esta en uso.
	;- Si existe una conexion pasiva en estado LISTEN
	;  con la misma combinacion de puerto local, puerto remoto
	;  e IP remota, se convierte esa conexion a activa
	;  y no se crea una nueva.

TCP_OPEN:	push	af
	ld	a,2
	ld	(INT_LEVEL),a
	pop	af
	call	_TCP_OPEN
	push	af
	xor	a
	ld	(INT_LEVEL),a
	pop	af
	ret

_TCP_OPEN:	;--- Lo primero es comprobar si estamos conectados
	;    a internet

	push	hl
	ld	ix,LV2_CHK_TLU
	call	CALL_LV2
	pop	hl
	ccf
	ld	a,2
	ret	c

	;--- Obtiene el pseudo-TCB

	push	hl
	pop	ix
	ld	a,(#8002)
	ld	b,a
	ld	iy,BUFER_GEN
	ld	hl,64
	nesmani	15

	;--- Si el puerto local es #FFFF, escoge uno

	ld	hl,(BUFER_GEN+6)
	inc	hl
	ld	a,h
	or	l
	dec	hl
	jr	nz,TCP_OPEN1

	ld	hl,(LAST_LOC_PORT)
	ld	de,#FFFE
	call	COMP16
	jr	nz,OTHER_PORT
	ld	hl,1023
OTHER_PORT:	inc	hl	;Selecciona un puerto que no
	push	hl	;este ya en uso
	ex	de,hl
	call	PORT_IN_USE
	pop	hl
	jr	c,OTHER_PORT
	ld	(LAST_LOC_PORT),hl

	;--- Convierte los puertos a big-endian

TCP_OPEN1:	ld	a,h
	ld	(BUFER_GEN+6),a
	ld	a,l
	ld	(BUFER_GEN+7),a
	ld	hl,(BUFER_GEN+4)
	ld	a,h
	ld	(BUFER_GEN+4),a
	ld	a,l
	ld	(BUFER_GEN+5),a

	;--- Si la IP remota es 127.x.x.x,
	;    la convierte a la IP local

	ld	a,(BUFER_GEN)
	cp	127
	jr	nz,NO_LPBCK
	ld	hl,LOCAL_IP
	ld	de,BUFER_GEN
	copy32
NO_LPBCK:	;

	;--- Si ya hay conexiones, comprueba si hay alguna
	;    en la que coincidan la IP remota y los puertos.
	;    Dicha comprobacion no se hace si la apertura es
	;    pasiva y el socket remoto esta sin especificar
	;    (IP remota y puerto remoto a 0)

	ld	a,(NUM_CON)
	or	a
	jp	z,TCPOPEN_NEWCON

	ld	ix,BUFER_GEN
	ld	a,(ix)	;Socket remoto=0 y apertura
	or	(ix+1)	;pasiva? Entonces salta
	or	(ix+2)	;directamente a NEWCON
	or	(ix+3)
	or	(ix+4)
	or	(ix+5)
	jr	nz,TCPOP_LOOP0
	ld	a,(ix+8)
	or	a
	jp	nz,TCPOPEN_NEWCON

TCPOP_LOOP0:	ld	hl,TCB_CON
	ld	de,TCB_SIZE
	ld	b,NUM_CON_MAX
	ld	c,0
TCPOP_LOOP1:	ld	a,(hl)	;Busca conexion existente
	or	a
	jr	z,TCPOP_LOOP2

	push	hl,de,bc	;HL=TCB de la conexion
	inc	hl
	ld	de,BUFER_GEN
	call	COMP32
	pop	bc,de,hl
	jr	nz,TCPOP_LOOP2
	push	hl,de,bc
	ld	bc,5
	add	hl,bc
	ld	de,BUFER_GEN+4
	call	COMP32
	pop	bc,de,hl
	jr	z,TCPOPEN_MATCH

TCPOP_LOOP2:	add	hl,de
	inc	c
	djnz	TCPOP_LOOP1
	jr	TCPOPEN_NEWCON

	;--- Conexion coincidente encontrada

TCPOPEN_MATCH:	ld	a,c
	call	LOAD_CON

	;Si no esta en estado LISTEN, se devuelve error

	ld	a,(CUR_STATE)
	cp	LISTEN
	ld	a,3
	scf
	ret	nz

	;Si se requiere conexion activa pero no se especifica
	;socket remoto, se devuelve error
	;(eliminado porque si se requiere conexion activa,
	; nunca llegaremos a este punto)

	;ld      ix,BUFER_GEN     ;Conexion activa y socket
	;ld      a,(ix)           ;remoto=0?
	;or      (ix+1)
	;or      (ix+2)
	;or      (ix+3)
	;or      (ix+5)
	;or      (ix+6)
	;or      (ix+8)
	;jr      nz,TCPOP_MATCH3

	;xor     a                ;Borra TCB
	;ld      (CUR_STATE),a
	;ld      a,(CUR_CON)
	;call    SAVE_CON
	;ld      hl,NUM_CON
	;dec     (hl)
	;call    DESTR_TCB_QUEUES

	;ld      a,4
	;scf
	;ret

	;Si se requiere conexion pasiva,
	;simplemente se termina con error 3

TCPOP_MATCH2:	ld	a,(BUFER_GEN+8)
	or	a
	jr	z,TCPOP_MATCH3

	ld	a,3
	scf
	ret

	;Se require conexion activa y el socet remoto no es 0:
	;se modifica la conexion actual como si fuera nueva

TCPOP_MATCH3:	jp	TCPOP_NEW2

	;--- No hay conexiones coincidentes: se crea una nueva

TCPOPEN_NEWCON:	ld	a,(NUM_CON)	;Comprueba cuantas
	cp	NUM_CON_MAX	;conexiones abiertas hay
	ccf
	ld	a,1
	ret	c

	ld	ix,BUFER_GEN	;Devuelve error 4
	ld	a,(ix)	;si se pide conexion activa
	or	(ix+1)	;pero la IP remota es 0.0.0.0
	or	(ix+2)
	or	(ix+3)
	or	(ix+8)
	ld	a,4
	scf
	ret	z

	ld	hl,NUM_CON
	inc	(hl)

	;--- Busca una conexion libre e inicializa TCB
	;    con valores por defecto

	ld	hl,TCB_CON
	ld	bc,TCB_SIZE
	ld	d,0
TCP_OPEN_LOP1:	ld	a,(hl)	;Busca una conexion libre
	or	a
	jr	z,TCB_OPEN_OK1
	add	hl,bc
	inc	d
	jr	TCP_OPEN_LOP1
TCB_OPEN_OK1:	;

	ld	a,d
	ld	(CUR_CON),a	;Inicializa TCB_CUR como
	ld	hl,TCB_CUR	;el TCB de la conexion nueva,
	ld	de,TCB_CUR+1	;con los valores por defecto
	ld	bc,TCB_SIZE-1
	ld	(hl),0
	ldir
	ld	hl,536
	ld	(SMSS),hl
	ld	(EFF_SMSS),hl
	ld	hl,536*2
	ld	(SMSS2),hl
	ld	hl,5000
	ld	(RETX_EX_MAX),hl
	ld	hl,10000
	ld	(RETX_EX_SMAX),hl
	ld	hl,15000
	ld	(USER_TOUT_V),hl
	ld	hl,3000
	ld	(RTO_MAX),hl
	ld	hl,(DEF_RCV_BUF)
	ld	(RCV_BUF),hl
	ld	(RCV_WND),hl
	srl	h
	rr	l
	ld	(RCV_BUF2),hl
	ld	hl,4096
	ld	(SSTHRESH),hl	;"Advertised window" es SND o RCV???
	ld	a,25
	ld	(OVERR_TOUT_V),a
	;ld      a,250            ;*** PRUEBAS: debe ser 25
	ld	(ACK_DELAY_MAX),a
	ld	hl,536*2
	ld	(ACK_RCV_MAX),hl
	ld	(CWND),hl
	ld	hl,150
	ld	(RTO),hl
	ld	(LAST_USED_RTO),hl
	ld	(IDLE_T),hl
	ld	hl,(MRU)
	ld	bc,40
	or	a
	sbc	hl,bc
	ld	(RMSS),hl
	ld	a,#FF
	ld	(NAGLE_ON),a
	ld	hl,MSL_T_MAX
	ld	(MSL_T_CUR),hl
	ld	hl,150
	ld	(PROBE_ZW_V),hl
	ld	(PROBE_ZW_T),hl

	;--- Crea las colas

	scf
	nesmani	20
	ld	(DATA_IN_QUEUE),a
	ld	(DATA_IN_QUEUE+1),ix
	scf
	nesmani	20
	ld	(DATA_OUT_QUEUE),a
	ld	(DATA_OUT_QUEUE+1),ix
	scf
	nesmani	20
	ld	(RETX_QUEUE),a
	ld	(RETX_QUEUE+1),ix
	;scf
	;nesmani 20
	;ld      (OOO_IN_QUEUE),a
	;ld      (OOO_IN_QUEUE+1),ix

	;--- Examina el pseudo-TCB pasado,
	;    y modifica las variables adecuadas

	;Primero copia los campos obligatorios

	ld	hl,BUFER_GEN
	ld	de,TCB_CUR+1
	ld	bc,8
	ldir

	ld	a,(BUFER_GEN+8)
	ld	(PASSIVE_OPEN),a

	;Despues examina los campos opcionales

	ld	ix,BUFER_GEN+9
TCPOP_PARS:	ld	a,(ix)

	;* 0: Fin de parametros opcionales

TCPOP_PAR0:	or	a
	jp	z,TCPOP_PAREND

	;* 1: Timeout de usuario

TCPOP_PAR1:	cp	1
	jr	nz,TCPOP_PAR2
	ld	l,(ix+1)
	ld	h,(ix+2)
	ld	(USER_TOUT_V),hl
	inc	ix
	inc	ix
	inc	ix
	jr	TCPOP_PARS

	;* 2: TOS a usar

TCPOP_PAR2:	cp	2
	jr	nz,TCPOP_PAR3
	ld	a,(ix+1)
	ld	(SEND_TOS),a
	inc	ix
	inc	ix
	jr	TCPOP_PARS

	;* 3: RETX_EX_MAX

TCPOP_PAR3:	cp	3
	jr	nz,TCPOP_PAR4
	ld	l,(ix+1)
	ld	h,(ix+2)
	ld	(RETX_EX_MAX),hl
	inc	ix
	inc	ix
	inc	ix
	jr	TCPOP_PARS

	;* 4: RETX_EX_SMAX

TCPOP_PAR4:	cp	4
	jr	nz,TCPOP_PAR5
	ld	l,(ix+1)
	ld	h,(ix+2)
	ld	(RETX_EX_SMAX),hl
	inc	ix
	inc	ix
	inc	ix
	jr	TCPOP_PARS

	;* 5: RCV_BUF

TCPOP_PAR5:	cp	5
	jr	nz,TCPOP_PAR6
	ld	l,(ix+1)
	ld	h,(ix+2)
	ld	(RCV_BUF),hl
	srl	h
	rr	l
	ld	(RCV_BUF2),hl
	inc	ix
	inc	ix
	inc	ix
	jr	TCPOP_PARS

	;* 6: ACK_DELAY_MAX

TCPOP_PAR6:	cp	6
	jr	nz,TCPOP_PAR7
	ld	a,(ix+1)
	ld	(ACK_DELAY_MAX),a
	inc	ix
	inc	ix
	jp	TCPOP_PARS

	;* 7: ACK_RCV_MAX

TCPOP_PAR7:	cp	7
	jr	nz,TCPOP_PAR8
	ld	l,(ix+1)
	ld	h,(ix+2)
	inc	ix
	inc	ix
	inc	ix
	ld	a,h
	or	l
	jp	z,TCPOP_PARS	;Si es 0, se ignora
	ld	(ACK_RCV_MAX),hl
	jp	TCPOP_PARS

	;* 8: RTO

TCPOP_PAR8:	cp	8
	jr	nz,TCPOP_PAR9
	ld	l,(ix+1)
	ld	h,(ix+2)
	ld	(RTO),hl
	ld	(LAST_USED_RTO),hl
	inc	ix
	inc	ix
	inc	ix
	jp	TCPOP_PARS

	;* 9: RMSS

TCPOP_PAR9:	cp	9
	jr	nz,TCPOP_PAR10
	ld	l,(ix+1)
	ld	h,(ix+2)
	inc	ix
	inc	ix
	inc	ix
	ld	a,h
	or	l
	jp	z,TCPOP_PARS	;Si es 0, se ignora
	ld	(RMSS),hl
	jp	TCPOP_PARS

	;* 10: Algoritmo de Nagle on/off

TCPOP_PAR10:	cp	10
	jr	nz,TCPOP_PAR11	;Si es desconocido, se ignora el resto
	ld	a,(ix+1)
	ld	(NAGLE_ON),a
	inc	ix
	inc	ix
	jp	TCPOP_PARS

	;* 11: MSL para TIME-WAIT

TCPOP_PAR11:	cp	11
	jr	nz,TCPOP_PAREND
	ld	l,(ix+1)
	ld	h,(ix+2)
	inc	ix
	inc	ix
	inc	ix
	ld	(MSL_T_CUR),hl
	jp	TCPOP_PARS
TCPOP_PAREND:	;

	;--- Si la conexion requerida es pasiva,
	;    pasa a estado LISTEN y termina

	;call    GEN_ISS          ;Selecciona el ISS ahora

	ld	a,(BUFER_GEN+8)
	or	a
	jr	z,TCPOP_ACT

	ld	a,LISTEN
	ld	(CUR_STATE),a

	jr	TCP_OPEND
TCPOP_ACT:	;

	;--- Selecciona ISS, envia paquete con <SEQ=ISS><CTL=SYN>,
	;    establece SND.UNA, SND.NXT y CON.STATE, y pasa
	;    a estado SYN.SENT

TCPOP_NEW2:	call	GEN_ISS

	;Crea paquete con SEQ=ISS y SYN
	;y establece SND_UNA=ISS, SND_NXT=ISS+1
	;Antes de enviarlo pasa a SYN.SENT

	ld	a,SYN.SENT
	ld	(CUR_STATE),a

	ld	hl,ISS
	ld	de,SND_UNA
	copy32
	ld	hl,ISS
	ld	bc,SND_NXT
	call	INC32
	call	INIT_UTOUT

	call	INCLUDE_SYN
	call	SEND_DGRAMI	;Envia dgrama sin datos
	call	SET_RTO

	;--- Graba TCB y termina

TCP_OPEND:	ld	a,(CUR_CON)
	call	SAVE_CON
	or	a
	ret

NULL32:	db	0,0,0,0


;----------------------
;---  Rutina CLOSE  ---
;----------------------

	;--- CLOSE: Cierra una conexion TCP
	;    Entrada: A = Numero de conexion
	;    Salida:  Cy=1 si error y A=error:
	;                1: La conexion no existe
	;                2: La conexion ya se esta cerrando

TCP_CLOSE:	push	af
	ld	a,2
	ld	(INT_LEVEL),a
	pop	af
	call	_TCP_CLOSE
	push	af
	xor	a
	ld	(INT_LEVEL),a
	pop	af
	ret

_TCP_CLOSE:	call	LOAD_CON_CHK
	ret	c

	;--- Si la conexion esta LISTEN o SYN.SENT,
	;    se borra el TCB y se termina

	ld	a,(CUR_STATE)
	cp	LISTEN
	jp	z,TCP_DELETE
	cp	SYN.SENT
	jp	z,TCP_DELETE

	;--- Establece todos los datos pendientes como PUSHED

	ld	hl,DATA_OUT_LAST
	ld	de,SEND_PUSH_LAST
	copy32
	ld	a,1
	ld	(SEND_PUSH),a
	ld	a,(OVERR_TOUT_V)
	ld	(OVERR_T),a

	;--- Si estado es SYN.RECEIVED:
	;    Si quedan datos pendientes, establece CLOSE_PENDING
	;    y termina.
	;    Si no, envia un segmento con FIN y pasa a FIN.WAIT.1.

	ld	a,(CUR_STATE)
	cp	SYN.RECEIVED
	jr	nz,TCP_CLOSE3
	ld	a,FIN.WAIT.1

TCP_CLOSE0:	ld	b,a
	ld	hl,DATA_OUT_SIZE
	ld	de,NULL32
	call	COMP32
	jr	nz,TCP_CLOSE_PEND
	ld	hl,RETX_SIZE
	ld	de,NULL32
	call	COMP32
	jr	nz,TCP_CLOSE_PEND
	;ld      a,(SYN_SENT_FLAG);Si se ha enviado SYN, se considera
	;or      a                ;como dato en la cola de ReTx
	;jr      nz,TCP_CLOSE_PEND;(aunque nunca deberia ocurrir)
	ld	a,b

	;No quedan datos pendientes (nuevos ni a retransmitir)

	push	af
	call	INCLUDE_FIN
	xor	a
	call	INCLUDE_ACK
	call	SEND_DGRAMI
	pop	af
	ld	(CUR_STATE),a
	jr	TCP_CLOSE_OK
TCP_CLOSE3:	;

	;--- Si estado es ESTABLISHED:
	;    Pasa a estado FIN.WAIT.1
	;    Si quedan datos pendientes, establece CLOSE_PENDING
	;    y termina.
	;    Si no, envia un segmento con FIN y termina.

	cp	ESTABLISHED
	jr	nz,TCP_CLOSE4

	ld	a,FIN.WAIT.1
	ld	(CUR_STATE),a

	ld	hl,DATA_OUT_SIZE
	ld	de,NULL32
	call	COMP32
	jr	nz,TCP_CLOSE_PEND
	ld	hl,RETX_SIZE
	ld	de,NULL32
	call	COMP32
	jr	nz,TCP_CLOSE_PEND

	;No quedan datos pendientes (nuevos ni a retransmitir)

	call	INCLUDE_FIN
	xor	a
	call	INCLUDE_ACK
	call	SEND_DGRAMI
	jr	TCP_CLOSE_OK
TCP_CLOSE4:	;

	;--- Estado FIN-WAIT-1/2:
	;    Devuelve "Ok".

	cp	FIN.WAIT.1
	ld	b,a
	ld	a,0
	ret	z
	ld	a,b
	cp	FIN.WAIT.2
	ld	b,a
	ld	a,0
	ret	z
	ld	a,b

	;--- Si estado es CLOSE_WAIT:
	;    Si quedan datos pendientes, establece CLOSE_PENDING
	;    y termina.
	;    Si no, envia un segmento con FIN y pasa a LAST.ACK.

	cp	CLOSE.WAIT
	jr	nz,TCP_CLOSE5

	ld	a,LAST.ACK
	jr	TCP_CLOSE0
TCP_CLOSE5:	;

	;--- En cualquier otro estado: devuelve error "con. closing"

	ld	a,2
	scf
	ret

	;--- Terminacion sin error/con datos pendientes

TCP_CLOSE_PEND:	ld	a,#FF
	ld	(CLOSE_PENDING),a
TCP_CLOSE_OK:	ld	a,(CUR_CON)
	call	SAVE_CON
	xor	a
	ret


;----------------------
;---  Rutina ABORT  ---
;----------------------

	;--- ABORT: Aborta una conexion TCP
	;    Entrada: A = Numero de conexion
	;    Salida:  Cy=1 si error (la conexion no existe)
	;                A=1: La conexion no existe

TCP_ABORT:	push	af
	ld	a,2
	ld	(INT_LEVEL),a
	pop	af
	call	_TCP_ABORT
	push	af
	xor	a
	ld	(INT_LEVEL),a
	pop	af
	ret

_TCP_ABORT:	call	LOAD_CON_CHK
	ret	c

	call	DESTR_TCB_QUEUES	;Destruye listas

	ld	a,(CUR_STATE)	;Anyadido en 0.2
	cp	LISTEN
	jr	z,TCPAB_END
	cp	SYN.SENT
	jr	z,TCPAB_END
	cp	CLOSING
	jr	z,TCPAB_END
	cp	LAST.ACK
	jr	z,TCPAB_END
	cp	TIME.WAIT
	jr	z,TCPAB_END

	call	INCLUDE_RST	;Crea dgrama con RST
	call	SEND_DGRAMI	;y lo envia

TCPAB_END:	xor	a
	ld	(CUR_STATE),a
	ld	hl,NUM_CON
	dec	(hl)
	ld	a,(CUR_CON)
	call	SAVE_CON
	xor	a
	ret


	;--- TCP_DELETE: Borra la conexion que hay en TCB_CUR
	;                pero no envia RST

TCP_DELETE:	call	DESTR_TCB_QUEUES
	jr	TCPAB_END


;---------------------
;---  Rutina SEND  ---
;---------------------

	;--- SEND: Envia datos a una conexion TCP
	;    Entrada: A = Numero de conexion
	;             HL = Direccion de los datos en TPA
	;             BC = Tamanyo de los datos
	;             D = Flags:
	;                 bit 0 = push
	;                 bit 1 = urg
	;    Salida:  Cy=1 si error y A=codigo de error:
	;                1: La conexion no existe
	;                2: Esta LISTEN pero el socket remoto
	;                   no esta especificado
	;                3: La conexion se esta cerrando
	;                4: No hay memoria para encolar los datos

TCP_SEND:	push	af
	ld	a,1
	ld	(INT_LEVEL),a
	pop	af
	call	_TCP_SEND
	push	af
	xor	a
	ld	(INT_LEVEL),a
	pop	af
	ret

_TCP_SEND:	ld	(TCP_SEND_SIZE),bc
	ld	(TCP_SEND_ADD),hl
	ld	b,a
	ld	a,d
	ld	(TCP_SEND_FLAGS),a
	ld	a,b
	call	LOAD_CON_CHK
	ret	c

	;--- Conexion LISTEN:
	;    Si el socket remoto no esta especificado,
	;    termina con error 2.
	;    Si no, pasa la conexion a activa y llama a TCPOP_NEW2
	;    (seleciona ISS, establece SND.UNA y SND.NXT,
	;     envia SYN, y pasa a estado SYN.SENT),
	;     tras lo cual encola los datos para su envio cuando
	;     se pase a LISTEN.

	ld	a,(CUR_STATE)
	cp	LISTEN
	jr	nz,TCP_SEND2

	ld	ix,REMOTE_IP
	ld	a,(ix)
	or	(ix+1)
	or	(ix+2)
	or	(ix+3)
	or	(ix+4)
	or	(ix+5)

	ld	a,2
	scf
	ret	z

	call	TCPOP_NEW2	;Pasa a modo activo, etc
	jr	TCP_SEND_ENQ	;Encola datos
TCP_SEND2:	;

	;--- Modo SYN-SENT, SYN-RECEIVED, ESTABLISHED, CLOSE-WAIT:
	;    Encola los datos para su envio en el modo ESTABLISHED

	cp	SYN.SENT
	jr	z,TCP_SEND3
	cp	SYN.RECEIVED
	jr	z,TCP_SEND3
	cp	ESTABLISHED
	jr	z,TCP_SEND3
	cp	CLOSE.WAIT
	jr	nz,TCP_SEND4

TCP_SEND3:	jr	TCP_SEND_ENQ
	;ld      a,(CUR_CON)
	;call    SAVE_CON
	;xor     a
	;ret

	;--- En otro modo: devuelve error "connection closing"

TCP_SEND4:	ld	a,3	;No es necesario guardar el TCB
	scf		;                ;(no hemos modificado nada)
	ret

	;--- Subrutina para encolar los datos en DATA_OUT_QUEUE
	;    Se encola en elementos de tamanyo maximo EFF_SMSS
	;    Vuelve con Cy=1 y A=4 si no hay memoria suficiente

TCP_SEND_ENQ:	xor	a
	ld	(TCP_SEND_SEGS),a

	ld	hl,DATA_OUT_SIZE	;Si la cola de salida esta vacia,
	ld	de,NULL32	;establece su primer y ultimo numero
	call	COMP32	;de secuencia como SND.NXT
	jr	nz,TCP_SEND_ENQ!	;!!! Era ENQL en 0.1
	ld	hl,SND_NXT
	ld	de,DATA_OUT_FIRST
	copy32
	ld	hl,SND_NXT
	ld	bc,DATA_OUT_LAST
	call	DEC32

TCP_SEND_ENQ!:	ld	bc,(TCP_SEND_SIZE)	;No hace nada si no hay datos
	ld	a,b	;para enviar (tamanyo 0)
	or	c
	jr	z,TCP_SEND_END2
	ld	(TCP_SEND_PSIZE),bc
	ld	iy,(TCP_SEND_ADD)

	;Bucle de encolamiento de datos:
	;Encola los datos en elementos de tamanyo EFF_SMSS,
	;mas un ultimo elemento de menor tamanyo.
	;TCP_SEND_SIZE disminuye y TCP_SEND_ADD aumentan en cada
	;iteracion, ambas en incrementos de EFF_SMSS.

TCP_SEND_ENQL:	ld	hl,(TCP_SEND_PSIZE)
	ld	a,h
	or	l
	jr	z,TCP_SEND_END1
	ld	de,(EFF_SMSS)	;Ultimo elemento
	inc	de
	call	COMP16
	ld	a,#FF
	jr	nc,TCP_SEND_ENQ2

	dec	de	;Elemento de tamanyo EFF_SMSS
	xor	a
	sbc	hl,de
	ld	(TCP_SEND_PSIZE),hl
	ld	hl,(EFF_SMSS)

TCP_SEND_ENQ2:	ld	(TCP_SEND_ENDF),a
	ld	iy,(TCP_SEND_ADD)
	push	iy
	ld	b,h
	ld	c,l
	add	iy,bc
	ld	(TCP_SEND_ADD),iy
	pop	iy
	ld	b,3
	ld	a,(DATA_OUT_QUEUE)
	ld	ix,(DATA_OUT_QUEUE+1)
	nesmani	24
	jr	c,TCP_SEND_ERR

	ld	hl,TCP_SEND_SEGS
	inc	(hl)

	ld	a,(TCP_SEND_ENDF)
	or	a
	jr	z,TCP_SEND_ENQL

	;Todos los datos se han encolado sin error:
	;actualiza DATA_OUT_LAST y DATA_OUT_SIZE,
	;y si es necesario SEND_PUSHED y SEND_URG

TCP_SEND_END1:	ld	hl,DATA_OUT_LAST	;ultimo+=tamanyo
	ld	de,(TCP_SEND_SIZE)
	ld	bc,DATA_OUT_LAST
	call	ADD3216
	ld	hl,DATA_OUT_SIZE
	ld	de,(TCP_SEND_SIZE)
	ld	bc,DATA_OUT_SIZE
	call	ADD3216

TCP_SEND_END2:	ld	a,(TCP_SEND_FLAGS)
	or	a
	jr	z,TCP_SEND_END3
	bit	0,a
	jr	z,TCP_SEND_UP
	ld	hl,DATA_OUT_LAST
	ld	de,SEND_PUSH_LAST
	copy32
	push	af
	ld	a,(SEND_PUSH)
	or	a
	jr	nz,TCP_SEND_UP0
	ld	a,1
	ld	(SEND_PUSH),a
	ld	a,(OVERR_TOUT_V)
	ld	(OVERR_T),a
TCP_SEND_UP0:	pop	af
TCP_SEND_UP:	bit	1,a
	jr	z,TCP_SEND_END3
	ld	hl,DATA_OUT_LAST
	ld	de,SEND_URG_LAST
	copy32
	ld	a,#FF
	ld	(SEND_URG),a

	;Si al final resulta que no hay datos en la cola de salida,
	;se resetean SEND_PUSH y SEND_URG

TCP_SEND_END3:	ld	hl,DATA_OUT_SIZE
	ld	de,NULL32
	call	COMP32
	jr	nz,TCP_SEND_END4
	xor	a
	ld	(SEND_PUSH),a
	ld	(SEND_URG),a

	;Finalizacion

TCP_SEND_END4:	ld	a,(CUR_CON)
	call	SAVE_CON
	xor	a
	ret

	;--- Error al encolar los datos (memoria agotada):
	;    Borra los elementos que han podido ser encolados
	;    y termina con error 4

TCP_SEND_ERR:	ld	a,(TCP_SEND_SEGS)
	or	a
	jr	z,TCP_SEND_ERR2

	ld	b,a
TCP_SEND_ERRL:	push	bc
	ld	a,(DATA_OUT_QUEUE)
	ld	ix,(DATA_OUT_QUEUE+1)
	ld	b,2
	ld	h,2
	nesmani	29
	pop	bc
	djnz	TCP_SEND_ERRL

TCP_SEND_ERR2:	ld	a,(CUR_CON)
	call	SAVE_CON
	ld	a,4
	scf
	ret

	;--- Variables

TCP_SEND_SIZE:	dw	0	;Numero total de datos
TCP_SEND_PSIZE:	dw	0	;Datos pendientes de encolar
TCP_SEND_ADD:	dw	0
TCP_SEND_FLAGS:	dw	0
TCP_SEND_SEGS:	dw	0	;Numero de elementos insertados
TCP_SEND_ENDF:	db	0


;------------------------
;---  Rutina RECEIVE  ---
;------------------------

	;--- RECEIVE: Lee datos de una conexion TCP
	;    Entrada: A = Numero de conexion
	;             HL = Direccion de destino en TPA
	;             BC = Numero de datos a leer
	;             D = Flags:
	;                 bit 0 = 1: No leer datos si no hay
	;                            al menos BC disponibles
	;    Salida:  BC = Numero de datos realmente leidos
	;             Cy=1 si error y A=codigo de error:
	;                1: La conexion no existe
	;                2: No esta ESTABLISHED aun
	;                3: La conexion se esta cerrando
	;                   (si D=1 pero no hay datos suficientes
	;                    y estamos en estado CLOSING)
	;                4: No hay suficientes datos
	;                   (si D=1 pero no hay datos suficientes
	;                    y estamos en estado ESTABLISHED/FIN.WAIT)
	;                5: No hay ningun dato para recoger
	;              Cy=0 y A=Flags:
	;                bit 0 = 1: Entre los datos recogidos
	;                           hay datos urgentes
	;              HL=Numero de datos urgentes (si bit0 A=1)

TCP_RCV:	push	af
	ld	a,1
	ld	(INT_LEVEL),a
	pop	af
	call	_TCP_RCV
	push	af
	xor	a
	ld	(INT_LEVEL),a
	pop	af
	ret

_TCP_RCV:	ld	(TCP_RCV_SIZE),bc
	ld	(TCP_RCV_ADD),hl
	ld	b,a
	ld	a,d
	ld	(TCP_RCV_FLAGS),a
	ld	a,b
	call	LOAD_CON_CHK
	ld	bc,0
	ret	c

	;--- Conexion LISTEN, SYN-SENT, SYN-RECEIVED:
	;    Terminar con error 2

	ld	a,(CUR_STATE)
	cp	LISTEN
	jr	z,TCP_ERR_2
	cp	SYN.SENT
	jr	z,TCP_ERR_2
	cp	SYN.RECEIVED
	jr	nz,TCP_RCV2

TCP_ERR_2:	ld	a,2
	scf
	ld	bc,0
	ret

	;--- Conexion ESTABLISHED, FIN-WAIT-1/2, CLOSE-WAIT:
	;    Primero se comprueba si D=1 y no hay datos suficientes,
	;    para en ese caso devolver error 3 o 4

TCP_RCV2:	cp	ESTABLISHED
	jr	z,TCP_RCV2!
	cp	FIN.WAIT.1
	jr	z,TCP_RCV2!
	cp	FIN.WAIT.2
	jr	z,TCP_RCV2!
	cp	CLOSE.WAIT
	jr	z,TCP_RCV2!

	ld	a,3	;En otro estado: error "closing"
	scf
	ld	bc,0
	ret

TCP_RCV2!:	ld	a,(TCP_RCV_FLAGS)	;No lo comprueba si D=0
	bit	0,a
	jr	z,TCP_RCV3

	ld	a,(DATA_IN_SIZE+1)	;No lo comprueba si hay mas
	or	a	;de 64K de datos
	jr	nz,TCP_RCV3

	ld	a,(DATA_IN_SIZE+2)	;No da error si hay mas datos
	ld	h,a	;disponibles de los pedidos
	ld	a,(DATA_IN_SIZE+3)
	ld	l,a
	ld	de,(TCP_RCV_SIZE)
	call	COMP16
	jr	c,TCP_RCV3

	ld	a,(CUR_STATE)	;No hay datos suficientes:
	cp	CLOSE.WAIT	;Devuelve error "closing"
	ld	a,3	;o "no hay datos suficientes"
	ld	bc,0
	scf
	ret	z
	inc	a
	ret

	;--- Si no hay ningun dato para recoger, se devuelve error 5

TCP_RCV3:	ld	a,(DATA_IN_SIZE+1)
	ld	hl,(DATA_IN_SIZE+2)
	or	h
	or	l
	ld	a,5
	scf
	ld	bc,0
	ret	z

	;--- Estamos listos para leer los datos.
	;    Se calcula el segmento de destino segun la
	;    direccion TPA y se llama a EXTRACT_DATA.

	ld	hl,DATA_IN_FIRST
	ld	de,OLD_IN_FIRST
	copy32
	ld	a,(TCP_RCV_ADD+1)
	rlc	a
	rlc	a
	and	%11
	ld	ix,DATA_IN_QUEUE
	ld	iy,(TCP_RCV_ADD)
	ld	bc,(TCP_RCV_SIZE)
	ld	d,#FF	;Llamada indirecta
	call	EXTRACT_DATA
	ld	a,#FF	;El algoritmo SWS-avoidance se
	ld	(UPWND_PEND),a	;encargara de actualizar la ventana

	;--- Datos urgentes (si RCV_URG=#FF):
	;    se actua de forma distinta si hemos vaciado
	;    completamente la cola, o si no

	ld	a,(RCV_URG)
	or	a
	ld	hl,0
	jr	z,TCP_RCV_END

	ld	ix,DATA_IN_SIZE
	ld	a,(ix+1)
	or	(ix+2)
	or	(ix+3)
	jr	nz,TCP_RCV_URG2

	;Habia datos urgentes y hemos vaciado la cola:
	;Entonces el numero de datos urgentes es:
	;RCV_URG_LAST - OLD_IN_FIRST + 1

TCP_RCV_URG1:	xor	a
	ld	(RCV_URG),a

	ld	de,RCV_URG_LAST
	ld	hl,OLD_IN_FIRST
	ld	bc,TCP_RCV_USIZE
	call	SUB32
	ld	a,(TCP_RCV_USIZE+2)
	ld	h,a
	ld	a,(TCP_RCV_USIZE+3)
	ld	l,a
	inc	hl
	ld	a,1
	jr	TCP_RCV_END

	;Habia datos urgentes pero NO hemos vaciado la cola:
	;Entonces los hemos consumido todos
	;si RCV_URG_LAST < DATA_IN_FIRST;
	;en ese caso se devuelve
	;HL = BC - (DATA_IN_FIRST - RCV_URG_LAST) + 1
	;y se pone RCV_URG a 0.
	;Si no, se devuelve HL = TCP_RCV_SIZE.

TCP_RCV_URG2:	ld	hl,RCV_URG_LAST	;No estan todos consumidos?
	ld	de,DATA_IN_FIRST
	call	COMP_SEQ
	ld	hl,(TCP_RCV_SIZE)
	ld	a,1
	jr	c,TCP_RCV_END

	ld	de,DATA_IN_FIRST	;Se han consumido todos
	ld	hl,RCV_URG_LAST
	ld	bc,TCP_RCV_USIZE
	call	SUB32
	ld	a,(TCP_RCV_USIZE+2)
	ld	b,a
	ld	a,(TCP_RCV_USIZE+3)
	ld	c,a
	ld	hl,(EXTD_SIZE)	;(TCP_RCV_SIZE)
	or	a
	sbc	hl,bc
	inc	hl

	xor	a
	ld	(RCV_URG),a
	inc	a

	;--- Termina

TCP_RCV_END:	push	af,hl
	ld	a,(CUR_CON)
	call	SAVE_CON
	pop	hl,af
	ld	bc,(EXTD_SIZE)
	or	a
	ret

	;--- Variables

TCP_RCV_SIZE:	dw	0
TCP_RCV_ADD:	dw	0
TCP_RCV_FLAGS:	equ	TCP_SEND_FLAGS
TCP_RCV_USIZE:	ds	4
OLD_IN_FIRST:	ds	4	;DATA_IN_FIRST antes de la extraccion


;-----------------------
;---  Rutina STATUS  ---
;-----------------------

	;--- STATUS:  Devuelve el estado de una conexion TCP
	;    Entrada: A = Numero de conexion
	;    Salida:  Cy=1 si error y A=codigo de error:
	;                1: La conexion no existe
	;                   Entonces D=error prim., E=error sec.
	;                   (#FF ambos si A>=NUM_CON_MAX)
	;             A=Estado de la conexion
	;             B=Flags de datos pendientes:
	;               bit 0: Hay datos recibidos pendientes
	;                   1: Hay datos recibidos urgentes pend.
	;                   2: Hay datos enviados pendientes
	;                   3: Hay datos enviados urgentes pend.
	;                   4: Hay datos enviados pushed pendientes
	;                   5: Hay datos en la cola de ReTx
	;             HL=Puntero al TCB
	;             D=Ultimo codigo de error primario
	;             E=Ultimo codigo de error secundario
	;               (#FF ambos si A>=NUM_CON_MAX)

TCP_STATUS:	push	af
	ld	a,1
	ld	(INT_LEVEL),a
	pop	af
	call	_TCP_STATUS
	push	af
	xor	a
	ld	(INT_LEVEL),a
	pop	af
	ret

_TCP_STATUS:	cp	NUM_CON_MAX
	jr	c,TCP_STAT_OK1
	ld	de,#FFFF
	ld	a,1
	scf
	ret

TCP_STAT_OK1:	call	LOAD_CON_CHK
	jr	nc,TCP_STAT_OK2

	ld	a,(LAST_ERR_P)
	ld	d,a
	ld	a,(LAST_ERR_S)
	ld	e,a
	ld	a,1
	ret

TCP_STAT_OK2:	ld	ix,TCP_STAT_FLAGS
	ld	(ix),0

TCP_STAT_B0:	ld	hl,DATA_IN_SIZE	;Datos recibidos
	ld	de,NULL32
	call	COMP32
	jr	z,TCP_STAT_B2
	set	0,(ix)

TCP_STAT_B1:	ld	a,(RCV_URG)	;Datos recibidos urgentes
	or	a
	jr	z,TCP_STAT_B2
	set	1,(ix)

TCP_STAT_B2:	ld	hl,DATA_OUT_SIZE	;Datos enviados
	ld	de,NULL32
	call	COMP32
	jr	z,TCP_STAT_B5
	set	2,(ix)

TCP_STAT_B3:	ld	a,(SEND_URG)	;Datos enviados urgentes
	or	a
	jr	z,TCP_STAT_B4
	set	3,(ix)

TCP_STAT_B4:	ld	a,(SEND_PUSH)	;Datos enviados pushed
	or	a
	jr	z,TCP_STAT_B5
	set	4,(ix)

;TCP_STAT_B5:      ld      hl,OOO_IN_SIZE   ;Datos fuera de secuencia
;                  ld      de,NULL32
;                  call    COMP32
;                  jr      z,TCP_STAT_B6
;                  set     5,(ix)

TCP_STAT_B5:	ld	hl,RETX_SIZE	;Datos a retransmitir
	ld	de,NULL32
	call	COMP32
	jr	z,TCP_STAT_B6
	set	5,(ix)

TCP_STAT_B6:	;                        ;Bits 6 y 7 sin uso

	ld	a,(CUR_CON)	;Obtiene HL=Puntero al TCB
	add	4
	push	ix
	call	TCP_TABLES
	pop	ix

	ld	a,(LAST_ERR_P)
	ld	d,a
	ld	a,(LAST_ERR_S)
	ld	e,a

	ld	a,(CUR_STATE)	;Obtiene A=estado, B=banderas
	ld	b,(ix)
	or	a
	ret

TCP_STAT_FLAGS:	equ	TCP_SEND_FLAGS


;----------------------
;---  Rutina FLUSH  ---
;----------------------

	;--- FLUSH_OUT: Borra la cola de los datos aun no enviados
	;    Entrada: A = Numero de conexion
	;    Salida:  Cy=1 si error y A=codigo de error:
	;                1: La conexion no existe

TCP_FLUSH_OUT:	push	af
	ld	a,1
	ld	(INT_LEVEL),a
	pop	af
	call	_TCP_FLUSH_OUT
	push	af
	xor	a
	ld	(INT_LEVEL),a
	pop	af
	ret

_TCP_FLUSH_OUT:	call	LOAD_CON_CHK
	ret	c

TCP_FLOUT_LOOP:	ld	a,(DATA_OUT_QUEUE)	;Mientras queden elementos,
	ld	ix,(DATA_OUT_QUEUE+1)	;los borra
	ld	b,1
	ld	h,2
	nesmani	29
	jr	nc,TCP_FLOUT_LOOP

	ld	hl,NULL32	;Establece tamanyo de la cola en 0
	ld	de,DATA_OUT_SIZE
	copy32

	ld	a,(CUR_CON)
	call	SAVE_CON
	xor	a
	ret



;********************************************************
;***                                                  ***
;***  RUTINA DE ATENCION A LA INTERRUPCION DEL RELOJ  ***
;***                                                  ***
;********************************************************

TCP_INT:	;

	ld	hl,(#FC9E)
	ld	a,h
	or	l
	jr	nz,TCP_INT0
	ld	hl,(ISS_T)
	inc	hl
	ld	(ISS_T),hl
TCP_INT0:	;

	ld	a,(INT_LEVEL)
	cp	2
	ret	z

	ld	a,(LOADING_CON)
	or	a
	ret	nz

	ld	a,(CUR_CON)
	ld	(PREV_CON),a

;*** 1) Si es la primera interrupcion, crea la cola TCP_IN_QUEUE

	ld	a,(TCP_IN_QUEUE)
	or	a
	jr	nz,OK_FIRST_INT

	ld	a,6
	ld	ix,IP_CREATE_PROT
	call	CALL_IP
	ld	a,6
	ld	ix,IP_QUEUES
	call	CALL_IP
	ld	(TCP_IN_QUEUE),a
	ld	(TCP_IN_QUEUE+1),hl

OK_FIRST_INT:	;


;*** 2) Comprueba el estado de la capa de nivel 2 y lo compara
;       con el estado en la anterior interrupcion:
;    -- Ahora OFF y antes OFF: Termina
;    -- Ahora OFF y antes ON:  Aborta todas las conexiones (borra los TCB)
;                              Antes, olvida PROT_OUT_QUEUE para que
;                              ABORT no envie paquetes RST
;    -- Ahora ON  y antes OFF: Pregunta LOCAL_IP, MRU, MTU, PROT_OUT_QUEUE
;    -- Ahora ON  y antes ON:  No hace nada y salta a 3)

	ld	ix,LV2_CHK_TLU
	call	CALL_LV2
	ld	d,a
	ld	hl,LOWER_STATUS
	ld	e,(hl)
	ld	(hl),d	;D=Estado actual, E=Estado antiguo

	;--- OFF y OFF?

	ld	hl,0	;Termina
	call	COMP16
	ret	z

	;--- ON y OFF?

	ld	hl,#FF00
	call	COMP16
	jp	nz,OFF_Y_ON

	xor	a	;Pregunta IP local
	ld	ix,LV2_IPS
	call	CALL_LV2
	ld	a,h
	ld	(LOCAL_IP),a
	ld	a,l
	ld	(LOCAL_IP+1),a
	ld	a,d
	ld	(LOCAL_IP+2),a
	ld	a,e
	ld	(LOCAL_IP+3),a

	ld	ix,LV2_MXU	;Pregunta MRU y MTU
	call	CALL_LV2
	ld	(MTU),hl
	ld	(MRU),de

	ld	a,255	;Pregunta PROT_OUT_QUEUE
	ld	ix,IP_QUEUES
	call	CALL_IP
	ld	(PROT_OUT_QUEUE),a
	ld	(PROT_OUT_QUEUE+1),hl

	ld	a,-1
	ld	(LAST_USED_CON),a
	ld	hl,TCB_CON-TCB_SIZE
	ld	(LAST_USED_TCB),hl

	;Termina enseguida, ya que como antes estabamos OFF,
	;no es posible que haya ninguna conexion TCP abierta
	;ni ningun paquete entrante

	ret

	;--- OFF y ON?

OFF_Y_ON:	ld	hl,#00FF
	call	COMP16
	jr	nz,TCP_INT_3

	xor	a	;Olvida PROT_OUT_QUEUE
	ld	hl,0
	ld	(PROT_OUT_QUEUE),a
	ld	(PROT_OUT_QUEUE+1),hl

	ld	b,NUM_CON_MAX	;Aborta las conexiones, si hay
TCP_RES_LOP2:	push	bc
	ld	a,b
	dec	a
	call	TCP_ABORT
	pop	bc
	djnz	TCP_RES_LOP2
	xor	a
	ld	(NUM_CON),a	;Anyadido en 0.2

	ld	hl,CONS_DEF_VAL	;Ctes a su valor por defecto
	ld	de,CONS_START
	ld	bc,CONS_END-CONS_START
	ldir

	ret

TCP_INT_3:	;


;*** 3) Recorre todas las conexiones existentes y actualiza
;       todos los temporizadores activos, modificando las banderas
;       y variables necesarias, pero sin enviar ningun datagrama
;       (excepto si la conexion se aborta, en ese caso se envia un RST).
;       Los temporizadores a decrementar que ya son 0 se ignoran.

	ld	a,(NUM_CON)	;No hace nada
	or	a	;si no hay conexiones
	jp	z,TCP_INT_4

	ld	a,(INT_LEVEL)	;Si se esta ejecutando SEND o RCV,
	or	a	;hay que guardar el TCB antes
	jr	z,TCP_INT3_LPO2	;de cargar otro (nuevo en 0.2)
	ld	a,(CUR_CON)
	call	SAVE_CON
TCP_INT3_LPO2:	;

	;--- Realiza un bucle de 0 a NUM_CON_MAX-1,
	;    carga la conexion en TCB_CUR si existe
	;    (no esta CLOSED) y la trata

	ld	d,-1
	ld	hl,TCB_CON-TCB_SIZE
	ld	bc,TCB_SIZE
TCP_INT3_LOOP:	add	hl,bc	;Se salta las conexiones no
	inc	d	;existentes sin cargarlas
	ld	a,d
	cp	NUM_CON_MAX
	jp	nc,TCP_INT_4	;Era "jp z" en 0.1
	ld	a,(hl)
	or	a
	jr	z,TCP_INT3_LOOP

TCP_INT3_LPOK:	push	hl,bc,de

	ld	a,d
	call	LOAD_CON

	;--- Primero comprobamos si estamos en estado TIME-WAIT.
	;    Si es asi, decrementamos MSL_T, y si llega a cero,
	;    borramos la conexion. Si no llega a 0, nos saltamos
	;    el resto de los contadores.

	ld	a,(CUR_STATE)
	cp	TIME.WAIT
	jr	nz,TCP_INT3_NOTW

	ld	hl,(MSL_T)
	dec	hl
	ld	(MSL_T),hl
	ld	a,h
	or	l
	jp	z,TCP_INT3_TW0

	ld	a,(CUR_CON)
	call	SAVE_CON
	jp	TCP_INT3_ENDL

TCP_INT3_TW0:	ld	a,(CUR_CON)
	push	af
	call	TCP_DELETE
	pop	af
	call	SAVE_CON
	jp	TCP_INT3_ENDL
TCP_INT3_NOTW:			;

	;--- Detiene RTO_RUN si no queda nada para ReTx

	ld	a,(SYN_SENT_FLAG)
	or	a
	jr	nz,TCP_INT3_OKRTX

	ld	a,(FIN_SENT_FLAG)
	or	a
	jr	nz,TCP_INT3_OKRTX

	ld	hl,RETX_SIZE
	ld	de,NULL32
	call	COMP32
	jr	nz,TCP_INT3_OKRTX
	xor	a
	ld	(RTO_RUN),a
	call	INIT_UTOUT
	ld	hl,(RTO)	;Cambiado en 0.3
	ld	(RTO_T),hl
TCP_INT3_OKRTX:	;

	;--- Decrementa RTT_M_T si RTT_M_ON=0,
	;    y si llega a 0, se pone RTT_M_ON a 1

	ld	a,(RTT_M_ON)
	or	a
	jr	nz,OK_RTTMT

	ld	bc,(RTT_M_T)
	ld	a,b
	or	c
	jr	z,OK_RTTMT

	dec	bc
	ld	(RTT_M_T),bc

	ld	a,b
	or	c
	jr	nz,OK_RTTMT
	ld	a,1
	ld	(RTT_M_ON),a
OK_RTTMT:	;

	;--- Incrementa RTT_M_CUR si RTT_M_ON=2

	ld	a,(RTT_M_ON)
	cp	2
	jr	nz,OK_RTTMCUR
	ld	bc,(RTT_M_CUR)
	inc	bc
	ld	(RTT_M_CUR),bc
OK_RTTMCUR:	;

	;--- Se decrementa RTO_T si RTO_RUN=#FF
	;    (quedaran variables pendientes de actualizar
	;     y un paquete por retransmitir, esto se hara
	;     cuando la conexion tenga permiso para enviar)

	ld	a,(RTO_RUN)
	inc	a
	jr	nz,OK_RTOT

	ld	bc,(RTO_T)
	ld	a,b
	or	c
	jr	z,OK_RTOT

	dec	bc
	ld	(RTO_T),bc
OK_RTOT:	;

	;--- Incrementa RETX_EX_T si RETX_SIZE>0 o si SYN_SENT_FLAG<>0
	;    Si llega a RETX_EX_MAX o RETX_EX_SMAX, aborta la conexion

	ld	a,(SYN_SENT_FLAG)
	or	a
	jr	nz,OK_RETXSYN

	ld	hl,RETX_SIZE
	ld	de,NULL32
	call	COMP32
	jr	z,OK_RETXEX

OK_RETXSYN:	ld	hl,(RETX_EX_T)
	inc	hl
	ld	(RETX_EX_T),hl

	ld	a,(SYN_SENT_FLAG)
	or	a
	ld	de,(RETX_EX_MAX)
	jr	z,OK_RETXEX0
	ld	de,(RETX_EX_SMAX)

OK_RETXEX0:	call	COMP16
	jr	nc,OK_RETXEX
	ld	a,(CUR_CON)
	push	af
	call	TCP_ABORT
	pop	af
	call	SAVE_CON
	jp	TCP_INT3_ENDL
OK_RETXEX:	;

	;--- Se decrementa ACK_DELAY_T si ACK_DELAYED=#FF

	ld	a,(ACK_DELAYED)
	inc	a
	jr	nz,OK_ACKDELAYT

	ld	a,(ACK_DELAY_T)
	or	a
	jr	z,OK_ACKDELAYT

	dec	a
	ld	(ACK_DELAY_T),a
OK_ACKDELAYT:	;

	;--- Decrementa OVERR_T si SEND_PUSH=1,
	;    y si llega a 0, se pone SEND_PUSHED a 2

	ld	a,(SEND_PUSH)
	cp	1
	jr	nz,OK_OVERRT

	ld	a,(OVERR_T)
	or	a
	jr	z,OK_OVERRT

	dec	a
	ld	(OVERR_T),a

	jr	nz,OK_OVERRT
	ld	a,2
	ld	(SEND_PUSH),a
OK_OVERRT:	;

	;--- Decrementa USER_TOUT_T si hay datos a ReTx,
	;    y si llega a 0, aborta la conexion

	ld	hl,RETX_SIZE
	ld	de,NULL32
	call	COMP32
	jr	z,OK_USERTOUT

	ld	bc,(USER_TOUT_T)
	dec	bc
	ld	(USER_TOUT_T),bc
	ld	a,b
	or	c
	jr	nz,OK_USERTOUT

	ld	a,(CUR_CON)
	push	af
	call	TCP_ABORT
	pop	af
	call	SAVE_CON	;Anyadido en 0.2
	jp	TCP_INT3_ENDL
OK_USERTOUT:	;

	;--- Decrementa contador IDLE_T, y si llega a 0,
	;    establece CWND <- 2*SMSS

	ld	bc,(IDLE_T)
	ld	a,b
	or	c
	jr	z,OK_IDLET

	dec	bc
	ld	(IDLE_T),bc

	ld	a,b
	or	c
	jr	nz,OK_IDLET
	ld	hl,(SMSS2)
	call	SET_CWND
OK_IDLET:	;

	;--- Si SND_WND=0 y DATA_OUT_SIZE<>0,
	;    decrementa PROBE_ZW_T si no es 0
	;    (anyadido en 0.3)

	ld	a,(CUR_STATE)	;Solo en estados a partir de
	cp	4	;ESTABLISHED
	jr	c,OK_ZWT

	ld	hl,(SND_WND)	;Ventana 0?
	ld	a,h
	or	l
	jr	nz,OK_ZWT

	ld	hl,DATA_OUT_SIZE	;Hay datos nuevos a Tx?
	ld	de,NULL32
	call	COMP32
	jr	z,OK_ZWT

	ld	hl,(PROBE_ZW_T)
	ld	a,h
	or	l
	jr	z,OK_ZWT

	dec	hl
	ld	(PROBE_ZW_T),hl
OK_ZWT:	;

	;--- Comprueba si hay que actualizar la ventana:
	;    Si RCV_BUF-DATA_IN_SIZE-RCV_WND>=min(RCV_BUF/2,EFF.SMSS),
	;    se establece RCV.WND <- RCV.BUFF - DATA_IN_SIZE
	;    y se programa un ACK (algoritmo SWS).

	ld	a,(UPWND_PEND)
	or	a
	jr	z,OK_NOUPWND

	;jr      OK_UPWND         ;*** PRUEBAS: Actualiza siempre

	ld	hl,(RCV_BUF)	;Calcula el lado izquierdo
	ld	de,(DATA_IN_SIZE+2)
	swap_de
	or	a
	sbc	hl,de
	ld	de,(RCV_WND)
	or	a
	sbc	hl,de

	ld	de,(RCV_BUF2)
	call	COMP16
	push	af

	ld	de,(EFF_SMSS)
	call	COMP16

	;Si en alguna de las dos comparaciones hemos obtenido C,
	;hay que actualizar la ventana
	;( X >= min(Y,Z) si X>=Y o X>=Z)

	pop	bc
	jr	c,OK_UPWND
	bit	0,c
	jr	z,OK_NOUPWND

OK_UPWND:	ld	hl,(RCV_BUF)
	ld	de,(DATA_IN_SIZE+2)
	swap_de
	or	a
	sbc	hl,de
	ld	(RCV_WND),hl
	call	SCHEDULE_ACK	;Anyadido en 0.2
	xor	a
	ld	(UPWND_PEND),a
OK_NOUPWND:	;

	;--- Cierre del bucle

	pop	af
	push	af
	call	SAVE_CON
TCP_INT3_ENDL:	pop	de,bc,hl
	jp	TCP_INT3_LOOP


;*** 4) Examina UN paquete de entrada, se carga la conexion a la que va
;       dirigido, y se realiza el procesado necesario (encolamiento de los
;       datos, actualizacion de variables).
;       NO se envian paquetes, excepto si:
;       - Se ha de enviar un RST o un SYN
;       - Llega un ACK de un SYN enviado, y hay que pasar
;         de SYN-SENT a SYN-RECEIVED (se envia un ACK enseguida)
;       - Llega una ReTx de un FIN (se envia un ACK enseguida)

TCP_INT_4:	;ld      a,(NUM_CON)      ;Se vuelve a comprobar, por si el
	;or      a                ;paso 3) ha abortado todas las
	;ret     z                ;conexiones

	;--- Si INT_LEVEL=1, la interrupcion llego cuando
	;    se estaba ejecutando un SEND o un RECEIVE del usuario.
	;    En ese caso hay que terminar aqui, pero antes
	;    hay que reponer la conexion que habia en CUR_TCB
	;    antes de la ejecucion de la interrupcion.

	ld	a,(INT_LEVEL)
	cp	1
	jr	nz,TCP_INT_4OK

	ld	a,(CUR_CON)
	ld	b,a
	ld	a,(PREV_CON)
	cp	b
	call	nz,LOAD_CON
	ret

	;--- Obtiene un paquete de entrada a BUFER_IN-20,
	;    y lo ajusta de forma que la parte TCP empieze
	;    en BUFER_IN (es decir, ignora las opciones IP)

TCP_INT_4OK:	ld	a,(#8002)
	ld	l,a
	ld	iy,BUFER_IN-21
	ld	b,1
	ld	h,3
	ld	a,(TCP_IN_QUEUE)
	ld	ix,(TCP_IN_QUEUE+1)
	nesman	29
	jp	c,TCP_INT_5	;No hay paquetes?

	;ld      hl,RCVED         ;*** PRUEBA
	;inc     (hl)

	;*** PRUEBAS: Si no es un paquete TCP, lo ignora.
	;    La version definitiva debe tratar paquetes ICMP.

	ld	a,(BUFER_IN-20+9)
	cp	6
	jp	nz,TCP_INT_5

	;Si el paquete tiene opciones IP, se las salta
	;(mueve hacia atras la parte TCP para que empiece
	; en TCP_IN_BUF)

	ld	a,(BUFER_IN-20)
	cp	#45
	jr	z,TCPINT4_OK1

	and	#0F
	sub	5
	ld	l,a
	ld	h,0
	add	hl,hl
	add	hl,hl
	push	hl
	pop	bc	;BC = Tamanyo sobrante

	ld	hl,BUFER_IN+20
	add	hl,bc	;HL = Origen a mover
	ld	de,BUFER_IN	;DE = Destino
	ld	a,(BUFER_IN-20+2)
	ld	b,a	;BC = Tamanyo a mover
	ld	a,(BUFER_IN-20+3)	;(en realidad se mueve un poco
	ld	c,a	;mas tamanyo del necesario
	ldir		;                ;pero no importa)
TCPINT4_OK1:	;


	;--- Se comprueba el checksum TCP, si es invalido
	;    se descarta el paquete

	ld	a,(BUFER_IN-21)
	ld	c,a
	ld	b,0	;BC = Tamanyo cabecera IP
	ld	a,(BUFER_IN-20+2)
	ld	h,a
	ld	a,(BUFER_IN-20+3)	;HL = Tamanyo IP total
	ld	l,a
	or	a
	sbc	hl,bc
	ld	(SEG_TLEN),hl	;Calcula tamanyo TCP total

	if	IGNORE_CHK=0

	push	hl	;Calcula checksum TCP
	pop	bc
	ld	hl,BUFER_IN-20+12
	ld	de,LOCAL_IP
	ld	ix,BUFER_IN
	call	TCP_CHKSUM
	ld	a,d
	or	e
	jp	nz,TCP_INT_5

	endif

	ld	a,(BUFER_IN+12)	;De paso calcula SEG_HLEN y SEG_DLEN
	and	%11110000
	srl	a
	srl	a
	ld	(SEG_HLEN),a
	ld	c,a
	ld	b,0
	ld	hl,(SEG_TLEN)
	or	a
	sbc	hl,bc
	ld	(SEG_DLEN),hl

	ld	hl,BUFER_IN+4	;Establece tambien SEG_SEQ,
	ld	de,SEG_SEQ	;SEG_ACK, SEG_WND y SEG_UP
	copy32
	ld	hl,BUFER_IN+8
	ld	de,SEG_ACK
	copy32
	ld	a,(BUFER_IN+15)
	ld	(SEG_WND),a
	ld	a,(BUFER_IN+14)
	ld	(SEG_WND+1),a
	ld	a,(BUFER_IN+19)
	ld	(SEG_UP),a
	ld	a,(BUFER_IN+18)
	ld	(SEG_UP+1),a


	;--- Ahora se examinan todas las conexiones en busca
	;    del destinatario (misma IP remota y mismos puertos)

	ld	a,(NUM_CON)
	or	a
	jr	z,TCP_INT4_FAIL2

	xor	a
	ld	(INT4_STEP),a

TCP_INT4_PREVL:	ld	d,-1
	ld	hl,TCB_CON-TCB_SIZE
	ld	bc,TCB_SIZE
TCP_INT4_LOOP:	inc	d
	add	hl,bc
	ld	a,d
	cp	NUM_CON_MAX
	jr	nc,TCP_INT4_FAIL
	ld	a,(hl)
	or	a
	jr	z,TCP_INT4_LOOP

	;Conexion en uso: se carga y se comprueban los datos

	push	de,hl,bc
	ld	a,d
	call	LOAD_CON

	;INT_STEP=0: Se comprueba si coinciden la IP remota
	;y los puertos

	ld	a,(INT4_STEP)
	or	a
	jr	nz,INT4_STEP_1

INT4_STEP_0:	ld	hl,BUFER_IN-20+12	;Coincide la IP remota?
	ld	de,REMOTE_IP
	call	COMP32
	jr	nz,TCP_INT4_ENDL

	ld	hl,BUFER_IN
	ld	de,REMOTE_PORT
	call	COMP32
	jr	z,TCP_INT4_MATCH

	;Conexion no coincide: se pasa a la siguiente

TCP_INT4_ENDL:	pop	bc,hl,de
	jr	TCP_INT4_LOOP

	;INT_STEP=1: Se comprueba si la conexion esta LISTEN
	;y el socket remoto es 0, en ese caso se comprueba
	;si coincide el puerto local; si no, se trata
	;como conexion no coincidente.

INT4_STEP_1:	ld	a,(CUR_STATE)
	cp	LISTEN
	jr	nz,TCP_INT4_ENDL

	ld	hl,REMOTE_IP
	ld	de,NULL32
	call	COMP32
	jr	nz,TCP_INT4_ENDL

	ld	hl,(REMOTE_PORT)
	ld	a,h
	or	l
	jr	nz,TCP_INT4_ENDL

	ld	hl,(BUFER_IN+2)
	ld	de,(LOCAL_PORT)
	call	COMP16
	jr	nz,TCP_INT4_ENDL

	jr	TCP_INT4_MATCH

	;No hay destinatario: se envia un mensaje RST
	;siempre que el paquete no contenga a su vez un RST
	;(PRUEBAS: la version completa debe enviar tambien
	; un paquete ICMP "port unreachable")
	;o bien se pasa a INT4_STEP=1 y se repite el bucle

TCP_INT4_FAIL:	ld	a,(INT4_STEP)
	or	a
	jr	nz,TCP_INT4_FAIL2
	inc	a
	ld	(INT4_STEP),a
	jr	TCP_INT4_PREVL

TCP_INT4_FAIL2:	ld	hl,BUFER_IN+13
	_bit	RST,(hl)
	call	z,REPLY_RST
	jp	TCP_INT_5

	;Conexion coincide: se sigue el proceso normal

TCP_INT4_MATCH:	pop	bc,hl,de

	;* Ya tenemos la conexion de destino del paquete
	;   en TCB_CUR, el paquete en BUFER_IN, y las
	;   variables SEG_x establecidas.


;--------------------------------
;--  Proceso en estado LISTEN  --
;--------------------------------

	ld	a,(CUR_STATE)
	cp	LISTEN
	jr	nz,TCP_INT4_SYNS

	;Si el segmento tiene RST, terminar

	ld	a,(BUFER_IN+13)
	_bit	RST,a
	jp	nz,TCP_INT_5

	;Si el segmento tiene ACK,
	;enviar <SEQ=SEG.ACK><CTL=RST> y terminar

	_bit	ACK,a
	push	af
	call	nz,REPLY_RST
	pop	af
	jp	nz,TCP_INT_5

	;Si el segmento no tiene SYN, terminar

	_bit	SYN,a
	jp	z,TCP_INT_5

	;* El segmento tiene SYN: inicializar la conexion

	;Establece RCV.NXT a SEG_SEQ+1 y IRS a SEG.SEQ

	ld	hl,SEG_SEQ
	ld	bc,RCV_NXT
	call	INC32

	ld	hl,SEG_SEQ
	ld	de,IRS
	copy32

	;Rellena los datos del socket remoto

	ld	hl,BUFER_IN-20+12
	ld	de,REMOTE_IP
	copy32
	ld	hl,(BUFER_IN)
	ld	(REMOTE_PORT),hl

	;Selecciona ISS, envia <SEQ=ISS><ACK=RCV.NXT><CTL=SYN,ACK>,
	;establece SND.NXT<-ISS+1, SNA.UNA<-ISS, y pasa a SYN-RECEIVED

	call	GEN_ISS

	ld	hl,ISS
	ld	de,SND_UNA
	copy32
	ld	hl,ISS
	ld	bc,SND_NXT
	call	INC32
	call	INIT_UTOUT

	call	INCLUDE_SYN
	xor	a
	call	INCLUDE_ACK
	call	SEND_DGRAM	;Envia dgrama sin datos
	call	SET_RTO

	ld	a,SYN.RECEIVED
	ld	(CUR_STATE),a

	;Busca la opcion SMSS en el datagrama

	call	SET_SMSS

	;Termina

	jp	TCP_INT4_URG	;Por si el dgrama tiene datos


;----------------------------------
;--  Proceso en estado SYN-SENT  --
;----------------------------------

TCP_INT4_SYNS:	cp	SYN.SENT
	jp	nz,TCP_INT4_EST

	;Si ACK=1, se comprueba si SEG.ACK<=ISS o si SEG.ACK>SND.NXT
	;(o lo que es lo mismo: si ISS<SEG.ACK<=SND.NXT -> OK)
	;en ese caso se envia <SEQ=SEG.ACK><CTL=RST> y se termina.
	;(si se da el caso pero RST esta activado, se termina
	; sin enviar el RST)

	ld	a,(BUFER_IN+13)	;Hay ACK?
	_bit	ACK,a
	jr	z,TCP_INT4_SYNS4

	ld	hl,ISS	;Version 0.2:
	ld	bc,TEMP_SEQ	;Si SEG_ACK=ISS+1, OK
	call	INC32	;En caso contrario error
	ld	hl,SEG_ACK
	ld	de,TEMP_SEQ
	call	COMP_SEQ
	jr	z,TCP_INT4_SYNS3

	;ld      hl,SEG_ACK       ;Si SEG_ACK=ISS: Error
	;ld      de,ISS
	;call    COMP_SEQ
	;jr      z,TCP_INT4_SYNS2

	;ld      hl,ISS           ;Si ISS<=SEG.ACK=<SND.NXT:
	;ld      de,SND_NXT       ;OK, si no, error
	;ld      bc,SEG_ACK
	;call    RANGE32
	;jr      c,TCP_INT4_SYNS3

TCP_INT4_SYNS2:	ld	a,(BUFER_IN+13)	;Error: enviar RST si el propio
	_bit	RST,a	;paquete entrante no tenia RST,
	call	z,REPLY_RST	;y terminar
	jp	TCP_INT_5

TCP_INT4_SYNS3:	ld	a,(BUFER_IN+13)	;ACK valido y RST=1:
	_bit	RST,a	;Abortar conexion
	jr	z,TCP_INT4_SYNS5
	ld	a,(CUR_CON)
	call	TCP_DELETE
	jp	TCP_INT_5

	;Si RST=1 y ACK=0, ignora segmento

TCP_INT4_SYNS4:	ld	a,(BUFER_IN+13)
	_bit	RST,a
	jp	nz,TCP_INT_5

	;Si SYN=0, ignora segmento y termina

TCP_INT4_SYNS5:			;ld      a,(BUFER_IN+13)
	_bit	SYN,a
	jp	z,TCP_INT_5

	;SYN=1: Establece RCV.NXT<-SEG.SEQ+1, IRS<-SEG.SEQ,
	;si ACK=1 establece SND_UNA<-SEG_ACK

	call	SET_SMSS	;Tambien busca la opcion SMSS

	ld	hl,SEG_SEQ
	ld	bc,RCV_NXT
	call	INC32

	ld	hl,SEG_SEQ
	ld	de,IRS
	copy32

	ld	a,(BUFER_IN+13)
	_bit	ACK,a
	jr	z,TCP_INT4_SYNS5
	ld	hl,SEG_ACK
	ld	de,SND_UNA
	copy32

	;* Aqui se deberian sacar de RETX_QUEUE los datos
	;  ACKeados, pero NestorTCP nunca envia datos
	;  en estado SYN-SENT.

TCP_INT4_S!NS5:			;

	;Si SND_UNA<=ISS:
	;Pasar a SYN-RECEIVED,
	;Enviar <SEQ=ISS><AC=RCV.NXT><CTL=SYN,ACK>,
	;Encolar datos del segmento en DATA_IN_QUEUE.

	ld	hl,SND_UNA
	ld	de,ISS
	call	COMP_SEQ
	jr	z,TCP_INT4_SYNS5_
	jr	c,TCP_INT4_SYNS6
TCP_INT4_SYNS5_:			;

	ld	a,SYN.RECEIVED
	ld	(CUR_STATE),a

	call	INCLUDE_SYN	;Se envia el ACK inmediatamente
	xor	a	;y se actualizan las variables
	call	INCLUDE_ACK	;relacionadas con el ACK manualmente
	ld	hl,ISS
	ld	de,BUFER_OUT+4
	copy32
	call	SEND_DGRAM
	call	SET_RTO
	xor	a
	ld	(ACK_DELAYED),a
	ld	a,(ACK_DELAY_MAX)
	ld	(ACK_DELAY_T),a
	ld	hl,0
	ld	(ACK_RCV_NUM),hl

	jp	TCP_INT4_URG

	;Si SND_UNA>ISS:
	;Pasar a ESTABLISHED
	;SND.WND<-SEG.WND
	;SND.WL1<-SEG.SEQ
	;SND.WL2<-SEG.ACK
	;Enviar <SEQ=SND.NXT><ACK=RCV.NXT><CTL=ACK>
	;Pasar a procesar el texto si hay

TCP_INT4_SYNS6:	ld	a,ESTABLISHED
	ld	(CUR_STATE),a
	xor	a
	ld	(SYN_SENT_FLAG),a
	ld	hl,(RTO)	;Anyadido en 0.3
	ld	(RTT_M_T),hl

	call	SET_WNDWL	;Establece SND_WND/WL1/WL2

	xor	a
	call	INCLUDE_ACK
	call	SEND_DGRAM

	xor	a
	ld	(ACK_DELAYED),a
	ld	a,(ACK_DELAY_MAX)
	ld	(ACK_DELAY_T),a
	ld	hl,0
	ld	(ACK_RCV_NUM),hl

	;call    SCHEDULE_ACK     ;Envia el ACK inmediatamente
	;xor     a
	;ld      (ACK_DELAY_T),a

	jp	TCP_INT4_URG


;--------------------------------
;--  Proceso en otros estados  --
;--------------------------------

TCP_INT4_EST:	ld	hl,(RTO)
	ld	(IDLE_T),hl

	;--- Primero se ha de comprobar si el segmento es
	;    aceptable (el test depende del tamanyo del segmento
	;    y de la ventana de recepcion)

	;SEG_DLEN=0 y RCV_WND=0?
	;Entonces OK si SEG.SEQ=RCV.NXT

TCP_INT4_TST1:	ld	hl,(SEG_DLEN)
	ld	de,(RCV_WND)	;Era SEG_WND en 0.1
	ld	a,h
	or	l
	or	d
	or	e
	jr	nz,TCP_INT4_TST2

	ld	hl,SEG_SEQ
	ld	de,RCV_NXT	;Era SEG_WND en 0.1
	call	COMP_SEQ
	jr	nz,TCP_INT4_TSTE
	jr	TCP_INT4_TSTOK

	;Aqui sabemos que o SEG_DLEN>0 o RCV_WND>0

	;SEG_DLEN=0 y RCV_WND>0?
	;Entonces OK si RCV_NXT<=SEG.SEQ<RCV_NXT+RCV_WND
	;SEG_DLEN>0 y RCV_WND=0?
	;Entonces nunca OK

TCP_INT4_TST2:	ld	hl,RCV_NXT	;Calcula
	ld	de,(RCV_WND)	;TEMP_SEQ3=RCV_NXT+RCV_WND-1
	ld	bc,TEMP_SEQ3
	call	ADD3216
	ld	hl,TEMP_SEQ3
	ld	bc,TEMP_SEQ3
	call	DEC32

	ld	hl,(SEG_DLEN)	;SEG_DLEN=0?
	ld	a,h	;Entonces seguro que RCV_WND>0
	or	l
	jr	nz,TCP_INT4_TST2!

	ld	hl,RCV_NXT	;Aqui sabemos quew SEG_DLEN=0
	ld	de,TEMP_SEQ3	;y RCV_WND>0: realizamos la
	ld	bc,SEG_SEQ	;comprobacion de si OK
	call	RANGE32

	jr	nc,TCP_INT4_TSTE
	jr	TCP_INT4_TSTOK

TCP_INT4_TST2!:	ld	hl,(RCV_WND)	;Aqui sabemos que SEG_DLEN>0.
	ld	a,h	;Si RCV_WND=0, error.
	or	l	;Si no, pasamos a la siguiente
	jr	z,TCP_INT4_TSTE	;comprobacion.

TCP_INT4_TST3:	;Aqui sabemos que SEG_DLEN>0 y RCV_WND>0

	;SEG_DLEN>0 y RCV_WND>0?
	;Entonces OK si:
	;RCV_NXT<=SEG_SEQ<RCV_NXT+RCV_WND, o
	;RCV_NXT<=SEG_SEQ+SEG_LEN-1<RCV_NXT+RCV_WND
	;(ya tenemos RCV_NXT+RCV_WND-1 en TEMP_SEQ)

	ld	hl,RCV_NXT	;Primera condicion
	ld	de,TEMP_SEQ3
	ld	bc,SEG_SEQ
	call	RANGE32
	jr	c,TCP_INT4_TSTOK

	ld	hl,SEG_SEQ	;Calcula TEMP_SEQ2=SEG_SEQ+SEG_LEN-1
	ld	de,(SEG_DLEN)
	ld	bc,TEMP_SEQ4
	call	ADD3216
	ld	hl,TEMP_SEQ4
	ld	bc,TEMP_SEQ4
	call	DEC32

	ld	hl,RCV_NXT	;Segunda condicion
	ld	de,TEMP_SEQ3
	ld	bc,TEMP_SEQ4
	call	RANGE32
	jr	c,TCP_INT4_TSTOK

	;No se ha pasado el test:
	;Envia un ACK inmediatamente e ignora el resto del segmento

TCP_INT4_TSTE:	call	SCHEDULE_ACK
	xor	a
	ld	(ACK_DELAY_T),a
	jp	TCP_INT_5

	;* Aqui ya sabemos que los datos estan en la ventana
	;  (mas adelante se comprobara si estan fuera de secuencia)

TCP_INT4_TSTOK:			;


	;--- El bit RST o SYN esta activado:
	;    En estado SYN-RECEIVED y si la apertura era pasiva,
	;    se vuelve al estado LISTEN y se borra RETX_QUEUE.
	;    En cualquier otro caso se aborta la conexion.

	ld	a,(BUFER_IN+13)
	_bit	RST,a
	jr	nz,TCP_INT4_RST
	_bit	SYN,a
	jr	z,TCP_INT4_NORST

TCP_INT4_RST:	ld	a,(CUR_STATE)
	cp	SYN.RECEIVED
	jr	nz,TCP_INT4_AB

	ld	a,(PASSIVE_OPEN)
	or	a
	jr	nz,TCP_INT4_AB

	ld	a,LISTEN
	ld	(CUR_STATE),a

	call	SET_SMSS

TCP_INT4_RLOOP:	ld	a,(RETX_QUEUE)
	ld	ix,(RETX_QUEUE+1)
	ld	b,1
	ld	h,2
	nesman	29
	jr	nc,TCP_INT4_RLOOP
	ld	hl,NULL32
	ld	de,RETX_SIZE
	copy32

	jp	TCP_INT_5

TCP_INT4_AB:	;ld      a,(CUR_CON)      ;Conexion activa o no SYN-RECEIVED:
	call	TCP_DELETE	;abortar
	jp	TCP_INT_5
TCP_INT4_NORST:			;


	;--- Si el bit ACK no esta activado,
	;    se ignora el segmento.

	;ld      a,(BUFER_IN+13)
	_bit	ACK,a
	jp	z,TCP_INT_5


	;--- En estado SYN-RECEIVED:
	;    Si SND_UNA<=SEG_ACK<=SND.NXT, pasar a ESTABLISHED,
	;    llamar a SET_WNDWL y continuar.
	;    Si no, enviar <SEQ=SEG_ACK><CTL=RST> y terminar.

	ld	a,(CUR_STATE)
	cp	SYN.RECEIVED
	jr	nz,TCP_INT4_EST3

	ld	hl,SND_UNA
	ld	de,SND_NXT
	ld	bc,SEG_ACK
	call	RANGE32
	jr	c,TCP_INT4_EST2

	call	INCLUDE_RST
	ld	hl,SEG_ACK
	ld	de,BUFER_OUT+4
	copy32
	call	SEND_DGRAM
	jp	TCP_INT_5

TCP_INT4_EST2:	ld	a,ESTABLISHED
	ld	(CUR_STATE),a
	xor	a
	ld	(SYN_SENT_FLAG),a
	ld	(RTO_RUN),a	;Anyadido en 0.2
	call	SET_WNDWL
	ld	hl,(RTO)	;Anyadido en 0.3
	ld	(RTT_M_T),hl
TCP_INT4_EST3:			;


	;--- Procesado del ACK recibido para el estado
	;    LAST-ACK: Si el FIN es ACKeado, borrar conexion
	;    y terminar (SEG_ACK>FIN_SENT_SEQ)

	ld	a,(CUR_STATE)
	cp	LAST.ACK
	jr	nz,TCP_INT4_NOLA

	ld	hl,SEG_ACK
	ld	de,FIN_SENT_SEQ
	call	COMP_SEQ
	jp	z,TCP_INT_5
	jp	nc,TCP_INT_5

	;ld      a,(CUR_CON)
	call	TCP_DELETE
	jp	TCP_INT_5


	;--- Procesado del ACK recibido para el estado
	;    TIME-WAIT: Solo puede llegar una ReTx del FIN;
	;    ACKearlo y reiniciar MSL_T.

TCP_INT4_NOLA:	ld	a,(CUR_STATE)
	cp	TIME.WAIT
	jr	nz,TCP_INT4_NOTW

	ld	a,(BUFER_IN+13)
	_bit	FIN,a
	jp	z,TCP_INT_5

	ld	a,1
	call	INCLUDE_ACK
	ld	hl,BUFER_OUT+8
	ld	bc,BUFER_OUT+8
	call	INC32
	call	SEND_DGRAM
	ld	hl,MSL_T_MAX
	ld	(MSL_T),hl
	jp	TCP_INT_5
TCP_INT4_NOTW:			;


	;* Procesado del ACK en los estados
	;  ESTABLISHED, FIN-WAIT-1/2, CLOSE-WAIT, CLOSING

	;--- Si RTT_M_SEQ<SEG_ACK y RTT_M_ON=2 se hace:
	;    RTT <- RTT_M_CUR
	;    RTT_M_ON <- 0
	;    RTT_M_T <- RTT
	;    y se actualizan SRTT, RTTVAR, RTO

	ld	a,(RTT_M_ON)
	cp	2
	jp	nz,TCP_INT4_ACK3

	ld	hl,RTT_M_SEQ
	ld	de,SEG_ACK
	call	COMP_SEQ
	jp	c,TCP_INT4_ACK3

	ld	hl,(RTT)	;Para comprobar despues
	ld	a,h	;si RTT era 0
	or	l
	push	af

	ld	hl,(RTT_M_CUR)	;Establece RTT=RTT_M_CUR
	ld	(RTT),hl
	xor	a
	ld	(RTT_M_ON),a	;Establece RTT_M_ON=0
	;ld      hl,(RTT)
	ld	(RTT_M_T),hl	;Establece RTT_M_T=RTT

	pop	af
	jr	nz,TCP_INT4_ACK1

	;Primera medida: establece
	;SRTT <- RTT
	;RTTVAR <- RTT/2
	;RTO <- 3*RTT

	ld	hl,(RTT)
	ld	(SRTT),hl

	ld	hl,(RTT)
	srl	h
	rr	l
	ld	(RTTVAR),hl

	ld	hl,(RTT)	;3*RTT
	push	hl
	pop	bc
	add	hl,hl
	add	hl,bc
	ld	(RTO),hl

	jr	TCP_INT4_ACK2

	;Siguientes medidas: establece
	;RTTVAR <- (3*RTTVAR + |SRTT-RTT|)/4
	;SRTT <- (7*SRTT + RTT)/8
	;RTO <- SRTT + 4*RTTVAR

TCP_INT4_ACK1:	ld	hl,(RTTVAR)	;3*RTTVAR
	push	hl
	pop	bc
	add	hl,hl
	add	hl,bc
	push	hl

	ld	hl,(SRTT)	;|SRTT-RTT|
	ld	bc,(RTT)
	or	a
	sbc	hl,bc
	jr	nc,SUB_OK1
	push	hl
	pop	bc
	or	a
	ld	hl,0
	sbc	hl,bc
SUB_OK1:	;

	pop	bc	;3*RTTVAR + |SRTT-RTT|
	add	hl,bc

	srl	h	;(3*RTTVAR+|SRTT-RTT|)/4
	rr	l
	srl	h
	rr	l

	ld	(RTTVAR),hl

	ld	hl,(SRTT)	;7*SRTT
	push	hl
	pop	bc
	add	hl,hl
	add	hl,hl
	add	hl,bc
	add	hl,bc
	add	hl,bc

	ld	bc,(RTT)	;7*SRTT + RTT
	add	hl,bc

	srl	h	;(7*SRTT+RTT)/8
	rr	l
	srl	h
	rr	l
	srl	h
	rr	l

	ld	(SRTT),hl

	push	hl	;SRTT + 4*RTTVAR
	pop	bc
	ld	hl,(RTTVAR)
	add	hl,hl
	add	hl,hl
	add	hl,bc
	ld	(RTO),hl

TCP_INT4_ACK2:			;

	;Si RTO<1 seg: RTO <- 1 seg

	ld	hl,(RTO)
	ld	de,50
	call	COMP16
	jr	c,OKRTOSIZE1

	ld	hl,50
	ld	(RTO),hl
	jr	TCP_INT4_ACK3
OKRTOSIZE1:	;

	;Si RTO>RTO_MAX: RTO<-RTO_MAX

	ld	de,(RTO_MAX)
	call	COMP16
	jr	nc,TCP_INT4_ACK3
	ld	(RTO),de

TCP_INT4_ACK3:			;


	;--- Si el ACK es duplicado (SEG_ACK=LAST_RCVD_ACK),
	;    se reenvia el ACK inmediatamente,
	;    se incrementa DUP_ACKS (hasta 4); si llega a 4,
	;    se hace:
	;    FLIGHT_SIZE <- SND.NXT-SND.UNA
	;    SSTHRESH <- MAX (FLIGHT_SIZE/2, 2*SMSS)
	;    CWND <- SSTHRESH + 3*SMSS
	;    Si DUP_ACKS es 4, se hace CWND<-CWND+SMSS.
	;    Si el ACK no es duplicado, DUP_ACKS <- 0
	;    Y CWND <- SSTHRESH

	;jp      TCP_INT4_ACK9    ;*** PRUEBAS: desactiva fast retr.
	ld	hl,RETX_SIZE
	ld	de,NULL32
	call	COMP32
	jp	z,TCP_INT4_ACK9

	ld	hl,SEG_ACK	;ACK duplicado (igual al anterior)?
	ld	de,LAST_RCVD_ACK
	call	COMP32
	push	af
	ld	hl,SEG_ACK
	ld	de,LAST_RCVD_ACK
	copy32
	pop	af
	jr	z,TCP_INT4_ACK4

	xor	a	;No: DUP_ACKS=0, y si estabamos en
	ld	(DUP_ACKS),a	;Fast Recovery, CWND=SSTHRESH
	ld	a,(FAST_RECOV_FLAG)
	or	a
	jr	z,TCP_INT4_ACK9
	xor	a
	ld	(FAST_RECOV_FLAG),a
	ld	hl,(SSTHRESH)
	call	SET_CWND
	jr	TCP_INT4_ACK9

TCP_INT4_ACK4:	;call    SCHEDULE_ACK     ;Programa un ACK inmediato
	;xor     a                ;Quitado en 0.3
	;ld      (ACK_DELAY_T),a

	ld	a,(DUP_ACKS)
	inc	a
	cp	4
	jr	z,TCP_INT4_ACK8
	ld	(DUP_ACKS),a
	cp	3
	jr	nz,TCP_INT4_ACK9

	;Tercer ACK duplicado

	ld	a,#FF
	ld	(FAST_RECOV_FLAG),a

	ld	hl,0	;Retransmite inmediatamente
	ld	(RTO_T),hl
	ld	hl,(LAST_USED_RTO)	;Divide por 2, ya que
	srl	h	;al ser detectado como 0,
	rr	l	;sera multiplicado por 2;
	ld	(LAST_USED_RTO),hl	;asi se queda igual

	call	SET_SSTHRESH	;Establece SSTHRESH

TCP_INT4_ACK6:	ld	de,(SSTHRESH)	;Establece CWND a SSTHRES+3*SMSS
	ld	hl,(SMSS2)
	ld	bc,(SMSS)
	add	hl,bc
	add	hl,de
	call	SET_CWND

TCP_INT4_ACK7:			;ld      (DUP_ACKS),a
	jr	TCP_INT4_ACK9

	;ACK duplicado a partir del cuarto:
	;CWND <- CWND+SMSS

TCP_INT4_ACK8:	ld	hl,(CWND)
	ld	de,(SMSS)
	add	hl,de
	call	SET_CWND

	;Primer a tercer ACK duplicado: no hace nada mas

TCP_INT4_ACK9:			;


	;--- Si SEG.ACK > SND.NXT, se envia un ACK y se ignora
	;    el resto del segmento (datos fuera de secuencia).

	ld	hl,SEG_ACK
	ld	de,SND_NXT
	call	COMP_SEQ
	jr	z,TCP_INT4_ACK10
	jr	nc,TCP_INT4_ACK10

	call	SCHEDULE_ACK
	xor	a	;ACK inmediato
	ld	(ACK_DELAY_T),a
	jp	TCP_INT_5
TCP_INT4_ACK10:			;


	;--- En otro caso (ACK valido):
	;    SND_UNA <- SEG_ACK
	;    RTO_T <- RTO
	;    Eliminar SEG_ACK-SND_UNA-1 bytes de RETX_QUEUE
	;    Si: SND.WL1<SEG.SEQ, o
	;        SND.WL1=SEG.SEQ y SND.WL2<=SEG.ACK,
	;        hacer CALL SET_WNDWL.
	;    Si no quedan datos a ReTx, hacer RTO_RUN<-0.
	;    Suma a SS_CA_NEWACK el numero de bytes ACKeados,
	;    y si llega a CWND, se hace:
	;    SS_CA_NEWACK<-0, CWND<-CWND+SMSS

	ld	hl,(RTO)
	ld	(LAST_USED_RTO),hl
	ld	(RTO_T),hl

	ld	de,SEG_ACK
	ld	hl,SND_UNA
	ld	bc,TEMP_SEQ	;TEMP_SEQ = Datos a retirar
	call	SUB32	;de RETX_QUEUE

	;ld      hl,TEMP_SEQ      ;Anyadido en 0.2
	;ld      bc,TEMP_SEQ
	;call    DEC32

	ld	hl,SEG_ACK	;Anyadido en 0.2
	ld	de,SND_UNA
	copy32

	ld	a,(TEMP_SEQ+2)	;BC = SEG_ACK - SND_UNA
	ld	b,a
	ld	a,(TEMP_SEQ+3)
	ld	c,a

	ld	a,(CONG_AVO)	;En Slow Start, siempre se
	or	a	;incrementa CWND cuando llegan
	jr	z,TCP_INT4_SS	;datos nuevos

	ld	hl,(SS_CA_NEWACK)	;Congestion Avoidance:
	add	hl,bc	;actualiza SS_CA_NEWACK...
	ld	(SS_CA_NEWACK),hl
	ld	de,(CWND)
	call	COMP16
	jr	nc,TCP_INT4_ACK10_

	ld	hl,0	;...y si es necesario, tambien CWND
	ld	(SS_CA_NEWACK),hl	;A en 0.2
TCP_INT4_SS:	ld	hl,(CWND)
	ld	bc,(SMSS)
	add	hl,bc	;Faltaba esto!! (anyadido en 0.3)
	call	SET_CWND
TCP_INT4_ACK10_:			;

	ld	a,(TEMP_SEQ+2)	;Extrae los datos de RETX_QUEUE
	ld	b,a
	ld	a,(TEMP_SEQ+3)
	ld	c,a
	ld	ix,RETX_QUEUE
	xor	a
	ld	iy,0
	ld	d,0
	call	EXTRACT_DATA
	ld	hl,0	;Temporizador de demasiadas
	ld	(RETX_EX_T),hl	;ReTx a 0

	ld	hl,RETX_SIZE	;Detiene el temporizador RTO
	ld	de,NULL32	;si no quedan datos a ReTx
	call	COMP32
	jr	nz,TCP_INT4_ACK11_
	xor	a
	ld	(RTO_RUN),a
TCP_INT4_ACK11_:	ld	hl,0	;Si quedan datos a ReTx, se envian
	ld	(RTO_T),hl	;enseguida

	ld	hl,SND_WL1	;SND_WL1<SEG_SEQ?
	ld	de,SEG_SEQ
	call	COMP_SEQ
	jr	z,TCP_INT4_ACK12_
	jr	c,TCP_INT4_ACK12
	call	SET_WNDWL
	jr	TCP_INT4_ACK12

TCP_INT4_ACK12_:			;jr      nz,TCP_INT4_ACK12;   ;SND_WL1=SEG_SEQ?
	ld	hl,SND_WL2
	ld	de,SEG_ACK
	call	COMP_SEQ	;SND_WL2<=SEG.ACK?
	jr	z,TCP_INT4_ACK11
	jr	c,TCP_INT4_ACK12
TCP_INT4_ACK11:	call	SET_WNDWL
TCP_INT4_ACK12:			;


	;--- Estado FIN-WAIT1
	;    Si el FIN enviado es ACKeado, pasa a FIN-WAIT-2
	;    (si SEG_ACK>FIN_SENT_SEQ)

	ld	a,(CUR_STATE)
	cp	FIN.WAIT.1
	jr	nz,TCP_INT4_ACK13

	ld	hl,SEG_ACK
	ld	de,FIN_SENT_SEQ
	call	COMP_SEQ
	jr	z,TCP_INT4_ACK13
	jr	nc,TCP_INT4_ACK13

	ld	a,FIN.WAIT.2
	ld	(CUR_STATE),a
	xor	a
	ld	(SYN_SENT_FLAG),a
	ld	(FIN_SENT_FLAG),a
TCP_INT4_ACK13:			;


	;--- Estado CLOSING:
	;    Si el FIN enviado es ACKeado, pasa a TIME-WAIT
	;    (si SEG_ACK>FIN_SENT_SEQ),
	;    si no, ignorar el segmento

	ld	a,(CUR_STATE)
	cp	CLOSING
	jr	nz,TCP_INT4_ACK14

	ld	hl,SEG_ACK
	ld	de,FIN_SENT_SEQ
	call	COMP_SEQ
	jp	z,TCP_INT_5
	jp	nc,TCP_INT_5

	ld	a,TIME.WAIT
	ld	(CUR_STATE),a
	ld	hl,(MSL_T_CUR)
	ld	(MSL_T),hl
	xor	a
	ld	(SYN_SENT_FLAG),a
	ld	(FIN_SENT_FLAG),a
TCP_INT4_ACK14:			;


	;* El proceso del ACK ya ha terminado.

	;--- Proceso de URG (solo en ESTABLISHED, FIN-WAIT-x):
	;    Se establece RCV_URG <- #FF,
	;    RCV_URG_LAST <- SEG_SEQ + SEG_UP

TCP_INT4_URG:	ld	a,(CUR_STATE)
	cp	ESTABLISHED
	jr	z,TCP_INT4_URG2
	cp	FIN.WAIT.1
	jr	z,TCP_INT4_URG2
	cp	FIN.WAIT.2
	jp	nz,TCP_INT4_FIN

TCP_INT4_URG2:	ld	hl,BUFER_IN+13
	_bit	URG,(hl)
	jr	z,TCP_INT4_URG3

	ld	a,#FF
	ld	(RCV_URG),a
	ld	hl,SEG_SEQ
	ld	de,(SEG_UP)
	ld	bc,RCV_URG_LAST
	call	ADD3216
TCP_INT4_URG3:			;


	;--- Proceso de los datos del segmento
	;    (solo en ESTABLISHED, FIN-WAIT-x):
	;    Si los datos estan fuera de secuencia
	;    (SEG_SEQ>RCV_NXT), se envia un ACK enseguida
	;    y se ignoran los datos.
	;    Si no, se encolan los datos en DATA_IN_QUEUE
	;    y se programa un ACK normal.

	;(en 0.1, cuando no habia datos no se comprobaba el
	; numero de secuencia)

	ld	hl,SEG_SEQ	;SEG_SEQ>RCV_NXT?
	ld	de,RCV_NXT
	call	COMP_SEQ
	jp	z,TCP_INT4_TXT1
	jp	nc,TCP_INT4_TXT1

	call	SCHEDULE_ACK	;Datos fuera de secuencia?
	xor	a
	ld	(ACK_DELAY_T),a
	jp	TCP_INT_5

TCP_INT4_TXT1:	ld	hl,(SEG_DLEN)	;No hace nada mas si no hay datos
	ld	a,h
	or	l
	jp	z,TCP_INT4_NOTXT

	;Calcula la cantidad de datos repetidos del segmento
	;y la direccion de inicio de los datos nuevos:
	;TEMP_SEQ = RCV_NXT - SEG_SEQ (num. datos repetidos)
	;SEG_DLEN = SEG_DLEN - TEMP_SEQ (num. datos nuevos)
	;TEMP_SEQ2 = BUFER_IN+20+TEMP_SEQ (inicio datos nuevos)

	ld	hl,BUFER_IN+20
	ld	(TEMP_SEQ2),hl

	ld	de,RCV_NXT
	ld	hl,SEG_SEQ
	ld	bc,TEMP_SEQ
	call	SUB32

	ld	a,(TEMP_SEQ+2)
	ld	b,a
	ld	a,(TEMP_SEQ+3)
	ld	c,a
	or	b
	jr	z,TCP_INT4_TXT2
	;ld      (TEMP_SEQ),bc    ;Datos repetidos

	ld	hl,(SEG_DLEN)
	or	a
	sbc	hl,bc
	ld	(SEG_DLEN),hl	;Datos nuevos

	ld	hl,BUFER_IN+20
	add	hl,bc
	ld	(TEMP_SEQ2),hl	;Dir. datos nuevos

	;Inserta datos nuevos al final de DATA_IN_QUEUE, y
	;actualiza DATA_IN_LAST y DATA_IN_SIZE
	;Tambien actualiza ACK_RCV_NUM (+=SEG_DLEN)
	;Si el puerto local es 9 y ECHO_SERVER=#FF,
	;en vez de encolar en DATA_IN encola en DATA_OUT

;TCP_INT4_TXT2:    ld      iy,(TEMP_SEQ2)   ;!!!PRUEBA: KKFLAG=#FF si se
;                  ld      a,(iy)           ;recibe dato "1" y 0 si se
;                  cp      "0"              ;recibe dato "0"
;                  jr      z,KK0
;                  cp      "1"
;                  jr      z,KK1
;                  jr      NOKK
;KK0:              xor     a
;                  ld      (KKFLAG),a
;                  ld      hl,1
;                  ld      (SND_WND),hl
;                  jr      NOKK
;KK1:              ld      a,#FF
;                  ld      (KKFLAG),a
;                  ld      hl,0
;                  ld      (SND_WND),hl
;NOKK:             xor     a

TCP_INT4_TXT2:	xor	a
	ld	(ECHO_NOW),a
	ld	a,(ECHO_SERVER)
	or	a
	jr	z,TCP_INT4_TXT2_

	ld	hl,(LOCAL_PORT)
	ld	de,ECHO_PORT
	call	COMP16
	jr	nz,TCP_INT4_TXT2_

	ld	a,#FF	;Intercambia IN y OUT
	ld	(ECHO_NOW),a	;para que los datos se encolen
	call	SWAP_IO	;en OUT

TCP_INT4_TXT2_:	ld	a,(#8002)
	ld	b,a
	ld	iy,(TEMP_SEQ2)
	ld	hl,(SEG_DLEN)
	set	7,h
	set	6,h
	ld	a,(DATA_IN_QUEUE)
	ld	ix,(DATA_IN_QUEUE+1)
	nesman	28	;Inserta elemento
	jp	c,TCP_INT_5
	;ld      hl,#BEFE
	;inc     (hl)
	;ld      a,(CUR_CON)
	;ld      (#BEFF),a

	ld	hl,DATA_IN_SIZE	;Si DATA_IN_QUEUE estaba vacia,
	ld	de,NULL32	;establece DATA_IN_FIRST=SEG_SEQ
	call	COMP32	;y DATA_IN_LAST=SEG_SEQ-1
	jr	nz,TCP_INT_TXT3
	ld	hl,SEG_SEQ
	ld	de,DATA_IN_FIRST
	copy32
	ld	hl,DATA_IN_FIRST
	ld	bc,DATA_IN_LAST
	call	DEC32
TCP_INT_TXT3:	;

	ld	hl,DATA_IN_LAST
	ld	de,(SEG_DLEN)
	ld	bc,DATA_IN_LAST
	call	ADD3216

	ld	hl,DATA_IN_SIZE
	ld	de,(SEG_DLEN)
	ld	bc,DATA_IN_SIZE
	call	ADD3216

	ld	hl,(SEG_DLEN)
	ld	bc,(ACK_RCV_NUM)
	add	hl,bc
	ld	(ACK_RCV_NUM),hl

	call	SCHEDULE_ACK

	;Actualiza RCV_NXT sumandole SEG_DLEN

	ld	hl,RCV_NXT
	ld	de,(SEG_DLEN)
	ld	bc,RCV_NXT
	call	ADD3216

	;Restaura IN y OUT si se intercambiaron,
	;y establece SEND_PUSH en ese caso

	ld	a,(ECHO_NOW)
	or	a
	jr	z,TCP_INT4_TXT4

	call	SWAP_IO

	ld	hl,(RCV_BUF)	;Actualiza ventana de recep.
	ld	de,(DATA_IN_SIZE+2)
	swap_de
	or	a
	sbc	hl,de
	ld	(RCV_WND),hl
	ld	a,#FF	;Anyadido en 0.2
	ld	(UPWND_PEND),a

	ld	a,(SEND_PUSH)
	or	a
	jr	nz,TCP_INT4_TXT4
	ld	a,1
	ld	(SEND_PUSH),a
	ld	a,(OVERR_TOUT_V)
	ld	(OVERR_T),a
	ld	hl,DATA_OUT_LAST
	ld	de,SEND_PUSH_LAST
	copy32
TCP_INT4_TXT4:	;

	;Actualiza ventana de recepcion

	;ld      hl,(RCV_BUF)
	;ld      de,(DATA_IN_SIZE+2)
	;swap_de
	ld	hl,(RCV_WND)
	ld	de,(SEG_DLEN)	;Cambiado en 0.2
	or	a
	sbc	hl,de
	ld	(RCV_WND),hl
TCP_INT4_NOTXT:	;

	;--- Proceso del bit FIN

TCP_INT4_FIN:	ld	a,(BUFER_IN+13)
	_bit	FIN,a
	jp	z,TCP_INT_5

	;En estado LISTEN o SYN-SENT, lo ignora

	ld	a,(CUR_STATE)
	cp	LISTEN
	jp	z,TCP_INT_5
	cp	SYN.SENT
	jp	z,TCP_INT_5

	;Actualiza RCV_NXT (lo incrementa) y programa un ACK.
	;Establece todos los datos restantes como PUSHed.

	ld	hl,RCV_NXT
	ld	bc,RCV_NXT
	call	INC32

	call	SCHEDULE_ACK
	xor	a
	ld	(ACK_DELAY_T),a

	ld	a,#FF
	ld	(SEND_PUSH),a
	ld	hl,DATA_OUT_LAST
	ld	de,SEND_PUSH_LAST
	copy32

	;En estado ESTABLISHED, SYN-RECEIVED: Pasa a estado
	;CLOSE-WAIT

	ld	a,(CUR_STATE)
	cp	ESTABLISHED
	jr	z,TCP_INT4_FIN1
	cp	SYN.RECEIVED
	jp	nz,TCP_INT4_FIN2

TCP_INT4_FIN1:	ld	a,CLOSE.WAIT
	ld	(CUR_STATE),a
	jp	TCP_INT_5
TCP_INT4_FIN2:			;

	;En estado FIN-WAIT-1: Si el FIN enviado ha sido ACKeado
	;(si SND_NXT>FIN_SENT_SEQ), pasa a TIME-WAIT y reinicia
	;MSL_T. Si no, pasa a CLOSING.

	cp	FIN.WAIT.1
	jr	nz,TCP_INT4_FIN4

	ld	hl,SND_NXT
	ld	de,FIN_SENT_SEQ
	call	COMP_SEQ
	jr	z,TCP_INT4_FIN3_
	jr	c,TCP_INT4_FIN3

TCP_INT4_FIN3_:	ld	a,CLOSING
	ld	(CUR_STATE),a
	jp	TCP_INT_5

TCP_INT4_FIN3:	ld	a,TIME.WAIT
	ld	(CUR_STATE),a
	ld	hl,MSL_T_MAX
	ld	(MSL_T),hl
	jp	TCP_INT_5
TCP_INT4_FIN4:			;

	;En estado FIN-WAIT-2: pasa a TIME-WAIT, reinicia
	;contador MSL, envia un ACK.

	cp	FIN.WAIT.2
	jr	z,TCP_INT4_FIN3

	;En estado TIME-WAIT: reinicia contador MSL.

TCP_INT4_FIN5:	cp	TIME.WAIT
	jr	z,TCP_INT4_FIN3



;*** 5) Examina UNA sola conexion en cada interrupcion para
;       enviar una retransmision, datos nuevos y/o un ACK si es necesario.
;       El numero de conexion examinada es el siguiente al usado en la
;       anterior interrupcion (tras NUM_CON_MAX-1 se vuelve a 0)

TCP_INT_5:	ld	a,(CUR_CON)	;Guarda los cambios efectuados
	call	SAVE_CON	;en el paso 4)

	ld	a,(NUM_CON)	;Se vuelve a comprobar, por si el
	or	a	;paso 4) ha abortado todas las
	ret	z	;conexiones

	ld	a,(CUR_STATE)
	or	a
	jr	z,TCP_INT5_DO

	ld	a,(NUM_CON)
	cp	1
	jr	z,TCP_INT5_SLCT3

	;--- Carga la conexion adecuada en TCB_CUR
	;    (la ultima usada+1, de NUM_CON_MAX-1 salta a 0)

TCP_INT5_DO:	ld	a,(LAST_USED_CON)
	ld	hl,(LAST_USED_TCB)
	ld	bc,TCB_SIZE
TCP_INT5_SLCT:	add	hl,bc	;Se salta las conexiones no
	inc	a	;existentes sin cargarlas
	cp	NUM_CON_MAX
	jr	c,TCP_INT5_SLCT2
	ld	hl,TCB_CON-TCB_SIZE
	ld	a,-1
	jr	TCP_INT5_SLCT	;NUM_CON_MAX-1 -> 0
TCP_INT5_SLCT2:	ld	d,a
	ld	a,(hl)
	or	a
	ld	a,d
	jr	z,TCP_INT5_SLCT

	ld	(LAST_USED_CON),a
	ld	(LAST_USED_TCB),hl
	call	LOAD_CON
TCP_INT5_SLCT3:			;

	;--- Primero comprueba si hay que retransmitir datos,
	;    es decir si RTO_RUN=#FF y RTO_T=0.
	;    En ese caso se hace:
	;    RTO <- RTO*2 (hasta RTO_MAX)
	;    RTO_T <- RTO
	;    y se envia el primer elemento de RETX_QUEUE
	;    (si se habia enviado un SYN, solo se reenvia el SYN).
	;    Ademas se pone SSTRHESH a max(FlightSize/2,2*SMSS)
	;    y CWND a SMSS.

	ld	a,(RTO_RUN)
	inc	a
	jp	nz,TCP_INT5_NORTX2
	ld	hl,(RTO_T)
	ld	a,h
	or	l
	jp	nz,TCP_INT5_NORTX2

	ld	hl,(LAST_USED_RTO)
	add	hl,hl
	ld	de,(RTO_MAX)
	call	COMP16
	jr	nc,TCP_INT5_RTX1
	ex	de,hl
TCP_INT5_RTX1:	ld	(LAST_USED_RTO),hl

	ld	(RTO_T),hl

	;Se ha enviado SYN?

	;call    CREATE_SEG      ;Suprimido en 0.2
	ld	a,(SYN_SENT_FLAG)
	or	a
	jr	z,TCP_INT5_RTX2
	call	INCLUDE_SYN
	jp	TCP_INT5_NOAK	;OKAK en 0.1
TCP_INT5_RTX2:	;

	;No se ha enviado SYN?
	;Entonces se extrae el paquete a BUFER_OUT+20
	;(se supone que no hay opciones TCP)

	ld	a,(#8002)
	ld	l,a
	ld	b,1
	ld	h,1
	ld	iy,BUFER_OUT+20
	ld	a,(RETX_QUEUE)
	ld	ix,(RETX_QUEUE+1)
	nesman	29
	;or      a
	jr	nc,TCP_INT5_RETX3	;Arreglado en 0.3

	ld	de,RETX_SIZE	;Anyadido en 0.2
	ld	hl,NULL32
	copy32
	ld	a,(FIN_SENT_FLAG)
	or	a
	jp	nz,TCP_INT5_NORTX
	xor	a
	ld	(RTO_RUN),a
	jp	TCP_INT5_NORTX2

TCP_INT5_RETX3:	push	bc
	call	SET_SSTHRESH	;Anyadido en 0.3
	ld	hl,(SMSS)
	call	SET_CWND
	pop	bc

	;dec     bc
	;dec     bc
	;dec     bc
	push	bc	;Arreglado en 0.3
	xor	a
	call	INCLUDE_ACK	;Anyadido en 0.2
	ld	hl,RETX_FIRST
	ld	de,BUFER_OUT+4	;Anyadido en 0.2
	copy32
	pop	bc
	ld	(SEG_PEND_DSIZE),bc
	ld	hl,20
	add	hl,bc
	ld	(SEG_PEND_TSIZE),hl
	;ld      hl,#BEFB
	;inc     (hl)
	;ld      a,(CUR_CON)
	;ld      (#BEFC),a

	;ld      hl,BUFER_OUT+20  ;Ajusta PSH, URG, SEG.UP
	;add     hl,bc
	;ld      a,(hl)
	;inc     hl
	;ld      e,(hl)
	;inc     hl
	;ld      d,(hl)
	;ld      (BUFER_OUT+18),de
	;ld      hl,BUFER_OUT+13
	;or      (hl)
	;ld      (hl),a

	;Comprueba si se ha de incluir bit PUSH,
	;es decir si:
	;SEG_SEQ<=LAST_RETX_PUSH
	;(nuevo en 0.2)

	ld	hl,LAST_RETX_PUSH
	ld	de,BUFER_OUT+4
	call	COMP_SEQ
	call	c,INCLUDE_PSH

	;Comprueba si se ha de incluir bit URG,
	;es decir si:
	;SEG_SEQ<=LAST_RETX_URG
	;(nuevo en 0.2)

	ld	hl,LAST_RETX_URG
	ld	de,BUFER_OUT+4
	call	COMP_SEQ
	jr	nc,NO_RETX_URG

	ld	bc,TEMP_SEQ	;Calcula long. de datos urgentes:
	ld	de,LAST_RETX_URG	;LAST_RETX_URG-SEQ
	ld	hl,BUFER_OUT+4	;(en realidad long.-1)
	call	SUB32

	ld	hl,(TEMP_SEQ)
	ld	a,h
	or	l
	jr	nz,NO_RETX_URG

	ld	de,(TEMP_SEQ+2)	;Si hay mas datos urgentes
	swap_de		;                ;para ReTx que la longitud
	ld	hl,(SEG_PEND_DSIZE)	;del segmento,
	dec	hl
	call	COMP16	;se pone solo la longitud
	jr	c,OK_URG_SIZE	;del segmento en URG
	ld	de,(SEG_PEND_DSIZE)
	dec	de
OK_URG_SIZE:	push	de
	pop	bc
	call	INCLUDE_URG
NO_RETX_URG:	;

	;Si RTT_M_ON=2, se comprueba si:
	;SEG.SEQ<=RTT_M_SEQ<SEG.SEQ+SEG.LEN
	;En ese caso se pone RTT_M_ON a 1

	ld	a,(RTT_M_ON)
	cp	2
	jr	nz,TCP_INT5_OKRTX	;Cambiado en 0.3

	ld	hl,BUFER_OUT+4	;Calcula
	ld	de,(SEG_PEND_DSIZE)	;TEMP_SEQ = SEG_SEQ+SEG_DLEN-1
	ld	bc,TEMP_SEQ
	call	ADD3216
	ld	hl,TEMP_SEQ
	ld	bc,TEMP_SEQ
	call	DEC32

	ld	hl,BUFER_OUT+4
	ld	de,TEMP_SEQ
	ld	bc,RTT_M_SEQ
	call	RANGE32
	jr	nc,TCP_INT5_NORTX

	ld	a,1
	ld	(RTT_M_ON),a

TCP_INT5_OKRTX:	;jp      TCP_INT5_OKAK    ;NONEW en 0.1

	;Se ha enviado FIN?

TCP_INT5_NORTX:	ld	a,(FIN_SENT_FLAG)	;Movido aqui en 0.3
	or	a
	call	nz,INCLUDE_FIN

	;Hay paquete a enviar despues de todo?

	ld	a,(SEG_PENDING)
	or	a
	jr	z,TCP_INT5_NORTX2

	;El paquete esta listo para enviar.
	;Si RTT_M_ON=2, comprueba si el numero de secuencia
	;medido (RTT_M_SEQ) esta incluido en el segmento
	;(si SEG_SEQ<=RTT_M_SEQ<SEQ_SEG+SEG_LEN);
	;en ese caso ponemos RTT_M_ON=1, ya que los segmentos
	;retransmitidos no pueden usarse para medir el RTT.

	ld	a,(RTT_M_ON)	;OK si RTT_M_ON<>2
	cp	2
	jp	nz,TCP_INT5_OKAK

	ld	hl,BUFER_OUT+4	;OK si SEG_SEQ<RTT_M_SEQ
	ld	de,RTT_M_SEQ
	call	COMP_SEQ
	jp	nc,TCP_INT5_OKAK

	ld	hl,BUFER_OUT+4	;TEMP_SEQ=SEG_SEQ+SEG_SIZE
	ld	de,(SEG_PEND_DSIZE)
	ld	bc,TEMP_SEQ
	call	ADD3216

	ld	hl,RTT_M_SEQ	;OK si NO SEG_SEQ+SEG_DLEN<RTT_M_SEQ
	ld	de,TEMP_SEQ
	call	COMP_SEQ
	jp	c,TCP_INT5_OKAK

	ld	a,1
	ld	(RTT_M_ON),a
	jp	TCP_INT5_OKAK
TCP_INT5_NORTX2:	;

	;--- Si no hay que retransmitir datos, comprueba si
	;    se pueden enviar datos nuevos.
	;    Se calcula USABLE_W <- SND.UNA - SND_NXT + min(SND.WND,CWND)
	;    (si SND.WND=0, USABLE_W<-0)
	;    y se envian datos en alguno de estos casos:
	;    - min(TCP_OUT_SIZE, USABLE_W) >= EFF.SMSS
	;    - SEND_PUSH=2
	;    - SND.NXT = SND.UNA & SEND_PUSH=1 & TCP_OUT_SIZE <=
	;      <= USABLE_W
	;    - SND.NXT = SND.UNA & min(TCP_OUT_SIZE, USABLE_W) >=
	;      >= 1/2*MAX_SNDW
	;    Tras el envio, si SND_NXT>LAST_PUSH, se hace SEND_PUSH<-0

	ld	hl,DATA_OUT_SIZE	;Realmente hay datos?
	ld	de,NULL32
	call	COMP32
	jp	z,TCP_INT5_NONEW

	;Se calcula USABLE_W

	ld	hl,(SND_WND)	;La ventana es cero?
	ld	a,h
	or	l
	;jr      nz,TCP_INT5_WNO0
	jp	z,TCP_INT5_NONEW	;Anyadido en 0.3

	;ld      hl,NUM1BUF
	;ld      de,USABLE_W
	;copy32
	;jr      TCP_INT5_W0

TCP_INT5_WNO0:	ld	hl,NULL32
	ld	de,USABLE_W
	copy32

	ld	hl,(SND_WND)	;DE=min(CWND,SND_WND)
	ld	de,(CWND)
	call	COMP16
	jr	c,MINWND
	ex	de,hl
MINWND:	;

	ld	hl,SND_UNA	;Calcula X=SND_UNA+SND_WND
	;ld      de,(SND_WND)
	ld	bc,USABLE_W
	call	ADD3216

	ld	de,USABLE_W	;Calcula Y=X-SND_NXT
	ld	hl,SND_NXT
	ld	bc,USABLE_W
	call	SUB32

TCP_INT5_W0:	ld	a,(USABLE_W)	;Si la ventana usable resultante
	bit	7,a	;es negativa, la tomamos como cero
	jp	nz,TCP_INT5_NONEW

	ld	a,(USABLE_W+2)	;Pasa USABLE_W a little endian
	ld	h,a
	ld	a,(USABLE_W+3)
	ld	l,a
	ld	(USABLE_W),hl

	ld	a,h	;Anyadido en 0.3
	or	l
	jp	z,TCP_INT5_NONEW

	;Se comprueba si min(DATA_OUT_SIZE,USABLE_W) >= EFF_SMSS
	;es decir, si DATA_OUT_SIZE>=EFF_SMSS y USABLE_W>=EFF_SMSS,
	;en ese caso se deberia saltar a TCP_INT5_NEW.
	;Implementacion alternativa:
	;si DATA_OUT_SIZE<EFF_SMSS o USABLE_W<EFF_SMSS,
	;NO se salta a TCP_INT5_NEW.
	;Ya que: A and B = not((not A) or (not B))

	ld	hl,(USABLE_W)
	ld	de,(EFF_SMSS)
	call	COMP16
	jr	nc,TCP_INT5_N1

	ld	a,(DATA_OUT_SIZE+1)	;Si >64K, seguro que es
	or	a	;   ;>EFF_SMSS; entonces
	jr	nz,TCP_INT5_NEW	;   ;salta a NEW.

	;ld      de,(EFF_SMSS)
	ld	a,(DATA_OUT_SIZE+2)
	ld	h,a
	ld	a,(DATA_OUT_SIZE+3)
	ld	l,a
	call	COMP16
	jr	c,TCP_INT5_NEW
TCP_INT5_N1:	;

	;Si SEND_PUSH=2, salta directamente a NEW.

	ld	a,(SEND_PUSH)
	cp	2
	jr	z,TCP_INT5_NEW

	;Si NAGLE_ON=#FF y SND_NXT<>SND_UNA,
	;se salta las dos ultimas comprobaciones.
	;Si NAGLE_ON=0, no comprueba si SND_NXT<>SND_UNA.

	ld	a,(NAGLE_ON)
	or	a
	jr	z,TCP_INT5_N2

	ld	hl,SND_NXT
	ld	de,SND_UNA
	call	COMP_SEQ
	jp	nz,TCP_INT5_NONEW
TCP_INT5_N2:	;

	;Comprueba si min(DATA_OUT_SIZE,USABLE_W)>=1/2*MAX_SNDW,
	;en ese caso deberia saltar a NEW.
	;Por el razonamiento de la primera condicion, esto equivale a:
	;si DATA_OUT_SIZE<1/2*MAX_SNW o USABLE_W<1/2*MAX_SNDW,
	;NO se salta a TCP_INT5_NEW.

	ld	hl,(USABLE_W)
	ld	de,(MAX_SNDW)
	sra	d	;DE=1/2*MAX_SNDW
	rr	e
	call	COMP16
	jr	nc,TCP_INT5_N3

	ld	a,(DATA_OUT_SIZE+1)	;Si >64K, seguro que es
	or	a	;   ;>1/2*MAX_SNDW; entonces
	jr	nz,TCP_INT5_NEW	;   ;salta a NEW.

	;ld      de,(MAX_SNDW)
	;sra     d
	;rr      e
	ld	a,(DATA_OUT_SIZE+2)
	ld	h,a
	ld	a,(DATA_OUT_SIZE+3)
	ld	l,a
	call	COMP16
	jr	c,TCP_INT5_NEW
TCP_INT5_N3:	;

	;Se comprueba si:
	;SEND_PUSH=1 & DATA_OUT_SIZE <= USABLE_W
	;En ese caso se salta a NEW, si no, directamente a NONEW

	ld	a,(SEND_PUSH)
	cp	1
	jp	nz,TCP_INT5_NONEW

	ld	a,(DATA_OUT_SIZE+1)	;Si >64K, seguro que es
	or	a	;   ;>USABLE_W; entonces
	jr	nz,TCP_INT5_NEW	;   ;salta a NONEW.

	ld	de,(USABLE_W)
	ld	a,(DATA_OUT_SIZE+2)
	ld	h,a
	ld	a,(DATA_OUT_SIZE+3)
	ld	l,a
	call	COMP16
	jr	z,TCP_INT5_NEW
	jp	c,TCP_INT5_NONEW


	;* Se da una de las condiciones para enviar
	;  datos nuevos.
	;  Una vez enviados, los datos se han de retirar
	;  de DATA_OUT_QUEUE y encolar en RETX_QUEUE.

TCP_INT5_NEW:	call	CREATE_SEG	;Lo primero es crear un seg. vacio

	ld	hl,RETX_SIZE	;Si la cola ReTx estaba vacia,
	ld	de,NULL32	;hay que establecer su FIRST
	call	COMP32	;como el del segmento
	jr	nz,TCP_INT5_NEW!	;y LAST como FIRST-1
	ld	hl,SND_NXT
	ld	de,RETX_FIRST	;Bloque movido aqui en 0.2
	copy32
	ld	hl,RETX_FIRST
	ld	bc,RETX_LAST
	call	DEC32
TCP_INT5_NEW!:	;

	;--- Se extraen hasta SMSS bytes de DATA_OUT_QUEUE hacia
	;    BUFER_OUT+20 (tras la cabecera del datagrama en blanco
	;    creado), tras lo cual se insertan agrupados
	;    en un solo elemento en RETX_QUEUE.

	ld	hl,(USABLE_W)	;Anyadido en 0.3
	ld	de,(EFF_SMSS)
	call	COMP16
	jr	nc,COMPEFFUSW
	ex	de,hl
COMPEFFUSW:	push	hl
	pop	bc

	ld	ix,DATA_OUT_QUEUE
	ld	a,(#8002)
	ld	iy,BUFER_OUT+20
	;ld      bc,(USABLE_W)    ;(EFF_SMSS) en 0.2
	ld	d,0
	call	EXTRACT_DATA

	ld	hl,(EXTD_SIZE)
	ld	(SEG_PEND_DSIZE),hl
	ld	bc,20
	add	hl,bc
	ld	(SEG_PEND_TSIZE),hl

	ld	hl,SND_NXT	;SND_NXT se incrementa por el
	ld	de,(SEG_PEND_DSIZE)	;numero de bytes enviados
	ld	bc,SND_NXT
	call	ADD3216
	call	INIT_UTOUT

	;--- Establece PSH y URG si es necesario

	;- PUSH: Si SEND_PUSH=#FF, se establece el bit PSH del dgrama;
	;  y si SEND_PUSH_LAST<DATA_OUT_FIRST, se hace SEND_PUSH<-0

	ld	a,(SEND_PUSH)
	or	a
	jr	z,TCP_INT5_NEW6

	call	INCLUDE_PSH

	ld	hl,SEND_PUSH_LAST
	ld	de,DATA_OUT_FIRST
	call	COMP_SEQ
	jr	c,TCP_INT5_NEW6!
	xor	a
	ld	(SEND_PUSH),a

TCP_INT5_NEW6!:
	;Actualiza LAST_RETX_PUSH (nuevo en 0.2)

	ld	hl,BUFER_OUT+4
	ld	de,(SEG_PEND_DSIZE)
	dec	de	;Nuevo en 0.3
	ld	bc,LAST_RETX_PUSH
	call	ADD3216
TCP_INT5_NEW6:			;

	;- URG (si SEND_URG=#FF):
	;Si SEND_URG_LAST<DATA_OUT_FIRST (nuevo),
	;o bien si DATA_OUT_SIZE=0, se establece SEG_UP
	;(el puntero urgente del segmento) como:
	;SEND_URG_LAST-SEG_PEND_SEQ y se hace SEND_URG<-0
	;(todos los datos urgentes pend. ya estan en el segmento)
	;Si no, se hace SEG_UP<-SEG_PEND_DLEN-1

	ld	a,(SEND_URG)
	or	a
	jr	z,TCP_INT5_NEWR	;NEW8 en 0.1

	ld	hl,DATA_OUT_SIZE
	ld	de,NULL32
	call	COMP32
	jr	z,TCP_INT5_NEW60

	ld	hl,SEND_URG_LAST
	ld	de,DATA_OUT_FIRST
	call	COMP_SEQ
	jr	c,TCP_INT5_NEW7

TCP_INT5_NEW60:	xor	a	;Caso SEND_URG_LAST<DATA_IN_FIRST
	ld	(SEND_URG),a
	ld	de,SEND_URG_LAST
	ld	hl,BUFER_OUT+4
	ld	bc,TEMP_SEQ
	call	SUB32
	ld	a,(TEMP_SEQ+2)
	ld	b,a
	ld	a,(TEMP_SEQ+3)
	ld	c,a
	call	INCLUDE_URG
	jr	TCP_INT5_NEW7!	;NEWR en 0.2

TCP_INT5_NEW7:	ld	bc,(SEG_PEND_DSIZE)	;El caso contrario
	dec	bc
	call	INCLUDE_URG

	;Actualiza LAST_RETX_URG (nuevo en 0.2)

TCP_INT5_NEW7!:	ld	hl,BUFER_OUT+4
	ld	de,(BUFER_OUT+18)
	swap_de
	ld	bc,LAST_RETX_URG
	call	ADD3216


	;--- El paquete ya esta compuesto y DATA_OUT_QUEUE ajustado,
	;    ahora insertamos los datos en RETX_QUEUE
	;    con tres bytes extra al final que incluyen
	;    las banderas PSH y URG, y el campo URG

TCP_INT5_NEWR:	ld	hl,(SEG_PEND_DSIZE)	;Anyadido en 0.2
	ld	a,h
	or	l
	jr	z,TCP_INT5_OKRTO

	;Primero comprobamos si RTT_M_ON=1,
	;en ese caso lo ponemos a 2, hacemos RTT_M_CUR=0
	;y RTT_M_SEQ=SEG_SEQ.

	ld	a,(RTT_M_ON)
	cp	1
	jr	nz,TCP_INT5_NEWR2

	inc	a
	ld	(RTT_M_ON),a
	ld	hl,BUFER_OUT+4
	ld	de,RTT_M_SEQ
	copy32
	ld	bc,0
	ld	(RTT_M_CUR),bc	;Arreglado en 0.3

TCP_INT5_NEWR2:	;ld      hl,RETX_SIZE     ;Si la cola ReTx estaba vacia,
	;ld      de,NULL32        ;hay que establecer su FIRST
	;call    COMP32           ;como el del segmento
	;jr      nz,TCP_INT5_NEW4 ;y LAST como FIRST-1
	;ld      hl,BUFER_OUT+4
	;ld      de,RETX_FIRST    ;Bloque trasladado en 0.2
	;copy32
	;ld      hl,RETX_FIRST
	;ld      bc,RETX_LAST
	;call    DEC32
TCP_INT5_NEW4:			;

	;ld      hl,BUFER_OUT+20  ;Anyade al final
	;ld      bc,(SEG_PEND_DSIZE)  ;PSH, URG y SEG.UP
	;add     hl,bc
	;ld      a,(BUFER_OUT+13)
	;and     %101000
	;ld      (hl),a
	;inc     hl
	;ld      a,(BUFER_OUT+18)
	;ld      (hl),a
	;inc     hl
	;ld      a,(BUFER_OUT+19)
	;ld      (hl),a

	ld	a,(#8002)	;Inserta el elemento al final
	ld	b,a	;de la cola de ReTx
	ld	iy,BUFER_OUT+20
	ld	hl,(SEG_PEND_DSIZE)
	;inc     hl
	;inc     hl
	;inc     hl
	set	7,h
	set	6,h
	ld	a,(RETX_QUEUE)
	ld	ix,(RETX_QUEUE+1)
	nesman	28

	ld	hl,RETX_LAST	;Actualiza SIZE y LAST
	ld	de,(SEG_PEND_DSIZE)	;de RETX_QUEUE
	ld	bc,RETX_LAST
	call	ADD3216
	ld	hl,RETX_SIZE
	ld	de,(SEG_PEND_DSIZE)
	ld	bc,RETX_SIZE
	call	ADD3216

	;Activa RTO_RUN y pone RTO_T <- RTO, si no estaba ya
	;activo

	;ld      a,(RTO_RUN)     ;Quitado en 0.2
	;or      a
	;jr      nz,TCP_INT5_OKRTO
	;cpl
	;ld      (RTO_RUN),a
	;ld      hl,(RTO)
	;ld      (RTO_T),hl
TCP_INT5_OKRTO:			;

	;--- Si no quedan mas datos a enviar y CLOSE_PENDING=#FF,
	;    se envia un FIN y se pasa a FIN-WAIT-1
	;    (excepto si el estado es CLOSE-WAIT, en ese caso
	;    se pasa a LAST-ACK)
	;    Bloque movido aqui en 0.2

TCP_INT5_NONEW:	;
TCP_INT5_NEW8:	ld	hl,DATA_OUT_SIZE
	ld	de,NULL32
	call	COMP32
	jr	nz,TCP_INT5_NOFIN	;NEWR en 0.1

	;ld      hl,RETX_SIZE     ;Anyadido en 0.1
	;ld      de,NULL32
	;call    COMP32
	;jr      nz,TCP_INT5_NOFIN ;NEWR en 0.1

	ld	a,(CLOSE_PENDING)
	or	a
	jr	z,TCP_INT5_NOFIN	;NEWR en 0.1

	call	INCLUDE_FIN
	xor	a
	ld	(CLOSE_PENDING),a

	ld	a,(CUR_STATE)
	cp	CLOSE.WAIT
	ld	a,FIN.WAIT.1
	jr	nz,TCP_INT5_NEW9
	ld	a,LAST.ACK
TCP_INT5_NEW9:	ld	(CUR_STATE),a

	;Fin del proceso de datos nuevos para enviar:
	;incluimos un ACK en el segmento junto con los
	;datos nuevos

TCP_INT5_NOFIN:	ld	a,(SEG_PENDING)
	or	a
	jr	nz,TCP_INT5_OKAK

	;--- ACK: Se envia si ACK_DELAYED=#FF y ACK_DELAY_T=0,
	;    o si ACK_RCV_NUM>=ACK_RCV_MAX, o si RWND_UPD_FLAG=#FF,
	;    o si PROBE_ZW_T=0

	;ld      a,(RWND_UPD_FLAG)
	;or      a
	;jr      nz,TCP_INT5_OKAK

	ld	hl,(ACK_RCV_NUM)
	ld	de,(ACK_RCV_MAX)
	call	COMP16
	jr	c,TCP_INT5_OKAK

	ld	a,(ACK_DELAY_T)
	cpl
	ld	b,a
	ld	a,(ACK_DELAYED)
	and	b
	cp	#FF
	jr	z,TCP_INT5_OKAK

	ld	hl,(PROBE_ZW_T)
	ld	a,h
	or	l
	jr	nz,TCP_INT5_NOAK

	ld	hl,(PROBE_ZW_V)	;Reinicia contador de prueba
	add	hl,hl	;de ventana cero con valor doble,
	ld	de,5000	;maximo 100 segundos
	call	COMP16
	jr	nc,TCP_INT5_INITZW
	ex	de,hl
TCP_INT5_INITZW:	ld	(PROBE_ZW_V),hl
	ld	(PROBE_ZW_T),hl

	call	CREATE_SEG	;Si es un segmento de prueba de
	ld	bc,BUFER_OUT+4	;ventana cero, envia el ACK con
	ld	hl,BUFER_OUT+4	;numero de secuencia=SND_NXT-1,
	call	DEC32	;para forzar un ACK como respuesta

	;Se cumple alguna de las condiciones: se envia el ACK

TCP_INT5_OKAK:	xor	a
	call	INCLUDE_ACK

	xor	a
	ld	(RWND_UPD_FLAG),a
	ld	(ACK_DELAYED),a
	ld	hl,0
	ld	(ACK_RCV_NUM),hl
	ld	a,(ACK_DELAY_MAX)
	ld	(ACK_DELAY_T),a
TCP_INT5_NOAK:			;

	;--- Finalmente, se envia el segmento, se graba el TCB
	;    y se termina

	call	SEND_DGRAM
	ld	hl,(SEG_PEND_DSIZE)	;Anyadido en 0.2
	ld	a,h
	or	l
	call	nz,SET_RTO
	ld	a,(CUR_CON)
	call	SAVE_CON
	ret



;****************************
;**                        **
;**   RUTINAS AUXILIARES   **
;**                        **
;****************************


;--- SET_RTO: Establece RTO_RUN y RTO_T si no estaban ya establecidos

SET_RTO:	ld	a,(RTO_RUN)
	or	a
	ret	nz
	cpl
	ld	(RTO_RUN),a
	ld	hl,(RTO)
	ld	(RTO_T),hl
	ld	(LAST_USED_RTO),hl
	ret


;--- NESMAN: Realiza una llamada a la funcion de NestorMan indicada en C.
;            La llamada es semidirecta si NMAN_INDIR=0, si no, indirecta.

NESMAN:	if	ALWAYS_INDIR=1

	ld	de,#2202
	jp	#FFCA

	else

	push	af
	ld	a,(NMAN_INDIR)
	or	a
	jr	nz,NESMAN2

	pop	af
	jp	#4139

NESMAN2:	pop	af
	ld	de,#2202
	jp	#FFCA

	endif

NMAN_INDIR:	db	0


;--- LOAD_CON_CHK: Carga en TCB_CUR la conexion A.
;                  Si no esta en uso, o si A>NUM_CON_MAX,
;                  devuelve Cy=1 y A=1.

LOAD_CON_CHK:	cp	NUM_CON_MAX	;A>NUM_CON_MAX: error
	ccf
	ld	b,a
	ld	a,1
	ret	c
	ld	a,b

	call	LOAD_CON	;Estado=CLOSED: error
	ld	a,(CUR_STATE)
	or	a
	scf
	ld	a,1
	ret	z

	xor	a
	ret


;--- SET_SMSS: Busca la opcion SMSS en el datagrama que esta en BUFER_IN,
;              y si la encuentra establece SMSS, SMSS2 y EFF_SMSS

SET_SMSS:	ld	a,(SEG_HLEN)
	cp	20
	ret	z	;No hay opciones?

	sub	20
	ld	c,a	;C = Longitud restante opciones
	ld	ix,BUFER_IN+20	;IX = Puntero a la opcion en curso
TCP_OP_LOOP:	ld	a,(ix)
	or	a
	ret	z	;Opcion "end of options"?
	cp	1
	jr	nz,TCP_OP_LOOP2
	dec	c	;Opcion "no operation"?
	ret	z	;No quedan mas opciones?
	inc	ix
	jr	TCP_OP_LOOP
TCP_OP_LOOP2:	cp	2	;No es opcion 0 ni 1: tiene codigo
	jr	z,TCP_OP_LOOP4	;y longitud, en IX e IX+1
	ld	b,(ix+1)
TCP_OP_LOOP3:	inc	ix	;Opcion desconocida: la ignora
	dec	c
	ret	z	;No quedan mas opciones?
	djnz	TCP_OP_LOOP3
	jr	TCP_OP_LOOP

	;Opcion encontrada: establece SMSS al valor de la opcion,
	;y establece EFF_SMSS <- min(SMSS, MRU-40)

TCP_OP_LOOP4:	ld	h,(ix+2)	;DE = SMSS
	ld	l,(ix+3)
	ld	de,536	;Si pretende SMSS<536, se ignora
	call	COMP16	;la opcion
	ret	nc
	ld	(SMSS),hl
	push	hl
	pop	de
	add	hl,hl
	ld	(SMSS2),hl

	ld	hl,(MRU)
	ld	bc,40
	or	a
	sbc	hl,bc	;HL = MRU-40

	call	COMP16
	jr	nc,TCP_OP_LOOP5
	ex	de,hl
TCP_OP_LOOP5:	ld	(EFF_SMSS),hl	;Establece el minimo de ambos

	ret


;--- INIT_UTOUT: Inicializa el timeout global de usuario

INIT_UTOUT:	ld	hl,(USER_TOUT_V)
	ld	(USER_TOUT_T),hl
	ret


;--- SCHEDULE_ACK: Avisa de que hay pendiente de envio un ACK
;                  e inicializa las variables y contadores
;                  para que se envie en el momento oportuno

SCHEDULE_ACK:	ld	a,(ACK_DELAYED)	;No hace nada si ya hay un ACK pend.
	or	a
	ret	nz
	cpl
	ld	(ACK_DELAYED),a
	ld	a,(ACK_DELAY_MAX)
	ld	(ACK_DELAY_T),a
	ret


;--- SET_WNDWL: Establece:
;               SND.WND<-SEG.WND
;               SND.WL1<-SEG.SEQ
;               SND.WL2<-SEG.ACK
;               Si es necesario, actualiza MAX_SNDW

SET_WNDWL:	ld	hl,(SEG_WND)	;Arreglado en 0.3: se trataba como
	ld	(SND_WND),hl	;valor de 32 bits

;                  ld      a,(KKFLAG)       ;!!!PRUEBA: Emulacion de ventana 0
;                  or      a                ;para emision
;                  jr      z,SET_WNDWLKK
;                  ld      hl,0
;                  ld      (SND_WND),hl
;SET_WNDWLKK:      ;

	ld	a,h
	or	l
	jr	z,SET_WNDWL2
	ld	hl,150
	ld	(PROBE_ZW_V),hl
	ld	(PROBE_ZW_T),hl
SET_WNDWL2:	;

	ld	hl,SEG_SEQ
	ld	de,SND_WL1
	copy32

	ld	hl,SEG_ACK
	ld	de,SND_WL2
	copy32

	ld	de,(SND_WND)	;Si SND_WND > MAX_SNDW,
	ld	hl,(MAX_SNDW)	;MAX_SNDW <- SND_WND
	call	COMP16
	ret	c
	ld	(MAX_SNDW),de	;Arreglado en 0.3

	ret


;--- REPLY_RST: Envia un paquete de reset como respuesta a un paquete recibido
;               que no corresponde a ninguna conexion abierta.
;               Si ACK=0, envia <SEQ=0><ACK=SEG.SEQ+SEG.LEN><CTL=RST,ACK>
;               Si ACK=1, envia <SEQ=SEG.ACK><CTL=RST>
;    Entrada:   Segmento TCP invalido en BUFER_IN (cabecera IP en BUFER_IN-20)
;               Variables SEG_xLEN establecidas

	;Primero crea el paquete con CREATE_SEG,
	;pero tomando los valores de la IP remota y los puertos
	;del paquete en BUFER_IN

REPLY_RST:	ld	hl,BUFER_IN-20+12
	call	CREATE_SEG2
	ld	hl,(BUFER_IN)	;Invierte puertos
	ld	(BUFER_OUT+2),hl
	ld	hl,(BUFER_IN+2)
	ld	(BUFER_OUT),hl
	ld	hl,BUFER_OUT+13	;Activa RST
	_set	RST,(hl)
	ld	hl,0
	ld	(BUFER_OUT+14),a	;Ventana a 0

	;Comprueba si ACK=1, en ese caso envia
	;<SEQ=SEG.ACK><CTL=RST>

	ld	hl,BUFER_IN+13
	_bit	ACK,(hl)
	jr	z,REPLY_RST2
	call	INCLUDE_RST	;RST on
	ld	hl,SEG_ACK
	ld	de,BUFER_OUT+4	;SEQ=SEG_ACK
	copy32
	jr	REPLY_RST3

	;Si ACK=0, envia <SEQ=0><ACK=SEG.SEQ+SEG.LEN><CTL=RST,ACK>

REPLY_RST2:	ld	a,1	;ACK=on, SEG_SEQ+SEG_LEN
	call	INCLUDE_ACK
	ld	hl,NULL32	;SEQ=0
	ld	de,BUFER_OUT+4
	copy32
	call	INCLUDE_RST	;RST on

	;Paquete completo: lo envia

REPLY_RST3:	jp	SEND_DGRAM



;--- ENQUEUE_IN_DATA: Introduce en la cola de entrada los datos
;                     recibidos en un paquete
;    Entrada: Paquete en BUFER_IN
;             SEG_xLEN establecidos (x=H,D,T)
;    Salida:  Se actualizan DATA_IN_xx

ENQUEUE_IN_DATA:			;


;--- SET_SSTHRESH: Establece SSTHRESH como:
;                  max(FlightSize/2, 2*SMSS)

SET_SSTHRESH:	ld	de,SND_NXT	;Calcula FLIGHT_SIZE
	ld	hl,SND_UNA
	ld	bc,FLIGHT_SIZE
	call	SUB32
	ld	a,(FLIGHT_SIZE+2)	;Suponemos que es <64K
	ld	h,a
	ld	a,(FLIGHT_SIZE+3)
	ld	l,a
	srl	h
	rr	l	;HL = FlightSize/2

	ld	de,(SMSS2)
	call	COMP16
	jr	c,SET_SSTH2
	ex	de,hl
SET_SSTH2:	ld	(SSTHRESH),hl
	ret


;--- SET_CWND: Establece CWND con el valor HL.
;              Si CWND>=SSTHRESH tras la operacion, pasa a
;              Congestion Avoidance; si no, pasa a Slow Start.
;    Modifica: AF, DE

SET_CWND:	ld	(CWND),hl
	ld	de,(SSTHRESH)
	call	COMP16
	ld	a,#FF
	jr	c,SET_CWND2
	cpl
SET_CWND2:	ld	(CONG_AVO),a
	ret

KK_DE_BK:	;push    hl,de,bc,af     ;*** PRUEBAS
	;ld      a,(INT_LEVEL)
	;cp      1
	;jr      nz,KK_FIN
	;ld      hl,(KK_PNT)
	;ld      de,#A800
	;call    COMP16
	;jr      z,KK_FIN
	;ld      (hl),c
	;inc     hl
	;ld      (KK_PNT),hl
KK_FIN:	;pop     af,bc,de,hl
	;ret
KK_PNT:	;dw      #9F00


;--- EXTRACT_DATA: Elimina/Extrae BC datos de la cola especificada en IX
;    Entrada:      IX = Puntero a la cola y:
;                       IX+3 = Primer numero de secuencia
;                       IX+7 = Ultimo numero de secuencia
;                       IX+11 = Numero de datos encolados
;                  A-IY = Direccion de extraccion (0-0: solo elimina)
;                  BC = Longitud a extraer/elimiar
;                  D = Valor para NMAN_INDIR
;    Salida:       (EXTD_SIZE) = Num. de datos realmente extraidos/eliminados

EXTRACT_DATA:	ld	(EXTD_SEG),a
	ld	(EXTD_ADD),iy
	ld	hl,0
	ld	(EXTD_SIZE),hl
	push	af
	ld	a,d
	ld	(NMAN_INDIR),a
	pop	af
	push	iy
	pop	hl
	or	h
	or	l
	ld	a,2
	jr	z,EXT_DATA2
	inc	a
EXT_DATA2:	ld	(EXTD_METHOD),a	;2: solo eliminar, 3: tambien extraer

	ld	a,b	;No hace nada si BC=0
	or	c	;o si no hay datos encolados
	ret	z
	ld	a,(ix+12)
	or	(ix+13)
	or	(ix+14)
	ret	z

	ld	(EXTD_SIZE),bc
	push	ix	;Guarda los datos de la cola
	pop	hl	;y del resto de parametros
	ld	de,EXTD_Q_QUEUE
	ld	bc,15
	ldir
	ld	(EXTD_QPNT),ix

	;--- Estamos listos para leer/eliminar los datos.
	;    Primero se comprueba si la recogida de datos
	;    vaciara completamente la cola: en ese caso
	;    usamos un algoritmo sencillo que simplemente
	;    extraera/eliminara los datos mientras queden.

	ld	a,(EXTD_Q_SIZE+1)
	or	a
	jr	nz,EXTD4

	ld	a,(EXTD_Q_SIZE+2)
	ld	h,a
	ld	a,(EXTD_Q_SIZE+3)
	ld	l,a
	ld	de,(EXTD_SIZE)
	inc	de
	call	COMP16
	jr	c,EXTD4

	ld	(EXTD_SIZE),hl	;Ajusta tamanyo real de los datos

	;Algoritmo sencillo: lee datos mientras queden

	ld	iy,(EXTD_ADD)
EXTD_LOP1:	ld	b,1
	ld	a,(EXTD_SEG)
	ld	l,a
	ld	a,(EXTD_METHOD)
	ld	h,a
	ld	a,(EXTD_Q_QUEUE)
	ld	ix,(EXTD_Q_QUEUE+1)
	push	iy
	ld	c,29
	call	NESMAN
	;call    KK_DE_BK
	pop	iy
	jr	c,EXTD_END2

	add	iy,bc
	jr	EXTD_LOP1

	;Como ahora la cola de entrada esta vacia,
	;establece EXTD_SIZE a 0

EXTD_END2:	ld	hl,NULL32
	ld	de,EXTD_Q_SIZE
	copy32

	;Aunque en teoria no hace falta porque cuando
	;una cola esta vacia los punteros FIRST y LAST
	;no tienen sentido, se establece FIRST
	;como si apuntara al ultimo elemento; esto puede
	;ahorrar problemas en partes del codigo que
	;comprueben FIRST o LAST sin antes comprobar si SIZE=0.

	ld	hl,EXTD_Q_LAST
	ld	de,EXTD_Q_FIRST
	copy32

	jp	EXTD_END	;Termina

	;--- Estamos listos para leer los datos, pero se requieren
	;    menos datos de los disponibles.
	;    Primero se recorren en un bucle todos los elementos
	;    de la cola de entrada pero sin extraerlos, solo se
	;    obtiene su longitud; de esta forma se averigua
	;    cuantos elementos hay que extraer, y que porcion del
	;    ultimo elemento hay que copiar al bufer del usuario.

EXTD4:	;ld      hl,0
	;ld      (EXTD_ASIZE),hl
	ld	hl,-1
	ld	(EXTD_SEGS),hl	;Num de elementos completos a extraer

	ld	a,(EXTD_Q_QUEUE)	;Establece el puntero al
	ld	ix,(EXTD_Q_QUEUE+1)	;principio de la lista
	ld	b,1
	ld	c,23
	call	NESMAN

	;Recorre todos los elementos y acumula sus tamanyos
	;hasta que lleguemos a EXTD_SIZE

	ld	hl,0
EXTD_LOP2:	push	hl	;HL = Tamanyo extraido acumulado
	ld	b,0
	ld	h,0
	ld	a,(EXTD_Q_QUEUE)
	ld	ix,(EXTD_Q_QUEUE+1)
	ld	c,29
	call	NESMAN
	;call    KK_DE_BK

	push	bc	;Avanza el puntero de la lista
	ld	a,(EXTD_Q_QUEUE)
	ld	ix,(EXTD_Q_QUEUE+1)
	ld	b,3
	ld	c,23
	call	NESMAN
	pop	bc

	ld	hl,(EXTD_SEGS)
	inc	hl
	ld	(EXTD_SEGS),hl

	pop	hl
	add	hl,bc	;Actualiza acumulado de datos

	ld	de,(EXTD_SIZE)	;ERA TCP_SEND_SIZE!!!
	call	COMP16	;Repite bucle si aun no hemos llegado
	jr	nc,EXTD_LOP2	;al tamanyo total

	;ld      (EXTD_ASIZE),hl   ;Calcula el tamanyo sobrante
	ld	bc,(EXTD_SIZE)	;   ;del ultimo elemento
	or	a
	sbc	hl,bc
	ld	(EXTD_SOBRA),hl

	ld	a,h	;Si el ultimo elemento completaba
	or	l	;exactamente los bytes necesarios,
	jr	nz,EXTD_NOSOBRA	;incrementamos el numero de
	ld	hl,(EXTD_SEGS)	;segmentos completos a extraer,
	inc	hl	;y el proceso de los datos sobrantes
	ld	(EXTD_SEGS),hl	;sera ignorado ya que SOBRA=0
EXTD_NOSOBRA:	;

	;Ahora se repite el bucle anterior, pero esta vez
	;extrayendo EXTD_SEGS segmentos
	;hacia el bufer del usuario

	ld	a,(EXTD_Q_QUEUE)	;Establece el puntero al
	ld	ix,(EXTD_Q_QUEUE+1)	;principio de la lista
	ld	b,1
	ld	c,23
	call	NESMAN	;"nesmani 23" en version 0.1

	ld	hl,0
	;ld      (EXTD_ASIZE),hl
	ld	bc,(EXTD_SEGS)
	ld	iy,(EXTD_ADD)

	ld	a,b
	or	c
	jr	z,EXTD_ENDL3

EXTD_LOP3:	push	bc
	push	hl	;HL = Tamanyo extraido acumulado
	ld	b,1
	ld	a,(EXTD_METHOD)
	ld	h,a
	ld	a,(EXTD_SEG)
	ld	l,a
	ld	a,(EXTD_Q_QUEUE)
	ld	ix,(EXTD_Q_QUEUE+1)
	push	iy
	ld	c,29
	call	NESMAN

	pop	iy	;Actualiza direccion de destino
	add	iy,bc	;y tamanyo acumulado
	pop	hl
	add	hl,bc

	pop	bc
	dec	bc
	ld	a,b
	or	c
	jr	nz,EXTD_LOP3

	ld	(EXTD_ADD),iy

	;Extrae el ultimo elemento necesario
	;a un bufer interno, y copia al bufer del usuario
	;solo la parte necesaria para completar EXTD_SIZE

EXTD_ENDL3:	ld	hl,(EXTD_SOBRA)
	ld	a,h	;No es necesario si el ultimo
	or	l	;elemento extraido ya completaba
	jr	z,EXTD_ENDL4	;EXTD_SIZE

	ld	a,(#8002)
	ld	l,a
	ld	b,1	;Extrae elemento al bufer generico
	ld	h,3
	ld	a,(EXTD_Q_QUEUE)
	ld	ix,(EXTD_Q_QUEUE+1)
	ld	iy,BUFER_GEN
	ld	c,29
	call	NESMAN

	push	bc	;Calcula HL = Tamanyo a copiar al
	pop	hl	;bufer del usuario
	ld	bc,(EXTD_SOBRA)
	or	a
	sbc	hl,bc

	ld	a,(EXTD_METHOD)
	cp	3
	ld	a,(EXTD_SEG)
	ld	b,a
	ld	a,(#8002)	;Realiza la transferencia
	ld	ix,BUFER_GEN	;solo si METHOD=3 (habia que extraer)
	ld	iy,(EXTD_ADD)
	push	hl
	ld	c,14
	call	z,NESMAN
	pop	bc

	ld	iy,BUFER_GEN	;Inserta la parte sobrante del
	add	iy,bc	;elemento extraido al principio
	ld	hl,(EXTD_SOBRA)	;de la cola de entrada
	set	7,h
	ld	a,(#8002)
	ld	b,a
	ld	a,(EXTD_Q_QUEUE)
	ld	ix,(EXTD_Q_QUEUE+1)
	set	7,h
	ld	c,28
	call	NESMAN
EXTD_ENDL4:	;

	;El bufer del usuario y la cola ya estan listos.
	;Ahora ajusta EXTD_Q_FIRST/LAST/SIZE.

	ld	hl,EXTD_Q_FIRST	;Ajusta EXTD_Q_FIRST
	ld	de,(EXTD_SIZE)	;para que apunte tras el ultimo
	ld	bc,EXTD_Q_FIRST	;num se secuencia consumido
	call	ADD3216

	ld	de,EXTD_Q_SIZE	;Ajusta EXTD_Q_SIZE
	ld	hl,(EXTD_SIZE)
	ld	bc,EXTD_Q_SIZE
	call	SUB3216

	;Termina

EXTD_END:	ld	hl,EXTD_Q_QUEUE
	ld	de,(EXTD_QPNT)
	ld	bc,15
	ldir
	ret

	;--- Variables

;EXTD_SIZE:        equ     TCP_SEND_SIZE    ;Numero total de datos a leer
;EXTD_ADD:         equ     TCP_SEND_ADD     ;Direccion de extraccion
;EXTD_SEGS:        equ     TCP_SEND_SEGS    ;Numero de elementos a extraer
;EXTD_SEG:         equ     TCP_SEND_ENDF    ;Segmento de extraccion
;EXTD_SOBRA:       equ     TCP_SEND_PSIZE   ;Datos a preservar en el ultimo elem.
EXTD_SIZE:	ds	4
EXTD_ADD:	ds	4
EXTD_SEGS:	ds	4
EXTD_SEG:	ds	4
EXTD_SOBRA:	ds	4
EXTD_Q_QUEUE:	ds	3	;Datos de la cola a operar
EXTD_Q_FIRST:	ds	4
EXTD_Q_LAST:	ds	4
EXTD_Q_SIZE:	ds	4
EXTD_QPNT:	dw	0	;Direccion original de EXTD_QUEUE
EXTD_METHOD:	db	0	;2=solo eliminar, 3=extraer y eliminar



;--- CREATE_SEG: Crea un segmento vacio en BUFER_OUT
;    La cabecera IP se crea en BUFER_OUT-8, de forma que la cabecera TCP
;    empieza en BUFER_OUT
;    Se supone que la conexion esta en TCB_CUR
;    Se toma el numero de secuencia de SND.NXT
;    Se establece la ventana como RCV.WND
;    Salida: Cy=1 si error (la conexion TCB_CUR no existe)

CREATE_SEG:	ld	a,(CUR_STATE)
	or	a
	scf
	ret	z

	;--- Crea pseudo-cabecera IP

	ld	hl,REMOTE_IP	;Dir. IP
CREATE_SEG2:	ld	de,BUFER_OUT-8
	copy32
	ld	a,6	;Protocolo TCP
	ld	(BUFER_OUT-4),a
	ld	a,1
	ld	(BUFER_OUT-3),a	;TOS
	ld	a,(SEND_TOS)
	ld	(BUFER_OUT-2),a
	xor	a	;Fin de pseudo-cabecera
	ld	(BUFER_OUT-1),a

	;--- Crea cabecera TCP

	ld	hl,(LOCAL_PORT)	;Puerto local
	ld	(BUFER_OUT),hl
	ld	hl,(REMOTE_PORT)	;Puerto remoto
	ld	(BUFER_OUT+2),hl
	ld	hl,BUFER_OUT+4	;Resto de la cabecera a 0
	ld	de,BUFER_OUT+5
	ld	(hl),0
	ld	bc,15
	ldir
	ld	a,#50	;Longitud cabecera=5
	ld	(BUFER_OUT+12),a
	ld	hl,SND_NXT	;Numero de secuencia
	ld	de,BUFER_OUT+4
	copy32
	ld	a,(RCV_WND)	;Ventana de recepcion
	ld	(BUFER_OUT+15),a
	ld	a,(RCV_WND+1)
	ld	(BUFER_OUT+14),a

	;--- Modifica variables

CREATE_SEG_END:	ld	a,#FF
	ld	(SEG_PENDING),a
	ld	hl,20
	ld	(SEG_PEND_TSIZE),hl
	ld	a,20
	ld	(SEG_PEND_HSIZE),a	;*** HL en 0.1
	ld	a,(CUR_CON)
	ld	(SEG_PEND_CON),a
	ld	hl,0
	ld	(SEG_PEND_DSIZE),hl
	or	a
	ret


;--- INCLUDE_RST: Establece el bit RST del paquete en BUFER_OUT.
;                 Si no hay paquete, crea uno.
;    Se supone que la conexion esta en TCB_CUR
;    Salida: Cy=1 si error (la conexion TCB_CUR no existe)

INCLUDE_RST:	ld	a,(SEG_PENDING)
	or	a
	call	z,CREATE_SEG
	ret	c

	ld	hl,BUFER_OUT+13
	_set	RST,(hl)
	ret


;--- INCLUDE_PSH: Establece el bit RST del paquete en BUFER_OUT.
;                 Si no hay paquete, crea uno.
;    Se supone que la conexion esta en TCB_CUR
;    Salida: Cy=1 si error (la conexion TCB_CUR no existe)

INCLUDE_PSH:	ld	a,(SEG_PENDING)
	or	a
	call	z,CREATE_SEG
	ret	c

	ld	hl,BUFER_OUT+13
	_set	PSH,(hl)
	ret


;--- INCLUDE_URG: Establece el bit URG del paquete en BUFER_OUT.
;                 Si no hay paquete, crea uno.
;                 Entrada: BC = Longitud de la zona urgente
;                               (dato a insertar en el campo UP)
;    Se supone que la conexion esta en TCB_CUR
;    Salida: Cy=1 si error (la conexion TCB_CUR no existe)

INCLUDE_URG:	ld	a,(SEG_PENDING)
	or	a
	push	bc
	call	z,CREATE_SEG
	pop	bc
	ret	c

	ld	hl,BUFER_OUT+13
	_set	URG,(hl)

	ld	a,b
	ld	(BUFER_OUT+18),a
	ld	a,c
	ld	(BUFER_OUT+19),a

	or	a
	ret


;--- INCLUDE_WND: Establece el campo "window" del paquete en BUFER_OUT.
;                 Si no hay paquete, crea uno.
;                 Entrada: BC = Longitud de la ventana
;    Se supone que la conexion esta en TCB_CUR
;    Salida: Cy=1 si error (la conexion TCB_CUR no existe)

INCLUDE_WND:	ld	a,(SEG_PENDING)
	or	a
	push	bc
	call	z,CREATE_SEG
	pop	bc
	ret	c

	ld	a,b
	ld	(BUFER_OUT+14),a
	ld	a,c
	ld	(BUFER_OUT+15),a
	ret


;--- INCLUDE_ACK: Establece el bit ACK y el campo "ack" del paq en BUFER_OUT.
;                 Si no hay paquete, crea uno.
;                 Entrada: A=0: ACK <- RCV_NXT
;                          A=1: ACK <- SEG_SEQ+SEG_LEN
;                          A=2: ACK <- (HL)
;    Se supone que la conexion esta en TCB_CUR
;    Salida: Cy=1 si error (la conexion TCB_CUR no existe)

INCLUDE_ACK:	push	af
	ld	a,(SEG_PENDING)
	or	a
	push	hl
	call	z,CREATE_SEG
	pop	hl
	jr	c,INC_ACK_ERR

	push	hl
	ld	hl,BUFER_OUT+13
	_set	ACK,(hl)
	pop	hl

	pop	af
	cp	1
	jr	z,INC_ACK_1
	cp	2
	jr	z,INC_ACK_02

INC_ACK_0:	ld	hl,RCV_NXT	;Si A=0
INC_ACK_02:	ld	de,BUFER_OUT+8
	copy32
	or	a
	ret

INC_ACK_1:	ld	hl,SEG_SEQ	;Si A=1
	ld	de,(SEG_PEND_DSIZE)	;Era SEG_DLEN en 0.2
	ld	bc,BUFER_OUT+8
	call	ADD3216
	or	a
	ret

INC_ACK_ERR:	pop	af
	scf
	ret


;--- INCLUDE_SYN: Incluye el bit SYN en el paquete en BUFER_OUT,
;                 poniendo su numero de secuencia a ISS.
;                 Inclye la opcion "segment size" si RMSS no es 536.
;    Se supone que la conexion esta en TCB_CUR
;    Salida: Cy=1 si error (la conexion TCB_CUR no existe)

INCLUDE_SYN:	ld	a,(SEG_PENDING)
	or	a
	call	z,CREATE_SEG
	ret	c

	ld	hl,BUFER_OUT+13
	_set	SYN,(hl)

	ld	a,#FF	;Establece el numero de secuencia
	ld	(SYN_SENT_FLAG),a	;del SYN enviado como ISS
	ld	hl,ISS
	ld	de,SYN_SENT_SEQ
	copy32
	ld	hl,ISS
	ld	de,BUFER_OUT+4
	copy32

	;Incluye opcion "segment size" si RMSS no es 536
	;(asume que no hay datos en el segmento)

	ld	hl,(RMSS)
	ld	de,536
	call	COMP16
	ret	z

	ld	hl,#0402
	ld	(BUFER_OUT+20),hl	;Tipo=2,Longitud=4
	ld	a,(RMSS+1)
	ld	(BUFER_OUT+22),a
	ld	a,(RMSS)
	ld	(BUFER_OUT+23),a	;RMSS en big-endian
	ld	a,#60
	ld	(BUFER_OUT+12),a	;Tamanyo cabecera

	ld	hl,24	;Ajusta tamanyo de segmento
	ld	(SEG_PEND_TSIZE),hl
	ld	a,24
	ld	(SEG_PEND_HSIZE),a	;*** HL en 0.1

	or	a
	ret


;--- INCLUDE_FIN: Incluye el bit FIN en el paquete en BUFER_OUT
;                 Establece FIN_SENT_FLAG y modifica SND_NXT si es necesario
;    Se supone que la conexion esta en TCB_CUR
;    Salida: Cy=1 si error (la conexion TCB_CUR no existe)

INCLUDE_FIN:	ld	a,(SEG_PENDING)
	or	a
	call	z,CREATE_SEG
	ret	c

	ld	hl,BUFER_OUT+13
	_set	FIN,(hl)

	ld	a,(FIN_SENT_FLAG)
	or	a
	jr	nz,INCFIN_1

	;Si no se habia enviado ya FIN

INCFIN_0:	cpl		;                ;Establece el numero de secuencia
	ld	(FIN_SENT_FLAG),a	;del FIN enviado como
	ld	hl,BUFER_OUT+4	;SEG_PEND_SEQ + SEG_PEND_DLEN
	ld	de,(SEG_PEND_DSIZE)
	ld	bc,FIN_SENT_SEQ	;(SEQ del FIN = el ultimo del
	call	ADD3216	;segmento+1)

	ld	hl,SND_NXT	;Necesario para reconocer adecuadamente
	ld	bc,SND_NXT	;el ACK del FIN
	call	INC32

	or	a
	ret

	;Si ya se habia enviado FIN

INCFIN_1:	ld	hl,SEG_PEND_DSIZE	;Si no hay datos en el dgrama,
	ld	a,h	;el numero de secuencia
	or	l	;es el del propio FIN
	jr	nz,INCFIN_F

	ld	hl,FIN_SENT_SEQ
	ld	de,BUFER_OUT+4
	copy32

INCFIN_F:	or	a
	ret


;--- LOAD_CON: Carga el TCB de una determinada conexion en TCB_CUR
;    Entrada:  A=numero de conexion

LOAD_CON:	push	af

	ld	b,a
	inc	b
	ld	hl,TCB_CON-TCB_SIZE
	ld	de,TCB_SIZE	;Calcula HL=dir. del TCB
LOAD_CON_LOP:	add	hl,de
	djnz	LOAD_CON_LOP

	ld	de,TCB_CUR	;Copia el TCB a TCB_CUR
	ld	bc,TCB_SIZE

	ld	a,#FF
	ld	(LOADING_CON),a
	ldir
	pop	af
	ld	(CUR_CON),a
	xor	a
	ld	(LOADING_CON),a

	ret


;--- SAVE_CON: Graba el TCB de TCB_CUR a una determinada conexion
;    Entrada:  A=numero de conexion
;    Preserva A

SAVE_CON:	ld	b,a
	inc	b
	ld	hl,TCB_CON-TCB_SIZE
	ld	de,TCB_SIZE	;Calcula HL=dir. del TCB
SAVE_CON_LOP:	add	hl,de
	djnz	SAVE_CON_LOP

	ex	de,hl
	ld	hl,TCB_CUR	;Copia el TCB de TCB_CUR
	ld	bc,TCB_SIZE
	ldir

	ret


;--- GEN_ISS: Genera un numero de secuencia en ISS

	;El ISS se establece de la siguiente manera:
	;Byte 3 = hora + 32*dia de la semana
	;Byte 2 = minuto
	;Byte 3 = segundo
	;Byte 4 = byte bajo del reloj TIME

GEN_ISS:	;ld      c,_GDATE
	;call    #F37D
	;and     %111
	;rrc     a
	;rrc     a
	;rrc     a
	;push    af
	;ld      c,_GTIME
	;call    #F37D
	;pop     af
	;or      h
	;ld      (ISS),a
	;ld      a,l
	;ld      (ISS+1),a
	;ld      a,d
	;ld      (ISS+2),a
	;ld      a,(#FC9E)
	;ld      (ISS+3),a

	ld	a,(ISS_T)
	ld	(ISS),a
	ld	a,(ISS_T+1)
	ld	(ISS+1),a
	ld	a,(#FC9E)
	ld	(ISS+2),a
	ld	a,(#FC9F)
	ld	(ISS+3),a

	ld	hl,ISS
	ld	de,LAST_RETX_PUSH
	copy32
	ld	hl,ISS
	ld	de,LAST_RETX_URG
	copy32

	ret


;--- TCP_CHKSUM: Calcula el checksum de un datagrama TCP
;    Entrada: IX = Datagrama
;             HL = Puntero a una IP (origen o destino)
;             DE = Puntero a la otra IP
;             BC = Longitud
;    Salida:  DE = Checksum

TCP_CHKSUM:	;

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

PROTO_6:	db	0,6
CHK_TMP:	dw	0


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
	call	COMP16	;Compara HL' y DE'
	exx
	ret


;--- NOMBRE: COMP16
;      Comparacion de HL con DE (sin signo)
;    ENTRADA:   HL, DE = numeros a comparar
;    SALIDA:     C, NZ si HL > DE
;                C,  Z si HL = DE
;               NC, NZ si HL < DE
;    Modifica: A

COMP16:	call	_COMP16
	ccf
	ret

_COMP16:	ld	a,h
	sub	d
	ret	nz
	ld	a,l
	sub	e
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


;--- NOMBRE: SEND_DGRAM
;    Envia el datagrama que hay en BUFER_OUT (y su pseudocabecera IP
;    en BUFER_OUT-8) de tamanyo SEG_PEND_TSIZE.
;    Previamente establece su campo de checksum.

;--- SEND_DGRAMI: Como SEND_DGRAM, pero la llamada a NestorMan es indirecta.

SEND_DGRAMI:	ld	a,#FF
	jr	SEND_DGRAMX

SEND_DGRAM:	xor	a

SEND_DGRAMX:	ld	(NMAN_INDIR),a
	ld	a,(PROT_OUT_QUEUE)	;No hace nada si no conocemos
	or	a	;PROT_OUT_QUEUE (no hay conexion
	jr	z,SEND_DG_END	;a internet)

	ld	a,(SEG_PENDING)	;No hace nada si no hay paquete
	or	a
	ret	z

	ld	hl,0	;Calcula checksum
	ld	(BUFER_OUT+16),hl
	ld	ix,BUFER_OUT
	ld	bc,(SEG_PEND_TSIZE)
	push	bc
	ld	hl,LOCAL_IP
	ld	de,BUFER_OUT-8
	call	TCP_CHKSUM
	dec	de
	ld	a,e
	cpl
	ld	(BUFER_OUT+16),a
	ld	a,d
	cpl
	ld	(BUFER_OUT+17),a

	pop	hl	;Encola datagrama y termina
	ld	bc,8
	add	hl,bc
	ld	a,(#8002)
	ld	b,a
	ld	iy,BUFER_OUT-8
	set	7,h
	set	6,h
	ld	a,(PROT_OUT_QUEUE)
	ld	ix,(PROT_OUT_QUEUE+1)
	ld	c,28
	call	NESMAN

SEND_DG_END:	ld	a,0
	ld	(SEG_PENDING),a

	;ld      a,(FIN_SENT_FLAG)
	;or      a
	;ret     nz

	;ld      hl,BUFER_OUT+13  ;Hay FIN y no es ReTx?
	;_bit    FIN,(hl)
	;ld      hl,SND_NXT       ;Anyadido en 0.2
	;ld      bc,SND_NXT
	;call    nz,INC32

	;ld      hl,BUFER_OUT-8   ;*** PRUEBAS
	;ld      de,BUFER_OUT-7
	;ld      bc,535
	;ld      (hl),0
	;ldir

	ret


;--- DESTR_TCB_QUEUES: Destruye las colas del TCB que esta en TCB_CUR

DESTR_TCB_QUEUES:	ld	a,(DATA_IN_QUEUE)
	ld	ix,(DATA_IN_QUEUE+1)
	nesmani	22
	ld	a,(DATA_OUT_QUEUE)
	ld	ix,(DATA_OUT_QUEUE+1)
	nesmani	22
	;ld      a,(OOO_IN_QUEUE)
	;ld      ix,(OOO_IN_QUEUE+1)
	;nesmani 22
	ld	a,(RETX_QUEUE)
	ld	ix,(RETX_QUEUE+1)
	nesmani	22
	xor	a
	ld	hl,0
	ld	(DATA_IN_QUEUE),a
	ld	(DATA_IN_QUEUE+1),hl
	ld	(DATA_OUT_QUEUE),a
	ld	(DATA_OUT_QUEUE+1),hl
	;ld      (OOO_IN_QUEUE),a
	;ld      (OOO_IN_QUEUE+1),hl
	ld	(RETX_QUEUE),a
	ld	(RETX_QUEUE+1),hl
	ret


;--- PORT_IN_USE: Devuelve Cy=1 si el puerto local DE ya esta siendo usado
;                 en alguna conexion

PORT_IN_USE:	ld	a,(NUM_CON)	;No encontrado si no hay conexiones
	or	a
	ret	z

	ld	b,NUM_CON_MAX
	ld	hl,TCB_CON
PIU_LOOP:	push	bc
	ld	a,(hl)
	or	a
	jr	z,PIU_NEXT
	ld	bc,7
	add	hl,bc
	ld	a,(hl)
	cp	d
	jr	nz,PIU_NEXT
	inc	hl
	ld	a,(hl)
	cp	e
	jr	z,PIU_FND
PIU_NEXT:	push	de
	ld	de,TCB_SIZE-8
	add	hl,de
	pop	de
	pop	bc
	djnz	PIU_LOOP

	or	a	;No encontrado
	ret

PIU_FND:	pop	bc	;Encontrado
	scf
	ret


;--- CALL_LV2: Llama a una rutina del modulo de nivel 2
;    Entrada: IX = Direccion de la rutina

CALL_LV2:	push	af
	ld	a,(LV2_SEG)
CALL_LV2_IP	or	a
	jr	z,CALL_LOW_NO
	ld	iyh,a
	pop	af
	call	CAL_SEG
	ret
CALL_LOW_NO:	pop	af
	ret


;--- CALL_IP: Llama a una rutina del modulo de nivel 2
;    Entrada: IX = Direccion de la rutina

CALL_IP:	push	af
	ld	a,(IP_SEG)
	jr	CALL_LV2_IP


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


;--- SWAP_IO: Intercambia los contenidos de los dos bloques de memoria
;             de 15 bytes DATA_IN_QUEUE y DATA_OUT_QUEUE,
;             tambien intercambia SND_NXT y SEG_SEQ

SWAP_IO:	ld	hl,DATA_IN_QUEUE	;IN -> TEMP
	ld	de,SWAP_TEMP
	ld	bc,15
	ldir

	ld	hl,DATA_OUT_QUEUE
	ld	de,DATA_IN_QUEUE	;OUT -> IN
	ld	bc,15
	ldir

	ld	hl,SWAP_TEMP	;TEMP -> OUT
	ld	de,DATA_OUT_QUEUE
	ld	bc,15
	ldir

	ld	hl,(SEG_SEQ)
	push	hl
	ld	hl,(SEG_SEQ+2)
	push	hl
	ld	hl,SND_NXT
	ld	de,SEG_SEQ
	copy32
	pop	hl
	ld	(SND_NXT+2),hl
	pop	hl
	ld	(SND_NXT),hl

	ret

SWAP_TEMP:	equ	#C000-16


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



;*************************************
;**                                 **
;**   CONSTANTES DE CONFIGURACION   **
;**                                 **
;*************************************

CONS_START:	;

;Tamanyo declarado del bufer de recepcion por defecto
DEF_RCV_BUF:	dw	16100

;El puerto 9 actua como servidor de eco o no
ECHO_SERVER:	db	#FF

CONS_END:	;

CONS_DEF_VAL:	dw	16100
	db	#FF


;************************************
;**                                **
;**   VARIABLES DE CONFIGURACION   **
;**                                **
;************************************

VAR_START:	;

;Variable puesta a #FF cuando se va a desinicializar
DEINITING:	db	0

;IP local (se pregunta al modulo IP)
LOCAL_IP:	ds	4

;Numero de conexiones abiertas
NUM_CON:	db	0

;Conexion en curso (su TCB esta en TCB_CUR)
CUR_CON:	db	0

;Valor de CHK_TLU devuelto por el nivel 2 en la anterior interrupcion
LOWER_STATUS:	db	0

;Bandera que indica si hay un segmento a medio componer en BUFER_OUT (si #FF)
SEG_PENDING:	db	0

;Tamanyo actual del segmento a medio componer de BUFER_OUT
;(no incluye la pseudo-cabecera IP)
SEG_PEND_TSIZE:	dw	0

;Tamanyo actual de la cabecera TCP del segmento a medio componer de BUFER_OUT
SEG_PEND_HSIZE:	db	0

;Tamanyo actual de la parte de datos del seg. en BUFER_OUT
SEG_PEND_DSIZE:	dw	0

;Conexion del paquete que hay en BUFER_OUT si SEG_PENDING=#FF
SEG_PEND_CON:	db	0

;Tamanyo del ultimo segmento recibido (solo datos)
SEG_DLEN:	dw	0

;Tamanyo de la cabecera TCP del ultimo segmento recibido
SEG_HLEN:	db	0

;Tamanyo del ultimo segmento recibido (total)
SEG_TLEN:	dw	0

;Tamanyo de ventana anunciado en el ultimo segmento recibido
SEG_WND:	dw	0

;Campos del ultimo segmento recibido
SEG_SEQ:	ds	4
SEG_ACK:	ds	4
SEG_UP:	dw	0

;Ultimo puerto local usado
LAST_LOC_PORT:	dw	1023

;MRU y MTU (preguntados al modulo de nivel 2)
MRU:	dw	0
MTU:	dw	0

;Direcciones de las colas externas
PROT_OUT_QUEUE:	ds	3	;Cola de salida
TCP_IN_QUEUE:	ds	3	;Cola de entrada para TCP
UDP_IN_QUEUE:	ds	3	;Cola de entrada para UDP

;Segmentos de los modulos IP y nivel 2
IP_SEG:	db	0
LV2_SEG:	db	0

;Conexion examinada para enviar un segmento en la anterior interrupcion
LAST_USED_CON:	db	0

;Puntero al TCB de LAST_USED_CON
LAST_USED_TCB:	dw	0

;Nivel de ejecucion permitido para la rutina de atencion a la interrupcion:
;0: Puede ejecutarse completamente, es decir, actualizar los temporizadores
;   y enviar/recibir paquetes (modo normal o ejecucion de STATUS)
;1: Puede ejecutar solo la parte 3, es decir, actualizar los temporizadores
;   pero no recibir/enviar paquetes (cuando se esta haciendo un SEND o RECEIVE)
;2: No puede ejecutarse (cuando se esta haciendo un OPEN, CLOSE o ABORT)
INT_LEVEL:	db	0

;Conexion en TCB_CUR antes de la interrupcion en curso
PREV_CON:	db	0

;Variables temporales
TEMP_SEQ:	ds	4
TEMP_SEQ2:	ds	4
TEMP_SEQ3:	ds	4
TEMP_SEQ4:	ds	4

;Bandera usada al comprobar un paquete entrante
INT4_STEP:	db	0

;Bandera activada cuando estamos tratando datos entrantes
;del servidor de eco
ECHO_NOW:	db	0

;Temporizador para seleccionar el ISS
ISS_T:	dw	0

;Bandera que indica que se esta cargando un TCB si #FF
LOADING_CON:	db	0

VAR_END:	;



;**************
;**          **
;**   TCBs   **
;**          **
;**************

;Primero esta el TCB de la conexion en curso (TCB_CUR).
;Despues hay NUM_CON_MAX buferes iguales para cada conexion (TCB_CON).
;El TCB de la conexion en curso se copia de TCB_CON a TCB_CUR
;cuando la conexion va a ser usada, y despues se copia a TCB_CON otra vez.

;--- TCB de la conexion en curso

TCB_CUR:

;Estado actual de la conexion (0=CLOSED=el TCB no esta en uso)
CUR_STATE:	db	0

;Direccion IP remota conectada
REMOTE_IP:	ds	4

;Puerto remoto conectado (guardado en big-endian)
REMOTE_PORT:	ds	2

;Puerto local conectado (guardado en big-endian)
LOCAL_PORT:	ds	2

;Apertura activa (0) o pasiva (#FF)
PASSIVE_OPEN:	db	0

;Primer numero de secuencia no ACKeado
SND_UNA:	ds	4

;Proximo numero de secuencia a enviar
SND_NXT:	ds	4

;Ventana de emision anunciada
SND_WND:	dw	0

;Maximo valor recibido de SND_WND
MAX_SNDW:	ds	4

;Ventana de congestion
CWND:	dw	0

;Umbral de ventana de congestion
SSTHRESH:	dw	0

;Bandera que indica si estamos en Slow Start (0) o en Congestion Avoidance (#FF)
CONG_AVO:	db	0

;Numero de bytes ACKeados nuevos para Slow Start/Congestion Avoidance
SS_CA_NEWACK:	dw	0

;Numero de ACKs duplicados recibidos
DUP_ACKS:	db	0

;Numero de bytes enviados pero no ACKeados aun
FLIGHT_SIZE:	dw	0

;Temporizador de conexion "idle"
IDLE_T:	dw	0

;Primer numero de secuencia de datos urgentes a enviar
SND_URG_FIRST:	ds	4

;Ultimo numero de secuencia de datos urgentes a enviar
SND_URG_LAST:	ds	4

;Numero de datos urgentes por enviar
SND_URG_SIZE:	dw	0

;Numero de secuencia usado para la ultima actualizacion de la ventana
SND_WL1:	ds	4

;Numero de ACK usado para la ultima actualizacion de la ventana
SND_WL2:	ds	4

;Numero de secuencia de envio inicial
ISS:	ds	4

;Proximo numero de secuencia esperado
RCV_NXT:	ds	4

;Ventana de recepcion
RCV_WND:	ds	4

;Ventana usable
USABLE_W:	ds	4

;Bandera de datos urgentes en la cola de entrada
RCV_URG:	db	0

;Ultimo numero de secuencia de los datos recibidos urgentes
RCV_URG_LAST:	ds	4

;Numero de secuencia de recepcion inicial
IRS:	ds	4

;Maximo tamanyo de segmento anunciado por el otro extremo (defecto: 536)
SMSS:	dw	536
SMSS2:	dw	536*2

;SMSS efectivo
EFF_SMSS:	dw	0

;Maximo tamanyo de segmento local (defecto: MRU-40)
RMSS:	dw	0

;Temporizador TIME-WAIT
TWAIT_T:	dw	0

;Temporizador de retransmisiones excesivas
;Esta activo mientras queden datos a ReTx, se inicializa
;cuando llega un ACK de datos nuevos
RETX_EX_T:	dw	0

;Valor maximo permitido para RETX_EX_T antes de cortar la conexion
RETX_EX_MAX:	dw	5000	;defecto: 100 seg

;Valor maximo permitido para RETX_EX_T antes de cortar la conexion
;en el caso de que se haya enviado un SYN
RETX_EX_SMAX:	dw	10000	;defecto: 3 minutos

;Time out de usuario (por defecto 5 minutos)
USER_TOUT_V:	dw	15000

;Contador del time out de usuario
;Se inicializa y activa al enviar datos nuevos, se detiene
;cuando ya no quedan datos para ReTx
USER_TOUT_T:	dw	0

;Byte TOS para los datagramas a enviar (por defecto 0)
SEND_TOS:	db	0

;Ultimo codigo de error (primario y secundario)
;0: conexion nunca usada
;1: conexion abortada
;   0: por el usuario
;   1: ha llegado un RST
;2: ha llegado un ICMP (su codigo esta en LAST_ERR_S)
;3: conexion cerrada por el usuario

LAST_ERR_P:	db	0
LAST_ERR_S:	db	0

;Bandera de datos PUSHeados
SEND_PUSH:	db	0

;Ultimo numero de secuencia de los datos PUSHeados para enviar
SEND_PUSH_LAST:	ds	4

;Bandera de datos urgentes a enviar
SEND_URG:	db	0

;Ultimo numero de secuencia de los datos urgentes para enviar
SEND_URG_LAST:	ds	4

;Tamanyo del bufer de recepcion (por defecto 16K)
RCV_BUF:	dw	16100
RCV_BUF2:	dw	8050	;Lo mismo /2 (para calcular la ventana)

;"Override timeout" para enviar datos PUSHed (por defecto 0.5 seg)
OVERR_TOUT_V:	db	25

;Temporizador de control del "override timeout"
OVERR_T:	db	0

;Bandera que indica si se ha enviado un SYN si #FF
;(se pone a 0 cuando su numero de secuencia se ACKea)
SYN_SENT_FLAG:	db	0

;Numero de secuencia del SYN enviado
SYN_SENT_SEQ:	ds	4

;Bandera que indica si se ha enviado un FIN si #FF
;(se pone a 0 cuando su numero de secuencia se ACKea)
FIN_SENT_FLAG:	db	0

;Numero de secuencia del FIN enviado
FIN_SENT_SEQ:	ds	4

;Cola de retransmision: puntero, primer num. sec., ultimo num. sec., tamanyo
RETX_QUEUE:	ds	3
RETX_FIRST:	ds	4
RETX_LAST:	ds	4
RETX_SIZE:	ds	4

;Cola de entrada: puntero, primer num. sec., ultimo num. sec., tamanyo
DATA_IN_QUEUE:	ds	3
DATA_IN_FIRST:	ds	4
DATA_IN_LAST:	ds	4
DATA_IN_SIZE:	ds	4

;Cola de salida: puntero, primer num. sec., ultimo num. sec., tamanyo
DATA_OUT_QUEUE:	ds	3
DATA_OUT_FIRST:	ds	4
DATA_OUT_LAST:	ds	4
DATA_OUT_SIZE:	ds	4

;Maximo retardo para enviar un ACK (maximo y defecto: 0.5 seg = 25 int)
ACK_DELAY_MAX:	db	25

;Maximo de datos llegados para enviar un ACK (defecto: 2*SMSS)
ACK_RCV_MAX:	dw	0

;Bandera que indica si hay un ACK retrasado (si #FF)
ACK_DELAYED:	db	0

;Numero de bytes a ACKear que hay acumulados
ACK_RCV_NUM:	dw	0

;Temporizador de retraso del ACK
ACK_DELAY_T:	db	0

;Retransmission Time Out (inicial: 3 seg)
RTO:	dw	150

;Temporizador de RTO
RTO_T:	dw	0

;Bandera que indica si el RTO esta funcionando (si #FF)
RTO_RUN:	db	0

;Temporizador que activa la medida de RTT cuando llega a cero
RTT_M_T:	dw	0

;Ultimo Round Trip Time medido
RTT:	dw	0

;Variable que controla la medida del RTT:
;0: No hay que medir RTT
;1: Hay que medir RTT cuando se envie un segmento
;2: Se esta midiendo el RTT
RTT_M_ON:	db	0

;Temporizador usado para medir el RTT
RTT_M_CUR:	dw	0

;Numero de secuencia cuyo RTT se esta midiendo
RTT_M_SEQ:	ds	4	;Era dw 0 en 0.2!!!

;Smoothed Round Trip Time para calcular RTO
SRTT:	dw	0

;Varianza del RTT
RTTVAR:	dw	0

;Valor maximo del RTO (defecto: 60 seg)
RTO_MAX:	dw	3000

;Algoritmo de Nagle activo (#FF) o no (0) (defecto: #FF)
NAGLE_ON:	db	#FF

;Bandera que indica que se ha pedido cierre de conexion
;pero aun hay datos pendientes para enviar, si #FF
CLOSE_PENDING:	db	0

;Bandera que indica que hay que retransmitir datos en la
;proxima interrupcion en la que tengamos permiso para enviar un paquete
RETX_PEND:	db	0

;Contador 2*MSL para el estado TIME-WAIT
MSL_T:	dw	0

;Flag que indica que se ha actualizado la ventana de recepcion
;y por tanto hay que enviar un ACK
RWND_UPD_FLAG:	db	0

;Flag que indica que se ha de actualizar la ventana de recepcion
;(se pone a #FF cuando llegan datos nuevos y cuando se recogen)
UPWND_PEND:	db	0

;MSL para el estado TIME-WAIT (defecto: MSL_T_MAX)
MSL_T_CUR:	dw	0

;Ultimo numero de secuencia con PUSH en la cola de ReTx
LAST_RETX_PUSH:	ds	4

;Ultimo numero de secuencia con URG en la cola de ReTx
LAST_RETX_URG:	ds	4

;Temporizador para enviar ACKs para probar ventana cero
PROBE_ZW_V:	dw	0
PROBE_ZW_T:	dw	0

;Ultimo ACK recibido, para comprobar duplicados
LAST_RCVD_ACK:	ds	4

;#FF si estamos en Fast recovery
FAST_RECOV_FLAG:	db	0

;Ultimo valor usado para RTO
LAST_USED_RTO:	dw	0

TCB_CUR_END:

TCB_SIZE:	equ	TCB_CUR_END-TCB_CUR


;--- NUM_CON_MAX TCBs para cada conexion

TCB_CON:	;



;*******************
;***             ***
;***   BUFERES   ***
;***             ***
;*******************

BUFERS:	equ	TCB_CON+NUM_CON_MAX*TCB_SIZE

BUFER_IN:	equ	#A800	;BUFERS+1
BUFER_OUT:	equ	#B000	;BUFER_IN+2100
BUFER_GEN:	equ	#B800	;BUFER_OUT+2100   ;Bufer generico
