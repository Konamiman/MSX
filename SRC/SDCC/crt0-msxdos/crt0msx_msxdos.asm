	;--- crt0.asm for MSX-DOS - by Konamiman & Avelino, 11/2004
	;    Simple version: allows "void main()" only.
	;
	;    Compile programs with --code-loc 0x108 --data-loc X
	;    X=0  -> global vars will be placed immediately after code
	;    X!=0 -> global vars will be placed at address X
	;            (make sure that X>0x100+code size)

	.globl	_main

    .globl  l__INITIALIZER
    .globl  s__INITIALIZED
    .globl  s__INITIALIZER

	.area _HEADER (ABS)

	.org    0x0100  ;MSX-DOS .COM programs start address

	;--- Initialize globals and jump to "main"

init:   call gsinit
	jp   __pre_main

	;--- Program code and data (global vars) start here

	;* Place data after program code, and data init code after data

	.area	_CODE

__pre_main:
	push de
	ld de,#_HEAP_start
	ld (_heap_top),de
	pop de
	jp _main

	.area	_DATA

_heap_top::
	.dw 0

        .area   _GSINIT
gsinit::
        ld	bc,#l__INITIALIZER
        ld	a,b
        or	a,c
        jp	z,gsinext
        ld	de,#s__INITIALIZED
        ld	hl,#s__INITIALIZER
        ldir
gsinext:
        .area   _GSFINAL
        ret

	;* These doesn't seem to be necessary... (?)

	;.area  _OVERLAY
	;.area	_HOME
	;.area  _BSS

	.area	_HEAP

_HEAP_start::
