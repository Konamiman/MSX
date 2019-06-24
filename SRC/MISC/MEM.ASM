;Mapped memory listing tool for DOS 2.
;Needs NUMTOASC.ASM appended at the end.

;============================
	
	;Sacadero de la memoria para DOS 2 
	;Por Konami Man, 26-5-96 y 31-5-19 (!)
	;Necesita NUMTOASC al final 

	;La salida por pantalla ser tal que asi (ejemplo): 

; Memorytestator - by Konami Man, 26-5-1996
;
; Mappers found: 2
;
;          Slot             Total           Reserved             Free
;          ----             -----           --------             ----
;
;            2              1024K                32K             992K
;          3-2               128K               128K               0K
;
;          All              1136K               160K             996K
;
;  Ramdisk size: 128K
;  MemMan version: 2.42
;  TPA end address: #D706 - TPA size is 53K

TERM0:	equ	#00
STROUT:	equ	#09
DOSVER:	equ	#6F
RAMD:	equ	#68
EXTBIO:	equ	#FFCA

	org	#100

    ld de,WELCOME_S
    ld c,STROUT
    call 5

	; *** Obtencion de la tabla del mapeador 

    xor a
	ld	de,#0401
	call	EXTBIO
    or a
    jr nz,OKMSR

    ld  c,STROUT
    ld  de,NOMSR_S
    call 5
    jp ENDLISTMEM

OKMSR:
	push	hl

	pop	ix
	ld	iy,_SLOT

	; *** Calculo del numero de mapeadores 

	ld	e,0
	ld	bc,8
	push	ix
OTROMAP:	ld	a,(ix)
	or	a
	jr	z,OKNUMAP
	inc	e
	add	ix,bc
	jr	OTROMAP
OKNUMAP:	pop	ix
	ld	a,e
	ld	(NUMMAP),a

	ld	d,0	;Convertimos a ASCII 
	ld	hl,_NUMMAP
	ld	b,2
	ld	c," "
	ld	a,%11000
	call	NUMTOASC

	ld	de,STR10 ;Sacamos numero de mapeadores 
	ld	c,STROUT
	call	5

	ld	de,STR2     ;Sacamos linea de indice 
	ld	c,STROUT
	call	5

	; *** Bucle de salida de los datos 

	; Slot 

BUCDAT:	ld	a,(ix)
	or	a
	jp	z,NOMASLOT
	bit	7,a
	jr	nz,EXPSLOT

NOEXP:	add	a,"0"	;Slot no expandido 
	ld	(iy+2),a
	ld	a," "
	ld	(iy),a
	ld	(iy+1),a
	jr	OKSLOT

EXPSLOT:	push	af	;Slot expandido 
	and	%11
	add	"0"
	ld	(iy),a
	ld	a,"-"
	ld	(iy+1),a
	pop	af
	and	%1100
	srl	a
	srl	a
	add	"0"
	ld	(iy+2),a
OKSLOT:	; 

	; Memoria total 

	ld	a,(ix+1)
	ld	d,0	;Multiplicamos el no. de segmentos por 1024 
	ld	e,a
	ld	b,4
MULTI:	sla	e
	rl	d
	djnz	MULTI

	ld	hl,(TOTAL)	;Aadimos a la cantidad de memoria total 
	add	hl,de
	ld	(TOTAL),hl

	ld	hl,_TOTAL	;Transformamos numero a ASCII 
	ld	b,5
	ld	c," "
	ld	a,%11000
	call	NUMTOASC

	; Memoria ocupada 

	ld	a,(ix+3)
	ld	b,a
	ld	a,(ix+4)
	add	a,b
	ld	d,0	;Multiplicamos el no. de segmentos por 1024  
	ld	e,a
	ld	b,4
MULTI2:	sla	e
	rl	d
	djnz	MULTI2

	ld	hl,(OCUP)	;Aadimos a la cantidad de memoria total 
	add	hl,de
	ld	(OCUP),hl

	ld	hl,_OCUP	;Transformamos numero a ASCII 
	ld	b,5
	ld	c," "
	ld	a,%11000
	call	NUMTOASC

	; Libre 

	ld	a,(ix+2)
	ld	d,0	;Multiplicamos el no. de segmentos por 1024 
	ld	e,a
	ld	b,4
