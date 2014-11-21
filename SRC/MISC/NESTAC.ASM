;NestorAcentos - resident tool that allows to write
;in Spanish (with accents) in computers with japanese keyboard.

;======================================

	;NestorAcentos #1.1
	;Empezado  12-12-98
	;Terminado 19-12-98
	;Version 1.11: 24-2-99
	;Version 1.12: 18-3-99

;******************************************************
;*                                                    *
;*                 MACROS, CONSTANTES                 *
;*                                                    *
;******************************************************


IDNAC:	equ	34	;ID para la BIOS extendida

; Si estas constantes estan a 0, no se parcheara el gancho correspondiente
; (solo para pruebas!!)

TIMI:	equ	1
INIP:	equ	1
CHGE:	equ	1
EXTB:	equ	1

; Si MBSET=1, NestorAcentos establecera el juego de caracteres Moonblaster.
; Si MBSET=0, el juego estandar europeo.

MBSET:	equ	0
	;

; Estas son un invento mio. (-v-)v

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

;--- Comprobamos presencia del DOS 2

	ld	c,DOSVER	;DOS 2?
	dos
	ld	a,b
	cp	2
	jrmyi	OKDOS2

NODOS2:	ld	de,NOD2STR
	ld	c,STROUT
	dos
	ret
NOD2STR:	db	13,10,"NestorAcentos #1.12 - DOS 2 required!",13,10,"$"
OKDOS2:	;

;--- Comprobamos si el teclado es japones

	ld	a,(EXPTBL)
	ld	hl,#002C
	call	RDSLT
	and	%111
	or	a
	jr	z,OKJAPK

NOJAPK:	ld	de,NOJKSTR
	ld	c,STROUT
	dos
FIN:	ld	b,0
	ld	c,TERM
	dos
	ret
NOJKSTR:	db	13,10,"ERROR: japanese keyboard not found.",13,10
	db	"NestorAcentos #1.12 not installed.",13,10,"$"
OKJAPK:	;

