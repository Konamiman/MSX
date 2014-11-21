;See DISK-ENG.ASM for an English version of this file.

;================================

	;--- RUTINAS PARA MANEJAR FICHEROS
	;    Compatibles DOS 1 y DOS 2
	;    Por Konami Man, 3-97


;-----===== MACROS Y CONSTANTES =====-----

;--- Parametros definibles por el usuario

;La constante DOS indica la version de sistema operativo soportada:

;DOS=1 -> Funcionamiento en DOS 1 y DOS 2, pero usando metodos de DOS 1 (FCBs).
;         No soporta subdirectorios, atributos ni otras caracteristicas DOS 2.
;         Longitud de las rutinas:  985 + 38 * MAXFILES bytes
;DOS=2 -> Funcionamiento solo en DOS 2.
;         Longitud de las rutinas:  375 bytes
;DOS=12-> Funcionamiento en DOS 1 y DOS 2, usando los metodos propios de cada
;         sistema operativo. Es la opcion mas eficiente.
;         Longitud de las rutinas: 1292 + 38 * MAXFILES bytes

DOS:	equ	12

;La constante MAXFILES indica el numero maximo de ficheros abiertos
;simultaneamente, asi como el tamanyo de la zona de FCBS (38 * MAXFILES).
;La zona de FCBS no es necesaria en DOS 2.

MAXFILES:	equ	0

;La constante DOSENTRY ha de valer #0005 si se van a usar las rutinas desde
;MSX-DOS, y #F37D si se van a usar desde MSX Disk BASIC.

DOSENTRY:	equ	#0005

;PREUBAS=1 hara que se ensamblen las rutinas de prueba.

PREUBAS:	equ	0

;START es la direccion de inicio de las rutinas.
;Si no van a ser ensambladas por separado, poner START=0
;y la directiva ORG sera ignorada.

START:	equ	#100

;--- Funciones del DOS

_FOPEN:	equ	#0F
_FCLOSE:	equ	#10
_SFIRST:	equ	#11
_SNEXT:	equ	#12
_FDEL:	equ	#13
_FMAKE:	equ	#16
_FREN:	equ	#17
_SETDTA:	equ	#1A	; ^
_WRBLK:	equ	#26	; |
_RDBLK:	equ	#27	; +-- DOS 1

_FFIRST:	equ	#40	; +-- DOS 2
_FNEXT:	equ	#41	; |
_OPEN:	equ	#43	; V
_CREATE:	equ	#44
_CLOSE:	equ	#45
_READ:	equ	#48
_WRITE:	equ	#49
_SEEK:	equ	#4A
_DELETE:	equ	#4D
_RENAME:	equ	#4E
_DOSVER:	equ	#6F

;--- Otras constantes

ENYEMAY:	equ	165
ENYEMIN:	equ	164
LONBUF:	equ	70	;Longitud del bufer generico (minimo 69)

;--- Macros

doscall:	macro	@function
	ld	c,@function
	call	DOSENTRY
	endm

;--- Inicio

	if	START<>0
	org	START
	endif

	if	PREUBAS=1
	ld	sp,#D500
	jp	PREUBA9	;Cambiar por la prueba deseada
	endif

;-----===== VARIABLES Y ZONAS DE DATOS =====-----

NUMFILES:	db	0	;Numero de ficheros abiertos 
BUFFER:	ds	LONBUF	;Bufer generico para las rutinas

;ESPACIO PARA FCBs. Cada fichero abierto necesita 37 bytes para el FCB.
;Ademas se usa uno mas para indicar si cada FCB esta en uso.
;Este espacio no es necesario en DOS 2.

	if	DOS<>2

FCBS:	ds	38*MAXFILES

	endif


;-----===== DIRECTORIO DE RUTINAS =====-----

;--- Rutinas auxiliares

;CLBUF:     Limpia el bufer generico
;MIN2MAY:   Convierte un caracter a mayuscula
;CHKDOS2:   Comprueba la version del DOS
;CONVNAME:  Convierte un nombre de fichero de/a formato FCB

;--- Rutinas de usuario

;DIR:       Busca un fichero y muestra informacion sobre el mismo
;REN:       Renombra un fichero
;CREATE:    Crea un fichero
;DEL:       Borra un fichero
;OPEN:      Abre un fichero
;CLOSE:     Cierra un fichero abierto
;READ:      Lee de un fichero abierto
;WRITE:     Escribe en un fichero abierto
;SEEK:      Mueve el puntero de un fichero abierto


;-----===== RUTINAS DE PRUEBA =====-----

	if	PREUBAS=1

PREUBA:	ld	sp,#d500	;Prueba de conversion de nombre
	ld	hl,PBA
	ld	de,#1000
	;scf
	or	a
	;call    CONVNAME
	nop
	nop
