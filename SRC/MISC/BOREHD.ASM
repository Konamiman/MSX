	;*** BORE-HD: BOOT REGISTER FOR MSX WITH HARD DISK V1.0
	;By Konami Man, 12-95
	;NUMTOASC.ASC file must be included

DOSVER:	EQU	#6F	;DOS 2 function calls
CONOUT:	EQU	#02
STROUT:	EQU	#09
CHKCHR:	EQU	#5D
TERM:	EQU	#62
GDATE:	EQU	#2A
GTIME:	EQU	#2C
SDATE:	EQU	#2B
DEFER:	EQU	#64
DEFAB:	EQU	#63
OPEN:	EQU	#43
CLOSE:	EQU	#45
WRITE:	EQU	#49
SEEK:	EQU	#4A
GENV:	EQU	#6B
EXPLAIN:	EQU	#66
DIRIN:	EQU	#07

	org	#100

	;*** Check if DOS 2 is present, else exits

CHKIFDOS2:	ld	c,DOSVER
	call	5
	ret	nz
	ld	a,b
	cp	1
	jr	nc,ENDCHK
NODOS2:	ld	de,TITLE
	ld	c,STROUT
	push	bc
	call	5
	pop	bc
	ld	de,NODOS2STR
	ld	c,STROUT
	jp	5
NODOS2STR:	DB	"*** BORE-HD runs only under DOS 2.",13,10,"$"
ENDCHK:	xor	a
	ld	(FHANDLE),a
	ld	(PARAM),a

	;*** Upper casing of command line

