        .area   _CODE
_putchar::
_putchar_rr_s::
        ld      hl,#2
        add     hl,sp

        ld	e,(hl)
_putchar_rr_dbs::
	ld	c,#2
	jp	5
