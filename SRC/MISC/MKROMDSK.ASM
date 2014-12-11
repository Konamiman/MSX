; This tool generates a ROM disk from a DOS 2.20 kernel and the contents of the RAM disk.

;=======================================================================================

	;--- MKDROMDSK: Generador de ROM disk a partir de RAM disk
	;               para cartuchos Flash (solo DOS 2)
	;    v1.2: Corregido el error que impedia que las ROMs
	;          generadas funcionaran en Turbo-R con
	;          mapeador de RAM externo
	;    v1.1: Anyadida seleccion de maper y correccion del
	;          error de lectura del ultimo sector
	;    Por Konami Man, 9/2005
	;
	;    Uso:
	;    MKROMDSK D <fichero DOS2>: Genera el fichero MKROMDSK.DAT
	;                               a partir de la ROM del DOS 2.20
	;    MKROMDSK G [<fichero ROM>] [/R] [/K|/S|/A|/8]:
	;       Genera el ROM disk (por defecto ROMDISK.ROM) a partir
	;       del RAM disk. /R redondea el tamanyo de la ROM
	;       a 128K, 256K, 512K, etc.
	;
	;    /K: Mapper Konami 4 no SCC
	;    /S: Mapper Konami 5 SCC
	;    /A: Mapper ASCII 16K
	;    /8: Mapper ASCII 8K (defecto)


;*****************************
;***  MACROS Y CONSTANTES  ***
;*****************************

;*** Funciones del DOS

_TERM0:	equ	#00
_CONIN:	equ	#01
_STROUT:	equ	#09
_SETDTA:	equ	#1A
_ALLOC:	equ	#1B
_RDABS:	equ	#2F
_WRABS:	equ	#30
_OPEN:	equ	#43
_CREATE:	equ	#44
_CLOSE:	equ	#45
_READ:	equ	#48
_WRITE:	equ	#49
_SEEK:	equ	#4A
_PARSE:	equ	#5B
_TERM:	equ	#62
_DEFAB:	equ	#63
_RAMD:	equ	#68
_GENV:	equ	#6B
_DOSVER:	equ	#6F


;*** Direcciones de buferes

BUFSEC:	equ	#4000-512
BUFPAR:	equ	BUFSEC-128
BUFNAME:	equ	BUFPAR-128
BUFDISK:	equ	#8000


;*** Macro para imprimir una cadena

print:	macro	@s
	ld	de,@s
	ld	c,_STROUT
	call	5
	endm


;******************
;***  PROGRAMA  ***
;******************

	org	#100

	;------------------------
	;---  Inicializacion  ---
	;------------------------

	;--- Muestra presentacion y comprueba DOS 2,
	;    si no lo hay, muestra error y termina

	print	PRESEN_S

	ld	c,_DOSVER
	call	5
	ld	a,b
	cp	2
	jr	nc,OKDOS2

	print	NODOS2_S
	ld	c,_TERM0
	jp	5
OKDOS2:

	ld	de,TERMERR	;Rutina a llamar si se aborta un error de disco
	ld	c,_DEFAB
	call	5

	;--- Extrae el primer parametro, si no lo hay,
	;    muestra info de uso y termina

	ld	a,1
	ld	de,BUFPAR
	call	EXTPAR
	jr	nc,PAR1OK

	print	INFO_S
	jp	TERMOK
PAR1OK:

	;--- Salta a la parte adecuada segun el parametro,
	;    o muestra error de parametro invalido

	ld	a,(BUFPAR)
	or	#20	;Convierte a minuscula
	cp	"g"
	jp	z,DO_MKROM
	cp	"d"
	jp	nz,INVPAR


	;------------------------------------
	;---  Generacion de MKROMDSK.DAT  ---
	;------------------------------------

