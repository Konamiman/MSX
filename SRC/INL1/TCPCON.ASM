	;--- TCP console for InterNestor Lite 1.03
	;    By Konami Man, 4-2005
	;    Use: TCPCON <host name>|<IP address> <remote port> [<local port>] [P]
	;         Append P to open connection in passive mode
	;         Use IP address 0.0.0.0 for unespecified remote socket

	;This program opens a TCP connection to the specified host
	;on the specified port (optionally a passive connection),
	;and enters a loop in which all the received data is printed
	;on the screen, and all the data typed on the keyboard
	;is sent, until we (by pressing ESC) or the peer
	;close the connection.

	;Note that this is NOT a Telnet client, since no
	;special characters being part of the Telnet specification
	;are supported (received data is printed raw in the screen,
	;and input data is sent raw to the TCP connection).

	.label	20	;Directive for Compass


;*****************************
;***                       ***
;***   MACROS, CONSTANTS   ***
;***                       ***
;*****************************

DOS:	equ	#0005	;DOS function calls entry point

	;--- Macro for printing a $-finished string

print:	macro	@d
	ld	de,@d
	ld	c,_STROUT
	call	DOS
	endm

	;--- Macro to call an InterNestor Lite function
	;
	;    Under DOS 1, after a call to any DOS function, the system
	;    restores the TPA segment in page 1. This does not happen
	;    under DOS 2.
	;
	;    Using this macro we ensure that INL calls will always
	;    be correctly executed regardless of the DOS version.
	;    On your DOS 2-only programs, you can override this macro
	;    and permorm the CALL directly.

inl:	macro	@d
	push	af
	ld	a,(INL_SEG1)
	call	PUT_P1
	pop	af

	call	@d
	endm

	;--- DOS function calls

_TERM0:	equ	#00	;Program terminate
_CONIN:	equ	#01	;Console input with echo
_CONOUT:	equ	#02	;Console output
_DIRIO:	equ	#06	;Direct console I/O
_INNOE:	equ	#08	;Console input without echo
_STROUT:	equ	#09	;String output
_BUFIN:	equ	#0A	;Buffered line input
_CONST:	equ	#0B	;Console status
_TERM:	equ	#62	;Terminate with error code
_DEFAB:	equ	#63	;Define abort exit routine
_DOSVER:	equ	#6F	;Get DOS version

	;--- InterNestor Lite variables and routines

IP_STRING:	equ	#4036	;Converts an IP address into a string
DNS_Q:	equ	#405D	;Performs a DNS request
DNS_S:	equ	#4060	;Obtains the DNS request status/result
TCP_OPEN:	equ	#4063	;Open a TCP connection
TCP_CLOSE:	equ	#4066	;Close a TCP connection
TCP_ABORT:	equ	#4069	;Abort a TCP connection
TCP_SEND:	equ	#406C	;Send data to TCP connection
TCP_RCV:	equ	#406F	;Receive data from TCP connection
TCP_STATUS:	equ	#4072	;Get TCP connection status
TCP_FLUSH:	equ	#4075	;Flush TCP outgoing data queue
WAIT_INT:	equ	#4081	;Wait for the next timer interrupt
NETWORK_STATE:	equ	#4084	;Check the network state


;************************
;***                  ***
;***   MAIN PROGRAM   ***
;***                  ***
;************************

	org	#100	;Needed for programs executing under MSX-DOS

	;------------------------
	;---  Initialization  ---
	;------------------------

	;--- Checks the DOS version and establishes variable DOS2

	ld	c,_DOSVER
	call	DOS
	or	a
	jr	nz,NODOS2
	ld	a,b
	cp	2
	jr	c,NODOS2

	ld	a,#FF
	ld	(DOS2),a	;#FF for DOS 2, 0 for DOS 1
NODOS2:	;

	;--- Prints the presentation

	print	PRESENT_S

	;--- Checks if there are command line parameters.
	;    If not, prints information and finishes.

	ld	a,1
	ld	de,BUFFER
	call	EXTPAR
	jr	nc,HAYPARS

TERMINFO:	print	INFO_S
	ld	c,_TERM0
	jp	DOS
HAYPARS:	;

	;--- Checks that InterNestor Lite is installed, if not,
	;    displays an error and finishes

	xor	a
	ld	de,#2203
	call	#FFCA
	or	a
	jr	nz,OKINS

	print	NOINS_S
	ld	c,_TERM0
	jp	DOS
