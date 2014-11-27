RAW_CONTROL = 0x407B

        .globl  _CALL_INL

        .area   _CODE

;byte ControlRaw(byte action, uint* size, byte* proto);

_ControlRaw::       push    ix
        ld      ix,#4
        add     ix,sp
        ld      e,1(ix)
        ld      d,2(ix) ;DE=&size
        ld      l,3(ix)
        ld      h,4(ix) ;HL=&proto
        ld      b,(hl)  ;B=Proto
        ld      a,(ix)  ;A=Action
        push    de
        push    hl
        call    _CALL_INL
        .dw     #RAW_CONTROL
        jr      nc,RAWC_OK
        or      #0x80
RAWC_OK:        ld      e,a
        pop     hl
        ld      (hl),d
        pop     hl
        ld      (hl),c
        inc     hl
        ld      (hl),b
        ld      l,e
        pop     ix
        ret
