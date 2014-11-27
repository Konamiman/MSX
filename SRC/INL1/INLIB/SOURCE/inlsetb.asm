SET_VAR = 0x4030

        .globl  _CALL_INL

        .area   _CODE

;void INLSetByte(void* address, byte data);

_INLSetByte::   push    ix
        ld      ix,#4
        add     ix,sp
        ld      l,(ix)
        ld      h,1(ix)
        ld      a,2(ix)
        or      a
        call    _CALL_INL
        .dw     #SET_VAR
        pop     ix
        ret        
