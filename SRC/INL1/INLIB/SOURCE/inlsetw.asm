SET_VAR = 0x4030

        .globl  _CALL_INL

        .area   _CODE

;void INLSetWord(void* address, uint data);

_INLSetWord::   push    ix
        ld      ix,#4
        add     ix,sp
        ld      l,(ix)
        ld      h,1(ix)
        ld      e,2(ix)
        ld      d,3(ix)
        scf
        call    _CALL_INL
        .dw     #SET_VAR
        pop     ix
        ret      
