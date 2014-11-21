;A couple of routines to save and restore
;all Z80 registers in the stack.

;========================

	;- Una subrutina que introduzca todos los registros en la pila?!
	;  Imposible!
	;- Nada es imposible para Konami Man!!

	;--- Preubas

	ld	sp,#D200

	ld	bc,#1234
	push	bc
	pop	af
	ld	bc,#1111
	ld	de,#2222
	ld	hl,#3333
	ld	ix,#4444
	ld	iy,#5555
	exx
	ex	af,af
	ld	a,#66
	ld	bc,#7777
	ld	de,#8888
	ld	hl,#9999
	exx
	ex	af,af

	call	TODOPUSH
	nop
	nop
	nop
	call	TODOPOP
	ret		;Si aqui tienes SP = #D200 es que funciona!!

TODOPUSH:	push	af,bc,de,hl,ix,iy
	exx
	ex	af,af
	push	af,bc,de,hl
	exx
	ex	af,af
	ld	a,b
	ld	b,18
BUCPUSH:	inc	sp
	djnz	BUCPUSH
	ld	b,a
	pop	af
	ret

TODOPOP:	ld	b,20
BUCPOP:	dec	sp
	djnz	BUCPOP
	exx
	ex	af,af
	pop	hl,de,bc,af
	exx
	ex	af,af
	pop	iy,ix,hl,de,bc,af
	ret
