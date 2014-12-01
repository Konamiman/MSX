; RS232 module (Fossil)  for InterNestor Suite

;===========================

	;--- Modulo de acceso fisico (Fossil) para Internestor Suite
	;    Version 0.2
	;    VERSION RESIDENTE
	;    Necesita NestorMan 1.12 y el driver Fossil

	;- Quitada la rutina FOS_CHK_TLU: Ahora devuelve siempre ON
	;- Arreglada FOS_QUEUES

	.label	20

nesman:	macro	@f
	call	#4100+3*@f
	endm

nesmani:	macro	@f
	ld	c,@f
	ld	de,#2202
	call	#FFCA
	endm

ENASLT:	equ	#0024
EXPTBL:	equ	#FCC1


;***********************************
;***                             ***
;***   CABECERA IDENTIFICADORA   ***
;***                             ***
;***********************************

	;--- #0000: Texto identificador de 256 caracteres

	org	#100
HEADER:	db	"NestorFossilCaller 0.3",13,10
	db	"Requires the Erix' Fossil driver installed",13,10
	db	"A level 1 module for InterNestor Suite",13,10
	db	"By Konami Man, 7-2001",13,10
	db	#1A
HEAD_END:	;
	ds	256-(HEAD_END-HEADER)

	;--- #0100: Cadena identificadora de 32 caracteres

	db	"NestorFossilCaller 0.3          "

	;--- #0120: Identificador de modulo de InterNestor Suite

	db	"INESUITE"

	;--- #0128: Version

	db	0,3,0

	;--- #012B: Nivel del modulo

	db	1

	;--- Hasta #200: Reservado para futura expansion

	ds	#200-#012B-1



;**************************
;***                    ***
;***   TABLA DE SALTO   ***
;***                    ***
;**************************

	;#8000 contendra el slot de los modulos
	;#8001 contendra el propio slot fisico de este modulo
	;#8002 contendra el propio slot NestorMan de este modulo
	;(establecidos al instalar InterNestor)

	org	#8003

	;--- Rutinas obligatorias

	jp	FOS_RESET	;#8003: Reset
	jp	FOS_DEINIT	;#8006: Desinicializacion
	jp	FOS_INT	;#8009: Atencion a la interrupcion
	jp	FOS_QUEUES	;#800C: Direccion de la cola
	jp	FOS_CHK_TLU	;#800F: La capa esta disponible o no
	jp	FOS_OPEN	;#8012: Peticion de apertura de la capa
	jp	FOS_CLOSE	;#8015: Peticion de cierre de la capa

	jp	FOS_RDY_SEND	;#8018: Se pueden enviar datos
	jp	FOS_RDY_RCV	;#801B: Hay datos para recibir
	jp	FOS_BYTE_IN	;#801E: Lee un byte de entrada
	jp	FOS_BYTE_OUT	;#8021: Escribe un byte de salida

	;--- Rutinas especificas de NestorFossilCaller

	jp	FOS_TABLE	;#8024: Direcciones internas



;****************************************
;***                                  ***
;***   RUTINAS DE LA TABLA DE SALTO   ***
;***                                  ***
;****************************************

	;--- Reset
	;    Inicializa la cola de salida.
	;    Devuelve Cy=1 y HL=Puntero a una cadena de error
	;    si el fossil no esta presente, o no se puede crear la cola

FOS_RESET:	xor	a
	ld	(Fossil_OK),a
	call	GetFossil	;Obtiene las rutinas del Fossil
	jr	z,FOS_RES2

	scf
	ld	hl,NOFOS_S
	ret

NOFOS_S:	db	"Fossil driver not installed.",13,10,"$"

FOS_RES2:	ld	a,#FF
	ld	(Fossil_OK),a
	ld	a,(IN_QUEUE)	;Destruye la lista si ya existia
	or	a
	jr	z,FOS_RES3

	ld	ix,(IN_QUEUE+1)
	nesmani	22
	xor	a
	ld	(IN_QUEUE),a
	ld	(IN_QUEUE+1),a
	ld	(IN_QUEUE+2),a

FOS_RES3:	scf
	nesmani	20	;Crea lista nueva
	jr	nc,FOS_RES4

	scf
	ld	hl,NOMEM_S
	ret