;PBA:       db      2,"MAGOMUCHOCG"
PBA:	db	"d:RaMoN.rIbAs",0

PREUBA2:	ld	de,PBA2	;Prueba de busqueda de ficheros
	ld	ix,#1000
	ld	a,0
BUCPBA:	call	DIR
	ld	a,1
	jp	BUCPBA

PBA2:	db	"*.asc",0

PREUBA3:	ld	de,PBA3	;Prueba de renombrado de ficheros
	ld	hl,PBA4
	call	REN
	nop
	nop
	nop

PBA3:	db	"file.uno",0
PBA4:	db	"file!.dos",0

PREUBA4:	ld	de,PBA5	;Prueba de borrado de ficheros
	call	DEL
	nop
	nop

PBA5:	db	"pabor.rar",0

PREUBA5:	ld	de,PBA6
	call	CREATE
	nop
	nop

PBA6:	db	"cread.me!",0

PREUBA6:	ld	de,PBA10	;Prueba de apertura y cerradura
	call	OPEN	;Debe devolver A<>0 (no existe)
	ld	de,PBA7
	call	OPEN	;Debe devolver A=0, B=1
	ld	de,PBA8
	call	OPEN	;Debe devolver A=0, B=2
	ld	de,PBA9
	call	OPEN	;Debe devolver A=0, B=3
	ld	de,PBA8
	call	OPEN	;Debe devolver A=1 (MAXFILES=3)

	ld	b,0
	call	CLOSE	;Debe devolver A=1
	ld	b,4
	call	CLOSE	;Debe devolver A=1
	ld	b,3
	call	CLOSE	;Debe devolver A=0
	ld	b,3
	call	CLOSE	;Debe devolver A=2
	ld	de,PBA8
	call	OPEN	;Debe devolver A=0, B=1
	nop
	nop

PBA7:	db	"file.uno",0
PBA8:	db	"file!.dos",0
PBA9:	db	"file!!.tre",0
PBA10:	db	"noexis.te",0

PREUBA7:	ld	de,PBA7	;Prueba de lectura de un fichero
	call	OPEN
	ld	hl,5
	ld	de,#1000
	call	READ
	ld	hl,9
	ld	de,#1100
	call	READ
	ld	hl,200
	ld	de,#1200
	call	READ

	call	CLOSE
	nop
	nop

PREUBA8:	ld	de,PBA8	;Prueba de escritura en un fichero
	call	OPEN
	ld	hl,10
	ld	de,PBA11
	call	WRITE
	call	CLOSE
	nop
	nop

PBA11:	db	"34 veces!!!!!"

PREUBA9:	ld	de,PBA7
	call	OPEN
	ld	de,0
	ld	hl,10	;Desplazamiento de 10
	ld	a,1
	call	SEEK
	ld	de,#1000
	ld	hl,20
	call	READ
	ld	de,#FFFF
	ld	hl,#FFFB	;Desplazamiento de -5
	ld	a,1
	call	SEEK
	ld	de,#1100
	ld	hl,20
	call	READ
	ld	de,#FFFF
	ld	hl,#FFF0	;Desplazamiento de -16 respecto al final
	ld	a,2
	call	SEEK
	ld	de,#1200
	ld	hl,20
	call	READ
	call	CLOSE
	nop
	nop

	endif


;-----===== RUTINAS AUXILIARES =====-----

;--- NOMBRE: CLBUF
;      Limpia el buffer generico
;    ENTRADA:   -
;    SALIDA:    -
;    REGISTROS: -
;    LLAMADAS:  -
;    VARIABLES: BUFFER, LONBUF

CLBUF:	push	hl,de,bc
	ld	hl,BUFFER
	ld	de,BUFFER+1
	ld	bc,LONBUF-1
	ld	(hl),0
	ldir
	pop	bc,de,hl
	ret


;--- NOMBRE: MIN2MAY
;      Convierte un caracter a mayuscula
;    ENTRADA:   A = Caracter
;    SALIDA:    A = Caracter en mayuscula si era minuscula,
;                   inalterado si no
;    REGISTROS: F
;    LLAMADAS:  -
;    VARIABLES: ENYEMIN, ENYEMAY

MIN2MAY:	cp	ENYEMIN
	jp	nz,NOENYE
	ld	a,ENYEMAY
	ret
NOENYE:	cp	"a"
	ret	c
	cp	"z"+1
	ret	nc
	and	%11011111
	ret


	if	DOS<>1

