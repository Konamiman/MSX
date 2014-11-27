DNS_S = 0x4060

        .globl  _CALL_INL

        .area   _CODE

; ip_address DNSResult(byte clear); 

_DNSResult::
        push    ix
        ld      hl,#4
        add     hl,sp
        ld      a,(hl)
        call    #_CALL_INL
        .dw     #DNS_S
        pop     ix
        ret