;--- Comprobamos que hay suficiente TPA (#0006 >= #C200)

	ld	a,(ENDTPA+1)
	cp	#C2
	jr	nc,OKTPA

	ld	de,NOTPAS
	ld	c,STROUT
	dos
	jp	FIN
NOTPAS:	db	13,10,"ERROR: too small TPA (end of TPA must be at least #C200).",13,10
	db	"NestorAcentos #1.12 not installed.",13,10,"$"
OKTPA:	;


;--- Obtencion de la tabla de rutinas de soporte del mapeador de memoria

	ld	de,#0402
	call	EXTBIO
	ld	a,b	;de paso establecemos el slot en la
	and	%10001111	;futura rutina de salto de pag. 3
	ld	(RESLOT000F),a
	ld	(RESLOT000E),a
	ld	de,ALL_SEG
	ld	bc,#30
	ldir

;--- Comprobamos si NA ya esta instalado,
;    en ese caso pasamos a desinstalar si el parametro es "U"

	ld	de,256*IDNAC
	xor	a
	call	EXTBIO
	cp	IDNAC
	jpi	DESINST

;--- Comienza la instalacion: reservamos un segmento de RAM

	ld	b,0	;Reservamos un segmento de sistema
	ld	a,1	;en el mapeador primario
	call	ALL_SEG
	jp	nc,OKRESEG
	ld	de,NOFSTR
	ld	c,STROUT
	dos
	jp	FIN

NOFSTR:	db	13,10,"ERROR: no free segment on primary mapper.",13,10
	db	"NestorAcentos #1.12 not installed.",13,10,"$"

OKRESEG:	ld	(RESEG000F),a
	ld	(RESEG000E),a

;--- Copiamos los antiguos ganchos en la futura rutina de salto

	di

	ld	hl,H_CHGE	;Copiamos antiguos ganchos
	ld	de,OLDCHG000F	;H_CHGE, H_TIMI y EXTBIOS
	ld	bc,5
	ldir

	ld	hl,H_TIMI
	ld	de,OLDTIM000F
	ld	bc,5
	ldir

	ld	hl,H_INIP
	ld	de,OLDINI000F
	ld	bc,5
	ldir

	ld	hl,EXTBIO
	ld	de,OLDBIO000F
	ld	bc,5
	ldir

	ld	hl,OLDTIM000F
	ld	de,OLDTIM000E
	ld	bc,5*4
	ldir

;--- Reservamos memoria en la pagina 3 para la rutina de salto y la copiamos

	ld	hl,(HIGHMEM)	;Guardamos antiguo HIGHMEM,
	ld	(OLDHM000F),hl	;y establecemos el nuevo
	ld	(OLDHM000E),hl
	ld	bc,ENDRES000F-INIRES000F
	or	a
	sbc	hl,bc
	ld	(HIGHMEM),hl
	ld	(NEWHM000F),hl
	ld	(NEWHM000E),hl

	ld	hl,(CAL_SEG+1)	;Copiamos entrada a CAL_SEG
	ld	(CAL_SEG000F+1),hl
	ld	(CAL_SEG000E+1),hl

	ld	hl,RESCODE1	;Copiamos la rutina de salto a pag. 3 !!
	ld	de,RESCODE2
	ld	ix,(NEWHM000F)
	ld	bc,ENDRES000F-INIRES000F
	call	REUBICA

;--- Copiamos la parte residente en el segmento que acabamos de reservar

	call	GET_P2	;Copiamos la parte residente
	push	af	;en el segmento
	ld	a,(RESEG000F)
	call	PUT_P2
	ld	hl,PARTRE2
	ld	de,#8000
	ld	bc,PARTRE2!-#8000
	ldir
	pop	af
	call	PUT_P2

;--- Establecemos los nuevos ganchos

	di

	ld	hl,(HIGHMEM)
	ld	a,#C3

	if	TIMI
	ld	(H_TIMI),a
	ld	(H_TIMI+1),hl
	endif

	inc	hl	;Los nuevos destinos de los ganchos
	inc	hl	;estan situados de forma consecutiva
	inc	hl
	if	INIP
	ld	(H_INIP),a
	ld	(H_INIP+1),hl
	endif

	inc	hl
	inc	hl
	inc	hl
	if	CHGE
	ld	(H_CHGE),a
	ld	(H_CHGE+1),hl
	endif

	inc	hl
	inc	hl
	inc	hl
	if	EXTB
	ld	(EXTBIO),a
	ld	(EXTBIO+1),hl
	endif

;--- Finalizacion de la instalacion

	ei

	ld	hl,NESTENV	;Establecemos variable NESTAC como 1.12
	ld	de,NESTVAL
	ld	c,SENV
	call	5

	ld	de,INSSTR
	ld	c,STROUT
	dos
	call	INIPAT
	ld	hl,#0081
	jp	CALSYS

INSSTR:	db	13,10,"NestorAcentos #1.12 - by Konami Man, 12-1998",13,10
	db	"Installed: KANA key is now ACCENT key!",13,10,"$"

NESTENV:	db	"NESTAC",0
NESTVAL:	db	"1.12"
NULVAL:	db	0

;--- Desinstalacion si el parametro es "U"

DESINST:	ld	hl,#0081	;Linea de comando: vamos pasando espacios
BUSCAU:	ld	a,(hl)
	inc	hl
	cp	32
	jri	BUSCAU
	or	a
	jr	nz,CHKU

NODES:	call	INIPAT
	ld	de,YAINSTR	;Si encontramos un 0: no hay parametros
	ld	c,STROUT
	dos
	jp	FIN

YAINSTR:	db	13,10,"NestorAcentos #1.12 already installed.",13,10
	db	"NESTAC U to uninstall.",13,10,"$"

CHKU:	and	%11011111	;Si encontramos algo tiene que ser "U"
	cp	"U"
	jr	nz,NODES
	ld	(POS2COM),hl	;Guardamos posicion posterior a la "U"

	ld	de,IDNAC*256	;Comprobamos que HIGHMEM actual es igual
	call	EXTBIO	;al HIGHMEM cuando instalamos NestAc.
	ld	de,(HIGHMEM)	;Si no, no podemos desinstalar.
	or	a
	sbc	hl,de
	ld	a,h
	or	l
	jp	z,OKHMEM

	ld	de,NOKHMEMS
	ld	c,STROUT
	dos
	jp	FIN

NOKHMEMS:	db	13,10,"ERROR: Other resident program was installed after NestorAcentos.",13,10
	db	"Please remove it and try again to uninstall NestorAcentos.",13,10,"$"

OKHMEM:	push	ix
	ld	a,c	;Liberamos el segmento
	call	FRE_SEG

	ld	hl,(HIGHMEM)
	ld	bc,12
	add	hl,bc
	ld	bc,5
	di

	pop	ix
	ld	(HIGHMEM),ix

	if	TIMI
	ld	de,H_TIMI	;Retauramos ganchos
	call	RESTHOOK
	else
	add	hl,bc
	endif
	if	INIP
	ld	de,H_INIP
	call	RESTHOOK
	else
	add	hl,bc
	endif
	if	CHGE
	ld	de,H_CHGE
	call	RESTHOOK
	else
	add	hl,bc
	endif
	if	EXTB
	ld	de,EXTBIO
	call	RESTHOOK
	else
	add	hl,bc
	endif

	ld	hl,NESTENV	;Borramos variable NESTAC
	ld	de,NULVAL
	ld	c,SENV
	call	5

	ld	de,DESSTR	;Terminamos!
	ld	c,STROUT
	dos
	call	INIPROM
	ld	hl,(POS2COM)
	jp	CALSYS

DESSTR:	db	13,10,"NestorAcentos #1.12 uninstalled.",13,10,"$"
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

;--- Inicializacion del juego de caracteres

INIPAT:	ld	de,IDNAC*256
	call	EXTBIO
	ld	a,c
	ld	iyh,a
	ld	ix,#8003
	call	CAL_SEG
	ret

;--- Inicializacion del juego de caracteres ROM (al desinstalar)

INIPROM:	ld	iy,(EXPTBL-1)	;Preparamos VDP para escritura
	ld	ix,SETWRT
	ld	hl,(CGPBAS)
	call	CALSLT

	ld	hl,(#F920)	;Bucle de lectura de ROM y escritura
	ld	bc,256*8	;en VRAM
BUCIPROM:	push	bc
	ld	a,(#F91F)
	call	RDSLT
	out	(#98),a
	inc	hl
	pop	bc
	dec	bc
	ld	a,b
	or	c
	ret	z
	jr	BUCIPROM

;--- Tabla de salto para las rutinas del mapeador

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


;******************************************************
;*                                                    *
;*            PARTE RESIDENTE EN PAG. 3               *
;*                                                    *
;******************************************************

PARTRES:	macro

INIRES@sym:	;
NEWTIM@sym:	jp	_NEWTIM@sym
NEWINI@sym:	jp	_NEWINI@sym
NEWCHG@sym:	jp	_NEWCHG@sym
NEWBIO@sym:	jp	_NEWBIO@sym

OLDTIM@sym:	ds	5
OLDINI@sym:	ds	5
OLDCHG@sym:	ds	5
OLDBIO@sym:	ds	5

;--- Nuevo gancho H_TIMI

_NEWTIM@sym:	di
	call	TODOPUSH@sym
	call	GETSLOT2@sym	;Guardamos el slot conectado en pag. 2
	push	af
	ld	b,a
	ld	a,(RESLOT@sym)
	;ld      (OLDSTACK@sym),sp
	;ld      sp,NEWSTACK@sym+100
	call	PUTSLOT2@sym	;Conectamos el slot si no es el que
	ld	iy,(RESEG@sym-1)	;ya hay puesto, y llamamos al segmento
	ld	ix,#8000
	call	CAL_SEG@sym
	;ld      sp,(OLDSTACK@sym)
	ld	a,(RESLOT@sym)
	ld	b,a
	pop	af
	call	PUTSLOT2@sym
	call	TODOPOP@sym
	jp	OLDTIM@sym	;Espacio para el antiguo gancho H_TIMI

;--- Nuevo gancho H_INIP

_NEWINI@sym:	di		;                ;Lo preparamos para que primero se
	ld	ix,(NEWHM@sym)	;ejecute INIP normalmente,
	pop	hl	;y luego nuestro gancho NEWINI2
	ld	bc,NEWINI2@sym-INIRES@sym
	add	ix,bc
	push	ix
	push	hl
	ret

NEWINI2@sym:	di
	call	TODOPUSH@sym	;El gancho para la inicializacion del
	call	GETSLOT2@sym	;juego de caracteres solo sera ejecutado
	ld	b,a	;si el slot conectado es el primario.
	ld	a,(RESLOT@sym)	;Esto se hace asi para evitar que el TED
	cp	b	;se cuelgue al salir.
	ld	iy,(RESEG@sym-1)
	ld	ix,#8003
	;ld      (OLDSTACK@sym),sp
	;ld      sp,NEWSTACK@sym+100
	call	z,CAL_SEG@sym
	;ld      sp,(OLDSTACK@sym)
	call	TODOPOP@sym
	jp	OLDINI@sym	;Espacio para el antiguo gancho H_INIP

;--- Nuevo gancho H_CHGE

_NEWCHG@sym:	di

	ld	(SAVIX@sym),ix	;Modificamos la pila de forma que
	ld	(SAVIY@sym),iy	;al terminar CHGET salte a NEWCHG2

	pop	ix,bc,de,hl
	ld	iy,NEWCHG2@sym
	push	iy,hl,de,bc,ix

	ld	ix,(SAVIX@sym)
	ld	iy,(SAVIY@sym)
	ei
	jp	OLDCHG@sym

NEWCHG2@sym:	di
	ld	(SAVEA@sym),a
	call	TODOPUSH@sym
	call	GETSLOT2@sym
	ld	(SL2@sym),a
	ld	b,a
	ld	a,(RESLOT@sym)
	;ld      (OLDSTACK@sym),sp
	;ld      sp,NEWSTACK@sym+100
	call	PUTSLOT2@sym
	ld	a,(SAVEA@sym)
	ld	l,a
	ld	iy,(RESEG@sym-1)
	ld	ix,#8006
	call	CAL_SEG@sym
	ld	a,l
	ld	(SAVEA@sym),a
	ld	a,(RESLOT@sym)
	ld	b,a
	ld	a,(SL2@sym)
	call	PUTSLOT2@sym
	;ld      sp,(OLDSTACK@sym)
	call	TODOPOP@sym
	ld	a,(SAVEA@sym)
	ret

SAVIX@sym:	ds	2
SAVIY@sym:	ds	2
SAVEA@sym:	ds	1
SL2@sym:	db	0

;--- Nuevo EXTBIO:
;    Entrada: D = IDNAC
;             E = 0
;    Salida:  HL= NewHIGHMEM
;             IX= OldHIGHMEM
;             B = Slot del segmento reservado
;             C = Segmento reservado
;             A = IDNAC

_NEWBIO@sym:	push	af	;BIOS extendida. Identificador: IDNAC
	ld	a,d	;Modifica IX, IY y alternativos.
	cp	IDNAC	;Nunca modifica DE.
	jr	nz,NOBIOS@sym
	ld	a,e
	or	a
	jr	z,OKBIOS@sym
NOBIOS@sym:	pop	af
	jp	OLDBIO@sym

OKBIOS@sym:	pop	af
	ld	hl,(NEWHM@sym)
	ld	ix,(OLDHM@sym)
	ld	a,(RESLOT@sym)
	ld	b,a
	ld	a,(RESEG@sym)
	ld	c,a
	ld	a,IDNAC
	ret
RESLOT@sym:	db	0
RESEG@sym:	db	0

CAL_SEG@sym:	jp	#0000
NEWHM@sym:	dw	0
OLDHM@sym:	dw	0
;OLDSTACK@sym: dw      0

;--- Subrutina para la obtencion del slot conectado en pagina 2

GETSLOT2@sym:	di
	exx
	in	a,(#A8)
	ld	e,a
	and	%00110000
	sra	a
	sra	a
	sra	a
	sra	a
	ld	c,a	;C = Slot
	ld	b,0
	ld	hl,EXPTBL
	add	hl,bc
	bit	7,(hl)
	jr	z,NOEXP@sym
EXP@sym:	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	and	%00110000
	sra	a
	sra	a
	or	c
	or	#80
	ld	c,a
NOEXP@sym:	ld	a,c
	exx
	ret

;--- Subrutina para la conexion del slot A en pag. 2 si es distinto de B

PUTSLOT2@sym:	cp	b
	ret	z
	ld	h,#80
	jp	ENASLT

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
SAVEHL@sym:	dw	0

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

;NEWSTACK@sym: ds      100

ENDRES@sym:	;                        ;Fin de la parte residente en pagina 3
	endm

RESCODE1:	PARTRES
RESCODE2:	PARTRES


;******************************************************
;*                                                    *
;*          PARTE RESIDENTE EN UN SEGMENTO            *
;*                                                    *
;******************************************************

PARTRE2:	org	#8000	;Se ejecutara en la pagina 2

	jp	RESTIM
	jp	RESINI
	jp	RESCHG


;-------------------------------------------------------------
;--- Gancho H_INIP: inicializacion del juego de caracteres ---
;-------------------------------------------------------------

RESINI:	ld	a,(EXPTBL)
	ld	iyh,a
	ld	ix,LDIRMV
	ld	hl,(CGPBAS)
	ex	de,hl
	ld	hl,ChStart
	ld	bc,256*8
	call	CALSLT
	ret


;---------------------------------------------
;--- Gancho H_TIMI: interrupcion del reloj ---
;---------------------------------------------

RESTIM:	xor	a
	ld	(KANAST),a
	ld	a,4
	ld	(MODE),a

	ld	a,(KANA)
	or	a
	jr	z,CHKANA

	ld	a,(CAPST)
	ld	b,a
	ld	a,(OLDCAPS)
	cp	b
	jri	CHKANA

	ld	(CAPST),a
	push	af
	ld	a,(EXPTBL)
	ld	iyh,a
	pop	af
	cpl
	ld	ix,CHGCAP
	call	CALSLT

	ld	a,(KANA)
	or	128
	ld	(KANA),a
	jr	FINTIM

CHKANA:	ld	a,(OLDKEY+6)
	bit	4,a
	jr	z,FINTIM

	ld	a,(NEWKEY+6)
	bit	4,a
	jr	nz,FINTIM

	ld	a,(KANA)
	or	a
	jr	nz,NOKANA
	or	1
	ld	(KANA),a
	ld	a,(NEWKEY+6)
	bit	0,a
	jr	nz,NOSHIFT
	ld	a,(KANA)
	or	2
	ld	(KANA),a
NOSHIFT:	ld	a,(NEWKEY+6)
	bit	1,a
	jr	nz,NOCTRL
	ld	a,(KANA)
	or	4
	ld	(KANA),a
NOCTRL:	ld	a,(NEWKEY+6)
	bit	2,a
	jr	nz,NOGRPH
	ld	a,(KANA)
	or	8
	ld	(KANA),a
NOGRPH:	ld	a,(NEWKEY+7)
	bit	6,a
	jr	nz,NOSEL
	ld	a,(KANA)
	or	16
	ld	(KANA),a
NOSEL:	jr	FINTIM

NOKANA:	xor	a
	ld	(KANA),a

FINTIM:	ld	a,(OLDKANA)
	ld	b,a
	ld	a,(KANA)
	cp	b
	call	nz,CHKLED

	ld	hl,NEWKEY
	ld	de,OLDKEY
	ld	bc,11
	ldir
	ld	a,(KANA)
	ld	(OLDKANA),a
	ld	a,(CAPST)
	ld	(OLDCAPS),a
	ret

CHKLED:	rrca		;Cambio del led del KANA
	or	%01111111
	cpl
	push	af

	ld	a,(EXPTBL)
	ld	iyh,a
	ld	ix,RDPSG
	ld	a,15
	call	CALSLT

	pop	bc
	and	%01111111
	or	b
	ld	e,a

	ld	a,(EXPTBL)
	ld	iyh,a
	ld	ix,WRPSG
	ld	a,15
	jp	CALSLT


;-----------------------------------------------
;--- Gancho H_CHGE: obtencion de un caracter ---
;-----------------------------------------------

RESCHG:	ld	d,l
	ld	hl,TABLA
	ld	bc,8
SIGUEBUS:	ld	a,(hl)
	or	a
	jp	z,NOFOUND
	cp	d
	jr	z,FOUNDAO
	add	hl,bc
	jr	SIGUEBUS

FOUNDAO:	xor	a
	ld	(KANAST),a
	ld	a,4
	ld	(MODE),a

	ld	a,(KANA)
	and	%01111111

	or	a	;Sin KANA
	ld	c,0
	jr	z,OKKEY

	cp	1	;KANA
	ld	c,1
	jr	z,OKKEY

	cp	3	;SHIFT + KANA
	ld	c,2
	jr	z,OKKEY

	cp	5
	ld	c,3	;CTRL + KANA
	jr	z,OKKEY

	cp	9	;GRPH + KANA
	ld	c,4
	jr	z,OKKEY

	cp	7	;CTRL + SHIFT + KANA
	ld	c,5
	jr	z,OKKEY

	cp	#B	;GRPH + SHIFT + KANA
	ld	c,6
	jr	z,OKKEY

	cp	#D	;GRPH + CTRL + KANA
	ld	c,7
	jr	z,OKKEY

NOKEY:	ld	c,0

OKKEY:	ld	a,(KANA)
	bit	7,a
	jr	nz,NORESKAN
RESKAN:	xor	a
	ld	(KANA),a

NORESKAN:	ld	b,0
	add	hl,bc
	ld	a,(hl)
	or	a
	jr	z,NOFOUND
	cp	33
	call	c,ESMENOR

FINCHG:	ld	l,a
	ret

ESMENOR:	or	64	;Si se trata de un caracter grafico,
	;                        ;primero hay que imprimir un codigo 1,
	;                        ;y luego el codigo del caracter
	push	af	;(almacenado con defecto 64)

	ld	a,(EXPTBL)
	ld	iyh,a
	ld	ix,CHPUT
	ld	a,1
	call	CALSLT

	pop	af
	ret

NOFOUND:	ld	l,d
	ld	a,(KANA)
	bit	7,a
	ret	nz
	xor	a
	ld	(KANA),a
	ret

	db	"CharSet"
TABLA:	db	"a",160,133,132,131,224,177,166
	db	"e",130,138,137,136,238,0,145
	db	"i",161,141,139,140,0,179,185
	db	"o",162,149,148,147,218,181,167
	db	"u",163,151,129,150,0,183,0
	db	"n",164,252,0,0,0,0,0
	db	"N",165,0,0,0,0,0,0
	db	"!",173,0,0,0,0,0,0
	db	"?",168,0,0,0,0,0,0
	db	">",242,175,203,0,0,0,0
	db	"<",243,174,204,0,0,0,0
	db	"+",22,241,31,0,0,0,0
	db	"=",240,247,246,0,0,0,0
	db	"1",26,0,0,0,0,0,0
	db	"2",17,171,253,0,0,0,0
	db	"3",27,186,0,0,0,0,0
	db	"4",20,172,0,0,0,0,0
	db	"5",16,0,0,0,0,0,0
	db	"6",19,0,0,0,0,0,0
	db	"7",24,169,0,0,0,0,0
	db	"8",18,0,0,0,0,0,0
	db	"9",25,170,0,0,0,0,0
	db	"-",23,0,0,0,0,0,0
	db	"/",29,0,0,0,0,0,0
	db	"*",30,15,0,0,0,0,0
	db	".",249,248,7,8,0,0,0
	db	"%",189,0,0,0,0,0,0
	db	"b",225,0,0,0,225,0,0
	db	"c",135,155,0,0,0,0,0
	db	"d",0,0,0,0,235,0,0
	db	"f",159,0,0,0,0,0,0
	db	"g",0,0,0,0,231,0,0
	db	"m",230,0,0,0,230,0,0
	db	"p",158,0,0,0,190,0,0
	db	"s",0,0,0,0,229,0,0
	db	"v",251,0,0,0,0,0,0
	db	"w",236,237,0,0,0,0,0
	db	"x",28,0,0,0,0,0,0
	db	"y",157,0,152,0,0,0,0
	db	"A",143,0,142,0,0,0,146
	db	"C",128,0,0,0,0,0,0
	db	"D",0,0,0,0,216,0,0
	db	"E",144,0,0,0,228,0,146
	db	"G",0,0,0,0,226,0,0
	db	"I",244,0,0,0,0,178,184
	db	"O",9,10,153,0,234,180,0
	db	"P",158,0,0,0,0,0,0
	db	"F",0,0,0,0,232,0,0
	db	"S",0,0,0,0,228,0,0
	db	"U",0,0,154,0,0,182,0
	db	"X",88,28,0,0,0,0,0
	db	"L",245,0,0,0,0,0,0
	db	"0",188,12,13,4,0,0,0
	db	34,215,0,0,0,0,0,0
	db	"Z",3,4,5,6,13,14,227

	db	0

OLDKEY:	ds	11
OLDCAPS:	db	0
KANA:	db	0
OLDKANA:	db	0

;FBE5 NEWKEY (11): 0=> 7       6      5      4      3      2      1      0
;        +1  FBE6: 1=> ;       ]      [      \      =      -      9      8
;        +2  FBE7: 2=> B       A      ACCENT /      .      ,      `      '
;        +3  FBE8: 3=> J       I      H      G      F      E      D      C
;        +4  FBE9: 4=> R       Q      P      O      N      M      L      K
;        +5  FBEA: 5=> Z       Y      X      W      V      U      T      S
;        +6  FBEB: 6=> F3      F2     F1     CODE   CAPS   GRPH   CTRL   SHIFT
;        +7  FBEC: 7=> RET     SEL    BS     STOP   TAB    ESC    F5     F4
;        +8  FBED: 8=> RIGHT   DOWN   UP     LEFT   DEL    INS    HOME   SPACE
;        +9  FBEE: 9=> 4       3      2      1      0      /      +      *
;       +10  FBEF:10-> .       ,      -      9      8      7      6      5

ChStart:	;

	if	MBSET=1

MbStart:	; 
OldMbCh0:	;      DB      #FC,#84,#84,#84,#84,#84,#84,#FC
MbChar0:	DB	#00,#00,#00,#00,#00,#00,#00,#00
MbChar1:	DB	#3C,#42,#A5,#81,#A5,#99,#42,#3C
MbChar2:	DB	#3C,#7E,#DB,#FF,#FF,#DB,#66,#3C
MbChar3:	DB	#6C,#FE,#FE,#FE,#7C,#38,#10,#00
MbChar4:	DB	#FF,#E7,#C3,#81,#C3,#E7,#FF,#FF
MbChar5:	DB	#10,#38,#54,#FE,#54,#10,#38,#00
MbChar6:	DB	#10,#38,#7C,#FE,#FE,#10,#38,#00
MbChar7:	DB	#00,#00,#00,#30,#30,#00,#00,#00
MbChar8:	DB	#FF,#FF,#FF,#E7,#E7,#FF,#FF,#FF
MbChar9:	DB	#30,#48,#84,#84,#84,#48,#30,#00
MbChar10:	DB	#CF,#B7,#7B,#7B,#7B,#B7,#CF,#FF
MbChar11:	DB	#00,#1C,#0C,#74,#90,#90,#90,#60
MbChar12:	DB	#38,#44,#44,#44,#38,#10,#7C,#10
MbChar13:	DB	#30,#28,#24,#24,#28,#20,#E0,#C0
MbChar14:	DB	#3C,#24,#3C,#24,#24,#E4,#DC,#18
MbChar15:	DB	#10,#54,#38,#EE,#38,#54,#10,#00
MbChar16:	DB	#10,#10,#10,#7C,#10,#10,#10,#10
EurCh17:	DB	#10,#10,#10,#FF,#00,#00,#00,#00
EurCh18:	DB	#00,#00,#00,#FF,#10,#10,#10,#10
EurCh19:	DB	#10,#10,#10,#F0,#10,#10,#10,#10
EurCh20:	DB	#10,#10,#10,#1F,#10,#10,#10,#10
EurCh21:	DB	#10,#10,#10,#FF,#10,#10,#10,#10
EurCh22:	DB	#10,#10,#10,#10,#10,#10,#10,#10
EurCh23:	DB	#00,#00,#00,#FF,#00,#00,#00,#00
EurCh24:	DB	#00,#00,#00,#1F,#10,#10,#10,#10
EurCh25:	DB	#00,#00,#00,#F0,#10,#10,#10,#10
EurCh26:	DB	#10,#10,#10,#1F,#00,#00,#00,#00
EurCh27:	DB	#10,#10,#10,#F0,#00,#00,#00,#00
;MbChar17:  DB      #CC,#CC,#84,#00,#FC,#00,#00,#00
;MbChar18:  DB      #00,#00,#FC,#00,#84,#CC,#CC,#CC
;MbChar19:  DB      #CC,#CC,#8C,#0C,#8C,#CC,#CC,#CC
;MbChar20:  DB      #CC,#CC,#C4,#C0,#C4,#CC,#CC,#CC
;MbChar21:  DB      #CC,#CC,#84,#00,#84,#CC,#CC,#CC
;MbChar22:  DB      #CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC
;MbChar23:  DB      #00,#00,#FF,#00,#FF,#00,#00,#00
;MbChar24:  DB      #00,#00,#7F,#C0,#C7,#CC,#CC,#CC
;MbChar25:  DB      #00,#00,#F8,#0C,#8C,#CC,#CC,#CC
;MbChar26:  DB      #CC,#CC,#C7,#C0,#7F,#00,#00,#00
;MbChar27:  DB      #CC,#CC,#8C,#0C,#F8,#00,#00,#00
MbChar28:	DB	#81,#42,#24,#18,#18,#24,#42,#81
MbChar29:	DB	#01,#02,#04,#08,#10,#20,#40,#80
MbChar30:	DB	#80,#40,#20,#10,#08,#04,#02,#01
MbChar31:	DB	#00,#10,#10,#FF,#10,#10,#00,#00
MbChar32:	DB	#00,#00,#00,#00,#00,#00,#00,#00
MbChar33:	DB	#30,#30,#30,#30,#30,#00,#30,#00
MbChar34:	DB	#28,#50,#A0,#00,#00,#00,#00,#00
MbChar35:	DB	#50,#50,#F8,#50,#F8,#50,#50,#00
MbChar36:	DB	#20,#F8,#A0,#F8,#28,#F8,#20,#00
MbChar37:	DB	#C8,#C8,#10,#20,#40,#98,#98,#00
MbChar38:	DB	#40,#A0,#40,#A8,#90,#98,#60,#00
MbChar39:	DB	#18,#30,#60,#00,#00,#00,#00,#00
MbChar40:	DB	#30,#60,#C0,#C0,#C0,#60,#30,#00
MbChar41:	DB	#30,#18,#0C,#0C,#0C,#18,#30,#00
MbChar42:	DB	#20,#A8,#70,#20,#70,#A8,#20,#00
MbChar43:	DB	#00,#20,#20,#F8,#20,#20,#00,#00
MbChar44:	DB	#00,#00,#00,#00,#00,#30,#30,#60
MbChar45:	DB	#00,#00,#00,#78,#00,#00,#00,#00
MbChar46:	DB	#00,#00,#00,#00,#00,#70,#70,#00
MbChar47:	DB	#00,#00,#08,#10,#20,#40,#80,#00
MbChar48:	DB	#70,#88,#98,#A8,#C8,#88,#70,#00
MbChar49:	DB	#20,#60,#E0,#20,#20,#20,#70,#00
MbChar50:	DB	#70,#88,#08,#10,#60,#80,#F8,#00
MbChar51:	DB	#F8,#88,#08,#30,#08,#88,#F8,#00
MbChar52:	DB	#10,#30,#50,#90,#F8,#10,#10,#00
MbChar53:	DB	#F8,#80,#80,#70,#08,#08,#F0,#00
MbChar54:	DB	#70,#88,#80,#F0,#88,#88,#70,#00
MbChar55:	DB	#F8,#88,#10,#20,#20,#20,#20,#00
MbChar56:	DB	#70,#88,#88,#70,#88,#88,#70,#00
MbChar57:	DB	#70,#88,#88,#78,#08,#88,#70,#00
MbChar58:	DB	#00,#00,#30,#00,#00,#30,#00,#00
MbChar59:	DB	#00,#00,#30,#00,#00,#30,#30,#60
MbChar60:	DB	#18,#30,#60,#C0,#60,#30,#18,#00
MbChar61:	DB	#00,#00,#F8,#00,#F8,#00,#00,#00
MbChar62:	DB	#C0,#60,#30,#18,#30,#60,#C0,#00
MbChar63:	DB	#78,#84,#08,#10,#20,#00,#20,#00
MbChar64:	DB	#70,#88,#08,#68,#A8,#A8,#70,#00
MbChar65:	DB	#70,#88,#88,#88,#F8,#88,#88,#00
MbChar66:	DB	#F0,#88,#88,#F0,#88,#88,#F0,#00
MbChar67:	DB	#70,#88,#80,#80,#80,#88,#70,#00
MbChar68:	DB	#F0,#88,#88,#88,#88,#88,#F0,#00
MbChar69:	DB	#78,#80,#80,#E0,#80,#80,#78,#00
MbChar70:	DB	#78,#80,#80,#F0,#80,#80,#80,#00
MbChar71:	DB	#70,#88,#80,#B8,#88,#88,#70,#00
MbChar72:	DB	#88,#88,#88,#F8,#88,#88,#88,#00
MbChar73:	DB	#70,#20,#20,#20,#20,#20,#70,#00
MbChar74:	DB	#08,#08,#08,#08,#08,#88,#70,#00
MbChar75:	DB	#88,#90,#A0,#C0,#A0,#A0,#98,#00
MbChar76:	DB	#80,#80,#80,#80,#80,#88,#F8,#00
MbChar77:	DB	#50,#A8,#A8,#88,#88,#88,#88,#00
MbChar78:	DB	#70,#88,#88,#88,#88,#88,#88,#00
MbChar79:	DB	#70,#88,#88,#88,#88,#88,#70,#00
MbChar80:	DB	#F0,#88,#88,#F0,#80,#80,#80,#00
MbChar81:	DB	#70,#88,#88,#88,#A8,#90,#68,#00
MbChar82:	DB	#F0,#88,#88,#F0,#90,#88,#88,#00
MbChar83:	DB	#70,#88,#80,#70,#08,#88,#70,#00
MbChar84:	DB	#F8,#20,#20,#20,#20,#20,#20,#00
MbChar85:	DB	#88,#88,#88,#88,#88,#88,#70,#00
MbChar86:	DB	#88,#88,#88,#88,#90,#A0,#40,#00
MbChar87:	DB	#88,#88,#88,#88,#A8,#A8,#50,#00
MbChar88:	DB	#88,#88,#50,#20,#50,#88,#88,#00
MbChar89:	DB	#88,#88,#88,#50,#20,#20,#20,#00
MbChar90:	DB	#F8,#08,#10,#20,#40,#80,#F8,#00
MbChar91:	DB	#70,#40,#40,#40,#40,#40,#70,#00
MbChar92:	DB	#00,#00,#80,#40,#20,#10,#08,#00
MbChar93:	DB	#70,#10,#10,#10,#10,#10,#70,#00
MbChar94:	DB	#20,#50,#88,#00,#00,#00,#00,#00
MbChar95:	DB	#00,#00,#00,#00,#00,#00,#00,#AB
MbChar96:	DB	#40,#20,#10,#00,#00,#00,#00,#00
MbChar97:	DB	#00,#00,#38,#48,#88,#98,#68,#00
MbChar98:	DB	#80,#80,#E0,#90,#88,#C8,#B0,#00
MbChar99:	DB	#00,#00,#70,#88,#80,#88,#70,#00
MbChar100:	DB	#08,#08,#38,#48,#88,#98,#68,#00
MbChar101:	DB	#00,#00,#70,#88,#B0,#C0,#78,#00
MbChar102:	DB	#70,#88,#80,#80,#E0,#80,#80,#00
MbChar103:	DB	#00,#00,#78,#88,#98,#68,#08,#F0
MbChar104:	DB	#80,#80,#F0,#88,#88,#88,#88,#00
MbChar105:	DB	#20,#00,#20,#20,#20,#20,#20,#00
MbChar106:	DB	#08,#00,#08,#08,#08,#08,#88,#70
MbChar107:	DB	#40,#40,#48,#50,#60,#50,#48,#00
MbChar108:	DB	#40,#40,#40,#40,#40,#40,#38,#00
MbChar109:	DB	#00,#00,#D0,#A8,#A8,#A8,#A8,#00
MbChar110:	DB	#00,#00,#F0,#88,#88,#88,#88,#00
MbChar111:	DB	#00,#00,#70,#88,#88,#88,#70,#00
MbChar112:	DB	#00,#00,#E0,#90,#88,#F0,#80,#80
MbChar113:	DB	#00,#00,#38,#48,#88,#78,#08,#08
MbChar114:	DB	#00,#00,#70,#88,#80,#80,#80,#00
MbChar115:	DB	#00,#00,#78,#80,#F0,#08,#F0,#00
MbChar116:	DB	#80,#80,#E0,#80,#80,#88,#70,#00
MbChar117:	DB	#00,#00,#88,#88,#88,#88,#70,#00
MbChar118:	DB	#00,#00,#88,#88,#88,#90,#60,#00
MbChar119:	DB	#00,#00,#88,#A8,#A8,#A8,#50,#00
MbChar120:	DB	#00,#00,#88,#50,#20,#50,#88,#00
MbChar121:	DB	#00,#00,#88,#88,#88,#78,#08,#F0
MbChar122:	DB	#00,#00,#F8,#10,#20,#40,#F8,#00
MbChar123:	DB	#18,#20,#20,#60,#20,#20,#18,#00
MbChar124:	DB	#30,#30,#30,#00,#30,#30,#30,#00
MbChar125:	DB	#C0,#20,#20,#30,#20,#20,#C0,#00
MbChar126:	DB	#40,#A8,#10,#00,#00,#00,#00,#00
MbChar127:	DB	#00,#00,#20,#50,#F8,#00,#00,#00
MbChar128:	DB	#70,#88,#80,#80,#88,#70,#20,#60
MbChar129:	DB	#90,#00,#00,#90,#90,#90,#68,#00
MbChar130:	DB	#10,#20,#70,#88,#F8,#80,#70,#00
MbChar131:	DB	#20,#50,#70,#08,#78,#88,#78,#00
MbChar132:	DB	#48,#00,#00,#38,#48,#98,#68,#00
MbChar133:	DB	#20,#10,#00,#38,#48,#98,#68,#00
MbChar134:	DB	#10,#10,#00,#38,#48,#98,#68,#00
MbChar135:	DB	#00,#70,#80,#80,#80,#70,#10,#60
MbChar136:	DB	#20,#50,#70,#88,#F8,#80,#70,#00
MbChar137:	DB	#50,#00,#70,#88,#F8,#80,#70,#00
MbChar138:	DB	#20,#10,#70,#88,#F8,#80,#70,#00
MbChar139:	DB	#50,#00,#20,#20,#20,#20,#20,#00
MbChar140:	DB	#20,#50,#00,#20,#20,#20,#20,#00
MbChar141:	DB	#40,#20,#00,#20,#20,#20,#20,#00
MbChar142:	DB	#50,#00,#70,#88,#88,#F8,#88,#00
MbChar143:	DB	#20,#00,#20,#50,#88,#F8,#88,#00
MbChar144:	DB	#10,#20,#F8,#80,#F0,#80,#F8,#00
MbChar145:	DB	#00,#00,#2C,#52,#9E,#B0,#5E,#00
MbChar146:	DB	#3E,#50,#90,#9C,#F0,#90,#9E,#00
MbChar147:	DB	#60,#90,#00,#60,#90,#90,#60,#00
MbChar148:	DB	#90,#00,#00,#60,#90,#90,#60,#00
MbChar149:	DB	#40,#20,#00,#60,#90,#90,#60,#00
MbChar150:	DB	#40,#A0,#00,#A0,#A0,#A0,#50,#00
MbChar151:	DB	#40,#20,#00,#90,#90,#90,#60,#00
MbChar152:	DB	#90,#00,#90,#90,#B0,#50,#10,#E0
MbChar153:	DB	#50,#00,#70,#88,#88,#88,#70,#00
MbChar154:	DB	#50,#00,#88,#88,#88,#88,#70,#00
MbChar155:	DB	#20,#20,#78,#80,#80,#78,#20,#20
MbChar156:	DB	#18,#24,#20,#F8,#20,#E2,#5C,#00
MbChar157:	DB	#88,#50,#20,#F8,#20,#F8,#20,#00
MbChar158:	DB	#C0,#A0,#A0,#C8,#9C,#88,#88,#8C
MbChar159:	DB	#38,#40,#40,#70,#40,#40,#40,#80
MbChar160:	DB	#10,#20,#00,#38,#48,#98,#68,#00
MbChar161:	DB	#10,#20,#00,#20,#20,#20,#20,#00
MbChar162:	DB	#20,#40,#00,#60,#90,#90,#60,#00
MbChar163:	DB	#10,#20,#00,#88,#88,#88,#70,#00
MbChar164:	DB	#50,#A0,#00,#60,#90,#90,#90,#00
MbChar165:	DB	#28,#50,#00,#C8,#A8,#98,#88,#00
MbChar166:	DB	#00,#00,#38,#48,#98,#68,#00,#F8
MbChar167:	DB	#00,#60,#90,#90,#90,#60,#00,#F0
MbChar168:	DB	#10,#00,#10,#20,#40,#84,#78,#00
MbChar169:	DB	#00,#00,#00,#F8,#80,#80,#00,#00
MbChar170:	DB	#00,#00,#00,#F8,#08,#08,#00,#00
MbChar171:	DB	#84,#88,#90,#A8,#54,#84,#08,#1C
MbChar172:	DB	#84,#88,#90,#A8,#58,#A8,#3C,#08
MbChar173:	DB	#30,#00,#30,#30,#30,#30,#30,#00
MbChar174:	DB	#00,#00,#24,#48,#90,#48,#24,#00
MbChar175:	DB	#00,#00,#90,#48,#24,#48,#90,#00
MbChar176:	DB	#28,#50,#20,#50,#88,#F8,#88,#00
MbChar177:	DB	#28,#50,#00,#38,#48,#98,#68,#00
MbChar178:	DB	#28,#50,#00,#70,#20,#20,#70,#00
MbChar179:	DB	#28,#50,#00,#20,#20,#20,#20,#00
MbChar180:	DB	#28,#50,#00,#70,#88,#88,#70,#00
MbChar181:	DB	#50,#A0,#00,#60,#90,#90,#60,#00
MbChar182:	DB	#28,#50,#00,#88,#88,#88,#70,#00
MbChar183:	DB	#50,#A0,#00,#90,#90,#90,#60,#00
MbChar184:	DB	#FC,#48,#48,#48,#E8,#08,#50,#20
MbChar185:	DB	#88,#00,#88,#88,#88,#88,#08,#70
MbChar186:	DB	#C0,#44,#C8,#54,#EC,#54,#9E,#04
MbChar187:	DB	#10,#A8,#40,#00,#00,#00,#00,#00
MbChar188:	DB	#00,#20,#50,#88,#50,#20,#00,#00
MbChar189:	DB	#88,#10,#20,#40,#80,#28,#00,#00
MbChar190:	DB	#7C,#A8,#A8,#68,#28,#28,#28,#00
MbChar191:	DB	#38,#40,#30,#48,#48,#30,#08,#70
MbChar192:	DB	#00,#00,#00,#00,#00,#00,#FF,#FF
MbChar193:	DB	#F0,#F0,#F0,#F0,#0F,#0F,#0F,#0F
MbChar194:	DB	#00,#00,#FF,#FF,#FF,#FF,#FF,#FF
MbChar195:	DB	#FF,#FF,#00,#00,#00,#00,#00,#00
MbChar196:	DB	#00,#00,#00,#3C,#3C,#00,#00,#00
MbChar197:	DB	#FF,#FF,#FF,#FF,#FF,#FF,#00,#00
MbChar198:	DB	#C0,#C0,#C0,#C0,#C0,#C0,#C0,#C0
MbChar199:	DB	#0F,#0F,#0F,#0F,#F0,#F0,#F0,#F0
MbChar200:	DB	#FC,#FC,#FC,#FC,#FC,#FC,#FC,#FC
MbChar201:	DB	#03,#03,#03,#03,#03,#03,#03,#03
MbChar202:	DB	#3F,#3F,#3F,#3F,#3F,#3F,#3F,#3F
MbChar203:	DB	#11,#22,#44,#88,#11,#22,#44,#88
MbChar204:	DB	#88,#44,#22,#11,#88,#44,#22,#11
MbChar205:	DB	#FE,#7C,#38,#10,#00,#00,#00,#00
MbChar206:	DB	#00,#00,#00,#00,#10,#38,#7C,#FE
MbChar207:	DB	#80,#C0,#E0,#F0,#E0,#C0,#80,#00
MbChar208:	DB	#01,#03,#07,#0F,#07,#03,#01,#00
MbChar209:	DB	#FF,#7E,#3C,#18,#18,#3C,#7E,#FF
MbChar210:	DB	#81,#C3,#E7,#FF,#FF,#E7,#C3,#81
MbChar211:	DB	#F0,#F0,#F0,#F0,#00,#00,#00,#00
MbChar212:	DB	#00,#00,#00,#00,#0F,#0F,#0F,#0F
MbChar213:	DB	#0F,#0F,#0F,#0F,#00,#00,#00,#00
MbChar214:	DB	#00,#00,#00,#00,#F0,#F0,#F0,#F0
MbChar215:	DB	#33,#33,#CC,#CC,#33,#33,#CC,#CC
MbChar216:	DB	#00,#20,#20,#50,#50,#88,#F8,#00
MbChar217:	DB	#20,#20,#70,#20,#70,#20,#20,#00
MbChar218:	DB	#00,#00,#00,#50,#88,#A8,#50,#00
MbChar219:	DB	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF
MbChar220:	DB	#00,#00,#00,#00,#FF,#FF,#FF,#FF
MbChar221:	DB	#F0,#F0,#F0,#F0,#F0,#F0,#F0,#F0
MbChar222:	DB	#0F,#0F,#0F,#0F,#0F,#0F,#0F,#0F
MbChar223:	DB	#FC,#FC,#FC,#FC,#00,#00,#00,#00
MbChar224:	DB	#00,#00,#68,#90,#90,#90,#68,#00
MbChar225:	DB	#30,#48,#48,#70,#48,#48,#70,#C0
MbChar226:	DB	#F8,#88,#80,#80,#80,#80,#80,#00
MbChar227:	DB	#F8,#50,#50,#50,#50,#50,#98,#00
MbChar228:	DB	#F8,#88,#40,#20,#40,#88,#F8,#00
MbChar229:	DB	#00,#00,#78,#90,#90,#90,#60,#00
MbChar230:	DB	#00,#50,#50,#50,#50,#68,#80,#80
MbChar231:	DB	#00,#50,#A0,#20,#20,#20,#20,#00
MbChar232:	DB	#F8,#20,#70,#A8,#A8,#70,#20,#F8
MbChar233:	DB	#20,#50,#88,#F8,#88,#50,#20,#00
MbChar234:	DB	#70,#88,#88,#88,#50,#50,#D8,#00
MbChar235:	DB	#30,#40,#40,#20,#50,#50,#50,#20
MbChar236:	DB	#00,#00,#00,#50,#A8,#A8,#50,#00
MbChar237:	DB	#08,#70,#A8,#A8,#A8,#70,#80,#00
MbChar238:	DB	#38,#40,#80,#F8,#80,#40,#38,#00
MbChar239:	DB	#70,#88,#88,#88,#88,#88,#88,#00
MbChar240:	DB	#00,#F8,#00,#F8,#00,#F8,#00,#00
MbChar241:	DB	#20,#20,#F8,#20,#20,#00,#F8,#00
MbChar242:	DB	#C0,#30,#08,#30,#C0,#00,#F8,#00
MbChar243:	DB	#18,#60,#80,#60,#18,#00,#F8,#00
MbChar244:	DB	#10,#28,#20,#20,#20,#20,#20,#20
MbChar245:	DB	#20,#20,#20,#20,#20,#20,#A0,#40
MbChar246:	DB	#00,#20,#00,#F8,#00,#20,#00,#00
MbChar247:	DB	#00,#50,#A0,#00,#50,#A0,#00,#00
MbChar248:	DB	#00,#18,#24,#24,#18,#00,#00,#00
MbChar249:	DB	#00,#30,#78,#78,#30,#00,#00,#00
MbChar250:	DB	#00,#00,#00,#00,#30,#00,#00,#00
MbChar251:	DB	#3E,#20,#20,#20,#A0,#60,#20,#00
MbChar252:	DB	#A0,#50,#50,#50,#00,#00,#00,#00
MbChar253:	DB	#40,#A0,#20,#40,#E0,#00,#00,#00
MbChar254:	DB	#00,#38,#38,#38,#38,#38,#38,#00
MbChar255:	DB	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF

	endif

	if	MBSET=0

EuroStart:	; 
EurChr0:	DB	#00,#00,#00,#00,#00,#00,#00,#00
EurChr1:	DB	#3C,#42,#A5,#81,#A5,#99,#42,#3C
EurChr2:	DB	#3C,#7E,#DB,#FF,#FF,#DB,#66,#3C
EurChr3:	DB	#6C,#FE,#FE,#FE,#7C,#38,#10,#00
EurChr4:	DB	#10,#38,#7C,#FE,#7C,#38,#10,#00
EurChr5:	DB	#10,#38,#54,#FE,#54,#10,#38,#00
EurChr6:	DB	#10,#38,#7C,#FE,#FE,#10,#38,#00
EurChr7:	DB	#00,#00,#00,#30,#30,#00,#00,#00
EurChr8:	DB	#FF,#FF,#FF,#E7,#E7,#FF,#FF,#FF
EurChr9:	DB	#38,#44,#82,#82,#82,#44,#38,#00
EurChr10:	DB	#C7,#BB,#7D,#7D,#7D,#BB,#C7,#FF
EurChr11:	DB	#0F,#03,#05,#79,#88,#88,#88,#70
EurChr12:	DB	#38,#44,#44,#44,#38,#10,#7C,#10
EurChr13:	DB	#30,#28,#24,#24,#28,#20,#E0,#C0
EurChr14:	DB	#3C,#24,#3C,#24,#24,#E4,#DC,#18
EurChr15:	DB	#10,#54,#38,#EE,#38,#54,#10,#00
EurChr16:	DB	#10,#10,#10,#7C,#10,#10,#10,#10
EurChr17:	DB	#10,#10,#10,#FF,#00,#00,#00,#00
EurChr18:	DB	#00,#00,#00,#FF,#10,#10,#10,#10
EurChr19:	DB	#10,#10,#10,#F0,#10,#10,#10,#10
EurChr20:	DB	#10,#10,#10,#1F,#10,#10,#10,#10
EurChr21:	DB	#10,#10,#10,#FF,#10,#10,#10,#10
EurChr22:	DB	#10,#10,#10,#10,#10,#10,#10,#10
EurChr23:	DB	#00,#00,#00,#FF,#00,#00,#00,#00
EurChr24:	DB	#00,#00,#00,#1F,#10,#10,#10,#10
EurChr25:	DB	#00,#00,#00,#F0,#10,#10,#10,#10
EurChr26:	DB	#10,#10,#10,#1F,#00,#00,#00,#00
EurChr27:	DB	#10,#10,#10,#F0,#00,#00,#00,#00
EurChr28:	DB	#81,#42,#24,#18,#18,#24,#42,#81
EurChr29:	DB	#01,#02,#04,#08,#10,#20,#40,#80
EurChr30:	DB	#80,#40,#20,#10,#08,#04,#02,#01
EurChr31:	DB	#00,#10,#10,#FF,#10,#10,#00,#00
EurChr32:	DB	#00,#00,#00,#00,#00,#00,#00,#00
EurChr33:	DB	#20,#20,#20,#20,#00,#00,#20,#00
EurChr34:	DB	#50,#50,#50,#00,#00,#00,#00,#00
EurChr35:	DB	#50,#50,#F8,#50,#F8,#50,#50,#00
EurChr36:	DB	#20,#78,#A0,#70,#28,#F0,#20,#00
EurChr37:	DB	#C0,#C8,#10,#20,#40,#98,#18,#00
EurChr38:	DB	#40,#A0,#40,#A8,#90,#98,#60,#00
EurChr39:	DB	#10,#20,#40,#00,#00,#00,#00,#00
EurChr40:	DB	#10,#20,#40,#40,#40,#20,#10,#00
EurChr41:	DB	#40,#20,#10,#10,#10,#20,#40,#00
EurChr42:	DB	#20,#A8,#70,#20,#70,#A8,#20,#00
EurChr43:	DB	#00,#20,#20,#F8,#20,#20,#00,#00
EurChr44:	DB	#00,#00,#00,#00,#00,#20,#20,#40
EurChr45:	DB	#00,#00,#00,#78,#00,#00,#00,#00
EurChr46:	DB	#00,#00,#00,#00,#00,#60,#60,#00
EurChr47:	DB	#00,#00,#08,#10,#20,#40,#80,#00
EurChr48:	DB	#70,#88,#98,#A8,#C8,#88,#70,#00
EurChr49:	DB	#20,#60,#A0,#20,#20,#20,#F8,#00
EurChr50:	DB	#70,#88,#08,#10,#60,#80,#F8,#00
EurChr51:	DB	#70,#88,#08,#30,#08,#88,#70,#00
EurChr52:	DB	#10,#30,#50,#90,#F8,#10,#10,#00
EurChr53:	DB	#F8,#80,#E0,#10,#08,#10,#E0,#00
EurChr54:	DB	#30,#40,#80,#F0,#88,#88,#70,#00
EurChr55:	DB	#F8,#88,#10,#20,#20,#20,#20,#00
EurChr56:	DB	#70,#88,#88,#70,#88,#88,#70,#00
EurChr57:	DB	#70,#88,#88,#78,#08,#10,#60,#00
EurChr58:	DB	#00,#00,#20,#00,#00,#20,#00,#00
EurChr59:	DB	#00,#00,#20,#00,#00,#20,#20,#40
EurChr60:	DB	#18,#30,#60,#C0,#60,#30,#18,#00
EurChr61:	DB	#00,#00,#F8,#00,#F8,#00,#00,#00
EurChr62:	DB	#C0,#60,#30,#18,#30,#60,#C0,#00
EurChr63:	DB	#70,#88,#08,#10,#20,#00,#20,#00
EurChr64:	DB	#70,#88,#08,#68,#A8,#A8,#70,#00
EurChr65:	DB	#20,#50,#88,#88,#F8,#88,#88,#00
EurChr66:	DB	#F0,#48,#48,#70,#48,#48,#F0,#00
EurChr67:	DB	#30,#48,#80,#80,#80,#48,#30,#00
EurChr68:	DB	#E0,#50,#48,#48,#48,#50,#E0,#00
EurChr69:	DB	#F8,#80,#80,#F0,#80,#80,#F8,#00
EurChr70:	DB	#F8,#80,#80,#F0,#80,#80,#80,#00
EurChr71:	DB	#70,#88,#80,#B8,#88,#88,#70,#00
EurChr72:	DB	#88,#88,#88,#F8,#88,#88,#88,#00
EurChr73:	DB	#70,#20,#20,#20,#20,#20,#70,#00
EurChr74:	DB	#38,#10,#10,#10,#90,#90,#60,#00
EurChr75:	DB	#88,#90,#A0,#C0,#A0,#90,#88,#00
EurChr76:	DB	#80,#80,#80,#80,#80,#80,#F8,#00
EurChr77:	DB	#88,#D8,#A8,#A8,#88,#88,#88,#00
EurChr78:	DB	#88,#C8,#C8,#A8,#98,#98,#88,#00
EurChr79:	DB	#70,#88,#88,#88,#88,#88,#70,#00
EurChr80:	DB	#F0,#88,#88,#F0,#80,#80,#80,#00
EurChr81:	DB	#70,#88,#88,#88,#A8,#90,#68,#00
EurChr82:	DB	#F0,#88,#88,#F0,#A0,#90,#88,#00
EurChr83:	DB	#70,#88,#80,#70,#08,#88,#70,#00
EurChr84:	DB	#F8,#20,#20,#20,#20,#20,#20,#00
EurChr85:	DB	#88,#88,#88,#88,#88,#88,#70,#00
EurChr86:	DB	#88,#88,#88,#88,#50,#50,#20,#00
EurChr87:	DB	#88,#88,#88,#A8,#A8,#D8,#88,#00
EurChr88:	DB	#88,#88,#50,#20,#50,#88,#88,#00
EurChr89:	DB	#88,#88,#88,#70,#20,#20,#20,#00
EurChr90:	DB	#F8,#08,#10,#20,#40,#80,#F8,#00
EurChr91:	DB	#70,#40,#40,#40,#40,#40,#70,#00
EurChr92:	DB	#00,#00,#80,#40,#20,#10,#08,#00
EurChr93:	DB	#70,#10,#10,#10,#10,#10,#70,#00
EurChr94:	DB	#20,#50,#88,#00,#00,#00,#00,#00
EurChr95:	DB	#00,#00,#00,#00,#00,#00,#F8,#00
EurChr96:	DB	#40,#20,#10,#00,#00,#00,#00,#00
EurChr97:	DB	#00,#00,#70,#08,#78,#88,#78,#00
EurChr98:	DB	#80,#80,#B0,#C8,#88,#C8,#B0,#00
EurChr99:	DB	#00,#00,#70,#88,#80,#88,#70,#00
EurChr100:	DB	#08,#08,#68,#98,#88,#98,#68,#00
EurChr101:	DB	#00,#00,#70,#88,#F8,#80,#70,#00
EurChr102:	DB	#10,#28,#20,#F8,#20,#20,#20,#00
EurChr103:	DB	#00,#00,#68,#98,#98,#68,#08,#70
EurChr104:	DB	#80,#80,#F0,#88,#88,#88,#88,#00
EurChr105:	DB	#20,#00,#60,#20,#20,#20,#70,#00
EurChr106:	DB	#10,#00,#30,#10,#10,#10,#90,#60
EurChr107:	DB	#40,#40,#48,#50,#60,#50,#48,#00
EurChr108:	DB	#60,#20,#20,#20,#20,#20,#70,#00
EurChr109:	DB	#00,#00,#D0,#A8,#A8,#A8,#A8,#00
EurChr110:	DB	#00,#00,#B0,#C8,#88,#88,#88,#00
EurChr111:	DB	#00,#00,#70,#88,#88,#88,#70,#00
EurChr112:	DB	#00,#00,#B0,#C8,#C8,#B0,#80,#80
EurChr113:	DB	#00,#00,#68,#98,#98,#68,#08,#08
EurChr114:	DB	#00,#00,#B0,#C8,#80,#80,#80,#00
EurChr115:	DB	#00,#00,#78,#80,#F0,#08,#F0,#00
EurChr116:	DB	#40,#40,#F0,#40,#40,#48,#30,#00
EurChr117:	DB	#00,#00,#90,#90,#90,#90,#68,#00
EurChr118:	DB	#00,#00,#88,#88,#88,#50,#20,#00
EurChr119:	DB	#00,#00,#88,#A8,#A8,#A8,#50,#00
EurChr120:	DB	#00,#00,#88,#50,#20,#50,#88,#00
EurChr121:	DB	#00,#00,#88,#88,#98,#68,#08,#70
EurChr122:	DB	#00,#00,#F8,#10,#20,#40,#F8,#00
EurChr123:	DB	#18,#20,#20,#40,#20,#20,#18,#00
EurChr124:	DB	#20,#20,#20,#00,#20,#20,#20,#00
EurChr125:	DB	#C0,#20,#20,#10,#20,#20,#C0,#00
EurChr126:	DB	#40,#A8,#10,#00,#00,#00,#00,#00
EurChr127:	DB	#00,#00,#20,#50,#F8,#00,#00,#00
EurChr128:	DB	#70,#88,#80,#80,#88,#70,#20,#60
EurChr129:	DB	#90,#00,#00,#90,#90,#90,#68,#00
EurChr130:	DB	#10,#20,#70,#88,#F8,#80,#70,#00
EurChr131:	DB	#20,#50,#70,#08,#78,#88,#78,#00
EurChr132:	DB	#48,#00,#70,#08,#78,#88,#78,#00
EurChr133:	DB	#20,#10,#70,#08,#78,#88,#78,#00
EurChr134:	DB	#20,#00,#70,#08,#78,#88,#78,#00
EurChr135:	DB	#00,#70,#80,#80,#80,#70,#10,#60
EurChr136:	DB	#20,#50,#70,#88,#F8,#80,#70,#00
EurChr137:	DB	#50,#00,#70,#88,#F8,#80,#70,#00
EurChr138:	DB	#20,#10,#70,#88,#F8,#80,#70,#00
EurChr139:	DB	#50,#00,#00,#60,#20,#20,#70,#00
EurChr140:	DB	#20,#50,#00,#60,#20,#20,#70,#00
EurChr141:	DB	#40,#20,#00,#60,#20,#20,#70,#00
EurChr142:	DB	#50,#00,#20,#50,#88,#F8,#88,#00
EurChr143:	DB	#20,#00,#20,#50,#88,#F8,#88,#00
EurChr144:	DB	#10,#20,#F8,#80,#F0,#80,#F8,#00
EurChr145:	DB	#00,#00,#6C,#12,#7E,#90,#6E,#00
EurChr146:	DB	#3E,#50,#90,#9C,#F0,#90,#9E,#00
EurChr147:	DB	#60,#90,#00,#60,#90,#90,#60,#00
EurChr148:	DB	#90,#00,#00,#60,#90,#90,#60,#00
EurChr149:	DB	#40,#20,#00,#60,#90,#90,#60,#00
EurChr150:	DB	#40,#A0,#00,#A0,#A0,#A0,#50,#00
EurChr151:	DB	#40,#20,#00,#A0,#A0,#A0,#50,#00
EurChr152:	DB	#90,#00,#90,#90,#B0,#50,#10,#E0
EurChr153:	DB	#50,#00,#70,#88,#88,#88,#70,#00
EurChr154:	DB	#50,#00,#88,#88,#88,#88,#70,#00
EurChr155:	DB	#20,#20,#78,#80,#80,#78,#20,#20
EurChr156:	DB	#18,#24,#20,#F8,#20,#E2,#5C,#00
EurChr157:	DB	#88,#50,#20,#F8,#20,#F8,#20,#00
EurChr158:	DB	#C0,#A0,#A0,#C8,#9C,#88,#88,#8C
EurChr159:	DB	#18,#20,#20,#F8,#20,#20,#20,#40
EurChr160:	DB	#10,#20,#70,#08,#78,#88,#78,#00
EurChr161:	DB	#10,#20,#00,#60,#20,#20,#70,#00
EurChr162:	DB	#20,#40,#00,#60,#90,#90,#60,#00
EurChr163:	DB	#20,#40,#00,#90,#90,#90,#68,#00
EurChr164:	DB	#50,#A0,#00,#A0,#D0,#90,#90,#00
EurChr165:	DB	#28,#50,#00,#C8,#A8,#98,#88,#00
EurChr166:	DB	#00,#70,#08,#78,#88,#78,#00,#F8
EurChr167:	DB	#00,#60,#90,#90,#90,#60,#00,#F0
EurChr168:	DB	#20,#00,#20,#40,#80,#88,#70,#00
EurChr169:	DB	#00,#00,#00,#F8,#80,#80,#00,#00
EurChr170:	DB	#00,#00,#00,#F8,#08,#08,#00,#00
EurChr171:	DB	#84,#88,#90,#A8,#54,#84,#08,#1C
EurChr172:	DB	#84,#88,#90,#A8,#58,#A8,#3C,#08
EurChr173:	DB	#20,#00,#00,#20,#20,#20,#20,#00
EurChr174:	DB	#00,#00,#24,#48,#90,#48,#24,#00
EurChr175:	DB	#00,#00,#90,#48,#24,#48,#90,#00
EurChr176:	DB	#28,#50,#20,#50,#88,#F8,#88,#00
EurChr177:	DB	#28,#50,#70,#08,#78,#88,#78,#00
EurChr178:	DB	#28,#50,#00,#70,#20,#20,#70,#00
EurChr179:	DB	#28,#50,#00,#20,#20,#20,#70,#00
EurChr180:	DB	#28,#50,#00,#70,#88,#88,#70,#00
EurChr181:	DB	#50,#A0,#00,#60,#90,#90,#60,#00
EurChr182:	DB	#28,#50,#00,#88,#88,#88,#70,#00
EurChr183:	DB	#50,#A0,#00,#A0,#A0,#A0,#50,#00
EurChr184:	DB	#FC,#48,#48,#48,#E8,#08,#50,#20
EurChr185:	DB	#00,#50,#00,#50,#50,#50,#10,#20
EurChr186:	DB	#C0,#44,#C8,#54,#EC,#54,#9E,#04
EurChr187:	DB	#10,#A8,#40,#00,#00,#00,#00,#00
EurChr188:	DB	#00,#20,#50,#88,#50,#20,#00,#00
EurChr189:	DB	#88,#10,#20,#40,#80,#28,#00,#00
EurChr190:	DB	#7C,#A8,#A8,#68,#28,#28,#28,#00
EurChr191:	DB	#38,#40,#30,#48,#48,#30,#08,#70
EurChr192:	DB	#00,#00,#00,#00,#00,#00,#FF,#FF
EurChr193:	DB	#F0,#F0,#F0,#F0,#0F,#0F,#0F,#0F
EurChr194:	DB	#00,#00,#FF,#FF,#FF,#FF,#FF,#FF
EurChr195:	DB	#FF,#FF,#00,#00,#00,#00,#00,#00
EurChr196:	DB	#00,#00,#00,#3C,#3C,#00,#00,#00
EurChr197:	DB	#FF,#FF,#FF,#FF,#FF,#FF,#00,#00
EurChr198:	DB	#C0,#C0,#C0,#C0,#C0,#C0,#C0,#C0
EurChr199:	DB	#0F,#0F,#0F,#0F,#F0,#F0,#F0,#F0
EurChr200:	DB	#FC,#FC,#FC,#FC,#FC,#FC,#FC,#FC
EurChr201:	DB	#03,#03,#03,#03,#03,#03,#03,#03
EurChr202:	DB	#3F,#3F,#3F,#3F,#3F,#3F,#3F,#3F
EurChr203:	DB	#11,#22,#44,#88,#11,#22,#44,#88
EurChr204:	DB	#88,#44,#22,#11,#88,#44,#22,#11
EurChr205:	DB	#FE,#7C,#38,#10,#00,#00,#00,#00
EurChr206:	DB	#00,#00,#00,#00,#10,#38,#7C,#FE
EurChr207:	DB	#80,#C0,#E0,#F0,#E0,#C0,#80,#00
EurChr208:	DB	#01,#03,#07,#0F,#07,#03,#01,#00
EurChr209:	DB	#FF,#7E,#3C,#18,#18,#3C,#7E,#FF
EurChr210:	DB	#81,#C3,#E7,#FF,#FF,#E7,#C3,#81
EurChr211:	DB	#F0,#F0,#F0,#F0,#00,#00,#00,#00
EurChr212:	DB	#00,#00,#00,#00,#0F,#0F,#0F,#0F
EurChr213:	DB	#0F,#0F,#0F,#0F,#00,#00,#00,#00
EurChr214:	DB	#00,#00,#00,#00,#F0,#F0,#F0,#F0
EurChr215:	DB	#33,#33,#CC,#CC,#33,#33,#CC,#CC
EurChr216:	DB	#00,#20,#20,#50,#50,#88,#F8,#00
EurChr217:	DB	#20,#20,#70,#20,#70,#20,#20,#00
EurChr218:	DB	#00,#00,#00,#50,#88,#A8,#50,#00
EurChr219:	DB	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF
EurChr220:	DB	#00,#00,#00,#00,#FF,#FF,#FF,#FF
EurChr221:	DB	#F0,#F0,#F0,#F0,#F0,#F0,#F0,#F0
EurChr222:	DB	#0F,#0F,#0F,#0F,#0F,#0F,#0F,#0F
EurChr223:	DB	#FF,#FF,#FF,#FF,#00,#00,#00,#00
EurChr224:	DB	#00,#00,#68,#90,#90,#90,#68,#00
EurChr225:	DB	#30,#48,#48,#70,#48,#48,#70,#C0
EurChr226:	DB	#F8,#88,#80,#80,#80,#80,#80,#00
EurChr227:	DB	#F8,#50,#50,#50,#50,#50,#98,#00
EurChr228:	DB	#F8,#88,#40,#20,#40,#88,#F8,#00
EurChr229:	DB	#00,#00,#78,#90,#90,#90,#60,#00
EurChr230:	DB	#00,#50,#50,#50,#50,#68,#80,#80
EurChr231:	DB	#00,#50,#A0,#20,#20,#20,#20,#00
EurChr232:	DB	#F8,#20,#70,#A8,#A8,#70,#20,#F8
EurChr233:	DB	#20,#50,#88,#F8,#88,#50,#20,#00
EurChr234:	DB	#70,#88,#88,#88,#50,#50,#D8,#00
EurChr235:	DB	#30,#40,#40,#20,#50,#50,#50,#20
EurChr236:	DB	#00,#00,#00,#50,#A8,#A8,#50,#00
EurChr237:	DB	#08,#70,#A8,#A8,#A8,#70,#80,#00
EurChr238:	DB	#38,#40,#80,#F8,#80,#40,#38,#00
EurChr239:	DB	#70,#88,#88,#88,#88,#88,#88,#00
EurChr240:	DB	#00,#F8,#00,#F8,#00,#F8,#00,#00
EurChr241:	DB	#20,#20,#F8,#20,#20,#00,#F8,#00
EurChr242:	DB	#C0,#30,#08,#30,#C0,#00,#F8,#00
EurChr243:	DB	#18,#60,#80,#60,#18,#00,#F8,#00
EurChr244:	DB	#10,#28,#20,#20,#20,#20,#20,#20
EurChr245:	DB	#20,#20,#20,#20,#20,#20,#A0,#40
EurChr246:	DB	#00,#20,#00,#F8,#00,#20,#00,#00
EurChr247:	DB	#00,#50,#A0,#00,#50,#A0,#00,#00
EurChr248:	DB	#00,#18,#24,#24,#18,#00,#00,#00
EurChr249:	DB	#00,#30,#78,#78,#30,#00,#00,#00
EurChr250:	DB	#00,#00,#00,#00,#30,#00,#00,#00
EurChr251:	DB	#3E,#20,#20,#20,#A0,#60,#20,#00
EurChr252:	DB	#A0,#50,#50,#50,#00,#00,#00,#00
EurChr253:	DB	#40,#A0,#20,#40,#E0,#00,#00,#00
EurChr254:	DB	#00,#38,#38,#38,#38,#38,#38,#00
EurChr255:	DB	#00,#00,#00,#00,#00,#00,#00,#00

	endif

PARTRE2!:	;
