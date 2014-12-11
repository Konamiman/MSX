; Base64 library for SDCC
; By Konamiman, 8/2010
;
; Assemble with:
; sdasz80 -o base64.asm

	.area	_CODE

;void Base64Init(byte charsPerLine)

_Base64Init::
	ld	hl,#2
	add	hl,sp
	ld	a,(hl)

;--- B64_INIT: Initialize the Base64 engine
;    Input:  A=Number of characters per line
;              (0=do not break encoded stream in lines)
;    Modifies: -

DO_B64_INIT:
	push	af
	push    hl
	or	a
	jr	z,B64_INIT2

	cp	a,#4
	jr	nc,B64_INIT1
	ld	a,#4
B64_INIT1:
	sra	a	;Converts to groups of 4
	sra	a
	and	#0b00111111

B64_INIT2:
	ld	(B64_CRINT),a
	ld	(B64_CRCNT),a
	xor	a
	ld	(B64_TEMPLON),a
	ld	(B64_DEC_FIN),a
	ld	hl,#B64_INTEMP
	ld	(B64_DEC_PNT),hl
	ld	hl,#0
	ld	(B64_TOTLEN),hl
	ld	(B64_TOTLEN+2),hl
	ld	(B64_INTEMP),hl
	ld	(B64_INTEMP+2),hl

	pop	hl
	pop	af
	ret


;uint Base64EncodeChunk(byte* source, byte* destination, uint length, byte final)

_Base64EncodeChunk::
	push	ix
	ld	ix,#4
	add	ix,sp
	ld	l,(ix)
	ld	h,1(ix)
	ld	e,2(ix)
	ld	d,3(ix)
	ld	c,4(ix)
	ld	b,5(ix)
	ld	a,6(ix)
	push	hl
	pop	ix
	push	de
	pop	iy
	rra
	call	_B64_ENCB
	ld	h,b
	ld	l,c
	pop	ix
	ret


;--- B64_ENCB: Encode a byte group in Base64.
;    Takes in account the previous encoding state,
;    therefore IX-1 and IX-2 must be available;
;    moreover, it stores the encoding state if not a final block.
;    Input:  IX = Source address
;            IY = Destination address
;            BC = Length
;            Cy = 1 if final block
;            (B64_CRINT) = Encoded line length
;            (B64_CRCNT) = Previous encoding state
;    Output: BC = Encoded result length
;            IX = IX+BC at input
;            IY = IY+BC at output
;            HL:DE = Accumulated encoded data length
;    Modifies: AF, BC, DE, HL, IX, IY

_B64_ENCB:
	ld	a,#0
	rla
	ld	(B64_IS_FINAL),a	;1 if final block, 0 if not
	push	iy

	;--- Previous state available?

	ld	a,(B64_TEMPLON)
	or	a
	jr	z,B64_ENCLOOP
	cp	#2
	jr	z,B64_ENC_PRV2

	;Previous state is 1 byte

	ld	a,(B64_INTEMP)
	ld	-1(ix),a
	dec	ix
	inc	bc
	jr	B64_ENCLOOP

	;Previous state is 2 byte

B64_ENC_PRV2:
	ld	a,(B64_INTEMP)
	ld	-2(ix),a
	ld	a,(B64_INTEMP+1)
	ld	-1(ix),a
	dec	ix
	dec	ix
	inc	bc
	inc	bc
	;jr      B64_ENCLOOP

B64_ENCLOOP:
	ld	a,b
	or	a
	jr	nz,B64ENC_NOFIN
	ld	a,c
	or	a
	jr	z,B64ENC_LAST0
	cp	#1
	jr	z,B64ENC_LAST1
	cp	#2
	jr	z,B64ENC_LAST2

	;--- Encodes normal block

B64ENC_NOFIN:
	exx
	call	B64_ENC3
	exx
	dec	bc
	dec	bc
	dec	bc

	;* Must insert CRLF?

	ld	a,(B64_CRCNT)
	or	a
	jr	z,B64_ENCLOOP

	dec	a
	ld	(B64_CRCNT),a
	jr	nz,B64_ENCLOOP

	ld	a,(B64_CRINT)
	ld	(B64_CRCNT),a
	ld	(iy),#13
	ld	1(iy),#10
	inc	iy
	inc	iy
	jr	B64_ENCLOOP

	;--- Last block, 1 byte

