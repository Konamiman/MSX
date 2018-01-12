        .area   _CODE
_putchar::
_putchar_rr_s::
        ld      hl,#2
        add     hl,sp

        ld	a,(hl)
	jp      0x00A2

_putchar_rr_dbs::
	ld	a,e
	jp	0x00A2