OKINS:	;

	ld	a,b
	ld	(INL_SEG1),a
	;ld      a,c                    ;--- In this program we don't need
	;ld      (INL_SEG2),a           ;--- this information, it is enough
	;ld      (INL_P3DIR),hl         ;--- with the code segment number

	;--- Obtains PUT_P1 routine from the INL page 3 jump area
	;    (its offset is 15)

	ld	bc,15
	add	hl,bc
	ld	de,PUT_P1
	ld	bc,3
	ldir

	;> From this point we can call TERMINATE to return to DOS.

	;--- Connects the InterNestor Lite segment in page 1
	;    (It is not necessary because "inl" macro is used)

	;ld     a,(INL_SEG1)
	;call   PUT_P1

	;--- Checks that we are connected to Internet.
	;    If not, displays an error and finishes.

	inl	NETWORK_STATE
	cp	2	;Is network available?
	jr	z,CONNECT_OK

	print	ASTERISK_S
	print	NOCON_S+1
	print	ONE_NL_S
	jp	TERMINATE
CONNECT_OK:	;

	;--- Obtains server name from the command line

	ld	a,1
	ld	de,HOST_NAME
	call	EXTPAR

	;--- Obtains remote port from command line

	ld	a,2
	ld	de,BUFFER
	call	EXTPAR
	jp	c,MISSPAR	;Error if the parameter is missing

	ld	hl,BUFFER
	call	EXTNUM16
	jp	c,INVPAR	;Error if not a valid number

	ld	(PORT_REMOTE),bc

	;--- Obtains other parameters, if any
	;    (local port and passive connection)

	ld	a,3	;Param number to be extracted
LASTPARAMS:	ld	ixh,a
	ld	de,BUFFER
	call	EXTPAR
	jr	c,NOMOREPARS	;The parameter is present?

	ld	a,(BUFFER)	;If the first character of the parameter
	or	%00100000	;is "P" or "p", set passive open...
	cp	"p"
	jr	nz,NO_PASSIVE
	ld	a,#FF
	ld	(PASSIVE_OPEN),a
	jr	LASTPAR_NEXT
NO_PASSIVE:

	ld	hl,BUFFER	;...otherwise, if it is a number, set
	call	EXTNUM16	;local port; otherwise, it is an
	jp	c,INVPAR	;invalid parameter.
	ld	(PORT_LOCAL),bc

LASTPAR_NEXT	ld	a,ixh
	inc	a
	cp	5	;Extracts params 3 and 4 only
	jr	c,LASTPARAMS
NOMOREPARS:	;

	;--- If we are in DOS 2, set the abort exit routine

	ld	a,(DOS2)
	or	a
	ld	de,CLOSE_END	;From now on, pressing CTRL-C
	ld	c,_DEFAB	;has te same effect of pressing CTRL-ESC
	call	nz,DOS		;(aborts the TCP connection and terminates program)


	;------------------------------------------------------------
	;---  Host name resolution and TCP connection initiation  ---
	;------------------------------------------------------------

	;>>> Resolves host name

	print	RESOLVING_S

	ld	hl,HOST_NAME	;Query the resolver...
	xor	a
	inl	DNS_Q

	ld	b,a	;...and check for an error
	ld	ix,DNSQERRS_T
	jr	c,DNSQR_ERR

	;* Waits for the query to finish

DNSQ_WAIT:	inl	WAIT_INT
	call	CHECK_KEY	;To allow process abort with CTRL-C

	ld	a,1
	inl	DNS_S

	;* Error?

	cp	3
	ld	ix,DNSRERRS_T
	jr	z,DNSQR_ERR

	;* The request continues? Then go back to the waiting loop

	cp	2
	jr	nz,DNSQ_WAIT	;The request has not finished yet?

	;* Request finished? Store and display result, and continue

	ld	(IP_REMOTE),hl	;Stores the returned result (L.H.E.D)
	ld	(IP_REMOTE+2),de

	ld	ix,RESOLVIP_S	;Displays the result
	ld	a,"$"
	inl	IP_STRING
	print	RESOLVOK_S
	print	TWO_NL_S

	jp	RESOLV_OK	;Continues

	;- Error routine for DNS_Q and DNS_S
	;  Input: B=Error code, IX=Errors table

