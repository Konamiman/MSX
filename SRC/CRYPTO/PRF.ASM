;************************************
;***                              ***
;***  TLS PSEUDO-RANDOM FUNCTION  ***
;***                              ***
;************************************

;NOTE: this code depends on MD5_SHA1.ASM

	;Input:
	;IX = Address of secret (assumed to be 48 bytes)
	;IY = Address of label
	;B  = Length of label
	;HL = Address of seed
	;C  = Length of seed (up to 64 bytes)
	;DE = Destination address for bytes
	;A  = Number of bytes to generate (up to 120)

PRF:
	;--- Initialize variables

	ld	(PRF_BYTES),a
	ld	(PRF_DEST),de
	ld	(PRF_LABEL),iy
	ld	a,b
	ld	(PRF_LAB_LEN),a
	ld	a,c
	ld	(PRF_SEED_LEN),a
	
	ld	b,0
	ld	de,PRF_SEED
	ldir

	;--- Generate the MD5 and SHA1 bytes

	push	ix
	push	ix
	pop	iy
	ld	a,16
	ld	ix,HMAC_MD5
	ld	de,PRF_MD5
	call	PRF_HASH

	pop	iy
	ld	bc,24
	add	iy,bc
	ld	a,20
	ld	ix,HMAC_SHA1
	ld	de,PRF_SHA1
	call	PRF_HASH

	;--- Finally, generate P_MD5 xor P_SHA1

	ld	ix,PRF_MD5
	ld	hl,PRF_SHA1
	ld	a,(PRF_BYTES)
	ld	b,a
	ld	de,(PRF_DEST)
PRF_XOR_LOOP:
	ld	a,(ix)
	xor	(hl)
	ld	(de),a
	inc	ix
	inc	hl
	inc	de
	djnz	PRF_XOR_LOOP

	ret


	;* Generate HMAC_hash(Sx, A(i) + label + seed)
	;    as much times as necessary
	;  Input: IY = Pointer to S1 or S2
	;         A  = Hash length (16 for MD5, 20 for SHA1)
	;         DE = Destination address for the hash bytes 
	;         IX = Address of hash routine

PRF_HASH:
	ld	(PRF_DO_HASH+1),ix
	ld	(PRF_HASH_LEN),a
	ld	(PRF_S_PNT),iy
	ld	bc,0
	
	push	bc
	push	de

	;* Calculate A(1) = HMAC(Sx, label + seed)

	xor	a
	ld	de,24
	ld	iy,(PRF_S_PNT)
	call	PRF_DO_HASH

	ld	a,1
	ld	hl,(PRF_LABEL)
	ld	bc,(PRF_LAB_LEN)
	call	PRF_DO_HASH

	ld	a,1
	ld	hl,PRF_SEED
	ld	bc,(PRF_SEED_LEN)
	call	PRF_DO_HASH

	ld	a,2
	ld	de,PRF_A
	call	PRF_DO_HASH

	;* Calculate HMAC(Sx, A(i) + label + seed)

PRF_HASH_LOOP:
	xor	a
	ld	de,24
	ld	iy,(PRF_S_PNT)
	call	PRF_DO_HASH

	ld	a,1
	ld	hl,PRF_A
	ld	bc,(PRF_HASH_LEN)
	call	PRF_DO_HASH

	ld	a,1
	ld	hl,(PRF_LABEL)
	ld	bc,(PRF_LAB_LEN)
	call	PRF_DO_HASH

	ld	a,1
	ld	hl,PRF_SEED
	ld	bc,(PRF_SEED_LEN)
	call	PRF_DO_HASH

	ld	a,2
	pop	de
	push	de
	call	PRF_DO_HASH

	ld	bc,(PRF_HASH_LEN)
	pop	hl
	add	hl,bc
	ex	de,hl	;DE=Pointer to generate next chunk of bytes

	pop	hl	;HL=No. of bytes generated so far
	add	hl,bc
	push	de
	ld	de,(PRF_BYTES)
	call	COMP16
	pop	de
	ret	nc

	;* Calculate A(i+1) = HMAC(Sx, A(i))

	push	hl
	push	de

	ld	a,3
	ld	ix,PRF_A
	ld	bc,(PRF_HASH_LEN)
	ld	iy,(PRF_S_PNT)
	ld	hl,24
	ld	de,PRF_A
	call	PRF_DO_HASH

	jr	PRF_HASH_LOOP



	;-------------------
	;---  DATA AREA  ---
	;-------------------

PRF_S_PNT:	defw	0
PRF_A:		defs	64
PRF_MD5:	defs	128
PRF_SHA1:	defs	128
PRF_BYTES:	defw	0
PRF_DEST:	defw	0
PRF_LABEL:	defw	0
PRF_LAB_LEN:	defw	0
PRF_SEED:	defs	64
PRF_SEED_LEN:	defw	0
PRF_HASH_LEN:	defw	0
PRF_DO_HASH:	jp	0
