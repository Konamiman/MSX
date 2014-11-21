;Chapuza Copy 2 - Diskcopy utility for MSX-DOS 2
;Uses all the available RAM and VRAM to minimize disk changes.
;Usage: CHCOPY2 <source drive> <destination drive>

;======================================

	; Chapcopy 2 !!
	; Para DOS 2, usa toda la RAM y la VRAM
	; Necesita NUMTOASC al final
	;
	; Formato: CHCOPY2 origen: destino:
	;
	; Salida en pantalla:

; Chapuza Copy #2.0 - by Konami Man, 5-96
;
; Source drive is A:                                   Free RAM:  1024K
; Destination drive is B:                              Free VRAM:  112K
;
; Disk type: Double Sided, 720 Kb, 1440 sectors
;
; ----------------------------------------------------------------------------
;
; Reading sectors 34-90 ...
;

	org	#100

;*** EQUS Y MACROS

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

txt:	macro	@text	;Uso: txt "cadena"
	dw	len@sym-$-2	;Define una cadena en el formato requerido
	db	@text	;por la subrutina PRINT
len@sym:	;
	endm

ESC:	equ	27

POS:	macro	@x,@y	;Posiciona el cursor en X,Y si se PRINTea
	db	ESC,"Y",@y+#20,@x+#20
	endm

ERALIN:	macro		;Borra la linea sin mover el cursor
	db	ESC,"l"
	endm

ERAEND:	macro		;Borra hasta el final de la linea
	db	ESC,"K"	;sin mover el cursor
	endm

CLS:	macro
	db	#0C
	endm

UP:	macro	@n	;Sube el cursor n posiciones
	ds	@n,#1E
	endm

DOWN:	macro	@n
	ds	@n,#1F
	endm

RIGHT:	macro	@n
	ds	@n,#1C
	endm

LEFT:	macro	@n
	ds	@n,#1D
	endm

DEL:	macro	@n
	ds	@n,#7F
	endm

ENTER:	macro	@n
	ds	@n,#0A
	db	#0D
	endm

DOSVER:	equ	#6F	;Funciones del DOS
STROUT:	equ	#09
DEFAB:	equ	#63
DEFER:	equ	#64
SETDTA:	equ	#1A
RDABS:	equ	#2F
WRABS:	equ	#30
READ:	equ	#48
WRITE:	equ	#49
CONST:	equ	#0B
TERM:	equ	#62
INNOE:	equ	#08
DPARM:	equ	#31
EXPLAIN:	equ	#66

INP:	equ	#8A	;Errores del DOS
IPARM:	equ	#8B
IDRV:	equ	#DB
NCOMP:	equ	#FF
NOPAR:	equ	#89

POINTDPB:	equ	#F355
INSDISK:	equ	#F24F
EXTBIO:	equ	#FFCA
RAMSLOT:	equ	#F344
ENASLT:	equ	#0024

;*** PROGRAMA PRINCIPAL

	; Presentacion y comprobacion del DOS 2

CHAPC2:	ld	c,DOSVER
	call	5
	ld	a,b
	cp	2
	jrmyi	OKDOS2

NODOS2:	ld	c,STROUT
	ld	de,NOD2STR
	jp	5

OKDOS2:	ld	de,INISTR
	call	PRINT

	; Extraccion de parametros (ver EXTUNI y EXTPAR)

	ld	a,1
	ld	ix,UNI_ORI
	call	EXTUNI
	ld	a,2
	ld	ix,UNI_DES
	call	EXTUNI

	; Comprobamos que las unidades especificadas existen
	; y son unidades de diskete del mismo tipo (SS/DS)

CHKORI:	ld	a,(UNI_ORI+1)
	dec	a
	ld	l,a
	ld	h,0
	add	hl,hl
	ex	de,hl
	ld	ix,POINTDPB	;IX = Puntero a la direccion inicial
	add	ix,de	;del DPB de la unidad de origen

	ld	l,(ix)	;HL = Puntero al DPB
	ld	h,(ix+1)
	ld	a,h
	or	l
	ld	b,IDRV	;"Invalid drive" si el puntero es cero
	jp	z,FIN

	inc	hl
	ld	a,(hl)
	ld	b,NCOMP
	cp	#F8
	jpmn	FIN
	cp	#F9
	jpmy	FIN
	ld	(UNI_ORI+2),a	;Tipo de disco: F8, simple cara; F9 doble.

CHKDEST:	ld	a,(UNI_DES+1)
	dec	a
	ld	l,a
	ld	h,0
	add	hl,hl
	ex	de,hl
	ld	ix,POINTDPB	;IX = Puntero a la direccion inicial 
	add	ix,de	;del DPB de la unidad de destino

	ld	l,(ix)	;HL = Puntero al DPB 
	ld	h,(ix+1)
	ld	a,h
	or	l
	ld	b,IDRV	;"Invalid drive" si el puntero es cero 
	jp	z,FIN

	inc	hl
	ld	a,(hl)	;"Incompatible disk" si no es un flopy
	ld	b,NCOMP
	cp	#F8
	jpmn	FIN
	cp	#F9
	jpmy	FIN
	ld	(UNI_DES+2),a	;Tipo de disco: F8, simple cara; F9 doble.

