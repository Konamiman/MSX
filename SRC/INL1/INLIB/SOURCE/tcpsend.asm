TCP_SEND =0x406C

        .globl  _CALL_INL

        .area   _CODE

;byte TCPSend(TCPHandle handle, void* data, uint length, byte push);

_TCPSend::	push	ix
	ld	ix,#4
	add	ix,sp
	ld	l,1(ix)
	ld	h,2(ix)
	ld	c,3(ix)
	ld	b,4(ix)
	ld	a,5(ix)
	or	a
	jr	z,TCPSEND2
	scf
TCPSEND2:	ld	a,(ix)
	call	_CALL_INL
	.dw	#TCP_SEND
	ld	l,a
	pop	ix
	ret
