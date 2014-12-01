; This application allows to control the TCP module of InterNestor Suite

;==========================================

	;--- TCPC - Programa de control de NestorTCP
	;    Por Konami Man, 12-2001
	;    Uso:
	;    TCPC S [n] -> Muestra informacion sobre la
	;                  conexion n, o sobre todas si se omite n
	;    TCPC P <puerto_local> [<IP remota> <puerto remoto>]
	;               Abre una conexion pasiva; si no se
	;               especifican IP remota y puerto remoto,
	;               se suponen 0
	;    TCPC O <puerto_local> <IP remota> <puerto remoto>
	;               Anre una conexion activa
	;    TCPC C n   -> Cierra la conexion n
	;    TCPC A n   -> Aborta la conexion n
	;    TCPC E [on|off] -> Activa o desactiva el puerto 7
	;                       como servidor de eco;
	;                       si solo se pone E, muestra info
	;    TCPC B [<tam_bufer>]
	;               Consulta o establece el tamanyo declarado
	;               del bufer de recepcion
	;    TCPC K n <offset> -> Muestra PEEK(base_TCB_n + offset)


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

;--- Llamadas al modulo TCP

TCP_TABLES:	equ	#801E
TCP_OPEN:	equ	#8021
TCP_CLOSE:	equ	#8024
TCP_ABORT:	equ	#8027
TCP_SEND:	equ	#802A
TCP_RCV:	equ	#802D
TCP_STATUS:	equ	#8030
TCP_FLUSH_OUT:	equ	#8033

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

ENASLT:	equ	#0024
TIME:	equ	#FC9E



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
	ld	a,d	;Obtiene el segmento del TCP
	nesman	3
	ld	a,c
	ld	(INS_SEG),a

	;--- Obtiene rutinas del mapeador

	ld	de,#0402	;Obtiene rutinas del mapeador
	call	#FFCA
	ld	de,ALL_SEG
	ld	bc,#30
	ldir

	;--- Conecta el segmento de NestorTCP en pagina 1

	ld	a,(INS_SLOT)
	ld	h,#80
	call	ENASLT
	ei
	ld	a,(INS_SEG)
	call	PUT_P2

	;--- Comprueba la opcion y salta a la rutina adecuada

	ld	a,(BUFPAR)
	or	%00100000
	cp	"s"
	jr	z,OPCION_S
	cp	"o"
	jp	z,OPCION_O
	cp	"p"
	jp	z,OPCION_P
	cp	"c"
	jp	z,OPCION_C
	cp	"a"
	jp	z,OPCION_A
	cp	"e"
	jp	z,OPCION_E
	cp	"b"
	jp	z,OPCION_B
	cp	"k"
	jp	z,OPCION_K

OPDESC:	print	INVOPT_S
	jp	TERMINFO	;Opcion desconocida?


;------------------
;---  Opcion S  ---
;------------------

OPCION_S:	ld	a,2
	ld	de,BUFPAR
	call	EXTPAR
	jr	c,OP_S_ALL

	;--- Se especifica conexion:
	;    muestra info solo de esa conexion

OP_S_UNO:	ld	a,(BUFPAR)
	and	%11111000	;Si el primer caracter del
	cp	"0"	;segundo parametro no es
	ld	de,BADCON_S	;"0" a "7", error
	jp	nz,TERMERR

	ld	a,(BUFPAR+1)	;Si el segundo parametro tiene
	or	a	;mas de un caracter, error
	jp	nz,TERMERR

	ld	a,#FF	;Mostrar estado aunque sea CLOSED
	ld	(SHOW_IF_CLOSED),a

	ld	a,(BUFPAR)	;Muestra info y termina
	and	%111
	call	SHOW_CON_INFO
	jp	TERMOK

	;--- No se especifica conexion: muestra info
	;    sobre todas las conexiones
	;    que no esten CLOSED

