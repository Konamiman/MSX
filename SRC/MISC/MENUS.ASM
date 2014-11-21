;Dropdown menus engine.
;I'm not sure if this got to work at all...

;=======================

	;Menus desplegables
	;Konami Man. Empezado 6-2-96
	;Version ejecutable desde DOS

	org	#100
	jp	START

;------------
;* CONSTANTES
;------------

EXTINT:	EQU	0	;1 para ejecutar int. externas
ERAFNK:	EQU	#00CC	;Desactiva visualizacion teclas funcion
CLS:	EQU	#00C3	;Borra la pantalla
INITXT:	EQU	#006C	;Inicializa SCREEN 0
CALSLT:	EQU	#001C	;Llama a una subrutina en un slot
EXPTBL:	EQU	#FCC1	;Tabla de expansion de los slots 
LINLEN:	EQU	#F3B0	;Columnas en pantalla
VDPBF1:	EQU	&HF3DF	;r#0-7  del VDP
VDPBF2:	EQU	&HFFE7-8	;r#8-23 del VDP
NEWPAD:	EQU	#01AD	;(SUBROM) Lectura del raton
EXBRSA:	EQU	#FAF8	;Slot de la SUB-ROM 
TIMINT:	EQU	#FD9F	;Gancho de interrupcion del reloj 
XSAVE:	EQU	#FAFE	;Offset X del raton
YSAVE:	EQU	#FB00	;Offset Y del raton

;--- Caracteres graficos

GRF1:	EQU	24
GRF2:	EQU	18
GRF3:	EQU	25
GRF4:	EQU	20
GRF5:	EQU	21
GRF6:	EQU	19
GRF7:	EQU	26
GRF8:	EQU	17
GRF9:	EQU	27
GRF10:	EQU	23
GRF11:	EQU	22
GRF12:	EQU	248
GRF13:	EQU	133
GRF14:	EQU	35

;-----------
;* VARIABLES
;-----------

BASEBK:	dw	#0800	;Base de la tabla Blink

OFSX:	ds	1	;Offset leido en la ultima interrupcion
OFSY:	ds	1

CORDX:	ds	2	;Coordenada a la que apunta el puntero   
CORDY:	ds	2

POSX:	ds	1	;Posicion a la que apunta el puntero:   
POSY:	ds	1	;0 a 79 para X, 0 a 22 para Y   

OFSCARX:	ds	1	;Coordenadas del puntero respecto a la  
OFSCARY:	ds	1	;coordenada del caracter al que apunta:  
;                                      ;0 a 5 para X, 0 a 7 para Y

BOTON1:	ds	1	;255 si boton pulsado, 0 si no.    
BOTON2:	ds	1
BOTON:	ds	1

OLDX:	ds	1	;Posiciones de la anterior interrupcion   
OLDY:	ds	1

PUERTO:	db	2	;Puerto al que esta conectado el raton
CONTA:	ds	1	;Esta variable se incrementa hasta #FF.  

MINX:	dw	0	;Coordenadas maxima y minima alcanzables.
MAXX:	dw	79*6	;Han de ser programadas por el usuario  
MINY:	dw	0
MAXY:	dw	23*8

BKX:	db	0	;Coordenadas cursor BLINK  
BKY:	db	0

SC_BUF:	dw	_SC_BUF	;Inicio buffer de pantalla
BK_BUF:	dw	_BK_BUF	;Inicio buffer Blink

TAMTAB:	equ	4	;Tamagno tabla coordenadas
TITMARC:	db	0	;Titulo marcado
MAXMDESP:	db	3	;Maximo no. menus desplegables
NUMMDESP:	db	0	;Numero total de menus desplegados
NUMPR:	db	0	;Numero de menu principal desplegado
PRIMX:	db	0	;Coord. X del menu principal
PRIMY:	db	0	;Coord. Y del menu principal
MARCP:	db	0	;Numero de opcion marcada

NUMS1:	db	0	;Numero y coordenadas de los secundarios
SEC1X:	db	0	;(hasta tres)
SEC1Y:	db	0
MARCS1:	db	0
NUMS2:	db	0
SEC2X:	db	0
SEC2Y:	db	0
MARCS2:	db	0
NUMS3:	db	0
SEC3X:	db	0
SEC3Y:	db	0
MARCS3:	db	0

;----------------------------------
;* TABLA DE SALTO DE LAS SUBRUTINAS
;----------------------------------

;--- Rutinas de acceso a la VRAM

SET_VDP:	jp	_SET_VDP	;Prepara VDP para lectura o escritura  
SET_RD:	jp	_SET_RD	;Prepara VDP para lectura  
SET_WR:	jp	_SET_WR	;Prepara VDP para escritura  
RDVRM:	jp	_RDVRM	;Lee un dato  
WRVRM:	jp	_WRVRM	;Escribe un dato  
VPEEK:	jp	_VPEEK	;Lee un dato de la direccion especificada
VPOKE:	jp	_VPOKE	;Escribe un dato en la dir. especificada  
LDIRVR:	jp	_LDIRVR	;Copia un bloque VRAM-RAM  
LDIRRV:	jp	_LDIRRV	;Copia un bloque RAM-VRAM  
LDIRVV:	jp	_LDIRVV	;Copia un bloque VRAM-VRAM  
FILLVR1:	jp	_FILLVR1	;Llena la VRAM con un dato  
FILLVR2:	jp	_FILLVR2	; " a partir de la direccion especificada
BLK_BAS:	jp	_BLK_BAS	;Establece la direccion VRAM base del Bli 
BLK_CLS:	jp	_BLK_CLS	;Limpia la zona Blink  
BLK_COL:	jp	_BLK_COL	;Establece los colores Blink  
BLK_TIM:	jp	_BLK_TIM	;Establece el tiempo Blink  
BLK_ON:	jp	_BLK_ON	;Construye un bloque Blink  
BLK_OF:	jp	_BLK_OF	;Borra un bloque Blink  
BLK_ON1:	jp	_BLK_ON1	;Activa el Blink de un caracter  
BLK_OF1:	jp	_BLK_OF1	;Desactiva el Blink de un caracter  
BLK_SW:	jp	_BLK_SW	;Invierte el Blink de un caracter  
C_BLKAD:	jp	_C_BLKAD	;Calcula dir. VRAM para coord. Blink 
C_STBT:	jp	_C_STBT	;Calcula 1er bit coord. Blink 
C_VRAD:	jp	_C_VRAD	;Calcula dir. VRAM para una coordenada 
PRINT:	jp	_PRINT	;Impresion de una cadena
SC_BACK:	jp	_SC_BACK	;Guarda/restaura la pantalla
;BK_BACK:      jp      _BK_BACK         ;Guarda/restaura la tabla Blink

;--- Rutinas aritmeticas

DIVISION:	jp	_DIVISION	;Division de 16 bits  
POR80:	jp	_POR80	;Multiplica por 80  
POR10:	jp	_POR10	;Multiplica por 10 
COMP:	jp	_COMP	;Compara HL y DE en complemento a 2 

;--- Entrada/Salida

GMOUSE:	jp	_GMOUSE	;Lectura del raton 
RDPSG:	jp	_RDPSG	;Lectura de un registro del PSG 
WRPSG:	jp	_WRPSG	;Escritura en un registro del PSG 

;--- Tratamiento de menus desplegables

GETOPD:	jp	_GETOPD	;Obtiene dir. tabla datos de una opcion
GETIOP:	jp	_GETIOP	;Optiene informacion de una opcion
PUTBAR:	jp	_PUTBAR	;Muestra barra de menus
DESPMENU:	jp	_DESPMENU	;Despliega un menu
MARCAOP:	jp	_MARCAOP	;Marca una opcion de un menu
MARCATIT:	jp	_MARCATIT	;Marca un titulo de menu

;--- Varias

BIOS:	jp	_BIOS	;Llamada a una subrutina BIOS
SUBBIOS:	jp	_SUBBIOS	;Llamada a una subrutina SUB-BIOS

