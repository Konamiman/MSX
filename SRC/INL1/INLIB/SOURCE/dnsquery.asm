DNS_Q = 0x405D

        .globl  _CALL_INL

        .area   _CODE

; byte DNSQuery(char* host, byte flags); 

_DNSQuery::
        push    ix
        ld      ix,#4
        add     ix,sp
        ld      l,(ix)
        ld      h,1(ix)
        ld      a,2(ix)
        call    #_CALL_INL
        .dw     #DNS_Q
        jr      c,DNSQ_ERR
        xor     a
DNSQ_ERR:
        ld      l,a
        pop     ix
        ret
