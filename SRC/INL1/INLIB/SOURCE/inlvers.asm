VERS_PAUSE = 0x402A

	.globl	_CALL_INL

        .area   _CODE

; long INLversion(); 

_INLVersion::
        push    ix
        xor     a
        call    #_CALL_INL
        .dw     #VERS_PAUSE

        ;Transforms CDEB to DEHL
        ld      l,b
        ld      h,e
        ld      e,d
        ld      d,c
        pop     ix
        ret
