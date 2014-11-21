;A routine that reads a given number of bits (not bytes!),
;up to 16, from a file.

;=================================

;--- GET_BITS
;    Esta subrutina extrae un cierto numero de bits del fichero (hasta 16).
;    Llama a la rutina GET_BYTE para leer un byte nuevo del fichero.
;    Entrada: A  = Numero de bits
;    Salida:  BC = Bits extraidos

GET_BITS:	ld	hl,0	;HL = Bits extraidos
	or	a	;0 bits a extraer? No hace nada
	ret	z
	ld	b,a	;B = Numero de bits a extraer

	;--- Si BIT_CNT es 0, hay que extraer un byte nuevo

GETBITS_LOOP:	push	hl,bc

	ld	a,(BIT_CNT)
	or	a
	jr	nz,GET_BITS2

	call	GET_BYTE
	jp	c,ERR_FILE
	ld	(LAST_BYTE),a
	ld	a,8
	ld	(BIT_CNT),a

	;Extrae un bit y actualiza variables

GET_BITS2:	pop	bc,hl
	ld	a,(LAST_BYTE)
	sla	a	;Proximo bit a Cy
	rl	l	;Bit de Cy a L rotando
	rl	h	;Antiguo bit 7 de L a bit 0 de H

	ld	(LAST_BYTE),a
	ld	a,(BIT_CNT)
	dec	a
	ld	(BIT_CNT),a
	djnz	GETBITS_LOOP

	ret

LAST_BYTE:	db	0	;Ultimo byte extraido del fichero
BIT_CNT:	db	8	;Contador de bits que quedan por extraer del byte
