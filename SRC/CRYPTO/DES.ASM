;****************************
;***                      ***
;***  DES AND TRIPLE-DES  ***
;***                      ***
;****************************

;--- Generate DES subkeys from a key
;    Input: HL = Address of the 64 bit key
;           DE = Address of a 96 byte buffer
;		         to generate the 16 6-byte subkeys

DES_INIT:
	push	de

	push	hl
	pop	iy

	ld	h,(iy)	
	ld	l,(iy+1)
	ld	d,(iy+2)
	ld	e,(iy+3)
	ld	b,(iy+4)
	ld	c,(iy+5)
	exx
	ld	h,(iy+6)
	ld	l,(iy+7)
	exx

	ld	ix,DES_PRE_KEY

	;--- Generate the permuted key
	;    by applying P1 to the supplied key

	;First 3 bytes:
	;57   49    41   33    25    17    9    1
	;58   50    42   34    26    18   10    2
	;59   51    43   35    27    19   11    3
	;Get bit 7 of each key byte, in reverse order
	
	exx
	ld	b,3

DES_INIT_1:
	exx
	xor	a

	exx
	rlc	l
	rla
	rlc	h
	rla
	exx
	rlc	c
	rla
	rlc	b
	rla
	rlc	e
	rla
	rlc	d
	rla
	rlc	l
	rla
	rlc	h
	rla

	ld	(ix),a
	inc	ix

	exx
	djnz	DES_INIT_1
	exx

	;4th byte:
	;60   52    44   36    63    55   47   39
	;But since we have rotated 3 times each byte,
	;it is equivalent to:
	;57   49    41   33    60    52   44   36
	;Bit 7 of last four key bytes,
	;then its bit 4

	xor	a

	exx
	rlc	l
	rla
	rlc	h
	rla
	exx
	rlc	c
	rla
	rlc	b
	rla

	exx
	rlc	l
	rlc	l
	rlc	l
	rla
	rlc	h
	rlc	h
	rlc	h
	rla
	exx
	rlc	c
	rlc	c
	rlc	c
	rla
	rlc	b
	rlc	b
	rlc	b
	rla

	ld	(ix),a
	inc	ix

	;5th and 6th byte:
	;31   23    15    7    62    54   46   38
	;The first 4 bytes have been rotated 3 times,
	;the last 4 bytes have been rotated 7 times.
	;Therefore it is equivalent to:
	;28   20    12    4    63    55   47   39
	;27   19    11    3    62    54   46   38
	;Bit 4 of first 4 bytes,
	;then bit 1 of last 4 bytes,
	;two times

	xor	a

	rlc	e
	rlc	e
	rlc	e
	rlc	e
	rla
	rlc	d
	rlc	d
	rlc	d
	rlc	d
	rla
	rlc	l
	rlc	l
	rlc	l
	rlc	l
	rla
	rlc	h
	rlc	h
	rlc	h
	rlc	h
	rla
	exx
	rrc	l
	rrc	l
	rla
	rrc	h
	rrc	h
	rla
	exx
	rrc	c
	rrc	c
	rla
	rrc	b
	rrc	b
	rla

	ld	(ix),a
	inc	ix

	;6th byte:
	;30   22    14    6    61    53   45   37
	;The first 4 bytes have been rotated 7 times,
	;the last 4 bytes have been rotated 7-2 = 5 times.
	;Therefore it is equivalent to:
	;31   23    15    7    64    56   48   40
	;Bit 1 of first 4 bytes, then bit 0 of last 4 bytes.

	rrc	e
	rrc	e
	rla
	rrc	d
	rrc	d
	rla
	rrc	l
	rrc	l
	rla
	rrc	h
	rrc	h
	rla
	exx
	rrc	l
	rla
	rrc	h
	rla
	exx
	rrc	c
	rla
	rrc	b
	rla

	ld	(ix),a
	inc	ix

	;7th byte:
	;29   21    13    5    28    20   12    4
	;The first 4 bytes have been rotated 7-2 = 5 times,
	;therefore it is equivalent to:
	;32   24    16    8    31    23   15    7
	;Bit 0 of the first 4 bytes, then bit 1

	xor	a

	rrc	e
	rla
	rrc	d
	rla
	rrc	l
	rla
	rrc	h
	rla
	rrc	e
	rla
	rrc	d
	rla
	rrc	l
	rla
	rrc	h
	rla

	ld	(ix),a
	
	;--- Generate the pre-16 subkeys by rotating the permuted key

	ld	b,16
	ld	ix,DES_PRE_KEY
	ld	hl,DES_SHIFTS
	ld	de,DES_SUBKEY_BUF
