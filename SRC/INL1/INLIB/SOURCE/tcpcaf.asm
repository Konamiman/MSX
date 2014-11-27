TCP_CLOSE =0x4066
TCP_ABORT =0x4069
TCP_FLUSH =0x4075

        .globl  _CALL_INL

        .area   _CODE

;byte TCPClose(TCPHandle handle);
;byte TCPAbort(TCPHandle handle);
;byte TCPFlush(TCPHandle handle);

_TCPClose::	ld	hl,#TCP_CLOSE
	ld	(CLOSAB),hl
	jr	TCP_CLOSAB
	
_TCPAbort::	ld	hl,#TCP_ABORT
	ld	(CLOSAB),hl
	jr	TCP_CLOSAB

_TCPFlush::	ld	hl,#TCP_FLUSH
	ld	(CLOSAB),hl
	
TCP_CLOSAB:	push	ix
	ld	hl,#4
	add	hl,sp
	ld	a,(hl)
        call    _CALL_INL
CLOSAB: .dw     0
	ld	l,a
	pop	ix
	ret
