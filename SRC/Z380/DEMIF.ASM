;MIF graphics decompressor for LPE-Z380

;==========================

	;Segunda prueba (no tan chorra) de velocidad Z380:
	;DESCOMPRESOR DE MIF!!!

	;Version optimizada (o eso pretende)

TRAPFDIR:	equ	#23

alter:	macro
	ldctli	dsr,3
	endm
prim:	macro
	ldctli	dsr,2
	endm
init:	macro
	ldctli	sr,2
	endm

frame:	macro	@r,@n
	swap	@r
	ld	@r,@n
	swap	@r
	endm

	include	4	;Macros Z380

	;--- PUNTEROS de lectura / escritura

	org	#1000

	jp	START

D#1003:	dw	#0002,&H0001	;Lectura desde #00010000
D#1007:	dw	#0000,&H0002	;Escritura a   #00020000


;-----------------------------------------------------------------------------
;------------ LZW DECOMPRESSION UNIT -----------------------------------------
;-----------------------------------------------------------------------------

	;*** PRUEBA DE TRAPPING ***

START:	ddir	lw
	ld	(SAVESP),sp
	init
	jp	START!

	frame	ix,#4000
	ld	ix,0
	ld	hl,AKI	;Establece dir. de trapping
	ldmr	(ix+TRAPFDIR),hl

	db	#ED,#80	;No existe
	jp	3	;Si no funciona, no hara nada

AKI:	resc	lw
	pop	ix
	frame	ix,0
	ldrm	hl,(ix)
	frame	ix,#4000
	ld	ix,0
	ldmr	(ix+#28),hl

	;*** FIN PRUEBA TRAPPING ***

START!:	setc	lw
	;ld      sp,0
	ld	hl,0
	ld	de,0
	ld	bc,0
	ld	ix,0
	ld	iy,0

	alter
	ddir	ib
	ld	hl,2
	db	1
	ddir	ib
	ld	de,0
	db	2
	prim

	resc	lw

	call	START2

	setc	lw
	ld	sp,0
	ld	hl,0
	ld	de,0
	ld	bc,0
	ld	ix,0
	ld	iy,0
	resc	lw

	ddir	lw
	ld	sp,(SAVESP)
	ret

SAVESP:	ds	4

START2:	ld	hl,READ

SetIn:	ld	(ReadH + 1),hl	; Set the Data Input Routine
;              ret     ; Must be called before DECMP
	; hl is the input routine, and must
	; preserve bc, de and ix.
	; This routine must return a value in A

;-----------------------------------------------------------------------------

	ld	hl,WRITE

SetOut:	ld	(WriteH1 + 1),hl	; Set the Data Output Routine
	ld	(WriteH2 + 1),hl	; Must be called before DECMP
;              ret     ; hl is the output routine, and must
	; preserve bc and de.
	; The value to write is passed in A

;-----------------------------------------------------------------------------

Decmp:	ld	a,80h	; Decompress all datas till the end
	ld	(BitCount),a

Decmp1:	ld	a,2	; Initialize parameters at the begining
	ld	(BitSize),a	; of each block
	ld	hl,2
	ld	(BitSve),hl
	ld	hl,3
	ld	(BitNum),hl
	ld	ix,DecTab + 2

Decmp2:	ld	b,1	; Read 1 bit...
	call	RdBits	; If bit=0, it's a position...
	bit	0,e	; else a raw byte
	jr	z,Coded

	ld	b,8
	call	RdBits	; Read the raw byte
	call	AdjBits
	ld	(ix-2),e	; and add it to the output...
	ld	(ix+0),d
	ld	(ix+2),e
	ld	a,e
WriteH1:	call	0

	ld	de,3
	add	ix,de
	jr	Decmp2

Coded:	ld	a,(BitSize)
	ld	b,a
	call	RdBits
	call	AdjBits

	ld	a,(ix-5)	; It's a position, we must decode it...
	ld	(ix-2),a

	ld	hl,DecTab + 2
	add	hl,de
	add	hl,de
	add	hl,de

	defb	0DDh	; Comparison between ix and the read position
	ld	a,h	; Warning: Hidden Z80 codes to be faster.
	cp	h
	jr	nz,Diff1

	defb	0DDh
	ld	a,l
	cp	l
	jr	z,Decmp1	; Si position = ix, end of LZW bloc
Diff1:	ret	c	; Si position > ix, end of file

	ld	(ix+0),h	; we add the element in the decompression
	ld	(ix+2),l	; table, as a prefix

	ld	bc,-1
	ld	de,DecTab + 4095 * 3 + 2	; The decompression stack
	; is located after the
	; decompression table
PushLoop:	ld	a,(hl)
	or	a	; We push all the prefixes...
	inc	hl
	ldi
	ld	l,(hl)
	ld	h,a
	jr	nz,PushLoop
	ld	a,l
	ld	(ix-2),a

WriteH2:
PopLoop:	call	0	; and then, we pop'em to the output
	dec	de
	inc	bc
	ld	a,b
	or	c
	ld	a,(de)
	jr	nz,PopLoop

	ld	de,3
	add	ix,de
	jr	Decmp2

;-----------------------------------------------------------------------------

RdBits:	ld	de,0	; This routine reads b bits from the
	ld	a,(BitCount)	; entry (defined by SetIn)
	ld	c,a
	ld	a,(BitByte)
RdBit1:	rlc	c
ReadH:	call	c,0
RdBit2:	rla
	rlw	de	;rl            e
	;rl      d
	djnz	RdBit1
	ld	(BitByte),a
	ld	a,c
	ld	(BitCount),a
	ret

BitCount:	defb	80h
BitByte:	defb	0

;-----------------------------------------------------------------------------

AdjBits:	ld	hl,(BitNum)	; Adjust the size of the entry to read
	dec	hl	; in function of the number of entries
	ld	(BitNum),hl	; already read
	orw	hl	; ld      a,h
	;or      l
	ret	nz
	ld	hl,(BitSve)
	add	hl,hl
	ld	(BitSve),hl
	ld	(BitNum),hl
	ld	hl,BitSize
	inc	(hl)
	ret

BitSize:	defb	2
BitSve:	defw	2
BitNum:	defw	3

;-----------------------------------------------------------------------------
;------------ END OF THE LZW DECOMPRESSION UNIT ------------------------------
;-----------------------------------------------------------------------------


READ:	setc	lw
	alter
	ld	a,(hl)
	inc	hl
	prim
	resc	lw
	ret

;READ:         setc    lw
;              ld      hl,(#1003)
;              ld      a,(hl)
;              inc     hl
;              orw     hl
;              jr      nz,NOSW
;SW:           swap    hl
;              inc     hl
;              swap    hl
;NOSW:         ld      (#1003),hl
;              ld      hl,0
;              resc    lw
;              ret


WRITE:	setc	lw
	alter
	ld	(de),a
	inc	de
	prim
	resc	lw
	ret

;WRITE:        setc    lw
;              ld      hl,(#1007)
;              ld      (hl),a
;              inc     hl
;              orw     hl
;              jr      nz,NOSW2
;SW2:          swap    hl
;              inc     hl
;              swap    hl
;NOSW2:        ld      (#1007),hl
;              ld      hl,0
;              resc    lw
;              ret


DecTab:	;equ     #4000

