	;Key assignment changer for Mega-SCSI FD emulation
	;By Konami Man, 1997

	;When you use the multiple FD emulation feature of Mega-SCSI
	;you must use the numeric keyboard to indicate the new disk number
	;when emulating the disk change.

	;Executing this program the Mega-SCSI SRAM will be patched, so
	;you will be able to use the normal keyboard (0-9 and A-F keys)
	;for this purpose.

KEY:	equ	0	;1: Set numeric keyboard
	;                        ;0: Set normal keyboard

CHGKEY:	ld	a,(SLOT)	;Enable Mega-SCSI slot
	ld	h,#40
	call	#24

	ld	a,#81	;Enable SRAM page 1 for writing
	ld	(#6000),a

	if	KEY=1	;Set new key data
	ld	hl,NUMDAT
	else
	ld	hl,NORMKEY
	endif
	ld	de,#5FB0
	ld	bc,16
	ldir

	xor	a	;Restore SRAM page 0
	ld	(#6000),a

	ld	a,(#FCC1)	;Restore BASIC slot
	ld	h,#40
	jp	#24

;*** Numeric keyboard data

NUMDAT:	db	#39,#49,#59,#69,#79,#0A,#1A,#2A,#3A,#4A	;Numeric 0-9
	db	#7A,#6A,#19,#5A,#09,#29	;Numeric "." "," "+" "-" "*" "/"

;*** Normal keyboard data

NORMDAT:	db	#00,#10,#20,#30,#40,#50,#60,#70,#01,#11	;Normal 0-9
	db	#62,#72,#03,#13,#23,#33	;Normal A-F

;*** ---> Put here the Mega-SCSI slot <--- ***

SLOT:	db	1