COMP:	ld	hl,UNI_DES+2	;"Incompatible disk" si no son iguales
	ld	a,(UNI_ORI+2)
	cp	(hl)
	jpni	FIN

	; Obtencion de las rutinas y la tabla de datos del mapeador

	ld	de,#0401
	call	EXTBIO
	ld	(MAPTAB),hl
	inc	de
	call	EXTBIO
	ld	de,ALL_SEG
	ld	bc,#30
	ldir

	; Obtencion de la cantidad total de memoria disponible

	ld	ix,(MAPTAB)
	ld	iy,0
	ld	bc,8
	ld	d,0
BUCFRAM:	ld	a,(ix)	;Al acabar, FREERAM=no. de segmentos libres
	or	a	;incluyendo el segmento inicial de la
	jr	z,OKFRAM	;pagina 1. El de la pagina 2 es el area
	ld	a,(ix+2)	;de transferencia de disco (DTA)
	ld	e,a
	add	iy,de
	add	ix,bc
	jr	BUCFRAM
OKFRAM:	inc	iy
	ld	(FREERAM),iy

	ld	hl,0	;Al acabar, FREEVR=segmentos VRAM libres
	scf		;(3 con 64K VRAM, 7 con 128K VRAM)
	call	VPEEK
	cpl
	ld	b,a
	ld	hl,0
	scf
	call	VPOKE
	ld	hl,0
	scf
	call	VPEEK
	cp	b
	ld	a,3
	jrni	ES64KV

ES128KV:	add	4
ES64KV:	ld	(FREEVR),a

	; Definicion de las rutinas de error de disco y terminacion

	ld	c,DEFAB
	ld	de,ABRUT
	call	5

	ld	c,DEFER
	ld	de,ERRUT
	call	5

	ld	hl,INSDISK	;Nueva rutina "Insert disk for drive tal"
	ld	de,OLDINS
	ld	bc,3
	ldir
	ld	hl,JNEWINS
	ld	de,INSDISK
	ld	bc,3
	ldir

	ld	c,SETDTA	;Area de transferencia de disco: pagina 2
	ld	de,#8000
	call	5

	; Guardamos los patrones de los caracteres 200 a 202

	ld	hl,4096+200*8
	or	a
	call	SET_RD
	ld	de,OLDCHR
	ld	bc,8*3
	call	LDIRVR

	; Redefinicion de los caracteres 200 a 202

	ld	hl,4096+200*8
	or	a
	call	SET_WR
	ld	hl,NEWCHR
	ld	bc,8*3
	call	LDIRRV

	; Mostramos drives fuente/destino, barra y mensaje "Insert disk"

	ld	a,(UNI_ORI)	;Imprimimos
	ld	(ORI_INFO),a	;"Source drive is X:" y
	ld	a,(UNI_DES)	;"Destination drive is Y:"
	ld	(DES_INFO),a
	ld	de,DRV_INFO
	call	PRINT

	ld	de,BARRA	;Imprimimos barra y
	call	PRINT	;"Insert SOURCE", o
	ld	a,(UNI_ORI+1)	;"Insert SOURCE and DESTINATION",
	ld	b,a	;segun si la unidad de origen es o no
	ld	a,(UNI_DES+1)	;la misma que la de destino
	cp	b
	ld	de,PRESIN1
	jri	SONIGU
SONDIST:	ld	de,PRESIN2
SONIGU:	call	PRINT

	call	ACTMSTR	;Actualizamos cadena de cantidad de memoria
	ld	de,MEMSTR	;y la imprimimos
	call	PRINT

	call	KEY

	ld	de,BOLIN	;Borramos "Insert & press"
	call	PRINT

	; Averiguamos tipo de disco de origen

	ld	c,DPARM
	ld	de,BUFFER
	ld	a,(UNI_ORI+1)
	ld	l,a
	call	5
	push	de
	pop	ix
	ld	a,(ix+11)
	ld	(DSKTYPE),a
	cp	#F9
	ld	de,DISK9
	jri	ESDISK9
