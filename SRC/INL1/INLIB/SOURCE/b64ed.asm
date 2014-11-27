B64_ENCODE = 0x4042
B64_DECODE = 0x4045

        .globl  _CALL_INL

        .area   _CODE

;typedef struct {
;        void* Src;             +0
;        void* Dest;            +2
;        uint Size;             +4
;        byte Final;            +6
;        long Cummulated;       +7
;} B64Info;

;byte B64Encode(B64info* Info);
;byte B64Decode(B64info* Info);

_B64Encode::	ld      hl,#B64_ENCODE
        ld      (B64ENCDEC),hl
        jr      _B64ED

_B64Decode::    ld      hl,#B64_DECODE
        ld      (B64ENCDEC),hl

_B64ED: push    ix
        ld      ix,#4
        add     ix,sp
        ld      l,(ix)
        ld      h,1(ix)
        push    hl
        pop     ix      ;IX=&B64Info
        push    ix
        ld      l,(ix)  ;Source
        ld      h,1(ix)
        push    hl
        ld      l,2(ix) ;Destination
        ld      h,3(ix)
        push    hl
        ld      c,4(ix)
        ld      b,5(ix)
        ld      a,6(ix)
        pop     iy
        pop     ix
        or      a
        jr      z,B64ED2
        scf
B64ED2: call    _CALL_INL
B64ENCDEC:      .dw     #0

        ex      (sp),ix ;IX to stack, IX=&B64Info
        jr      c,B64EDERR
        ld      4(ix),c ;Size
        ld      5(ix),b
        ld      7(ix),e ;Cummulated size
        ld      8(ix),d
        ld      9(ix),l
        ld      10(ix),h
        push    iy
        pop     hl
        ld      2(ix),l ;Updated destination
        ld      3(ix),h
        pop     hl
        ld      (ix),l ;Updated source
        ld      1(ix),h
        ld      l,#0
        pop     ix
        ret

B64EDERR:       pop     ix
        pop     ix
        ld      l,a
        ret
