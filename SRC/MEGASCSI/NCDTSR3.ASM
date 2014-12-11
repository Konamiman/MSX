;NestorCDPlayer: music CD control program for MEGASCSI
;It's a TSR program. Once installed, music CD is controlled with various keys
;(see usage help strings)

;================================================= 	
	
	;NestorCDPlayer 1.01
	;Atensao: queda residente y controla el CD
	;con CTRL/SHIFT + CODE/GRAPH!
	;Si es que soy la ley!! (yo, el Konami Man)

;******************************************************
;*                                                    *
;*                 MACROS, CONSTANTES                 *
;*                                                    *
;******************************************************

IDNCD:	equ	34	;ID para la BIOS extendida
IDCD:	equ	1

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

	;*** GANCHOS Y VARIABLES DEL SISTEMA

ENDTPA:	equ	#0006
HIGHMEM:	equ	#F349
H_CHGE:	equ	#FDC2
H_TIMI:	equ	#FD9F
H_STKE:	equ	#FEDA
H_INIP:	equ	#FDC7
EXTBIO:	equ	#FFCA
CALSLT:	equ	#001C
CGPBAS:	equ	#F924	;Actual dir. gen. de caracteres (VRAM)
LDIRMV:	equ	#005C	;Copia de memoria a VRAM
ENASLT:	equ	#0024
KANAST:	equ	#FCAC
NEWKEY:	equ	#FBE5
CAPST:	equ	#FCAB
CHGCAP:	equ	#0132
MODE:	equ	#FAFC
CHPUT:	equ	#00A2
RDSLT:	equ	#000C
WRPSG:	equ	#0093
RDPSG:	equ	#0096
EXPTBL:	equ	#FCC1
SETWRT:	equ	#0053

	;*** FUNCIONES DEL DOS

DOSVER:	equ	#6F
STROUT:	equ	#09
TERM:	equ	#62
SENV:	equ	#6C


;******************************************************
;*                                                    *
;*                 INSTALACION                        *
;*                                                    *
;******************************************************

	org	#100