OP_S_ALL:	xor	a
OP_SALL_L:	push	af
	call	SHOW_CON_INFO
	pop	af
	inc	a
	cp	8
	jr	nz,OP_SALL_L

	ld	a,(CONS_EXIST)	;Imprime "No connections open"
	or	a	;si CONS_EXIST=0 (todas las
	ld	de,NOCONS_S	;conexiones estaban CLOSED)
	ld	c,_STROUT
	call	z,5
	jp	TERMOK

	;--- Rutina de impresion de informacion sobre
	;    la conexion

SHOW_CON_INFO:	ld	b,a
	add	"0"
	ld	(STAT_S_NUM),a
	ld	a,b
	call	TCP_STATUS
	jr	nc,SHOW_CI_OK1

	;Conexion no abierta: muestra estado (CLOSED)
	;si SHOW_IF_CLOSED=#FF. Despues termina.

SHOW_CI_ERR:	ld	a,(SHOW_IF_CLOSED)
	or	a
	ret	z
	print	STAT_S
	print	STAT0_S
	ret

	;Conexion abierta: primero muestra estado

SHOW_CI_OK1:	ld	(TCBPNT),hl
	ld	d,a
	ld	a,b
	ld	(CON_FLAGS),a
	ld	a,#FF
	ld	(CONS_EXIST),a
	ld	a,d

	push	af
	print	STAT_S
	pop	af
	ld	de,STAT1_S
	dec	a
	jr	z,SHOW_CI_OK2
	ld	de,STAT2_S
	dec	a
	jr	z,SHOW_CI_OK2
	ld	de,STAT3_S
	dec	a
	jr	z,SHOW_CI_OK2
	ld	de,STAT4_S
	dec	a
	jr	z,SHOW_CI_OK2
	ld	de,STAT5_S
	dec	a
	jr	z,SHOW_CI_OK2
	ld	de,STAT6_S
	dec	a
	jr	z,SHOW_CI_OK2
	ld	de,STAT7_S
	dec	a
	jr	z,SHOW_CI_OK2
	ld	de,STAT8_S
	dec	a
	jr	z,SHOW_CI_OK2
	ld	de,STAT9_S
	dec	a
	jr	z,SHOW_CI_OK2
	ld	de,STAT10_S
	dec	a
	jr	z,SHOW_CI_OK2
	ld	de,UNK_S

SHOW_CI_OK2:	ld	c,_STROUT
	call	5

	;Muestra el puerto local
	;(almacenado en TCBPNT+7 en big endian)

	ld	ix,(TCBPNT)
	ld	d,(ix+7)
	ld	e,(ix+8)
	ld	hl,LOCP_S_NUM
	ld	b,1
	ld	a,%1000
	call	NUMTOASC
	print	LOCP_S

	;Muestra el puerto remoto
	;(almacenado en TCBPNT+5 en big endian)

	ld	ix,(TCBPNT)
	ld	d,(ix+5)
	ld	e,(ix+6)
	ld	hl,REMP_S_NUM
	ld	b,1
	ld	a,%1000
	call	NUMTOASC
	print	REMP_S

	;Muestra la IP remota
	;(almacenada en TCBPNT+1)

	print	REMIP_S
	ld	ix,(TCBPNT)
	inc	ix
	call	SHOWIP

	;Muestra informacion sobre datos recibidos pendientes

	print	RPEND_S
	ld	a,(CON_FLAGS)
	and	%11
	ld	de,NO_S
	or	a	;No hay
	jr	z,SHOW_CI_OK3
	ld	de,NORMAL_S
	cp	%01	;Normales
	jr	z,SHOW_CI_OK3
	ld	de,URGENT_S
	cp	%11	;Urgentes
	jr	z,SHOW_CI_OK3
	ld	de,UNK_S

SHOW_CI_OK3:	ld	c,_STROUT
	call	5

	;Muestra informacion sobre datos a enviar pendientes

	print	SPEND_S
	ld	a,(CON_FLAGS)
	and	%111 00
	ld	de,NO_S
	or	a	;No hay
	jr	z,SHOW_CI_OK4
	ld	de,NORMAL_S
	cp	%001 00	;Normales
	jr	z,SHOW_CI_OK4
	ld	de,URGENT_S
	cp	%011 00	;Urgentes
	jr	z,SHOW_CI_OK4
	ld	de,PUSHED_S
	cp	%101 00	;Pushed
	jr	z,SHOW_CI_OK4
	ld	de,PUSHURG_S
	cp	%111 00	;Urgentes y pushed
	jr	z,SHOW_CI_OK4
	ld	de,UNK_S

