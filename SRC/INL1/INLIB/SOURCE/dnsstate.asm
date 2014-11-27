DNS_S = 0x4060

        .globl  _CALL_INL

        .area   _CODE

; uint DNSState(); 

_DNSState::
        push    ix
        xor     a
        call    #_CALL_INL
        .dw     #DNS_S
        ld      h,a
        ld      l,b
        pop     ix
        ret