DNSQR_ERR:	push	ix,bc

	;* Prints "ERROR <code>: "

	ld	ix,RESOLVERRC_S
	call	BYTE2ASC
	ld	(ix),":"
	ld	(ix+1)," "
	ld	(ix+2),"$"
	print	RESOLVERR_S

	;* Obtains the error code, diasplays it and finishes

	pop	bc,de
	call	GET_STRING
	ld	c,_STROUT
	call	DOS

	jp	TERMINATE
RESOLV_OK:	;


	;>>> Opens the TCP connection

	ld	hl,(IP_REMOTE)
	ld	de,(IP_REMOTE+2)
	ld	ix,(PORT_REMOTE)
	ld	iy,(PORT_LOCAL)
	ld	a,(PASSIVE_OPEN)
	ld	bc,0
	inl	TCP_OPEN
	jr	nc,OPEN_OK

	push	af
	print	ERROR_S
	pop	af
	ld	b,a	;Error: Show the cause and terminate
	ld	de,TCPOPERRS_T
	call	GET_STRING
	ld	c,_STROUT
	call	DOS
	jp	TERMINATE

OPEN_OK:	ld	(CON_NUM),a	;No error: saves connection handle
	print	OPENING_S

	;--- Wait until the connection is established.
	;    If ESC is pressed meanwhile, the connection is closed
	;    and the program finishes.

