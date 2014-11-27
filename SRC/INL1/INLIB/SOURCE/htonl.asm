        .globl  _CALL_INL

        .area   _CODE

;ulong htonl(ulong arg);

_htonl::
        ld      iy,#4
        add     iy,sp
        ld      d,4(iy)
        ld      e,5(iy)
        ld      h,6(iy)
        ld      l,7(iy)
        ret
