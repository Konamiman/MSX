	;--- TFTP server/client for the TCP/IP UNAPI 1.0
	;    By Konamiman, 4/2010

	;General features:

	;- Conforming with RFC1350, except for the indicated below.
	;- TFTP options are not supported
	;  (this implies that the block size is fixed to 512 bytes).
	;- Only binary transmission mode ("OCTET") is supported.
	;- No error messages are sent when unexpected or invalid
	;  packets are received. These messages are sent in case of timeout,
	;  disk error or file not found only.
	;- Disk errors are not captured under DOS 2.
	;- The maximum number of retransmissions for a packet
	;  before cancelling the transmission, and the retransmission
	;  intervals are fixed. These are defined in the
	;  RETX_CNT_MAX and RETX_TIMER_MAX constants.


	;.label	20	;Compass needs this

;****************************
;***                      ***
;***  MACROS & CONSTANTS  ***
;***                      ***
;****************************

	;--- Some constants

RETX_TIMER_MAX:	equ	3	;Seconds between retransmissions
RETX_CNT_MAX:	equ	5	;Maximum number of retransmissions

MAXFILES:	equ	1	;Maximum number of files that can be opened
				;on DOS 1

ENYEMAY:	equ	165	;Capital 'enye' in ASCII
ENYEMIN:	equ	164	;Small letter 'enye' in ASCII

TIME:	equ	#FC9E	;System timer, 50/60Hz

	;--- Macro to print a string

print:	macro	@s
	ld	de,@s
	ld	c,_STROUT
	call	5
	endm

	;--- System variables and routines

DOS:	equ	#0005	;DOS function calls entry point
ENASLT:	equ	#0024

TPASLOT1:	equ	#F342
ARG:	equ	#F847
EXTBIO:	equ	#FFCA

	;--- DOS function calls

	;* DOS 1

_TERM0:	equ	#00
_CONOUT:	equ	#02
_DIRIO:	equ	#06
_STROUT:	equ	#09
_FOPEN:	equ	#0F
_FCLOSE:	equ	#10
_SFIRST:	equ	#11
_SNEXT:	equ	#12
_FMAKE:	equ	#16
_SETDTA:	equ	#1A
_WRBLK:	equ	#26
_RDBLK:	equ	#27

	;* DOS 2

_FFIRST:	equ	#40
_FNEXT:	equ	#41
_OPEN:	equ	#43
_CREATE:	equ	#44
_CLOSE:	equ	#45
_READ:	equ	#48
_WRITE:	equ	#49
_PARSE:	equ	#5B
_DEFAB:	equ	#63
_EXPLAIN:	equ	#66
_DOSVER:	equ	#6F

	;--- TCP/IP UNAPI routines

TCPIP_GET_CAPAB:	equ	1
TCPIP_DNS_Q:	equ	6
TCPIP_DNS_S:	equ	7
TCPIP_UDP_OPEN:	equ	8
TCPIP_UDP_CLOSE:	equ	9
TCPIP_UDP_STATE:	equ	10
TCPIP_UDP_SEND:	equ	11
TCPIP_UDP_RCV:	equ	12
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

	;--- Other

TFTP_PORT:	equ	69


;**********************
;***                ***
;***  MAIN PROGRAM  ***
;***                ***
;**********************

	org	#100

	;-------------------------------
	;---  Common initialization  ---
	;-------------------------------

	;--- Prints the presentation

	print	PRESENT_S

	;--- Check if there are command line parameters.
	;    If not, print information and finish.

	ld	a,1
	ld	de,PARAM_BUFFER
	call	EXTPAR
	jr	nc,HAYPARS

TERMINFO:	print	INFO_S
	jp	TERMIN2
HAYPARS:	;

	;--- Checks the DOS version and set variable DOS2

	ld	c,_DOSVER
	call	5
	or	a
	jr	nz,NODOS2
	ld	a,b
	cp	2
	jr	c,NODOS2

	ld	a,#FF
	ld	(DOS2),a	;#FF for DOS 2, 0 for DOS 1
NODOS2:	;

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
	jp	TERMIN2
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

	;--- Check if this implementation can open UDP connections

	call	SET_UNAPI
	ld	b,1
	ld	a,TCPIP_GET_CAPAB
	call	CALL_UNAPI
	bit	2,h
	ld	de,NOUDP_S
	jp	z,PRINT_TERM

              ;--- Close transient UDP connections

	call	SET_UNAPI
	ld	a,TCPIP_UDP_CLOSE
	ld	b,0
	call	CALL_UNAPI

	;--- Check that there is still at least one free UDP connection

	ld	b,2
	ld	a,TCPIP_GET_CAPAB
	call	CALL_UNAPI
	ld	a,e
	or	a
	ld	de,NOFREEUDP_S
	jp	z,PRINT_TERM

	;--- Initialize the FCBs zone (only used in DOS1)

	xor	a
	ld	(FCBS),a

              ;> The following will do nothing on DOS 1
	ld	de,TERM_AB	;Routine to be executed
	ld	c,_DEFAB	;if CTRL-C/STOP is pressed
	call	5	;or a disk error is ABORTed

	;--- Check if the first parameter is /S...
	;    If so, server mode is activated

	ld	a,(PARAM_BUFFER)
	cp	"/"
	jp	nz,NO_SERVER
	ld	a,(PARAM_BUFFER+1)
	or	#20
	cp	"s"
	jp	z,TO_SERVER

	jp	INVPAR	;If it is "/<something>" with <something> != S
NO_SERVER:	;


	;--------------------------------------------
	;---  Common inicialization, client mode  ---
	;--------------------------------------------

	;--- Obtains the second parameter and decides whether to jump
	;    to send or to receive mode (establishes the GETPUT var)

	ld	de,PARAM_BUFFER
	ld	a,2
	call	EXTPAR
	jp	c,MISSPAR	;There is no second parameter?

	ld	a,(PARAM_BUFFER)
	or	#20
	cp	"g"
	jr	z,GETPUT_OK
	cp	"r"
	jr	z,GETPUT_OK	;"G" or "R": Receive

	ld	b,a
	ld	a,#FF
	ld	(GETPUT),a
	ld	a,b
	cp	"p"
	jr	z,GETPUT_OK
	cp	"s"	;"P" or "S": Send
	jp	nz,INVPAR	;Other: Error
	ld	a,(TIME)
	ld	(OLD_TIME),a
	ld	a,(TIME+1)
	ld	(OLD_TIME+1),a
GETPUT_OK:	;
	
	;--- Resolves the server name

	ld	a,1
	ld	de,PARAM_BUFFER
	call	EXTPAR

	print	RESOLVING_S

	call	SET_UNAPI
	ld	hl,PARAM_BUFFER
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

	ld	(REMOTE_IP),hl	;Saves the returned
	ld	(REMOTE_IP+2),de	;result in L.H.E.D

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

	jp	TERMINATE
RESOLV_END:	;

	;--- Jumps to sending or receiving mode

	ld	a,(GETPUT)
	or	a
	jp	z,TFTP_GET


	;----------------------------------------
	;---  Sending of a file, client mode  ---
	;----------------------------------------

TFTP_PUT:
	;--- Obtains the file name to send and opens it

	ld	a,3
	ld	de,PARAM_BUFFER
	call	EXTPAR
	jp	c,MISSPAR	;Missing parameter?

	ld	de,PARAM_BUFFER
	call	OPEN
	or	a
	jr	z,OPEN_PUT_OK

	ld	de,ERROPEN_S	;Error when opening the file?
	call	PRINT_DSKERR
	jp	TERMINATE