;----------------
;* INICIALIZACION
;----------------

;--- Ponemos modo texto 80 columnas

START:	;ld      a,(LINLEN)
	;push    af
	; ld      a,80
	; ld      (LINLEN),a

	;ld      ix,INITXT
	;call    BIOS

	;ld      ix,ERAFNK
	;call    BIOS

	;ld      ix,CLS
	;call    BIOS

;--- Inicializacion del Blink

	call	BLK_CLS
	ld	a,#5e
	call	BLK_COL
	ld	a,#f0
	call	BLK_TIM

;--- Inicializacion de las interrupciones

	di

	ld	hl,TIMINT
	ld	de,OLDINT
	ld	bc,5
	ldir

	ld	hl,NEWINT
	ld	de,TIMINT
	ld	bc,5
	; ldir

	ei

;--------------------
;* PROGRAMA PRINCIPAL (Prueba)
;--------------------

;FBED: 8=> RIGHT   DOWN   UP     LEFT   DEL    INS    HOME   SPACE

PRUEBA:	ld	a,1	;Saca titulo y despliega el primer menu
	ld	l,1
	call	PUTBAR
	ld	a,1
	call	MARCATIT
	ld	a,1
	call	DESPMENU
	ld	iy,NUMPR	;IY = inicio tabla coordenadas
	ld	e,1	;E = opcion a marcar ahora
	ld	b,1	;B=1/-1 -> Sentido descendente/ascend.
	ld	d,1
	or	a
	call	BEGINEA

