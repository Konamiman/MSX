	;--- DenYoNet Ethernet UNAPI BIOS v1.5
	;    By Konamiman, 5/2011


;*******************
;***  CONSTANTS  ***
;*******************

DO_DEBUG:	equ	0

debug:	macro	@x

	if	DO_DEBUG<>0

	push	af,bc,de,hl,ix,iy
	ld	a,"("
	ld	iy,(#FCC0)
	ld	ix,#A2
	call	#1C
	ld	a,@x
	ld	iy,(#FCC0)
	ld	ix,#A2
	call	#1C
	ld	a,")"
	ld	iy,(#FCC0)
	ld	ix,#A2
	call	#1C
	pop	iy,ix,hl,de,bc,af

	endif

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
EXTBIO:	equ	0FFCAh
SLTWRK:	equ	0FD09h
ARG:	equ	0F847h
H_PHYD:	equ	0FFA7H

;--- API version and implementation version

API_V_P	equ	1
API_V_S	equ	1
ROM_V_P	equ	1
ROM_V_S	equ	5


;--- Maximum number of available standard and implementation-specific function numbers

;Must be 0 to 127
MAX_FN	equ	11

;Must be either zero (if no implementation-specific functions available), or 128 to 254
MAX_IMPFN	equ	0


;--- W5100 registers, 8000h based

;Common registers

WIZ_MR	equ	8000h
WIZ_GAR0	equ	8001h
WIZ_GAR1	equ	8002h
WIZ_GAR2	equ	8003h
WIZ_GAR3	equ	8004h
WIZ_SUBR0	equ	8005h
WIZ_SUBR1	equ	8006h
WIZ_SUBR2	equ	8007h
WIZ_SUBR3	equ	8008h
WIZ_SHAR0	equ	8009h
WIZ_SHAR1	equ	800Ah
WIZ_SHAR2	equ	800Bh
WIZ_SHAR3	equ	800Ch
WIZ_SHAR4	equ	800Dh
WIZ_SHAR5	equ	800Eh
WIZ_IMR		equ 	8016h
WIZ_RMSR	equ	801Ah
WIZ_TMSR	equ	801Bh

;Socket 0 registers

WIZ_S0_MR	equ	8400h
WIZ_S0_CR	equ	8401h
WIZ_S0_IR	equ	8402h
WIZ_S0_SR	equ	8403h
WIZ_S0_DHAR0	equ	8006h
WIZ_S0_DHAR1	equ	8007h
WIZ_S0_DHAR2	equ	8008h
WIZ_S0_DHAR3	equ	8009h
WIZ_S0_DHAR4	equ	800Ah
WIZ_S0_DHAR5	equ	800Bh
WIZ_S0_TX_FSR0	equ	8420h
WIZ_S0_TX_FSR1	equ	8421h
WIZ_S0_TX_RD0	equ	8422h
WIZ_S0_TX_RD1	equ	8423h
WIZ_S0_TX_WR0	equ	8424h
WIZ_S0_TX_WR1	equ	8425h
WIZ_S0_RX_RSR0	equ	8426h
WIZ_S0_RX_RSR1	equ	8427h
WIZ_S0_RX_RD0	equ	8428h
WIZ_S0_RX_RD1	equ	8429h


;--- W5100 commands

CMD_OPEN	equ	01h
CMD_CLOSE	equ	10h
CMD_SEND	equ	20h
CMD_RECV	equ	40h


;--- W5100 socket status register values

SOCK_CLOSED	equ	00h
SOCK_MACRAW	equ	42h


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


;********************************************
;***  ROM HEADER AND INITIALIZATION CODE  ***
;********************************************

	org	04000h

	;--- ROM header

	db	"AB"
	dw	INIT
	ds	12

	;--- Default MAC

DEF_MAC:
	;db	#00,#21,#70,#6F,#91,#01
	db	#58,#53,#4D,0,1,1

INIT:

	;--- Do nothing if ESC is pressed

	ld	a,7
	call	SNSMAT
	and	4
	ret	z

	;--- Initialize EXTBIO hook if necessary

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

	;--- Save previous EXTBIO hook

	call	GETSLTP1
	call	GETWRK
	ex	de,hl
	ld	hl,EXTBIO
	ld	bc,5
	ldir

	;--- Patch EXTBIO hook

	di
	ld	a,0F7h	;code for "RST 030"
	ld	(EXTBIO),a
	call	GETSLTP1
	ld	(EXTBIO+1),a
	ld	hl,DO_EXTBIO
	ld	(EXTBIO+2),hl
	ei

	;>>> UNAPI initialization finished, now perform
	;    other ROM initialization tasks.

ROM_INIT:
	;--- Show informative message

	ld	hl,INITMSG
PRINT_LOOP:
	ld	a,(hl)
	or	a
	jp	z,INIT2
	call	CHPUT
	inc	hl
	jr	PRINT_LOOP
INIT2:
	;--- Setup hardware

	call	GETSLTP1
	ld	h,#80
	call	ENASLT

	;Reset hardware

	call	DO_RESET

	;Set MAC address to default value

	ld	hl,(DEF_MAC)
	ld	de,(DEF_MAC+2)
	ld	bc,(DEF_MAC+4)
	call	SET_MAC

	;Hide W5100 registers.
	;Without this, the W5100 is reset again and MAC address is lost.
	;Probably the MSX startup code messes with the
	;W5100 memory thinking that it is standard RAM.

	call	SET_WIZ_BUF2

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
FN_0:	dw	ETH_GETINFO
FN_1:	dw	ETH_RESET
FN_2:	dw	ETH_GET_HWADD
FN_3:	dw	ETH_GET_NETSTAT
FN_4:	dw	ETH_NET_ONOFF
FN_5:	dw	ETH_DUPLEX
FN_6:	dw	ETH_FILTERS
FN_7:	dw	ETH_IN_STATUS
FN_8:	dw	ETH_GET_FRAME
FN_9:	dw	ETH_SEND_FRAME
FN_10:	dw	ETH_OUT_STATUS
FN_11:	dw	ETH_SET_HWADD

;--- Implementation-specific routines addresses table

IMPFN_TABLE:
;FN_128:	dw	...


;************************
;***  FUNCTIONS CODE  ***
;************************

;--- Mandatory routine 0: return API information
;    Input:  A  = 0
;    Output: HL = Descriptive string for this implementation, on this slot, zero terminated
;            DE = API version supported, D.E
;            BC = This implementation version, B.C.
;            A  = 0 and Cy = 0

ETH_GETINFO:
	ld	bc,256*ROM_V_P+ROM_V_S
	ld	de,256*API_V_P+API_V_S
	ld	hl,APIINFO
	xor	a
	ret


;--- ETH_RESET: Reset hardware
;    Input:  A  = 1
;    Output: -

ETH_RESET:	;debug   "1"
	call	SETSLOTP2
	call	DO_RESET
	call	RESTSLOTP2
	ret

DO_RESET:
	call	SET_WIZ_REGS2

	;Save current MAC

	ld	ix,WIZ_SHAR0
	ld	l,(ix)
	ld	h,(ix+1)
	ld	e,(ix+2)
	ld	d,(ix+3)
	ld	c,(ix+4)
	ld	b,(ix+5)
	push	hl,de,bc

	;Set mode register to 10000000b
	;(do reset, ping disabled, PPPoE disabled,
	; auto-increment disabled, indirect bus I/F mode disabled)

	ld	a,10010000b
	ld	(WIZ_MR),a
WAIT_RESET:
	ld	a,(WIZ_MR)
	and	10000000b
	jr	nz,WAIT_RESET

	;Restore MAC

	pop	bc,de,hl
	call	SET_MAC

	;Set socket 0 to use 8K for RX and 8K for TX
	;(using all the available buffer)

	ld	a,3
	ld	(WIZ_RMSR),a
	ld	(WIZ_TMSR),a

	;Clear the last send status cache byte

	call	GETWRK
	push	hl
	pop	ix
	ld	(ix+7),0

	;Clear socket 0 interrupts

	ld	a,#FF
	ld	(WIZ_S0_IR),a

	;Open socket 0

	jp	OPEN_S0


;--- ETH_GET_HWADD: Get hardware address
;    Input:  A  = 2
;    Output: L-H-E-D-C-B = Ethernet address

ETH_GET_HWADD:	;debug   "2"
	call	SETSLOTP2
	call	SET_WIZ_REGS2

	ld	ix,WIZ_SHAR0
	ld	l,(ix)
	ld	h,(ix+1)
	ld	e,(ix+2)
	ld	d,(ix+3)
	ld	c,(ix+4)
	ld	b,(ix+5)

	exx
	call	RESTSLOTP2
	exx
	ret


;--- ETH_GET_NETSTAT: Obtain network connection status
;    Input:  A  = 3
;    Output: A  = 0 if NOT connected to an active network
;                 1 if connected to an active network

ETH_GET_NETSTAT:	;debug   "3"
	in	a,(WIZ_LEDS)
	rlca
	rlca
	rlca
	or	%11111110
	cpl
	ret


;--- ETH_NET_ONOFF: Enable or disable networking
;    Input:  A = 4
;            B = 0: Obtain current state only
;                1: Enable networking
;                2: Disable networking
;    Output: A = State after routine execution:
;                1: Networking is enabled
;                2: Networking is disabled

ETH_NET_ONOFF:	;debug   "4"
	exx
	call	SETSLOTP2
	call	SET_WIZ_REGS2
	exx

	ld	hl,ET_ONOFF_END
	push	hl

	ld	a,b
	dec	a
	jp	z,OPEN_S0
	dec	a
	jp	z,CLOSE_S0

	;Get status if B=0 or has invalid value

	ld	a,(WIZ_S0_SR)
	cp	SOCK_MACRAW
	ld	a,1
	ret	z
	inc	a
	ret

ET_ONOFF_END:
	ex	af,af
	call	RESTSLOTP2
	ex	af,af
	ret


;--- ETH_DUPLEX: Configure duplex mode
;    Input:  A = 5
;            B = 0: Obtain current mode only
;                1: Set half-duplex mode
;                2: Set full-duplex mode
;    Output: A = Mode after routine execution:
;                1: Currently half-duplex mode set
;                2: Currently full-duplex mode set
;                3: Current mode unknown or duplex mode does not apply

ETH_DUPLEX:	;debug   "5"
	;We ignore B since setting the mode is not supported

	in	a,(WIZ_LEDS)
	and	00001000b
	ld	a,1
	ret	nz
	inc	a
	ret


;--- ETH_FILTERS: Configure frame reception filters
;    Input:   A = 6
;             B = Filter bitmask:
;                 Bit 7: Set to return current configuration only
;                 Bit 6: Reserved
;                 Bit 5: Reserved
;                 Bit 4: Set to enable promiscuous mode, reset do disable it
;                 Bit 3: Reserved
;                 Bit 2: Set to accept broadcast frames,
;                        reset to reject them
;                 Bit 1: Set to accept small frames (smaller than 64 bytes),
;                        reset to reject them
;                 Bit 0: Reserved
;    Output: A = Filter configuration after execution
;                (bitmask with same format as B at input)

ETH_FILTERS:
	;Changing the filters is not supported by W5100

	ld	a,00000110b
	ret


;--- ETH_IN_STATUS: Check for received frames availability
;    Input:  A = 7
;    Output: A = 0: No received frames available
;                1: At least one received frame is available
;            When A=1:
;                BC = Size of the oldest available frame
;                HL = Bytes 12 and 13 of the oldest available frame

ETH_IN_STATUS:	;debug   "7"
	call	SETSLOTP2
	call	SET_WIZ_REGS2

	;Get received size, terminate if it is zero

	ld	a,(WIZ_S0_RX_RSR0)
	ld	b,a
	ld	a,(WIZ_S0_RX_RSR1)
	ld	c,a	;BC = Frame size
	or	b
	jr	nz,INSTAT_NEXT

	call	RESTSLOTP2
	xor	a
	ret
INSTAT_NEXT:

	;Calculate the frame start address as:
	;gS0_RC_BASE + (S0_RX_RD and gS0_RX_MASK), that is:
	;A000h + (S0_RX_RD and 1FFFh)

	ld	a,(WIZ_S0_RX_RD0)
	and	1Fh
	or	0A0h
	ld	h,a
	ld	a,(WIZ_S0_RX_RD1)
	ld	l,a	;HL = Frame address

	call	SET_WIZ_BUF2

	;Read frame header (two bytes containing size,
	;including header itself)

	ld	b,(hl)
	inc	hl
	res	6,h
	set	5,h
	ld	c,(hl)
	dec	bc
	dec	bc

	;Now read bytes 12 and 13 of the frame.
	;To handle the circular buffer, it is enough
	;to calculate the desired address normally
	;and then ensure that its three high bits are 101.

	ld	de,12+1
	add	hl,de
	ld	a,(hl)
	inc	hl
	res	6,h
	set	5,h
	ld	l,(hl)
	ld	h,a

	call	SET_WIZ_REGS2
	exx
	call	RESTSLOTP2
	exx
	ld	a,1
	ret


;--- ETH_GET_FRAME: Retrieve the oldest received frame
;    Input:  A  = 8
;            HL = Destination address for the frame, or
;                 0 to discard the frame
;    Output: A  = 0 if frame has been retrieved or discarded
;                 1 if no received frames are available
;            BC = Size of the retrieved frame

ETH_GET_FRAME:	;debug   "8"
	exx
	call	SETSLOTP2
	call	SET_WIZ_REGS2
	exx

	;Wait if W5100 is busy

	;debug   "1"
	call	WAIT_WIZ_BUSY
	;debug   "2"

	;Get recived size, terminate if it is zero

	ld	a,(WIZ_S0_RX_RSR0)
	ld	b,a
	ld	a,(WIZ_S0_RX_RSR1)
	ld	c,a	;BC = Frame size
	or	b
	jr	nz,GETFRAME_NEXT

	call	RESTSLOTP2
	ld	a,1
	ld	bc,0
	ret
GETFRAME_NEXT:
	;Calculate the frame start address as:
	;gS0_RC_BASE + (S0_RX_RD and gS0_RX_MASK), that is:
	;A000h + (S0_RX_RD and 1FFFh)

	ld	a,(WIZ_S0_RX_RD0)
	and	1Fh
	or	0A0h
	ld	d,a
	ld	a,(WIZ_S0_RX_RD1)
	ld	e,a	;DE = Frame address

	call	SET_WIZ_BUF2

	;Read frame header (two bytes containing size,
	;including header itself)

	ex	de,hl
	ld	b,(hl)
	inc	hl
	res	6,h
	set	5,h
	ld	c,(hl)
	inc	hl
	ex	de,hl
	dec	bc
	dec	bc	;Discount header size

	;Start reading frame data

	ld	a,h	;Discard frame?
	or	l
	jp	z,GETFRAME_END

	res	6,d
	set	5,d	;Account for circular buffer

	call	SET_WIZ_BUF2
	ex	de,hl

	;At this point we have:
	;HL = Source address, W5100 RAM
	;DE = Destination address, MSX RAM
	;BC = Frame size

	;How we transfer the frame to user space
	;depends on the destination address:
	;If it is in page 0 or 3, we can do direct transfer.
	;If it is in page 2, we need to do page 3 buffering
	;(if disk system is available) or inter-slot write (if not).

	ld	a,d
	and	11000000b
	cp	80h
	jr	z,GETFRAME_INDIR

	;>>> Get frame, direct transfer <<<

GETFRAME_DIR:
	call	WIZ_TO_MSX
	jp	GETFRAME_END

GETFRAME_INDIR:
	ld	a,(H_PHYD)
	cp	#C9	;mnemonic for RET
	jr	nz,GETFRAME_BUFP3

	;>>> Get frame, using inter-slot write <<<

	pop	af
	push	bc
	push	af

GETFRAME_RDSLT:
	pop	af	;Retrieve slot number (set by SETSLOTP2)
	push	af

	res	6,h	;Account for circular buffer (A000h-BFFFh)
	set	5,h

	push	hl,bc,de
	ld	e,(hl)
	pop	hl
	push	hl
	call	WRSLT
	pop	de,bc,hl

	inc	hl
	inc	de
	dec	bc
	ld	a,b
	or	c
	jr	nz,GETFRAME_RDSLT

	ei
	pop	af
	pop	bc
	push	af
	jp	GETFRAME_END

	;>>> Get frame, buffering in page 3 <<<

GETFRAME_BUFP3:
	exx
	call	RESTSLOTP2
	call	GETSLTP1
	ld	ixh,a	;IXh=Our slot
	call	GETSLTP2
	ld	ixl,a	;IXl=MSX RAM slot
	exx

	push	bc

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
	call	WIZ_TO_MSX
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
	call	WIZ_TO_MSX	;...copy the remaining bytes bytes to page 3...

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

	pop	bc
	exx
	call	SETSLOTP2
	exx

	;>>> Transfer done, now update S0_RX_RD and perform RECV command <<<

GETFRAME_END:
	call	SET_WIZ_REGS2
	ld	a,(WIZ_S0_RX_RD0)
	ld	h,a
	ld	a,(WIZ_S0_RX_RD1)
	ld	l,a
	add	hl,bc	;Add frame size
	inc	hl
	inc	hl	;Add header size
	ld	a,h
	ld	(WIZ_S0_RX_RD0),a
	ld	a,l
	ld	(WIZ_S0_RX_RD1),a

	ld	a,CMD_RECV
	ld	(WIZ_S0_CR),a

	exx
	call	RESTSLOTP2
	exx
	xor	a
	ret


;This routine transfers a chunk of data
;from W5100 socket 0 receive buffer to MSX memory,
;taking in account that receive buffer is circular.
;Assumes that receive buffer is 8K long and 
;is currenly visible at page 2.
;
;Input:  HL = Source address in W5100 RAM (page 2)
;        DE = Destination address in MSX RAM (page 0 or 3)
;        BC = Transfer length
;Output: HL = (HL + BC) and #1FFF or #A000
;        DE = DE + BC
;Modifies: AF

WIZ_TO_MSX:

	;If the circular buffer border is not crossed, one single transfer will do...

	push	hl
	add	hl,bc
	dec	hl
	ld	a,h
	cp	0C0h
	pop	hl
	jr	nc,W2M_2XFERS

W2M_1XFER:
	push	bc
	ldir
	res	6,h
	set	5,h
	pop	bc
	ret

	;...otherwise, we'll need to transfer in two chunks.

W2M_2XFERS:
	push	bc

	push	hl
	push	de
	ex	de,hl
	ld	hl,0C000h
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
	ld	hl,0A000h
	ldir

	pop	bc
	ret


;--- ETH_SEND_FRAME: Send a frame
;    Input:  A  = 9
;            HL = Frame address in memory
;            BC = Frame length
;            D  = Routine execution mode:
;                 0: Synchronous
;                 1: Asynchronous
;    Output: A  = 0: Frame sent, or transmission started
;                 1: Invalid frame length
;                 3: Carrier lost
;                 4: Excessive collisions
;                 5: Asyncrhonous mode not supported

ETH_SEND_FRAME:	;debug   "9"
	exx
	call	SETSLOTP2
	call	SET_WIZ_REGS2
	exx

	;>>> Initial checkings and setup <<<

	ld	iyh,d	;Save sync/async mode for (much) later

	;Check frame size

	push	hl
	push	bc
	pop	hl

	ld	de,60
	call	COMP16
	jr	nc,SENDF_NOSMALL
	ld	bc,60
	jr	SENDF_OKSIZE
SENDF_NOSMALL:
	ld	de,1514+1
	call	COMP16
	jr	c,SENDF_OKSIZE
SENDF_BADSIZE:
	pop	hl
	call	RESTSLOTP2
	ld	a,1
	;debug   "3"
	ret
SENDF_OKSIZE:
	pop	hl

	;Wait if W5100 is busy

	call	WAIT_WIZ_BUSY

	;Get free memory size

	push	hl
	ld	d,b
	ld	e,c	;DE = Frame size
SEND_WAIT_FREE:
	ld	a,(WIZ_S0_TX_FSR0)	;HL = Free W5100 memory size
	ld	h,a
	ld	a,(WIZ_S0_TX_FSR1)
	ld	l,a
	call	COMP16
	jr	c,SEND_WAIT_FREE
	pop	hl

	;Calculate the send buffer start address as:
	;gS0_TX_BASE + (S0_TX_WR and gS0_TX_MASK), that is:
	;8000h + (S0_TX_WR and 1FFFh)

	ld	a,(WIZ_S0_TX_WR0)
	and	1Fh
	or	80h
	ld	d,a
	ld	a,(WIZ_S0_TX_WR1)
	ld	e,a

	call	SET_WIZ_BUF2

	;At this point we have:
	;HL = Source address, MSX RAM
	;DE = Destination address, W5100 RAM
	;BC = Frame size

	;How we transfer the frame to user space
	;depends on the destination address:
	;If it is in page 0 or 3, we can do direct transfer.
	;If it is in page 2, we need to do page 3 buffering
	;(if disk system is available) or inter-slot read (if not).

	ld	a,h
	and	11000000b
	cp	80h
	jr	z,SETFRAME_INDIR

	;>>> Copy frame to W5100, direct transfer <<<

SETFRAME_DIR:
	call	MSX_TO_WIZ
	jp	SETFRAME_END

SETFRAME_INDIR:
	ld	a,(H_PHYD)
	cp	#C9	;mnemonic for RET
	jr	nz,SETFRAME_BUFP3

	;>>> Copy frame to W5100, using inter-slot read <<<

	pop	af
	push	bc
	push	af

SETFRAME_RDSLT:
	pop	af	;Retrieve slot number (set by SETSLOTP2)
	push	af

	res	5,d	;Account for circular buffer (8000h-9FFFh)

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
	pop	af
	pop	bc
	push	af
	jp	SETFRAME_END

	;>>> Copy frame to W5100, buffering in page 3 <<<

SETFRAME_BUFP3:
	exx
	call	RESTSLOTP2
	call	GETSLTP1
	ld	ixh,a	;IXh=Our slot
	call	GETSLTP2
	ld	ixl,a	;IXl=MSX RAM slot
	exx

	push	bc

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
	ld	a,ixh	;...switcsh W5100 RAM...
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
	call	MSX_TO_WIZ	;...copy the 512 bytes from page 3...

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
	call	MSX_TO_WIZ	;...copy the remaining bytes from page 3...

	exx
	ld	a,ixl	;...and switch MSX RAM again.
	ld	h,#80
	call	ENASLT
	exx

SFI_END:
	;At this point, page 2 must have MSX RAM switched.

	pop	bc
	exx
	call	SETSLOTP2
	exx

	;>>> Transfer done, now update S0_TX_WR and perform SEND command <<<

SETFRAME_END:
	call	SET_WIZ_REGS2

	ld	a,(WIZ_S0_TX_WR0)
	ld	h,a
	ld	a,(WIZ_S0_TX_WR1)
	ld	l,a
	add	hl,bc	;Add frame size
	ld	a,h
	ld	(WIZ_S0_TX_WR0),a
	ld	a,l
	ld	(WIZ_S0_TX_WR1),a

	ld	a,CMD_SEND
	ld	(WIZ_S0_CR),a

	;If asyncrhonous mode was requested, terminate immediately...

	ld	a,iyh
	dec	a
	jr	z,SENDF_END

	;...otherwise wait for the transmission to finish,
	;and return appropriate status code

	call	WAIT_WIZ_BUSY
	ld	d,0
	jp	DO_OUTSTAT

SENDF_END:
	ex	af,af'
	call	RESTSLOTP2
	ex	af,af'
	;debug   "4"
	ret


;This routine transfers a chunk of data
;from MSX memory to W5100 socket 0 send buffer,
;taking in account that send buffer is circular.
;Assumes that send buffer is 8K long and 
;is currenly visible at page 2.
;
;Input:  HL = Source address in MSX RAM (page 0 or 3)
;        DE = Destination address in W5100 RAM (page 2)
;        BC = Transfer length
;Output: HL = HL + BC
;        DE = (DE + BC) and #1FFF or #8000
;Modifies: AF, BC

MSX_TO_WIZ:

	;If the circular buffer border is not crossed, one single transfer will do...

	ex	de,hl
	push	hl
	add	hl,bc
	dec	hl
	ld	a,h
	cp	0A0h
	pop	hl
	ex	de,hl
	jr	nc,M2W_2XFERS

M2W_1XFER:
	push	bc
	ldir
	res	6,d
	res	5,d
	pop	bc
	ret

	;...otherwise, we'll need to transfer in two chunks.

M2W_2XFERS:
	push	bc

	push	hl
	push	de
	ld	hl,0A000h
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
	ld	de,08000h
	ex	(sp),hl
	ldir

	pop	bc
	ret


;--- ETH_OUT_STATUS: Check frame transmission status
;    Input:  A = 10
;    Output: A = 0: No frames were sent since last reset
;                1: Now transmitting
;                2: Transmission finished successfully
;                3: Carrier lost
;                4: Excessive collisions
;                6: Timeout

ETH_OUT_STATUS:	;debug   "A"
	call	SETSLOTP2
	call	SET_WIZ_REGS2

	;Check if transmitting data

	ld	a,(WIZ_S0_CR)
	cp	CMD_SEND
	ld	a,1
	jr	z,OUTSTAT_END
	ld	d,2

	;At this point, D contains the value to be returned
	;for "transmission finished" (it is different
	;for ETH_SEND_FRAME and ETH_OUT_STATUS)

DO_OUTSTAT:
	call	GETWRK
	push	hl
	pop	ix

	;Check if there is an interrupt for socket 0

	ld	a,(WIZ_S0_IR)
	and	00011000b	;Timeout or Send OK?
	jr	nz,OUTSTAT_NEWDATA

	;No interrupt available: get cached data

	ld	a,(ix+7)
OUTSTAT_END:
	ex	af,af'
	call	RESTSLOTP2
	ex	af,af'
	ret

	;Interrupt available: update the cached data

OUTSTAT_NEWDATA:
	and	00001000b	;Timeout?
	ld	a,6
	jr	nz,OUTSTAT_SETNEW
	ld	a,d

OUTSTAT_SETNEW:
	ld	(ix+7),a

	ex	af,af'
	ld	a,00011000b	;Clear interrupt bits
	ld	(WIZ_S0_IR),a
	call	RESTSLOTP2
	ex	af,af'
	ret


;--- ETH_SET_HWADD: Set hardware address
;    Input:  A  = 11
;            L-H-E-D-C-B = Ethernet address to set
;    Output: L-H-E-D-C-B = Current ethernet address

ETH_SET_HWADD:	;debug   "B"
	exx
	call	SETSLOTP2
	call	SET_WIZ_REGS2
	exx

	call	SET_MAC

	exx
	call	RESTSLOTP2
	exx
	ret

SET_MAC:
	ld	ix,WIZ_SHAR0
	ld	(ix),l
	ld	(ix+1),h
	ld	(ix+2),e
	ld	(ix+3),d
	ld	(ix+4),c
	ld	(ix+5),b
	ret


;****************************
;***  AUXILIARY ROUTINES  ***
;****************************

;--- Set on page 2 the same slot of page 1.
;    The previous slot on page 2 is saved on the stack,
;    and can be restored by calling RESTSLOTP2.
;    Input:  -
;    Output: -
;    Modifies: AF, BC, DE, HL

;Note: this routine must be CALLed, it can't be JPed!

SETSLOTP2:
	call	GETSLTP2
	pop	hl
	push	af
	push	hl
	call	GETSLTP1
	ld	h,80h
	jp	ENASLT


;--- Restores the original slot on page 2,
;    must be called with the stack pointing at
;    the same location as when SETSLOTP2 was called.
;    Input:  -
;    Output: -
;    Modifies: AF, BC, DE, HL

;Note: this routine must be CALLed, it can't be JPed!

RESTSLOTP2:
	pop	hl
	pop	af
	push	hl
	ld	h,80h
	jp	ENASLT


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


;--- Get slot connected on page 1
;    Input:  -
;    Output: A = Slot number
;    Modifies: AF, HL, E, BC

GETSLTP1:
	di
	in	a,(0A8h)
	ld	e,a
	and	00001100b
	sra	a
	sra	a
	ld	c,a	;C = Slot
	ld	b,0
	ld	hl,EXPTBL
	add	hl,bc
	bit	7,(hl)
	jr	z,NOEXP1
EXP1:	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	and	00001100b
	or	c
	or	080h
	ld	c,a
NOEXP1:	ld	a,c
	ei
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


;--- Open socket 0
;    Assumes W5100 registers visible on page 2
;    Input:  -
;    Output: A = 1
;    Modifies: F

OPEN_S0:
	ld	a,4
	ld	(WIZ_S0_MR),a

	ld	a,CMD_OPEN
	ld	(WIZ_S0_CR),a

	ld	a,(WIZ_S0_SR)
	cp	SOCK_MACRAW
	ld	a,1
	ret	z

	ld	a,CMD_CLOSE
	ld	(WIZ_S0_CR),a
	jr	OPEN_S0


;--- Close socket 0
;    Assumes W5100 registers visible on page 2
;    Input:  -
;    Output: A = 2
;    Modifies: F

CLOSE_S0:
	ld	a,CMD_CLOSE
	ld	(WIZ_S0_CR),a
	ld	a,2
	ret


;--- Wait until W5100 is not busy
;    Assumes W5100 registers visible on page 2
;    Input:  -
;    Output: -
;    Modifies:  AF

WAIT_WIZ_BUSY:
	ld	a,(WIZ_S0_CR)
	or	a
	ret	z

	cp	CMD_SEND
	jr	nz,WAIT_WIZ_BUSY

	push	hl
	push	de
	push	bc
	ld	b,255
WIZ_BUSY_LOOP:

	ld	a,(WIZ_S0_CR)
	or	a
	jr	z,WAIT_WIZ_END

	;Due to errata on W5100 chip,
	;sometimes the sending process
	;does not complete on UDP and Raw modes.
	;In this case, S0_TX_RD and S0_TX_WR
	;will never get equal,
	;and after some time a reset must be issued.

	ld	a,(WIZ_S0_TX_RD0)
	ld	h,a
	ld	a,(WIZ_S0_TX_RD1)
	ld	l,a
	ld	a,(WIZ_S0_TX_WR0)
	ld	d,a
	ld	a,(WIZ_S0_TX_WR1)
	ld	e,a
	call	COMP16
	jr	z,WAIT_WIZ_END

	djnz	WIZ_BUSY_LOOP
	call	CLOSE_S0
	call	OPEN_S0

WAIT_WIZ_END:
	pop	bc
	pop	de
	pop	hl
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


;**************
;***  DATA  ***
;**************

	;--- Specification identifier (up to 15 chars and zero terminated)

UNAPI_ID:
	db	"ETHERNET",0

	;--- Implementation identifier (up to 63 chars and zero terminated)

APIINFO:
	db	"DenYoNet",0

	;--- Other data

INITMSG:
	db	13,10,"DenYoNet Ethernet Cartridge",13,10
	db	"(c) 2009 Dennis Koller & Yobi",13,10
	db	"Produced by Sunrise for MSX",13,10
	db	13,10
	db	"DenYoNEt Ethernet UNAPI BIOS ",ROM_V_P+48,".",ROM_V_S+48,13,10
	db	"(c) 2010,2011 Konamiman",13,10
	db	13,10
	db	0

	;ds      08000h-$,#FF     ;Padding to make a 16K ROM

	end
