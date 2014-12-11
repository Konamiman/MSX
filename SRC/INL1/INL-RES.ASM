;InterNestor Lite v1.1.1 - TCP/IP stack for MSX2 computers
;Resident part (timer interrupt code and user functions)
;
;Copyright (C) 2003-2007 Nestor Soriano (Konamiman)

;This code is prepared for the Compass MSX assembler.

;--- This constant selects the InterNestor version to be generated:
;--- 0 for the serial (RS232/modem) version, 1 for the Ethernet version
;
;    NOTE:
;    RS232/modem version requires Erik Maas' Fossil driver installed.
;    Ethernet version requires UNAPI compliant Ethernet API installed.

LINK:	equ	0


;The source code for InterNestor Lite is divided in two files:
;INL-TRAN.ASM is the transient part (installer and control program)
;INL-RES.ASM is the resident part (timer interrupt and user functions)
;
;Assemble both, the concatenate the results,
;and name the resulting file INL.COM. For example, in MSX-DOS:
;
;concat /b inl-tran.dat+inl-res.dat inl.com


;NOTE: for PPP code:
;"XCP" means "LCP or IPCP"
;"XAP" means "PAP or CHAP"


;****************************
;***                      ***
;***  MACROS & CONSTANTS  ***
;***                      ***
;****************************

;NOTE: Timer values are in 1/60 seconds unless otherwise stated

	.label	20	;for Compass

;--- INL version number

INL_VERSION1:	equ	1
INL_VERSION2:	equ	1
INL_VERSION3:	equ	1

;--- UDP port for the DNS resolver

DNS_PORT:	equ	#FFFE

;--- Storage of the allocated segments numbers

INL_SEG1:	equ	#7FF0	;Code segment number
INL_SEG2:	equ	#7FF1	;Data segment number

;--- Initial values for TCP timers

ACK_DELAY_V:	equ	6	;Delayed ACK: 0.1 seconds
RTO_V:		equ	3	;Retransmissions: 3 seconds
ZWP_V:		equ	10	;Zero window probe: 10 seconds
SEND_TOUT_V:	equ	30	;Non-PUSH data send: 0.5 seconds
UTOUT_DEF:	equ	3*60	;Default user timeout: 3 minutes

;--- TCP states

CLOSED:		equ	0
LISTEN:		equ	1
SYN.SENT:	equ	2
SYN.RECEIVED:	equ	3
ESTABLISHED:	equ	4
FIN.WAIT.1:	equ	5
FIN.WAIT.2:	equ	6
CLOSE.WAIT:	equ	7
CLOSING:	equ	8
LAST.ACK:	equ	9
TIME.WAIT:	equ	10	;Not used (CLOSED is entered directly)


		if LINK=1

;--- Macro to call Ethernet UNAPI routines

ethnet:	macro	@d
	ld	a,@d
	call	EXEUNAPI
	endm

;--- Types of DHCP messages

DHCPDISCOVER:	equ	1
DHCPOFFER:	equ	2
DHCPREQUEST:	equ	3
DHCPDECLINE:	equ	4
DHCPACK:	equ	5
DHCPNAK:	equ	6
DHCPRELEASE:	equ	7
DHCPINFORM:	equ	8

;--- DHCP automaton states

INIT:		equ	0
SELECTING:	equ	1
REQUESTING:	equ	2
BOUND:		equ	3
RENEWING:	equ	4
REBINDING:	equ	5
INFORMING:	equ	6	;When sending DHCPINFORM
CONFIGURED:	equ	7	;After receiving ACK from DHCPINFORM

;--- ARP and routing tables sizes

ARP_ENTRIES:	equ	32
ROUTE_ENTRIES:	equ	16

;--- Ethernet UNAPI routines

ETH_GET_HWADD:	equ	2
ETH_GET_NETSTAT:	equ	3
ETH_IN_STATUS:	equ	7
ETH_GET_FRAME:	equ	8
ETH_SEND_FRAME:	equ	9

		endif

;--- System variables and routines

RDSLT:		equ	#000C	;A=PEEK(Slot A, Address HL)
WRSLT:		equ	#0014
CALSLT:		equ	#001C	;CALL Slot IYh, Address IX
ENASLT:		equ	#0024

EXPTBL:		equ	#FCC1
SYSTIMER:	equ	#FC9E

	if	LINK=0
TCB_MAX_SIZE:	equ	160
	endif

	if	LINK=1
TCB_MAX_SIZE:	equ	96
	endif


;********************
;***              ***
;***  JUMP TABLE  ***
;***              ***
;********************

	org	#4000

	;--- Destination of timer interrupt

	jp	TIME_INT

	;--- Slots and segments management.
	;    "JP 0" entries are set at installation time
	;    and point to code on page 3.

LDIRP3:		jp	0	;Switches slot H, seg L on page 1, and copies IX->IY len BC
PUT_P1:		jp	0
GET_P1:		jp	0
PUT_P2:		jp	0
GET_P2:		jp	0
GETSLOT1:	jp	0
PUTSLOT1:	jp	0
GETSLOT2:	jp	_GETSLOT2
PUTSLOT2:	jp	_PUTSLOT2

	;--- RS232 access.
	;    These entries are copied from Fossil work area at installation time.
	;    (for the Ethernet version, these are simply dummy placeholders)

	if	LINK=0

RS_IN:		jp	0
RS_OUT:		jp	0
RS_IN_STAT:	jp	0
RS_OUT_STAT:	jp	0

	endif

	if	LINK=1

RS_IN:	ret
	ret
	ret
RS_OUT:	ret
	ret
	ret

RS_IN_STAT:	ret
	ret
	ret
RS_OUT_STAT:	ret
	ret
	ret

	endif

	;--- General, configuration and codifications

VERS_PAUSE:	jp	_VERS_PAUSE
GET_VAR:	jp	_GET_VAR
SET_VAR:	jp	_SET_VAR
COPY_DATA:	jp	_COPY_DATA
IP_STRING:	jp	_IP_STRING
USER_MD5:	jp	_USER_MD5
USER_CHKSUM:	jp	_USER_CHKSUM
USER_B64INIT:	jp	B64_INIT
USER_B64ENC:	jp	_USER_B64ENC
USER_B64DEC:	jp	_USER_B64DEC

	;--- PPP (unused on the Ethernet version)

	if	LINK=0

SEND_MODEM:	jp	_SEND_MODEM
PPP_OPEN:	jp	_PPP_OPEN
PPP_CLOSE:	jp	_PPP_CLOSE

	endif

	if	LINK=1

SEND_MODEM:	ret
	ret
	ret
PPP_OPEN:	ret
	ret
	ret
PPP_CLOSE:	ret
	ret
	ret

	endif

	;--- ICMP

SEND_ECHO:	jp	_SEND_ECHO
RCV_ECHO:	jp	_RCV_ECHO

	;--- UDP

UDP_SEND:	jp	_UDP_SEND
UDP_RCV:	jp	_UDP_RCV

	;--- DNS resolver

DNS_Q:	jp	_DNS_Q
DNS_R:	jp	_DNS_R

	;--- TCP

TCP_OPEN:	jp	_TCP_OPEN
TCP_CLOSE:	jp	_TCP_CLOSE
TCP_ABORT:	jp	_TCP_ABORT
TCP_SEND:	jp	_TCP_SEND
TCP_RCV:	jp	_TCP_RCV
TCP_STATUS:	jp	_TCP_STATUS
TCP_FLUSH:	jp	_TCP_FLUSH

	;--- Raw receiving and sending

RAW_SEND:	jp	_RAW_SEND
RAW_CONTROL:	jp	_RAW_CONTROL
RAW_RCV:	jp	_RAW_RCV

	;--- Other

WAIT_INT:	jp	_WAIT_INT
NETWORK_STATE:	jp	_NETWORK_STATE


	if	LINK=1

	;--- Ethernet

ENET_INFO:	jp	_ENET_INFO
ETH2ASCII:	jp	_ETH2ASCII
ASCII2ETH:	jp	_ASCII2ETH
MASK2BITS:	jp	_MASK2BITS
BITS2MASK:	jp	_BITS2MASK
ARP_ROUTE:	jp	_ARP_ROUTE

	;--- Code to call an UNAPI routine
	;    (generated at installation time)

EXEUNAPI:	ds	12

	endif


;******************************
;***                        ***
;***  TIMER INTERRUPT CODE  ***
;***                        ***
;******************************

;This code is executed 60 times per second unless INL is paused

TIME_INT:

	;--- If DISABLE_INT is ON, do nothing; otherwise set it ON.
	;    This is to prevent reentrance of another timer interrupt
	;    in case we perform a too long task.

	ld	a,(DISABLE_INT)
	or	a
	ret	nz

	ld	a,#FF
	ld	(DISABLE_INT),a

	call	TIME_INT2

	xor	a
	ld	(DISABLE_INT),a
	ret

TIME_INT2:

	;=======================
	;===  Update timers  ===
	;=======================

	if	LINK=0

	;-----------------------------
	;---  PPP specific timers  ---
	;-----------------------------

	;--- If PPP state is 0 (disconnected), skip this part

	ld	a,(PPP_STATE)
	or	a
	jp	z,END_TIMERS

	ld	a,(PPP_STATE)
	cp	4
	jr	z,TIMERS_S4

	;--- XCP/XAP one minute timer
	;    (states 1 to 3)

	ld	hl,(XCP_TTIMER)
	ld	a,h
	or	l
	dec	hl
	ld	(XCP_TTIMER),hl
	jr	nz,END_1MTIM

	;* Timer expired:
	;  Close connection with the appropriate error code (8 to 10)

	ld	a,(PPP_STATE)
	add	7
	ld	(PPP_CLCODE),a

	call	SEND_TREQ

	xor	a
	ld	(PPP_STATE),a
	ld	(PCAP_STATE),a
	call	CLOSE_ALL_TCP
	jp	END_TIMERS
END_1MTIM:	;

	;--- XCP/XAP resend timer
	;    (states 1 to 3)

	ld	hl,(XCP_RTIMER)
	ld	a,h
	or	l
	dec	hl
	ld	(XCP_RTIMER),hl
	jr	nz,END_XCPTIM

	;* Timer expired:
	;  Resend the appropriate packet

	ld	hl,TIMERS_NEXT1
	push	hl
	ld	a,(PPP_STATE)
	cp	1
	jp	z,SEND_LCP_CREQ
	cp	3
	jp	z,SEND_IPCP_CREQ

	ld	a,(AUTH_PROTO)
	cp	#C0
	jp	z,SEND_PAP_REQ

	;* If we reached this point, we are using CHAP:
	;  do nothing
TIMERS_NEXT1:

	ld	hl,60*3		;Reset timer to 3 seconds
	ld	(XCP_RTIMER),hl
	jr	END_XCPTIM

	;--- Timer to begin sending echoes
	;    (state 4)

TIMERS_S4:
	ld	a,(USEPPPECHO)
	or	a
	jr	z,END_XCPTIM

	ld	hl,(XCP_TTIMER)
	ld	a,h
	or	l
	jr	z,TIMERS_S4_2

	dec	hl
	ld	(XCP_TTIMER),hl
	jr	END_XCPTIM

	;--- Timer to resend echo (state 4)

TIMERS_S4_2:
	ld	hl,(XCP_RTIMER)
	ld	a,h
	or	l
	dec	hl
	ld	(XCP_RTIMER),hl
	jr	nz,END_XCPTIM

	;* Timer expired: if we have sent 4 echoes already,
	;  close connection with error 17

	ld	a,(ECHOES_SENT)
	cp	4
	jr	nz,MOREECHOS

	ld	a,17
	ld	(PPP_CLCODE),a
	call	SEND_TREQ
	jp	END_GET_PACK

MOREECHOS:
	inc	a
	ld	(ECHOES_SENT),a
	ld	hl,PACK_LCPECHO
	ld	de,OUT_BUFFER+2
	ld	bc,26
	ldir
	ld	a,(ID_PPPECHO)
	ld	(OUT_BUFFER+5),a
	inc	a
	ld	(ID_PPPECHO),a
	call	SEND_PACKET

	ld	hl,5*60
	ld	(XCP_RTIMER),hl

	jr	END_XCPTIM

END_XCPTIM:	;

	endif

	if	LINK=1

	;----------------------------------
	;---  Ethernet specific timers  ---
	;----------------------------------

	;--- Timer to periodically check network state

	ld	a,(CHECK_NET)
	or	a
	jr	nz,DO_CHECK_NET

	ld	a,#FF
	ld	(NET_STATE),a
	jr	OK_NETTIMER

DO_CHECK_NET:
	ld	hl,(NETSTAT_TIMER)
	dec	hl
	ld	(NETSTAT_TIMER),hl
	ld	a,h
	or	l
	jr	nz,OK_NETTIMER

	ethnet	ETH_GET_NETSTAT
	or	a
	jr	z,NETSTAT_0

NETSTAT_1:
	ld	a,#FF
	ld	(NET_STATE),a
	jr	NETSTAT_OK

NETSTAT_0:
	call	CLOSE_ALL_TCP
	xor	a
	ld	(NET_STATE),a
	ld	(PCAP_STATE),a

NETSTAT_OK:
	ld	hl,10*60
	ld	(NETSTAT_TIMER),hl
OK_NETTIMER:


	;--- ARP cache timer

	ld	ix,ARP_CACHE
	ld	b,ARP_ENTRIES
CHK_ARP_LOOP:
	push	bc

	ld	a,(ix)
	cp	2
	jr	nz,NO_ARP_INUSE

	;* Dynamic entry in use:
	;  decrease cahce expiration timer;
	;  if it reaches 0, delete entry

CHK_ARP_TYPE2:
	push	ix
	pop	hl
	ld	bc,11
	add	hl,bc
	push	hl,hl
	pop	bc
	call	DEC32
	pop	hl

	ld	de,ZERO32
	call	COMP32
	jr	nz,CHK_ARP_NXT

	ld	(ix),0
	jr	CHK_ARP_NXT

NO_ARP_INUSE:
	cp	3
	jr	nz,CHK_ARP_NXT

	;* Dynamic entry being resolved:
	;  decrease resend timer (1 byte) if it is not 0.
	;  If it reaches 0, resend the ARP packet,
	;  or delete entry if 5 packets were already sent.

CHK_ARP_TYPE3:
	ld	a,(ix+11)
	dec	a
	ld	(ix+11),a
	jr	nz,CHK_ARP_NXT

	ld	a,(ix+12)	;If 5 packets were sent...
	cp	5
	jr	c,CHK_ARP_NODEL

	xor	a	;...delete entry
	ld	(ix),a
	jr	CHK_ARP_NXT
CHK_ARP_NODEL:

	inc	a
	ld	(ix+12),a
	ld	a,2*60	;2 seconds between retransmissions
	ld	(ix+11),a

	ld	l,(ix+7)
	ld	h,(ix+8)
	ld	e,(ix+9)
	ld	d,(ix+10)

	push	ix
;SND_ARPRQ:
	call	SEND_ARP_RQ
	pop	ix

	;* Next entry, if any

CHK_ARP_NXT:
	ld	bc,16
	add	ix,bc
	pop	bc
	djnz	CHK_ARP_LOOP


	;--- DHCP automaton timer

	ld	a,(DHCP_VECT)
	or	a
	jp	z,TDHCP_OK

	ld	a,(DHCP_STATE)
	cp	CONFIGURED
	jp	z,TDHCP_OK

	;* INIT state:
	;  Enter SELECTING or INFORMING, send DHCPDISCOVER or DHCPINFORM,
	;  and initialize retransmission timer

	ld	a,(DHCP_STATE)
	or	a	;cp INIT
	jr	nz,TDHCP_NOINIT

	call	DHCP_DO_INIT

	ld	a,(DHCP_VECT)	;SELECTING if IP required, INFORMING otherwise
	and	1
	jr	z,TDHCP_INIT0

	ld	a,SELECTING
	ld	(DHCP_STATE),a
	ld	a,DHCPDISCOVER
	jr	TDHCP_INIT1

TDHCP_INIT0:
	ld	a,INFORMING
	ld	(DHCP_STATE),a
	ld	a,DHCPINFORM

TDHCP_INIT1:
	call	SEND_DHCP
	call	DHCP_FIRST

	jp	TDHCP_OK
TDHCP_NOINIT:

	;* If state is not BOUND or CONFIGURED, update SECS

	cp	BOUND
	jr	z,TDHCP_OKSECS
	cp	CONFIGURED
	jr	z,TDHCP_OKSECS

	ld	a,(DHCP_SECS_T)
	inc	a
	ld	(DHCP_SECS_T),a
	cp	60
	jr	c,TDHCP_OKSECS

	xor	a
	ld	(DHCP_SECS_T),a
	ld	hl,(DHCP_SECS)
	inc	hl
	ld	(DHCP_SECS),hl
TDHCP_OKSECS:

	;* Update retransmission timer, and if it expires,
	;  resend the appropriate packet

	ld	a,(DHCP_SNDTIM)
	dec	a
	ld	(DHCP_SNDTIM),a
	jr	nz,TDHCP_OKRETIM

	ld	a,(DHCP_STATE)
	cp	REQUESTING
	jr	nz,TDHCP_OKTRIES
	ld	a,(DHCP_TRIES)	;If retried 10 times in REQUESTING state,
	cp	10	;return to INIT
	jp	nc,TDHCP_OK2

TDHCP_OKTRIES:
	ld	a,3*60
	ld	(DHCP_SNDTIM),a
	ld	hl,DHCP_TRIES
	inc	(hl)

	;In SELECTING state, resend DHCPDISCOVER

	ld	a,(DHCP_STATE)
	cp	SELECTING
	jr	nz,TDHCP_NOSEL

	ld	a,DHCPDISCOVER
	call	SEND_DHCP
	jr	TDHCP_OKRETIM
TDHCP_NOSEL:

	;In INFORMING state, resend DHCPINFORM

	ld	a,(DHCP_STATE)
	cp	INFORMING
	jr	nz,TDHCP_NOINF

	ld	a,DHCPINFORM
	call	SEND_DHCP
	jr	TDHCP_OKRETIM
TDHCP_NOINF:

	;In REQUESTING, REBINDING or RENEWING states, resend DHCPREQUEST

	cp	BOUND	;All remaining states except BOUND
	jr	z,TDHCP_OKRETIM
	ld	a,DHCPREQUEST
	call	SEND_DHCP
TDHCP_OKRETIM:

	;* In BOUND, REBINDING or RENEWING states, decrease T1, T2 and LEASE.
	;  In RENEWING state, decrease T2 and LEASE.
	;  In REBINDING state, decremease LEASE.
	;  Decrease only non infinite values.

	ld	a,(DHCP_STATE)
	cp	BOUND
	jr	z,TDHCP_DECT1
	cp	RENEWING
	jr	z,TDHCP_DECT2
	cp	REBINDING
	jr	z,TDHCP_DECLS
	jp	TDHCP_OK

TDHCP_DECT1:
	ld	a,(DHCP_T1)
	inc	a
	jr	z,TDHCP_DECT2
	ld	hl,DHCP_T1
	ld	bc,DHCP_T1
	call	DEC32

TDHCP_DECT2:
	ld	a,(DHCP_T2)
	inc	a
	jr	z,TDHCP_DECLS
	ld	hl,DHCP_T2
	ld	bc,DHCP_T2
	call	DEC32

TDHCP_DECLS:
	ld	a,(DHCP_LEASE)
	inc	a
	jr	z,TDHCP_OKDEC
	ld	hl,DHCP_LEASE
	ld	bc,DHCP_LEASE
	call	DEC32
TDHCP_OKDEC:

	;* In BOUND state, if T1 expires enter RENEWING
	;  and DHCPREQUEST, also initialize SECS

	ld	a,(DHCP_STATE)
	cp	BOUND
	jr	nz,TDHCP_NORENEW

	ld	hl,DHCP_T1
	ld	de,ZERO32
	call	COMP32
	jr	nz,TDHCP_OK

	xor	a
	ld	(DHCP_SECS_T),a
	ld	hl,0
	ld	(DHCP_SECS),hl

	ld	a,RENEWING
	ld	(DHCP_STATE),a
	ld	a,DHCPREQUEST
	call	SEND_DHCP
	call	DHCP_FIRST
	jr	TDHCP_OK
TDHCP_NORENEW:

	;* In RENEWING state, if T2 expires enter REBINDING
	;  and send DHCPREQUEST

	cp	RENEWING
	jr	nz,TDHCP_NOREBIND

	ld	hl,DHCP_T2
	ld	de,ZERO32
	call	COMP32
	jr	nz,TDHCP_OK

	ld	a,REBINDING
	ld	(DHCP_STATE),a
	ld	a,DHCPREQUEST
	call	SEND_DHCP
	call	DHCP_FIRST
	jr	TDHCP_OK
TDHCP_NOREBIND:

	;* In REBINDING state, if LEASE expires enter INIT

	cp	REBINDING
	jr	nz,TDHCP_OK

	ld	hl,DHCP_LEASE
	ld	de,ZERO32
	call	COMP32
	jr	nz,TDHCP_OK

TDHCP_OK2:
	ld	a,INIT
	ld	(DHCP_STATE),a
TDHCP_OK:

	endif

	;-----------------------
	;---  Common timers  ---
	;-----------------------

	;--- Timer to resend DNS packets

	ld	a,(DNS_STAT_P)	;Is there a query in progress?
	cp	1
	jp	nz,END_DNS_TIM

	;* Total timer expired?
	;  Then set error 17

	ld	hl,(DNS_TTOUT)
	ld	a,h
	or	l
	dec	hl
	ld	(DNS_TTOUT),hl
	jr	nz,DNS_NOEXPTOT

	ld	a,3
	ld	(DNS_STAT_P),a
	ld	a,17
	ld	(DNS_STAT_S),a
	jp	END_DNS_TIM
DNS_NOEXPTOT:

	;* Resend timer expired?

	ld	a,(DNS_TOUT)
	dec	a
	ld	(DNS_TOUT),a
	jp	nz,END_DNS_TIM

	;Expired: any retransmissions left?

	ld	a,(DNS_RETRY)
	cp	5
	jr	nz,DNS_RESEND

	;No retransmissions left:
	;If it was primary server, try secondary if it exists.

	call	DNS_USE_SEC
	jr	nc,DNS_RESEND

	;No retransmissions left and it was not primary server,
	;or it was primary server but there is not secondary server:
	;Error 16

DNS_NOREPLY:	ld	a,3
	ld	(DNS_STAT_P),a
	ld	a,16
	ld	(DNS_STAT_S),a
	jp	END_DNS_TIM

	;* Resend DNS query

	;Compose packet

DNS_RESEND:
	ld	hl,(ID_DNS)	;Identifier
	inc	hl
	ld	(OUT_BUFFER+32),hl
	ld	(ID_DNS),hl

	ld	hl,#0001	;Recursion desired, other flags to 0
	ld	(OUT_BUFFER+34),hl

	ld	hl,#0100
	ld	(OUT_BUFFER+36),hl	;QDCOUNT
	ld	h,0
	ld	(OUT_BUFFER+38),hl	;ANCOUNT
	ld	(OUT_BUFFER+40),hl	;NSCOUNT
	ld	(OUT_BUFFER+42),hl	;ARCOUNT

	ld	hl,DNS_BUFFER	;Name to be resolved
	ld	ix,OUT_BUFFER+44
	call	GET_SERV

	ld	(ix),0		;QTYPE and QCLASS
	ld	(ix+1),1	;(inet, IP address)
	ld	(ix+2),0
	ld	(ix+3),1

	;Send packet

	inc	ix
	inc	ix
	inc	ix
	inc	ix
	push	ix
	pop	hl
	ld	bc,OUT_BUFFER+32
	or	a
	sbc	hl,bc
	push	hl
	pop	bc	;BC = Packet length

	ld	ix,DNS_PORT
	ld	iy,53
	ld	hl,(DNS_IP)
	ld	de,(DNS_IP+2)
	call	SEND_UDP	;Sends packet

	;Update variables

	ld	a,3*60
	ld	(DNS_TOUT),a	;Retransmission timer
	ld	a,(DNS_RETRY)
	inc	a
	ld	(DNS_RETRY),a	;One more retransmission performed

END_DNS_TIM:

	;--- TCP connections timers

	call	IS_CONNECTED
	jr	nz,END_TCP_TIM

	;* Loop all TCP connections

	xor	a
TCP_TIM_LOOP:
	push	af
	ld	b,a
	call	GET_TCB_DIR
	ld	a,(hl)
	or	a
	jr	z,TCP_TIM_NEXT

	ld	a,b
	call	LOAD_TCB

	;* Retransmission timer

	ld	hl,(RTO_T)
	ld	a,h
	or	l
	jr	z,RTO_TIM_OK
	dec	hl
	ld	(RTO_T),hl
RTO_TIM_OK:	;

	;* ACK sending timer

	ld	a,(ACK_DELAY_T)
	or	a
	jr	z,ACK_TIM_OK
	dec	a
	ld	(ACK_DELAY_T),a
ACK_TIM_OK:	;

	;* User timeout

	ld	hl,(USER_TOUT)
	ld	a,h
	or	l
	jr	z,USER_TIM_OK
	dec	hl
	ld	(USER_TOUT),hl
USER_TIM_OK:	;

	;* Non-PUSH data send timer

	ld	hl,(SEND_TOUT)
	ld	a,h
	or	l
	jr	z,SEND_TOUT_OK
	dec	hl
	ld	(SEND_TOUT),hl
SEND_TOUT_OK:	;

	;* Loop to next connection

	call	SAVE_TCB
TCP_TIM_NEXT:
	pop	af
	inc	a
	cp	4
	jr	c,TCP_TIM_LOOP

END_TCP_TIM:

END_TIMERS:


	if	LINK=1

	;===============================================
	;===  Send packet pending an ARP resolution  ===
	;===============================================

	;--- Is there a pending packet?

	ld	a,(WOUT_BUFFER)
	or	a
	jr	z,SEND_WOUT_OK

	;--- Search matching ARP entry

	ld	de,WOUT_IP	;Entry exists?
	call	SRCH_ARP
	jr	c,SEND_WOUT_OK

	ld	a,(ix)	;Is it being resolved?
	cp	3
	jr	z,SEND_WOUT_OK

	;--- Send packet

	push	ix
	ld	hl,WOUT_BUFFER
	ld	de,OUT_BUFFER+4
	ld	bc,576
	ldir

	pop	hl
	inc	hl
	ld	de,#0800
	call	SEND_PACKET

	xor	a	;Clear WOUT_BUFFER
	ld	(WOUT_BUFFER),a
SEND_WOUT_OK:

	endif


	if	LINK=0

	;================================================
	;===  Obtain an incoming packet, PPP version  ===
	;================================================

;The packet start address in memory is decided dynamically
;according to enabled compressions (PPP protocol and/or initial
;#FF #03 compression), so that the packet data (after the PPP
;protocol code) always starts at IN_BUFFER+4.
;(That is, with no compressions in place, packet starts at IN_BUFFER).

GET_PACKET:

	;--- Get incoming data pointer, 0 means that nothing was being received

	ld	hl,(INBUF_PNT)
	ld	bc,(INBUF_SIZE)
	ld	a,h
	or	l
	jr	nz,NONEWPACK

	xor	a
	ld	(BAD_PACKETS),a
NONEWPACK2:
	ld	hl,IN_BUFFER
	ld	bc,0
	ld	(LAST_ESC),a
	ld	(TOO_BIG),a
	ld	(GETPACK_STATE),a
	ld	(GOT_TCP),a
	ld	(VJ_RCVED),a
	ld	(IN_BUFFER),bc
	ld	(IN_BUFFER+2),bc
NONEWPACK:

	;--- Obtain incoming data from serial port while available

RS_IN_LOOP:
	push	hl,bc
	call	RS_IN_STAT
	pop	bc,hl
	or	a
	jp	z,NO_MORE_IN

	push	hl,bc
	call	RS_IN
	pop	bc,hl

	;--- If #7D, it is the escape character

	cp	#7D
	jr	nz,NO_CHAR_ESC
	ld	a,#FF
	ld	(LAST_ESC),a
	jr	RS_IN_LOOP
NO_CHAR_ESC:

	;--- If #7E, it is the packet end mark: process packet

	cp	#7E
	jr	nz,NO_CHAR_END
	ld	hl,0
	ld	(INBUF_PNT),hl
	ld	(INBUF_SIZE),bc
	jp	PROCESS_PACK
NO_CHAR_END:

	;--- Normal character:
	;    Check if it must be unescaped

	ld	d,a
	ld	a,(LAST_ESC)
	or	a
	ld	a,d
	jr	z,NO_CHAR_ESC2
	xor	a
	ld	(LAST_ESC),a
	ld	a,d
	xor	#20
NO_CHAR_ESC2:

	;--- Data obtain state is final (1-4): Store data

	ld	d,a	;D = Data
	ld	a,(GETPACK_STATE)
	ld	e,a	;E = State
	or	a
	jr	z,IS_CHAR_ESP
	cp	5
	jr	c,IS_CHAR_DATA
IS_CHAR_ESP:

	;* Data obtain state 0:
	;  If byte is #FF, enter state 5.
	;  If byte is odd number, enter state 1
	;     and set HL (incoming data pointer) to IN_BUFFER+3.
	;  If byte is even number, enter state 2
	;     and set HL (incoming data pointer) to IN_BUFFER+2
	;     (we don't check if the next byte is odd).

	;ld      a,e
	or	a
	jr	nz,NO_CHARST_0

	ld	a,d
	cp	#FF
	ld	e,5
	jr	z,END_CHARST

	ld	a,d
	and	1
	jr	nz,CHARST_0_IMP

CHARST_0_PAR:
	ld	e,2
	ld	hl,IN_BUFFER+2
	jr	END_CHARST

CHARST_0_IMP:
	ld	e,1
	ld	hl,IN_BUFFER+3
	jr	END_CHARST
NO_CHARST_0:

	;* Data obtain state is 5:
	;  Enter state 6.

	cp	5
	jr	nz,NO_CHARST_5

	ld	e,6
	jr	END_CHARST
NO_CHARST_5:

	;* Data obtain state is 6:
	;  If byte is odd, enter state 3
	;     and set HL (incoming data pointer) to IN_BUFFER+3
	;  If byte is even, enter state 4
	;     (we don't check if the next byte is odd).

	ld	a,d
	and	1
	ld	e,4
	jr	z,END_CHARST

	ld	e,3
	ld	hl,(IN_BUFFER)	;El #FF #03
	ld	(IN_BUFFER+1),hl
	ld	hl,IN_BUFFER+3

	;--- Store received byte and update data pointer and length counter

END_CHARST:
	ld	a,e
	ld	(GETPACK_STATE),a
IS_CHAR_DATA:
	ld	(hl),d
	inc	hl
	inc	bc

	;--- If packet is bigger than 582 bytes:
	;    Reset pointer and length counter,
	;    set TOO_BIG, and terminate.

	ld	de,INBUF_PNT+584
	call	COMP
	jp	c,RS_IN_LOOP

	ld	hl,IN_BUFFER
	ld	bc,0
	ld	a,#FF
	ld	(TOO_BIG),a

	;--- No more incoming data available
	;    but packet is not complete yet

NO_MORE_IN:
	ld	(INBUF_PNT),hl
	ld	(INBUF_SIZE),bc
	jp	END_GET_PACK


	;=========================================
	;===  Process received packet:         ===
	;===  Check taht it is a valid packet  ===
	;=========================================

PROCESS_PACK:

	ld	a,(PPP_STATE)
	cp	4
	jr	nz,PROPACK2
	xor	a	;Reset echo counters
	ld	(ECHOES_SENT),a
	ld	hl,30*60
	ld	(XCP_TTIMER),hl
	ld	hl,1
	ld	(XCP_RTIMER),hl
PROPACK2:

	;--- Too big: discard it

	ld	a,(TOO_BIG)
	or	a
	call	nz,SET_TOSS_FLAG
	jp	nz,END_GET_PACK

	;--- Ends with #7F #7E: discard it

	ld	a,(LAST_ESC)
	or	a
	call	nz,SET_TOSS_FLAG
	jp	nz,END_GET_PACK

	;--- If the packet is too small try to get another one,
	;    up to 50 times per timer interrupt.
	;    Minimum size is 6 bytes, for a VJ compressed packet;
	;    #2D Flags Chk1 Chk2 FCS1 FCS2.
	;    Later, if the packet it is an IP datagram
	;    we will check size again, this time against
	;    a mimimun size of 26 bytes (20 for the IP header).

	ld	hl,(INBUF_SIZE)
	ld	de,6
	call	COMP
	jr	c,IN_SIZE_OK

	ld	a,(BAD_PACKETS)
	cp	50
	jp	nc,END_GET_PACK
	inc	a
	ld	(BAD_PACKETS),a
	xor	a
	jp	NONEWPACK2
IN_SIZE_OK:

	;--- Check FCS unless optimization is ON

	ld	a,(CHKVECT)
	bit	0,a
	jr	z,FCS_OK

	ld	hl,IN_BUFFER+4	;Packet start address=IN_BUFFER+4-(GETPACK_STATE)
	ld	de,(GETPACK_STATE)
	ld	d,0
	or	a
	sbc	hl,de
	ld	de,#FFFF
	ld	bc,(INBUF_SIZE)
	call	CALC_FCS
	ld	hl,#F0B8	;Valid FCS = #F0B8
	call	COMP
	call	nz,SET_TOSS_FLAG
	jp	nz,END_GET_PACK	;Invalid FCS: discard packet
FCS_OK:

	;--- If packet obtain state is 1 or 3, put 0
	;    at IN_BUFFER+2, so that the protocol field has the
	;    appropriate value "#00 (odd number)"

	ld	a,(GETPACK_STATE)
	and	1
	jr	z,FCS_OK2
	xor	a
	ld	(IN_BUFFER+2),a
FCS_OK2:

	ld	hl,#03FF	;Prevents this not being transmitted
	ld	(IN_BUFFER),hl


	;--- Update INBUF_SIZE so that it includes
	;    the initial #FF #03 and the uncompressed protocol code
	;    even if it was not transmitted:
	;    INBUF_SIZE = INBUF_SIZE + 4 - GETPACK_STATE

	ld	hl,(INBUF_SIZE)
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	de,(GETPACK_STATE)
	ld	d,0
	or	a
	sbc	hl,de
	ld	(INBUF_SIZE),hl


	;====================================
	;===  Process received packet:    ===
	;===  Check transported protocol  ===
	;====================================

	ld	hl,(IN_BUFFER+2)

	;--- If protocol is known, jump to the
	;    appropriate handling code

	ld	de,#2100
	call	COMP
	jp	z,IS_IP

	ld	de,#2D00
	call	COMP
	jp	z,IS_VJ_COMP

	ld	de,#2F00
	call	COMP
	jp	z,IS_VJ_UNCOMP

	ld	de,#21C0
	call	COMP
	jp	z,IS_XCP

	ld	de,#2180
	call	COMP
	jp	z,IS_XCP	;LCP and IPCP share handling code

	ld	de,#23C0
	call	COMP
	jp	z,IS_PAP

	ld	de,#23C2
	call	COMP
	jp	z,IS_CHAP

	;--- Unknown protocol:
	;    If packet obtain state is 2, 3 or 4,
	;    send Protocol-Reject

	ld	a,(PPP_STATE)
	cp	2
	jp	c,END_GET_PACK

	ld	a,8	;Code for "Protocol-Reject"
	ld	(OUT_BUFFER+4),a
	ld	a,(ID_PROTREJ)
	ld	(OUT_BUFFER+5),a
	inc	a
	ld	(ID_PROTREJ),a

	ld	hl,(INBUF_SIZE)
	ld	bc,6	;Discounts #FF03, Protocol and FCS
	or	a
	sbc	hl,bc	;HL = Received packet payload length
	ld	de,571
	call	COMP
	jr	nc,NOTRIM
	ld	hl,570	;Max len = 570 for rejected packer + 6 for LCP packet
NOTRIM:

	push	hl
	pop	bc
	push	hl
	ld	hl,IN_BUFFER+4		;Skip #FF03 Proto
	ld	de,OUT_BUFFER+10	;Skip #FF03 Proto 8 Id Len Proto
	ldir

	pop	hl	;Set LCP length
	ld	bc,6
	add	hl,bc
	ld	a,h	;Big-Endian copy
	ld	(OUT_BUFFER+6),a
	ld	a,l
	ld	(OUT_BUFFER+7),a

	ld	hl,(IN_BUFFER+2)	;Rejected protocol
	ld	(OUT_BUFFER+8),hl
	ld	hl,#21C0	;LCP protocol code
	ld	(OUT_BUFFER+2),hl

	call	SEND_PACKET
	jp	END_GET_PACK


	;==============================
	;===  XCP packet received:  ===
	;===  Check packet code     ===
	;==============================

IS_XCP:

	;--- If announced size is >576 bytes, ignore it

	ld	a,(IN_BUFFER+6)
	ld	h,a
	ld	a,(IN_BUFFER+7)
	ld	l,a
	ld	de,577
	call	COMP
	jp	c,END_GET_PACK

	;--- If it is IPCP and packet obtain state is 0, 1 or 2,
	;    ignore packet

	ld	a,(IN_BUFFER+2)
	cp	#80
	jr	nz,IS_XCP2

	ld	a,(PPP_STATE)
	cp	3
	jp	c,END_GET_PACK
	ld	a,(IN_BUFFER+4)
	jp	NOPPPCLO
IS_XCP2:

	;--- If it is LCP and connection state is 0,
	;    send Terminate-Ack and terminate.
	;    (do not send if the received packet is itself a Terminate-Ack)

	ld	a,(PPP_STATE)	;Connection closed?
	or	a
	ld	a,(IN_BUFFER+4)
	jr	nz,NOPPPCLO

	cp	6	;Terminate-Ack packet?
	jp	z,END_GET_PACK
	call	SEND_TACK
	jp	END_GET_PACK
NOPPPCLO:

	;--- Depending on packet type, jump to the appropriate routine
	;    (from this point we know we're not in closed state)

	dec	a
	jp	z,IS_XCP_CREQ	;Configure Request
	dec	a
	jp	z,IS_XCP_CACK	;Configure Ack
	dec	a
	jp	z,IS_XCP_CNACK	;Configure Nack
	dec	a
	jp	z,IS_XCP_CREJ	;Configure Reject
	dec	a
	jp	z,IS_XCP_TREQ	;Terminate Request
	dec	a
	jp	z,IS_XCP_TACK	;Terminate Ack
	dec	a
	jp	z,IS_XCP_PREJ	;Code Reject

	;* For IPCP, checking finishes here,
	;  because IPCP has no codes >7

	ld	b,a
	ld	a,(IN_BUFFER+2)
	cp	#80
	jr	z,IS_XCP_UNK
	ld	a,b

	dec	a
	jp	z,IS_XCP_PREJ	;Protocol Reject
	dec	a
	jp	z,IS_XCP_EREQ	;Echo Request
	dec	a
	jp	z,END_GET_PACK	;Echo Reply: ignore it (not requested)
	dec	a
	jp	z,END_GET_PACK	;Discard Request: ignore it

	;--- Unknown type:
	;    If connection state is at least 1 (LCP) or 3 (XCP)
	;    send Code_Reject

IS_XCP_UNK:	ld	a,(IN_BUFFER+2)	;#C0 for LCP, #80 for IPCP
	and	#40	;Now A=#40 for LCP, 0 for IPCP
	xor	#40	;Invert: now A=0 for LCP, #40 for IPCP
	rlca
	rlca
	rlca
	or	1	;Now A=1 for LCP, 3 for IPCP
	ld	b,a
	ld	a,(PPP_STATE)
	cp	b
	jp	c,END_GET_PACK
	jp	SEND_CREJ


	;========================================
	;===  XCP Configure-Request received  ===
	;========================================

IS_XCP_CREQ:

	;--- We first create a blank Configure-Reject packet

	ld	hl,(IN_BUFFER+2)	;Protocol must match
	ld	(OUT_BUFFER+2),hl
	ld	a,4			;Code for ConfReq
	ld	(OUT_BUFFER+4),a
	ld	a,(IN_BUFFER+5)	;ID must match
	ld	(OUT_BUFFER+5),a

	ld	hl,IN_BUFFER+8	;HL = Pointer to source
	ld	de,OUT_BUFFER+8	;DE = Pointer to destination
	ld	a,(IN_BUFFER+6)
	ld	ixh,a		;IX = Remaining size
	ld	a,(IN_BUFFER+7)
	ld	ixl,a
	dec	ix	;Substract 1 Id Lon
	dec	ix
	dec	ix
	dec	ix

	;--- Option checking loop

XCP_CREQ_LOOP:

	;* More options left?

	ld	a,ixh
	bit	7,a
	jp	nz,END_GET_PACK	;Invalid packet (length of all options <> packet length)
	or	ixl
	jp	z,XCP_CREQ_EOP

	;* For LCP, accept options 1, 2, 3, 7 and 8.
	;  For IPCP, accept only options 2 and 3.

	ld	a,(hl)
	cp	9
	jr	nc,XCP_OP_REJ	;Reject if option>8
	and	%00001111
	ld	a,(IN_BUFFER+2)
	and	#C0
	ld	b,a
	ld	a,(hl)
	or	b	;Now A=Protocol OR option code

	cp	#83
	jp	z,IPCP_OP_IP
	cp	#82
	jp	z,IPCP_OP_VJ
	cp	#C1
	jr	z,LCP_OP_MRU
	cp	#C2
	jr	z,LCP_OP_AM
	cp	#C3
	jr	z,LCP_OP_AU
	cp	#C7
	jp	z,XCP_OP_NEXT	;Protocol compression: accept
	cp	#C8
	jp	z,XCP_OP_NEXT	;Compression of initial #FF #03: accept

	;* Not accpeted option: include it in the Configure-Reject packet
	;  and loop to next option.
	;  HL must point to the beginning of the option.

XCP_OP_REJ:
	inc	hl
	ld	c,(hl)	;BC=Option length
	ld	b,0
	dec	hl
	ld	a,c
	ldir		;This will update HL and DE appropriately
	ld	b,a

LOOPREJ1:
	dec	ix	;Decrease remaining packet length
	djnz	LOOPREJ1
	jp	XCP_CREQ_LOOP

	;* MRU option:
	;  Accept if >=576, reject otherwise

LCP_OP_MRU:
	push	de,hl,hl
	pop	iy
	ld	h,(iy+2)
	ld	l,(iy+3)
	ld	de,576
	call	COMP
	pop	hl,de
	jp	nc,XCP_OP_REJ
	jp	XCP_OP_NEXT

	;* Async-Map option:
	;  Accept if 0, reject otherwise

LCP_OP_AM:	push	hl
	pop	iy
	ld	a,#FF
	ld	(ASYNC_MAP),a
	ld	a,(iy+2)
	or	(iy+3)
	or	(iy+4)
	or	(iy+5)
	jp	nz,XCP_OP_REJ

	xor	a
	ld	(ASYNC_MAP),a
	jp	XCP_OP_NEXT

	;* Authentication option:
	;  Accept if PAP or CHAP, otherwise
	;  send a prebuilt NAK packet

LCP_OP_AU:
	push	de,hl,hl
	pop	iy
	ld	h,(iy+2)
	ld	l,(iy+3)
	res	1,h	;Accept if #C023 and #C223
	ld	de,#C023
	call	COMP
	pop	hl,de
	jr	nz,LCP_AUTH_NAK

	ld	a,(iy+2)
	ld	(AUTH_PROTO),a
	jp	XCP_OP_NEXT

	;Unknown authentication protocol:
	;Prior to v1.1, a Configure NAK packet was sent
	;suggesting PAP and CHAP.
	;This seems to be not the right procedure
	;(according to Linux PPPD), so now
	;the option is simply rejected.
LCP_AUTH_NAK:
	jp	XCP_OP_REJ
	;ld	hl,PACK_NAK
	;ld	de,OUT_BUFFER+2
	;ld	bc,15
	;ldir
	;ld	a,(IN_BUFFER+5)	;Copy ID from Request packet
	;ld	(OUT_BUFFER+5),a
	;call	SEND_PACKET
	;jp	END_GET_PACK
	
	;* Remote IP address option:
	;  If not 0.0.0.0, accept it.
	;  If no 0.0.0.0, send NAK with IP_REMOTE;
	;  but if IP_REMOTE es 0.0.0.0, close connection with error 12.

IPCP_OP_IP:
	push	hl
	pop	iy
	ld	a,(iy+2)
	or	(iy+3)
	or	(iy+4)
	or	(iy+5)
	jr	z,REMIP0

	push	hl,de	;Not 0: accept
	inc	hl
	inc	hl
	ld	de,BUF_IPREMOTE
	ld	bc,4
	ldir
	pop	de,hl
	jp	XCP_OP_NEXT

REMIP0:	ld	iy,BUF_IPREMOTE	;It is 0: check IPREMOTE
	ld	a,(iy+0)
	or	(iy+1)
	or	(iy+2)
	or	(iy+3)
	jr	nz,OKREMIP

	ld	a,12	;Close with error 12
	ld	(PPP_CLCODE),a
	xor	a
	ld	(PPP_STATE),a
	ld	(PCAP_STATE),a
	call	CLOSE_ALL_TCP
	call	SEND_TREQ
	jp	END_GET_PACK

	;* Van Jacobson compresson option:
	;  Accept if USEPPPVJ is #FF
	;  and the proposed slots number is at least 4

IPCP_OP_VJ:
	ld	a,(USEPPPVJ)
	or	a
	jp	z,XCP_OP_REJ

	push	de,hl,hl	;Is it actually VJ compression?
	pop	iy
	ld	h,(iy+2)
	ld	l,(iy+3)
	ld	de,#002D
	call	COMP
	pop	hl,de
	jp	nz,XCP_OP_REJ

	ld	a,(iy+4)	;Maximum slot number
	bit	7,a
	jr	nz,XCP_OP_VJOK	;>127? Accept
	cp	3
	jp	c,XCP_OP_REJ	;<3? Reject

XCP_OP_VJOK:
	ld	a,(iy+5)	;Compress slot number yes/no
	inc	a
	ld	(USE_VJ_OUT),a
	jp	XCP_OP_NEXT

	;Compose ConfNak packet:
	;#80 #21 #02(Nak) Id 0 len(10) 3 6 IP IP IP IP.
	;ID and #8021 are not established because they were already
	;on the Request packet we are overwriting.

OKREMIP:
	ld	a,2
	ld	(OUT_BUFFER+4),a
	ld	hl,#0A00
	ld	(OUT_BUFFER+6),hl
	ld	hl,#0603
	ld	(OUT_BUFFER+8),hl
	ld	hl,BUF_IPREMOTE
	ld	de,OUT_BUFFER+10
	ld	bc,4
	ldir
	ld	hl,#2180
	ld	(OUT_BUFFER+2),hl
	call	SEND_PACKET
	jp	END_GET_PACK

	;* Accepted option:
	;  simply update HL and IX and loop to next option

XCP_OP_NEXT:	inc	hl
	ld	b,(hl)
	dec	hl
LOOPREJ2:	dec	ix
	inc	hl
	djnz	LOOPREJ2
	jp	XCP_CREQ_LOOP

	;--- Option processing end:
	;    Length of rejected options = DE-(OUT_BUFFER+8).
	;    If this length is <>0, there are rejected options,
	;    so the generated Configure-Reject is sent.
	;    Bit if it is 0, no options have been rejected.

XCP_CREQ_EOP:
	ex	de,hl
	ld	de,OUT_BUFFER+8
	or	a
	sbc	hl,de	;Now HL = total length of rejected options
	ld	a,h
	or	l
	jr	z,XCP_OPTS_OK

	;There are rejected options: prepare Reject packet and send it

	ld	bc,4
	add	hl,bc	;Add header length (code ID length)
	ld	a,h
	ld	(OUT_BUFFER+6),a	;LCP length
	ld	a,l
	ld	(OUT_BUFFER+7),a
	call	SEND_PACKET
	jp	END_GET_PACK

	;--- All options have been accepted:
	;    Activate bit on XCP_ACKS that indicates that
	;    we have sent an ACK packet (we'll send it right now).

XCP_OPTS_OK:
	ld	a,(XCP_ACKS)
	or	1
	ld	(XCP_ACKS),a

	call	STATE_UP	;Updates PPP connection state if necessary

	;--- Prepare and send ACK packet:
	;    Simpy copy the Request packet and change its code,
	;    then send packet.

XCP_SACK:
	ld	hl,IN_BUFFER
	ld	de,OUT_BUFFER
	ld	bc,(INBUF_SIZE)
	ldir
	ld	a,2	;Code for Configure-Ack
	ld	(OUT_BUFFER+4),a
	call	SEND_PACKET
	jp	END_GET_PACK


	;====================================
	;===  XCP Configure-Ack received  ===
	;====================================

	;--- Simply update XCP_ACKS
	;    and change the PPP state if necessary

IS_XCP_CACK:
	ld	a,(XCP_ACKS)
	or	2
	ld	(XCP_ACKS),a

	call	STATE_UP
	jp	END_GET_PACK


	;============================================
	;===  XCP Configure-Nack/Reject received  ===
	;============================================

IS_XCP_CNACK:
IS_XCP_CREJ:

	;--- If it is LCP and connection state is not 1,
	;    or if it is IPCP and connection state is not 3,
	;    ignore it

	ld	a,(IN_BUFFER+2)
	ld	b,a
	ld	a,(PPP_STATE)
	or	b

	cp	#C1
	jr	z,IS_XCP_CNROK1
	cp	#83
	jp	nz,END_GET_PACK
IS_XCP_CNROK1:

	;--- Inicialize registers

	ld	iy,IN_BUFFER+8	;IY = Pointer to source (options)
	ld	a,(IN_BUFFER+6)
	ld	ixh,a		;IX = Remaining size
	ld	a,(IN_BUFFER+7)
	ld	ixl,a
	dec	ix	;Substract 1 Id Lon
	dec	ix
	dec	ix
	dec	ix

	;* Load H with protocol (#C0 for LCP, #80 for IPCP);
	;  plus 3 for NACK or 4 for Reject; and the option code will be in L

	ld	a,(IN_BUFFER+2)	;Protocol
	ld	h,a
	ld	a,(IN_BUFFER+4)	;Nack or Reject
	or	h
	ld	h,a

	;--- Option checking loop

XCP_CNR_LOOP:

	;* More options left?

	ld	a,ixh
	bit	7,a
	jp	nz,END_GET_PACK	;Invalid packet (length of all options <> packet length)
	or	ixl
	jp	z,XCP_CNR_EOP

	ld	a,(iy)	;Option code
	ld	l,a

	;* Act according to option

	ld	de,#8303	;Nack for option IP of IPCP
	call	COMP
	jp	z,XCP_CNR_OP3N
	ld	de,#8403	;Reject for option IP of IPCP
	call	COMP
	jp	z,XCP_CNR_OP3R

	ld	de,#8381	;Nack for option DNS1 of IPCP
	call	COMP
	jp	z,XCP_CNR_OP129N
	ld	de,#8481	;Reject for option DNS1 of IPCP
	call	COMP
	jp	z,XCP_CNR_OP129R

	ld	de,#8383	;Nack for option DNS2 of IPCP
	call	COMP
	jp	z,XCP_CNR_OP131N
	ld	de,#8483	;Reject for option DNS2 of IPCP
	call	COMP
	jp	z,XCP_CNR_OP131R

	ld	de,#C301	;Nack for option MRU of LCP
	call	COMP
	jr	z,XCP_CNR_OP1N
	ld	de,#C401	;Reject for option MRU of LCP
	call	COMP
	jr	z,XCP_CNR_OP1R

	ld	de,#C302	;Nack for option Async-Map of LCP
	call	COMP
	jr	z,XCP_CNR_OP2N
	ld	de,#C402	;Reject for option Async-Map of LCP
	call	COMP
	jr	z,XCP_CNR_OP2R

	ld	de,#C307	;Reject of LCP protocol compression 
	call	COMP
	jp	z,XCP_CNR_OP7R
	ld	de,#C308	;Reject of LCP #FF #03 compression
	call	COMP
	jp	z,XCP_CNR_OP8R

	ld	a,h	;From here we don't need to distinguish
	and	#C0	;between Nack and Reject
	ld	h,a

	ld	de,#8002	;Nack or Reject of VJ compression (IPCP)
	call	COMP
	jp	z,XCP_CNR_OP2IP

	;> If we reach this point, it was a Nack/Rej for an option
	;  that we had not sent: ignore it

	;* Loop to next option

XCP_CNR_NEXT:
	ld	b,(iy+1)
LOOPCNR2:	dec	ix
	inc	iy
	djnz	LOOPCNR2
	jp	XCP_CNR_LOOP

	;* Reject of MRU or Async-Map: Do not negotiate again

XCP_CNR_OP1R:
XCP_CNR_OP2R:
	ld	a,l	;1 for MRU, 2 for Async
	cpl
	and	3	;Now %10 for MRU, %01 for Async
	ld	a,(XCP_NEXTOP)
	and	l
	ld	(XCP_NEXTOP),a	;To not negotiate again the option
	jr	XCP_CNR_NEXT

	;* Nack of MRU: set the proposed value as the value to be negotiated next time

XCP_CNR_OP1N:
	push	hl
	ld	h,(iy+2)
	ld	l,(iy+3)
	ld	(NEXT_MRU),hl
	pop	hl
	jr	XCP_CNR_NEXT

	;* Nack of Async-Map: set the proposed value as the value to be negotiated next time

XCP_CNR_OP2N:
	push	hl
	ld	l,(iy+2)
	ld	h,(iy+3)
	ld	(NEXT_ASYNC),hl
	ld	l,(iy+4)
	ld	h,(iy+5)
	ld	(NEXT_ASYNC+2),hl
	pop	hl
	jr	XCP_CNR_NEXT

	;* Nack of IP address: set the proposed value

XCP_CNR_OP3N:
	push	hl
	ld	l,(iy+2)
	ld	h,(iy+3)
	ld	(BUF_IPLOCAL),hl
	ld	l,(iy+4)
	ld	h,(iy+5)
	ld	(BUF_IPLOCAL+2),hl
	pop	hl
	jr	XCP_CNR_NEXT

	;* Reject of IP address: fatal error,
	;  act as if the peer had no IP address for us
	;  and close connection with error 11

XCP_CNR_OP3R:
	ld	a,11
	ld	(PPP_CLCODE),a
	xor	a
	ld	(PPP_STATE),a
	ld	(PCAP_STATE),a
	call	CLOSE_ALL_TCP
	call	SEND_TREQ
	jp	END_GET_PACK

	;* Nack of DNS address: set the proposed value

XCP_CNR_OP129N:
	push	hl
	ld	l,(iy+2)
	ld	h,(iy+3)
	ld	(BUF_IPDNS1),hl
	ld	l,(iy+4)
	ld	h,(iy+5)
	ld	(BUF_IPDNS1+2),hl
	pop	hl
	jr	XCP_CNR_NEXT

XCP_CNR_OP131N:
	push	hl
	ld	l,(iy+2)
	ld	h,(iy+3)
	ld	(BUF_IPDNS2),hl
	ld	l,(iy+4)
	ld	h,(iy+5)
	ld	(BUF_IPDNS2+2),hl
	pop	hl
	jp	XCP_CNR_NEXT

	;* Reject of DNS address: Do not negotiate again

XCP_CNR_OP131R:
XCP_CNR_OP129R:
	xor	a
	ld	(NEGDNS),a
	jp	XCP_CNR_NEXT

	;* Reject for PPP protocol compression:
	;  do not negotiate again

XCP_CNR_OP7R:
	xor	a
	ld	(PPP_COMP_P),a
	jp	XCP_CNR_NEXT

	;* Reject for initial #FF #03 compression:
	;  do not negotiate again

XCP_CNR_OP8R:
	xor	a
	ld	(PPP_COMP_FF),a
	jp	XCP_CNR_NEXT

	;* Reject or NACK for VJ compression:
	;  do not negotiate again

XCP_CNR_OP2IP:
	xor	a
	ld	(USE_VJ_IN),a
	jp	XCP_CNR_NEXT

	;* No more options:
	;  Set retransmission timer to 0, so the appropriate Request packet
	;  will be sent in the next timer interrupt

XCP_CNR_EOP:
	ld	hl,0
	ld	(XCP_RTIMER),hl
	jp	END_GET_PACK


	;============================================
	;===  XCP Terminate-Request/Ack received  ===
	;============================================

IS_XCP_TREQ:

	;--- Send Terminate ACK

	ld	hl,IN_BUFFER	;Copy the request packet,
	ld	de,OUT_BUFFER	;and resend as Ack
	ld	bc,(INBUF_SIZE)
	ldir
	ld	a,6	;Code for TermAck
	ld	(OUT_BUFFER+4),a
	call	SEND_PACKET

	;--- Enter connection state 0 and set close reason

IS_XCP_TACK:
	xor	a
	ld	(PPP_STATE),a
	ld	(PCAP_STATE),a
	call	CLOSE_ALL_TCP
	ld	a,(IN_BUFFER+2)
	cp	#C0
	ld	a,3
	jr	z,IS_XCP_TREQ2
	inc	a
IS_XCP_TREQ2:
	ld	(PPP_CLCODE),a	;3 for LCP, 4 for IPCP
	jp	END_GET_PACK


	;===========================================
	;===  XCP Code/Protocol-Reject received  ===
	;===========================================

	;--- Consider it a fatal error,
	;    so set the appropriate close reason and close connection

IS_XCP_PREJ:
	ld	a,(IN_BUFFER+4)
	add	6	;13 for CodeRej, 14 for ProtoRej
	ld	b,a
	ld	a,(IN_BUFFER+2)
	cp	#C0
	ld	a,b
	jr	z,IS_XCP_CREJ2
	add	2	;Add 2 if it is IPCP
IS_XCP_CREJ2:
	ld	(PPP_CLCODE),a
	call	SEND_TREQ
	jp	END_GET_PACK


	;===================================
	;===  XCP Echo-Request received  ===
	;===================================

	;--- Simply copy packet, change the
	;    Request code for a Reply code, set magic number to 0,
	;    and resend packet

IS_XCP_EREQ:
	ld	hl,IN_BUFFER
	ld	de,OUT_BUFFER
	ld	bc,(INBUF_SIZE)
	ldir
	ld	a,10	;EchoReply code
	ld	(OUT_BUFFER+4),a
	ld	hl,0
	ld	(OUT_BUFFER+8),hl	;Magic number
	ld	(OUT_BUFFER+10),hl
	call	SEND_PACKET
	jp	END_GET_PACK


	;=============================
	;===  PAP packet received  ===
	;=============================

IS_PAP:	ld	a,(IN_BUFFER+4)
	cp	2
	jp	z,IS_XAP_ACK
	cp	3
	jp	z,IS_XAP_NACK
	jp	END_GET_PACK	;Unknown: ignore it


	;==============================
	;===  CHAP packet received  ===
	;==============================

IS_CHAP:	ld	a,(IN_BUFFER+4)
	dec	a
	jr	z,IS_CHAP_CHALL
	dec	a
	dec	a
	jr	z,IS_XAP_ACK
	dec	a
	jr	z,IS_XAP_NACK
	jp	END_GET_PACK	;Unknown: ignore it


	;--- CHAP challenge: composes response and sends it.
	;    OUT_BUFFER+100 is used as temporary buffer
	;    to compose the string to digest using MD5.
	;    This leaves a margin of 484 bytes for the string,
	;    but the maximum size will be:
	;    1 (ID) + 255 (challenge) + 31 (passwordd) = 287.
	;    The packet to be sent will be at most:
	;    4 (#FF03 proto) + 5 (CHAP header) + 16 (hash) + 31 (name)
	;    = 40 bytes < 100.


	;* First compose the whole response packet
	;  except the MD5 digest only

IS_CHAP_CHALL:
	ld	a,2	;Response code
	ld	(OUT_BUFFER+4),a
	ld	hl,#23C2	;Protocol
	ld	(OUT_BUFFER+2),hl
	ld	a,(IN_BUFFER+5)	;ID
	ld	(OUT_BUFFER+5),a
	ld	a,16	;MD5 digest length
	ld	(OUT_BUFFER+8),a

	ld	hl,BUF_PPPUSER
	push	hl	;Copy user name at the end
	call	STRLEN	;of the packet
	pop	hl
	ld	de,OUT_BUFFER+9+16
	push	bc
	ldir
	pop	hl
	ld	bc,16+5	;Packet length = name+header+hash
	add	hl,bc
	ld	h,l
	ld	l,0
	ld	(OUT_BUFFER+6),hl	;Length field

	;* The data to be digested is:
	;  ID + password + challenge

	ld	a,(IN_BUFFER+5)	;Set ID
	ld	(OUT_BUFFER+100),a

	ld	hl,BUF_PPPASSW	;Set password
	push	hl
	call	STRLEN
	pop	hl
	ld	de,OUT_BUFFER+101
	push	bc
	ldir

	ld	a,(IN_BUFFER+8)	;Set challenge
	ld	c,a
	ld	b,0
	ld	hl,IN_BUFFER+9
	push	bc
	ldir

	pop	bc,hl	;Calculate length of resulting string
	add	hl,bc
	inc	hl

	push	hl	;Generate digest
	pop	bc	;and copy it to the response packet
	ld	hl,OUT_BUFFER+100
	call	MD5
	ld	de,OUT_BUFFER+9
	ld	bc,16
	ldir

	call	SEND_PACKET
	jp	END_GET_PACK


	;--- ACK of PAP or CHAP: if connection state
	;    is 2, enter state 3

IS_XAP_ACK:
	ld	a,(PPP_STATE)
	cp	2
	jp	nz,END_GET_PACK

	ld	a,3
	jp	STATEUP_3


	;--- NACK of PAP o CHAP:
	;    close with the appropriate error code

IS_XAP_NACK:
	ld	a,5
	ld	(PPP_CLCODE),a

	call	SEND_TREQ
	jp	END_GET_PACK


	;===============================================
	;===  VJ Uncompressed_TCP datagram received  ===
	;===============================================

IS_VJ_UNCOMP:
	xor	a
	ld	(TOSS_FLAG),a

	;--- Obtain slot id, if it is invalid
	;    set Toss flag and terminate

	ld	a,(IN_BUFFER+13)
	cp	4
	call	nc,SET_TOSS_FLAG
	jp	nc,END_GET_PACK

	ld	(VJ_LAST_ISLOT),a
	ld	(VJ_CUR_ISLOT),a

	;--- Restore protocol code and terminate
	;    (later the TCP/IP header will be copied to appropriate TCB,
	;    when IP and TCP options have been discarded)

	ld	a,6
	ld	(IN_BUFFER+13),a

	ld	a,1
	ld	(VJ_RCVED),a
	jp	IS_IP


	;=============================================
	;===  VJ Compressed_TCP datagram received  ===
	;=============================================

IS_VJ_COMP:
	ld	a,2
	ld	(VJ_RCVED),a

	ld	a,(IN_BUFFER+4)
	ld	(VJ_FLAGS),a
	ld	b,a

	ld	ix,IN_BUFFER+5

	;--- If bit C is set, obtain and store slot ID

	bit	6,b
	jr	z,NO_VJ_C_IN

	xor	a
	ld	(TOSS_FLAG),a
	ld	a,(ix)
	ld	(VJ_LAST_ISLOT),a
	ld	(VJ_CUR_ISLOT),a
	inc	ix
	jr	VJ_OK_C_IN

	;--- If bit C is NOT set, set VJ_CUR_ISLOT as VJ_LAST_ISLOT;
	;    but if VJ_LAST_ISLOT is invalid, set TOSS_FLAG and terminate.
	;    If TOSS_FLAG is already set, terminate.

NO_VJ_C_IN:
	ld	a,(TOSS_FLAG)
	or	a
	jp	nz,END_GET_PACK

	ld	a,(VJ_LAST_ISLOT)
	cp	4
	call	nc,SET_TOSS_FLAG
	jp	nc,END_GET_PACK
	ld	(VJ_CUR_ISLOT),a
VJ_OK_C_IN:

	;--- Search appropriate slot and put its address in IY

	call	GET_VJ_INSLOT
	ld	(VJ_ISLOT_DIR),hl
	push	hl
	pop	iy

	;--- Restore TCP checksum in the stored header

	ld	h,(ix)
	ld	l,(ix+1)
	ld	(iy+40),h
	ld	(iy+41),l
	inc	ix
	inc	ix

	;--- If PUSH bit was set, set it in the header

	ld	a,(iy+37)
	and	%11110111
	ld	b,a
	ld	a,(VJ_FLAGS)
	bit	4,a
	jr	z,VJ_OK_P_IN

	set	3,b
VJ_OK_P_IN:
	ld	(iy+37),b

	;--- If S, W, U are set, add the data size
	;    to the sequence number of the header

	ld	a,(VJ_FLAGS)
	and	%00001011
	cp	%00001011
	jr	nz,VJ_OK_SAWU_IN

	ld	e,(iy)
	ld	d,(iy+1)
	push	iy
	pop	hl
	ld	bc,28
	add	hl,bc
	push	hl
	pop	bc
	push	de
	call	ADD3216
	pop	de

	;* If besides A is NOT set, add the data size
	;  to ACK field

	ld	a,(VJ_FLAGS)
	and	%00000100
	jp	nz,VJ_IN_END

	inc	hl
	inc	hl
	inc	hl
	inc	hl
	push	hl
	pop	bc
	call	ADD3216
	jr	VJ_IN_END
VJ_OK_SAWU_IN:

	;--- Decode URG field if present

	ld	a,(iy+37)
	and	%11011111
	ld	(iy+37),a
	ld	b,a
	ld	a,(VJ_FLAGS)
	bit	0,a
	jr	z,VJ_OK_U_IN

	set	5,b
	ld	(iy+37),b
	call	GET_VJ_VALUE
	ld	(iy+42),b
	ld	(iy+43),c
VJ_OK_U_IN:

	;--- Decode window if present

	ld	a,(VJ_FLAGS)
	bit	1,a
	jr	z,VJ_OK_W_IN

	call	GET_VJ_VALUE
	ld	h,(iy+38)
	ld	l,(iy+39)
	add	hl,bc
	ld	(iy+38),h
	ld	(iy+39),l
VJ_OK_W_IN:

	;--- Calculate ACK field address in the stored header
	;    and put it HL

	push	iy
	pop	hl
	ld	bc,32
	add	hl,bc

	;--- If A is set, increase ACK by the obtained value

	ld	a,(VJ_FLAGS)
	bit	2,a
	jr	z,VJ_OK_A_IN

	call	GET_VJ_VALUE
	push	bc
	pop	de
	push	hl,hl
	pop	bc
	call	ADD3216
	pop	hl
VJ_OK_A_IN:

	;--- If S is set, increase SEQ by the obtained value

	ld	a,(VJ_FLAGS)
	bit	3,a
	jr	z,VJ_OK_S_IN

	call	GET_VJ_VALUE
	push	bc
	pop	de
	dec	hl
	dec	hl
	dec	hl
	dec	hl
	push	hl
	pop	bc
	call	ADD3216
VJ_OK_S_IN:

	;--- If I is set, add the obtained value to ID.
	;    Otherwise, add one.

VJ_IN_END:
	ld	bc,1
	ld	a,(VJ_FLAGS)
	bit	5,a
	jr	z,VJ_OK_I_IN

	call	GET_VJ_VALUE
VJ_OK_I_IN:
	ld	h,(iy+8)
	ld	l,(iy+9)
	add	hl,bc
	ld	(iy+8),h
	ld	(iy+9),l

	;--- Update total size of IP datagram field.
	;    It must be: (INBUF_SIZE)-6-(VJ header length)+40

	push	ix
	pop	hl
	ld	bc,IN_BUFFER+4
	or	a
	sbc	hl,bc	;HL=VJ header length

	push	hl
	pop	bc
	ld	hl,(INBUF_SIZE)
	or	a
	sbc	hl,bc	;HL=(INBUF_SIZE)-VJ header length

	ld	bc,40-6
	add	hl,bc	;HL = The length we were searching

	ld	(iy+6),h	;Update IP header
	ld	(iy+7),l

	ld	bc,6	;New INBUF_SIZE=Total IP size + PPP header size
	add	hl,bc
	ld	(INBUF_SIZE),hl

	;--- Header is already completely regenerated.
	;    Calculate the new IP checksum.
	;    (removed, it is actually not necessary)

	;ld	(iy+14),0
	;ld	(iy+15),0
	push	ix	;IX: We'll use this value later,
	;push	iy	;when copying data to IN_BUFFER+44
	;pop	ix
	;inc	ix
	;inc	ix
	;inc	ix
	;inc	ix
	;ld	bc,20
	;call	CALC_CHKSUM
	;ld	(iy+14),e
	;ld	(iy+15),d

	;--- Move data (now pointer by IX, in the stack) to IN_BUFFER+44.
	;    Use LDDR, otherwise data will overwrite itself!!

	ld	hl,(INBUF_SIZE)
	ld	bc,40+6
	or	a
	sbc	hl,bc
	push	hl
	pop	bc
	ld	a,b
	or	c
	pop	hl	;Data address, previously in IX
	jr	z,VJ_OK_COPY

	add	hl,bc	;HL=Source final address
	ex	de,hl
	ld	hl,IN_BUFFER+44
	add	hl,bc
	ex	de,hl	;DE=Destination final address
	inc	bc
	lddr
VJ_OK_COPY:

	;--- Copy the regenerated header to IN_BUFFER+4

	push	iy
	pop	hl
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	de,IN_BUFFER+4
	ld	bc,40
	ldir

	;--- End

	ld	hl,#2100
	ld	(IN_BUFFER+2),hl
	ld	hl,#03FF
	ld	(IN_BUFFER),hl
	jp	IS_IP

	endif


	if	LINK=1

	;=====================================================
	;===  Obtain an incoming packet, Ethernet version  ===
	;=====================================================

;The packet start address in memory is decided dynamically
;according to the packet type (Ethernet II or IEEE802.3),
;so that the packet data (after the Ethernet header)
;always starts at IN_BUFFER+4.
;This allows to use the same IP/UDP/TCP processing code
;as the PPP version.

GET_PACKET:
	ethnet	ETH_IN_STATUS	;BC=length, HL=Eth-Type or length
	or	a
	jp	z,END_GET_PACK

	;--- If there is a frame available, network is active

	ld	a,#FF
	ld	(NET_STATE),a
	ld	de,5*60
	ld	(NETSTAT_TIMER),de

	;--- If frame payload is >576 bytes, discard it

	ld	a,b
	and	%11111100
	jp	nz,END_GET_PACK
	ld	a,b
	or	c
	jp	z,END_GET_PACK

	push	hl,bc
	pop	hl

	ld	de,576+22+1	;Prevents IEEE802.3 header
	call	COMP	;NC if HL<DE
	pop	hl
	jr	nc,INSIZE_OK

	ld	hl,0	;Too big: discard it
	ethnet	ETH_GET_FRAME
	jp	END_GET_PACK
INSIZE_OK:

	;--- Retrieve frame at the appropriate address
	;    according to its type

	ld	de,1501
	call	COMP
	jr	nc,IN_IS_IEEE

	;* Ethernet 2 type

	ld	hl,IN_BUFFER-10
	ethnet	ETH_GET_FRAME

	ld	(INBUF_SIZE),bc
	jr	IN_GET_OK

	;* IEEE802.3 type

IN_IS_IEEE:

	ld	hl,IN_BUFFER-18
	ethnet	ETH_GET_FRAME

	;Modify header so that MAC addresses and ether-type
	;are in the same place as in Ethernet 2 frames

	push	bc
	pop	hl
	ld	bc,8
	or	a
	sbc	hl,bc
	ld	(INBUF_SIZE),hl

	ld	hl,IN_BUFFER-18+6
	ld	de,IN_BUFFER-10+6
	ld	bc,6
	ldir
	ld	hl,IN_BUFFER-18
	ld	de,IN_BUFFER-10
	ld	bc,6
	ldir
IN_GET_OK:

	;--- Check that destination MAC address matches our address
	;    or is the broadcast address (prevents promiscuous mode
	;    being set by another program)

	ld	hl,HWAD
	ld	de,IN_BUFFER-10
	call	COMP32
	jp	nz,GETP_CHKBRO

	ld	hl,(HWAD+4)
	ld	de,(IN_BUFFER-10+4)
	call	COMP32
	jp	z,OK_GETP_HW

GETP_CHKBRO:	ld	hl,ETH_BROAD
	ld	de,IN_BUFFER-10
	call	COMP32
	jp	nz,END_GET_PACK

	ld	hl,(ETH_BROAD+4)
	ld	de,(IN_BUFFER-10+4)
	call	COMP32
	jp	nz,END_GET_PACK

OK_GETP_HW:


	;====================================
	;===  Process received frame:     ===
	;===  Check transported protocol  ===
	;====================================

	ld	hl,(IN_BUFFER+2)	;Ether-Type

	;--- If protocol is known, jump to the
	;    appropriate handling code

	ld	de,#0008
	call	COMP
	jp	z,IS_IP

	ld	de,#0608
	call	COMP
	jp	z,IS_ARP

	;--- Unknown protocol: ignore frame

	jp	END_GET_PACK


	;============================
	;===  ARP frame received  ===
	;============================

	;Algorithm according to RFC826, "Packet Reception"

IS_ARP:
	;--- Check hardware and protocol

	ld	hl,(IN_BUFFER+4)
	ld	de,#0100
	call	COMP
	jp	nz,END_GET_PACK

	ld	hl,(IN_BUFFER+6)
	ld	de,#0008
	call	COMP
	jp	nz,END_GET_PACK

	;--- Check if hardware address size is 0: UNARP packet.
	;    In this case, search the entry and delete it
	;    unless it is a static entry.

	ld	a,(IN_BUFFER+8)
	cp	6
	jr	z,NO_UNARP
	or	a
	jp	nz,END_GET_PACK	;If not 0 nor 6, invalid value

	ld	de,IN_BUFFER+18	;Search ARP entry...
	call	SRCH_ARP
	jp	c,END_GET_PACK

	ld	a,(ix)
	cp	1
	jp	z,END_GET_PACK

	ld	(ix),0		;...and if found and not static,
	call	END_GET_PACK	;delete it.
NO_UNARP:

	;--- If source IP address is 0, do not cache the address
	;    (DHCP clients checking its newly assigned address
	;    may send ARP request with the IP of sender set to 0)

	ld	a,#FF
	ld	(MERGE_FLAG),a

	ld	hl,IN_BUFFER+18
	ld	de,ZERO32
	call	COMP32
	jr	z,IS_ARP_2

	;--- Check if there is an ARP entry for this IP

	xor	a
	ld	(MERGE_FLAG),a

	ld	de,IN_BUFFER+18
	call	SRCH_ARP
	jr	c,NOTINCACHE

	;* Found: update MAC address

	ld	a,#FF
	ld	(MERGE_FLAG),a

	ld	a,(ix)	;Static entry: do nothing
	cp	1
	jp	z,NOUPTIMER

	push	ix
	pop	de
	inc	de
	ld	hl,IN_BUFFER+12
	ld	bc,6

	ldir
NOUPTIMER:

	;* Update entry expiration timer

	ld	(ix),2	;Prevents entry being in resolution
	push	ix
	pop	hl
	ld	bc,11
	add	hl,bc
	ex	de,hl
	ld	hl,ARP_TOUT
	ld	bc,4
	ldir
NOTARPSTAT:
NOTINCACHE:

	;--- If required IP is not our address, terminate

IS_ARP_2:
	ld	hl,IN_BUFFER+28
	ld	de,BUF_IPLOCAL
	call	COMP32
	jp	nz,END_GET_PACK

	;--- If the entry was not in the table, create it

	ld	a,(MERGE_FLAG)
	or	a
	jr	nz,OKMERGEARP

	call	GET_FREE_ARP

	ld	(ix),2	;Dynamic entry

	push	ix	;Copy MAC and IP with one single LDIR
	pop	de
	inc	de
	ld	hl,IN_BUFFER+12
	ld	bc,10
	ldir

	ld	hl,ARP_TOUT	;Set expiration timer
	ld	bc,4
	ldir
OKMERGEARP:

	;--- If it was a Request packet, send Reply

	ld	a,(IN_BUFFER+11)
	cp	1
	call	z,SEND_ARP_RP

	jp	END_GET_PACK

MERGE_FLAG:
	db	0

	endif


	;==============================
	;===  IP datagram received  ===
	;==============================

IS_IP:	;

	;--- First check that it reaches the minimum size:
	;    #FF #03 #00 #21 Header(20) FCS1 FCS2

	ld	hl,(INBUF_SIZE)
	ld	de,26
	call	COMP
	jp	nc,END_GET_PACK

	;--- Save header size.
	;    If <20 bytes, ignore datagram.

	ld	a,(IN_BUFFER+4)
	and	#0F
	cp	5
	jp	c,END_GET_PACK

	sla	a
	sla	a
	ld	l,a
	ld	h,0
	ld	(IP_HEADER_LEN),hl

	;--- Save total datagram length.
	;    If >576 bytes, ignore datagram.

	ld	a,(IN_BUFFER+6)
	ld	h,a
	ld	a,(IN_BUFFER+7)
	ld	l,a
	ld	de,577
	call	COMP
	jp	c,END_GET_PACK

	ld	(IP_TOTAL_LEN),hl

	;--- Calculate header checksum

	if	LINK=0

	ld	a,(VJ_RCVED)	;If it was VJ Compressed_TCP, header was
	cp	2		;generated by us: don't calculate checksum
	jr	z,IPCHKSOK

	endif

	ld	a,(CHKVECT)
	and	%10
	jr	z,IPCHKSOK

	ld	ix,IN_BUFFER+4
	ld	bc,(IP_HEADER_LEN)
	call	CALC_CHKSUM
	ld	a,d
	or	e
	jp	nz,END_GET_PACK
IPCHKSOK:	;

	if	LINK=1

	;--- Check destination IP address,
	;    must be our address or a broadcast address

	;* Is it our address?

	ld	hl,IN_BUFFER+20
	ld	de,BUF_IPLOCAL
	call	COMP32
	jr	z,OK_IPDEST

	;* Is it a broadcast address?
	;  (Network mask OR address = all ones)

	ld	hl,SUBNET_MASK
	ld	de,IN_BUFFER+20
	ld	b,4
CHKIPBROAD2:
	ld	a,(de)
	or	(hl)
	inc	a
	jp	nz,END_GET_PACK
	inc	hl
	inc	de
	djnz	CHKIPBROAD2
OK_IPDEST:

	endif

	;--- Check if datagram must be captured

	ld	a,(PCAP_STATE)	;Capture requested?
	cp	1
	jr	nz,NO_PCAP

	ld	a,(PCAP_PROTO)	;Capture all?
	or	a
	jr	z,DO_PCAP

	ld	b,a	;Protocol matches?
	ld	a,(IN_BUFFER+13)
	ld	d,a
	cp	b
	jr	z,DO_PCAP
	ld	a,b

	cp	#FF	;All except UDP, TCP and ICMP echo?
	jr	nz,NO_PCAP

	;Check if it is UDP, TCP or ICMP echo

	ld	a,d
	cp	6	;TCP
	jr	z,NO_PCAP
	cp	17	;UDP
	jr	z,NO_PCAP
	cp	1	;ICMP
	jr	nz,DO_PCAP

	ld	a,(IN_BUFFER+24)
	or	a	;ECHO Reply?
	jr	z,NO_PCAP
	cp	8	;ECHO request?
	jp	z,NO_PCAP

	;Capture datagram

DO_PCAP:
	ld	a,(IN_BUFFER+6)
	ld	b,a
	ld	a,(IN_BUFFER+7)
	ld	c,a
	ld	(PCAP_SIZE),bc
	ld	hl,IN_BUFFER+4
	ld	de,PCAP_BUFFER
	ldir

	ld	a,2
	ld	(PCAP_STATE),a
	jp	END_GET_PACK

NO_PCAP:

	;--- If version field is not 4, ignore datagram

	ld	a,(IN_BUFFER+4)
	and	#F0
	cp	#40
	jp	nz,END_GET_PACK

	;--- If it is a datagram fragment, ignore it

	ld	hl,(IN_BUFFER+10)
	res	7,l	;Reset unused bit (prevents future extensions of IP)
	res	6,l	;Reset DF bit. Now HL has only DF & Fragment offset bits.
	ld	a,h	;If MF or Fragment Offset are set,
	or	l	;it is a fragment: ignore it
	jp	nz,END_GET_PACK

	;--- If the datagram contains options, discard them
	;    (move data to IN_BUFFER+24)

	ld	hl,(IP_HEADER_LEN)	;HL = Header length
	ld	de,20
	call	COMP
	jr	z,IPOPTOK

	ld	bc,IN_BUFFER+4
	add	hl,bc	;HL = Start of data
	ld	de,IN_BUFFER+24
	ld	bc,(IP_TOTAL_LEN)
	ldir

	ld	hl,(IP_TOTAL_LEN)	;Change datagram size
	ld	de,(IP_HEADER_LEN)	;to not include IP options
	or	a
	sbc	hl,de	;HL = Size without headers
	ld	de,20
	add	hl,de	;HL = Size with header and without options
	ld	a,h
	ld	(IN_BUFFER+6),a
	ld	a,l
	ld	(IN_BUFFER+7),a
	ld	(IP_TOTAL_LEN),hl
	ld	(IP_HEADER_LEN),de
IPOPTOK:

	if	LINK=0

	;--- If it was VJ Uncompressed_TCP,
	;    copy headers to the appropriate slot.

	ld	a,(VJ_RCVED)
	cp	1
	jr	nz,NO_VJU_RCV

	ld	a,(IN_BUFFER+36)
	push	af
	and	#F0
	or	#50	;Save with TCP header size=20
	ld	(IN_BUFFER+36),a
	ld	a,(VJ_CUR_ISLOT)
	call	GET_VJ_INSLOT
	ld	(VJ_ISLOT_DIR),hl
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ex	de,hl
	ld	hl,IN_BUFFER+4
	ld	bc,40
	ldir
	pop	af
	ld	(IN_BUFFER+36),a
NO_VJU_RCV:

	endif

	;--- Substitute total datagram size field for
	;    data size, in little-endian

	ld	hl,(IP_TOTAL_LEN)
	ld	de,(IP_HEADER_LEN)
	or	a
	sbc	hl,de
	ld	(IN_BUFFER+6),hl

	;--- Decide action according to transported protocol

	ld	a,(IN_BUFFER+13)
	cp	6
	jp	z,IS_TCP
	cp	17
	jp	z,IS_UDP
	cp	1
	jp	z,IS_ICMP

	;jp	END_GET_PACK	;Unknown: discard datagram

	;Note: IS_xxx routines always terminate with JP END_GET_PACK

	;--- Process the next TCP connection

END_GET_PACK:
	call	IS_CONNECTED
	ret	nz

	jp	DO_TCP_PROCESS


	;===============================
	;===  ICMP message received  ===
	;===============================

IS_ICMP:
	;--- Check checksum

	ld	a,(CHKVECT)
	and	%10000
	jr	z,ICMPCHK_OK

	ld	ix,IN_BUFFER+24
	ld	bc,(IN_BUFFER+6)
	call	CALC_CHKSUM
	ld	a,d
	or	e
	jp	nz,END_GET_PACK
ICMPCHK_OK:

	;--- Check type

	ld	a,(IN_BUFFER+24)
	or	a	;ECHO Reply?
	jr	z,IS_ICMP_EREP
	cp	3
	jp	z,IS_ICMP_HOSTUN
	cp	8	;ECHO request?
	jp	nz,END_GET_PACK	;Other: ignore it

	;--- ICMP Echo Request: Reply iy if REPLYECHO<>0

IS_ICMP_EREQ:
	ld	a,(REPLYECHO)
	or	a
	jp	z,END_GET_PACK

	ld	hl,IN_BUFFER+24	;Copy message verbosely
	ld	de,OUT_BUFFER+24
	ld	bc,(IN_BUFFER+6)
	push	bc
	inc	bc	;To include padding zero
	ldir

	xor	a
	ld	(OUT_BUFFER+24),a	;Change type to "Echo reply"
	pop	bc
	ld	hl,0
	ld	(OUT_BUFFER+26),hl	;Delete old checksum
	ld	ix,OUT_BUFFER+24
	call	CALC_CHKSUM
	ld	(OUT_BUFFER+26),de	;Calculate new checksum

	ld	hl,(IN_BUFFER+16)	;Destination IP = message sender
	ld	de,(IN_BUFFER+18)
	ld	bc,(IN_BUFFER+6)	;Length
	ld	a,1	;Protocol = ICMP
	jp	SEND_IP

	;--- ICM Echo Reply: queue it if there is enough room
	;    (there is space for 4 messages to be stored)

IS_ICMP_EREP:
	ld	a,(ICMPI_PINDEX)
	ld	b,a

	inc	b
	ld	ix,ICMPI_IP0-11
	ld	de,11
BUC_EREP1:
	add	ix,de
	djnz	BUC_EREP1	;Now IX points to the appropriate data area

	ld	a,(ICMPI_PINDEX)
	ld	b,a
	ld	a,(ICMPI_GINDEX)
	cp	b
	jr	nz,EREP_OKROOM

	ld	a,(ix)	;GET index = PUT index:
	or	(ix+1)	;There is room if the entry is empty (IP=0),
	or	(ix+2)	;otherwise, terminate.
	or	(ix+3)
	jp	nz,END_GET_PACK
EREP_OKROOM:			;

	ld	hl,(IN_BUFFER+16)
	ld	(ix),l
	ld	(ix+1),h
	ld	hl,(IN_BUFFER+18)
	ld	(ix+2),l
	ld	(ix+3),h
	ld	a,(IN_BUFFER+12)	;TTL
	ld	(ix+4),a
	ld	hl,(IN_BUFFER+28)	;Identifier (we store in little-endian)
	ld	(ix+5),h
	ld	(ix+6),l
	ld	hl,(IN_BUFFER+30)	;Sequence number (we store in little-endian)
	ld	(ix+7),h
	ld	(ix+8),l
	ld	hl,(IN_BUFFER+6)	;Data length
	ld	bc,8	;Substracts ICMP header length
	or	a
	sbc	hl,bc
	ld	(ix+9),l
	ld	(ix+10),h

	ld	a,(ICMPI_PINDEX)	;Increase PUT index,
	inc	a	;jumping from 3 to 0 if necessary
	and	%111
	ld	(ICMPI_PINDEX),a

	jp	END_GET_PACK

	;--- ICMP Destination Unreachable: if it refers to an
	;    existing TCP connection, abort connection with error code 7.

	;Nota: the header of the packet that caused this message
	;ICMP to be returned is at IN_BUFFER+32.

IS_ICMP_HOSTUN:
	ld	a,(IN_BUFFER+9+32)
	cp	6	;If the offending packet it not TCP, ignore it
	jp	nz,END_GET_PACK

	ld	hl,(IN_BUFFER+20+28)
	ld	de,(IN_BUFFER+22+28)
	ld	a,(IN_BUFFER+24+28)
	ld	iyh,a
	ld	a,(IN_BUFFER+25+28)
	ld	iyl,a
	ld	a,(IN_BUFFER+26+28)
	ld	ixh,a
	ld	a,(IN_BUFFER+27+28)
	ld	ixl,a
	call	SEARCH_TCP
	cp	#FF	;Not referring to an existing TCP connection: terminate
	jp	z,END_GET_PACK

	call	LOAD_TCB
	xor	a	;Close connection with error code 7
	ld	(TCP_STATE),a
	ld	a,7
	ld	(LAST_CLOSE),a
	call	SAVE_TCB

	jp	END_GET_PACK


	;=============================
	;===  UDP packet received  ===
	;=============================

IS_UDP:
	;--- Check checksum, unless CHKVECT says no

	ld	a,(CHKVECT)
	and	%1000
	jp	z,OK_UDP_CHKSUM

	;* To calculate checksum, compose pseudo-header
	;  immediately before data, overwriting the IP header.
	;  But since the order of the 16-bit words is not meaningful
	;  for the checksum calculation,
	;  we recycle the IP addresses and the protocol field already set
	;  on the IP header; therefore we only need to set 0 on the TTL field
	;  and the UDP length on the IP checksum field.

	xor	a
	ld	(IN_BUFFER+12),a	;TTL field
	ld	hl,(IN_BUFFER+28)	;UDP length on the IP checksum field
	ld	(IN_BUFFER+14),hl

	ld	hl,(IN_BUFFER+6)
	ld	bc,12	;To include pseudo-header
	add	hl,bc
	push	hl
	pop	bc
	ld	ix,IN_BUFFER+12
	call	CALC_CHKSUM
	ld	a,d
	or	e
	jp	nz,END_GET_PACK
OK_UDP_CHKSUM:

	;--- Checksum OK: check if it is a DNS reply or a DHCP packet,
	;    in this case jump to the appropriate processing code

	ld	a,(IN_BUFFER+26)
	ld	h,a
	ld	a,(IN_BUFFER+27)
	ld	l,a
	ld	de,DNS_PORT
	call	COMP
	jp	z,IS_DNS

	if	LINK=1

	ld	de,68
	call	COMP
	jp	z,IS_DHCP

	endif

	;--- Check if the packet can be stored
	;    (there is space for 8 packets to be stored)

	ld	hl,(IN_BUFFER+6)	;Too big?
	ld	de,556+8+1
	call	COMP
	jp	c,END_GET_PACK

	ld	a,(UDPI_PINDEX)
	ld	b,a

	inc	b
	ld	ix,UDPI_IP0-10
	ld	de,10
BUC_UDP1:
	add	ix,de
	djnz	BUC_UDP1	;Now IX points to the appropriate buffer

	ld	a,(UDPI_PINDEX)
	ld	b,a
	ld	a,(UDPI_GINDEX)
	cp	b
	jr	nz,UDPI_HAYSITIO

	ld	a,(ix)	;GET index = PUT index:
	or	(ix+1)	;There is room if the entry is empty (IP=0),
	or	(ix+2)	;otherwise, terminate.
	or	(ix+3)
	jp	nz,END_GET_PACK
UDPI_HAYSITIO:

	;--- Store packet

	ld	hl,(IN_BUFFER+16)	;Source IP
	ld	(ix),l
	ld	(ix+1),h
	ld	hl,(IN_BUFFER+18)
	ld	(ix+2),l
	ld	(ix+3),h
	ld	hl,(IN_BUFFER+24)	;Source port (little endian)
	ld	(ix+4),h
	ld	(ix+5),l
	ld	hl,(IN_BUFFER+26)	;Destination port (little endian)
	ld	(ix+6),h
	ld	(ix+7),l
	ld	hl,(IN_BUFFER+6)	;UDP data length
	ld	bc,8
	or	a
	sbc	hl,bc
	ld	(ix+8),l
	ld	(ix+9),h

	ld	a,h	;Copy data part unless its length is 0
	or	l
	jr	z,OK_UDPIDATA

	push	hl
	ld	hl,UDP_BUFFERS-556
	ld	de,556
	ld	a,(UDPI_PINDEX)
	inc	a
	ld	b,a
UDPLEN_LOP1:	add	hl,de
	djnz	UDPLEN_LOP1
	ex	de,hl
	ld	hl,IN_BUFFER+32
	pop	bc
	ldir
OK_UDPIDATA:	;

	ld	hl,UDPI_PINDEX
	call	INC_UDPINDEX	;Update index for the next packet
	jp	END_GET_PACK


;--- This subroutine increases UDPI_PINDEX or UDPI_GINDEX (address passed in HL).
;    Wraps from 7 to 0, or from 6 to 0 if there is a captured packet
;    or a packet capture is pending.
;    Modifies: AF, BC, HL

INC_UDPINDEX:	ld	a,(hl)
	inc	a
	and	%111
	ld	(hl),a

	ld	b,a
	ld	a,(PCAP_STATE)
	or	a
	ret	z
	ld	a,b

	cp	7
	ret	nz
	ld	a,6
	ld	(hl),a
	ret


	;=============================
	;===  DNS packet received  ===
	;=============================

IS_DNS:
	;--- Check if there is a query in progress
	;    and the response ID matches the last sent query ID;
	;    if not, discard packet.

	ld	a,(DNS_STAT_P)
	cp	1
	jp	nz,END_GET_PACK

	ld	hl,(IN_BUFFER+32)
	ld	de,(ID_DNS)
	call	COMP
	jp	nz,END_GET_PACK

	;--- If the response is truncated, terminate with error 21
	;    unless we can try with secondary server.

	ld	a,(IN_BUFFER+34)
	and	%00000010
	jr	z,DNS_NOTRUNC

	call	DNS_USE_SEC
	jp	nc,END_GET_PACK

	ld	a,3
	ld	(DNS_STAT_P),a
	ld	a,21
	ld	(DNS_STAT_S),a
	jp	END_GET_PACK
DNS_NOTRUNC:

	;--- If the response contains any error, set it and terminate,
	;    unless we can try with secondary server.

	ld	a,(IN_BUFFER+35)
	and	%00001111
	jr	z,DNS_NOERR

	call	DNS_USE_SEC
	jp	nc,END_GET_PACK

	ld	a,3
	ld	(DNS_STAT_P),a
	ld	a,(IN_BUFFER+35)
	and	%00001111
	ld	(DNS_STAT_S),a
	jp	END_GET_PACK
DNS_NOERR:

	;--- The response does not contain any error.
	;    Check if it contains any valid resource information.

	ld	ix,IN_BUFFER+32	;Point to packet start DNS

	ld	h,(ix+6)
	ld	l,(ix+7)
	ld	(ANCOUNT),hl	;Resource count
	ld	h,(ix+8)
	ld	l,(ix+9)
	ld	(NSCOUNT),hl	;Authoritative servers count
	ld	h,(ix+10)
	ld	l,(ix+11)
	ld	(ARCOUNT),hl	;Additional sections count

	ld	ix,IN_BUFFER+44	;IX=Start of query

SKIPQ_LOOP:
	ld	a,(ix)	;Skip query
	inc	ix	;(QNAME field)
	or	a	;checking for compression
	jr	z,SKIPQ_LOOP3
	bit	7,a
	jr	z,SKIPQ_LOOP
SKIPQ_LOOP2:
	inc	ix	;Skip QTYPE and QCLASS
SKIPQ_LOOP3:
	inc	ix	;(plus the second byte of pointer if necessary)
	inc	ix
	inc	ix
	inc	ix	;Now IX points to the resources

	;* Check if the requested address was already provided

SCAN_FOR_AN:
	ld	bc,(ANCOUNT)
	ld	a,b
	or	c
	jr	z,SCAN_FOR_NS
	call	SCAN_DNS_RR
	or	a
	jr	z,SCAN_FOR_NS

	ld	a,2	;If valid resource present,
	ld	(DNS_STAT_P),a	;set status=2 and terminate
	xor	a
	ld	(DNS_STAT_S),a
	jp	END_GET_PACK

	;* Otherwise, chek for other DNS servers IPs
	;  in "Authoritative" or in "Aditional"

SCAN_FOR_NS:
	ld	bc,(NSCOUNT)
	ld	a,b
	or	c
	jr	z,SCANNS_FAILED	;Empty NS section?

	call	SCAN_DNS_RR	;Search server IPs
	or	a	;in "authoritative"
	jp	nz,CHANGE_DNS_IP

	ld	bc,(ARCOUNT)
	ld	a,b
	or	c
	jr	z,SCANNS_FAILED	;Empty AR section?

	call	SCAN_DNS_RR	;Search server IPs
	or	a	;in "additional"
	jp	nz,CHANGE_DNS_IP

SCANNS_FAILED:
	ld	a,3	;If both NS and AR are empty, error 20
	ld	(DNS_STAT_P),a
	ld	a,20
	ld	(DNS_STAT_S),a
	jp	END_GET_PACK

	;* The IP of other DNS server has been found:
	;  Repeat query using this address.

CHANGE_DNS_IP:
	ld	hl,DNS_RESULT
	ld	de,DNS_IP	;Set new DNS server address
	ld	bc,4
	ldir

	ld	hl,(ID_DNS)	;Increase identifier
	inc	hl
	ld	(ID_DNS),hl

	ld	a,3	;Set secondary state to 3
	ld	(DNS_STAT_S),a
	xor	a	;Initialize retry count
	ld	(DNS_RETRY),a
	inc	a
	ld	(DNS_TOUT),a	;This causes the query to be sent immediately

	jp	END_GET_PACK


	;--- This subroutine examinates the zone pointed by IX
	;    and searches a RR of type "Address IP".
	;    If found, copies the IP address to DNS_REPLY
	;    and sets DNS_RESP_FLAG to #FF (returned also in A).
	;    At the end, IX poins to the next zone.
	;
	;    Input: BC = Count of RRs in the zone.

SCAN_DNS_RR:
	xor	a
	ld	(DNS_RESP_FLAG),a

DNS_AN_LOOP:
	push	bc
SKIPQ_LOOP4:
	ld	a,(ix)	;Skip name, checking for compression
	inc	ix	;comprobando if esta comprimido
	or	a
	jr	z,SKIPQ_LOOP6
	bit	7,a
	jr	z,SKIPQ_LOOP4
SKIPQ_LOOP5:	inc	ix
SKIPQ_LOOP6:	;

	ld	a,(DNS_RESP_FLAG)	;If there is a valid reply,
	or	a	;simply skip RR
	jr	nz,DNS_AN_LOOP2

	;* Check that type is "IP address"

	ld	h,(ix)	;IX points to TYPE
	ld	l,(ix+1)
	ld	de,1
	call	COMP
	jr	nz,DNS_AN_LOOP2

	;* Answer found: copy it to DNS_RESULT

	ld	l,(ix+10)
	ld	h,(ix+11)
	ld	e,(ix+12)
	ld	d,(ix+13)
	ld	(DNS_RESULT),hl
	ld	(DNS_RESULT+2),de

	ld	a,#FF
	ld	(DNS_RESP_FLAG),a

	;* Go to next RR

DNS_AN_LOOP2:
	ld	bc,10
	add	ix,bc	;So that it points to RDATA
	ld	b,(ix-2)
	ld	c,(ix-1)	;BC = RDLENGTH
	add	ix,bc

	;* If there are RRs left, start again

	pop	bc
	dec	bc
	ld	a,b
	or	c
	jr	nz,DNS_AN_LOOP

	ld	a,(DNS_RESP_FLAG)
	ret

DNS_RESP_FLAG:	db	0	;#FF when a reply is found


	;--- This subroutine is invoked when an invalid DNS packet
	;    is received or all retransmissions are exhausted.
	;    It checks if the DNS server used was the primary one
	;    and there is a secondary server available.
	;    If that is the case, set the secondary server address to DNS_IP,
	;    set DNS_STAT_S to 2 DNS_RETRY to 0 (that is, prepare all to
	;    repeat the query using the secondary server), and return Cy=0.
	;    Otherwise, return Cy=1 (error).

DNS_USE_SEC:
	ld	a,(DNS_STAT_S)
	cp	1
	scf
	ret	nz	;Not the primary server

	ld	ix,BUF_IPDNS1
	ld	a,(ix+4)
	or	(ix+5)
	or	(ix+6)
	or	(ix+7)
	scf
	ret	z	;It was primary but no secondary available.

	ld	hl,BUF_IPDNS2	;Set secondary server
	ld	de,DNS_IP	;and reset retransmission counter
	ld	bc,4
	ldir
	ld	a,2
	ld	(DNS_STAT_S),a
	xor	a	;This causes Cy=0
	ld	(DNS_RETRY),a
	inc	a
	ld	(DNS_TOUT),a	;This causes the query to be sent immediately
	ret


	if	LINK=1

	;==============================
	;===  DHCP packet received  ===
	;==============================

IS_DHCP:
	ld	a,(DHCP_VECT)	;Ignore it if not using DHCP
	or	a
	jp	z,END_GET_PACK

	ld	a,(DHCP_STATE)
	cp	CONFIGURED
	jp	z,END_GET_PACK

	;--- Obtain packet type

	ld	a,(IN_BUFFER+32)	;BOOTREPLY?
	cp	2
	jp	nz,END_GET_PACK

	ld	hl,IN_BUFFER+36	;'xid' matches?
	ld	de,DHCP_XID
	call	COMP32
	jp	nz,END_GET_PACK

	call	DHCP_GET_TYPE
	cp	DHCPOFFER
	jr	z,IS_DHCP_OFFER
	cp	DHCPACK
	jr	z,IS_DHCP_ACK
	cp	DHCPNAK
	jp	z,IS_DHCP_NAK
	jp	END_GET_PACK	;Other types are ignored


	;--- DHCPOFFER packet

IS_DHCP_OFFER:

	;* If not in SELECTING state, ignore it

	ld	a,(DHCP_STATE)
	cp	SELECTING
	jp	nz,END_GET_PACK

	;* Save server identifier

	call	DHCP_GET_SERVER
	jp	c,END_GET_PACK
	ld	de,DHCP_SERVER
	ld	bc,4
	ldir

	;* Save 'yiaddr' field as the offered IP address

	ld	hl,IN_BUFFER+48
	ld	de,DHCP_YIADDR
	ld	bc,4
	ldir

	;* Save received 'xid'

	ld	hl,IN_BUFFER+36
	ld	de,DHCP_RCVXID
	ld	bc,4
	ldir

	;* Enter REQUESTING state and send DHCPREQUEST

	ld	a,REQUESTING
	ld	(DHCP_STATE),a
	ld	a,DHCPREQUEST
	call	SEND_DHCP
	call	DHCP_FIRST
	jp	END_GET_PACK


	;--- ACK packet

IS_DHCP_ACK:

	;* If not in REBINDING, REQUESTING, RENEWING
	;  or INFORMING state, ignore it

ISDHCPACK2:
	cp	REQUESTING
	jr	z,ISDHCPACK3
	cp	RENEWING
	jr	z,ISDHCPACK3
	cp	REBINDING
	jr	z,ISDHCPACK3
	cp	INFORMING
	jp	nz,END_GET_PACK
ISDHCPACK3:

	;* If server identifier does not match the previous one, ignore message
	;  (Problem: What if ACK has been received in REBINDING state,
	;  by a server different from the one used previously?
	;  For this reason, we'll rely on XID only)

	;call	DHCP_GET_SERVER
	;jp	c,END_GET_PACK
	;ld	de,DHCP_SERVER
	;call	COMP32
	;jp	nz,END_GET_PACK

	;* Initialize fields Lease, T1 and T2

	ld	hl,DHCP_T1
	ld	de,DHCP_T1+1
	ld	bc,12-1
	ld	(hl),0
	ldir

	;* Save 'yiaddr' field as the assigned IP,
	;  unless we had sent DHCPINFORM

	ld	a,(DHCP_VECT)
	and	1
	jr	z,ISDHCPACK4

	ld	hl,IN_BUFFER+48
	ld	de,BUF_IPLOCAL
	ld	bc,4
	ldir
	ld	a,1
	ld	(DHCP_VECT_O),a
ISDHCPACK4:

	;* Traverse all options and precess them

	call	DHCP_INIT_OP

ISDHCPACKL:
	call	DHCP_NEXT_OP
	or	a
	jp	z,ISDHCPACKEND	;No more options?

	;* T1: Store it

	cp	58
	jr	nz,ISDHCPACK_NOT1

	push	ix
	pop	hl
	ld	de,DHCP_T1
	ld	bc,4
	ldir

	ld	ix,DHCP_T1
	call	POR60_32
	jr	ISDHCPACKL
ISDHCPACK_NOT1:

	;* T2: Store it

	cp	59
	jr	nz,ISDHCPACK_NOT2

	push	ix
	pop	hl
	ld	de,DHCP_T2
	ld	bc,4
	ldir

	ld	ix,DHCP_T2
	call	POR60_32
	jr	ISDHCPACKL
ISDHCPACK_NOT2:

	;* Lease: Store it

	cp	51
	jr	nz,ISDHCPACK_NOLS

	push	ix
	pop	hl
	ld	de,DHCP_LEASE
	ld	bc,4
	ldir

	ld	ix,DHCP_LEASE
	call	POR60_32
	jr	ISDHCPACKL
ISDHCPACK_NOLS:

	;* Subnet mask: store it if we had requested it

	cp	1
	jr	nz,ISDHCPACK_NOSB

	ld	a,(DHCP_VECT)
	and	%10	;Requested?
	jr	z,ISDHCPACKL

	push	ix
	pop	hl
	ld	de,SUBNET_MASK
	ld	bc,4
	ldir

	ld	a,(DHCP_VECT_O)
	or	%10
	ld	(DHCP_VECT_O),a
	jr	ISDHCPACKL
ISDHCPACK_NOSB:

	;* Default gateway: store it if we had requested it

	cp	3
	jr	nz,ISDHCPACK_NOGW

	ld	a,(DHCP_VECT)
	and	%100	;Requested?
	jr	z,ISDHCPACKL

	push	ix
	pop	hl
	ld	de,DEFGW
	ld	bc,4
	ldir

	ld	a,(DHCP_VECT_O)
	or	%100
	ld	(DHCP_VECT_O),a
	jp	ISDHCPACKL
ISDHCPACK_NOGW:

	;* DNS servers: store them if we had requested them

	cp	6
	jr	nz,ISDHCPACK_NODN

	ld	a,(DHCP_VECT)
	and	%1000	;Requested?
	jp	z,ISDHCPACKL

	ld	a,(DHCP_VECT_O)
	or	%1000
	ld	(DHCP_VECT_O),a

	push	bc
	push	ix
	pop	hl
	ld	de,BUF_IPDNS1
	ld	bc,4
	ldir

	pop	bc	;More than one DNS supplied?
	ld	a,b
	cp	8
	jp	c,ISDHCPACKL
	ld	de,BUF_IPDNS2
	ld	bc,4
	ldir
	jp	ISDHCPACKL
ISDHCPACK_NODN:

	;* ARP timeout: store it if we had requested it

	cp	35
	jr	nz,ISDHCPACK_NOAT

	ld	a,(DHCP_VECT)
	and	%10000	;Requested?
	jp	z,ISDHCPACKL

	push	ix,ix
	pop	hl
	ld	de,ARP_TOUT
	ld	bc,4
	ldir
	pop	hl
	ld	de,ARP_TOUT_SECS
	ld	bc,4
	ldir
	ld	ix,ARP_TOUT
	call	POR60_32

	ld	a,(DHCP_VECT_O)
	or	%10000
	ld	(DHCP_VECT_O),a
	jp	ISDHCPACKL
ISDHCPACK_NOAT:

	;* Ethernet frame type: store it if we had requested it

	cp	36
	jr	nz,ISDHCPACK_NOFT

	ld	a,(DHCP_VECT)
	and	%100000	;Requested?
	jp	z,ISDHCPACKL

	ld	a,(ix)
	or	a
	jr	z,ISDHCPACK_FT
	ld	a,#FF
ISDHCPACK_FT:
	ld	(FRAME_TYPE),a

	ld	a,(DHCP_VECT_O)
	or	%100000
	ld	(DHCP_VECT_O),a
	;jp      ISDHCPACKL
ISDHCPACK_NOFT:

	;* Unknown option: ignore it

	jp	ISDHCPACKL
ISDHCPACKEND:

	;* No more options.
	;  In INFORMING state, enter CONFIGURED state and terminate.

	ld	a,(DHCP_STATE)
	cp	INFORMING
	jr	nz,ISDHCPACKEND0

	ld	a,CONFIGURED
	ld	(DHCP_STATE),a
	jp	END_GET_PACK
ISDHCPACKEND0:

	;* If T1 is 0, set it to lease/2

	ld	hl,DHCP_T1
	ld	de,ZERO32
	call	COMP32
	jr	nz,OKT1NZ

	ld	hl,#FFFF	;If lease is infinite, T1 infine
	ld	(DHCP_T1),hl
	ld	(DHCP_T1+2),hl
	ld	a,(DHCP_LEASE)
	cp	h
	jr	z,OKT1NZ

	ld	hl,DHCP_LEASE
	ld	de,DHCP_T1
	ld	bc,4
	ldir
	ld	ix,DHCP_T1
	ld	b,1
	call	ENTRE2_32
OKT1NZ:

	;* If T2 is 0, set it to 0.875*lease ((7/8)*lease)

	ld	hl,DHCP_T2
	ld	de,ZERO32
	call	COMP32
	jr	nz,OKT2NZ

	ld	hl,#FFFF	;If lease is infinite, T2 infine
	ld	(DHCP_T2),hl
	ld	(DHCP_T2+2),hl
	ld	a,(DHCP_LEASE)
	cp	h
	jr	z,OKT2NZ

	ld	hl,DHCP_LEASE
	ld	de,DHCP_T2
	ld	bc,4
	ldir

	ld	ix,DHCP_T2	;Divide T2 by 8
	ld	b,3
	call	ENTRE2_32

	ld	hl,DHCP_T2
	ld	de,IN_BUFFER
	ld	bc,4
	ldir

	ld	b,6
T2ISZL:	push	bc	;Multiply (T2/8) by 7
	ld	hl,IN_BUFFER
	ld	de,DHCP_T2
	ld	bc,DHCP_T2
	call	ADD32
	pop	bc
	djnz	T2ISZL
OKT2NZ:

	;* End: enter BOUND and terminate

	ld	a,BOUND
	ld	(DHCP_STATE),a
	jp	END_GET_PACK


	;--- NAK packet

IS_DHCP_NAK:

	;* In BOUND, SELECTING, INFORMING or CONFIGURED states, ignore it

	ld	a,(DHCP_STATE)
	cp	BOUND
	jp	z,END_GET_PACK
	cp	SELECTING
	jp	z,END_GET_PACK
	cp	INFORMING
	jp	z,END_GET_PACK
	cp	CONFIGURED
	jp	z,END_GET_PACK

	;* In other states, return to INIT

	xor	a	;ld     a,INIT
	ld	(DHCP_STATE),a
	jp	END_GET_PACK

	endif


	;==============================
	;===  TCP segment received  ===
	;==============================

IS_TCP:
	if	LINK=0

	ld	a,#FF
	ld	(GOT_TCP),a

	endif

	;--- Check checksum, unless CHKVECT says no

	ld	a,(CHKVECT)
	and	%100
	jp	z,OK_TCP_CHKSUM

	;For ckecksum calculation we use the same trick as for UDP
	;(see IS_UDP)

	xor	a
	ld	(IN_BUFFER+12),a	;TTL field
	ld	ix,IN_BUFFER+14
	ld	hl,(IN_BUFFER+6)	;TCP length in the IP checksum field
	ld	(ix),h
	ld	(ix+1),l

	;ld      hl,(IN_BUFFER+6)
	ld	bc,12	;To include pseudo-header
	add	hl,bc
	push	hl
	pop	bc
	ld	ix,IN_BUFFER+12
	call	CALC_CHKSUM
	ld	a,d
	or	e
	jp	nz,END_GET_PACK
OK_TCP_CHKSUM:

	;--- If the segment contains TCP options, search MSS;
	;    then discard all others and move TCP data to IN_BUFFER+44.
	;    If no MSS option is present, assume 512.

	ld	de,536
	ld	(RECEIVED_MSS),de

	ld	a,(IN_BUFFER+36)
	and	#F0
	srl	a
	srl	a
	ld	l,a
	ld	h,0	;HL = TCP header size in bytes

	cp	20
	jr	z,TCPOPTOK	;No options present

	push	hl
	ld	a,(IN_BUFFER+37)	;Do not bother searching MSS option
	and	%10	;if the segment has no SYN
	jr	z,TCP_OP_END2

	;* Search MSS option

	ld	a,l
	sub	20
	ld	b,a	;B = Options size
	ld	ix,IN_BUFFER+44	;Options start

TCP_OP_LOOP:
	ld	a,(ix)
	or	a
	jr	z,TCP_OP_END	;"End of options" option
	inc	ix
	dec	b
	jr	z,TCP_OP_END	;No more options
	dec	a
	jr	z,TCP_OP_LOOP	;Option 1 ("Padding")
	dec	a
	jr	nz,TCP_OP_NEXT	;Option 2 (MSS)

	;MSS option found

	ld	h,(ix+1)
	ld	l,(ix+2)
	ld	a,h	;If MSS=0 is announced, assume 1
	or	l
	jr	nz,NO_MSS_0
	ld	hl,1
NO_MSS_0:
	ld	(RECEIVED_MSS),hl
	jr	TCP_OP_END	;Ignore all other options

	;Other option: ignore it

TCP_OP_NEXT:
	ld	a,(ix)	;Option length
	dec	a	;Do not count option code (already skipped)
TCP_NXT_LOOP:
	inc	ix
	dec	b
	dec	a
	jr	nz,TCP_NXT_LOOP

	;Next option, if any

TCP_OP_NEXT2:
	ld	a,b	;If less than 4 bytes remaining,
	cp	4	;there can't be MSS option
	jr	nc,TCP_OP_LOOP
TCP_OP_END:

	;* Move data to segment start

	pop	hl
	push	hl
TCP_OP_END2:
	ld	bc,IN_BUFFER+44
	add	hl,bc	;HL = Data area start
	ld	de,IN_BUFFER+44
	ld	bc,(IP_TOTAL_LEN)
	ldir		;Move data immediately after IP header
	pop	hl

TCPOPTOK:
	push	hl
	pop	bc	;Update data size (subtract TCP header)
	ld	hl,(IN_BUFFER+6)
	or	a
	sbc	hl,bc
	ld	(IN_BUFFER+6),hl

	if	LINK=0

	ld	a,(VJ_RCVED)	;If it was a VJ compressed packet,
	or	a	;save data size in its slot
	jr	z,TCPOPTOK2
	ld	ix,(VJ_ISLOT_DIR)
	ld	(ix),l
	ld	(ix+1),h
TCPOPTOK2:

	endif

	;--- Change window information to be little-endian

	ld	a,(IN_BUFFER+38)
	ld	h,a
	ld	a,(IN_BUFFER+39)
	ld	l,a
	ld	(IN_BUFFER+38),hl

	;--- Search associated connection

	call	SRCH_TCP_INBUF
	cp	#FF
	jr	nz,TCP_OKEX

	;If associated connection is not found, and the segment has SYN,
	;search a connection in LISTEN state with remote socket unespecified

	ld	a,(IN_BUFFER+37)	;Has SYN?
	and	%10
	jr	z,TCP_NOEX

	call	SEARCH_LISTEN	;Appropriate connection exists?
	cp	#FF
	jr	z,TCP_NOEX

	call	LOAD_TCB

	ld	hl,IN_BUFFER+16	;Set remote IP as the datagram source IP
	ld	de,REMOTE_IP
	ld	bc,4
	ldir

	ld	hl,(IN_BUFFER+24)	;Set ports as the packet ports
	ld	de,(IN_BUFFER+26)
	ld	ix,TCB_TEMP
	ld	(ix+5),h
	ld	(ix+6),l
	ld	(ix+7),d
	ld	(ix+8),e

	jr	TCP_OKEX2

	;Associated connection not found and segment has no SYN:
	;sent RST and terminate

TCP_NOEX:
	ld	a,(IN_BUFFER+37)
	bit	2,a
	jp	nz,END_GET_PACK	;If it has RST, terminate

	and	%10000	;RST type to be sent depends on whether
	ld	a,1	;the segment has ACK or not
	jp	z,TCP_SNDRST
	inc	a
TCP_SNDRST:
	call	SEND_RST
	jp	END_GET_PACK

TCP_OKEX:
	call	LOAD_TCB
TCP_OKEX2:	;

	;>>> Processing in LISTEN state <<<

	ld	a,(TCP_STATE)
	cp	LISTEN
	jp	nz,TCP_NO_LISTEN

	;--- If it has RST, ignore it

	ld	a,(IN_BUFFER+37)
	bit	2,a
	jp	nz,END_GET_PACK

	;--- If it has ACK, send RST

	bit	4,a
	jr	z,TCP_LST_NOACK
	ld	a,2
	call	SEND_RST
	jp	END_GET_PACK
TCP_LST_NOACK:

	;--- If it has NO SYN, ignore it;
	;    otherwise process it

	bit	1,a
	jp	z,END_GET_PACK

	ld	hl,(RECEIVED_MSS)
	ld	(MSS),hl

	ld	hl,IN_BUFFER+28	;Do RCV_NXT = SEG_SEQ+1
	ld	bc,RCV_NXT
	call	INC32

	ld	hl,IN_BUFFER+28	;Do IRS = SEG_SEQ
	ld	de,IRS
	ld	bc,4
	ldir

	;> Here we should set ISS, but it is 0 already
	;ld     hl,ZERO32
	;ld     de,ISS
	;ld     bc,4
	;ldir

	ld	hl,ISS	;Do SND_NXT = ISS+1
	ld	bc,SND_NXT
	call	INC32

	ld	hl,ISS	;Do SND_UNA = ISS
	ld	de,SND_UNA
	ld	bc,4
	ldir

	ld	hl,ISS	;Prepare segment to be sent: sequence number
	ld	de,OUT_BUFFER+28
	ld	bc,4
	ldir

	ld	hl,RCV_NXT	;Prepare ACK
	ld	de,OUT_BUFFER+32
	ld	bc,4
	ldir

	ld	a,%10010
	ld	(OUT_BUFFER+37),a	;ACK + SYN

	call	SET_TCP_PORTS	;Send segment
	ld	bc,0
	call	SEND_SEGMENT

	ld	a,SYN.RECEIVED	;Update the rest of TCB and terminate
	ld	(TCP_STATE),a
	ld	hl,(USER_TOUT_V)
	ld	(USER_TOUT),hl
	ld	a,#FF
	ld	(SYN_SENT_FLAG),a
	ld	hl,RTO_V*60
	ld	(RTO_T),hl

	jp	END_GET_TCP

TCP_NO_LISTEN:

	;>>> Processing in SYN-SENT state <<<

	;ld      a,(TCP_STATE)
	cp	SYN.SENT
	jp	nz,TCP_NO_SYNS

	;--- Check ACK:
	;    if SEG_ACK<=ISS or SEG_ACK>SND_NXT, send RST
	;    (OK if ISS<SEG_ACK<=SND_NXT)

	ld	a,(IN_BUFFER+37)
	and	%10000
	ld	b,0
	jr	z,TCP_SYNS_OKACK

	ld	de,IN_BUFFER+32	;Error if SEG_ACK<=ISS
	ld	hl,ISS
	call	COMP_SEQ
	jr	c,TCP_SYNS_BADACK

	ld	hl,SND_NXT	;OK if SND_NXT>=SEG_ACK
	ld	de,IN_BUFFER+32
	call	COMP_SEQ
	ld	b,1
	jr	c,TCP_SYNS_OKACK

	;Invalid ACK:
	;send reset unless segment has already one

TCP_SYNS_BADACK:
	ld	a,(IN_BUFFER+37)
	and	%100
	ld	a,2
	call	z,SEND_RST
	jp	END_GET_PACK
TCP_SYNS_OKACK:

	;--- Check RST: if present, discard segment
	;    if it had no ACK (B=0);
	;    otherwise (B=1) close connection.

	ld	a,(IN_BUFFER+37)
	bit	2,a
	jr	z,TCP_SYNS_OKRST

	bit	0,b
	jp	z,END_GET_PACK
	xor	a
	ld	(TCP_STATE),a
	ld	a,3
	ld	(LAST_CLOSE),a
	jp	END_GET_TCP
TCP_SYNS_OKRST:

	;--- Check SYN

	and	%10	;Discard segment if it has no SYN
	jp	z,END_GET_PACK

	ld	hl,(RECEIVED_MSS)
	ld	(MSS),hl

	ld	hl,IN_BUFFER+28	;Do RCV_NXT=SEG_SEQ+1
	ld	bc,RCV_NXT
	call	INC32

	ld	hl,IN_BUFFER+28	;Do IRS=SEG_SEQ
	ld	de,IRS
	ld	bc,4
	ldir

	ld	a,(IN_BUFFER+37)	;Do SND_UNA=SEG_ACK if ACK present
	and	%10000
	jr	z,TCP_SYNS_OKACK2
	ld	hl,IN_BUFFER+32
	ld	de,SND_UNA
	ld	bc,4
	ldir
TCP_SYNS_OKACK2:

	ld	de,SND_UNA	;Compare SND_UNA and ISS
	ld	hl,ISS
	call	COMP_SEQ
	jr	c,TCP_SYNS_2

	;Processing if SND_UNA>ISS

	ld	a,ESTABLISHED
	ld	(TCP_STATE),a
	xor	a
	ld	(SYN_SENT_FLAG),a
	call	SET_WNDWL

	call	SEND_ACK
	jp	END_GET_TCP

	;Processing if SND_UNA<=ISS

TCP_SYNS_2:
	ld	a,SYN.RECEIVED
	ld	(TCP_STATE),a
	ld	a,#12
	call	SEND_SYN
	jp	END_GET_TCP
TCP_NO_SYNS:

	;>>> Check sequence number <<<

	call	CHECK_SEQ
	jp	nc,END_GET_TCP	;???

	;>>> Check RST flag <<<

	ld	a,(IN_BUFFER+37)
	bit	2,a
	jr	z,TCP_NO_RST

	;--- SYN-RECEIVED state and connection was passive:
	;    return to LISTEN state

	call	RET_LISTEN
	jp	c,END_GET_TCP

	;--- Other states or active connection:
	;    close connection

SET_CLOSED:
	xor	a
	ld	(TCP_STATE),a
	ld	a,3
	ld	(LAST_CLOSE),a
	jp	END_GET_TCP
TCP_NO_RST:

	;>>> Check SYN flag <<<

	;ld      a,(IN_BUFFER+37)
	bit	1,a
	jr	z,TCP_NO_SYN

	;--- SYN-RECEIVED state and connection is passive:
	;    send RST and return to LISTEN state,
	;    Other states or active connection:
	;    close connection

	call	RET_LISTEN
	jp	c,END_GET_TCP
	xor	a
	call	SEND_RST
	jp	SET_CLOSED
TCP_NO_SYN:

	;>>> Check ACK flag <<<

	;--- If no ACK present, ignore segment

	;ld      a,(IN_BUFFER+37)
	and	%10000
	jp	z,END_GET_PACK

	;--- SYN-RECEIVED state:
	;    If SND.UNA =< SEG.ACK =< SND.NXT, enter ESTABLISHED state
	;    and call SET_WNDWL. Otherwise, send ACK.

	ld	a,(TCP_STATE)
	cp	SYN.RECEIVED
	jr	nz,TCP_NO_SYNR

	ld	hl,SND_UNA
	ld	bc,IN_BUFFER+32
	ld	de,SND_NXT
	call	RANGE32
	jr	c,OK_ACK_RANGE

	call	SEND_ACK	;Not acceptable ACK
	jp	END_GET_TCP

OK_ACK_RANGE:
	ld	a,ESTABLISHED	;Acceptable ACK
	ld	(TCP_STATE),a
	xor	a
	ld	(SYN_SENT_FLAG),a
	call	SET_WNDWL
	ld	hl,IN_BUFFER+32
	ld	de,SND_UNA
	ld	bc,4
	ldir
	jp	END_GET_TCP
TCP_NO_SYNR:

	;--- Process all other states

	call	PROCESS_ACK
	jp	nc,END_GET_TCP

	;--- FIN_WAIT_1: If FIN is ACKed, enter FIN-WAIT-2 state

	ld	a,(TCP_STATE)
	cp	FIN.WAIT.1
	jr	nz,TCP_NO_FW1

	ld	a,(FIN_SENT_FLAG)
	or	a
	jr	nz,TCP_NO_FW1

	ld	a,FIN.WAIT.2
	ld	(TCP_STATE),a
	jr	TCP_NO_CLLA
TCP_NO_FW1:

	;--- CLOSING (8) and LAST-ACK (9): If FIN is ACKed,
	;    close connection.
	;NOTE: We should go from CLOSING to TIME-WAIT,
	;      but we haven't implemented this state.

	or	1
	cp	9
	jr	nz,TCP_NO_CLLA

	ld	a,(FIN_SENT_FLAG)
	or	a
	jp	nz,END_GET_TCP

TCP_TO_CLOSED:
	xor	a
	ld	(TCP_STATE),a
	ld	a,1
	ld	(LAST_CLOSE),a
	jp	END_GET_TCP
TCP_NO_CLLA:

	;>>> Processing of segment data <<<

	;--- If not in ESTABLISHED (4), FIN_WAIT_1 (5) or FIN_WAIT_2 (6),
	;    ignore segment data

	ld	a,(TCP_STATE)
	cp	ESTABLISHED
	jp	c,TCP_OK_TXT
	cp	FIN.WAIT.2+1
	jp	nc,TCP_OK_TXT

	;--- Queue data and update RCV_NXT

TCP_INSAGAIN:
	ld	bc,(IN_BUFFER+6)
	ld	a,b
	or	c
	jr	z,TCP_OK_TXT
	ld	ix,INBUF
	ld	hl,IN_BUFFER+44
	push	bc
	call	RBUF_INSERT
	pop	de
	jr	nc,TCP_INSERT_OK

	ld	bc,(INBUF_FREE)	;In case there is too much data
	ld	(IN_BUFFER+6),bc
	jr	TCP_INSAGAIN

TCP_INSERT_OK:
	ld	hl,RCV_NXT
	ld	bc,RCV_NXT
	call	ADD3216

	;--- Update variables to send delayed ACK

	ld	hl,(ACK_RCV_NUM)
	ld	a,h
	or	l
	jr	nz,OK_ACK_TIM
	ld	a,ACK_DELAY_V
	ld	(ACK_DELAY_T),a
OK_ACK_TIM:

	ld	bc,(IN_BUFFER+6)
	add	hl,bc
	ld	(ACK_RCV_NUM),hl
TCP_OK_TXT:

	;>>> Processing of FIN bit <<<

	ld	a,(IN_BUFFER+37)
	and	1
	jr	z,TCP_NO_FIN

	;--- In LISTEN or SYN-SENT, ignore segment

	ld	a,(TCP_STATE)
	cp	LISTEN
	jp	z,END_GET_TCP
	cp	SYN.SENT
	jp	z,END_GET_TCP

	;--- Update RCV_NXT and schedule ACK

	ld	hl,RCV_NXT
	ld	bc,RCV_NXT
	call	INC32
	call	SCHEDULE_ACK

	;--- SYN-RECEIVED and ESTABLISHED: enter CLOSE_WAIT state

	ld	a,(TCP_STATE)
	cp	ESTABLISHED
	jr	z,TCP_TO_CW
	cp	SYN.RECEIVED
	jr	nz,TCP_NO_CW

TCP_TO_CW:	ld	a,CLOSE.WAIT
	ld	(TCP_STATE),a
	jp	END_GET_TCP
TCP_NO_CW:

	;--- FIN-WAIT-1 state: If FIN is ACKed, close connection;
	;    otherwise enter CLOSING state

	cp	FIN.WAIT.1
	jr	nz,TCP_NO_FW1_2

	ld	a,(FIN_SENT_FLAG)
	or	a
	jp	z,TCP_TO_CLOSED
	ld	a,CLOSING
	ld	(TCP_STATE),a
	jp	END_GET_TCP
TCP_NO_FW1_2:

	;--- FIN-WAIT-2 state: Close connection

	cp	FIN.WAIT.2
	jp	z,TCP_TO_CLOSED
TCP_NO_FIN:

	;>>> End <<<

END_GET_TCP:
	call	SAVE_TCB
	jp	END_GET_PACK


	;======================================
	;===  Processing of TCP connection  ===
	;======================================

	;This code performs the appropriate actions
	;when timers expire, or when enough data has been
	;accumulated to be sent or ACKed.
	;
	;Only one connection is processed per timer interrupr
	;(all connections are processed alternately)

DO_TCP_PROCESS:

	;--- Obtain number of the last processed connection,
	;    increase it (wrapping from 3 to 0), and check
	;    that the corresponding connection is not closed.
	;    In this case process it, otherwise try with the next one.
	;    If no connections are open at all, terminate.

	ld	b,4	;Maximum number of connections to check
	ld	a,(LAST_PROC_TCB)
LOOP_TCBS:
	inc	a
	and	%11	;To loop from 3 to 0
	ld	c,a
	call	GET_TCB_DIR
	ld	a,(hl)
	or	a	;Closed?
	ld	a,c
	jr	nz,PROCESS_TCB	;No: process connection
	djnz	LOOP_TCBS	;Yes: Try with next connection, if any
	ret		;No connections open after all

PROCESS_TCB:
	ld	(LAST_PROC_TCB),a
	call	LOAD_TCB

	;>>> The followed algorythm is:
	;    - If there is old data to be retransmitted:
	;       * If user timeout expired, close connection. End.
	;       * If retransmission timeout is 0, retransmit data. End.
	;       * Jump to delayed ACK checking.
	;    - If there is new data to be sent:
	;       * If it is NOT true that: there is PUSH data,
	;         OR there are at least MSS bytes to be sent,
	;         OR non-push data send timeout has expired, end.
	;       * If transmission window is NOT zero, send new data.
	;         End.
	;       * If zero window probe timeout expired, send a probe.
	;       * End.
	;    - If there is a pending FIN, send it and enter
	;      LAST-ACK if necessary. End.
	;    - If delayed ACK is pending:
	;      * If delayed ACK send timeout has expired, or there are
	;        at least 512 bytes pending to be ACKed, send ACK.
	;      * End.

	;--- Process if there is old data pending retransmission

	;* If user timeout expired, close connection

	ld	a,(SYN_SENT_FLAG)	;Data to be ReTx available?
	or	a
	jr	nz,DO_RETX_PEND
	ld	a,(FIN_SENT_FLAG)
	or	a
	jr	nz,DO_RETX_PEND
	ld	hl,(RETX_SIZE)
	ld	a,h
	or	l
	jp	z,NO_RETX_PEND
DO_RETX_PEND:

	ld	hl,(USER_TOUT_V)	;If initial timeout value is
	inc	hl	;#FFFF, it is "infinite": do not check
	ld	a,h
	or	l
	jr	z,NO_UTOUT_EXP

	ld	hl,(USER_TOUT)
	ld	a,h
	or	l
	jr	nz,NO_UTOUT_EXP

	xor	a
	call	SEND_RST
	ld	a,(TCP_STATE)
	or	1
	cp	3
	ld	a,4
	jr	nz,TOUT_EXP_2
	inc	a
TOUT_EXP_2:
	ld	(LAST_CLOSE),a	;Error 5 if state SYN_xxx, otherwise, error 4
	xor	a
	ld	(TCP_STATE),a
	jp	END_PROC_TCP
NO_UTOUT_EXP:

	;* If retransmission timeout expired, retransmit data;
	;  otherwise, jump to delayed ACK processing

	ld	hl,(RTO_T)
	ld	a,h
	or	l
	jp	nz,END_RETX_PEND

	ld	hl,RTO_V*60	;Also reset timer
	ld	(RTO_T),hl

	;* Resend SYN

	ld	a,(SYN_SENT_FLAG)
	or	a
	jr	z,NO_RETX_SYN

	ld	a,(TCP_STATE)	;With ACK if state is SYN-RECEIVED
	cp	SYN.SENT
	ld	a,2
	jr	z,RETX_SYN
	ld	a,#12
RETX_SYN:
	call	SEND_SYN
	jp	END_PROC_TCP
NO_RETX_SYN:

	;* Resend FIN

	ld	a,(FIN_SENT_FLAG)
	or	a
	jr	z,NO_RETX_FIN

	ld	a,1
	ld	bc,0
	call	SEND_DATA
	jp	END_PROC_TCP
NO_RETX_FIN:

	;* Resend data

	ld	ix,OUTBUF
	ld	de,OUT_BUFFER+44
	ld	bc,(RETX_SIZE)
	call	RBUF_PEEK

	ld	hl,(SEND_PUSH_PEND)
	ld	a,h
	or	l
	jr	z,NO_PUSH_1
	ld	a,8
NO_PUSH_1:
	call	SEND_DATA
	jp	END_PROC_TCP

NO_RETX_PEND:

	;--- No data to be retransmitted:
	;    Check if new data can be sent, this is true if:
	;    - There is PUSH data, or
	;    - There are at least MSS pending bytes, or
	;    - Non-push data send timeout expired

	ld	hl,(OUTBUF_USED)	;New data available?
	ld	a,h
	or	l
	jp	z,NO_NEW_PEND

	ld	de,(SEND_PUSH_PEND)	;Push data?
	ld	a,d
	or	e
	jr	nz,DO_SEND_NEW

	ld	de,(MSS)	;At least MSS bytes?
	call	COMP
	jr	c,DO_SEND_NEW

	ld	hl,(SEND_TOUT)	;Send timeout expired?
	ld	a,h
	or	l
	jp	nz,NO_SEND_NEW

	;* If transmission window is 0, and zero window probe timer
	;  expired, send ACK with sequence number SND_NXT-1,
	;  and reset timer to its initial value

DO_SEND_NEW:
	ld	hl,(SND_WND)
	ld	a,h
	or	l
	jr	nz,DO_SEND_NEW2

	ld	hl,(RTO_T)
	ld	a,h
	or	l
	jp	nz,NO_SEND_NEW

	ld	hl,SND_UNA
	ld	bc,SND_UNA
	call	DEC32
	call	SEND_ACK
	ld	hl,SND_UNA
	ld	bc,SND_UNA
	call	INC32
	ld	hl,SND_UNA
	ld	de,SND_NXT
	ld	bc,4
	ldir
	ld	hl,ZWP_V*60	;Reset timer
	ld	(RTO_T),hl
	jr	NO_SEND_NEW

	;* Extract data and send it

DO_SEND_NEW2:
	ld	hl,(SND_WND)	;The maximum amount of data to be sent is
	ld	de,(MSS)	;the minimum of transmission window, MSS and 448...
	call	COMP
	jr	nc,OK_SND_SIZE
	ex	de,hl
OK_SND_SIZE:
	ld	de,448
	call	COMP
	jr	nc,OK_SND_SIZE2
	ex	de,hl
OK_SND_SIZE2:
	push	hl
	pop	bc

	ld	ix,OUTBUF
	ld	de,OUT_BUFFER+44
	call	RBUF_PEEK	;...if not that much data is available,
	ld	(RETX_SIZE),bc	;extract as many as possible.
	ld	hl,(SEND_PUSH_PEND)
	ld	a,h
	or	l
	jr	z,NO_PUSH_2
	ld	a,8
NO_PUSH_2:
	call	SEND_DATA

	ld	hl,RTO_V*60	;Initialize retransmission timer
	ld	(RTO_T),hl
	ld	hl,(USER_TOUT_V)	;Initialize user timer
	ld	(USER_TOUT),hl
	jr	END_PROC_TCP
NO_NEW_PEND:

	;--- If sending FIN is pending and all data has been sent already,
	;    send FIN and change state to LAST-ACK if we were in CLOSE-WAIT state

	ld	a,(FIN_PENDING)
	or	a
	jr	z,NO_FIN_PEND

	ld	a,(TCP_STATE)
	cp	CLOSE.WAIT
	jr	nz,NO_TO_LACK
	ld	a,LAST.ACK
	ld	(TCP_STATE),a
NO_TO_LACK:

	xor	a
	ld	(FIN_PENDING),a
	ld	a,1
	ld	bc,0
	call	SEND_DATA
	ld	a,#FF
	ld	(FIN_SENT_FLAG),a

	ld	hl,RTO_V*60	;Initialize retransmission timer
	ld	(RTO_T),hl
	ld	hl,(USER_TOUT_V)	;Initialize user timer
	ld	(USER_TOUT),hl
	jr	END_PROC_TCP
NO_FIN_PEND:
END_RETX_PEND:
NO_SEND_NEW:

	;--- If nothing was sent at this point, check
	;    if an ACK must be sent. This is true if:
	;    - 512 bytes are pending an ACK, or
	;    - At least 1 byte is pending ACK and the delayed ACK timeout expired

	ld	a,(ACK_PENDING)	;Is there a pending ACK not for data reception?
	or	a
	jr	nz,DO_ACK_PEND

	ld	hl,(ACK_RCV_NUM)	;Is there any data pending to be ACKed?
	ld	a,h
	or	l
	jr	z,NO_ACK_PEND

	ld	a,h	;At least 512 bytes?
	cp	2
	jr	nc,DO_ACK_PEND

	ld	a,(ACK_DELAY_T)	;Delayed ACK timeout expired?
	or	a
	jr	nz,NO_ACK_PEND

DO_ACK_PEND:
	call	SEND_ACK
	;jr      END_PROC_TCP
NO_ACK_PEND:

	;--- End, save the updated TCB

END_PROC_TCP:	jp	SAVE_TCB


;*********************
;***               ***
;***  SUBROUTINES  ***
;***               ***
;*********************


;--- IS_CONNECTED:
;    Returns Z=1 if there is network connection available

IS_CONNECTED:

		if LINK=0

	ld	a,(PPP_STATE)
	cp	4
	ret

	endif

	if	LINK=1

	ld	a,(NET_STATE)
	inc	a
	ret

	endif


	;=====================================
	;===  Slots and memory management  ===
	;=====================================

;--- GETSLOT2: Returns in A the slot switched on page 2

_GETSLOT2:
	di
	exx
	in	a,(#A8)
	ld	e,a
	and	%00110000
	sra	a
	sra	a
	sra	a
	sra	a
	ld	c,a	;C = Slot
	ld	b,0
	ld	hl,EXPTBL
	add	hl,bc
	bit	7,(hl)
	jr	z,NOEXP2
EXP2:	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	and	%00110000
	sra	a
	sra	a
	or	c
	or	#80
	ld	c,a
NOEXP2:	ld	a,c
	exx
	ret


;--- PUTLOT2: Switches slot A in page 2 only if A<>B

_PUTSLOT2:
	cp	b
	ret	z
	ld	h,#80
	call	ENASLT
	ei
	ret


;--- SETUP_P2 and RESTORE_P2: Switch variables segment on page 2
;    and restore the original segment, respectively

SETUP_P2:
	push	af
	call	GET_P2
	push	af
	ld	a,(INL_SEG2)
	call	PUT_P2
	pop	af
	ld	(R_SEGP2),a
	pop	af
	ret

RESTORE_P2:
	push	af
	ld	a,(R_SEGP2)
	call	PUT_P2
	pop	af
	ret


;--- TPA2SEG: Conviert the TPA passed in HL
;    to a segment number returned in A,
;    and to a page 1 address returned in HL

TPA2SEG:
	ld	a,h
	rlca
	rlca
	cpl
	and	3

	res	7,h
	set	6,h
	ret


;--- LDIR_ST: Copy a block of data from TPA to data segment
;    Input: HL = Source
;           DE = Destination (page 2 address)
;           BC = Length

LDIR_ST:
	call	TPA2SEG
	push	hl
	pop	ix	;IX = Source address in page 1

	set	7,d
	res	6,d
LDIR_XX:
	push	de
	pop	iy	;IY = Destination address in page 2

	ld	hl,(#F344)
	ld	h,a	;H = TPA segment, L = Slot
	jp	LDIRP3


;--- LDIR_TS: Copy a block of data from data segment to TPA
;    Input: HL = Source (page 2 address)
;           DE = Destination
;           BC = Length

LDIR_TS:
	ex	de,hl
	call	TPA2SEG
	ex	de,hl
	set	7,h
	res	6,h
	push	hl
	pop	ix	;IX = Source address in page 2

	res	7,d	;IY = Destination address in page 1
	set	6,d
	jr	LDIR_XX


	;========================================
	;===  String and arithmetic routines  ===
	;========================================

;--- NAME: COMP
;      Compare HL with DE (16 bits in twos complement)
;    INPUT:   HL, DE = numbers to compare
;    OUTPUT:   C, NZ if HL > DE
;              C,  Z if HL = DE
;             NC, NZ if HL < DE
;    MODIFIES: -

COMP:	call	_COMP16
	ccf
	ret

_COMP16:
	ld	a,h
	sub	d
	ret	nz
	ld	a,l
	sub	e
	ret

	if	LINK=0

;--- CALC_FCS: Calculate a 16 bit FCS
;    Input:   HL = Address
;             DE = Previous FCS
;             BC = Length
;    Output:  DE = New FCS (without complement)
;    Modifies: AF, IX

;Implements the following C code:
;           while   (len--)
;               fcs = (fcs >> 8) ^ fcstab[(fcs ^ *cp++) & #ff] ;
;           return  (fcs)

CALC_FCS:
	push	bc	;BC = "len"

	ld	a,(hl)	;A = "*cp"
	inc	hl	;"cp ++"

	xor	e	;A = "fcs ^ *cp"

	ld	c,a
	ld	b,0
	ld	ix,FCSTAB
	add	ix,bc
	add	ix,bc
	ld	c,(ix)
	ld	b,(ix+1)	;BC = "fcstab[(fcs ^ *cp)]"

	ld	e,d
	ld	d,0	;DE = "(fcs >> 8)"

	ld	a,e
	xor	c
	ld	e,a
	ld	d,b	;DE = "(fcs>>8) ^ fcstab[(fcs ^ *cp)]"

	pop	bc
	dec	bc	;"len--"
	ld	a,b
	or	c
	jr	nz,CALC_FCS	;"} while(len)"

	ret

FCSTAB:
	dw	#0000,#1189,#2312,#329b,#4624,#57ad,#6536,#74bf
	dw	#8c48,#9dc1,#af5a,#bed3,#ca6c,#dbe5,#e97e,#f8f7
	dw	#1081,#0108,#3393,#221a,#56a5,#472c,#75b7,#643e
	dw	#9cc9,#8d40,#bfdb,#ae52,#daed,#cb64,#f9ff,#e876
	dw	#2102,#308b,#0210,#1399,#6726,#76af,#4434,#55bd
	dw	#ad4a,#bcc3,#8e58,#9fd1,#eb6e,#fae7,#c87c,#d9f5
	dw	#3183,#200a,#1291,#0318,#77a7,#662e,#54b5,#453c
	dw	#bdcb,#ac42,#9ed9,#8f50,#fbef,#ea66,#d8fd,#c974
	dw	#4204,#538d,#6116,#709f,#0420,#15a9,#2732,#36bb
	dw	#ce4c,#dfc5,#ed5e,#fcd7,#8868,#99e1,#ab7a,#baf3
	dw	#5285,#430c,#7197,#601e,#14a1,#0528,#37b3,#263a
	dw	#decd,#cf44,#fddf,#ec56,#98e9,#8960,#bbfb,#aa72
	dw	#6306,#728f,#4014,#519d,#2522,#34ab,#0630,#17b9
	dw	#ef4e,#fec7,#cc5c,#ddd5,#a96a,#b8e3,#8a78,#9bf1
	dw	#7387,#620e,#5095,#411c,#35a3,#242a,#16b1,#0738
	dw	#ffcf,#ee46,#dcdd,#cd54,#b9eb,#a862,#9af9,#8b70
	dw	#8408,#9581,#a71a,#b693,#c22c,#d3a5,#e13e,#f0b7
	dw	#0840,#19c9,#2b52,#3adb,#4e64,#5fed,#6d76,#7cff
	dw	#9489,#8500,#b79b,#a612,#d2ad,#c324,#f1bf,#e036
	dw	#18c1,#0948,#3bd3,#2a5a,#5ee5,#4f6c,#7df7,#6c7e
	dw	#a50a,#b483,#8618,#9791,#e32e,#f2a7,#c03c,#d1b5
	dw	#2942,#38cb,#0a50,#1bd9,#6f66,#7eef,#4c74,#5dfd
	dw	#b58b,#a402,#9699,#8710,#f3af,#e226,#d0bd,#c134
	dw	#39c3,#284a,#1ad1,#0b58,#7fe7,#6e6e,#5cf5,#4d7c
	dw	#c60c,#d785,#e51e,#f497,#8028,#91a1,#a33a,#b2b3
	dw	#4a44,#5bcd,#6956,#78df,#0c60,#1de9,#2f72,#3efb
	dw	#d68d,#c704,#f59f,#e416,#90a9,#8120,#b3bb,#a232
	dw	#5ac5,#4b4c,#79d7,#685e,#1ce1,#0d68,#3ff3,#2e7a
	dw	#e70e,#f687,#c41c,#d595,#a12a,#b0a3,#8238,#93b1
	dw	#6b46,#7acf,#4854,#59dd,#2d62,#3ceb,#0e70,#1ff9
	dw	#f78f,#e606,#d49d,#c514,#b1ab,#a022,#92b9,#8330
	dw	#7bc7,#6a4e,#58d5,#495c,#3de3,#2c6a,#1ef1,#0f78

	endif

;--- Checksum

;Input: IX = Address, BC = Length en bytes
;Accepts odd length, no need for padding zero
;
; On entry:
;             IX -> block to checksum
;             BC = number of halfwords to checksum
;
; On exit:
;             DE = checksum
;             Z set if DE = 0 (i.e. checksum good)
;             A, BC and other flags corrupt

CALC_CHKSUM:
	ld	de,0

CALC_CHKSUMP:
	bit	0,c
	ld	a,0
	jr	z,CALC_CHKSUMP2
	dec	bc	;If BC is odd, substrac 1
	ld	a,#FF

CALC_CHKSUMP2:
	sra	b	;Convert BC to 16 bit words
	rr	c
	ld	(CHK_EVEN),a

	push	hl
	ex	de,hl
	push	ix
	or	a
	push	af
	jr	CHK_CHZERO	;Prevents BC being 1 and now 0

CALC_CHKLOOP:
	pop	af	; 3N
	ld	e,(ix + 0)	; 5N
	ld	d,(ix + 1)	; 5N
	adc	hl,de	; 4N
	push	af	; 3N
	inc	ix	; 3N
	inc	ix	; 3N
	dec	bc	; 2N
CHK_CHZERO:
	ld	a,b	; 1N
	or	c	; 1N
	jr	nz,CALC_CHKLOOP	; 3/2N -> 33N per halfword

	ld	a,(CHK_EVEN)
	or	a
	jr	z,CHK_NOEVEN

	pop	af	;If odd length, treat last byte
	ld	e,(ix)	;in a special way
	ld	d,0
	adc	hl,de
	push	af

CHK_NOEVEN:
	pop	af
	ld	de,1
	adc	hl,de
	ex	de,hl

	pop	ix
	pop	hl

	dec	de
	ld	a,d
	cpl
	ld	d,a
	ld	a,e
	cpl
	ld	e,a
	ret

CHK_EVEN:
	db	0

	if	LINK=0

;--- STRLEN: Returns in BC the length of the
;    zero-terminated string pointed by HL

STRLEN:	ld	bc,0
STRLEN2:
	ld	a,(hl)
	or	a
	ret	z
	inc	hl
	inc	bc
	jr	STRLEN2

	endif


;--- MD5 Message-Digest algorithm for Z80 processor
;    Conforming to RFC1321
;    By Nestor Soriano (Konami Man), 27-5-2001
;    http://www.konamiman.com
;    <konamiman@konamiman.com>

	;Input:  HL = Address of message to digest
	;        BC = Length of message in bytes (maximum 8191)
	;Output: HL = Address where calculated digest is stored

	;NOTE: A 72 byte buffer for padding must be placed
	;      IMMEDIATELY AFTER the message (that is, at address HL+BC)
	;For example:
	;      ld hl,MSG
	;      ld bc,18
	;      call MD5
	;      ret
	;MSG:  defb "This is a message!"
	;      defs 72

	;Only messages using complete bytes are supported
	;(that is, the number of bits must be multiple of 8)

	;This source code is for the MSX assembler COMPASS,
	;other assemblers may differ in the macros syntax

	;Some values for testing (taken from RFC1321):

	;MD5 ("") = d41d8cd98f00b204e9800998ecf8427e
	;MD5 ("a") = 0cc175b9c0f1b6a831c399e269772661
	;MD5 ("abc") = 900150983cd24fb0d6963f7d28e17f72
	;MD5 ("message digest") = f96b697d7cb7938d525a2f31aaf161d0
	;MD5 ("abcdefghijklmnopqrstuvwxyz") = c3fcd3d76192e4007dfb496cca67e13b
	;MD5 ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789") =
	;d174ab98d277d9f5a5611c2c9f419d9f
	;MD5 ("123456789012345678901234567890123456789012345678901234567890123456
	;78901234567890") = 57edf4a22be3c955ac49da2e2107b67a


	;--- Macro for 32 bit addition

m_add32:	macro	@a,@b	;Performs (@a) = (@a) + (@b)
	ld	hl,(@a)
	ld	bc,(@b)
	add	hl,bc
	ld	(@a),hl
	ld	hl,(@a+2)
	ld	bc,(@b+2)
	adc	hl,bc
	ld	(@a+2),hl
	endm


	;----------------------
	;---  MAIN PROGRAM  ---
	;----------------------

MD5:	ld	(MSG_PNT),hl
	ld	(MSG_LEN),bc

	;--- Step 1: append padding bits

	add	hl,bc
	ld	(hl),80h	;First adds the mandatory padding "1" bit
	inc	bc
	inc	hl

	ld	a,c
	and	3Fh
	cp	56
	jr	z,OKPAD1	;No more padding necessary if already
	sub	56	;congruent to 56 bytes, modulo 64
	neg
	and	3Fh	;Now A=Number of 0 bytes to add

	ld	b,a	;Adds padding "0" bits
PADLOOP:
	ld	(hl),0
	inc	hl
	djnz	PADLOOP
OKPAD1:	;

	;--- Step 2: append length

	push	hl
	ld	hl,(MSG_LEN)
	ld	bc,(MSG_LEN)
	add	hl,bc
	add	hl,hl
	add	hl,hl
	push	hl
	pop	bc	;Now BC = Length of message in bits
	pop	hl
	ld	(hl),c
	inc	hl
	ld	(hl),b	;Appends length to the end of the message
	inc	hl

	ld	b,6	;Since length is 2 bytes long and
PADLOP2:
	ld	(hl),0	;8 bytes are required, adds another
	inc	hl	;6 zero bytes
	djnz	PADLOP2

	ld	bc,(MSG_PNT)	;Calculates total message length
	or	a	;in bytes, which is multiple of 64
	sbc	hl,bc

	ld	b,6
PADLOP3:
	srl	h	;Calculates the message length
	rr	l	;in blocks of 16 32-bit words
	djnz	PADLOP3	;(that is, divides length by 64)
	ld	(MSG_BLK),hl

	;--- Step 3: initialize buffer

	ld	hl,INIT_ABCD
	ld	de,BUF_A
	ld	bc,16
	ldir

	;--- Step 4: process blocks

	;* Copy current block to buffer X:
	;  No need for that! Message data is read directly,
	;  and value of (MSG_PNT) acts as the starting address of X

	;* Backup A,B,C,D

PBLOCKS:
	ld	hl,BUF_A	;Sets buffers AA,BB,CC,DD
	ld	de,BUF_AA
	ld	bc,16
	ldir

	;* Rounds execution

	ld	hl,R_DATA
	ld	(ROUND_PNT),hl
	ld	a,1
	ld	(ROUND_N),a
	ld	(PAR_I),a

	call	ROUND
	call	ROUND
	call	ROUND
	call	ROUND

	;* Adds AA to A, BB to B, CC to C, DD to D

	m_add32	BUF_A,BUF_AA
	m_add32	BUF_B,BUF_BB
	m_add32	BUF_C,BUF_CC
	m_add32	BUF_D,BUF_DD

	;* Continues to next block, if any

	ld	bc,(MSG_BLK)
	dec	bc
	ld	a,b
	or	c
	jr	z,MD5END
	ld	(MSG_BLK),bc

	ld	hl,(MSG_PNT)	;Updates message pointer by adding 64
	ld	bc,64
	add	hl,bc
	ld	(MSG_PNT),hl
	jp	PBLOCKS

	;--- Step 5: output

MD5END:	ld	hl,BUF_A
	ret


	;--------------------------------
	;---  ROUTINES AND FUNCTIONS  ---
	;--------------------------------

	;--- Sets parameters for round execution and executes round;
	;    after each operation exchanges A,B,C,D, and after
	;    the entire round increases ROUND_N

ROUND:	ld	b,16	;There are 16 operations per round

DO_RLOOP:
	push	bc
	ld	hl,(ROUND_PNT)
	ld	a,(hl)
	ld	(PAR_K),a	;Sets parameters and executes operation
	inc	hl
	ld	a,(hl)
	ld	(PAR_S),a
	inc	hl
	ld	(ROUND_PNT),hl
	call	ROUND_OP
	call	SH_ABCD	;After each operation A,B,C,D are shifted
	ld	hl,PAR_I	;and PAR_I is increased
	inc	(hl)
	pop	bc
	djnz	DO_RLOOP

	ld	hl,ROUND_N	;After the 16 operations, round number
	inc	(hl)	;is increased
	ret

	;--- SH_ABCD: Transforms ABCD into DABC, DABC into CDAB, CDAB into BCDA,
	;             or BCDA into ABCD

SH_ABCD:
	ld	hl,BUF_D+3	;D->temp
	ld	de,RES_FGHI+3
	ld	bc,4
	lddr

	ld	de,BUF_D+3
	ld	c,12	;C->D, B->C, A->B
	lddr

	ld	hl,RES_FGHI+3
	ld	c,4	;temp->A
	lddr

	ret

	;--- Function for ROUND operation execution
	;    Executes  A = B + ((A + F/G/H/I(B,C,D) + X[k] + T[i]) <<< s)
	;              where F,G,H,I is choosen when ROUND_N is 1,2,3,4 respectively
	;    Input:  PAR_K, PAR_S and PAR_I appropriately set
	;            ABCD buffer approriately rotated so it is ABCD,DABC,CDAB or BCDA
	;            ROUND_N set to 1,2,3 or 4
	;    Output: BUF_A with the result of the operation

ROUND_OP:
	ld	a,(ROUND_N)	;Calls function F,G,H or I
	ld	hl,FUN_F	;depending on the round number
	dec	a
	jr	z,OKR1
	ld	hl,FUN_G
	dec	a
	jr	z,OKR1
	ld	hl,FUN_H
	dec	a
	jr	z,OKR1
	ld	hl,FUN_I
OKR1:	ld	de,OKR2
	push	de
	jp	(hl)
OKR2:	;

	m_add32	BUF_A,RES_FGHI	;Adds A to the result of F/G/H/I
	;                        ;and stores result on A

	ld	a,(PAR_K)	;Adds X[k] to the previous result
	ld	ix,(MSG_PNT)	;and stores it to A again.
	call	ADD_XT	;Note that actually no X buffer is used.

	ld	a,(PAR_I)	;Adds T[i] to the previous result
	dec	a	;ans stores it to A again
	ld	ix,BUF_T
	call	ADD_XT

	ld	ix,BUF_A	;Shifts s bits A
	ld	a,(PAR_S)
	ld	b,a
	call	SHIFT

	m_add32	BUF_A,BUF_B	;Finally, adds B to A

	ret

ADD_XT:	ld	c,a	;Routine for adding X[k] or T[i] to A
	ld	b,0	;Input: IX=(MSG_PNT) and A=(PAR_K)
	add	ix,bc	;or IX=BUF_T and A=(PAR_I)-1
	add	ix,bc
	add	ix,bc
	add	ix,bc
	ld	l,(ix+0)
	ld	h,(ix+1)
	ld	de,(BUF_A)
	add	hl,de
	ld	(BUF_A),hl
	ld	l,(ix+2)
	ld	h,(ix+3)
	ld	de,(BUF_A+2)
	adc	hl,de
	ld	(BUF_A+2),hl
	ret

	;--- Circular left shifting of a 32 bit word (stored low byte first)
	;    Input: IX = Pointer to the word, B = Positions to shift

SHIFT:	sla	(ix+0)
	rl	(ix+1)
	rl	(ix+2)
	rl	(ix+3)
	jr	nc,SHIFT2
	set	0,(ix+0)
SHIFT2:	djnz	SHIFT
	ret

	;--- Function F

nXaZ:	macro	@n	;Calculates "not(X) and Z"
	ld	a,(ix+@n)	;for the byte @n (0 to 3)
	cpl		;                ;of the 32-bit word
	and	(ix+8+@n)
	ld	(iy+@n),a
	endm

XaYo:	macro	@n	;Calculates "X and Y or nXaZ"
	ld	a,(ix+@n)
	and	(ix+4+@n)
	or	(iy+@n)
	ld	(iy+@n),a
	endm

FUN_F:	call	FUN_SETP

	nXaZ	0
	nXaZ	1
	nXaZ	2
	nXaZ	3

	XaYo	0
	XaYo	1
	XaYo	2
	XaYo	3

	ret

	;--- Function G

nZaY:	macro	@n	;Calculates "not(Z) and Y"
	ld	a,(ix+8+@n)
	cpl
	and	(ix+4+@n)
	ld	(iy+@n),a
	endm

XaZo:	macro	@n	;Calculates "X and Z or nZaY"
	ld	a,(ix+@n)
	and	(ix+8+@n)
	or	(iy+@n)
	ld	(iy+@n),a
	endm

FUN_G:	call	FUN_SETP

	nZaY	0
	nZaY	1
	nZaY	2
	nZaY	3

	XaZo	0
	XaZo	1
	XaZo	2
	XaZo	3

	ret

	;--- Function H

XxYxZ:	macro	@n	;Calculates "X xor Y xor Z"
	ld	a,(ix+@n)
	xor	(ix+4+@n)
	xor	(ix+8+@n)
	ld	(iy+@n),a
	endm

FUN_H:	call	FUN_SETP

	XxYxZ	0
	XxYxZ	1
	XxYxZ	2
	XxYxZ	3

	ret

	;--- Function I

XonZ:	macro	@n	;Calculates "X or (not Z)"
	ld	a,(ix+8+@n)
	cpl
	or	(ix+@n)
	ld	(iy+@n),a
	endm

Yx:	macro	@n	;Calculates "Y xor XonZ"
	ld	a,(ix+4+@n)
	xor	(iy+@n)
	ld	(iy+@n),a
	endm

FUN_I:	call	FUN_SETP

	XonZ	0
	XonZ	1
	XonZ	2
	XonZ	3

	Yx	0
	Yx	1
	Yx	2
	Yx	3

	ret

	;--- Initial pointer setting for functions

FUN_SETP:	ld	ix,PAR_X
	ld	iy,RES_FGHI
	ret


	;-------------------
	;---  DATA AREA  ---
	;-------------------

	;*** Do not modify the buffers order in memory ***

	;--- Data for round execution
	;    Parameter I is omitted, since it is always the one for the
	;    previous operation plus one

R_DATA:
	;* ROUND 1

	defb	0,7
	defb	1,12
	defb	2,17
	defb	3,22
	defb	4,7
	defb	5,12
	defb	6,17
	defb	7,22
	defb	8,7
	defb	9,12
	defb	10,17
	defb	11,22
	defb	12,7
	defb	13,12
	defb	14,17
	defb	15,22

	;* ROUND 2

	defb	1,5
	defb	6,9
	defb	11,14
	defb	0,20
	defb	5,5
	defb	10,9
	defb	15,14
	defb	4,20
	defb	9,5
	defb	14,9
	defb	3,14
	defb	8,20
	defb	13,5
	defb	2,9
	defb	7,14
	defb	12,20

	;* ROUND 3

	defb	5,4
	defb	8,11
	defb	11,16
	defb	14,23
	defb	1,4
	defb	4,11
	defb	7,16
	defb	10,23
	defb	13,4
	defb	0,11
	defb	3,16
	defb	6,23
	defb	9,4
	defb	12,11
	defb	15,16
	defb	2,23

	;* ROUND 4

	defb	0,6
	defb	7,10
	defb	14,15
	defb	5,21
	defb	12,6
	defb	3,10
	defb	10,15
	defb	1,21
	defb	8,6
	defb	15,10
	defb	6,15
	defb	13,21
	defb	4,6
	defb	11,10
	defb	2,15
	defb	9,21

	;--- Result of F/G/H/I functions

RES_FGHI:
	defs	4

	;---- Buffers for A,B,C,D,AA,BB,CC,DD

BUF_A:	defs	4
BUF_B:	defs	4
BUF_C:	defs	4
BUF_D:	defs	4
BUF_AA:	defs	4
BUF_BB:	defs	4
BUF_CC:	defs	4
BUF_DD:	defs	4

	;--- Buffers for parameters X,Y,Z to use on functions F,G,H,I
	;    (must be consecutive in memory)
	;    Since these functions are always called with (X,Y,Z)=(B,C,D),
	;    actually no buffers are defined but B,C,D buffers are directly referred

PAR_X:	equ	BUF_B
PAR_Y:	equ	BUF_C
PAR_Z:	equ	BUF_D

	;--- Initial values for BUF_A/B/C/D

INIT_ABCD:
	defb	1h,23h,45h,67h
	defb	89h,0ABh,0CDh,0EFh
	defb	0FEh,0DCh,0BAh,98h
	defb	76h,54h,32h,10h

	;--- Some variables

MSG_LEN:	defw	0	;Message length in bytes (without padding)
MSG_BLK:	defw	0	;Message length in blocks of 32-bit words
MSG_PNT:	defw	0	;Pointer to the start of next block
PAR_K:		defb	0	;Parameters k,s,i for round steps
PAR_S:		defb	0
PAR_I:		defb	0
ROUND_N:	defb	0	;Current round number (1 to 4)
ROUND_PNT:	defw	0	;Current round data pointer

	;--- Sinus table for function T

BUF_T:	defw	0A478h,0D76Ah,0B756h,0E8C7h,070DBh,02420h,0CEEEh,0C1BDh
	defw	0FAFh,0F57Ch,0C62Ah,04787h,04613h,0A830h,09501h,0FD46h
	defw	098D8h,06980h,0F7AFh,08B44h,05BB1h,0FFFFh,0D7BEh,0895Ch
	defw	01122h,06B90h,07193h,0FD98h,0438Eh,0A679h,0821h,049B4h
	defw	02562h,0F61Eh,0B340h,0C040h,05A51h,0265Eh,0C7AAh,0E9B6h
	defw	0105Dh,0D62Fh,01453h,0244h,0E681h,0D8A1h,0FBC8h,0E7D3h
	defw	0CDE6h,021E1h,07D6h,0C337h,0D87h,0F4D5h,014EDh,0455Ah
	defw	0E905h,0A9E3h,0A3F8h,0FCEFh,02D9h,0676Fh,04C8Ah,08D2Ah
	defw	03942h,0FFFAh,0F681h,08771h,06122h,06D9Dh,0380Ch,0FDE5h
	defw	0EA44h,0A4BEh,0CFA9h,04BDEh,04B60h,0F6BBh,0BC70h,0BEBFh
	defw	07EC6h,0289Bh,027FAh,0EAA1h,03085h,0D4EFh,01D05h,0488h
	defw	0D039h,0D9D4h,099E5h,0E6DBh,07CF8h,01FA2h,05665h,0C4ACh
	defw	02244h,0F429h,0FF97h,0432Ah,023A7h,0AB94h,0A039h,0FC93h
	defw	059C3h,0655Bh,0CC92h,08F0Ch,0F47Dh,0FFEFh,05DD1h,08584h
	defw	07E4Fh,06FA8h,0E6E0h,0FE2Ch,04314h,0A301h,011A1h,04E08h
	defw	07E82h,0F753h,0F235h,0BD3Ah,0D2BBh,02AD7h,0D391h,0EB86h

	;Note: the sinus table has been generated
	;with the following MSX-BASIC program:

	;1   'Sinus table generator for MD5 algorithm
	;2   'By Nestor Soriano, 27-5-2001
	;10  OPEN"md5sin.asm" FOR OUTPUT AS#1
	;20  PRINT"Generating file..."
	;30  FOR I1=0 TO 15
	;40    PRINT#1,"   defw ";
	;50    FOR I2=0 TO 3
	;60      S=INT((ABS(SIN(I1*4+I2+1)))*2^32)
	;70      SH=INT(S/65536!)
	;80      SL=S-SH*65536!
	;90      PRINT#1,"0";HEX$(SL);"h,0";HEX$(SH);"h";
	;100     IF I2<3 THEN PRINT#1,",";
	;110   NEXT I2:PRINT#1,""
	;120 NEXT I1
	;130 CLOSE#1
	;140 PRINT"Done. Resulting file:"
	;150 COPY"md5sin.asm"TO"con"


	if	LINK=0

;--- NAME: INSTR
;      Search a string included in another one
;    INPUT:   HL = Main string address
;             DE = Searched string addrss, zero terminated
;             C  = Main string termination character
;    OUTPUT:  Cy = 0 if found, 1 if not found
;    MODIFIES: AF, C, DE, HL

INSTR:

	;* Search termination character, set length in B

	push	hl
	ld	b,-1
BUSFIN:	inc	b
	ld	a,(hl)
	inc	hl
	cp	c
	jr	nz,BUSFIN
	pop	hl

	;* Prepare variables

	push	de	;Searched string
	inc	b	;Characters left to compare

	;* Comparison main loop

COMPA:	ld	a,(de)
	or	a
	jr	z,COMPEND
	cp	(hl)
	inc	hl
	inc	de
	jr	nz,NOMATCH
COMPA2:
	djnz	COMPA
	scf

COMPEND:
	pop	de
	ret

NOMATCH:
	pop	de
	push	de
	jr	COMPA2

	endif


;--- PARSE_IP: Extracts an IP address from a string
;    Input:  Atring at DNS_BUFFER, zero terminated 0
;    Output: Cy=0 and IP at DNS_RESULT, or Cy=1 if not a valid IP

PARSE_IP:
	ld	hl,DNS_BUFFER
PARSE_IPL:
	ld	a,(hl)
	or	a
	jr	z,PARSE_IP2	;Appends a dot to ease parsing process
	inc	hl
	jr	PARSE_IPL
PARSE_IP2:	ld	(hl),"."
	ld	(PARSE_IPDIR),hl

	ld	de,DNS_RESULT
	ld	hl,DNS_BUFFER
	ld	b,4

IPLOOP:	push	bc,de
	call	EXTNUM
	jp	c,ERRIP	;Checks that it is a number in the range 0-255
	or	a	;and that it is zero terminated
	jp	nz,ERRIP
	ld	a,b
	or	a
	jp	nz,ERRIP
	ld	a,e
	cp	"."
	jp	nz,ERRIP

	ld	a,c
	ld	c,d
	ld	b,0
	pop	de
	ld	(de),a
	add	hl,bc
	inc	hl
	inc	de
	pop	bc
	djnz	IPLOOP

	or	a
	jr	PARSE_IPEND

ERRIP:	pop	de,bc
	scf

PARSE_IPEND:
	ld	hl,(PARSE_IPDIR)
	ld	(hl),0
	ret

PARSE_IPDIR:	dw	0


;--- NAME: EXTNUM16
;      Extracts a 16 bit number from a string
;    INPUT:  HL = ASCII string address
;    OUTPUT: BC = number
;            Cy=1 if error
;    MODIFIES: All

EXTNUM16:
	call	EXTNUM
	ret	c
	or	a
	scf
	ret	nz
	ld	a,e
	or	a
	scf
	ret	nz
	or	a
	ret


;--- NAME: EXTNUM8
;	   Extracts a 8 bit number from a string
;    INPUT:  HL = ASCII string address
;    OUTPUT: A  = number
;            Cy=1 if error
;    MODIFIES: All

EXTNUM8:
	call	EXTNUM
	ret	c
	or	a
	scf
	ret	nz
	ld	a,b
	or	a
	scf
	ret	nz
	ld	a,e
	or	a
	scf
	ret	nz
	ld	a,c
	or	a
	ret


;--- NAME: EXTNUM
;      Extracts a 5 digit number from a string
;    INPUT:    HL = ASCII string address
;    OUTPUT:   CY-BC = 17 bit number
;              D  = Count of digits of the number.
;		The number is considered to be extracted
;                   when a non-numeric character is found,
;                   or when five digits have been extracted.
;              E  = First non-numeric character (o 6th digit)
;              A  = error code:
;                   0 => Success
;                   1 => The number has more than 5 digits.
;                        CY-BC contains then the number built from
;                        the first 5 digits.
;    MODIFIES:  -

EXTNUM:	push	hl,ix
	ld	ix,ACA
	res	0,(ix)
	set	1,(ix)
	ld	bc,0
	ld	de,0
BUSNUM:	ld	a,(hl)	;Jump to FINEXT if not a digit, or is the 6th digit
	ld	e,a
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


;--- GET_SERV: Read a server name stored with dots
;              and store it in DNS format
;    Input:  HL = Server name, zero terminated
;            IX = Destination address
;    Output: IX points after the generated string

GET_SERV:
	ld	a,(hl)	;Empty string is a special case
	or	a
	jr	nz,GET_SERV0

	ld	(ix),0
	inc	ix
	ret

GET_SERV0:
	ld	(GETSERV_PNT),ix
	inc	ix
	ld	b,0
GETSERV_LOP:
	ld	a,(hl)	;Get characters until finding "." or 0
	inc	hl
	cp	"."
	jr	z,GETS_LBELOK
	or	a
	jr	z,GETS_LBELOK
	ld	(ix),a
	inc	ix
	inc	b
	jr	GETSERV_LOP

GETS_LBELOK:
	push	ix	;"." or 0: insert length
	ld	ix,(GETSERV_PNT)
	res	7,b
	res	6,b
	ld	(ix),b
	pop	ix

	dec	hl
	ld	a,(hl)
	inc	hl
	or	a
	jr	nz,GET_SERV0
	ld	(ix),0
	inc	ix
	ret

GETSERV_PNT:
	dw	0	;Save address where length is inserted


	;=================================
	;===  Packet sending routines  ===
	;=================================

	if	LINK=0

;--- Physical packet send, PPP version.
;    Assumes that the complete packet is at OUT_BUFFER,
;    except for the initial #FF03 and the final FCS.

SEND_PACKET:

	;--- Calculate packet start address

	;* Initially assume packet starts at OUT_BUFFER
	;  and no compressions will be used

	ld	hl,#03FF
	ld	(OUT_BUFFER),hl
	ld	ix,OUT_BUFFER
	ld	bc,4	;PPP header length

	;* If protocol is LCP, do not compress anything

	ld	hl,(OUT_BUFFER+2)
	ld	de,#21C0
	call	COMP
	jr	z,OK_PAQ_PNT

	;* If protocol can be compressed and first byte
	;  is zero, compress it

	ld	a,(PPP_COMP_P)
	or	a
	jr	z,NO_PPPCOMPP

	ld	a,(OUT_BUFFER+2)
	or	a
	jr	nz,NO_PPPCOMPP

	ld	hl,#03FF
	ld	(OUT_BUFFER+1),hl
	inc	ix
	dec	bc	;Now the header is #FF #03 (odd protocol number)
NO_PPPCOMPP:

	;* If initial #FF #03 can be compressed, compress it

	ld	a,(PPP_COMP_FF)
	or	a
	jr	z,OK_PAQ_PNT

	inc	ix
	inc	ix
	dec	bc
	dec	bc

OK_PAQ_PNT:
	ld	(SEND_PAQ_PNT),ix

	;--- Obtain packet data size.
	;    Whatever the packet type is, data part is at OUT_BUFFER+6
	;    (starting with packet length).

	ld	a,(OUT_BUFFER+6)
	ld	h,a
	ld	a,(OUT_BUFFER+7)
	ld	l,a	;HL =  Packet length

	ld	a,(USE_VJ_OUT)	;Peer supports VJ?
	ld	d,a
	ld	a,(IS_RAW_DGRAM)	;Raw datagram?
	cpl
	and	d
	push	bc
	call	nz,COMPRESS_VJ	;Returns updated SEND_PAQ_PNT and HL=new datagram length
	pop	bc

	xor	a
	ld	(IS_RAW_DGRAM),a

	ld	de,576	;If too big, reduce to 576
	call	COMP
	jr	nc,OKPAQ2
	ex	de,hl
OKPAQ2:

	;ld	bc,?	;Add #FF03 and/or Proto (BC is already set)
	add	hl,bc	;Now HL = Total length except FCS

	;--- Calculate FCS and append it to the packet

	push	hl,hl
	pop	bc
	ld	hl,(SEND_PAQ_PNT)
	push	hl
	ld	de,#FFFF
	call	CALC_FCS
	pop	hl

	pop	bc
	;ld	hl,(SEND_PAQ_PNT)
	add	hl,bc	;Now HL points to packet end
	ld	a,e
	cpl
	ld	(hl),a
	inc	hl
	ld	a,d
	cpl
	ld	(hl),a

	inc	bc
	inc	bc	;Now BC=packet length including FCS

	;--- Send packet.
	;    Always escape #7D and #7E.
	;    If LCP, always escape 0-31.
	;    Otherwise, escape 0-31 if ASYNC_MAP=#FF.

	ld	a,(ASYNC_MAP)
	ld	d,a
	ld	hl,(OUT_BUFFER+2)
	ld	de,#21C0
	call	COMP
	jr	nz,IS_NOT_LCP
	ld	d,#FF
IS_NOT_LCP:	;D=#FF if 0-31 must be escaped

	;--- Send BC bytes starting at OUT_BUFFER

	ld	hl,(SEND_PAQ_PNT)
	ld	a,#7E	;Packet start flag
	call	SEND_BYTE

SEND_PACK_LOOP:
	ld	a,(hl)
	cp	#7D
	jr	z,SEND_ESCAPED
	cp	#7E
	jr	z,SEND_ESCAPED

	bit	0,d
	jr	z,SEND_NORMAL
	bit	7,a
	jr	nz,SEND_NORMAL	;Because 128-255 is considered <32 by CP
	cp	32
	jr	nc,SEND_NORMAL

SEND_ESCAPED:
	ld	e,a
	ld	a,#7D
	call	SEND_BYTE
	ld	a,e
	xor	#20
SEND_NORMAL:
	call	SEND_BYTE

	inc	hl
	dec	bc
	ld	a,b
	or	c
	jr	nz,SEND_PACK_LOOP

	;--- Packet sent: send final #7E and terminate

	ld	a,#7E

	;--- Send a byte preserving registers

SEND_BYTE:
	push	hl,de,bc
	call	RS_OUT
	pop	bc,de,hl
	ret

SEND_PAQ_PNT:
	dw	0	;Pointer to PPP packet start


;--- Send LCP/IPCP Code-Reject.
;    Assumes the packet to be rejected in IN_BUFFER.
;    Assumes the packet to be rejected has length<=(576-4).

SEND_CREJ:
	ld	hl,(IN_BUFFER+2)
	ld	(OUT_BUFFER+2),hl	;Protocol
	ld	a,7	;Code Reject
	ld	(OUT_BUFFER+4),a
	ld	a,(ID_CODEREJ)
	ld	(OUT_BUFFER+5),a
	inc	a
	ld	(ID_CODEREJ),a	;Identifier

	ld	hl,(INBUF_SIZE)
	ld	bc,6
	or	a
	sbc	hl,bc	;Substract #FF03 Proto FCS
	push	hl
	pop	bc
	ld	hl,IN_BUFFER+4
	ld	de,OUT_BUFFER+8
	ldir		;Copy the offending packet

	ld	hl,(INBUF_SIZE)	;Size of packet to be sent:
	dec	hl	;substract #FF03 Proto FCS, add 7 Id Long
	dec	hl	;(-6+4 = -2)
	ld	a,h
	ld	(OUT_BUFFER+6),a
	ld	a,l
	ld	(OUT_BUFFER+7),a

	jp	SEND_PACKET


;---  Send LCP Configure-Request.
;     Include or not MRU and Async-map options, according to XCP_NEXTOP.

SEND_LCP_CREQ:
	ld	hl,#21C0
	ld	(OUT_BUFFER+2),hl	;Proto LCP
	ld	a,1
	ld	(OUT_BUFFER+4),a	;ConfReq code
	ld	a,(ID_CONFREQ)
	ld	(OUT_BUFFER+5),a	;ID
	inc	a
	ld	(ID_CONFREQ),a
	ld	hl,4	;Initial size of packet
	ld	ix,OUT_BUFFER+8	;IX = Pointer to area where options will be created

	;--- Add MRU option if necessary

	ld	a,(XCP_NEXTOP)
	bit	0,a
	jr	z,SLCPC_OP1OK
	ld	(ix),1
	ld	(ix+1),4
	push	hl
	ld	hl,(NEXT_MRU)
	ld	(ix+2),h	;576 unless peer NAKs other value
	ld	(ix+3),l
	pop	hl
	ld	bc,4
	add	ix,bc
	add	hl,bc
SLCPC_OP1OK:

	;--- Add AsyncMap option if necessary

	bit	1,a
	jr	z,SLCPC_OP2OK
	ld	(ix),2
	ld	(ix+1),6
	push	hl
	ld	hl,(NEXT_ASYNC)
	ld	(ix+2),l	;#00000000 unless peer NAKs other value
	ld	(ix+3),h
	ld	hl,(NEXT_ASYNC+2)
	ld	(ix+4),l
	ld	(ix+5),h
	pop	hl
	ld	bc,6
	add	ix,bc
	add	hl,bc
SLCPC_OP2OK:

	;--- Add PPP protocol compression option if necessary

	ld	a,(PPP_COMP_P)
	or	a
	jr	z,SLCPC_OP7OK
	ld	(ix),7
	ld	(ix+1),2
	inc	ix
	inc	ix
	inc	hl
	inc	hl
SLCPC_OP7OK:	;

	;--- Add initial #FF #03 compression option if necessary

	ld	a,(PPP_COMP_FF)
	or	a
	jr	z,SLCPC_OP8OK
	ld	(ix),8
	ld	(ix+1),2
	inc	ix
	inc	ix
	inc	hl
	inc	hl
SLCPC_OP8OK:	;

	;--- Set resulting size and send packet

	ld	a,l
	ld	(OUT_BUFFER+7),a
	xor	a
	ld	(OUT_BUFFER+6),a
	jp	SEND_PACKET


;---  Send IPCP Configure-Request.
;     Include or not DNS options according to NEGDNS,
;     and the VJ option according to USE_VJ_IN

SEND_IPCP_CREQ:
	ld	hl,PACK_IPREQ
	ld	de,OUT_BUFFER+2
	ld	bc,24
	ldir		;Initially copy the prebuilt packet

	ld	a,(ID_CONFREQ)	;Set ID
	ld	(OUT_BUFFER+5),a
	inc	a
	ld	(ID_CONFREQ),a

	ld	hl,BUF_IPLOCAL	;Set local IP
	ld	de,OUT_BUFFER+10
	ld	bc,4
	ldir

	ld	ix,OUT_BUFFER+14	;Pointer to next option
	ld	b,10	;Inicial packet size

	;--- Add DNS options if necessary

	ld	a,(NEGDNS)	;DNS not negotiated: all done
	or	a	;(packet has preconfigured length)
	jr	z,NO_ADD_DNS

	ld	hl,BUF_IPDNS1	;Add IP DNS options
	ld	de,OUT_BUFFER+16
	ld	bc,4
	ldir
	ld	hl,BUF_IPDNS2
	ld	de,OUT_BUFFER+22
	ld	bc,4
	ldir

	ld	b,22	;New size
	ld	ix,OUT_BUFFER+14+12	;New pointer to next option
NO_ADD_DNS:

	;--- Add VJ compression option VJ if necessary

	ld	a,(USE_VJ_IN)
	or	a
	jr	z,NO_ADD_VJ

	ld	a,b
	push	ix
	pop	de
	ld	hl,PACK_VJ	;Option is already prebuilt
	ld	bc,6
	ldir

	add	6
	ld	b,a
NO_ADD_VJ:

	;--- Send packet

	ld	a,b
	ld	(OUT_BUFFER+7),a
	jp	SEND_PACKET


;--- Send LCP Terminate-Request or
;    Terminate-Ack that is NOT a reply to a Terminate-Request

SEND_TREQ:
	ld	a,5
	jr	SEND_TRA

SEND_TACK:
	ld	a,6

SEND_TRA:
	ld	hl,#21C0
	ld	(OUT_BUFFER+2),hl	;Protocol
	ld	(OUT_BUFFER+4),a	;Terminate-Request/Ack code
	ld	a,(ID_TERMREQ)
	ld	(OUT_BUFFER+5),a	;ID
	inc	a
	ld	(ID_TERMREQ),a
	ld	hl,#0400
	ld	(OUT_BUFFER+6),hl	;Length

	xor	a
	ld	(PPP_STATE),a
	ld	(PCAP_STATE),a
	call	CLOSE_ALL_TCP
	jp	SEND_PACKET


;--- Send PAP Request

SEND_PAP_REQ:
	ld	hl,#23C0	;PAP protocol
	ld	(OUT_BUFFER+2),hl
	ld	a,1	;Code for Request
	ld	(OUT_BUFFER+4),a
	ld	a,(ID_PAPREQ)
	ld	(OUT_BUFFER+5),a	;ID
	inc	a
	ld	(ID_PAPREQ),a
	xor	a	;Length, high byte
	ld	(OUT_BUFFER+6),a
	ld	de,OUT_BUFFER+8

	ld	hl,BUF_PPPUSER
	push	hl	;Copy user name
	call	STRLEN
	pop	hl
	push	bc
	ld	a,c
	ld	(de),a
	inc	de
	ldir

	ld	hl,BUF_PPPASSW
	push	hl	;Copy password
	call	STRLEN
	pop	hl
	push	bc
	ld	a,c
	ld	(de),a
	inc	de
	ldir

	pop	bc,hl	;Set toal packet length
	add	hl,bc
	ld	a,l
	add	6
	ld	(OUT_BUFFER+7),a

	jp	SEND_PACKET

	endif

	if	LINK=1

;--- Physical packet send, Ethernet version.
;    Assumes the packet data starts at OUT_BUFFER+4.
;    Input: HL=Pointer to destination MAC address
;           DE=Ether-type

SEND_PACKET:

	;--- Set Ether-Type

	ld	a,d
	ld	(OUT_BUFFER+2),a
	ld	a,e
	ld	(OUT_BUFFER+3),a

	;--- Obtain packet length.
	;    It is at OUT_BUFFER+6 if it is an IP datagram,
	;    for ARP packets length is always 28.

	push	hl

	ld	hl,#0800
	call	COMP
	ld	hl,28
	jr	nz,SEND_PAQ_2

	ld	a,(OUT_BUFFER+6)
	ld	h,a
	ld	a,(OUT_BUFFER+7)
	ld	l,a

	ld	de,576	;If too big, reduce it to 576
	call	COMP
	jr	nc,SEND_PAQ_2
	ex	de,hl
SEND_PAQ_2:
	ex	(sp),hl	;Length to stack, HL=MAC address

	;--- Decide frame type

	ld	a,(FRAME_TYPE)
	or	a
	jr	nz,SEND_IEEE

	;--- Ethernet 2 frame

SEND_ETH2:
	ld	de,OUT_BUFFER-10	;Destination address
	ld	bc,6
	ldir

	ld	hl,HWAD	;Source address
	ld	de,OUT_BUFFER-4
	ld	bc,6
	ldir

	pop	hl	;Update length
	ld	bc,14
	add	hl,bc
	push	hl
	pop	bc

	ld	hl,OUT_BUFFER-10

	ld	d,1
	ethnet	ETH_SEND_FRAME
	ret

	;--- IEEE802.3 frame

SEND_IEEE:
	ld	de,OUT_BUFFER-18	;Destination address
	ld	bc,6
	ldir

	ld	hl,HWAD	;Source address
	ld	de,OUT_BUFFER-12
	ld	bc,6
	ldir

	ld	hl,SNAP_HDR	;SNAP header
	ld	de,OUT_BUFFER-4
	ld	bc,6
	ldir

	pop	hl	;Set length...
	ld	bc,8
	add	hl,bc
	ld	a,h
	ld	(OUT_BUFFER-6),a
	ld	a,l
	ld	(OUT_BUFFER-5),a
	ld	bc,14
	add	hl,bc	;...and update it
	push	hl
	pop	bc

	ld	hl,OUT_BUFFER-18

	ld	d,1
	ethnet	ETH_SEND_FRAME
	ret

SNAP_HDR:
	db	170,170,3,0,0,0


;--- Send an ARP request
;    Input: L.H.E.D = Address to be queried

SEND_ARP_RQ:
	ld	(ARPRQ_IPRCV),hl	;Destination IP
	ld	(ARPRQ_IPRCV+2),de

	ld	hl,BUF_IPLOCAL	;Source IP
	ld	de,ARPRQ_IPSND
	ld	bc,4
	ldir

	ld	hl,HWAD		;Source MAC
	ld	de,ARPRQ_HWSND
	ld	bc,6
	ldir

	ld	hl,ARP_RQ	;Copy packet to OUT_BUFFER
	ld	de,OUT_BUFFER+4
	ld	bc,28
	ldir

	ld	hl,ETH_BROAD	;Send packet to broadcast address
	ld	de,#0806
	jp	SEND_PACKET

	;ARP Request packet

ARP_RQ:		db	0,1,8,0,6,4,0,1
ARPRQ_HWSND:	ds	6
ARPRQ_IPSND:	ds	4
ARPRQ_HWRCV:	ds	6	;Always 0
ARPRQ_IPRCV:	ds	4

ETH_BROAD:	db	#FF,#FF,#FF,#FF,#FF,#FF


;--- Send an ARP Reply
;    Input: Source ARP Request received at IN_BUFFER+4

SEND_ARP_RP:
	ld	hl,IN_BUFFER+4	;Copy header,
	ld	de,OUT_BUFFER+4	;changing REQUEST into REPLY
	ld	bc,7
	ldir
	ld	a,2
	ld	(de),a
	inc	de

	ld	hl,HWAD	;Source MAC
	;ld	de,OUT_BUFFER+12
	ld	bc,6
	ldir

	ld	hl,BUF_IPLOCAL	;Source IP
	;ld	de,OUT_BUFFER+18
	ld	bc,4
	ldir

	ld	hl,IN_BUFFER+12	;Copy data from SENDER to RECEIVER
	;ld	de,OUT_BUFFER+22
	ld	bc,10
	ldir

	ld	hl,OUT_BUFFER+22	;Send packet
	ld	de,#0806
	jp	SEND_PACKET

	endif


;--- IP datagram sending routine.
;    Input: L.H.E.D = Destination IP
;           BC = Data length
;           A = Protocol code
;           Data to be sent at OUT_BUFFER+24

SEND_IP:
	call	PREPARE_IP	;Set IPs and protocol

	;> If executed from here:
	;  Input: BC = Data length

SEND_IP2:
	;* Set length

	ld	hl,20
	add	hl,bc
	ld	a,h	;Length (data+header)
	ld	(OUT_BUFFER+6),a
	ld	a,l
	ld	(OUT_BUFFER+7),a

	;* Set other parameters

	if	LINK=0

	ld	hl,#2100	;PPP protocol
	ld	(OUT_BUFFER+2),hl

	endif

	ld	a,#45	;IP version + header length
	ld	(OUT_BUFFER+4),a

	ld	a,(TOS)	;Type Of Service
	ld	(OUT_BUFFER+5),a

	ld	hl,(ID_IP)	;IP identifier
	ld	a,h
	ld	(OUT_BUFFER+8),a
	ld	a,l
	ld	(OUT_BUFFER+9),a
	inc	hl
	ld	(ID_IP),hl

	ld	a,(TTL)	;Time To Live
	ld	(OUT_BUFFER+12),a

	;* Calculate checksum

	ld	ix,OUT_BUFFER+4
	ld	bc,20
	call	CALC_CHKSUM
	ld	(OUT_BUFFER+14),de

	if	LINK=0

	;* Datagram is complete: send it

	jp	SEND_PACKET

	endif

	if	LINK=1

	;>>> Datagrama is complete.
	;>>> No we must manage ARP, routing, etc.
	;    Input: HL=Pointer to destination IP address

SEND_IP_ETH0:
	xor	a
	ld	(IS_ROUTER),a

	ld	hl,OUT_BUFFER+20

SEND_IP_ETH:
	ld	de,IP_TO_SEND
	ld	bc,4
	ldir

	;--- If destination IP is broadcast (mask OR IP = 255.255.255.255),
	;    send to broadcast MAC address.

	ld	hl,SUBNET_MASK
	ld	de,IP_TO_SEND
	ld	b,4
CHKIPBROAD:
	ld	a,(de)
	or	(hl)
	inc	a
	jr	nz,SEND_IP_NOBRO
	inc	hl
	inc	de
	djnz	CHKIPBROAD

	ld	hl,ETH_BROAD
	ld	de,#0800
	jp	SEND_PACKET
SEND_IP_NOBRO:

	;--- Check if there is an entry for the destination IP
	;    in the ARP cache

	ld	de,IP_TO_SEND
	call	SRCH_ARP
	jr	c,SIPE_NOARP

	;* If entry is in resolution, terminate

	ld	a,(ix)
	cp	3
	jp	z,COPY_TO_WOUT

	;* Oteherwise, send packet to this entry's MAC

	push	ix
	pop	hl
	inc	hl
	ld	de,#0800
	jp	SEND_PACKET
SIPE_NOARP:

	;--- Check if destination IP is in our subnet,
	;    or if subnet mask is 0.
	;    If so, perform an ARP request to obtain
	;    the recipient's IP address.

	ld	a,(IS_ROUTER)	;IP belongs to a router:
	or	a		;use local ARP  (it will be in the same,
	jr	nz,SI_SAME_SUB	;subnet or if not, rely in Proxy-ARP).

	ld	hl,SUBNET_MASK	;Mask is 0: use local ARP,
	ld	de,ZERO32	;relying in Proxy-ARP.
	call	COMP32
	jr	z,SI_SAME_SUB

	ld	de,IP_TO_SEND
	ld	hl,BUF_IPLOCAL
	ld	ix,SUBNET_MASK
	call	SAME_SUBNET
	jr	nc,NO_SAME_SUB

SI_SAME_SUB:
	call	COPY_TO_WOUT
	ld	hl,IP_TO_SEND
	call	NEW_ARP
	ret
NO_SAME_SUB:

	;--- Search in the routing table

	ld	iy,ROUTE_TABLE
	ld	b,ROUTE_ENTRIES

SRCHROU_LOOP:
	push	bc
	ld	a,(iy)
	or	a
	ld	bc,16
	jr	z,SRCHROU_NXT

	push	iy
	pop	hl
	inc	hl	;HL=Address of routed subnet
	ld	de,IP_TO_SEND	;DE=Destination address
	ld	bc,5
	add	iy,bc
	push	iy
	pop	ix	;IX=Mask
	call	SAME_SUBNET
	ld	bc,11
	jr	nc,SRCHROU_NXT

	pop	bc
	push	iy
	pop	hl
	inc	hl
	inc	hl
	inc	hl
	inc	hl	;HL=Pointer to the destination router

	ld	a,#FF
	ld	(IS_ROUTER),a
	jp	SEND_IP_ETH	;No danger of infinite loop,
	;because now IP is for sure in the same subnet.

SRCHROU_NXT:
	add	iy,bc
	pop	bc
	djnz	SRCHROU_LOOP

	;--- No appropriate entry in routing table.
	;    If there is a default gatway defined, use it.
	;    Otherwise, use local ARP (rely in Proxy-ARP working).

	ld	hl,DEFGW
	ld	de,ZERO32
	call	COMP32
	jr	z,SI_SAME_SUB

	ld	a,#FF
	ld	(IS_ROUTER),a
	ld	hl,DEFGW
	jp	SEND_IP_ETH

	;--- Copy datagram to WOUT_BUFFER to be sent
	;    when ARP entry resolution finishes

COPY_TO_WOUT:	ld	hl,IP_TO_SEND
	ld	de,WOUT_IP
	ld	bc,4
	ldir

	ld	bc,576
	ld	hl,OUT_BUFFER+4
	ld	de,WOUT_BUFFER
	ldir

	ret

IP_TO_SEND:	ds	4
IS_ROUTER:	db	0

	endif


;--- PREPARE_IP: Clear IP header of outgoing datagram,
;    and set source IP, destination IP (L.H.E.D)
;    and protocol (A).

PREPARE_IP:
	push	hl,de,bc

	ld	hl,OUT_BUFFER+4	;Clear header
	ld	de,OUT_BUFFER+5
	ld	bc,19
	ld	(hl),0
	ldir

	ld	hl,BUF_IPLOCAL	;Source IP
	ld	de,OUT_BUFFER+16
	ld	bc,4
	ldir

	pop	bc,de,hl
	ld	(OUT_BUFFER+13),a	;Protocol
	ld	(OUT_BUFFER+20),hl	;Destination IP
	ld	(OUT_BUFFER+22),de

	ret


;--- SEND_UDP: Send an UDP datagram.
;    Input: L.H.E.D = Destination IP
;       	BC = Data length
;       	IX = Source port
;       	IY = Destination port
;           Data in OUT_BUFFER+32

SEND_UDP:
	ld	a,17
	call	PREPARE_IP	;IPs and protocol

	push	ix	;Ports
	pop	hl
	push	iy
	pop	de
	ld	ix,OUT_BUFFER+24
	ld	(ix),h
	ld	(ix+1),l
	ld	(ix+2),d
	ld	(ix+3),e

	ld	hl,8	;Total UDP length
	add	hl,bc
	ld	(ix+4),h
	ld	(ix+5),l

	ld	(ix+6),0	;Checksum
	ld	(ix+7),0
	push	hl,hl
	pop	bc
	ld	(ix-10),b
	ld	(ix-9),c	;UDP length in IP checksum field
	ld	hl,12
	add	hl,bc	;To include pseudo-header
	push	hl
	pop	bc
	ld	ix,OUT_BUFFER+12	;See trick explanation in IS_UDP
	call	CALC_CHKSUM
	ld	(OUT_BUFFER+30),de

	ld	hl,0	;Leave IP checksum to 0 again
	ld	(OUT_BUFFER+14),hl

	pop	bc
	jp	SEND_IP2


	if	LINK=0

	;====================================
	;===  Auxiliary routines for PPP  ===
	;====================================

;--- STATE_UP: Checks XCP_ACKS. If not 3, terminates, if it is 3 continues.
;              If connection state is 1, enter state 2, or 3 if
;              authentication is not required.
;              If state is 3, enters state 4.

STATE_UP:

	;--- If XCP_ACKS is not 3, terminate

	ld	a,(XCP_ACKS)
	cp	3
	ret	nz

	;--- If not in state 1 o 3, terminate

	ld	a,(PPP_STATE)
	cp	1
	jr	z,STATEUP_2
	cp	3
	ret	nz

	ld	a,4
	jr	STATEUP_3

	;--- We must enter state 2 or 3

STATEUP_2:
	ld	a,(AUTH_PROTO)
	and	#80
	xor	#80
	rlca		;A=0 if auth required, 1 if not
	inc	a
	inc	a

	;--- If we must enter state 2 but no user name or
	;    password was provided, close connection with error 7

	cp	3
	jr	z,STATEUP_3

	ld	a,(BUF_PPPUSER)
	ld	b,a
	ld	a,(BUF_PPPASSW)
	or	b
	ld	a,2
	jr	nz,STATEUP_3

	ld	a,7
	ld	(PPP_CLCODE),a
	jp	SEND_TREQ

	;--- Set state and initialize packet sending timers

STATEUP_3:
	ld	(PPP_STATE),a
	cp	4
	ld	hl,60*60
	jr	nz,STATEUP_3_2
	ld	hl,30*60
STATEUP_3_2:
	ld	(XCP_TTIMER),hl
	ld	hl,1
	ld	(XCP_RTIMER),hl

	xor	a
	ld	(XCP_ACKS),a
	ld	(ECHOES_SENT),a

	ret

	endif

	if	LINK=1

	;--- SEND_DHCP: Send a DHCP packet of the type passed in A

SEND_DHCP:

	;--- Common initialization

	ld	hl,OUT_BUFFER+32	;Clear output buffer
	ld	de,OUT_BUFFER+32+1
	ld	bc,576-32-1
	ld	(hl),0
	ldir

	ld	(OUT_BUFFER+274),a	;Set message type

	ld	hl,#0101	;Common header ('op' to 'hops')
	ld	(OUT_BUFFER+32),hl
	ld	hl,#0006
	ld	(OUT_BUFFER+34),hl

	;--- 'xid': in DHCPREQUEST in SELECTING or REQUESTING state,
	;    use the last one received; otherwise, the last one plus one

	ld	b,a
	cp	DHCPREQUEST
	jr	nz,SDHCP_OWNXID

	ld	a,(DHCP_STATE)
	cp	SELECTING
	jr	z,SDHCP_LASTXID
	cp	REQUESTING
	jr	nz,SDHCP_OWNXID

SDHCP_LASTXID:
	ld	a,b
	ld	hl,DHCP_RCVXID
	jr	SDHCP_OKXID

SDHCP_OWNXID:
	ld	a,b
	ld	hl,DHCP_XID
	ld	bc,DHCP_XID
	push	af
	call	INC32
	pop	af
	ld	hl,DHCP_XID

SDHCP_OKXID:
	ld	de,OUT_BUFFER+36
	ld	bc,4
	ldir

	;--- 'secs': in DHCPDECLINE or DHCPRELEASE, 0;
	;    otherwise, DHCP_SECS
	;    'flags': in DHCPDECLINE oi DHCPRELEASE, 0;
	;    otherwise, #8000

	cp	DHCPDECLINE
	jr	z,SDHCP_OKSECS
	cp	DHCPRELEASE
	jr	z,SDHCP_OKSECS

	ld	hl,(DHCP_SECS)
	ld	b,a
	ld	a,h
	ld	h,l
	ld	l,a
	ld	a,b
	ld	(OUT_BUFFER+40),hl

	ld	hl,#0080
	ld	(OUT_BUFFER+42),hl
SDHCP_OKSECS:

	;--- 'ciadr': our own IP address if:
	;    * Packet is DHCPINFORM or DHCPRELEASE
	;    * Packet is DHCPREQUEST in BOUND/RENEW/REBIND state

	cp	DHCPINFORM
	jr	z,SDHCP_DOCIADR
	cp	DHCPRELEASE
	jr	z,SDHCP_DOCIADR
	cp	DHCPREQUEST
	jr	nz,SDHCP_OKCIADR

	ld	b,a
	ld	a,(DHCP_STATE)
	cp	BOUND
	jr	z,SDHCP_DOCIADR
	cp	RENEWING
	jr	z,SDHCP_DOCIADR
	cp	REBINDING
	ld	a,b
	jr	nz,SDHCP_OKCIADR

SDHCP_DOCIADR:
	ld	a,b
	ld	hl,BUF_IPLOCAL
	ld	de,OUT_BUFFER+44
	ld	bc,4
	ldir
SDHCP_OKCIADR:

	;--- 'chaddr': MAC address

	ld	hl,HWAD
	ld	de,OUT_BUFFER+60
	ld	bc,6
	ldir

	;--- Options: first, magic cookie and "message type" option

	ld	hl,DHCP_COOKIE
	ld	de,OUT_BUFFER+268
	ld	bc,6
	ldir

	;--- Other options: according to message type and DHCP_VECT

	ld	ix,OUT_BUFFER+275	;Pointer to add options

	;* 'Requested IP': include it if message is DHCPDECLINE,
	;  or if it is DHCPREQUEST in SELECTING or REQUESTING state.
	;  'Server identifier': As previous one, but also
	;  if message is DHCPRELEASE.

	cp	DHCPRELEASE
	jr	z,SDHCP_DOSRVID
	cp	DHCPDECLINE
	jr	z,SDHCP_DOREQIP
	cp	DHCPREQUEST
	jr	nz,SDHCP_OKREQIP

	ld	b,a
	ld	a,(DHCP_STATE)
	cp	SELECTING
	jr	z,SDHCP_DOREQIP
	cp	REQUESTING
	ld	a,b
	jr	nz,SDHCP_OKREQIP

SDHCP_DOREQIP:
	ld	a,b
	ld	(ix),50
	ld	(ix+1),4
	push	ix
	pop	de
	inc	de
	inc	de
	ld	hl,DHCP_YIADDR
	ld	bc,4
	ldir
	push	de
	pop	ix

SDHCP_DOSRVID:
	ld	(ix),54
	ld	(ix+1),4
	push	ix
	pop	de
	inc	de
	inc	de
	ld	hl,DHCP_SERVER
	ld	bc,4
	ldir
	push	de
	pop	ix
SDHCP_OKREQIP:

	;* 'Parameter request': if not DHCPDECLINE nor DHCPRELEASE,
	;  and according to DHCP_VECT.
	;  'Maximum message size': if not DHCPDECLINE nor DHCPRELEASE.

	cp	DHCPRELEASE
	jr	z,SDHCP_OKREQOPS
	cp	DHCPDECLINE
	jr	z,SDHCP_OKREQOPS

	ld	(ix),57	;"Maximum message size"
	ld	(ix+1),2
	ld	(ix+2),#02
	ld	(ix+3),#40
	inc	ix
	inc	ix
	inc	ix
	inc	ix

	ld	(ix),55	;"Parameter request list"
	inc	ix
	push	ix
	pop	hl
	inc	ix
	ld	b,0	;Accumulated option length
	ld	a,(DHCP_VECT)

	;Subnet mask

	bit	1,a
	jr	z,SDHCP_OKOPMASK

	ld	(ix),1
	inc	b
	inc	ix
SDHCP_OKOPMASK:

	;Default gateway

	bit	2,a
	jr	z,SDHCP_OKOPROU

	ld	(ix),3
	inc	b
	inc	ix
SDHCP_OKOPROU:

	;DNS servers

	bit	3,a
	jr	z,SDHCP_OKOPDNS

	ld	(ix),6
	inc	b
	inc	ix
SDHCP_OKOPDNS:

	;Timeout ARP

	bit	4,a
	jr	z,SDHCP_OKARP

	ld	(ix),35
	inc	b
	inc	ix
SDHCP_OKARP:

	;Ethernet frame type

	bit	5,a
	jr	z,SDHCP_OKFRM

	ld	(ix),36
	inc	b
	inc	ix
SDHCP_OKFRM:

	;Set option length

	ld	(hl),b
SDHCP_OKREQOPS:

	;--- Packet is complete: calculate resulting size

	push	ix
	pop	hl
	ld	bc,OUT_BUFFER+32
	or	a
	sbc	hl,bc
	push	hl
	pop	bc

	;--- Destination IP address: if DHCP_SERVER is 0,
	;    or if packet is DHCPREQUEST in REQUESTING or REBINDING state,
	;    send to broadcast; otherwise, to the appropriate address

	ld	a,(OUT_BUFFER+274)
	cp	DHCPREQUEST
	jr	nz,SDHCP_OKIPDEST

	ld	hl,#FFFF
	ld	de,#FFFF
	ld	a,(DHCP_STATE)
	cp	REBINDING
	jr	z,SDHCP_OKSNDIP
	cp	REQUESTING
	jr	z,SDHCP_OKSNDIP

SDHCP_OKIPDEST:
	ld	hl,(DHCP_SERVER)
	ld	de,(DHCP_SERVER+2)
	ld	a,h
	or	l
	or	d
	or	e
	jr	nz,SDHCP_OKSNDIP

	dec	hl	;HL,DE=#FFFF (255.255.255.255)
	dec	de
SDHCP_OKSNDIP:

	;--- End: send UDP packet using the appropriate ports

	ld	ix,68
	ld	iy,67
	jp	SEND_UDP

DHCP_COOKIE:	db	99,130,83,99,53,1	;Includes "message type" option


	;=========================================
	;===  Auxiliary routines for Ethernet  ===
	;=========================================

;--- SRCH_ARP: Search an entry in the ARP table for the given IP address
;    Input:  DE = Pointer to IP address
;    Output: IX = ARP entry address
;            Cy=1 if no matching entry found
;    Modifies AF, BC, DE, HL, IX

SRCH_ARP:
	ld	ix,ARP_CACHE
	ld	b,ARP_ENTRIES
SRCH_ARP_LOOP:
	push	bc

	;* Empty entry?

	ld	a,(ix)
	or	a
	jr	z,SRCH_ARP_NXT

	;* IP matches?

	push	ix
	pop	hl
	ld	bc,7
	add	hl,bc
	push	de
	call	COMP32
	pop	de
	jr	nz,SRCH_ARP_NXT

	;* Entry found

	pop	bc
	or	a
	ret

	;* Next entry, if any

SRCH_ARP_NXT:
	ld	bc,16
	add	ix,bc
	pop	bc
	djnz	SRCH_ARP_LOOP

	scf		;Not found
	ret


;--- SAME_SUBNET: Check if two IPs are in the same subnet.
;    Input:  DE,HL = IPs to check
;            IX = Subnet mask
;    Output: Cy=1 if same subnet, 0 if not.
;    Modifies AF, BC, DE, HL, IX

SAME_SUBNET:
	ld	b,4

SAME_SUBLOOP:
	ld	a,(hl)
	and	(ix)
	ld	c,a
	ld	a,(de)
	and	(ix)
	cp	c
	scf
	ccf
	ret	nz
	inc	hl
	inc	de
	inc	ix
	djnz	SAME_SUBLOOP
	scf
	ret


;--- GET_FREE_ARP: Obtain a free ARP entry
;    Output: IX = Entry address

GET_FREE_ARP:

	;--- First search an empty entry

	ld	ix,ARP_CACHE
	ld	b,ARP_ENTRIES
FREARP_LOP1:
	ld	a,(ix)
	or	a
	jr	z,FREARP_FOUND

	ld	de,16
	add	ix,de
	djnz	FREARP_LOP1

	;--- No empty entries:
	;    Search the dynamic entry closer to expiration.

	ld	hl,#7F
	ld	(FREARP_TIMER),hl
	ld	hl,#FF
	ld	(FREARP_TIMER+2),hl
	ld	hl,0
	ld	(FREARP_DIR),hl
	ld	ix,ARP_CACHE
	ld	b,ARP_ENTRIES
FREARP_LOP2:	push	bc

	;* Check that it is a dynamic entry inuse

	ld	a,(ix)
	cp	2
	jr	nz,FREARP_NXT2

	;* Compare last timer with the current timer,
	;  if current has smaller value, put its pointer at FREARP_DIR

	push	ix
	pop	hl
	ld	bc,11
	add	hl,bc
	ld	de,FREARP_TIMER
	push	hl
	call	COMP32	;NC if (HL)<(DE)
	pop	hl
	jr	c,FREARP_NXT2

	ld	de,FREARP_TIMER
	ld	bc,4
	ldir
	ld	(FREARP_DIR),ix

FREARP_NXT2:	ld	bc,16
	add	ix,bc
	pop	bc
	djnz	FREARP_LOP2

	;* If none found, return the last entry in the table

	ld	ix,(FREARP_DIR)
	ld	a,ixh
	or	ixl
	jr	nz,FREARP_FOUND

	ld	ix,ARP_CACHE+16*(ARP_ENTRIES-1)
	ret

	;* Entry found

FREARP_FOUND:
	ld	(ix),0
	ret

FREARP_DIR:	ds	2
FREARP_TIMER:	ds	4


;--- NEW_ARP: Create a new ARP entry for a given IP address,
;             and send the first ARP request packet.
;    Input: HL = IP address to be resolved

NEW_ARP:
	push	hl

	;--- First search an empty entry

	call	GET_FREE_ARP

	;--- Create the new entry and send first request

	pop	iy
	ld	(ix),3
	;ld	(ix+1),0
	;ld	(ix+2),0
	;ld	(ix+3),0
	;ld	(ix+4),0
	;ld	(ix+5),0
	;ld	(ix+6),0
	ld	(ix+11),4*60
	ld	(ix+12),1
	ld	l,(iy)
	ld	h,(iy+1)
	ld	e,(iy+2)
	ld	d,(iy+3)
	ld	(ix+7),l
	ld	(ix+8),h
	ld	(ix+9),e
	ld	(ix+10),d

	jp	SEND_ARP_RQ


	;=====================================
	;===  Auxiliary routines for DHCP  ===
	;=====================================

;--- DHCP_DO_INIT: Initialize automaton in INIT state

DHCP_DO_INIT:
	call	CLOSE_ALL_TCP

	;* Clear all DHCP variables except XID

	ld	hl,DHCP_VAR_START+4
	ld	de,DHCP_VAR_START+4+1
	ld	bc,DHCP_VAR_END-DHCP_VAR_START-4-1
	ld	(hl),0
	ldir
	xor	a
	ld	(DHCP_STATE),a
	ld	(DHCP_VECT_O),a

	;* Clear appropriate IP addresses, depending on DHCP_VECT

	ld	a,(DHCP_VECT)
	ld	hl,0

	bit	0,a
	jr	z,DHCP2INIT_1
	ld	(BUF_IPLOCAL),hl
	ld	(BUF_IPLOCAL+2),hl
DHCP2INIT_1:

	bit	1,a
	jr	z,DHCP2INIT_2
	ld	(SUBNET_MASK),hl
	ld	(SUBNET_MASK+2),hl
DHCP2INIT_2:

	bit	2,a
	jr	z,DHCP2INIT_3
	ld	(DEFGW),hl
	ld	(DEFGW+2),hl
DHCP2INIT_3:

	bit	3,a
	jr	z,DHCP2INIT_4
	ld	(BUF_IPDNS1),hl
	ld	(BUF_IPDNS1+2),hl
	ld	(BUF_IPDNS2),hl
	ld	(BUF_IPDNS2+2),hl
DHCP2INIT_4:

	bit	4,a
	jr	z,DHCP2INIT_5
	ld	hl,ARP_TOUT_DEF
	ld	de,ARP_TOUT
	ld	bc,4
	ldir
	ld	hl,ARP_TOUT_DEF2
	ld	de,ARP_TOUT_SECS
	ld	bc,4
	ldir
DHCP2INIT_5:

	bit	5,a
	jr	z,DHCP2INIT_6
	ld	b,a
	xor	a
	ld	(FRAME_TYPE),a
	ld	a,b
DHCP2INIT_6:

	ret

ARP_TOUT_DEF:	db	#00,#00,#46,#50	;5 minutes * 60 secs * 60 ints
ARP_TOUT_DEF2:	db	#00,#00,#01,#2C	;5 minutes * 60 secs


;--- DHCP_NEXT_OP: Return next DHCP option in this way:
;    A  = Code (0=no more options available)
;    B  = Length
;    IX = Pointer to option data
;    Takes in account "option overload".
;    Must be initialized with DHCP_INIT_OP.

DHCP_INIT_OP:
	xor	a
	ld	(DHCP_OP_OVL),a
	ld	ix,IN_BUFFER+272	;'options' field after cookie
	ld	(DHCP_OP_PNT),ix
	ret

DHCP_NEXT_OP:
	ld	ix,(DHCP_OP_PNT)
DHCPNO_LOOP:
	ld	(DHCP_OP_PNT),ix
	ld	a,(ix)
	inc	ix	;Now IX points to length (if op is not 0 or 255)

	;* Option 0: Pad

	or	a
	jr	z,DHCPNO_LOOP

	;* Option 255: end, jump to 'file' or 'sname' if necessary

	cp	255
	jr	nz,DHCPNO_NOEND

	ld	a,(DHCP_OP_OVL)
	ld	b,a
	or	a
	ld	a,0
	ret	z
	ld	a,b

	bit	0,a
	jr	z,DHCPNO_NOFILE
	and	%10
	ld	(DHCP_OP_OVL),a
	ld	ix,IN_BUFFER+140	;'file' field
	jr	DHCPNO_LOOP
DHCPNO_NOFILE:

	xor	a
	ld	(DHCP_OP_OVL),a
	ld	ix,IN_BUFFER+76	;'sname' field
	jr	DHCPNO_LOOP
DHCPNO_NOEND:

	;* Option 52 (overload): save option and continue

	cp	52
	jr	nz,DHCPNO_NOOVL

	ld	a,(ix+1)
	and	%11
	ld	(DHCP_OP_OVL),a
	inc	ix
	inc	ix
	jr	DHCPNO_LOOP
DHCPNO_NOOVL:

	;* Other option: return it and update pointer

	ld	a,(ix-1)
	ld	b,(ix)
	inc	ix	;Now it points to option data
	push	ix,bc
DHCPNO_NXT:	inc	ix
	djnz	DHCPNO_NXT
	ld	(DHCP_OP_PNT),ix
	pop	bc,ix

	ret

DHCP_OP_OVL:	db	0	;"Option overload" option found
DHCP_OP_PNT:	dw	0	;Pointer to next option


;--- DHCP_GET_TYPE: Returns in A the code of the received message,
;    or 0 if it has no code.

DHCP_GET_TYPE:
	call	DHCP_INIT_OP
DHCP_GT_LOOP:
	call	DHCP_NEXT_OP
	or	a
	ret	z
	cp	53
	jr	nz,DHCP_GT_LOOP
	ld	a,(ix)
	ret


;--- DHCP_GET_SERVER: Returns in HL a pointer to the 'Server id' option,
;    or Cy=1 if this option is not found

DHCP_GET_SERVER:
	call	DHCP_INIT_OP
DHCP_GS_LOOP:
	call	DHCP_NEXT_OP
	or	a
	scf
	ret	z
	cp	54
	jr	nz,DHCP_GS_LOOP
	push	ix
	pop	hl
	or	a
	ret


;--- DHCP_FIRST: Must be called when a packet is send for the
;    first time after a state change

DHCP_FIRST:
	ld	a,1
	ld	(DHCP_TRIES),a
	ld	a,3*60
	ld	(DHCP_SNDTIM),a
	ret

	endif


	;====================================
	;===  Auxiliary routines for TCP  ===
	;====================================

;--- SRCH_TCP_INBUF: Search the TCP connection associated
;    to the packet at IN_BUFFER

SRCH_TCP_INBUF:
	ld	hl,(IN_BUFFER+16)
	ld	de,(IN_BUFFER+18)
	ld	a,(IN_BUFFER+24)
	ld	ixh,a
	ld	a,(IN_BUFFER+25)
	ld	ixl,a
	ld	a,(IN_BUFFER+26)
	ld	iyh,a
	ld	a,(IN_BUFFER+27)
	ld	iyl,a

;--- SEARCH_TCP: Search an open connection with the given
;    remote IP and ports.
;    Input:   L.H.E.D = Remote IP
;             IX = Remote port
;             IY = Local port
;    Output:  A = Connection number, 0 to 3 (#FF if not found)
;    Modifies: HL, DE, BC

SEARCH_TCP:
	ld	(STCP_TEMP),hl	;Save parameters
	ld	(STCP_TEMP+2),de	;in a temporary zone
	ld	(STCP_TEMP+4),ix
	ld	(STCP_TEMP+6),iy

	ld	hl,TCBS+TCB_SIZE*3
	ld	b,4

	;Loop for all 4 connections

STCP_LOOP:
	ld	a,(hl)	;Connection is open?
	or	a
	inc	hl
	jr	z,STCP_NEXT

	push	hl,bc
	ld	de,STCP_TEMP
	call	COMP32
	pop	bc,hl
	jr	nz,STCP_NEXT

	push	hl,bc
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	de,STCP_TEMP+4
	call	COMP32
	pop	bc,hl
	jr	nz,STCP_NEXT

	ld	a,b	;Connection found
	dec	a
	ret

	;Next connection, if any

STCP_NEXT:
	dec	hl
	ld	de,TCB_SIZE
	or	a
	sbc	hl,de
	djnz	STCP_LOOP
	ld	a,#FF	;If this point is reached, no more connections available
	ret

STCP_TEMP:	ds	8


;--- SEARCH_LISTEN: Search a TCP connection in LISTEN state
;    with unespecified remote socket
;    Input:  -
;    Output: A = Connection, 0 a 3 (#FF if not found)
;    Modifies: AF, BC, DE, HL

SEARCH_LISTEN:
	ld	hl,TCBS+TCB_SIZE*3
	ld	b,4

SLST_LOOP:	ld	a,(hl)
	cp	LISTEN
	jr	nz,SLST_NEXT

	push	hl,bc
	inc	hl
	ld	de,ZERO32
	call	COMP32
	pop	bc,hl
	jr	nz,SLST_NEXT

	ld	a,b	;Connection found
	dec	a
	ret

	;Next connection, if any

SLST_NEXT:	ld	de,TCB_SIZE
	or	a
	sbc	hl,de
	djnz	SLST_LOOP
	ld	a,#FF	;If this point is reached, no more connections available
	ret

ZERO32:	db	0,0,0,0


;--- SEARCH_FRTCP: Search a free TCP connection (in CLOSED state)
;    Input:  -
;    Output: A = Connection, 0 to 3 (#FF if not found)
;    Modifies: AF, HL,  DE,BC

SEARCH_FRTCP:
	ld	a,(TCBS)
	or	a
	ret	z

	ld	a,(TCBS+TCB_SIZE)
	or	a
	ld	a,1
	ret	z

	ld	a,(TCBS+2*TCB_SIZE)
	or	a
	ld	a,2
	ret	z

	ld	a,(TCBS+3*TCB_SIZE)
	or	a
	ld	a,3
	ret	z

	ld	a,#FF
	ret


;--- LOAD_TCB: Loads the specified TCB in TCB_TEMP
;    Input:  A = TCB number (0 to 3)
;    Modifies: AF, BC, DE, HL

LOAD_TCB:
	ld	(CURTCB_NUM),a
	call	GET_TCB_DIR
	ld	de,TCB_TEMP
	ld	bc,TCB_SIZE
	ldir
	ret


;--- SAVE_TCB: Saves TCB_TEMP to TCB specified in CURTCB_NUM
;    Input:  -
;    Output: -
;    Modifies: AF, BC, DE, HL

SAVE_TCB:
	ld	a,(CURTCB_NUM)
	call	GET_TCB_DIR
	ex	de,hl
	ld	hl,TCB_TEMP
	ld	bc,TCB_SIZE
	ldir
	ret


;--- GET_TCB_DIR: Obtain in HL the TCB address for connection A
;    Modifies: AF, DE

;* If real size TCBs are used:

GET_TCB_DIR:	ld	hl,TCBS
	ld	de,TCB_SIZE
	inc	a
GET_TCB_DLOOP:	dec	a
	ret	z
	add	hl,de
	jr	GET_TCB_DLOOP

;* If 256 byte TCBs are used:

;GET_TCB_DIR:    ld      hl,TCBS
;        add     h
;        ld      h,a
;        ret


;--- TCP_IS_ZERO: Check if currrent TCB's IP is 0.0.0.0
;    Input:  -
;    Output: Z=1 if REMOTE_IP is 0.0.0.0
;    Modifies: AF,HL,DE

TCP_IS_ZERO:
	ld	hl,(REMOTE_IP)
	ld	de,(REMOTE_IP+2)
	ld	a,h
	or	l
	or	d
	or	e
	ret

;--- SET_TCP_PORTS: Returns remote IP in L.H.E.D,
;    local port en IY, and remote port en IX

SET_TCP_PORTS:
	ld	ix,(REMOTE_PORT)
	ld	iy,(LOCAL_PORT)
	ld	hl,(REMOTE_IP)
	ld	de,(REMOTE_IP+2)
	ret


;--- SEND_SEGMENT: Send a TCP segment.
;    Assumes TCP header already composed at OUT_BUFER+24 (Seq, Ack and flags),
;    and data already copied to OUT_BUFER+44.
;    Input: L.H.E.D = Destination IP
;           IX = Remote port
;           IY = Local port
;           BC = Data length

SEND_SEGMENT:
	ld	a,6
	call	PREPARE_IP	;IPs and protocol

	push	ix,iy
	pop	de,hl
	ld	ix,OUT_BUFFER	;IX=TCP header
	ld	(ix+24),d	;Local port
	ld	(ix+25),e
	ld	(ix+26),h	;Remote port
	ld	(ix+27),l
	ld	(ix+36),#50	;Data Offset
	ld	(ix+40),0	;Checksum
	ld	(ix+41),0
	ld	(ix+42),0	;Urgent Pointer
	ld	(ix+43),0

	call	CALC_RCV_WIN
SMALL_WIN:
	ld	(ix+38),h
	ld	(ix+39),l
	ld	(LAST_WIN_SENT),hl

	ld	hl,20
	add	hl,bc	;Total TCP length

	;* If it has SYN, MSS option at the end
	;  (notese that a SYN segment has never data)

	ld	a,(ix+37)
	and	%10
	jr	z,NO_PUT_MSS

	ld	hl,MSS_DATA
	ld	de,OUT_BUFFER+44
	ld	bc,4
	ldir
	ld	hl,24	;New TCP size
	ld	(ix+36),#60	;New header length
NO_PUT_MSS:

	push	hl,hl
	pop	bc
	ld	(ix+14),b
	ld	(ix+15),c	;TCP length in IP checksum field
	ld	hl,12
	add	hl,bc	;To include pseudo-header
	push	hl
	pop	bc
	ld	ix,OUT_BUFFER+12	;See trick explanation in IS_UDP
	call	CALC_CHKSUM
	ld	(OUT_BUFFER+40),de

	ld	hl,0	;Set IP checksum to 0 again
	ld	(OUT_BUFFER+14),hl

	pop	bc
	jp	SEND_IP2

	;MSS option:
	;For serial version, announce 512-64, otherwise
	;some data could be lost when various packets
	;are received at the same time
	;(RS232 buffer is 512 bytes long)

	if	LINK=0

MSS_DATA:	db	2,4,1,#C0	;Option MSS=448 (Cod=2, Tam=4, MSS=#01C0)

	endif

	if	LINK=1

MSS_DATA:	db	2,4,2,#00	;Option MSS=512 (Cod=2, Tam=4, MSS=#0200)

	endif


;--- SEND_SYN: Send a TCP datagram with SYN.
;    Input: A=#02 for SYN of type <SEQ=ISS><CTL=SYN>
;           A=#12 for SYN of type <SEQ=ISS><ACK=RCV.NXT><CTL=SYN,ACK>

SEND_SYN:
	push	af

	ld	hl,ISS	;Set sequence number
	ld	de,OUT_BUFFER+28
	ld	bc,4
	ldir

	ld	hl,RCV_NXT	;Set ACK number
	ld	de,OUT_BUFFER+32
	ld	bc,4
	ldir

	pop	af	;Set control flags
	ld	(OUT_BUFFER+37),a

	ld	a,(SYN_SENT_FLAG)
	or	a
	jr	nz,ES_SYN_RETX
	ld	a,#FF	;Update TCB if not a retransmission
	ld	(SYN_SENT_FLAG),a
	ld	hl,(USER_TOUT_V)
	ld	(USER_TOUT),hl
ES_SYN_RETX:

	call	SET_TCP_PORTS	;Ports and IP
	ld	bc,0
	jp	SEND_SEGMENT


;--- SEND_RST: Send a TCP datagram with RST.
;    Input: A=0 for RST of type <SEQ=SND.NXT><CTL=RST>
;           A=1 for SYN of type <SEQ=0><ACK=SEG.SEQ+SEG.LEN><CTL=RST,ACK>
;           A=2 for SYN of type <SEQ=SEG.ACK><CTL=RST>

SEND_RST:
	or	a
	jr	z,SEND_RST0
	dec	a
	jr	z,SEND_RST1

	;>>> Form 2: <SEQ=SEG.ACK><CTL=RST>

SEND_RST2:
	ld	hl,IN_BUFFER+32	;Set sequence number
	ld	de,OUT_BUFFER+28
	ld	bc,4
	ldir

	ld	a,%100	;Set control flags
	ld	(OUT_BUFFER+37),a

	jr	SEND_RST_X

	;>>> Form 1: <SEQ=0><ACK=SEG.SEQ+SEG.LEN><CTL=RST,ACK>

SEND_RST1:	ld	hl,ZERO32	;Sequence number
	ld	de,OUT_BUFFER+28
	ld	bc,4
	ldir

	call	GET_SEG_LEN	;ACK number
	ex	de,hl
	ld	hl,IN_BUFFER+28
	ld	bc,OUT_BUFFER+32
	call	ADD3216

	ld	a,%10100	;Control
	ld	(OUT_BUFFER+37),a

SEND_RST_X:
	ld	hl,(IN_BUFFER+16)	;Ports and IP from incoming segment
	ld	de,(IN_BUFFER+18)
	ld	a,(IN_BUFFER+24)
	ld	ixh,a
	ld	a,(IN_BUFFER+25)
	ld	ixl,a
	ld	a,(IN_BUFFER+26)
	ld	iyh,a
	ld	a,(IN_BUFFER+27)
	ld	iyl,a
	ld	bc,0
	jp	SEND_SEGMENT

	;>>> Form 0: <SEQ=SND.NXT><CTL=RST>

SEND_RST0:	ld	hl,SND_NXT	;Sequence number
	ld	de,OUT_BUFFER+28
	ld	bc,4
	ldir

	ld	a,%100	;Set control flags
	ld	(OUT_BUFFER+37),a

	call	SET_TCP_PORTS	;Ports and IP from current connection
	jp	SEND_SEGMENT


;--- SEND_DATA: Send a segment of type <SEQ=SND.NXT><ACK=RCV.NXT><CTL=ACK>
;    with IP and ports of current TCB.
;    Input: BC=Data length (already copied to OUT_BUFFER+44)
;           A=0 for normal data
;             8 for PUSH
;             1 for FIN
;             9 for PUSH+FIN
;    SEND_ACK does not send data.

SEND_ACK:
	ld	bc,0
	xor	a

SEND_DATA:
	push	bc,af,bc	;Set sequence number
	ld	hl,SND_UNA
	ld	de,OUT_BUFFER+28
	ld	bc,4
	ldir

	pop	bc
	ld	a,b
	or	c
	jr	nz,SNDDATA_2

	ld	de,(RETX_SIZE)
	ld	hl,OUT_BUFFER+28
	ld	bc,OUT_BUFFER+28
	call	ADD3216
SNDDATA_2:

	ld	hl,RCV_NXT	;Set ACK number
	ld	de,OUT_BUFFER+32
	ld	bc,4
	ldir

	pop	af
	or	%10000	;Set ACK flag
	ld	(OUT_BUFFER+37),a

	pop	de	;Actualiza SND_NXT
	push	de
	bit	0,a
	jr	z,SEND_NO_FIN
	inc	de	;FIN has sequence number
	ld	a,#FF
	ld	(FIN_SENT_FLAG),a
SEND_NO_FIN:	ld	hl,SND_UNA
	ld	bc,SND_NXT
	call	ADD3216

	call	SET_TCP_PORTS
	pop	bc
	call	SEND_SEGMENT

	ld	hl,0
	ld	(ACK_RCV_NUM),hl
	xor	a
	ld	(ACK_DELAY_T),a
	ld	(ACK_PENDING),a
	ret


;--- GET_SEG_LEN: Obtain the length of data part of incoming segment
;    Input: Segmentt in IN_BUFFER
;    Output:  HL = Length including SYN and FIN
;             BC = Length of data only

GET_SEG_LEN:
	ld	hl,(IN_BUFFER+6)
	push	hl
	pop	bc
	ld	a,(IN_BUFFER+37)	;%xxxxxxSF
	and	%11
	ret	z	;%00: Return HL=BC
	inc	hl
	cp	%11	;%01 o %10: Return HL=BC+1
	ret	nz
	inc	hl	;%11: Return HL=BC+2
	ret


;--- CALC_RCV_WIN: Returns in HL the receive window to announce
;    - If state is before ESTABLISHED, return 1.
;    - If INBUF_FREE is >512, return 512.
;    - If INBUF_FREE is <128, return INBUF_FREE.
;    - Otherwise, return INBUF_FREE
;      rounded down to a multiple of 128.

CALC_RCV_WIN:
	ld	hl,(INBUF_FREE)
	ld	de,128
	call	COMP
	ld	a,l
	jr	nc,GETRCVW_2
	and	%10000000
	ld	l,a
GETRCVW_2:

	ret


;--- CHK_TCP_EXIST: Check that a TCP connection exists
;                   and is not closed
;    Input:  A = Connection number
;    Output: Cy=1 and
;            A = 1 if connection number is invalid (>3)
;                2 if specified connection is closed
;            Cy=0 and A=0 if connection exists and is open
;    Modifies: HL

CHK_TCP_EXIST:
	ld	h,a

	;--- Check connection number

	and	%11111100
	ld	a,1
	scf
	ret	nz
	ld	a,h

	;--- Check connection state

	push	de
	call	GET_TCB_DIR
	pop	de
	ld	a,(hl)
	or	a
	ld	a,2
	scf
	ret	z

	;--- No error condition

	xor	a
	ret


;--- SET_WNDWL: Updates SND_WND and SND_WL1/2

SET_WNDWL:
	ld	hl,(IN_BUFFER+38)
	ld	(SND_WND),hl

	ld	hl,IN_BUFFER+28
	ld	de,SND_WL1
	ld	bc,4
	ldir

	ld	hl,IN_BUFFER+32
	ld	de,SND_WL2
	ld	bc,4
	ldir

	ret


;--- RET_LISTEN: If current connection is in SYN-RECEIVED state
;    and it was passive, return to LISTEN and return Cy=1.
;    Otherwise, return Cy=0.

RET_LISTEN:
	ld	a,(TCP_STATE)
	cp	SYN.RECEIVED
	scf
	ccf
	ret	nz

	ld	a,(PASSIVE_OPEN)
	or	a
	ret	z

	ld	a,LISTEN
	ld	(TCP_STATE),a
	scf
	ret


;--- CHECK_SEQ: Check validity of sequence number of the incoming packet.
;    If es valid, return Cy=1.
;    Otherwise, send ACK and return Cy=0.

CHECK_SEQ:

	;--- Segment is valid if SEG_SEQ=RCV_NXT
	;    and also SEG_LEN<=RCV_WND.

	ld	hl,IN_BUFFER+28
	ld	de,RCV_NXT
	call	COMP_SEQ
	jr	nz,TCP_BAD_SEQ

	ld	de,(IN_BUFFER+6)
	ld	hl,(INBUF_FREE)
	call	COMP
	ret	c

	;If not valid, send ACK (unless it has RST)
	;and terminate

TCP_BAD_SEQ:
	ld	a,(IN_BUFFER+37)
	and	%100
	ret	z
	call	SCHEDULE_ACK
	or	a
	ret


;--- SCHEDULE_ACK: Schedules a delayed ACK
;                  even if no pending data is available

SCHEDULE_ACK:
	ld	hl,(ACK_RCV_NUM)
	ld	a,h
	or	l
	ret	nz
	ld	a,#FF
	ld	(ACK_PENDING),a
	ld	a,ACK_DELAY_V
	ld	(ACK_DELAY_T),a
	ret


;--- PROCESS_ACK: Process ACK of incoming segment.
;    Returns Cy=1 if segment processing must continue,
;    Cy=0 otherwise.

PROCESS_ACK:

	;--- If SND.UNA =< SEG.ACK =< SND.NXT, update window

	ld	hl,SND_UNA
	ld	bc,IN_BUFFER+32
	ld	de,SND_NXT
	call	RANGE32
	jr	nc,PROC_ACK_2

	ld	hl,SND_WL1	;Update if SND.WL1 < SEG.SEQ...
	ld	de,IN_BUFFER+28
	call	COMP_SEQ
	jr	nc,PROC_ACK_UW

	jr	nz,PROC_ACK_2	;...or if (SND.WL1 = SEG.SEQ...
	ld	de,IN_BUFFER+32
	ld	hl,SND_WL2
	call	COMP_SEQ	;... and SND.WL2 <= SEG.ACK)
	jr	z,PROC_ACK_UW
	jr	c,PROC_ACK_2

PROC_ACK_UW:
	call	SET_WNDWL
PROC_ACK_2:

	;--- If SEG_ACK>SND_NXT, send ACK
	;    and ignore segment

	ld	a,(SYN_SENT_FLAG)
	ld	b,a
	ld	a,(FIN_SENT_FLAG)
	or	b
	ld	hl,SND_NXT
	jr	nz,PROC_ACK_20

	ld	hl,SND_UNA
	ld	de,(RETX_SIZE)
	ld	bc,TEMP32_1
	call	ADD3216
	ld	hl,TEMP32_1

PROC_ACK_20:
	ld	de,IN_BUFFER+32
	call	COMP_SEQ
	jr	c,PROC_ACK_3

	call	SCHEDULE_ACK
	or	a
	ret
PROC_ACK_3:

	;--- If SEG_ACK<=SND_UNA, ignore ACK

	ld	hl,SND_UNA	;Check if SND_UNA>=SND_ACK
	ld	de,IN_BUFFER+32
	call	COMP_SEQ
	ret	c

	;--- If we reach here, SND.UNA < SEG.ACK =< SND.NXT

	;If FIN was sento, it is already ACKed: set
	;FIN_SENT_FLAG to 0 and terminate
	;(since no more data was pending ACK)

	ld	a,(FIN_SENT_FLAG)
	or	a
	jr	z,PROC_ACK_4

	xor	a
	ld	(FIN_SENT_FLAG),a
	jr	PROC_ACK_END
PROC_ACK_4:

	;We must extract SEG.ACK-SND.UNA from ReTx queue

	ld	de,IN_BUFFER+32
	ld	hl,SND_UNA
	ld	bc,TEMP32_1
	call	SUB32

	ld	a,(TEMP32_1+2)
	ld	h,a
	ld	a,(TEMP32_1+3)
	ld	l,a
	or	h
	jr	z,PROC_ACK_END

	ld	a,(TEMP32_1)
	and	%10000000
	jr	z,PROC_ACK_5
	ex	de,hl
	ld	hl,0
	or	a
	sbc	hl,de	;HL = Bytes to extract
PROC_ACK_5:
	ld	a,h
	or	l
	jr	z,PROC_ACK_END

	ld	ix,OUTBUF
	ld	de,OUT_BUFFER
	push	hl,hl
	pop	bc
	call	RBUF_EXTRACT

	pop	bc
	ld	hl,(RETX_SIZE)
	or	a
	sbc	hl,bc
	ld	(RETX_SIZE),hl

	;Decrease pending PUSH bytes counter

	ld	hl,(SEND_PUSH_PEND)
	or	a
	sbc	hl,bc
	bit	7,h	;If substraction gives a negative number, use 0
	jr	z,NO_PUSH_NEG
	ld	hl,0
NO_PUSH_NEG:
	ld	(SEND_PUSH_PEND),hl

	;Reset non-PUSH data sending timer

	ld	hl,SEND_TOUT_V	;0.5 seconds
	ld	(SEND_TOUT),hl

	;Update SND_UNA and terminate

PROC_ACK_END:
	ld	hl,IN_BUFFER+32
	ld	de,SND_UNA
	ld	bc,4
	ldir

	scf
	ret


;--- CLOSE_ALL_TCP: Close all open TCP connections
;    with error 6 (internet connection lost)

CLOSE_ALL_TCP:
	push	hl,de,bc
	xor	a
CLOSE_TCP_LOOP:
	push	af
	call	LOAD_TCB
	ld	a,(TCP_STATE)
	or	a
	jr	z,NEXT_TCP
	xor	a
	ld	(TCP_STATE),a
	ld	a,6
	ld	(LAST_CLOSE),a
	call	SAVE_TCB
NEXT_TCP:
	pop	af
	inc	a
	cp	4
	jr	c,CLOSE_TCP_LOOP
	pop	bc,de,hl
	xor	a
	ret


	;===========================================
	;===  Routines to manage 32 bit numbers  ===
	;===========================================

;--- COMP32: Compare two 32 bit numbers, modulo 2^32,
;            stored in big-endian
;    Input: HL = Pointer al primer numero
;             DE = Pointer al segundo numero
;    Output:     C, NZ if (HL) > (DE)
;                C,  Z if (HL) = (DE)
;               NC, NZ if (HL) < (DE)
;    Modifies: HL, DE, AF, HL', DE', AF'

;COMP32 is part of COMP_SEQ


;--- COMP_SEQ: Compare two 32 bit numbers, modulo 2^32,
;              stored in big-endian; assumes that
;              they are TCP sequence numbers
;    Input:  HL = Pointer to first number
;            DE = Pointer to second number
;    Output:  C, NZ if (HL) > (DE)
;             C,  Z if (HL) = (DE)
;            NC, NZ if (HL) < (DE)
;    Modifies: HL, DE, AF, HL', DE', AF'

;The 32 bit addressing space is divided in 3 zones:
;A: &H00000000 - &H3FFFFFFF (first quarter)
;B: &H40000000 - &HBFFFFFFF (second and third quarters)
;C: &HC0000000 - &HFFFFFFFF (fourth quarter)

;Then for two given numbers, a normal comparison is done except
;if they belong to zones A and C; number in zone A > number in zone C always.
;(Assumes that TCP can't send 1GByte of data without being ACKed)

COMP_SEQ:
	ld	a,(de)	;In the most common case, the first bytes match,
	cp	(hl)	;the jump to normal comparison
	jr	z,COMP32

	ld	a,(hl)	;(HL) in zone A and (DE) in zone C?
	and	%11000000
	jr	nz,COMP32_1
	ld	a,(de)
	or	%00111111
	inc	a
	jr	nz,COMP32_1

	xor	a	;Then return with
	cp	1	;NZ and C (HL>DE)
	ret

COMP32_1:
	ld	a,(de)	;(DE) in zone A and (HL) in zoni C?
	and	%11000000
	jr	nz,COMP32
	ld	a,(hl)
	or	%00111111
	inc	a
	jr	nz,COMP32

	inc	a	;Then return with
	ret		;NZ and NC (HL<DE)

COMP32:	call	COMP32_3	;Normal comparison
	ret	nz
	call	COMP32_3
	ret

	;This subroutine compares the first two bytes in the first call,
	;and the second two bytes in the second call

COMP32_3:
	ld	a,(hl)	;Loads HL' with (HL) and (HL+1)
	ex	af,af	;(first call)
	inc	hl	;or with (HL+2) and (HL+3)
	ld	a,(hl)	;(second call).
	inc	hl	;Takes in account that the number is big-endian.
	exx
	ld	l,a
	ex	af,af
	ld	h,a
	exx

	ld	a,(de)	;Loads DE' with (DE) and (DE+1)
	ex	af,af	;(first call)
	inc	de	;or with (DE+2) and (DE+3)
	ld	a,(de)	;(second call).
	inc	de	;Takes in account that the number is big-endian.
	exx
	ld	e,a
	ex	af,af
	ld	d,a
	;exx

	;exx
	call	COMP	;Compare HL' and DE'
	exx
	ret


;--- NAME: ADD32
;      Adds two 32 bit numbers
;    INPUT:  HL, DE = Numbers to add
;            BC = Destination number
;            That is, it does: (BC) = (DE) + (HL)
;    OUTPUT: -
;    MODIFIES: AF

ADD32:	ld	a,#8E	;Code for "adc (hl)"
	ld	(ADDSUB_CODE),a
	jr	ADDSUB32


;--- NAME: SUB32
;      Substracts two 32 bit numbers
;    INPUT:  DE = Minuend
;            HL = Subtrahend
;            BC = Destination number
;            That is, it does: (BC) = (DE) - (HL)
;    OUTPUT:   -
;    MODIFIES: AF

SUB32:	ld	a,#9E	;Code for "sbc (hl)"
	ld	(ADDSUB_CODE),a

	;Common code for ADD32 and SUB32

ADDSUB32:
	inc	de	;Move to the last byte
	inc	de	;(number is stored big-endian)
	inc	de
	inc	hl
	inc	hl
	inc	hl
	inc	bc
	inc	bc
	inc	bc

	or	a
	call	ADD32_STEP2	;Add or substract byte by byte,
	call	ADD32_STEP	;from LSB to MSB, accumulating
	call	ADD32_STEP	;carry, in 4 steps

ADD32_STEP:
	dec	hl
	dec	de
	dec	bc
ADD32_STEP2:
	ld	a,(de)
ADDSUB_CODE:
	nop		;Here goes "adc (hl)" or "sbc (hl)"
	ld	(bc),a
	ret


;--- NAME: ADD3216
;      Adds a 16 bit number to a 32 bit number
;    INPUT:  HL = 32 bit number
;            DE = 16 bit number
;            BC = Destination number
;            That is, it does: (BC) = DE + (HL)
;    OUTPUT: -
;    MODIFIES: AF

ADD3216:
	ld	a,d
	ld	(NUM16BUF+2),a
	ld	a,e
	ld	(NUM16BUF+3),a
	ld	de,NUM16BUF
	jr	ADD32

NUM16BUF:
	db	0,0,0,0


;--- NAME: SUB3216
;      Substracts a 16 bit number from a 32 bit number
;    INPUT:  DE = Minuend
;            HL = Subtrahend
;            BC = Destination number
;            That is, it does: (BC) = (DE) - HL
;    OUTPUT:   -
;    MODIFIES: AF

SUB3216:
	ld	a,h
	ld	(NUM16BUF+2),a
	ld	a,l
	ld	(NUM16BUF+3),a
	ld	hl,NUM16BUF
	jr	SUB32


;--- NAME: INC32
;      Increases a 16 bit number by one
;    INPUT:  HL = Number to increase
;            BC = Destination number
;            That is, it does: (BC) = (HL) + 1

INC32:	ld	de,NUM1BUF
	jr	ADD32

NUM1BUF:
	db	0,0,0,1


;--- NAME: DEC32
;      Decreases a 16 bit number by one
;    INPUT:  HL = Number to decrease
;            BC = Destination number
;            That is, it does:  (BC) = (HL) - 1

DEC32:	ex	de,hl
	ld	hl,NUM1BUF
	jr	SUB32


;--- NAME: RANGE32
;      Check if a TCP sequence number is inside a given range
;    INPUT:  HL = Lower limit
;            DE = Upper limit
;            BC = Number to check
;    OUTPUT: Cy=1 if (HL) <= (BC) <= (DE)
;    MODIFIES: HL, DE, AF, HL', DE', AF'
;

RANGE32:
	push	hl,de,bc	;First check if
	ex	de,hl		;(BC) < (HL), if so, terminate
	ld	h,b
	ld	l,c
	call	COMP_SEQ
	pop	bc,de,hl
	ret	nc

RANGE32_2:
	ld	h,b
	ld	l,c
	call	COMP_SEQ
	ret	z
	ccf
	ret


	if	LINK=1

	;--- POR60_32: Multiplies a 32 bit number by 60
	;    Input: IX = Pointer to number (big-endian)

POR60_32:
	push	ix
	pop	hl
	ld	de,NUMBUF
	ld	bc,4
	ldir

	;* Multiplies by 64 (1)

	ld	b,6
	call	MULT32B

	;* Multiplies original by 4 (2)

	push	ix
	ld	ix,NUMBUF
	ld	b,2
	call	MULT32B
	pop	ix

	;* Substracts (2) from (1) and terminates

	ld	iy,NUMBUF

	ld	h,(ix+2)
	ld	l,(ix+3)
	ld	d,(iy+2)
	ld	e,(iy+3)
	or	a
	sbc	hl,de
	ld	(ix+2),h
	ld	(ix+3),l

	ld	h,(ix)
	ld	l,(ix+1)
	ld	d,(iy)
	ld	e,(iy+1)
	sbc	hl,de	;Use carry from previous operation
	ld	(ix),h
	ld	(ix+1),l

	ret

	;* Generic routine to multiply (IX) by 2^B

MULT32B:

MULT32_LOP:
	sla	(ix+3)
	rl	(ix+2)
	rl	(ix+1)
	rl	(ix)
	djnz	MULT32_LOP
	ret

NUMBUF:	ds	4


;--- ENTRE2_32: Divide a 32 bit number by 2^B
;    Input: IX = Number to divide

ENTRE2_32:
	res	7,(ix)	;Just in case
ENTRE2_32L:
	sra	(ix)
	rr	(ix+1)
	rr	(ix+2)
	rr	(ix+3)
	djnz	ENTRE2_32L

	ret

	endif


	;================================================
	;===  Routines for managing circular buffers  ===
	;================================================

;--- Initialize a buffer
;    Input:  IX = Address of buffer control area (12 bytes required)
;            HL = Address of buffer
;            BC = Buffer size
;    Output: -
;    Modifies: F, HL, DE, BC

RBUF_INIT:
	ld	(TRBUF_BUFADD),hl
	ld	(TRBUF_INPNT),hl
	ld	(TRBUF_OUTPNT),hl
	add	hl,bc
	ld	(TRBUF_ENDADD),hl
	ld	(TRBUF_FREE),bc
	ld	hl,0
	ld	(TRBUF_USED),hl
	call	BUF_SDATA
	ret


;--- Insert data in buffer
;    Input:  IX = Buffer control area address
;            HL = Address of data to be inserted
;            BC = Data length
;    Output: Cy = 1 on error (BC>free space), 0 on success
;    Modifies: AF, DE

RBUF_INSERT:
	call	BUF_GDATA

	;--- Is there enough free space?

	push	hl
	ld	hl,(TRBUF_FREE)
	push	bc
	pop	de
	call	COMP
	pop	hl
	ccf
	ret	c

	push	bc	;Total size to stack

	;--- Check data can be inserted all at once,
	;    this will be true if INPNT+BC<=ENDADD

	push	hl
	ld	hl,(TRBUF_INPNT)
	add	hl,bc
	ld	de,(TRBUF_ENDADD)
	ex	de,hl	;HL=ENDADD, DE=INPNT+BC
	call	COMP
	pop	hl
	ld	de,(TRBUF_INPNT)
	jr	c,BUF_IN_DIRECT

	;--- Insert the first ENDADD-INPNT bytes

	; Do BC=ENDADD-INPNT

	push	hl
	ld	hl,(TRBUF_ENDADD)
	ld	de,(TRBUF_INPNT)
	or	a
	sbc	hl,de

	push	hl
	pop	bc	;BC=ENDADD-INPNT

	pop	hl
	push	bc	;Total size and first block size to stack

	; Copy first block

	ld	de,(TRBUF_INPNT)
	ldir

	; Set DE to BUFADD,
	; calculate in BC the remaining block size,
	; and jump to direct insertion code

	pop	bc	;BC = copied size (1st block)
	pop	de	;DE = Total size
	push	de
	push	hl	;Pila=Total size, Current source address

	push	bc
	pop	hl
	ex	de,hl	;HL = Total size, DE = Copied size
	or	a
	sbc	hl,de
	push	hl
	pop	bc	;BC = Remaining size to copy

	pop	hl	;HL = Current source address; Total size to stack

	ld	de,(TRBUF_BUFADD)

	;--- Insert last block

BUF_IN_DIRECT:
	ldir

	ld	hl,(TRBUF_ENDADD)	;HL=ENDADD, DE=Last insertad address +1
	call	COMP
	jr	nz,NO_ADJ_PNT
	ld	de,(TRBUF_BUFADD)	;Checks if the copy reached the buffer end
NO_ADJ_PNT:

	;--- Adjust pointers and terminate

	ld	(TRBUF_INPNT),de
	pop	bc
	ld	hl,(TRBUF_USED)
	add	hl,bc
	ld	(TRBUF_USED),hl
	ld	hl,(TRBUF_FREE)
	or	a
	sbc	hl,bc
	ld	(TRBUF_FREE),hl

	call	BUF_SDATA
	xor	a
	ret


;--- Extract data from a buffer
;    Input:  IX = Buffer control area address
;            DE = Destination address
;            BC = Number of bytes to extract
;    Output: BC = Number of bytes extracted
;            Cy=1 if error (0 bytes available in buffer)
;    Modifies: AF, HL, DE, BC

RBUF_EXTRACT:
	xor	a
	jr	BUF_EXTPEEK


;--- Obtain data from a buffer without extracting it
;    Input:  IX = Buffer control area address
;            DE = Destination address
;            BC = Number of bytes to peek
;    Output: BC = Number of bytes peeked
;            Cy=1 if error (0 bytes available in buffer)
;    Modifies: AF, HL, DE, BC

RBUF_PEEK:
	ld	a,#FF
BUF_EXTPEEK:
	ld	(BUF_OUTACTION),a

	call	BUF_GDATA

	;--- Check BC

	; If BC=0, do nothing and terminate

	ld	a,b
	or	c
	ret	z

	; If no available data, terminate with error

	ld	hl,(TRBUF_USED)
	ld	a,h
	or	l
	scf
	ret	z

	; If BC>available bytes, modify it

	push	de
	push	bc
	pop	hl
	ld	de,(TRBUF_USED)	;HL=Bytes to extract, DE=Available bytes
	call	COMP
	jr	nc,BEX_NOADJBC
	push	de
	pop	bc
BEX_NOADJBC:
	pop	de

	push	bc	;Number of bytes to extract to stack

	;--- Check data can be extracted all at once,
	;    this will be true if OUTPNT+BC<=ENDADD

	push	de
	ld	hl,(TRBUF_OUTPNT)
	add	hl,bc
	ld	de,(TRBUF_ENDADD)
	ex	de,hl	;HL=ENDADD, DE=OUTPNT+BC
	call	COMP
	pop	de
	ld	hl,(TRBUF_OUTPNT)
	jr	c,BUF_OUT_DIRECT

	;--- Extract the first ENDADD-OUTPNT bytes

	; Do BC=ENDADD-OUTPNT

	push	de
	ld	hl,(TRBUF_ENDADD)
	ld	de,(TRBUF_OUTPNT)
	or	a
	sbc	hl,de
	push	hl
	pop	bc
	pop	de
	push	bc	;1st block size

	; Copy first block

	ld	hl,(TRBUF_OUTPNT)
	ldir

	; Set HL as BUFADD,
	; calculate in BC the remaining block size,
	; then jump to direct extraction

	pop	bc	;BC = Copied size (1st block)
	pop	hl	;HL = Total size
	push	hl
	push	de	;Total size and current destination address to stack

	push	bc
	pop	de	;HL = Total size, DE = Copied size
	or	a
	sbc	hl,de
	push	hl
	pop	bc	;BC = Remaining size to copy

	pop	de	;DE = Current destination address; Total size to stack

	ld	hl,(TRBUF_BUFADD)

	;--- Extract last block

BUF_OUT_DIRECT:
	ldir

	ld	de,(TRBUF_ENDADD)	;DE=ENDADD, HL=Last extracted address +1
	call	COMP
	jr	nz,NO_ADJ_PNT2
	ld	hl,(TRBUF_BUFADD)	;Checks if the copy reached the buffer end
NO_ADJ_PNT2:	;

	;--- Adjust pointers if extraccion required, and terminate

	pop	bc
	ld	a,(BUF_OUTACTION)
	or	a
	ld	a,0
	ret	nz

	ld	(TRBUF_OUTPNT),hl
	ld	hl,(TRBUF_USED)
	or	a
	sbc	hl,bc
	ld	(TRBUF_USED),hl
	ld	hl,(TRBUF_FREE)
	add	hl,bc
	ld	(TRBUF_FREE),hl

	push	bc
	call	BUF_SDATA
	pop	bc
	xor	a
	ret

BUF_OUTACTION:	db	0	;0 for extract, #FF for peek


	;=== Auxiliary routines

	;--- Copy a buffer control area to/from temporal buffer
	;    (area pointed by IX)

BUF_GDATA:
	push	hl,de,bc
	push	ix
	pop	hl
	ld	de,TRBUF_USED
	ld	bc,12
	ldir
	pop	bc,de,hl
	ret

BUF_SDATA:
	push	ix
	pop	de
	ld	hl,TRBUF_USED
	ld	bc,12
	ldir
	ret



	;---------------------------------------
	;---  Temporary buffer control area  ---
	;---------------------------------------

TRBUF_USED:	dw	0
TRBUF_FREE:	dw	0
TRBUF_INPNT:	dw	0
TRBUF_OUTPNT:	dw	0
TRBUF_BUFADD:	dw	0
TRBUF_ENDADD:	dw	0



	;===============================================
	;===  Routines for Base64 (de)codification   ===
	;===============================================

;* Graphic of Base64 transformation:
;
;         +--first octet--+-second octet--+--third octet--+
;         |7 6 5 4 3 2 1 0|7 6 5 4 3 2 1 0|7 6 5 4 3 2 1 0| --> Normal
;         +-----------+---+-------+-------+---+-----------+
;         |5 4 3 2 1 0|5 4 3 2 1 0|5 4 3 2 1 0|5 4 3 2 1 0| --> Codified
;         +--1.index--+--2.index--+--3.index--+--4.index--+

;--- B64_INIT: Initialize the Base64 engine
;    Input:  A=Number of characters per line
;              (0=do not break encoded stream in lines)
;    Modifies: -

B64_INIT:
	push	af,hl
	or	a
	jr	z,B64_INIT2

	cp	4
	jr	nc,B64_INIT1
	ld	a,4
B64_INIT1:
	sra	a	;Converts to groups of 4
	sra	a
	and	%00111111

B64_INIT2:
	ld	(B64_CRINT),a
	ld	(B64_CRCNT),a
	xor	a
	ld	(B64_TEMPLON),a
	ld	(B64_DEC_FIN),a
	ld	hl,B64_INTEMP
	ld	(B64_DEC_PNT),hl
	ld	hl,0
	ld	(B64_TOTLEN),hl
	ld	(B64_TOTLEN+2),hl
	ld	(B64_INTEMP),hl
	ld	(B64_INTEMP+2),hl

	pop	hl,af
	ret


;--- B64_ENCB: Encode a byte group in Base64.
;    Takes in account the previous encoding state,
;    therefore IX-1 and IX-2 must be available;
;    moreover, it stores the encoding state if not a final block.
;    Input:  IX = Source address
;            IY = Destination address
;            BC = Length
;            Cy = 1 if final block
;            (B64_CRINT) = Encoded line length
;            (B64_CRCNT) = Previous encoding state
;    Output: BC = Encoded result length
;            IX = IX+BC at input
;            IY = IY+BC at output
;            HL:DE = Accumulated encoded data length
;    Modifies: AF, BC, DE, HL, IX, IY

B64_ENCB:
	ld	a,0
	rla
	ld	(B64_IS_FINAL),a	;1 if final block, 0 if not
	push	iy

	;--- Previous state available?

	ld	a,(B64_TEMPLON)
	or	a
	jr	z,B64_ENCLOOP
	cp	2
	jr	z,B64_ENC_PRV2

	;Previous state is 1 byte

	ld	a,(B64_INTEMP)
	ld	(ix-1),a
	dec	ix
	inc	bc
	jr	B64_ENCLOOP

	;Previous state is 2 byte

B64_ENC_PRV2:
	ld	a,(B64_INTEMP)
	ld	(ix-2),a
	ld	a,(B64_INTEMP+1)
	ld	(ix-1),a
	dec	ix
	dec	ix
	inc	bc
	inc	bc
	;jr      B64_ENCLOOP

B64_ENCLOOP:
	ld	a,b
	or	a
	jr	nz,B64ENC_NOFIN
	ld	a,c
	or	a
	jr	z,B64ENC_LAST0
	cp	1
	jr	z,B64ENC_LAST1
	cp	2
	jr	z,B64ENC_LAST2

	;--- Encodes normal block

B64ENC_NOFIN:
	exx
	call	B64_ENC3
	exx
	dec	bc
	dec	bc
	dec	bc

	;* Must insert CRLF?

	ld	a,(B64_CRCNT)
	or	a
	jr	z,B64_ENCLOOP

	dec	a
	ld	(B64_CRCNT),a
	jr	nz,B64_ENCLOOP

	ld	a,(B64_CRINT)
	ld	(B64_CRCNT),a
	ld	(iy),13
	ld	(iy+1),10
	inc	iy
	inc	iy
	jr	B64_ENCLOOP

	;--- Last block, 1 byte

B64ENC_LAST1:	ld	a,(B64_IS_FINAL)
	or	a
	jr	z,B64ENC_L1_2

	;* It was final block

	call	B64_ENC1
	jr	B64_ENC_END

	;* No final block

B64ENC_L1_2
	ld	a,(ix)
	ld	(B64_INTEMP),a
	ld	a,1
	ld	(B64_TEMPLON),a
	inc	ix
	jr	B64_ENC_END

	;--- Last block, 2 bytes

B64ENC_LAST2:
	ld	a,(B64_IS_FINAL)
	or	a
	jr	z,B64_L2_2

	;* It was final block

	call	B64_ENC2
	jr	B64_ENC_END

	;* No final block

B64_L2_2:
	ld	a,(ix)
	ld	(B64_INTEMP),a
	ld	a,(ix+1)
	ld	(B64_INTEMP+1),a
	ld	a,2
	ld	(B64_TEMPLON),a
	inc	ix
	inc	ix
	jr	B64_ENC_END

	;--- No last block

B64ENC_LAST0:
	xor	a
	ld	(B64_TEMPLON),a

	;--- End: calculate resulting length
	;    as new IY - old IY

B64_ENC_END:
	pop	bc
	push	iy
	push	iy
	pop	hl
	or	a
	sbc	hl,bc
	push	hl
	pop	bc
	pop	iy

	call	B64_INCTLEN

	xor	a
	ret


;--- B64_ENC3: Encode 3 bytes in Base64
;    Input:  IX = Bytes address
;            IY = Destination address
;    Output: IX = IX+3
;            IY = IY+4
;    Modifies: AF, HL, BC

B64_ENC3:
	ld	a,(ix)
	sra	a
	sra	a
	and	%00111111
	call	GETB64CHAR
	ld	(iy),a

	ld	a,(ix)
	sla	a
	sla	a
	sla	a
	sla	a
	and	%00110000
	ld	b,a
	ld	a,(ix+1)
	sra	a
	sra	a
	sra	a
	sra	a
	and	%00001111
	or	b
	call	GETB64CHAR
	ld	(iy+1),a

	ld	a,(ix+1)
	sla	a
	sla	a
	and	%00111100
	ld	b,a
	ld	a,(ix+2)
	rlca
	rlca
	and	%00000011
	or	b
	call	GETB64CHAR
	ld	(iy+2),a

	ld	a,(ix+2)
	and	%00111111
	call	GETB64CHAR
	ld	(iy+3),a

	inc	ix
B64_ENCEND2:
	inc	ix
B64_ENCEND1:
	inc	ix
	inc	iy
	inc	iy
	inc	iy
	inc	iy
	ret


;--- B64_ENC1: Encode a final 1-byte block in Base64
;    Input:   IX = Byte address
;             IY = Destination address
;    Output:  IX = IX+1
;             IY = IY+4
;    Modifies: AF, HL, BC

B64_ENC1:
	ld	a,(ix)
	sra	a
	sra	a
	and	%00111111
	call	GETB64CHAR
	ld	(iy),a

	ld	a,(ix)
	sla	a
	sla	a
	sla	a
	sla	a
	and	%00110000
	call	GETB64CHAR
	ld	(iy+1),a

	ld	(iy+2),"="
	ld	(iy+3),"="
	jr	B64_ENCEND1


;--- B64_ENC2:  Encode a final s-byte block in Base64
;    Input:   IX = Byte address
;             IY = Destination address
;    Output:  IX = IX+2
;             IY = IY+4
;    Modifies: AF, HL, BC

B64_ENC2:
	ld	a,(ix)
	sra	a
	sra	a
	and	%00111111
	call	GETB64CHAR
	ld	(iy),a

	ld	a,(ix)
	sla	a
	sla	a
	sla	a
	sla	a
	and	%00110000
	ld	b,a
	ld	a,(ix+1)
	sra	a
	sra	a
	sra	a
	sra	a
	and	%00001111
	or	b
	call	GETB64CHAR
	ld	(iy+1),a

	ld	a,(ix+1)
	sla	a
	sla	a
	and	%00111100
	call	GETB64CHAR
	ld	(iy+2),a

	ld	(iy+3),"="
	jr	B64_ENCEND2



;--- B64_DECB: Decode a Base64 characters group
;    Skips tabs, spaces and CRLF;
;    other invalid characters return error.
;    Takes in account the previous encoding state,
;    moreover, it stores the decoding state if not a final block.
;    Input:  IX = Source address
;            IY = Destination address
;            BC = Length
;            Cy = 1 if final block
;    Output: BC = Decoded result length
;            IX = IX+BC at input
;            IY = IY+BC at output
;            HL:DE = Accumulated decoded data length
;            Cy=1 if error
;                 A=2: Invalid length in non final block
;                   3: Invalidos characteres found
;    Modifies: AF, BC, DE, HL, IX, IY

B64_DECB:
	ld	a,0
	rla
	ld	(B64_IS_FINAL),a	;1 if final, 0 if not
	ld	(B64_DEC_IY),iy

	;--- Main loop

B64_DECLOOP:
	;* If a full 4 characters group is available, decode it

	ld	a,(B64_TEMPLON)
	cp	4
	jr	nz,B64_DECLOOP2

	exx
	call	B64_DEC4
	exx
	xor	a
	ld	(B64_TEMPLON),a
	ld	hl,B64_INTEMP
	ld	(B64_DEC_PNT),hl

	ld	a,(B64_TEMPLON+2)
	cp	#FF
	jr	nz,B64_DECLOOP2
	ld	a,(B64_TEMPLON+3)
	cp	#FF
	jr	nz,B64_DECLOOP2
	ld	(B64_DEC_FIN),a
B64_DECLOOP2:	;

	;* If no input characters left, terminate

B64_DEC_NEXT:	ld	a,b
	or	c
	jr	z,B64_DEC_END

	;* Obtain a new character to decode

	ld	a,(ix)
	inc	ix
	dec	bc

	;* Ignorable character?

	cp	9	;TAB
	jr	z,B64_DEC_NEXT
	cp	32	;SPC
	jr	z,B64_DEC_NEXT
	cp	13	;CR
	jr	z,B64_DEC_NEXT
	cp	10	;LF
	jr	z,B64_DEC_NEXT

	;If a "=" character was poresent in the last decoded group,
	;only ignorable characters may remain; otherwise it is an error

	ld	h,a
	ld	a,(B64_DEC_FIN)
	or	a
	jr	nz,B64_DEC_ER3
	ld	a,h

	;* If "=" found, it is an error if:
	;  - Not the final block; or
	;  - Not at least 2 characters in B64_INTEMP

	cp	"="
	jr	nz,B64_DECLOOP3

	ld	a,(B64_TEMPLON)
	cp	2
	jr	c,B64_DEC_ER3

	ld	a,#FF
	jr	B64_DECLOOP4

	;* Try to decode character, if success, store it

B64_DECLOOP3:
	exx
	call	GETB64INDEX
	exx
	jr	nz,B64_DEC_ER3
B64_DECLOOP4:
	ld	hl,(B64_DEC_PNT)
	ld	(hl),a
	inc	hl
	ld	(B64_DEC_PNT),hl
	ld	hl,B64_TEMPLON
	inc	(hl)
	jr	B64_DECLOOP

	;--- End: if there are pendientes characters
	;    and block was not final, error

B64_DEC_END:
	ld	bc,(B64_DEC_IY)
	push	iy
	push	iy
	pop	hl
	or	a
	sbc	hl,bc
	push	hl
	pop	bc
	pop	iy

	call	B64_INCTLEN

	ld	a,(B64_IS_FINAL)
	or	a
	ret	z

	ld	a,(B64_TEMPLON)
	or	a
	ret	z

	ld	a,2
	scf
	ret

	;--- Error 3

B64_DEC_ER3:
	ld	a,3
	scf
	ret

B64_DEC_IY:	dw	0


;--- B64_DEC4: Decode a Base64 4 characters group
;    Input:  Characters in B64_INTEMP, unescaped
;            (characters are 0-63, or #FF for "=")
;            IY = Destination address
;    Output: IY = IY+1, 2 o 3
;    Modifies: AF, HL, BC

B64_DEC4:
	ld	hl,(B64_INTEMP)	;Read characters at L, H, E, D
	ld	de,(B64_INTEMP+2)

	ld	a,l
	sla	a
	sla	a
	and	%11111100
	ld	b,a
	ld	a,h
	sra	a
	sra	a
	sra	a
	sra	a
	and	%00000011
	or	b
	ld	(iy),a

	ld	a,e
	cp	#FF
	jr	z,B64_DEC4_END1

	ld	a,h
	sla	a
	sla	a
	sla	a
	sla	a
	and	%11110000
	ld	b,a
	ld	a,e
	sra	a
	sra	a
	and	%00001111
	or	b
	ld	(iy+1),a

	ld	a,d
	cp	#FF
	jr	z,B64_DEC4_END2

	ld	a,e
	rrca
	rrca
	and	%11000000
	ld	b,a
	ld	a,d
	and	%00111111
	or	b
	ld	(iy+2),a

	inc	iy
B64_DEC4_END2:
	inc	iy
B64_DEC4_END1:
	inc	iy
	ret


;--- GETB64CHAR: Obtain a Base64 character from its index
;    Input:  A = Index (0-63)
;    Output: A = Character
;    Modifies: AF, HL, BC

GETB64CHAR:
	ld	hl,B64TABLE
	ld	c,a
	ld	b,0
	add	hl,bc
	ld	a,(hl)
	ret


;--- GETB64INDEX: Obtain the index of a Base64 character
;    Input:  A = Caracter
;    Output: A = Index and Z=1 (A=#FF and Z=0 if character not found)
;    Modifies: AF, HL, BC

GETB64INDEX:
	ld	hl,B64TABLE+63
	ld	bc,64
	cpdr
	ld	a,#FF
	ret	nz
	ld	a,c
	ret


;--- B64_INCTLEN: Increases B64_TOTLEN field by BC
;    Input:  BC = Length to add
;    Output: HL:DE = New value of B64_TOTLEN
;    Modifies: F, HL, DE

B64_INCTLEN:
	ld	hl,(B64_TOTLEN)
	add	hl,bc
	ld	(B64_TOTLEN),hl
	ex	de,hl
	ld	hl,(B64_TOTLEN+2)
	ret	nc
	inc	hl
	ld	(B64_TOTLEN+2),hl
	ret


;--- Variables

B64TABLE:
	db	"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	db	"abcdefghijklmnopqrstuvwxyz"
	db	"0123456789+/"
B64_CRINT:	db	0	;Encoded line length, in groups of 4
				;(0 = do not insert line breaks)
B64_CRCNT:	db	0	;Counter for inserting CRLF
B64_INTEMP:	ds	4	;For temporary storage of an incomplete group
B64_TEMPLON:	db	0	;Incomplete group length
B64_DEC_PNT:	dw	0	;Pointer for filling B64_INTEMP when decoding
B64_TOTLEN:	ds	4	;Total accumulated length of output blocks
B64_IS_FINAL:	db	0
B64_DEC_FIN:	db	0


	if	LINK=0

	;===============================================
	;===  Routines for Van Jacobson compression  ===
	;===============================================

;--- Set Toss flag

SET_TOSS_FLAG:
	push	af
	ld	a,#FF
	ld	(TOSS_FLAG),a
	pop	af
	ret

;--- Obtain the storage address from an incoming slot
;    Input: A=slot, Output: HL=address

GET_VJ_INSLOT:
	ld	hl,VJ_IN_HEADS
	or	a
	ret	z
	ld	b,a
	ld	de,44
GVJIS_LOOP:
	add	hl,de
	djnz	GVJIS_LOOP
	ret

;--- Read an encoded value from a VJ header VJ
;    Input:  IX = Pointer to value
;    Output: IX updated
;            BC = Value

GET_VJ_VALUE:
	ld	b,0
	ld	c,(ix)
	inc	ix
	ld	a,c
	or	a
	ret	nz	;1 byte value

	ld	b,(ix)	;0 + two byte value
	ld	c,(ix+1)
	inc	ix
	inc	ix
	ret


;--- Write an encoded value in a VJ header
;    Input:  IX = Pointer to value
;            BC = Value to write
;    Output: IX updated (decreased)

SET_VJ_VALUE:
	ld	(ix),c
	dec	ix

	ld	a,b
	or	c
	jr	z,SET_VJ_VALUE2	;If value is 0, expand it
	ld	a,b
	or	a
	ret	z

SET_VJ_VALUE2:
	ld	(ix),b	;2 byte value
	ld	(ix-1),0
	dec	ix
	dec	ix
	ret


;--- Compress a VJ datagram
;    (assumes URG field never set)
;    Input:  Datagram in OUT_BUFFER+4
;            HL = Datagram length
;            BC = PPP header length (1 to 4)
;    Output: SEND_PAQ_PNT updated
;            PPP protocol updated
;            HL = New datagram length

COMPRESS_VJ:
	ld	(VJ_ORIG_SIZE),hl
	ld	(VJ_ORIG_PPPHS),bc

	;--- Check if actually an IP datagram
	;    (IN_BUFFER+3 must be #21 and IN_BUFFER+2 must not be #80)

	ld	a,(OUT_BUFFER+3)
	cp	#21
	ret	nz
	ld	a,(OUT_BUFFER+2)
	cp	#80
	ret	z

	;--- Check if it is TCP; if not, send as IP

	ld	a,(OUT_BUFFER+13)
	cp	6
	ret	nz

	;--- If it has SYN, FIN o RST, or if it has no ACK, send as IP

	ld	a,(OUT_BUFFER+37)
	ld	b,a
	and	%111
	ret	nz

	bit	4,b
	ret	z

	;--- If no previous state, send Uncompressed_TCP

	ld	a,(VJ_OUT_HEAD+4)
	or	a
	jp	z,SEND_VJ_UC

	;--- If TTL or TOS changed, send Uncompressed_TCP

	ld	a,(OUT_BUFFER+5)
	ld	b,a
	ld	a,(VJ_OUT_HEAD+5)
	cp	b
	jp	nz,SEND_VJ_UC

	ld	a,(OUT_BUFFER+12)
	ld	b,a
	ld	a,(VJ_OUT_HEAD+12)
	cp	b
	jp	nz,SEND_VJ_UC

	;--- From here we can send a compressed datagram.
	;    Create an initial empty flags byte.

	ld	iy,VJ_FLAGS
	ld	(iy),0

	;--- Check if window changed, if so, store the change

	ld	hl,(OUT_BUFFER+38)
	ld	a,h
	ld	h,l
	ld	l,a
	ld	de,(VJ_OUT_HEAD+38)
	ld	a,d
	ld	d,e
	ld	e,a
	or	a
	sbc	hl,de
	ld	a,h
	or	l
	jr	z,OK_VJ_OUT_W

	ld	(DELTA_W),hl
	set	1,(iy)
OK_VJ_OUT_W:

	;--- Check if ACK changed; if change is negative or >64K,
	;    send Uncompressed_TCP; if not zero, store change

	ld	bc,TEMP32_1
	ld	de,OUT_BUFFER+32
	ld	hl,VJ_OUT_HEAD+32
	call	SUB32

	ld	hl,(TEMP32_1)
	ld	a,h
	or	l
	jp	nz,SEND_VJ_UC

	ld	hl,(TEMP32_1+2)
	ld	a,h
	or	l
	jr	z,OK_VJ_OUT_A

	ld	a,h
	ld	h,l
	ld	l,a
	ld	(DELTA_A),hl
	set	2,(iy)
OK_VJ_OUT_A:

	;--- Check if SEQ changed; if change is negative or >64K,
	;    send Uncompressed_TCP; if not zero, store change

	ld	bc,TEMP32_1
	ld	de,OUT_BUFFER+28
	ld	hl,VJ_OUT_HEAD+28
	call	SUB32

	ld	hl,(TEMP32_1)
	ld	a,h
	or	l
	jp	nz,SEND_VJ_UC

	ld	hl,(TEMP32_1+2)
	ld	a,h
	or	l
	jr	z,OK_VJ_OUT_S

	ld	a,h
	ld	h,l
	ld	l,a
	ld	(DELTA_S),hl
	set	3,(iy)
OK_VJ_OUT_S:

	;--- If only S changed, check if the change on sequence number is equal
	;    to last sent data size; if so, send SAWU.

	ld	a,(iy)
	cp	%1000	;Solo S
	jr	nz,OK_VJ_OUT_SAWU

	ld	hl,(VJ_OUT_HEAD)
	ld	de,(DELTA_S)
	call	COMP
	jr	nz,OK_VJ_OUT_SAWU

	ld	(iy),%1111	;SAWU
	jr	OK_VJ_OUT_SXWU
OK_VJ_OUT_SAWU:

	;--- If only S and A changed, check if the change on sequence number and in ACK
	;    are equal to last sent data size; if so, send SWU.

	ld	a,(iy)
	cp	%1100	;Only S and A
	jr	nz,OK_VJ_OUT_SWU

	ld	hl,(VJ_OUT_HEAD)
	ld	de,(DELTA_S)
	call	COMP
	jr	nz,OK_VJ_OUT_SWU
	ld	de,(DELTA_A)
	call	COMP
	jr	nz,OK_VJ_OUT_SWU

	ld	(iy),%1011	;SWU
	jr	OK_VJ_OUT_SXWU
OK_VJ_OUT_SWU:

	;--- If nothing changed, and datagram has no data or previous packet
	;    had data, send Uncompressed_TCP

	ld	a,(iy)
	or	a
	jr	nz,OK_VJ_OUT_SXWU

	ld	hl,(VJ_ORIG_SIZE)
	ld	bc,40
	or	a
	sbc	hl,bc	;Substract headers size
	ld	a,h
	or	l
	jp	z,SEND_VJ_UC

	ld	hl,(VJ_OUT_HEAD)
	ld	a,h
	or	l
	jp	nz,SEND_VJ_UC
OK_VJ_OUT_SXWU:

	;--- Calculate the difference of IDs, if not 1, store it

	ld	hl,(OUT_BUFFER+8)
	ld	a,h
	ld	h,l
	ld	l,a
	ld	de,(VJ_OUT_HEAD+8)
	ld	a,d
	ld	d,e
	ld	e,a
	or	a
	sbc	hl,de
	ld	de,1
	call	COMP
	jr	z,OK_VJ_OUT_I

	ld	(DELTA_I),hl
	set	5,(iy)
OK_VJ_OUT_I:

	;--- Set PUSH in flags if datagram has it set

	ld	a,(OUT_BUFFER+37)
	and	%1000
	jr	z,OK_VJ_OUT_P

	set	4,(iy)
OK_VJ_OUT_P:

	;--- Copy headers to TCB

	ld	hl,OUT_BUFFER+4
	ld	de,VJ_OUT_HEAD+4
	ld	bc,40
	ldir

	;--- Componese VJ header, in reverse order

	ld	ix,OUT_BUFFER+43

	;* If flags are SxWU, jump directly yo checksum calculation

	bit	0,(iy)	;It is enough to check U, since we'll never set it alone
	jr	nz,DO_VJ_CHKSUM

	;* ID IP

	bit	5,(iy)
	ld	bc,(DELTA_I)
	call	nz,SET_VJ_VALUE

	;* Sequence number

	bit	3,(iy)
	ld	bc,(DELTA_S)
	call	nz,SET_VJ_VALUE

	;* ACK

	bit	2,(iy)
	ld	bc,(DELTA_A)
	call	nz,SET_VJ_VALUE

	;* Window

	bit	1,(iy)
	ld	bc,(DELTA_W)
	call	nz,SET_VJ_VALUE

	;* TCP checksum

DO_VJ_CHKSUM:
	ld	bc,(VJ_OUT_HEAD+40)
	ld	(ix),b
	ld	(ix-1),c
	dec	ix
	dec	ix

	;* Connection Id: Set it if it changed since last time,
	;  or if peer doesn't support Id obviation

	ld	a,(USE_VJ_OUT)
	cp	2
	jr	nz,DO_VJ_OUT_C

	ld	a,(VJ_LAST_OSLOT)
	ld	b,a
	ld	a,(CURTCB_NUM)
	cp	b
	jr	z,OK_VJ_OUT_C

DO_VJ_OUT_C:
	ld	a,(CURTCB_NUM)
	ld	(ix),a
	set	6,(iy)
	dec	ix
OK_VJ_OUT_C:

	ld	a,(CURTCB_NUM)
	ld	(VJ_LAST_OSLOT),a

	;* Finally, flags byte

	ld	a,(iy)
	ld	(ix),a

	;--- Now SEND_PAQ_PNT and datagram length must be updated.
	;    Here, IX points to the start of datagram.

	;* Update data size in TCB

	ld	hl,(VJ_ORIG_SIZE)
	ld	bc,40
	or	a
	sbc	hl,bc	;Substracts headers size
	ld	(VJ_OUT_HEAD),hl

	;* Update PPP protocol field

	ld	(ix-1),#2D

	;* New pointer is IX - PPP header size

	ld	bc,(VJ_ORIG_PPPHS)
	or	a
	push	ix
	pop	hl
	sbc	hl,bc
	ld	(SEND_PAQ_PNT),hl

	;* New size is old one - (IX - OUT_BUFFER+4)

	push	ix
	pop	hl
	ld	bc,OUT_BUFFER+4
	or	a
	sbc	hl,bc
	push	hl
	pop	bc

	ld	hl,(VJ_ORIG_SIZE)
	or	a
	sbc	hl,bc

	ret

	;--- Send UNCOMPRESSED_TCP

SEND_VJ_UC:

	;* Copy header to TCB

	ld	hl,OUT_BUFFER+4
	ld	de,VJ_OUT_HEAD+4
	ld	bc,40
	ldir

	;* Store data length

	ld	hl,(VJ_ORIG_SIZE)
	ld	bc,40
	or	a
	sbc	hl,bc
	ld	(VJ_OUT_HEAD),hl

	;* Send slot id in the protocol field,
	;  update PPP protocol field, and terminate

	ld	a,(CURTCB_NUM)	;Slot id is the number of the TCP connection
	ld	(OUT_BUFFER+13),a

	ld	a,#2F
	ld	(OUT_BUFFER+3),a

	ld	hl,(VJ_ORIG_SIZE)
	ret

VJ_ORIG_SIZE:	dw	0
VJ_ORIG_PPPHS:	dw	0

	endif


;***********************
;***                 ***
;***  USER ROUTINES  ***
;***                 ***
;***********************


	;====================
	;===  VERS_PAUSE  ===
	;====================

;Returns the INL version number, and optionally
;pauses or resumes INL execution.
;Input:  A = 0 to return information only
;            1 to pause INL
;            2 to resume INL
;Output: A = 1 if INL is paused, 2 if active
;        C = Main INL version number
;        D = Secundary version number
;        E = Revision number
;        B = INL typo: 0 = INL for PPP over RS232
;                      1 = INL for ObsoNET (discontinued)
;                      2 = INL for the Ethernet UNAPI

;NOTE: "Pausing" INL means detaching the resident code
;      from the timer interrupt routine.

_VERS_PAUSE:
	push	af
	ld	de,#2203
	call	#FFCA
	pop	af
	push	hl
	pop	ix

	or	a
	jr	z,VERS_PAUSEND

	dec	a
	jr	nz,VERS_PAUSE2

	;--- Pause

VERS_PAUSE1:
	xor	a
	di
	ld	(ix),a
	ld	(ix+1),a
	ld	(ix+2),a
	ei
	jr	VERS_PAUSEND

	;--- Resume

VERS_PAUSE2:
	ld	a,#C3
	di
	ld	(ix),a
	ld	a,(ix+8)
	ld	(ix+1),a
	ld	a,(ix+9)
	ld	(ix+2),a
	ei

	;--- Information

VERS_PAUSEND:	ld	a,(ix)
	and	1
	inc	a

	if	LINK=0
	ld	bc,INL_VERSION1	;Implies B=0
	endif

	if	LINK=1
	ld	bc,INL_VERSION1+2*256	;Implies B=2
	endif

	ld	de,INL_VERSION3+256*INL_VERSION2
	ret


	;=================
	;===  GET_VAR  ===
	;=================

;Read variable whose address is HL from variables segment.
;Returns result in A (1 byte) and in DE (2 bytes).
;Preserves HL.

_GET_VAR:
	push	hl
	call	SETUP_P2
	set	7,h	;Convert address to page 2
	res	6,h

	ld	a,(hl)
	ld	e,(hl)
	inc	hl
	ld	d,(hl)

	pop	hl
	jp	RESTORE_P2


	;=================
	;===  SET_VAR  ===
	;=================

;Write variable whose address is HL from variables segment.
;If Cy=0, write one byte from A; if 1, write two bytes from DE.

_SET_VAR:
	push	hl,af,de
	call	SETUP_P2
	set	7,h	;Convert address to page 2
	res	6,h
	pop	de,af

	jr	c,SET2BYTES

SET1BYTE:
	ld	(hl),a
	jr	SETVAR2

SET2BYTES:
	ld	(hl),e
	inc	hl
	ld	(hl),d

SETVAR2:
	pop	hl
	jp	RESTORE_P2


	;===================
	;===  COPY_DATA  ===
	;===================

;Copy a data block from TPA to data segment or vice versa.
;Input: HL=Source, DE=Destination, BC=Length
;Cy=0 for Seg->TPA transfer, 1 for TPA->SEG transfer

_COPY_DATA:
	call	SETUP_P2
	ld	ix,RESTORE_P2
	push	ix
	jp	c,LDIR_ST
	jp	LDIR_TS


	;===================
	;===  IP_STRING  ===
	;===================

;Convert an IP address to a string.
;Input: L.H.E.D = IP address
;       IX = Destination address fro the string (in TPA)
;       A = Termination character

_IP_STRING:
	push	ix,af
	call	SETUP_P2
	ld	ix,OUT_BUFFER+500

	ld	a,#FF
	ld	(DISABLE_INT),a

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

	pop	af	;Termination character
	ld	(ix),a

	push	ix
	pop	hl
	inc	hl	;Calculate resulting length
	ld	bc,OUT_BUFFER+500
	or	a
	sbc	hl,bc
	push	hl
	pop	bc

	pop	de	;Copy result to TPA
	ld	hl,OUT_BUFFER+500
	;ld      bc,16
	call	LDIR_TS

	xor	a
	ld	(DISABLE_INT),a

	jp	RESTORE_P2


	;--- Convert a 8 bit number to an unterminated string
	;    Input:  A  = Number
	;            IX = Destination address
	;    Output: IX points after the generated string
	;    Modifies: C

BYTE2ASC:
	cp	10
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
B2A_2D2:
	inc	c
	sub	10
	cp	10
	jr	nc,B2A_2D2

	ld	(ix),c
	inc	ix
	jr	B2A_1D

	;--- Between 100 and 199

B2A_1XX:
	ld	(ix),"1"
	sub	100
B2A_XXX:
	inc	ix
	cp	10
	jr	nc,B2A_2D	;If 1XY with X>0
	ld	(ix),"0"	;If 10Y
	inc	ix
	jr	B2A_1D

	;--- Between 200 and 255

B2A_2XX:
	ld	(ix),"2"
	sub	200
	jr	B2A_XXX



	;==================
	;===  USER_MD5  ===
	;==================

;Calculate a MD5 digest of a message up to 1024 bytes long.
;Input:  HL = Message address in TPA
;        DE = Destination address in TPA (16 bytes)
;        BC = Message length
;Output: Cy=1 if error (length >1024 bytes)

_USER_MD5:
	call	SETUP_P2

	ld	a,#FF
	ld	(DISABLE_INT),a

	;Valid length?

	push	hl,de,bc
	pop	hl
	push	hl
	ld	de,1025
	call	COMP
	pop	bc,de,hl
	ld	a,1
	jp	c,CALC_MD5_END

	;Copy message to OUT_BUFFER

	push	de,bc
	ld	de,IN_BUFFER
	ld	a,b
	or	c
	call	nz,LDIR_ST

	;Calculate digest

	pop	bc
	ld	hl,IN_BUFFER
	call	MD5

	;Copy result to TPA

	ld	de,IN_BUFFER	;First copy it to data segment
	ld	bc,16
	ldir

	ld	hl,IN_BUFFER
	pop	de
	ld	bc,16
	call	LDIR_TS

	;Terminate

	xor	a

CALC_MD5_END:
	push	af
	xor	a
	ld	(DISABLE_INT),a
	pop	af

	jp	RESTORE_P2


	;=====================
	;===  USER_CHKSUM  ===
	;=====================

;Calculate checksum for a packet up to 1024 bytes long.
;Input:  HL = Packet address in TPA
;        BC = Packet length
;Output: Cy = 1 if error (length >1024 or 0)
;        DE = Checksum

_USER_CHKSUM:
	call	SETUP_P2

	ld	a,#FF
	ld	(DISABLE_INT),a

	;Valid length?

	push	hl,bc
	pop	hl
	push	hl
	ld	de,1025
	call	COMP
	pop	bc,hl
	ld	a,1
	jr	c,USER_CHKS_END
	ld	a,b
	or	c
	ld	a,1
	scf
	jr	z,USER_CHKS_END

	;Copy message to OUT_BUFFER

	push	bc
	ld	de,IN_BUFFER
	call	LDIR_ST

	;Calculate checksum

	pop	bc
	ld	ix,IN_BUFFER
	call	CALC_CHKSUM

	;Terminate

	xor	a

USER_CHKS_END:
	push	af
	xor	a
	ld	(DISABLE_INT),a
	pop	af

	jp	RESTORE_P2


	;======================
	;===  USER_B64INIT  ===
	;======================

;Initiates a Base64 encoding/decoding operation
;Input:  A = Size of one encoded line
;Output: -
;Modifies: none

;> Jumps directly to B64_INIT


	;=====================
	;===  USER_B64ENC  ===
	;=====================

;Encode a block on bytes in Base64
;Input:  IX = Source address in TPA
;        IY = Destination address in TPA
;        BC = Size (0 to 512 bytes)
;        Cy = 0 for initial or intermediate block,
;             1 for final block
;Output: IX = IX+BC at input
;        IY = IY+BC at output
;        HL:DE = Accumulated output size
;        BC = Output size
;        Cy=1 and A=1 if BC>512 at input

_USER_B64ENC:
	ld	hl,B64_ENCB
	jr	_USER_B64


	;=====================
	;===  USER_B64DEC  ===
	;=====================

;Decode a Base64 block of characters
;Input:  IX = Source address in TPA
;        IY = Destination address in TPA
;        BC = Size (0 to 512 bytes)
;        Cy = 0 for initial or intermediate block,
;             1 for final block
;Output: IX = IX+BC at input
;        IY = IY+BC at output
;        HL:DE = Accumulated output size
;        BC = Output size
;        Cy = 1 if error:
;             A=1 if BC>512 at input
;             A=2 if invalid length in final block
;             A=3 if invalid characters found

_USER_B64DEC:
	ld	hl,B64_DECB
	;jr      _USER_B64


	;*** Common code for USER_B64ENC and USER_B64DEC
	;    Input: HL = code to execute

_USER_B64:
	ld	(UB64_RUT+1),hl
	ld	(UB64_SOURCE),ix
	ld	(UB64_DEST),iy
	ld	(UB64_ISIZE),bc

	push	af
	push	bc
	pop	hl
	ld	de,513
	call	COMP
	jr	nc,UB64_OK1

	pop	af
	scf
	ld	a,1
	ret
UB64_OK1:

	call	SETUP_P2
	ld	a,#FF
	ld	(DISABLE_INT),a

	;--- Copy data from TPA

	ld	hl,(UB64_SOURCE)
	ld	de,OUT_BUFFER
	ld	a,b
	or	c
	call	nz,LDIR_ST

	;--- Encode or deacode

	pop	af	;Cy=Intermediate or final block
	ld	bc,(UB64_ISIZE)
	ld	ix,OUT_BUFFER
	ld	iy,IN_BUFFER
UB64_RUT:
	call	0	;B64_ENCB or B64_DECB
	jr	c,UB64_END

	;--- Copy resulting block to TPA

	push	hl,de,bc
	ld	hl,IN_BUFFER
	ld	de,(UB64_DEST)
	ld	a,b
	or	c
	call	nz,LDIR_TS

	;--- Set variables and terminate

	ld	hl,(UB64_SOURCE)
	ld	bc,(UB64_ISIZE)
	add	hl,bc
	push	hl
	pop	ix

	pop	bc
	ld	hl,(UB64_DEST)
	add	hl,bc
	push	hl
	pop	iy

	pop	de,hl	;Accumulated size
	xor	a
UB64_END:
	push	af
	xor	a
	ld	(DISABLE_INT),a
	pop	af
	call	RESTORE_P2
	ret

UB64_SOURCE:	dw	0
UB64_DEST:	dw	0
UB64_ISIZE:	dw	0


	if	LINK=0

	;====================
	;===  SEND_MODEM  ===
	;====================

;Send a command to modem.
;Input:  Cy = 0 to send command pointed by HL
;        Cy = 1 to send ATDT+number stored at BUF_DIAL
;        HL = Zero terminated comand address in TPA (if Cy=0)
;        DE = Address for modem response in TPA (0 if not required)
;        A  = Terminacion character for modem reply
;Output: A = 1 if reply is OK
;            2 if reply is ERROR
;            4 if reply contains the string BUF_MODREP
;            8 if error: Cy=1 but BUF_DIAL is empty
;
;If Cy=1 at  input and A<>4 at output, sets PPP_CLCODE to 1

_SEND_MODEM:
	push	de,af
	call	SETUP_P2
	ld	a,#FF
	ld	(DISABLE_INT),a
	pop	af
	push	af

	;--- Compose command to be sent

	ld	a,0	;Not XOR A, to not destroy Cy
	ld	(OUT_BUFFER+550),a
	jr	c,SENDMOD_2

	ld	de,OUT_BUFFER	;Command pointed by HL
	ld	bc,513
	call	LDIR_ST
	jr	SENDMOD_4

SENDMOD_2:
	ld	a,(BUF_DIAL)	;Is there a number to dial?
	or	a
	jr	nz,OK_DIALNUM
	pop	de,af
	ld	a,8
	jp	REPFND
OK_DIALNUM:
	ld	hl,#5441	;"ATDT"+BUF_DIAL
	ld	(OUT_BUFFER),hl
	ld	hl,#5444
	ld	(OUT_BUFFER+2),hl
	ld	de,OUT_BUFFER+4
	ld	hl,BUF_DIAL
	ld	a,(hl)
	or	32
	cp	"p"
	jr	nz,SENDMOD_3	;If first character es "P",
	dec	de	;use "ATDP"
SENDMOD_3:
	ld	bc,16
	ldir
SENDMOD_4:
	ld	a,#FF
	ld	(OUT_BUFFER+550),a

	;--- Clear reception buffer

	call	MOD_CLBUF

	;--- Check if echo is active.
	;    For this, send command AT and check if
	;    first character received is "A".

	ld	a,"A"
	call	RS_OUT
	ld	a,"T"
	call	RS_OUT
	ld	a,13
	call	RS_OUT

	call	WAIT_MODEM

	call	RS_IN
	sub	"A"	;0 if hay eco
	ld	(SMOD_NOECHO),a

SENDMOD_WOK:
	call	WAIT_MODEM	;Wait to receive "OK"
	call	RS_IN
	or	32
	cp	"k"
	jr	nz,SENDMOD_WOK

	call	WAIT_MODEM	;Skip final CRL
	call	RS_IN
	call	WAIT_MODEM
	call	RS_IN

	call	MOD_CLBUF

	;--- Send command to modem

	ld	hl,OUT_BUFFER
SMOD_LOOP1:
	ld	a,(hl)
	or	a
	jr	z,SMOD_SND13
	call	SEND_MCHAR
	inc	hl
	jr	SMOD_LOOP1
SMOD_SND13:
	ld	a,13
	call	SEND_MCHAR

	;--- Wait response

	call	WAIT_MODEM

	;--- Store response in OUT_BUFFER

	ld	hl,OUT_BUFFER-1
	ld	bc,0
SENDMOD_WR2:
	inc	hl
	inc	bc
	push	hl,bc
	call	RS_IN_STAT
	pop	bc,hl
	jr	z,SMOD_WR2END
	halt
	push	hl,bc
	call	RS_IN
	pop	bc,hl
	ld	(hl),a
	jr	SENDMOD_WR2

SMOD_WR2END:
	pop	af	;Termination character
	ld	(hl),a
	ld	(OUT_BUFFER+555),a

	;--- Copy response to TPA, if necessary

	pop	de
	ld	a,d
	or	e
	jr	z,NOCOPYREP

	ld	hl,OUT_BUFFER
SKIP_CRLF:
	ld	a,(hl)
	cp	32
	jr	nc,SKIP_CRLFEND
	inc	hl
	dec	bc
	jr	SKIP_CRLF
SKIP_CRLFEND:	;

	call	LDIR_TS
NOCOPYREP:	;

	;--- Check response and set A

	ld	hl,OUT_BUFFER
	ld	a,(OUT_BUFFER+555)
	ld	c,a
	xor	a
	ld	de,OK_S	;Es OK?
	ld	b,0
	scf
	call	INSTR
	jr	c,CHKREP1
	cp	4
	ld	a,1
	jr	c,REPFND
CHKREP1:

	ld	hl,OUT_BUFFER
	ld	a,(OUT_BUFFER+555)
	ld	c,a
	xor	a
	ld	de,ERROR_S	;ERROR?
	ld	b,0
	scf
	call	INSTR
	jr	c,CHKREP2
	cp	4
	ld	a,2
	jr	c,REPFND
CHKREP2:	;

	ld	hl,OUT_BUFFER
	ld	a,(OUT_BUFFER+555)
	ld	c,a
	xor	a
	ld	de,BUF_MODREP	;Equals BUF_MODREP?
	ld	b,0
	scf
	call	INSTR
	ld	a,4
	jr	nc,REPFND

	xor	a

	;--- If A<>4 and OUT_BUFFER+550=#FF, set PPP_CLCODE to 1

	ld	b,a
	ld	a,(OUT_BUFFER+550)
	or	a
	ld	a,b
	jr	z,REPFND

	cp	4
	jr	z,REPFND
	ld	b,a
	ld	a,1
	ld	(PPP_CLCODE),a
	ld	a,b

	;--- End

REPFND:	ld	b,a
	xor	a
	ld	(DISABLE_INT),a
	ld	a,b

	jp	RESTORE_P2

	;--- Send one character to modem, preserves HL

SEND_MCHAR:
	push	hl
	call	RS_OUT
	halt
	ld	a,(SMOD_NOECHO)
	or	a
	jr	nz,SEND_MCH_END
SEND_MCH_W:
	call	RS_IN_STAT
	jr	z,SEND_MCH_W
	call	RS_IN
SEND_MCH_END:
	pop	hl
	ret

	;--- Clear reception buffer

MOD_CLBUF:	call	RS_IN_STAT
	ret	z
	call	RS_IN
	jr	MOD_CLBUF

	;--- Wait until there is data available

WAIT_MODEM:
	call	RS_IN_STAT
	ret	nz
	halt
	jr	WAIT_MODEM

OK_S:		db	"OK",13,0
ERROR_S:	db	"ERROR",13,0
SMOD_NOECHO:	db	0


	;==================
	;===  PPP_OPEN  ===
	;==================

;Open a PPP connection, unless it is already open

_PPP_OPEN:
	call	SETUP_P2
	ld	a,(PPP_STATE)
	or	a
	jp	nz,RESTORE_P2

	;--- Clear ICMP and UDP information area

	ld	a,#FF
	ld	(DISABLE_INT),a

	ld	hl,PACKINFO_START
	ld	de,PACKINFO_START+1
	ld	bc,PACKINFO_END-PACKINFO_START-1
	ld	(hl),0
	ldir

	;--- Initialize variables

	ld	hl,0
	ld	(INBUF_PNT),hl
	ld	(XCP_RTIMER),hl
	ld	hl,60*60
	ld	(XCP_TTIMER),hl
	xor	a
	ld	(XCP_ACKS),a
	ld	(USE_VJ_OUT),a
	ld	(AUTH_PROTO),a
	cpl
	ld	(TOSS_FLAG),a
	ld	(VJ_LAST_OSLOT),a
	ld	(VJ_LAST_ISLOT),a
	ld	a,3
	ld	(XCP_NEXTOP),a
	ld	hl,576
	ld	(NEXT_MRU),hl
	ld	hl,0
	ld	(NEXT_ASYNC),hl
	ld	(NEXT_ASYNC+2),hl
	ld	a,(USEPPPVJ)
	ld	(USE_VJ_IN),a

	ld	a,1
	ld	(PPP_STATE),a
	ld	a,#FF
	ld	(PPP_COMP_P),a
	ld	(PPP_COMP_FF),a

	xor	a
	ld	(DISABLE_INT),a

	call	RESTORE_P2
	ret


	;===================
	;===  PPP_CLOSE  ===
	;===================

;Close a PPP connection, unless it is already closed

_PPP_CLOSE:
	call	SETUP_P2
	ld	a,(PPP_STATE)
	or	a
	jp	z,RESTORE_P2

	di
	call	SEND_TREQ
	xor	a
	ld	(PPP_STATE),a
	ld	(PCAP_STATE),a
	call	CLOSE_ALL_TCP
	ld	a,2
	ld	(PPP_CLCODE),a
	call	RESTORE_P2
	ei
	ret

	endif


	;===================
	;===  SEND_ECHO  ===
	;===================

;Send an ICMP Echo Request message.
;Input:  L.H.E.D. = Destination IP
;        A = TTL
;        IX = Identifier
;        IY = Sequence number
;        BC = Data length (-1: use PING_SIZE)
;Output: Cy = 1 if error (no network connection)

_SEND_ECHO:
	call	SETUP_P2

	push	bc
	ld	b,a
	call	IS_CONNECTED
	ld	a,b
	pop	bc
	scf
	jp	nz,RESTORE_P2

	ex	af,af
	ld	a,#FF
	ld	(DISABLE_INT),a
	ex	af,af

	;--- Compose packet to send

	push	af,hl,de

	ld	hl,#0008	;Type and code
	ld	(OUT_BUFFER+24),hl
	ld	hl,0
	ld	(OUT_BUFFER+26),hl	;Checksum, initially 0
	ld	a,ixh
	ld	(OUT_BUFFER+28),a	;Identifier
	ld	a,ixl
	ld	(OUT_BUFFER+29),a
	ld	a,iyh
	ld	(OUT_BUFFER+30),a	;Sequence number
	ld	a,iyl
	ld	(OUT_BUFFER+31),a

	inc	bc
	ld	a,b
	or	c
	dec	bc
	jr	nz,NO_PING64

	ld	bc,(PING_SIZE)
NO_PING64:
	push	bc
	ld	a,b
	or	c
	jr	z,SECHO_OKDATA

	xor	a
	ld	hl,OUT_BUFFER+32
SECHO_LOOP:
	ld	(hl),a	;Compose the data part
	inc	a
	inc	hl
	dec	bc
	ld	d,a
	ld	a,b
	or	c
	ld	a,d
	jr	nz,SECHO_LOOP

SECHO_OKDATA:
	pop	bc	;Recover length and add ICMP header length
	ld	hl,8
	add	hl,bc
	push	hl
	pop	bc
	push	bc
	ld	ix,OUT_BUFFER+24
	call	CALC_CHKSUM
	ld	(OUT_BUFFER+26),de	;Checksum

	;--- Send IP datagram

	pop	bc,de,hl
	ld	a,(TTL)
	ld	(SAVE_TTL),a
	pop	af
	ld	(TTL),a
	ld	a,1	;ICMP protocolo

	call	SEND_IP
	ld	a,(SAVE_TTL)
	ld	(TTL),a

	;--- End

	xor	a
	ld	(DISABLE_INT),a
	call	RESTORE_P2
	ret

SAVE_TTL:	db	0


	;==================
	;===  RCV_ECHO  ===
	;==================

;Obtain the oldest queued ICMP Echo Reply message.
;Input:  -
;Output: L.H.E.D. = Source IP
;        A = TTL
;        IX = Identifier
;        IY = Sequence number
;        BC = Data length
;        Cy = 1 if no available packets

_RCV_ECHO:
	call	SETUP_P2

	ld	a,#FF
	ld	(DISABLE_INT),a

	ld	a,(ICMPI_GINDEX)
	ld	b,a

	inc	b
	ld	ix,ICMPI_IP0-11
	ld	de,11
BUC_EREP2:
	add	ix,de
	djnz	BUC_EREP2	;Now IX points to the appropriate data area

	ld	a,(ICMPI_PINDEX)
	ld	b,a
	ld	a,(ICMPI_GINDEX)
	cp	b
	jr	nz,EREP_HAYECOS

	ld	a,(ix)	;Index GET = Index PUT:
	or	(ix+1)	;There are echoes if entry is not empty (IP<>0),
	or	(ix+2)	;otherwise, terminate with error.
	or	(ix+3)
	scf
	jr	z,END_RCV_ECHO
EREP_HAYECOS:

	ld	l,(ix)	;Source IP
	ld	h,(ix+1)
	ld	e,(ix+2)
	ld	d,(ix+3)
	ld	(ix),0	;Put zeros to free entry
	ld	(ix+1),0
	ld	(ix+2),0
	ld	(ix+3),0

	ld	a,(ix+4)	;TTL

	ld	c,(ix+9)	;Data size
	ld	b,(ix+10)

	exx
	ld	l,(ix+5)	;Identifier
	ld	h,(ix+6)
	ld	e,(ix+7)	;Sequence number
	ld	d,(ix+8)

	push	hl,de
	pop	iy,ix
	exx

	ex	af,af	;Increases entry index, wrapping from 7 to 0
	ld	a,(ICMPI_GINDEX)
	inc	a
	and	%111
	ld	(ICMPI_GINDEX),a
	ex	af,af

	or	a	;End with no error

END_RCV_ECHO:
	push	af
	xor	a
	ld	(DISABLE_INT),a
	call	RESTORE_P2
	pop	af
	ret


	;==================
	;===  UDP_SEND  ===
	;==================

;Send an UDP packet
;Input:  L.H.E.D. = Destination IP
;        IX = Source port
;        IY = Destination port
; 	BC = Data address in TPA
;        AF = Data length (up to 548 bytes)
;Output: Cy = 1 if no network connection or too big packet

_UDP_SEND:
	call	SETUP_P2
	push	af
	call	IS_CONNECTED
	jr	z,UDPS_OKNET

UDPS_ERR:
	pop	af
	call	RESTORE_P2
	scf
	ret

	;Valid length?

UDPS_OKNET:
	ex	(sp),hl	;Now, IP in stack and length in HL
	push	de
	ld	de,549	;Max. data length = 548 bytes
	call	COMP
	pop	de
	jr	c,UDPS_ERR

	ld	a,#FF
	ld	(DISABLE_INT),a

	ld	a,h
	or	l
	jr	z,UDPS_OKCOPY

	;Copy data to OUT_BUFFER+32

	push	de,ix,iy,hl	;To stack: IP,ports,length
	push	hl,bc	;Exchanges HL and BC:
	pop	hl,bc	;now HL = Source in TPA, BC = Length
	ld	de,OUT_BUFFER+32
	call	LDIR_ST
	pop	hl,iy,ix,de
UDPS_OKCOPY:

	;Send IP datagram

	push	hl
	pop	bc	;BC = Length
	pop	hl	;HL and DE = IP
	call	SEND_UDP

	xor	a
	ld	(DISABLE_INT),a

	call	RESTORE_P2
	or	a
	ret


	;=================
	;===  UDP_RCV  ===
	;=================

;Obtain the oldest received UDP datagram
;Input: HL = Destination address for data in TAP
;            (0 if data not required)
;Output: L.H.E.D. = Source IP
;        IX = Source port
;        IY = Destination port
;        BC = Data length
;        Cy = 1 if no available packets

_UDP_RCV:
	call	SETUP_P2

	ld	a,#FF
	ld	(DISABLE_INT),a

	ld	a,(UDPI_GINDEX)
	ld	b,a

	inc	b
	ld	ix,UDPI_IP0-10
	ld	de,10
BUC_UDP2:
	add	ix,de
	djnz	BUC_UDP2	;Now IX points to the appropriate data area

	ld	a,(UDPI_PINDEX)
	ld	b,a
	ld	a,(UDPI_GINDEX)
	cp	b
	jr	nz,UDP_HAYALGOS

	ld	a,(ix)	;Index GET = Index PUT:
	or	(ix+1)	;There are packets if entry is not empty (IP<>0),
	or	(ix+2)	;otherwise, terminate with error.
	or	(ix+3)
	scf
	jr	z,END_UDP_RCV
UDP_HAYALGOS:	;

	ld	c,(ix+8)	;Data length
	ld	b,(ix+9)
	ld	a,h	;Data required?
	or	l
	jr	z,UDP_OKGDATA
	ld	a,b	;Data available?
	or	c
	jr	z,UDP_OKGDATA

	ex	de,hl	;Copy data to TPA
	push	de,bc
	ld	hl,UDP_BUFFERS-556
	ld	de,556
	ld	a,(UDPI_GINDEX)
	inc	a
	ld	b,a
UDPLEN_LOP2:
	add	hl,de
	djnz	UDPLEN_LOP2
	pop	bc,de
	push	ix,bc
	call	LDIR_TS
	pop	bc,ix

UDP_OKGDATA:
	ld	l,(ix)	;Source IP
	ld	h,(ix+1)
	ld	e,(ix+2)
	ld	d,(ix+3)
	ld	(ix),0	;Put zeros to free entry
	ld	(ix+1),0
	ld	(ix+2),0
	ld	(ix+3),0

	exx
	ld	l,(ix+4)	;Source port
	ld	h,(ix+5)
	ld	e,(ix+6)	;Destination port
	ld	d,(ix+7)

	push	hl,de
	pop	iy,ix
	exx

	push	hl,bc
	ld	hl,UDPI_GINDEX
	call	INC_UDPINDEX	;Increase entry index, wrapping from 7 to 0
	pop	bc,hl

	xor	a	;End with no error

END_UDP_RCV:
	push	af
	xor	a
	ld	(DISABLE_INT),a
	call	RESTORE_P2
	pop	af
	ret


	;===============
	;===  DNS_Q  ===
	;===============

;Performs a DNS query.
;Input: HL = Pointer to zero terminated name to resolve in TPA (max 255 chars)
;         A  = Flags:
;              bit 0: Only cancel query in progress
;                     (ignores all other flags and registers)
;              bit 1: Do NOT query DNS servers
;                     (assume name is an IP address)
;              bit 2: If a query is already in progress, do NOT cancel it
;                     (return an error instead)
;Output:  Cy=1 and A=error:
;                1: No network connection
;                2: A query is already in progress (only if A:0 set)
;                3: Not a valid IP address (only if A:1 set)
;                4: No DNS server addresses configured
;         Cy=0 and A=result:
;                0: OK, query in progress (or cancelled, if A:0 set)
;                1: OK, name was an IP address
;         HL, DE: IP address (only if A=1 at output)
;                 with this format formato: L.H.E.D

	if	LINK=0

DNSQ_FLAGS:	equ	#8C7E+100	;OUT_BUFFER+100
DNSQ_HL:	equ	#8C7E+101	;OUT_BUFFER+101

	endif

	if	LINK=1

DNSQ_FLAGS:	equ	#8980+100	;OUT_BUFFER+100
DNSQ_HL:	equ	#8980+101	;OUT_BUFFER+101

	endif

_DNS_Q:	call	SETUP_P2
	ld	(DNSQ_HL),hl
	ld	(DNSQ_FLAGS),a
	call	IS_CONNECTED
	jr	z,DNSQ_OKNET

	call	RESTORE_P2
	scf
	ld	a,1
	ret

DNSQ_OKNET:
	ld	a,#FF
	ld	(DISABLE_INT),a

	;--- Only cancel query in progress?

	ld	a,(DNSQ_FLAGS)
	and	%00000001
	jr	z,DNSQ_NOAB
	ld	a,3
	ld	(DNS_STAT_P),a
	ld	a,18
	ld	(DNS_STAT_S),a
	or	a
	jp	DNSQ_END
DNSQ_NOAB:	;

	;--- A query is in progress already?

	ld	a,(DNSQ_FLAGS)
	and	%00000100
	jr	z,IP_DNSQ2

	ld	a,(DNS_STAT_P)	;If A:2=1 and query is in progress,
	cp	1	;return error 2
	ld	a,2
	scf
	jp	z,DNSQ_END
IP_DNSQ2:

	;--- Obtain name to resolve,
	;    and first check if it is an IP address

	xor	a	;Cancel query in progress, if any
	ld	(DNS_STAT_P),a
	ld	(DNS_STAT_S),a

	ld	hl,(DNSQ_HL)	;Copy string to DNS_BUFFER,
	ld	de,DNS_BUFFER	;oly first 255 bytes
	ld	bc,255
	call	LDIR_ST
	xor	a
	ld	(DNS_BUFFER+255),a

	call	PARSE_IP
	jr	c,IP_DNSQ3

	ld	a,2	;If name was an IP address, return it
	ld	(DNS_STAT_P),a	;and set state as prim=2, sec=1
	dec	a
	ld	(DNS_STAT_S),a
	or	a
	ld	hl,(DNS_RESULT)
	ld	de,(DNS_RESULT+2)
	or	a
	jp	DNSQ_END

IP_DNSQ3:
	ld	a,(DNSQ_FLAGS)	;If not a valid IP address and "do not query servers"
	and	%00000010	;was specified, return error 3
	scf
	ld	a,3
	jp	nz,DNSQ_END

	;--- Check if there is any DNS server configured,
	;    if not, terminate with error 4

	ld	ix,BUF_IPDNS1
	ld	a,(ix)
	or	(ix+1)
	or	(ix+2)
	or	(ix+3)
	or	(ix+4)
	or	(ix+5)
	or	(ix+6)
	or	(ix+7)
	scf
	ld	a,4
	jp	z,DNSQ_END

	;--- Prepares variables so that query will start
	;    in the next timer interrupt

	xor	a
	ld	(DNS_RETRY),a
	inc	a
	ld	(DNS_TOUT),a
	ld	hl,60*60
	ld	(DNS_TTOUT),hl

	ld	a,1
	ld	(DNS_STAT_P),a
	ld	hl,BUF_IPDNS1
	push	hl
	pop	ix
	ld	a,(ix)
	or	(ix+1)
	or	(ix+2)
	or	(ix+3)
	ld	a,1
	jr	nz,DNSQ_NOINC
	ld	hl,BUF_IPDNS2
	inc	a
DNSQ_NOINC:
	ld	(DNS_STAT_S),a
	ld	de,DNS_IP
	ld	bc,4
	ldir

	xor	a

	;--- End

DNSQ_END:
	push	af,hl,de
	xor	a
	ld	(DISABLE_INT),a
	call	RESTORE_P2
	pop	de,hl,af
	ret


	;===============
	;===  DNS_R  ===
	;===============

;Return the state of a DNS query
;Input:   A  = Flags:
;              bit 0: Clear any existing result/error after the call
;                     (unless state is 1)
;Output:  A  = Primary state code
;         B  = Secondary state code
;         A  = 0: No query in progress nor result available
;              1: Query in progress
;                 B=1: Querying primary DNS server
;                 B=2: Querying secondary DNS server
;                 B=3: Querying another DNS server (we were redirected)
;              2: Query completed, result is returned in HL, DE
;                 en formato L.H.E.D
;                 B=0: Name was not an IP address
;                 B=1: Name was an IP address
;              3: Error:
;                 B=1-15: Error returned by DNS server
;                 B=16: DNS server did not reply
;                 (DNS_RETRY_V petitions were sent with no reply)
;                 B=17: Total timeout expired
;                 B=18: Query cancelled by user
;                 B=19: Network connection lost
;                 B=20: Answer did not contain REPLY nor AUTHORITATIVE
;                 B=21: Answer is truncated

_DNS_R:	call	SETUP_P2
	ld	c,a

	call	IS_CONNECTED	;If not connected but there seems
	jr	z,DNS_R2	;to be a query in progress,
	ld	a,(DNS_STAT_P)	;set error 19
	cp	1
	jr	nz,DNS_R2
	ld	a,3
	ld	(DNS_STAT_P),a
	ld	a,19
	ld	(DNS_STAT_S),a
DNS_R2:

	ld	a,(DNS_STAT_S)
	ld	b,a
	ld	a,(DNS_STAT_P)
	ld	hl,(DNS_RESULT)
	ld	de,(DNS_RESULT+2)
	bit	0,c
	jp	z,RESTORE_P2

	push	af	;A=1 and no query in progress:
	ld	a,(DNS_STAT_P)	;clear result
	cp	1
	jr	z,DNS_R_2
	xor	a
	ld	(DNS_STAT_P),a
	ld	(DNS_STAT_S),a
DNS_R_2:	pop	af

	jp	RESTORE_P2


	;==================
	;===  TCP_OPEN  ===
	;==================

;Open a new TCP connection.
;Input:  A = 0 for active, 1 for passive
;        L.H.E.D = remote IP (0.0.0.0 for passive with unespecified remote socket)
;        IX = Remote port (ignored if IP=0.0.0.0)
;        IY = Local port (#FFFF for random between 16384 and 32767)
;        BC = Usuer timeout in seconds
;             (1-1080, 0 for 3 minutes, #FFFF for infinite)
;Output: Cy=0 if OK, 1 if error
;        If OK: A = Connection number
;        If error: A = Error code:
;           1: Too many connections open
;           2: No network connection
;           3: Connection already exists
;           4: Active connection but IP was 0.0.0.0
;           5: Invalido value of BC

_TCP_OPEN:
	call	SETUP_P2

	;--- Sotre input parameters in temporary TCB

	push	af
	ld	a,#FF
	ld	(DISABLE_INT),a
	pop	af
	ld	(PASSIVE_OPEN),a
	ld	(REMOTE_IP),hl
	ld	(REMOTE_IP+2),de
	ld	(REMOTE_PORT),ix
	ld	(LOCAL_PORT),iy

	push	bc
	ld	hl,TCB_TEMP+10	;Clear the rest of TCB
	ld	de,TCB_TEMP+11
	ld	bc,TCB_SIZE-10-1
	ld	(hl),0
	ldir

	pop	hl	;User timeout: check value
	ld	de,#FFFF	;If #FFFF (infinite), do not modify
	call	COMP
	jr	z,UTOUT_OK

	ld	a,h
	or	l
	jr	nz,TCPOP_BCNOZ
	ld	hl,UTOUT_DEF	;3 minutes
TCPOP_BCNOZ:
	ld	de,1080
	call	COMP	;Cy if HL>=DE
	jr	nc,TCPOP_OKBC
	ld	a,5
	scf
	jp	TCP_OPEND
TCPOP_OKBC:

	;--- Multiply user timeout by 60

	add	hl,hl	;*2
	add	hl,hl	;*4
	push	hl
	add	hl,hl	;*8
	push	hl
	add	hl,hl	;*16
	push	hl
	add	hl,hl	;*32
	pop	bc
	add	hl,bc	;*(32+16)
	pop	bc
	add	hl,bc	;*(32+16+8)
	pop	bc
	add	hl,bc	;*(32+16+8+4) = *60
UTOUT_OK:
	ld	(USER_TOUT_V),hl

	;--- Network connection available?

	call	IS_CONNECTED
	jr	z,TCPOP_OKNET

	ld	a,2
	scf
	jp	TCP_OPEND
TCPOP_OKNET:

	;--- Active connection with zero IP?

	call	TCP_IS_ZERO
	jr	nz,TCPOP_OKIP

	ld	hl,0	;Also set remote port to 0 if IP is zero
	ld	(REMOTE_PORT),hl

	ld	a,(PASSIVE_OPEN)	;Here, IP is cero
	or	a
	jr	nz,TCPOP_OKIP

	ld	a,4
	scf
	jp	TCP_OPEND
TCPOP_OKIP:

	;--- Free connections available?

	call	SEARCH_FRTCP
	cp	#FF
	jr	nz,TCPOP_OKFREE

	ld	a,1
	scf
	jp	TCP_OPEND

TCPOP_OKFREE:
	ld	(CURTCB_NUM),a	;Store connection number

	;--- If local port is #FFFF, pick a random one
	;    in thel range 16384-32767 (#4000-#7FFF)

	xor	a
	ld	(RAND_PORT),a
	ld	hl,(LOCAL_PORT)
	ld	de,#FFFF
	call	COMP
	jr	nz,TCPOP_OKPORT

	ld	a,#FF
	ld	(RAND_PORT),a
TCPOP_RNDPORT:
	ld	hl,(SYSTIMER)	;Use system timer
	res	7,h	;Transforma to appropriate range
	set	6,h
	ld	(LOCAL_PORT),hl
TCPOP_OKPORT:

	;--- Check if connection exists
	;    (unless remote IP is not specified)

	call	TCP_IS_ZERO
	jr	z,TCPOP_OKEX

	ld	hl,(REMOTE_IP)
	ld	de,(REMOTE_IP+2)
	ld	ix,(REMOTE_PORT)
	ld	iy,(LOCAL_PORT)
	call	SEARCH_TCP
	cp	#FF
	jr	z,TCPOP_OKEX

	;Connection exist: if port was random
	;pick another one; if not, return error

	ld	a,(RAND_PORT)
	or	a
	jr	nz,TCPOP_RNDPORT

	ld	a,3
	scf
	jr	TCP_OPEND
TCPOP_OKEX:

	;>> At this point parameters are all OK:
	;>> We can open connection

	;--- Initialize data buffers

	ld	hl,#A000-2048	;Calculate buffer address:
	ld	de,2048	;#A000+2048*connection number
	ld	a,(CURTCB_NUM)
	inc	a
	ld	b,a
CURTCB_BUFLOP:
	add	hl,de
	djnz	CURTCB_BUFLOP

	push	hl
	ld	bc,1024
	ld	ix,INBUF	;Incoming data buffer
	call	RBUF_INIT

	pop	hl
	ld	bc,1024
	add	hl,bc	;Outgoing data buffer, 1024 bytes later
	ld	ix,OUTBUF
	call	RBUF_INIT

	;--- If passive connection, enter LISTEN state and terminate

	ld	a,(PASSIVE_OPEN)
	or	a
	jr	z,TCPOP_NOPAS

	ld	a,LISTEN
	ld	(TCP_STATE),a
	jr	TCP_OPEND2
TCPOP_NOPAS:

	;--- Active: send SYN segment, enter SYN-SENT state and terminate

	ld	a,2
	call	SEND_SYN
	ld	a,SYN.SENT
	ld	(TCP_STATE),a

	;Set SND.UNA to ISS: not necessary, both are 0 already
	;Set SND.NXT to ISS+1:
	ld	a,1
	ld	(SND_NXT+3),a

	ld	a,RTO_V*60	;Initialize timers
	ld	(RTO_T),a
	ld	hl,(USER_TOUT_V)
	ld	(USER_TOUT),hl


TCP_OPEND2:
	call	SAVE_TCB
	ld	a,(CURTCB_NUM)	;Connection number must be returned
	or	a
TCP_OPEND:
	push	af
	xor	a
	ld	(DISABLE_INT),a

	pop	af
	jp	RESTORE_P2

RAND_PORT:	db	0



	;===================
	;===  TCP_CLOSE  ===
	;===================

;Close a TCP connection
;Input:  A = Connection number
;Output: Cy=1 if error, then A=error code:
;             1: Invalid connection number
;             2: Connection already closed

_TCP_CLOSE:
	call	SETUP_P2

	;--- Check error conditions

	ld	b,a
	call	CHK_TCP_EXIST
	jp	c,RESTORE_P2

	;--- Load TCB and act according to connection state

	ld	a,#FF
	ld	(DISABLE_INT),a
	ld	a,b

	call	LOAD_TCB
	ld	a,(TCP_STATE)

	;> LISTEN or SYN-SENT (1 or 2): Simply clear TCB

	cp	3
	jr	nc,TCP_CL_1

	xor	a
	ld	(TCP_STATE),a
	ld	a,1
	ld	(LAST_CLOSE),a
	jr	TCP_CL_END
TCP_CL_1:

	;> SYN-RECEIVED or ESTABLISHED (3 or 4): enter FIN-WAIT-1
	;  and set FIN_PENDING

	cp	5
	jr	nc,TCP_CL_2

	ld	a,#FF
	ld	(FIN_PENDING),a
	ld	a,FIN.WAIT.1
	ld	(TCP_STATE),a
	xor	a
	ld	(SYN_SENT_FLAG),a
	jr	TCP_CL_PEND
TCP_CL_2:

	;> CLOSE_WAIT: Set FIN_PENDING

	cp	CLOSE.WAIT
	jr	nz,TCP_CL_END

TCP_CL_PEND:
	ld	a,#FF
	ld	(FIN_PENDING),a

	;> In other states do nothing and terminate

TCP_CL_END:	call	SAVE_TCB

	xor	a
	ld	(DISABLE_INT),a
	jp	RESTORE_P2


	;===================
	;===  TCP_ABORT  ===
	;===================

;Abort a TCP connection
;Input:  A = Connection number
;Output: Cy=1 if error, then A=error code:
;             1: Invalid connection number
;             2: Connection already closed

_TCP_ABORT:
	call	SETUP_P2

	ld	b,a
	call	CHK_TCP_EXIST	;Check error conditions
	jp	c,RESTORE_P2

	ld	a,#FF
	ld	(DISABLE_INT),a
	ld	a,b

	;--- Load connection TCB, clear it,
	;    and send RST state was SYN-RECEIVED to CLOSE-WAIT

	call	LOAD_TCB
	ld	a,(TCP_STATE)
	push	af
	xor	a
	ld	(TCP_STATE),a
	ld	a,2
	ld	(LAST_CLOSE),a
	call	SAVE_TCB
	pop	af

	cp	3	;SYN-RECEIVED=3, CLOSE-WAIT=7
	jr	c,TCP_AB_OK
	cp	8
	ld	a,0
	call	c,SEND_RST

TCP_AB_OK:
	xor	a
	ld	(DISABLE_INT),a
	jp	RESTORE_P2


	;==================
	;===  TCP_SEND  ===
	;==================

;Send data to a TCP connection
;Input:  A = Connection number
;        HL = Data address in TPA
;        BC = Data length
;        Cy=1 for PUSH
;Output: Cy=1 if error, then A=error code:
;           1: Invalido connection number
;           2: Connection is closed
;           3: Connection state is not valid for sending data
;           4: Not enough buffer space to store data

_TCP_SEND:
	call	SETUP_P2

	ld	(TCP_SEND_HL),hl
	ld	(TCP_SEND_BC),bc
	push	af
	pop	de	;D = Connection number
	ld	a,e
	and	1
	ld	(TCP_SEND_CY),a

	;--- Check error conditions 1 and 2

	ld	a,d
	call	CHK_TCP_EXIST
	jp	c,RESTORE_P2

	ld	a,#FF
	ld	(DISABLE_INT),a

	;--- Load connection TCB and check other parameters

	ld	a,d
	call	LOAD_TCB

	ld	a,(FIN_PENDING)
	or	a
	jr	nz,TCP_SND_ERR4
	ld	a,(TCP_STATE)	;Check that it is ESTABLISHED o CLOSE_WAIT
	cp	ESTABLISHED
	jr	z,TCP_SND_OK1
	cp	CLOSE.WAIT
	jr	z,TCP_SND_OK1

TCP_SND_ERR4:
	ld	a,3	;Error not a valid state
	scf
	jr	TCP_SND_END
TCP_SND_OK1:

	ld	hl,(OUTBUF_USED)
	ld	(TCP_SND_OLDUSED),hl	;We'll use it to set SEND_TOUT

	ld	de,(TCP_SEND_BC)	;Check that there is enough buffer space
	ld	a,d
	or	e
	jr	z,TCP_SND_OK3
	ld	hl,(OUTBUF_FREE)
	call	COMP
	jr	c,TCP_SND_OK2

	ld	a,4	;Error if not enough buffer space
	scf
	jr	TCP_SND_END
TCP_SND_OK2:

	;--- Obtain data, queue it,
	;    and set SEND_PUSH_PEND if necesary

	ld	hl,(TCP_SEND_HL)
	ld	de,IN_BUFFER	;Use IN_BUFFER+OUT_BUFFER, which is >1024 bytes
	ld	bc,(TCP_SEND_BC)
	call	LDIR_ST

	ld	ix,OUTBUF	;Insert data in circular buffer
	ld	hl,IN_BUFFER
	ld	bc,(TCP_SEND_BC)
	call	RBUF_INSERT

TCP_SND_OK3:	;Jump here if there are 0 bytes to send
	ld	a,(TCP_SEND_CY)	;PUSH?
	or	a
	jr	z,TCP_SND_OK4
	ld	hl,(OUTBUF_USED)
	ld	(SEND_PUSH_PEND),hl
TCP_SND_OK4:

	ld	hl,(TCP_SND_OLDUSED)	;If output queue was empty,
	ld	a,h	;initialize 0.5 secs counter for sending
	or	l
	jr	nz,TCP_SND_OK5
	ld	hl,SEND_TOUT_V	;0.5 seconds
	ld	(SEND_TOUT),hl
TCP_SND_OK5:

	;--- Restore state and terminate

	call	SAVE_TCB
	xor	a

TCP_SND_END:
	push	af
	xor	a
	ld	(DISABLE_INT),a
	pop	af
	jp	RESTORE_P2

TCP_SEND_HL:	dw	0
TCP_SEND_BC:	dw	0
TCP_SEND_CY:	db	0
TCP_SND_OLDUSED:	dw	0


	;=================
	;===  TCP_RCV  ===
	;=================

;Obtain data from a TCP connection
;Input:  A  = Connection number
;        DE = Destination address for data
;        BC = Data length
;Output: Cy=1 if error, then A=error code:
;             1: Invalid connection number
;             2: Connection is closed
;        BC = Actual obtained data length
;        Z = 1 if BC=0

_TCP_RCV:
	call	SETUP_P2

	;--- Check error conditions 1 and 2

	ld	h,a
	push	hl
	call	CHK_TCP_EXIST
	pop	hl
	jr	nc,TCP_RCV2
	ld	bc,0
	jr	TCP_RCV_END
TCP_RCV2:

	ld	a,#FF
	ld	(DISABLE_INT),a

	;--- Load connection TCB and check other parameters

	ld	a,h
	push	de,bc
	call	LOAD_TCB

	;--- Extract data and copy to TPA

	pop	bc,de
	ld	a,b
	or	c
	jr	z,TCP_RCV_OK2
	push	de
	ld	ix,INBUF
	ld	de,IN_BUFFER	;Uses OUT_BUFFER+IN_BUFFER, which is >1024 bytes
	call	RBUF_EXTRACT
	jr	nc,TCP_RCV_OK1

	pop	de	;Error if no data available
	ld	bc,0
	jr	TCP_RCV_OK2

TCP_RCV_OK1:
	ld	hl,IN_BUFFER	;Copy data to TPA
	pop	de
	push	bc
	call	LDIR_TS

	;--- Schedule an ACK if the window size to announce
	;    is different from the last one announced

	ld	hl,(ACK_RCV_NUM)	;Not necessary if there is an shceduled ACK already
	ld	a,h
	or	l
	jr	nz,RCV_NO_ACK

	call	CALC_RCV_WIN
	ld	de,(LAST_WIN_SENT)
	call	COMP
	jr	z,RCV_NO_ACK

	;* Schedule an ACK

	call	SCHEDULE_ACK

RCV_NO_ACK:
	pop	bc

	;--- Update TCB and terminate

TCP_RCV_OK2:	push	bc
	call	SAVE_TCB
	pop	bc
	xor	a

TCP_RCV_END:	push	af
	xor	a
	ld	(DISABLE_INT),a
	pop	hl
	res	6,l	;NZ if L es F
	ld	a,b
	or	c
	jr	nz,TCP_RCV_END2
	set	6,l	;Z if L es F
TCP_RCV_END2:	push	hl
	pop	af
	jp	RESTORE_P2


	;====================
	;===  TCP_STATUS  ===
	;====================

;Obtain the state of a TCP connection
;Input:  A = Connection number
;Output: Cy=1 if error, then A=error codigo:
;           1: Invalid connection number
;        Cy=0 if OK, and:
;        A = Connection state
;        HL = Available received bytes
;        DE = Available space for outgoing bytes
;        BC = Bytes in retransmission queue
;        IX = Connection TCB address in data segment
;        (If A=0, B=LAST_CLOSE)

_TCP_STATUS:
	call	SETUP_P2

	;--- Check error conditions

	ld	b,a
	ld	a,#FF
	ld	(DISABLE_INT),a
	ld	a,b
	call	CHK_TCP_EXIST
	jr	nc,TCP_STATOK
	cp	2	;Error 2 is not an error in this case
	jp	c,TCP_STAT_END
TCP_STATOK:	;

	;--- Load connection TCB, and obtain parameters

	ld	a,b
	call	LOAD_TCB
	ld	a,(LAST_CLOSE)
	ld	b,a
	ld	a,(TCP_STATE)
	or	a
	jp	z,TCP_STAT_END	;If closed, no parameters to obtain

	ld	a,(CURTCB_NUM)
	call	GET_TCB_DIR
	push	hl
	pop	ix

	ld	hl,(INBUF_USED)
	ld	de,(OUTBUF_FREE)
	ld	bc,(RETX_SIZE)
	ld	a,(TCP_STATE)

	or	a

TCP_STAT_END:
	push	af
	xor	a
	ld	(DISABLE_INT),a
	pop	af
	jp	RESTORE_P2


	;===================
	;===  TCP_FLUSH  ===
	;===================

;Clear outgoing data not yet sent on a TCP connection
;Input:  A = Connection number
;Output: Cy=1 if error, then A=error codigo:
;           1: Invalid connection number
;           2: Connection is closed
;        Cy=0 and A=0 if OK

_TCP_FLUSH:	call	SETUP_P2

	;--- Check error conditions 1 and 2

	ld	b,a
	call	CHK_TCP_EXIST
	jp	c,RESTORE_P2

	ld	a,#FF
	ld	(DISABLE_INT),a

	;--- Load connection TCB

	ld	a,b
	call	LOAD_TCB

	;--- If no pending outgoing data,
	;    or if retransmission data exists only, terminate

	ld	hl,(OUTBUF_USED)
	ld	a,h
	or	l
	jp	z,TCP_FLUSH_END

	ld	de,(RETX_SIZE)
	call	COMP
	jp	z,TCP_FLUSH_END

	;--- If there is data to be retransmitted,
	;    store it to not lose it when initializing buffer

	ld	bc,(RETX_SIZE)
	ld	a,b
	or	c
	jr	z,TCP_FLUSH1

	ld	ix,OUTBUF
	ld	de,IN_BUFFER
	call	RBUF_PEEK
TCP_FLUSH1:

	;--- Initialize output buffer, by erasing all contents

	ld	ix,OUTBUF
	ld	hl,(OUTBUF_BUFADD)
	ld	bc,1024
	call	RBUF_INIT

	;--- If there was retransmission data, insert it
	;    again at output buffer

	ld	bc,(RETX_SIZE)
	ld	a,b
	or	c
	jr	z,TCP_FLUSH2

	ld	ix,OUTBUF
	ld	hl,OUT_BUFFER
	call	RBUF_INSERT
TCP_FLUSH2:

	;--- If there was PUSH data, update SEND_PUSH_PEND

	ld	hl,(SEND_PUSH_PEND)
	ld	a,h
	or	l
	jr	z,TCP_FLUSH3

	ld	hl,(OUTBUF_USED)
	ld	(SEND_PUSH_PEND),hl
TCP_FLUSH3:

	;--- End

	call	SAVE_TCB
TCP_FLUSH_END:
	xor	a
	ld	(DISABLE_INT),a
	jp	RESTORE_P2


	;==================
	;===  RAW_SEND  ===
	;==================

;Send a raw datagram
;Input:  Cy = 0: Datagram does not include IP header
;        Cy = 1: Datagram includes IP header already
;        IX = Packet address in TPA
;        BC = Datagram length (up to 576 if Cy=0, up to 556 if Cy=1)
;        L.H.E.D = Destination IP (if Cy=0)
;        A = Transport protocol (if Cy=0)
;        IYh = TOS (if Cy=0)
;        IYl = TTL (if Cy=0)
;Output: Cy=1 and A=Error:
;           1: No network connection
;           2: Invalid datagram size

_RAW_SEND:
	ld	(RAW_A),a
	ld	a,0
	rla
	ld	(RAW_CY),a

	;--- Check size

	push	de,hl
	push	bc
	pop	hl
	ld	a,(RAW_CY)
	or	a
	ld	de,557
	jr	z,RAW_SEND2
	ld	de,577
RAW_SEND2:
	call	COMP
	jr	nc,RAW_SEND3

	pop	hl,de
	ld	a,2
	scf
	ret
RAW_SEND3:

	;--- If size is 0 and Cy=1, terminate

	ld	a,b
	or	c
	jr	nz,RAW_SEND4

	ld	a,(RAW_CY)
	or	a
	jr	z,RAW_SEND4

	pop	hl,de
	xor	a
	ret
RAW_SEND4:

	;--- Switch data segment

	call	SETUP_P2
	ld	a,#FF
	ld	(DISABLE_INT),a

	;--- Check network connection

	call	IS_CONNECTED
	jr	z,RAW_SEND1

	ld	a,1
	scf
	pop	hl,de
	jr	RAW_SEND_END
RAW_SEND1:

	push	bc,iy,ix
	pop	hl

	;--- Copy data from TPA

	ld	a,(RAW_CY)
	or	a
	ld	de,OUT_BUFFER+24
	jr	z,RAW_SEND5
	ld	de,OUT_BUFFER+4
RAW_SEND5:
	ld	a,b
	or	c
	call	nz,LDIR_ST
	pop	iy,bc,hl,de

	if	LINK=0

	ld	a,#FF	;To not send it as compressed VJ
	ld	(IS_RAW_DGRAM),a

	endif

	;--- Decide action according to Cy

	ld	a,(RAW_CY)
	or	a
	jr	nz,RAW_SEND_CY

	;--- Send without header

	push	hl	;Store current TTL and TOS
	ld	hl,(TTL)
	ex	(sp),hl

	ld	a,iyh	;Set specified TTL and TOS
	ld	(TOS),a
	ld	a,iyl
	ld	(TTL),a

	ld	a,(RAW_A)
	call	SEND_IP	;HL, DE, BC are already set

	pop	hl	;Restore previous TTL and TOS
	ld	(TTL),hl

	jr	RAW_SEND_OK

	;--- Send with header

RAW_SEND_CY:

	if	LINK=0

	ld	hl,#2100	;Protocol for PPP
	ld	(OUT_BUFFER+2),hl
	call	SEND_PACKET

	endif

	if	LINK=1

	call	SEND_IP_ETH0

	endif

	;--- End

RAW_SEND_OK:
	xor	a
RAW_SEND_END:
	push	af
	xor	a
	ld	(DISABLE_INT),a
	pop	af
	call	RESTORE_P2
	ret

RAW_A:	db	0
RAW_CY:	db	0

	if	LINK=0
IS_RAW_DGRAM:	db	0
	endif


	;=====================
	;===  RAW_CONTROL  ===
	;=====================

;Obain/set status of raw datagram capture
;Input:  A = 0: Obtain state
;            1: Request capture
;            2: Cancel capture
;        B = Transport protocol to capture (if A=1) or
;          0: All
;          #FF: All except TCP, UDP and echo ICMP
;Output: Cy = 1 and A=Error:
;           1: Capture required but no network connection available
;           2: Invalid value of A
;        A = State:
;           0: No capture required, or no network connection available
;           1: Capture required but no captured datagram available
;           2: Captured datagram available
;        BC = Size of captured datagram (if A=2)
;        D  = Required protocol (if A<>0)

_RAW_CONTROL:
	cp	3
	ccf
	ld	c,a
	ld	a,2	;Error 2?
	ret	c
	ld	a,c

	push	af
	call	SETUP_P2
	ld	a,#FF
	ld	(DISABLE_INT),a
	pop	af

	;--- If A=1, and no network connection, error

	cp	1
	jr	nz,RAW_CONTROL2

	call	IS_CONNECTED
	ld	a,1
	scf
	jr	nz,RAW_CTRL_END
RAW_CONTROL2:

	;--- Only check state: terminate

	or	a
	jr	z,RAW_CTRL_STAT

	;--- Request capture

	cp	1
	jr	nz,RAW_CTRL_CANCEL

	ld	(PCAP_STATE),a
	ld	a,b
	ld	(PCAP_PROTO),a

	ld	a,(UDPI_GINDEX)	;If UDP 8 packets are stored,
	cp	7	;discard 8th
	jr	nz,RAW_CONTROL3
	xor	a
	ld	(UDPI_GINDEX),a
RAW_CONTROL3:

	ld	a,(UDPI_PINDEX)
	cp	7
	jr	nz,RAW_CONTROL4
	xor	a
	ld	(UDPI_PINDEX),a
RAW_CONTROL4:

	jr	RAW_CTRL_STAT

	;--- Cancel capture

RAW_CTRL_CANCEL:	xor	a
	ld	(PCAP_STATE),a

	;--- State

RAW_CTRL_STAT:
	ld	de,(PCAP_PROTO-1)
	ld	bc,(PCAP_SIZE)
	ld	a,(PCAP_STATE)
	or	a

	;--- End

RAW_CTRL_END:	push	af
	xor	a
	ld	(DISABLE_INT),a
	pop	af
	jp	RESTORE_P2


	;=================
	;===  RAW_RCV  ===
	;=================

;Obtain a captured raw datagram
;Input:  HL = Destination TPA address
;Output: Cy = 1 and A=Error:
;             1: No captured datagram available
;        A  = IP header length
;        BC = Datagram total length
;        DE = Datagram data length
;        HL = Pointer to datagram data part in TPA

_RAW_RCV:
	call	SETUP_P2
	ld	a,#FF
	ld	(DISABLE_INT),a

	;--- Error if no datagram available

	ld	a,(PCAP_STATE)
	cp	2
	ld	a,1
	scf
	jr	nz,RAW_RCV_END

	;--- Copy datagram to TPA

	push	hl
	ex	de,hl
	ld	hl,PCAP_BUFFER
	ld	bc,(PCAP_SIZE)
	ld	a,b
	or	c
	call	nz,LDIR_TS

	;--- Set output parameters

	xor	a
	ld	(PCAP_STATE),a

	ld	a,(PCAP_BUFFER)
	and	#0F
	sla	a
	sla	a
	ld	c,a
	ld	b,0	;BC=Header length

	ld	hl,(PCAP_SIZE)
	or	a
	sbc	hl,bc
	ex	de,hl	;DE=Data length

	pop	hl
	add	hl,bc	;HL=Pointer to data part

	ld	a,c	;A=Header length
	ld	bc,(PCAP_SIZE)	;BC=Total length

	or	a

	;--- End

RAW_RCV_END:
	push	af
	xor	a
	ld	(DISABLE_INT),a
	pop	af
	jp	RESTORE_P2


	;==================
	;===  WAIT_INT  ===
	;==================

;Wait until at least one timer interrupt occurs since
;the last time this routine was called.
;Returns Cy=1 if it was necessary to wait, Cy=0 if no.

_WAIT_INT:
	ld	hl,(SYSTIMER)
	ld	de,(LAST_SYSTIM)
	call	COMP
	ld	(LAST_SYSTIM),hl
	scf
	ccf
	ret	nz

WAIT_INT2:
	ld	hl,(SYSTIMER)
	call	COMP
	jr	z,WAIT_INT2
	ld	(LAST_SYSTIM),hl
	scf
	ret

LAST_SYSTIM:	dw	0


	;=======================
	;===  NETWORK_STATE  ===
	;=======================

;Returns network state in A:
;0: Closed
;1: Initializing
;2: Open
;3: Closing

_NETWORK_STATE:
	call	SETUP_P2

	if	LINK=0

	ld	a,(PPP_STATE)
	or	a
	jp	z,RESTORE_P2

	cp	4
	ld	a,2
	jp	z,RESTORE_P2

	ld	a,1
	jp	RESTORE_P2

	endif

	if	LINK=1

	ld	a,(CHECK_NET)
	or	a
	jr	nz,NETWORK_STAT2

	ethnet	ETH_GET_NETSTAT
	or	a
	jp	z,RESTORE_P2
	ld	a,2
	jp	RESTORE_P2

NETWORK_STAT2:
	ld	a,(NET_STATE)
	or	a
	jp	z,RESTORE_P2

	ld	a,2
	jp	RESTORE_P2

	endif


	if	LINK=1

	;===================
	;===  ENET_INFO  ===
	;===================

;Returns MAC address in L-H-E-D-C-B.

_ENET_INFO:
	ethnet	ETH_GET_HWADD
	ret


	;===================
	;===  ETH2ASCII  ===
	;===================

;Converts a MAC address to an ASCII string.
;Input:  L-H-E-D-C-B = MAC address
;        IX = Destination address for the string in TPA
;        A  = Flags:
;             Bit 0: 0 to use upper case for hex digits, 1 for lower case
;             Bit 1: 0 to use "-" as separator, 1 to use ":"
;Output:  -

_ETH2ASCII:
	ld	(ETH2ASCBUF),hl
	ld	(ETH2ASCBUF+2),de
	ld	(ETH2ASCBUF+4),bc

	push	ix,af
	call	SETUP_P2
	ld	a,#FF
	ld	(DISABLE_INT),a
	pop	af

	rrca
	rrca
	rrca		;Now bit 5 is upper/lower, bit 6=separator
	ld	d,a
	and	#20
	ld	c,a	;C=#20 for lower, 0 for upper
	ld	a,d
	and	#40
	ld	d,a	;D=#40 for ":", 0 for "-"

	ld	hl,OUT_BUFFER
	ld	ix,ETH2ASCBUF
	ld	b,6

	;--- Generate the string

E2ALOOP:	ld	a,(ix)
	inc	ix
	ld	e,a
	rrca
	rrca
	rrca
	rrca
	call	NIBLE2ASC
	ld	(hl),a
	inc	hl

	ld	a,e
	call	NIBLE2ASC
	ld	(hl),a
	inc	hl

	ld	a,b
	cp	1
	jr	z,E2ALOOP3

	ld	a,d
	or	a
	ld	a,"-"
	jr	z,E2ALOOP2
	ld	a,":"
E2ALOOP2:
	ld	(hl),a
	inc	hl

	djnz	E2ALOOP
E2ALOOP3:

	;--- Copy string to TPA

	ld	hl,OUT_BUFFER
	pop	de
	ld	bc,17
	call	LDIR_TS

	xor	a
	ld	(DISABLE_INT),a
	call	RESTORE_P2
	ret

;--- Subroutine that converts A (low nibble) to a character

NIBLE2ASC:
	and	%1111
	cp	10
	jr	nc,NIB2ASC2

	add	"0"
	ret

NIB2ASC2:
	add	"A"-10
	or	c
	ret

ETH2ASCBUF:	ds	6


	;===================
	;===  ASCII2ETH  ===
	;===================

;Converts a string to a MAC address
;Input:  HL = String address in TPA
;Output: L-H-E-D-C-B = Resulting MAC address
;        Cy = 1 if not a valid string

_ASCII2ETH:
	call	SETUP_P2
	ld	a,#FF
	ld	(DISABLE_INT),a

	ld	de,OUT_BUFFER
	ld	bc,17
	call	LDIR_ST

	;--- Parse the string

	ld	ix,OUT_BUFFER
	ld	hl,ETH2ASCBUF
	ld	b,6

A2ELOOP:
	ld	a,(ix)
	call	ASC2NIBLE
	jr	c,A2EEND
	sla	a
	sla	a
	sla	a
	sla	a
	ld	d,a
	inc	ix

	ld	a,(ix)
	call	ASC2NIBLE
	jr	c,A2EEND
	or	d
	ld	(hl),a
	inc	hl
	inc	ix

	ld	a,b
	cp	1
	jr	z,A2ELOOP2

	ld	a,(ix)
	cp	":"
	jr	z,A2ELOOP3
	cp	"-"
	scf
	jr	nz,A2EEND
A2ELOOP3:
	inc	ix

	djnz	A2ELOOP
A2ELOOP2:

	or	a

	;--- End, return results

A2EEND:	push	af
	xor	a
	ld	(DISABLE_INT),a
	call	RESTORE_P2
	pop	af
	ret	c

	ld	hl,(ETH2ASCBUF)
	ld	de,(ETH2ASCBUF+2)
	ld	bc,(ETH2ASCBUF+4)
	ret


;--- Subroutine to parse character passed in A
;    Returns A=Digit, Cy=1 if invalid

ASC2NIBLE:
	cp	"0"
	ret	c
	cp	"9"+1
	jr	nc,ASC2NIBLE2

	;* It is 0-9

	sub	"0"
	or	a
	ret
ASC2NIBLE2:

	;* Can ber A-F

	or	32	;Conviert to lower case
	cp	"a"
	ret	c
	cp	"f"+1
	ccf
	ret	c

	sub	"a"-10
	or	a
	ret


	;===================
	;===  MASK2BITS  ===
	;===================

;Converts a subnet mask to a 1 byte number.
;(Stops when finding one 0 bit)
;Input:  L.H.E.D = Mask
;Output: A = Number of 1 bits

_MASK2BITS:
	ld	c,0
	call	COUNT_ONES
	ld	a,c
	cp	16
	ret	c

	ex	de,hl
	call	COUNT_ONES
	ld	a,c
	ret

	;--- Count ones in HL and add number to C

COUNT_ONES:
	ld	b,16
COUNTONES_L:
	sla	h
	rl	l
	ret	nc
	inc	c
	djnz	COUNTONES_L
	ret


	;===================
	;===  BITS2MASK  ===
	;===================

;Converts a 1 byte number to a subnet mask.
;Input:  A = Number of bits
;Output: L.H.E.D = Subnet mask

_BITS2MASK:
	ld	hl,0
	ld	de,0

	or	a
	ret	z

	ld	b,a
B2M_LOOP:
	scf
	rr	l
	rr	h
	rr	e
	rr	d
	djnz	B2M_LOOP

	ret


	;===================
	;===  ARP_ROUTE  ===
	;===================

;Returns the addresses of the ARP and routing entries
;Input: -
;Output:  IX = Address of ARP table
;         IY = Address of routing table
;         B = Number of entries in ARP table
;         C = Number of entries in routing table

_ARP_ROUTE:
	ld	ix,ARP_CACHE
	ld	iy,ROUTE_TABLE
	ld	bc,ROUTE_ENTRIES+256*ARP_ENTRIES
	ret

	endif


	;==========================
	;===  Prebuilt packets  ===
	;==========================

	;*** They are in the code segment, not in the data segment.

	if	LINK=0

	;--- LCP "Configure-Nak" that proposes PAP and CHAP authentication,
	;    this is the only "Configure-Nak" sent by INL, it is sent only
	;    if the peer proposes an unknown authentication method.
	;    The approrpiate Id must be set at 4th byte before sending it.
	;    Protocol field is already set to LCP.

	;From v1.1, this packet is never sent;
	;unknown authentication protocols are simply rejected.
	;That's because Linux PPPD first proposes EAP as the authentication protocol,
	;and says that this NAK packet is a "bad Configure Nak" and ignores it,
	;but reacts correctly when rejecting the option, proposing then CHAP or PAP
	;(is this the standard behavior?)

;PACK_NAK:
;		db	#C0,#21		;LCP protocol
;		db	#03,0,0,13	;ConfNak + ID + Length
;		db	#03,#04,#C0,#23	;PAP option
;		db	#03,#05,#C2,#23,#05	;CHAP option



	;--- VJ compression option for IPCP "Configure-Request"
	;    (four slots + compress slot id)

PACK_VJ:	db	2,6,0,#2D,3,1

	;--- IPCP "Configure-Request" with local IP and DNS options.
	;    Addresses and size must be configured appropriately.

PACK_IPREQ:	db	#80,#21	;IPCP protocol
		db	#01,0,0,10	;ConfReq + ID + Length
		db	3,6,0,0,0,0	;IP local option
		db	129,6,0,0,0,0	;DNS 1 option
		db	131,6,0,0,0,0	;DNS 2 option


	;--- LCP echo, ID must be set appropriately.

PACK_LCPECHO:	db	#C0,#21	;LCP protocol
		db	#09,0,0,24	;EchoReq + ID + length
		db	0,0,0,0	;Magic number (0=not used)
		db	"InterNestor Lite"

	endif

	if	LINK=1

	;--- UNARP packet (16 bytes)

UNARP_PACKET:	db	0,1,8,0,0,4,0,2
UNARP_IP:	ds	4
		db	255,255,255,255

	endif

CODE_END:


;*******************************
;***                         ***
;***  VARIABLES AND BUFFERS  ***
;***                         ***
;*******************************

;They are defined here so that the code can be assembled,
;but actually these variables are in the code segment.

	org	#8000

	;================================================================
	;===  Variables and buffers that can be useful for the usuer  ===
	;================================================================

BUF_IPLOCAL:	ds	4	;Local IP (4 bytes)
BUF_IPDNS1:	ds	4	;IP DNS 1 (4 bytes)
BUF_IPDNS2:	ds	4	;IP DNS 2 (4 bytes)
REPLYECHO:	ds	1	;Reply PINGs yes/no
TTL:	ds	1	;TTL for outgoing datagrams
TOS:	ds	1	;TOS for outgoing datagrams
CHKVECT:	ds	1	;Checksum optimizacions vector
			;       (&B 0 0 0 ICMP UDP TCP IP PPP)
PING_SIZE:	ds	2	;Size of outgoing PINGs (0-512)

		if LINK=0

			;* Variables for PPP and modem

BUF_DIAL:	ds	16	;Buffer for ISP phone number (16 bytes)
BUF_MODREP:	ds	16	;Buffer for modem reply (16 bytes)
BUF_PPPUSER:	ds	32	;Buffer for PPP user (32 bytes)
BUF_PPPASSW:	ds	32	;Buffer for PPP password (32 bytes)
BUF_IPREMOTE:	ds	4	;Remote IP (4 bytes)
NEGDNS:		ds	1	;Negotiate DNSs yes/no
USEPPPECHO:	ds	1	;Use PPP echoes for keep alive
USEPPPVJ:	ds	1	;Use Van Jacobson compression
PPP_STATE:	ds	1	;PPP automaton state:
			;0: Closed
			;1: LCP negociation
			;2: Authentication
			;3: IPCP negociation
			;4: Open
PPP_CLCODE:	ds	1	;Reason the last PPP connection close:
			;0: PPP connection never open
			;1: Modem error ("CONNECT" reply not received)
			;2: User closed connection
			;3: The peer closed LCP
			;4: The peer closed IPCP
			;5: Authentication rejected
			;6: Authentication required with unknown method
			;7: Authentication required but no user specified
			;8: LCP negotiation lasted for more than 1 minute
			;9: Authentication process lasted for more than 1 minute
			;10: IPCP negotiation lasted for more than 1 minute
			;11: Local IP is unknown by both sides
			;12: Remote IP is unknown by both sides
			;13: LCP "Code Reject" received
			;14: LCP "Protocol Reject" received
			;15: IPCP "Code Reject" received
			;16: IPCP "Protocol Reject" received
			;17: Too many unreplied LCP echoes sent

	endif

	if	LINK=1

	;* Variables for Ethernet

		ds	1	;Dummy (old slot number for OsbonET)
HWAD:		ds	6	;MAC address
SUBNET_MASK:	ds	4	;Subnet mask
DEFGW:		ds	4	;Default gateway
ARP_TOUT:	ds	4	;ARP cache timeout, in 1/60 seconds
ARP_TOUT_SECS:	ds	4	;ARP cache timeout, in seconds
FRAME_TYPE:	ds	1	;0=send Eth 2 frames, 1=send IEEE 802.3 frames
CHECK_NET:	ds	1	;Periodically check network connection if #FF
DHCP_VECT:	ds	2	;Parameters to be obtained via DHCP
	;bit 0: Local IP
	;bit 1: Subnet mask
	;bit 2: Default gateway
	;bit 3: DNS servers
	;bit 4: ARP cache timeout
	;bit 5: Ethernet frame type
DHCP_VECT_O:	ds	2	;Parameters actually obtained via DHCP
DHCP_STATE:	ds	1	;DHCP state:
	;0: INIT
	;1: SELECTING
	;2: REQUESTING
	;3: BOUND
	;4: RENEWING
	;5: REBINDING
	;6: INFORMING
	;7: CONFIGURED
	;253: Error: No DHCP servers
	;254: Error: No reply from server

NET_STATE:	ds	1	;Network state, #FF=active
NETSTAT_TIMER:	ds	2	;Timer to check network state


	;================================
	;===  Information about DHCP  ===
	;================================

DHCP_VAR_START:

DHCP_XID:	ds	4	;Next DHCP XID to use
DHCP_SNDTIM:	ds	1	;Timer for sending next packet
DHCP_TRIES:	ds	1	;DHCP packets sent
DHCP_RCVXID:	ds	4	;XID of last received packet
DHCP_SERVER:	ds	4	;Server IP
DHCP_T1:	ds	4	;T1 timer
DHCP_T2:	ds	4	;T2 timer
DHCP_LEASE:	ds	4	;IP address lease
DHCP_SECS:	ds	2	;Seconds since process started
DHCP_SECS_T:	ds	1	;1/60 secs timer for updating SECS
DHCP_YIADDR:	ds	4	;Offered IP

DHCP_VAR_END:

	endif


	;========================================
	;===  Information about ICMP and UDP  ===
	;========================================

PACKINFO_START:

	;--- Buffers for information about received ICMP "echo reply" messages (up to 4)

ICMPI_GINDEX:	ds	1	;Input index (0 to 7)
ICMPI_PINDEX:	ds	1	;Output index (0 a 7)

ICMPI_IP0:	ds	4	;Source IP (0.0.0.0 if empty buffer)
ICMPI_TTL0:	ds	1	;TTL of received packet
ICMPI_ID0:	ds	2	;Identifier
ICMPI_SEQ0:	ds	2	;Sequence number
ICMPI_LEN0:	ds	2	;Data length

		ds	11*7	;Other 7 equal buffers

	;--- Bufferes for information about UDP packets received (up to 8)
	;    Actual buffers for packet data are below

UDPI_GINDEX:	ds	1	;Input index (0 to 7)
UDPI_PINDEX:	ds	1	;Output index (0 a 7)

UDPI_IP0:	ds	4	;Source IP (0.0.0.0 if empty buffer)
UDPI_SPORT0:	ds	2	;Source port
UDPI_DPORT0:	ds	2	;Destination port
UDPI_LEN0:	ds	2	;Data length

		ds	10*7	;Other 7 equal buffers

PACKINFO_END:


	;================================================
	;===  Variables for storing the paging state  ===
	;================================================

I_SEGP2:	ds	1	;Page 2 segment for timer interrupt
I_SLOT2:	ds	1	;Page 2 slot for timer interrupt
R_SEGP2:	ds	1	;Page 2 segment for routines

DISABLE_INT:	ds	1	;#FF if la rutina TIME_INT no puede ejecutarse


		if LINK=0

	;===================================================
	;===  Variables for RS232 send/receive routines  ===
	;===================================================

INBUF_PNT:	ds	2	;Pointer where the next incoming byte will be stored
				;(if 0, no packet reception in progress)
INBUF_SIZE:	ds	2	;Received packet size (data between #7E bytes)
LAST_ESC:	ds	1	;#FF if last incoming byte was #7F
TOO_BIG:	ds	1	;#FF if a too big packet is being received
BAD_PACKETS:	ds	1	;Number of too short packets received
NEXT_MRU:	ds	2	;Next MRU value to announce
NEXT_ASYNC:	ds	4	;Next async-map value to announce
GOT_TCP:	db	0	;#FF if TCP packet received
USE_VJ_IN:	db	0	;#FF if incoming VJ compression negotiated
USE_VJ_OUT:	db	0	;0: Outgoing VJ compression NOT negotiated
	;1: Negotiated, do not compress slot number
	;2: Negotiated, slot number can be compressed
GETPACK_STATE:	db	0	;Packet reception status.
	;Used to control compressed PPP headers.
	;Final states (that is, data packet is being received):
	;1: (odd) received.
	;2: (even) (odd) received.
	;3: #FF #03 (odd) received.
	;4: #FF #03 (even) (odd) received.

	;Initial states:
	;0: Nothing received.
	;5: #FF received.
	;6: #FF #03 received.

		endif


	;==========================================
	;===  Identifiers for outgoing packets  ===
	;==========================================

		if LINK=0

ID_CONFREQ:	ds	1	;Configuration Request
ID_TERMREQ:	ds	1	;Termination Request
ID_CODEREJ:	ds	1	;Code Reject
ID_PPPECHO:	ds	1	;PPP echo
ID_PROTREJ:	ds	1	;Protocol Reject
ID_PAPREQ:	ds	1	;PAP requests

		endif

ID_IP:	ds	2	;IP datagrams
ID_DNS:	ds	2	;DNS queries


		if LINK=0

	;=================================================
	;===  Variables LCP/IPCP/PAP/CHAP negotiation  ===
	;=================================================

XCP_TTIMER:	ds	2	;Global 1 minute timer
XCP_RTIMER:	ds	2	;Retransmission timer
XCP_NEXTOP:	ds	1	;Options to negotiate in the next ConfReq:
			;Bit 0: MRU=576
			;Bit 1: Async-Map=0
XCP_ACKS:	ds	1	;Negotiation state
			;Bit 0: ACK sent
			;Bit 1: ACK received
AUTH_PROTO:	ds	1	;Authentication protocolo to use
			;0: none
			;#C0: PAP
			;#C2: CHAP
ASYNC_MAP:	ds	1
ECHOES_SENT:	ds	1	;Number of sent LCP echoes
PPP_COMP_P:	db	0	;#FF if PPP protocol can be sent compressed
PPP_COMP_FF:	db	0	;#FF if initial #FF #03 can be sent compressed

		endif


	;================================
	;===  Variables for resolver  ===
	;================================

DNS_STAT_P:	ds	1	;Current state, primary
DNS_STAT_S:	ds	1	;Current state, secondary
DNS_TOUT:	ds	1	;Timeout counter for current server
DNS_TTOUT:	ds	2	;Total timeout counter
DNS_RETRY:	ds	1	;Retransmission counter for current DNS
DNS_RESULT:	ds	4	;Answer returned by server
DNS_IP:		ds	4	;Current server IP address
ANCOUNT:	ds	2
ARCOUNT:	ds	2
NSCOUNT:	ds	2
DNS_BUFFER:	ds	256	;To store the name to resolve


	;===========================
	;===  Variables for TCP  ===
	;===========================

CURTCB_NUM:	db	0	;Number of connection whose TCB is at TCB_TEMP
TEMP32_1:	ds	4	;For 32 bit numbers operations
LAST_PROC_TCB:	db	0	;Number of connection processed last time
RECEIVED_MSS:	dw	0	;TCP MSS option received in current segment, or 512


	;========================================
	;===  Variables for packet capturing  ===
	;========================================

PCAP_STATE:	db	0	;0=do not capture, 1=capture requested, 2=captured
PCAP_PROTO:	db	0	;Protocol to capture, or 0 or #FF
PCAP_SIZE:	dw	0	;Captured packet size

		if LINK=1

INBUF_SIZE:	ds	2	;Total size of last received frame
WOUT_SIZE:	ds	2	;Size of packet at WOUT_BUFFER

		endif

VARS_END:


	;================================================
	;===  Buferes for incoming and outgoing data  ===
	;================================================

	;>>> For PPP, the format of stored packets is:

	;#FF #03 Proto_H Proto_L (Informacion) FCS_L FCS_H

	;>>> Buffers order in memory is:
	;VJ variables (PPP only)
	;TCB_TEMP
	;TCBS
	;IN_BUFFER
	;OUT_BUFFER
	;UDP_BUFFERS
	;TCP_BUFFERS

	;They are declared in reverse order so that they can be assembled

	;--- Buferes for incoming and outoing TCP data
	;    (1024 incoming bytes + 1024 outgoing bytes)*4 connections

TCP_BUFFERS:	equ	#A000

	if	LINK=1

	;--- ARP cache and routing table (32 and 16 entries, respectively)

ARP_CACHE:	equ	TCP_BUFFERS-16*ARP_ENTRIES
ROUTE_TABLE:	equ	ARP_CACHE-16*ROUTE_ENTRIES

	endif

	;--- Buferes for received UDP packets
	;    548 bytes * 8 packets,
	;    +28 bytes to store a 576 byte captured packer

	if	LINK=0
UDP_BUFFERS:	equ	TCP_BUFFERS-(548*8)-28
	endif

	if	LINK=1
UDP_BUFFERS:	equ	ROUTE_TABLE-(548*8)-28
	endif

PCAP_BUFFER:	equ	UDP_BUFFERS+7*548	;For one captured packet


	if	LINK=0

	;--- Buffer for outgoing packet, PPP version
	;    Length: 576 + 2 for #FF03 + 2 for PPP protocol + 2 for FCS = 582

OUT_BUFFER:	equ	UDP_BUFFERS-582

	endif

	if	LINK=1

	;--- Buffer for outgoing packet, Ethernet version
	;    Length: 576 + 32 for IEEE802.2 header = 608
	;    Data starts at OUT_BUFFER+4 for compatibility with PPP version

OUT_BUFFER:	equ	UDP_BUFFERS-580
OUT_BUFSTART:	equ	OUT_BUFFER-28

	endif

	;--- Buffer for incoming packet
	;    Length: 576 + 2 for #FF03 + 2 for PPP protocol + 2 for FCS = 582
	;    PPP: Add an extra un byte so that too big packets can be detected
	;    (if we store the 583th byte, packet is too long)

	if	LINK=0

IN_BUFFER:	equ	OUT_BUFFER-583

	endif

	if	LINK=1

IN_BUFFER:	equ	OUT_BUFSTART-580
IN_BUFSTART:	equ	IN_BUFFER-28

	endif

	if	LINK=1

	;--- Buffer for an outgoing datagram that is
	;    waiting for an ARP resolucion

WOUT_IP:	equ	IN_BUFSTART-4
WOUT_BUFFER:	equ	WOUT_IP-576

	endif


	;--- Buffers for TCBs of TCP connections

	if	LINK=0

TCBS:	equ	IN_BUFFER-(TCB_MAX_SIZE*4)

	endif

	if	LINK=1

TCBS:	equ	WOUT_BUFFER-(TCB_MAX_SIZE*4)

	endif

	;--- Temporary TCB area

TCB_TEMP:	equ	TCBS-TCB_MAX_SIZE

TCP_STATE:	equ	TCB_TEMP	;TCP state
REMOTE_IP:	equ	TCP_STATE+1	;Remote IP
REMOTE_PORT:	equ	REMOTE_IP+4	;Remote port (Big-Endian)
LOCAL_PORT:	equ	REMOTE_PORT+2	;Remote port (Big-Endian)
PASSIVE_OPEN:	equ	LOCAL_PORT+2	;0/#FF for connection active/passive

SND_UNA:	equ	PASSIVE_OPEN+1	;First non ACKed sequence number
SND_NXT:	equ	SND_UNA+4	;Next sequence number to send
SND_WND:	equ	SND_NXT+4	;Announced transmission window
SND_WL1:	equ	SND_WND+2	;Sequence number used for last window update
SND_WL2:	equ	SND_WL1+4	;ACK number used for last window update

ISS:		equ	SND_WL2+4	;Initial send sequence number

RCV_NXT:	equ	ISS+4		;Next expected incoming sequence number
IRS:		equ	RCV_NXT+4	;Initial received sequence number

USER_TOUT_V:	equ	IRS+4		;Initial value for user timeout
USER_TOUT:	equ	USER_TOUT_V+2	;Current value for user timeout
LAST_CLOSE:	equ	USER_TOUT+2	;Last connection close error code:
;0: Connection is open or was never used
;1: CLOSE
;2: ABORT
;3: RST received
;4: User timeout expired
;5: Connection establishment timeout expired
;6: Network connection lost
;7: Destination unreachable

SEND_PUSH_PEND:	equ	LAST_CLOSE+1	;Number of PUSH bytes to send
SEND_TOUT:	equ	SEND_PUSH_PEND+2	;Timeout for sending non PUSH data
SYN_SENT_FLAG:	equ	SEND_TOUT+2	;#FF if a SYN has been sent but not ACKed yet
FIN_SENT_FLAG:	equ	SYN_SENT_FLAG+1	;#FF if a FIN has been sent

RETX_SIZE:	equ	FIN_SENT_FLAG+1	;Retransmission queue length
RTO_T:	equ	RETX_SIZE+2	;Retransmission timer

ACK_RCV_NUM:	equ	RTO_T+2	;Number of received and not yet ACKead bytes
ACK_DELAY_T:	equ	ACK_RCV_NUM+2	;Delayed ACK timer (1 byte)

FIN_PENDING:	equ	ACK_DELAY_T+1	;FIN must be sent but there is pending outgoing data

LAST_WIN_SENT:	equ	FIN_PENDING+1	;Last announced window

MSS:	equ	LAST_WIN_SENT+2	;Max. outgoing segment size

ACK_PENDING:	equ	MSS+2	;ACK pending but not for new data

INBUF:	equ	ACK_PENDING+1
INBUF_USED:	equ	INBUF	;Input buffer control area
INBUF_FREE:	equ	INBUF_USED+2
INBUF_INPNT:	equ	INBUF_FREE+2
INBUF_OUTPNT:	equ	INBUF_INPNT+2
INBUF_BUFADD:	equ	INBUF_OUTPNT+2
INBUF_ENDADD:	equ	INBUF_BUFADD+2

OUTBUF:	equ	INBUF_ENDADD+2
OUTBUF_USED:	equ	OUTBUF	;Output buffer control area
OUTBUF_FREE:	equ	OUTBUF_USED+2
OUTBUF_INPNT:	equ	OUTBUF_FREE+2
OUTBUF_OUTPNT:	equ	OUTBUF_INPNT+2
OUTBUF_BUFADD:	equ	OUTBUF_OUTPNT+2
OUTBUF_ENDADD:	equ	OUTBUF_BUFADD+2

		if LINK=0
VJ_OUT_HEAD:	equ	OUTBUF_ENDADD+2	;Header for Van Jacobson compression (output)

TCB_END:	equ	VJ_OUT_HEAD+44
		endif

		if LINK=1
TCB_END:	equ	OUTBUF_ENDADD+2
		endif

TCB_SIZE:	equ	TCB_END-TCB_TEMP

		if LINK=0

	;--- Variables for VJ compression

VJ_IN_HEADS:	equ	TCB_TEMP-44*4	;Headers for VJ (input)
VJ_RCVED:	equ	VJ_IN_HEADS-1	;1 if Uncompressed_TCP received, 2 if compressed
VJ_LAST_OSLOT:	equ	VJ_RCVED-1	;Last slot id sent
VJ_LAST_ISLOT:	equ	VJ_LAST_OSLOT-1	;Last slot id received
TOSS_FLAG:	equ	VJ_LAST_ISLOT-1	;"Toss" flag
VJ_CUR_ISLOT:	equ	TOSS_FLAG-1	;Received slot (if Uncompressed_TCP)
VJ_FLAGS:	equ	VJ_CUR_ISLOT-1	;Flags from received VJ packet
DELTA_U:	equ	VJ_FLAGS-2	;Urgent pointer of received VJ packet
DELTA_W:	equ	DELTA_U-2	;Window increment
DELTA_A:	equ	DELTA_W-2	;ACK increment
DELTA_S:	equ	DELTA_A-2	;Sequence number increment
DELTA_I:	equ	DELTA_S-2	;IP ID increment
VJ_ISLOT_DIR:	equ	DELTA_I-2	;Current incoming slot address

		endif

IP_HEADER_LEN:	equ	OUT_BUFFER
IP_TOTAL_LEN:	equ	OUT_BUFFER+2