TOMAY:	ld	a,(#80)
	or	a
	jr	z,SHOW	;If no parameters, shows info directly
	ld	ix,#81
	ld	d,0	;Conversion flags
BUCTOMAY:	ld	a,(ix)
	or	a
	jr	z,ENDTOMAY
	ld	e,a
	ld	c,CHKCHR
	call	5
	ld	(ix),e
	inc	ix
	jr	BUCTOMAY
ENDTOMAY:

	;*** Check if "/?" passed, then shows help and exits

CHKHLP:	ld	hl,#81
	ld	a,(#80)
	ld	c,a
	ld	b,a
	ld	a,"?"
	call	STRING
	ld	a,b
	or	a
	jp	nz,SHOWHLP

	;*** Check for "RESET" parameter

CHKRES:	ld	b,c
	xor	a
	ld	de,RESSTR
	call	STRING
	ld	a,b
	or	a
	jp	nz,RESET

	;*** Check for "BOOT" parameter

CHKBOOT:	ld	hl,#81
	ld	b,c
	xor	a
	ld	de,BOOTSTR
	call	STRING
	ld	a,b
	or	a
	jp	nz,BOOT

	;*** Check for "REF" parameter

CHKREF:	ld	hl,#81
	ld	b,c
	xor	a
	ld	de,REFSTR
	call	STRING
	ld	a,b
	or	a
	push	bc
	call	nz,REF
	pop	bc

	;*** Check for "NUM" parameter

CHKNUM:	ld	hl,#81
	ld	b,c
	xor	a
	ld	de,NUMSTR
	call	STRING
	ld	a,b
	or	a
	jp	nz,NUM

	;*** Shows info

SHOW:	ld	c,GDATE	;Update current date and time
	call	5
	ld	ix,FECHACT
	call	CONVDAT
	ld	c,GTIME
	call	5
	ld	de,HORACT
	call	CONVHOR

	ld	c,CONOUT	;Clear screen
	ld	e,#c
	call	5
	ld	de,TITLE	;Shows title
	ld	c,STROUT
	push	bc
	call	5
	ld	de,MENSAJE	;Shows info
	pop	bc
	call	5

CHKMODE:	ld	a,(PARAM)	;Shows running mode
	ld	de,MCONSSTR
	or	a
	jr	z,SHOWMODE
	ld	de,MRESSTR
	cp	1
	jr	z,SHOWMODE
	ld	de,MBOOTSTR
	cp	2
	jr	z,SHOWMODE
	ld	de,MACTSTR
SHOWMODE:	ld	c,STROUT
	call	5

	;*** Check for any invalid parameter, then
	;    register is not updated

CHKPARERR:	ld	a,(PARAM)
	or	a
	jp	z,ACABOSE	;End if no parameters
	and	%11000000
	or	a
	jr	z,OKPARAM	;No error if b7 and b6 of (PARAM) are 0
	ld	de,ERPSTR
	ld	c,STROUT
	push	af
	call	5
	pop	af
	ld	de,SOLOREF	;Shows invalid parameter(s)
	cp	%10000000
	jr	z,SHOWERPAR
	ld	de,SOLONUM
	cp	%01000000
	jr	z,SHOWERPAR
	ld	de,REFYNUM
SHOWERPAR:	ld	c,STROUT
	call	5
	ld	de,NOACTSTR
	ld	c,STROUT
	call	5
	jr	ACABOSE
OKPARAM:	;

	;*** Update register

ACTREG:	;
DEFINE:	ld	de,RUTERR	;Define disk error handling routine
	ld	c,DEFER
	call	5
	call	SHOWACT	;Messaje "Updating register"

OPENREG:	ld	hl,PROGSTR	;Get BOREHD name and path
	ld	de,RAMDDNAM
	ld	b,64
	ld	c,GENV
	call	5

	xor	a	;Open file
	ld	c,OPEN
	call	5
	push	bc

	xor	a	;Sets file pointer to data area
	ld	de,0
	ld	hl,MENSAJE-#100
	ld	c,SEEK
	call	5

	pop	bc	;Overwrite updated data zone
	push	bc	;in BOREHD file
	ld	de,MENSAJE
	ld	hl,ENDDAT-MENSAJE+1
	ld	c,WRITE
	call	5

	pop	bc	;Close file
	ld	c,CLOSE
	call	5

	call	LOCATE	;Message "Register updated"
	ld	de,RACTSTR
	ld	c,STROUT
	push	bc
	call	5
	pop	bc
	ld	de,BLANCO
	call	STROUT

ACABOSE:	ld	de,0
	ld	c,DEFER
	call	5
	ld	c,TERM
	ld	b,0
	jp	5

SHOWACT:	call	LOCATE
	ld	de,ACTSTR
	ld	c,STROUT
	push	bc
	call	5
	pop	bc
	ld	de,BLANCO
	call	5
	ret

ACTSTR:	db	"Updating register ...                                  "
	db	13,10,"$"
BLANCO:	ds	80,32
	db	"$"
RACTSTR:	db	"Register updated OK.                                   "
	db	13,10,13,10,"$"
ERRDSKSTR:	db	"Error: "
AQUIERR:	ds	67
OPTSTR:	db	"Retry or Cancel (R/C)? $"
SOLOREF:	db	" REF is invalid$"
SOLONUM:	db	" NUM is invalid$"
REFYNUM:	db	"s REF and NUM are invalid$"
FINSTR:	db	13,10,"$"
ABSTR:	db	"Register update cancelled.                        "
	db	13,10,"$"

	;*** Disk error handling routine

RUTERR:	push	af
	call	LOCATE
	ld	de,BLANCO
	ld	c,STROUT
	call	5
	call	LOCATE

	pop	af	;Obtains error message
	ld	b,a
	ld	de,AQUIERR
	ld	c,EXPLAIN
	call	5

	ld	hl,AQUIERR-1	;Puts 10,13,"$" at end of string
BUSFERR:	inc	hl
	ld	a,(hl)
	or	a
	jr	nz,BUSFERR
	ex	de,hl
	ld	hl,FINSTR
	ld	bc,3
	ldir
	ld	de,ERRDSKSTR	;Shows "Error: "+error string
	ld	c,STROUT
	push	bc
	call	5

	ld	de,OPTSTR	;Ask for Retry or Cancel
	pop	bc
	call	5
PREGUNTA:	ld	c,DIRIN
	call	5
	cp	"r"
	jr	z,RETRY
	cp	"R"
	jr	z,RETRY
	cp	"C"
	jr	z,ABORT
	cp	"c"
	jr	z,ABORT
	jr	PREGUNTA

RETRY:	call	SHOWACT	;Retry
	ld	a,2
	ret

ABORT:	call	LOCATE
	ld	de,ABSTR	;Cancel: exits to DOS
	ld	c,STROUT
	push	bc
	call	5
	ld	de,BLANCO
	pop	bc
	call	5
	ld	b,0
	ld	c,TERM
	jp	5

	;*** "?" found in parameters: shows help and exits

SHOWHLP:	ld	e,#c
	ld	c,CONOUT
	call	5
	ld	de,TITLE
	ld	c,STROUT
	push	bc
	call	5
	pop	bc
	ld	de,HELPSTR
	call	5
	ld	c,TERM
	ld	b,0
	jp	5

	;*** RESET: sets boots number to 1 and current date as ref. date

RESET:	ld	a,1
	ld	(BOOTS),A	;Boots number to 1
	xor	a	;---> NOT INCLUDED IN VERSION #1.0
	ld	(BOOTS+1),A	;---> (CAUSE OF RESET OPTION FAILURE)
	ld	ix,NUMARR
	ld	a," "
	ld	(ix),a
	ld	(ix+1),a
	ld	(ix+2),a
	ld	(ix+3),a
	ld	a,"1"
	ld	(ix+4),a

	ld	c,GDATE	;Sets all dates to current date
	call	5
	ld	ix,REFDAT
	call	CONVDAT
	ld	ix,ULTDAT
	call	CONVDAT
	ld	ix,ACTDAT
	call	CONVDAT
	ld	c,GTIME	;Sets all times as current time
	call	5
	ld	de,ULTHOR
	call	CONVHOR
	ld	de,ACTHOR
	call	CONVHOR

	ld	a,1
	ld	(PARAM),a	;PARAM=1 => RESET parameter found
	jp	SHOW

	;*** BOOT: Boots=boots+1,
	;          current boot date => last boot date,
	;          current date => current boot date

BOOT:	ld	de,(BOOTS)
	inc	de
	ld	(BOOTS),de	;DE = updated boots number
	ld	hl,NUMARR
	ld	bc,#0520
	ld	a,%00011000
	call	NUMTOASC

	ld	hl,ACTDAT	;Current boot => last boot
	ld	de,ULTDAT
	ld	bc,8
	ldir
	ld	hl,ACTHOR
	ld	de,ULTHOR
	ld	bc,5
	ldir

	ld	c,GDATE	;Current date => current boot
	call	5
	ld	ix,ACTDAT
	call	CONVDAT
	ld	c,GTIME
	call	5
	ld	de,ACTHOR
	call	CONVHOR

	ld	a,2
	ld	(PARAM),a	;PARAM=2 => BOOT parameter found
	jp	SHOW

	;*** REF: checks for REF:NOW

REF:	ld	b,5	;Pointer to string after REF
TRASREF:	inc	hl
	djnz	TRASREF

	xor	a
	ld	de,NOWSTR	;Check if NOW is placed immediately
	pop	ix,bc	;after "/REF:"
	push	bc,ix
	ld	b,c
	call	STRING
	ld	a,b
	cp	1
	jr	nz,REFNUM

REFNOW:	ld	c,GDATE	;Current date => reference date
	call	5
	ld	ix,REFDAT
	call	CONVDAT
	ld	a,4	;b2 of (PARAM)=1 => REF:NOW found
	ld	(PARAM),a
	ret

REFNUM:	ld	a,8
	ld	(PARAM),a	;b3 of (PARAM)=1 => REF:something found
	call	EXTNUM	;Gets day
	ld	a,d
	or	a
	jp	z,ERREF	;Error if day has 0 digits
	cp	3	;(that is, is not a number)
	jr	nc,ERREF	;Error if day has more than 2 digits
	ld	a,c
	ld	(TMPDIA),a	;If correct, stores day

	ld	a,e
	cp	"-"
	jr	nz,ERREF	;Error if "-" not found after day

	ld	c,d
	ld	b,0
	add	hl,bc
	inc	hl	;Pass to month
	call	EXTNUM	;Gets month
	ld	a,d
	or	a
	jr	z,ERREF	;Error if month has 0 digits
	cp	3	;(that is, is not a number)
	jr	nc,ERREF	;Error if month has more than 2 digits
	ld	a,c
	ld	(TMPMES),a	;If correct, stores month

	ld	a,e
	cp	"-"
	jr	nz,ERREF	;Error if "-" not found after month

	ld	c,d
	ld	b,0
	add	hl,bc
	inc	hl	;Pass to year
	call	EXTNUM	;Gets year
	ld	a,d
	or	a
	jr	z,ERREF	;Error if year has 0 digits
	cp	3	;(that is, is not a number)
	jr	nc,ERREF	;Error if year has more than 2 digits
	ld	a,c
	ld	(TMPAGNO),a

CHKDAT:	ld	c,GDATE	;Stores current datel
	call	5
	push	hl,de
	ld	a,(TMPMES)	;Stores year in HL, month in D, day in E.
	ld	d,a	;At this point, date has dd-mm-yy correct
	ld	a,(TMPDIA)	;form. Now this date will be set as current
	ld	e,a	;date with DOS function SET DATE. If error
	ld	bc,1900	;is returned, then date is not correct.
	ld	a,(TMPAGNO)
	ld	l,a
	ld	h,0
	cp	81
	jr	nc,MENOS2MIL
MAS2MIL:	ld	bc,2000
MENOS2MIL:	add	hl,bc	;Converts 2-digit year to 4-digit year
	ld	c,SDATE
	call	5	;A=#FF if date is not correct.
	pop	de,hl
	push	af
	ld	c,SDATE
	call	5	;Restores current date
	pop	af
	or	a
	jr	nz,ERREF

	ld	a,(TMPMES)	;Date is correct and will be copied into
	ld	d,a	;reference date field.
	ld	a,(TMPDIA)
	ld	e,a
	ld	a,(TMPAGNO)
	ld	l,a
	ld	h,0
	ld	ix,REFDAT
	call	CONVDAT
	ret		;Return, and check for NUM parameter

ERREF:	ld	a,(PARAM)
	or	128	;b7 of (PARAM)=1 => error in /REF param.
	ld	(PARAM),a
	ret		;Return, and check for NUM parameter
NOWSTR:	db	"NOW",0
TMPDIA:	ds	1
TMPMES:	ds	1
TMPAGNO:	ds	2

	;*** NUM: update boots number by adding/substracting/substituing
	;         current number to/from/with specified number

NUM:	ld	a,(PARAM)	;bit 4 of (PARAM)=1 => NUM found
	or	16
	ld	(PARAM),a

	ld	b,5	;Pointer after "/NUM:"
TRASNUM:	inc	hl
	djnz	TRASNUM

	ld	a,(hl)
	cp	"+"
	jr	z,INCNUM
	cp	"-"
	jr	z,DECNUM

SUSTNUM:	call	EXTNUM
	jr	c,ERRNUM	;Error if number is greatest than 65535
	or	a
	jr	nz,ERRNUM	;Error if number has more than 5 digits
	ld	a,d
	or	a
	jr	z,ERRNUM	;Error if number has 0 digits

	ld	(BOOTS),bc
	push	bc
	pop	de
	jr	ARRTONUM

INCNUM:	inc	hl	;Adds the number after "/NUM:"
	call	EXTNUM	;to boots number
	jr	c,ERRNUM
	or	a
	jr	nz,ERRNUM
	ld	hl,(BOOTS)
	add	hl,bc
	ex	de,hl
	jr	ARRTONUM

DECNUM:	inc	hl	;Substracts the number after "/NUM:"
	call	EXTNUM	;from boots number
	jr	c,ERRNUM
	or	a
	jr	nz,ERRNUM
	ld	hl,(BOOTS)
	sbc	hl,bc
	ex	de,hl

ARRTONUM:	ld	hl,NUMARR	;Update boots number field
	ld	bc,#0520
	ld	a,%00011000
	call	NUMTOASC
	jp	SHOW

ERRNUM:	ld	a,(PARAM)	;bit 6 of (PARAM)=1 => parameter after
	or	64	;/NUM: is not correct
	ld	(PARAM),a
	jp	SHOW

	;*** STRING function: checks if a string is into another
	;*** In:      HL = beginning of main string
	;             A  = 0 and DE = contained string+#00, or
	;             A  = contained character and DE ignored
	;             B  = lenght of main string and C ignored, or
	;             B  = 0 and C=termination character of main string
	;*** Out:     HL = beginning address of found string
	;             B  = beginning position of found string relative
	;                  to beginning of main string
	;                  (1st position has number 1, etc.)
	;             If contained string or character is not found
	;                into main string:
	;             HL = beginning of main string (preserved)
	;             B  = 0
	;             All other registers preserved
	;

STRING:	or	a
	ld	(CHARA),a
	push	af
	ld	a,c
	push	af,ix,de,hl
CHKIFA:	jr	z,NOCHAR
CHARENA:	ld	de,CHARA+1	;If character passed in A,
	xor	a	;copy it into internal buffer
	ld	(de),a	;and search as if a string was passed
	dec	de

NOCHAR:	ld	a,b
	or	a
	jr	nz,BNOCERO
BCERO:	push	hl
	ld	b,-1
BUSFIN:	inc	b	;If B=0, search termination character
	ld	a,(hl)	;and stores string lenght in B
	inc	hl
	cp	c
	jr	nz,BUSFIN
	pop	hl

BNOCERO:	dec	de	;While comparation between (HL) and (IX)
	push	de	;is positive, increases HL and IX
	inc	b
	dec	hl
	ld	c,0

COMPA:	inc	hl
	inc	de
	inc	c
	ld	a,(de)
	or	a
	jr	z,FOUND
	cp	(hl)
	call	nz,RESETDE
	djnz	COMPA
	jr	NOTF

RESETDE:	pop	ix
	pop	de
	push	de
	push	ix
	ld	a,1
	cp	c
	ld	c,0
	ret	z
	dec	hl
	inc	b
	ret

FOUND:	pop	de	;C=number of match characters+1
	dec	c
	ld	b,0
	or	a
	sbc	hl,bc	;HL=beginning of found string
	pop	de	;DE=beginning of original string
	push	hl	;(passed to subroutine in HL)
	sbc	hl,de
	ld	b,l	;L=position relative to beginning
	inc	b
ENDSTR:	pop	hl,de,ix,af
	ld	c,a
	pop	af
	ret

NOTF:	pop	de,hl
	ld	b,0
	push	hl
	jr	ENDSTR

	;*** EXTNUM function: extracts 5-digits ASCII number
	;*** In:       HL = beginning of ASCII string
	;*** Out:      CY-BC = 17-bit number
	;              D  = number of digits actually extracted
	;                   The subroutine ends when a no-numeric
	;                   character is found, or when 5 digits
	;                   are already extracted.
	;              E  = first invalid character, or 6th digit
	;              A  = error:
	;                   0 => no error
	;                   1 => number has more than 5 digits.
	;                        CY-BC contains number formed by
	;                        first 5 digits
	;              All other registers preserved
	;

EXTNUM:	push	hl,ix
	ld	ix,ACA
	res	0,(ix)
	set	1,(ix)
	ld	bc,0
	ld	de,0
BUSNUM:	ld	a,(hl)	;Jumps to FINEXT if character is not
	ld	e,a	;a number, or if is the 6th digit
	cp	"0"
	jr	c,FINEXT
	cp	"9"+1
	jr	nc,FINEXT
	ld	a,d
	cp	5
	jr	z,FINEXT
	call	POR10

SUMA:	push	hl	;BC = BC + A
	push	bc
	pop	hl
	ld	bc,0
	ld	a,e
	sub	"0"
	ld	c,a
	add	hl,bc
	call	c,BIT17
	push	hl
	pop	bc
	pop	hl

	inc	d
	inc	hl
	jr	BUSNUM

BIT17:	set	0,(ix)
	ret
ACA:	db	0	;b0: num>65535. b1: more than 5 digits

FINEXT:	ld	a,e
	cp	"0"
	call	c,NODESB
	cp	"9"+1
	call	nc,NODESB
	ld	a,(ix)
	pop	ix,hl
	srl	a
	ret

NODESB:	res	1,(ix)
	ret

POR10:	push	de,hl	;BC = BC * 10
	push	bc
	push	bc
	pop	hl
	pop	de
	ld	b,3
ROTA:	sla	l
	rl	h
	djnz	ROTA
	call	c,BIT17
	add	hl,de
	call	c,BIT17
	add	hl,de
	call	c,BIT17
	push	hl
	pop	bc
	pop	hl,de
	ret

	;*** CONVDAT function: converts a date gived by DOS function
	;    GET DATE (#2A) to an ASCII string in the form dd-mm-yy
	;    Uses subroutine NUMTOASC
	;*** In:      date in the format of GET DATE, that is
	;             HL = year, 1980..2079
	;             D  = month, 1..12 (january..december)
	;             E  = day, 1..31
	;             IX = buffer to put ASCII string
	;*** Out:     dd-mm-yy string in (IX)
	;             This subroutine don't check for invalid dates
	;             All registers preserved
	;

CONVDAT:	push	af,hl,bc,de,de
CONVAGNO:	ex	de,hl	;DE=year
	push	ix
	pop	hl
	inc	hl
	inc	hl
	inc	hl	;HL=buffer beginning+3
	inc	hl
	ld	b,4
	ld	a,%00011000
	call	NUMTOASC	;(HL)="xxxxYYYY"
	ld	a,"-"
	inc	hl
	ld	(hl),a	;(HL)="xxxxY-YY"

CONVMES:	pop	de
	push	de
	ld	e,d
	ld	d,0	;DE=month
	dec	hl
	dec	hl
	ld	bc,#0230
	ld	a,%00011000
	call	NUMTOASC	;(HL)="xxxMM-YY"
	dec	hl
	ld	a,"-"
	ld	(hl),a	;(HL)="xx-MM-YY"

CONVDIA:	pop	de
	ld	d,0	;DE=day
	dec	hl
	dec	hl
	ld	bc,#0230
	ld	a,%00011000
	call	NUMTOASC	;(HL)="DD-MM-YY"

	pop	de,bc,hl,af
	ret

	;*** CONVHOR function: convierts time gived by DOS function
	;    GET TIME (#2C) to an ASCII string in the form
	;    hh:mm, or h:mm
	;    Uses subroutine NUMTOASC
	;*** In:      hour in the format of GET DATE, that is
	;             H = hours
	;             L = minutes
	;             DE= buffer to put ASCII string
	;*** Out:     string in (DE)
	;             All registers preserved
	;

CONVHOR:	push	af,bc,hl,de,hl
	ex	de,hl	;HL=buffer, DE=hour
	ld	e,d
	ld	d,0
	ld	bc,#0220
	ld	a,%00011000
	push	af
	call	NUMTOASC	;(HL)="HHxxx"

	inc	hl
	inc	hl
	ld	a,":"
	ld	(hl),a	;(HL)="HH:xx"
	inc	hl
	pop	af
	pop	de
	ld	d,0
	ld	bc,#0230
	call	NUMTOASC	;(HL)="HH:MM"

	pop	de,hl,bc,af
	ret

	;*** LOCATE function: locate cursor at posicion 0,9
	;
LOCATE:	push	af,bc,de,hl
	ld	de,LOCSTR
	ld	c,STROUT
	call	5
	pop	hl,de,bc,af
	ret
LOCSTR:	db	#1B,"Y",#29,#20,"$"

CHARA:	ds	2
RESSTR:	db	"/RESET",0
BOOTSTR:	db	"/BOOT",0
NUMSTR:	db	"/NUM:",0
REFSTR:	db	"/REF:",0
PROGSTR:	db	"PROGRAM",0

	;*** Message + data area

TITLE:	db	"   BORE-HD v1.01: BOot REgister for MSX with Ha"
	db	"rd Disk - (j) Konami Man '95",13,10
	db	"   --------------------------------------------"
	db	"----------------------------",13,10,13,10,"$"
MENSAJE:	db	"Number of boots from  "
REFDAT:	ds	8,32
	db	" :    "
NUMARR:	ds	5,32
	db	"   |   Date:  "
FECHACT:	ds	8,32
	db	13,10,"Last boot was done in "
ULTDAT:	ds	8,32
	db	" at "
ULTHOR:	ds	5,32
	db	" h   |  -----------------",13,10
	db	"Current boot done in  "
ACTDAT:	ds	8,32
	db	" at "
ACTHOR:	ds	5,32
	db	" h   |   Time:  "
HORACT:	ds	5,32
	db	" h",13,10,13,10
	db	"Run mode: $"
MBOOTSTR:	db	"Booting system.",13,10,13,10,"$"
MRESSTR:	db	"Initializing register.",13,10,13,10,"$"
MCONSSTR:	db	"Consulting register. "
	db	"BOREHD /? shows options.",13,10,13,10,"$"
MACTSTR:	db	"Updating register.",13,10,13,10,"$"
ERPSTR:	db	"Error: parameter$"
NOACTSTR:	db	". Register not updated.",13,10,"$"
EXPERR:	ds	65,32
BOOTS:	dw	0
ENDDAT:	nop
HELPSTR:	db	#1b,"A  This program stores a register of how "
	db	"many times computer was booted from a   "

	db	"reference date, and also time and date o"
	db	"f last boot and current boot. Data are  "

	db	"stored in the own program file, which ca"
	db	"n be freely renamed.",13,10,13,10

	db	"  When executed without parameters, BORE"
	db	"HD just shows register data without any "

	db	"update. Available parameters are:",13,10,13,10

	db	"/RESET => Initializes register: sets cur"
	db	"rent date as reference date and sets    "

	db	"number of boots to one.",13,10,13,10

	db	"/BOOT  => Boot mode: increases boots num"
	db	"ber, copies date and time of Current Boo"

	db	"t field into Last Boot field, and curren"
	db	"t date and time into Current Boot field."

	db	"You must put BOREHD /BOOT command into A"
	db	"UTOEXEC.BAT of your HD for actually make"

	db	"a count of boots.",13,10,13,10

	db	"/REF:{NOW|<dd-mm-yy>} => Sets given date"
	db	"as reference date. With NOW sets current"

	db	"date as reference date.",13,10,13,10

	db	"/NUM:[+|-]<nnnnn> => Sets boots number t"
	db	"o <nnnnn>. With + or - adds or subtracts"

	db	"<nnnnn> to boots number. Maximum boots n"
	db	"umber is 65535.",13,10,"$"

FHANDLE:	ds	1
ERROR:	ds	1
PARAM:	ds	1
RAMDDNAM:	ds	1

NUMTOASC:	;Place NUMTOASC.ASC here!
