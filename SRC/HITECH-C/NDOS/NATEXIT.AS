;void natexit ((int*)routine)

;int routine (int primerr, int secerr)
;Debe devolver: 0 para seguir la ejecucion, otro para terminar

global	csv,cret,_natexit

psect	text

_natexit:      call    csv
	ld	(_SAVEIX),ix
	ld	e,(ix+6)	;Direccion
	ld	d,(ix+7)

	ld	a,e
	or	d
	jp	nz,def

undef:	ld	c,63h
	call	5
	jp	FIN

def:	ld	(rut+1),de
	ld	de,exrut
	ld	c,63h
	call	5

FIN:	ld	ix,(_SAVEIX)
	jp	cret

	;La rutina llamada al terminar

exrut:	ld	(_PRIME),a ;Guarda error primario
	ld	a,b
	ld	(_SECE),a  ;Guarda error secundario
	xor	a
	ld	(_PRIME+1),a
	ld	(_SECE+1),a
	ld	bc,_SECE
	push	bc
	ld	bc,_PRIME
	push	bc
rut:	call	0
	pop	bc
	pop	bc
	ld	a,h
	or	l
	ld	a,(_SECE)  ;Recupera error secundario
	ld	b,a
	ld	a,(_PRIME) ;Recupera error secundario
	ret	nz
	pop	de	;Para que no termine
	ret

_SAVEIX:	defw	0
_PRIME: defw	0
_SECE:	defw	0

