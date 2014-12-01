	;--- TelNestor 1.0
	;    A telnet client for InterNestor Suite
	;    By Konami Man, 2-2002
	;    Use: TELNEST <host name>|<IP address> [<remote port>] [P]
	;         Append P to open connection in passive mode

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

CSRY:	equ	#F3DC	;del cursor
CSRX:	equ	#F3DD	;Guarda las coordenadas actuales

CALSLT:	equ	#001C	;Llama a IX en el slot IY
ENASLT:	equ	#0024	;Slot swithcing BIOS routine
LDIRMV:	equ	#0059	;HL(VRAM)->DE(RAM), BC bytes
LDIRVM:	equ	#005C	;HL(RAM)->DE(VRAM), BC bytes
POSIT:	equ	#00C6	;LOCATE H,L
KILBUF:	equ	#0156	;Borra el bufer del teclado

	;--- Codigos de caracteres telnet

EOR:	equ	239
SE:	equ	240
NOP:	equ	241
DM:	equ	242
BRK:	equ	243
IP:	equ	244
AO:	equ	245
AYT:	equ	246
EC:	equ	247
EL:	equ	248
GA:	equ	249
SB:	equ	250
WILL:	equ	251
WONT:	equ	252
DO:	equ	253
DONT:	equ	254
IAC:	equ	255

OP_BINARY:	equ	0	;Opciones soportadas
OP_GA:	equ	3
OP_ECHO:	equ	1
OP_EOR:	equ	25

	;--- Level 4 module (TCP) calls

TCP_OPEN:	equ	#8021	;Open a connection
TCP_CLOSE:	equ	#8024	;Close a connection
TCP_ABORT:	equ	#8027	;Abort a connection
TCP_SEND:	equ	#802A	;Send data
TCP_RCV:	equ	#802D	;Receive data
TCP_STATUS:	equ	#8030	;Get connection status
TCP_FLUSH_OUT:	equ	#8033	;Flush outgoing data queue

	;--- IP calls (for resolver)

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

	;--- Obtains other parameters, if any

	ld	a,2	;Checks 3rd parameter
	call	MOREPARS
	ld	a,3	;Checks 4th parameter
	call	MOREPARS
	ld	a,4
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

MOREP_OK1:	ld	(PORT_REMOTE),bc
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