OPEN_PUT_OK:	;

	ld	a,b
	ld	(FH),a	;Saves the file identifier

	;--- Obtains the name to announce in the transfer (4th parameter);
	;    if it has not been specified, the real name of the file
	;    (which is in PARAM_BUFFER) will be used
	;    (the path will be ignored)

	ld	hl,PARAM_BUFFER	;From now on we suppose that
	ld	(FILEPART_PNT),hl	;transfer name=real name

	ld	a,(PARAM_BUFFER)
	ld	b,a	;EXTPAR puts 0 in PARAM_BUFFER if there is no param.
	push	bc	;Therefore we save the first byte of the real name
	ld	de,PARAM_BUFFER	;so we can restore it later if necessary.
	ld	a,4
	call	EXTPAR
	pop	bc
	jr	nc,TFTP_GET2

	;* 4th parameter did not exist:
	;  We obtain the address of the partial real name 
	;  (the real name without path)

	ld	a,b	;Restore the 1st byte of the real name
	ld	(PARAM_BUFFER),a

	ld	hl,PARAM_BUFFER
	call	GET_FILEPART
	ld	(FILEPART_PNT),hl
TFTP_GET2:	;

	;--- Open UDP connection with a random port

	call	INIT_TIDS_CLIENT

	;--- Composes the write request packet

	ld	hl,#0200	;WRQ code
	ld	(OUT_BUFFER),hl

	ld	hl,(FILEPART_PNT)	;Copies the file name
	call	STRLEN
	inc	bc	;To include the trailing 0
	push	bc
	ld	hl,(FILEPART_PNT)
	ld	de,OUT_BUFFER+2
	ldir

	ld	hl,OCTET_S	;Adds "OCTET" to the end
	ld	bc,6
	ldir

	pop	bc
	ld	hl,8	;To include the code
	add	hl,bc	;and the "OCTET" string
	push	hl
	pop	bc
	call	SEND_TFTP	;Sends packet

	print	WRQSENT_S
	
	call	INITIALIZE_PROGRESS ;Initialize progress indication

	;--- Initializes timers

	call	INIT_RETX

	ld	hl,0
	ld	(LAST_BLKID),hl


	;---------------------------
	;---  Sending main loop  ---
	;---------------------------

TFTP_PUT_LOOP:			;--- Checks if the confirmation packet has arrived

	call	CHECK_KEY

	call	RCV_TFTP
	jp	c,PUT_LOOP_W	;Jumps if there are not packets

	;* If it is an error packet, prints it and finishes

	ld	hl,(IN_BUFFER)
	ld	de,#0500
	call	COMP
	jr	nz,NO_PUTERR

	call	SHOW_TFTPE
	call	FCLOSE
	jp	GETPUT_END
NO_PUTERR:	;

	;* If it is an ACK packet, the ID is compared with the last one sent

	ld	hl,(IN_BUFFER)
	ld	de,#0400
	call	COMP
	jr	nz,PUT_LOOP_W	;If it is not ACK then it is ignored

	ld	a,(IN_BUFFER+2)
	ld	h,a
	ld	a,(IN_BUFFER+3)
	ld	l,a
	ld	de,(LAST_BLKID)
	call	COMP
	jr	nz,PUT_LOOP_W	;If the ID doesn't match then it is ignored

	;--- Correct ACK received

	;* If we had previosuly sent less than 512 bytes
	;  then the transmission was completed: finish

	ld	hl,(LAST_BLKID)	;If BLKID=0, no data has been
	ld	a,h	;sent yet, only the write request
	or	l	;has been sent
	jr	z,NO_LASTBLK

	ld	hl,(LAST_SND_SIZE)
	ld	de,512+4
	call	COMP
	jr	z,NO_LASTBLK

	print	TCOMPLETE_S
	call	FCLOSE
	jp	GETPUT_END
NO_LASTBLK:	;

	;* The next block is sent (it is read from the file)

SEND_BLOCK:	ld	hl,#0300	;DATA code
	ld	(OUT_BUFFER),hl

	ld	hl,(LAST_BLKID)	;Last block ID + 1
	inc	hl
	ld	(LAST_BLKID),hl
	ld	a,h
	ld	(OUT_BUFFER+2),a
	ld	a,l
	ld	(OUT_BUFFER+3),a

	ld	a,(FH)
	ld	b,a
	ld	de,OUT_BUFFER+4
	ld	hl,512
	call	READ	;Tries to read 512 bytes

	inc	hl	;To include the packet header
	inc	hl	;(DATA code +ID block)
	inc	hl
	inc	hl
	push	hl
	pop	bc
	call	SEND_TFTP	;Sends packet

	;--- Print progress info and
	;    go back to the main loop

	call	SHOW_PROGRESS
	jp	TFTP_PUT_LOOP

	;--- There are no packets available: wait

PUT_LOOP_W:	call	WAIT_TICK
	jp	nc,TFTP_PUT_LOOP

	call	FCLOSE	;Arrives here in case of timeout
	jp	GETPUT_END


	;---------------------------------------
	;---  Receiving a file, client mode  ---
	;---------------------------------------

TFTP_GET:	;--- Obtains the file name to announce in the transfer
			;    and composes the request packet

	ld	a,3
	ld	de,PARAM_BUFFER
	call	EXTPAR
	jp	c,MISSPAR	;The parameter is missing?

	ld	hl,#0100	;RRQ code
	ld	(OUT_BUFFER),hl

	ld	hl,PARAM_BUFFER
	call	STRLEN
	inc	bc	;To include the ending 0
	push	bc
	ld	hl,PARAM_BUFFER
	ld	de,OUT_BUFFER+2
	ldir

	ld	hl,OCTET_S	;Adds "OCTET" at the end
	ld	bc,6
	ldir

	pop	bc
	ld	hl,8	;To include the code
	add	hl,bc	;and the "OCTET" string
	ld	(LAST_SND_SIZE),hl	;The length is stored (used later)

	;--- Obtains the name of the file to be created locally.
	;    If the 4th parameter is specified then this one is used.
	;    Otherwise the 3rd parameter is used without the path info.

	ld	hl,PARAM_BUFFER	;The presence of the 4th parameter
	ld	(FILEPART_PNT),hl	;is supposed from now on

	ld	a,(PARAM_BUFFER)
	ld	b,a	;EXTPAR puts 0 in PARAM_BUFFER if there is no param.
	push	bc	;Therefore we save the first byte of the 3rd param
	ld	de,PARAM_BUFFER	;so we can restore it if necessary.
	ld	a,4
	call	EXTPAR
	pop	bc
	jr	nc,TFTP_GET4

	;* There was no 4th parameter: obtains the name part
	;  of the file from the 3rd parameter.

	ld	a,b
	ld	(PARAM_BUFFER),a
	ld	hl,PARAM_BUFFER
	call	GET_FILEPART
	or		a
	jr	z,TFTP_GET3

	call	PRINT_DSKERR	;The path was not correct: error
	jp	TERMINATE

TFTP_GET3:	;
	ld	(FILEPART_PNT),hl
TFTP_GET4:	;

	;--- Creates the file and opens it

	;* Creates the file

	ld	de,(FILEPART_PNT)
	call	CREATE
	or	a
	jr	z,CREATE_GET_OK

	ld	de,ERRCREATE_S	;Error when creating the file?
	call	PRINT_DSKERR
	jp	TERMINATE
CREATE_GET_OK:			;

	;* Now the file is opened

	ld	de,(FILEPART_PNT)
	call	OPEN
	or	a
	jr	z,OPEN_GET_OK

	ld	de,ERROPEN_S	;Error when opening the file?
	call	PRINT_DSKERR
	jp	TERMINATE
OPEN_GET_OK:	;

	ld	a,b
	ld	(FH),a

	;--- Open UDP connection with a random port

	call	INIT_TIDS_CLIENT

	;--- Sends read request packet

	ld	bc,(LAST_SND_SIZE)
	call	SEND_TFTP

	print	RRQSENT_S
	
	call	INITIALIZE_PROGRESS ;Initialize progress indication

	;--- Initializes timers

	call	INIT_RETX

	ld	hl,0
	ld	(LAST_BLKID),hl


	;-----------------------------
	;---  Receiving main loop  ---
	;-----------------------------