DES_INIT_ROT:

	push	bc

	;Rotate the left subkey.
	;Note that it is 28 bytes long: 3 whole bytes
	;plus the high nibble of the 4th byte.

	ld	b,(hl)	;Number of rotations table
	push	hl
	push	de	;Destination for subkeys
DES_INIT_ROT2:
	
	ld	a,(ix+3)
	ld	c,a
	and	00001111b
	ld	d,a		;D = Backup of low nibble of 3rd byte
	ld	a,c
	and	11110000b
	sla	a		;A = High nibble of 3rd byte, rotated
	rl	(ix+2)
	rl	(ix+1)
	rl	(ix)
	jr	nc,DES_INIT_ROT3
	or	00010000b
DES_INIT_ROT3:
	or	d
	ld	(ix+3),a

	;Rotate the right subkey.
	;Note that it is 28 bytes long:
	;the low nibble of the 1st byte,
	;plus 2 whole bytes.

	ld	a,(ix+3)
	ld	c,a
	and	11110000b
	ld	d,a		;D = Backup of high nibble of 1st byte
	ld	a,c
	sla	(ix+6)
	rl	(ix+5)
	rl	(ix+4)
	rla
	bit	4,a
	jr	z,DES_INIT_ROT4
	set	0,(ix+6)
DES_INIT_ROT4:
	and	00001111b
	or	d
	ld	(ix+3),a

	djnz	DES_INIT_ROT2

	pop	de
	ld	hl,DES_PRE_KEY
	ld	bc,7
	ldir

	pop	hl	;Num. of rotations table pointer
	inc	hl
	pop	bc	;Main subkey loop counter
	djnz	DES_INIT_ROT

	;--- Generate the definitive subkeys
	;    by applying PC-2 to the rotated subkeys

	ld	ix,DES_SUBKEY_BUF
	pop	iy	;Pointer to destination
	exx
	ld	b,16

