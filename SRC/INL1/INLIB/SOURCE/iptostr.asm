IP_STRING = 0x4036

        .globl  _CALL_INL

        .area   _CODE

; char* IPToString(ip_address ip, char* str); 

_IPToString::
        push    ix
        ld      ix,#0
        add     ix,sp
        ld      d,7(ix)
        ld      e,6(ix)
        ld      h,5(ix)
        ld      l,4(ix)
        push    hl
        ld      h,9(ix)
        ld      l,8(ix)
        push    hl
        pop     ix
        pop     hl
	push	ix
        xor     a
        call    #_CALL_INL
        .dw     #IP_STRING
	pop	hl
        pop     ix
        ret