TFTP_GET_LOOP:			;--- Checks if a data packet has arrived

	call	CHECK_KEY

	call	RCV_TFTP
	jp	c,GET_LOOP_W
	ld	(LAST_RCV_SIZE),bc	;Jumps if there are not packets

	;* If it is an error packet, displays it and finishes

	ld	hl,(IN_BUFFER)
	ld	de,#0500
	call	COMP
	jr	nz,NO_GETERR

	call	SHOW_TFTPE
	call	FCLOSE
	jp	GETPUT_END
NO_GETERR:	;

	;* If it is a data packet, we check if the ID matches with the
	;  last one received + 1

	ld	hl,(IN_BUFFER)
	ld	de,#0300
	call	COMP
	jr	nz,GET_LOOP_W	;If it is not a data packet then it is ignored

	ld	a,(IN_BUFFER+2)
	ld	h,a
	ld	a,(IN_BUFFER+3)
	ld	l,a
	ld	de,(LAST_BLKID)
	inc	de
	call	COMP
	jr	nz,GET_LOOP_W	;If the ID does not match then it is ignored

	ld	(LAST_BLKID),de	;ID is updated

	;--- Correct data received

	;* Writes data in the file

	ld	hl,(LAST_RCV_SIZE)
	ld	de,4
	or	a
	sbc	hl,de	;Subtracts the header from the size
	ld	a,h
	or	l
	jr	z,GET_WROK	;Zero: nothing is written

	ld	de,IN_BUFFER+4
	ld	a,(FH)
	ld	b,a
	call	WRITE	;Writes data
	or	a
	jr	z,GET_WROK

	call	SEND_DSKERR
	call	PRINT_DSKERR	;Disk error: sends an error and finishes
	call	FCLOSE
	jp	GETPUT_END
GET_WROK:	;

	;--- Sends ACK packet

SEND_ACK:	ld	hl,#0400
	ld	(OUT_BUFFER),hl
	ld	hl,(LAST_BLKID)
	ld	a,h
	ld	(OUT_BUFFER+2),a
	ld	a,l
	ld	(OUT_BUFFER+3),a

	ld	bc,4
	call	SEND_TFTP

	;--- Shows progress info

	call	SHOW_PROGRESS

	;--- If the packet size was under 512 bytes, then the transfer
	;    finished; otherwise go back to the main loop.

	ld	hl,(LAST_RCV_SIZE)
	ld	de,512+4
	call	COMP
	jp	z,TFTP_GET_LOOP

	print	TCOMPLETE_S
	call	FCLOSE
	jp	GETPUT_END

	;--- There are no packets: wait

GET_LOOP_W:	call	WAIT_TICK
	jp	nc,TFTP_GET_LOOP

	call	FCLOSE	;Arrives here in case of timeout
	;jp      GETPUT_END


	;--- Common end when sending or receiving a file:
	;    If in client mode, finish.
	;    If in server mode, go back to the waiting loop.

GETPUT_END:	ld	a,(SERVER)
	or	a
	jp	z,TERMINATE
	jr	TO_SERVER2


	;-----------------------------------
	;---  Server mode, waiting loop  ---
	;-----------------------------------

TO_SERVER:	print	INSERV_S
	ld	a,#FF
	ld	(SERVER),a

              ld      a,(PARAM_BUFFER+2)
              or      #20
              cp      "p"
	jr	nz,TO_SERVER2
	ld	hl,TFTP_PORT
	ld	(LOCAL_TID),hl

TO_SERVER2:	print	WAITING_IN_S

	;--- Open TFTP standard port
	;    and wait until a packet is received or a key is pressed

SRV_MAIN_LOOP:
	call	OPEN_UDP_TFTP
	ld	hl,0	;Initializes IP and local port
	ld	(REMOTE_IP),hl	;so RCV_TFTP accepts
	ld	(REMOTE_IP+2),hl	;packets from any host

SRV_MAIN_LOOP2:	call	CHECK_KEY
	or	a
	jp	nz,TERMINATE	;If a key is pressed, finish

	call	RCV_TFTP
	jr	c,SRV_MAIN_LOOP2	;If there are not packets, wait again

	;--- Packet arrives: check if it is a sending request
	;    or a receiving request

	ld	hl,(IN_BUFFER)
	ld	de,#0200	;Writing request
	call	COMP
	jr	z,SRV_WRQ_RCVD

	ld	de,#0100	;Reading request
	call	COMP
	jr	nz,SRV_MAIN_LOOP


	;--------------------------------------------
	;---  Server mode, read request received  ---
	;--------------------------------------------

SRV_RRQ_RCVD:	print	RRQRCVD_S	;Prints the host's IP
	ld	de,IN_BUFFER+2
	call	PRINTZ
	print	ONE_NL_S

	;--- Checks if the required file exists

	ld	de,IN_BUFFER+2
	ld	b,0
	xor	a
	ld	ix,PARAM_BUFFER
	call	DIR
	or	a
	jr	z,RRQ_OK_1

	;* It does not exist: send error and go back to the waiting loop

	ld	a,1
	ld	de,FNOTF_S
	call	SEND_ERR

	ld	de,FNOTF_S
	call	PRINTZ
	print	TWO_NL_S
	jp	TO_SERVER2
RRQ_OK_1:	;

	;--- File is opened

	ld	de,IN_BUFFER+2
	call	OPEN
	or	a
	jr	z,RRQ_OK_2

	push	af	;Error?
	call	SEND_DSKERR
	pop	af
	ld	de,ERROPEN_S
	call	PRINT_DSKERR
	print	ONE_NL_S
	jp	TO_SERVER2
RRQ_OK_2:	;

	ld	a,b
	ld	(FH),a

	;--- Jump to the client mode main loop
	;    (jump to SEND_BLOCK, where theorically the request ACK that we
	;    would have sent if being in client mode would have been received)

	call	INIT_RETX	

	ld	hl,0
	ld	(LAST_BLKID),hl

	ld	a,#FF
	ld	(GETPUT),a
	call	INITIALIZE_PROGRESS ;Initialize progress indication

	jp	SEND_BLOCK


	;-----------------------------------------------
	;---  Server mode, writing request received  ---
	;-----------------------------------------------

SRV_WRQ_RCVD:	print	WRQRCVD_S	;Prints the host's IP
	ld	de,IN_BUFFER+2
	call	PRINTZ
	print	ONE_NL_S

	;--- The required file is created and then opened

	;* Creating

	ld	de,IN_BUFFER+2
	call	CREATE
	or	a
	ld	de,ERRCREATE_S
	jr	nz,WRQ_ERR

	;* Opening

	ld	de,IN_BUFFER+2
	call	OPEN
	or	a
	ld	de,ERROPEN_S
	jr	z,WRQ_OK_2

WRQ_ERR:	push	af,de	;Error when opening or creating?
	call	SEND_DSKERR
	pop	de,af
	call	PRINT_DSKERR
	print	ONE_NL_S
	jp	TO_SERVER2
WRQ_OK_2:	;

	ld	a,b
	ld	(FH),a

	;--- Jump to the receiving main loop of the
	;    client mode

	call	INIT_RETX	

	ld	hl,0
	ld	(LAST_BLKID),hl

	xor	a
	ld	(GETPUT),a
	call	INITIALIZE_PROGRESS ;Initialize progress indication

	;* Jump to the client mode main loop.
	;  We make the code to believe that we have previously received 512
	;  bytes of data, this is to avoid the code to exit the receiving loop
	;  prematurely.

	ld	hl,512+4
	ld	(LAST_RCV_SIZE),hl

	jp	SEND_ACK


;******************************
;***                        ***
;***   AUXILIARY ROUTINES   ***
;***                        ***
;******************************

;--- Segment switching routines for page 1,
;    these are overwritten with calls to
;    mapper support routines on DOS 2

