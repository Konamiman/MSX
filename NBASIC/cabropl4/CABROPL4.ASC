	;CONTROL DIRECTO DEL OPL4 PARA NESTORBASIC
	;A peticion del cabron

	;Se ejecuta con:
	;   P(0)=Segmento
	;   P(1)=Direccion
	;   P(2)=Canal
	;   P(3)=Parametro:
	;        0: Reset
	;        1: No. instrumento (0-511)
	;	    0-383 para instrumento ROM, 385-511 para SRAM
	;	 2: Nota (0-1023)
	;        3: Octava (-7 - 7)
	;        4: Volumen (0-127)
	;        5: Stereo (-7 - 7)
	;        6: Vibrato (0-7)
	;        7: Velocidad LFO (0-7)
	;        8: Tremolo (0-7)
	;        9: Pseudo reverb on/off/invertir (1/0/-1)
	;       10: Canal on/off/invertir (1/0/-1)
	;       11: Parar nota
	;       12: Reset LFO
	;       13: Volumen maestro (0-7)
	;   P(4)=Valor
	;
	;MODIFICACION: Si P(3)=14, toca las notas
	;              P(8) a P(11) en los canales 1 a 4.
	;              Entonces P(7) = &B4321 (a 1 para que suene)
	;MODIFICA2:    Si P(3)=15,
	;              P(4) a P(7) = Canales A, B, C, D (0=nada)
	;              P(8) a P(11) = Nota A, B, C, D

	org	#8000

;********************************************
;*** PUNTO DE EJECUCION DESDE NESTORBASIC ***
;********************************************

;Entrada: AF = P(2) = Canal
;         BC = P(3) = Numero de funcion
;         DE = P(4) = Valor
;Salida:  No modifica P(0), P(1), P(2)
;         Destroza P(3) a P(11)

;MODIFICACION: Para la funcion 14, la entrada es P(8) a P(11).

	;--- Guarda todos los parametros de entrada

	ld	(SAVE_SP),sp
	push	af,bc,de,hl,ix,iy
	exx
	ex	af,af
	push	af,bc,de

	ld	(P_11),hl
	pop	hl
	ld	(P_10),hl
	pop	hl
	ld	(P_9),hl
	pop	hl
	ld	(P_8),hl
	pop	hl
	ld	(P_7),hl
	pop	hl
	ld	(P_6),hl
	pop	hl
	ld	(P_5),hl
	pop	hl
	ld	(P_4),hl
	pop	hl
	ld	(P_3),hl
	pop	hl
	ld	(P_2),hl

	ld	hl,(P_11)
	ex	af,af
	exx
	ld	sp,(SAVE_SP)

	;--- Decide que funcion ejecutar

	ex	af,af
	push	af	;Copia P(8) a IX
	pop	ix
	ex	af,af

	push	af
	push	af
	pop	hl	;L=Canal
	ld	a,l

	push	bc	;BC = Funcion
	pop	hl
	add	hl,bc
	add	hl,bc
	push	hl
	pop	bc
	ld	hl,TABLA
	add	hl,bc

	ld	c,a
	ld	b,0
	dec	bc
	jp	(hl)

;**********************
;*** TABLA DE SALTO ***
;**********************

TABLA:	;
F0:	jp	RESET
F1:	jp	INSTR
F2:	jp	NOTA
F3:	jp	OCTAVA
F4:	jp	VOLUMEN
F5:	jp	STEREO
F6:	jp	VIBRATO
F7:	jp	LFOSPEED
F8:	jp	TREMOLO
F9:	jp	REVERB
F10:	jp	CANAL
F11:	jp	OFF
F12:	jp	RESETLFO
F13:	jp	MASTVOL
F14:	jp	CUATROCAN	;Nuevo!!!
F15:	jp	QUE4CAN	;Novisimo!!!!!


;***************
;*** RUTINAS ***
;***************

;Entrada: BC = Canal-1
;         DE = Valor
;Salida:  Recuperar AF de la pila

;*** SUBRUTINAS VARIAS ***

FIN:	pop	af
	ret

