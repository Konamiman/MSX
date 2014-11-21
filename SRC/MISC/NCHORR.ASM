;Demonstration of system hooks patching:
;When installed, a BEEP will be emitted when pressing CTRL+SHIFT.
;Published in SD MESXES #13.

;=========================================

;Listado 10: NestorChorrada 1.0
;BEEPea al pulsar CTRL+SHIFT
;Parchea el gancho de la interrupcion del reloj
;Parchea el gancho de la BIOS extendida usando el identificador DE=#22FF
;Por Konami Man, para SD MESXES#13 con carinio

H_TIMI:	equ	#FD9F	;Gancho de la interrupcion del reloj
EXTBIO:	equ	#FFCA	;Gancho de la BIOS extendida
HIMEM:	equ	#F349	;Limite superior del MSXDOS.SYS
CALSLT:	equ	#001C	;Llama a una rutina en otro slot
EXPTBL:	equ	#FCC1	;Indica el slot de la BIOS
BEEP:	equ	#00C0	;Produce un BEEP
ENASLT:	EQU	#0024	;Activa un slot en una pagina
ENDTPA:	equ	#0006	;Fin de la zona de usuario (TPA)
STROUT:	equ	#09	;Muestra una cadena en pantalla

;****************************
;*                          *
;* PROGRAMA (DES)INSTALADOR *
;*                          *
;****************************

	org	#100

