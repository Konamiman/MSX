SEND_ECHO = 0x4051

        .globl  _CALL_INL

        .area   _CODE

;typedef struct {
;        ip_address PeerIP;
;        byte TTL;
;        uint ICMPId;
;        uint ICMPSeq;
;        uint DataLen;
;} EchoInfo;

; byte SendPING(EchoInfo* info);

_SendPING::
        push    ix
        ld      ix,#4
        add     ix,sp
        ld      l,(ix)
        ld      h,1(ix)
        push    hl
        pop     ix      ;IX=&EchoInfo
        
        ld      l,5(ix)  ;ICMP Id
        ld      h,6(ix)
        push    hl
        ld      l,7(ix) ;ICMP Seq
        ld      h,8(ix)
        push    hl
        pop     iy
        ld      d,3(ix) ;IP
        ld      e,2(ix)
        ld      h,1(ix)
        ld      l,(ix)
        ld      a,4(ix) ;TTL
        ld      c,9(ix) ;Data length
        ld      b,10(ix)
        pop     ix
        call    _CALL_INL
        .dw     #SEND_ECHO

        ld      l,#0
        jr      nc,SECHO_OK
        ld      l,#1
SECHO_OK:       pop     ix
        ret

