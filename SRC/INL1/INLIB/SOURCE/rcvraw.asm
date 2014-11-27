RAW_RCV = 0x407E

        .globl  _CALL_INL

        .area   _CODE

;typedef struc {
;        uint IPHeaderLen;      +0
;        uint DataLen;          +2
;        uint TotalLen;         +4
;        void* Datagram;        +6
;        void* DataPart;        +8
;} RawRcvInfo;

;byte RcvRaw(RawRcvInfo* info);

_RcvRaw::
        push    ix
        ld      ix,#4
        add     ix,sp
        ld      l,(ix)
        ld      h,1(ix)
        push    hl      ;&RawRcvInfo to the stack
        pop     ix
        ld      l,6(ix) ;Datagram destination address
        ld      h,7(ix)
        push    ix
        
        call    _CALL_INL
        .dw     #RAW_RCV
        jr      c,RAWR_ERR
        pop     ix ;IX=&RawRcvInfo
        
        ld      (ix),a ;IPHeader length
        ld      1(ix),#0
        ld      2(ix),e ;Data part length
        ld      3(ix),d
        ld      4(ix),c ;Total length
        ld      5(ix),b
        ld      8(ix),l ;Data part pointer
	ld	9(ix),h
        
        ld      l,#0
        pop     ix
        ret

RAWR_ERR:       ld      l,a
	pop	ix
        pop     ix
        ret
