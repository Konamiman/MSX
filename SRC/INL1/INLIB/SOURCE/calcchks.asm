CALC_CHKSUM = 0x403C

        .globl  _CALL_INL

        .area   _CODE

;uint CalcChecksum(void* source, uint length);

_CalcChecksum::        push    ix
        ld      ix,#4
        add     ix,sp
        ld      l,(ix)
        ld      h,1(ix)
        ld      c,2(ix)
        ld      b,3(ix)
        call    _CALL_INL
        .dw     #CALC_CHKSUM
        ex      de,hl
        pop     ix
        ret       
