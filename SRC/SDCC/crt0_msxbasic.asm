	;--- crt0.asm for MSX-BASIC - by Konamiman, 1/2018
	;
	;    Change the .org directive as appropriate for your program
	;
	;    To assemble it:
	;    sdasz80 -o crt0_msxbasic.rel crt0_msxbasic.s
	;
	;    Compile programs with --code-loc <org address + 32> --data-loc X
	;    X=0  -> global vars will be placed immediately after code
	;    X!=0 -> global vars will be placed at address X
	
	.module crt0
	.globl	_main

    .globl  l__INITIALIZER
    .globl  s__INITIALIZED
    .globl  s__INITIALIZER

	.area _HEADER (ABS)

	.org    0xA000
    .db 	0xFE
    .dw 	init
    .dw		end
    .dw 	init

	;--- Initialize globals and jump to "main"

init:
    ld	bc, #l__INITIALIZER
	ld	a, b
	or	a, c
	jp	z,_main
	ld	de, #s__INITIALIZED
	ld	hl, #s__INITIALIZER
	ldir

	jp    _main

	;; Ordering of segments for the linker.
	.area	_HOME
	.area	_CODE
	.area	_INITIALIZER
	.area   _GSINIT
	.area   _GSFINAL
	.area	_DATA
	.area	_INITIALIZED
	.area	_BSEG
	.area   _BSS
	.area   _HEAP

end:
