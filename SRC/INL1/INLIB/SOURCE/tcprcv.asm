TCP_RCV =0x406F

        .globl  _CALL_INL

        .area   _CODE

;byte TCPRcv(TCPHandle handle, void* data, uint* length);

_TCPRcv::	push	ix
	ld	ix,#4
	add	ix,sp
	ld	e,1(ix)
	ld	d,2(ix)
	ld	l,3(ix)
	ld	h,4(ix)
	push	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	a,(ix)
	call	_CALL_INL
	.dw	#TCP_RCV
	pop	hl
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ld	l,a
	pop	ix
	ret