SHOW_CI_OK4:	ld	c,_STROUT
	call	5

	;Muestra informacion sobre datos a retransmitir pendientes

	print	RETX_S
	ld	a,(CON_FLAGS)
	ld	de,NO_S
	bit	5,a
	jr	z,SHOW_CI_OK5
	ld	de,YES_S

SHOW_CI_OK5:	ld	c,_STROUT
	call	5

	;Termina

	ret


;------------------------
;---  Opciones O y P  ---
;------------------------

OPCION_P:	ld	a,#FF
	ld	(ACTORPAS),a

	;Obtiene puerto local

OPCION_O:	ld	a,2	;Si no hay mas parametros
	ld	de,BUFPAR	;tras O o P, error
	call	EXTPAR	;Extrae puerto local
	ld	de,ATLLOC_S
	jp	c,TERMERR

	ld	a,(BUFPAR)	;Si el puerto local es "*",
	cp	"*"	;ignorarlo
	jr	z,OK_OPO1
	ld	hl,BUFPAR
	call	EXTNUM16	;Extrae numero de puerto local
	ld	de,INVPES_S
	jp	c,TERMERR
	ld	(LOCAL_PORT),bc
OK_OPO1:	;

	;Obtiene IP remota

	ld	a,3
	ld	de,BUFPAR
	call	EXTPAR	;Si no existe el par,
	jr	c,OK_OPO4	;se asume 0.0.0.0 0

	ld	hl,BUFPAR	;Anyade "." al final para
	ld	c,b	;facilitar el proceso
	ld	b,0
	add	hl,bc
	ld	(hl),"."

	ld	de,REMOTE_IP
	ld	hl,BUFPAR
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

	jr	OK_OPO3

ERRIP:	ld	de,INVIP_S
	jp	TERMERR
OK_OPO3:	;

	;Obtiene puerto remoto

	ld	a,4	;Si no hay mas parametros
	ld	de,BUFPAR	;tras la IP, error
	call	EXTPAR	;Extrae puerto remoto
	ld	de,MISRPORT_S
	jp	c,TERMERR

	ld	hl,BUFPAR
	call	EXTNUM16	;Extrae numero de puerto remoto
	ld	de,INVPES_S
	jp	c,TERMERR
	ld	(REMOTE_PORT),bc

	;Intenta abrir la conexion

OK_OPO4:	ld	hl,PSEUDO_TCB
	call	TCP_OPEN
	jr	nc,OK_OPO5

	ld	de,OPERR1_S	;Error? Lo muestra y termina
	dec	a
	jp	z,TERMERR
	ld	de,OPERR2_S
	dec	a
	jp	z,TERMERR
	ld	de,OPERR3_S
	dec	a
	jp	z,TERMERR
	ld	de,OPERR4_S
	dec	a
	jp	z,TERMERR
	ld	de,OPERRX_S
	jp	TERMERR

OK_OPO5:	add	"0"	;Muestra numero de conexion y termina
	ld	(CONOP_S_NUM),a
	print	CONOP_S
	jp	TERMOK


;------------------------
;---  Opciones C y A  ---
;------------------------

OPCION_A:	ld	hl,TCP_ABORT
	ld	(CODE1+1),hl
	ld	hl,ABORTED_S
	ld	(CODE2+1),hl

OPCION_C:	ld	a,2
	ld	de,BUFPAR
	call	EXTPAR
	ld	de,MISCON_S
	jp	z,TERMERR

	ld	a,(BUFPAR)
	and	%11111000	;Si el primer caracter del
	cp	"0"	;segundo parametro no es
	ld	de,BADCON_S	;"0" a "7", error
	jp	nz,TERMERR

	ld	a,(BUFPAR+1)	;Si el segundo parametro tiene
	or	a	;mas de un caracter, error
	jp	nz,TERMERR

	ld	a,(BUFPAR)
	ld	(HASBN_S_NUM),a
	and	%111