MULTI3:	sla	e
	rl	d
	djnz	MULTI3

	ld	hl,(LIBRE)	;Aadimos a la cantidad de memoria total 
	add	hl,de
	ld	(LIBRE),hl

	ld	hl,_LIBRE	;Transformamos numero a ASCII 
	ld	b,5
	ld	c," "
	ld	a,%11000
	call	NUMTOASC

	; Sacamos cadena de datos de ese mapeador y volvemos a empezar 

	ld	de,STR3
    ld  c,STROUT
	call	5

	ld	bc,8	;Apuntamos al siguiente mapeador 
	add	ix,bc
	jp	BUCDAT

	; *** Sacamos datos totales de la memoria 

NOMASLOT:	ld	de,(TOTAL)	;Memoria total 
	ld	hl,_TOTAL2
	ld	b,5
	ld	c," "
	ld	a,%11000
	call	NUMTOASC

	ld	de,(OCUP)
	ld	hl,_OCUP2	;Memoria ocupada 
	ld	b,5
	ld	c," "
	ld	a,%11000
	call	NUMTOASC

	ld	de,(LIBRE)
	ld	hl,_LIBRE2	;Memoria libre 
	ld	b,5
	ld	c," "
	ld	a,%11000
	call	NUMTOASC

	ld	de,STR4
	ld	c,STROUT
	call	5

ENDLISTMEM:

	;*** Sacamos datos del RAMDISK (solo en DOS 2)

    ld	c,DOSVER
	call	5
	ld	a,b
	cp	2
    jr c,OKRDISK

	ld	c,RAMD
	ld	b,#ff
	call	5

	ld	a,b
	or	a
	jr	nz,SIRAMD

NORAMD:	
	ld	de,STR5 ;Cadena "No hay Ramdisk" 
    ld  c,9
	call	5
	jp	OKRDISK

SIRAMD:	ld	d,0	;Multiplicamos el no. de segmentos por 1024 
	ld	e,b
	ld	b,4
MULTI4:	sla	e
	rl	d
	djnz	MULTI4

	ld	hl,_RAMD	;Transformamos numero a ASCII 
	ld	b,4
	ld	c," "
	ld	a,%11000
	call	NUMTOASC

	ld	de,STR6 ;Sacamos tamagno del Ramdisk 
	ld	c,STROUT
	call	5
OKRDISK:	; 

	;*** Sacamos datos del MEMMAN 

	ld	de,#4D1E
	ld	a,34
	call	EXTBIO
	cp	34+"M"
	jr  z,SIMM

NOMM:
	ld	de,STR7 ;Cadena "No hay Memman" 
	ld	c,STROUT
	call	5
	jr	OKMM

SIMM:	ld	a,d	;Componemos version del MemMan 
	add	a,"0"
	ld	(_MMVER),a
	ld	a,e
	add	a,"0"
	ld	(_MMVER+2),a

	ld	de,STR8 ;Sacamos version del MEMMAN 
	ld	c,STROUT
	call	5
OKMM:	; 

	;*** Sacamos datos sobre TPA 

	ld	de,(6)
	ld	hl,_TPAEND	;Transformamos numero a ASCII 
	ld	b,6
	ld	c," "
	ld	a,%11010
	call	NUMTOASC

	ld	b,10	;Dividimos por 1024
MULTI5:	srl	d
	rr	e
	djnz	MULTI5

	ld	hl,_TPASIZ	;Transformamos numero a ASCII 
	ld	b,2
	ld	c," "
	ld	a,%11000
	call	NUMTOASC

	ld	de,STR9 ;Sacamos datos de la TPA
	ld	c,STROUT
	call	5

	;*** Fin del programa 

	ld	c,TERM0
	jp	5

	;*** Zona de datos 

NUMMAP:	db	0
TOTAL:	dw	0
OCUP:	dw	0
LIBRE:	dw	0

WELCOME_S:
	db	13,10,"Memorytestator (the judgement byte)"
	db	" - by Konamiman, 26-5-1996 & 31-5-2019 (!)",13,10
	db	13,10,"$"

STR2:	db	"          Slot            Memory           Reserved     "
	db	"       Free",13,10
	db	"          ----            ------           --------     "
	db	"       ----",13,10,13,10,"$"

STR3:	db	"           "
_SLOT:	ds	15," "
_TOTAL:	db	"     K"
	ds	13," "
_OCUP:	db	"     K"
	ds	10," "
_LIBRE:	db	"     K",13,10,"$"

STR4:	db	13,10,"Total:     "
_SLOT2:	ds	15," "
_TOTAL2:	db	"     K"
	ds	13," "
_OCUP2:	db	"     K"
	ds	10," "
_LIBRE2:	db	"     K",13,10,13,10,"$"

NOMSR_S: db "Mapper support routines not found.",13,10,13,10,"$"

STR5:	db	"RAM disk not installed",13,10,"$"