DES_INIT_PC2:
	ld	h,(ix+6)
	exx
	ld	h,(ix)	
	ld	l,(ix+1)
	ld	d,(ix+2)
	ld	e,(ix+3)
	ld	b,(ix+4)
	ld	c,(ix+5)

	;First byte:
	;14    17   11    24     1    5     3   28

	xor	a
	rrc	l
	rrc	l
	rrc	l
	rla
	rlc	d
	rla
	rrc	l
	rrc	l
	rrc	l
	rla
	rrc	d
	rrc	d
	rla
	rlc	h
	rla
	rlc	h
	rlc	h
	rlc	h
	rlc	h
	rla
	rrc	h
	rrc	h
	rrc	h
	rla
	rlc	e
	rlc	e
	rlc	e
	rlc	e
	rla

	ld	(iy),a
	inc	iy

	;Second byte:
	;15     6   21    10    23    19   12    4
	;We have rotated left:
	;Byte 1, 2 times
	;Byte 2, 2 times
	;Byte 3, 7 times
	;Byte 4, 4 times
	;Therefore it is equivalent to:
	;13     4   22    16    24    20   10    2

	xor	a

	rrc	l
	rrc	l
	rrc	l
	rrc	l
	rla
	rlc	h
	rlc	h
	rlc	h
	rlc	h
	rla
	rrc	d
	rrc	d
	rrc	d
	rla
	rlc	l
	rlc	l
	rlc	l
	rlc	l
	rla
	rlc	d
	rlc	d
	rlc	d
	rla
	rlc	d
	rlc	d
	rlc	d
	rlc	d
	rla
	rlc	l
	rlc	l
	rla
	rrc	h	;Bug corrected, was: 4 x rlc h
	rrc	h
	rrc	h
	rla

	rrc	h	;To compensate for the bug correction

	ld	(iy),a
	inc	iy

	;Third byte:
	;26     8   16     7    27    20   13    2
	;We have rotated left:
	;Byte 1, 2 times
	;Byte 2, 4 times
	;Byte 3, 3 times
	;Byte 4, 4 times
	;Therefore it is equivalent to:
	;30     6   12     5    31    17    9    8

	xor	a

	rrc	e
	rrc	e
	rrc	e
	rla
	rrc	h
	rrc	h
	rrc	h
	rla
	rlc	l
	rlc	l
	rlc	l
	rlc	l
	rla
	rrc	h
	rla
	rlc	e
	rlc	e
	rla
	rlc	d
	rla
	rrc	l
	rrc	l
	rrc	l
	rrc	l
	rla
	rlc	h
	rlc	h
	rlc	h
	rlc	h
	rla

	ld	(iy),a
	inc	iy

	;Fourth byte:
	;41    52   31    37    47    55   30   40
	;We have rotated left:
	;Byte 1, 2 times
	;Byte 2, 4 times
	;Byte 3, 4 times
	;Byte 4, 3 times
	;Therefore it is equivalent to:
	;41    52   28    37    47    55   27   40

	xor	a
	
	rlc	c
	rla
	exx
	rlc	h
	rlc	h
	rlc	h
	rlc	h
	rla
	exx
	rlc	e
	rlc	e
	rlc	e
	rlc	e
	rla
	rrc	b
	rrc	b
	rrc	b
	rrc	b
	rla
	rrc	c
	rrc	c
	rrc	c
	rla
	exx
	rlc	h
	rlc	h
	rlc	h
	rla
	exx
	rrc	e
	rrc	e
	rla
	rlc	b
	rlc	b
	rlc	b
	rlc	b
	rla

	ld	(iy),a
	inc	iy

	;Fifth byte:
	;51    45   33    48    44    49   39   56
	;We have rotated left:
	;Byte 4, 5 times
	;Byte 5, 0 times
	;Byte 6, 6 times
	;Byte 7, 7 times
	;Therefore it is equivalent to:
	;52    47   33    42    46    50   39   49

	xor	a

	exx
	rlc	h
	rlc	h
	rlc	h
	rlc	h
	rla
	exx
	rrc	c
	rrc	c
	rla
	rlc	b
	rla
	rlc	c
	rlc	c
	rlc	c
	rlc	c
	rla
	rlc	c
	rlc	c
	rlc	c
	rlc	c
	rla
	exx
	rrc	h
	rrc	h
	rrc	h
	rla
	exx
	rrc	b
	rrc	b
	rrc	b
	rla
	exx
	rrc	h
	rla
	exx

	ld	(iy),a
	inc	iy

	;Sixth byte:
	;34    53   46    42    50    36   29   32
	;We have rotated left:
	;Byte 4, 5 times
	;Byte 5, 6 times
	;Byte 6, 4 times
	;Byte 7, 7 times
	;Therefore it is equivalent to:
	;36    54   42    46    51    38   32   27

	xor	a

	rlc	b
	rlc	b
	rlc	b
	rlc	b
	rla
	exx
	rrc	h
	rrc	h
	rrc	h
	rla
	exx
	rlc	c
	rlc	c
	rla
	rlc	c
	rlc	c
	rlc	c
	rlc	c
	rla
	exx
	rrc	h
	rrc	h
	rrc	h
	rla
	exx
	rlc	b
	rlc	b
	rla
	rrc	e
	rla
	rlc	e
	rlc	e
	rlc	e
	rlc	e
	rla

	ld	(iy),a
	inc	iy

	;Subkey done, go for the next one

	inc	ix
	inc	ix
	inc	ix
	inc	ix
	inc	ix
	inc	ix
	inc	ix

	exx
	dec	b
	jp	nz,DES_INIT_PC2

	exx
	ret


