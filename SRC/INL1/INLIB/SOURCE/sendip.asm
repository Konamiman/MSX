RAW_SEND = 0x4078

        .globl  _CALL_INL

        .area   _CODE

;typedef struct {
;        ip_address PeerIP;     +0
;        byte Protocol;         +4
;        byte TTL;              +5
;        byte ToS;              +6
;        void* Data;            +7
;        uint DataLen;          +9
;} IPInfo;

;byte SendIP(IPInfo* info);

_SendIP::
        push    ix
        ld      ix,#4
        add     ix,sp
        ld      l,(ix)
        ld      h,1(ix)
        push    hl
        pop     ix      ;IX=&IPInfo

        ld      l,7(ix)  ;Data address
        ld      h,8(ix)
        push    hl
        ld      l,5(ix) ;ToS and TTL
        ld      h,6(ix)
        push    hl
        pop     iy
        ld      d,3(ix) ;IP
        ld      e,2(ix)
        ld      h,1(ix)
        ld      l,(ix)
        ld      a,4(ix) ;Protocol
        ld      c,9(ix) ;Size
        ld      b,10(ix)
        pop     ix
        or      a
        call    _CALL_INL
        .dw     #RAW_SEND

        pop     ix
	ld	l,a
        ret