;--- NOMBRE: CHKDOS2
;      Obtiene la version de MSX-DOS
;    ENTRADA:   -
;    SALIDA:    Cy = 1 -> MSX-DOS 1.x o MSX-DOS 2.1x
;               Cy = 0 -> MSX-DOS 2.20 o superior
;    REGISTROS: F
;    LLAMADAS:  -
;    VARIABLES: -

CHKDOS2:	ld	(ATEMP),a
	ld	a,(DV)	;Si DV=0, aun no se ha comprobado
	cp	2	;la version del DOS.
	jp	z,CD2END2	;Si DV=1 -> DOS 1 o DOS 2.1
	or	a	;Si DV=2 -> DOS 2.20 o superior
	scf
	jp	nz,CD2END2

	push	bc,de,hl	;Comprueba la version del DOS
	doscall	_DOSVER	;y establece DV.
	ld	a,b
	cp	2
	ld	a,1
	jp	c,CD2END
	ld	a,c
	cp	2
	ld	a,1
	jp	c,CD2END
	ld	a,2

CD2END:	ld	(DV),a
	pop	hl,de,bc
	jp	CHKDOS2

CD2END2:	ld	a,(ATEMP)
	ret

DV:	db	0
ATEMP:	db	0

	endif


	if	DOS<>2

;--- NOMBRE: CONVNAME
;      Convierte un nombre de fichero de/a formato FCB
;      NO comprueba caracteres invalidos en el nombre del fichero
;    ENTRADA:    HL = Cadena de origen
;                     Formato FCB:    12 caracteres, sin punto
;                                     (los sobrantes se rellenan con espacios)
;                                     El primero es la unidad
;                                     (0: defecto, 1: A, 2: B, etc)
;                     Formato normal: Acabada en 0, maximo 14 caracteres
;                                     Comienza con la unidad y ":"
;                                     si no es la idem por defecto (la 0)
;                DE = Cadena de destino (idem)
;                Cy = 0 -> Formato normal a FCB
;                Cy = 1 -> Formato FCB a normal
;     SALIDA:    B  = Longitud de la cadena de destino
;                     Formato FCB: siempre 12
;                     Formato normal: no incluye el 0 final
;     REGISTROS: AF, C
;     LLAMADAS:  MIN2MAY
;     VARIABLES: -

CONVNAME:	push	de,hl
	jp	c,FCB2NOR
	xor	a
	ld	(EXTFLG),a
	jp	NOR2FCB
ENDCONV:	pop	hl,de
	ret

;--- Conversion nombre normal a nombre FCB

NOR2FCB:	push	de,hl,de	;Rellena de espacios la zona del nombre
	pop	hl
	inc	de
	ld	a," "
	ld	(hl),a
	ld	bc,11
	ldir
	pop	hl,de
	xor	a
	ld	(de),a	;Pone a 0 la unidad

	inc	hl	;Comprueba si se ha especificado unidad.
	ld	a,(hl)	;Si es asi, la convierte al numero
	cp	":"	;de unidad correspondiente.
	jp	nz,NOUN1
	dec	hl
	ld	a,(hl)
	call	MIN2MAY
	sub	"A"-1
	ld	(de),a
	inc	hl
	inc	hl
	inc	hl

NOUN1:	inc	de
	dec	hl
	xor	a	;Bucle para el nombre
	ld	(EXTFLG),a
	ld	b,8
	call	N2FBUC

	ld	a,(EXTFLG)	;Si se ha llegado al final, no procesa
	or	a	;la extension
	jp	nz,ENDCONV
	ld	a,#FF
	ld	(EXTFLG),a
	ld	b,3	;Bucle para la extension
	call	N2FBUC
	ld	b,12
	jp	ENDCONV
;                                   ;Pasa sin convertir los 8 o 3 primeros
N2FBUC:	ld	a,(hl)	;caracteres, a no ser que encuentre
	inc	hl
	cp	"*"	;un 0 (fin de cadena),
	jp	z,AFND1	;un punto (fin de nombre),
	cp	"."	;o un asterisco (que convierte en "?")
	jp	z,PFND1
	or	a
	jp	z,EFND1
	call	MIN2MAY
	ld	(de),a
	inc	de
	djnz	N2FBUC

PASASOB:	ld	a,(EXTFLG)	;Si es la extension no hay nada que pasar
	or	a
	ret	nz

	ld	a,(hl)	;Pasa caracteres sobrantes (mas alla de 8
	inc	hl	;o 3) en el nombre del fichero
	or	a
	jp	z,EFND1
	cp	"."
	jp	nz,PASASOB
	ret

AFND1:	ld	a,"?"	;Rellena de "?" hasta completar
AFND11:	ld	(DE),a	;8 o 3 caracteres
	inc	DE
	djnz	AFND11
	jp	PASASOB

