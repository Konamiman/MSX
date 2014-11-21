;Helper routines to manage VRAM access.

;========================

;               ***** RUTINAS DE ACCESO A LA VRAM *****
;
;                   ///  Por Konami Man, 1996  \\\

	org	#100
;
;
; ----------------------
; ----- Constantes -----
; ----------------------

SI:	equ	1
NO:	equ	0

USEBLK:	equ	SI	;Para el ensamblado condicional:
;                                   ;si es 0 no ensambla las rutinas blink
PRUEBA_V:	equ	NO	;Usado para pruebas
BKMOV:	equ	SI

BASESCR:	equ	#0000	;Dir. VRAM de la zona de representacion
;                                   ;en pantalla (2 Kb)

BASEPAT:	equ	#1000	;Dir. VRAM de la tabla de patrones (2 Kb) 

MAXVSP:	equ	5	;Niveles de la pila VRAM
;                                   ;Si solo vamos a usar la pagina 0 de VRAM,
;                                   ;el maximo es 5

BUFFER:	equ	#8000	;Buffer para transferencias VRAM-VRAM

VDPBF1:	equ	&HF3DF	;r#0-7  del VDP
VDPBF2:	equ	&HFFE7-8	;r#8-23 del VDP

; ---------------------
; ----- Variables -----
; ---------------------
;
; BASE DE LA TABLA BLINK. El valor por defecto es #0800, se puede modificar
; con la subrutina BAS_BLK.

	if	USEBLK=SI
BASEBK:	dw	#0800
	endif

; PUNTERO A VRAM. Actualizado por todas las subrutinas que accedan a la
; Video RAM, en todo momento apunta a la misma direccion VRAM que el VDP.
; Algunas rutinas no modifican PVRAM (lo guardan, realizan las operaciones
; de acceso a VRAM y despues lo restauran), en cuyo caso se indica.

PVRAM:	dw	0	;Los 16 bits bajos
	db	0	;bit 0: MSB de la dir. VRAM apuntada 
;                                   ;bit 6: lectura (0) o escritura (1) VRAM


; IMAGEN DE LA ZONA BLINK. Actualizada por todas las  instrucciones relacionadas
; con el modo blink, esta zona de la memoria es en todo momento una copia de la
; tabla blink de la VRAM.

	if	USEBLK=SI
BKIMG:	ds	256	;Imagen en RAM de la zona BLINK
	endif

; INTMODE. Distinto de cero cuando se ejecuta la rutina de atencion
; a la interrupcion. Entonces las rutinas BLK_ON1, BLK_OF1 y BLK_SW1
; no actualizan la zona imagen del blink.

INTMODE:	db	0

; LIMITES DE LA PANTALLA. Cualquier intento de crear o mover un bloque blink
; mas alla de estas oordenadas provocara que la funcion vuelva con error.

MIN_X:	db	5
MIN_Y:	db	5
MAX_X:	db	75
MAX_Y:	db	20

; PANTALLAS INTRODUCIDAS EN LA PILA VRAM. De 0 a MAXVSP. Ver mas abajo.

VSP:	db	0

; TABLA DE DIRECCIONES DE LA PILA VRAM.

TABPILV:	dw	#1800,#0900	;Direccion pila pantalla y blink, nivel 1
	dw	#2000,#0A00	;Nivel 2
	dw	#2800,#0B00	;Nivel 3
	dw	#3000,#0C00	;Nivel 4
	dw	#3800,#0D00	;Nivel 5

; ---------------------------
; ----- Tabla de saltos -----
; ---------------------------

; Actualizacion del puntero a VRAM

INCPV:	jp	_INCPV	;Incrementa PVRAM en una unidad 
SUMPV:	jp	_SUMPV	;Incrementa PVRAM en BC unidades 

; Establecimiento de la direccion de acceso a VRAM y PVRAM

SET_VDP:	jp	_SET_VDP	;Prepara VDP para lectura o escritura   
SET_RD:	jp	_SET_RD	;Prepara VDP para lectura   
SET_WR:	jp	_SET_WR	;Prepara VDP para escritura   

; Lectura/escritura de un dato de VRAM

RDVRM:	jp	_RDVRM	;Lee un dato   
WRVRM:	jp	_WRVRM	;Escribe un dato   
VPEEK:	jp	_VPEEK	;Lee un dato de la direccion especificada 
VPOKE:	jp	_VPOKE	;Escribe un dato en la dir. especificada   

; Lectura/escritura de un bloque de datos de VRAM

LDIRVR:	jp	_LDIRVR	;Copia un bloque VRAM-RAM   
LDIRRV:	jp	_LDIRRV	;Copia un bloque RAM-VRAM   
LDIRVV:	jp	_LDIRVV	;Copia un bloque VRAM-VRAM   

; Relleno de zonas de la VRAM

FILLVR1:	jp	_FILLVR1	;Llena la VRAM con un dato   
FILLVR2:	jp	_FILLVR2	;Idem a partir de la direccion especificada

; Establecimientos para el modo blink

	if	USEBLK=SI
BLK_BAS:	jp	_BLK_BAS	;Establece la direccion VRAM base del Blink
BLK_CLS:	jp	_BLK_CLS	;Limpia la zona Blink   
BLK_COL:	jp	_BLK_COL	;Establece los colores Blink   
BLK_TIM:	jp	_BLK_TIM	;Establece el tiempo Blink   

; Acceso a la zona blink

BLK_MAK:	jp	_BLK_MAK	;Dibuja/borra un bloque blink (usa tabla)
BLK_ON:	jp	_BLK_ON	;Dibuja un bloque Blink
BLK_OF:	jp	_BLK_OF	;Borra un bloque Blink   
BLK_MOV:	jp	_BLK_MOV	;Movimiento de un bloque Blink
BLK_ON1:	jp	_BLK_ON1	;Activa el Blink de un caracter   
BLK_OF1:	jp	_BLK_OF1	;Desactiva el Blink de un caracter   
BLK_SW1:	jp	_BLK_SW1	;Invierte el Blink de un caracter

; Varios

C_BLKAD:	jp	_C_BLKAD	;Calcula dir. VRAM para coord. Blink  
C_BLKIM:	jp	_C_BLKIM	;Calcula dir. en zona imagen para c. Blink
C_STBT:	jp	_C_STBT	;Calcula 1er bit coord. Blink  
	endif		;<--- USEBLK
C_VRAD:	jp	_C_VRAD	;Calcula dir. VRAM para una coordenada  
PRINT:	jp	_PRINT	;Impresion de una cadena 
POR10:	jp	_POR10	;Multiplicacion de un numero por 10
POR80:	jp	_POR80	;Multiplicacion de un numero por 80
INVCAR:	jp	_INVCAR	;Invierte un caracter
VPUSH:	jp	_VPUSH	;Guarda pantalla en pila VRAM
VPOP:	jp	_VPOP	;Restaura pantalla de pila VRAM