;--- Comprobamos que hay suficiente TPA (#0006 >= #C200)

	ld	a,(ENDTPA+1)
	cp	#C2
	jr	nc,OKTPA

	ld	de,NOTPAS
	ld	c,STROUT
	dos
	ret
NOTPAS:	db	13,10,"ERROR: Too scare TPA.",13,10
	db	"NestorCDPlayer 1.01 not installed.",13,10,"$"
OKTPA:	;

;--- Comprobamos si NCDP ya esta instalado,
;    en ese caso pasamos a desinstalar si el parametro es "U"

	ld	de,256*IDNCD+1
	xor	a
	call	EXTBIO
	cp	IDNCD
	jpi	DESINST

;--- Buscamos el slot y el ID del CD-ROM a controlar

	ld	hl,#FB22
	ld	b,4

BUCSLOT:	push	hl,bc	;Bucle de busqueda de Mega-SCSI
	ld	a,(hl)	;a traves de los cuatro controladores
	or	a
	jr	z,FIN_NOMEGA
	call	CHK_SLOT
	call	nc,CHK_IDBUC
	pop	bc,hl
	inc	hl
	inc	hl
	djnz	BUCSLOT
	jr	FIN_NOMEGA

CHK_IDBUC:	ld	b,8	;Para cada MegaSCSI: busqueda de un CD
BUCID:	push	bc	;a traves de todos los IDs

	ld	a,b	;ID normal -> ID raro para el MegaSCSI
	dec	a
	cpl
	and	7
	ld	b,a
	inc	b
	ld	a,%10000000
BUCID2:	rlc	a
	djnz	BUCID2
	ld	(DATOS),a

	ld	ix,#7FCC
	ld	a,(hl)
	ld	iyh,a
	ld	a,#C0
	push	hl
	ld	hl,DATOS	;Comando INQUIRY para todos los IDs
	call	CALSLT
	pop	hl
	jr	c,ENDBUCID

	ld	a,(DAT)
	cp	5	;Tipo de dispositivo 5 = CD-ROM
	jr	z,CD_FOUND
ENDBUCID:	pop	bc
	djnz	BUCID
	ret

CD_FOUND:	ld	a,(DATOS)
	ld	(DATOS000B),a
	ld	(DATOS000F),a
	pop	bc
	ld	a,(hl)
	ld	(MGSLOT000B),a
	ld	(MGSLOT000F),a
	jp	OKSRCHCD

FIN_NOMEGA:	ld	de,NOMEGA_S
	ld	c,STROUT
	dos
	ld	c,0
	dos
NOMEGA_S:	db	13,10,"ERROR: No MegaSCSI or no CD-ROM drive found.",13,10
	db	"NestorCDPlayer 1.01 not installed.",13,10,"$"

DATOS:	db	0,0
	dw	COM
	dw	DAT
	dw	STA
	dw	MES
COM:	db	#12,0,0,0,1,0
DAT:	db	0
STA:	db	0
MES:	db	0
OKSRCHCD:	;

;--- Copiamos los antiguos ganchos en la futura rutina de salto

	di

	ld	hl,H_TIMI
	ld	de,OLDTIM000F
	ld	bc,5
	ldir

	ld	hl,EXTBIO
	ld	de,OLDBIO000F
	ld	bc,5
	ldir

	ld	hl,OLDTIM000F
	ld	de,OLDTIM000B
	ld	bc,5*2
	ldir

;--- Reservamos memoria en la pagina 3 para la rutina de salto y la copiamos

	ld	hl,(HIGHMEM)	;Guardamos antiguo HIGHMEM,
	ld	(OLDHM000F),hl	;y establecemos el nuevo
	ld	(OLDHM000B),hl
	ld	bc,ENDRES000F-INIRES000F
	or	a
	sbc	hl,bc
	ld	(HIGHMEM),hl
	ld	(NEWHM000F),hl
	ld	(NEWHM000B),hl

	ld	hl,RESCODE1	;Copiamos la rutina de salto a pag. 3 !!
	ld	de,RESCODE2
	ld	ix,(NEWHM000F)
	ld	bc,ENDRES000F-INIRES000F
	call	REUBICA

;--- Establecemos los nuevos ganchos

	di

	ld	hl,(HIGHMEM)
	ld	a,#C3

	ld	(H_TIMI),a
	ld	(H_TIMI+1),hl

	inc	hl
	inc	hl
	inc	hl
	ld	(EXTBIO),a
	ld	(EXTBIO+1),hl

;--- Finalizacion de la instalacion

	ei

	ld	hl,NCDPENV	;Establecemos variable NCDPLAYER
	ld	de,NCDPVAL
	ld	c,SENV
	call	5

	ld	de,INSSTR
	ld	c,STROUT
	dos
	ld	hl,#0081
	jp	CALSYS

INSSTR:	db	13,10,"NestorCDPlayer #1.01 - by Konami Man, 3-1999",13,10
	db	"Installed: CD is controlled with CTRL/SHIFT + CODE/GRAPH!",13,10
HELPSTR:	db	13,10,"CTRL+CODE:   Pause / Resume CD replay",13,10
	db	"CTRL+GRAPH:  Stop CD replay / Extract CD if already stopped",13,10
	db	"SHIFT+CODE:  Restart in next track",13,10
	db	"SHIFT+GRAPH: Restart current track / Previous track if track time < 4 sec",13,10,13,10
	db	"CTRL+SHIFT+SELECT: Activate / Desactivate NestorCDPlayer (NOT uninstall)",13,10
	db	"NCDPLAY U to uninstall.",13,10,"$"

NCDPENV:	db	"NCDPLAYER",0
NCDPVAL:	db	"1.01"
NULVAL:	db	0

;--- Desinstalacion si el parametro es "U"

DESINST:	ld	hl,#0081	;Linea de comando: vamos pasando espacios
BUSCAU:	ld	a,(hl)
	inc	hl
	cp	32
	jri	BUSCAU
	or	a
	jr	nz,CHKU

NODES:	ld	de,YAINSTR	;Si encontramos un 0: no hay parametros
	ld	c,STROUT
	dos
	ld	de,HELPSTR
	ld	c,STROUT
	dos
	ret

YAINSTR:	db	13,10,"NestorCDPlayer #1.01 already installed.",13,10,"$"

CHKU:	and	%11011111	;Si encontramos algo tiene que ser "U"
	cp	"U"
	jr	nz,NODES
	ld	(POS2COM),hl	;Guardamos posicion posterior a la "U"

	ld	de,IDNCD*256+1	;Comprobamos que HIGHMEM actual es igual
	call	EXTBIO	;al HIGHMEM cuando instalamos NestCD.
	ld	de,(HIGHMEM)	;Si no, no podemos desinstalar.
	or	a
	sbc	hl,de
	ld	a,h
	or	l
	jp	z,OKHMEM

	ld	de,NOKHMEMS
	ld	c,STROUT
	dos
	ret

NOKHMEMS:	db	13,10,"ERROR: Other resident program was installed after NestorCDPlayer.",13,10
	db	"Please remove it and try again to uninstall NestorCDPlayer.",13,10,"$"

OKHMEM:	ld	hl,(HIGHMEM)
	ld	bc,3*2
	add	hl,bc
	ld	bc,5
	di

	ld	(HIGHMEM),ix

	ld	de,H_TIMI	;Retauramos ganchos
	call	RESTHOOK
	ld	de,EXTBIO
	call	RESTHOOK

	ld	hl,NCDPENV	;Borramos variable NESTAC
	ld	de,NULVAL
	ld	c,SENV
	call	5

	ld	de,DESSTR	;Terminamos!
	ld	c,STROUT
	dos
	ld	hl,(POS2COM)
	jp	CALSYS

DESSTR:	db	13,10,"NestorCDPlayer #1.01 uninstalled.",13,10,"$"
POS2COM:	dw	0

RESTHOOK:	ldir
	ld	bc,5
	ret

;--- Subrutina de reubicacion de un codigo
;    Entrada: HL = Primera copia
;             DE = Segunda copia
;             IX = Destino
;             BC = Longitud

REUBICA:	push	bc,de,hl	;Primero copiamos el codigo tal cual
	push	ix	;(HL a IX, lon. BC)
	pop	de
	ldir
	pop	hl,de

	push	de
	pop	iy	;IY = Segunda copia
	ld	b,h
	ld	c,l
	push	ix
	pop	hl
	or	a
	sbc	hl,bc
	ld	b,h
	ld	c,l	;BC = Distancia a sumar (IX - HL)

	exx
	pop	bc
	exx

	;En este punto: IX = Destino
	;               IY = Segunda copia
	;               BC = Distancia a sumar (nueva dir - 1a copia)
	;               BC'= Longitud

BUCLE:	ld	a,(ix)
	cp	(iy)
	jr	z,NEXT	;Si no hay diferencias pasamos al siguiente byte

	ld	l,a
	ld	h,(ix+1)	;HL = Dato a cambiar
	add	hl,bc	;HL = Dato cambiado
	ld	(ix),l	;IX = Direccion del dato a cambiar
	ld	(ix+1),h

	call	CHKCOMP
	jr	z,FINREUB	;Si: sacabo!

	inc	ix
	inc	iy
NEXT:	inc	ix	;Siguiente byte a comparar
	inc	iy	;(si hemos sutituido, hay que incrementar dos veces)
	call	CHKCOMP
	jr	nz,BUCLE

FINREUB	ret

CHKCOMP:	exx
	dec	bc	;Decrementamos contador, y si llega a 0
	ld	a,b	;volvemos con Z=1
	or	c
	exx
	ret

;--- Rutina de salto al BASIC y CALL SYSTEM.
;    Previamente se copia el comando a ser ejecutado tras el _SYSTEM,
;    a partir de la posicion de la linea de comando entrada en HL.

CALSYS:	ld	ix,SysCom

BUCSYSCOM:	ld	a,(hl)	;Buscamos el primer caracter, o el 0
	inc	hl
	or	a
	jr	z,OKBSC
	cp	" "
	jr	z,BUCSYSCOM
	dec	hl

BUCSYS2:	ld	(ix),a	;Copiamos caravteres hasta encontrar
	inc	ix	;el 0
	inc	hl
	ld	a,(hl)
	cp	"&"
	jr	nz,NOANGLUNO
	ld	a,"^"
NOANGLUNO:	or	a
	jr	nz,BUCSYS2

	ld	(ix),34
	ld	(ix+1),")"
	ld	(ix+2),0
OKBSC:	;

	;CALL SYSTEM propiamente dicho

	ld	hl,SystemProg
	ld	de,08000h
	ld	bc,0200h
	ldir
	jp	08000h
SystemProg:
	ld	a,(0FCC1h)
	push	af
	ld	h,0
	call	024h
	pop	af
	ld	h,040h
	call	024h
	xor	a
	ld	hl,0F41Fh
	ld	(0F860h),hl
	ld	hl,0F423h
	ld	(0F41Fh),hl
	ld	(hl),a
	ld	hl,0F52Ch
	ld	(0F421h),hl
	ld	(hl),a
	ld	hl,0F42Ch
	ld	(0F862h),hl
	ld	hl,08030h
	jp	04601h

SysTxT:	defb	03Ah,0CAh
	defb	"SYSTEM(",34
SysCom:	db	34,")"
	defb	0,01Ah

;--- Comprobacion de la presencia de un MegaSCSI en un slot
;    Entrada:  A = Slot a comprobar
;    Salida:   Cy = 0 si hay un MegaSCSI
;    Modifica: AF

CHK_SLOT:	;ld      a,(SLOT)
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


;******************************************************
;*                                                    *
;*            PARTE RESIDENTE EN PAG. 3               *
;*                                                    *
;******************************************************

PARTRES:	macro

INIRES@sym:	;
NEWTIM@sym:	jp	_NEWTIM@sym
NEWBIO@sym:	jp	_NEWBIO@sym

OLDTIM@sym:	ds	5
OLDBIO@sym:	ds	5

;--- Nuevo gancho H_TIMI

_NEWTIM@sym:	di
	call	TODOPUSH@sym

	ld	a,(KANAST)	;Guarda estado de KANA y el led
	ld	(OLDKANA@sym),a
	ld	a,(MODE)
	ld	(OLDMODE@sym),a
	ld	a,15
	out	(#A0),a
	in	a,(#A2)
	ld	(OLDPSG@sym),a

	ld	a,(#FBEB)
;FBEB: 6=> F3      F2     F1     CODE   CAPS   GRPH   CTRL   SHIFT
	and	%00010111

	cp	%00010100	;------->
	jr	nz,NODES@sym
	ld	e,a
	ld	a,(#FBEC)
	cp	%10111111
	ld	a,e
	jr	nz,NODES@sym
	call	PREVKEY@sym
	jp	c,ENDTIM@sym
	ld	a,(ACTIV@sym)	;Activa/desactiva programa
	cpl		;                ;con CTRL+GRAPH+SELECT
	ld	(ACTIV@sym),a
	jp	ENDTIM@sym
NODES@sym:	ld	e,a
	ld	a,(ACTIV@sym)
	or	a
	jp	z,NADAPUL@sym
	ld	a,e
	;                        ;-------<

	cp	%00000101
	jr	z,CT_CD@sym
	cp	%00010001
	jr	z,CT_GR@sym
	cp	%00000110
	jp	z,SH_CD@sym
	cp	%00010010
	jp	z,SH_GR@sym

	;cp      %00010101        ;------->
	;jr      nz,NOZIP@sym
	;ld      a,(#FBEC)
	;bit     6,a
	;jr      nz,NOZIP@sym
	;ld      a,(DATOS@sym)    ;BONUS: Extraccion de un zipkete (ID 5)
	;push    af               ;con CTRL + SELECT!! ;-)
	;ld      a,%00100000
	;ld      (DATOS@sym),a
	;ld      hl,EJECT@sym
	;call    EJECOM@sym
	;pop     af
	;ld      (DATOS@sym),a
	;jp      ENDTIM@sym
NOZIP@sym:	;                        ;-------<

NADAPUL@sym:	xor	a
	ld	(PULSADO@sym),a
	jp	ENDTIM@sym

	;--- CTRL+CODE: Pausa o continua la reproduccion

CT_CD@sym:	call	PREVKEY@sym
	jp	c,ENDTIM@sym

	ld	hl,READ_Q@sym
	call	EJECOM@sym
	jp	c,ENDTIMCK@sym

	ld	a,(DATA@sym+1)
	cp	#11
	jr	z,PAU@sym
	cp	#12
	jr	z,UNPAU@sym

STPLAY@sym:	ld	a,1
	ld	(PLAYALL@sym+4),a
	ld	hl,PLAYALL@sym
	jr	ENDT2@sym

PAU@sym:	ld	a,0
	jr	OKBIT@sym
UNPAU@sym:	ld	a,1
OKBIT@sym:	ld	(PAUCONT@sym+8),a
	ld	hl,PAUCONT@sym

ENDT2@sym:	call	EJECOM@sym
	jp	ENDTIMCK@sym

	;--- CTRL + GRAPH: Para el CD o lo saca

CT_GR@sym:	call	PREVKEY@sym
	jp	c,ENDTIM@sym

	ld	hl,READ_Q@sym
	call	EJECOM@sym
	jp	c,ENDTIM@sym

	ld	a,(DATA@sym+1)
	ld	hl,STOP@sym
	cp	#11
	jr	z,OKCTGR@sym
	cp	#12
	jr	z,OKCTGR@sym
	ld	hl,EJECT@sym
OKCTGR@sym:	call	EJECOM@sym
	jp	ENDTIM@sym

	;--- SHIFT+CODE: Siguiente cancion

SH_CD@sym:	call	PREVKEY@sym
	jp	c,ENDTIM@sym
	ld	hl,TOC@sym
	call	EJECOM@sym
	jp	c,ENDTIMSK@sym
	ld	hl,(DATA@sym+2)
	push	hl

	ld	hl,READ_Q@sym
	call	EJECOM@sym
	jp	c,ENDTIMSK@sym
	ld	a,(DATA@sym+6)
	inc	a

	pop	hl
	cp	h
	jrmni	OKSIG@sym
	ld	a,l
OKSIG@sym:	ld	(PLAYALL@sym+4),a
	ld	hl,PLAYALL@sym
	call	EJECOM@sym
	jp	ENDTIMSK@sym

	;--- SHIFT+GRAPH: Cancion anterior

SH_GR@sym:	call	PREVKEY@sym
	jp	c,ENDTIM@sym
	ld	hl,TOC@sym
	call	EJECOM@sym
	jp	c,ENDTIM@sym
	ld	hl,(DATA@sym+2)
	push	hl

	ld	hl,READ_Q@sym
	call	EJECOM@sym
	jr	c,ENDTIM@sym
	pop	hl
	ld	a,(DATA@sym+6)
	ld	(PLAYALL@sym+4),a
	ld	ix,DATA@sym+12
	ld	a,(ix)
	or	(ix+1)
	or	(ix+2)
	jr	nz,OKPREV@sym
	ld	a,(ix+3)
	cp	2
	jrmn	OKPREV@sym

	ld	a,(DATA@sym+6)
	dec	a
	cp	l
	jrmyi	OKPREV2@sym
	ld	a,h
OKPREV2@sym:	ld	(PLAYALL@sym+4),a
OKPREV@sym:	ld	hl,PLAYALL@sym
	call	EJECOM@sym
	jr	ENDTIM@sym

	;--- Subrutinas y datos

EJECOM@sym:	ld	(COM@sym),hl	;Ejecuta un comando SCSI
	ld	a,#c0
	ld	hl,DATOS@sym
	ld	ix,#7FCC
	ld	iy,(MGSLOT@sym-1)
	call	CALSLT
	ret

ENDTIMSK@sym:	;
ENDTIMCK@sym:	call	TODOPOP@sym
	call	OLDTIM@sym
	push	af
	ld	a,(OLDKANA@sym)
	ld	(KANAST),a
	ld	a,(OLDMODE@sym)
	ld	(MODE),a
	ld	a,15
	out	(#A0),a
	ld	a,(OLDPSG@sym)
	out	(#A1),a
	pop	af
	ei
	ret

ENDTIM@sym:	call	TODOPOP@sym
	ei
	jp	OLDTIM@sym

DATOS@sym:	db	%00000010,0
COM@sym:	dw	0
	dw	DATA@sym
	dw	STATUS@sym
	dw	MESSAGE@sym

READ_Q@sym	db	#42,0,#40,1,0,0,0,0,16,0	;Lee sub-canal Q
PAUCONT@sym:	db	#4B,0,0,0,0,0,0,0,1,0	;Pausa / continuacion
STOP@sym:	db	#45,0,0,0,0,0,0,0,1,0	;Reproduce 1 sector -> para el CD
EJECT@sym:	db	#1B,0,0,0,%10,0	;       ;Extraccion
PLAYALL@sym:	db	#48,0,0,0,1,1,0,99,99,0	;Playeado de todas las pistas
TOC@sym:	db	#43,0,0,0,0,0,0,0,4,0	;Leer TOC

AQUI@sym:	ds	18	;Espacio para los datos devueltos
MGSLOT@sym:	db	0	;por el CD-ROM
ACTIV@sym:	db	#FF
OLDKANA@sym:	db	0
OLDMODE@sym:	db	0
OLDPSG@sym:	db	0

PREVKEY@sym:	ld	a,(PULSADO@sym)	;Evita que la pulsacion de una tecla
	cp	#FF	;sea detectada infinitas veces
	scf
	ret	z
	ld	a,#FF
	ld	(PULSADO@sym),a
	or	a
	ret
PULSADO@sym:	db	0

DATA@sym:	equ	AQUI@sym
STATUS@sym:	equ	AQUI@sym+16
MESSAGE@sym:	equ	AQUI@sym+17

;--- Nuevo EXTBIO:
;    Entrada: D = IDNCD
;             E = 1
;    Salida:  HL= NewHIGHMEM
;             IX= OldHIGHMEM
;             A = IDNCD

_NEWBIO@sym:	push	af	;BIOS extendida. Identificador: IDNCD
	ld	a,d	;Modifica IX, IY y alternativos.
	cp	IDNCD	;Nunca modifica DE.
	jr	nz,NOBIOS@sym
	ld	a,e
	cp	1
	jr	z,OKBIOS@sym
NOBIOS@sym:	pop	af
	jp	OLDBIO@sym

OKBIOS@sym:	pop	af
	ld	hl,(NEWHM@sym)
	ld	ix,(OLDHM@sym)
	ld	a,IDNCD
	ret

NEWHM@sym:	dw	0
OLDHM@sym:	dw	0

;--- Subrutinas para guardar y recuperar todos los registros en la pila

TODOPUSH@sym:	ld	(SAVEHL@sym),hl
	ex	(sp),hl
	push	af,bc,de,ix,iy
	exx
	ex	af,af
	push	af,bc,de,hl
	exx
	ex	af,af
	dec	sp
	dec	sp
	ex	(sp),hl
	ld	hl,(SAVEHL@sym)
	ret
SAVEHL@sym:	equ	DATA@sym

TODOPOP@sym:	ex	(sp),hl
	inc	sp
	inc	sp
	exx
	ex	af,af
	pop	hl,de,bc,af
	exx
	ex	af,af
	pop	iy,ix,de,bc,af
	ex	(sp),hl
	ret

ENDRES@sym:	;                        ;Fin de la parte residente en pagina 3
	endm

RESCODE1:	PARTRES
RESCODE2:	PARTRES

;FBE5 NEWKEY (11): 0=> 7       6      5      4      3      2      1      0
;            FBE6: 1=> ;       ]      [      \      =      -      9      8
;  Dit is    FBE7: 2=> B       A      ACCENT /      .      ,      `      '
;    de      FBE8: 3=> J       I      H      G      F      E      D      C
;  Europese  FBE9: 4=> R       Q      P      O      N      M      L      K
;   versie   FBEA: 5=> Z       Y      X      W      V      U      T      S
;            FBEB: 6=> F3      F2     F1     CODE   CAPS   GRPH   CTRL   SHIFT
;            FBEC: 7=> RET     SEL    BS     STOP   TAB    ESC    F5     F4
;            FBED: 8=> RIGHT   DOWN   UP     LEFT   DEL    INS    HOME   SPACE
;            FBEE: 9=> 4       3      2      1      0      /      +      *
;            FBEF:10-> .       ,      -      9      8      7      6      5

LONRES:	equ	ENDRES000B-INIRES000B