PUT_P1:	out	(#FD),a
	ret
GET_P1:	in	a,(#FD)
	ret

TPASEG1:	db	2	;TPA segment on page 1


;--- Program terminations

PRINT_TERM:
	ld	c,_STROUT
	call	DOS
	jr	TERMINATE

	;* Invalid parameter

INVPAR:	print	INVPAR_S
	jp	TERMINATE

	;* Missing parameter

MISSPAR:	print	MISSPAR_S
	jp	TERMINATE

	;* Generic termination routine

TERMINATE:
	call	CLOSE_UDP

	ld	a,(TPASLOT1)
	ld	h,#40
	call	ENASLT

	ld	a,(TPASEG1)
	call	PUT_P1

	ld	a,(DOS2)	;Under DOS 2, the CTRL-STOP
	or	a	;control routine has to be cancelled first
	ld	de,0
	ld	c,_DEFAB
	call	nz,5

	call	FCLOSE

	;* Jumps here if PUT_P1 has not been obtained yet

TERMIN2:	ld	c,_TERM0
	jp	5


;--- CTRL-STOP pressing and disk error abort control routine, used
;    under DOS 2. We just ensure that the program will finish
;    through TERMINATE, so the opened file will be closed and 
;    the TPA will be restored in page 1 before returning to DOS.

TERM_AB:	pop	hl
	ld	de,GENERR_S
	call	PRINT_DSKERR	;The error is printed
	jp	TERMINATE


;--- PRINTZ: Prints a string finished with a 0 character
;            Input: DE = String

PRINTZ:	ld	a,(de)
	or	a
	ret	z
	push	de
	ld	e,a
	ld	c,2
	call	5
	pop	de
	inc	de
	jr	PRINTZ


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
	jr	nz,LOOP_GETS2
	ld	de,STRUNK_S
	ret

LOOP_GETS2:	cp	b	;Does it match?
	ret	z

LOOP_GETS3:	ld	a,(de)	;No: Go to the next
	inc	de
	cp	"$"
	jr	nz,LOOP_GETS3
	jr	GET_STRING

STRUNK_S:	db	"Unknown$"


; DE contains the number to be converted
; HL contains the destination of ASCII string
LEADING0EXCLUSION db 1
NOTFINALRET db 1
CURRENTDIGIT db '0'
NUM2DEC:
	push af
	push bc
	push de
	push hl
	ex	de,hl
	ld	a,1
	ld	(LEADING0EXCLUSION),a	
	ld	(NOTFINALRET),a	
	ld	a,(LAST_NUMBER_OF_CHARS)
	or	a
	jr	z,NUM2DECST
	ld	b,a
	ld	a,29
NUN2DECGOTOLEFT:	
	ld	(de),a
	inc	de
	dec	b
	jr	nz,NUN2DECGOTOLEFT
	
NUM2DECST:
	xor	a
	ld	(LAST_NUMBER_OF_CHARS),a
	ld	bc,-10000
	call	NUM1
	ld	bc,-1000
	call	NUM1
	ld	bc,-100
	call	NUM1
	ld	c,-10
	call	NUM1
	xor	a
	ld	(NOTFINALRET),a
	ld	c,b

NUM1:
	ld	a,'0'-1
NUM2:
	inc	a
	add	hl,bc
	jr	c,NUM2
	sbc	hl,bc
	
	ld	(de),a
	ld	(CURRENTDIGIT),a
	ld	a,(LEADING0EXCLUSION)
	or	a
	jr	z,NUMNOTEXCLUDINGLEADING0
	ld	a,(NOTFINALRET)
	or	a
	jr	z,NUMNOTEXCLUDINGLEADING0; last digit, so it does not matter if leading 0 ended or not
	ld	a,(CURRENTDIGIT)
	cp	'0'
	ret	z ;if a leading 0, do not want to increment HL
	xor a
	ld	(LEADING0EXCLUSION),a ;if here a digit that is not 0 has been found, so there are no more leading 0s
NUMNOTEXCLUDINGLEADING0:	
	inc	de ;not excluding, so increment address
	ld	a,(LAST_NUMBER_OF_CHARS)
	inc	a
	ld	(LAST_NUMBER_OF_CHARS),a ;increment how many chars will be printed
	ld	a,(NOTFINALRET)
	or	a
	ret	nz ;if not the final ret, we won't append $ and restore registers
	;If here, need to finalize string with '$' and restore registers
	ld	a,'$'
	ld	(de),a
	pop	hl
	pop	de
	pop	bc
	pop af
	ret

;--- STRLEN: Returns in BC the length of the string
;    pointed by HL and finished with 0

STRLEN:	ld	bc,0
STRLEN2:	ld	a,(hl)
	or	a
	ret	z
	inc	hl
	inc	bc
	jr	STRLEN2


;--- NAME: CLBUF
;      Clears the generic buffer for disk operations
;    INPUT:     -
;    OUTPUT:    -
;    REGISTERS: -

CLBUF:	push	hl,de,bc
	ld	hl,DISK_BUFFER
	ld	de,DISK_BUFFER+1
	ld	bc,70-1
	ld	(hl),0
	ldir
	pop	bc,de,hl
	ret


;--- NAME: MIN2MAY
;      Small letter to capital conversion
;    INPUT:     A = Character
;    OUTPUT:    A = Character in capital if it was small,
;                   otherwise it remains unchanged
;    REGISTERS: F

MIN2MAY:	cp	ENYEMIN
	jp	nz,NOENYE
	ld	a,ENYEMAY
	ret
NOENYE:	cp	"a"
	ret	c
	cp	"z"+1
	ret	nc
	and	%11011111
	ret


;--- NAME: CONVNAME
;      Normal file name <--> FCB format file name conversion
;      Invaled characters in the file name are NOT checked
;    INPUT:      HL = Source string
;                     FCB format:     12 characters without dot (the
;                                     exceeding ones are filled with spaces)
;                                     The first one is the drive number
;                                     (0: default, 1: A, 2: B, etc)
;                     Normal format:  Terminated with 0, 14 characters max.
;                                     Starts with drive letter and ":" if
;                                     the drive is not the default one (0)
;                DE = Destination string (the same as with HL applies)
;                Cy = 0 -> Normal format to FCB format
;                Cy = 1 -> FCB format to normal format
;     OUTPUT:    B  = Destination string length
;                     FCB format: always 12
;                     Normal format: does not include the trailing 0
;     REGISTERS: AF, C

CONVNAME:	push	de,hl
	jp	c,FCB2NOR
	xor	a
	ld	(EXTFLG),a
	jp	NOR2FCB
ENDCONV:	pop	hl,de
	ret

;--- Normal name -> FCB name

NOR2FCB:	push	de,hl,de	;Name zone is filled with spaces
	pop	hl
	inc	de
	ld	a," "
	ld	(hl),a
	ld	bc,11
	ldir
	pop	hl,de
	xor	a
	ld	(de),a	;Drive is set to 0

	inc	hl	;Checks if a drive has been specified.
	ld	a,(hl)	;If so, converts it to the appropriate drive number.
	cp	":"
	jp	nz,NOUN1
	dec	hl
	ld	a,(hl)
	call	MIN2MAY
	sub	"A"-1
	ld	(de),a
	inc	hl
	inc	hl
	inc	hl

NOUN1:	inc	de
	dec	hl
	xor	a	;Loop for the name
	ld	(EXTFLG),a
	ld	b,8
	call	N2FBUC

	ld	a,(EXTFLG)	;If it arrived to the end, the extension
	or	a	;is not processed.
	jp	nz,ENDCONV
	ld	a,#FF
	ld	(EXTFLG),a
	ld	b,3	;Loop for the extension
	call	N2FBUC
	ld	b,12
	jp	ENDCONV
;                                   ;Converts only the 8 or 3 first
N2FBUC:	ld	a,(hl)	;characters if it finds
	inc	hl
	cp	"*"	;a 0 (end of string),
	jp	z,AFND1	;a dot (end of name),
	cp	"."	;or an asterisk (converts it to "?")
	jp	z,PFND1
	or	a
	jp	z,EFND1
	call	MIN2MAY
	ld	(de),a
	inc	de
	djnz	N2FBUC

PASASOB:	ld	a,(EXTFLG)	;If it is the extension then nothing
	or	a	;has to be skipped
	ret	nz

	ld	a,(hl)	;Skips the exceeding characters (beyond 8 or 3)
	inc	hl	;in the file name
	or	a
	jp	z,EFND1
	cp	"."
	jp	nz,PASASOB
	ret

AFND1:	ld	a,"?"	;Fills with "?" until completing 8 or 3 characters
AFND11:	ld	(DE),a
	inc	DE
	djnz	AFND11
	jp	PASASOB

PFND1:	ld	a,(EXTFLG)
	or	a
	jp	nz,EFND1
	ld	a,b
	cp	8	;If a dot is at the beginning,
	dec	hl
	jp	z,AFND1	;interprets "*.<ext>"
	inc	hl
	ld	a," "	;Fills with " " until completing 8 or 3 characters
PFND11:	ld	(DE),a
	inc	de
	djnz	PFND11
	ret

EFND1:	ld	a,1
	ld	(EXTFLG),a
	ret

EXTFLG:	db	0	;#FF when the extension is processed, 
;                       ;1 when the end has arrived

;--- FCB name -> Normal name

FCB2NOR:	push	de
	ld	a,(hl)
	or	a
	jp	z,NOUN2
	add	"A"-1
	ld	(de),a
	inc	de
	ld	a,":"
	ld	(de),a
	inc	de

NOUN2:	inc	hl
	ld	b,8	;The name is being copied
F2NBUC:	ld	a,(hl)	;until 8 characters are processed
	inc	hl	;or a space is found...
	cp	" "
	jp	z,SPFND
	ld	(de),a
	inc	de
	djnz	F2NBUC
	ld	a,"."
	ld	(de),a
	inc	de
	jp	F2NEXT

SPFND:	ld	a,"."	;...then we add the dot,
	ld	(de),a	;and step over the exceeding spaces
	inc	de	;until arriving to the extension.
SFBUC:	ld	a,(hl)
	inc	hl
	djnz	SFBUC
	dec	hl

F2NEXT:	ld	b,3	;The extension is copied until
F2NEX2:	ld	a,(hl)	;3 characters are copied
	inc	hl	;or until a space is found.
	cp	" "
	jp	z,F2NEND
	ld	(de),a
	inc	de
	djnz	F2NEX2

F2NEND:	dec	de	;If there is not extension then the dot is deleted.
	ld	a,(de)
	cp	"."
	jp	z,NOPUN
	inc	de
NOPUN:	xor	a
	ld	(de),a

	ex	de,hl	;Obtains the string length.
	pop	de
	or	a
	sbc	hl,de
	ld	b,l
	jp	ENDCONV


;--- NAME: DIR
;      Searches a file
;      Firstly it must be executed with A=0
;      To search the next files, DISK_BUFFER must not be modified
;    INPUT:      DE = File name (it can contain wildcards), terminated with 0
;                IX = Pointer to a 26 bytes empty zone
;                B  = Searching attributes (ignored if DOS 1)
;                A  = 0 -> Search first
;                A  = 1 -> Search next
;    OUTPUT:     A  = 0 -> File found
;                A <> 0 -> File not found
;                IX+0          -> #FF (own fanzine of DOS 2)
;                IX+1  a IX+13 -> File name
;                IX+14         -> Attributes byte
;                IX+15 y IX+16 -> Modification hour
;                IX+17 y IX+18 -> Modification date
;                IX+19 y IX+20 -> Initial cluster
;                IX+21 a IX+24 -> File length
;                IX+25         -> Logic drive number
;     REGISTERS: F,C

OFBUF1:	equ	38

DIR:	ld	c,a
	ld	a,(DOS2)
	or	a
	ld	a,c
	jp	nz,DIR2

	;--- DIR: DOS 1 version

DIR1:	push	bc,de,hl,iy,ix,af
	call	CLBUF
	ex	de,hl
	ld	de,DISK_BUFFER	;Normal name in (DE) is converted to
	or	a	;FCB name in BUFFER.
	call	CONVNAME

	ld	de,DISK_BUFFER+OFBUF1	;Transfer area set to the buffer
	ld	c,_SETDTA	;located after the file FCB to be found
	call	5
	ld	de,DISK_BUFFER
	pop	af
	and	1
	ld	c,_SFIRST
	add	c
	ld	c,a
	call	5
	or	a	;Finishes with A=#FF if not found.
	jp	nz,ENDFF1

	ld	a,(DISK_BUFFER+OFBUF1)	;The FCB drive is saved
	ld	(ULO1),a	;in ULO1, and it is set to 0
	xor	a	;to convert it to normal name
	ld	(DISK_BUFFER+OFBUF1),a	;without drive.
	ld	iy,DISK_BUFFER+OFBUF1

	push	iy
	pop	hl	;HL = Directory entry
	pop	de	;(starting with the drive set to 0 and the name).
	push	de	;DE = IX at the input (user buffer).
	ld	a,#FF
	ld	(de),a	;First byte to #FF to make it equal to DOS 2 format.
	inc	de
	scf		;The name in normal format is copied
	call	CONVNAME	;to the user buffer.

	pop	ix	;IX = user buffer.
	ld	a,(iy+12)	;Attributes byte is copied.
	ld	(ix+14),a

	push	iy
	pop	hl
	ld	bc,23	;HL = Creation hour in the directory entry
	add	hl,bc

	push	ix
	pop	de
	ld	bc,15	;DE = User buffer, pointing to
	ex	de,hl	;the +15 position.
	add	hl,bc
	ex	de,hl

	ld	bc,10	;Data, hour, initial cluster and length
	ldir		;are copied at the same time.

	ld	a,(ULO1)	;Logic drive is copied.
	ld	(ix+25),a

	xor	a	;Finishing without error.
	push	ix
ENDFF1:	pop	ix,iy,hl,de,bc
	ret

ULO1:	db	0

	;--- DIR: DOS 2 version

DIR2:	push	hl,bc,de,ix
	ld	ix,DISK_BUFFER
	ld	c,_FFIRST
	and	1
	add	c
	ld	c,a
	call	5
	or	a
	jp	nz,ENDFF2
	push	ix
	pop	hl
	pop	de
	push	de
	ld	bc,26
	ldir
	xor	a
ENDFF2:	pop	ix,de,bc,hl
	ret


;--- NAME: CREATE
;      Creates a file but does NOT open it
;      WARNING! If the file already exists it is erased
; 		and a new one is created
;    INPUT:     DE = File name
;    OUTPUT:    A  = 0 -> File has been created
;               A <> 0 -> Error
;    REGISTERS: F

CREATE:	ld	a,(DOS2)
	or	a
	jp	nz,CREA2

	;--- CREATE: DOS 1 version

CREA1:	push	bc,de,hl,ix,iy
	call	CLBUF
	ex	de,hl	;HL = File name
	ld	de,DISK_BUFFER
	or	a
	call	CONVNAME
	ex	de,hl
	ld	de,DISK_BUFFER
	push	de
	ld	c,_FMAKE	;Creates the file and closes it
	call	5
	pop	de
	or	a
	jp	nz,CR1END
	ld	c,_FCLOSE
	call	5
	xor	a
CR1END:	pop	iy,ix,hl,de,bc
	ret

	;--- CREATE: DOS 2 version

CREA2:	push	bc,de,hl
	xor	a
	ld	b,0	;If the file already exists, erases it.
	ld	c,_CREATE	;Creates the file and closes it
	call	5
	or	a	;if there is no error.
	jp	nz,CR2END
	ld	c,_CLOSE
	call	5
	xor	a
CR2END:	pop	hl,de,bc
	ret


;--- NAME: OPEN
;      Opens a file
;    INPUT:     DE = File to be opened
;    OUTPUT:    A  = 0 -> OK
;               A <> 0 -> Error
;                         DOS 1: A=1 -> Too many opened files
;               B  = Number related to the file
;                    (it is not related  with the number of files opened)
;    REGISTERS: F, C

OPEN:	ld	a,(DOS2)
	or	a
	jp	nz,OPEN2

	;--- OPEN: DOS 1 version

OPEN1:	ld	a,(NUMFILES)
	cp	MAXFILES
	ld	a,1
	ret	nc

	push	hl,de,ix,iy
	ld	b,MAXFILES
	ld	hl,FCBS
	push	de
	ld	de,38
OP1BUC1:	ld	a,(hl)	;Searches for a free FCB
	or	a
	jp	z,FCBFND
	add	hl,de
	djnz	OP1BUC1
	ld	a,1
	jp	OP1END

FCBFND:	push	hl	;FCB is cleaned
	pop	de
	push	de
	inc	de
	ld	bc,37
	ld	(hl),0
	ldir

	pop	de
	inc	de
	pop	hl	;File name is set in the FCB
	or	a
	call	CONVNAME

	push	de
	ld	c,_FOPEN
	call	5
	pop	ix
	or	a	;Finishes if error
	jp	nz,OP1END

	ld	a,1
	ld	(ix+14),a	;"record size" is set to 1
	xor	a
	ld	(ix+15),a
	ld	(ix+33),a	;"random record" is set to 0
	ld	(ix+34),a
	ld	(ix+35),a
	ld	(ix+36),a

	ld	a,#FF	;FCB is marked as used
	ld	(ix-1),a

	ld	a,(NUMFILES)	;The number of opened files
	inc	a	;is incremented and
	ld	(NUMFILES),a	;this number is returned in A
	ld	b,a
	xor	a

OP1END:	pop	iy,ix,de,hl
	ret

	;--- OPEN: DOS 2 version

OPEN2:	push	hl,de
	xor	a
	ld	c,_OPEN
	call	5
	or	a
	jp	nz,OP2END
	ld	a,(NUMFILES)
	inc	a
	ld	(NUMFILES),a
	xor	a
OP2END:	pop	de,hl
	ret


;--- NAME: CLOSE
;      Closes a file
;    INPUT:     B  = File number
;    OUTPUT:    A  = 0 -> File has been closed
;               A <> 0 -> Error
;    REGISTERS: F

CLOSE:	ld	a,(DOS2)
	or	a
	jp	nz,CLOSE2

	;--- CLOSE: DOS 1 version

CLOSE1:	ld	a,b	;Error if B>MAXFILES
	cp	MAXFILES+1	;or B=0.
	ld	a,2
	ret	nc
	ld	a,b
	or	a
	ld	a,2
	ret	z

	push	bc,de,hl,ix,iy
	ld	hl,FCBS
	ld	de,38
	or	a
	sbc	hl,de
CL1BUC1:	add	hl,de	;HL = FCB for the file
	djnz	CL1BUC1

	ld	a,(hl)	;Error if the file is not opened
	or	a
	ld	a,2
	jp	z,ENDCL1

	inc	hl
	ex	de,hl	;DE = FCB of the file
	push	de
	ld	c,_FCLOSE
	call	5
	pop	ix
	or	a
	jp	nz,ENDCL1

	ld	a,(NUMFILES)
	dec	a
	ld	(NUMFILES),a
	xor	a	;FCB is marked as free
	ld	(ix-1),a

ENDCL1:	pop	iy,ix,hl,de,bc
	ret

	;--- CLOSE: DOS 2 version

CLOSE2:	push	bc,de,hl
	ld	c,_CLOSE
	call	5
	or	a
	jp	nz,ENDCL2
	ld	a,(NUMFILES)
	dec	a
	ld	(NUMFILES),a
	xor	a
ENDCL2:	pop	hl,de,bc
	ret


;--- NAME: READ
;      Reads from an opened file
;    INPUT:     B  = File number
;               DE = Buffer address
;               HL = Number of bytes to read
;    OUTPUT:    A  = 0 -> There is no error
;               A <> 0 -> Error
;                         If all the required bytes have not been
;                         read, this is considered an error, so
;                         input HL <> output HL.
;                         This error has the code A=1
;                         in both DOS 1 and DOS 2.
;               HL = Number of readed bytes
;    REGISTERS: F

READ:	ld	a,(DOS2)
	or	a
	jp	nz,READ2

	;--- READ: DOS 1 version

READ1:	ld	a,_RDBLK
	ld	(RWCODE),a
	jp	RW1

	;--- READ: DOS 2 version

READ2:	ld	a,_READ
	ld	(RWCODE),a
	jp	RW2


;--- NAME: WRITE
;      Writes to an opened file
;    INPUT:     B  = File number
;               DE = Buffer address
;               HL = Number of bytes to write
;    OUTPUT:    A  = 0 -> There is no error
;               A <> 0 -> Error
;                         If all the required bytes have not been
;                         written, this is considerated an error, so
;                         input HL <> output HL.
;                         This error has the code A=1
;                         in both DOS 1 and DOS 2.
;               HL = Number of written bytes
;    REGISTERS: F
;    CALLS:  CHKDOS2, RW1, RW2

WRITE:	ld	a,(DOS2)
	or	a
	jp	nz,WRITE2

	;--- WRITE: DOS 1 version

WRITE1:	ld	a,_WRBLK
	ld	(RWCODE),a
	jp	RW1

	;--- WRITE: DOS 2 version

WRITE2:	ld	a,_WRITE
	ld	(RWCODE),a
	jp	RW2


;--- RW: Generic read/write routine

	;--- RW: DOS 1 version

RW1:	ld	a,b
	cp	MAXFILES+1
	ld	a,1
	ret	nc
	ld	a,b
	or	a
	ld	a,2
	ret	z

	push	bc,de,ix,iy
	push	hl,de
	ld	hl,FCBS
	ld	de,38
	or	a
	sbc	hl,de
RW1BUC1:	add	hl,de	;HL = FCB for tje file
	djnz	RW1BUC1
	ld	a,(hl)	;A = Opened file handle
	ex	(sp),hl
	push	hl

	or	a	;Error if the file is not opened
	ld	a,2
	jp	z,ENDRW11

	pop	de
	ld	c,_SETDTA
	call	5
	pop	de,hl
	inc	de
	ld	a,(RWCODE)	;Read or Write code is choosed
	ld	c,a
	call	5	;and the call is executed

ENDRW1:	pop	iy,ix,de,bc
	ret
ENDRW11:	pop	bc,bc,bc
	jp	ENDRW1

	;--- RW: DOS 2 version

RW2:	;push	bc,de,hl
	ld	a,(RWCODE)	;Read or Write code is choosen
	ld	c,a
	call	5
	ret		;*** TESTING: Returns the real error, not 1

	pop	de
	or	a
	jp	nz,ENDRW2
	push	hl

	sbc	hl,de	;HL = readed bytes, DE = required bytes
	ld	a,h	;If HL=DE then there is no error
	or	l	;If HL<>DE then error 1
	ld	a,0
	pop	hl
	jp	z,ENDRW2
	ld	a,1

ENDRW2:	pop	de,bc
	ret

RWCODE:	db	0	;Read/Write function code


;--- GET_FILEPART: Returns pointer to the file part of given string 
;		with the format x:\path\file
;
;    Input:    HL = String
;    Output:   HL = Pointer to the file name
;              A  = Error (always 0 under DOS 1)
;    Modifies: AF

GET_FILEPART:	ld	a,(DOS2)
	or	a
	jr	nz,GFP_DOS2

	;--- DOS 1 version: can be "x:file" or "file" only

GFP_DOS1:	inc	hl
	ld	a,(hl)
	inc	hl
	cp	":"
	ld	a,0
	ret	z
	dec	hl
	dec	hl
	xor	a
	ret

	;--- DOS 2 version

GFP_DOS2:	ex	de,hl
	ld	bc,_PARSE	;B must be 0
	jp	5


;--- PRINT_DSKERR: Prints a disk error.
;    Firstly it prints the string passed in DE and in DOS1
;    it does nothing more.
;    In DOS 2, furthermore, it prints a description of the error passed in A.

PRINT_DSKERR:	ld	b,a
	ld	a,(DOS2)
	or	a
	jr	nz,PRDE_DOS2

	;--- DOS 1 version

	ld	c,_STROUT
	call	5
	print	ONE_NL_S
	ret

	;--- DOS 2 version

PRDE_DOS2:	push	bc
	ld	c,_STROUT
	call	5
	ld	e,":"
	ld	c,_CONOUT
	call	5
	ld	e," "
	ld	c,_CONOUT
	call	5

	pop	bc
	ld	de,PARAM_BUFFER
	ld	c,_EXPLAIN
	call	5
	ld	de,PARAM_BUFFER
	call	PRINTZ
	ret


;--- SEND_TFTP: Sends the datagram placed in OUT_BUFFER
;    Input:   BC = Length (it will be stored in LAST_SND_SIZE)

SEND_TFTP:
	ld	(LAST_SND_SIZE),bc
	ld	(DATA_SIZE),bc
	call	SET_UNAPI
	ld	hl,OUT_BUFFER
	ld	de,UDP_PARAMS
	ld	a,(UDP_CONN)
	ld	b,a
	ld	a,TCPIP_UDP_SEND
	jp	CALL_UNAPI


;--- RCV_TFTP: Receives a TFTP packet in IN_BUFFER ensuring that the IP
;    and port of sender are correct and modifying them if necessary.
;    Note: it DOES NOT check the TFTP code of the packet,
;    only the IP and the ports are checked.
;    Returns Cy=1 if there are not available packets,
;    and BC = the length of the received packet

RCV_TFTP:
	call	SET_UNAPI
	ld	hl,IN_BUFFER
	ld	de,548
	ld	a,(UDP_CONN)
	ld	b,a
	ld	a,TCPIP_UDP_RCV
	call	CALL_UNAPI
	or	a
	scf
	ret	nz

	;--- REMOTE_IP is 0.0.0.0?

	ld	iy,REMOTE_IP
	ld	a,(iy)
	or	(iy+1)
	or	(iy+2)
	or	(iy+3)
	jr	nz,RCV_TFTP2

	;--- Yes: we are in sever mode and a connection is awaited.
	;    Close the connection and open a new one with a random port.

	ld	(REMOTE_IP),hl	;Host IP is established as the one of
	ld	(REMOTE_IP+2),de	;the received packet

	ld	(REMOTE_PORT),ix	;The same with the host port

	call	OPEN_UDP_RAND

	or	a
	ret
RCV_TFTP2:	;

	;--- No: Check if the IP and ports matches with the ones
	;    already established.

	push	de	;Remote IP, first half
	ld	de,(REMOTE_IP)
	call	COMP
	pop	de
	jr	nz,RCV_TFTP

	ld	hl,(REMOTE_IP+2)	;Remote IP, second half
	call	COMP
	jr	nz,RCV_TFTP

	ld	hl,(REMOTE_PORT)	;Remote port: If it was 69,
	ld	de,69	;the connection was being initiated.
	call	COMP	;Then the new remote port is established
	jr	nz,RCV_TFTP4	;as the one received.

	ld	(REMOTE_PORT),ix
	or	a
	ret

RCV_TFTP4:	push	ix	;Remote port after the connection is
	pop	hl	;initialized: it must match with the one already
	ld	de,(REMOTE_PORT)	;stored
	call	COMP
	jp	nz,RCV_TFTP

	;--- Correct packet: reset the retransmissions counter

RCV_TFTPOK:	call	INIT_RETX

	or	a
	ret

;--- Changed by Oduvaldo 07/2019
;--- WAIT_TICK: This version won't wait a tick after calling TCPIP_WAIT
;    but if tick has changed will decrements RETX_TIMER, otherwise return.
;    If it arrives to 0, restores it to RETX_TIMER_MAX*60, increments
;    RETX_COUNTER, and sends again the last sent packet.
;    If the retransmissions counter arrives to RETX_CNT_MAX,
;    it sends a timeout error message and returns Cy=1.

WAIT_TICK:	
	call	SET_UNAPI
	ld	a,TCPIP_WAIT
	call	CALL_UNAPI
	ld	hl,(OLD_TIME)
	ld	de,(TIME)	;Tick changed?
	call	COMP	
	scf
	ccf
	ret	z	;Nope, so nothing else to do
	ld	(OLD_TIME),de	;New tick value

	;* At least an interval of 1/50 or 1/60 seconds has elapsed

	ld	a,(RETX_TIMER)
	dec	a
	ld	(RETX_TIMER),a
	scf
	ccf
	ret	nz

	;* The timer has arrived to 0: incements the counter

	ld	a,RETX_TIMER_MAX*60
	ld	(RETX_TIMER),a

	ld	a,(RETX_COUNTER)
	inc	a
	ld	(RETX_COUNTER),a
	cp	RETX_CNT_MAX
	jr	z,WAIT_TICK_2

	ld	bc,(LAST_SND_SIZE)
	call	SEND_TFTP	;Retransmits the last packet
	scf
	ccf
	ret
	
WAIT_TICK_2:	;

	;* No more attempts remaining: sends an error packet and finishes

	call	SEND_TOUTRTT
	print	ABTOUT_S
	scf
	ret	

;--- SHOW_TFTPE: Shows information about the received error packet
;    (stored in IN_BUFFER);
;    shows the error code and the received message if it exists.

SHOW_TFTPE:	print	ERRRCV_S

	ld	a,(IN_BUFFER+3)
	ld	ix,PARAM_BUFFER
	call	BYTE2ASC	;Assumes that it has one byte only
	ld	(ix)," "
	ld	(ix+1),"-"
	ld	(ix+2)," "
	ld	(ix+3),"$"
	print	PARAM_BUFFER

	ld	de,IN_BUFFER+4
	ld	a,(de)
	or	a
	jr	nz,SHOW_TFTPE2
	ld	de,NOMESSAGE_S	;String to print if there is no message
SHOW_TFTPE2:	call	PRINTZ

	print	ONE_NL_S
	ret

;--- INITIALIZE_PROGRESS: Shows just the text Sending or Receiving, we won't print it again
INITIALIZE_PROGRESS:
	xor a
	ld	(LAST_NUMBER_OF_CHARS),a
	ld	a,(GETPUT)
	or	a
	ld	de,RECEIVED_S
	jr	z,SHOW_PROG2
	ld	de,SENT_S
SHOW_PROG2:	ld	c,_STROUT	;Prints "Sending" or "Receiving"
	call	5
	ret

;--- SHOW_PROGRESS: Shows the sending/receiving progress
SHOW_PROGRESS:	
	ld	de,(LAST_BLKID)
	srl	d
	rr	e	;DE=Received KBytes

	ld	hl,PARAM_BUFFER
	call	NUM2DEC
	print	PARAM_BUFFER	;Prints the number of KBytes

	ret


;--- SEND_TOUTERR: Sends a timeout error message

SEND_TOUTRTT:	ld	de,TOUT_MSG
	xor	a
	jp	SEND_ERR

TOUT_MSG:	db	"Timeout",0


;--- SEND_DSKERR: Sends an error message with the passed DOS error in A.
;    In DOS 1 the message is always "Disk error".

SEND_DSKERR:	ld	b,a
	ld	a,(DOS2)
	or	a
	jr	nz,SND_DSKERR2

	;--- DOS 1

	ld	de,DSKERR_S
	jr	SND_DE_COMMON

	;--- DOS 2

SND_DSKERR2:	ld	de,PARAM_BUFFER
	push	de
	ld	c,_EXPLAIN
	call	5
	pop	de

	;--- Common

SND_DE_COMMON:	ld	a,3	;Error "Allocation exceeded"
	jp	SEND_ERR


;--- SEND_ERR: Generic routine to send an error.
;    Input:   A = Error code
;             DE = Error message, terminated with 0

SEND_ERR:	ld	hl,#0500	;"Error packet" code
	ld	(OUT_BUFFER),hl
	ld	h,a	;Error code passed
	ld	l,0
	ld	(OUT_BUFFER+2),hl

	push	de
	pop	hl
	call	STRLEN
	inc	bc	;BC = String length including the trailing 0

	ex	de,hl
	ld	de,OUT_BUFFER+4
	push	bc	;Appends the string to the packet
	ldir

	pop	bc
	inc	bc
	inc	bc
	inc	bc
	inc	bc	;To make the length to include the header
	jp	SEND_TFTP


;--- FCLOSE: Closes the file whose number is in FH, if it is opened

FCLOSE:	ld	a,(FH)	;If FH is 0, it is not opened
	or	a
	ret	z

	ld	b,a
	call	CLOSE
	xor	a
	ld	(FH),a
	ret


;--- INIT_RETX: Initialization of the retransmission timer and counter

INIT_RETX:	ld	a,RETX_TIMER_MAX*60
	ld	(RETX_TIMER),a
	ld	a,0
	ld	(RETX_COUNTER),a
	ret


;--- INIT_TIDS_CLIENT: TIDs initialization for client mode
;    (to avoid confusions it discards the local port 69)

INIT_TIDS_CLIENT:
	ld	hl,69
	ld	(REMOTE_PORT),hl
	jp	OPEN_UDP_RAND


;--- OPEN_UDP_TFTP: Open the UDP connection
;    for the standard TFTP port.
;    Assumes there is at least a free connection.

OPEN_UDP_TFTP:
	call	SET_UNAPI
	call	CLOSE_UDP2
	ld	hl,TFTP_PORT
	ld	b,0
	ld	a,TCPIP_UDP_OPEN
	call	CALL_UNAPI
	ld	a,b
	ld	(UDP_CONN),a
	ret


;--- OPEN_UDP_RAND: Open the UDP connection
;    for a random UDP port, discarding port 69.
;    Assumes there is at least a free connection.

OPEN_UDP_RAND:
	call	SET_UNAPI
	call	CLOSE_UDP2
        ld      hl,(LOCAL_TID)
	ld	b,0
	ld	a,TCPIP_UDP_OPEN
	call	CALL_UNAPI
	ld	a,b
	ld	(UDP_CONN),a
	ret


;--- CLOSE_UDP: Close the UDP connection

CLOSE_UDP:
	call	SET_UNAPI
CLOSE_UDP2:
	ld	bc,(UDP_CONN-1)
	ld	a,TCPIP_UDP_CLOSE
	jp	CALL_UNAPI


;--- CHECK_KEY: Calls a DOS routine in order to be able to detect the
;    pressing of CTRL-C so the user can cancel de transmission.
;    Furthermore, it returns A<>0 if any key has been pressed.

CHECK_KEY:	ld	e,#FF
	ld	c,_DIRIO
	jp	5


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


;--- Code to switch TCP/IP implementation on page 1, if necessary

SET_UNAPI:
UNAPI_SLOT:	ld	a,0
	ld	h,#40
	call	ENASLT
	ei
UNAPI_SEG:	ld	a,0
	jp	PUT_P1


CALL_UNAPI:	jp	0


;**************************
;***                    ***
;***  VARS AND STRINGS  ***
;***                    ***
;**************************

	;--- Variables

UDP_PARAMS:
REMOTE_IP:	ds	4	;Remote Host IP
REMOTE_PORT:	dw	0	;TID for transfer
DATA_SIZE:	dw	0	;Length of UDP data to send

DOS2:	db	0	;#FF if there is DOS 2
SERVER:	db	0	;#FF if working in server mode
FH:	db	0	;File Handle of the last opened file
LAST_BLKID:	dw	0	;Last ID of received block
GETPUT:	db	0	;0 if receiving, #FF if sending
NUMFILES:	db	0	;Number of opened files (DOS 1)
RETX_TIMER:	db	0	;Timer for retransmissions
RETX_COUNTER:	db	0	;Counter for retransmissions
FILEPART_PNT:	dw	0	;Pointer to the file name
LAST_SND_SIZE:	dw	0	;Length of the last sent packet
LAST_RCV_SIZE:	dw	0	;Length of the last received packet
UDP_CONN:	db	#FF	;UDP connection number
LOCAL_TID:    dw      #FFFF            ;Will be 69 if /SP option is used
OLD_TIME:	dw	0	;Stores the last tick
LAST_NUMBER_OF_CHARS:	db	0	;Stores how many size chars were printed so we know how many to go back

	;--- Strings

	;* Usage Information

PRESENT_S:	db	27,"x5"	;Disables cursor
	db	"TFTP Client/Server for the TCP/IP UNAPI 1.1",13,10
	db	"Oduvaldo (ducasp@gmail.com) 07/2019",13,10
	db	"Based on TFTP 1.0 by Konamiman",13,10,10,"$"

INFO_S:	db	"Usage:",13,10,10
	db	"* To send a file:",13,10
	db	"  TFTP <host name> S[END]|P[UT] <local filename> [<transfer filename>]",13,10
	db	"  Default for <transfer filename> is <local filename> without the drive/path",13,10,10
	db	"* To receive a file:",13,10
	db	"  TFTP <host name> R[CV]|G[ET] <remote filename> [<local filename>]",13,10
	db	"  Default for <local filename> is <remote filename> without the path",13,10
	db	"  (only if <remote filename> has a valid MSX-DOS path, and only in DOS 2)",13,10,10
	db	"* To run in server mode:",13,10
	db	"  TFTP /S|/SP",13,10,10
	db	"  /S uses a random number as the local TID (standard behavior)",13,10
	db	"  /SP uses 69 (the default TFTP server port) as the local TID",13,10
	db	"  (/SP is necessary when the client is the standard tftp.exe of MS Windows)",13,10
	db	"$"

	;* Initialization errors

INVPAR_S:	db	"*** Invalid parameter",13,10,"$"
MISSPAR_S:	db	"*** Missing parameter(s)",13,10,"$"

	;* Host name resolution

RESOLVING_S:	db	"Resolving host name... $"
RESOLVERR_S:	db	13,10,"ERROR "
RESOLVERRC_S:	ds	6	;Leave space for "<code>: $"
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

	;* Errors during the execution

ERROPEN_S:	db	"*** Error when opening file$"
ERRCREATE_S:	db	"*** Error when creating file$"
ERRREAD_S:	db	"*** Error when reading from file$"
ERRWRITE_S:	db	"*** Error when writing to file$"
GENERR_S:	db	13,10,"*** Error$"

ERRRCV_S:	db	13,10,"*** Error received: $"
NOMESSAGE_S:	db	"(No message included)",0

ABTOUT_S:	db	13,10,"*** Timeout - Transmission aborted",13,10,"$"

DSKERR_S:	db	"Disk error",0
FNOTF_S:	db	"File not found or invalid path",0

	;* Information during the execution

INSERV_S:	db	13,">>> Now running in server mode. Press any key to exit.",13,10,"$"

RECEIVED_S:	db	13,10,"Receiving (KBytes): $"
SENT_S:	db	13,10,"Sending (KBytes): $"

RRQSENT_S:	db	"Read request sent...",13,"$"
WRQSENT_S:	db	"Write request sent...",13,"$"

TCOMPLETE_S:	db	13,10,10,"Transfer complete.",13,10,"$"

WAITING_IN_S:	db	13,10,"* Waiting for incoming connection...",13,10,10,"$"
RRQRCVD_S:	db	"Received read request for file $"
WRQRCVD_S:	db	"Received write request for file $"
ERRETURN_S:	db	"Error returned: $"

OCTET_S:	db	"OCTET",0

	;* UNAPI related

TCPIP_S:	db	"TCP/IP",0
NOTCPIP_S:	db	"*** No TCP/IP UNAPI implementation found.",13,10,"$"
NOUDP_S:	db	"*** This TCP/IP UNAPI implementation does not support UDP connections",13,10,"$"
NOFREEUDP_S:	db	"*** No free UDP connections available",13,10,"$"


	;-----------------
	;---  Buffers  ---
	;-----------------

PARAM_BUFFER:		;For the last extracted parameter
DISK_BUFFER:	equ	PARAM_BUFFER+128	;Generic buffer for disk op.
OUT_BUFFER:	equ	DISK_BUFFER+70	;For the last sent packet
IN_BUFFER:	equ	OUT_BUFFER+520	;For the last received packet
FCBS:	equ	IN_BUFFER+556	;For FCBs of opened files (DOS 1)
END_BUFFERS:	equ	FCBS+38*MAXFILES
