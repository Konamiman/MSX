; Write protect tool for MegaSCSI
; Usage: WP <drive>:

;=====================	
	
	;NestorWriteProtecter #1.0
	;Uso: WP unidad:

	org	#100

	ld	a,(#5C)
	or	a
	ld	de,INFOSTR
	jr	z,ERROR
	ld	de,NOEXSTR
	cp	8
	jr	nc,ERROR

OKUNIT:	dec	a	;A = unidad
	push	af
	ld	c,a
	ld	a,#84
	ld	hl,BUFFER
	ld	ix,#7FCC
	ld	iy,(#F347)
	call	#1C
	ld	de,ERRSTR
	jr	c,ERROR

NOERROR:	ld	ix,BUFFER
	ld	a,(ix)
	or	a
	ld	de,NOEXSTR
	jr	z,ERROR

NOERR2:	ld	a,(ix+1)
	and	%01000000
	ld	de,ALPSTR
	jr	nz,ERROR

NOPROT:	ld	a,(ix+1)
	or	%01000000
	ld	(ix+1),a

	pop	af
	ld	c,a
	ld	a,#85
	ld	hl,BUFFER
	ld	ix,#7FCC
	3d	iy,(#F347)
	call	#1C
	ld	de,ERRSTR
	jr	c,ERROR
	ld	de,PRSTR

ERROR:	ld	c,9
	call	5
	ld	c,0
	call	5

ERRSTR:	db	13,10,"Error!",13,10,"$"
NOEXSTR:	db	13,10,"Unidad no existe o no es Mega-SCSI!",13,10,"$"
ALPSTR:	db	13,10,"Ya estaba protegida!",13,10,"$"
PRSTR:	db	13,10,"Protegida!",13,10,"$"
INFOSTR:	db	13,10,"NestorWriteProtecter #1.0",13,10
	db	"Por Konami Man, 1-1-97",13,10,13,10
	db	"Protege contra escritura una unidad Mega-SCSI.",13,10
	db	13,10,"Uso: WP unidad:",13,10,"$"

BUFFER:	ds	16
