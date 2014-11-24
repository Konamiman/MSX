;***************************************
;***                                 ***
;***  MD5 AND SHA1 HASHING ROUTINES  ***
;***                                 ***
;***************************************

	;Routines have entry points HASH_MD5 and HASH_SHA1.
	;Both have the same input and output parameters.
    ;
	;Usage:
    ;
	;To hash a short message in one single step, call the routine with these parameters:
	;        A  = 3
	;        HL = Address of message to digest
	;        BC = Length of message in bytes
	;        DE = Address for the generated 16-byte hash
	;
	;To hash a message in chunks (because it does not fit in the available memory,
	;or because you don't have the whole message available in advance):
	;
	;1. Call the routine with A=0 to initialize the hashing procedure.
	;2. For each message chunk call the routine with these parameters:
	;   A  = 1
	;   HL = Address of the chunk
	;   BC = Length of the chunk (may be anything, even zero)
	;3. After all the chunks are processed, retrieve the hash by calling
	;   the routine with these parameters:
	;   A  = 2
	;   DE = Address for the generated MD5 16-byte or SHA1 20-byte hash

	;--- Macros for 32 bit addition

m_add32:	macro	@a,@b	;Performs (@a) = (@a) + (@b)
	ld	hl,(@a)
	ld	bc,(@b)
	add	hl,bc
	ld	(@a),hl
	ld	hl,(@a+2)
	ld	bc,(@b+2)
	adc	hl,bc
	ld	(@a+2),hl
	endm

m_add32_ix:	macro	@a	;Performs (@a) = (@a) + (IX+0..3)
	ld	hl,(@a)
	ld	c,(ix)
	ld	b,(ix+1)
	add	hl,bc
	ld	(@a),hl
	ld	hl,(@a+2)
	ld	c,(ix+2)
	ld	b,(ix+3)
	adc	hl,bc
	ld	(@a+2),hl
	endm

	;--- Macro for leftrotate a little-endian 32 bit word pointed by IX

m_lrotate_ix:	macro	@times
	ld	b,@times
rllp@SYM:
	sla	(ix+0)
	rl	(ix+1)
	rl	(ix+2)
	rl	(ix+3)
	jr	nc,rlbot@SYM
	set	0,(ix+0)
rlbot@SYM:
	djnz	rllp@SYM
	endm

	;--- Macro for leftrotate a little-endian 32 bit word, where IX points after the last byte

m_lrotate_ix_rev:	macro
rllpr@SYM:
	sla	(ix-4)
	rl	(ix-3)
	rl	(ix-2)
	rl	(ix-1)
	jr	nc,rlbotr@SYM
	set	0,(ix-4)
rlbotr@SYM:
	endm

	;--- Macro for 32 bit copy using HL

m_copy32:	macro	@dst,@src
	ld	hl,(@src)
	ld	(@dst),hl
	ld	hl,(@src+2)
	ld	(@dst+2),hl
	endm


	;----------------------
	;---  MAIN PROGRAM  ---
	;----------------------

	;--- MD5

HASH_MD5:
	ld	ix,MD5_STATE
	ld	iy,MD5_BLOCK

	or	a
	jr	z,MD5_INIT
	
	dec	a
	jp	z,MD5_CONT

	dec	a
	jr	z,MD5_FINALIZE

	jp	MD5_ONESTEP


	;--- SHA1

HASH_SHA1:	
	ld	ix,SHA1_STATE
	ld	iy,SHA1_BLOCK

	or	a
	jr	z,SHA1_INIT

	dec	a
	jp	z,MD5_CONT

	dec	a
	jr	z,SHA1_FINALIZE

	jp	SHA1_ONESTEP


	;--- Initialize
	;    Input: IX = Pointer to state variables

MD5_INIT:
	ld	hl,INIT_ABCD
	ld	de,BUF_A
	ld	bc,16
	ldir
	jr	INIT_NEXT

SHA1_INIT:
	ld	hl,INIT_H_SHA
	ld	de,BUF_H0_SHA
	ld	bc,20
	ldir

INIT_NEXT:
	ld	(ix),0		;TOTAL_LEN
	ld	(ix+1),0
	ld	(ix+2),0
	ld	(ix+3),0

	ld	(ix+8),0	;CUR_BLOCK_LEN

	push	ix
	pop	hl
	ld	bc,11
	add	hl,bc
	ld	(ix+9),l	;CUR_BLOCK_PNT
	ld	(ix+10),h

	ret


	;--- Finalize
	;    Input: IX = Pointer to state variables
	;           IY = Pointer to block hash routine
	;           DE = Destination for the hash
	;           Cy = 0 for MD5, 1 for SHA1

MD5_FINALIZE:
	or	a
	jr	FINALIZE

SHA1_FINALIZE:
	scf

FINALIZE:
	push	de
	push	af

	;* Calculate how much padding must be added

	ld	a,(ix)	;TOTAL_LEN
	and	3Fh
	sub	56
	neg
	and	3Fh	
	or	a
	jr	nz,OKPAD
	ld	a,64
OKPAD:	;Now A=Number of padding bytes to add

	;* Hash the padding, then the total message length

	ld	c,a
	ld	b,0
	ld	hl,ZERO_PAD
	call	MD5_CONT2

	ld	b,3
ROTATE:	;Convert length in bytes to length in bits
	sla	(ix)
	rl	(ix+1)
	rl	(ix+2)
	rl	(ix+3)
	djnz	ROTATE

	push	ix
	pop	hl	;TOTAL_LEN
	pop	af
	push	af
	jr	nc,OK_LEN_BIG

	;If SHA1 is used, convert length to big endian

	ld	d,(ix)
	ld	e,(ix+1)
	ld	(ix+7),d
	ld	(ix+6),e
	ld	d,(ix+2)
	ld	e,(ix+3)
	ld	(ix+5),d
	ld	(ix+4),e
	ld	(ix),0
	ld	(ix+1),0
	ld	(ix+2),0
	ld	(ix+3),0
OK_LEN_BIG:
	ld	bc,8
	call	MD5_CONT2

	;* Copy the final hash to its destination

	pop	af
	jr	c,COPY_END_SHA1

COPY_END_MD5:
	pop	de
	ld	bc,16
	ld	hl,BUF_A
	ldir
	ret

COPY_END_SHA1:
	
	;SHA1 hash = h0 append h1 append h2 append h3 append h4 (big endian)

	ld	b,5
	pop	iy
	ld	ix,BUF_H0_SHA
COPY_END_SHA1_L:
	ld	a,(ix)
	ld	(iy+3),a
	ld	a,(ix+1)
	ld	(iy+2),a
	ld	a,(ix+2)
	ld	(iy+1),a
	ld	a,(ix+3)
	ld	(iy),a
	inc	ix
	inc	ix
	inc	ix
	inc	ix
	inc	iy
	inc	iy
	inc	iy
	inc	iy

	djnz	COPY_END_SHA1_L
	ret


	;--- Continue
	;    Input: IX = Pointer to state variables
	;           IY = Pointer to block hash routine
	;           HL = Block address
	;           BC = Block length

MD5_CONT:
	;* Update accumulated length

	push	hl
	ld	l,(ix)
	ld	h,(ix+1)
	add	hl,bc
	ld	(ix),l
	ld	(ix+1),h
	ld	l,(ix+2)
	ld	h,(ix+3)
	ld	de,0
	adc	hl,de
	ld	(ix+2),l
	ld	(ix+3),h
	pop	hl

MD5_CONT2:
	ld	(CHUNK_PNT),hl
	ld	(CHUNK_LEN),bc

	;* If buffered block length plus next block length
	;  is less than 64, then simply copy new data to current block buffer...

MD5_CONT_LOOP:
	ld	bc,(CHUNK_LEN)

	ld	a,b	;No more data left if current message length = 0
	or	c
	ret	z

	ld	l,(ix+8)	;CUR_BLOCK_LEN
	ld	h,0
	add	hl,bc
	ld	de,64
	call	COMP16
	jr	nc,MD5_CONT_DO

	ld	(ix+8),l	;CUR_BLOCK_LEN
	ld	hl,(CHUNK_PNT)
	ld	e,(ix+9)	;CUR_BLOCK_PNT
	ld	d,(ix+10)
	ldir
	ld	(ix+9),e
	ld	(ix+10),d
	ret

	;* ...otherwise hash a whole block and repeat

MD5_CONT_DO:
	ld	hl,64
	ld	e,(ix+8)	;CUR_BLOCK_LEN
	ld	d,0
	or	a
	sbc	hl,de	
	push	hl
	push	hl
	pop	bc	;Now BC = Space remaining in block buffer

	ld	hl,(CHUNK_PNT)
	ld	e,(ix+9)	;CUR_BLOCK_PNT
	ld	d,(ix+10)
	ldir		;Fill the buffer
	push	hl

	push	ix
	push	iy
	ld	hl,MD5_CONT_NEXT
	push	hl
	jp	(iy)		;Processes current 64-bit block
MD5_CONT_NEXT:
	pop	iy
	pop	ix

	pop	hl
	ld	(CHUNK_PNT),hl

	pop	de
	ld	hl,(CHUNK_LEN)
	or	a
	sbc	hl,de
	ld	(CHUNK_LEN),hl

	ld	(ix+8),0	;CUR_BLOCK_LEN
	push	ix
	pop	hl
	ld	bc,11
	add	hl,bc
	ld	(ix+9),l	;Initialize CUR_BLOCK_PNT
	ld	(ix+10),h

	jr	MD5_CONT_LOOP


	;--- Single-step processing
	;    Input: IX = Pointer to state variables
	;           IY = Pointer to block hash routine
	;           HL = Block address
	;           BC = Block length
	;           DE = Destination for the hash

MD5_ONESTEP:
	push	de
	push	hl
	push	bc

	call	MD5_INIT
	or	a
	jr	ONESTEP

SHA1_ONESTEP:
	push	de
	push	hl
	push	bc

	call	SHA1_INIT
	scf

ONESTEP:
	pop	bc
	pop	hl
	push	af
	call	MD5_CONT
	pop	af

	pop	de
	call	FINALIZE
	ret


	;------------------------------
	;---  CODE SPECIFIC FOR MD5 ---
	;------------------------------

	;--- Process a 64-bit block of data.
	;    Block is at CUR_BLOCK. in the MD5 state area.

MD5_BLOCK:

	;* Backup A,B,C,D

	ld	hl,BUF_A	;Sets buffers AA,BB,CC,DD
	ld	de,BUF_AA
	ld	bc,16
	ldir

	;* Rounds execution

	ld	hl,R_DATA
	ld	(ROUND_PNT),hl
	ld	a,1
	ld	(ROUND_N),a
	ld	(PAR_I),a

	call	ROUND
	call	ROUND
	call	ROUND
	call	ROUND

	;* Adds AA to A, BB to B, CC to C, DD to D

	m_add32	BUF_A,BUF_AA
	m_add32	BUF_B,BUF_BB
	m_add32	BUF_C,BUF_CC
	m_add32	BUF_D,BUF_DD

	ret


	;--- Sets parameters for round execution and executes round;
	;    after each operation exchanges A,B,C,D, and after
	;    the entire round increases ROUND_N

ROUND:	ld	b,16	;There are 16 operations per round

DO_RLOOP:
	push	bc
	ld	hl,(ROUND_PNT)
	ld	a,(hl)
	ld	(PAR_K),a	;Sets parameters and executes operation
	inc	hl
	ld	a,(hl)
	ld	(PAR_S),a
	inc	hl
	ld	(ROUND_PNT),hl
	call	ROUND_OP
	call	SH_ABCD	;After each operation A,B,C,D are shifted
	ld	hl,PAR_I	;and PAR_I is increased
	inc	(hl)
	pop	bc
	djnz	DO_RLOOP

	ld	hl,ROUND_N	;After the 16 operations, round number
	inc	(hl)	;is increased
	ret

	;--- SH_ABCD: Transforms ABCD into DABC, DABC into CDAB, CDAB into BCDA,
	;             or BCDA into ABCD

SH_ABCD:
	ld	hl,BUF_D+3	;D->temp
	ld	de,RES_FGHI+3
	ld	bc,4
	lddr

	ld	de,BUF_D+3
	ld	c,12	;C->D, B->C, A->B
	lddr

	ld	hl,RES_FGHI+3
	ld	c,4	;temp->A
	lddr

	ret

	;--- Function for ROUND operation execution
	;    Executes  A = B + ((A + F/G/H/I(B,C,D) + X[k] + T[i]) <<< s)
	;              where F,G,H,I is choosen when ROUND_N is 1,2,3,4 respectively
	;    Input:  PAR_K, PAR_S and PAR_I appropriately set
	;            ABCD buffer approriately rotated so it is ABCD,DABC,CDAB or BCDA
	;            ROUND_N set to 1,2,3 or 4
	;    Output: BUF_A with the result of the operation

ROUND_OP:
	ld	a,(ROUND_N)	;Calls function F,G,H or I
	ld	hl,FUN_F	;depending on the round number
	dec	a
	jr	z,OKR1
	ld	hl,FUN_G
	dec	a
	jr	z,OKR1
	ld	hl,FUN_H
	dec	a
	jr	z,OKR1
	ld	hl,FUN_I
OKR1:	call	CALL_HL

	m_add32	BUF_A,RES_FGHI	;Adds A to the result of F/G/H/I
	;                        ;and stores result on A

	ld	a,(PAR_K)	;Adds X[k] to the previous result
	ld	ix,MD5_CUR_BLOCK	;MD5_STATE+11	;and stores it to A again.
	call	ADD_XT	;Note that actually no X buffer is used.

	ld	a,(PAR_I)	;Adds T[i] to the previous result
	dec	a	;ans stores it to A again
	ld	ix,BUF_T
	call	ADD_XT

	ld	ix,BUF_A	;Shifts s bits A
	ld	a,(PAR_S)
	ld	b,a
	call	SHIFT

	m_add32	BUF_A,BUF_B	;Finally, adds B to A

	ret

ADD_XT:	ld	c,a	;Routine for adding X[k] or T[i] to A
	ld	b,0	;Input: IX=CUR_BLOCK and A=(PAR_K)
	add	ix,bc	;or IX=BUF_T and A=(PAR_I)-1
	add	ix,bc
	add	ix,bc
	add	ix,bc
	ld	l,(ix+0)
	ld	h,(ix+1)
	ld	de,(BUF_A)
	add	hl,de
	ld	(BUF_A),hl
	ld	l,(ix+2)
	ld	h,(ix+3)
	ld	de,(BUF_A+2)
	adc	hl,de
	ld	(BUF_A+2),hl
	ret

	;--- Circular left shifting of a 32 bit word (stored low byte first)
	;    Input: IX = Pointer to the word, B = Positions to shift

SHIFT:	sla	(ix+0)
	rl	(ix+1)
	rl	(ix+2)
	rl	(ix+3)
	jr	nc,SHIFT2
	set	0,(ix+0)
SHIFT2:	djnz	SHIFT
	ret

	;--- Function F

nXaZ:	macro	@n	;Calculates "not(X) and Z"
	ld	a,(ix+@n)	;for the byte @n (0 to 3)
	cpl		;                ;of the 32-bit word
	and	(ix+8+@n)
	ld	(iy+@n),a
	endm

XaYo:	macro	@n	;Calculates "X and Y or nXaZ"
	ld	a,(ix+@n)
	and	(ix+4+@n)
	or	(iy+@n)
	ld	(iy+@n),a
	endm

FUN_F:	call	FUN_SETP

	nXaZ	0
	nXaZ	1
	nXaZ	2
	nXaZ	3

	XaYo	0
	XaYo	1
	XaYo	2
	XaYo	3

	ret

	;--- Function G

nZaY:	macro	@n	;Calculates "not(Z) and Y"
	ld	a,(ix+8+@n)
	cpl
	and	(ix+4+@n)
	ld	(iy+@n),a
	endm

XaZo:	macro	@n	;Calculates "X and Z or nZaY"
	ld	a,(ix+@n)
	and	(ix+8+@n)
	or	(iy+@n)
	ld	(iy+@n),a
	endm

FUN_G:	call	FUN_SETP

	nZaY	0
	nZaY	1
	nZaY	2
	nZaY	3

	XaZo	0
	XaZo	1
	XaZo	2
	XaZo	3

	ret

	;--- Function H

XxYxZ:	macro	@n	;Calculates "X xor Y xor Z"
	ld	a,(ix+@n)
	xor	(ix+4+@n)
	xor	(ix+8+@n)
	ld	(iy+@n),a
	endm

FUN_H:	call	FUN_SETP

	XxYxZ	0
	XxYxZ	1
	XxYxZ	2
	XxYxZ	3

	ret

	;--- Function I

XonZ:	macro	@n	;Calculates "X or (not Z)"
	ld	a,(ix+8+@n)
	cpl
	or	(ix+@n)
	ld	(iy+@n),a
	endm

Yx:	macro	@n	;Calculates "Y xor XonZ"
	ld	a,(ix+4+@n)
	xor	(iy+@n)
	ld	(iy+@n),a
	endm

FUN_I:	call	FUN_SETP

	XonZ	0
	XonZ	1
	XonZ	2
	XonZ	3

	Yx	0
	Yx	1
	Yx	2
	Yx	3

	ret

	;--- Initial pointer setting for functions

FUN_SETP:	ld	ix,PAR_X
	ld	iy,RES_FGHI
	ret

	;--- 16 bit comparison
	;    Returns Cy=1 if HL<DE, Z=1 if HL=DE

COMP16:
	ld	a,h
	cp	d
	ret	nz
	ld	a,l
	cp	e
	ret


	;--------------------------
	;---  DATA AREA FOR MD5 ---
	;--------------------------

	;*** Do not modify the buffers order in memory ***

	;--- Data for round execution
	;    Parameter I is omitted, since it is always the one for the
	;    previous operation plus one

R_DATA:
	;* ROUND 1

	defb	0,7
	defb	1,12
	defb	2,17
	defb	3,22
	defb	4,7
	defb	5,12
	defb	6,17
	defb	7,22
	defb	8,7
	defb	9,12
	defb	10,17
	defb	11,22
	defb	12,7
	defb	13,12
	defb	14,17
	defb	15,22

	;* ROUND 2

	defb	1,5
	defb	6,9
	defb	11,14
	defb	0,20
	defb	5,5
	defb	10,9
	defb	15,14
	defb	4,20
	defb	9,5
	defb	14,9
	defb	3,14
	defb	8,20
	defb	13,5
	defb	2,9
	defb	7,14
	defb	12,20

	;* ROUND 3

	defb	5,4
	defb	8,11
	defb	11,16
	defb	14,23
	defb	1,4
	defb	4,11
	defb	7,16
	defb	10,23
	defb	13,4
	defb	0,11
	defb	3,16
	defb	6,23
	defb	9,4
	defb	12,11
	defb	15,16
	defb	2,23

	;* ROUND 4

	defb	0,6
	defb	7,10
	defb	14,15
	defb	5,21
	defb	12,6
	defb	3,10
	defb	10,15
	defb	1,21
	defb	8,6
	defb	15,10
	defb	6,15
	defb	13,21
	defb	4,6
	defb	11,10
	defb	2,15
	defb	9,21

	;--- Result of F/G/H/I functions

RES_FGHI:
	defs	4

	;---- Buffers for A,B,C,D,AA,BB,CC,DD and parameters

BUF_A:	defs	4
BUF_B:	defs	4
BUF_C:	defs	4
BUF_D:	defs	4
BUF_AA:	defs	4
BUF_BB:	defs	4
BUF_CC:	defs	4
BUF_DD:	defs	4

	;--- Buffers for parameters X,Y,Z to use on functions F,G,H,I
	;    (must be consecutive in memory)
	;    Since these functions are always called with (X,Y,Z)=(B,C,D),
	;    actually no buffers are defined but B,C,D buffers are directly referred

PAR_X:	equ	BUF_B
PAR_Y:	equ	BUF_C
PAR_Z:	equ	BUF_D

	;--- Initial values for BUF_A/B/C/D

INIT_ABCD:
	defb	1h,23h,45h,67h
	defb	89h,0ABh,0CDh,0EFh
	defb	0FEh,0DCh,0BAh,98h
	defb	76h,54h,32h,10h

	;--- Parameters k,s,i for round steps

PAR_K:		defb	0
PAR_S:		defb	0
PAR_I:		defb	0

	;--- Sinus table for function T

BUF_T:	defw	0A478h,0D76Ah,0B756h,0E8C7h,070DBh,02420h,0CEEEh,0C1BDh
	defw	0FAFh,0F57Ch,0C62Ah,04787h,04613h,0A830h,09501h,0FD46h
	defw	098D8h,06980h,0F7AFh,08B44h,05BB1h,0FFFFh,0D7BEh,0895Ch
	defw	01122h,06B90h,07193h,0FD98h,0438Eh,0A679h,0821h,049B4h
	defw	02562h,0F61Eh,0B340h,0C040h,05A51h,0265Eh,0C7AAh,0E9B6h
	defw	0105Dh,0D62Fh,01453h,0244h,0E681h,0D8A1h,0FBC8h,0E7D3h
	defw	0CDE6h,021E1h,07D6h,0C337h,0D87h,0F4D5h,014EDh,0455Ah
	defw	0E905h,0A9E3h,0A3F8h,0FCEFh,02D9h,0676Fh,04C8Ah,08D2Ah
	defw	03942h,0FFFAh,0F681h,08771h,06122h,06D9Dh,0380Ch,0FDE5h
	defw	0EA44h,0A4BEh,0CFA9h,04BDEh,04B60h,0F6BBh,0BC70h,0BEBFh
	defw	07EC6h,0289Bh,027FAh,0EAA1h,03085h,0D4EFh,01D05h,0488h
	defw	0D039h,0D9D4h,099E5h,0E6DBh,07CF8h,01FA2h,05665h,0C4ACh
	defw	02244h,0F429h,0FF97h,0432Ah,023A7h,0AB94h,0A039h,0FC93h
	defw	059C3h,0655Bh,0CC92h,08F0Ch,0F47Dh,0FFEFh,05DD1h,08584h
	defw	07E4Fh,06FA8h,0E6E0h,0FE2Ch,04314h,0A301h,011A1h,04E08h
	defw	07E82h,0F753h,0F235h,0BD3Ah,0D2BBh,02AD7h,0D391h,0EB86h

	;Note: the sinus table has been generated
	;with the following MSX-BASIC program:

	;1   'Sinus table generator for MD5 algorithm
	;2   'By Nestor Soriano, 27-5-2001
	;10  OPEN"md5sin.asm" FOR OUTPUT AS#1
	;20  PRINT"Generating file..."
	;30  FOR I1=0 TO 15
	;40    PRINT#1,"   defw ";
	;50    FOR I2=0 TO 3
	;60      S=INT((ABS(SIN(I1*4+I2+1)))*2^32)
	;70      SH=INT(S/65536!)
	;80      SL=S-SH*65536!
	;90      PRINT#1,"0";HEX$(SL);"h,0";HEX$(SH);"h";
	;100     IF I2<3 THEN PRINT#1,",";
	;110   NEXT I2:PRINT#1,""
	;120 NEXT I1
	;130 CLOSE#1
	;140 PRINT"Done. Resulting file:"
	;150 COPY"md5sin.asm"TO"con"

	;--- State variables (same structure for MD5 and SHA1):
	;    +0: Accumulated total message length in bytes (8 bytes)
	;    +8: Number of bytes buffered in the current 64-bit block buffer (1 byte)
	;    +9: Pointer to continue filling the current 64-bit block buffer (2 bytes)
	;    +11: Current 64-bit block buffer (64 bytes)

MD5_STATE:	defs	11+64
MD5_CUR_BLOCK:	equ	MD5_STATE+11


	;--------------------------------
	;---  CODE SPECIFIC FOR SHA1  ---
	;--------------------------------

	;--- Process a 64-bit block of data.
	;    Block is at CUR_BLOCK in the SHA1 state area.

SHA1_BLOCK:

	;* Convert the sixteen 4-byte words of the block to little endian

	ld	ix,SHA1_CUR_BLOCK
	ld	b,16
SHA1_CHGENDIAN:
	ld	d,(ix)
	ld	e,(ix+1)
	ld	h,(ix+2)
	ld	l,(ix+3)
	ld	(ix),l
	ld	(ix+1),h
	ld	(ix+2),e
	ld	(ix+3),d
	inc	ix
	inc	ix
	inc	ix
	inc	ix
	djnz	SHA1_CHGENDIAN
 
	;* Extend the sixteen 32-bit words into eighty 32-bit words:
	;     for i from 16 to 79
        ;         w[i] = (w[i-3] xor w[i-8] xor w[i-14] xor w[i-16]) leftrotate 1

	ld	ix,SHA1_CUR_BLOCK+16*4

	ld	c,64	;64 words
SHA1_EXT_LOOP1:

	ld	b,4	;4 bytes per word
SHA1_EXT_LOOP2:
	ld	a,(ix-3*4)
	xor	(ix-8*4)
	xor	(ix-14*4)
	xor	(ix-16*4)
	ld	(ix),a
	inc	ix
	djnz	SHA1_EXT_LOOP2

	m_lrotate_ix_rev

	dec	c
	jr	nz,SHA1_EXT_LOOP1

	;* Initialize hash value for this chunk:
	;  a = h0
	;  b = h1
	;  c = h2
	;  d = h3
	;  e = h4

	ld	hl,BUF_H0_SHA
	ld	de,BUF_A_SHA
	ld	bc,5*4
	ldir

	;* Perform main loop

	ld	hl,SHA1_CUR_BLOCK
	ld	(W_PNT_SHA),hl
	xor	a
SHA1_MAIN_LOOP:
	push	af
	call	SHA1_MAIN_STEP
	ld	hl,(W_PNT_SHA)
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	(W_PNT_SHA),hl
	pop	af
	inc	a
	cp	80
	jr	c,SHA1_MAIN_LOOP
	
	;* Add this chunk's hash to result so far:
	;    h0 = h0 + a
	;    h1 = h1 + b 
	;    h2 = h2 + c
	;    h3 = h3 + d
	;    h4 = h4 + e

	m_add32	BUF_H0_SHA,BUF_A_SHA
	m_add32	BUF_H1_SHA,BUF_B_SHA
	m_add32	BUF_H2_SHA,BUF_C_SHA
	m_add32	BUF_H3_SHA,BUF_D_SHA
	m_add32	BUF_H4_SHA,BUF_E_SHA

	ret


	;--- Step for SHA1 main loop
	;    Input: A = step number

SHA1_MAIN_STEP:
	ld	hl,SHA1_FUNC_0_19
	ld	ix,K_SHA
	cp	20
	jr	c,SHA1_STEP_DO

	ld	hl,SHA1_FUNC_20_39
	ld	ix,K_SHA+4
	cp	40
	jr	c,SHA1_STEP_DO

	ld	hl,SHA1_FUNC_40_59
	ld	ix,K_SHA+4*2
	cp	60
	jr	c,SHA1_STEP_DO

	ld	hl,SHA1_FUNC_60_79
	ld	ix,K_SHA+4*3

SHA1_STEP_DO:
	;Now HL points to the function to calculate F, and IX points to K

	push	ix

	ld	ix,BUF_A_SHA
	ld	b,4
	call	CALL_HL	;Calculate F

	;* temp = (a leftrotate 5) + f + e + k + w[i]

	m_copy32	BUF_TEMP_SHA,BUF_A_SHA

	ld	ix,BUF_TEMP_SHA
	m_lrotate_ix	5
	
	m_add32	BUF_TEMP_SHA,BUF_F_SHA
	m_add32	BUF_TEMP_SHA,BUF_E_SHA
	pop	ix
	m_add32_ix	BUF_TEMP_SHA	;Add k
	ld	ix,(W_PNT_SHA)
	m_add32_ix	BUF_TEMP_SHA	;Add w[i]

	;* e = d
        ;* d = c
        ;* c = b leftrotate 30
        ;* b = a
        ;* a = temp

	m_copy32	BUF_E_SHA,BUF_D_SHA
	m_copy32	BUF_D_SHA,BUF_C_SHA
	m_copy32	BUF_C_SHA,BUF_B_SHA
	ld	ix,BUF_C_SHA
	m_lrotate_ix	30
	m_copy32	BUF_B_SHA,BUF_A_SHA
	m_copy32	BUF_A_SHA,BUF_TEMP_SHA

	ret


	;--- Routines for calculating F
	;    They are called with IX=BUF_A_SHA, B=4
	;    They take profit of the fact that A,B,C,D,E,F
	;    are located consecutively in memory

	;* f = d xor (b and (c xor d))

SHA1_FUNC_0_19:
	ld	a,(ix+12)	;d
	ld	d,a
	xor	(ix+8)		;c
	and	(ix+4)		;b
	xor	d		;original d

	ld	(ix+20),a	;f
	inc	ix
	djnz	SHA1_FUNC_0_19
	ret


	;* f = b xor c xor d

SHA1_FUNC_20_39:
SHA1_FUNC_60_79:
	ld	a,(ix+12)	;d
	xor	(ix+8)		;c
	xor	(ix+4)		;b

	ld	(ix+20),a	;f
	inc	ix
	djnz	SHA1_FUNC_20_39
	ret


	;* f = (b and c) or (b and d) or (c and d) 

SHA1_FUNC_40_59:
	ld	d,(ix+12)	;d
	ld	c,(ix+8)	;c
	ld	e,(ix+4)	;b

	ld	a,c
	and	d
	ld	h,a	;h = (c and d)

	ld	a,e
	and	d
	or	h
	ld	h,a	;h = h or (b and d)

	ld	a,e
	and	c
	or	h	;a = h or (b and c)
	
	ld	(ix+20),a	;f
	inc	ix
	djnz	SHA1_FUNC_40_59
	ret


	;----------------------------
	;---  DATA AREA FOR SHA1  ---
	;----------------------------

	;--- Initial values for H0-H4

INIT_H_SHA:
	defb	01h,23h,45h,67h
	defb	89h,0ABh,0CDh,0EFh
	defb	0FEh,0DCh,0BAh,98h
	defb	76h,54h,32h,10h
	defb	0F0h,0E1h,0D2h,0C3h

	;--- Values for K

K_SHA:
	defb	99h,79h,82h,5Ah		;Rounds 0-19
    defb	0A1H,0EBh,0D9h,6Eh	;Rounds 20-39
    defb	0DCh,0BCh,1Bh,8Fh	;Rounds 40-59
	defb	0D6h,0C1h,62h,0CAh	;Rounds 60-79

	;--- Buffers for H0-H4, A-K

BUF_A_SHA:	defs	4
BUF_B_SHA:	defs	4
BUF_C_SHA:	defs	4
BUF_D_SHA:	defs	4
BUF_E_SHA:	defs	4
BUF_F_SHA:	defs	4
BUF_TEMP_SHA:	defs	4
BUF_H0_SHA:	defs	4
BUF_H1_SHA:	defs	4
BUF_H2_SHA:	defs	4
BUF_H3_SHA:	defs	4
BUF_H4_SHA:	defs	4

W_PNT_SHA:	defw	0	;Pointer to w[i] for main loop


	;--- State variables (same structure for MD5 and SHA1):
	;    +0: TOTAL_LEN, Accumulated total message length in bytes (8 bytes)
	;    +8: CUR_BLOCK_LEN, Number of bytes buffered in the current 64-bit block buffer (1 byte)
	;    +9: CUR_BLOCK_PNT, Pointer to continue filling the current 64-bit block buffer (2 bytes)
	;    +11: CUR_BLOCK, Current 64-bit block buffer (64 bytes plus 256 for extended block)

SHA1_STATE:	defs	11+64+256
SHA1_CUR_BLOCK:	equ	SHA1_STATE+11


	;-------------------------------
	;---  COMMON VARIABLES AREA  ---
	;-------------------------------
	
CHUNK_LEN:	defw	0	;Chunk length in bytes
CHUNK_PNT:	defw	0	;Pointer to the start of next chunk
ROUND_N:	defb	0	;Current round number (1 to 4)
ROUND_PNT:	defw	0	;Current round data pointer

ZERO_PAD:	defb	80h	;Source for final padding
            defs	64-1
