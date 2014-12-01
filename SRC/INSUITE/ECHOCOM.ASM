; This tool just sends a string to the serial port.

; ===========================

	;--- ECHOCOM: Envia una cadena al puerto serie

	org	#100

	ld	a,(#80)
	or	a
	jr	nz,OKPAR

	ld	de,USE_S
	ld	c,9
	call	5
	ret
OKPAR:	;

	call	GetFossil
	jr	z,OKFOS

	ld	de,NOFOS_S
	ld	c,9
	call	5
	ret
OKFOS:	;

	call	F_Init
	ld	a,(#80)
	dec	a
	ld	hl,#82
	ld	b,a
BUC:	push	hl,bc
	ld	a,(hl)
	call	F_RS_Out
	pop	bc,hl
	inc	hl
	djnz	BUC

	ld	a,13
	call	F_RS_Out
	ld	a,10
	call	F_RS_Out
	ret

NOFOS_S:	db	"*** ERROR: Fossil driver not installed.",13,10,"$"

USE_S:	db	"ECHOCOM - Sens a string to the serial port. Requires FOSSIL driver.",13,10
	db	"By Konami Man, 3-7-2001",13,10,10
	db	"Use: ECHOCOM string",13,10,"$"

;
; RS232 recognize/caller routine
;
; (p) 1993,1994 Erik Maas
;
; made to use with GEN80 macro assembler from HiSoft's DevPack80 v2.03

; To use this library, first you have to call GetFossil, this routine will
; check whether the fossil is available or not, if it is available, then it
; will adjust the jump table, so you can use this table.
; The return flags of GetFossil can tell you whether the fossil was found or
; not. Z  means the Fossil was found and installed
;      NZ means the Fossil was not found, and therefore NOT installed
;         (so be wise, return to DOS or whatever, do not use the routines)

; The fossil has it marks at the cassette parameter table, I do not believe
; any MSX 2 or turbo-R will use it anymore.... (??????)

; F3FC: "R"     mark 1
; F3FD: "S"     mark 2
; F3FE: LSB     LSB of addres to jump table of fossil driver
; F3FF: MSB     MSB of addres to jump table of fossil driver

GetFossil	ld	a,(#f3fc)	; get first mark of fossil
	cp	"R"	; is it the right one?
	ret	nz	; return if not with NZ flags
	ld	a,(#f3fd)	; get second mark of fossil
	cp	"S"	; is it the right one?
	ret	nz	; return if not with NZ flags

	; now we know the Fossil is installed, just get the addres
	; of the jump table now, and connect it to the program

	ld	hl,(#f3fe)	; get addres of jump table
	ld	de,F_GetVersion	; point to my own table
	ld	bc,21*3	; number of entry's at this moment
	ldir		; make a copy of the table
	call	F_GetVersion
	xor	a	; set Z flags
	ret		; and return to caller

;
; Jump Table to use in ML
;
; This table will be filled in by the GetFossil routine, after that you can
; simply call these addresses in the table
;

F_GetVersion	jp	0	; 0
F_Init	jp	0	; 1
F_DeInit	jp	0	; 2
F_SetBaud	jp	0	; 3
F_Protocol	jp	0	; 4
F_Channel	jp	0	; 5
F_RS_In	jp	0	; 6
F_RS_Out	jp	0	; 7
F_RS_In_Stat	jp	0	; 8
F_RS_Out_Stat	jp	0	; 9
F_DTR	jp	0	; 10
F_RTS	jp	0	; 11
F_Carrier	jp	0	; 12
F_Chars_In_Buf	jp	0	; 13
F_Size_Of_Buf	jp	0	; 14
F_Flush_Buf	jp	0	; 15
F_Fastint	jp	0	; 16
F_Hook38Stat	jp	0	; 17
F_Chput_Hook	jp	0	; 18
F_Keyb_Hook	jp	0	; 19
F_Get_Info	jp	0	; 20