CHKD:	ld	a,(#FBED)
	bit	6,a
	jr	nz,CHKU
	ld	b,1
	scf
	call	BEGINEA
	ld	e,d
	or	a
	call	BEGINEA
	call	PAUSA

CHKU:	ld	a,(#fbed)
	bit	5,a
	jr	nz,CHKS
	ld	b,-1
	scf
	call	BEGINEA
	ld	e,d
	or	a
	call	BEGINEA
	call	PAUSA

CHKS:	ld	a,(#fbed)
	bit	0,a
	jr	nz,CHKD

FINMARC:	ld	de,0
	call	MARCAOP
	xor	a
	call	MARCATIT
	xor	a
	call	DESPMENU

	di
	ld	hl,OLDINT
	LD	DE,TIMINT
	LD	BC,5
	LDIR
	EI

	ld	c,0	;#62
	jp	5

PAUSA:	ld	bc,10000	;Retardo
RETA:	dec	bc
	ld	a,b
	or	c
	jr	nz,RETA
	ret

;--- Marca una opcion. Si esta inhibida o es una barra de separacion,
;    marca la anterior (si B = -1) o la siguiente (si B = 1).
;    Si tampoco esta se puede, continua hasta enccontrar una opcion valida:
;    Entrada: E = Opcion a marcar
;             B = -1 o 1
;             CY=0 -> Marcar opcion E resultante
;             CY=1 -> No marcar
;    Salida:  E = Opcion marcada
;             D = Opcion siguiente, segun B
;             Modifica AF

BEGINEA:	push	iy,ix,bc,af
	call	BEGIN2
	ld	c,e
	ld	a,e
	add	b
	ld	e,a
	push	bc
	call	BEGIN2
	pop	bc
	ld	d,e
	ld	e,c

	pop	af
	ld	a,0
	push	de
	ld	d,0
	call	nc,MARCAOP
	pop	de
	pop	bc,ix,iy
	ret

BEGIN2:	ld	a,(ACTSMEN)	;Calcula opcion a marcar
	ld	d,0
	call	GETIOP
	bit	3,a	;Barra de separacion?
	jr	nz,CHKP
	bit	1,a	;Opcion inhibida?
	ret	z

CHKP:	bit	5,a	;Primera opcion?
	jr	z,CHKU2
	ld	a,b	;Si primera opcion y B = -1,
	cp	-1	;E = ultima opcion y vuelta a empezar.
	ld	c,e
	ld	e,(iy+2)
	jr	z,BEGIN2
	ld	e,c

CHKU2:	bit	4,a	;Ultima opcion?
	jr	z,SUMOREST
	ld	a,b	;Si ultima opcion y B = 1,
	cp	1	;E = primera opcion y vuelta a empezar.
	ld	c,e
	ld	e,1
	jr	z,BEGIN2
	ld	e,c

SUMOREST:	ld	a,e
	add	b
	ld	e,a
	jr	BEGIN2

;------------
;* SUBRUTINAS
;------------

;--- Preparacion del VDP para lectura o escritura de VRAM
;    Entrada: A = %0S00000P
;                 P = bit 17 de la direccion VRAM
;                 S = 0 para lectura de VRAM, 1 para escritura
;             HL= direccion VRAM, 16 bits bajos
;             Modifica AF y HL

_SET_VDP:	di
	push	de,af
	and	%00000001
	ld	e,l
	ld	d,h	;E=%b7 ... b0 
	or	a

	rl	h
	rla
	rl	h
	rla
	and	%00000111	;A=%00000 P b15 b14 
	ld	l,a

	res	7,d	;D=%0 S b13 ... b8 
	res	6,d
	pop	af
	and	%01000000
	or	d
	ld	d,a
	ld	a,l

	out	(#99),a
	ld	a,14or128
	out	(#99),a
	ld	a,e
	out	(#99),a
	ld	a,d
	out	(#99),a

	pop	de
	ei
	ret

;--- Preparacion del VDP para lectura de VRAM
;    Entrada: HL = direccion VRAM, 16 bits bajos
;             CY = direccion VRAM, bit 17
;             Modifica AF y HL

_SET_RD:	ld	a,0
	jr	nc,PAG1R
PAG0R:	ld	a,1
PAG1R:	jp	SET_VDP

;--- Preparacion del VDP para escritura en VRAM
;    Entrada: HL = direccion VRAM, 16 bits bajos
;             CY = direccion VRAM, bit 17
;             Modifica AF y HL

_SET_WR:	ld	a,64
	jr	nc,PAG1W
PAG0W:	ld	a,65
PAG1W:	jp	SET_VDP

;--- Lectura de un dato de VRAM
;    Entrada: direccion establecida con SET_VDP
;    Salida:  A = dato

_RDVRM:	in	a,(#98)
	ret

;--- Escritura de un dato en VRAM
;    Entrada: direccion establecida con SET_VDP
;             A = dato

_WRVRM:	out	(#98),a
	ret

;--- Lectura de un dato de VRAM con especificacion de direccion
;    Entrada: CY-HL = direccion VRAM
;    Salida:  A  = dato
;             Modifica AF y HL

_VPEEK:	call	SET_RD
	di
	in	a,(#98)
	ei
	ret

;--- Escritura de un dato en VRAM con especificacion de direccion
;    Entrada: CY-HL = direccion VRAM
;             A  = dato
;             Modifica HL y AF

_VPOKE:	push	af
	call	SET_WR
	di
	pop	af
	out	(#98),a
	ret

;--- Copia de un bloque de datos de VRAM a RAM
;    Entrada: direccion VRAM establecida con SET_RD
;             DE = destino RAM
;             BC = longitud
;    Salida:  bloque de datos a partir de (DE)
;             DE = direccion siguiente al final del bloque
;             Modifica AF

_LDIRVR:	push	hl,de,bc
	di
	ex	de,hl
	ld	d,b
	ld	e,c
	ld	c,#98
BUCLDVR:	ini
	dec	de
	ld	a,d
	or	e
	jr	nz,BUCLDVR
	ei
	pop	bc,de,hl
	ret

;--- Copia de un bloque de datos de RAM a VRAM
;    Entrada: direccion VRAM establecida con SET_WR
;             HL = origen RAM
;             BC = longitud
;    Salida:  HL = direccion siguiente al final del bloque
;             Modifica AF

_LDIRRV:	push	de,bc
	di
	ld	d,b
	ld	e,c
	ld	c,#98
BUCLDRV:	outi
	dec	de
	ld	a,d
	or	e
	jr	nz,BUCLDRV
	pop	bc,de
	ei
	ret

;--- Copia de un bloque de datos de VRAM a VRAM
;    Entrada: HL = origen, 16 bits bajos
;             DE = destino, 16 bits bajos
;             BC = longitud
;             A  = %000000 D O, bit 17 de Origen y Destino
;             IX = buffer RAM de BC bytes
;             Modifica AF, HL y DE

_LDIRVV:	rra
	push	af
	call	SET_RD
	di
	push	de,ix
	pop	de
	call	LDIRVR
	di
	pop	hl,af
	rra
	call	SET_WR
	di
	push	ix
	pop	hl
	jp	LDIRRV

;--- Llenado de una porcion de VRAM con un dato
;    Entrada: direccion inicial establecida con SET_WR
;             BC = longitud
;             A  = dato
;             No modifica registros

_FILLVR1:	di
	push	bc,de,af
BUCFL1:	out	(#98),a
	ld	d,a
	dec	bc
	ld	a,b
	or	c
	ld	a,d
	jr	nz,BUCFL1
	pop	af,bc,de
	ei
	ret

;--- Llenado de una porcion de VRAM con especificacion de direccion
;    Entrada: CY-HL: direccion VRAM
;             BC = longitud
;             A  = dato
;             Modifica AF y HL

_FILLVR2:	di
	push	af
	call	SET_WR
	di
	pop	af
	jp	FILLVR1

;--- Blink: establecimiento de la direccion base (#800 por defecto)
;    Entrada: HL = direccion base (multiplo de 512 = #200)
;             Modifica AF

_BLK_BAS:	XOR	A
	di
	LD	(BASEBK),A
	LD	A,H
	AND	&HFE
	LD	(BASEBK+1),A
	RLCA
	RLCA
	AND	&HF8
	OR	&H07
	DI
	LD	(VDPBF1+3),A
	OUT	(&H99),A
	LD	A,3 OR &H80
	OUT	(&H99),A
	ei
	RET

;--- Limpieza de la zona Blink
;    Modifica AF y HL

_BLK_CLS:	push	bc
	LD	a,(BASEBK)
	ld	l,a
	LD	a,(BASEBK+1)
	ld	h,a
	xor	a
	ld	bc,512
	call	FILLVR2
	pop	bc
	ret

;--- Establecimiento del color Blink
;    Entrada: A = color texto + 16* color fondo
;    Modifica A

_BLK_COL:	di
	OUT	(&H99),A
	LD	A,&H80+12
	OUT	(&H99),A
	ei
	RET

;--- Establecimiento del tiempo Blink
;    Entrada: A = tiempo ON + 16* tiempo OFF
;    Modifica A


_BLK_TIM:	di
	OUT	(&H99),A
	LD	A,&H80+13
	OUT	(&H99),A
	ei
	RET

;--- Blink ON
;    Entrada: HL = XXYY
;             B  = longitud X
;             C  = longitud Y
;    Salida:  L  = YY siguiente a la ultima linea
;             Modifica AF

_BLK_ON:	di
	push	bc,de
BUCBKON:	push	hl,bc
	ld	a,h
	call	C_STBT
	ld	e,a	;HL = direccion VRAM inicial 
	call	C_BLKAD	;E tiene el bit inicial puesto a 1 

BLON.1:	push	hl
	or	a
	call	VPEEK
	di
	pop	hl
	push	hl,af	;A = contenido de (HL) [VRAM] 
	or	a
	CALL	SET_WR	;VDP preparado para escribir en (HL) 
	di
	POP	AF,hl

BLON.0:	OR	E
	RRC	E
	JR	NC,BLON.2
	OUT	(&H98),A
	INC	HL
	DJNZ	BLON.1
	jr	OTRALIN1
	RET
BLON.2:	DJNZ	BLON.0
	OUT	(&H98),A

OTRALIN1:	pop	bc,hl
	inc	l
	dec	c
	ld	a,c
	or	a
	jr	nz,BUCBKON
	pop	de,bc
	ei
	RET

;--- Blink OFF
;    Entrada: HL = XXYY
;             B  = longitud X
;             C  = longitud Y
;    Salida:  L  = YY siguiente a la ultima linea
;             Modifica AF

_BLK_OF:	di
	push	bc,de
BUCBKOF:	push	hl,bc
	ld	a,h
	call	C_STBT
	cpl
	ld	e,a	;HL = direccion VRAM inicial 
	call	C_BLKAD	;E tiene el bit inicial a 1 

BLOF.1:	push	hl
	call	VPEEK
	di
	pop	hl
	push	hl,af	;A = contenido de (HL) [VRAM]  
	CALL	SET_WR	;VDP preparado para escribir en (HL)  
	di
	POP	AF,hl

BLOF.0:	AND	E
	RRC	E
	JR	C,BLOF.2
	OUT	(&H98),A
	INC	HL
	DJNZ	BLOF.1
	jr	OTRALIN2
	RET
BLOF.2:	DJNZ	BLOF.0
	OUT	(&H98),A

OTRALIN2:	pop	bc,hl
	inc	l
	dec	c
	ld	a,c
	or	a
	jr	nz,BUCBKOF
	ei
	pop	de,bc
	RET

;--- Blink ON para un solo caracter
;    Entrada: HL = XXYY
;    Modifica AF y HL

_BLK_ON1:	push	de
	ld	a,h
	call	C_STBT
	push	af
	call	C_BLKAD
	pop	de
	or	a
	push	hl
	call	VPEEK
	or	d
	pop	hl
	call	VPOKE
	pop	de
	ret

;--- Blink OFF para un solo caracter
;    Entrada: HL = XXYY
;    Modifica AF y HL

_BLK_OF1:	push	de
	ld	a,h
	call	C_STBT
	cpl
	push	af
	call	C_BLKAD
	pop	de
	or	a
	push	hl
	call	VPEEK
	and	d
	pop	hl
	call	VPOKE
	pop	de
	ret


;--- Blink SWAP para un solo caracter
;    Entrada: HL = XXYY
;    Modifica AF y HL

_BLK_SW:	push	de
	ld	a,h
	call	C_STBT
	push	af
	call	C_BLKAD
	pop	de
	or	a
	push	hl
	call	VPEEK
	xor	d
	pop	hl
	call	VPOKE
	pop	de
	ret

;--- Calculo de la direccion VRAM para una coordenada Blink
;    Entrada: HL = XXYY
;    Salida:  HL = direccion VRAM
;             Modifica AF

_C_BLKAD:	push	bc
	LD	A,H
	AND	&HF8
	RRCA
	RRCA
	RRCA
	ld	c,a
	ld	b,0	;BC = H/8 

	ld	h,0
	CALL	POR10	;HL = L*10 

	ADD	HL,BC
	LD	BC,(BASEBK)
	ADD	HL,BC
	pop	bc
	RET

;--- Calculo del bit de la direccion Blink.
;    Entrada: A = coordenada X
;    Salida:  A = bit puesto a 1
;             No modifica los registros

_C_STBT:	push	bc	; A mod 8
	AND	7
	LD	B,A
	inc	b	;--> Esto no estaba en el listado origina
	LD	A,&H80
CSTB.0:	RRCA
	DJNZ	CSTB.0
	pop	bc
	rlca
	RET

;--- Calculo de la direccion VRAM para una coordenada
;    Entrada: HL = XXYY
;    Salida:  HL = dir. VRAM
;             CY = 0
;             No modifica el resto de registros

_C_VRAD:	push	af,de,bc
	push	hl
	pop	de
	ld	h,0
	call	POR80
	ld	c,d
	ld	b,0
	add	hl,bc
	pop	bc,de,af
	or	a
	ret

;--- Impresion de una cadena
;    Entrada: HL = XXYY, coordenadas
;                  #FFFF para imprimir en las coordenadas actuales
;                  (direccion actual de VRAM)
;             DE = inicio del mensaje
;             CY = 0 y A = caracter de terminacion, o bien
;             CY = 1 y A = longitud de la cadena
;    Salida:  DE = caracter siguiente al de terminacion, o al ultimo
;             Direccion VRAM actualizada a despues de la cadena
;             Modifica AF

_PRINT:	push	bc,hl,af
	di
	inc	hl
	ld	a,h
	or	l
	jr	z,NOCOORD

SETCORD:	dec	hl
	call	C_VRAD
	call	SET_WR
	di

NOCOORD:	pop	af
	;push    af
	jr	c,CONLON

CONTER:	ld	a,(de)
	inc	de
	or	a
	jr	z,PREND
	out	(#98),a
	jr	CONTER

CONLON:	ld	b,a
PRINT1:	ld	a,(de)
	out	(#98),a
	inc	de
	djnz	PRINT1

PREND:	pop	hl,bc
	ei
	ret

;--- Copia/restauracion de la pantalla
;    Entrada: (SCBUF) = inicio del primer buffer
;             A = numero de buffer RAM (2048 bytes)
;             CY= 0 -> Grabar pantalla
;             CY= 1 -> Restaurar pantalla
;             Modifica Af

_SC_BACK:	di
	push	hl,de,bc,af
	ld	hl,(SC_BUF)
	ld	de,2048
	or	a
	sbc	hl,de
	ld	b,a
C_BUFSCD:	add	hl,de
	djnz	C_BUFSCD

	ex	de,hl	;HL = dir. VRAM
	ld	hl,0	;DE = dir. RAM
	ld	bc,2048	;BC = longitud
	pop	af
	jr	c,REST_SC

GRAB_SC:	or	a
	call	SET_RD
	di
	call	LDIRVR
	jr	FINSCBK

REST_SC:	or	a
	call	SET_WR
	di
	ex	de,hl
	call	LDIRRV

FINSCBK:	pop	bc,de,hl
	ret

;--- Division 16 bits por 16 bits
;    Entrada:  HL = dividendo
;              DE = divisor
;    Salida:   DE = cociente
;              BC = resto
;              No modifica HL ni A

_DIVISION:	push	hl,af
	ld	a,h
	ld	c,l

div16:	ld	hl,0
	ld	b,16
loop16:	rl	c
	rla
	adc	hl,hl
	sbc	hl,de
	jr	nc,$+3
	add	hl,de
	ccf
	djnz	loop16
	rl	c
	rla

	ld	d,a
	ld	e,c
	ld	b,h
	ld	c,l
	pop	af,hl
	ret

;--- Multiplicacion de un numero por 80
;    Entrada: HL = numero
;    Salida:  HL = numero por 80
;             No modifica los demas registros
;
_POR80:	push	de,bc,hl
	ld	b,6
ROTA1:	sla	l
	rl	h
	djnz	ROTA1
	ex	de,hl	;DE = numero por 64  

	pop	hl
	ld	b,4
ROTA2:	sla	l
	rl	h
	djnz	ROTA2
	add	hl,de
	pop	bc,de
	ret

;--- Multiplicacion de un numero por 10
;    Entrada: HL = numero
;    Salida:  HL = numero por 10
;             No modifica los otros registros

_POR10:	push	bc,hl
	ld	b,3
BUCP10:	sla	l	;Multiplicamos por dos tres veces   
	rl	h	;y sumamos dos veces   
	djnz	BUCP10
	pop	bc
	add	hl,bc
	add	hl,bc
	pop	bc
	ret

;--- Comparacion de HL con DE (16 bits en complemento a 2)
;    Entrada: HL, DE = numeros a comparar
;    Salida:   C, NZ si HL > DE
;             NC,  Z si HL = DE
;             NC, NZ si HL < DE
;             No modifica ningun registro

_COMP:	push	hl
	or	a
	sbc	hl,de
	pop	hl
	jp	p,HMAYD
HMEND:	scf
	ccf
	ret
HMAYD:	scf
	ret

;--- Lectura del raton (usa la SUB-ROM)
;    Entrada: A = puerto del raton a leer
;    Salida:  H = desplazamiento X
;             L = desplazamiento Y
;             D = #FF si se ha pulsado el boton 1, 0 si no
;             E = #FF si se ha pulsado el boton 2, 0 si no
;             A = #FF si se ha pulsado algun boton, 0 si no (A = D or E)
;             Modifica BC, IX, IY.

_GMOUSE:	ex	af,af

	ld	a,(EXBRSA)	;Conectamos slot SUB-ROM  
	ld	iyh,a
	ld	ix,NEWPAD

	ex	af,af	;Recuperamos puerto  
	push	af	;Guardamos puerto para GTTRIG  
	sla	a	;Si A=1 => lo transforma en 12  
	or	11	;Si A=2 => lo transforma en 15  
	inc	a

	call	CALSLT	;Pedimos los datos del raton  
	di

RDBOT:	pop	af	;Recuperamos puerto  
	or	a
	rrca
	rrca
	rrca
	and	%01000000
	ex	af,af

	ld	a,15
	call	RDPSG	;Preparamos para leer puerto A o B  
	and	%10001111
	ld	b,a
	ex	af,af
	or	b
	ld	e,a
	ld	a,15
	call	WRPSG

	ld	a,14	;Leemos puerto  
	call	RDPSG

	push	af
	bit	4,a
	ld	a,0
	ld	b,0
	jr	nz,B1NOPUL
B1PUL:	cpl
B1NOPUL:	ld	d,a
	or	b
	ld	b,a

	pop	af
	bit	5,a
	ld	a,0
	jr	nz,B2NOPUL
B2PUL:	cpl
B2NOPUL:	ld	e,a
	or	b
	ld	b,a

COMPREG:	ld	a,(XSAVE)	;HL indica los desplazamientos en X e Y
	ld	h,a
	ld	a,(YSAVE)
	ld	l,a

	ld	a,b
	ret

;--- Lectura de un puerto del PSG
;    Entrada: A = Puerto
;    Salida:  A = Dato
;             No modifica los demas registros

_RDPSG:	out	(#a0),a
	in	a,(#a2)
	ret

;--- Escritura en un puerto del PSG
;    Entrada: A = puerto
;             E = Dato
;             No modifica los demas registros

_WRPSG:	out	(#a0),a
	ld	a,e
	out	(#a1),a
	ret

;--- Obtencion de la direccion de inicio de una opcion de un menu
;    Entrada: A = sistema de menus
;             D = menu
;             E = opcion (0 = informacion general del menu)
;    Salida:  HL = direccion tabla de datos de la opcion
;             A  = error:
;                  0 -> no hay error
;                  1 -> no existe ese sistema
;                  2 -> no existe ese menu
;                  3 -> no existe esa opcion
;             Modifica AF, BC, IX

_GETOPD:	ld	ix,NUMSMEN
	cp	(ix)
	jr	c,OKNUMS
	jr	z,OKNUMS
ERRNUMS:	ld	a,1	;Error de num. de sistema
	ret

OKNUMS:	ld	c,a
	ld	b,a
GETOPD1:	inc	ix
	inc	ix
	inc	ix
	djnz	GETOPD1
	ld	l,(ix)
	ld	h,(ix+1)	;HL = dir. del sistema de menus

	ld	a,(hl)
	cp	d
	jr	nc,OKNUMM
ERRNUMM:	ld	a,2	;Error de num. de menu
	ret

OKNUMM:	ld	b,d
GETOPD2:	inc	hl
	inc	hl
	djnz	GETOPD2
	dec	hl
	push	hl
	pop	ix
	ld	l,(ix)
	ld	h,(ix+1)	;HL = dir. del menu

	ld	a,e
	or	a
	ret	z	;Si E = 0 ya hemos acabado

	inc	hl
	inc	hl
	ld	a,(hl)
	cp	e
	jr	nc,OKNUMO
ERRNUMO:	ld	a,3	;Error de num. de opcion
	ret

OKNUMO:	ld	b,e
	dec	hl
	dec	hl
GETOPD3:	push	hl
	pop	ix
	ld	l,(ix)
	ld	h,(ix+1)
	djnz	GETOPD3

	xor	a	;Volvemos sin error
	ret

;--- Obtencion de informacion sobre una opcion de un menu
;    Entrada: A = Sistema de menus (0 -> actual)
;             D = Menu (0 -> el ultimo desplegado)
;             E = Opcion
;             IX= tabla de datos de la opcion
;             IY= tabla de datos del menu
;    Salida:  CY=0 -> No hay error, y entonces A = &B 00PUBAIX
;                     P -> Esta opcion es la primera del menu
;                     U -> Esta opcion es la ultima del menu
;                     B -> Es una barra de separacion
;                     A -> Opcion activada
;                     I -> Opcion inhibida
;                     X -> Genera submenu
;             CY=1 -> Error:
;                     A = 1 -> No existe ese sistema
;                     A = 2 -> No existe ese menu
;                     A = 3 -> No existe esa opcion en ese menu
;                     A = 4 -> No hay ningun menu desplegado (D=0 a la entrada)
;             Modifica AF'

_GETIOP:	push	hl,de,bc
	or	a
	jr	z,GETIO0
	ld	c,a
	ld	a,(NUMSMEN)
	cp	c
	jr	nc,GETIO1
	ld	a,1
	scf
	jp	FINGIOP	;Generacion de error 1

GETIO0:	ld	a,(ACTSMEN)	;Si A = 0 a la entrada
	ld	c,a	;C = sistema de menus

GETIO1:	ld	a,d
	or	a
	jr	nz,GETIO3
	ld	a,(NUMMDESP)
	or	a
	ld	a,4	;Generacion de error 4
	scf
	jr	z,FINGIOP

	ld	a,(NUMMDESP)	;Se ejecuta si D=0 a la entrada
	ld	b,a
	push	de
	ld	de,TAMTAB
	ld	hl,NUMPR
	or	a
	sbc	hl,de
GETIO2:	add	hl,de
	djnz	GETIO2
	pop	de
	ld	d,(hl)	;D = ultimo menu desplegado

GETIO3:	ld	a,c
	ld	iyh,a	;IYh= no. de sistema de menus
	call	GETOPD
	or	a
	jr	z,GETIO31
	scf
	jr	FINGIOP	;Generacion de error 2 o 3

GETIO31:	push	hl
	pop	ix	;IX = direccion tabla de datos
	xor	a	;Vamos poniendo bits en A

	ld	c,a
	ld	a,(ix+6)
	or	a
	ld	a,c
	jr	z,GETIO4
	or	1	;Genera submenu

GETIO4:	ld	c,a
	ld	a,(ix+5)
	inc	a
	ld	a,c
	jr	z,GETIO5
	or	2	;Opcion inhibida

GETIO5:	ld	c,a
	ld	a,(ix+4)
	or	a
	ld	a,c
	jr	z,GETIO6
	or	4	;Opcion activada

GETIO6:	ld	c,a
	ld	a,(ix+2)
	or	(ix+3)
	ld	a,c
	jr	nz,GETIO7
	or	8	;Barra de separacion

GETIO7:	ld	c,a
	push	ix,bc,de
	ld	a,iyh
	ld	e,0
	call	GETOPD
	push	hl
	pop	iy
	pop	de,bc,ix
	ld	a,(iy+2)
	cp	e
	ld	a,c
	jr	nz,GETIO8
	or	16	;Ultima opcion

GETIO8:	ld	c,a
	ld	a,e
	dec	a
	ld	a,c
	jr	nz,GETIO9
	or	32	;Primera opcion

GETIO9:	or	a	;No hay error

FINGIOP:	pop	bc,de,hl
	ret

;--- Muestra de la barra de menus desplegables y actualiza ACTSMEN
;    Entrada: A = Numero de sistema de menus
;             L = Coordenada Y
;    Salida:  A = 0 => barra puesta OK, (ACTSMEN) y (CORDYMEN) actualizados
;             A = 1 => num. de sistema incorrecto
;             Modifica AF'

_PUTBAR:	di
	push	hl,de,bc,ix
	ld	ix,NUMSMEN
	cp	(ix)
	jr	c,OKNUMS2
	jr	z,OKNUMS2
ERRNUMS2:	ld	a,1	;Error de num. de sistema
	jr	FINPUTB

OKNUMS2:	ld	(ACTSMEN),a

BORRALIN:	ex	af,af	;Borra la linea donde ira la barra
	ld	a,l	;Guarda coordenada Y en A'
	ld	(CORDYMEN),a
	ex	af,af
	ld	h,0
	call	C_VRAD
	call	SET_WR
	di
	ld	b,80
	ld	a," "
BUCBORL:	out	(#98),a
	djnz	BUCBORL

	ld	de,#0100	;Primer menu
OTROMEN:	ld	a,1
	call	GETOPD
	or	a
	ld	a,0
	jr	nz,FINPUTB	;Terminar si no hay mas menus
	inc	d	;Siguiente menu en la proxima iteracion
	push	hl
	pop	ix	;IX = informacion del menu
	ld	a,(ix+7)
	or	a
	jr	z,OTROMEN	;No imprimir si es secundario
	push	de

	ld	a,(ix+4)	;A = coordenada X
	ld	bc,7
	add	hl,bc
	ex	de,hl	;DE = inicio de la cadena
	ld	h,a
	ex	af,af
	ld	l,a
	ex	af,af
	xor	a
	call	PRINT
	di
	pop	de	;DE = menu + 0 (opcion)

	ld	a,(ix)	;Si la direccion del proximo menu
	or	(ix+1)	;es cero, no hay mas menus
	jr	nz,OTROMEN

FINPUTB:	pop	ix,bc,de,hl
	ei
	ret

;--- Muestra un menu desplegable del actual sistema
;    Entrada: A = menu (0 -> repliega menu)
;             B = no. de opcion actualmente apuntada, contando barras separacion
;             C = #FF -> El submenu aparece a la izquierda de la opcion
;                 #00 -> El submenu aparece a la derecha de la opcion
;                 (B y C usados solo se el menu a desplegar es secundario)
;    Salida:  A = 0 -> Menu desplegado y tabla actualizada
;             A = 1 -> Ese menu no existe en el sistema actual
;             A = 2 -> Ese menu es secundario y no hay ningun primario despl.
;             A = 3 -> Ese menu es primario y ya hay uno desplegado
;             A = 4 -> Demasiados menus desplagados
;             A = 5 -> Se ha dado orden de replegar y no hay nada desplegado
;             No modifica el resto de registros

_DESPMENU:	push	iy,ix,hl,de,bc
	di
	or	a
	jp	z,REPL
	ld	c,a	;A' = no. de menu a desplegar/replegar
	ex	af,af
	ld	a,c
	ex	af,af

	ld	a,(NUMMDESP)	;Error 4 si NUMMDESP = MAXMDESP
	ld	b,a	;actualmente
	ld	a,(MAXMDESP)
	cp	b
	ld	a,4
	jp	z,FINDESP

	ld	d,c	;Direccion del menu en IX.
	ld	e,0	;Error 1 si no existe
	ld	a,(ACTSMEN)
	call	GETOPD
	push	hl
	pop	ix
	or	a
	ld	a,1
	jp	nz,FINDESP

	ld	a,(ix+7)	;Miramos si el menu es primario
	or	a	;o secundario, y comprobamos
	jr	z,CHKER2	;si hemos de generar error 2 o 3

CHKER3:	ld	a,(NUMMDESP)	;El menu es primario: comprobamos
	or	a	;si ya hay menus desplegados,
	ld	a,3	;en ese caso generamos error 3
	jp	nz,FINDESP
	jr	NOERDESP

CHKER2:	ld	a,(NUMMDESP)	;El menu es secundario: comprobamos
	or	a	;si no hay ninguno desplegado
	ld	a,2	;en ese caso generamos error 2
	jp	z,FINDESP

NOERDESP:	ld	a,(NUMMDESP)	;No hay errores: actualizamos NUMMDESP
	inc	a	;y seguimos
	ld	(NUMMDESP),a
	or	a
	call	SC_BACK	;Guardamos la pantalla
	di

	ld	de,TAMTAB	;Calcula y deposita en IY
	ld	hl,NUMPR
	ex	af,af
	ld	b,a
	ex	af,af
C_TBDIR:	add	hl,de	;la direccion de la tabla de datos
	djnz	C_TBDIR	;del menu a desplegar (NUM, X, Y)
	or	a
	sbc	hl,de
	push	hl
	pop	iy

	ex	af,af	;Actualizamos tabla:
	ld	c,a	;No. menu -> (IY)
	ld	(iy),a
	ex	af,af

	ld	a,(ix+7)
	or	a
	jr	z,ESSEC

ESPRIM:	ld	a,(ix+6)	;Se ejecuta si el menu es primario:
	ld	(iy+1),a	;Cord. X -> (IY+1), MnnXMENU
	ld	a,(CORDYMEN)
	inc	a
	ld	(iy+2),a	;Cord. Y -> (IY+2), la de la barra +1
	jr	OKTABLA

ESSEC:	pop	bc	;Se ejecuta si el menu es secundario
	push	bc
	ld	a,(iy-2)
	add	b
	dec	a	;(IY+2) <- Cord. Y opcion generadora
	ld	(iy+2),a	;          + opcion apuntada + 1

	inc	c	;Calculo de X segun si el submenu
	jr	nz,ALADCHA	;se ha de situar a la dcha. o a la izda.

ALAIZDA:	ld	a,(ix+3)
	ld	c,a	;A = cord. X menu generador
	ld	a,(iy-4)	;C = anchura menu a desplegar
	sub	c
	jr	OKLADO

ALADCHA:	ld	a,(ACTSMEN)
	ld	d,(iy-4)
	ld	e,0
	push	bc,ix
	call	GETOPD
	pop	ix,bc
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	ld	c,a
	ld	a,(iy-3)
	add	c

OKLADO:	ld	(iy+1),a	;(IY+1) -> Cord. X adecuada para salir
	nop		;a la dcha. o a la izda. del generador

OKTABLA:	ld	h,(iy+1)	;La tabla de menus desplegados
	ld	l,(iy+2)	;ya esta actualizada
	push	hl
	call	C_VRAD
	call	SET_WR
	di

BORDSUP:	ld	a,GRF1	;Dibuja el borde superior
	out	(#98),a
	ld	b,(ix+3)
	dec	b
	dec	b
	ld	a,GRF10
BUCBSUP:	out	(#98),a
	djnz	BUCBSUP
	ld	a,GRF3
	out	(#98),a

	ex	af,af	;A'= anchura del menu -2
	ld	a,(ix+3)
	dec	a
	dec	a
	ex	af,af
	ld	b,(ix+2)	;B = no. de opciones
	ld	e,(ix)
	ld	d,(ix+1)
	push	de
	pop	ix	;IX = dir. primera opcion
	pop	hl
	inc	hl	;HL = coordenadas primera opcion

BUCOPTS:	push	hl
	or	a
	call	C_VRAD
	call	SET_WR
	di

CHKSEPB:	ld	a,(ix+2)	;Comprobamos si es barra de separacion
	or	(ix+3)
	jr	z,ESBSEP

	ld	a,GRF11	;Sacamos lateral izquierdo
	out	(#98),a

ACTOINH:	ld	a,(ix+5)	;Si MnnnINH = 0 ponemos marca inh.
	inc	a	;Si no, miramos MnnnACT,
	ld	a,GRF14	;y si es #FF ponemos marca act.
	jr	nz,SIINH	;Si no, espacio
NOINH:	ld	a,(ix+4)
	inc	a
	ld	a,GRF13
	jr	z,SIACT
NOACT:	ld	a," "
SIACT:	;
SIINH:	out	(#98),a	;Ponemos o no la marca de activacion

	push	ix
	pop	hl
	ld	de,7
	add	hl,de
BUCPRNT:	ld	a,(hl)	;Imprimimos titulo de la opcion
	or	a
	jr	z,FINPRNT
	out	(#98),a
	inc	hl
	jr	BUCPRNT

FINPRNT:	ld	a,(ix+5)	;Sacamos segunda marca de inhibicion
	inc	a	;si es necesaria
	ld	a,GRF14
	jr	nz,SIINH2
NOINH2:	ld	a," "
SIINH2:	out	(#98),a
	nop
	nop

	ld	a,GRF11	;Sacamos lateral derecho
	out	(#98),a
	jr	OTRAOP

ESBSEP:	ld	a,GRF4
	out	(#98),a
	ex	af,af
	ld	c,a	;Guardamos A' temporalmente en C
	ld	a,b	;y B en A'
	ld	b,c	;B = A' original
	ex	af,af
	ld	a,GRF10
BUCBSEP:	out	(#98),a
	djnz	BUCBSEP
	ld	a,GRF6
	out	(#98),a
	ex	af,af
	ld	b,a	;Restauramos B (contador de opciones)
	ld	a,c	;y A' (anchura del menu)
	ex	af,af

OTRAOP:	pop	hl	;Aumentamos coordenada Y
	inc	l
	ld	e,(ix)
	ld	d,(ix+1)
	push	de
	pop	ix
	djnz	BUCOPTS	;Siguiente opcion

BORDINF:	or	a	;Dibuja el borde inferior
	call	C_VRAD
	call	SET_WR
	di
	ex	af,af
	ld	b,a
	ex	af,af
	ld	a,GRF7	;Esquina izquierda
	out	(#98),a
	ld	a,GRF10
	nop
	nop
BUCBINF:	out	(#98),a
	djnz	BUCBINF
	ld	a,GRF9	;Esquina derecha
	out	(#98),a

	xor	a
	jr	FINDESP	;Terminar sin errores

REPL:	ld	a,(NUMMDESP)	;Replegamiento
	or	a
	ld	a,5
	jr	z,FINDESP
	ld	a,(NUMMDESP)
	push	af
	scf
	call	SC_BACK	;Error 5 si no hay menu desplegado
	di
	pop	af
	dec	a
	ld	(NUMMDESP),a

FINDESP:	pop	bc,de,hl,iy,ix
	ei
	ret

;--- Marca titulo de la barra actual
;    Entrada: A = Titulo a marcar (0 = desmarcar)
;    Salida:  A = 0 -> Titulo marcado y TITMARC actualizado
;             A = 1 -> No hay ningun sistema desplegado (ACTSMEN = 0)
;             A = 2 -> No existe ese titulo
;             Modifica AF

_MARCATIT:	or	a
	jr	z,_MARKATIT
	push	af
	xor	a
	call	_MARKATIT
	pop	af

_MARKATIT:	push	ix,hl,de,bc
	ld	d,a	;D = Titulo a marcar
	ld	a,(ACTSMEN)	;Comprobamos error 1
	or	a
	ld	a,1
	jr	z,FMARTIT

	ld	a,(NUMSMEN)	;Comprobamos error 2
	cp	d
	ld	a,2
	jr	c,FMARTIT

	ld	a,d
	ld	b,a	;B = D, temporalmente
	or	a
	jr	nz,NOERRMTIT	;Comprobamos error 3
	ld	a,(TITMARC)
	or	a
	ld	a,3
	jr	z,FMARTIT

	ld	a,(TITMARC)	;Si D = 0 a la entrada,
	ld	d,a	;ahora D = titulo marcado

NOERRMTIT:	ld	a,(ACTSMEN)
	ld	e,0
	push	bc
	call	GETOPD
	pop	bc
	push	hl
	pop	ix	;IX = informacion general del menu

	ld	d,b	;Recuperamos D original (A a la entrada)
	ld	h,(ix+4)	;H, L = coordenadas
	ld	a,(CORDYMEN)
	ld	l,a	;B, C = longitud
	ld	b,(ix+5)
	ld	c,1

	ld	a,d
	or	a
	jr	z,ESOF10
ESON10:	ld	a,d
	ld	(TITMARC),a
	call	BLK_ON
	xor	a
	jr	FMARTIT
ESOF10:	call	BLK_OF
	xor	a
	ld	(TITMARC),a

FMARTIT:	pop	bc,de,hl,ix
	ret

;--- Marca una opcion de un menu desplegado
;    Entrada: D = numero de menu (0 = el ultimo desplegado)
;             E = numero de opcion (se cuentan las barras de separacion)
;                 Si hay otra opcion marcada se desmarca antes
;                 (E = 0 desmarca la opcion actual)
;    Salida:  A = 0 -> Opcion marcada/desmarcada OK
;             A = 1 -> Esta opcion no existe en este menu
;             A = 2 -> Numero de menu incorrecto
;             A = 3 -> Se ha intentado desmarcar sin haber nada marcado
;             Actualiza MARCP o MARCSn
;             Modifica AF, AF'

_MARCAOP:	ld	a,e
	or	a
	jr	z,_MARKAOP
	push	de
	ld	e,0	;Primero desmarca opcion actual, si hay
	call	_MARKAOP
	pop	de

_MARKAOP:	di		;Igual que _MARCA, pero no desmarca
	push	ix,hl,de,bc	;automaticamente la opcion ya marcada
	ld	a,d	;anteriormente. Para ello hay que
	or	a	;pasarle E = 0.
	jr	nz,NOLASTD
LASTD:	ld	a,(NUMMDESP)
NOLASTD:	ld	b,a	;B = no. de menu

	ld	a,e
	or	a
	ld	c,e	;C = no. de opcion 
	jr	z,MARCAOP1
	ld	a,(NUMMDESP)
	cp	b
	ld	a,2
	jr	c,FMARCAOP	;Error 2 si no hay A menus desplegados

MARCAOP1:	ld	hl,NUMPR
	ld	de,TAMTAB
	or	a
	sbc	hl,de
MARCAOP0:	add	hl,de
	djnz	MARCAOP0
	push	hl
	pop	ix	;IX = tabla coord. menu desplegado

NOTIT:	ld	a,(ACTSMEN)
	ld	d,(ix)
	ld	e,0
	push	af,de,ix,bc
	call	GETOPD
	push	hl
	pop	ix
	pop	bc
	ld	b,(ix+3)
	pop	ix,de,af	;B = Anchura del menu

	push	ix,bc	;Comprobamos posible error 1
	ld	d,(ix)
	ld	e,c
	call	GETOPD
	pop	bc,ix
	or	a
	ld	a,1
	jr	nz,FMARCAOP

	ld	a,c
	or	a
	ld	d,c	;D = no. de opcion
	jr	nz,ESON1
ESOF1:	ld	a,(ix+3)
	or	a
	ld	a,4
	jr	z,FMARCAOP	;Si se quiere desmarcar pero no hay
	ld	a,(ix+3)
	ld	c,a	;nada marcado, acaba
ESON1:	ld	h,(ix+1)	;H, L = Coordenadas
	inc	h	;BC = Longitud
	ld	l,(ix+2)
	ld	a,l
	add	c
	ld	(ix+3),c	;(IY+3) <- Opcion marcada
	ld	l,a
	ld	c,1
	dec	b
	dec	b
	ld	a,d
	or	a
	jr	z,ESOF2
ESON2:	call	BLK_ON
	xor	a
	jr	FMARCAOP
ESOF2:	call	BLK_OF
	xor	a
	ld	(ix+3),a

FMARCAOP:	pop	bc,de,hl,ix
	ret

;--- Llamada a una subrutina de la BIOS
;    Entrada: IX = direccion
;    Salida:  Depende de la rutina
;             Siempre modifica A e IYh

_BIOS:	ld	a,(EXPTBL)
	ld	iyh,a
	jp	CALSLT

;--- Llamada a una subrutina de la SUB-BIOS
;    Entrada: IX = direccion
;    Salida:  depende de la rutina
;             Siempre modifica A

_SUBBIOS:	ld	a,(EXBRSA)
	ld	iyh,a
	jp	CALSLT

;------------------------
;* RUTINA DE INTERRUPCION
;------------------------

;Aqui se actualizan las variables del raton y el puntero

NEWINT:	jp	RSITIM	;Nuevo gancho
	nop
	nop

;--- Guardamos registros

RSITIM:	di
	push	af,bc,de,hl,ix,iy
	exx
	ex	af,af
	push	af,bc,de,hl
	exx
	ex	af,af

;--- Lectura del raton y actualizacion de variables de coordenada

ACTVARS:	ld	hl,POSX	;Guardamos la posicion obtenida en 
	ld	de,OLDX	;la anterior iteracion 
	ld	bc,2
	ldir

	di
	ld	a,(PUERTO)
	call	GMOUSE
	di

	ex	af,af
	ld	a,h
	ld	(OFSX),a
	ld	a,l
	ld	(OFSY),a

	ld	ix,CORDX	;Actualizamos CORDX y CORDY 
	ld	c,h
	ld	a,l
	call	ACTCORD
	ld	c,a
	call	ACTCORD
	ex	af,af
	jr	CHMINX

ACTCORD:	ld	b,0
	bit	7,c
	jr	z,POS
NEG:	ld	b,255	;C siempre es de 8 bits, pero BC de 16. 
POS:	ld	l,(ix)	;Si C es negativo, B ha de ser %11111111 
	ld	h,(ix+1)
	add	hl,bc	;para que la suma HL+BC sea correcta.  
	ld	(ix),l
	ld	(ix+1),h
	inc	ix
	inc	ix
	ret

;--- Comprobamos si sobrepasamos las coordenadas limite

CHMINX:	push	af,de,hl	;Minimo de coordenada X 
	ld	de,(CORDX)
	ld	hl,(MINX)
	call	COMP
	jr	nc,CHMAXX
	ld	(CORDX),hl
	jr	CHMINY

CHMAXX:	ex	de,hl	;Maximo de coordenada X 
	ld	de,(MAXX)
	call	COMP
	jr	nc,CHMINY
	ld	(CORDX),de

CHMINY:	ld	de,(CORDY)	;Minimo de coordenada Y 
	ld	hl,(MINY)
	call	COMP
	jr	nc,CHMAXY
	ld	(CORDY),hl
	jr	ENDCH

CHMAXY:	ex	de,hl	;Maximo de coordenada Y 
	ld	de,(MAXY)
	call	COMP
	jr	nc,ENDCH
	ld	(CORDY),de

ENDCH:	pop	hl,de,af

;--- Actualizamos botones

ACTBOT:	ex	de,hl
	ld	d,l
	ld	e,h
	ld	(BOTON1),de	;Actualizamos BOTON1, BOTON2 y BOTON 
	ld	(BOTON),a

;--- Incremento del contador de 1 byte

ACTCONT:	ld	a,(CONTA)	;Incrementamos el contador 
	inc	a	;si aun no ha llegado a 255 
	or	a
	jr	nz,INC
NOINC:	dec	a
INC:	ld	(CONTA),a
ENDINC:	; 

;--- Actualizacion de POS y OFS

	ld	b,2
	ld	a,6
	ld	iy,CORDX
ACTPOS:	push	bc	;Actualizamos, por este orden, POS y OFS 
	ld	l,(iy)	;de X e Y. 
	ld	h,(iy+1)
	ld	d,0
	ld	e,a
	call	DIVISION
	ld	(ix),e	;POS=CORD/6(X) o 8(Y) 
	ld	(ix+2),c	;OFS=CORD MOD 6(X) o 8(Y) 
	inc	ix
	inc	iy
	inc	iy
	xor	%00001110	;6 XOR %1110 = 8, 8 XOR %1110 =6 
	pop	bc	;Asi conseguimos 6 en las iteraciones 
	djnz	ACTPOS	;X y 8 en las Y. 

;--- Actualizamos cursor BLINK

	ld	hl,(BKX)
	ex	de,hl
	ld	h,e
	ld	l,d
	call	BLK_OF1
	di
	ld	hl,(POSX)
	ld	(BKX),hl
	ex	de,hl
	ld	h,e
	ld	l,d
	call	BLK_ON1
	di

;--- RUTINA USADA PARA PRUEBAS:
;    Si se pulsa el boton derecho restaura las interrupciones

CHKFIN:	ld	a,(BOTON2)
	or	a
	jr	z,ENDINT
	ld	hl,OLDINT
	ld	de,TIMINT
	ld	bc,5
	ldir

;--- Recuperamos registros y terminamos

ENDINT:	exx
	ex	af,af
	pop	hl,de,bc,af
	ex	af,af
	exx
	pop	iy,ix,hl,de,bc,af
	ei

	if	EXTINT=1
	ret
	endif

OLDINT:	ds	5

;---------------------------------
;* DATOS DE LOS MENUS DESPLEGABLES
;---------------------------------

;El formato de los menus sera el siguiente:

;* Una tabla donde se indique la direccion en memoria de cada sistema de
;  menus, asi como el numero de ellos, y el actual:

; NUMSMEN: db n
; ACTSMEN: db act
; CORDYMEN:db y         -> Coordenada Y de la barra de menus
; SMENU1:  DW @smenu1
; SMENU2:  DW @smenu2
; ...

;* Para cada sistema de menus:

; @smenu1 : ;
; S1NUMMEN: db x        -> Numero de menus, incluyendo secundarios
; S1MENU1 : db @menu11
; S1MENU2 : db @menu12  -> Direccion de inicio de cada menu
; ...

;* Para cada menu:

; @menu11 :   dw @m111    -> Direccion de la primera opcion
; M11NUMOP:   db nop      -> Numero de opciones
; M11ANCHO:   db a        -> Ancho total del menu
; M11XTIT :   db x        -> Coordenada x de aparicion del titulo
; M11ANTIT:   db a2       -> Ancho detectable del titulo
; M11XMENU:   db x        -> Coordenada de aparicion del menu
; M11TIT  :   db "Titulo menu 1" -> acabado en un caracter 0.
;                            Si el primer caracter es 0, es menu secundario
;                            y no aparece en la barra de menus.

;* Para cada opcion:

; @m111   :  dw @m112    -> Direccion de la segunda opcion
; M111DIR :  dw @rut111  -> Direccion de salto si se ejecuta este menu
; M111ACT :  db act      -> #FF si opcion activada (aparece con un circulo)
; M111INH :  db inh      -> 0 si opcion inhibida (no puede seleccionarse)
; M111EXT :  db ext      -> Si este menu da lugar a otro submenu,
;                          aqui figurara el numero de submenu, si no 0.
;                          El submenu aparecera a la derecha del menu
;                          si MnnXTIT=0, a la izquierda si MnnXTIT=#FF,
;                          y a la misma altura. El titulo es ignorado.
; M111TIT :  db "Titulo opcion 1" -> acabado en 0.

; @m112   :  dw @m113    -> Direccion de la tercera opcion (#0000 en la ultima)
; M112DIR :  dw @rut112  -> Asi con todas las opciones y todos los menus.
; ...                       Una barra de separacion se indica con #0000
;                           en la direccion de salto, y se cuenta como
;                           opcion en MsmNUMOP.

; El formato de las etiquetas es: MsmoXXXX, o MsmXXXXX, con s=sistema de menus,
; m=menu y o=opcion del menu.

; Los submenus deben ir despues de los menus principales en memoria.

NUMSMEN:	db	1	;Un solo sistema con dos menus
ACTSMEN:	db	1
CORDYMEN:	db	1
SMENU1:	dw	dirs1

dirs1:	;
S1NUMMEN:	db	3
S1MENU1:	dw	dirs1m1
S1MENU2:	dw	dirs1m2
S1MENU3:	dw	dirs1m3

;--- Primer menu

dirs1m1:	dw	m111
M11NUMOP:	db	7	;Primer menu: "Konamis", 5 opciones
M11ANCHO:	db	19
M11XTIT:	db	20
M11ANTIT:	db	10
M11XMENU:	db	19
M11TIT:	db	"Konamis",0

m111:	dw	m112
M111DIR:	dw	m111rut
M111ACT:	db	0
M111INH:	db	#ff
M111EXT:	db	0
M111TIT:	db	"Nemesis/Gradius",0

m112:	dw	m113
M112DIR:	dw	m112rut
M112ACT:	db	#ff
M112INH:	db	#ff
M112EXT:	db	0
M112TIT:	db	"King's Valley  ",0

m113:	dw	m114
M113DIR:	dw	0	;Barra de separacion
M113ACT:	db	0
M113INH:	db	#ff
M113EXT:	db	0
M113TIT:	db	"Monkey Academy ",0

m114:	dw	m115
M114DIR:	dw	m114rut
M114ACT:	db	0
M114INH:	db	#ff
M114EXT:	db	2
M114TIT:	db	"Vamp. Killer...",0

m115:	dw	m116
M115DIR:	dw	m115rut
M115ACT:	db	#ff
M115INH:	db	#ff
M115EXT:	db	0
M115TIT:	db	"Metal Gear     ",0

m116:	dw	m117
M116DIR:	dw	m116rut
M116ACT:	db	0
M116INH:	db	0
M116EXT:	db	0
M116TIT:	db	"Snatcher       ",0

m117:	dw	0
M117DIR:	dw	m117rut
M117ACT:	db	0
M117INH:	db	#ff
M117EXT:	db	0
M117TIT:	db	"Penguin Advent.",0

;--- Segundo menu

dirs1m2:	dw	m121	;Tres opciones
M12NUMOP:	db	3
M12ANCHO:	db	10
M12XTIT:	db	15
M12ANTIT:	db	10
M12XMENU:	db	13
M12TIT:	db	0,"  Otros",0

m121:	dw	m122
M121DIR:	dw	m121rut
M121ACT:	db	0
M121INH:	db	0
M121EXT:	db	0
M121TIT:	db	" NOOO ",0

m122:	dw	m123
M122DIR:	dw	m122rut
M122ACT:	db	#ff
M122INH:	db	#ff
M122EXT:	db	0
M122TIT:	db	"Mola! ",0

m123:	dw	0
M123DIR:	dw	m123rut
M123ACT:	db	0
M123INH:	db	#ff
M123EXT:	db	3
M123TIT:	db	"Fin...",0

;--- Tercer menu

dirs1m3:	dw	m131
M13NUMOP:	db	2
M13ANCHO:	db	13
M13XTIT:	db	50
M13ANTIT:	db	10
M13XMENU:	db	49
M13TIT:	db	0

m131:	dw	m132
M131DIR:	dw	m131rut
M131ACT:	db	0
M131INH:	db	#ff
M131EXT:	db	0
M131TIT:	db	"Acabose  ",0

m132:	dw	0
M132DIR:	dw	m132rut
M132ACT:	db	0
M132INH:	db	#ff
M132EXT:	db	0
M132TIT:	db	"No ai mas",0

m111rut:	ret
m112rut:	ret
m113rut:	ret
m114rut:	ret
m115rut:	ret
m116rut:	ret
m117rut:	ret
m121rut:	ret
m122rut:	ret
m123rut:	ret
m131rut:	ret
m132rut:	ret

_SC_BUF:	ds	0
_BK_BUF:	equ	_SC_BUF+2048*3	;tres buffers para pantalla
