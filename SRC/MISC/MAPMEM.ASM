;Helper routines to manage mapped memory in DOS 2.

;=================================

	;Gestion de memoria mapeada en DOS 2

ENASLT:	equ	#0024
EXTBIO:	equ	#FFCA

;--- Inicializacion

	;Copia la tabla de rutinas del mapeador

INITMEM:	ld	de,#0402
	call	EXTBIO
	ld	de,ALL_SEG
	ld	bc,#30
	ldir

	ld	a,4
	ld	(NUMSEGS),a

	ld	a,(#F344)	;Rellena las 4 primeras entradas
	ld	(TABSEGS),a	;con los segmentos de TPA
	ld	(TABSEGS+2),a
	ld	(TABSEGS+4),a
	ld	(TABSEGS+6),a
	ld	(CURSLOT2),a
	call	GET_P0
	ld	(TABSEGS+1),a
	call	GET_P1
	ld	(TABSEGS+3),a
	call	GET_P2
	ld	(TABSEGS+5),a
	call	GET_P3
	ld	(TABSEGS+7),a

	ld	a,2
	ld	(CUR_S2),a

	ret

NUMSEGS:	db	0	;Num. de segmentos reservados
TABSEGS:	ds	255	;Tabla de segmentos reservados

	;Rutinas de soporte del mapeador

ALL_SEG:	ds	3
FRE_SEG:	ds	3
RD_SEG:	ds	3
WR_SEG:	ds	3
CAL_SEG:	ds	3
CALLS:	ds	3
PUT_PH:	ds	3
GET_PH:	ds	3
PUT_P0:	ds	3
GET_P0:	ds	3
PUT_P1:	ds	3
GET_P1:	ds	3
PUT_P2:	ds	3
GET_P2:	ds	3
PUT_P3:	ds	3
GET_P3:	ds	3


;--- FINISH:  Libera toda la memoria reservada
;    Entrada: -
;    Salida:  -
;    Regist:  AF, BC, DE, HL

FINISH:	ld	a,(NUMSEGS)
	cp	4
	ret	z

	ld	c,4
	ld	de,TABSEGS+8
	ld	hl,NUMSEGS

BUC_FM:	ld	a,(de)
	ld	b,a	;B = Slot
	inc	de
	ld	a,(de)	;A = Segmento
	inc	de
	push	bc,de,hl
	call	FRE_SEG
	pop	hl,de,bc
	inc	c
	ld	a,c
	cp	(hl)
	jr	nz,BUC_FM

	ret


;--- GET_S2:  Devuelve el segmento logico conectado en la pagina 2
;    Entrada: -
;    Salida:  A = Segmento en pagina 2
;    Regist:  -

GET_S2:	ld	a,(CUR_S2)
	ret

CUR_S2:	db	0


;--- PUT_S2:  Conecta un segmento logico
;    Entrada: A = Numero de segmento
;    Salida:  -
;    Regist:  -

PUT_S2:	push	af,hl,bc
	ld	(CUR_S2),a
	ld	c,a
	ld	b,0
	ld	hl,TABSEGS
	add	hl,bc
	add	hl,bc
	ld	a,(CURSLOT2)
	ld	b,a
	ld	a,(hl)
	cp	b
	jr	z,PUTS22

	push	af,hl,de,ix,iy	;Conecta el slot solo si no esta
	ld	h,#80	;conectado ya
	call	ENASLT
	pop	iy,ix,de,hl,af
	ld	(CURSLOT2),a

PUTS22:	inc	hl	;Conecta segmento fisico
	ld	a,(hl)
	call	PUT_P2
	pop	bc,hl,af
	ret

CURSLOT2:	db	0