CODE1:	call	TCP_CLOSE
	jr	nc,OK_OPC1

	ld	de,CLOSERR1_S
	dec	a
	jp	z,TERMERR
	ld	de,CLOSERR2_S
	dec	a
	jp	z,TERMERR
	ld	de,CLOSERRX_S
	jp	TERMERR
OK_OPC1:	;

	print	HASBEEN_S
CODE2:	ld	de,CLOSED_S
	ld	c,_STROUT
	call	5

	jp	TERMOK


;------------------
;---  Opcion E  ---
;------------------

OPCION_E:	xor	a
	call	TCP_TABLES
	inc	hl
	inc	hl
	push	hl	;HL = Dir de cte ECHO_SERVER

	ld	a,2
	ld	de,BUFPAR
	call	EXTPAR
	jr	c,OPE_CHECK

	;Establecer

	ld	a,(BUFPAR)	;Establece a 0 si la entrada es "0",
	cp	"0"	;a #FF si es cualquier otra
	ld	a,0
	jr	z,OPE_OK1
	ld	a,#FF
OPE_OK1:	pop	hl
	ld	(hl),a

	ld	de,OFF_S	;Imprime "swicthed to ON/OFF"
	or	a
	jr	z,OPE_OK2
	ld	de,ON_S
OPE_OK2:	push	de
	print	ECHOSW_S
	pop	de
	ld	c,_STROUT
	call	5

	jp	TERMOK

	;Consultar

OPE_CHECK:	pop	hl	;Imprime "Is currently ON/OFF"
	ld	a,(hl)
	ld	de,OFF_S
	or	a
	jr	z,OPE_OK3
	ld	de,ON_S
OPE_OK3:	push	de
	print	ECHOF_S
	pop	de
	ld	c,_STROUT
	call	5

	jp	TERMOK


;------------------
;---  Opcion B  ---
;------------------

OPCION_B:	xor	a
	call	TCP_TABLES
	push	hl	;HL = Dir de cte DEF_RCV_BUF

	ld	a,2
	ld	de,BUFPAR
	call	EXTPAR
	jr	c,OPB_CHECK

	;Establecer

	ld	hl,BUFPAR	;Extrae numero
	call	EXTNUM16
	ld	de,INVNUM_S
	jp	c,TERMERR

	pop	hl	;Establece constante
	ld	(hl),c
	inc	hl
	ld	(hl),b

	print	BUFSCH_S
	jp	TERMOK

	;Consultar

OPB_CHECK:	pop	hl	;Obtiene numero
	ld	e,(hl)
	inc	hl
	ld	d,(hl)

	ld	hl,BUFS_S_NUM	;Transforma a cadena e imprime
	ld	b,1
	ld	a,%1000
	call	NUMTOASC
	print	BUFS_S
	print	CRLF_S

	jp	TERMOK


;------------------
;---  Opcion K  ---
;------------------

OPCION_K:	ld	a,2
	ld	de,BUFPAR
	call	EXTPAR
	ld	de,MISCON_S
	jp	z,TERMERR

	ld	a,(BUFPAR)
	and	%11111000	;Si el primer caracter del
	cp	"0"	;segundo parametro no es
	ld	de,BADCON_S	;"0" a "7", error
	jp	nz,TERMERR

	ld	a,(BUFPAR+1)	;Si el segundo parametro tiene
	or	a	;mas de un caracter, error
	jp	nz,TERMERR

	ld	a,(BUFPAR)
	ld	(CON_S_NUM),a
	sub	"0"	;Conexion correcta:
	call	TCP_STATUS	;guarda la dir de inicio de su TCB
	ld	(TCBPNT),hl

	ld	a,3	;Obtiene offset
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

	push	bc
	print	CON_S	;Imprime conexion y offset
	print	OFFSET_S
	print	BUFPAR
	print	CRLF_S

	pop	bc
	ld	hl,(TCBPNT)
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