NOMEM_S:	db	"Could note create queue - out of memory.",13,10,"$"

FOS_RES4:	ld	(IN_QUEUE),a
	ld	(IN_QUEUE+1),ix

	ld	de,#0402	;Obtiene rutinas del mapeador
	call	#FFCA
	ld	de,ALL_SEG
	ld	bc,#30
	ldir

	xor	a
	ld	hl,0
	ld	(PAQ_PEND),a
	ld	(PAQ_PNT),hl
	ld	(PAQ_CNT),hl
	ld	(DIAL_COMMAND),a
	ld	(HANG_COMMAND),a

	nesmani	32
	ld	a,b	;Obtiene seg de la capa superir
	nesmani	3
	ld	a,c
	ld	(UPPER_SEG),a

	ld	c,1	;Obtiene slot y seg de NestorMan
	ld	de,#2202
	call	#FFCA
	ld	a,b
	ld	(NMAN_SLOT),a
	ld	a,c
	ld	(NMAN_SEG),a

	ld	hl,IN_BUFER_DIR
	ld	(INBUF_INPNT),hl
	ld	(INBUF_OUTPNT),hl
	ld	hl,0
	ld	(INBUF_SIZE),hl

	call	F_Init	;Inicializa RS-232 y termina
	call	F_Flush_Buf
	or	a
	ret


	;--- Deinit
	;    Borra la lista y desinicializa el RS-232

FOS_DEINIT:	ld	a,(Fossil_OK)
	or	a
	jr	z,FOS_DEINIT2
	call	FOS_CLOSE
	call	F_DeInit
FOS_DEINIT2:	ld	a,(IN_QUEUE)
	or	a
	jr	z,FOS_DEINIT3
	ld	ix,(IN_QUEUE+1)
	nesmani	22
	xor	a
FOS_DEINIT3:	ld	(UPPER_SEG),a
	ld	(Fossil_OK),a
	ld	(IN_QUEUE),a
	ld	(IN_QUEUE+1),a
	ld	(IN_QUEUE+2),a
	ret


	;--- Queues
	;    Devuelve en A-HL la direccion de la cola segun A:
	;    0: Entrada desde el modulo superior
	;    Devuelve Cy=1 si A es incorrecto

FOS_QUEUES:	or	a
	scf
	ret	nz
	ld	a,(IN_QUEUE)
	ld	hl,(IN_QUEUE+1)
	or	a
	ret


	;--- Capa disponible
	;    Devuelve Cy=1 si el medio fisico esta disponible

