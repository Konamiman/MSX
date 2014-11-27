        .globl  _CALL_INL

        .area   _CODE

;uint hton(uint arg);

_hton::
        ld      hl,#2
        add     hl,sp
        ld      a,(hl)
        inc     hl
        ld      l,(hl)
        ld      h,a
        ret
