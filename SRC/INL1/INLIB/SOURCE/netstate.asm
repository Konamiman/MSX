NETWORK_STATE =	0x4084

        .globl  _CALL_INL

        .area   _CODE

; byte NetworkState(); 

_NetworkState::
        push    ix
        call    #_CALL_INL
        .dw     #NETWORK_STATE
        ld      l,a
        pop     ix
        ret