FOS_CHK_TLU:	;call    F_Carrier
	;or      a
	;ret     z
	;scf
	;ret

	;in      a,(#82)
	;bit     0,a
	;scf
	;ret     z
	;ccf
	;ret

	scf
	ret

	;--- Listo para enviar
	;    Devuelve Cy=1 si el medio fisico esta disponible
	;    y el bufer no esta lleno

FOS_RDY_SEND:	call	FOS_CHK_TLU
	ret	nc

	call	F_Size_Of_Buf	;No se pueden enviar si bufer lleno
	push	hl
	call	F_Chars_In_Buf
	pop	de
	call	COMP
	ccf
	ret


	;--- Listo para recibir
	;    Devuelve Cy=1 si hay datos en el bufer

FOS_RDY_RCV:	ld	hl,(INBUF_SIZE)
	ld	a,h
	or	l
	ret	z
	scf
	ret


	;--- Entrada de un byte, lo devuelve en A

FOS_BYTE_IN:	ld	hl,(INBUF_SIZE)
	ld	a,h
	or	l
	ret	z
	dec	hl
	ld	(INBUF_SIZE),hl

	ld	hl,(INBUF_OUTPNT)
	ld	a,(hl)	;Lo saca del bufer circular
	push	af
	inc	hl
	ld	de,INBUF_MAXDIR
	call	COMP
	jr	nz,FOSBYTIN2
	ld	hl,IN_BUFER_DIR
FOSBYTIN2:	ld	(INBUF_OUTPNT),hl
	pop	af
	ret


	;--- Salida del byte A

FOS_BYTE_OUT:	jp	F_RS_Out


	;--- Peticion de apertura de la capa
	;    Ejecuta el comando almacenado en DIAL_COMMAND
	;    acabado en 0

FOS_OPEN:	ld	hl,DIAL_COMMAND
FOS_OPEN_L:	push	hl
	call	F_Flush_Buf
	pop	hl
	ld	a,(hl)
	or	a
	ret	z
	push	hl
	call	F_RS_Out
	pop	hl
	inc	hl
	jr	FOS_OPEN_L


	;--- Peticion de cierre de la capa
	;    Ejecuta el comando alamcenado en HANGUP_COMMAND
	;    acabado en 0

FOS_CLOSE:	ld	hl,HANG_COMMAND
	jr	FOS_OPEN_L


	;--- Direcciones de variables y tablas
	;    Devuelve en HL la tabla especificada por A:
	;    (y en BC su longitud)
	;    0: Variables
	;    Devuelve Cy=1 para comando desconocido

FOS_TABLE:	ld	hl,VAR_START
	ld	bc,VAR_END-VAR_START
	or	a
	ret	z
	ld	hl,HANG_COMMAND
	cp	1
	ret	z
	scf
	ret



;********************************************************
;***                                                  ***
;***  RUTINA DE ATENCION A LA INTERRUPCION DEL RELOJ  ***
;***                                                  ***
;********************************************************

FOS_INT:	;nesman  1                ;No hace nada si ya se estaba
	;jr      c,FOS_INT_END    ;ejecutando NestorMan

	;in      a,(#FC)
	;and     %00011111
	;cp      3
	;jp      nz,FOSSILEND

;--- Recoge todos los bytes de entrada disponibles y los mete en
;    un bufer circular propio

	call	F_Chars_In_Buf
	ld	a,h	;Hay realmente datos pendientes?
	or	l
	jr	z,GETIN_END
	push	hl

	ld	hl,(INBUF_SIZE)	;Bufer lleno?
	ld	de,INBUF_MAXSIZE
	call	COMP
	jr	z,GETIN_END

	pop	bc
GETIN_LOOP:	push	bc
	call	F_RS_In
	ld	hl,(INBUF_INPNT)
	ld	(hl),a
	inc	hl
	ld	de,INBUF_MAXDIR
	call	COMP
	jr	nz,NOSEPASA
	ld	hl,IN_BUFER_DIR
NOSEPASA:	ld	(INBUF_INPNT),hl
	ld	hl,(INBUF_SIZE)
	inc	hl
	ld	(INBUF_SIZE),hl

	pop	bc
	dec	bc
	ld	a,b
	or	c
	jr	nz,GETIN_LOOP
GETIN_END:	;


;--- Conexion del segmento de NestorMan y llamada a la int propia

	call	GETSLOT1	;Guarda el estado de la pagina 1
	push	af	;y la zona de trabajo
	call	GET_P1
	push	af
	;in      a,(#FC)
	;ld      (SAVEP1),a
	ld	hl,(#FCC5)
	ld	(WORK_BACKUP),hl
	ld	hl,(#FCC7)
	ld	(WORK_BACKUP+2),hl

	ld	a,(NMAN_SLOT)	;Conecta el slot de NestorMan
	ld	h,#40	;en la pagina 1
	call	ENASLT
	ei
	ld	a,(NMAN_SEG)
	call	PUT_P1

	call	_FOS_INT	;Llama a la de la interrupcion
	ld	a,(UPPER_SEG)	;propia, y despues a la del
	or	a	;modulo de nivel superior
	jr	z,FOS_INT_END

	ld	a,(UPPER_SEG)
	ld	iyh,a
	ld	ix,#8009
	call	CAL_SEG

FOS_INT_END:	pop	af	;Restaura estado y zona de trabajo,
	call	PUT_P1	;y termina
	pop	af
	ld	h,#40
	di
	call	ENASLT
	ld	hl,(WORK_BACKUP)
	ld	(#FCC5),hl
	ld	hl,(WORK_BACKUP+2)
	ld	(#FCC7),hl
	;ld      a,(SAVEP1)
	;out     (#FC),a
FOSSILEND:	ei
	ret


;*** Rutina principal de interrupcion
;Extrae un paquete de la cola y lo envia.
;Si deja de haber disponibilidad para enviar datos, el envio queda pendiente
;para la siguiente interrupcion.
;Si el medio fisico cae, borra los datos pendientes.

_FOS_INT:	call	FOS_CHK_TLU
	jr	c,FOS_INT1
	xor	a
	ld	hl,0
	ld	(PAQ_PEND),a	;Si no hay capa fisica disponible,
	ld	(PAQ_PNT),hl	;borra cualquier dato pendiente
	ld	(PAQ_CNT),hl
	ld	hl,IN_BUFER_DIR
	ld	(INBUF_INPNT),hl
	ld	(INBUF_OUTPNT),hl
	ld	hl,0
	ld	(INBUF_SIZE),hl
	ret

FOS_INT1:	ld	a,(PAQ_PEND)	;Paquete pendiente? Continua enviando
	ld	hl,(PAQ_PNT)
	ld	bc,(PAQ_CNT)
	or	a
	jr	nz,FRAMEO_LOOP

	ld	a,(#8002)
	ld	l,a
	ld	a,(IN_QUEUE)	;No hay paquete pendiente?
	ld	ix,(IN_QUEUE+1)	;Extrae uno, si hay, y lo elimina
	ld	b,1	;de la cola
	ld	h,3
	ld	iy,QUEUE_BUFER

	nesman	29
	ret	c
	ld	hl,QUEUE_BUFER
	ld	(PAQ_PNT),hl
	ld	(PAQ_CNT),bc
	ld	a,#FF
	ld	(PAQ_PEND),a

FRAMEO_LOOP:	push	bc,hl
	call	FOS_RDY_SEND
	pop	hl,bc
	jr	nc,FRAMEO_NORDY
	push	hl,bc
	ld	a,(hl)
	call	FOS_BYTE_OUT
	pop	bc,hl
	inc	hl
	dec	bc
	ld	a,b
	or	c
	jr	nz,FRAMEO_LOOP

	xor	a
	ld	(PAQ_PEND),a
	ret

FRAMEO_NORDY:	ld	(PAQ_PNT),hl	;Si no se pueden enviar datos,
	ld	(PAQ_CNT),bc	;los deja pendientes
	ld	a,#FF
	ld	(PAQ_PEND),a
	ret



;**************************
;***                    ***
;***   RUTINAS FOSSIL   ***
;***                    ***
;**************************

; RS232 recognize/caller routine
;
; (p) 1993,1994 Erik Maas
;
; made to use with GEN80 macro assembler from HiSoft's DevPack80 v2.03

; To use this library, first you have to call GetFossil, this routine will
; check whether the fossil is available or not, if it is available, then it
; will adjust the jump table, so you can use this table.
; The return flags of GetFossil can tell you whether the fossil was found or
; not. Z  means the Fossil was found and installed
;      NZ means the Fossil was not found, and therefore NOT installed
;         (so be wise, return to DOS or whatever, do not use the routines)

; The fossil has it marks at the cassette parameter table, I do not believe
; any MSX 2 or turbo-R will use it anymore.... (??????)

; F3FC: "R"     mark 1
; F3FD: "S"     mark 2
; F3FE: LSB     LSB of addres to jump table of fossil driver
; F3FF: MSB     MSB of addres to jump table of fossil driver

GetFossil	ld	a,(#f3fc)	; get first mark of fossil
	cp	"R"	; is it the right one?
	ret	nz	; return if not with NZ flags
	ld	a,(#f3fd)	; get second mark of fossil
	cp	"S"	; is it the right one?
	ret	nz	; return if not with NZ flags

	; now we know the Fossil is installed, just get the addres
	; of the jump table now, and connect it to the program

	ld	hl,(#f3fe)	; get addres of jump table
	ld	de,F_GetVersion	; point to my own table
	ld	bc,21*3	; number of entry's at this moment
	ldir		; make a copy of the table
	call	F_GetVersion
	xor	a	; set Z flags
	ret		; and return to caller

;
; Jump Table to use in ML
;
; This table will be filled in by the GetFossil routine, after that you can
; simply call these addresses in the table
;

F_GetVersion	jp	0	; 0
F_Init	jp	0	; 1
F_DeInit	jp	0	; 2
F_SetBaud	jp	0	; 3
F_Protocol	jp	0	; 4
F_Channel	jp	0	; 5
F_RS_In	jp	0	; 6
F_RS_Out	jp	0	; 7
F_RS_In_Stat	jp	0	; 8
F_RS_Out_Stat	jp	0	; 9
F_DTR	jp	0	; 10
F_RTS	jp	0	; 11
F_Carrier	jp	0	; 12
F_Chars_In_Buf	jp	0	; 13
F_Size_Of_Buf	jp	0	; 14
F_Flush_Buf	jp	0	; 15
F_Fastint	jp	0	; 16
F_Hook38Stat	jp	0	; 17
F_Chput_Hook	jp	0	; 18
F_Keyb_Hook	jp	0	; 19
F_Get_Info	jp	0	; 20



;******************************
;***                        ***
;***   RUTINAS AUXILIARES   ***
;***                        ***
;******************************

;--- Rutinas de acceso al mapeador

ALL_SEG:	ds	3
FRE_SEG:	ds	3
RD_SEG:	ds	3
WR_SEG:	ds	3
CAL_SEG:	ds	3
CALLS:	ds	3
PUT_PH:	ds	3
GET_PH:	ds	3
PUT_P0:	ds	3
GET_P0:	ds	3
PUT_P1:	ds	3
GET_P1:	ds	3
PUT_P2:	ds	3
GET_P2:	ds	3
PUT_P3:	ds	3
GET_P3:	ds	3

;--- NOMBRE: COMP
;      Comparacion de HL con DE (16 bits en complemento a 2)
;    ENTRADA:   HL, DE = numeros a comparar
;    SALIDA:     C, NZ si HL > DE
;                C,  Z si HL = DE
;               NC, NZ si HL < DE
;    REGISTROS: -
;    VARIABLES: -
;    LLAMADAS:  -

COMP:	call	_COMP16
	ccf
	ret

_COMP16:	ld	a,h
	sub	d
	ret	nz
	ld	a,l
	sub	e
	ret


;--- Rutina para obtener el slot conectado en pagina 1
;    sin usar EXPTBL para obtener el subslot

GETSLOT1:	di
	exx
	in	a,(#A8)
	ld	(SAVEA8),a
	ld	e,a
	and	%00001100
	sra	a
	sra	a
	ld	c,a	;C = Slot
	ld	b,0
	ld	hl,EXPTBL	;Esta expandido?
	add	hl,bc
	bit	7,(hl)
	jr	z,NOEXP1

	;ld      a,c
	rrca
	rrca
	and	%11000000
	ld	b,a
	ld	a,(SAVEA8)
	and	%00111111
	or	b
	out	(#A8),a	;Conecta slot en pag. 3
	ld	a,(-1)
	cpl
	and	%00001100
	or	c
	or	#80

	ld	(SAVEREGA),a	;Restaura slot en pag. 3
	ld	a,(SAVEA8)
	out	(#A8),a
	ld	a,(SAVEREGA)
	ld	c,a

NOEXP1:	ld	a,c
	exx
	ei
	ret

SAVEA8:	db	0
SAVEREGA:	db	0


;*********************
;***               ***
;***   VARIABLES   ***
;***               ***
;*********************

IN_QUEUE:	ds	3

VAR_START:	;

PAQ_PEND:	db	0	;#FF si hay paq. pendiente
PAQ_PNT:	dw	0	;Puntero al paquete
PAQ_CNT:	dw	0	;Bytes pendientes de enviar
UPPER_SEG:	db	0	;Segmento de nivel 2
Fossil_OK:	db	0	;#FF si Fossil esta inicializado
NMAN_SEG:	db	0	;Segmento de NestorMan
NMAN_SLOT:	db	0	;Slot de NestorMan
WORK_BACKUP:	ds	4
SAVEP1:	db	0
INBUF_INPNT:	dw	IN_BUFER_DIR
INBUF_OUTPNT:	dw	IN_BUFER_DIR
INBUF_SIZE:	dw	0

DIAL_COMMAND:	;
HANG_COMMAND:	equ	DIAL_COMMAND+257

VAR_END:	equ	HANG_COMMAND+257

QUEUE_BUFER:	equ	HANG_COMMAND+257

IN_BUFER_DIR:	equ	QUEUE_BUFER+257
INBUF_MAXSIZE:	equ	#BFFF-IN_BUFER_DIR
INBUF_MAXDIR:	equ	IN_BUFER_DIR+INBUF_MAXSIZE

