; Original ObsoNET BIOS 1.0.

; Set GEN_DAT to 0 to generate a padded 16K ROM,
; set to 0 to generate the barebones 1.5K DAT file.

;==================================================

;--- BOOT y BIOS ROM para ObsoNET
;    Por Konami Man, 7-2004
;
;    Se usa la pila para variables temporales,
;    no se usa la zona de trabajo del sistema.
;    El numero de pagina SRAM del RTL para la proxima extraccion
;    de un paquete recibido se almacena en #45FF
;    de la propia SRAM.


;*****************************
;***  Macros y constantes  ***
;*****************************

;*** MANUAL_MAC=1 para establecer la MAC a mano,
;               0 para leerla de la EEPROM

MANUAL_MAC:	equ	0

MANUAL_MAC0:	equ	#58	;"X"
MANUAL_MAC1:	equ	#53	;"S"
MANUAL_MAC2:	equ	#4D	;"M"
MANUAL_MAC3:	equ	0
MANUAL_MAC4:	equ	0
MANUAL_MAC5:	equ	1

;*** GEN_DAT debe ser 1 para generar el fichero DAT de 1.5K,
;    o bien 0 para generar el fichero ROM de 16K

GEN_DAT:	equ	0

;*** Numero de entradas en la tabla de salto
;    (mantener actualizado!!)

JMP_CNT:	equ	11

;*** Version de la ROM

VER_P:	equ	1
VER_S:	equ	0
VER_R:	equ	0

;*** Variables del sistema

EXPTBL:	EQU	#FCC1	;Tabla de info sobre slots expandidos
SLTWRK:	equ	#FD09	;Zona de trabajo para cada slot
CHPUT:	equ	#00A2	;Rutina MSX-BIOS para imprimir un caracter

;*** Direccion base de los registros del RTL

RTL_REGS:      equ     #7FE0

;*** Paginas inicial y final para recepcion
;    de paquetes, y pagina final para el envio,
;    en la SRAM del RTL (1 pagina=256 bytes).
;    La SRAM esta mapeada en la direccion
;    #4000 del RTL.

TX_FIRSTP:	equ	#40	;Debe apuntar a un bufer de 6 paginas (1.5K)
RX_FIRSTP:	equ	#46
RX_LASTP:	equ	#60


;---------------------------------
;---  Registros del RTL8019AS  ---
;---------------------------------

;*** Todos los bancos

CR:	equ	0
DMA_PORT:	equ	#10
RESET_PORT:	equ	#18

;*** Banco 0

CLDA0:	equ	1	;R
PSTART:	equ	1	;W
CLDA1:	equ	2	;R
PSTOP:	equ	2	;W
BNRY:	equ	3	;R/W
TSR:	equ	4	;R
TPSR:	equ	4	;W
NCR:	equ	5	;R
TBCR0:	equ	5	;W
FIFO:	equ	6	;R
TBCR1:	equ	6	;W
ISR:	equ	7	;R/W
CRDA0:	equ	8	;R
RSAR0:	equ	8	;W
CRDA1:	equ	9	;R
RSAR1:	equ	9	;W
R8019ID0:	equ	#A	;R
RBCR0:	equ	#A	;W
R8019ID1:	equ	#B	;R
RBCR1:	equ	#B	;W
RSR:	equ	#C	;R
RCR:	equ	#C	;W
CNTR0:	equ	#D	;R
TCR:	equ	#D	;W
CNTR1:	equ	#E	;R
DCR:	equ	#E	;W
CNTR2:	equ	#F	;R
IMR:	equ	#F	;W

;*** Banco 1 (todos R/W)

PAR0:	equ	1
PAR1:	equ	2
PAR2:	equ	3
PAR3:	equ	4
PAR4:	equ	5
PAR5:	equ	6
CURR:	equ	7
MAR0:	equ	8
MAR1:	equ	9
MAR2:	equ	#A
MAR3:	equ	#B
MAR4:	equ	#C
MAR5:	equ	#D
MAR6:	equ	#E
MAR7:	equ	#F

;*** Banco 2 (todos R)
;    Tambien estan en el banco 0, pero en modo W

;PSTART:           equ     1
;PSTOP:            equ     2
;TPSR:             equ     4
;RCR:              equ     #C
;TCR:              equ     #D
;DCR:              equ     #E
;IMR:              equ     #F

;*** Banco 3

