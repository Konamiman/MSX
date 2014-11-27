GET_VAR = 0x402D

        .globl  _CALL_INL

        .area   _CODE

;uint INLGetData(void* address);

_INLGetData::
        push    ix
        ld      ix,#4
        add     ix,sp
        ld      l,(ix)
        ld      h,1(ix)
        call    _CALL_INL
        .dw     #GET_VAR
        ex      de,hl
        pop     ix
        ret
