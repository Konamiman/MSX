; File:SEE3PLAY.asm             Project:SEE v3.10 release A    Update:25/01/94
; Sound Effect Driver v3.10a    coding:SHADOW                  (c) FUZZY LOGIC
; Replay a .SEE file (v3.xx only!)      Original version.
;       You can still replay your version 3.00 files on this driver!!
;
;   * This source is 100% PUBLIC DOMAIN, and may never me sold for profit! *
; The Z80 commands 'EI' and "'DI' are not used, except during H_TIMI set/reset
; Uses ROM-BIOS: &h20 (RST) in the MAIN routine (check it, can be removed...)
; If ye'r using DOS-2.xx then replace the "IN A,(&HFE)" command in SETMAP:.
;
;+-----------------------------------------------------------------------------+

;
; Some space for you to fill... Anybody knows a joke?
;

;+----------------------------[ SEE header ]-----------------------------------+
H_TIMI: EQU   &HFD9F          ;Hook_Timer Interrupt

; Song structure OFFSETS
%SEEID: EQU   &H00            ;ID: "SEE3org", version number
%HISPT: EQU   &H08            ;Highest used Start_pattern
%HIPTA: EQU   &H0A            ;Higest used pattern+1_address
%HISFX: EQU   &H0C            ;Highest used SFX
%_____: EQU   &H0E            ;Unused
%POSTB: EQU   &H10            ;Table with SFX start pattern
%PATTS: EQU   &H0210          ;Pattern data (max 1024 patts)


        ORG   &HC000

;      [Vector Jump Table]
        JP    SEE_IN          ;Init SEE replayer
        JP    SEE_EX          ;Exit SEE replayer
        JP    SETSFX          ;Set a new sound effect
        JP    CUTSFX          ;Cut current sound effect
SEEINT: JP    MAIN.A          ;Main routine jumper (for own timing)

;      [Vars]
SEEADR: DW    &H8000          ;Base address
SEEMAP: DB    1               ;Mapper
SEETID: DB    0               ;Timer I.D.  0=SEE (uses "H_Timi")
;                                          1=Own timing (from other ISR)
SEESTA: DB    0               ;SEE status: b0: 1=SEE is installed
;                                          b1: 1=SFX on (SFX status)
;                                          b2: 1=Busy setting SFX
SFXPRI: DB    0               ;SFX priority: 0=Overwrite, otherwise no effect
;                                           can be set if the current one is
;                                           still playing!
SEEVOL: DB    15              ;Maximum Volume (makes real volume relative!)
;+-----------------------------------------------------------------------------+


;+----- Init SEE -----+
;Out: Carry, 1=not installed (no SEE3 file)
;            0=succes fully installed
SEE_IN: LD    A,(SEESTA)      ;See already installed?
        AND   A               ;[Cy:0]
        RET   NZ              ;Yup, so return

        LD    A,(SEEADR+1)    ;data in page 2 only!
        AND   &HBF
        LD    (SEEADR+1),A

        CALL  SETMAP

        LD    HL,(SEEADR)     ;check file ("SEE3")
        LD    BC,%SEEID
        ADD   HL,BC
        LD    DE,SEE_ID
        LD    B,4
SEEI.0: LD    A,(DE)
        CP    (HL)
        SCF                   ;[Cy:1]
        JP    NZ,RETURN       ;not a SEE3 file!
        INC   HL
        INC   DE
        DJNZ  SEEI.0

        LD    DE,_HISPT       ;copy header
        LD    BC,8
        LDIR

        LD    A,&H01
        LD    (SEESTA),A      ;[status: SEE on]
        DEC   A
        LD    (SFXPRI),A      ;[Priority]

        LD    A,(SEETID)      ;Timing on H_TIMI?
        AND   A               ;[Cy:0]
        JP    NZ,RETURN       ;nope.

; set SEE on Vblank Hook
        DI
        LD    HL,H_TIMI       ;Store intr. hook
        LD    DE,OLDVBL
        LD    BC,5
        LDIR
        LD    DE,H_TIMI       ;Set new intr. hook
        LD    HL,NEWVBL
        LD    BC,5
        LDIR
        EI
        AND   A               ;[Cy:0]
        JP    RETURN

NEWVBL: JP    MAIN            ;This is the new Vblank hook (H_TIMI)
        RET
        RET


;+----- Exit SEE -----+
SEE_EX: LD    A,(SEESTA)      ;See installed?
        AND   A
        RET   Z               ;Nope, so return
        XOR   A
        LD    (SEESTA),A      ;[status: SEE off]

        CALL  PSGOFF

        LD    A,(SEETID)      ;Timing from H_TIMI?
        AND   A
        RET   NZ              ;nope