B64ENC_LAST1:	ld	a,(B64_IS_FINAL)
	or	a
	jr	z,B64ENC_L1_2

	;* It was final block

	call	B64_ENC1
	jr	B64_ENC_END

	;* No final block

B64ENC_L1_2:
	ld	a,(ix)
	ld	(B64_INTEMP),a
	ld	a,#1
	ld	(B64_TEMPLON),a
	inc	ix
	jr	B64_ENC_END

	;--- Last block, 2 bytes

B64ENC_LAST2:
	ld	a,(B64_IS_FINAL)
	or	a
	jr	z,B64_L2_2

	;* It was final block

	call	B64_ENC2
	jr	B64_ENC_END

	;* No final block

B64_L2_2:
	ld	a,(ix)
	ld	(B64_INTEMP),a
	ld	a,1(ix)
	ld	(B64_INTEMP+1),a
	ld	a,#2
	ld	(B64_TEMPLON),a
	inc	ix
	inc	ix
	jr	B64_ENC_END

	;--- No last block

B64ENC_LAST0:
	xor	a
	ld	(B64_TEMPLON),a

	;--- End: calculate resulting length
	;    as new IY - old IY

B64_ENC_END:
	pop	bc
	push	iy
	push	iy
	pop	hl
	or	a
	sbc	hl,bc
	push	hl
	pop	bc
	pop	iy

	call	B64_INCTLEN

	xor	a
	ret


;--- B64_ENC3: Encode 3 bytes in Base64
;    Input:  IX = Bytes address
;            IY = Destination address
;    Output: IX = IX+3
;            IY = IY+4
;    Modifies: AF, HL, BC

B64_ENC3:
	ld	a,(ix)
	sra	a
	sra	a
	and	#0b00111111
	call	GETB64CHAR
	ld	(iy),a

	ld	a,(ix)
	sla	a
	sla	a
	sla	a
	sla	a
	and	#0b00110000
	ld	b,a
	ld	a,1(ix)
	sra	a
	sra	a
	sra	a
	sra	a
	and	#0b00001111
	or	b
	call	GETB64CHAR
	ld	1(iy),a

	ld	a,1(ix)
	sla	a
	sla	a
	and	#0b00111100
	ld	b,a
	ld	a,2(ix)
	rlca
	rlca
	and	#0b00000011
	or	b
	call	GETB64CHAR
	ld	2(iy),a

	ld	a,2(ix)
	and	#0b00111111
	call	GETB64CHAR
	ld	3(iy),a

	inc	ix
B64_ENCEND2:
	inc	ix
B64_ENCEND1:
	inc	ix
	inc	iy
	inc	iy
	inc	iy
	inc	iy
	ret


;--- B64_ENC1: Encode a final 1-byte block in Base64
;    Input:   IX = Byte address
;             IY = Destination address
;    Output:  IX = IX+1
;             IY = IY+4
;    Modifies: AF, HL, BC

B64_ENC1:
	ld	a,(ix)
	sra	a
	sra	a
	and	#0b00111111
	call	GETB64CHAR
	ld	(iy),a

	ld	a,(ix)
	sla	a
	sla	a
	sla	a
	sla	a
	and	#0b00110000
	call	GETB64CHAR
	ld	1(iy),a

	ld	2(iy),#61	;"="
	ld	3(iy),#61	;"="
	jr	B64_ENCEND1


;--- B64_ENC2:  Encode a final s-byte block in Base64
;    Input:   IX = Byte address
;             IY = Destination address
;    Output:  IX = IX+2
;             IY = IY+4
;    Modifies: AF, HL, BC

B64_ENC2:
	ld	a,(ix)
	sra	a
	sra	a
	and	#0b00111111
	call	GETB64CHAR
	ld	(iy),a

	ld	a,(ix)
	sla	a
	sla	a
	sla	a
	sla	a
	and	#0b00110000
	ld	b,a
	ld	a,1(ix)
	sra	a
	sra	a
	sra	a
	sra	a
	and	#0b00001111
	or	b
	call	GETB64CHAR
	ld	1(iy),a

	ld	a,1(ix)
	sla	a
	sla	a
	and	#0b00111100
	call	GETB64CHAR
	ld	2(iy),a

	ld	3(iy),#61	;"="
	jr	B64_ENCEND2