DO_MKDAT:

	;--- Extrae el segundo parametro, que es el nombre
	;    de la ROM del DOS 2. Si no existe, muestra error.

	ld	a,2
	ld	de,BUFPAR
	call	EXTPAR
	jp	c,INVPAR

	print	CREADAT_S	;Muestra "Creating DAT file"

	;--- Abre el fichero con la ROM del DOS 2

	ld	de,BUFPAR
	ld	a,1	;Solo lectura
	ld	c,_OPEN
	call	5
	jp	nz,DO_ERROR

	ld	a,b
	ld	(DOS2FH),a

	;--- Comprueba que el fichero del DOS 2 es valido,
	;    para ello comprueba que tiene exactamente 64K
	;    y busca la cadena "2.20" en la posicion #135

	ld	a,(DOS2FH)	;Obtiene tamanyo del fichero
	ld	b,a
	ld	a,2
	ld	de,0
	ld	hl,0
	ld	c,_SEEK
	call	5

	;Aqui debe haber DE=#0001, HL=0; si no, error

	dec	e
	ld	a,d
	or	e
	or	h
	or	l
	jp	nz,DOS2INV

	;Busca "2.20", de paso lee el primer bloque de 16K del fichero

	ld	a,(DOS2FH)	;Devuelve el puntero al ppio del fichero
	ld	b,a
	xor	a
	ld	de,0
	ld	hl,0
	ld	c,_SEEK
	call	5

	ld	a,(DOS2FH)	;Lee las primeras 16K
	ld	b,a
	ld	hl,#4000
	ld	de,BUFDISK
	ld	c,_READ
	call	5
	jp	nz,TERMERR

	ld	hl,(BUFDISK+#135)	;Comprueba "2.20",0 en la posicion #135
	ld	de,".2"
	call	COMP
	jp	nz,DOS2INV
	ld	hl,(BUFDISK+#135+2)
	ld	de,"02"
	call	COMP
	jp	nz,DOS2INV
	ld	a,(BUFDISK+#135+4)
	or	a
	jp	nz,DOS2INV

	;--- Crea el fichero MKROMDSK.DAT en el mismo dir del COM,
	;    para ello usa la variable de entorno PROGRAM

	ld	hl,PROGRAM_S	;Obtiene variable PROGRAM
	ld	de,BUFPAR
	ld	b,128
	ld	c,_GENV
	call	5

	ld	de,BUFPAR	;Obtiene puntero a nombre de fichero
	ld	bc,_PARSE	;en BUFPAR, y lo cambia por MKROMDSK.DAT
	call	5
	ex	de,hl
	ld	hl,ROMDAT_S
	ld	bc,13
	ldir

	ld	de,BUFPAR	;Crea el fichero MKROMDSK.DAT
	xor	a
	ld	bc,_CREATE
	call	5
	jp	nz,DO_ERROR

	ld	a,b
	ld	(DATFH),a


	;>>> Comienzo del parcheo de la ROM del DOS 2

	;(Nota: las primeras 16K ya estan en BUFDISK)

	;--- Copia la nueva rutina de inicio

	ld	hl,INIT
	ld	de,BUFDISK+#00A0
	ld	bc,INIT_END-INIT
	ldir

	;--- Modifica los "puntos clave"

	ld	hl,MAPCODE_END-MAPCODE	;Tamanyo de la zona de trabajo a reservar en pag. 3
	ld	(BUFDISK+#088D),hl

	ld	hl,DRIVES	;Rutina que devuelve el num de unidades a reservar para esta DiskROM
	ld	(BUFDISK+#08B9),hl

	ld	hl,DPB-1	;Direccion del DPB "por defecto" (?)
	ld	(BUFDISK+#08EB),hl

	ld	hl,INIENV	;Rutina que inicializa la zona de trabajo en pag. 3
	ld	(BUFDISK+#08F7),hl

	ld	hl,DSKIO	;Rutina de lectura/escritura de sectores
	ld	(BUFDISK+#0011),hl

	ld	hl,DSKCHG	;Rutina de comprobacion de cambio de disco
	ld	(BUFDISK+#0014),hl

	ld	hl,GETDPB	;Rutina de obtencion del DPB de una unidad
	ld	(BUFDISK+#0017),hl

	ld	hl,CHOICE	;Rutina que devuelve la dir de una cadena con opciones de formateo
	ld	(BUFDISK+#001A),hl

	ld	hl,DSKFMT	;Rutina de formateo
	ld	(BUFDISK+#001D),hl

	ld	hl,#40A0	;Nueva rutina de inicio de la ROM
	ld	(BUFDISK+#0002),hl

	;--- Copia el codigo nuevo

	ld	hl,NEWCODE
	ld	de,BUFDISK+#3300
	ld	bc,NEWCODE_E-NEWCODE_S
	ldir

	;--- Escribe el bloque parcheado en MKROMDSK.DAT

	ld	a,(DATFH)
	ld	b,a
	ld	hl,#4000
	ld	de,BUFDISK
	ld	c,_WRITE
	call	5
	jp	nz,DO_ERROR

	;--- Escribe los otros tres bloques de 16K

	ld	b,3

PATCHL:	push	bc

	ld	a,(DOS2FH)
	ld	b,a
	ld	hl,#4000
	ld	de,BUFDISK
	ld	c,_READ
	call	5
	jp	nz,DO_ERROR

	ld	a,(DATFH)
	ld	b,a
	ld	hl,#4000
	ld	de,BUFDISK
	ld	c,_WRITE
	call	5
	jp	nz,DO_ERROR

	pop	bc
	djnz	PATCHL

	;--- Proceso finalizado, termina

	print	OK_S
	jp	TERMOK


	;-----------------------------------
	;---  Generacion de un ROM disk  ---
	;-----------------------------------

DO_MKROM:

	;--- Abre el fichero MKROMDSK.DAT, si no es posible,
	;    muestra error. Si el error es "file not found",
	;    muestra un mensaje especial.

	ld	hl,PROGRAM_S	;Obtiene variable PROGRAM
	ld	de,BUFPAR
	ld	b,128
	ld	c,_GENV
	call	5

	ld	de,BUFPAR	;Obtiene puntero a nombre de fichero
	ld	bc,_PARSE	;en BUFPAR, y lo cambia por MKROMDSK.DAT
	call	5
	ex	de,hl
	ld	hl,ROMDAT_S
	ld	bc,13
	ldir

	ld	de,BUFPAR	;Intenta abrir fichero
	ld	a,1	;Solo lectura
	ld	c,_OPEN
	call	5
	jr	z,OPENDAT_OK

	cp	#D7	;El error es "File not found"?
	jp	nz,TERMERR	;No: fin con error estandar.
	print	NODAT_S	;Si: muestra aviso de que hay que crear el DAT.
	jp	TERMOK
OPENDAT_OK:

	ld	a,b
	ld	(DATFH),a

	;--- Comprueba si el RAM disk existe y obtiene su tamanyo

	ld	b,#FF
	ld	c,_RAMD
	call	5
	ld	a,b
	or	a
	jr	nz,OKRAMD

	print	NORAMD_S
	jp	TERMOK
OKRAMD:

	ld	(RAMDSIZE),a

	;--- Procesa los parametros a partir del segundo

	;Primero copia a BUFNAME el nombre de fichero por defecto

	ld	hl,ROMDISK_S
	ld	de,BUFNAME
	ld	bc,13
	ldir

	;Va buclando (?!) por todos los parametros desde el segundo

	ld	a,1
	ld	(PARNUM),a

PARLOOP:	ld	a,(PARNUM)
	inc	a
	ld	(PARNUM),a

	ld	de,BUFPAR
	call	EXTPAR
	jp	c,OKPARAMS

	ld	a,(BUFPAR)
	cp	"/"
	jr	z,ISSLASH

	;Es el nombre del fichero: lo copia a BUFNAME

	ld	hl,BUFPAR
	ld	de,BUFNAME
	ld	bc,128
	ldir

	jr	PARLOOP

	;Es un parametro "/"

ISSLASH:	ld	a,(BUFPAR+1)
	or	#20	;Pasa a minuscula

	cp	"r"
	jr	nz,NO_PAR_R
	ld	a,#FF
	ld	(ROUND),a
	jr	PARLOOP
NO_PAR_R:

	cp	"8"
	ld	hl,#6000
	ld	de,#6800
	jr	z,SETMAP8

	cp	"a"
	ld	hl,#6000
	jr	z,SETMAP16

	cp	"k"
	ld	hl,#4000
	ld	de,#6000
	jr	z,SETMAP8

	cp	"s"
	ld	hl,#5000
	ld	de,#7000
	jr	z,SETMAP8

	jp	INVPAR	;Cualquier otro caracter es invalido

	;Adaptacion de las rutinas de mapeo para maper de 8K
	;Entrada: HL=Primera direccion, DE=Segunda

SETMAP8:	ld	(MR8_1+1),hl
	ld	(LD8_1+1),hl
	ld	(LD8_3+1),hl
	ld	(MR8_2+1),de
	ld	(LD8_2+1),de
	ld	(LD8_4+1),de
	jr	PARLOOP

	;Adaptacion de las rutinas de mapeo para maper de 16K
	;Entrada: HL=Direccion

SETMAP16:	ld	(MAPRUT16+1),hl
	ld	(LD16_1+1),hl
	ld	(LD16_2+1),hl

	ld	hl,MAPRUT16
	ld	de,MAPRUT
	ld	bc,MAPRUT16_E-MAPRUT16
	ldir

	ld	hl,LDIRCODE16
	ld	de,LDIRCODE
	ld	bc,LDIRCODE16_E-LDIRCODE16
	ldir

	jp	PARLOOP
OKPARAMS:


	;>>> Aqui, el nombre del fichero ROM esta en BUFNAME

	print	CREAROM_S	;Muestra "Creating ROM"

	;--- Crea el fichero ROM

	ld	de,BUFNAME
	xor	a
	ld	b,0
	ld	c,_CREATE
	call	5
	jp	nz,DO_ERROR

	ld	a,b
	ld	(ROMFH),a

	;--- Parchea el sector 0 del RAM disk para que tenga
	;    codigo de arranque

	ld	de,BUFSEC	;Establece area de transferencia
	ld	c,_SETDTA
	call	5

	ld	de,0	;Lee sector
	ld	hl,#0107
	ld	c,_RDABS
	call	5
	jp	nz,DO_ERROR

	ld	hl,BOOT1	;Modifica sector (hasta #A)
	ld	de,BUFSEC
	ld	bc,BOOT1_E-BOOT1
	ldir

	ld	hl,BOOT2	;Modifica sector (desde #1E)
	ld	de,BUFSEC+#1E
	ld	bc,BOOT2_E-BOOT2
	ldir

	;ld	de,0	;Escribe sector modificado (en v1.1 no hace falta)
	;ld	hl,#0107
	;ld	c,_WRABS
	;call	5
	;jp	nz,DO_ERROR

	;--- Lee las primeras 16K de MKROMDSK.DAT,
	;    y las parchea adecuadamente
	;    (hay que parchear el tamanyo del disco, el DPB y la rutina de mapeo,
	;     asi como copiar el sector 0)

	ld	a,(DATFH)
	ld	b,a
	ld	hl,#4000
	ld	de,BUFDISK
	ld	c,_READ
	call	5
	jp	nz,DO_ERROR

	;Copia sector 0

	ld	hl,BUFSEC
	ld	de,SECTOR0-NEWCODE_S+BUFDISK+#3300
	ld	bc,512
	ldir

	;Copia rutinas de mapeo

	ld	hl,MAPRUT
	ld	de,BUFDISK+#0092
	ld	bc,MAPRUT_E-MAPRUT
	ldir

	ld	hl,LDIRCODE
	ld	de,MAPCODE-NEWCODE_S+BUFDISK+#3300
	ld	bc,LDIRCODE_E-LDIRCODE
	ldir

	;Calcula el tamanyo del RAM disk en sectores:
	;num. paginas (16K * 32) + 1

	ld	hl,(RAMDSIZE)
	ld	h,0
	ld	b,5

CALCSIZE:	add	hl,hl
	djnz	CALCSIZE

	inc	hl
	ld	(BUFDISK+#3300),hl

	;Obtiene DPB del RAM disk

	ld	e,8
	ld	c,_ALLOC
	call	5
	push	ix
	pop	hl
	inc	hl	;OJO: _ALLOC devuelve en IX puntero al DPB MENOS UNO
	ld	de,BUFDISK+#3303
	ld	bc,18
	ldir

	;Escribe las 16K en el fichero ROM

	ld	a,(ROMFH)
	ld	b,a
	ld	hl,#4000
	ld	de,BUFDISK
	ld	c,_WRITE
	call	5
	jp	nz,DO_ERROR

	;--- Copia las otras 3 paginas del fichero DAT en el ROM,
	;    parcheando adecuadamente la rutina de mapeo

	ld	b,3

DAT2ROM:	push	bc

	ld	a,(DATFH)
	ld	b,a
	ld	hl,#4000
	ld	de,BUFDISK
	ld	c,_READ
	call	5
	jp	nz,DO_ERROR

	ld	hl,MAPRUT
	ld	de,BUFDISK+#0092
	ld	bc,MAPRUT_E-MAPRUT
	ldir

	ld	a,(ROMFH)
	ld	b,a
	ld	hl,#4000
	ld	de,BUFDISK
	ld	c,_WRITE
	call	5
	jp	nz,DO_ERROR

	pop	bc
	djnz	DAT2ROM

	;--- Anexa el RAMDisk al fichero ROM

	ld	de,BUFDISK	;Cambia area de transferencia
	ld	c,_SETDTA
	call	5

	ld	a,(RAMDSIZE)
	ld	b,a
	ld	de,1	;Ojo: empezar por el sector 1

RAM2ROM:	push	bc,de

	ld	l,7	;Lee 16K (32 sectores)
	ld	h,32
	ld	c,_RDABS
	call	5
	jp	nz,DO_ERROR

	ld	a,(ROMFH)	;Escribe en el fichero
	ld	b,a
	ld	hl,#4000
	ld	de,BUFDISK
	ld	c,_WRITE
	call	5
	jp	nz,DO_ERROR

	pop	hl,bc	;Siguiente bloque de 32 sectores
	ld	de,32
	add	hl,de
	ex	de,hl
	djnz	RAM2ROM

	;--- Redondea el tamanyo del fichero si es necesario

	ld	a,(ROUND)
	or	a
	jr	z,OKROUND

	;Obtiene el tamanyo del fichero menos uno en DE:HL

	ld	a,(ROMFH)
	ld	b,a
	ld	a,2
	ld	de,-1
	ld	hl,-1
	ld	c,_SEEK
	call	5

	;Calcula el nuevo tamanyo: de 64K a 128K pone 128K, de 128K a 256K pone 256K, etc.
	;Para ello, busca el primer bit 1 de E empezando por el MSB; cuando lo encuentra,
	;pone todos los bits subsiguientes a 1.
	;(El puntero es DE:HL, con D=0 siempre)

	ld	b,8
ROUNDL:	rlc	e
	jr	c,ROUNDL2
	djnz	ROUNDL
	jr	DO_ROUND

ROUNDL2:	ld	e,0
ROUNDL3:	scf
	rl	e
	djnz	ROUNDL3

	;Pone el puntero del fichero en la ultima posicion del mismo
	;y escribe un byte cualquiera, asi el fichero pasa a tener
	;el tamanyo deseado.

DO_ROUND:	ld	d,0

	ld	hl,#FFFF	;Establece puntero  
	ld	a,(ROMFH)
	ld	b,a
	xor	a
	ld	c,_SEEK
	call	5

	ld	a,(ROMFH)	;Escribe un byte en el fichero
	ld	b,a
	ld	hl,1
	ld	de,BUFDISK
	ld	c,_WRITE
	call	5
	jp	nz,DO_ERROR
OKROUND:

	;--- Fin

	print	OK_S
	print	YOUCAN_S
	jp	TERMOK


;********************
;***  SUBRUTINAS  ***
;********************

;--- Comparacion de HL con DE
;    Salida:  C, NZ si HL < DE
;             C,  Z si HL = DE
;            NC, NZ si HL > DE

COMP:	ld	a,h
	cp	d
	ret	nz
	ld	a,l
	cp	e
	ret


;--- Terminacion por fichero de DOS 2 invalido

DOS2INV:	print	ERROR_S
	print	NOVALID_S
	jr	TERMOK


;--- Muestra "ERROR!" y termina con el error pasado en A y B

DO_ERROR:	push	af,bc
	print	ERROR_S
	pop	bc,af
	jr	TERMERR


;--- Muestra "Missing or invalid parameters" y termina

INVPAR:	print	INVPAR_S


;--- Terminacion del programa sin codigo de error

TERMOK:	xor	a
	ld	b,0


;--- Terminacion del programa con error.
;    A y B deben tener los codigos de error.
;    Tambien se salta aqui si se aborta un error de disco.

TERMERR:	push	af,bc

	ld	de,0
	ld	c,_DEFAB	;Anula rutina de tratamiento de salida
	call	5

	;Cierra los ficheros, si no estan abiertos
	;el FH almacenado sera #FF y el DOS no hara nada.

	ld	a,(DOS2FH)
	ld	b,a
	ld	c,_CLOSE
	call	5
	ld	a,(DATFH)
	ld	b,a
	ld	c,_CLOSE
	call	5
	ld	a,(ROMFH)
	ld	b,a
	ld	c,_CLOSE
	call	5

	pop	bc,af
	ld	c,_TERM
	jp	5


;--- Rutinas de mapeo (por defecto ASCII 8K)

MAPRUT:	sla	a
MR8_1:	ld	(#6000),a
	inc	a
MR8_2:	ld	(#6800),a
	ret
MAPRUT_E:

MAPRUT16:	ld	(#6000),a
	ret
	ds	6	;Relleno para igualar tamanyo
MAPRUT16_E:

LDIRCODE:	sla	a
LD8_1:	ld	(#6000),a
	inc	a
LD8_2:	ld	(#6800),a
	ldir
	xor	a
LD8_3:	ld	(#6000),a
	inc	a
LD8_4:	ld	(#6800),a
	ret
LDIRCODE_E:

LDIRCODE16:
LD16_1:	ld	(#6000),a
	ldir
	xor	a
LD16_2:	ld	(#6000),a
	ret
	ds	10	;Relleno para igualar tamanyo
LDIRCODE16_E:


;--- Nueva rutina de inicio para la ROM

	;Primero comprueba si esta ROM ya esta en la tabla
	;de Disk ROMs (si la rutina de inicializacion ya se ha
	;ejecutado antes).
	;Puede ocurrir si la pagina 1 esta replicada en la
	;pagina 2 al arrancar (ocurre en las ROMs mapeadas).

INIT:	call	GETSLT
	ld	c,a	;C=Slot del DOS 2
	ld	b,4
	ld	hl,#FB21
DRLOOP:	ld	a,(hl)
	or	a
	jr	z,INIT2	;No quedan mas entradas?
	inc	hl
	ld	a,(hl)
	cp	c
	ret	z	;Ya estamos en la tabla?
	inc	hl
	djnz	DRLOOP
INIT2:

	;Salta a la rutina de incializacion antigua

	jp	#406A
INIT_END:


;--- NOMBRE: EXTPAR
;      Extraccion de un parametro de la linea de comando
;    ENTRADA:   A  = Parametro a extraer (el primero es el 1)
;               DE = Bufer para dejar el parametro
;    SALIDA:    A  = Numero de parametros
;               CY = 1 -> No existe ese parametro
;                         B indefinido, bufer inalterado
;               CY = 0 -> B = Longitud del parametro (no incluye el 0)
;                         Parametro a partir de DE, acabado en 0
;    REGISTROS: -

EXTPAR:	or	a	;Volvemos con error si A = 0
	scf
	ret	z

	ld	b,a
	ld	a,(#80)	;Volvemos con error si no hay parametros
	or	a
	scf
	ret	z
	ld	a,b

	push	af,hl
	ld	a,(#80)
	ld	c,a	;Ponemos un 0 al final
	ld	b,0
	ld	hl,#81
	add	hl,bc
	ld	(hl),0
	pop	hl,af

	push	hl,de,ix
	ld	ix,0	;IXl: Numero de parametros    
	ld	ixh,a	;IXh: Parametro a extraer    
	ld	hl,#81

PASASPC:	ld	a,(hl)	;Vamos pasando espacios    
	or	a
	jr	z,ENDPNUM
	cp	" "
	inc	hl
	jr	z,PASASPC

	inc	ix
PASAPAR:	ld	a,(hl)	;Vamos pasando el parametro    
	or	a
	jr	z,ENDPNUM
	cp	" "
	inc	hl
	jr	z,PASASPC
	jr	PASAPAR

ENDPNUM:	ld	a,ixh	;Error si se el parametro a extraer    
	dec	a	;(anyadido para quitar el jrmy)
	cp	ixl	;es mayor que el numero de parametros    
	jr	nc,EXTPERR
	;jrmy	EXTPERR	;existentes    

	ld	hl,#81
	ld	b,1	;B = parametro actual    
PASAP2:	ld	a,(hl)	;Pasamos espacios hasta dar    
	cp	" "	;con el siguiente parametro    
	inc	hl
	jr	z,PASAP2

	ld	a,ixh	;Si es el que buscamos lo extraemos.    
	cp	B	;Si no ...    
	jr	z,PUTINDE0

	inc	B
PASAP3:	ld	a,(hl)	;... lo pasamos y volvemos a PAPAP2    
	cp	" "
	inc	hl
	jr	nz,PASAP3
	jr	PASAP2

PUTINDE0:	ld	b,0
	dec	hl
PUTINDE:	inc	b
	ld	a,(hl)
	cp	" "
	jr	z,ENDPUT
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


;*****************************
;***  VARIABLES Y CADENAS  ***
;*****************************

;*** Variables

DOS2FH:	dw	#FF
DATFH:	dw	#FF
ROMFH:	dw	#FF
RAMDSIZE:	db	0	;Tamanyo RAM disk en pags 16K
ROUND:	db	0	;#FF si se especifica /R
PARNUM:	db	0	;Usado al buclar (?!) por los parametros

;*** Cadenas programativas

PROGRAM_S:	db	"PROGRAM",0
ROMDAT_S:	db	"MKROMDSK.DAT",0
ROMDISK_S:	db	"ROMDISK.ROM",0

;*** Cadenas informativas

PRESEN_S:	db	"ROM disk with DOS 2 kernel creator for Flash ROM cartridges 1.2",13,10
	db	"By Konami Man, 9/2005",13,10,13,10,"$"

INFO_S:	db	"Usage:",13,10
	db	13,10
	db	"MKROMDSK D <DOS2 file name>",13,10
	db	"Generate the MKROMDSK.DAT file from a DOS 2.20 kernel ROM image file.",13,10
	db	13,10
	db	"MKROMDSK G [<ROM file name>] [/R] [/8|/A|/K|/S]",13,10
	db	"Generate a ROM disk file ready to burn on a Flash cartridge.",13,10
	db	"The contents of the ROM disk will be obtained from the existing RAM disk.",13,10
	db	"Default ROM file name is ROMDISK.ROM.",13,10
	db	13,10
	db	"/R: Round the file size up to a power of two (128K, 256K, 512K, etc)",13,10
	db	"/8: Use ASCII 8K mapper (default)",13,10
	db	"/A: Use ASCII 16K mapper",13,10
	db	"/K: Use Konami 4 non-SCC mapper",13,10
	db	"/S: Use Konami 5 SCC mapper",13,10
	db	"$"

INVPAR_S:	db	"*** Missing or invalid parameter(s)",13,10,"$"
CREADAT_S:	db	"Creating MKROMDSK.DAT file... $"
CREAROM_S:	db	"Generating ROM-disk image file... $"
OK_S:	db	"OK!",13,10,13,10,"$"
ERROR_S:	db	"ERROR!",13,10,13,10,"$"
NODAT_S:	db	"*** Error: MKROMDSK.DAT file not found.",13,10
	db	13,10
	db	"You must create a MKROMDSK.DAT file from a DOS 2.20 kernel ROM image file",13,10
	db	"prior to using this program (do this with: MKRAMD D <DOS 2 ROM filename>).",13,10,"$"
NOVALID_S:	db	"This file is not a valid MSX-DOS 2.20 kernel ROM image.",13,10,"$"
NODOS2_S:	db	"*** This program needs MSX-DOS 2 to run.",13,10,"$"
NORAMD_S:	db	"*** Error: RAM disk does not exist.",13,10
	db	13,10
	db	"Create a DOS 2 RAM disk and copy to it all the files and directories you want",13,10
	db	"to appear in the ROM disk. Don't forget COMMAND2.COM and MSXDOS2.SYS.",13,10,"$"
YOUCAN_S:	db	"You can now burn the resulting ROM file on a Flash ROM cartridge.",13,10,"$"

;*** Sector 0 con codigo de arranque

BOOT1:	db	#EB,#FE,#90,#52,#4F,#4D,#5F,#44,#49,#53,#4B
BOOT1_E:

BOOT2:	db	#18,#1E
	db	#56,#4F,#4C,#5F,#49,#44,#00,#05,#06,#07,#08,#4E,#45,#53,#54,#4F
	db	#52,#53,#4F,#46,#54,#20,#46,#41,#54,#31,#32,#20,#20,#20,#D0,#ED
	db	#53,#7B,#C0,#11,#78,#C0,#73,#23,#72,#11,#80,#C0,#0E,#0F,#CD,#7D
	db	#F3,#3C,#CA,#22,#40,#11,#00,#01,#0E,#1A,#CD,#7D,#F3,#21,#01,#00
	db	#22,#8E,#C0,#21,#00,#3F,#11,#80,#C0,#0E,#27,#D5,#CD,#7D,#F3,#D1
	db	#0E,#10,#CD,#7D,#F3,#C3,#00,#01,#68,#C0,#CD,#00,#00,#C3,#22,#40
	db	0,"MSXDOS  SYS",0,0,0,0
BOOT2_E:


;*****************************************************
;***  CODIGO NUEVO PARA PARCHEAR LA ROM DEL DOS 2  ***
;*****************************************************

;* Un par de rutinas utiles de la ROM del DOS 2:

GETWRK:	equ	#4DB0	;Devuelve en IX la dir de la zona de trabajo en pag. 3 del slot
GETSLT:	equ	#402D	;Devuelve en A el slot de la ROM

NEWCODE:	org	#7300

NEWCODE_S:

	;*** Parametros a establecer para cada ROM disk

DISKSIZE:	dw	0	;Numero de sectores en el disco

	db	#FF
DPB:	ds	18	;DPB del disco


	;*** Obtencion del numero de unidades a reservar para esta DiskROM
	;    Out: L=Numero de unidades
	;    Debe preservar AF,BC,DE

DRIVES:	ld	l,1
	ret


	;*** Inicializacion de la zona de trabajo:
	;    copia MAPCODE a pagina 3

INIENV:	call	GETWRK
	push	ix
	pop	de
	ld	hl,MAPCODE
	ld	bc,MAPCODE_END-MAPCODE
	ldir
	ret

	;Rutina que establece la pagina A de ROM (16K), hace LDIR, y restablece pag 0;
	;se copiara en la zona de trabajo en pagina 3

MAPCODE:	sla	a
	ld	(#6000),a
	inc	a
	ld	(#6800),a
	ldir
	xor	a
	ld	(#6000),a
	inc	a
	ld	(#6800),a
	ret
MAPCODE_END:


	;*** Lectura de sectores
	;    In:   Cy=0 para leer, 1 para escribir
	;          A=Unidad
	;          B=Numero de sectores
	;          C=Descriptor del medio
	;          DE=Primer sector
	;          HL=Direccion origen/destino para los datos
	;    Out:  Cy=0 si OK, 1 si error
	;          A=codigo de error:
	;               0       Write protected
	;               2       Not ready
	;               4       Data (CRC) error
	;               6       Seek error
	;               8       Record not found
	;               10      Write fault
	;               12      Other errors
	;          B=num de sectores transferidos

DSKIO:	jr	c,DSKIOE0	;Se pide escritura: error
	or	a
	jr	nz,DSKIOE2	;La unidad no es la 0: error

	ld	a,b	;0 sectores a transferir: no hace nada
	or	a
	ret	z

	push	hl	;Comprueba que el numero
	ld	hl,(DISKSIZE)	;de sector sea valido
	call	COMPROM
	pop	hl
	jr	c,DSKIOE6

	push	hl,de,bc
	call	GETWRK	;IX=rutina de copia
	pop	bc,hl,de	;Invierte DE y HL a proposito

	;>>> Aqui HL=primer sector, DE=direccion de destino

	;Si es el sector 0, lo copia directamente, decrementa el numero de sectores,
	;y pone el numero de sector a 1

	ld	a,h
	or	l
	jr	nz,NOSEC0

	push	bc
	ld	hl,SECTOR0
	ld	bc,512
	ldir		;DE queda convenientemente actualizado
	pop	bc

	dec	b	;Decrementa numero de sectores a leer
	jr	nz,NO1SEC
	xor	a
	ld	b,1	;Si solo se pedia un sector, terminar ya
	ret
NO1SEC:	ld	hl,1	;Ahora el primer sector a leer es el 1
NOSEC0:

	;Decrementa el numero de sector, ya que el primero almacenado
	;en ROM es el 1

	dec	hl

	;Calcula la pagina de ROM inicial como: (sector\32)+4

	push	hl

	sra	h
	rr	l
	sra	h
	rr	l
	sra	h
	rr	l
	sra	h
	rr	l
	sra	h
	rr	l

	ld	a,l
	add	4
	ld	c,a	;C=Pagina ROM inicial

	pop	hl

	;Calcula la direccion de origen inicial como: ((sector MOD 32)*512)+#4000

	ld	a,l
	and	%11111
	add	a,a
	add	#40
	ld	h,a
	ld	l,0	;HL=Dir inicial

	push	bc	;B=Numero de sectores, C=Pagina ROM

	;Bucle de copia

DSKIOL:	ld	a,c
	push	bc
	ld	bc,512
	ld	iy,DSKIOK
	push	iy
	jp	(ix)	;Copia un sector de pagina A, dir HL a dir DE

DSKIOK:	pop	bc
	bit	7,h	;Si la dir de origen llega a #8000,
	jr	z,DSKIOK2	;volverla a #4000 e incrementar la pagina ROM
	ld	hl,#4000
	inc	c

DSKIOK2:	djnz	DSKIOL

	;Fin sin error

	pop	bc	;Ha de devolver el numero de sectores copiados en B
	xor	a
	ret

	;Fines con error

DSKIOE0:	xor	a
	jr	DSKIOE

DSKIOE2:	ld	a,2
	jr	DSKIOE2

DSKIOE6:	ld	a,6

DSKIOE:	scf
	ld	b,0
	ret


	;*** Cambio de disco y obtencion del DPB
	;Para DSKCHG:
	;    In:   A=Unidad
	;          B y C=Descriptor del medio
	;          HL=Direccion para dejar el DPB si se devuelve B=0 o 1
	;    Out:  Cy=0 si OK, 1 si error
	;          A=Codigo de error (como DSKIO)
	;          B=1: disco cambiado, -1: no cambiado, 0: estado desconocido
	;Para GETDPB:
	;    In:   A=Unidad
	;          B y C=Descriptor del medio
	;          HL=Direccion para dejar el DPB
	;    Out:  Cy=0 si OK, 1 si error
	;          A=Codigo de error (como DSKIO)

DSKCHG:
GETDPB:	or	a
	ld	a,12
	scf
	ret	nz	;La unidad no es la 0: error

	ex	de,hl
	ld	hl,DPB
	ld	bc,18	;Copia DPB
	inc	de	;CUIDADO !!!
	ldir

	xor	a
	ld	b,-1	;Siempre devuelve "disco no cambiado"
	ret


	;*** Devuelve en HL la direccion de una cadena con las opciones de formateo.
	;    Si solo hay una opcion, devuelve HL=0.
	;    Si no se puede formatear, devuelve un puntero a una cadena vacia.

CHOICE:	ld	hl,ZERO_S
	ret

ZERO_S:	db	0


	;*** Formateo
	;    In:   A=Opcion elegida por el usuario (1-9)
	;          D=Unidad
	;          HL=Direccion inicial area de trabajo
	;          BC=Area de trabajo
	;    Out:  Cy=0 si OK, 1 si error
	;          A=Codigo de error:
	;          0    Write protected
	;          2    Not ready
	;          4    Data (CRC) error
	;          6    Seek error
	;          8    Record not found
	;          10   Write fault
	;          12   Bad parameter
	;          14   Insufficient memory
	;          16   Other errors

DSKFMT:	scf
	ld	a,16
	ret


;--- Comparacion de HL con DE
;    Salida:  C, NZ si HL < DE
;             C,  Z si HL = DE
;            NC, NZ si HL > DE

COMPROM:	ld	a,h
	cp	d
	ret	nz
	ld	a,l
	cp	e
	ret

SECTOR0:	;Aqui se copia el sector 0 del disco

NEWCODE_E:
