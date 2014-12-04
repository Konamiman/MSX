	;--- DenYoNet TCP/IP UNAPI BIOS v0.6
	;    By Konamiman, 2/2014

	.label	20

;*******************
;***  CONSTANTS  ***
;*******************

;Set NO_INIT_BOOT=1 to prevent BIOS from initializing at boot time
;(needed for Turbo-R GT, the computer hangs otherwise)
;BIOS can be initialized after boot with CALL DENYOINIT or DENYINIT.COM.

NO_TIMI:	equ	0
NO_EXTBIO:	equ	0
NO_INIT_BOOT:	equ	0

debug:	macro	@x
	push	af,bc,de,hl,ix,iy
	ld	a,@x
	ld	ix,#A2
	call	#001C
	pop	iy,ix,hl,de,bc,af
	endm

;--- System variables and routines

RDSLT:	equ	000Ch	;A=PEEK(HL, slot A)
WRSLT:	equ	0014h	;POKE(HL, slot A),E
ENASLT:	equ	0024h
SNSMAT:	equ	0141h
CHPUT:	equ	00A2h
SECBUF:	equ	0F34Dh
HOKVLD:	equ	0FB20h
EXPTBL:	equ	0FCC1h
SYSTIMER:	equ	0FC9Eh
EXTBIO:	equ	0FFCAh
SLTWRK:	equ	0FD09h
ARG:	equ	0F847h
PROCNM:	equ	0FD89h
H_TIMI:		equ	0FD9Fh
H_PHYD:	equ	0FFA7h


;--- API version and implementation version

API_V_P	equ	1
API_V_S	equ	0
ROM_V_P	equ	0
ROM_V_S	equ	6


;--- Maximum number of available standard and implementation-specific function numbers

;Must be 0 to 127
MAX_FN	equ	29

;Must be either zero (if no implementation-specific functions available), or 128 to 254
MAX_IMPFN	equ	0


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
TIME.WAIT:	equ	10


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


;--- Port definitios

DNS_SERVER_PORT:	equ	53
DHCP_SERVER_PORT:	equ	67
DNS_DHCP_LOCAL_PORT:	equ	68


;--- Possible values for S0_STATE

S0_IS_CLOSED:	equ	0	;Socket 0 is closed
S0_IS_UDP:	equ	1	;Socket 0 is open for UDP on the DNS and DHCP client port


;--- W5100 registers, 8000h based

;Common registers

WIZ_MR	equ	8000h
WIZ_GAR	equ	8001h
WIZ_SUBR	equ	8005h
WIZ_SHAR	equ	8009h
WIZ_SIPR	equ	800Fh
WIZ_IMR		equ 	8016h
WIZ_RMSR	equ	801Ah
WIZ_TMSR	equ	801Bh

;Base address and size of socket register set

WIZ_SOCKREG_BASE	equ	8400h
WIZ_SOCKREG_SIZE	equ	100h

;Socket registers offset addresses
;To access registers for socket N, add:
;WIZ_SOCKREG_BASE + (WIZ_SOCKREG_SIZE * n)

WIZ_Sn_MR	equ	00h
WIZ_Sn_CR	equ	01h
WIZ_Sn_IR	equ	02h
WIZ_Sn_SR	equ	03h
WIZ_Sn_PORT	equ	04h
WIZ_Sn_DHAR	equ	06h
WIZ_Sn_DIPR	equ	0Ch
WIZ_Sn_DPORT	equ	10h
WIZ_Sn_MSSR	equ	12h
WIZ_Sn_PROTO	equ	14h
WIZ_Sn_TOS	equ	15h
WIZ_Sn_TTL	equ	16h
WIZ_Sn_TX_FSR	equ	20h
WIZ_Sn_TX_RD	equ	22h
WIZ_Sn_TX_WR	equ	24h
WIZ_Sn_RX_RSR	equ	26h
WIZ_Sn_RX_RD	equ	28h

;--- W5100 buffer related constants

;Receive/transmit buffer base addresses and sizes

WIZ_RX_BASE	equ	0A000h
WIZ_TX_BASE	equ	8000h
WIZ_RX_SIZE	equ	800h	;2K
WIZ_TX_SIZE	equ	400h	;1K

;Receive/transmit buffer masks, high byte
;(low byte is always FFh)

gSn_RX_MASK	equ	07h
gSn_TX_MASK	equ	03h

;--- W5100 commands

CMD_OPEN	equ	01h
CMD_LISTEN	equ	02h
CMD_CONNECT	equ	04h
CMD_DISCON	equ	08h
CMD_CLOSE	equ	10h
CMD_SEND	equ	20h
CMD_RECV	equ	40h


;--- W5100 socket status register values

SOCK_CLOSED	equ	00h
SOCK_ARP	equ	01h
SOCK_INIT	equ	13h
SOCK_LISTEN	equ	14h
SOCK_SYNSENT	equ	15h
SOCK_SYNRECV	equ	16h
SOCK_ESTABLISHED	equ	17h
SOCK_FIN_WAIT1	equ	18h
SOCK_FIN_WAIT2	equ	19h
SOCK_CLOSING	equ	1Ah
SOCK_TIME_WAIT	equ	1Bh
SOCK_CLOSE_WAIT	equ	1Ch
SOCK_LAST_ACK	equ	1Dh
SOCK_UDP	equ	22h
SOCK_IPRAW	equ	32h
SOCK_MACRAW	equ	42h


;--- W5100 socket protocol values

SOCK_PROTO_NONE	equ	0
SOCK_PROTO_TCP	equ	1
SOCK_PROTO_UDP	equ	2
SOCK_PROTO_IPRAW	equ	3


;--- ROM and W5100 RAM mapping port
;    bits 0-3 select the 32K ROM segment visible at 0000h-7FFFh
;    bit 4 selects the W5100 16K segment visible at 8000h-BFFFh
;    bit 5 selects the W5100 16K segment visible at C000h-FFFFh

WIZ_PORT	equ	28h


;--- LEDS state port
;Bit 0 = TX
;Bit 1 = RX
;Bit 2 = Collision
;Bit 3 = Full duplex
;Bit 4 = Speed, 100Mbps
;Bit 5 = Link

WIZ_LEDS	equ	029h


;*********************************
;***  DATA IN TRANSMIT BUFFER  ***
;*********************************

;Part of the W5100 RAM is used for variables used by the implementation.
;1K is assigned for transmission for each socket,
;this gives 4K free for variables at the second half of the transmit memory.

DATA_BASE:	equ	9000h	;First addrss of data area
DATA_LIMIT:	equ	0A000h	;Last address of data area +1

	;--- Global variables

INSIDE_FUNC:	equ	DATA_BASE	;Nonzero when running user function
INSIDE_INT:	equ	INSIDE_FUNC+1	;Nonzero when running timer interrupt
OLD_TIMI:	equ	INSIDE_INT+1	;Original value of the timer interrupt handler hook
USER_SLOT_P2:	equ	OLD_TIMI+5	;Slot connected on page 2 when a function is invoked
BUF_IPDNS1:	equ	USER_SLOT_P2+1	;Primary DNS server IP address
BUF_IPDNS2:	equ	BUF_IPDNS1+4	;Secondary DNS server IP address
CONN_FLAGS:	equ	BUF_IPDNS2+4	;One byte per connection (first byte is not used):
	;bit 0: Set if connection is resident
DEFAULT_TOS:	equ	CONN_FLAGS+4	;Default TOS for new connections
DEFAULT_TTL:	equ	DEFAULT_TOS+1	;Default TOS for new connections
S0_STATE:	equ	DEFAULT_TTL+1	;Current state of socket 0
PREV_TIMER:	equ	S0_STATE+1	;Used by TCPIP_WAIT
AUTOIP_CONFIG:	equ	PREV_TIMER+2	;DHCP use flags: 0 for local+remote+mask+gw, 1 for DNS

	;--- Information for current connection (set by SET_CUR_CONN)

CURCONN:	equ	AUTOIP_CONFIG+1	;Current connection number
CURCONN_RX_BASE:	equ	CURCONN+1	;Receive buffer base for current connection
CURCONN_TX_BASE:	equ	CURCONN_RX_BASE+2	;Transmit buffer base for current connection
CURCONN_TX_LIMIT:	equ	CURCONN_TX_BASE+2	;CURCONN_TX_BASE+WIZ_TX_SIZE
CURCONN_RX_LIMIT:	equ	CURCONN_TX_LIMIT+2	;CURCONN_RX_BASE+WIZ_RX_SIZE
CURCONN_REG_BASE:	equ	CURCONN_RX_LIMIT+2	;Current connection registers base

	;--- Data for the resolver

DNS_STAT_P:	equ	CURCONN_REG_BASE+2	;Current state, primary
DNS_STAT_S:	equ	DNS_STAT_P+1	;Current state, secondary
DNS_TOUT:	equ	DNS_STAT_S+1	;Timeout counter for current server
DNS_TTOUT:	equ	DNS_TOUT+1	;Total timeout counter
DNS_RETRY:	equ	DNS_TTOUT+2	;Retransmission counter for current DNS
DNS_RESULT:	equ	DNS_RETRY+1	;Answer returned by server
DNS_IP:		equ DNS_RESULT+4	;Current server IP address
ANCOUNT:	equ	DNS_IP+4
ARCOUNT:	equ	ANCOUNT+2
NSCOUNT:	equ	ARCOUNT+2
DNS_BUFFER:	equ	NSCOUNT+2	;To store the name to resolve
GETSERV_PNT:	equ	DNS_BUFFER+256	;Two bytes, used by GET_SERV
ID_DNS:	equ	GETSERV_PNT+2	;Identifier for outgoing DNS packets
DNS_RESP_FLAG:	equ	ID_DNS+2	;Used by SCAN_DNS_RR, #FF when a reply is found

	;--- Data for PINGs

PING_COUNT:	equ	DNS_RESP_FLAG+2
PING_READ_INDEX:	equ	PING_COUNT+1
PING_WRITE_INDEX:	equ	PING_READ_INDEX+1
PING_BUFFER:	equ	PING_WRITE_INDEX+1	;Data for 8 incoming PINGs, 11 bytes each

	;--- Data for DHCP

DHCP_STATE:	equ	PING_BUFFER+88	;DHCP state:
	;One of the "DHCP automaton states" constant or:
	;253: Error: No DHCP servers
	;254: Error: No reply from server

DHCP_VAR_START:
DHCP_XID:	equ	DHCP_STATE+1	;Next DHCP XID to use
DHCP_SNDTIM:	equ	DHCP_XID+4	;Timer for sending next packet
DHCP_TRIES:	equ	DHCP_SNDTIM+1	;DHCP packets sent
DHCP_RCVXID:	equ	DHCP_TRIES+1	;XID of last received packet
DHCP_SERVER:	equ	DHCP_RCVXID+4	;Server IP
DHCP_T1:	equ	DHCP_SERVER+4	;T1 timer
DHCP_T2:	equ	DHCP_T1+4	;T2 timer
DHCP_LEASE:	equ	DHCP_T2+4	;IP address lease
DHCP_SECS:	equ	DHCP_LEASE+4	;Seconds since process started
DHCP_SECS_T:	equ	DHCP_SECS+2	;1/60 secs timer for updating SECS
DHCP_YIADDR:	equ	DHCP_SECS_T+1	;Offered IP
DHCP_VAR_END:

DHCP_OP_OVL:	equ	DHCP_YIADDR+4	;Used by DHCP_OP_NEXT: "Option overload" option found
DHCP_OP_PNT:	equ	DHCP_OP_OVL+1	;Used by DHCP_OP_NEXT: Pointer to next option

	;--- Temporary data area

NUMBUF:	equ	DHCP_OP_PNT+2	;Used by POR60_32
CHK_EVEN:	equ	NUMBUF+1	;Used by CALC_CHKSUM
TEMP:	equ	CHK_EVEN+4	;Generic 16 byte buffer for functions use
DGRAM_BUF:	equ	TEMP+16	;536 byte buffer to hold one datagram

	;--- Data for the CAPS blink test

BLINK_RATE:	equ	50
CAPS_STATE:	equ	TEMP
CAPS_CNT:	equ	TEMP+1


;********************************************
;***  ROM HEADER AND INITIALIZATION CODE  ***
;********************************************

	org	04000h

	;--- ROM header

	db	"AB"
	dw	BOOT
	dw	STATEMENT
	ds	10

	;--- Card MAC address
	;    Format: CC-CC-CC-SS-SS-NN
	;    CC: Common identifier for MSX network cards (#58,#53,#4D)
	;    SS: Series identifier (00-01 for Denyonet)
	;    NN: Serial number within the series

CARD_MAC:
	db	#58,#53,#4D,#00,#01,#01

	;--- Supporting code for the DENYINIT.COM tool

L4016:	db	"DenYoNet TCP/IP BIOS ",ROM_V_P+48,".",ROM_V_S+48,0
	ds	#4036-$,#FF

L4036:
	;* Entry point for DENYINIT.COM.
	;  If BIOS is already initialized, return A!=0 and NZ.
	;  Otherwise initialize BIOS and return A=0 and Z.

	call	GETSLTP1
	call	GETWRK
	ld	a,(hl)
	or	a
	ret	nz
	call	ROM_INIT
	xor	a
	ret

BOOT:
	;--- Show informative message

	ld	hl,INITMSG
	call	PRINT

	;--- Do nothing if ESC is pressed
	;    (or if ESC is not pressed, if NO_INIT_BOOT = 1)

	call	GETSLTP1
	call	GETWRK
	xor	a
	ld	(hl),a

	ld	a,7
	call	SNSMAT
	and	4

	if	NO_INIT_BOOT = 0
	jr	nz,CONT_INIT
	endif

	if	NO_INIT_BOOT = 1
	jr	z,CONT_INIT
	endif

	ld	hl,NOINITMSG
	call	PRINT
	ret
CONT_INIT:

	;--- Patch EXTBIO hook

ROM_INIT:

	;* Initialize EXTBIO hook if necessary

	ld	a,(HOKVLD)
	bit	0,a
	jr	nz,OK_INIEXTB

	ld	hl,EXTBIO
	ld	de,EXTBIO+1
	ld	bc,15-1		;Initialize EXTBIO, DISINT and ENAINT
	ld	(hl),0C9h	;code for RET
	ldir

	or	1
	ld	(HOKVLD),a
OK_INIEXTB:

	;* Save previous EXTBIO hook

	call	GETSLTP1
	call	GETWRK
	ex	de,hl
	ld	hl,EXTBIO
	ld	bc,5
	ldir

	;* Patch EXTBIO hook

	if	NO_EXTBIO = 0

	di
	ld	a,0F7h	;code for "RST 030"
	ld	(EXTBIO),a
	call	GETSLTP1
	ld	(EXTBIO+1),a
	ld	hl,DO_EXTBIO
	ld	(EXTBIO+2),hl
	ei

	endif

	;--- Setup hardware

	call	GETSLTP2
	push	af

	call	GETSLTP1
	ld	h,#80
	call	ENASLT

	;Reset hardware

	call	DO_RESET

	;Set MAC address to default value

	call	SET_WIZ_REGS2
	ld	hl,(CARD_MAC)
	ld	de,(CARD_MAC+2)
	ld	bc,(CARD_MAC+4)
	call	SET_MAC

	;--- Clear and initialize data area

	call	SET_WIZ_BUF2
	ld	hl,DATA_BASE
	ld	de,DATA_BASE+1
	ld	bc,DATA_LIMIT-DATA_BASE-1
	ld	(hl),0
	ldir

	ld	a,64
	ld	(DEFAULT_TTL),a
	xor	a
	ld	(DEFAULT_TOS),a
	ld	a,3
	ld	(AUTOIP_CONFIG),a

	;--- Set the new timer interrupt hook

	if	NO_TIMI = 0

	di
	ld	hl,H_TIMI
	ld	de,OLD_TIMI
	ld	bc,5
	ldir

	ld	a,0F7h	;"RST 30h"
	ld	(H_TIMI),a
	call	GETSLTP1
	ld	(H_TIMI+1),a
	ld	hl,NEW_TIMI
	ld	(H_TIMI+2),hl
	ld	a,0C9h	;"RET"
	ld	(H_TIMI+4),a
	ei

	endif

	;Hide W5100 registers.
	;Without this, the W5100 is reset again and MAC address is lost.
	;Probably the MSX startup code messes with the
	;W5100 memory thinking that it is standard RAM.

	call	SET_WIZ_BUF2

	pop	af
	ld	h,#80
	call	ENASLT

	ret


;***********************
;***  HOOK PATCHING  ***
;***********************

;--- Handle the CALL command

STATEMENT:
	push	hl

	ld	hl,PROCNM
	ld	de,DENYOHOOKS_S

STMNT_LOOP:
	ld	a,(de)
	cp	(hl)
	jr	z,STMNT_OKCHAR
	pop	hl
	scf
	ret		;Command does not match

STMNT_OKCHAR:
	inc	hl
	inc	de
	or	a
	jr	nz,STMNT_LOOP

	call	GETSLTP1
	call	GETWRK
	ld	a,(hl)
	or	a
	jr	z,STMNT_OK

	;* BIOS is already initialized

	ld	hl,ALR_PATCHED
	call	PRINT
	pop	hl
	or	a
	ret
STMNT_OK:

	;* Now activate the BIOS

	call	ROM_INIT
	ld	hl,OK_PATCHED
	call	PRINT

	pop	hl
	or	a
	ret

PRINT:
	ld	a,(hl)
	or	a
	ret	z
	call	CHPUT
	inc	hl
	jr	PRINT

ALR_PATCHED:
	db	"ERROR: Denyonet is already active.",0
OK_PATCHED:
	db	"Denyonet has been successfully activated.",0
DENYOHOOKS_S:
	db	"DENYOINIT",0


;*********************************
;***  TIMER INTERRUPT HANDLER  ***
;*********************************

NEW_TIMI:
	push	af	;save VDP status

	call	GETSLTP2
	push	af

	call	GETSLTP1
	ld	h,#80
	call	ENASLT

	in	a,(WIZ_PORT)
	push	af
	call	SET_WIZ_BUF2

	ld	a,(INSIDE_FUNC)
	or	a
	jr	nz,END_TIMI

	ld	a,(INSIDE_INT)
	or	a
	jr	nz,END_TIMI

	cpl
	ld	(INSIDE_INT),a

	;--- Receive a packet from socket 0

	call	SET_WIZ_REGS2
	ld	a,(WIZ_SOCKREG_BASE+WIZ_Sn_SR)
	cp	SOCK_UDP	;Is socket 0 actually open in UDP or IP raw mode?
	jr	z,TIMI_SOCKET0_OK
	cp	SOCK_IPRAW
	jr	nz,TIMI_PACKET_END
TIMI_SOCKET0_OK:

	push	af
	call	UDP_STATE_INTERNAL	;Is there any packet available?
	ld	a,b
	or	a
	jr	nz,TIMI_ISPACKET
	pop	af
	jr	TIMI_PACKET_END
TIMI_ISPACKET:

	call	UDP_RCV_INTERNAL	;Retrieve the oldest UDP packet from socket 0

	call	SET_WIZ_BUF2
	pop	af
	ld	iy,TIMI_PACKET_END
	push	iy

	;At this point HL,DE,BC,IX must be preserved from UDP_RCV_INTERNAL
	cp	SOCK_IPRAW
	jp	z,PROCESS_PING_PACKET
	push	ix
	pop	de
	ld	hl,DNS_SERVER_PORT
	call	COMP16
	jp	z,PROCESS_DNS_PACKET
	ld	hl,DHCP_SERVER_PORT
	call	COMP16
	jp	z,PROCESS_DHCP_PACKET
	pop	de	;Non-DNS and non-DHCP packets are ignored

TIMI_PACKET_END:

	call	SET_WIZ_BUF2
	call	DO_DNS_TIMERS
	call	DO_DHCP_TIMERS
	;call	BLINK_TEST

	call	SET_WIZ_BUF2
	xor	a
	ld	(INSIDE_INT),a
END_TIMI:
	if	NO_TIMI=0
	call	OLD_TIMI
	endif

	pop	af
	out	(WIZ_PORT),a

	pop	af
	ld	h,#80
	call	ENASLT

	pop	af
	ret


	;--- Test: make CAPS led to blink

BLINK_TEST:
	ld	a,(CAPS_CNT)
	dec	a
	ld	(CAPS_CNT),a
	or	a
	ret	nz

	ld	a,BLINK_RATE
	ld	(CAPS_CNT),a

	ld	a,(CAPS_STATE)
	cpl
	ld	(CAPS_STATE),a
	or	a
	jr	nz,DO_CAPS_ON

DO_CAPS_OFF:
	in	a,(#AA)
	or	%01000000
	jr	DO_CAPS_END

DO_CAPS_ON:
	in	a,(#AA)
	and	%10111111

DO_CAPS_END:
	out	(#AA),a
	ret


;*******************************************
;***  INCOMING IP RAW PACKET PROCESSING  ***
;*******************************************

PROCESS_PING_PACKET:

	;--- Do nothing if we have no free space in the PING buffer

	ld	a,(PING_COUNT)
	cp	8
	ret	z

	;--- Check datagram header

	push	bc,hl,de
	ld	hl,(DGRAM_BUF)	;ICMP Type and Code, both must be 0
	ld	a,h
	or	l
	jr	nz,PROC_PING_END

	ld	ix,DGRAM_BUF
	call	CALC_CHKSUM
	jr	nz,PROC_PING_END

	;--- Calculate address of buffer for PING data

	ld	a,(PING_WRITE_INDEX)
	ld	ix,PING_BUFFER-11
	ld	de,11
	ld	b,a
	inc	b
CALC_PING_BUF:
	add	ix,de
	djnz	CALC_PING_BUF

	;--- Write data from datagram in buffer

	pop	de,hl		;source IP
	ld	(ix),h
	ld	(ix+1),l
	ld	(ix+2),d
	ld	(ix+3),e

	;W5100 does not provide a way to retrieve the TTL of incoming datagrams
	;unless we open socket 0 in MAC raw mode.
	;But if we do that we must manually handle the whole IP header.
	;Too much a hassle for now, maybe in a future version.
	ld	(ix+4),0	;TTL

	ld	hl,(DGRAM_BUF+4)	;ICMP identifier
	ld	(ix+5),h
	ld	(ix+6),l
	ld	hl,(DGRAM_BUF+6)	;ICMP sequence
	ld	(ix+7),h
	ld	(ix+8),l

	pop	hl
	ld	bc,-8
	add	hl,bc
	ld	(ix+9),l	;Data length
	ld	(ix+10),h

	;--- Adjust buffer and terminate

	ld	hl,PING_COUNT
	inc	(hl)

	ld	a,(PING_WRITE_INDEX)
	inc	a
	and	%00000111	;Loop from 7 to 0 again
	ld	(PING_WRITE_INDEX),a

	ret

PROC_PING_END:
	pop	de,hl,bc
	ret


;****************************************
;***  INCOMING DNS PACKET PROCESSING  ***
;****************************************

PROCESS_DNS_PACKET:

	;* Is a DNS query actually in progress?

	ld	a,(DNS_STAT_P)
	cp	1
	ret	nz

	;* Check if  the response ID matches the last sent query ID;
	;  if not, discard the packet.

	ld	hl,(DGRAM_BUF)
	ld	de,(ID_DNS)
	call	COMP16
	ret	nz

	;* If the response is truncated, terminate with error 21
	;  unless we can try with secondary server.

	ld	a,(DGRAM_BUF+2)
	and	%00000010
	jr	z,DNS_NOTRUNC

	call	DNS_USE_SEC
	ret	nc

	ld	a,3
	ld	(DNS_STAT_P),a
	ld	a,21
	ld	(DNS_STAT_S),a
	ret
DNS_NOTRUNC:

	;* If the response contains any error, set it and terminate,
	;  unless we can try with secondary server.

	ld	a,(DGRAM_BUF+3)
	and	%00001111
	jr	z,DNS_NOERR

	call	DNS_USE_SEC
	ret	nc

	ld	a,3
	ld	(DNS_STAT_P),a
	ld	a,(DGRAM_BUF+3)
	and	%00001111
	ld	(DNS_STAT_S),a
	ret
DNS_NOERR:

	;* The response does not contain any error.
	;  Check if it contains any valid resource information.

	ld	ix,DGRAM_BUF	;Point to packet start DNS

	ld	h,(ix+6)
	ld	l,(ix+7)
	ld	(ANCOUNT),hl	;Resource count
	ld	h,(ix+8)
	ld	l,(ix+9)
	ld	(NSCOUNT),hl	;Authoritative servers count
	ld	h,(ix+10)
	ld	l,(ix+11)
	ld	(ARCOUNT),hl	;Additional sections count

	ld	ix,DGRAM_BUF+12	;IX=Start of query

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
	ret

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
	ret

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

	ret


;*******************************
;***  DNS TIMERS PROCESSING  ***
;*******************************

DO_DNS_TIMERS:

	;* Is a DNS query in progress?

	ld	a,(DNS_STAT_P)
	cp	1
	ret	nz

	;* Is socket 0 still open? (it should!)

	xor	a
	call	SET_CUR_CONN

	call	SET_WIZ_REGS2
	ld	a,(WIZ_SOCKREG_BASE+WIZ_Sn_SR)
	cp	SOCK_UDP	;Open UDP connection?
	jr	z,DNSTIM_OKCONN

	ld	a,3
	ld	(DNS_STAT_P),a
	ld	a,19
	ld	(DNS_STAT_S),a
	jp	OPEN_S0_FOR_UDP

DNSTIM_OKCONN:
	call	SET_WIZ_BUF2

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
	ret
DNS_NOEXPTOT:

	;* Resend timer expired?

	ld	a,(DNS_TOUT)
	dec	a
	ld	(DNS_TOUT),a
	ret	nz

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
	ret

	;* Resend DNS query

	;Compose packet

DNS_RESEND:
	ld	hl,(ID_DNS)	;Identifier
	inc	hl
	ld	(DGRAM_BUF),hl
	ld	(ID_DNS),hl

	ld	hl,#0001	;Recursion desired, other flags to 0
	ld	(DGRAM_BUF+2),hl

	ld	hl,#0100
	ld	(DGRAM_BUF+4),hl	;QDCOUNT
	ld	h,0
	ld	(DGRAM_BUF+6),hl	;ANCOUNT
	ld	(DGRAM_BUF+8),hl	;NSCOUNT
	ld	(DGRAM_BUF+10),hl	;ARCOUNT

	ld	hl,DNS_BUFFER	;Name to be resolved
	ld	ix,DGRAM_BUF+12
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
	ld	bc,DGRAM_BUF
	or	a
	sbc	hl,bc
	push	hl
	pop	bc	;BC = Packet length

	ld	ix,DNS_SERVER_PORT
	ld	hl,(DNS_IP)
	ld	de,(DNS_IP+2)
	call	UDP_SEND_INTERNAL

	;Update variables

	ld	a,3*60
	ld	(DNS_TOUT),a	;Retransmission timer
	ld	a,(DNS_RETRY)
	inc	a
	ld	(DNS_RETRY),a	;One more retransmission performed

	ret


;*****************************************
;***  INCOMING DHCP PACKET PROCESSING  ***
;*****************************************

PROCESS_DHCP_PACKET:

	;* Are we using DHCP for anything at all?

	ld	a,(AUTOIP_CONFIG)
	or	a
	ret	z

	;* Are our IPs already configured?

	ld	a,(DHCP_STATE)
	cp	CONFIGURED
	ret	z

	;* Obtain packet type

	ld	a,(DGRAM_BUF)	;BOOTREPLY?
	cp	2
	ret	nz

	ld	hl,DGRAM_BUF+4	;'xid' matches?
	ld	de,DHCP_XID
	call	COMP32
	ret	nz

	call	DHCP_GET_TYPE
	cp	DHCPOFFER
	jr	z,IS_DHCP_OFFER
	cp	DHCPACK
	jr	z,IS_DHCP_ACK
	cp	DHCPNAK
	jp	z,IS_DHCP_NAK
	ret		;Other types are ignored

	;--- DHCPOFFER packet

IS_DHCP_OFFER:

	;* If not in SELECTING state, ignore it

	ld	a,(DHCP_STATE)
	cp	SELECTING
	ret	nz

	;* Save server identifier

	call	DHCP_GET_SERVER
	ret	c
	ld	de,DHCP_SERVER
	ld	bc,4
	ldir

	;* Save 'yiaddr' field as the offered IP address

	ld	hl,DGRAM_BUF+16
	ld	de,DHCP_YIADDR
	ld	bc,4
	ldir

	;* Save received 'xid'

	ld	hl,DGRAM_BUF+4
	ld	de,DHCP_RCVXID
	ld	bc,4
	ldir

	;* Enter REQUESTING state and send DHCPREQUEST

	ld	a,REQUESTING
	ld	(DHCP_STATE),a
	ld	a,DHCPREQUEST
	call	SEND_DHCP
	jp	DHCP_FIRST

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
	ret	nz
ISDHCPACK3:

	;* If server identifier does not match the previous one, ignore message
	;  (Problem: What if ACK has been received in REBINDING state,
	;  by a server different from the one used previously?
	;  For this reason, we'll rely on XID only)

	;call	DHCP_GET_SERVER
	;ret	c
	;ld	de,DHCP_SERVER
	;call	COMP32
	;ret	nz

	;* Initialize fields Lease, T1 and T2

	ld	hl,DHCP_T1
	ld	de,DHCP_T1+1
	ld	bc,12-1
	ld	(hl),0
	ldir

	;* Save 'yiaddr' field as the assigned IP,
	;  unless we had sent DHCPINFORM

	ld	a,(AUTOIP_CONFIG)
	and	1
	jr	z,ISDHCPACK4

	ld	hl,(DGRAM_BUF+16)
	ld	de,(DGRAM_BUF+18)
	call	SET_WIZ_REGS2
	ld	(WIZ_SIPR),hl
	ld	(WIZ_SIPR+2),de
	call	SET_WIZ_BUF2
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

	ld	a,(AUTOIP_CONFIG)
	and	1	;Requested?
	jr	z,ISDHCPACKL

	ld	l,(ix)
	ld	h,(ix+1)
	ld	e,(ix+2)
	ld	d,(ix+3)
	call	SET_WIZ_REGS2
	ld	(WIZ_SUBR),hl
	ld	(WIZ_SUBR+2),de
	call	SET_WIZ_BUF2

	jr	ISDHCPACKL
ISDHCPACK_NOSB:

	;* Default gateway: store it if we had requested it

	cp	3
	jr	nz,ISDHCPACK_NOGW

	ld	a,(AUTOIP_CONFIG)
	and	1	;Requested?
	jr	z,ISDHCPACKL

	ld	l,(ix)
	ld	h,(ix+1)
	ld	e,(ix+2)
	ld	d,(ix+3)
	call	SET_WIZ_REGS2
	ld	(WIZ_GAR),hl
	ld	(WIZ_GAR+2),de
	call	SET_WIZ_BUF2

	jp	ISDHCPACKL
ISDHCPACK_NOGW:

	;* DNS servers: store them if we had requested them

	cp	6
	jr	nz,ISDHCPACK_NODN

	ld	a,(AUTOIP_CONFIG)
	and	%10	;Requested?
	jp	z,ISDHCPACKL

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
	jp	CLOSE_S0
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
	ld	de,NUMBUF
	ld	bc,4
	ldir

	ld	b,6
T2ISZL:	push	bc	;Multiply (T2/8) by 7
	ld	hl,NUMBUF
	ld	de,DHCP_T2
	ld	bc,DHCP_T2
	call	ADD32
	pop	bc
	djnz	T2ISZL
OKT2NZ:

	;* End: enter BOUND and terminate

	ld	a,BOUND
	ld	(DHCP_STATE),a
	jp	CLOSE_S0

	;--- NAK packet

IS_DHCP_NAK:

	;* In BOUND, SELECTING, INFORMING or CONFIGURED states, ignore it

	ld	a,(DHCP_STATE)
	cp	BOUND
	ret	z
	cp	SELECTING
	ret	z
	cp	INFORMING
	ret	z
	cp	CONFIGURED
	ret	z

	;* In other states, return to INIT

	xor	a	;ld     a,INIT
	ld	(DHCP_STATE),a
	ret


;--- DHCP_NEXT_OP: Return next DHCP option in this way:
;    A  = Code (0=no more options available)
;    B  = Length
;    IX = Pointer to option data
;    Takes in account "option overload".
;    Must be initialized with DHCP_INIT_OP.

DHCP_INIT_OP:
	xor	a
	ld	(DHCP_OP_OVL),a
	ld	ix,DGRAM_BUF+240	;'options' field after cookie
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
	ld	ix,DGRAM_BUF+108	;'file' field
	jr	DHCPNO_LOOP
DHCPNO_NOFILE:

	xor	a
	ld	(DHCP_OP_OVL),a
	ld	ix,DGRAM_BUF+44	;'sname' field
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


;--- SEND_DHCP: Send a DHCP packet of the type passed in A

SEND_DHCP:
	;--- Common initialization

	push	af
	xor	a
	call	SET_CUR_CONN
	call	OPEN_S0_FOR_UDP
	pop	af

	ld	hl,DGRAM_BUF	;Clear output buffer
	ld	de,DGRAM_BUF+1
	ld	bc,536-1
	ld	(hl),0
	ldir

	ld	(DGRAM_BUF+242),a	;Set message type

	ld	hl,#0101	;Common header ('op' to 'hops')
	ld	(DGRAM_BUF),hl
	ld	hl,#0006
	ld	(DGRAM_BUF+2),hl

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
	ld	de,DGRAM_BUF+4
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
	ld	(DGRAM_BUF+8),hl

	ld	hl,#0080
	ld	(DGRAM_BUF+10),hl
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
	call	SET_WIZ_REGS2
	ld	hl,(WIZ_SIPR)
	ld	de,(WIZ_SIPR+2)
	call	SET_WIZ_BUF2
	ld	ix,DGRAM_BUF+12
	ld	(ix),l
	ld	(ix+1),h
	ld	(ix+2),e
	ld	(ix+3),d
	ld	a,b
SDHCP_OKCIADR:

	;--- 'chaddr': MAC address

	push	af
	call	SET_WIZ_REGS2
	ld	ix,WIZ_SHAR
	ld	l,(ix)
	ld	h,(ix+1)
	ld	e,(ix+2)
	ld	d,(ix+3)
	ld	c,(ix+4)
	ld	b,(ix+5)
	call	SET_WIZ_BUF2
	ld	(DGRAM_BUF+28),hl
	ld	(DGRAM_BUF+30),de
	ld	(DGRAM_BUF+32),bc
	pop	af

	;--- Options: first, magic cookie and "message type" option

	ld	hl,DHCP_COOKIE
	ld	de,DGRAM_BUF+236
	ld	bc,6
	ldir

	;--- Other options: according to message type and DHCP_VECT

	ld	ix,DGRAM_BUF+243	;Pointer to add options

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
	ld	a,(AUTOIP_CONFIG)

	;Subnet mask and default gateway

	bit	0,a
	jr	z,SDHCP_OKOPMASK

	ld	(ix),1
	inc	b
	inc	ix
	ld	(ix),3
	inc	b
	inc	ix
SDHCP_OKOPMASK:

	;DNS servers

	bit	1,a
	jr	z,SDHCP_OKOPDNS

	ld	(ix),6
	inc	b
	inc	ix
SDHCP_OKOPDNS:

	;Set option length

	ld	(hl),b
SDHCP_OKREQOPS:

	;--- Packet is complete: calculate resulting size

	push	ix
	pop	hl
	ld	bc,DGRAM_BUF
	or	a
	sbc	hl,bc
	push	hl
	pop	bc

	;--- Destination IP address: if DHCP_SERVER is 0,
	;    or if packet is DHCPREQUEST in REQUESTING or REBINDING state,
	;    send to broadcast; otherwise, to the appropriate address

	ld	a,(DGRAM_BUF+242)
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

	ld	ix,67
	jp	UDP_SEND_INTERNAL

DHCP_COOKIE:	db	99,130,83,99,53,1	;Includes "message type" option


;--- DHCP_DO_INIT: Initialize automaton in INIT state

DHCP_DO_INIT:
	;* Clear all DHCP variables except XID

	ld	hl,DHCP_XID+4
	ld	de,DHCP_XID+4+1
	ld	bc,DHCP_YIADDR-DHCP_XID-4-1

	ld	(hl),0
	ldir

	;* Clear appropriate IP addresses, depending on DHCP_VECT

	ld	a,(AUTOIP_CONFIG)
	ld	hl,0

	bit	0,a
	jr	z,DHCP2INIT_1
	push	af
	call	SET_WIZ_REGS2
	ld	(WIZ_SIPR),hl
	ld	(WIZ_SIPR+2),hl
	ld	(WIZ_SUBR),hl
	ld	(WIZ_SUBR+2),hl
	ld	(WIZ_GAR),hl
	ld	(WIZ_GAR+2),hl
	call	SET_WIZ_BUF2
	pop	af
DHCP2INIT_1:

	bit	1,a
	jr	z,DHCP2INIT_2
	ld	(BUF_IPDNS1),hl
	ld	(BUF_IPDNS1+2),hl
	ld	(BUF_IPDNS2),hl
	ld	(BUF_IPDNS2+2),hl
DHCP2INIT_2:

	ret


;--- DHCP timers initial values

ARP_TOUT_DEF:	db	#00,#00,#46,#50	;5 minutes * 60 secs * 60 ints
ARP_TOUT_DEF2:	db	#00,#00,#01,#2C	;5 minutes * 60 secs


;********************************
;***  DHCP TIMERS PROCESSING  ***
;********************************

DO_DHCP_TIMERS:

	;* Are we using DHCP for anything at all?

	ld	a,(AUTOIP_CONFIG)
	or	a
	ret	z

	ld	a,(DHCP_STATE)
	cp	CONFIGURED
	ret	z


	;* INIT state:
	;  Enter SELECTING or INFORMING, send DHCPDISCOVER or DHCPINFORM,
	;  and initialize retransmission timer

	ld	a,(DHCP_STATE)
	or	a	;cp INIT
	jr	nz,TDHCP_NOINIT

	call	SET_WIZ_BUF2
	call	DHCP_DO_INIT

	ld	a,(AUTOIP_CONFIG)	;SELECTING if IP required, INFORMING otherwise
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

	ret



;*******************************
;***  EXTBIO HOOK EXECUTION  ***
;*******************************

DO_EXTBIO:
	push	hl
	push	bc
	push	af
	ld	a,d
	cp	022h
	jr	nz,JUMP_OLD
	cp	e
	jr	nz,JUMP_OLD

	;Check API ID

	ld	hl,UNAPI_ID
	ld	de,ARG
LOOP:	ld	a,(de)
	call	TOUPPER
	cp	(hl)
	jr	nz,JUMP_OLD2
	inc	hl
	inc	de
	or	a
	jr	nz,LOOP

	;A=255: Jump to old hook

	pop	af
	push	af
	inc	a
	jr	z,JUMP_OLD2

	;A=0: B=B+1 and jump to old hook

	call	GETSLTP1
	call	GETWRK
	pop	af
	pop	bc
	or	a
	jr	nz,DO_EXTBIO2
	inc	b
	ex	(sp),hl
	ld	de,02222h
	ret
DO_EXTBIO2:

	;A=1: Return A=Slot, B=Segment, HL=UNAPI entry address

	dec	a
	jr	nz,DO_EXTBIO3
	pop	hl
	call	GETSLTP1
	ld	b,0FFh
	ld	hl,UNAPI_ENTRY
	ld	de,02222h
	ret

	;A>1: A=A-1, and jump to old hook

DO_EXTBIO3:	;A=A-1 already done
	ex	(sp),hl
	ld	de,02222h
	ret

	;--- Jump here to execute old EXTBIO code

JUMP_OLD2:
	ld	de,02222h
JUMP_OLD:	;Assumes "push hl,bc,af" done
	push	de
	call	GETSLTP1
	call	GETWRK
	pop	de
	pop	af
	pop	bc
	ex	(sp),hl
	ret


;************************************
;***  FUNCTIONS ENTRY POINT CODE  ***
;************************************

UNAPI_ENTRY:
	push	hl
	push	af
	ld	hl,FN_TABLE
	bit	7,a

	if	MAX_IMPFN >= 128

	jr	z,IS_STANDARD
	ld	hl,IMPFN_TABLE
	and	%01111111
	cp	MAX_IMPFN-128
	jr	z,OK_FNUM
	jr	nc,UNDEFINED
IS_STANDARD:

	else

	jr	nz,UNDEFINED

	endif

	cp	MAX_FN
	jr	z,OK_FNUM
	jr	nc,UNDEFINED

OK_FNUM:
	add	a,a
	push	de
	ld	e,a
	ld	d,0
	add	hl,de
	pop	de

	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a

	pop	af
	ex	(sp),hl
	ret

	;--- Undefined function: return with registers unmodified

UNDEFINED:
	pop	af
	pop	hl
	ret


;***********************************
;***  FUNCTIONS ADDRESSES TABLE  ***
;***********************************

;--- Standard routines addresses table

FN_TABLE:
FN_0:	dw	UNAPI_GET_INFO
FN_1:	dw	TCPIP_GET_CAPAB
FN_2:	dw	TCPIP_GET_IPINFO
FN_3:	dw	TCPIP_NET_STATE
FN_4:	dw	TCPIP_SEND_ECHO
FN_5:	dw	TCPIP_RCV_ECHO
FN_6:	dw	TCPIP_DNS_Q
FN_7:	dw	TCPIP_DNS_S
FN_8:	dw	TCPIP_UDP_OPEN
FN_9:	dw	TCPIP_UDP_CLOSE
FN_10:	dw	TCPIP_UDP_STATE
FN_11:	dw	TCPIP_UDP_SEND
FN_12:	dw	TCPIP_UDP_RCV
FN_13:	dw	TCPIP_TCP_OPEN
FN_14:	dw	TCPIP_TCP_CLOSE
FN_15:	dw	TCPIP_TCP_ABORT
FN_16:	dw	TCPIP_TCP_STATE
FN_17:	dw	TCPIP_TCP_SEND
FN_18:	dw	TCPIP_TCP_RCV
FN_19:	dw	TCPIP_TCP_FLUSH
FN_20:	dw	FN_NOT_IMP	;TCPIP_RAW_OPEN
FN_21:	dw	FN_NOT_IMP	;TCPIP_RAW_CLOSE
FN_22:	dw	FN_NOT_IMP	;TCPIP_RAW_STATE
FN_23:	dw	FN_NOT_IMP	;TCPIP_RAW_SEND
FN_24:	dw	FN_NOT_IMP	;TCPIP_RAW_RCV
FN_25:	dw	TCPIP_CONFIG_AUTOIP
FN_26:	dw	TCPIP_CONFIG_IP
FN_27:	dw	TCPIP_CONFIG_TTL
FN_28:	dw	TCPIP_CONFIG_PING
FN_29:	dw	TCPIP_WAIT

;--- Implementation-specific routines addresses table

IMPFN_TABLE:
;FN_128:	dw	...


;************************
;***  FUNCTIONS CODE  ***
;************************

	;========================
	;===  UNAPI_GET_INFO  ===
	;========================

;Obtain the implementation name and version.
;
;Input:  A = 0
;Output: A  = Error code
;        HL = Address of the implementation name string
;        DE = API specification version supported. D=primary, E=secondary.
;        BC = API implementation version. B=primary, C=secondary.

UNAPI_GET_INFO:
	ld	bc,256*ROM_V_P+ROM_V_S
	ld	de,256*API_V_P+API_V_S
	ld	hl,APIINFO
	xor	a
	ret


	;=========================
	;===  TCPIP_GET_CAPAB  ===
	;=========================

;Get information about the TCP/IP capabilities and features.
;
;Input:  A = 1
;        B = Index of information block to retrieve:
;            1: Capabilities and features flags, link level protocol
;            2: Connection pool size and status
;            3: Maximum datagram size allowed
;Output: A = Error code
;        When information block 1 requested:
;            HL = Capabilities flags
;            DE = Features flags
;            B  = Link level protocol used
;        When information block 2 requested:
;            B = Maximum simultaneous TCP connections supported
;            C = Maximum simultaneous UDP connections supported
;            D = Free TCP connections currently available
;            E = Free UDP connections currently available
;            H = Maximum simultaneous raw IP connections supported
;            L = Free raw IP connections currently available
;        When information block 3 requested:
;            HL = Maximum incoming datagram size supported
;            DE = Maximum outgoing datagram size supported


TCPIP_GET_CAPAB:
	ld	a,b
	or	a
	jp	z,END_INV_PAR
	cp	3+1
	jp	nc,END_INV_PAR

	dec	a
	jr	z,GETCAP_1
	dec	a
	jr	z,GETCAP_2

	;--- Info block 3

GETCAP_3:
	ld	hl,576	;Should be 1024?
	ld	de,576	;Should be 1024?
	xor	a
	ret

	;--- Info block 2

GETCAP_2:
	call	SETSLOTP2
	call	SET_WIZ_REGS2
	ld	ix,WIZ_SOCKREG_BASE+WIZ_SOCKREG_SIZE
	ld	de,WIZ_SOCKREG_SIZE
	ld	h,0	;Free connections count
	ld	b,3
GETCAP2_LOOP:
	ld	a,(ix+WIZ_Sn_SR)	;Is the connection in use?
	or	a
	jr	nz,GETCAP_2_NEXT
	inc	h
GETCAP_2_NEXT:
	add	ix,de
	djnz	GETCAP2_LOOP

	ld	bc,#0303
	ld	d,h
	ld	e,h
	ld	hl,0
	jp	RESTSLOTP2

	;--- Info block 1

GETCAP_1:

	; Capability flags ENABLED:
	;- Send ICMP echo messages (PINGs) and retrieve the answers
	;- Resolve host names by querying a DNS server
	;- Explicitly set the TTL and TOS for outgoing datagrams
	;- Open UDP connections
	;- Explicitly set the automatic reply to PINGs on or off
	;- Open TCP connections in active mode
	;- Open TCP connections in passive mode, with unsepecified remote socket
	;- Automatically obtain the IP addresses, by using DHCP or an equivalent protocol
	;
	; Capability flags DISABLED:
	;- Send ICMP echo messages (PINGs) and retrieve the answers
	;- Resolve host names by querying a local hosts file or database
	;- Open TCP connections in passive mode, with specified remote socket
	;- Send and receive TCP urgent data
	;- Send data to a TCP connection before the ESTABLISHED state is reached
	;- Flush the output buffer of a TCP connection
	;- Open raw IP connections
	;- Explicitly set the PUSH bit when sending TCP data

	ld	hl,% 0 111010000101101

	; Features flags ENABLED:
	; - Connection pool is shared by TCP, UDP and raw IP
	; - The TCP/IP handling code is assisted by external hardware

	ld	de,% 0000000 000010100

	ld	b,3	;Ethernet protocol
	xor	a
	ret


	;==========================
	;===  TCPIP_GET_IPINFO  ===
	;==========================

;Get IP address.
;
;Input:  A = 2
;        B = Index of address to obtain:
;            1: Local IP address
;            2: Peer IP address
;            3: Subnet mask
;            4: Default gateway
;            5: Primary DNS server IP address
;            6: Secondary DNS server IP address
;Output: A = Error code
;        L.H.E.D = Requested address

TCPIP_GET_IPINFO:
	call	SETSLOTP2

	ld	a,b
	or	a
	jp	z,END_INV_PAR_R

	;--- Local IP address

	dec	a
	jr	nz,GETIP_NO1
	call	SET_WIZ_REGS2
	ld	hl,(WIZ_SIPR)
	ld	de,(WIZ_SIPR+2)
	xor	a
	jp	RESTSLOTP2
GETIP_NO1:

	;--- Peer IP address

	dec	a
	jp	z,END_INV_PAR_R

	;--- Subnet mask

	dec	a
	jr	nz,GETIP_NO3
	call	SET_WIZ_REGS2
	ld	hl,(WIZ_SUBR)
	ld	de,(WIZ_SUBR+2)
	xor	a
	jp	RESTSLOTP2
GETIP_NO3:

	;--- Default gateway

	dec	a
	jr	nz,GETIP_NO4
	call	SET_WIZ_REGS2
	ld	hl,(WIZ_GAR)
	ld	de,(WIZ_GAR+2)
	xor	a
	jp	RESTSLOTP2
GETIP_NO4:

	;--- Primary DNS

	dec	a
	jr	nz,GETIP_NO5
	call	SET_WIZ_BUF2
	ld	hl,(BUF_IPDNS1)
	ld	de,(BUF_IPDNS1+2)
	xor	a
	jp	RESTSLOTP2
GETIP_NO5:

	;--- Secondary DNS

	dec	a
	jp	nz,END_INV_PAR_R
	call	SET_WIZ_BUF2
	ld	hl,(BUF_IPDNS2)
	ld	de,(BUF_IPDNS2+2)
	xor	a
	jp	RESTSLOTP2


	;=========================
	;===  TCPIP_NET_STATE  ===
	;=========================

;Get network state.
;
;Input:  A = 3
;Output: A = Error code
;        B = Current network state:
;            0: Closed
;            1: Opening
;            2: Open
;            3: Closing
;            255: Unknown

;Note: for some reason, checking the Link led sometimes
;gives a false value of one (no link available).
;For this reason, we first check if any the Tx, Rx or collision
;leds are reset (data activity means there is link),
;if none is reset then we resort to checking the link bit.

TCPIP_NET_STATE:
NET_STATE_CORE:
	in	a,(WIZ_LEDS)
	ld	c,a
	and	%111
	cp	%111
	ld	b,2
	ld	a,0
	ret	nz
	ld	a,c

	rrca
	rrca
	rrca
	rrca
	or	%11111101
	cpl

	ld	b,a
	xor	a
	ret


	;=========================
	;===  TCPIP_SEND_ECHO  ===
	;=========================

;Send ICMP echo message (PING).
;
;Input:  A  = 4
;        HL = Address of echo parameters block
;Output: A = Error code
;
;Parameters block:
;
;+0 (4): IP address of the destination machine
;+4 (1): TTL for the datagram
;+5 (2): ICMP identifier
;+7 (2): ICMP sequence number
;+9 (2): Data length, 0 to maximum datagram size - 28

ECHO_IP:	equ	TEMP
ECHO_TTL:	equ	TEMP+4
ECHO_ID:	equ	TEMP+5
ECHO_SEQ:	equ	TEMP+7
ECHO_LEN:	equ	TEMP+9

TCPIP_SEND_ECHO:

	call	SETSLOTP2
	call	SET_WIZ_BUF2

	;--- Copy parameters block to temporary area

	ld	bc,DATA_BASE
	ld	(CURCONN_TX_BASE),bc
	ld	bc,DATA_LIMIT
	ld	(CURCONN_TX_LIMIT),bc

	ld	de,ECHO_IP
	ld	bc,11
	call	MSX_TO_WIZ

	;--- Check data length

	ld	hl,(ECHO_LEN)
	ld	de,576-28+1
	call	COMP16
	ld	a,ERR_LARGE_DGRAM
	jp	nc,RESTSLOTP2

	;--- Check netowrk connection

	call	NET_STATE_CORE
	ld	a,b
	or	a
	ld	a,ERR_NO_NETWORK
	jp	z,RESTSLOTP2

	;--- Compose the ICMP datagram

	ld	ix,DGRAM_BUF
	ld	(ix),8		;Type
	ld	(ix+1),0	;Code
	ld	(ix+2),0	;Checksum
	ld	(ix+3),0	;Checksum
	ld	hl,(ECHO_ID)
	ld	(ix+4),h
	ld	(ix+5),l
	ld	hl,(ECHO_SEQ)
	ld	(ix+6),h
	ld	(ix+7),l

	ld	bc,(ECHO_LEN)
	ld	a,b
	or	c
	jr	z,MKECHO_OK
	ld	hl,DGRAM_BUF+8	;Data
	ld	d,0
MKECHO_LOOP:
	ld	(hl),d
	inc	hl
	inc	d
	dec	bc
	ld	a,b
	or	c
	jr	nz,MKECHO_LOOP
MKECHO_OK:

	ld	a,(ECHO_TTL)
	ld	b,a
	call	SET_WIZ_REGS2
	ld	a,b
	ld	(WIZ_SOCKREG_BASE+WIZ_Sn_TTL),a
	call	SET_WIZ_BUF2

	;--- Calculate total message size and checksum

	ld	hl,(ECHO_LEN)
	ld	bc,8
	add	hl,bc
	push	hl
	pop	bc

	push	bc
	ld	ix,DGRAM_BUF
	call	CALC_CHKSUM
	ld	(DGRAM_BUF+2),de

	;--- Send the datagram

	call	OPEN_S0_FOR_IPRAW
	pop	bc
	ld	hl,(ECHO_IP)
	ld	de,(ECHO_IP+2)
	ld	a,#FF
	ld	(INSIDE_INT),a
	call	UDP_SEND_INTERNAL
	xor	a
	ld	(INSIDE_INT),a

	;xor     a
	jp	RESTSLOTP2

FN_NOT_IMP:
	ld	a,ERR_NOT_IMP
	ret


	;========================
	;===  TCPIP_RCV_ECHO  ===
	;========================

;Retrieve ICMP echo response message.
;
;Input:  A  = 5
;        HL = Address for the echo parameters block
;Output: A = Error code
;
;Echo parameters block is the same as TCPIP_SEND_ECHO.

TCPIP_RCV_ECHO:
	call	SETSLOTP2
	call	SET_WIZ_BUF2

	;--- Is there any incoming PING data available?

	ld	a,(PING_COUNT)
	or	a
	ld	a,ERR_NO_DATA
	jp	z,RESTSLOTP2

	;--- Calculate address of buffer for PING data

	ld	a,(PING_READ_INDEX)
	ld	ix,PING_BUFFER-11
	ld	de,11
	ld	b,a
	inc	b
CALC_PING_BUF_RCV:
	add	ix,de
	djnz	CALC_PING_BUF_RCV

	;--- Copy the data to MSX

	ld	bc,DATA_BASE
	ld	(CURCONN_TX_BASE),bc
	ld	bc,DATA_LIMIT
	ld	(CURCONN_TX_LIMIT),bc

	ex	de,hl
	push	ix
	pop	hl
	ld	bc,11
	call	WIZ_TO_MSX

	;--- Adjust PING pointers and terminate

	ld	hl,PING_COUNT
	dec	(hl)

	ld	a,(PING_READ_INDEX)
	inc	a
	and	%00000111	;Loop from 7 to 0 again
	ld	(PING_READ_INDEX),a

	xor	a
	jp	RESTSLOTP2


	;=====================
	;===  TCPIP_DNS_Q  ===
	;=====================

;Start a host name resolution query.
;
;Input:  A  = 6
;        HL = Address of the host name to be resolved, zero terminated
;        B  = Flags, when set to 1 they instruct the resolver to:
;             bit 0: Only abort the query currently in progress, if there is any
;                    (other flags and registers are then ignored)
;             bit 1: Assume that the passed name is an IP address,
;                    and return an error if this is not true
;             bit 2: If there is a query in progress already,
;                    do NOT abort it and return an error instead
;Output:  A = Error code
;         B = 0 if a query to a DNS server is in progress
;             1 if the name represented an IP address
;             2 if the name could be resolved locally
;         L.H.E.D = Resolved IP address
;                   (only if no error occurred and B=1 or 2 is returned)

TCPIP_DNS_Q:
	ld	a,b
	and	%11111000
	ld	a,ERR_INV_PARAM
	ret	nz

	call	SETSLOTP2
	call	SET_WIZ_BUF2

	bit	0,b
	jr	z,DNS_Q_NO_CANCEL

	;--- Only cancel the query in progress

	ld	a,3
	ld	(DNS_STAT_P),a
	ld	a,18
	ld	(DNS_STAT_S),a

	jp	RESTSLOTP2
DNS_Q_NO_CANCEL:

	;--- If there is a query in progress and
	;    B:2 is set, return an error

	bit	2,b
	jr	z,DNS_Q_NO_EXISTING

	ld	a,(DNS_STAT_P)
	or	a
	jr	z,DNS_Q_NO_EXISTING

	ld	a,ERR_QUERY_EXISTS
	jp	RESTSLOTP2
DNS_Q_NO_EXISTING:

	xor	a
	ld	(DNS_STAT_P),a
	ld	(DNS_STAT_S),a

	;--- Get the host name

	push	bc
	ld	bc,DATA_BASE
	ld	(CURCONN_TX_BASE),bc
	ld	bc,DATA_LIMIT
	ld	(CURCONN_TX_LIMIT),bc
	ld	de,DNS_BUFFER
	ld	bc,256
	call	MSX_TO_WIZ
	xor	a
	ld	(DNS_BUFFER+255),a

	;--- Try to parse the host name as an IP address

	call	PARSE_IP
	pop	bc
	jr	c,DNSQ_NO_IP
	ld	a,2
	ld	(DNS_STAT_P),a
	dec	a
	ld	(DNS_STAT_S),a
	ld	hl,(DNS_RESULT)
	ld	de,(DNS_RESULT+2)
	ld	b,1
	xor	a
	jp	RESTSLOTP2

	;--- The host name was not an IP address

DNSQ_NO_IP:
	bit	1,b	;Was "assume IP address" flag set?
	ld	a,ERR_INV_IP
	jp	nz,RESTSLOTP2

	;If DNS server query is not supported:
	;ld	a,ERR_NOT_IMP
	;jp	RESTSLOTP2

	;--- Check if there is any DNS server configured,
	;    if not, terminate with error

	ld	ix,BUF_IPDNS1
	ld	a,(ix)
	or	(ix+1)
	or	(ix+2)
	or	(ix+3)
	or	(ix+4)
	or	(ix+5)
	or	(ix+6)
	or	(ix+7)
	ld	a,ERR_NO_DNS
	jp	z,RESTSLOTP2

	;--- Check netowrk connection

	call	NET_STATE_CORE
	ld	a,b
	or	a
	ld	a,ERR_NO_NETWORK
	jp	z,RESTSLOTP2

	;--- Prepares variables so that query will start
	;    in the next timer interrupt

	di

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

	ld	b,0

	;--- Ensure socket 0 is open for UDP and terminate

	call	OPEN_S0_FOR_UDP

	xor	a
	ei
	jp	RESTSLOTP2


	;=====================
	;===  TCPIP_DNS_S  ===
	;=====================

;Obtains the host name resolution process state and result.
;
;Input:  A = 7
;        B = Flags, when set to 1 they instruct the resolver to:
;            bit 0: Clear any existing result or error condition after the execution
;                   (except if there is a query in progress)
;Output: A = Error code
;        B = DNS error code (when error is ERR_DNS)
;        B = Current query status (when error is ERR_OK):
;            0: There is no query in progress, nor any result nor error code available
;            1: There is a query in progress
;            2: Query is complete
;        C = Current query substatus (when error is ERR_OK and B=1):
;            0: Unknown
;            1: Querying the primary DNS server
;            2: Querying the secondary DNS server
;            3: Querying another DNS server
;        C = Resolution process type (when error is ERR_OK and B=2):
;            0: The name was obtained by querying a DNS server
;            1: The name was a direct representation of an IP address
;            2: The name was resolved locally
;       L.H.E.D = Resolved IP address (when error is ERR_OK and B=2)

TCPIP_DNS_S:
	call	SETSLOTP2
	call	SET_WIZ_BUF2
	ld	c,b

	ld	a,(DNS_STAT_S)
	ld	b,a
	ld	a,(DNS_STAT_P)
	ld	hl,(DNS_RESULT)
	ld	de,(DNS_RESULT+2)
	bit	0,c
	jr	z,DNS_R_3

	push	af	;A=1 and no query in progress:
	ld	a,(DNS_STAT_P)	;clear result
	cp	1
	jr	z,DNS_R_2
	xor	a
	ld	(DNS_STAT_P),a
	ld	(DNS_STAT_S),a

DNS_R_2:	pop	af
DNS_R_3:

	cp	3
	jr	z,DNS_R_ERR
	ld	c,b
	ld	b,a

DNS_R_END:
	xor	a
	jp	RESTSLOTP2

DNS_R_ERR:
	ld	a,ERR_DNS
	jp	RESTSLOTP2


	;========================
	;===  TCPIP_UDP_OPEN  ===
	;========================

;Open a UDP connection.
;
;Input:  A  = 8
;        HL = Local port number (#FFFF=random)
;        B  = Intended connection lifetime:
;             0: Transient
;             1: Resident
;Output: A = Error code
;        B = Connection number

TCPIP_UDP_OPEN:

	;--- Check por number

	ld	a,h
	or	l
	ld	a,ERR_INV_PARAM
	ret	z
	ld	a,b
	and	%11111110
	ld	a,ERR_INV_PARAM
	ret	nz

	call	SETSLOTP2
	call	SET_WIZ_REGS2

	push	bc
	ld	a,h
	and	l
	cp	#FF
	call	z,GET_RANDOM_PORT
	pop	bc

	ld	a,h
	inc	a
	jr	nz,OK_UDPOP_PORT
	ld	a,l
	and	#F0
	cp	#F0
	ld	a,ERR_INV_PARAM
	jp	z,RESTSLOTP2
OK_UDPOP_PORT:

	;--- Check if the port is in use

	ld	a,1
CHK_UDP_EX:	push	af
	call	GET_CONN_BASE
	ld	a,(ix+WIZ_Sn_SR)
	cp	SOCK_UDP
	jr	nz,CHK_UDP_EXNEXT
	ld	d,(ix+WIZ_Sn_PORT)
	ld	e,(ix+WIZ_Sn_PORT+1)
	call	COMP16
	jr	nz,CHK_UDP_EXNEXT
	pop	af
	ld	a,ERR_CONN_EXISTS
	jp	RESTSLOTP2
CHK_UDP_EXNEXT:	pop	af
	inc	a
	cp	4
	jr	c,CHK_UDP_EX

	;--- Get free connection and open in UDP mode

	push	bc
	call		GET_FREE_CONN
	pop	bc
	or	a
	ld	c,a
	ld	a,ERR_NO_FREE_CONN
	jp	z,RESTSLOTP2

	push	hl
	call	SET_WIZ_BUF2	;Set resident or transient flag
	ld	hl,CONN_FLAGS
	ld	e,c
	ld	d,0
	add	hl,de
	ld	(hl),b
	call	SET_WIZ_REGS2
	pop	hl

	ld	a,c
	call	GET_CONN_BASE

UDP_OPEN_LOOP:
	ld	(ix+WIZ_Sn_MR),SOCK_PROTO_UDP
	ld	(ix+WIZ_Sn_PORT),h
	ld	(ix+WIZ_Sn_PORT+1),l
	ld	(ix+WIZ_Sn_CR),CMD_OPEN

	ld	a,(ix+WIZ_Sn_SR)
	cp	SOCK_UDP
	jr	z,UDP_OPEN_OK
	ld	a,CMD_CLOSE
	ld	(ix+WIZ_Sn_CR),a
	jr	UDP_OPEN_LOOP

UDP_OPEN_OK:
	call	SET_WIZ_BUF2
	ld	hl,(DEFAULT_TOS)
	call	SET_WIZ_REGS2
	ld	(ix+WIZ_Sn_TOS),l
	ld	(ix+WIZ_Sn_TTL),h

	xor	a
	ld	b,c
	jp	RESTSLOTP2


	;=========================
	;===  TCPIP_UDP_CLOSE  ===
	;=========================

;Close a UDP connection.
;
;Input:  A = 9
;        B = Connection number
;            0 to close all open transient UDP connections
;Output: A = Error code

TCPIP_UDP_CLOSE:
	ld	a,b
	cp	3+1
	ld	a,ERR_NO_CONN
	ret	nc

	ld	a,b
	or	a
	jr	z,UDP_CLOSE_ALL

	;--- Close one connection

	call	SETSLOTP2
	call	SET_WIZ_REGS2

	ld	a,b
	call	GET_CONN_BASE
	ld	a,(ix+WIZ_Sn_SR)
	cp	SOCK_UDP	;Open UDP connection?
	ld	a,ERR_NO_CONN
	jp	nz,RESTSLOTP2

	ld	a,CMD_CLOSE
	ld	(ix+WIZ_Sn_CR),a
	xor	a
	jp	RESTSLOTP2

	;--- Close all transient connections

UDP_CLOSE_ALL:
	call	SETSLOTP2
	call	SET_WIZ_BUF2
	ld	hl,CONN_FLAGS+1
	ld	a,1
UDP_CLOSE_LOOP:
	ld	c,a
	ld	a,(hl)	;Transient connection?
	and	1
	jr	nz,UDP_CLOSE_NEXT2

	call	SET_WIZ_REGS2
	ld	a,c
	call	GET_CONN_BASE
	ld	a,(ix+WIZ_Sn_SR)
	cp	SOCK_UDP	;UDP open connection?
	jr	nz,UDP_CLOSE_NEXT

	ld	a,CMD_CLOSE
	ld	(ix+WIZ_Sn_CR),a

UDP_CLOSE_NEXT:
	call	SET_WIZ_BUF2
UDP_CLOSE_NEXT2:
	inc	hl
	ld	a,c
	inc	a
	cp	3+1
	jr	c,UDP_CLOSE_LOOP

	xor	a
	jp	RESTSLOTP2


	;=========================
	;===  TCPIP_UDP_STATE  ===
	;=========================

;Get the state of a UDP connection.
;
;Input:  A = 10
;        B = Connection number
;Output: A  = Error code
;        HL = Local port number
;        B  = Number of pending incoming datagrams
;        DE = Size of oldest pending incoming datagram (data part only)

	;*** Call here for internal use on socket 0.
	;    Assumes that socket 0 is open in UDP or IP raw mode,
	;    and that our slot is already set in page 2.

UDP_STATE_INTERNAL:
	call	SET_WIZ_BUF2
	xor	a
	call	SET_CUR_CONN
	ld	de,(CURCONN_RX_BASE)
	call	SET_WIZ_REGS2
	jr	UDPSTATE_OKPARAMS

	;*** Call here for the user function.

TCPIP_UDP_STATE:
	ld	a,b
	or	a
	ld	a,ERR_NO_CONN
	ret	z

	ld	a,b
	cp	3+1
	ld	a,ERR_NO_CONN
	ret	nc

	call	SETSLOTP2
	call	SET_WIZ_BUF2
	ld	a,b
	call	SET_CUR_CONN
	ld	de,(CURCONN_RX_BASE)
	call	SET_WIZ_REGS2

	ld	a,(ix+WIZ_Sn_SR)
	cp	SOCK_UDP	;Open UDP connection?
	ld	a,ERR_NO_CONN
	jp	nz,RESTSLOTP2

	;--- Check if there are pending datagrams

UDPSTATE_OKPARAMS:
	ld	b,0
	ld	a,(ix+WIZ_Sn_RX_RSR)
	ld	c,(ix+WIZ_Sn_RX_RSR+1)
	or	c
	jr	z,UDP_STATE_NODATA

	;--- Get pending datagram size

	ld	a,(ix+WIZ_Sn_RX_RD)
	ld	l,(ix+WIZ_Sn_RX_RD+1)
	and	gSn_RX_MASK
	ld	h,a		;HL = get_offset

	ld	a,(ix+WIZ_Sn_SR)
	cp	SOCK_IPRAW
	ld	bc,4
	jr	z,UDPSTATE_OKPROTO
	ld	c,6
UDPSTATE_OKPROTO:

	call	SET_WIZ_BUF2
	add	hl,de	;HL = get_start_address
	add	hl,bc
	call	ADJUST_RX_POINTER	;HL = Pointer to data size

	ld	b,(hl)
	inc	hl
	call	ADJUST_RX_POINTER
	ld	e,(hl)
	ld	d,b

	ld	b,1

UDP_STATE_NODATA:
	ld	h,(ix+WIZ_Sn_PORT)
	ld	l,(ix+WIZ_Sn_PORT+1)

	jp	END_UDP_FUNCTION


;--- This routine adjust a RX buffer pointer
;    to take in account circular buffer.
;    Input:  HL = Unadjusted pointer
;            D  = High byte of RX base address
;    Output: HL = Adjusted pointer
;    Modifies: AF

ADJUST_RX_POINTER:
	ld	a,h
	and	gSn_RX_MASK
	or	d
	ld	h,a
	ret


;--- This routine adjust a TX buffer pointer
;    to take in account circular buffer.
;    Input:  HL = Unadjusted pointer
;            D  = High byte of TX base address
;    Output: HL = Adjusted pointer
;    Modifies: AF

ADJUST_TX_POINTER:
	ld	a,h
	and	gSn_TX_MASK
	or	d
	ld	h,a
	ret


	;========================
	;===  TCPIP_UDP_SEND  ===
	;========================

;Send an UDP datagram.
;
;Input:  A = 11
;        B = Connection number
;        HL = Address of datagram data
;        DE = Address of parameters block
;Output: A = Error code
;
;Parameters block:
;
;    +0 (4): Destination IP address
;    +4 (2): Destination port
;    +6 (2): Data length

UDPSND_IP:	equ	TEMP
UDPSND_PORT:	equ	TEMP+4
UDPSND_LEN:	equ	TEMP+6
UDPSND_DATA:	equ	TEMP+8

	;*** Call here for internal UDP and IP raw datagram sending
	;    by using socket 0.
	;    Assumes that socket 0 is open in UDP or IP raw mode,
	;    and that our slot is already set in page 2.
	;    Input:
	;    LHED = Destination IP
	;    BC = UDP data length
	;    IX = Destination port
	;    UDP data in DGRAM_BUF

UDP_SEND_INTERNAL:
	call	SET_WIZ_BUF2
	ld	(UDPSND_IP),hl
	ld	(UDPSND_IP+2),de
	ld	(UDPSND_LEN),bc
	ld	(UDPSND_PORT),ix
	ld	hl,DGRAM_BUF
	ld	(UDPSND_DATA),hl
	xor	a
	call	SET_CUR_CONN
	jr	UDPSND_OKPARAMS

	;*** Call here for the user function.

TCPIP_UDP_SEND:
	ld	a,b
	or	a
	ld	a,ERR_NO_CONN
	ret	z

	ld	a,b
	cp	3+1
	ld	a,ERR_NO_CONN
	ret	nc

	call	SETSLOTP2
	ld	a,b
	push	hl,de
	call	SET_CUR_CONN
	call	SET_WIZ_REGS2
	ld	a,(ix+WIZ_Sn_SR)
	cp	SOCK_UDP	;Open UDP connection?
	ld	a,ERR_NO_CONN
	pop	de,hl
	jp	nz,RESTSLOTP2

	;--- Copy parameters block to temporary area

	call	SET_WIZ_BUF2
	ld	(UDPSND_DATA),hl

	ld	a,(CURCONN)
	push	af
	ld	bc,DATA_BASE
	ld	(CURCONN_TX_BASE),bc
	ld	bc,DATA_LIMIT
	ld	(CURCONN_TX_LIMIT),bc
	ex	de,hl
	ld	de,UDPSND_IP
	ld	bc,8
	call	MSX_TO_WIZ

	pop	af
	call	SET_CUR_CONN

	;--- Check parameters

	ld	hl,(UDPSND_LEN)
	ld	de,548+1
	call	COMP16
	jp	nc,END_INV_PAR_R

	;--- Wait for free buffer available and set W5100 registers

UDPSND_OKPARAMS:
	exx
	ld	hl,(UDPSND_PORT)
	ld	de,(UDPSND_IP+2)
	ld	bc,(UDPSND_IP)
	exx

	call	SET_WIZ_REGS2
UDPSND_FREE:
	ld	h,(ix+WIZ_Sn_TX_FSR)
	ld	l,(ix+WIZ_Sn_TX_FSR+1)
	ld	de,(UDPSND_LEN)
	call	COMP16
	jr	c,UDPSND_FREE

	exx
	ld	(ix+WIZ_Sn_DIPR),c
	ld	(ix+WIZ_Sn_DIPR+1),b
	ld	(ix+WIZ_Sn_DIPR+2),e
	ld	(ix+WIZ_Sn_DIPR+3),d
	ld	(ix+WIZ_Sn_DPORT),h
	ld	(ix+WIZ_Sn_DPORT+1),l
	exx

	;--- Copy the datagram data to transmit buffer

	ld	a,(ix+WIZ_Sn_TX_WR)
	and	gSn_TX_MASK
	ld	l,(ix+WIZ_Sn_TX_WR+1)
	ld	h,a	;HL = get_offset

	call	SET_WIZ_BUF2

	ld	de,(CURCONN_TX_BASE)
	add	hl,de	;HL = get_start_address

	ex	de,hl
	ld	hl,(UDPSND_DATA)
	ld	bc,(UDPSND_LEN)
	ld	a,(INSIDE_INT)
	or	a
	jr	z,UDPSND_DO1
	ldir
	jr	UDPSND_DO2
UDPSND_DO1:
	call	MSX_TO_WIZ
UDPSND_DO2:

	;--- Send the datagram

	ld	ix,(CURCONN_REG_BASE)
	ld	bc,(UDPSND_LEN)
	call	SET_WIZ_REGS2
	ld	h,(ix+WIZ_Sn_TX_WR)
	ld	l,(ix+WIZ_Sn_TX_WR+1)
	add	hl,bc
	ld	(ix+WIZ_Sn_TX_WR),h
	ld	(ix+WIZ_Sn_TX_WR+1),l

	ld	a,CMD_SEND
	ld	(ix+WIZ_Sn_CR),a

END_UDP_FUNCTION:
	call	SET_WIZ_BUF2
	ld	a,(INSIDE_INT)
	or	a
	ret	nz
	xor	a
	jp	RESTSLOTP2


	;=======================
	;===  TCPIP_UDP_RCV  ===
	;=======================

;Retrieve an incoming UDP datagram.
;
;Input:  A = 12
;        B = Connection number
;        HL = Address for datagram data
;        DE = Maximum data size to retrieve
;Output: A = Error code
;        L.H.E.D = Source IP address
;        IX = Source port
;        BC = Actual received data size

UDPRCV_ADD:	equ	TEMP
UDPRCV_MAXSIZE:	equ	TEMP+2
UDPRCV_IP:	equ	TEMP+4
UDPRCV_PORT:	equ	TEMP+8
UDPRCV_ACTSIZE:	equ	TEMP+10
UDPRCV_HDRSIZE:	equ	TEMP+12

	;*** Call here for internal use on socket 0
	;    Assumes that socket 0 is open in UDP or IP raw mode,
	;    and that our slot is already set in page 2.
	;    Datagram is always copied to DGRAM_BUF.
	;    Actual availability of incoming datagrams is NOT checked.

UDP_RCV_INTERNAL:
	call	SET_WIZ_REGS2
	ld	a,(ix+WIZ_Sn_SR)
	push	af
	call	SET_WIZ_BUF2
	xor	a
	call	SET_CUR_CONN
	ld	hl,DGRAM_BUF
	ld	de,536
	jr	UDPRCV_OKPARAMS

	;*** Call here for the user function.

TCPIP_UDP_RCV:
	ld	a,b
	or	a
	ld	a,ERR_NO_CONN
	ret	z

	ld	a,b
	cp	3+1
	ld	a,ERR_NO_CONN
	ret	nc

	call	SETSLOTP2
	call	SET_WIZ_BUF2
	ld	a,b
	exx
	call	SET_CUR_CONN
	call	SET_WIZ_REGS2
	ld	a,(ix+WIZ_Sn_SR)
	cp	SOCK_UDP	;Open UDP connection?
	ld	a,ERR_NO_CONN
	exx
	jp	nz,RESTSLOTP2

	;--- Check if there are pending datagrams

	ld	b,0
	ld	a,(ix+WIZ_Sn_RX_RSR)
	ld	c,(ix+WIZ_Sn_RX_RSR+1)
	or	c
	ld	a,ERR_NO_DATA
	jp	z,RESTSLOTP2

	ld	a,(ix+WIZ_Sn_SR)
	push	af

	call	SET_WIZ_BUF2
UDPRCV_OKPARAMS:
	ld	(UDPRCV_ADD),hl
	ld	(UDPRCV_MAXSIZE),de

	;--- Get IP address, port, and data size

	ld	de,(CURCONN_RX_BASE)

	call	SET_WIZ_REGS2
	ld	a,(ix+WIZ_Sn_RX_RD)
	ld	l,(ix+WIZ_Sn_RX_RD+1)
	and	gSn_RX_MASK
	ld	h,a		;HL = get_offset

	call	SET_WIZ_BUF2
	add	hl,de	;HL = get_start_address

	ld	c,(hl)
	inc	hl
	call	ADJUST_RX_POINTER
	ld	b,(hl)
	inc	hl
	call	ADJUST_RX_POINTER
	ld	(UDPRCV_IP),bc	;IP address, first half
	ld	c,(hl)
	inc	hl
	call	ADJUST_RX_POINTER
	ld	b,(hl)
	inc	hl
	call	ADJUST_RX_POINTER
	ld	(UDPRCV_IP+2),bc	;IP address, second half

	pop	af
	cp	SOCK_IPRAW
	ld	a,6
	jr	z,UDPRCV_NOPORT
	ld	a,8

	push	af
	ld	b,(hl)
	inc	hl
	call	ADJUST_RX_POINTER
	ld	c,(hl)
	inc	hl
	call	ADJUST_RX_POINTER
	ld	(UDPRCV_PORT),bc	;Destination port
	pop	af
UDPRCV_NOPORT:

	ld	(UDPRCV_HDRSIZE),a
	ld	b,(hl)
	inc	hl
	call	ADJUST_RX_POINTER
	ld	c,(hl)			;BC=Datagram size
	inc	hl
	call	ADJUST_RX_POINTER	;Now HL=Address of datagram data
	ld	(UDPRCV_ACTSIZE),bc

	push	hl
	ld	de,(UDPRCV_MAXSIZE)	;DE=Maximum size to get
	ld	h,b
	ld	l,c		;HL=Actual size
	call	COMP16
	jr	c,UDPRCV_OKSIZE
	ld	b,d
	ld	c,e
UDPRCV_OKSIZE:
	pop	hl

	ld	a,b
	or	c
	jp	z,END_UDP_RCV	;No data to transfer?

	ld	de,(UDPRCV_ADD)
	ld	a,(INSIDE_INT)
	or	a
	jr	z,UDPRCV_DO1
	ldir
	jr	UDPRCV_DO2
UDPRCV_DO1:
	call	WIZ_TO_MSX
UDPRCV_DO2:

	;--- Data has been transferred or skipped,
	;    now update pointers and return data

END_UDP_RCV:
	call	SET_WIZ_BUF2
	ld	bc,(UDPRCV_HDRSIZE)
	ld	b,0
	push	bc
	ld	bc,(UDPRCV_ACTSIZE)
	call	SET_WIZ_REGS2
	ld	h,(ix+WIZ_Sn_RX_RD)
	ld	l,(ix+WIZ_Sn_RX_RD+1)
	add	hl,bc
	pop	bc
	add	hl,bc
	ld	(ix+WIZ_Sn_RX_RD),h
	ld	(ix+WIZ_Sn_RX_RD+1),l
	ld	a,CMD_RECV
	ld	(ix+WIZ_Sn_CR),a

	call	SET_WIZ_BUF2
	ld	hl,(UDPRCV_IP)
	ld	de,(UDPRCV_IP+2)
	ld	ix,(UDPRCV_PORT)
	ld	bc,(UDPRCV_ACTSIZE)

	jp	END_UDP_FUNCTION


	;========================
	;===  TCPIP_TCP_OPEN  ===
	;========================

;Open a TCP connection.
;
;Input:  A  = 13
;        HL = Address of parameters block
;Output: A = Error code
;        B = Connection number
;
;Parameters block format:
;
;+0 (4): Remote IP address (0.0.0.0 for unespecified remote socket)
;+4 (2): Remote port (ignored if unespecified remote socket)
;+6 (2): Local port, 0FFFFh for a random value
;+8 (2): Suggestion for user timeout value
;+10 (1): Flags:
;         bit 0: Set for passive connection
;         bit 1: Set for resident connection

TCPOP_IP:	equ	TEMP
TCPOP_RPORT:	equ	TEMP+4
TCPOP_LPORT:	equ	TEMP+6
TCPOP_TOUT:	equ	TEMP+8	;Not used
TCPOP_FLAGS:	equ	TEMP+10


TCPIP_TCP_OPEN:
	call	SETSLOTP2
	call	SET_WIZ_BUF2

	;--- Copy parameters block to temporary area

	ld	bc,DATA_BASE
	ld	(CURCONN_TX_BASE),bc
	ld	bc,DATA_LIMIT
	ld	(CURCONN_TX_LIMIT),bc

	ld	de,TCPOP_IP
	ld	bc,11
	call	MSX_TO_WIZ

	;--- Check flags

	ld	a,(TCPOP_FLAGS)
	ld	b,a
	and	%11111100
	ld	a,ERR_INV_PARAM
	jp	nz,RESTSLOTP2

	;--- Check IP address depending on open mode

	ld	hl,(TCPOP_IP)
	ld	de,(TCPOP_IP+2)
	ld	a,b
	and	1
	jr	nz,CHKIP_PASSIVE

CHKIP_ACTIVE:
	ld	a,h
	or	l
	or	d
	or	e
	ld	a,ERR_INV_PARAM
	jp	z,RESTSLOTP2
	jr	TCPOP_OKIP

CHKIP_PASSIVE:
	ld	a,h
	or	l
	or	d
	or	e
	ld	a,ERR_NOT_IMP
	jp	nz,RESTSLOTP2
TCPOP_OKIP:

	;--- Check netowrk connection

	push	bc
	call	NET_STATE_CORE
	ld	a,b
	pop	bc
	or	a
	ld	a,ERR_NO_NETWORK
	jp	z,RESTSLOTP2

	;--- Generate random local port if necessary

	ld	hl,(TCPOP_LPORT)
	ld	a,h
	and	l
	cp	#FF
	jr	nz,TCPOP_NO_RANDPORT
	call	SET_WIZ_REGS2
	call	GET_RANDOM_PORT
	call	SET_WIZ_BUF2
	ld	(TCPOP_LPORT),hl
TCPOP_NO_RANDPORT:

	;--- Check if there is another connection
	;    with the same pair of ports

	ld	a,b	;Check only if active connection
	and	1
	jr	nz,TCPOP_OKPORTS

	ld	de,(TCPOP_RPORT)
	push	de

	call	SET_WIZ_REGS2
	ld	a,1
CHK_TCP_EX:
	ld	b,a
	call	GET_CONN_BASE
	ld	a,(ix+WIZ_Sn_SR)
	cp	SOCK_UDP		;A socket no in TCP mode 
	jr	z,CHK_TCP_EXNEXT	;can be either closed or in UDP mode
	cp	SOCK_CLOSED
	jr	z,CHK_TCP_EXNEXT
	ld	d,(ix+WIZ_Sn_PORT)
	ld	e,(ix+WIZ_Sn_PORT+1)
	call	COMP16
	jr	nz,CHK_TCP_EXNEXT
	ex	(sp),hl
	ld	d,(ix+WIZ_Sn_DPORT)
	ld	e,(ix+WIZ_Sn_DPORT+1)
	call	COMP16
	ex	(sp),hl
	jr	nz,CHK_TCP_EXNEXT
	pop	de
	ld	a,ERR_CONN_EXISTS
	jp	RESTSLOTP2
CHK_TCP_EXNEXT:
	ld	a,b
	inc	a
	cp	4
	jr	c,CHK_TCP_EX
	pop	de
TCPOP_OKPORTS:
	call	SET_WIZ_REGS2

	;--- Get free connection

	call	GET_FREE_CONN
	or	a
	ld	c,a
	ld	a,ERR_NO_FREE_CONN
	jp	z,RESTSLOTP2

	;--- Set resident or transient flag

	call	SET_WIZ_BUF2
	ld	hl,CONN_FLAGS
	ld	e,c
	ld	d,0
	add	hl,de
	ld	a,(TCPOP_FLAGS)
	rrca
	and	1
	ld	(hl),a

	;--- Set source port and issue a INIT command

	ld	a,c
	ld	(CURCONN),a
	call	GET_CONN_BASE

	ld	bc,(TCPOP_LPORT)
	call	SET_WIZ_REGS2
TCPOP_TRY1:
	ld	(ix+WIZ_Sn_MR),SOCK_PROTO_TCP
	ld	(ix+WIZ_Sn_PORT),b
	ld	(ix+WIZ_Sn_PORT+1),c
	ld	(ix+WIZ_Sn_CR),CMD_OPEN
	ld	a,(ix+WIZ_Sn_SR)
	cp	SOCK_INIT
	jr	z,TCPOP_OK1
TCPOP_FAILED:
	ld	a,CMD_CLOSE
	ld	(ix+WIZ_Sn_CR),a
	jr	TCPOP_TRY1
TCPOP_OK1:

	;--- Open connection in TCP active or passive mode

	call	SET_WIZ_BUF2
	ld	a,(TCPOP_FLAGS)
	and	1
	jr	nz,TCPOP_PASSIVE

TCPOP_ACTIVE:
	ld	hl,(TCPOP_IP)
	ld	de,(TCPOP_IP+2)
	ld	bc,(TCPOP_RPORT)
	call	SET_WIZ_REGS2
	ld	(ix+WIZ_Sn_DIPR),l
	ld	(ix+WIZ_Sn_DIPR+1),h
	ld	(ix+WIZ_Sn_DIPR+2),e
	ld	(ix+WIZ_Sn_DIPR+3),d
	ld	(ix+WIZ_Sn_DPORT),b
	ld	(ix+WIZ_Sn_DPORT+1),c
	ld	a,CMD_CONNECT
	ld	(ix+WIZ_Sn_CR),a
	jr	TCPOP_END

TCPOP_PASSIVE:
	call	SET_WIZ_REGS2
	ld	a,CMD_LISTEN
	ld	(ix+WIZ_Sn_CR),a
	ld	a,(ix+WIZ_Sn_SR)
	cp	SOCK_LISTEN
	jr	nz,TCPOP_FAILED

TCPOP_END:
	call	SET_WIZ_BUF2
	ld	a,(CURCONN)
	ld	b,a
	xor	a
	jp	RESTSLOTP2


	;=========================
	;===  TCPIP_TCP_CLOSE  ===
	;=========================

;Close a TCP connection.
;
;Input:  A  = 14
;        B = Connection number
;            0 to close all open transient TCP connections
;Output: A = Error code

TCPIP_TCP_CLOSE:
	ld	c,CMD_DISCON
	jr	TCP_CLOSE_ABORT


	;=========================
	;===  TCPIP_TCP_ABORT  ===
	;=========================

;Abort a TCP connection.
;Input:  A  = 15
;        B = Connection number
;            0 to abort all open transient TCP connections
;Output: A = Error code

TCPIP_TCP_ABORT:
	ld	c,CMD_CLOSE


	;--- Close or abort one or all TCP connection(s)
	;    Input: B = Connection number
	;           C = Command for the CR register

TCP_CLOSE_ABORT:
	ld	a,b
	or	a
	jr	z,TCP_CLOSE_ALL

	;--- Close one connection

	push	bc
	call	SETUP_TCP
	pop	bc
	or	a
	ret	nz

	ld	a,c
	ld	(ix+WIZ_Sn_CR),a
	xor	a
	jp	RESTSLOTP2

	;--- Close all transient connections

TCP_CLOSE_ALL:
	call	SETSLOTP2
	call	SET_WIZ_BUF2
	ld	hl,CONN_FLAGS+1
	ld	a,1
TCP_CLOSE_LOOP:
	ld	b,a
	ld	a,(hl)	;Transient connection?
	and	1
	jr	nz,TCP_CLOSE_NEXT2

	call	SET_WIZ_REGS2
	ld	a,b
	call	GET_CONN_BASE
	ld	a,(ix+WIZ_Sn_SR)
	cp	SOCK_UDP
	jr	z,TCP_CLOSE_NEXT
	cp	SOCK_CLOSED
	jr	z,TCP_CLOSE_NEXT

	ld	a,c
	ld	(ix+WIZ_Sn_CR),a

TCP_CLOSE_NEXT:
	call	SET_WIZ_BUF2
TCP_CLOSE_NEXT2:
	inc	hl
	ld	a,b
	inc	a
	cp	3+1
	jr	c,TCP_CLOSE_LOOP

	xor	a
	jp	RESTSLOTP2


	;=========================
	;===  TCPIP_TCP_STATE  ===
	;=========================

;Get the state of a TCP connection.
;
;Input:  A = 16
;        B = Connection number
;        HL = Pointer in TPA for connection information block
;             (0 if not needed)
;Output: A  = Error code
;        B  = Connection state
;        C  = Close reason (only if ERR_NO_CONN is returned)
;        HL = Number of total available incoming bytes
;        DE = Number of urgent available incoming bytes
;        IX = Available free space in the output buffer
;             (0FFFFh = infinite)
;
;Connection information block consists of:
;
;    +0 (4): Remote IP address
;    +4 (2): Remote port
;    +6 (2): Local port

TCPST_IP:	equ	TEMP
TCPST_RPORT:	equ	TEMP+4
TCPST_LPORT:	equ	TEMP+6
TCPST_STATE:	equ	TEMP+8

TCPIP_TCP_STATE:
	call	SETUP_TCP
	or	a
	ret	nz

	;--- Get connection state

	ex	de,hl	;Save connection info block address for later
	ld	b,(ix+WIZ_Sn_SR)
	ld	hl,TCP_STATE_TABLE
TCPST_STATE_LOOP:
	ld	a,(hl)
	inc	hl
	or	a
	jp	z,TCPST_ERROR	;If an unexpected state is found, abort the connection
	cp	b
	jr	z,TCPST_STATE_OK
	inc	hl
	jr	TCPST_STATE_LOOP

TCPST_STATE_OK:
	ld	a,(hl)
	push	af

	;--- Return connection information block if necessary

	ld	a,d
	or	e
	jr	z,TCPST_OK_INFOBLOCK

	exx
	ld	l,(ix+WIZ_Sn_DIPR)
	ld	h,(ix+WIZ_Sn_DIPR+1)
	ld	e,(ix+WIZ_Sn_DIPR+2)
	ld	d,(ix+WIZ_Sn_DIPR+3)
	ld	b,(ix+WIZ_Sn_DPORT)
	ld	c,(ix+WIZ_Sn_DPORT+1)
	exx
	ld	b,(ix+WIZ_Sn_PORT)
	ld	c,(ix+WIZ_Sn_PORT+1)

	call	SET_WIZ_BUF2
	ld	(TCPST_LPORT),bc
	exx
	ld	(TCPST_RPORT),bc
	ld	(TCPST_IP),hl
	ld	(TCPST_IP+2),de
	exx

	ld	a,(CURCONN)
	push	af
	ld	bc,DATA_BASE
	ld	(CURCONN_TX_BASE),bc
	ld	bc,DATA_LIMIT
	ld	(CURCONN_TX_LIMIT),bc

	ld	hl,TCPST_IP
	ld	bc,8
	call	WIZ_TO_MSX

	pop	af
	call	SET_CUR_CONN
	call	SET_WIZ_REGS2
TCPST_OK_INFOBLOCK:

	;--- Get buffer space information

	ld	h,(ix+WIZ_Sn_RX_RSR)
	ld	l,(ix+WIZ_Sn_RX_RSR+1)
	ld	d,(ix+WIZ_Sn_TX_FSR)
	ld	e,(ix+WIZ_Sn_TX_FSR+1)
	push	de
	pop	ix
	ld	de,0

	pop	bc	;Connection state was PUSHed before
	xor	a
	push	ix
	call	RESTSLOTP2
	pop	ix
	ret

TCPST_ERROR:
	ld	a,CMD_CLOSE
	ld	(ix+WIZ_Sn_CR),a
	ld	c,0
	jp	END_NOCONN


;This table translates the value of register SR
;to the connection state values returned by this routine

TCP_STATE_TABLE:
	db	SOCK_ARP,2
	db	SOCK_INIT,2
	db	SOCK_LISTEN,1
	db	SOCK_SYNSENT,2
	db	SOCK_SYNRECV,3
	db	SOCK_ESTABLISHED,4
	db	SOCK_FIN_WAIT1,5
	db	SOCK_FIN_WAIT2,6
	db	SOCK_CLOSING,8
	db	SOCK_TIME_WAIT,10
	db	SOCK_CLOSE_WAIT,7
	db	SOCK_LAST_ACK,9
	db	0


	;========================
	;===  TCPIP_TCP_SEND  ===
	;========================

;Send data to a TCP connection.
;
;Input:  A  = 17
;        B  = Connection number
;        DE = Address of the data to be sent
;        HL = Length of the data to be sent
;        C  = Flags:
;             bit 0: Send the data PUSHed
;             bit 1: The data is urgent
;Output: A = Error code

TCPS_ADD:	equ	TEMP
TCPS_LEN:	equ	TEMP+2

TCPIP_TCP_SEND:
	push	de
	call	SETUP_TCP
	pop	de
	or	a
	ret	nz

	;--- Check if the connection is in a valid state

	ld	a,(ix+WIZ_Sn_SR)
	cp	SOCK_ESTABLISHED
	jr	z,TCPSND_OK1
	cp	SOCK_CLOSE_WAIT
	ld	a,ERR_CONN_STATE
	jp	nz,RESTSLOTP2
TCPSND_OK1:

	;--- Do nothing if data length is zero

	ld	a,h
	or	l
	ld		a,0
	jp	z,RESTSLOTP2

	;--- Check if Tx buffer has enough free space

	push	de
	ex	de,hl
	ld	h,(ix+WIZ_Sn_TX_FSR)
	ld	l,(ix+WIZ_Sn_TX_FSR+1)
	call	COMP16
	ex	de,hl
	pop	de
	ld	a,ERR_BUFFER
	jp	c,RESTSLOTP2

	;--- Copy the data to send to the transmit buffer

	push	hl	;Data length

	ld	a,(ix+WIZ_Sn_TX_WR)
	and	gSn_TX_MASK
	ld	l,(ix+WIZ_Sn_TX_WR+1)
	ld	h,a	;HL = get_offset

	call	SET_WIZ_BUF2

	ld	bc,(CURCONN_TX_BASE)
	add	hl,bc	;HL = get_start_address

	ex	de,hl	;Source address to HL, dest address to DE
	pop	bc
	push	bc
	call	MSX_TO_WIZ
	ld	ix,(CURCONN_REG_BASE)
	pop	bc

	;--- Issue the SEND command

	call	SET_WIZ_REGS2
	ld	h,(ix+WIZ_Sn_TX_WR)
	ld	l,(ix+WIZ_Sn_TX_WR+1)
	add	hl,bc
	ld	(ix+WIZ_Sn_TX_WR),h
	ld	(ix+WIZ_Sn_TX_WR+1),l

	ld	a,CMD_SEND
	ld	(ix+WIZ_Sn_CR),a

	xor	a
	jp	RESTSLOTP2


	;=======================
	;===  TCPIP_TCP_RCV  ===
	;=======================

;Receive data from a TCP connection.
;
;Input:   A  = 18
;         B  = Connection number
;         DE = Address for the retrieved data
;         HL = Length of the data to be obtained
;Output:  A  = Error code
;         BC = Total number of bytes that have been actually retrieved
;         HL = Number of urgent data bytes that have been retrieved
;              (placed at the beginning of the received data block)

TCPIP_TCP_RCV:
	push	de
	call	SETUP_TCP
	pop	de
	or	a
	ret	nz

	;--- Calculates the actual amount of data to retrieve

	call	SET_WIZ_REGS2
	push	de
	ld	d,(ix+WIZ_Sn_RX_RSR)
	ld	e,(ix+WIZ_Sn_RX_RSR+1)
	call	COMP16
	jr	c,TCPR_OKSIZE
	ld	h,d	;Change length of data to obtain
	ld	l,e	;to length of data availalbe
TCPR_OKSIZE:

	pop	de

	ld	a,h
	or	l
	jr	nz,TCPR_DATAAV
	ld	hl,0
	ld	bc,0
	xor	a
	jp	RESTSLOTP2 	;Do nothing if no data available
TCPR_DATAAV:

	push	hl

	;--- Transfer the data to MSX memory

	call	SET_WIZ_REGS2
	ld	a,(ix+WIZ_Sn_RX_RD)
	ld	l,(ix+WIZ_Sn_RX_RD+1)
	and	gSn_RX_MASK
	ld	h,a		;HL = get_offset

	call	SET_WIZ_BUF2
	ld	bc,(CURCONN_RX_BASE)
	add	hl,bc	;HL = get_start_address

	pop	bc
	push	bc
	call	WIZ_TO_MSX
	ld	ix,(CURCONN_REG_BASE)
	pop	bc

	;--- Issue the RECEIVE command

	call	SET_WIZ_REGS2
	ld	h,(ix+WIZ_Sn_RX_RD)
	ld	l,(ix+WIZ_Sn_RX_RD+1)
	add	hl,bc
	ld	(ix+WIZ_Sn_RX_RD),h
	ld	(ix+WIZ_Sn_RX_RD+1),l

	ld	a,CMD_RECV
	ld	(ix+WIZ_Sn_CR),a

	ld	hl,0
	xor	a
	jp	RESTSLOTP2


	;=========================
	;===  TCPIP_TCP_FLUSH  ===
	;=========================

;Flush the output buffer of a TCP connection.
;
;Input:   A = 19
;         B = Connection number
;Output:  A = Error code

TCPIP_TCP_FLUSH:
	ld	a,ERR_NOT_IMP
	ret


	;=============================
	;===  TCPIP_CONFIG_AUTOIP  ===
	;=============================

;Enable or disable the automatic IP addresses retrieval.
;
;Input:  A = 25
;        B = 0: Get current configuration
;            1: Set configuration
;        C = Configuration to set (only if B=1):
;            bit 0: Set to automatically retrieve
;                   local IP address, subnet mask and default gateway
;            bit 1: Set to automatically retrieve DNS servers addresses
;            bits 2-7: Unused, must be zero
;Output: A = Error code
;        C = Configuration after the routine execution
;            (same format as C at input)

TCPIP_CONFIG_AUTOIP:
	ld	a,b
	and	%11111110
	ld	a,ERR_INV_PARAM
	ret	nz
	ld	a,b
	or	a
	jr	z,AUTOIP_NOCHECK_C
	ld	a,c
	and	%11111100
	ld	a,ERR_INV_PARAM
	ret	nz
AUTOIP_NOCHECK_C:

	call	SETSLOTP2
	call	SET_WIZ_BUF2

	bit	0,b	;Get configuration?
	jr	nz,AUTOIP_SET
	ld	a,(AUTOIP_CONFIG)
	ld	c,a
	xor	a
	jp	RESTSLOTP2

AUTOIP_SET:
	ld	a,c
	ld	(AUTOIP_CONFIG),a
	xor	a
	ld	(DHCP_STATE),a
	jp	RESTSLOTP2


	;=========================
	;===  TCPIP_CONFIG_IP  ===
	;=========================

;Manually configure an IP address.
;
;Input:  A = 26
;        B = Index of address to set:
;            1: Local IP address
;            2: Peer IP address
;            3: Subnet mask
;            4: Default gateway
;            5: Primary DNS server IP address
;            6: Secondary DNS server IP address
;        L.H.E.D = Address value
;Output: A = Error code

TCPIP_CONFIG_IP:
	call	SETSLOTP2

	ld	a,b
	or	a
	jp	z,END_INV_PAR_R

	;--- Local IP address

	dec	a
	jr	nz,CFGIP_NO1
	call	SET_WIZ_REGS2
	ld	(WIZ_SIPR),hl
	ld	(WIZ_SIPR+2),de
	xor	a
	jp	RESTSLOTP2
CFGIP_NO1:

	;--- Peer IP address

	dec	a
	jp	z,END_INV_PAR_R

	;--- Subnet mask

	dec	a
	jr	nz,CFGIP_NO3
	call	SET_WIZ_REGS2
	ld	(WIZ_SUBR),hl
	ld	(WIZ_SUBR+2),de
	xor	a
	jp	RESTSLOTP2
CFGIP_NO3:

	;--- Default gateway

	dec	a
	jr	nz,CFGIP_NO4
	call	SET_WIZ_REGS2
	ld	(WIZ_GAR),hl
	ld	(WIZ_GAR+2),de
	xor	a
	jp	RESTSLOTP2
CFGIP_NO4:

	;--- Primary DNS

	dec	a
	jr	nz,CFGIP_NO5
	call	SET_WIZ_BUF2
	ld	(BUF_IPDNS1),hl
	ld	(BUF_IPDNS1+2),de
	xor	a
	jp	RESTSLOTP2
CFGIP_NO5:

	;--- Secondary DNS

	dec	a
	jp	nz,END_INV_PAR_R
	call	SET_WIZ_BUF2
	ld	(BUF_IPDNS2),hl
	ld	(BUF_IPDNS2+2),de
	xor	a
	jp	RESTSLOTP2


	;==========================
	;===  TCPIP_CONFIG_TTL  ===
	;==========================

;Get/set the value of TTL and TOS for outgoing datagrams.
;
;Input:  A = 27
;        B = 0: Get current values
;            1: Set values
;        D = New value for TTL (only if B=1)
;        E = New value for ToS (only if B=1)
;Output: A = Error code
;        D = Value of TTL after the routine execution
;        E = Value of ToS after the routine execution

TCPIP_CONFIG_TTL:
	ld	a,b
	and	%11111110
	or	a
	ld	a,ERR_INV_PARAM
	ret	nz

	call	SETSLOTP2
	ld	a,b
	or	a
	jr	z,TTLTOS_GET

	call	SET_WIZ_BUF2
	ld	(DEFAULT_TOS),de

	call	SET_WIZ_REGS2
	xor	a
TTLTOS_SET_L:
	push	af,de
	call	SET_CUR_CONN
	pop	de
	ld	(ix+WIZ_Sn_TOS),e
	ld	(ix+WIZ_Sn_TTL),d
	pop	af
	inc	a
	cp	4
	jr	c,TTLTOS_SET_L
	xor	a
	jp	RESTSLOTP2

TTLTOS_GET:
	call	SET_WIZ_BUF2
	ld	de,(DEFAULT_TOS)
	xor	a
	jp	RESTSLOTP2


	;===========================
	;===  TCPIP_CONFIG_PING  ===
	;===========================

;Get/set the automatic PING reply flag.
;
;Input:  A = 28
;        B = 0: Get current flag value
;            1: Set flag value
;        C = New flag value (only if B=1):
;            0: Off
;            1: On
;Output: A = Error code
;        C = Flag value after the routine execution

TCPIP_CONFIG_PING:
	ld	a,b
	and	%11111110
	or	a
	ld	a,ERR_INV_PARAM
	ret	nz
	ld	a,b
	or	a
	jr	z,CFGPING_NOC
	ld	a,c
	and	%11111110
	ld	a,ERR_INV_PARAM
	ret	nz
CFGPING_NOC:

	call	SETSLOTP2
	call	SET_WIZ_REGS2
	ld	hl,WIZ_MR
	ld	a,b
	or	a
	jr	z,CFGPING_GET

CFGPING_SET:
	bit	0,c
	jr	z,CFGPING_SET0
CFGPING_SET1:
	res	4,(hl)		;0 = Ping block disabled (ping enabled)
	jp	RESTSLOTP2
CFGPING_SET0:
	set	4,(hl)		;1 = Ping block enabled (ping disabled)
	jp	RESTSLOTP2

CFGPING_GET:
	ld	a,(hl)
	and	%00010000
	ld	a,0
	ld	c,0
	jp	nz,RESTSLOTP2
	inc	c
	jp	RESTSLOTP2



	;====================
	;===  TCPIP_WAIT  ===
	;====================

;Wait for a processing step to run.
;
;Input:  A = 29
;Output: A = Error code

TCPIP_WAIT:
	ei
	ld	de,(PREV_TIMER)
TCPIP_WAIT2:
	ld	hl,(SYSTIMER)
	ld	(PREV_TIMER),hl
	ld	a,h
	cp	d
	ret	nz
	ld	a,l
	cp	e
	ld	a,0
	ret	nz
	jr	TCPIP_WAIT2


;********************************
;***  DATA TRANSFER ROUTINES  ***
;********************************

;--- WIZ_TO_MSX
;
;This routine does a data transfer of data from
;W5100 receive buffer of the current connection to MSX memory,
;taking in account that receive buffer is circular.
;Assumes that receive buffer is 2K long and 
;is currenly visible at page 2.
;
;Input:  HL = Source address in W5100 RAM (page 2)
;        DE = Destination address in MSX RAM (page 0, 2 or 3)
;        BC = Transfer length
;Output: -
;Modifies: All (main, index, and alternate)

WIZ_TO_MSX:
	ld	a,d
	and	11000000b
	cp	80h
	jr	z,WIZ_TO_MSX_INDIR


;Direct data transfer from W5100 buffer to MSX memory,
;it is invoked by WIZ_TO_MSX when the destination
;address is in page 0 or 3.
;
;Input:  HL = Source address in W5100 RAM (page 2)
;        DE = Destination address in MSX RAM (page 0 or 3)
;        BC = Transfer length
;Output: HL = (HL + BC) and gSn_RX_MASK or (CURCONN_RX_BASE)
;        DE = DE + BC
;Modifies: AF

WIZ_TO_MSX_DIR:

	;If the circular buffer border is not crossed, one single transfer will do...

	ld	a,(CURCONN_RX_LIMIT+1)

	push	hl
	add	hl,bc
	dec	hl
	cp	h
	pop	hl
	jr	c,W2M_2XFERS
	jr	z,W2M_2XFERS

W2M_1XFER:
	push	bc
	ldir
	pop	bc
	ld	a,(CURCONN_RX_LIMIT+1)
	cp	h
	ret	nz
	ld	hl,(CURCONN_RX_BASE)
	ret

	;...otherwise, we'll need to transfer in two chunks.

W2M_2XFERS:
	push	bc

	push	hl
	push	de
	ex	de,hl
	ld	hl,(CURCONN_RX_LIMIT)
	or	a
	sbc	hl,de
	ld	b,h
	ld	c,l	;BC=Size of higher chunk
	pop	de	;DE=Destination MSX address
	pop	hl	;HL=Source W5100 address
	push	bc
	ldir

	pop	bc	;BC=Size of higher chunk
	pop	hl	;HL=Original size
	push	hl
	or	a
	sbc	hl,bc
	ld	b,h
	ld	c,l	;BC=Remaining size
	ld	hl,(CURCONN_RX_BASE)
	ldir

	pop	bc
	ret


;Indirect data transfer from W5100 buffer to MSX memory,
;it is invoked by WIZ_TO_MSX when the destination
;address is in page 2.
;
;Input:  HL = Source address in W5100 RAM (page 2)
;        DE = Destination address in MSX RAM (page 0 or 3)
;        BC = Transfer length
;Output: -
;Modifies: All (main, index, and alternate)

WIZ_TO_MSX_INDIR:
	ld	a,(H_PHYD)
	cp	#C9	;mnemonic for RET
	jr	nz,GETFRAME_BUFP3

	;>>> Get frame, using inter-slot write <<<

GETFRAME_RDSLT:
	push	de
	ld	de,(CURCONN_RX_BASE)	;Account for circular buffer
	call	ADJUST_RX_POINTER
	pop	de

	push	hl,bc,de
	ld	e,(hl)
	pop	hl
	push	hl
	ld	a,(USER_SLOT_P2)
	call	WRSLT
	pop	de,bc,hl

	inc	hl
	inc	de
	dec	bc
	ld	a,b
	or	c
	jr	nz,GETFRAME_RDSLT

	ei
	ret

	;>>> Get frame, buffering in page 3 <<<

GETFRAME_BUFP3:
	push	hl,de,bc
	call	RESTSLOTP2_INT
	call	GETSLTP1
	ld	ixh,a	;IXh=Our slot
	call	GETSLTP2
	ld	ixl,a	;IXl=MSX RAM slot
	pop	bc,de,hl

GFI_LOOP1:
	ld	a,b
	or	c
	jr	z,GFI_END
	ld	a,b
	cp	2
	jr	c,GFI_LAST

	push	bc
	exx
	ld	a,ixh	;Switch W5100 RAM...
	ld	h,#80
	call	ENASLT
	exx
	ld	bc,512
	push	de
	ld	de,(SECBUF)	;...copy 512 bytes to page 3...
	call	WIZ_TO_MSX_DIR
	exx
	ld	a,ixl	;...switch MSX RAM...
	ld	h,#80
	call	ENASLT
	exx

	push	hl
	pop	iy
	pop	de
	ld	hl,(SECBUF)
	ld	bc,512
	ldir		;...and copy the 512 bytes from page 3.

	pop	hl
	ld	bc,-512
	add	hl,bc
	ld	b,h
	ld	c,l	;BC=Remaining frame size
	push	iy
	pop	hl
	jr	GFI_LOOP1

	;Jump here when less than 512 frame bytes are remaining

GFI_LAST:
	exx
	ld	a,ixh	;Switch W5100 RAM...
	ld	h,#80
	call	ENASLT
	exx
	push	bc
	push	de
	ld	de,(SECBUF)
	call	WIZ_TO_MSX_DIR	;...copy the remaining bytes bytes to page 3...

	pop	de
	pop	bc
	exx
	ld	a,ixl
	ld	h,#80
	call	ENASLT	;...switch MSX RAM...
	exx
	ld	hl,(SECBUF)
	ldir		;...and copy the remaining bytes from page 3.

GFI_END:
	;At this point, page 2 must have MSX RAM switched.

	call	SETSLOTP2_INT
	ret


;--- MSX_TO_WIZ
;
;This routine does a data transfer of data from MSX memory
;to W5100 transmit buffer of the current connection,
;taking in account that transmit buffer is circular.
;Assumes that transmit buffer is 2K long and 
;is currenly visible at page 2.
;
;Input:  HL = Source address in MSX RAM (page 0, 2 or 3)
;        DE = Destination address in W5100 RAM (page 2)
;        BC = Transfer length
;Output: -
;Modifies: All (main, index, and alternate)

MSX_TO_WIZ:
	ld	a,h
	and	11000000b
	cp	80h
	jr	z,MSX_TO_WIZ_INDIR


;Direct data transfer from MSX memory to W5100 buffer,
;it is invoked by MSX_TO_WIZ when the source
;address is in page 0 or 3.
;
;Input:  HL = Source address in MSX RAM (page 0 or 3)
;        DE = Destination address in W5100 RAM (page 2)
;        BC = Transfer length
;Output: HL = HL + BC
;        DE = (DE + BC) and gSn_TX_MASK or (CURCONN_TX_BASE)
;Modifies: AF

MSX_TO_WIZ_DIR:

	;If the circular buffer border is not crossed, one single transfer will do...

	ld	a,(CURCONN_TX_LIMIT+1)

	ex	de,hl
	push	hl
	add	hl,bc
	dec	hl
	cp	h
	pop	hl
	ex	de,hl
	jr	c,M2W_2XFERS
	jr	z,M2W_2XFERS

M2W_1XFER:
	push	bc
	ldir
	pop	bc
	ld	a,(CURCONN_TX_LIMIT+1)
	cp	d
	ret	nz
	ld	de,(CURCONN_TX_BASE)
	ret

	;...otherwise, we'll need to transfer in two chunks.

M2W_2XFERS:
	push	bc

	push	hl
	push	de
	ld	hl,(CURCONN_TX_LIMIT)
	or	a
	sbc	hl,de
	ld	b,h
	ld	c,l	;BC=Size of higher chunk
	pop	de	;DE=Destination W5100 address
	pop	hl	;HL=Source MSX address
	push	bc
	ldir

	pop	bc	;BC=Size of higher chunk
	ex	(sp),hl	;HL=Original size, source address to stack
	or	a
	sbc	hl,bc
	ld	b,h
	ld	c,l	;BC=Remaining size
	ld	de,(CURCONN_TX_BASE)
	ex	(sp),hl
	ldir

	pop	bc
	ret


;Indirect data transfer from MSX memory to W5100 buffer,
;it is invoked by MSX_TO_WIZ when the source
;address is in page 2.
;
;Input:  HL = Source address in MSX RAM (page 2)
;        DE = Destination address in W5100 RAM (page 2)
;        BC = Transfer length
;Output: -
;Modifies: All (main, index, and alternate)

MSX_TO_WIZ_INDIR:
	ld	a,(H_PHYD)
	cp	#C9	;mnemonic for RET
	jr	nz,SETFRAME_BUFP3

	;>>> Copy frame to W5100, using inter-slot read <<<

SETFRAME_RDSLT:
	push	hl
	ex	de,hl
	ld	de,(CURCONN_TX_BASE)	;Account for circular buffer
	call	ADJUST_TX_POINTER
	ex	de,hl
	pop	hl

	push	bc,de	;RDSLT preserves HL
	call	RDSLT
	pop	de,bc
	ld	(de),a

	inc	hl
	inc	de
	dec	bc
	ld	a,b
	or	c
	jr	nz,SETFRAME_RDSLT

	ei
	ret

	;>>> Copy frame to W5100, buffering in page 3 <<<

SETFRAME_BUFP3:
	push	hl,de,bc
	call	RESTSLOTP2_INT
	call	GETSLTP1
	ld	ixh,a	;IXh=Our slot
	call	GETSLTP2
	ld	ixl,a	;IXl=MSX RAM slot
	pop	bc,de,hl

SFI_LOOP1:
	ld	a,b
	or	c
	jr	z,SFI_END
	ld	a,b
	cp	2
	jr	c,SFI_LAST

	push	bc
	ld	bc,512
	push	de
	ld	de,(SECBUF)	;Copy 512 bytes to page 3...
	ldir

	exx
	ld	a,ixh	;...switch W5100 RAM...
	ld	h,#80
	call	ENASLT
	exx

	ld	a,iyh
	push	hl
	pop	iy
	ld	hl,(SECBUF)
	pop	de
	ld	bc,512
	ex	af,af'
	call	MSX_TO_WIZ_DIR	;...copy the 512 bytes from page 3...

	exx
	ld	a,ixl	;...and switch MSX RAM again.
	ld	h,#80
	call	ENASLT
	exx
	ex	af,af'

	pop	hl
	ld	bc,-512
	add	hl,bc
	ld	b,h
	ld	c,l	;BC=Remaining frame size

	push	iy
	pop	hl
	ld	iyh,a
	jr	SFI_LOOP1

	;Jump here when less than 512 frame bytes are remaining

SFI_LAST:
	push	bc
	push	de
	ld	de,(SECBUF)
	ldir		;Copy the remaining bytes to page 3...

	pop	de
	pop	bc
	exx
	ld	a,ixh
	ld	h,#80
	call	ENASLT	;...switch W5100 RAM...
	exx
	ld	hl,(SECBUF)
	call	MSX_TO_WIZ_DIR	;...copy the remaining bytes from page 3...

	exx
	ld	a,ixl	;...and switch MSX RAM again.
	ld	h,#80
	call	ENASLT
	exx

SFI_END:
	;At this point, page 2 must have MSX RAM switched.

	jp	SETSLOTP2_INT



;***********************************
;***  W5100 MANAGEMENT ROUTINES  ***
;***********************************

;--- Initialize hardware

DO_RESET:
	call	SETSLOTP2_INT
	call	SET_WIZ_REGS2

	;Save current MAC

	ld	ix,WIZ_SHAR
	ld	l,(ix)
	ld	h,(ix+1)
	ld	e,(ix+2)
	ld	d,(ix+3)
	ld	c,(ix+4)
	ld	b,(ix+5)
	push	hl,de,bc

	;Set mode register to 10000000b
	;(do reset, ping enabled, PPPoE disabled,
	; auto-increment disabled, indirect bus I/F mode disabled)

	ld	a,10000000b
	ld	(WIZ_MR),a
WAIT_RESET:
	ld	a,(WIZ_MR)
	and	10000000b
	jr	nz,WAIT_RESET

	;Restore MAC

	pop	bc,de,hl
	call	SET_MAC

	;Configure memory so that every socket has
	;2K for receive buffer and 1K for transmit buffer

	ld	a,%01010101
	ld	(WIZ_RMSR),a
	xor	a
	ld	(WIZ_TMSR),a

	;Clear socket interrupts

	ld	a,#FF
	ld	(WIZ_SOCKREG_BASE + (WIZ_SOCKREG_SIZE*0) + WIZ_Sn_IR),a
	ld	(WIZ_SOCKREG_BASE + (WIZ_SOCKREG_SIZE*1) + WIZ_Sn_IR),a
	ld	(WIZ_SOCKREG_BASE + (WIZ_SOCKREG_SIZE*2) + WIZ_Sn_IR),a
	ld	(WIZ_SOCKREG_BASE + (WIZ_SOCKREG_SIZE*3) + WIZ_Sn_IR),a

	jp	RESTSLOTP2_INT


;--- Set the MAC address
;    Assumes W5100 registers visible on page 2
;    Input:  L-H-E-D-C-B = MAC address to set
;    Output: -
;    Modifies: IX

SET_MAC:
	ld	ix,WIZ_SHAR
	ld	(ix),l
	ld	(ix+1),h
	ld	(ix+2),e
	ld	(ix+3),d
	ld	(ix+4),c
	ld	(ix+5),b
	ret


;--- Set W5100 registers on page 2
;    (does NOT change the slot on page 2)
;    Input:  -
;    Output: -
;    Modifies: AF

SET_WIZ_REGS2:
	in	a,(WIZ_PORT)
	and	11101111b
	out	(WIZ_PORT),a
	ret


;--- Set W5100 buffer on page 2
;    (does NOT change the slot on page 2)
;    Input:  -
;    Output: -
;    Modifies: AF

SET_WIZ_BUF2:
	in	a,(WIZ_PORT)
	or	00010000b
	out	(WIZ_PORT),a
	ret


;--- Open socket 0 in UDP mode or in IP raw mode
;    Assumes W5100 registers visible on page 2

OPEN_S0_FOR_IPRAW:
	ld	b,SOCK_PROTO_IPRAW
	ld	c,SOCK_IPRAW
	jr	OPEN_S0

OPEN_S0_FOR_UDP:
	ld	b,SOCK_PROTO_UDP
	ld	c,SOCK_UDP

OPEN_S0:
	call	SET_WIZ_REGS2
	ld	a,(WIZ_SOCKREG_BASE+WIZ_Sn_SR)
	cp	c
	jp	z,SET_WIZ_BUF2

OPEN_S0_DO:
	ld	a,CMD_CLOSE
	ld	(WIZ_SOCKREG_BASE+WIZ_Sn_CR),a

	ld	a,1	;IP protocol = ICMP (ignored in UDP mode)
	ld	(WIZ_SOCKREG_BASE+WIZ_Sn_PROTO),a
	ld	hl,DNS_DHCP_LOCAL_PORT
	ld	a,b
	ld	(WIZ_SOCKREG_BASE+WIZ_Sn_MR),a
	ld	a,h
	ld	(WIZ_SOCKREG_BASE+WIZ_Sn_PORT),a	;UDP port (ignored in IP raw mode)
	ld	a,l
	ld	(WIZ_SOCKREG_BASE+WIZ_Sn_PORT+1),a
	ld	a,CMD_OPEN
	ld	(WIZ_SOCKREG_BASE+WIZ_Sn_CR),a

	ld	a,(WIZ_SOCKREG_BASE+WIZ_Sn_SR)
	cp	c
	jr	z,OPEN_S0_OK
	ld	a,CMD_CLOSE
	ld	(WIZ_SOCKREG_BASE+WIZ_Sn_CR),a
	jr	OPEN_S0_DO

OPEN_S0_OK:
	call	SET_WIZ_BUF2
	ld	hl,(DEFAULT_TOS)
	call	SET_WIZ_REGS2
	ld	a,l
	ld	(WIZ_SOCKREG_BASE+WIZ_Sn_TOS),a
	ld	a,h
	ld	(WIZ_SOCKREG_BASE+WIZ_Sn_TTL),a
	jp	SET_WIZ_BUF2


;--- Open socket 0 in RAW IP mode
;    Assumes W5100 registers visible on page 2
;    Input:  -
;    Output: A = 1
;    Modifies: F

	if	0

OPEN_S0:
	ld	a,SOCK_PROTO_IPRAW
	ld	(WIZ_SOCKREG_BASE+WIZ_Sn_MR),a

	ld	a,CMD_OPEN
	ld	(WIZ_SOCKREG_BASE+WIZ_Sn_CR),a

	ld	a,(WIZ_SOCKREG_BASE+WIZ_Sn_SR)
	cp	SOCK_IPRAW
	ld	a,1
	ret	z

	ld	a,CMD_CLOSE
	ld	(WIZ_SOCKREG_BASE+WIZ_Sn_CR),a
	jr	OPEN_S0

	endif


;--- Close socket 0
;    Assumes W5100 slot visible on page 2
;    Input:  -
;    Output: A = 2
;    Modifies: F

CLOSE_S0:
	call	SET_WIZ_REGS2
	ld	a,CMD_CLOSE
	ld	(WIZ_SOCKREG_BASE+WIZ_Sn_CR),a
	call	SET_WIZ_BUF2
	ld	a,2
	ret


;--- Wait until W5100 is not busy
;    Assumes W5100 registers visible on page 2
;    Input:  -
;    Output: -
;    Modifies:  AF

	if	0

WAIT_WIZ_BUSY:
	ld	a,(WIZ_Sn_CR)
	or	a
	ret	z

	cp	CMD_SEND
	jr	nz,WAIT_WIZ_BUSY

	push	hl
	push	de
	push	bc
	ld	b,255
WIZ_BUSY_LOOP:

	ld	a,(WIZ_Sn_CR)
	or	a
	jr	z,WAIT_WIZ_END

	;Due to errata on W5100 chip,
	;sometimes the sending process
	;does not complete on UDP and Raw modes.
	;In this case, S0_TX_RD and S0_TX_WR
	;will never get equal,
	;and after some time a reset must be issued.

	ld	a,(WIZ_Sn_TX_RD)
	ld	h,a
	ld	a,(WIZ_Sn_TX_RD+1)
	ld	l,a
	ld	a,(WIZ_Sn_TX_WR)
	ld	d,a
	ld	a,(WIZ_Sn_TX_WR+1)
	ld	e,a
	call	COMP16
	jr	nz,WIZ_BUSY_LOOP

	djnz	WAIT_WIZ_END
	ld	hl,(WIZ_SOCKREG_BASE+WIZ_Sn_TOS)
	call	CLOSE_S0
	call	OPEN_S0
	ld	(WIZ_SOCKREG_BASE+WIZ_Sn_TOS),hl

WAIT_WIZ_END:
	pop	bc
	pop	de
	pop	hl
	ret

	endif


;--- Get a free connection
;    Input:  -
;    Output: A =  Free connection number (1 to 3), 
;                 0 if no free connections available
;    Modifies: AF, BC, DE, IX

GET_FREE_CONN:
	ld	ix,WIZ_SOCKREG_BASE+WIZ_SOCKREG_SIZE
	ld	de,WIZ_SOCKREG_SIZE
	ld	bc,#0301
FREECONN_LOOP:
	ld	a,(ix+WIZ_Sn_SR)
	or	a
	ld	a,c
	ret	z
	add	ix,de
	inc	c
	djnz	FREECONN_LOOP

	xor	a
	ret


;--- Check if a TCP connection exists, and if so,
;    switch W5100 registers at page 2 (via SETSLOTP2) and
;    set the connection it as the current connection.
;    Input:  B = Connection number
;    Output: A = Error code (ERR_OK or ERR_NO_CONN)
;            C = 0 if A<>0
;    Modifies: F, C, DE, IY

SETUP_TCP:
	ld	a,b
	cp	3+1
	ld	a,ERR_NO_CONN
	ret	nc

	ld	a,b
	or	a
	ld	a,ERR_NO_CONN
	ret	z

	call	SETSLOTP2
	ld	a,b
	call	SET_CUR_CONN
	call	SET_WIZ_REGS2

	ld	a,(ix+WIZ_Sn_SR)
	ld	c,0	;Close reason is not supported currently
	cp	SOCK_UDP
	jp	z,END_NOCONN
	cp	SOCK_CLOSED
	jp	z,END_NOCONN

	xor	a
	ret


;*****************************************************
;***  AUXILIARY ROUTINES FOR HOST NAME RESOLUTION  ***
;*****************************************************

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
	call	COMP16
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


;******************************************
;***  MISCELLANEOUS AUXILIARY ROUTINES  ***
;******************************************

;Calculate checksum

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


;--- Terminate functions with various error codes

END_INV_PAR_R:
	call	RESTSLOTP2
END_INV_PAR:
	ld	a,ERR_INV_PARAM
	ret

END_OK:
	xor	a
	jp	RESTSLOTP2

END_NOCONN:
	ld	a,ERR_NO_CONN
	jp	RESTSLOTP2


;--- Set on page 2 the same slot of page 1.
;    The previous slot on page 2 is saved on the variables area,
;    and can be restored by calling RESTSLOTP2.
;    Input:  -
;    Output: - (W5100 data memory is visible at page 2)
;    Modifies: AF', BC', DE', HL'

SETSLOTP2:
	ex	af,af'
	exx
	call	GETSLTP2
	push	af
	call	GETSLTP1
	ld	h,80h
	call	ENASLT
	call	SET_WIZ_BUF2
	ld	a,#FF
	ld	(INSIDE_FUNC),a
	pop	af
	ld	(USER_SLOT_P2),a
	exx
	ex	af,af'
	ret


;This version does not set INSIDE_FUNC

SETSLOTP2_INT:
	ex	af,af'
	exx
	call	GETSLTP2
	push	af
	call	GETSLTP1
	ld	h,80h
	call	ENASLT
	call	SET_WIZ_BUF2
	pop	af
	ld	(USER_SLOT_P2),a
	exx
	ex	af,af'
	ret


;--- Restore the original slot on page 2,
;    assumes that SETSLOTP2 has been
;    called previously.
;    Input:  -
;    Output: -
;    Modifies: AF', BC', DE', HL'

RESTSLOTP2:
	ex	af,af'
	exx
	call	SET_WIZ_BUF2
	xor	a
	ld	(INSIDE_FUNC),a
	ld	a,(USER_SLOT_P2)
	ld	h,80h
	call	ENASLT
	exx
	ex	af,af'
	ret


;This version does not reset INSIDE_FUNC

RESTSLOTP2_INT:
	ex	af,af'
	exx
	call	SET_WIZ_BUF2
	ld	a,(USER_SLOT_P2)
	ld	h,80h
	call	ENASLT
	exx
	ex	af,af'
	ret


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


;--- Get slot connected on page 2
;    Input:  -
;    Output: A = Slot number
;    Modifies: AF, HL, E, BC

GETSLTP2:
	di
	in	a,(0A8h)
	ld	e,a
	and	00110000b
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
	and	00110000b
	sra	a
	sra	a
	or	c
	or	080h
	ld	c,a
NOEXP2:	ld	a,c
	ei
	ret


;--- Obtain slot work area (8 bytes) on SLTWRK
;    Input:  A  = Slot number
;    Output: HL = Work area address
;    Modifies: AF, BC

GETWRK:
	ld	b,a
	rrca
	rrca
	rrca
	and	060h
	ld	c,a	;C = Slot * 32
	ld	a,b
	rlca
	and	018h	;A = Subslot * 8
	or	c
	ld	c,a
	ld	b,0
	ld	hl,SLTWRK
	add	hl,bc
	ret


;--- Convert a character to upper-case if it is a lower-case letter
;    Input:  A = Character
;    Output: A = Converted character
;    Modifies: F

TOUPPER:
	cp	"a"
	ret	c
	cp	"z"+1
	ret	nc
	and	0DFh
	ret


;--- Compare HL and DE
;    Input:  HL, DE = values to compare
;    Output: Cy set if HL<DE
;            Z  set if H=DE
;    Modifies: AF

COMP16:
	ld	a,h
	sub	d
	ret	nz
	ld	a,l
	sub	e
	ret


;--- COMP32: Compare two 32 bit numbers, modulo 2^32,
;            stored in big-endian
;    Input: HL = Pointer al primer numero
;             DE = Pointer al segundo numero
;    Output:     C, NZ if (HL) > (DE)
;                C,  Z if (HL) = (DE)
;               NC, NZ if (HL) < (DE)
;    Modifies: HL, DE, AF, HL', DE', AF'

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
	call	COMP16	;Compare HL' and DE'
	exx
	ret


;--- Get a pointer to a connection
;    Input:  A = Connection number
;    Output: IX = Pointer to registers area of the connection
;    Modifies: AF

GET_CONN_BASE:
	ld	ix,WIZ_SOCKREG_BASE
	or	a
	ret	z
	ld	ix,WIZ_SOCKREG_BASE+WIZ_SOCKREG_SIZE
	dec	a
	ret	z
	ld	ix,WIZ_SOCKREG_BASE+WIZ_SOCKREG_SIZE*2
	dec	a
	ret	z
	ld	ix,WIZ_SOCKREG_BASE+WIZ_SOCKREG_SIZE*3
	ret


;--- Get a random local port not in use
;    Input:    -
;    Output:   HL = Port number
;    Modifies: AF, DE, HL

GET_RANDOM_PORT:
	ld	hl,(SYSTIMER)
RAND_PORT_LOOP:
	inc	hl
	res	7,h	;Ensure random port
	set	6,h	;is in the range 16384-32767

	ld	de,(WIZ_SOCKREG_BASE+WIZ_SOCKREG_SIZE+WIZ_Sn_PORT)
	call	COMP16
	jr	z,RAND_PORT_LOOP
	ld	de,(WIZ_SOCKREG_BASE+WIZ_SOCKREG_SIZE*2+WIZ_Sn_PORT)
	call	COMP16
	jr	z,RAND_PORT_LOOP
	ld	de,(WIZ_SOCKREG_BASE+WIZ_SOCKREG_SIZE*3+WIZ_Sn_PORT)
	call	COMP16
	jr	z,RAND_PORT_LOOP

	ret


;--- Set variables for current connection.
;    Assumes W5100 buffer RAM visible on page 2.
;    Input:  A = Connection number
;    Output: IX = Pointer to registers area of the connection
;    Modifies: AF, BC, DE, IY

SET_CUR_CONN:
	push	af
	call	SET_WIZ_BUF2
	pop	af
	ld	(CURCONN),a

	ld	ix,WIZ_RX_BASE
	ld	iy,WIZ_TX_BASE
	ld	bc,WIZ_RX_SIZE
	ld	de,WIZ_TX_SIZE

	inc	a
SET_CUR_CONN_LOOP:
	dec	a
	jr	z,SET_CUR_CONN_END
	add	ix,bc
	add	iy,de
	jr	SET_CUR_CONN_LOOP

SET_CUR_CONN_END:
	ld	(CURCONN_RX_BASE),ix
	ld	(CURCONN_TX_BASE),iy
	ld	bc,WIZ_RX_SIZE
	add	ix,bc
	ld	(CURCONN_RX_LIMIT),ix
	ld	bc,WIZ_TX_SIZE
	add	iy,bc
	ld	(CURCONN_TX_LIMIT),iy

	ld	a,(CURCONN)
	call	GET_CONN_BASE
	ld	(CURCONN_REG_BASE),ix
	ret


;--- PARSE_IP: Extracts an IP address from a string
;    Input:  String at DNS_BUFFER, zero terminated
;    Output: Cy=0 and IP at DNS_RESULT, or Cy=1 if not a valid IP
;    Modifies: AF, BC, DE, HL, IX

PARSE_IP:
	ld	hl,DNS_BUFFER
PARSE_IPL:
	ld	a,(hl)
	or	a
	jr	z,PARSE_IP2	;Appends a dot to ease parsing process
	inc	hl
	jr	PARSE_IPL
PARSE_IP2:	ld	(hl),"."
	push	hl
	pop	ix	;IX = Address of the last dot

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
	ld	(ix),0
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


;--- NAME: ADD32
;      Adds two 32 bit numbers
;    INPUT:  HL, DE = Numbers to add
;            BC = Destination number
;            That is, it does: (BC) = (DE) + (HL)
;    OUTPUT: -
;    MODIFIES: AF

ADD32:
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
	adc	a,(hl)
	ld	(bc),a
	ret


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


;--- NAME: SUB32
;      Substracts two 32 bit numbers
;    INPUT:  DE = Minuend
;            HL = Subtrahend
;            BC = Destination number
;            That is, it does: (BC) = (DE) - (HL)
;    OUTPUT:   -
;    MODIFIES: AF

SUB32:
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
	call	SUB32_STEP2	;Add or substract byte by byte,
	call	SUB32_STEP	;from LSB to MSB, accumulating
	call	SUB32_STEP	;carry, in 4 steps

SUB32_STEP:
	dec	hl
	dec	de
	dec	bc
SUB32_STEP2:
	ld	a,(de)
SUBSUB_CODE:
	sbc	a,(hl)
	ld	(bc),a
	ret

ZERO32:	db	0,0,0,0


;**************
;***  DATA  ***
;**************

	;--- Specification identifier (up to 15 chars and zero terminated)

UNAPI_ID:
	db	"TCP/IP",0

	;--- Implementation identifier (up to 63 chars and zero terminated)

APIINFO:
	db	"DenYoNet",0

	;--- Other data

INITMSG:
	db	13,10,"DenYoNet Ethernet Cartridge",13,10
	db	"(c) 2009 Dennis Koller & Yobi",13,10
	db	"Produced by Sunrise for MSX",13,10
	db	13,10
	db	"DenYoNet TCP/IP UNAPI BIOS ",ROM_V_P+48,".",ROM_V_S+48,13,10
	db	"(c) 2014 Konamiman",13,10
	db	13,10
	db	0

NOINITMSG:
	db	"DENYONET NOT INITIALIZED!",13,10
	db	"Run _DENYOINIT or DENYINIT.COM to initialize",13,10
	db	13,10
	db	0

	;ds      08000h-$,#FF     ;Padding to make a 16K ROM

	end
