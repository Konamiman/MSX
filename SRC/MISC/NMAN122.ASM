;NestorMan - resident memory manager

;Go to http://konamiman.com#nestorman for the documentation.

;=======================================

	;--- NetorMan - Gestor residente de memoria dinamica
	;    Por Konami Man, 2-2002
	;    Version 1.22

	;Cambios respecto a 1.11:
	;- La funcion 1 devuelve Cy=1 si NestorMan ya se estaba
	;  ejecutando (util si se pretende usar NestorMan
	;  desde una rutina de interrupcion, dado que las
	;  funciones de NestorMan no son reentrantes)
	;- Anyadidas las funciones 28 y 29
	;- Anyadidas las funciones 30 a 32 para InterNestor Suite
	;- Anyadido soporte para llamar a la entrada #4009
	;  del primer segmento de InterNestor Suite
	;  en cada interrupcion del reloj
	;- Todas las funciones vuelven en modo DI

	;Cambios respecto a 1.2:
	;- Anyadidos SAVE_DOS_VARS y LOAD_DOS_VARS
	;  para evitar cuelgues al llamar a ALL_SEG y FRE_SEG
	;  desde una rutina de interrupcion
	;- Anyadidos EIs tras los ENASLTs
	;- Corregido LOADP2 (PUSH IX antes de CALL ENASL)
	;  y la funcion 0 (llamaba a SAVEP2 pero no a LOADP2)

	;Cambios respecto a 1.21:
	;- Corregido un fallo grave en MALLOC (REQ2REAL) y MFREE
	;- Corregidos varios "call FUNxx" a "call _FUNxx"

	.label	20

VERPRIM:	equ	1
VERSEC:	equ	#0202
SYSMAT:	equ	123	;Bytes MAT siempre ocupados en seg. NMAN

DOSENTRY:	equ	5	;5 o #F37D

dummy:	macro
	endm

div_hl:	macro		;Divide HL por 2
	srl	h
	rr	l
	endm

div_de:	macro		;Divide DE por 2
	srl	d
	rr	e
	endm

IDNMAN:	equ	2	;0 es NestorAcentos, 1 es NestorCPlayer

nesman:	macro	@f	;Llamada indirecta
	ld	c,@f
	ld	de,34*256 + IDNMAN
	call	EXTBIO
	endm

nesmani:	macro	@f	;Llamada semidirecta
	ld	c,@f
	call	#4139
	endm

	;--- Saltos [mayor|menor|igual]

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

ENDTPA:	equ	#0006
HIGHMEM:	equ	#F349
H_TIMI:	equ	#FD9F

	;*** FUNCIONES DEL DOS

DOSVER:	equ	#6F
STROUT:	equ	#09
TERM:	equ	#62
SENV:	equ	#6C

_OPEN:	equ	#43
_CREATE:	equ	#44
_CLOSE:	equ	#45
_READ:	equ	#48
_WRITE:	equ	#49
_SEEK:	equ	#4A

ENASLT:	equ	#0024
EXTBIO:	equ	#FFCA
EXPTBL:	equ	#FCC1


;*********************
;***               ***
;***  INSTALACION  ***
;***               ***
;*********************

	dummy
	dummy
	dummy
	dummy
	dummy
	dummy
	dummy
	dummy


;--- Comprobamos presencia del DOS 2

	ld	c,DOSVER	;DOS 2?
	call	5
	ld	a,b
	cp	2
	jrmyi	OKDOS2

NODOS2:	ld	de,NOD2STR
	ld	c,STROUT
	call	5
	ret
NOD2STR:	db	13,10,"NestorMan #1.22 requires DOS 2!",13,10,"$"
OKDOS2:	;


;--- Obtencion de la tabla de rutinas de soporte del mapeador de memoria

	ld	de,#0402
	call	EXTBIO
	ld	a,b	;de paso establecemos el slot en la
	and	%10001111	;futura rutina de salto de pag. 3
	ld	(RESLOT000F),a
	ld	(RESLOT000E),a
	ld	de,_ALL_SEG
	ld	bc,#30
	ldir


;--- Comprobamos si NESMAN ya esta instalado,
;    en ese caso pasamos a desinstalar si el parametro es "U"

	xor	a
	nesman	1
	or	a
	jp	nz,DESINST