STR6:	db	"RAM disk size: "
_RAMD:	db	"    K",13,10,"$"

STR7:	db	"MemMan not installed",13,10,"$"

STR8:	db	"MemMan version: "
_MMVER:	db	" . ",13,10,"$"

STR9:	db	"TPA end address: "
_TPAEND:	ds	6," "
	db	" - TPA size is "
_TPASIZ:	db	"  K",13,10,"$"

STR10:	db	"Mappers found: "
_NUMMAP:	db	"  ",13,10,13,10,"$"

;------------------------------------------------------------------------------------------

	;Conversion de un entero de 16 bits a una cadena de caracteres
	;
	;Entrada: DE = Numero a convertir
	;         HL = Buffer para depositar la cadena
	;         B  = Numero total de caracteres de la cadena
	;              sin incluir signos de terminacion
	;         C  = Caracter de relleno
	;              El numero se justifica a la derecha, y los
	;              espacios sobrantes se rellenan con el caracter (C).
	;              Si el numero resultante ocupa mas caracteres que
	;              los indicados en B, este registro es ignorado
	;              y la cadena ocupa los caracteres necesarios.
	;              No se cuenta el caracter de terminacion, "$" o 00,
	;              a efectos de longitud.
	;         A = &B ZPRFFTTT
	;   TTT = Formato del numero resultante
	;               0: decimal
	;               1: hexdecimal 
	;               2: hexadecimal, comenzando con "&H"
	;               3: hexadecimal, comenzando con "#"
	;               4: hexadecimal, acabado en "H"
	;               5: binario 
	;               6: binario, comenzando con "&B"
	;               7: binario, acabado en "B"
	;   R   = Rango del numero
	;               0: 0..65535 (entero sin signo)
	;               1: -32768..32767 (entero en complemento a dos)
	;                  Si el formato de salida es binario,
	;                  el numero se interpreta como entero de 8 bits
	;                  y el rango es 0..255. Es decir, el bit R
	;                  y el registro D son ignorados.
	;   FF  = Tipo de finalizacion de la cadena
	;               0: Adicion de un caracter "$"
	;               1: Adicion de un caracter 00
	;               2: Puesta a 1 del 7o bit del ultimo caracter
	;               3: Sin finalizacion especial
	;   P   = Signo "+"
	;               0: No agnadir un signo "+" a los numeros positivos
	;               1: Agnadir un signo "+" a los numeros positivos
	;   Z   = Ceros sobrantes
	;               0: Quitar ceros a la izquierda
	;               1: No quitar ceros a la izquierda
	;
	;Salida: Cadena a partir de (HL)
	;        B = Numero de caracteres de la cadena que forman
	;            el numero, incluyendo el signo y el indicador
	;            de tipo si son generados
	;        C = Numero de caracteres totales de la cadena
	;            sin contar el "$" o el 00 si son generados 
	;        No modifica HL, DE, A, IX, IY ni reg. alt.


NUMTOASC:	push	af,ix,de,hl
	ld	ix,WorkArea
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
	ld	hl,BufRut
	ld	(ix+10),l	;Buffer de la rutina
	ld	(ix+11),h

ChkTyp:	ld	a,(ix+0)	;Divisor a 2 o a 16, o dejar a 10
	or	a
	jr	z,Continue1
	cp	5
	jp	nc,IsBin
IsHexa:	ld	a,16
	jr	ActualType
IsBin:	ld	a,2
	ld	d,0
	res	0,(ix+6)	;Si es binario esta entre 0 y 255
ActualType:	ld	(ix+7),a

Continue1:	ld	a,(ix+0)	;Comprueba si hay que poner "H" o "B"
	cp	7	;al final
	jp	z,PutB
	cp	4
	jr	nz,ChkTyp2
PutH:	ld	a,"H"
	jr	PutHorB
PutB:	ld	a,"B"
PutHorB:	ld	(hl),a
	inc	hl
	inc	(ix+4)
	inc	(ix+5)

ChkTyp2:	ld	a,d	;Si el numero es 0 nunca se pone signo  
	or	e
	jr	z,NoSign
	bit	0,(ix+6)	;Comprueba rango  
	jr	z,SignPos
CheckSign:	bit	7,d
	jr	z,SignPos
SignNeg:	push	hl	;Niega el numero  
	ld	hl,0	;Signo=0:sin signo; 1:+; 2:-  
	xor	a
	sbc	hl,de
	ex	de,hl
	pop	hl
	ld	a,2
	jr	EndSign
SignPos:	bit	1,(ix+6)
	jr	z,NoSign
	ld	a,1
	jr	EndSign
