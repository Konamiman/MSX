UDP_SEND = 0x4057

;typedef struct {
;        ip_address PeerIP;
;        uint DestPort;
;        uint SrcPort;
;        void* Data;
;        uint DataLength;
;} UDPInfo;

        .globl  _CALL_INL

        .area   _CODE

; byte SendUDP(UDPInfo* info);

_SendUDP::
        push    ix
        ld      ix,#4
        add     ix,sp
        ld      l,(ix)
        ld      h,1(ix)
        push    hl
        pop     ix      ;IX=&UDPInfo
        
        ld      l,4(ix) ;Dest. port
        ld      h,5(ix)
        push    hl
        ld      l,6(ix) ;Src. port
        ld      h,7(ix)
        push    hl
        ld      l,10(ix) ;Data length
        ld      h,11(ix)
        push    hl
        ld      d,3(ix) ;Dest. IP
        ld      e,2(ix)
        ld      h,1(ix)
        ld      l,0(ix)
        ld      c,8(ix) ;Data pointer
        ld      b,9(ix)
        pop     af
        pop     ix
        pop     iy
        call    #_CALL_INL
        .dw     #UDP_SEND

        ld      l,#0
        jr      nc,UDPS_NOERR
        ld      l,#1
UDPS_NOERR:
        pop     ix
        ret