PFND1:	ld	a,(EXTFLG)
	or	a
	jp	nz,EFND1
	ld	a,b
	cp	8	;Si el punto esta al principio,
	dec	hl
	jp	z,AFND1	;interpreta "*.<ext>"
	inc	hl
	ld	a," "	;Rellena de " " hasta completar
PFND11:	ld	(DE),a	;8 o 3 caracteres
	inc	de
	djnz	PFND11
	ret

EFND1:	ld	a,1
	ld	(EXTFLG),a
	ret

EXTFLG:	db	0	;#FF cuando se procesa la extension, 
;                                   ;1 cuando se ha llegado al final

;--- Conversion nombre FCB a nombre normal

FCB2NOR:	push	de
	ld	a,(hl)
	or	a
	jp	z,NOUN2
	add	"A"-1
	ld	(de),a
	inc	de
	ld	a,":"
	ld	(de),a
	inc	de

NOUN2:	inc	hl
	ld	b,8	;Vamos copiando el nombre tal cual
F2NBUC:	ld	a,(hl)	;hasta que pasamos ocho caracteres
	inc	hl	;o encontramos un espacio...
	cp	" "
	jp	z,SPFND
	ld	(de),a
	inc	de
	djnz	F2NBUC
	ld	a,"."
	ld	(de),a
	inc	de
	jp	F2NEXT

SPFND:	ld	a,"."	;...entonces ponemos el punto,
	ld	(de),a	;y pasamos los espacios sobrantes
	inc	de	;hasta llegar a la extension.
SFBUC:	ld	a,(hl)
	inc	hl
	djnz	SFBUC
	dec	hl

F2NEXT:	ld	b,3	;Copiamos la extension hasta haber
F2NEX2:	ld	a,(hl)	;copiado tres caracteres,
	inc	hl	;o hasta encontrar un espacio.
	cp	" "
	jp	z,F2NEND
	ld	(de),a
	inc	de
	djnz	F2NEX2

F2NEND:	dec	de	;Si no hay extension, suprimimos el punto.
	ld	a,(de)
	cp	"."
	jp	z,NOPUN
	inc	de
NOPUN:	xor	a
	ld	(de),a

	ex	de,hl	;Obtencion de la longitud de la cadena.
	pop	de
	or	a
	sbc	hl,de
	ld	b,l
	jp	ENDCONV

	endif


;-----===== RUTINAS DE USUARIO =====-----

;--- NOMBRE: DIR
;      Busca un fichero
;      Siempre se debe ejecutar primero con A=0
;      Para buscar los siguientes, el bufer generico no debe ser modificado
;    ENTRADA:    DE = Nombre del fichero (puede contener comodines), con fin 0
;                IX = Puntero a una zona vacia de 26 bytes
;                B  = Atributos de busqueda (ignorado si DOS 1)
;                A  = 0 -> Buscar primero
;                A  = 1 -> Buscar siguientes
;    SALIDA:     A  = 0 -> Fichero encontrado
;                A <> 0 -> Fichero no encontrado
;                IX+0          -> #FF (fanzine propio del DOS 2)
;                IX+1  a IX+13 -> Nombre del fichero
;                IX+14         -> Byte de atributos
;                IX+15 y IX+16 -> Hora de modificacion
;                IX+17 y IX+18 -> Fecha de modificacion
;                IX+19 y IX+20 -> Cluster inicial
;                IX+21 a IX+24 -> Longitud del fichero
;                IX+25         -> Unidad logica
;     REGISTROS: F
;     LLAMADAS:  CONVNAME, CHKDOS2
;     VARIABLES: BUFFER, DOSENTRY, doscall, _SETDTA, _SFIND, _SNEXT,
;                _FFIND, _FNEXT

OFBUF1:	equ	38

DIR:	if	DOS=12

	call	CHKDOS2
	jp	nc,DIR2

	endif

	;--- DIR: Version DOS 1

	if	DOS<>2

DIR1:	push	bc,de,hl,iy,ix,af
	call	CLBUF
	ex	de,hl
	ld	de,BUFFER	;Pasamos el nombre normal de (DE)
	or	a	;a nombre FCB en BUFFER.
	call	CONVNAME

	ld	de,BUFFER+OFBUF1	;Ponemos el area de transferencia
	doscall	_SETDTA	;en el buffer, tras el FCB del fichero
