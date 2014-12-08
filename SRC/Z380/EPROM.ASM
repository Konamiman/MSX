;EPROM BIOS for the LPE-Z380

;===================

	;/// EPROM LPE-Z380 2.1
	;/// Parte: arranque del Z380 (direccion EPROM: #0000)

;- Inicializa los puertos internos del Z380
;- Establece la configuracion RAM, BIPORT, EPROM, RAM 16 bits
;  en las paginas 0, 1, 2 y 3 respectivamente
;- Envia al MSX su programa de arranque (muestra logo e informacion)
;- Copia la rutina de trapping y el gestor de comandos a la parte mas alta
;  del primer bloque de 64K, y deja disponible para el usuario el area
;  #0100-(#0009)

	include	4	;Macros Z380 (Z380MAC.ASC)

;********************
;***  CONSTANTES  ***
;********************

	;--- Direcciones de la biport

STATMNT:	equ	4
Z380ST:	equ	#10
ZDIR_3:	equ	#11
ZVAL:	equ	#15
ZDIR_M:	equ	#17
ZBLON:	equ	#19
ZTLON:	equ	#1B
BLKDIR:	equ	#1D
BLKLON:	equ	#1F
USRDIR:	equ	#21
TRAPFDIR:	equ	#23
TRAPIDIR:	equ	#25
INTFLAG:	equ	#27
SERVSPC:	equ	#28
BASPNT:	equ	#2A
MEMLON:	equ	#3F
S_C_DIR:	equ	#40
S_JMP:	equ	#42
S_ACTION:	equ	#45


	;--- Rutinas BIOS y BASIC MSX

CALBAS:	equ	#0159
CHRGTR:	EQU	&H4666
FRMEVL:	EQU	&H4C64
FRMQNT:	EQU	&H542F
GETBYT:	EQU	&H521C
FRESTR:	EQU	&H67D0
PTRGET:	EQU	&H5EA4

SUBFLG:	EQU	&HF6A5
PROCNM:	equ	#FD89
VALTYP:	equ	#F663


	;--- Un "frame" es un bloque de 64K.
	;    La macro "frame" carga el valor especificado
	;    en la parte alta del registro especificado.

RAM:	equ	#0000	;Frames correspondientes al inicio
BIPORT:	equ	#4000	;de cada pagina del Z380.
EPROM:	equ	#8000
RAMH:	equ	#C000

HIFRAM:	equ	#F300	;Direccion mas alta usable

frame:	macro	@r,@f
	swap	@r
	ld	@r,@f
	swap	@r
	endm

frame0:	macro	@r,@f	;Como "frame", pero pone la parte baja
	ddir	iw.lw	;del registro a 0
	ld	@r,0
	dw	@f
	endm

PRUEBAS:	equ	1

	if	PRUEBAS

	db	#FE
	dw	#A000
	dw	#B000
	dw	#A000

	else

	db	#FE
	dw	#0	;Para el grabador de EPROMs
	dw	#3FFF
	dw	0

	endif


;***************************
;***  ARRANQUE DEL Z380  ***
;***************************

	org	0

D0000:	JP	INICIALIZA	;Sera sustituido por JP TRAP
	;                        ;tras el arranque
D0003:	JP	PPARAO	;Entrada al gestor de comandos
	;                        ;(pone Z380ST a 0 y espera comando)
D0006:	jp	EJECUT	;Ejecucion de un comando desde el Z380
	;                        ;(entrar comando en A, no en Z380ST)
MAXDIR:	dw	HIFRAM	;MAXIMA DIRECCION DISPONIBLE

	ds	5	;Resto hasta 16 bytes


	;--- Tabla de saltos para las rutinas de soporte del server

	if	PRUEBAS
MRBYTE:	jp	AKIMESM+#8000	;MRBYTE
	else
MRBYTE:	jp	_MRBYTE
	endif
MRWORD:	jp	_MRWORD	;Versiones con paso de parametros por
MWBYTE:	jp	_MWBYTE	;registros
MWWORD:	jp	_MWWORD
MRPORT:	jp	_MRPORT
MWPORT:	jp	_MWPORT
EXEMSX:	jp	_EXEMSX
ZTOM:	jp	_ZTOM
MTOZ:	jp	_MTOZ
MTOP:	jp	_MTOP
PTOM:	jp	_PTOM

MRBYT2:	jp	_MRBYT2	;Versiones con paso de parametros
MRWOR2:	jp	_MRWOR2	;mediante CALL + DW
MWBYT2:	jp	_MWBYT2
MWWOR2:	jp	_MWWOR2
MRPOR2:	jp	_MRPOR2
MWPOR2:	jp	_MWPOR2
EXEMS2:	jp	_EXEMS2
ZTOM2:	jp	_ZTOM2
MTOZ2:	jp	_MTOZ2
MTOP2:	jp	_MTOP2
PTOM2:	jp	_PTOM2

