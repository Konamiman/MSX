;NestorPreTer - MSX-BASIC preinterpreter
;Go to http://konamiman.com#nestorpreter for documentation and examples.

;===============================================

	;NestorPreTer 0.3 - Pre-interprete de MSX-BASIC
	;por Konami Man, 1999

	;Cambios de 0.2 a 0.3:
	;- Arreglado un fallo que producia numeracion incorrecta
	;  al usar directivas y la opcion /LIN juntas
	;- Anyadida la opcion de usar un fichero de macros


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

_CONOUT:	equ	#02
_STROUT:	equ	#09
_FOPEN:	equ	#0F
_FCLOSE:	equ	#10
_FMAKE:	equ	#16
_SETDTA:	equ	#1A
_WRBLK:	equ	#26
_RDBLK:	equ	#27
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

ENASLT:	equ	#0024
EXTBIO:	equ	#FFCA
GETPNT:	equ	#F3FA
PUTPNT:	equ	#F3F8
KEYBUF:	equ	#FBF0

EOF:	equ	#1A
NOPCODE:	equ	#00
RETCODE:	equ	#C9
TAB:	equ	9

PARBUF:	equ	#4000
PARBUF2:	equ	#4100

INFCOPIA_SEG:	equ	3	;Segmento con la copia de las primeras
	;                        ;16K del fichero de entrada
MACCOPIA_SEG:	equ	4	;Segmento con la copia de las primeras
	;                        ;16K del fichero de macros
;TABLAS_SEG:   equ     5                ;Primer segmento de la tabla de macros
	;                        ;y etiquetas de linea


;***************************************************************************
;*                                                                         *
;* INICIALIZACION: OBTENCION DE PARAMETROS, APERTURA/CREACION DE FICHEROS, *
;*                 Y RESERVA DE MEMORIA                                    *
;*                                                                         *
;***************************************************************************

	org	#100

	ld	a,RETCODE
	ld	(INCCODE),a

	;--- Presentacion

	ld	de,PRES_S
	call	PRINT

	ld	a,1
	ld	de,PARBUF
	call	EXTPAR
	jr	nc,HAYPARS

	ld	de,USAGE_S	;Si no hay parametros, solo mostramos uso
	call	PRINT
	ld	c,0
	jp	5
HAYPARS:	;

	;--- Limpieza zona de variables

	ld	hl,DATOS
	ld	de,DATOS+1
	ld	bc,#3FFF-DATOS
	ld	(hl),0
	ldir

	;--- Obtencion de la version del DOS

	ld	c,_GETVER
	call	5
	ld	a,b
	or	a
	jr	z,OKDOSV
	dec	a
OKDOSV:	ld	(DOSVER),a

	;--- Reserva de memoria

	ld	ix,MEMTAB
	ld	a,(DOSVER)
	or	a
	jr	nz,MEMDOS2

MEMDOS1:	ld	de,#4000
	call	MEMTEST1
	cp	1
	jrmy	OKMAP
	ld	de,NOMAP_S	;Error si no hay mem. mapeada
	jp	INIERR

OKMAP:	cp	4
	jrmy	OKMAP2
	ld	de,NOFREE_S	;Error si solo hay 64K de mem. mapeada
	jp	INIERR

OKMAP2:	cp	16
	jrmn	OKMAP3

MEM256:	push	af	;Menos de 256K (=128K)?
	ld	a,8
	ld	(ix+13),a
	pop	af

OKMAP22:	cp	32
	jrmni	OKMAP3	;Maximo: 512K (32 segs)
	ld	a,32

