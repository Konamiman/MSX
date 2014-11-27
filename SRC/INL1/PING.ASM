	;--- Ping for InterNestor Lite 1.02
	;    By Konami Man, 12-2004
	;
	;    Usage: PING <dir. ip>
	;    It sends only one packet by default, but more packets
	;    can be sent by pressing any key.

	;    Translated to english by Francisco Alvarez


;******************************
;***                        ***
;***   MACROS, CONSTANTS    ***
;***                        ***
;******************************

BUFER:	equ	#3000	;Buffer to get parameters

	;--- Macro to print a string

print:	macro	@d
	ld	de,@d
	ld	c,_STROUT
	call	5
	endm

	;--- Macro to call a InterNestor Lite function.
	;
	;    Under DOS1 and after CALLing any DOS function the system
	;    restores the TPA segment in page 1. this does not happen
	;    under DOS2.
	;
	;    Using this macro we ensure that CALLs to INL will be
	;    always made correctly and TPA will be restored in page 1.

inl:	macro	@d
	push	af	;Connects the INL segment in page 1
	ld	a,(INL_SEG1)
	call	PUT_P1
	pop	af

	call	@d	;Calls to the INL function

	push	af	;Restores TPA in page 1
	ld	a,2
	call	PUT_P1
	pop	af
	endm

	;--- DOS functions

_TERM0:	equ	#00
_DIRIO:	equ	#06
_STROUT:	equ	#09

	;--- InterNestor Lite routines

IP_STRING:	equ	#4036	;Converts an IP into a string
SEND_ECHO:	equ	#4051	;Sends echo packet
RCV_ECHO:	equ	#4054	;Receives echo reply
DNS_Q:	equ	#405D	;Performs DNS request
DNS_S:	equ	#4060	;Obtains DNS request status
WAIT_INT:	equ	#4081	;Wait for the next timer interrupt


;******************************
;***                        ***
;***      MAIN PROGRAM      ***
;***                        ***
;******************************

	org	#100

;----------------------------
;---  Initial Checkings   ---
;----------------------------

	;--- Checks if there are parameters. If not, it prints
	;    help and finishes

	print	PRESEN_S

	ld	a,1	;Tries to extract the first parameter
	ld	de,BUFER
	call	EXTPAR
	jr	nc,HAYPARS

TERMINFO:	print	INFO_S
	jp	TERMOK2

HAYPARS:	;

	;--- Checks that InterNestor Lite is installed, if not, it
	;    displays an error and finishes

	xor	a
	ld	de,#2203
	call	#FFCA
	or	a
	jr	nz,OKINS

	print	NOINS_S
	jp	TERMOK2
OKINS:	;

	ld	a,b
	ld	(INL_SEG1),a
	;ld      a,c                    ;--- In this program we don't need
	;ld      (INL_SEG2),a           ;--- this information, it is enough
	;ld      (INL_P3DIR),hl         ;--- with the code segment number

	;--- Gets GET_P1 and PUT_P1 from INL jump area
	;    in page 3 (they have offset 15)

	ld	bc,15
	add	hl,bc
	ld	de,PUT_P1
	ld	bc,6
	ldir

	;--- Connects the INL segment in page 1
	;    (it is not necessary because the macro "inl" is used)

	;ld	a,(INL_SEG1)
	;call	PUT_P1

	;--- Gets the host name from the command line
	;    and resolves it, saving the result in IP_REMOTE

	ld	a,1
	ld	de,BUFER
	call	EXTPAR

	print	RESOLVING_S

	ld	hl,BUFER
	xor	a
	inl	DNS_Q	;Queries the DNS server

	ld	b,a
	ld	ix,DNSQERRS_T
	jr	c,DNSQR_ERR	;Did DNS_Q return error?

	;* Waits for the query to complete

DNSQ_WAIT:	inl	WAIT_INT
	ld	a,1
	inl	DNS_S	;Gets the current state of the query

	;* Error?

	ld	b,a
	cp	3
	ld	ix,DNSRERRS_T
	jr	z,DNSQR_ERR

	;* Does the query continue? Then go back to the waiting loop

	cp	2
	jr	nz,DNSQ_WAIT	;The query hasn't finished yet?

	;* Query completed? Show the result and continue

	ld	(IP_REMOTE),hl	;Saves the returned
	ld	(IP_REMOTE+2),de	;result in L.H.E.D

	ld	ix,RESOLVIP_S	;Shows the result
	ld	a,"$"
	inl	IP_STRING

	print	RESOLVOK_S
	print	TWO_NL_S
	jp	RESOLV_END	;Continues

	;- Common error routine for DNS_Q and DNS_S
	;  Input: IX=Errors Table, B=Error code

