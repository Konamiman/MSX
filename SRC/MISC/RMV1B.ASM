;This small routine just removes the first byte from a file.

;==================================

	;--- Quitador del primer byte de un fichero

	;--- Abrimos

	ld	de,FILENAME1
	ld	c,#43
	ld	a,1	;No write
	call	5
	jr	z,OKOPEN1

	ld	b,a
	ld	c,#62
	jp	5

OKOPEN1:	ld	a,b
	ld	(FH1),a

	ld	de,FILENAME2
	ld	c,#44
	ld	a,2	;No read
	ld	b,0
	call	5
	jr	z,OKOPEN2

	ld	b,a
	ld	c,#62
	jp	5

OKOPEN2:	ld	a,b
	ld	(FH2),a

	;--- Saltamos el 1er byte

	ld	c,#48
	ld	a,(FH1)
	ld	b,a
	ld	de,#4000
	ld	hl,1
	call	5

	;--- Leemos y escribimos

LOOP:	ld	c,#48
	ld	a,(FH1)
	ld	b,a
	ld	de,#4000
	ld	hl,#8000
	call	5
	jr	nz,OKCOPY

	ld	c,#49
	ld	a,(FH2)
	ld	b,a
	ld	de,#4000
	call	5
	jr	LOOP

	;--- Fin: cerramos ficheros

OKCOPY:	ld	a,(FH1)
	ld	b,a
	ld	c,#45
	call	5

	ld	a,(FH2)
	ld	b,a
	ld	c,#45
	call	5

	ld	bc,#62
	jp	5

	;--- Datos

FILENAME1:	db	"d:\nemesis3.img",0
FILENAME2:	db	"d:\nemesis3.dsk",0
FH1:	db	0
FH2:	db	0