; reset SEE from Vblank hook
        DI
        LD    HL,OLDVBL       ;Restore intr. hook
        LD    DE,&HFD9F
        LD    BC,5
        LDIR
        EI
        RET


;+----- Set new Sound Effect -----+
;In:   C, SFX nr
;      B, priority (0, low / <>0, high)
;Out:  Cy, 1=SFX not set -> A, error nr
;                               0, SFX doesn't excist
;                               1, previous SFX still playing (higher prior.)
;                             255, SFX not defined (OFF)
SETSFX: LD    A,B             ;New Priority <>0 ?
        AND   A
        JR    NZ,SEFF.0
        LD    A,(SFXPRI)      ;Current SFX priority <>0?
        AND   A
        JR    Z,SEFF.0
        LD    A,(SEESTA)      ;SFX on?
        AND   2               ;[Cy:0]
        SCF                   ;[Cy:1]
        LD    A,1             ;[error nr]
        RET   NZ

SEFF.0: CALL  SETMAP          ;Store and Set mapper

        LD    A,(_HISFX)      ;Max SFX?
        CP    C
        LD    A,0             ;[error nr]
        JP    C,RETURN        ;Cy -> SFX doesn't excist

        LD    L,C
        LD    H,0
        ADD   HL,HL           ;Eff *2
        LD    DE,(SEEADR)
        ADD   HL,DE
        LD    DE,%POSTB
        ADD   HL,DE
        LD    E,(HL)          ;Get start pattern
        INC   HL
        LD    D,(HL)
        LD    A,D
        CP    &HFF            ;in use?...
        SCF                   ;[Cy:1]
        JP    Z,RETURN        ;...nope

;All checks are done, now set SFX:
        LD    A,C
        LD    (SFX_NR),A
        LD    A,B
        LD    (SFXPRI),A

        CALL  CUTSFX

        LD    A,(SEESTA)      ;status:
        OR    &H04            ;b2: Busy setting SFX
        LD    (SEESTA),A      ;(no double SEE int while setting SFX)

        LD    (PAT_NR),DE

        CALL  C_PTAD

        LD    HL,0
        LD    (TEMPO),HL
        LD    A,&H03          ;[status: b0: SEE on
        LD    (SEESTA),A      ;         b1: SFX on]
        AND   A               ;[Cy:0], succesfull
        JP    RETURN


;+----- Cut Sound Effect -----+
CUTSFX: LD    A,(SEESTA)
        AND   1
        RET   Z
        LD    (SEESTA),A
        JP    PSGOFF


;+----- Main routine (timed) / Main.A from own timing -----+
MAIN:   CALL  OLDVBL          ;Call old Vblank first [Timing from H_timi]

;["MAIN.A" from timing other than H_timi ("SEEINT")]
MAIN.A: LD    A,(SEESTA)
        BIT   0,A             ;SEE on?
        RET   Z               ;...nope
        BIT   1,A             ;SFX on?
        RET   Z               ;...nope
        BIT   2,A             ;Busy setting new SFX?
        RET   NZ              ;...Yup!

        LD    A,(TEMPO+1)
        SUB   1
        LD    (TEMPO+1),A
        RET   NC
        LD    A,(TEMPO+0)
        LD    (TEMPO+1),A

        CALL  SETMAP
        LD    HL,(PATADR)
;<
;  The following piece'a code is only an xtra security. It's not realy necessary
;  if ye make correct SEE data! (check for a pattern overflow).
;  This will work as a little delay, and that's something we don't want!!
;  Besides it uses a ROM-BIOS routine, so you'd better remove it if
;  you've set page 0 to RAM and didn't include de RST vector jumps!
        PUSH  HL              ;(HL=current pat adr)
        LD    HL,(SEEADR)     ;[base adr]
        LD    DE,(_HIPTA)     ;[hi pat adr offset]
        ADD   HL,DE
        EX    DE,HL
        POP   HL

        RST   &H20            ; Max patt adr?
        JR    C,MAIN.0

        CALL  CUTSFX          ;Pattern overflow!!
        JP    RETURN
;>

MAIN.0: LD    A,(_HALT)       ;Halt counter
        AND   A
        JR    Z,MAIN.1

        DEC   A
        LD    (_HALT),A
        AND   A
        JP    NZ,RETURN
        JR    MAIN.2          ;previously a HALT event was done, now do PSG

MAIN.1: CALL  !EVENT          ;Do operation command

MAIN.2: CALL  SETPSG          ;Set PSG reg.
        LD    (PATADR),HL
        JP    RETURN