DNSQR_ERR:	push	ix,bc

	;* Prints "ERROR <code>: "

	ld	ix,RESOLVERRC_S
	call	BYTE2ASC
	ld	(ix),":"
	ld	(ix+1)," "
	ld	(ix+2),"$"
	print	RESOLVERR_S

	;* Gets the error string, prints it and finishes

	pop	bc,de
	call	GET_STRING
	ld	c,_STROUT
	call	5

	jp	TERMOK
RESOLV_END:	;

	;--- Cleans the old echo reply packets (if there is any)

CLEANOLD:	inl	RCV_ECHO
	jr	nc,CLEANOLD

	;--- Sends the first echo packet

	print	PRESS_S
	call	SEND_PAQ
	jr	KEYOK

	;--- Waits for a key being pressed or for a packet being received

KEY:	inl	WAIT_INT
	ld	e,#FF
	ld	c,_DIRIO
	call	5
	or	a
	jr	z,KEYOK	;Nothing has been pressed
	cp	13
	jp	nz,TERMOK	;Another key: finishes
	call	SEND_PAQ	;Enter: sends an echo packet
KEYOK:	;

	;Gets an answer packet, or otherwise repeat the loop

	inl	RCV_ECHO
	jr	c,KEY

	;--- A reply packet has been received: print its data

	push	af,iy
	pop	de	;Composes sequence number
	ld	hl,SEQR_S
	ld	b,1
	ld	a,%1000
	call	NUMTOASC

	pop	af
	ld	e,a	;Composes TTL
	ld	d,0
	ld	hl,TTL_S
	ld	b,1
	xor	a
	call	NUMTOASC

	print	RCV_S	;Prints information
	print	ANDTTL_S
	jp	KEY	;Go back to the main loop

	;--- Packet sending routine

SEND_PAQ:	;push    af
	;call    _SEND_PAQ
	;pop     af
	;ret

	;* Composes the packet

_SEND_PAQ:	ld	hl,(IP_REMOTE)
	ld	de,(IP_REMOTE+2)
	ld	ix,0
	ld	iy,(SEQ)	;Sequence number = previous one + 1
	inc	iy
	ld	(SEQ),iy
	ld	bc,-1	;Data Size = defined default size
	ld	a,255	;TTL = 255

	inl	SEND_ECHO
	jr	nc,SEND_PAQ2

	pop	af,af,af	;If there is any error it may be
	print	NOCON_S	;only that the network connection is lost: finish
	jp	TERMOK

SEND_PAQ2:	;

	;* Prints the sending information with the used sequence number

	ld	de,(SEQ)
	ld	hl,SEQS_S
	ld	b,1
	xor	a
	call	NUMTOASC
	print	SENT_S

	ret


;******************************
;***                        ***
;***   AUXILIARY ROUTINES   ***
;***                        ***
;******************************

;--- NAME: COMP
;      Compares HL and DE (16 bits unsigned)
;    INPUT:    HL, DE = numbers to compare
;    OUTPUT:    C, NZ if HL > DE
;               C,  Z if HL = DE
;              NC, NZ if HL < DE

COMP:	call	_COMP
	ccf
	ret

_COMP:	ld	a,h
	sub	d
	ret	nz
	ld	a,l
	sub	e
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

;--- Program termination

TERMOK:	ld	a,2
	call	PUT_P1

	;* Jumps here if PUT_P1 has not been obtained yet

TERMOK2:	ld	c,_TERM0
	jp	5


;--- Segment switching routine for page 1. If it is obtained from the
;    INL jump area in page 3, so there is no need to worry about
;    the DOS version beign used.

PUT_P1:	ds	3
GET_P1:	ds	3


