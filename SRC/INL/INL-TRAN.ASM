;InterNestor Lite v2.1 - TCP/IP stack for MSX2 computers
;Transient part (installer and control application)
;
;Copyright (C) 2003-2019 Nestor Soriano (Konamiman)

;This code is prepared for the Compass MSX assembler.

;--- This constant selects the InterNestor version to be generated:
;--- 0 for the serial (RS232/modem) version, 1 for the Ethernet version
;
;    NOTE:
;    RS232/modem version requires Erik Maas' Fossil driver installed.
;    Ethernet version requires UNAPI compliant Ethernet API installed.

LINK:	equ	1


;The source code for InterNestor Lite is divided in two files:
;INL-TRAN.ASM is the transient part (installer and control program)
;INL-RES.ASM is the resident part (timer interrupt and user functions)
;
;Assemble both, the concatenate the results,
;and name the resulting file INL.COM. For example, in MSX-DOS:
;
;concat /b inl-tran.dat+inl-res.dat inl.com


;****************************
;***                      ***
;***  MACROS & CONSTANTS  ***
;***                      ***
;****************************

	;.label	20	;For Compass

;When the following variable is 0, resident code is NOT attached
;to timer interrupt hook (for debugging)
USETIMI:	equ	1

;Maximum number of files that can be opened simultaneously
;(applies under DOS 1 only)
MAXFILES:	equ	1

;Addresses where the reserved code and data slot and segment numbers
;will be stored (in the code segment)
RES_SEG1:	equ	#7FF0	;Code segment number
RES_SEG2:	equ	#7FF1	;Data segment number

;--- MSX-DOS functions

;* DOS 1

_TERM0:		equ	#00
_CONOUT:	equ	#02
_DIRIO:		equ	#06
_STROUT:	equ	#09
_FOPEN:		equ	#0F
_FCLOSE:	equ	#10
_SETDTA:	equ	#1A
_WRBLK:		equ	#26
_RDBLK:		equ	#27
_GDATE:		equ	#2A
_GTIME:		equ	#2C

;* DOS 2

_OPEN:		equ	#43
_CLOSE:		equ	#45
_READ:		equ	#48
_WRITE:		equ	#49
_PARSE:		equ	#5B
_DEFAB:		equ	#63
_EXPLAIN:	equ	#66
_TERM:		equ	#62
_GENV:		equ	#6B
_DOSVER:	equ	#6F

;--- System variables, hooks and BIOS routines

ENDTPA:		equ	#0006
ENASLT:		equ	#0024
RDSLT:		equ	#000C	;A=PEEK(Slot A, Address HL)
CALSLT:		equ	#001C	;CALL Slot IYh, Address IX
GETCPU:		equ	#0183	;A=0 if Z80 mode
HIMSAV:		equ	#F349
ARG:		equ	#F847
SYSTIMER:	equ	#FC9E
EXPTBL:		equ	#FCC1
H_TIMI:		equ	#FD9F
EXTBIO:		equ	#FFCA

	if	LINK=1

;--- Ethernet UNAPI routines

ETH_RESET:	equ	1	;Hardware reset
ETH_GET_HWADD:	equ	2	;Get MAC address

	endif

;--- TCP/IP UNAPI routines

TCPIP_NET_STATE:	equ	3
TCPIP_DNS_Q:	equ	6
TCPIP_DNS_S:	equ	7
TCPIP_TCP_CLOSE:	equ	14
TCPIP_TCP_ABORT:	equ	15
TCPIP_TCP_STATE:	equ	16
TCPIP_WAIT:	equ	29

INL_GET_DATASEG:	equ	128
INL_ETH2ASCII:	equ	129
INL_ASCII2ETH:	equ	130
INL_IP_STRING:	equ	136
INL_SEND_MODEM:	equ	138
INL_PPP_OPEN:	equ	139
INL_PPP_CLOSE:	equ	140
INL_GET_SOCKS_PROXY: equ 141
INL_SET_SOCKS_PROXY: equ 142

;--- TCP/IP UNAPI error codes

ERR_NO_NETWORK:	equ	2
ERR_NO_DNS:	equ	7

;--- Macros

print:	macro	@s
	ld	de,@s
	ld	c,_STROUT
	call	5
	endm

dummy:	macro
	endm

;--- Misc constants

;Entry point for MSX-DOS function calls
DOS:	equ	#0005

;Temporary space for parameters, calculations, etc
TEMPBUF:	equ	#C000

;--- Data segment constants.
;    These may need to be updated when the data segment code changes.
;    On the other hand, if the code is converted for an assembler
;    that has support for includes/multiple file projects,
;    this section may be completely removed.

	if	LINK=1

ARP_ENTRIES:	equ	32	;Number of supported ARP entries
ROUTE_ENTRIES:	equ	16	;Number of supported routing entries
ARP_CACHE:	equ	#A000-16*ARP_ENTRIES
ROUTE_TABLE:	equ	ARP_CACHE-16*ROUTE_ENTRIES

	endif

BUF_IPLOCAL:	equ	#8000	;Local IP (4 bytes)
BUF_IPDNS1:	equ	#8004	;IP DNS 1 (4 bytes)
BUF_IPDNS2:	equ	#8008	;IP DNS 2 (4 bytes)
REPLYECHO:	equ	#800C	;Reply PINGs yes/no
TTL:		equ	#800D	;TTL for outgoing datagrams
TOS:		equ	#800E	;TOS for outgoing datagrams
CHKVECT:	equ	#800F	;Checksum optimizacions vector
			;       (&B 0 0 0 ICMP UDP TCP IP PPP)
PING_SIZE:	equ	#8010	;Size of outgoing PINGs

	if	LINK=0

BUF_DIAL:	equ	#8012	;Buffer for ISP phone number (16 bytes)
BUF_MODREP:	equ	#8022	;Buffer for modem reply (16 bytes)
BUF_PPPUSER:	equ	#8032	;Buffer for PPP user (32 bytes)
BUF_PPPASSW:	equ	#8052	;Buffer for PPP password (32 bytes)
BUF_IPREMOTE:	equ	#8072	;Remote IP (4 bytes)
NEGDNS:		equ	#8076	;Negotiate DNSs yes/no
USEPPPECHO:	equ	#8077	;Use PPP echoes for keep alive
USEPPPVJ:	equ	#8078	;Use Van Jacobson compression
PPP_STATE:	equ	#8079	;PPP automaton state
PPP_CLCODE:	equ	#807A	;Last PPP close reason
XCP_TTIMER:	equ	#8146	;Global timer for LCP/IPCP/PAP/CHAP automatons
XCP_RTIMER:	equ	#8148	;Retry timer for LCP/IPCP/PAP/CHAP automatons

	endif

	if	LINK=1

HWAD:		equ	#8013	;MAC address
SUBNET_MASK:	equ	#8019	;Subnet mask
DEFGW:		equ	#801D	;Default gateway
ARP_TOUT:	equ	#8021	;ARP cache timeout, in 1/60 seconds
ARP_TOUT_SECS:	equ	#8025	;ARP cache timeout, in seconds
FRAME_TYPE:	equ	#8029	;0=send Eth 2 frames, 1=send IEEE 802.3 frames
CHECK_NET:	equ	#802A	;Periodically check network connection if #FF
DHCP_VECT:	equ	#802B	;Parameters to be obtained via DHCP
DHCP_VECT_O:	equ	#802D	;Parameters actually obtained via DHCP
DHCP_STATE:	equ	#802F	;DHCP automaton state
NETSTAT_TIMER:	equ	#8031	;Timer to check network state

DHCP_XID:	equ	#8033	;Next DHCP XID to use

;Ethernet API related values:
UN_SEG:		equ	#822C	;Implementacion segment, #FF if ROM
UN_SLOT:	equ	#822D	;Implementacion slot
UN_ADDRESS:	equ	#822E	;Routines entry point
UN_RAMCALL:	equ	#8230	;RAM helper address

	endif


;--- Code segment routines

TIMI_ENTRY:	equ	#4000
EXTBIO_ENTRY:	equ	#4003
PAUSED:		equ	#4006
OLD_EXTBIO:	equ	#4007
OLD_TIMI:	equ	#400C
NEW_EXTBIO:	equ	#4011
NEW_TIMI:	equ	#4016
INITRES:	equ	#401B
PUT_P1:		equ	#401E

	if	LINK=0
RS_IN:		equ	#402A
	endif

	if	LINK=1
EXEUNAPI:	equ	#402A	;Code to execute Ethernet UNAPI routines
	endif

TCP_UNAPI_ENTRY: equ #4036


;************************
;***                  ***
;***  INITIALIZATION  ***
;***                  ***
;************************

	org	#100

	;--- Show welcome message

	print	INIT_S

	;--- Obtain mapper support routines table when they are available

	ld	c,_DOSVER	;DOS 2?
	call	5
	or	a
	jr	nz,NODOS2
	ld	a,b
	cp	2
	jr	c,NODOS2

    ld  a,0FFh
    ld  (DOS2),a
NODOS2:

	ld	de,#0402
	xor	a
	call	EXTBIO
	or	a
	jr	z,NOMAPPER
	ld	a,#FF
	ld	(MAPPER_ROUTINES),a
	ld	de,_ALL_SEG
	ld	bc,#30
	ldir
NOMAPPER:

	;--- Set program abort handler routine

    ld  a,(DOS2)
    or  a
	ld	de,AB_HANDLER
	ld	c,_DEFAB
	call	nz,5

	;--- Extract first parameter from command line,
	;    if none available, show usage info and exit

	ld	a,1
	ld	de,TEMPBUF
	call	EXTPAR
	jr	nc,OKPAR1

	print	INFO_S
	jp	FIN
OKPAR1:

	;--- Check if INL is already installed, but only if mapper support routines are installed

    ld  a,(MAPPER_ROUTINES)
    or  a
    jr  z,NOTINST

	;> Get the number of TCP/IP UNAPI implementations

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
	jr	z,NOTINST

	;> For each implementation which is on mapped RAM,
	;  check the name against "InterNestor Lite"

CHKIMP:
	push	bc
	ld	a,b
	ld	de,#2222
	call	EXTBIO		;Returns A=slot, B=segment, HL=entry point

	ld	c,a
	ld	a,h
	cp	#C0
	ld	a,c
	jr	nc,NEXTIMP	;Skip if page 3 implementation
	ld	ix,#F344
	cp	(ix)
	jr	nz,NEXTIMP	;Skip if not mapped RAM slot
	ld	a,b
	cp	#FF
	jr	z,NEXTIMP	;Skip if segment is #FF (should never occur)

	ld	(SEG1),a	;Store candidate segment and entry point values
	ld	(CALL_UNAPI+1),hl

	call	_PUT_P1

	xor	a	;UNAPI_GET_INFO
	call	JP_HL	;Returns address of implementation name in HL
	ld	de,INLID_S

COMPNAME:
	ld	a,(de)
	cp	(hl)
	jr	nz,NEXTIMP
	inc	hl
	inc	de
	jr	nz,COMPNAME

	pop	bc
	jr	YESINST

NEXTIMP:
	pop	bc
	djnz	CHKIMP
	ld	a,1
	call	_PUT_P1

	;--- Not installed: if parameter is not "I", error

NOTINST:
	ld	a,(TEMPBUF)
	or	#20	;To lower case
	ld	h,a
	ld	a,(TEMPBUF+1)
	ld	l,a
	ld	de,#6900	;"i" followed by 0
	call	COMP
	jr	z,OKPAR3

	print	NOTINS_S
	jp	FIN

	;--- Installed: if parameter is "I", error

YESINST:
	ld	a,INL_GET_DATASEG
	call	CALL_UNAPI
	ld	a,b	;Save data segment number
	ld	(SEG2),a

	ld	a,1
	call	_PUT_P1

	ld	a,(TEMPBUF)
	or	#20
	cp	"i"
	jr	nz,OKPAR2
	ld	a,(TEMPBUF+1)
	or	a
	jr	nz,OKPAR2

	print	YESINS_S
	jp	FIN
OKPAR2:

	if	LINK=1

	;--- Obtain necessary information to execute Ethernet UNAPI routines

	ld	a,(SEG2)
	call	_PUT_P2
	ld	hl,UN_SEG
	ld	de,_UN_SEG
	ld	bc,6
	ldir
	ld	a,1
	call	_PUT_P2

	endif

OKPAR3:

	;--- According to first parameter (and maybe the second one),
	;    jump to the appropriate part of the code

PROC_PARAMS:
	ld	a,(TEMPBUF+1)
	or	a
	jr	z,SIMPLEPAR
	ld	a,(TEMPBUF)
	or	#20	;To lower case
	cp	"t"
	jp	z,TCPPAR
	cp	"d"
	jp	z,DNSPAR
	cp	"g"
	jp	z,GETPAR
	cp	"s"
	jp	z,SETPAR
	cp	"i"
	jp	z,IPPAR

	if	LINK=0
	cp	"p"
	jr	z,PPPPAR
	endif

	if	LINK=1
	cp	"e"
	jp	z,ETHPAR
	cp	"a"
	jp	z,ARPPAR
	cp	"r"
	jp	z,ROUPAR
	endif

UNKPAR:	print	UNKPAR_S
	jp	FIN

	;* Simple parameter

SIMPLEPAR:
	ld	a,(TEMPBUF)
	or	#20
	cp	"i"
	jp	z,PAR_SIM_I
	cp	"u"
	jp	z,PAR_SIM_U
	cp	"p"
	jp	z,PAR_SIM_P
	cp	"r"
	jp	z,PAR_SIM_R
	cp	"s"
	jp	z,PAR_SIM_S
	cp	"d"
	jp	z,PAR_SIM_D
	cp	"o"
	jp	z,PAR_SIM_O
	cp	"v"
	jp	z,PAR_SIM_V
	cp	"f"
	jp	z,PAR_SIM_F
	jr	UNKPAR

	if	LINK=0

	;* PPP parameter

PPPPAR:
	ld	a,2
	ld	de,TEMPBUF
	call	EXTPAR
	jp	c,MISSPAR

	ld	a,(TEMPBUF)
	or	#20
	cp	"m"
	jp	z,PAR_PPP_M
	cp	"n"
	jp	z,PAR_PPP_N
	cp	"b"
	jp	z,PAR_PPP_B
	cp	"r"
	jp	z,PAR_PPP_R
	cp	"u"
	jp	z,PAR_PPP_U
	cp	"p"
	jp	z,PAR_PPP_P
	cp	"o"
	jp	z,PAR_PPP_O
	cp	"c"
	jp	z,PAR_PPP_C
	cp	"e"
	jp	z,PAR_PPP_E
	cp	"v"
	jp	z,PAR_PPP_V
	jp	UNKPAR

	endif

	;* TCP parameter

TCPPAR:	
	ld	a,2
	ld	de,TEMPBUF
	call	EXTPAR
	jp	c,MISSPAR

	ld	a,(TEMPBUF)
	or	#20
    cp  "x"
    jp  z,PAR_TCP_X

    ld b,a
    ld	a,(IS_FILE)
	or	a
	jp	nz,NOFILE
    ld a,b

	cp	"s"
	jp	z,PAR_TCP_S
	cp	"c"
	jp	z,PAR_TCP_C
	cp	"a"
	jp	z,PAR_TCP_A
    
	jp	UNKPAR

	;* DNS parameter

DNSPAR:	ld	a,(IS_FILE)
	or	a
	jp	nz,NOFILE

	ld	a,2
	ld	de,TEMPBUF
	call	EXTPAR
	jp	c,MISSPAR

	ld	a,(TEMPBUF)
	or	#20
	cp	"r"
	jp	z,PAR_DNS_R
	jp	UNKPAR

	;* IP parameter
IPPAR:
	ld	a,2
	ld	de,TEMPBUF
	call	EXTPAR
	jp	c,MISSPAR

	ld	a,(TEMPBUF)
	or	#20
	cp	"i"
	jp	z,PAR_IP_I
	cp	"p"
	jp	z,PAR_IP_P
	cp	"s"
	jp	z,PAR_IP_S
	cp	"e"
	jp	z,PAR_IP_E
	cp	"t"
	jp	z,PAR_IP_T
	cp	"o"
	jp	z,PAR_IP_O
	cp	"z"
	jp	z,PAR_IP_Z
	cp	"l"
	jp	z,PAR_IP_L

	if	LINK=0
	cp	"r"
	jp	z,PAR_IP_R
	cp	"n"
	jp	z,PAR_IP_N
	endif

	if	LINK=1
	cp	"g"
	jp	z,PAR_IP_G
	cp	"m"
	jp	z,PAR_IP_M
	cp	"d"
	jp	z,PAR_IP_D
	endif

	jp	UNKPAR

	if	LINK=1

	;* Ethernet parameter
