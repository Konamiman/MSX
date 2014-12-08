;Device partition lister for MEGASCSI
;Usage: PARLIST <ID> [/Sslot]

;=======================

	;*** PARLIST ***
	;    Obtiene una lista de las particiones de un dispositivo
	;    Uso: PARLIST <ID> [/Sslot]

_STROUT:	equ	#09
_DOSVER:	equ	#6F
BUFPAR:	equ	#4000-255

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


;******************************************************************************
;*                                                                            *
;*             PROGRAMA                                                       *
;*                                                                            *
;******************************************************************************

;*** Presentacion. Comprobacion del DOS 2 ***

	ld	de,PRESEN
	call	PRINT

	ld	c,_DOSVER
	call	5
	or	a
	ret	nz
	ld	a,b
	cp	2
	jrmyi	OKDOS

	ld	de,NODOS2
	call	PRINT
	ret
OKDOS:	;

;*** Obtencion de parametros. Si no hay o son incorrectos, muestra forma de uso

	; Obtencion del ID

	ld	a,1
	ld	de,BUFPAR
	call	EXTPAR

	jr	c,SHOWUSE	;Si no hay parametros
	ld	a,b
	cp	1
	jrni	ERRID

	ld	a,(de)
	ld	hl,"70"
	call	RANGE	;No es numero 0-7? Error (bad ID).
	jr	nz,ERRID
	sub	"0"
	ld	(ID),a
	jr	OKID

ERRID:	ld	de,ERRIDS
	call	PRINT
SHOWUSE:	ld	de,USAGE
	call	PRINT
	ret
