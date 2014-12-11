;/*** ATERROR - By Konami Man, 2-2001 ***/

;void naterror ((int*)routine)

;int routine (int errcode, int drive, flags f, unsigned int sector)

global	csv,cret,_naterror

psect	text

_naterror:	call	csv
	ld	(_SAVEIX),ix
	ld	e,(ix+6)	;Direccion
	ld	d,(ix+7)

	ld	a,e
	or	d
	jp	nz,def

undef:	ld	c,64h
	call	5
	jp	FIN

def:	ld	(rut+1),de
	ld	de,errut
	ld	c,64h
	call	5

FIN:	ld	ix,(_SAVEIX)
	jp	cret

	;La rutina llamada en caso de error

errut:	push	de
	ld	l,c
	ld	h,0
	push	hl
	ld	l,b
	push	hl
	ld	l,a
	push	hl
rut:	call	0
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ld	a,l
	ret

_SAVEIX:	defw	0

