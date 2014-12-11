; This tool generates a ROM disk from a DOS 1 kernel and the contents of the RAM disk.

;====================================================================================

	;--- MKROMD1: Generador de ROM disk a partir de RAM disk,
	;             version que genera una DiskROM DOS 1
	;             (pero el programa sigue requiriendo DOS 2)
	;    Por Konami Man, 1/2005
	;
	;    Uso:
	;    MKROMD1 G [<fichero ROM>] [/R] [/K|/S|/A|/8]:
	;       Genera el ROM disk (por defecto ROMDISK.ROM) a partir
	;       del RAM disk. /R redondea el tamanyo de la ROM
	;       a 128K, 256K, 512K, etc.
	;
	;    /K: Mapper Konami 4 no SCC
	;    /S: Mapper Konami 5 SCC
	;    /A: Mapper ASCII 16K
	;    /8: Mapper ASCII 8K (defecto)

;4010: JP DSKIO
;4013: JP DSKCHG
;4016: JP GETDPB
;4019: JP CHOICE
;401C: JP DSKFMT
;401F: JP MTOFF
;576F: CALL INIHRD
;5850: CALL DRIVES
;5883: LD HL,DEFDPB-1
;588F: CALL INIENV
;65AE: JP OEMSTAT

;57A9: LD HL,F380+MySize
;581D: LD HL,MySize
;582E: LD DE,SECLEN

;7405: Inicio zona libre


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

BUFSEC:	equ	#C000-512
BUFPAR:	equ	BUFSEC-128
BUFNAME:	equ	BUFPAR-128
BUFDISK:	equ	#8000
DISKROMEND:	equ	#7405	;Inicio de laa zona libre del DOS 1
BUFNEWCODE:	equ	DISKROMEND+#4000

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
	jp	nz,INVPAR


	;-----------------------------------
	;---  Generacion de un ROM disk  ---
	;-----------------------------------

DO_MKROM:

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
	jr	c,OKPARAMS

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

	;Adaptacion de la rutina de mapeo para maper de 8K
	;Entrada: HL=Primera direccion, DE=Segunda

SETMAP8:	ld	(LD8_1+1),hl
	ld	(LD8_3+1),hl
	ld	(LD8_2+1),de
	ld	(LD8_4+1),de
	jr	PARLOOP

	;Adaptacion de la rutina de mapeo para maper de 16K
	;Entrada: HL=Direccion

SETMAP16:	ld	(LD16_1+1),hl
	ld	(LD16_2+1),hl

	ld	hl,LDIRCODE16
	ld	de,LDIRCODE
	ld	bc,LDIRCODE16_E-LDIRCODE16
	ldir

	jr	PARLOOP
