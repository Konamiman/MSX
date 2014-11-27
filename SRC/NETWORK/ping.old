	;--- Ping for the TCP/IP UNAPI 1.0
	;    By Konamiman, 4/2010
	;
	;    Usage: PING <dir. ip>
	;    Only one packet is sent at startup, more packets
	;    can be sent by pressing any key.


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

	;--- DOS functions and system variables

_TERM0:	equ	#00
_DIRIO:	equ	#06
_STROUT:	equ	#09

ENASLT:	equ	#0024
CALSLT:		equ	#001C

TPASLOT1:	equ	#F342
ARG:		equ	#F847
EXTBIO:		equ	#FFCA

	;--- TCP/IP UNAPI routines

TCPIP_GET_CAPAB:	equ	1
TCPIP_SEND_ECHO:	equ	4
TCPIP_RCV_ECHO:	equ	5
TCPIP_DNS_Q:	equ	6
TCPIP_DNS_S:	equ	7
TCPIP_WAIT:	equ	29

	;--- TCP/IP UNAPI error codes

ERR_OK:			equ	0
ERR_NOT_IMP:		equ	1
ERR_NO_NETWORK:		equ	2
ERR_NO_DATA:		equ	3
ERR_INV_PARAM:		equ	4
ERR_QUERY_EXISTS:	equ	5
ERR_INV_IP:		equ	6
ERR_NO_DNS:		equ	7
ERR_DNS:		equ	8
ERR_NO_FREE_CONN:	equ	9
ERR_CONN_EXISTS:	equ	10
ERR_NO_CONN:		equ	11
ERR_CONN_STATE:		equ	12
ERR_BUFFER:		equ	13
ERR_LARGE_DGRAM:	equ	14
ERR_INV_OPER:		equ	15

	endif


;******************************
;***                        ***
;***      MAIN PROGRAM      ***
;***                        ***
;******************************

	org	#100

;----------------------------
;---  Initial Checkings   ---
;----------------------------

	;--- Check if there are parameters. If not, print
	;    help and terminate.

	print	PRESEN_S

	ld	a,1	;Try to extract the first parameter
	ld	de,BUFER
	call	EXTPAR
	jr	nc,HAYPARS

TERMINFO:	print	INFO_S
	jp	TERMOK2

HAYPARS:	;

	;--- Search a TCP/IP UNAPI implementation

	ld	hl,TCPIP_S
	ld	de,ARG
	ld	bc,15
	ldir

	xor	a
	ld	b,0
	ld	de,#2222
	call	EXTBIO
	ld	a,b
	or	a
	jr	nz,OKINST

	print	NOTCPIP_S
	jp	TERMOK2
OKINST:	;

	ld	a,1
	ld	de,#2222
	call	EXTBIO

	;--- Setup the UNAPI calling code

	ld	(CALL_UNAPI+1),hl
	ld	c,a
	ld	a,h
	cp	#C0
	ld	a,c
	jr	c,NO_UNAPI_P3

	ld	a,#C9
	ld	(SET_UNAPI),a
	jr	OK_SET_UNAPI
NO_UNAPI_P3:

	ld	(UNAPI_SLOT+1),a
	ld	a,b
	cp	#FF
	jr	nz,NO_UNAPI_ROM

	ld	a,#C9
	ld	(UNAPI_SEG),a
	jr	OK_SET_UNAPI
NO_UNAPI_ROM:

	ld	(UNAPI_SEG+1),a
OK_SET_UNAPI:


	;--- Get mapper support routines in DOS 2 (we need GET_P1 and PUT_P1)

	ld	de,#0402
	xor	a
	call	EXTBIO
	or	a
	jr	z,NOMAPPER

	ld	bc,10*3	;Skip ALL_SEG to GET_P0
	add	hl,bc
	ld	de,PUT_P1
	ld	bc,2*3
	ldir

	call	GET_P1
	ld	(TPASEG1),a
NOMAPPER:

	;--- Check if this implementation can send PINGs

	call	SET_UNAPI
	ld	b,1
	ld	a,TCPIP_GET_CAPAB
	call	CALL_UNAPI
	bit	0,l
	jr	nz,CAN_SEND_PING

	print	NOPING_S
	jp	TERMOK
CAN_SEND_PING:

	;--- Get the host name from the command line
	;    and resolve it, saving the result in IP_REMOTE

	ld	a,1
	ld	de,BUFER
	call	EXTPAR

	print	RESOLVING_S

	call	SET_UNAPI
	ld	hl,BUFER
	ld	b,0
	ld	a,TCPIP_DNS_Q
	call	CALL_UNAPI

	ld	b,a
	ld	ix,DNSQERRS_T
	or	a
	jr	nz,DNSQR_ERR	;Did DNS_Q return error?

	;* Waits for the query to complete

DNSQ_WAIT:
	ld	a,TCPIP_WAIT
	call	CALL_UNAPI
	ld	b,1
	ld	a,TCPIP_DNS_S
	call	CALL_UNAPI

	;* Error?

	or	a
	ld	ix,DNSRERRS_T
	jr	nz,DNSQR_ERR

	;* Query finished? Show results and terminate

	ld	a,b
	cp	2
	jr	nz,DNSQ_WAIT	;Query not finished yet?

	;* Query completed? Store IP and continue

	ld	(IP_REMOTE),hl	;Saves the returned
	ld	(IP_REMOTE+2),de	;result in L.H.E.D

	ld	ix,RESOLVIP_S	;Displays the result
	ld	a,"$"
	call	IP_STRING
	print	RESOLVOK_S
	print	TWO_NL_S

	jp	RESOLV_END

	;- Common error routine for DNS_Q and DNS_S
	;  Input: IX=Errors Table, B=Error code