TERMERR:	ld	c,_STROUT
	call	5

TERMOK:	ld	a,(#F343)
	ld	h,#80
	call	ENASLT
	ld	a,1
	call	PUT_P2

TERMOK2:	ld	bc,#0062
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



;****************************
;***                      ***
;***   DATOS, VARIABLES   ***
;***                      ***
;****************************

INS_SLOT:	db	0
INS_SEG:	db	0
SHOW_IF_CLOSED:	db	0	;#FF para mostrar estado aunque sea CLOSED
CONS_EXIST:	db	0	;#FF si existe alguna conexion abierta
CON_FLAGS:	db	0	;Flags de la conexion
TCBPNT:	dw	0

PSEUDO_TCB:
REMOTE_IP:	db	0,0,0,0	;IP remota
REMOTE_PORT:	dw	0	;Puerto remoto
LOCAL_PORT:	dw	#FFFF	;Puerto local
ACTORPAS:	db	0	;Conexion activa
	db	0


PRESEN_S:	db	13,10,"NestorTCP control program 0.1",13,10
	db	"By Konami Man, 12-2001",13,10,10,"$"
INFO_S:	db	"Use:",13,10,10
	db	"* TCPC S [<connection_number>]",13,10
	db	"Shows the status and information about the specified connection,",13,10
	db	"or about all connections if <connection_number> is omitted",13,10,10
	db	"* TCPC O|P <local_port> [<remote_IP> <remote_port>]",13,10
	db	"Opens an active (O) or passive (P) connection to the specified remote socket",13,10
	db	"- If remote socket is not specified, ",34,"0.0.0.0 0",34," is used,",13,10
	db	"  meaning that any incoming connection will be accepted (passive open only)",13,10
	db	"- ",34,"*",34," may be specified instead of local port, meaning automatic port selection",13,10,10
	db	"* TCPC C|A <connection_number>",13,10
	db	"Closes (C) or aborts (A) the specified connection",13,10,10
	db	"* TCPC E [0|1]",13,10
	db	"Switches on (1) or off (0) the echo server feature for port 7",13,10
	db	"Note that this option does NOT open or close port 7",13,10
	db	"If on or off is omitted, the current status is shown",13,10,10
	db	"* TCPC B [<buffer_size>]",13,10
	db	"Sets to <buffer_size> the declared total size of the receive buffer",13,10
	db	"This value is reset to 16100 when Internet connection is lost",13,10
	db	"If <buffer_size> is not specified, current size is shown",13,10,10
	db	"* TCPC K <connection_number> <variable_offset>",13,10
	db	"Shows the contents of the variable with the specified offset",13,10
	db	"in the TCB of the specified connection (specify offset in decimal)",13,10
	db	"$"

NONMAN_S:	db	"ERROR: NestorMan not installed!",13,10,"$"
BADNMAN_S:	db	"ERROR: Invalid NestorMan version!",13,10,"$"
NEEDNMAN_S:	db	"NestorMan version 1.21 or higher is needed.",13,10,"$"
INVOPT_S:	db	"ERROR: Invalid option!",13,10,10,"$"
NOINS_S:	db	"ERROR: InterNestor suite is not installed!",13,10,"$"
BADCON_S:	db	"ERROR: Invalid connection number (must be 0 to 7)",13,10,"$"
ATLLOC_S:	db	"ERROR: Missing parameters - at least local port must be specified",13,10,"$"
INVPES_S:	db	"ERROR: Invalid port number - must be 0 to 65535",13,10,"$"
INVIP_S:	db	"ERROR: Invalid IP address - must be xx.xx.xx.xx",13,10,"$"
MISRPORT_S:	db	"ERROR: Missing parameter - remote port must be specified",13,10,"$"
MISCON_S:	db	"ERROR: Missing parameter - connection number must be specified",13,10,"$"
OPERR1_S:	db	"ERROR: Too many open connections",13,10,"$"
OPERR2_S:	db	"ERROR: No internet connection currently",13,10,"$"
OPERR3_S:	db	"ERROR: Connection exists (same local port and remote socket)",13,10,"$"
OPERR4_S:	db	"ERROR: Can't open an active connection with unespecified socket",13,10,"$"
OPERRX_S:	db	"Unknown error when opening connection",13,10,"$"
CLOSERR1_S:	db	"ERROR: Connection don't exists (already closed)",13,10,"$"
CLOSERR2_S:	db	"ERROR: Connection is already closing",13,10,"$"
CLOSERRX_S:	db	"Unknown error when closing/aborting connextion",13,10,"$"
INVNUM_S:	db	"ERROR: Invalid number - must be 0 to 65535",13,10,"$"
INVOFF_S:	db	"ERROR: Invalid offset number - must be 0 to 65535",13,10,"$"
MISOFF_S:	db	"ERROR: Missing parameter - variable offset must be specified",13,10,"$"
NOCONS_S:	db	"* No TCP open connections currently",13,10,"$"


STAT0_S:	db	"CLOSED",13,10,"$"
STAT1_S:	db	"LISTEN",13,10,"$"
STAT2_S:	db	"SYN-SENT",13,10,"$"
STAT3_S:	db	"SYN-RECEIVED",13,10,"$"
STAT4_S:	db	"ESTABLISHED",13,10,"$"
STAT5_S:	db	"FIN-WAIT-1",13,10,"$"
STAT6_S:	db	"FIN-WAIT-2",13,10,"$"
STAT7_S:	db	"CLOSE-WAIT",13,10,"$"
STAT8_S:	db	"CLOSING",13,10,"$"
STAT9_S:	db	"LAST-ACK",13,10,"$"
STAT10_S:	db	"TIME-WAIT",13,10,"$"
UNK_S:	db	"Unknown!!",13,10,"$"

STAT_S:	db	13,10,"* Connection number "
STAT_S_NUM:	db	"0 status is: $"
LOCP_S:	db	"  Local port number: "
LOCP_S_NUM:	db	"00000$"
REMP_S:	db	13,10,"  Remote port number: "
REMP_S_NUM:	db	"00000$"
REMIP_S:	db	13,10,"  Remote IP address: $"
RPEND_S:	db	"  Received data pending: $"
YES_S:	db	"Yes",13,10,"$"
NO_S:	db	"No",13,10,"$"
NORMAL_S:	db	"Yes, normal",13,10,"$"
PUSHED_S:	db	"Yes, pushed",13,10,"$"
URGENT_S:	db	"Yes, urgent",13,10,"$"
PUSHURG_S:	db	"Yes, pushed and urgent",13,10,"$"
SPEND_S:	db	"  Outgoing data pending: $"
RETX_S:	db	"  Data in the retransmission queue pending: $"
CONOP_S:	db	"! Connection opened with number "
CONOP_S_NUM:	db	"0",13,10,"$"
HASBEEN_S:	db	"* Connection "
HASBN_S_NUM:	db	"0 has been $"
CLOSED_S:	db	"closed",13,10,"$"
ABORTED_S:	db	"aborted",13,10,"$"
ON_S:	db	"ON",13,10,"$"
OFF_S:	db	"OFF",13,10,"$"
ECHOF_S:	db	"Port 7 echo server feature is currently $"
ECHOSW_S:	db	"Port 7 echo server feature switched $"
BUFS_S:	db	"Receive buffer size is currently: "
BUFS_S_NUM:	db	"00000$"
BUFSCH_S:	db	"Buffer size has been modified"
CRLF_S:	db	13,10,"$"
BYTE_S:	db	"Byte: "
BYTE_S_NUM:	db	"00000$"
WORD_S:	db	13,10,"Word: "
WORD_S_NUM:	db	"00000$"
WBE_S:	db	13,10,"Word, big endian: "
WBE_S_NUM:	db	"00000$"
COMA_S:	db	", #$"
CON_S:	db	"Connection: "
CON_S_NUM:	db	"0",13,10,"$"
OFFSET_S:	db	"Offset: $"

BUFPAR:	;