;--- NAME: NUMTOASC
;      16 bits integer to characters string conversion
;    INPUT:      DE = Number to be converted to
;                HL = Buffer to store the string
;                B  = Total number of string characters without
;                     including end symbols
;                C  = Filling character
;                     The number is justified to the right, and the exceeded
;                     spaces are filled in with (C) character.
;                     If the resultant number has more characters than the
;                     number that B shows, this register is ignored and the
;                     string fills just the necessary characters.
;                     The ending character is not counted, "$" or 00,
;                     talking about length.
;                 A = &B ZPRFFTTT
;                     TTT = Resultant number format
;                            0: decimal
;                            1: hexadecimal
;                            2: hexadecimal, starting with "&H"
;                            3: hexadecimal, starting with "#"
;                            4: hexadecimal, finishing with "H"
;                            5: binary
;                            6: binary, starting with "&B"
;                            7: binary, finishing with "B"
;                     R   = Number Range
;                            0: 0..65535 (Unsigned integer)
;                            1: -32768..32767 (2's complement integer)
;                               If the output format is binary, the
;                               number is interpreted as 8 bits integer
;                               and its range is 0..255. So, R bit and
;                               D register are ignored.
;                     FF  = String ending type
;                            0: Without special ending
;                            1: Character "$" added
;                            2: Character 00 added
;                            3: 7th bit of last character is set to 1
;                     P   = Sign "+"
;                            0: Sign "+" is not added to positive numbers
;                            1: Sign "+" added to positive numbers
;                     Z   = Exceeded spaces
;                            0: Taking zeros out from the left
;                            1: Not taking zeros out from the left
;    OUTPUT:    String starting from (HL)
;               B = Characters number of the string formed by the number
;                   (including the sign) and the type indicator
;                   (if they are generated)
;               C = Total characters number of the string
;                   without counting "$" or 00 if they are generated
;    REGISTERS: -
;    CALLS:     -
;    VARS:      -

NUMTOASC:	push	af,ix,de,hl
	ld	ix,WorkNTOA
	push	af,af
	and	%00000111
	ld	(ix+0),a	;Type 
	pop	af
	and	%00011000
	rrca
	rrca
	rrca
	ld	(ix+1),a	;End
	pop	af
	and	%11100000
	rlca
	rlca
	rlca
	ld	(ix+6),a	;Flags: Z(zero), P(sign +), R(range) 
	ld	(ix+2),b	;Ending characters number
	ld	(ix+3),c	;Filling character
	xor	a
	ld	(ix+4),a	;Total length
	ld	(ix+5),a	;Number length
	ld	a,10
	ld	(ix+7),a	;Divisor = 10 
	ld	(ix+13),l	;Buffer sent by user 
	ld	(ix+14),h
	ld	hl,BufNTOA
	ld	(ix+10),l	;Routine buffer
	ld	(ix+11),h

ChkTipo:	ld	a,(ix+0)	;Divisor = 2 or = 16, or it keeps = 10
	or	a
	jr	z,ChkBoH
	cp	5
	jp	nc,EsBin
EsHexa:	ld	a,16
	jr	GTipo
EsBin:	ld	a,2
	ld	d,0
	res	0,(ix+6)	;If it is binary then it is between 0 and 255 
GTipo:	ld	(ix+7),a

ChkBoH:	ld	a,(ix+0)	;Checks if "H" or "B" has to be added
	cp	7	;at the end
	jp	z,PonB
	cp	4
	jr	nz,ChkTip2
PonH:	ld	a,"H"
	jr	PonHoB
PonB:	ld	a,"B"
PonHoB:	ld	(hl),a
	inc	hl
	inc	(ix+4)
	inc	(ix+5)

ChkTip2:	ld	a,d	;If the number is 0 the sign is never added
	or	e
	jr	z,NoSgn
	bit	0,(ix+6)	;Checks the range
	jr	z,SgnPos
ChkSgn:	bit	7,d
	jr	z,SgnPos
SgnNeg:	push	hl	;Negates the number
	ld	hl,0	;Sign=0:without sign; 1:+; 2:-   
	xor	a
	sbc	hl,de
	ex	de,hl
	pop	hl
	ld	a,2
	jr	FinSgn
SgnPos:	bit	1,(ix+6)
	jr	z,NoSgn
	ld	a,1
	jr	FinSgn
NoSgn:	xor	a
FinSgn:	ld	(ix+12),a

ChkDoH:	ld	b,4
	xor	a
	cp	(ix+0)
	jp	z,EsDec
	ld	a,4
	cp	(ix+0)
	jp	nc,EsHexa2
EsBin2:	ld	b,8
	jr	EsHexa2
EsDec:	ld	b,5

EsHexa2:	push	de
Divide:	push	bc,hl	;DE/(IX+7)=DE, remainder A 
	ld	a,d
	ld	c,e
	ld	d,0
	ld	e,(ix+7)
	ld	hl,0
	ld	b,16
BucDiv:	rl	c
	rla
	adc	hl,hl
	sbc	hl,de
	jr	nc,$+3
	add	hl,de
	ccf
	djnz	BucDiv
	rl	c
	rla
	ld	d,a
	ld	e,c
	ld	a,l
	pop	hl,bc

ChkRest9:	cp	10	;Remainder to character conversion
	jp	nc,EsMay9
EsMen9:	add	a,"0"
	jr	PonEnBuf
EsMay9:	sub	10
	add	a,"A"

PonEnBuf:	ld	(hl),a	;Character is stored in buffer
	inc	hl
	inc	(ix+4)
	inc	(ix+5)
	djnz	Divide
	pop	de

ChkECros:	bit	2,(ix+6)	;Checks if zeros have to be erased
	jr	nz,ChkAmp
	dec	hl
	ld	b,(ix+5)
	dec	b	;B=Digits number to be checked
Chk1Cro:	ld	a,(hl)
	cp	"0"
	jr	nz,FinECeros
	dec	hl
	dec	(ix+4)
	dec	(ix+5)
	djnz	Chk1Cro
FinECeros:	inc	hl

ChkAmp:	ld	a,(ix+0)	;Adds "#", "&H" or "&B" if it is necessary
	cp	2
	jr	z,PonAmpH
	cp	3
	jr	z,PonAlm
	cp	6
	jr	nz,PonSgn
PonAmpB:	ld	a,"B"
	jr	PonAmpHB
PonAlm:	ld	a,"#"
	ld	(hl),a
	inc	hl
	inc	(ix+4)
	inc	(ix+5)
	jr	PonSgn
PonAmpH:	ld	a,"H"
PonAmpHB:	ld	(hl),a
	inc	hl
	ld	a,"&"
	ld	(hl),a
	inc	hl
	inc	(ix+4)
	inc	(ix+4)
	inc	(ix+5)
	inc	(ix+5)

PonSgn:	ld	a,(ix+12)	;The sign is set
	or	a
	jr	z,ChkLon
SgnTipo:	cp	1
	jr	nz,PonNeg
PonPos:	ld	a,"+"
	jr	PonPoN
	jr	ChkLon
PonNeg:	ld	a,"-"
PonPoN	ld	(hl),a
	inc	hl
	inc	(ix+4)
	inc	(ix+5)

ChkLon:	ld	a,(ix+2)	;Filling characters are added if necessary
	cp	(ix+4)
	jp	c,Invert
	jr	z,Invert
PonCars:	sub	(ix+4)
	ld	b,a
	ld	a,(ix+3)
Pon1Car:	ld	(hl),a
	inc	hl
	inc	(ix+4)
	djnz	Pon1Car

Invert:	ld	l,(ix+10)
	ld	h,(ix+11)
	xor	a	;Reverts the string
	push	hl
	ld	(ix+8),a
	ld	a,(ix+4)
	dec	a
	ld	e,a
	ld	d,0
	add	hl,de
	ex	de,hl
	pop	hl	;HL=starting buffer, DE=ending buffer
	ld	a,(ix+4)
	srl	a
	ld	b,a
BucInv:	push	bc
	ld	a,(de)
	ld	b,(hl)
	ex	de,hl
	ld	(de),a
	ld	(hl),b
	ex	de,hl
	inc	hl
	dec	de
	pop	bc
	ld	a,b	;***
	or	a	;*** It was needed!
	jr	z,ToBufUs	;***
	djnz	BucInv
ToBufUs:	ld	l,(ix+10)
	ld	h,(ix+11)
	ld	e,(ix+13)
	ld	d,(ix+14)
	ld	c,(ix+4)
	ld	b,0
	ldir
	ex	de,hl

ChkFin1:	ld	a,(ix+1)	;Checks if it has to be ended
	and	%00000111		;with "$" or 0
	or	a
	jr	z,Fin
	cp	1
	jr	z,PonDolar
	cp	2
	jr	z,PonChr0

PonBit7:	dec	hl
	ld	a,(hl)
	or	%10000000
	ld	(hl),a
	jr	Fin

PonChr0:	xor	a
	jr	PonDo0
PonDolar:	ld	a,"$"
PonDo0:	ld	(hl),a
	inc	(ix+4)

Fin:	ld	b,(ix+5)
	ld	c,(ix+4)
	pop	hl,de,ix,af
	ret

WorkNTOA:	defs	16
BufNTOA:	ds	10


;--- BYTE2ASC: Converts number A into a string without termination char
;    It stores the string in (IX) and modifies IX to point after the end
;    of the string.
;    Modifies: C

BYTE2ASC:	cp	10
	jr	c,B2A_1D
	cp	100
	jr	c,B2A_2D
	cp	200
	jr	c,B2A_1XX
	jr	B2A_2XX

	;--- One digit

B2A_1D:	add	"0"
	ld	(ix),a
	inc	ix
	ret

	;--- Two digits

B2A_2D:	ld	c,"0"
B2A_2D2:	inc	c
	sub	10
	cp	10
	jr	nc,B2A_2D2

	ld	(ix),c
	inc	ix
	jr	B2A_1D

	;--- Between 100 and 199

B2A_1XX:	ld	(ix),"1"
	sub	100
B2A_XXX:	inc	ix
	cp	10
	jr	nc,B2A_2D	;If it is 1XY with X>0
	ld	(ix),"0"	;If it is 10Y
	inc	ix
	jr	B2A_1D

	;--- Between 200 and 255

B2A_2XX:	ld	(ix),"2"
	sub	200
	jr	B2A_XXX


;--- GET_STRING: Returns a string related to a number or "Unknown".
;    Input:   DE = Pointer to the string and numbers table with the format:
;                  db num,"String$"
;                  db num2,"String2$"
;                  ...
;                  db 0
;             B = Related number
;    Output:  DE = String pointer

GET_STRING:	ld	a,(de)
	inc	de
	or	a	;The code is not found: "Unknown" is returned
	jr	nz,LOOP_REA2
	ld	de,UNK_S
	ret

LOOP_REA2:	cp	b	;Does it match?
	ret	z

LOOP_REA3:	ld	a,(de)	;No: Go to the next
	inc	de
	cp	"$"
	jr	nz,LOOP_REA3
	jr	GET_STRING

UNK_S:	db	"Unknown$"


;****************************
;***                      ***
;***   DATA, VARIABLESS   ***
;***                      ***
;****************************

INL_SEG1:	db	0
;INL_SEG2:       db      0      ;--- Not needed
;INL_P3DIR:      dw      0      ;--- in this program
IP_REMOTE:	ds	4	;Host IP Address
SEQ:	dw	0	;Last ICMP sequence number used

;--- Strings

	;* Presentation

PRESEN_S:	db	27,"x5"	;Disables cursor
	db	13,10,"Ping for InterNestor Lite 1.02",13,10
	db	"By Konami Man, 12-2004",13,10,10,"$"
INFO_S:	db	"Use: PING <host name>",13,10,"$"

	;* Errors

NOINS_S:	db	"ERROR: InterNestor Lite is not installed",13,10,"$"
INVIP_S:	db	"ERROR: Invalid IP address. Must be xxx.xxx.xxx.xxx, with 0<=xxx<=255",13,10,"$"
NOCON_S:	db	"ERROR: No network connection",13,10,"$"

	;* Information

PRESS_S:	db	"*** Press ENTER to send additional echo requests",13,10
	db	"*** Press any other key to exit",13,10,10,"$"
SENT_S:	db	"- Sent echo request with sequence number "
SEQS_S:	db	"     ",13,10,"$"
RCV_S:	db	"! Received echo reply with sequence number "
SEQR_S:	db	"     $"
ANDTTL_S:	db	" and TTL="
TTL_S:	db	"     ",13,10,"$"

	;* DNS resolution

RESOLVING_S:	db	"Resolving host name... $"
RESOLVERR_S:	db	13,10,"ERROR "
RESOLVERRC_S:	ds	6	;Lets space for "<code>: $"
RESOLVOK_S:	db	"OK: "
RESOLVIP_S:	ds	16	;Space for "xxx.xxx.xxx.xxx$"
TWO_NL_S:	db	13,10,10,"$"

	;* DNS_Q errors

DNSQERRS_T:	db	1,"Not connected to Internet$"
	db	4,"No DNS servers available$"
	db	0

	;* DNS_S errors

DNSRERRS_T:	db	1,"Query format error$"
	db	2,"Server failure$"
	db	3,"Name error (this host name does not exist)$"
	db	4,"Query type not implemented by the server$"
	db	5,"Query refused by the server$"
	db	16,"Server(s) not responding to queries$"
	db	17,"Total operation timeout expired$"
	db	19,"Internet connection lost$"
	db	20,"Dead-end reply (not containing answers nor redirections)$"
	db	21,"Truncated reply$"
	db	0
