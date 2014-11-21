;NestorDiskImageCreator
;Creates a disk image file containing an empty FAT12 filesystem.

;=======================================

	;NestorDiskImageCreator
	;Crea un fichero imagen de la longitud especificada
	;Por Konami Man, 2-99

	;Uso: NDIC filename.ext dd|sd|<tamanio en K> [R]

;****************************************
;*                                      *
;*    MACROS, CONSTANTES Y CROQUETAS    *
;*                                      *
;****************************************

jri:	macro	@a
	jr	z,@a
	endm

jrni:	macro	@a
	jr	nz,@a
	endm

jrmn:	macro	@a
	jr	c,@a
	endm

jrmy:	macro	@a
	jr	z,$+4
	jr	nc,@a
	endm

jrmni:	macro	@a
	jr	c,@a
	jr	z,@a
	endm

jrmyi:	macro	@a
	jr	nc,@a
	endm

jpi:	macro	@a
	jp	z,@a
	endm

jpni:	macro	@a
	jp	nz,@a
	endm

jpmn:	macro	@a
	jp	c,@a
	endm

jpmy:	macro	@a
	jr	z,$+5
	jp	nc,@a
	endm

jpmni:	macro	@a
	jr	c,@a
	jp	z,@a
	endm

jpmyi:	macro	@a
	jp	nc,@a
	endm

dos:	macro
	call	5
	endm

;--- Funciones del DOS

_STROUT:	equ	#09
_OPEN:	equ	#43
_CREATE:	equ	#44
_CLOSE:	equ	#45
_READ:	equ	#48
_WRITE:	equ	#49
_SEEK:	equ	#4A
_PARSE:	equ	#5B
_TERM:	equ	#62
_EXPLAIN:	equ	#66
_GETVER:	equ	#6F

;**************************
;*                        *
;*   PROGRAMA PRINCIPAL   *
;*                        *
;**************************

;--- Para empezar, un poco de limpieza & presentacion

	ld	hl,FILENAME	;Limpiamos zona de parametros,
	ld	de,FILENAME+1	;FAT & directorio raiz
	ld	(hl),0
	ld	bc,25000
	ldir

	ld	c,_STROUT
	ld	de,PRESENS
	call	5
	jr	OKPRESEN

PRESENS:	db	13,10,"NestorDiskImageCreator 1.0 - by Konami Man, 2-1999",13,10,13,10,"$"
OKPRESEN:	;

;--- Comprobamos presencia de DOS 2

	ld	c,_GETVER
	call	5
	or	a
	ret	nz
	ld	a,b
	cp	1
	jrmy	OKDOS2

	ld	de,NODOS2S
	jp	FERR

NODOS2S:	db	"ERROR: DOS 2 required!",13,10,"$"
OKDOS2:	;

;--- Obtencion del nombre de fichero en FILENAME.
;    Si no hay parametros, muestra ayuda y termina.

	ld	a,1
	ld	de,FILENAME
	call	EXTPAR
	jp	nc,OKPAR1

	ld	de,AYUDA
	jp	FERR

AYUDA:	db	"Creates an empty disk image file of any size",13,10,13,10
	db	"Usage: NDIC <filename[.dsk]> d|s|<size> [R]",13,10
	db	"       d: Creates a standard double sided, double density, 720K disk image",13,10
	db	"       s: Creates a standard single sided, double density, 360K disk image",13,10
	db	"       <size>: Creates a disk image of the specified size (in Kilobytes)",13,10
	db	"               Range for <size> is 10 to 32500",13,10
	db	"       R: Set 240 root directory entries",13,10,13,10,"$"

OKPAR1:	ld	c,_PARSE	;El nombre de fichero tiene extension?
	ld	b,0
	ld	de,FILENAME
	call	5
	jp	nz,DOSERR

	bit	4,b	;No: le ponemos .DSK
	jr	nz,OKEXT
	ld	hl,DSKEXT
	ld	bc,5
	ldir
OKEXT:	;

;--- Obtencion del tamanyo del fichero a crear en SIZESTR

	ld	a,2
	ld	de,SIZESTR
	call	EXTPAR
	jr	nc,OKPAR2

	ld	de,NOSIZES
	jp	FERR
