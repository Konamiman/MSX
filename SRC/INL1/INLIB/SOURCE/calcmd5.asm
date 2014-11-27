CALC_MD5 = 0x4039

        .globl  _CALL_INL

        .area   _CODE

;byte CalcMD5(void* source, void* detination, uint length);

_CalcMD5::      push    ix
        ld      ix,#4
        add     ix,sp
        ld      l,(ix)
        ld      h,1(ix)
        ld      e,2(ix)
        ld      d,3(ix)
        ld      c,4(ix)
        ld      b,5(ix)
        call    _CALL_INL
        .dw     #CALC_MD5
        pop     ix
        ret       
