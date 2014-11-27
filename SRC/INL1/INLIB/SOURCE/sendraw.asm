RAW_SEND = 0x4078

        .globl  _CALL_INL

        .area   _CODE

;byte SendRaw(void* packet, uint length);

_SendRaw::	push	ix
	ld	ix,#4
	add	ix,sp
        ld      l,(ix)  ;packet address
        ld      h,1(ix)
        push    hl
        ld      c,2(ix) ;Length
        ld      b,3(ix)
        pop     ix
        scf
	call	_CALL_INL
	.dw	#RAW_SEND
	ld	l,a
	pop	ix
	ret