;                                   ;a buscar.
	ld	de,BUFFER
	pop	af
	and	1
	ld	c,_SFIRST
	add	c
	ld	c,a
	call	DOSENTRY
	or	a	;Terminamos con A=#FF si no se encuentra.
	jp	nz,ENDFF1

	ld	a,(BUFFER+OFBUF1)	;Guardamos la unidad del FCB
	ld	(ULO1),a	;en ULO1, y la ponemos a 0
	xor	a	;para poder convertirla a nombre normal
	ld	(BUFFER+OFBUF1),a	;sin unidad.
	ld	iy,BUFFER+OFBUF1

	push	iy
	pop	hl	;HL = Entrada de directorio del fichero
	pop	de	;(comenzando con la unidad a 0 y el nombre).
	push	de	;DE = IX de la entrada (buffer del usuario).
	ld	a,#FF
	ld	(de),a	;Primer byte a #FF para igualarlo al DOS 2.
	inc	de
	scf		;Copiamos nombre en formato normal
	call	CONVNAME	;al buffer del usuario.

	pop	ix	;IX = buffer de usuario.
	ld	a,(iy+12)	;Copiamos byte de atributos.
	ld	(ix+14),a

	push	iy
	pop	hl
	ld	bc,23	;HL = Entrada de directorio apuntando a
	add	hl,bc	;la hora de creacion.

	push	ix
	pop	de
	ld	bc,15	;DE = Buffer del usuario apuntando a
	ex	de,hl	;la posicion +15.
	add	hl,bc
	ex	de,hl

	ld	bc,10	;Copiamos fecha,hora,cluster inicial
	ldir		;y longitud a la vez.

	ld	a,(ULO1)	;Copiamos unidad logica.
	ld	(ix+25),a

	xor	a	;Terminamos sin error.
	push	ix
ENDFF1:	pop	ix,iy,hl,de,bc
	ret

ULO1:	db	0

	endif

	;--- DIR: Version DOS 2

	if	DOS<>1

DIR2:	push	hl,bc,de,ix
	ld	ix,BUFFER
	ld	c,_FFIRST
	and	1
	add	c
	ld	c,a
	call	DOSENTRY
	or	a
	jp	nz,ENDFF2
	push	ix
	pop	hl
	pop	de
	push	de
	ld	bc,26
	ldir
	xor	a
ENDFF2:	pop	ix,de,bc,hl
	ret

	endif


;--- NOMBRE: REN
;      Renombra un fichero
;    ENTRADA:   DE = Nombre del fichero
;               HL = Nuevo nombre del fichero (puede contener comodines)
;    SALIDA:    A  = 0 -> Fichero renombrado
;               A <> 0 -> Error
;    REGISTROS: F
;    LLAMADAS:  CHKDOS2, CONVNAME
;    VARIABLES: BUFFER, _FREN, _RENAME, DOSENTRY, doscall

REN:	if	DOS=12

	call	CHKDOS2
	jp	nc,REN2

	endif

	;--- REN: Version DOS 1 

	if	DOS<>2

REN1:	push	bc,de,hl,ix,iy
	call	CLBUF

	push	hl
	ex	de,hl	;HL = Nombre antiguo 
	ld	de,BUFFER
	or	a
	call	CONVNAME

	pop	hl	;HL = Nombre nuevo 
	ld	de,BUFFER+16
	or	a
	call	CONVNAME
	ld	de,BUFFER

	doscall	_FREN
	pop	iy,ix,hl,de,bc
	ret

	endif


;--- NOMBRE: CREATE
;      Crea un fichero pero NO lo deja abierto
;      !CUIDADU! Si ya existe ese fichero, lo borra y crea uno nuevo
;    ENTRADA:   DE = Nombre del fichero
;    SALIDA:    A  = 0 -> Fichero creado
;               A <> 0 -> Error
;    REGISTROS: F
;    LLAMADAS:  CONVNAME, CHKDOS2
;    VARIABLES: doscall, _FMAKE, _FCLOSE, _CREATE, _CLOSE, BUFFER

CREATE:	if	DOS=12

	call	CHKDOS2
	jp	nc,CREA2

	endif

	;--- CREATE: Version DOS 1

	if	DOS<>2

CREA1:	push	bc,de,hl,ix,iy
	call	CLBUF
	ex	de,hl	;HL = Nombre del fichero 
	ld	de,BUFFER
	or	a
	call	CONVNAME
	ex	de,hl
	ld	de,BUFFER
	push	de
	doscall	_FMAKE	;Crea el fichero y lo cierra
	pop	de
	or	a
	jp	nz,CR1END
	doscall	_FCLOSE
	xor	a
CR1END:	pop	iy,ix,hl,de,bc
	ret

	endif

	;--- CREATE: Version DOS 2

	if	DOS<>1

CREA2:	push	bc,de,hl
	xor	a
	ld	b,0	;Si el fichero ya existe, lo borra.
	doscall	_CREATE	;Crea el fichero y lo cierra
	or	a	;si no hay error.
	jp	nz,CR2END
	doscall	_CLOSE
	xor	a
