UDP_RCV = 0x405A

;typedef struct {
;        ip_address PeerIP;
;        uint DestPort;
;        uint SrcPort;
;        void* Data;
;        uint DataLength;
;} UDPInfo;

        .globl  _CALL_INL

        .area   _CODE

; byte RcvUDP(UDPInfo* info);

_RcvUDP::
        push    ix
        ld      ix,#4
        add     ix,sp
        ld      l,(ix)
        ld      h,1(ix)
        push    hl      ;&UDPInfo to the stack
        
	pop	ix
	push	ix
	ld	l,8(ix)	;Destination for data
	ld	h,9(ix)

        call    _CALL_INL
        .dw     #UDP_RCV
        jr      c,RUDP_ERR
        ex      (sp),ix ;IX=&UDPInfo, source port to the stack

        ld      3(ix),d ;Source IP
        ld      2(ix),e
        ld      1(ix),h
        ld      (ix),l
        ld      10(ix),c ;Data length
        ld      11(ix),b
        push    iy
        pop     hl
        ld      4(ix),l ;Dest. port
        ld      5(ix),h
        pop     hl
        ld      6(ix),l ;Src. port
        ld      7(ix),h
        ld      l,#0
        pop     ix
        ret

RUDP_ERR:       ld      l,#1
	pop	ix
        pop     ix
        ret