WAIT:	in	a,(#C4)
	bit	0,a
	jr	nz,WAIT
	ret

OPL4:	ex	af,af	;C=Puerto, A=Valor
	ld	a,c	;Modifica AF'
	out	(#7E),a
	call	WAIT
	ex	af,af
	out	(#7F),a
	ex	af,af
	call	WAIT
	ex	af,af
	ret

SAVE_08:	ds	24
SAVE_20:	ds	24	;Preserva los valores de los registros
SAVE_38:	ds	24
SAVE_68:	ds	24,#80
SAVE_80:	ds	24


;*** RESET DEL OPL4 ***

RESET:	xor	a
	out	(#C4),a
	nop
	out	(#C5),a
	nop
	out	(#7E),a
	nop
	out	(#7F),a

	ld	a,5	;OPL4 en modo OPL4
	out	(#C6),a	;(nota: creerselo si es necesario)
	nop
	nop
	ld	a,3
	out	(#C7),a

	ld	c,#02	;Le dice al OPL4 donde esta la ROM,
	ld	a,#10	;o algo asi
	call	OPL4

	ld	hl,SAVE_20	;Limpia zona de reserva de registros
	ld	de,SAVE_20+1
	ld	bc,24*4-1
	ld	(hl),0
	ldir

	ld	b,24
BUCRESTE:	ld	a,#68-1	;Stereo a cero y canal ON
	add	b
	ld	c,a
	ld	a,#C0
	call	OPL4
	ld	a,c
	sub	#68-#50
	ld	c,a
	xor	a
	call	OPL4
	djnz	BUCRESTE

	ld	hl,SAVE_68
	ld	de,SAVE_68+1
	ld	bc,23
	ld	(hl),#80
	ldir

	jp	FIN


;*** INSTRUMENTO ***

INSTR:	ld	hl,SAVE_20
	add	hl,bc	;HL = Zona de reserva del registro
	ld	b,c	;B = Canal

	ld	a,#20
	add	b
	ld	c,a	;C = Registro

	ld	a,d	;Primero mandamos bit 8
	and	1
	ld	d,a
	ld	a,(hl)
	and	%11111110
	or	d
	ld	(hl),a
	call	OPL4

	ld	hl,SAVE_68	;Desconectamos el canal para que
	ld	c,b	;no suene al cambiar el instrumento
	ld	b,0
	add	hl,bc
	ld	b,c
	ld	a,(hl)
	and	%01111111
	ld	d,a
	ld	a,#68
	add	b
	ld	c,a
	ld	a,d
	call	OPL4

	ld	a,#08
	add	b
	ld	c,a	;C = Registro

	ld	a,e
	call	OPL4	;Mandamos bits 0-7

	ld	a,(hl)	;Dejamos el canal como estaba
	or	#40
	ld	d,a
	ld	a,#68
	add	b
	ld	c,a
	ld	a,d
	call	OPL4

	jp	FIN

;*** NOTA (tambien hace que suene el OPL4) ***

NOTA:	call	NOTA2
	jp	FIN

NOTA2:	ld	hl,SAVE_38
	add	hl,bc	;HL = Zona de reserva del registro
	ld	b,c	;B = Canal

	ld	a,#38
	add	b
	ld	c,a	;C = Registro

	sla	e
	rl	d
	ld	a,d
	and	%111
	ld	d,a
	ld	a,(hl)
	and	%11111000	;Mandamos bits 7,8,9
	or	d
	ld	(hl),a
	call	OPL4

	ld	hl,SAVE_20
	ld	c,b
	ld	b,0
	add	hl,bc
	ld	b,c

	ld	a,#20
	add	b
	ld	c,a

	ld	a,(hl)
	and	1
	or	e
	ld	(hl),a	;Mandamos bits 0 a 6
	call	OPL4

	ld	hl,SAVE_68
	ld	c,b
	ld	b,0
	add	hl,bc
	ld	b,c
	ld	a,#68
	add	b
	ld	c,a
	ld	a,(hl)
	call	OPL4

	ld	a,#20
	add	b
	out	(#7E),a
	call	WAIT
	in	a,(#7F)
	out	(#7F),a
	call	WAIT

	ld	a,#08	;Toca la nota
	add	b
	out	(#7E),a
	call	WAIT
	in	a,(#7F)
	out	(#7F),a

	ret		;jp      FIN


;*** OCTAVA ***

OCTAVA:	ld	hl,SAVE_38
	add	hl,bc
	ld	b,c

	ld	a,e
	rla
	rla
	rla
	rla
	and	%11110000
	ld	e,a
	ld	a,(hl)
	and	%00001111
	or	e
	ld	(hl),a
	ld	e,a
	ld	a,#38
	add	b
	ld	c,a
	ld	a,e
	call	OPL4

	jp	FIN


;*** VOLUMEN ***

VOLUMEN:	ld	a,#50
	add	c
	ld	c,a

	sla	e
	ld	a,e
	call	OPL4

	jp	FIN


;*** STEREO ***

STEREO:	ld	hl,SAVE_68
	add	hl,bc
	ld	b,c

	ld	a,e
	and	%00001111
	ld	e,a
	ld	a,(hl)
	and	%11110000
	or	e
	and	%10101111
	ld	e,a
	ld	(hl),e
	ld	a,#68
	add	b
	ld	c,a
	ld	a,e
	call	OPL4

	jp	FIN


;*** VIBRATO ***

VIBRATO:	ld	hl,SAVE_80
	add	hl,bc
	ld	b,c

	ld	a,e
	and	%111
	ld	e,a
	ld	a,(hl)
	and	%11111000
	or	e
	ld	e,a
	ld	(hl),a
	ld	a,#80
	add	b
	ld	c,a
	ld	a,e
	call	OPL4

	jp	FIN


;*** VELOCIDAD LFO ***

LFOSPEED:	ld	hl,SAVE_80
	add	hl,bc
	ld	b,c

	ld	a,e
	rla
	rla
	rla
	and	%111000
	ld	e,a
	ld	a,(hl)
	and	%11000111
	or	e
	ld	e,a
	ld	(hl),a
	ld	a,#80
	add	b
	ld	c,a
	ld	a,e
	call	OPL4

	jp	FIN


;*** VELOCIDAD TREMOLO ***

TREMOLO:	ld	a,#E0
	add	c
	ld	c,a

	ld	a,e
	and	%111
	call	OPL4

	jp	FIN


;*** PSEUDO REVERB ON/OFF ***

REVERB:	ld	hl,SAVE_38
	add	hl,bc
	ld	b,c

	ld	a,e
	or	a
	jr	z,REVOFF
	cp	1
	jr	z,REVON

REVINV:	ld	a,(hl)
	xor	%00001000
	jr	REVOK
REVOFF:	ld	a,(hl)
	and	%11110111
	jr	REVOK
REVON:	ld	a,(hl)
	or	%00001000

REVOK:	ld	(hl),a
	ld	e,a
	ld	a,#38
	add	b
	ld	c,a
	ld	a,e
	call	OPL4

	jp	FIN


;*** CANAL ON/OFF ***

CANAL:	ld	hl,SAVE_68
	add	hl,bc
	ld	b,c

	ld	a,e
	or	a
	jr	z,CANOFF
	cp	1
	jr	z,CANON

CANINV:	ld	a,(hl)
	xor	%10000000
	jr	REVOK
CANOFF:	ld	a,(hl)
	and	%01111111
	jr	REVOK
CANON:	ld	a,(hl)
	or	%10000000

CANOK:	and	%10101111
	ld	(hl),a
	ld	e,a
	ld	a,#68
	add	b
	ld	c,a
	ld	a,e
	call	OPL4

	jp	FIN


;*** NOTA OFF ***

OFF:	ld	hl,SAVE_68
	add	hl,bc
	ld	b,c

	ld	a,(hl)
	or	%01000000
	ld	e,a
	ld	a,#68
	add	b
	ld	c,a
	ld	a,e
	call	OPL4

	jp	FIN


;*** RESET DEL LFO ***

RESETLFO:	ld	hl,SAVE_68
	add	hl,bc
	ld	b,c

	ld	a,e
	or	a
	jr	z,RLFOOFF
	cp	1
	jr	z,RLFOON

RLFOINV:	ld	a,(hl)
	xor	%00100000
	jr	RLFOOK
RLFOOFF:	ld	a,(hl)
	and	%11011111
	jr	RLFOOK
RLFOON:	ld	a,(hl)
	or	%00100000

RLFOOK:	and	%10101111
	ld	(hl),a
	ld	e,a
	ld	a,#68
	add	b
	ld	c,a
	ld	a,e
	call	OPL4

	jp	FIN


;*** VOLUMEN MAESTRO ***

MASTVOL:	ld	a,#F9
	out	(#7E),a
	ld	a,e
	and	%111
	ld	c,a
	ld	b,0
	ld	hl,VOLTABLE
	add	hl,bc
	ld	a,(hl)
	out	(#7F),a
	jp	FIN

VOLTABLE:	db	#3F,#36,#2D,#24,#1B,#12,#09,#00


;*** 4 CANALES A LA VEZ ***

CUATROCAN:	ld	bc,0
	push	ix
	pop	de
	ld	a,iyl
	bit	0,a
	call	nz,NOTA2

	exx
	push	bc
	exx
	pop	de
	ld	bc,1
	ld	a,iyl
	bit	1,a
	call	nz,NOTA2

	exx
	push	de
	exx
	pop	de
	ld	bc,2
	ld	a,iyl
	bit	2,a
	call	nz,NOTA2

	exx
	push	hl
	exx
	pop	de
	ld	bc,3
	ld	a,iyl
	bit	3,a
	call	nz,NOTA2

	jp	FIN

;*** 4 CANALES A ELEGIR A LA VEZ ***

QUE4CAN:	;
CANAL_A:	ld	hl,(P_4)
	call	CHKCAN
	jr	c,CANAL_B
	ld	de,(P_8)
	call	NOTA2

CANAL_B:	ld	hl,(P_5)
	call	CHKCAN
	jr	c,CANAL_C
	ld	de,(P_9)
	call	NOTA2

CANAL_C:	ld	hl,(P_6)
	call	CHKCAN
	jr	c,CANAL_D
	ld	de,(P_10)
	call	NOTA2

CANAL_D:	ld	hl,(P_6)
	call	CHKCAN
	jr	c,CANAL_E
	ld	de,(P_11)
	call	NOTA2

CANAL_E:	jp	FIN

CHKCAN:	ld	a,h	;HL-1 -> BC y Cy=0 si canal<>0
	or	l	;Cy=1 si canal=0
	scf
	ret	z
	dec	hl
	push	hl
	pop	bc
	or	a
	ret

P_2:	;
P_3:	equ	P_2+2
P_4:	equ	P_3+2
P_5:	equ	P_4+2
P_6:	equ	P_5+2
P_7:	equ	P_6+2
P_8:	equ	P_7+2
P_9:	equ	P_8+2
P_10:	equ	P_9+2
P_11:	equ	P_10+2
SAVE_SP:	equ	P_11+2