CR2END:	pop	hl,de,bc
	ret

	endif

	;--- REN: Version DOS 2

	if	DOS<>1

REN2:	push	hl,de,bc
	doscall	_RENAME
	pop	bc,de,hl
	ret

	endif


;--- NOMBRE: DEL
;      Borra un fichero
;      EL FICHERO NO DEBE ESTAR ABIERTO
;    ENTRADA:   DE = Nombre del fichero
;    SALIDA:    A  = 0 -> Fichero borrado
;               A <> 0 -> Error
;    REGISTROS: F
;    LLAMADAS:  CONVNAME, CHKDOS2
;    VARIABLES: doscall, _FDEL, _DELETE, BUFFER

DEL:	if	DOS=12

	call	CHKDOS2
	jp	nc,DEL2

	endif

	;--- DEL: Version DOS 1

	if	DOS<>2

DEL1:	push	bc,de,hl,ix,iy
	call	CLBUF
	ex	de,hl	;HL = Nombre del fichero
	ld	de,BUFFER
	or	a
	call	CONVNAME
	ex	de,hl
	ld	de,BUFFER
	doscall	_FDEL
	pop	iy,ix,hl,de,bc
	ret

	endif

	;--- DEL: Version DOS 2

	if	DOS<>1

DEL2:	push	bc,de,hl
	doscall	_DELETE
	pop	hl,de,bc
	ret

	endif


;--- NOMBRE: OPEN
;      Abre un fichero
;    ENTRADA:   DE = Fichero a abrir
;    SALIDA:    A  = 0 -> Error
;               A <> 0 -> Error
;                         DOS 1: A=1 -> demasiados ficheros abiertos
;               B  = Numero asociado al fichero
;                    (no tiene nada que ver con el numero de ficheros abiertos)
;    REGISTROS: F, C
;    LLAMADAS:  CHKDOS2, CONVNAME
;    VARIABLES: DOS, doscall, NUMFILES, MAXFILES, _FOPEN, _OPEN, FCBS

OPEN:	if	DOS=12

	call	CHKDOS2
	jp	nc,OPEN2

	endif

	;--- OPEN: Version DOS 1

	if	DOS<>2

OPEN1:	ld	a,(NUMFILES)
	cp	MAXFILES
	ld	a,1
	ret	nc

	push	hl,de,ix,iy
	ld	b,MAXFILES
	ld	hl,FCBS
	push	de
	ld	de,38
OP1BUC1:	ld	a,(hl)	;Buscamos, en todos los FCBs,
	or	a	;alguno que este libre.
	jp	z,FCBFND
	add	hl,de
	djnz	OP1BUC1
	ld	a,1
	jp	OP1END

FCBFND:	push	hl	;Limpiamos FCB
	pop	de
	push	de
	inc	de
	ld	bc,37
	ld	(hl),0
	ldir

	pop	de
	inc	de
	pop	hl	;Pasamos el nombre del fichero al FCB
	or	a
	call	CONVNAME

	push	de
	doscall	_FOPEN
	pop	ix
	or	a	;Terminamos si hay error
	jp	nz,OP1END

	ld	a,1
	ld	(ix+14),a	;Ponemos a 1 "record size"
	xor	a
	ld	(ix+15),a
	ld	(ix+33),a	;Ponemos a 0 "random record"
	ld	(ix+34),a
	ld	(ix+35),a
	ld	(ix+36),a

	ld	a,#FF	;Marcamos el FCB como usado
	ld	(ix-1),a

	ld	a,(NUMFILES)	;Incrementamos el numero
	inc	a	;de ficheros abiertos y
	ld	(NUMFILES),a	;devolvemos en A el numero de este
	ld	b,a
	xor	a

OP1END:	pop	iy,ix,de,hl
	ret

	endif

	;--- OPEN: Version DOS 2

	if	DOS<>1

OPEN2:	push	hl,de
	xor	a
	doscall	_OPEN
	or	a
	jp	nz,OP2END
	ld	a,(NUMFILES)
	inc	a
	ld	(NUMFILES),a
	xor	a
OP2END:	pop	de,hl
	ret

	endif


;--- NOMBRE: CLOSE
;      Cierra un fichero
;    ENTRADA:   B  = Numero de fichero
;    SALIDA:    A  = 0 -> Fichero cerrado
;               A <> 0 -> Error
;    REGISTROS: F
;    LLAMADAS:  CHKDOS2
;    VARIABLES: BUFFER, FCBS, doscall, DOS, MAXFILES, NUMFILES, _FCLOSE, _CLOSE