R9346CR:	equ	1	;R/W
BPAGE:	equ	2	;R/W
CONFIG0:	equ	3	;R
CONFIG1:	equ	4	;R/W
CONFIG2:	equ	5	;R/W
CONFIG3:	equ	6	;R/W
TEST:	equ	7	;W
CSNSAV:	equ	8	;R
HLTCLK:	equ	9	;W
INTR:	equ	#B	;R
FMWP:	equ	#C	;W
CONFIG4:	equ	#D	;R


;-----------------------------------------------
;---  Macros para leer y escribir registros  ---
;-----------------------------------------------

;Suponen que la direccion base esta en IX

rreg:	macro	@d,@r
	ld	@d,(ix+@r)
	endm

wreg:	macro	@r,@d
	ld	(ix+@r),@d
	endm

;* Seleccion de banco

selbank:	macro	@b
	ld	(ix),@b*64+%00100000
	endm

;* Seleccion de banco, activando el RTL

rtlstart:	macro	@b
	ld	(ix),@b*64+%00100010
	endm

;* Seleccion de banco, deteniendo el RTL

rtlstop:	macro	@b
	ld	(ix),@b*64+%00100001
	endm


;**************************
;***  Cabecera ROM MSX  ***
;**************************

	if	GEN_DAT=0

	org	#4000

	db	#41,#42
	dw	INIT	;Esta rutina debe llamar a RTL_RESET
	dw	0	;Statement
	dw	0	;Device
	dw	0	;Text
	ds	6	;Reserved

	;*** Espacio vacio hasta las rutinas

HEAD_END:	ds	#7A00-HEAD_END,#FF

	endif

	if	GEN_DAT=1

	org	#7A00

	endif

	;>>> Sea cual sea el valor de GEN_DAT, el csdigo
	;    a partir de aqum se ensambla en #7A00.


;**********************
;***  Rutinas BIOS  ***
;**********************

;* Todas estas rutinas se pueden ensamblar en cualquier direccion;
;  la BIOS funcionara mientras la tabla de salto este en su sitio.


;==================
;===  Arranque  ===
;==================

INIT:	ld	hl,INITMSG
INIT_LOOP:	ld	a,(hl)
	or	a
	jp	z,RTL_RESET
	call	CHPUT
	inc	hl
	jr	INIT_LOOP

INITMSG:
               db      13,10,"ObsoNET card BIOS 1.0",13,10
	db	"(c) 2004",13,10
	db	"Daniel Berdugo (hardware)",13,10
	db	"Nestor Soriano (BIOS)",13,10
	db	13,10
	db	0


;================================
;===  Inicializacion del RTL  ===
;================================

;Entrada: -
;Salida:  -