;uint Base64DecodeChunk(byte* source, byte* destination, uint length, byte final, byte* error)

_Base64DecodeChunk::
	push	ix
	ld	ix,#4
	add	ix,sp
	ld	l,(ix)
	ld	h,1(ix)
	ld	e,2(ix)
	ld	d,3(ix)
	ld	c,4(ix)
	ld	b,5(ix)
	ld	a,6(ix)
	push	de
	pop	iy
	ld	e,7(ix)
	ld	d,8(ix)
	push	de
	push	hl
	pop	ix
	rra
	call	_B64_DECB
	pop	de
	jr	c,DECERR
	ld	a,#1
DECERR:	dec	a
	ld	(de),a
	ld	h,b
	ld	l,c
	pop	ix
	ret


;--- B64_DECB: Decode a Base64 characters group
;    Skips tabs, spaces and CRLF;
;    other invalid characters return error.
;    Takes in account the previous encoding state,
;    moreover, it stores the decoding state if not a final block.
;    Input:  IX = Source address
;            IY = Destination address
;            BC = Length
;            Cy = 1 if final block
;    Output: BC = Decoded result length
;            IX = IX+BC at input
;            IY = IY+BC at output
;            HL:DE = Accumulated decoded data length
;            Cy=1 if error
;                 A=2: Invalid length in non final block
;                   3: Invalid characteres found
;    Modifies: AF, BC, DE, HL, IX, IY

_B64_DECB:
	ld	a,#0
	rla
	ld	(B64_IS_FINAL),a	;1 if final, 0 if not
	ld	(B64_DEC_IY),iy

	;--- Main loop

B64_DECLOOP:
	;* If a full 4 characters group is available, decode it

	ld	a,(B64_TEMPLON)
	cp	#4
	jr	nz,B64_DECLOOP2

	exx
	call	B64_DEC4
	exx
	xor	a
	ld	(B64_TEMPLON),a
	ld	hl,#B64_INTEMP
	ld	(B64_DEC_PNT),hl

	ld	a,(B64_TEMPLON+2)
	cp	#0xFF
	jr	nz,B64_DECLOOP2
	ld	a,(B64_TEMPLON+3)
	cp	#0xFF
	jr	nz,B64_DECLOOP2
	ld	(B64_DEC_FIN),a
B64_DECLOOP2:	;

	;* If no input characters left, terminate

B64_DEC_NEXT:	ld	a,b
	or	c
	jr	z,B64_DEC_END

	;* Obtain a new character to decode

	ld	a,(ix)
	inc	ix
	dec	bc

	;* Ignorable character?

	cp	#9	;TAB
	jr	z,B64_DEC_NEXT
	cp	#32	;SPC
	jr	z,B64_DEC_NEXT
	cp	#13	;CR
	jr	z,B64_DEC_NEXT
	cp	#10	;LF
	jr	z,B64_DEC_NEXT

	;If a "=" character was poresent in the last decoded group,
	;only ignorable characters may remain; otherwise it is an error

	ld	h,a
	ld	a,(B64_DEC_FIN)
	or	a
	jr	nz,B64_DEC_ER3
	ld	a,h

	;* If "=" found, it is an error if:
	;  - Not the final block; or
	;  - Not at least 2 characters in B64_INTEMP

	cp	#61	;"="
	jr	nz,B64_DECLOOP3

	ld	a,(B64_TEMPLON)
	cp	#2
	jr	c,B64_DEC_ER3

	ld	a,#0xFF
	jr	B64_DECLOOP4

	;* Try to decode character, if success, store it

B64_DECLOOP3:
	exx
	call	GETB64INDEX
	exx
	jr	nz,B64_DEC_ER3
B64_DECLOOP4:
	ld	hl,(B64_DEC_PNT)
	ld	(hl),a
	inc	hl
	ld	(B64_DEC_PNT),hl
	ld	hl,#B64_TEMPLON
	inc	(hl)
	jr	B64_DECLOOP

	;--- End: if there are pendientes characters
	;    and block was not final, error

