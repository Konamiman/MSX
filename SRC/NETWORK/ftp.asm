        ;--- FTP 1.0 - FTP client for the TCP/IP UNAPI
        ;    By Konamiman, 4/2010
        ;
        ;    Can be complied with sjasm 0.39 (https://github.com/Konamiman/Sjasm/releases):
        ;    sjasm ftp.asm ftp.com

;*****************************
;***                       ***
;***   MACROS, CONSTANTS   ***
;***                       ***
;*****************************

        macro nesman func      ;Indirect call to NestorMan functions
        ld      c,func
        ld      de,2202h
        call    0FFCAh
        endm

        macro print str      ;Print a "$" terminated string
        ld      de,str
        ld      c,_STROUT
        call    DO_DOS
        endm

        macro printl str      ;Print a CRLF terminated string
        ld      de,str
        call    PRINT_L
        endm

        macro printz str      ;Print a zero terminated string
        ld      de,str
        call    PRINT_Z
        endm

_TERM0: equ     00h
_CONOUT:        equ     02h     ;Some DOS function calls
_DIRIO: equ     06h
_INNOE: equ     08h
_STROUT:        equ     09h
_BUFIN: equ     0Ah
_CONST: equ     0Bh
_SELDSK:        equ     0Eh
_CURDRV:        equ     19h
_ALLOC: equ     1Bh
_FFIRST:        equ     40h
_FNEXT: equ     41h
_OPEN:  equ     43h
_CREATE:        equ     44h
_CLOSE: equ     45h
_READ:  equ     48h
_WRITE: equ     49h
_DELETE:        equ     4Dh
_RENAME:        equ     4Eh
_ATTR:  equ     50h
_GETCD: equ     59h
_CHDIR: equ     5Ah
_PARSE: equ     5Bh
_TERM:  equ     62h
_DEFAB: equ     63h
_ERROR: equ     65h
_EXPLAIN:       equ     66h
_GENV:  equ     6Bh
_DOSVER:        equ     6Fh

ENASLT: equ     0024h   ;Slot swithcing BIOS routine
BEEP:   equ     00C0h   ;Generates a BEEP
CALSLT: equ     001Ch   ;Calls a routine on another slot

TPASLOT1:       equ     0F342h
ARG:    equ     0F847h
H_CHPH: equ     0FDA4h   ;Gancho CHPUT
EXTBIO: equ     0FFCAh

        ;--- TCP/IP UNAPI routines

TCPIP_GET_CAPAB:        equ     1
TCPIP_GET_IPINFO:       equ     2
TCPIP_NET_STATE:        equ     3
TCPIP_DNS_Q:    equ     6
TCPIP_DNS_S:    equ     7
TCPIP_TCP_OPEN: equ     13
TCPIP_TCP_CLOSE:        equ     14
TCPIP_TCP_ABORT:        equ     15
TCPIP_TCP_STATE:        equ     16
TCPIP_TCP_SEND: equ     17
TCPIP_TCP_RCV:  equ     18
TCPIP_WAIT:     equ     29

        ;--- TCP/IP UNAPI error codes

ERR_OK:                 equ     0
ERR_NOT_IMP:            equ     1
ERR_NO_NETWORK:         equ     2
ERR_NO_DATA:            equ     3
ERR_INV_PARAM:          equ     4
ERR_QUERY_EXISTS:       equ     5
ERR_INV_IP:             equ     6
ERR_NO_DNS:             equ     7
ERR_DNS:                equ     8
ERR_NO_FREE_CONN:       equ     9
ERR_CONN_EXISTS:        equ     10
ERR_NO_CONN:            equ     11
ERR_CONN_STATE:         equ     12
ERR_BUFFER:             equ     13
ERR_LARGE_DGRAM:        equ     14
ERR_INV_OPER:           equ     15

        macro debug char
        push    af
        push    bc
        push    de
        push    hl
        ld      e,@c
        ld      c,2
        call    DO_DOS
        pop     hl
        pop     de
        pop     bc
        pop     af
        endm


;**************************
;***                    ***
;***   INITIALIZATION   ***
;***                    ***
;**************************

        org     100h

        ld      hl,DATA
        ld      de,8000h
        ld      bc,DATA_END-DATA_START
        ldir

        ld      a,0FFh
        ld      (USER_COM_BUF),a

        ;--- Muestra la cadena inicial

        print   PRESEN_S        ;Presentation string
        ld      (SAVESP),sp

        ;--- Comprueba la version del DOS

        ld      c,_DOSVER
        call    DO_DOS
        or      a
        jr      nz,NODOS2
        ld      a,b
        cp      2
        jr      z,OKDOS2

NODOS2: print   NODOS2_S
        ld      c,_TERM0
        jp      DO_DOS

NODOS2_S:       db      "*** Sorry, this program is for DOS 2 only$"
OKDOS2:

        ;--- Search the TCP/IP UNAPI implementation

        ld      hl,TCPIP_S
        ld      de,ARG
        ld      bc,15
        ldir

        xor     a
        ld      b,0
        ld      de,2222h
        call    EXTBIO
        ld      a,b
        or      a
        jr      nz,OKINS

        print   NOTCPIP_S
        ld      c,_TERM0
        jp      DO_DOS

TCPIP_S:        db      "TCP/IP",0
NOTCPIP_S:      db      "*** No TCP/IP UNAPI implementation found.",13,10,"$"
OKINS:  ;

        ;--- Setup the UNAPI calling code

        ld      a,1
        ld      de,2222h
        call    EXTBIO

        ld      (DO_UNAPI+1),hl
        ld      c,a
        ld      a,h
        cp      0C0h
        ld      a,c
        jr      c,NO_UNAPI_P3

        ld      a,0C9h
        ld      (SET_UNAPI),a
        jr      OK_SET_UNAPI
NO_UNAPI_P3:

        ld      (UNAPI_SLOT+1),a
        ld      a,b
        cp      0FFh
        jr      nz,NO_UNAPI_ROM

        ld      a,0C9h
        ld      (UNAPI_SEG),a
        jr      OK_SET_UNAPI
NO_UNAPI_ROM:

        ld      (UNAPI_SEG+1),a
OK_SET_UNAPI:

        ;--- Get mapper support routines (we need GET_P1 and PUT_P1)

        ld      de,0402h
        xor     a
        call    EXTBIO
        or      a
        jr      z,NOMAPPER

        ld      bc,10*3 ;Skip ALL_SEG to GET_P0
        add     hl,bc
        ld      de,PUT_P1
        ld      bc,2*3
        ldir

        call    GET_P1
        ld      (TPASEG1),a
NOMAPPER:

        ;--- Comprueba que realmente estemos conectados,
        ;    en caso contrario muestra error y termina

        ld      a,TCPIP_NET_STATE       ;La red esta disponible?
        call    CALL_UNAPI
        or      a
        jr      z,CONNECT_OK    ;Assume ok if "unknown"
        cp      2
        jr      z,CONNECT_OK

        print   NOCON_S
        jp      TERM

NOCON_S:        db      "*** No network connection",13,10,"$"
CONNECT_OK:     ;

        ;--- Check if this implementation can open active and passive TCP connections

        ld      b,1
        ld      a,TCPIP_GET_CAPAB
        call    CALL_UNAPI

        bit     3,l
        jr      nz,CAN_ACTIVE
        print   NOTCPA_S
        jp      TERM

NOTCPA_S:       db      "*** This TCP/IP UNAPI implementation does not support",13,10
                db      "    opening active TCP connections.",13,10,"$"
CAN_ACTIVE:

        bit     5,l
        jp      nz,CAN_PASSIVE
        print   NOTCPPU_S
        jp      TERM

NOTCPPU_S:      db      "*** This TCP/IP UNAPI implementation does not support",13,10
        db      "    opening passive TCP connections with remote socket unespecified.",13,10,"$"
CAN_PASSIVE:

        ;--- Clear all transient connections

        ld      a,TCPIP_TCP_CLOSE
        ld      b,0
        call    CALL_UNAPI

        ;--- Comprueba que haya al menos dos conexiones TCP libres

        ld      b,2
        ld      a,TCPIP_GET_CAPAB
        call    CALL_UNAPI
        ld      a,d
        cp      2
        jr      nc,OKFRCON

        print   NOFRCON_S
        jp      TERM
NOFRCON_S:      db      "*** Not enough free TCP connections available (I need two)$"
OKFRCON:

        ;--- Comprueba que NestorMan 1.21 o superior este instalado,
        ;    y establece HAY_NMAN en ese caso

        xor     a       ;Installed?
        nesman  1
        or      a
        jr      z,OKNMAN

OKNMAN1:        ld      hl,0201h        ;Installed: now check version
        ex      de,hl
        call    COMP
        jr      nc,OKNMAN

        ld      a,0FFh
        ld      (HAY_NMAN),a
OKNMAN:

        ;--- Obtiene la IP local.
        ;    Con esta informacion compone la primera parte
        ;    de la cadena que forma el comando "PORT".

        ld      a,TCPIP_GET_IPINFO
        ld      b,1
        call    CALL_UNAPI
        ld      (IP_LOCAL),hl
        ld      (IP_LOCAL+2),de

        ld      a,l
        call    SET_IP
        ld      a,h
        call    SET_IP
        ld      a,e
        call    SET_IP
        ld      a,d
        call    SET_IP
        jr      OK_SET_PORT

SET_IP: push    hl
        push    de
        ld      e,a
        ld      d,0
        ld      b,1
        xor     a
        ld      hl,(PORT_C_PNT)
        call    NUMTOASC
        ld      c,b
        ld      b,0
        add     hl,bc
        ld      (hl),","
        inc     hl
        ld      (PORT_C_PNT),hl
        pop     de
        pop     hl
        ret
OK_SET_PORT:    ;

        ;--- Compone DEF_USER y DEF_PASSWORD

        ld      hl,ENV_USER
        ld      de,DEF_USER
        ld      b,255
        ld      c,_GENV
        call    DO_DOS

        ld      hl,ENV_PASSWORD
        ld      de,DEF_PASSWORD
        ld      b,255
        ld      c,_GENV
        call    DO_DOS

        ld      hl,ENV_ACCOUNT
        ld      de,DEF_ACCOUNT
        ld      b,255
        ld      c,_GENV
        call    DO_DOS

        ld      a,(DEF_USER)
        or      a
        jr      nz,OK_DEFUSER
        ld      hl,ANONYMOUS_S
        ld      de,DEF_USER     ;Por si no hay variable FTP_USER
        ld      bc,10
        ldir
OK_DEFUSER:     ;

        ;--- Copia el codigo del gancho CHPUT

        ld      hl,HOOK_CODE0
        ld      de,HOOK_CODE
        ld      bc,HOOK_CODE0_END-HOOK_CODE0
        ldir

        ld      hl,H_CHPH
        ld      de,HOOK_OLD
        ld      bc,5
        ldir

        xor     a
        ld      (ESC_CHAR),a

        ;--- Define la rutina de terminacion

        ld      de,R_ABORT
        ld      c,_DEFAB
        call    DO_DOS

        ;--- Si hay parametros, salta a OPEN

        ld      hl,80h
        ld      de,USER_COM_BUF+1
        ld      a,1
        call    EXTPAR
        jr      c,NOPARS

        ld      hl,81h  ;Copia el comando ficticio "X"
        ld      de,USER_COM_BUF+3
        ld      bc,255  ;y los parametros a USER_COM_BUF,
        ldir
        ld      a,(80h) ;entonces salta a OPEN
        inc     a
        inc     a
        ld      (USER_COM_BUF+1),a
        ld      hl," X"
        ld      (USER_COM_BUF+2),hl
        call    R_OPEN
NOPARS: ;



;*****************************
;***                       ***
;***   MAIN PROGRAM LOOP   ***
;***                       ***
;*****************************

MAIN_LOOP:      ld      sp,(SAVESP)

        ;--- Pone ABORT_STAT a 1 o a 2

        ld      a,(CONTROL_CON)
        cp      0FFh
        ld      a,1
        jr      z,MAINLOP_2
        inc     a
MAINLOP_2:      ld      (ABORT_STAT),a

        ;--- Imprime prompt y queda a la espera de un comando

        xor     a
        ld      (ES_XCOM),a
        print   FTP_S

        ld      de,USER_COM_BUF
        ld      c,_BUFIN
        call    DO_DOS
        call    LF

        ld      a,(USER_COM_BUF+1)      ;Anyade 0 al final
        ld      c,a
        ld      b,0
        ld      hl,USER_COM_BUF+2
        add     hl,bc
        ld      (hl),0

        ;--- Busca en la tabla el comando adecuado,
        ;    y salta a su rutina.
        ;    Si no existe, muestra "Unknown command".

        ld      hl,USER_COM_BUF+1
        ld      de,PARSE_BUF
        ld      a,1
        call    EXTPAR
        jr      c,MAIN_LOOP

        ld      a,(PARSE_BUF)
        cp      "!"
        jr      nz,NOADMIRA

        ld      hl,R_LITERAL!
        jr      COM_OK

NOADMIRA:       ld      hl,PARSE_BUF
        call    SEARCH_COM
        jr      nc,COM_OK

        print   UNKCOM_S
        jr      MAIN_LOOP

COM_OK: ld      a,(CONTROL_CON) ;Flushea datos si hay conexion
        cp      0FFh
        jr      z,COM_OK2
        ;call     TCP_STATUS
        ;jr      c,COM_OK2
        ;cp      4
        ;jr      nz,COM_OK2
        push    hl
        call    R_FLUSH
        pop     hl
COM_OK2:        call    JP_HL   ;Ejecuta comando

        ld      a,(BELL)
        or      a
        jr      z,MAIN_LOOP

        ld      iy,(0FCC1h-1)    ;Ejecuta BEEP si BELL=0FFh
        ld      ix,BEEP
        call    CALSLT
        jp      MAIN_LOOP



;************************
;***                  ***
;***   USER COMMANDS  ***
;***                  ***
;************************

;-----------------
;---  ?, HELP  ---
;-----------------

R_HELP: ld      a,3
        ld      (ABORT_STAT),a

        ld      hl,USER_COM_BUF+1
        ld      de,PARSE_BUF
        ld      a,2
        call    EXTPAR
        jr      nc,COMM_HELP

        print   BIGHELP_H       ;Solo "HELP": Muestra ayuda general
        ret

COMM_HELP:      cp      2
        jp      nz,R_INVPAR     ;Mas de un parametro: error

COMM_HELP2:     ld      hl,PARSE_BUF
        call    SEARCH_COM
        jr      nc,COMM_HELP3

        ld      e,34
        ld      c,_CONOUT
        call    DO_DOS
        printz  PARSE_BUF
        ld      e,34
        ld      c,_CONOUT
        call    DO_DOS
        print   NOHELP_S        ;No existe ese comando: error
        ret

COMM_HELP3:     push    de
        call    LF
        pop     de
        ld      c,_STROUT
        call    DO_DOS
        jp      LF


;----------------
;---  APPEND  ---
;----------------

R_APPEND:       ld      a,3
        ld      hl,C_APPE

        jp      R_SEND_APP


;---------------
;---  ASCII  ---
;---------------

R_ASCII:        ld      a,4
        ld      (ABORT_STAT),a

        xor     a
        push    af
        ld      a,"A"

R_ASCBIN:       ld      (SEND_COM_BUF+5),a
        ld      hl,0A0Dh        ;Vuelve con Cy=1 en caso de error
        ld      (SEND_COM_BUF+6),hl     ;(usado por R_DIR)
        ld      hl,C_TYPE
        call    SET_COMMAND
        call    SET_SPACE
        call    AUTOMATA_NO1
        pop     bc
        ret     c
        ld      a,b
        ld      (TYPE),a
        or      a
        ret


;--------------
;---  BELL  ---
;--------------

R_BELL: ld      a,3
        ld      (ABORT_STAT),a

        ld      hl,BELL
        ld      de,BELL_M_S
        jp      TURN_ON_OFF


;----------------
;---  BINARY  ---
;----------------

R_BINARY:       ;ld      a,4
        ;ld      (ABORT_STAT),a

        ld      a,0FFh
        push    af
        ld      a,"I"

        jp      R_ASCBIN


;------------
;---  CD  ---
;------------

R_CD:   call    CHK_CON
        ret     c

        ld      a,4
        ld      (ABORT_STAT),a

        ld      hl,USER_COM_BUF+1
        ld      de,SEND_COM_BUF+4
        ld      a,2
        call    EXTPAR
        jp      c,R_PWD

        ld      a,0FFh
        ld      (ES_XCOM),a
        ld      hl,C_CWD
        jp      PARAM_XCOM


;--------------
;---  CDUP  ---
;--------------

R_CDUP: call    CHK_CON
        ret     c

        ld      a,4
        ld      (ABORT_STAT),a

        ld      hl,C_CDUP
        ld      a,(XCOM)
        or      a
        jp      z,SINGLE_COM
        ld      hl,C_XCUP
        jp      SINGLE_COM


;---------------
;---  CLOSE  ---
;---------------

R_CLOSE:        call    CHK_CON
        ret     c

        ld      a,5
        ld      (ABORT_STAT),a

        ld      a,0FFh
        ld      (QUITTING),a
        ld      hl,C_QUIT
        call    SET_COMMAND
        call    APPEND_LF
        call    AUTOMATA_NO1
        ld      a,(CONTROL_CON)
        ld      b,a
        ld      a,TCPIP_TCP_CLOSE
        call    CALL_UNAPI
        ld      a,0FFh
        ld      (CONTROL_CON),a
        xor     a
        ld      (QUITTING),a
        ld      (GCDATA_COUNT),a
        ld      (TYPE),a
        jp      MAIN_LOOP


;---------------
;---  DEBUG  ---
;---------------

R_DEBUG:        ld      a,3
        ld      (ABORT_STAT),a

        ld      hl,DEBUG
        ld      de,DEBUG_M_S
        jp      TURN_ON_OFF


;----------------
;---  DELETE  ---
;----------------

R_DELETE:       call    CHK_CON
        ret     c

        ld      a,4
        ld      (ABORT_STAT),a

        ld      hl,USER_COM_BUF+1
        ld      de,SEND_COM_BUF+5
        ld      a,2
        call    EXTPAR
        ld      hl,C_DELE
        jp      nc,PARAM_COM
        jp      R_INVPAR


;-------------
;---  DIR  ---
;-------------

R_DIR:  ld      hl,C_LIST
R_DIR_LS:       ld      (RETR_COM),hl

        ld      a,4
        ld      (ABORT_STAT),a

        ld      hl,USER_COM_BUF+1       ;Busca tercer parametro
        ld      de,DATA_BUF     ;(nombre de fichero)
        ld      a,3
        call    EXTPAR
        jr      c,R_DIR_LS2

        call    CLOSE_FILE      ;Crea el fichero
        ld      c,_CREATE
        ld      de,DATA_BUF
        xor     a
        ld      b,0
        call    DOS
        ret     c
        ld      a,b
        ld      (FILE_FH),a

R_DIR_LS2:      ld      a,2     ;Ejecuta comando
        ld      (RETR_PAR),a
        ld      a,0FFh
        ld      (MUST_ASCII),a
        jp      RETRIEVE


;---------------
;---  FLUSH  ---  (ejecutado por el bucle principal)
;---------------

R_FLUSH:        ld      a,3
        ld      (ABORT_STAT),a

        ;call    CHK_CON
        ;ret     c

R_FLUSH2:
        ld      a,(CONTROL_CON) ;Hay datos sin recoger?
        ld      b,a
        ld      hl,0
        ld      a,TCPIP_TCP_STATE
        call    CALL_UNAPI
        or      a
        ret     z
        ld      a,h
        or      l
        jr      nz,R_FLUSH2!

        ld      a,(GCDATA_COUNT)        ;Hay datos recogidos pero no consumidos?
        or      a
        ret     z

R_FLUSH2!:      print   FLUSHED_S
R_FLUSH3:       call    GET_CDATA
        jr      c,R_FLUSH_END
        push    af
        ld      e,a
        ld      c,_CONOUT
        call    DO_DOS
        pop     af
        cp      10
        jr      z,R_FLUSH2
        jr      R_FLUSH3

R_FLUSH_END:    call    CRLF
        ret


;-------------
;---  GET  ---
;-------------

R_GET:  ld      a,4
        ld      (ABORT_STAT),a

        ld      hl,C_RETR       ;Coge el fichero
        ld      (RETR_COM),hl
        ld      hl,USER_COM_BUF+1       ;Error si no hay parametros
        ld      de,PARSE_BUF
        ld      a,2
        call    EXTPAR
        jp      c,R_INVPAR

        call    CLOSE_FILE      ;Crea el fichero
        ld      c,_CREATE
        ld      de,PARSE_BUF
        xor     a
        ld      b,0
        call    DOS
        ret     c
        ld      a,b
        ld      (FILE_FH),a

        ld      hl,C_RETR       ;Coge el fichero
        ld      (RETR_COM),hl
        ld      a,2
        ld      (RETR_PAR),a
        xor     a
        ld      (MUST_ASCII),a
        jp      RETRIEVE


;--------------
;---  HASH  ---
;--------------

R_HASH: ld      a,3
        ld      (ABORT_STAT),a

        ld      hl,HASH
        ld      de,HASH_M_S
        jp      TURN_ON_OFF


;-------------
;---  LCD  ---
;-------------

R_LCD:  ld      a,3
        ld      (ABORT_STAT),a

        ld      hl,USER_COM_BUF+1
        ld      de,RESPONSE_BUF
        ld      a,2
        call    EXTPAR
        jr      nc,LCD_SET

        ;--- No se ha especificado parametro:
        ;    muestra unidad+dir actual

        print   CURPATH_S
        jp      PRINT_PATH

        ;--- Se ha especificado parametro:
        ;    Establece unidad y/o directorio

LCD_SET:        ld      c,_PARSE
        ld      b,0
        ld      de,RESPONSE_BUF
        call    DO_DOS

        bit     2,b
        ld      de,RESPONSE_BUF
        ld      h,b
        jr      z,LCD_NODRIVE

        push    bc
        ld      e,c     ;Establece unidad
        dec     e
        ld      c,_SELDSK
        call    DO_DOS
        ld      c,_ERROR
        call    DO_DOS
        pop     hl
        ld      a,b
        or      a
        jp      nz,DOS2
        ld      de,RESPONSE_BUF+2

LCD_NODRIVE:    ;
        bit     0,h
        jr      z,LCD_NOPATH

        ld      c,_CHDIR        ;Establece directorio
        call    DOS
        ret     c

LCD_END:        print   PATHCHAN_S
        jp      PRINT_PATH

LCD_NOPATH:     ld      a,92 ;"\"   ;Si se especifica unidad pero no dir,
        ld      (RESPONSE_BUF+2),a      ;se muestra el dir actual
        ld      c,_GETCD
        ld      de,RESPONSE_BUF+3
        ld      c,_GETCD
        call    DO_DOS

        jr      LCD_END


;-----------------
;---  LDELETE  ---
;-----------------

R_LDELETE:      ;ld     a,0FFh
        ;ld     (LDIR_EXE),a
        call    _R_LDELETE
        xor     a
        ld      (LDIR_EXE),a
        ret

_R_LDELETE:     ld      a,4
        ld      (ABORT_STAT),a

        xor     a
        ld      (ALSO_RONLY),a
        ld      (BORRALGUNO),a
        ld      a,(PROMPT)
        cpl
        ld      (ALLFILES),a
        ld      hl,USER_COM_BUF+1
        ld      de,PARSE_BUF    ;Extrae nombre(s)
        ld      a,2
        call    EXTPAR
        jp      c,R_INVPAR

        ld      hl,USER_COM_BUF+1       ;Busca parametro "R",
        ld      de,RESPONSE_BUF ;si lo encuentra establece ALSO_RONLY
        ld      a,3
        call    EXTPAR
        jr      c,RLDEL2
        ld      a,(RESPONSE_BUF+1)
        or      a
        jp      nz,R_INVPAR
        ld      a,(RESPONSE_BUF)
        or      00100000b
        cp      "r"
        jp      nz,R_INVPAR
        ld      a,0FFh
        ld      (ALSO_RONLY),a
RLDEL2: ;

        ;--- Busca el primer (o siguiente) fichero disponible

        ld      c,_FFIRST
        ld      de,PARSE_BUF
        ld      b,00111b        ;Incluye ficheros ocultos y de sistema
R_LDELLOOP:             ld      ix,USER_COM_BUF+1
        call    DOS     ;Realiza la busqueda
        jr      c,R_LDELEND
        ld      a,0FFh   ;Solo imprimira "file not found"
        ld      (LDIR_EXE),a    ;si no encuentra el primero

        ;--- Comprueba si es de solo lectura,
        ;    en ese caso se lo salta si ALSO_RONLY=0

        ld      a,(USER_COM_BUF+15)
        bit     0,a
        jr      z,LDEL_NORO

        ld      a,(ALSO_RONLY)
        or      a
        jr      z,LDEL_NODEL
LDEL_NORO:      ;

        ;--- Si ALLFILES=0FFh, pregunta
        ;    si se quiere borrar; si no, lo borra directamente

        ld      a,(ALLFILES)
        or      a
        jr      nz,LDEL_DEL

        print   DELETE_S
        printz  USER_COM_BUF+2
        call    ASK_YNAC
        or      a
        jr      z,LDEL_DEL
        cp      1
        jr      z,LDEL_NODEL
        cp      3
        jr      z,LDEL_CANCEL
        ld      a,0FFh
        ld      (ALLFILES),a

        ;--- Borrar fichero: primero le quita
        ;    el atributo de solo lectura si lo tiene

LDEL_DEL:       ld      a,(USER_COM_BUF+15)
        bit     0,a
        jr      z,LDEL_DEL2
        ld      l,a
        res     0,l
        ld      c,_ATTR
        ld      de,USER_COM_BUF+1       ;Quita el atributo "Read only"
        ld      a,1
        call    DOS
        ret     c

LDEL_DEL2:      ld      de,USER_COM_BUF+1       ;Borra el fichero
        ld      c,_DELETE
        call    DOS
        ret     c
        ld      a,0FFh
        ld      (BORRALGUNO),a

        ;--- Pasa al siguiente fichero

LDEL_NODEL:     ld      c,_FNEXT
        jp      R_LDELLOOP

        ;--- Proceso completado

R_LDELEND:      ld      a,(LDIR_EXE)
        or      a
        ret     z
        ld      a,(BORRALGUNO)
        or      a
        ret     z
        print   OPCOMP_S
        ret

        ;--- Finalizacion

LDEL_CANCEL:    print   OPCAN_S
        ret

BORRALGUNO:     db      0       ;Al final sera 0 si no se ha borrado nada


;--------------
;---  LDIR  ---
;--------------

R_LDIR: ld      a,0FFh
        ld      (LDIR_EXE),a
        call    _R_LDIR
        xor     a
        ld      (LDIR_EXE),a
        ret

_R_LDIR:        ld      a,3
        ld      (ABORT_STAT),a

        xor     a
        ld      (RESPONSE_BUF),a        ;Extrae mascara
        ld      hl,USER_COM_BUF+1
        ld      de,RESPONSE_BUF
        ld      a,2
        call    EXTPAR

        ld      de,RESPONSE_BUF ;Obtiene unidad a la que se refiere la mascara
        ld      b,0
        ld      c,_PARSE
        call    DO_DOS
        ld      a,c
        ld      (LDIR_DRV),a

        ;print  DIROF_S ;Muestra "Directory of "+ruta
        ;call   PRINT_PATH
        call    CRLF
        ld      hl,0
        ld      (LDIR_FILES),hl
        ld      (LDIR_DIRS),hl

        ld      c,_FFIRST
        ld      de,RESPONSE_BUF
        ld      b,10111b        ;Incluye directorios, ocultos y de sistema
R_LDIRLOOP:             ld      ix,USER_COM_BUF+1
        call    DOS     ;Realiza la busqueda
        jp      c,LDIR_END

        ld      hl,USER_COM_BUF+2-1     ;Ajusta nombre de fichero
        ld      b,12    ;para que ocupe exatamente 12 caracteres
R_LDIRLOP2:     inc     hl      ;(rellena con espacios)
        ld      a,(hl)
        or      a
        jr      z,R_LDIRLOP3
        djnz    R_LDIRLOP2
        jr      R_LDIRLOP4
R_LDIRLOP3:     ld      (hl)," "
        inc     hl
        djnz    R_LDIRLOP3
R_LDIRLOP4:     xor     a
        ld      (USER_COM_BUF+2+12),a
        printz  USER_COM_BUF+2

        ld      a," "
        ld      (ATRIB_S+1),a
        ld      (ATRIB_S+2),a
        ld      (ATRIB_S+3),a
        ld      a,(USER_COM_BUF+15)     ;Imprime atributos
        bit     0,a
        jr      z,LDIR_AT1
        push    af
        ld      a,"r"   ;Read only
        ld      (ATRIB_S+1),a
        pop     af
LDIR_AT1:       bit     1,a
        jr      z,LDIR_AT2
        push    af
        ld      a,"h"   ;Hidden
        ld      (ATRIB_S+2),a
        pop     af
LDIR_AT2:       bit     2,a
        jr      z,LDIR_AT3
        push    af
        ld      a,"s"   ;System
        ld      (ATRIB_S+3),a
        pop     af
LDIR_AT3:       push    af
        print   ATRIB_S
        pop     af

        bit     4,a
        jr      z,LDIR_ESFILE
LDIR_ESDIR:     ;Es directorio?     Imprime "<dir>"
        print   ESDIR_S
        ld      hl,(LDIR_DIRS)
        inc     hl
        ld      (LDIR_DIRS),hl
        jr      LDIR_OKFILE

LDIR_ESFILE:    ld      hl,(LDIR_FILES) ;Es fichero? Imprime tamanyo
        inc     hl
        ld      (LDIR_FILES),hl
        ld      ix,USER_COM_BUF+22      ;IX=Tamanyo del fichero
        ld      a,(ix+2)
        or      (ix+3)
        ld      e,(ix)
        ld      d,(ix+1)
        jr      z,LDIR_PEQUEN   ;"Grande" si es mayor de 64K
        ;ld     a,(ix+1)
        ;and     11000000b
        ;ld     e,(ix)
        ;ld      d,(ix+1)
        ;jr      z,LDIR_PEQUEN

LDIR_GRANDE:    ld      a,(ix+3)        ;A-DE = Tamanyo en unidades de 256 bytes
        ld      e,(ix+1)
        ld      d,(ix+2)
        sra     a       ;Lo convierte a K
        rr      d
        rr      e
        sra     a
        rr      d
        rr      e
        inc     de
        scf

LDIR_PEQUEN:    ;Aqui, DE es el tamanyo a imprimir, y Cy=1 si es "K"
        ld      hl,RESPONSE_BUF
        ld      b,7
        ld      c," "
        push    af
        ld      a,1000b
        call    NUMTOASC
        print   RESPONSE_BUF
        pop     af
        jr      nc,LDIR_OKFILE
        ld      e,"K"
        ld      c,_CONOUT
        call    DO_DOS

LDIR_OKFILE:    call    CRLF
        ld      c,_FNEXT
        jp      R_LDIRLOOP

LDIR_END:       ld      (LDIR_ERRNUM),a
        ld      hl,(LDIR_DIRS)
        ld      de,(LDIR_FILES)
        ld      a,d
        or      e
        or      h
        or      l
        call    nz,CRLF
        ld      hl,RESPONSE_BUF ;Fin: muestra num de dirs y files encontrados
        ld      de,(LDIR_FILES)
        ld      b,1
        ld      a,1000b
        call    NUMTOASC
        print   RESPONSE_BUF
        print   FFOUND_S

        ld      hl,RESPONSE_BUF
        ld      de,(LDIR_DIRS)
        ld      b,1
        ld      a,1000b
        call    NUMTOASC
        print   RESPONSE_BUF
        print   DFOUND_S

        ld      a,(LDIR_ERRNUM) ;Si el error no era "file not found",
        cp      0D7h     ;no calcula espacio libre
        jr      nz,LDIR_ENDL3

        ld      a,(LDIR_DRV)    ;Consulta espacio libre en la unidad
        ld      e,a
        ld      c,_ALLOC
        call    DO_DOS

LDIR_ENDL:      sra     a       ;Convierte clusters a sectores
        jr      c,LDIR_ENDL2
        sla     l
        rl      h
        jr      nc,LDIR_ENDL
LDIR_ENDL2:     srl     h       ;Convierte sectores a K
        rr      l

        ex      de,hl   ;Muestra "XXX K free on drive X:"
        ld      hl,RESPONSE_BUF
        ld      b,1
        ld      a,1000b
        call    NUMTOASC
        print   RESPONSE_BUF
        print   KFREE_S
        ld      a,(LDIR_DRV)
        add     "A"-1
        ld      e,a
        ld      c,_CONOUT
        call    DO_DOS
        ld      e,":"
        ld      c,_CONOUT
        call    DO_DOS
        call    CRLF
LDIR_ENDL3:     jp      LF


LDIR_EXE:       db      0
LDIR_FILES:     dw      0
LDIR_DIRS:      dw      0
LDIR_DRV:       db      0
ATRIB_S:        db      9,"rhs",9,"$"
LDIR_ERRNUM:    db      0


;-----------------
;---  LITERAL  ---
;-----------------

R_LITERAL:      call    CHK_CON
        ret     c

        ld      a,4
        ld      (ABORT_STAT),a

        ld      a,2     ;Va cogiendo los elementos de la cadena
        ;ld     hl,USER_COM_BUF+1       ;pasada por el usuario, y los
        ld      de,SEND_COM_BUF ;copia a SEND_COM_BUF
LITELOOP:       push    af      ;separados con un espacio
        push    de
        ld      hl,USER_COM_BUF+1
        call    EXTPAR
        pop     hl
        jr      c,LITERAL2
        ld      c,b
        ld      b,0
        add     hl,bc
        ld      (hl)," "
        inc     hl
        ex      de,hl
        pop     af
        inc     a
        jr      LITELOOP

LITERAL2:       pop     af
        dec     hl
        ld      (hl),0
        call    APPEND_LF
        call    SEND_COM
        jp      WAIT_REPLY


;-----------
;---  !  ---
;-----------

R_LITERAL!:     call    CHK_CON
        ret     c

        ld      a,4
        ld      (ABORT_STAT),a

        ld      a,1     ;Como LITERAL, pero empieza por el primer
        ;ld     hl,USER_COM_BUF+1       ;elemento de la cadena
        ld      de,SEND_COM_BUF-1       ;excepto el "!" inicial
        jr      LITELOOP


;----------------
;---  LMKDIR  ---
;----------------

R_LMKDIR:       ld      a,3
        ld      (ABORT_STAT),a

        ld      hl,USER_COM_BUF+1
        ld      de,PARSE_BUF
        ld      a,2
        call    EXTPAR
        jp      c,R_INVPAR

        ld      c,_CREATE
        ld      de,PARSE_BUF
        xor     a
        ld      b,10000b
        call    DOS
        ret     c

        print   OPCOMP_S
        ret


;-----------------
;---  LRENAME  ---
;-----------------

R_LRENAME:      ;ld     a,0FFh
        ;ld     (LDIR_EXE),a
        call    _R_LRENAME
        xor     a
        ld      (LDIR_EXE),a
        ret

_R_LRENAME:     ld      a,3
        ld      (ABORT_STAT),a

        ld      hl,USER_COM_BUF+1
        ld      de,RESPONSE_BUF ;Extrae nombre(s) de destino
        ld      a,3
        call    EXTPAR
        jp      c,R_INVPAR

        ld      hl,USER_COM_BUF+1       ;Extrae nombre(s) de origen
        ld      de,PARSE_BUF
        ld      a,2
        call    EXTPAR

        ld      c,_FFIRST
        ld      de,PARSE_BUF
        ld      b,00111b        ;Incluye ficheros ocultos y de sistema
R_LRENLOOP:             ld      ix,USER_COM_BUF+1
        call    DOS     ;Realiza la busqueda
        jr      c,R_LRENEND
        ld      a,0FFh   ;Solo imprimira "file not found"
        ld      (LDIR_EXE),a    ;si no encuentra el primero

        ld      de,USER_COM_BUF+1       ;Renombra cada fichero encontrado
        ld      hl,RESPONSE_BUF
        ld      c,_RENAME
        call    DOS
        ret     c

        ld      c,_FNEXT
        jr      R_LRENLOOP

R_LRENEND:      ld      a,(LDIR_EXE)
        or      a
        ret     z
        print   OPCOMP_S
        ret


;----------------
;---  LRMDIR  ---
;----------------

R_LRMDIR:       ld      a,3
        ld      (ABORT_STAT),a

        ld      hl,USER_COM_BUF+1
        ld      de,RESPONSE_BUF ;Extrae nombre de directorio
        ld      a,2
        call    EXTPAR
        jp      c,R_INVPAR

        ld      de,RESPONSE_BUF ;Si hay comodines, error "Invalid filename"
        ld      b,0
        ld      c,_PARSE
        call    DO_DOS
        bit     5,b
        ld      a,0DAh   ;"Invalid filename"
        jp      nz,DOS2

        ld      c,_FFIRST       ;Error si no encuentra el fichero/directorio
        ld      de,RESPONSE_BUF ;con ese nombre, o si lo encuentra pero
        ld      b,10111b        ;es un fichero
        ld      ix,USER_COM_BUF+1
        call    DOS
        ret     c
        ld      a,(USER_COM_BUF+15)
        bit     4,a
        ld      a,0D6h   ;"Directory not found"
        jp      z,DOS2

        ld      de,USER_COM_BUF+1       ;Intenta borrar el directorio
        ld      c,_DELETE
        call    DOS
        ret     c

        print   OPCOMP_S
        ret


;------------
;---  LS  ---
;------------

R_LS:   ld      hl,C_NLST

        jp      R_DIR_LS


;---------------
;---  LSHOW  ---
;---------------

R_LSHOW:        ld      a,3
        ld      (ABORT_STAT),a

        ld      hl,USER_COM_BUF+1
        ld      de,PARSE_BUF    ;Extrae nombre de fichero
        ld      a,2
        call    EXTPAR
        jp      c,R_INVPAR

        ld      de,PARSE_BUF    ;Si hay comodines, error "Invalid filename"
        ld      b,0
        ld      c,_PARSE
        call    DO_DOS
        bit     5,b
        ld      a,0DAh   ;"Invalid filename"
        jp      nz,DOS2

        ld      a,(FILE_FH)     ;Si ya hay un fichero abierto,
        cp      0FFh     ;lo cierra primero (no deberia pasar nunca)
        jr      z,R_LSHOW_OK1
        ld      c,_CLOSE
        ld      b,a
        call    DO_DOS
R_LSHOW_OK1:    ;

        ld      a,1     ;Abre el fichero, termina si hay error
        ld      de,PARSE_BUF
        ld      c,_OPEN
        call    DOS
        ret     c
        ld      a,b
        ld      (FILE_FH),a

R_LSHOW_LOOP1:  xor     a
        ld      (LINE_COUNT),a
        ld      (BYTE_COUNT),a

R_LSHOW_LOOP:   call    GET_LDATA       ;Obtiene un byte y lo imprime
        jr      c,GET_LSHOW_END
        call    PRINT_PAUSE
        jr      R_LSHOW_LOOP

GET_LSHOW_END:  ld      a,(FILE_FH)     ;No quedan datos: cierra el fichero
        ld      b,a
        ld      c,_CLOSE
        call    DO_DOS
        ld      a,0FFh
        ld      (FILE_FH),a
        ret


;-----------------
;---  MDELETE  ---
;-----------------

R_MDELETE:      ld      a,(HAY_NMAN)
        or      a
        jr      nz,R_MDEL2

        print   NONMAN_S
        ret

R_MDEL2:        ld      hl,R_DELETE
        ld      (MUL_COM),hl
        ld      hl,DELETER_S
        ld      (MUL_STR),hl
        jp      MULTIPLE


;--------------
;---  MGET  ---
;--------------

R_MGET: ld      a,(HAY_NMAN)
        or      a
        jr      nz,R_MGET2

        print   NONMAN_S
        ret

R_MGET2:        ld      hl,R_GET
        ld      (MUL_COM),hl
        ld      hl,RECEIVE_S
        ld      (MUL_STR),hl
        jp      MULTIPLE


;---------------
;---  MKDIR  ---
;---------------

R_MKDIR:        call    CHK_CON
        ret     c

        ld      a,4
        ld      (ABORT_STAT),a

        ld      a,0FFh
        ld      (ES_XCOM),a
        ld      hl,USER_COM_BUF+1
        ld      de,SEND_COM_BUF+4
        ld      a,2
        call    EXTPAR
        ld      hl,C_MKD
        jp      nc,PARAM_XCOM
        jp      R_INVPAR


;--------------
;---  MPUT  ---
;--------------

R_MPUT: ld      a,(HAY_NMAN)
        or      a
        jr      nz,R_MPUT2

        print   NONMAN_S
        ret

R_MPUT2:        ld      a,4
        ld      (ABORT_STAT),a

        ld      a,0FFh
        ld      (LDIR_EXE),a
        ld      a,(VERBOSE)
        ld      (OLD_VERBOSE_M),a
        call    _R_MPUT
        xor     a
        ld      (LDIR_EXE),a
        ld      a,(MUL_LISTA)
        ld      ix,0
        nesman  22
        ld      a,0FFh
        ld      (MUL_LISTA),a
        ld      a,(OLD_VERBOSE_M)
        ld      (VERBOSE),a
        ret

_R_MPUT:        call    CHK_CON
        ret     c

        ld      hl,USER_COM_BUF+1
        ld      de,RESPONSE_BUF ;Extrae mascara
        ld      a,2
        call    EXTPAR
        jp      c,R_INVPAR

        or      a       ;Crea lista interna
        nesman  20
        jr      c,R_MPUT_OOME
        ld      (MUL_LISTA),a

        ;--- Primero busca todos los archivos y guarda
        ;    sus nombres en la lista

        ld      c,_FFIRST
        ld      de,RESPONSE_BUF
        ld      b,0
R_MPUTLOOP1:    ld      ix,USER_COM_BUF+1
        call    DOS     ;Realiza la busqueda
        jp      c,RMPUT_OKLIST

        ld      a,(MUL_LISTA)
        ld      ix,0
        ld      b,3
        ld      hl,13
        ld      iy,USER_COM_BUF+2
        nesman  24
        jr      c,R_MPUT_OOME
        ld      c,_FNEXT
        jr      R_MPUTLOOP1
RMPUT_OKLIST:   ;

        ;--- Ya tenemos los nombres, ahora saltamos a MULTIPLE

        xor     a
        ld      (MUST_ASCII),a

        ld      hl,R_SEND
        ld      (MUL_COM),hl
        ld      hl,SENDFILE_S
        ld      (MUL_STR),hl

        jp      MULTIPLE2

R_MPUT_OOME:    print   OUTOFM_S
        ret


;--------------
;---  OPEN  ---
;--------------

R_OPEN: ld      a,0FFh   ;Primero actualiza informacion
        ld      (QUITTING),a    ;sobre la conexion
        call    CHK_CON
        ld      a,0
        ld      (QUITTING),a
        jr      c,R_OPEN1

        ld      de,ALCON_S      ;Ya estamos conectados?
        ld      c,_STROUT
        jp      nz,DO_DOS

R_OPEN1:        ld      a,4
        ld      (ABORT_STAT),a

        ;--- Extrae segundo parametro si lo hay (numero de puerto)
        ;    y lo establece en el pseudo-TCB

        ld      hl,21   ;Puertos por defecto
        ld      (PORT_REMOTE_C),hl

        ld      hl,USER_COM_BUF+1
        ld      de,PARSE_BUF
        ld      a,3
        call    EXTPAR
        jr      c,R_OPEN2

        ld      hl,PARSE_BUF
        call    EXTNUM
        jp      c,R_INVPAR
        ld      a,e
        or      a
        jp      nz,R_INVPAR

        ld      (PORT_REMOTE_C),bc
R_OPEN2:        ;

        ;--- Extrae el primer parametro (nombre de host)
        ;    y lo resuelve

        ld      hl,USER_COM_BUF+1       ;Extrae nombre
        ld      de,SERVER_NAME
        ld      a,2
        call    EXTPAR
        jp      c,R_INVPAR

        print   CONNECTING_S

        ld      b,0
        ld      a,TCPIP_DNS_Q
        ld      hl,SERVER_NAME  ;Hace el query al DNS
        ;debug   "1"
        call    CALL_UNAPI
        ;debug   "2"
        or      a
        jr      z,R_OPEN_L1

        ld      de,WHENDNS_S    ;Error devuelto por IP_DNS_Q?
        ld      hl,DNSQERRS_T
        jp      SHOW_ERR

R_OPEN_L1:      ld      a,TCPIP_WAIT    ;Espera un resultado o un error del DNS
        call    CALL_UNAPI
        ld      b,0
        ld      a,TCPIP_DNS_S
        call    CALL_UNAPI
        or      a
        jr      nz,R_OPEN_L1!
        ld      a,b
        cp      1
        jr      z,R_OPEN_L1
        jr      R_OPEN3

R_OPEN_L1!:
        ld      a,b     ;Error devuelto por IP_DNS_S?
        ld      de,WHENDNS_S
        ld      hl,DNSERRS_T
        jp      SHOW_ERR

R_OPEN3:        ld      (IP_REMOTE_C),hl        ;Establece las IPs en los TCBs
        ld      (IP_REMOTE_C+2),de

        ;--- Abre la conexion de control al servidor FTP
        ;    y la conexion para el protocolo IDENT

        ld      hl,0
        ld      de,0
        ld      iy,113  ;Conx pasiva a nuestro puerto 113
        ld      bc,0
        ld      a,0FFh
        ;debug   "3"
        call    TCP_OPEN
        ;debug   "4"
        jr      c,OK_IDENT
        ld      (IDENT_CON),a
OK_IDENT:       ;

        ld      hl,(IP_REMOTE_C)
        ld      de,(IP_REMOTE_C+2)
        ld      ix,(PORT_REMOTE_C)
        ld      iy,0FFFFh
        ld      bc,0
        xor     a
        ;debug   "5"
        call    TCP_OPEN        ;Intenta abrir conexion
        ;debug   "6"
        ld      b,a
        jr      nc,R_OPEN_L2!

        push    af
        ld      a,(IDENT_CON)
        ;debug   "7"
        call    TCP_ABORT
        ;debug   "8"
        pop     af
        ld      de,WHENCONN_S
        ld      hl,OPENERR_T
        jp      SHOW_ERR

R_OPEN_L2!:     ;ld      (CONTROL_CON),a  ;1.1
R_OPEN_L2:      call    IDENT_AUTOM
        push    bc      ;Espera hasta que este ESTABLISHED
        call    HALT
        ld      a,b     ;o hasta que se cierre ("Error: connection refused")
        call    TCP_STATUS
        pop     bc
        or      a
        jr      nz,OPENNOREF

        ld      a,(IDENT_CON)
        call    TCP_ABORT
        ld      a,0FFh
        ld      (IDENT_CON),a
        ld      de,CONREF_S
        ld      c,_STROUT
        or      a
        jp      DO_DOS

OPENNOREF:      ld      d,a
        ld      a,(0FBECh)       ;El bit 2 de 0FBECh es 0
        bit     2,a     ;cuando se esta pulsando ESC
        ld      a,d
        jr      nz,NOOPCANCEL

        ld      a,b
        call    TCP_ABORT
        ld      a,0FFh
        ld      (CONTROL_CON),a
        print   CANCELLED_S
        ret

NOOPCANCEL:     ;ld      a,b
        cp      4
        jr      nz,R_OPEN_L2

        ld      a,b
        ld      (CONTROL_CON),a
        print   OK_S

        ;--- Espera una respuesta que no sea 1yz

R_OPEN_L3:      call    IDENT_AUTOM
        call    WAIT_REPLY
        ret     c
        cp      1
        jr      z,R_OPEN_L3
        cp      4       ;Si la respuesta es 4yz, termina
        ret     z
        cp      2       ;Si no es 2yz, "ERROR: Unexpected reply" y fin.
        jr      z,R_OPEN4
R_UNEX: print   UNEXPEC_S
        ret
R_OPEN4:        ;

        ;>>> Ahora empieza la secuencia USER - PASSWORD - ACCOUNT.

        call    IDENT_AUTOM
        ld      a,(IDENT_CON)
        call    TCP_ABORT

        ;--- Pregunta el nombre de usuario, y lo envia mediante comando USER

_R_USER:        print   USER._S ;Obtiene nombre de usuario
        printz  DEF_USER
        print   CIERRAPAR_S
        ld      de,USER_COM_BUF
        ld      c,_BUFIN
        call    DO_DOS
        call    CRLF

_R_USER2:       ld      hl,C_USER       ;Compone "USER usuario"+CRLF en SEND_COM_BUF
        call    SET_COMMAND
        call    SET_SPACE
        ld      hl,USER_COM_BUF+1
        ld      de,SEND_COM_BUF+5
        ld      a,1
        call    EXTPAR
        jr      nc,RUSER2
        ld      hl,DEF_USER     ;DEF_USER si no se escribe nada
        ld      de,SEND_COM_BUF+5
        ld      bc,255
        ldir
RUSER2: call    APPEND_LF

        ;debug   "1"
        call    SEND_COM        ;Envia comando
        ;debug   "2"
        ret     c

        ;debug   "3"
        call    WAIT_REPLY      ;Respuesta 2, 4 o 5: termina
        ;debug   "4"
        ret     c
        cp      4
        ret     z
        cp      5
        ret     z
        cp      2
        ret     z
        cp      3       ;Respuesta 3: continua; otra: error "Unexpected reply"
        jp      nz,R_UNEX

        ;--- Se requiere contrasenya: se pregunta y se envia

RPASS2: print   PASSWORD._S     ;Obtiene password
        ;debug   "5"
        ld      a,(DEF_PASSWORD)
        or      a
        ld      de,NONE_S
        jr      z,RPASS2_0
        ld      de,DEF_PASSWORD
        call    SET_HOOK
RPASS2_0:       call    PRINT_Z
        call    RESET_HOOK
        print   CIERRAPAR_S
        ld      de,USER_COM_BUF
        call    SET_HOOK
        ld      c,_BUFIN
        call    DO_DOS
        call    RESET_HOOK

        ld      hl,C_PASS       ;Compone "PASS password"+CRLF en SEND_COM_BUF
        call    SET_COMMAND
        call    SET_SPACE
        ld      hl,USER_COM_BUF+1
        ld      de,SEND_COM_BUF+5
        ld      a,1
        call    EXTPAR
        jr      nc,RPASS2_1
        ld      a,(DEF_PASSWORD)        ;Si no se ha introducido password:
        or      a       ;Comprueba si hay password por
        jr      z,RPASS2        ;defecto y en ese caso lo usa,
        ld      hl,DEF_PASSWORD ;en caso contrario vuelve a preguntarlo
        ld      de,SEND_COM_BUF+5
        ld      bc,255
        ldir
RPASS2_1:       call    APPEND_LF
        call    LF

        call    SEND_COM        ;Envia comando
        ret     c

        call    WAIT_REPLY      ;Respuesta 2, 4 o 5: termina
        ret     c
        cp      4
        ret     z
        cp      5
        ret     z
        cp      2
        ret     z
        cp      3       ;Respuesta 3: continua; otra: error "Unexpected reply"
        jp      nz,R_UNEX

        ;--- Se requiere "account": se pregunta y se envia

RACCT2: print   ACCOUNT._S      ;Obtiene account
        ld      a,(DEF_ACCOUNT)
        or      a
        ld      de,NONE_S
        jr      z,RACCT2_0
        ld      de,DEF_ACCOUNT
RACCT2_0:       call    PRINT_Z
        print   CIERRAPAR_S
        ld      de,USER_COM_BUF
        ld      c,_BUFIN
        call    DO_DOS

        ld      hl,C_ACCT       ;Compone "ACCT account"+CRLF en SEND_COM_BUF
        call    SET_COMMAND
        call    SET_SPACE
        ld      hl,USER_COM_BUF+1
        ld      de,SEND_COM_BUF+5
        ld      a,1
        call    EXTPAR
        jr      nc,RACCT2_1
        ld      a,(DEF_ACCOUNT) ;Si no se ha introducido account:
        or      a       ;Comprueba si hay account por
        jr      z,RACCT2        ;defecto y en ese caso lo usa,
        ld      hl,DEF_ACCOUNT  ;en caso contrario vuelve a preguntarlo
        ld      de,SEND_COM_BUF+5
        ld      bc,255
        ldir
RACCT2_1:       call    APPEND_LF
        call    LF

        call    SEND_COM        ;Envia comando
        ret     c

        call    WAIT_REPLY      ;Respuesta 2, 4 o 5: termina
        ret     c
        cp      4
        ret     z
        cp      5
        ret     z
        cp      2
        ret     z
        jp      R_UNEX  ;Otra: error "Unexpected reply"


;-----------------
;---  PASSIVE  ---
;-----------------

R_PASSIVE:      ld      a,3
        ld      (ABORT_STAT),a

        ld      hl,PASSIVE
        ld      de,PASSIVE_M_S
        jp      TURN_ON_OFF


;---------------
;---  PAUSE  ---
;---------------

R_PAUSE:        ld      a,3
        ld      (ABORT_STAT),a

        ld      hl,PAUSE
        ld      de,PAUSE_M_S
        jp      TURN_ON_OFF


;----------------
;---  PROMPT  ---
;----------------

R_PROMPT:       ld      a,3
        ld      (ABORT_STAT),a

        ld      hl,PROMPT
        ld      de,PROMPT_M_S
        jp      TURN_ON_OFF


;-------------
;---  PWD  ---
;-------------

R_PWD:  call    CHK_CON
        ret     c

        ld      a,4
        ld      (ABORT_STAT),a

        ld      a,0FFh
        ld      (ES_XCOM),a
        ld      a,(VERBOSE)
        push    af      ;Siempre muestra el resultado,
        ld      a,0FFh   ;aunque "verbose" sea 0
        ld      (VERBOSE),a
        ld      hl,C_PWD
        call    SINGLE_XCOM
        pop     af
        ld      (VERBOSE),a
        ret


;--------------
;---  QUIT  ---
;--------------

R_QUIT: ld      a,0FFh
        ld      (QUITTING),a
        call    CHK_CON
        jp      c,TERM

        ld      a,5
        ld      (ABORT_STAT),a

        ld      hl,C_QUIT
        call    SET_COMMAND
        call    APPEND_LF
        call    AUTOMATA_NO1
        call    HALT
        call    HALT
        call    HALT
        jp      TERM


;--------------------
;---  REMOTEHELP  ---
;--------------------

R_REMOTEHELP:   call    CHK_CON
        ret     c

        ld      a,4
        ld      (ABORT_STAT),a

        ld      a,2
        ld      hl,USER_COM_BUF+1       ;No hay parametros: solo envia "HELP"
        ld      de,PARSE_BUF
        call    EXTPAR
        ld      hl,C_HELP
        jp      c,SINGLE_COM

        ld      hl,C_HELP       ;Hay parametros: los envia todos
        call    SET_COMMAND     ;tras el HELP, usando la rutina de "LITERAL"
        call    SET_SPACE
        ld      de,SEND_COM_BUF+5
        ld      a,(VERBOSE)
        push    af
        ld      a,0FFh   ;Siempre muestra respuesta
        ld      (VERBOSE),a
        ld      a,2
        call    LITELOOP
        pop     af
        ld      (VERBOSE),a
        ret


;----------------
;---  RENAME  ---
;----------------

R_RENAME:       call    CHK_CON
        ret     c

        ld      a,4
        ld      (ABORT_STAT),a

        ld      a,2
        ld      hl,USER_COM_BUF+1
        ld      de,SEND_COM_BUF+5
        call    EXTPAR
        cp      3
        jp      nz,R_INVPAR     ;Error si no hay dos parametros
        ld      hl,C_RNFR       ;Envia "RNFR..."
        call    PARAM_COM
        cp      3
        jr      z,R_REN2        ;Si respuesta 2yz, termina con
        cp      1
        ret     z
        cp      4
        ret     z
        cp      5
        ret     z
        print   UNEXPEC_S       ;error "Unexpected reply"
        ret
R_REN2: ;

        ld      a,3     ;Envia "RNTO..."
        ld      hl,USER_COM_BUF+1
        ld      de,SEND_COM_BUF+5
        call    EXTPAR
        ld      hl,C_RNTO
        call    PARAM_COM
        cp      1
        ret     z
        cp      2
        ret     z
        cp      4
        ret     z
        cp      5
        ret     z
        ld      c,_STROUT       ;Si la respuesta no es "2yz", "4yz" o "5yz",
        ld      de,UNEXPEC_S    ;imprime "Unexpected reply"
        call    z,5
        ret


;---------------
;---  RMDIR  ---
;---------------

R_RMDIR:        call    CHK_CON
        ret     c

        ld      a,4
        ld      (ABORT_STAT),a

        ld      a,0FFh
        ld      (ES_XCOM),a
        ld      hl,USER_COM_BUF+1
        ld      de,SEND_COM_BUF+4
        ld      a,2
        call    EXTPAR
        ld      hl,C_RMD
        jp      nc,PARAM_XCOM
        jp      R_INVPAR


;--------------
;---  SEND  ---
;--------------

R_SEND: ld      a,2
        ld      hl,C_STOR

R_SEND_APP:     ld      (PUTR_PAR),a    ;Comprueba si existe el parametro
        ld      (PUTR_COM),hl   ;2 (SEND) o 3 (APPEND)
        push    af
        ld      a,4
        ld      (ABORT_STAT),a
        pop     af
        ld      hl,USER_COM_BUF+1
        ld      de,PARSE_BUF
        call    EXTPAR
        jp      c,R_INVPAR

        ld      hl,USER_COM_BUF+1       ;Extrae el parametro 2 (fichero local)
        ld      de,PARSE_BUF
        ld      a,2
        call    EXTPAR

        ld      c,_OPEN
        ld      de,PARSE_BUF
        ld      a,1
        ld      b,0
        call    DOS
        ret     c
        ld      a,b
        ld      (FILE_FH),a

        ld      a,0FFh
        ld      (PUT_EXE),a
        call    PUTRIEVE
        xor     a
        ld      (PUT_EXE),a
        ret


;--------------
;---  SHOW  ---
;--------------

R_SHOW: ld      hl,C_RETR

        jp      R_DIR_LS


;----------------
;---  STATUS  ---
;----------------

R_STATUS:       ld      a,3
        ld      (ABORT_STAT),a

        ld      a,0FFh   ;Primero actualiza informacion
        ld      (QUITTING),a    ;sobre la conexion
        call    CHK_CON
        xor     a
        ld      (QUITTING),a

        ld      a,(CONTROL_CON)
        cp      0FFh
        jr      nz,STATR_2

        call    CRLF
        print   DISCON_S
        jr      STATR_3

STATR_2:        print   CONNTO_S
        printz  SERVER_NAME
        call    CRLF
STATR_3:        ;


        print   TYPE_S
        ld      a,(TYPE)
        or      a
        ld      de,ASCII_S
        jr      z,STATR_4
        ld      de,BINARY_S
STATR_4:        ld      c,_STROUT
        call    DO_DOS

        ld      hl,VERBOSE
        ld      de,VERBOSE_S
        call    SHOW_ON_OFF

        ld      hl,DEBUG
        ld      de,DEBUG_S
        call    SHOW_ON_OFF

        ld      hl,PROMPT
        ld      de,PROMPT_S
        call    SHOW_ON_OFF

        ld      hl,HASH
        ld      de,HASH_S
        call    SHOW_ON_OFF

        ld      hl,BELL
        ld      de,BELL_S
        call    SHOW_ON_OFF

        ld      hl,PASSIVE
        ld      de,PASSIVE_S
        call    SHOW_ON_OFF

        ld      hl,PAUSE
        ld      de,PAUSE_S
        call    SHOW_ON_OFF

        ld      hl,XCOM
        ld      de,XCOM_S
        call    SHOW_ON_OFF

        jp      CRLF


;--------------
;---  TYPE  ---
;--------------

R_TYPE: call    CHK_CON
        ret     c

        ld      a,4
        ld      (ABORT_STAT),a

        ld      hl,USER_COM_BUF+1
        ld      de,PARSE_BUF
        ld      a,2
        call    EXTPAR  ;Error si no hay parametro
        jp      c,R_INVPAR

        ld      a,(PARSE_BUF+1) ;Error si el parametro es
        or      a       ;de mas de una letra
        jp      nz,R_INVPAR

        ld      a,(PARSE_BUF)   ;Error si no es "A" o "I",
        or      00100000b       ;si no hay error, salta a ASCII o BINARY
        cp      "a"
        jp      z,R_ASCII
        cp      "i"
        jp      z,R_BINARY


;--------------
;---  USER  ---
;--------------

R_USER: call    CHK_CON
        ret     c

        ld      a,4
        ld      (ABORT_STAT),a

        ld      hl,USER_COM_BUF+1
        ld      de,PARSE_BUF
        ld      a,2
        call    EXTPAR
        jp      c,_R_USER

        ld      a,b
        ld      (USER_COM_BUF+1),a
        ld      c,a
        ld      b,0
        inc     bc
        ld      hl,PARSE_BUF
        ld      de,USER_COM_BUF+2
        ldir
        jp      _R_USER2


;-----------------
;---  VERBOSE  ---
;-----------------

R_VERBOSE:      ld      a,3
        ld      (ABORT_STAT),a

        ld      hl,VERBOSE
        ld      de,VERBOSE_M_S
        jp      TURN_ON_OFF


;-------------------
;---  XCOMMANDS  ---
;-------------------

R_XCOMMANDS:    ld      a,3
        ld      (ABORT_STAT),a

        ld      hl,XCOM
        ld      de,XCOM_M_S
        jp      TURN_ON_OFF


;*** Rutinas auxiliares para la ejecucion de comandos

;--- SINGLE_COM: Ejecuta el comando HL sin parametros

SINGLE_COM:     call    SET_COMMAND
        call    APPEND_LF
        jp      AUTOMATA_NO1

;--- PARAM_COM: Ejecuta el comando HL con parametros ya establecidos
;               (SEND_COM_BUF contiene "xxxxx<paramatros>")

PARAM_COM:      call    SET_COMMAND
        call    SET_SPACE
        call    APPEND_LF
        jp      AUTOMATA_NO1

;--- SINGLE_XCOM: Como SINGLE_COM, para comandos "X"

SINGLE_XCOM:    call    SET_COMMAND
        call    APPEND_LF
        ld      a,0FFh
        ld      (ES_XCOM),a
        jp      AUTOMATA_NO1

;--- PARAM_XCOM: Como SINGLE_COM, para comandos "X"

PARAM_XCOM:     call    SET_COMMAND
        call    SET_SPACE
        call    APPEND_LF
        ld      a,0FFh
        ld      (ES_XCOM),a
        jp      AUTOMATA_NO1

;--- R_INVPAR: Faltan parametros o son incorrectos

R_INVPAR:       print   INVPAR_S
        ret



;******************************
;***                        ***
;***   AUXILIARY ROUTINES   ***
;***                        ***
;******************************


;----------------------------------------------------------
;---  String manipulation and screen printing routines  ---
;----------------------------------------------------------


;--- NAME: COMP
;      Compares HL and DE (16 bits in twos complement)
;    INPUT:    HL, DE = numbers to compare
;    OUTPUT:    C, NZ if HL > DE
;               C,  Z if HL = DE
;              NC, NZ if HL < DE

COMP:   call    _COMP
        ccf
        ret

_COMP:  ld      a,h
        sub     d
        ret     nz
        ld      a,l
        sub     e
        ret


;--- NAME: EXTPAR
;      Extracts a parameter from the command line
;    INPUT:   A  = Parameter to extract (the first one is 1)
;             DE = Buffer to put the extracted parameter
;       HL = Direccion de la cadena (el primer byte es la longitud)
;    OUTPUT:  A  = Total number of parameters in the command line
;             CY = 1 -> The specified parameter does not exist
;                       B undefined, buffer unmodified
;             CY = 0 -> B = Parameter length, not including the tailing 0
;                       Parameter extracted to DE, finished with a 0 byte
;                       DE preserved

EXTPAR: or      a       ;Terminates with error if A = 0
        scf
        ret     z

        ld      b,a
        ld      a,(hl)  ;Terminates with error if
        or      a       ;there are no parameters
        scf
        ret     z
        ld      a,b

        push    hl
        push    de
        push    ix
        push    iy
        ld      ix,0    ;IXl: Number of parameter
        ld      ixh,a   ;IXh: Parameter to be extracted
        inc     hl
        push    hl
        pop     iy

        ;* Scans the command line and counts parameters

PASASPC:        ld      a,(hl)  ;Skips spaces until a parameter
        or      a       ;is found
        jr      z,ENDPNUM
        cp      13
        jr      z,ENDPNUM
        cp      " "
        inc     hl
        jr      z,PASASPC

        inc     ix      ;Increases number of parameters
PASAPAR:        ld      a,(hl)  ;Walks through the parameter
        or      a
        jr      z,ENDPNUM
        cp      " "
        inc     hl
        jr      z,PASASPC
        jr      PASAPAR

        ;* Here we know already how many parameters are available

ENDPNUM:        ld      a,ixh   ;Error if the parameter to extract
        cp      ixl     ;is greater than the total number of
        jr      z,PAROK ;parameters available
        jr      nc,EXTPERR
PAROK:

        push    iy
        pop     hl
        ;ld      hl,81h
        ld      b,1     ;B = current parameter
PASAP2: ld      a,(hl)  ;Skips spaces until the next
        cp      " "     ;parameter is found
        inc     hl
        jr      z,PASAP2

        ld      a,ixh   ;If it is the parameter we are
        cp      b       ;searching for, we extract it,
        jr     z,PUTINDE0        ;else...

        inc     b
PASAP3: ld      a,(hl)  ;...we skip it and return to PASAP2
        cp      " "
        inc     hl
        jr      nz,PASAP3
        jr      PASAP2

        ;* Parameter is located, now copy it to the user buffer

PUTINDE0:       ld      b,0
        dec     hl
PUTINDE:        inc     b
        ld      a,(hl)
        cp      " "
        jr      z,ENDPUT
        or      a
        jr      z,ENDPUT
        cp      13
        jr      z,ENDPUT
        ld      (de),a  ;Paramete is copied to (DE)
        inc     de
        inc     hl
        jr      PUTINDE

ENDPUT: xor     a
        ld      (de),a
        dec     b

        ld      a,ixl
        or      a
        jr      FINEXTP
EXTPERR:        scf
FINEXTP:        pop     iy
        pop     ix
        pop     de
        pop     hl
        ret

;--- Rutina de terminacion
;    Aborta las conexiones abiertas, si las hay
;    y borra la cola de nombres de fichero

TERM:   xor     a       ;Desde ahora, CTRL-C no tiene efecto
        ld      (ABORT_STAT),a

        ;ld      a,(DATA_CON)
        ;ld      b,a
        ;ld      a,(CONTROL_CON)
        ;and     b
        ;cp      0FFh
        ;jr      z,TERM_CON_OK

        ld      a,(DATA_CON)
        cp      0FFh
        call    nz,TCP_CLOSE    ;TCP_ABORT
        ld      a,(CONTROL_CON)
        cp      0FFh
        call    nz,TCP_CLOSE    ;TCP_ABORT
        ld      a,(IDENT_CON)
        cp      0FFh
        call    nz,TCP_CLOSE
TERM_CON_OK:    ;

TERM2:  
        ld      a,(TPASLOT1)
        ld      h,40h
        call    ENASLT

        ld      a,(TPASEG1)     ;Restaura TPA
        call    PUT_P1

        ld      a,(FILES_QUEUE) ;Borra cola de nombres de fichero
        cp      0FFh
        jr      z,TERM_Q_OK
        ld      ix,0
        nesman  22
TERM_Q_OK:      ;

        ld      de,0    ;Desdefine rutina de CTRL-C
        ld      c,_DEFAB
        call    DO_DOS

        ld      bc,_TERM+0*256  ;Termina
        jp      DO_DOS

;--- Prints LF

CRLF:   ld      e,13
        ld      c,_CONOUT
        call    DO_DOS
LF:     ld      e,10
        ld      c,_CONOUT
        jp      DO_DOS


;--- Segment switching routines for page 1,
;    these are overwritten with calls to
;    mapper support routines on DOS 2

PUT_P1: out     (0FDh),a
        ret
GET_P1: in      a,(0FDh)
        ret

TPASEG1:        db      2       ;TPA segment on page 1


;--- NAME: NUMTOASC
;      Converts a 16 bit number into an ASCII string
;    INPUT:      DE = Number to convert
;                HL = Buffer to put the generated ASCII string
;                B  = Total number of characters of the string
;                     not including any termination character
;                C  = Padding character
;                     The generated string is right justified,
;                     and the remaining space at the left is padded
;                     with the character indicated in C.
;                     If the generated string length is greater than
;                     the value specified in B, this value is ignored
;                     and the string length is the one needed for
;                     all the digits of the number.
;                     To compute length, termination character "$" or 00
;                     is not counted.
;                 A = &B ZPRFFTTT
;                     TTT = Format of the generated string number:
;                            0: decimal
;                            1: hexadecimal
;                            2: hexadecimal, starting with "&H"
;                            3: hexadecimal, starting with "#"
;                            4: hexadecimal, finished with "H"
;                            5: binary
;                            6: binary, starting with "&B"
;                            7: binary, finishing with "B"
;                     R   = Range of the input number:
;                            0: 0..65535 (unsigned integer)
;                            1: -32768..32767 (twos complement integer)
;                               If the output format is binary,
;                               the number is assumed to be a 8 bit integer
;                               in the range 0.255 (unsigned).
;                               That is, bit R and register D are ignored.
;                     FF  = How the string must finish:
;                            0: No special finish
;                            1: Add a "$" character at the end
;                            2: Add a 00 character at the end
;                            3: Set to 1 the bit 7 of the last character
;                     P   = "+" sign:
;                            0: Do not add a "+" sign to positive numbers
;                            1: Add a "+" sign to positive numbers
;                     Z   = Left zeros:
;                            0: Remove left zeros
;                            1: Do not remove left zeros
;    OUTPUT:    String generated in (HL)
;               B = Length of the string, not including the padding
;               C = Length of the string, including the padding
;                   Tailing "$" or 00 are not counted for the length
;               All other registers are preserved

NUMTOASC:       push    af
        push    ix
        push    de
        push    hl
        ld      ix,WorkNTOA
        push    af
        push    af
        and     00000111b
        ld      (ix+0),a        ;Type
        pop     af
        and     00011000b
        rrca
        rrca
        rrca
        ld      (ix+1),a        ;Finishing
        pop     af
        and     11100000b
        rlca
        rlca
        rlca
        ld      (ix+6),a        ;Flags: Z(zero), P(+ sign), R(range)
        ld      (ix+2),b        ;Number of final characters
        ld      (ix+3),c        ;Padding character
        xor     a
        ld      (ix+4),a        ;Total length
        ld      (ix+5),a        ;Number length
        ld      a,10
        ld      (ix+7),a        ;Divisor = 10
        ld      (ix+13),l       ;User buffer
        ld      (ix+14),h
        ld      hl,BufNTOA
        ld      (ix+10),l       ;Internal buffer
        ld      (ix+11),h

ChkTipo:        ld      a,(ix+0)        ;Set divisor to 2 or 16,
        or      a       ;or leave it to 10
        jr      z,ChkBoH
        cp      5
        jp      nc,EsBin
EsHexa: ld      a,16
        jr      GTipo
EsBin:  ld      a,2
        ld      d,0
        res     0,(ix+6)        ;If binary, range is 0-255
GTipo:  ld      (ix+7),a

ChkBoH: ld      a,(ix+0)        ;Checks if a final "H" or "B"
        cp      7       ;is desired
        jp      z,PonB
        cp      4
        jr      nz,ChkTip2
PonH:   ld      a,"H"
        jr      PonHoB
PonB:   ld      a,"B"
PonHoB: ld      (hl),a
        inc     hl
        inc     (ix+4)
        inc     (ix+5)

ChkTip2:        ld      a,d     ;If the number is 0, never add sign
        or      e
        jr      z,NoSgn
        bit     0,(ix+6)        ;Checks range
        jr      z,SgnPos
ChkSgn: bit     7,d
        jr      z,SgnPos
SgnNeg: push    hl      ;Negates number
        ld      hl,0    ;Sign=0:no sign; 1:+; 2:-
        xor     a
        sbc     hl,de
        ex      de,hl
        pop     hl
        ld      a,2
        jr      FinSgn
SgnPos: bit     1,(ix+6)
        jr      z,NoSgn
        ld      a,1
        jr      FinSgn
NoSgn:  xor     a
FinSgn: ld      (ix+12),a

ChkDoH: ld      b,4
        xor     a
        cp      (ix+0)
        jp      z,EsDec
        ld      a,4
        cp      (ix+0)
        jp      nc,EsHexa2
EsBin2: ld      b,8
        jr      EsHexa2
EsDec:  ld      b,5

EsHexa2:        push    de
Divide: push    bc   ;DE/(IX+7)=DE, remaining A
        push    hl
        ld      a,d
        ld      c,e
        ld      d,0
        ld      e,(ix+7)
        ld      hl,0
        ld      b,16
BucDiv: rl      c
        rla
        adc     hl,hl
        sbc     hl,de
        jr      nc,$+3
        add     hl,de
        ccf
        djnz    BucDiv
        rl      c
        rla
        ld      d,a
        ld      e,c
        ld      a,l
        pop     hl
        pop     bc

ChkRest9:       cp      10      ;Converts the remaining
        jp      nc,EsMay9       ;to a character
EsMen9: add     a,"0"
        jr      PonEnBuf
EsMay9: sub     10
        add     a,"A"

PonEnBuf:       ld      (hl),a  ;Puts character in the buffer
        inc     hl
        inc     (ix+4)
        inc     (ix+5)
        djnz    Divide
        pop     de

ChkECros:       bit     2,(ix+6)        ;Cchecks if zeros must be removed
        jr      nz,ChkAmp
        dec     hl
        ld      b,(ix+5)
        dec     b       ;B=num. of digits to check
Chk1Cro:        ld      a,(hl)
        cp      "0"
        jr      nz,FinECeros
        dec     hl
        dec     (ix+4)
        dec     (ix+5)
        djnz    Chk1Cro
FinECeros:      inc     hl

ChkAmp: ld      a,(ix+0)        ;Puts "#", "&H" or "&B" if necessary
        cp      2
        jr      z,PonAmpH
        cp      3
        jr      z,PonAlm
        cp      6
        jr      nz,PonSgn
PonAmpB:        ld      a,"B"
        jr      PonAmpHB
PonAlm: ld      a,"#"
        ld      (hl),a
        inc     hl
        inc     (ix+4)
        inc     (ix+5)
        jr      PonSgn
PonAmpH:        ld      a,"H"
PonAmpHB:       ld      (hl),a
        inc     hl
        ld      a,"&"
        ld      (hl),a
        inc     hl
        inc     (ix+4)
        inc     (ix+4)
        inc     (ix+5)
        inc     (ix+5)

PonSgn: ld      a,(ix+12)       ;Puts sign
        or      a
        jr      z,ChkLon
SgnTipo:        cp      1
        jr      nz,PonNeg
PonPos: ld      a,"+"
        jr      PonPoN
        jr      ChkLon
PonNeg: ld      a,"-"
PonPoN  ld      (hl),a
        inc     hl
        inc     (ix+4)
        inc     (ix+5)

ChkLon: ld      a,(ix+2)        ;Puts padding if necessary
        cp      (ix+4)
        jp      c,Invert
        jr      z,Invert
PonCars:        sub     (ix+4)
        ld      b,a
        ld      a,(ix+3)
Pon1Car:        ld      (hl),a
        inc     hl
        inc     (ix+4)
        djnz    Pon1Car

Invert: ld      l,(ix+10)
        ld      h,(ix+11)
        xor     a       ;Inverts the string
        push    hl
        ld      (ix+8),a
        ld      a,(ix+4)
        dec     a
        ld      e,a
        ld      d,0
        add     hl,de
        ex      de,hl
        pop     hl      ;HL=initial buffer, DE=final buffer
        ld      a,(ix+4)
        srl     a
        ld      b,a
BucInv: push    bc
        ld      a,(de)
        ld      b,(hl)
        ex      de,hl
        ld      (de),a
        ld      (hl),b
        ex      de,hl
        inc     hl
        dec     de
        pop     bc
        ld      a,b     ;*** This part was missing on the
        or      a       ;*** original routine
        jr      z,ToBufUs       ;***
        djnz    BucInv
ToBufUs:        ld      l,(ix+10)
        ld      h,(ix+11)
        ld      e,(ix+13)
        ld      d,(ix+14)
        ld      c,(ix+4)
        ld      b,0
        ldir
        ex      de,hl

ChkFin1:        ld      a,(ix+1)        ;Checks if "$" or 00 finishing is desired
        and     00000111b
        or      a
        jr      z,Fin
        cp      1
        jr      z,PonDolar
        cp      2
        jr      z,PonChr0

PonBit7:        dec     hl
        ld      a,(hl)
        or      10000000b
        ld      (hl),a
        jr      Fin

PonChr0:        xor     a
        jr      PonDo0
PonDolar:       ld      a,"$"
PonDo0: ld      (hl),a
        inc     (ix+4)

Fin:    ld      b,(ix+5)
        ld      c,(ix+4)
        pop     hl
        pop     de
        pop     ix
        pop     af
        ret

WorkNTOA:       defs    16
BufNTOA:        ds      10


;--- NAME: EXTNUM
;      Extracts a 5 digits number from an ASCII string
;    INPUT:      HL = ASCII string address
;    OUTPUT:     CY-BC = 17 bits extracted number
;                D  = number of digits of the number
;                     The number is considered to be completely extracted
;                     when a non-numeric character is found,
;                     or when already five characters have been processed.
;                E  = first non+numeric character found (or 6th digit)
;                A  = error:
;                     0 => No error
;                     1 => The number has more than five digits.
;                          CY-BC contains then the number composed with
;                          only the first five digits.
;    All other registers are preserved.

EXTNUM: push    hl
        push    ix
        ld      ix,ACA
        res     0,(ix)
        set     1,(ix)
        ld      bc,0
        ld      de,0
BUSNUM: ld      a,(hl)  ;Jumps to FINEXT if no numeric character
        ld      e,a     ;IXh = last read character
        cp      "0"
        jr      c,FINEXT
        cp      "9"+1
        jr      nc,FINEXT
        ld      a,d
        cp      5
        jr      z,FINEXT
        call    POR10

SUMA:   push    hl      ;BC = BC + A 
        push    bc
        pop     hl
        ld      bc,0
        ld      a,e
        sub     "0"
        ld      c,a
        add     hl,bc
        call    c,BIT17
        push    hl
        pop     bc
        pop     hl

        inc     d
        inc     hl
        jr      BUSNUM

BIT17:  set     0,(ix)
        ret
ACA:    db      0       ;b0: num>65535. b1: more than 5 digits

FINEXT: ld      a,e
        cp      "0"
        call    c,NODESB
        cp      "9"+1
        call    nc,NODESB
        ld      a,(ix)
        pop     ix
        pop     hl
        srl     a
        ret

NODESB: res     1,(ix)
        ret

POR10:  push    de
        push    hl   ;BC = BC * 10 
        push    bc
        push    bc
        pop     hl
        pop     de
        ld      b,3
ROTA:   sla     l
        rl      h
        djnz    ROTA
        call    c,BIT17
        add     hl,de
        call    c,BIT17
        add     hl,de
        call    c,BIT17
        push    hl
        pop     bc
        pop     hl
        pop     de
        ret


;--- PRINT_L: Imprime la cadena DE, acabada en CRLF

PRINT_L:        ld      a,(de)
        push    af
        push    de
        ld      e,a
        ld      c,_CONOUT
        call    DO_DOS
        pop     de
        pop     af
        cp      10
        ret     z
        inc     de
        jr      PRINT_L

;--- PRINT_Z: Imprime la cadena DE, acabada en cero

PRINT_Z:        ld      a,(de)
        or      a
        ret     z
        push    de
        ld      e,a
        ld      c,_CONOUT
        call    DO_DOS
        pop     de
        inc     de
        jr      PRINT_Z

;--- SHOW_ERR: Muestra la cadena DE, y a continuacion
;    busca un error con codigo A en la tabla HL, y lo muestra.

SHOW_ERR        push    af
        push    hl
        push    de
        print   ERROR_S
        pop     de
        ld      c,_STROUT
        call    DO_DOS
        pop     de
        pop     af
        ld      b,a
SEARCH_ERROR:   ld      a,(de)
        inc     de
        cp      b
        jr      z,ERROR_FOUND
NEXT_ERROR:     ld      a,(de)
        inc     de
        or      a
        jr      z,ERROR_NOTF
        cp      "$"
        jr      nz,NEXT_ERROR
        jr      SEARCH_ERROR

ERROR_NOTF:     ld      de,UNKERR_S
ERROR_FOUND:    ld      c,_STROUT       ;Print error string
        call    DO_DOS
        call    LF
        scf
        ret

;--- SEARCH_COM: Busca un comando en la tabla de idems
;    Entrada: HL = Dir. del comando, acabado en 0
;    Salida:  HL = Dir de la rutina del comando
;             DE = Dir de la ayuda del comando
;       Cy = 1 si no existe

SEARCH_COM:     ld      (COMM_DIR),hl

        ld      hl,COMMAND_TABLE
SRCH_C_START:   ld      de,(COMM_DIR)
        ld      a,(hl)
        or      a
        scf
        ret     z

        dec     hl
        dec     de
SRCH_C_LOOP:    inc     hl
        inc     de
        ld      a,(de)
        cp      "A"
        jr      c,SRCH_C_LP2
        and     11011111b       ;Lo transforma a mayusculas
SRCH_C_LP2:     cp      (hl)
        jr      nz,NEXT_COM
        or      a
        jr      nz,SRCH_C_LOOP

        inc     hl
        push    hl      ;Comando encontrado
        pop     ix
        ld      l,(ix)
        ld      h,(ix+1)
        ld      e,(ix+2)
        ld      d,(ix+3)
        or      a
        ret

NEXT_COM:       ld      a,(hl)
        inc     hl
        or      a
        jr      nz,NEXT_COM
        inc     hl
        inc     hl
        inc     hl
        inc     hl
        jr      SRCH_C_START

COMM_DIR:       dw      0


;--- TURN_ON_OFF: Intercambia el valor de una variable
;    Entrada: HL = Variable
;             DE = Cadena para imprimir "xxx turned ON/OFF"

TURN_ON_OFF:    push    de
        ld      a,(hl)
        cpl
        ld      (hl),a
        or      a
        ld      hl,OFF_S
        jr      z,TONOFF2
        ld      hl,ON_S
TONOFF2:        pop     de
        push    hl
        ld      c,_STROUT
        call    DO_DOS
        print   TURNED_S
        pop     de
        ld      c,_STROUT
        call    DO_DOS
        jp      CRLF


;--- SHOW_ON_OFF: Muestra la cadena DE, y luego "ON" o "OFF"
;                 segun el valor de la variable HL.

SHOW_ON_OFF:    push    hl
        ld      c,_STROUT
        call    DO_DOS
        pop     hl
        ld      a,(hl)
        or      a
        ld      de,OFF_S
        jr      z,SHOWONOFF2
        ld      de,ON_S
SHOWONOFF2:     ld      c,_STROUT
        call    DO_DOS
        jp      CRLF


;--- APPEND_LF: Aqade CRLF al final de la cadena en SEND_COM_BUF (acabada en 0)

APPEND_LF:      ld      hl,SEND_COM_BUF-1
APLF_L: inc     hl
        ld      a,(hl)
        or      a
        jr      nz,APLF_L
        ld      (hl),13
        inc     hl
        ld      (hl),10
        ret


;--- SET_COMMAND: Copia el comando HL a SEND_COM_BUF, acabado en 0

SET_COMMAND:    ld      de,SEND_COM_BUF
        ld      bc,5
        push    hl
        inc     hl
        inc     hl
        inc     hl
        ld      a,(hl)
        pop     hl
        or      a
        jr      nz,SETCOM2
        dec     bc
SETCOM2:        ldir
        ret


;--- SET_SPACE: Pone un espacio tras el comando en SEND_COM_BUF
;               (donde esta el 0)

SET_SPACE:      ld      hl,SEND_COM_BUF-1
SETSPACE2:      inc     hl
        ld      a,(hl)
        or      a
        jr      nz,SETSPACE2
        ld      (hl)," "
        ret


;--- DOS: Llama a una funcion del DOS, y en caso de error,
;         imprime su codigo y vuelve con Cy=1

DOS:    call    DO_DOS
        or      a
        ret     z

DOS2:   push    hl
        push    de
        push    bc
        ld      b,a     ;Si se esta haciendo un DIR, el error 0D7h
        ld      a,(LDIR_EXE)    ;(file not found) no se imprime
        or      a
        jr      z,DOS3
        ld      a,b
        cp      0D7h
        jr      z,DOS5
DOS3:   ld      a,(PUT_EXE)     ;Si se esta haciendo un PUT,
        or      a       ;el error 0C7h (end of file)
        jr      z,DOS4  ;no se imprime
        ld      a,b
        cp      0C7h
        jr      z,DOS5
DOS4:   ld      de,RESPONSE_BUF
        ld      c,_EXPLAIN
        call    DO_DOS
        print   DISKERR_S
        printz  RESPONSE_BUF
        call    CRLF
DOS5:   scf
        pop     bc
        pop     de
        pop     hl
        ret

;--- PRINT_PATH: Muestra la unidad+directorio actual y un fin de linea

PRINT_PATH:     ld      c,_CURDRV       ;Muestra unidad
        call    DO_DOS
        add     "A"
        ld      e,a
        ld      c,_CONOUT
        call    DO_DOS
        ld      e,":"
        ld      c,_CONOUT
        call    DO_DOS
        ld      e,92    ;"\"
        ld      c,_CONOUT
        call    DO_DOS

        ld      b,0     ;Muestra dir y CRLF
        ld      de,RESPONSE_BUF
        ld      c,_GETCD
        call    DO_DOS
        printz  RESPONSE_BUF
        jp      CRLF


;--- ASK_YNAC
;    - Imprime "(y,n,a,c)?"
;    - Obtiene un caracter del teclado
;    - Devuelve 0,1,2,3 para y,n,a,c respectivamente.

ASK_YNAC:       print   YNAC_S

ASK_YNAC2:      ld      c,_INNOE
        call    DO_DOS
        ld      c,a
        or      00100000b
        ld      b,0
        cp      "y"
        jr      z,ASK_YNAC3
        inc     b
        cp      "n"
        jr      z,ASK_YNAC3
        inc     b
        cp      "a"
        jr      z,ASK_YNAC3
        inc     b
        cp      "c"
        jr      nz,ASK_YNAC2

ASK_YNAC3:      push    bc
        ld      e,c
        ld      c,_CONOUT
        call    DO_DOS
        call    CRLF
        pop     af
        ret


;--- PRINT_PAUSE: Imprime el caracter A, y si PAUSE=0FFh,
;                 realiza una pausa "Press any key to continue"
;                 cuando se muestra una pantalla llena.
;                 Se ha de inicializar con BYTE_COUNT y LINE_COUNT a 0.

PRINT_PAUSE:    cp      0Ch      ;Si es "borrar panrtalla",
        jr      z,PPAUSE_CLS    ;actua como pantalla llena
        push    af
        ld      e,a
        ld      c,_CONOUT
        call    DO_DOS
        pop     bc
        ld      a,(PAUSE)
        or      a
        ret     z

        ld      a,(BYTE_COUNT)
        inc     a       ;Si se encuentra LF, o se han cogido 80 caracteres,
        ld      (BYTE_COUNT),a  ;se cambia de linea
        cp      80
        jr      z,PPAUSE_NEWL
        ld      a,b
        cp      10
        ret     nz

PPAUSE_NEWL:    xor     a
        ld      (BYTE_COUNT),a
        ld      a,(LINE_COUNT)  ;Si era LF, PAUSE=0FFh, y era la linea 23,
        inc     a       ;imprime "Press any key" y hace una pausa
        ld      (LINE_COUNT),a
        cp      23
        ret     nz

PPAUSE_NEWS:    xor     a       ;Pantalla llena
        ld      (LINE_COUNT),a
        ld      (BYTE_COUNT),a
        print   PRESS_S
        ld      c,_INNOE
        call    DO_DOS
        push    af
        call    CRLF
        pop     af
        or      00100000b
        cp      "p"
        ret     nz
        xor     a
        ld      (PAUSE),a
        ret

PPAUSE_CLS:     call    PPAUSE_NEWS
        ld      e,0Ch
        ld      c,_CONOUT
        jp      DO_DOS


;--- CLOSE_FILE: Cierra fichero abierto si lo hay

CLOSE_FILE:     ld      a,(FILE_FH)
        cp      0FFh
        ret     z

        ld      b,a
        ld      c,_CLOSE
        call    DO_DOS
        ld      a,0FFh
        ld      (FILE_FH),a
        ret


;-------------------------
;---  Rutinas TCP/FTP  ---
;-------------------------

;--- CHK_CON: Comprueba la conexion con el servidor FTP.
;    Si hay conexion, devuelve Cy=0.
;    Si no hay conexion y CONTROL_CON=0FFh, imprime "Disconnected" y devuelve Cy=1.
;    Si no hay conexion y CONTROL_CON<>0FFh, imprimer "ERROR" y devuelve Cy=1.
;    Si QUITTING=0FFh, no imprime nada.

CHK_CON:        call    _CHK_CON
        ret     nc
        ld      a,0
        ld      (TYPE),a
        ret

_CHK_CON:       ld      a,(CONTROL_CON)
        cp      0FFh
        jr      nz,CHK_CON2

        ;CONTROL_CON es 0FFh:
        ;Imprime "Disconnected" y devuelve Cy=1

        ld      a,(QUITTING)
        or      a
        ld      de,DISCON_S
        ld      c,_STROUT
        call    z,DO_DOS
        scf
        ret

        ;CONTROL_CON no es 0FFh:
        ;En teoria hay alguna conexion abierta

CHK_CON2:       call    TCP_STATUS
        or      a
        jr      z,CHK_CON3
        cp      4
        ret     z       ;Si estamos cerrando, no devolvemos error
        ld      a,(CONTROL_CON)
        call    TCP_CLOSE       ;1.1
        ld      a,(QUITTING)    ;aunque no este ESTABLISHED,
        or      a       ;ya que pueden quedar datos por recoger
        ld      a,0FFh
        ld      (CONTROL_CON),a
        scf
        ret     nz

CHK_CON21:      ;call    GET_CDATA        ;Si quedan datos pendientes,
        ;jr      c,CHK_CON22      ;los imprime
        ;ld      e,a              ;(eliminado porque ahora siempre
        ;ld      c,_CONOUT        ;llamamos a R_FLUSH antes de
        ;call    DO_DOS                ;ejecutar cualquier comando)
        ;jr      CHK_CON21
CHK_CON22:      ;call    CRLF

        ld      a,(CONTROL_CON)
        call    TCP_CLOSE       ;TCP_ABORT        ;No hay conexion abierta: imprime "ERROR"
CHK_CON3:       ld      a,0FFh
        ld      (CONTROL_CON),a
        xor     a
        ld      (GCDATA_COUNT),a
        ld      a,(QUITTING)
        or      a
        ld      de,CONLOST_S
        ld      c,_STROUT
        call    z,DO_DOS
        scf
        ret


;--- SEND_COM: Envia el comando que hay en SEND_COM_BUF (acabado en CRLF).
;    Si ES_XCOM=0FFh y XCOMMANDS=0FFh, envia la version "X"
;    Si DEBUG=0FFh, tambien lo imprime por pantalla.
;    Devuelve Cy=1 si no hay conexion.

SEND_COM:       ld      hl,SEND_COM_BUF
        ld      bc,0    ;Mide la longitud del comando
SEND_COM2:      inc     bc
        ld      a,(hl)
        inc     hl
        cp      10
        jr      nz,SEND_COM2

        push    bc
        call    CHK_CON
        pop     bc
        ret     c

        ld      hl,SEND_COM_BUF
        ld      de,(XCOM)
        inc     de
        ld      a,d
        or      e
        jr      nz,SEND_COM3    ;Decrementa el puntero al comando,
        ld      a,"X"   ;incrementa la longitud y pone "X" al principio
        ld      (SEND_COM_BUF-1),a      ;si XCOM y ES_XCOM son 0FFh
        xor     a
        ld      (ES_XCOM),a
        dec     hl
        inc     bc
SEND_COM3:      push    hl
        ld      a,(CONTROL_CON)
        scf
        call    TCP_SEND
        pop     hl
        jr      c,SEND_COM_E

        ld      a,(DEBUG)
        or      a
        ret     z

        push    hl
        print   FLECHA_S
        pop     de
        call    PRINT_L
        or      a
        ret

SEND_COM_E:     print   NOMEM_S
        scf
        ret


;--- WAIT_REPLY: Espera una respuesta del servidor y la encola en RESPONSE_BUF
;                (una linea cada vez).
;    Devuelve Cy=1 si no hay conexion.
;    Devuelve Cy=0 y A=primer digito de la respuesta en caso contrario.
;    Imprime la respuesta si VERBOSE=0FFh (cada vez que hay una linea disponible).

WAIT_REPLY:     ld      a,0FFh
        ld      (LAST_REPLY),a
        call    _WAIT_REPLY
        ret     c       ;Si tras llamar a la rutina quedan datos,
        ld      (LAST_REPLY),a
        call    HALT
        ld      e,a     ;se vuelve a llamar
        push    de
        ld      a,(CONTROL_CON)
        call    TCP_STATUS
        pop     de
        ld      a,h
        or      l
        jr      nz,WAIT_REPLY
        ld      a,e
        or      a
        ret

_WAIT_REPLY:    ;
        xor     a
        ld      (WREPLY_LINE),a

        ;--- Coge una linea completa

WREPLY_LOOP1:   ld      hl,RESPONSE_BUF
WREPLY_LOOP2:   call    HALT
        ld      a,(IDENT_CON)
        cp      0FFh
        call    nz,IDENT_AUTOM  ;!!! Mejorar esto
        push    hl
        call    CHK_CON
        pop     hl
        ret     c
WREPLY_LOOP3:   push    hl
        call    GET_CDATA
        pop     hl
        jr      c,WREPLY_LOOP2
        ld      (hl),a
        inc     hl
        cp      10
        jr      nz,WREPLY_LOOP3

        ;--- Se ha cogido una linea completa:
        ;    Actuamos segun si es la primera linea o no

        ld      a,(WREPLY_LINE)
        or      a
        jr      nz,WREPLY_NO1

        ;--- Primera linea

        ;Comprueba que el primer caracter sea un numero,
        ;de lo contrario ignora la linea

        ld      a,(RESPONSE_BUF)
        cp      "0"
        jr      c,WREPLY_LOOP1
        cp      "9"+1
        jr      nc,WREPLY_LOOP1

        ;Copia el codigo a WREPLY_CODE

        ld      hl,RESPONSE_BUF
        ld      de,WREPLY_CODE
        ld      bc,4
        ldir

        ;Lo imprime si es un error, o si VERBOSE=0FFh

        call    WREPLY_PRINT

        ;Si no hay mas lineas, termina

WREPLY_OK1:     ld      a,(RESPONSE_BUF+3)
        cp      " "
        jr      nz,WREPLY_HAYMAS

        ld      a,(RESPONSE_BUF)
        sub     "0"
        or      a
        ret

WREPLY_HAYMAS:  ld      a,0FFh
        ld      (WREPLY_LINE),a
        jr      WREPLY_LOOP1

        ;--- Siguientes lineas

WREPLY_NO1:     ;

        ;Lo imprime si es un error, o si VERBOSE=0FFh

        call    WREPLY_PRINT

        ;Comprueba si el codigo coincide con el que hay en WREPLY_CODE,
        ;en ese caso termina, si no, hay mas lineas

        ld      hl,RESPONSE_BUF
        ld      de,WREPLY_CODE
        ld      b,3
WREPLY_LOOP4:   ld      a,(de)
        cp      (hl)
        inc     hl
        inc     de
        jp      nz,WREPLY_LOOP1
        djnz    WREPLY_LOOP4
        ld      a,(hl)
        cp      " "
        jp      nz,WREPLY_LOOP1

        ld      a,(RESPONSE_BUF)
        sub     "0"
        or      a
        ret

        ;--- Esta subrutina imprime la linea de RESPONSE_BUF
        ;    si es un error o si VERBOSE=0FFh

WREPLY_PRINT:   ld      a,(VERBOSE)
        or      a
        jr      nz,WREPLY_PRINT2

        ld      a,(RESPONSE_BUF)
        cp      "4"
        jr      z,WREPLY_PRE
        cp      "5"
        ret     nz

WREPLY_PRE:     printl  RESPONSE_BUF+4
        jr      WREPLY_OK1

WREPLY_PRINT2:  printl  RESPONSE_BUF
        ret

WREPLY_LINE:    db      0       ;Linea: 0=1a, 0FFh=otras
WREPLY_CODE:    db      "000 "  ;Codigo de la 1a linea


;--- GET_CDATA: Obtiene un byte de datos en A de la conexion de control,
;               usando un bufer de 256 bytes

GET_CDATA:      ld      a,(GCDATA_COUNT)
        or      a
        jr      z,GCDATA_NEW
        dec     a
        ld      (GCDATA_COUNT),a
        ld      hl,(GCDATA_PNT)
        ld      a,(hl)
        inc     hl
        ld      (GCDATA_PNT),hl
        or      a
        ret

GCDATA_NEW:     ld      de,GDATA_CBUF
        ld      a,(CONTROL_CON)
        ld      bc,256
        call    TCP_RCV
        ret     c
        scf
        ret     z

        dec     bc
        ld      a,c
        ld      (GCDATA_COUNT),a
        ld      hl,GDATA_CBUF+1
        ld      (GCDATA_PNT),hl
        ld      a,(GDATA_CBUF)
        or      a
        ret

GCDATA_COUNT:   db      0
GCDATA_PNT:     dw      0


;--- GET_DDATA: Obtiene un byte de datos en A de la conexion de datos,
;               usando un bufer de 256 bytes

GET_DDATA:      ld      a,(GDDATA_COUNT)
        or      a
        jr      z,GDDATA_NEW
        dec     a
        ld      (GDDATA_COUNT),a
        ld      hl,(GDDATA_PNT)
        ld      a,(hl)
        inc     hl
        ld      (GDDATA_PNT),hl
        or      a
        ret

GDDATA_NEW:     ld      de,GDATA_DBUF
        ld      a,(DATA_CON)
        ld      bc,256
        call    TCP_RCV
        ret     c
        scf
        ret     z

        dec     bc
        ld      a,c
        ld      (GDDATA_COUNT),a
        ld      hl,GDATA_DBUF+1
        ld      (GDDATA_PNT),hl
        ld      a,(GDATA_DBUF)
        or      a
        ret

GDDATA_COUNT:   db      0
GDDATA_PNT:     dw      0



;--- GET_LDATA: Obtiene un byte de datos en A del fichero abierto en FILE_FH,
;               usando un bufer de 256 bytes (el mismo que GET_DDATA)

GET_LDATA:      ld      a,(GLDATA_COUNT)
        or      a
        jr      z,GLDATA_NEW
        dec     a
        ld      (GLDATA_COUNT),a
        ld      hl,(GLDATA_PNT)
        ld      a,(hl)
        inc     hl
        ld      (GLDATA_PNT),hl
        or      a
        ret

GLDATA_NEW:     ld      a,(FILE_FH)
        cp      0FFh
        scf
        ret     z
        ld      b,a
        ld      de,GDATA_DBUF
        ld      hl,256
        ld      c,_READ
        call    DO_DOS
        or      a
        scf
        ret     nz

        dec     hl
        ld      a,l
        ld      (GLDATA_COUNT),a
        ld      hl,GDATA_DBUF+1
        ld      (GLDATA_PNT),hl
        or      a
        ld      a,(GDATA_DBUF)
        or      a
        ret

GLDATA_COUNT:   db      0
GLDATA_PNT:     dw      0


;--- AUTOMATA_NO1: Automata FTP para comandos simples,
;    que no pueden devolver un codigo 1yz.
;    Envia el comando que hay en SEND_COM_BUF y espera una respuesta.
;    Si la respuesta no es 2yz, 4yz o 5yz, imprime "ERROR: Unexpected reply".

AUTOMATA_NO1:   call    SEND_COM
        ret     c

        call    WAIT_REPLY
        ret     c

        cp      2
        ret     z
        cp      4
        ret     z
        cp      5
        ret     z

        print   UNEXPEC_S
        scf
        ret


;--- HALT: Espera a la siguiente interrupcion

HALT:   push    af
        push    bc
        push    de
        push    hl
        ld      a,TCPIP_WAIT
        call    CALL_UNAPI
        ;ld      c,0Bh
        ;call    DO_DOS
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret


;--- OPEN_DCON: Abre una conexion de datos activa o pasiva

OPEN_DCON:      ld      a,(PASSIVE)
        or      a
        jp      z,OPEN_DCON_A


;--- OPEN_DCON_P:
;    - Envia un comando PASV
;    - Espera la respuesta e interpreta la IP y puerto devueltos
;    - Abre una conexion activa de datos con esa informacion
;    - Si no puede abrir la conexion, o hay error al enviar el PORT,
;      imprime el error y vuelve con Cy=1

OPEN_DCON_P:    ld      a,(DATA_CON)
        cp      0FFh
        jr      z,OPEN_DCONP2
        call    TCP_ABORT
OPEN_DCONP2:    call    HALT

        ld      hl,C_PASV
        ld      de,SEND_COM_BUF
        ld      bc,5
        ldir
        call    APPEND_LF

        call    AUTOMATA_NO1    ;Envia comando PASV y espera respuesta,
        cp      2       ;termina si no es 2yz
        jp      nz,OPEN_DCON_E

        ;* Busca en la respuesta el primer caracter numerico

        ld      hl,RESPONSE_BUF+3
OPEN_DCP_L1:    inc     hl
        ld      a,(hl)
        cp      "0"
        jr      c,OPEN_DCP_L1
        cp      "9"+1
        jr      nc,OPEN_DCP_L1

        ;* Ahora extrae la IP y el puerto, los va guardando en DATA_BUF

        ld      de,DATA_BUF
        ld      b,6     ;4 bytes para IP y 2 para puerto

OPEN_DCP_L2:    push    bc
        push    de
        call    EXTNUM

        ld      e,d     ;Hace que HL apunte al siguiente numero
        ld      d,0
        add     hl,de
        inc     hl

        pop     de      ;Almacena el numero y pasa al siguiente
        ld      a,c
        ld      (de),a
        inc     de
        pop     bc
        djnz    OPEN_DCP_L2

        ;* Abre la conexion con los datos obtenidos

        ld      hl,(DATA_BUF)
        ld      de,(DATA_BUF+2)
        ld      a,(DATA_BUF+4)
        ld      ixh,a
        ld      a,(DATA_BUF+5)
        ld      ixl,a
        ld      iy,0FFFFh
        xor     a
        ld      bc,0
        call    TCP_OPEN

        ld      de,WHENOPEND_S
        ld      hl,OPENERR_T
        jp      c,SHOW_ERR
        ld      (DATA_CON),a
        or      a
        ret


;--- OPEN_DCON_A:
;    - Abre una conexion pasiva de datos
;    - Envia un comando PORT y espera respuesta
;    - Si no puede abrir la conexion, o hay error al enviar el PORT,
;      imprime el error y vuelve con Cy=1

OPEN_DCON_A:    ld      a,(DATA_CON)
        cp      0FFh
        jr      z,OPEN_DCON2
        call    TCP_ABORT
OPEN_DCON2:     call    HALT

        ld      hl,0
        ld      de,0
        ld      iy,0FFFFh
        ld      bc,0
        ld      a,0FFh
        call    TCP_OPEN        ;Abre conexion pasiva
        ld      de,WHENOPEND_S
        ld      hl,OPENERR_T
        jp      c,SHOW_ERR
        ld      (DATA_CON),a

        ld      b,a
        ld      hl,TCP_INFO_BLOCK
        ld      a,TCPIP_TCP_STATE       ;Establece lo que queda de la cadena
        call    CALL_UNAPI
        or      a
        jr      nz,OPEN_DCON_E
        ld      de,(TCP_INFO_BLOCK+6)   ;Lee el puerto local

        ld      bc,(PORT_C_PNT)
        push    bc
        ld      a,d
        push    de
        call    SET_IP
        pop     de
        inc     hl
        ld      a,e
        call    SET_IP
        ld      hl,(PORT_C_PNT)
        dec     hl
        ld      (hl),0
        pop     hl
        ld      (PORT_C_PNT),hl

        ld      hl,C_PORT
        ld      de,SEND_COM_BUF
        ld      bc,32
        ldir
        call    APPEND_LF

        call    AUTOMATA_NO1    ;Envia comando PORT y espera respuesta,
        cp      2       ;termina si no es 2yz
        jr      nz,OPEN_DCON_E

        or      a
        ret

OPEN_DCON_E:    ld      a,(DATA_CON)
        call    TCP_ABORT
        ld      a,0FFh
        ld      (DATA_CON),a
        scf
        ret


;--- PUTRIEVE: Rutina generica para enviar datos con el comando PUT:
;              - Envia el comando PORT y abre una conexion de datos
;              - Envia los datos del fichero FILE_FH
;              - El comando a enviar sera (PUTR_COM),
;                junto a la palabra que haya
;                en USER_COM_BUF en el lugar PUTR_PAR
;              Vuelve con Cy=1 si hay cualquier error

PUTRIEVE:       call    CHK_CON
        jp      c,PUTR_END

        ;--- Abre conexion,
        ;    envia PORT, espera conexion OK

        call    OPEN_DCON       ;Abre conexion, envia PORT
        jp      c,PUTR_END

        ld      hl,(PUTR_COM)   ;Envia comando con el parametro
        call    SET_COMMAND
        ld      hl,USER_COM_BUF+1
        ld      de,SEND_COM_BUF+5
        ld      a,(PUTR_PAR)
        call    EXTPAR
        call    nc,SET_SPACE
        call    APPEND_LF
        call    SEND_COM

        call    WAIT_REPLY      ;Espera respuesta, que ha de
        jp      c,PUTR_E        ;ser 1yz
        cp      1
        jr      z,PUTR_WAIT
        cp      4
        jp      z,PUTR_E
        cp      5
        jp      z,PUTR_E
        jp      PUTR_EX

PUTR_WAIT:      call    HALT    ;Espera a que la conexion este
        ld      a,(DATA_CON)    ;o ESTABLISHED o cerrandose
        call    TCP_STATUS      ;(ya se han recibido todos los datos)
        or      a
        jp      z,PUTR_E2
        cp      4
        jr      c,PUTR_WAIT

        ;--- Conexion abierta: va leyendo datos del fichero
        ;    y los envia a la conexion

PUTR_LOOP:      ld      a,(FILE_FH)
        ld      b,a
        ld      c,_READ
        ld      hl,512
        ld      de,DATA_BUF
        call    DOS
        jr      nc,PUTR_RDOK

        ld      a,(HASH)
        or      a
        call    nz,CRLF
        ld      a,(DATA_CON)
        call    TCP_CLOSE
        call    HALT
        call    WAIT_REPLY      ;Fin del fichero: cierra conexcion de datos,
        jp      c,PUTR_END      ;espera respuesta de la conexion de control,
        cp      2       ;y termina
        jp      z,PUTR_END
        cp      4
        jp      z,PUTR_END
        cp      5
        jp      z,PUTR_END
        print   UNEXPEC_S
        scf
        jp      PUTR_END

PUTR_RDOK:      push    hl
        pop     bc
PUTR_LOP2:      push    bc
        call    HALT
        ld      a,(DATA_CON)
        ld      hl,DATA_BUF
        scf
        call    TCP_SEND        ;Intenta enviar datos
        pop     bc
        jr      nc,PUTR_OKDATA

        cp      ERR_BUFFER
        jr      z,PUTR_LOP2

        ld      a,(DATA_CON)    ;Conexion cerrada antes de tiempo?
        call    TCP_ABORT       ;Entonces mostramos error
        ld      a,(HASH)
        or      a
        call    nz,CRLF
        ld      a,0FFh
        ld      (DATA_CON),a
        print   DCONREF_S
        ;call    WAIT_REPLY       ;Conexion cerrada legalmente: la cerramos nosotros,
        ;jp      c,PUTR_END       ;espera respuesta de la conexion de control,
        ;cp      2                ;y termina
        ;jp      z,PUTR_END
        ;cp      4
        ;jp      z,PUTR_END
        ;cp      5
        ;jp      z,PUTR_END
        ;print   UNEXPEC_S
        scf
        jr      PUTR_END
PUTR_OKDATA:    ;

        ld      a,(HASH)
        or      a
        ld      e,"#"
        ld      c,_CONOUT
        call    nz,DO_DOS

        jp      PUTR_LOOP

        ;--- Rutinas de terminacion

PUTR_E: ld      a,(DATA_CON)    ;Error del comando "PORT":
        call    TCP_ABORT       ;cierra conexion y termina
        scf
        jp      PUTR_END

PUTR_E2:        print   DCONREF_S       ;Conexion de datos cerrada sin llegar
        ld      a,(DATA_CON)
        call    TCP_ABORT
        call    WAIT_REPLY      ;a abrirse (probable perdida de con. a internet)
        scf
        jp      PUTR_END

PUTR_EX:        ld      a,(DATA_CON)    ;Respuesta inesperada al
        call    TCP_ABORT       ;comando "PORT"
        call    R_UNEX
        scf
        ;jp     PUTR_END

PUTR_END:       push    af
        ld      a,(FILE_FH)
        cp      0FFh
        jr      z,PUTR_END2
        ld      a,(FILE_FH)
        ld      b,a
        ld      c,_CLOSE
        call    DO_DOS
        ld      a,0FFh
        ld      (FILE_FH),a
PUTR_END2:      pop     af

        ret

PUT_EXE:        db      0
PUTR_COM:       dw      0


;--- RETRIEVE: Rutina generica para obtener datos
;              desde una conexion de datos:
;              - Usa SILENT_ASCII y SILENT_BIN si MUST_ASCII=0FFh
;              - Envia el comando PORT y abre una conexion de datos
;              - Lee los datos recibidos. Si FILE_FH=0FFh, los
;                imprime por pantalla. Si no, los escribe en el fichero.
;              - El comando a enviar ha de estar en RETR_COM;
;                se envia junto a la palabra que haya
;                en USER_COM_BUF en el lugar RETR_PAR
;              Vuelve con Cy=1 si hay cualquier error

RETRIEVE:       call    CHK_CON
        jp      c,RETR_END

        ;--- Abre conexion, envia TYPE A si es necesario,
        ;    envia PORT, espera conexion OK

        ld      a,(MUST_ASCII)
        or      a
        jr      z,RETRV2
        call    SILENT_ASCII    ;Pone modo ASCII si es necesario
        jp      c,RETR_END

        ld      a,(LAST_REPLY)  ;Si "TYPE A" genera error,
        cp      2       ;no seguimos
        jr      z,RETRV2

        xor     a
        ld      (MUST_ASCII),a
        jp      RETR_END

RETRV2: call    OPEN_DCON       ;Abre conexion, envia PORT
        jr      nc,RETRV3

        ;xor     a
        ;ld      (MUST_ASCII),a
        jp      RETR_END

RETRV3: ld      hl,(RETR_COM)   ;Envia comando con el parametro
        call    SET_COMMAND
        ld      hl,USER_COM_BUF+1
        ld      de,SEND_COM_BUF+5
        ld      a,(RETR_PAR)
        call    EXTPAR
        call    nc,SET_SPACE
        call    APPEND_LF
        call    SEND_COM

        call    _WAIT_REPLY     ;Espera respuesta, que ha de
        jp      c,RETR_E        ;ser 1yz
        cp      1
        jr      z,RETR_WAIT
        cp      4
        jp      z,RETR_E
        cp      5
        jp      z,RETR_E
        jp      RETR_EX

RETR_WAIT:      call    HALT    ;Espera a que la conexion este
        ld      a,(DATA_CON)    ;o ESTABLISHED o cerrandose
        call    TCP_STATUS      ;(ya se han recibido todos los datos)
        or      a
        jp      z,RETR_E2
        cp      4
        jr      c,RETR_WAIT

        xor     a
        ld      (LINE_COUNT),a
        ld      (BYTE_COUNT),a

        ;--- Conexion abierta: va leyendo datos
        ;    y los imprime o los guarda en el fichero

RETR_LOOP:      call    HALT
        ld      a,(DATA_CON)
        ld      de,DATA_BUF
        ld      bc,512
        call    TCP_RCV ;Intenta recibir datos
        jr      nz,RETR_OKDATA

        ;cp     5       ;Si no hay datos pero la conexion sigue ESTABLISHED
        ;jp     nz,RETR_E2      ;(puede recibir mas datos), sigue esperando
        ld      a,(DATA_CON)
        call    TCP_STATUS
        cp      4
        jr      z,RETR_LOOP
        ld      a,(DATA_CON)
        call    TCP_CLOSE       ;TCP_ABORT
        ld      a,(HASH)
        or      a
        call    nz,CRLF
        ld      a,0FFh
        ld      (DATA_CON),a
        call    WAIT_REPLY      ;Conexion cerrada legalmente: la cerramos nosotros,
        jp      c,RETR_END      ;espera respuesta de la conexion de control,
        cp      2       ;y termina
        jp      z,RETR_END
        cp      4
        jp      z,RETR_END
        cp      5
        jp      z,RETR_END
        print   UNEXPEC_S
        scf
        jp      RETR_END
RETR_OKDATA:    ;

        ld      a,(FILE_FH)
        cp      0FFh
        jr      nz,RETR_FILE

        ;--- FILE_FH=0FFh: Imprime los datos en pantalla

        ld      hl,DATA_BUF     ;Imprime todos los datos recibidos
RETR_LOOP2:     push    bc
        push    hl
        ld      a,(hl)
        call    PRINT_PAUSE
        pop     hl
        inc     hl
        pop     bc
        dec     bc
        ld      a,b
        or      c
        jr      nz,RETR_LOOP2
        jp      RETR_LOOP

        ;--- FILE_FH<>0FFh: Guarda los datos en el fichero

RETR_FILE:      ld      a,(HASH)
        or      a
        ld      e,"#"
        push    bc
        ld      c,_CONOUT
        call    nz,DO_DOS
        pop     hl

        ld      a,(FILE_FH)
        ld      b,a
        ld      c,_WRITE
        ld      de,DATA_BUF
        call    DOS
        jr      c,RETR_E

        jp      RETR_LOOP

        ;--- Rutinas de terminacion

RETR_E: ld      a,(DATA_CON)    ;Error del comando "PORT":
        call    TCP_ABORT       ;cierra conexion y termina
        scf
        jp      RETR_END

RETR_E2:        print   DCONREF_S       ;Conexion de datos cerrada sin llegar
        ld      a,(DATA_CON)
        call    TCP_ABORT
        call    WAIT_REPLY      ;a abrirse (probable perdida de con. a internet)
        scf
        jp      RETR_END

RETR_EX:        ld      a,(DATA_CON)    ;Respuesta inesperada al
        call    TCP_ABORT       ;comando "PORT"
        call    R_UNEX
        scf
        ;jp     RETR_END

RETR_END:       push    af
        ld      a,(FILE_FH)
        cp      0FFh
        jr      z,RETR_END2
        ld      a,(FILE_FH)
        ld      b,a
        ld      c,_CLOSE
        call    DO_DOS
        ld      a,0FFh
        ld      (FILE_FH),a
RETR_END2:      ;

        ld      a,(MUST_ASCII)
        or      a
        jr      z,RETR_END2!
        ld      a,(CONTROL_CON)
        cp      0FFh
        call    nz,SILENT_BIN   ;Restaura TYPE antiguo
RETR_END2!:     pop     af
        ret

RETR_COM:       dw      0
RETR_PAR:       db      0
PUTR_PAR:       equ     RETR_PAR
MUST_ASCII:     db      0


;--- SILENT_ASCII: Establece modo ASCII sin mostrar respuesta
;                  aunque VERBOSE este activado.
;                  Devuelve Cy=1 en caso de error.

SILENT_ASCII:   ld      a,(VERBOSE)
        ld      (OLD_VERBOSE),a
        xor     a
        ld      (VERBOSE),a
        ld      a,(TYPE)        ;Primero pone tipo ASCII
        ld      (OLD_TYPE),a    ;(no muestra el resultado del comando
        call    R_ASCII ;aunque VERBOSE este activado)
        ld      a,(OLD_VERBOSE)
        ld      (VERBOSE),a
        ret


;--- SILENT_BIN: Restaura el modo de OLD_TYPE sin mostrar respuesta
;                aunque VERBOSE este activado.
;                Devuelve Cy=1 en caso de error.

SILENT_BIN:     ld      hl,SILENT_BIN2
        push    hl
        ld      a,(VERBOSE)     ;Restaura TYPE antiguo
        ld      (OLD_VERBOSE),a
        xor     a
        ld      (VERBOSE),a
        ld      a,(OLD_TYPE)
        or      a
        jp      z,R_ASCII
        jp      R_BINARY
SILENT_BIN2:    ld      a,(OLD_VERBOSE)
        ld      (VERBOSE),a
        ret


;--- MULTIPLE: Ejecuta un comando multiple (MGET, MPUT, MDELETE)
;              - Ejecuta NLST silenciosamente y guarda el resultado
;                en una lista
;              - Para cada nombre de fichero, pregunta "Y,N,A,C?" si en
;                modo PROMPT, y si la respuesta es "y", establece el nombre
;                de fichero como segundo parametro en USER_COM_BUF y ejecuta
;                la rutina (MUL_COM)
;              - Al preguntar para cada fichero, muestra la cadena (MUL_STR)

MULTIPLE:       call    _MULTIPLE
        push    af
        ld      a,(MUL_LISTA)
        ld      ix,0
        nesman  22
        ld      a,0FFh
        ld      (MUL_LISTA),a
        ld      a,(OLD_VERBOSE_M)
        ld      (VERBOSE),a
        pop     af
        ret

_MULTIPLE:      ;--- Crea una lista y si no hay memoria, termina con error

        ld      a,4
        ld      (ABORT_STAT),a

        ld      a,(VERBOSE)
        ld      (OLD_VERBOSE_M),a

        or      a       ; Lista interna
        nesman  20
        jr      nc,MUL_OK1

        print   OUTOFM_S
        ret

MUL_OK1:        ld      (MUL_LISTA),a

        ;--- Abre conexion, envia TYPE A,
        ;    envia PORT, espera conexion OK, envia NLST

        xor     a
        ld      (VERBOSE),a

        call    SILENT_ASCII    ;Pone modo ASCII si es necesario
        jp      c,MUL_END
        ld      a,0FFh
        ld      (MUST_ASCII),a

        call    OPEN_DCON       ;Abre conexion, envia PORT
        jp      c,MUL_END

        ld      hl,C_NLST       ;Envia NLST con el 2o parametro
        call    SET_COMMAND
        ld      hl,USER_COM_BUF+1
        ld      de,SEND_COM_BUF+5
        ld      a,2
        call    EXTPAR
        call    nc,SET_SPACE
        call    APPEND_LF
        call    SEND_COM

        ;debug   "1"
        call    WAIT_REPLY      ;Espera respuesta, que ha de
        ;debug   "2"
        jp      c,MUL_E ;ser 1yz
        cp      1
        jr      z,MUL_WAIT
        cp      4
        jp      z,MUL_E
        cp      5
        jp      z,MUL_E
        jp      MUL_EX

MUL_WAIT:       ;debug   "3"
        call    HALT    ;Espera a que la conexion este
        ld      a,(DATA_CON)    ;o ESTABLISHED o cerrandose
        call    TCP_STATUS      ;(ya se han recibido todos los datos)
        or      a
        jp      z,MUL_E2
        cp      4
        jr      c,MUL_WAIT

        ;debug   "4"
        xor     a
        ld      hl,DATA_BUF

        ;--- Va cogiendo Los nombres de fichero y los
        ;    inserta en la lista

MUL_NLST_LOOP:  push    af
        push    hl
MUL_NLST_LOOP2: call    GET_DDATA
        jr      c,MUL_NODATA
        cp      10
        jr      z,MUL_NLST_LOOP2
        cp      13
        jr      z,MUL_NEXT_NAME
        pop     hl
        ld      (hl),a
        inc     hl
        pop     af
        inc     a
        jr      MUL_NLST_LOOP

MUL_NEXT_NAME:  ;Nombre completo obtenido, HL apunta a su direccion
        ;y A contiene su longitud (en la pila)

        pop     hl ;Inserta nombre en la lista
        pop     af
        ld      l,a
        ld      h,0
        ld      a,(MUL_LISTA)
        ld      ix,0
        ld      b,3
        ld      iy,DO_DOS
        nesman  24
        jp      c,MUL_MEME

        ld      hl,DO_DOS
        ld      a,0
        jr      MUL_NLST_LOOP

        ;--- No se pueden coger mas datos: esperamos o
        ;    pasamos a tratar los nombres de fichero recibidos

MUL_NODATA:     pop     hl
        pop     bc
        push    af
        ld      (MUL_NAME_PNT),hl
        ld      a,b
        ld      (MUL_NAME_SIZE),a
        pop     af

        ;cp      5                ;Si no hay datos pero la conexion sigue ESTABLISHED
        ;jp      nz,MUL_E2        ;(puede recibir mas datos), sigue esperando
        ld      a,(DATA_CON)
        call    TCP_STATUS
        cp      4
        jr      nz,MUL_NODATA2

        call    HALT    ;Esperamos una interrupcion y
        ld      a,(MUL_NAME_SIZE)       ;volvemos a intentarlo
        ld      hl,(MUL_NAME_PNT)
        jr      MUL_NLST_LOOP

MUL_NODATA2:    ld      a,(DATA_CON)
        call    TCP_CLOSE       ;TCP_ABORT
        ld      a,0FFh
        ld      (DATA_CON),a
        call    WAIT_REPLY      ;Conexion cerrada legalmente: la cerramos nosotros,
        jp      c,MUL_END       ;espera respuesta de la conexion de control,
        cp      2       ;y termina
        jp      z,MUL_OK_LIST
        cp      4
        jp      z,MUL_END
        cp      5
        jp      z,MUL_END
        print   UNEXPEC_S
        scf
        jp      MUL_END

        ;--- Ya tenemos la lista completa de ficheros,
        ;    ahora ejecutamos el comando adecuado

MUL_OK_LIST:    xor     a
        ld      (MUST_ASCII),a
        call    SILENT_BIN
        jp      c,MUL_END

        ld      a,(OLD_VERBOSE_M)
        ld      (VERBOSE),a

        ;>>> MPUT salta aqui

MULTIPLE2:      ld      a,(PROMPT)
        cpl
        ld      (ALLFILES),a

        ;--- Obtiene un nombre de fichero y
        ;    pregunta si se ha de actuar sobre el,
        ;    solo si ALLFILES=0FFh

MUL_FILE_LOOP:  ld      a,(MUL_LISTA)
        ld      ix,0
        ld      b,1
        ld      h,3
        ld      iy,DATA_BUF
        nesman  25
        ret     c
        ld      hl,DATA_BUF
        add     hl,bc
        ld      (hl),0
        inc     bc
        inc     bc
        ld      a,c
        ld      (USER_COM_BUF+1),a

        ld      a,(ALLFILES)
        or      a
        jr      nz,MUL_DO_FILE

        ld      de,(MUL_STR)
        ld      c,_STROUT
        call    DO_DOS
        printz  DATA_BUF
        call    ASK_YNAC
        cp      3       ;Cancel?
        push    af
        ld      c,_STROUT
        ld      de,OPCAN_S
        call    z,DO_DOS
        pop     af
        ret     z
        cp      1       ;No?
        jr      z,MUL_FILE_LOOP
        or      a       ;Yes?
        jr      z,MUL_DO_FILE

        ld      a,0FFh   ;All
        ld      (ALLFILES),a

MUL_DO_FILE:    ld      hl," X"
        ld      (USER_COM_BUF+2),hl
        ld      hl,DATA_BUF
        ld      de,USER_COM_BUF+4
        ld      bc,252
        ldir

        ld      hl,(MUL_COM)
        call    JP_HL

        jp      MUL_FILE_LOOP

        ;--- Rutinas de terminacion

MUL_E:  ld      a,(DATA_CON)    ;Error del comando "PORT":
        call    TCP_ABORT       ;cierra conexion y termina
        scf
        jp      MUL_END

MUL_E2: print   DCONREF_S       ;Conexion de datos cerrada sin llegar
        ld      a,(DATA_CON)
        call    TCP_ABORT
        call    WAIT_REPLY      ;a abrirse (probable perdida de con. a internet)
        scf
        jp      MUL_END

MUL_EX: ld      a,(DATA_CON)    ;Respuesta inesperada al
        call    TCP_ABORT       ;comando "PORT"
        call    R_UNEX
        scf
        jr      MUL_END

MUL_MEME:       print   OUTOFM_S
        ld      a,(DATA_CON)
        call    TCP_ABORT
        call    WAIT_REPLY
        ;jr      MUL_END

MUL_END:        push    af
        ld      a,(MUST_ASCII)
        or      a
        jr      z,MUL_END2!
        ld      a,(CONTROL_CON)
        cp      0FFh
        call    nz,SILENT_BIN   ;Restaura TYPE antiguo
MUL_END2!:      pop     af
        ret

        ;--- Variables

MUL_LISTA:      db      0
MUL_NAME_SIZE:  db      0
MUL_NAME_PNT:   dw      0
OLD_VERBOSE_M:  db      0
MUL_STR:        dw      0
MUL_COM:        dw      0

JP_HL:  jp      (hl)


;--- R_ABORT: Rutina de tratamiento de CTRL-C o CTRL-STOP,
;             o de "abort" en errores de disco
;    La variable ABORT_STAT ha de contener uno de estos valores:
;    0: Inicializando el programa, o ejecutando TERM
;    1: Bucle principal, no hay conexion
;    2: Bucle principal, hay conexion, no se ejecuta ningun comando
;    3: Se esta ejecutando un comando local (configuracion, acceso a disco)
;    4: Se esta ejecutando un comando FTP, con o sin conexion de datos
;    5: Se esta ejecutando CLOSE o QUIT

R_ABORT:        pop     hl      ;Para ajustar la pila

        push    af
        xor     a
        ld      (LDIR_EXE),a
        ld      (PUT_EXE),a
        ld      a,(MUL_LISTA)
        ld      ix,0
        nesman  22
        ld      a,0FFh
        ld      (MUL_LISTA),a

        ld      a,(HOOKING)     ;Restauramos gancho CHPUT
        or      a       ;si es necesario
        jr      z,AB_NOHOOK
        xor     a
        ld      (HOOKING),a
        ld      hl,HOOK_OLD
        ld      de,H_CHPH
        ld      bc,5
        ldir

AB_NOHOOK:      pop     af

        ;--- Primero comprobamos si es un error de disco,
        ;    en ese caso simplemente terminamos

        cp      9Dh     ;Codigo de "disk operation aborted"
        jr      nz,R_AB_NODISK

        ld      a,b
        or      a
        ret

        ;--- Imprimimos "CTRL-C pressed" o "CTRL-STOP pressed"

R_AB_NODISK:    ld      de,CTRLC_S
        cp      9Eh     ;Codigo de "CTRL-C pressed"
        jr      z,R_AB_PRINT
        ld      de,CTRLS_S
        cp      9Fh     ;Codigo de "CTRL-STOP pressed"
        jr      z,R_AB_PRINT
        ld      de,UNKE_S       ;Error desconocido
R_AB_PRINT:     ld      c,_STROUT
        call    DO_DOS

        ld      a,(ABORT_STAT)

        ;--- 0: No hacemos nada (ignoramos CTRL-C/STOP)

R_ABORT_0:      or      a
        jr      nz,R_ABORT_1

        ret

        ;--- 1: Salimos del programa

R_ABORT_1:      cp      1
        jr      nz,R_ABORT_2

        print   EXITING_S
        jp      TERM

        ;--- 2: Ejecutamos CLOSE

R_ABORT_2:      cp      2
        jr      nz,R_ABORT_3

        print   DISCONN_S
        jp      R_CLOSE

        ;--- 3: Saltamos al bucle principal

R_ABORT_3:      cp      3
        jr      nz,R_ABORT_4

        print   ABCOMM_S
        call    CLOSE_FILE
        jp      MAIN_LOOP

        ;--- 4: Enviamos ABORT si no hay datos pendientes
        ;       en la conexion de control

R_ABORT_4:      cp      4
        jr      nz,R_ABORT_5

        ld      a,5
        ld      (ABORT_STAT),a

        call    CLOSE_FILE

        print   ABCOMM_S

        ld      a,(CONTROL_CON) ;Hay datos en conexion de control?
        call    TCP_STATUS      ;Entonces recogerlos y no
        or      a
        jp      z,MAIN_LOOP     ;enviar ABORT
        ld      a,h
        or      l
        jr      z,R_AB4_1

        call    WAIT_REPLY
        jr      R_AB4_2

R_AB4_1:        ;ld     hl,0F4FFh        ;Envia comando telnet IP
        ;ld     (SEND_COM_BUF),hl
        ;ld     hl,SEND_COM_BUF
        ;ld     bc,2
        ;scf
        ;ld     a,(CONTROL_CON)
        ;call   TCP_SEND

        ;ld     hl,0F2FFh        ;Envia secuencia telnet SYNCH
        ;ld     (SEND_COM_BUF),hl
        ;ld     hl,SEND_COM_BUF
        ;ld     bc,2
        ;ld     d,2     ;??? (si es datos urgentes, vas dao...)
        ;ld     a,(CONTROL_CON)
        ;call   TCP_SEND

        ld      hl,C_ABOR
        call    SET_COMMAND
        call    APPEND_LF
        call    AUTOMATA_NO1

R_AB4_2:        ld      a,(DATA_CON)
        cp      0FFh
        jp      z,MAIN_LOOP
        call    TCP_ABORT
        ld      a,0FFh
        ld      (DATA_CON),a
        jp      MAIN_LOOP

        ;--- 5: Abortamos conexion de control

R_ABORT_5:      ld      a,(DATA_CON)
        cp      0FFh
        jr      z,R_ABORT_52

        print   ABDCON_S
        ld      a,(DATA_CON)
        call    TCP_ABORT
        ld      a,0FFh
        ld      (DATA_CON),a
        ret

R_ABORT_52:     print   ABCCON_S

        call    CLOSE_FILE
        ld      a,(DATA_CON)
        cp      0FFh
        jr      z,R_ABORT_53
        call    TCP_ABORT
R_ABORT_53:     ld      a,(CONTROL_CON)
        call    TCP_ABORT

        jp      MAIN_LOOP


;--- Automata del protocolo de identificacion
;    Espera datos de la conexion IDENT_CON,
;    y los devuelve seguidos de IDENT_S

IDENT_AUTOM:    push    af
        push    bc
        push    de
        push    hl
        call    _IDENT_AUTOM
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

_IDENT_AUTOM:   ld      a,(IDENT_CON)
        cp      0FFh
        ret     z

        call    TCP_STATUS
        or      a
        jr      nz,IDENT_AUT1
        ld      a,0FFh
        ld      (IDENT_CON),a
        ret

IDENT_AUT1:     cp      4
        ret     c

        ld      a,(IDENT_CON)   ;Recoge datos
        ld      de,DATA_BUF
        ld      bc,256
        call    TCP_RCV
        ret     z

        push    bc
        ld      hl,DATA_BUF     ;Compone cadena de respuesta
        add     hl,bc
        ex      de,hl
        ld      hl,IDENT_S
        ld      bc,IDENT_LEN
        ldir

        pop     bc      ;Envia respuesta
        ld      hl,IDENT_LEN
        add     hl,bc
        push    hl
        pop     bc
        ld      hl,DATA_BUF
        ld      a,(IDENT_CON)
        scf
        call    TCP_SEND

        ret

;--- Codigo del gancho para CHPUT para enmascaramiento de password
;    Imprime todos los caracteres como "*",
;    excepto espacios, caracteres de control (<32 y 127)
;    y secuencias de escape

HOOK_CODE0:     pop     hl
        pop     bc   ;B=Caracter a imprimir
        ld      a,(ESC_CHAR)
        or      a
        jr      z,HOOK_C0_NORMAL
        ld      c,a     ;C=Caracter en ESC_CHAR

        ;Tratamiento de una secuencia de escape

        cp      27      ;El caracter anterior era ESC:
        ld      a,b     ;Ponemos en ESC_CHAR el caracter
        jr      z,HOOK_C0_SETESC        ;actual e imprimimos el ESC
        ld      a,c

        cp      1       ;"1": secuencia "ESC Y n m"
        ld      a,0     ;y el caracter actual es "m":
        jr      z,HOOK_C0_SETESC        ;lo imprimimos
        ld      a,c

        cp      "Y"     ;Secuencia "ESC Y n m" y el
        ld      a,1     ;caracter actual es "n":
        jr      z,HOOK_C0_SETESC        ;lo imprimimos
        ld      a,c

        and     11111110b       ;Secuencia "ESC x n" o "ESC y n"
        cp      "x"     ;y el caracter actual es "n":
        ld      a,0     ;lo imprimimos
        jr      z,HOOK_C0_SETESC

        ld      a,b     ;Otra secuencia "ESC m" ya completa
        jr      HOOK_C0_NORMAL

HOOK_C0_SETESC: ld      (ESC_CHAR),a    ;ESC_CHAR=0 si no estamos
        ld      a,b     ;en una secuencia de escape
        jr      HOOK_C0_OK

        ;Tratamiento normal (no estamos en secuencia ESC)

HOOK_C0_NORMAL: ld      a,b
        cp      27
        jr      nz,HOOK_C0_NORM2
        ld      (ESC_CHAR),a
        jr      HOOK_C0_OK
HOOK_C0_NORM2:  cp      33
        jr      c,HOOK_C0_OK
        cp      127
        jr      z,HOOK_C0_OK
        ld      a,"*"
HOOK_C0_OK:     push    af
        push    hl
HOOK_CODE0_END: ;

;--- Rutinas para establecer y resetear el gancho

SET_HOOK:       push    af
        push    bc
        push    de
        push    hl
        di
        ld      a,0C3h
        ld      (H_CHPH),a
        ld      hl,HOOK_CODE
        ld      (H_CHPH+1),hl
        ld      a,0FFh
        ld      (HOOKING),a
        ei
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

RESET_HOOK:     push    af
        push    bc
        push    de
        push    hl
        di
        ld      hl,HOOK_OLD
        ld      de,H_CHPH
        ld      bc,5
        ldir
        ei
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret


;--- Code to switch TCP/IP implementation on page 1, if necessary

SET_UNAPI:
        ld      a,(UNAPI_IS_SET)
        or      a
        ret     nz
        dec     a
        ld      (UNAPI_IS_SET),a
UNAPI_SLOT:     ld      a,0
        ld      h,40h
        call    ENASLT
UNAPI_SEG:      ld      a,0
        jp      PUT_P1

CALL_UNAPI:     ex      af,af'
        exx
        call    SET_UNAPI
        ei
        ex      af,af'
        exx

DO_UNAPI:       jp      0


;--- Code to call a DOS function

DO_DOS:
        ex      af,af'
        xor     a
        ld      (UNAPI_IS_SET),a
        ex      af,af'
        jp      5


        ;>>> These rouines invoke the TCP related TCP/IP UNAPI <<<
        ;>>> routines accepting the old INL input parameters   <<<               

;--- TCP_OPEN: Open a new TCP connection.
;Input:  A = 0 for active, 1 for passive
;        L.H.E.D = remote IP (0.0.0.0 for passive with unespecified remote socket)
;        IX = Remote port (ignored if IP=0.0.0.0)
;        IY = Local port (0FFFFh for random between 16384 and 32767)
;        BC = Usuer timeout in seconds
;             (1-1080, 0 for 3 minutes, 0FFFFh for infinite)
;Output: Cy=0 if OK, 1 if error
;        If OK: A = Connection number
;        If error: A = UNAPI Error code

TCP_OPEN:
        ld      (TCP_INFO_BLOCK),hl
        ld      (TCP_INFO_BLOCK+2),de
        ld      (TCP_INFO_BLOCK+4),ix
        ld      (TCP_INFO_BLOCK+6),iy
        ld      (TCP_INFO_BLOCK+8),bc
        and     1
        ld      (TCP_INFO_BLOCK+10),a

        ld      a,TCPIP_TCP_OPEN
        ld      hl,TCP_INFO_BLOCK
        call    CALL_UNAPI
        or      a
        scf
        ret     nz
        ld      a,b
        or      a
        ret

TCP_INFO_BLOCK: ds      11


;--- TCP_CLOSE: Close a TCP connection
;Input:  A = Connection number
;Output: Cy=1 if error, then A=UNAPI error code

TCP_CLOSE:
        ld      b,a
        ld      a,TCPIP_TCP_CLOSE
        call    CALL_UNAPI
        or      a
        scf
        ret     nz
        or      a
        ret


;--- TCP_ABORT: Abort a TCP connection
;Input:  A = Connection number
;Output: Cy=1 if error, then A=UNAPI error code

TCP_ABORT:
        ld      b,a
        ld      a,TCPIP_TCP_ABORT
        call    CALL_UNAPI
        or      a
        scf
        ret     nz
        or      a
        ret


;--- TCP_STATUS: Obtain the state of a TCP connection
;Input:  A = Connection number
;Output: Cy=1 if error, then A=UNAPI error code
;        Cy=0 if OK, and:
;        A = Connection state
;        HL = Available received bytes
;        DE = Available space for outgoing bytes
;        BC = Bytes in retransmission queue
;        IX = Connection TCB address in data segment (NOT available here)
;        (If A=0, B=LAST_CLOSE)

TCP_STATUS:
        ld      b,a
        ld      a,TCPIP_TCP_STATE
        ld      hl,0
        call    CALL_UNAPI
        or      a
        jr      z,TCP_STATUS_2
        ld      b,c
        xor     a       ;Convert errors to "connection closed"
        ret

TCP_STATUS_2:
        ld      a,b
        push    ix
        pop     de
        ld      ix,0
        ld      bc,0
        or      a
        ret


;--- TCP_SEND: Send data to a TCP connection
;Input:  A = Connection number
;        HL = Data address in TPA
;        BC = Data length
;        Cy=1 for PUSH
;Output: Cy=1 if error, then A=UNAPI error code

TCP_SEND:
        push    hl
        push    bc

        ld      b,a
        rla
        and     1
        ld      c,a

        pop     hl
        pop     de
        ld      a,TCPIP_TCP_SEND
        call    CALL_UNAPI
        or      a
        scf
        ret     nz
        or      a
        ret


;--- TCP_RCV: Obtain data from a TCP connection
;Input:  A  = Connection number
;        DE = Destination address for data
;        BC = Data length
;Output: Cy=1 if error, then A=UNAPI error code
;             1: Invalid connection number
;             2: Connection is closed
;        BC = Actual obtained data length
;        Z = 1 if BC=0

TCP_RCV:
        push    af
        push    bc
        pop     hl
        pop     bc

        ld      a,TCPIP_TCP_RCV
        call    CALL_UNAPI
        or      a
        scf
        ret     nz

        ld      a,b
        or      c
        ld      a,0
        ret


;************************************
;***                              ***
;***   DATA, VARIABLES, STRINGS   ***
;***                              ***
;************************************

DATA:
        org     8000h

DATA_START:

;--- Variables

IP_LOCAL:       ds      4
IP_REMOTE:      ds      4
PORT_REMOTE_C:  dw      21
PORT_REMOTE_I:  dw      0       ;Ident: el puerto local sera el 113
PORT_REMOTE_D:  dw      0
HAY_NMAN:       db      0
DATA_CON:       db      0FFh
CONTROL_CON:    db      0FFh
IDENT_CON:      db      0FFh
VERBOSE:        db      0FFh
XCOM:   db      0
ES_XCOM:        db      0
SAVESP: dw      0
TYPE:   db      0       ;0 para ASCII, 1 para binario
DEBUG:  db      0
BELL:   db      0
HASH:   db      0
PROMPT: db      0FFh
PAUSE:  db      0
PASSIVE:        db      0
OLD_TYPE:       db      0
OLD_VERBOSE:    db      0
PORT_C_PNT:     dw      C_PORT+5        ;Puntero a la parte "puerto" de PORT_C
FILE_FH:        db      0FFh
FILES_QUEUE:    db      0FFh     ;Cola para guardar los nombres de fichero
QUITTING:       db      0       ;0FFh cuando se esta cerrando/saliendo
ALLFILES:       db      0
ALSO_RONLY:     db      0
LINE_COUNT:     db      0
BYTE_COUNT:     db      0
INS_IX: dw      0
ABORT_STAT:     db      0
LAST_REPLY:     db      0
MSS:    dw      448     ;Valor fijo
HOOKING:        db      0       ;0FFh cuando el gancho CHPUT esta parcheado
UNAPI_IS_SET:   db      0       ;0FFh when UNAPI slot/seg is switched on page 1

;--- Pseudo-TCBs

;Control connection

IP_REMOTE_C:    db      0,0,0,0
;PORT_REMOTE_C:    dw      21

;Data connection

IP_REMOTE_D:    db      0,0,0,0
;PORT_REMOTE_D: dw      0
        ;db     0FFh     ;Control connection is passive

;Ident protocol connection

;PORT_REMOTE_I:    dw      0
        ;dw     113
        ;db     0FFh     ;Is passive


;--- Cadenas de texto (informacion y errores)

PRESEN_S:       db      13,10,"FTP client for the TCP/IP UNAPI 1.0",13,10
        db      "By Konamiman, 4/2010",13,10,10
TYPEHELP_S:     db      "Type ",34,"HELP",34," or ",34,"?",34," at any time to obtain help.",13,10,10,"$"
NONMAN_S:       db      13,10,"*** This command needs NestorMan 1.21 or higher to be installed",13,10,13,10,"$"

ERROR_S:        db      13,10,"*** ERROR $"
UNKERR_S:       db      "Unknown error",13,10,"$"
UNKCOM_S:       db      "Unknown command",13,10,"$"
INVPAR_S:       db      "Invalid or missing parameter(s) for command",13,10,"$"
NOHELP_S:       db      " is not a command implemented in this application",13,10,"$"
WHENDNS_S:      db      "when resolving server name:",13,10,"    $"
WHENOPEN_S:     db      "when creating or accessing local file:",13,10,"    $"
WHENCONN_S:     db      "when connecting to the server:",13,10,"    $"
WHENOPEND_S:    db      "when opening data connection:",13,10,"    $"
CONNECTING_S:   db      "Connecting (press ESC to cancel)... $"
CONLOST_S:      db      13,10,"*** ERROR: Connection to FTP server lost",13,10,10,"$"
NOMEM_S:        db      13,10,"*** ERROR: Not enough memory to enqueue data",13,10,10,"$"
UNEXPEC_S:      db      13,10,"*** ERROR: Unexpected reply from FTP server",13,10,10,"$"
CONREF_S:       db      13,10,"*** ERROR: Connection refused",13,10,10,"$"
DCONREF_S:      db      13,10,"*** ERROR: Unexpected data connection loss",13,10,10,"$"
OUTOFM_S:       db      13,10,"*** ERROR: Out of memory",13,10,"$"
DISKERR_S:      db      13,10,"*** Disk error:",13,10,"    $"
CTRLC_S:        db      13,10,"*** CTRL-C pressed: $"
CTRLS_S:        db      13,10,"*** CTRL-STOP pressed: $"
UNKE_S: db      13,10,"*** Unknown error!: $"
CANCELLED_S:    db      13,10,"*** Connection cancelled",13,10,"$"
EXITING_S:      db      "Exiting FTP application",13,10,"$"
DISCONN_S:      db      "Disconnecting from FTP server",13,10,"$"
ABCOMM_S:       db      "Aborting command execution",13,10,"$"
ABCCON_S:       db      "Aborting FTP server connection",13,10,"$"
ABDCON_S:       db      "Aborting data connection",13,10,"$"
FLUSHED_S:      db      "Flushing: $"
ANONYMOUS_S:    db      "anonymous",0
NONE_S: db      "none",0
ENV_USER:       db      "FTP_USER",0
ENV_PASSWORD:   db      "FTP_PASSWORD",0
ENV_ACCOUNT:    db      "FTP_ACCOUNT",0

FTP_S:  db      13,"ftp>$"
FLECHA_S:       db      13,"--->$"
ON_S:   db      "ON$"
OFF_S:  db      "OFF$"
OK_S:   db      "OK",13,10,"$"
TURNED_S:       db      " mode turned $"
TYPESET_S:      db      "Type set to $"

HASH_M_S:       db      "Hash$"
DEBUG_M_S:      db      "Debug$"
VERBOSE_M_S:    db      "Verbose$"
PROMPT_M_S:     db      "Prompt$"
BELL_M_S:       db      "Bell$"
PAUSE_M_S:      db      "Pause$"
PASSIVE_M_S:    db      "Passive$"
XCOM_M_S:       db      "X Commands$"
HASH_S: db      "Hash:    $"
DEBUG_S:        db      "Debug:   $"
VERBOSE_S:      db      "Verbose: $"
PROMPT_S:       db      "Prompt:  $"
PASSIVE_S:      db      "Passive: $"
PAUSE_S:        db      "Pause:   $"
BELL_S: db      "Bell:    $"
TYPE_S: db      "Type:    $"
XCOM_S: db      "X Commands: $"
ASCII_S:        db      "ASCII",13,10,"$"
BINARY_S:       db      "Binary",13,10,"$"

DISCON_S:       db      13,"Disconnected",13,10,"$"
CONNTO_S:       db      13,10,"Connected to: $"
USER._S:        db      "User ($"
PASSWORD._S:    db      "Password ($"
CIERRAPAR_S:    db      "): $"
ACCOUNT._S:     db      "Account ($"
CURPATH_S:      db      "Current local path: $"
PATHCHAN_S:     db      "Local path changed to: $"
DIROF_S:        db      13,10,"Directory of $"
ESDIR_S:        db      "  <dir>$"
FFOUND_S:       db      " file(s) found",13,10,"$"
DFOUND_S:       db      " directory(es) found",13,10,"$"
KFREE_S:        db      "K free on drive $"
DELETE_S:       db      "Delete local file $"
RECEIVE_S:      db      "Receive file $"
DELETER_S:      db      "Delete file $"
SENDFILE_S:     db      "Send file $"
OPCOMP_S:       db      "Operation completed",13,10,"$"
OPCAN_S:        db      "Operation cancelled, remaining files skipped",13,10,"$"
YNAC_S: db      " (y,n,a,c)? $"
ALCON_S:        db      "Already connected, CLOSE first",13,10,"$"
PRESS_S:        db      "--- Press any key to continue (",34,"P",34," to turn off pause mode) --- $"

IDENT_S:        db      ":USERID:OTHER:MSX-DOS 2 running FTP for the TCP/IP UNAPI"
IDENT_S_END:    ;
IDENT_LEN:      equ     IDENT_S_END-IDENT_S

;--- Cadenas de ayuda

BIGHELP_H:      db      13,10,"Available commands:",13,10,10
        db      "?               dir             ls              recv",13,10
        db      "!               disconnect      lshow           remotehelp",13,10
        db      "append          get             mdelete         rename",13,10
        db      "ascii           hash            mget            rmdir",13,10
        db      "bell            help            mkdir           send",13,10
        db      "binary          lcd             mput            show",13,10
        db      "bye             ldelete         open            status",13,10
        db      "cd              ldir            passive         type",13,10
        db      "cdup            literal         pause           user",13,10
        db      "close           lmkdir          prompt          verbose",13,10
        db      "debug           lrename         put             xcommands",13,10
        db      "delete          lrmdir          quote",13,10
        db      10,"Program execution: FTP [<server name>|<IP address> [<remote port>]]",13,10
        db      "On ",34,"multiple",34," commands, ",34,"(y,n,a,c)?",34," means ",34,"(Yes, No, yes to All, Cancel)?",34,13,10,10
        db      "Default values for the login sequence can be set up in the environment",13,10
        db      "variables FTP_USER, FTP_PASSWORD and FTP_ACCOUNT",13,10
        db      10,"$"

H_APPEND:       db      "APPEND <local file> <remote file>",13,10
        db      "Appends the content of the local file",13,10
        db      "at the end of the remote file.",13,10,"$"

H_ASCII:        db      "ASCII",13,10
        db      "Sets the transfer mode to ASCII (same as TYPE A).",13,10,"$"

H_BELL: db      "BELL",13,10
        db      "Turns on/off the bell mode. In this mode, a BEEP will sound",13,10
        db      "when a command execution is complete.",13,10,"$"

H_BINARY:       db      "BINARY",13,10
        db      "Sets the transfer mode to binary (same as TYPE I).",13,10,"$"

H_CD:   db      "CD [<directory>]",13,10
        db      "Changes to the specified remote directory.",13,10
        db      "If no directory is specified, shows the current one (same as ",34,"PWD",34,").",13,10,"$"

H_CDUP: db      "CDUP",13,10
        db      "Changes to the parent directory (usually same as CD ..)",13,10,"$"

H_CLOSE:        db      "CLOSE|DISCONNECT",13,10
        db      "Closes connection to FTP server.",13,10,"$"

H_DEBUG:        db      "DEBUG",13,10
        db      "Turns on/off the debug mode. In this mode, all commands sent",13,10
        db      "to the FTP server will be printed on the screen.",13,10,"$"

H_DELETE:       db      "DELETE <filename>",13,10
        db      "Deletes the specified remote file.",13,10,"$"

H_DIR:  db      "DIR [<mask> [<filename>]]",13,10
        db      "Shows the detailed contents of the remote directory",13,10
        db      "according to the specified mask (all files if omitted).",13,10
        db      "If <filename> is specified, information will be stored on",13,10
        db      "the specified file instead of being shown on the screen.",13,10
        db      "Mask specification is mandatory when specifying <filename>,",13,10
        db      "use ",34,".",34," to specify ",34,"all files",34,".",13,10,"$"

H_FLUSH:        ;db      "FLUSH",13,10
        ;db      "Flushes any data received from the FTP server but not yet",13,10
        ;db      "consummed by the application. This type of data appears tipically",13,10
        ;db      "when aborting commands with CTRL-C. Use FLUSH when the application",13,10
        ;db      "starts to act incorrectly or gives strange errors.",13,10,"$"

H_GET:  db      "GET|RETR <filename> [<local name>]",13,10
        db      "Obtains the specified remote filename.",13,10,"$"

H_HASH  db      "HASH",13,10
        db      "Turns on/off the hash mode. In this mode, every time that",13,10
        db      "new data arrives from the data connection, a ",34,"#",34," symbol",13,10
        db      "is printed on the screen.",13,10,"$"

H_HELP: db      "HELP|? [<command>]",13,10
        db      "Shows help on available commands.",13,10,"$"

H_LCD:  db      "LCD [<drive>:][<directory>]",13,10
        db      "Changes to the specified local drive and/or directory.",13,10
        db      "If no parameter is specified, shows the current drive and directory.",13,10,"$"

H_LDELETE:      db      "LDELETE <mask> [R]",13,10
        db      "Deletes the specified local file(s).",13,10
        db      "With ",34,"R",34," deletes also read-only file(s).",13,10,"$"

H_LDIR: db      "LDIR [<path>",92,"][<mask>]",13,10
        db      "Shows the contents of the specified local directory (current one if omitted)",13,10
        db      "according to the specified mask (all files if omitted).",13,10,"$"

H_LITERAL:      db      "LITERAL|QUOTE <command>",13,10
        db      "!<command>",13,10
        db      "Sends a raw command to the FTP server.",13,10
        db      "When using ",34,"!",34,", do not put an space between it and the command",13,10
        db      "(for example: !NOOP)",13,10,"$"

H_LMKDIR:       db      "LMKDIR <directory name>",13,10
        db      "Creates the specified local directory.",13,10,"$"

H_LRENAME:      db      "LRENAME <mask> <new name(s)>",13,10
        db      "Renames the specified local file(s).",13,10,"$"

H_LRMDIR:       db      "LRMDIR <directory name>",13,10
        db      "Removes the specified local directory.",13,10,"$"

H_LS:   db      "LS [<mask> [<filename>]]",13,10
        db      "Shows the contents of the remote directory (filenames only)",13,10
        db      "according to the specified mask (all files if omitted).",13,10
        db      "If <filename> is specified, information will be stored on",13,10
        db      "the specified file instead of being shown on the screen.",13,10
        db      "Mask specification is mandatory when specifying <filename>,",13,10
        db      "use ",34,".",34," to specify ",34,"all files",34,".",13,10,"$"

H_LSHOW:        db      "LSHOW <filename>",13,10
        db      "Shows the contents of the specified local file",13,10
        db      "(which is assumed to be a text file).",13,10,"$"

H_MDELETE:      db      "MDELETE <mask>",13,10
        db      "Deletes multiple remote files, according to the mask.",13,10
        db      "This command needs NestorMan 1.21 or higher to be installed.",13,10,"$"

H_MGET: db      "MGET <mask>",13,10
        db      "Obtains multiple remote files.",13,10
        db      "This command needs NestorMan 1.21 or higher to be installed.",13,10,"$"

H_MKDIR:        db      "MKDIR <directory name>",13,10
        db      "Creates the specified remote directory.",13,10,"$"

H_MPUT: db      "MPUT <mask>",13,10
        db      "Sends multiple files to the FTP server.",13,10
        db      "This command needs NestorMan 1.21 or higher to be installed.",13,10,"$"

H_OPEN: db      "OPEN <server name>|<IP address> [<port number>]",13,10
        db      "Opens a connection to the specified FTP server.",13,10
        db      "Default port number is 21.",13,10,"$"

H_PASSIVE:      db      "PASSIVE",13,10
        db      "Turns on/off the passive mode. In this mode, the application opens",13,10
        db      "actively the data connections, instead of waiting for the server to do it.",13,10,"$"

H_PAUSE:        db      "PAUSE",13,10
        db      "Turns on/off the pause mode. In this mode, all commands involving",13,10
        db      "data output to the screen (LIST, LS, SHOW and LSHOW) make a pause",13,10
        db      "and ask for key pressing after a complete screen has been displayed.",13,10,"$"

H_PROMPT:       db      "PROMPT",13,10
        db      "Turns on/off the prompt mode. In this mode, all commands involving",13,10
        db      "multiple files processing (MGET, MPUT, MDELETE, LDELETE) ask the user",13,10
        db      "for confirmation on each file.",13,10,"$"

H_PWD:  db      "PWD",13,10
        db      "Shows current remote directory",13,10
        db      "(same as ",34,"CD",34," without parameters).",13,10,"$"

H_REMOTEHELP:   db      "REMOTEHELP [<command>]",13,10
        db      "Requests and shows help from the FTP server.",13,10,"$"

H_RENAME:       db      "RENAME <filename> <new name>",13,10
        db      "Renames the specified remote file.",13,10,"$"

H_RMDIR:        db      "RMDIR <directory name>",13,10
        db      "Removes the specified remote directory.",13,10,"$"

H_SEND: db      "PUT|SEND <filename>",13,10
        db      "Sends the specified local file to the FTP server.",13,10,"$"

H_SHOW: db      "SHOW <filename>",13,10
        db      "Shows the contents of the specified remote file",13,10
        db      "(which is assumed to be a text file).",13,10,"$"

H_STATUS:       db      "STATUS",13,10
        db      "Shows the current status of the application.",13,10,"$"

H_TYPE: db      "TYPE A|I"
        db      "Sets the file transfer type to ASCII (A) or binary (I).",13,10
        db      "Commands ASCII and BINARY can be used for the same purpose.",13,10,"$"

H_QUIT: db      "BYE|QUIT",13,10
        db      "Closes connection to FTP server and exits application.",13,10,"$"

H_USER: db      "USER <username>",13,10
        db      "(Re)starts the login procedure on the FTP server.",13,10
        db      "Default values por user, password and account information",13,10
        db      "can be set up in the environment variables FTP_USER,",13,10
        db      "FTP_PASSWORD and FTP_ACCOUNT respectively.",13,10,"$"

H_VERBOSE:      db      "VERBOSE",13,10
        db      "Turns on/off the verbose mode. In this mode, all replies received",13,10
        db      "from the server are printed on the screen (error messages are always printed).",13,10,"$"

H_XCOMMANDS:    db      "XCOMMANDS",13,10
        db      "Turns on/off the ",34,"X",34," commands mode. In this mode, FTP commands",13,10
        db      "XMKD, XRMD, XPWD, XCUP and XCWD are sent to the FTP server",13,10
        db      "instead of MKD, RMD, PWD, CDUP and CWD, respectively.",13,10,"$"

;--- Comandos para enviar al servidor FTP

C_ABOR: db      "ABOR",0
C_ACCT: db      "ACCT",0
C_APPE: db      "APPE",0
C_CDUP: db      "CDUP",0
C_DELE: db      "DELE",0
C_CWD:  db      "CWD",0,0
C_RETR: db      "RETR",0
C_HELP: db      "HELP",0
C_LIST: db      "LIST",0
C_MKD:  db      "MKD",0,0
C_NLST: db      "NLST",0
C_PASS: db      "PASS",0
C_PASV: db      "PASV",0
C_PORT: db      "PORT 000,000,000,000,000,000",13,10
C_PWD:  db      "PWD",0,0
C_QUIT: db      "QUIT",0
C_RMD:  db      "RMD",0,0
C_RNFR: db      "RNFR",0
C_RNTO: db      "RNTO",0
C_STOR: db      "STOR",0
C_TYPE: db      "TYPE",0
C_USER: db      "USER",0
C_XCUP: db      "XCUP",0


;--- Tabla de comandos de usuario y direccion de su rutina y texto de ayuda

COMMAND_TABLE:

        ;?,HELP
        db      "?",0
        dw      R_HELP
        dw      H_HELP

        ;!,LITERAL
        db      "!",0
        dw      R_LITERAL
        dw      H_LITERAL

        ;APPEND
        db      "APPEND",0
        dw      R_APPEND
        dw      H_APPEND

        ;ASCII
        db      "ASCII",0
        dw      R_ASCII
        dw      H_ASCII

        ;BELL
        db      "BELL",0
        dw      R_BELL
        dw      H_BELL

        ;BYE,QUIT
        db      "BYE",0
        dw      R_QUIT
        dw      H_QUIT

        ;BINARY
        db      "BINARY",0
        dw      R_BINARY
        dw      H_BINARY

        ;CD
        db      "CD",0
        dw      R_CD
        dw      H_CD

        ;CDUP
        db      "CDUP",0
        dw      R_CDUP
        dw      H_CDUP

        ;CLOSE
        db      "CLOSE",0
        dw      R_CLOSE
        dw      H_CLOSE

        ;DEBUG
        db      "DEBUG",0
        dw      R_DEBUG
        dw      H_DEBUG

        ;DELETE
        db      "DELETE",0
        dw      R_DELETE
        dw      H_DELETE

        ;DIR
        db      "DIR",0
        dw      R_DIR
        dw      H_DIR

        ;DISCONNECT,CLOSE
        db      "DISCONNECT",0
        dw      R_CLOSE
        dw      H_CLOSE
        
        ;FLUSH
        ;db      "FLUSH",0
        ;dw      R_FLUSH
        ;dw      H_FLUSH

        ;GET
        db      "GET",0
        dw      R_GET
        dw      H_GET

        ;HASH
        db      "HASH",0
        dw      R_HASH
        dw      H_HASH

        ;HELP
        db      "HELP",0
        dw      R_HELP
        dw      H_HELP

        ;LCD
        db      "LCD",0
        dw      R_LCD
        dw      H_LCD

        ;LDELETE
        db      "LDELETE",0
        dw      R_LDELETE
        dw      H_LDELETE

        ;LDIR
        db      "LDIR",0
        dw      R_LDIR
        dw      H_LDIR

        ;LITERAL
        db      "LITERAL",0
        dw      R_LITERAL
        dw      H_LITERAL

        ;LMKDIR
        db      "LMKDIR",0
        dw      R_LMKDIR
        dw      H_LMKDIR

        ;LRENAME
        db      "LRENAME",0
        dw      R_LRENAME
        dw      H_LRENAME

        ;LRMDIR
        db      "LRMDIR",0
        dw      R_LRMDIR
        dw      H_LRMDIR

        ;LS
        db      "LS",0
        dw      R_LS
        dw      H_LS

        ;LSHOW
        db      "LSHOW",0
        dw      R_LSHOW
        dw      H_LSHOW

        ;MDELETE
        db      "MDELETE",0
        dw      R_MDELETE
        dw      H_MDELETE

        ;MGET
        db      "MGET",0
        dw      R_MGET
        dw      H_MGET

        ;MKDIR
        db      "MKDIR",0
        dw      R_MKDIR
        dw      H_MKDIR

        ;MPUT
        db      "MPUT",0
        dw      R_MPUT
        dw      H_MPUT

        ;OPEN
        db      "OPEN",0
        dw      R_OPEN
        dw      H_OPEN

        ;PASSIVE
        db      "PASSIVE",0
        dw      R_PASSIVE
        dw      H_PASSIVE

        ;PROMPT
        db      "PROMPT",0
        dw      R_PROMPT
        dw      H_PROMPT

        ;PAUSE
        db      "PAUSE",0
        dw      R_PAUSE
        dw      H_PAUSE

        ;PUT,SEND
        db      "PUT",0
        dw      R_SEND
        dw      H_SEND

        ;PWD
        db      "PWD",0
        dw      R_PWD
        dw      H_PWD

        ;QUIT
        db      "QUIT",0
        dw      R_QUIT
        dw      H_QUIT

        ;QUOTE,LITERAL
        db      "QUOTE",0
        dw      R_LITERAL
        dw      H_LITERAL

        ;RECV,GET
        db      "RECV",0
        dw      R_GET
        dw      H_GET

        ;REMOTEHELP
        db      "REMOTEHELP",0
        dw      R_REMOTEHELP
        dw      H_REMOTEHELP

        ;RENAME
        db      "RENAME",0
        dw      R_RENAME
        dw      H_RENAME

        ;RMDIR
        db      "RMDIR",0
        dw      R_RMDIR
        dw      H_RMDIR

        ;SEND
        db      "SEND",0
        dw      R_SEND
        dw      H_SEND

        ;SHOW
        db      "SHOW",0
        dw      R_SHOW
        dw      H_SHOW

        ;STATUS
        db      "STATUS",0
        dw      R_STATUS
        dw      H_STATUS

        ;TYPE
        db      "TYPE",0
        dw      R_TYPE
        dw      H_TYPE

        ;USER
        db      "USER",0
        dw      R_USER
        dw      H_USER

        ;VERBOSE
        db      "VERBOSE",0
        dw      R_VERBOSE
        dw      H_VERBOSE

        ;XCOMMANDS
        db      "XCOMMANDS",0
        dw      R_XCOMMANDS
        dw      H_XCOMMANDS

        db      0

;--- Tabla de errores DNS

DNSERRS_T:      db      1,"Query format error$"
        db      2,"Server failure$"
        db      3,"Name error (unknwon host)$"
        db      4,"Query type not implemented$"
        db      5,"Query refused$"
        db      6,"DNS error 6$"
        db      7,"DNS error 7$"
        db      8,"DNS error 8$"
        db      9,"DNS error 9$"
        db      10,"DNS error 10$"
        db      11,"DNS error 11$"
        db      12,"DNS error 12$"
        db      13,"DNS error 13$"
        db      14,"DNS error 14$"
        db      15,"DNS error 15$"
        db      16,"Can't get a reply from DNS$"
        db      17,"Operation timeout expired$"
        db      18,"Query aborted$"
        db      19,"Connection lost$"
        db      20,"DNS did not give neither a reply nor a pointer to another DNS$"
        db      21,"Answer is truncated$"
        db      0

DNSQERRS_T:     db      ERR_NO_NETWORK,"No network connection$"
        db      ERR_NO_DNS,"No DNS servers available$"
        db      ERR_NOT_IMP,"This TCP/IP UNAPI implementation does not support name resolution.",13,10
        db      "An IP address must be specified instead.$"
        db      0


;--- Tabla de errores al abrir una conexion

OPENERR_T:      db      ERR_NO_FREE_CONN,"Too many TCP connections opened$"
                db      ERR_NO_NETWORK,"No network connection found$"
                db      ERR_CONN_EXISTS,"Connection already exists, try another local port number$"
                db      ERR_INV_PARAM,"Invalid parameter when opening connection$"
                db      0

        db      0

DATA_END:

;--- Bufer para el comando tecleado por el usuario

USER_COM_BUF:   equ     DATA_END

;--- Bufer para el primer comando a enviar

SEND_COM_BUF:   equ     USER_COM_BUF+270

;--- Bufer para el nombre del servidor

SERVER_NAME:    equ     SEND_COM_BUF+270

;--- Bufer para la respuesta del servidor

RESPONSE_BUF:   equ     SERVER_NAME+257

;--- Bufer para examinar el comando del usuario

PARSE_BUF:      equ     RESPONSE_BUF+257

;--- Bufer para GET_DATA

GDATA_CBUF:     equ     PARSE_BUF+257
GDATA_DBUF:     equ     GDATA_CBUF+257

;--- Bufer para coger datos de la conexion de idem

DATA_BUF:       equ     GDATA_DBUF+257

;--- Buferes para el nombre de usuario y password por defecto

DEF_USER:       equ     DATA_BUF+1510
DEF_PASSWORD:   equ     DEF_USER+257
DEF_ACCOUNT:    equ     DEF_PASSWORD+257

;--- Espacio para la rutina HOOK

HOOK_CODE:      equ     DEF_ACCOUNT+257

        ;Donde colocaremos el gancho antiguo
        ;(justo despues del codigo nuevo)

HOOK_OLD:       equ     HOOK_CODE0_END-HOOK_CODE0+HOOK_CODE
ESC_CHAR:       equ     HOOK_OLD+5