ESDISK8:	ld	de,DISK8
ESDISK9:	call	PRINT

	; Reservamos memoria

	ld	ix,SEGTBL	;SEGTBL: tabla de segmentos reservados
	ld	a,(RAMSLOT)	;en fomato slot (#FF: VRAM), segmento
	ld	(ix),a
	call	GET_P1	;El primer segmento es la pagina 1
	ld	(ix+1),a	;del TPA
	ld	(INIPG1),a
	inc	ix
	inc	ix
	ld	iy,NUMALLS	;NUMALLS: numero de segmentos reservados

	ld	a,(DSKTYPE)
	cp	#F8
	ld	a,23
	jri	SON23
SON45:	add	45-23	;B = segmentos necesarios para
SON23:	ld	b,a	;hacer la copia de una pasada

	ld	a,b
	ld	(NECESEG),a
	dec	b
BUCRES:	push	bc	;Reservamos NECESEG-1 segmentos, si es
	ld	a,(RAMSLOT)	;posible
	and	%10001111
	or	%00100000
	ld	b,a
	xor	a
	call	ALL_SEG
	jr	c,NOFREES
	inc	(iy)
	ld	(ix),b
	ld	(ix+1),a
	inc	ix
	inc	ix
	pop	bc
	djnz	BUCRES
	push	bc

NOFREES:	pop	bc
	ld	a,b	;Si ya hemos reservado los segmentos
	or	a	;necesarios, no reservamos VRAM. Si no,
	jr	z,NORESV	;B = num. de segmentos por reservar.

	ld	a,(FREEVR)
	ld	e,a	;E = num. segmentos VRAM libres
RESV:	push	bc	;(todos menos el primero)
	ld	a,#FF
	ld	(ix),a	;Si el indicador de slot es #FF,
	ld	a,e	;nos referimos a un segmento de la VRAM
	ld	(ix+1),a
	inc	(iy)
	inc	ix
	inc	ix
	dec	e
	pop	bc	;Al final, NUMALLS = num. segmentos res.,
	jr	z,NOFREEV	;y SEGTBL contiene los segmentos en formato
	djnz	RESV	;slot (#FF -> VRAM), segmento.
NOFREEV:	;
NORESV:	;

	; Lectura

LECTURA:	xor	a
	ld	(RDORWR),a
	ld	a,(NUMALLS)
	ld	b,a	;B = segmentos disponibles
BUCRDSEC:	ld	hl,NECESEG
	ld	a,(SEGRACT)	;A = primer segmento a utilizar (0 1a vez)
	cp	(hl)
	jri	ESCRIBE	;Pasamos a escritura si ya hemos leido
	inc	a	;todo el disco
	cp	(hl)
	jrni	NORDLAST
	dec	a
	ld	l,a
	ld	a,(DSKTYPE)	;Si tenemos que leer el ultimo bloque
	cp	#F8	;y el disco es de simple cara, saltamos a
	ld	a,l
	jpi	LELAST8	;una rutina especial (lectura 16 sectores)
	inc	a
NORDLAST:	dec	a

BUCMEN:	ld	c,a	;Si el segmento a usar es mayor que
	ld	a,(NUMALLS)	;NUMALLS es que estamos en otra vuelta.
	cp	c	;Entonces le restamos NUMALLS las veces
	jrmy	OKSEG	;necesarias.
	sub	c
	neg
	jr	BUCMEN
OKSEG:	ld	a,c

	push	bc,af
	ld	hl,(SECRACT)	;HL = primer sector a leer
	push	hl
	pop	de
	ld	bc,32
	add	hl,bc
	ld	(SECRACT),hl	;Actualizamos SECYARD (sectores ya leidos)

	xor	a	;Imprimimos y actualizamos "Reading..."
	call	ACTRDWR

	ld	a,(UNI_ORI+1)	;Leemos sectores
	dec	a
	ld	l,a
	ld	h,32
	ld	c,RDABS
	call	5

	pop	af	;Copiamos al segmento correspondiente
	call	DTA_SEG

	xor	a	;Actualizamos barra e info de la memoria
	call	ACTBAR
	ld	a,(DSKTYPE)
	cp	#F9
	jri	ACT2R
ACT4R:	xor	a
	call	ACTBAR
ACT2R:	call	ACTMSTR
	ld	de,MEMSTR
	call	PRINT

	ld	a,(SEGRACT)
	inc	a
	ld	(SEGRACT),a
	pop	bc
	djnz	BUCRDSEC

	ld	a,1
	ld	(RDORWR),a

	; Escritura

ESCRIBE:	ld	a,1
	ld	(RDORWR),a

	ld	a,(UNI_ORI+1)
	ld	b,a
	ld	a,(UNI_DES+1)
	cp	b
	jrni	NOINSD

PETIND:	ld	a,(UNI_DES)	;Pedimos disco de destino si ambas unidades
	ld	hl,$+7	;son la misma
	push	hl
	call	NEWINS
NOINSD:	;

	ld	a,(NUMALLS)
	ld	b,a	;B = segmentos que quedan libres 
BUCWRSEC:	ld	hl,NECESEG
	ld	a,(SEGWACT)	;A = primer segmento a utilizar (0 1a vez)
	cp	(hl)
	jpi	FINAL	;Si ya hemos escrito todo el disco
	inc	a
	cp	(hl)
	jrni	NOWRLAST
	dec	a
	ld	l,a
	ld	a,(DSKTYPE)	;Si tenemos que escribir el ultimo bloque
	cp	#F8	;y el disco es de simple cara, saltamos a 
	ld	a,l
	jpi	ESCLAST8	;una rutina especial (escritura 16 sectores)
	inc	a
NOWRLAST:	dec	a

BUCMEN2:	ld	c,a	;Si el segmento a usar es mayor que
	ld	a,(NUMALLS)	;NUMALLS es que estamos en otra vuelta. 
	cp	c	;Entonces le restamos NUMALLS las veces 
	jrmy	OKSEG2	;necesarias.
	sub	c
	neg
	jr	BUCMEN2
OKSEG2:	ld	a,c

	push	bc,af
	ld	hl,(SECWACT)
	push	hl
	pop	de
	ld	bc,32
	add	hl,bc
	ld	(SECWACT),hl

	ld	a,1	;Imprimimos y actualizamos "Writing..."
	call	ACTRDWR

	pop	af	;Copiamos el segmento correspondiente
	call	SEG_DTA

	ld	a,(UNI_DES+1)	;Escribimos sectores
	dec	a
	ld	l,a
	ld	h,32
	ld	c,WRABS
	call	5

	ld	a,1	;Actualizamos barra e info de la memoria
	call	ACTBAR
	ld	a,(DSKTYPE)
	cp	#F9
	jri	ACT2R2
ACT4R2:	ld	a,1
	call	ACTBAR
ACT2R2:	call	ACTMSTR
	ld	de,MEMSTR
	call	PRINT

	ld	a,(SEGWACT)
	inc	a
	ld	(SEGWACT),a

	pop	bc
	dec	b
	jp	nz,BUCWRSEC

	ld	hl,NUMALLS
	ld	a,(NECESEG)
	cp	(hl)
	jpi	FINAL	;Terminamos si esta todo el disco copiado

	xor	a
	ld	(RDORWR),a

	ld	a,(UNI_DES+1)
	ld	b,a
	ld	a,(UNI_ORI+1)
	cp	b
	jrni	NOINSO

PETINO:	ld	a,(UNI_ORI)	;Pedimos disco de origen si ambas unidades 
	ld	hl,$+7	;son la misma
	push	hl
	call	NEWINS
NOINSO:	; 

	jp	LECTURA

	; Lectura del ultimo bloque de un disco de simple cara 
	; (segmento 23, sectores 704-719) 

LELAST8:	ld	hl,ULSECSTR
	ld	de,RDSEC1
	ld	bc,11
	ldir
	ld	de,RDSTR
	call	PRINT

	ld	a,(UNI_ORI+1)	;Leemos sectores 
	dec	a
	ld	l,a
	ld	h,16
	ld	de,704
	ld	c,RDABS
	call	5

	ld	a,(NUMALLS)	;Copiamos DTA al ultimo segmento
	dec	a
	call	DTA_SEG

	ld	a,45	;Actualizamos barra e info de la memoria
	ld	(SEGLEC),a
	xor	a
	call	ACTBAR
	call	ACTMSTR
	ld	de,MEMSTR
	call	PRINT

	jp	ESCRIBE

	; Escritura del ultimo bloque de un disco de simple cara
	; (segmento 23, sectores 704-719)  

ESCLAST8:	ld	hl,ULSECSTR
	ld	de,WRSEC1
	ld	bc,11
	ldir
	ld	de,WRSTR
	call	PRINT

	ld	a,(NUMALLS)	;Copiamos el ultimo segmento al DTA
	dec	a
	call	SEG_DTA

	ld	a,(UNI_DES+1)	;Escribimos sectores
	dec	a
	ld	l,a
	ld	h,16
	ld	de,704
	ld	c,WRABS
	call	5

	ld	a,45	;Actualizamos barra e info de la memoria
	ld	(SEGESC),a
	ld	a,1
	call	ACTBAR
	call	ACTMSTR
	ld	de,MEMSTR
	call	PRINT

	; Finalizacion (ver ABRUT)

FINAL:	ld	b,0
	jp	FIN

;*** SUBRUTINAS

;Extraccion de un parametro de la linea de comando
;Entrada:  A = Parametro a extraer (el primero es el 1)
;         DE = Buffer para dejar el parametro
;Salida:   A = Numero de parametros
;         CY = 1 => No existe ese parametro, B indefinido
;          B = Longitud del parametro (no incluye el 0)
;          Parametro a partir de DE, acabado en 0
;
;          Modifica AF, B

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

; Extrae un parametro de unidad de disco, del tipo X: o x:
; Si no hay parametros extrae ayuda y termina sin error
; Si no hay dos parametros termina con "Too many parameters" o "Missing param."
; Si el parametro no es correcto termina con "Invalid parameter"
; Entrada: A = Parametro a extraer (1 o 2)
;          IX = buffer
; Salida: unidad (letra mayuscula) en IX
;         unidad (1=A:, etc) en IX+1

EXTUNI:	push	ix
	pop	de
	call	EXTPAR

	or	a
	jr	nz,HAYPAR
NOHAYP:	ld	de,HELP	;Si no hay parametros, mostramos ayuda
	call	PRINT	;y terminamos 
	ld	b,0
	jp	FIN

HAYPAR:	ld	c,b
	ld	b,INP
	cp	2	;Si hay mas de dos parametros terminamos
	jpmy	FIN	;con error "Too many parameters"
	ld	b,NOPAR
	cp	1	;Si solo hay uno, "Missing parameter"
	jpi	FIN

	ld	a,c
	ld	b,IPARM
	cp	2	;Si el parametro tiene mas de dos caracteres 
	jpni	FIN	;terminamos con error "Invalid parameter" 

	ld	a,(ix+1)
	cp	":"	;Idem si el segundo caracter no es ":" 
	jpni	FIN

	ld	a,(ix)
	cp	"A"	;Idem si el parametro no esta 
	jpmn	FIN	;en A-Z o en a-z 
	cp	"H"
	jpmni	ESMAY
	cp	"a"
	jpmn	FIN
	cp	"h"
	jpmy	FIN

ESMIN:	sub	"a"-1
	ld	(ix+1),a	;Pone la unidad (letra mayuscula)
	add	"A"-1	;en ORISTR, y el numero (1=A:, etc) 
	ld	(ix),a	;en ORINUM (ORISTR+1)
	ret

ESMAY:	sub	"A"-1
	ld	(ix+1),a
	ret

;--- Preparacion del VDP para lectura o escritura de VRAM
;    Entrada: A = %0S00000P
;                 P = bit 17 de la direccion VRAM
;                 S = 0 para lectura de VRAM, 1 para escritura
;             HL= direccion VRAM, 16 bits bajos
;             Modifica AF y HL

SET_VDP:	di
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

SET_RD:	ld	a,0
	jr	nc,PAG1R
PAG0R:	ld	a,1
PAG1R:	jp	SET_VDP

;--- Preparacion del VDP para escritura en VRAM
;    Entrada: HL = direccion VRAM, 16 bits bajos
;             CY = direccion VRAM, bit 17
;             Modifica AF y HL

SET_WR:	ld	a,64
	jr	nc,PAG1W
PAG0W:	ld	a,65
PAG1W:	jp	SET_VDP

;--- Lectura de un dato de VRAM con especificacion de direccion
;    Entrada: CY-HL = direccion VRAM
;    Salida:  A  = dato
;             Modifica AF y HL

VPEEK:	di
	call	SET_RD
	in	a,(#98)
	ei
	ret

;--- Escritura de un dato en VRAM con especificacion de direccion
;    Entrada: CY-HL = direccion VRAM
;             A  = dato
;             Modifica HL

VPOKE:	di
	push	af
	call	SET_WR
	pop	af
	out	(#98),a
	ei
	ret

;--- Copia de un bloque de datos de VRAM a RAM
;    Entrada: direccion VRAM establecida con SET_RD
;             DE = destino RAM
;             BC = longitud
;    Salida:  bloque de datos a partir de (DE)
;             DE = direccion siguiente al final del bloque
;             Modifica AF

LDIRVR:	push	hl,de,bc
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

LDIRRV:	push	de,bc,hl
	di
	ld	d,b
	ld	e,c
	ld	c,#98
BUCLDRV:	outi
	dec	de
	ld	a,d
	or	e
	jr	nz,BUCLDRV
	pop	hl,bc,de
	ei
	ret

; Impresion de una cadena
; Entrada: DE = Puntero a la cadena, que ha de estar en formato
;          DW Longitud
;          DB "Cadena"
; No modifica ningun registro principal

PRINT:	ex	af,af
	push	hl,de,bc
	ld	c,WRITE
	ld	b,1
	ex	de,hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ex	de,hl
	call	5
	ex	af,af
	pop	bc,de,hl
	ret

; Peticion de insertacion de un disco (se puede llamar con CALL INSDISK)
; Entrada: A = unidad en formato ASCII mayuscula
; No modifica los registros principales

JNEWINS:	jp	NEWINS	;Nuevo salto del DOS a "Insert disk..."

NEWINS:	ld	(SAVHL),hl
	pop	hl
	push	af,bc,de

	ld	de,BOLIN
	call	PRINT
	ld	de,IN1_STR
	call	PRINT	;Imprimimos "Insert "

	ld	a,(RDORWR)
	or	a
	jr	z,INSORI

INSDES:	ld	de,DE_STR	;Imprimimos "SOURCE" o "DESTINATION"
	ld	a,(UNI_DES)	;y actualizamos UNI_INS con la unidad
	jr	PRSOD	;de origen o la de destino
INSORI:	ld	de,SO_STR
	ld	a,(UNI_ORI)
PRSOD:	ld	(UNI_INS),a
	call	PRINT

	ld	de,IN2_STR	;Imprimimos " disk in drive X:"
	call	PRINT

	call	KEY
	ld	de,BOLIN
	call	PRINT

	pop	de,bc,af
	ret
SAVHL:	ds	2

; Actualizacion de la cadena de informacion de memoria libre
; No modifica ningun registro

ACTMSTR:	push	af,bc,de,hl
	ld	de,(FREERAM)
	ld	hl,FR_INFO
	ld	b,4
MULTI:	sla	e	;Multiplicamos por 16
	rl	d
	djnz	MULTI
	ld	b,5
	ld	c," "
	ld	a,%11000
	call	NUMTOASC

	ld	de,(FREEVR)
	ld	hl,FV_INFO
	ld	b,4
MULTI2:	sla	e	;Multiplicamos por 16
	rl	d
	djnz	MULTI2
	ld	b,3
	ld	c," "
	call	NUMTOASC

	pop	hl,de,bc,af
	ret

; Actualizacion y muestra de la barra
; Entrada: A = 0 -> Lectura
;          A = 1 -> Escritura
; Modifica AF y reg. alt.

ACTBAR:	exx

	add	201
	ld	e,a
	ld	hl,SEGLEC-201	;No actualizamos la barra si el no. de
	ld	c,a	;segmentos usados es multiplo de 8
	ld	b,0	;(tenemos 80 posiciones para 90 segmentos)
	add	hl,bc
	ld	a,(hl)
	inc	a
	ld	(hl),a
	cp	1
	ld	b,2
	jri	MENOS1
	cp	42
	jrmyi	MENOS1
	and	7
	jr	nz,SIACT
MENOS1:	dec	b

SIACT:	push	bc
	ld	a,e
	ld	hl,POSLEC-201
	ld	c,a
	ld	b,0
	add	hl,bc
	ld	a,(hl)
	inc	a
	ld	(hl),a
	ld	hl,BARRA+6
	ld	c,a
	ld	b,0
	add	hl,bc
	ld	a,e
	ld	(hl),e	;Ponemos un caracter 201 o 202 en la barra
	pop	bc
	djnz	SIACT

	ld	de,BARRA
	call	PRINT

NOACT:	exx
	ret

SEGLEC:	db	-1
SEGESC:	db	-1
POSLEC:	db	-1
POSESC:	db	-1

; Actualizacion del mensaje "Reading sectors" o "Writing sectors"
; Entrada: A = 0 -> Lectura
;          A = 1 -> Escritura
; Modifica AF

ACTRDWR:	exx
	push	ix,iy

	ld	ix,NUMRD
	ld	hl,RDSEC1
	ld	iy,RDSTR
	or	a
	jr	z,ESLEC
ESESC:	ld	ix,NUMWR
	ld	hl,WRSEC1
	ld	iy,WRSTR
ESLEC:	;

	ld	e,(ix)	;Actualizamos la cadena
	ld	d,(ix+1)	;y la variable de num. de sectores
	ld	b,4	;leidos o escritos
	ld	c," "
	ld	a,%11000
	call	NUMTOASC
	ld	bc,7
	add	hl,bc
	ex	de,hl
	ld	bc,32
	add	hl,bc
	ex	de,hl
	ld	(ix),e
	ld	(ix+1),d
	dec	de
	ld	b,4
	ld	c," "
	call	NUMTOASC

	push	iy	;Imprimimos la cadena actualizada
	pop	de
	call	PRINT

	pop	iy,ix
	exx
	ret

NUMRD:	dw	0
NUMWR:	dw	0

; Copia de la pagina 2 (#8000-#BFFF) a un segmento
; Tambien decrementa FREERAM o FREEVR
; Entrada: A = segmento reservado (DD: 0-44, SD: 0-23)
; Modifica AF y el slot y segmento de la pagina 1

DTA_SEG:	push	bc,de,hl,ix

	ld	ix,SEGTBL
	ld	c,a
	sla	c
	ld	b,0
	add	ix,bc
	ld	a,(ix)
	cp	#FF
	jri	DTA_VR	;slot #FF -> VRAM

	ld	h,#40	;Conectamos slot
	call	ENASLT
	ld	a,(ix+1)
	call	PUT_P1	;Conectamos segmento
	ld	hl,#8000
	ld	de,#4000
	ld	bc,#4000
	ldir		;Copiamos y actualizamos FREERAM
	ld	hl,(FREERAM)
	dec	hl
	ld	(FREERAM),hl
	jp	DTA_END

DTA_VR:	ld	h,(ix+1)
	ld	b,6
SETPGV:	sla	h	;Componemos direccion VRAM
	djnz	SETPGV
	ld	l,0
	call	SET_WR
	ld	hl,#8000
	ld	bc,#4000
	call	LDIRRV	;Copiamos y actualizamos FREEVR
	ld	a,(FREEVR)
	dec	a
	ld	(FREEVR),a

DTA_END:	pop	ix,hl,de,bc
	ret

; Copia de un segmento a la pagina 2 (#8000-#BFFF)
; Tambien incrementa FREERAM o FREEVR
; Entrada: A = segmento reservado (DD: 0-44, SD: 0-23)
; Modifica AF y el slot y segmento de la pagina 1

SEG_DTA:	push	bc,de,hl,ix

	ld	ix,SEGTBL
	ld	c,a
	sla	c
	ld	b,0
	add	ix,bc
	ld	a,(ix)
	cp	#FF
	jri	VR_DTA	;slot #FF -> VRAM

	ld	h,#40	;Conectamos slot 
	call	ENASLT
	ld	a,(ix+1)
	call	PUT_P1	;Conectamos segmento 
	ld	hl,#4000
	ld	de,#8000
	ld	bc,#4000
	ldir		;Copiamos y actualizamos FREERAM
	ld	hl,(FREERAM)
	inc	hl
	ld	(FREERAM),hl
	jp	SEG_END

VR_DTA:	ld	h,(ix+1)
	ld	b,6
SETPGV2:	sla	h	;Componemos direccion VRAM
	djnz	SETPGV2
	ld	l,0
	call	SET_RD
	ld	de,#8000
	ld	bc,#4000
	call	LDIRVR	;Copiamos y actualizamos FREEVR
	ld	a,(FREEVR)
	inc	a
	ld	(FREEVR),a

SEG_END:	pop	ix,hl,de,bc
	ret

; Rutina de error de disco, llamada automaticamente por el DOS
; Entrada: A = error
;          B = unidad fisica
;          C = b0 - 0: lectura, 1: escritura
;              b1 - 1: ignorar no recomendado
;              b2 - 1: cancelar no recomendado
;              b3 - 1: numero de sector valido
;          DE= numero de sector
; Se ha de volver con
;          A = 0: llamar rutina de error del sistema
;          A = 1: cancelar
;          A = 2: reintentar
;          A = 3: ignorar

ERRUT:	push	bc,af

	bit	3,c
	jr	z,SECNOV

SECVAL:	ld	hl,ERR_SEC	;Convertimos sector del error a ASCII
	ld	b,4
	ld	c," "
	ld	a,%11000
	call	NUMTOASC
	ld	a,1
	ld	(IMPSEC),a
	jr	MOREERR

SECNOV:	xor	a
	ld	(IMPSEC),a

MOREERR:	pop	bc	;Obtenemos la cadena del error y
	ld	c,EXPLAIN	;rellenamos con espacios a partir del final
	ld	de,ERR_EXP	;de la misma (caracter 0)
	call	5
	ld	hl,ERR_EXP
	ld	b,70
BUCEXP:	ld	a,(hl)
	or	a
	inc	hl
	jr	z,OKCERO
	djnz	BUCEXP
OKCERO:	dec	hl
BUCEXP2:	ld	a," "
	ld	(hl),a
	inc	hl
	djnz	BUCEXP2

	pop	bc	;Imprimimos "Error writing/reading",
	bit	0,c	;el error, el numero de sector,
	ld	de,ERR_R	;y la peticion R/I/C
	jr	z,ERAR
ERAW:	ld	de,ERR_W
ERAR:	call	PRINT
	ld	a,(IMPSEC)
	or	a
	jr	z,NOISEC
	ld	de,ERR_2
	call	PRINT
NOISEC:	ld	de,ERR_3
	call	PRINT

ASK:	call	KEY	;Preguntamos si reintentar, ignorar
	cp	"r"	;o cancelar
	jri	RETRY
	cp	"R"
	jri	RETRY
	cp	"i"
	jri	IGNORE
	cp	"I"
	jri	IGNORE
	cp	"c"
	jri	CANCEL
	cp	"C"
	jri	CANCEL
	jr	ASK

CANCEL:	ld	a,1
	ret

RETRY:	ld	a,2
	push	af
	jr	REOIG
IGNORE:	ld	a,3
	push	af

REOIG:	ld	de,BOLIN
	call	PRINT
	ld	a,(RDORWR)
	or	a
	ld	de,RDSTR
	jr	z,RD34
WR34:	ld	de,WRSTR
RD34:	call	PRINT

	pop	af
	ret

IMPSEC:	ds	1

; Rutina de terminacion
; Llamada automaticamente por el DOS cuando se llama a la funcion #62
; o cuando se selecciona Cancelar con un error de disco.
; A contiene el error.
; Al volver con RET finaliza el programa.

ABRUT:	or	a
	jr	z,TERNOE

TERSIE:	ld	de,BOLIN
	call	PRINT
	ld	de,COPYCAN
	call	PRINT
	jr	TERM34

TERNOE:	ld	de,COPYCOM
	call	PRINT

TERM34:	call	KEY
	ld	de,JEJEJE	;Despedida chorra
	call	PRINT
	call	KEY
	ld	de,JEJEJE2
	call	PRINT

	ld	hl,OLDINS	;Restauramos salto a "Insert disk..." 
	ld	de,INSDISK
	ld	bc,3
	ldir

	ld	a,(DSKTYPE)
	or	a
	jr	z,NOREST

	ld	a,(RAMSLOT-2)	;Restauramos slot y segmento pagina 1
	ld	h,#40
	call	ENASLT
	ld	a,(INIPG1)
	call	PUT_P1

NOREST:	ld	hl,4096+200*8	;Restauramos caracteres 200 a 202
	or	a
	call	SET_WR
	ld	hl,OLDCHR
	ld	bc,8*3
	call	LDIRRV

	xor	a
	ld	b,0
	ret

; Esperamiento de que se pulse una tecla
; Devuelve en A la tecla pulsada

KEY:	exx

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

; Finalizacion con error (cuando aun no se ha definido ABRUT)
; Entrada: B = error (0: sin error)

FIN:	ld	c,TERM
	jp	5

;*** DATOS Y TABLAS DE SALTO

	; Tabla de salto para las rutinas del mapeador

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

	; Datos y variables

UNI_ORI:	ds	3
UNI_DES:	ds	3
INIPG1:	db	0
DSKTYPE:	ds	1
RDORWR:	ds	1
SECRACT:	dw	0
SECWACT:	dw	0
SEGRACT:	db	0
SEGWACT:	db	0
MAPTAB:	dw	0
FREERAM:	ds	2
FREEVR:	ds	2
NECESEG:	ds	1
OLDINS:	ds	3
OLDCHR:	ds	8*3
NEWCHR:	db	0,0,0,255,0,0,0,0	;Nuevo caracter 200: linea
	db	85,170,85,170,85,170,85,170	;Nuevo 201: sombra
	ds	8,255	;Nuevo caracter 202: bloque


NOD2STR:	ENTER	1
	db	"Chapuza Copy #2.0 - by Konami Man, 5-96"
	ENTER	2
	db	"DOS 2 needed!! Hasta la vista, baby!"
	ENTER	2
	db	"$"

INISTR:	dw	INISTR!-$-2
	CLS
	db	"Chapuza Copy #2.0 - by Konami Man, 5-96"
	ENTER	1
INISTR!:	;

DRV_INFO:	dw	DRV_INF!-$-2
	POS	0,2
	db	"Source drive is "
ORI_INFO:	db	" :"
	ENTER	1
	db	"Destination drive is "
DES_INFO:	db	" :"
DRV_INF!:	;

MEMSTR:	dw	MEMSTR!-$-2
	POS	60,2
	db	"Free RAM: "
FR_INFO:	db	"      K"
	POS	60,3
	db	"Free VRAM:  "
FV_INFO:	db	"    K"
MEMSTR!:	;

PRESIN1:	dw	PRESIN1!-$-2
	POS	0,9
	db	"Set SOURCE disk and press any key ..."
	ERAEND
PRESIN1!:	;

PRESIN2:	dw	PRESIN2!-$-2
	POS	0,9
	db	"Set SOURCE and DESTINATION disks and press any key ..."
	ERAEND
PRESIN2!:	;

IN1_STR:	dw	IN1_STR!-$-2
	POS	0,9
	db	"Insert "
IN1_STR!:	;

SO_STR:	txt	"SOURCE "
DE_STR:	txt	"DESTINATION "

IN2_STR:	dw	IN2_STR!-$-2
	db	"disk in drive "
UNI_INS:	db	" : and press any key ..."
	ERAEND
	ENTER	1
IN2_STR!:	;

PRE_STR:	dw	PRE_STR!-$-2
	db	"Press any key when ready ..."
	ERAEND
PRE_STR!:	;

BARRA:	dw	BARRA!-$-2
	POS	0,7
	ds	80,200
	db	" "
BARRA!:	;

HELP:	dw	HELP!-$-2
	db	"A simple sector copier for single and double sided"
	db	" floppies."
	ENTER	2
	db	"Usage: CHCOPY2 <source drive> <destination drive>"
	ENTER	2
	db	"- Source and destination drive can be the same."
	ENTER	1
	db	"- Destination disk must be a formatted disk."
	ENTER	1
	db	"- All free RAM will be used, "
	db	"and also VRAM if necessary."
	ENTER	1
HELP!:	;

JEJEJE:	dw	JE!-$-2
	CLS
	db	"An exception occured - system halted"
	ENTER	1
	db	"Press any key to reboot"
	ENTER	2
JE!:	;

JEJEJE2:	dw	JE2!-$-2
	db	"Just kidding!! No Bill Gates here. 8-)"
	ENTER	1
JE2!:	;

DISK9:	dw	DISK9!-$-2
	POS	0,5
	db	"Disk type: double sided, 1440 sectors, 720 K"
DISK9!:	;

DISK8:	dw	DISK8!-$-2
	POS	0,5
	db	"Disk type: single sided, 720 sectors, 360 K"
DISK8!:	;

BOLIN:	dw	BOLIN!-$-2
	POS	0,9
	ERALIN
	ENTER	1
	ERALIN
	ENTER	1
	ERALIN
	POS	0,9
BOLIN!:	;

RDSTR:	dw	RDSTR!-$-2
	POS	0,9
	db	"Reading SOURCE disk, sectors "
RDSEC1:	db	"   0 -"
RDSEC2:	db	"    0 ..."
	ERAEND
RDSTR!:	;

WRSTR:	dw	WRSTR!-$-2
	POS	0,9
	db	"Writing DESTINATION disk, sectors "
WRSEC1:	db	"     -"
WRSEC2:	db	"      ..."
	ERAEND
WRSTR!:	;

ULSECSTR:	db	" 704 -  719"

BUFFER:	ds	32
NUMALLS:	db	1
SEGTBL:	ds	90	;Tabla de segmentos

COPYCAN:	dw	COPYCA!-$-2
	POS	0,9
	db	"Copy cancelled. Press any key ..."
	ERAEND
	ENTER	1
	ERALIN
	ENTER	1
	ERALIN
COPYCA!:	;

COPYCOM:	dw	COPYCO!-$-2
	POS	0,9
	db	"Copy complete! Press any key ..."
	ERAEND
	ENTER	1
	ERALIN
	ENTER	1
	ERALIN
COPYCO!:	;

ERR_R:	dw	ERR_R!-$-2
	POS	0,9
	db	"Error reading SOURCE disk"
	ERAEND
ERR_R!:	;

ERR_W:	dw	ERR_W!-$-2
	POS	0,9
	db	"Error writing DESTINATION disk"
	ERAEND
ERR_W!:	;

ERR_2:	dw	ERR_2!-$-2
	db	", sector "
ERR_SEC:	db	"    "
ERR_2!:	;

ERR_3:	dw	ERR_3!-$-2
	db	":"
	ENTER	1
	db	"*** "
ERR_EXP:	ds	76," "
	db	"Select: Retry, Ignore error, Cancel copy?"
	ERAEND
ERR_3!:	;
