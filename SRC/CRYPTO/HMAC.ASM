;*******************************
;***                         ***
;***  HMAC HASHING ROUTINES  ***
;***                         ***
;*******************************

;NOTE: this code depends on MD5_SHA1.ASM

	;Usage:
    ;
	;To hash a short message in one single step, call the routine with these parameters:
	;        A  = 3
	;        IX = Address of message to digest
	;        BC = Length of message in bytes
	;        IY = Address of key
	;        HL = Length of key
	;        DE = Destination address for the hash
	;
	;To hash a message in chunks (because it does not fit in the available memory,
	;or because you don't have the whole message available in advance):
	;
	;1. Call the routine to initialize the hashing procedure with:
	;   A = 0
	;   IY = Address of key
	;   DE = Length of key
	;2. For each message chunk call the routine with these parameters:
	;   A  = 1
	;   HL = Address of the chunk
	;   BC = Length of the chunk (may be anything, even zero)
	;3. After all the chunks are processed, retrieve the hash by calling
	;   the routine with these parameters:
	;   A  = 2
	;   DE = Address for the generated MD5 16-byte or SHA1 20-byte hash


HMAC_MD5:
	or	a
	jr	z,HMAC_INIT_MD5

	cp	1
	jp	z,HMAC_ROUTINE

	cp	2
	jr	z,HMAC_END

	jp	HMAC_ONESTEP_MD5

HMAC_SHA1:
	or	a
	jr	z,HMAC_INIT_SHA1

	cp	1
	jp	z,HMAC_ROUTINE

	cp	2
	jr	z,HMAC_END

	jp	HMAC_ONESTEP_SHA1


	;--- Initialization:
	;    Hash (key xor ipad) and leave the hashing engine
	;    ready for hashing message chunks

HMAC_INIT_MD5:
	ld	a,16
	ld	hl,HASH_MD5
	jr	HMAC_INIT

HMAC_INIT_SHA1:
	ld	a,20
	ld	hl,HASH_SHA1

HMAC_INIT:
	ld	(HMAC_LEN),a
	ld	(HMAC_ROUTINE+1),hl

	push	de	;Initialize zero padding for key
	ld	hl,HMAC_KEY
	ld	de,HMAC_KEY+1
	ld	(hl),0
	ld	bc,64-1
	ldir
	pop	de

	ld	hl,64
	call	COMP16
	jr	nc,HMAC_SHORTKEY

	;* The key is longer than HMAC_LEN: hash it first to HMAC_KEY
	
	push	iy

	push	iy
	pop	hl
	push	de
	pop	bc
	ld	de,HMAC_KEY
	ld	a,3
	call	HMAC_ROUTINE

	pop	iy
	ld	de,HMAC_KEY
	jr	HMAC_DO_IPAD

	;* Copy the original key or the hashed one to HMAC_KEY

HMAC_SHORTKEY:
	ld	a,d
	or	e
	jr	z,HMAC_DO_IPAD	;Empty key?

	push	de
	pop	bc
	push	iy
	pop	hl
	ld	de,HMAC_KEY
	ldir

	;* Apply ipad

HMAC_DO_IPAD:
	ld	hl,HMAC_KEY
	ld	b,64
HMAC_IPAD_LOOP:
	ld	a,(hl)
	xor	36h
	ld	(hl),a
	inc	hl
	djnz	HMAC_IPAD_LOOP
	
	;* Initialize the hashing procedure, then hash the processed key

	xor	a
	call	HMAC_ROUTINE

	ld	a,1
	ld	hl,HMAC_KEY
	ld	bc,64
	jp	HMAC_ROUTINE

	
	;--- Finalization:
	;    Finish the internal hash, then hash (key xor opad) || (internal hash)

HMAC_END:
	push	de

	ld	de,HMAC_INTERNAL
	call	HMAC_ROUTINE	;A=2 already

	;* Xor the key with opad (5Ch).
	;  Since the key was already XORed with ipad (36h),
	;  we xor with (ipad xor opad) = 6Ah.

HMAC_DO_OPAD:
	ld	hl,HMAC_KEY
	ld	b,64
HMAC_OPAD_LOOP:
	ld	a,(hl)
	xor	6Ah
	ld	(hl),a
	inc	hl
	djnz	HMAC_OPAD_LOOP
	
	;* Initialize the hashing procedure, then hash the processed key

	xor	a
	call	HMAC_ROUTINE

	ld	a,1
	ld	hl,HMAC_KEY
	ld	bc,64
	call	HMAC_ROUTINE

	;* Finally, hash the internal hash

	ld	a,1
	ld	hl,HMAC_INTERNAL
	ld	bc,(HMAC_LEN)
	ld	b,0
	call	HMAC_ROUTINE

	pop	de
	ld	a,2
	jp	HMAC_ROUTINE
	

	;--- Single-step processing

HMAC_ONESTEP_MD5:
	push	de
	push	ix
	push	bc
	ex	de,hl
	call	HMAC_INIT_MD5
	jr	HMAC_ONESTEP

HMAC_ONESTEP_SHA1:
	push	de
	push	ix
	push	bc
	ex	de,hl
	call	HMAC_INIT_SHA1

HMAC_ONESTEP:
	pop	bc
	pop	hl
	ld	a,1
	call	HMAC_ROUTINE

	pop	de
	ld	a,2
	jp	HMAC_END


	;-------------------
	;---  DATA AREA  ---
	;-------------------

HMAC_LEN:	defb	0
HMAC_ROUTINE:	jp	0

HMAC_KEY:	defs	64
HMAC_INTERNAL:	defs	20