DNSQR_ERR:	push	ix,bc

	;* Prints "ERROR <code>: "

	ld	ix,RESOLVERRC_S
	ld	a,b
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

	;--- Clean the old echo reply packets (if there is any)

CLEANOLD:
	call	SET_UNAPI
	ld	a,TCPIP_RCV_ECHO
	ld	hl,PING_DATA2
	call	CALL_UNAPI
	or	a
	jr	z,CLEANOLD

	;--- Send the first echo packet

	print	PRESS_S
	call	SEND_PAQ
	jr	KEYOK

	;--- Waits for a key being pressed or for a packet being received

KEY:	call	SET_UNAPI
	ld	a,TCPIP_WAIT
	call	CALL_UNAPI
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

	call	SET_UNAPI
	ld	a,TCPIP_RCV_ECHO
	ld	hl,PING_DATA2
	call	CALL_UNAPI
	or	a
	jr	nz,KEY

	;--- A reply packet has been received: print its data

	ld	de,(PING_DATA2+7)	;Compose sequence number
	ld	hl,SEQR_S
	ld	b,1
	ld	a,%1000
	call	NUMTOASC

	ld	de,(PING_DATA2+4)	;Compose TTL
	ld	d,0
	ld	hl,TTL_S
	ld	b,1
	xor	a
	call	NUMTOASC

	print	RCV_S	;Print information
	print	ANDTTL_S
	call	SET_UNAPI
	jp	KEY	;Go back to the main loop

	;--- Packet sending routine

SEND_PAQ:	call	SET_UNAPI
	ld	hl,(SEQ)	;Sequence number = previous one + 1
	inc	hl
	ld	(SEQ),hl

	ld	a,TCPIP_SEND_ECHO
	ld	hl,PING_DATA
	call	CALL_UNAPI
	or	a
	jr	z,SEND_PAQ2

	print	NOCON_S	;only that the network connection is lost: finish
	jp	TERMOK

SEND_PAQ2:

	;* Display the sending information with the used sequence number

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

TERMOK:	
	ld	a,(TPASLOT1)
	ld	h,#40
	call	ENASLT

	ld	a,(TPASEG1)
	call	PUT_P1

	;* Jumps here if PUT_P1 has not been obtained yet

TERMOK2:	ld	c,_TERM0
	jp	5


;--- Segment switching routines for page 1,
;    these are overwritten with calls to
;    mapper support routines on DOS 2

PUT_P1:	out	(#FD),a
	ret
GET_P1:	in	a,(#FD)
	ret

TPASEG1:	db	2	;TPA segment on page 1


;--- IP_STRING: Converts an IP address to a string
;    Input: L.H.E.D = IP address
;           A = Termination character
;           IX = Address for the string

IP_STRING:
	push	af
	ld	a,l
	call	BYTE2ASC
	ld	(ix),"."
	inc	ix
	ld	a,h
	call	BYTE2ASC
	ld	(ix),"."
	inc	ix
	ld	a,e
	call	BYTE2ASC
	ld	(ix),"."
	inc	ix
	ld	a,d
	call	BYTE2ASC

	pop	af
	ld	(ix),a	;Termination character
	ret


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


;--- Code to switch TCP/IP implementation on page 1, if necessary

SET_UNAPI:
UNAPI_SLOT:	ld	a,0
	ld	h,#40
	call	ENASLT
	ei
UNAPI_SEG:	ld	a,0
	jp	PUT_P1


CALL_UNAPI:	jp	0


;--- This code allows calling a routine in a UNAPI implementation.
;    It is composed according to the TCP/IP implementation used.

;CALL_UNAPI:
;	ds	12



;****************************
;***                      ***
;***   DATA, VARIABLESS   ***
;***                      ***
;****************************

PING_DATA:
IP_REMOTE:	ds	4	;Host IP Address
	db	255	;TTL
	dw	0	;Identifier
SEQ:	dw	0	;Last ICMP sequence number used
	dw	64	;Data length

PING_DATA2:
	ds	12

;--- Strings

	;* Presentation

PRESEN_S:	db	27,"x5"	;Disables cursor
	db	13,10,"Ping for the TCP/IP UNAPI 1.0",13,10
	db	"By Konamiman, 4/2010",13,10,10,"$"
INFO_S:	db	"Use: PING <host name>",13,10,"$"

	;* Errors

NOCON_S:	db	"*** No network connection",13,10,"$"
NOTCPIP_S:	db	"*** No TCP/IP UNAPI implementation found.",13,10,"$"
NOPING_S:	db	"*** This TCP/IP UNAPI implementation does not support sending PINGs.",13,10,"$"

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
RESOLVERRC_S:	ds	6	;Space for "<code>: $"
RESOLVOK_S:	db	"OK: "
RESOLVIP_S:	ds	16	;Space for "xxx.xxx.xxx.xxx$"
TWO_NL_S:	db	13,10
ONE_NL_S:	db	13,10,"$"

	;* DNS_Q errors

DNSQERRS_T:	db	ERR_NO_NETWORK,"No network connection$"
	db	ERR_NO_DNS,"No DNS servers available$"
	db	ERR_NOT_IMP,"This TCP/IP UNAPI implementation does not support name resolution.",13,10
	db	"An IP address must be specified instead.$"
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

	;* UNAPI related

TCPIP_S:	db	"TCP/IP",0