NoSign:	xor	a
EndSign:	ld	(ix+12),a

Continue2:	ld	b,4
	xor	a
	cp	(ix+0)
	jp	z,IsDec
	ld	a,4
	cp	(ix+0)
	jp	nc,IsHexa2
IsBin2:	ld	b,8
	jr	IsHexa2
IsDec:	ld	b,5
IsHexa2:	nop

	;DIVISION 16 POR 16   
	;Entrada:  DE=dividendo
	;          (IX+7)=divisor
	;Salida:   DE=cociente
	;          A=resto

	push	de
division:	push	bc,hl
	ld	a,d
	ld	c,e
	ld	d,0
	ld	e,(ix+7)
div16:	ld	hl,0
	ld	b,16
loop16:	rl	c
	rla
	adc	hl,hl
	sbc	hl,de
	jr	nc,$+3
	add	hl,de
	ccf
	djnz	loop16
	rl	c
	rla
done:	ld	d,a
	ld	e,c
	ld	a,l
	pop	hl,bc

ChkRest9:	cp	10	;Convierte el resto en caracter
	jp	nc,IsGr9
IsLw9:	add	a,"0"
	jr	PutInBuf
IsGr9:	sub	10
	add	a,"A"

PutInBuf:	ld	(hl),a	;Pone caracter en buffer
	inc	hl
	inc	(ix+4)
	inc	(ix+5)
	djnz	division
	pop	de

ChkOutZros:	bit	2,(ix+6)	;Comprueba si hay que eliminar ceros
	jr	nz,CheckAmp
KillZeros:	dec	hl
	ld	b,(ix+5)
	dec	b	;B=no. de digitos a comprobar
ChkforZro:	ld	a,(hl)
	cp	"0"
	jr	nz,EndKilling
KillZro:	dec	hl
	dec	(ix+4)
	dec	(ix+5)
	djnz	ChkforZro
EndKilling:	inc	hl

CheckAmp:	ld	a,(ix+0)	;Coloca "#", "&H" o "&B" si es necesario
	cp	2
	jr	z,PutAmpH
	cp	3
	jr	z,Put#
	cp	6
	jr	nz,PutSign
PutAmpB:	ld	a,"B"
	jr	PutAmpHorB
Put#:	ld	a,"#"
	ld	(hl),a
	inc	hl
	inc	(ix+4)
	inc	(ix+5)
	jr	PutSign
PutAmpH:	ld	a,"H"
PutAmpHorB:	ld	(hl),a
	inc	hl
	ld	a,"&"
	ld	(hl),a
	inc	hl
	inc	(ix+4)
	inc	(ix+4)
	inc	(ix+5)
	inc	(ix+5)

PutSign:	ld	a,(ix+12)	;Coloca el signo
	or	a
	jr	z,ChkLon
SgnType:	cp	1
	jr	nz,PutNeg
PutPos:	ld	a,"+"
	jr	Put
	jr	ChkLon
PutNeg:	ld	a,"-"
Put:	ld	(hl),a
	inc	hl
	inc	(ix+4)
	inc	(ix+5)

ChkLon:	ld	a,(ix+2)	;Pone caracteres de relleno si necesario
	cp	(ix+4)
	jp	c,ChkBit7
	jr	z,ChkBit7
AddChars:	sub	(ix+4)
	ld	b,a
	ld	a,(ix+3)
Put1Char:	ld	(hl),a
	inc	hl
	inc	(ix+4)
	djnz	Put1Char

ChkBit7:	;push    hl              ;Guardamos pos. final del buffer
	ld	l,(ix+10)	;para poner despues "$" o 0
	ld	h,(ix+11)	;si es necesario
	ld	a,(ix+1)
	cp	2
	jr	nz,Invert
SetBit7:	set	7,(hl)	;Si tipo=2, poner a 1 bit 7 1er car. 


Invert:	xor	a	;Invierte la cadena
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
InvLoop:	push	bc
	ld	a,(de)
	ld	b,(hl)
	ex	de,hl
	ld	(de),a
	ld	(hl),b
	ex	de,hl
	inc	hl
	dec	de
	pop	bc
	djnz	InvLoop
	;pop     hl               ;Recuperamos pos. final de buffer
ToUsBuf:	ld	l,(ix+10)
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
	jr	z,PutDollar
	cp	1
	jr	nz,End
PutZero:	xor	a
	jr	Put1
PutDollar:	ld	a,"$"
Put1:	ld	(hl),a

End:	ld	b,(ix+5)
	ld	c,(ix+4)
	pop	hl,de,ix,af
	ret

WorkArea:	defs	16
BufRut:	ds	10