OKMAP3:	sub	2	;Descontamos pag. 0 y 3
	ld	(NUMSEGS),a
	ld	b,a
	ld	a,(#F342)
BUCMEM1:	ld	(ix),a
	inc	ix
	inc	ix
	djnz	BUCMEM1
	ld	a,-1
	ld	(ix+1),a

	jr	OK_MEM

MEMDOS2:	ld	de,#0402
	call	EXTBIO
	ld	de,ALL_SEG
	ld	bc,#30
	ldir

	ld	a,(#F342)
	ld	(MEMTAB),a
	ld	(MEMTAB+2),a

	ld	b,28
	ld	ix,MEMTAB+4
BUCRESMEM:	push	bc	;Reserva todos los segmentos que puede
	ld	a,-1	;hasta 12
	ld	(ix+1),a
	ld	a,(#F342)
	ld	b,a
	set	5,b
	xor	a
	call	ALL_SEG
	jr	c,OKRESMEM
	ld	(ix),b
	ld	(ix+1),a
	inc	ix
	inc	ix
	pop	bc
	djnz	BUCRESMEM
	push	bc

OKRESMEM:	pop	bc
	ld	a,28
	sub	b
	cp	3
	jrmyi	OKRESM2

	ld	de,NOFREE_S	;Error si no se ha podido reservar ningun
	jp	INIERR	;segmento

OKRESM2:	add	2
	ld	(NUMSEGS),a

	call	GET_P1
	ld	(MEMTAB+1),a
	call	GET_P2
	ld	(MEMTAB+3),a

OK_MEM:	ld	a,(#F342)
	ld	(SLOT_P1),a
	ld	(SLOT_P2),a

	;--- Establecemos MEM_S

	ld	a,(NUMSEGS)
	sub	3
	ld	e,a
	ld	d,0
	sla	e
	rl	d
	sla	e
	rl	d
	sla	e
	rl	d
	sla	e
	rl	d
	ld	hl,MEM_S2
	call	NUMTO2
	ld	a,"K"
	ld	(hl),a
	inc	hl
	call	PUTCR

	;--- Obtencion del nombre del fichero de entrada

	ld	a,1
	ld	de,PARBUF
	call	EXTPAR

	ld	hl,PARBUF
	ld	a,(hl)
	cp	"/"
	jr	nz,OKINFILE

	ld	de,INFERR_S	;Si no hay infile o es incorrecto, error
	jp	INIERR	;y fin

OKINFILE:	ld	de,EXT_ASC
	call	CHKEXT	;Ponemos extension ASC si no hay ninguna
	ld	de,INFILE
	call	COPYFN	;Copiamos nombre de fichero a INFILE

	ld	hl,PARBUF	;Guardamos nombre/ruta de INFILE
	ld	de,PARBUF2	;por si hay que usarlo en OUTFILE
	ld	bc,128
	ldir

	ld	ix,INFILE
	call	ENDFN
	call	OPEN	;Abrimos fichero
	jp	c,INIERRC
	ld	(FH_IN),a

	;--- Obtencion del nombre del fichero de salida

	ld	a,2
	ld	de,PARBUF
	call	EXTPAR
	ld	de,OUTFILE
	call	c,PUTINF	;outfile = infile si no hay mas pars...
	ld	a,(PARBUF)
	cp	"/"
	ld	de,OUTFILE
	call	z,PAR2BARRA
	call	z,PUTINF	;...o si el segundo ya es "/algo"

	ld	de,EXT_BAS
	call	CHKEXT
	ld	de,OUTFILE
	call	COPYFN

	ld	ix,OUTFILE
	call	ENDFN
	ld	de,DUPLI_S
	ld	hl,INFILE
	call	COMPFN
	jp	c,INIERR

	call	CREATE	;Creamos fichero
	jp	c,INIERRC
	ld	(FH_OUT),a

	;--- Obtencion de los demas parametros

	ld	a,(NEXTPAR)
BUCPAR:	push	af
	ld	de,PARBUF
	call	EXTPAR
	jp	c,OKALLPARS

	ld	a,(PARBUF)
	cp	"/"
	jr	z,OKBARRA

PERR:	ld	de,PARERR_S	;Si el parametro no empieza por "/",
	jp	INIERR	;error y fin

OKBARRA:	ld	a,(PARBUF+1)
	and	%11011111
	cp	"B"
	jp	z,PAR_B
	cp	"C"
	jp	z,PAR_C
	cp	"F"
	jp	z,PAR_F
	cp	"I"
	jp	z,PAR_I
	cp	"M"
	jr	z,CHK_MAC1
	cp	"L"
	jp	nz,PERR

CHK_LOG1:	ld	a,(PARBUF+2)
	and	%11011111
	cp	"O"
	jp	nz,CHK_LIN1
	ld	a,(PARBUF+3)
	and	%11011111
	cp	"G"
	jp	nz,PERR
	ld	a,(FH_LOG)
	cp	-1
	jp	nz,OKNEXTPAR
	jp	PAR_LOG

CHK_LIN1:	ld	a,(PARBUF+2)
	and	%11011111
	cp	"I"
	jp	nz,CHK_LIN1
	ld	a,(PARBUF+3)
	and	%11011111
	cp	"N"
	jp	nz,PERR
	ld	a,(FH_LIN)
	cp	-1
	jp	nz,OKNEXTPAR
	jp	PAR_LIN

CHK_MAC1:	ld	a,(PARBUF+2)
	and	%11011111
	cp	"A"
	jp	nz,CHK_LIN1
	ld	a,(PARBUF+3)
	and	%11011111
	cp	"C"
	jp	nz,PERR
	ld	a,(FH_MAC)
	cp	-1
	jp	nz,OKNEXTPAR
	jp	PAR_MAC

PAR_B:	ld	a,(PARBUF+2)	;*** /B
	cp	"1"
	jr	nz,NOPARB1
	ld	a,(BOOT)
	cp	34
	jp	nz,OKNEXTPAR
	ld	a,-1
	ld	(BOOT),a
	jp	OKNEXTPAR
NOPARB1:	cp	"0"
	jp	nz,PERR
	jp	OKNEXTPAR

PAR_C:	ld	a,(PARBUF+2)	;*** /C
	cp	"1"
	jr	nz,NOPARC1
	ld	a,(CASE)
	cp	34
	jp	nz,OKNEXTPAR
	ld	a,-1
	ld	(CASE),a
	jp	OKNEXTPAR
NOPARC1:	cp	"0"
	jp	nz,PERR
	jp	OKNEXTPAR

PAR_I:	ld	hl,PARBUF+2	;*** /I
	call	EXTNUM
	jp	c,PERR
	ld	hl,(FIRSTBI)
	inc	hl
	ld	a,h
	or	l
	jp	nz,OKNEXTPAR
	ld	(FIRSTBI),bc
	jp	OKNEXTPAR

PAR_F:	ld	hl,PARBUF+2	;*** /F
	call	EXTNUM
	jp	c,PERR
	ld	hl,(FIRSTBL)
	inc	hl
	ld	a,h
	or	l
	jp	nz,OKNEXTPAR
	ld	(FIRSTBL),bc
	jp	OKNEXTPAR

PAR_LOG:	ld	hl,PARBUF+4	;*** /LOG
PL2:	ld	a,(hl)
	cp	" "
	jr	z,LOGESIN
	or	a
	jr	z,LOGESIN
	cp	":"
	inc	hl
	jr	z,PL2
	dec	hl

	ld	de,PARBUF	;Copiamos fichero LOG, sin el "/LOG:",
	ld	bc,128	;a PARBUF
	ldir
	jr	OKLOGN

LOGESIN:	call	PUTINF
OKLOGN:	ld	de,EXT_LOG
	call	CHKEXT
	ld	de,LOGFILE
	call	COPYFN

	ld	ix,LOGFILE
	call	ENDFN
	ld	de,DUPLI_S
	ld	hl,INFILE
	call	COMPFN
	jp	c,INIERR
	ld	hl,OUTFILE
	call	COMPFN
	jp	c,INIERR

	call	CREATE	;Creamos fichero
	jp	c,INIERRC
	ld	(FH_LOG),a
	jp	OKNEXTPAR

PAR_LIN:	ld	hl,PARBUF+4	;*** /LIN
PL3:	ld	a,(hl)
	cp	" "
	jr	z,LINESIN
	or	a
	jr	z,LINESIN
	cp	":"
	inc	hl
	jr	z,PL3
	dec	hl

	ld	de,PARBUF	;Copiamos fichero LIN, sin el "/LIN:",
	ld	bc,128	;a PARBUF
	ldir
	jr	OKLINN

LINESIN:	call	PUTINF
OKLINN:	ld	de,EXT_LIN
	call	CHKEXT
	ld	de,LINFILE
	call	COPYFN

	ld	ix,LINFILE
	call	ENDFN
	ld	de,DUPLI_S
	ld	hl,INFILE
	call	COMPFN
	jp	c,INIERR
	ld	hl,OUTFILE
	call	COMPFN
	jp	c,INIERR
	ld	hl,LOGFILE
	call	COMPFN
	jp	c,INIERR

	call	CREATE	;Creamos fichero
	jp	c,INIERRC
	ld	(FH_LIN),a
	jp	OKNEXTPAR

PAR_MAC:	ld	hl,PARBUF+4	;*** /MAC
PM1:	ld	a,(hl)
	cp	" "
	jr	z,MACESIN
	or	a
	jr	z,MACESIN
	cp	":"
	inc	hl
	jr	z,PM1
	dec	hl

	ld	de,PARBUF	;Copiamos fichero MAC, sin el "/MAC:",
	ld	bc,128	;a PARBUF
	ldir
	jr	OKMACN

MACESIN:	call	PUTINF
OKMACN:	ld	de,EXT_MAC
	call	CHKEXT
	ld	de,MACFILE
	call	COPYFN

	ld	ix,MACFILE
	call	ENDFN
	ld	de,DUPLI_S
	ld	hl,INFILE
	call	COMPFN
	jp	c,INIERR
	ld	hl,OUTFILE
	call	COMPFN
	jp	c,INIERR
	ld	hl,LOGFILE
	call	COMPFN
	jp	c,INIERR
	ld	hl,LINFILE
	call	COMPFN
	jp	c,INIERR

	call	OPEN	;Abrimos fichero
	ld	b,a
	push	af
	cp	215
	jr	nz,OKMACN2
	ld	b,7
OKMACN2:	pop	af
	ld	a,b
	jp	c,INIERRC
	ld	(FH_MAC),a
	;jp      OKNEXTPAR

OKNEXTPAR:	pop	af	;Siguiente parametro
	inc	a
	jp	BUCPAR

OKALLPARS:	pop	af

CHKDEFB:	ld	a,(BOOT)	;Establece los parametros que no han
	cp	34	;sido especificados
	jr	nz,CHKDEFC
	xor	a
	ld	(BOOT),a
CHKDEFC:	ld	a,(CASE)
	cp	34
	jr	nz,CHKDEFF
	xor	a
	ld	(BOOT),a
CHKDEFF:	ld	hl,(FIRSTBL)
	inc	hl
	ld	a,h
	or	l
	jr	nz,CHKDEFI
	ld	hl,10
	ld	(FIRSTBL),hl
CHKDEFI:	ld	hl,(FIRSTBI)
	inc	hl
	ld	a,h
	or	l
	jr	nz,CHKDEFX
	ld	hl,10
	ld	(FIRSTBI),hl
CHKDEFX:	;

	ld	a,(FH_MAC)
	cp	-1
	jr	z,NOHAYMAC0
	ld	a,5
	ld	(TABLAS_SEG),a
NOHAYMAC0:	;


;*************************************************
;*                                               *
;* MUESTRA INFO Y CREA LISTA DE DEFINES Y LINEAS *
;*                                               *
;*************************************************

	;--- Muestra nombres de ficheros, y memoria,
	;    en pantalla y en LOG file

	ld	de,LOGTIT_S
	call	PRINTLOG
	call	BLANKLOG
	call	BLANKLOG
	ld	de,LINTIT_S
	call	PRINTLIN
	call	BLANKLIN
	call	BLANKLIN

	ld	de,INF_S
	call	PRINTLOG
	call	PRINTLIN
	call	PRINT

	ld	de,OUTF_S
	call	PRINTLOG
	call	PRINTLIN
	call	PRINT

	ld	de,NOLOG_S
	ld	a,(FH_LOG)
	cp	-1
	jr	z,PRLOG
	ld	de,LOGF_S
PRLOG:	call	PRINTLOG
	call	PRINT

	ld	de,NOLIN_S
	ld	a,(FH_LIN)
	cp	-1
	jr	z,PRLIN
	ld	de,LINF_S
PRLIN:	call	PRINTLOG
	call	PRINT

	ld	de,NOMAC_S
	ld	a,(FH_MAC)
	cp	-1
	jr	z,PRMAC
	ld	de,MACF_S
PRMAC:	call	PRINTLOG
	call	PRINT

	call	BLANK
	call	BLANKLOG
	ld	de,MEM_S
	call	PRINTLOG
	call	PRINT

	call	BLANK
	ld	a,(CASE)
	or	a
	ld	hl,NO_S
	ld	bc,5
	jr	z,MKCASE
	ld	hl,YES_S
	ld	bc,6
MKCASE:	ld	de,CASE_ONOF
	ldir
	ld	de,CASE_S
	call	PRINTLOG
	call	PRINT
	call	BLANKLOG

	ld	a,(BOOT)
	or	a
	ld	hl,NO_S
	ld	bc,5
	jr	z,MKBOOT
	ld	hl,YES_S
	ld	bc,6
MKBOOT:	ld	de,BOOT_ONOF
	ldir
	ld	de,BOOT_S
	call	PRINT

	;--- Construye tabla de DEFINEs

	call	BLANK
	ld	de,SRDEF_S
	call	PRINT
	call	BLANK
	ld	de,PASS1_S
	call	PRINTLOG
	call	BLANKLOG

	ld	a,(TABLAS_SEG)	;Conecta 1er segmento de tablas en pag. 2
	call	PUT_S2
	ld	hl,#8000	;Limpia segmento de tablas
	ld	de,#8001
	ld	bc,#3FFF
	ld	(hl),0
	ldir

	ld	a,(CASE)
	ld	(ABSCASE),a

	ld	a,(FH_MAC)
	cp	-1
	jr	z,NO_MAC

	;--- Primero procesa las macros del fichero MAC, si hay

	ld	a,1
	call	PUT_S1
	call	READMAC	;Lee fichero de macros a pagina 1
	ld	a,MACCOPIA_SEG
	call	PUT_S2	;Lo copia a su segmento
	ld	hl,#4000
	ld	de,#8000
	ld	bc,#4000
	ldir
	ld	a,MACCOPIA_SEG	;Conecta ese segmento en pagina 1
	call	PUT_S1
	ld	a,EOF	;Para que detecte EOF aunque no haya
	ld	(#7FFF),a	;leido todo el fichero
	ld	a,-1
	ld	(SIESMACONO),a
	ld	a,(TABLAS_SEG)
	call	PUT_S2
	ld	ix,#4000	;Dir. inicial de lectura
	ld	iy,(GET_DEF_D)	;Dir. inicial de esc. (#8000 al princ.)
	call	GET_DEFINES
NO_MAC:	;

	;--- Ahora procesa las macros del fichero principal

	ld	hl,1
	ld	(PHLIN),hl
	ld	a,1
	call	PUT_S1
	call	READINF	;Lee las primeras 16K
	ld	a,(#4000)
	cp	#FF	;Error si "No es ASCII file"
	ld	de,FAT4_S
	jp	z,FATERR
	ld	a,INFCOPIA_SEG	;Crea copia de las primeras 16K
	call	PUT_S2	;de INFILE en su segmento
	ld	hl,#4000
	ld	de,#8000
	ld	bc,#4000
	ldir
	ld	a,INFCOPIA_SEG
	call	PUT_S1
	ld	a,EOF	;Para que detecte EOF aunque no haya
	ld	(#7FFF),a	;leido todo el fichero
	xor	a
	ld	(SIESMACONO),a
	ld	a,(TABLAS_SEG)
	call	PUT_S2
	ld	ix,#4000	;Dir. inicial de lectura
	ld	iy,(GET_DEF_D)	;Dir. inicial de esc. (#8000 al princ.)
	call	GET_DEFINES
	;ld      a,1
	;call    PUT_S1

	ld	hl,(NUMERR)
	ld	a,h
	or	l
	jr	nz,FGETDEF3
	ld	de,NOERR_S	;"No errors" en pantalla tras coger mac.
	call	PRINT
FGETDEF3:	call	BLANK
	ld	hl,(NUMERR)
	ld	(TOTERR),hl
	ld	hl,0
	ld	(NUMERR),hl
	jp	OK_GET_DEF

	;--- Rutina principal de proceso de macros

GET_DEFINES:	ld	(SAVESP),sp

	;--- BUCLE DE OBTENCION DE DEFINES
	;
	;Formato de la tabla de defines:
	;- 2 bytes indicando la direccion del siguiente define
	;    (0 indica fin de la tabla)
	;- Nombre del define, acabado en 0
	;- Direccion, en el texto, del cuerpo del define (#4000-#7FFF)

	xor	a
	ld	(PRMACRO),a
BUCGETDEF:	ld	a,(ix)	;Primer caracter de la linea:
	cp	EOF	;Si EOF -> fin del bucle
	jp	z,FGETDEF
	cp	13
	jp	z,NEXTLD
	inc	ix

NO13D:	cp	"@"	;Si no "@" -> proxima linea
	jp	nz,NEXTLD

	call	CHKRESV
	cp	2
	jp	z,FGETDEF	;Si es "endbasic" -> fin del bucle
	cp	1	;Si no es "define" -> prox. linea
	jp	nz,NEXTLD
	call	PASSPACE
	;ld      a,(ix)
	cp	13
	ld	de,INV4_S	;Si 1er caracter tras el @define es CR,
	call	z,GENERR	;error y siguiente linea
	jp	z,NEXTLD
	;inc     ix

	ld	a,-1	;PRMACRO=-1 (procesando macro)
	ld	(PRMACRO),a

	ld	(SAVEIY),iy
	push	iy
	pop	hl
	inc	hl
	inc	hl
	push	hl
	call	CHKRESV	;Error si es palabra reservada
	pop	hl
	ld	de,INV3_S
	or	a
	call	nz,GENERR
	jp	nz,NEXTLD
	call	GETNAME	;Copiamos el nombre a la tabla
	ld	(PRIMINV),a
	ld	(NAMEDIR),ix
	ex	de,hl
	ld	de,INV2_S
	call	c,GENERR	;Error si nombre demasiado largo
	jr	c,NEXTLD
	cp	EOF
	jp	z,FGETDEOF	;Fin si acaba en EOF
	call	CHKDUPD
	ld	de,INV5_S
	call	c,GENERR	;Error si nombre duplicado
	jr	c,NEXTLD
	ld	c,a
	ld	a,b
	or	a
	jr	nz,GETMAC0
	ld	de,INV4_S
	ld	a,(PRIMINV)
	call	CHKSPACE
	jr	z,GETMAC00
	cp	13
	jr	z,GETMAC00
	ld	de,INV1_S
GETMAC00:	call	GENERR
	jr	NEXTLD	;Error si no hay nombre de macro
GETMAC0:	ld	a,c
	cp	13
	ld	de,INV7_S	;Error si tras el nombre hay CR
	call	z,GENERR
	jr	z,NEXTLD
	cp	EOF
	jr	z,FGETDEF	;Si el primer caracter tras el nombre
	call	CHKSPACE	;no es espacio o tabulador,
	ld	de,INV1_S	;generamos error y pasamos a la
	call	nz,GENERR	;siguiente linea sin modificar IY
	jr	nz,NEXTLD

UNDEFMAS:	ld	de,(NUMDEFS)
	inc	de	;Un define mas.
	ld	(NUMDEFS),de
	inc	hl
	inc	hl
	ld	(iy),l	;Campo "dir. del siguiente"
	ld	(iy+1),h
	dec	hl
	dec	hl
	push	hl
	pop	iy
	ld	hl,(NAMEDIR)	;Campo "dir. en el texto"
	ld	a,(SIESMACONO)	;Si estamos procesando las macros,
	or	a
	jr	z,NOESMAC	;ponemos el bit 7 de la dir. a 1
	set	7,h
NOESMAC:	inc	hl
	ld	(iy),l
	inc	iy
	ld	(iy),h
	inc	iy

NEXTLD:	ld	a,(ix)	;Va pasando caracteres hasta el
	inc	ix	;fin de la linea
	cp	EOF
	jr	z,FGETDEF
	cp	13
	jr	nz,NEXTLD

	ld	a,(ix-2)	;Si CR, siguiente linea y sig. macro,
	cp	" "	;pero si " "+CR, solo sig. linea
	call	z,INCPHLIN
	jr	z,NEXTLD

	call	INCPHLIN
	xor	a
	ld	(PRMACRO),a
	ld	a,(ix)
	cp	10
	jp	nz,BUCGETDEF
	inc	ix
	jp	BUCGETDEF

FGETDEF:	ld	a,(PRMACRO)	;Ignoramos macro si encontramos EOF
	or	a	;en su cuerpo
	jr	z,FGETDF2
	ld	de,INV6_S
	call	GENERR
	ld	hl,(NUMDEFS)
	dec	hl
	ld	(NUMDEFS),hl
	ld	iy,(SAVEIY)

FGETDF2:	push	iy
	pop	hl
	ld	(GET_DEF_D),hl
	ld	(hl),0	;Marca de fin de tabla: sig. dir=0
	inc	hl
	ld	(hl),0
	inc	hl
	ld	(LINDIR),hl	;Dir. final

	;call    BLANK
	;call    BLANKLOG
	ld	de,(NUMDEFS)
	ld	hl,NUMDEF_S
	call	NUMTO2
	call	PUTCR
	;ld      de,PRODEF_S
	;call    PRINTLOG
	;call    PRINT

	;ld      hl,(NUMERR)
	;ld      (TOTERR),hl
	;ld      hl,0
	;ld      (NUMERR),hl

	ld	sp,(SAVESP)

	ret		;jp      BUILDLIN ;!!!

FGETDEOF:	ld	de,INV6_S	;Encontramos EOF en el nombre del macro
	call	GENERR
	xor	a
	ld	(PRMACRO),a
	jr	FGETDEF

INCPHLIN:	push	af,hl
	ld	a,(MACROIND)
	or	a
	jr	nz,NOINCPH
	ld	hl,(PHLIN)
	inc	hl
	ld	(PHLIN),hl
NOINCPH:	pop	hl,af
	ret
OK_GET_DEF:	;


;*******************************************************************
;*                                                                 *
;* CONSTRUYE LISTA DE ETIQUETAS DE LINEA, Y COMPONE FICHERO "LIN " *
;*                                                                 *
;*******************************************************************

BUILDLIN:	;ld      a,1              ;Recuperamos primeras 16K originales
	;call    PUT_S1           ;(sin el EOF en #7FFF)

	;call    BLANK
	ld	de,SRLIN_S
	call	PRINT
	call	BLANK
	ld	iy,(LINDIR)
	call	BLANKLIN

	ld	a,1
	call	PUT_S1
	ld	a,(TABLAS_SEG)
	call	PUT_S2

z3:	ld	iy,(LINDIR)
	ld	(iy),0
	ld	(iy+1),0
	ld	ix,#4000
	ld	a,NOPCODE
	ld	(INCCODE),a

	ld	a,-1
	ld	(NEWLINE),a
	xor	a
	ld	(REM),a
	ld	(BLOVERF),a
	ld	hl,1
	ld	(PHLIN),hl

	ld	hl,(FIRSTBL)
	ld	(BASLIN),hl
	ld	(ANTBL),hl
	ld	hl,(FIRSTBI)
	ld	(BASINC),hl

	ld	(SAVESP),sp

	;--- BUCLE DE OBTENCION DE ETIQUETAS

;* Algoritmo para cada linea fisica:
;1:EOF?
;   Si: FIN
;2:CR?
;   Si: Flag nueva linea ON
;       Siguiente linea fisica
;3:Espacio?
;   Si: Pasar espacios
;       FIN si EOF
;       4:CR?
;         Si: Flag nueva linea ON
;             Siguiente linea fisica
;       5:'?
;         6:Si: REM ON?
;             7:Si: Siguiente linea BASIC
;                   Siguiente linea fisica
;             8:No: ;Flag nueva linea ON
;                   Siguiente linea fisica
;       9:Flag nueva linea ON?
;          10:Si: Siguiente linea BASIC
;                 Siguiente linea fisica
;          11:No: Flag nueva linea OFF
;                 Siguiente linea fisica
;12:'?
;  13:Si: REM ON?
;      14:Si: Siguiente linea BASIC
;             Siguiente linea fisica
;      15:No: Flag nueva linea ON
;             Siguiente linea fisica
;16:@?
;  17:Si: Palabra reservada?
;         No: ir a 23
;      17A: @EndBasic?
;         18:Si: Fin
;      19:@Line?
;         20:Si: Extraer y establecer
;                Siguiente linea fisica
;      21:@Rem?
;         22:Si: Extraer y establecer
;                Siguiente linea fisica
;23:~?
;  24:Si: Extraer etiqueta = linea BASIC actual
;         Error fatal y FIN si se acaba la memoria
;         24A: Pasar espacios
;              Acaba en CR?
;              24B: Si: Siguiente linea fisica
;         24C: Acaba en "'"?
;              24D: Si: REM ON?
;                   24E: Si: Siguiente linea BASIC
;                            Siguiente linea fisica
;                   24F: No: Siguiente linea fisica
;         24G:Siguiente linea BASIC
;         Siguiente linea fisica
;25:Numero?
;  26:Si: Extraer etiqueta = linea BASIC actual
;         Error fatal y FIN si se acaba la memoria
;         Ir a 24A
;27:Siguiente linea BASIC
;Siguiente linea fisica

GL1:	ld	a,(ix)
	cp	EOF
	jp	z,FINGL

GL2:	cp	13
	jr	nz,GL3
	call	NL_ON
	jp	NEXTPL

GL3:	call	CHKSPACE
	jr	nz,GL12
	call	PASSPACE
	cp	EOF
	jp	z,FINGL

GL4:	cp	13
	jr	nz,GL5
	call	NL_ON
	jp	NEXTPL

GL5:	call	CHKREM
	jr	nz,GL9

GL6:	ld	a,(REM)
	or	a
	jr	z,GL8

GL7:	call	NEXTBL
	jp	NEXTPL

GL8:	;call    NL_ON
	jp	NEXTPL

GL9:	ld	a,(NEWLINE)	;FLAG_LN
	or	a
	jr	z,GL11

GL10:	call	NEXTBL
	jp	NEXTPL

GL11:	call	NL_OFF
	jp	NEXTPL

GL12:	call	CHKREM
	jr	nz,GL16

GL13:	ld	a,(REM)
	or	a
	jr	z,GL15

GL14:	call	NEXTBL
	jp	NEXTPL

GL15:	call	NL_ON
	jp	NEXTPL

GL16:	cp	"@"
	call	INCRIX
	jr	nz,GL23

GL17:	call	CHKRESV
	or	a
	call	z,NEXTBL
	jp	z,NEXTPL

GL17A:	cp	2
	jr	nz,GL19

GL18:	jp	FINGL

GL19:	cp	7
	jr	nz,GL21

GL20:	call	EXTLINE
	cp	1
	ld	de,INV8_S
	call	z,GENERR
	cp	2
	ld	de,INV9_S
	call	z,GENERR
	jp	NEXTPL

GL21:	cp	2
	call	z,NEXTBL
	jp	z,NEXTPL
	cp	3
	call	z,NEXTBL
	jp	z,NEXTPL
	cp	5
	jpmn	NEXTPL

GL22:	sub	6
	cpl
	ld	(REM),a
	jr	NEXTPL

GL23:	cp	"~"
	jr	nz,GL25

	ld	a,(ix)	;Esto es para que no generen error
	call	CHKSPACE	;los "~" sueltos
	jr	z,GL24A

GL24:	call	EXTL
GL24AA:	push	af
	ld	a,-1
	ld	(NEWLINE),a
	pop	af
	or	a
	jr	z,GL24AB
	cp	-1
	ld	de,FAT2_S
	jp	z,FATERR
	cp	1
	ld	de,INV10_S
	call	z,GENERR
	jr	z,GL24A
	cp	2
	ld	de,INV11_S
	call	z,GENERR
	jr	z,GL24A
	cp	3
	ld	de,INV12_S
	call	z,GENERR
	jr	z,GL24A
	cp	4
	ld	de,INV13_S
	call	z,GENERR
	jr	z,GL24A
GL24AB:	ld	de,(NUMLABS)
	inc	de
	ld	(NUMLABS),de

GL24A:	call	PASSPACE
	cp	13

GL24B:	jr	z,NEXTPL

GL24C:	call	CHKREM
	jr	nz,GL24E	;GL24G

GL24D:	ld	a,(REM)
	or	a
	jr	z,NEXTPL	;GL24F

GL24E:	call	NEXTBL
	jr	NEXTPL

GL25:	ld	hl,"90"
	call	RANGE
	jr	nz,GL27

GL26:	call	EXTLN
	jr	GL24AA

GL27:	call	NEXTBL
	;jr      NEXTPL

NEXTPL:	call	_NEXTPL
	jp	nc,FINGL
	jp	GL1

_NEXTPL:	ld	a,(ix)	;Pasa a la siguiente linea fisica.
	call	INCRIX
	cp	EOF
	ret	z	;jp      z,FINGL
	cp	13
	jr	nz,_NEXTPL

	ld	a,(ix-2)
	cp	" "
	call	z,INCPHLIN
	jr	z,_NEXTPL

	call	INCPHLIN
	ld	a,(ix)
	cp	10
	scf
	ret	nz
	call	INCRIX
	scf
	ret

;--- Subrutinas del bucle de extraccion de etiquetas de linea

NL_ON:	ret
	;push    af
	;ld      a,-1
	;ld      (NEWLINE),a
	;pop     af
	;ret

NL_OFF:	push	af
	xor	a
	ld	(NEWLINE),a
	pop	af
	ret

NEXTBL:	push	af
	call	_NEXTBL
	pop	af
	ret

_NEXTBL:	ld	a,(BLOVERF)
	or	a
	ld	de,FAT1_S
	jp	nz,FATERR

	xor	a
	ld	(NEWLINE),a

	ld	hl,(NUMBASLIN)
	inc	hl
	ld	(NUMBASLIN),hl
	ld	hl,(BASLIN)
	ld	(ANTBL),hl
	ld	de,(BASINC)
	add	hl,de
	ld	(BASLIN),hl	;Si hay desbordamiento de num. de linea,
	ret	nc	;la rutina EXTL o EXTLN lo detectara
	ld	a,-1	;y generara error fatal.
	ld	(BLOVERF),a
	ret


;--- EXTL: Extrae nombre de etiqueta y lo guarda con su num. de linea
;             a partir de IY.
;          Si no cabe, conecta el segmento siguiente.
;          Si no quedan segmentos, devuelve A=-1.
;          Si encuentra un caracter invalido que no sea ":", devuelve A=1.
;          Si encuentra un caracter no numerico en EXTLN, devuelve A=3.
;          Si el nombre es demasiado largo, devuelve A=2.
;          Si el nombre ya estaba en la tabla, devuelve A=4.
;          Si no, devuelve A=0.
;          Devuelve IX tras el nombre (usa INCRIX)

EXTLN:	dec	ix
	ld	a,-1	;Ponemos NUMFLAG=-1 para que la rutina
	ld	(NUMFLAG),a	;GETNAME detecte como invalido
	call	EXTL	;cualquier caracter que no sea
	push	af	;un numero.
	xor	a
	ld	(NUMFLAG),a
	pop	af
	ret

EXTL:	ld	hl,DTABUF
	call	GETNAME
	ld	c,a
	ld	a,2
	ret	c

	ld	a,c	;Error 1 o 3 si no termina con
	cp	":"	;":" o espacio o tab.
	call	z,INCRIX	;!!!
	jr	z,EXTL2
	call	CHKSPACE
	jr	z,EXTL2
	cp	13
	jr	z,EXTL2
	ld	a,(NUMFLAG)	;Error 3 si NUMFLAG=3
	cp	3	;(llamada a EXTLN y caracter valido
	ret	z	;pero no numerico encontrado)
	ld	a,1
	ret

EXTL2:	call	CHKDUPL	;Comprueba si esta duplicado
	ld	a,4
	ret	c

	ld	(SAVEIY),iy
	ld	a,-1
	ld	(iy),a
	inc	iy	;En principio, dir. sig. =-1
	ld	(iy),a	;(por si no cabe en este segmento)
	call	INCRIY2
	jr	c,NEXTSEGL
	ld	hl,DTABUF
BUCEXTL:	ld	a,(hl)
	call	MAYCASE
	ld	(iy),a
	ld	c,a
	inc	hl
	call	INCRIY2
	jr	c,NEXTSEGL
	ld	a,c
	or	a
	jr	z,FBEXTL
	jr	BUCEXTL

FBEXTL:	ld	hl,(BASLIN)	;Tras el nombre+0, num. linea BASIC
	ld	(iy),l
	call	INCRIY2
	jr	c,NEXTSEGL
	ld	(iy),h
	call	INCRIY2
	jr	c,NEXTSEGL

	push	iy
	pop	hl
	ld	iy,(SAVEIY)	;Tras num. l. BASIC, han de quedar
	ld	(iy),l	;al menos dos bytes libres
	inc	iy	;para la proxima dir. (o -1)
	jr	c,NEXTSEGL
	ld	(iy),h
	push	hl
	pop	iy
	call	INCRIY2
	jr	c,NEXTSEGL
	call	INCRIY2
	jr	c,NEXTSEGL
	dec	iy
	dec	iy

	xor	a
	ret

NEXTSEGL:	ld	a,(SEG_P2)	;Si se llega al final del segmento,
	ld	hl,NUMSEGS	;se conecta el siguiente y vuelta a
	inc	a	;empezar con el almacenamiento del
	cp	(hl)	;nombre.
	jrmy	OUTSEGL
	call	PUT_S2
	ld	hl,#8000
	ld	de,#8001
	ld	bc,#3FFF
	ld	(hl),0
	ldir
	ld	iy,#8000
	jp	EXTL2

OUTSEGL:	ld	a,-1	;Error si no quedan segmentos
	ret


;--- EXTLINE: Extrae nuevo numero de linea y/o incremento a (BASLIN) y (BASINC)
;             Devuelve A=1 si un parametro es incorrecto.
;             Devuelve A=2 si se intenta establecer un no. inferior al actual.

EXTLINE:	ld	hl,(BASLIN)
	ld	(OLDBL),hl
	ld	hl,(BASINC)
	ld	(OLDBI),hl

	call	PASSPACE
	cp	13
	jr	z,RETA1
	cp	","
	call	z,INCRIX
	jr	z,EXTINC

	call	EXTNUM3
	jr	c,RETA1	;Error si num. >65535
	push	bc
	pop	hl
	ld	(BASLIN),hl
	call	PASSPACE
	cp	","
	call	z,INCRIX
	jr	z,EXTINC
	cp	13
	jr	z,RETA0	;Error si tras el numero no hay
	call	CHKSPACE	;espacio, tab, CR o ","
	jr	z,EXTINC
	jr	RETA1

EXTINC:	call	PASSPACE
	call	EXTNUM3
	jr	c,RETA1
	ld	a,b	;Error si el incremento es 0
	or	c
	jr	z,RETA1
	push	bc
	pop	hl
	ld	(BASINC),hl
	call	PASSPACE
	cp	13
	jr	nz,RETA1

RETA0:	ld	hl,(BASLIN)	;Error si nuevo numero < antiguo
	ld	de,(OLDBL)
	call	COMPDEHL
	jrmn	RETA2
	xor	a
	ret

RETA1:	ld	a,1
	jr	RETA12
RETA2:	ld	a,2
RETA12:	ld	hl,(OLDBL)	;Si hay error, restauramos
	ld	(BASLIN),hl	;los valores antiguos
	ld	hl,(OLDBI)
	ld	(BASINC),hl
	ret

	;--- Fin de la extraccion de etiquetas

FINGL:	ld	sp,(SAVESP)

	ld	hl,(NUMERR)
	ld	a,h
	or	l
	jr	nz,FGL0
	ld	de,NOERR_S
	call	PRINT

FGL0:	ld	hl,(NUMERR)
	ld	de,(TOTERR)
	add	hl,de
	ld	(TOTERR),hl
	ld	hl,0
	ld	(NUMERR),hl

FINGL2:	;call    BLANKLOG
	ld	hl,(TOTERR)
	ld	a,h
	or	l
	jr	nz,FINGL3
	ld	de,NOERR_S
	call	PRINTLOG
	call	BLANKLOG

FINGL3:	call	BLANK

	ld	de,(TOTERR)	;"Total errors on pass 1"
	ld	a,d	;solo si hay errores
	or	e
	jr	z,FINGL4
	call	BLANKLOG
	ld	de,(TOTERR)
	ld	hl,NE1_S
	ld	b,5
	ld	c," "
	xor	a
	call	NUMTO2
	call	PUTCR
	ld	de,NUME1_S
	call	PRINTLOG
	call	BLANKLOG
	call	BLANKLIN
	;ld      de,PASS2_S
	;call    PRINTLOG

FINGL4:	ld	de,PRODEF_S	;"Number of macros"
	call	PRINTLOG
	call	PRINT

	ld	de,(NUMLABS)	;"Number of labels"
	ld	hl,NUMLIN_S
	call	NUMTO2
	call	PUTCR
	ld	de,PROLIN_S
	call	PRINTLOG
	call	PRINTLIN
	call	PRINT

	ld	de,(NUMBASLIN)
	ld	hl,NUMBL_S
	ld	b,5
	ld	c," "
	xor	a
	call	NUMTO2
	call	PUTCR
	ld	de,PROBL_S
	call	PRINTLOG
	call	PRINTLIN
	call	PRINT

	call	BLANKLOG
	call	BLANKLIN
	ld	de,PASS2_S	;"---PASS 2"
	call	PRINTLOG
	call	BLANKLOG

	;ld      hl,(NUMERR)
	;ld      (TOTERR),hl
	ld	hl,0
	ld	(NUMERR),hl

	;--- Crea fichero LIN

	ld	a,(FH_LIN)
	cp	-1
	jr	z,FMAKELIN
	ld	hl,(NUMLABS)
	ld	a,h
	or	l
	jr	z,FMAKELIN

	call	BLANKLIN
	ld	de,MATCH_S
	call	PRINTLIN
	call	BLANKLIN

	ld	a,(TABLAS_SEG)
	call	PUT_S2
	ld	iy,(LINDIR)

BUCMKLIN:	ld	l,(iy)	;Fin si hemos encontrado #0000
	ld	h,(iy+1)
	inc	iy
	inc	iy
	ld	a,h
	or	l
	jr	z,FMAKELIN

	inc	hl
	ld	a,h	;-1 -> Conectar siguiente segmento
	or	l
	ld	hl,DTABUF
	jr	nz,BUCMKL2

	ld	a,(SEG_P2)
	inc	a
	call	PUT_S2
	ld	iy,#8000
	ld	hl,DTABUF

BUCMKL2:	ld	a,(iy)	;Extrae el nombre a DTABUF,
	ld	(hl),a	;acabado en tabulador
	inc	hl
	inc	iy
	or	a
	jr	nz,BUCMKL2
	dec	hl
	ld	a,TAB
	ld	(hl),a
	inc	hl

	ld	e,(iy)
	ld	d,(iy+1)
	inc	iy
	inc	iy
	call	NUMTO2
	call	PUTCR

	ld	de,DTABUF
	call	PRINTLIN
	jr	BUCMKLIN

FMAKELIN:	;


;************************************************
;*                                              *
;* AL GRANO: CONSTRUCCION DEL FICHERO DE SALIDA *
;*                                              *
;************************************************

	ld	a,2
	call	PUT_S2

	ld	hl,0
	ld	(NUMERR),hl

	call	BLANK
	ld	de,PAR_S
	call	PRINT
	call	BLANK

	call	REBOBI	;Volvemos al principio del fichero
	call	READINF	;de entrada y leemos 16K

	ld	ix,#4000
	ld	iy,#8000

	ld	hl,1
	ld	(PHLIN),hl
	ld	hl,(FIRSTBL)
	ld	(BASLIN),hl
	ld	(ANTBL),hl
	ld	hl,(FIRSTBI)
	ld	(BASINC),hl

	ld	(SAVESP),sp

	ld	a,-1
	ld	(NEWLINE),a
	ld	(PRIMVEZ),a

	xor	a
	ld	(REM),a
	ld	(SPAZ),a
	ld	(BLOVERF),a
	ld	(NUMFLAG),a


;BUCLE DE PROCESO DE LINEAS: igual al bucle de obtencion de etiquetas,
;con estas diferencias:
;- En vez de "pasar a siguiente linea fisica", hay que "procesar linea"
;  (llamada a PARSE o a IGLIN)
;- Al hacer "siguiente linea fisica", hay que insertar el numero de linea
;  en el fichero de salida
;- Las etiquetas no se extraen (EXTL), sino que simplemente se ignoran
;- Tras pasar una etiqueta, hay que comprobar que hay detras.
;  Si solo hay espacios, o CR, o REM ignorable, no se pone nuevo numero de
;  linea BASIC

PR1:	ld	a,(ix)
	;ld      (PRIMCH),a
	cp	EOF
	jp	z,FINPR

PR2:	cp	13
	jr	nz,PR3
	;ld      a,-1
	;ld      (BGENTER),a

	call	NL_ON
	jp	IGLIN

PR3:	call	CHKSPACE
	jr	nz,PR12
	call	PASSPACE
	cp	EOF
	jp	z,FINPR

PR4:	cp	13
	jr	nz,PR5
	call	NL_ON
	jp	IGLIN

PR5:	call	CHKREM
	jr	nz,PR9

PR6:	ld	a,(REM)
	or	a
	jr	z,PR8

PR7:	call	NEXTBL2
	jp	PARSED

PR8:	;call    NL_ON
	jp	IGLIN

PR9:	ld	a,(NEWLINE)
	or	a
	jr	z,PR11

PR10:	call	NEXTBL2
	jp	PARSE

PR11:	call	NL_OFF
	jp	PARSE

PR12:	call	CHKREM
	jr	nz,PR16

PR13:	ld	a,(REM)
	or	a
	jr	z,PR15

PR14:	call	NEXTBL2
	jp	PARSE

PR15:	call	NL_ON
	jp	IGLIN

PR16:	push	af
	xor	a
	ld	(COMILL),a
	pop	af
	cp	"@"
	jr	nz,PR23
	call	INCRIX

PR17:	call	CHKRESV
	or	a
	call	z,NEXTBL2
	jp	z,PARSED

PR17A:	cp	2
	jr	nz,PR19

PR18:	jp	FINPR

PR19:	cp	7
	jr	nz,PR21

PR20:	call	EXTLINE
	;cp      1
	;ld      de,INV8_S
	;call    z,GENERR
	;cp      2
	;ld      de,INV9_S
	;call    z,GENERR
	jp	IGLIN

PR21:	cp	3
	call	z,SETSPON
	jp	z,PR1	;PARSE
	cp	4
	call	z,SETSPOFF
	jp	z,PARSE
	cp	1
	jp	z,IGLIN

PR22:	sub	6
	cpl
	ld	(REM),a
	jp	IGLIN

PR23:	cp	"~"
	jr	nz,PR25

	ld	a,(ix)	;Esto es para que no generen error
	call	CHKSPACE	;los "~" sueltos
	jr	z,PR24A

PR24:	call	PASSL
PR24AA:	ld	a,-1	;jr      PR24AB
	ld	(NEWLINE),a

	;cp      -1
	;ld      de,FAT2_S
	;jp      z,FATERR
	;cp      1
	;ld      de,INV10_S
	;call    z,GENERR
	;jr      z,PR24A
	;cp      2
	;ld      de,INV11_S
	;call    z,GENERR
	;jr      z,PR24A
	;cp      3
	;ld      de,INV12_S
	;call    z,GENERR
	;jr      z,PR24A
	;cp      4
	;ld      de,INV13_S
	;call    z,GENERR
	;jr      z,PR24A
PR24AB:	;ld      de,(NUMLABS)
	;inc     de
	;ld      (NUMLABS),de

PR24A:	call	PASSPACE
	cp	13

PR24B:	jp	z,IGLIN

PR24C:	call	CHKREM
	jr	nz,PR24E	;PR24G

PR24D:	ld	a,(REM)
	or	a
	jp	z,IGLIN	;PR24F

PR24E:	call	NEXTBL2
	jp	PARSE

PR25:	ld	hl,"90"
	call	RANGE
	jr	nz,PR27

PR26:	call	PASSL
	jr	PR24AA

PR27:	call	NEXTBL2
	jp	PARSE	;PARSED

FINPR:	ld	sp,(SAVESP)

	ld	de,#8000
	or	a
	push	iy
	pop	hl
	sbc	hl,de
	;inc     hl
	push	hl
	pop	bc
	ld	hl,#8000
	ld	a,(FH_OUT)
	call	WRITE

	ld	de,(NUMERR)
	ld	a,d
	or	e
	jr	nz,FINPR1

	ld	de,NOERR_S
	call	PRINTLOG
	call	PRINT

FINPR1:	ld	de,(NUMERR)	;"Total errors on pass 2"
	ld	a,d	;solo si hay errores
	or	e
	jr	z,FINPR4
	call	BLANKLOG
	ld	de,(NUMERR)
	ld	hl,NE2_S
	ld	b,5
	ld	c," "
	xor	a
	call	NUMTO2
	call	PUTCR
	ld	de,NUME2_S
	call	PRINTLOG
	;call    BLANKLOG
	call	BLANKLIN

FINPR4:	;call    BLANK

FINPR34:	;call    BLANK
	;ld      de,DONE_S
	;call    PRINT

	call	BLANK
	call	BLANKLOG
	ld	de,FNSH_S
	call	PRINT
	call	BLANK
	ld	de,MENOS_S
	call	PRINTLOG
	call	BLANKLOG
	ld	hl,(TOTERR)
	ld	de,(NUMERR)
	add	hl,de
	ld	(TOTERR),hl

	ld	a,h
	or	l
	jr	nz,PRTOTERR

	ld	de,NOEF_S
	call	PRINTLOG
	call	PRINT	;"No errors were found", o bien...
	jr	BOOTONO

PRTOTERR:	ld	de,(TOTERR)	;..."total errors found"
	ld	hl,NET_S
	ld	b,5
	ld	c," "
	xor	a
	call	NUMTO2
	call	PUTCR
	ld	de,NUMET_S
	call	PRINTLOG
	call	PRINT

;--- Ejecuta programa generado, si B=1 y no hubo errores

BOOTONO:	call	BLANK
	ld	a,(BOOT)
	or	a
	jr	nz,SIBOOT

	ld	de,DONE_S
	call	PRINT
	jp	FIN

SIBOOT:	ld	hl,(NUMERR)
	ld	a,h
	or	l
	jr	z,PUEDEBOOT

	ld	de,NOPUB_S
	call	PRINT
	jp	FIN

PUEDEBOOT:	ld	de,PUB_S
	call	PRINT

	di
	ld	hl,KEYBUF
	ld	(GETPNT),hl
	ld	hl,BASIC_S
	ld	de,KEYBUF
	ld	bc,6
	ldir
	ld	bc,6
	ld	hl,OUTFILE
BUCBOOT:	ld	a,(hl)
	ld	(de),a
	inc	bc
	cp	13
	jr	z,FBBOOT
	inc	hl
	inc	de
	jr	BUCBOOT
FBBOOT:	ld	hl,(GETPNT)
	add	hl,bc
	ld	(PUTPNT),hl
	ei

	jp	FIN

;--- Subrutinas

NEXTBL2:	push	af,bc,de,hl
	call	_NEXTBL2
	pop	hl,de,bc,af
	ret

_NEXTBL2:	ld	a,(BLOVERF)
	or	a
	ld	de,FAT1_S
	jp	nz,FATERR

	xor	a
	ld	(NEWLINE),a

	ld	a,(PRIMVEZ)
	or	a
	ld	a,0
	ld	(PRIMVEZ),a
	jr	nz,NBL22

	ld	a,13
	ld	(iy),a
	call	INCRIY
	;call    INCRIX
	ld	a,10
	ld	(iy),a
	call	INCRIY

NBL22:	ld	hl,BLBUF	;Imprime num. de linea
	ld	de,BLBUF+1	;en el fichero de salida
	ld	bc,7
	ld	(hl),0
	ldir
	ld	de,(BASLIN)
	ld	hl,BLBUF
	call	NUMTO2
	ld	hl,BLBUF
BUCNBL21:	ld	a,(hl)
	or	a
	jr	z,FBNBL1
	ld	(iy),a
	inc	hl
	call	INCRIY
	jr	BUCNBL21
FBNBL1:	ld	a," "
	ld	(iy),a
	call	INCRIY

	ld	hl,(NUMBASLIN)
	inc	hl
	ld	(NUMBASLIN),hl
	ld	hl,(BASLIN)
	ld	(ANTBL),hl
	ld	de,(BASINC)
	add	hl,de
	ld	(BASLIN),hl	;Si hay desbordamiento de num. de linea,
	ret	nc	;la rutina EXTL o EXTLN lo detectara
	ld	a,-1	;y generara error fatal.
	ld	(BLOVERF),a
	ret

PASSL:	ld	hl,DTABUF
	call	GETNAME	;Ignora etiqueta: pasa hasta
	ld	a,(ix)	;encontrar caracter invalido
	cp	":"
	jr	nz,PASSL2
	call	INCRIX
PASSL2:	call	PASSPACE
	ret

SETSPON:	push	af
	ld	a,-1
	ld	(SPAZ),a
	ld	a,(ix)
	cp	":"
	jr	nz,FSPON
	call	INCRIX
FSPON:	pop	af
	ret

SETSPOFF:	push	af
	xor	a
	ld	(SPAZ),a
	ld	a,(ix)
	cp	":"
	jr	nz,FSPOFF
	call	INCRIX
FSPOFF:	pop	af
	ret


;--- SUBRUTINA DE PROCESO DE UNA LINEA

IGLIN:	ld	a,(MACROIND)
	or	a
	jr	z,IGLIN1
	call	_NEXTPL
	jp	nc,FINPR
	call	POPMAC
	dec	ix
	jp	PS1

IGLIN1:	call	_NEXTPL	;Ignorar linea
	jp	nc,FINPR
	jp	PR1

IGLIN2:	ld	a,13
	ld	(iy),a
	call	INCRIY
	ld	a,10
	ld	(iy),a
	call	INCRIY
	jr	IGLIN

PARSED:	dec	ix
PARSE:	call	PASSPACE
	dec	ix
	;push    af
	;xor     a
	;ld      (BGENTER),a
	;pop     af

;- Al llamar a PARSE, IX ya apunta a despues de "@algo" si era un comando,
;  o despues de "~algo". Por tanto, si se encuentra un comando que no sea
;  @spaceon o @spaceoff hay que generar error; si se encuentra "~algo"
;  hay que convertirlo a su numero de linea.
;- Los espacios iniciales se saltan aunque SPACE este a ON.

;Algoritmo de PARSE:

;Inicialmente, saltar espacios
;1: Coger caracter
;1A: Si COMILL ON y no son otras comillas, copiar tal cual y saltar a 1
;   2: Es "'"?
;      2A: Si: REM on?
;         3: Si: Copiar tal cual hasta el final de la linea
;         4: No: Ignorar hasta el final de la linea
;   5: Es "@"?
;      6: Si: Es palabra reservada?
;         6A: No: Obtener su direccion (error si no esta en la lista)
;                 Actualizar la pila de macros
;                 Establecer la nueva direccion
;                 Pasar espacios iniciales
;                 Saltar a 1
;         7: Si: Es SPCON?
;                8: Si: Poner SPAZ a ON y saltar a 1
;                9: No: Es SPCOFF?
;                   10: Si: Poner SPAZ a OFF y saltar a 1
;                   11: No: Generar error y saltar a 1
;   50: Es comillas?
;       51: Si: Complementar COMILL
;               Saltar a 1
;   52: Es espacio?
;       53: Si: SPACE ON?
;               54: Si: Poner espacio
;                       Saltar a 1
;               55: No: Saltar a 1
;   56: Es "~"?
;       57: Si: Adquirir su numero asociado y ponerlo. Si no existe, error.
;               Saltar a 1.
;   58: Es numero?
;       59: Tiene una instruccion de salto antes?
;           Si: es etiqueta. Saltar a 57.
;   60: Es CR?
;       61: Si: Antes hay un espacio?
;           62: Si: Pasar el CR y el LF posterior
;                   Saltar a 1
;           63: No: Restaurar pila de macros
;                   Poner COMILL a 0
;                   Saltar a PR1
;   80: Es caracter normal.
;       Copiarlo en mayusculas, y saltar a 1

PS1:	call	INCRIX
	ld	a,(ix)
	cp	EOF
	jp	z,FINPR

	ld	a,(COMILL)
	cp	-1
	ld	a,(ix)
	jr	nz,PS2
	cp	13
	jr	z,PS2
	cp	34
	jr	z,PS2
	ld	(iy),a
	call	INCRIY
	jr	PS1

PS2:	call	CHKREM
	jr	nz,PS5

PS2A:	ld	a,(REM)
	or	a
PS4:	jr	z,IGLIN
PS3:	;ld      a,"'"
	;ld      (iy),a
	;call    INCRIY
	jp	COPYLIN

PS5:	cp	"@"
	jr	nz,PS50
	call	INCRIX

PS6:	call	CHKRESV
	or	a
	jr	nz,PS7

PS6A:	call	GETMDIR
	ld	(MACDIR),hl
	res	7,h
	ld	de,PRE1_S
	dec	ix
	call	c,GENERR
	jr	c,PS1
	inc	ix
	push	hl
	call	PUSHMAC
	pop	hl
	ld	de,FAT3_S
	jp	c,FATERR
	push	hl
	pop	ix
	dec	ix
	dec	ix
	call	PASSPACE
	jr	PS1

PS7:	cp	4
	jr	nz,PS9

PS8:	call	SETSPOFF
	dec	ix
	jr	PS1

PS9:	cp	3
	ld	de,PRE2_S
PS11:	call	nz,GENERR
	dec	ix
	jp	nz,PS1
	inc	ix

PS10:	call	SETSPON
	dec	ix
	jp	PS1

PS50:	cp	34
	jr	nz,PS52

PS51:	ld	(iy),a
	call	INCRIY
	ld	a,(COMILL)
	cpl
	ld	(COMILL),a
	jp	PS1

PS52:	call	CHKSPACE
	jr	nz,PS56

PS53:	ld	a,(SPAZ)
	or	a
	jr	z,PS55

PS54:	ld	a,(ix)
	ld	(iy),a
	call	INCRIY
	jp	PS1

PS55:	jp	PS1

PS56:	cp	"~"
	jr	nz,PS58

	call	INCRIX	;Linea actual si es "~~"
	ld	a,(ix)
	dec	ix
	cp	"~"
	jr	nz,PS57
	inc	ix
	inc	ix
	ld	hl,(ANTBL)
	xor	a
	jr	PS57A

PS57:	call	GETLNUM
PS57A:	ld	a,0
	ld	(NUMFLAG),a
	ld	de,PRE3_S
	call	c,GENERR
	ex	de,hl
	call	nc,PUTNUM
	dec	ix
	jp	PS1

PS58:	ld	hl,"90"
	call	RANGE
	jr	nz,PS60

PS59:	call	CHKJMP
	jr	nc,PS60
	ld	a,-1
	ld	(NUMFLAG),a
	jr	PS57

PS60:	cp	13
	jr	nz,PS80
	call	INCPHLIN

PS61:	ld	a,(ix-1)
	cp	" "
	jr	nz,PS63

PS62:	call	INCRIX
	ld	a,(ix)
	cp	10
	dec	ix
	jp	nz,PS1
	inc	ix
	ld	(ix),a
	jp	PS1

PS63:	ld	a,(MACROIND)
	or	a
	jr	z,PS63B
	call	POPMAC
	dec	ix
	jp	PS1

PS63B:	;ld      a,(BGENTER)
	;or      a
	;jr      nz,PS63C
	;ld      a,13
	;ld      (iy),a
	;call    INCRIY
	call	INCRIX
	;ld      a,10
	;ld      (iy),a
	;call    INCRIY
PS63C:	ld	a,(ix)
	cp	10
	jr	nz,PS63A
	call	INCRIX
PS63A:	;call    POPMAC
	;xor     a
	;ld      (COMILL),a
	jp	PR1	;NO PS1

PS80:	call	MAY
	ld	(iy),a
	call	INCRIY
	jp	PS1


;--- SUBRUTINAS DE PARSE ---

;--- COPYLIN: Copia la linea tal cual hasta encontrar un CR
;             En ese momento salta a PS1

COPYLIN:	ld	a,(ix)
	call	INCRIX
	cp	13
	jr	z,CPLIN2
	ld	(iy),a
	call	INCRIY
	jr	COPYLIN

CPLIN2:	call	INCPHLIN
	;ld      (iy),a
	;call    INCRIY
	ld	a,(ix)
	cp	10
	jp	nz,PR1
	;ld      (iy),a
	call	INCRIX
	;call    INCRIY
	jp	PR1


;--- GETMDIR: Devuelve en HL la direccion de la macro (IX+1)
;             Devuelve Cy=1 si la macro no existe

GETMDIR:	ld	a,(TABLAS_SEG)
	call	PUT_S2
	call	_GETMDIR
	push	af,hl
	ld	a,2
	call	PUT_S2
	pop	hl,af
	ret

_GETMDIR:	;call    INCRIX
	ld	hl,DTABUF
	call	GETNAME	;Nombre en #C000

	ld	hl,#8000
BUCGMD:	ld	c,(hl)	;BC = Dir. siguiente
	inc	hl
	ld	b,(hl)
	inc	hl
	ld	a,b	;Si es 0 -> error y fin
	or	c
	scf
	ret	z
	ld	de,DTABUF

BUCGMD2:	ld	a,(de)	;Compara nombres
	call	MAYCASE
	cp	(hl)
	inc	hl
	inc	de
	jr	nz,NEXTMD
	or	a
	jr	nz,BUCGMD2

	ld	e,(hl)	;Encontrado -> dir. en HL y fin
	inc	hl
	ld	d,(hl)
	ex	de,hl
	or	a
	ret

NEXTMD:	push	bc	;No coincide -> siguiente
	pop	hl
	jr	BUCGMD


;--- GETLNUM: Devuelve en HL el numero de linea de la etiqueta (IX)
;             Salta el primer "~" si es necesario
;             Devuelve Cy=1 si la etiqueta no existe

GETLNUM:	ld	a,(TABLAS_SEG)
	call	PUT_S2
	call	_GETLNUM
	push	af,hl
	ld	a,2
	call	PUT_S2
	pop	hl,af
	ret

_GETLNUM:	ld	a,(ix)
	cp	"~"
	call	z,INCRIX
	ld	hl,DTABUF
	call	GETNAME	;Nombre en #C000

	ld	hl,(LINDIR)
BUCGLN:	ld	c,(hl)	;BC = Dir. siguiente
	inc	hl
	ld	b,(hl)
	inc	hl
	ld	a,b	;Si es 0 -> error y fin
	or	c
	scf
	ret	z

	inc	bc	;Si es -1 -> siguiente segmento
	ld	a,b
	or	c
	jr	nz,NONXSEG
	ld	a,(SEG_P2)
	inc	a
	push	bc
	call	PUT_S2
	pop	bc
	ld	hl,#8000
NONXSEG:	dec	bc
	ld	de,DTABUF

BUCGLN2:	ld	a,(de)	;Compara nombres
	call	MAYCASE
	cp	(hl)
	inc	hl
	inc	de
	jr	nz,NEXLN
	or	a
	jr	nz,BUCGLN2

	ld	e,(hl)	;Encontrado -> num. en HL y fin
	inc	hl
	ld	d,(hl)
	ex	de,hl
	or	a
	ret

NEXLN:	push	bc	;No coincide -> siguiente
	pop	hl
	jr	BUCGLN


;--- PUSHMAC: Guarda IX en la pila de macros, e incrementa MACROIND
;             Conecta el segmento de macros (MAC o INF segun MACDIR)
;             Si es una macro del fichero MAC (segun MACDIR), guarda IX
;             con el bit mas alto a 1
;             Devuelve Cy=1 si hay desbordamiento de pila de macros

PUSHMAC:	ld	a,(MACROIND)
	cp	127	;Desbordamiento?
	scf
	ret	z
	inc	a
	ld	(MACROIND),a

	ld	a,(SEG_P1)
	cp	MACCOPIA_SEG
	jr	nz,PUSH_NOMAC
	ld	a,ixh
	set	7,a
	ld	ixh,a

PUSH_NOMAC:	ld	hl,(MACROPNT)	;Incrementa puntero
	ld	a,ixl
	ld	(hl),a
	inc	hl
	ld	a,ixh
	ld	(hl),a
	inc	hl
	ld	(MACROPNT),hl

	ld	a,(MACDIR+1)	;Conecta segmento MACCOPIA_SEG si
	bit	7,a	;la dir. de la macro tiene el bit 7 a 1,
	ld	a,MACCOPIA_SEG	;si no, conecta INFCOPIA_SEG
	jr	nz,PUSH_ESMAC
	ld	a,INFCOPIA_SEG
PUSH_ESMAC:	call	PUT_S1
	or	a
	ret


;--- POPMAC:  Recupera IX de la pila de macros, y decrementa MACROPNT
;             Recupera el segmento normal si MACROPNT llega a 0
;             Conecta el segmento adecuado segun el bit 7 del IX recuperado
;             No hace nada si MACROPNT esta a 0 al principio

POPMAC:	ld	(SAVEA),a
	call	_POPMAC
	ld	a,(SAVEA)
	ret

_POPMAC:	ld	a,(MACROIND)
	or	a
	ret	z

	ld	a,(MACROIND)
	dec	a
	ld	(MACROIND),a
	or	a
	ld	a,1
	call	z,PUT_S1

	ld	a,NOPCODE
	ld	(INCCODE),a

POPMAC2:	ld	hl,(MACROPNT)
	dec	hl
	ld	a,(hl)
	ld	ixh,a
	dec	hl
	ld	a,(hl)
	ld	ixl,a
	;dec     hl
	ld	(MACROPNT),hl

	ld	a,(MACROIND)
	or	a
	jr	z,FINPOPMAC

	ld	a,ixh
	bit	7,a
	ld	a,MACCOPIA_SEG
	jr	nz,NOESMACPOP
	ld	a,INFCOPIA_SEG
NOESMACPOP:	ld	b,a
	ld	a,(SEG_P1)
	cp	b
	ld	a,b
	call	nz,PUT_S1
FINPOPMAC:	ld	a,ixh
	res	7,a
	ld	ixh,a
	ret


;--- CHKJMP:  Comprueba si antes de (IX) hay una instruccion de salto,
;             en ese caso devuelve Cy=1

CHKJMP:	ld	(SAVEA),a
	call	_CHKJMP
	ld	a,(SAVEA)
	ret

_CHKJMP:	ld	hl,JMPITAB
	push	ix
	pop	de
	dec	de

BUCCH0:	ld	a,(de)
	call	CHKSPACE
	jr	nz,BUCCH1
	dec	de
	jr	BUCCH0

BUCCH1:	ld	(SAVEDE),de
BUCCHJ:	ld	a,(de)
	call	MAY
	cp	(hl)
	jr	nz,NXBCHJ
	ld	a,(hl)
	or	a
	scf
	ret	z
	inc	hl
	dec	de
	jr	BUCCHJ

NXBCHJ:	;inc     hl
	ld	a,(hl)
	or	a
	scf
	ret	z
	ld	de,(SAVEDE)
NBCHJ2:	ld	a,(hl)
	inc	hl
	or	a
	jr	nz,NBCHJ2

	ld	a,(hl)
	or	a
	ret	z
	;inc     hl
	jr	BUCCHJ

SAVEDE:	dw	0


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


;--- Comparacion de DE y HL
;    HL hace las veces de A
;    Modifica A

COMPDEHL:	ld	a,h
	sub	d
	ret	nz
	ld	a,l
	sub	e
	ret


;--- EXTNUM3: Llama a EXTNUM2, y establece IX tras el numero, con INCRIX.

EXTNUM3:	call	EXTNUM2
	push	af,bc
	ld	a,d
	or	a
	jr	z,RETPOPBA
	ld	b,a
BUCEXTN3:	call	INCRIX
	djnz	BUCEXTN3
RETPOPBA:	pop	bc,af
	ret


;--- EXTNUM2: Copia el numero de IX al bufer DTABUF usando INCRIX,
;             y luego llama a EXTNUM. No modifica IX ni HL.

EXTNUM2:	ld	b,10
	ld	de,DTABUF
	ld	(OLDIX),ix
BUCEXN2:	ld	a,(ix)
	ld	(de),a
	inc	de
	call	INCRIX
	djnz	BUCEXN2
	push	hl
	ld	hl,DTABUF
	call	EXTNUM
	pop	hl
	ld	(NEWIX),ix
	ld	ix,(OLDIX)
	call	AJUSTIX
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


;--- PUTNUM:  Convierte el numero DE a ASCII con NUMTOASC, y lo pone en IY.
;             A la salida, INCRIY apunta tras el numero.
;             ->Usa INCRIY

PUTNUM:	push	af,bc,de,hl
	ld	hl,DTABUF
	ld	b,5
	ld	c," "
	ld	a,%10 000
	call	NUMTOASC
BUCPN:	ld	a,(hl)
	inc	hl
	or	a
	jr	z,FBUCPN
	cp	" "	;Se salta los caracteres de relleno
	jr	z,BUCPN
	ld	(iy),a
	call	INCRIY
	jr	BUCPN
FBUCPN:	pop	hl,de,bc,af
	ret


;--- NUMTO2:   Convierte el numero DE a cadena ASCII en HL, sin fin. especial
;              Se salta los espacios de relleno
;              A la salida, HL apunta tras el numero

NUMTO2:	push	af,de,hl
	ld	b,5
	ld	c," "
	ld	a,%10 000
	ld	hl,BUFNT2
	call	NUMTOASC

	pop	hl
	ld	de,BUFNT2
BUCNT2:	ld	a,(de)
	inc	de
	cp	" "
	jr	z,BUCNT2
	dec	de
BUCNT3:	ld	a,(de)
	or	a
	jr	z,FNT2
	ld	(hl),a
	inc	hl
	inc	de
	jr	BUCNT3

FNT2:	pop	de,af
	ret


;--- PUTCR:   Pone CR+"$" en HL

PUTCR:	push	af
	ld	a,13
	ld	(hl),a
	inc	hl
	ld	a,10
	ld	(hl),a
	inc	hl
	ld	a,"$"
	ld	(hl),a
	pop	af
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


;*** GESTION DE FICHEROS ***

;--- OPEN: Abre el fichero con ruta+nombre en PARBUF
;          Si se puede abrir, devuelve A=FH y Cy=0
;          Si no, Cy=1 y A=Error

;--- CREATE: Crea el fichero con ruta+nombre en PARBUF
;            Si se puede crear, devuelve A=FH y Cy=0
;            Si no, Cy=1 y A=Error

TEMPFH:	equ	#4200
DOSF1:	equ	#4210
DOSF2:	equ	#4220

OPEN:	ld	a,_FOPEN
	ld	(DOSF1),a
	ld	a,_OPEN
	ld	(DOSF2),a
	jr	OPCR

CREATE:	ld	a,_FMAKE
	ld	(DOSF1),a
	ld	a,_CREATE
	ld	(DOSF2),a

OPCR:	ld	a,(DOSVER)
	or	a
	jr	nz,OPENDOS2

OPENDOS1:	ld	ix,FCBS	;DOS 1: Buscamos FCB libre
	ld	d,1
	ld	bc,40
SRCHFCB:	ld	a,(ix)
	or	a
	jr	z,OKFCB
	inc	d
	add	ix,bc
	jr	SRCHFCB
OKFCB:	ld	a,-1
	ld	(ix),a
	inc	ix
	ld	a,d
	ld	(TEMPFH),a

	call	BUILDFCB	;Construimos FCB y abrimos el fichero
	push	ix
	pop	de
	ld	a,(DOSF1)
	ld	c,a
	push	ix
	call	5
	pop	ix
	or	a
	ld	a,(DOSF1)	;Si hay error, devolvemos codigo
	scf
	ret	nz
	ld	a,1	;Tamanyo de un registro = 1
	ld	(ix+14),a
	ld	a,(TEMPFH)
	ccf
	ret

OPENDOS2:	ld	de,PARBUF	;DOS 2: Usamos FHs
	ld	a,(DOSF2)
	ld	c,a
	xor	a
	ld	b,0
	call	5
	or	a
	scf
	ret	nz
	ld	a,b
	ccf
	ret


;--- CLOSE: Cierra el fichero con el FH pasado en A
;           Si A=-1 no hace nada

CLOSE:	cp	-1
	ret	z

	ex	af,af
	ld	a,(DOSVER)
	or	a
	jr	nz,CLOSEDOS2

CLOSEDOS1:	ex	af,af
	ld	hl,FCBS-39
	ld	de,40
	ld	b,a
BUCCL1:	add	hl,de
	djnz	BUCCL1
	ex	de,hl
	ld	c,_FCLOSE
	call	5
	ret

CLOSEDOS2:	ex	af,af
	ld	b,a
	ld	c,_CLOSE
	call	5
	ret


;--- READ: Lectura de BC bytes del FH A a la direccion HL
;          Devuelve HL = Num. de bytes leidos y A=Error

;--- WRITE: Escritura de BC bytes al FH A desde la direccion HL
;           Devuelve HL = Num. de bytes escritos y A=Error

READ:	cp	-1
	ret	z
	ex	af,af
	ld	a,_RDBLK
	ld	(DOSF1),a
	ld	a,_READ
	ld	(DOSF2),a
	jr	RW

WRITE:	cp	-1
	ret	z
	ex	af,af
	ld	a,_WRBLK
	ld	(DOSF1),a
	ld	a,_WRITE
	ld	(DOSF2),a

RW:	ld	a,(DOSVER)
	or	a
	jr	nz,RWDOS2

RWDOS1:	push	bc	;Primero establecemos dir. de transf.
	ex	de,hl
	ld	c,_SETDTA
	call	5
	ex	af,af

	ld	hl,FCBS-39
	ld	de,40
	ld	b,a
BUCRW1:	add	hl,de
	djnz	BUCRW1

	ex	de,hl
	pop	hl
	ld	a,(DOSF1)	;Lectura/escritura y fin
	ld	c,a
	call	5
	ret

RWDOS2:	ex	de,hl
	push	bc
	pop	hl
	ld	a,(DOSF2)	;DOS 2: Lee/escribe en FH
	ld	c,a
	ex	af,af
	ld	b,a
	call	5
	ret


;--- READINF: Lee 16k de INFILE a pag.1, y pone marca EOF si es necesario

;--- READMACF: Idem con MACFILE

READINF:	ld	a,(FH_IN)
	ld	(FH_READ),a
	jr	RINFMAC

READMAC:	ld	a,(FH_MAC)
	ld	(FH_READ),a
	;jr      RINFMAC

RINFMAC:	ld	hl,#7F80	;Copia ultimos 128 bytes a pag. 0
	ld	de,#3F80
	ld	bc,128
	ldir

	ld	hl,#4000	;Rellenamos todo con EOFs por si acaso
	ld	de,#4001
	ld	bc,#3FFF
	ld	(hl),EOF
	ldir

	ld	hl,#4000
	ld	bc,#4000
	ld	a,(FH_READ)
	call	READ

	;ex      af,af            ;Pone EOF si no hemos leido 16K completas
	;ld      a,h
	;cp      #40
	;jr      z,EXAFRET
	;set     6,h
	;ld      a,EOF
	;ld      (hl),a
	;res     6,h
EXAFRET:	;ex      af,af
	ret

FH_READ:	db	0


;--- REBOBI:   Rebobina fichero de entrada (puntero al principio)

REBOBI:	ld	a,(DOSVER)
	or	a
	jr	nz,REBODOS2

REBODOS1:	ld	a,(FH_IN)
	ld	hl,FCBS-39
	ld	de,40
	ld	b,a
BUCRB1:	add	hl,de
	djnz	BUCRB1

	push	hl
	pop	ix
	ld	(ix+33),0
	ld	(ix+34),0
	ld	(ix+35),0
	ld	(ix+36),0

	ret

REBODOS2:	ld	a,(FH_IN)
	ld	b,a
	xor	a
	ld	de,0
	ld	hl,0
	ld	c,_SEEK
	call	5

	ret


;--- PRINTF: Imprime la cadena DE en el fichero A

DTABUF:	equ	#C000
CRLF:	db	13,10,0

PRINTF:	push	af,de,hl,ix,iy
	call	_PF
	pop	iy,ix,hl,de,af
	ret

_PF:	ex	af,af
	ld	hl,DTABUF
	ld	bc,0
BUCPRF:	ld	a,(de)
	or	a
	jr	z,OKPRF
	cp	"$"
	jr	z,OKPRF
	ld	(hl),a
	inc	hl
	inc	de
	inc	bc
	jr	BUCPRF

OKPRF:	ld	hl,DTABUF
	ex	af,af
	call	WRITE
	ret


BLANKF:	ld	de,CRLF
	jp	PRINTF

PRINTLOG:	ld	a,(FH_LOG)
	cp	-1
	ret	z
	jp	PRINTF
PRINTLIN:	ld	a,(FH_LIN)
	cp	-1
	ret	z
	jp	PRINTF
BLANKLOG:	ld	a,(FH_LOG)
	cp	-1
	ret	z
	jp	BLANKF
BLANKLIN:	ld	a,(FH_LIN)
	cp	-1
	ret	z
	jp	BLANKF


;*** RUTINAS DE ERROR ***

;--- INIERR: error DE al inicializar, y fin

INIERR:	push	de
	ld	de,ERR_S
	call	PRINT
	pop	de
	call	PRINT

	jp	FIN

ERR_S:	db	"ERROR: $"


;--- INIERRC: Error segun el codigo en A, y fin

INIERRC:	ld	b,a
	ld	hl,ERRORS
INIERBUC:	ld	a,(hl)
	inc	hl
	or	a
	jr	z,NOCODE
	cp	b
	jr	nz,NEXTCODE

ESTECODE:	ld	de,PARBUF
ESTEC1:	ld	a,(hl)
	ld	(de),a
	inc	de
	inc	hl
	or	a
	jr	z,PRINTERR
	jr	ESTEC1

PRINTERR:	ld	a,10
	ld	(de),a
	inc	de
	ld	a,"$"
	ld	(de),a
	ld	de,PARBUF
	jp	INIERR

NEXTCODE:	ld	a,(hl)
	inc	hl
	or	a
	jr	nz,NEXTCODE
	jr	INIERBUC

NOCODE:	ld	e,b
	ld	d,0
	ld	hl,ERRNUM
	ld	b,3
	ld	c," "
	xor	a
	call	NUMTOASC
	ld	de,ERRNUM_S
	jp	INIERR


;--- FIN: Libera memoria, cierra ficheros y termina

FIN:	ld	a,1
	call	PUT_S1
	ld	a,2
	call	PUT_S2

	ld	a,(DOSVER)
	or	a
	jr	z,FILESFIN

	ld	a,(NUMSEGS)
	or	a
	jr	z,FILESFIN

	dec	a
	dec	a
	ld	b,a
	ld	ix,MEMTAB+4
BUCFREE:	push	bc
	ld	b,(ix)
	ld	a,(ix+1)
	call	FRE_SEG
	pop	bc
	djnz	BUCFREE

FILESFIN:	ld	a,(FH_IN)
	call	CLOSE
	ld	a,(FH_OUT)
	call	CLOSE
	ld	a,(FH_LOG)
	call	CLOSE
	ld	a,(FH_LIN)
	call	CLOSE
	ld	a,(FH_MAC)
	call	CLOSE

TODOFIN:	ld	c,0
	jp	5


;*** TRATAMIENTO DE NOMBRES DE FICHERO DE ENTRADA ***


;--- CHKEXT: Comprueba si el nombre de fichero en PARBUF tiene extension.
;            Si no tiene, se le anyiade la extension pasada en DE.

CHKEXT:	ld	a,(DOSVER)
	or	a
	ld	hl,PARBUF
	jr	z,OKITEM

	push	de	;DOS 2: nos movemos hasta el nombre
	ld	c,_PARSE	;del fichero
	ld	de,PARBUF
	ld	b,0
	call	5
	pop	de

OKITEM:	ld	a,(hl)
	or	a
	jr	z,COPYEXT
	cp	"."
	ret	z
	inc	hl
	jr	OKITEM

COPYEXT:	ex	de,hl
	ld	bc,5
	ldir
	ret


;--- COPYFN: Copia el nombre de fichero de PARBUF a DE (bufer de 13 bytes)

COPYFN:	ld	hl,PARBUF
	ld	a,(PARBUF+1)
	cp	":"
	jr	nz,COPYFN2
	ld	hl,PARBUF+2

COPYFN2:	ld	a,(DOSVER)
	or	a
	jr	z,OKFN

	push	de	;DOS 2: nos movemos hasta el nombre
	ld	c,_PARSE	;del fichero
	ld	de,PARBUF
	ld	b,0
	call	5
	pop	de

OKFN:	ld	bc,13
	ldir
	ret


;--- PUTINF: Copia el nombre de fichero INFILE, sin ext., de PARBUF2 a PARBUF

PUTINF:	ld	hl,PARBUF2	;Recuperamos INFILE con su ruta a PARBUF
	ld	de,PARBUF	;y le borramos la extension
	ld	bc,128
	ldir

	ld	a,(DOSVER)
	or	a
	ld	hl,PARBUF
	jr	z,OKITEM2

	ld	c,_PARSE
	ld	de,PARBUF
	ld	b,0
	call	5

OKITEM2:	ld	a,(hl)
	cp	"."
	jr	z,OKNOEXT
	inc	hl
	jr	OKITEM2
OKNOEXT:	xor	a
	ld	(hl),a
	ret

PAR2BARRA:	ld	a,2
	ld	(NEXTPAR),a
	ret
NEXTPAR:	db	3


;--- ENDFN: Pone 13,10,"$" al final del nombre de fichero en IX,
;           y lo pasa a mayusculas

ENDFN:	push	ix
	call	_ENDFN
	pop	ix
	ret

_ENDFN:	ld	a,(ix)
	ld	hl,"za"
	call	RANGE
	jr	nz,ENDFN0
	and	%11011111
	ld	(ix),a
ENDFN0:	inc	ix
	or	a
	jr	nz,_ENDFN

	ld	a,13
	ld	(ix-1),a
	ld	a,10
	ld	(ix),a
	ld	a,"$"
	ld	(ix+1),a
	ret


;--- COMPFN:  Compara dos nombres de fichero en IX y HL (no modif. IX)
;             Si son iguales devuelve Cy=1

COMPFN:	push	ix
	call	_COMPFN
	pop	ix
	ret

_COMPFN:	ld	a,(ix)
	cp	(hl)
	scf
	ccf
	ret	nz
	cp	13
	scf
	ret	z
	inc	ix
	inc	hl
	jr	_COMPFN


;--- BUILDFCB: Construye FCB en IX segun el nombre de fichero en PARBUF

BUILDFCB:	push	ix
	call	_BUILDFCB
	pop	ix
	ret

_BUILDFCB:	ld	(STACK),sp

	push	ix	;Limpiamos FCB con ceros
	push	ix
	pop	hl
	pop	de
	inc	de
	ld	(hl),0
	ld	bc,38
	ldir

	push	ix	;Limpiamos nombre de ficheros con espacios
	push	ix
	pop	hl
	inc	hl
	pop	de
	inc	de
	inc	de
	ld	(hl),32
	ld	bc,10
	ldir

	ld	iy,PARBUF	;Hay que establecer unidad?
	ld	a,(iy+1)
	cp	":"
	jr	nz,OKDRIVE
	ld	a,(iy)
	and	%11011111
	sub	"A"-1
	ld	(ix),a
	inc	iy
	inc	iy

OKDRIVE:	ld	b,8
	inc	ix
	push	ix
BUCFCB:	ld	a,(iy)	;Copia nombre de fichero
	inc	iy
	cp	"."
	jr	z,EXTFCB
	or	a
	jr	z,FINFCB
	ld	hl,"za"
	call	RANGE
	jr	nz,BUCFCB1
	and	%11011111
BUCFCB1:	ld	(ix),a
	inc	ix
	djnz	BUCFCB
EXTFCB:	pop	ix	;Copia extension del fichero
	ld	bc,8
	add	ix,bc
	ld	b,3
BUCFCBE:	ld	a,(iy)
	inc	iy
	cp	"."
	jr	z,BUCFCBE
	or	a
	jr	z,FINFCB
	ld	hl,"za"
	call	RANGE
	jr	nz,BUCFCBE1
	and	%11011111
BUCFCBE1:	ld	(ix),a
	inc	ix
	djnz	BUCFCBE

FINFCB:	ld	sp,(STACK)
	ret

STACK:	dw	0


;*** Rutinas para el mapeador de memoria bajo DOS 2 ***

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


;--- PUT_Sx: Conecta segmento A de la tabla MEMTAB en pag. x = 1 o 2
;            Devuelve Cy=1 si no existe ese segmento

PUT_S1:	ld	(SAVEA),a
	ex	af,af
	ld	a,#40
	ld	(PAGE_S),a
	ld	a,#FD
	ld	(PORT_S),a
	ld	hl,SEG_P1
	call	PUT_S
	ret	c
	ld	a,(SAVEA)
	ld	(SEG_P1),a
	ret

PUT_S2:	ld	(SAVEA),a
	ex	af,af
	ld	a,#80
	ld	(PAGE_S),a
	ld	a,#FE
	ld	(PORT_S),a
	ld	hl,SEG_P2
	call	PUT_S
	ret	c
	ld	a,(SAVEA)
	ld	(SEG_P2),a
	ret

PUT_S:	push	ix
	push	hl
	pop	ix
	ex	af,af
	dec	a
	call	_PUT_S
	pop	ix
	ret

_PUT_S:	ld	c,a	;Error si no existe el segmento
	ld	a,(NUMSEGS)
	cp	c
	jrmni	RETCY1

	;ld      a,(ix)           ;No hace nada si ya esta conectado ese
	;cp      c                ;segmento
	;jr      z,RETCY0
	ld	a,c
	ld	(ix),a

	sla	c	;Conecta slot para el segmento,
	ld	b,0	;si no esta conectado ya
	ld	hl,MEMTAB
	add	hl,bc
	ld	a,(ix+1)
	cp	(hl)
	ld	a,(hl)
	push	hl,ix,af
	ld	a,(PAGE_S)
	ld	h,a
	pop	af
	call	nz,ENASLT
	pop	ix,hl
	ld	a,(hl)
	ld	(ix+1),a
	inc	hl

	ld	a,(DOSVER)
	or	a
	jr	nz,PUTSDOS2

PUTSDOS1:	ld	a,(PORT_S)
	ld	c,a
	ld	a,(hl)
	out	(c),a
	jr	OKPUTS

PUTSDOS2:	ld	a,(PAGE_S)
	ld	c,a
	ld	a,(hl)
	ld	h,c
	call	PUT_PH

OKPUTS:	;jr      RETCY0

RETCY0:	or	a
	ret

RETCY1:	scf
	ret


;--- Test de memoria directo (DOS 1)
;    ENTRADA:   DE = Bufer de 256 bytes que NO puede estar en la pagina 2
;                    ni puede contener la direccion #4001
;                    El mapeador ha de estar conectado en la pagina 2
;    SALIDA:    A  = Numero de segmentos
;                    0 -> El slot no contiene RAM
;                    1 -> El slot contiene RAM no mapeada
;    LLAMADAS:  GET_P2, PUT_P2
;    REGISTROS: F, HL, BC, DE

MEMTEST1:	ld	a,(#8001)	;Comprobamos si es ROM   
	ld	h,a
	cpl
	ld	(#8001),a
	ld	a,(#8001)
	cpl
	ld	(#8001),a
	cpl
	cp	h
	ld	a,0
	ret	z

	ld	hl,#8001
	ld	a,(TEST_P2)
	push	af	;A  = Segmento actual en pagina 2   
	push	de	;DE = Bufer   
	ld	b,0

MT1BUC1:	ld	a,b	;Grabamos el primer byte de todas los   
	out	(#FE),a	;segmentos
	ld	(TEST_P2),a
	ld	a,(hl)
	ld	(de),a
	ld	a,b
	ld	(hl),a
	inc	de
	inc	b
	ld	a,b
	cp	0
	jr	nz,MT1BUC1

	out	(#FE),a
	ld	(TEST_P2),a
	ld	a,(hl)
	neg
	ld	(NUMSGS),a	;A = Numero de segmentos encontrados  
	ld	b,0	;    (0 para 256)   
	ld	c,a
	pop	de

MT1BUC2:	ld	a,b
	out	(#FE),a	;Restauramos el primer byte de
	ld	(TEST_P2),a
	ld	a,(de)	;todos los segmentos   
	ld	(hl),a
	inc	de
	inc	b
	ld	a,b
	cp	c
	jr	nz,MT1BUC2

	pop	af	;Restauramos segmento original   
	out	(#FE),a
	ld	(TEST_P2),a
	ld	a,(NUMSGS)
	cp	1
	jr	z,NOMAP1
	or	a
	ret	nz
	ld	a,#FF
	ret
NOMAP1:	xor	a
	ret

NUMSGS:	db	0
TEST_P2:	db	1


;*** Rutinas generales para cadenas ***

BLANK:	ld	e,13	;Imprime linea en blanco
	ld	c,_CONOUT
	call	5
	ld	e,10
	ld	c,_CONOUT
	jp	5

PRINT:	ld	c,_STROUT
	jp	5

PR:	cp	10
	ret	z
	cp	13
	ret	z
	push	af
	ld	c,2
	ld	e,a
	call	5
	pop	af
	ret

CHKSPACE:	cp	" "	;Devuelve Z si A es espacio o tabulador
	ret	z
	cp	9
	ret

CHKREM:	cp	"'"
	ret	z
	ld	(SAVEAREM),a
	ld	(OLDIX),ix
	call	MAY
	cp	"R"
	jr	nz,FCHKREM
	call	INCRIX
	ld	a,(ix)
	call	MAY
	cp	"E"
	jr	nz,FCHKREM
	call	INCRIX
	ld	a,(ix)
	call	MAY
	cp	"M"
FCHKREM:	push	af
	ld	(NEWIX),ix
	ld	ix,(OLDIX)
	call	AJUSTIX
	pop	af
	ld	a,(SAVEAREM)
	ret
SAVEAREM:	db	0


;--- GETNAME: Obtiene nombre tras un "@" o "~" en HL, acabado en 0
;             Si hay espacios o tabuladores, los pasa antes
;             Si ABSCASE=0, lo convierte a mayusculas
;             Entrada: IX apunta al nombre
;             Salida:  IX apunta tras el nombre (1er car. inv.)
;                      A = primer caracter invalido
;                      B = longitud nombre
;                      DE apunta tras el 0 final, HL preservado
;                      Cy=1 y nombre truncado, si long. > 255
;             -> Usa INCRIX

GETNAME:	push	hl
	call	_GNAME
	ex	de,hl
	pop	hl
	ret

_GNAME:	ld	bc,0
BUCGDF0:	ld	a,(ix)
	call	CHKSPACE	;Pasa espacios/tabs.
	jr	nz,BUCGDFN
	call	INCRIX
	jr	BUCGDF0

BUCGDFN:	push	hl
	ld	a,(ix)
	cp	"{"
	jr	z,FGETDFN
	cp	"}"
	jr	z,FGETDFN
	cp	127
	jr	z,FGETDFN
	ld	hl,#2F00	;0-47?
	call	RANGE
	jr	z,FGETDFN
	ld	hl,#403A	;58-64?
	call	RANGE
	jr	z,FGETDFN
	ld	hl,#5E5B	;91-94?
	call	RANGE
	jr	z,FGETDFN
	call	GETNNUM
	jr	nz,FGETDFN

	ld	h,a	;Lo pasa a mayusculas
	ld	a,(ABSCASE)	;si es necesario
	or	a
	ld	a,h
	jr	nz,OKDN1
	ld	hl,"za"
	call	RANGE
	jr	nz,OKDN1
	and	%11011111

OKDN1:	pop	hl
	ld	(hl),a
	inc	hl
	inc	bc
	call	INCRIX
	bit	0,b	;Longitud ha llegado a 256?
	jr	z,BUCGDFN
	scf
	ld	b,255
	dec	hl
	jr	FGETDF3

FGETDFN:	or	a
	pop	hl
FGETDF3:	ld	(hl),0
	inc	hl
	ld	b,c
	ret

GETNNUM:	ld	h,a	;Devuelve Z=0 si NUMFLAG=-1
	ld	a,(NUMFLAG)	;y el caracter no es un numero,
	or	a	;y pone NUMFLAG=3
	ld	a,h
	ret	z
	ld	hl,"90"
	call	RANGE
	ret	z
	ld	a,3
	ld	(NUMFLAG),a
	ret



;--- CHKRESV: Comprueba si el nombre en IX es una palabra reservada
;             Si lo es, devuelve en A su codigo; si no, devuelve A=0
;             Preserva IX si no es palabra reservada
;             No hace nada si el nombre tiene long. > 255 (entonces Cy=1)
;             -> Usa INCRIX

NAMEBUF:	equ	#C000

CHKRESV:	ld	a,(ABSCASE)
	push	af
	ld	(OLDIX),ix
	xor	a
	ld	(ABSCASE),a
	call	_CHKRV
	ld	(NEWIX),ix
	push	af
	or	a
	call	z,SAVIX2
	pop	af
	ex	af,af
	pop	af
	ld	(ABSCASE),a
	ex	af,af
	ret

SAVIX2:	ld	ix,(OLDIX)
	call	AJUSTIX
	ret

_CHKRV:	xor	a
	ld	(ABSCASE),a
	ld	hl,NAMEBUF
	call	GETNAME
	ret	c

	ld	de,RESVTAB
BUCCHRES:	ld	hl,NAMEBUF-1
	ld	a,(de)
	or	a
	ret	z
	;ld      b,c              ;C=Codigo palabra
	ld	c,a	;B=Longitud palabra IX
	inc	de
BUCHR2:	ld	a,(de)
	inc	de
	inc	hl
	cp	(hl)
	jr	nz,NEXTRES
	;djnz    BUCHR2
	or	a
	jr	nz,BUCHR2
	ld	a,c
	or	a
	ret
	jr	BUCHR2
NEXTRES:	ld	a,(de)
	inc	de
	or	a
	jr	nz,NEXTRES
	jr	BUCCHRES


;--- CHKDUP: Comprueba si el nombre en (IY+2) ya esta en la lista de macros
;            Si ya estaba, devuelve Cy=1

CHKDUPD:	ld	(SAVEA),a
	push	hl,iy
	call	_CHKDUPD
	pop	iy,hl
	ld	a,(SAVEA)
	ret

_CHKDUPD:	push	iy
	pop	hl
	inc	hl
	inc	hl	;HL=Nombre de referencia
	ld	(REFDD),hl
	ld	iy,#8000
BUCCHDUP:	ld	hl,(REFDD)
	ld	e,(iy)
	ld	a,(iy+1)
	or	e
	ret	z	;Fin si hemos llegado al final de tabla
	ld	d,(iy+1)
	push	de	;DE=Dir. siguiente
	inc	iy
	inc	iy	;IY=Nombre a comparar
BUCDD2:	ld	a,(hl)
	call	MAYCASE
	cp	(iy)
	inc	hl
	inc	iy
	jr	nz,NEXTDD
	or	a
	jr	nz,BUCDD2
ESDUP:	pop	de	;Si los dos llegan al 0 final ->
	scf		;                ;nombre duplicado -> fin con Cy=1
	ret
NEXTDD:	pop	iy	;Difieren -> siguiente nombre
	jr	BUCCHDUP


;--- CHKDUPL: Comprueba si el nombre de etiqueta en DTABUF ya esta en la lista.
;             Si lo esta, devuelve Cy=1.

CHKDUPL:	push	hl,ix,iy
	ld	a,(SEG_P2)
	ld	(SAVEA),a
	call	_CHKDUPL
	push	af
	ld	a,(SAVEA)
	call	PUT_S2
	pop	af
	pop	iy,ix,hl
	ret

_CHKDUPL:	ld	a,(TABLAS_SEG)
	call	PUT_S2
	ld	iy,(LINDIR)
BUCCHDUL:	ld	hl,DTABUF
	ld	e,(iy)
	ld	d,(iy+1)
	ld	a,d
	or	e
	ret	z	;Fin si hemos llegado al final de tabla
	inc	de
	ld	a,d
	or	e
	jr	nz,BUCDL22
	ld	a,(SEG_P2)	;Siguiente segmento si hemos
	inc	a	;encontrado -1
	call	PUT_S2
	ld	iy,#8000
	jr	BUCCHDUL

BUCDL22:	dec	de
	push	de	;DE=Dir. siguiente
	inc	iy
	inc	iy	;IY=Nombre a comparar
BUCDL2:	ld	a,(hl)
	call	MAYCASE
	cp	(iy)
	inc	hl
	inc	iy
	jr	nz,NEXTDL
	or	a
	jr	nz,BUCDL2
ESDUPL:	pop	de	;Si los dos llegan al 0 final ->
	scf		;                ;nombre duplicado -> fin con Cy=1
	ret
NEXTDL:	pop	iy	;Difieren -> siguiente nombre
	jr	BUCCHDUL




;--- MAYCASE: Transforma A a mayusculas si CASE=0

MAYCASE:	ld	(SAVEAMAY),a
	ld	a,(CASE)
	or	a
	ld	a,(SAVEAMAY)
	ret	nz
	call	MAY
	ret

RETPOPA:	pop	af
	ret
SAVEAMAY:	db	0


;--- MAY:     Transforma A a mayusculas

MAY:	push	hl
	ld	hl,"za"
	call	RANGE
	pop	hl
	ret	nz
	and	%11011111
	ret


;--- PASSPACE:Pasa espacios y tabuladores a partir de IX.
;             Salida: IX apunta al primer caracter que no es espacio ni tab.
;                     A contiene (IX).
;             ->Usa INCRIX

PASSPACE:	ld	a,(ix)
	call	CHKSPACE
	ret	nz
	call	INCRIX
	jr	PASSPACE


;--- GENERR:  Genera mensaje "Error in line [tal]: ..."
;             Lo imprime en pantalla y en LOG file
;             Incrementa NUMERR
;             Entrada: (PHLIN) = Numero de linea
;                      DE = Cadena de error
;                      Preserva AF

GENERR:	push	af
	call	_GENERR
	pop	af
	ret

_GENERR:	push	de

	ld	de,(PHLIN)
	ld	hl,ERRIL_S2
	ld	b,5
	ld	c,0
	xor	a
	call	NUMTOASC

	ld	hl,ERRIL_S2
	ld	de,ERRIL_S2
	ld	b,5
BUCERRI1:	ld	a,(hl)
	inc	hl
	or	a
	jr	z,BUCERRI2
	ld	(de),a
	inc	de
BUCERRI2:	djnz	BUCERRI1
	;ld      a,"]"
	;ld      (de),a
	;inc     de

	ld	a,(MACROIND)	;Imprime "[Mnum]" si el error
	or	a	;esta dentro de una macro
	jr	z,BUCERRI3
	ld	a," "
	ld	(de),a
	inc	de
	ld	a,"["
	ld	(de),a
	inc	de
	ld	a,"M"
	ld	(de),a
	inc	de
	ex	de,hl
	ld	a,(MACROIND)
	ld	e,a
	ld	d,0
	call	NUMTO2
	ex	de,hl
	ld	a,"]"
	ld	(de),a
	inc	de

BUCERRI3:	ld	a,(SEG_P1)	;Imprime "[F]" si el error esta en el
	cp	MACCOPIA_SEG	;fichero de macros
	jr	nz,BUCERRI4
	ld	a," "
	ld	(de),a
	inc	de
	ld	a,"["
	ld	(de),a
	inc	de
	ld	a,"F"
	ld	(de),a
	inc	de
	ld	a,"]"
	ld	(de),a
	inc	de

BUCERRI4:	ld	a,":"
	ld	(de),a
	inc	de
	ld	a," "
	ld	(de),a
	inc	de
	ld	a,"$"
	ld	(de),a

	ld	de,ERRIL_S
	call	PRINTLOG
	call	PRINT

	pop	de
	call	PRINTLOG
	call	PRINT

	ld	de,(NUMERR)
	inc	de
	ld	(NUMERR),de

	ret


;--- FATERR:  Error fatal DE y fin.

FATERR:	push	de
	call	BLANK
	call	BLANKLOG
	ld	de,FATAL_S
	call	PRINTLOG
	call	PRINT
	pop	de
	call	GENERR
	ld	de,ABORT_S
	call	PRINTLOG
	call	PRINT
	call	BLANK
	jp	FIN


;*** CONTROL DE PUNTEROS ***

;--- INCRIX:  Incrementa IX y, si llega a #8000, lo pone a #4000
;             y lee otras 16K de INFILE a pag. 1
;             Si INCCODE es RET, simplemente incrementa IX

INCRIX:	inc	ix
INCCODE:	ret

	ex	af,af
	ld	a,ixh
	cp	#80
	jr	nz,RETEX2

	ex	af,af
	push	af,bc,de,hl,iy
	call	READINF
	pop	iy,hl,de,bc,af
	ld	ix,#4000
	ret

RETEX2:	ex	af,af
	ret


;--- INCRIY:  Incrementa IY y, si llega a #C000, lo pone a #8000,
;             y escribe la pagina 2 en OUTFILE.

INCRIY:	inc	iy

	ex	af,af
	ld	a,iyh
	cp	#C0
	jr	nz,RETEX2

	push	af,bc,de,hl,iy
	ld	hl,#8000
	ld	bc,#4000
	ld	a,(FH_OUT)
	call	WRITE
	pop	iy,hl,de,bc,af
	ld	iy,#8000
	ret


;--- INCRIY2: Incrementa IY y, si llega a #C000, devuelve Cy=1.

INCRIY2:	inc	iy

	ex	af,af
	ld	a,iyh
	cp	#C0
	jr	nz,RETEX3

	ex	af,af
	scf
	ret

RETEX3:	ex	af,af
	or	a
	ret


;--- AJUSTIX: Si (OLDIX) es mayor que (NEWIX), resta #4000 a IX.
;             Esto es necesario si se ha llamado a INCRIX
;             y se quiere recuperar un antiguo IX, guardado en (OLDIX).

AJUSTIX:	push	hl,de,af
	ld	de,(OLDIX)
	ld	hl,(NEWIX)
	call	COMPDEHL
	jrmyi	FJUSTIX
	ld	hl,(OLDIX)
	ld	de,#4000
	or	a
	sbc	hl,de
	push	hl
	pop	ix
FJUSTIX:	pop	af,de,hl
	ret


;--- INCRIXN: Incrementa IX con INCRIX, D veces
;             (coloca el puntero tras el numero extraido en EXTNUM)

INCRIXN:	push	af
	ld	a,d
	or	a
	jp	z,RETPOPA
	push	bc
	ld	b,d
BUCIIXN:	call	INCRIX
	djnz	BUCIIXN
	pop	bc
	jp	RETPOPA

ANS:	push	af,bc,de,hl
	ld	e,"!"
	ld	c,2
	call	5
	pop	hl,de,bc,af
	ret


;***********
;*         *
;* CADENAS *
;*         *
;***********

PRES_S:	db	13,10,"-=-= NestorPreTer 0.3 alfa - the MSX-BASIC pre-interpreter =-=-",13,10
	db	"     By Konami Man, 12-1999  (^^)v",13,10,10,"$"
USAGE_S:	db	"Usage:   NPR <infile>[.<ext>] [<outfile>[.<ext>]] [/C0|/C1] [/B0|/B1] [/F<n>]",13,10
	db	"         [/I<n>] [/LOG[:][<logfile>[.<ext>]]] [/LIN[:][<linfile>[.<ext>]]]",13,10
	db	"         [/MAC[:][<macfile>[.<ext>]]]",13,10,10
	db	"infile:  Source ASCII file. Default extension is ASC.",13,10
	db	"outfile: Destination MSX-BASIC ASCII file.",13,10
	db	"         Default filename is same as infile. Default extension is BAS.",13,10,10
	db	"/C0|1:   Case sensitive for defines and line labels, no/yes (default: no).",13,10
	db	"/B0|1:   Jump to BASIC and execute created program when finishing,",13,10
	db	"         no/yes (default: no).",13,10
	db	"/Fn:     n = First BASIC line number (default: 10).",13,10
	db	"/In:     n = BASIC line number increase (default: 10).",13,10,10
	db	"/LOG:    Creates a logfile with program statistics and processing errors.",13,10
	db	"         Default name is same as infile, default extension is LOG.",13,10
	db	"/LIN:    Creates a file with a list of line labels with",13,10
	db	"         their matching BASIC line numbers.",13,10
	db	"         Default name is same as infile, default extension is LIN.",13,10
	db	"/MAC:    Uses an external file for macro definitions,",13,10
	db	"         in addition to the source file itself.",13,10
	db	"         Default name is same as infile, default extension is MAC.",13,10
	db	"$"

LOGTIT_S:	db	"-=-= NestorPreTer 0.3 LOG file =-=-",13,10,0
LINTIT_S:	db	"-=-= NestorPreTer 0.3 line labels list file =-=-",13,10,0

EXT_ASC:	db	".ASC",0
EXT_BAS:	db	".BAS",0
EXT_LOG:	db	".LOG",0
EXT_LIN:	db	".LIN",0
EXT_MAC:	db	".MAC",0

INF_S:	db	"Source ASCII file: "
INFILE:	db	13,10,"$"
	ds	13
OUTF_S:	db	"Target BASIC ASCII file: "
OUTFILE:	db	13,10,"$"
	ds	13
LOGF_S:	db	"Process logfile: "
LOGFILE:	db	13,10,"$"
	ds	13
LINF_S:	db	"Line labels list file: "
LINFILE:	db	13,10,"$"
	ds	13
MACF_S:	db	"External macros file: "
MACFILE:	db	13,10,"$"
	ds	13

MEM_S:	db	"Available memory for macros and line labels: "
MEM_S2:	db	"-----K",13,10,"$"
CASE_S:	db	"Case sensitive for macros and line labels: "
CASE_ONOF:	ds	6
BOOT_S:	db	"Execute created BASIC program when finishing: "
BOOT_ONOF:	ds	6
SRDEF_S:	db	"* Building macros table...",13,10,"$"
OK_S:	db	"OK!",13,10,"$"
PRODEF_S:	db	"Number of valid macros found: "
NUMDEF_S:	db	"-----",13,10,"$"
SRLIN_S:	db	"* Building line labels table...",13,10,"$"
PROLIN_S:	db	"Number of valid line labels found: "
NUMLIN_S:	db	"-----",13,10,"$"
PROBL_S:	db	"Number of BASIC lines generated: "
NUMBL_S:	db	"-----",13,10,"$"
NUME1_S:	db	"Errors found on pass 1: "
NE1_S:	db	"-----",13,10,"$"
NUME2_S:	db	"Errors found on pass 2: "
NE2_S:	db	"-----",13,10,"$"
PAR_S:	db	"* Parsing BASIC text...",13,10,"$"
NUMET_S:	db	"Total errors found: "
NET_S:	db	"-----",13,10,"$"

NOLOG_S:	db	"No process logfile created.",13,10,"$"
NOLIN_S:	db	"No line labels list file created.",13,10,"$"
NOMAC_S:	db	"No external macros file specified.",13,10,"$"
MATCH_S:	db	"Line labels and BASIC line numbers match as follows:",13,10,"$"

FATAL_S:	db	"FATAL $"
ERRIL_S:	db	"ERROR in line "
ERRIL_S2:	db	"-----]: $"

ERRNUM_S:	db	"Disk error with DOS code "
ERRNUM:	db	"---.",13,10,"$"
YES_S:	db	"YES",13,10,"$"
NO_S:	db	"NO",13,10,"$"

INFERR_S:	db	"Source file name invalid or not specified.",13,10,"$"
PARERR_S:	db	"Invalid input prameter.",13,10,"$"
NOMAP_S:	db	"No mapped memory found.",13,10,"$"
NOFREE_S:	db	"No free memory segments found.",13,10,"$"
DUPLI_S:	db	"Duplicate filename in input parameters.",13,10,"$"

ERRORS:	db	#16,"Invalid drive/filename, or disk/root directory full.",0
	db	#0F,"Invalid drive/filename, or source file not found.",0
	db	7,"Macros file not found.",0
	db	219,"Invalid drive.",0
	db	218,"Invalid file name.",0
	db	217,"Invalid pathname.",0
	db	215,"Source file not found.",0
	db	214,"Directory not found.",0
	db	213,"Root directory full.",0
	db	212,"Disk full.",0
	db	209,"Out/log/lin file already exists and is read-only file.",0
	db	0

INV1_S:	db	"Invalid character in macro name.",13,10,"$"
INV2_S:	db	"Macro name too long (>255 characters).",13,10,"$"
INV3_S:	db	"Reserved word used as macro name.",13,10,"$"
INV4_S:	db	"Empty macro name and body.",13,10,"$"
INV5_S:	db	"Duplicate macro name.",13,10,"$"
INV6_S:	db	"16K limit reached - macro ignored.",13,10,"$"
INV7_S:	db	"Empty macro body.",13,10,"$"

INV8_S:	db	"Invalid parameter in @LINE command.",13,10,"$"
INV9_S:	db	"Can't set BASIC line number lower than current one.",13,10,"$"
INV10_S:	db	"Invalid character in line label name.",13,10,"$"
INV11_S:	db	"Line label too long (>255 characters).",13,10,"$"
INV12_S:	db	"Non-numeric characters in a numeric label name.",13,10,"$"
INV13_S:	db	"Duplicate line label.",13,10,"$"

PRE1_S:	db	"Undefined macro name.",13,10,"$"
PRE2_S:	db	"NestorPreTer command found in a BASIC line.",13,10,"$"
PRE3_S:	db	"Undefined line label name.",13,10,"$"

FAT1_S:	db	"BASIC line number overflow!",13,10,"$"
FAT2_S:	db	"Memory for macros and line labels exhausted!",13,10,"$"
FAT3_S:	db	"Macro recursivity overflow!",13,10,"$"
FAT4_S:	db	"Source file is not an ASCII format file!",13,10,"$"
ABORT_S:	db	"Process aborted.",13,10,"$"
NOERR_S:	db	"No errors.",13,10,"$"
PASS1_S:	db	"--- PASS 1 (macros and line labels search)",13,10,"$"
PASS2_S:	db	"--- PASS 2 (BASIC code process)",13,10,"$"

FNSH_S:	db	"* Finishing...",13,10,"$"
MENOS_S:	db	"--- Process complete",13,10,"$"
NOEF_S:	db	"No errors were found.",13,10,"$"

DONE_S:	db	"Done!",13,10,"$"
NOPUB_S:	db	"Errors were found, can't execute target program.",13,10,"$"
PUB_S:	db	"Now executing target program...",13,10,"$"

RESVTAB:	db	1,"MACRO",0
	db	1,"DEFINE",0	;Palabras reservadas, no pueden
	db	2,"ENDBASIC",0	;ser usadas como nombres de macros
	db	3,"SPACEON",0
	db	4,"SPACEOFF",0
	db	5,"REMOFF",0
	db	6,"REMON",0
	db	7,"LINE",0
	db	0

JMPITAB:	db	"OTOG",0	;Si un numero esta precedido por una de
	db	"BUSOG",0	;estas instrucciones, es una etiqueta
	db	"NEHT",0
	db	"ESLE",0
	db	"NRUTER",0
	db	"EROTSER",0
	db	"EMUSER",0
	db	"MUNER",0
	db	"OTUA",0
	db	"NUR",0
	db	"ETELED",0
	db	"TSIL",0
	db	0

BASIC_S:	db	"basic "


;*********
;*       *
;* DATOS *
;*       *
;*********

MEMTAB:	db	0,2,0,1,0,4,0,5,0,6,0,7,0,-1,0,9,0,10,0,11,0,12,0,13,0,14
	db	0,15,0,16,0,17,0,18,0,19,0,20,0,21,0,22,0,23,0,24,0,25
	db	0,26,0,27,0,28,0,29,0,30,0,31
	db	0,-1
NUMSEGS:	db	6
SEG_P1:	db	1
SLOT_P1:	db	0
SEG_P2:	db	2
SLOT_P2:	db	0
FIRSTBL:	dw	-1
FIRSTBI:	dw	-1
FH_IN:	db	-1
FH_OUT:	db	-1
FH_LOG:	db	-1
FH_LIN:	db	-1
FH_MAC:	db	-1
NUMPHLIN:	dw	1	;Numero de lineas fisicas
PHLIN:	dw	1	;Linea fisica actual
CASE:	db	34
BOOT:	db	34
MACROPNT:	dw	MACROSTK
GET_DEF_D:	dw	#8000
TABLAS_SEG:	db	4
REM:	db	0
SPAZ:	db	0

DATOS:	;

DOSVER:	db	0	;Version del DOS: 0 = Ver. 1, 1 = Ver. 2
ABSCASE:	db	0
SIESMACONO:	db	0
PAGE_S:	db	0
PORT_S:	db	0
SAVESP:	dw	0
SAVEA:	db	0
SAVEIY:	dw	0
PRIMVEZ:	db	0
OLDIX:	dw	0
NEWIX:	dw	0
OLDIY:	dw	0
NEWIY:	dw	0
NEWLINE:	db	0
NUMFLAG:	db	0
PRIMINV:	db	0
PRMACRO:	db	0
BLOVERF:	dw	0
REFDD:	dw	0
BASLIN:	dw	0
BASINC:	dw	0
OLDBL:	dw	0
OLDBI:	dw	0
ANTBL:	dw	0
NAMEDIR:	dw	0
NUMDEFS:	dw	0	;Numero de DEFINEs generados
NUMLABS:	dw	0
NUMBASLIN:	dw	0	;Numero de lineas BASIC generadas
LINDIR:	dw	0	;Dir. de inicio de la tabla de lineas
COMILL:	db	0	;-1 si hay comillas abiertas
NUMERR:	dw	0	;Num. de errores encontrados
TOTERR:	dw	0	;Num. total de errores encontrados
MACDIR:	dw	0
BLBUF:	ds	10
BUFNT2:	ds	10
FCBS:	ds	40*5	;Flag + 39 bytes para el FCB
	;Flag=-1 si el FCB esta en uso, si no 0

	ds	10
MACROIND:	db	0	;Puntero a la pila de macros
MACROSTK:	ds	256	;Pila de macros


;             ! " # $ % & ' ( ) * + , - . / : ; < = > ? @ [ \ ] ^ { }

j:	ld	hl,#c000
	ld	ix,akesto
	call	CHKRESV
	nop

akesto:	db	"@remon",13
