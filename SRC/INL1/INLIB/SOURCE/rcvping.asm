RCV_ECHO = 0x4054

        .globl  _CALL_INL

        .area   _CODE

;typedef struct {
;        ip_address PeerIP;
;        byte TTL;
;        uint ICMPId;
;        uint ICMPSeq;
;        uint DataLen;
;} EchoInfo;

; byte RcvPING(EchoInfo* info);

_RcvPING::
        push    ix
        ld      ix,#4
        add     ix,sp
        ld      l,(ix)
        ld      h,1(ix)
        push    hl      ;&EchoInfo to the stack
        
        call    _CALL_INL
        .dw     #RCV_ECHO
        jr      c,RECHO_ERR
        ex      (sp),ix ;IX=&EchoInfo, ICMP Id to the stack
        
        ld      3(ix),d ;IP
        ld      2(ix),e
        ld      1(ix),h
        ld      (ix),l
        ld      4(ix),a ;TTL
        ld      9(ix),c ;Data length
        ld      10(ix),b
        push    iy
        pop     hl        
        ld      7(ix),l ;ICMP Seq
        ld      8(ix),h
        pop     hl
        ld      5(ix),l  ;ICMP Id
        ld      6(ix),h
        
        ld      l,#0
        pop     ix
        ret

RECHO_ERR:      ld      l,#1
	pop	ix
        pop     ix
        ret