CALLNAM:	ds	16	;Para el nombre del comando CALL (#0052)

AKIMESM:	;
	if	PRUEBAS

PREXE:	resc	lw
	frame0	hl,0
	frame0	de,0
	frame0	bc,0
	ld	hl,#8000	;Rutina de autocopia para pruebas
	ld	de,0
	ld	bc,4096
	ldir

	ddir	iw.lw
	ld	ix,0
	dw	#4000

	ld	(ix+#10),0

	frame	hl,0

	ld	hl,_MRBYTE
	ld	(#11),hl

	jp	0

	endif

	;--- Inicializacion de puertos

INICIALIZA:	DI
	IM	1
	resc	lw
	xor	a
	out0	(#0F),a
	LD	A,&H95
	out0	(#15),a

	;Pone EPROM, BIPORT, ---, RAM en pag. 0,1,2,3 resp.

	LD	C,&HF0

	if	PRUEBAS
	ld	h,&B 11 00 01 11
	ld	l,&B 11 00 01 11
	else
	LD	H,&B 11 00 01 00
	LD	L,&B 11 00 01 00
	endif

	outw	(c),hl

	;Escritura en registro #F3

	LD	C,&HF3
	inw	hl,(c)

	LD	A,L
	AND	&B10000000
	RLCA
	RLCA
	LD	HL,&HFC01
	OR	H
	LD	H,A

	outw	(c),hl

	;--- Copia cabecera ROM, CALLs, etc. a la biport

	if	PRUEBAS=0
	setc	lw
	ld	hl,#4000	;#4000 de EPROM = codigo BIPORT
	ddir	iw
	ld	de,0
	dw	#4000
	ld	bc,#03FF
	ddir	w
	LDIR
	endif

	;--- Copia EPROM a RAM y pone RAM en pagina 0

	if	PRUEBAS=0
	ld	hl,0
	ddir	iw
	ld	de,0	;La RAM esta en pag. 3
	dw	#C000
	ld	bc,#8000	;32K
	resc	lw
	LDIR
	endif

	;--- Pone RAM, BIPORT, EPROM, RAM en pag. 0, 1, 2, 3 resp.
	;    (esta es la configuracion definitiva)

	LD	C,&HF0
	LD	H,&HC7
	LD	L,&HC7
	outw	(c),hl


	;--- Establece velocidad maxima

	xor	a
	out0	(&H08),a


	;--- TEST DE MEMORIA - SUPONE EFECTO ESPEJO
	;    No destructivo

	ld	a,(0)	;Guarda contenido original de 0
	ld	d,a
	xor	a
	ld	(0),a

	ld	bc,4
	ddir	ib.lw
	ld	hl,0	;Dir. inicial test = #00040000
	db	4

BUCMEM:	ld	e,(hl)
	ld	a,1	;Pokeamos y comprobamos si se ha
	ld	(hl),a	;modificado el contenido de #00000000
	ld	a,(0)
	or	a
	ld	(hl),e
	jr	nz,ENDBMEM	;Si: fin del test, HL-1 = Ultima dir.

	swap	hl	;No: comprobamos siguiente bloque
	add	hl,bc	;de 256K
	swap	hl
	jr	BUCMEM

ENDBMEM:	swap	hl	;Transforma dir. en HL a megas en L
	srlw	hl
	srlw	hl
	srlw	hl
	srlw	hl
	frame0	ix,BIPORT
	if	PRUEBAS
	ld	(ix+#0F),l
	else
	ld	(ix+MEMLON),l
	endif
	swap	hl

	ld	a,d	;Recupera contenido original de 0
	ld	(0),a

	;--- Copia la parte permanente a 64K-512

	setc	lw
	ld	hl,PERM
	ld	de,HIFRAM
	ld	bc,#FFFF-HIFRAM
	resc	lw
	ldir

	ld	hl,TRAP	;Cambia el salto de 0 de JP INICIALIZA
	ld	(1),hl	;a JP TRAP

	;--- Establece la pila y los ganchos

	;--- EXPLICACION SOBRE LOS GANCHOS:
	;* El gancho #FFE8 es llamado al principio de la rutina
	;  de tratamiento de los CALLs.
	;  Ha de volver con (ZVAL)=1 si procesa el comando; si no lo
	;  procesa, ha de saltar al gancho antiguo.
	;* El gancho #FFF0 es llamado cada vez que se invoca un comando
	;  del Z380, ya sea a traves del MSX o via CALL 6 desde el Z380.
	;  El gancho sera llamado en modo LW, y ha de preservar A.
	;* El gancho #FFF8 es llamado continuamente mientras el Z380
	;  esta parado, es decir, mientras espera a que se le ordene
	;  ejecutar un comando.
	;  Este gancho es llamado en modo LW y ha de preservar HL.


	ddir	lw
	ld	sp,0
	ld	sp,(MAXDIR)	;Pone pila en la parte mas alta de mem.
	ld	hl,#F8FF	;Pone la RAM de la pagina 3
	ld	c,#F1	;en modo 16 bits
	outw	(c),hl

	setc	lw
	ld	hl,#FFE8	;Pone RETs en los ganchos
	ld	de,#FFE9
	ld	bc,23
	ld	(hl),#C9
	resc	lw
	ldir

	ddir	iw.lw
	ld	ix,0
	dw	#4000

	ldrm	hl,(ix+USRDIR)	;Para que BLKLON sea multiplo de 3
	ldmr	(ix+ZDIR_M),hl
	ld	a,8
	call	6

	;--- Copia el programa de inicializacion al MSX
	;    y espera a que lo ejecute

IWAIT:	ld	a,65	;Para evitar que el TR confunda con RAM
	ld	(ix),a
	ld	a,(ix+S_ACTION)	;Espera a que el MSX haya entrado en
	cp	2	;modo server
	jr	nz,IWAIT

	ld	de,0	;Para evitar que el cartucho arranque
	ldmr	(ix+2),de	;mas de una vez

	call	ZTOM2	;Copia rutina de init
	if	PRUEBAS	;de #80004400 (EPROM) a #9000 (MSX)
	dw	#4400,0	;Longitud: #3600
	else
	dw	#4400,#8000
	endif
	dw	#9000
	dw	#3600

	call	EXEMS2	;Ejecuta rutina de init
	dw	#9000

	ddir	iw.lw
	ld	ix,0
	dw	#4000

IWAIT2:	ld	a,(ix+S_ACTION)	;Libera el server para que el arranque
	cp	2	;del MSX prosiga
	jr	nz,IWAIT2
	ld	(ix+S_ACTION),0


	;--- PRUEBA ---
	;    Coloca una rutina en el gancho #FFF8
	;    que incrementa constantemente una variable de 4 bytes
	;    situada en #402C.
	;    En modo nativo solo se vera un incremento de 2 bytes.

	if	PRUEBAS

	ld	hl,(MAXDIR)	;<<< PROCEDIMIENTO CORRECTO para reservar
	subwi	#20	;<<< memoria en el frame 0
	ld	(MAXDIR),hl	;<<<
	ld	(chorra+1),hl
	ex	de,hl
	ld	hl,chorra2
	ld	bc,#20
	ldir

	ld	hl,chorra
	ld	de,#FFF8
	ld	bc,4
	ldir

	endif

	jp	3

	if	PRUEBAS

chorra:	jp	0
	ret

chorra2:	ddir	iw.lw
	ld	bc,(#2C)
	dw	#4000
	inc	bc
	ddir	iw.lw
	ld	(#2C),bc
	dw	#4000
	frame0	bc,0
	ret

	endif


;-------  Aqui empieza la parte a copiar en 64K-512  -------

PERM:	org	HIFRAM


;****************************
;***  RUTINA DE TRAPPING  ***
;****************************

;Salta a la direccion especificada por el usuario
;si el bit de trapping esta a 1, si no, salta a 3.

;Hay definidas dos direcciones de trapping: normal (instruccion inexistente
;encontrada al ejecutar un programa) y de interrupcion (instruccion
;inexistente depositada por un dispositivo al generar una interrupcion
;de tipo 0). Esta ultima sin uso de momento.

TRAP:	ld	c,#19
	inw	hl,(c)
	bit	1,h	;Comprobamos si la instruccion indef.
	jr	nz,TRAPINS	;se ha producido en un fetch...

	bit	0,h	;...o en una interrupcion
	jr	nz,TRAPINT

	jp	3

TRAPINS:	ddir	iw.w
	ld	de,(TRAPFDIR)
	dw	#4000
	jr	TRAPALL

TRAPINT:	ddir	iw.w
	ld	de,(TRAPIDIR)
	dw	#4000

TRAPALL:	andwi	#FCFC	;Pone bits de trapping a 0
	outw	(c),hl
	ldrr	hl,de
	jp	(hl)


;****************************
;***  GESTOR DE COMANDOS  ***
;****************************

;Aqui el Z380 ejecuta un bucle infinito, en el que espera comandos desde
;el MSX (leyendo la variable de la biport Z380ST) y los ejecuta.

;--> Se puede acceder aqui con JP 3.


PPARAO:	;--- Pone Z380ST a 0 (preparado)

	resc	lw
	ld	a,(CALLEXE)
	or	a
	jr	z,NOCEXE

	xor	a	;Si se retorna de un programa
	;                        ;ejecutado con CALL EXE, hay que
	ld	(CALLEXE),a	;poner (ZVAL) a 1 (=comando procesado)
	;                        ;antes de liberar el servidor
	inc	a
	ddir	iw
	ld	(ZVAL),a
	dw	#4000

NOCEXE:	ddir	iw	;Liberamos el servidor si no ha sido
	ld	a,(S_ACTION)	;liberado ya antes
	dw	#4000
	or	a
	jr	z,OKFSERV

WFSERV:	ddir	iw	;Antes de liberar el servidor,
	ld	a,(S_ACTION)	;hay que esperar a que (S_ACTION) = 2
	dw	#4000
	cp	2
	jr	nz,WFSERV

	xor	a	;Para liberar el servidor ponemos 0
	ddir	iw	;en (S_ACTION)
	ld	(S_ACTION),a
	dw	#4000

OKFSERV:	resc	lw
	frame0	sp,0
	ld	sp,(MAXDIR)

	setc	lw
	ddir	iw
	ld	hl,Z380ST
	dw	BIPORT
	LD	(HL),0

	;--- Espera sin hacer nada hasta que el MSX le envie un comando
	;    (mientras, ejecuta gancho #FFF8)

ESPERA:	call	#FFF8	;Debe preservar HL
	setc	lw
	LD	A,(HL)
	AND	A
	JR	Z,ESPERA

	pushi	0
	pushi	3	;Equivalente a CALL EJECUT : JP 3
	jp	6


;--> Se puede acceder aqui con CALL 6 (poniendo el comando en A, no en Z380ST)

MAXCOM:	equ	14	;Numero maximo de comando

EJECUT:	;--- Ejecuta comando

	setc	lw
	call	#FFF0	;Debe preservar A si no hace nada...
	or	a
	jp	z,3	;...o devolver A=0 si ejecuta su
	ddir	lw	;propio codigo.
	ld	hl,0
	resc	lw
	ddir	iw.lw
	ld	ix,0
	dw	#4000

	or	a	;No hace nada si el comando no existe
	ret	z
	cp	MAXCOM+1
	ret	nc

	ld	l,a
	slaw	hl
	addwi	EJ_BASE
	ldrm	hl,(hl)
	setc	lw
	ddir	w
	jp	(hl)

EJ_BASE:	dw	#0003
	dw	PEEK	;1
	dw	POKE	;2
	dw	EXE	;3
	dw	GET	;4
	dw	PUT	;5
	dw	OUT0	;6
	dw	IN0	;7
	dw	BCLEAR	;8
	dw	ZMODE	;9
	dw	CALLHAND	;10
	dw	SETSSPC	;11
	dw	PUTCODE	;12
	dw	COMPCALL	;13
	dw	CALLPAR	;14


	;--- Llega hasta aqui si el comando es desconocido

	ret


	;--- Comando PEEK (1)
	;    Entrada: (ZDIR3) = Direccion
	;    Salida:  (ZVAL)  = Dato
	;    Registros modificados a la salida:
	;    IX = #40000000
	;    AF, DE, HL

PEEK:	call	GETDIR	;Hace PEEK de 8 o 16 bits
	resc	lw
	ldrm	hl,(de)
	jr	nc,PEEK16
PEEK8:	ld	h,0
PEEK16:	ldmr	(ix+ZVAL),hl
	ret


	;GETDIR: Devuelve DE=(ix+ZDIR_3), y Cy=0 si es de 16 bits

GETDIR:	ldrm	de,(ix+ZDIR_3)
	swap	de
	ld	a,d
	swap	de
	and	%11000000
	cp	#C0
	scf
	ret	nz
	bit	0,e
	ret	nz
	ccf
	ret


	;--- Comando POKE (2)
	;    Entrada: (ZDIR3) = Direccion
	;             (ZVAL)  = Dato
	;    Registros modificados a la salida:
	;    IX = #40000000
	;    AF, DE, HL

POKE:	call	GETDIR	;Hace POKE de 8 o 16 bits
	resc	lw
	jr	nc,POKE16
POKE8:	ld	a,(ix+ZVAL)
	ld	(de),a
	ret
POKE16:	ldrm	hl,(ix+ZVAL)
	ldmr	(de),hl
	ret


	;--- Comando EXE (3)
	;    Entrada: (ZDIR3) = Direccion (4 bytes)

;Antes de ejecutar el programa:
;- El banco de registros 0 es seleccionado
;- Pone la parte alta de todos los registros a 0
;- Pone el modo "word"
;- Establece las direcciones de salto de trapping a #0003
;- La pila contendra #00000003
;- Espera a que el MSX este en modo server (S_ACTION=2)

;El programa puede terminar con RET si mantiene la pila original, o con JP 3

EXE:	resc	lw
	ldctli	sr,0
	ld	hl,#0003
	ldmr	(ix+TRAPFDIR),hl
	ldmr	(ix+TRAPIDIR),hl
	setc	lw
	ldrm	hl,(ix+ZDIR_3)
	ld	(DO_EXE+1),hl

	ld	hl,0
	ld	bc,0
	ld	de,0
	ld	ix,0
	ld	iy,0
	exall
	ld	hl,0
	ld	bc,0
	ld	de,0
	ld	ix,0
	ld	iy,0
	exall
	resc	lw

WFSERV2:	ddir	iw	;Espera a que el serv. este preparado
	ld	a,(S_ACTION)
	dw	#4000
	cp	2
	jr	nz,WFSERV2

	ddir	iw
DO_EXE:	JP	0	;Aqui se copia la dir. a saltar
	dw	0	;(4 bytes)


	;--- Comando GET (4)
	;    Entrada: (ZDIR3) = Direccion origen en Z380
	;             (ZBLON) = Longitud, maximo: (BLKLON)
	;    Salida:  Bloque copiado en (BLKDIR) de la biport
	;             (ZDIR_3) = (ZDIR_3) + (ZBLON)
	;    Registros modificados a la salida:
	;    IX = #40000000
	;    AF, BC, DE, HL, DE', HL'

GET:	resc	lw

	frame0	hl,BIPORT
	ldrm	hl,(ix+BLKDIR)	;Dir. de destino en biport
	andwi	#03FF
	ddir	lw
	ex	de,hl

	ldrm	bc,(ix+ZBLON)	;Longitud

	frame0	hl,BIPORT	;Dir. fuente en RAM
	ddir	lw
	ldrm	hl,(ix+ZDIR_3)

	;* Aqui ya estan listos HL, DE y BC.
	;  Ahora decidimos que tipo de transferencia realizamos
	;  (8 -> 8, o 16 -> 8)

	swap	hl	;16 -> 8 si origen >= #C0000000
	ld	a,h
	swap	hl
	and	%11000000
	cp	#C0
	jr	nz,GET88

	;* Transferencia 16->8:
	;- Si la direccion de origen es par,
	;  no esta permitido que BC = 3n + 1 (cortamos dir. de 16 bits),
	;  si es asi sumamos 1 a BC.
	;- Si la direccion de origen es impar,
	;  lo mismo con BC = 3n + 2.

	setc	lw
	exr	hl,hl.
	exr	de,de.
	ldrr	hl,bc
	ld	de,3
	resc	lw
	divuw	de
	swap	hl
	ld	e,l	;E = Resto de BC/3 (BC = 3n + E)
	swap	hl

	ddir	lw
	exr	hl,hl.
	ld	a,l
	and	%1
	inc	a	;A = 2 si dir. impar, 1 si dir. par
	cp	e
	jr	nz,OKGET1

	inc	bc	;Inc. BC si A=E (BC prohibido)
	ldmr	(ix+ZBLON),bc
OKGET1:	;

	ddir	lw
	exr	de,de.

	cp	2	;Empezamos por dir. par o impar?
	jr	z,GET_O

GET_E:	ldiw
	jp	po,ENDGET
	dec	hl
GET_O:	ldi
	jp	po,ENDGET
	jr	GET_E

	;* Transferencia 8->8 normal:

GET88:	ldir

	;* Fin de la transferencia

ENDGET:	ddir	lw
	ldmr	(ix+ZDIR_3),hl

	ret


	;--- Comando PUT (5)
	;    Entrada: (ZDIR_3) = Direccion destino en Z380
	;             (ZBLON) = Longitud, maximo: (BLKLON)
	;    Salida:  Bloque copiado desde (BLKDIR) de la biport
	;             (ZDIR_3) = (ZDIR_3) + (ZBLON)
	;    Registros modificados a la salida:
	;    IX = #40000000
	;    AF, BC, DE, HL, DE', HL'

PUT:	resc	lw

	frame0	hl,BIPORT
	ldrm	hl,(ix+BLKDIR)	;Dir. fuente en biport
	andwi	#03FF

	ldrm	bc,(ix+ZBLON)	;Longitud

	ddir	lw	;Dir. destino en RAM
	ldrm	de,(ix+ZDIR_3)

	;* Aqui ya estan listos HL, DE y BC.
	;  Ahora decidimos que tipo de transferencia realizamos
	;  (8 -> 8, o 8 -> 16)

	swap	de	;8 -> 16 si origen >= #C0000000
	ld	a,d
	swap	de
	and	%11000000
	cp	#C0
	jr	nz,PUT88

	;* Transferencia 8->16:
	;- Si la direccion de destino es par,
	;  no esta permitido que BC = 3n + 1 (cortamos dir. de 16 bits),
	;  si es asi sumamos 1 a BC.
	;- Si la direccion de destino es impar,
	;  lo mismo con BC = 3n + 2.

	setc	lw
	exr	hl,hl.
	exr	de,de.
	ldrr	hl,bc
	ld	de,3
	resc	lw
	divuw	de
	swap	hl	;L = Resto de BC/3 (BC = 3n + E)

	ddir	lw
	exr	de,de.
	ld	a,e
	and	%1
	inc	a	;A = 2 si dir. impar, 1 si dir. par
	cp	l
	jr	nz,OKPUT1

	inc	bc	;Inc. BC si A=E (BC prohibido)
	ldmr	(ix+ZBLON),bc
OKPUT1:	;

	ddir	lw
	exr	hl,hl.

	cp	2	;Empezamos por dir. par o impar?
	jr	z,PUT_O

PUT_E:	ldiw
	jp	po,ENDPUT
	dec	de
PUT_O:	ldi
	jp	po,ENDPUT
	jr	PUT_E

	;* Transferencia 8->8 normal:

PUT88:	ldir

	;* Fin de la transferencia

ENDPUT:	ddir	lw
	ldmr	(ix+ZDIR_3),de

	ret


	;--- Comando OUT0 (6)
	;    Entrada: (ZDIR_3) = Puerto
	;             (ZVAL)   = Dato
	;    Registros modificados a la salida:
	;    IX = #40000000
	;    AF, C, HL

OUT0:	resc	lw
	ld	c,(ix+ZDIR_3)
	ldrm	hl,(ix+ZVAL)
COM6D:	outw	(c),hl
	ret


	;--- Comando IN0 (7)
	;    Entrada: (ZDIR_3) = Puerto
	;    Salida:  (ZVAL)   = Dato
	;    Registros modificados a la salida:
	;    IX = #40000000
	;    AF, C, HL

IN0:	resc	lw
	frame0	ix,BIPORT
	ld	a,(ix+ZDIR_3)
	ld	c,a
	inw	hl,(c)
	ldmr	(ix+ZVAL),hl
	ret
FIN:	;


	;--- Comando BCLEAR (8)
	;    Entrada: (ZDIR_M) = Nueva direccion de inicio de la
	;                        zona de usuario en biport, o 0
	;    Salida:  (USRDIR) = (ZDIR_M)
	;             (BLKLON) = (USRDIR) - (BLKDIR)
	;             OJO: (BLKLON) se redondea a multiplo de 3
	;    Registros modificados a la salida:
	;    IX = #40000000
	;    AF, DE, HL


BCLEAR:	resc	lw
	ldrm	hl,(ix+ZDIR_M)	;Coge nueva dir. para USRDIR
	orw	hl
	jr	z,BC0
	andwi	#03FF
	orwi	#4000	;Adecua al rango #4000-#43FF si no es 0
BC0:	;

	ldmr	(ix+USRDIR),hl	;(USRDIR) <- Nueva dir. de inicio, o 0
	orw	hl
	jr	nz,BC1
	ld	hl,#4400
BC1:	;

	ldrm	de,(ix+BLKDIR)	;(BLKLON) <- USRDIR - BLKDIR
	subw	de	;HL = Longitud sin redondear

	swap	hl	;Lo redondea a multiplo de 3
	ld	hl,0	;para que las transferencias largas
	swap	hl	;sean consistentes
	ld	de,3
	divuw	de
	multw	de
	ldmr	(ix+BLKLON),hl

	ret


	;--- Comando ZMODE (9)
	;    Si (ZVAL)=0   -> Devuelve en ZVAL el modo actual del Z380
	;                     (0 = Nativo, #FF = Extendido)
	;    Si (ZVAL=#FF) -> Pone el Z380 en modo extendido
	;    Registros modificados a la salida:
	;    IX = #40000000
	;    AF, BC, HL

ZMODE:	resc	lw
	ld	a,(ix+ZVAL)
	or	a
	jr	z,MODE0
	cp	#FF
	ret	nz

MODEFF:	mtest
	ret	m	;Equivale a RET S

	pop	hl	;Para que haga el RET correctamente
	pushi	0	;(en modo extendido, ha de haber
	push	hl	;4 bytes en la pila indicando la
	setc	xm	;direccion de retorno;
	ret		;                ;en modo nativo, solo 2)

MODE0:	xor	a
	mtest		;Pone flag S (bit 7 de F) a 1 si esta en modo extendido
	push	af
	pop	bc
	bit	7,c
	jr	z,OKMODE
	ld	a,#FF
OKMODE:	ld	(ix+ZVAL),a
	ret


	;--- Comando CALLHAND (10)
	;    Es ejecutado al hacer un CALL desde BASIC

CALLHAND:	setc	lw	;Actua como si se hubiera ejecutado
	ld	hl,CALLZONE	;un EXE a CALLZONE
	ldmr	(ix+ZDIR_3),hl
	ld	a,3
	jp	6


	;--- Comando SETSSPC (11)
	;    Entrada: (ZVAL) = Nuevo tamanyo de la zona reservada
	;                      para el servidor.
	;                      Con -1 reserva el maximo posible
	;    Salida:  (BLKDIR)  = (BLKDIR) + (ZVAL)
	;             (SERVSPC) = (ZVAL)
	;             (BLKLON)  = (USRDIR) - (BLKDIR) redondeado a mlt. 3
	;    Registros modificados a la salida:
	;    IX = #40000000
	;    AF, BC, DE, HL
	;    Tambien modifica (ZDIR_M)

SETSSPC:	resc	lw
	ldrm	hl,(ix+ZVAL)
	cpwi	-1
	jr	nz,NOSMAX

	ldrm	hl,(ix+USRDIR)	;Si se especifica -1, se toma
	orw	hl	;la max. lon. posible-3
	jr	nz,NOSUSR
	ld	hl,#4400
NOSUSR:	ldrm	de,(ix+S_C_DIR)
	subw	de
	dec	hl
	dec	hl
	dec	hl

NOSMAX:	ldmr	(ix+SERVSPC),hl
	ldrm	bc,(ix+S_C_DIR)
	add	hl,bc
	ldmr	(ix+BLKDIR),hl

	ldrm	hl,(ix+USRDIR)
	ldmr	(ix+ZDIR_M),hl
	ld	a,8	;Hace un BCLEAR
	call	6

	ret


	;--- Comando PUTCODE (12)
	;    Entrada: (ZDIR_3) = Direccion del codigo a insertar
	;                        en la zona del server
	;                        (2 bytes para long. + codigo en si)
	;    Registros modificados a la salida:
	;    IX = #40000000
	;    AF, BC, DE, HL

PUTCODE:	setc	lw
	ldrm	hl,(ix+ZDIR_3)
	ld	bc,0
	resc	lw
	ldrm	bc,(hl)
	inc	hl
	inc	hl
	ld	de,#4000
	swap	de
	ldrm	de,(ix+S_C_DIR)
	res	6,d

	ldir
	ret


	;--- Comando COMPCALL (13)
	;    Entrada: (ZDIR_3) = Tabla de CALLs
	;             Comando a comparar en CALLNAM
	;    Salida:  (ZVAL+1) = Numero de CALL en la lista,
	;                        0 si no figura
	;    Registros modificados a la salida:
	;    IX = #40000000
	;    AF, BC, DE, HL

COMPCALL:	setc	lw
	ldrm	hl,(ix+ZDIR_3)
	ld	b,1

CCLOOP:	ld	de,CALLNAM
CCLOP2:	ld	a,(de)
	cp	(hl)
	jr	nz,CCDIF
	inc	de
	inc	hl
	or	a
	jr	nz,CCLOP2
	ld	(ix+ZVAL+1),b
	resc	lw
	ret

CCDIF:	inc	b
	ld	c,&HFF
	xor	a
	cpir
	ld	a,(hl)
	or	a
	jr	nz,CCLOOP

	ld	(ix+ZVAL+1),0
	resc	lw
	ret


	;--- Comando CALLPAR (14)
	;    Entrada: (BASPNT) = Direccion del texto BASIC
	;             (ZVAL)   = 1 -> Extrae "("
	;                        2 -> Extrae ")"
	;                        3 -> Extrae ","
	;                        4 -> Extrae entero de 1 byte
	;                        5 -> Extrae entero de 2 bytes
	;                        6 -> Obtiene dir. de una variable
	;                        7 -> Evalua una expresion en el texto
	;                        8 -> Registra una cadena
	;    Salida: (BASPNT) actualizado
	;            (ZVAL)    = Valor extraido (para 4 y 5)
	;                        Direccion de la variable (para 6)
	;                        Tipo de valor extraido (2, 3, 4 o 8)
	;                             y valor en DAC (#F7F6) (para 7)
	;                        Direccion del descriptor de la cadena
	;                             (para 8)
	;    Si hay un error, salta a "Syntax error";
	;       entonces (S_ACTION)=0 y el programa ha de terminar.
	;    Registros modificados a la salida:
	;    IX = #40000000
	;    AF, BC, DE, HL

CALLPAR:	ld	a,(ix+ZVAL)
	dec	a
	jr	z,CPAR_1
	dec	a
	jr	z,CPAR_2
	dec	a
	jr	z,CPAR_3
	dec	a
	jr	z,CPAR_4
	dec	a
	jr	z,CPAR_5
	dec	a
	jr	z,CPAR_6
	dec	a
	jr16	z,CPAR_7
	dec	a
	jr16	z,CPAR_8
	jr16	t,SYNERR	;"Syntax error" si (ZVAL) no es 1-6

CPAR_1:	ld	a,"("
	jr	CP_123
CPAR_2:	ld	a,")"
	jr	CP_123
CPAR_3:	ld	a,","

CP_123:	resc	lw
	push	af
	ldrm	hl,(ix+BASPNT)
	call	MRBYTE
	pop	bc
	cp	b
	jr16	nz,SYNERR	;"Syntax error" si el caracter no es
	inc	hl	;el esperado
	ddir	iw
	ld	(BASPNT),hl
	dw	#4000
	jr16	t,CP_END

CPAR_5:	ld	ix,FRMQNT
	call	CP_45
CP_452:	ddir	iw
	ld	(ZVAL),de
	dw	#4000
	jr16	t,CP_END

CPAR_4:	ld	ix,GETBYT
	call	CP_45
	ld	d,0
	jr	CP_452

CP_45:	resc	lw
	ddir	iw
	ld	hl,(BASPNT)
	dw	#4000
	call	EXEMS2
	dw	CALBAS
	ddir	iw
	ld	(BASPNT),hl
	dw	#4000
	ret

CPAR_6:	resc	lw
	xor	a	;Primero pone SUBFLG a 0
	call	MWBYT2
	dw	SUBFLG
	ddir	iw
	ld	hl,(BASPNT)
	dw	#4000
	ld	ix,PTRGET
	call	EXEMS2
	dw	CALBAS
	ddir	iw
	ld	(BASPNT),hl
	dw	#4000
	ddir	iw
	ld	(ZVAL),de
	dw	#4000
	jr	CP_END

CPAR_7:	resc	lw
	ddir	iw
	ld	hl,(BASPNT)
	dw	#4000
	ld	ix,FRMEVL
	call	EXEMS2
	dw	CALBAS
	ddir	iw
	ld	(BASPNT),hl
	dw	#4000
	call	MRBYT2
	dw	VALTYP
	ddir	iw
	ld	(ZVAL),a
	dw	#4000
	jr	CP_END

CPAR_8:	resc	lw
	ld	ix,FRESTR
	call	EXEMS2
	dw	CALBAS
	ddir	iw
	ld	(ZVAL),hl
	dw	#4000
	jr	CP_END

SYNERR:	ld	ix,#406F	;Genera "Syntax error" y acaba
	ld	e,2
	call	EXEMS2
	dw	CALBAS
	jp	3

CP_END:	resc	lw
	ddir	iw.lw
	ld	ix,0
	dw	#4000
	ret


;********************************************
;***  RUTINA DE TRATAMIENTO DE LOS CALLS  ***
;********************************************

CALLZONE:	resc	lw

	call	MTOZ2	;Copia el nombre del comando
	dw	PROCNM	;de PROCNM a CALLNAM
	dw	CALLNAM,0
	dw	16

	xor	a
	ddir	iw
	ld	(ZVAL),a
	dw	#4000
	call	#FFE8	;Ejecuta primero CALL del usuario
	ddir	iw
	ld	a,(ZVAL)	;Termina si el gancho ya ha
	dw	#4000	;gestionado el CALL
	or	a
	ret	nz

	setc	lw	;Busca el CALL en la lista
	ld	hl,CALLST
	ddir	iw
	ld	(ZDIR_3),hl
	dw	#4000
	ld	a,13
	call	6

	ddir	iw
	ld	a,(ZVAL+1)
	dw	#4000
	or	a	;Termina si el CALL no esta en nuestra
	ret	z	;lista

	setc	lw
	dec	a	;Obtiene dir de ejecucion y ejecuta
	ld	hl,0	;el codigo para ese CALL
	ld	l,a
	slaw	hl
	ld	bc,CALDIRS
	add	hl,bc
	resc	lw
	ldrm	hl,(hl)
	jp	(hl)


	;--- Lista de CALLs

CALLST:	DB	"ZPEEK",0
	DB	"ZPOKE",0
	DB	"BPEEK",0
	DB	"BPOKE",0
	DB	"ZEXE",0
	DB	"ZGET",0
	DB	"ZPUT",0
	DB	"OUT0",0
	DB	"IN0",0
	DB	"BCLEAR",0
	db	0


	;--- Direcciones de los CALLs

CALDIRS:	dw	_ZPEEK
	dw	_ZPOKE
	dw	_BPEEK
	dw	_BPOKE
	dw	_ZEXE
	dw	_ZGET
	dw	_ZPUT
	dw	_OUT0
	dw	_IN0
	dw	_BCLEAR


	;--- CALL BPEEK (dir, var%)

_BPEEK:	ld	(ix+ZVAL),1	;Extrae "("
	ld	a,14
	call	6

	ld	(ix+ZVAL),5	;Extrae direccion a leer
	ld	a,14
	call	6
	ldrm	hl,(ix+ZVAL)
	push	hl

	ld	(ix+ZVAL),3	;Extrae ","
	ld	a,14
	call	6

	ld	(ix+ZVAL),6	;Obtiene direccion de la variable
	ld	a,14
	call	6

	ld	hl,#4000
	swap	hl
	pop	hl
	andwi	#03FF
	ld	e,(hl)	;E = Dato solicitado
	ld	d,0

	ldrm	hl,(ix+ZVAL)	;Escribe DE en la variable
	call	MWWORD

	ld	a,2	;Extrae ")"
	ddir	iw
	ld	(ZVAL),a
	dw	#4000
	ld	a,14
	call	6

	jr16	t,FCALL


	;--- CALL BPOKE (dir, var%)

_BPOKE:	ld	(ix+ZVAL),1	;Extrae "("
	ld	a,14
	call	6

	ld	(ix+ZVAL),5	;Extrae direccion a escribir
	ld	a,14
	call	6
	ldrm	hl,(ix+ZVAL)
	push	hl

	ld	(ix+ZVAL),3	;Extrae ","
	ld	a,14
	call	6

	ld	(ix+ZVAL),4	;Extrae dato a escribir
	ld	a,14
	call	6

	ld	hl,#4000
	swap	hl
	pop	hl
	andwi	#03FF
	ld	a,(ix+ZVAL)	;Escribe dato
	ld	(hl),a

	ld	a,2	;Extrae ")"
	ddir	iw
	ld	(ZVAL),a
	dw	#4000
	ld	a,14
	call	6

	jr16	t,FCALL


	;--- CALL ZPEEK (dirh, dirl, var%)

_ZPEEK:	ld	(ix+ZVAL),1	;Extrae "("
	ld	a,14
	call	6

	ld	(ix+ZVAL),5	;Extrae direccion a leer (parte alta)
	ld	a,14
	call	6
	ldrm	hl,(ix+ZVAL)
	push	hl

	ld	(ix+ZVAL),3	;Extrae ","
	ld	a,14
	call	6

	ld	(ix+ZVAL),5	;Extrae direccion a leer (parte baja)
	ld	a,14
	call	6
	ldrm	hl,(ix+ZVAL)
	push	hl

	ld	(ix+ZVAL),3	;Extrae ","
	ld	a,14
	call	6

	ld	(ix+ZVAL),6	;Obtiene direccion de la variable
	ld	a,14
	call	6

	ddir	lw	;Pone la direccion a leer en (ZDIR_3)
	pop	hl
	ddir	lw
	ldmr	(ix+ZDIR_3),hl

	ldrm	hl,(ix+ZVAL)	;Guarda direccion de la variable
	push	hl

	ld	a,1
	call	6	;Hace el PEEK a traves de ZBIOS

	ldrm	de,(ix+ZVAL)
	pop	hl
	call	MWWORD	;Escribe el dato en la variable

	ld	a,2	;Extrae ")"
	ddir	iw
	ld	(ZVAL),a
	dw	#4000
	ld	a,14
	call	6

	jr16	t,FCALL


	;--- CALL ZPOKE (dirh, dirl, valor)

_ZPOKE:	ld	(ix+ZVAL),1	;Extrae "("
	ld	a,14
	call	6

	ld	(ix+ZVAL),5	;Extrae direccion a escr. (parte alta)
	ld	a,14
	call	6
	ldrm	hl,(ix+ZVAL)
	push	hl

	ld	(ix+ZVAL),3	;Extrae ","
	ld	a,14
	call	6

	ld	(ix+ZVAL),5	;Extrae direccion a escr. (parte baja)
	ld	a,14
	call	6
	ldrm	hl,(ix+ZVAL)
	push	hl

	ld	(ix+ZVAL),3	;Extrae ","
	ld	a,14
	call	6

	ld	(ix+ZVAL),5	;Obtiene dato a escribir
	ld	a,14
	call	6

	ddir	lw	;Pone la direccion a leer en (ZDIR_3)
	pop	hl
	ddir	lw
	ldmr	(ix+ZDIR_3),hl

	ld	a,2
	call	6	;Hace el POKE a traves de ZBIOS

	ld	a,2	;Extrae ")"
	ddir	iw
	ld	(ZVAL),a
	dw	#4000
	ld	a,14
	call	6

	jr16	t,FCALL


	;--- CALL ZEXE (dirh, dirl)

_ZEXE:	ld	(ix+ZVAL),1	;Extrae "("
	ld	a,14
	call	6

	ld	(ix+ZVAL),5	;Extrae direccion (parte alta)
	ld	a,14
	call	6
	ldrm	hl,(ix+ZVAL)
	push	hl

	ld	(ix+ZVAL),3	;Extrae ","
	ld	a,14
	call	6

	ld	(ix+ZVAL),5	;Extrae direccion (parte baja)
	ld	a,14
	call	6
	ldrm	hl,(ix+ZVAL)
	push	hl

	ld	a,2	;Extrae ")"
	ddir	iw
	ld	(ZVAL),a
	dw	#4000
	ld	a,14
	call	6

	ddir	lw	;Pone la direccion a leer en (ZDIR_3)
	pop	hl
	ddir	lw
	ldmr	(ix+ZDIR_3),hl

	ld	a,1
	ld	(CALLEXE),a

	ld	a,3	;Ejecuta el programa a traves de ZBIOS
	jp	6

CALLEXE:	db	0


	;--- CALL ZGET (origen_h, origen_l, destino, longitud)

_ZGET:	call	_ZGP
	call	ZTOM
	jr16	t,FCALL


	;--- CALL ZPUT (destino_h, destino_l, origen, longitud)

_ZPUT:	call	_ZGP
	ddir	lw
	ex	de,hl
	call	MTOZ
	jr16	t,FCALL


	;--- Codigo comun _ZGET y _ZPUT

_ZGP:	ld	(ix+ZVAL),1	;Extrae "("
	ld	a,14
	call	6

	ld	b,3
ZGLOP:	ld	a,b
	ld	(SAVEB),a
	ld	(ix+ZVAL),5	;Extrae parametros 1,2,3
	ld	a,14
	call	6
	ldrm	hl,(ix+ZVAL)
	push	hl
	ld	(ix+ZVAL),3	;Extrae ","
	ld	a,14
	call	6
	exr	b,b.
	ld	a,(SAVEB)
	ld	b,a
	djnz	ZGLOP

	ld	(ix+ZVAL),5	;Extrae parametro 4
	ld	a,14
	call	6
	ldrm	hl,(ix+ZVAL)
	push	hl
	ld	(ix+ZVAL),2	;Extrae ")"
	ld	a,14
	call	6

	pop	bc	;BC = Par. 4
	pop	de	;DE = Par. 3
	ddir	lw
	pop	hl	;HL = Par. 2, HLz = Par. 1

	ret

SAVEB:	db	0


	;--- CALL OUT0 (puerto, valor)

_OUT0:	ld	(ix+ZVAL),1	;Extrae "("
	ld	a,14
	call	6

	ld	(ix+ZVAL),4	;Extrae puerto
	ld	a,14
	call	6
	ldrm	hl,(ix+ZVAL)
	push	hl

	ld	(ix+ZVAL),3	;Extrae ","
	ld	a,14
	call	6

	ld	(ix+ZVAL),5	;Extrae valor
	ld	a,14
	call	6

	pop	hl	;Establece puerto
	ldmr	(ix+ZDIR_3),hl

	ld	a,6	;Hace el OUT0 a traves de ZBIOS
	call	6

	ld	(ix+ZVAL),2	;Extrae ")"
	ld	a,14
	call	6

	jr	FCALL


	;--- CALL IN0 (puerto, var%)

_IN0:	ld	(ix+ZVAL),1	;Extrae "("
	ld	a,14
	call	6

	ld	(ix+ZVAL),4	;Extrae puerto
	ld	a,14
	call	6
	ldrm	hl,(ix+ZVAL)
	push	hl

	ld	(ix+ZVAL),3	;Extrae ","
	ld	a,14
	call	6

	ld	(ix+ZVAL),6	;Extrae dir. de la variable
	ld	a,14
	call	6
	ldrm	hl,(ix+ZVAL)
	ex	(sp),hl

	ldmr	(ix+ZDIR_3),hl	;Hace el IN0 a traves de ZBIOS
	ld	a,7
	call	6

	pop	hl
	ldrm	de,(ix+ZVAL)
	call	MWWORD

	ld	a,2	;Extrae ")"
	ddir	iw
	ld	(ZVAL),a
	dw	#4000
	ld	a,14
	call	6

	jr	FCALL


	;--- CALL BCLEAR (direccion)

_BCLEAR:	ld	(ix+ZVAL),1	;Extrae "("
	ld	a,14
	call	6

	ld	(ix+ZVAL),5	;Extrae direccion
	ld	a,14
	call	6

	ldrm	hl,(ix+ZVAL)	;Ejecuta BCLEAR de ZBIOS
	ldmr	(ix+ZDIR_M),hl
	ld	a,8
	call	6

	ld	a,2	;Extrae ")"
	ddir	iw
	ld	(ZVAL),a
	dw	#4000
	ld	a,14
	call	6

	;jr      FCALL


	;--- Finalizacion comun de todos los CALLs

FCALL:	ld	a,1
	ddir	iw
	ld	(ZVAL),a
	dw	#4000
	ret


;***********************************
;***  RUTINAS DE USO DEL SERVER  ***
;***********************************

;--- MRBYTE (&H10): Lee en A un byte de la memoria del MSX, dir. HL
;                   Modifica: AF, BC, DE, IX
;                   Preserva HL
;                   Modifica (ZVAL)

_MRBYTE:	call	MREAD
	ddir	iw
	ld	a,(ZVAL)
	dw	#4000
	ret


;--- MRWORD (&H13): Lee en DE un byte de la memoria del MSX, dir. HL
;                   Modifica: AF, BC, DE, IX
;                   Preserva HL
;                   Modifica (ZVAL)

_MRWORD:	call	MREAD
	ddir	iw
	ld	de,(ZVAL)
	dw	#4000
	ret


;--- Codigo comun MRBYTE y MRWORD

MREAD:	ddir	w	;Establece direccion a leer
	ld	(MC1_DIR+1),hl

	setc	lw	;Copia el codigo a biport
	ld	hl,MCODE1
	ddir	iw
	ld	(ZDIR_3),hl
	dw	#4000
	ld	a,12
	call	6

	call	MEXE	;Ejecuta codigo
	ld	hl,(MC1_DIR+1)
	ret

	;--- Manda al MSX ejecutar el codigo, y espera a que acabe

MEXE:	call	MWAIT
	ld	a,1
	ddir	iw
	ld	(S_ACTION),a
	dw	#4000

MWAIT:	ddir	iw
	ld	a,(S_ACTION)
	dw	#4000
	or	a	;--->  ABORTA EL PROGRAMA SI EL SERVIDOR
	jp	z,3	;--->  HA SIDO LIBERADO PREVIAMENTE
	cp	2	;      O SI EL BASIC HA GENERADO UN ERROR
	jr	nz,MWAIT
	ret


;--- MWBYTE (&H16): Escribe el byte A en la memoria del MSX, dir. HL
;                   Modifica: AF, BC, DE, IX
;                   Preserva HL

_MWBYTE:	ddir	w
	ld	(MC2_DIR+1),hl
	ld	(MC2_A+1),a

	setc	lw	;Copia el codigo a biport
	ld	hl,MCODE2
	ddir	iw
	ld	(ZDIR_3),hl
	dw	#4000
	ld	a,12
	call	6

	call	MEXE
	ddir	lw
	ld	hl,0
	ld	hl,(MC2_DIR+1)
	ret


;--- MWWORD (&H19): Escribe el word DE en la memoria del MSX, dir. HL
;                   Modifica: AF, BC, DE, IX
;                   Preserva HL

_MWWORD:	resc	lw
	ld	(MC3_DIR+1),hl
	ld	(MC3_HL+1),de

	setc	lw	;Copia el codigo a biport
	ld	hl,MCODE3
	ddir	iw
	ld	(ZDIR_3),hl
	dw	#4000
	ld	a,12
	call	6

	call	MEXE
	ddir	lw
	ld	hl,0
	ld	hl,(MC3_DIR+1)
	ret


;--- MRPORT (&H1C): Lee en A del puerto C del MSX
;                   Modifica: AF, B, DE, HL, IX
;                   Preserva C
;                   Modifica (ZVAL)

_MRPORT:	ld	a,c
	ld	(MC4_P+1),a

	setc	lw	;Copia el codigo a biport
	ld	hl,MCODE4
	ddir	iw
	ld	(ZDIR_3),hl
	dw	#4000
	ld	a,12
	call	6

	call	MEXE

	ld	a,(MC4_P+1)
	ld	c,a
	ddir	iw
	ld	a,(ZVAL)
	dw	#4000
	ret


;--- MWPORT (&H1F): Escribe el dato A en el puerto C del MSX
;                   Modifica: AF, B, DE, HL, IX
;                   Preserva C

_MWPORT:	ld	(MC5_A+1),a
	ld	a,c
	ld	(MC5_P+1),a

	setc	lw	;Copia el codigo a biport
	ld	hl,MCODE5
	ddir	iw
	ld	(ZDIR_3),hl
	dw	#4000
	ld	a,12
	call	6

	call	MEXE
	ld	a,(MC5_P+1)
	ld	c,a
	ret


;--- EXEMSX (&H22): Ejecuta una rutina del MSX, direccion HLz
;                   Pasa los registros de entrada y devuelve los de salida
;                   Preserva HLz, devuelve BCz, DEz, IXz, IYz = 0
;                   Modifica (ZDIR_3), (ZVAL), (ZDIR_M), (ZBLON), (ZTLON)

_EXEMSX:	resc	lw	;Copia registros de entrada
	ld	(MC6_BC+1),bc
	ld	(MC6_DE+1),de
	ld	(MC6_HL+1),hl
	ld	(MC6_IX+2),ix
	ld	(MC6_IY+2),iy
	push	af
	pop	hl
	ld	(MC6_AF+1),hl

	swap	hl	;Copia direccion de la rutina
	ld	(MC6_DIR+1),hl

	ddir	lw
	ld	hl,MCODE6
	ddir	iw.lw
	ld	(ZDIR_3),hl
	dw	#4000
	ld	a,12
	call	6

	call	MEXE	;Ejecuta la rutina

	setc	lw
	ld	hl,0
	ld	de,0
	ld	bc,0
	ld	ix,0
	ld	iy,0
	resc	lw

	ddir	iw	;Copia los registros de salida
	ld	hl,(#11)
	dw	#4000
	push	hl
	pop	af
	ddir	iw
	ld	bc,(#13)
	dw	#4000
	ddir	iw
	ld	de,(#15)
	dw	#4000
	ddir	iw
	ld	hl,(#17)
	dw	#4000
	ddir	iw
	ld	ix,(#19)
	dw	#4000
	ddir	iw
	ld	iy,(#1B)
	dw	#4000

	ret


;--- ZTOM (&H25): Copia BC bytes de la memoria del Z380, dir. HL,
;                 a la memoria del MSX, dir. DE
;                 Modifica: AF, BC, DE, HL, IX
;                 Devuelve HL y DE incrementados por BC
;                 Modifica (ZDIR_3), (ZVAL), (ZDIR_M), (ZBLON), (ZTLON)

_ZTOM:	setc	lw	;Establece parametros
	push	hl,de,bc

	ld	hl,MCODE7	;Copia codigo MSX a biport
	ddir	iw
	ld	(ZDIR_3),hl
	dw	#4000
	ld	a,12
	call	6

	resc	lw	;Reserva espacio para el codigo
	ddir	iw
	ld	hl,(SERVSPC)
	dw	#4000
	ld	(OLD_SSP),hl
	ld	hl,MC7_END - MC7_ST
	ddir	iw
	ld	(ZVAL),hl
	dw	#4000
	ld	a,11
	call	6

	setc	lw
	pop	bc,de,hl
	ddir	iw
	ld	(ZDIR_3),hl
	dw	#4000
	resc	lw
	ddir	iw
	ld	(ZDIR_M),de
	dw	#4000
	ddir	iw
	ld	(ZTLON),bc
	dw	#4000

ZTOM3:	ddir	iw
	ld	hl,(ZTLON)	;Comprueba si quedan datos a transferir
	dw	#4000
	orw	hl
	jr	z,ZTOMEND

	call	DEC_LON	;Copia bloque con GET de ZBIOS
	ddir	iw
	ld	(ZBLON),bc
	dw	#4000
	ld	a,4
	call	6
	call	MEXE

	jr	ZTOM3

ZTOMEND:	ld	hl,(OLD_SSP)	;Restaura antiguo espacio para codigo
	ddir	iw
	ld	(ZVAL),hl
	dw	#4000
	ld	a,11
	call	6

	ddir	iw.lw
	ld	hl,(ZDIR_3)
	dw	#4000
	ddir	lw
	ld	de,0
	ddir	iw
	ld	de,(ZDIR_M)
	dw	#4000
	ret

	;--- Resta BLKLON a ZTLON, si sale <0, lo pone a 0
	;    Devuelve BC=BLKLON o la longitud restante.

DEC_LON:	ddir	iw
	ld	hl,(ZTLON)
	dw	#4000
	ddir	iw
	ld	bc,(BLKLON)
	dw	#4000
	and	a
	sbc	hl,bc
	jr	nc,CZP1
	ld	hl,0
	ddir	iw
	ld	bc,(ZTLON)
	dw	#4000
CZP1:	ddir	iw
	ld	(ZTLON),hl
	dw	#4000
	ret

OLD_SSP:	dw	0


;--- MTOZ (&H28): Copia BC bytes de la memoria del MSX, dir. HL,
;                 a la memoria del Z380, dir. DE
;                 Modifica: AF, BC, DE, HL, IX
;                 Devuelve HL y DE incrementados por BC
;                 Modifica (ZDIR_3), (ZVAL), (ZDIR_M), (ZBLON), (ZTLON)

_MTOZ:	setc	lw	;Establece parametros
	push	hl,de,bc

	ld	hl,MCODE8	;Copia codigo MSX a biport
	ddir	iw
	ld	(ZDIR_3),hl
	dw	#4000
	ld	a,12
	call	6

	resc	lw	;Reserva espacio para el codigo
	ddir	iw
	ld	hl,(SERVSPC)
	dw	#4000
	ld	(OLD_SSP),hl
	ld	hl,MC8_END - MC8_ST + 1
	ddir	iw
	ld	(ZVAL),hl
	dw	#4000
	ld	a,11
	call	6

	setc	lw
	pop	bc,de,hl
	ddir	iw
	ld	(ZDIR_3),de
	dw	#4000
	resc	lw
	ddir	iw
	ld	(ZDIR_M),hl
	dw	#4000
	ddir	iw
	ld	(ZTLON),bc
	dw	#4000

MTOZ3:	ddir	iw
	ld	hl,(ZTLON)	;Comprueba si quedan datos a transferir
	dw	#4000
	orw	hl
	jr	z,MTOZEND

	call	DEC_LON	;Copia bloque con GET de ZBIOS
	ddir	iw
	ld	(ZBLON),bc
	dw	#4000
	call	MEXE
	ld	a,5
	call	6

	jr	MTOZ3

MTOZEND:	ld	hl,(OLD_SSP)	;Restaura antiguo espacio para codigo
	ddir	iw
	ld	(ZVAL),hl
	dw	#4000
	ld	a,11
	call	6

	ddir	iw.lw
	ld	de,(ZDIR_3)
	dw	#4000
	ddir	lw
	ld	hl,0
	ddir	iw
	ld	hl,(ZDIR_M)
	dw	#4000

	ret


;--- MTOP (&H2B): Copia DE bytes desde la dir. HL del MSX, al puerto C
;                 Modifica: AF, BC, DE, HL, IX
;                 Devuelve HL incrementado por DE
;                 Modifica (ZDIR_M)

_MTOP:	ld	a,#B3	;OTIR: ED B3
	jr	MPPM


;--- PTOM (&H2E): Copia DE bytes desde el puerto C, hacia la dir. HL del MSX
;                 Modifica: AF, BC, DE, HL, IX
;                 Devuelve HL incrementado por DE
;                 Modifica (ZDIR_M)

_PTOM:	ld	a,#B2	;INIR: ED B2


;--- Codigo comun a MTOP y PTOM

MPPM:	ld	(MC9_IO1+1),a	;Establece OTIR o INIR
	ld	(MC9_IO2+1),a

	resc	lw
	ld	(MC9_HL+1),hl
	ld	(MC9_DE+1),de
	ld	a,c
	ld	(MC9_C+1),a

	setc	lw
	ld	hl,MCODE9	;Copia codigo MSX a biport
	ddir	iw
	ld	(ZDIR_3),hl
	dw	#4000
	ld	a,12
	call	6
	call	MEXE

	ddir	lw
	ld	hl,0
	ddir	iw.w
	ld	hl,(ZDIR_M)
	dw	#4000
	ret


;--- MRBYT2 (&H31): Lee en A un byte de la memoria del MSX
;                   Uso: CALL MRBYT2
;                        DW Direccion
;                   Modifica: AF, BC, DE, IX
;                   Preserva HL
;                   Modifica (ZVAL)

_MRBYT2:	ddir	lw
	ld	hl,MRB2_0
	jp	GETSPW
MRB2_0:	ddir	lw
	ldrr	hl,de
	jp	MRBYTE


;--- MRWOR2 (&H34): Lee en DE un word de la memoria del MSX
;                   Uso: CALL MRWOR2
;                        DW Direccion
;                   Modifica: AF, BC, DE, IX
;                   Preserva HL
;                   Modifica (ZVAL)

_MRWOR2:	setc	lw
	ld	hl,MRW2_0
	jp	GETSPW
MRW2_0:	ddir	lw
	ldrr	hl,de
	jp	MRWORD


;--- MWBYT2 (&H37): Escribe el byte A en la memoria del MSX
;                   Uso: CALL MWBYT2
;                        DW Direccion
;                   Modifica: AF, BC, DE, IX
;                   Preserva HL

_MWBYT2:	setc	lw
	ld	hl,MWB2_0
	jp	GETSPW
MWB2_0:	ddir	lw
	ldrr	hl,de
	jp	MWBYTE


;--- MWWOR2 (&H3A): Escribe el word DE en la memoria del MSX
;                   Uso: CALL MWWOR2
;                        DW Direccion
;                   Modifica: AF, BC, DE, IX, DE'
;                   Preserva HL

_MWWOR2:	setc	lw
	exr	de,de.
	ld	hl,MWW2_0
	jp	GETSPW
MWW2_0:	setc	lw
	ldrr	hl,de
	exr	de,de.
	jp	MWWORD


;--- MRPOR2 (&H3D): Lee en A un dato de un puerto del MSX
;                   Uso: CALL MRPOR2
;                        DB Puerto
;                   Modifica: AF, B, DE, HL, IX
;                   Preserva C
;                   Modifica (ZVAL)

_MRPOR2:	setc	lw
	ld	hl,MRPORT
	jp	GETSPB


;--- MWPOR2 (&H40): Escribe el dato A en un puerto del MSX
;                   Uso: CALL MWPOR2
;                        DB Puerto
;                   Modifica: AF, B, DE, HL, IX
;                   Preserva C

_MWPOR2:	setc	lw
	ld	hl,MWPORT
	jp	GETSPB


;--- EXEMS2 (&H43): Ejecuta una rutina del MSX
;                   Pasa los registros de entrada y devuelve los de salida
;                   Uso: CALL EXEMS2
;                        DW Direccion
;                   Pasa los registros de entrada y devuelve los de salida
;                   Preserva HLz, devuelve BCz, DEz, IXz, IYz = 0
;                   Modifica (ZDIR_3), (ZVAL), (ZDIR_M), (ZBLON), (ZTLON)

_EXEMS2:	exall
	ex	af,af
	ddir	lw
	ld	hl,EX2_2
	jp	GETSPW
EX2_2:	resc	lw
	push	de
	exall
	ex	af,af
	swap	hl
	pop	hl
	swap	hl
	jp	EXEMSX


;--- ZTOM2 (&H46): Transferencia de la memoria del Z380 a la del MSX
;                  Uso: CALL ZTOM2
;                       DW Origen(15..0)
;                       DW Origen(31..16)
;                       DW Destino
;                       DW Longitud
;                 Modifica: AF, BC, DE, HL, IX, HL', DE', BC'
;                 Devuelve HL y DE incrementados por BC
;                 Modifica (ZDIR_3), (ZVAL), (ZDIR_M), (ZBLON), (ZTLON)

_ZTOM2:	ddir	lw
	ld	hl,ZM2_0

	jp	GETSPW	;Obtiene origen(15..0) -> HL
ZM2_0:	ldrr	hl,de
	exr	hl,hl.
	ddir	lw
	ld	hl,ZM2_1

	jp	GETSPW	;Obtiene origen(32..16) -> HLz
ZM2_1:	exr	hl,hl.
	swap	hl
	ddir	w
	ldrr	hl,de
	swap	hl
	setc	lw
	exr	hl,hl.
	ld	hl,ZM2_2

	jp	GETSPW	;Obtiene destino -> DE
ZM2_2:	exr	de,de.
	ddir	lw
	ld	hl,ZM2_3

	jp	GETSPW	;Obtiene longitud -> BC
ZM2_3:	ldrr	bc,de
	exr	bc,bc.

	exx		;Recupera todos los parametros
	jp	ZTOM


;--- MTOZ2 (&H49): Transferencia de la memoria del MSX a la del Z380
;                  Uso: CALL MTOZ2
;                       DW Origen
;                       DW Destino(0..15)
;                       DW Destino(31..16)
;                       DW Longitud
;                 Modifica: AF, BC, DE, HL, IX, HL', DE', BC'
;                 Devuelve HL y DE incrementados por BC
;                 Modifica (ZDIR_3), (ZVAL), (ZDIR_M), (ZBLON), (ZTLON)

_MTOZ2:	ddir	lw
	ld	hl,MZ2_0

	jp	GETSPW	;Obtiene origen -> DE
MZ2_0:	exr	de,de.
	ddir	lw
	ld	hl,MZ2_1

	jp	GETSPW	;Obtiene destino(15..0) -> HL
MZ2_1:	ldrr	hl,de
	exr	hl,hl.
	ddir	lw
	ld	hl,MZ2_2

	jp	GETSPW	;Obtiene destino(32..16) -> HLz
MZ2_2:	exr	hl,hl.
	swap	hl
	ddir	w
	ldrr	hl,de
	swap	hl
	setc	lw
	exr	hl,hl.
	ld	hl,MZ2_3

	jp	GETSPW	;Obtiene longitud -> BC
MZ2_3:	ldrr	bc,de
	exr	bc,bc.

	exx		;Recupera todos los parametros
	ddir	lw	;Pone origen en HL y destino en DE
	ex	de,hl
	jp	MTOZ


;--- MTOP2 (&H4C): Envia un bloque de bytes desde la mem. del MSX, a un puerto
;                  Uso: CALL MTOP2
;                       DW Direccion origen
;                       DB Puerto destino
;                       DW Longitud
;                 Modifica: AF, BC, DE, HL, IX, HL'
;                 Devuelve HL incrementado por DE
;                 Modifica (ZDIR_M)

_MTOP2:	ddir	lw
	ld	hl,MP2_0

	jp	GETSPW	;Obtiene dir. origen -> HL
MP2_0:	ldrr	hl,de
	exr	hl,hl.
	ddir	lw
	ld	hl,MP2_1

	jp	GETSPB	;Obtiene puerto -> C
MP2_1:	ddir	lw
	ld	hl,MP2_2

	jp	GETSPW	;Obtiene longitud -> DE
MP2_2:	exr	hl,hl.
	jp	MTOP


;--- PTOM2 (&H4F): Lee un bloque de datos de un puerto a la memoria del MSX
;                  Uso: CALL PTOM2
;                       DB Puerto origen
;                       DW Direccion destino
;                       DW Longitud
;                 Modifica: AF, BC, DE, HL, IX, HL'
;                 Devuelve HL incrementado por DE
;                 Modifica (ZDIR_M)

_PTOM2:	ddir	lw
	ld	hl,PM2_0

	jp	GETSPB	;Obtiene puerto origen -> C
PM2_0:	ddir	lw
	ld	hl,PM2_1

	jp	GETSPW	;Obtiene dir. destino -> HL
PM2_1:	ldrr	hl,de
	exr	hl,hl.
	ddir	lw
	ld	hl,PM2_2

	jp	GETSPW	;Obtiene longitud -> DE
PM2_2:	exr	hl,hl.
	jp	PTOM


	;--- GETSPW: Devuelve en DE el word especificado como CALL : DW
	;            y actualiza la dir. de retorno de la pila
	;            Modifica IX, HL, DE
	;            Entrada: HL = Dir. de retorno de GETSPW,
	;                          se ha de llamar con JP

GETSPW:	setc	lw
	ld	ix,0
	ld	de,0
	mtest		;Estamos en modo nativo o extendido?
	jp	m,GSPW_E

GSPW_N:	resc	lw
GSPW_E:	ldrm	ix,(sp)	;IX = Dir. de retorno
	inc	ix	;(2/4 bytes para nativo/extendido)
	inc	ix
	ldmr	(sp),ix	;Nueva dir. de retorno = IX+2
	resc	lw
	ldrm	de,(ix+#FE)	;HL = Dato en el DW
	jp	(hl)


	;--- GETSPB: Devuelve en C el byte especificado como CALL : DB
	;            y actualiza la dir. de retorno de la pila
	;            Modifica IX
	;            Entrada: HL = Dir. de retorno de GETSPB,
	;                          se ha de llamar con JP

GETSPB:	setc	lw
	ld	ix,0
	mtest		;Estamos en modo nativo o extendido?
	jp	m,GSPB_E

GSPB_N:	resc	lw
GSPB_E:	ldrm	ix,(sp)	;IX = Dir. de retorno
	inc	ix	;(2/4 bytes para nativo/extendido)
	ldmr	(sp),ix	;Nueva dir. de retorno = IX+1
	ld	c,(ix-1)	;HL = Dato en el DB
	jp	(hl)


;*********************
;***  CODIGOS MSX  ***
;*********************

;--- MRBYTE y MRWORD

MCODE1:	dw	MC1_END - MC1_ST
MC1_ST:	;
MC1_DIR:	ld	hl,(0)
	ld	(ZVAL+#4000),hl
	ret
MC1_END:	;


;--- MWBYTE

MCODE2:	dw	MC2_END - MC2_ST
MC2_ST:	;
MC2_A:	ld	a,0
MC2_DIR:	ld	(0),a
	ret
MC2_END:	;


;--- MWWORD

MCODE3:	dw	MC3_END - MC3_ST
MC3_ST:	;
MC3_HL:	ld	hl,0
MC3_DIR:	ld	(0),hl
	ret
MC3_END:	;


;--- MRPORT

MCODE4:	dw	MC4_END - MC4_ST
MC4_ST:	;
MC4_P:	in	a,(0)
	ld	(ZVAL+#4000),a
	ret
MC4_END:	;


;--- MWPORT

MCODE5:	dw	MC5_END - MC5_ST
MC5_ST:	;
MC5_A:	ld	a,0
MC5_P:	out	(0),a
	ret
MC5_END:	;


;--- EXEMSX

MCODE6:	dw	MC6_END - MC6_ST
MC6_ST:	;
MC6_AF:	ld	hl,0
	push	hl
	pop	af
MC6_BC:	ld	bc,0
MC6_DE:	ld	de,0
MC6_HL:	ld	hl,0
MC6_IX:	ld	ix,0
MC6_IY:	ld	iy,0
MC6_DIR:	call	0
	ld	(#4013),bc
	ld	(#4015),de
	ld	(#4017),hl
	ld	(#4019),ix
	ld	(#401B),iy
	push	af
	pop	hl
	ld	(#4011),hl
	ret
MC6_END:	;


;--- ZTOM

MCODE7:	dw	MC7_END - MC7_ST
MC7_ST:	ld	hl,(BLKDIR+#4000)
	ld	de,(ZDIR_M+#4000)
	ld	bc,(ZBLON+#4000)
	ldir
	ld	(ZDIR_M+#4000),de
	ret
MC7_END:	;


;--- MTOZ

MCODE8:	dw	MC8_END - MC8_ST
MC8_ST:	ld	de,(BLKDIR+#4000)
	ld	hl,(ZDIR_M+#4000)
	ld	bc,(ZBLON+#4000)
	ldir
	ld	(ZDIR_M+#4000),hl
	ret
MC8_END:	;


;--- MTOP y PTOM

MCODE9:	dw	MC9_END - MC9_ST
MC9_ST:	;
MC9_HL:	ld	hl,0
MC9_DE:	ld	de,0
MC9_C:	ld	c,0
MC9_0:	ld	a,d
	or	a
	jr	z,MC9_1
	dec	d
	ld	b,0
MC9_IO1:	db	#ED,0	;OTIR o INIR
	jr	MC9_0
MC9_1:	cp	e
	jr	z,MC9_2
	ld	b,e
MC9_IO2:	db	#ED,0	;OTIR o INIR
MC9_2:	ld	(ZDIR_M+#4000),hl
	ret
MC9_END:	;


endall:	;
	end
