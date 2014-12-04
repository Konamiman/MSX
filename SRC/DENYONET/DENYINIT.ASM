;DenyoNet TCP/IP BIOS initializer 1.0
;By Konamiman, 2/2014

ENASLT:	equ	#0024
EXPTBL:	equ	#FCC1

_TERM0:	equ	#00
_CONOUT:	equ	#02
_STROUT:	equ	#09
_TERM:	equ	#62

BUFFER:	equ	#8000

DENY_ROM_ID:	equ	#4016
DENY_INIT:	equ	#4036

	org	#100

	;--- Get DenYoNet slot from command line

	ld	a,1
	ld	de,BUFFER
	call	EXTPAR
	jp	c,INFO_AND_END

	ld	a,(BUFFER)
	cp	"0"
	jp	c,INFO_AND_END
	cp	"3"+1
	jp	nc,INFO_AND_END
	sub	"0"
	ld	b,a

	ld	a,(BUFFER+1)
	or	a
	jr	z,OKSLOT
	cp	"-"
	jp	nz,INFO_AND_END
	ld	a,(BUFFER+3)
	or	a
	jp	nz,INFO_AND_END

	ld	a,(BUFFER+2)
	cp	"0"
	jp	c,INFO_AND_END
	cp	"3"+1
	jp	nc,INFO_AND_END
	sub	"0"
	rlca
	rlca
	and	%1100
	or	b
	or	%10000000
	ld	b,a
OKSLOT:
	ld	a,b

	;--- Switch the supplied slot and check if DenyoNet is present with proper BIOS

	push	af
	call	GETSLTP1
	ld	(OLDSLOT),a
	pop	af
	ld	h,#40
	call	ENASLT

	ld	hl,DENY_ID
	ld	de,DENY_ROM_ID
	ld	b,DENY_ID_END-DENY_ID
CHKID:	ld	a,(de)
	or	32	;Lower-casize it
	cp	(hl)
	jr	nz,WRONG_ID
	inc	de
	inc	hl
	djnz	CHKID
	jr	OK_ID

WRONG_ID:
	ld	de,NODENYO_S
	ld	c,_STROUT
	call	5
	ld	b,1
	jp	TERMINATE

OK_ID:
	ld	de,FOUND_S
	ld	c,_STROUT
	call	5

	ld	hl,DENY_ROM_ID
PRINT_ID:
	ld	a,(hl)
	or	a
	jr	z,PRINT_ID_OK
	push	hl
	ld	e,(hl)
	ld	c,_CONOUT
	call	5
	pop	hl
	inc	hl
	jr	PRINT_ID

PRINT_ID_OK:
	ld	de,TWO_CRLF_S
	ld	c,_STROUT
	call	5

	;--- Call initialization code in ROM, print appropriate message, terminate.

	call	DENY_INIT

	ld	de,INITOK_S
	jr	z,OK_ID2
	ld	de,ALRINIT_S
OK_ID2:	ld	c,_STROUT
	call	5

	ld	b,0
	jp	TERMINATE


INFO_AND_END:
	ld	de,INFO_S
	ld	c,_STROUT
	call	5
	ld	b,0


;--- Terminate program (with error code passed in B in DOS 2)

TERMINATE:
	push	bc
	ld	a,(OLDSLOT)
	ld	h,#40
	or	a
	call	nz,ENASLT
	pop	bc

	ld	c,_TERM
	call	5
	ld	c,_TERM0
	jp	5


;--- Get slot connected on page 1
;    Input:  -
;    Output: A = Slot number
;    Modifies: AF, HL, E, BC

GETSLTP1:
	in	a,(0A8h)
	rrca
	rrca
	and	3
	ld	c,a
	ld	b,0
	ld	hl,EXPTBL
	add	hl,bc
	ld	a,(hl)
	and	#80
	or	c
	ld	c,a
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	and	0Ch
	or	c
	bit	7,a
	ret	nz
	and	%11
	ret