NOSIZES:	db	"ERROR: Disk size not specified!",13,10,"$"
OKPAR2:	;

	ld	a,(SIZESTR)	;Disco sd?
	or	%00100000
	cp	"s"
	ld	hl,360
	ld	(DISKSIZE),hl
	ld	a,1
	ld	(SIZEFLAG),a
	jp	z,OKPAR3

	ld	a,(SIZESTR)	;Disco dd?
	or	%00100000
	cp	"d"
	ld	hl,720
	ld	(DISKSIZE),hl
	ld	a,2
	ld	(SIZEFLAG),a
	jp	z,OKPAR3

	xor	a
	ld	(SIZEFLAG),a

	ld	hl,SIZESTR
	call	EXTNUM
	jp	c,ERRPAR3	;Error si el num tiene mas de 5 cifras...
	ld	a,e
	or	a
	jr	nz,ERRPAR3	;...o contiene un caracter incorrecto...

	push	bc
	pop	hl
	ld	de,32500
	call	COMPDEHL	;...o es mayor de 32500...
	jrmyi	ERRPAR3

	ld	de,10
	call	COMPDEHL	;...o es menor de 10.
	jrmyi	OKPAR3

ERRPAR3:	ld	de,BADSIZES
	call	FERR

BADSIZES:	db	"ERROR: Invalid disk size specification!",13,10
	db	"       Please specify a number between 10 and 32500",13,10,13,10,"$"
OKPAR3:	;

	ld	(DISKSIZE),hl

;--- Obtencion del parametro R si lo hay

	ld	a,3
	ld	de,SIZESTR
	call	EXTPAR
	jr	c,OKPARR

	ld	a,#FF
	ld	(ROOTFLAG),a
	ld	a,(SIZESTR)
	or	%00100000
	cp	"r"
	jr	z,OKPARR

	ld	de,BADRS
	call	FERR

BADRS:	db	"ERROR: Invalid parameter!",13,10
OKPARR:	;

;--- Creacion del fichero y relleno con tantos ceros como su longitud

	ld	de,ATINGS
	ld	c,_STROUT
	call	5
	jr	OKATING

ATINGS:	db	"Creating file...",13,"$"
OKATING:	;

	ld	c,_CREATE	;Creacion
	ld	de,FILENAME
	xor	a
	ld	b,0
	call	5
	or	a
	jp	nz,DOSERR
	ld	a,b
	ld	(FH),a

	ld	hl,(DISKSIZE)	;DE:HL = HL*1024 (tamanyo en bytes)
	ld	d,0
	ld	e,h
	ld	h,l
	ld	l,0
	sla	h
	rl	e
	rl	d
	sla	h
	rl	e
	rl	d

	ld	bc,1
	or	a
	sbc	hl,bc	;DE:HL = DE:HL-1
	ex	de,hl
	ld	bc,0
	sbc	hl,bc
	ex	de,hl

	ld	a,(FH)	;Colocamos el puntero
	ld	b,a	;en la longitud deseada...
	xor	a
	ld	c,_SEEK
	call	5
	jp	nz,DOSERR

	ld	a,(FH)	;...escribimos un byte,
	ld	b,a	;y ya tenemos el fichero con
	ld	de,DSKEXT+1	;esa longitud.
	ld	hl,1
	ld	c,_WRITE
	call	5
	jp	nz,DOSERR

	ld	a,(FH)	;Volvemos a poner el puntero del fichero
	ld	b,a	;al principio del mismo
	ld	c,_SEEK
	xor	a
	ld	de,0
	ld	hl,0
	call	5
	jp	nz,DOSERR

;--- Creacion del sector de arranque y la FAT

	ld	de,BUIBOOT
	ld	c,_STROUT
	call	5
	jr	OKBUIBOOT

BUIBOOT:	db	27,"K","Building boot sector & FAT...",13,"$"
OKBUIBOOT:	;

	ld	b,4	;Generamos numero de serie
	ld	hl,SERIAL	;aleatoriamente
BUCSER:	push	bc
	ld	a,r
	ld	(hl),a
	ld	b,a
TONTERIA:	djnz	TONTERIA
	inc	hl
	pop	bc
	djnz	BUCSER

	ld	a,(SIZEFLAG)	;Si el parametro es "d"
	cp	2	;copiamos directamente el sector
	jp	z,PUTFAT

	or	a	;Si el parametro es "s"
	jr	z,NOSDDD	;cambiamos lo que cambia respecto a dd
	ld	hl,720	;y copiamos directamente
	ld	(NUMSEC),hl
	ld	a,#F8
	ld	(ID),a
	ld	(FATENT),a
	ld	hl,2
	ld	(FATSIZE),hl
	ld	hl,1
	ld	(SIDES),hl
	jp	PUTFAT