WAIT_OPEN:	call	WAIT_INT
	ld	a,(#FBEC)	;Bit 2 of #FBEC is 0
	bit	2,a	;when ESC is being pressed
	jp	z,CLOSE_END

	ld	a,(CON_NUM)
	inl	TCP_STATUS
	or	a
	jr	nz,WAIT_OPEN2

	push	bc
	print	ONE_NL_S
	pop	bc
	ld	de,TCPCLOSED_T	;If the connection has reverted to CLOSED,
	call	GET_STRING	;show the reason and terminate
	ld	c,_STROUT
	call	DOS
	jp	TERMINATE

WAIT_OPEN2:	cp	4	;4 = code for ESTABLISHED state
	jr	nz,WAIT_OPEN

	print	OPENED_S


	;---------------------------
	;---  Program main loop  ---
	;---------------------------

	;- Check for incoming data, if present, print it.
	;- Check for "established" state loss, if so, print
	;  "connection closed by remote side" and finish.
	;- Check for ESC pressing, if so, print "connection
	;  closed/aborted by user" and finish.
	;- Check for F1/F2/F3 pressing, if so, process it.
	;- Check for other key pressing, if so, get the character
	;  or the line (depending on current input mode)
	;  and send it.
	;- Wait for the next interrupt (WAIT_INT) and repeat the loop.

MAIN_LOOP:	;

	;--- First try to get incoming data and then print it

	ld	a,(CON_NUM)
	ld	de,BUFFER
	ld	bc,1024
	inl	TCP_RCV
	jp	c,TCP_ERROR	;Error?
	jr	z,END_RCV	;No data available?
TCP_RCVOK:	;

	ld	hl,BUFFER

PRNTLOOP:	ld	a,(#FBEC)	;If ESC is pressed, terminate
	bit	2,a
	jp	z,CLOSE_END

	push	bc	;Print out data character by character.
	ld	a,(hl)	;We can't use _STROUT function call,
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
END_RCV:	;

	;--- Check if the connection has lost the ESTABLISHED
	;    state. If so, close the connection and terminate.

	ld	a,(CON_NUM)
	inl	TCP_STATUS
	cp	4	;ESTABLISHED state
	jr	z,STATUS_OK

	or	a	;If closed, act as if
	ld	a,2	;TCP_xxx returned error 2
	jp	z,TCP_ERROR

	ld	a,(CON_NUM)	;Otherwise, close and print
	inl	TCP_CLOSE	"Closed by remote peer" before terminating
	print	TWO_NL_S
	print	PEERCLOSE_S+1
	jp	TERMINATE
STATUS_OK:

	;--- Check for ESC key being pressed, if so, close/abort
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

FUN_XOR:	equ	1 xor 8	;_CONIN xor _INNOE

CHECK_F3:	ld	a,(GETCHAR_FUN)
	xor	FUN_XOR	;Toggles _CONIN <--> _INNOE
	ld	(GETCHAR_FUN),a	;(the DOS function used to get char.)

	cp	_CONIN
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
	call	DOS	;to be accepted as data to be sent
	or	a
	jr	nz,END_F_KEY

	jp	END_KEY

NO_F_KEY:	;

	;--- Check if any other key is pressed, if so, it is
	;    assumed to be data to be sent to the TCP connection
	;    (a whole line is read or just one character, depending
	;    on the current input mode)

	ld	c,_CONST	;Any key was pressed?
	call	DOS
	or	a
	jp	z,END_KEY

	ld	a,(INPUT_MODE)
	or	a
	jr	nz,GET_INPUT_C

	;* Line mode: gets one line, adds a LF at the end,
	;  and sends it

GET_INPUT_L:	ld	a,255
	ld	(BUFFER),a
	ld	c,_BUFIN	;Read characters until ENTER is pressed
	ld	de,BUFFER
	call	DOS
	call	LF	;Prints a LF to change screen line

	ld	a,(BUFFER+1)	;Adds a LF at the end of the line
	ld	c,a
	ld	b,0
	inc	bc
	ld	hl,BUFFER+2
	add	hl,bc
	ld	(hl),10
	inc	bc

	ld	a,(CON_NUM)	;Sends the line to the connection
	ld	hl,BUFFER+2
	scf		;"Push" is specified
	inl	TCP_SEND
	jp	c,TCP_ERROR

	jr	END_KEY

	;* Character mode: gets the character with or without echo,
	;  and sends it to the connection

GET_INPUT_C:	ld	a,(GETCHAR_FUN)
	ld	c,a
	push	bc
	call	DOS
	ld	(BUFFER),a

	pop	hl	;If character is CR, sends also
	cp	13	;a LF
	ld	bc,1
	jr	nz,GET_INPUT_C2

	ld	a,10
	ld	(BUFFER+1),a
	ld	a,l	;If local echo is ON, the LF
	cp	_CONIN	;must be explicitly printed
	call	z,LF
	ld	bc,2

GET_INPUT_C2:	ld	a,(CON_NUM)	;Sends the character(s)
	ld	hl,BUFFER
	scf		;"PUSH" is specified
	inl	TCP_SEND
	jp	c,TCP_ERROR

END_KEY:	;

	;--- End of the main loop step:
	;    Give the INL code an opportunity to excute,
	;    then repeat the loop.

	inl	WAIT_INT
	jp	MAIN_LOOP


	;--- Jump here in case a call to TCP_SEND or TCP_RCV return an error.
	;    Input: A=Error code

	;* If the error is "Output buffer overflow",
	;  print the error, close the connection and finish

TCP_ERROR:	cp	4
	jr	nz,TCP_ERROR2

	ld	a,(CON_NUM)
	inl	TCP_CLOSE
	print	BUFOVF_S
	jp	TERMINATE
TCP_ERROR2:

	;* Otherwise the error is "Connection is closed"
	;  (cannot be "Invalid state for sending", since the
	;  connection is either CLOSED, ESTABLISHED or CLOSE-WAIT;
	;  and we assume that it is not "Invalid connection handle"):
	;  Print the cause and finish

	print	TWO_NL_S
	ld	a,(CON_NUM)
	inl	TCP_STATUS
	ld	de,TCPCLOSED_T
	call	GET_STRING
	ld	c,_STROUT
	call	DOS
	jp	TERMINATE


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

	push	af,hl
	ld	a,(#80)
	ld	c,a	;Adds 0 at the end
	ld	b,0	;(required under DOS 1)
	ld	hl,#81
	add	hl,bc
	ld	(hl),0
	pop	hl,af

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
	jr	z,PASASPC

	inc	ix	;Increases number of parameters
PASAPAR:	ld	a,(hl)	;Walks through the parameter
	or	a
	jr	z,ENDPNUM
	cp	" "
	inc	hl
	jr	z,PASASPC
	jr	PASAPAR

	;* Here we know already how many parameters are available

ENDPNUM:	ld	a,ixl	;Error if the parameter to extract
	cp	ixh	;is greater than the total number of
	jr	c,EXTPERR	;parameters available

	ld	hl,#81
	ld	b,1	;B = current parameter
PASAP2:	ld	a,(hl)	;Skips spaces until the next
	cp	" "	;parameter is found
	inc	hl
	jr	z,PASAP2

	ld	a,ixh	;If it is the parameter we are
	cp	b	;searching for, we extract it,
	jr	z,PUTINDE0	;else...

	inc	B
PASAP3:	ld	a,(hl)	;...we skip it and return to PASAP2
	cp	" "
	inc	hl
	jr	nz,PASAP3
	jr	PASAP2

	;* Parameter is located, now copy it to the user buffer

PUTINDE0:	ld	b,0
	dec	hl
PUTINDE:	inc	b
	ld	a,(hl)
	cp	" "
	jr	z,ENDPUT
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

CLOSE_END:	ld	a,(CON_NUM)
	cp	#FF
	jr	z,TERMINATE

	ld	a,(#FBEB)	;Checks CTRL key status
	bit	1,a	;in order to decide whether
	ld	ix,TCP_CLOSE	;CLOSE or ABORT must be executed
	ld	de,USERCLOS_S	;(always ABORT in case of CTRL-C)
	jr	nz,CLOSE_END2	;and which message to show
	ld	ix,TCP_ABORT	;("user closed" or "user aborted")
	ld	de,USERAB_S
CLOSE_END2:	push	de
	ld	a,(CON_NUM)
	ld	hl,CLOSE_END3
	push	hl

	jp	(ix)
CLOSE_END3:	pop	de
	ld	c,_STROUT
	call	DOS
	jr	TERMINATE


;--- Program terminations

	;* Invalid parameter

INVPAR:	print	INVPAR_S
	jp	TERMINATE

	;* Missing parameter

MISSPAR:	print	MISSPAR_S
	jp	TERMINATE

	;* Generic termination routine

TERMINATE:
	ld	a,2	;Restores TPA on page 1
	call	PUT_P1

	ld	a,(DOS2)	;Under DOS 2, the CTRL-C
	or	a	;control routine has to be cancelled first
	ld	de,0
	ld	c,_DEFAB
	call	nz,DOS

	ld	c,_TERM0
	jp	DOS


;--- Prints LF

LF:	ld	e,10
	ld	c,_CONOUT
	jp	DOS


;--- Routine to switch segment on page 1,
;    it is obtained from INL page 3 code
;    so it is independent of the DOS version

PUT_P1:	ds	3


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


;--- EXTNUM16
;      Extracts a 16-bit number from a zero-finished ASCII string
;    Input:  HL = ASCII string address
;    Output: BC = Extracted number
;            Cy = 1 if error (invalid string)

EXTNUM16:	call	EXTNUM
	ret	c
	jp	c,INVPAR	;Error if >65535

	ld	a,e
	or	a	;Error if the last char is not 0
	ret	z
	scf
	ret


;--- NAME: EXTNUM
;      Extracts a 5 digits number from an ASCII string
;    INPUT:      HL = ASCII string address
;    OUTPUT:     CY-BC = 17 bits extracted number
;                D  = number of digits of the number
;                     The number is considered to be completely extracted
;                     when a non-numeric character is found,
;                     or when already five characters have been processed.
;                E  = first non-numeric character found (or 6th digit)
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


;--- CHECK_KEY: Calls a DOS routine so the CTRL-C pressing
;    can be detected by DOS and the program can be aborted.
;    Also, returns A<>0 if a key has been pressed.

CHECK_KEY:	ld	e,#FF
	ld	c,_DIRIO
	jp	DOS


;--- BYTE2ASC: Converts the number A into a string without termination
;    Puts the string in (IX), and modifies IX so it points after the string
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
	jr	nc,B2A_2D	;If ti is 1XY with X>0
	ld	(ix),"0"	;If it is 10Y
	inc	ix
	jr	B2A_1D

	;--- Between 200 and 255

B2A_2XX:	ld	(ix),"2"
	sub	200
	jr	B2A_XXX


;--- GET_STRING: Returns the string associated to a number, or "Unknown".
;    Input:  DE = Pointer to a table of numbers and strings, with the format:
;                 db num,"String$"
;                 db num2,"String2$"
;                 ...
;                 db 0
;            B = Associated number
;    Output: DE = Pointer to the string

GET_STRING:	ld	a,(de)
	inc	de
	or	a	;String not found: return "Unknown"
	jr	nz,LOOP_GETS2
	ld	de,STRUNK_S
	ret

LOOP_GETS2:	cp	b	;The number matches?
	ret	z

LOOP_GETS3:	ld	a,(de)	;No: pass to the next one
	inc	de
	cp	"$"
	jr	nz,LOOP_GETS3
	jr	GET_STRING

STRUNK_S:	db	"Unknown$"


;***************************
;***                     ***
;***   DATA, VARIABLES   ***
;***                     ***
;***************************

;--- INL zones

INL_SEG1:	db	0
;INL_SEG2:       db      0      ;--- Not needed
;INL_P3DIR:      dw      0      ;--- in this program

;--- Connection data, it is filled in with the command line parameters

IP_REMOTE:	db	0,0,0,0
PORT_REMOTE:	dw	0
PORT_LOCAL:	dw	#FFFF	;Random port if none is specified
PASSIVE_OPEN:	db	0

;--- Variables

CON_NUM:	db	#FF	;Connection handle
INPUT_MODE:	db	0	;0 for line mode, #FF for character mode
GETCHAR_FUN:	db	_CONIN	;_CONIN for echo ON, _INNOE for echo OFF
DOS2:	db	0	;0 for DOS 1, #FF for DOS 2

;--- Text strings

PRESENT_S:
	db	"TCP Console (simplified Telnet client) for InterNestor Lite 1.03",13,10
	db	"By Konami Man, 4-2005",13,10,10,"$"

INFO_S:	db	"Usage: TCPCON <host name>|<remote IP address> <remote port> [<local port>] [P]",13,10,10
	db	"       <host name> can be 0.0.0.0 to accept a connection from any host",13,10
	db	"                   (only for passive connections)",13,10
	db	"       <local port>: if not specified, a random port will be selected",13,10
	db	"       P: Use passive connection open",13,10,"$"

NOINS_S:	db	"*** InterNestor Lite is not installed",13,10,"$"
INVPAR_S:	db	"*** Invalid parameter(s)",13,10,"$"
MISSPAR_S:	db	"*** Missing parameter(s)",13,10,"$"
BUFOVF_S:	db	"*** Output buffer overflow",13,10,"$"
ERROR_S:	db	"*** ERROR: $"
OPENING_S:	db	"Opening connection (press ESC to cancel)... $"
RESOLVING_S:	db	"Resolving host name... $"
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
USERCLOS_S:	db	13,10,"*** Connection closed by user",13,10,"$"
USERAB_S:	db	13,10,"*** Connection aborted by user",13,10,"$"
LINE_S:	db	"line     "
CHAR_S:	db	"character"
ON_S:	db	"ON "
OFF_S:	db	"OFF"
ASTERISK_S:	db	"*** $"

	;* Host name resolution

RESOLVERR_S:	db	13,10,"ERROR "
RESOLVERRC_S:	ds	6	;Leave space for "<code>: $"
RESOLVOK_S:	db	"OK: "
RESOLVIP_S:	ds	16	;Space for "xxx.xxx.xxx.xxx$"
TWO_NL_S:	db	13,10
ONE_NL_S:	db	13,10,"$"

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
	db	16,"Server(s) not responding to queries$"
	db	17,"Total operation timeout expired$"
	db	19,"Internet connection lost$"
	db	20,"Dead-end reply (not containing answers nor redirections)$"
	db	21,"Answer is truncated$"
	db	0

	;* TCP_OPEN errors

TCPOPERRS_T:	db	1,"Too many TCP connections opened$"
NOCON_S:	db	2,"Not connected to Internet$"
	db	3,"Connection already exists, try another local port number$"
		db	4,"Unespecified remote socket is not allowed on active connections$"
	db	5,"Invalid user timeout value$"	;Should never occur
		db	0

	;* TCP close reasons

TCPCLOSED_T:
PEERCLOSE_S:	db	1,"*** Connection closed by peer$"	;Actually local CLOSE, but we close only when the peer closes
	db	2,"*** Connection locally aborted$"
	db	3,"*** Connection refused (RST received)$"
	db	4,"*** Data sending timeout expired$"
	db	5,"*** Connection timeout expired$"
	db	6,"*** Internet connection lost$"
	db	7,"*** Destination host is unreachable$"
	db	0

;--- Buffer for the remote host name

HOST_NAME:	;

;--- Generic temporary buffer for data send/receive
;    and for parameter parsing

BUFFER:	equ	HOST_NAME+256