; VPUSH guarda la pantalla mas la zona blink en una pila contenida en la
; primera pagina de la VRAM (#0000-#3FFF). En esta pila caben cinco pantallas.
; La disposicion de la primera pagina de VRAM queda entonces asi:

; Direccion hex       Direccion dec     Uso
; -------------       -------------     ---
; #0000-#07FF             0-2047        Zona de pantalla (caracteres)
; #0800-#08FF          2048-2303        Zona de pantalla (blink)

; #0900-#09FF          2304-2559        Pila blink, nivel 1
; #0A00-#0AFF          2560-2815        Pila blink, nivel 2
; #0B00-#0BFF          2816-3071        Pila blink, nivel 3
; #0C00-#0CFF          3072-3327        Pila blink, nivel 4
; #0D00-#0DFF          3328-3583        Pila blink, nivel 5

; #0E00-#0FFF          3584-4093        512 bytes sin usar

; #1000-#17FF          4096-6143        Tabla de patrones de los caracteres

; #1800-#1FFF          6144-8191        Pila pantalla, nivel 1
; #2000-#27FF          8192-10239       Pila pantalla, nivel 2
; #2800-#2FFF          10240-12287      Pila pantalla, nivel 3
; #3000-#37FF          12288-14335      Pila pantalla, nivel 4
; #3800-#3FFF          14336-16383      Pila pantalla, nivel 5

; La variable VSP indica cuantas pantallas hay ya en la pila VRAM.
; Para recuperar una pantalla hay que usar VPOP.
; Se pueden agnadir niveles de pila aumentando MAXVSP y ampliando TAVPILV,
; asumiendo el uso de la VRAM por encima de #3FFF (mas alla de la 1a pagina).
; No se pueden usar las 64K superiores a #FFFF.

; INTERRUPCIONES: Solo es necesario que permanezcan inhibidas
; en aquellas rutinas que accedan directamente a los puertos del VDP (IN, OUT)
; o que modifiquen directamente PVRAM.

; Si la rutina de servicio a la interrupcion accede a la VRAM,
; antes ha de leer PVRAM y guardarlo:

; LD HL,(PVRAM)
; LD A,(PVRAM+2)
; PUSH HL,AF

; ... y al final restaurar tanto el puntero del VDP como PVRAM:

; POP AF,HL
; CALL SET_VDP

; Recordar que SET_VDP termina con EI.

;-------------------
;----- Rutinas -----
;-------------------

; Formato de la cabecera de las rutinas:

; --- NOMBRE: La etiqueta que identifica la rutina.
;       Explicacion de la funcion de la rutina.
;     ENTRADA:   Incluye los registros a cargar y las acciones a realizar
;                antes de llamar a la rutina.
;     SALIDA:    Incluye los datos devueltos en registros
;                y las acciones realizadas no explicadas tras el nombre.
;     REGISTROS: Registros modificados por la rutina. No incluye los de salida.
;     LLAMADAS:  Subrutinas llamadas por la rutina.
;     VARIABLES: Variables y constantes externas a la rutina usadas por esta
;                y/o por alguna de las subrutinas llamadas.



;--- NOMBRE: INCPV
;      Actualizacion del puntero a VRAM: incremento de una unidad
;      Tras #0FFFF pasa a #10000, tras #1FFFF pasa a #00000
;    ENTRADA:   -
;    SALIDA:    -
;    REGISTROS: -
;    LLAMADAS:  -
;    VARIABLES: PVRAM

_INCPV:	di
	push	hl,af,de

	ld	hl,PVRAM
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	de
	ld	(hl),d
	dec	hl
	ld	(hl),e

CHK0000:	ld	a,d	;Comprobamos si pasa de #00000
	or	e
	jr	nz,CHKFFFF

PASA:	inc	hl	;Invertimos bit 0 de PVRAM+1
	inc	hl	;si pasa de #00000 o de #1FFFF
	ld	a,(hl)
	xor	%00000001
	ld	(hl),a
	jr	FINPV

CHKFFFF:	inc	e	;Comprobamos si pasa de #xFFFF
	jr	nz,FINPV
	inc	d
	jr	nz,FINPV

FINPV:	pop	de,af,hl
	ei
	ret

;--- NOMBRE: SUMPV
;      Actualizacion del puntero a VRAM: incremento de BC unidades
;      Tras #0FFFF pasa a #10000, tras #1FFFF pasa a #00000
;    ENTRADA:   BC = incremento
;    SALIDA:    -
;    REGISTROS: -
;    LLAMADAS:  -
;    VARIABLES: PVRAM

_SUMPV:	di
	push	af,hl,de
	ld	hl,PVRAM
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl	;DE = PVRAM+1, HL=dir. VRAM actual 
	add	hl,bc
	ex	de,hl	;DE = dir. VRAM nueva, HL = PVRAM+1 
	ld	(hl),d
	dec	hl
	ld	(hl),e	;HL = PVRAM 
	pop	de
	jr	nc,FISUMPV

	inc	hl	;Se ejecuta si pasamos de #xFFFF
	inc	hl
	ld	a,(hl)
	xor	%00000001
	ld	(hl),a
FISUMPV:	pop	hl,af
	ei
	ret

;--- NOMBRE: SET_VDP
;      Preparacion del VDP para lectura o escritura de VRAM
;      y establecimiento de PVRAM
;    ENTRADA:   A = %0S00000P
;                   P = bit 17 de la direccion VRAM
;                   S = 0 para lectura de VRAM, 1 para escritura
;               HL= direccion VRAM, 16 bits bajos
;    SALIDA:    -
;    REGISTROS: AF, HL
;    LLAMADAS:  -
;    VARIABLES: PVRAM

_SET_VDP:	di
	ld	(PVRAM),hl
	ld	(PVRAM+2),a
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

;--- NOMBRE: SET_RD
;      Preparacion del VDP para lectura de VRAM
;      y establecimiento de PVRAM
;    ENTRADA:   HL = direccion VRAM, 16 bits bajos
;               CY = direccion VRAM, bit 17
;    SALIDA:    -
;    REGISTROS: AF, HL
;    LLAMADAS:  SET_VDP
;    VARIABLES: PVRAM

_SET_RD:	ld	a,0
	jr	nc,PAG1R
PAG0R:	ld	a,1
PAG1R:	jp	SET_VDP

;--- NOMBRE: SET_WR
;      Preparacion del VDP para escritura en VRAM
;    ENTRADA:   HL = direccion VRAM, 16 bits bajos
;               CY = direccion VRAM, bit 17
;    SALIDA:    -
;    REGISTROS: AF, HL
;    LLAMADAS:  SET_VDP
;    VARIABLES: PVRAM

_SET_WR:	ld	a,%01000000
	jr	nc,PAG1W
PAG0W:	ld	a,%01000001
PAG1W:	jp	SET_VDP

;--- NOMBRE: RDVRM
;      Lectura de un dato de VRAM
;    ENTRADA:   Direccion establecida con SET_VDP
;    SALIDA:    A = dato
;    REGISTROS: -
;    LLAMADAS:  INCPV
;    VARIABLES: PVRAM

_RDVRM:	di
	in	a,(#98)
	jp	INCPV

;--- NOMBRE: WRVRM
;      Escritura de un dato en VRAM
;    ENTRADA:   Direccion establecida con SET_VDP
;               A = dato
;    SALIDA:    -
;    REGISTROS: -
;    LLAMADAS:  INCPV
;    VARIABLES: PVRAM

_WRVRM:	di
	out	(#98),a
	jp	INCPV

;--- NOMBRE: VPEEK
;      Lectura de un dato de VRAM con especificacion de direccion
;      No modifica la direccion VRAM ni PVRAM
;    ENTRADA:   CY-HL = direccion VRAM
;    SALIDA:    A  = dato
;    REGISTROS: AF, HL
;    LLAMADAS:  SET_RD, RDVRM, SET_VDP, INCPV, SET_RD, RDVRM
;    VARIABLES: PVRAM (no lo modifica)

_VPEEK:	push	hl,af
	ld	hl,(PVRAM)
	ld	a,(PVRAM+2)
	ld	(VPEK2),hl
	ld	(VPEK1),a
	pop	af,hl

	call	SET_RD
	call	RDVRM

	push	af
	ld	a,(VPEK1)
	ld	hl,(VPEK2)
	call	SET_VDP
	pop	af

	ret

VPEK1:	db	0
VPEK2:	dw	0

;--- NOMBRE: VPOKE
;      Escritura de un dato en VRAM con especificacion de direccion
;      No modifica la direccion VRAM ni PVRAM
;    ENTRADA:   CY-HL = direccion VRAM
;               A  = dato
;    SALIDA:    -
;    REGISTROS: AF, HL
;    LLAMADAS:  SET_WR, WRVRM, SET_VDP, INCPV
;    VARIABLES: PVRAM (no lo modifica)

_VPOKE:	push	hl,af
	ld	hl,(PVRAM)
	ld	a,(PVRAM+2)
	ld	(VPOK1),hl
	ld	(VPOK2),a
	pop	af,hl

	push	af
	call	SET_WR
	pop	af
	call	WRVRM

	ld	hl,(VPOK1)
	ld	a,(VPOK2)
	jp	SET_VDP

VPOK1:	dw	0
VPOK2:	db	0

;--- NOMBRE: LDIRVR
;      Copia de un bloque de datos de VRAM a RAM
;    ENTRADA:   Direccion VRAM establecida con SET_RD
;               DE = destino RAM
;               BC = longitud
;    SALIDA:    Bloque de datos a partir de (DE)
;               DE = direccion siguiente al final del bloque
;    REGISTROS: AF
;    LLAMADAS:  SUMPV
;    VARIABLES: PVRAM

_LDIRVR:	di
	push	hl,de,bc
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
	jp	SUMPV	;Esta rutina vuelve con EI

;--- NOMBRE: LDIRRV
;      Copia de un bloque de datos de RAM a VRAM
;    ENTRADA:   Direccion VRAM establecida con SET_WR
;               HL = origen RAM
;               BC = longitud
;    SALIDA:    HL = direccion siguiente al final del bloque
;    REGISTROS: AF
;    LLAMADAS:  SUMPV
;    VARIABLES: PVRAM

_LDIRRV:	di
	push	de,bc,hl
	ld	d,b
	ld	e,c
	ld	c,#98
BUCLDRV:	outi
	dec	de
	ld	a,d
	or	e
	jr	nz,BUCLDRV
	pop	hl,bc,de
	jp	SUMPV	;Esta rutina termina con EI

;--- NOMBRE: LDIRVV
;      Copia de un bloque de datos de VRAM a VRAM a traves de un buffer en RAM
;    ENTRADA:   HL = origen, 16 bits bajos
;               DE = destino, 16 bits bajos
;               BC = longitud
;               A  = %000000 D O, bit 17 de Origen y Destino
;               IX = buffer RAM de BC bytes
;    SALIDA:    -
;    REGISTROS: AF, HL, DE
;    LLAMADAS:  SET_RD, LDIRVR, SET_WR, LDIRRV
;    VARIABLES: PVRAM

_LDIRVV:	rra
	push	af
	call	SET_RD
	push	de,ix
	pop	de
	call	LDIRVR
	pop	hl,af
	rra
	call	SET_WR
	push	ix
	pop	hl
	jp	LDIRRV

;--- NOMBRE: FILLVR1
;      Llenado de una porcion de VRAM con un dato
;    ENTRADA:   Direccion inicial establecida con SET_WR
;               BC = longitud
;               A  = dato
;    SALIDA:    -
;    REGISTROS: -
;    LLAMADAS:  -
;    VARIABLES: PVRAM

_FILLVR1:	di
	push	hl,bc,de,af
BUCFL1:	out	(#98),a
	ld	d,a
	dec	bc
	ld	a,b
	or	c
	ld	a,d
	jr	nz,BUCFL1
	pop	af,de,bc,hl
	jp	SUMPV	;Esta rutina termina con EI

;--- NOMBRE: FILLVR2
;      Llenado de una porcion de VRAM con especificacion de direccion
;      No modifica la direccion VRAM ni PVRAM
;    ENTRADA:   CY-HL: direccion VRAM
;               BC = longitud
;               A  = dato
;    SALIDA:    -
;    REGISTROS: AF, HL
;    LLAMADAS:  SET_WR, FILLVR1, SET_VDP, SUMPV
;    VARIABLES: PVRAM (no la modifica)

_FILLVR2:	push	af,hl,af
	ld	hl,(PVRAM)
	ld	a,(PVRAM+2)
	ld	(FILV21),hl
	ld	(FILV22),a

	pop	af,hl
	call	SET_WR
	pop	af
	call	FILLVR1

	ld	hl,(FILV21)
	ld	a,(FILV22)
	jp	SET_VDP	;Esta rutina acaba con EI

FILV21:	dw	0
FILV22:	db	0


	if	USEBLK=SI	;<--- !!!

;--- NOMBRE: BLK_BAS
;      Blink: establecimiento de la direccion base (#800 por defecto)
;    ENTRADA:   HL = direccion base (multiplo de 512 = #200)
;    SALIDA:    -
;    REGISTROS: AF
;    LLAMADAS:  -
;    VARIABLES: BASEBK, VDPBF

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
	LD	(VDPBF1+3),A
	OUT	(&H99),A
	LD	A,3 OR &H80
	OUT	(&H99),A
	ei
	RET

;--- NOMBRE: BLK_CLS
;      Limpieza de la zona Blink
;    ENTRADA:   -
;    SALIDA:    -
;    REGISTROS: AF y HL
;    LLAMADAS:  FILLVR2, FILLVR1
;    VARIABLES: BASEBK, BKIMG, PVRAM

_BLK_CLS:	push	bc,de
	LD	hl,(BASEBK)
	xor	a
	ld	bc,256
	call	FILLVR2	;Limpiamos zona VRAM
	ld	hl,BKIMG
	ld	de,BKIMG+1
	ld	bc,256
	xor	a
	ld	(hl),a
	ldir		;Limpiamos zona imagen
	pop	de,bc
	ret

;--- NOMBRE: BLK_COL
;      Establecimiento del color Blink
;    ENTRADA:   A = color texto + 16* color fondo
;    SALIDA:    -
;    REGISTROS: A
;    LLAMADAS:  -
;    VARIABLES: -

_BLK_COL:	di
	OUT	(&H99),A
	LD	A,&H80+12
	OUT	(&H99),A
	ei
	RET

;--- NOMBRE: BLK_TIM
;      Establecimiento del tiempo Blink
;    ENTRADA:   A = tiempo ON + 16* tiempo OFF
;    SALIDA:    -
;    REGISTROS: A
;    LLAMADAS:  -
;    VARIABLES: -

_BLK_TIM:	di
	OUT	(&H99),A
	LD	A,&H80+13
	OUT	(&H99),A
	ei
	RET

;--- NOMBRE: BLK_MAK
;     Crea/borra un bloque Blink a partir de una tabla de coor. y dimensiones
;    ENTRADA:   IX= Puntero a la tabla de datos del bloque:
;                   +0: Posicion X
;                   +1: Posicion Y
;                   +2: Longitud X
;                   +3: Longitud Y
;               CY= 0 -> Borrar el bloque
;               CY= 1 -> Dibujar el bloque
;    SALIDA:    - (NO hay deteccion de coordenadas limite)
;    REGISTROS: AF
;    LLAMADAS:  SET_WR, SET_VDP, WRVDP, VPEEK, C_STBT, C_BLKAD, BLK_ON, BLK_OF
;    VARIABLES: PVRAM (no la modifica), BKIMG

_BLK_MAK:	ld	h,(ix)
	ld	l,(ix+1)
	ld	b,(ix+2)
	ld	c,(ix+3)
	jp	c,BLK_ON
	jp	BLK_OF

;--- NOMBRE: BLK_ON
;      Blink ON para un bloque
;    ENTRADA:   HL = XXYY
;               B  = longitud X
;               C  = longitud Y
;    SALIDA:    L  = YY siguiente a la ultima linea
;               H  = XX original
;    REGISTROS: AF
;    LLAMADAS:  SET_WR, SET_VDP, WRVDP, VPEEK, C_STBT, C_BLKAD, SET_RD, RDVDP
;    VARIABLES: PVRAM (no la modifica), BKIMG

_BLK_ON:	push	ix,bc,de

	ld	de,(PVRAM)	;Guardamos puntero a VRAM  
	ld	a,(PVRAM+2)
	ld	(BLON1),de
	ld	(BLON2),a

BUCBKON:	push	hl,bc
	ld	a,h
	call	C_STBT
	ld	e,a	;HL = direccion VRAM inicial  
	call	C_BLKAD	;E tiene el bit inicial puesto a 1  

	push	de,hl
	ld	de,(BASEBK)
	or	a
	sbc	hl,de
	ld	de,BKIMG
	add	hl,de
	push	hl
	pop	ix
	pop	hl,de	;IX = dir. inicial zona imagen 

BLON.1:	push	hl
	or	a
	call	VPEEK
	pop	hl
	push	hl,af	;A = contenido de (HL) [VRAM]  
	or	a
	CALL	SET_WR	;VDP preparado para escribir en (HL)  
	POP	AF,hl

BLON.0:	OR	E
	RRC	E
	JR	NC,BLON.2
	call	WRVRM
	ld	(ix),a	;Actualizamos zona imagen 
	inc	ix
	INC	HL
	DJNZ	BLON.1
	jr	OTRALIN1
BLON.2:	DJNZ	BLON.0
	call	WRVRM
	ld	(ix),a
	inc	ix

OTRALIN1:	pop	bc,hl
	inc	l
	dec	c
	ld	a,c
	or	a
	jr	nz,BUCBKON

	ex	de,hl	;Restauramos puntero a VRAM  
	ld	hl,(BLON1)
	ld	a,(BLON2)
	call	SET_VDP
	ex	de,hl

	pop	de,bc,ix
	RET

BLON1:	dw	0
BLON2:	db	0

;--- NOMBRE: BLK_OF
;      Blink OFF para un bloque
;    ENTRADA:   HL = XXYY
;               B  = longitud X
;               C  = longitud Y
;    SALIDA:    L  = YY siguiente a la ultima linea
;               H  = XX original
;    REGISTROS: AF
;    LLAMADAS:  SET_WR, SET_VDP, WRVDP, VPEEK, C_STBT, C_BLKAD, SET_RD, RD_VDP
;    VARIABLES: PVRAM (no la modifica), BKIMG

_BLK_OF:	push	ix,bc,de

	ld	de,(PVRAM)	;Guardamos puntero a VRAM 
	ld	a,(PVRAM+2)
	ld	(BLOF1),de
	ld	(BLOF2),a

BUCBKOF:	push	hl,bc
	ld	a,h
	call	C_STBT
	cpl
	ld	e,a	;HL = direccion VRAM inicial  
	call	C_BLKAD	;E tiene el bit inicial a 1  

	push	de,hl
	ld	de,(BASEBK)
	or	a
	sbc	hl,de
	ld	de,BKIMG
	add	hl,de
	push	hl
	pop	ix
	pop	hl,de	;IX = dir. inicial zona imagen  

BLOF.1:	push	hl
	or	a
	call	VPEEK
	pop	hl
	push	hl,af	;A = contenido de (HL) [VRAM]   
	CALL	SET_WR	;VDP preparado para escribir en (HL)   
	POP	AF,hl

BLOF.0:	AND	E
	RRC	E
	JR	C,BLOF.2
	call	WRVRM
	ld	(ix),a	;Actualizamos zona imagen 
	inc	ix
	INC	HL
	DJNZ	BLOF.1
	jr	OTRALIN2
BLOF.2:	DJNZ	BLOF.0
	call	WRVRM
	ld	(ix),a
	inc	ix

OTRALIN2:	pop	bc,hl
	inc	l
	dec	c
	ld	a,c
	or	a
	jr	nz,BUCBKOF

	ex	de,hl	;Restauramos puntero a VRAM 
	ld	hl,(BLOF1)
	ld	a,(BLOF2)
	call	SET_VDP
	ex	de,hl

	pop	de,bc,ix
	RET

BLOF1:	dw	0
BLOF2:	db	0

;--- NOMBRE: BLK_MOV
;      Movimiento/redimensionado de un bloque blink
;    ENTRADA:   A = Direccion del movimiento:
;                   #01 -> Mover hacia arriba
;                   #02 -> Mover hacia la derecha
;                   #03 -> Mover hacia abajo
;                   #04 -> Mover hacia la izquierda
;                   #11 -> Reducir por debajo
;                   #12 -> Reducir por la izquierda
;                   #13 -> Reducir por arriba
;                   #14 -> Reducir por la derecha
;                   #21 -> Ampliar por arriba
;                   #22 -> Ampliar por la derecha
;                   #23 -> Ampliar por abajo
;                   #24 -> Ampliar por la izquierda
;               IX= Puntero a la tabla de datos del bloque:
;                   +0: Posicion X
;                   +1: Posicion Y
;                   +2: Longitud X
;                   +3: Longitud Y
;    SALIDA:    A = 0: Bloque movido/redimensionado OK
;               A = 1: Parametro incorrecto
;               A = 2: Salida de los limites, bloque no modificado
;    REGISTROS: -
;    LLAMADAS:  BLK_ON, BLK_OF, SET_WR, SET_VDP, WRVDP, VPEEK, C_STBT, C_BLKAD
;               SET_RD, RD_VDP
;    VARIABLES: PVRAM (no la modifica), BKIMG, MIN_X, MIN_Y, MAX_X, MAX_Y

_BLK_MOV:	push	ix,hl,de,bc

	ld	d,a
	and	%11110000
	jr	z,OKPMOV
	cp	#10
	jr	z,OKPMOV
	cp	#20
	jp	nz,FBKMOV1

OKPMOV:	ld	a,d
	and	%00001111
	cp	1
	jr	z,BLK_U
	cp	2
	jr	z,BLK_R
	cp	3
	jr	z,BLK_D
	cp	4
	jp	z,BLK_L

	jp	FBKMOV1

BLK_U:	ld	a,d
	cp	#11
	call	nz,DIBLSUP	;Si mover o ampliar, dibujar linea superior
	cp	34
	jp	z,FBKMOV2
	ld	a,d
	cp	#21
	call	nz,BORLINF	;Si mover o reducir, borrar linea inferior
	ld	a,d	;Actualizamos tabla
	cp	1
	jr	nz,BLKU1
	dec	(ix+1)	;Mover
	jr	BLKU3
BLKU1:	cp	#11
	jr	nz,BLKU2
	dec	(ix+3)	;Reducir
	jr	BLKU3
BLKU2:	dec	(ix+1)	;Ensanchar
	inc	(ix+3)
BLKU3:	jp	FBKMOV0

BLK_D:	ld	a,d
	cp	#13
	call	nz,DIBLINF	;Si mover o ampliar, dibujar linea inferior
	cp	34
	jp	z,FBKMOV2
	ld	a,d
	cp	#23
	call	nz,BORLSUP	;Si mover o reducir, borrar linea superior
	ld	a,d	;Actualizamos tabla 
	cp	3
	jr	nz,BLKD1
	inc	(ix+1)	;Mover
	jr	BLKD3
BLKD1:	cp	#13
	jr	nz,BLKD2
	dec	(ix+3)	;Reducir 
	inc	(ix+1)
	jr	BLKD3
BLKD2:	inc	(ix+3)	;Ensanchar
BLKD3:	jp	FBKMOV0

BLK_R:	ld	a,d
	cp	#12
	call	nz,DIBLDER	;Si mover o ampliar, dibujar linea derecha
	cp	34
	jp	z,FBKMOV2
	ld	a,d
	cp	#22
	call	nz,BORLIZQ	;Si mover o reducir, borrar linea izquierda
	ld	a,d	;Actualizamos tabla 
	cp	2
	jr	nz,BLKR1
	inc	(ix)	;Mover
	jr	BLKR3
BLKR1:	cp	#12
	jr	nz,BLKR2
	inc	(ix)	;Reducir
	dec	(ix+2)
	jr	BLKR3
BLKR2:	inc	(ix+2)	;Ensanchar
BLKR3:	jp	FBKMOV0

BLK_L:	ld	a,d
	cp	#14
	call	nz,DIBLIZQ	;Si mover o ampliar, dibujar linea izquierda
	cp	34
	jp	z,FBKMOV2
	ld	a,d
	cp	#24
	call	nz,BORLDER	;Si mover o reducir, borrar linea derecha
	ld	a,d	;Actualizamos tabla 
	cp	4
	jr	nz,BLKL1
	dec	(ix)	;Mover
	jr	BLKL3
BLKL1:	cp	#14
	jr	nz,BLKL2
	dec	(ix+2)	;Reducir
	jr	BLKL3
BLKL2:	dec	(ix)	;Ensanchar
	inc	(ix+2)
BLKL3:	jp	FBKMOV0

DIBLSUP:	ld	l,(ix+1)
	ld	a,(MIN_Y)
	cp	l
	ld	a,34	;Error (A=34) si la nueva linea a dibujar
	ret	z	;sobrepasa los margenes
	dec	l
	ld	h,(ix)
	ld	b,(ix+2)
	ld	c,1
	call	BLK_ON
	xor	a
	ret

BORLSUP:	ld	h,(ix)
	ld	l,(ix+1)
	ld	b,(ix+2)
	ld	c,1
	call	BLK_OF
	ret

DIBLINF:	ld	l,(ix+1)
	ld	a,(ix+3)
	add	l
	ld	l,a
	dec	l
	ld	a,(MAX_Y)
	cp	l
	ld	a,34	;Error (CY=1) si la nueva linea a dibujar
	ret	z	;supera los margenes
	inc	l
	ld	h,(ix)
	ld	b,(ix+2)
	ld	c,1
	call	BLK_ON
	xor	a
	ret

BORLINF:	ld	l,(ix+1)
	ld	a,(ix+3)
	add	l
	ld	l,a
	dec	l
	ld	h,(ix)
	ld	b,(ix+2)
	ld	c,1
	call	BLK_OF
	ret

DIBLDER:	ld	h,(ix)
	ld	a,(ix+2)
	add	h
	dec	a
	ld	h,a
	ld	a,(MAX_X)
	cp	h
	ld	a,34	;Error (A=34) si la nueva linea a dibujar
	ret	z	;supera los margenes
	inc	h
	ld	l,(ix+1)
	ld	b,1
	ld	c,(ix+3)
	call	BLK_ON
	xor	a
	ret

BORLDER:	ld	h,(ix)
	ld	a,(ix+2)
	add	h
	ld	h,a
	dec	h
	ld	l,(ix+1)
	ld	b,1
	ld	c,(ix+3)
	call	BLK_OF
	ret

DIBLIZQ:	ld	h,(ix)
	ld	a,(MIN_X)
	cp	h
	ld	a,34
	ret	z	;Error (A=34) si la nueva linea a dibujar
	dec	h	;sobrepasa los margenes
	ld	l,(ix+1)
	ld	b,1
	ld	c,(ix+3)
	call	BLK_ON
	xor	a
	ret

BORLIZQ:	ld	h,(ix)
	ld	l,(ix+1)
	ld	b,1
	ld	c,(ix+3)
	call	BLK_OF
	ret

FBKMOV0:	xor	a
	jr	FBKMOV
FBKMOV1:	ld	a,1
	jr	FBKMOV
FBKMOV2:	ld	a,2
FBKMOV:	pop	bc,de,hl,ix
	ret

;--- NOMBRE: BLK_ON1
;      Blink ON para un solo caracter
;      No actualiza la zona imagen si INTMODE<>0 (atencion a la interrupcion)
;    ENTRADA:   HL = XXYY
;    SALIDA:    -
;    REGISTROS: AF
;    LLAMADAS:  C_STBT, C_BLKAD, VPEEK, VPOKE
;    VARIABLES: PVRAM (no la modifica), BASEBK, BKIMG, INTMODE

_BLK_ON1:	push	hl,ix,de
	ld	a,h
	call	C_STBT
	push	af
	call	C_BLKAD

	push	de,hl
	ld	de,(BASEBK)
	or	a
	sbc	hl,de
	ld	de,BKIMG
	add	hl,de
	push	hl
	pop	ix
	pop	hl,de	;IX = dir. inicial zona imagen  

	pop	de
	or	a
	push	hl
	call	VPEEK
	or	d
	pop	hl
	ld	e,d
	call	VPOKE

	ld	a,(INTMODE)
	or	a
	jr	nz,FBLON1
	ld	(ix),d
FBLON1:	pop	de,ix,hl
	ret

;--- NOMBRE: BLK_OF1
;      Blink OFF para un solo caracter
;      No actualiza la zona imagen si INTMODE<>0 (atencion a la interrupcion)
;    ENTRADA:   HL = XXYY
;    SALIDA:    -
;    REGISTROS: AF
;    LLAMADAS:  C_STBT, C_BLKAD, VPEEK, VPOKE
;    VARIABLES: PVRAM (no la modifica), BASEBK, BKIMG, INTMODE

_BLK_OF1:	push	hl,de
	ld	a,h
	call	C_STBT
	cpl
	push	af
	call	C_BLKAD

	push	hl
	ld	de,(BASEBK)
	or	a
	sbc	hl,de
	ld	de,BKIMG
	add	hl,de
	push	hl
	pop	ix
	pop	hl	;IX = dir. inicial zona imagen 

	pop	de
	or	a
	push	hl
	call	VPEEK
	and	d
	pop	hl
	ld	d,a
	call	VPOKE

	ld	a,(INTMODE)
	or	a
	jr	nz,FBLOF1
	ld	(ix),d
FBLOF1:	pop	de,hl
	ret


;--- NOMBRE: BLK_SW1
;      Blink SWAP para un solo caracter
;      No actualiza la zona imagen si INTMODE<>0 (atencion a la interrupcion)
;    ENTRADA:   HL = XXYY
;    SALIDA:    -
;    REGISTROS: AF
;    LLAMADAS:  C_STBT, C_BLKAD, VPEEK, VPOKE
;    VARIABLES: PVRAM (no la modifica), BASEBK, BKIMG, INTMODE

_BLK_SW1:	push	hl,ix,de
	ld	a,h
	call	C_STBT
	push	af
	call	C_BLKAD

	push	hl
	ld	de,(BASEBK)
	or	a
	sbc	hl,de
	ld	de,BKIMG
	add	hl,de
	push	hl
	pop	ix
	pop	hl	;IX = dir. inicial zona imagen 

	pop	de
	or	a
	push	hl
	call	VPEEK
	xor	d
	pop	hl
	ld	d,a
	call	VPOKE

	ld	a,(INTMODE)
	or	a
	jr	nz,FBLSW1
	ld	(ix),d
FBLSW1:	pop	de,ix,hl
	ret

;--- NOMBRE: C_BLKAD
;      Calculo de la direccion VRAM para una coordenada Blink
;    ENTRADA:   HL = XXYY
;    SALIDA:    HL = direccion VRAM
;    REGISTROS: AF
;    LLAMADAS:  POR10
;    VARIABLES: BASEBK

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

;--- NOMBRE: C_BLKIM
;      Calculo de la direccion en la zona imagen para una coordenada blink
;    ENTRADA:   HL = XXYY
;    SALIDA:    HL = direccion RAM
;    REGISTROS: AF
;    LLAMADAS:  C_BLKAD, POR10
;    VARIABLES: BASEBK, BKIMG

_C_BLKIM:	push	de

	call	C_BLKAD
	ld	de,(BASEBK)
	or	a
	sbc	hl,de
	ld	de,BKIMG
	add	hl,de

	pop	de
	ret

;--- NOMBRE: C_STBT
;      Calculo del bit de la direccion blink.
;    ENTRADA:   A = coordenada X
;    SALIDA:    A = bit puesto a 1
;    REGISTROS: F
;    LLAMADAS:  -
;    VARIABLES: -

_C_STBT:	push	bc	; A mod 8 
	AND	7
	LD	B,A
	inc	b	;--> Esto no estaba en el listado original 
	LD	A,&H80
CSTB.0:	RRCA
	DJNZ	CSTB.0
	pop	bc
	rlca
	RET

	endif		;<--- !!! (fin del anterior "if USEBLK=SI") 

;--- NOMBRE: C_VRAD
;      Calculo de la direccion VRAM para una coordenada
;    ENTRADA:   HL = XXYY
;    SALIDA:    HL = dir. VRAM
;               CY = 0
;    REGISTROS: -
;    LLAMADAS:  POR80
;    VARIABLES: BASESCR

_C_VRAD:	push	af,de,bc
	push	hl
	pop	de
	ld	h,0
	call	POR80
	ld	c,d
	ld	b,0
	add	hl,bc
	ex	de,hl
	ld	hl,BASESCR
	add	hl,de
	pop	bc,de,af
	or	a
	ret

;--- NOMBRE: PRINT
;      Impresion de una cadena
;    ENTRADA:   HL = XXYY, coordenadas
;                    #FFFF para imprimir en las coordenadas actuales
;                    (direccion actual de VRAM)
;               DE = inicio del mensaje
;               CY = 0 y A = caracter de terminacion, o bien
;               CY = 1 y A = longitud de la cadena
;    SALIDA:    DE = caracter siguiente al de terminacion, o al ultimo
;               Direccion VRAM actualizada a despues de la cadena
;    REGISTROS: AF
;    LLAMADAS:  C_VRAD, SET_WR, WRVRM, INCPV, POR80
;    VARIABLES: PVRAM, BASESCR

_PRINT:	push	bc,hl,af
	inc	hl
	ld	a,h
	or	l
	jr	z,NOCOORD

SETCORD:	dec	hl
	call	C_VRAD
	call	SET_WR

NOCOORD:	pop	af
	ex	de,hl
	jr	c,CONLON

CONTER:	ld	d,(hl)	;D = car. a imprimir si no es el de term.
	cpi		;A = caracter de terminacion
	jr	z,PREND
	ld	c,a
	ld	a,d
	call	WRVRM
	ld	a,c
	jr	CONTER

CONLON:	ld	b,a
PRINT1:	ld	a,(hl)
	call	WRVRM
	inc	hl
	djnz	PRINT1

PREND:	ex	de,hl
	pop	hl,bc
	ret

;--- NOMBRE: POR10
;      Multiplicacion de un numero por 10
;    ENTRADA:   HL = numero
;    SALIDA:    HL = numero por 10
;    REGISTROS: F
;    LLAMADAS:  -
;    VARIABLES: -

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

;--- NOMBRE: POR80
;      Multiplicacion de un numero por 80
;    ENTRADA:   HL = numero
;    SALIDA:    HL = numero por 80
;    REGISTROS: F
;    LLAMADAS:  -
;    VARIABLES: -

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

;--- NOMBRE: INVCAR
;      Construye el video inverso de un caracter y lo copia en otro
;    ENTRADA:    B = Caracter original
;                C = Caracter en el que dejar el original invertido
;    SALIDA:     C = C + 1
;    REGISTROS:  AF
;    LLAMADAS:   SET_RD, SET_WR, SET_VDP, LDIRVR, LDIRRV, SUMPV
;    VARIABLES:  BASESCR, BASEPAT, PVRAM, BASESCR, BASEPAT

_INVCAR:	push	hl,de,bc

	ld	hl,BASEPAT
	ld	e,b
	ld	d,0
	ld	b,3

INPOR8:	sla	e
	rl	d
	djnz	INPOR8

	add	hl,de	;HL = dir. VRAM del caracter origen

	or	a
	call	SET_RD	;Copiamos el caracter al buffer RAM
	ld	de,BUFINV
	ld	bc,8
	call	LDIRVR

	ld	b,8
	ld	hl,BUFINV
INV1A1:	ld	a,(hl)	;Invertimos el caracter en RAM
	cpl
	ld	(hl),a
	inc	hl
	djnz	INV1A1

	pop	bc
	push	bc
	ld	hl,BASEPAT
	ld	e,c
	ld	d,0
	ld	b,3

INPOR82:	sla	e
	rl	d
	djnz	INPOR82

	add	hl,de	;HL = dir. VRAM del caracter destino
	push	hl

	or	a
	call	SET_WR	;Copiamos caracter invertido
	ld	hl,BUFINV
	pop	de
	ld	bc,8
	call	LDIRRV

	pop	bc,de,hl
	inc	c
	ret

BUFINV:	ds	8

;--- NOMBRE: VPUSH
;      Introduce una pantalla en la pila VRAM y actualiza VSP
;      Utiliza el buffer definido en la constante BUFFER
;      No modifica PVRAM
;    ENTRADA:   -
;    SALIDA:    CY = 0 -> Pantalla introducida OK
;               CY = 1 -> Pila VRAM llena, introduccion no realizada
;    REGISTROS: AF
;    LLAMADAS:  SET_VDP, SET_RD, SET_WR, LDIRVV, LDIRRV, LDIRVR, SUMPV
;    VARIABLES: PVRAM (no lo modifica), BUFFER, VSP, MAXSVP, BKIMG,
;               BASESCR, TABPILV

_VPUSH:	push	hl,de,bc,ix

	ld	de,(PVRAM)	;Guardamos puntero a VRAM  
	ld	a,(PVRAM+2)
	ld	(VPSH1),de
	ld	(VPSH2),a

	ld	a,(VSP)
	cp	MAXVSP
	scf
	jr	z,FVPUSH	;Regresamos con error si la pila esta llena
	inc	a
	ld	(VSP),a	;Si no, incrementamos VSP

	dec	a
	sla	a
	sla	a
	ld	c,a
	ld	b,0
	ld	hl,TABPILV
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)	;DE = destino en pila VRAM (pantalla)
	push	de
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl	;HL = destino en pila VRAM (blink)

	or	a
	call	SET_WR
	ld	hl,BKIMG
	ld	bc,256
	call	LDIRRV	;Copiamos zona imagen BLINK

	pop	de	;Recuperamos destino en pila VRAM (pantalla)
	ld	hl,BASESCR
	ld	bc,2048
	ld	ix,BUFFER
	xor	a
	call	LDIRVV	;Copiamos pantalla

	ld	hl,(VPSH1)	;Restauramos puntero VRA
	ld	a,(VPSH2)
	call	SET_VDP

	or	a
FVPUSH:	pop	ix,bc,de,hl
	ret

VPSH1:	dw	0
VPSH2:	db	0

;--- NOMBRE: VPOP
;      Restaura una pantalla de la pila VRAM y actualiza VSP
;      Utiliza el buffer definido en la constante BUFFER
;      No modifica PVRAM
;    ENTRADA:   -
;    SALIDA:    CY = 0 -> Pantalla extraida OK
;               CY = 1 -> Pila VRAM vacia, extraccion no realizada
;    REGISTROS: AF
;    LLAMADAS:  SET_VDP, SET_RD, SET_WR, LDIRVV, LDIRRV, LDIRVR, SUMPV
;    VARIABLES: PVRAM (no lo modifica), BUFFER, VSP, MAXSVP, BKIMG,
;               BASESCR, TABPILV

_VPOP:	push	hl,de,bc,ix

	ld	de,(PVRAM)	;Guardamos puntero a VRAM   
	ld	a,(PVRAM+2)
	ld	(VPP1),de
	ld	(VPP2),a

	ld	a,(VSP)
	or	a
	scf
	jr	z,FVPOP	;Regresamos con error si la pila esta vacia
	dec	a
	ld	(VSP),a	;Si no, decrementamos VSP

	sla	a
	sla	a
	ld	c,a
	ld	b,0
	ld	hl,TABPILV
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)	;DE = origen de pila VRAM (pantalla)
	push	de
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl	;HL = origen de pila VRAM (blink)
	push	hl

	or	a
	call	SET_RD
	ld	de,BKIMG
	ld	ix,BUFFER
	xor	a
	ld	bc,256
	call	LDIRVR	;Restauramos zona imagen BLINK

	ld	hl,(BASEBK)
	ex	de,hl
	pop	hl
	xor	a
	ld	ix,BUFFER
	ld	bc,256
	call	LDIRVV	;Restauramos zona BLINK en VRAM

	pop	hl	;Restauramos origen de la pila VRAM (pant.)
	ld	de,BASESCR
	ld	bc,2048
	ld	ix,BUFFER
	xor	a
	call	LDIRVV	;Restauramos pantalla

	ld	hl,(VPP1)	;Restauramos punte
	ld	a,(VPP2)
	call	SET_VDP	;Esta rutina termina con EI  

	or	a
FVPOP:	pop	ix,bc,de,hl
	ret

VPP1:	dw	0
VPP2:	db	0

;---------------- PRUEBAS -------------------

	if	PRUEBA_V=SI

;--- Prueba de FILLVR1 y 2

PFILL:	call	CLS
	call	KEY

	ld	hl,0
	or	a
	call	SET_WR

	ld	bc,80*10	;Se debe llenar la pantalla de As
	ld	a,65
	call	FILLVR1

	call	KEY

	ld	hl,80*11	;A continuacion, dejando una linea
	or	a	;en blanco, de Bs
	ld	bc,80*10
	ld	a,66
	call	FILLVR2

	call	KEY

	ld	bc,80*10	;Donde estaban las Bs deben aparecer Cs,
	ld	a,67	;comiendose la linea en blanco
	call	FILLVR1

	call	KEY

	ret

;--- Prueba de LDIRVR/RV/VV/PRINT

PLDIR:	call	CLS
	call	KEY

	ld	c,2	;Imprimimos "!"
	ld	e,"!"
	call	5

	ld	hl,81
	or	a
	call	SET_WR

	ld	hl,TXT1	;Debajo, TXT1...
	ld	bc,TXT1!-TXT1
	call	LDIRRV

	call	KEY	;...al lado, TXT2
	ld	hl,TXT2
	ld	bc,TXT2!-TXT2
	call	LDIRRV

	call	KEY

	ld	hl,0	;Copiamos las dos lineas mas abajo
	ld	de,80*3
	ld	bc,80*2
	xor	a
	ld	ix,#C000
	call	LDIRVV

	call	KEY

	ld	hl,#0505	;Prueba PRINT con coordenadas especificas
	ld	de,TXT3	;y caracter de terminacion...
	or	a
	ld	a,"J"
	call	PRINT

	call	KEY

	ld	hl,#FFFF
	ld	de,TXT4
	scf
	ld	a,TXT4!-TXT4
	call	PRINT

	call	KEY

	ret

TXT1:	db	"Esto es un texto"
TXT1!:	;
TXT2:	db	"...de prueba!"
TXT2!:	;
TXT3:	db	"PRINT con coordenadas especificas"
	db	"y caracter de terminacion...J"
TXT4:	db	" y PRINT aqui mismo!"
TXT4!:	;

;--- Prueba de manejo de bloques:
;    Bloque que se mueve con los cursores y se ensancha/reduce
;    con U/u, D/d, L/l, R/r

PBK:	call	CLS
	call	BLK_CLS
	ld	a,#01
	call	BLK_COL
	ld	a,#F0
	call	BLK_TIM

	;ld      a,1
	;ld      (SIZE_X),a
	;ld      (SIZE_Y),a
	;dec     a
	;ld      (CORD_X),a
	;ld      (CORD_Y),a

	ld	ix,CORD_X
	scf
	call	BLK_MAK

BUCPBK:	call	KEY
	cp	"f"
	ret	z

	cp	#1E	;Movimiento
	call	z,POS_U
	cp	#1F
	call	z,POS_D
	cp	#1D
	call	z,POS_L
	cp	#1C
	call	z,POS_R

	cp	"U"	;Ensanchamiento
	call	z,SIZE_U
	cp	"D"
	call	z,SIZE_D
	cp	"L"
	call	z,SIZE_L
	cp	"R"
	call	z,SIZE_R

	cp	"u"	;Estrechamiento
	call	z,SIZE_u
	cp	"d"
	call	z,SIZE_d
	cp	"l"
	call	z,SIZE_l
	cp	"r"
	call	z,SIZE_r

	cp	"f"	;Terminamos con "F"
	ret	z
	cp	"F"
	ret	z

	ld	ix,CORD_X	;Mostramos nuevo bloque
	scf
	call	BLK_MAK

	jp	BUCPBK	;Volvemos al bucle

	if	BKMOV=NO	;Cambio de posicion sin usar BLK_MOV

POS_U:	ld	hl,CORD_Y
	dec	(hl)
	ret

POS_D:	ld	hl,CORD_Y
	inc	(hl)
	ret

POS_R:	ld	hl,CORD_X
	inc	(hl)
	ret

POS_L:	ld	hl,CORD_X
	dec	(hl)
	ret

SIZE_U:	ld	hl,CORD_Y
	dec	(hl)
	ld	hl,SIZE_Y
	inc	(hl)
	ret

SIZE_D:	ld	hl,SIZE_Y
	inc	(hl)
	ret

SIZE_L:	ld	hl,CORD_X
	dec	(hl)
	ld	hl,SIZE_X
	inc	(hl)
	ret

SIZE_R:	ld	hl,SIZE_X
	inc	(hl)
	ret

SIZE_u:	call	GETHLBC
	call	BLK_OF
	ld	hl,SIZE_Y
	dec	(hl)
	ret

SIZE_d:	call	GETHLBC
	call	BLK_OF
	ld	hl,CORD_Y
	inc	(hl)
	ld	hl,SIZE_Y
	dec	(hl)
	ret

SIZE_l:	call	GETHLBC
	call	BLK_OF
	ld	hl,SIZE_X
	dec	(hl)
	ret

SIZE_r:	call	GETHLBC
	call	BLK_OF
	ld	hl,CORD_X
	inc	(hl)
	ld	hl,SIZE_X
	dec	(hl)
	ret

	endif

	if	BKMOV=SI	;Cambio de posicion usando BLK_MOV 

POS_U:	ld	ix,CORD_X
	ld	a,1
	call	BLK_MOV
	xor	a
	ret

POS_D:	ld	ix,CORD_X
	ld	a,3
	call	BLK_MOV
	xor	a
	ret

POS_R:	ld	ix,CORD_X
	ld	a,2
	call	BLK_MOV
	xor	a
	ret

POS_L:	ld	ix,CORD_X
	ld	a,4
	call	BLK_MOV
	xor	a
	ret

SIZE_U:	ld	ix,CORD_X
	ld	a,#21
	call	BLK_MOV
	xor	a
	ret

SIZE_D:	ld	ix,CORD_X
	ld	a,#23
	call	BLK_MOV
	xor	a
	ret

SIZE_L:	ld	ix,CORD_X
	ld	a,#24
	call	BLK_MOV
	xor	a
	ret

SIZE_R:	ld	ix,CORD_X
	ld	a,#22
	call	BLK_MOV
	xor	a
	ret

SIZE_u:	ld	ix,CORD_X
	ld	a,#11
	call	BLK_MOV
	xor	a
	ret

SIZE_d:	ld	ix,CORD_X
	ld	a,#13
	call	BLK_MOV
	xor	a
	ret

SIZE_l:	ld	ix,CORD_X
	ld	a,#14
	call	BLK_MOV
	xor	a
	ret

SIZE_r:	ld	ix,CORD_X
	ld	a,#12
	call	BLK_MOV
	xor	a
	ret

	endif

GETHLBC:	ld	a,(CORD_X)	;Devuelve en HL las coordenadas
	ld	h,a	;y en BC la longitud del bloque
	ld	a,(CORD_Y)
	ld	l,a
	ld	a,(SIZE_X)
	ld	b,a
	ld	a,(SIZE_Y)
	ld	c,a
	ret

CORD_X:	db	5
CORD_Y:	db	5
SIZE_X:	db	1
SIZE_Y:	db	1

;--- Prueba de la pila VRAM

PPV:	call	CLS
	call	BLK_CLS
	ld	a,#1F
	call	BLK_COL
	ld	a,#F0
	call	BLK_TIM

	ld	a,(VSP)
	add	"0"
	or	a
	ld	hl,0
	call	VPOKE
	ld	hl,#0505
	ld	de,TXT5
	xor	a
	call	PRINT
	ld	hl,#0506
	ld	de,TXT6
	xor	a
	call	PRINT
	ld	hl,#0505
	ld	bc,#0A02
	call	BLK_ON

	call	KEY
	call	VPUSH

PPV2:	ld	a,(VSP)
	add	"0"
	or	a
	ld	hl,0
	call	VPOKE
	ld	hl,#0706
	ld	de,TXT7
	xor	a
	call	PRINT
	ld	hl,#0707
	ld	de,TXT8
	xor	a
	call	PRINT
	ld	hl,#0706
	ld	bc,#0A02
	call	BLK_OF

	call	KEY
	call	VPUSH

PPV3:	ld	a,(VSP)
	add	"0"
	or	a
	ld	hl,0
	call	VPOKE
	ld	hl,#0A0A
	ld	de,TXT9
	xor	a
	call	PRINT
	ld	hl,#0A09
	ld	de,TXT10
	xor	a
	call	PRINT
	ld	hl,#0A09
	ld	bc,#0A02
	call	BLK_ON

	call	KEY
	call	VPOP
	ld	a,(VSP)
	add	"0"
	or	a
	ld	hl,0
	call	VPOKE
	call	KEY
	call	VPOP
	ld	a,(VSP)
	add	"0"
	or	a
	ld	hl,0
	call	VPOKE
	call	KEY

	ret

TXT5:	db	"Este es el texto 5...",0
TXT6:	db	"Este es el texto 6...",0
	db	"... eso.",0
TXT7:	db	"Este, el texto 7...",0
	db	"... ello.",0
TXT8:	db	"Aqui el texto 8...",0
	db	"... vaya!.",0
TXT9:	db	"Mira el texto 9...",0
	db	"... anda.",0
TXT10:	db	"Acabamos con el...",0
	db	"... texto 10.",0

;--- Prueba de INVCAR

PINV:	call	CLS	;Copia la A invertida en 192, y la muestra.
	ld	b,65
	ld	c,192
	call	INVCAR
	ld	a,192
	or	a
	ld	hl,160
	call	VPOKE
	call	KEY
	ret

	endif

;--- Subrutinas auxiliares para las pruebas

CONST:	equ	#0B
INNOE:	equ	#08

CLS:	ld	c,2
	ld	e,#0C
	jp	5

KEY:	exx		;Espera pulsacion de una tecla

WANOKEY:	ld	c,CONST	;Si hay teclas pulsadas pendientes 
	call	5	;las vamos pasando 
	or	a
	jr	z,WAKEY
	ld	c,INNOE
	call	5
	jr	WANOKEY

WAKEY:	ld	c,CONST	;Ahora esperamos a que se pulse una tecla 
	call	5
	or	a
	jr	z,WAKEY
	ld	c,INNOE
	call	5

	exx
	ret

