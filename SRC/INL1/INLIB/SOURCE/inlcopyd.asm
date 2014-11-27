COPY_DATA = 0x4033

        .globl  _CALL_INL

        .area   _CODE

;void INLCopyData(void* source, void* destination, uint length, byte direction);

_INLCopyData::   push    ix
        ld      ix,#4
        add     ix,sp
        ld      l,(ix)
        ld      h,1(ix)
        ld      e,2(ix)
        ld      d,3(ix)
        ld      c,4(ix)
        ld      b,5(ix)
        ld      a,6(ix)
        or      a
        jr      z,INLCDATA2
        scf
INLCDATA2:        call    _CALL_INL
        .dw     #COPY_DATA
        pop     ix
        ret
