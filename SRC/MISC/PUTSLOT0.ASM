;Routine to switch the slot in page 0 without using ENASLT.

;===================================

;--- NOMBRE: PUTSLOT0
;      Conecta un slot en la pagina 0 sin usar ENASLT
;      Vuelve con las interrupciones inhibidas
;    ENTRADA:   A = Slot a conectar
;    SALIDA:    -
;    REGISTROS: AF
;    LLAMADAS:  -
;    VARIABLES: -

PUTSLOT0:	di
	push	hl,de,bc
	ld	c,a	;C = Slot+subslot a conectar
	and	%00000011	;B = Slot a conectar (=C and 3)
	ld	b,a

	in	a,(#A8)
	and	%11111100
	or	b
	ld	d,a	;D = Nuevo valor a mandar a #A8

	ld	a,c	;Slot expandido?
	bit	7,a
	jr	z,OCU_PPR

	ld	a,b
	rrca
	rrca
	ld	b,a	;B = Slot a conectar, en pagina 3
	ld	a,d
	or	b
	out	(#A8),a	;Slot conectado en pagina 3

	ld	a,c
	and	%00001100
	sra	a
	sra	a	;B = Subslot a conectar
	ld	b,a

	ld	a,(-1)	;Conexion del subslot
	cpl
	and	%11111100
	or	b
	ld	(-1),a

	ld	a,d	;Conexion del slot
	out	(#A8),a

	ld	hl,#FCC5
	ld	a,c
	and	%00000011	;E = Slot conectado
	ld	e,a
	ld	d,0
	add	hl,de
	ld	a,(hl)
	and	%11111100
	or	b
	ld	(hl),a
	jr	OCU_FPS

OCU_PPR:	ld	a,d
	out	(#A8),a
OCU_FPS:	pop	bc,de,hl
	ret