RTL_RESET:	call	STACKALLOC
	ld	ix,RTL_REGS

	;--- Lee y escribe el registro RESET

	rreg	a,RESET_PORT
	call	WAIT
	wreg	RESET_PORT,a

	;--- Envia comando stop y espera a que termine la Tx pendiente

	rtlstop	0
	call	WAIT

	;--- Programa CONFIG1 a CONFIG4

	wreg	R9346CR,#C0	;Habilita escritura en CONFIGX

	wreg	CONFIG1,#90
	wreg	CONFIG2,0
	wreg	CONFIG3,#30
	wreg	CONFIG4,0

	wreg	R9346CR,0

	;--- Establece longitud de transferencia DMA a cero

	wreg	RBCR1,0
	wreg	RBCR0,0

	;--- Pone el dispositivo en modo monitor y loopback,
	;    establece modo de transferencia por bytes

	wreg	RCR,%00100000
	wreg	TCR,%0000 01 00

	wreg	DCR,%0 10 0 1 000	;Fifo TH=%10, normal op, bytes

	;--- Lee la direccion MAC desde el 9346 y la guarda en la zona de trabajo.
	;    Para ello hay que leer 12 bytes de la direccion 0 del RTL
	;    y quedarse solo con los pares.

	if	MANUAL_MAC=0

	rtlstart	0

	wreg	RBCR0,12	;Long. dir. ethernet * 2
	wreg	RBCR1,0

	wreg	RSAR0,0	;Direccion de lectura
	wreg	RSAR1,0

	wreg	CR,%00 001 0 10	;Iniciar lectura

	rreg	a,DMA_PORT	;Guarda los bytes pares
	ld	(iy),a
	rreg	a,DMA_PORT
	rreg	a,DMA_PORT
	ld	(iy+1),a
	rreg	a,DMA_PORT
	rreg	a,DMA_PORT
	ld	(iy+2),a
	rreg	a,DMA_PORT
	rreg	a,DMA_PORT
	ld	(iy+3),a
	rreg	a,DMA_PORT
	rreg	a,DMA_PORT
	ld	(iy+4),a
	rreg	a,DMA_PORT
	rreg	a,DMA_PORT
	ld	(iy+5),a
	rreg	a,DMA_PORT

	wreg	CR,%00 100 0 10	;Fin lectura

	endif

	if	MANUAL_MAC=1

	ld	(iy),MANUAL_MAC0
	ld	(iy+1),MANUAL_MAC1
	ld	(iy+2),MANUAL_MAC2
	ld	(iy+3),MANUAL_MAC3
	ld	(iy+4),MANUAL_MAC4
	ld	(iy+5),MANUAL_MAC5

	endif

	;--- Establece parametros de buffer

	rtlstart	0

	wreg	PSTART,RX_FIRSTP
	wreg	BNRY,RX_FIRSTP
	wreg	PSTOP,RX_LASTP

	;--- Limpia y deshabilita las interrupciones

	wreg	ISR,#FF
	wreg	IMR,0

	;--- Guarda la dir MAC en los registros del RTL

	selbank	1

	ld	de,RTL_REGS+PAR0
	push	iy
	pop	hl
	ld	bc,6
	ldir

	;--- Establece la mascara de multicasts como todo unos

	rtlstop	1

	wreg	MAR0,#FF
	wreg	MAR1,#FF
	wreg	MAR2,#FF
	wreg	MAR3,#FF
	wreg	MAR4,#FF
	wreg	MAR5,#FF
	wreg	MAR6,#FF
	wreg	MAR7,#FF

	rtlstart	0

	;--- Inicializa el puntero del bufer de recepcion

	rtlstop	1

	wreg	CURR,RX_FIRSTP+1

	rtlstart	0

	;--- Establece el transmisor en modo normal

	wreg	TCR,0

	;--- Establece el receptor en modo normal:
	;    Aceptar broadcast y <64 bytes, rechazar multicast y erroneos

	wreg	RCR,%00000110

	;--- Inicializa puntero al proximo paquete,
	;    limpia interrupciones pendientes y termina

	;ld	(iy+7),RX_FIRSTP+1
	ld	a,RX_FIRSTP+1
	call	SET_PAQ_PNT
	wreg	ISR,#FF

	call	STACKFREE
	ret


;===========================================
;===  Obtencion de la version de la ROM  ===
;===========================================

;Entrada: -
;Salida:  Version en A.B.C

GET_VERS:	ld	a,VER_P
	ld	b,VER_S
	ld	c,VER_R
	ret


;============================================
;===  Obtencion de la direccion Ethernet  ===
;============================================

;Entrada: -
;Salida:  L-H-E-D-C-B = Direccion Ethernet local

GET_HWAD:	ld	ix,RTL_REGS

	selbank	1

	rreg	l,PAR0
	rreg	h,PAR1
	rreg	e,PAR2
	rreg	d,PAR3
	rreg	c,PAR4
	rreg	b,PAR5

	ret


;========================================
;===  Obtencion del estado de la red  ===
;========================================

;Entrada: -
;Salida:  A=0 si no hay red, 1 si hay

