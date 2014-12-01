	;--- TCP console 0.1
	;    For use with InterNestor Suite beta 3
	;    By Konami Man, 2-2002
	;    Use: TCPCON <host name>|<IP address> <remote port> [<local port>] [P]
	;         Append P to open connection in passive mode

	;Note that this is NOT a telnet client, since no
	;special characters being part of the telnet specification
	;are supported (received data is printed raw in the screen,
	;and input data is sent raw to the TCP connection).

	;However it can actually connect to any telnet server
	;(specify 23 as remote port), just ignore the crap which will
	;eventually appear on your screen at options negotiation time.
	;It works fine with SMTP and POP3 servers.

	.label	20

;*****************************
;***                       ***
;***   MACROS, CONSTANTS   ***
;***                       ***
;*****************************

OPEN_ECHO:	equ	0

DOS:	equ	5	;DOS functions call entry

nesman:	macro	@f	;Indirect call to NestorMan functions
	ld	c,@f
	ld	de,#2202
	call	#FFCA
	endm

print:	macro	@d	;Prints a string
	ld	de,@d
	ld	c,_STROUT
	call	5
	endm

_CONOUT:	equ	#02	;Some DOS function calls
_DIRIO:	equ	#06
_STROUT:	equ	#09
_BUFIN:	equ	#0A
_CONST:	equ	#0B
_TERM:	equ	#62
_DEFAB:	equ	#63

ENASLT:	equ	#0024	;Slot swithcing BIOS routine

	;--- Level 4 module (TCP) calls

TCP_OPEN:	equ	#8021	;Open a connection
TCP_CLOSE:	equ	#8024	;Close a connection
TCP_ABORT:	equ	#8027	;Abort a connection
TCP_SEND:	equ	#802A	;Send data
TCP_RCV:	equ	#802D	;Receive data
TCP_STATUS:	equ	#8030	;Get connection status
TCP_FLUSH_OUT:	equ	#8033	;Flush outgoing data queue

	;--- IP calls (for revolver)

IP_DNS_Q:	equ	#802A	;Resolver query
IP_DNS_S:	equ	#802D	;Get response/status

; Conditional relative jumps

jri:	macro	@a	;A = x
	jr	z,@a
	endm

jrni:	macro	@a	;A <> x
	jr	nz,@a
	endm

jrmn:	macro	@a	;A < x
	jr	c,@a
	endm

jrmy:	macro	@a	;A > x
	jr	z,$+4
	jr	nc,@a
	endm

jrmni:	macro	@a	;A <= x
	jr	c,@a
	jr	z,@a
	endm

jrmyi:	macro	@a	;A >= x
	jr	nc,@a
	endm

; Conditional absolute jumps

jpi:	macro	@a	;A = x
	jp	z,@a
	endm

jpni:	macro	@a	;A <> x
	jp	nz,@a
	endm

jpmn:	macro	@a	;A < x
	jp	c,@a
	endm

jpmy:	macro	@a	;A > x
	jr	z,$+5
	jp	nc,@a
	endm

jpmni:	macro	@a	;A <= x
	jp	c,@a
	jp	z,@a
	endm

jpmyi:	macro	@a	;A >=x
	jp	nc,@a
	endm



;************************
;***                  ***
;***   MAIN PROGRAM   ***
;***                  ***
;************************

	org	#100

;---------------------------
;---  Initial checkings  ---
;---------------------------

	;--- Checks whether there are parameters or not.
	;    If not, shows help and finishes.

	print	PRESEN_S	;Presentation string

	ld	a,1	;Try to extract first parameter
	ld	de,BUFER
	call	EXTPAR
	jr	nc,THEREISPARS

TERMINFO:	print	INFO_S	;Shows info and finishes
	jp	TERM_NO_R

THEREISPARS:	;

	;--- Checks whether NestorMan 1.21 or higher is installed,
	;    otherwise shows an error message and finishes.

	xor	a	;Installed?
	nesman	1
	or	a
	jr	nz,OKNMAN1

	print	NONMAN_S	;Prints "not installed" and finishes
	print	NEEDNMAN_S	;if not installed
	jp	TERM_NO_R

OKNMAN1:	ld	hl,#0201	;Installed: now check version
	ex	de,hl
	call	COMP
	jr	c,OKNMAN2

	print	BADNMAN_S	;Prints "invalid version" and finishes
	print	NEEDNMAN_S	;if not version 1.21 or higher
	jp	TERM_NO_R