OKID:	;

	; Obtencion del slot

	ld	a,2
	ld	de,BUFPAR
	call	EXTPAR
	jr	nc,HAYSLOT

	ld	a,(#F348)	;No hay segundo par: es el cont. primario
	ld	(SLOT),a
	jr	OKSLOT

HAYSLOT:	ld	a,(de)	;El segundo par. no empieza por
	cp	"/"	;/S o /s: error (bad slot specif.)
	jrni	ERRSL
	inc	de
	ld	a,(de)
	and	%11011111
	cp	"S"
	jrni	ERRSL
	inc	de

	ld	a,(de)
	ld	hl,"30"
	call	RANGE
	jr	nz,ERRSL
	sub	"0"
	ld	b,a	;B = Slot primario
	ld	(SLOT),a

	inc	de
	ld	a,(de)	;Siguiente caracter es 0? Ya esta.
	or	a
	jr	z,OKSLOT

	ld	hl,"30"
	call	RANGE
	jr	nz,ERRSL
	sub	"0"
	sla	a
	sla	a
	or	b
	or	%10000000
	ld	(SLOT),a

	inc	de
	ld	a,(de)
	or	a
	jr	nz,ERRSL	;Error si hay mas caracteres
	jr	OKSLOT

ERRSL:	ld	de,ERRSLS
	call	PRINT
	jp	SHOWUSE
OKSLOT:	;

	; Conversion del slot y el ID a cadenas

	ld	a,(ID)
	add	"0"
	ld	(IDCAD),a

	ld	a,(SLOT)
	ld	b,a
	and	%00000011
	add	"0"
	ld	(SLCAD),a
	bit	7,b
	jr	z,OKSLCAD
	ld	a,"-"
	ld	(SLCAD+1),a
	ld	a,b
	and	%00001100
	sra	a
	sra	a
	add	"0"
	ld	(SLCAD+2),a
OKSLCAD:	;

	; Comprueba que en el slot especificado hay un MegaSCSI ***

	call	CHK_SLOT
	jr	nc,HAYMEGA
	ld	de,ERRNM
	jp	PRINT
HAYMEGA:	;

	; Establece el nombre del dispositivo

	ld	a,(ID)	;Establecemos el primer bit de la nueva
	ld	b,a	;tabla segun la entrada
	inc	b
	ld	a,%10000000
SETID_LOP2:	rlca
	djnz	SETID_LOP2
	ld	(INQDATA),a

	ld	a,#c0
	ld	hl,INQDATA
	call	MEGA
	jp	c,MEGAERR
	ld	hl,AKIMISMO+16
	ld	de,DEVNAM
	ld	bc,16
	ldir
	ld	hl,DEVNAM+15
BUCDVNAM:	ld	a,(hl)
	cp	32
	jr	nz,OKDVNAM
	xor	a
	ld	(hl),a
	dec	hl
	jr	BUCDVNAM
OKDVNAM:	ld	hl,AKIMISMO+8
	ld	de,MANUNAM
	ld	bc,8
	ldir

;*** Muestra el slot a examinar ***

	ld	de,LISTING
	call	PRINT

;*** Muestra las particiones ***

	xor	a
	ld	(EXT_N),a
	inc	a
	ld	(PRIM_N),a

BUCSHOW:	ld	hl,PARNS	;Limpia zona de informacion
	ld	de,PARNS+1
	ld	bc,LONSHOW-1
	ld	(HL),32
	ldir

	ld	a,(PRIM_N)	;Convierte particion prim. a cadena
	add	"0"
	ld	(PARNS),a

	ld	a,(EXT_N)	;Convierte particion ext. e cadena
	or	a
	jr	z,NOEXT
	ld	e,a
	ld	d,0
	ld	hl,PARNS+2
	ld	b,3
	ld	c,0
	xor	a
	call	NUMTOASC
	ld	a,"-"
	ld	(PARNS+1),a

LEFT:	ld	a,(PARNS+2)	;Alinea el numero de part. ext.
	or	a	;a la izquierda
	jr	nz,OKLEFT
	ld	a,(PARNS+3)
	ld	(PARNS+2),a
	ld	a,(PARNS+4)
	ld	(PARNS+3),a
	ld	a," "
	ld	(PARNS+4),a
	jr	LEFT
OKLEFT:	;
NOEXT:	;

	ld	a,(ID)
	ld	d,a
	ld	a,(EXT_N)
	ld	b,a
	ld	a,(PRIM_N)

	call	GET_PART
	jr	nc,OKGPAR
	cp	18	;Error 18? Siguiente par. prim.
	jp	nz,MEGAERR
	ld	a,(PRIM_N)
	inc	a
	cp	5	;No hay mas par. prim? Terminamos.
	jp	z,FINNN
	ld	(PRIM_N),a
	xor	a
	ld	(EXT_N),a
	jp	BUCSHOW
OKGPAR:	;

	; Muestra tipo de particion

	exx
	ld	c,a
	ld	(TIPOPAR),a
	ex	af,af
	ld	hl,TABTYPE	;Recorremos la tabla de tipos.
BUCTIPO:	ld	a,(hl)
	cp	#FF	;FF? Fin de la tabla, tipo desconocido.
	jr	z,NOFTYP
	cp	c
	jri	FTYP
	ld	de,LONTYPE+1
	add	hl,de
	jr	BUCTIPO

NOFTYP:	ld	e,c
	ld	d,0
	ld	hl,TYPBYT+1
	ld	b,2
	ld	c,"0"
	ld	a,%00000001
	call	NUMTOASC
	ld	hl,NOFTS	;Establecemos cadena, o "unknown"
	jr	SETTYPS
FTYP:	inc	hl
SETTYPS:	ld	de,TYPES
	ld	bc,LONTYPE
	ldir
	exx

	; Establece sector inicial

	ld	a,(TIPOPAR)	;Tipo 0 (no usada) o 5 (extendida)?
	or	a	;Entonces no muestra sector inicial
	jr	z,EXTOUN	;ni tamanio.
	cp	5
	jr	z,EXTOUN

	ld	a,c
	exx
	ld	e,a
	ld	d,0
	ld	hl,FIRSS+1
	ld	b,2
	ld	a,%00000001
	ld	c,"0"
	call	NUMTOASC	;Byte 1
	exx
	push	de
	exx
	pop	de
	ld	hl,FIRSS+3
	ld	b,4
	ld	a,%10000001
	call	NUMTOASC
	ld	a,"#"
	ld	(FIRSS),a

	; Mostramos tamanio

	exx
	ld	a,b
	or	a
	jr	z,ENKAS
ENMEGS:	ld	a,"M"
	ld	(SIZES+5),a
	ld	e,h
	ld	d,b
	ld	b,3
TOMEGS:	srl	d
	rr	e
	djnz	TOMEGS
	jr	SHOWSIZ
ENKAS:	ld	a,"K"
	ld	(SIZES+5),a
	ex	de,hl
	srl	d
	rr	e
SHOWSIZ:	ld	hl,SIZES
	ld	b,5
	ld	c," "
	xor	a
	call	NUMTOASC
	ld	a,"B"
	ld	(SIZES+6),a

	; Mostramos informacion

EXTOUN:	ld	de,PARNS2
	call	PRINT

	; Siguiente particion

NEXPAR:	ex	af,af
	cp	5
	jri	ESEXT
NOESEXT:	ld	a,(EXT_N)
	or	a
	jr	z,NOESEX2
	inc	a
	ld	(EXT_N),a
	jp	BUCSHOW
NOESEX2:	ld	a,(PRIM_N)
	inc	a
	cp	5
	jri	FINNN
	ld	(PRIM_N),a
	jp	BUCSHOW
ESEXT:	ld	a,1
	ld	(EXT_N),a
	jp	BUCSHOW

FINNN:	ret

	; Terminacion con error devuelto por el MegaSCSI

MEGAERR:	ld	hl,MEGAERT
	ld	c,a
BUCERRT:	ld	a,(hl)
	or	a	;FF? Fin de la tabla, tipo desconocido.
	jr	z,NOFERR
	cp	c
	jri	FERR
	ld	de,LONERMG+1
	add	hl,de
	jr	BUCERRT

NOFERR:	ld	e,c
	ld	d,0
	ld	hl,ERRBYT+1
	ld	b,2
	ld	c,"0"
	ld	a,%00000001
	call	NUMTOASC
	ld	hl,NOFES	;Establecemos cadena, o "unknown"
	jr	SETERRS
FERR:	inc	hl
SETERRS:	ld	de,MEGAERS2
	ld	bc,LONERMG
	ldir

	ld	de,MEGAERS
	call	PRINT
	ret


;******************************************************************************
;*                                                                            *
;*             SUBRUTINAS                                                     *
;*                                                                            *
;******************************************************************************


;--- GET_PART
;    Obtencion de sector inicial, tamanyo y tipo de una particion
;
;    Entrada: A = Numero de particion primaria, la primera es la 1
;             B = Numero de particion extendida (0=entrada primaria)
;             D = Numero de dispositivo, 0 a 7
;             (SLOT) = Slot del Mega-SCSI
;    Salida:  C-DE = Primer sector de la particion
;             B-HL = Longitud de la particion en sectores
;             A = Error (si Cy = 1):
;               0: Protegido contra escritura (este no deberia salir nunca)
;               2: No esta listo
;               4: Error al trasnferir datos
;               8: Conflicto de reserva
;              12: Otro error/Error de arbitraje
;              16: Error de format(e)o
;              17: En ese slot no hay un MegaSCSI
;              18: Esa particion no existe
;              19: ID incorrecto
;             A = Tipo de particion (si Cy=0)
;               Si la particion es extendida (A=5), B-HL puede no ser valido
;               Si la particion no esta extendida, B ha de ser 0
;    Modifica:  Todos

RDSLT:	equ	#000C
CALSLT:	equ	#001C
DISKSLOT:	equ	#F348
_PFILE:	equ	#5C

GET_PART:	ld	(PILA),sp
	ld	(PAR_PRIM),a
	ld	a,b
	ld	(PAR_EXT),a
	xor	a
	ld	(REST_TABLA),a
	ld	a,d
	ld	(IDN),a
	and	%11111000
	ld	a,19
	jp	nz,FIN_ERROR

	;--- Hay un MegaSCSI en el slot indicado?

	call	CHK_SLOT
	ld	a,17
	jp	c,FIN_ERROR

	;--- Guardamos la tabla de la particion extendida 15,
	;    y la establecemos como todo el disco

	ld	a,#86
	ld	c,15
	ld	hl,OLD_TABLE
	call	MEGA
	jp	c,FIN_ERROR

	ld	a,(IDN)	;Establecemos el primer bit de la nueva
	ld	b,a	;tabla segun la entrada
	inc	b
	ld	a,%10000000
SETID_LOOP:	rlca
	djnz	SETID_LOOP
	ld	(NEW_TABLE),a

	ld	a,#87	;Establecemos la nueva tabla
	ld	c,15
	ld	hl,NEW_TABLE
	call	MEGA
	jp	c,FIN_ERROR
	ld	a,#FF
	ld	(REST_TABLA),a

	;--- Accion! (lectura de la tabla de particion primaria)

	xor	a
	ld	(SEC_INI),a
	ld	(SEC_INI+1),a
	ld	(SEC_INI+2),a

	ld	a,(PAR_PRIM)
	or	a
	ld	a,18
	jp	z,FIN_ERROR	;Error si se indica particion > 4
	ld	a,(PAR_PRIM)	;o es 0
	cp	5
	ld	a,18
	jp	nc,FIN_ERROR

	ld	a,(PAR_PRIM)
	ld	b,a
	ld	a,-16
BUC1:	add	16
	djnz	BUC1
	ld	c,a
	ld	b,0
	ld	hl,#1BE
	add	hl,bc	;HL = Posicion inicio tabla de particion

	ld	(TABLA_INI),hl
	ld	a,#40+15
	ld	bc,#0100
	ld	de,0	;Leemos el sector fisico 0
	ld	hl,SECTOR
	or	a
	breakp
	call	MEGA
	jp	c,FIN_ERROR

	ld	ix,(TABLA_INI)
	ld	bc,SECTOR
	add	ix,bc	;IX = Inicio tabla particion

	ld	a,(ix+4)
	cp	5
	jr	nz,ES_PRIM
	ld	a,(PAR_EXT)
	or	a
	jr	nz,ES_EXT

ES_PRIM:	ld	a,(PAR_EXT)	;Error si la particion no esta extendida
	or	a	;y se ha indicado B<>0 a la entrada
	ld	a,18
	jp	nz,FIN_ERROR

	call	SET_REG	;Establece C-DE y B-HL a partir de IX

	ld	a,(ix+4)
	jp	FIN_OK

	;--- Bucle de lectura de la tabla secundaria

ES_EXT:	ld	a,1
	ld	(CURR_PAR),a

	ld	a,(ix+8)
	ld	(SEC_INI),a	;Establecemos el sector inicial,
	ld	a,(ix+9)	;que sera la base a sumar al campo
	ld	(SEC_INI+1),a	;"primer sector" de las tablas
	ld	a,(ix+10)	;extendidas
	ld	(SEC_INI+2),a

	ld	ix,SEC_INI	;Leemos el sector que contiene
	ld	c,(ix+2)	;la nueva tabla de particiones
	ld	d,(ix+1)
	ld	e,(ix)
BUC_EXT:	ld	b,1
	ld	hl,SECTOR
	ld	a,#40+15
	or	a
	push	bc,de
	call	MEGA
	pop	de,bc
	jp	c,FIN_ERROR

	ld	a,(PAR_EXT)	;Comprobamos si es esta
	ld	h,a	;la particion que queremos
	ld	a,(CURR_PAR)
	cp	h
	jr	nz,SIGUIENTE

ESESTA:	ld	ix,SECTOR+#1BE	;IX = Inicio primera tabla particion
	call	SET_REG2	;B-HL = Longitud (C-DE ya estan)
	ld	a,(ix+8)
	add	e	;Sumamos a C-DE el valor de "primer
	ld	e,a	;sector" de la tabla
	ld	a,(ix+9)
	adc	d
	ld	d,a
	ld	a,(ix+10)
	adc	c
	ld	c,a
	ld	a,(ix+4)
	jp	FIN_OK

SIGUIENTE:	ld	ix,SECTOR+#1CE	;Error si se busca la siguiente
	ld	a,(ix+4)	;particion extendida
	or	a	;pero no existe
	ld	a,18
	jp	z,FIN_ERROR
	ld	a,(CURR_PAR)
	inc	a
	ld	(CURR_PAR),a
	call	SET_REG
	ld	a,(SEC_INI)
	add	e
	ld	e,a
	ld	a,(SEC_INI+1)
	adc	d
	ld	d,a
	ld	a,(SEC_INI+2)
	adc	c
	ld	c,a
	jp	BUC_EXT

;--- Finalizacion con o sin error

FIN_ERROR:	call	FIN
	scf
	jr	FIN2

FIN_OK:	call	FIN
	or	a
	jr	FIN2

FIN2:	ld	sp,(PILA)
	ret

FIN:	push	bc
	ld	b,a
	ld	a,(REST_TABLA)
	inc	a
	ld	a,b
	pop	bc
	ret	nz

	push	af,bc,de,hl
	ld	a,#87
	ld	c,15
	ld	hl,OLD_TABLE
	call	MEGA
	pop	hl,de,bc,af
	ret

;--- Carga de C-DE y B-HL para la salida.
;    IX ha de apuntar al inicio de la tabla de la particion

SET_REG:	ld	e,(ix+8)
	ld	d,(ix+9)
	ld	c,(ix+10)
SET_REG2:	ld	l,(ix+12)
	ld	h,(ix+13)
	ld	b,(ix+14)
	ret

;--- Datos

IDN:	db	0
PAR_PRIM:	db	0
PAR_EXT:	db	0
CURR_PAR:	db	0
PILA:	dw	0
TABLA_INI:	dw	0
SEC_INI:	ds	3
REST_TABLA:	db	0	;Si es #FF hay que restaurar la tabla
	;                        ;de particion 15 antes de terminar
OLD_TABLE:	ds	16
NEW_TABLE:	db	0	;Id. de dispositivo
	db	0
	db	0,0,0	;Sector inicial
	db	#FF,#FF,#FF	;Longitud (todo el disco)
	db	#02,#00	;Tamanyo de un sector
	ds	6


;--- Comprobacion de la presencia de un MegaSCSI en un slot
;    Entrada:  (SLOT) = Slot a comprobar
;    Salida:   Cy = 0 si hay un MegaSCSI
;    Modifica: AF

CHK_SLOT:	ld	a,(SLOT)
	push	bc,de,hl
	call	SRCHMEGA
	pop	hl,de,bc
	ccf
	ret

SRCHMEGA:	ld	b,8
	ld	c,a
	ld	de,#7FE0
	ld	hl,MEGA_STR

SMS_LOOP:	push	hl,de,bc
	ld	a,c
	ex	de,hl
	call	RDSLT
	pop	bc,de,hl
	xor	(hl)
	ret	nz
	inc	de
	inc	hl
	djnz	SMS_LOOP
	scf
	ret

MEGA_STR:	db	"MEGASCSI"


;--- Llamada a una funcion del Mega-SCSI
;    Entrada: (SLOT) = Slot del Mega-SCSI
;             Registros segun la funcion. Siempre preserva IX,IY.
;    Salida:  Segun la funcion

MEGA:	push	ix,iy
	ld	iy,(SLOT-1)
	ld	ix,#7FCC
	call	CALSLT
	pop	iy,ix
	ret

;--- Impresion de una cadena

PRINT:	push	bc
	ld	c,_STROUT
	call	5
	pop	bc
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


;--- NOMBRE: RANGE
;      Comprueba que un byte esta dentro de un rango
;    ENTRADA:    H = Valor superior del rango (inclusive)
;                L = Valor inferior del rango (inclusive)
;                A = Byte
;    SALIDA:     Z = 1 Si esta dentro del rango (Cy = ?)
;                Cy= 1 si esta por encima del rango (Z = 0)
;                Cy= 0 si esta por debajo del rango (Z = 0)

RANGE:	cp	l	;Menor?
	ccf
	ret	nc

	cp	h	;Mayor?
	jr	z,R_H
	ccf
	ret	c

R_H:	push	bc	;=H?
	ld	b,a
	xor	a
	ld	a,b
	pop	bc
	ret


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



;******************************************************************************
;*                                                                            *
;*             ZONA DE DATOS                                                  *
;*                                                                            *
;******************************************************************************

SLOT:	db	0	;Slot del Mega-SCSI
ID:	db	0	;ID del dispositivo a examinar
EXT_N:	db	0
PRIM_N:	db	0
PARTITION:	db	0	;Particion DOS o extendida
;                                       ;(extendida: en exceso 64)

PRESEN:	db	13,10,"Partition listing for Mega-SCSI",13,10
	db	"By Nestor Soriano (Konami Man), 1998",13,10,10,"$"
NODOS2:	db	"*** ERROR: DOS 2 required!",13,10,"$"
USAGE:	db	"Usage: PARLIST <ID> [/Sp[s]]",13,10
	db	"       ps: slot number of disk controller (primary, secondary)",13,10
	db	"       By default, master controller is used",13,10,"$"

ERRIDS:	db	"*** ERROR: Invalid ID number",13,10,10,"$"
ERRSLS:	db	"*** ERROR: Invalid slot specification",13,10,10,"$"
ERRNM:	db	"*** ERROR: No Mega-SCSI found in the specified slot"
	db	13,10,"$"
LISTING:	db	"Listing partitions for device with ID "
IDCAD:	db	"!"
	db	" controlled by Mega-SCSI in slot "
SLCAD:	db	"    ",13,10
	db	"Device name: "
DEVNAM:	ds	16,32
	db	", manufactured by "
MANUNAM:	ds	8
	db	13,10,10
	db	"Par. num.              Type                 First sector          Size",13,10
	db	"--------               ----                 ------------          ----",13,10,10,"$"
LONSHOW:	equ	69
PARNS2:	db	"  "
PARNS:	ds	15
TYPES:	ds	29
FIRSS:	ds	18
SIZES:	db	"      B"
	db	13,10,"$"

LONTYPE:	equ	24
TABTYPE:	db	0,"--- UNUSED ENTRY ---    "
	db	1,"MS(X)-DOS, FAT12        "
	db	2,"XENIX                   "
	db	3,"XENIX                   "
	db	4,"MS(X)-DOS, FAT16        "
	db	5,"MS(X)-DOS extended      "
	db	6,"MS(X)-DOS hugue (>32Mb) "
	db	7,"OS/2                    "
	db	#63,"UNIX V                  "
	db	#64,"Net                     "
	db	#75,"PC/IX                   "
	db	#DB,"Concurrent DOS          "
	db	#FF
NOFTS:	db	"-- Unknown (byte "
TYPBYT:	db	"#  ) --"

GENERRS:	db	"Error!!",13,10,10,"$"
TIPOPAR:	db	0

LONERMG:	equ	32
MEGAERS:	db	"*** MEGASCSI ERROR: "
MEGAERS2:	ds	LONERMG
	db	13,10,"$"
MEGAERT:	db	2,"Device not ready                "
	db	4,"Data transfer error             "
	db	8,"Reservation conflict            "
	db	12,"Other error / arbitration error "
	db	16,"Format error                    "
	db	19,"Invalid ID number               "
	db	0
NOFES:	db	"Unknown error (code "
ERRBYT:	db	"#  )        "

INQDATA:	db	%00100000,0
	dw	comando
	dw	AKIMISMO	;data
	dw	AKIMISMO+#1000	;status
	dw	AKIMISMO+#1100	;message

comando:	db	#12,0,0,0,100,0
;data:         equ     AKIMISMO
;status:       equ     AKIMISMO+#1000
;message:      equ     AKIMISMO+#1100
AKIMISMO:	;
SECTOR:	;
