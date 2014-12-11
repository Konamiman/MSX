; A test program that will eject the media on a removable SCSI device

;=============================================

;Prueba de extraer el zipketekete, gracias

	org	#100

START:	ld	a,#c0
	ld	hl,datos
	ld	ix,#7fcc
	ld	iy,(#f347)
	call	#1c
	ld	a,(status)
	and	%11111110
	cp	2
	jr	z,START
	or	a
	ret	z
	ld	de,errstr
	ld	c,9
	jp	5

datos:	db	%00100000,0
	dw	comando
	dw	data
	dw	status
	dw	message

;comando:   db      #1b,0,0,0,%10,0 ;Extraccion
;comando:   db      #00,0,0,0,0,0    ;Test ready
comando:	db	#03,0,0,0,100,0	;Request sense
;comando:   db      #3C,%10,0,0,0,0,0,#40,#00,0 ;Read buffer
;comando:   db      #1D,%10100,0,0,0,0          ;Self-test
;comando:   db      #1D,%10000,0,0,4,0          ;Send diagnostic
;comando:   db      #1C,0,0,#10,#00,0           ;Receive diagnostic
data:	equ	#1008
status:	equ	#1000
message:	equ	#3000

errstr:	db	"Error!",13,10,"$"

	org	#1008
	db	0,0,0,0
