	;NestorBASIC version 1.11
	;Por Konami Man, Diciembre 2.004

	;--- Cambios respecto a 1.10
	;    - Adaptado al nuevo metodo de deteccion
	;      de InterNestor Lite 1.0

	;--- Cambios respecto a 1.0
	;    - Arreglado un fallo en la funcion 54,
	;      los graficos no se descomprimian en la
	;      pagina de VRAM adecuada
	;    - Arreglado un fallo en la reserva de segmentos,
	;      TOTSEGS no se establecia en DOS 1
	;    - Al desinstalar, ahora modifica la zona de trabajo
	;      para que no haya CALLs activos en RAM.
	;    - Ahora la deteccion de chips musicales se hace
	;      al instalar NestorBASIC. Ademas, la funcion
	;      72 devuelve los chips musicales presentes
	;      aunque no se haya cargado reproductor.
	;    - Anyadido soporte para InterNestor Lite

	;Una vez ensamblado, se ha de concatenar el fichero NBASIC.DAT
	;al fichero de codigo resultante

	db	#FE
	dw	EXE_I	;Yeah! Cabecera pal BLOAD, y asi
	dw	EXE_F	;poder usar el truki del Pentaro!!
	dw	EXE_I

;-------------------------------------
;--- MAKROS, KONSTANTES Y KROKETAS ---
;-------------------------------------

VERP:	equ	1	;Version principal de NestorBASIC
VERS:	equ	1	;Version secundaria, primer digito
VERT:	equ	1	;Version secundaria, segundo digito

TAMFCB:	equ	38
MAXFIL:	equ	5	;Maximo numero de ficheros abiertos
LONBUF:	equ	TAMFCB+33
DIMP:	equ	15	;Dimension de la matriz de parametros
	;                        ;(10 a 255)
LONF01:	equ	80	;Tamanio maximo cadenas F$(0) y F$(1)
LONMB14:	equ	#1200	;Longitud del reproductor Moonblaster 1.4
LONWAVE:	equ	#1400	;Longitud del rep. Moonblaster Wave
LONPATCH:	equ	#2500

RDSLT:	equ	#000C
WRSLT:	equ	#0014
CALSLT:	equ	#001C
ENASLT:	equ	#0024
MSXVER:	equ	#002D
GRPRT:	equ	#0089
EXTROM:	equ	#015F
CHGCPU:	equ	#0180
GETCPU:	equ	#0183
HIMEM:	equ	#FC4A
SUBFLG:	equ	#F6A5
PTRGET:	equ	#5EA4
USRTAB:	equ	#F39A
VALTYP:	equ	#F663
EXPTBL:	equ	#FCC1
NEWSTT:	equ	#4601
FRMEVL:	equ	#4C64
FRESTR:	equ	#67D0
SAVTXT:	equ	#F6AF
DAC:	equ	#F7F6
ARG:	equ	#F847
STKTOP:	equ	#F674
MEMSIZ:	equ	#F672
VARTAB:	equ	#F6C2
ARYTAB:	equ	#F6C4
STREND:	equ	#F6C6
SCRMOD:	equ	#FCAF
LINLEN:	equ	#F3B0
H.TIMI:	equ	#FD9F
HERR:	equ	#FFB1
EXTBIO:	equ	#FFCA

_SELDSK:	equ	#0E
_FOPEN:	equ	#0F
_FCLOSE:	equ	#10
_SFIRST:	equ	#11
_SNEXT:	equ	#12
_FDEL:	equ	#13
_FMAKE:	equ	#16
_FREN:	equ	#17
_LOGIN:	equ	#18
_CURDRV:	equ	#19
_SETDTA:	equ	#1A
_ALLOC:	equ	#1B
_WRBLK:	equ	#26
_RDBLK:	equ	#27	; ^
_RDABS:	equ	#2F	; |
_WRABS:	equ	#30	; +-- DOS 1

_FFIRST:	equ	#40	; +-- DOS 2 
_FNEXT:	equ	#41	; | 
_OPEN:	equ	#43	; V 
_CREATE:	equ	#44
_CLOSE:	equ	#45
_ENSURE:	equ	#46
_DUP:	equ	#47
_READ:	equ	#48
_WRITE:	equ	#49
_SEEK:	equ	#4A
_DELETE:	equ	#4D
_RENAME:	equ	#4E
_MOVE:	equ	#4F
_ATTR:	equ	#50
_HATTR:	equ	#55
_GETCD:	equ	#59
_CHDIR:	equ	#5A
_PARSE:	equ	#5B
_FLUSH:	equ	#5F
_RAMD:	equ	#68
_BUFFER:	equ	#69
_DOSVER:	equ	#6F

ENYEMAY:	equ	165
ENYEMIN:	equ	164

SEG_BUF:	equ	4	;Segmento bufer

P3_ID:	equ	#F400
P3_SEG1:	equ	#F402
P3_SEG2:	equ	#F403
P3_P3DIR:	equ	#F404

;--- Esta macro ejecuta la rutina @RUT y vuelve con las interrupciones
;    en el estado anterior a la llamada. La rutina no puede usar AF'.

callint:	macro	@RUT
	ex	af,af
	push	af	;AF' original en la pila 
	ld	a,i	;F' contiene el estado de las int. en P/V 
	ex	af,af
	call	@RUT
	ex	af,af
	jp	po,$+6
	ei
	jr	$+3
	di
	pop	af
	ex	af,af
	ret
	endm

;--- Direcciones del segmento de los reproductores musicales

MUSINT:	equ	#4010
STRMUS:	equ	#4013
PAUMUS:	equ	#4016
CONTMUS:	equ	#4019
STPMUS:	equ	#401C
;SRCCHP:    equ     #401F

CHIPS:	equ	#8022
CHIPS_AC:	equ	#8023
MUS_ON:	equ	#8024
MUS_SL:	equ	#8025
MUS_SL1:	equ	#8026
MUS_SL2:	equ	#8027
MUS_SL3:	equ	#8028
MUS_DIR:	equ	#8029
POS:	equ	#802B
STEP:	equ	#802C
MUS_PAU:	equ	#802D
FADING:	equ	#802E
FADSPD:	equ	#802F
FADCNT:	equ	#8030
SMPADR:	equ	#8031
TAB_MUS:	equ	#8031
SL_NOW:	equ	#8037


;*******************************************************************************
;******************                                        *********************
;******************   PARTE EJECUTABLE DE INICIALIZACION   *********************
;******************                                        *********************
;*******************************************************************************

;(Pero que basto soy con las etiquetas...)

	;* Al tanto que va de canto ((c) MdA):
	;  El poke magico debe estar en la pagina 2,
	;  pero el resto de la rutina de inicializacion,
	;  en pagina 3. De ahi el ORG tan raro.

	;org     #C000-(POKEMAGI_END-POKEMAGI_INI)
	ORG	#C000-39	;Igual que arriba pero no da error
	;org     #C000
EXE_I:	;

;*******  Poke magico (poke -1,x), v1.01

POKEMAGI_INI:	di
	ld	a,(#F344)
	and	%10000000
	jr	z,POKEMAGI_END
	ld	a,(-1)
	cpl
	and	%11110000
	ld	b,a
	rrca
	rrca
	rrca
	rrca
	and	%00001111
	or	b
	ld	b,a
	ld	(-1),a

	ld	a,(#F344)
	and	%11
	ld	e,a
	ld	d,0
	ld	hl,#FCC5
	add	hl,de
	ld	(hl),b
POKEMAGI_END:

	;*** Inicializacion real

EXE_I2:	ld	hl,(SAVTXT)
	ld	(POINTXT),hl

	ld	hl,(MEMSIZ)
	ld	bc,(STKTOP)
	or	a
	sbc	hl,bc
	ld	(CLSTR),hl	;Espacio para cadenas 

;--- Obtencion de la tabla de rutinas de soporte del mapeador
;    de una vez por todas

	ld	a,(#FB20)	;Inicializacion de RES_Pn y RES_SETn  
	bit	0,a
	jp	z,OKGETMAP
	xor	a
	ld	de,#0402
	call	#FFCA
	or	a
	jp	z,OKGETMAP

	ld	de,ALL_SEGE
	ld	bc,16*3
	ldir

	ld	a,#FF	;Bandera que indica que hay rutinas 
	ld	(MAPRUTS),a	;del mapeador si vale #FF 

OKGETMAP:	; 

;--- Comprobamos que NestorBASIC no este ya instalado

	ld	hl,EXE_SLT0	;Copiamos la subrutina de cambio de slot
	ld	de,#BFB0	;a la pagina 2
	ld	bc,FEXESLT0-EXE_SLT0
	ldir

	ld	a,(#F341)
	call	#BFB0

	ld	hl,NESSTR
	ld	de,OCU_I-#4000
	ld	b,11
BUCCOMP:	ld	a,(de)
	cp	(hl)
	ld	a,#FF
	jr	nz,OKCOMP1
	inc	de
	inc	hl
	djnz	BUCCOMP
	;xor     a
	;jr      OKCOMP1

	ld	ix,(USRTAB)	;Si el salto de USRTAB es
	ld	a,(ix)	;#3E, #FF, #DD, #21
	cp	#3E	;es que ya esta instalado
	jr	nz,OKCOMP1
	ld	a,(ix+1)
	cp	#FF
	jr	nz,OKCOMP1
	ld	a,(ix+2)
	cp	#DD
	jr	nz,OKCOMP1
	ld	a,(ix+3)
	cp	#21
	jr	nz,OKCOMP1
	xor	a

OKCOMP1:	push	af	;A = 0 si NestorBASIC ya esta instalado
	ld	a,(#FCC1)
	call	#BFB0	;Restauramos slot 0
	pop	af
	or	a
	jp	z,YAIERR



;--- Reserva de memoria en la pagina 2 y actualizacion de HIMEM

INSTNB:	ld	hl,(HIMEM)
	ld	(OLDHIME),hl
	ld	bc,RES_F-RES_I+1
	or	a
	sbc	hl,bc
	ld	(CLDIR),hl	;Direccion para el CLEAR

	ld	a,(MSXVER)	;v1.01
	cp	3	;Por si hay ampliacion externa bajo DOS 1
	jr	c,NOTR
	ld	a,(#F344)
	ld	(#F341),a
	ld	(#F342),a
NOTR:	;

;--- Establecimiento del primer USR y ejecucion del texto BASIC
;    que hace el CLEAR y crea la matriz de parametros P

	ld	hl,CONTEX
	ld	(USRTAB),hl
	ld	hl,BASICTXT
	jp	NEWSTT

CONTEX:	ld	hl,(CLDIR)	;Aqui continua la ejecucion
	ld	(USRTAB),hl	;tras la linea BASIC

;--- Inicializacion de la parte residente y copia en la pagina 3

	ld	c,_CURDRV	;Colocamos en NBSTR la unidad actual...
	call	#F37D
	add	"A"
	ld	(NBSTR),a

	call	GETDOSV
	ld	a,b
	cp	1
	jr	z,OKNPATH

	ld	a,"\"	;...y el directorio, si estamos en DOS 2
	ld	(NBSTR+2),a
	ld	b,0
	ld	c,_GETCD
	ld	de,NBSTR+3
	call	#F37D

	ld	hl,NBSTR+3
	ld	a,(hl)
	or	a
	jr	z,LDIRNB
BUCNBP:	inc	hl
	ld	a,(hl)
	or	a
	jr	nz,BUCNBP
	ld	a,"\"
	ld	(hl),a
	inc	hl
LDIRNB:	ex	de,hl
	ld	hl,NBNAME
	ld	bc,11
	ldir

OKNPATH:	ld	hl,(USRTAB)
	ld	a,l
	ld	(RES_IX+2),a	;Para que se cargue en IX
	ld	(RES_INTX+2),a
	ld	a,h
	ld	(RES_IX+3),a
	ld	(RES_INTX+3),a

	ld	a,(MAPRUTS)	;Inicializacion de RES_Pn y RES_SETn
	inc	a	;si hay rutinas de soporte del mapeador
	jp	nz,OKINIRES

	ld	hl,PUT_P1E	;Inicializacion de RES_SETn
	ld	de,RES_SET0	;y RES_GET1
	ld	bc,3
	ldir
	ld	hl,PUT_P1E
	ld	de,RES_SET1
	ld	bc,3
	ldir
	ld	hl,PUT_P1E
	ld	de,RES_SET2
	ld	bc,3
	ldir
	ld	hl,PUT_P1E
	ld	de,RES_SET3
	ld	bc,3
	ldir
	ld	hl,GET_P1E
	ld	de,RES_GET1
	ld	bc,3
	ldir

	xor	a
	ld	de,#2203
	call	#FFCA
	or	a
	jr	z,NOINLINS
	ld	a,b
	ld	(INL_CSEG+1),a
NOINLINS:	;

	call	GET_P0E	;Inicializacion de RES_Pn
	ld	(RES_P0),a
	call	GET_P1E
	ld	(RES_P1),a

	ld	hl,(USRTAB)
	ld	de,RES_P0-RES_I
	add	hl,de
	ld	(RES_RESP0+1),hl

	ld	a,#CD	;Cambiamos los JP por CALL
	ld	(RES_SET0),a
	ld	(RES_SET1),a
	ld	(RES_SET2),a
	ld	(RES_SET3),a
	ld	(RES_GET1),a

OKINIRES:	ld	hl,RES_I	;Copia en la pagina 3
	ld	de,(USRTAB)
	ld	bc,RES_F-RES_I+1
	ldir

;--- Conexion del segmento de las rutinas ocultas en la pagina 2

	call	GET_P2E
	ld	(SAVEP2),a

	ld	a,(RES_P0)	;Conectamos el segmento de la pagina 0
	call	PUT_P2E	;en la pagina 2

;--- Lectura de la parte oculta y el Turbo-BASIC del fichero
;    La parte oculta residira en el segmento original de la pag. 0 (3 en DOS 1)
;    El Turbo-BASIC residira en el segmento original de la pag. 1 (2 en DOS 1)

	ld	de,FCBE	;Apertura del fichero
	ld	c,_FOPEN
	call	#F37D
	or	a
	jp	nz,DSKERR

	ld	ix,FCBE	;Ponemos el puntero tras la
	ld	hl,EXE_F-EXE_I+7	;parte ejecutable...
	xor	a
	ld	(ix+33),l
	ld	(IX+34),h
	ld	(IX+35),a
	ld	(IX+36),a

	ld	(ix+15),a	;... y el tamanio de registro a 1
	inc	a
	ld	(ix+14),a

	ld	c,_SETDTA	;Establecemos zona de transferencia
	ld	de,#8100	;en #8100
	call	#F37D

KKKK:	ld	hl,OCU_F-OCU_I
	ld	de,FCBE	;Lectura de la parte oculta
	ld	c,_RDBLK
	call	#F37D
	or	a
	jp	nz,DSKERR

	call	SRCCHP+#4000	;v1.01: Ejecuta ahora el test de chips

	ld	a,MAXFIL
	or	a
	jr	z,NOLIMFCB
	ld	hl,FCBS	;Limpieza de los FCBs si MAXFIL > 0
	ld	de,FCBS+1
	ld	(hl),0
	ld	bc,(MAXFIL*TAMFCB)-1
	ldir

NOLIMFCB:	ld	a,(RES_P1)	;Restauramos el segmento original
	call	PUT_P2E	;de la pagina 1 para el turbo-BASIC

	ld	c,_SETDTA	;Establecemos zona de transferencia
	ld	de,#8000	;en #8000 (#8100???)
	call	#F37D

	ld	hl,7	;Pasamos la cabecera del Turbo-BASIC
	ld	de,FCBE
	ld	c,_RDBLK
	call	#F37D
	or	a
	jp	nz,DSKERR

	ld	hl,#4000	;Lectura del Turbo-BASIC
	ld	de,FCBE
	ld	c,_RDBLK
	call	#F37D
	or	a
	jp	nz,DSKERR

	ld	de,FCBE	;Cerramos el fichero
	ld	c,_FCLOSE
	call	#F37D
	or	a
	jp	nz,DSKERR

	call	ACTATR	;Actualizamos la tabla de atributos
	;                        ;del slot del Turbo-BASIC
	push	ix	;v1.01


;--- Restauracion de la pagina 2 y conexion de RAM en la pagina 1

YAVALE:	ld	a,(SAVEP2)
	call	PUT_P2E

	ld	a,(#F342)
	ld	h,#40
	call	ENASLT

	ld	a,(RES_P0)	;Conectamos el segmento de la parte oculta 
	call	PUT_P1E	;en #4000

	pop	ix
	ld	(ATR_DIR),ix	;v1.01

;--- Inicializacion de la parte oculta:
;    rutinas de acceso a los segmentos fisicos

INITFIS:	ld	a,(MAPRUTS)
	inc	a
	jp	nz,RESERV1

	ld	hl,ALL_SEGE
	ld	de,ALL_SEG
	ld	bc,16*3
	ldir

;--- Inicializacion de la parte oculta:
;    reserva de segmentos de memoria (version DOS 2)

RESERV2:	;xor     a
	;ld      (NMANS4),a

	call	MEMTEST2	;Devuelve en BC el num. de segmentos libres
	jp	c,NEMERR	;Error si no hay al menos un segmento libre
	;                        ;en el mapeador primario
	inc	bc	;Anyadimos los cuatro primeros segmentos
	inc	bc	;a la lista de idems libres
	inc	bc
	inc	bc

	ld	a,b
	or	a
	jr	nz,SOBRAN

	ld	a,c
	cp	247
	jr	nc,SOBRAN

BASTAN:	ld	(NUMSEGS),a	;NUMSEGS = Numero de segmentos encontrados
	;ld	(TOTSEGS),a     ;v1.01 (comentado)
	jr	OKSEGS1	;(maximo 247)
SOBRAN:	ld	a,247
	jr	BASTAN

OKSEGS1:	call	RES4PRIM
	ld	a,(NUMSEGS)
	sub	4	;A = Numero de segmentos a reservar    
	ld	b,a

	push	ix,bc
	xor	a
	ld	c,1
	ld	de,#2202
	call	EXTBIO	;Esta instalado NestorMan?
	;ld      d,b
	;ld      e,c
	pop	bc,ix
	or	a
	jr	z,RESBUC2
	;ld      a,(#F344)        ;Esta en el mapeador primario?
	;cp      d
	;jr      nz,RESBUC2
	;ld      a,e
	;ld      (NMANSEG),a

	push	bc,ix	;Si esta instalado,
	ld	c,7	;reserva un segmento exclusivo
	ld	de,#2202	;y lo asigna como el seg. 4
	scf		;                ;de NestorBASIC
	push	de
	call	EXTBIO
	ld	(NMANS4),a
	ld	c,3
	pop	de
	call	EXTBIO
	pop	ix
	ld	(ix),b
	ld	(ix+1),c
	pop	bc
	inc	ix	;Un segmento menos a reservar
	inc	ix	;con el metodo "clasico" de DOS 2

	push	bc,ix	;Esta instalado INS?
	ld	c,32
	ld	de,#2202
	call	EXTBIO
	or	a
	jr	z,NOINS
	ld	(INS_SLOT),a
	ld	ix,INS_SL1
	ld	(ix),c
	ld	(ix+1),b
	ld	(ix+2),e
	ld	(ix+3),d

	;inc     ix
	ld	iy,INS_SF1
	ld	b,4
BUC_GETINS:	push	bc,ix,iy	;Obtiene segmentos fisicos de INS
	ld	de,#2202
	ld	c,3
	ld	a,(ix)
	call	EXTBIO
	pop	iy,ix
	ld	(iy),c
	pop	bc
	inc	ix
	inc	iy
	djnz	BUC_GETINS

NOINS:	pop	ix,bc
	dec	b
	jr	z,ENDRESV

RESBUC2:	push	bc	;Bucle de reserva de los segmentos  
	ld	a,(#F343)	;(modo SISTEMA)
	and	%10001111
	or	%00100000
	ld	b,a
	ld	a,1	;---> EN PRUEBAS: PONER 1 EN EL DEFINITIVO
	call	ALL_SEGE
	ld	(ix),b
	ld	(ix+1),a
	inc	ix
	inc	ix
	pop	bc
	djnz	RESBUC2

ENDRESV:	ld	a,(#F342)	;Restauramos slot RAM principal
	ld	h,#40	;y segmento de rutinas ocultas en pag. 1
	call	ENASLT
	ld	a,(RES_P0)
	call	PUT_P1E

	ld	a,(NUMSEGS)	;v1.01
	ld	(TOTSEGS),a	;v1.01
	ld	ix,TABSEGS	;Actualiza la zona de datos
	ld	a,(ix+2)
	ld	(SLOT_1),a
	ld	a,(ix+3)
	ld	(SEG_1),a
	ld	a,(ix+4)
	ld	(SLOT_2),a
	ld	a,(ix+5)
	ld	(SEG_2),a
	ld	a,1
	ld	(SL_1),a
	ld	a,2
	ld	(SL_2),a

	xor	a
	jp	OKRESEG

;--- Inicializacion de la parte oculta:
;    reserva de segmentos de memoria (version DOS 1)

RESERV1:	ld	hl,(P3_ID)
	ld	de,"NI"
	call	COMP16
	jr	nz,_RESERV1

	ld	a,#FF
	ld	(HAS_INL),a

_RESERV1:	ld	hl,TABSEGS
	ld	de,512-8*2-4	;Reservaremos 256-8 segmentos como maximo
	add	hl,de
	ld	a,#FF	;Ponemos #FF en el espacio para el slot
	ld	(hl),a	;del ultimo segmento a reservar  
	ld	(ESTESLT),a

	call	RES4PRIM	;Reservamos los cuatro primeros segmentos
	ld	a,4
	ld	iy,NUMSEGS	;IY = no. de segmentos ya reservados  
	ld	(iy),4

	ld	de,EXE_F	;Buffer de 256 bytes
	call	MEMTEST1
	cp	1
	jp	z,MEMERR	;Error si la memoria no esta mapeada
	;                        ;A = No. de segmentos del mapeador primario

	ld	b,a	;Si hay INL instalado,
	ld	a,(HAS_INL)	;decrementa en 2 el num.
	or	a	;de segs. disponibles
	jr	z,BUCRES0
	dec	b
	dec	b
BUCRES0:	ld	a,b
	cp	5
	jp	c,MEMERR	;Error si no hay al menos 5 segmentos

	sub	4	;B = No. de segmentos a colocar en la tabla
	ld	b,a
	ld	c,4
BUCRES1:	ld	a,(ix)
	push	af
	ld	a,(#F344)
	call	IS_INL_SEG
	jr	c,_BUCRES1
	ld	(ix),a	;Rellena la tabla  
	ld	(ix+1),c
	inc	ix
	inc	ix
	inc	(iy)	;Incrementa no. de segmentos reservados  
_BUCRES1:	pop	af
	cp	#FF
	jr	z,FINRES1	;Termina si ya se han reservado todos  
	inc	c	;los necesarios  
	djnz	BUCRES1

MASLOTS:	call	SIGSLOT	;Ahora reserva en los siguientes slots  
	ld	c,a
	cp	#FF
	ld	a,0
	jr	z,FINRES1
	ld	a,(#F342)
	cp	c
	jr	z,MASLOTS	;Para no volver a reservar en el primario

	push	ix,iy	;Conecta el slot en la pagina 1
	ld	a,c
	ld	h,#40
	call	ENASLT
	pop	iy,ix

	ld	de,EXE_F
	call	MEMTEST1
	ld	b,a
	or	a
	jr	z,MASLOTS	;Si no es RAM o no esta mapeada,  
	cp	1	;pasamos al siguiente slot.
	jr	z,MASLOTS

	push	bc,ix,iy	;Para rellenar la tabla hemos de conectar
	ld	a,(#F342)	;el slot de la RAM principal.
	ld	h,#40
	call	ENASLT
	ld	a,(RES_P0)
	call	PUT_P1E
	pop	iy,ix,bc

	ld	c,0
BUCRES2:	ld	a,(ix)
	push	af
	ld	a,(ESTESLT)
	ld	(ix),a	;Rellena la tabla   
	ld	(ix+1),c
	inc	ix
	inc	ix
	inc	(iy)	;Incrementa no. de segmentos reservados   
	pop	af
	cp	#FF
	ld	a,0	;Termina si ya se han reservado todos   
	jr	z,FINRES1	;los necesarios  
	inc	c
	djnz	BUCRES2

	jr	MASLOTS

FINRES1:	jp	ENDRESV	;Termina actualizando zona de datos

OKRESEG:	ld	a,(NUMSEGS)

;--- Inicializacion de la parte oculta: establecimiento de VRAMCAPA y DOSVER
;    asi como CALLINL_DIR e INLDIR_DIR

FININI:	push	af

	ld	hl,(USRTAB)
	ld	de,CALL_INL-RES_I
	add	hl,de
	ld	(CALLINL_DIR+1),hl

	ld	hl,(USRTAB)
	ld	de,INL_DIR+1-RES_I
	add	hl,de
	ld	(INLDIR_DIR),hl

	ld	hl,(USRTAB)
	ld	de,INL_CSEG+1-RES_I
	add	hl,de
	ld	(INLCSEG_DIR),hl

	ld	a,(#FAFC)
	and	%00000110
	cp	4
	jr	z,GETDV	;VRAM=128K por defecto

	ld	a,64
	ld	(VRAMCAPA),a	;VRAM=64K

GETDV:	call	GETDOSV

	ld	a,b
	ld	(DOSVERP),a
	ld	a,c
	ld	(DOSVERS),a

	pop	af
	jp	NOERR

;--- Finalizacion de la inicializacion

YAIERR:	ld	hl,(USRTAB)	;Finalizacion con error:
	ld	(ERRDIR),hl	;NestorBASIC ya estaba instalado
	ld	(OLDHIME),hl
	ld	ix,(USRTAB)
	ld	a,#FF
	ld	(CERO),a	;Para no borrar la cadena identificadora
	ld	a,3
	jr	FININI3
NEMERR:	ld	a,2	;No hay al menos un segmento libre
	ld	ix,RES_I	;en el mapeador primario
	jr	FININI3
DSKERR:	ld	a,(SAVEP2)	;Error al leer NBASIC.BIN
	call	PUT_P2E
	ld	ix,RES_I
	ld	a,1
	jr	FININI3
MEMERR:	xor	a	;No hay al menos 128K de RAM
	ld	ix,RES_I
	jr	FININI3
NOERR:	ld	hl,(USRTAB)	;Terminacion sin error
	push	hl
	ld	bc,FCBR-RES_I
	add	hl,bc
	ld	(FCBRDIR),hl	;Establecimiento de FCBRDIR
	ld	hl,FCBS
	ld	de,FCBS+1
	ld	(hl),0	;Limpieza de la zona de FCBS
	ld	bc,(TAMFCB*MAXFIL)-1
	ldir
	pop	hl
	push	hl
	ld	bc,F0BUF-RES_I
	add	hl,bc
	ld	(F0BUFD),hl	;Establecimiento de F0BUFD y F1BUFD
	;ld	bc,LONF01+3	;Era +2 en 0.07
	pop	hl
	push	hl
	ld	bc,F1BUF-RES_I
	add	hl,bc
	ld	(F1BUFD),hl
	pop	hl
	push	hl
	ld	bc,RESERR-RES_I
	add	hl,bc
	ld	(RESERRD),hl	;Establecimiento de RESERRD
	push	af
	call	GETDOSV
	ld	a,b
	cp	2
	jr	c,NOALBUF	;Guarda el numero de buferes del DOS 2
	ld	b,0	;en SECBUF, y allocata solo 2
	ld	c,_BUFFER
	call	#F37D
	ld	a,b
	ld	(SECBUF),a
	ld	b,2
	ld	c,_BUFFER
	call	#F37D
NOALBUF:	pop	af,ix	;Buffers = 2
	jr	FININI2

FININI3:	ld	(ERRCODE),a

	ld	a,(ix+RES_P1-RES_I)
	ld	(SAVEIX),ix
	call	PUT_P1E	;Restauramos el segmento del Turbo-BASIC 
	ld	a,(#FCC1)	;y el slot del BASIC en pagina 1 
	ld	h,#40
	call	ENASLT

	ld	a,(CERO)
	or	a
	jr	nz,NOINUSTR
	call	GET_P2E	;Inutilizamos la cadena "NestorBASIC"
	ld	ix,(SAVEIX)	;del segmento donde se habia cargado
	push	af
	ld	a,(ix+RES_P0-RES_I)
	call	PUT_P2E
	xor	a
	ld	(OCU_I+#4000),a
	pop	af
	call	PUT_P2E

NOINUSTR:	ld	hl,(OLDHIME)
	ld	(CLDIR),hl
	ld	hl,CONTERR
	ld	(USRTAB),hl
	ld	hl,BASICTXT
	jp	NEWSTT

CONTERR:	ld	hl,(ERRDIR)	;Inutilizacion del USR
	ld	(USRTAB),hl
	ld	a,(#F342)
	ld	h,#40
	call	ENASLT
	ld	a,(ERRCODE)
	ld	ix,(SAVEIX)

FININI2:	push	af	;Finalizacion con o sin error

	ld	a,(CERO)
	or	a
	jr	nz,NOINVSEG

	ld	hl,(OLDHIME)
	ld	(OLDHIM),hl

	;ld      hl,(TABSEGS+4)   ;El SL 2 pasa a ser el 4, y viceversa
	;ld      de,(TABSEGS+8)   ;Esto no se hace si NestorBASIC
	;ld      (TABSEGS+4),de   ;ya estaba instalado
	;ld      (TABSEGS+8),hl
	ld	a,2	;*** Era 4
	ld	(SL_2),a

NOINVSEG:	ld	a,(ix+RES_P1-RES_I)
	call	PUT_P1E	;Restauramos el segmento del Turbo-BASIC
	ld	a,(#FCC1)	;y el slot del BASIC en pagina 1
	ld	h,#40
	call	ENASLT

	xor	a
	ld	(SUBFLG),a
	ld	hl,P_NAME	;Obtenemos direccion de P(0)
	call	PTRGET
	push	de
	pop	ix

	pop	af	;P(0)=segmentos, o 0 (si no hay memoria
	ld	(ix),a	;mapeada), o 1 (si hubo algun error)
	xor	a
	ld	(ix+1),a

	ld	(ix+2),VERP	;P(1)=version principal de NestorBASIC
	xor	a
	ld	(ix+3),a

	ld	(ix+4),VERT+16*VERS	;P(2)=version secundaria de NB.
	xor	a
	ld	(ix+5),a

	push	ix
	call	GETDOSV
	pop	ix
	ld	(ix+6),b	;P(3)=version principal de MSX-DOS
	xor	a
	ld	(ix+7),a

	ld	(ix+8),c	;P(4)=version secundaria de MSX-DOS
	ld	(ix+9),a

CONTBAS:	ld	hl,(POINTXT)
	ld	a,(hl)
	or	a
	jr	nz,BUSSIG
	ld	bc,5
	add	hl,bc

BUSSIG:	inc	hl
BUCBUS:	ld	a,(hl)
	or	a
	jr	z,FNDSIG
	cp	":"
	jr	z,FNDSIG
	inc	hl
	jr	BUCBUS

FNDSIG:	ld	(SAVTXT),hl
	jp	NEWSTT


;------------------------------------------------
;--- SUBRUTINAS DE LA PARTE DE INICIALIZACION ---
;------------------------------------------------

;--- IS_INL_SEG: Devuelve Cy=1 si el segmento C es de INL
;    Modifica: HL, DE

IS_INL_SEG:	ld	h,a
	ld	a,(HAS_INL)	;Hay INL instalado?
	or	a
	ld	a,h
	ret	z

	ld	a,(P3_SEG1)	;Es el seg. 1 de INL?
	cp	c
	ld	a,h
	scf
	ret	z

	ld	a,(P3_SEG2)	;Es el seg. 2 de INL?
	cp	c
	ld	a,h
	scf
	ret	z

	or	a
	ret

HAS_INL:	db	0


;--- NOMBRE: COMP16
;      Comparacion de HL con DE (16 bits en complemento a 2)
;    ENTRADA:   HL, DE = numeros a comparar
;    SALIDA:     C, NZ si HL > DE
;                C,  Z si HL = DE
;               NC, NZ si HL < DE
;    REGISTROS: -
;    VARIABLES: -
;    LLAMADAS:  -

COMP16:	call	_COMP16
	ccf
	ret

_COMP16:	ld	a,h
	sub	d
	ret	nz
	ld	a,l
	sub	e
	ret


;--- GETDOSV: Devuelve en BC la version de MSX-DOS

GETDOSV:	ld	c,_DOSVER
	call	#F37D
	ld	d,a

	ld	a,b
	cp	2
	ld	a,d
	ret	nc

	ld	bc,#0100

	ret

;--- Subrutina RES4PRIM:
;    Establece las 64K basicas del TPA como los primeros 4 segmentos reservados.

RES4PRIM:	ld	ix,TABSEGS	;Coloca los datos de los cuatro  
	ld	a,(#f341)	;segmentos basicos en la tabla  
	ld	(ix),a
	call	GET_P0E
	ld	(ix+1),a
	ld	a,(#f342)
	ld	(ix+2),a
	ld	a,(RES_P1)
	ld	(ix+3),a
	ld	a,(#f343)
	ld	(ix+4),a
	call	GET_P2E
	ld	(ix+5),a
	ld	a,(#f344)
	ld	(ix+6),a
	call	GET_P3E
	ld	(ix+7),a
	ld	bc,8
	add	ix,bc	;IX = Tabla de segmentos a reservar   
	ret

;--- Subrutina SIGSLOT:
;    Devuelve el siguiente slot cada vez que es llamada.
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


;--- Test de memoria directo (DOS 1)
;    ENTRADA:   DE = Bufer de 256 bytes que NO puede estar en la pagina 1
;                    ni puede contener la direccion #5000
;                    El mapeador ha de estar conectado en la pagina 1
;    SALIDA:    A  = Numero de segmentos
;                    0 -> El slot no contiene RAM
;                    1 -> El slot contiene RAM no mapeada
;    LLAMADAS:  -
;    REGISTROS: F, HL, BC, DE

MEMTEST1:	ld	a,(#438F)	;Comprobamos si es ROM
	ld	h,a
	cpl
	ld	(#438F),a
	ld	a,(#438F)
	cpl
	ld	(#438F),a
	cpl
	cp	h
	ld	a,0
	ret	z

	ld	hl,#4001
	call	GET_P1E	;in      a,(#FD)                   <--!!!!!
	push	af	;A  = Segmento actual en pagina 2    
	push	de	;DE = Bufer    
	ld	b,0

MT1BUC1:	ld	a,b	;Grabamos el primer byte de todas los    
	call	PUT_P1E	;out     (#FD),a          ;segmentos
	ld	a,(hl)
	ld	(de),a
	ld	a,b
	ld	(hl),a
	inc	de
	inc	b
	ld	a,b
	cp	0
	jr	nz,MT1BUC1

	call	PUT_P1E	;out     (#FD),a                   <--!!!!!
	ld	a,(hl)
	neg
	ld	(NUMSGS),a	;A = Numero de segmentos encontrados   
	ld	b,0	;    (0 para 256)    
	ld	c,a
	pop	de

MT1BUC2:	ld	a,b
	call	PUT_P1E	;out (#FD),a ;Restauramos el primer byte de
	ld	a,(de)	;todos los segmentos    
	ld	(hl),a
	inc	de
	inc	b
	ld	a,b
	cp	c
	jr	nz,MT1BUC2

	pop	af	;Restauramos segmento original    
	call	PUT_P1E	;out     (#FD),a                   <--!!!!! 
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

;--- Test de memoria DOS 2
;    ENTRADA:   -
;    SALIDA:    A  = Numero de mapeadores encontrados
;                    0 -> No hay rutinas de soporte del mapeador:
;                         hay que ejecutar el test directo
;               HL = Numero total de segmentos encontrados
;               BC = Numero de segmentos libres encontrados
;               DE = Numero de segmentos de sistema
;               Cy = 1 si no hay al menos un seg. libre en el mapeador prim.
;    REGISTROS: Todos
;    LLAMADAS:  -

MEMTEST2:	xor	a
	push	de
	pop	bc
	ld	de,#0401
	call	#FFCA

	push	hl
	pop	ix
	ld	a,(ix+2)
	or	a
	scf		;Error si no hay al menos un segmento libre
	ret	z	;en el mapeador primario

	ld	b,0
	ld	de,0
	ld	(TOTALSG),de
	ld	(FREESG),de
	ld	(SYSTSG),de
	ld	(TOTALMP),de

MT2BUC1:	ld	a,(ix)
	or	a
	jr	z,MT2END
	inc	b
	ld	a,(ix+1)
	ld	e,a
	ld	hl,(TOTALSG)
	add	hl,de
	ld	(TOTALSG),hl
	ld	a,(ix+2)
	ld	e,a
	ld	hl,(FREESG)
	add	hl,de
	ld	(FREESG),hl
	ld	a,(ix+3)
	Ld	e,a
	ld	hl,(SYSTSG)
	add	hl,de
	ld	(SYSTSG),hl
	ld	e,8
	add	ix,de
	jr	MT2BUC1

MT2END:	ld	a,b
	ld	(TOTALMP),a
	ld	hl,(TOTALSG)
	ld	bc,(FREESG)
	ld	de,(SYSTSG)
	or	a
	ret

TOTALSG:	dw	0
FREESG:	dw	0
SYSTSG:	dw	0
TOTALMP:	dw	0


;--- NOMBRE: EXE_SLT0
;      Conecta un slot en la pagina 0 sin usar ENASLT
;      Vuelve con las interrupciones inhibidas
;    ENTRADA:   A = Slot a conectar
;    SALIDA:    -
;    REGISTROS: AF
;    LLAMADAS:  -
;    VARIABLES: -

EXE_SLT0:	di
	push	hl,de,bc
	ld	c,a	;C = Slot+subslot a conectar 
	and	%00000011	;B = Slot a conectar (=C and 3) 
	ld	b,a

	in	a,(#A8)
	and	%11111100
	or	b
	ld	d,a	;D = Nuevo valor a mandar a #A8 

	ld	a,c	;Slot expandido? 
	bit	7,a
	jr	z,PUTSLPR

	ld	a,b
	rrca
	rrca
	ld	b,a	;B = Slot a conectar, en pagina 3 
	ld	a,d
	and	%00111111	;<<<<---- !!!!!!!
	or	b
	out	(#A8),a	;Slot conectado en pagina 3 

	ld	a,c
	and	%00001100
	sra	a
	sra	a	;B = Subslot a conectar 
	ld	b,a

	ld	a,(-1)	;Conexion del subslot 
	cpl
	and	%11111100
	or	b
	ld	(-1),a

	ld	a,d	;Conexion del slot 
	out	(#A8),a

	ld	hl,#FCC5
	ld	a,c
	and	%00000011	;E = Slot conectado 
	ld	e,a
	ld	d,0
	add	hl,de
	ld	a,(hl)
	and	%11111100
	or	b
	ld	(hl),a
	jr	FPSLT0

PUTSLPR:	ld	a,d
	out	(#A8),a
FPSLT0:	pop	bc,de,hl
	ret
FEXESLT0:	;

;--- Actualizacion de la tabla de atributos del slot del Turbo-BASIC

ACTATR:	ld	a,(#F342)
	ld	b,a

	and	%11
	rlca		;Slot prim *16
	rlca
	rlca
	rlca
	ld	c,a

	ld	a,b	;Slot sec *4
	and	%1100
	or	c

	ld	c,a
	ld	b,0
	ld	ix,#FCC9
	add	ix,bc
	ld	(ix+1),#20
	ret


;ACTATR:           LD      IX,#FCC9
;                  CALL    #0138            ;RSLREG
;                  AND     #30
;                  RRCA
;                  RRCA
;                  RRCA
;                  RRCA
;                  LD      C,A
;                  LD      B,A
;                  OR      A
;                  LD      DE,#0010
;                  JR      Z,JD019
;JD015:            ADD     IX,DE
;                  DJNZ    JD015
;JD019:            LD      B,#00
;                  LD      HL,#FCC1
;                  ADD     HL,BC
;                  OR      (HL)
;                  JP      P,JD040
;                  INC     HL
;                  INC     HL
;                  INC     HL
;                  INC     HL
;                  LD      C,A
;                  LD      A,(HL)
;                  AND     #30
;                  RRCA
;                  RRCA
;                  RRCA
;                  RRCA
;                  LD      B,A
;                  OR      A
;                  LD      DE,#0004
;                  JR      Z,JD03A
;JD036:            ADD     IX,DE
;                  DJNZ    JD036
;JD03A:            LD      A,(HL)
;                  AND     #30
;                  RRCA
;                  RRCA
;                  OR      C
;JD040:            LD      (IX+#01),#20
;                  RET

;---------------------------------------------------
;--- ZONA DE DATOS DE LA PARTE DE INICIALIZACION ---
;---------------------------------------------------

FCBE:	db	0
	db	"NBASIC  BIN"
	ds	25

MAPRUTS:	db	0	;Se pone a #FF si hay rutinas de soporte de
	;                        ;mapeador de memoria

SAVEIX:	dw	0
OLDHIME:	dw	0	;Antiguo HIMEM
SAVEP2:	db	0
ERRCODE:	db	0
ERRDIR:	dw	#475A	;(USRTAB) si error 3; si no, #475A
CERO:	db	0

NESSTR:	db	"NestorBASIC"
NBNAME:	db	"NBASIC.BIN",0

ALL_SEGE:	ds	3
FRE_SEGE:	ds	3
RD_SEGE:	ds	3
WR_SEGE:	ds	3
CAL_SEGE:	ds	3
CALLSE:	ds	3
PUT_PHE:	ds	3
GET_PHE:	ds	3
PUT_P0E:	jp	PUT_P0E2
GET_P0E:	jp	GET_P0E2
PUT_P1E:	jp	PUT_P1E2
GET_P1E:	jp	GET_P1E2
PUT_P2E:	jp	PUT_P2E2
GET_P2E:	jp	GET_P2E2
PUT_P3E:	jp	PUT_P3E2
GET_P3E:	jp	GET_P3E2

PUT_P0E2:	out	(#FC),a
	ld	(GUARDP0E),a
	ret
GET_P0E2:	ld	a,(GUARDP0E)
	ret
PUT_P1E2:	out	(#FD),a
	ld	(GUARDP1E),a
	ret
GET_P1E2:	ld	a,(GUARDP1E)
	ret
PUT_P2E2:	out	(#FE),a
	ld	(GUARDP2E),a
	ret
GET_P2E2:	ld	a,(GUARDP2E)
	ret
PUT_P3E2:	ret
GET_P3E2:	ld	a,(GUARDP3E)
	ret

GUARDP0E:	db	3
GUARDP1E:	db	2
GUARDP2E:	db	1
GUARDP3E:	db	0

POINTXT:	dw	0

;--- Programa BASIC ":CLEAR xx,&Hyyyy:DEFINT P:DIM P(DIMP):P(0)=USR(0)"

BASICTXT:	db	":",#92," ",#1C	;"CLEAR "
CLSTR:	ds	2	;Espacio para cadenas
	db	",",#0C	",&H"
CLDIR:	ds	2	;Direccion para el CLEAR
	db	":",#AC," P"	;"DEFINT P"
	db	":",#86," P(",#0F,DIMP,")"	;"DIM P(DIMP)"
	db	":P(",#11,")",#EF,#DD,"(",#11,")",0	;"P(0)=USR(0)"

;***************************************************************************
;******************                                    *********************
;******************   PARTE RESIDENTE EN LA PAGINA 2   *********************
;******************                                    *********************
;***************************************************************************

;La parte de inicializacion pone la direccion real de RES_I en RES_I+2,
;para que sea cargada en IX nada mas ejecutarse.
;Tambien establece RES_Pn y RES_SETPn.
;Una vez inicializada, las variables RES_Pn pueden usarse desde el resto del
;programa ejecutable.
;Esta parte sera llamada en dos casos: cuando se ejecute una funcion y
;en cada interrupcion del reloj, si hay alguna rutina residente en marcha
;(reproduccion de musica o efecto PSG, o rutina de usuario).
;En ambos casos la ejecucion difiere ligeramente, esto es controlado
;por la variable INTOFUN.
;Cuando se ejecuta una funcion el punto de entrada es RES_I.
;Cuando se responde a la interrupcion el punto de entrada es RES_INT.

RES_I:	ld	a,#FF
RES_IX:	ld	ix,#0000
	ld	(ix+FUN_FLG-RES_I),a	;FUN_FLG=#FF: funcion ejecutando
	jr	CONTRES1

RES_INT:	call	#0000	;Punto de ejecucion para la rutina de
	di		;interrupcion
	push	af,bc,de,hl,ix,iy
	exx
	ex	af,af
	push	af,bc,de,hl
	exx
	ex	af,af
RES_INTX:	ld	ix,#0000	;Ejecuta la rutina de interrupcion solo si
	ld	a,#FF
	ld	(ix+INT_FLG-RES_I),a	;INT_FLG=#FF: int. ejecutando
RES_GET1:	in	a,(#FD)
	nop
	ld	c,a
	ld	a,(#F313)
	or	a
	ld	a,c
	jr	nz,NOMASKIN	;DOS 1: el segmento sera el 2 o el 3
	and	%00000011	;Esto es para evitar problemas en el TR
NOMASKIN:	ld	(ix+INT_P1-RES_I),a
	ld	a,#FF
	di
	jr	CONTRES1

P_NAME:	db	"P(",#11,")",0	;"P(0)" 
F0_NAME:	db	"F$(",#11,")",0	;"F$(0)" 
F1_NAME:	db	"F$(",#12,")",0	;"F$(1)" 
RES_P0:	db	3	;Segmentos originales en paginas 0 y 1
RES_P1:	db	2
INT_P1:	db	0	;Segmento en P. 1 al ejecutarse la int.
SLTSTAT:	db	0	;Slot original en la pagina 1 
SLTINT:	db	0	;Slot original pagin a 1 (interrupcion) 
INT_FLG:	db	0	;#FF si se esta atendiendo la int.
FUN_FLG:	db	0	;#FF si se esta ejecutando una funcion
OLD_INT:	ds	5	;Interrupcion original 
FCBR:	ds	TAMFCB

CONTRES1:	ld	a,(ix+INT_FLG-RES_I)
	or	a
	jr	nz,NOGETBC
	ld	a,(#F7F8)	;BC = Parametro del USR 
	ld	c,a	;(lo cogemos si no estamos en int.)
	ld	a,(#F7F9)
	ld	b,a
	push	bc
NOGETBC:	;

	di
	in	a,(#A8)	;Guardamos el estado de la pagina 1
	and	%00001100
	sra	a
	sra	a
	ld	c,a	;C = Slot pagina 1
	ld	b,0
	ld	hl,#FCC1
	add	hl,bc
	ld	a,(hl)
	bit	7,a
	ld	a,c
	jr	z,GSLOT
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	and	%00001100
	or	c
	or	%10000000
GSLOT:	ld	c,a
	ld	a,(ix+INT_FLG-RES_I)
	or	a
	jr	z,GSLOTF
GSLOTI:	ld	(ix+SLTINT-RES_I),c
	ld	b,4
	ld	hl,#FB22
BUCNOIN:	ld	a,(hl)	;No ejecuta la interrupcion si en P. 1
	or	a	;esta alguna controladora de disco activa
	jr	z,CONTRES2
	cp	c
	jr	z,FINRESI
	inc	hl
	inc	hl
	djnz	BUCNOIN
	jr	CONTRES2
GSLOTF:	ld	(ix+SLTSTAT-RES_I),c

	ld	a,(#FCC1)
	ld	h,#40
	push	ix
	call	ENASLT
	pop	ix

	xor	a
	ld	(SUBFLG),a
	push	ix
	pop	hl
	ld	bc,P_NAME-RES_I
	add	hl,bc
	call	PTRGET
	di
	push	de	;DE = Direccion de la matriz de parametros

CONTRES2:	ld	h,#40	;Conectamos RAM en pagina 1
	ld	a,(#F342)
	push	ix
	call	ENASLT
	pop	ix

	di
	ld	a,(ix+RES_P0-RES_I)
RES_SET1:	out	(#FD),a
	nop

	jr	RESSET12
FINRESI:	jr	FINRESI2

RESSET12:	ld	a,(ix+INT_FLG-RES_I)
	or	a
	jr	z,CALLOCF

CALLOCI:	push	ix	;Salto a la pagina 1 (interrupcion)
	call	OCU_INT
	pop	ix
	jr	CONTRES4

CALLOCF:	pop	hl,bc	;HL=Dir. matriz parametros, BC=parametro
	push	ix
	ei
	call	OCU_I2	;Salto a la pagina 2 (funcion)
	pop	ix
	push	hl	;HL=Valor a devolver por el USR

CONTRES3:	;                        ;Restaura segmento del Turbo-BASIC en P. 1,
	ld	a,(ix+RES_P1-RES_I)	;(funcion), o
	jr	RES_SET0	;el que habia antes (interrupcion)
CONTRES4:	ld	a,(ix+INT_P1-RES_I)
RES_SET0:	out	(#FD),a
	nop

	di		;Dejamos la pagina 1 como estaba
	ld	a,(ix+INT_FLG-RES_I)	;(slot del BASIC o del XBASIC)
	or	a
	jr	z,RESTP1F
RESTP1I:	ld	a,(ix+SLTINT-RES_I)
	jr	OKREST
RESTP1F:	ld	a,(ix+SLTSTAT-RES_I)
OKREST:	ld	h,#40
	call	ENASLT
	xor	a

	ld	a,(ix+INT_FLG-RES_I)
	or	a
	jr	z,FINRESF

FINRESI2:	xor	a	;Finalizacion (interrupcion)
	ld	(ix+INT_FLG-RES_I),a
	exx
	ex	af,af
	pop	hl,de,bc,af
	exx
	ex	af,af
	pop	iy,ix,hl,de,bc,af
	ei
	ret

FINRESF:	ld	a,2	;Finalizacion (funcion)
	ld	(VALTYP),a
	pop	hl
	ld	(#F7F8),hl
	xor	a
	ld	(ix+FUN_FLG-RES_I),a

	ret

RESERR:	exx		;Salto del nuevo gancho de la rut. de error
	ld	a,(#F342)
	ld	h,#40
	call	ENASLT
	exx
	jp	CONTEDC

	db	34
F0BUF:	ds	LONF01+1	;Buferes para F$(0) y F$(1)
	db	34
	db	34
F1BUF:	ds	LONF01+1	;@@@        ;Era +1
	db	34

CAL_SEGR:	push	af	;Llamada a una rutina en un segmento
	ld	a,iyh	;de la pagina 1, para DOS 1
	out	(#FD),a	;Es llamada por CAL_SEGO con HL en la pila
	pop	af
	push	bc
	ld	hl,(USRTAB)
	ld	bc,CALSEGR2-RES_I
	add	hl,bc
	pop	bc
	ex	(sp),hl
	jp	(ix)
CALSEGR2:	push	af
	ld	a,3
	out	(#FD),a
	pop	af
	ret

	;--- Llamada a una funcion de INL.
	;    Entrada: Registros establecidos
	;             y direccion a llamar en HL'

CALL_INL:	push	af
INL_CSEG:	ld	a,0
RES_SET2:	out	(#FD),a
	nop
	pop	af

INL_DIR:	call	0	;Se establece al realizar la llamada

	push	af
RES_RESP0:	ld	a,(RES_P0)	;Se establece durante la instalacion
RES_SET3:	out	(#FD),a
	nop

	pop	af
	ret

NBSTR:	db	" :NBASIC.BIN",0
	ds	70

RES_F:	;

EXE_F:	;                        ;LA PARTE RESIDENTE ESTA INCLUIDA EN LA
	;                        ;EJECUTABLE

;************************************************************************
;******************                                 *********************
;******************   PARTE OCULTA EN UN SEGMENTO   *********************
;******************                                 *********************
;************************************************************************

OCULTA:	org	#4100

OCU_I:	db	"NestorBASIC ",VERP+"0",".",VERS+"0",VERT+"0"
DIRTABS:	dw	TABSEGS	;#4110
INT_DATA:	db	0

;--- Tabla de salto: rutinas para manejo de slots y segmentos

C4113:	jp	PUTSLOT0
C4116:	jp	CHKSLE
C4119:	jp	CHKSLFF
C411C:	jp	CHKSLV
C411F:	jp	VTOSL
C4122:	jp	GET_SF
C4125:	jp	GET_SLT
C4128:	jp	READ_SL
C412B:	jp	WRITE_SL
C412E:	jp	LDIRSS

;--- Tabla de salto: rutinas para gestion de la VRAM

C4131:	jp	CHKBV
C4134:	jp	SET_RD
C4137:	jp	SET_WR
C413A:	jp	LDIRVR
C413D:	jp	LDIRRV
C4140:	jp	LDIRVV
C4143:	jp	FILLVR
C4146:	jp	BLK_CLS
C4149:	jp	BLK_COL
C414C:	jp	BLK_TIM
C414F:	jp	BLK_ON
C4152:	jp	BLK_OF
C4155:	jp	C_BLKAD
C4158:	jp	C_STBT

;--- Obtencion de informacion sobre las interrupciones

C415B:	jp	GINFOUS
C415E:	jp	GINFOSFX
C4161:	jp	GINFOMUS
TIPOREP:	db	0	;@@@        ;En #4164
UGETF01:	jp	_UGETF01	;#4165
USETF0:	jp	_USETF0	;#4168
USETF1:	jp	_USETF1	;#416B
F0BUFD:	dw	0	;#416E
F1BUFD:	dw	0	;#4170

SL_2:	db	2	;Segmento logico conectado a la pagina 2, #4172
NMANS4:	db	0	;Num. SL NMAN de SL 4, #4173
INS_SL1:	db	0	;#4174
INS_SL2:	db	0	;#4175
INS_SL3:	db	0	;#4176
INS_SL4:	db	0	;#4177

INS_SLOT:	db	0
INS_SF1:	db	0
INS_SF2:	db	0
INS_SF3:	db	0
INS_SF4:	db	0

OCU_I2:	jp	OCU_EXE	;Salto al punto de ejecucion
OCU_INT:	jp	INT_EXE	;Salto a la rutina de interrupcion


;----------------------------------------
;--- ZONA DE DATOS DE LA PARTE OCULTA ---
;----------------------------------------

FUNCION:	dw	0	;Funcion a ejecutar (parametro del USR)
FUNCION_ANT:	dw	0	;@@@    ;Funcion anterior
DIRP:	dw	0	;Direccion de la matriz de parametros
PARAM:	ds	(DIMP+1)*2	;Copia del contenido de la mat. parametros
DOSVERP:	db	1	;Version principal de MSX-DOS
DOSVERS:	db	0	;Version secundaria de MSX-DOS
VRAMCAPA:	db	128	;Capacidad de la VRAM en Kb

LONRES:	dw	RES_F-RES_I+1	;Longitud de la parte residente
OLDHIM:	dw	0	;Antiguo HIMEM
SL_1:	db	0	;Segmento logico conectado a la pagina 1 
SLOT_1:	db	0
SEG_1:	db	0
;SL_2:	db	2	;Segmento logico conectado a la pagina 2 (movido tras TIPOREP)
SLOT_2:	db	0
SEG_2:	db	0
TOTSEGS:	db	0	;Segmentos disponibles reales
NUMSEGS:	db	0	;Numero de segmentos disponibles
TABSEGS:	ds	512-8*2	;Parejas slot + segmento
FILENAME:	ds	64	;Nombre del fichero a abrir

PVRAM:	ds	3	;Direccion VRAM apuntada por el VDP

;FCBS:      equ     OCU_F            ;FCBS al final de la parte oculta
;BUFER:     equ     FCBS+(MAXFIL*TAMFCB)
NUMFILES:	db	0	;Numero de ficheros abiertos
FCBRDIR:	dw	0	;Direccion del FCB en la parte residente
;F0BUFD:	dw	0	;Direccion de F0BUF, movido tras TIPOREP
;F1BUFD:	dw	0	;Direccion de F1BUF
SECBUF:	db	0

;-------------------------------------------------
;--- RUTINAS PARA ESTABLECER SEGMENTOS FISICOS ---
;--------------------------------------------------

;En DOS 2 se usan las rutinas del DOS en lugar de estas.

ALL_SEG:	scf
	ret
	nop
FRE_SEG:	scf
	ret
	nop
RD_SEG:	ret
	nop
	nop
WR_SEG:	ret
	nop
	nop
CAL_SEG:	jp	CAL_SEGO
CALLS:	ret
	nop
	nop
PUT_PH:	jp	PUT_PHO
GET_PH:	jp	GET_PHO
PUT_P0:	jp	PUT_P0O
GET_P0:	jp	GET_P0O
PUT_P1:	jp	PUT_P1O
GET_P1:	jp	GET_P1O
PUT_P2:	jp	PUT_P2O
GET_P2:	jp	GET_P2O
PUT_P3:	jp	PUT_P3O
GET_P3:	jp	GET_P3O

PUT_PHO:	PUSH	AF	;Conecta el segmento A en la pagina que
	LD	A,H	;contiene la direccion HL. 
	RLA		;El slot del mapeador ha de estar 
	RLA		;conectado en la pagina correspondiente. 
	RLA		;No modifica ningun registro. 
	AND	%00000011
	CP	1
	JR	Z,PP1
	CP	2
	JR	Z,PP2
	CP	3
	JR	Z,PP3
PP0:	POP	AF
	JP	PUT_P0O
PP1:	POP	AF
	JP	PUT_P1O
PP2:	POP	AF
	JP	PUT_P2O
PP3:	POP	AF
	JP	PUT_P3O

GET_PHO:	PUSH	AF	;Devuelve en A el segmento conectado
	LD	A,H	;a la pagina que contiene la direccion 
	RLA		;indicada en HL. 
	RLA		;No modifica ningun registro excepto A. 
	RLA
	AND	%00000011
	CP	1
	JR	Z,GP1
	CP	2
	JR	Z,GP2
	CP	3
	JR	Z,GP3
GP0:	POP	AF
	JP	GET_P0O
GP1:	POP	AF
	JP	GET_P1O
GP2:	POP	AF
	JP	GET_P2O
GP3:	POP	AF
	JP	GET_P3O

PUT_P0O:	LD	(GUARDAP0),A	;Conecta el segmento A en la pagina 0.
	OUT	(#FC),A	;El slot del mapeador ha de estar conecta
	RET		;No modifica ningun registro. 

PUT_P1O:	LD	(GUARDAP1),A	;Idem para la pagina 1
	OUT	(#FD),A
	RET

PUT_P2O:	LD	(GUARDAP2),A	;Idem para la pagina 2
	OUT	(#FE),A
	RET

PUT_P3O:	RET		;No se puede cambiar la pagina 3
	DW	0

GET_P0O:	LD	A,(GUARDAP0)	;Devuelve en A el segmento conectado
	RET		;en la pagina 0. No modifica registros. 

GET_P1O:	LD	A,(GUARDAP1)	;Idem para la pagina 1
	RET

GET_P2O:	LD	A,(GUARDAP2)	;Idem para la pagina 2
	RET

GET_P3O:	LD	A,(GUARDAP3)	;Idem para la pagina 3
	RET

CAL_SEGO:	push	hl,bc
	ld	hl,(USRTAB)
	ld	bc,CAL_SEGR-RES_I
	add	hl,bc	;HL = Dir. de CAL_SEGR
	pop	bc
	jp	(hl)


GUARDAP3:	DB	0
GUARDAP2:	DB	1
GUARDAP1:	DB	2
GUARDAP0:	DB	3

;-----------------------------------------------
;--- RUTINAS DE GESTION DE SEGMENTOS LOGICOS ---
;-----------------------------------------------

;El segmento logico #FF se refiere a la memoria del BASIC (#8000-#FFFF),
;con independencia del SL conectado a la pagina 2.

;Los segmentos logicos NUMSEGS a NUMSEGS+7 se refieren a la VRAM.


;--- NOMBRE: PUTSLOT0
;      Conecta un slot en la pagina 0 sin usar ENASLT
;      Vuelve con las interrupciones inhibidas
;    ENTRADA:   A = Slot a conectar
;    SALIDA:    -
;    REGISTROS: AF
;    LLAMADAS:  -
;    VARIABLES: -

PUTSLOT0:	di
	push	hl,de,bc
	ld	c,a	;C = Slot+subslot a conectar
	and	%00000011	;B = Slot a conectar (=C and 3)
	ld	b,a

	in	a,(#A8)
	and	%11111100
	or	b
	ld	d,a	;D = Nuevo valor a mandar a #A8

	ld	a,c	;Slot expandido?
	bit	7,a
	jr	z,OCU_PPR

	ld	a,b
	rrca
	rrca
	ld	b,a	;B = Slot a conectar, en pagina 3
	ld	a,d
	or	b
	out	(#A8),a	;Slot conectado en pagina 3

	ld	a,c
	and	%00001100
	sra	a
	sra	a	;B = Subslot a conectar
	ld	b,a

	ld	a,(-1)	;Conexion del subslot
	cpl
	and	%11111100
	or	b
	ld	(-1),a

	ld	a,d	;Conexion del slot
	out	(#A8),a

	ld	hl,#FCC5
	ld	a,c
	and	%00000011	;E = Slot conectado
	ld	e,a
	ld	d,0
	add	hl,de
	ld	a,(hl)
	and	%11111100
	or	b
	ld	(hl),a
	jr	OCU_FPS

OCU_PPR:	ld	a,d
	out	(#A8),a
OCU_FPS:	pop	bc,de,hl
	ret


;--- NOMBRE: FREESEG
;      Libera la memoria reservada
;    ENTRADA:   -
;    SALIDA:    -
;    REGISTROS: Todos
;    LLAMADAS:  -
;    VARIABLES: TABSEGS, NUMSEGS

FREESEG:	ld	de,#0402	;No hace nada si DOS 1 
	xor	a
	call	#FFCA
	or	a
	ret	z

	;ld      hl,(TABSEGS+4)   ;Restauramos la correspondecia original
	;ld      de,(TABSEGS+8)   ;de los SL 2 y 4
	;ld      (TABSEGS+4),de
	;ld      (TABSEGS+8),hl
	ld	a,2
	ld	(SL_2),a

	ld	ix,TABSEGS+8
	ld	a,(NUMSEGS)
	cp	5
	ret	c	;Termina si no hay mas de 4 segmentos 
	sub	4	;resevados 
	ld	b,a

	ld	a,(NMANS4)	;Si estaba instalado NMAN,
	or	a	;liberamos el SL 4 a traves del idem
	jr	z,BUCFRE
	push	ix,bc
	ld	c,8
	call	NESMAN
	pop	bc,ix
	inc	ix
	inc	ix
	dec	b
	jr	z,BUCFREND

BUCFRE:	push	bc
	ld	b,(ix)
	ld	a,(ix+1)
	call	FRE_SEG
	inc	ix
	inc	ix
	pop	bc
	djnz	BUCFRE

BUCFREND:	ld	a,4	;Ahora solo estan disponibles los
	ld	(NUMSEGS),a	;cuatro primeros segmentos 
	ret


;--- NOMBRE: CHKSLE
;      Comprueba si un numero de segmento logico es valido
;      NO reconoce como validos los SL equivalentes a VRAM
;    ENTRADA:   A = Segmento logico
;    SALIDA:    Cy= 1 -> El segmento logico existe
;               Cy= 0 -> El segmento logico no existe
;    REGISTROS: F
;    LLAMADAS:  -
;    VARIABLES: NUMSEGS

CHKSLE:	push	hl
	ld	hl,NUMSEGS
	cp	(hl)
	pop	hl
	ret


;--- NOMBRE: CHKSLFF
;      Comprueba si un segmento logico es el #FF (RAM del BASIC),
;      en ese caso lo convierte al segmento adecuado.
;    ENTRADA:   A  = Segmento logico
;               HL = Direccion
;    SALIDA:    A  = Segmento real si era el #FF
;    REGISTROS: F
;    LLAMADAS:  -
;    VARIABLES: SL_2

CHKSLFF:	cp	#FF
	ret	nz

	bit	6,h
	ld	a,3
	ret	nz	;Si HL>=#C000 -> SL 3
	ld	a,(SL_2)	;Si HL< #C000 -> SL actual pagina 2
	ret


;--- NOMBRE: CHKSLV
;      Comprueba si un SL corresponde a VRAM.
;    ENTRADA:   A  = Segmento logico
;               HL = Direccion
;    SALIDA:    Si es VRAM:
;                  A  = Bloque VRAM
;                  HL = Direccion VRAM
;                  Cy = 1
;               Si no es VRAM:
;                  A, HL inalterados
;                  Cy = 0
;    REGISTROS: -
;    LLAMADAS:  -
;    VARIABLES: NUMSEGS, VRAMCAPA

CHKSLV:	callint	_CHKSLV

_CHKSLV:	di		;Si es el 255 no es VRAM
	cp	#FF
	ret	z

	push	hl
	ld	(SAVSL),a
	ld	hl,NUMSEGS	;Comprobamos si A > NUMSEGS, 
	cp	(hl)	;si no volvemos con Cy = 0 
	pop	hl
	ccf
	ret	nc

	push	bc
	ld	c,a
	ld	a,(VRAMCAPA)
	srl	a
	srl	a
	srl	a
	srl	a
	ld	b,a	;B = Paginas VRAM, 4 o 8  

	ld	a,(NUMSEGS)
	sub	c
	neg		;C = Numero de SL - NUMSEGS 
	ld	c,a
	ld	(RELSL),a

	cp	b	;Finalizacion con Cy=0 si C >= B 
	jr	nc,FINCHV

	ld	a,h
	and	%00111111
	ld	h,a
	ld	a,c
	and	%00000011	;Adaptamos direccion 
	rrca
	rrca
	cpl
	and	%11000000
	or	h
	ld	h,a

	pop	bc
	ld	a,(VRAMCAPA)	;Si hay 64K VRAM, ya esta 
	cp	64
	ld	a,0
	scf
	ret	z

	ld	a,(RELSL)
	cp	4
	ld	a,1
	ret	c
	xor	a
	scf
	ret

FINCHV:	pop	bc
	ld	a,(SAVSL)
	or	a
	ret

SAVSL:	db	0
RELSL:	db	0


;--- NOMBRE: VTOSL
;      Convierte una direccion VRAM en su SL correspondiente
;    ENTRADA:   A  = Bloque VRAM
;               HL = Direccion VRAM
;    SALIDA:    A  = Segmento logico equivalente
;               HL = Direccion RAM equivalente
;               Cy = 1 -> A=1 pero solo hay 64K VRAM
;    REGISTROS: F
;    LLAMADAS:  -
;    VARIABLES: VRAMCAPA, NUMSEGS

VTOSL:	or	a
	jr	z,V2SLNO1
	ld	a,(VRAMCAPA)	;Hay que volver con error?
	cp	64
	scf
	ret	z
	ld	a,1

V2SLNO1:	push	bc,af
	ld	a,h
	ld	c,h
	and	%00111111	;Conversion de la direccion  
	ld	h,a

	ld	a,c
	and	%11000000
	rlca
	rlca
	xor	%11
	and	%11
	ld	c,a
	ld	a,(NUMSEGS)
	add	c	;Obtencion del SL  
	ld	c,a

	pop	af	;Sumamos 4 al SL si era el bloque 0 
	or	a	;y hay 128K VRAM  
	ld	a,c
	jr	nz,FINV2SL
	ld	b,a
	ld	a,(VRAMCAPA)
	cp	128
	ld	a,b
	jr	nz,FINV2SL
	add	4

FINV2SL:	pop	bc
	or	a
	ret


;--- NOMBRE: CHKFF01
;      Si el SL indicado en P(0) no es #FF,
;      convierte la direccion indicada en P(1) al rango #0000-#3FFF.
;    ENTRADA:   IX = PARAM
;               IY = (DIRP)
;    REGISTROS: AF'
;    LLAMADAS:  -
;    VARIABLES: -

CHKFF01:	ex	af,af
	ld	a,(ix)
	inc	a
	jr	z,ESFF

	res	7,(iy+3)
	res	6,(iy+3)

ESFF:	ex	af,af
	ret


;--- NOMBRE: CHKFF23
;      Si el SL indicado en P(2) no es #FF,
;      convierte la direccion indicada en P(3) al rango #0000-#3FFF.
;    ENTRADA:   IX = PARAM
;               IY = (DIRP)
;    REGISTROS: AF'
;    LLAMADAS:  ESFF
;    VARIABLES: -

CHKFF23:	ex	af,af
	ld	a,(ix+4)
	inc	a
	jr	z,ESFF

	res	7,(iy+7)
	res	6,(iy+7)

	jp	ESFF


;--- NOMBRE: DIRTOP2
;      Transforma una direccion a la pagina 2
;    ENTRADA:   HL = Direccion
;    SALIDA:    HL = Direccion modificada
;    REGISTROS: F
;    LLAMADAS:  -
;    VARIABLES: -

DIRTOP2:	push	af
	ld	a,h
	and	%00111111
	or	%10000000
	ld	h,a
	pop	af
	ret


;--- NOMBRE: GET_SF
;      Obtiene el segmento fisico y el slot
;      correspondientes a un segmento logico
;    ENTRADA:   A = Segmento logico
;    SALIDA:    A = Segmento fisico
;               B = Slot (#FF -> Segmento logico inexistente)
;    REGISTROS: AF, B
;    LLAMADAS:  CHKSLE
;    VARIABLES: NUMSEGS, TABSEGS

GET_SF:	call	CHKSLE	;Error si el segmento logico no existe
	ld	b,#FF
	ret	nc

	push	hl,bc
	ld	c,a	;Obtiene segmento fisico correspondiente  
	ld	b,0	;a un segmento logico  
	sla	c	;Entrada: A=segmento logico  
	rl	b	;Salida: A=segmento fisico, B=slot  
	ld	hl,TABSEGS	;Modifica AF y B 
	add	hl,bc
	ld	a,(hl)
	ld	b,a
	inc	hl
	ld	a,(hl)

	pop	hl	;Recupera C 
	ld	c,l
	pop	hl
	ret


;--- NOMBRE: GET_SLT
;      Obtiene el slot conectado a la pagina 1 o 2
;    ENTRADA:   A  = Pagina (1 o 2)
;    SALIDA:    B  = Slot
;    REGISTROS: F, C
;    LLAMADAS:  -
;    VARIABLES: EXPTBL

GET_SLT:	callint	_GETSLT

_GETSLT:	di
	and	%11
	ld	(PG1O2),a
	push	hl
	in	a,(#a8)
	rrca
	rrca
	ld	b,a
	ld	a,(PG1O2)
	cp	1
	ld	a,b
	jr	z,GSLTOK1
	rrca
	rrca

GSLTOK1:	and	%11
	ld	c,a
	ld	b,0
	ld	hl,#FCC1
	add	hl,bc
	ld	a,(hl)
	and	#80
	or	c
	ld	c,a
	inc	hl
	inc	hl
	inc	hl
	inc	hl

	ld	a,(PG1O2)
	cp	1
	ld	a,(hl)
	jr	z,GSLTP1
GSLTP2:	and	%110000
	rrca
	rrca
	jr	GSLTOK2
GSLTP1:	and	%1100
GSLTOK2:	or	c
	ld	b,a
	pop	hl
	ret

PG1O2:	db	0


;--- NOMBRE: PUT_SL2
;      Conecta un segmento logico en la pagina 2
;      Habilita las interrupciones
;    ENTRADA:   A  =  Segmento logico
;    SALIDA:    A  =  0  -> Segmento logico conectado
;               A  = #FF -> Segmento logico inexistente
;    REGISTROS: AF, BC, DE, HL
;    LLAMADAS:  GET_SF, ENASLT, PUT_P2
;    VARIABLES: SL_2, SLOT_2, SEG_2

PUT_SL2:	callint	_PUTSL2

_PUTSL2:	di
	push	af
	call	GET_SF
	ld	c,a	;C = Segmento fisico  
	ld	a,b	;B = Slot  
	cp	#FF
	jr	z,FPTSL2

	ld	hl,SLOT_2
	cp	(hl)
	jr	z,OKPSL2
	ld	h,#80
	push	ix,iy,bc	;Conecta el slot solo si  
	call	ENASLT	;no esta conectado ya  
	pop	bc,iy,ix

OKPSL2:	ld	a,c	;Actualiza la zona de datos 
	call	PUT_P2
	pop	af
	ld	(SL_2),a
	ld	a,b
	ld	(SLOT_2),a
	ld	a,c
	ld	(SEG_2),a
	xor	a
	ret

FPTSL2:	pop	hl
	ret

;TEMPSL2:   db      0


;--- NOMBRE: READ_SL
;      Lee un dato de un segmento logico
;    ENTRADA:   A  = Segmento logico
;               HL = Direccion (0-#3FFF)
;    SALIDA:    A  = Dato
;    REGISTROS: F, AF'
;    LLAMADAS:  PUT_SL1, DIRTOP2
;    VARIABLES: OR_SL1

READ_SL:	callint	_READSL

_READSL:	di
	push	bc,de,hl
	ex	af,af	;Guardamos segmento logico actual
	ld	a,(SL_2)	;de la pagina 2
	ld	(SAVSLRS),a
	ex	af,af

	push	hl
	call	PUT_SL2	;Conectamos el segmento en la pagina 2
	pop	hl

	call	DIRTOP2	;Convertimos la direccion
	ld	a,(hl)	;a su equivalente en la pagina 2

	push	af
	ld	a,(SAVSLRS)	;Restauramos segmento logico original
	;                        ;en la pagina 2
	call	PUT_SL2
	pop	af
	pop	hl,de,bc

	ret

SAVSLRS:	db	0


;--- NOMBRE: WRITE_SL
;      Lee un dato de un segmento logico
;      Habilita las interrupciones
;    ENTRADA:   A  = Segmento logico
;               E  = Dato
;               HL = Direccion (0-#3FFF)
;    SALIDA:    -
;    REGISTROS: F, AF'
;    LLAMADAS:  PUT_SL2, DIRTOP2
;    VARIABLES: OR_SL2

WRITE_SL:	callint	_WRITESL

_WRITESL:	di
	push	af,bc,de,hl	;Guardamos segmento logico actual
	ex	af,af
	ld	a,(SL_2)
	ld	(SAVSLWS),a
	ex	af,af

	push	hl,de
	call	PUT_SL2	;Conectamos el segmento en la pagina 2
	pop	de,hl

	call	DIRTOP2	;Convertimos la direccion
	;                        ;a su equivalente en la pagina 2
	ld	(hl),e	;Leemos el dato

	ld	a,(SAVSLWS)	;Restauramos segmento logico original
	call	PUT_SL2	;en la pagina 2
	pop	hl,de,bc,af

	ret

SAVSLWS:	db	0


;--- NOMBRE: LDIRSS
;      Realiza una transferencia de un segmento logico a otro
;      Vuelve con las interrupciones inhibidas
;      y la BIOS en la pagina 0
;      Reconoce el segmento logico #FF y los segmentos VRAM
;      NO comprueba si BC > #4000
;    ENTRADA:    IXh = Segmento logico fuente
;                IXl = Segmento logico destino
;                HL  = Direccion origen (0..#3FFF)
;                DE  = Direccion destino (0..#3FFF)
;                BC  = Longitud (0..#3FFF)
;     SALIDA:    A   = 0 -> Transferencia realizada
;                A  <> 0 -> Uno de los segmentos logicos no existe
;     REGISTROS: Todos
;     LLAMADAS:  PUT_P0, PUT_S1, PUT_S2, CHKSLE, DIRTOP2
;     VARIABLES: NUMSEGS

LDIRSS:	callint	_LDIRSS

_LDIRSS:	ld	a,ixh
	call	CHKSLV
	ld	ixh,a	;IXh:HL = Dir. origen, RAM o VRAM
	ld	a,0
	rl	a
	ld	iyl,a	;IYl = %0000000F, F=1 si fuente VRAM

	ex	de,hl
	ld	a,ixl
	call	CHKSLV
	ld	ixl,a
	ex	de,hl	;IXl:DE = Dir. destino, RAM o VRAM
	ld	a,iyl
	rl	a	;A = %000000FD ;D=1 si destino VRAM

	cp	3
	jp	z,LDIRSS3	;Transferencia VRAM-VRAM
	cp	2
	jp	z,LDIRSS2	;Transferencia VRAM-RAM
	dec	a
	jp	z,LDIRSS1	;Transferencia RAM-VRAM


;--- LDIRSS: Version RAM-RAM

LDIRSS0:	ld	a,(SL_2)	;Guardamos segmento logico actual P. 2
	push	af

	ld	a,ixh	;Comprobamos si el SL fuente existe,
	call	CHKSLFF	;y si es el #FF lo transformamos
	ld	ixh,a
	call	CHKSLE
	jp	nc,LDSS0ERR

	ld	a,ixl	;Idem con el SL destino
	ex	de,hl
	call	CHKSLFF
	ex	de,hl
	ld	ixl,a
	call	CHKSLE
	jp	nc,LDSS0ERR

	ld	a,b	;Longitud 0: no copiamos nada
	or	c
	jr	z,LDSSEND

	ex	de,hl
	ld	a,h	;Comprobamos si la zona de destino
	;                        ;esta contenida en dos paginas. En ese caso,
	push	hl	;la transferencia se hace de la pagina 0
	add	hl,bc	;a la 2; si no, de la 2 a la 0.
	xor	h	;Esto se hace asi para que funcione bien
	pop	hl	;si el segmento de destino es el #FF
	bit	6,a	;y la zona de destino esta contenida en las
	ex	de,hl	;paginas 2 y 3.
	jr	z,LDSS2TO0

LDSS0TO2:	ex	de,hl
	call	DIRTOP2	;Transformamos la direccion de destino
	ex	de,hl	;a su equivalente en la pagina 2

	ld	a,h	;Transformamos la direccion de origen
	and	%00111111	;a su equivalente en la pagina 0
	ld	h,a

	push	bc,de,hl	;Conectamos el segmento de destino
	ld	a,ixl
	call	PUT_SL2

	ld	a,ixh	;Conectamos el segmento de origen
	call	GET_SF
	ld	c,a
	ld	a,b

	jr	LDSS

LDSS2TO0:	call	DIRTOP2	;Transformamos la direccion de origen
	;                        ;a su equivalente en la pagina 2

	ld	a,d	;Transformamos la direccion de destino
	and	%00111111	;a su equivalente en la pagina 0
	ld	d,a

	push	bc,de,hl	;Conectamos el segmento de origen
	ld	a,ixh
	call	PUT_SL2

	ld	a,ixl	;Conectamos el segmento de destino
	call	GET_SF
	ld	c,a
	ld	a,b

LDSS:	call	PUTSLOT0	;Ponemos el SL adecuado en la pagina 0,
	ld	a,c	;guardando antes el que ya habia
	ex	af,af
	call	GET_P0
	push	af
	ex	af,af
	call	PUT_P0

	pop	af,hl,de,bc	;Realizamos la transferencia
	ldir

	call	PUT_P0	;Reponemos SL de la pagina 0
	di
	ld	a,(#FCC1)	;Reponemos la BIOS y el segmento de la
	call	PUTSLOT0	;pagina 2
LDSSEND:	pop	af
	call	PUT_SL2

	xor	a
	ret

LDSS0ERR:	pop	af
	ld	a,#FF
	ret


;--- LDIRSS: Version VRAM-VRAM

LDIRSS3:	ld	a,(SL_2)
	push	af
	ld	a,SEG_BUF	;*** Era 2
	push	bc,hl,de
	call	PUT_SL2	;Conectamos bufer
	pop	de,hl

	ld	a,ixl
	and	1
	sla	a
	ld	c,a
	ld	a,ixh
	or	c	;A = %000000DO
	pop	bc

	ld	ix,#8000	;Transferencia a traves de #8000
	call	LDIRVV

	pop	af
	call	PUT_SL2
	xor	a
	ret


;--- LDIRSS: Version VRAM-RAM (IXh:HL - IXl:DE)

LDIRSS2:	ld	a,ixl
	ex	de,hl
	call	CHKSLFF
	call	DIRTOP2
	call	CHKSLE	;Error si no existe el SL
	ex	de,hl
	jr	nc,LDSS_NOE	;@@@
	ex	af,af	;@@@
	ld	a,(SL_2)	;@@@
	push	af	;@@@

	ex	af,af
	push	hl,bc,de	;@@@
	call	PUT_SL2	;@@@
	pop	de,bc,hl	;@@@
	ld	a,ixh	;@@@
	sra	a	;@@@
	call	SET_RD	;@@@
	call	LDIRVR	;@@@
	pop	af	;@@@
	call	PUT_SL2	;@@@
	xor	a	;@@@
	ret		;                ;@@@

LDSS_NOE:	ld	a,1	;@@@
	ret		;                ;@@@


;--- LDIRSS: Version RAM-VRAM (IXh:HL - IXl:DE)

LDIRSS1:	ld	a,ixh	;Existe el SL de RAM?
	call	CHKSLFF
	call	DIRTOP2
	call	CHKSLE
	jr	nc,LDSS_NOE	;@@@
	ex	af,af	;@@@
	ld	a,(SL_2)	;@@@

	push	af	;@@@
	ex	af,af	;@@@
	push	hl,de,bc	;@@@
	call	PUT_SL2	;@@@
	pop	bc,de,hl	;@@@
	ld	a,ixl	;@@@
	sra	a	;@@@
	ex	de,hl	;@@@

	call	SET_WR	;@@@
	ex	de,hl	;@@@
	call	LDIRRV	;@@@
	pop	af	;@@@
	call	PUT_SL2	;@@@
	xor	a	;@@@
	ret		;                ;@@@


;-----------------------------------
;--- RUTINAS DE ACCESO A LA VRAM ---
;-----------------------------------

;--- NOMBRE: CHKBV
;      Devuelve error si el bloque VRAM es 1 y solo hay 64K VRAM
;    ENTRADA:   A  = Bloque VRAM
;    SALIDA:    Cy = 1 -> No existe esa VRAM
;               A  = 1 si era <>0
;    REGISTROS: -
;    VARIABLES: VRAMCAPA

CHKBV:	or	a
	ret	z
	ld	a,(VRAMCAPA)
	cp	128
	ld	a,1
	ret


;--- NOMBRE: SET_VDP
;      Preparacion del VDP para lectura o escritura de VRAM
;    ENTRADA:   A = %0S00000P
;                   P = bit 17 de la direccion VRAM
;                   S = 0 para lectura de VRAM, 1 para escritura
;               HL= direccion VRAM, 16 bits bajos
;    SALIDA:    -
;    REGISTROS: AF, HL
;    LLAMADAS:  -
;    VARIABLES: -

SET_VDP:	callint	_SETVDP

_SETVDP:	di
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

SET_RD:	ld	(PVRAM),hl
	ld	a,0
	jr	nc,PAG1R
PAG0R:	ld	a,1
PAG1R:	ld	(PVRAM+2),a
	jp	SET_VDP


;--- NOMBRE: SET_WR
;      Preparacion del VDP para escritura en VRAM
;    ENTRADA:   HL = direccion VRAM, 16 bits bajos
;               CY = direccion VRAM, bit 17
;    SALIDA:    -
;    REGISTROS: AF, HL
;    LLAMADAS:  SET_VDP
;    VARIABLES: PVRAM

SET_WR:	ld	(PVRAM),hl
	ld	a,0
	jr	nc,PAG1W
PAG0W:	ld	a,1
PAG1W:	ld	(PVRAM+2),a
	or	%01000000
	jp	SET_VDP


;--- NOMBRE: LDIRVR
;      Copia de un bloque de datos de VRAM a RAM
;    ENTRADA:   Direccion VRAM establecida con SET_RD
;               DE = destino RAM
;               BC = longitud
;    SALIDA:    Bloque de datos a partir de (DE)
;               DE = direccion siguiente al final del bloque
;    REGISTROS: AF
;    LLAMADAS:  -
;    VARIABLES: -

LDIRVR:	callint	_LDIRVR

_LDIRVR:	di
	ld	a,b
	or	c
	ret	z
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
	pop	bc,de,hl
	ret


;--- NOMBRE: LDIRRV
;      Copia de un bloque de datos de RAM a VRAM
;    ENTRADA:   Direccion VRAM establecida con SET_WR
;               HL = origen RAM
;               BC = longitud
;    SALIDA:    HL = direccion siguiente al final del bloque
;    REGISTROS: AF
;    LLAMADAS:  -
;    VARIABLES: -

LDIRRV:	callint	_LDIRRV

_LDIRRV:	di
	ld	a,b
	or	c
	ret	z
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
	ret


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
;    VARIABLES: -

LDIRVV:	callint	_LDIRVV

_LDIRVV:	rra
	di
	push	af
	call	SET_RD
	push	de,ix
	pop	de
	call	LDIRVR
	di
	pop	hl,af
	rra
	call	SET_WR
	push	ix
	pop	hl
	jp	LDIRRV


;--- NOMBRE: FILLVR
;      Llenado de una porcion de VRAM con un dato
;    ENTRADA:   Direccion inicial establecida con SET_WR
;               BC = longitud
;               A  = dato
;    SALIDA:    -
;    REGISTROS: -
;    LLAMADAS:  -
;    VARIABLES: PVRAM

FILLVR:	callint	_FILLVR

_FILLVR:	di
	push	bc,de,af
	ld	a,b
	or	c
	jr	z,NOFILLV
	pop	af
	push	af
BUCFL1:	out	(#98),a
	ld	d,a
	dec	bc
	ld	a,b
	or	c
	ld	a,d
	jr	nz,BUCFL1
NOFILLV:	pop	af,de,bc	;No hace nada si BC = 0
	ret


;--- NOMBRE: INCDIRV
;      Actualizacion de una direccion VRAM: incremento de BC unidades
;      Tras #0FFFF pasa a #10000, tras #1FFFF pasa a #00000
;    ENTRADA:   BC = Incremento
;               (PVRAM) = Direccion
;    SALIDA:    -
;    REGISTROS: -
;    LLAMADAS:  -
;    VARIABLES: PVRAM

INCDIRV:	callint	_INCDIRV

_INCDIRV:	di
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


;--- NOMBRE: BLK_CLS
;      Limpieza de la zona Blink
;    ENTRADA:   -
;    SALIDA:    -
;    REGISTROS: AF
;    LLAMADAS:  FILLVR, SET_WR
;    VARIABLES: -

BLK_CLS:	push	bc,de,hl
	LD	hl,#0A00	;@@@        ;Era #0800
	or	a
	push	hl
	call	SET_WR
	pop	hl
	ld	bc,270	;@@@        ;Era 256
	xor	a
	call	FILLVR	;Limpiamos zona VRAM 
	pop	hl,de,bc
	ret


;--- NOMBRE: BLK_COL
;      Establecimiento del color Blink
;    ENTRADA:   A = color texto + 16* color fondo
;    SALIDA:    -
;    REGISTROS: A
;    LLAMADAS:  -
;    VARIABLES: -

BLK_COL:	callint	_BLKCOL

_BLKCOL:	di
	OUT	(&H99),A
	LD	A,&H80+12
	OUT	(&H99),A
	RET


;--- NOMBRE: BLK_TIM
;      Establecimiento del tiempo Blink
;    ENTRADA:   A = tiempo ON + 16* tiempo OFF
;    SALIDA:    -
;    REGISTROS: A
;    LLAMADAS:  -
;    VARIABLES: -

BLK_TIM:	callint	_BLKTIM

_BLKTIM:	di
	OUT	(&H99),A
	LD	A,&H80+13
	OUT	(&H99),A
	RET


;--- NOMBRE: BLK_ON
;      Blink ON para un bloque
;    ENTRADA:   HL = XXYY
;               B  = longitud X
;               C  = longitud Y
;    SALIDA:    L  = YY siguiente a la ultima linea
;               H  = XX original
;    REGISTROS: AF
;    LLAMADAS:  SET_WR, C_STBT, C_BLKAD, SET_RD
;    VARIABLES: -

BLK_ON:	callint	_BLKON

_BLKON:	di
	push	ix,bc,de

BUCBKON:	push	hl,bc
	ld	a,h
	call	C_STBT
	ld	e,a	;HL = direccion VRAM inicial   
	call	C_BLKAD	;E tiene el bit inicial puesto a 1   

BLON.1:	push	hl
	or	a
	call	SET_RD
	in	a,(#98)
	pop	hl
	push	hl,af	;A = contenido de (HL) [VRAM]   
	or	a
	CALL	SET_WR	;VDP preparado para escribir en (HL)   
	POP	AF,hl

BLON.0:	OR	E
	RRC	E
	JR	NC,BLON.2
	out	(#98),a
	INC	HL
	DJNZ	BLON.1
	jr	OTRALIN1
BLON.2:	DJNZ	BLON.0
	out	(#98),a

OTRALIN1:	pop	bc,hl
	inc	l
	dec	c
	ld	a,c
	or	a
	jr	nz,BUCBKON

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
;    LLAMADAS:  SET_WR, C_STBT, C_BLKAD, SET_RD
;    VARIABLES: PVRAM (no la modifica), BKIMG

BLK_OF:	callint	_BLKOF

_BLKOF:	di
	push	bc,de

BUCBKOF:	push	hl,bc
	ld	a,h
	call	C_STBT
	cpl
	ld	e,a	;HL = direccion VRAM inicial   
	call	C_BLKAD	;E tiene el bit inicial a 1   

BLOF.1:	push	hl
	or	a
	call	SET_RD
	in	a,(#98)
	pop	hl
	push	hl,af	;A = contenido de (HL) [VRAM]    
	CALL	SET_WR	;VDP preparado para escribir en (HL)    
	POP	AF,hl

BLOF.0:	AND	E
	RRC	E
	JR	C,BLOF.2
	out	(#98),a
	INC	HL
	DJNZ	BLOF.1
	jr	OTRALIN2
BLOF.2:	DJNZ	BLOF.0
	out	(#98),a

OTRALIN2:	pop	bc,hl
	inc	l
	dec	c
	ld	a,c
	or	a
	jr	nz,BUCBKOF

	pop	de,bc
	RET

BLOF1:	dw	0
BLOF2:	db	0


;--- NOMBRE: C_BLKAD
;      Calculo de la direccion VRAM para una coordenada Blink
;    ENTRADA:   HL = XXYY
;    SALIDA:    HL = direccion VRAM
;    REGISTROS: AF
;    LLAMADAS:  POR10
;    VARIABLES: -

C_BLKAD:	push	bc
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
	LD	BC,#0A00	;@@@        ;Era #0800
	ADD	HL,BC
	pop	bc
	RET


;--- NOMBRE: C_STBT
;      Calculo del bit de la direccion blink.
;    ENTRADA:   A = coordenada X
;    SALIDA:    A = bit puesto a 1
;    REGISTROS: F
;    LLAMADAS:  -
;    VARIABLES: -

C_STBT:	push	bc	; A mod 8
	AND	7
	LD	B,A
	inc	b	;--> Esto no estaba en el listado origina
	LD	A,&H80
CSTB.0:	RRCA
	DJNZ	CSTB.0
	pop	bc
	rlca
	RET

;--- Usada por el modo blink, supongo que pone la direccion base en #0A00

BLKALGO:	PUSH	AF	;@@@
	LD	A,#2F	;@@@
	OUT	(#99),A	;@@@
	LD	A,#83	;@@@
	OUT	(#99),A	;@@@
	LD	A,#00	;@@@
	OUT	(#99),A	;@@@
	LD	A,#8A	;@@@
	OUT	(#99),A	;@@@
	POP	AF	;@@@
	RET		;@@@


;--- NOMBRE: POR10
;      Multiplicacion de un numero por 10
;    ENTRADA:   HL = numero
;    SALIDA:    HL = numero por 10
;    REGISTROS: F
;    LLAMADAS:  -
;    VARIABLES: -

POR10:	push	bc,hl
	ld	b,3
BUCP10:	sla	l	;Multiplicamos por dos tres veces     
	rl	h	;y sumamos dos veces     
	djnz	BUCP10
	pop	bc
	add	hl,bc
	add	hl,bc
	pop	bc
	ret


;----------------------------------------------
;--- COMPRESION Y DESCOMPRESION DE GRAFICOS ---
;----------------------------------------------

;--- NOMBRE: COMP
;      Comprime una zona de VRAM
;    ENTRADA:  VDP listo para lectura de la VRAM
;              BC = Num. de bytes a comprimir
;              DE = Dir. RAM destino
;    SALIDA:   BC = Num. de bytes ocupados por la imagen una vez comprimida
;              Cy = 1 si hay error por parte de INCIX
;                     (la subrutina de incremento de la direccion RAM)
;                     En ese caso los datos comprimidos no son validos
;              DE = Ultima dir. RAM utilizada (inservible si Cy=1)
;              VDP listo para lectura de la VRAM tras la imagen leida
;                  (direccion indeterminada si Cy=1)
;   REGISTROS: Todos, incluidos los alternativos
;   LLAMADAS:  INCIX
;   VARIABLES: -

;Uso interno de los registros:
;HL' = Puntero del bufer de 63 datos
;DE' = No. bytes que va ocupando la imagen comprimida
;BC' = No. de bytes que quedan por comprimir
;IX  = Puntero a RAM de destino
;C   = Puerto VDP para escritura en VRAM

;--- Inicializacion

COMP:	ld	(SPCOMP),sp

	push	de
	pop	ix
	push	bc	;Inicializacion de BC', DE' y IX 
	exx
	pop	bc
	ld	de,0
	exx

	push	hl	;No comprime nada si BC=0 
	ld	h,a
	ld	a,b
	or	c
	ld	a,h
	pop	hl
	jp	z,FinComp

	ld	a,(6)	;Cambiar por LD A,#99 si te da rabia 
	ld	c,a	;C = Puerto VDP 
	call	CLBUFC	;Limpia bufer e inicializa HL'
	in	a,(c)
	ld	b,a	;A = B = Primer dato 

;--- Bucle principal

BucNRep:	call	TOBUF	;Dato A, al bufer 
	call	c,BUFTOMEM	;Si desbordamiento del bufer, a memoria
	ld	b,a	;B = Dato antiguo 
	in	a,(c)	;A = Dato nuevo 
	cp	b
	jr	nz,BucNRep	;Repeticion mientras no se repitan los da

	call	BUFTM2	;Al bufer todos los datos menos el ultimo 
	ld	de,1	;Contador de repetidos 
	call	CLBUFC
BucRep:	ld	b,a
	exx
	dec	bc
	ld	a,b
	or	c
	exx
	call	z,REPTOMEM
	jp	z,FinComp
	inc	de
	in	a,(c)
	cp	b
	jr	z,BucRep

	call	REPTOMEM
	push	bc
	ld	b,a
	exx
	ld	a,b	;Quedan datos?
	or	c
	exx
	ld	a,b
	pop	bc
	jr	nz,BucNRep
	jp	FinComp

;--- Subrutina de limpieza del bufer

CLBUFC:	push	af
	xor	a
	ld	(BUFNREP),a
	exx
	ld	hl,BUFNREP+1
	exx
	pop	af
	ret

;--- Subrutina de introduccion de A en el bufer
;    Vuelve con Cy=1 si el dato introducido es el 63

TOBUF:	push	bc

	exx		;Dato al bufer y actualizacion del punter
	ld	(hl),a
	inc	hl
	exx

	ld	b,a	;Incrementa el contador del bufer 
	ld	a,(BUFNREP)
	inc	a
	ld	(BUFNREP),a

	cp	63	;Comprueba si es el dato 63 
	ld	a,b
	ccf

	pop	bc
	ret

;--- Subrutina de copia del bufer a la memoria y limpieza del mismo

BUFTM2:	push	bc	;No pone el ultimo elemento 
	ld	b,a
	ld	a,(BUFNREP)
	dec	a
	ld	(BUFNREP),a
	ld	a,b
	pop	bc
	jp	z,CLBUFC

BUFTOMEM:	push	af,bc,de,hl

	ld	a,(BUFNREP)	;No hace nada si el bufer esta vacio 
	or	a
	jr	z,FBFTOMEM

	ld	b,a	;B = Num. de datos en el bufer 
	ld	de,BUFNREP+1	;DE = Inicio del bufer 

	exx
	ld	a,b	;Numero de datos=B si BC'>B,
	or	a	;si no BC'
	ld	a,c
	exx
	jr	nz,NoFinC

	cp	b
	jr	c,NoFinC2

NoFinC:	ld	a,b
NoFinC2:	ld	(ix),a
	call	INCIX
	ld	b,a

BucB2M:	ld	a,(de)
	ld	(ix),a
	call	INCIX
	exx
	inc	de	;Inc. contador comprimidos 
	dec	bc	;Dec. contador a comprimir 
	ld	a,b
	or	c
	exx
	jp	z,FinComp2	;Comprueba si ya se han comprimido todos 
	inc	de
	djnz	BucB2M
	ld	a,(6)
	ld	c,a
	exx
	inc	de
	exx

FBFTOMEM:	pop	hl,de,bc,af
	jp	CLBUFC

;--- Introduccion en memoria de la indicacion de datos repetidos
;    DE contiene el numero de repeticiones, B el dato
;    Ha de volver con B = A inicial y las banderas intactas

REPTOMEM:	push	af,bc,de,hl

	ld	hl,ContR2M
	push	hl

	exx
	ex	af,af
	ld	a,b
	or	c
	jr	z,RTOM2
	dec	bc
RTOM2:	ex	af,af
	exx

	ld	hl,#3f
	call	COMPDEHL	;Rutina BIOS que compara HL y DE   
	jp	nc,SeRep63	;Si se repite hasta 63 veces     
	ld	hl,#3fff
	call	COMPDEHL
	jp	nc,SeRep16K	;Si se repite hasta #3FFF veces     
	ld	hl,#7fff
	call	COMPDEHL
	jp	nc,SeRep32K	;Si se repite hasta #7FFF veces 
	ld	hl,#bfff
	call	COMPDEHL
	jp	nc,SeRep48K	;Si se repite hasta #BFFF veces 
	jp	SeRep64K	;Si se repite hasta #FFFF veces 

ContR2M:	pop	hl,de,bc,af
	ld	b,a
	ret

;--- Repeticion hasta 63 veces

SeRep63:	ld	a,e
	or	%01000000
	ld	(ix),a
	call	INCIX

	ld	(ix),b
	call	INCIX

	exx
	inc	de
	inc	de
	exx

	ret

;--- Repeticion hasta 16K

SeRep16K:	ld	a,d
	or	%10000000
	ld	(ix),a
	call	INCIX
	ld	(ix),e
	call	INCIX
	ld	(ix),b
	call	INCIX

	exx
	inc	de
	inc	de
	inc	de
	exx

	ret

;--- Repeticion 16K

Justo16K:	ld	a,%10111111
	ld	(ix),a
	call	INCIX
	ld	a,%11111111
	ld	(ix),a
	call	INCIX
	ld	(ix),b
	call	INCIX

	ld	a,d
	sub	#40
	ld	d,a
	inc	de

	exx
	inc	de
	inc	de
	inc	de
	exx

	ret

;--- Repeticion hasta 32K

SeRep32K:	call	Justo16K
	jp	SeRep16K

;--- Repeticion hasta 48K

SeRep48K:	call	Justo16K
	jp	SeRep32K

;--- Repeticion hasta 64K

SeRep64K:	call	Justo16K
	jp	SeRep48K

;--- Comparacion de DE y HL
;    Modifica A

COMPDEHL:	ld	a,h
	sub	d
	ret	nz
	ld	a,l
	sub	e
	ret

;--- Finalizacion

FinComp2:	exx
	inc	de
	exx

FinComp:	ld	a,%11000000
	ld	(ix),a
	exx
	push	de
	exx
	pop	bc
	inc	bc

	push	ix
	pop	de
	or	a
FinCErr:	ld	sp,(SPCOMP)
	ret

SPCOMP:	dw	0
;BUFNREP:          ds      64               ;Bufer para datos no repetidos


;--- NOMBRE: DESC
;      Descomprime datos a RAM
;    ENTRADA:   VDP listo para escritura en VRAM
;               HL = Direccion de origen RAM
;    SALIDA:    BC = Tamanio de la imagen descomprimida (inservible si Cy=1)
;               Cy = 1 si hay error por parte de INCIX
;                      (la subrutina de incremento de la direccion RAM)
;                      o si se ha encontrado un dato incorrecto
;                      En ese caso los datos comprimidos no son validos
;               HL = Ultima direccion RAM leida
;    REGISTROS: Todos
;    LLAMADAS:  FinCErr, INCIX
;    VARIABLES: SPCOMP

;Modifica todos los registros

DESC:	ld	de,0	;DE = Contador de bytes enviados a VRAM 
	ld	a,(7)
	ld	c,a
	push	hl
	pop	ix
	ld	(SPCOMP),sp

QueDesc:	ld	a,(ix)
	or	a
	scf
	jr	z,FinCErr
	and	%11000000
	jr	z,DescNR
	cp	%01000000
	jr	z,Desc63
	cp	%10000000
	jr	z,Desc16K
	or	a
	push	ix
	pop	hl
	push	de
	pop	bc
	jr	FinCErr

DescNR:	ld	b,(ix)
	call	INCIX
BucDNR:	ld	a,(ix)
	call	INCIX
	out	(c),a
	inc	de
	djnz	BucDNR
	jr	QueDesc

Desc63:	ld	a,(ix)
	call	INCIX
	and	%00111111
	scf
	jp	z,FinCErr	;Error si el numero de datos es 0
	ld	b,a
	ld	a,(ix)
	call	INCIX
BucD63:	out	(c),a
	inc	de
	djnz	BucD63
	jr	QueDesc

Desc16K:	ld	a,(ix)
	call	INCIX
	and	%00111111
	ld	h,a
	ld	l,(ix)
	or	l
	scf
	jp	z,FinCErr	;Error si el numero de datos es 0
	call	INCIX
	ld	b,(ix)
	call	INCIX
BucD16K:	out	(c),b
	inc	de
	dec	hl
	ld	a,h
	or	l
	jr	nz,BucD16K
	jr	QueDesc


;-------------------------------------
;--- RUTINAS DE MANEJO DE FICHEROS ---
;-------------------------------------

;--- NOMBRE: GETF01
;      Copia de F$(0) y F$(1) a los buferes F0BUF y F1BUF
;    ENTRADA:   Segmento del BASIC conectado en P. 2
;    SALIDA:    F0BUF y F1BUF rellenos (hasta 77 caracteres), acabados en 0
;    REGISTROS: AF, HL, DE, BC
;    LLAMADAS:  -
;    VARIABLES: F0BUF, F1BUF, ARYTAB

GETF01:	push	ix
	ld	ix,(F0BUFD)
	ld	(ix),0
	ld	ix,(F1BUFD)
	ld	(ix),0
	;ld      (ix+LONF01+2),a
	ld	ix,(ARYTAB)	;Inicialmente, buferes vacios

BUCBUSF:	ld	a,(ix)

	cp	1	;Matriz de cadenas en Turbo-BASIC?
	jp	z,GETFTB

	cp	2	;Matriz de cualquier otro tipo?
	jr	z,GETFSM
	cp	3
	jr	z,GETFSM
	cp	4
	jr	z,GETFSM
	cp	8
	jr	z,GETFSM
	jr	BUSFTB	;Si o quedan mas matrices, sig. bucle

GETFSM:	ld	c,(ix+3)	;Si no es de cadenas, pasamos a la siguiente
	ld	b,(ix+4)
	add	ix,bc
	ld	bc,5
	add	ix,bc
	jr	BUCBUSF

BUSFTB:	ld	ix,(ARYTAB)	;Inicialmente, buferes vacios

BUCBUSF2:	ld	a,(ix)

	cp	3	;Matriz de cadenas en BASIC normal? 
	jr	z,GETFB

	cp	2	;Matriz de cualquier otro tipo?
	jr	z,GETFSM2
	cp	4
	jr	z,GETFSM2
	cp	8
	jr	z,GETFSM2
	jr	OKGETF	;Si o quedan mas matrices, terminamos

GETFSM2:	ld	c,(ix+3)	;Si no es de cadenas, pasamos a la siguiente
	ld	b,(ix+4)
	add	ix,bc
	ld	bc,5
	add	ix,bc
	jr	BUCBUSF2

;--- Obtencion de F$(0) y F$(1), version BASIC normal

GETFB:	ld	a,(ix+1)	;Si no es F, seguimos buscando
	cp	"F"
	jr	nz,BUCBUSF
	ld	a,(ix+2)
	or	a
	jr	nz,BUCBUSF

	ld	c,(ix+6)
	ld	b,(ix+7)
	push	bc	;BC = Num. de elementod de la matriz
	ld	bc,8
	add	ix,bc	;IX apunta ahora a la descripcion de F$(0)

GETF0B:	ld	a,(ix)	;F$(0) tiene longitud >0?
	or	a
	jr	z,GETF1B
	cp	LONF01	;Longitud maxima LONF01
	jr	c,OKLENF0B
	ld	a,LONF01
OKLENF0B:	ld	c,a
	ld	b,0	;BC = Longitud de F$(0)
	ld	l,(ix+1)
	ld	h,(ix+2)	;HL = Dir. inicio cadena
	ld	de,(F0BUFD)
	ldir
	xor	a
	ld	(de),a	;Caracter 0 al final

GETF1B:	pop	bc
	dec	bc
	ld	a,b
	or	c
	jr	z,OKGETF	;Existe F$(1)?
	ld	a,(ix+3)
	or	a
	jr	z,OKGETF	;Tiene longitud >0?
	cp	LONF01	;Longitud maxima 77
	jr	c,OKLENF1B
	ld	a,LONF01
OKLENF1B:	ld	c,a	;BC = Longitud de F$(1)
	ld	b,0
	ld	l,(ix+4)	;HL = Inicio cadena
	ld	h,(ix+5)
	ld	de,(F1BUFD)
	ldir
	xor	a
	ld	(de),a	;Caracter 0 al final

OKGETF:	pop	ix
	ret

;--- Obtencion de F$(0) y F$(1), version Turbo-BASIC

GETFTB:	ld	c,(ix+1)
	ld	b,(ix+2)
	push	bc	;BC = Num. de elementos de la matriz

GETF0TB:	ld	a,(ix+3)
	or	a
	jr	z,GETF1TB	;F$(0) tiene longitud >0?
	cp	LONF01
	jr	c,OKLF0TB
	ld	a,LONF01	;Limitamos la longitud a LONF01 (-1?)
OKLF0TB:	ld	c,a
	ld	b,0	;BC = Longitud cadena
	push	ix
	pop	hl
	ld	de,4
	add	hl,de	;HL = Inicio cadena
	ld	de,(F0BUFD)
	ldir
	xor	a
	ld	(de),a	;Caracter 0 al final

GETF1TB:	pop	bc
	dec	bc
	ld	a,b	;Existe F$(1)?
	or	c
	jr	z,OKGETF

	ld	de,#103
	add	ix,de
	ld	a,(ix)
	or	a
	jr	z,OKGETF	;F$(1) tiene longitud >0?
	cp	LONF01
	jr	c,OKLF1TB
	ld	a,LONF01
OKLF1TB:	ld	c,a	;Limitamos la longitud a 77
	ld	b,0
	push	ix
	pop	hl
	inc	hl
	ld	de,(F1BUFD)
	ldir
	xor	a
	ld	(de),a	;Caracter 0 al final

	jr	OKGETF


;--- NOMBRE: SETF0 y SETF1
;      Copia los buferes F0BUF o F1BUF a F$(0) o F$(1)
;    ENTRADA:   Segmento del BASIC conectado en P. 2
;    SALIDA:    F$(0) y F$(1) establecidos
;    REGISTROS: AF, HL, DE, BC
;    LLAMADAS:  -
;    VARIABLES: F0BUF, F1BUF, ARYTAB

;ATENCION: Estas funciones hacen que las cadenas descriptoras de FnBUF
;realmente apunten a FnBUF. Por tanto, cualquier modificacion posterior
;de este bufer tambien implicara una modificacion de F$(n), aunque no se
;haga la llamada a SETFn.

;Asi pues, si se desea manipular los buferes FnBUF sin modificar las variables
;F$(n), hay que hacer una copia de los mismos y restaurarlos despues.

;OJO: Lo anterior solo se aplica al BASIC normal, no al turbo-BASIC

SETF0:	ld	hl,(F0BUFD)
	ld	bc,F0_NAME-RES_I
	xor	a
	jr	SETF01

SETF1:	ld	hl,(F1BUFD)
	ld	bc,F1_NAME-RES_I
	ld	a,1

SETF01:	PUSH	HL	;@@@
	LD	HL,(SAVTXT)	;@@@
	EX	(SP),HL	;@@@
	CALL	_SETF01	;@@@
		EX	(SP),HL	;@@@
	LD	(SAVTXT),HL	;@@@
	POP	HL	;@@@
	RET		;@@@

_SETF01:	push	iy,ix,af	;HL = Origen de la cadena
	xor	a	;BC + (USRTAB) = Nombre de la variable
	ld	(SUBFLG),a
	ld	ix,(USRTAB)
	ex	de,hl
	ld	hl,#FCC1
	ld	a,(ix+SLTSTAT-RES_I)
	cp	(hl)
	ex	de,hl
	jr	nz,SETF01TB

;--- SETF01: Version BASIC normal

SETF01B:	pop	af	;A = 0 o 1 (solo usado en la version XBASIC)
	add	ix,bc
	push	hl	;Guardamos direccion del bufer
	push	ix
	pop	hl	;HL = Nombre de la variable
	ld	ix,PTRGET
	ld	iy,(#FCC0)
	call	#001C	;DE = Cadena descriptora de la variable
	ld	(DESCF),de

	pop	hl	;HL = Inicio de la cadena (bufer 0 o 1)
	ld	a,(hl)
	or	a
	jr	nz,NOZSTR	;Cadena vacia: no registramos nada,
	xor	a
	ld	(de),a	;solo ponemos longitud 0
	jr	OKSETF	;en el descriptor de la cadena

NOZSTR:	push	hl
	dec	hl
	ld	b,#50	;@@@
SF01BC:	inc	hl
	ld	a,(hl)	;Buscamos el 0 de terminacion
	cp	34
	jr	nz,NOCOM1	;Si hay comillas, las cambiamos a 255
	ld	a,255
	ld	(hl),a
NOCOM1:	or	a
	jr	z,NOCOM1X	;@@@  ;jr	nz,SF01BC
	djnz	SF01BC	;@@@
	inc	hl	;@@@
NOCOM1X:	ld	a,34
	ld	(hl),a
	ex	de,hl
	pop	hl	;HL = Inicio de la cadena
	push	de	;DE = Final cadena (comillas aniadidas)

	dec	hl	;HL = Cadena (comillas iniciales)
	ld	ix,FRMEVL
	ld	iy,(#FCC0)
	call	#001C
	ld	ix,FRESTR	;Registramos cadena
	ld	iy,(#FCC0)
	call	#001C

	push	hl	;Una vez registrada, sustituimos
	ld	b,(hl)	;los 255 por comillas
	ld	a,b
	or	a
	jr	z,CADVACIA	;Aniadido en 1.0
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl
BUCCOM:	ld	a,(hl)
	cp	255
	jr	nz,NOCOM2
	ld	a,34
	ld	(hl),a
NOCOM2:	inc	hl
	djnz	BUCCOM
CADVACIA:	pop	hl

	ld	de,(DESCF)
	ld	bc,3
	ldir		;Establecemos cadena descriptora

	pop	de
	xor	a
	ld	(de),a	;Restauramos caracter 0 de la cadena

OKSETF:	pop	ix,iy
	ei
	ret

DESCF:	dw	0

;--- SETF01: Version Turbo-BASIC

SETF01TB:	ld	d,a
	ld	ix,(ARYTAB)

BUCBUSFS:	ld	a,(ix)
	cp	1	;Matriz de cadenas en Turbo-BASIC? 
	jr	z,FNDF01TB
	;cp      2
	;jr      nz,OKSETF2

	ld	c,(ix+3)	;Si no es de cadenas, pasamos a la siguiente
	ld	b,(ix+4)
	add	ix,bc
	ld	bc,5
	add	ix,bc
	jr	BUCBUSFS

FNDF01TB:	pop	af
	or	a
	jr	nz,SETF1TB
	ld	bc,3
ST0O1TB:	add	ix,bc
	push	ix
	pop	de
	inc	de
	ld	(ix),0
BUCS0TB:	ld	a,(hl)
	or	a
	jr	z,OKSETF
	ld	(de),a
	inc	de
	inc	hl
	inc	(ix)
	jr	BUCS0TB

SETF1TB:	ld	c,(ix+1)
	ld	b,(ix+2)
	ld	a,b
	or	c
	jr	z,OKSETF
	ld	bc,#103
	jr	ST0O1TB

OKSETF2:	pop	af,ix
	ei
	ret


;--- Versiones de GETF01 y SETF0/1 para ser llamadas por el usuario

_UGETF01:	ld	hl,GETF01
	jr	_GSF01

_USETF0:	ld	hl,SETF0
	jr	_GSF01

_USETF1:	ld	hl,SETF1
	jr	_GSF01

_GSF01:	ld	a,(SL_2)
	ld	(GFS01DIR+1),hl
	push	af
	ld	a,2
	call	PUT_SL2

GFS01DIR:	call	0

	pop	af
	call	PUT_SL2
	ret


;--- NOMBRE: MAXBC
;      Limita BC a #4000 si es mayor
;    ENTRADA:   BC = Longitud
;    SALIDA:    BC = Longitud limitada
;    REGISTROS: -
;    LLAMADAS:  -
;    VARIABLES: -

MAXBC:	push	af
	ld	a,b
	cp	#40
	jr	c,FMAXBC
	ld	bc,#4000
FMAXBC:	pop	af
	ret


;--- NOMBRE: CLBUF
;      Limpia el bufer generico
;    ENTRADA:   -
;    SALIDA:    -
;    REGISTROS: -
;    LLAMADAS:  -
;    VARIABLES: BUFER, LONBUF

CLBUF:	push	hl,de,bc
	ld	hl,BUFER
	ld	de,BUFER+1
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

F2NEND:	dec	de	;Si no hay extension, suprimimos el punto
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


;--- NOMBRE: CHKFCBV
;      Comprueba si un nombre FCB esta vacio,
;      en ese caso lo rellena de espacios.
;    ENTRADA:   DE = Direccion FCB
;    SALIDA:    FCB convertido
;    REGISTROS: AF
;    LLAMADAS:  -
;    VARIABLES: -

CHKFCBV:	push	hl,de,bc
	inc	de
	ld	a,(de)
	cp	#20
	jr	nz,FCHKFCBV

	push	de
	pop	hl
	inc	de
	ld	a,"?"
	ld	(hl),a
	ld	bc,10
	ldir

FCHKFCBV:	pop	bc,de,hl
	ret


;--- NOMBRE: CHKDRVE
;      Comprueba si una unidad existe
;    ENTRADA:   A  = Unidad
;    SALIDA:    Cy = 0 si la unidad existe
;               Cy = 1 si no existe
;    REGISTROS: AF
;    LLAMADAS:  DOSCALL
;    VARIABLES: _LOGIN

CHKDRVE:	cp	8
	ccf
	ret	c	;Error si la unidad es > 7

	push	hl,de,bc
	ld	b,a
	ld	a,%10000000
	inc	b
DRTOBIT:	rlca
	djnz	DRTOBIT
	push	af	;A tiene el bit P(0) a 1 

	ld	c,_LOGIN
	call	DOSCALL
	pop	af
	and	l
	pop	bc,de,hl
	scf
	ret	z
	or	a
	ret


;--- NOMBRE: FCB2FCBR y FCBR2FCB
;      Mueve un FCB al FCB en la zona residente, o al reves
;    ENTRADA:   A  = Numero de FCB (1 a MAXFIL)
;    SALIDA:    Cy = 0 -> Ok
;               Cy = 1 -> Error (A > MAXFIL o A = 0)
;    REGISTROS: AF, AF'
;    LLAMADAS:  -
;    VARIABLES: FCBS, TAMFCB, FCBRDIR

FCB2FCBR:	ex	af,af
	xor	a	;FCB -> FCBR: borramos el EX DE,HL
	ld	(EXFCBR),a
	jr	FCBFCBR

FCBR2FCB:	ex	af,af	;FCBR -> FCB: ponemos el EX DE,HL
	ld	a,#EB
	ld	(EXFCBR),a

FCBFCBR:	ex	af,af
	or	a
	scf
	ret	z
	cp	MAXFIL+1
	ccf
	ret	c

	push	hl,de,bc

	ld	hl,FCBS
	ld	de,TAMFCB
	ld	b,a
	or	a
	sbc	hl,de
BUCFCBR:	add	hl,de
	djnz	BUCFCBR

	ld	de,(FCBRDIR)
EXFCBR:	ex	de,hl
	ld	bc,TAMFCB
	ldir

	or	a
	pop	bc,de,hl
	ret


;--- NOMBRE: FLUSH
;      Flushea (mande?) los buferes internos del DOS 2.
;    ENTRADA:   -
;    SALIDA:    A = Error
;    REGISTROS: F
;    LLAMADAS:  DOSCALL
;    VARIABLES: FLUSH

FLUSH:	push	ix,iy,hl,de,bc
	ld	b,#FF
	ld	d,0
	ld	c,_FLUSH
	call	DOSCALL
	pop	bc,de,hl,iy,ix
	ret


;--- NOMBRE: DOSCALL
;      Llamada a una funcion del DOS, con prevision
;      de error de disco fisico con salto al BASIC
;    ENTRADA:   Registros establecidos para la llamada
;    SALIDA:    A = Error BASIC
;               HL, DE, BC = 0 si hay error BASIC
;    REGISTROS: AF', BC', DE', HL'
;    LLAMADAS:  -
;    VARIABLES: HERR

DOSCALL:	exx
	ld	hl,HERR	;Guardamos el antiguo gancho de error
	ld	de,OLDHERR
	ld	bc,5
	ldir
	ld	hl,NEWERR	;Guardamos el nuevo gancho de error
	ld	de,HERR
	ld	bc,5
	ldir
	exx

	push	ix,iy
	ld	(SAVSPDC),sp	;Guardamos la pila
	call	#F37D	;Si la funcion DOS vuelve, restauramos
CONTEDC2:	pop	iy,ix	;el gancho y volvemos tal cual.

	exx
	ld	hl,OLDHERR
	ld	de,HERR
	ld	bc,5
	ldir
	exx
	cp	#FF
	ret	nz	;Transforma el error #FF en error 1
	ld	a,1
	ret

CONTEDC:	ld	sp,(SAVSPDC)	;Salto aqui si hay error BASIC
	ld	a,e
	ld	d,0
	ld	hl,0
	ld	bc,0
	jr	CONTEDC2

NEWERR:	db	#C3	;Codigo de JP
RESERRD:	dw	0	;Dir. establecida en la inicializacion
	ds	2

OLDHERR:	ds	5
SAVSPDC:	dw	0


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
;     LLAMADAS:  CONVNAME
;     VARIABLES: BUFER, _SETDTA, _SFIND, _SNEXT, _FFIND, _FNEXT, DOSVERP

OFBUF1:	equ	TAMFCB

DIR:	ex	af,af
	ld	a,(DOSVERP)
	dec	a
	jr	nz,DIR2

	;--- DIR: Version DOS 1 

DIR1:	ex	af,af
	push	bc,de,hl,iy,ix,af
	call	CLBUF
	ex	de,hl
	ld	de,BUFER	;Pasamos el nombre normal de (DE)
	or	a	;a nombre FCB en BUFER.
	call	CONVNAME
	call	CHKFCBV	;Si el FCB esta vacio lo pasamos a "*.*"

	ld	de,BUFER+OFBUF1	;Ponemos el area de transferencia
	ld	c,_SETDTA	;en el buffer, tras el FCB del fichero 
	call	#F37D	;a buscar. 
	ld	de,BUFER
	pop	af
	and	1
	ld	c,_SFIRST
	add	c
	ld	c,a
	call	DOSCALL
	or	a	;Terminamos con A=#FF si no se encuentra. 
	jp	nz,ENDFF1

	ld	a,(BUFER+OFBUF1)	;Guardamos la unidad del FCB
	ld	(ULO1),a	;en ULO1, y la ponemos a 0 
	xor	a	;para poder convertirla a nombre normal 
	ld	(BUFER+OFBUF1),a	;sin unidad.
	ld	iy,BUFER+OFBUF1

	push	iy
	pop	hl	;HL = Entrada de directorio del fichero 
	pop	de	;(comenzando con la unidad a 0 y el nombre
	push	de	;DE = IX de la entrada (buffer del usuario)
	ld	a,#FF
	ld	(de),a	;Primer byte a #FF para igualarlo al DOS 2
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

DIR2:	ex	af,af
	push	hl,bc,de,ix
	ld	ix,BUFER
	ld	c,_FFIRST
	and	1
	add	c
	ld	c,a
	call	DOSCALL
	or	a
	jp	nz,ENDFF2
	push	ix
	pop	hl
	pop	de
	push	de
	ld	bc,26
	ldir
	;call    FLUSH
ENDFF2:	pop	ix,de,bc,hl
	ret


;--- NOMBRE: REN
;      Renombra un fichero
;    ENTRADA:   DE = Nombre del fichero
;               HL = Nuevo nombre del fichero (puede contener comodines)
;    SALIDA:    A  = 0 -> Fichero renombrado
;               A <> 0 -> Error
;    REGISTROS: F
;    LLAMADAS:  CHKDOS2, CONVNAME
;    VARIABLES: BUFER, _FREN, _RENAME, DOSVERP

REN:	ld	a,(DOSVERP)
	dec	a
	jr	nz,REN2

	;--- REN: Version DOS 1  

REN1:	push	bc,de,hl,ix,iy
	call	CLBUF

	push	hl
	ex	de,hl	;HL = Nombre antiguo  
	ld	de,BUFER
	or	a
	call	CONVNAME
	call	CHKFCBV

	pop	hl	;HL = Nombre nuevo  
	ld	de,BUFER+16
	or	a
	call	CONVNAME
	ld	de,BUFER

	ld	c,_FREN
	call	DOSCALL
	pop	iy,ix,hl,de,bc
	ret

	;--- REN: Version DOS 2  

REN2:	push	hl,de,bc
	ld	c,_RENAME
	call	DOSCALL
	or	a
	call	z,FLUSH
	pop	bc,de,hl
	ret


;--- NOMBRE: CREATE
;      Crea un fichero pero NO lo deja abierto
;      !CUIDADU! Si ya existe ese fichero, lo borra y crea uno nuevo
;    ENTRADA:   DE = Nombre del fichero
;               B  = Atributos (ignorado en DOS 1)
;    SALIDA:    A  = 0 -> Fichero creado
;               A <> 0 -> Error
;    REGISTROS: F
;    LLAMADAS:  CONVNAME
;    VARIABLES: _FMAKE, _FCLOSE, _CREATE, _CLOSE, BUFER, DOSVERP

CREATE:	ld	a,(DOSVERP)
	dec	a
	jr	nz,CREA2

	;--- CREATE: Version DOS 1 

CREA1:	push	bc,de,hl,ix,iy
	call	CLBUF
	ex	de,hl	;HL = Nombre del fichero  
	ld	de,BUFER
	or	a
	call	CONVNAME
	call	CHKFCBV
	ex	de,hl
	ld	de,BUFER
	push	de
	ld	c,_FMAKE	;Crea el fichero y lo cierra 
	call	DOSCALL
	pop	de
	or	a
	jp	nz,CR1END
	ld	c,_FCLOSE
	call	DOSCALL
	xor	a
CR1END:	pop	iy,ix,hl,de,bc
	ret

	;--- CREATE: Version DOS 2 

CREA2:	push	bc,de,hl
	xor	a
	res	7,b	;Si el fichero ya existe, lo borra.
	ld	c,_CREATE	;Crea el fichero y lo cierra 
	call	DOSCALL
	or	a	;si no hay error. 
	jp	nz,CR2END
	ld	a,b	;Si se ha creado un subdirectorio (B=#FF)
	inc	a	;no se cierra (no esta abierto)
	jr	z,CR2END
	ld	c,_CLOSE
	call	DOSCALL
	or	a
	call	z,FLUSH
CR2END:	pop	hl,de,bc
	ret


;--- NOMBRE: DEL
;      Borra un fichero
;      EL FICHERO NO DEBE ESTAR ABIERTO
;    ENTRADA:   DE = Nombre del fichero
;    SALIDA:    A  = 0 -> Fichero borrado
;               A <> 0 -> Error
;    REGISTROS: F
;    LLAMADAS:  CONVNAME, CHKDOS2
;    VARIABLES: _FDEL, _DELETE, BUFER, DOSVERP

DEL:	ld	a,(DOSVERP)
	dec	a
	jr	nz,DEL2

	;--- DEL: Version DOS 1 

DEL1:	push	bc,de,hl,ix,iy
	call	CLBUF
	ex	de,hl	;HL = Nombre del fichero 
	ld	de,BUFER
	or	a
	call	CONVNAME
	call	CHKFCBV
	ex	de,hl
	ld	de,BUFER
	ld	c,_FDEL
	call	DOSCALL
	pop	iy,ix,hl,de,bc
	ret

	;--- DEL: Version DOS 2 

DEL2:	push	bc,de,hl
	ld	c,_DELETE
	call	DOSCALL
	or	a
	call	z,FLUSH
DEL2END:	pop	hl,de,bc
	ret


;--- NOMBRE: OPEN
;      Abre un fichero
;    ENTRADA:   DE = Fichero a abrir
;    SALIDA:    A  = 0 -> Error
;               A <> 0 -> Error
;                         DOS 1: A=3 -> demasiados ficheros abiertos
;               B  = Numero asociado al fichero
;                    (no tiene nada que ver con el numero de ficheros abiertos)
;    REGISTROS: F, C
;    LLAMADAS:  CONVNAME
;    VARIABLES: DOS, NUMFILES, MAXFIL, _FOPEN, _OPEN, FCBS, DOSVERP,
;               FCB2FCBR, FCBR2FCB

OPEN:	ld	a,(DOSVERP)
	dec	a
	jp	nz,OPEN2

	;--- OPEN: Version DOS 1 

OPEN1:	ld	a,(NUMFILES)
	cp	MAXFIL
	ld	a,3	;Demasiados ficheros abiertos
	ret	nc

	push	hl,de,ix,iy
	ld	b,MAXFIL
	ld	hl,FCBS
	push	de
	ld	de,TAMFCB
	ld	c,1
OP1BUC1:	ld	a,(hl)	;Buscamos, en todos los FCBs, 
	or	a	;alguno que este libre. 
	jp	z,FCBFND
	add	hl,de
	inc	c
	djnz	OP1BUC1
	ld	a,1
	jp	OP1END

FCBFND:	ld	a,c
	ld	(OPFNUM),a	;OPFNUM = Numero de FCB
	call	FCB2FCBR	;Lo pasamos a la parte residente
	ld	hl,(FCBRDIR)

	push	hl	;Limpiamos FCB
	pop	de
	push	de
	inc	de
	ld	bc,TAMFCB-1
	ld	(hl),0
	ldir

	pop	de
	inc	de
	pop	hl	;Pasamos el nombre del fichero al FCB 
	or	a
	call	CONVNAME
	call	CHKFCBV

	push	de
	ld	c,_FOPEN
	call	DOSCALL
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
	ld	(NUMFILES),a	;devolvemos en B el numero de este
	ld	a,(OPFNUM)
	ld	b,a
	call	FCBR2FCB	;Volvemos a copiar el FCB a la zona de FCBs

	xor	a
OP1END:	pop	iy,ix,de,hl
	ret
OPFNUM:	db	0

	;--- OPEN: Version DOS 2 

OPEN2:	push	iy,ix,hl,de
	xor	a
	ld	c,_OPEN
	call	DOSCALL
	or	a
	jp	nz,OP2END
	ld	a,(NUMFILES)
	inc	a
	ld	(NUMFILES),a
	xor	a
OP2END:	pop	de,hl,ix,iy
	ret


;--- NOMBRE: CLOSE
;      Cierra un fichero
;    ENTRADA:   B  = Numero de fichero
;    SALIDA:    A  = 0 -> Fichero cerrado
;               A <> 0 -> Error
;                    2 -> Fichero no abierto/No. de fichero incorrecto
;    REGISTROS: F
;    LLAMADAS:  CHKDOS2
;    VARIABLES: BUFER, FCBS, DOS, MAXFIL, NUMFILES, _FCLOSE, _CLOSE, DOSVERP,
;               FCB2FCBR, FCBR2FCB, OPFNUM

CLOSE:	ld	a,(DOSVERP)
	dec	a
	jr	nz,CLOSE2

	;--- CLOSE: Version DOS 1 

CLOSE1:	ld	a,b	;Error si B>MAXFIL 
	cp	MAXFIL+1	;o B=0. 
	ld	a,2
	ret	nc
	ld	a,b
	or	a
	ld	a,2
	ret	z

	push	bc,de,hl,ix,iy
	ld	hl,FCBS
	ld	de,TAMFCB
	ld	c,0
	or	a
	sbc	hl,de
CL1BUC1:	add	hl,de	;HL = Zona en FCBS del fichero B 
	inc	c
	djnz	CL1BUC1

	ld	a,(hl)	;Error si el fichero no esta abierto 
	or	a
	ld	a,2
	jp	z,ENDCL1

	ld	a,c
	ld	(OPFNUM),a
	call	FCB2FCBR
	ld	de,(FCBRDIR)
	inc	de
	push	de
	ld	c,_FCLOSE
	call	DOSCALL
	pop	ix
	or	a
	jr	nz,ENDCL1

	ld	a,(NUMFILES)
	dec	a
	ld	(NUMFILES),a
	xor	a	;Marcamos el FCB como libre 
	ld	(ix-1),a

	ld	a,(OPFNUM)
	call	FCBR2FCB
	xor	a
ENDCL1:	pop	iy,ix,hl,de,bc
	ret

	;--- CLOSE: Version DOS 2 

CLOSE2:	push	ix,iy,bc,de,hl
	ld	c,_CLOSE
	call	DOSCALL
	or	a
	jp	nz,ENDCL2
	ld	a,(NUMFILES)
	dec	a
	ld	(NUMFILES),a
	xor	a
ENDCL2:	pop	hl,de,bc,iy,ix
	ret


;--- NOMBRE: READ
;      Lee de un fichero abierto
;    ENTRADA:   B  = Numero de fichero
;               DE = Direccion del bufer
;               HL = Numero de bytes a leer
;    SALIDA:    A  = 0 -> No hay error
;               A <> 0 -> Error
;                    2 -> Fichero no abierto/No. de fichero incorrecto
;                         Se considera error no haber podido leer
;                         todos los bytes requeridos, es decir,
;                         HL a la entrada <> HL a la salida.
;                         Este error tiene el codigo A=1 en DOS 1,
;                         y el #C7 en DOS 2.
;               HL = Numero de bytes leidos
;    REGISTROS: F
;    LLAMADAS:  CHKDOS2, RW1, RW2
;    VARIABLES: BUFER, FCBS, DOESNTRY, DOS, MAXFIL, NUMFILES, _RDBLK,
;               _READ, _SETDTA, RWCODE, DOSVERP

READ:	ld	a,(DOSVERP)
	dec	a
	jr	nz,READ2

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
;                    2 -> Fichero no abierto/No. de fichero incorrecto
;                         Se considera error no haber podido escribir
;                         todos los bytes requeridos, es decir,
;                         HL a la entrada <> HL a la salida.
;                         Este error tiene el codigo A=1 en DOS 1,
;                         y el #C7 en DOS 2.
;               HL = Numero de bytes escritos
;    REGISTROS: F
;    LLAMADAS:  CHKDOS2, RW1, RW2
;    VARIABLES: BUFER, FCBS, DOSCALL, DOS, MAXFIL, NUMFILES, _WRBLK,
;               _WRITE, _SETDTA, RWCODE, DOSVERP

WRITE:	ld	a,(DOSVERP)
	dec	a
	jr	nz,WRITE2

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
	cp	MAXFIL+1
	ld	a,2
	ret	nc
	ld	a,b
	or	a
	ld	a,2
	ret	z
	ld	a,b

	push	iy,ix,bc,hl,de
	ld	(OPFNUM),a
	call	FCB2FCBR	;FCB -> FCBR
	ld	ix,(FCBRDIR)
	ld	a,(ix-1)
	inc	a	;Error si el fichero no esta abierto
	ld	a,2
	jp	z,ENDRW11

	pop	de
	push	de
	ld	c,_SETDTA
	call	DOSCALL
	pop	de,hl
	push	de
	ld	de,(FCBRDIR)
	inc	de
	ld	a,(RWCODE)	;Leemos el codigo de lectura o escritura 
	ld	c,a
	call	DOSCALL	;y ejecutamos la llamada
	push	af

	ld	a,(OPFNUM)
	call	FCBR2FCB
	pop	af

	pop	de
ENDRW1:	pop	bc,ix,iy
	ret
ENDRW11:	pop	de,hl
	jp	ENDRW1

	;--- RW: Version DOS 2 

RW2:	push	ix,iy,bc,de,hl
	ld	a,b
	ld	(FHRW),a
	;jr      nz,ENDRW2       ;UNA TARDE PERDIDA POR CULPA DESTA P. LINEA
	ld	a,(RWCODE)	;Leemos el codigo de lectura o escritura 
	ld	c,a
	call	DOSCALL
	pop	de
	or	a
	jr	nz,ENDRW2
	push	hl,de

	ld	a,(FHRW)
	ld	b,a
	ld	c,_ENSURE
	call	DOSCALL
	pop	de,hl
	or	a
	jr	nz,ENDRW22
	push	hl

	sbc	hl,de	;HL = bytes leidos, DE = bytes requeridos 
	ld	a,h	;Si HL=DE, no hay error 
	or	l	;Si HL<>DE, error #C7, o el de ENSURE
	pop	hl
	ld	a,0
	jr	z,ENDRW2
	ld	a,#C7

ENDRW2:	pop	de,bc,iy,ix
	ret
ENDRW22:	ld	hl,0
	jr	ENDRW2

RWCODE:	db	0	;Codigo de la funcion de lectura/escritur
FHRW:	db	0


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
;                    2 -> Fichero no abierto/No. de fichero incorrecto
;               DE:HL  = Nuevo puntero
;    * Para obtener la posicion del puntero sin modificarla,
;      ejecutar con A = 1 y DE:HL=0.
;    * Para obtener la longitud del fichero,
;      ejecutar con A = 2 y DE:HL=0.
;    REGISTROS:  F
;    LLAMADAS:   CHKDOS2
;    VARIABLES:  MAXFIL, NUMFILES, _SEEK, BUFER, DOSVERP


SEEK:	ld	(SKMET),a
	ld	a,(DOSVERP)
	dec	a
	ld	a,(SKMET)
	jp	nz,SEEK2

	;--- SEEK: Version DOS 1 

SEEK1:	ld	(SKMET),a
	ld	a,b	;Error si B>MAXFIL 
	cp	MAXFIL+1	;o B=0. 
	ld	a,2
	ret	nc
	ld	a,b
	or	a
	ld	a,2
	ret	z

	push	bc,ix,iy
	push	de,hl
	ld	hl,FCBS
	ld	de,TAMFCB
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

	ld	a,(SKMET)
	cp	1	;Si metodo>2, asumimos metodo=0
	jp	z,METODO1
	cp	2
	jp	z,METODO2
	jp	METODO0

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

	;--- SEEK: Version DOS 2 

SEEK2:	push	bc
	ld	c,_SEEK
	call	DOSCALL
	or	a
	jr	nz,SEK2END
	push	hl,de
	call	FLUSH
	pop	de,hl
SEK2END:	pop	bc
	ret

SKMET:	db	0


;--- NOMBRE: RDABS y WRABS
;      Lectura y escritura de sectores
;    ENTRADA:   B  = Unidad
;               DE = Direccion del bufer
;               HL = No. de sectores a leer/escribir
;               IX = PARAM y P(1) = Sector inicial
;    SALIDA:    A  = Error
;               HL = No. de bytes leidos/escritos (0 si hay error)
;    REGISTROS: F
;    LLAMADAS:  DOSCALL, FLUSH
;    VARIABLES: _SETDTA, _RDABS, DOSVERP

RDABS:	ld	a,_RDABS
	ld	(SECCODE),a
	jr	RWABS

WRABS:	ld	a,_WRABS
	ld	(SECCODE),a

RWABS:	push	ix,iy,de,bc,hl
	ld	c,_SETDTA	;Establecimiento de la dir. de transferencia
	call	#F37D

	pop	de,bc
	ld	l,b	;L = Unidad
	ld	h,e	;H = No. de sectores a leer
	ld	ix,PARAM
	push	bc,de
	ld	e,(ix+2)
	ld	d,(ix+3)	;DE = Sector inicial

	ld	a,(SECCODE)
	ld	c,a
	call	DOSCALL	;Lectura o escritura!
	or	a
	jr	nz,FRDABSE

	ld	a,(DOSVERP)	;Flusheamiento si es DOS 2
	dec	a
	call	nz,FLUSH

	pop	hl	;Transformacion de sectores a bytes
	ld	h,l
	sla	h
	ld	l,0

FRDABS:	pop	bc,de,iy,ix
	ret
FRDABSE:	pop	hl	;Error: vuelta con 0 bytes leidos
	ld	hl,0
	cp	1
	jr	z,FRDABS	;Transforma el error #FF en 1
	ld	a,1
	jr	FRDABS

SECCODE:	db	0


;--------------------------------------------------------------------
;--- RUTINAS Y ZONA DE DATOS DEL REPRODUCTOR DE EFECTOS DE SONIDO ---
;--------------------------------------------------------------------

;
; Some space for you to fill... Anybody knows a joke?
;
; Eres mas indeciso que el registro R !!

; Song structure OFFSETS
!SEEID:	EQU	&H00	;ID: "SEE3org", version number
!HISPT:	EQU	&H08	;Highest used Start_pattern
!HIPTA:	EQU	&H0A	;Higest used pattern+1_address
!HISFX:	EQU	&H0C	;Highest used SFX
!_____:	EQU	&H0E	;Unused
!POSTB:	EQU	&H10	;Table with SFX start pattern
!PATTS:	EQU	&H0210	;Pattern data (max 1024 patts)

;      [Vars]
SFX_DIR:	DW	0	;Base address (#8000-#BFFF) 
SFX_SL:	DB	0	;Mapper 
SFX_PRI:	DB	0	;SFX priority: 0=Overwrite, otherwise no ef 
;                                           can be set if the current one is
;                                           still playing!
SFX_VOLM:	DB	15	;Maximum Volume (makes real volume relativ 
SFX_BUSY:	db	0

;-------------------------------------------------------------------------------

;--- NOMBRE: SFXINI
;      Inicializa un juego de efectos de sonido
;    ENTRADA:   A  = Segmento
;               HL = Direccion
;    SALIDA:    Cy = 1 si el fichero es incorrecto
;    REGISTROS: AF, BC, DE, HL

SFXINI:	callint	_SFXINI

_SFXINI:	di
	call	DIRTOP2
	LD	(SFX_TMP1),hl	;check file ("SEE3") 
	ld	(SFX_TMP2),a
	LD	BC,!SEEID
	ADD	HL,BC
	LD	DE,SEE_ID
	LD	B,4
SEEI.0:	LD	A,(DE)
	CP	(HL)
	SCF		;[Cy:1] 
	ret	NZ	;not a SEE3 file! 
	INC	HL
	INC	DE
	DJNZ	SEEI.0

	inc	hl
	inc	hl
	inc	hl
	inc	hl
	LD	DE,_HISPT	;copy header 
	LD	BC,8
	LDIR

	xor	a
	LD	(SFX_PRI),A	;[Priority] 

	ld	hl,(SFX_TMP1)
	ld	(SFX_DIR),hl
	ld	a,(SFX_TMP2)
	ld	(SFX_SL),a

	or	a
	ret

SFX_TMP1:	dw	0
SFX_TMP2:	db	0


;--- NOMBRE: SFXSET
;      Ejecuta un efecto de sonido
;    ENTRADA:   C = Numero de efecto
;               B = Prioridad (0=baja, <>0=alta)
;    SALIDA:    Cy= 1 -> Error en A:
;                        0 = El SFX no existe
;                        1 = Suena otro con mas prioridad
;                      255 = SFX no definido (OFF)
;    REGISTROS: DE, HL

SFXSET:	LD	A,B	;New Priority <>0 ?
	di
	AND	A
	JR	NZ,SEFF.0
	LD	A,(SFX_PRI)	;Current SFX priority <>0? 
	AND	A
	JR	Z,SEFF.0
	LD	A,(INT_DATA)	;SFX on? 
	bit	1,a
	SCF		;[Cy:1] 
	LD	A,1	;[error nr] 
	RET	NZ

SEFF.0:	ld	a,(SL_2)	;Store and Set mapper
	ld	(SFX_SL2),a
	ld	a,(SFX_SL)
	push	bc,de,hl
	call	PUT_SL2
	pop	hl,de,bc

	LD	A,(_HISFX)	;Max SFX? 
	CP	C
	LD	A,0	;[error nr] 
	jr	c,FSFXSET	;Cy -> SFX doesn't excist 

	LD	L,C
	LD	H,0
	ADD	HL,HL	;Eff *2 
	LD	DE,(SFX_DIR)
	ADD	HL,DE
	LD	DE,!POSTB
	ADD	HL,DE
	LD	E,(HL)	;Get start pattern 
	INC	HL
	LD	D,(HL)
	LD	A,D
	CP	&HFF	;in use?... 
	SCF		;[Cy:1] 
	jr	z,FSFXSET	;...nope 

;All checks are done, now set SFX:

	di

	ld	a,#FF
	ld	(SFX_BUSY),a

	xor	a
	ld	(_HALT),a
	ld	(LOOPNR),a

	CALL	PSGOFF

	LD	A,C
	LD	(SFX_NUM),A
	LD	A,B
	LD	(SFX_PRI),A

	LD	(PAT_NR),DE

	CALL	C_PTAD

	LD	HL,0
	LD	(TEMPO),HL
	ld	a,(INT_DATA)
	or	a
	push	af
	call	z,INT_ON
	pop	af
	set	1,a
	ld	(INT_DATA),a
	AND	A	;[Cy:0], succesfull 

FSFXSET:	push	af
	ld	a,(SFX_SL2)
	push	bc
	call	PUT_SL2
	pop	bc
	xor	a
	ld	(SFX_BUSY),a
	pop	af
	ret


;--- NOMBRE: SFXCUT
;      Corta el efecto de sonido actual
;    ENTRADA:   -
;    SALIDA:    -
;    REGISTROS: AF

SFXCUT:	di
	LD	A,(INT_DATA)
	or	a
	jp	z,PSGOFF
	res	1,a
	ld	(INT_DATA),a
	or	a
	call	z,INT_OFF
	ei
	JP	PSGOFF


;+----- Main routine (timed) / Main.A from own timing -----+
;       El segmento SFX_SL ha de estar en P. 2

SFXINT:	LD	A,(TEMPO+1)
	SUB	1
	LD	(TEMPO+1),A
	RET	NC
	LD	A,(TEMPO+0)
	LD	(TEMPO+1),A

	LD	HL,(PATADR)

MAIN.0:	LD	A,(_HALT)	;Halt counter 
	AND	A
	JR	Z,MAIN.1

	DEC	A
	LD	(_HALT),A
	AND	A
	ret	nz
	JR	MAIN.2	;previously a HALT event was done, now do PS

MAIN.1:	CALL	!EVENT	;Do operation command 

MAIN.2:	CALL	SETPSG	;Set PSG reg. 
	LD	(PATADR),HL
	ret


;+----- Event Commands -----+
!EVENT:	LD	A,(HL)	;Get event 
	LD	C,A
	AND	&H70
	AND	A
	RET	Z	;No command 

	CP	&H10
	JP	Z,EV_HLT	;Halt 
	CP	&H20
	JP	Z,EV_FOR	;Loop start 
	CP	&H30
	JP	Z,EV_NXT	;Loop next 
	CP	&H40
	JP	Z,EV_STR	;Continue Loop start 
	CP	&H50
	JP	Z,EV_RER	;Continue Loop next 
	CP	&H60
	JP	Z,EV_TEM	;Tempo 
	JP	EV_END	;End 

;- Halt "hlt:x"
EV_HLT:	LD	A,C
	AND	&H0F
	LD	(_HALT),A
	POP	AF	;restore stack 
	ret

;- Loop start "for:x"
EV_FOR:	PUSH	HL

	LD	A,(LOOPNR)	;Inc loop nr 
	INC	A
	AND	&H03
	LD	(LOOPNR),A

	PUSH	HL
	LD	HL,LOOPBF
	LD	D,0
	LD	E,A
	ADD	HL,DE
	ADD	HL,DE
	ADD	HL,DE

	LD	A,C
	AND	&H0F
	LD	(HL),A	;set Counter 
	INC	HL
	POP	DE
	LD	(HL),E	;set Address 
	INC	HL
	LD	(HL),D

	POP	HL
	RET

;- Loop next "next"
EV_NXT:	PUSH	HL

	LD	A,(LOOPNR)
	AND	&H03

	LD	HL,LOOPBF
	LD	D,0
	LD	E,A
	ADD	HL,DE
	ADD	HL,DE
	ADD	HL,DE
	DEC	(HL)	;Dec. counter 
	JR	Z,EV_N.0	;Z, loop end 

	INC	HL
	LD	E,(HL)	;get address 
	INC	HL
	LD	D,(HL)

	POP	HL
	EX	DE,HL
	RET

;Loop done, now remove this loop
EV_N.0:	LD	A,(LOOPNR)	;Dec loopnr 
	DEC	A
	AND	3
	LD	(LOOPNR),A

	POP	HL
	RET

;- Continue loop start "start"
EV_STR:	LD	(CLPADR),HL	;Store Patt adr. 
	RET

;- Continue loop next "rerun"
EV_RER:	LD	HL,(CLPADR)
	RET

;- Tempo "tmp:x"
EV_TEM:	LD	A,C
	AND	&H0F
	LD	(TEMPO+0),A
	LD	(TEMPO+1),A
	RET

;- Effect end " end "
EV_END:	LD	A,(INT_DATA)
	or	a
	jr	z,EVEND1
	res	1,a
	LD	(INT_DATA),A
	or	a
	call	z,INT_OFF
EVEND1:	POP	AF	;restore stack
	ret


;+----- Set all PSG regs.-----+
SETPSG:	LD	IX,PSGREG
	LD	E,0	;Start reg.0 
	INC	HL	;[skip event byte] 

	LD	B,3	;First 6 reg. [sound frequency] 
STPS.0:	PUSH	BC
	LD	C,(HL)	;r# 0, 2 or 4 
	INC	HL
	LD	B,(HL)	;r# 1, 3 or 5 
	BIT	7,(HL)	;check and handle Tuning 
	CALL	NZ,TUNWUP
	BIT	6,(HL)
	CALL	NZ,TUNWDW
	INC	HL
	LD	A,C
	CALL	WRTPSG
	LD	A,B
	AND	&H0F
	CALL	WRTPSG
	POP	BC
	DJNZ	STPS.0

	LD	A,(HL)	;r# 6 [Rustle frequency] 
	INC	HL
	BIT	7,A
	CALL	NZ,TUN_UP
	BIT	6,A
	CALL	NZ,TUN_DW
	AND	&H1F
	CALL	WRTPSG

	LD	A,(HL)	;r# 7 [channel control, ON/OFF] 
	AND	&H3F
	OR	&H80	;bit 7 is necessary to write the PSG!! 
	INC	HL
	CALL	WRTPSG

	LD	B,3	;r# 8-10 [Volume] 
STPS.1:	PUSH	BC
	LD	A,(HL)
	INC	HL
	LD	C,A
	AND	&H1F
	LD	B,A	;Save real volume.. 
	BIT	4,A
	JP	NZ,STPS.2	;Volume pattern is set. 
	BIT	7,C
	CALL	NZ,TUN_UP
	BIT	6,C
	CALL	NZ,VOL_DW
	LD	B,A	;Save real volume.. 
	CALL	FIXVOL
STPS.2:
	CALL	WRTPSG
	LD	(IX-1),B	; ..Re-Write real volume to buffer (not fixe
	POP	BC
	DJNZ	STPS.1

	LD	B,3	;r# 11-13 [volume effect] 
STPS_2:	LD	A,(HL)
	INC	HL
	CALL	WRTPSG
	DJNZ	STPS_2
	RET


;Tuning
;- byte
TUN_UP:	ADD	A,(IX)	;Up 
	RET
TUN_DW:	SUB	(IX)	;Down 
	NEG
	RET
;- word
TUNWUP:	PUSH	HL
	LD	L,(IX)
	LD	H,(IX+1)
	ADD	HL,BC
	PUSH	HL
	POP	BC
	POP	HL
	RET
TUNWDW:	PUSH	HL
	LD	L,(IX)
	LD	H,(IX+1)
	XOR	A
	SBC	HL,BC
	PUSH	HL
	POP	BC
	POP	HL
	RET

;Volume Down
VOL_DW:	AND	&H0F
	LD	B,A
	LD	A,(IX+0)
	AND	&H0F
	SUB	B
	RET	NC
	XOR	A
	RET


;Make relative volume (depending on "SFX_VOLM")
;In:  A, volume
;Out: A, new volume [seevol - (15-volume)]
FIXVOL:	AND	&H0F
	XOR	15
	LD	C,A
	LD	A,(SFX_VOLM)
	AND	&H0F
	SUB	C
	RET	NC
	XOR	A
	RET


;Shut up PSG!
PSGOFF:	LD	A,7
	OUT	(&HA0),A
	LD	A,&H3F OR &H80
	OUT	(&HA1),A
	RET


;Write PSG (not ROM-BIOS compatible!)
;In:   A, data
;      E, port
;     IX, PSG store table
;Out:  E+1
;     IX+1
WRTPSG:	LD	(IX),A
	INC	IX
	PUSH	AF
	LD	A,E
	OUT	(&HA0),A
	INC	E
	POP	AF
	OUT	(&HA1),A
	RET


;Calculate pattern address (only for "SEE3org" files)
;In:  (PAT_NR), pattern nr (0-$3FF)
;Out: (PATADR), pattern adr
;           DE, pattern adr
C_PTAD:	PUSH	AF
	PUSH	HL
	PUSH	BC
	LD	HL,(SFX_DIR)
	LD	BC,!PATTS
	ADD	HL,BC
	LD	BC,(PAT_NR)
	LD	DE,15
C_PA.0:	LD	A,B
	OR	C
	JR	Z,C_PA.1
	ADD	HL,DE
	DEC	BC
	JP	C_PA.0
C_PA.1:	LD	(PATADR),HL
	EX	DE,HL
	POP	BC
	POP	HL
	POP	AF
	RET


;+----------------------------< Work Area >------------------------------------+
SEE_ID:	DM	"SEE3???",&H10	;ID + filetype + vers.nr 
TEMPO:	DB	0,0	;[Original, counter] 
PAT_NR:	DW	0	;Current pattern (0-1023) (temp) 
PATADR:	DS	2	;Current pattern address 
SFX_NUM:	DB	0	;Current Sound Effect (0-255) 
_HALT:	DB	0	;Halt counter (0-15) 
LOOPNR:	DB	0	;Current loop number (0-3) 
LOOPBF:	DS	4*3	;[4 x Counter+Address] 
CLPADR:	DW	&H00	;"Continue-loop" / "Restart" address 

;Copy from Song structure OFFSETS
_SEEID:	DS	8	;"SEE3EDIT" 
_HISPT:	DS	2	;Highest used Start_pattern 
_HIPTA:	DS	2	;Higest used pattern+1_address 
_HISFX:	DS	2	;Highest used SFX 
_FLELN:	DS	2	;File length 
_POSTB:	DS	2	;Table with SFX start pattern 
_PATTS:	DS	2	;Pattern data (max 1024 patts) 

;            reg.  0 1 2 3 4 5 6 7 8 9 A B C D
PSGREG:	DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0	;   - PSG port store buffer - 
SFX_SL2:	db	0


;--------------------------------------------------
;--- REPRODUCTOR MUSICAL (PARTE DEL SEGMENTO 0) ---
;--------------------------------------------------

MUS_PAU0:	db	0	;#FF si hay una musica pausada
MUS_SL0:	db	0	;Segmento actual de la musica
;TIPOREP:         db      0                ;Tipo de reproductor.   ;@@@ ;Ahora esta en #4164
	;                         0: MB14
	;                         1: MBWave
	;                         2: MBFM

;--- NOMBRE: READ_MUS
;      Lee un dato del segmento 5
;    ENTRADA:  HL = Direccion
;    SALIDA:   A  = Dato
;    MODIFICA: F, AF'

READ_MUS:	ld	a,5
	jp	READ_SL


;--- NOMBRE: WRITE_MUS
;      Escribe un dato en el segmento 5
;    ENTRADA:  HL = Direccion
;              E  = Dato
;    SALIDA:   -
;    MODIFICA: F, AF'

WRITE_MUS:	ld	a,5
	jp	WRITE_SL


;--- NOMBRE: CALL_MUS
;      Ejecuta una rutina del segmento 5 a traves de la pagina 1
;    ENTRADA:  IX = Direccion
;              AF, BC, DE, HL pasados a la rutina
;    SALIDA:   AF, BC, DE, HL devueltos por la rutina
;    MODIFICA: IX, IY

CALL_MUS:	;ld      iy,#0500
	push	af
	ld	iy,TABSEGS
	ld	a,(iy+5*2+1)
	ld	iyh,a
	ld	iyl,0
	pop	af
	jp	CAL_SEG


;--- NESMAN: Llama a una funcion de NestorMan

NESMAN:	ld	de,#2202
	jp	EXTBIO


;--- NOMBRE: CHKREP
;      Comprueba si hay algun reproductor musical cargado
;    ENTRADA:  -
;    SALIDA:   Cy = 1 si hay alguno cargado
;    MODIFICA: AF

CHKREP:	push	bc,de,hl
	ld	a,(NUMSEGS)
	cp	6	;Si hay menos de 6 segmentos,
	ccf		;                ;seguro que no hay rep. cargado
	jr	nc,CHKREPEND
	ld	a,(SL_2)
	push	af
	ld	a,5
	call	PUT_SL2

	ld	hl,#8000
	ld	de,NPSTR
	ld	b,12
BUCCREP:	ld	a,(de)
	cp	(hl)
	scf
	ccf
	jr	nz,FBUCCREP
	inc	hl
	inc	de
	djnz	BUCCREP
	scf

FBUCCREP:	push	af
	pop	bc
	pop	af
	push	bc
	call	PUT_SL2
	pop	af
CHKREPEND:	pop	hl,de,bc
	ret

NPSTR:	db	"NestorPlayer"


;---------------- check aanwezige soundchips ---------------
;
;Uitvoer = chips_in bevat 0,1 of 2. (msx-audio,msx-music,both)
;ATENCION: Esta rutina se ha de ejecutar en la pagina 2
;Usa MUSCHIPS en lugar de CHIPS

;CHIPSSLT:	equ	_CHIPSSLT+#4000 ;v1.01, era #BFFE
;SLTTST:	equ     _SLTTST+#4000   ;v1.01, era #BFFD

SRCCHP:	xor	a
	ld	(MUSCHIPS+#4000),a

	;ld	a,1
	;call	GET_SLT+#4000   ;v1.01
	;ld	a,b
	;ld	(CHIPSSLT),a

	CALL	SRCFMP+#4000
	CALL	SRCAUD+#4000
	call	SRCOPL4+#4000

	ld	a,(#FCC1)	;v1.01, era (CHIPSSLT)
	ld	h,#40
	call	ENASLT
	RET

;----- zoek msx-music -----
;      Como ke "zoek"?? Si esta rutina es del Armando!!


SRCFMP:
	;xor     a
	;ld      (savefm+#4000),a

	call	findfm+#4000
	di
	ld	a,(0FCC1h)
	ld	h,040h
	call	024h
	;ei

	ret

findfm:
	ld	hl,0FCCAh
	xor	a
	ld	b,4
FMLP2:	push	bc
	ld	b,4
FMLP1:	push	bc
	push	af
	push	hl
	set	7,a
	di
	ld	h,040h
	call	024h
	ei
	pop	hl
	push	hl
	ld	a,(hl)
	cp	020h
	call	z,FMTest+#4000
	jp	z,FMFnd+#4000
	pop	hl
	pop	af
	add	a,4
	and	0Fh
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	pop	bc
	djnz	FMLP1
	add	a,1
	and	03h
	pop	bc
	djnz	FMLP2
	ei
	ret
FMTest:	ld	hl,0401Ch
	ld	de,FMText+#4000
	ld	b,4
FMLP:	ld	a,(de)
	cp	(hl)
	ret	nz
	inc	hl
	inc	de
	djnz	FMLP
	cp	a
	ret
FMFnd:	pop	hl
	pop	af
	pop	bc
	pop	bc

	;ld      a,1
	;ld      (savefm),a

	ld	a,(MUSCHIPS+#4000)
	set	0,a
	ld	(MUSCHIPS+#4000),a

	;ld      hl,savemusic
	;inc     (hl)

FM_Check:	ld	hl,04018h
	ld	de,FM_Japones+#4000
	ld	b,4
Japo:	ld	a,(de)
	cp	(hl)
	jp	nz,Es_Japones+#4000
	inc	hl
	inc	de
	djnz	Japo
	ei
	ret
Es_Japones:
	ld	a,(07FF6h)
	or	1
	ld	(07FF6h),a
	ei
	ret
FMText:	db	"OPLL"
FM_Japones:	db	"APRL"


;---- zoek msx-audio ----

SRCAUD:	IN	A,(0C0h)
	CP	0FFh
	RET	Z
	;LD      A,(chips_in) 
	;INC     A                ;SET     0,A 
	;LD      (chips_in),A 

	ld	a,(MUSCHIPS+#4000)
	set	1,a
	ld	(MUSCHIPS+#4000),a
	RET

;---- busqueda del OPL4 ----

SRCOPL4:	in	a,(#C4)
	cp	#FF
	ret	z

	ld	a,(MUSCHIPS+#4000)
	set	2,a
	ld	(MUSCHIPS+#4000),a
	ret

FSRCCHP:	;


;--- CARGA DE SAMPLEKIT MUSIC MODULE ---

;MOVSMPA carga la pagina 2 en las 16K bajas de la sample-RAM
;MOVSMPB carga la pagina 2 en las 16K altas de la sample-RAM

MOVSMPA:	di
	call	MOVSM2
	jr	akinas
MOVSMPB:	di
	call	MOVSM3
akinas:	DI
	LD	A,4
	OUT	(0C0h),A
	LD	A,060h
	OUT	(0C1h),A
	LD	BC,04000h
	LD	HL,08000h
MOVSM6:	LD	A,0Fh
	OUT	(0C0h),A
	LD	A,(HL)
	OUT	(0C1h),A
	LD	A,4
	OUT	(0C0h),A
	LD	A,080h
	OUT	(0C1h),A
	INC	HL
	DEC	BC
	LD	A,B
	OR	C
	JR	Z,MOVSM4
MOVSM5:	IN	A,(0C0h)
	BIT	7,A
	JR	Z,MOVSM5
	BIT	4,A
	JR	Z,MOVSM6
MOVSM4:	LD	A,4
	OUT	(0C0h),A
	LD	A,078h
	OUT	(0C1h),A
	LD	A,080h
	OUT	(0C1h),A
	LD	A,7
	OUT	(0C0h),A
	LD	A,1
	OUT	(0C1h),A
	EI
	RET
MOVSM3:	LD	HL,SAMPD3
	JR	MOVSM7
MOVSM2:	LD	HL,SAMPD2
MOVSM7:	LD	B,10
MOVSM8:	LD	A,(HL)
	OUT	(0C0h),A
	INC	HL
	LD	A,(HL)
	OUT	(0C1h),A
	INC	HL
	DJNZ	MOVSM8
	RET
SAMPD2:	DB	004h,078h,004h,080h,007h,001h,007h,060h,008h,000h
	DB	009h,000h,00ah,000h,00bh,0ffh,00ch,00fh,010h,0f0h
SAMPD3:	DB	004h,078h,004h,080h,007h,001h,007h,060h,008h,000h
	DB	009h,000h,00ah,010h,00bh,0ffh,00ch,01fh,010h,0f0h


;-----------------------------------------------------------------------
;--- ZONA DE DATOS Y PUNTO DE EJECUCION DE LA RUTINA DE INTERRUPCION ---
;-----------------------------------------------------------------------

;----- Zona de datos de las interrupciones

;INT_DATA:  db      0                ;Interrupciones en marcha:
;                                   ;  b0: Int. de usuario
;                                   ;  b1: Efecto sonoro PSG
;                                   ;  b2: Musica MB14 (F.A.)
;                                   ;  b3: Musica MB4MS Wave (F.A.)
;                                   ;  b4: Musica MB4MS FM (F.A.)

USR_SL:	db	0
USR_DIR:	dw	0

NEW_INT:	jp	#0000	;Nueva int: salto a RES_INT  
	nop		;en la P. 3  
	nop


;--- Subrutina INT_ON: conecta el control de interrupciones de NestorBASIC
;    Vuelve en modo DI

INT_ON:	di

	ld	hl,(USRTAB)	;Establece el salto a OLD_INT  
	ld	bc,OLD_INT-RES_I
	add	hl,bc	;HL = Dir. real de OLD_INT  
	push	hl
	ld	ix,(USRTAB)
	ld	bc,RES_INT-RES_I
	add	ix,bc	;IX = Dir. real del RES_INT  
	ld	(ix+1),l
	ld	(ix+2),h

	pop	de	;Guarda el gancho antiguo  
	ld	hl,H.TIMI
	ld	bc,5
	ldir

	ld	hl,(USRTAB)	;Establece nuevo gancho: salto a RES_INT  
	ld	bc,RES_INT-RES_I
	add	hl,bc	;HL = Dir. real de RES_INT  
	ld	(NEW_INT+1),hl
	ld	hl,NEW_INT
	ld	de,H.TIMI
	ld	bc,5
	ldir
	ret


;--- Subrutina INT_OFF: desconecta el control de interrupciones de NestorBASIC
;    Vuelve en modo DI

INT_OFF:	di
	ld	hl,(USRTAB)
	ld	bc,OLD_INT-RES_I
	add	hl,bc	;HL = Dir. real de OLD_INT  
	ld	de,H.TIMI
	ld	bc,5
	ldir
	ret


;--- Punto de ejecucion al producirse una interrupcion

HAYQUEND:	db	0	;=#FF si hay que llamar a STPMUS
;                                   ;y detener la interrupcion de la musica
;                                   ;en la proxima interrupcion

INT_EXE:	di
	ld	a,(INT_DATA)
	or	a
	jr	nz,CHKINT0

	call	INT_OFF	;Si INT_DATA=0, desconecta el control de int
	ei
	ret

CHKINT0:	bit	0,a
	jr	z,CHKINT1

	ld	a,(SL_2)	;Conexion del segmento de la int.
	push	af
	ld	a,(USR_SL)
	call	PUT_SL2

	ld	hl,(USR_DIR)	;Llamada a la rutina de int. de usuario
	call	DIRTOP2
	call	JOTAPE

	pop	af
	call	PUT_SL2

	ld	a,(INT_DATA)

CHKINT1:	bit	1,a
	jr	z,CHKINT2

	ld	a,(SFX_BUSY)
	or	a
	ld	a,(INT_DATA)
	jr	nz,CHKINT2

	ld	a,(SL_2)
	push	af
	ld	a,(SFX_SL)
	call	PUT_SL2

	call	SFXINT	;Llamada a la rutina de int. de SFX

	pop	af
	call	PUT_SL2

	ld	a,(INT_DATA)

CHKINT2:	and	%11100
	jr	z,CHKINT3
	ld	a,(HAYQUEND)
	or	a
	jr	nz,CHKINT2B
	ld	a,(MUS_PAU0)
	or	a
	jr	nz,CHKINT3

	ld	a,(SL_2)
	push	af
	ld	a,(MUS_SL0)	;<---!!!
	call	PUT_SL2

	ld	ix,MUSINT
	call	CALL_MUS	;Llamada a la interrupcion del reproductor
	or	a
	jr	nz,CHKI22

	push	af
	ld	a,#FF	;Si MUSINT devuelve (MUS_ON)=0,
	ld	(HAYQUEND),a	;HAYQUEND=#FF, y asi MUSINT de desactivara
	xor	a	;en la proxima interrupcion
	ld	(MUS_PAU0),a
	ld	hl,MUS_PAU
	ld	e,0
	call	WRITE_MUS
	pop	af

CHKI22:	ld	(MUS_SL0),a

	ld	(SL_2),a	;El reproductor hace cambios de segmento
	call	GET_SF	;directamente con OUT (#FE),A;
	ld	(SEG_2),a	;por tanto tras su ejecucion hay que
	ld	a,b	;actualizar la tabla usada por PUT_SL2
	ld	(SLOT_2),a	;manualmente.

	pop	af
	call	PUT_SL2

	jr	CHKINT3

CHKINT2B:	xor	a
	ld	(HAYQUEND),a
	ld	ix,STPMUS
	call	CALL_MUS
	ld	hl,FADING
	ld	e,0
	call	WRITE_MUS
	ld	a,(INT_DATA)	;Por si el final de un fade 
	and	%11100011	;ha terminado la musica pero ha dejado 
	ld	(INT_DATA),a	;la interrupcion activa 
	call	z,INT_OFF

CHKINT3:	ret

JOTAPE:	jp	(hl)


;--- Rutinas de la tabla de salto

;--- NOMBRE: GINFOUS
;      Devuelve informacion sobre la interrupcion de usuario
;    ENTRADA: -
;    SALIDA:  A  = Segmento
;             HL = Direccion

GINFOUS:	ld	a,(USR_SL)
	ld	hl,(USR_DIR)
	ret


;--- NOMBRE: GINFOSFX
;      Devuelve informacion sobre la interupcion del efecto sonoro
;    ENTRADA: A  = Nuevo volumen maximo (-1 para no cambiarlo)
;    SALIDA:  A  = Segmento
;             HL = Direccion
;             B  = Numero de SFX
;             C  = Prioridad
;             D  = Numero SFX mayor
;             E  = Volumen maximo

GINFOSFX:	cp	-1
	jr	z,NOCVG2
	cp	15
	jr	c,NOCVG
	ld	a,15
NOCVG:	ld	(SFX_VOLM),a
NOCVG2:	ld	hl,(SFX_DIR)
	ld	a,(SFX_NUM)
	ld	b,a
	ld	a,(SFX_PRI)
	ld	c,a
	ld	a,(_HISFX)
	ld	d,a
	ld	a,(SFX_VOLM)
	ld	e,a
	ld	a,(SFX_SL)
	ret


;--- NOMBRE: GINFOMUS
;      Devuelve informacion sobre la musica que suena
;      No hace nada si no suena o si los rep. no estan inicializados
;    ENTRADA: -
;    SALIDA:  A  = Segmento logico de la musica que suena
;             HL = Direccion de la musica que suena
;             B  = Chips presentes
;             C  = Chips activos
;             D  = Paterna
;             E  = Posicion
;             IXl= #FF si la musica esta pausada
;             Cy = 1 si los reproductores no estan inicializados

GINFOMUS:	call	CHKREP
	ccf
	ret	c

	ld	a,(INT_DATA)
	and	%11100011
	scf
	ccf
	ret	z

	ld	a,(MUS_PAU0)
	ld	ixl,a
	ld	hl,STEP
	call	READ_MUS
	ld	e,a
	ld	hl,POS
	call	READ_MUS
	ld	d,a
	ld	hl,CHIPS_AC
	call	READ_MUS
	ld	c,a
	;ld	hl,CHIPS        ;v1.01
	;call	READ_MUS        ;v1.01
	ld	a,(MUSCHIPS)	;v1.01
	ld	b,a
	push	de
	ld	hl,MUS_DIR
	call	READ_MUS
	ld	e,a
	inc	hl
	call	READ_MUS
	and	%00111111
	ld	d,a
	ld	hl,MUS_SL
	call	READ_MUS
	ex	de,hl
	pop	de
	or	a
	ret


;---------------------------------------------
;--- PUNTO DE EJECUCION DE LA PARTE OCULTA ---
;---------------------------------------------

;Al hacer un USR(funcion), la parte residente desvia la ejecucion aqui
;con la direccion de la matriz de parametros en HL y el no. de funcion en BC.
;Al terminar, HL ha de contener el valor a devolver al BASIC a traves del USR.

OCU_EXE:	ld	(DIRP),hl
	ld	(FUNCION),bc	;Copia del no. de funcion y de la matriz P
	ld	de,PARAM	;a la zona de datos de la parte oculta
	ld	bc,(DIMP+1)*2
	ldir

	ld	hl,(FUNCION)	;Calculo de la direccion a ejecutar
	push	hl	;segun la funcion
	pop	bc
	add	hl,bc
	add	hl,bc
	push	hl
	pop	bc
	ld	hl,FUNC_00
	add	hl,bc
	ld	ix,PARAM
	ld	iy,(DIRP)
	call	EXEHL
	ret

EXEHL:	jp	(hl)

;--- Tabla de salto de las funciones.
;    Son llamadas con IX=PARAM, IY=DIRP.

FUNC_00:	jp	LIBERALL	;Libera la memoria
FUNC_01:	jp	GETINFO	;Muestra informacion sobre NestorBASIC

FUNC_02:	jp	RD1SLNI	;Lectura de un byte de un SL
FUNC_03:	jp	RD1SLI	;Idem con autoincremento de P(1)
FUNC_04:	jp	RD2SLNI	;Lectura de dos bytes de un SL
FUNC_05:	jp	RD2SLI	;Idem con autoincremento de P(1)
FUNC_06:	jp	WR1SLNI	;Escritura de un byte de un SL
FUNC_07:	jp	WR1SLI	;Idem con autoincremento de P(1)
FUNC_08:	jp	WR2SLNI	;Escritura de dos bytes de un SL
FUNC_09:	jp	WR2SLI	;Idem con autoincremento de P(1)
FUNC_10:	jp	LDIRSL	;Copia de un bloque de un SL a otro
FUNC_11:	jp	FILLSLNI	;Llenado de una zona de memoria
FUNC_12:	jp	FILLSLI	;Idem con autoincremento

FUNC_13:	jp	RD1VNI	;Lectura de un byte de la VRAM
FUNC_14:	jp	RD1VI	;Idem con autoincremento de P(0) y P(1)
FUNC_15:	jp	RD2VNI	;Lectura de dos bytes de la VRAM
FUNC_16:	jp	RD2VI	;Idem con autoincremento de P(0) y P(1)
FUNC_17:	jp	WR1VNI	;Escritura de un byte en VRAM
FUNC_18:	jp	WR1VI	;Idem con autoincremento de P(0) y P(1)
FUNC_19:	jp	WR2VNI	;Escritura de dos bytes en VRAM
FUNC_20:	jp	WR2VI	;Idem con autoincremento de P(1)
FUNC_21:	jp	LDIRVS	;Transferencia de VRAM a un SL
FUNC_22:	jp	LDIRSV	;Transferencia de un SL a VRAM
FUNC_23:	jp	LDIRV	;Transferencia de VRAM a VRAM
FUNC_24:	jp	FILLVNI	;Llenado de una zona de VRAM
FUNC_25:	jp	FILLVI	;Idem con autoincremento de la direccion

FUNC_26:	jp	DIRO	;Busqueda de ficheros
FUNC_27:	jp	RENO	;Renombrado de un fichero
FUNC_28:	jp	DELO	;Borrado de un fichero
FUNC_29:	jp	MOVEO	;Movimiento de un fichero
FUNC_30:	jp	CREATEO	;Creacion de un fichero
FUNC_31:	jp	OPENO	;Apertura de un fichero
FUNC_32:	jp	CLOSEO	;Cerrado de un fichero
FUNC_33:	jp	READO	;Lectura de un fichero
FUNC_34:	jp	READOV	;Lectura de un fichero a VRAM
FUNC_35:	jp	RDSEC	;Lectura de sectores
FUNC_36:	jp	RDSECV	;Lectura de sectores a VRAM
FUNC_37:	jp	WRITEO	;Escritura en un fichero
FUNC_38:	jp	WRITEOV	;Escritura de VRAM a un fichero
FUNC_39:	jp	WRSEC	;Escritura de sectores
FUNC_40:	jp	WRSECV	;Escritura de VRAM a sectores
FUNC_41:	jp	FILLF	;Rellenado de un fichero
FUNC_42:	jp	SEEKO	;Establecimiento del puntero de un fichero
FUNC_43:	jp	GETDRV	;Obtencion de la unidad actual
FUNC_44:	jp	CHDRV	;Establecimiento de la unidad actual
FUNC_45:	jp	GALLOC	;Obtiene tamanio/capac. libre de un disco
FUNC_46:	jp	GETDIR	;Obtencion del directorio actual
FUNC_47:	jp	CHDIR	;Establecimiento del directorio actual
FUNC_48:	jp	GETRAMD	;Obtencion del tamanio del RAM disk
FUNC_49:	jp	SETRAMD	;Establecimiento del RAM disk
FUNC_50:	jp	GETATRIB	;Obtencion de los atributos de un fichero
FUNC_51:	jp	SETATRIB	;Establ. de los atrib. de un fichero
FUNC_52:	jp	PARSE	;Tratamiento de una cadena de directorio

FUNC_53:	jp	COMPGFX	;Compresion de un grafico
FUNC_54:	jp	DESCGFX	;Descompresion de un grafico

FUNC_55:	jp	NBARUN	;Ejecuta un programa en formato NBA
FUNC_56:	jp	NBASET	;Establece un rograma en formato NBA
FUNC_57:	jp	NBASAVE	;Graba un programa en formato NBA

FUNC_58:	jp	BIOSCALL	;Llamada a una rutina de la BIOS
FUNC_59:	jp	SEGCALL	;Llamada a una rutina en un segmento

FUNC_60:	jp	GFXPRNT	;Impresion de una cadena en modo grafico
FUNC_61:	jp	ST2MEM	;Copia de una cadena a memoria
FUNC_62:	jp	MEM2ST	;Recuperacion de una cadena de memoria

FUNC_63:	jp	BLKINI	;Inicializa el blink
FUNC_64:	jp	BLKMAK	;Construye o borra un bloque blink

FUNC_65:	jp	INFINT	;Devuelve informacion sobre interrupciones
FUNC_66:	jp	ESTINT	;Pone/quita/invierte int. de usuario
FUNC_67:	jp	INFOEFS	;Devuelve informacion sobre efectos sonoros
FUNC_68:	jp	INITEFS	;Inicializa un juego de efectos sonoros
FUNC_69:	jp	PLAYEFS	;Reproduce un efecto sonoro
FUNC_70:	jp	STOPEFS	;Corta un efecto sonoro

FUNC_71:	jp	INITMUS	;Carga de los reproductores musicales
FUNC_72:	jp	INFOMUS	;Devuelve informacion sobre la musica
FUNC_73:	jp	SETCHIPS	;(Des)activa chips musicales
FUNC_74:	jp	PLAYMUS	;Comienza la reproduccion de una musica
FUNC_75:	jp	ENDMUS	;Detiene la ejecucion de la musica
FUNC_76:	jp	PACOMUS	;Pausa la musica
FUNC_77:	jp	FADEMUS	;Fadea la musica
FUNC_78:	jp	LOADMBK	;Carga un samplekit Music Module
FUNC_79:	jp	LOADMWK	;@@@

FUNC_80:	jp	SETMEM	;Establece la memoria max. usable
FUNC_81:	jp	INFONMAN	;Devuelve info sobre NestorMan
FUNC_82:	jp	NMANCALL	;Llamada a una funcion de NestorMan
FUNC_83:	jp	LDIR_NB_NM	;Traspaso de seg NMAN a seg NB
FUNC_84:	jp	LDIR_NM_NB	;Traspaso de seg NB a seg NMAN
FUNC_85:	jp	INSCALL	;Llamada a una funcion de INS
FUNC_86:	jp	INLCALL	;Llamada a una funcion de INL


;-----------------------------------------------------
;--- RUTINAS INAS (Destinos de la tabla de saltos) ---
;-----------------------------------------------------

;Las direcciones de segmentos logicos van de 0 a #3FFF.
;Han de volver con HL=Valor a devolver en el USR.


;--- Terminacion con error TERMERR y sin error TERMOK

;TERMERR:          ld      hl,-1
;                  ret
;TERMOK:	ld	hl,0
;	ret
;TERMHL:	ld	l,a
;	ld	h,0
;	ret
TERMERR:	LD	HL,#FFFF	;@@@
	JR	TERMTODO	;@@@
TERMOK:	LD	HL,#0000	;@@@
	JR	TERMTODO	;@@@
TERMHL:	LD	L,A	;@@@
	LD	H,#00	;@@@
TERMTODO:	LD	DE,(FUNCION)	;@@@
	PUSH	HL	;@@@
	LD	HL,#0001	;@@@
	CALL	COMPDEHL	;@@@
	JR	Z,TERMTODO2	;@@@
	LD	(FUNCION_ANT),DE	;@@@
TERMTODO2:	POP	HL	;@@@
	RET		;@@@

NODOS1:	ld	a,(DOSVERP)
	cp	1
	pop	hl
	jr	z,TERMHL
	push	hl
	ret


;--- NOMBRE: LIBERALL
;      Libera la memoria, desinstala NestorBASIC e inutiliza el USR
;    ENTRADA:   P(0) = 0 -> No liberar la parte residente:
;                           Solo se liberan los segmentos reservados
;                           y se inutiliza el USR.
;               P(0) <>0 -> Liberar la parte residente: se restaura el
;                           HIMEM anterior a la carga de NestorBASIC.
;                           Tambien se borran las variables, y P se inicializa.
;    SALIDA:    USR y P(0) a P(15) indeterminados

LIBERALL:	ld	hl,(ATR_DIR)	;v1.01:
	inc	hl
	ld	(hl),0	;Para que no busque CALLs en RAM desde ahora

	ld	a,(INT_DATA)
	or	a
	call	nz,INT_OFF

	call	CHKREP
	jr	nc,NOBOREP
	ld	ix,STPMUS
	call	CALL_MUS
	ld	e,0
	ld	hl,#8000
	call	WRITE_MUS

NOBOREP:	call	PSGOFF

	ld	a,(DOSVERP)
	dec	a
	jr	z,LIBERAL2

	ld	hl,PUT_P1
	ld	de,LIBPUT1
	ld	bc,3
	ldir
	ld	a,#CD
	ld	(LIBPUT1),a

	;ld      b,#FF            ;Flushea los buferes y los invalida
	;ld      d,#FF
	;ld      c,_FLUSH
	;call    DOSCALL         ;Con esto, INS no fona (???!??!!!)
	ld	a,(SECBUF)	;Restaura los buffers del DOS 2
	ld	b,a
	ld	c,_BUFFER
	call	#F37D

LIBERAL2:	ld	a,(ix)
	or	(ix+1)
	jp	z,NOLIBRES

LIBRES:	ld	hl,(SAVTXT)	;Guardamos puntero BASIC actual
	ld	(POINTX2),hl

	ld	a,(TABSEGS+3)	;Obtenemos segmento fisico original P.1
	ld	(RETRUT+1),a

	ld	hl,(USRTAB)	;Obtenemos direccion de la parte residente
	ld	(FINDIR),hl

	ld	a,SEG_BUF	;Ponemos las rutinas en P. 2,
	call	PUT_SL2	;en el segmento bufer
	ld	hl,LIBERALL	;*** Era 2
	ld	de,LIBERALL+#4000
	ld	bc,FLBALL-LIBERALL
	ldir

	ld	hl,CONTLIB+#4000	;Punto de continuacion USR
	ld	(USRTAB),hl
	ld	hl,(MEMSIZ)
	ld	bc,(STKTOP)
	or	a
	sbc	hl,bc
	ld	(CLSTRO+#4000),hl	;Espacio para cadenas
	ld	hl,(OLDHIM)
	ld	(CLDIRO+#4000),hl	;Direccion para el CLEAR

	ld	hl,FINBTXT+#4000
	push	hl
	ld	hl,(FINDIR)	;Desviamos la ejecucion a RETRUT2
	ex	de,hl	;en la pagina 3
	ld	hl,RETRUT2
	ld	bc,RETRUTF-RETRUT2
	ldir
	ld	hl,(FINDIR)
	jp	(hl)

CONTLIB:	ld	a,(#F342)	;Recuperamos RAM en P. 1
	ld	h,#40
	call	ENASLT
	jp	CONTLIB2

CONTLIB2:	ld	a,2	;La ejecucion vuelve a la P. 1
	call	PUT_SL2	;Reponemos la P. 2
	;*** Era 4
	call	NOLIBRES

CONTBO:	ld	hl,(POINTX2)
	ld	a,(hl)
	or	a
	jr	nz,BUSSIGO
	ld	bc,5
	add	hl,bc

BUSSIGO:	inc	hl
BUCBUSO:	ld	a,(hl)
	or	a
	jr	z,FNDSIGO
	cp	":"
	jr	z,FNDSIGO
	inc	hl
	jr	BUCBUSO

FNDSIGO:	ld	(SAVTXT),hl	;Copiamos RETRUT a RETRUTF a la pagina 3,
	push	hl	;donde estaba la parte residente,
	ld	hl,RETRUT	;y desviamos la ejecucion a RETRUT.
	ld	de,#FBF0
	ld	bc,RETRUTF-RETRUT
	push	hl
	call	#0156
	di
	pop	hl
	ldir
	ld	hl,#FBF0	;... que verguenzaaa ...
	jp	(hl)	;... tener que usar el bufer del teclado!

RETRUT:	ld	a,0	;Reponemos el segmento original de la 
LIBPUT1:	out	(#FD),a	;pagina 1 y seguimos con el programa BASIC. 
	nop
RETRUT2:	ld	h,#40
	ld	a,(#FCC1)
	call	ENASLT
	pop	hl
	jp	NEWSTT
RETRUTF:	; 

NOLIBRES:	call	FREESEG

	ld	hl,UNINSTR	;Copia cadena "Ueeep! etc." en la direccion
	ld	de,OCU_I	;#4100 del SL 0
	ld	bc,UNIF-UNINSTR
	ldir

	ld	hl,#475A	;Inutiliza el USR
	ld	(USRTAB),hl

	jp	TERMOK

ATR_DIR:	dw	0	;v1.01

UNINSTR:	db	"Ueeep, NestorBASIC "
	db	VERP+"0",".",VERS+"0",VERT+"0"
	db	" has been uninstalled !",0
UNIF:	db	0

;--- Programa BASIC ":CLEAR xx,&Hyyyy:?USR(0)"

FINDIR:	dw	0
POINTX2:	dw	0
FINBTXT:	db	":",#92," ",#1C	;"CLEAR "
CLSTRO:	ds	2	;Espacio para cadenas
	db	",",#0C	",&H"
CLDIRO:	ds	2	;Direccion para el CLEAR
	db	":",#91,#DD,"(",#11,")",0	;"PRINTUSR(0)"
FLBALL:	;


;--- NOMBRE: GETINFO
;      Obtiene informacion sobre NestorBASIC
;    ENTRADA:   P(0) = Segmento logico a investigar
;    SALIDA:    P(0) = Numero de segmentos logicos disponibles
;               P(1) = Version principal de NestorBASIC
;               P(2) = Version secundaria de NestorBASIC
;               P(3) = Version principal de MSX-DOS
;               P(4) = Version secundaria de MSX-DOS
;               P(5) = Cantidad de memoria ocupada en la pagina 2
;                      por NestorBASIC
;               P(6) = Tamanio de la VRAM en Kb
;               P(7) = Inicio de la parte libre en el SL 0
;               P(8) = Segmento conectado en la pagina 2
;               P(9) = Numero de ficheros abiertos
;               P(10) = Numero maximo de ficheros abribles
;               P(11) = Slot correspondiente al SL P(5) (#FF: no existe)
;               P(12) = Segmento fisico correspondiente al SL P(5)
;               F$(0) = Unidad+directorio de NBASIC.BIN

GETINFO:	ld	a,(NUMSEGS)
	ld	(iy),a
	xor	a
	ld	(iy+1),a

	ld	(iy+2),VERP
	ld	(iy+4),VERT+16*VERS
	xor	a
	ld	(iy+3),a
	ld	(iy+5),a

	ld	a,(DOSVERP)
	ld	(iy+6),a
	xor	a
	ld	(iy+7),a

	ld	a,(DOSVERS)
	ld	(iy+8),a
	xor	a
	ld	(iy+9),a

	ld	hl,(LONRES)
	ld	(iy+10),l
	ld	(iy+11),h

	ld	a,(VRAMCAPA)
	ld	(iy+12),a
	xor	a
	ld	(iy+13),a

LIBRE:	;ld      hl,OCU_F-#4000-(MAXFIL*TAMFCB)-LONBUF-1264
	;ld      hl,SAVBUF-#4100+LONBUF
	ld	hl,FCBS+(MAXFIL*TAMFCB)
	ld	(iy+14),l
	ld	(iy+15),h

	ld	hl,(FUNCION_ANT)	;@@@
	ld	(iy+16),l	;@@@
	ld	(iy+17),h	;@@@

	;ld	a,(SL_2)
	;ld	(iy+18),a
	;xor	a
	;ld	(iy+19),a

	ld	a,(NUMFILES)
	ld	(iy+18),a	;@@@ era 18
	xor	a
	ld	(iy+19),a	;@@@ era 19, etc

	ld	a,MAXFIL
	ld	(iy+20),a
	xor	a
	ld	(iy+21),a

	ld	hl,(USRTAB)	;Copia del path de NBASIC a F$(0)
	ld	de,NBSTR-RES_I
	add	hl,de
	ld	de,(F0BUFD)
	push	de
	ld	bc,80
	ldir

	pop	hl	;Borramos la parte del nombre de
BUSNBPF:	ld	a,(hl)	;fichero
	or	a
	inc	hl
	jr	nz,BUSNBPF
	ld	bc,-11
	add	hl,bc
	ld	(hl),0
	call	SETF0

	ld	a,(ix)
	call	GET_SF
	ld	(iy+22),b
	ld	(iy+24),a
	xor	a
	ld	(iy+23),a
	ld	(iy+25),a

	ld	a,b
	inc	a
	jp	z,TERMERR	;Error si el SL no existe
	jp	TERMOK


;--- NOMBRE: READSL
;      Lee uno o dos bytes de un segmento logico
;    ENTRADA:   P(0) = Segmento logico
;               P(1) = Direccion
;    SALIDA:    P(2) = Dato
;               USR  =  0: OK
;                      -1: No existe ese segmento logico
;               Lectura de un byte si B=0 a la entrada, si no, lectura de dos
;               Incremento automatico de P(1) si C=1 a la entrada

RD1SLNI:	ld	bc,#0000
	jr	READSL
RD1SLI:	ld	bc,#0001
	jr	READSL
RD2SLNI:	ld	bc,#0100
	jr	READSL
RD2SLI:	ld	bc,#0101

READSL:	ld	a,(ix)
	ld	l,(ix+2)
	ld	h,(ix+3)
	cp	#FF	;Si es #FF, lectura directa
	ld	a,(hl)
	jr	z,RD1SLDIR
	ld	a,(ix)
	call	CHKSLV	;Es VRAM? 
	jr	c,READSLV
	call	CHKSLE	;Existe el segmento?
	jp	nc,TERMERR

	call	READ_SL
RD1SLDIR:	ld	(iy+4),a	;Lectura del primer byte

	ld	a,b
	or	a
	jr	z,RD1SL
RD2SL:	inc	hl	;Lectura del segundo byte o no
	ld	a,(ix)
	cp	#FF	;Si es el SL #FF, lectura directa
	ld	a,(hl)
	jr	z,OKRDSL1
	ld	a,(ix)
	call	READ_SL	;en funcion de B
	jr	OKRDSL1
RD1SL:	xor	a
OKRDSL1:	ld	(iy+5),a

	ld	a,c
	or	a
	jr	z,RDSLNI
RDSLI:	inc	hl	;Incremento de P(1) o no
	ld	(iy+2),l	;En funcion de C
	ld	(iy+3),h
RDSLNI:	;

	call	CHKFF01	;Adaptacion de la direccion a la P. 0
	jp	TERMOK	;Terminacion sin error

READSLV:	ex	af,af	;Lectura de VRAM
	ld	a,(ix)
	push	af	;Guardamos SL y lo sustituimos
	ex	af,af	;por bloque VRAM
	call	READVEXT
	pop	af
	ld	(iy),a	;Recuperamos numero de SL

	ld	a,(iy+3)
	and	%00111111
	ld	(iy+3),a	;Adaptamos direccion de destino a 0-#3FFF

	ret


;--- NOMBRE: WRITESL
;      Escribe uno o dos bytes en un segmento logico
;    ENTRADA:   P(0) = Segmento logico
;               P(1) = Direccion
;               P(2) = Dato
;    SALIDA:    USR  =  0: OK
;                      -1: No existe ese segmento logico
;               Escritura de un byte si B=0 a la entrada, si no, escr. de dos
;               Incremento automatico de P(1) si C=1 a la entrada

WR1SLNI:	ld	bc,#0000
	jr	WRITESL
WR1SLI:	ld	bc,#0001
	jr	WRITESL
WR2SLNI:	ld	bc,#0100
	jr	WRITESL
WR2SLI:	ld	bc,#0101

WRITESL:	ld	a,(ix)
	ld	l,(ix+2)
	ld	h,(ix+3)
	ld	e,(ix+4)
	cp	#FF
	jr	nz,NOWSLDIR	;Si el SL es #FF, escritura directa
	ld	(hl),e
	jr	WSLDIR
NOWSLDIR:	call	CHKSLV
	jr	c,WRITESLV
	call	CHKSLE
	jp	nc,TERMERR

	call	WRITE_SL	;Escritura del primer byte

WSLDIR:	ld	a,b
	or	a
	jr	z,WR1SL
WR2SL:	inc	hl	;Escritura del segundo byte o no
	ld	e,(ix+5)	;en funcion de B
	ld	a,(ix)
	cp	#FF
	jr	nz,W2NODIR
	ld	(hl),e
W2NODIR:	ld	a,(ix)
	call	WRITE_SL
WR1SL:	;

	ld	a,c
	or	a
	jr	z,WRSLNI
WRSLI:	inc	hl	;Incremento de P(1) o no
	ld	(iy+2),l	;en funcion de C 
	ld	(iy+3),h
WRSLNI:	;

	call	CHKFF01
	jp	TERMOK	;Terminacion sin error

WRITESLV:	ex	af,af	;Lectura de VRAM
	ld	a,(ix)
	push	af	;Guardamos SL y lo sustituimos 
	ex	af,af	;por bloque VRAM 
	call	WRITVEXT
	pop	af
	ld	(iy),a	;Recuperamos numero de SL 

	res	7,(iy+3)
	res	6,(ix+3)
	;                        ;Adaptamos direccion de destino a 0-#3FFF

	ret


;--- NOMBRE: LDIRSL
;      Intercambio de un bloque de datos entre dos segmentos logicos
;    ENTRADA:  P(0) = SL origen
;              P(1) = Direccion origen
;              P(2) = SL destino
;              P(3) = Direccion destino
;              P(4) = Longitud de la transferencia
;              P(5) = Incrementar P(1) si <>0
;              P(6) = Incrementar P(3) si <>0
;    SALIDA:   USR =  0: Transferencia realizada
;                    -1: Uno de los SL no existe

LDIRSL:	ld	a,(ix)	;IYh:HL = Dir. origen
	ld	l,(ix+2)
	ld	h,(ix+3)
	ld	iyh,a

	ld	a,(ix+4)	;IYl:DE = Dir. destino
	ld	e,(ix+6)
	ld	d,(ix+7)
	ld	iyl,a

	call	LDIRSL2
	jp	nz,TERMERR
	jp	TERMOK

LDIRSL2:	ld	c,(ix+8)
	ld	b,(ix+9)

	push	iy
	pop	ix
	push	hl,de,bc
	call	LDIRSS	;Transferencia
	pop	bc,de,hl

	or	a	;Retorno con error si A<>0
	ret	nz	;jp      nz,TERMERR

	ld	ix,PARAM
	ld	iy,(DIRP)

CHKINCF:	ld	a,(ix+10)	;Incrementar fuente?
	or	(ix+11)
	jr	z,CHKINCD

INCF:	add	hl,bc
	ld	(iy+2),l
	ld	(iy+3),h

CHKINCD:	ld	a,(ix+12)	;Incrementar destino?
	or	(ix+13)
	jp	z,FINLDSS

INCD:	ex	de,hl
	add	hl,bc
	ld	(iy+6),l
	ld	(iy+7),h

FINLDSS:	call	CHKFF01	;Adaptamos las direcciones a la p. 0
	call	CHKFF23
	xor	a
	ret		;jp      TERMOK


;--- NOMBRE: FILLSL
;      Llenado de una zona de memoria con un dato
;    ENTRADA:  P(0) = Segmento logico
;              P(1) = Direccion inicial
;              P(2) = Dato
;              P(3) = Longitud
;    SALIDA:   USR =  0: Transferencia realizada
;                    -1: Uno de los SL no existe
;              Incremento de P(1) si B<>0

FILLSLNI:	ld	b,0
	jr	FILLSL
FILLSLI:	ld	b,#FF

FILLSL:	ld	a,(ix)
	ld	l,(ix+2)
	ld	h,(ix+3)

	call	CHKSLV
	jr	c,FILLSLV
	call	CHKSLFF
	call	CHKSLE	;HL = Direccion inicial
	call	DIRTOP2
	jp	nc,TERMERR

	ld	c,a
	ld	a,(SL_2)
	push	bc,af
	ld	a,c
	push	hl
	call	PUT_SL2	;Conectamos SL
	pop	hl

	ld	e,l
	ld	d,h
	inc	de	;DE = HL + 1
	ex	de,hl
	call	DIRTOP2
	ex	de,hl
	ld	c,(ix+6)
	ld	b,(ix+7)	;BC = Longitud transferencia

	ld	a,b	;Comprobamos si BC=0 o 1
	or	a
	jr	nz,OKFSL
	ld	a,c
	or	a
	jr	z,RFSL	;No hace nada si P(3)=0
	cp	1
	jr	nz,OKFSL
	ld	a,(ix+4)	;Tranferencia de un solo dato
	ld	(hl),a
	jr	RFSL

OKFSL:	dec	bc	;BC = Longitud-1 para el LDIR
	ld	a,(ix+4)
	ld	(hl),a
	ldir		;Transferencia

RFSL:	pop	af
	push	de
	call	PUT_SL2	;Restauramos SL original
	pop	de

	pop	bc
	ld	a,b
	or	a
	jr	z,FSLNI
FSLI:	ld	a,d
	and	%00111111
	ld	(iy+2),e
	ld	(iy+3),a

FSLNI:	call	CHKFF01	;Adaptamos las direcciones a la p. 0
	jp	TERMOK

FILLSLV:	call	FILLVEXT
	ld	a,(ix)
	ld	(iy),a
	res	7,(iy+3)
	res	6,(iy+3)
	jp	TERMOK


;--- NOMBRE: READV
;      Lee uno o dos bytes de la VRAM
;    ENTRADA:   P(0) = Bloque VRAM (0: 64K inf., 1: 64K sup.)
;               P(1) = Direccion
;    SALIDA:    P(2) = Dato
;               USR  = 0
;               Lectura de un byte si B=0 a la entrada, si no, lectura de dos
;               Incremento automatico de P(1) si C=1 a la entrada

RD1VNI:	ld	bc,#0000
	jr	READV
RD1VI:	ld	bc,#0001
	jr	READV
RD2VNI:	ld	bc,#0100
	jr	READV
RD2VI:	ld	bc,#0101

READV:	ld	a,(ix)
	call	CHKBV
	jp	c,TERMERR
	ld	l,(ix+2)
	ld	h,(ix+3)
	or	(ix+1)
	jr	z,$+4	;Cy = Bloque
	ld	a,1
	;                        ;HL = Direccion

;--- Punto de llamada de la rutina con A:HL = direccion VRAM

READVEXT:	push	bc

	srl	a
	di
	call	SET_RD
	in	a,(#98)
	ei
	ld	(iy+4),a	;Lectura del primer byte
	ld	bc,1
	call	INCDIRV

	pop	bc
	push	bc
	ld	a,b
	or	a
	jr	z,RD1V
RD2V:	ld	hl,(PVRAM)	;Lectura del segundo byte o no
	ld	a,(PVRAM+2)
	rra
	di
	call	SET_RD
	ld	bc,1
	call	INCDIRV
	in	a,(#98)
	ei
	jr	OKRDV1
RD1V:	xor	a
OKRDV1:	ld	(iy+5),a

	pop	bc
	ld	a,c
	or	a
	jr	z,RDVNI
RDVI:	ld	hl,(PVRAM)	;Incremento de P(1) o no
	ld	a,(PVRAM+2)
	;nd     1
	ld	(iy+2),l	;en funcion de C 
	ld	(iy+3),h
	ld	(iy),a
RDVNI:	;

	jp	TERMOK	;Terminacion sin error


;--- NOMBRE: WRITEV
;      Escribe uno o dos bytes en VRAM
;    ENTRADA:   P(0) = Bloque VRAM (0: 64K inf., 1: 64K sup.)
;               P(1) = Direccion
;    SALIDA:    P(2) = Dato
;               USR  = 0
;               Escritura de un byte si B=0 a la entrada, si no, escr. de do
;               Incremento automatico de P(1) si C=1 a la entrada

WR1VNI:	ld	bc,#0000
	jr	WRITEV
WR1VI:	ld	bc,#0001
	jr	WRITEV
WR2VNI:	ld	bc,#0100
	jr	WRITEV
WR2VI:	ld	bc,#0101

WRITEV:	ld	a,(ix)
	call	CHKBV
	jp	c,TERMERR
	ld	l,(ix+2)
	ld	h,(ix+3)
	or	(ix+1)
	jr	z,$+4	;Cy = Bloque
	ld	a,1
	;                        ;HL = Direccion

;--- Punto de llamada de la rutina con A:HL = direccion VRAM

WRITVEXT:	push	bc
	srl	a
	di
	call	SET_WR
	ld	bc,1
	call	INCDIRV

	ld	a,(ix+4)	;Escritura del primer byte
	out	(#98),a
	ei

	pop	bc
	push	bc
	ld	a,b
	or	a
	jr	z,WR1V
WR2V:	ld	hl,(PVRAM)	;Escritura del segundo byte o no
	ld	a,(PVRAM+2)	;en funcion de B
	rra
	di
	call	SET_WR
	ld	bc,1
	call	INCDIRV
	ld	a,(ix+5)	;en funcion de B
	out	(#98),a
	ei
WR1V:	;

	pop	bc
	ld	a,c
	or	a
	jr	z,WRVNI
WRVI:	ld	hl,(PVRAM)	;Incremento de P(1) o no
	ld	a,(PVRAM+2)
	;nd     1
	ld	(iy+2),l	;en funcion de C  
	ld	(iy+3),h
	ld	(iy),a
WRVNI:	;

	jp	TERMOK	;Terminacion sin error


;--- NOMBRE: LDIRSV, LDIRVS y LDIRV
;      Copia de un bloque entre VRAM y un SL
;    ENTRADA:  P(0) = Segmento logico origen
;    (S->V)    P(1) = Direccion RAM origen
;              P(2) = Bloque VRAM destino
;              P(3) = Direccion VRAM destino
;              P(4) = Longitud de la transferencia
;              P(5) = Actualizar P(1) si <>0
;              P(6) = Actualizar P(3) si <>0
;    ENTRADA:  P(0) = Bloque VRAM origen
;    (V->S)    P(1) = Direccion inicial VRAM
;              P(2) = Segmento logico destino
;              P(3) = Direccion RAM destino
;              P(4) a P(6) como en SV
;     ENTRADA: P(0) = Bloque VRAM origen
;     (V->V)   P(1) = Direccion inicial VRAM
;              P(2) = Bloque VRAM destino
;              P(3) = Direccion destino VRAM
;              P(4) a P(6) como en SV
;    SALIDA:   USR =  0: Transferencia realizada
;                    -1: El SL o la dir. VRAM no existe
;              Transferencia VRAM  -> RAM si A=1 (%01)  \
;              Transferencia RAM  -> VRAM si A=2 (%10)   -> %DO (1:VRAM, 0:RAM)
;              Transferencia VRAM -> VRAM si A=3 (%11)  /

LDIRVS:	ld	a,1
	jr	LDIRVSSV
LDIRSV:	ld	a,2
	jr	LDIRVSSV
LDIRV:	ld	a,3

LDIRVSSV:	ld	(TIPOLD),a
	ld	a,(ix)	;IYh:HL = Origen VRAM o RAM
	ld	iyh,a
	ld	l,(ix+2)
	ld	h,(ix+3)

	ld	a,(ix+4)	;IYl:HL = Destino VRAM o RAM
	ld	iyl,a
	ld	e,(ix+6)
	ld	d,(ix+7)

	ld	c,(ix+8)	;BC = Longitud
	ld	b,(ix+9)

	ld	a,(TIPOLD)
	cp	3
	call	z,MAXBC
NOMAX:	;

CHKOV:	bit	0,a	;Si el origen es VRAM,
	jr	z,CHKDV	;transformamos dir. en SL
	ld	a,iyh
	call	VTOSL
	jp	c,TERMERR	;Error si no existe esa dir. VRAM
	ld	iyh,a
	ld	a,(TIPOLD)

CHKDV:	bit	1,a	;Idem con el destino
	jr	z,OKCHKDV
	ld	a,iyl
	ex	de,hl
	call	VTOSL
	ex	de,hl
	jp	c,TERMERR	;Error si no existe esa dir. VRAM
	ld	iyl,a
OKCHKDV:	;

	push	iy
	pop	ix
	push	hl,de,bc
	call	LDIRSS	;Transferencia
	pop	bc,de,hl
	or	a
	jp	nz,TERMERR

	ld	ix,PARAM
	ld	a,(ix)
	ld	iyh,a
	ld	a,(ix+4)
	ld	iyl,a
	ld	h,(ix+3)	;Por si han sido convertidas
	ld	d,(ix+7)
	push	iy
	ld	iy,(DIRP)

CHINCF:	ld	a,(ix+10)	;Incrementar fuente?
	or	(ix+11)
	jr	z,CHINCD

	ld	a,(TIPOLD)
	bit	0,a
	jr	z,INCFR

INCFV:	;ush    af               ;Incremento de la dir. fuente si es VRAM
	ex	(sp),ix
	ld	a,ixh
	ld	(PVRAM),hl
	ld	(PVRAM+2),a
	call	INCDIRV
	ld	hl,(PVRAM)
	ld	a,(PVRAM+2)
	ex	(sp),ix
	ld	(iy),a
	xor	a
	ld	(iy+1),a
	ld	(iy+2),l
	ld	(iy+3),h
	jr	OKINCF

INCFR:	;ush    af               ;Incremento de la dir. fuente si es RAM
	add	hl,bc
	ld	(iy+2),l
	ld	(iy+3),h
OKINCF:	;

CHINCD:	ld	a,(ix+12)	;Incrementar destino?
	or	(ix+13)
	jr	z,OKINCD

	ld	a,(TIPOLD)
	bit	1,a
	jr	z,INCDR

INCDV:	ex	(sp),ix	;Incremento de la dir. destino si es VRAM
	ld	a,ixl
	ld	(PVRAM),de
	ld	(PVRAM+2),a
	call	INCDIRV
	ld	de,(PVRAM)
	ld	a,(PVRAM+2)
	ex	(sp),ix
	ld	(iy+4),a
	xor	a
	ld	(iy+5),a
	ld	(iy+6),e
	ld	(iy+7),d
	jr	OKINCD

INCDR:	ex	de,hl	;Incremento de la dir. destino si es RAM
	add	hl,bc
	ld	(iy+6),l
	ld	(iy+7),h
OKINCD:	;

	ld	a,(TIPOLD)
	bit	0,a
	call	z,CHKFF01
	bit	1,a
	call	z,CHKFF23

	pop	ix
	jp	TERMOK

TIPOLD:	db	0


;--- NOMBRE: FILLV
;      Llenado de una zona de VRAM con un dato
;    ENTRADA:  P(0) = Bloque inicial
;              P(1) = Direccion inicial
;              P(2) = Dato
;              P(3) = Longitud (maximo 16K)
;    SALIDA:   USR  = 0
;              Incremento de P(1) si B<>0

FILLVI:	ld	b,#FF
	jr	FILLV
FILLVNI:	ld	b,0

FILLV:	ld	a,(ix)
	call	CHKBV
	jp	c,TERMERR
	ld	l,(ix+2)
	ld	h,(ix+3)	;A:HL = Direccion inicial

;--- Punto de llamada con A:HL = Dir. inicial y B establecido

FILLVEXT:	push	bc
	rra
	call	SET_WR
	ld	c,(ix+6)
	ld	b,(ix+7)
	ld	a,(ix+4)
	call	FILLVR

	pop	de	;Actualizacion o no de P(0) y P(1)
	bit	0,d
	jp	z,TERMOK
	call	INCDIRV
	ld	hl,(PVRAM)
	ld	a,(PVRAM+2)
	ld	(iy),a
	xor	a
	ld	(iy+1),a
	ld	(iy+2),l
	ld	(iy+3),h

	jp	TERMOK


;--- NOMBRE: DIRO
;      Busqueda de un fichero
;    ENTRADA:  P(0)  = 0 -> Buscar primero
;                      1 -> Buscar siguientes
;              P(1)  = Atributos de busqueda: 2*H + 4*S + 8*V + 16*D
;                      H = 1 -> Incluir archivos ocultos en la busqueda
;                      S = 1 -> Incluir archivos de sistema en busqueda
;                      D = 1 -> Incluir subdirectorios en busqueda
;                      V = 1 -> Buscar solo etiqueta de volumen del disco
;              F$(1) = Ruta y mascara de busqueda
;                      (necesario solo para la primera busqueda)
;    SALIDA:   F$(0) = Nombre del fichero encontrado
;                      Cadena vacia ("") si no se ha encontrado ninguno
;                      o ha habido error
;    SALIDA:   P(0)  = 1 (no cambia si hay error)
;              P(1)  = Atributos del fichero encontrado:
;                      R + 2*H + 4*S + 8*V + 16*D + 32*A
;              P(2)  = Hora de modificacion (0 a 23)
;              P(3)  = Minuto de modificacion (0 a 59)
;              P(4)  = Dia de modificacion (1 a 31)
;              P(5)  = Mes de modificacion (1 a 12)
;              P(6)  = Anio de modificacion (1980 a 2079)
;              P(7)  = Cluster inicial
;              P(8)  = Unidad logica
;              P(9)  = Longitud (parte baja) \  Longitud =
;              P(10) = Longitud (parte alta) /  P(10) + 65536 * P(11) bytes
;              P(11) = Ficheros encontrados hasta ese momento
;                      (se pone a 0 o a 1 en la primera busqueda)
;              USR   = Error (0 si no hay)

DIRO:	ld	a,(SL_2)
	push	af
	call	GETF01
	ld	a,SEG_BUF	;Bufer en pagina 2
	call	PUT_SL2	;*** Era 2

	ld	a,(ix)
	or	(ix+1)
	jr	z,DIRPRIM

DIRSIG:	ld	hl,SAVBUF	;Reposicion del bufer generico
	ld	de,BUFER	;si no es la primera busqueda
	ld	bc,LONBUF
	ldir
	ld	a,1
	ld	(PRIMONO),a
	jr	DIRGEN

DIRPRIM:	xor	a
	ld	(PRIMONO),a

DIRGEN:	push	af
	ld	de,(F1BUFD)	;DE = Ruta + mascara
	ld	hl,(F0BUFD)
	ld	(hl),0	;Inicialmente, F$(0)=""
	ld	b,(ix+2)	;B = Atributos
	pop	af	;A = 0 para buscar primero, 1 siguientes
	ld	ix,BUFER+LONBUF
	call	DIR	;Busqueda!

	or	a
	jp	nz,DIRERR	;Error?

	push	ix
	pop	hl
	ld	de,SAVBUF	;Copia el bufer de datos a SAVBUF
	ld	bc,26
	ldir
	ld	ix,SAVBUF	;IX = Bufer de datos en pag. 1

	pop	af
	call	PUT_SL2	;Restauramos SL original P. 2

	ld	iy,(DIRP)
	xor	a
	ld	(iy+1),a	;P(0) = 1
	ld	a,1
	ld	(iy),a

	push	ix
	pop	hl
	inc	hl	;Establecimiento de F$(0)
	ld	de,(F0BUFD)
	ld	bc,13
	ldir
	call	SETF0

	ld	a,(ix+14)	;P(1) = Atributos
	ld	(iy+2),a
	xor	a
	ld	(iy+3),a

	ld	a,(ix+16)	;P(2) = Hora
	and	%11111000
	srl	a
	srl	a
	srl	a
	ld	(iy+4),a
	xor	a
	ld	(iy+5),a

	ld	a,(ix+16)	;P(3) = Minuto
	and	%00000111
	sla	a
	sla	a
	sla	a
	ld	h,a
	ld	a,(ix+15)
	and	%11100000
	rlc	a
	rlc	a
	rlc	a
	or	h
	ld	(iy+6),a
	xor	a
	ld	(iy+7),a

	ld	a,(ix+17)	;La fecha a cero si no es correcta
	and	%00011111
	ld	(iy+8),a
	ld	(iy+9),a
	ld	(iy+10),a
	ld	(iy+11),a
	ld	(iy+12),a
	ld	(iy+13),a
	jr	z,OKFECHA	;P(4) = Dia
	xor	a
	ld	(iy+9),a

	ld	a,(ix+18)	;P(5) = Mes
	and	1
	srl	a
	ld	a,(ix+17)
	rr	a
	and	%11110000
	srl	a
	srl	a
	srl	a
	srl	a
	ld	(iy+10),a
	xor	a
	ld	(iy+11),a

	ld	a,(ix+18)	;P(6) = Anio
	and	%11111110
	srl	a
	ld	hl,1980
	ld	c,a
	ld	b,0
	add	hl,bc
	ld	(iy+12),l
	ld	(iy+13),h
OKFECHA:	;

	ld	a,(ix+19)	;P(7) = Cluster inicial
	ld	(iy+14),a
	ld	a,(ix+20)
	ld	(iy+15),a

	ld	a,(ix+25)	;P(8) = Unidad logica
	ld	(iy+16),a
	xor	a
	ld	(iy+17),a

	push	ix	;P(9) y P(10) = Longitud
	pop	de
	push	iy
	pop	hl
	ld	bc,18
	add	hl,bc
	ex	de,hl
	add	hl,bc
	inc	hl
	inc	hl
	inc	hl
	ld	bc,4
	ldir

	;ld      a,(ix+21)
	;ld      (iy+18),a
	;ld      a,(ix+22)
	;ld      (iy+19),a
	;ld      a,(ix+23)
	;ld      (iy+20),a
	;ld      a,(ix+24)
	;ld      (iy+21),a

	ld	a,(PRIMONO)
	or	a
	ld	hl,0
	jr	z,ESPRIM
	ld	l,(iy+22)	;P(11) = P(11) + 1
	ld	h,(iy+23)
ESPRIM:	inc	hl
	ld	(iy+22),l
	ld	(iy+23),h

	ld	a,(SL_2)	;Copia del bufer generico a SAVBUF
	push	af	;para usarlo en posteriores busquedas
	ld	a,SEG_BUF	;*** Era 2
	call	PUT_SL2
	ld	hl,BUFER
	ld	de,SAVBUF
	ld	bc,LONBUF
	ldir
	pop	af
	call	PUT_SL2

	jp	TERMOK

DIRERR:	ld	l,a	;Terminacion con error
	ld	h,0
	pop	af
	push	hl
	call	PUT_SL2
	;call	SETF0
	;pop	hl
	;ret

	LD	A,(PRIMONO)	;@@@
	OR	A	;@@@
	JR	NZ,J6C0A	;@@@
	XOR	A	;@@@
	LD	(IY+#16),A	;@@@
	LD	(IY+#17),A	;@@@
J6C0A:	CALL	SETF0	;@@@
	POP	HL	;@@@
	LD	A,L	;@@@
	JP	TERMHL	;@@@

PRIMONO:	db	0


;--- NOMBRE: RENO
;      Renombra un fichero.
;      En DOS 1, se pueden renombrar varios a la vez.
;    ENTRADA:  F$(0) = Nombre antiguo
;              F$(1) = Nombre nuevo
;    SALIDA:   USR   = Error (0 si no hay)

RENO:	ld	a,(SL_2)
	push	af
	call	GETF01
	ld	a,SEG_BUF	;*** Era 2
	call	PUT_SL2	;Conectamos bufer

	ld	de,(F0BUFD)
	ld	hl,(F1BUFD)
	call	REN

REPON:	ld	l,a
	ld	h,0	;Reponemos segmento original pag. 2
	pop	af
	push	hl
	call	PUT_SL2
	pop	hl
	ret


;--- NOMBRE: MOVEO
;      Mueve un fichero.
;      Disponible solo en DOS 1
;    ENTRADA:  F$(0) = Fichero
;              F$(1) = Nueva ruta
;    SALIDA:   USR   = Error (0: no hay error, 1: es DOS 1)

MOVEO:	ld	a,(DOSVERP)
	ld	l,a
	ld	h,0
	dec	a
	ret	z

	call	GETF01
	ld	de,(F0BUFD)
	ld	hl,(F1BUFD)

	ld	c,_MOVE
	call	DOSCALL

	jp	TERMHL


;--- NOMBRE: DELO
;      Borra un fichero.
;      En DOS 1, se pueden borrar varios a la vez.
;    ENTRADA:  F$(0) = Fichero a borrar
;    SALIDA:   USR   = Error (0 si no hay)

DELO:	ld	a,(SL_2)
	push	af
	call	GETF01
	ld	a,SEG_BUF	;*** Era 2
	call	PUT_SL2	;Conectamos bufer 

	ld	de,(F0BUFD)
	call	DEL

	jp	REPON


;--- NOMBRE: CREATEO
;      Crea un fichero pero NO lo deja abierto
;    ENTRADA:  F$(0) = Nombre del fichero
;              P(0)  = Atributos
;    SALIDA:   USR   = Error (0: no hay error)

CREATEO:	ld	a,(SL_2)
	push	af
	call	GETF01
	ld	a,SEG_BUF	;*** Era 2
	call	PUT_SL2	;Conectamos bufer  

	ld	b,(ix)	;Atributos
	ld	de,(F0BUFD)
	call	CREATE

	jp	REPON


;--- NOMBRE: OPENO
;      Abre un fichero
;    ENTRADA:  F$(0) = Nombre del fichero
;    SALIDA:   P(0)  = Numero asociado al fichero
;              USR   = Error (0: no hay, 4: demasiados ficheros abiertos)

OPENO:	call	GETF01
	ld	de,(F0BUFD)
	call	OPEN
	or	a
	jp	nz,TERMHL
	ld	(iy),b
	xor	a
	ld	(iy+1),a
	jp	TERMOK


;--- NOMBRE: CLOSEO
;      Cierra un fichero
;    ENTRADA:  P(0) = Numero de fichero
;    SALIDA:   USR  = Error (3: num. invalido, 2: no esta abierto)

CLOSEO:	ld	a,(DOSVERP)
	dec	a
	jr	z,CLOSO2
	ld	b,(ix)
	ld	c,_ENSURE
	call	DOSCALL
	or	a
	jp	nz,TERMHL

CLOSO2:	ld	b,(ix)
	call	CLOSE
	jp	TERMHL


;--- NOMBRE: READO, READV, RDSEC, RDSECV, WRITEO, WRITEOV, WRSEC, WRSECV
;      Lee/escribe de un fichero/de sectores a un segmento/a VRAM
;    ENTRADA:  P(0) = Fichero/Unidad
;              P(1) = Sector inicial
;              P(2) = Segmento/Bloque VRAM fuente/destino
;              P(3) = Direccion fuente/destino
;              P(4) = Longitud (maximo #4000)/No. de sectores (max. 32)
;              P(5) = Incremento de P(1) si <>0 (sectores)
;              P(6) = Incremento de P(3) si <>0
;    SALIDA:   P(7) = Num. de bytes que se han podido leer/escribir (fichero)
;              USR  = Error:
;                    -1 -> SL/Bloque VRAM inexistente
;                     2 -> Fichero no abierto
;                     3 -> Num. de fichero incorrecto -> NO

READO:	ld	a,%000	;Lectura de fichero a SL
	jr	READD

READOV:	ld	a,%010	;Lectura de fichero a VRAM
	jr	READDV

RDSEC:	ld	a,%100	;Lectura de sectores a RAM
	jr	READD

RDSECV:	ld	a,%110	;Lectura de sectores a VRAM
	jr	READDV

WRITEO:	ld	a,%001	;Escritura de un SL a un fichero
	jr	READD

WRITEOV:	ld	a,%011	;Escritura de VRAM a un fichero
	jr	READDV

WRSEC:	ld	a,%101	;Escritura de un SL a sectores
	jr	READD

WRSECV:	ld	a,%111	;Escritura de VRAM a sectores
	jr	READDV

;--- Rutina generica de lectura/escritura de sectores/ficheros en SL/VRAM

READDV:	ld	(TAD),a	;Establecemos Tipo de Acceso a Disco
	ld	a,(ix+4)	;Lectura a VRAM: la convertimos a SL
	ld	l,(ix+6)
	ld	h,(ix+7)
	call	VTOSL
	ld	(ix+6),l
	ld	(ix+7),h
	ld	(RDFSL),a
	jp	c,TERMERR
	jr	READOVR

READD:	ld	(TAD),a
	ld	a,(ix+4)	;Lectura a SL
	ld	(RDFSL),a
	call	CHKSLFF	;Primero comprobamos si existe el SL
	ld	b,a
	push	hl
	call	CHKSLV	;Guardamos A y HL para que no los convierta
	pop	hl	;a bloque y dir. VRAM
	ld	a,b
	jr	c,OKSLRD1
	call	CHKSLE
	jp	nc,TERMERR
OKSLRD1:	;

READOVR:	ld	a,(RDFSL)	;Transferencia de P(3) al SL 2
	ld	iyh,a	;si hay que escribir
	ld	l,(ix+6)
	ld	h,(ix+7)
	ld	a,SEG_BUF	;IYh:HL = Fuente
	ld	iyl,a	;*** Era 2
	ld	c,(ix+8)
	ld	b,(ix+9)
	ld	a,(TAD)
	bit	1,a
	call	nz,MAXBC
	bit	2,a
	call	nz,MAXSEC
	ld	de,#8000	;IYl:DE = Destino
	push	ix,de,bc,iy
	pop	ix
	ld	a,(TAD)
	bit	2,a
	jr	z,NOSTOB
	ld	b,c	;Si son sectores, los pasamos primero
	sla	b	;a bytes
	ld	c,0
NOSTOB:	bit	0,a
	call	nz,LDIRSS

	ld	a,(SL_2)	;Conectamos SL 2
	push	af
	ld	a,SEG_BUF	;*** Era 2
	call	PUT_SL2
	pop	af,hl,de,ix	;Recuperamos HL=longitud y DE=#8000
	push	af

	ld	b,(ix)
	ld	iy,OKAD
	push	iy	;Para que continue tras el JP
	ld	a,(TAD)
	and	%101
	or	a
	jp	z,READ
	cp	%100
	jp	z,RDABS
	cp	%001
	jp	z,WRITE
	jp	WRABS

OKAD:	ld	(LEIDOS),hl	;Acceso a disco realizado
	ld	(ERREAD),a

	pop	af
	push	hl
	call	PUT_SL2	;Restauramos segmento original p. 2
	pop	hl

	ld	a,h
	or	l
	jp	z,FRD1

	push	hl
	pop	bc	;BC = No. de bytes leidos
	ld	a,SEG_BUF	;IYh:HL = Origen para la transferencia
	ld	iyh,a	;SL -> SL
	ld	hl,#8000	;*** Era 2
	ld	a,(RDFSL)	;RDFSL = Segmento
	ld	iyl,a	;IYl:DE = Destino
	ld	e,(ix+6)
	ld	d,(ix+7)

	push	iy
	pop	ix
	push	de,bc
	ld	a,(TAD)
	bit	0,a
	jr	nz,NOLDRF
	ld	a,b
	or	c
	call	nz,LDIRSS	;Transferencia al SL adecuado si se
NOLDRF:	pop	bc,hl	;ha leido y mas de 0 bytes

	ld	iy,(DIRP)
	push	hl,bc
	ld	hl,(LEIDOS)
	ld	(iy+14),l
	ld	(iy+15),h
	pop	bc,hl

	ld	ix,PARAM	;Incremento de P(3)?
	ld	iy,(DIRP)
	ld	a,(ix+12)
	or	(ix+13)
	jr	z,NOIRDO
	ld	a,(TAD)
	bit	1,a
	jr	z,IRFS
IRFV:	ld	a,(RDFSL)
	ld	l,(ix+6)
	ld	h,(ix+7)
	call	CHKSLV	;Volvemos a convertir la direccion a VRAM
	ld	(PVRAM),hl	;para la actualizacion
	ld	(PVRAM+2),a
	call	INCDIRV
	ld	hl,(PVRAM)
	ld	a,(PVRAM+2)
	ld	(iy+4),a
	jr	IRFVS
IRFS:	add	hl,bc	;Incremento de P(3) si es SL
IRFVS:	ld	(iy+6),l
	ld	(iy+7),h
NOIRDO:	ld	a,(TAD)
	bit	1,a
	call	z,CHKFF23	;Adaptamos P(3) a p. 2 si no es VRAM
	ld	a,(TAD)
	bit	2,a
	jr	z,NOISN	;Incremento de P(1) si P(5)<>0
	ld	a,(ix+10)	;y se trata de sectores
	or	(ix+11)
	jr	z,NOISN
	ld	l,(ix+2)
	ld	h,(ix+3)
	ld	c,(ix+8)
	ld	a,(TAD)
	ld	b,0
	call	MAXSEC
	add	hl,bc
	ld	(iy+2),l
	ld	(iy+3),h
NOISN:	ld	a,(ERREAD)
	ld	l,a
	ld	h,0
	ret

FRD1:	ld	a,(ERREAD)
	ld	l,a
	ld	h,0
	push	hl
	ld	hl,(LEIDOS)
	ld	iy,(DIRP)
	ld	(iy+14),l
	ld	(iy+15),h
	pop	hl
	ret

MAXSEC:	bit	1,a	;Limitacion de BC a 32 sectores si es VRAM
	ret	z
	ld	a,c
	cp	32
	ret	c
	ld	bc,32
	ret

LEIDOS:	dw	0
ERREAD:	db	0
RDFSL:	db	0
TAD:	db	0	;Tipo de Acceso a Disco: %DMR
;                                   ; D = 1 si acceso a sectores
;                                   ; M = 1 si acceso a VRAM
;                                   ; R = 1 si escritura


;--- NOMBRE: FILLF
;      Rellena un fichero
;    ENTRADA:  P(0) = No. de fichero
;              P(1) = Dato
;              P(4) = Longitud (max. #4000)
;    SALIDA:   P(7) = P(4)
;              USR  = Error

FILLF:	ld	a,(SL_2)
	push	af
	ld	a,SEG_BUF	;*** Era 2
	call	PUT_SL2

	ld	hl,#8000	;Rellenamos el bufer con BC veces P(1)
	ld	de,#8001
	ld	c,(ix+8)
	ld	b,(ix+9)
	call	MAXBC
	ld	a,b
	or	c
	jr	z,FFILLF
	dec	bc
	ld	a,(ix+2)
	ld	(hl),a
	ld	a,b
	or	c
	jr	z,OKFILLF
	ldir
OKFILLF:	;

	ld	a,2	;P(2) = 2
	ld	(ix+4),a
	xor	a
	ld	(ix+5),a
	ld	de,#8000
	ld	(ix+6),e	;P(3) = #8000
	ld	(ix+7),d
	ld	(ix+12),a	;P(6) = 0
	ld	(ix+13),a
	pop	af
	call	PUT_SL2
	call	WRITEO
	ret

FFILLF:	pop	af
	call	PUT_SL2
	jp	TERMOK


;--- NOMBRE: SEEK
;      Establece el puntero de un fichero
;    ENTRADA:   P(0) = No. de fichero
;               P(1) = Metodo de desplazamiento:
;                      0 -> Relativo al principio del fichero
;                      1 -> Relativo a la posicion actual
;                      2 -> Relativo al final del fichero
;               P(2) = Desplazamiento (bajo)
;               P(3) = Desplazamiento (alto)
;    SALIDA:    USR  = Error
;                     2 -> Fichero no abierto
;                     3 -> Num. de fichero incorrecto
;               P(4) = Nuevo puntero (bajo), si no hay error
;               P(5) = Nuevo puntero (alto), si no hay error

SEEKO:	ld	b,(ix)
	ld	a,(ix+2)
	ld	l,(ix+4)
	ld	h,(ix+5)
	ld	e,(ix+6)
	ld	d,(ix+7)
	call	SEEK
	or	a
	jp	nz,TERMHL
	ld	(iy+8),l
	ld	(iy+9),h
	ld	(iy+10),e
	ld	(iy+11),d
	jp	TERMHL


;--- NOMBRE: GETDRV
;      Obtiene informacion sobre la unidad por defecto
;      y vector de disketeras
;    ENTRADA:  -
;    SALIDA:   P(0) = Unidad actual (0: A, ...)
;              P(1) = Vector de disketeras
;              USR  = 0

GETDRV:	ld	c,_CURDRV
	call	DOSCALL
	ld	(iy),a
	ld	c,_LOGIN
	call	DOSCALL
	ld	(iy+2),l
	xor	a
	ld	(iy+1),a
	ld	(iy+3),a
	jp	TERMOK


;--- NOMBRE: CHDRV
;      Establece una unidad por defecto
;    ENTRADA:  P(0) = Unidad (0=A:, ...)
;    SALIDA:   USR  = Error
;                     62: No existe esa unidad

CHDRV:	ld	a,(ix)
	call	CHKDRVE
	ld	a,62
	jp	c,TERMHL	;Error si la unidad no existe

	ld	e,(ix)	;Si la unidad existe la seleccionamos
	ld	c,_SELDSK
	call	DOSCALL
	xor	a

	jp	TERMHL


;--- NOMBRE: GALLOC
;      Obtiene informacion sobre un disco
;    ENTRADA:   P(0) = Unidad (0=defecto, 1=A:, ...)
;    SALIDA:    P(1) = Sectores por cluster
;               P(2) = No. de clusters totales
;               P(3) = No. de clusters libres
;               USR  = Error (62: no existe la unidad)

GALLOC:	ld	a,(ix)
	dec	a
	cp	#FF
	call	nz,CHKDRVE
	ld	a,62
	jp	c,TERMHL

	ld	e,(ix)
	ld	c,_ALLOC
	call	DOSCALL
	cp	65
	jp	nc,TERMHL

	ld	(iy+2),a
	xor	a
	ld	(iy+3),a
	ld	(iy+4),e
	ld	(iy+5),d
	ld	(iy+6),l
	ld	(iy+7),h

	jp	TERMHL


;--- NOMBRE: GETDIR
;      Obtiene el directorio actual
;    ENTRADA:  P(0)  = Unidad (0=defecto, 1=A:, ...)
;    SALIDA:   F$(0) = Directorio actual
;              USR   = Error

GETDIR:	call	NODOS1

	ld	b,(ix)
	ld	de,(F0BUFD)
	ld	c,_GETCD
	call	DOSCALL

	push	af
	or	a
	call	z,SETF0
	pop	af

	jp	TERMHL


;--- NOMBRE: CHDIR
;      Cambia el directorio por defecto de una unidad
;    ENTRADA:  F$(0) = Unidad + directorio a establecer
;    SALIDA:   USR   = Error

CHDIR:	call	NODOS1

	call	GETF01
	ld	de,(F0BUFD)
	ld	c,_CHDIR
	call	DOSCALL

	jp	TERMHL


;--- NOMBRE: GETRAMD y SETRAMD
;      Obtiene el tamanio del RAM disk/Establece el RAM disk
;    ENTRADA:  P(0) = Tamanio a establecer para SETRAMD en segmentos de 16K
;                     (0 para destruir el RAM disk)
;    SALIDA:   P(0) = Tamanio del RAM disk en segmentos (0: no hay RAM disk)
;              USR  = Error

GETRAMD:	ld	b,#FF
	jr	GSRAMD

SETRAMD:	ld	b,(ix)
	ld	a,b
	cp	#FF
	jr	nz,GSRAMD
	dec	b

GSRAMD:	call	NODOS1

	ld	c,_RAMD
	call	DOSCALL
	push	af

	ld	(iy),b
	xor	a
	ld	(iy+1),a

	pop	af
	jp	TERMHL


;--- NOMBRE: GETATRIB y SETATRIB
;      Obtiene/establece los atributos de un fichero
;    ENTRADA:  P(0) = No. de fichero, o bien
;              P(0) = #FF y F$(0) = Nombre del fichero
;              P(1) = Nuevo byte de atributos
;                     R + 2*H + 4*S + 8*V + 16*D + 32*A
;    SALIDA:   P(1) = Byte de atributos del fichero

GETATRIB:	xor	a
	jr	GSATRIB

SETATRIB:	ld	a,1

GSATRIB:	ld	(GOSAT),a
	call	NODOS1
	call	GETF01
	ld	hl,CONTATR
	push	hl

	ld	de,(F0BUFD)
	ld	l,(ix+2)
	ld	b,(ix)
	ld	a,b
	inc	a
	ld	a,(GOSAT)	;Actuar sobre un fichero abierto
	ld	c,_ATTR	;o sobre un nombre de fichero?
	jp	z,DOSCALL
	ld	c,_HATTR
	jp	DOSCALL

CONTATR:	or	a
	jp	nz,TERMHL
	ld	(iy+2),l
	ld	(iy+3),a
	jp	TERMOK

GOSAT:	db	0


;--- NOMBRE: PARSE
;      Tratamiento de una cadena de ruta + nombre de archivo
;    ENTRADA: F$(0) = Cadena a tratar
;             P(10)<>0 para tratar etiqueta de volumen
;    SALIDA:  P(0) = #FF -> Especificacion de algo que no es la unidad
;             P(1) = #FF -> Especificacion de ruta de acceso
;             P(2) = #FF -> Especificacion de unidad
;             P(3) = #FF -> Especificacion de nombre de fichero
;             P(4) = #FF -> Especificacion de extension
;             P(5) = #FF -> El ultimo elemento es ambiguo
;             P(6) = #FF -> El ultimo elemento es "." o ".."
;             P(7) = #FF -> El ultimo elemento es ".."
;             P(8) = Unidad (1=A:, ...)
;             P(9) = Posicion del ultimo elemento en la cadena (1a = 1)
;             F$(1)= Ultimo elemento

PARSE:	call	NODOS1

	call	GETF01
	ld	de,(F0BUFD)
	ld	a,(ix+20)
	ld	b,%00010000
	or	a
	jr	nz,OKPRS1
	ld	b,0

OKPRS1:	ld	c,_PARSE
	call	DOSCALL
	or	a
	jp	nz,TERMHL

	ld	(iy+16),c	;Establecemos unidad en P(8)
	ld	(iy+17),a

	push	hl,de

	ld	de,(F0BUFD)
	sbc	hl,de
	inc	hl	;HL = Posicion del ultimo elemento
	ld	(iy+18),l	;Establecemosla en P(9)
	ld	(iy+19),h

	ld	c,b	;C = Banderas
	push	iy
	pop	hl
	ld	b,8
BUCPAR:	xor	a
	sra	c	;Bandera al acarreo
	jr	nc,PARS0	;Bandera a 1?
PARS1:	cpl		;Si: ponemos el parametro a -1
PARS0:	ld	(hl),a	;No: ponemos el parametro a  0
	inc	hl
	ld	(hl),a
	inc	hl
	djnz	BUCPAR

	pop	de	;DE = Pos. caracter de terminacion
	pop	hl	;HL = Pos. ultimo elemento
	push	hl
	xor	a
	push	hl
	ld	hl,(F1BUFD)	;Limpiamos F$(1)
	ld	(hl),a
	pop	hl

	or	a
	ex	de,hl
	sbc	hl,de
	ld	a,h
	or	l
	jp	z,FPARNOUL	;Terminamos si no hay ultimo elemento

	push	hl
	pop	bc
	inc	bc	;Para copiar tambien el caracter 0 de fin
	pop	hl
	ld	de,(F1BUFD)
	ldir
FPARSE:	call	SETF1
	jp	TERMOK
FPARNOUL:	xor	a
	ld	(iy+18),a
	ld	(iy+19),a
	pop	hl
	jr	FPARSE	;P(9)=0 si no hay ultimo elemento


;--- NOMBRE: COMPGFX, DESCGFX
;      Compresion/descompresion de un grafico a/de memoria
;      NO soporta el segmento 255 ni los segmentos VRAM
;      Si un segmento no basta, sigue en el siguiente
;    ENTRADA: P(0) = Bloque VRAM inicial
;             P(1) = Dir. VRAM inicial
;             P(2) = Segmento
;             P(3) = Direccion RAM
;             P(4) = Tamanio de la imagen (compresion)
;             P(5) = Actualizar P(1) si <>0
;             P(6) = Actualizar P(3) si <>0
;    SALIDA:  P(7) = Tamanio de la imagen comprimida/descomprimida
;             P(8) = Segmentos utilizados
;             P(0):P(1) = P(0):P(1) + P(4/7) si P(5)<>0
;             P(2):P(3) apunta al ultimo dato de la imagen comprimida si P(6)<>0
;             USR  = -1 -> No existe el segmento o la dir. VRAM
;                     5 -> Segmentos insuficientes
;                     6 -> Dato incorrecto al descomprimir

COMPGFX:	xor	a
	jr	COMPDES

DESCGFX:	ld	a,1

COMPDES:	ld	(COD),a	;COD = 0 para compresion, 1 para desc.
	ld	a,(ix+4)	;Si no existe el segmento, error -1
	call	CHKSLE
	jp	nc,TERMERR

	ld	a,(ix)	;A = bloque VRAM 
	ld	l,(ix+2)	;HL = dir. VRAM 
	ld	h,(ix+3)

	ld	d,a	;v1.01
	push	hl
	call	VTOSL	;Existe la dir. VRAM? 
	pop	hl
	jp	c,TERMERR	;Si no: error -1 

	ld	(SAVSPCD),sp
	ld	a,1	;Para empezar, un segmento utilizado
	ld	(SEGUTL),a

	;ld	a,d	;Establecimiento del VDP para lectura
	ld	bc,CONTCOD	;o escritura en funcion de COD
	push	bc
	ld	a,(COD)
	or	a
	ld	a,d	;v1.01
	rra		;v1.01
	jp	z,SET_RD
	jp	SET_WR

CONTCOD:	ld	a,(SL_2)
	ld	(CD_SL2),a	;Guardamos SL original en P. 2
	ld	a,(ix+4)
	call	PUT_SL2	;y conectamos el SL P(4)

	ld	l,(ix+6)	;HL = P(3) = direccion RAM inicial
	ld	h,(ix+7)
	call	DIRTOP2
	ex	de,hl	;DE = Dir. RAM in. en rango #8000-#BFFF
	ld	c,(ix+8)
	ld	b,(ix+9)	;BC = Longitud 
	push	ix,iy
	ld	ix,CONCOD2
	push	ix
	ld	a,(COD)
	or	a
	jp	z,COMP	;Compresion o descompresion 
	ex	de,hl	;en funcion de COD
	jp	DESC
CONCOD2:	pop	iy,ix

	ld	a,0
	rla
	ex	af,af	;A'= 1 si ha habido error
	ld	sp,(SAVSPCD)
	ld	a,(CD_SL2)
	push	bc,de,hl
	call	PUT_SL2	;Restauracion del SL original en P.
	pop	hl,de,bc

	ex	af,af	;Terminacion con error 5 si no han bastado
	or	a	;los segmentos (compresion),
	jp	z,OKTERCD	;con error 6 si se ha encontrado algun 
	ld	a,(COD)	;dato incorrecto al descomprimir.
	add	5
	jp	TERMHL

OKTERCD:	ld	a,(COD)
	or	a
	jr	nz,CONCOD3	;CDULDIR = Ultima dir. RAM usada:
	ex	de,hl	;          DE para comp., HL para desc.
CONCOD3:	ld	(CDULDIR),hl

	ld	(iy+14),c	;P(7) = Tamanio de la imagen comprimida
	ld	(iy+15),b	;       o descomprimida 

	ld	a,(COD)
	or	a
	jr	z,NOCOMP
	ld	(ix+8),c	;Para que P(1)=P(1)+P(7) si descomprime 
	ld	(ix+9),b	;y P(1)=P(1)+P(4) si comprime 

NOCOMP:	ld	a,(SEGUTL)	;P(8) = Segmentos usados 
	ld	(iy+16),a
	xor	a
	ld	(iy+17),a

CHKI1C:	ld	a,(ix+10)	;Incremento de la dir. VRAM 
	or	(ix+11)
	jr	z,CHKI3C
	ld	c,(ix+8)
	ld	b,(ix+9)
	call	INCDIRV
	ld	hl,(PVRAM)
	ld	a,(PVRAM+2)
	ld	(iy),a
	xor	a
	ld	(iy+1),a
	ld	(iy+2),l
	ld	(iy+3),h

CHKI3C:	ld	a,(ix+12)	;Actualizacion de P(3) 
	or	(ix+13)
	jr	c,FCMPGFX
	ld	hl,(CDULDIR)
	res	7,h	;Ultima dir. usada, de 0 a #3FFF
	res	6,h

	ld	a,(SEGUTL)	;Actualizacion de P(3)
	inc	hl
	bit	6,h	;Si CDULDIR+1=#4000,
	jr	z,OKCD1	;pasamos al siguiente segmento, dir. 0
	ld	hl,0
	inc	a
OKCD1:	ld	(iy+6),l
	ld	(iy+7),h
	ld	b,(ix+4)	;Actualizacion de P(2) 
	add	b
	dec	a
	call	CHKSLE	;Si el siguiente segmento no existe,
	jr	c,OKCD2	;pasamos al 0
	xor	a
OKCD2:	ld	(iy+4),a

FCMPGFX:	jp	TERMOK

;--- Subrutina de incremento de la direccion RAM
;    En caso de error, ha de saltar a FinCErr con Cy = 1

INCIX:	ex	af,af
	inc	ix
	ld	a,ixh
	cp	#C0
	jr	nz,FINCIX
	ex	af,af

	push	af,hl,de,bc
	exx
	push	hl,de,bc
	exx
	ld	a,(SEGUTL)
	inc	a
	ld	(SEGUTL),a
	ld	a,(SL_2)
	inc	a
	call	CHKSLE
	ccf
	jp	c,FinCErr

	call	PUT_SL2
	ld	ix,#8000
	exx
	pop	bc,de,hl
	exx
	pop	bc,de,hl,af
	ex	af,af
FINCIX:	ex	af,af
	ret

SEGUTL:	db	0
COD:	db	0
SAVSPCD:	dw	0
CD_SL2:	db	0
CDULDIR:	dw	0


;--- NOMBRE: BIOSCALL
;      Llamada a una rutina de la BIOS o SUB-BIOS
;    ENTRADA: P(0) = 0 para llamada a la BIOS, <>0 para SUB-BIOS
;             P(1) = Direccion, #FFCA para BIOS extendida
;             P(2) = Registros AF
;                    Banderas: &B SZ-H-PNC
;             P(3) = Registros BC
;             P(4) = Registros DE
;             P(5) = Registros HL
;             P(6) = Registros IX
;             P(7) = Registros IY
;             P(8) = Registros AF'
;             P(9) = Registros BC'
;             P(10) = Registros DE'
;             P(11) = Registros HL'
;    SALIDA:  P(2) a P(11) como la entrada
;             Error -1 si P(1)>=&H4000

BIOSCALL:	ld	l,(ix+2)
	ld	h,(ix+3)
	ld	a,(ix)
	or	(ix+1)
	jr	nz,SUBCALL

	ld	(BIOSCDIR+1),hl	;BIOS normal
	call	P2BUF
	call	VAR2REG
BIOSCDIR:	call	0
	call	REG2VAR
	call	BUF2P
	jp	TERMOK

SUBCALL:	ld	a,h	;Dir.>#3FFF?
	and	%11000000
	jp	nz,TERMERR	;Si no, error

	push	hl	;SUB-BIOS
	call	P2BUF
	call	VAR2REG
	pop	ix
	call	EXTROM
	call	REG2VAR
	call	BUF2P
	jp	TERMOK


;--- NOMBRE: SEGCALL
;      Llamada a una rutina en un segmento
;    ENTRADA: P(0) = Segmento
;             P(1) = Direccion
;             P(2) a P(11) = Registros
;    SALIDA:  P(2) a P(12) = Registros
;             Error -1 si no existe el segmento

SEGCALL:	ld	a,(ix)	;Segmento: existe el segmento?
	call	CHKSLE
	jp	nc,TERMERR	;No: error

	call	P2BUF
	ld	a,(ix)
	call	PUT_SL2	;Conexion del segmento en P. 2
	ld	hl,(BUFNREP+2)
	call	DIRTOP2

	ld	(SEGCDIR+1),hl
	call	VAR2REG
SEGCDIR:	call	0
	call	REG2VAR

	ld	a,2	;(SEGC_SAVP2)
	call	PUT_SL2

	call	BUF2P
	jp	TERMOK


;--- NOMBRE: NMANCALL
;      Llamada a una rutina de NestorMan
;    ENTRADA: P(0) = Funcion
;             P(2) a P(11): Registros
;    SALIDA:  P(2) a P(12): Registros
;             Error -1 si NestorMan no esta instalado

NMANCALL:	ld	a,(NMANS4)
	or	a
	jp	z,TERMERR

	ld	a,(ix)
	ld	(ix+6),a	;C = Funcion

	call	P2BUF
	call	VAR2REG
	call	NESMAN
	call	REG2VAR
	call	BUF2P
	jp	TERMOK


;--- NOMBRE: INSCALL
;      Llamada a una rutina en un segmento de InterNestor Suite
;    ENTRADA: P(0) = Modulo, 1 a 4
;             P(1) = Direccion
;             P(2) a P(11) = Registros
;    SALIDA:  P(2) a P(12) = Registros
;             Error -1 si no existe el modulo o NMAN no instalado

INSCALL:	ld	a,(NMANS4)
	or	a
	jp	z,TERMERR
	ld	a,(INS_SL1)
	or	a
	jp	z,TERMERR	;No hay NMAN o INS: Error

	ld	a,(ix+1)	;El modulo no esta
	or	a	;entre 1 y 4: error
	jp	nz,TERMERR
	ld	a,(ix)
	cp	1
	jp	c,TERMERR
	cp	5
	jp	nc,TERMERR

	push	af
	call	P2BUF

	ld	a,(#F343)	;Pone slot de INS
	ld	b,a	;si no es el mismo de TPA
	ld	a,(INS_SLOT)
	cp	b
	ld	h,#80
	call	ENASLT

	pop	af
	ld	hl,INS_SF1-1
	ld	c,a
	ld	b,0
	add	hl,bc	;Conexion del segmento
	ld	a,(hl)	;del modulo en pag. 2
	call	PUT_P2

	ld	hl,(BUFNREP+2)
	call	DIRTOP2

	ld	(INSCDIR+1),hl
	call	VAR2REG	;Coge los registros de BUFNREP
INSCDIR:	call	0
	call	REG2VAR	;Pasa registros a BUFNREP

	ld	a,(INS_SLOT)	;Pone slot de TPA
	ld	b,a	;si no es el mismo de INS
	ld	a,(#F343)
	cp	b
	ld	h,#80
	call	ENASLT

	ld	a,(TABSEGS+5)	;Restaura TPA en pag. 2
	call	PUT_P2

	call	BUF2P
	jp	TERMOK

	;--- P2BUF: Pasa la matriz P (apuntada por IX) a BUFNREP

P2BUF:	push	ix	;Preparamos para el VAR2REG
	pop	hl
	ld	de,BUFNREP
	ld	bc,16*2
	ldir
	ret

	;--- BUF2P: Pasa BUFNREP a la matriz P

BUF2P:	ld	hl,BUFNREP
	ld	de,(DIRP)
	ld	bc,16*2
	ldir
	ret

	;--- VAR2REG: Pasa las variables P(2)-P(11) a los registros
	;             Antes se han tenido que copiar las variables
	;             a BUFNREP

VAR2REG:	ld	a,4
	ld	b,10
	ld	ix,BUFNREP
BUCGREG:	ld	(RXGREG1+2),a	;Este bucle mete en la pila
	inc	a	;las entradas para:
	ld	(RXGREG2+2),a	;AF, BC, DE, HL, IX, IY, AF', BC', DE', HL'
	inc	a
RXGREG1:	ld	l,(ix+0)
RXGREG2:	ld	h,(ix+0)
	push	hl
	djnz	BUCGREG

	exx
	ex	af,af
	pop	hl,de,bc,af

	exx
	ex	af,af
	pop	iy,ix,hl,de,bc,af

	ret

	;--- REG2VAR: Pasa los registros a las variables P(2)-P(12)
	;             En realidad los pasa a BUFNREP, despues
	;             hay que copiarlos a las variables (DIRP)

REG2VAR:	push	hl,de,bc,af	;Guardamos temporalmente los registros
	ld	a,iyl
	ld	(BSGTMPY),a
	ld	a,iyh
	ld	(BSGTMPY+1),a

	ld	iy,BUFNREP
	;ld      iy,(DIRP)        ;IY = Direccion de la matriz P

	pop	bc	;BC = AF devuelto
	ld	(iy+4),c	;Establecemos P(2) a P(11)
	ld	(iy+5),b
	ld	(iy+24),b	;P(12)
	ld	(iy+25),0
	push	bc
	pop	af
	ld	a,-1
	jr	c,CARRYSET
	ld	a,0
CARRYSET:	ld	(iy+26),a	;P(13)
	ld	(iy+27),a
	ld	a,-1
	jr	z,ZEROSET
	ld	a,0
ZEROSET:	ld	(iy+28),a	;P(14)
	ld	(iy+29),a
	pop	bc,de,hl
	ld	(iy+6),c
	ld	(iy+7),b
	ld	(iy+8),e
	ld	(iy+9),d
	ld	(iy+10),l
	ld	(iy+11),h
	ld	a,ixl
	ld	(iy+12),a
	ld	a,ixh
	ld	(iy+13),a
	ld	a,(BSGTMPY)
	ld	(iy+14),a
	ld	a,(BSGTMPY+1)
	ld	(iy+15),a
	ex	af,af
	push	af
	pop	bc	;BC = AF' devuelto
	ld	(iy+16),c
	ld	(iy+17),b
	exx
	ld	(iy+18),c
	ld	(iy+19),b
	ld	(iy+20),e
	ld	(iy+21),d
	ld	(iy+22),l
	ld	(iy+23),h
	exx
	ex	af,af

	ret

BSGTMPY:	dw	0


;--- NOMBRE: INLCALL
;      Llamada a una rutina en un segmento de InterNestor Lite
;    ENTRADA:
;             P(1) = Direccion
;             P(2) a P(11) = Registros
;    SALIDA:  P(2) a P(12) = Registros
;             Error -1 si INL no instalado

INLCALL:	ld	hl,(INLCSEG_DIR)
	ld	a,(hl)
	inc	a
	jp	z,TERMERR

	ld	hl,(INLDIR_DIR)
	ld	a,(ix+2)
	ld	(hl),a
	inc	hl
	ld	a,(ix+3)
	and	%00111111
	or	%01000000
	ld	(hl),a
	call	P2BUF
	call	VAR2REG
CALLINL_DIR:	call	0	;Se establece durante la instalacion
	call	REG2VAR
	call	BUF2P
	jp	TERMOK

INLDIR_DIR:	dw	0	;Se establece durante la instalacion
INLCSEG_DIR:	dw	0


;--- NOMBRE: GFXPRNT
;      Imprimie una cadena en modo grafico
;    ENTRADA: Coordenadas establecidas con PSET
;             F$(0) = Cadena
;    SALIDA:  -

GFXPRNT:	call	GETF01
	ld	hl,(F0BUFD)
	;ld      ix,GRPRT
BUCGFXP:	ld	a,(hl)
	or	a
	jp	z,TERMOK
	ld	ix,GRPRT
	call	EXTROM
	inc	hl
	jr	BUCGFXP


;--- NOMBRE: ST2MEM
;      Almacena una cadena en un segmento
;    ENTRADA: F$(0) = Cadena, hasta LONF01 caracteres
;             P(0)  = Segmento
;             P(1)  = Direccion
;             P(2)<>0 -> Actualizar P(1)
;    SALIDA:  P(1)  = P(1) + LEN(F$(0)) + 1 si P(2)<>0
;             USR   = -1 si no existe el segmento

ST2MEM:	call	GETF01
	ld	hl,(F0BUFD)
	push	hl
	ld	bc,0

BUCS2M:	inc	c	;Obtiene longitud de la cadena
	ld	a,(hl)	;(0 final incluido) en C
	or	a
	jr	z,OKS2ML
	inc	hl
	jr	BUCS2M

OKS2ML:	pop	hl	;HL = Dir. origen = F0BUF
	ld	e,(ix+2)	;DE = Dir. destino = P(1)
	ld	d,(ix+3)	;BC = Longitud
	res	7,d
	res	6,d
	ld	a,(ix)
	push	de,bc,ix,iy
	ld	ix,#FF00	;IXh = Segmento origen = 255
	ld	ixl,a	;IXl = Segmento destino = P(0)
	call	LDIRSS
	pop	iy,ix,bc,hl

	or	a
	jp	nz,TERMERR

	ld	a,(ix+4)	;Incremento de P(1) si P(2)<>0
	or	(ix+5)
	jp	z,TERMOK
	add	hl,bc
	ld	(iy+2),l
	ld	(iy+3),h
	jp	TERMOK


;--- NOMBRE: MEM2ST
;      Almacena una cadena contenida en un segmento en F$(1)
;    ENTRADA: P(0)  = Segmento
;             P(1)  = Direccion
;             P(2)  = Actualizar P(1) si <>0
;    SALIDA:  F$(1) = Cadena
;             P(1)  = P(1) + LEN(F$(1)) + 1 si P(2)<>0
;             USR   = -1 si no existe el segmento

MEM2ST:	ld	hl,(F1BUFD)
	ex	de,hl	;DE = Destino = F1BUF
	ld	bc,LONF01	;BC = Longitud = LONF01
	ld	l,(ix+2)	;HL = Origen = P(1)
	ld	h,(ix+3)
	res	7,h
	res	6,h
	ld	a,(ix)
	push	hl,ix,iy
	ld	ix,#00FF	;IXh = Segmento de origen = P(0)
	ld	ixh,a	;IXl = Segmento de destino = 255

	call	LDIRSS
	pop	iy,ix,hl
	or	a
	jp	nz,TERMERR

	xor	a	;Por si acaso, terminamos la cadena con 0
	push	ix
	ld	ix,(F1BUFD)
	ld	(ix+LONF01),a
	pop	ix

	ld	a,(ix+4)	;Actualizacion de P(1) si P(2)<>0
	or	(ix+5)
	jr	z,OKM2S
	ld	bc,1
	ld	de,(F1BUFD)
BUCM2S:	ld	a,(de)
	or	a
	jr	z,FBUCM2S
	;cp      34
	;jr      z,FBUCM2S
	inc	c
	inc	de
	jr	BUCM2S
FBUCM2S:	add	hl,bc
	ld	(iy+2),l
	ld	(iy+3),h

OKM2S:	call	SETF1
	jp	TERMOK


;--- NOMBRE: NBASAVE
;      Graba un programa BASIC en formato NBA
;      Previamente se ha de haber hecho POKE &HF676,4:POKE &H8003,0:NEW
;    ENTRADA: P(0)  = Dato a grabar en #8000
;             F$(0) = Nombre del fichero
;    SALIDA:  P(1)  = Numero de fichero (por si hay error)
;                     Si no ha quedado abierto, -1
;             Mismos errores que las funciones de disco

NBASAVE:	call	GETF01

	ld	a,-1
	ld	(iy+2),a
	ld	(iy+3),a

	ld	a,(ix)
	ld	(#8000),a

	ld	hl,(VARTAB)
	ld	(#8001),hl	;HL = Ultima dir. del programa +1
	ld	de,#8000
	or	a
	sbc	hl,de	;HL = Longitud a grabar
	ld	(LONSNBA),hl

	ld	hl,(F0BUFD)	;DE = Nombre del fichero
	ex	de,hl
	ld	b,0	;Sin atributos

	call	CREATE
	or	a
	jp	nz,TERMHL

	call	OPEN
	or	a
	jp	nz,TERMHL
	ld	(iy+2),b	;P(1) = Numero de fichero
	ld	(iy+3),a

	ld	de,#8000
	ld	hl,(LONSNBA)
	call	WRITE	;Grabacion del fichero
	or	a
	jp	nz,TERMHL

	call	CLOSE
	or	a
	jp	nz,TERMHL

	ld	a,-1
	ld	(iy+2),a
	ld	(iy+3),a
	jp	TERMOK

LONSNBA:	dw	0


;--- NOMBRE: NBASET
;      Establece un programa grabado en formato NBA y salta al modo directo
;    ENTRADA: P(0) = Segmento
;             P(1) = Direccion
;    SALIDA:  USR  = -1 -> No existe el segmento
;                    -2 -> Programa + Variables > HIMEM
;--- NOMBRE: NBARUN
;      Ejecuta un programa grabado en formato NBA
;    ENTRADA: P(0) = Segmento
;             P(1) = Direccion
;    SALIDA:  USR  = -1 -> No existe el segmento
;                    -2 -> Programa + Variables > HIMEM

NBASET:	ld	hl,#409B
	jr	NBASR

NBARUN:	ld	hl,#4601

NBASR:	ld	(RUNOSET),hl
	ld	l,(ix+2)
	ld	h,(ix+3)
	call	DIRTOP2
	ld	(NBADIR),hl
	ld	a,(ix)	;Existe el segmento
	call	CHKSLE
	jr	c,OKRUN1
	ld	b,a
	call	CHKSLV
	ld	a,b
	jp	nc,TERMERR
OKRUN1:	ld	(SEGRUN),a

	ld	hl,(ARYTAB)
	ld	de,(VARTAB)
	or	a
	sbc	hl,de
	ld	(LONVAR),hl	;LONVAR = Longitud zona de variables
	push	hl

	ld	hl,(STREND)
	ld	de,(ARYTAB)
	or	a
	sbc	hl,de
	ld	(LONMAT),hl	;LONMAT = Longitud zona de matrices

	;ld      hl,(LONMAT)
	pop	de	;DE = LONVAR
	add	hl,de
	push	hl
	pop	bc	;BC = Longitud variables + matrices
	ld	hl,(VARTAB)
	ld	de,0
	ld	ix,SEG_BUF+256*#FF
	;ld      ix,#FF02        ;*** Era 2
	call	LDIRSS	;Copia de las variables al seg. 2

	ld	a,(SEGRUN)
	ld	hl,(NBADIR)
	inc	hl
	call	CHKSLV
	jr	c,NBAVRM1
NBARAM1:	ld	b,a
	call	READ_SL
	ld	e,a
	inc	hl
	ld	a,b
	call	READ_SL
	ld	d,a
	ex	de,hl
	jr	OKNBA1
NBAVRM1:	rrca		;v1.01
	call	SET_RD
	in	a,(#98)
	ld	l,a
	ds	10	;10 NOPs de retardo
	in	a,(#98)	;NEWVAR = Nuevo inicio de las variables
	ld	h,a	;         (VARTAB)
OKNBA1:	ld	(NEWVAR),hl

	;ld      a,(SL_2)        ;Este cacho es de la beta 0.04
	;push    af
	;ld      a,(SEGRUN)
	;call    PUT_SL2
	;ld      ix,(NBADIR)      ;ld hl,(#8001)
	;ld      l,(ix+1)
	;ld      h,(ix+2)
	;ld      (NEWVAR),hl      ;NEWVAR = Nuevo inicio de las variables
	;pop     af               ;         (VARTAB)
	;call    PUT_SL2

	ld	hl,(NEWVAR)
	ld	de,(LONVAR)
	add	hl,de	;NEWARY = Nuevo inicio de las matrices
	ld	(NEWARY),hl	;         (ARYTAB)

	;ld      hl,(NEWARY)
	ld	de,(LONMAT)
	add	hl,de	;NEWSTR = Nuevo fin de las matrices
	ld	(NEWSTR),hl	;         (STREND)

	;ld      hl,(NEWSTR)
	ld	(SPRUN),sp
	ld	de,(SPRUN)
	ex	de,hl	;DE = NEWSTR
	ld	bc,100
	or	a
	sbc	hl,bc	;HL = SP-100

	or	a	;HL = Espacio libre si ponemos el nuevo
	sbc	hl,de	;programa, (SP-100) - STREND
	ld	hl,-2	;Fin con error -2 si espacio negativo
	ret	m

	ld	hl,(NBADIR)	;0
	ld	de,#8000
	ld	bc,(NEWVAR)
	res	7,b
	res	6,b	;BC = NEWVAR-#8000 = Longitud nuevo prog.
	ld	a,(SEGRUN)
	ld	ix,#00FF	;Origen: SEGRUN, Destino: seg. 255
	ld	ixh,a
	call	LDIRSS	;Copiamos el programa

	ld	hl,(LONVAR)
	ld	de,(LONMAT)
	add	hl,de
	push	de
	pop	bc	;BC = Longitud variables + matrices
	ld	de,(NEWVAR)
	ld	hl,0
	ld	ix,#FF+256*SEG_BUF
	;ld      ix,#02FF        ;*** Era 2
	call	LDIRSS	;Copiamos las variables + matrices

	ld	hl,(NEWVAR)	;Actualizamos zona de trabajo del BASIC
	ld	(VARTAB),hl
	ld	hl,(NEWARY)
	ld	(ARYTAB),hl
	ld	hl,(NEWSTR)
	ld	(STREND),hl

	pop	hl	;Ejecucion o establec. del nuevo programa
	ld	hl,#8003
	ld	iy,(#FCC0)
	ld	ix,(RUNOSET)
	jp	CALSLT

SEGRUN:	db	0
SPRUN:	dw	0
NEWVAR:	dw	0
NEWARY:	dw	0
NEWSTR:	dw	0
LONVAR:	dw	0
LONMAT:	dw	0
RUNOSET:	dw	0
NBADIR:	dw	0


;--- NOMBRE: BLKINI
;      Inicializa los colores y los tiempos del modo blink,
;      y borra la zona de la VRAM correspondiente.
;      No hace nada en modo grafico, o con menos de 41 columnas
;    ENTRADA: P(0) = Color de texto
;             P(1) = Color de fondo
;             P(2) = Tiempo ON
;             P(3) = Tiempo OFF
;    SALIDA:  USR  = -1 si no es SCREEN 0, o menos de 40 columnas

BLKINI:	ld	a,(SCRMOD)	;No hace nada si no estamos en SCREEN 0
	or	a
	jp	nz,TERMERR

	ld	a,(LINLEN)	;No hace nada si menos de 41 columnas
	cp	41	;(SCREEN 0 del MSX1)
	jp	c,TERMERR

	call	BLKALGO	;@@@
	call	BLK_CLS	;Borrado de la VRAM

	ld	a,(ix)	;Establecimiento del color
	sla	a
	sla	a
	sla	a
	sla	a
	ld	b,a
	ld	a,(ix+2)
	and	%00001111
	or	b
	call	BLK_COL

	ld	a,(ix+4)	;Establecimiento del color
	sla	a
	sla	a
	sla	a
	sla	a
	ld	b,a
	ld	a,(ix+6)
	and	%00001111
	or	b
	call	BLK_TIM

	jp	TERMOK


;--- NOMBRE: BLKMAK
;      Construye o borra un bloque blink
;    ENTRADA: P(0) = 0 para borrar bloque, 1 para crearlo
;             P(1) = Coordenada X inicial
;             P(2) = Coordenada Y inicial
;             P(3) = Longitud X
;             P(4) = Longitud Y
;             P(5) = Actualizar P(2) si <>0
;             P(6) = Actualizar P(3) si <>0
;    SALIDA:  P(1) = P(1) + P(3) si P(5)<>0
;             P(2) = P(2) + P(4) si P(6)<>0
;             USR  = -1 si P(3)>79 o P(4)>23 a la entrada.

BLKMAK:	ld	a,(SCRMOD)	;No hace nada si no estamos en SCREEN 0
	or	a
	jp	nz,TERMOK

	ld	a,(LINLEN)	;No hace nada si menos de 41 columnas 
	cp	41	;(SCREEN 0 del MSX1) 
	jp	c,TERMOK

	ld	a,(ix+3)	;Error si X>79
	or	a
	jp	nz,TERMERR
	ld	a,(ix+2)
	cp	80
	jp	nc,TERMERR

	ld	a,(ix+5)	;@@@ ;Error si Y>27 (era 23)
	or	a
	jp	nz,TERMERR
	ld	a,(ix+4)
	cp	28	;@@@    ;era 24
	jp	nc,TERMERR

	call	BLKALGO	;@@@
	ld	h,(ix+2)	;Obtencion de los parametros
	ld	l,(ix+4)
	ld	b,(ix+6)
	ld	c,(ix+8)

	ld	de,BKINCX	;Construccion/borrado del bloque
	push	de
	ld	a,(ix)
	or	a
	jp	z,BLK_OF
	jp	BLK_ON

BKINCX:	ld	a,(ix+10)	;Actualizacion de P(1)
	or	(ix+11)
	jr	z,BKINCY
	ld	l,(ix+2)
	ld	h,(ix+3)
	ld	c,(ix+6)
	ld	b,(ix+7)
	add	hl,bc
	ld	(iy+2),l
	ld	(iy+3),h

BKINCY:	ld	a,(ix+12)	;Actualizacion de P(2)
	or	(ix+13)
	jp	z,TERMOK
	ld	l,(ix+4)
	ld	h,(ix+5)
	ld	c,(ix+8)
	ld	b,(ix+9)
	add	hl,bc
	ld	(iy+4),l
	ld	(iy+5),h

	jp	TERMOK


;--- NOMBRE: INFINT
;      Devuelve informacion general sobre las interrupciones en marcha
;    ENTRADA: -
;    SALIDA:  P(0) = -1 si hay alguna interrupcion en marcha
;             P(1) = -1 si hay una interrupcion de usuario en marcha
;                  P(2) = Segmento
;                  P(3) = Direccion
;             P(4) = -1 si hay un efecto de sonido en marcha
;             P(5) = -1 si hay una musica sonando

INFINT:	di
	ld	a,(INT_DATA)
	push	af
	or	a
	jr	z,NOHAYINT
HAYINT:	ld	a,-1
NOHAYINT:	ld	(iy),a
	ld	(iy+1),a

	pop	af
	push	af
	bit	0,a
	ld	a,0
	jr	z,NOHAYUS
HAYUS:	ld	a,-1
NOHAYUS:	ld	(iy+2),a
	ld	(iy+3),a
	ld	a,(USR_SL)
	ld	(iy+4),a
	xor	a
	ld	(iy+5),a
	ld	hl,(USR_DIR)
	ld	(iy+6),l
	ld	(iy+7),h

	pop	af
	push	af
	bit	1,a
	ld	a,0
	jr	z,NOHAYSFX
HAYSFX:	ld	a,-1
NOHAYSFX:	ld	(iy+8),a
	ld	(iy+9),a

	pop	af
	push	af
	and	%00011100
	ld	a,0
	jr	z,NOHAYMUS
HAYMUS:	ld	a,-1
NOHAYMUS:	ld	(iy+10),a
	ld	(iy+11),a

	pop	af
	ei
	jp	TERMOK


;--- NOMBRE: ESTINT
;      Establece o quita la interrupcion de usuario
;    ENTRADA: P(0) =  0 -> Quitarla
;                     1 -> Ponerla
;                    -1 -> Invertir estado actual
;             P(1) = Segmento (solo para P(0)=1)
;             P(2) = Direccion (solo para P(0)=1)
;    SALIDA:  USR  = -1 -> Error: no existe el SL
;                          (no soporta el 255 ni los VRAM)
;                     7 -> P(0) incorrecto

ESTINT:	ld	a,(ix)
	or	(ix+1)
	jr	z,QUITIU

	ld	l,(ix)
	ld	h,(ix+1)
	inc	hl
	ld	a,h
	or	l
	jr	z,INVIU

	ld	a,(ix)
	dec	a
	jr	nz,ESTIERR
	or	(ix+1)
	jr	nz,ESTIERR

;--- Establecimiento

PONIU:	di
	ld	a,(ix+2)
	call	CHKSLE
	jp	nc,TERMERR

	ld	(USR_SL),a
	ld	l,(ix+4)
	ld	h,(ix+5)
	res	7,h
	res	6,h
	ld	(USR_DIR),hl

	ld	a,(INT_DATA)	;Si no habia control de int.,
	or	a	;lo activamos
	call	z,INT_ON
	ld	a,(INT_DATA)
	set	0,a
	ld	(INT_DATA),a

	ei
	jp	TERMOK

;--- Quitamiento

QUITIU:	di
	ld	a,(INT_DATA)
	res	0,a
	ld	(INT_DATA),a
	ei
	jp	TERMOK

;--- Giravueltamiento

INVIU:	di
	ld	a,(INT_DATA)
	or	a
	call	z,INT_ON
	ld	a,(INT_DATA)
	xor	%00000001
	ld	(INT_DATA),a
	ei
	jp	TERMOK

;--- Error 7

ESTIERR:	ld	a,7
	ei
	jp	TERMHL


;--- NOMBRE: INFOEFS
;      Devuelve informacion sobre los efectos sonoros
;    ENTRADA: P(0) = Nuevo volumen relativo (-1 para no cambiarlo)
;    SALIDA:  P(1) = -1 si hay un efecto sonando
;             P(2) = Numero de efecto que suena, o el ultimo que ha sonado
;             P(3) = Prioridad del efecto que suena
;             P(4) = Segmento del juego de efectos
;             P(5) = Direccion base del juego de efectos
;             P(6) = Numero del efecto mas alto
;             P(7) = Volumen relativo

INFOEFS:	ld	l,(ix)
	ld	h,(ix+1)
	inc	hl
	ld	a,h
	or	l
	jr	z,NOCHGV

	ld	a,(ix+1)
	or	a
	ld	a,15
	jr	nz,OKSETVM
	ld	a,(ix)	;Establecimiento del volumen maximo
	cp	15
	jr	c,OKSETVM
	ld	a,15
OKSETVM:	ld	(SFX_VOLM),a

NOCHGV:	ld	a,(INT_DATA)	;Establecimiento de P(1)
	bit	1,a
	ld	a,-1
	jr	nz,SISFXON
NOSFXON:	xor	a
SISFXON:	ld	(iy+2),a
	ld	(iy+3),a

	ld	a,(SFX_NUM)	;Establecimiento de P(2)
	ld	(iy+4),a

	ld	a,(SFX_PRI)	;Establecimiento de P(3)
	ld	(iy+6),a
	ld	(iy+7),a

	ld	a,(SFX_SL)	;Establecimiento de P(4)
	ld	(iy+8),a

	ld	hl,(SFX_DIR)	;Establecimiento de P(5)
	res	7,h
	res	6,h
	ld	(iy+10),l
	ld	(iy+11),h

	ld	a,(_HISFX)	;Establecimiento de P(6)
	ld	(iy+12),a

	ld	a,(SFX_VOLM)	;Establecimiento de P(7)
	ld	(iy+14),a

	xor	a
	ld	(iy+5),a
	ld	(iy+9),a
	ld	(iy+13),a
	ld	(iy+15),a

	jp	TERMOK


;--- NOMBRE: INITEFS
;      Inicializa un juego de efectos de sonido
;    ENTRADA: P(0) = Segmento
;             P(1) = Direccion
;    SALIDA:  USR  = -1 si no existe la direccion
;                     8 si los datos son incorrectos

INITEFS:	ld	a,(ix)
	call	CHKSLE
	jp	nc,TERMERR

	ld	a,(SL_2)
	push	af
	ld	a,(ix)
	call	PUT_SL2

	ld	a,(ix)
	ld	l,(ix+2)
	ld	h,(ix+3)
	call	DIRTOP2
	call	SFXINI
	ex	af,af
	pop	af
	call	PUT_SL2
	ex	af,af

	jp	nc,TERMOK
	ld	a,8
	jp	TERMHL


;--- NOMBRE: PLAYEFS
;      Reproduce un efecto sonoro
;    ENTRADA:  P(0) = Numero de efecto
;              P(1) = Prioridad (0: baja, <>0: alta)
;    SALIDA:   USR  = 0 -> Ok
;                     9 -> El efecto no esta definido (OFF)
;                    10 -> El efecto no existe
;                    11 -> Esta sonando otro con mas prioridad

PLAYEFS:	ld	a,(ix+1)
	or	a
	ld	a,10
	jp	nz,TERMHL

	ld	c,(ix)
	ld	b,(ix+2)
	or	(ix+3)
	call	SFXSET
	jp	nc,TERMOK

	add	10
	jp	TERMHL


;--- NOMBRE: STOPEFS
;      Detiene el efecto sonoro que suena
;    ENTRADA: -
;    SALIDA:  -

STOPEFS:	call	SFXCUT
	jp	TERMOK


;--- NOMBRE: INITMUS
;      Carga de los reproductores musicales en el segmento 5
;    ENTRADA: P(0) = 0 -> Cargar reproductor de Moonblaster 1.4
;                    1 -> Cargar reproductor de Moonblaster Wave
;                    2 -> Cargar reproductor de Moonblaster FM
;                    3 -> Deteccion automatica:
;                         Cargar MBWave si hay OPL4, si no, cargar MB14
;                    4 -> Deteccion automatica:
;                         Cargar MBFM si hay OPL4, si no, cargar MB14
;                   -1 -> Desinstalar
;    SALIDA:  USR  = -1 si el segmento 5 no existe o no es del mapeador primario
;                     7 si P(0) es incorrecto
;             P(0) = Reproductor cargado (0 a 2, -1 si desinstalar)
;             P(1) = Numero de fichero (por si hay error)
;                    Si no ha quedado abierto, -1
;             Mismos errores que las funciones de disco

INITMUS:	;--- Desinstalar?

	ld	a,(iy)
	and	(iy+1)
	cp	#FF
	jr	nz,INITMUS2

	ld	(iy),-1
	ld	(iy+1),-1
	ld	(iy+2),-1
	ld	(iy+3),-1
	call	CHKREP
	jp	nc,TERMOK

	push	iy
	call	_ENDMUS

	ld	e,0
	ld	hl,#8000
	call	WRITE_MUS
	pop	iy

	jp	TERMOK

	;--- Comprobaciones ---

INITMUS2:	ld	a,5
	call	GET_SF
	ld	a,(#F342)
	cp	b	;Error si el SL 5 no existe o no esta en
	jp	nz,TERMERR	;el mapeador primario

	ld	a,-1
	ld	(iy+2),a
	ld	(iy+3),a

	ld	a,(ix+1)	;Que reproductor hay que cargar?
	or	a
	ld	a,7
	jp	nz,TERMHL

	ld	a,(ix)
	or	a
	jr	z,OKTREP
	cp	1
	jr	z,OKTREP
	cp	3
	jr	z,OKTREP
	ld	a,7
	jp	TERMHL
OKTREP:	;ld      a,(ix)
	;ld      b,a              ;B = Tipo de reproductor a cargar

	;push    bc
	;call    CHKREP           ;Si ya hay cargado un reproductor
	;pop     bc               ;y es el mismo que queremos cargar...
	;jp      nc,NOHAYREP

	;ld      a,(TIPOREP)
	;cp      b
	;jp      z,TERMOK         ;...no lo cargamos otra vez.

NOHAYREP:	;ld      a,b
	ld	(TIPOREP),a
	ld	a,(SL_2)
	push	af

	;--- Ejecucion del test de chips (establece MUSCHIPS) ---
	;    Quitado en v1.01, ahora el test se hace al instalar

	ld	a,SEG_BUF	;*** Era 2
	call	PUT_SL2
;	ld	hl,SRCCHP-3	;Copia de la rutina SRCCHP al bufer
;	ld	de,SRCCHP+#4000-3
;	ld	bc,FSRCCHP-SRCCHP+3
;	ldir
;	call	SRCCHP+#4000	;Ejecucion de SRCCHP desde la P. 2 

	;--- Decision del reproductor que hay que cargar ---

	;ld	a,(CHIPSTMP)
	;ld	(CHIPSTM2),a

	ld	a,(TIPOREP)
	cp	3
	jr	c,OKTIPOREP

	ld	a,(MUSCHIPS)
	bit	2,a
	ld	a,0
	jr	z,OKTIPOREP

	ld	a,1
	;ld      a,(TIPOREP)
	;sub     2
OKTIPOREP:	ld	(TIPOREP),a

	;--- Carga del reproductor ---

	pop	af
	push	af
	call	PUT_SL2

	ld	hl,(USRTAB)	;Apertura de NBASIC.BIN
	ld	de,NBSTR-RES_I
	add	hl,de
	ex	de,hl
	call	OPEN
	or	a
	jp	nz,FINIMUS
	ld	(iy+2),b	;P(1) = Numero de fichero 
	ld	(iy+3),a
	push	bc
	ld	a,5
	call	PUT_SL2

	ld	de,0	;Establecimiento del puntero del fichero
	ld	hl,OCU_F-OCU_I+EXE_F-EXE_I+7+16488
	ld	a,(TIPOREP)
	ld	bc,0	;Puntero al reproductor MB14
	or	a
	jr	z,OKPF
	ld	bc,LONMB14+LONWAVE*2	;Punt. al reproductor MBFM
	cp	2
	jr	z,OKPF
	ld	bc,LONMB14	;Punt. al reproductor MBWAVE, Z80
	ld	a,(MSXVER)
	cp	3
	jr	c,OKPF
	call	GETCPU
	or	a
	jr	z,OKPF
	ld	bc,LONMB14+LONWAVE	;Punt. al rep. MBWAVE, R800

OKPF:	add	hl,bc
	xor	a
	pop	bc
	call	SEEK

	ld	de,#8000	;Lectura del fichero
	ld	hl,#4000
	call	READ
	cp	1
	jr	z,OKINIMUS
	cp	199
	jr	z,OKINIMUS
	or	a
	jr	nz,FINIMUS
OKINIMUS:	;

	;pop     bc               ;Lectura de los patches de OPL4
	ld	a,(TIPOREP)
	or	a
	jr	z,OKINIMUS2
	ld	hl,OCU_F-OCU_I+EXE_F-EXE_I+7+16488+LONMB14+LONWAVE*2
	ld	de,0
	xor	a
	call	SEEK

	ld	de,LONWAVE+#8000	;Lectura del fichero
	ld	hl,#4000-LONWAVE
	call	READ
	cp	1
	jr	z,OKINIMUS2
	cp	199
	jr	z,OKINIMUS2
	or	a
	jr	nz,FINIMUS
OKINIMUS2:	;

	call	CLOSE	;Cierre del fichero
	or	a
	jr	nz,FINIMUS

	;--- Finalizacion ---

	ld	a,(MUSCHIPS)	;Establecimiento de CHIPS y CHIPS_AC
	ld	e,a
	ld	hl,CHIPS
	call	WRITE_MUS
	ld	a,(MUSCHIPS)
	ld	e,a
	ld	hl,CHIPS_AC
	call	WRITE_MUS

	pop	af	;Establecimiento de P(0) y P(1)
	call	PUT_SL2
	ld	a,-1
	ld	(iy+2),a
	ld	(iy+3),a
	ld	a,(TIPOREP)
	ld	(iy),a
	xor	a
	ld	(iy+1),a

	jp	TERMOK	;Fin sin error

FINIMUS:	ld	b,a
	pop	af
	push	bc
	call	PUT_SL2
	ld	e,0
	ld	hl,#8000
	call	WRITE_MUS
	pop	af
	jp	TERMHL	;Fin con error

MUSCHIPS:	db	0


;--- NOMBRE: INFOMUS
;      Obtencion de informacion sobre la musica en curso
;    ENTRADA: -
;    SALIDA:  P(0) = -1 si hay una musica sonando o pausada
;             P(1) = -1 si hay una musica MB14 sonando o pausada
;             P(2) = -1 si hay una musica MBWAVE sonando o pausada
;             P(3) = -1 si hay una musica MBFM sonando o pausada
;             P(4) = -1 si la musica esta pausada
;             P(5) = Segmento
;             P(6) = Direccion
;             P(7) = Paterna
;             P(8) = Posicion
;             P(9) = -1 si hay MSX-MUSIC
;             P(10)= -1 si hay MSX-AUDIO
;             P(11)= -1 si hay OPL4
;             P(12)= -1 si los reproductores estan inicializados
;             P(13)= Reproductor cargado (valido solo si P(12)=-1)
;             F$(0)= Titulo de la musica
;             F$(1)= Samplekit

INFOMUS:
	;--- Establece P(9) a P(11)
	;    (v1.01, antes se establecian despues de comprobar
	;    que el reproductor estaba instaldo)

	ld	a,(MUSCHIPS)
	ld	b,a
	bit	0,b
	ld	a,-1
	jr	nz,MUSS4
	xor	a
MUSS4:	ld	(iy+18),a	;Establecimiento de P(9)
	ld	(iy+19),a
	bit	1,b
	ld	a,-1
	jr	nz,MUSS5
	xor	a
MUSS5:	ld	(iy+20),a	;Establecimiento de P(10)
	ld	(iy+21),a
	bit	2,b
	ld	a,-1
	jr	nz,MUSS6
	xor	a
MUSS6:	ld	(iy+22),a	;Establecimiento de P(11)
	ld	(iy+23),a

	call	CHKREP	;Establecimiento de P(12)
		ld	a,0	;y fin si es 0
	ld	(iy+24),a
	ld	(iy+25),a
	jp	nc,TERMOK
	ld	a,-1
	ld	(iy+24),a
	ld	(iy+25),a

	xor	a	;Inicialmente, F$(0) y F$(1) vacios
	ld	hl,(F0BUFD)
	ld	(hl),a
	ld	hl,(F1BUFD)
	ld	(hl),a

	ld	a,(INT_DATA)	;Establecimiento de P(0)
	and	%11100
	jr	z,NOMUSS
	ld	a,-1
NOMUSS:	ld	(iy),a
	ld	(iy+1),a

	ld	a,(INT_DATA)
	ld	b,a
	bit	2,b
	ld	a,-1
	jr	nz,MUSS1
	xor	a
MUSS1:	ld	(iy+2),a	;Establecimiento de P(1)
	ld	(iy+3),a
	bit	3,b
	ld	a,-1
	jr	nz,MUSS2
	xor	a
MUSS2:	ld	(iy+4),a	;Establecimiento de P(2)
	ld	(iy+5),a
	bit	4,b
	ld	a,-1
	jr	nz,MUSS3
	xor	a
MUSS3:	ld	(iy+6),a	;Establecimiento de P(3)
	ld	(iy+7),a

	ld	hl,MUS_PAU	;Establecimiento de P(4)
	call	READ_MUS
	ld	(iy+8),a
	ld	(iy+9),a

	ld	hl,MUS_SL1	;Establecimiento de P(5)
	call	READ_MUS
	ld	(iy+10),a
	xor	a
	ld	(iy+11),a

	ld	hl,MUS_DIR	;Esatblecimiento de P(6)
	call	READ_MUS
	ld	(iy+12),a
	inc	hl
	call	READ_MUS
	ld	(iy+13),a

	ld	hl,POS	;Establecimiento de P(7)
	call	READ_MUS
	ld	(iy+14),a
	xor	a
	ld	(iy+15),a

	ld	hl,STEP	;Establecimiento de P(8)
	call	READ_MUS
	ld	(iy+16),a
	xor	a
	ld	(iy+17),a

	;ld	(iy+25),a	;Establecimiento de P(13)
	;ld	a,(TIPOREP)
	;ld	(iy+24),a

	XOR	A	;@@@
	LD	(IY+27),A	;@@@
	LD	A,(TIPOREP)	;@@@
	LD	(IY+26),A	;@@@
	call	SETF0	;Hay que establecer F$(0) y F$(1)?
	call	SETF1
	ld	a,(iy)
	or	a
	jp	z,TERMOK

	ld	a,(SL_2)
	push	af
	ld	l,(iy+12)	;HL = Dir. de la musica
	ld	h,(iy+13)
	push	hl
	ld	a,(TIPOREP)
	or	a
	ld	bc,#CF	;Offset titulo para MB14
	jr	z,OKTIT1
	ld	bc,#E2-6	;Offset titulo para MBWAVE
OKTIT1:	add	hl,bc	;HL = Dir. del titulo

	ld	a,(iy+10)	;A  = SL de la musica
	push	hl
	call	PUT_SL2
	pop	hl

	ld	de,(F0BUFD)	;Establecimiento de F$(0)
	ld	a,(TIPOREP)
	or	a
	ld	bc,40	;Longitud titulo para MB14
	jr	z,OKTIT2
	ld	bc,50	;Longitud titulo para MBWAVE
OKTIT2:	ldir
	xor	a
	ld	(de),a

	pop	hl
	ld	a,(TIPOREP)
	or	a
	ld	bc,#140	;Offset samplekit para MB14
	jr	z,OKTIT3
	ld	bc,#114-6	;Offset samplekit para MBWAVE
OKTIT3:	add	hl,bc	;HL = Dir. del samplekit

	ld	b,8
	ld	de,(F1BUFD)
BUCSAM:	ld	a,(hl)	;Establecimiento de F$(1)
	cp	" "
	jr	z,FBUCSAM
	ld	(de),a
	inc	hl
	inc	de
	djnz	BUCSAM
FBUCSAM:	xor	a
	ld	(de),a

	pop	af
	call	PUT_SL2
	call	SETF0
	call	SETF1
	jp	TERMOK


;--- NOMBRE: SETCHIPS
;      Activa o desactiva los chips musicales
;    ENTRADA: P(0) = 0 -> No establecer, solo consultar
;                    1 -> Establecer segun P(1) a P(3)
;                    2 -> Establecer segun los que haya
;             P(1) = 0 -> No modificar MSX-MUSIC
;                    1 -> Desactivar MSX-MUSIC
;                    2 -> Activar MSX-MUSIC
;                   -1 -> Invertir estado del MSX-MUSIC
;             P(2) = 0 -> No modificar MSX-AUDIO
;                    1 -> Desactivar MSX-AUDIO
;                    2 -> Activar MSX-AUDIO
;                   -1 -> Invertir estado del MSX-AUDIO
;             P(3) = 0 -> No modificar OPL4
;                    1 -> Desactivar OPL4
;                    2 -> Activar OPL4
;                   -1 -> Invertir estado del OPL4
;    SALIDA:  P(4) = 0 -> MSX-MUSIC no presente
;                    1 -> MSX-MUSIC inactivo
;                    2 -> MSX-MUSIC activo
;             P(5) = 0 -> MSX-AUDIO no presente
;                    1 -> MSX-AUDIO inactivo
;                    2 -> MSX-AUDIO activo
;             P(6) = 0 -> OPL4 no presente
;                    1 -> OPL4 inactivo
;                    2 -> OPL4 activo

SETCHIPS:	call	CHKREP
	ld	a,12
	jp	nc,TERMHL

	;ld	hl,CHIPS
	;call	READ_MUS
	ld	a,(MUSCHIPS)	;v1.01
	ld	(CHIPS0),a
	ld	hl,CHIPS_AC
	call	READ_MUS
	ld	(CHIPS_AC0),a

	ld	a,(iy+1)
	or	a
	ld	a,7
	jp	nz,TERMHL
	ld	a,(iy)
	or	a
	jp	z,SCH_C
	cp	1
	jr	z,SCH_E
	cp	2
	jp	z,SCH_T
	ld	a,7
	jp	TERMHL

;--- Establecimiento segun P(1) a P(3)

SCH_E:	;

SCH_MUS:	ld	h,(iy+3)	;Modifcacion de MSX-MUSIC segun P(1)
	ld	l,(iy+2)
	inc	hl
	ld	a,h
	or	l
	jr	z,SCHMUS3
	dec	hl
	ld	a,h
	or	a
	ld	a,7
	jp	nz,TERMHL
	ld	a,l
	or	a
	jr	z,SCHMUS0
	cp	1
	jr	z,SCHMUS1
	cp	2
	jr	z,SCHMUS2
	ld	a,7
	jp	TERMHL

SCHMUS0:	jr	SCH_AUD	;No modificar

SCHMUS1:	ld	a,(CHIPS_AC0)	;OFF
	res	0,a
	ld	(CHIPS_AC0),a
	jr	SCH_AUD

SCHMUS2:	ld	a,(CHIPS0)	;ON
	bit	0,a
	jr	z,SCH_AUD
	ld	a,(CHIPS_AC0)
	set	0,a
	ld	(CHIPS_AC0),a
	jr	SCH_AUD

SCHMUS3:	ld	a,(CHIPS0)	;Invertir si el MUSIC esta presente
	bit	0,a
	jr	z,SCH_AUD
	ld	a,(CHIPS_AC0)
	xor	%00000001
	ld	(CHIPS_AC0),a

SCH_AUD:	ld	h,(iy+5)	;Modifcacion de MSX-AUDIO segun P(2)
	ld	l,(iy+4)
	inc	hl
	ld	a,h
	or	l
	jr	z,SCHAUD3
	dec	hl
	ld	a,h
	or	a
	ld	a,7
	jp	nz,TERMHL
	ld	a,l
	or	a
	jr	z,SCHAUD0
	cp	1
	jr	z,SCHAUD1
	cp	2
	jr	z,SCHAUD2
	ld	a,7
	jp	TERMHL

SCHAUD0:	jr	SCH_OP4	;No modificar

SCHAUD1:	ld	a,(CHIPS_AC0)	;OFF
	res	1,a
	ld	(CHIPS_AC0),a
	jr	SCH_OP4

SCHAUD2:	ld	a,(CHIPS0)	;ON
	bit	1,a
	jr	z,SCH_OP4
	ld	a,(CHIPS_AC0)
	set	1,a
	ld	(CHIPS_AC0),a
	jr	SCH_OP4

SCHAUD3:	ld	a,(CHIPS0)	;Invertir si el AUDIO esta presente
	bit	1,a
	jr	z,SCH_OP4
	ld	a,(CHIPS_AC0)
	xor	%00000010
	ld	(CHIPS_AC0),a

SCH_OP4:	ld	h,(iy+7)	;Modifcacion del OPL4 segun P(3)
	ld	l,(iy+6)
	inc	hl
	ld	a,h
	or	l
	jr	z,SCHOP43
	dec	hl
	ld	a,h
	or	a
	ld	a,7
	jp	nz,TERMHL
	ld	a,l
	or	a
	jr	z,SCHOP40
	cp	1
	jr	z,SCHOP41
	cp	2
	jr	z,SCHOP42
	ld	a,7
	jp	TERMHL

SCHOP40:	jr	SCH_OK	;No modificar

SCHOP41:	ld	a,(CHIPS_AC0)	;OFF
	res	2,a
	ld	(CHIPS_AC0),a
	jr	SCH_OK

SCHOP42:	ld	a,(CHIPS0)	;ON
	bit	2,a
	jr	z,SCH_OK
	ld	a,(CHIPS_AC0)
	set	2,a
	ld	(CHIPS_AC0),a
	jr	SCH_OK

SCHOP43:	ld	a,(CHIPS0)	;Invertir si el OPL4 esta presente
	bit	2,a
	jr	z,SCH_OK
	ld	a,(CHIPS_AC0)
	xor	%00000100
	ld	(CHIPS_AC0),a

SCH_OK:	ld	a,(CHIPS_AC0)	;Establecimiento
	ld	e,a
	ld	hl,CHIPS_AC
	call	WRITE_MUS

	jr	SCH_C

;--- Establecimiento de todos los chips disponibles

SCH_T:	ld	a,(CHIPS0)
	ld	e,a
	ld	hl,CHIPS_AC
	call	WRITE_MUS

;--- Parametros de salida

SCH_C:	xor	a
	ld	(iy+8),a
	ld	(iy+9),a
	ld	(iy+10),a
	ld	(iy+11),a
	ld	(iy+12),a
	ld	(iy+13),a

SCH_CMUS:	ld	a,(CHIPS0)	;P(4)
	bit	0,a
	jr	z,SCH_CAUD
	ld	a,(CHIPS_AC0)
	and	1
	inc	a
	ld	(iy+8),a

SCH_CAUD:	ld	a,(CHIPS0)	;P(5)
	bit	1,a
	jr	z,SCH_COP4
	ld	a,(CHIPS_AC0)
	srl	a
	and	1
	inc	a
	ld	(iy+10),a

SCH_COP4:	ld	a,(CHIPS0)	;P(6)
	bit	2,a
	jp	z,TERMOK
	ld	a,(CHIPS_AC0)
	srl	a
	srl	a
	and	1
	inc	a
	ld	(iy+12),a

	jp	TERMOK

CHIPS0:	db	0
CHIPS_AC0:	db	0


;--- NOMBRE: PLAYMUS
;      Comienza la reproduccion de una musica
;    ENTRADA: P(0) = Segmento
;             P(1) = Direccion
;    SALIDA:  USR  = -1 -> Segmento no existe o es VRAM
;                    12 -> Los reproductores no estan cargados
;                    13 -> No es un fichero Moonblaster USER
;                    14 -> Hay otra musica sonando o pausada

PLAYMUS:	di
	call	CHKREP	;Reproductores cargados?
	ld	a,12
	jp	nc,TERMHL

	ld	a,(iy)	;Existe el segmento? 
	call	CHKSLE
	jp	nc,TERMERR

	ld	hl,CHIPS_AC
	call	READ_MUS
	ld	(CHIPS_TMP),a

	ld	a,(TIPOREP)
	or	a
	jr	z,CHKPL14
	cp	1
	jr	z,CHKPLW

CHKPLF:	ld	a,1	;La musica esta en modo USER? (OPL4)
	call	CHKMBMS	;<---!!!
	jr	OKCHKPL
CHKPLW:	ld	a,8
	call	CHKMBMS	;<---!!!
OKCHKPL:	or	a
	jp	nz,TERMHL
	ld	a,(CHIPS_TMP)
	bit	2,a
	jp	z,TERMOK	;No hace nada si no hay OPL4 ;<---!!!
	jr	OKCHKPL2

CHKPL14:	ld	a,(iy)	;La musica no esta modo EDIT? (MB14)
	ld	b,a
	ld	l,(iy+2)
	ld	h,(iy+3)
	call	READ_SL
	cp	#FF
	ld	a,13
	jp	z,TERMHL
	ld	a,(CHIPS_TMP)	;Termina si no hay OPL1 ni OPLL activos
	and	%11
	jp	z,TERMOK
OKCHKPL2:	;

	ld	a,(INT_DATA)	;No hay musica sonando?
	and	%11100
	ld	a,14
	jp	nz,TERMHL

	ld	a,(iy)	;Establecimiento de MUS_SL y MUS_DIR
	ld	(MUS_SL0),a
	ld	hl,MUS_SL
	ld	e,a
	call	WRITE_MUS	;MUS_SL = Segmento inicial ;<---!!!
	inc	hl
	call	WRITE_MUS	;MUS_SL1 = Segmento inicial
	;push	hl
	;ld	hl,SL_NOW
	;call	WRITE_MUS
	;pop	hl
	;inc	hl
	;inc	e
	;call	WRITE_MUS	;MUS_SL2 = Segmento inicial + 1
	;inc	hl
	;inc	e
	;call	WRITE_MUS	;MUS_SL3 = Segmento inicial + 2
	LD	B,E
	INC	HL
	INC	E
	CALL	WRITE_MUS
	INC	HL
	INC	E
	CALL	WRITE_MUS
	LD	A,(TIPOREP)
	OR	A
	JR	Z,PLAYMUS34
	LD	E,B
	LD	HL,SL_NOW
	CALL	WRITE_MUS

	ld	l,(iy)	;Establecimiento de TAB_MUS
	ld	h,0
	add	hl,hl
	ld	bc,TABSEGS
	add	hl,bc
	ld	de,TAB_MUS
	ld	bc,6
	ld	ix,#0005
	push	ix,iy
	call	LDIRSS
	pop	iy,ix
PLAYMUS34:

	ld	l,(iy+2)
	ld	h,(iy+3)
	set	7,h
	res	6,h
	ld	bc,6	;Para saltarnos la cabecera
	ld	a,(TIPOREP)
	or	a
	jr	z,OKTIT10
	add	hl,bc
OKTIT10:	ex	de,hl
	ld	hl,MUS_DIR	;MUS_DIR = Direccion inicial
	call	WRITE_MUS	;<---!!!
	ld	e,d
	inc	hl
	call	WRITE_MUS	;<---!!!

	ld	a,(SL_2)
	push	af
	ld	a,(iy)	;<---!!!
	call	PUT_SL2

	ld	ix,STRMUS	;Musica mestre!!
	push	iy
	call	CALL_MUS
	pop	iy

	pop	af
	call	PUT_SL2

	ld	a,(INT_DATA)	;Establecimiento de las interrupciones
	or	a	;si no habia ninguna activa
	call	z,INT_ON
	di

	ld	a,(TIPOREP)
	or	a
	jr	z,ESREP0
	cp	1
	jr	z,ESREP1

ESREP2:	ld	a,(INT_DATA)
	set	4,a
	jr	OKESREP

ESREP1:	ld	a,(INT_DATA)
	set	3,a
	jr	OKESREP

ESREP0:	ld	a,(INT_DATA)
	set	2,a

OKESREP:	ld	(INT_DATA),a
	jp	TERMOK

;--- Subrutina CHKMBMS: Comprueba si la musica es MBWave of MBFM
;    Entrada: A = 1 para MBFM
;             A = 8 para MBWave
;    Salida:  A = Error (0 o 13)

CHKMBMS:	push	bc,de,hl
	ld	(TIPOCHK),a

	ld	l,(iy+2)
	ld	h,(iy+3)	;Direccion, adecuada a pag. 2
	set	7,h
	res	6,h

	ld	a,(SL_2)
	push	af
	ld	a,(iy)
	push	hl
	call	PUT_SL2
	pop	hl

	ld	de,MBMSSTR
	ld	b,4
CHKMBSTR:	ld	a,(de)	;Comprobacion de la cadena "MBMS"
	cp	(hl)
	ld	a,13
	jr	nz,FINCHKMB
	inc	de
	inc	hl
	djnz	CHKMBSTR

	ld	a,(TIPOCHK)	;Es del tipo adecuado?
	inc	hl
	cp	(hl)
	ld	a,13
	jr	nz,FINCHKMB

	xor	a
FINCHKMB:	ex	af,af
	pop	af
	call	PUT_SL2
	ex	af,af
	pop	bc,de,hl
	ret

TIPOCHK:	db	0	;Tipo a comprobar

MBMSSTR:	db	"MBMS",16,0
CHIPS_TMP:	db	0


;--- NOMBRE: ENDMUS
;      Termina la reproduccion de la musica
;      No hace nada si no hay musica sonando
;    ENTRADA: -
;    SALIDA:  -

ENDMUS:	call	CHKREP	;@@@
	jp	nc,TERMOK	;@@@

	ld	hl,TERMOK
	push	hl

_ENDMUS:	;          di
	ld	a,(INT_DATA)
	or	a
	jr	z,ENDMU1
	and	%11100011
	ld	(INT_DATA),a
	call	z,INT_OFF
ENDMU1:	ei

	ld	ix,STPMUS
	call	CALL_MUS
	ld	hl,FADING
	ld	e,0
	call	WRITE_MUS

	xor	a
	ld	(MUS_PAU0),a
	ld	e,a
	ld	hl,MUS_PAU
	call	WRITE_MUS

	ret		;jp      TERMOK


;--- NOMBRE: PACOMUS
;      Pausa o continua la musica
;      No hace nada si no hay musica sonando
;    ENTRADA: P(0) = 0 -> Pausar musica
;                    1 -> Continuar musica
;                   -1 -> Invertir estado
;    SALIDA:  USR  = 7 -> P(0) incorrecto

PACOMUS:	call	CHKREP
	jp	nc,TERMOK

	ld	a,(ix)
	or	(ix+1)
	jr	z,PAUMU

	ld	l,(ix)
	ld	h,(ix+1)
	inc	hl
	ld	a,h
	or	l
	jr	z,INVMU

	ld	a,(ix)
	dec	a
	jr	nz,PACOERR
	or	(ix+1)
	jr	nz,PACOERR

;--- Continuamiento

CONMU:	ld	a,(MUS_PAU0)	;No hace nada si no hay musica pausada
	or	a
	jp	z,TERMOK

	ld	a,(INT_DATA)	;No hace nada si no hay musica sonando 
	and	%11100
	jp	z,TERMOK

	ld	ix,CONTMUS
	call	CALL_MUS

	xor	a
	ld	(MUS_PAU0),a

	jp	TERMOK

;--- Pauseamiento

PAUMU:	ld	a,(MUS_PAU0)	;No hace nada si ya esta pausada
	or	a
	jp	nz,TERMOK

	ld	a,(INT_DATA)	;No hace nada si no hay musica sonando
	and	%11100
	jp	z,TERMOK

	ld	ix,PAUMUS
	call	CALL_MUS

	ld	a,#FF
	ld	(MUS_PAU0),a

	jp	TERMOK

;--- Inversionamiento

INVMU:	ld	a,(MUS_PAU0)
	or	a
	jr	z,PAUMU
	jr	CONMU

;--- Error

PACOERR:	ld	a,7
	jp	TERMHL


;--- NOMBRE: FADEMUS
;      Fadea la musica
;    ENTRADA: P(0) = Velocidad (1=rapida ... 255=lenta, 0=solo consultar)
;    SALIDA:  P(1) = -1 si hay una musica fadeando
;             P(2) = Velocidad a la que fadea

FADEMUS:	CALL	CHKREP	;@@@
	JR	NC,FADENO	;@@@

	ld	a,(INT_DATA)
	and	%11100
	jr	z,FADENO	;@@@        ;Era JP

	ld	a,(iy)
	or	(iy+1)
	jr	z,FADECON

	ld	e,255
	ld	hl,FADING
	call	WRITE_MUS
	ld	e,(iy)
	ld	hl,FADSPD
	call	WRITE_MUS
	ld	e,0
	ld	hl,FADCNT
	call	WRITE_MUS

FADECON:	ld	hl,FADING
	call	READ_MUS
	ld	(iy+2),a
	ld	(iy+3),a
	XOR	A	;@@@
	LD	(IY+#05),A	;@@@

	ld	hl,FADSPD
	call	READ_MUS
	ld	(iy+4),a
	CP	#FF
	JP	NZ,TERMOK
	;xor	a
	ld	(iy+5),a

	jp	TERMOK

FADENO:	xor	a
	ld	(iy+2),a
	ld	(iy+3),a
	ld	(iy+4),a
	ld	(iy+5),a
	jp	TERMOK


;--- NOMBRE: LOADMBK
;      Carga un samplekit de Music Module de un fichero
;    ENTRADA: P(0) = Numero de fichero
;    SALIDA:  P(7) = Bytes leidos
;             Errores de acceso a disco. No hace nada si no hay MM.

LOADMBK:	call	CHKREP
	jp	nc,TERMOK

	LD	A,(TIPOREP)	;@@@
	OR	A	;@@@
	JP	NZ,TERMOK	;@@@

	;ld	hl,CHIPS
	;call	READ_MUS
	ld	a,(MUSCHIPS)	;v1.01
	bit	1,a
	ld	a,0
	ld	(iy+14),a
	ld	(iy+15),a
	jp	z,TERMOK

	ld	a,(MSXVER)
	cp	3
	jr	c,LDMBK2

	call	GETCPU	;Cambio a modo Z80
	or	a
	ld	(CPULMBK),a
	jr	z,LDMBK2
	ld	a,%10000000
	call	CHGCPU

LDMBK2:	ld	hl,0
	ld	(LEIMBK),hl
	ld	(iy+14),h
	ld	(iy+15),h

	ld	a,(iy)
	ld	(MBKFN),a
	ld	a,(SL_2)
	push	af
	ld	a,5
	call	PUT_SL2

	ld	a,(MBKFN)
	ld	b,a
	ld	hl,56
	ld	de,SMPADR
	call	READ
	or	a
	jr	nz,FLMBK
	ld	hl,56
	ld	(LEIMBK),hl

	ld	a,SEG_BUF	;*** Era 2
	call	PUT_SL2

	ld	a,(MBKFN)
	ld	b,a
	ld	de,#8000
	ld	hl,#4000
	call	READ
	or	a
	jr	nz,FLMBK
	ld	hl,#4000+56
	ld	(LEIMBK),hl
	push	iy
	call	MOVSMPA
	pop	iy

	ld	a,(MBKFN)
	ld	b,a
	ld	de,#8000
	ld	hl,#4000
	call	READ
	or	a
	jr	nz,FLMBK
	ld	hl,#8000+56
	ld	(LEIMBK),hl
	push	iy
	call	MOVSMPB
	pop	iy

	xor	a
	jr	FLMBK2

FLMBK:	ex	de,hl
	ld	hl,(LEIMBK)
	add	hl,de
	ld	(LEIMBK),hl
FLMBK2:	ld	b,a
	pop	af
	push	bc
	call	PUT_SL2
	ld	hl,(LEIMBK)
	ld	(iy+14),l
	ld	(iy+15),h
	ld	a,(MSXVER)
	cp	3
	jr	c,FLMBK3
	ld	a,(CPULMBK)
	or	a
	jr	z,FLMBK3	;Restauracion de la CPU
	set	7,a
	call	CHGCPU
FLMBK3:	pop	af
	jp	TERMHL

LEIMBK:	dw	0
	dw	0
MBKFN:	db	0
CPULMBK:	db	0


	;--- Carga de wavekit MoonSound
	;    Parametros como LOADMBK.

LOADMWK:	CALL	CHKREP	;#57E2
	JP	NC,TERMOK	;#5BDA

	LD	A,(TIPOREP)	;Reproductor Wave?
	CP	#01
	JP	NZ,TERMOK

	;LD	HL,CHIPS
	;CALL	READ_MUS
	ld	a,(MUSCHIPS)	;v1.01
	BIT	2,A
	LD	A,#00
	LD	(IY+#0E),A
	LD	(IY+#0F),A
	JP	Z,TERMOK	;Hay MoonSound?

	LD	HL,#0000	;De momento 0 datos leidos de disco
	LD	(LEIMBK),HL
	LD	(LEIMBK+2),HL
	LD	(IY+#0E),H
	LD	(IY+#0F),H

	LD	A,(IY+#00)
	LD	(MBKFN),A	;Numero de fichero

	LD	A,(SL_2)	;Conecta segmento bufer
	PUSH	AF
	ld	a,SEG_BUF	;*** Era 2
	CALL	PUT_SL2	;#4653

	LD	HL,BUF_MWK	;Limpia bufer de 1264 bytes
	LD	DE,BUF_MWK+1
	LD	BC,#04EF
	LD	(HL),#00
	LDIR

	LD	A,(MBKFN)	;Lee 6 bytes al bufer
	LD	B,A
	LD	HL,#0006
	LD	DE,#8000
	CALL	READ

	CALL	UPDAT_LEID
	OR	A
	JR	NZ,J75F3
	LD	A,#0D
	CALL	CHK_MBMS
	LD	A,#0F
	JP	NZ,J75F3
	CALL	SEND_35210
	CALL	READ_44
	OR	A
	JR	NZ,J75F3
	CALL	C766B
	OR	A
	JR	NZ,J75F3
	LD	A,#05
	CALL	PUT_SL2	;#4653
	LD	HL,(#8038)
	;LD      BC,#4000
	;ADD     HL,BC
	EX	DE,HL
	LD	HL,BUF_MWK
	LD	BC,#04F0
	;LDIR
	push	ix,iy
	LD	IX,5+256*SEG_BUF	;*** Era 2
	;LD      IX,#0205         ;*** PRUEBAS
	CALL	LDIRSS	;*** PRUEBAS
	pop	iy,ix

	XOR	A

J75F3:	LD	B,A
	POP	AF
	PUSH	BC
	CALL	PUT_SL2	;#4653
	LD	HL,(LEIMBK)
	LD	(IY+#0E),L
	LD	(IY+#0F),H
	LD	HL,(LEIMBK+2)
	LD	(IY+#0C),L
	LD	(IY+#0D),H
	POP	AF
	JP	TERMHL	;#5BDF

	;--- Actualizacion del num. de bytes leidos

UPDAT_LEID:	PUSH	AF
	PUSH	DE
	PUSH	HL
	EX	DE,HL
	LD	HL,(LEIMBK)
	ADD	HL,DE
	LD	(LEIMBK),HL
	LD	HL,(LEIMBK+2)
	LD	DE,#0000
	ADC	HL,DE
	LD	(LEIMBK+2),HL
	POP	HL
	POP	DE
	POP	AF
	RET

	;--- Lee #44 bytes

READ_44:	LD	HL,#0044
	LD	DE,#8000
	LD	A,(MBKFN)
	LD	B,A
	CALL	READ	;#5349
	CALL	UPDAT_LEID
	OR	A
	RET	NZ

	PUSH	BC
	LD	HL,#8004
	LD	DE,BUF_MWK+1200	;*** PRUEBA: era #7C77
	LD	BC,#0040
	LDIR
	LD	A,(#8003)
	LD	B,A
	LD	HL,#0000
	LD	DE,#0019
J7651:	ADD	HL,DE
	DJNZ	J7651
	POP	BC
	PUSH	HL
	LD	DE,#8000
	CALL	READ	;#5349
	CALL	UPDAT_LEID
	POP	BC
	OR	A
	RET	NZ

	LD	HL,#8000
	LD	DE,BUF_MWK
	LDIR
	RET


C766B:	LD	DE,#0000
	LD	IX,D7757
	LD	(IX+#00),#00
	LD	(IX+#01),#03
	LD	(IX+#02),#20
	LD	HL,BUF_MWK+1200	;*** PRUEBA: era #7C77
	LD	B,#40
	XOR	A
J7684:	PUSH	BC
	PUSH	HL
	BIT	0,(HL)
	CALL	NZ,C76A5
	OR	A
	JR	NZ,J76A2
	EX	DE,HL
	LD	DE,#000C
	ADD	HL,DE
	EX	DE,HL
	POP	HL
	INC	HL
	POP	BC
	DJNZ	J7684
	LD	C,#02
	LD	A,#10
	CALL	SEND_C_A
	XOR	A
	RET

J76A2:	POP	HL
	POP	BC
	RET


C76A5:	PUSH	DE
	PUSH	HL
	LD	DE,#8001
	LD	HL,#000D
	LD	A,(MBKFN)
	LD	B,A
	CALL	READ	;#5349
	CALL	UPDAT_LEID
	OR	A
	JP	NZ,J7754
	LD	HL,(#8001)
	LD	A,(IX+#00)
	ADD	A,L
	LD	(#8002),A
	LD	A,(IX+#01)
	ADD	A,H
	LD	(#8001),A
	POP	HL
	PUSH	AF
	LD	A,(HL)
	AND	#C0
	OR	(IX+#02)
	LD	(#8000),A
	POP	AF
	JR	NC,J76DE
	LD	HL,#8000
	INC	(HL)
J76DE:	POP	HL
	PUSH	HL
	LD	E,#20
	CALL	C7772
	LD	HL,#8000
	LD	DE,#000C
	CALL	SEND_C4
	LD	L,(IX+#00)
	LD	H,(IX+#01)
	LD	E,(IX+#02)
	CALL	C7772
	LD	HL,(#800C)
	PUSH	HL
	LD	(D775A),HL
J7701:	LD	DE,#3000	;*** PRUEBA: era #4000
	LD	HL,(D775A)
	OR	A
	SBC	HL,DE
	LD	(D775A),HL
	JR	C,J772C
	LD	A,L
	OR	H
	JR	Z,J772C
	LD	A,(MBKFN)
	LD	B,A
	LD	DE,#8000
	LD	HL,#3000	;*** PRUEBA: era #4000
	CALL	READ	;#5349
	CALL	UPDAT_LEID
	OR	A
	JR	NZ,J7754
	EX	DE,HL
	CALL	SEND_C4
	JR	J7701
J772C:	ADD	HL,DE
	LD	DE,#8000
	CALL	READ	;#5349
	CALL	UPDAT_LEID
	OR	A
	JR	NZ,J7754
	EX	DE,HL
	CALL	SEND_C4
	POP	HL
	LD	A,(IX+#00)
	ADD	A,L
	LD	(IX+#00),A
	LD	A,(IX+#01)
	ADC	A,H
	LD	(IX+#01),A
	JR	NC,J7751
	INC	(IX+#02)
J7751:	POP	DE
	XOR	A
	RET

J7754:	POP	DE
	POP	HL
	RET

D7757:	NOP
	NOP
	NOP
D775A:	NOP
	NOP

	;--- Envia DE bytes desde la dir HL al puerto #C4

SEND_C4:	PUSH	HL
	PUSH	DE
	PUSH	BC
	LD	C,#7F
J7761:	OUTI
J7763:	IN	A,(#C4)
	BIT	0,A
	JR	NZ,J7763
	DEC	DE
	LD	A,D
	OR	E
	JR	NZ,J7761
	POP	BC
	POP	DE
	POP	HL
	RET


C7772:	LD	C,#02
	LD	A,#11
	CALL	SEND_C_A
	INC	C
	LD	A,E
	AND	#3F
	CALL	SEND_C_A
	INC	C
	LD	A,H
	CALL	SEND_C_A
	INC	C
	LD	A,L
	CALL	SEND_C_A
	LD	A,#06
	OUT	(#7E),A
	LD	C,#7F
	RET


	;--- Comprueba si es un fichero MBMS

CHK_MBMS:	LD	(MBMSSTR+5),A	;(#7388),A
	LD	HL,MBMSSTR	;#7383
	LD	DE,#8000
	LD	B,#06
J779C:	LD	A,(DE)
	CP	(HL)
	RET	NZ
	INC	HL
	INC	DE
	DJNZ	J779C
	RET


	;--- Envia 3, 5, 2, 10 a #C5 y #C6

SEND_35210:	LD	A,#03
	LD	C,#05
	CALL	SEND_C5_C6
	LD	C,#02
	LD	A,#10

	;--- Envia C y luego A a #7E

SEND_C_A:	EX	AF,AF'
	LD	A,C
	PUSH	BC
	POP	BC
	OUT	(#7E),A
	EX	AF,AF'
	PUSH	BC
	POP	BC
	OUT	(#7F),A
	RET

	;--- Envia C a #C6, y luego A a #C5

SEND_C5_C6:	EX	AF,AF'
	LD	A,C
	PUSH	BC
	POP	BC
	OUT	(#C6),A
	EX	AF,AF'
	PUSH	BC
	POP	BC
	OUT	(#C5),A
	RET

	;--- Zona de datos desde aqui

BUF_MWK:	EQU	#B000	;*** PRUEBA


;--- NOMBRE: SETMEM
;      Devuelve o establece la cantidad de memoria que usara NB
;    ENTRADA: P(0) = Numero de segmentos a usar, 5 a 247
;                    0 para solo consultar
;    SALIDA:  P(0) = Numero de segmentos que usara NB
;             P(1) = Numero maximo de segmentos disponibles

SETMEM:	ld	a,(DOSVERP)
	cp	2
	jr	nc,SETM_DOS2

;--- SETMEM: Version DOS 1

SETM_DOS1:	ld	a,(iy)
	or	(iy+1)
	jr	z,SM1_END

	call	SM_ADJP0	;Acotamos el num. de segmentos
	ld	a,(TOTSEGS)	;B = Seg. maximos + 1
	ld	b,a
	inc	b
	ld	a,(iy)	;A = Seg. requeridos
	cp	b	;Cy si requeridos<maximos+1
	jr	c,SM1_2
	ld	a,b
	dec	a
SM1_2:	ld	(NUMSEGS),a

SM1_END:	ld	a,(NUMSEGS)
	ld	(iy),a
	ld	(iy+1),0
	ld	a,(TOTSEGS)
	ld	(iy+2),a
	ld	(iy+3),0
	jp	TERMOK

;--- SETMEM: Version DOS 2

SETM_DOS2:	ld	a,(iy)
	or	(iy+1)
	jp	z,SM2_INFO

	;--- Comprueba si queremos mas o menos segmentos
	;    de los que hay ahora

	call	SM_ADJP0
	ld	b,(iy)
	ld	a,(NUMSEGS)
	cp	b
	jp	z,SM2_INFO	;Iguales: no hacemos nada

	jr	c,SM2_RESERVA	;Cy si requeridos<actuales

	;--- Liberacion de segmentos existentes:
	;    Va liberando hasta que (NUMSEGS) coincida con P(0)

SM2_LIBERA:	ld	ix,TABSEGS
	ld	a,(NUMSEGS)
	ld	e,a
	ld	d,0
	dec	e
	add	ix,de	;IX apunta al ultimo seg. disponible
	add	ix,de
	inc	e	;E = (NUMSEGS)

SM2_LIBLOOP:	ld	b,(ix)
	ld	a,(ix+1)
	push	ix,iy,de
	call	FRE_SEG
	pop	de,iy,ix
	ld	(ix),0
	ld	(ix+1),0
	dec	ix
	dec	ix
	dec	e
	ld	a,e
	cp	(iy)
	jr	z,SM2_END
	jr	nc,SM2_LIBLOOP
SM2_END:	;

	;ld      a,e
	ld	(NUMSEGS),a
	jr	SM2_INFO

	;--- Adicion de segmentos nuevos:
	;    Los va anyadiendo hasta que no queden
	;    o hasta llegar a P(0) o a 247

SM2_RESERVA:	ld	ix,TABSEGS
	ld	a,(NUMSEGS)
	ld	e,a	;E = (NUMSEGS)
	;ld      a,c
	;cp      247
	;jr      z,SETM_INFO
	ld	d,0
	add	ix,de	;IX apunta al 1er seg. libre
	add	ix,de

	ld	a,(#F344)
	and	%1 000 1111
	or	%0 010 0000
	ld	b,a	;B = Slot para la reserva

SM2_RESLOOP:	xor	a
	push	bc,ix,iy,de
	call	ALL_SEG
	pop	de,iy,ix
	jr	c,SM2_RESEND

	ld	(ix),b
	ld	(ix+1),a
	pop	bc
	inc	ix
	inc	ix
	inc	e

	ld	a,e
	cp	247
	jr	nc,SM2_RESEND
	cp	(iy)
	jr	c,SM2_RESLOOP

	push	bc
SM2_RESEND:	pop	bc
	ld	a,e
	ld	(NUMSEGS),a

SM2_INFO:	;--- Solo informacion:
	;    Calcula num. de segmentos libres en el sistema

	xor	a
	ld	de,#0401
	push	iy
	call	EXTBIO
	pop	iy
	ld	e,0	;E = Contador de segs. libres
	ld	bc,6

SM2_LOOP1:	ld	a,(hl)
	or	a
	jr	z,SM2_LP1END
	inc	hl
	inc	hl
	ld	a,(hl)
	add	e
	ld	e,a
	add	hl,bc
	jr	SM2_LOOP1
SM2_LP1END:	;

	;--- Establece P(1) como E + (NUMSEGS) y P(0)=(NUMSEGS)

	ld	a,(NUMSEGS)
	ld	l,a
	ld	h,0
	ld	d,0
	add	hl,de
	ld	(iy),l
	ld	(iy+1),h	;P(0) = Totales posibles

	call	SM_ADJP0
	ld	a,(iy)
	ld	(iy+2),a
	ld	a,(iy+1)
	ld	(iy+3),a	;P(0) -> P(1)
	ld	a,(NUMSEGS)
	ld	(iy),a
	ld	(iy+1),0
	jp	TERMOK

;--- Rutinas comunes DOS 1 y 2

	;--- Ajuste de P(0)
	;    Si es >247 lo pone a 247
	;    Si es <6 lo pone a 5, o a 6 si hay rep. musical

SM_ADJP0:	ld	c,(iy)
	ld	a,(iy+1)
	or	a
	jr	z,OK_P01
	bit	7,a
	ld	c,5	;<0? Lo ponemos a 5
	jr	nz,OK_P01
	or	a
	ld	c,247	;>255? Lo ponemos a 247
	jr	nz,OK_P01
	ld	c,(iy)

OK_P01:	ld	(iy+1),0	;>247? Lo ponemos a 247
	ld	a,c
	cp	248
	jr	c,OK_P02
	ld	(iy),247
	ret

OK_P02:	cp	6	;<6? Lo ponemos a 5 o a 6,
	jr	nc,OK_P03	;segun si hay rep. musical o no
	ld	c,5
	call	CHKREP
	jr	nc,OK_P03
	inc	c

OK_P03:	ld	(iy),c
	ret


;--- NOMBRE: LDIR_NB_NM
;      Copia un bloque de memoria de un segmento de NMAN a un segmento de NB
;    ENTRADA:  P(0) = SL NMAN origen
;              P(1) = Direccion origen
;              P(2) = SL NB destino
;              P(3) = Direccion destino
;              P(4) = Longitud de la transferencia
;              P(5) = Incrementar P(1) si <>0
;              P(6) = Incrementar P(3) si <>0
;    SALIDA:   USR =  0: Transferencia realizada
;                    -1: Uno de los SL no existe

LDIR_NB_NM:	ld	a,(ix+1)
	or	a
	jp	nz,TERMERR
	ld	a,(ix)
	ld	c,3	;Out: B=Slot, C=Seg
	push	ix
	call	NESMAN
	pop	ix
	ld	a,b
	or	a
	jp	z,TERMERR

	ld	hl,(TABSEGS+2)
	push	hl
	ld	(TABSEGS+2),a	;Establece seg NB 1
	ld	a,c	;como el seg NMAN fuente
	ld	(TABSEGS+3),a

	ld	a,1
	ld	iyh,a
	ld	l,(ix+2)	;IYh:HL = Dir. origen
	ld	h,(ix+3)

	ld	a,(ix+4)	;IYl:DE = Dir. destino
	ld	e,(ix+6)
	ld	d,(ix+7)
	ld	iyl,a

	call	LDIRSL2
	pop	hl
	ld	(TABSEGS+2),hl
	jp	nz,TERMERR
	jp	TERMOK


;--- NOMBRE: LDIR_NM_NB
;      Copia un bloque de memoria de un segmento de NB a un segmento de NMAN
;    ENTRADA:     P(0) = SL NB origen
;	P(1) = Direccion origen
;                 P(2) = SL NMAN destino
;	P(3) = Direccion destino
;	P(4) = Longitud de la transferencia
;	P(5) = Incrementar P(1) si <>0
;	P(6) = Incrementar P(3) si <>0
;    SALIDA:   USR =  0: Transferencia realizada
;                    -1: Uno de los SL no existe

LDIR_NM_NB:	ld	a,(ix+5)
	or	a
	jp	nz,TERMERR
	ld	a,(ix+4)
	ld	c,3	;Out: B=Slot, C=Seg
	push	ix
	call	NESMAN
	pop	ix
	ld	a,b
	or	a
	jp	z,TERMERR

	ld	hl,(TABSEGS+2)
	push	hl
	ld	(TABSEGS+2),a	;Establece seg NB 1
	ld	a,c	;como el seg NMAN fuente
	ld	(TABSEGS+3),a

	ld	a,1
	ld	iyl,a
	ld	e,(ix+6)	;IYl:DE = Dir. destino
	ld	d,(ix+7)

	ld	a,(ix)
	ld	l,(ix+2)	;IYh:HL = Dir. origen
	ld	h,(ix+3)
	ld	iyh,a

	call	LDIRSL2
	pop	hl
	ld	(TABSEGS+2),hl
	jp	nz,TERMERR
	jp	TERMOK


;--- NOMBRE: INFONMAN
;      Devuelve informacion sobre NestorMan & INS
;    ENTRADA: -
;    SALIDA:  P(0) = 0 si NestorMan no esta instalado
;                    1 si NestorMan esta instalado pero INS no
;                    3 si NestorMan e INS estan instalados
;             P(1) a P(4): SL de NMAN de los modulos de INS
;             P(5) = Num. de SL de NMAN del SL 4 de NBASIC (0 si no NMAN)

INFONMAN:	ld	(iy),0
	ld	(iy+1),0
	ld	(iy+11),0

	ld	a,(NMANS4)	;NMAN instalado?
	ld	(iy+10),a
	or	a
	jr	z,INFONM2
	ld	(iy),1

	ld	c,32	;INS instalado?
	push	iy
	call	NESMAN
	pop	iy
	or	a
	jr	z,INFONM2

	ld	(iy),3

	;--- Segmentos de INS

INFONM2:	ld	a,(INS_SL1)
	ld	(iy+2),a
	ld	(iy+3),0
	ld	a,(INS_SL2)
	ld	(iy+4),a
	ld	(iy+5),0
	ld	a,(INS_SL3)
	ld	(iy+6),a
	ld	(iy+7),0
	ld	a,(INS_SL4)
	ld	(iy+8),a
	ld	(iy+9),0

	jp	TERMOK

	;--- Para buscar chips musicales (v1.01)

_CHIPSSLT:	db	0
_SLTTST:	db	0

CHIPSSLT:	equ	_CHIPSSLT+#4000	;v1.01, era #BFFE
SLTTST:	equ	_SLTTST+#4000	;v1.01, era #BFFD


OCU_F:	;

BUFNREP:	equ	#4000
SAVBUF:	equ	BUFNREP+64
BUFER:	equ	#8000
FCBS:	equ	OCU_F

;BUFNREP:          ;
;FCBS:             equ     BUFNREP+64       ;FCBS al final de la parte oculta
;BUFER:            equ     #8000            ;El bufer es el SL 2
;SAVBUF:           equ     FCBS+(MAXFIL*TAMFCB) ;Espacio para guardar el bufer
