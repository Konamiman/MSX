;ObsoNET Flash ROM loader tool.

;==============================

;--- Programador de la Flash ROM de ObsoNET 1.0
;    Por Konami Man, 7-2004


;*****************************
;***  MACROS Y CONSTANTES  ***
;*****************************

MAXFILES:	equ	1	;Usado solo en DOS 1
ENYEMAY:	equ	165	;ASCII de enye mayuscula
ENYEMIN:	equ	164	;ASCII de enye minuscula

;--- Direcciones de programacion de la flash

FLASH_TYPE:	equ	8	;8 bits o 16 bits

	if	FLASH_TYPE=8

FLASH_BANK_1:	equ	2
FLASH_DIR_1:	equ	#6AAA
FLASH_BANK_2:	equ	1
FLASH_DIR_2:	equ	#5555

	endif

	if	FLASH_TYPE=16

FLASH_BANK_1:	equ	1
FLASH_DIR_1:	equ	#5555
FLASH_BANK_2:	equ	0
FLASH_DIR_2:	equ	#6AAA

	endif

;--- Registros del RTL8019AS

RTL_REGS:	equ	#7FE0	;Direccion base de los registros del RTL
CR:	equ	RTL_REGS+0	;Comando/Seleccion de banco
BPAGE:	equ	RTL_REGS+2	;R/W, banco 3; selecciona el sector visible de la flash
FMWP:	equ	RTL_REGS+12	;W, banco 3; escribir #57 y #A8 para poder escribir en la flash

;--- Funciones del DOS

;* DOS 1

_TERM0:	equ	#00
_STROUT:	equ	#09
_FOPEN:	equ	#0F
_FCLOSE:	equ	#10
_SFIRST:	equ	#11
_SNEXT:	equ	#12
_SETDTA:	equ	#1A
_WRBLK:	equ	#26
_RDBLK:	equ	#27

;* DOS 2

_FFIRST:	equ	#40
_FNEXT:	equ	#41
_OPEN:	equ	#43
_CLOSE:	equ	#45
_READ:	equ	#48
_WRITE:	equ	#49
_TERM:	equ	#62
_DEFAB:	equ	#63
_EXPLAIN:	equ	#66
_DOSVER:	equ	#6F

;--- Rutinas y variables del sistema

ENASLT:	equ	#0024
EXPTBL:	equ	#FCC1

;--- Macro para imprimir una cadena acabada en "$"

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

	;--- Imprime presentacion

	print	PRESENT_S

	;--- Extrae el nombre del fichero (primer parametro),
	;    si no hay parametros, muestra informacion y termina

	ld	a,1
	ld	de,PARBUF
	call	EXTPAR
	jr	nc,HAYPARS

TERMINFO:	print	INFO_S
	ld	c,_TERM0
	jp	5
HAYPARS:

	;--- Comprueba version del DOS y establece DOS2
	;    y la rutina de captura de CTRL-C

	ld	c,_DOSVER
	call	5
	or	a
	jr	nz,NODOS2
	ld	a,b
	cp	2
	jr	c,NODOS2

	ld	a,#FF
	ld	(DOS2),a	;#FF para DOS 2, 0 para DOS 1

	ld	de,TERM_AB	;Rutina a ejecutar
	ld	c,_DEFAB	;si se pulsa CTRL-C/STOP
	call	5	;o se ABORTa un error de disco
NODOS2:	;

	;--- Comprueba el tamanyo del fichero y obtiene numero de sector

	call	CLBUF

	ld	de,PARBUF
	ld	ix,DISK_BUFFER
	xor	a
	ld	b,0
	call	DIR
	or	a	;Si no existe el fichero, saltar esta parte;
	jr	nz,OK_FSIZE	;al intentar abrirlo ya capturaremos el error

	ld	b,(ix+23)
	ld	a,(ix+24)
	or	b
	jr	nz,OK_FSIZE	;Mayor de 64K

	ld	l,(ix+21)
	ld	h,(ix+22)
	ld	de,16384+1
	call	COMP
	jr	c,OK_FSIZE	;Mayor de 16K

	;* El fichero es <16K: usa sector 0

	xor	a
	ld	(SECNUM),a