;We perform loopback mode 3 to test the cable connection status.
; set RCR=00h to accept physical packet (#20 para modo monitor??)
; set PAR0-5 to accept packet
; set TCR=06h (CRC enabled)
; set DCR=40h (8-bit slot) or 43h (16-bit slot)
; clear ISR
; tx a packet
; check TSR after loopback: 3=OK

;Pues vamos a ello...

GET_NETSTAT:	ld	ix,RTL_REGS

	;--- Espera a que termine la Tx en curso

	selbank	0

W_NETSTAT:	rreg	a,CR
	and	%100
	jr	nz,W_NETSTAT

	;--- Guarda el estado de los registros

	selbank	2
	rreg	d,RCR
	rreg	b,TCR
	rreg	c,DCR
	push	de,bc

	;--- Establece los registros como dice esta gente

	selbank	0
	wreg	RCR,%00011111	;Aceptar todos los paquetes
	wreg	TCR,6
	wreg	DCR,#60
	wreg	ISR,#FF

	;--- Establece temporalmente la MAC como todo AAs

	;call    GET_HWAD         ;Primero guarda la MAC actual
	;push    hl,de,bc

	;selbank 1
	;wreg    PAR0,#AA
	;wreg    PAR1,#AA
	;wreg    PAR2,#AA
	;wreg    PAR3,#AA
	;wreg    PAR4,#AA
	;wreg    PAR5,#AA

	;--- Envia un paquete de prueba

	ld	hl,PPAQ
	ld	bc,PPAQ_END-PPAQ
	xor	a
	call	SEND_PACKET
	ld	ix,RTL_REGS

	;--- Reestablece la MAC

	;pop     bc,de,hl
	;push    af
	;selbank 1
	;wreg    PAR0,l
	;wreg    PAR1,h
	;wreg    PAR2,e
	;wreg    PAR3,d
	;wreg    PAR4,c
	;wreg    PAR5,b
	;pop     af

	;--- Reestablece los registros modificados

	selbank	0
	pop	bc,de
	wreg	RCR,d
	wreg	TCR,b
	wreg	DCR,c
	wreg	ISR,#FF

	;--- Devuelve 0 o 1 segun si el paquete
	;    se envio bien o no

	selbank	0
	rreg	a,TSR

	cp	#43
	ld	a,1
	ret	z
	xor	a
	ret

	;and     #0F
	;cp      3
	;ld      a,1
	;ret     z
	;xor     a
	;ret

	;--- Paquete de prueba

PPAQ:	ds	12,#AA	;Origen y destino: todo ceros
	db	#FF,#FF	;Ether-Type falso
	ds	46,#34	;46 bytes de datos "aleatorios"
PPAQ_END:


;================================================
;===  Activacion/desactivacion de la tarjeta  ===
;================================================

;Entrada: A=0: Obtener estado
;           1: Activar
;           2: Desactivar
;Salida:  A=Estado (1=Activada, 2=Desactivada)

CARD_ONOFF:	ld	ix,RTL_REGS

	or	a
	jr	z,CONOFF_STAT

	cpl
	and	%11
	ld	b,a
	rreg	a,CR
	and	%11000000
	or	b
	wreg	CR,a

CONOFF_STAT:	rreg	a,CR
	and	1
	inc	a
	ret


;=======================================
;===  Configuracion de la recepcion  ===
;=======================================

;Entrada: A=#80: Solo obtener configuracion. Si no:
;           Bit 4: Aceptar todas las direcciones de destino
;           Bit 3: Aceptar paquetes multicast
;           Bit 2: Aceptar paquetes broadcast
;           Bit 1: Aceptar paquetes <64 bytes
;Salida:  A=Estado

CONF_RX:	ld	ix,RTL_REGS

	bit	7,a
	jr	nz,CONF_RX_GET

	selbank	0
	and	%00011110
	wreg	RCR,a

CONF_RX_GET:	selbank	2
	rreg	a,RCR
	and	%00011110
	selbank	0
	ret


;==================================================
;===  Configuracion de la mascara de multicast  ===
;==================================================

;Entrada: Cy=0 para obtener
;            1 para establecer
;Salida:  HL = Direccion para obtener o escribir la mascara de multicast

CONF_MCAST:	ld	ix,RTL_REGS

	jr	nc,CMCAST_GET
	push	hl
	rreg	a,CR
	rtlstop	1
	ld	de,RTL_REGS+MAR0
	ld	bc,8
	ldir
	pop	hl

	bit	1,a
	jr	z,CMCAST_START

CMCAST_STOP:	rtlstop	1
	jr	CMCAST_GET

CMCAST_START:	rtlstart	1

CMCAST_GET:	selbank	1
	ex	de,hl
	ld	hl,RTL_REGS+MAR0
	ld	bc,8
	ldir

	ret


;============================================
;===  Estado de la recepcion de paquetes  ===
;============================================

;Entrada: -
;Salida:  A=0 si no hay paquetes pendientes, 1 si hay
;         BC=Longitud del paquete pendiente
;         HL=Bytes 12 y 13 del paquete
;            (Ether Type o longitud)
;
;         Ademas, el siguiente parametro, no documentado:
;         D=Puntero al siguiente paquete, si hay paquetes pendientes

GET_INSTAT:	call	STACKALLOC
	ld	ix,RTL_REGS
	call	GET_INSTAT2
	selbank	0
	call	STACKFREE
	ret

GET_INSTAT2:	ld	a,32
GET_INSTAT3:	ld	(iy+3),a

	;--- Comprueba que haya paquetes en el buffer,
	;    comparando el puntero de proximo paquete
	;    con el registro CURR

	selbank	0
	call	GET_PAQ_PNT
	ld	e,a
	;ld	a,(iy+7)
	selbank	1
	rreg	h,CURR
	cp	h
	ld	a,0
	ld	bc,0
	ret	z

	;--- Hay paquetes.
	;    Lee el estado, el puntero a proximo paquete
	;    y la longitud del paquete.
	;    Tambien lee la posicion +12 del paquete,
	;    para poder distinguir si es Eth2 o IEEE 802.

	ld	a,e
	;ld	a,(iy+7)

	selbank	0
	wreg	RBCR1,0
	wreg	RBCR0,4+14	;Transmitimos 18 bytes
	wreg	RSAR1,a
	wreg	RSAR0,0	;Dir inicial de Tx

	wreg	CR,%00 001 0 10	;Inicio de la transferencia

	rreg	a,DMA_PORT	;Estado del paquete
	rreg	d,DMA_PORT	;Puntero al siguiente
	rreg	c,DMA_PORT	;Longitud de la trama
	rreg	b,DMA_PORT

	push	bc	;Se salta las direcciones
	ld	b,12
SKIP_HDR:	rreg	h,DMA_PORT
	djnz	SKIP_HDR
	pop	bc

	rreg	h,DMA_PORT	;Lee el campo que sera el Ether Type
	rreg	l,DMA_PORT	;o bien la longitud

	wreg	CR,%00 100 0 10	;Fin de la transferencia

	;> En este punto:
	;  A=Estado paquete
	;  D=Puntero a siguiente
	;  BC=Longitud
	;  HL=EtherType/Longitud

	;--- Comprueba que el puntero al siguiente este en el rango valido
	;    (entre #46 y #60 inclusive). Si no, borra todo el bufer de entrada
	;    y termina.

	ld	e,a
	ld	a,d
	cp	RX_FIRSTP
	jr	c,CHKIN_BADPNT
	cp	RX_LASTP
	jr	c,CHKIN_OKPNT

CHKIN_BADPNT:	selbank	1
	wreg	CURR,RX_FIRSTP+1
	selbank	0
	wreg	PSTART,RX_FIRSTP
	wreg	BNRY,RX_FIRSTP
	ld	a,RX_FIRSTP+1
	call	SET_PAQ_PNT
	;ld     (iy+7),RX_FIRSTP+1

	xor	a
	ret
CHKIN_OKPNT:

	;--- Comprueba que el estado del paquete sea OK,
	;    si no lo es, se salta el paquete y vuelve a empezar

	bit	0,e
	jr	nz,CHKIN_OKPAQ

	selbank	0
	ld	a,d
	call	SET_PAQ_PNT
	;ld     (iy+7),d

	ld	a,(iy+3)
	dec	a
	jp	nz,GET_INSTAT3	;Para no entrar en un bucle infinito
	jr	CHKIN_BADPNT

	;--- Puntero correcto

CHKIN_OKPAQ:	ld	a,1
	ret


;=================================
;===  Obtencion de un paquete  ===
;=================================

;Entrada: HL = Direccion para el paquete, 0 para descartarlo
;Salida:  A = 0 si se ha obtenido o descartado el paquete
;             1 si no habia paquetes pendientes
;         BC = Longitud del paquete se se ha recogido

;       Usa variables:
;       iy:   Direccion de destino
;       iy+2: Estado de ISR (para comprobar overflow)
;       iy+3: Usado por GET_INSTAT, a la que llamamos
;       iy+4: Estado de TCR (para poner/quitar loopback)
;       iy+5: Puntero al prox. paquete        

GET_PACKET:	call	STACKALLOC
	ld	ix,RTL_REGS

	ld	(iy),l
	ld	(iy+1),h

	;--- Comprueba si hay indicacion de desbordamiento de bufer

	selbank	0

	rreg	a,ISR
	ld	(iy+2),a	;indicacion de overflow
	and	%00010000
	jr	z,GETP_NOOVF

	;> Tratamiento del desbordamiento de bufer

	;--- Detiene el dispositivo y espera a que termine
	;    una posible Tx de un paquete

	;rreg	a,CR
	;ld	(iy+3),a	;Guarda el estado de CR
	rreg	a,TCR
	ld	(iy+4),a	;Guarda TCR

	rtlstop	0
	call	WAIT

	;--- Establece la longitud de la Tx a 0

	wreg	RBCR1,0
	wreg	RBCR0,0

	;--- Pone el dispositivo en modo loopback y lo reinicia

	wreg	TCR,%00000 01 0	;Modo loopback interno
	rtlstart	0

	;> Fin del tratamiento inicial de desbordamiento de bufer

	;--- Comprueba si se puede leer un paquete

GETP_NOOVF:	call	GET_INSTAT2
	ld	(iy+5),d	;Puntero al proximo paquete si lo hay
	or	a
	;ld      bc,0
	ld	a,1
	jr	z,GETP_END	;No hay paquete a recibir

	;* En este punto hay un paquete correcto a obtener,
	;  y tenemos su longitud en BC

GETP_GETP:	ld	e,(iy)
	ld	d,(iy+1)

	ld	a,d
	or	e
	jr	z,GETP_DESC	;Descartar paquete?

	selbank	0
	call	GET_PAQ_PNT
	ld	h,a
	;ld	h,(iy+7)

	push	bc
	call	READ_PACK
	pop	bc

GETP_DESC:
	ld	a,(iy+5)
	selbank	0
	call	SET_PAQ_PNT
	;ld     (iy+7),a         ;Actualiza puntero a siguiente
	xor	a

GETP_END:

	;--- Transmision completada, o paquete descartado,
	;    o bufer vaciado; A y BC ya estan tal como
	;    se deben devolver

	push	af,bc

	;* Actualiza BNRY

	selbank	0
	call	GET_PAQ_PNT
	;ld	a,(iy+7)
	dec	a
	cp	RX_FIRSTP
	jr	nc,GETP_OKBNRY
	ld	a,RX_LASTP-1
GETP_OKBNRY:	wreg	BNRY,a

	;* Si no habia bufer overflow, ya podemos terminar

	ld	a,(iy+2)
	and	%00010000
	jr	z,GETP_END2

	;* Borra la indicacion de buffer overflow

	ld	a,%00010000
	wreg	ISR,a

	;* Deshabilita modo loopback

	ld	a,(iy+4)
	wreg	TCR,a

	;* Si se detuvo una Tx, reiniciarla

	;ld	a,(iy+3)
	;and	%100
	;jr	z,GETP_NOTABORT

	;wreg	CR,%00 100 1 10
GETP_NOTABORT:

	;* Fin, devolver resultados

GETP_END2:	pop	bc,af
	call	STACKFREE
	ret


;*** READ_DMA: Lee BC bytes de DMA, dir HL, a DE en memoria.
;    Modifica HL,DE,BC; vuelve con banco 0.
;    Devuelve DE=Dir siguiente a la ultima escrita.

READ_DMA:	ld	ix,RTL_REGS

	wreg	RBCR1,b	;Prepara dir inicial y longitud
	wreg	RBCR0,c
	wreg	RSAR1,h
	wreg	RSAR0,l

	ld	a,c
	and	7	;A=BC MOD 8

	sra	b
	rr	c
	sra	b
	rr	c
	sra	b
	rr	c
	ld	b,c	;B=BC \ 8
	ld	c,a	;C=BC MOD 8

	wreg	CR,%00 001 0 00	;Inicio de la transferencia

	ld	hl,RTL_REGS+DMA_PORT
	ld	a,b
	or	a
	jr	z,RDMA_RESTO

	push	bc
RDMA_LOOP:	ld	a,b
	ldi		;Copia BC\8 veces 8 bytes
	ldi
	ldi
	ldi
	ldi
	ldi
	ldi
	ldi
	ld	b,a
	res	3,l
	djnz	RDMA_LOOP
	pop	bc
RDMA_RESTO:
	ld	a,c	;Copia los bytes restantes
	or	a
	jr	z,RDMA_LOOP3
	ld	b,0
RDMA_LOOP2:	ldir
	;djnz    RDMA_LOOP2
RDMA_LOOP3:

	wreg	CR,%00 100 0 00	;Fin de la transferencia        
	ret


;*** READ_PACK: Lee el paquete desde la pagina H, longitud BC,
;    a la dir DE de memoria (se salta la cabecera de 4 bytes).

READ_PACK:	;--- Calcula en B el num de paginas de 256 bytes

	ld	l,4
	push	bc
	ld	a,c
	or	a
	jr	z,READ_PACK2
	inc	b
READ_PACK2:

	;--- Si primera pag+num pags>RX_LASTP,
	;    habra que copiar en dos pasos;
	;    si no, bastara uno

	ld	a,h
	add	b
	pop	bc
	dec	a
	cp	RX_LASTP	;primera pag+num pags-1>=ultima pag?
	jr	c,READP_1STEP

	;--- Primer paso

	ld	a,RX_LASTP
	sub	h	;A=Num de pags a copiar
	push	bc

	ld	b,a
	ld	c,0
	push	af
	call	READ_DMA
	pop	af,bc
	sub	b
	neg
	ld	b,a	;Descontamos la long. ya leida

	ld	h,RX_FIRSTP
	ld	l,0

	;--- Copia del ultimo o unico paso:
	;    de HL a DE, long BC

READP_1STEP:
	call	READ_DMA
	ret


;=============================
;===  Envio de un paquete  ===
;=============================

;Entrada: HL = Dir del paquete (destino-origen-long/etherytype-datos)
;         BC = Long del paquete (16 a 1514)
;         A = 0: Tx sincrona (esperar a que acabe)
;             1: Tx asincrona (terminar inmediatamente)
;Salida:  A=0: Enviado OK
;           1: Longitud invalida
;         Si Tx sincrona, ademas:
;           3: Portadora perdida
;           4: Demasiadas retransmisiones


SEND_PACKET:	call	STACKALLOC
	ld	ix,RTL_REGS

	ld	(iy),l
	ld	(iy+1),h
	ld	(iy+2),c
	ld	(iy+3),b
	ld	(iy+4),a

	;--- Comprueba la longitud del paquete

	push	bc
	pop	hl

	ld	de,16	;Demasiado pequenyo
	call	COMP
	ld	a,1
	jp	nc,SEND_PACKETX

	ld	de,1515	;Demasiado grande
	call	COMP
	ld	a,1
	jp	c,SEND_PACKETX

	;ld	de,64
	;call	COMP
	;jr	c,PQSIZE_OK1
	;ld	hl,64	;Demasiado pequenyo: aumenta hasta 64 bytes
PQSIZE_OK1:
	;ld	(iy+2),l
	;ld	(iy+3),h

	;--- Espera hasta que se haya Tx el paquete actual

	selbank	0
WAIT_PQTX1:	rreg	a,CR
	and	%100
	jr	nz,WAIT_PQTX1

	;--- Limpia el estado de la transmision

	wreg	ISR,%00001010

	;--- Copia el paquete a la SRAM del RTL

	ld	l,(iy)
	ld	h,(iy+1)
	ld	c,(iy+2)
	ld	b,(iy+3)	;Recupera dir y long

	rtlstart	0

	wreg	RBCR1,b	;Longitud del paquete
	wreg	RBCR0,c
	wreg	RSAR1,TX_FIRSTP	;Direccion de destino
	wreg	RSAR0,0

	wreg	CR,%00 010 0 00	;Banco 0, Write DMA

	push	bc

	;Bucle de copia de BC bytes desde (HL) a SRAM

	ld	a,c
	and	7	;A=BC MOD 8

	sra	b
	rr	c
	sra	b
	rr	c
	sra	b
	rr	c
	ld	b,c	;B=BC \ 8
	ld	c,a	;C=BC MOD 8
	push	bc

	ld	de,RTL_REGS+DMA_PORT
WR_LOOP:	ld	a,b
	ldi		;Copia BC\8 veces 8 bytes
	ldi
	ldi
	ldi
	ldi
	ldi
	ldi
	ldi
	ld	b,a
	res	3,e
	djnz	WR_LOOP

	pop	bc
	ld	a,c	;Copia los bytes restantes
	or	a
	jr	z,WR_LOOP3
	ld	b,0
WR_LOOP2:	ldir
	;djnz	WR_LOOP2
WR_LOOP3:

	;Fin bucle de copia

	wreg	CR,%00 100 0 00	;Fin DMA

	pop	bc

	;--- Si el paquete es <64 bytes, convierte long. en 64

	ld	h,b
	ld	l,c
	ld	de,64	;Demasiado pequenyo
	call	COMP
	jr	c,PQSIZE_OK2
	ld	bc,64
PQSIZE_OK2:

	;--- Inicia la Tx        

	wreg	TBCR1,b	;Longitud a enviar
	wreg	TBCR0,c

	wreg	TPSR,TX_FIRSTP	;Pagina inicial de envio

	wreg	CR,%00 100 1 00	;Inicia la Tx

	;--- Si Tx asincrona, termina ya

	ld	a,(iy+4)
	or	a
	ld	a,0
	jr	nz,SEND_PACKETX

	;--- Si Tx sincrona, espera a que termine la Tx

WAIT_TXEND:	call	SEND_STATUS
	cp	2
	jr	c,WAIT_TXEND
	jr	nz,SEND_PACKETX
	xor	a

SEND_PACKETX:	call	STACKFREE
	ret


;========================================
;===  Estado del envio de un paquete  ===
;========================================

;Entrada: -
;Salida:  A=0: No hay estado
;           1: Paquete enviandose
;           2: Paquete enviado OK
;           3: Portadora perdida
;           4: Demasiadas colisiones

;       TSR indica:
;       bit 4: Portadora perdida
;       bit 3: Demasiadas colisiones
;       bit 0: Enviado OK


SEND_STATUS:	ld	ix,RTL_REGS

	selbank	0

SNDST_LOOP:

	;--- Hay un paquete enviandose?

	rreg	a,CR
	and	%100
	ld	a,1
	ret	nz

	;--- Enviado OK?

	rreg	b,TSR

	bit	0,b
	ld	a,2
	ret	nz

	;--- Excesivas colisiones?

	bit	3,b
	ld	a,4
	ret	nz

	;--- Portadora perdida?

	bit	4,b
	ld	a,3
	ret	nz

	;--- En cualquier otro caso, no hay estado
	;    (no se ha enviado nada todavia)

	xor	a
	ret


;============================
;===  Rutinas auxiliares  ===
;============================

;--- Reserva de 6 bytes para la pila,
;    devuelve el puntero al espacio reservado en IY.
;    Solo modifica IX, IY.

STALLTMP:	equ	#F3B5	;TXTCOL, no se usa (pero lo restauramos)

STACKALLOC:
	;* Obtenemos el contenido de SP en IX.
	;  Como solo existe LD (nn),SP tenemos que dar un rodeo.

	ld	ix,(STALLTMP)
	ld	(STALLTMP),sp
	ld	iy,(STALLTMP)
	ld	(STALLTMP),ix
	dec	iy
	dec	iy
	dec	iy
	dec	iy

	;* Decrementamos la pila, el hueco que queda
	;  podremos usarlo libremente.

	ex	(sp),ix	;Direccion de retorno a IY
	dec	sp
	dec	sp
	dec	sp
	dec	sp
	jp	(ix)


;--- Liberacion del espacio de pila
;    previamente reservado con STACKALLOC,
;    modifica IX

STACKFREE:	pop	ix
	inc	sp
	inc	sp
	inc	sp
	inc	sp
	inc	sp
	inc	sp
	jp	(ix)


;--- Obtencion en A/escritrura desde A del puntero al proximo paquete,
;    almacenado en #45FF de SRAM

GET_PAQ_PNT:	wreg	RBCR1,0	;Prepara dir inicial y longitud
	wreg	RBCR0,1
	wreg	RSAR1,RX_FIRSTP-1
	wreg	RSAR0,#FF

	wreg	CR,%00 001 0 00	;Inicio de la lectura
	rreg	a,DMA_PORT
	wreg	CR,%00 100 0 00	;Fin de la lectura

	ret


SET_PAQ_PNT:	wreg	RBCR1,0	;Prepara dir inicial y longitud
	wreg	RBCR0,1
	wreg	RSAR1,RX_FIRSTP-1
	wreg	RSAR0,#FF

	wreg	CR,%00 010 0 00	;Inicio de la escritura
	wreg	DMA_PORT,a
	wreg	CR,%00 100 0 00	;Fin de la escritura

	ret


;--- Espera de unos 1.6 ms
;    (a mejorar, suponemos que un NOP tarda 3.57 us)

WAIT:	push	bc
	ld	b,220
_WAIT:	nop
	djnz	_WAIT
	pop	bc
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


;***********************
;***  Espacio vacio  ***
;***********************

;Necesario para que la tabla de salto se ensamble al final de la pagina.
;Se puede incluir codigo adicional aqui.

BIOS_END:	ds	#7FD0-BIOS_END-JMP_CNT*3,#FF


;************************
;***  Tabla de salto  ***
;************************

;Debe estar en la direccion indicada por la etiqueta de la primera entrada.
;Si se han de anyadir entradas nuevas, anyadirlas AL PRINCIPIO de la tabla.
;Mantener siempre actualizado JMP_CNT.

J7FAF:	jp	SEND_STATUS	;Estado del envio de un paquete
J7FB2:	jp	SEND_PACKET	;Envia un paquete
J7FB5:	jp	GET_PACKET	;Obtiene un paquete recibido
J7FB8:	jp	GET_INSTAT	;Comprueba si hay paquetes recibidos
J7FBB:	jp	CONF_MCAST	;Configura la direccion de multicast
J7FBE:	jp	CONF_RX	;Configura los parametros de recepcion
J7FC1:	jp	CARD_ONOFF	;Activa o desactiva la tarjeta
J7FC4:	jp	GET_NETSTAT	;Obtener el estado de la red (disponible o no)
J7FC7:	jp	GET_HWAD	;Obtener la direccion de la tarjeta
J7FCA:	jp	GET_VERS	;Obtener la version de la ROM
J7FCD:	jp	RTL_RESET	;Resetear la tarjeta


;*****************************************************
;***  Cadena identificadora y espacio final vacio  ***
;*****************************************************

ID7FD0:	db	"ObsoNET",0
	db	VER_P,VER_S,VER_R
ID_END:	ds	#8000-ID_END,0

;El tamanyo final debe ser exactamente 16384 bytes (ROM) o 1536 bytes (DAT).