CLOSE:	if	DOS=12

	call	CHKDOS2
	jp	nc,CLOSE2

	endif

	;--- CLOSE: Version DOS 1

	if	DOS<>2

CLOSE1:	ld	a,b	;Error si B>MAXFILES
	cp	MAXFILES+1	;o B=0.
	ld	a,2
	ret	nc
	ld	a,b
	or	a
	ld	a,2
	ret	z

	push	bc,de,hl,ix,iy
	ld	hl,FCBS
	ld	de,38
	or	a
	sbc	hl,de
CL1BUC1:	add	hl,de	;HL = Zona en FCBS del fichero B
	djnz	CL1BUC1

	ld	a,(hl)	;Error si el fichero no esta abierto
	or	a
	ld	a,2
	jp	z,ENDCL1

	inc	hl
	ex	de,hl	;DE = FCB del fichero
	push	de
	doscall	_FCLOSE
	pop	ix
	or	a
	jp	nz,ENDCL1

	ld	a,(NUMFILES)
	dec	a
	ld	(NUMFILES),a
	xor	a	;Marcamos el FCB como libre
	ld	(ix-1),a

ENDCL1:	pop	iy,ix,hl,de,bc
	ret

	endif

	;--- CLOSE: Version DOS 2

	if	DOS<>1

CLOSE2:	push	bc,de,hl
	doscall	_CLOSE
	or	a
	jp	nz,ENDCL2
	ld	a,(NUMFILES)
	dec	a
	ld	(NUMFILES),a
	xor	a
ENDCL2:	pop	hl,de,bc
	ret

	endif


;--- NOMBRE: READ
;      Lee de un fichero abierto
;    ENTRADA:   B  = Numero de fichero
;               DE = Direccion del bufer
;               HL = Numero de bytes a leer
;    SALIDA:    A  = 0 -> No hay error
;               A <> 0 -> Error
;                         Se considera error no haber podido leer
;                         todos los bytes requeridos, es decir,
;                         HL a la entrada <> HL a la salida.
;                         Este error tiene el codigo A=1
;                         tanto en DOS 1 como en DOS 2.
;               HL = Numero de bytes leidos
;    REGISTROS: F
;    LLAMADAS:  CHKDOS2, RW1, RW2
;    VARIABLES: BUFFER, FCBS, DOESNTRY, DOS, MAXFILES, NUMFILES, _RDBLK,
;               _READ, _SETDTA, RWCODE

READ:	if	DOS=12

	call	CHKDOS2
	jp	nc,READ2

	endif

	;--- READ: Version DOS 1 

	if	DOS<>2

READ1:	ld	a,_RDBLK
	ld	(RWCODE),a
	jp	RW1

	endif

	;--- READ: Version DOS 2 

	if	DOS<>1

READ2:	ld	a,_READ
	ld	(RWCODE),a
	jp	RW2

	endif


;--- NOMBRE: WRITE
;      Escribe en un fichero abierto
;    ENTRADA:   B  = Numero de fichero
;               DE = Direccion del bufer
;               HL = Numero de bytes a escribir
;    SALIDA:    A  = 0 -> No hay error
;               A <> 0 -> Error
;                         Se considera error no haber podido escribir
;                         todos los bytes requeridos, es decir,
;                         HL a la entrada <> HL a la salida.
;                         Este error tiene el codigo A=1
;                         tanto en DOS 1 como en DOS 2.
;               HL = Numero de bytes escritos
;    REGISTROS: F
;    LLAMADAS:  CHKDOS2, RW1, RW2
;    VARIABLES: BUFFER, FCBS, DOSENTRY, DOS, MAXFILES, NUMFILES, _WRBLK,
;               _WRITE, _SETDTA, RWCODE

WRITE:	if	DOS=12

	call	CHKDOS2
	jp	nc,WRITE2

	endif

	;--- WRITE: Version DOS 1

	if	DOS<>2

WRITE1:	ld	a,_WRBLK
	ld	(RWCODE),a
	jp	RW1

	endif

	;--- WRITE: Version DOS 2

	if	DOS<>1

WRITE2:	ld	a,_WRITE
	ld	(RWCODE),a
	jp	RW2

	endif


;--- RW: Rutina generica de lectura/escritura

	;--- RW: Version DOS 1

	if	DOS<>2

RW1:	ld	a,b
	cp	MAXFILES+1
	ld	a,1
	ret	nc
	ld	a,b
	or	a
	ld	a,2
	ret	z

	push	bc,de,ix,iy
	push	hl,de
	ld	hl,FCBS
	ld	de,38
	or	a
	sbc	hl,de