OK_FSIZE:

	;--- Busca la tarjeta ObsoNET

	print	SRCHOBS_S
	ld	a,#FF
	ld	(ESTESLT),a

SRCH_LOOP:	call	SIGSLOT	;Obtiene siguiente slot disponible
	cp	#FF
	jr	nz,HAYSLOTS

	print	ERROR_S	;ObsoNET no encontrado
	print	OBSNOTF_S
	jp	TERMINATE
HAYSLOTS:

	push	af
	ld	h,#40	;Conecta slot y ejecuta test
	call	ENASLT
	call	CHKOBNET
	pop	bc
	jr	nc,SRCH_LOOP

	;* Tarjeta encontrada, tenemos su slot en B

	ld	a,b
	ld	(OBSLOT),a
	and	%11
	add	"0"	;Prepara cadena informativa, slot primario...
	ld	(SLOT_S),a
	bit	7,b
	jr	z,NOEXPSLT

	ld	a,"-"	;...y subslot si es necesario
	ld	(SLOT_S+1),a
	ld	a,b
	rrca
	rrca
	and	%11
	add	"0"
	ld	(SLOT_S+2),a
NOEXPSLT:

	print	FOUND_S	;Muestra informacion de tarjeta encontrada

	ld	a,(OBSLOT)
	ld	h,#40
	call	ENASLT

	ld	a,%00000001	;Detiene el RTL
	ld	(CR),a

	;--- Abre el fichero con la ROM

	xor	a	;Necesario en DOS 1
	ld	(FCBS),a

	ld	de,PARBUF
	call	OPEN
	or	a
	jr	z,OPEN_OK

	;* No puede abrirlo: en DOS 1 muestra "Can't open file",
	;  en DOS 2 muestra el error adecuado; despues termina

	ld	a,(DOS2)
	or	a
	jr	nz,FERR_DOS2

	print	CANTOPEN_S	;DOS 1
	jp	TERMINATE

FERR_DOS2:	ld	de,PARBUF
	ld	c,_EXPLAIN	;DOS 2
	call	5
	print	AST_S
	ld	de,PARBUF
	call	PRINTZ
	jp	TERMINATE

OPEN_OK:	ld	a,b
	ld	(FH),a

	;--- Conecta banco 3 del RTL para poder acceder a BPAGE

        ld      a,(OBSLOT)
        ld      h,#40
        call    ENASLT

	ld	a,%11 000 0 00	;Conecta banco 3
	ld	(CR),a


;-----------------------------
;---  Borrado de la flash  ---
;-----------------------------

	;--- Imprime el mensaje de borrado

	ld	a,(SECNUM)
	cp	#FF
	jr	z,PRINTE_ALL

	;* Imprime "Borrando sector 0"

	print	ERASEC_S
	jr	OK_PRINTER

	;* Imprime "Borrando memoria"

