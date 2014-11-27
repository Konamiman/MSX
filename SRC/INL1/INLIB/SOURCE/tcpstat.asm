TCP_STATUS =0x4072

        .globl  _CALL_INL

        .area   _CODE

;typedef struct {
;        byte State;		+0
;        uint IncomingUsed;	+1
;        uint OutgoingFree;	+3
;        uint ReTXUsed;		+5
;        void* TCBAddress;	+7
;} TCPStateInfo;

;byte TCPStatus(TCPHandle handle, TCPStateInfo* info);

_TCPStatus::
        push    ix
        ld      ix,#4
        add     ix,sp
	ld	a,(ix)
        ld      l,1(ix)
        ld      h,2(ix)
        push    hl      ;&TCPStateInfo to the stack
        
        call    _CALL_INL
        .dw     #TCP_STATUS
        jr      c,TCPST_ERR
        ex      (sp),ix ;IX=&EchoInfo, ICMP Id to the stack
        
        ld      (ix),a ;Connection status
        ld      9(ix),b
        ld      1(ix),l ;Incoming bytes
        ld      2(ix),h
        ld      3(ix),e ;Outgoing free space
        ld      4(ix),d
        ld      5(ix),c ;ReTX queue length
	ld	6(ix),b
        pop     hl
        ld      7(ix),l  ;TCP address
        ld      8(ix),h
        
        ld      l,#0
        pop     ix
        ret

TCPST_ERR:      ld      l,a
	pop	ix
        pop     ix
        ret