OKPARAMS:
	;Copia rutina de mapeo a la posicion adecuada

	ld	hl,LDIRCODE
	ld	de,MAPCODE	;-NEWCODE_S+BUFNEWCODE
	ld	bc,LDIRCODE_E-LDIRCODE
	ldir


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

	ld	de,0	;Escribe sector modificado
	ld	hl,#0107
	ld	c,_WRABS
	call	5
	jp	nz,DO_ERROR

	;--- Adapta el codigo de la DiskROM

	;Primero copia el codigo del DOS 1 a la pagina 2,
	;y a continuacion el codigo nuevo en la zona libre

	ld	hl,CODE_END
	ld	de,BUFDISK
	ld	bc,DISKROMEND-#4000
	ldir

	ld	hl,NEWCODE_S
	ld	de,BUFNEWCODE
	ld	bc,NEWCODE_E-NEWCODE_S
	ldir

	;Copia rutina de mapeo a la posicion adecuada

	ld	hl,LDIRCODE
	ld	de,MAPCODE-NEWCODE_S+BUFNEWCODE
	ld	bc,LDIRCODE_E-LDIRCODE
	ldir

	;Modifica los "puntos clave" de la ROM

	ld	hl,MAPCODE_END-MAPCODE	;Tamanyo de la zona de trabajo a reservar en pag. 3
	ld	(BUFDISK+#181D+1),hl
	ld	bc,#F380
	add	hl,bc
	ld	(BUFDISK+#17A9+1),hl

	ld	hl,DRIVES-NEWCODE_S+DISKROMEND	;Rutina que devuelve el num de unidades a reservar para esta DiskROM
	ld	(BUFDISK+#1850+1),hl

	ld	hl,RAMDDPB-1-NEWCODE_S+DISKROMEND	;Direccion del DPB "por defecto" (?)
	ld	(BUFDISK+#1883+1),hl

	ld	hl,INIENV-NEWCODE_S+DISKROMEND	;Rutina que inicializa la zona de trabajo en pag. 3
	ld	(BUFDISK+#188F+1),hl
	;xor     a
	;ld      (BUFDISK+#188F+0),a
	;ld      (BUFDISK+#188F+1),a
	;ld      (BUFDISK+#188F+2),a

	ld	hl,_DSKIO-NEWCODE_S+DISKROMEND	;Rutina de lectura/escritura de sectores
	ld	(BUFDISK+#0011),hl

	ld	hl,_DSKCHG-NEWCODE_S+DISKROMEND	;Rutina de comprobacion de cambio de disco
	ld	(BUFDISK+#0014),hl

	ld	hl,_GETDPB-NEWCODE_S+DISKROMEND	;Rutina de obtencion del DPB de una unidad
	ld	(BUFDISK+#0017),hl

	ld	hl,_CHOICE-NEWCODE_S+DISKROMEND	;Rutina que devuelve la dir de una cadena con opciones de formateo
	ld	(BUFDISK+#001A),hl

	ld	hl,_DSKFMT-NEWCODE_S+DISKROMEND	;Rutina de formateo
	ld	(BUFDISK+#001D),hl

	xor	a
	ld	(BUFDISK+#001F),a	;MTOFF
	ld	a,#C9
	ld	(BUFDISK+#0020),a
	ld	(BUFDISK+#0021),a

	ld	a,#37	;Codigo de SCF
	ld	(BUFDISK+#25AE),a	;OEMSTAT
	ld	a,#C9	;Codigo de RET
	ld	(BUFDISK+#25AF),a
	xor	a	;Codigo de NOP
	ld	(BUFDISK+#25B0),a


	;Pisa los primeros bytes del codigo de arrranque con una rutina que mapea
	;adecuadamente la ROM y despues salta a INIT

	ld	de,#576F+#4000	;Direccion del codigo de arranque
	ld	a,#AF	;Codigo de XOR A
	ld	(de),a
	inc	de
	ld	hl,MAPCODE-NEWCODE_S+BUFNEWCODE
	ld	bc,9
	ldir
	xor	a	;Codigo de NOP (necesario para cuadrar instrucciones)
	ld	(de),a
	inc	de
	xor	a	;Codigo de NOP (necesario para cuadrar instrucciones)
	ld	(de),a
	inc	de
	ld	a,#C3	;Codigo de JP
	ld	(de),a
	inc	de
	ld	hl,INIT-NEWCODE_S+DISKROMEND
	ld	a,l
	ld	(de),a
	inc	de
	ld	a,h
	ld	(de),a

	;Copia sector 0 a la posicion adecuada

	ld	hl,BUFSEC
	ld	de,SECTOR0-NEWCODE_S+BUFNEWCODE
	ld	bc,512
	ldir

	;Calcula el tamanyo del RAM disk en sectores:
	;num. paginas (16K * 32) + 1

	ld	hl,(RAMDSIZE)
	ld	h,0
	ld	b,5

CALCSIZE:	add	hl,hl
	djnz	CALCSIZE

	inc	hl
	ld	(DISKSIZE-NEWCODE_S+BUFNEWCODE),hl

	;Obtiene DPB del RAM disk

	ld	e,8
	ld	c,_ALLOC
	call	5
	push	ix
	pop	hl
	inc	hl	;OJO: _ALLOC devuelve en IX puntero al DPB MENOS UNO
	ld	de,RAMDDPB-NEWCODE_S+BUFNEWCODE
	ld	bc,18
	ldir

	;Escribe las 16K del kernel+codigo propio en el fichero ROM

	ld	a,(ROMFH)
	ld	b,a
	ld	hl,#4000
	ld	de,BUFDISK
	ld	c,_WRITE
	call	5
	jp	nz,DO_ERROR

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

	ld	a,(ROMFH)
	ld	b,a
	ld	c,_CLOSE
	call	5

	pop	bc,af
	ld	c,_TERM
	jp	5


;--- Rutinas de mapeo (por defecto ASCII 8K)

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
	ds	6
	ldir
	xor	a
LD16_2:	ld	(#6000),a
	ds	4
	ret
LDIRCODE16_E:


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

ROMFH:	dw	#FF
RAMDSIZE:	db	0	;Tamanyo RAM disk en pags 16K
ROUND:	db	0	;#FF si se especifica /R
PARNUM:	db	0	;Usado al buclar (?!) por los parametros


;*** Cadenas programativas

PROGRAM_S:	db	"PROGRAM",0
ROMDISK_S:	db	"ROMDISK.ROM",0


;*** Cadenas informativas

PRESEN_S:	db	"ROM disk with DOS 1 kernel creator for Flash ROM cartridges 1.0",13,10
	db	"By Konami Man, 9/2005",13,10,13,10,"$"

INFO_S:	db	"Usage:",13,10
	db	13,10
	db	"MKROMD1 G [<ROM file name>] [/R] [/8|/A|/K|/S|/2]",13,10
	db	"Generates a ROM disk file ready to burn on a Flash cartridge.",13,10
	db	"The contents of the ROM disk will be obtained from the existing RAM disk.",13,10
	db	"Default ROM file name is ROMDISK.ROM.",13,10
	db	13,10
	db	"/R: Round the file size up to a power of two (128K, 256K, 512K, etc)",13,10
	db	"/8: Use ASCII 8K mapper (default)",13,10
	db	"/A: Use ASCII 16K mapper",13,10
	db	"/K: Use Konami 4 non-SCC mapper",13,10
	db	"/S: Use Konami 5 SCC mapper",13,10
	db	13,10
	db	"The resulting ROM disk will have a DOS 2 boot sector.",13,10
	db	"Any DOS 2 kernel present will take control. To boot with DOS 1 kernel",13,10
	db	"in Turbo-R, press the 1 key while booting.",13,10
	db	"$"

INVPAR_S:	db	"*** Missing or invalid parameter(s)",13,10,"$"
CREAROM_S:	db	"Generating ROM-disk image file... $"
OK_S:	db	"OK!",13,10,13,10,"$"
ERROR_S:	db	"ERROR!",13,10,13,10,"$"
NODOS2_S:	db	"*** This program needs MSX-DOS 2 to run.",13,10,"$"
NORAMD_S:	db	"*** Error: RAM disk does not exist.",13,10
	db	13,10
	db	"Create a DOS 2 RAM disk and copy to it all the files you want",13,10
	db	"to appear in the ROM disk. Don't forget COMMAND.COM and MSXDOS.SYS.",13,10,"$"
YOUCAN_S:	db	"You can now burn the resulting ROM file on a Flash ROM cartridge.",13,10,"$"


;*** Sector 0 con codigo de arranque

	;* Primera parte, desde el offset 0

BOOT1:	db	#EB,#FE,#90,#52,#4F,#4D,#5F,#44,#49,#53,#4B
BOOT1_E:

	;* Segunda parte, desde el offset #1E, version DOS 2

BOOT2:	db	#18,#1E
	db	#56,#4F,#4C,#5F,#49,#44,#00,#05,#06,#07,#08,#4E,#45,#53,#54,#4F
	db	#52,#53,#4F,#46,#54,#20,#46,#41,#54,#31,#32,#20,#20,#20,#d0,#ED	;Cambiar d0 por c9 para no arrancar
	db	#53,#7B,#C0,#11,#78,#C0,#73,#23,#72,#11,#80,#C0,#0E,#0F,#CD,#7D
	db	#F3,#3C,#CA,#22,#40,#11,#00,#01,#0E,#1A,#CD,#7D,#F3,#21,#01,#00
	db	#22,#8E,#C0,#21,#00,#3F,#11,#80,#C0,#0E,#27,#D5,#CD,#7D,#F3,#D1
	db	#0E,#10,#CD,#7D,#F3,#C3,#00,#01,#68,#C0,#CD,#00,#00,#C3,#22,#40
	db	0,"MSXDOS  SYS",0,0,0,0
BOOT2_E:

	;* Segunda parte, desde el offset #1E, version DOS 1.
	;  No se puede usar, se da de hostias con el DOS 2 del Turbo-R.

;BOOT2:
;	db	#D0,#ED,#53,#59,#C0,#32,#C4,#C0,#36,#56,#23,#36,#C0,#31,#1F,#F5
;	db	#11,#79,#C0,#0E,#0F,#CD,#7D,#F3,#3C,#CA,#63,#C0,#11,#01,#0E,#1A
;	db	#CD,#7D,#F3,#21,#01,#22,#87,#C0,#21,#3F,#11,#79,#C0,#0E,#27,#CD
;	db	#7D,#F3,#C3,#01,#58,#C0,#CD,#79,#E6,#FE,#FE,#02,#C2,#6A,#C0,#3A
;	db	#C4,#C0,#A7,#CA,#22,#40,#11,#9E,#C0,#0E,#09,#CD,#7D,#F3,#0E,#07
;	db	#CD,#7D,#F3,#18,#B2,#4D,#53,#58,#44,#4F,#53,#20,#20,#53,#59,#53
;	db	#42,#6F,#6F,#74,#20,#65,#72,#72,#6F,#72,#0D,#0A,#50,#72,#65,#73
;	db	#73,#20,#61,#6E,#79,#20,#6B,#65,#79,#20,#66,#6F,#72,#20,#72,#65
;	db	#74,#72,#79,#0D,#0A,#24,#76,#20,#31,#2E,#30,#35,#1A,#FF,#FF,#FF
;BOOT2_E:


;***************************************
;***  CODIGO NUEVO PARA EL DISK-ROM  ***
;***************************************

NEWCODE_S:

;* Un par de rutinas utiles del kernel del DOS:

GETWRK:	equ	#5FC2	;Devuelve en IX la dir de la zona de trabajo en pag. 3 del slot
GETSLT:	equ	#402D	;Devuelve en A el slot de la ROM

	;org    #7405

	;*** Parametros a establecer para cada ROM disk

DISKSIZE:	dw	0	;Numero de sectores en el disco

	db	#FF
RAMDDPB:	ds	18	;DPB del disco


	;*** Obtencion del numero de unidades a reservar para esta DiskROM
	;    Out: L=Numero de unidades
	;    Debe preservar AF,BC,DE

DRIVES:	ld	l,1
	ret


	;*** Inicializacion de la zona de trabajo:
	;    copia MAPCODE a pagina 3

INIENV:	call	GETWRK
	ex	de,hl
	ld	hl,MAPCODE-NEWCODE_S+DISKROMEND
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

_DSKIO:	jr	c,DSKIOE0	;Se pide escritura: error
	or	a
	jr	nz,DSKIOE2	;La unidad no es la 0: error

	ld	a,b	;0 sectores a transferir: no hace nada
	or	a
	ret	z

	push	hl	;Comprueba que el numero
	ld	hl,(DISKSIZE-NEWCODE_S+DISKROMEND)	;de sector sea valido
	call	COMPROM-NEWCODE_S+DISKROMEND
	pop	hl
	jr	c,DSKIOE6

	push	hl,de,bc
	call	GETWRK	;IX=rutina de copia
	pop	bc,hl,de	;Invierte DE y HL a proposito

	;>>> Aqui HL=primer sector, DE=direccion de destino

	;Si es el sector 0, lo copia directamente, decrementa el numero de sectores,
	;y vuelve a dejar el numero de sector como 0 (facilita los calculos)

	ld	a,h
	or	l
	jr	nz,NOSEC0

	push	bc
	ld	hl,SECTOR0-NEWCODE_S+DISKROMEND
	ld	bc,512
	ldir		;DE queda convenientemente actualizado
	pop	bc

	dec	b
	jr	nz,NO1SEC
	ld	b,1	;Solo se pedia un sector?
	ret
NO1SEC:	ld	hl,1	;Ahora el primer sector a leer es el 1
NOSEC0:

	;Decrementa el numero de sector, ya que el primero almacenado
	;en ROM es el 1

	dec	hl

	;Calcula la pagina de ROM inicial como: (sector\32)+1

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
	inc	a
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
	ld	iy,DSKIOK-NEWCODE_S+DISKROMEND
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

_DSKCHG:
_GETDPB:	or	a
	ld	a,12
	scf
	ret	nz	;La unidad no es la 0: error

	ex	de,hl
	ld	hl,RAMDDPB-NEWCODE_S+DISKROMEND
	ld	bc,18	;Copia DPB
	inc	de	;CUIDADO !!!!!!! Esto hace falta!
	ldir

	xor	a
	ld	b,-1	;Siempre devuelve "disco no cambiado"
	ret


	;*** Devuelve en HL la direccion de una cadena con las opciones de formateo.
	;    Si solo hay una opcion, devuelve HL=0.
	;    Si no se puede formatear, devuelve un puntero a una cadena vacia
	;    (esto ultimo solo funciona en DOS 2).

_CHOICE:	ld	a,(#F313)	;DOS 1 o DOS 2?
	or	a
	jr	z,_CHOICE1

_CHOICE2:	ld	hl,ZERO_S-NEWCODE_S+DISKROMEND	;Version DOS 2
	ret

_CHOICE1:	ld	hl,0	;Version DOS 1
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

_DSKFMT:	scf
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


;--- Nueva rutina de arranque de la DiskROM

INIT:
	;--- Comprueba si este slot ya esta en la tabla
	;    de DiskROMs (puede ocurrir si al arrancar
	;    la pagina 2 del cartucho contiene una replica
	;    de la pagina 1); en ese caso terminamos.

	di
	call	GETSLT
	ld	c,a	;C=Slot del DOS
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

	;--- Esto es la parte del codigo de arranque original que es pisada
	;    por el codigo que mapea adecuadamente la ROM

	;CALL    #781D           ;INIHRD, no necesario
	DI
	LD	A,(#FD99)
	AND	A
	RET	M
	JP	NZ,#580C
	LD	HL,#FB20
	jp	#577E	;Continuacion del codigo de arranque original

SECTOR0:	ds	512	;Aqui se copia el sector 0 del disco

NEWCODE_E:
CODE_END:
