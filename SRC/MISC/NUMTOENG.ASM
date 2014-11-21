	;Conversion de un entero de 16 bits a una cadena de caracteres
	;
              ;Entrada: DE = Number to convert
              ;         HL = Buffer to put string including left zeros
              ;         B  = Total number of characters in string
              ;         C  = Filling character
              ;              Number is right justified, and the rest
              ;              spaces are filled with the character passed in (C).
	;         A = &B ZPRFFTTT
              ;   TTT = Format of resulting string
	;               0: decimal
	;               1: hexdecimal 
              ;               2: hexadecimal, beginning with "&H"
              ;               3: hexadecimal, beginning with "#"
              ;               4: hexadecimal, ending with "H"
              ;               5: binary
              ;               6: binary, beginning in "&B"
              ;               7: binary, ending in "B"
              ;   R   = Number range
              ;               0: 0..65535 (unsigned integer)
              ;               1: -32768..32767 (complement-two integer)
              ;                  If specified format is binary,
              ;                  number is interpreted as 8-bit integer
              ;                  and range is 0..255. Thenm R bit
              ;                  and D register are ignored.
              ;   FF  = Ending type of string
              ;               0: Adding "$" character
              ;               1: Adding 00 character
              ;               2: Bit 7 of last character is set to 1
              ;               3: Without special ending
              ;   P   = Sign "+"
              ;               0: Don't add "+" sign to positive numbers
              ;               1: Add "+" sign to positive numbers
              ;   Z   = Left zeros
              ;               0: Remove left zeros
              ;               1: Don't remove left zeros
	;
              ;Out: String beginning in (HL)
              ;        B = Number of characters of string building number
              ;            including sign and type indicator, if there are
              ;        C = Numero of total characters of string
              ;            not including "$" or 00 if generated

NumToAsc:	push	de,hl
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
	ld	(ix+10),l	;Buffer inicial
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
	jr	division
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

	breakp

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

ChkBit7:	push	hl	;Guardamos pos. final del buffer
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
	pop	hl	;Recuperamos pos. final de buffer

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
	pop	hl,de
	ret

WorkArea:	defs	15