OKNMAN2:	;

	;--- Checks whether InterNestor is installed or not.
	;    If not, shows an error message and finishes.

	nesman	32	;It is installed?
	or	a
	jr	nz,OKINS

	print	NOINS_S	;Not installed: prints "INS not
	jp	TERM_NO_R	;installed" and finishes.

OKINS:	ld	a,(ix)	;Checks if INS is paused,
	or	a	;then an error is printed
	jr	nz,OKINS2	;and the program finishes

	print	PAUSED_S
	jp	TERM_NO_R

OKINS2:	ld	(INS_SLOT),a	;Saves modules slot
	push	de
	ld	a,d	;Converts segment number for level 4
	nesman	3	;module (TCP) into physical segment
	ld	a,c	;number and stores it.
	ld	(INS_TCP_SEG),a
	pop	de
	ld	a,e
	nesman	3	;Same for level 3 module (IP).
	ld	a,c
	ld	(INS_IP_SEG),a

	;--- Obtains mapper support routines

	ld	de,#0402
	call	#FFCA
	ld	de,ALL_SEG
	ld	bc,#30
	ldir

	;--- Obtains server name from the command line

	ld	a,1
	ld	de,HOST_NAME
	call	EXTPAR

	;--- Obtains remote port from command line

	ld	a,2
	ld	de,BUFER
	call	EXTPAR
	jp	c,INVPAR	;Error if parameter is missing

	ld	hl,BUFER
	call	EXTNUM
	jp	c,INVPAR	;Error if >65535

	ld	a,e
	or	a	;Error if contains non-numeric
	jp	nz,INVPAR	;characters at the end

	ld	(PORT_REMOTE),bc

	;--- Obtains other parameters, if any

	ld	a,3	;Checks 3rd parameter
	call	MOREPARS
	ld	a,4	;Checks 4th parameter
	call	MOREPARS
	ld	a,5
	call	EXTPAR	;If more than 4 parameters, error
	jp	nc,INVPAR
	jr	NOMOREPARS

MOREPARS:	ld	de,BUFER
	call	EXTPAR	;If no more parameters, continue
	jr	c,MOREP_E2

	ld	hl,BUFER
	call	EXTNUM	;If no 16 bit number or "P", error;
	jr	c,MOREP_E1	;Otherwise set local port or
	ld	a,e	;passive open flag
	or	a
	jr	z,MOREP_OK1
	or	%00100000
	cp	"p"
	jr	z,MOREP_OK2

MOREP_E1:	pop	hl
	jp	INVPAR

MOREP_E2:	pop	hl
	jr	NOMOREPARS

MOREP_OK1:	ld	(PORT_LOCAL),bc
	ret

MOREP_OK2:	ld	a,#FF
	ld	(ACT_OR_PAS),a
	ret

NOMOREPARS:	;

	;--- Switches level 4 module (TCP) segment on page 2

	call	GET_P2	;First saves the original
	ld	(TPA_SEG2),a	;TPA page 2 segment number

	ld	a,(INS_SLOT)	;Switch slot
	ld	h,#80
	call	ENASLT
	ei
	ld	a,(INS_TCP_SEG)	;Switch segment
	call	PUT_P2

	ld	de,CLOSE_END	;From now on, pressing CTRL-C
	ld	c,_DEFAB	;has te same effect of pressing CTRL-ESC
	call	DOS		;(aborts connection)

	;--- Resolves host name

	ld	hl,HOST_NAME	;Makes the DNS query
	xor	a	;(IP call is done via
	ld	ix,IP_DNS_Q	;inter-segment call)
	ld	iy,(INS_IP_SEG-1)
	call	CAL_SEG
	jp	nc,QUERY_OK

	ld	de,QERR1_S	;If an error was returned,
	cp	1	;print it and exit
	jr	z,QUERY_ERR
	ld	de,QERR4_S	;Error can be only "No connection"
	cp	4	;(1) or "No DNS available" (4)
	jr	z,QUERY_ERR
	ld	de,QERRX_S
QUERY_ERR:	ld	c,_STROUT
	call	DOS
	jp	TERM_R

QUERY_OK:	cp	1	;If it was a direct IP address,
	jr	nz,WAIT_DNS	;set it at IP_REMOTE and continue
OK_IP:	ld	(IP_REMOTE),hl
	ld	(IP_REMOTE+2),de
	jr	OK_HOSTNAME