ETHPAR:
	ld	a,2
	ld	de,TEMPBUF
	call	EXTPAR
	jp	c,MISSPAR

	ld	a,(TEMPBUF)
	or	#20
	cp	"h"
	jp	z,PAR_ETH_H
	cp	"f"
	jp	z,PAR_ETH_F
	cp	"c"
	jp	z,PAR_ETH_C
	cp	"r"
	jp	z,PAR_ETH_R
	;cp     "d"
	;jp     z,PAR_ETH_D
	jp	UNKPAR

	;* ARP parameter
ARPPAR:
	ld	a,2
	ld	de,TEMPBUF
	call	EXTPAR
	jp	c,MISSPAR

	ld	a,(TEMPBUF)
	or	#20
	cp	"t"
	jp	z,PAR_ARP_T
	cp	"s"
	jp	z,PAR_ARP_S
	cp	"c"
	jp	z,PAR_ARP_C
	cp	"a"
	jp	z,PAR_ARP_A
	cp	"d"
	jp	z,PAR_ARP_D
	jp	UNKPAR

	;* Routing table parameter
ROUPAR:
	ld	a,2
	ld	de,TEMPBUF
	call	EXTPAR
	jp	c,MISSPAR

	ld	a,(TEMPBUF)
	or	#20
	cp	"s"
	jp	z,PAR_ROU_S
	cp	"c"
	jp	z,PAR_ROU_C
	cp	"a"
	jp	z,PAR_ROU_A
	cp	"d"
	jp	z,PAR_ROU_D
	jp	UNKPAR

	endif

;--- Parameters not implemented yet

GETPAR:
SETPAR:

	print	NOTIMP_S
	jp	FIN
NOTIMP_S:	db	"*** Not implemented yet.$"


;**********************
;***                ***
;***  INSTALLATION  ***
;***                ***
;**********************

PAR_SIM_I:
	ld	a,(IS_FILE)
	or	a
	jp	nz,NOFILE

	;--- Check that the mapper support routines and the RAM helper are installed

    ld  a,(MAPPER_ROUTINES)
    or  a
    jr  nz,OKMSR

    print   NOMSR_S
    jp  FIN
OKMSR:

	ld	a,#FF
	ld	de,#2222
	ld	hl,0
	call	EXTBIO
	ld	a,h
	or	l
	jr	nz,OKRAMHELP

	print	NORAMHELP_S
	jp	FIN

OKRAMHELP:
	ld	(RAMHELPER),hl
	ld	(MAPTAB),bc

    ;--- If mapper table supplied by standard mapper support routines is present, use it

    ld  de,0401h
    xor  a
    call  EXTBIO
    or  a
    ld  a,2
    jr z,NOMAPTAB
    ld  (MAPTAB),hl
    ld  a,8
