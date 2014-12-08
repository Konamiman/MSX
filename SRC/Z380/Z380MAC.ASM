	;/// Macros for assembling Z380 instructions
	;    in a Z80 assembler (tested only in Compass)
	;    Version 1.0

	;/// By Konami Man, 3-2000

;*** Macro header:

;--- <instruction name> ---
;   [<macro syntax1>  [<--- <original Zilog instruction syntax 1>]]
;   [<macro syntax2>  [<--- <original Zilog instruction syntax 2>]]
;   ...

;   Macro syntax = how the macro must be used
;   (inst r1/r2/r3... means different syntaxes: inst r1, inst r2, inst r3...)
;   Original syntax = how the instruction should be used in a Z380 assembler
;   (when original syntax is not specified, it is same as macro syntax)

;*** Notes about header syntax:

; - #nn and #nnnn are 1 byte and 2 byte immediate data, respectively.
;   n is an immediate data whose range depends on the concrete instruction.

; - When no macro nor instruction syntax is given, it is an instruction
;   without parameters: use just the instruction name.

; - When indicating immediate displacements, such (IX+#nn), do not use
;   negative numbers; for example use (IX+#FE) instead of (IX-2).

;*** Notes about syntax variations:

; - Some instructions have three versions: normal, plus "I" and plus "X".
;   The "I" is intended to mean "Immediate", and the "X" is intended to mean
;   "addressed by eXtended register" (also by HL sometimes). For example, ADCW.

; - New LD instructions have three formats:

;   LDRR = LoaD from Register to Register
;   LDMR = LoaD from Register to Memory (M <-- R)
;   LDRM = LoaD from Memory to Register (R <-- M)

;   and also LDW, which is same as original syntax.
;   Note that in LDWI, I does not mean "Immediate" but "I register".

; - All new EX instructions are defined as EXR.

; - In EXR, alternate registers are identified by a dot (".") instead of
;   an apostrophe ("'"). For example DE. instead of DE'

; - In DDIR, when two parameters are used, they are separed by a dot (".")
;   instead of a comma (","). For example IW.LW instead of IW,LW

; - CALR, DJNZ and JR have a "16" added when a 16 bit displacement is used.
;   These instructions are not defined for 24 bit displacement
;   (if you need 24 bit displacement you are programming in extended mode,
;   so for sure you are using not a normal Z80 assembler and you don't need
;   these macros at all!)

; - Only conditional branch is defined for CALR/CALR16 and JR16.
;   To specify an inconditional branch, use "T" (True) as condition.

;*** Miscellaneous

;   For details about Z380 programming, see Z380 User's Manual on
;   http://www.zilog.com

;   And by the way, visit also http://konamiman.msx.tni.nl
;   Please write me to <konamiman@geocities.com> if any error is found.

;   Z380 is a trademark of Zilog Inc. (for if the flys)


;*******************************
;***  LABELS FOR PARAMETERS  ***
;*******************************

;lw:           equ     %01+#900
lck:	equ	%10+#900
xm:	equ	%11+#900

xsr:	equ	%01+#800
dsr:	equ	%10+#800
ysr:	equ	%11+#800
sr:	equ	%100+#800

b:	equ	%000+#300
c:	equ	%001+#300
d:	equ	%010+#300
e:	equ	%011+#300
h:	equ	%100+#300
l:	equ	%101+#300
a:	equ	%111+#300
f:	equ	%1000
i:	equ	%1001

b.:	equ	%000+#400	;Alternate registers
c.:	equ	%001+#400
d.:	equ	%010+#400
e.:	equ	%011+#400
h.:	equ	%100+#400
l.:	equ	%101+#400
a.:	equ	%111+#400

bc:	equ	%00
de:	equ	%01
hl:	equ	%11
ix:	equ	#102
iy:	equ	#202
sp:	equ	%10+#900

bc.:	equ	%00+#500	;Alternate registers
de.:	equ	%01+#500
hl.:	equ	%11+#500
ix.:	equ	#100+#500
iy.:	equ	#200+#500

nz:	equ	%000
z:	equ	%001
nc:	equ	%010
cy:	equ	%011
po:	equ	%100
nv:	equ	po
pe:	equ	%101
v:	equ	pe
p:	equ	%110
ns:	equ	p
m:	equ	%111
s:	equ	m
t:	equ	%1000

w:	equ	%000
ib.w:	equ	%001
iw.w:	equ	%010
ib:	equ	%011
lw:	equ	%100
ib.lw:	equ	%101
iw.lw:	equ	%110
iw:	equ	%111


;****************
;***  MACROS  ***
;****************


	;--- ADCW ---

	;    ADCW HL/BC/DE/IX/IY
	;    ADCWX (IX/IY+#nn)   <--- ADCW (IX/IY+#nn)
	;    ADCWI #nnnn         <--- ADCW #nnnn

adcw:	macro	@r
	if	@r=#202
	db	#FD,#8F
	else
	if	@r=#102
	db	#DD,#8F
	else
	if	@r<4
	db	#ED,#8C or @r
	else
	errmac
	endif
	endif
	endif
	endm

adcwi:	macro	@n
	db	#ED,#8E
	dw	@n
	endm

adcwx:	macro	@d
	if	@d>#201
	db	#FD
	dw	#CE+(@d-#202)*256
	else
	if	@d>#101
	db	#DD
	dw	#CE+(@d-#102)*256
	else
	errmac
	endif
	endif
	endm


	;--- ADDW ---

	;    ADDW HL/BC/DE/IX/IY
	;    ADDWX (IX/IY+#nn)   <--- ADCW (IX/IY+#nn)
	;    ADDWI #nnnn         <--- ADCW #nnnn

	;    ADDSP #nnnn         <--- ADD SP,#nnnn

addw:	macro	@r
	if	@r=#202
	db	#FD,#87
	else
	if	@r=#102
	db	#DD,#87
	else
	if	@r<4
	db	#ED,#84 or @r
	else
	errmac
	endif
	endif
	endif
	endm

addwi:	macro	@n
	db	#ED,#86
	dw	@n
	endm

addwx:	macro	@d
	if	@d>#201
	db	#FD
	dw	#C6+(@d-#202)*256
	else
	if	@d>#101
	db	#DD
	dw	#C6+(@d-#102)*256
	else
	errmac
	endif
	endif
	endm

addsp:	macro	@n
	db	#ED,#82
	dw	@n
	endm


	;--- ANDW ---

	;    ANDW HL/BC/DE/IX/IY
	;    ANDWX (IX/IY+#nn)   <--- ANDW (IX/IY+#nn)
	;    ANDWI #nnnn         <--- ANDW #nnnn

andw:	macro	@r
	if	@r=#202
	db	#FD,#A7
	else
	if	@r=#102
	db	#DD,#A7
	else
	if	@r<4
	db	#ED,#A4 or @r
	else
	errmac
	endif
	endif
	endif
	endm

andwi:	macro	@n
	db	#ED,#A6
	dw	@n
	endm

andwx:	macro	@d
	if	@d>#201
	db	#FD
	dw	#E6+(@d-#202)*256
	else
	if	@d>#101
	db	#DD
	dw	#E6+(@d-#102)*256
	else
	errmac
	endif
	endif
	endm


	;--- BTEST ---

btest:	macro
	db	#ED,#CF
	endm


	;--- CALR ---

	;    CALR T,#nn             <--- CALR #nn
	;    CALR16 T,#nnnn         <--- CALR #nnnn
	;    CALR cond,#nn          <--- CALR cond,#nn
	;    CALR16 cond,#nnnn      <--- CALR cond,#nnnn

	;    CALR with 24 bit displacement is not implemented

	;    cond = NZ, Z, NC, C, PO/NV, PE/V, P/NS, M/S

calr:	macro	@c,@d
	if	@c=#301
	calr!	cy,@d-$-2
	else
	calr!	@c,@d-$-2
	endif
	endm

calr!:	macro	@c,@d
	db	#ED
	if	@c=%1000
	dw	#00CD + ((@d and #FF)*256)
	else
	if	@c<%1000
	dw	#00C4 + @c*8 + ((@d and #FF)*256)
	else
	errmac
	endif
	endif
	endm

calr16:	macro	@c,@d
	if	@c=#301
	calr16!	cy,@d-$-2
	else
	calr16!	@c,@d-$-2
	endif
	endm

calr16!:	macro	@c,@d
	db	#DD
	if	@c=%1000
	db	#CD
	else
	if	@c<%1000
	db	#C4 or @c*8
	else
	errmac
	endif
	endif
	dw	@d
	endm


	;--- CPW ---

	;    CPW HL/BC/DE/IX/IY
	;    CPWX (IX/IY+#nn)   <--- CPW (IX/IY+#nn)
	;    CPWI #nnnn         <--- CPW #nnnn

cpw:	macro	@r
	if	@r=#202
	db	#FD,#BF
	else
	if	@r=#102
	db	#DD,#BF
	else
	if	@r<4
	db	#ED,#BC or @r
	else
	errmac
	endif
	endif
	endif
	endm

cpwi:	macro	@n
	db	#ED,#BE
	dw	@n
	endm

cpwx:	macro	@d
	if	@d>#201
	db	#FD
	dw	#FE+(@d-#202)*256
	else
	if	@d>#101
	db	#DD
	dw	#FE+(@d-#102)*256
	else
	errmac
	endif
	endif
	endm


	;--- CPLW ---

cplw:	macro
	db	#DD,#2F
	endm


	;--- DDIR ---

	;    DDIR W
	;    DDIR IB.W     <--- DDIR IB,W
	;    DDIR IW.W     <--- DDIR IW,W
	;    DDIR IB
	;    DDIR LW
	;    DDIR IB.LW    <--- DDIR IB,LW
	;    DDIR IW.LW    <--- DDIR IW,LW
	;    DDIR IW

ddir:	macro	@r
	if	@r<8
	db	#DD or @r*8
	db	(#C0 or @r) and #C3
	else
	errmac
	endif
	endm


	;--- DIVUW ---

	;    DIVUW HL/BC/DE/IX/IY
	;    DIVUWX (IX/IY+#nn)   <--- DIVUW (IX/IY+#nn)
	;    DIVUWI #nnnn         <--- DIVUW #nnnn

divuw:	macro	@r
	if	@r=#202
	db	#ED,#CB,#BD
	else
	if	@r=#102
	db	#ED,#CB,#BC
	else
	if	@r<4
	db	#ED,#CB,#B8 or @r
	else
	errmac
	endif
	endif
	endif
	endm

divuwi:	macro	@n
	db	#ED,#CB,#BF
	dw	@n
	endm

divuwx:	macro	@d
	if	@d>#201
	db	#FD,#CB
	dw	#BA00+(@d-#202)
	else
	if	@d>#101
	db	#DD,#CB
	dw	#BA00+(@d-#102)
	else
	errmac
	endif
	endif
	endm


	;--- DJNZ ---

	;    DJNZ #nn
	;    DJNZ16 #nnnn        <--- DJNZ #nnnn

	;    DJNZ with 24 bit displacement is not implemented


djnz16:	macro	@d
	db	#DD,#10
	dw	@d-$-2
	endm


	;--- EI ---

	;    EI
	;    EII n    <--- EI n   (n = %00000 to %11111)

EII:	macro	@n
	db	#DD,#FB
	db	@n
	endm


	;--- EX ---

	;    EX AF,AF'
	;    EX (SP),HL/IX/IY
	;    EX DE,HL
	;    EXR BC,DE/HL        <--- EX BC,DE/HL
	;    EXR BC/DE/HL,IX/IY  <--- EX BC/DE/HL,IX/IY
	;    EXR IX,IY           <--- EX IX,IY
	;    EXR r,r.            <--- EX r,r'  (r=A, B, C, D, E, H, L)
	;    EXR rr,rr.          <--- EX rr,rr'  (rr=BC, DE, HL, IX, IY)
	;    EXR A,r             <--- EX A,r   (r=A, B, C, D, E, H, L)
	;    EXR A,(HL)          <--- EX A,(HL)

exr:	macro	@r1,@r2

	if	@r2=#700	;EX IY,IY'
	db	#ED,#CB,#35
	else

	if	@r2=#600	;EX IX,IX'
	db	#ED,#CB,#34
	else

	if	@r2>#4FF	;EX rr,rr'
	db	#ED
	dw	#30CB + (@r2-#500)*256
	else

	if	@r2>#3FF	;EX r,r'
	dw	#30CB + (@r2-#400)*256
	else

	if	@r1=#307	;EX A,?
	if	@r2=%11
	db	#ED,#37	;EX A,(HL)
	else
	dw	#07ED + (@r2-#300)*8*256	;EX A,r
	endif
	else

	if	@r2=#202	;EX ?,IY
	if	@r1=#102
	db	#ED,#2B	;EX IX,IY
	else
	dw	#0BED + @r1*16*256	;EX rr,IY
	endif
	else

	if	@r2=#102	;EX rr,IX
	dw	#03ED + @r1*16*256
	else

	if	@r1=0	;EX BC,?
	db	#ED
	if	@r2=%01
	db	#05	;EX BC,DE
	else
	db	#0D	;EX BC,HL
	endif
	else

	errmac

	endif
	endif
	endif
	endif
	endif
	endif
	endif
	endif
	endm


	;--- EXALL ---

exall:	macro
	db	#ED,#D9
	endm


	;--- EXTS ---

exts:	macro
	db	#ED,#65
	endm


	;--- EXTSW ---

extsw:	macro
	db	#ED,#75
	endm


	;--- EXXX ---

exxx:	macro
	db	#DD,#D9
	endm


	;--- EXXY ---

exxy:	macro
	db	#FD,#D9
	endm


	;--- IM ---

	;    IM  0
	;    IM  1
	;    IM  2
	;    IMI  n        <--- IM n (n=0, 1, 2, 3)

imi:	macro	@i
	if	@i=3
	db	#ED,#4E
	else
	im	@i
	endif
	endm


	;--- INW ---

	;    INW BC/DE/HL,(C)

inw:	macro	@r1,@r2
	if	@r2=#301
	db	#DD
	if	@r1=%11
	db	#78
	else
	if	@r1=%01
	db	#50
	else
	if	@r1=%00
	db	#40
	else
	errmac
	endif
	endif
	endif
	endif
	endm


	;--- IN0 ---

	;    IN0 A/B/C/D/E/H/L,(#nn)
	;    IN0 F,(#nn)     <--- IN0 (#nn)

in0:	macro	@r,@n
	if	@r=%1000
	db	#ED,#30
	else
	dw	#00ED + (@r-#300)*8*256
	endif
	db	@n
	endm


	;--- INA ---

	;    INA A,(#nnnn)

ina:	macro	@r,@n
	if	@r=#307
	db	#ED,#DB
	dw	@n
	else
	errmac
	endif
	endm


	;--- INAW ---

	;    INAW HL,(#nnnn)

inaw:	macro	@r,@n
	if	@r=%11
	db	#FD,#DB
	dw	@n
	else
	errmac
	endif
	endm


	;--- INDW ---

indw:	macro
	db	#ED,#EA
	endm


	;--- INDRW ---

indrw:	macro
	db	#ED,#FA
	endm


	;--- INIW ---

iniw:	macro
	db	#ED,#E2
	endm


	;--- INIRW ---

inirw:	macro
	db	#ED,#F2
	endm


	;--- JR ---

	;    JR #nn
	;    JR16 T,#nnnn         <--- JR #nnnn
	;    JR cond,#nn
	;    JR16 cond,#nnnn      <--- JR cond,#nnnn

	;    JR with 24 bit displacement is not implemented

	;    cond = NZ, Z, NC, C

jr16:	macro	@c,@d
	if	@c=#301
	jr16!	cy,@d-$-2
	else
	jr16!	@c,@d-$-2
	endif
	endm

jr16!:	macro	@c,@d
	db	#DD
	if	@c=%1000
	db	#18
	else
	if	@c<%1000
	db	#20 or @c*8
	else
	errmac
	endif
	endif
	dw	@d
	endm


	;--- LD ---

	;Original syntax: change LDMR/LDRM/LDRR to LD

	;    LDMR (BC/DE/HL) , BC/DE/HL/IX/IY
	;    LDMR (IX+#nn) , BC/DE/HL/IY
	;    LDMR (IY+#nn) , BC/DE/HL/IX
	;    LDMR (SP+#nn) , BC/DE/HL/IX/IY

	;    LDRM BC/DE/HL/IX/IY , (BC/DE/HL)
	;    LDRM BC/DE/HL/IY , (IX+#nn)
	;    LDRM BC/DE/HL/IX , (IY+#nn)
	;    LDRM BC/DE/HL/IX/IY , (SP+#nn)

	;    LDRR BC/DE/HL , BC/DE/HL/IX/IY
	;    LDRR BC/DE/HL/IX/IY , BC/DE/HL
	;    LDRR IX , IY
	;    LDRR IY , IX

ldrr:	macro	@r1,@r2
	if	@r2=%00
	if	@r1<#102
	ldrr!	@r1,%10
	else
	ldrr!	@r1,@r2
	endif
	else
	ldrr!	@r1,@r2
	endif
	endm

ldrr!:	macro	@r1,@r2

	if	@r2=#202	;LD ?,IY
	if	@r1=#102	;LD IX,IY
	db	#DD,#27
	else
	if	@r1<%100
	dw	#0BFD + @r1*16*256	;LD rr,IY
	else
	errmac
	endif
	endif
	else

	if	@r2=#102	;LD ?,IX
	if	@r1=#202	;LD IY,IX
	db	#FD,#27
	else
	if	@r1<%100
	dw	#0BDD + @r1*16*256	;LD rr,IX
	else
	endmac
	endif
	endif
	else

	if	@r1=#202	;LD IY,rr
	if	@r2<%100
	dw	#07FD + @r2*16*256
	else
	errmac
	endif
	else

	if	@r1=#102	;LD IX,rr
	if	@r2<%100
	dw	#07DD + @r2*16*256
	else
	errmac
	endif
	else

	if	@r1<%100	;LD rr,rr
	if	@r2<%100
	dw	#02CD + @r2*16 + @r1*16*256
	else
	errmac
	endif

	endif
	endif
	endif
	endif
	endif
	endm

ldmr:	macro	@r1,@r2

	if	@r2=#202	;LD ??,IY
	if	@r1<%100	;LD (BC/DE/HL),IY
	dw	#01FD + @r1*16*256
	else

	if	@r1<#202	;LD (IX+#nn),IY
	db	#DD,#CB
	dw	#2B00 + @r1-#102
	else

	if	@r1<#A02	;LD (SP+#nn),IY
	db	#FD,#CB
	dw	#2900 + @r1-#902
	else
	errmac

	endif
	endif
	endif
	else

	if	@r2=#102	;LD ??,IX
	if	@r1<%100	;LD (BC/DE/HL),IX
	dw	#01DD + @r1*16*256
	else

	if	@r1<#302	;LD (IY+#nn),IX
	db	#FD,#CB
	dw	#2B00 + @r1-#202
	else

	if	@r1<#A02	;LD (SP+#nn),IX
	db	#DD,#CB
	dw	#2900 + @r1-#902
	else
	errmac

	endif
	endif
	endif
	else

	if	@r2<%100
	if	@r1<%100	;LD (rr),rr
	dw	#0CFD + @r1*256 +@r2*16*256
	else
	if	@r1<#202	;LD (IX+#nn),rr
	db	#DD,#CB
	dw	#0B00 + (@r1-#102) + @r2*16*256
	else
	if	@r1<#302
	db	#FD,#CB	;LD (IY+#nn),rr
	dw	#0B00 + (@r1-#202) + @r2*16*256
	else
	db	#DD,#CB	;LD (SP+#nn),rr
	dw	#0900 + (@r1-#902) + @r2*16*256

	endif
	endif
	endif

	else
	errmac

	endif
	endif
	endif
	endm

ldrm:	macro	@r2,@r1

	if	@r2=#202	;LD IY,??
	if	@r1<%100	;LD IY,(BC/DE/HL)
	dw	#03FD + @r1*16*256
	else

	if	@r1<#202	;LD IY,(IX+#nn)
	db	#DD,#CB
	dw	#2300 + @r1-#102
	else

	if	@r1<#A02	;IY,LD (SP+#nn)
	db	#FD,#CB
	dw	#2100 + @r1-#902
	else
	errmac

	endif
	endif
	endif
	else

	if	@r2=#102	;LD IX,??
	if	@r1<%100	;LD IX,(BC/DE/HL)
	dw	#03DD + @r1*16*256
	else

	if	@r1<#302	;LD IX,(IY+#nn)
	db	#FD,#CB
	dw	#2300 + @r1-#202
	else

	if	@r1<#A02	;LD IX,(SP+#nn)
	db	#DD,#CB
	dw	#2100 + @r1-#902
	else
	errmac

	endif
	endif
	endif
	else

	if	@r2<%100
	if	@r1<%100	;LD rr,(rr)
	dw	#0CDD + @r1*256 +@r2*16*256
	else
	if	@r1<#202	;LD rr,(IX+#nn)
	db	#DD,#CB
	dw	#0300 + (@r1-#102) + @r2*16*256
	else
	if	@r1<#302
	db	#FD,#CB	;LD rr,(IY+#nn)
	dw	#0300 + (@r1-#202) + @r2*16*256
	else
	db	#DD,#CB	;LD rr,(SP+#nn)
	dw	#0100 + (@r1-#902) + @r2*16*256

	endif
	endif
	endif

	else
	errmac

	endif
	endif
	endif
	endm


	;--- LDW ---

	;    LDW (BC/DE/HL),#nnnn
	;    LDWI I,HL  <--- LDW I,HL
	;    LDWI HL,I  <--- LDW HL,I

ldw:	macro	@r,@n
	dw	#06ED + @r*16*256
	dw	@n
	endm

ldwi:	macro	@r1,@r2
	if	@r2=%11
	db	#DD,#47
	else
	if	@r1=%11
	db	#DD,#57
	endif
	endif
	endm


	;--- LDCTL ---

	;    LDCTL SR,A
	;    LDCTL XSR/DSR/YSR,A
	;    LDCTL A,XSR/DSR/YR
	;    LDCTLI SR,#nn               <--- LDCTL SR,#nn
	;    LDCTLI XSR/DSR/YSR,#nn      <--- LDCTL XSR/DSR/YSR,#nn
	;    LDCTL HL,SR
	;    LDCTL SR,HL

ldctl:	macro	@r1,@r2
	if	@r1=%11
	db	#ED,#C0	;LDCTL HL,SR
	else
	if	@r2=%11
	db	#ED,#C8	;LDCTL SR,HL
	else
	if	@r1>#803
	db	#DD,#C8	;LDCTL SR,A
	else
	if	@r1>#7FF
	dw	#D8CD + (@r1-#800)*16	;LDCTL ?SR,A
	else
	if	@r2>#7FF
	dw	#D0CD + (@r2-#800)*16	;LDCTL A,?SR
	else
	errmac
	endif
	endif
	endif
	endif
	endif
	endm

ldctli:	macro	@r,@n
	if	@r=#804
	db	#DD,#CA	;LDCTL SR,#nn
	db	@n
	else
	if	@r>#7FF
	dw	#DACD + (@r-#800)*16
	db	@n
	else
	errmac
	endif
	endif
	endm


	;--- LDDW ---

lddw:	macro
	db	#ED,#E8
	endm


	;--- LDDRW ---

lddrw:	macro
	db	#ED,#F8
	endm


	;--- LDIW ---

ldiw:	macro
	db	#ED,#E0
	endm


	;--- LDIRW ---

ldirw:	macro
	db	#ED,#F0
	endm


	;--- MLT ---

	;    MLT BC/DE/HL/SP

mlt:	macro	@r
	db	#ED
	if	@r=%11
	db	#6C
	else
	if	@r=%10+#900
	db	#7C
	else
	if	@r<%10
	db	#4C or @r*16
	else
	errmac
	endif
	endif
	endif
	endm


	;--- MTEST ---

mtest:	macro
	db	#DD,#CF
	endm


	;--- MULTW ---

	;    MULTW HL/BC/DE/IX/IY
	;    MULTWX (IX/IY+#nn)   <--- MULTW (IX/IY+#nn)
	;    MULTWI #nnnn         <--- MULTW #nnnn

multw:	macro	@r
	if	@r=#202
	db	#ED,#CB,#95
	else
	if	@r=#102
	db	#ED,#CB,#94
	else
	if	@r<4
	db	#ED,#CB,#90 or @r
	else
	errmac
	endif
	endif
	endif
	endm

multwi:	macro	@n
	db	#ED,#CB,#97
	dw	@n
	endm

multwx:	macro	@d
	if	@d>#201
	db	#FD,#CB
	dw	#9200+(@d-#202)
	else
	if	@d>#101
	db	#DD,#CB
	dw	#9200+(@d-#102)
	else
	errmac
	endif
	endif
	endm


	;--- MULTUW ---

	;    MULTUW HL/BC/DE/IX/IY
	;    MULTUWX (IX/IY+#nn)   <--- MULTUW (IX/IY+#nn)
	;    MULTUWI #nnnn         <--- MULTUW #nnnn

multuw:	macro	@r
	if	@r=#202
	db	#ED,#CB,#9D
	else
	if	@r=#102
	db	#ED,#CB,#9C
	else
	if	@r<4
	db	#ED,#CB,#98 or @r
	else
	errmac
	endif
	endif
	endif
	endm

multuwi:	macro	@n
	db	#ED,#CB,#9F
	dw	@n
	endm

multuwx:	macro	@d
	if	@d>#201
	db	#FD,#CB
	dw	#9A00+(@d-#202)
	else
	if	@d>#101
	db	#DD,#CB
	dw	#9A00+(@d-#102)
	else
	errmac
	endif
	endif
	endm


	;--- NEGW ---

negw:	macro
	db	#ED,#54
	endm


	;--- ORW ---

	;    ORW HL/BC/DE/IX/IY
	;    ORWX (IX/IY+#nn)   <--- ORW (IX/IY+#nn)
	;    ORWI #nnnn         <--- ORW #nnnn

orw:	macro	@r
	if	@r=#202
	db	#FD,#B7
	else
	if	@r=#102
	db	#DD,#B7
	else
	if	@r<4
	db	#ED,#B4 or @r
	else
	errmac
	endif
	endif
	endif
	endm

orwi:	macro	@n
	db	#ED,#B6
	dw	@n
	endm

orwx:	macro	@d
	if	@d>#201
	db	#FD
	dw	#F6+(@d-#202)*256
	else
	if	@d>#101
	db	#DD
	dw	#F6+(@d-#102)*256
	else
	errmac
	endif
	endif
	endm


	;--- OTDM ---

otdm:	macro
	db	#ED,#8B
	endm


	;--- OTDMR ---

otdmr:	macro
	db	#ED,#9B
	endm


	;--- OTDRW ---

otdrw:	macro
	db	#ED,#FB
	endm


	;--- OTIM ---

otim:	macro
	db	#ED,#83
	endm


	;--- OTIMR ---

otimr:	macro
	db	#ED,#93
	endm


	;--- OTIRW ---

otirw:	macro
	db	#ED,#F3
	endm


	;--- OUT0 ---

	;    OUT0 (#nn),A/B/C/D/E/H/L

out0:	macro	@n,@r
	if	@r>#2FF
	dw	#01ED + (@r-#300)*8*256
	db	@n
	else
	errmac
	endif
	endm


	;--- OUTW ---

	;    OUTW (C),BC/DE/HL
	;    OUTWI (C),#nnnn   <--- OUTW (C),#nnnn

outw:	macro	@r1,@r2
	if	@r1=#301
	db	#DD
	if	@r2=%11
	db	#79
	else
	if	@r2=%01
	db	#51
	else
	if	@r2=%00
	db	#41
	else
	errmac
	endif
	endif
	endif
	endif
	endm

outwi:	macro	@r,@n
	if	@r=#301
	db	#FD,#79
	dw	@n
	else
	errmac
	endif
	endm


	;--- OUTA ---

	;    OUTA (#nnnn),A

outa:	macro	@n,@r
	if	@r=#307
	db	#ED,#D3
	dw	@n
	else
	errmac
	endif
	endm


	;--- OUTAW ---

	;    OUTAW (#nnnn),HL

outaw:	macro	@n,@r
	if	@r=%11
	db	#FD,#D3
	dw	@n
	else
	errmac
	endif
	endm


	;--- OUTDW ---

outdw:	macro
	db	#ED,#EB
	endm


	;--- OUTIW ---

outiw:	macro
	db	#ED,#E3
	endm


	;--- POP ---

	;    POP AF/BC/DE/HL/IX/IY
	;    POPSR          <--- POP SR

popsr:	macro
	db	#ED,#C1
	endm


	;--- PUSH ---

	;    PUSH AF/BC/DE/HL/IX/IY
	;    PUSR           <--- PUSH SR
	;    PUSHI #nnnn    <--- PUSH #nnnn

pusr:	macro
	db	#ED,#C5
	endm

pushi:	macro	@n
	db	#FD,#F5
	dw	@n
	endm


	;--- RESC ---

	;    RESC LCK/LW

resc:	macro	@r
	if	@r=%100
	db	#DD,#FF
	else
	if	@r=#902
	db	#ED,#FF
	else
	errmac
	endif
	endif
	endm


	;--- RETB ---

retb:	macro
	db	#ED,#55
	endm


	;--- RLW ---

	;    RLW HL/BC/DE/IX/IY
	;    RLWX (IX/IY+#nn)    <--- RLW (IX/IY+#nn)
	;    RLWX (HL)           <--- RLW (HL)

rlw:	macro	@r
	if	@r=#202
	db	#ED,#CB,#15
	else
	if	@r=#102
	db	#ED,#CB,#14
	else
	if	@r<4
	db	#ED,#CB,#10 or @r
	else
	errmac
	endif
	endif
	endif
	endm

rlwx:	macro	@d
	if	@d=%11
	db	#ED,#CB,#12
	else
	if	@d>#201
	db	#FD,#CB
	dw	#1200+(@d-#202)
	else
	if	@d>#101
	db	#DD,#CB
	dw	#1200+(@d-#102)
	else
	errmac
	endif
	endif
	endif
	endm


	;--- RLCW ---

	;    RLCW HL/BC/DE/IX/IY
	;    RLCWX (IX/IY+#nn)   <--- RLCW (IX/IY+#nn)
	;    RLCWX (HL)          <--- RLCW (HL)

rlcw:	macro	@r
	if	@r=#202
	db	#ED,#CB,#05
	else
	if	@r=#102
	db	#ED,#CB,#04
	else
	if	@r<4
	db	#ED,#CB,#00 or @r
	else
	errmac
	endif
	endif
	endif
	endm

rlcwx:	macro	@d
	if	@d=%11
	db	#ED,#CB,#02
	else
	if	@d>#201
	db	#FD,#CB
	dw	#0200+(@d-#202)
	else
	if	@d>#101
	db	#DD,#CB
	dw	#0200+(@d-#102)
	else
	errmac
	endif
	endif
	endif
	endm


	;--- RRW ---

	;    RRW HL/BC/DE/IX/IY
	;    RRWX (IX/IY+#nn)    <--- RRW (IX/IY+#nn)
	;    RRWX (HL)           <--- RRW (HL)

rrw:	macro	@r
	if	@r=#202
	db	#ED,#CB,#1D
	else
	if	@r=#102
	db	#ED,#CB,#1C
	else
	if	@r<4
	db	#ED,#CB,#18 or @r
	else
	errmac
	endif
	endif
	endif
	endm

rrwx:	macro	@d
	if	@d=%11
	db	#ED,#CB,#1A
	else
	if	@d>#201
	db	#FD,#CB
	dw	#1A00+(@d-#202)
	else
	if	@d>#101
	db	#DD,#CB
	dw	#1A00+(@d-#102)
	else
	errmac
	endif
	endif
	endif
	endm


	;--- RRCW ---

	;    RRCW HL/BC/DE/IX/IY
	;    RRCWX (IX/IY+#nn)   <--- RRCW (IX/IY+#nn)
	;    RRCWX (HL)          <--- RRCW (HL)

rrcw:	macro	@r
	if	@r=#202
	db	#ED,#CB,#0D
	else
	if	@r=#102
	db	#ED,#CB,#0C
	else
	if	@r<4
	db	#ED,#CB,#08 or @r
	else
	errmac
	endif
	endif
	endif
	endm

rrcwx:	macro	@d
	if	@d=%11
	db	#ED,#CB,#0A
	else
	if	@d>#201
	db	#FD,#CB
	dw	#0A00+(@d-#202)
	else
	if	@d>#101
	db	#DD,#CB
	dw	#0A00+(@d-#102)
	else
	errmac
	endif
	endif
	endif
	endm


	;--- SBCW ---

	;    SBCW HL/BC/DE/IX/IY
	;    SBCWX (IX/IY+#nn)   <--- SBCW (IX/IY+#nn)
	;    SBCWI #nnnn         <--- SBCW #nnnn

sbcw:	macro	@r
	if	@r=#202
	db	#FD,#9F
	else
	if	@r=#102
	db	#DD,#9F
	else
	if	@r<4
	db	#ED,#9C or @r
	else
	errmac
	endif
	endif
	endif
	endm

sbcwi:	macro	@n
	db	#ED,#9E
	dw	@n
	endm

sbcwx:	macro	@d
	if	@d>#201
	db	#FD
	dw	#DE+(@d-#202)*256
	else
	if	@d>#102
	db	#DD
	dw	#DE+(@d-#102)*256
	else
	errmac
	endif
	endif
	endm


	;--- SETC ---

	;    SETC LW/LCK/XM

setc:	macro	@r
	if	@r=%100
	setc!	#901
	else
	setc!	@r
	endif
	endm

setc!:	macro	@r
	if	@r>#8FF
	dw	#F7CD + (@r-#900)*16
	else
	errmac
	endif
	endm


	;--- SLAW ---

	;    SLAW HL/BC/DE/IX/IY
	;    SLAWX (IX/IY+#nn)   <--- SLAW (IX/IY+#nn)
	;    SLAWX (HL)          <--- SLAW (HL)

slaw:	macro	@r
	if	@r=#202
	db	#ED,#CB,#25
	else
	if	@r=#102
	db	#ED,#CB,#24
	else
	if	@r<4
	db	#ED,#CB,#20 or @r
	else
	errmac
	endif
	endif
	endif
	endm

slawx:	macro	@d
	if	@d=%11
	db	#ED,#CB,#22
	else
	if	@d>#201
	db	#FD,#CB
	dw	#2200+(@d-#202)
	else
	if	@d>#101
	db	#DD,#CB
	dw	#2200+(@d-#102)
	else
	errmac
	endif
	endif
	endif
	endm


	;--- SLP ---

slp:	macro
	db	#ED,#76
	endm


	;--- SRAW ---

	;    SRAW HL/BC/DE/IX/IY
	;    SRAWX (IX/IY+#nn)   <--- SRAW (IX/IY+#nn)
	;    SRAWX (HL)          <--- SRAW (HL)

sraw:	macro	@r
	if	@r=#202
	db	#ED,#CB,#2D
	else
	if	@r=#102
	db	#ED,#CB,#2C
	else
	if	@r<4
	db	#ED,#CB,#28 or @r
	else
	errmac
	endif
	endif
	endif
	endm

srawx:	macro	@d
	if	@d=%11
	db	#ED,#CB,#2A
	else
	if	@d>#201
	db	#FD,#CB
	dw	#2A00+(@d-#202)
	else
	if	@d>#101
	db	#DD,#CB
	dw	#2A00+(@d-#102)
	else
	errmac
	endif
	endif
	endif
	endm


	;--- SRLW ---

	;    SRLW HL/BC/DE/IX/IY
	;    SRLWX (IX/IY+#nn)   <--- SRLW (IX/IY+#nn)
	;    SRLWX (HL)          <--- SRLW (HL)

srlw:	macro	@r
	if	@r=#202
	db	#ED,#CB,#3D
	else
	if	@r=#102
	db	#ED,#CB,#3C
	else
	if	@r<4
	db	#ED,#CB,#38 or @r
	else
	errmac
	endif
	endif
	endif
	endm

srlwx:	macro	@d
	if	@d=%11
	db	#ED,#CB,#3A
	else
	if	@d>#201
	db	#FD,#CB
	dw	#3A00+(@d-#202)
	else
	if	@d>#101
	db	#DD,#CB
	dw	#3A00+(@d-#102)
	else
	errmac
	endif
	endif
	endif
	endm


	;--- SUBW ---

	;    SUBW HL/BC/DE/IX/IY
	;    SUBWX (IX/IY+#nn)   <--- SUBW (IX/IY+#nn)
	;    SUBWI #nnnn         <--- SUBW #nnnn

	;    SUBSP #nnnn         <--- SUB SP,#nnnn

subw:	macro	@r
	if	@r=#202
	db	#FD,#97
	else
	if	@r=#102
	db	#DD,#97
	else
	if	@r<4
	db	#ED,#94 or @r
	else
	errmac
	endif
	endif
	endif
	endm

subwi:	macro	@n
	db	#ED,#96
	dw	@n
	endm

subwx:	macro	@d
	if	@d>#202
	db	#FD
	dw	#D6+(@d-#202)*256
	else
	if	@d>#FF
	db	#DD
	dw	#D6+(@d-#102)*256
	else
	errmac
	endif
	endif
	endm

subsp:	macro	@n
	db	#ED,#92
	dw	@n
	endm


	;--- SWAP ---

	;    SWAP BC/DE/HL/IX/IY

swap:	macro	@r
	if	@r<4
	db	#ED,#0E or @r*16
	else
	if	@r=#102
	db	#DD,#3E
	else
	if	@r=#202
	db	#FD,#3E
	else
	errmac
	endif
	endif
	endif
	endm


	;--- TST ---

	;    TST A/B/C/D/E/H/L
	;    TST (HL)
	;    TSTI #nn      <--- TST #nn

tst:	macro	@r
	if	@r=%11
	db	#ED,#34
	else
	if	@r>#2FF
	dw	#04ED + (@r-#300)*8*256
	else
	errmac
	endif
	endif
	endm

tsti:	macro	@n
	db	#ED,#64
	db	@n
	endm


	;--- TSTIO ---

	;    TSTIO #nn

tstio:	macro	@n
	db	#ED,#74
	db	@n
	endm


	;--- XORW ---

	;    XORW HL/BC/DE/IX/IY
	;    XORWX (IX/IY+#nn)   <--- XORW (IX/IY+#nn)
	;    XORWI #nnnn         <--- XORW #nnnn

xorw:	macro	@r
	if	@r=#202
	db	#FD,#AF
	else
	if	@r=#102
	db	#DD,#AF
	else
	if	@r<4
	db	#ED,#AC or @r
	else
	errmac
	endif
	endif
	endif
	endm

xorwi:	macro	@n
	db	#ED,#AE
	dw	@n
	endm

xorwx:	macro	@d
	if	@d>#201
	db	#FD
	dw	#EE+(@d-#202)*256
	else
	if	@d>#101
	db	#DD
	dw	#EE+(@d-#102)*256
	else
	errmac
	endif
	endif
	endm