WAIT_DNS:	print	RESOLVING_S	;If not a direct IP address,
WAIT_DNS_LOOP:	ld	ix,IP_DNS_S	;print "Resolving host name"
	ld	iy,(INS_IP_SEG-1)	;and wait for a reply or an error
	xor	a
	call	CAL_SEG
	cp	1	;1: Query yet in progress, wait
	jr	z,WAIT_DNS_LOOP
	cp	2	;2: Query finished successfully
	call	z,PRINT_OK
	jr	z,OK_IP	;Other (3): Query aborted due to error

RESOLV_ERROR:	push	af	;An error was returned:
	print	ERROR_S	;Search its string on ERRCODE_T,
	pop	af	;print it and exit
	ld	b,a
	ld	de,ERRCODE_T
SEARCH_ERROR:	ld	a,(de)
	inc	de
	cp	b
	jr	z,ERROR_FOUND
NEXT_ERROR:	ld	a,(de)
	inc	de
	or	a
	jr	z,ERROR_NOTF
	cp	"$"
	jr	nz,NEXT_ERROR
	jr	SEARCH_ERROR

ERROR_NOTF:	ld	de,UNKERR_S
ERROR_FOUND:	ld	c,_STROUT	;Print error string
	call	DOS
	call	LF
	jp	TERM_R

PRINT_OK:	push	af,hl,de
	print	OK_S
	pop	de,hl,af
	ret

	;--- Opens the connection

OK_HOSTNAME:	;
	if	OPEN_ECHO=1

	ld	hl,TCB_P	;*** Opens the local echo server
	call	TCP_OPEN	;*** Use it for loopback test
	ld	(CON_ECHO),a	;(execute with pars "127.0.0.1 7")

	endif

	ld	hl,TCB	;Open TCP connection
	call	TCP_OPEN
	jr	nc,OPEN_OK

	ld	de,OPEN_E1_S	;If error, shows the cause
	dec	a	;and finishes
	jr	z,OPEN_ERR
	ld	de,OPEN_E2_S
	dec	a
	jr	z,OPEN_ERR
	ld	de,OPEN_E3_S
	dec	a
	jr	z,OPEN_ERR
	ld	de,OPEN_E4_S
	dec	a
	jr	z,OPEN_ERR
	ld	de,OPEN_EX_S
OPEN_ERR:	ld	c,_STROUT
	call	DOS
	jp	TERM_R

OPEN_OK:	ld	(CON_NUM),a	;No error: saves connection number
	print	OPENING_S

	;--- Waits until the connection is established.
	;    If ESC is pressed meanwhile, connection is closed
	;    and program finishes.