;--- DES-encrypt or decrypt a 8 byte block
;    Input: Cy = 0 to encrypt, 1 to decrypt
;           HL = Address of the 8 byte block
;           DE = Destination address for the encrypted/decrypted data
;           IX = Pointer to subkeys (generated with DES_INIT)

DES_ENCDEC_BLK:
	ld	bc,6
	jr	nc,DES_BLKED2

	ld	bc,15*6
	add	ix,bc
	ld	bc,-6
DES_BLKED2:
	;IX = Pointer to frist key to apply
	;BC = How much to add to go to next key

	push	bc
	pop	ix

	;* Apply initial permutation

	push	hl
	pop	iy
	ld	ix,DES_EDBLK_L
	ld	h,(iy)	
	ld	l,(iy+1)
	ld	d,(iy+2)
	ld	e,(iy+3)
	ld	b,(iy+4)
	ld	c,(iy+5)
	exx
	ld	h,(iy+6)
	ld	l,(iy+7)

	ld	b,4

	;Loop for first 4 bytes

DES_BLKED_IP:
	xor	a

	rlc	l
	rlc	l
	rla	
	rlc	h
	rlc	h
	rla
	exx
	rlc	c
	rlc	c
	rla
	rlc	b
	rlc	b
	rla
	rlc	e
	rlc	e
	rla
	rlc	d
	rlc	d
	rla
	rlc	l
	rlc	l
	rla
	rlc	h
	rlc	h
	rla

	ld	(ix),a
	inc	ix
	
	exx
	djnz	DES_BLKED_IP

	;Loop for next 4 bytes

	ld	b,4

DES_BLKED_IP2:
	xor	a

	rlc	l
	rla	
	rlc	l
	rlc	h
	rla
	rlc	h
	exx
	rlc	c
	rla
	rlc	c
	rlc	b
	rla
	rlc	b
	rlc	e
	rla
	rlc	e
	rlc	d
	rla
	rlc	d
	rlc	l
	rla
	rlc	l
	rlc	h
	rla
	rlc	h

	ld	(ix),a
	inc	ix
	
	exx
	djnz	DES_BLKED_IP2
	
	;WIP...

	pop	ix
	pop	bc
	ld	hl,DES_EDBLK_L
	ret


	;-------------------
	;---  DATA AREA  ---
	;-------------------

;Permuted key
DES_PRE_KEY:	defs	7

;Number of shifts for each rotation
;for the permuted key
DES_SHIFTS:	defb	1,1,2,2,2,2,2,2,1,2,2,2,2,2,2,1

;Buffer for the subkeys before PC-2 is applied
DES_MISC_BUF:	defs	112
DES_SUBKEY_BUF:	equ	DES_MISC_BUF
DES_EDBLK_L:	equ	DES_MISC_BUF
DES_EDBLK_R:	equ	DES_EDBLK_L+4
DES_EDBLK_RX:	equ	DES_EDBLK_R+4	;Expanded R
DES_EDBLK_RS:	equ	DES_EDBLK_RX+6	;R after applying substitution box

;Bit ordering for PC-1:
;57   49    41   33    25    17    9    1
;58   50    42   34    26    18   10    2
;59   51    43   35    27    19   11    3
;60   52    44   36    63    55   47   39
;31   23    15    7    62    54   46   38
;30   22    14    6    61    53   45   37
;29   21    13    5    28    20   12    4

;Bit ordering for PC-2:
;14    17   11    24     1    5     3   28
;15     6   21    10    23    19   12    4
;26     8   16     7    27    20   13    2
;41    52   31    37    47    55   30   40
;51    45   33    48    44    49   39   56
;34    53   46    42    50    36   29   32

;Expansion table for the Feistel function:
;32     1    2     3     4    5    4     5
; 6     7    8     9     8    9   10    11
;12    13   12    13    14   15   16    17
;16    17   18    19    20   21   20    21
;22    23   24    25    24   25   26    27
;28    29   28    29    30   31   32     1