NOSDDD:	ld	a,#F0
	ld	(ID),a
	ld	(FATENT),a
	ld	hl,(DISKSIZE)
	ld	ix,CLUSTABLE
	call	GETTABLE	;Obtiene A = Sectores por cluster
	ld	(SECCLUS),a
	sla	l
	rl	h	;HL = Numero de sectores
	ld	(NUMSEC),hl

OBCLUS:	srl	a	;HL = HL/A:
	jr	c,OKNUMCLUS	;obtenemos HL = numero de clusters
	srl	h
	rr	l
	jr	OBCLUS
OKNUMCLUS:	;

	ld	ix,FATTABLE
	call	GETTABLE	;Obtiene A = Sectores para la FAT
	ld	(FATSIZE),a

	ld	hl,0
	ld	(SECPIS),hl
	ld	(SIDES),hl

	ld	a,(SIZEFLAG)
	or	a
	jr	nz,PUTFAT

	ld	a,15	;Forzar 240 entradas dir. raiz?
	ld	(SECRAIZ),a
	ld	a,240
	ld	(ROOTENT),a
	ld	a,(ROOTFLAG)
	inc	a
	jr	z,PUTFAT

	ld	hl,(DISKSIZE)	;Anyiade sectores sobrantes a dir. raiz
	sla	l
	rl	h	;HL = Tamanyo disco en sectores
	ld	a,(FATSIZE)
	sla	a
	add	1+7	;Sector de arranque + dir. raiz
	ld	c,a
	ld	b,0
	or	a
	sbc	hl,bc	;HL = Sectores para datos
	ld	a,(SECCLUS)
	dec	a
	and	l	;A = Sectores sobrantes
	add	7	;A = Sectores totales para dir. raiz
	ld	(SECRAIZ),a
	ld	l,a
	ld	h,0
	sla	l	;HL*16 = Num. entradas dir. raiz
	rl	h
	sla	l
	rl	h
	sla	l
	rl	h
	sla	l
	rl	h
	ld	de,#00F0
	call	COMPDEHL
	ld	a,#F0
	jrmy	MAS256
	ld	a,l
MAS256:	ld	(ROOTENT),a

PUTFAT:	ld	a,(FH)	;Escribe el sector de arranque
	ld	b,a	;en el fichero
	ld	de,BOOTSEC
	ld	hl,512
	ld	c,_WRITE
	call	5
	jp	nz,DOSERR

;--- Establecimiento de los tres primeros bytes de cada copia de la FAT

	ld	hl,FATENT	;Primera copia
	ld	de,FATSPACE
	ld	bc,3
	ldir

	ld	a,(FATSIZE)	;Segunda copia
	sla	a
	ld	b,a
	ld	c,0	;BC = Longitud FAT en bytes (FATSEC*512)
	push	bc
	ld	hl,FATSPACE
	add	hl,bc
	ex	de,hl
	ld	hl,FATENT
	ld	bc,3
	ldir

;--- Escritura de los sectores de la FAT y el dir. raiz en el fichero

	pop	hl
	sla	l
	rl	h	;HL = Tamanyo FAT en bytes

	ld	a,(SECRAIZ)
	ld	b,a	;BC = Tamanyo dir. raiz en bytes
	sla	b
	ld	c,0

	add	hl,bc
	ld	de,FATSPACE
	ld	a,(FH)
	ld	b,a
	ld	c,_WRITE
	call	5
	jp	nz,DOSERR

;--- Cierre del fichero y terminacion

	ld	a,(FH)
	ld	b,a
	ld	c,_CLOSE
	call	5

	ld	de,SUCCESS
	jp	FERR

SUCCESS:	db	27,"K","Disk image file successfully created!",13,10,"$"


;*************
;*           *
;*   DATOS   *
;*           *
;*************

item:	macro	@b,@w
	db	@b
	dw	@w
	endm

FATTABLE:	item	1,339	;Tabla de sectores para FAT
	item	2,681	;segun numero de clusters
	item	3,1023
	item	4,1364
	item	5,1705
	item	6,2047
	item	7,2388
	item	8,2730
	item	9,3071
	item	10,3413
	item	11,3754
	item	12,4096
	db	0

CLUSTABLE:	item	1,4096/2	;Tabla de sectores por cluster
	item	2,8192/2	;segun el tamanyo en K
	item	4,16384/2
	item	8,32768/2
	item	16,65536/2
	db	0