WAIT_OPEN:	ld	a,(#FBEC)	;Bit 2 of #FBEC is 0
	bit	2,a	;when ESC is being pressed
	jp	z,CLOSE_END

	ld	a,(CON_NUM)
	call	TCP_STATUS
	jr	nc,WAIT_OPEN2

	print	CONREF_S	;If connection is closed, it was
	jp	TERM_R	;refused or host is not responding

WAIT_OPEN2:	cp	4	;4 = code for ESTABLISHED state
	jr	nz,WAIT_OPEN

	print	OPENED_S

	;* PROGRAM MAIN LOOP
	;- Check for incoming data, if so, print it.
	;- Check for ESC pressing, if so, print "connection
	;  closed/aborted by user" and finish.
	;- Check for F1/F2/F3 pressing, if so, process it.
	;- Check for other key pressing, if so, get the character
	;  or the line (depending on current input mode)
	;  and send it.
	;- Check for "established" state loss, if so, print
	;  "connection closed by remote side" and finish.
	;- Wait for the next interrupt (HALT) and repeat the loop.

MAIN_LOOP:	;

	;--- First try to get incoming data and then print it

	ld	a,(CON_NUM)
	ld	hl,RCV_BUF
	ld	bc,2048	;Get as much data as possible
	ld	d,0
	call	TCP_RCV
	jp	c,NO_RCV

	ld	hl,RCV_BUF
PRNTLOOP:	push	bc	;Print out data character by character.
	ld	a,(hl)	;We can't use _STROUT routine,
	inc	hl	;since we don't know if any "$" character
	push	hl	;is contained in the string.
	ld	e,a
	ld	c,_CONOUT
	call	DOS
	pop	hl,bc
	dec	bc
	ld	a,b
	or	c
	jr	nz,PRNTLOOP
NO_RCV:	;

	;--- Check for ESC key pressed, if so, close/abort
	;    and finish

	ld	a,(#FBEC)
	bit	2,a
	jp	z,CLOSE_END

	;--- Check for F1/F2/F3 pressing

	ld	a,(#FBEB)	;#FBEB contains the status of
	and	%11100000	;F1, F2 and F3 keys on bits
	cp	%11100000	;5, 6 and 7 respectively
	jp	z,NO_F_KEY	;(0 when being pressed)

	;--- F1? Then print help

CHECK_F1:	bit	5,a
	jr	nz,CHECK_F2

	print	HELP_S
	jr	END_F_KEY

	;--- F2? Then toggle character/line mode

CHECK_F2:	bit	6,a
	jr	nz,CHECK_F3

	ld	a,(INPUT_MODE)
	cpl
	ld	(INPUT_MODE),a

	ld	de,INPTOG0_S
	ld	hl,LINE_S
	or	a
	jr	z,CHECK_F22
	ld	de,INPTOG1_S
	ld	hl,CHAR_S
CHECK_F22:	push	hl	;Prints change information
	ld	c,_STROUT	;and updates help text
	call	DOS
	pop	hl
	ld	de,LINCHAR_S
	ld	bc,9
	ldir
	jr	END_F_KEY

	;--- F3? Then toggle local echo ON/OFF

CHECK_F3:	ld	a,(GETCHAR_FUN)
	xor	9	;Toggles 1 <--> 8
	ld	(GETCHAR_FUN),a	;(the DOS function used to get char.)

	cp	1
	ld	de,ECHOTOG0_S
	ld	hl,ON_S
	jr	z,CHECK_F32
	ld	de,ECHOTOG1_S
	ld	hl,OFF_S
CHECK_F32:	push	hl	;Prints change information
	ld	c,_STROUT	;and updates help text
	call	DOS
	pop	hl
	ld	de,ECHONOFF_S
	ld	bc,3
	ldir

END_F_KEY:	ld	c,_DIRIO	;Erases keyboard buffer
	ld	e,#FF	;to avoid the Fx key contents
	call	DOS	;to be accepted as data
	or	a
	jr	nz,END_F_KEY

	jr	END_KEY

NO_F_KEY:	;

	;--- Check if any other key is pressed, if so, it is
	;    assumed to be data to be sent to the TCP connection
	;    (a whole line is read or just one character, depending
	;    on the current input mode)

	ld	c,_CONST	;Any key was pressed?
	call	DOS
	or	a
	jr	z,END_KEY

	ld	a,(INPUT_MODE)
	or	a
	jr	nz,GET_INPUT_C

	;* Line mode: gets one line, adds a LF at the end,
	;  and sends it

GET_INPUT_L:	ld	c,_BUFIN
	ld	de,SEND_BUF
	call	DOS
	call	LF	;Prints a LF to change screen line

	ld	a,(SEND_BUF+1)	;Adds a LF at the end of the line
	ld	c,a
	ld	b,0
	inc	bc
	ld	hl,SEND_BUF+2
	add	hl,bc
	ld	(hl),10
	inc	bc

	ld	a,(CON_NUM)	;Sends the line to the connection
	ld	hl,SEND_BUF+2
	ld	d,1	;"Push" is specified
	call	TCP_SEND

	jr	END_KEY

	;* Character mode: gets the character with or without echo,
	;  and sends it to the connection

GET_INPUT_C:	ld	a,(GETCHAR_FUN)
	ld	c,a
	push	bc
	call	DOS
	ld	(SEND_BUF+2),a

	pop	hl	;If character is CR, sends also
	cp	13	;a LF
	ld	bc,1
	jr	nz,GET_INPUT_C2

	ld	a,10
	ld	(SEND_BUF+3),a
	ld	a,l	;If local echo is ON, the LF
	cp	1	;must be explicitly printed
	call	z,LF
	ld	bc,2

GET_INPUT_C2:	ld	a,(CON_NUM)	;Sends the character(s)
	ld	hl,SEND_BUF+2
	ld	d,1	;"Push" is specified
	call	TCP_SEND

END_KEY:	;

	;--- Check if we still "established". If not, print
	;    "connection closed by remote side" and finish.

	ld	a,(CON_NUM)
	call	TCP_STATUS
	push	af	;If connection does not exist
	ld	de,CONLOST_S	;(probably due to internet connection
	ld	c,_STROUT	;loss) show "connection lost"
	call	c,DOS	;and finish
	pop	af
	jp	c,TERM_R

	cp	4
	jr	z,OK_STAT

	ld	a,(CON_NUM)	;Since connection is no longer
	call	TCP_CLOSE	;usable, we close it

	print	REMCLOS_S
	jp	TERM_R

OK_STAT:	;

	;--- At this point we have (maybe) send and/or received data.
	;    Since no more incoming data will be available
	;    (and no more outgoing data will be sent) until the
	;    next timer interrupt, we issue a HALT before returning
	;    to the main loop, so we ensure that the TCP timer
	;    interrupt routine will have been executed once again
	;    before trying to process more data.

	halt
	jp	MAIN_LOOP



;******************************
;***                        ***
;***   AUXILIARY ROUTINES   ***
;***                        ***
;******************************


;--- NAME: COMP
;      Compares HL and DE (16 bits in twos complement)
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
;    INPUT:   A  = Parameter to extract (the first one is 1)
;             DE = Buffer to put the extracted parameter
;    OUTPUT:  A  = Total number of parameters in the command line
;             CY = 1 -> The specified parameter does not exist
;                       B undefined, buffer unmodified
;             CY = 0 -> B = Parameter length, not including the tailing 0
;                       Parameter extracted to DE, finished with a 0 byte
;                       DE preserved

EXTPAR:	or	a	;Terminates with error if A = 0
	scf
	ret	z

	ld	b,a
	ld	a,(#80)	;Terminates with error if
	or	a	;there are no parameters
	scf
	ret	z
	ld	a,b

	push	hl,de,ix
	ld	ix,0	;IXl: Number of parameter
	ld	ixh,a	;IXh: Parameter to be extracted
	ld	hl,#81

	;* Scans the command line and counts parameters

PASASPC:	ld	a,(hl)	;Skips spaces until a parameter
	or	a	;is found
	jr	z,ENDPNUM
	cp	" "
	inc	hl
	jri	PASASPC

	inc	ix	;Increases number of parameters
PASAPAR:	ld	a,(hl)	;Walks through the parameter
	or	a
	jr	z,ENDPNUM
	cp	" "
	inc	hl
	jri	PASASPC
	jr	PASAPAR

	;* Here we know already how many parameters are available

ENDPNUM:	ld	a,ixh	;Error if the parameter to extract
	cp	ixl	;is greater than the total number of
	jrmy	EXTPERR	;parameters available

	ld	hl,#81
	ld	b,1	;B = current parameter
PASAP2:	ld	a,(hl)	;Skips spaces until the next
	cp	" "	;parameter is found
	inc	hl
	jri	PASAP2

	ld	a,ixh	;If it is the parameter we are
	cp	b	;searching for, we extract it,
	jri	PUTINDE0	;else...

	inc	B
PASAP3:	ld	a,(hl)	;...we skip it and return to PASAP2
	cp	" "
	inc	hl
	jrni	PASAP3
	jr	PASAP2

	;* Parameter is located, now copy it to the user buffer

PUTINDE0:	ld	b,0
	dec	hl
PUTINDE:	inc	b
	ld	a,(hl)
	cp	" "
	jri	ENDPUT
	or	a
	jr	z,ENDPUT
	ld	(de),a	;Paramete is copied to (DE)
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


;--- Termination due to ESC or CTRL-C pressing
;    Connection is closed, or aborted if CTRL is pressed,
;    and program finishes

CLOSE_END:	if	OPEN_ECHO=1

	ld	a,(CON_ECHO)
	call	TCP_CLOSE

	endif

	ld	a,(#FBEB)	;Checks CTRL key status
	bit	1,a	;in order to decide whether
	ld	ix,TCP_CLOSE	;CLOSE or ABORT must be executed
	ld	de,USERCLOS_S	;(always ABORT in case of CTRL-C)
	jr	nz,CLOSE_END2
	ld	ix,TCP_ABORT
	ld	de,USERAB_S
CLOSE_END2:	push	de
	ld	a,(CON_NUM)
	ld	hl,CLOSE_END3
	push	hl
	jp	(ix)
CLOSE_END3:	pop	de
	ld	c,_STROUT
	call	DOS
	jr	TERM_R

;--- Termination due to invalid parameter

INVPAR:	print	INVPAR_S
	;print	INFO_S
	;jr      TERM_R

;--- Termination routines
;    TERM_R restores TPA slot in page 2 before terminating,
;    TERM_NO_R just terminates

TERM_R:	ld	a,(#F343)
	ld	h,#80
	call	ENASLT
	ld	a,(TPA_SEG2)
	call	PUT_P2

	ld	de,0	;Disables abort exit routine definition
	ld	c,_DEFAB	;to avoid an infinite loop when calling _TERM
	call	DOS

TERM_NO_R:	ld	bc,_TERM+0*256	;Terminates with error code 0
	jp	5

;--- Prints LF

LF:	ld	e,10
	ld	c,_CONOUT
	jp	DOS

;--- DOS mapper support routines

ALL_SEG:	ds	3
FRE_SEG:	ds	3
RD_SEG:	ds	3
WR_SEG:	ds	3
CAL_SEG:	ds	3
CALLS:	ds	3
PUT_PH:	ds	3
GET_PH:	ds	3
PUT_P0:	ds	3
GET_P0:	ds	3
PUT_P1:	ds	3
GET_P1:	ds	3
PUT_P2:	ds	3
GET_P2:	ds	3
PUT_P3:	ds	3
GET_P3:	ds	3


;--- NAME: NUMTOASC
;      Converts a 16 bit number into an ASCII string
;    INPUT:      DE = Number to convert
;                HL = Buffer to put the generated ASCII string
;                B  = Total number of characters of the string
;                     not including any termination character
;                C  = Padding character
;                     The generated string is right justified,
;                     and the remaining space at the left is padded
;                     with the character indicated in C.
;                     If the generated string length is greater than
;                     the value specified in B, this value is ignored
;                     and the string length is the one needed for
;                     all the digits of the number.
;                     To compute length, termination character "$" or 00
;                     is not counted.
;                 A = &B ZPRFFTTT
;                     TTT = Format of the generated string number:
;                            0: decimal
;                            1: hexadecimal
;                            2: hexadecimal, starting with "&H"
;                            3: hexadecimal, starting with "#"
;                            4: hexadecimal, finished with "H"
;                            5: binary
;                            6: binary, starting with "&B"
;                            7: binary, finishing with "B"
;                     R   = Range of the input number:
;                            0: 0..65535 (unsigned integer)
;                            1: -32768..32767 (twos complement integer)
;                               If the output format is binary,
;                               the number is assumed to be a 8 bit integer
;                               in the range 0.255 (unsigned).
;                               That is, bit R and register D are ignored.
;                     FF  = How the string must finish:
;                            0: No special finish
;                            1: Add a "$" character at the end
;                            2: Add a 00 character at the end
;                            3: Set to 1 the bit 7 of the last character
;                     P   = "+" sign:
;                            0: Do not add a "+" sign to positive numbers
;                            1: Add a "+" sign to positive numbers
;                     Z   = Left zeros:
;                            0: Remove left zeros
;                            1: Do not remove left zeros
;    OUTPUT:    String generated in (HL)
;               B = Length of the string, not including the padding
;               C = Length of the string, including the padding
;                   Tailing "$" or 00 are not counted for the length
;               All other registers are preserved

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
	ld	(ix+1),a	;Finishing
	pop	af
	and	%11100000
	rlca
	rlca
	rlca
	ld	(ix+6),a	;Flags: Z(zero), P(+ sign), R(range)
	ld	(ix+2),b	;Number of final characters
	ld	(ix+3),c	;Padding character
	xor	a
	ld	(ix+4),a	;Total length
	ld	(ix+5),a	;Number length
	ld	a,10
	ld	(ix+7),a	;Divisor = 10
	ld	(ix+13),l	;User buffer
	ld	(ix+14),h
	ld	hl,BufNTOA
	ld	(ix+10),l	;Internal buffer
	ld	(ix+11),h

ChkTipo:	ld	a,(ix+0)	;Set divisor to 2 or 16,
	or	a	;or leave it to 10
	jr	z,ChkBoH
	cp	5
	jp	nc,EsBin
EsHexa:	ld	a,16
	jr	GTipo
EsBin:	ld	a,2
	ld	d,0
	res	0,(ix+6)	;If binary, range is 0-255
GTipo:	ld	(ix+7),a

ChkBoH:	ld	a,(ix+0)	;Checks if a final "H" or "B"
	cp	7	;is desired
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

ChkTip2:	ld	a,d	;If the number is 0, never add sign
	or	e
	jr	z,NoSgn
	bit	0,(ix+6)	;Checks range
	jr	z,SgnPos
ChkSgn:	bit	7,d
	jr	z,SgnPos
SgnNeg:	push	hl	;Negates number
	ld	hl,0	;Sign=0:no sign; 1:+; 2:-
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
Divide:	push	bc,hl	;DE/(IX+7)=DE, remaining A
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

ChkRest9:	cp	10	;Converts the remaining
	jp	nc,EsMay9	;to a character
EsMen9:	add	a,"0"
	jr	PonEnBuf
EsMay9:	sub	10
	add	a,"A"

PonEnBuf:	ld	(hl),a	;Puts character in the buffer
	inc	hl
	inc	(ix+4)
	inc	(ix+5)
	djnz	Divide
	pop	de

ChkECros:	bit	2,(ix+6)	;Cchecks if zeros must be removed
	jr	nz,ChkAmp
	dec	hl
	ld	b,(ix+5)
	dec	b	;B=num. of digits to check
Chk1Cro:	ld	a,(hl)
	cp	"0"
	jr	nz,FinECeros
	dec	hl
	dec	(ix+4)
	dec	(ix+5)
	djnz	Chk1Cro
FinECeros:	inc	hl

ChkAmp:	ld	a,(ix+0)	;Puts "#", "&H" or "&B" if necessary
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

PonSgn:	ld	a,(ix+12)	;Puts sign
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

ChkLon:	ld	a,(ix+2)	;Puts padding if necessary
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
	xor	a	;Inverts the string
	push	hl
	ld	(ix+8),a
	ld	a,(ix+4)
	dec	a
	ld	e,a
	ld	d,0
	add	hl,de
	ex	de,hl
	pop	hl	;HL=initial buffer, DE=final buffer
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
	ld	a,b	;*** This part was missing on the
	or	a	;*** original routine
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

ChkFin1:	ld	a,(ix+1)	;Checks if "$" or 00 finishing is desired
	and	%00000111
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


;--- NAME: EXTNUM
;      Extracts a 5 digits number from an ASCII string
;    INPUT:      HL = ASCII string address
;    OUTPUT:     CY-BC = 17 bits extracted number
;                D  = number of digits of the number
;                     The number is considered to be completely extracted
;                     when a non-numeric character is found,
;                     or when already five characters have been processed.
;                E  = first non+numeric character found (or 6th digit)
;                A  = error:
;                     0 => No error
;                     1 => The number has more than five digits.
;                          CY-BC contains then the number composed with
;                          only the first five digits.
;    All other registers are preserved.

EXTNUM:	push	hl,ix
	ld	ix,ACA
	res	0,(ix)
	set	1,(ix)
	ld	bc,0
	ld	de,0
BUSNUM:	ld	a,(hl)	;Jumps to FINEXT if no numeric character
	ld	e,a	;IXh = last read character
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


;***************************
;***                     ***
;***   DATA, VARIABLES   ***
;***                     ***
;***************************

;--- Pseudo-TCB, it is filled in with the command line parameters

TCB:	;
IP_REMOTE:	db	0,0,0,0
PORT_REMOTE:	dw	0
PORT_LOCAL:	dw	#FFFF
ACT_OR_PAS:	db	0
	db	0

	if	OPEN_ECHO=1

	;Pseudo-TCB of the local echo server

TCB_P:	db	0,0,0,0
	dw	0
	dw	7
	db	#FF
	db	0

	endif

;--- Variables

INS_SLOT:	db	0	;InterNestor Suite slot
INS_TCP_SEG:	db	0	;Level 4 module physical segment
INS_IP_SEG:	db	0	;Level 3 module physical segment
CON_NUM:	db	0	;Connection number
INPUT_MODE:	db	0	;0 for line mode, #FF for char. mode
GETCHAR_FUN:	db	1	;1 for echo ON, 8 for echo OFF
TPA_SEG2:	db	0	;Original TPA page 2 segment number
	if	OPEN_ECHO=1
CON_ECHO:	db	0	;Con. num. of the local echo server
	endif

;--- Text strings

PRESEN_S:	db	13,10,"TCP Console 0.1 - a simplified telnet client",13,10
	db	"By Konami Man, 2-2002",13,10,10,"$"
INFO_S:	db	"Use: TCPCON <host name>|<remote IP address> <remote port> [<local port>] [P]",13,10,10
	db	"     <local port>: if not specified, a free port will be selected",13,10
	db	"     P: Use passive connection open",13,10,"$"
NONMAN_S:	db	"ERROR: NestorMan not installed",13,10,"$"
BADNMAN_S:	db	"ERROR: Invalid NestorMan version!",13,10,"$"
NEEDNMAN_S:	db	"NestorMan version 1.21 or higher is needed.",13,10,"$"
NOINS_S:	db	"ERROR: InterNestor suite is not installed",13,10,"$"
INVIP_S:	db	"ERROR: Invalid IP address. Must be xxx.xxx.xxx.xxx, with 0<=xxx<=255",13,10,"$"
INVPAR_S:	db	"ERROR: Invalid parameter(s)",13,10,"$"
OPEN_E1_S:	db	"ERROR: Too many TCP connections opened",13,10,"$"
OPEN_E2_S:	db	"ERROR: No internet connection currently",13,10,"$"
QERR1_S:	equ	OPEN_E2_S
OPEN_E3_S:	db	"ERROR: Connection already exists, try another local port number",13,10,"$"
OPEN_E4_S:	db	"ERROR: Unespecified remote socket is not allowed on active connections",13,10,"$"
OPEN_EX_S:	db	"Unknown ERROR when opening connection",13,10,"$"
PAUSED_S:	db	"ERROR: InterNestor Suite is paused - do INSINS R first",13,10,"$"
QERR4_S:	db	"ERROR: No DNS addresses available - can't resolve host name",13,10,"$"
QERRX_S:	db	"Unknown ERROR when querying DNS",13,10,"$"
ERROR_S:	db	"ERROR",13,10,"*** $"
OPENING_S:	db	"Opening connection... $"
RESOLVING_S:	db	"Resolving host name... $"
OK_S:	db	"OK!",13,10,10,"$"
OPENED_S:	db	"OK!",13,10,10
	db	"*** Press F1 for help",13,10,10,"$"
HELP_S:	db	13,10,"*** F1: Show this help",13,10
	db	"*** F2: Toggle line/character mode",13,10
	db	"        Current mode is: "
LINCHAR_S:	db	"line     ",13,10
	db	"*** F3: Toggle local echo ON/OFF (only on character mode)",13,10
	db	"        Currently local echo is: "
ECHONOFF_S:	db	"ON ",13,10
	db	"*** ESC: Close connection and exit",13,10
	db	"*** CTRL+ESC: Abort connection and exit",13,10
	db	"*** Type the text to be sent to the other side.",13,10
	db	"    In line mode, the line text will be sent when pressing ENTER.",13,10
	db	"    In character mode, each typed character will be sent immediately.",13,10
	db	"    Incoming data will be printed out to the screen.",13,10,10,"$"
INPTOG0_S:	db	13,10,"*** Input mode toggled to line mode",13,10,"$"
INPTOG1_S:	db	13,10,"*** Input mode toggled to character mode",13,10,"$"
ECHOTOG0_S:	db	13,10,"*** Local echo toggled ON",13,10,"$"
ECHOTOG1_S:	db	13,10,"*** Local echo toggled OFF",13,10,"$"
REMCLOS_S:	db	13,10,"*** Connection closed by remote side",13,10,"$"
USERCLOS_S:	db	13,10,"*** Connection closed by user",13,10,"$"
USERAB_S:	db	13,10,"*** Connection aborted by user",13,10,"$"
CONLOST_S:	db	13,10,"*** Connection lost",13,10,"$"
CONREF_S:	db	13,10,"*** Connection refused or host unreachable",13,10,"$"
LINE_S:	db	"line     "
CHAR_S:	db	"character"
ON_S:	db	"ON "
OFF_S:	db	"OFF"

ERRCODE_T:	db	0,"DNS error 0 (ooops, this is an INS failure!)$"
	db	1,"Query format error$"
	db	2,"Server failure$"
	db	3,"Name error$"
	db	4,"Query type not implemented$"
	db	5,"Query refused$"
	db	6,"DNS error 6$"
	db	7,"DNS error 7$"
	db	8,"DNS error 8$"
	db	9,"DNS error 9$"
	db	10,"DNS error 10$"
	db	11,"DNS error 11$"
	db	12,"DNS error 12$"
	db	13,"DNS error 13$"
	db	14,"DNS error 14$"
	db	15,"DNS error 15$"
	db	16,"Can't get a reply from DNS$"
	db	17,"Operation timeout expired$"
	db	18,"Query aborted$"
	db	19,"Connection lost$"
	db	20,"DNS did not give neither a reply nor a pointer to another DNS$"
	db	21,"Answer is truncated$"
	db	0
UNKERR_S:	db	"Unknown error code$"

;--- Buffer for sending data

SEND_BUF:	db	255	;Buffer size for _BUFIN

;--- Buffer for receive data

RCV_BUF:	equ	SEND_BUF+260

;--- Buffer for host name

HOST_NAME:	equ	RCV_BUF+2048

;--- Generic buffer

BUFER:	equ	HOST_NAME+256