B64_DEC_END:
	ld	bc,(B64_DEC_IY)
	push	iy
	push	iy
	pop	hl
	or	a
	sbc	hl,bc
	push	hl
	pop	bc
	pop	iy

	call	B64_INCTLEN

	ld	a,(B64_IS_FINAL)
	or	a
	ret	z

	ld	a,(B64_TEMPLON)
	or	a
	ret	z

	ld	a,#2
	scf
	ret

	;--- Error 3

B64_DEC_ER3:
	ld	a,#3
	scf
	ret

B64_DEC_IY:	.dw	#0


;--- B64_DEC4: Decode a Base64 4 characters group
;    Input:  Characters in B64_INTEMP, unescaped
;            (characters are 0-63, or #0xFF for "=")
;            IY = Destination address
;    Output: IY = IY+1, 2 o 3
;    Modifies: AF, HL, BC

B64_DEC4:
	ld	hl,(B64_INTEMP)	;Read characters at L, H, E, D
	ld	de,(B64_INTEMP+2)

	ld	a,l
	sla	a
	sla	a
	and	#0b011111100
	ld	b,a
	ld	a,h
	sra	a
	sra	a
	sra	a
	sra	a
	and	#0b00000011
	or	b
	ld	(iy),a

	ld	a,e
	cp	#0xFF
	jr	z,B64_DEC4_END1

	ld	a,h
	sla	a
	sla	a
	sla	a
	sla	a
	and	#0b011110000
	ld	b,a
	ld	a,e
	sra	a
	sra	a
	and	#0b00001111
	or	b
	ld	1(iy),a

	ld	a,d
	cp	#0xFF
	jr	z,B64_DEC4_END2

	ld	a,e
	rrca
	rrca
	and	#0b11000000
	ld	b,a
	ld	a,d
	and	#0b00111111
	or	b
	ld	2(iy),a

	inc	iy
B64_DEC4_END2:
	inc	iy
B64_DEC4_END1:
	inc	iy
	ret


;--- GETB64CHAR: Obtain a Base64 character from its index
;    Input:  A = Index (0-63)
;    Output: A = Character
;    Modifies: AF, HL, BC

GETB64CHAR:
	ld	hl,#B64TABLE
	ld	c,a
	ld	b,#0
	add	hl,bc
	ld	a,(hl)
	ret


;--- GETB64INDEX: Obtain the index of a Base64 character
;    Input:  A = Caracter
;    Output: A = Index and Z=1 (A=#0xFF and Z=0 if character not found)
;    Modifies: AF, HL, BC

GETB64INDEX:
	ld	hl,#B64TABLE+#63
	ld	bc,#64
	cpdr
	ld	a,#0xFF
	ret	nz
	ld	a,c
	ret


;--- B64_INCTLEN: Increases B64_TOTLEN field by BC
;    Input:  BC = Length to add
;    Output: HL:DE = New value of B64_TOTLEN
;    Modifies: F, HL, DE

B64_INCTLEN:
	ld	hl,(B64_TOTLEN)
	add	hl,bc
	ld	(B64_TOTLEN),hl
	ex	de,hl
	ld	hl,(B64_TOTLEN+2)
	ret	nc
	inc	hl
	ld	(B64_TOTLEN+2),hl
	ret


;--- Variables

B64TABLE:
	.db	65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90  ;"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	.db	97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122 ;"abcdefghijklmnopqrstuvwxyz"
	.db	48,49,50,51,52,53,54,55,56,57,43,47	;"0123456789+/"
B64_CRINT:	.db	0	;Encoded line length, in groups of 4
				;(0 = do not insert line breaks)
B64_CRCNT:	.db	0	;Counter for inserting CRLF
B64_INTEMP:	.ds	4	;For temporary storage of an incomplete group
B64_TEMPLON:	.db	0	;Incomplete group length
B64_DEC_PNT:	.dw	0	;Pointer for filling B64_INTEMP when decoding
B64_TOTLEN:	.ds	4	;Total accumulated length of output blocks
B64_IS_FINAL:	.db	0
B64_DEC_FIN:	.db	0