PRINTE_ALL:	print	ERAMEM_S
OK_PRINTER:

	;--- Envia el comando de borrado a la flash

	ld	a,(OBSLOT)
	ld	h,#40
	call	ENASLT

	;* Cinco primeros ciclos, comunes al borrado completo y de sector

	ld	a,FLASH_BANK_1	;Primer ciclo (unlock)
	ld	(BPAGE),a
	ld	a,#AA
	ld	(FLASH_DIR_1),a

	ld	a,FLASH_BANK_2	;Segundo ciclo (unlock)
	ld	(BPAGE),a
	ld	a,#55
	ld	(FLASH_DIR_2),a

	ld	a,FLASH_BANK_1	;Tercer ciclo (comando)
	ld	(BPAGE),a
	ld	a,#80
	ld	(FLASH_DIR_1),a

	;ld      a,FLASH_BANK_1
	;ld      (BPAGE),a
	ld	a,#AA	;Cuarto ciclo (unlock)
	ld	(FLASH_DIR_1),a

	ld	a,FLASH_BANK_2	;Quinto ciclo (unlock)
	ld	(BPAGE),a
	ld	a,#55
	ld	(FLASH_DIR_2),a

	;* Sexto ciclo, depende de si es borrado completo o de sector

	ld	a,(SECNUM)
	cp	#FF
	jr	z,CYCLE6_ALL

	ld	(BPAGE),a	;Borrado de sector
	ld	a,#30
	ld	(#4000),a
	jr	OK_ERASE6

CYCLE6_ALL:	ld	a,FLASH_BANK_1	;Borrado completo
	ld	(BPAGE),a
	ld	a,#10
	ld	(FLASH_DIR_1),a
OK_ERASE6:

	;--- Espera a que termine el borrado

WAIT_ERASE:	nop
	ld	a,(#4000)
	bit	7,a
	jr	nz,OK_ERASE

	and	%00100000
	jr	z,WAIT_ERASE

	nop
	ld	a,(#4000)
	and	%10000000
	jr	nz,OK_ERASE

	;* El borrado ha fallado

	print	ERROR_S
	print	FAILERASE_S
	jp	TERMINATE

	;* El borrado ha terminado OK

OK_ERASE:	print	OK_S

	;--- Ultimas inicializaciones

	xor	a
	ld	(SECNUM),a

	print	WRITING_S	;Imprime "escribiendo"

	ld	a,(OBSLOT)
	ld	h,#40
	call	ENASLT

;-------------------------------
;---  Escritura en la flash  ---
;-------------------------------

MAIN_LOOP:

	;--- Lee 16K-32 bytes del fichero
	;    (se salta los registros del RTL) en la pagina 2

	ld	a,(FH)
	ld	b,a
	ld	de,#8000
	ld	hl,16384-32
	call	READ
	ld	a,h
	or	l
	jr	nz,OK_READED

	;* No lee nada: operacion finalizada

	print	OK_S
	print	OKWRITE_S
	jp	TERMINATE
OK_READED:

	ld	a,(SECNUM)
	cp	32	;8 en 128K
	jr	c,NO_TOOBIG
	print	OK_S	;Fichero demasiado grande: avisa y termina
	print	OKWRITE_S
	print	TOOBIG_S
	jp	TERMINATE
NO_TOOBIG:

	push	hl
	ld	a,(OBSLOT)
	ld	h,#40
	call	ENASLT

        ld      a,%11000000
        ld      (CR),a

	;--- Bucle de escritura de todos los bytes leidos

	pop	bc
	ld	hl,#8000	;Origen en TPA
	ld	de,#4000	;Destino en la flash

WRITE_LOOP:	push	bc

	;* Envia el comando de escritura a la flash

	ld	a,FLASH_BANK_1	;Primer ciclo (unlock)
	ld	(BPAGE),a
	ld	a,#AA
	ld	(FLASH_DIR_1),a

	ld	a,FLASH_BANK_2	;Segundo ciclo (unlock)
	ld	(BPAGE),a
	ld	a,#55
	ld	(FLASH_DIR_2),a

	ld	a,FLASH_BANK_1	;Tercer ciclo (comando)
	ld	(BPAGE),a
	ld	a,#A0
	ld	(FLASH_DIR_1),a

	ld	a,(SECNUM)	;Cuarto ciclo: escritura del dato
	ld	(BPAGE),a
	ld	a,(hl)
	ld	(de),a

	;* Espera a que la escritura termine

	and	%10000000
	ld	b,a	;B=bit 7 del dato escrito
WAIT_WRITE:	nop
	ld	a,(de)
	ld	c,a
	and	%10000000
	cp	b
	jr	z,OK_WRITE

	ld	a,c
	and	%00100000
	jr	z,WAIT_WRITE

	nop
	ld	a,(de)
	and	%10000000
	cp	b
	jr	z,OK_WRITE

	pop	bc	;La escritura ha fallado
	print	ERROR_S
	print	FAILWRITE_S
	jp	TERMINATE

OK_WRITE:	pop	bc
	inc	hl	;Actualiza direcciones y contador
	inc	de
	dec	bc

	ld	a,b	;Quedan datos: repetir bucle
	or	c
	jr	nz,WRITE_LOOP

	;--- La escritura del bloque de 16K ha terminado

	;* Se salta los siguientes 32 bytes del fichero
	;  (corresponden a los 32 registros del RTL; no podemos escribirlos
	;   y tampoco podriamos leerlos)

	ld	a,(FH)
	ld	b,a
	ld	de,#8000
	ld	hl,32
	call	READ

	;* Incrementa el numero de sector
	;  y vuelve al bucle principal

	ld	hl,SECNUM
	inc	(hl)
	jp	MAIN_LOOP


;********************
;***  SUBRUTINAS  ***
;********************

;--- Rutina de terminacion, se asegura de que el fichero quede cerrado
;    y de que se resetee la flash y se restaure la RAM en la pagina 1

TERM_AB:	push	af	;Terminacion al pulsar CTRL-C o abortar error de disco
	call	FINISH	;en DOS 2: el error se pasa en A
	pop	af
	ret

TERMINATE:	ld	c,_DEFAB	;Terminacion normal, DOS 1 y DOS 2
	ld	de,0
	ld	a,(DOS2)
	or	a
	call	nz,5
	call	FINISH
	ld	c,_TERM0
	jp	5

	;* Rutina comun para preparar la finalizacion

FINISH:	ld	a,(FH)
	cp	#FF
	ld	b,a
	call	nz,CLOSE	;Cierra el fichero de la ROM si esta abierto

	;Habia ObsoNET: Ejecuta RESET en la flash

	ld	a,(OBSLOT)
	cp	#FF
	jr	z,NOOBS

        ld      a,(OBSLOT)
        ld      h,#40
        call    ENASLT

	ld	a,%11 100 0 00	;Conecta banco 3 del RTL
	ld	(CR),a

	ld	a,FLASH_BANK_1	;Primer ciclo (unlock)
	ld	(BPAGE),a
	ld	a,#AA
	ld	(FLASH_DIR_1),a

	ld	a,FLASH_BANK_2	;Segundo ciclo (unlock)
	ld	(BPAGE),a
	ld	a,#55
	ld	(FLASH_DIR_2),a

	ld	a,FLASH_BANK_1	;Tercer ciclo (comando)
	ld	(BPAGE),a
	ld	a,#F0
	ld	(FLASH_DIR_1),a

	xor	a	;Deja la pagina 0 de ROM
	ld	(BPAGE),a

	;xor	a
	;ld	(FMWP),a	;Deshabilita escritura en flash
	ld	a,%00 100 0 00	;Restaura banco 0 del RTL
	ld	(CR),a
NOOBS:

	;Restaura TPA en pagina 1 y termina        

	ld	a,(#F342)
	ld	h,#40
	call	ENASLT

	ld	hl,0
	ld	(#8000),hl

	ret


;--- NOMBRE: EXTPAR
;      Extraccion de un parametro de la linea de comandos
;    ENTRADA:   A  = Parametro a extraer (el primero es el 1)
;               DE = Bufer para dejar el parametro
;    SALIDA:    A  = Numero de parametros
;               CY = 1 -> No existe ese parametro
;                         B indefinido, bufer inalterado
;               CY = 0 -> B = Longitud del parametro (no incluye el 0)
;                         Parametro a partir de DE, acabado en 0
;    REGISTROS: -
;    LLAMADAS:  -

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
	ld	b,0	;(necesario en DOS 1)
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
	;jrmy   EXTPERR          ;existentes    

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


;--- NOMBRE: COMP
;      Comparacion de HL con DE (16 bits en complemento a 2)
;    ENTRADA:   HL, DE = numeros a comparar
;    SALIDA:     C, NZ si HL > DE
;                C,  Z si HL = DE
;               NC, NZ si HL < DE
;    REGISTROS: AF

COMP:	call	_COMP16
	ccf
	ret

_COMP16:	ld	a,h
	sub	d
	ret	nz
	ld	a,l
	sub	e
	ret


;--- Subrutina SIGSLOT:
;    Devuelve en A el siguiente slot cada vez que es llamada.
;    Para incializarla hay que poner ESETESLT a #FF.

SIGSLOT:	ld	a,(ESTESLT)	;Devuelve el siguiente slot, empezando
	cp	#FF	;por el 0. Si no quedan mas, devuelve #FF
	jr	nz,SIGSL1	;Modifica AF, BC, HL.  
	ld	a,(EXPTBL)
	and	%10000000
	ld	(ESTESLT),a
	ret

SIGSL1:	ld	a,(ESTESLT)
	cp	%10001111
	jr	z,NOMASLT
	cp	%00000011
	jr	z,NOMASLT
	bit	7,a
	jr	nz,SLTEXP

SLTSIMP:	and	%00000011
	inc	a
	ld	c,a
	ld	b,0
	ld	hl,EXPTBL
	add	hl,bc
	ld	a,(hl)
	and	%10000000
	or	c
	ld	(ESTESLT),a
	ret

SLTEXP:	ld	c,a
	and	%00001100
	cp	%00001100
	ld	a,c
	jr	z,SLTSIMP
	add	%00000100
	ld	(ESTESLT),a
	ret

NOMASLT:	ld	a,#FF
	ret

ESTESLT:	db	#FF


;--- Busqueda "hard" de una tarjeta ObsoNET.
;    El metodo de buscar la cadena "ObsoNET" en el slot no funcionara
;    si la ROM esta vacia o corrupta. Esta rutina SIEMPRE encontrara
;    una tarjeta ObsoNET presente en el slot conectado en pagina 1.
;
;    Entrada:  -
;    Salida:   Cy = 1 si en la pagina 1 hay una ObsoNET, 0 si no
;    Modifica: AF, B

CHKOBNET:
	ld	a,(#7FE0)	;Guarda valor para restaurarlo
	ld	b,a	;si no hay una ObsoNET

	xor	a		;Conecta banco 0
	ld	(#7FE0),a

	ld	a,(#7FEA)	;Lee registros 10 y 11 (8019ID0/1),
	cp	#50	;deben devolver #50 y #70 respectivamente
	jr	nz,NO_OBNET
	ld	a,(#7FEB)
	cp	#70
	jr	nz,NO_OBNET

	ld	a,#80		;Conecta banco 2
	ld	(#7FE0),a

	ld	a,(#7FEA)	;Lee registros 10 y 11 (no usados,
	cp	#50	;NO deben devolver #50 y #70)
	scf
	ret	nz
	ld	a,(#7FEB)
	cp	#70
	scf
	ret	nz

NO_OBNET:
	ld	a,b	;No hay ObsoNET: restaura contenido
	ld	(#7FE0),a	;de #7FE0 por si es RAM
	or	a
	ret


;--- PRINTZ: Imprime una cadena acabada en "0"
;            Entrada: DE = Cadena

PRINTZ:	ld	a,(de)
	or	a
	ret	z
	push	de
	ld	e,a
	ld	c,2
	call	5
	pop	de
	inc	de
	jr	PRINTZ


;-----------------------------------
;---  Rutinas de acceso a disco  ---
;-----------------------------------

;--- NOMBRE: CLBUF
;      Limpia el buffer generico para las operaciones de disco
;    ENTRADA:   -
;    SALIDA:    -
;    REGISTROS: -

CLBUF:	push	hl,de,bc
	ld	hl,DISK_BUFFER
	ld	de,DISK_BUFFER+1
	ld	bc,70-1
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


;--- NOMBRE: DIR
;      Busca un fichero
;      Siempre se debe ejecutar primero con A=0
;      Para buscar los siguientes, DISK_BUFFER no debe ser modificado
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
;     REGISTROS: F,C

OFBUF1:	equ	38

DIR:	ld	c,a
	ld	a,(DOS2)
	or	a
	ld	a,c
	jp	nz,DIR2

	;--- DIR: Version DOS 1

DIR1:	push	bc,de,hl,iy,ix,af
	call	CLBUF
	ex	de,hl
	ld	de,DISK_BUFFER	;Pasamos el nombre normal de (DE)
	or	a	;a nombre FCB en BUFFER.
	call	CONVNAME

	ld	de,DISK_BUFFER+OFBUF1	;Ponemos el area de transferencia
	ld	c,_SETDTA	;en el buffer, tras el FCB del fichero
	call	5	;a buscar.
	ld	de,DISK_BUFFER
	pop	af
	and	1
	ld	c,_SFIRST
	add	c
	ld	c,a
	call	5
	or	a	;Terminamos con A=#FF si no se encuentra.
	jp	nz,ENDFF1

	ld	a,(DISK_BUFFER+OFBUF1)	;Guardamos la unidad del FCB
	ld	(ULO1),a	;en ULO1, y la ponemos a 0
	xor	a	;para poder convertirla a nombre normal
	ld	(DISK_BUFFER+OFBUF1),a	;sin unidad.
	ld	iy,DISK_BUFFER+OFBUF1

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

	;--- DIR: Version DOS 2

DIR2:	push	hl,bc,de,ix
	ld	ix,DISK_BUFFER
	ld	c,_FFIRST
	and	1
	add	c
	ld	c,a
	call	5
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


;--- NOMBRE: OPEN
;      Abre un fichero
;    ENTRADA:   DE = Fichero a abrir
;    SALIDA:    A  = 0 -> Error
;               A <> 0 -> Error
;                         DOS 1: A=1 -> demasiados ficheros abiertos
;               B  = Numero asociado al fichero
;                    (no tiene nada que ver con el numero de ficheros abiertos)
;    REGISTROS: F, C

OPEN:	ld	a,(DOS2)
	or	a
	jp	nz,OPEN2

	;--- OPEN: Version DOS 1

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
	ld	c,_FOPEN
	call	5
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

	;--- OPEN: Version DOS 2

OPEN2:	push	hl,de
	xor	a
	ld	c,_OPEN
	call	5
	or	a
	jp	nz,OP2END
	ld	a,(NUMFILES)
	inc	a
	ld	(NUMFILES),a
	xor	a
OP2END:	pop	de,hl
	ret


;--- NOMBRE: CLOSE
;      Cierra un fichero
;    ENTRADA:   B  = Numero de fichero
;    SALIDA:    A  = 0 -> Fichero cerrado
;               A <> 0 -> Error
;    REGISTROS: F

CLOSE:	ld	a,(DOS2)
	or	a
	jp	nz,CLOSE2

	;--- CLOSE: Version DOS 1

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
	ld	c,_FCLOSE
	call	5
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

	;--- CLOSE: Version DOS 2

CLOSE2:	push	bc,de,hl
	ld	c,_CLOSE
	call	5
	or	a
	jp	nz,ENDCL2
	ld	a,(NUMFILES)
	dec	a
	ld	(NUMFILES),a
	xor	a
ENDCL2:	pop	hl,de,bc
	ret


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

READ:	ld	a,(DOS2)
	or	a
	jp	nz,READ2

	;--- READ: Version DOS 1 

READ1:	ld	a,_RDBLK
	ld	(RWCODE),a
	jp	RW1

	;--- READ: Version DOS 2 

READ2:	ld	a,_READ
	ld	(RWCODE),a
	jp	RW2


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

WRITE:	ld	a,(DOS2)
	or	a
	jp	nz,WRITE2

	;--- WRITE: Version DOS 1

WRITE1:	ld	a,_WRBLK
	ld	(RWCODE),a
	jp	RW1

	;--- WRITE: Version DOS 2

WRITE2:	ld	a,_WRITE
	ld	(RWCODE),a
	jp	RW2


;--- RW: Rutina generica de lectura/escritura

	;--- RW: Version DOS 1

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
	ld	c,_SETDTA
	call	5
	pop	de,hl
	inc	de
	ld	a,(RWCODE)	;Leemos el codigo de lectura o escritura
	ld	c,a
	call	5	;y ejecutamos la llamada

ENDRW1:	pop	iy,ix,de,bc
	ret
ENDRW11:	pop	bc,bc,bc
	jp	ENDRW1

	;--- RW: Version DOS 2

RW2:	;push	bc,de,hl
	ld	a,(RWCODE)	;Leemos el codigo de lectura o escritura
	ld	c,a
	call	5
	ret		;*** PRUEBAS: Devuelve el error real, no el 1

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

RWCODE:	db	0	;Codigo de la funcion de lectura/escritura


;*************************************
;***  VARIABLES, CADENAS, BUFERES  ***
;*************************************

;-------------------
;---  Variables  ---
;-------------------

NUMFILES:	db	0	;Numero de ficheros abiertos
SECNUM:	db	#FF	;Sector a escribir, #FF=todo el chip
OBSLOT:	db	#FF	;Slot de ObsoNET
FH:	db	#FF	;File Handle del fichero abierto (incluso en DOS 1)
DOS2:	db	0	;#FF si se detecta DOS 2


;-----------------
;---  Cadenas  ---
;-----------------

PRESENT_S:	db	"ObsoNET Flash ROM loader 1.0 - By Konami Man, 10-2004",13,10
	db	"ObsoNET hardware by Daniel Berdugo",13,10,13,10,"$"
INFO_S:	db	"Usage: ONETFRL <filename>",13,10	; [<page>]",13,10
	db	"       <filename>: File with the ROM image to write (up to 512K long).",13,10
	db	"       The last 32 bytes of each 16K block of the file data are skipped.",13,10,"$"
SRCHOBS_S:	db	"> Searching ObsoNET card... $"
FOUND_S:	db	"OK, found at slot "
SLOT_S:	db	"0  ",13,10,13,10,"$"
OBSNOTF_S:	db	"*** ObsoNET card not found",13,10,"$"
OPENINGF_S:	db	"> Opening file... $"
CANTOPEN_S:	db	"*** File not found or invalid file name",13,10,"$"
ERAMEM_S:	db	"> Erasing flash memory... $"
ERASEC_S:	db	"> Erasing flash memory page 0... $"
OK_S:	db	"OK",13,10,13,10,"$"
ERROR_S:	db	"ERROR!",13,10,13,10,"$"
FAILERASE_S:	db	"*** Failed to erase the flash memory",13,10,"$"
WRITING_S:	db	"> Writing flash memory... $"
FAILWRITE_S:	db	"*** Failed to write on the flash memory",13,10,"$"
OKWRITE_S:	db	"Write process completed.",13,10,"$"
TOOBIG_S:	db	13,10,"WARNING: The file is too big.",13,10
	db	"Only the first 512 KBytes of the file have been written to the flash memory.",13,10,"$"
AST_S:	db	"*** $"


;-----------------
;---  Buferes  ---
;-----------------

FCBS:	;Usado solo en DOS 1
DISK_BUFFER:	equ	FCBS+38*MAXFILES
PARBUF:	equ	DISK_BUFFER+71
BUFPAR:	equ	PARBUF
