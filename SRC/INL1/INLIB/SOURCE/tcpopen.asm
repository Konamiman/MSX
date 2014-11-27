TCP_OPEN =0x4063

        .globl  _CALL_INL

        .area   _CODE

;typedef struct {
;        ip_address PeerIP; +0
;        uint DestPort;     +4
;        uint SrcPort;      +6
;        byte Passive;      +8
;        uint Timer;        +9
;} TCPOpenInfo;

; TCPHandle TCPOpen(TCPOpenInfo* info);

_TCPOpen::
        push    ix
        ld      ix,#4
        add     ix,sp
        ld      l,(ix)
        ld      h,1(ix)
        push    hl
        pop     ix      ;IX=&TCPOpenInfo

        ld      l,4(ix)  ;Remote port
        ld      h,5(ix)
        push    hl
        ld      l,6(ix) ;Local port
        ld      h,7(ix)
        push    hl
        pop     iy
        ld      d,3(ix) ;IP
        ld      e,2(ix)
        ld      h,1(ix)
        ld      l,(ix)
        ld      a,8(ix) ;Active/passive
        ld      c,9(ix) ;Timer
        ld      b,10(ix)
        pop     ix
        call    _CALL_INL
        .dw     #TCP_OPEN

        jr      nc,TCPOP_OK
	or	#0x80
TCPOP_OK:       pop     ix
	ld	l,a
        ret