;+----- Event Commands -----+
!EVENT: LD    A,(HL)          ;Get event
        LD    C,A
        AND   &H70
        AND   A
        RET   Z               ;No command

        CP    &H10
        JP    Z,EV_HLT        ;Halt
        CP    &H20
        JP    Z,EV_FOR        ;Loop start
        CP    &H30
        JP    Z,EV_NXT        ;Loop next
        CP    &H40
        JP    Z,EV_STR        ;Continue Loop start
        CP    &H50
        JP    Z,EV_RER        ;Continue Loop next
        CP    &H60
        JP    Z,EV_TEM        ;Tempo
        JP    EV_END          ;End

;- Halt "hlt:x"
EV_HLT: LD    A,C
        AND   &H0F
        LD    (_HALT),A
        POP   AF              ;restore stack
        JP    RETURN

;- Loop start "for:x"
EV_FOR: PUSH  HL

        LD    A,(LOOPNR)      ;Inc loop nr
        INC   A
        AND   &H03
        LD    (LOOPNR),A

        PUSH  HL
        LD    HL,LOOPBF
        LD    D,0
        LD    E,A
        ADD   HL,DE
        ADD   HL,DE
        ADD   HL,DE

        LD    A,C
        AND   &H0F
        LD    (HL),A          ;set Counter
        INC   HL
        POP   DE
        LD    (HL),E          ;set Address
        INC   HL
        LD    (HL),D

        POP   HL
        RET

;- Loop next "next"
EV_NXT: PUSH  HL

        LD    A,(LOOPNR)
        AND   &H03

        LD    HL,LOOPBF
        LD    D,0
        LD    E,A
        ADD   HL,DE
        ADD   HL,DE
        ADD   HL,DE
        DEC   (HL)            ;Dec. counter
        JR    Z,EV_N.0        ;Z, loop end

        INC   HL
        LD    E,(HL)          ;get address
        INC   HL
        LD    D,(HL)

        POP   HL
        EX    DE,HL
        RET

;Loop done, now remove this loop
EV_N.0: LD    A,(LOOPNR)      ;Dec loopnr
        DEC   A
        AND   3
        LD    (LOOPNR),A

        POP   HL
        RET

;- Continue loop start "start"
EV_STR: LD    (CLPADR),HL     ;Store Patt adr.
        RET

;- Continue loop next "rerun"
EV_RER: LD    HL,(CLPADR)
        RET

;- Tempo "tmp:x"
EV_TEM: LD    A,C
        AND   &H0F
        LD    (TEMPO+0),A
        LD    (TEMPO+1),A
        RET

;- Effect end " end "
EV_END: LD    A,1
        LD    (SEESTA),A
        POP   AF              ;restore stack
        JP    RETURN


;+----- Set all PSG regs.-----+
SETPSG: LD    IX,PSGREG
        LD    E,0             ;Start reg.0
        INC   HL              ;[skip event byte]

        LD    B,3             ;First 6 reg. [sound frequency]
STPS.0: PUSH  BC
        LD    C,(HL)          ;r# 0, 2 or 4
        INC   HL
        LD    B,(HL)          ;r# 1, 3 or 5
        BIT   7,(HL)          ;check and handle Tuning
        CALL  NZ,TUNWUP
        BIT   6,(HL)
        CALL  NZ,TUNWDW
        INC   HL
        LD    A,C
        CALL  WRTPSG
        LD    A,B
        AND   &H0F
        CALL  WRTPSG
        POP   BC
        DJNZ  STPS.0

        LD    A,(HL)          ;r# 6 [Rustle frequency]
        INC   HL
        BIT   7,A
        CALL  NZ,TUN_UP
        BIT   6,A
        CALL  NZ,TUN_DW
        AND   &H1F
        CALL  WRTPSG

        LD    A,(HL)          ;r# 7 [channel control, ON/OFF]
        AND   &H3F
        OR    &H80            ;bit 7 is necessary to write the PSG!!
        INC   HL
        CALL  WRTPSG

        LD    B,3             ;r# 8-10 [Volume]
STPS.1: PUSH  BC
        LD    A,(HL)
        INC   HL
        LD    C,A
        AND   &H1F
        LD    B,A             ;Save real volume..
        BIT   4,A
        JP    NZ,STPS.2       ;Volume pattern is set.
        BIT   7,C
        CALL  NZ,TUN_UP
        BIT   6,C
        CALL  NZ,VOL_DW
        LD    B,A             ;Save real volume..
        CALL  FIXVOL
STPS.2:
        CALL  WRTPSG
        LD    (IX-1),B        ; ..Re-Write real volume to buffer (not fixed)
        POP   BC
        DJNZ  STPS.1

        LD    B,3             ;r# 11-13 [volume effect]