NOMAPTAB:
    ld  (MAPTAB_ENTRY_SIZE),a

	if	LINK=0

	;--- Check that Fossil driver is installed

	ld	hl,(#F3FC)
	ld	de,"SR"
	call	COMP
	jr	z,OKFOSSIL

	print	NOFOS_S
	jp	FIN
OKFOSSIL:	;

	endif

	;--- Check TPA type is valid
	;    (all pages must be in the same RAM slot)

	ld	a,(#F344)
	ld	b,a
	ld	a,(#F342)
	cp	b
	jr	z,OKTPATYPE

	print	BADTPAT_S
	jp	FIN
OKTPATYPE:	;

	;--- Save command line
	;    (it will be destroyed if INL.CFG is parsed)

	ld	hl,#80
	ld	de,TEMPBUF2
	ld	bc,128
	ldir

	if	LINK=0

	;--- If not Turbo-R, or Turbo-R in Z80 mode, set 9600 bauds.
	;    If Turbo-R in R800 mode, set 19200 bauds.

	ld	a,(#FCC1)	;Turbo-R?
	ld	hl,#002D
	call	RDSLT
	cp	3
	jr	nz,SET9600

	ld	iy,(#FCC1-1)	;R800?
	ld	ix,GETCPU
	call	CALSLT
	or	a
	jr	z,SET9600

	ld	a,7
	jr	SET19K9K

SET9600:
	ld	a,6

SET19K9K
	ld	ix,(#F3FE)
	ld	bc,9	;IX = Fossil's SetBaud routine
	add	ix,bc
	ld	h,a
	ld	l,a
	ld	de,SETBOK
	push	de
	jp	(ix)
SETBOK:	;

	endif

	if	LINK=1

	;--- Search for an UNAPI compliant Ethernet API

	print	SRCHUNAPI_S

	ld	hl,UNAPIID_S
	ld	de,ARG
	ld	bc,9
	ldir
	ld	de,#2222
	xor	a
	ld	b,0
	call	EXTBIO
	ld	a,b
	or	a
	jr	nz,SRCHUNAPI_1

	;* Not found

	print	NOUNAPI_S
	jp	FIN

	;* Found: obtain and save slot, and show information

SRCHUNAPI_1:
	call	EXTBIO	;We'll use implementation with highest index (smaller slot number)
	ld	(_UN_SLOT),a
	ld	a,b
	ld	(_UN_SEG),a
	ld	(_UN_ADDRESS),hl

	cp	#FF
	jr	nz,SRCHUNAPI_2
	;ld	a,#FF
	call	EXTBIO
	ld	(_UN_RAMCALL),hl
SRCHUNAPI_2:

	;Show implementation name and version

	print	FOUND_S

	xor	a
	call	_EXEUNAPI
	push	bc
	ld	a,(_UN_ADDRESS+1)
	and	%10000000
	ld	ix,READHL
	jr	nz,IS_ROM
	ld	a,(_UN_SEG)
	cp	#FF
	ld	ix,RDSLT	;CALSLT: In: A=Slot, HL=Dir; Out: A=Data
	jr	z,IS_ROM
	ld	b,a
	ld	ix,(_UN_RAMCALL)	;RAMCALL: In: A=Slot, HL=Dir, B=Seg; Out: A=Data
IS_ROM:

	;>> Here IX contains READHL, RDSLT or UN_RAMCALL,
	;   depending on the implementation location

	ld	a,(_UN_SLOT)
IMP_LOOP:
	push	af,hl,ix,bc
	ld	de,IMP_LOOP2
	push	de
	jp	(ix)
IMP_LOOP2:
	or	a
	jr	z,IMP_END
	ld	e,a
	ld	c,_CONOUT
	call	5
	pop	bc,ix,hl,af
	inc	hl
	jr	IMP_LOOP

IMP_END:
	pop	bc,ix,hl,af
	ld	e," "
	ld	c,_CONOUT
	call	5
		ld	e,"v"
	ld	c,_CONOUT
	call	5

	pop	bc
	push	bc
	ld	a,b
	ld	ix,SLOT_S
	call	BYTE2ASC
	ld	(ix),"$"
	print	SLOT_S

	ld	e,"."
	ld	c,_CONOUT
	call	5

	pop	bc
	ld	a,c
	ld	ix,SLOT_S
	call	BYTE2ASC
	ld	(ix),"$"
	print	SLOT_S

	;Shows "at page 3" if necessary

	ld	a,(_UN_ADDRESS+1)
	and	%10000000
	jr	z,NOATPAGE3

	print	ATPAGE3_S
	jr	OK_SHOWSEG
NOATPAGE3:

	;Show slot number

	ld	a,"$"
	ld	(SLOT_S+1),a
	ld	a,(_UN_SLOT)
	ld	c,a
	and	%11
	add	"0"	;Prepare descriptive string, primary slot...
	ld	(SLOT_S),a
	bit	7,c
	jr	z,NOEXPSLT

	ld	a,"-"	;...and subslot if necessary
	ld	(SLOT_S+1),a
	ld	a,c
	rrca
	rrca
	and	%11
	add	"0"
	ld	(SLOT_S+2),a
NOEXPSLT:

	print	FOUND2_S
	print	SLOT_S

	;Show segment number

	ld	a,(_UN_SEG)
	cp	#FF
	jr	z,OK_SHOWSEG

	ld	ix,SLOT_S
	call	BYTE2ASC
	ld	(ix),"$"
	print	FOUND3_S
	print	SLOT_S

OK_SHOWSEG:
	print	TWOLINES

	;--- Initialize Ethernet hardware

	ld	a,ETH_RESET
	call	_EXEUNAPI

	ld	a,ETH_GET_HWADD
	call	_EXEUNAPI	;Get MAC
	ld	(_HWAD),hl
	ld	(_HWAD+2),de
	ld	(_HWAD+4),bc

	endif


	;=============================
	;===  Segments allocation  ===
	;=============================

	;--- Allocate two segments in system mode on primary mapper

DOALLS:
	ld	b,0	;Allocate 2 segments in system mode
	ld	a,1
	call	_ALL_SEG
    jr  c,NOFRESEG
	ld	(SEG1),a

	ld	b,0
	ld	a,1
	call	_ALL_SEG
    jr  nc,OKSELSEG
	
    ld  a,(SEG1)
    ld  b,0
    call    _FRE_SEG
NOFRESEG:
	print	NOFREE_S
	jp	FIN

OKSELSEG:
    ld	(SEG2),a


	;==========================================================
	;===  Copy and initialize resident code and variables  ===
	;==========================================================

	;--- Copy resident code to page 2 temporarily,
	;    switch segment code on page 1,
	;    and copy code from page 2 to page 1.

	ld	hl,INL_CODE
	ld	de,#8000
	ld	bc,16384
	ldir

	ld	a,(SEG1)
	call	_PUT_P1

	ld	hl,#8000
	ld	de,#4000
	ld	bc,16384
	ldir

	ld	hl,(SEG1)
	ld	(RES_SEG1),hl	;Also setup segment numbers info

	ld	a,#FF
	ld	(IS_FILE_INS),a

	if	LINK=1

	;--- Create the code for EXEUNAPI in the code segment

	ld	ix,EXEUNAPI

	;* Direct call: put "JP address"

	ld	hl,(_UN_ADDRESS)
	bit	7,h
	jr	z,INIEXE2

	ld	(ix),#C3
	ld	(ix+1),l
	ld	(ix+2),h
	jr	INIEXE_OK

	;* ROM or mapped RAM: put LD IY,seg+slot*256 - LD IX,address - JP...

INIEXE2:
	ld	hl,(_UN_SEG)	;H=slot, L=segment or #FF
	ld	de,(_UN_ADDRESS)
	ld	(ix),#FD
	ld	(ix+1),#21
	ld	(ix+2),l
	ld	(ix+3),h
	ld	(ix+4),#DD
	ld	(ix+5),#21
	ld	(ix+6),e
	ld	(ix+7),d
	ld	(ix+8),#C3

	;* JP to CALSLT if segment is #FF, to UN_RAMCALL otherwise

	ld	a,l
	cp	#FF
	ld	hl,CALSLT
	jr	z,INIEXE3
	ld	hl,(_UN_RAMCALL)
INIEXE3:
	ld	(ix+9),l
	ld	(ix+10),h
INIEXE_OK:

	;--- Initialize hardware

RESET_INL:
	ld	a,ETH_RESET
	call	_EXEUNAPI

	ld	a,ETH_GET_HWADD
	call	_EXEUNAPI	;Obain MAC
	ld	(_HWAD),hl
	ld	(_HWAD+2),de
	ld	(_HWAD+4),bc

	endif

	;--- Switch data segment on page 2 and initialize it

	ld	a,(SEG2)
	call	_PUT_P2

	call	INIT_VARS

	if	LINK=0
	call	FOS_INIT	;Initialize Fossil driver
	endif

	if	LINK=1

	ld	hl,_UN_SEG	;Initialize Ethernet API data
	ld	de,UN_SEG
	ld	bc,6
	ldir

	ld	hl,_HWAD	;Set MAC address info
	ld	de,HWAD
	ld	bc,6
	ldir

	ld	a,63
	ld	(DHCP_VECT),a

	;--- Obtain environment items for initialization

	ld	a,(DOS2)
	or	a
	jp	z,ENV_OK

	;* IPs

	ld	hl,ENV_IP
	ld	de,BUF_IPLOCAL
	call	DO_ENV_IP

	ld	hl,ENV_MASK
	ld	de,SUBNET_MASK
	call	DO_ENV_IP

	ld	hl,ENV_GW
	ld	de,DEFGW
	call	DO_ENV_IP

	ld	hl,ENV_DNS1
	ld	de,BUF_IPDNS1
	call	DO_ENV_IP

	ld	hl,ENV_DNS2
	ld	de,BUF_IPDNS2
	call	DO_ENV_IP

	;* DHCP vector

	ld	hl,ENV_DHCP
	ld	de,TEMPBUF
	ld	b,6
	ld	c,_GENV
	call	DOS

	ld	a,(TEMPBUF)
	or	a
	jr	z,ENV_OK
	ld	hl,TEMPBUF
	call	EXTNUM8
	jr	c,ENV_OK

	ld	(DHCP_VECT),a
	jr	ENV_OK

	;* This subroutine extracts the IP addres from environment item
	;  pointed by HL, and stores it in the address pointed by DE

DO_ENV_IP:
	push	de
	ld	b,16
	ld	de,TEMPBUF+3
	ld	c,_GENV
	call	DOS
	pop	de
	ld	a,(TEMPBUF)
	or	a
	ret	z
	push	de

	call	PARSE_IP
	pop	de
	ret	c
	ld	hl,PARSED_IP
	ld	bc,4
	ldir

	ret

	;* Environment items that will be checked

ENV_IP:		db	"INL_IP",0
ENV_MASK:	db	"INL_MASK",0
ENV_GW:		db	"INL_GW",0
ENV_DNS1:	db	"INL_DNS_P",0
ENV_DNS2:	db	"INL_DNS_S",0
ENV_DHCP:	db	"INL_DHCP",0

ENV_OK:

	endif

	;--- Read and parse INL.CFG, if it exists

	xor	a
	ld	(FCBS),a	;Needed in DOS 1

	;* Filename: in DOS 1 use simply INL.CFG,
	;  in DOS 2 use INL.CFG at the same directory as INL.COM

	ld	de,TEMPBUF
	ld	a,(DOS2)
	or	a
	jr	z,READINI_OK1

	ld	hl,PROGRAM_S	;DOS 2: Obtain env item PROGRAM...
	;ld	de,TEMPBUF
	ld	b,128
	ld	c,_GENV
	call	DOS

	ld	de,TEMPBUF	;...and from there obtain the pointer
	ld	bc,_PARSE	;to file name
	call	DOS
	ex	de,hl

READINI_OK1:	ld	hl,INLCFG_S
	ld	bc,8
	ldir

	;* Try to open the file

	ld	de,TEMPBUF
	call	OPEN
	or	a
	jr	nz,READINI_END
	ld	a,b
	ld	(FH),a

	;* Set IS_FILE and jump to FIN, this will cause
	;  the first parameter to be processed

	ld	a,#FF
	ld	(IS_FILE),a
	jp	FIN

	;* When finished, it will jump here

READINI_END:
	ld	a,(IS_FILE_INS)	;In case INL D was invoked
	or	a
	jr	nz,READINI_END2

	xor	a
	ld	(IS_FILE),a
	jp	FIN

READINI_END2:
	xor	a
	ld	(IS_FILE_INS),a
	ld	a,1	;Restore TPA in page 2
	call	_PUT_P2


	;===========================================================
	;===  Patch code segment and the timer and EXTBIO hooks  ===
	;===========================================================

	ld	a,(SEG1)
	call	_PUT_P1

	;--- Copy fossil routines and mapper routines to code segment

	if	LINK=0

	ld	hl,(#F3FE)
	ld	bc,6*3
	add	hl,bc
	ld	de,RS_IN
	ld	bc,4*3
	ldir

	endif

	ld	hl,_PUT_P1
	ld	de,PUT_P1
	ld	bc,4*3
	ldir

	call	INITRES

	;--- Save the old hook values

	ld	hl,H_TIMI
	ld	de,OLD_TIMI
	ld	bc,5
	ldir

	ld	hl,EXTBIO
	ld	de,OLD_EXTBIO
	ld	bc,5
	ldir

	;--- Patch the hooks to invoke the RAM helper

	di

	xor	a
	ld	ix,H_TIMI
	call	PATCH_HOOK

	ld	a,1
	ld	ix,EXTBIO
	call	PATCH_HOOK

	ei

	;--- Copy the new hook values (needed to uninstall)

	ld	hl,H_TIMI
	ld	de,NEW_TIMI
	ld	bc,5
	ldir

	ld	hl,EXTBIO
	ld	de,NEW_EXTBIO
	ld	bc,5
	ldir

	ld	a,2	;Restore TPA in page 1
	call	_PUT_P1

	;--- Installation has finished.

	print	HAVEFUN_S

	jp	FIN

	if	LINK=1
READHL:	ld	a,(hl)
	ret
	endif


;--- This routine patches a hook so that
;    it calls the routine with the specified index
;    in the allocated segment.
;    Input: A  = Routine index, 0 to 63
;           IX = Hook address
;           ALLOC_SEG and ALLOC_SLOT set

PATCH_HOOK:
	push	af
	ld	a,#CD	;Code for "CALL"
	ld	(ix),a
	ld	hl,(RAMHELPER)
	ld	bc,6
	add	hl,bc	;Now HL points to segment call routine
	ld	(ix+1),l
	ld	(ix+2),h

	ld	hl,(MAPTAB)
    ld  bc,(MAPTAB_ENTRY_SIZE)
    ld  b,0
	ld	a,(#F344)	;Primary mapper slot
	ld	d,a
	ld	e,0	;Index on mappers table
SRCHMAP:
	ld	a,(hl)
	cp	d
	jr	z,MAPFND
	add hl,bc	;Next table entry
	inc	e
	jr	SRCHMAP
MAPFND:
	ld	a,e	;A = Index of slot on mappers table
	rrca
	rrca
	and	%11000000
	pop	de	;Retrieve routine index
	or	d
	ld	(ix+3),a

	ld	a,(SEG1)
	ld	(ix+4),a
	ret


;===========================================
;===  Strings for the installation code  ===
;===========================================

	;--- Presentation and help string

INIT_S:

	if	LINK=0
	db	"InterNestor Lite for RS232/modem"
	endif

	if	LINK=1
	db	"InterNestor Lite for the Ethernet UNAPI"
	endif

	db	" v2.2: TCP/IP stack for MSX-DOS",13,10

	if	USETIMI=0
	db	"*** NO TIMER!!",13,10
	endif
	db	"By Konamiman, 8/2019",13,10,13,10,"$"

INFO_S:	db	"Frequently used options:",13,10,13,10

	db	"INL I|U",13,10
	db	"Installs/uninstalls InterNestor Lite.",13,10,13,10

	if	LINK=0

	db	"INL PPP O [/n:[<number>]] [/u:[<user>]] [/p:[<passw>]] [/r:<ex mod rep>] [/i]",13,10
	db	"Opens a PPP connection (when using a modem, connects to Internet).",13,10,13,10

	db	"INL PPP C",13,10
	db	"Closes the PPP connection (when using a modem, disconnects from Internet).",13,10,13,10

	endif

	if	LINK=1

	db	"INL IP D 0|63",13,10
	db	"Turn off/on the usage of DHCP for configuration.",13,10,13,10

	db	"INL IP L|M|G|P|S <IP address>",13,10
	db	"Set up the local IP address/subnet mask/default gateway/",13,10
	db	"primary DNS server/secondary DNS server.",13,10,13,10
    
	db	"INL TCP X1|X2 <IP address>|0 <port>",13,10
	db	"Sets SOCKS server address and port for non-TLS (X1) and TLS (X2) connections.",13,10
    db  "Pass 0 instead of IP address and no port to unset.",13,10,13,10

	endif

	db	"INL S|V",13,10
	db	"Show InterNestor Lite status/configuration variables.",13,10,13,10

	db	"See the INL user's manual for more details.",13,10,"$"

	;--- Status and error messages

NOTINS_S:	db	"*** InterNestor Lite is not installed",13,10,"$"
YESINS_S:	db	"*** InterNestor Lite is already installed",13,10,"$"
BADTPAT_S:
	db	"*** Error: TPA pages are located at more than one slot.",13,10
	db	"    Reboot in DOS 2 mode or remove external mappers and try again.",13,10,"$"
NOMAP_S:	db	"*** No mapped RAM found. InterNestor Lite not installed.",13,10,"$"
MAP64_S:	db	"*** Only 64K mapped RAM found. InterNestor Lite not installed.",13,10,"$"
NOFREE_S:	db	"*** No free segments on primary mapper. InterNestor Lite not installed.",13,10,"$"
HAVEFUN_S:	db	"InterNestor Lite has been installed. Have fun! (^^)/",13,10,"$"

	if	LINK=0
NOFOS_S:	db	"*** Fossil driver not found. InterNestor Lite not installed.",13,10,"$"
	endif

	if	LINK=1

SRCHUNAPI_S:	db	"Searching Ethernet UNAPI implementation... $"
NOUNAPI_S:	db	"ERROR!",13,10,13,10,"*** No Ethernet UNAPI implementation found. InterNestor Lite not installed.",13,10,"$"
FOUND_S:	db	"OK",13,10,"Found $"
FOUND2_S:	db	" at slot $"
SLOT_S:		db	"   $"
FOUND3_S:	db	", segment $"
ATPAGE3_S:	db	" at page 3$"
TWOLINES:	db	13,10,13,10,"$"

	endif

	;--- TCP/IP UNAPI related

NORAMHELP_S:	db	"*** No UNAPI RAM helper found.",13,10
                db  "    Install it with RAMHELPR.COM from www.konamiman.com"
                db  13,10,"$"
NOMSR_S:        db  "*** No mapper support routines found.",13,10
                db  "    Install it with MSR.COM from www.konamiman.com"
                db  13,10,"$"
TCPIP_S:	db	"TCP/IP",0
INLID_S:	db	"InterNestor Lite",0


;************************
;***                  ***
;***  UNINSTALLATION  ***
;***                  ***
;************************

PAR_SIM_U:
	ld	a,(IS_FILE)
	or	a
	jp	nz,NOFILE

	;--- Check that we can actually uninstall
	;    (no other page 3 resident code was installed after INL)

	ld	a,(SEG1)
	call	_PUT_P1

	ld	hl,H_TIMI
	ld	de,NEW_TIMI
	call	COMP_HOOK
	jr	nz,CANT_UNINST

	ld	hl,EXTBIO
	ld	de,NEW_EXTBIO
	call	COMP_HOOK
	jr	z,CAN_UNINST

CANT_UNINST:
	print	CANTUN_S
	jp	FIN
CAN_UNINST:

	;--- Uninitialize the Fossil driver

	if	LINK=0

	call	FOS_DEINIT

	endif

	;--- Restore the original timer interrupt hook

	di

	if	USETIMI=1

	di
	ld	hl,OLD_TIMI
	ld	de,H_TIMI
	ld	bc,5
	ldir

	endif

	;--- Restore original EXTBIO hook

	ld	hl,OLD_EXTBIO
	ld	de,EXTBIO
	ld	bc,5
	ldir

	ei

	;--- Free allocated segments

	ld	a,(#F344)
	ld	b,a
	ld	a,(RES_SEG1)
	call	_FRE_SEG
	ld	a,(#F344)
	ld	b,a
	ld	a,(RES_SEG2)
	call	_FRE_SEG

	;--- Show information and terminate

	print	OKUNINS_S
	jp	FIN

	;--- This subroutine compares the 5 bytes at (HL) and (DE), returns Z if same

COMP_HOOK:
	ld	a,(de)
	cp	(hl)
	ret	nz
	djnz	COMP_HOOK
	ret

	;--- Strings for uninstallation

CANTUN_S:	db	"*** Other resident programs were installed after InterNestor Lite.",13,10
		db	"    Uninstall these programs first, then retry uninstalling InterNestor Lite.",13,10,"$"
OKUNINS_S:	db	"InterNestor Lite has been uninstalled. Please come back later.",13,10,"$"


;***************************
;***  SIMPLE PARAMETERS  ***
;***************************

;These parameters are invoked as:
;INL.COM <parameter letter> <additional parameters>

	;================================
	;===  P: Pause and R: Resume  ===
	;================================

PAR_SIM_P:
	ld	b,#FF
	jr	PAR_SIM_PR

PAR_SIM_R:
	ld	b,0

PAR_SIM_PR:
	ld	a,(IS_FILE)
	or	a
	jp	nz,NOFILE

	ld	a,(SEG1)
	call	_PUT_P1

	ld	a,b
	ld	(PAUSED),a
	push	af
	print	HASBEEN_S
	pop	af
	or	a
	ld	c,_STROUT
	ld	de,PAUSED_S
	jr	nz,PARPR2
	ld	de,ACTIVATED_S
PARPR2:	call	DOS

	ld	a,2
	call	_PUT_P1

	jp	FIN

HASBEEN_S:	db	"InterNestor Lite has been $"
PAUSED_S:	db	"paused",13,10,"$"
ACTIVATED_S:	db	"activated",13,10,"$"


	;===================
	;===  S: Status  ===
	;===================

PAR_SIM_S:
	ld	a,(SEG1)
	call	_PUT_P1
	ld	a,(SEG2)
	call	_PUT_P2

	;--- Active or paused

	print	ISINS_S
	ld	a,(PAUSED)
	ld	c,_STROUT
	ld	de,ACTIVE_S
	or	a
	jr	z,PARSIMS_2
	ld	de,PAUSED2_S
PARSIMS_2:	call	DOS

	if	LINK=0

	;--- PPP connection status

	print	PPPIS_S
	ld	a,(PPP_STATE)
	ld	c,_STROUT
	ld	de,PPPS0_S
	or	a
	jr	z,PARSIMS_3
	ld	de,PPPS1_S
	dec	a
	jr	z,PARSIMS_3
	ld	de,PPPS2_S
	dec	a
	jr	z,PARSIMS_3
	ld	de,PPPS3_S
	dec	a
	jr	z,PARSIMS_3
	ld	de,PPPS4_S
	dec	a
	jr	z,PARSIMS_3
	ld	de,PPPSX_S
PARSIMS_3:	call	DOS

	;--- Last PPP close reason

	ld	a,(PPP_STATE)	;Do not show if PPP connection not closed
	or	a
	jr	nz,PARSIMS_4

	ld	a,(PPP_CLCODE)	;Do not show if close code is 0
	or	a
	jr	z,PARSIMS_4
	ld	b,a

	push	bc
	print	WASCLOSED_S
	pop	bc

	call	GET_REASON
	ld	c,_STROUT
	call	DOS
	print	TWONL_S
PARSIMS_4:	;

	endif

	if	LINK=1

	;--- Network status

	print	NETSTAT_S
	ld	a,TCPIP_NET_STATE
	call	CALL_UNAPI
	ld	a,b
	ld	c,_STROUT
	ld	de,NETSTAT0_S
	or	a
	jr	z,PARSIMS_3
	ld	de,NETSTAT1_S
	dec	a
	jr	z,PARSIMS_3
	ld	de,NETSTAT2_S
	dec	a
	jr	z,PARSIMS_3
	ld	de,NETSTAT3_S
	dec	a
	jr	z,PARSIMS_3
	ld	de,NETSTATX_S
PARSIMS_3:	call	DOS

	endif

	;--- IP addresses

	print	IPLOCIS_S
	ld	hl,(BUF_IPLOCAL)
	ld	de,(BUF_IPLOCAL+2)
	call	DO_PRINT_STRING

	if	LINK=0

	print	IPREMIS_S
	ld	hl,(BUF_IPREMOTE)
	ld	de,(BUF_IPREMOTE+2)
	call	DO_PRINT_STRING

	endif

	if	LINK=1

	print	SUBNET_S
	ld	hl,(SUBNET_MASK)
	ld	de,(SUBNET_MASK+2)
	call	DO_PRINT_STRING

	print	DEFGW_S
	ld	hl,(DEFGW)
	ld	de,(DEFGW+2)
	call	DO_PRINT_STRING

	endif

	print	IPDNS1IS_S
	ld	hl,(BUF_IPDNS1)
	ld	de,(BUF_IPDNS1+2)
	call	DO_PRINT_STRING

	print	IPDNS2IS_S
	ld	hl,(BUF_IPDNS2)
	ld	de,(BUF_IPDNS2+2)
	call	DO_PRINT_STRING

    ld de,IPSOCKS1_S
    or a
    call PRINT_SOCKS_INFO
    ld de,IPSOCKS2_S
    scf
    call PRINT_SOCKS_INFO

	;--- DHCP automaton state

	if	LINK=1

	ld	a,(DHCP_VECT)
	or	a
	jp	z,FIN

	print	DHCPSTAT_S
	ld	a,(DHCP_STATE)
	inc	a
	ld	b,a
	ld	de,DHCPSTATES_T
	call	GET_STRING
	ld	c,_STROUT
	call	DOS
	print	NEWLINE_S

	endif

	;--- End

	jp	FIN

DO_PRINT_STRING:
	ld	bc,IPBUF
	ld	a,INL_IP_STRING
	call	CALL_UNAPI
	ld	de,IPBUF
	jp	PRINTZ

PRINT_SOCKS_INFO:
    push af
    ld c,_STROUT
    call DOS
    pop af

    ld a,INL_GET_SOCKS_PROXY
    call CALL_UNAPI

    ld  a,h
    or l
    or e
    or d
    jr nz,SOCKS_INFO_PRESENT
    print NOTSET_S
    ret
SOCKS_INFO_PRESENT:

    push bc
    call	DO_PRINT_STRING
    print SOCKSPORT_S
    pop hl
    ld de,TEMPBUF
    call NUMTOASC
    ld de,TEMPBUF
    ld c,_STROUT
    call DOS

    ret


	;--- Strings

ISINS_S:	db	"InterNestor Lite is installed and $"
ACTIVE_S:	db	"ACTIVE",13,10,13,10,"$"
PAUSED2_S:	db	"PAUSED",13,10,13,10,"$"

	if	LINK=0

PPPIS_S:	db	"PPP connection state is: $"
PPPS0_S:	db	"CLOSED",13,10,13,10,"$"
PPPS1_S:	db	"Negotiating link parameters",13,10,13,10,"$"
PPPS2_S:	db	"Authenticating",13,10,13,10,"$"
PPPS3_S:	db	"Negotiating network parameters",13,10,13,10,"$"
PPPS4_S:	db	"OPEN",13,10,13,10,"$"
PPPSX_S:	db	"Unknown!"
TWONL_S:	db	13,10
NEWLINE_S:	db	13,10,"$"

	endif

	if	LINK=1

NETSTAT_S:	db	"Network state is: $"
NETSTAT0_S:	db	"OFF",13,10,13,10,"$"
NETSTAT1_S:	db	"Initializing",13,10,13,10,"$"
NETSTAT2_S:	db	"ON",13,10,13,10,"$"
NETSTAT3_S:	db	"Closing",13,10,13,10,"$"
NETSTATX_S:	db	"Unknown!"
TWONL_S:	db	13,10
NEWLINE_S:	db	13,10,"$"

	endif

IPLOCIS_S:	db	"Local IP address: $"

	if	LINK=0
IPREMIS_S:	db	13,10,"Remote IP address: $"
	endif

	if	LINK=1
SUBNET_S:	db	13,10,"Subnet mask: $"
DEFGW_S:	db	13,10,"Default gateway: $"
	endif

IPDNS1IS_S:	db	13,10,"Primary DNS address: $"
IPDNS2IS_S:	db	13,10,"Secondary DNS address: $"

IPSOCKS1_S: db  13,10,"Socks server (non-TLS): $"
IPSOCKS2_S: db  13,10,"Socks server (TLS): $"
SOCKSPORT_S: db ", port $"
NOTSET_S: db "Not set$"
OK_S: db "Ok",13,10,"$"

	if	LINK=1

DHCPSTAT_S:	db	13,10,10,"DHCP automaton state: $"

DHCPSTATES_T:	db	1,"INIT$"
	db	2,"SELECTING$"
	db	3,"REQUESTING$"
	db	4,"BOUND (network ready)$"
	db	5,"RENEWING$"
	db	6,"REBINDING$"
	db	7,"INFORMING$"
	db	8,"CONFIGURED (network ready)$"
	db	0

	endif

	if	LINK=0

WASCLOSED_S:	db	"The previous PPP connection was closed for the following reason:"
		db	13,10,"$"
REASONS_SS:	db	1,"The modem could not connect to the peer$"
		db	2,"User close request$"
		db	3,"Remote LCP close request$"
		db	4,"Remote IPCP close request$"
		db	5,"Authentication failed$"
		db	6,"Authentication requested with unknown method$"
		db	7,"Authentication requested but user name or password is empty$"
		db	8,"LCP negotiation timeout expired$"
		db	9,"Authentication process timeout expired$"
		db	10,"IPCP negotiation timeout expired$"
		db	11,"Local IP address unknown by us and by the peer$"
		db	12,"Remote IP address unknown by us and by the peer$"
		db	13,"LCP ",34,"Code Reject",34," packet received$"
		db	14,"LCP ",34,"Protocol Reject",34," packet received$"
		db	15,"IPCP ",34,"Code Reject",34," packet received$"
		db	16,"IPCP ",34,"Protocol Reject",34," packet received$"
		db	17,"Too many LCP echo requests sent without reply$"
		db	0

	endif

IPBUF:	ds	16


	;======================
	;===  V: Variables  ===
	;======================

PAR_SIM_V:
	ld	a,(SEG2)
	call	_PUT_P2

	if	LINK=0

	;--- Bauds

	print	BAUDRATE_S
	ld	hl,(#F3FE)
	ld	bc,20*3
	add	hl,bc
	ld	de,SIMV_CONT
	push	de
	jp	(hl)

SIMV_CONT:
	inc	hl
	inc	hl
	ld	a,(hl)	;A = Bauds code
	cp	12
	ld	de,REAUNK_S
	jr	nc,PRINTBAUD
	ld	b,a
	inc	b

	ld	de,7
	ld	hl,BAUD_TABLE-7
SIMV_BLOP:
	add	hl,de
	djnz	SIMV_BLOP
	ex	de,hl

PRINTBAUD:
	ld	c,_STROUT
	call	DOS
	print	NEWLINE_S

	endif

	;--- Other parameters

	ld	hl,VARS_TABLE

SIMV_LOOP:
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	a,d
	or	e

	if	LINK=0
	jp	z,FIN
	endif

	if	LINK=1
	jp	z,SIMV_OK1
	endif

	push	hl
	ld	c,_STROUT
	call	DOS
	pop	hl

	ld	a,(hl)	;A=Type of value
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)	;DE=Address of value
	inc	hl

	dec	a	;Type 1: byte
	jr	z,SIMV_1B
	dec	a	;Type 2: word
	jr	z,SIMV_2B
	dec	a	;Type 3: ON/OFF
	jr	z,SIMV_ONOFF

	;--- String (type 4)

	ld	a,(de)
	or	a
	jr	nz,NOEMPS
	ld	de,EMPTY_S
NOEMPS:	push	hl
	call	PRINTZ
	print	NEWLINE_S
	pop	hl
	jr	SIMV_LOOP

	;--- ON_OFF type

SIMV_ONOFF:
	ld	a,(de)
	or	a
	ld	de,ON_S
	jr		nz,SIMV2
	ld	de,OFF_S
SIMV2:	push	hl
	ld	c,_STROUT
	call	DOS
	pop	hl
	jr	SIMV_LOOP

	;--- Byte type

SIMV_1B:
	ld	a,(de)
	ld	e,a
	ld	d,0
	jr	SIMV_12B

	;--- Word type

SIMV_2B:
	ld	a,(de)
	ld	c,a
	inc	de
	ld	a,(de)
	ld	e,c
	ld	d,a

SIMV_12B:
	push	hl
	ld	hl,TEMPBUF
	ex	de,hl
	call	NUMTOASC
	print	TEMPBUF
	print	NEWLINE_S
	pop	hl
	jr	SIMV_LOOP

	if	LINK=1

	;--- ARP timeout

SIMV_OK1:
	print	VARARPT_S
	ld	de,(ARP_TOUT_SECS)
	ld	a,d
	or	e
	jr	z,SIMV_OK2

	print	MORE18_S
	jp	FIN
SIMV_OK2:

	ld	a,(ARP_TOUT_SECS+2)
	ld	h,a
	ld	a,(ARP_TOUT_SECS+3)
	ld	l,a
	ld	de,TEMPBUF
	call	NUMTOASC
	print	TEMPBUF
	print	SECONDS_S

	jp	FIN

	endif

	;--- Variables table

VARS_TABLE:
	dw	VARTTL_S
	db	1
	dw	TTL

	dw	VARTOS_S
	db	1
	dw	TOS

	dw	VARCHK_S
	db	1
	dw	CHKVECT

	dw	VARPSIZE_S
	db	2
	dw	PING_SIZE

	dw	VARPINGECHO_S
	db	3
	dw	REPLYECHO

	if	LINK=0

	dw	VARDIAL_S
	db	4
	dw	BUF_DIAL

	dw	VARMODREP_S
	db	4
	dw	BUF_MODREP

	dw	VARUSER_S
	db	4
	dw	BUF_PPPUSER

	dw	VARPASS_S
	db	4
	dw	BUF_PPPASSW

	dw	VARPPPVJ_S
	db	3
	dw	USEPPPVJ

	dw	VARNEGDNS_S
	db	3
	dw	NEGDNS

	dw	VARPPPECHO_S
	db	3
	dw	USEPPPECHO

	endif

	if	LINK=1

	dw	VARFTYPE_S
	db	3
	dw	FRAME_TYPE

	dw	VARCNET_S
	db	3
	dw	CHECK_NET

	dw	VARDHCP_S
	db	2
	dw	DHCP_VECT

	dw	VARDHCPO_S
	db	2
	dw	DHCP_VECT_O

	endif

	dw	0

	;--- Strings

EMPTY_S:	db	"(empty)",0
ON_S:	db	"ON",13,10,"$"
OFF_S:	db	"OFF",13,10,"$"

	if	LINK=0

BAUDRATE_S:	db	"RS232 baud rate: $"
VARDIAL_S:	db	"Number to be dialed by modem: $"
VARMODREP_S:	db	"Expected modem reply: $"
VARUSER_S:	db	"PPP user name: $"
VARPASS_S:	db	"PPP password: $"
VARPPPVJ_S:	db	"Negotiate Van Jacobson compression: $"
VARNEGDNS_S:	db	"Negotiate DNS addresses: $"
VARPINGECHO_S:	db	"Reply incoming PINGs (ICMP echo requests): $"
VARPPPECHO_S:	db	"Periodically send PPP echo requests: $"
VARTTL_S:	db	"TTL for outgoing datagrams: $"
VARTOS_S:	db	"TOS for outgoing datagrams: $"
VARCHK_S:	db	"Checksum calculations vector: $"
VARPSIZE_S:	db	"Size of outgoing PINGs in bytes (data part): $"

BAUD_TABLE:	db	"75    $"
		db	"300   $"
		db	"600   $"
		db	"1200  $"
		db	"2400  $"
		db	"4800  $"
		db	"9600  $"
		db	"19200 $"
		db	"38400 $"
		db	"57600 $"
		db	"115200$"
	db	"115200$"

	endif

	if	LINK=1

VARPINGECHO_S:	db	"Reply incoming PINGs (ICMP echo requests): $"
VARTTL_S:	db	"TTL for outgoing datagrams: $"
VARTOS_S:	db	"TOS for outgoing datagrams: $"
VARCHK_S:	db	"Checksum calculations vector: $"
VARPSIZE_S:	db	"Size of outgoing PINGs in bytes (data part): $"
VARFTYPE_S:	db	"Send frames with IEEE802.3 encapsulation: $"
VARCNET_S:	db	"Check network state every 10 seconds: $"
VARDHCP_S:	db	"Requested DHCP parameters vector: $"
VARDHCPO_S:	db	"Obtained DHCP parameters vector: $"

VARARPT_S:	db	"ARP cache timeout: $"
MORE18_S:	db	"more than 18 hours",13,10,"$"
SECONDS_S:	db	" seconds",13,10,"$"

	endif


	;==================
	;===  D: Reset  ===
	;==================

PAR_SIM_D:
	ld	a,(SEG2)
	call	_PUT_P2

	call	INIT_VARS

	if	LINK=0

	print	RESOK_S
	jp	FIN

RESOK_S:	db	"InterNestor Lite data area has been reset to default values",13,10,"$"

	endif

	if	LINK=1

	ld	a,(SEG1)
	call	_PUT_P1

	print	RESOK_S

	jp	RESET_INL	;FIN

RESOK_S:	db	"InterNestor Lite has been reset.",13,10,13,10,"$"

	endif


	;==========================
	;===  O: Optimizations  ===
	;==========================

PAR_SIM_O:
	ld	a,(SEG2)
	call	_PUT_P2

	ld	a,2
	ld	de,TEMPBUF+3
	call	EXTPAR
	jp	c,MISSPAR

	ld	a,1
	ld	hl,CHKVECT
	call	SET_PARAM
	jp	c,INVPAR

	print	PARSETOK_S
	jp	FIN


	;===============================
	;===  F: Configuration file  ===
	;===============================

PAR_SIM_F:
	ld	a,(IS_FILE)	;To avoid recursivity
	or	a
	jp	nz,NOFILE

	xor	a
	ld	(FCBS),a	;Needed for DOS 1

	;--- Extracts file name

	ld	a,2
	ld	de,TEMPBUF
	call	EXTPAR
	jr	nc,SIMF_OKFNAME

	;* Name not specified: in DOS 1 use simply INL.CFG,
	;  in DOS 2 use INL.CFG at the same directory as INL.COM

	ld	de,TEMPBUF
	ld	a,(DOS2)
	or	a
	jr	z,SIMF_SETNAME

	ld	hl,PROGRAM_S	;DOS 2: Obtain PROGRAM environment item...
	ld	de,TEMPBUF
	ld	b,128
	ld	c,_GENV
	call	5

	ld	de,TEMPBUF	;...and from there obtain pointer
	ld	bc,_PARSE	;to file name
	call	5
	ex	de,hl

SIMF_SETNAME:
	ld	hl,INLCFG_S
	ld	bc,8
	ldir
SIMF_OKFNAME:

	;--- Try to open file

	ld	de,TEMPBUF
	call	OPEN
	or	a
	jr	z,SIMF_OPENOK
	ld	b,a

	ld	a,(DOS2)	;Error in DOS 1: show "Can't open file"
	or	a
	jp	z,FNOTF

	ld	de,TEMPBUF
	ld	c,_EXPLAIN
	call	5
	print	AST_S
	ld	de,TEMPBUF
	call	PRINTZ
	ld	c,_TERM0	;Error in DOS 2: show appropriate error
	jp	5

SIMF_OPENOK:	ld	a,b
	ld	(FH),a

	;--- Set IS_FILE and jump to FIN,
	;    this will cause the first parameter to be processed

	ld	a,#FF
	ld	(IS_FILE),a
	jp	FIN


	if	LINK=0

;************************
;***  PPP PARAMETERS  ***
;************************

;These parameters are invoked as:
;INL.COM PPP <parameter letter> <additional parameters>

	;========================================
	;===  PPP M: Send a command to modem  ===
	;========================================

PAR_PPP_M:
	ld	a,(IS_FILE)
	or	a
	jp	nz,NOFILE

	ld	a,3
	ld	de,TEMPBUF
	call	EXTPAR
	jp	c,MISSPAR	;The command has been actually specified?

	ld	a,(SEG1)
	call	_PUT_P1

	print	SNDNG_S		;Print "Sending <command>..."
	ld	de,TEMPBUF
	call	PRINTZ
	print	PUNSUS_S

	ld	b,0	;Sends command
	ld	c,"$"
	ld	hl,TEMPBUF
	ld	de,TEMPBUF
	ld	a,INL_SEND_MODEM
	call	CALL_UNAPI

	print	REPLY_S	;Prints reply
	print	TEMPBUF
	print	NEWLINE_S

	jp	FIN

SNDNG_S:	db	"Sending $"
PUNSUS_S:	db	"...",13,10,"$"
REPLY_S:	db	"Reply: $"


	;====================================
	;===  PPP O: Open PPP connection  ===
	;====================================

PAR_PPP_O:
	ld	a,(IS_FILE)
	or	a
	jp	nz,NOFILE

	ld	a,(SEG1)
	call	_PUT_P1
	ld	a,(SEG2)
	call	_PUT_P2

	;--- Setup the appropriate parameters

	ld	a,3	;Start with 3rd parameter
PPP_O_LOP1:
	push	af
	ld	de,TEMPBUF
	call	EXTPAR
	pop	bc
	jr	c,PPP_O_LOPEND
	push	bc

	ld	a,(TEMPBUF)
	cp	"/"
	jp	c,INVPAR
	ld	a,(TEMPBUF+1)
	or	32
	cp	"i"
	jr	nz,PPPO_NOI

	ld	hl,0	;"/i" parameter
	ld	(BUF_IPLOCAL),hl
	ld	(BUF_IPLOCAL+2),hl
	ld	(BUF_IPREMOTE),hl
	ld	(BUF_IPREMOTE+2),hl
	ld	(BUF_IPDNS1),hl
	ld	(BUF_IPDNS1+2),hl
	ld	(BUF_IPDNS2),hl
	ld	(BUF_IPDNS2+2),hl

	ld	a,#FF
	ld	(NEGDNS),a
	jr	PPPO_NEXTP

PPPO_NOI:
	ld	a,(TEMPBUF+2)
	cp	":"
	jp	c,INVPAR

	ld	a,(TEMPBUF+1)
	or	32
	call	FIND_PARAM
	jp	c,INVPAR_S
	call	SET_PARAM
	jp	c,INVPAR_S

PPPO_NEXTP:
	pop	af
	inc	a
	jr	PPP_O_LOP1
PPP_O_LOPEND:

	call	SET_CONNECT	;In case an empty "/r:" was specified

	;--- If connection is already open, warn and terminate

	ld	a,(PPP_STATE)
	or	a
	jr	z,PPPOP_NOOP

	print	PPPISALR_S
	ld	a,(PPP_STATE)
	cp	4
	ld	de,OPEN2_S
	jr	z,PPPOP_YAOP
	ld	de,OPENING_S
PPPOP_YAOP:
	ld	c,_STROUT
	call	DOS
	jp	PPPOP_END
PPPOP_NOOP:	;

	;--- Dial number if necessary

	ld	a,(BUF_DIAL)
	or	a
	jr	z,PPPOP_NODIAL

	print	DIALING_S
	ld	de,BUF_DIAL
	call	PRINTZ
	print	PUNSUS_S

	ld	b,1
	ld	de,TEMPBUF
	ld	c,"$"
	ld	a,INL_SEND_MODEM
	call	CALL_UNAPI

	push	bc
	print	REPLY_S
	print	TEMPBUF
	print	NEWLINE_S

	pop	af
	cp	4
	jr	nz,PPPOP_ERROR
PPPOP_NODIAL:

	;--- Open connection and show progress

	ld	a,INL_PPP_OPEN
	call	CALL_UNAPI
	print	KEYEXIT_S
	ld	b,0

PPPOP_LOOP:
	ld	e,#FF	;Any key pressed?
	push	bc
	ld	c,_DIRIO
	call	DOS
	or	a
	pop	bc
	jp	nz,FIN

	ld	a,(PPP_STATE)
	or	a
	jr	z,PPPOP_ERROR	;If state returns to 0, an error occured

	cp	b
	jr	z,PPPOP_LOOP	;Waits until state changes
	ld	b,a

	ld	de,PPPTO1_S
	dec	a
	jr	z,PPPOP_LOP2
	ld	de,PPPTO2_S
	dec	a
	jr	z,PPPOP_LOP2
	ld	de,PPPTO3_S
	dec	a
	jr	z,PPPOP_LOP2
	ld	de,PPPTO4_S
	dec	a
	jr	z,PPPOP_LOP2
	ld	de,PPPTOX_S
PPPOP_LOP2:

	push	bc
	ld	c,_STROUT
	call	DOS
	pop	bc

	ld	a,b
	cp	4
	jr	nz,PPPOP_LOOP
	jr	PPPOP_END

	;--- Error When opening connection

PPPOP_ERROR:
	print	PPPOPERR_S
	ld	a,(PPP_CLCODE)
	ld	b,a
	call	GET_REASON
	ld	c,_STROUT
	call	DOS
	print	NEWLINE_S

	;--- End

PPPOP_END:	jp	FIN

	;--- Strings

PPPISALR_S:	db	"*** PPP connection is already $"
OPEN2_S:	db	"open",13,10,"$"
OPENING_S:	db	"opening",13,10,"$"
DIALING_S:	db	"- Dialing $"
KEYEXIT_S:	db	">>> Press any key to exit "
		db	"(connection will then be established in background)",13,10,13,10,"$"
PPPOPERR_S:	db	13,10,"*** Connection failed due to the following reason:",13,10,"$"
PPPTO1_S:	db	"- Negotiating link parameters...",13,10,"$"
PPPTO2_S:	db	"- Authenticating...",13,10,"$"
PPPTO3_S:	db	"- Negotiating network parameters...",13,10,"$"
PPPTO4_S:	db	13,10,"Connection established successfully",13,10,"$"
PPPTOX_S:	db	"* Unknown state reached!",13,10,"$"


	;=====================================
	;===  PPP C: Close PPP connection  ===
	;=====================================

PAR_PPP_C:
	ld	a,(IS_FILE)
	or	a
	jp	nz,NOFILE

	ld	a,(SEG1)
	call	_PUT_P1

	ld	a,INL_PPP_CLOSE
	call	CALL_UNAPI

	ld	a,2
	call	_PUT_P1

	print	CLOSED_S
	jp	FIN

CLOSED_S:	db	"PPP connection has been closed$"


	ld	a,(SEG2)
	call	_PUT_P2


	;======================
	;===  PPP B: Bauds  ===
	;======================

PAR_PPP_B:
	ld	a,3
	ld	de,TEMPBUF
	call	EXTPAR
	jp	c,MISSPAR

	ld	hl,TEMPBUF
	call	EXTNUM8
	jp	c,INVPAR
	cp	12
	jp	nc,INVPAR
	cp	10
	jr	nz,PPPB_2
	inc	a
PPPB_2:	;

	push	af
	print	PARSETOK_S
	pop	af

	ld	ix,(#F3FE)
	ld	bc,9	;IX = Fossil routine SetBaud
	add	ix,bc
	ld	h,a
	ld	l,a
	ld	de,FIN
	push	de
	jp	(ix)


	;============================
	;===  PPP N, R, U, P y E  ===
	;============================

PAR_PPP_N:
PAR_PPP_R:
PAR_PPP_U:
PAR_PPP_P:
PAR_PPP_E:
PAR_PPP_V:
	or	32	;To lower case
	jp	PAR_SETVAL


	;====================================
	;===  IP L, R, P, S, N, E, T y O  ===
	;====================================

PAR_IP_L:
PAR_IP_R:
PAR_IP_P:
PAR_IP_S:
PAR_IP_N:
PAR_IP_E:
PAR_IP_T:
PAR_IP_O:
PAR_IP_Z:
	and	223	;To upper case
	jp	PAR_SETVAL

	endif


;***********************
;***  IP PARAMETERS  ***
;***********************

;These parameters are invoked as:
;INL.COM IP <parameter letter> <additional parameters>

	;==============================
	;===  IP I: Initialize IPs  ===
	;==============================

PAR_IP_I:
	ld	a,(SEG2)
	call	_PUT_P2

	ld	hl,BUF_IPLOCAL
	ld	de,BUF_IPLOCAL+1
	ld	(hl),0
	ld	bc,15
	ldir

	if	LINK=0

	ld	a,#FF
	ld	(NEGDNS),a

	endif

	if	LINK=1

	ld	hl,SUBNET_MASK
	ld	de,SUBNET_MASK+1
	ld	(hl),0
	ld	bc,7
	ldir

	endif

	print	IPRESET_S
	jp	FIN

IPRESET_S:	db	"All IP addresses have been reset to 0.0.0.0",13,10,"$"


	if	LINK=1

	;======================================
	;===  IP L, P, S, N, E, T, O, G, M  ===
	;======================================

PAR_IP_L:
PAR_IP_P:
PAR_IP_S:
PAR_IP_N:
PAR_IP_E:
PAR_IP_T:
PAR_IP_O:
PAR_IP_Z:
PAR_IP_G:
PAR_IP_M:
PAR_IP_D:
	and	223	;To upper case
	jp	PAR_SETVAL

	endif


	;============================================================
	;===  Parameters that simply set a value in data segment  ===
	;============================================================

PAR_SETVAL:
	push	af
	xor	a
	ld	(TEMPBUF+3),a

	ld	a,(SEG2)
	call	_PUT_P2

	ld	a,3
	ld	de,TEMPBUF+3
	call	EXTPAR

	pop	af
	call	FIND_PARAM
	jp	c,INVPAR

	call	SET_PARAM
	jp	c,INVPAR

	print	PARSETOK_S

	if	LINK=0

	;--- If modem reply was set to empty string,
	;    set it to CONNECT

	call	SET_CONNECT

	endif

	jp	FIN

PARSETOK_S:	db	"The specified parameter has been modified",13,10,"$"

	if	LINK=0

	;--- This subroutine sets the modem reply to CONNECT
	;    if it is currently an empty string

SET_CONNECT:
	ld	a,(BUF_MODREP)
	or	a
	ret	nz

	ld	hl,CONN_S
	ld	de,BUF_MODREP
	ld	bc,8
	ldir

	ret

	endif


;************************
;***  DNS PARAMETERS  ***
;************************

;These parameters are invoked as:
;INL.COM DNS <parameter letter> <additional parameters>

	;====================================
	;===  DNS R: Resolve a host name  ===
	;====================================

	;--- Obtain the name to resolve,
	;    return error if not specified

PAR_DNS_R:
	ld	a,3
	ld	de,TEMPBUF
	call	EXTPAR
	jp	c,MISSPAR

	;--- Switch INL code segment and call DNS_Q

	ld	a,(SEG1)
	call	_PUT_P1

	print	RESOLVING_S

	ld	hl,TEMPBUF
	ld	b,0
	ld	a,TCPIP_DNS_Q
	call	CALL_UNAPI

	ld	b,a
	or	a
	jr	nz,DNSQ_ERR

	;--- Wait until the query finishes;
	;    if a key is pressed meanwhile, terminate

DNSQ_WAIT:
	ld	a,TCPIP_WAIT
	call	CALL_UNAPI
	ld	b,1
	ld	a,TCPIP_DNS_S
	call	CALL_UNAPI

	;* Error?

	or	a
	jr	nz,DNSR_ERR

	;* Query finished? Show results and terminate

	ld	a,b
	cp	2
	jr	nz,DNSQ_WAIT2

	push	hl,de
	print	RESOLVOK_S
	pop	de,hl
	call	DO_PRINT_STRING
	jp	FIN

	;* Check if a key was pressed

DNSQ_WAIT2:
	ld	e,#FF
	ld	c,_DIRIO
	call	5
	or	a
	jr	z,DNSQ_WAIT

	ld	a,TCPIP_DNS_Q	;If query has been cancelled,
	ld	b,1
	call	CALL_UNAPI	;abort query
	jp	FIN

	;--- Common error routine for DNS_Q and DNS_R
	;    Input: DE=Errors table, B=Error code

DNSQ_ERR:
	ld	de,DNSQERRS_T
	jr	DNSQR_ERR

DNSR_ERR:
	ld	de,DNSRERRS_T

DNSQR_ERR:
	push	de,bc

	;* Print "ERROR <code>: "

	ld	a,b
	ld	ix,RESOLVERRC_S
	call	BYTE2ASC
	ld	(ix),":"
	ld	(ix+1)," "
	ld	(ix+2),"$"
	print	RESOLVERR_S

	;* Obtain error string and print it

	pop	bc,de
	call	GET_STRING
	ld	c,_STROUT
	call	5

	jp	FIN

	;--- Strings

RESOLVING_S:	db	"Resolving host name...",13,10,"$"
RESOLVERR_S:	db	"ERROR "
RESOLVERRC_S:	ds	6	;Leave space for "<code>: $"
RESOLVOK_S:	db	"OK, host IP address is: $"

DNSQERRS_T:	db	ERR_NO_NETWORK,"No network connection$"
	db	ERR_NO_DNS,"No DNS servers available$"
	db	0

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


;************************
;***  TCP PARAMETERS  ***
;************************

;These parameters are invoked as:
;INL.COM TCP <parameter letter> <additional parameters>

	;============================================
	;===  TCP S: Show TCP connections status  ===
	;============================================

PAR_TCP_S:
	ld	a,(SEG1)
	call	_PUT_P1
	ld	a,(SEG2)
	call	_PUT_P2

	;* Check network connection

	if	LINK=0

	ld	a,(PPP_STATE)
	cp	4

	endif

	if	LINK=1

	ld	a,TCPIP_NET_STATE
	call	CALL_UNAPI
	ld	a,b
	cp	2

	endif

	jr	z,TCPS_OKINET
	print	TCPNOINET_S
	jp	FIN
TCPS_OKINET:

	;* Extract connection number if it was specified

	ld	a,3
	ld	de,TEMPBUF
	call	EXTPAR
	jr	nc,TCPS_ONE

	;* No connection number: loop for all connections

	ld	a,1
TCPS_LOOP:	push	af
	call	SHOW_TCP_INFO
	pop	af
	inc	a
	cp	5
	jr	c,TCPS_LOOP
	jp	FIN

	;* Show information about the specified connection,
	;  if the connection number specified is valid

TCPS_ONE:
	ld	a,(TEMPBUF+1)
	or	a
	jr	nz,TCPS_ERR

	ld	a,(TEMPBUF)
	sub	"0"
	or	a
	jr	z,TCPS_ERR
	cp	5
	jr	nc,TCPS_ERR

	call	SHOW_TCP_INFO
	jp	FIN

TCPS_ERR:
	print	INVTCPE_S
	jp	FIN


	;--- Subroutine to show information about connection A

SHOW_TCP_INFO:
	ld	(CONNUM),a
	add	"0"
	ld	(CONNUM2_S),a
	print	CONNUM_S

	;* Show state

	ld	a,(CONNUM)
	ld	b,a
	ld	hl,INFOBLOCK
	ld	a,TCPIP_TCP_STATE
	call	CALL_UNAPI
	or	a
	jr	z,TCPINFO_OK1
	ld	b,0
TCPINFO_OK1:

	ld	(TCB_POINTER),ix
	ld	a,c
	ld	(CLOSE_CAUSE),a
	ld	c,b	;C = State

	ld	de,TCPSTAT_T
	push	bc
	inc	b
	call	GET_STRING
	ld	c,_STROUT
	call	5
	print	NEWLINE_S

	pop	bc
	ld	a,b
	or	a
	jr	nz,TCP_NOCLOSED

	;* Connection closed: show reason and terminate

	print	CLCAUSE_S
	ld	de,TCPCLOSE_T
	ld	a,(CLOSE_CAUSE)
	ld	b,a
	call	GET_STRING
	ld	c,_STROUT
	call	5
	print	NEWLINE_S
	ret

	;* Connection open: show local port

TCP_NOCLOSED:
	ld	hl,(INFOBLOCK+6)
	ld	de,TEMPBUF
	call	NUMTOASC
	print	LOCPORT_S
	print	TEMPBUF
	print	NEWLINE_S

	;* Show remote port

	print	REMPORT_S
	ld	hl,(INFOBLOCK+4)
	ld	de,TEMPBUF
	call	NUMTOASC
	print	TEMPBUF
	print	NEWLINE_S

	;* Show remote IP

	print	REMIP_S
	ld	hl,(INFOBLOCK)
	ld	de,(INFOBLOCK+2)
	call	DO_PRINT_STRING
	print	NEWLINE_S

	ret

	;--- Variables

CLOSE_CAUSE:	db	0
CONNUM:	db	0
TCB_POINTER:	dw	0
INFOBLOCK:	ds	8

	;--- Strings

INVTCPE_S:	db	"*** Invalid TCP connection number$"
TCPNOINET_S:	db	"*** Not connected to Internet$"
CONNUM_S:	db	13,10,"> Connection "
CONNUM2_S:	db	"0 - State: $"
REMIP_S:	db	"  Remote IP: $"
REMPORT_S:	db	"  Remote port: $"
LOCPORT_S:	db	"  Local port: $"
CLCAUSE_S:	db	"  Close cause: $"


TCPSTAT_T:	db	1,"CLOSED$"
	db	2,"LISTEN$"
	db	3,"SYN-SENT$"
	db	4,"SYN-RECEIVED$"
	db	5,"ESTABLISHED$"
	db	6,"FIN-WAIT-1$"
	db	7,"FIN-WAIT-2$"
	db	8,"CLOSE-WAIT$"
	db	9,"CLOSING$"
	db	10,"LAST-ACK$"
	db	11,"TIME-WAIT$"
	db	0

TCPCLOSE_T:	db	1,"Connection never used$"
	db	2,"Local CLOSE call$"
	db	3,"Local ABORT call$"
	db	4,"Remote RST received$"
	db	5,"User timeout expired$"
	db	6,"Connection establishment timeout expired$"
	db	7,"Internet connection lost$"
	db	8,"Destination host unreachable$"
    db  128,"Malformed response from SOCKS server$"
    db  129,"SOCKS server requires authentication$"
    db  130,"SOCKS: server failure$"
    db  131,"SOCKS: connection not allowed by ruleset$"
    db  132,"SOCKS: network unreachable$"
    db  133,"SOCKS: host unreachable$"
    db  134,"SOCKS: host refused connection$"
    db  135,"SOCKS: TTL expired$"
	db	0


	;=============================================
	;===  TCP C/A: Close/Abort TCP connection  ===
	;=============================================


PAR_TCP_C:
	ld	a,TCPIP_TCP_CLOSE
	ld	de,TCP_CLOSED_S
	jr	PAR_TCP_CA

PAR_TCP_A:
	ld	a,TCPIP_TCP_ABORT
	ld	de,TCP_ABORTED_S


	;*** Common code for TCP C and TCP A
	;    Input: A = Routine to call, TCP_CLOSE or TCP_ABORT
	;           DE = "closed" or "aborted" string

PAR_TCP_CA:
	ld	(TCP_CA_RUT),a
	ld	(TCP_CA_STR),de

	ld	a,(SEG1)
	call	_PUT_P1

	;* Extract connection number

	ld	a,3	;Parameter exists?
	ld	de,TEMPBUF
	call	EXTPAR
	jp	c,MISSPAR

	ld	hl,TEMPBUF	;Is it a number?
	call	EXTNUM8
	jr	nc,TCPCA_OK1

	print	INVTCPE_S
	jp	FIN
TCPCA_OK1:

	;* Call the appropriate routine

	ld	b,a
	ld	a,(TCP_CA_RUT)
	call	CALL_UNAPI
	or	a
	jr	nz,TCPCA_ERR

	print	TCPCA_OK_S	;Print success string
	ld	de,(TCP_CA_STR)
	ld	c,_STROUT
	call	5
	jp	FIN
TCPCA_ERR:

	;* On error, print the appropriate error string

	print	TCPNOCONN_S
	jp	FIN

	;--- Variables

TCP_CA_RUT:	db	0
TCP_CA_STR:	dw	0

	;--- Strings

TCPCA_OK_S:	db	"The specified connection has been $"
TCP_CLOSED_S:	db	"closed.$"
TCP_ABORTED_S:	db	"aborted.$"

TCPNOCONN_S:	db	1,"*** Invalid TCP connection number or connection is closed",13,10,"$"


	;====================================
	;===  TCP X1/X2: Set SOCKS proxy  ===
	;====================================

PAR_TCP_X:
	ld  a,(TEMPBUF+1)
    sub "0"
    or a
    jp z,INVPAR
    cp 2+1
    jp nc,INVPAR
    ld (TCP_X_WHICH),a

    ld a,3  ;Extract server IP
    ld	de,TEMPBUF+3
    call EXTPAR
    jp c,MISSPAR
    ld a,(TEMPBUF+3)
    cp "0"
    jr nz,PAR_TCP_X_SET
    ld a,(TEMPBUF+4)
    or a
    ld hl,0
    ld de,0
    jr z,PAR_TCP_X_SET2 ;Just "0" passed: unset the address
PAR_TCP_X_SET:
    ld hl,TEMPBUF+3
    call PARSE_IP
    jp c,INVPAR

    ld a,4  ;Extract server port
    ld	de,TEMPBUF
    call EXTPAR
    jp c,MISSPAR
    ld hl,TEMPBUF
    call EXTNUM16
    jp c,INVPAR

    ;Parameters ok, do the thing

PAR_TCP_X_SET2:
	ld	a,(SEG1)
	call	_PUT_P1

    ld a,(TCP_X_WHICH)
    rrca
    ccf
    ld a,INL_SET_SOCKS_PROXY
    ld hl,(PARSED_IP)
    ld de,(PARSED_IP+2)
    call TCP_UNAPI_ENTRY    ;We can't use CALL_UNAPI from the config file at install time

    print PARSETOK_S

    jp FIN

TCP_X_WHICH: db 0


	if	LINK=1

;*****************************
;***  ETHERNET PARAMETERS  ***
;*****************************

;These parameters are invoked as:
;INL.COM ETH <parameter letter> <additional parameters>

	;======================================
	;===  ETH H: Show hardware address  ===
	;======================================

PAR_ETH_H:
	ld	a,(SEG1)
	call	_PUT_P1

	ld	a,ETH_GET_HWADD
	call	_EXEUNAPI
	ld	(ETH_H_BUF),hl
	ld	(ETH_H_BUF+2),de
	ld	(ETH_H_BUF+4),bc
	ld	hl,ETH_H_BUF
	ld	de,HWADD_BUF
	ld	b,1
	ld	a,INL_ETH2ASCII
	call	CALL_UNAPI

	print	HWADD_S
	jp	FIN

HWADD_S:	db	"Ethernet hardware address: "
HWADD_BUF:	ds	17
	db	13,10,"$"

ETH_H_BUF:	ds	6

	;=======================================================
	;===  ETH F: Set the frame type for outgoing frames  ===
	;=======================================================

PAR_ETH_F:
	ld	a,(SEG2)
	call	_PUT_P2

	ld	de,TEMPBUF
	ld	a,3
	call	EXTPAR
	jp	c,MISSPAR

	ld	hl,TEMPBUF
	call	EXTNUM8
	jp	c,INVPAR
	or	a
	jr	z,ETHH_OK
	cp	1
	jp	nz,INVPAR
	ld	a,#FF

ETHH_OK:
	ld	(FRAME_TYPE),a
	print	PARSETOK_S
	jp	FIN


	;=============================================================
	;===  ETH C: Set periodical network state check ON or OFF  ===
	;=============================================================

PAR_ETH_C:
	ld	a,(SEG2)
	call	_PUT_P2

	ld	de,TEMPBUF
	ld	a,3
	call	EXTPAR
	jp	c,MISSPAR

	ld	hl,TEMPBUF
	call	EXTNUM8
	jp	c,INVPAR
	or	a
	jr	z,ETHC_OK
	cp	1
	jp	nz,INVPAR
	ld	a,#FF

ETHC_OK:
	ld	(CHECK_NET),a
	print	PARSETOK_S
	jp	FIN


	;========================================
	;===  ETH R: Reset Ethernet hardware  ===
	;========================================

PAR_ETH_R:
	ld	a,(SEG1)
	call	_PUT_P1

	ld	a,ETH_RESET
	call	_EXEUNAPI
	ld	a,ETH_GET_HWADD
	call	_EXEUNAPI

	ld	(HWAD),hl
	ld	(HWAD+2),de
	ld	(HWAD+4),bc

	print	ETHRESET_S
	jp	FIN

ETHRESET_S:	db	"Ethernet harwdare has been reset.",13,10,"$"


;************************
;***  ARP PARAMETERS  ***
;************************

;These parameters are invoked as:
;INL.COM ARP <parameter letter> <additional parameters>

	;================================
	;===  ARP T: Set ARP timeout  ===
	;================================

PAR_ARP_T:
	ld	a,(SEG2)
	call	_PUT_P2

	;* Extract timeout value

	ld	a,3	;Parameter exists?
	ld	de,TEMPBUF
	call	EXTPAR
	jp	c,MISSPAR

	ld	hl,TEMPBUF
	call	EXTNUM
	jp	c,INVPAR
	ld	a,b
	ld	(ETHT_NUM+2),a
	or	c
	jp	z,INVPAR
	ld	a,c
	ld	(ETHT_NUM+3),a
	push	bc
	pop	hl

	ld	a,e
	or	#20
	cp	"s"
	jr	z,ETH_T_S
	cp	"m"
	jr	z,ETH_T_M
	cp	"h"
	jp	nz,INVPAR

	;--- Hours (up to 18)

ETH_T_H:
	ld	de,19
	call	COMP	;NC if HL<DE
	jp	c,INVPAR

	ld	ix,ETHT_NUM
	call	POR60_32	;Minutes
	call	POR60_32	;Seconds
	jr	ETH_T_S

	;--- Minutes (up to 1080)

ETH_T_M:
	ld	de,1081
	call	COMP
	jp	c,INVPAR

	ld	ix,ETHT_NUM
	call	POR60_32	;Seconds

	;--- Seconds

ETH_T_S:
	ld	hl,ETHT_NUM
	ld	de,ARP_TOUT_SECS
	ld	bc,4
	ldir

	ld	ix,ETHT_NUM
	call	POR60_32	;1/60 seconds
	ld	hl,ETHT_NUM
	ld	de,ARP_TOUT
	ld	bc,4
	ldir

	print	PARSETOK_S
	jp	FIN

ETHT_NUM:
	ds	4


	;===============================
	;===  ARP S: Show ARP cache  ===
	;===============================

PAR_ARP_S:
	ld	a,(SEG2)
	call	_PUT_P2
	ld	a,(SEG1)
	call	_PUT_P1

	print	ARPHEAD_S

	;--- Loop for all ARP entries

	ld	ix,ARP_CACHE
	ld	b,ARP_ENTRIES
ARPS_LOOP:
	push	bc

	;* Entry in use?

	ld	a,(ix)
	or	a
	jr	z,ARPS_NEXT

	;* Clear string buffer

	ld	hl,ARPIP_B
	ld	de,ARPIP_B+1
	ld	bc,18+24+7-1
	ld	(hl),32
	ldir

	;* Set IP address

	ld	l,(ix+7)
	ld	h,(ix+8)
	ld	e,(ix+9)
	ld	d,(ix+10)
	push	ix
	ld	bc,ARPIP_B
	call	DO_ROUS_IPSTRING
	pop	ix

	;* Set MAC, unless it is being resolved

	ld	a,(ix)
	cp	3
	jr	nz,NOARPRSLV

	ld	hl,RESOLVINGA_S
	ld	de,ARPHW_B
	ld	bc,11
	ldir
	jr	OK_ARPS_HW
NOARPRSLV:

	push	ix
	push	ix
	pop	hl
	inc	hl
	ld	b,1
	ld	de,ARPHW_B
	ld	a,INL_ETH2ASCII
	call	CALL_UNAPI
	pop	ix
OK_ARPS_HW:

	;* Set entry type

	ld	hl,STATIC_S
	ld	a,(ix)
	cp	1
	jr	z,OK_ARPS_TYPE
	ld	hl,DINAMIC_S
OK_ARPS_TYPE:	ld	de,ARPTYPE_B
	ld	bc,7
	ldir

	;* Print entry and loop to next one, if any

	print	ARPIP_B

ARPS_NEXT:
	ld	bc,16
	add	ix,bc
	pop	bc
	dec	b
	jp	nz,ARPS_LOOP

	jp	FIN

	;--- Strings

ARPHEAD_S:
	db	"IP address        Hardware address        Type",13,10
	db	"----------        ----------------        ----",13,10,"$"
ARPIP_B:	ds	18
ARPHW_B:	ds	24
ARPTYPE_B:	ds	7
	db	13,10,"$"
STATIC_S:	db	"static "
DINAMIC_S:	db	"dynamic"
RESOLVINGA_S:	db	"(resolving)"


	;================================
	;===  ARP C: Clear ARP cache  ===
	;================================

PAR_ARP_C:
	ld	a,(SEG2)
	call	_PUT_P2

	ld	hl,ARP_CACHE
	ld	de,ARP_CACHE+1
	ld	bc,ARP_ENTRIES*16-1
	ld	(hl),0
	ldir

	print	ARPCLEAR_S
	jp	FIN

ARPCLEAR_S:	db	"The ARP table has been cleared.",13,10,"$"


	;==============================
	;===  ARP A: Add ARP entry  ===
	;==============================

PAR_ARP_A:
	ld	a,(SEG2)
	call	_PUT_P2
	ld	a,(SEG1)
	call	_PUT_P1

	;* Extract parameters

	ld	a,3	;Extract IP address...
	ld	de,TEMPBUF
	call	EXTPAR
	jp	c,MISSPAR

	ld	hl,TEMPBUF	;...and parse it
	ld	b,2
	ld	a,TCPIP_DNS_Q
	call	CALL_UNAPI
	or	a
	jp	nz,INVPAR
	ld	(ARPA_IP),hl
	ld	(ARPA_IP+2),de

	ld	a,4	;Extract MAC address...
	ld	de,TEMPBUF
	call	EXTPAR
	jp	c,MISSPAR

	ld	hl,TEMPBUF	;...and parse it
	ld	a,INL_ASCII2ETH
	call	CALL_UNAPI
	or	a
	jp	nz,INVPAR
	ld	(ARPA_HW),hl
	ld	(ARPA_HW+2),de
	ld	(ARPA_HW+4),bc

	;--- First check if an ARP entry already exists for the given IP,
	;    in that case, update the existing entry

	ld	ix,ARP_CACHE
	ld	b,ARP_ENTRIES
ARPA_LOOP1:
	push	bc
	ld	a,(ix)
	or	a
	jr	z,ARPA_NEXT1

	push	ix	;IPs match?
	pop	hl
	ld	bc,7
	add	hl,bc
	ld	de,ARPA_IP
	call	EQUAL32
	jr	nz,ARPA_NEXT1

	push	ix
	pop	de
	ld	hl,ARPA_HW-1
	ld	bc,11
	ldir

	print	ARPAUP_S
	pop	bc
	jp	FIN

ARPA_NEXT1:
	ld	bc,16
	add	ix,bc
	pop	bc
	djnz	ARPA_LOOP1

	;--- Search for an unused entry

	ld	ix,ARP_CACHE
	ld	b,ARP_ENTRIES
	ld	h,0
	ld	de,0
ARPA_LOOP2:
	push	bc
	inc	h
	ld	a,(ix)
	or	a
	jr	nz,ARPA_NEXT2

	dec	h
	ld	a,d
	or	e
	jr	nz,ARPA_NEXT2
	push	ix
	pop	de
ARPA_NEXT2:
	ld	bc,16
	add	ix,bc
	pop	bc
	djnz	ARPA_LOOP2

	;>> Here, H contains the number of used entries
	;   and DE the address of the free entry if found.

	;* Show error if there are ARP_ENTRIES-2 entries in use
	;  (two entries are always reserved for dynamic resolution)

	ld	a,h
	cp	ARP_ENTRIES-2
	jr	c,ARPA_OK1

	print	ARPAFULL_S
	jp	FIN
ARPA_OK1:

	;* Add entry and terminate

	ld	hl,ARPA_HW-1
	ld	bc,11
	ldir

	print	ARPAADDED_S
	jp	FIN


	;--- Strings and buffers

ARPAUP_S:	db	"The ARP entry has been updated.",13,10,"$"
ARPAFULL_S:	db	"*** ERROR: The ARP cache is full.",13,10,"$"
ARPAADDED_S:	db	"The ARP entry has been added.",13,10,"$"
	db	1
ARPA_HW:	ds	6
ARPA_IP:	ds	4


	;=================================
	;===  ARP D: Delete ARP entry  ===
	;=================================

PAR_ARP_D:
	ld	a,(SEG2)
	call	_PUT_P2
	ld	a,(SEG1)
	call	_PUT_P1

	;* Extract parameter

	ld	a,3	;Exctract IP address...
	ld	de,TEMPBUF
	call	EXTPAR
	jp	c,MISSPAR

	ld	hl,TEMPBUF	;...and parse it
	ld	b,2
	ld	a,TCPIP_DNS_Q
	call	CALL_UNAPI
	or	a
	jp	nz,INVPAR
	ld	(ARPA_IP),hl
	ld	(ARPA_IP+2),de

	;* Searches the matching entry

	ld	ix,ARP_CACHE
	ld	b,ARP_ENTRIES
ARPD_LOOP1:	push	bc
	ld	a,(ix)
	or	a
	jr	z,ARPD_NEXT1

	push	ix	;IPs match?
	pop	hl
	ld	bc,7
	add	hl,bc
	ld	de,ARPA_IP
	call	EQUAL32
	jr	nz,ARPD_NEXT1

	ld	(ix),0	;Yes: delete entry and terminate
	print	ARPDELETED_S
	pop	bc
	jp	FIN

ARPD_NEXT1:
	ld	bc,16
	add	ix,bc
	pop	bc
	djnz	ARPD_LOOP1

	;* Not found

	print	ARPD_NOTF_S
	jp	FIN

	;--- Strings

ARPDELETED_S:	db	"The specified ARP entry has been deleted.",13,10,"$"
ARPD_NOTF_S:	db	"*** ERROR: ARP entry not found.",13,10,"$"


;****************************
;***  ROUTING PARAMETERS  ***
;****************************

;These parameters are invoked as:
;INL.COM ROU <parameter letter> <additional parameters>

	;===================================
	;===  ROU S: Show routing table  ===
	;===================================

PAR_ROU_S:
	ld	a,(SEG2)
	call	_PUT_P2
	ld	a,(SEG1)
	call	_PUT_P1

	print	ROUHEAD_S

	;--- Loop for all routing entries

	ld	ix,ROUTE_TABLE
	ld	b,ROUTE_ENTRIES
ROUS_LOOP:	push	bc

	;* Entry in use?

	ld	a,(ix)
	or	a
	jr	z,ROUS_NEXT

	;* Clear string buffer

	ld	hl,ROUNET_B
	ld	de,ROUNET_B+1
	ld	bc,20+20+20-1
	ld	(hl)," "
	ldir

	;* Set network IP

	ld	l,(ix+1)
	ld	h,(ix+2)
	ld	e,(ix+3)
	ld	d,(ix+4)
	push	ix
	ld	bc,ROUNET_B
	call	DO_ROUS_IPSTRING
	pop	ix

	;* Set network mask

	ld	l,(ix+5)
	ld	h,(ix+6)
	ld	e,(ix+7)
	ld	d,(ix+8)
	push	ix
	ld	bc,ROUMASK_B
	call	DO_ROUS_IPSTRING
	pop	ix

	;* Set router address

	ld	l,(ix+9)
	ld	h,(ix+10)
	ld	e,(ix+11)
	ld	d,(ix+12)
	push	ix
	ld	bc,ROUROU_B
	call	DO_ROUS_IPSTRING
	pop	ix

	;* Print entry and loop to the next one, if any

	print	ROUNET_B

ROUS_NEXT:
	ld	bc,16
	add	ix,bc
	pop	bc
	djnz	ROUS_LOOP

	jp	FIN

	;* Convert IP in HL,DE to string in BC, terminated buth space

DO_ROUS_IPSTRING:
	push	bc
	ld	a,INL_IP_STRING
	call	CALL_UNAPI
	pop	hl
	dec	hl
ZEROTOSPACE:
	inc	hl
	ld	a,(hl)
	or	a
	jr	nz,ZEROTOSPACE
	ld	(hl)," "
	ret

	;--- Strings

ROUHEAD_S:
	db	"Network             Mask                Router ",13,10
	db	"-------             ----                ------",13,10,"$"
ROUNET_B:	ds	20
ROUMASK_B:	ds	20
ROUROU_B:	ds	20
	db	13,10,"$"


	;========================================
	;===  ROU C: Clear the routing table  ===
	;========================================

PAR_ROU_C:
	ld	a,(SEG2)
	call	_PUT_P2

	ld	hl,ROUTE_TABLE
	ld	de,ROUTE_TABLE+1
	ld	bc,ROUTE_ENTRIES*16-1
	ld	(hl),0
	ldir

	print	ROUCLEAR_S
	jp	FIN

ROUCLEAR_S:	db	"The routing table has been cleared.",13,10,"$"


	;========================================
	;===  ROU A: Add a new routing entry  ===
	;========================================

PAR_ROU_A:
	ld	a,(SEG2)
	call	_PUT_P2
	ld	a,(SEG1)
	call	_PUT_P1

	;* Extract parameters

	ld	a,3	;Extract network address...
	ld	de,TEMPBUF
	call	EXTPAR
	jp	c,MISSPAR

	ld	hl,TEMPBUF	;...and parse it
	ld	b,2
	ld	a,TCPIP_DNS_Q
	call	CALL_UNAPI
	or	a
	jp	nz,INVPAR
	ld	(ROUA_NET),hl
	ld	(ROUA_NET+2),de

	ld	a,4	;Extract network mask...
	ld	de,TEMPBUF
	call	EXTPAR
	jp	c,MISSPAR

	ld	hl,TEMPBUF	;...and parse it
	ld	b,2
	ld	a,TCPIP_DNS_Q
	call	CALL_UNAPI
	or	a
	jp	nz,INVPAR
	ld	(ROUA_MASK),hl
	ld	(ROUA_MASK+2),de

	ld	a,5	;Extract router address...
	ld	de,TEMPBUF
	call	EXTPAR
	jp	c,MISSPAR

	ld	hl,TEMPBUF	;...and parse it
	ld	b,2
	ld	a,TCPIP_DNS_Q
	call	CALL_UNAPI
	or	a
	jp	nz,INVPAR
	ld	(ROUA_ROU),hl
	ld	(ROUA_ROU+2),de

	;--- First check if the entry exists,
	;    in that case update it

	ld	ix,ROUTE_TABLE
	ld	b,ROUTE_ENTRIES
ROUA_LOOP1:
	push	bc
	ld	a,(ix)
	or	a
	jr	z,ROUA_NEXT1

	push	ix	;IPs match?
	pop	hl
	inc	hl
	ld	de,ROUA_NET
	call	EQUAL64
	jr	nz,ROUA_NEXT1

	push	ix
	pop	de
	inc	de
	ld	hl,ROUA_NET
	ld	bc,12
	ldir

	print	ROUAUP_S
	pop	bc
	jp	FIN

ROUA_NEXT1:
	ld	bc,16
	add	ix,bc
	pop	bc
	djnz	ROUA_LOOP1

	;--- Search an unused entry

	ld	ix,ROUTE_TABLE
	ld	b,ROUTE_ENTRIES
ROUA_LOOP2:
	push	bc
	ld	a,(ix)
	or	a
	jr	nz,ROUA_NEXT2

	push	ix
	pop	de
	ld	hl,ROUA_NET-1
	ld	bc,13
	ldir

	print	ROUAADDED_S
	pop	bc
	jp	FIN

ROUA_NEXT2:
	ld	bc,16
	add	ix,bc
	pop	bc
	djnz	ROUA_LOOP2

	;* Table is full: warn and terminate

	print	ROUAFULL_S
	jp	FIN

	;--- Strings and buffers

ROUAUP_S:	db	"The routing entry has been updated.",13,10,"$"
ROUAFULL_S:	db	"*** ERROR: The routing table is full.",13,10,"$"
ROUAADDED_S:	db	"The routing entry has been added.",13,10,"$"
	db	1
ROUA_NET:	ds	4
ROUA_MASK:	ds	4
ROUA_ROU:	ds	4


	;=======================================
	;===  ROU D: Delete a routing entry  ===
	;=======================================

PAR_ROU_D:
	ld	a,(SEG2)
	call	_PUT_P2
	ld	a,(SEG1)
	call	_PUT_P1

	;* Extract parameters

	ld	a,3	;Extract network address...
	ld	de,TEMPBUF
	call	EXTPAR
	jp	c,MISSPAR

	ld	hl,TEMPBUF	;...and parse it
	ld	b,2
	ld	a,TCPIP_DNS_Q
	call	CALL_UNAPI
	or	a
	jp	nz,INVPAR
	ld	(ROUA_NET),hl
	ld	(ROUA_NET+2),de

	ld	a,4	;Extract network mask...
	ld	de,TEMPBUF
	call	EXTPAR
	jp	c,MISSPAR

	ld	hl,TEMPBUF	;...and parse it
	ld	b,2
	ld	a,TCPIP_DNS_Q
	call	CALL_UNAPI
	or	a
	jp	nz,INVPAR
	ld	(ROUA_MASK),hl
	ld	(ROUA_MASK+2),de

	;--- Check if the specified entry exists,
	;    in that case delete it

	ld	ix,ROUTE_TABLE
	ld	b,ROUTE_ENTRIES
ROUD_LOOP1:
	push	bc
	ld	a,(ix)
	or	a
	jr	z,ROUD_NEXT1

	push	ix	;IPs match?
	pop	hl
	inc	hl
	ld	de,ROUA_NET
	call	EQUAL64
	jr	nz,ROUD_NEXT1

	ld	(ix),0
	print	ROUDELETED_S
	pop	bc
	jp	FIN

ROUD_NEXT1:
	ld	bc,16
	add	ix,bc
	pop	bc
	dec	b
	jr	nz,ROUD_LOOP1

	;--- Entry not found

	print	ROUDNOTF_S
	jp	FIN

	;--- Strings

ROUDELETED_S:	db	"The specified routing entry has been deleted.",13,10,"$"
ROUDNOTF_S:	db	"*** ERROR: Routing entry not found.",13,10,"$"

	endif


;*********************
;***               ***
;***  SUBROUTINES  ***
;***               ***
;*********************

	if	LINK=1

;--- Execute an UNAPI routine
;    (this is for the transient code only;
;    for the code segment, UNAPI calling code
;    is generated at installation time)

_EXEUNAPI:
	push	af
	ld	ix,(_UN_ADDRESS)
	ld	a,ixh
	and	%10000000
	jr	z,EXEUNAP2

	pop	af
	jp	(ix)	;Direct call to page 3

EXEUNAP2:
	ld	a,(_UN_SEG)
	cp	#FF
	jr	nz,EXEUNAP3

	ld	iy,(_UN_SLOT-1)
	ld	ix,(_UN_ADDRESS)
	pop	af
	jp	CALSLT	;ROM call

EXEUNAP3:
	pop	af
	ld	ix,(_UN_RAMCALL)
	push	ix
	ld	iy,(_UN_SEG)
	ld	ix,(_UN_ADDRESS)	;RAM segment call
	ret


;--- Compare two 32 bit numbers at (HL) and (DE), return Z=1 if they are equal

EQUAL32:
	ld	b,4
EQUAL32L:
	ld	a,(de)
	cp	(hl)
	ret	nz
	inc	hl
	inc	de
	djnz	EQUAL32L
	ret

EQUAL64:
	call	EQUAL32
	ret	nz
	jp	EQUAL32

	endif


;--- Program termination.
;    If reading a configuration file, read next line and execute its associated code.

FIN:	ld	a,(IS_FILE)
	or	a
	jr	z,FIN_REAL

	;--- Reading file

	;* Read parameter

	call	READ_LINE
	ld	a,(#80)
	or	a
	jr	z,FIN_REAL	;Nothing could be read?

	;* Print parameter and jump to program start code,
	;  so that parameter is processed as if it came from command line

	ld	de,#82
	call	PRINTZ	;Print "<parameter>: "
	ld	e,":"
	ld	c,_CONOUT
	call	5
	ld	e," "
	ld	c,_CONOUT
	call	5

	ld	a,1
	ld	de,TEMPBUF
	call	EXTPAR

	jp	PROC_PARAMS

	;--- Actual program termination, or installation continuation

FIN_REAL:
	ld	a,(IS_FILE_INS)	;Reading INL.CFG during installation?
	or	a
	jr	z,FIN_REAL2
	print	NEWLINE_S
	jp	READINI_END
FIN_REAL2:

	ld	a,(#F342)
	ld	h,#40
	call	ENASLT

	ld	a,(DOS2)
	or	a
	ld	de,0
	ld	c,_DEFAB
	call	nz,5

	ld	a,(FH)
	cp	#FF
	ld	b,a
	call	nz,CLOSE

	ld	a,2
	call	_PUT_P1
	ld	a,1
	call	_PUT_P2
	ld	c,_TERM0
	jp	5


;--- Abort handler routine for DOS 2,
;    prevents aborting program with CTRL-STOP

AB_HANDLER:
	pop	hl
	ret


;--- PRINTZ: Print a zero terminated string, followed by a carriage return
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


;--- NAME: COMP
;      Compares HL and DE (16 bits, twos complement)
;    INPUT:   HL, DE = numbers to compare
;    OUTPUT:   C, NZ si if > DE
;              C,  Z si if = DE
;             NC, NZ si if < DE
;    MODIFIES: -

COMP:	call	_COMP16
	ccf
	ret

_COMP16:	ld	a,h
	sub	d
	ret	nz
	ld	a,l
	sub	e
	ret


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
;	Extracts a 8 bit number from a string
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


;--- NAME: EXTNUM16
;      Extracts a 16 bit number from a string
;    INPUT:    HL = ASCII string address
;    OUTPUT:   BC = number
;              Cy = 1 on error (number too big, or not zero-terminated)

;EXTNUM16:
;    call EXTNUM
;    ret c ;Not a 16 bit number
;    ld a,e
;    or a
;    ret z
;    scf ;Not zero terminated, or has more than 5 digits
;    ret


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


;--- NAME: EXTPAR
;      Extract a parameter from the command line
;    INPUT:   A  = Parameter index (starting at 1)
;             DE = Destination address for parameter
;    OUTPUT:  A  = Total number of parameters
;             CY = 1 -> Parameter does not exists
;                       B undefined, destination buffer unmodified
;             CY = 0 -> Parameter copied at address DE, zero terminated
;		B = Parameter length (not including terminating zero)
;    MODIFIES: -

EXTPAR:	or	a	;Terminate with error if A = 0
	scf
	ret	z

	ld	b,a
	ld	a,(#80)	;Terminate with error if no parameters available
	or	a
	scf
	ret	z
	ld	a,b

	push	af,hl
	ld	a,(#80)
	ld	c,a	;Put zero at the end of command line
	ld	b,0
	ld	hl,#81
	add	hl,bc
	ld	(hl),0
	pop	hl,af

	push	hl,de,ix
	ld	ix,0	;IXl: Number of parameters
	ld	ixh,a	;IXh: Parameter to be extracted
	ld	hl,#81

PASASPC:
	ld	a,(hl)	;Skip spaces
	or	a
	jr	z,ENDPNUM
	cp	" "
	inc	hl
	jr	z,PASASPC

	inc	ix
PASAPAR:	ld	a,(hl)	;Traverse parameter characters
	or	a
	jr	z,ENDPNUM
	cp	" "
	inc	hl
	jr	z,PASASPC
	jr	PASAPAR

ENDPNUM:
	ld	a,ixh	;Error if parameter index
	dec	a	;is larger that the number of parameters
	cp	ixl
	jr	nc,EXTPERR

	ld	hl,#81
	ld	b,1	;B = current parameter
PASAP2:	ld	a,(hl)	;Skip spaces until finding next parameter
	cp	" "
	inc	hl
	jr	z,PASAP2

	ld	a,ixh	;If it is the desired parameter, extract it.
	cp	B	;Otherwise...
	jr	z,PUTINDE0

	inc	B
PASAP3:	ld	a,(hl)	;...skip it and jump to PASAP2
	cp	" "
	inc	hl
	jr	nz,PASAP3
	jr	PASAP2

PUTINDE0:
	ld	b,0
	dec	hl
PUTINDE:
	inc	b
	ld	a,(hl)
	cp	" "
	jr	z,ENDPUT
	or	a
	jr	z,ENDPUT
	ld	(de),a	;Copy paramater to (DE)
	inc	de
	inc	hl
	jr	PUTINDE

ENDPUT:	xor	a
	ld	(de),a
	dec	b

	ld	a,ixl
	or	a
	jr	FINEXTP
EXTPERR:
	scf
FINEXTP:
	pop	ix,de,hl
	ret


;--- Convert a 8 bit number to an unterminated string
;    Input:  A  = Number
;            IX = Destination address
;    Output: IX points after the generated string
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


;--- Initialization of INL variables on data segment
;    (assumes data segment switched on page 2)

INIT_VARS:
	ld	hl,#8000	;First erase all space
	ld	de,#8001
	ld	bc,16384-1
	ld	(hl),0
	ldir

	;xor	a	;Set TCBs to blank (not necessary)
	;ld	(TCBS),a
	;ld	(TCBS+256),a
	;ld	(TCBS+2*256),a
	;ld	(TCBS+3*256),a

	ld	hl,64
	ld	(PING_SIZE),hl
	ld	a,64
	ld	(TTL),a	;TTL
	ld	a,31
	ld	(CHKVECT),a	;All checksums ON
	ld	a,#FF
	ld	(REPLYECHO),a	;Reply PINGs ON

	if	LINK=0

	ld	(NEGDNS),a	;Negotiate DNS ON
	ld	(USEPPPECHO),a	;Use PPP echo
	ld	(USEPPPVJ),a	;Use Van Jacobson compression
	ld	hl,#FFFF
	ld	(XCP_TTIMER),hl

	ld	hl,CONN_S	;Modem reply = CONNECT
	ld	de,BUF_MODREP
	ld	bc,8
	ldir

	ret

CONN_S:	db	"CONNECT",0

	endif

	if	LINK=1

	ld	(CHECK_NET),a	;Periodically check network status ON
	ld	hl,ARP_TOUT_DEF
	ld	de,ARP_TOUT
	ld	bc,4
	ldir
	ld	hl,ARP_TOUT_DEF2	;ARP timeout
	ld	de,ARP_TOUT_SECS
	ld	bc,4
	ldir

	ld	a,63		;Obtain all via DHCP
	ld	(DHCP_VECT),a

	ld	hl,60	;Wait 1 second
	ld	(NETSTAT_TIMER),hl

	ld	hl,(SYSTIMER)	;Initialize XID for DHCP with a random value
	ld	a,r
	xor	h
	ld	(DHCP_XID),a
	ld	a,r
	xor	l
	ld	(DHCP_XID+1),a
	ld	c,_GTIME
	call	DOS
	ld	a,r
	xor	l
	ld	(DHCP_XID+2),a
	ld	a,r
	xor	d
	ld	(DHCP_XID+3),a

	ret

ARP_TOUT_DEF:	db	#00,#00,#46,#50	;5 minutes * 60 secs * 60 ints
ARP_TOUT_DEF2:	db	#00,#00,#01,#2C	;5 minutes * 60 secs

	endif

	if	LINK=0

;--- Initialize Fossil driver

FOS_INIT:
	ld	hl,(#F3FE)
	inc	hl
	inc	hl
	inc	hl
	jp	(hl)

;--- Uninitialize Fossil driver

FOS_DEINIT:
	ld	hl,(#F3FE)
	ld	bc,6
	add	hl,bc
	jp	(hl)

	endif

	if	LINK=0

;--- GET_REASON: Returns in DE a pointer to the reason of the last
;    PPP connection close, or "unknown"

GET_REASON:	ld	de,REASONS_SS

	endif


;--- GET_STRING: Returns a string associated to a number, or "Unknown"
;    INPUT: DE = Pointer to the strings and numbers table, with this format:
;                db num1,"String1$"
;                db num2,"String2$"
;                ...
;                db 0
;             B = Number whose string is searched
;    OUTPUT:  DE = String associated to the specified number

GET_STRING:
	ld	a,(de)
	inc	de
	or	a	;Number not found: return "Unknown (number)"
	jr	nz,LOOP_REA2

	ld	a,b
	ld	ix,CODEUNK_S
	call	BYTE2ASC
	ld	(ix),")"
	ld	(ix+1),"$"
	ld	de,REAUNK_S
	ret

LOOP_REA2:
	cp	b	;Match found?
	ret	z

LOOP_REA3:
	ld	a,(de)	;No: loop to the next one
	inc	de
	cp	"$"
	jr	nz,LOOP_REA3
	jr	GET_STRING

REAUNK_S:	db	"Unknown ("
CODEUNK_S:	db	"000)$"


;--- FIND_PARAM: Returns information about a given simple parameter
;    INPUT:  A=Parameter letter
;    OUTPUT: A and HL ready to be passed to SET_PARAM
;            Cy=1 if parameter is not found

FIND_PARAM:
	;or	32
	ld	b,a
	ld	hl,PAR_LIST

FINDP_LOOP:
	ld	a,(hl)
	or	a
	scf
	ret	z

	cp	b
	inc	hl
	jr	z,FINDP_FOUND
	inc	hl
	inc	hl
	inc	hl
	jr	FINDP_LOOP

FINDP_FOUND:
	ld	a,(hl)
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,c

	or	a
	ret

	;--- Parameters list.
	;    IP parameters are stored as upper case
	;    and PPP parameter as lower case.

PAR_LIST:
	db	"E",1
	dw	REPLYECHO
	db	"P",4
	dw	BUF_IPDNS1
	db	"S",4
	dw	BUF_IPDNS2
	db	"T",1
	dw	TTL
	db	"O",1
	dw	TOS
	db	"L",4
	dw	BUF_IPLOCAL
	db	"Z",2
	dw	PING_SIZE

	if	LINK=0

	db	"N",1
	dw	NEGDNS
	db	"R",4
	dw	BUF_IPREMOTE

	db	"n",15
	dw	BUF_DIAL
	db	"r",15
	dw	BUF_MODREP
	db	"u",31
	dw	BUF_PPPUSER
	db	"p",31
	dw	BUF_PPPASSW
	db	"e",1
	dw	USEPPPECHO
	db	"v",1
	dw	USEPPPVJ

	endif

	if	LINK=1

	db	"G",4
	dw	DEFGW
	db	"M",4
	dw	SUBNET_MASK
	db	"D",2
	dw	DHCP_VECT

	endif

	db	0


;--- SET_PARAM: Sets the value of an INL parameter (on data segment)
;    with the value stored at TEMPBUF+3.
;    INPUT:  A=1 for byte parameter, 2 for word parameter, 4 for IP parameter
;            A=other: string parameter (the number is max length)
;            HL=Parameter address
;    OUTPUT: Cy=1 for invalid parameter
;    Assumes INL data segment switched on page 2

SET_PARAM:
	cp	1
	jr	z,SETPARAM_B
	cp	2
	jr	z,SETPARAM_W
	cp	4
	jr	z,SETPARAM_I

	;--- String: measure length

	ld	b,a	;Max length+1
	inc	b
	ld	c,-1	;Will contain the string length
	ld	de,TEMPBUF+2
MIDELON:
	inc	de
	inc	c
	ld	a,(de)
	or	a
	jr	nz,MIDELON

	ld	a,c	;Too long?
	cp	b
	ccf
	ret	c

	ld	b,0
	inc	bc	;To include terminating zero
	ex	de,hl
	ld	hl,TEMPBUF+3	;Set parameter value
	ldir

	or	a
	ret

	;--- 1 byte

SETPARAM_B:
	push	hl
	ld	hl,TEMPBUF+3
	call	EXTNUM8
	pop	hl
	ret	c

	ld	(hl),a
	or	a
	ret

	;--- 2 bytes

SETPARAM_W:
	push	hl
	ld	hl,TEMPBUF+3
	call	EXTNUM16
	pop	hl
	ret	c

	ld	(hl),c
	inc	hl
	ld	(hl),b
	or	a
	ret

	;--- IP address

SETPARAM_I:
	push	hl
	call	PARSE_IP
	pop	de
	ret	c

	ld	hl,PARSED_IP
	ld	bc,4
	ldir

	or	a
	ret



;--- PARSE_IP: Obtains an IP address from a string
;    INPUT:  Zero terminated string at TEMPBUF+3
;    OUTPUT: Cy=0 and IP at PARSED_IP, or Cy=1 if not a valid IP string

PARSE_IP:
	ld	hl,TEMPBUF+3
PARSE_IPL:
	ld	a,(hl)
	or	a
	jr	z,PARSE_IP2	;Appends a dot to ease parsing process
	inc	hl
	jr	PARSE_IPL
PARSE_IP2:
	ld	(hl),"."
	ld	(PARSE_IPDIR),hl

	ld	de,PARSED_IP
	ld	hl,TEMPBUF+3
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
PARSED_IP:	ds	4


;--- NUMTOASC: Converts a 16 bit unsigned value to an ASCII string,
;    terminating it with a "$" character
;    Input: HL = Number to convert
;           DE = Destination address for the string
;
;    This routine is a modification of one borrowed from:
;    http://map.tni.nl/sources/external/z80bits.html
;    (this one skips dummy zeros and adds "$" at the end)

NUMTOASC:
	;* HL=0 is a special case
	ld	a,h
	or	l
	jr	nz,n2anozero
	ex	de,hl
	ld	(hl),"0"
	inc	hl
	ld	(hl),"$"
	ret

n2anozero:
	;* Generate string
	push	de
	ld	de,n2abuf

	ld	bc,-10000
	call	Num1
	ld	bc,-1000
	call	Num1
	ld	bc,-100
	call	Num1
	ld	c,-10
	call	Num1
	ld	c,-1
	call	Num1

	;* Copy string to destination, skipping initial zeros
	pop	de
	ld	hl,n2abuf-1
n2acopy1:
	inc	hl
	ld	a,(hl)
	cp	"0"
	jr	z,n2acopy1
n2acopy2:
	ld	(de),a
	cp	"$"
	ret	z
	inc	de
	inc	hl
	ld	a,(hl)
	jr	n2acopy2

	;* Generate a single digit
Num1:	ld	a,'0'-1
Num2:	inc	a
	add	hl,bc
	jr	c,Num2
	sbc	hl,bc

	ld	(de),a
	inc	de
	ret

n2abuf:	db	"00000$"


;--- DOS 2 Mapper support routines
;    (direct mapper port access is provided for DOS 1)

_ALL_SEG:	ds	3
_FRE_SEG:	ds	3
_RD_SEG:	ds	3
_WR_SEG:	ds	3
_CAL_SEG:	ds	3
_CALLS:		ds	3
_PUT_PH:	ds	3
_GET_PH:	ds	3
_PUT_P0:	ds	3
_GET_P0:	ds	3
_PUT_P1:    ds  3
_GET_P1:    ds  3
_PUT_P2:    ds  3
_GET_P2:    ds  3
_PUT_P3:	ds	3
_GET_P3:	ds	3

	if	LINK=1

;--- POR60_32: In place multiplication of a 32 bit number by 60
;    INPUT: IX = Pointer to number (big-endian)

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

	;* Substracts (2) from (1)

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
	sbc	hl,de	;Uses carry from previous operation
	ld	(ix),h
	ld	(ix+1),l

	ret

	;* Generic routine to multiply (IX) by 2^B

MULT32B:
	ld	d,(ix)
	ld	e,(ix+1)
	ld	h,(ix+2)
	ld	l,(ix+3)

MULT32_LOP:
	add	hl,hl
	ex	de,hl
	adc	hl,hl
	ex	de,hl
	djnz	MULT32_LOP

	ld	(ix),d
	ld	(ix+1),e
	ld	(ix+2),h
	ld	(ix+3),l
	ret

NUMBUF:	ds	4

	endif


;--- Auxiliary routines for terminating printing an error string

MISSPAR:
	print	MISSPAR_S
	jp	FIN

INVPAR:	print	INVPAR_S
	jp	FIN

NOFILE:	print	NOFILE_S
	jp	FIN

FNOTF:	print	FNOTF_S
	jp	FIN


;--- Invoke the TCP/IP UNAPI entry point,
;    assuming INL code segment switched on page 1.
;    Address to call is set at UNAPI discovery time.

CALL_UNAPI:	jp	0

JP_HL:	jp	(hl)


;==============================
;===  Disk access routines  ===
;==============================

;--- READ_LINE: Reads a line of text from the open file whose handle is at (FH).
;               Puts the line at address #81 and its length at #80.
;    If nothing could be read, sets (#80)=0.

READ_LINE:
	xor	a
	ld	(#80),a
	ld	a," "
	ld	(#81),a

	;--- Skip initial spaces, tabs and CRLFs

RL_SKIPINIT:
	ld	hl,1	;Try to read a character
	ld	de,DUMMY
	ld	a,(FH)
	ld	b,a
	call	READ

	ld	a,h
	or	l	;Could be read?
	ret	z

	ld	a,(DUMMY)	;It was EOF?
	cp	#1A
	ret	z

	cp	" "
	jr	z,RL_SKIPINIT
	cp	9
	jr	z,RL_SKIPINIT
	cp	10
	jr	z,RL_SKIPINIT
	cp	13
	jr	z,RL_SKIPINIT
	cp	";"	;Comment: discard the entire line
	jr	z,RL_ISCOMM
	cp	"#"	;Comment
RL_ISCOMM:
	push	af
	call	z,SKIP_LINE
	pop	af
	jr	z,RL_SKIPINIT

	;--- A valid character has been read.
	;    Now read up to 125 more characters.

	ld	(#82),a	;Save the first valid character readed
	ld	b,2	;Includes initial space and the first readed character
	ld	de,#83
RL_LOOP:
	push	bc,de
	ld	hl,1
	ld	a,(FH)
	ld	b,a
	call	READ
	ld	a,b
	or	c
	pop	de,bc

	jr	z,RL_LOOP_END
	ld	a,(de)
	cp	#1A
	jr	z,RL_LOOP_END
	cp	13
	jr	z,RL_LOOP_END

	inc	de
	inc	b
	ld	a,b
	cp	126
	jr	c,RL_LOOP
	push	bc,de
	call	SKIP_LINE
	pop	de,bc

	;--- A complete line has been read

RL_LOOP_END:
	xor	a
	ld	(de),a
	ld	a,b
	inc	a
	ld	(#80),a	;Line length
	ret

	;--- Skip the whole line
	;    (comment or too long line)

SKIP_LINE:
	ld	hl,1
	ld	de,DUMMY
	ld	a,(FH)
	ld	b,a
	call	READ
	ld	a,b
	or	c
	ret	z

	ld	a,(DUMMY)
	cp	13
	ret	z
	cp	#1A
	ret	z
	jr	SKIP_LINE

DUMMY:	db	0


;--- NAME: TOUPPER
;      Converts a character to upper case
;    INPUT:   A = Character
;    OUTPUT:  A = Caracter upper cased if it was a letter,
;                 unmodified otherwise
;    MODIFIES: F

TOUPPER:
	cp	"a"
	ret	c
	cp	"z"+1
	ret	nc
	and	%11011111
	ret


;--- NAME: CONVNAME
;      Converts a file name from/to FCB format (used in DOS 1 only)
;      Does NOT check for inavlid characters in the file name
;    INPUT:    HL = Source string
;                   FCB format:    12 characters, without dot
;                                  (unused chars padded with spaces).
;                                  The first one is the drive number
;                                  (0: default, 1: A, 2: B, etc).
;                   Normal format: Zero terminated, up to 14 characters.
;                                  Begins with drive letter and ":"
;                                  if not the default drive.
;              DE = Destination string (same format as source)
;              Cy = 0 -> Convert normal format to FCB format
;              Cy = 1 -> Convert FCB format to normal format
;     OUTPUT:  B  = Destination string length
;                   FCB format: always 12
;                   Normal formato: does not include terminating zero
;     MODIFIES: AF, C

CONVNAME:
	push	de,hl
	jp	c,FCB2NOR
	xor	a
	ld	(EXTFLG),a
	jp	NOR2FCB
ENDCONV:
	pop	hl,de
	ret

	;--- Conversion from normal name to FCB name

NOR2FCB:
	push	de,hl,de	;Fill with spaces the destination name zone
	pop	hl
	inc	de
	ld	a," "
	ld	(hl),a
	ld	bc,11
	ldir
	pop	hl,de
	xor	a
	ld	(de),a	;Set drive to 0

	inc	hl	;Set drive number if drive letter has been specified
	ld	a,(hl)
	cp	":"
	jp	nz,NOUN1
	dec	hl
	ld	a,(hl)
	call	TOUPPER
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

	ld	a,(EXTFLG)	;If string end reached, do not process extension
	or	a
	jp	nz,ENDCONV
	ld	a,#FF
	ld	(EXTFLG),a
	ld	b,3	;Loop for the extension
	call	N2FBUC
	ld	b,12
	jp	ENDCONV

N2FBUC:	ld	a,(hl)	;Verbosely copy the first 8 or 3 characters,
	inc	hl	;until finding 0 (string end), a dot (name end), or an asterisk
	cp	"*"	;(which is translated into "?")
	jp	z,AFND1
	cp	"."
	jp	z,PFND1
	or	a
	jp	z,EFND1
	call	TOUPPER
	ld	(de),a
	inc	de
	djnz	N2FBUC

PASASOB:
	ld	a,(EXTFLG)	;Nothing to skip if we are processing extension
	or	a
	ret	nz

	ld	a,(hl)	;Skip characters after the 8th in the file name
	inc	hl
	or	a
	jp	z,EFND1
	cp	"."
	jp	nz,PASASOB
	ret

AFND1:	ld	a,"?"	;Fill with "?" until completing
AFND11:	ld	(DE),a	;8 or 3 characters
	inc	DE
	djnz	AFND11
	jp	PASASOB

PFND1:	ld	a,(EXTFLG)
	or	a
	jp	nz,EFND1
	ld	a,b
	cp	8	;If the dot is at the beginning,
	dec	hl	;assumes "*.<ext>"
	jp	z,AFND1
	inc	hl
	ld	a," "	;Fill with " " until completing
PFND11:	ld	(de),a	;8 or 3 characters
	inc	de
	djnz	PFND11
	ret

EFND1:	ld	a,1
	ld	(EXTFLG),a
	ret

EXTFLG:	db	0	;#FF when processing extension, 1 when string end reached

	;--- Conversion from FCB name to normal name

FCB2NOR:
	push	de
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
	ld	b,8	;Copy file name verbosely until 8 characters
F2NBUC:	ld	a,(hl)	;have been copied or a space is found...
	inc	hl
	cp	" "
	jp	z,SPFND
	ld	(de),a
	inc	de
	djnz	F2NBUC
	ld	a,"."
	ld	(de),a
	inc	de
	jp	F2NEXT

SPFND:	ld	a,"."	;...then put a dot and skip dummy spaces
	ld	(de),a	;until finding the extension.
	inc	de
SFBUC:	ld	a,(hl)
	inc	hl
	djnz	SFBUC
	dec	hl

F2NEXT:	ld	b,3	;Copy extension until 3 characters
F2NEX2:	ld	a,(hl)	;have been copied or a space is found.
	inc	hl
	cp	" "
	jp	z,F2NEND
	ld	(de),a
	inc	de
	djnz	F2NEX2

F2NEND:	dec	de	;If no extension, supress the dot.
	ld	a,(de)
	cp	"."
	jp	z,NOPUN
	inc	de
NOPUN:	xor	a
	ld	(de),a

	ex	de,hl	;Obtain string length.
	pop	de
	or	a
	sbc	hl,de
	ld	b,l
	jp	ENDCONV


;--- NAME: OPEN
;      Open a file
;    INPUT:   DE = Open a file
;    OUTPUT:  A  = 0 -> Success
;             A <> 0 -> Error code
;                       DOS 1: A=1 -> too many files open
;             B  = File handle
;    MODIFIES: F, C

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
OP1BUC1:
	ld	a,(hl)	;Search a free FCB
	or	a
	jp	z,FCBFND
	add	hl,de
	djnz	OP1BUC1
	ld	a,1
	jp	OP1END

FCBFND:	push	hl	;Clear FCB
	pop	de
	push	de
	inc	de
	ld	bc,37
	ld	(hl),0
	ldir

	pop	de
	inc	de
	pop	hl	;Copy file name to FCB
	or	a
	call	CONVNAME

	push	de
	ld	c,_FOPEN
	call	5
	pop	ix
	or	a	;Terminate in case of error
	jp	nz,OP1END

	ld	a,1
	ld	(ix+14),a	;Set "record size" to 1
	xor	a
	ld	(ix+15),a
	ld	(ix+33),a	;Set "random record" to 0
	ld	(ix+34),a
	ld	(ix+35),a
	ld	(ix+36),a

	ld	a,#FF	;Flag FCB as used
	ld	(ix-1),a

	ld	a,(NUMFILES)	;Increase the number of opened files
	inc	a
	ld	(NUMFILES),a	;Return file number (file handle simulation)
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
;      Close a file
;    INPUT:   B  = File handle
;    OUTPUT:  A  = 0 -> Success
;             A <> 0 -> Error
;    MODIFIES: F

CLOSE:	ld	a,(DOS2)
	or	a
	jp	nz,CLOSE2

	;--- CLOSE: DOS 1 version

CLOSE1:	ld	a,b	;Error if B>MAXFILES or B=0
	cp	MAXFILES+1
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
CL1BUC1:
	add	hl,de	;HL = Pointer to FCB for file B
	djnz	CL1BUC1

	ld	a,(hl)	;Error if file not open
	or	a
	ld	a,2
	jp	z,ENDCL1

	inc	hl
	ex	de,hl	;DE = Pointer to FCB
	push	de
	ld	c,_FCLOSE
	call	5
	pop	ix
	or	a
	jp	nz,ENDCL1

	ld	a,(NUMFILES)
	dec	a
	ld	(NUMFILES),a
	xor	a	;Flag FCB as free
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
;      Read from an open file
;    INPUT:   B  = File handle
;             DE = Destination address
;             HL = Number of bytes to read
;    OUTPUT:  A  = 0 -> Success
;             A <> 0 -> Error
;                       It is an error to not be able to read
;                       all the required bytes, that is,
;                       HL at input <> HL at output.
;                       This error has code 1, both in DOS 1 and DOS 2.
;             HL = Number of bytes readed
;    MODIFIES: F

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
;      Write to an open file
;    INPUT:   B  = File handle
;             DE = Source address
;             HL = Number of bytes to write
;    OUTPUT:  A  = 0 -> Success
;             A <> 0 -> Error
;                       It is an error to not be able to write
;                       all the required bytes, that is,
;                       HL at input <> HL at output.
;                       This error has code 1, both in DOS 1 and DOS 2.
;             HL = Number of bytes written
;    MODIFIES: F

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


;--- RW: Generic code for reading and writing a file
;    Input: same as READ/WRITE, and A=DOS function code

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
RW1BUC1:
	add	hl,de	;HL = Pointer to FCB for file B
	djnz	RW1BUC1
	ld	a,(hl)	;A = File status
	ex	(sp),hl
	push	hl

	or	a	;Error if file not open
	ld	a,2
	jp	z,ENDRW11

	pop	de
	ld	c,_SETDTA
	call	5
	pop	de,hl
	inc	de
	ld	a,(RWCODE)	;DOS function number
	ld	c,a
	call	5	;Invoke DOS function

ENDRW1:	pop	iy,ix,de,bc
	ret
ENDRW11:
	pop	bc,bc,bc
	jp	ENDRW1

	;--- RW: DOS 2 version

RW2:	push	bc,de,hl
	ld	a,(RWCODE)	;DOS function number
	ld	c,a
	call	5
	;ret

	pop	de
	or	a
	jp	nz,ENDRW2
	push	hl

	sbc	hl,de	;HL = readed bytes, DE = required bytes
	ld	a,h	;If HL=DE, success
	or	l	;If HL<>DE, error 1
	ld	a,0
	pop	hl
	jp	z,ENDRW2
	ld	a,1

ENDRW2:	pop	de,bc
	ret

RWCODE:	db	0	;DOS function number


;*** Strings

FNOTF_S:	db	"*** Cannot open the specified file",13,10,"$"
NOFILE_S:	db	"*** Cannot execute this command from a configuration file",13,10,"$"
DSKE_S:		db	"*** Disk error",13,10,"$"
AST_S:		db	"*** $"
INLCFG_S:	db	"INL.CFG",0
PROGRAM_S:	db	"PROGRAM",0

	if	LINK=1

UNAPIID_S:	db	"ETHERNET",0

	endif


;*******************
;***             ***
;***  VARIABLES  ***
;***             ***
;*******************

DOS2:		db	0	;0 under DOS 1, #FF under DOS 2
MAPPER_ROUTINES: db 0   ;0FFh if mapper support routines available
SEG1:		db	0	;Code segment number
SEG2:		db	0	;Data segment number
P3DIR:		dw	0	;Address of page 3 code
NEXTPAR:	db	0	;Next parameter to be extracted
IS_FILE:	db	0	;#FF if parsing a configuration file
IS_FILE_INS:	db	0	;idem, at installation time
RAMHELPER:	dw	0	;Address of UNAPI RAM helper
MAPTAB:		dw	0	;Address of UNAPI mappers table
MAPTAB_ENTRY_SIZE: db   0   ;Size of an entry in the mappers table:
                              ;- 8 in DOS 2 (mappers table provided by standard mapper support routines),
                              ;- 2 in DOS 1 (mappers table provided by the RAM helper)

	if	LINK=1

_UN_SEG:	db	0	;API segment number
_UN_SLOT:	db	0	;API slot number
_UN_ADDRESS:	dw	0	;API entry point
_UN_RAMCALL:	dw	0	;RAM helper address
_HWAD:		ds	6	;MAC address

	endif

UNKPAR_S:	db	"*** Unknown parameter",13,10,"$"
MISSPAR_S:	db	"*** Missing parameter(s)",13,10,"$"
INVPAR_S:	db	"*** Invalid parameter(s)",13,10,"$"

NUMFILES:	db	0	;Number of open files (DOS 1 only)
FH:		db	#FF	;Open file handle

TEMPBUF2:	ds	128

FCBS:

INL_CODE:
