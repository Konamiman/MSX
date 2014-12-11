	;Mega-SCSI patch for 60Hz boot
	;By Konami Man, 1997

	;Executing this program you will patch the beginning of the
	;Mega-SCSI's boot program, so the computer will automatically
	;boot in 60Hz mode. 50Hz boot will then be available
	;by pressing the "H" key while booting.


	org	#A000

BOOT60:	ld	a,(SLOT)	;Enable Mega-SCSI slot
	ld	h,#40
	call	#24

	ld	a,#80	;Enable SRAM page 0 for writing
	ld	(#6000),a

	ld	hl,PATCH	;Patching!
	ld	de,#4092
	ld	bc,FPATCH-PATCH
	ldir

	xor	a	;Restore SRAM page 0 
	ld	(#6000),a

	ld	a,(#FCC1)	;Restore BASIC slot 
	ld	h,#40
	jp	#24

;*** Patch data ***

PATCH:	xor	a
	ld	(#6000),a
	inc	a
	ld	(#6800),a
	push	af
	ld	a,3
	call	#141
	bit	5,a
	ld	a,(#FFE8)
	res	1,a
	jr	nz,KEY	;Check if "H" is pressed
	set	1,a
KEY:	ld	(#FFE8),a
	out	(#99),a
	ld	a,#89
	out	(#99),a
	pop	af
	jp	#7000
FPATCH:	;

;*** ---> Put here the Mega-SCSI slot <--- ***

SLOT:	db	1
