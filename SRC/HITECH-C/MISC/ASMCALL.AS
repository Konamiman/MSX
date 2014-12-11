; ASMCALL 1.1 - Function to call assembler routines from a C program
; By Konami Man, 2-2001

; Use:
; void asmcall (uint address, regset* regs)

;typedef struct{
;     uchar    f
;     uchar    a
;     uint     bc
;     uint     de
;     uint     hl
;     uint     ix
;     uint     iy
;} regset


global	csv,cret,_asmcall

psect	text

_asmcall:	call	csv
	ld	l,(ix+6)	;Address
	ld	h,(ix+7)
	ld	e,(ix+8)	;Registers
	ld	d,(ix+9)
	ld	(ASMDIR+1),hl

	ld	a,d
	or	e
	jr	z,ASMC2

	;*** With registers

	push	ix
GETREG: ld	b,6
	ex	de,hl
	dec	hl
GETR2:	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	push	de
	djnz	GETR2

	pop	iy
	pop	ix
	pop	hl
	pop	de
	pop	bc
	pop	af

	call	ASMDIR

	ex	(sp),iy
	push	ix
	push	hl
	push	de
	push	bc
	push	af
	ld	l,(iy+8)
	ld	h,(iy+9)

GETR3:	ld	b,6
	dec	hl

GETR4:	pop	de
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	djnz	GETR4

	push	iy
	pop	ix
	jp	cret

	;*** Without registers

ASMC2:	push	ix
	call	ASMDIR
	pop	ix
	jp	cret

ASMDIR: jp	0