WAIT_OPEN:	call	HALT

	ld	a,(#FBEC)	;Bit 2 of #FBEC is 0
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

	ld	hl,INIT_COMMANDS	;Envia comandos iniciales
	ld	bc,INIT_COMM_END-INIT_COMMANDS
	ld	a,(CON_NUM)
	ld	d,1
	call	TCP_SEND


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
	;    Va cogiendo caracteres hasta completar una linea

	call	GET_TDATA
	jr	c,NO_RCV

	or	a	;0 significa CRLF
	jr	nz,NO_CHAR0

	call	CRLF
	jr	NO_RCV

NO_CHAR0:	ld	e,a	;Imprime el caracter, y si no
	ld	c,_CONOUT	;era salto de linea, mira si hay mas
	push	af	;caracteres disponibles
	call	DOS
	pop	af
	cp	13
	jr	z,NO_RCV
	cp	10
	jr	nz,MAIN_LOOP
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

	push	af
	call	EMPTY_KBUF
	pop	af

	;--- F1? Then print options screen

CHECK_F1:	bit	5,a
	jr	nz,CHECK_F2

	call	DO_OPTIONS
	jr	END_F_KEY

	;--- F2? Then toggle character/line mode

CHECK_F2:	bit	6,a
	jr	nz,CHECK_F3

	ld	a,(INPUT_MODE)
	cpl
	ld	(INPUT_MODE),a

	ld	de,INPTOG0_S
	or	a
	jr	z,CHECK_F22
	ld	de,INPTOG1_S
CHECK_F22:	;                        ;Prints change information
	ld	c,_STROUT	;and updates help text
	call	DOS
	jr	END_F_KEY

	;--- F3? Then toggle local echo ON/OFF

CHECK_F3:	ld	a,(GETCHAR_FUN)
	xor	9	;Toggles 1 <--> 8
	ld	(GETCHAR_FUN),a	;(the DOS function used to get char.)

	cp	1
	ld	de,ECHOTOG0_S
	jr	z,CHECK_F32
	ld	de,ECHOTOG1_S
CHECK_F32:	;                        ;Prints change information
	ld	c,_STROUT	;and updates help text
	call	DOS

;END_F_KEY:       ;

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

	ld	bc,2
	cp	"1"
	jr	nz,KKSEND
	ld	bc,536
KKSEND:	ld	(KKSIZE),bc

	pop	hl	;If character is CR, sends also
	cp	13	;a LF
	;ld      bc,1
	jr	nz,GET_INPUT_C2

	ld	a,10
	ld	(SEND_BUF+3),a
	ld	a,l	;If local echo is ON, the LF
	cp	1	;must be explicitly printed
	call	z,LF
	ld	bc,(KKSIZE)

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

	call	HALT
	jp	MAIN_LOOP



;******************************
;***                        ***
;***   AUXILIARY ROUTINES   ***
;***                        ***
;******************************


;--- HALT: Espera a la siguiente interrupcion

HALT:	push	af,bc,de,hl
	ld	a,(#FC9E)
	ld	b,a
HALT2:	ld	a,(#FC9E)
	cp	b
	jr	nz,HALT3
	push	bc
	ld	c,#B
	call	5
	pop	bc
	jr	HALT2
HALT3:	pop	hl,de,bc,af
	ret


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


;--- GET_TDATA: Obtiene un byte de datos segun las reglas Telnet.
;               Si se recibe un comando, se actua adecuadamente.
;               si el modo remoto NO es binario, devuelve "1" para CRLF

GET_TDATA:	call	GET_DATA
	ret	c	;Hay bytes disponibles?

	ld	b,a	;El byte anterior era IAC
	ld	a,(PROCESSING_COM)
	or	a
	ld	a,b
	jp	nz,PROCESS_COM

	cp	IAC
	jp	z,ES_IAC

	;--- No es IAC ni un comando:
	;    Si LOC_ECHO=2 debemos devolver
	;    el caracter de vuelta

	ld	b,a
	ld	a,(LOC_ECHO)
	cp	2
	jr	nz,NO_LOCECHO

	ld	a,b
	push	bc
	ld	(BUFER),a
	ld	a,(CON_NUM)
	ld	hl,BUFER
	ld	bc,1
	ld	d,1
	call	TCP_SEND
	pop	bc
NO_LOCECHO:	;

	ld	a,(REM_BIN)
	cp	2
	ld	a,b
	jr	z,GTD_CHKEOL

	;--- Comprueba que sea un caracter permitido
	;    (>31 o 10,13,7,8,9,11,12)
	;    y realiza la transformacion adecuada a CR-LF
	;    si es necesario

	cp	32
	jr	nc,GTD_ESBIN

	cp	7
	ret	z
	cp	8
	ret	z
	cp	9
	ret	z
	cp	11
	ret	z
	cp	12
	ret	z

GTD_CHKEOL:	cp	13
	jr	z,ES_CRLF
	cp	10
	jr	z,ES_CRLF

	ld	a,(REM_BIN)	;Caracter desconocido:
	cp	2	;En modo ASCII lo ignoramos
	ld	a,b
	jr	nz,GET_TDATA
	or	a
	ret

ES_CRLF:	ld	a,(EOLC)
	or	a
	ld	a,b
	jr	z,GTD_ESBIN

	;Aqui sabemos que el caracter es CR o LF
	;y hay que convertirlo

	ld	d,a	;D=Actual, E=Anterior,
	ld	a,(WAS_CRLF)	;y actualizamos WAS_CRLF
	ld	e,a	;Anterior=0 si no era CR o LF
	ld	a,d
	ld	(WAS_CRLF),a

	ld	a,e	;Anterior era normal: devuelve 0
	or	a
	ld	a,0
	ret	z

	ld	a,e	;Anterior igual que actual:
	cp	d	;Devuelve 0
	ld	a,0
	ret	z

	ld	hl,#0D0A	;Anterior era LF y actual CR:
	call	COMP	;Es una secuencia CR-LF
	ld	a,0	;detras de otra, asi que
	ccf
	ret	z	;devuelve 0

	jp	GET_TDATA	;Ant CR y actual LF: ignorar

	;--- Comprueba si es un comando y lo procesa

GTD_ESBIN:	ld	b,a
	xor	a
	ld	(WAS_CRLF),a
	ld	a,b

	ld	b,a	;Se ignora el caracter
	ld	a,(ERASING_LINE)	;si se estaba borrando la linea
	or	a
	ld	a,b
	ret	z
	jp	GET_TDATA

ES_IAC:	ld	a,#FF
	ld	(PROCESSING_COM),a
	jp	GET_TDATA

	;>>> Al saltar aqui, tenemos el byte recogido en A y en B

PROCESS_COM:	cp	255	;Era el byte de datos 255?
	jr	nz,PROC_COM2
	xor	a
	ld	(PROCESSING_COM),a
	ld	a,255
	ret
PROC_COM2:	;

	ld	a,(PROCESSING_COM)
	cp	IAC
	jr	nz,PROC_COM3
	ld	a,b

	;--- En este punto sabemos que el byte anterior era IAC

	cp	251	;Es WILL/WONT/DO/DONT:
	jr	c,NO_WD	;lo almacena
	ld	(PROCESSING_COM),a
	or	a
	jp	GET_TDATA
NO_WD:	;

	xor	a
	ld	(PROCESSING_COM),a
	ld	a,b

	cp	EL	;Erase Line?
	jr	nz,PROC_NOEL
	ld	a,(REM_BIN)
	cp	2
	jp	z,GET_TDATA	;Se ignora en modo binario
	ld	a,#FF
	ld	(ERASING_LINE),a
	jp	GET_TDATA
PROC_NOEL:	;

	cp	EC	;Erase Character? Devuelve 8
	jr	nz,PROC_NOEC
	ld	a,127
	or	a
	ret
PROC_NOEC:	;

	cp	AO	;Abort Output?
	jr	nz,PROC_NOAO
	ld	a,(CON_NUM)
	call	TCP_FLUSH_OUT
	jp	GET_TDATA
PROC_NOAO:	;

	cp	AYT	;Are You there? Envia respuesta
	jr	nz,PROC_NOAYT
	ld	a,(CON_NUM)
	ld	hl,AYTREP_S
	ld	bc,AYTREP_S_END-AYTREP_S
	ld	d,1
	call	TCP_SEND
	print	AYTRCV_S
	jp	GET_TDATA
PROC_NOAYT:	;

	cp	BRK	;Break? Lo notifica
	jr	nz,PROC_NOBRK
	print	BRKRCV_S
	jp	GET_TDATA
PROC_NOBRK:	;

	jp	GET_TDATA	;Cualuier otro: lo ignora

PROC_COM3:	;--- En este punto sabemos que el byte anterior era
	;    WILL/WONT/DO/DONT; lo tenemos en A, y la opcion en B

	ld	c,a	;Byte anterior ahora en C
	xor	a
	ld	(PROCESSING_COM),a

	;* Opciones SUPRESS-GA, ECHO, EOR, BINARY:
	;Se usa el metodo "que si que te oigo"
	;(siempre se aceptan, tanto locales como remotos)
	;Otras opciones: DO se responde con WONT, WILL con DONT
	;(aqui tenemos la opcion en B y el comando en C)

PROC_NOBIN:	ld	a,b
	cp	OP_GA
	ld	hl,LOC_GA
	jr	z,OK_OPTION
	cp	OP_ECHO
	ld	hl,LOC_ECHO
	jr	z,OK_OPTION
	cp	OP_EOR
	ld	hl,LOC_EOR
	jr	z,OK_OPTION
	cp	OP_BINARY
	ld	hl,LOC_BIN
	jr	z,OK_OPTION

	;Opcion desconocida:
	;DO->WONT, WILL->DONT, DONT y WONT ignorados

	ld	a,c
	cp	DO
	jr	nz,UNKOP_NODO
	ld	a,b
	call	SEND_WONT
	jp	GET_TDATA
UNKOP_NODO:	cp	WILL
	jp	nz,GET_TDATA
	ld	a,b
	call	SEND_DONT
	jp	GET_TDATA

	;Opcion conocida: HL contiene la direccion
	;de su variable LOC, A el numero de opcion

OK_OPTION:	;ld      b,a

	;WILL: Si REM=0, poner a 2 y enviar DO
	;      Si REM=1, poner a 2
	;      Si REM=2, ignorar

OK_OPCION_0:	ld	a,c
	cp	WILL
	jr	nz,OK_OPCION_1

	inc	hl
	ld	a,(hl)
	cp	2
	jp	z,GET_TDATA

	cp	1
	jr	z,OK_OPCION_0_1
	push	hl
	ld	a,b
	call	SEND_DO
	pop	hl
OK_OPCION_0_1:	ld	(hl),2
	jp	GET_TDATA

	;WONT: Si REM=0, ignorar
	;      Si REM=1, poner a 0
	;      Si REM=2, poner a 0 y enviar DONT

OK_OPCION_1:	;ld      a,c
	cp	WONT
	jr	nz,OK_OPCION_2

	inc	hl
	ld	a,(hl)
	or	a
	jp	z,GET_TDATA

	cp	1
	jr	z,OK_OPCION_1_1
	push	hl
	ld	a,b
	call	SEND_DONT
	pop	hl
OK_OPCION_1_1:	ld	(hl),0
	jp	GET_TDATA

	;DO: Si LOC=0, poner a 2 y enviar WILL
	;    Si LOC=1, poner a 2
	;    Si LOC=2, ignorar

OK_OPCION_2:	;ld      a,c
	cp	DO
	jr	nz,OK_OPCION_3

	ld	a,(hl)
	cp	2
	jp	z,GET_TDATA

	cp	1
	jr	z,OK_OPCION_2_1
	push	hl
	ld	a,b
	call	SEND_WILL
	pop	hl
OK_OPCION_2_1:	ld	(hl),2
	jp	GET_TDATA

	;DONT: Si LOC=0, ignorar
	;      Si LOC=1, poner a 0
	;      Si LOC=2, enviar WONT y poner a 0

OK_OPCION_3:	ld	a,(hl)
	or	a
	jp	z,GET_TDATA

	cp	1
	jr	z,OK_OPCION_3_1
	push	hl
	ld	a,b
	call	SEND_WONT
	pop	hl
OK_OPCION_3_1:	ld	(hl),0
	jp	GET_TDATA


;--- GET_DATA: Obtiene un byte de datos en A de la conexion,
;              usando un bufer de 256 bytes

GET_DATA:	ld	a,(GDATA_COUNT)
	or	a
	jr	z,GDATA_NEW
	dec	a
	ld	(GDATA_COUNT),a
	ld	hl,(GDATA_PNT)
	ld	a,(hl)
	inc	hl
	ld	(GDATA_PNT),hl
	or	a
	ret

GDATA_NEW:	ld	hl,GDATA_BUF
	ld	a,(CON_NUM)
	ld	bc,256
	ld	d,0
	call	TCP_RCV
	ret	c

	dec	bc
	ld	a,c
	ld	(GDATA_COUNT),a
	ld	hl,GDATA_BUF+1
	ld	(GDATA_PNT),hl
	ld	a,(GDATA_BUF)
	or	a
	ret

GDATA_COUNT:	db	0
GDATA_PNT:	dw	0


;--- Envio de comandos
;    entrada: A = Comando

SEND_WILL:	ld	b,WILL
	jr	SEND_COMM
SEND_WONT:	ld	b,WONT
	jr	SEND_COMM
SEND_DO:	ld	b,DO
	jr	SEND_COMM
SEND_DONT:	ld	b,DONT

SEND_COMM:	ld	(BUFER+2),a
	ld	a,b
	ld	(BUFER+1),a
	ld	a,IAC
	ld	(BUFER),a
	ld	hl,BUFER
	ld	a,(CON_NUM)
	ld	bc,3
	ld	d,1
	call	TCP_SEND
	ret

;--- Envio del caracter A precedido de IAC

SEND_CHAR:	ld	(BUFER+1),a
	cp	DM
	ld	d,1	;DM lo envia urgente (SYNCH)
	jr	nz,SEND_CHAR2
	inc	d
SEND_CHAR2:	ld	a,IAC
	ld	(BUFER),a
	ld	hl,BUFER
	ld	a,(CON_NUM)
	ld	bc,2
	call	TCP_SEND
	ret

CRLF:	ld	e,13
	ld	c,_CONOUT
	call	5
	ld	e,10
	ld	c,_CONOUT
	jp	5


;--- DO_OPTIONS: Muestra la pantalla de opciones

DO_OPTIONS:	;

	;--- Primero guarda la pantalla actual
	;    y las coordenadas del cursor

	ld	hl,0
	ld	de,#7000
	ld	bc,80*24
	ld	ix,LDIRMV
	ld	iy,(#FCC1-1)
	call	CALSLT
	ei

	ld	hl,(CSRY)
	ld	(OLD_Y),hl

	;--- Compone la pantalla a mostrar
	;    segun las opciones

	;Compone ECHOX_S y RECHO_S

DOOPT_COMP:	ld	a,(REM_ECHO)
	cp	2
	ld	hl,ECHO1_S
	ld	ix,ON_S
	jr	z,DOOPT_0
	ld	hl,ECHO0_S
	ld	ix,OFF_S
DOOPT_0:	ld	de,ECHOX_S
	ld	bc,ECHOX_S_END-ECHOX_S
	ldir
	push	ix
	pop	hl
	ld	de,RECHO_S
	ld	bc,3
	ldir

	;Compone BINARYX_S y RBINARY_S

	ld	a,(REM_BIN)
	cp	2
	ld	hl,BINARY1_S
	ld	ix,ON_S
	jr	z,DOOPT_1
	ld	hl,BINARY0_S
	ld	ix,OFF_S
DOOPT_1:	ld	de,BINARYX_S
	ld	bc,BINARYX_S_END-BINARYX_S
	ldir
	push	ix
	pop	hl
	ld	de,RBINARY_S
	ld	bc,3
	ldir

	;Compone SECHO_S

	ld	a,(LOC_ECHO)
	cp	2
	ld	hl,ON_S
	jr	z,DOOPT_2
	ld	hl,OFF_S
DOOPT_2:	ld	de,SECHO_S
	ld	bc,3
	ldir

	;Compone SBINARY_S

	ld	a,(LOC_BIN)
	cp	2
	ld	hl,ON_S
	jr	z,DOOPT_3
	ld	hl,OFF_S
DOOPT_3:	ld	de,SBINARY_S
	ld	bc,3
	ldir

	;Compone IMODE_S

	ld	a,(INPUT_MODE)
	or	a
	ld	hl,LINE_S
	jr	z,DOOPT_4
	ld	hl,CHAR_S
DOOPT_4:	ld	de,IMODE_S
	ld	bc,9
	ldir

	;Compone LECHO_S

	ld	a,(GETCHAR_FUN)
	cp	1
	ld	hl,ON_S
	jr	z,DOOPT_5
	ld	hl,OFF_S
DOOPT_5:	ld	de,LECHO_S
	ld	bc,3
	ldir

	;Compone EOLC_S

	ld	a,(EOLC)
	or	a
	ld	hl,OFF_S
	jr	z,DOOPT_6
	ld	hl,ON_S
DOOPT_6:	ld	de,EOLC_S
	ld	bc,3
	ldir

	;--- Imprime la pantalla

	print	OPTIONS_S

	;--- Espera que se pulse una tecla y actua segun cual sea

DOOPT_WKEY:	ld	a,(#FBEB)	;Espera a que F1 deje de estar pulsada
	bit	5,a
	jr	z,DOOPT_WKEY

	call	EMPTY_KBUF

DOOPT_KEY:	ld	a,(#FBEB)	;Se pulsa F1?
	bit	5,a
	jp	z,DOOPT_END

	ld	c,_DIRIO
	ld	e,#FF
	call	5
	or	a
	jr	z,DOOPT_KEY

	or	%00100000	;Convierte a minuscula

	;0: Envia BEEP

DOOPT_BEEP:	cp	"0"
	jr	nz,DOOPT_NUM

	ld	a,7
	ld	(BUFER),a
	ld	hl,BUFER
	ld	bc,1
	ld	a,(CON_NUM)
	ld	d,1
	call	TCP_SEND

	jp	DOOPT_END

	;Numero?

DOOPT_NUM:	cp	"1"
	jr	c,DOOPT_KEY
	cp	"8"+1
	jr	nc,DOOPT_NONUM

	;Numero entre 1 y 7: Envia el codigo apropiado, que es
	;241+numero

	add	241-"0"
	call	SEND_CHAR
	jp	DOOPT_END
DOOPT_NONUM:	;

	;9: Envia EOR

	cp	"9"
	jr	nz,DOOPT_L

	ld	a,EOR
	call	SEND_CHAR
	jp	DOOPT_END

	;L: Eco local on/off

DOOPT_L:	cp	"l"
	jr	nz,DOOPT_M

	ld	a,(GETCHAR_FUN)
	xor	9	;Toggles 1 <--> 8
	ld	(GETCHAR_FUN),a	;(the DOS function used to get char.)

	jp	DOOPT_END

	;M: Modo de entrada

DOOPT_M:	cp	"m"
	jr	nz,DOOPT_E

	ld	a,(INPUT_MODE)
	cpl
	ld	(INPUT_MODE),a

	jp	DOOPT_END

	;E: Pide eco o no eco

DOOPT_E:	cp	"e"
	jr	nz,DOOPT_B

	ld	a,(REM_ECHO)
	cp	2
	jr	z,DOOPT_E2

	ld	a,OP_ECHO	;No estaba en uso: enviar DO
	call	SEND_DO
	ld	a,1
	ld	(REM_ECHO),a
	jp	DOOPT_END

DOOPT_E2:	ld	a,OP_ECHO	;Opcion ya en uso: enviar DONT
	call	SEND_DONT
	jp	DOOPT_END

	;B: Pide transmision binaria o no

DOOPT_B:	cp	"b"
	jr	nz,DOOPT_C

	ld	a,(REM_BIN)
	cp	2
	jr	z,DOOPT_B2

	ld	a,#FF
	ld	a,OP_BINARY	;No estaba en uso: enviar DO
	call	SEND_DO
	ld	a,1
	ld	(REM_BIN),a
	jp	DOOPT_END

DOOPT_B2:	ld	a,OP_BINARY	;Opcion ya en uso: enviar DONT
	call	SEND_DONT
	jp	DOOPT_END

	;R: conversion de fin de linea o no

DOOPT_C:	cp	"r"
	jp	nz,DOOPT_KEY

	ld	a,(EOLC)
	cpl
	ld	(EOLC),a

	;jp      DOOPT_END

	;--- Salida: restaura pantalla y cursor,
	;    tras lo cual salta al bucle principal

DOOPT_END:	ld	de,0	;Restaura pantalla
	ld	hl,#7000
	ld	bc,80*24
	ld	ix,LDIRVM
	ld	iy,(#FCC1-1)
	call	CALSLT
	ei

	ld	hl,(OLD_Y)	;Restaura cursor
	ld	ix,POSIT
	ld	iy,(#FCC1-1)
	call	CALSLT
	ei

DOOPT_WEND:	ld	a,(#FBEB)	;Espera a que F1 deje de estar pulsada
	bit	5,a
	jr	z,DOOPT_WEND

	call	EMPTY_KBUF
	ret

;--- Borrado del bufer del teclado

	;ld      e,#FF
	;call    DOS
	;or      a
	;jr      nz,EMPTY_KBUF
	;ld      c,_DIRIO
EMPTY_KBUF:	ld	ix,KILBUF
	ld	iy,(#FCC1-1)
	call	CALSLT
	ei
	ret


;***************************
;***                     ***
;***   DATA, VARIABLES   ***
;***                     ***
;***************************

;--- Pseudo-TCB, it is filled in with the command line parameters

TCB:	;
IP_REMOTE:	db	0,0,0,0
PORT_REMOTE:	dw	23
PORT_LOCAL:	dw	23
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

OLD_X:	db	0
OLD_Y:	db	0

INIT_COMMANDS:	db	IAC,DO,OP_GA,IAC,WILL,OP_BINARY
	db	IAC,WILL,OP_EOR	;Comandos iniciales
INIT_COMM_END:	;

;--- Variables de estado para las opciones
;    "LOC_xxx" es para las opciones enviadas ("WILL"),
;    "REM_xxx" es para las opciones recibidas ("DO"),
;    0: no negociada, 1: requerida, 2: respondida positivamente

LOC_BIN:	db	1
REM_BIN:	db	0
LOC_GA:	db	0
REM_GA:	db	1
LOC_ECHO:	db	0
REM_ECHO:	db	0
LOC_EOR:	db	1
REM_EOR:	db	0

PROCESSING_COM:	db	0
ERASING_LINE:	db	0
WAS_CRLF:	db	0
EOLC:	db	0	;Conversion de CR/LF

;--- Text strings

PRESEN_S:	db	13,10,"TelNestor 1.0 - a telnet client for InterNestor Suite",13,10
	db	"By Konami Man, 5-2002",13,10,10,"$"
INFO_S:	db	"Use: TELNEST <host name>|<remote IP address> [<remote port>] [P]",13,10,10
	db	"     <remote port>: if not specified, port 23 is used",13,10
	db	"     Local port used is always 23",13,10
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
	db	"*** Press F1 for options screen",13,10,10,"$"
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
AYTRCV_S:	db	13,10,"*** AYT character received",13,10,"$"
BRKRCV_S:	db	13,10,"*** BRK character received",13,10,"$"
AYTREP_S:	db	"*** TelNestor 1.0 is here!",13,10
AYTREP_S_END:	;

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

;--- Pantalla de info/opciones

OPTIONS_S:	db	#C,"            ---=== TelNestor 1.0 - Options/Information screen ===---",13,10
	db	13,10
	db	"1. Send SYNCH (DM as urgent)       5. Send AYT (Are You there)",13,10
	db	"2. Send BRK (Break)                6. Send EC (Erase Character)",13,10
	db	"3. Send IP (Interrupt Process)     7. Send EL (Erase Line)",13,10
	db	"4. Send AO (Abort Output)          8. Send GA (Go Ahead)",13,10
	db	"9. Send EOR (End Of Record)        0. Send BEEP (ASCII 7)",13,10
	db	13,10
	db	"R. Toggle incoming end of line conversion ON/OFF",13,10
	db	"   (Converts single CR and LF to CR-LF sequence, even in binary mode)",13,10
	db	"L. Toggle local echo ON/OFF (in character mode only) - F2 when in program",13,10
	db	"M. Toggle input mode (character/line) - F3 when in program",13,10
ECHOX_S:	db	"E. Request peer to send echo    ",13,10
ECHOX_S_END:	;
BINARYX_S:	db	"B. Request peer to do binary transmission    ",13,10
BINARYX_S_END:	;
	db	">>> F1. Return to program",13,10
	db	13,10
	db	"Send echo: "
SECHO_S:	db	"OFF"
	db	"    Receive echo: "
RECHO_S:	db	"OFF"
	db	"    Send binary: "
SBINARY_S:	db	"OFF"
	db	"    Receive binary: "
RBINARY_S:	db	"OFF"
	db	13,10
	db	"Local echo: "
LECHO_S:	db	"OFF"
	db	"   Input mode: "
IMODE_S:	db	"character"
	db	"     End of line conversion: "
EOLC_S:	db	"OFF"
	db	13,10
	db	13,10
	db	"Inside the program:",13,10
	db	"Press ESC to close connection and exit.",13,10
	db	"Press CTRL-ESC, CTRL-C or CTRL-STOP to abort connection and exit."
	db	"$"

ECHO0_S:	db	"E. Request peer to send echo    ",13,10
ECHO1_S:	db	"E. Request peer to NOT send echo",13,10
BINARY0_S:	db	"B. Request peer to do binary transmission    ",13,10
BINARY1_S:	db	"B. Request peer to NOT do binary transmission",13,10
KKSIZE:	dw	0

;--- Buffer for sending data

SEND_BUF:	db	255	;Buffer size for _BUFIN

;--- Buffer for receive data

RCV_BUF:	equ	SEND_BUF+260

;--- Buffer for host name

HOST_NAME:	equ	RCV_BUF+2048

;--- Generic buffer

GDATA_BUF:	equ	HOST_NAME+260

BUFER:	equ	GDATA_BUF+260