DSKEXT:	db	".dsk",0
FATENT:	db	#F9,#FF,#FF	;Los trs primeros bytes de la FAT
DISKSIZE:	dw	0
FH:	db	0
SIZEFLAG:	db	0	;0 = size, 1 = sd, 2 = dd
ROOTFLAG:	db	0	;#FF = Forzar 240 entradas en dir. raiz
SECRAIZ:	db	7	;Sectores para el dir. raiz

;--- Sector de arranque (por defecto: disco 720K)

BOOTSEC:	db	#EB,#FE,#90
	db	"NESTOR  "
	dw	#200	;Bytes/sector
SECCLUS:	db	2	;Sectores/cluster
	dw	1	;Sectores no usados
	db	2	;Numero de FATs
ROOTENT:	dw	112	;Numero de entradas en dir. raiz
NUMSEC:	dw	1440	;Numero de sectores
ID:	db	#F9	;Media ID
FATSIZE:	dw	3	;Tamanyo FAT en sectores
SECPIS:	dw	9	;Sectores por pista
SIDES:	dw	2	;Numero de caras
	dw	0	;Sectores ocultos
	db	#18,#16	;Salto relativo
	db	"VOL_ID",0
SERIAL:	ds	4	;Numero de serie
	db	"KONAMI MAN "

	RET	NC	;Codigo de arranque
	LD	(#C070),DE
	LD	(#C07A),A
	LD	(HL),#6D
	INC	HL
	LD	(HL),#C0
J1043:	LD	SP,#F51F
	LD	DE,#C0B4
	LD	C,#0F
	CALL	#F37D
	OR	A
	JR	NZ,J1079
	LD	DE,#0100
	LD	C,#1A
	CALL	#F37D
	LD	HL,#0001
	LD	(#C0C2),HL
	LD	HL,#3F00
	LD	DE,#C0B4
	LD	C,#27
	CALL	#F37D
	JP	#0100
	LD	L,A
	RET	NZ
	CALL	#0000
	LD	A,C
	AND	#FE
	CP	#02
	JR	NZ,J107F
J1079:	LD	A,#00
	OR	A
	JP	Z,#4022
J107F:	LD	DE,#C08E
	LD	C,#09
	CALL	#F37D
	LD	C,#07
	CALL	#F37D
	JR	J1043

	db	"Boot error",13,10
	db	"Press any key for retry",13,10,"$",0
	db	"MSXDOS  SYS"
FINBOOT:	ds	512-(FINBOOT-BOOTSEC)


;******************
;*                *
;*   SUBRUTINAS   *
;*                *
;******************

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

;--- Comparacion de DE y HL
;    HL hace las veces de A
;    Modifica A

COMPDEHL:	ld	a,h
	sub	d
	ret	nz
	ld	a,l
	sub	e
	ret

;--- NOMBRE: GETTABLE
;      Recorre una tabla compuesta de datos en la forma: byte+word
;      Los words han de ser crecientes
;      Devuelve el primer byte para el cual word>=HL
;    ENTRADA:    IX = Direccion de inicio de la tabla
;                HL = Valor a comparar
;                A  = Byte
;    REGISTROS:  AF, IX, DE
;    LLAMADAS:   -
;    VARIABLES:  -

GETTABLE:	ld	a,(ix)
	or	a
	ret	z
	ld	e,(ix+1)
	ld	d,(ix+2)
	call	COMPDEHL
	ld	a,(ix)
	ret	c
	ret	z
	inc	ix
	inc	ix
	inc	ix
	jr	GETTABLE

;--- Finalizacion con error DE

FERR:	ld	c,_STROUT
	call	5
	ld	b,0
	ld	c,_TERM
	jp	5

;--- Finalizacion con error del DOS

DOSERR:	ld	de,ERRS
	ld	c,_EXPLAIN
	ld	b,a
	call	5
	ld	hl,ERRS
BUCERRS:	ld	a,(hl)
	or	a
	jr	z,OKERRS
	inc	hl
	jr	BUCERRS
OKERRS:	ld	a,"$"
	ld	(hl),a
	ld	de,ERRS2
	ld	c,_STROUT
	call	5
	ld	b,0
	ld	c,_TERM
	jp	5

ERRS2:	db	27,"K","DOS ERROR: "
ERRS:	;

FILENAME:	;
SIZESTR:	equ	FILENAME+100
FATSPACE:	equ	SIZESTR+10
