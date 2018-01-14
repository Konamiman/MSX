#include "asm.h"

void AsmCall(uint address, Z80_registers* regs, register_usage inRegistersDetail, register_usage outRegistersDetail) __naked
{
    __asm
    push    ix
    ld      ix,#4
    add     ix,sp

    ld      l,(ix)  ;HL=Routine address
    ld      h,1(ix)
    ld      e,2(ix) ;DE=regs address
    ld      d,3(ix)
    ld      a,5(ix) ;A=out registers detail
    push    af
    ld	    a,4(ix)	;A=in registers detail

    push    de

    push    de
    pop     ix   ;IX=&Z80regs

    ld      de,#CONT
    push    de
    push    hl

    or	    a
    ret     z   ;Execute code, then CONT (both in stack)

    exx
    ld	    l,(ix)
    ld	    h,1(ix)	;AF
    dec	    a
    jr	    z,ASMRUT_DOAF
    exx

    ld      c,2(ix) ;BC, DE, HL
    ld      b,3(ix)
    ld      e,4(ix)
    ld      d,5(ix)
    ld      l,6(ix)
    ld      h,7(ix)
    dec	    a
    exx
    jr	    z,ASMRUT_DOAF

    ld      c,8(ix)	 ;IX
    ld      b,9(ix)
    ld      e,10(ix) ;IY
    ld      d,11(ix)
    push	de
    push	bc
    pop	    ix
    pop	    iy

ASMRUT_DOAF:
    push	hl
    pop	    af
    exx

    ret  ;Execute code, then CONT (both in stack)
CONT:

    ex      (sp),ix ;IX to stack, now IX=&Z80regs
    ex	    af,af	;Alternate AF

    pop     af  ;out registers detail
    or	    a
    jr	    z,CALL_END

    exx		;Alternate HLDEBC
    ex  	af,af	;Main AF
    push	af
    pop	    hl
    ld	    (ix),l
    ld	    1(ix),h
    exx		;Main HLDEBC
    ex	    af,af	;Alternate AF
    dec 	a
    jr	    z,CALL_END

    ld      2(ix),c ;BC, DE, HL
    ld      3(ix),b
    ld      4(ix),e
    ld      5(ix),d
    ld      6(ix),l
    ld      7(ix),h
    dec	a
    jr	z,CALL_END

    exx		;Alternate HLDEBC
    pop     hl
    ld      8(ix),l ;IX
    ld      9(ix),h
    push    iy
    pop     hl
    ld      10(ix),l ;IY
    ld      11(ix),h
    exx		;Main HLDEBC

    ex	    af,af
    pop 	ix
    ret

CALL_END:
    ex	    af,af
    pop	    hl
    pop 	ix
    ret

    __endasm;
}