RW1BUC1:	add	hl,de	;HL = Zona en FCBS del fichero B
	djnz	RW1BUC1
	ld	a,(hl)	;A = Identificador de fichero abierto
	ex	(sp),hl
	push	hl

	or	a	;Error si el fichero no esta abierto
	ld	a,2
	jp	z,ENDRW11

	pop	de
	doscall	_SETDTA
	pop	de,hl
	inc	de
	ld	a,(RWCODE)	;Leemos el codigo de lectura o escritura
	ld	c,a
	call	DOSENTRY	;y ejecutamos la llamada

ENDRW1:	pop	iy,ix,de,bc
	ret
ENDRW11:	pop	bc,bc,bc
	jp	ENDRW1

	endif

	;--- RW: Version DOS 2

	if	DOS<>1

RW2:	push	bc,de,hl
	ld	a,(RWCODE)	;Leemos el codigo de lectura o escritura
	ld	c,a
	call	DOSENTRY
	pop	de
	or	a
	jp	nz,ENDRW2
	push	hl

	sbc	hl,de	;HL = bytes leidos, DE = bytes requeridos
	ld	a,h	;Si HL=DE, no hay error
	or	l	;Si HL<>DE, error 1
	ld	a,0
	pop	hl
	jp	z,ENDRW2
	ld	a,1

ENDRW2:	pop	de,bc
	ret

	endif

RWCODE:	db	0	;Codigo de la funcion de lectura/escritura


;--- NOMBRE: SEEK
;      Mueve el puntero de un fichero
;      La primera posicion es la 0
;    ENTRADA:   B  = Numero de fichero
;               A  = Metodo de desplazamiento:
;                    A = 0 -> Relativo al principio del fichero
;                    A = 1 -> Relativo a la posicion actual
;                    A = 2 -> Relativo al final del fichero
;               DE:HL  = Desplazamiento en complemento a dos
;    SALIDA:    A  = 0 -> No hay error
;               A <> 0 -> Error
;               DE:HL  = Nuevo puntero
;    * Para obtener la posicion del puntero sin modificarla,
;      ejecutar con A = 1 y DE:HL=0.
;    * Para obtener la longitud del fichero,
;      ejecutar con A = 2 y DE:HL=0.
;    REGISTROS:  F
;    LLAMADAS:   CHKDOS2
;    VARIABLES:  MAXFILES, NUMFILES, doscall, _SEEK, BUFFER

SEEK:	if	DOS=12

	ld	(BUFFER),a
	call	CHKDOS2
	ld	a,(BUFFER)
	jp	nc,SEEK2

	endif

	;--- SEEK: Version DOS 1

	if	DOS<>2

SEEK1:	ld	(BUFFER),a
	ld	a,b	;Error si B>MAXFILES
	cp	MAXFILES+1	;o B=0. 
	ld	a,2
	ret	nc
	ld	a,b
	or	a
	ld	a,2
	ret	z

	push	bc,ix,iy
	push	de,hl
	ld	hl,FCBS
	ld	de,38
	or	a
	sbc	hl,de
SK1BUC1:	add	hl,de	;HL = Zona en FCBS del fichero B
	djnz	SK1BUC1

	ld	a,(hl)	;Error si el fichero no esta abierto 
	or	a
	ld	a,2
	jp	z,ENDSK11

	push	hl
	pop	ix
	inc	ix	;IX = FCB del fichero

	ld	a,(BUFFER)
	or	a	;Obtenemos metodo, y acabamos con error
	jp	z,METODO0	;si es >2
	cp	1
	jp	z,METODO1
	cp	2
	jp	z,METODO2
	ld	a,3
	jp	ENDSK11

METODO0:	ld	de,0
	ld	hl,0
	jp	OKMETOD	;DE:HL = 0

METODO1:	ld	l,(ix+33)
	ld	h,(ix+34)
	ld	e,(ix+35)
	ld	d,(ix+36)	;DE:HL = Puntero actual
	jp	OKMETOD

METODO2:	ld	l,(ix+16)
	ld	h,(ix+17)
	ld	e,(ix+18)
	ld	d,(ix+19)	;DE:HL = Longitud del fichero

OKMETOD:	pop	bc
	add	hl,bc
	pop	bc
	ex	de,hl
	adc	hl,bc	;DE:HL = Nuevo puntero
	ex	de,hl
	xor	a

	ld	(ix+33),l	;Actualizamos puntero
	ld	(ix+34),h
	ld	(ix+35),e
	ld	(ix+36),d

ENDSK1:	pop	iy,ix,bc
	ret
ENDSK11:	pop	bc,bc
	jp	ENDSK1

	endif

	;--- SEEK: Version DOS 2

	if	DOS<>1

SEEK2:	push	bc
	doscall	_SEEK
	pop	bc
	ret

	endif
