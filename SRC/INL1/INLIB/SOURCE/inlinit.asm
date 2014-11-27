        .globl _CALL_INL
        .globl _INL_PUT_P1
        .globl _INL_SEG1

        .area   _CODE

; byte INLInit();

_INLInit::     
        xor     a
        ld      de,#0x2203
	push	ix
        call    #0xFFCA
	pop	ix
        or      a
	ld	a,l
        ld      l,#0
        ret     z
	ld	l,a
        
        ld      a,b
        ld      (_INL_SEG1),a

        ld      bc,#15
        add     hl,bc
        ld      de,#_INL_PUT_P1
        ld      bc,#3
        ldir

        ld      l,#1
        ret