;--- Comprobamos que hay suficiente TPA (#0006 >= #C100)
;    En caso contrario mostramos error y terminamos

	ld	a,(ENDTPA+1)
	cp	#C1
	jr	nc,OKTPA

	ld	de,ERR_NOTPA
	ld	c,STROUT
	call	5
	ld	c,0
	jp	5

ERR_NOTPA:	db	"ERROR: TPA demasiado pequenio! "
	db	"Yo asi no me instalo!!",13,10,"$"

;--- Comprobamos si NestorChorrada ya esta instalado,
;    en ese caso pasamos a la rutina de desinstalacion

OKTPA:	ld	de,#22FF
	xor	a
	call	EXTBIO
	cp	#22	;Si devuelve A=34, es que ya esta instalado
	jp	z,DESINST

;--- Copiamos los antiguos ganchos en la futura rutina residente.
;    Hay que copiarlos dos veces porque esta ensamblada dos veces.

	ld	hl,H_TIMI
	ld	de,OLDTIM0001
	ld	bc,5
	ldir
	ld	hl,H_TIMI
	ld	de,OLDTIM0002
	ld	bc,5
	ldir

	ld	hl,EXTBIO
	ld	de,OLDBIO0001
	ld	bc,5
	ldir
	ld	hl,EXTBIO
	ld	de,OLDBIO0002
	ld	bc,5
	ldir

;--- Reservamos memoria en la pagina 3 para la rutina,
;    guardamos los valores antiguo y nuevo de HIMEM en la misma
;    y la copiamos en la zona reservada

	ld	hl,(HIMEM)	;Guardamos antiguo HIGHMEM dos veces,
	ld	(OLDHM0001),hl	;y establecemos el nuevo
	ld	(OLDHM0002),hl
	ld	bc,ENDRES0001-INIRES0001
	or	a
	sbc	hl,bc	;Nuevo HIMEM = antiguo - longitud rutina
	ld	(HIMEM),hl
	ld	(NEWHM0001),hl
	ld	(NEWHM0002),hl

	ld	hl,RUTINA1	;Copiamos la rutina a pag. 3
	ld	de,RUTINA2	;en la nueva zona reservada
	ld	ix,(HIMEM)
	ld	bc,ENDRES0001-INIRES0001
	call	REUBICA

;--- Establecemos los nuevos ganchos:
;    El nuevo H_TIMI esta justo al principio de la rutina,
;    y el nuevo EXTBIO 3 bytes despues.

	di

	ld	hl,(HIMEM)	;HL = NEWTIM
	ld	a,#C3	;Codigo de la instruccion JP

	ld	(H_TIMI),a
	ld	(H_TIMI+1),hl

	inc	hl
	inc	hl
	inc	hl	;HL = NEWBIO
	ld	(EXTBIO),a
	ld	(EXTBIO+1),hl

	ei

;--- Finalizacion de la instalacion con el _SYSTEM pirulero

	ld	de,OKINST
	ld	c,STROUT
	call	5
	jp	CALSYS

OKINST:	db	"NestorChorrada ha sido instalado!",13,10,"$"

;--- DESINSTALACION: Saltamos aqui si NestorChorrada ya esta instalado.
;    Entonces comprobamos si el parametro es "U" o "u".
;    Si lo es, intentamos desinstalar: comprobamos que NEWHM=(HIMEM),
;    en ese caso desinstalamos, si no mostramos error "no se puede desinstalar".
;    Si no lo es, mostramos error "ya esta instalado".

DESINST:	ld	a,(#0082)
	or	%00100000
	cp	"u"
	jr	z,SI_DES

NO_DES:	ld	de,ERR_YAINS
	ld	c,STROUT
	call	5
	ld	c,0
	jp	5

ERR_YAINS:	db	"ERROR: Ya estoy instalado!"
	db	"No me puedo volver a idemar.",13,10,"$"

SI_DES:	ld	de,#22FF
	call	EXTBIO	;Devuelve HL=NEWHM, BC=OLDHM
	ld	de,(HIMEM)
	or	a	;Si HL-DE=0 es que son iguales,
	sbc	hl,de	;entonces podemos desinstalar.
	ld	a,h
	or	l
	jp	z,SI_DES2

	ld	de,ERR_OTRO
	ld	c,STROUT
	call	5
	ld	c,0
	jp	5

ERR_OTRO:	db	"ERROR: Hay otro TSR instalado despues de mi!",13,10
	db	"No me puedo desinstalar si no se quita de enmedio.",13,10,"$"

SI_DES2:	push	bc
	pop	ix	;IX=OLDHM, valor a restaurar en HIMEM

	ld	hl,(HIMEM)
	ld	bc,6
	add	hl,bc	;Ahora HL=OLDTIM
	di

	ld	(HIMEM),ix	;OLDHM -> HIMEM

	ld	de,H_TIMI	;Retauramos ganchos:
	ld	bc,5	;OLDTIM -> H_TIM
	ldir
	ld	de,EXTBIO
	ld	bc,5
	ldir		;OLDBIO -> EXTBIO

	ld	de,OKDES	;Terminamos!
	ld	c,STROUT
	call	5
	jp	CALSYS		;Para que el MSXDOS.SYS vuelva a cargarse

OKDES:	db	"NestorChorrada ha sido desinstalado!",13,10,"$"

;--- Subrutina de reubicacion de un codigo
;    Entrada: HL = Primera copia
;             DE = Segunda copia
;             IX = Destino
;             BC = Longitud

;Listado 5: Reubicaci"n de una rutina a partir de
;             dos copias en direcciones conocidas
;Entrada:     HL = Direcci"n de la primera copia
;             DE = Direcci"n de la segunda copia
;             IX = Direcci"n de destino
;             BC = Longitud de la rutina
;--EL BYTE BAJO DE DE NO PUEDE SER IGUAL AL DE HL!!

REUBICA:	push	bc,de,hl	;Primero copiamos el c"digo tal cual
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

	call	CHKCOMP	;(El contador ha llegado a 0?
	jr	z,FINREUB	;S!: -sacab"!

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
;    Previamente se copia a #8000, para conectar la BIOS y el BASIC

CALSYS:	ld	hl,CALSYS2
	ld	de,#8000
	ld	bc,#100
	ldir
	jp	#8000

CALSYS2:	ld	a,(EXPTBL)
	push	af
	ld	h,0
	call	ENASLT
	pop	af
	ld	h,#40
	call	ENASLT
	xor	a
	ld	hl,#F41F
	ld	(#F860),hl
	ld	hl,#F423
	ld	(#F41F),hl
	ld	(hl),a
	ld	hl,#F52C
	ld	(#F421),hl
	ld	(hl),a
	ld	hl,#F42C
	ld	(#F862),hl
	ld	hl,#8030	;#8030 = SYSTXT
	jp	#4601

SYSTXT:	db	#3A,#CA,"SYSTEM",0


;***************************************************************
;*                                                             *
;* RUTINA RESIDENTE definida como macro y ensamblada dos veces *
;*                                                             *
;***************************************************************

RUTINA:	macro

INIRES@sym:	;
NEWTIM@sym:	jp	_NEWTIM@sym	;H_TIMI salta aqui
NEWBIO@sym:	jp	_NEWBIO@sym	;EXTBIO salta aqui

OLDTIM@sym:	ds	5
OLDBIO@sym:	ds	5

;--- Destino del nuevo gancho H_TIMI

_NEWTIM@sym:	di
	call	TODOPUSH@sym	;Guarda registros!
	ld	a,(#FBEB)
	and	%00000011
	jp	nz,NOKEY@sym	;Termina si no estan pulsadas CTRL+SHIFT

	call	AUNPULSA@sym
	jp	c,ENDTIM@sym

	ld	ix,BEEP	;Produce el BEEP a traves de la BIOS...
	ld	iy,(EXPTBL-1)
	call	CALSLT

ENDTIM@sym:	call	TODOPOP@sym	;...recupera registros y termina.
	ei
	jp	OLDTIM@sym

NOKEY@sym:	xor	a
	ld	(PULSADO@sym),a
	jr	ENDTIM@sym

AUNPULSA@sym:	ld	a,(PULSADO@sym)	;Devuelve Cy=1 si las teclas ya estaban
	cp	#FF	;pulsadas en la interrupcion anterior,
	scf		;y actualiza el valor de PULSADO
	ret	z	;(#FF si las teclas estan pulsadas)
	ld	a,#FF	;para que sea usado en la proxima int.
	ld	(PULSADO@sym),a
	or	a
	ret
PULSADO@sym:	db	0

;--- Destino del nuevo gancho EXTBIO:
;    Entrada: DE= #22FF
;    Salida:  HL= NEWHM
;             BC= OLDHM
;             A = #22

_NEWBIO@sym:	push	af
	ld	a,d
	cp	#22
	jr	nz,NOBIOS@sym
	ld	a,e
	cp	#FF
	jr	z,OKBIOS@sym
NOBIOS@sym:	pop	af	;DE<>#22FF -> No hace nada y termina
	jp	OLDBIO@sym

OKBIOS@sym:	pop	af
	ld	hl,(NEWHM@sym)
	ld	bc,(OLDHM@sym)
	ld	a,#22
	ret

NEWHM@sym:	dw	0	;Nuevo HIMEM al instalar NestorChorrada
OLDHM@sym:	dw	0	;Antiguo HIMEM al instalar NCH

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

ENDRES@sym:	;                        ;Fin de la parte residente en pagina 3
	endm

;--- ESTAS SON LAS DOS COPIAS DE LA RUTINA

RUTINA1:	RUTINA
RUTINA2:	RUTINA

