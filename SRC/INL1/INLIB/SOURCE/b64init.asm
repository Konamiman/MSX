B64_INIT = 0x403F

        .globl  _CALL_INL

        .area   _CODE

;void B64Init(byte linelength);

_B64Init::      push    ix
        ld      hl,#4
        add     hl,sp
        ld      a,(hl)
        call    _CALL_INL
        .dw     #B64_INIT
        pop     ix
        ret   
