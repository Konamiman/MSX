VERS_PAUSE = 0x402A

        .globl  _CALL_INL

        .area   _CODE

; byte INLstate(byte action); 

_INLState::
        push    ix
        ld      hl,#4
        add     hl,sp
        ld      a,(hl)
        call    #_CALL_INL
        .dw     #VERS_PAUSE
        ld      l,a
        pop     ix
        ret