STPS_2: LD    A,(HL)
        INC   HL
        CALL  WRTPSG
        DJNZ  STPS_2
        RET


;Tuning
;- byte
TUN_UP: ADD   A,(IX)          ;Up
        RET
TUN_DW: SUB   (IX)            ;Down
        NEG
        RET
;- word
TUNWUP: PUSH  HL
        LD    L,(IX)
        LD    H,(IX+1)
        ADD   HL,BC
        PUSH  HL
        POP   BC
        POP   HL
        RET
TUNWDW: PUSH  HL
        LD    L,(IX)
        LD    H,(IX+1)
        XOR   A
        SBC   HL,BC
        PUSH  HL
        POP   BC
        POP   HL
        RET

;Volume Down
VOL_DW: AND   &H0F
        LD    B,A
        LD    A,(IX+0)
        AND   &H0F
        SUB   B
        RET   NC
        XOR   A
        RET


;Make relative volume (depending on "SEEVOL")
;In:  A, volume
;Out: A, new volume [seevol - (15-volume)]
FIXVOL: AND   &H0F
        XOR   15
        LD    C,A
        LD    A,(SEEVOL)
        AND   &H0F
        SUB   C
        RET   NC
        XOR   A
        RET


;Shut up PSG!
PSGOFF: LD    A,7
        OUT   (&HA0),A
        LD    A,&H3F OR &H80
        OUT   (&HA1),A
        RET


;Write PSG (not ROM-BIOS compatible!)
;In:   A, data
;      E, port
;     IX, PSG store table
;Out:  E+1
;     IX+1
WRTPSG: LD    (IX),A
        INC   IX
        PUSH  AF
        LD    A,E
        OUT   (&HA0),A
        INC   E
        POP   AF
        OUT   (&HA1),A
        RET


;Calculate pattern address (only for "SEE3org" files)
;In:  (PAT_NR), pattern nr (0-$3FF)
;Out: (PATADR), pattern adr
;           DE, pattern adr
C_PTAD: PUSH  AF
        PUSH  HL
        PUSH  BC
        LD    HL,(SEEADR)
        LD    BC,%PATTS
        ADD   HL,BC
        LD    BC,(PAT_NR)
        LD    DE,15
C_PA.0: LD    A,B
        OR    C
        JR    Z,C_PA.1
        ADD   HL,DE
        DEC   BC
        JP    C_PA.0
C_PA.1: LD    (PATADR),HL
        EX    DE,HL
        POP   BC
        POP   HL
        POP   AF
        RET


; When using DOS2, use other mapper routs (not: OUT (&HFE),A / IN A,(&HFE) !)

;Store current mapper and Set SEE mapper
SETMAP: PUSH  AF
        IN    A,(&HFE)        ;Store old mapper
        LD    (OLDMAP),A
        LD    A,(SEEMAP)      ;Set SEE mapper
        OUT   (&HFE),A
        POP   AF
        RET


;+----- Return from SEE-driver, restore map -----+
RETURN: PUSH  AF
        LD    A,(OLDMAP)
        OUT   (&HFE),A
        POP   AF
        RET


;+----------------------------< Work Area >------------------------------------+
SEE_ID: DM    "SEE3???",&H10  ;ID + filetype + vers.nr
TEMPO:  DB    0,0             ;[Original, counter]
PAT_NR: DW    0               ;Current pattern (0-1023) (temp)
PATADR: DS    2               ;Current pattern address
SFX_NR: DB    0               ;Current Sound Effect (0-255)
_HALT:  DB    0               ;Halt counter (0-15)
LOOPNR: DB    0               ;Current loop number (0-3)
LOOPBF: DS    4*3             ;[4 x Counter+Address]
CLPADR: DW    &H00            ;"Continue-loop" / "Restart" address

;Copy from Song structure OFFSETS
_SEEID: DS    8               ;"SEE3EDIT"
_HISPT: DS    2               ;Highest used Start_pattern
_HIPTA: DS    2               ;Higest used pattern+1_address
_HISFX: DS    2               ;Highest used SFX
_FLELN: DS    2               ;File length
_POSTB: DS    2               ;Table with SFX start pattern
_PATTS: DS    2               ;Pattern data (max 1024 patts)

;       reg.  0 1 2 3 4 5 6 7 8 9 A B C D
PSGREG: DB    0,0,0,0,0,0,0,0,0,0,0,0,0,0 ;   - PSG port store buffer -

OLDVBL: DS    5               ;Old Vblank Interrupt (H_timi)
OLDMAP: DB    0               ;Stored mapper (page 2)

        END
L: DS    5