;--- NAME: EXTPAR
;      Extracts a parameter from the command line
;    INPUT:     A  = Parameter to be extracted (the first one is 1)
;               DE = Buffer to store the parameter
;    OUTPUT:    A  = Number of existing parameters
;               CY = 1 -> That specified parameter does not exist
;                         B undefined, buffer unchanged
;               CY = 0 -> B = Parameter length (trailing 0 is not included)
;                         Parameter stored from DE, finished with 0
;    REGISTERS: -
;    CALLS:     -

EXTPAR:	or	a	;Returns error if A = 0
	scf
	ret	z

	ld	b,a
	ld	a,(#80)	;Returns error if there are no parameters
	or	a
	scf
	ret	z
	ld	a,b

	push	af,hl
	ld	a,(#80)
	ld	c,a	;Adds 0 at the end
	ld	b,0	;(required under DOS 1)
	ld	hl,#81
	add	hl,bc
	ld	(hl),0
	pop	hl,af

	push	hl,de,ix
	ld	ix,0	;IXl: Number of parameters    
	ld	ixh,a	;IXh: Parameter to be extracted
	ld	hl,#81

PASASPC:	ld	a,(hl)	;Skips spaces    
	or	a
	jr	z,ENDPNUM
	cp	" "
	inc	hl
	jr	z,PASASPC

	inc	ix
PASAPAR:	ld	a,(hl)	;Skips the parameter
	or	a
	jr	z,ENDPNUM
	cp	" "
	inc	hl
	jr	z,PASASPC
	jr	PASAPAR

ENDPNUM:	ld	a,ixh	;Error if the parameter number to be 
	dec	a	;exctracted
	cp	ixl	;is bigger than the total number of parameters
	jr	nc,EXTPERR
	;jrmy   EXTPERR

	ld	hl,#81
	ld	b,1	;B = current parameter
PASAP2:	ld	a,(hl)	;We skip spaces until the next    
	cp	" "	;parameter is found   
	inc	hl
	jr	z,PASAP2

	ld	a,ixh	;If it is the searched parameter we extract it    
	cp	b	;Otherwise ...    
	jr	z,PUTINDE0

	inc	B
PASAP3:	ld	a,(hl)	;... we skip it and go back to PAPAP2   
	cp	" "
	inc	hl
	jr	nz,PASAP3
	jr	PASAP2

PUTINDE0:	ld	b,0
	dec	hl
PUTINDE:	inc	b
	ld	a,(hl)
	cp	" "
	jr	z,ENDPUT
	or	a
	jr	z,ENDPUT
	ld	(de),a	;The parameter is stored starting from (DE)    
	inc	de
	inc	hl
	jr	PUTINDE

ENDPUT:	xor	a
	ld	(de),a
	dec	b

	ld	a,ixl
	or	a
	jr	FINEXTP
EXTPERR:	scf
FINEXTP:	pop	ix,de,hl
	ret

	;--- Variables and strings

OLDSLOT:	db	0

INFO_S:	db	"DenyoNet TCP/IP BIOS initializer 1.0",13,10
	db	"By Konamiman, 2/2014",13,10
	db	13,10
	db	"Usage: DENYINIT <DenyoNet slot>[-<subslot>]",13,10
	db	13,10
	db	"TCP/IP Unapi BIOS 0.6 or newer is required.",13,10
	db	"$"

NODENYO_S:
	db	"*** No suitable DenyoNet hardware found in the specified slot.",13,10
	db	13,10
	db	"Note that DenyoNet TCP/IP BIOS 0.6 or newer is required.",13,10
	db	"$"

DENY_ID:
	db	"denyonet tcp/ip bios "
DENY_ID_END:

INITOK_S:	db	"DenYoNet has been initialized successfully.",13,10,"$"
ALRINIT_S:	db	"DenyoNet was already initialized.",13,10,"$"
FOUND_S:	db	"Found: $"
TWO_CRLF_S:	db	13,10,13,10,"$"
