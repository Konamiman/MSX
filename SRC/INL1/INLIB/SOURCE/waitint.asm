WAIT_INT = 0x4081

        .globl  _CALL_INL

        .area   _CODE

; byte WaitInt(); 

_WaitInt::
        push    ix
        call    #_CALL_INL
        .dw     #WAIT_INT
        ld      a,#1
        jr      c,INT_WAITED
        ld      a,#0
INT_WAITED:     ld      l,a
        pop     ix
        ret