;--- Comprobamos que hay suficiente TPA (#0006 >= #C100)

	ld	a,(ENDTPA+1)
	cp	#C1
	jr	nc,OKTPA

	ld	de,NOTPAS
	ld	c,STROUT
	call	5
	jp	FIN
NOTPAS:	db	13,10,"ERROR: too small TPA (end of TPA must be at least #C100).",13,10
	db	"NestorMan #1.22 not installed.",13,10,"$"

FIN:	ld	b,0
	ld	c,TERM
	call	5
	ret

OKTPA:	;


;--- Comienza la instalacion: reservamos un segmento de RAM

	ld	a,(#F344)
	or	%0 010 0000
	ld	b,a	;Reservamos un segmento de sistema
	ld	a,1	;en el mapeador primario
	call	_ALL_SEG
	jp	nc,OKRESEG
	ld	de,NOFSTR
	ld	c,STROUT
	call	5
	jp	FIN

NOFSTR:	db	13,10,"ERROR: no free segments on any mapper.",13,10
	db	"NestorMan #1.22 not installed.",13,10,"$"

OKRESEG:	ld	(RESEG000F),a
	ld	(RESEG000E),a

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

	ld	hl,(_GET_P1+1)	;Copiamos entrada a GET_P1
	ld	(GET_P1000F+1),hl
	ld	(GET_P1000E+1),hl
	ld	hl,(_PUT_P1+1)	;Copiamos entrada a PUT_P1
	ld	(PUT_P1000F+1),hl
	ld	(PUT_P1000E+1),hl
	ld	hl,(_GET_P2+1)	;Copiamos entrada a GET_P2
	ld	(GET_P2000F+1),hl
	ld	(GET_P2000E+1),hl
	ld	hl,(_PUT_P2+1)	;Copiamos entrada a PUT_P2
	ld	(PUT_P2000F+1),hl
	ld	(PUT_P2000E+1),hl
	ld	hl,(_CAL_SEG+1)	;Copiamos entrada a CAL_SEG
	ld	(CAL_SEG000F+1),hl
	ld	(CAL_SEG000E+1),hl

	ld	hl,EXTBIO	;Guardamos antiguo EXTBIO
	ld	de,OLDBIO000F
	ld	bc,5
	push	hl,bc
	ldir
	pop	bc,hl
	ld	de,OLDBIO000E
	ldir

	ld	hl,H_TIMI	;Guardamos antiguo H_TIMI
	ld	de,OLDTIME000F
	ld	bc,5
	push	hl,bc
	ldir
	pop	bc,hl
	ld	de,OLDTIME000E
	ldir

	ld	hl,RESCODE1	;Copiamos la rutina de salto a pag. 3 !!
	ld	de,RESCODE2
	ld	ix,(NEWHM000F)
	ld	bc,ENDRES000F-INIRES000F
	call	REUBICA

;--- Copiamos la parte residente en el segmento que acabamos de reservar

	call	_GET_P1	;Copiamos la parte residente
	push	af	;en el segmento
	ld	a,(RESEG000F)
	call	_PUT_P1
	call	_CLEAN4
	ld	hl,PARTRE1
	ld	de,#4100
	ld	bc,PARTRE1!-#4100
	ldir

	ld	hl,EXECU000F	;Calcula direccion real del flag
	ld	bc,INIRES000F	;EXECU y la pone en EXEC_DIR
	or	a
	sbc	hl,bc
	ld	bc,(HIGHMEM)
	add	hl,bc
	ld	(EXEC_DIR+1),hl

	di
	ld	hl,NEWTIME000F	;Calcula la direccion real de
	ld	bc,INIRES000F	;NEWTIME y establece H_TIMI
	or	a	;apuntandole
	sbc	hl,bc
	ld	bc,(HIGHMEM)
	add	hl,bc
	ld	(H_TIMI+1),hl
	ld	a,#C3
	ld	(H_TIMI),a
	ei

	ld	hl,LDIRP3000F	;Establece la dir para la llamada
	ld	bc,INIRES000F	;a LDIRP3 en pagina 3
	or	a
	sbc	hl,bc
	ld	bc,(HIGHMEM)
	add	hl,bc
	ld	(CALLP3+1),hl


	;--- INITMEM:  Inicializa el tinglado:
	;              - Limpia la parte de datos del segmento
	;              - Inicializa la tabla de segmentos
	;    Entrada:  -
	;    Salida:   Cy=1 si no hay ningun segmento libre
	;    Regist:   AF, BC, DE, HL

	;Copia la tabla de rutinas del mapeador

INITMEM:	ld	hl,_ALL_SEG
	ld	de,ALL_SEG
	ld	bc,#30
	ldir

	;Inicializa la tabla de segmentos

	ld	a,(RESEG000E)
	ld	(TABSEGS+9),a	;El segmento reservado
	ld	a,(RESLOT000E)	;sera el numero 5 en la tabla de segmentos
	ld	(TABSEGS+8),a
	ld	a,5
	ld	(NUMSEGS),a

	ld	a,(#F344)	;Rellena las 4 primeras entradas
	or	%0 001 0000
	ld	(TABSEGS),a	;con los segmentos de TPA (modo exclusivo)
	ld	(TABSEGS+2),a
	ld	(TABSEGS+4),a
	ld	(TABSEGS+6),a
	call	GET_P0
	ld	(TABSEGS+1),a
	pop	af	;call    GET_P1
	push	af
	ld	(TABSEGS+3),a
	call	GET_P2
	ld	(TABSEGS+5),a
	call	GET_P3
	ld	(TABSEGS+7),a

	ld	hl,SEGSLOTS
	ld	(CNT),hl

	pop	af
	call	PUT_P1

	ld	a,#C3	;Establecemos nuevo EXTBIO
	ld	(EXTBIO),a
	ld	hl,(HIGHMEM)
	ld	(EXTBIO+1),hl

;--- Finalizacion de la instalacion

	ei

	ld	hl,NESTENV	;Establecemos variable NESMAN como 1.22
	ld	de,NESTVAL
	ld	c,SENV
	call	5

	ld	de,INSSTR
	ld	c,STROUT
	call	5
	ld	hl,#0081
	jp	CALSYS

INSSTR:	db	13,10,"NestorMan #1.22 - The resident dynamic memory manager",13,10
	db	"By Konami Man, 2-2002",13,10
	db	"Installed. Have fun! (^^)/",13,10,"$"

NESTENV:	db	"NESMAN",0
NESTVAL:	db	"1.22"
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
	call	5
	jp	FIN

YAINSTR:	db	13,10,"NestorMan #1.22 already installed.",13,10
	db	"NESMAN U to uninstall.",13,10,"$"

CHKU:	and	%11011111	;Si encontramos algo tiene que ser "U"
	cp	"U"
	jr	nz,NODES
	ld	(POS2COM),hl	;Guardamos posicion posterior a la "U"

	;                        ;Comprobamos que HIGHMEM actual es igual
	nesman	1	;al HIGHMEM cuando instalamos NestAc.
	ld	de,(HIGHMEM)	;Si no, no podemos desinstalar.
	or	a
	sbc	hl,de
	ld	a,h
	or	l
	jp	z,OKHMEM

	ld	de,NOKHMEMS
	ld	c,STROUT
	call	5
	jp	FIN

NOKHMEMS:	db	13,10,"ERROR: Other resident program was installed after NestorMan.",13,10
	db	"Please remove it and try again to uninstall NestorMan.",13,10,"$"
POS2COM:	dw	0

OKHMEM:	push	ix,bc
	nesman	0	;Libero todos los segmentos

	di
	ld	hl,OLDTIME000F	;Calcula la direccion real de
	ld	bc,INIRES000F	;OLDTIME y restablece H_TIMI
	or	a
	sbc	hl,bc
	ld	bc,(HIGHMEM)
	add	hl,bc
	ld	de,H_TIMI
	ld	bc,5
	ldir
	ei

	pop	bc
	ld	a,c	;Liberamos el segmento de NESMAN
	call	_FRE_SEG

	ld	hl,(HIGHMEM)
	ld	bc,3
	add	hl,bc
	di

	pop	ix	;Restaura gancho EXTBIO
	ld	(HIGHMEM),ix
	ld	de,EXTBIO
	ld	bc,5
	ldir

	ld	hl,NESTENV	;Borramos variable NESMAN
	ld	de,NULVAL
	ld	c,SENV
	call	5

	ld	de,DESSTR	;Terminamos!
	ld	c,STROUT
	call	5
	ld	hl,(POS2COM)
	jp	CALSYS

DESSTR:	db	13,10,"NestorMan #1.22 uninstalled.",13,10,"$"


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

_CLEAN4:	ld	hl,#4000	;Limpia la zona de NESMAN en pag. 1
	ld	de,#4001	;(solo MAT)
	ld	bc,SYSMAT
	ld	(hl),255
	ldir
	ld	bc,256-SYSMAT-1
	ld	(hl),0
	ldir
	ret


	;Rutinas de soporte del mapeador

_ALL_SEG:	ds	3
_FRE_SEG:	ds	3
_RD_SEG:	ds	3
_WR_SEG:	ds	3
_CAL_SEG:	ds	3
_CALLS:	ds	3
_PUT_PH:	ds	3
_GET_PH:	ds	3
_PUT_P0:	ds	3
_GET_P0:	ds	3
_PUT_P1:	ds	3
_GET_P1:	ds	3
_PUT_P2:	ds	3
_GET_P2:	ds	3
_PUT_P3:	ds	3
_GET_P3:	ds	3


;*************************************
;***                               ***
;***  PARTE RESIDENTE EN PAGINA 3  ***
;***                               ***
;*************************************

PARTRES:	macro

INIRES@sym:	;
NEWBIO@sym:	jp	_NEWBIO@sym
OLDBIO@sym:	ds	5

;--- Nuevo EXTBIO:
;    Entrada: D = 34
;             E = IDNMAN
;             C = Funcion
;    Salida:  Segun la funcion. Para C=1:
;             HL= NewHIGHMEM
;             IX= OldHIGHMEM
;             B = Slot del segmento reservado
;             C = Segmento reservado
;             A = Version principal de NESMAN
;             DE= Version secundaria de NESMAN
;             Cy= 1 si ya se estaba ejecutado NESMAN

_NEWBIO@sym:	push	af	;BIOS extendida. Identificador: IDNAC
	ld	a,d	;Modifica IX, IY y alternativos.
	cp	34	;Nunca modifica DE.
	jr	nz,NOBIOS@sym
	ld	a,e
	cp	IDNMAN
	jr	z,OKBIOS@sym
NOBIOS@sym:	pop	af
	jp	OLDBIO@sym

OKBIOS@sym:	ld	a,c
	cp	1
	jr	nz,FUNCION@sym

	pop	af	;Funcion 1
	ld	a,(EXECU@sym)
	or	a
	jr	z,OKBI2@sym
	scf
OKBI2@sym:	ld	hl,(NEWHM@sym)
	ld	ix,(OLDHM@sym)
	ld	a,(RESLOT@sym)
	ld	b,a
	ld	a,(RESEG@sym)
	ld	c,a
	ld	a,VERPRIM
	ld	de,VERSEC
	ret

FUNCION@sym:	ld	a,-1
	ld	(EXECU@sym),a
	pop	af	;Otra funcion
	push	af,bc,de,hl,ix,iy
	call	GETSLOT1@sym	;Guardamos el slot conectado en pag. 2
	ld	(OLDSLOT@sym),a
	ld	b,a
	ld	a,(RESLOT@sym)
	call	PUTSLOT1@sym	;Conectamos el slot si no es el que
	call	GET_P1@sym
	ld	(OLDSEG@sym),a
	ld	a,(RESEG@sym)
	call	PUT_P1@sym
	ld	a,#C9	;RET para que la rutina no modifique
	ld	(RES_EXECU),a	;el flag EXECU al terminar
	pop	iy,ix,hl,de,bc,af
	call	ENTRYP
	push	af,bc,de,hl,ix,iy
	xor	a	;Vuelve a habilitar a las rutinas
	ld	(RES_EXECU),a	;para modificar EXECU, por si se
	ld	a,(RESLOT@sym)	;hace una llamada directa
	ld	b,a
	ld	a,(OLDSLOT@sym)
	call	PUTSLOT1@sym
	ld	a,(OLDSEG@sym)
	call	PUT_P1@sym
	pop	iy,ix,hl,de,bc
	xor	a
	ld	(EXECU@sym),a
	pop	af
	ret

RESLOT@sym:	db	0
RESEG@sym:	db	0
GET_P1@sym:	jp	#0000
PUT_P1@sym:	jp	#0000
GET_P2@sym:	jp	#0000
PUT_P2@sym:	jp	#0000
CAL_SEG@sym:	jp	#0000
NEWHM@sym:	dw	0
OLDHM@sym:	dw	0
OLDSLOT@sym:	db	0
OLDSEG@sym:	db	0
EXECU@sym:	db	0	;-1 si ya se esta ejecutando NESMAN
INETSLOT@sym:	db	0	;PONER ESTA JUSTO DESP DE INETSLOT
INETSEG@sym:	db	0
OLDSLOTT@sym:	db	0
OLDSEGT@sym:	db	0
;OLDSEGT2@sym:     db      0
MYINT@sym:	db	0
SAVESP@sym:	dw	0

;--- Destino de la nueva interrupcion del reloj

NEWTIME@sym:	di
	ld	a,(MYINT@sym)
	or	a
	jr	nz,OLDTIME@sym-1
	dec	a
	ld	(MYINT@sym),a
	ei

	;in      a,(#FC)
	;and     %00011111
	;cp      #1A
	;jr      z,ENDTIME@sym
	;cp      #1B
	;jr      z,ENDTIME@sym

	ld	a,(INETSLOT@sym)
	or	a
	jr	z,ENDTIME@sym
	ld	a,(EXECU@sym)
	or	a
	jr	nz,ENDTIME@sym

	;ld      (SAVESP@sym),sp
	;ld      a,(SAVESP@sym+1)
	;and     %11100000
	;cp      %11100000
	;jr      z,ENDTIME@sym
	;ld      sp,NEWSP@sym-2

	call	GETSLOT2@sym
	ld	(OLDSLOTT@sym),a
	ld	b,a
	ld	a,(INETSLOT@sym)
	call	PUTSLOT2@sym	;Conectamos el slot si no es el que
	call	GET_P2@sym
	ld	(OLDSEGT@sym),a
	;in      a,(#FE)
	;ld      (OLDSEGT2@sym),a
	ld	a,(INETSEG@sym)
	call	PUT_P2@sym
	call	#8009
	ld	a,(INETSLOT@sym)
	ld	b,a
	ld	a,(OLDSLOTT@sym)
	call	PUTSLOT2@sym
	ld	a,(OLDSEGT@sym)
	call	PUT_P2@sym
	;ld      a,(OLDSEGT2@sym)
	;out     (#FE),a

	;ld      sp,(SAVESP@sym)

	;xor     a                ;Restaura registro de estado 0
	;out     (#99),a          ;del VDP
	;nop
	;ld      a,#8F
	;out     (#99),a

ENDTIME@sym:	xor	a
	ld	(MYINT@sym),a

	ei
OLDTIME@sym:	ds	5

;--- Subrutina LDIRP3: Conecta el slot L, segmento H en pagina 1,
;    hace un LDIR de IX a IY longitud BC, y restaura NestorMan en pagina 1

LDIRP3@sym:	push	ix,iy,bc,hl
	di
	call	GETSLOT1@sym
	ld	b,a
	pop	hl
	push	hl
	ld	a,l
	ld	(SLOTLDIR@sym),a
	call	PUTSLOT1@sym
	ei
	pop	af
	call	PUT_P1@sym
	pop	bc,de,hl
	ldir
	ld	a,(SLOTLDIR@sym)
	ld	b,a
	ld	a,(RESLOT@sym)
	call	PUTSLOT1@sym
	ei
	ld	a,(RESEG@sym)
	call	PUT_P1@sym
	ret
SLOTLDIR@sym:	db	0

;--- Subrutina para la obtencion del slot conectado en pagina 1

GETSLOT1@sym:	di
	exx
	in	a,(#A8)
	ld	e,a
	and	%00001100
	sra	a
	sra	a
	ld	c,a	;C = Slot
	ld	b,0
	ld	hl,EXPTBL
	add	hl,bc
	bit	7,(hl)
	jr	z,NOEXP1@sym
EXP1@sym:	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	and	%00001100
	or	c
	or	#80
	ld	c,a
NOEXP1@sym:	ld	a,c
	exx
	ei
	ret

;--- Subrutina para la conexion del slot A en pag. 1 si es distinto de B

PUTSLOT1@sym:	cp	b
	ret	z
	ld	h,#40
	call	ENASLT
	ei
	ret

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
	jr	z,NOEXP2@sym
EXP2@sym:	inc	hl
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
NOEXP2@sym:	ld	a,c
	exx
	ret

;--- Subrutina para la conexion del slot A en pag. 2 si es distinto de B

PUTSLOT2@sym:	cp	b
	ret	z
	ld	h,#80
	call	ENASLT
	ei
	ret

	;ds      250
;NEWSP@sym:        ;

ENDRES@sym:	;                        ;Fin de la parte residente en pagina 3
	endm

RESCODE1:	PARTRES
RESCODE2:	PARTRES



;*****************************
;***                       ***
;***  RUTINAS EN PAGINA 1  ***
;***                       ***
;*****************************

PARTRE1:	org	#4100

;---------------------------------------------
;---  PUNTO DE EJECUCION Y TABLA DE SALTO  ---
;---------------------------------------------

MAXFUN:	equ	32

FUNBASE:	;
	jp	FUN0
	jp	FUN1
	jp	FUN2
	jp	FUN3
	jp	FUN4
	jp	FUN5
	jp	FUN6
	jp	FUN7
	jp	FUN8
	jp	FUN9
	jp	FUN10
	jp	FUN11
	jp	FUN12
	jp	FUN13
	jp	FUN14
	jp	FUN15
	jp	FUN16
	jp	FUN17
	jp	FUN18
	jp	FUN19
	jp	FUN20
	jp	FUN21
	jp	FUN22
	jp	FUN23
	jp	FUN24
	jp	FUN25
	jp	FUN26
	jp	FUN27
	jp	FUN28
	jp	FUN29
	jp	FUN30
	jp	FUN31
	jp	FUN32

ENTRYP:	ex	af,af
	ld	a,MAXFUN
	cp	c
	jpmn	BADFUN

	ld	a,c
	exx
	ld	c,a
	ld	b,0
	ld	l,a
	ld	h,0
	add	hl,hl
	add	hl,bc
	ld	bc,FUNBASE
	add	hl,bc
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(SALTOFUN+1),hl
	exx
	ex	af,af
SALTOFUN:	jp	0

BADFUN:	ex	af,af
	scf
	ret


;-------------------
;---  FUNCIONES  ---
;-------------------

	;--- Funcion 0: Resetea NESMAN. Libera todos los segmentos
	;    excepto los de TPA y el de NESMAN,
	;    y limpia la MAT de este ultimo

FUN0:	call	SET_EXECU
	call	SAVE_DOS_VARS
	call	_FUN0
	call	LOAD_DOS_VARS
	jp	RES_EXECU

_FUN0:	call	_FUN32	;Libera tambien los segmentos de IN

	ld	a,#CD	;#CD = Codigo de "call"
	ld	(CALLZ),a
	ld	a,#C9
	ld	(CHKCLEAN),a	;#C9 = Codigo de "ret"
	call	DESTLIST

FUN045:	ld	hl,TABSEGS+10	;Codigo comun funciones 0, 4 y 5
	ld	b,256-10
BUCF0:	push	bc
	ld	a,(hl)
	or	a
	jr	z,FBUCF0
	inc	hl
	ld	b,(hl)
	or	a
	call	CHKCLEAN	;Siempre devuelve Cy=0 en fun. 0 y 4...
	jr	c,FBUCF0	;...por tanto este es ignorado en f. 0 y 4
	or	a
	jr	z,FBUCF0
	bit	4,a
	res	4,a
CALLZ:	call	LIB04	"call" en fun. 0/5, "call z" en fun. 4/5
FBUCF0:	inc	hl
	pop	bc
	djnz	BUCF0
	call	CLEAN4
	ret

LIB04:	push	hl
	ld	hl,NUMSEGS
	dec	(hl)
	ld	d,a
	ld	a,b
	ld	b,d
	call	FRE_SEG	;Libera segmento y lo borra de la tabla
	pop	hl
	dec	hl
	ld	(hl),0
	inc	hl
	ld	(hl),0

	ret

	;Comprobador de segmento vacio
	;Entrada: Cy=0, Salida: Cy=0 si el segmento esta limpio
	;A=Slot, B=Segmento

CHKCLEAN:	nop		;"nop" para funcion 5, "ret" para funciones 0 y 4
	ld	d,a
	push	hl,de,bc

	call	SAVEP2
	ld	h,#80
	call	ENASLT
	ei

	pop	bc
	ld	a,b
	push	bc
	call	PUT_P2

	ld	hl,#8004
	ld	b,256-4
	ld	c,0
CHKCLE:	ld	a,(hl)
	inc	hl
	or	c
	ld	c,a
	djnz	CHKCLE

	;push    af
	;ld      a,(SAVESLOT)
	;ld      h,#80
	;call    ENASLT
	;ei
	;ld      a,(SAVESEG)
	;call    PUT_P2
	;pop     af
	call	LOADP2

	pop	bc,de,hl
	or	a
	ld	a,d
	ret	z
	scf
	ret

SAVESLOT:	db	0
SAVESEG:	db	0


	;--- Funcion 1: Devuelve informacion sobre NESMAN
	;    Entrada: -
	;    Salida:  HL= NewHIGHMEM
	;             IX= OldHIGHMEM
	;             B = Slot del segmento reservado
	;             C = Segmento reservado
	;             A = Version principal de NESMAN
	;             DE= Version secundaria de NESMAN
	;             Cy= 1 si ya se estaba ejecutado NESMAN

FUN1:	ld	de,34*256+IDNMAN	;Es ejecutado por EXTBIO en pagina 3
	ld	c,1
	jp	EXTBIO


	;--- Funcion 2: Informacion general sobre la memoria
	;    Entrada:  -
	;    Salida:   A = Numero total de segmentos
	;              B = Numero de segmentos exclusivos
	;              C = Numero total de segmendos libres
	;              D = Numero de segmentos libres en el map. primario
	;              E = Numero de listas internas
	;              IX = Direccion de la tabla de segmentos
	;              IY = Direccion de la tabla de listas

FUN2:	call	SET_EXECU
	call	_FUN2
	jp	RES_EXECU

_FUN2:	ld	de,#0401
	call	EXTBIO
	ex	de,hl
	inc	de
	inc	de
	ld	a,(de)
	dec	de
	dec	de
	push	af
	ld	bc,0
	ld	hl,0

BUCF2:	ld	a,(de)	;Recorre toda la tabla de mapeadores
	or	a
	jr	z,FBUCF2
	inc	de
	inc	de
	ld	a,(de)
	ld	c,a
	add	hl,bc
	ld	a,h
	or	a
	jr	nz,PON251
	inc	de
	inc	de
	inc	de
	inc	de
	inc	de
	inc	de
	jr	BUCF2

FBUCF2:	ld	a,l	;C = Total seg. libres
	cp	251
	jrmni	OKFBF2
PON251:	ld	c,251
OKFBF2:	ld	c,a

	pop	af
	cp	251
	jrmni	OKFBF22
	ld	a,251
OKFBF22:	ld	d,a	;D = Seg. libres map. prim.

	ld	e,0
	ld	hl,TABSEGS
	ld	b,0
BUCF22:	ld	a,(hl)
	bit	4,a
	jr	z,NEXTBF22
	inc	e
NEXTBF22:	inc	hl
	inc	hl
	djnz	BUCF22
	ld	b,e	;B = Seg. excl.

	ld	a,(NUMLISTS)
	ld	e,a
	ld	a,(NUMSEGS)	;A = Seg. totales
	ld	ix,TABSEGS
	ld	iy,TABLISTS
	ret


	;--- Funcion 3: Informacion sobre un segmento
	;    Entrada:   A = Numero de segmento
	;    Salida:    A preservado
	;               B = Slot del segmento (0 si no existe)
	;               C = Segmento fisico
	;               Cy = 1 si es segmento exclusivo
	;               HL = Memoria total libre en el segmento
	;               DE = Tamanyo del mayor bloque encontrado en el seg.

FUN3:	call	SET_EXECU
	call	_FUN3
	jp	RES_EXECU

_FUN3:	ld	e,a
	ld	l,a
	ld	h,0
	add	hl,hl
	ld	bc,TABSEGS	;Obtiene slot, segmento
	add	hl,bc
	ld	b,(hl)
	inc	hl
	ld	c,(hl)
	ld	d,a
	ld	a,b
	or	a
	ld	a,d
	ret	z	;Termina si el segmento no existe
	ld	a,e

	push	af,bc
	call	SAVEP2
	call	PUT_S2
	call	MIDLIB	;Mide memoria libre y bloque >
	call	LOADP2
	pop	bc,af

	bit	4,b	;Es exclusivo?
	res	4,b
	scf
	ret	nz
	or	a
	ret


	;--- Funcion 4: Reserva de un bloque de memoria
	;    Entrada: HL = Tamanyoo requerido
	;    Salida:  HL = Direccion, empezando en #8000
	;             A  = Segmento
	;             Cy = 1 si hay error (no queda memoria libre)

FUN4:	call	SET_EXECU
	call	MALLOC	;_FUN4
	jp	RES_EXECU

;_FUN4:       jp      MALLOC


	;--- Funcion 5: Reserva un bloque en un segmento determinado
	;    Entrada: A  = Segmento
	;             HL = Tamanyo requerido
	;    Salida:  A preservado
	;             HL = Direccion del bloque
	;             Cy = 1 si hay error (no queda espacio o no ex. seg.)

FUN5:	call	SET_EXECU
	call	_FUN5
	jp	RES_EXECU

_FUN5:	ld	b,a

	dec	hl	;Error si el tamanyo requerido
	ld	a,h	;es >16384-256 (#3F00)
	and	%11000000
	scf
	ret	nz
	inc	hl
	call	REQ2REAL

	ld	a,b
	call	SAVEP2
	call	PUT_S2
	ret	c

	ld	hl,(TAMREAL)
	push	bc
	call	MAXMIN	;Tamanyo encontrado en HL, dir. en DE
	pop	bc
	ld	a,b
	call	c,LOADP2
	ret	c
	ld	(DIRFND),de
	push	bc

OKF14:	ex	de,hl
	ld	de,(TAMREQ)
	dec	de
	dec	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	ld	a,#C0
	ld	de,(TAMREAL)
	call	ADJMAT	;Pone los bits adecuados de MAT a 1

	call	LOADP2
	ld	hl,(DIRFND)
	inc	hl
	inc	hl
	pop	bc
	ld	a,b
	or	a

	ret


	;--- Funcion 6: Libera un bloque de memoria
	;    Entrada: A  = Segmento del bloque
	;             HL = Direccion del bloque
	;    Salida:  Cy = 1 si el segmento no existe, o es el 0 o el 3

FUN6:	call	SET_EXECU
	call	MFREE	;_FUN6
	jp	RES_EXECU

;FUN6:       jp      MFREE


	;--- Funcion 7: Reserva un segmento nuevo
	;    Entrada: Cy = 1 para reservarlo exclusivo
	;    Salida:  Cy = 1 si no quedan segmentos libres
	;             A  = Segmento

FUN7:	call	SET_EXECU
	call	_FUN7
	jp	RES_EXECU

_FUN7:	push	af
	pop	de
	ld	a,(NUMSEGS)
	cp	255
	scf
	ret	z

	call	BUSFREE
	ld	d,a
	push	hl,de	;D=Seg, E=excl. o no, HL=Dir. tabla
	ld	a,(STRICT_SLOT)
	or	a
	jr	nz,FUN7_2
	ld	a,(#F344)
	or	%0 010 0000
FUN7_2:	ld	b,a
	ld	a,1
	call	SAVE_DOS_VARS
	call	ALL_SEG
	call	LOAD_DOS_VARS
	pop	de,hl
	ret	c

	call	SAVEP2
	ld	(hl),b
	inc	hl
	ld	(hl),a
	ld	a,d
	call	PUT_S2
	push	hl,de
	call	CLEAN
	ld	hl,NUMSEGS
	inc	(hl)

	call	LOADP2
	pop	de,hl
	dec	hl
	or	a
	bit	0,e
	ret	z
	set	4,(hl)
	or	a
	ret

STRICT_SLOT:	db	0	;Slot de reserva, 0=cualquiera

	;--- Funcion 8: Libera un segmento determinado
	;    Entrada: A = Segmento
	;    Salida:  Cy= 1 si seg. no existe o es <4

FUN8:	call	SET_EXECU
	call	_FUN8
	jp	RES_EXECU

_FUN8:	cp	4
	jrmni	F6E
	ld	l,a
	ld	h,0
	add	hl,hl
	ld	bc,TABSEGS
	add	hl,bc
	ld	a,(hl)
	or	a
	jr	z,F6E
	ld	(hl),0
	res	4,a
	ld	b,a
	inc	hl
	ld	a,(hl)
	ld	(hl),0
	call	SAVE_DOS_VARS
	call	FRE_SEG
	call	LOAD_DOS_VARS
	ld	hl,NUMSEGS
	dec	(hl)
	ret

F6E:	scf
	ret


	;--- Funcion 9: Limpieza de un segmento
	;    Entrada:  A = Segmento
	;    Salida:   A preservado
	;              Cy = 1 si es el segmento 0 o el 3 o no existe

FUN9:	call	SET_EXECU
	call	_FUN9
	jp	RES_EXECU

_FUN9:	or	a
	jp	z,F6E
	cp	3
	jp	z,F6E
	cp	4
	push	af
	call	z,CLEAN4
	pop	af
	ret	z

	call	SAVEP2
	call	PUT_S2
	push	af
	call	nc,CLEAN
	pop	af
	call	LOADP2

	ret


	;--- Funcion 10: Cambia el estado de un segmento
	;    Entrada: A = Segmento
	;             Cy= 1 para hacerlo exclusivo, 0 para hace lo normal
	;    Salida:  Cy= 1 si seg. no exi te o es <5

FUN10:	call	SET_EXECU
	call	_FUN10
	jp	RES_EXECU

_FUN10:	ld	d,%0 001 0000
	jr	c,FUN70
	ld	d,0

FUN70:	cp	5
	jrmn	F6E
	ld	l,a
	ld	h,0
	add	hl,hl
	ld	bc,TABSEGS
	add	hl,bc
	ld	a,(hl)
	or	a
	jr	z,F6E
	and	%1 110 1111
	or	d
	ld	(hl),a
	or	a
	ret


	;--- Funcion 11: Establece un determinado segmento en pag. 2
	;    Entrada: A = Numero de segmento
	;    Salida:  Cy= 1 si ese segmento no existe

FUN11:	call	SET_EXECU
	call	PUT_S2	;_FUN11
	jp	RES_EXECU

_FUN11:	jp	PUT_S2


	;--- Funcion 12: Lee un byte de un segmento
	;    Entrada:  A = Segmento
	;              HL= Direccion
	;    Salida:   A,HL preservados
	;              B = Dato
	;              Cy= 1 si el segmento no existe

FUN12:	call	SET_EXECU
	call	_FUN12
	jp	RES_EXECU

_FUN12:	ld	de,RD_SEG
	jr	FUN910


	;--- Funcion 13: Escribe un dato en un segmento
	;    Entrada:  A = Segmento
	;              HL= Direccion
	;              B = Dato
	;    Salida:   A,HL preservados
	;              Cy= 1 si el segmento no existe

FUN13:	call	SET_EXECU
	call	_FUN13
	jp	RES_EXECU

_FUN13:	ld	de,WR_SEG

FUN910:	ld	(F9VAR+1),de	;Codigo comun funciones 9 y 10
	push	af,hl
	ld	l,a
	ld	h,0
	add	hl,hl
	ld	a,b
	ld	(SAVESEG),a	;Si es escritura, guarda el dato
	ld	bc,TABSEGS
	add	hl,bc
	ld	a,(hl)
	or	a
	jr	z,F9E

	ld	a,2
	push	hl
	call	GETSLOT
	ld	a,b
	ld	(SAVESLOT),a
	pop	hl
	ld	a,(hl)
	push	hl
	ld	h,#80
	res	4,a
	call	ENASLT
	ei
	pop	hl
	inc	hl
	ld	a,(SAVESEG)	;Si es escritua, recupera el dato
	ld	e,a
	ld	a,(hl)
	pop	hl
F9VAR:	call	0	;RD_SEG o WR_SEG

	push	af,hl
	ld	a,(SAVESLOT)
	ld	h,#80
	call	ENASLT
	ei
	pop	hl,af
	ld	b,a
	pop	af
	or	a
	ret

F9E:	pop	hl,af
	scf
	ret


	;--- Funcion 14: Transferencia de bloques entre segmentos
	;    Entrada: A-IX = Origen
	;             B-IY = Destino
	;             HL = Longitud
	;    Salida:  Cy = 1 si alguno de los segmentos no existe

FUN14:	call	SET_EXECU
	call	_FUN14
	jp	RES_EXECU

_FUN14:	ld	(SAVESP),sp
	push	ix,iy,hl,bc
	ld	l,a
	ld	h,0
	add	hl,hl
	ld	bc,TABSEGS
	add	hl,bc
	ld	a,(hl)
	or	a
	jr	z,F11E
	res	4,a
	ld	(LDIR_SLOT_O),a	;Origen
	inc	hl
	ld	a,(hl)
	ld	(LDIR_SEG_O),a

	pop	bc
	ld	l,b
	ld	h,0
	add	hl,hl
	ld	bc,TABSEGS
	add	hl,bc
	ld	a,(hl)
	or	a
	jr	z,F11E
	res	4,a
	ld	(LDIR_SLOT_D),a	;Destino
	inc	hl
	ld	a,(hl)
	ld	(LDIR_SEG_D),a

	ld	a,2
	call	GETSLOT
	ld	a,b
	ld	(SAVESLO2),a	;Slot orig. p. 2
	ld	a,c
	ld	(SAVESEG2),a	;Segmento orig. p. 2

	ld	a,(LDIR_SLOT_D)	;Conecta destino en pag. 2
	cp	b
	ld	h,#80
	call	nz,ENASLT
	ei
	ld	a,(LDIR_SEG_D)
	call	PUT_P2

	pop	bc,de,hl	;Copia bloque
	res	7,h
	set	6,h
	set	7,d
	res	6,d
	push	hl,de
	pop	iy,ix
	ld	a,(LDIR_SLOT_O)
	ld	l,a
	ld	a,(LDIR_SEG_O)
	ld	h,a
CALLP3:	call	0

	ld	a,(LDIR_SLOT_D)
	ld	b,a
	ld	a,(SAVESLO2)	;Restaura pag. 2
	cp	b
	ld	h,#80
	call	nz,ENASLT
	ei
	ld	a,(SAVESEG2)
	call	PUT_P2

	or	a
	ret

F11E:	ld	sp,(SAVESP)
	scf
	ret

SAVESP:	dw	0
SAVESLO2:	db	0
SAVESEG2:	db	0
LDIR_SLOT_O:	db	0
LDIR_SEG_O:	db	0
LDIR_SLOT_D:	db	0
LDIR_SEG_D:	db	0


	;--- Funcion 15: Transferencia TPA -> Segmento
	;    Entrada: IX = Origen
	;             B-IY = Destino
	;             HL = Longitud
	;    Salida:  Cy = 1 si el segmento B no existe

FUN15:	call	SET_EXECU
	call	_FUN15
	jp	RES_EXECU

_FUN15:	ld	a,ixh
	rlca
	rlca
	and	%11
	jp	_FUN14	;ERA "jp FUN14" EN v. 1.21


	;--- Funcion 16: Transferencia Segmento -> TPA
	;    Entrada: A-IX = Origen
	;             IY = Destino
	;             HL = Longitud
	;    Salida:  Cy = 1 si el segmento B no existe

FUN16:	call	SET_EXECU
	call	_FUN16
	jp	RES_EXECU

_FUN16:	ld	c,a
	ld	a,iyh
	rlca
	rlca
	and	%11
	ld	b,a
	ld	a,c
	jp	_FUN14	;ERA "jp FUN14" EN v. 1.21


	;--- Funcion 17: Libera todos los segmentos excepto los exclusivos

FUN17:	call	SET_EXECU
	call	_FUN17
	jp	RES_EXECU

_FUN17:	call	CLEAN4
	ld	a,#CC	;#CC = Codigo de "call z"
	ld	(CALLZ),a
	ld	a,#C9
	ld	(CHKCLEAN),a	;#C9 = Codigo de "ret"
	call	DESTLIST
	jp	FUN045

DESTLIST:	xor	a	;Si funcion 0 o 17, limpia tabla de listas
	ld	(NUMLISTS),a
	ld	hl,TABLISTS
	ld	de,TABLISTS+1
	ld	bc,256*3-1
	ld	(hl),0
	ldir
	ret

	;--- Funcion 18: Libera los segmentos limpios
	;    Entrada: Cy=1 para liberar tambien los exclusivos

FUN18:	call	SET_EXECU
	call	_FUN18
	jp	RES_EXECU

_FUN18:	ld	a,#CD
	jr	c,F52
	ld	a,#CC
F52:	ld	(CALLZ),a
	xor	a	;0 = Codigo de "nop"
	ld	(CHKCLEAN),a
	jp	FUN045


	;--- Funcion 19: Llamada indirecta a una funcion

FUN19:	call	SET_EXECU
	call	_FUN19
	jp	RES_EXECU

_FUN19:	push	af
	pop	de
	ld	a,c
	cp	19	;Error si es la funcion 19
	scf
	ret	z
	push	de
	pop	af

	jp	ENTRYP


	;--- Funcion 20: Crea una lista
	;    Entrada: Cy = 1 para crearla externa (no en TABLISTS)
	;    Salida:  B = 1 si no hay memoria libre (y Cy=1)
	;                 2 si ya hay 255 tablas internas (y Cy=1)
	;             A-IX = Localizador (si es interna, solo A)

FUN20:	call	SET_EXECU
	call	_FUN20
	jp	RES_EXECU

_FUN20:	ld	a,-1
	ld	(F20LNUM),a
	ld	hl,0
	ld	(TAB_DIR),hl
	ld	de,L_DIR
	jr	c,F20EX

	;--- Interna

	ld	a,(NUMLISTS)
	cp	255
	ld	b,2
	scf
	ret	z

	ld	hl,TABLISTS
	ld	b,0
BUCF20:	ld	a,(hl)
	or	a
	jr	z,OKBUC20
	inc	hl
	inc	hl
	inc	hl
	inc	b
	jr	BUCF20
OKBUC20:	ld	a,b
	ld	(F20LNUM),a
	ld	(TAB_DIR),hl
	ex	de,hl
	ld	hl,NUMLISTS
	inc	(hl)

	;--- Externa / continuacion de la interna

F20EX:	push	de	;Reserva memoria para el descriptor
	ld	hl,12
	call	MALLOC
	pop	de
	jr	nc,F20EX2	;Fin si hay error...
	ld	b,1
	ld	hl,TAB_DIR
	ld	a,(TAB_DIR+1)	;...pero primero limpiamos la entrada
	cp	(hl)	;de la tabla si la habiamos rellenado
	scf
	ret	z
	ld	(hl),0
	inc	hl
	ld	(hl),0
	inc	hl
	ld	(hl),0
	ret

F20EX2:	ld	b,a	;Guarda la dir+seg del descriptor creado
	ld	(de),a	;en L_DIR y en (DE)
	inc	de	;(DE)=Tabla de listas si interna
	ld	a,l
	ld	(de),a	;(DE)=L_DIR si interna
	inc	de
	ld	a,h
	ld	(de),a
	ld	a,b
	ld	(L_DIR),a
	ld	(L_DIR+2),hl

	push	hl	;Inicializa descriptor
	pop	ix
	call	GETLIST
	ld	ix,LISTA
	call	L_INIT
	call	PUTLIST

	ld	a,(F20LNUM)
	cp	-1
	jr	z,ERAEX20

ERAIN20:	ld	ix,0
	or	a
	ld	b,0
	ret

ERAEX20:	ld	a,(L_DIR)
	ld	ix,(L_DIR+1)
	or	a
	ld	b,0
	ret

F20LNUM:	db	0


	;--- Funcion 21: Obtiene informacion sobre una lista
	;    Entrada:  A-IX = Localizador (si es interna, solo A)
	;    Salida:   A-IX = Localizador convertido a seg+dir
	;              B-IY = Puntero al elemento en curso
	;              D-HL = Numero de elementos
	;              Cy = 1 si no existe esa lista o segmento

FUN21:	call	SET_EXECU
	call	_FUN21
	jp	RES_EXECU

_FUN21:	call	GETLIST
	ret	c
	ld	ix,LISTA
	call	L_GETP
	push	af,hl	;Elemento actual
	call	L_GETN
	push	af,hl	;Numero de elementos
	ld	a,(L_DIR)
	ld	ix,(L_DIR+1)
	pop	hl,de
	pop	iy,bc
	or	a
	ret


	;--- Funcion 22: Destruye una lista
	;    Entrada:  A-IX = Localizador (si es interna, solo A)
	;    Salida:   Cy = 1 si no existe esa lista o segmento

FUN22:	call	SET_EXECU
	call	_FUN22
	jp	RES_EXECU

_FUN22:	ld	c,a
	ld	l,a
	call	GETLIST
	ret	c
	ld	a,ixh
	or	ixl
	jr	nz,F232

	;--- Si es interna, hay que borrar su entrada de la tabla de listas

	ld	b,0
	ld	h,0
	add	hl,hl
	add	hl,bc
	ld	bc,TABLISTS
	add	hl,bc
	ld	(hl),0
	inc	hl
	ld	(hl),0
	inc	hl
	ld	(hl),0
	ld	hl,NUMLISTS
	dec	(hl)

	;--- Destruye la lista y su descriptor

F232:	ld	ix,LISTA
	call	L_DEST
	ld	a,(L_DIR)
	ld	hl,(L_DIR+1)
	call	MFREE
	ret


	;--- Funcion 23: Consulta/modifica el puntero de una lista
	;    Entrada:  A-IX = Localizador (si es interna, solo A)
	;              B = Metodo:
	;                  0 = Solo consultar
	;                  1 = Establecer el puntero al ppio
	;                  2 = Establecer el puntero al final
	;                  3 = Hacer avanzar el puntero
	;                  4 = Hacer retroceder el puntero
	;                  5 = Establecer el puntero en un elemento dado
	;                  6 = Establecer el puntero con un valor dado
	;              H-IY = Numero de elemento (si B=5)
	;                     Nuevo puntero (si B=6)
	;    Salida:   Cy = 1 si no existe esa lista o segmento
	;              A-IX = Puntero tras la llamada
	;              B = Datos del puntero tras la llamada:
	;                  0 = Ninguna de las siguientes
	;                  1 = El puntero esta al ppio de la lista
	;                  2 = El puntero esta al final de la lista
	;                  3 = Solo hay un elemento en la lista
	;                  4 = La lista esta vacia
	;                #80 = Error: B=5 pero no existe ese elemento
	;                #81 = Error: Metodo desconocido

FUN23:	call	SET_EXECU
	call	_FUN23
	jp	RES_EXECU

_FUN23:	call	GETLIST
	ret	c
	ld	ix,LISTA
	ld	a,b
	or	a
	jr	z,F24_0
	dec	a
	jr	z,F24_1
	dec	a
	jr	z,F24_2
	dec	a
	jr	z,F24_3
	dec	a
	jr	z,F24_4
	dec	a
	jr	z,F24_5
	dec	a
	jr	z,F24_6
	ld	b,#81
	or	a
	ret

F24_0:	ld	b,4	;Consultar
	call	L_EMPTY
	jr	c,F24_F
	ld	b,0
	call	L_ISF
	jr	nc,F24_01
	ld	b,1
F24_01:	call	L_ISL
	jr	nc,F24_F
	set	1,b
F24_F:	or	a
	call	PUTLIST
	call	L_GETP
	push	hl
	pop	ix
	ret

F24_1:	call	L_SETPF
	jr	F24_0

F24_2:	call	L_SETPL
	jr	F24_0

F24_3:	call	L_FWD
	jr	F24_0

F24_4:	call	L_REW
	jr	F24_0

F24_5:	ld	b,h
	push	iy
	pop	de
	call	L_SEEK
	jr	nc,F24_0
	ld	b,#80
	or	a
	ret

F24_6:	ld	a,h
	push	iy
	pop	hl
	call	L_SETP
	jr	F24_0


	;--- Funcion 24: Inserta un elemento en la lista desde TPA
	;    Entrada:  A-IX = Localizador (si es interna, solo A)
	;              B  = Donde insertar el elemento:
	;                   0: Despues del elemento actualmente apuntado
	;                   1: Antes del elemento actualmente apuntado
	;                   2: Antes del primer elemento (al ppio de lista)
	;                   3: Despues del ultimo elemento (al fin de lista)
	;              HL = Longitud del elemento
	;              IY = Direccion del elemento en TPA
	;    Salida:   A  = 1 si no hay memoria libre (y Cy=1)
	;                   2 si ese segmento o lista no existe (y Cy=1)
	;                   3 si el metodo es desconocido (y Cy=1)
	;                   4 si longitud cero (y Cy=1)

FUN24:	call	SET_EXECU
	push	af
	ld	a,-1
	ld	(LDIR_TPA),a
	pop	af
	call	_FUN24
	ld	a,b
	jp	RES_EXECU

;FUN24:      call    _FUN24
;            ld      a,b
;            ret

_FUN24:	ld	d,a
	ld	e,b
	ld	a,h	;Error si tamanyo 0
	or	l
	ld	b,4
	scf
	ret	z
	ld	a,d
	ld	b,e

	call	GETLIST	;Obtiene descriptor
	ld	a,b
	ld	b,2
	ret	c
	;ld      b,a

	ld	c,a	;Metodo desconocido?
	and	%11111100
	ld	b,3
	ret	nz
	ld	a,c

	ld	ix,LISTA	;Introduce el elemento
	;ld      a,b
	push	hl
	pop	bc
	push	iy
	pop	hl
	call	L_PUTE
	ld	b,1
	ret	c

	call	PUTLIST
	ld	b,0
	or	a
	ret


	;--- Funcion 25: Obtencion y/o eliminacion de un elemento a TPA
	;    Entrada:  A-IX = Localizador (si es interna, solo A)
	;              B = Que elemento obtener y/o eliminar
	;                  0 = El actual
	;                  1 = El primero
	;                  2 = El ultimo
	;              H = Accion a realizar:
	;                  0 = Solo consultar tamanyo
	;                  1 = Solo obtener
	;                  2 = Solo eliminar
	;                  3 = Obtener y eliminar
	;              IY = Direccion de destino en TPA
	;    Salida:   A = 1 si ese segmento o lista no existe (y Cy=1)
	;                  2 si la lista esta vacia (y Cy=1)
	;                  3 si B o H es desconocido (y Cy=1)
	;              BC = Tamanyo del elemento

FUN25:	call	SET_EXECU
	push	af
	ld	a,-1
	ld	(LDIR_TPA),a
	pop	af
	call	_FUN25
	jp	RES_EXECU

_FUN25:	call	GETLIST
	ld	a,1
	ret	c
	ld	ix,LISTA
	call	L_EMPTY
	ld	a,2
	ret	c

	;--- Guarda parametros de entrada y obtiene el tamanyo del elem.

	ld	a,h
	ld	(F25_A),a	;Guarda la accion a realizar
	and	%11111100
	jr	nz,F25FE
	ld	a,b
	ld	(F25_E),a	;Guarda el elemento a obtener
	cp	3
	jr	nc,F25FE
	ld	(F25_D),iy	;Guarda direccion de destino

	ld	iy,L_GETP
	or	a
	jr	z,F252
	ld	iy,L_GETF
	dec	a
	jr	z,F252
	ld	iy,L_GETL

F252:	ld	hl,F253
	push	hl
	jp	(iy)	;Ejecuta el F_GETx correspondiente
F253:	ld	(F25_P),a	;Guarda el puntero obtenido
	ld	(F25_P+1),hl

	dec	hl
	dec	hl
	call	_FUN12	;ERA "call _FUN12" en v. 1.21
	ld	e,b
	push	de
	inc	hl
	call	_FUN12
	pop	de
	ld	d,b
	dec	de	;Decrementa el tamanyo de los punteros
	dec	de
	dec	de
	dec	de
	dec	de
	dec	de
	ld	(F25_T),de	;Guarda tamanyo

	ld	a,(F25_A)	;Si solo se pedia consultar,
	or	a	;salta directamente al final
	jr	z,F25F

	;--- Obtencion del elemento si se pide

F25_O:	;ld      a,(F25_A)
	and	1
	jr	z,F25_B

	ld	a,(F25_P)
	ld	hl,(F25_P+1)
	ld	de,(F25_D)
	ld	ix,LISTA
	call	L_GETE

	;--- Eliminacion del elemento si se pide

F25_B:	ld	a,(F25_A)
	and	2
	jr	z,F25F

	ld	a,(F25_E)
	ld	ix,LISTA
	call	L_DELE

	;--- Final: devuelve el tamanyo del elemento

F25F:	ld	bc,(F25_T)
	xor	a
	call	PUTLIST
	ret

	;--- Final con error 3

F25FE:	ld	a,3
	scf
	ret

F25_A:	db	0	;Accion a realizar
F25_E:	db	0	;Que elemento
F25_P:	ds	3	;Puntero al elemento
F25_T:	dw	0	;Tamanyo del elemento
F25_D:	dw	0	;Direccion de destino


	;--- Funcion 26: Grabacion de una lista en disco
	;    Entrada:  A-IX = Localizador (si es interna, solo A)
	;              HL = Ruta + nombre del fichero y B=255
	;                   (creara ese fichero), o
	;              B  = FH de un fichero abierto
	;              (grabara en ese fichero a partir del puntero actual)
	;    Salida:   Cy=1 y A=Error de disco si lo hay,
	;              o Cy=1 y A=1 si no existe la lista/seg

FUN26:	call	SET_EXECU
	call	_FUN26
	jp	RES_EXECU

_FUN26:	call	GETLIST
	ld	a,1
	ret	c

	ld	ix,LISTA
	ex	de,hl
	ld	hl,DISKBUF
	jp	L_SAVE


	;--- Funcion 27: Carga de una lista de disco
	;    Entrada:  A-IX = Localizador (si es interna, solo A)
	;              HL = Ruta + nombre del fichero y B=255
	;                   (creara ese fichero), o
	;              B  = FH de un fichero abierto
	;              (grabara en ese fichero a partir del puntero actual)
	;    Salida:   Cy=1 y A=Error de disco si lo hay, o:
	;                     A=1 si no existe la lista/seg
	;                     A=2 si no hay memoria
	;                     A=3 si el elemento es demasiado grande
	;              B-DE = Numero de elementos segun cabecera
	;              C-HL = Numero de elementos realmente leidos
	;              Si B=255, el fichero es cerrado al final

FUN27:	call	SET_EXECU
	call	_FUN27
	jp	RES_EXECU

_FUN27:	call	GETLIST
	ld	a,1
	ret	c

	ld	ix,LISTA
	ex	de,hl
	ld	hl,DISKBUF
	call	L_LOAD
	ret	nc
	inc	a
	scf
	ret


	;--- Funcion 28: Inserta un elemento en la lista desde un segmento
	;    Entrada:  A-IX = Localizador (si es interna, solo A)
	;              HL = Longitud del elemento (bits 0 a 13)
	;              H  = Donde insertar el elemento (bits 15 y 14):
	;                   0: Despues del elemento actualmente apuntado
	;                   1: Antes del elemento actualmente apuntado
	;                   2: Antes del primer elemento (al ppio de lista)
	;                   3: Despues del ultimo elemento (al fin de lista)
	;              B-IY = Direccion del elemento
	;    Salida:   A  = 1 si no hay memoria libre (y Cy=1)
	;                   2 si ese segmento o lista no existe (y Cy=1)
	;                   3 si el metodo es desconocido (y Cy=1)
	;                   4 si longitud cero (y Cy=1)

FUN28:	call	SET_EXECU
	call	_FUN28
	jp	RES_EXECU

_FUN28:	call	SET_EXECU
	push	af	;Convierte la entrada al formato
	xor	a	;de la funcion 24
	ld	(LDIR_TPA),a
	ld	a,b
	ld	(LDIR_SEG),a
	ld	a,h
	rlca
	rlca
	and	%11
	ld	b,a
	res	7,h
	res	6,h
	pop	af
	call	_FUN24
	ld	a,b
	jp	RES_EXECU


	;--- Funcion 29: Obtencion y/o eliminacion de un elemento
	;                a cualquier segmento
	;    Entrada:  A-IX = Localizador (si es interna, solo A)
	;              B = Que elemento obtener y/o eliminar
	;                  0 = El actual
	;                  1 = El primero
	;                  2 = El ultimo
	;              H = Accion a realizar:
	;                  0 = Solo consultar tamanyo
	;                  1 = Solo obtener
	;                  2 = Solo eliminar
	;                  3 = Obtener y eliminar
	;              L-IY = Direccion de destino
	;    Salida:   A = 1 si ese segmento o lista no existe (y Cy=1)
	;                  2 si la lista esta vacia (y Cy=1)
	;                  3 si B o H es desconocido (y Cy=1)
	;              BC = Tamanyo del elemento

FUN29:	call	SET_EXECU
	call	_FUN29
	jp	RES_EXECU

_FUN29:	call	SET_EXECU
	push	af
	xor	a
	ld	(LDIR_TPA),a
	ld	a,l
	ld	(LDIR_SEG),a
	pop	af
	call	_FUN25
	jp	RES_EXECU


	;--- Funcion 30: Reserva de 4 segmentos para InterNestor
	;                (los 4 en el mismo slot)
	;    Entrada: -
	;    Salida:  A=0 y Cy=0 si OK
	;             Cy=0 si error:
	;             A=1: No hay ningun maper con 4 segmentos libres
	;               2: Ya hay segmentos reservados para IN

FUN30:	call	SET_EXECU
	call	_FUN30
	jp	RES_EXECU

_FUN30:	ld	a,(IN_SEGS)
	or	a
	ld	a,2
	scf
	ret	nz

	;Busca slot con 4 segmentos libres

	ld	de,#0401	;Obtiene tabla de vars. de
	call	EXTBIO	;las mapeadores
	push	hl
	pop	ix

FUN30_BUC:	ld	a,(ix)	;Busca hasta encontrar un slot
	or	a	;con al menos 4 segmentos libres
	jr	z,FUN30_E
	ld	a,(ix+2)
	cp	4
	jrmyi	FUN30_OK
	ld	bc,8
	add	ix,bc
	jr	FUN30_BUC

FUN30_E:	ld	a,1	;Error si no hay ninguno
	scf
	ret

FUN30_OK:	call	SAVEP2
	ld	a,(ix)	;Reserva los 4 segmentos
	ld	(IN_SLOT),a
	ld	(STRICT_SLOT),a
	ld	b,4
	ld	hl,IN_SEGS
FUN30_BUC2:	push	bc,hl
	scf		;                ;Lo reserva exclusivo
	call	_FUN7
	pop	hl
	ld	(hl),a
	push	hl
	call	PUT_S2
	ld	hl,#8000	;Rellena el segmento con #C9 (RET)
	ld	de,#8001	;por si se llama accidentalmente
	ld	bc,#3FFF	;a alguna rutina de InterNestor
	ld	(hl),#C9	;antes de instalarlo
	ldir
	ld	a,(IN_SLOT)
	ld	(#8000),a	;Pone slot en posicion 0
	pop	hl
	push	hl
	ld	a,(hl)
	ld	(#8002),a	;Pone seg. de NMAN en posicion 2
	call	_FUN3
	ld	a,c
	ld	(#8001),a	;Pone seg. fisico en posicion 1
	pop	hl,bc
	inc	hl
	djnz	FUN30_BUC2
	call	LOADP2

	ld	a,(IN_SEGS)	;Establece la variable INETSEG
	call	_FUN3	;se la pagina 3
	ld	a,c
	push	af
	call	_FUN32
	pop	af
	ld	(ix+1),a

	xor	a
	ld	(STRICT_SLOT),a
	ret

IN_SLOT:	db	0
IN_SEGS:	ds	4


	;--- Funcion 31: Libera los segmentos reservados para IN
	;    No hace nada ni devuelve error si no estan reservados
	;    Entrada: -
	;    Salida:  -

FUN31:	call	SET_EXECU
	call	_FUN31
	jp	RES_EXECU

_FUN31:	ld	a,(IN_SLOT)
	or	a
	ret	z

	call	_FUN32
	ld	(ix),0
	ld	(ix+1),a

	ld	hl,IN_SEGS
	ld	b,4
FUN31_BUC:	push	hl,bc
	ld	a,(hl)
	ld	(hl),0
	call	_FUN8
	pop	bc,hl
	inc	hl
	djnz	FUN31_BUC

	xor	a
	ld	(IN_SLOT),a
	ret


	;--- Funcion 32: Devuelve informacion sobre los segmentos
	;    reservados para InterNestor
	;    Entrada: -
	;    Salida:  A = Slot de InterNestor (0 si no hay reserva)
	;             C = Segmento del protocolo de nivel 1
	;             B = Segmento del protocolo de nivel 2
	;             E = Segmento del protocolo de nivel 3
	;             D = Segmento del protocolo de nivel 4
	;             HL=0 (reservado para futura expansion)
	;             IX= Direccion en pagina 3 del slot de IN
	;                 Si se pone a 0, no se llamara a la
	;                 rutina de interrupcion del reloj
	;                 de los segmentos

FUN32:	call	SET_EXECU
	call	_FUN32
	jp	RES_EXECU

_FUN32:	call	FUN1
	ld	bc,INETSLOT000F-INIRES000F
	add	hl,bc
	push	hl
	pop	ix
	ld	hl,0

	ld	a,(IN_SLOT)
	ld	bc,(IN_SEGS)
	ld	de,(IN_SEGS+2)
	ret


;------------------------
;---  RUTINAS VARIAS  ---
;------------------------

	;Guarda y recupera el estado de la pagina 2

SAVEP2:	push	af,bc,de,hl,ix,iy
	ld	ix,(CNT)
	ld	a,2
	call	GETSLOT
	ld	(ix),b
	ld	(ix+1),c
	inc	ix
	inc	ix
	ld	(CNT),ix
	pop	iy,ix,hl,de,bc,af
	ret

LOADP2:	push	af,bc,de,hl,ix,iy
	ld	ix,(CNT)
	dec	ix
	dec	ix
	ld	(CNT),ix
	ld	a,(ix)
	ld	h,#80
	push	ix
	call	ENASLT
	ei
	pop	ix
	ld	a,(ix+1)
	call	PUT_P2
	pop	iy,ix,hl,de,bc,af
	ret

;SEGSLOTS:     ds      32               ;Pila de slot+seg a guardar/cargar
CNT:	dw	SEGSLOTS


;--- GETSLOT:   Obtiene slot y segmento conectado a una pagina
;    Entrada:   A = Pagina
;    Salida:    B = Slot
;               C = Segmento
;    Registros: BC, DE, HL

GETSLOT:	push	af,ix,iy
	and	3
	ld	(GETIPAG),a

	;--- Obtiene slot

	in	a,(#A8)
	ld	e,a
	call	GETIAJ1
	ld	c,a	;C = Slot
	ld	b,0
	ld	hl,EXPTBL
	add	hl,bc
	bit	7,(hl)
	jr	z,NOEXP
EXP:	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	call	GETIAJ2
	or	c
	or	#80
	ld	c,a
NOEXP:	ld	a,c
	push	af

	;--- Obtiene segmento

	ld	a,(GETIPAG)
	rrca
	rrca
	ld	h,a
	call	GET_PH
	ld	c,a
	pop	af
	ld	b,a

	pop	iy,ix,af
	ret

	;--- Ajuste de bits segun la pagina

GETIAJ1:	ld	b,a
	ld	a,(GETIPAG)
	or	a
	jr	z,GETIAJ10
	dec	a
	jr	z,GETIAJ11
	dec	a
	jr	z,GETIAJ12
GETIAJ13:	sra	b
	sra	b
GETIAJ12:	sra	b
	sra	b
GETIAJ11:	sra	b
	sra	b
GETIAJ10:	ld	a,b
	and	%00000011
	ret

	;--- Ajuste de bits 2

GETIAJ2:	ld	b,a
	ld	a,(GETIPAG)
	or	a
	jr	z,GETIAJ20
	dec	a
	jr	z,GETIAJ21
	dec	a
	jr	z,GETIAJ22
GETIAJ20	sra	b
	sra	b
GETIAJ23:	sra	b
	sra	b
GETIAJ22:	sra	b
	sra	b
GETIAJ21:	ld	a,b
	and	%00001100
	ret

GETIPAG:	db	0


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


;--- Tabla de segmentos

NUMSEGS:	db	0	;Num. de segmentos reservados
TABSEGS:	ds	512	;Tabla de segmentos reservados


;--- Rutinas de soporte del mapeador

ALL_SEG:	jp	#F200	;Valores predefinidos para pruebas.
FRE_SEG:	jp	#F203	;Al instalar NESMAN, se rellenan con
RD_SEG:	jp	#F206	;la tabla real.
WR_SEG:	jp	#F209
CAL_SEG:	jp	#F20C
CALLS:	jp	#F20F
PUT_PH:	jp	#F212
GET_PH:	jp	#F215
PUT_P0:	jp	#F218
GET_P0:	jp	#F21B
PUT_P1:	jp	#F21E
GET_P1:	jp	#F221
PUT_P2:	jp	#F224
GET_P2:	jp	#F227
PUT_P3:	jp	#F22A
GET_P3:	jp	#F22D


;Esta subrutina inicializa un segmento:
;Pone los cuatro primeros bytes de MAT a #FF,
;y el resto a 0 (solo MAT)

CLEAN:	ld	hl,#8000
	ld	de,#8001
	ld	bc,4
	ld	(hl),255
	ldir
	ld	bc,256-4-1
	ld	(hl),0
	ldir
	ret

CLEAN4:	ld	hl,#4000	;Idem del segmento de NESMAN en pag. 1
	ld	de,#4001	;(solo MAT)
	ld	bc,SYSMAT
	ld	(hl),255
	ldir
	ld	bc,256-SYSMAT-1
	ld	(hl),0
	ldir
	ret


;--- MAXMIN:  Encuentra el bloque libre mas pequenyo
;             de tamanyo igual o superior a uno requerido
;             en un determinado segmento
;    Entrada: HL = Tamanyo requerido
;             Segmento a examinar conectado en pagina 2
;    Salida:  HL = Tamanyo del bloque encontrado
;             DE = Direccion del bloque encontrado,
;                  en pagina 2 (con desplazamiento #8000)
;             Cy = 1 si no hay bloques libres de al menos
;                  el tamanyo requerido en el segmento
;    Regist:  AF, BC, DE, HL


MAXMIN:	ld	a,#30	;#30 = Codigo de "jr nc"
	ld	(JRNC),a
	xor	a	;#00 = Codigo de "nop"
	ld	(RETNC),a
	ld	de,#7FFF
	jr	MAXMID


;--- MIDLIB:  Mide la memoria total libre de un segmento,
;             y el tamanyo del mayor bloque libre
;    Entrada: Segmento a examinar conectado en pagina 2
;    Salida:  DE = Tamanyo del mayor bloque libre encontrado
;             HL = Total de memoria libre en el segmento
;             Cy = 1 si no hay ningun bloque libre
;    Registros: AF, BC, DE, HL

MIDLIB:	ld	a,#18	;#30 = Codigo de "jr"
	ld	(JRNC),a
	ld	a,#C9
	ld	(RETNC),a	;#C9 = Codigo de "ret"
	ld	hl,0
	ld	(LIBTOTAL),hl
	ld	hl,1
	ld	de,1

	;--- Codigo comun a MAXMIN y MIDLIB

MAXMID:	ld	(BUSCAR),hl
	ld	a,4	;Empieza por el cuarto byte MAT,
	ld	(BYTE),a	;que apunta a #100
	xor	a
	ld	(BIT),a
	ld	hl,#7FFF
	ex	de,hl
	ld	(MIN_FND),hl

	;Busca un bloque libre

BUSLIB:	ld	a,(BIT)	;C=Contador de bits de un byte
	ld	c,a
	ld	a,(BYTE)	;L=Contador de bytes
	or	a
	jp	z,BL_FIN
	ld	l,a
	ld	h,#80	;HL=Direccion de ese byte MAT

	ld	b,(hl)
	xor	a
BUC_BL0:	cp	c	;Rota B para leer el primer bit
	jr	z,BUC_BL10	;(hace que el primer bit este en la
	srl	b		;posicion 0)
	inc	a
	jr	BUC_BL0

BUC_BL1:	srl	b	;Este bucle va pasando bits
	jr	nc,FREE_FND	;mientras sean 1
	inc	c
BUC_BL10:	bit	3,c
	jr	z,BUC_BL1	;Siguiente bit

	inc	hl
	bit	0,h
	jr	nz,BL_FIN	;Fin si se llega a #8100 (fin de MAT)
	ld	c,0
	ld	b,(hl)
	jr	BUC_BL1	;Siguiente byte si se ha llegado al bit 8

	;Bloque libre encontrado: comprueba tamanyoo

FREE_FND:	ld	a,c
	ld	(BIT2),a
	ld	a,l
	ld	(BYTE2),a
	ld	de,1	;DE=Longitud del bloque en sectores
	jr	BUC_BL20

BUC_BL2:	srl	b	;Va pasando bits mientras sean 0,
	jr	c,OK_FREE	;y mientras incrementa DE
	inc	de
BUC_BL20:	inc	c
	bit	3,c
	jr	z,BUC_BL2	;Siguiente bit

	inc	hl
	bit	0,h
	jr	nz,OK_FREE
	ld	c,0
	ld	b,(hl)
	jr	BUC_BL2	;Siguiente byte si se llega al bit 8

OK_FREE:	ld	a,c
	ld	(BIT),a
	ld	a,l
	ld	(BYTE),a

	call	DEPOR8	;Multiplica DE por 8

	ld	hl,(BUSCAR)	;Si el bloque encontrado es de
	call	COMP	;tamanyo menor al requerido, lo descartamos
	jr	z,OKF2	;y pasamos a buscar el siguiente bloque libre
	jr	c,BUSLIB	;(requerido=1 en MIDLIB)
OKF2:	;

	;Si el bloque encontrado es de tamanyo >= al requerido,
	;comprueba si es menor que el ultimo bloque encontrado,
	;si es asi sustituye el anterior por el nuevo (MAXMIN)

	;Si el bloque encontrado es mayor que el mayor encontrado antes,
	;el bloque nuevo pasa a ser el mayor encontrado.
	;Ademas suma el tamanyo del bloque encontrado al total (MIDLIB)

	scf
JRNC:	jr	nc,ESMIDLIB	;"jr nc" par MAXMIN, "jr" para MIDLIB

	ld	hl,(MIN_FND)	;Para MAXMIN
	call	COMP
	jr	z,BUSLIB
	jr	nc,BUSLIB	;Busca siguiente bloque libre
	ld	(MIN_FND),de
	jr	MAXMID0

ESMIDLIB:	ld	hl,(LIBTOTAL)	;Para MIDLIB
	add	hl,de
	ld	(LIBTOTAL),hl
	ld	hl,(MIN_FND)
	call	COMP
	jp	c,MAXMID0
	ld	(MIN_FND),de

MAXMID0:	ld	a,(BIT2)
	ld	(BITFND),a
	ld	a,(BYTE2)
	ld	(BYTEFND),a
	jp	BUSLIB	;Busca siguiente bloque libre

	;Fin de MAT encontrado: devuelve HL, DE y Cy adecuados

BL_FIN:	ld	hl,(MIN_FND)
	ld	de,#7FFF	;Si DE sigue teniendo el valor inicial
	call	COMP	;#7FFF, es que no se ha encontrado
	scf		;ningun bloque libre >= al requerido (MAXMIN)
	ret	z
	ld	de,1
	call	COMP	;Idem con DE=1 (MIDLIB)
	scf
	dec	de
	dec	hl
	ret	z
	inc	de
	inc	hl

	ex	de,hl
	ld	hl,(LIBTOTAL)
	or	a
RETNC:	ret		;                ;"ret" para MIDLIB, "nop" para MAXMIN
	ex	de,hl

	ld	a,(BYTEFND)	;Dir = (BYTE * 64) + BIT * 8=
	ld	e,a	;    = ((BYTE * 8) + BIT) * 8
	ld	d,0

	call	DEPOR8	;Multiplica BYTE por 8

	ld	a,(BITFND)	;Suma BIT
	ld	c,a
	ld	b,0
	ex	de,hl
	add	hl,bc
	ex	de,hl

	call	DEPOR8	;Vuelve a multiplicar por 8
	set	7,d

	or	a
	ret

	;Esta subrutina multiplica DE por 8

DEPOR8:	sla	e
	rl	d
	sla	e
	rl	d
	sla	e
	rl	d
	ret

BUSCAR:	dw	0	;Tamanyo requerido
MIN_FND:	dw	0	;Tamanyo del mejor bloque encontrado
BYTE:	db	0	;Byte MAT que esta siendo examinado
BIT:	db	0	;Bit que esta siendo examinado
BYTE2:	db	0	;Byte MAT del ultimo bloque libre encontrado
BIT2:	db	0	;Bit de inicio del ultimo b. libre encontrado
BYTEFND:	db	0	;Byte MAT del mejor bloque encontrado   
BITFND:	db	0	;Bit de inicio del mejor bloque encontrado
LIBTOTAL:	dw	0	;Total de memoria libre encontrada


;--- MALLOC:  Reserva un bloque de memoria
;    Entrada: HL = Tamanyo requerido
;    Salida:  HL = Direccion, empezando en #8000
;             B  = Segmento
;             Cy = 1 si hay error (no queda memoria libre)
;    Regist:  AF, BC, DE, HL

MALLOC:	ld	a,h
	or	l
	scf
	ret	z
	inc	hl
	ld	a,h
	or	l
	scf
	ret	z
	inc	h	;Error si el tamanyor requerido
	ld	a,h	;es >16384-256 (#3F00)
	and	%11000000
	scf
	ret	nz
	dec	h
	dec	hl
	call	REQ2REAL

	;Inicializa algunas variables

	xor	a
	ld	(SEGFND),a
	call	SAVEP2

	ld	hl,#7FFF
	ld	(TAMFND),hl

	;Recorre todos los segmentos reservados, buscando
	;el que tiene el menor tamanyo de bloque posible
	;que sea >= que el tamanyo requerido

	call	FIRSTSEG

BUC_MALL:	call	NEXTSEG
	jr	c,FND_MALL
	ld	c,a
	push	bc
	call	PUT_S2

	ld	hl,(TAMREQ)
	call	MAXMIN
	pop	bc
	jr	c,BUC_MALL

	push	de	;Si el mejor bloque de este segmento
	ld	de,(TAMFND)	;es mas pequenyo que el ultimo mejor
	call	COMP	;bloque encontrado, cambiamos el viejo
	pop	de	;por el nuevo
	jr	c,BUC_MALL
	ld	(TAMFND),hl
	ld	(DIRFND),de
	ld	a,c
	ld	(SEGFND),a

	;Una vez examinados todos los slots, comprobamos si
	;hemos encontrado un bloque libre en alguno de ellos

FND_MALL:	ld	a,(SEGFND)
	or	a
	jr	z,_NEW_SEG

	;Actualizamos MAT, ponemos el tamanyo del bloque
	;al principio del mismo y terminamos

	call	PUT_S2	;Conecta segmento encontrado a pag. 2

	ld	de,(TAMREAL)
	ld	hl,(DIRFND)

	ld	a,#C0
	call	ADJMAT	;Pone los bits adecuados de MAT a 1

	ld	a,(SEGFND)	;Pone el tamanyo del bloque
	ld	b,a	;al principio del mismo
	ld	de,(TAMREQ)
	dec	de
	dec	de
	ld	hl,(DIRFND)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	;pop     af
	;call    PUT_S2           ;Restaura segmento original y termina

	or	a
	jp	LOADP2	;jr      MALL_REFIN       ;ret

	;Si no hay ningun bloque libre, reservamos un segmento nuevo.
	;Si no es posible, devolvemos un error.

_NEW_SEG:	ld	a,(NUMSEGS)
	cp	255	;Error si ya habia 255 seg. reservados
	jr	z,MALL_ERR

	ld	a,(#F344)	;Reserva segmento y lo inicializa
	or	%0 010 0000
	ld	b,a
	ld	a,1	;Lo reserva de sistema
	call	SAVE_DOS_VARS
	call	ALL_SEG
	call	LOAD_DOS_VARS
	jr	c,MALL_ERR
	ld	c,a	;B=Slot, C=Segmento

	call	BUSFREE	;Registra nuevo segmento
	ld	(hl),b
	inc	hl
	ld	(hl),c
	ld	hl,NUMSEGS
	inc	(hl)

	ld	(SEGFND),a
	call	PUT_S2
	call	CLEAN

	;                        ;Ahora actua como si hubiera encontrado
	;ld      (SEGFND),a       ;un bloque libre en el segmento
	ld	hl,#8100	;que acabamos de reservar
	ld	(DIRFND),hl
	ld	hl,#3F00
	ld	(TAMFND),hl
	jp	FND_MALL

MALL_ERR:	scf		;Terminacion con error

MALL_REFIN:	jp	LOADP2	;call    LOADP2
	;ret


	;Esta subrutina comprueba si DE es 0

DE_ES_0:	ld	(SAVEA),a
	ld	a,d
	or	e
	ld	a,(SAVEA)
	ret

TAMREQ:	dw	0	;Tamanyo requerido
SEGFND:	db	0	;Segmento del mejor bloque encontrado
TAMFND:	dw	0	;Tamanyo del mejor bloque encontrado
CURSLOT:	db	0	;Segmento que esta siendo examinado
DIRFND:	dw	0	;Direccion del mejor bloque encontrado
TAMREAL:	dw	0	;Tamanyo declarado convertido a real
SAVEA:	db	0


	;NEXTSEG devuelve en A el siguiente segmento que no es exclusivo.
	;Devuelve Cy=1 cuando no quedan mas segmentos.
	;FIRSTSEG inicializa.
	;Modifican AF, B, DE, HL

FIRSTSEG:	ld	hl,TABSEGS
	ld	(PNTSEG),hl
	ld	a,(NUMSEGS)
	inc	a
	ld	(CNTSEG),a
	ld	a,-1
	ld	(CURSEG),a
	ret

NEXTSEG:	ld	a,(CNTSEG)
	or	a
	scf
	ret	z
	ld	a,(CURSEG)
	ld	b,a
	ld	de,(PNTSEG)
	ld	hl,CNTSEG

BUCNXSEG:	ld	a,(de)
	inc	de
	inc	de
	inc	b
	or	a
	jr	z,BUCNXSEG
	dec	(hl)
	scf
	ret	z
	bit	4,a
	jr	nz,BUCNXSEG

	ld	(PNTSEG),de
	ld	a,b
	ld	(CURSEG),a
	;ld      hl,CNTSEG
	;dec     (hl)
	or	a
	ret

PNTSEG:	dw	0	;Puntero a la sig. entrada en tabla seg.
CURSEG:	db	0	;Ultimo segmento devuelto
CNTSEG:	db	0	;Segmentos que quedan por devolver


	;BUSFREE busca una entrada vacia en la tabla de segmentos.
	;Devuelve en A el numero de la entrada y en HL la dir. en la tabla.

BUSFREE:	push	de
	ld	hl,TABSEGS	;Registra nuevo segmento
	ld	e,-1
BUSENTAB:	ld	a,(hl)	;Busca entrada vacia en la tabla
	inc	hl
	inc	hl
	inc	e
	or	a
	jr	nz,BUSENTAB
	ld	a,e
	dec	hl
	dec	hl
	pop	de
	ret


	;REQ2REAL transforma un tamanyo requerido HL en uno real.
	;Establece TAMREQ y TAMREAL.

REQ2REAL:	inc	hl
	inc	hl
	ld	(TAMREQ),hl
	ld	a,l
	and	%111
	jr	z,OKTREAL
	ld	a,l
	and	%11111000
	add	8
	ld	l,a
	jr	nc,OKTREAL	;*** ANYADIDO EN 1.22
	inc	h	;***
OKTREAL:	ld	(TAMREAL),hl
	ret


;--- MFREE: Libera un bloque de memoria
;    Entrada: A  = Segmento del bloque
;             HL = Direccion del bloque
;    Salida:  Cy = 1 si el segmento no existe, o es el 0 o el 3
;    Regist:  AF, BC, DE, HL

MFREE:	;ld      e,b
	;call    GET_S2
	;push    af
	;ld      a,e
	;call    PUT_S2
	or	a
	scf
	ret	z
	cp	3
	scf
	ret	z
	call	SAVEP2
	call	PUT_S2
	ret	c
	set	7,h
	res	6,h

	res	1,l
	ld	e,(hl)
	inc	hl
	ld	d,(hl)	;DE = Tamanyo declarado
	inc	de	;!!!!!!!
	inc	de	;!!!!!!!
	ld	a,e
	and	%111	;Convierte a tamanyo real
	jr	z,OKTRE2
	ld	a,e
	and	%11111000
	add	8
	ld	e,a	;Ahora DE = Tamanyo real
	jr	nc,OKTRE2	;*** ANYADIDO EN 1.22
	inc	d	;***
OKTRE2:	res	0,l	;HL = Direccion real (multiplo de 8)

	ld	a,#80	;Pone bits de MAT a 0
	call	ADJMAT

	call	LOADP2
	or	a
	ret


;--- ADJMAT:  Pone a 1 o a 0 los bits MAT correspondientes
;             a un bloque de memoria
;    Entrada: HL = Direccion (ha de ser multiplo de 8)
;             DE = Tamanyo real del bloque
;             A  = #80 para poner a 0 (entonces SETMAT_2 sera RES 0,B)
;                  #C0 para poner a 1 (entonces SETMAT_2 sera SET 0,B)
;    Salida:  -
;    Regist:  AF, BC, DE, HL

ADJMAT:	ld	(SETMAT_2+1),a

	xor	a
	div_hl		;HL = HL / 8
	div_hl
	div_hl

	div_hl		;HL = HL / 8 y resto a A
	rr	a
	div_hl
	rr	a
	div_hl
	rr	a	;Ahora HL = Byte MAT y A = Bit
	ld	h,#80
	rlca
	rlca
	rlca

	div_de		;DE = DE / 8 = Num. de bits a poner a 1
	div_de
	div_de

	push	af
	ld	b,(hl)
SETMAT_1:	or	a	;Rota B hasta que el primer bit a modificar
	jr	z,OKMAT_1	;esta en la posicion 0
	rrc	b
	dec	a
	jr	SETMAT_1
OKMAT_1:	pop	af

SETMAT_2:	db	#CB,0	;Va poniendo a 1/0
	rrc	b	;todos los bits necesarios
	dec	de
	call	DE_ES_0
	jr	z,SETMAT_F
	inc	a
	cp	8
	jr	nz,SETMAT_2

	ld	(hl),b	;Siguiente byte
	inc	hl
	ld	b,(hl)
	xor	a
	jr	SETMAT_2

SETMAT_F:	inc	a	;Ajusta el ultimo byte
	cp	8
	jr	z,SETMAT_F2
	rrc	b
	jr	SETMAT_F
SETMAT_F2:	ld	(hl),b

	ret


;--- NOMBRE: COMP
;      Comparacion de HL con DE (sin signo)
;    ENTRADA:   HL, DE = numeros a comparar
;    SALIDA:     C, NZ si HL > DE
;                C,  Z si HL = DE
;               NC, NZ si HL < DE
;    Modifica: A

COMP:	call	_COMP
	ccf
	ret

_COMP:	ld	a,h
	sub	d
	ret	nz
	ld	a,l
	sub	e
	ret


;--- GET_S2:  Devuelve el segmento logico conectado en la pagina 2
;    Entrada: -
;    Salida:  A = Segmento en pagina 2
;    Regist:  -

GET_S2:	ld	a,(CUR_S2)
	ret

CUR_S2:	db	0


;--- PUT_S2:  Conecta un segmento logico a la pagina 2
;    Entrada: A = Numero de segmento
;    Salida:  Cy= 1 si el segmento no existe
;    Regist:  -

PUT_S2:	push	hl,bc,de
	ld	(CUR_S2),a
	ld	l,a
	ld	h,0
	add	hl,hl
	ld	bc,TABSEGS
	add	hl,bc

	ld	a,(hl)
	or	a
	scf
	jr	z,PUTS2F	;Error si el segmento no existe
	push	hl	;Conecta el slot
	ld	h,#80
	call	ENASLT
	pop	hl

PUTS22:	inc	hl	;Conecta segmento fisico
	ld	a,(hl)
	call	PUT_P2
	or	a
PUTS2F:	pop	de,bc,hl
	ld	a,(CUR_S2)
	ret

CURSLOT2:	db	0


;--------------------------------------------------
;---  RUTINAS DE GESTION DE LISTAS ENCADENADAS  ---
;--------------------------------------------------

;* Un elemento de lista consta de:
;- Segmento + direccion del elemento anterior
;- Segmento + direccion del elemento siguiente
;- Datos que forman el elemento

;* El descriptor de una lista es una tabla de 12 bytes con:
;- Segmento + direccion del primer elemento
;- Segmento + direccion del elemento en curso
;- Segmento + direccion del ultimo elemento
;- Numero de elementos (3 bytes)


;--- L_INIT:  Inicializa un descriptor de lista (punteros y num. elems. a 0)
;    Entrada: IX   = Direccion del descriptor de la lista
;    Salida:  -
;    Regist:  F, BC, DE, HL

L_INIT:	push	ix
	pop	hl
	push	hl
	pop	de
	inc	de
	ld	bc,11
	ld	(hl),0
	ldir
	ret


;--- L_PNTS:  Obtiene las direcciones de elemento anterior
;             y posterior de un elemento de lista
;    Entrada: IX   = Direccion del descriptor de la lista
;    Salida:  A-HL = Puntero al elemento anterior
;             B-DE = Puntero al elemento siguiente
;    Regist:  F

L_PNTS:	call	SAVEP2	;call    GET_S2
	;ld      (LPNTS_A),a
	ld	a,(ix+3)
	call	PUT_S2

	ld	l,(ix+4)
	ld	h,(ix+5)
	push	ix,hl
	pop	ix
	ld	a,(ix)
	ld	l,(ix+1)
	ld	h,(ix+2)
	ld	b,(ix+3)
	ld	e,(ix+4)
	ld	d,(ix+5)

	push	af
	;ld      a,(LPNTS_A)
	call	LOADP2	;call    PUT_S2
	pop	af,ix
	ret

LPNTS_A:	db	0


;--- L_FWD:   Avanza el puntero de una lista
;    Entrada: IX = Direccion del descriptor de la tabla
;    Salida:  Cy = 1 si el elemento apuntado previamente era el ultimo
;             A-HL = Nuevo puntero
;    Regist:  AF, HL

L_FWD:	call	L_PNTS
	ld	a,d
	or	e
	scf
	ret	z

	ld	(ix+3),b
	ld	(ix+4),e
	ld	(ix+5),d
	push	bc,de
	pop	hl,af
	or	a
	ret


;--- L_REW:   Retrocede el puntero de una lista
;    Entrada: IX = Direccion del descriptor de la tabla
;    Salida:  Cy = 1 si el elemento apuntado previamente era el primero
;             A-HL = Nuevo puntero
;    Regist:  B, DE

L_REW:	call	L_PNTS
	ld	b,a
	ld	a,h
	or	l
	scf
	ret	z

	ld	(ix+3),b
	ld	(ix+4),l
	ld	(ix+5),h
	ld	a,b
	or	a
	ret


;--- L_SETP:  Establece el puntero de una lista
;    Entrada: IX = Direccion del descriptor de la tabla
;             A-HL = Nuevo puntero
;    Salida:  -
;    Regist:  -

L_SETP:	ld	(ix+3),a
	ld	(ix+4),l
	ld	(ix+5),h
	ret


;--- L_SETPF: Establece el puntero de una lista al primer elemento
;    Entrada: IX = Direccion del descriptor de la tabla
;    Salida:  A-HL = Puntero al primer elemento
;    Regist:  F

L_SETPF:	ld	a,(ix)
	ld	(ix+3),a
	ld	l,(ix+1)
	ld	(ix+4),l
	ld	h,(ix+2)
	ld	(ix+5),h
	ret


;--- L_SETPL: Establece el puntero de una lista al ultimo elemento
;    Entrada: IX = Direccion del descriptor de la tabla
;    Salida:  A-HL = Puntero al primer elemento
;    Regist:  F

L_SETPL:	ld	a,(ix+6)
	ld	(ix+3),a
	ld	l,(ix+7)
	ld	(ix+4),l
	ld	h,(ix+8)
	ld	(ix+5),h
	ret


;--- L_EMPTY: Comprueba si una lista esta vacia
;    Entrada: IX = Direccion del descriptor de la tabla
;    Salida:  Cy = 1 si la lista esta vacia
;    Regist:  -

L_EMPTY:	ld	(LEMPT_A),a
	ld	a,(ix+9)
	or	(ix+10)
	or	(ix+11)
	ld	a,(LEMPT_A)
	scf
	ret	z
	ccf
	ret

LEMPT_A:	db	0


;--- L_SEEK:  Establece el puntero de una lista en un elemento determinado
;    Entrada: IX = Direccion del descriptor de la tabla
;             B-DE = Numero de elemento (el primero es 1)
;    Salida:  Cy = 1 si ese elemento no existe
;    Regist:  A

L_SEEK:	call	L_EMPTY
	ret	c
	ld	c,b
	call	L_SETPF
	ld	b,0	;B-HL = Numero del elemento actual
	ld	hl,1

LSEEK_B:	ld	a,b
	cp	c
	jr	nz,LSK_NEXT
	call	COMP
	ccf
	ret	z

LSK_NEXT:	push	bc,de,hl
	call	L_FWD
	pop	hl,de,bc
	ret	c
	inc	hl
	ld	a,h
	or	l
	jr	nz,LSEEK_B
	inc	b
	jr	LSEEK_B


;--- L_GETF: Obtiene el puntero del primer elmento de una lista
;    Entrada: IX = Direccion del descriptor de la tabla
;    Salida:  A-HL = Puntero del primer elemento
;    Regist:  -

L_GETF:	ld	a,(ix)
	ld	l,(ix+1)
	ld	h,(ix+2)
	ret


;--- L_GETL: Obtiene el puntero del ultimo elemento de una lista
;    Entrada: IX = Direccion del descriptor de la tabla
;    Salida:  A-HL = Puntero del ultimo elemento
;    Regist:  -

L_GETL:	ld	a,(ix+6)
	ld	l,(ix+7)
	ld	h,(ix+8)
	ret


;--- L_GETP: Obtiene el puntero del elemento actual una lista
;    Entrada: IX = Direccion del descriptor de la tabla
;    Salida:  A-HL = Puntero actual
;    Regist:  -

L_GETP:	ld	a,(ix+3)
	ld	l,(ix+4)
	ld	h,(ix+5)
	ret


;--- L_GETN: Obtiene el numero de elementos de una lista
;    Entrada: IX = Direccion del descriptor de la tabla
;    Salida:  A-HL = Numero de elementos de la lista
;             Cy = 1 si la lista esta vacia
;    Regist:  -

L_GETN:	call	L_EMPTY
	ld	l,(ix+9)
	ld	h,(ix+10)
	ld	a,(ix+11)
	ret


;--- L_GETCE: Obtiene el elemento actualmente apuntado de la lista
;    Entrada: IX = Puntero al descriptor de la tabla
;             DE = Direccion en la que dejar el elemento
;    Salida:  BC = Longitud del elemento
;             Cy = 1 si la lista esta vacia
;    Regist:  AF, HL

L_GETCE:	call	L_GETP
	jp	L_GETE


;--- L_GETE:  Obtiene un elemento de la lista
;    Entrada: A-HL = Puntero al elemento
;             DE = Direccion en la que dejar el elemento
;             IX = Puntero al descriptor de la tabla
;    Salida:  BC = Longitud del elemento
;             Cy = 1 si la lista esta vacia
;    Regist:  AF, HL

L_GETE:	call	L_EMPTY
	ret	c
	;push    de,af
	call	SAVEP2	;call    GET_S2
	;ld      (LGET_A),a
	;pop     af
	call	PUT_S2

	push	de,de
	dec	hl
	ld	d,(hl)
	dec	hl
	ld	e,(hl)	;DE = Longitud incluyendo punteros
	call	LOADP2	;Ya tenemos la longitud -> rest. pagina
	ld	bc,8
	add	hl,bc	;HL = Direccion tras los punteros
	ex	de,hl
	ld	bc,6
	or	a
	sbc	hl,bc
	ex	de,hl
	push	de
	pop	bc	;BC = Longitud sin incluir punteros
	pop	de
	push	bc
	call	L_LDIR1	;ldir
	pop	bc

	pop	de
	;ld      a,(LGET_A)
	;call    PUT_S2
	or	a
	ret

LGET_A:	db	0


;--- L_ISF:   Comprueba si el elemento apuntado es el primero de la tabla
;    Entrada: IX = Puntero al descriptor de la tabla
;    Salida:  Cy = 1 si es el primer elemento
;    Regist:  AF

L_ISF:	call	L_EMPTY
	ccf
	ret	nc

	ld	a,(ix)
	cp	(ix+3)
	jr	nz,LISF2
	ld	a,(ix+1)
	cp	(ix+4)
	jr	nz,LISF2
	ld	a,(ix+2)
	cp	(ix+5)
	jr	nz,LISF2
	scf
	ret
LISF2:	or	a
	ret


;--- L_ISL:   Comprueba si el elemento apuntado es el ultimo de la tabla
;    Entrada: IX = Puntero al descriptor de la tabla
;    Salida:  Cy = 1 si es el primer elemento
;    Regist:  AF

L_ISL:	call	L_EMPTY
	ccf
	ret	nc

	ld	a,(ix+6)
	cp	(ix+3)
	jr	nz,LISL2
	ld	a,(ix+7)
	cp	(ix+4)
	jr	nz,LISL2
	ld	a,(ix+8)
	cp	(ix+5)
	jr	nz,LISL2
	scf
	ret
LISL2:	or	a
	ret


;--- L_PUTE:  Introduce un elemento en la lista
;    Entrada: IX = Puntero al descriptor de la tabla
;             A  = Donde insertar el elemento:
;                  0: Despues del elemento actualmente apuntado
;                  1: Antes del elemento actualmente apuntado
;                  2: Antes del primer elemento (al principio de la lista)
;                  3: Despues del ultimo elemento (al final de la lista)
;             BC = Longitud del elemento
;             HL = Direccion del elemento
;    Salida:  Cy = 1 si no hay memoria libre
;    Regist:  AF, BC, DE, HL

L_PUTE:	ld	(LPUT_M),a	;Guarda metodo
	ld	(LPUT_E),hl	;Guarda dir. origen del nuevo elemento
	ld	(LPUT_T),bc	;Guarda tamanyo del bloque sin punt.
	call	SAVEP2	;call    GET_S2
	;ld      (LPUT_PS),a      ;Guarda seg. original en pag. 2

	push	bc	;Suma 6 al tamanyo para los punteros
	pop	hl
	ld	bc,6
	add	hl,bc

	push	ix
	call	MALLOC
	pop	ix
	ret	c
	ld	(LPUT_D),hl	;Guarda direccion
	ld	(LPUT_S),a	;Guarda segmento

	call	L_EMPTY
	jr	nc,LPUT2

	;--- Actualizacion de punteros si la lista esta vacia
	;    (en este caso, el metodo es irrelevante)

	ld	a,(LPUT_S)
	ld	hl,(LPUT_D)
	ld	(ix),a	;Coloca la dir. del elemento recien
	ld	(ix+1),l	;creado como el primero, actual y ultimo
	ld	(ix+2),h
	ld	(ix+3),a
	ld	(ix+4),l
	ld	(ix+5),h
	ld	(ix+6),a
	ld	(ix+7),l
	ld	(ix+8),h

	xor	a	;Punteros anterior y siguiente a 0
	ld	hl,0
	ld	b,0
	ld	de,0

	jp	LPUT_F

	;--- Si la lista no estaba vacia, comprobamos el metodo

LPUT2:	ld	a,(LPUT_M)
	and	3
	jp	z,LPUT_M0
	dec	a
	jr	z,LPUT_M1
	dec	a
	jp	z,LPUT_M2
	jp	LPUT_M3

	;--- Metodo 0: a continuacion del elemento actual
	;    Pasos a seguir:
	;    - P. anterior (e. nuevo) = d. elem. actual
	;    - P. siguiente (e. nuevo) = d. elem. siguiente al actual
	;    - P. anterior (e. siguiente al actual) = d. elem. nuevo
	;    - P. siguiente (e. actual) = d. elemento nuevo

LPUT_M0:	call	L_ISL	;Si elem. actual = ultimo,
	jp	c,LPUT_M3	;saltamos directamente al metodo 3

	call	L_FWD	;Dir. elem. siguiente a la pila
	call	L_GETP
	push	af,hl
	call	L_REW

	call	L_GETP	;Dir. elem. actual a la pila
	push	af,hl

	call	PUT_S2	;P. siguiente (e. actual) = d. el. nuevo
	inc	hl
	inc	hl
	inc	hl
	ld	a,(LPUT_S)
	ld	de,(LPUT_D)
	ld	(hl),a
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d

	pop	de,bc,hl,af
	push	af,hl,bc,de

	call	PUT_S2	;P. anterior (el. sig.) = d. el. nuevo
	ld	a,(LPUT_S)
	ld	de,(LPUT_D)
	ld	(hl),a
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d

	pop	hl,af	;Recupera dir. antiguo actual
	pop	de,bc	;Recupera dir. antiguo siguiente
	jp	LPUT_F

	;--- Metodo 1: antes del elemento actual
	;    Pasos a seguir:
	;    - P. siguiente (e. nuevo) = d. elem. actual
	;    - P. anterior (e. nuevo) = d. elem. anterior al actual
	;    - P. siguiente (e. anterior al actual) = d. elem. nuevo
	;    - P. anterior (e. actual) = d. elemento nuevo

LPUT_M1:	call	L_ISF	;Si elem. actual = primero,
	jr	c,LPUT_M2	;saltamos directamente al metodo 2

	call	L_REW
	call	L_GETP	;Dir. elem. anterior la pila
	push	af,hl
	call	L_FWD	;Dir. elem. actual a la pila
	call	L_GETP
	push	af,hl

	call	PUT_S2	;P. anterior (e. actual) = d. el. nuevo
	ld	a,(LPUT_S)
	ld	de,(LPUT_D)
	ld	(hl),a
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d

	pop	de,bc,hl,af
	push	af,hl,bc,de

	call	PUT_S2	;P. siguiente (el. ant.) = d. el. nuevo
	inc	hl
	inc	hl
	inc	hl
	ld	a,(LPUT_S)
	ld	de,(LPUT_D)
	ld	(hl),a
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d

	pop	de,bc	;Recupera dir. antiguo actual
	pop	hl,af	;Recupera dir. antiguo anterior
	jr	LPUT_F

	;--- Metodo 2: antes del primer elemento

LPUT_M2:	ld	a,(ix)
	call	PUT_S2
	ld	l,(ix+1)
	ld	h,(ix+2)	;HL = Dir. primer elemento

	push	af,hl
	ld	a,(LPUT_S)	;El puntero al anterior del que
	ld	(hl),a	;antes era el primer antes era 0,
	ld	de,(LPUT_D)	;ahora apunta al nuevo elemento
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d

	ld	a,(LPUT_S)	;El primer elemento es ahora el nuevo
	ld	(ix),a
	ld	hl,(LPUT_D)
	ld	(ix+1),l
	ld	(ix+2),h

	pop	de,bc	;El nuevo elemento tendra como punteros:
	ld	a,0	;Anterior: 0
	ld	hl,0	;Siguiente: el antiguo primer elemento
	jp	LPUT_F

	;--- Metodo 3: despues del ultimo elemento

LPUT_M3:	ld	a,(ix+6)
	call	PUT_S2
	ld	l,(ix+7)
	ld	h,(ix+8)	;HL = Dir. ultimo elemento

	push	af,hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(LPUT_S)	;El puntero al siguiente del que
	ld	(hl),a	;antes era el ultimo antes era 0,
	ld	de,(LPUT_D)	;ahora apunta al nuevo elemento
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d

	ld	a,(LPUT_S)	;El ultimo elemento es ahora el nuevo
	ld	(ix+6),a
	ld	hl,(LPUT_D)
	ld	(ix+7),l
	ld	(ix+8),h

	pop	hl,af	;El nuevo elemento tendra como punteros:
	ld	b,0	;Anterior: el antiguo ultimo elemento
	ld	de,0	;Siguiente: 0
	jp	LPUT_F

	;--- FIN:
	;    - Pone los punteros A-HL y B-DE como anterior y siguiente
	;      en el elemento recien creado
	;    - Copia el elemento recien creado a la memoria reservada
	;    - Incrementa el numero de elementos de la lista
	;    - Restaura el segmento original en pag. 2 y termina

LPUT_F:	push	af
	ld	a,(LPUT_S)
	call	PUT_S2

	pop	af
	push	ix
	ld	ix,(LPUT_D)
	ld	(ix),a
	ld	(ix+1),l
	ld	(ix+2),h
	ld	(ix+3),b
	ld	(ix+4),e
	ld	(ix+5),d
	pop	ix

	call	LOADP2
	ld	de,(LPUT_E)	;Copia el elemento a la memoria reserv.
	ld	hl,(LPUT_D)
	ld	bc,6
	add	hl,bc
	ex	de,hl
	ld	bc,(LPUT_T)
	ld	a,(LPUT_S)
	call	L_LDIR2	;ldir

	ld	l,(ix+9)	;Incrementa num de elementos
	ld	h,(ix+10)
	inc	hl
	ld	(ix+9),l
	ld	(ix+10),h
	ld	a,h
	or	l
	jr	nz,LPUT_F2
	ld	a,(ix+11)
	inc	a
	ld	(ix+11),a

LPUT_F2:	;ld      a,(LPUT_PS)
	;call    LOADP2           ;call    PUT_S2
	or	a
	ret

LPUT_PS:	db	0	;Segmento original en p. 2
LPUT_S:	db	0	;Seg. del nuevo elemento
LPUT_D:	dw	0	;Dir. del nuevo elemento
LPUT_T:	dw	0	;Tamanyo del nuevo elemento
LPUT_M:	db	0	;Metodo
LPUT_E:	dw	0	;Dir. original del nuevo elemento


;--- L_DELE:  Borra un elemento en la lista
;    Entrada: IX = Puntero al descriptor de la tabla
;             A  = Que elemento borrar:
;                  0: El actual
;                  1: El primero
;                  2: El ultimo
;    Salida:  Cy = 1 si la lista estaba vacia
;             El elemento actual pasa a ser el siguiente
;             (si era el ultimo, apunta al nuevo ultimo)
;    Regist:  AF, BC, DE, HL

L_DELE:	call	L_EMPTY
	ret	c

	ld	(LDEL_M),a	;Guarda metodo
	;call    GET_S2
	call	SAVEP2	;ld      (LDEL_PS),a
	call	L_PNTS
	ld	(LDEL_SA),a
	ld	(LDEL_DA),hl	;Guarda seg + dir del anterior
	ld	a,b
	ld	(LDEL_SS),a	;Guarda seg + dir del siguiente
	ld	(LDEL_DS),de

	call	L_GETN	;Termina directamente
	or	a	;si solo hay un elemento
	jr	nz,LDEL3
	dec	hl
	ld	a,h
	or	l
	jr	nz,LDEL3
	call	L_GETP
	jp	L_DELF

	;--- Decide que hacer segun el metodo

LDEL3:	ld	a,(LDEL_M)
	and	3
	jr	z,LDEL_M0
	dec	a
	jr	z,LDEL_M1
	jr	LDEL_M2

	;--- Metodo 1: borra el primero

LDEL_M1:	call	L_ISF	;Si el actual era el primero,
	call	c,L_FWD	;hay que avanzarlo

LDEL_M11:	call	L_GETP
	push	af,hl	;Puntero original a la pila
	call	L_SETPF
	push	af,hl	;Puntero a borrar (primero) a la pila
	call	L_FWD

	ld	(ix),a	;El que antes era el segundo es
	ld	(ix+1),l	;ahora el primero
	ld	(ix+2),h
	call	PUT_S2
	ld	(hl),0	;El punt. anterior del nuevo primero
	inc	hl	;es ahora 0
	ld	(hl),0
	inc	hl
	ld	(hl),0
	dec	hl
	dec	hl

LDEL_M12:	pop	de,bc	;Puntero a borrar
	pop	hl,af	;Puntero original
	push	bc,de
	call	L_SETP	;Restablece puntero original
	pop	hl,af
	jr	L_DELF

	;--- Metodo 2: borra el ultimo

LDEL_M2:	call	L_ISL	;Si el actual era el ultimo,
	call	c,L_REW	;hay que retrocederlo

LDEL_M22:	call	L_GETP
	push	af,hl	;Puntero original a la pila
	call	L_SETPL
	push	af,hl	;Puntero a borrar (ultimo) a la pila
	call	L_REW

	ld	(ix+6),a	;El que antes era el penultimo es
	ld	(ix+7),l	;ahora el pultimo
	ld	(ix+8),h
	call	PUT_S2
	push	hl
	inc	hl
	inc	hl
	inc	hl
	ld	(hl),0	;El punt. siguiente del nuevo ultimo
	inc	hl	;es ahora 0
	ld	(hl),0
	inc	hl
	ld	(hl),0
	pop	hl

	jr	LDEL_M12

	;--- Metodo 0: borra el actual

LDEL_M0:	call	L_GETP	;Si el elemento actual es el primero
	call	L_ISF	;o el ultimo, salta directamente al
	jr	c,LDEL_M1	;metodo 1 o el 2
LDELM01:	call	L_ISL
	jr	c,LDEL_M2

	ld	a,(LDEL_SA)	;Ahora el puntero al siguiente del
	call	PUT_S2	;anterior el la dir. del siguiente
	ld	hl,(LDEL_DA)
	inc	hl
	inc	hl
	inc	hl
	ld	a,(LDEL_SS)
	ld	(hl),a
	inc	hl
	ld	de,(LDEL_DS)
	ld	(hl),e
	inc	hl
	ld	(hl),d

	ld	a,(LDEL_SS)	;Ahora el puntero al anterior del
	call	PUT_S2	;siguiente es la dir. del anterior
	ld	hl,(LDEL_DS)
	ld	a,(LDEL_SA)
	ld	(hl),a
	inc	hl
	ld	de,(LDEL_DA)
	ld	(hl),e
	inc	hl
	ld	(hl),d

	call	L_GETP	;El puntero queda apuntando al siguiente
	push	af,hl
	call	L_FWD
	pop	hl,af
	;jr      L_DELF

	;FIN:
	;- Borra el elemento A-HL
	;- Decrementa el contador de elementos
	;- Restaura segmento original en pag. 2 y termina

L_DELF:	;ld      b,a
	call	MFREE

	call	L_GETN	;Decrementa contador de elementos
	ld	b,a
	ld	a,h
	or	l
	dec	hl
	ld	(ix+9),l
	ld	(ix+10),h
	jr	nz,L_DELF2
	dec	b
	ld	(ix+11),b

	;--- Si solo habia un elemento,
	;    ahora la lista esta vacia y borramos los punteros

L_DELF2:	call	L_EMPTY
	jr	nc,L_DELF3

	call	L_INIT
	jr	L_DELF4

	;--- Si ahora solo hay un elemento,
	;    ponemos puntero actual = primero

L_DELF3:	call	L_GETN
	or	a
	jr	nz,L_DELF4
	dec	hl
	ld	a,h
	or	l
	call	z,L_SETPF

	;--- Restauramos segmento y terminamos

L_DELF4:	;ld      a,(LDEL_PS)
	call	LOADP2	;call    PUT_S2
	or	a
	ret

LDEL_PS:	equ	LPUT_PS	;Reciclamos variables
LDEL_M:	equ	LPUT_M
LDEL_SA:	equ	LPUT_S
LDEL_DA:	equ	LPUT_D
LDEL_SS:	equ	LPUT_T
LDEL_DS:	equ	LPUT_E


;--- L_PUSH/L_ENQ:  Inserta un elemento en la lista considerando
;                   que es una pila o una cola (lo inserta al final)
;    Entrada: IX = Puntero al descriptor de la tabla
;             BC = Longitud del elemento
;             HL = Direccion del elemento
;    Salida:  Cy = 1 si no hay memoria libre
;    Regist:  AF, BC, DE, HL

L_PUSH:	ld	a,3
	jp	L_PUTE

L_ENQ:	equ	L_PUSH


;--- L_POP:   Extrae (borra) un elemento de la lista considerando
;             que es una pila (extrae el ultimo)
;    Entrada: IX = Puntero al descriptor de la tabla
;    Salida:  Cy = 1 si la lista estaba vacia
;             El penultimo elemento pasa a ser el ultimo
;    Regist:  AF, BC, DE, HL

L_POP:	ld	a,2
	jp	L_DELE


;--- L_DEQ:   Extrae (borra) un elemento de la lista considerando
;             que es una cola (extrae el primero)
;    Entrada: IX = Puntero al descriptor de la tabla
;    Salida:  Cy = 1 si la lista estaba vacia
;             El segundo elemento pasa a ser el primero
;    Regist:  AF, BC, DE, HL

L_DEQ:	ld	a,1
	jp	L_DELE


;--- L_DEST:  Destruye una lista
;    Entrada: IX = Puntero al descriptor de la tabla
;    Regist:  AF, BC, DE, HL

L_DEST:	call	L_POP
	jr	nc,L_DEST
	ret


;--- L_SAVE:  Guarda una lista en un fichero (requiere DOS 2).
;    Entrada: IX = Puntero al descriptor de la tabla
;             DE = Ruta + nombre del fichero y B=255
;                  (creara ese fichero), o
;             B  = FH de un fichero abierto
;                  (grabara en ese fichero a partir del puntero actual)
;             HL = Bufer de tamanyo = elemento mas grande lista + 2
;    Salida:  Cy = 1 si hay error de disco
;             A  = Error de disco, si lo hay
;             Si B=255, el fichero es cerrado al final
;    Formato del fichero:
;    Num. elementos (3 bytes) + tam. elem (2 bytes) + elem. + ... + 0 + 0
;    Regist:  F, BC, DE, HL

L_SAVE:	call	SAVEP2
	call	TPA0
	ld	(LS_BUFD),hl	;Guarda puntero original de la lista
	call	L_GETP
	push	af,hl

	ld	a,255
	ld	(LSAVFLG),a
	ld	a,b
	cp	255
	jr	nz,LSAVOK1

	;--- Inicializacion del fichero

	xor	a	;Crea y abre fichero
	ld	bc,_CREATE
	call	DOSENTRY
	jp	nz,LSAVE2
	ld	(LSAVFLG),a
	ld	a,b
LSAVOK1:	ld	(FHLS),a

	call	L_GETN	;Escribe num. de elementos en el fichero
	ld	de,(LS_BUFD)
	ex	de,hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	ld	(hl),a
	ld	bc,3
	call	F_WRITE

	call	L_EMPTY	;Termina si la lista esta vacia
	jr	c,LSAV_F
	call	L_SETPF	;Puntero al primer elemento

	;--- Bucle de grabacion de elementos

LSAV_B:	call	L_GETP
	push	af,hl,ix
	call	_FUN11	;Obtiene seg, lo pone en pag.2
	pop	ix,hl,af	;(era "call FUN11" en v. 1.21)

	ld	de,(LS_BUFD)
	dec	hl
	dec	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	inc	hl
	dec	bc	;Resta el tamanyo de los punteros
	dec	bc
	dec	bc
	dec	bc
	dec	bc
	dec	bc
	ld	a,c
	ld	(LSAV_T),a
	ld	(de),a
	ld	a,b	;Tamanyo (con punteros) a LSAV_T
	inc	de	;y a (LS_BUFD)
	ld	(LSAV_T+1),a
	ld	(de),a
	ld	(SAVEHL),hl	;Escribe tamanyo a disco
	ld	bc,2
	call	F_WRITE
	ld	hl,(SAVEHL)
	inc	hl	;Se salta los punteros
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	inc	hl

LSAV_B2:	ld	bc,(LSAV_T)	;Escribe en bloques de 1024 bytes
	dec	bc
	bit	7,b	;traspasandolos primero al bufer (LS_BUFD)
	jr	nz,LSAV_NX
	;inc     bc

	;dec     bc
	ld	a,b
	and	%11111100
	inc	bc
	jr	z,LSAVB2OK
	ld	bc,1024
LSAVB2OK:	push	bc
	ld	de,(LS_BUFD)
	ldir
	pop	bc
	ld	(SAVEHL),hl
	call	F_WRITE
	ld	hl,(LSAV_T)
	ld	bc,1024
	or	a
	sbc	hl,bc
	ld	(LSAV_T),hl
	ld	hl,(SAVEHL)
	jr	LSAV_B2

;LSAV_B:     ld      de,(LS_BUFD)     ;Pone tamanyo + elemento en (LS_BUFD)
;            inc     de               ;y lo graba en el fichero
;            inc     de
;            call    L_GETCE
;            dec     de
;            ld      a,b
;            ld      (de),a
;            dec     de
;            ld      a,c
;            ld      (de),a
;            inc     bc
;            inc     bc
;            call    F_WRITE

LSAV_NX:	call	L_FWD	;Siguiente elemento, si quedan
	jr	nc,LSAV_B

	;--- Cierre del fichero y finalizacion

LSAV_F:	ld	hl,(LS_BUFD)	;Escribe dos bytes 0 como terminacion
	ld	(hl),0
	inc	hl
	ld	(hl),0
	ld	bc,2
	call	F_WRITE

	ld	a,(LSAVFLG)
	or	a
	jr	nz,LSAVOK2

	ld	a,(FHLS)	;Cierra el fichero si lo habiamos creado
	ld	b,a
	ld	c,_CLOSE
	call	5

LSAVOK2:	pop	hl,af	;Restaura puntero de la lista
	call	L_SETP

	xor	a
	call	UNTPA0
	call	LOADP2
	ret

	;--- Error: restaura puntero de la lista y termina

LSAV_E:	push	af
	ld	a,(LSAVFLG)
	or	a
	ld	a,(FHLS)
	ld	b,a
	ld	c,_CLOSE
	call	z,5
	pop	af

LSAVE2:	ld	b,a
	pop	hl,af
	call	L_SETP
	ld	a,b
	scf
	call	UNTPA0
	call	LOADP2
	ret

	;--- Subrutina F_WRITE:
	;    Escribe BC bytes desde la dir. (LS_BUFD) en el fichero (FHLS)

F_WRITE:	push	bc
	pop	hl
	ld	a,(FHLS)
	ld	b,a
	ld	c,_WRITE
	ld	de,(LS_BUFD)
	call	DOSENTRY
	ret	z
	pop	de
	jr	LSAV_E

FHLS:	db	0
LS_BUFD:	dw	0
LSAVFLG:	db	0	;0 si hemos creado el fichero, 255 si no
LSAV_T:	dw	0
SAVEHL:	dw	0


;--- L_LOAD:  Carga una lista desde un fichero (requiere DOS 2).
;    Entrada: IX = Puntero al descriptor de la tabla
;                  (el fichero se anyadira al final de la misma)
;             DE = Ruta + nombre del fichero y B=255
;                  (creara ese fichero), o
;             B  = FH de un fichero abierto
;                  (cargara de ese fichero a partir del puntero actual)
;             HL = Bufer de tamanyo = elemento mas grande lista + 2
;    Salida:  Cy = 1 si hay error de disco
;             A  = Error de disco, si lo hay
;                  1 si el error es que no queda memoria
;                  2 si el error es que el elemento es demasiado grande
;             B-DE = Numero de elementos leidos del fichero si no hay error
;             C-HL = Elementos leidos realmente
;             Si B=255, el fichero es cerrado al final
;    Formato del fichero:
;    Num. elementos (3 bytes) + tam. elem (2 bytes) + elem. + ... + 0 + 0
;    Regist:  F, BC, DE, HL

LLOAFLG:	equ	LSAVFLG

L_LOAD:	ld	(LL_BUFD),hl
	ld	(LL_SP),sp
	call	SAVEP2
	call	TPA0

	xor	a
	ld	(LL_ACT),a
	ld	(LL_ACT+1),a
	ld	(LL_ACT+2),a
	dec	a	;Numero de elementos en cabecera:
	ld	(LL_NUM),a	;inicialmente -1
	ld	(LL_NUM+1),a
	ld	(LL_NUM+2),a

	ld	a,255
	ld	(LLOAFLG),a
	ld	a,b
	cp	255
	jr	nz,LLOAOK1

	;--- Apertura del fichero

	xor	a	;Abre el fichero
	ld	c,_OPEN
	call	DOSENTRY
	jp	nz,LLOADE2
	ld	(LLOAFLG),a
	ld	a,b
LLOAOK1:	ld	(FHLS),a

	ld	bc,3	;Lee y guarda numero de elementos
	call	F_READ
	push	ix
	ld	ix,(LL_BUFD)
	ld	l,(ix)
	ld	h,(ix+1)
	ld	a,(ix+2)
	ld	(LL_NUM),hl
	ld	(LL_NUM+2),a
	or	h
	or	l
	pop	ix
	jp	z,LLOAD_F	;Termina directamente si no hay elementos
	ld	a,-1
	ld	(LL_ACT),a
	ld	(LL_ACT+1),a
	ld	(LL_ACT+2),a

	;--- Bucle de carga de elementos

LLOAD_B:	xor	a
	ld	(LL_DUME),a
	ld	hl,(LL_ACT)
	inc	hl
	ld	(LL_ACT),hl
	ld	a,h
	or	l
	jr	nz,LLOAD_BX
	ld	hl,LL_ACT+2	;Incrementa num. de elementos leidos
	inc	(hl)

LLOAD_BX:	ld	bc,2
	call	F_READ
	ld	hl,(LL_BUFD)	;Lee el elemento y lo inserta
	;push    hl               ;al final de la lista
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	a,b	;Fin si es la marca de fin (dos ceros)
	or	c
	jr	z,LLOAD_F

	;dec     bc
	;inc     b
	;ld      a,b
	;dec     b
	;inc     bc
	;and     %11000000        ;Error si el elemento es demasiado
	;ld      a,2              ;grande
	;jr      nz,LLOAD_E
	bit	7,b
	ld	a,2
	jp	nz,LLOAD_E
	push	bc
	pop	hl
	ld	de,16121
	call	COMP
	ld	a,2
	jp	c,LLOAD_E
	ld	(LSAV_T),hl

	;ush    bc               ;Crea elemento de ese tamanyo...
	ld	a,3	;...y deja su segmento en pag. 2
	ld	hl,#4000
	call	L_PUTE
	ld	a,1
	ld	(LL_DUME),a
	jr	c,LLOAD_E
	call	L_GETL
	push	ix,hl
	call	PUT_S2
	pop	hl,ix
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ex	de,hl	;Aqui DE=Inicio del elemento

LLOAD_B2:	ld	bc,(LSAV_T)
	dec	bc
	bit	7,b
	jr	nz,LLOAD_B
	;inc     bc

	;dec     bc
	ld	a,b
	and	%11111100
	inc	bc
	jr	z,LLOAB2OK
	ld	bc,1024
LLOAB2OK:	push	de,bc
	call	F_READ	;Lee trozo...
	pop	bc,de
	ld	hl,(LL_BUFD)	;...y lo copia al segmento del elemento
	ldir

	ld	hl,(LSAV_T)	;Actualiza tamanyo pendiente
	ld	bc,1024	;y lee el siguiente trozo
	or	a
	sbc	hl,bc
	ld	(LSAV_T),hl
	jr	LLOAD_B2

	;push    bc
	;call    F_READ
	;pop     bc,hl
	;ld      a,3
	;call    L_PUTE
	;ld      a,1
	;jr      c,LLOAD_E
	;jr      LLOAD_B          ;Siguiente elemento

	;--- Cierre del fichero y finalizacion

LLOAD_F:	ld	a,(LLOAFLG)
	or	a
	ld	a,(FHLS)	;Cierra el fichero si lo habiamos creado
	ld	b,a
	ld	c,_CLOSE
	call	z,DOSENTRY

	xor	a
LLOAD_F2:	ld	sp,(LL_SP)
	push	af
	ld	a,(LL_DUME)	;Borra elemento a medio crear
	or	a	;si lo hay
	ld	a,2
	call	nz,L_DELE
	call	UNTPA0
	call	LOADP2
	call	PUTLIST
	ld	hl,(LL_ACT)
	ld	a,(LL_ACT+2)
	ld	c,a
	ld	de,(LL_NUM)
	ld	a,(LL_NUM+2)
	ld	b,a
	pop	af
	ret

	;--- Error: cierra fichero y termina

LLOAD_E:	push	af
	ld	a,(LLOAFLG)
	or	a
	ld	a,(FHLS)
	ld	b,a
	ld	c,_CLOSE
	call	z,DOSENTRY
	pop	af

LLOADE2:	scf
	jr	LLOAD_F2
	;ld      sp,(LL_SP)
	;call    LOADP2
	;call    PUTLIST
	;ret

	;--- Subrutina F_READ:
	;    Lee BC bytes a la dir. (LS_BUFD) desde el fichero (FHLS)

F_READ:	push	bc,bc
	pop	hl
	ld	a,(FHLS)
	ld	b,a
	ld	c,_READ
	ld	de,(LS_BUFD)
	call	DOSENTRY
	jr	nz,LLOAD_E
	pop	de	;Si no puede leer los bytes requeridos,
	call	COMP	;genera un error
	ld	a,#C7
	jr	nz,LLOAD_E
	ret

LL_BUFD:	equ	LS_BUFD
LL_NUM:	ds	3
LL_SP:	dw	0
LL_ACT:	ds	3	;Elementos leidos correctamente
LL_DUME:	db	0	;Elemento a medio crear?

	;--- L_LDIR1: Copia de HL en segmento A a DE en TPA, lon. BC
	;             si (LDIR_TPA)=0.
	;             Copia a DE en segmento (LDIR_SEG) si (LDIR_TPA)=-1.

L_LDIR1:	ld	(LDIRSAVEA),a
	ld	a,(LDIR_TPA)
	or	a
	ld	a,(LDIRSAVEA)
	jr	z,L_LDIR12

L_LDIR11:	push	ix	;A TPA
	call	L_LDIRP
	call	_FUN16	;ERA "call FUN16" EN v. 1.21
	pop	ix
	ret

L_LDIR12:	push	ix	;A segmento
	call	L_LDIRP
	push	af
	ld	a,(LDIR_SEG)
	ld	b,a
	pop	af
	call	_FUN14	;ERA "call FUN14" EN v. 1.21
	pop	ix
	ret

L_LDIRP:	push	hl
	pop	ix
	push	de
	pop	iy
	push	bc
	pop	hl
	ret

	;--- L_LDIR2: Copia de HL en TPA a DE en segmento A, lon. BC
	;             si (LDIR_TPA)=0.
	;             Copia de DE en segmento (LDIR_SEG) si (LDIR_TPA)=-1.

L_LDIR2:	ld	(LDIRSAVEA),a
	ld	a,(LDIR_TPA)
	or	a
	ld	a,(LDIRSAVEA)
	jr	z,L_LDIR22

L_LDIR21:	push	ix	;De TPA
	call	L_LDIRP
	ld	b,a
	call	_FUN15	;ERA "call FUN15" EN v. 1.21
	pop	ix
	ret

L_LDIR22:	push	ix	;De segmento
	call	L_LDIRP
	push	af
	ld	a,(LDIR_SEG)
	pop	bc
	call	_FUN14	;ERA "call FUN14" EN v. 1.21
	pop	ix
	ret

LDIR_TPA:	db	0	;#FF para transf. a/de TPA, 0 para seg.
LDIR_SEG:	db	0	;Segmento si (LDIR_TPA)=0
LDIRSAVEA:	db	0


	;--- GETLIST: Obtiene el descriptor de una lista a partir
	;             de su localizador
	;    Entrada: A-IX = Localizador de la lista
	;                    (identificador en A e IX=0,
	;                     o direccion en A-IX)
	;    Salida:  Descriptor en LISTA y direccion en L_DIR
	;             o Cy=1 si la lista/el segmento no existe
	;    Preserva todos los registros

GETLIST:	ld	d,a
	push	bc,de,hl,ix,iy
	call	_GETLIST
	pop	iy,ix,hl,de,bc
	ld	a,d
	ret

_GETLIST:	ld	d,a
	ld	a,ixh
	or	ixl
	ld	a,d
	jr	nz,GETLIST2

	;Con identificador

	ld	l,a
	ld	h,0
	ld	c,a
	ld	b,0
	add	hl,hl
	add	hl,bc
	ld	bc,TABLISTS
	add	hl,bc
	ld	a,(hl)
	or	a
	scf
	ret	z	;Error si esa lista no existe
	ld	b,(hl)
	inc	hl
	ld	a,(hl)
	ld	ixl,a
	inc	hl
	ld	a,(hl)
	ld	ixh,a
	ld	a,b

	;Con direccion directa

GETLIST2:	ld	(L_DIR),a
	push	ix
	pop	hl
	ld	(L_DIR+1),hl
	ld	b,4
	ld	iy,LISTA
	ld	hl,12
	call	_FUN14	;Obtiene descriptor de la lista
	or	a	;(era "call FUN14" en v. 1.21)
	ret


	;--- PUTLIST: Restaura el descriptor de la lista a su
	;             direccion original
	;             Preserva todos los registros

PUTLIST:	push	af,bc,de,hl,ix,iy
	ld	a,(L_DIR)
	ld	hl,(L_DIR+1)
	ld	b,a
	push	hl
	pop	iy
	ld	a,4
	ld	ix,LISTA
	ld	hl,12
	call	_FUN14	;ERA "call FUN14" EN v. 1.21
	pop	iy,ix,hl,de,bc,af
	ret

TAB_DIR:	;
L_DIR:	ds	3
LISTA:	ds	12
NUMLISTS:	db	0
TABLISTS:	ds	256*3

	;--- TPA0: Guarda el estado de la pagina 0 y pone TPA

TPA0:	push	af,bc,de,hl,ix
	ld	a,0
	call	GETSLOT
	ld	a,b
	ld	(SLOTP0),a
	ld	a,c
	ld	(SEGP0),a
	ld	a,(TABSEGS)
	res	4,a
	call	PUTSLOT0
	ld	a,(TABSEGS+1)
	call	PUT_P0
	pop	ix,hl,de,bc,af
	ret

	;--- UNTPA0: Restaura el estado de la pagina 0

UNTPA0:	push	af,bc,de,hl,ix
	ld	a,(SLOTP0)
	call	PUTSLOT0
	ld	a,(SEGP0)
	call	PUT_P0
	pop	ix,hl,de,bc,af
	ret

SLOTP0:	db	0
SEGP0:	db	0

	;--- Establece/desestablece el flag EXECU

SET_EXECU:	push	af
	ld	a,-1
	jr	EXEC_DIR
RES_EXECU:	nop		;Puesto a NOP o RET por el codigo de pag. 3
	push	af
	xor	a
EXEC_DIR:	ld	(0),a
	pop	af
	ret

	;--- Guarda/restaura el estado de las variables
	;    usadas por el DOS para guardar el estado

SAVE_DOS_VARS:	push	af,hl
	ld	hl,(#F2EA)
	ld	(DOSVARS),hl
	ld	hl,(#F2CB)
	ld	(DOSVARS+2),hl
	ld	a,(#F2CD)
	ld	(DOSVARS+4),a
	pop	hl,af
	ret

LOAD_DOS_VARS:	push	af,hl
	ld	hl,(DOSVARS)
	ld	(#F2EA),hl
	ld	hl,(DOSVARS+2)
	ld	(#F2CB),hl
	ld	a,(DOSVARS+4)
	ld	(#F2CD),a
	pop	hl,af
	ret

DOSVARS:	ds	5

SEGSLOTS:	ds	32	;Pila de slot+seg para SAVEP2/LOADP2
DISKBUF:	;
PARTRE1!:	;
