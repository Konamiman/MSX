;NestorCartridge #1
;A ROM tool that provides miscellaneous utilities
;via custom CALL commands.

;=============================

;NESTORCARTRIDGE#1
;  Este programa esta pensado para instalarse en un cartucho ROM,
;de #4000 a #7FFF, con autoejecucion.
;  Para usarlo desde RAM simulando ROM:
;- Ensamblarlo en #4000
;- Copiar #4000-#7FFF a #8000
;- Grabar de #8000 a #BFFF en formato binario, con arranque en #84F0
;- Desde BASIC hacer:
;  BLOAD "cartucho.bin"
;  DEFUSR=&H8500:?USR(Slot+4*Subslot) => Slot de la RAM
;  o bien BLOAD"cartucho.bin",R, entonces toma el slot 3-2
;- El ordenador hara reset y el programa se inicializara.
;- Es recomendable usar una ampliacion de memoria externa, y entonces
;  instalar el programa en el slot de memoria interna:
;  de este modo la simulacion de ROM es casi perfecta
;  (puedes cargar Turbo-BASIC y DOS 1/2 sin problemas.
;   Ojo con los programas de DOS 2 que accedan a la memoria mapeada)

PROCNM:	EQU	#FD89	;Almacen del comando CALL ejecutado
SLTATR:	EQU	#FCC9	;Tabla de atributos de los slots
EXPTBL:	EQU	#FCC1	;Tabla de expansion de los slots
SLTTBL:	EQU	#FCC5	;Copia del registro selector de subslots
CGTABL:	EQU	#4	;Direccion del gen. de caracteres (ROM)
CGPNT:	EQU	#F91F	;Puntero al generador de caracteres (ROM)
CGPBAS:	EQU	#F924	;Actual dir. gen. de caracteres (VRAM)
LDIRMV:	EQU	#5C	;Copia de memoria a VRAM
NEWKEY:	EQU	#FBE5	;Almacena el estado de cada tecla
INITXT:	EQU	#6C	;Inicializa SCREEN 0
LINL40:	EQU	#F3AE	;Columnas en pantalla (inicial)
LINLEN:	EQU	#F3B0	;Columnas en pantalla (actual)
INIFNK:	EQU	#3E	;Inicializa teclas de funcion
CHPUT:	EQU	#A2	;Imprime un caracter en pantalla
MSXVER:	EQU	#2D	;Version MSX
CHGCPU:	EQU	#180	;Cambia procesador (Turbo-R)
GETCPU:	EQU	#183	;Obtiene CPU actual (Turbo-R)
RDVRAM:	EQU	#4A	;Lee de VRAM
WRTVRAM:	EQU	#4D	;Escribe en VRAM
BEEP:	EQU	#C0	;Genera un fabuloso BEEP
CHSNS:	EQU	#9C	;Comprueba si se ha pulsado tecla
NAMBAS:	EQU	#F922	;Actual base tabla de nombres (VRAM)
SCRMOD:	EQU	#FCAF	;Modo grafico actual
CSRY:	EQU	#F3DC	;Posicion Y del cursor
KILBUF:	EQU	#156	;Borra buffer de teclado
ENASCR:	EQU	#44	;Conecta pantalla
DISASCR:	EQU	#41	;Desconecta pantalla
RESET:	EQU	#0	;Adivina...
FNKSTR:	EQU	#F87F	;Contenido de las teclas de funcion
ENASLT:	EQU	#24	;Conecta slot
RDSLT:	EQU	#C	;Lee de un slot
CALSLT:	EQU	#1C	;Llama a una subrutina en un slot
RSLREG:	EQU	#138	;Lee el selector de slots primario
SLTWRK:	EQU	#FD09	;Zona de trabajo de los slots
HOKVLD:	EQU	#FB20	;Bandera de BIOS extendida
EXTBIO:	EQU	#FFCA	;Gancho a la BIOS extendida
CHGET:	EQU	#FDC2

aConAc:	EQU	160	;Caracteres acentuados
eConAc:	EQU	130
iConAc:	EQU	161
oConAc:	EQU	162
uConAc:	EQU	163
egneMin:	EQU	164
egneMay:	EQU	165
AbEx:	EQU	173
AbInt:	EQU	168

	ORG	#4000
ROMHead:	DB	#41,#42
StartHead:	DW	Start
CallHead:	DW	Call
DevHead:	DW	0
BasicHead:	DW	0
BlankSpace:	DS	6

IdString:	DB	"NESTOR#1.0",0,0,0,0,0,0
J4020:	JP	SetOriChar
J4023:	JP	SetEuroChar
J4026:	JP	SetMbChar
J4029:	JP	SetJapChar
J402C:	JP	SetFutChar
J402F:	JP	Set50Hz
J4032:	JP	Set60Hz
J4035:	JP	InitFnk
J4038:	JP	SetZ80
J403B:	JP	SetR8ROM
J403E:	JP	SetR8DRAM
J4041:	JP	FreeDRAM

Start:	PUSH	AF,BC,DE,HL
	LD	A,40	;SCREEN 0, 40 columnas
	LD	(LINL40),A
	CALL	INITXT
	CALL	Set60Hz

ChkForKey:	LD	A,(NEWKEY+3)	;Comprueba si se ha pulsado la "H"
	AND	%00100000
	CALL	Z,Set50Hz
	LD	A,(NEWKEY+3)	;Comprueba si se ha pulsado la "J"
	AND	%10000000
	JP	Z,StartJap
	LD	A,(NEWKEY+4)	;Comprueba si se ha pulsado la "M"
	AND	%00000100
	JP	Z,StartMb
	LD	A,(NEWKEY+3)	;Comprueba si se ha pulsado la "F"
	AND	%00001000
	JP	Z,StartFut
	LD	A,(NEWKEY+4)	;Comprueba si se ha pulsado la "O"
	AND	%00010000
	JP	Z,StartOri

StartEur:	CALL	SetEuroChar	;Arranque con juego europeo
	LD	DE,StEurMsg
	CALL	Print
	JP	ShowCallNst

StartMb:	CALL	SetMbChar	;Arranque con juego MoonBlaster
	LD	DE,StMbMsg
	CALL	Print
	JP	ShowCallNst

StartJap:	CALL	SetJapChar	;Arranque con juego japones
	LD	DE,StJapMsg
	CALL	Print
	JP	ShowCallNst

StartFut:	CALL	SetFutChar	;Arranque con juego futurista
	LD	DE,StFutMsg
	CALL	Print
	JP	ShowCallNst

StartOri:	LD	DE,StOriMsg	;Arranque con juego original
	CALL	Print

ShowCallNst:	LD	DE,CallNstMsg
	CALL	Print

IniSltWrk:	CALL	GetSltWrk	;(SLTWRK de este slot)=0 si FREEDRAM
	XOR	A	;aun no ha sido llamado, 1 en caso
	LD	(HL),A	;contrario

	LD	BC,0
Waitea:	DEC	BC	;Bucle de espera
	LD	A,B	;para que de tiempo a leer
	OR	C	;el mensaje
	JR	NZ,Waitea
	CALL	InitFnk
	POP	HL,DE,BC,AF

	RET		;Fin del arranque

Print:	LD	A,(DE)	;Rutina de impresion de una cadena
	CP	"$"	;(la funcion 9 del DOS no funciona aun)
	RET	Z
	CALL	CHPUT
	INC	DE
	JR	Print

EntyFin:	MACRO
	DB	13,10,10,"$"
	ENDM

StEurMsg:	DB	"Juego de car",aConAc,"cteres europeo OK ..."
	EntyFin
StMbMsg:	DB	"Juego de car",aConAc,"cteres MoonBlaster OK ..."
	EntyFin
StJapMsg:	DB	"Juego de car",aConAc,"cteres japon",eConAc,"s OK ..."
	EntyFin
StOriMsg:	DB	"Juego de car",aConAc,"cteres original OK ..."
	EntyFin
StFutMsg:	DB	"Juego de car",aConAc,"cteres futurista OK ..."
	EntyFin
CallNstMsg:	DB	"CALL NESTOR para m",aConAc,"s info."
	EntyFin

InWhichSlot:	PUSH	HL,BC
	CALL	RSLREG	;Devuelve en A el slot activo en
	AND	%00001100	;la pagina 1
	RRCA
	RRCA
	LD	HL,EXPTBL
	LD	C,A
	LD	B,0
	ADD	HL,BC
	BIT	7,(HL)
	JR	Z,NoExp
	INC	HL
	INC	HL
	INC	HL
	INC	HL
	LD	A,(HL)
	AND	%00001100
	OR	%10000000
	OR	C
NoExp:	POP	BC,HL
	RET

Call:	PUSH	AF,BC,DE,HL
	LD	DE,Comandos	;Proceso de comandos CALL
ReBegin:	LD	HL,PROCNM
Compara:	LD	A,(DE)
	CP	"$"
	JP	Z,NoneFound
	CP	(HL)
	JR	NZ,BuscaOtro
	OR	A
	JR	Z,ComFound
	INC	HL
	INC	DE
	JR	Compara
BuscaOtro:	LD	A,(DE)
	OR	A
	JR	Z,PasaAlSig
	INC	DE
	JR	BuscaOtro
PasaAlSig:	INC	DE
	INC	DE
	INC	DE
	JR	ReBegin
ComFound:	INC	DE
	LD	A,(DE)
	LD	L,A
	INC	DE
	LD	A,(DE)
	LD	H,A
	LD	DE,CallRet
	PUSH	DE
	JP	(HL)
NoneFound:	POP	HL,DE,BC,AF
	SCF
	RET

Comandos:	DB	"EUROCHAR",0	;Formato: comando + #00 + direccion
	DW	SetEuroChar	;La lista termina con un caracter "$"
	DB	"JAPCHAR",0
	DW	SetJapChar
	DB	"ORICHAR",0
	DW	SetOriChar
	DB	"MBCHAR",0
	DW	SetMbChar
	DB	"FUTCHAR",0
	DW	SetFutChar
	DB	"INIFNK",0
	DW	InitFnk
	DB	"60HZ",0
	DW	Set60Hz
	DB	"50HZ",0
	DW	Set50Hz
	DB	"Z80",0
	DW	SetZ80
	DB	"SLOW",0
	DW	SetZ80
	DB	"R800ROM",0
	DW	SetR8ROM
	DB	"R800",0
	DW	SetR8ROM
	DB	"MEDIUM",0
	DW	SetR8ROM
	DB	"R800DRAM",0
	DW	SetR8DRAM
	DB	"FAST",0
	DW	SetR8DRAM
	DB	"FREEDRAM",0
	DW	FreeDRAM
	DB	"RESET",0
	DW	RESET
	DB	"ENASCR",0
	DW	ENASCR
	DB	"DISASCR",0
	DW	DISASCR
	DB	"NESTOR",0
	DW	Nestor
	DB	"$",0,0

SetEuroChar:	LD	DE,EuroStart
	JP	SetChar
SetMbChar:	LD	DE,MbStart
	JP	SetChar
SetJapChar:	LD	DE,JapStart
	JP	SetChar
SetFutChar:	LD	DE,FutStart
	JP	SetChar

SetChar:	CALL	InWhichSlot	;Establece juego de caracteres
	LD	HL,CGPNT	;almacenado a partir de DE
	LD	(HL),A
	INC	HL
	LD	(HL),E
	INC	HL
	LD	(HL),D
	EX	DE,HL
	LD	DE,(CGPBAS)
	LD	BC,2048
	JP	LDIRMV

SetOriChar:	LD	HL,CGPNT	;Establece juego de caracteres original
	LD	A,(EXPTBL)
	LD	(HL),A
	INC	HL
	LD	A,(CGTABL)
	LD	(HL),A
	INC	HL
	LD	A,(CGTABL+1)
	LD	(HL),A
	LD	HL,(CGTABL)
	LD	DE,(CGPBAS)
	LD	BC,2048
	JP	LDIRMV

InitFnk:	CALL	INIFNK	;Inicailiza teclas de funcion
	LD	HL,LoadStr	;F7=load"
	LD	DE,FNKSTR+16*6
	LD	BC,16
	LDIR
	RET
LoadStr:	DB	"load",34
	DS	11

Set60Hz:	LD	A,(#FFE8)
	AND	%11111101
	LD	(#FFE8),A
	OUT	(#99),A
	LD	A,#89
	OUT	(#99),A
	RET

Set50Hz:	LD	A,(#FFE8)
	OR	%00000010
	LD	(#FFE8),A
	OUT	(#99),A
	LD	A,#89
	OUT	(#99),A
	RET

SetZ80:	LD	A,(MSXVER)
	CP	3
	JP	C,BEEP
	LD	A,%10000000
	JP	CHGCPU

SetR8ROM:	LD	A,(MSXVER)
	CP	3
	JP	C,BEEP
	LD	A,%10000001
	JP	CHGCPU

SetR8DRAM:	LD	A,(MSXVER)
	CP	3
	JP	C,BEEP
	CALL	GetSltWrk	;No activa R800DRAM si los segmentos
	LD	A,(HL)	;DRAM copia de las ROMS
	OR	A	;han sido liberados
	JP	NZ,BEEP
	LD	A,%10000010
	JP	CHGCPU

FreeDRAM:	LD	A,(MSXVER)
	CP	3
	JP	C,BEEP
	CALL	GETCPU	;Si esta en Z80 lo deja
	OR	A	;si no activa R800ROM
	CALL	NZ,SetR8ROM
	CALL	GetSltWrk
	LD	A,(HL)
	OR	A
	JP	NZ,BEEP
GetFreAddr:	LD	A,(HOKVLD)
	RRCA
	JP	NC,BEEP	;Error si no hay BIOS extendida
	LD	DE,#0402
	XOR	A
	CALL	EXTBIO
	OR	A
	JP	Z,BEEP	;Error si no hay rutinas de soporte
	INC	HL	;del mapeador
	INC	HL
	INC	HL
	INC	HL
	LD	E,(HL)
	INC	HL
	LD	D,(HL)
	PUSH	DE
SetSegNum:	LD	DE,#0401	;Obtiene inicio tabla de variables
	CALL	EXTBIO
	INC	HL
	LD	A,(HL)	;A=Numero de segmentos en mapeador activo
	DEC	A	;Apuntamos al ultimo segmento
	LD	B,4
	POP	IX	;IX=Direccion de la rutina FRE_SEG
Libera:	PUSH	AF,BC
	LD	B,0
CallFre:	LD	DE,Continua
	PUSH	DE
	JP	(IX)
Continua:	JR	C,Error
	POP	BC,AF
	DEC	A
	DJNZ	Libera
Exit:	CALL	GetSltWrk	;Actualiza (SLTWRK): ya no funcionaran
	LD	A,1	;R800DRAM ni FREEDRAM
	LD	(HL),A
	RET
Error:	CALL	GetSltWrk	;Si no se pueden liberar las paginas
	LD	A,1	;se supone que ya han sido liberadas
	LD	(HL),A	;antes, y se actualiza (SLTWRK)
	POP	BC,AF
	JP	BEEP

GetSltWrk:	LD	HL,SLTWRK	;Devuelve HL=Direccion de SLTWRK
	CALL	InWhichSlot	;para el slot de NC#1, pagina 1
	LD	D,A	;Modifica BC y DE
	AND	%00000011
	SLA	A
	SLA	A
	SLA	A
	SLA	A
	SLA	A
	LD	B,0
	LD	C,A
	ADD	HL,BC
	LD	A,D
	AND	%00001100
	SLA	A
	LD	C,A
	ADD	HL,BC
	INC	HL
	INC	HL
	RET

Nestor:	LD	A,(SCRMOD)	;Comprueba si estamos en SC0
	OR	A
	JP	NZ,BEEP
Save:	LD	BC,(CSRY)	;Guarda anchura de pantalla,
	PUSH	BC	;posicion del cursor
	LD	HL,(NAMBAS)	;y la propia pantalla
	LD	DE,#3500
	LD	BC,80*24
SavLoop:	CALL	RDVRAM
	EX	DE,HL
	CALL	WRTVRAM
	EX	DE,HL
	INC	DE
	INC	HL
	DEC	BC
	LD	A,B
	OR	C
	JR	NZ,SavLoop
SetW80:	LD	A,(LINLEN)	;80 columnas
	PUSH	AF
	LD	A,80
	LD	(LINL40),A
	CALL	INITXT
	CALL	KILBUF
ShowPag1:	LD	HL,HelPage1	;Primera pgina de ayuda
	LD	DE,(NAMBAS)
	LD	BC,80*24
	CALL	LDIRMV
Guait1:	CALL	CHSNS	;Pulsa 1 tecla...
	JR	Z,Guait1
	CALL	KILBUF
ShowPag2:	LD	HL,HelPage2	;Segunda pagina de ayuda
	LD	DE,(NAMBAS)
	LD	BC,80*24
	CALL	LDIRMV
Guait2:	CALL	CHSNS	;Pulsa 1 tecla...
	JR	Z,Guait2
	CALL	KILBUF
ShowPag3:	LD	HL,HelPage3	;Tercera pgina de ayuda
	LD	DE,(NAMBAS)
	LD	BC,80*24
	CALL	LDIRMV
Guait3:	CALL	CHSNS	;Pulsa 1 tecla...
	JR	Z,Guait3
	CALL	KILBUF
Restaura:	POP	AF	;Restaura pantalla, anchura y cursor
	LD	(LINL40),A
	CALL	INITXT
	LD	DE,(NAMBAS)
	LD	HL,#3500
	LD	BC,80*24
RestLoop:	CALL	RDVRAM
	EX	DE,HL
	CALL	WRTVRAM
	EX	DE,HL
	INC	DE
	INC	HL
	DEC	BC
	LD	A,B
	OR	C
	JR	NZ,RestLoop
	POP	BC
	LD	(CSRY),BC
	RET

RDVRAM2:	LD	A,0
	RLA
	RLC	H
	RLA
	RLC	H
	RLA
	OUT	(#99),A
	LD	A,14OR128
	OUT	(#99),A
	LD	A,L
	OUT	(#99),A
	RRC	H
	RRC	H
	LD	A,H
	AND	%00111111
	OR	%10000000
	OUT	(#99),A
	IN	A,(#98)
	RET

WRTVRAM2:	PUSH	AF
	LD	A,0
	RLA
	RLC	H
	RLA
	RLC	H
	RLA
	OUT	(#99),A
	LD	A,14OR128
	OUT	(#99),A
	LD	A,L
	OUT	(#99),A
	RRC	H
	RRC	H
	LD	A,H
	AND	%00111111
	OUT	(#99),A
	POP	AF
	OUT	(#98),A
	RET

CallRet:	POP	HL,DE,BC,AF
	OR	A
	RET

              ORG     #44F0
ComaErre:	LD	A,%10001011	;BLOAD"CARTUCHO.BIN",R
	JR	CopyData	;instala NC#1 en slot 3-2 y resetea
	ORG	#4500
FromUSR:	INC	HL	;o bien
	INC	HL	;BLOAD"CARTUCHO.BIN"
	LD	A,(HL)	;DEFUSR=&H8500
	AND	%00001111
	LD	D,A
	AND	%00000011	;?USR(Slot+4*Subslot)
	LD	HL,EXPTBL
	LD	C,A
	LD	B,0
	ADD	HL,BC
	BIT	7,(HL)
	LD	A,D
	JR	Z,CopyData
	OR	%10000000
CopyData:	LD	H,#40
	DI
	CALL	ENASLT
	LD	HL,#8000
	LD	DE,#4000
	LD	BC,#4000
	LDIR
	JP	0

HelPage1:	;
TxtLin0:	DB	"                 ***** NESTORCARTRIDGE #"
	DB	"1.0 - Mayo 1.995 *****                  "
TxtLin1:	DB	"                                        "
	DB	"                                        "
TxtLin2:	DB	"1. ARRANQUE                             "
	DB	"                                        "
TxtLin3:	DB	"                                        "
	DB	"                                        "
TxtLin4:	DB	"   Al inicializar el ordenador, NestorCa"
	DB	"rtridge#1 establece por defecto la      "
TxtLin5:	DB	"siguiente configuraci",oConAc,"n:                "
	DB	"                                        "
TxtLin6:	DB	"                                        "
	DB	"                                        "
TxtLin7:	DB	"   * Juego de car",aConAc,"cteres europeo        "
	DB	"                                        "
TxtLin8:	DB	"   * Frecuencia de pantalla 60 Hz       "
	DB	"                                        "
TxtLin9:	DB	"                                        "
	DB	"                                        "
TxtLin10:	DB	"   Es posible arrancar con otra configur"
	DB	"aci",oConAc,"n pulsando:                         "
TxtLin11:	DB	"                                        "
	DB	"                                        "
TxtLin12:	DB	"   'O' --> Carga el juego original del o"
	DB	"rdenador                                "
TxtLin13:	DB	"   'M' --> Carga el juego de car",aConAc,"cteres "
	DB	"MoonBlaster                             "
TxtLin14:	DB	"   'J' --> Carga el juego de car",aConAc,"cteres "
	DB	"japon",eConAc,"s                                 "
TxtLin15:	DB	"   'F' --> Carga el juego de car",aConAc,"cteres "
	DB	"futurista                               "
TxtLin16:	DB	"                                        "
	DB	"                                        "
TxtLin17:	DB	"   'H' --> Arranca con 50 Hz            "
	DB	"                                        "
TxtLin18:	DB	"                                        "
	DB	"                                        "
TxtLin19:	DB	"                                        "
	DB	"                                        "
TxtLin20:	DB	"                                        "
	DB	"                                        "
TxtLin21:	DB	"                           --- PULSA UNA"
	DB	" TECLA ---                              "
TxtLin22:	DB	"                                        "
	DB	"                                        "
TxtLin23:	DB	"                                        "
	DB	"                                        "

HelPage2:	;
Txt2Lin0:	DB	"2. COMANDOS EXTENDIDOS (CALLs)          "
	DB	"                                        "
Txt2Lin1:	DB	"                                        "
	DB	"                                        "
Txt2Lin2:	DB	"   CALL ORICHAR  --> Establece el juego "
	DB	"original de la m",aConAc,"quina                  "
Txt2Lin3:	DB	"   CALL EUROCHAR --> Establece el juego "
	DB	"de car",aConAc,"cteres europeo                   "
Txt2Lin4:	DB	"   CALL MBCHAR   --> Establece el juego "
	DB	"de car",aConAc,"cteres MoonBlaster               "
Txt2Lin5:	DB	"   CALL JAPCHAR  --> Establece el juego "
	DB	"de car",aConAc,"cteres japon",eConAc,"s         "
	DS	10," "
Txt2Lin6:	DB	"   CALL FUTCHAR  --> Establece el juego "
	DB	"de car",aConAc,"cteres futurista                 "
Txt2Lin7:	DB	"                                        "
	DB	"                                        "
Txt2Lin8:	DB	"   CALL 50HZ     --> Cambian la frecuenc"
	DB	"ia de barrido en pantalla               "
Txt2Lin9:	DB	"   CALL 60HZ                            "
	DB	"                                        "
Txt2Lin10:	DB	"                                        "
	DB	"                                        "
Txt2Lin11:	DB	"   CALL Z80      (o CALL SLOW)   --> Cam"
	DB	"bian el procesador del Turbo-R          "
Txt2Lin12:	DB	"   CALL R800ROM  (o CALL MEDIUM)     El "
	DB	"modo DRAM no puede volver a conectarse  "
Txt2Lin13:	DB	"   CALL R800DRAM (o CALL FAST)       si "
	DB	"se ha ejecutado FREEDRAM                "
Txt2Lin14:	DB	"   CALL FREEDRAM --> Desconecta el modo "
	DB	"R800DRAM y libera las 64K de RAM usadas "
Txt2Lin15:	DB	"                     para guardar las co"
	DB	"pias de las ROMs                        "
Txt2Lin16:	DB	"                                        "
	DB	"                                        "
Txt2Lin17:	DB	"   CALL INIFNK   --> Inicializa las tecl"
	DB	"as de funci",oConAc,"n                           "
Txt2Lin18:	DB	"   CALL DISASCR  --> Desconecta la visua"
	DB	"lizaci",oConAc,"n de la pantalla                 "
Txt2Lin19:	DB	"   CALL ENASCR   --> Conecta la visualiz"
	DB	"aci",oConAc,"n de la pantalla                    "
Txt2Lin20:	DB	"   CALL RESET    --> ",AbEx,"Usalo con cuidado!"
	DB	"                                        "
Txt2Lin21:	DB	"   CALL NESTOR   --> Presenta este texto"
	DB	" (s",oConAc,"lo en SCREEN 0)                     "
Txt2Lin22:	DB	"                                        "
	DB	"                                        "
Txt2Lin23:	DB	"                       --- PULSA UNA TEC"
	DB	"LA ---                                  "

HelPage3:	;
Txt3Lin0:	DB	"3. USO DESDE CODIGO MAQUINA             "
	DB	"                                        "
Txt3Lin1:	DB	"                                        "
	DB	"                                        "
Txt3Lin2:	DB	"   Es posible usar las rutinas implement"
	DB	"adas en NestorCartridge#1 desde C.M.    "
Txt3Lin3:	DB	"usando sin m",aConAc,"s la rutina CALSLT de la BI"
	DB	"OS (que ha de estar activa en p",aConAc,"g. 0):  "
Txt3Lin4:	DB	"                                        "
	DB	"                                        "
Txt3Lin5:	DB	"   LD IY,SLOT                           "
	DB	"                                        "
Txt3Lin6:	DB	"   LD IX,DIRECCION                      "
	DB	"                                        "
Txt3Lin7:	DB	"   CALL CALSLT (&H001C)                 "
	DB	"                                        "
Txt3Lin8:	DB	"                                        "
	DB	"                                        "
Txt3Lin9:	DB	"   Para averiguar en qu",eConAc," slot est",aConAc
	DB	" NestorCartridge#1 hay que buscar la cadena   "
Txt3Lin10:	DB	"                                        "
	DB	"                                        "
Txt3Lin11:	DB	"   NESTOR#1.0                           "
	DB	"                                        "
Txt3Lin12:	DB	"                                        "
	DB	"                                        "
Txt3Lin13:	DB	"   en todos los slots, a partir de la di"
	DB	"recci",oConAc,"n &H4010. Las rutinas est",aConAc,"n en:"
              DS      3," "
Txt3Lin14:	DB	"                                        "
	DB	"                                        "
Txt3Lin15:	DB	"   &H4020 --> ORICHAR      &H402F --> 50"
	DB	"HZ      &H4038 --> Z80                  "
Txt3Lin16:	DB	"   &H4023 --> EUROCHAR     &H4032 --> 60"
	DB	"HZ      &H403B --> R800ROM              "
Txt3Lin17:	DB	"   &H4026 --> MBCHAR       &H4035 --> IN"
	DB	"IFNK    &H403E --> R800DRAM             "
Txt3Lin18:	DB	"   &H4029 --> JAPCHAR                   "
	DB	"        &H4041 --> FREEDRAM             "
Txt3Lin19:	DB	"   &H402C --> FUTCHAR                   "
	DB	"                                        "
Txt3Lin20:	DB	"                                        "
	DB	"                                        "
Txt3Lin21:	DB	"   DISASCR, ENASCR y RESET se pueden lla"
	DB	"mar directamente a la BIOS.             "
Txt3Lin22:	DB	"                                        "
	DB	"                                        "
Txt3Lin23:	DB	"                       ----- PULSA UNA T"
	DB	"ECLA -----                              "

	ORG	#6000
FutStart:	;
FutChr0:	DB	#00,#00,#00,#00,#00,#00,#00,#00
FutChr1:	DB	#3C,#42,#A5,#81,#A5,#99,#42,#3C
FutChr2:	DB	#3C,#7E,#DB,#FF,#FF,#DB,#66,#3C
FutChr3:	DB	#6C,#FE,#FE,#FE,#7C,#38,#10,#00
FutChr4:	DB	#10,#38,#7C,#FE,#7C,#38,#10,#00
FutChr5:	DB	#10,#38,#54,#FE,#54,#10,#38,#00
FutChr6:	DB	#10,#38,#7C,#FE,#FE,#10,#38,#00
FutChr7:	DB	#00,#00,#00,#30,#30,#00,#00,#00
FutChr8:	DB	#FF,#FF,#FF,#E7,#E7,#FF,#FF,#FF
FutChr9:	DB	#38,#44,#82,#82,#82,#44,#38,#00
FutChr10:	DB	#C7,#BB,#7D,#7D,#7D,#BB,#C7,#FF
FutChr11:	DB	#0F,#03,#05,#79,#88,#88,#88,#70
FutChr12:	DB	#38,#44,#44,#44,#38,#10,#7C,#10
FutChr13:	DB	#30,#28,#24,#24,#28,#20,#E0,#C0
FutChr14:	DB	#3C,#24,#3C,#24,#24,#E4,#DC,#18
FutChr15:	DB	#10,#54,#38,#EE,#38,#54,#10,#00
FutChr16:	DB	#10,#10,#10,#7C,#10,#10,#10,#10
FutChr17:	DB	#10,#10,#10,#FF,#00,#00,#00,#00
FutChr18:	DB	#00,#00,#00,#FF,#10,#10,#10,#10
FutChr19:	DB	#10,#10,#10,#F0,#10,#10,#10,#10
FutChr20:	DB	#10,#10,#10,#1F,#10,#10,#10,#10
FutChr21:	DB	#10,#10,#10,#FF,#10,#10,#10,#10
FutChr22:	DB	#10,#10,#10,#10,#10,#10,#10,#10
FutChr23:	DB	#00,#00,#00,#FF,#00,#00,#00,#00
FutChr24:	DB	#00,#00,#00,#1F,#10,#10,#10,#10
FutChr25:	DB	#00,#00,#00,#F0,#10,#10,#10,#10
FutChr26:	DB	#10,#10,#10,#1F,#00,#00,#00,#00
FutChr27:	DB	#10,#10,#10,#F0,#00,#00,#00,#00
FutChr28:	DB	#81,#42,#24,#18,#18,#24,#42,#81
FutChr29:	DB	#01,#02,#04,#08,#10,#20,#40,#80
FutChr30:	DB	#80,#40,#20,#10,#08,#04,#02,#01
FutChr31:	DB	#00,#10,#10,#FF,#10,#10,#00,#00
FutChr32:	DB	#00,#00,#00,#00,#00,#00,#00,#00
FutChr33:	DB	#20,#20,#20,#20,#00,#00,#20,#00
FutChr34:	DB	#50,#50,#50,#00,#00,#00,#00,#00
FutChr35:	DB	#50,#50,#F8,#50,#F8,#50,#50,#00
FutChr36:	DB	#20,#78,#A0,#70,#28,#F0,#20,#00
FutChr37:	DB	#C0,#C8,#10,#20,#40,#98,#18,#00
FutChr38:	DB	#40,#A0,#40,#A8,#90,#98,#60,#00
FutChr39:	DB	#10,#20,#40,#00,#00,#00,#00,#00
FutChr40:	DB	#10,#20,#40,#40,#40,#20,#10,#00
FutChr41:	DB	#40,#20,#10,#10,#10,#20,#40,#00
FutChr42:	DB	#20,#A8,#70,#F8,#70,#A8,#20,#00
FutChr43:	DB	#00,#20,#20,#F8,#20,#20,#00,#00
FutChr44:	DB	#00,#00,#00,#00,#00,#20,#20,#40
FutChr45:	DB	#00,#00,#00,#78,#00,#00,#00,#00
FutChr46:	DB	#00,#00,#00,#00,#00,#60,#60,#00
FutChr47:	DB	#00,#00,#08,#10,#20,#40,#80,#00
FutChr48:	DB	#F8,#88,#98,#A8,#C8,#88,#F8,#00
FutChr49:	DB	#20,#60,#A0,#20,#20,#20,#20,#00
FutChr50:	DB	#F8,#88,#08,#10,#60,#80,#F8,#00
FutChr51:	DB	#F8,#88,#08,#30,#08,#88,#F8,#00
FutChr52:	DB	#10,#50,#50,#90,#F8,#10,#10,#00
FutChr53:	DB	#F8,#80,#F0,#08,#08,#10,#E0,#00
FutChr54:	DB	#30,#40,#80,#F0,#88,#88,#70,#00
FutChr55:	DB	#F8,#08,#10,#20,#20,#20,#20,#00
FutChr56:	DB	#70,#88,#88,#70,#88,#88,#70,#00
FutChr57:	DB	#70,#88,#88,#78,#08,#10,#60,#00
FutChr58:	DB	#00,#00,#20,#00,#00,#20,#00,#00
FutChr59:	DB	#00,#00,#20,#00,#00,#20,#20,#40
FutChr60:	DB	#18,#30,#60,#C0,#60,#30,#18,#00
FutChr61:	DB	#00,#00,#F8,#00,#F8,#00,#00,#00
FutChr62:	DB	#C0,#60,#30,#18,#30,#60,#C0,#00
FutChr63:	DB	#70,#88,#08,#10,#20,#00,#20,#00
FutChr64:	DB	#70,#88,#08,#48,#A8,#A8,#70,#00
FutChr65:	DB	#F8,#88,#88,#F8,#88,#88,#88,#00
FutChr66:	DB	#F8,#88,#88,#F0,#88,#88,#F8,#00
FutChr67:	DB	#F8,#80,#80,#80,#80,#80,#F8,#00
FutChr68:	DB	#F0,#88,#88,#88,#88,#88,#F0,#00
FutChr69:	DB	#F8,#80,#80,#F0,#80,#80,#F8,#00
FutChr70:	DB	#F8,#80,#80,#F0,#80,#80,#80,#00
FutChr71:	DB	#F8,#80,#80,#B8,#88,#88,#F8,#00
FutChr72:	DB	#88,#88,#88,#F8,#88,#88,#88,#00
FutChr73:	DB	#20,#20,#20,#20,#20,#20,#20,#00
FutChr74:	DB	#10,#10,#10,#10,#10,#90,#F0,#00
FutChr75:	DB	#90,#90,#90,#F8,#88,#88,#88,#00
FutChr76:	DB	#80,#80,#80,#80,#80,#80,#F8,#00
FutChr77:	DB	#F8,#A8,#A8,#A8,#A8,#A8,#A8,#00
FutChr78:	DB	#F8,#88,#88,#88,#88,#88,#88,#00
FutChr79:	DB	#F8,#88,#88,#88,#88,#88,#F8,#00
FutChr80:	DB	#F8,#88,#88,#F8,#80,#80,#80,#00
FutChr81:	DB	#F8,#88,#88,#88,#98,#98,#F8,#00
FutChr82:	DB	#F0,#90,#90,#F8,#88,#88,#88,#00
FutChr83:	DB	#F8,#80,#80,#F8,#08,#08,#F8,#00
FutChr84:	DB	#F8,#20,#20,#20,#20,#20,#20,#00
FutChr85:	DB	#88,#88,#88,#88,#88,#88,#F8,#00
FutChr86:	DB	#88,#88,#88,#50,#50,#50,#20,#00
FutChr87:	DB	#A8,#A8,#A8,#A8,#A8,#A8,#F8,#00
FutChr88:	DB	#88,#88,#88,#70,#88,#88,#88,#00
FutChr89:	DB	#88,#88,#88,#F8,#20,#20,#20,#00
FutChr90:	DB	#F8,#08,#10,#20,#40,#80,#F8,#00
FutChr91:	DB	#70,#40,#40,#40,#40,#40,#70,#00
FutChr92:	DB	#00,#00,#80,#40,#20,#10,#08,#00
FutChr93:	DB	#70,#10,#10,#10,#10,#10,#70,#00
FutChr94:	DB	#20,#50,#88,#00,#00,#00,#00,#00
FutChr95:	DB	#00,#00,#00,#00,#00,#00,#F8,#00
FutChr96:	DB	#80,#40,#20,#00,#00,#00,#00,#00
FutChr97:	DB	#00,#00,#F8,#08,#F8,#88,#F8,#00
FutChr98:	DB	#80,#80,#80,#F8,#88,#88,#F8,#00
FutChr99:	DB	#00,#00,#F8,#80,#80,#80,#F8,#00
FutChr100:	DB	#08,#08,#08,#F8,#88,#88,#F8,#00
FutChr101:	DB	#00,#00,#F8,#88,#F8,#80,#F8,#00
FutChr102:	DB	#70,#40,#40,#E0,#40,#40,#40,#00
FutChr103:	DB	#00,#00,#F8,#88,#88,#F8,#08,#F8
FutChr104:	DB	#80,#80,#F8,#88,#88,#88,#88,#00
FutChr105:	DB	#20,#00,#20,#20,#20,#20,#20,#00
FutChr106:	DB	#10,#00,#10,#10,#10,#10,#10,#70
FutChr107:	DB	#A0,#A0,#A0,#F0,#90,#90,#90,#00
FutChr108:	DB	#20,#20,#20,#20,#20,#20,#30,#00
FutChr109:	DB	#00,#00,#F8,#A8,#A8,#A8,#A8,#00
FutChr110:	DB	#00,#00,#F8,#88,#88,#88,#88,#00
FutChr111:	DB	#00,#00,#F8,#88,#88,#88,#F8,#00
FutChr112:	DB	#00,#00,#F8,#88,#88,#F8,#80,#80
FutChr113:	DB	#00,#00,#F8,#88,#88,#F8,#08,#08
FutChr114:	DB	#00,#00,#F0,#80,#80,#80,#80,#00
FutChr115:	DB	#00,#00,#F8,#80,#F8,#08,#F8,#00
FutChr116:	DB	#40,#40,#E0,#40,#40,#40,#60,#00
FutChr117:	DB	#00,#00,#90,#90,#90,#90,#F0,#00
FutChr118:	DB	#00,#00,#88,#88,#88,#50,#20,#00
FutChr119:	DB	#00,#00,#A8,#A8,#A8,#A8,#F8,#00
FutChr120:	DB	#00,#00,#88,#88,#70,#88,#88,#00
FutChr121:	DB	#00,#00,#88,#88,#88,#F8,#08,#F8
FutChr122:	DB	#00,#00,#F8,#10,#20,#40,#F8,#00
FutChr123:	DB	#18,#20,#20,#40,#20,#20,#18,#00
FutChr124:	DB	#20,#20,#20,#00,#20,#20,#20,#00
FutChr125:	DB	#C0,#20,#20,#10,#20,#20,#C0,#00
FutChr126:	DB	#40,#A8,#10,#00,#00,#00,#00,#00
FutChr127:	DB	#00,#00,#20,#50,#F8,#00,#00,#00
FutChr128:	DB	#F8,#80,#80,#80,#80,#80,#F8,#30
FutChr129:	DB	#90,#00,#90,#90,#90,#90,#F0,#00
FutChr130:	DB	#08,#10,#F8,#88,#F8,#80,#F8,#00
FutChr131:	DB	#20,#50,#F8,#08,#F8,#88,#F8,#00
FutChr132:	DB	#50,#A0,#70,#08,#78,#88,#78,#00
FutChr133:	DB	#80,#40,#F8,#08,#F8,#88,#F8,#00
FutChr134:	DB	#20,#00,#70,#08,#78,#88,#78,#00
FutChr135:	DB	#00,#00,#F8,#80,#80,#80,#F8,#20
FutChr136:	DB	#20,#50,#F8,#88,#F8,#80,#F8,#00
FutChr137:	DB	#50,#A0,#70,#88,#F8,#80,#70,#00
FutChr138:	DB	#08,#10,#F8,#88,#88,#88,#F8,#00
FutChr139:	DB	#10,#20,#90,#90,#90,#90,#F0,#00
FutChr140:	DB	#20,#50,#F8,#88,#F8,#88,#88,#00
FutChr141:	DB	#20,#50,#F8,#80,#F8,#80,#F8,#00
FutChr142:	DB	#20,#50,#F8,#88,#88,#88,#F8,#00
FutChr143:	DB	#40,#20,#F8,#88,#F8,#88,#88,#00
FutChr144:	DB	#10,#20,#F8,#80,#F8,#80,#F8,#00
FutChr145:	DB	#00,#00,#6C,#12,#7E,#90,#6E,#00
FutChr146:	DB	#3E,#50,#90,#9C,#F0,#90,#9E,#00
FutChr147:	DB	#20,#50,#F8,#88,#88,#88,#F8,#00
FutChr148:	DB	#50,#A0,#70,#88,#88,#88,#70,#00
FutChr149:	DB	#80,#40,#70,#88,#88,#88,#70,#00
FutChr150:	DB	#60,#90,#00,#90,#90,#90,#68,#00
FutChr151:	DB	#80,#40,#90,#90,#90,#90,#68,#00
FutChr152:	DB	#50,#A0,#10,#90,#B0,#50,#10,#E0
FutChr153:	DB	#50,#A0,#70,#88,#88,#88,#70,#00
FutChr154:	DB	#88,#00,#88,#88,#88,#88,#F8,#00
FutChr155:	DB	#20,#20,#78,#80,#80,#78,#20,#20
FutChr156:	DB	#18,#24,#20,#F8,#20,#E2,#5C,#00
FutChr157:	DB	#88,#50,#20,#F8,#20,#F8,#20,#00
FutChr158:	DB	#40,#A0,#80,#8A,#8C,#A8,#48,#00
FutChr159:	DB	#18,#20,#20,#F8,#20,#20,#20,#40
FutChr160:	DB	#10,#20,#70,#08,#78,#88,#78,#00
FutChr161:	DB	#10,#20,#00,#60,#20,#20,#70,#00
FutChr162:	DB	#08,#10,#70,#88,#88,#88,#70,#00
FutChr163:	DB	#10,#20,#90,#90,#90,#90,#68,#00
FutChr164:	DB	#50,#A0,#00,#A0,#D0,#90,#90,#00
FutChr165:	DB	#28,#50,#00,#C8,#A8,#98,#88,#00
FutChr166:	DB	#60,#90,#90,#68,#00,#F8,#00,#00
FutChr167:	DB	#60,#90,#90,#60,#00,#F0,#00,#00
FutChr168:	DB	#20,#00,#20,#40,#80,#88,#70,#00
FutChr169:	DB	#00,#00,#00,#F8,#80,#80,#00,#00
FutChr170:	DB	#00,#00,#00,#F8,#08,#08,#00,#00
FutChr171:	DB	#84,#88,#90,#A8,#54,#84,#08,#1C
FutChr172:	DB	#84,#88,#90,#A8,#58,#A8,#3C,#08
FutChr173:	DB	#20,#00,#00,#20,#20,#20,#20,#00
FutChr174:	DB	#00,#12,#24,#48,#90,#48,#24,#12
FutChr175:	DB	#00,#90,#48,#24,#12,#24,#48,#90
FutChr176:	DB	#28,#50,#20,#50,#88,#F8,#88,#00
FutChr177:	DB	#28,#50,#70,#08,#78,#88,#78,#00
FutChr178:	DB	#28,#50,#00,#70,#20,#20,#70,#00
FutChr179:	DB	#28,#50,#00,#20,#20,#20,#70,#00
FutChr180:	DB	#50,#A0,#70,#88,#88,#88,#70,#00
FutChr181:	DB	#50,#A0,#70,#88,#88,#88,#70,#00
FutChr182:	DB	#50,#A0,#88,#88,#88,#88,#70,#00
FutChr183:	DB	#50,#A0,#00,#90,#90,#90,#68,#00
FutChr184:	DB	#FC,#48,#48,#48,#E8,#08,#50,#20
FutChr185:	DB	#00,#A0,#00,#A0,#A0,#A0,#20,#40
FutChr186:	DB	#C0,#44,#C8,#54,#EC,#54,#9E,#04
FutChr187:	DB	#10,#A8,#40,#00,#00,#00,#00,#00
FutChr188:	DB	#00,#20,#50,#88,#50,#20,#00,#00
FutChr189:	DB	#C4,#C8,#10,#20,#40,#B6,#36,#00
FutChr190:	DB	#7C,#A8,#A8,#68,#28,#28,#28,#00
FutChr191:	DB	#38,#40,#30,#48,#48,#30,#08,#70
FutChr192:	DB	#00,#00,#00,#00,#00,#00,#FF,#FF
FutChr193:	DB	#F0,#F0,#F0,#F0,#0F,#0F,#0F,#0F
FutChr194:	DB	#00,#00,#FF,#FF,#FF,#FF,#FF,#FF
FutChr195:	DB	#FF,#FF,#00,#00,#00,#00,#00,#00
FutChr196:	DB	#00,#00,#00,#3C,#3C,#00,#00,#00
FutChr197:	DB	#FF,#FF,#FF,#FF,#FF,#FF,#00,#00
FutChr198:	DB	#C0,#C0,#C0,#C0,#C0,#C0,#C0,#C0
FutChr199:	DB	#0F,#0F,#0F,#0F,#F0,#F0,#F0,#F0
FutChr200:	DB	#FC,#FC,#FC,#FC,#FC,#FC,#FC,#FC
FutChr201:	DB	#03,#03,#03,#03,#03,#03,#03,#03
FutChr202:	DB	#3F,#3F,#3F,#3F,#3F,#3F,#3F,#3F
FutChr203:	DB	#11,#22,#44,#88,#11,#22,#44,#88
FutChr204:	DB	#88,#44,#22,#11,#88,#44,#22,#11
FutChr205:	DB	#FE,#7C,#38,#10,#00,#00,#00,#00
FutChr206:	DB	#00,#00,#00,#00,#10,#38,#7C,#FE
FutChr207:	DB	#80,#C0,#E0,#F0,#E0,#C0,#80,#00
FutChr208:	DB	#01,#03,#07,#0F,#07,#03,#01,#00
FutChr209:	DB	#FF,#7E,#3C,#18,#18,#3C,#7E,#FF
FutChr210:	DB	#81,#C3,#E7,#FF,#FF,#E7,#C3,#81
FutChr211:	DB	#F0,#F0,#F0,#F0,#00,#00,#00,#00
FutChr212:	DB	#00,#00,#00,#00,#0F,#0F,#0F,#0F
FutChr213:	DB	#0F,#0F,#0F,#0F,#00,#00,#00,#00
FutChr214:	DB	#00,#00,#00,#00,#F0,#F0,#F0,#F0
FutChr215:	DB	#33,#33,#CC,#CC,#33,#33,#CC,#CC
FutChr216:	DB	#00,#20,#20,#50,#50,#88,#F8,#00
FutChr217:	DB	#20,#20,#70,#20,#70,#20,#20,#00
FutChr218:	DB	#00,#00,#00,#50,#88,#A8,#50,#00
FutChr219:	DB	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF
FutChr220:	DB	#00,#00,#00,#00,#FF,#FF,#FF,#FF
FutChr221:	DB	#F0,#F0,#F0,#F0,#F0,#F0,#F0,#F0
FutChr222:	DB	#0F,#0F,#0F,#0F,#0F,#0F,#0F,#0F
FutChr223:	DB	#FF,#FF,#FF,#FF,#00,#00,#00,#00
FutChr224:	DB	#00,#00,#68,#90,#90,#90,#68,#00
FutChr225:	DB	#30,#48,#48,#70,#48,#48,#70,#C0
FutChr226:	DB	#F8,#88,#80,#80,#80,#80,#80,#00
FutChr227:	DB	#F8,#50,#50,#50,#50,#50,#98,#00
FutChr228:	DB	#F8,#88,#40,#20,#40,#88,#F8,#00
FutChr229:	DB	#00,#00,#78,#90,#90,#90,#60,#00
FutChr230:	DB	#00,#50,#50,#50,#50,#68,#80,#80
FutChr231:	DB	#00,#50,#A0,#20,#20,#20,#20,#00
FutChr232:	DB	#F8,#20,#70,#A8,#A8,#70,#20,#F8
FutChr233:	DB	#20,#50,#88,#F8,#88,#50,#20,#00
FutChr234:	DB	#70,#88,#88,#88,#50,#50,#D8,#00
FutChr235:	DB	#30,#40,#40,#20,#50,#50,#50,#20
FutChr236:	DB	#00,#00,#00,#50,#A8,#A8,#50,#00
FutChr237:	DB	#08,#70,#A8,#A8,#A8,#70,#80,#00
FutChr238:	DB	#38,#40,#80,#F8,#80,#40,#38,#00
FutChr239:	DB	#70,#88,#88,#88,#88,#88,#88,#00
FutChr240:	DB	#00,#50,#A0,#00,#F0,#00,#F0,#00
FutChr241:	DB	#20,#20,#F8,#20,#20,#00,#F8,#00
FutChr242:	DB	#C0,#30,#08,#30,#C0,#00,#F8,#00
FutChr243:	DB	#18,#60,#80,#60,#18,#00,#F8,#00
FutChr244:	DB	#10,#28,#20,#20,#20,#20,#20,#20
FutChr245:	DB	#20,#20,#20,#20,#20,#20,#A0,#40
FutChr246:	DB	#00,#20,#00,#F8,#00,#20,#00,#00
FutChr247:	DB	#00,#50,#A0,#00,#50,#A0,#00,#00
FutChr248:	DB	#00,#18,#24,#24,#18,#00,#00,#00
FutChr249:	DB	#00,#30,#78,#78,#30,#00,#00,#00
FutChr250:	DB	#00,#00,#00,#00,#30,#00,#00,#00
FutChr251:	DB	#3E,#20,#20,#20,#A0,#60,#20,#00
FutChr252:	DB	#A0,#50,#50,#50,#00,#00,#00,#00
FutChr253:	DB	#40,#A0,#20,#40,#E0,#00,#00,#00
FutChr254:	DB	#00,#38,#38,#38,#38,#38,#38,#00
FutChr255:	DB	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF

	ORG	#6800
EuroStart:	;
EurChr0:	DB	#00,#00,#00,#00,#00,#00,#00,#00
EurChr1:	DB	#3C,#42,#A5,#81,#A5,#99,#42,#3C
EurChr2:	DB	#3C,#7E,#DB,#FF,#FF,#DB,#66,#3C
EurChr3:	DB	#6C,#FE,#FE,#FE,#7C,#38,#10,#00
EurChr4:	DB	#10,#38,#7C,#FE,#7C,#38,#10,#00
EurChr5:	DB	#10,#38,#54,#FE,#54,#10,#38,#00
EurChr6:	DB	#10,#38,#7C,#FE,#FE,#10,#38,#00
EurChr7:	DB	#00,#00,#00,#30,#30,#00,#00,#00
EurChr8:	DB	#FF,#FF,#FF,#E7,#E7,#FF,#FF,#FF
EurChr9:	DB	#38,#44,#82,#82,#82,#44,#38,#00
EurChr10:	DB	#C7,#BB,#7D,#7D,#7D,#BB,#C7,#FF
EurChr11:	DB	#0F,#03,#05,#79,#88,#88,#88,#70
EurChr12:	DB	#38,#44,#44,#44,#38,#10,#7C,#10
EurChr13:	DB	#30,#28,#24,#24,#28,#20,#E0,#C0
EurChr14:	DB	#3C,#24,#3C,#24,#24,#E4,#DC,#18
EurChr15:	DB	#10,#54,#38,#EE,#38,#54,#10,#00
EurChr16:	DB	#10,#10,#10,#7C,#10,#10,#10,#10
EurChr17:	DB	#10,#10,#10,#FF,#00,#00,#00,#00
EurChr18:	DB	#00,#00,#00,#FF,#10,#10,#10,#10
EurChr19:	DB	#10,#10,#10,#F0,#10,#10,#10,#10
EurChr20:	DB	#10,#10,#10,#1F,#10,#10,#10,#10
EurChr21:	DB	#10,#10,#10,#FF,#10,#10,#10,#10
EurChr22:	DB	#10,#10,#10,#10,#10,#10,#10,#10
EurChr23:	DB	#00,#00,#00,#FF,#00,#00,#00,#00
EurChr24:	DB	#00,#00,#00,#1F,#10,#10,#10,#10
EurChr25:	DB	#00,#00,#00,#F0,#10,#10,#10,#10
EurChr26:	DB	#10,#10,#10,#1F,#00,#00,#00,#00
EurChr27:	DB	#10,#10,#10,#F0,#00,#00,#00,#00
EurChr28:	DB	#81,#42,#24,#18,#18,#24,#42,#81
EurChr29:	DB	#01,#02,#04,#08,#10,#20,#40,#80
EurChr30:	DB	#80,#40,#20,#10,#08,#04,#02,#01
EurChr31:	DB	#00,#10,#10,#FF,#10,#10,#00,#00
EurChr32:	DB	#00,#00,#00,#00,#00,#00,#00,#00
EurChr33:	DB	#20,#20,#20,#20,#00,#00,#20,#00
EurChr34:	DB	#50,#50,#50,#00,#00,#00,#00,#00
EurChr35:	DB	#50,#50,#F8,#50,#F8,#50,#50,#00
EurChr36:	DB	#20,#78,#A0,#70,#28,#F0,#20,#00
EurChr37:	DB	#C0,#C8,#10,#20,#40,#98,#18,#00
EurChr38:	DB	#40,#A0,#40,#A8,#90,#98,#60,#00
EurChr39:	DB	#10,#20,#40,#00,#00,#00,#00,#00
EurChr40:	DB	#10,#20,#40,#40,#40,#20,#10,#00
EurChr41:	DB	#40,#20,#10,#10,#10,#20,#40,#00
EurChr42:	DB	#20,#A8,#70,#20,#70,#A8,#20,#00
EurChr43:	DB	#00,#20,#20,#F8,#20,#20,#00,#00
EurChr44:	DB	#00,#00,#00,#00,#00,#20,#20,#40
EurChr45:	DB	#00,#00,#00,#78,#00,#00,#00,#00
EurChr46:	DB	#00,#00,#00,#00,#00,#60,#60,#00
EurChr47:	DB	#00,#00,#08,#10,#20,#40,#80,#00
EurChr48:	DB	#70,#88,#98,#A8,#C8,#88,#70,#00
EurChr49:	DB	#20,#60,#A0,#20,#20,#20,#F8,#00
EurChr50:	DB	#70,#88,#08,#10,#60,#80,#F8,#00
EurChr51:	DB	#70,#88,#08,#30,#08,#88,#70,#00
EurChr52:	DB	#10,#30,#50,#90,#F8,#10,#10,#00
EurChr53:	DB	#F8,#80,#E0,#10,#08,#10,#E0,#00
EurChr54:	DB	#30,#40,#80,#F0,#88,#88,#70,#00
EurChr55:	DB	#F8,#88,#10,#20,#20,#20,#20,#00
EurChr56:	DB	#70,#88,#88,#70,#88,#88,#70,#00
EurChr57:	DB	#70,#88,#88,#78,#08,#10,#60,#00
EurChr58:	DB	#00,#00,#20,#00,#00,#20,#00,#00
EurChr59:	DB	#00,#00,#20,#00,#00,#20,#20,#40
EurChr60:	DB	#18,#30,#60,#C0,#60,#30,#18,#00
EurChr61:	DB	#00,#00,#F8,#00,#F8,#00,#00,#00
EurChr62:	DB	#C0,#60,#30,#18,#30,#60,#C0,#00
EurChr63:	DB	#70,#88,#08,#10,#20,#00,#20,#00
EurChr64:	DB	#70,#88,#08,#68,#A8,#A8,#70,#00
EurChr65:	DB	#20,#50,#88,#88,#F8,#88,#88,#00
EurChr66:	DB	#F0,#48,#48,#70,#48,#48,#F0,#00
EurChr67:	DB	#30,#48,#80,#80,#80,#48,#30,#00
EurChr68:	DB	#E0,#50,#48,#48,#48,#50,#E0,#00
EurChr69:	DB	#F8,#80,#80,#F0,#80,#80,#F8,#00
EurChr70:	DB	#F8,#80,#80,#F0,#80,#80,#80,#00
EurChr71:	DB	#70,#88,#80,#B8,#88,#88,#70,#00
EurChr72:	DB	#88,#88,#88,#F8,#88,#88,#88,#00
EurChr73:	DB	#70,#20,#20,#20,#20,#20,#70,#00
EurChr74:	DB	#38,#10,#10,#10,#90,#90,#60,#00
EurChr75:	DB	#88,#90,#A0,#C0,#A0,#90,#88,#00
EurChr76:	DB	#80,#80,#80,#80,#80,#80,#F8,#00
EurChr77:	DB	#88,#D8,#A8,#A8,#88,#88,#88,#00
EurChr78:	DB	#88,#C8,#C8,#A8,#98,#98,#88,#00
EurChr79:	DB	#70,#88,#88,#88,#88,#88,#70,#00
EurChr80:	DB	#F0,#88,#88,#F0,#80,#80,#80,#00
EurChr81:	DB	#70,#88,#88,#88,#A8,#90,#68,#00
EurChr82:	DB	#F0,#88,#88,#F0,#A0,#90,#88,#00
EurChr83:	DB	#70,#88,#80,#70,#08,#88,#70,#00
EurChr84:	DB	#F8,#20,#20,#20,#20,#20,#20,#00
EurChr85:	DB	#88,#88,#88,#88,#88,#88,#70,#00
EurChr86:	DB	#88,#88,#88,#88,#50,#50,#20,#00
EurChr87:	DB	#88,#88,#88,#A8,#A8,#D8,#88,#00
EurChr88:	DB	#88,#88,#50,#20,#50,#88,#88,#00
EurChr89:	DB	#88,#88,#88,#70,#20,#20,#20,#00
EurChr90:	DB	#F8,#08,#10,#20,#40,#80,#F8,#00
EurChr91:	DB	#70,#40,#40,#40,#40,#40,#70,#00
EurChr92:	DB	#00,#00,#80,#40,#20,#10,#08,#00
EurChr93:	DB	#70,#10,#10,#10,#10,#10,#70,#00
EurChr94:	DB	#20,#50,#88,#00,#00,#00,#00,#00
EurChr95:	DB	#00,#00,#00,#00,#00,#00,#F8,#00
EurChr96:	DB	#40,#20,#10,#00,#00,#00,#00,#00
EurChr97:	DB	#00,#00,#70,#08,#78,#88,#78,#00
EurChr98:	DB	#80,#80,#B0,#C8,#88,#C8,#B0,#00
EurChr99:	DB	#00,#00,#70,#88,#80,#88,#70,#00
EurChr100:	DB	#08,#08,#68,#98,#88,#98,#68,#00
EurChr101:	DB	#00,#00,#70,#88,#F8,#80,#70,#00
EurChr102:	DB	#10,#28,#20,#F8,#20,#20,#20,#00
EurChr103:	DB	#00,#00,#68,#98,#98,#68,#08,#70
EurChr104:	DB	#80,#80,#F0,#88,#88,#88,#88,#00
EurChr105:	DB	#20,#00,#60,#20,#20,#20,#70,#00
EurChr106:	DB	#10,#00,#30,#10,#10,#10,#90,#60
EurChr107:	DB	#40,#40,#48,#50,#60,#50,#48,#00
EurChr108:	DB	#60,#20,#20,#20,#20,#20,#70,#00
EurChr109:	DB	#00,#00,#D0,#A8,#A8,#A8,#A8,#00
EurChr110:	DB	#00,#00,#B0,#C8,#88,#88,#88,#00
EurChr111:	DB	#00,#00,#70,#88,#88,#88,#70,#00
EurChr112:	DB	#00,#00,#B0,#C8,#C8,#B0,#80,#80
EurChr113:	DB	#00,#00,#68,#98,#98,#68,#08,#08
EurChr114:	DB	#00,#00,#B0,#C8,#80,#80,#80,#00
EurChr115:	DB	#00,#00,#78,#80,#F0,#08,#F0,#00
EurChr116:	DB	#40,#40,#F0,#40,#40,#48,#30,#00
EurChr117:	DB	#00,#00,#90,#90,#90,#90,#68,#00
EurChr118:	DB	#00,#00,#88,#88,#88,#50,#20,#00
EurChr119:	DB	#00,#00,#88,#A8,#A8,#A8,#50,#00
EurChr120:	DB	#00,#00,#88,#50,#20,#50,#88,#00
EurChr121:	DB	#00,#00,#88,#88,#98,#68,#08,#70
EurChr122:	DB	#00,#00,#F8,#10,#20,#40,#F8,#00
EurChr123:	DB	#18,#20,#20,#40,#20,#20,#18,#00
EurChr124:	DB	#20,#20,#20,#00,#20,#20,#20,#00
EurChr125:	DB	#C0,#20,#20,#10,#20,#20,#C0,#00
EurChr126:	DB	#40,#A8,#10,#00,#00,#00,#00,#00
EurChr127:	DB	#00,#00,#20,#50,#F8,#00,#00,#00
EurChr128:	DB	#70,#88,#80,#80,#88,#70,#20,#60
EurChr129:	DB	#90,#00,#00,#90,#90,#90,#68,#00
EurChr130:	DB	#10,#20,#70,#88,#F8,#80,#70,#00
EurChr131:	DB	#20,#50,#70,#08,#78,#88,#78,#00
EurChr132:	DB	#48,#00,#70,#08,#78,#88,#78,#00
EurChr133:	DB	#20,#10,#70,#08,#78,#88,#78,#00
EurChr134:	DB	#20,#00,#70,#08,#78,#88,#78,#00
EurChr135:	DB	#00,#70,#80,#80,#80,#70,#10,#60
EurChr136:	DB	#20,#50,#70,#88,#F8,#80,#70,#00
EurChr137:	DB	#50,#00,#70,#88,#F8,#80,#70,#00
EurChr138:	DB	#20,#10,#70,#88,#F8,#80,#70,#00
EurChr139:	DB	#50,#00,#00,#60,#20,#20,#70,#00
EurChr140:	DB	#20,#50,#00,#60,#20,#20,#70,#00
EurChr141:	DB	#40,#20,#00,#60,#20,#20,#70,#00
EurChr142:	DB	#50,#00,#20,#50,#88,#F8,#88,#00
EurChr143:	DB	#20,#00,#20,#50,#88,#F8,#88,#00
EurChr144:	DB	#10,#20,#F8,#80,#F0,#80,#F8,#00
EurChr145:	DB	#00,#00,#6C,#12,#7E,#90,#6E,#00
EurChr146:	DB	#3E,#50,#90,#9C,#F0,#90,#9E,#00
EurChr147:	DB	#60,#90,#00,#60,#90,#90,#60,#00
EurChr148:	DB	#90,#00,#00,#60,#90,#90,#60,#00
EurChr149:	DB	#40,#20,#00,#60,#90,#90,#60,#00
EurChr150:	DB	#40,#A0,#00,#A0,#A0,#A0,#50,#00
EurChr151:	DB	#40,#20,#00,#A0,#A0,#A0,#50,#00
EurChr152:	DB	#90,#00,#90,#90,#B0,#50,#10,#E0
EurChr153:	DB	#50,#00,#70,#88,#88,#88,#70,#00
EurChr154:	DB	#50,#00,#88,#88,#88,#88,#70,#00
EurChr155:	DB	#20,#20,#78,#80,#80,#78,#20,#20
EurChr156:	DB	#18,#24,#20,#F8,#20,#E2,#5C,#00
EurChr157:	DB	#88,#50,#20,#F8,#20,#F8,#20,#00
EurChr158:	DB	#C0,#A0,#A0,#C8,#9C,#88,#88,#8C
EurChr159:	DB	#18,#20,#20,#F8,#20,#20,#20,#40
EurChr160:	DB	#10,#20,#70,#08,#78,#88,#78,#00
EurChr161:	DB	#10,#20,#00,#60,#20,#20,#70,#00
EurChr162:	DB	#20,#40,#00,#60,#90,#90,#60,#00
EurChr163:	DB	#20,#40,#00,#90,#90,#90,#68,#00
EurChr164:	DB	#50,#A0,#00,#A0,#D0,#90,#90,#00
EurChr165:	DB	#28,#50,#00,#C8,#A8,#98,#88,#00
EurChr166:	DB	#00,#70,#08,#78,#88,#78,#00,#F8
EurChr167:	DB	#00,#60,#90,#90,#90,#60,#00,#F0
EurChr168:	DB	#20,#00,#20,#40,#80,#88,#70,#00
EurChr169:	DB	#00,#00,#00,#F8,#80,#80,#00,#00
EurChr170:	DB	#00,#00,#00,#F8,#08,#08,#00,#00
EurChr171:	DB	#84,#88,#90,#A8,#54,#84,#08,#1C
EurChr172:	DB	#84,#88,#90,#A8,#58,#A8,#3C,#08
EurChr173:	DB	#20,#00,#00,#20,#20,#20,#20,#00
EurChr174:	DB	#00,#00,#24,#48,#90,#48,#24,#00
EurChr175:	DB	#00,#00,#90,#48,#24,#48,#90,#00
EurChr176:	DB	#28,#50,#20,#50,#88,#F8,#88,#00
EurChr177:	DB	#28,#50,#70,#08,#78,#88,#78,#00
EurChr178:	DB	#28,#50,#00,#70,#20,#20,#70,#00
EurChr179:	DB	#28,#50,#00,#20,#20,#20,#70,#00
EurChr180:	DB	#28,#50,#00,#70,#88,#88,#70,#00
EurChr181:	DB	#50,#A0,#00,#60,#90,#90,#60,#00
EurChr182:	DB	#28,#50,#00,#88,#88,#88,#70,#00
EurChr183:	DB	#50,#A0,#00,#A0,#A0,#A0,#50,#00
EurChr184:	DB	#FC,#48,#48,#48,#E8,#08,#50,#20
EurChr185:	DB	#00,#50,#00,#50,#50,#50,#10,#20
EurChr186:	DB	#C0,#44,#C8,#54,#EC,#54,#9E,#04
EurChr187:	DB	#10,#A8,#40,#00,#00,#00,#00,#00
EurChr188:	DB	#00,#20,#50,#88,#50,#20,#00,#00
EurChr189:	DB	#88,#10,#20,#40,#80,#28,#00,#00
EurChr190:	DB	#7C,#A8,#A8,#68,#28,#28,#28,#00
EurChr191:	DB	#38,#40,#30,#48,#48,#30,#08,#70
EurChr192:	DB	#00,#00,#00,#00,#00,#00,#FF,#FF
EurChr193:	DB	#F0,#F0,#F0,#F0,#0F,#0F,#0F,#0F
EurChr194:	DB	#00,#00,#FF,#FF,#FF,#FF,#FF,#FF
EurChr195:	DB	#FF,#FF,#00,#00,#00,#00,#00,#00
EurChr196:	DB	#00,#00,#00,#3C,#3C,#00,#00,#00
EurChr197:	DB	#FF,#FF,#FF,#FF,#FF,#FF,#00,#00
EurChr198:	DB	#C0,#C0,#C0,#C0,#C0,#C0,#C0,#C0
EurChr199:	DB	#0F,#0F,#0F,#0F,#F0,#F0,#F0,#F0
EurChr200:	DB	#FC,#FC,#FC,#FC,#FC,#FC,#FC,#FC
EurChr201:	DB	#03,#03,#03,#03,#03,#03,#03,#03
EurChr202:	DB	#3F,#3F,#3F,#3F,#3F,#3F,#3F,#3F
EurChr203:	DB	#11,#22,#44,#88,#11,#22,#44,#88
EurChr204:	DB	#88,#44,#22,#11,#88,#44,#22,#11
EurChr205:	DB	#FE,#7C,#38,#10,#00,#00,#00,#00
EurChr206:	DB	#00,#00,#00,#00,#10,#38,#7C,#FE
EurChr207:	DB	#80,#C0,#E0,#F0,#E0,#C0,#80,#00
EurChr208:	DB	#01,#03,#07,#0F,#07,#03,#01,#00
EurChr209:	DB	#FF,#7E,#3C,#18,#18,#3C,#7E,#FF
EurChr210:	DB	#81,#C3,#E7,#FF,#FF,#E7,#C3,#81
EurChr211:	DB	#F0,#F0,#F0,#F0,#00,#00,#00,#00
EurChr212:	DB	#00,#00,#00,#00,#0F,#0F,#0F,#0F
EurChr213:	DB	#0F,#0F,#0F,#0F,#00,#00,#00,#00
EurChr214:	DB	#00,#00,#00,#00,#F0,#F0,#F0,#F0
EurChr215:	DB	#33,#33,#CC,#CC,#33,#33,#CC,#CC
EurChr216:	DB	#00,#20,#20,#50,#50,#88,#F8,#00
EurChr217:	DB	#20,#20,#70,#20,#70,#20,#20,#00
EurChr218:	DB	#00,#00,#00,#50,#88,#A8,#50,#00
EurChr219:	DB	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF
EurChr220:	DB	#00,#00,#00,#00,#FF,#FF,#FF,#FF
EurChr221:	DB	#F0,#F0,#F0,#F0,#F0,#F0,#F0,#F0
EurChr222:	DB	#0F,#0F,#0F,#0F,#0F,#0F,#0F,#0F
EurChr223:	DB	#FF,#FF,#FF,#FF,#00,#00,#00,#00
EurChr224:	DB	#00,#00,#68,#90,#90,#90,#68,#00
EurChr225:	DB	#30,#48,#48,#70,#48,#48,#70,#C0
EurChr226:	DB	#F8,#88,#80,#80,#80,#80,#80,#00
EurChr227:	DB	#F8,#50,#50,#50,#50,#50,#98,#00
EurChr228:	DB	#F8,#88,#40,#20,#40,#88,#F8,#00
EurChr229:	DB	#00,#00,#78,#90,#90,#90,#60,#00
EurChr230:	DB	#00,#50,#50,#50,#50,#68,#80,#80
EurChr231:	DB	#00,#50,#A0,#20,#20,#20,#20,#00
EurChr232:	DB	#F8,#20,#70,#A8,#A8,#70,#20,#F8
EurChr233:	DB	#20,#50,#88,#F8,#88,#50,#20,#00
EurChr234:	DB	#70,#88,#88,#88,#50,#50,#D8,#00
EurChr235:	DB	#30,#40,#40,#20,#50,#50,#50,#20
EurChr236:	DB	#00,#00,#00,#50,#A8,#A8,#50,#00
EurChr237:	DB	#08,#70,#A8,#A8,#A8,#70,#80,#00
EurChr238:	DB	#38,#40,#80,#F8,#80,#40,#38,#00
EurChr239:	DB	#70,#88,#88,#88,#88,#88,#88,#00
EurChr240:	DB	#00,#F8,#00,#F8,#00,#F8,#00,#00
EurChr241:	DB	#20,#20,#F8,#20,#20,#00,#F8,#00
EurChr242:	DB	#C0,#30,#08,#30,#C0,#00,#F8,#00
EurChr243:	DB	#18,#60,#80,#60,#18,#00,#F8,#00
EurChr244:	DB	#10,#28,#20,#20,#20,#20,#20,#20
EurChr245:	DB	#20,#20,#20,#20,#20,#20,#A0,#40
EurChr246:	DB	#00,#20,#00,#F8,#00,#20,#00,#00
EurChr247:	DB	#00,#50,#A0,#00,#50,#A0,#00,#00
EurChr248:	DB	#00,#18,#24,#24,#18,#00,#00,#00
EurChr249:	DB	#00,#30,#78,#78,#30,#00,#00,#00
EurChr250:	DB	#00,#00,#00,#00,#30,#00,#00,#00
EurChr251:	DB	#3E,#20,#20,#20,#A0,#60,#20,#00
EurChr252:	DB	#A0,#50,#50,#50,#00,#00,#00,#00
EurChr253:	DB	#40,#A0,#20,#40,#E0,#00,#00,#00
EurChr254:	DB	#00,#38,#38,#38,#38,#38,#38,#00
EurChr255:	DB	#00,#00,#00,#00,#00,#00,#00,#00

	ORG	#7000
MbStart:	;
OldMbChar0:	;      DB      #FC,#84,#84,#84,#84,#84,#84,#FC
MbChar0:	DB	#00,#00,#00,#00,#00,#00,#00,#00
MbChar1:	DB	#3C,#42,#A5,#81,#A5,#99,#42,#3C
MbChar2:	DB	#3C,#7E,#DB,#FF,#FF,#DB,#66,#3C
MbChar3:	DB	#6C,#FE,#FE,#FE,#7C,#38,#10,#00
MbChar4:	DB	#FF,#E7,#C3,#81,#C3,#E7,#FF,#FF
MbChar5:	DB	#10,#38,#54,#FE,#54,#10,#38,#00
MbChar6:	DB	#10,#38,#7C,#FE,#FE,#10,#38,#00
MbChar7:	DB	#00,#00,#00,#30,#30,#00,#00,#00
MbChar8:	DB	#FF,#FF,#FF,#E7,#E7,#FF,#FF,#FF
MbChar9:	DB	#30,#48,#84,#84,#84,#48,#30,#00
MbChar10:	DB	#CF,#B7,#7B,#7B,#7B,#B7,#CF,#FF
MbChar11:	DB	#00,#1C,#0C,#74,#90,#90,#90,#60
MbChar12:	DB	#38,#44,#44,#44,#38,#10,#7C,#10
MbChar13:	DB	#30,#28,#24,#24,#28,#20,#E0,#C0
MbChar14:	DB	#3C,#24,#3C,#24,#24,#E4,#DC,#18
MbChar15:	DB	#10,#54,#38,#EE,#38,#54,#10,#00
MbChar16:	DB	#10,#10,#10,#7C,#10,#10,#10,#10
MbChar17:	DB	#CC,#CC,#84,#00,#FC,#00,#00,#00
MbChar18:	DB	#00,#00,#FC,#00,#84,#CC,#CC,#CC
MbChar19:	DB	#CC,#CC,#8C,#0C,#8C,#CC,#CC,#CC
MbChar20:	DB	#CC,#CC,#C4,#C0,#C4,#CC,#CC,#CC
MbChar21:	DB	#CC,#CC,#84,#00,#84,#CC,#CC,#CC
MbChar22:	DB	#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC
MbChar23:	DB	#00,#00,#FF,#00,#FF,#00,#00,#00
MbChar24:	DB	#00,#00,#7F,#C0,#C7,#CC,#CC,#CC
MbChar25:	DB	#00,#00,#F8,#0C,#8C,#CC,#CC,#CC
MbChar26:	DB	#CC,#CC,#C7,#C0,#7F,#00,#00,#00
MbChar27:	DB	#CC,#CC,#8C,#0C,#F8,#00,#00,#00
MbChar28:	DB	#81,#42,#24,#18,#18,#24,#42,#81
MbChar29:	DB	#01,#02,#04,#08,#10,#20,#40,#80
MbChar30:	DB	#80,#40,#20,#10,#08,#04,#02,#01
MbChar31:	DB	#00,#10,#10,#FF,#10,#10,#00,#00
MbChar32:	DB	#00,#00,#00,#00,#00,#00,#00,#00
MbChar33:	DB	#30,#30,#30,#30,#30,#00,#30,#00
MbChar34:	DB	#28,#50,#A0,#00,#00,#00,#00,#00
MbChar35:	DB	#50,#50,#F8,#50,#F8,#50,#50,#00
MbChar36:	DB	#20,#F8,#A0,#F8,#28,#F8,#20,#00
MbChar37:	DB	#C8,#C8,#10,#20,#40,#98,#98,#00
MbChar38:	DB	#40,#A0,#40,#A8,#90,#98,#60,#00
MbChar39:	DB	#18,#30,#60,#00,#00,#00,#00,#00
MbChar40:	DB	#30,#60,#C0,#C0,#C0,#60,#30,#00
MbChar41:	DB	#30,#18,#0C,#0C,#0C,#18,#30,#00
MbChar42:	DB	#20,#A8,#70,#20,#70,#A8,#20,#00
MbChar43:	DB	#00,#20,#20,#F8,#20,#20,#00,#00
MbChar44:	DB	#00,#00,#00,#00,#00,#30,#30,#60
MbChar45:	DB	#00,#00,#00,#78,#00,#00,#00,#00
MbChar46:	DB	#00,#00,#00,#00,#00,#70,#70,#00
MbChar47:	DB	#00,#00,#08,#10,#20,#40,#80,#00
MbChar48:	DB	#70,#88,#98,#A8,#C8,#88,#70,#00
MbChar49:	DB	#20,#60,#E0,#20,#20,#20,#70,#00
MbChar50:	DB	#70,#88,#08,#10,#60,#80,#F8,#00
MbChar51:	DB	#F8,#88,#08,#30,#08,#88,#F8,#00
MbChar52:	DB	#10,#30,#50,#90,#F8,#10,#10,#00
MbChar53:	DB	#F8,#80,#80,#70,#08,#08,#F0,#00
MbChar54:	DB	#70,#88,#80,#F0,#88,#88,#70,#00
MbChar55:	DB	#F8,#88,#10,#20,#20,#20,#20,#00
MbChar56:	DB	#70,#88,#88,#70,#88,#88,#70,#00
MbChar57:	DB	#70,#88,#88,#78,#08,#88,#70,#00
MbChar58:	DB	#00,#00,#30,#00,#00,#30,#00,#00
MbChar59:	DB	#00,#00,#30,#00,#00,#30,#30,#60
MbChar60:	DB	#18,#30,#60,#C0,#60,#30,#18,#00
MbChar61:	DB	#00,#00,#F8,#00,#F8,#00,#00,#00
MbChar62:	DB	#C0,#60,#30,#18,#30,#60,#C0,#00
MbChar63:	DB	#78,#84,#08,#10,#20,#00,#20,#00
MbChar64:	DB	#70,#88,#08,#68,#A8,#A8,#70,#00
MbChar65:	DB	#70,#88,#88,#88,#F8,#88,#88,#00
MbChar66:	DB	#F0,#88,#88,#F0,#88,#88,#F0,#00
MbChar67:	DB	#70,#88,#80,#80,#80,#88,#70,#00
MbChar68:	DB	#F0,#88,#88,#88,#88,#88,#F0,#00
MbChar69:	DB	#78,#80,#80,#E0,#80,#80,#78,#00
MbChar70:	DB	#78,#80,#80,#F0,#80,#80,#80,#00
MbChar71:	DB	#70,#88,#80,#B8,#88,#88,#70,#00
MbChar72:	DB	#88,#88,#88,#F8,#88,#88,#88,#00
MbChar73:	DB	#70,#20,#20,#20,#20,#20,#70,#00
MbChar74:	DB	#08,#08,#08,#08,#08,#88,#70,#00
MbChar75:	DB	#88,#90,#A0,#C0,#A0,#A0,#98,#00
MbChar76:	DB	#80,#80,#80,#80,#80,#88,#F8,#00
MbChar77:	DB	#50,#A8,#A8,#88,#88,#88,#88,#00
MbChar78:	DB	#70,#88,#88,#88,#88,#88,#88,#00
MbChar79:	DB	#70,#88,#88,#88,#88,#88,#70,#00
MbChar80:	DB	#F0,#88,#88,#F0,#80,#80,#80,#00
MbChar81:	DB	#70,#88,#88,#88,#A8,#90,#68,#00
MbChar82:	DB	#F0,#88,#88,#F0,#90,#88,#88,#00
MbChar83:	DB	#70,#88,#80,#70,#08,#88,#70,#00
MbChar84:	DB	#F8,#20,#20,#20,#20,#20,#20,#00
MbChar85:	DB	#88,#88,#88,#88,#88,#88,#70,#00
MbChar86:	DB	#88,#88,#88,#88,#90,#A0,#40,#00
MbChar87:	DB	#88,#88,#88,#88,#A8,#A8,#50,#00
MbChar88:	DB	#88,#88,#50,#20,#50,#88,#88,#00
MbChar89:	DB	#88,#88,#88,#50,#20,#20,#20,#00
MbChar90:	DB	#F8,#08,#10,#20,#40,#80,#F8,#00
MbChar91:	DB	#70,#40,#40,#40,#40,#40,#70,#00
MbChar92:	DB	#00,#00,#80,#40,#20,#10,#08,#00
MbChar93:	DB	#70,#10,#10,#10,#10,#10,#70,#00
MbChar94:	DB	#20,#50,#88,#00,#00,#00,#00,#00
MbChar95:	DB	#00,#00,#00,#00,#00,#00,#00,#AB
MbChar96:	DB	#40,#20,#10,#00,#00,#00,#00,#00
MbChar97:	DB	#00,#00,#38,#48,#88,#98,#68,#00
MbChar98:	DB	#80,#80,#E0,#90,#88,#C8,#B0,#00
MbChar99:	DB	#00,#00,#70,#88,#80,#88,#70,#00
MbChar100:	DB	#08,#08,#38,#48,#88,#98,#68,#00
MbChar101:	DB	#00,#00,#70,#88,#B0,#C0,#78,#00
MbChar102:	DB	#70,#88,#80,#80,#E0,#80,#80,#00
MbChar103:	DB	#00,#00,#78,#88,#98,#68,#08,#F0
MbChar104:	DB	#80,#80,#F0,#88,#88,#88,#88,#00
MbChar105:	DB	#20,#00,#20,#20,#20,#20,#20,#00
MbChar106:	DB	#08,#00,#08,#08,#08,#08,#88,#70
MbChar107:	DB	#40,#40,#48,#50,#60,#50,#48,#00
MbChar108:	DB	#40,#40,#40,#40,#40,#40,#38,#00
MbChar109:	DB	#00,#00,#D0,#A8,#A8,#A8,#A8,#00
MbChar110:	DB	#00,#00,#F0,#88,#88,#88,#88,#00
MbChar111:	DB	#00,#00,#70,#88,#88,#88,#70,#00
MbChar112:	DB	#00,#00,#E0,#90,#88,#F0,#80,#80
MbChar113:	DB	#00,#00,#38,#48,#88,#78,#08,#08
MbChar114:	DB	#00,#00,#70,#88,#80,#80,#80,#00
MbChar115:	DB	#00,#00,#78,#80,#F0,#08,#F0,#00
MbChar116:	DB	#80,#80,#E0,#80,#80,#88,#70,#00
MbChar117:	DB	#00,#00,#88,#88,#88,#88,#70,#00
MbChar118:	DB	#00,#00,#88,#88,#88,#90,#60,#00
MbChar119:	DB	#00,#00,#88,#A8,#A8,#A8,#50,#00
MbChar120:	DB	#00,#00,#88,#50,#20,#50,#88,#00
MbChar121:	DB	#00,#00,#88,#88,#88,#78,#08,#F0
MbChar122:	DB	#00,#00,#F8,#10,#20,#40,#F8,#00
MbChar123:	DB	#18,#20,#20,#60,#20,#20,#18,#00
MbChar124:	DB	#30,#30,#30,#00,#30,#30,#30,#00
MbChar125:	DB	#C0,#20,#20,#30,#20,#20,#C0,#00
MbChar126:	DB	#40,#A8,#10,#00,#00,#00,#00,#00
MbChar127:	DB	#00,#00,#20,#50,#F8,#00,#00,#00
MbChar128:	DB	#70,#88,#80,#80,#88,#70,#20,#60
MbChar129:	DB	#90,#00,#00,#90,#90,#90,#68,#00
MbChar130:	DB	#10,#20,#70,#88,#F8,#80,#70,#00
MbChar131:	DB	#20,#50,#70,#08,#78,#88,#78,#00
MbChar132:	DB	#48,#00,#00,#38,#48,#98,#68,#00
MbChar133:	DB	#20,#10,#00,#38,#48,#98,#68,#00
MbChar134:	DB	#10,#10,#00,#38,#48,#98,#68,#00
MbChar135:	DB	#00,#70,#80,#80,#80,#70,#10,#60
MbChar136:	DB	#20,#50,#70,#88,#F8,#80,#70,#00
MbChar137:	DB	#50,#00,#70,#88,#F8,#80,#70,#00
MbChar138:	DB	#20,#10,#70,#88,#F8,#80,#70,#00
MbChar139:	DB	#50,#00,#20,#20,#20,#20,#20,#00
MbChar140:	DB	#20,#50,#00,#20,#20,#20,#20,#00
MbChar141:	DB	#40,#20,#00,#20,#20,#20,#20,#00
MbChar142:	DB	#50,#00,#70,#88,#88,#F8,#88,#00
MbChar143:	DB	#20,#00,#20,#50,#88,#F8,#88,#00
MbChar144:	DB	#10,#20,#F8,#80,#F0,#80,#F8,#00
MbChar145:	DB	#00,#00,#2C,#52,#9E,#B0,#5E,#00
MbChar146:	DB	#3E,#50,#90,#9C,#F0,#90,#9E,#00
MbChar147:	DB	#60,#90,#00,#60,#90,#90,#60,#00
MbChar148:	DB	#90,#00,#00,#60,#90,#90,#60,#00
MbChar149:	DB	#40,#20,#00,#60,#90,#90,#60,#00
MbChar150:	DB	#40,#A0,#00,#A0,#A0,#A0,#50,#00
MbChar151:	DB	#40,#20,#00,#90,#90,#90,#60,#00
MbChar152:	DB	#90,#00,#90,#90,#B0,#50,#10,#E0
MbChar153:	DB	#50,#00,#70,#88,#88,#88,#70,#00
MbChar154:	DB	#50,#00,#88,#88,#88,#88,#70,#00
MbChar155:	DB	#20,#20,#78,#80,#80,#78,#20,#20
MbChar156:	DB	#18,#24,#20,#F8,#20,#E2,#5C,#00
MbChar157:	DB	#88,#50,#20,#F8,#20,#F8,#20,#00
MbChar158:	DB	#C0,#A0,#A0,#C8,#9C,#88,#88,#8C
MbChar159:	DB	#38,#40,#40,#70,#40,#40,#40,#80
MbChar160:	DB	#10,#20,#00,#38,#48,#98,#68,#00
MbChar161:	DB	#10,#20,#00,#20,#20,#20,#20,#00
MbChar162:	DB	#20,#40,#00,#60,#90,#90,#60,#00
MbChar163:	DB	#10,#20,#00,#88,#88,#88,#70,#00
MbChar164:	DB	#50,#A0,#00,#60,#90,#90,#90,#00
MbChar165:	DB	#28,#50,#00,#C8,#A8,#98,#88,#00
MbChar166:	DB	#00,#00,#38,#48,#98,#68,#00,#F8
MbChar167:	DB	#00,#60,#90,#90,#90,#60,#00,#F0
MbChar168:	DB	#10,#00,#10,#20,#40,#84,#78,#00
MbChar169:	DB	#00,#00,#00,#F8,#80,#80,#00,#00
MbChar170:	DB	#00,#00,#00,#F8,#08,#08,#00,#00
MbChar171:	DB	#84,#88,#90,#A8,#54,#84,#08,#1C
MbChar172:	DB	#84,#88,#90,#A8,#58,#A8,#3C,#08
MbChar173:	DB	#30,#00,#30,#30,#30,#30,#30,#00
MbChar174:	DB	#00,#00,#24,#48,#90,#48,#24,#00
MbChar175:	DB	#00,#00,#90,#48,#24,#48,#90,#00
MbChar176:	DB	#28,#50,#20,#50,#88,#F8,#88,#00
MbChar177:	DB	#28,#50,#00,#38,#48,#98,#68,#00
MbChar178:	DB	#28,#50,#00,#70,#20,#20,#70,#00
MbChar179:	DB	#28,#50,#00,#20,#20,#20,#20,#00
MbChar180:	DB	#28,#50,#00,#70,#88,#88,#70,#00
MbChar181:	DB	#50,#A0,#00,#60,#90,#90,#60,#00
MbChar182:	DB	#28,#50,#00,#88,#88,#88,#70,#00
MbChar183:	DB	#50,#A0,#00,#90,#90,#90,#60,#00
MbChar184:	DB	#FC,#48,#48,#48,#E8,#08,#50,#20
MbChar185:	DB	#88,#00,#88,#88,#88,#88,#08,#70
MbChar186:	DB	#C0,#44,#C8,#54,#EC,#54,#9E,#04
MbChar187:	DB	#10,#A8,#40,#00,#00,#00,#00,#00
MbChar188:	DB	#00,#20,#50,#88,#50,#20,#00,#00
MbChar189:	DB	#88,#10,#20,#40,#80,#28,#00,#00
MbChar190:	DB	#7C,#A8,#A8,#68,#28,#28,#28,#00
MbChar191:	DB	#38,#40,#30,#48,#48,#30,#08,#70
MbChar192:	DB	#00,#00,#00,#00,#00,#00,#FF,#FF
MbChar193:	DB	#F0,#F0,#F0,#F0,#0F,#0F,#0F,#0F
MbChar194:	DB	#00,#00,#FF,#FF,#FF,#FF,#FF,#FF
MbChar195:	DB	#FF,#FF,#00,#00,#00,#00,#00,#00
MbChar196:	DB	#00,#00,#00,#3C,#3C,#00,#00,#00
MbChar197:	DB	#FF,#FF,#FF,#FF,#FF,#FF,#00,#00
MbChar198:	DB	#C0,#C0,#C0,#C0,#C0,#C0,#C0,#C0
MbChar199:	DB	#0F,#0F,#0F,#0F,#F0,#F0,#F0,#F0
MbChar200:	DB	#FC,#FC,#FC,#FC,#FC,#FC,#FC,#FC
MbChar201:	DB	#03,#03,#03,#03,#03,#03,#03,#03
MbChar202:	DB	#3F,#3F,#3F,#3F,#3F,#3F,#3F,#3F
MbChar203:	DB	#11,#22,#44,#88,#11,#22,#44,#88
MbChar204:	DB	#88,#44,#22,#11,#88,#44,#22,#11
MbChar205:	DB	#FE,#7C,#38,#10,#00,#00,#00,#00
MbChar206:	DB	#00,#00,#00,#00,#10,#38,#7C,#FE
MbChar207:	DB	#80,#C0,#E0,#F0,#E0,#C0,#80,#00
MbChar208:	DB	#01,#03,#07,#0F,#07,#03,#01,#00
MbChar209:	DB	#FF,#7E,#3C,#18,#18,#3C,#7E,#FF
MbChar210:	DB	#81,#C3,#E7,#FF,#FF,#E7,#C3,#81
MbChar211:	DB	#F0,#F0,#F0,#F0,#00,#00,#00,#00
MbChar212:	DB	#00,#00,#00,#00,#0F,#0F,#0F,#0F
MbChar213:	DB	#0F,#0F,#0F,#0F,#00,#00,#00,#00
MbChar214:	DB	#00,#00,#00,#00,#F0,#F0,#F0,#F0
MbChar215:	DB	#33,#33,#CC,#CC,#33,#33,#CC,#CC
MbChar216:	DB	#00,#20,#20,#50,#50,#88,#F8,#00
MbChar217:	DB	#20,#20,#70,#20,#70,#20,#20,#00
MbChar218:	DB	#00,#00,#00,#50,#88,#A8,#50,#00
MbChar219:	DB	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF
MbChar220:	DB	#00,#00,#00,#00,#FF,#FF,#FF,#FF
MbChar221:	DB	#F0,#F0,#F0,#F0,#F0,#F0,#F0,#F0
MbChar222:	DB	#0F,#0F,#0F,#0F,#0F,#0F,#0F,#0F
MbChar223:	DB	#FC,#FC,#FC,#FC,#00,#00,#00,#00
MbChar224:	DB	#00,#00,#68,#90,#90,#90,#68,#00
MbChar225:	DB	#30,#48,#48,#70,#48,#48,#70,#C0
MbChar226:	DB	#F8,#88,#80,#80,#80,#80,#80,#00
MbChar227:	DB	#F8,#50,#50,#50,#50,#50,#98,#00
MbChar228:	DB	#F8,#88,#40,#20,#40,#88,#F8,#00
MbChar229:	DB	#00,#00,#78,#90,#90,#90,#60,#00
MbChar230:	DB	#00,#50,#50,#50,#50,#68,#80,#80
MbChar231:	DB	#00,#50,#A0,#20,#20,#20,#20,#00
MbChar232:	DB	#F8,#20,#70,#A8,#A8,#70,#20,#F8
MbChar233:	DB	#20,#50,#88,#F8,#88,#50,#20,#00
MbChar234:	DB	#70,#88,#88,#88,#50,#50,#D8,#00
MbChar235:	DB	#30,#40,#40,#20,#50,#50,#50,#20
MbChar236:	DB	#00,#00,#00,#50,#A8,#A8,#50,#00
MbChar237:	DB	#08,#70,#A8,#A8,#A8,#70,#80,#00
MbChar238:	DB	#38,#40,#80,#F8,#80,#40,#38,#00
MbChar239:	DB	#70,#88,#88,#88,#88,#88,#88,#00
MbChar240:	DB	#00,#F8,#00,#F8,#00,#F8,#00,#00
MbChar241:	DB	#20,#20,#F8,#20,#20,#00,#F8,#00
MbChar242:	DB	#C0,#30,#08,#30,#C0,#00,#F8,#00
MbChar243:	DB	#18,#60,#80,#60,#18,#00,#F8,#00
MbChar244:	DB	#10,#28,#20,#20,#20,#20,#20,#20
MbChar245:	DB	#20,#20,#20,#20,#20,#20,#A0,#40
MbChar246:	DB	#00,#20,#00,#F8,#00,#20,#00,#00
MbChar247:	DB	#00,#50,#A0,#00,#50,#A0,#00,#00
MbChar248:	DB	#00,#18,#24,#24,#18,#00,#00,#00
MbChar249:	DB	#00,#30,#78,#78,#30,#00,#00,#00
MbChar250:	DB	#00,#00,#00,#00,#30,#00,#00,#00
MbChar251:	DB	#3E,#20,#20,#20,#A0,#60,#20,#00
MbChar252:	DB	#A0,#50,#50,#50,#00,#00,#00,#00
MbChar253:	DB	#40,#A0,#20,#40,#E0,#00,#00,#00
MbChar254:	DB	#00,#38,#38,#38,#38,#38,#38,#00
MbChar255:	DB	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF

	ORG	#7800
JapStart:	;
JapChr0:	DB	#00,#00,#00,#00,#00,#00,#00,#00
JapChr1:	DB	#7E,#42,#7E,#42,#7E,#42,#82,#00
JapChr2:	DB	#10,#92,#54,#10,#28,#44,#82,#00
JapChr3:	DB	#12,#14,#F8,#14,#34,#52,#92,#00
JapChr4:	DB	#10,#10,#FE,#10,#38,#54,#92,#00
JapChr5:	DB	#10,#28,#7C,#92,#38,#54,#FE,#00
JapChr6:	DB	#10,#10,#10,#7C,#10,#10,#FE,#00
JapChr7:	DB	#7E,#42,#42,#7E,#42,#42,#7E,#00
JapChr8:	DB	#40,#7E,#48,#3C,#28,#7E,#08,#00
JapChr9:	DB	#FE,#92,#92,#FE,#82,#82,#86,#00
JapChr10:	DB	#04,#EE,#A4,#EF,#A2,#EA,#06,#00
JapChr11:	DB	#28,#44,#82,#3C,#14,#24,#4C,#00
JapChr12:	DB	#28,#C8,#5C,#EA,#6C,#C8,#50,#00
JapChr13:	DB	#7C,#20,#7C,#44,#7C,#44,#7C,#00
JapChr14:	DB	#0C,#70,#10,#FE,#10,#10,#10,#00
JapChr15:	DB	#7E,#10,#1E,#12,#22,#44,#08,#00
JapChr16:	DB	#00,#7C,#28,#28,#28,#4E,#00,#00
JapChr17:	DB	#10,#10,#10,#FF,#00,#00,#00,#00
JapChr18:	DB	#00,#00,#00,#FF,#10,#10,#10,#10
JapChr19:	DB	#10,#10,#10,#F0,#10,#10,#10,#10
JapChr20:	DB	#10,#10,#10,#1F,#10,#10,#10,#10
JapChr21:	DB	#10,#10,#10,#FF,#10,#10,#10,#10
JapChr22:	DB	#10,#10,#10,#10,#10,#10,#10,#10
JapChr23:	DB	#00,#00,#00,#FF,#00,#00,#00,#00
JapChr24:	DB	#00,#00,#00,#1F,#10,#10,#10,#10
JapChr25:	DB	#00,#00,#00,#F0,#10,#10,#10,#10
JapChr26:	DB	#10,#10,#10,#1F,#00,#00,#00,#00
JapChr27:	DB	#10,#10,#10,#F0,#00,#00,#00,#00
JapChr28:	DB	#81,#42,#24,#18,#18,#24,#42,#81
JapChr29:	DB	#10,#7C,#10,#10,#28,#44,#82,#00
JapChr30:	DB	#10,#10,#FE,#92,#FE,#10,#10,#00
JapChr31:	DB	#10,#10,#54,#54,#92,#10,#30,#00
JapChr32:	DB	#00,#00,#00,#00,#00,#00,#00,#00
JapChr33:	DB	#20,#20,#20,#20,#00,#00,#20,#00
JapChr34:	DB	#50,#50,#50,#00,#00,#00,#00,#00
JapChr35:	DB	#50,#50,#F8,#50,#F8,#50,#50,#00
JapChr36:	DB	#20,#78,#A0,#70,#28,#F0,#20,#00
JapChr37:	DB	#C0,#C8,#10,#20,#40,#98,#18,#00
JapChr38:	DB	#40,#A0,#40,#A8,#90,#98,#60,#00
JapChr39:	DB	#10,#20,#40,#00,#00,#00,#00,#00
JapChr40:	DB	#10,#20,#40,#40,#40,#20,#10,#00
JapChr41:	DB	#40,#20,#10,#10,#10,#20,#40,#00
JapChr42:	DB	#20,#A8,#70,#20,#70,#A8,#20,#00
JapChr43:	DB	#00,#20,#20,#F8,#20,#20,#00,#00
JapChr44:	DB	#00,#00,#00,#00,#00,#20,#20,#40
JapChr45:	DB	#00,#00,#00,#78,#00,#00,#00,#00
JapChr46:	DB	#00,#00,#00,#00,#00,#60,#60,#00
JapChr47:	DB	#00,#00,#08,#10,#20,#40,#80,#00
JapChr48:	DB	#70,#88,#98,#A8,#C8,#88,#70,#00
JapChr49:	DB	#20,#60,#A0,#20,#20,#20,#F8,#00
JapChr50:	DB	#70,#88,#08,#10,#60,#80,#F8,#00
JapChr51:	DB	#70,#88,#08,#30,#08,#88,#70,#00
JapChr52:	DB	#10,#30,#50,#90,#F8,#10,#10,#00
JapChr53:	DB	#F8,#80,#E0,#10,#08,#10,#E0,#00
JapChr54:	DB	#30,#40,#80,#F0,#88,#88,#70,#00
JapChr55:	DB	#F8,#88,#10,#20,#20,#20,#20,#00
JapChr56:	DB	#70,#88,#88,#70,#88,#88,#70,#00
JapChr57:	DB	#70,#88,#88,#78,#08,#10,#60,#00
JapChr58:	DB	#00,#00,#20,#00,#00,#20,#00,#00
JapChr59:	DB	#00,#00,#20,#00,#00,#20,#20,#40
JapChr60:	DB	#18,#30,#60,#C0,#60,#30,#18,#00
JapChr61:	DB	#00,#00,#F8,#00,#F8,#00,#00,#00
JapChr62:	DB	#C0,#60,#30,#18,#30,#60,#C0,#00
JapChr63:	DB	#70,#88,#08,#10,#20,#00,#20,#00
JapChr64:	DB	#70,#88,#08,#68,#A8,#A8,#70,#00
JapChr65:	DB	#20,#50,#88,#88,#F8,#88,#88,#00
JapChr66:	DB	#F0,#48,#48,#70,#48,#48,#F0,#00
JapChr67:	DB	#30,#48,#80,#80,#80,#48,#30,#00
JapChr68:	DB	#E0,#50,#48,#48,#48,#50,#E0,#00
JapChr69:	DB	#F8,#80,#80,#F0,#80,#80,#F8,#00
JapChr70:	DB	#F8,#80,#80,#F0,#80,#80,#80,#00
JapChr71:	DB	#70,#88,#80,#B8,#88,#88,#70,#00
JapChr72:	DB	#88,#88,#88,#F8,#88,#88,#88,#00
JapChr73:	DB	#70,#20,#20,#20,#20,#20,#70,#00
JapChr74:	DB	#38,#10,#10,#10,#90,#90,#60,#00
JapChr75:	DB	#88,#90,#A0,#C0,#A0,#90,#88,#00
JapChr76:	DB	#80,#80,#80,#80,#80,#80,#F8,#00
JapChr77:	DB	#88,#D8,#A8,#A8,#88,#88,#88,#00
JapChr78:	DB	#88,#C8,#C8,#A8,#98,#98,#88,#00
JapChr79:	DB	#70,#88,#88,#88,#88,#88,#70,#00
JapChr80:	DB	#F0,#88,#88,#F0,#80,#80,#80,#00
JapChr81:	DB	#70,#88,#88,#88,#A8,#90,#68,#00
JapChr82:	DB	#F0,#88,#88,#F0,#A0,#90,#88,#00
JapChr83:	DB	#70,#88,#80,#70,#08,#88,#70,#00
JapChr84:	DB	#F8,#20,#20,#20,#20,#20,#20,#00
JapChr85:	DB	#88,#88,#88,#88,#88,#88,#70,#00
JapChr86:	DB	#88,#88,#88,#88,#50,#50,#20,#00
JapChr87:	DB	#88,#88,#88,#A8,#A8,#D8,#88,#00
JapChr88:	DB	#88,#88,#50,#20,#50,#88,#88,#00
JapChr89:	DB	#88,#88,#88,#70,#20,#20,#20,#00
JapChr90:	DB	#F8,#08,#10,#20,#40,#80,#F8,#00
JapChr91:	DB	#70,#40,#40,#40,#40,#40,#70,#00
JapChr92:	DB	#88,#50,#20,#70,#20,#70,#20,#00
JapChr93:	DB	#70,#10,#10,#10,#10,#10,#70,#00
JapChr94:	DB	#20,#50,#88,#00,#00,#00,#00,#00
JapChr95:	DB	#00,#00,#00,#00,#00,#00,#F8,#00
JapChr96:	DB	#40,#20,#10,#00,#00,#00,#00,#00
JapChr97:	DB	#00,#00,#70,#08,#78,#88,#78,#00
JapChr98:	DB	#80,#80,#B0,#C8,#88,#C8,#B0,#00
JapChr99:	DB	#00,#00,#70,#88,#80,#88,#70,#00
JapChr100:	DB	#08,#08,#68,#98,#88,#98,#68,#00
JapChr101:	DB	#00,#00,#70,#88,#F8,#80,#70,#00
JapChr102:	DB	#10,#28,#20,#F8,#20,#20,#20,#00
JapChr103:	DB	#00,#00,#68,#98,#98,#68,#08,#70
JapChr104:	DB	#80,#80,#F0,#88,#88,#88,#88,#00
JapChr105:	DB	#20,#00,#60,#20,#20,#20,#70,#00
JapChr106:	DB	#10,#00,#30,#10,#10,#10,#90,#60
JapChr107:	DB	#40,#40,#48,#50,#60,#50,#48,#00
JapChr108:	DB	#60,#20,#20,#20,#20,#20,#70,#00
JapChr109:	DB	#00,#00,#D0,#A8,#A8,#A8,#A8,#00
JapChr110:	DB	#00,#00,#B0,#C8,#88,#88,#88,#00
JapChr111:	DB	#00,#00,#70,#88,#88,#88,#70,#00
JapChr112:	DB	#00,#00,#B0,#C8,#C8,#B0,#80,#80
JapChr113:	DB	#00,#00,#68,#98,#98,#68,#08,#08
JapChr114:	DB	#00,#00,#B0,#C8,#80,#80,#80,#00
JapChr115:	DB	#00,#00,#78,#80,#F0,#08,#F0,#00
JapChr116:	DB	#40,#40,#F0,#40,#40,#48,#30,#00
JapChr117:	DB	#00,#00,#90,#90,#90,#90,#68,#00
JapChr118:	DB	#00,#00,#88,#88,#88,#50,#20,#00
JapChr119:	DB	#00,#00,#88,#A8,#A8,#A8,#50,#00
JapChr120:	DB	#00,#00,#88,#50,#20,#50,#88,#00
JapChr121:	DB	#00,#00,#88,#88,#98,#68,#08,#70
JapChr122:	DB	#00,#00,#F8,#10,#20,#40,#F8,#00
JapChr123:	DB	#18,#20,#20,#40,#20,#20,#18,#00
JapChr124:	DB	#20,#20,#20,#00,#20,#20,#20,#00
JapChr125:	DB	#C0,#20,#20,#10,#20,#20,#C0,#00
JapChr126:	DB	#40,#A8,#10,#00,#00,#00,#00,#00
JapChr127:	DB	#00,#00,#00,#00,#00,#00,#00,#00
JapChr128:	DB	#10,#38,#7C,#FE,#FE,#38,#7C,#00
JapChr129:	DB	#6C,#FE,#FE,#FE,#7C,#38,#10,#00
JapChr130:	DB	#38,#38,#FE,#FE,#D6,#10,#7C,#00
JapChr131:	DB	#10,#38,#7C,#FE,#7C,#38,#10,#00
JapChr132:	DB	#00,#78,#84,#84,#84,#84,#78,#00
JapChr133:	DB	#00,#78,#FC,#FC,#FC,#FC,#78,#00
JapChr134:	DB	#20,#F0,#4C,#70,#A8,#40,#3C,#00
JapChr135:	DB	#00,#20,#78,#20,#78,#B4,#64,#00
JapChr136:	DB	#00,#00,#88,#84,#84,#84,#40,#00
JapChr137:	DB	#00,#70,#00,#70,#88,#08,#30,#00
JapChr138:	DB	#00,#70,#00,#F0,#20,#60,#98,#00
JapChr139:	DB	#00,#20,#F8,#24,#78,#A4,#68,#00
JapChr140:	DB	#00,#90,#58,#64,#A8,#20,#10,#00
JapChr141:	DB	#00,#10,#B8,#D4,#94,#18,#20,#00
JapChr142:	DB	#00,#10,#1C,#10,#70,#98,#74,#00
JapChr143:	DB	#00,#00,#00,#78,#04,#04,#38,#00
JapChr144:	DB	#00,#00,#00,#00,#00,#00,#00,#00
JapChr145:	DB	#20,#7C,#20,#7C,#AA,#92,#64,#00
JapChr146:	DB	#00,#84,#82,#82,#82,#80,#40,#00
JapChr147:	DB	#38,#00,#38,#44,#04,#08,#30,#00
JapChr148:	DB	#70,#00,#F8,#10,#20,#60,#9C,#00
JapChr149:	DB	#24,#FA,#20,#7C,#A2,#A2,#44,#00
JapChr150:	DB	#40,#44,#F2,#4A,#48,#88,#30,#00
JapChr151:	DB	#20,#FC,#10,#FC,#08,#80,#78,#00
JapChr152:	DB	#08,#10,#20,#40,#20,#10,#08,#00
JapChr153:	DB	#04,#84,#9E,#84,#84,#84,#48,#00
JapChr154:	DB	#78,#04,#00,#00,#00,#80,#7C,#00
JapChr155:	DB	#10,#FE,#08,#04,#04,#80,#78,#00
JapChr156:	DB	#80,#80,#80,#80,#84,#88,#70,#00
JapChr157:	DB	#08,#FE,#38,#48,#38,#08,#10,#00
JapChr158:	DB	#44,#44,#FE,#44,#48,#40,#3C,#00
JapChr159:	DB	#44,#28,#FE,#20,#40,#40,#3C,#00
JapChr160:	DB	#00,#00,#00,#00,#00,#00,#00,#00
JapChr161:	DB	#00,#00,#00,#00,#60,#90,#60,#00
JapChr162:	DB	#38,#20,#20,#20,#00,#00,#00,#00
JapChr163:	DB	#00,#00,#00,#20,#20,#20,#E0,#00
JapChr164:	DB	#00,#00,#00,#00,#80,#40,#20,#00
JapChr165:	DB	#00,#00,#00,#30,#30,#00,#00,#00
JapChr166:	DB	#F8,#08,#F8,#08,#10,#20,#40,#00
JapChr167:	DB	#00,#00,#F0,#10,#60,#40,#80,#00
JapChr168:	DB	#00,#10,#20,#60,#A0,#20,#20,#00
JapChr169:	DB	#00,#20,#F0,#90,#10,#20,#40,#00
JapChr170:	DB	#00,#00,#F0,#20,#20,#20,#F0,#00
JapChr171:	DB	#00,#20,#F0,#60,#A0,#A0,#20,#00
JapChr172:	DB	#00,#40,#F8,#48,#50,#40,#40,#00
JapChr173:	DB	#00,#00,#70,#10,#10,#10,#F8,#00
JapChr174:	DB	#00,#00,#F0,#10,#F0,#10,#F0,#00
JapChr175:	DB	#00,#00,#A8,#A8,#08,#10,#20,#00
JapChr176:	DB	#00,#00,#80,#7C,#00,#00,#00,#00
JapChr177:	DB	#F8,#08,#28,#30,#20,#20,#40,#00
JapChr178:	DB	#08,#10,#20,#60,#A0,#20,#20,#00
JapChr179:	DB	#20,#F8,#88,#88,#08,#10,#20,#00
JapChr180:	DB	#00,#F8,#20,#20,#20,#20,#F8,#00
JapChr181:	DB	#10,#F8,#10,#30,#50,#90,#10,#00
JapChr182:	DB	#20,#F8,#28,#28,#28,#48,#88,#00
JapChr183:	DB	#20,#F8,#20,#F8,#20,#20,#20,#00
JapChr184:	DB	#78,#48,#88,#08,#08,#10,#20,#00
JapChr185:	DB	#40,#78,#50,#90,#10,#10,#20,#00
JapChr186:	DB	#00,#F8,#08,#08,#08,#08,#F8,#00
JapChr187:	DB	#50,#F8,#50,#50,#10,#10,#20,#00
JapChr188:	DB	#00,#C0,#08,#C8,#08,#10,#E0,#00
JapChr189:	DB	#00,#F8,#08,#10,#20,#50,#88,#00
JapChr190:	DB	#40,#F8,#48,#50,#40,#40,#38,#00
JapChr191:	DB	#88,#88,#48,#08,#10,#20,#40,#00
JapChr192:	DB	#78,#48,#78,#88,#08,#10,#20,#00
JapChr193:	DB	#10,#E0,#20,#F8,#20,#20,#40,#00
JapChr194:	DB	#A8,#A8,#A8,#08,#08,#10,#20,#00
JapChr195:	DB	#70,#00,#F8,#20,#20,#20,#40,#00
JapChr196:	DB	#40,#40,#60,#50,#48,#40,#40,#00
JapChr197:	DB	#20,#F8,#20,#20,#20,#20,#40,#00
JapChr198:	DB	#00,#70,#00,#00,#00,#00,#F8,#00
JapChr199:	DB	#00,#F8,#08,#D0,#20,#50,#88,#00
JapChr200:	DB	#20,#F8,#08,#30,#E8,#20,#20,#00
JapChr201:	DB	#08,#08,#08,#10,#20,#40,#80,#00
JapChr202:	DB	#20,#10,#48,#48,#48,#48,#88,#00
JapChr203:	DB	#80,#80,#F8,#80,#80,#80,#78,#00
JapChr204:	DB	#F8,#08,#08,#08,#10,#20,#40,#00
JapChr205:	DB	#00,#40,#A0,#10,#08,#08,#00,#00
JapChr206:	DB	#20,#F8,#20,#20,#A8,#A8,#20,#00
JapChr207:	DB	#00,#F8,#08,#08,#50,#20,#10,#00
JapChr208:	DB	#F0,#00,#60,#00,#00,#F0,#08,#00
JapChr209:	DB	#10,#20,#40,#80,#90,#88,#F8,#00
JapChr210:	DB	#08,#08,#08,#50,#20,#50,#80,#00
JapChr211:	DB	#78,#20,#F8,#20,#20,#20,#18,#00
JapChr212:	DB	#40,#F8,#48,#48,#50,#40,#40,#00
JapChr213:	DB	#00,#70,#10,#10,#10,#10,#F8,#00
JapChr214:	DB	#00,#F8,#08,#F8,#08,#08,#F8,#00
JapChr215:	DB	#70,#00,#F8,#08,#08,#10,#20,#00
JapChr216:	DB	#48,#48,#48,#48,#48,#10,#20,#00
JapChr217:	DB	#10,#50,#50,#50,#50,#58,#90,#00
JapChr218:	DB	#40,#40,#40,#48,#48,#50,#60,#00
JapChr219:	DB	#00,#F8,#88,#88,#88,#88,#F8,#00
JapChr220:	DB	#F8,#88,#88,#08,#08,#10,#20,#00
JapChr221:	DB	#00,#C0,#00,#08,#08,#10,#E0,#00
JapChr222:	DB	#90,#48,#00,#00,#00,#00,#00,#00
JapChr223:	DB	#60,#90,#60,#00,#00,#00,#00,#00
JapChr224:	DB	#20,#F8,#20,#4E,#40,#90,#8E,#00
JapChr225:	DB	#10,#FE,#20,#78,#04,#04,#78,#00
JapChr226:	DB	#00,#FC,#02,#02,#02,#04,#18,#00
JapChr227:	DB	#FE,#08,#10,#20,#20,#20,#1C,#00
JapChr228:	DB	#20,#24,#38,#60,#80,#80,#7C,#00
JapChr229:	DB	#2C,#F2,#44,#44,#9C,#26,#1C,#00
JapChr230:	DB	#00,#9E,#80,#80,#80,#90,#4E,#00
JapChr231:	DB	#48,#48,#7C,#D2,#B6,#AA,#4C,#00
JapChr232:	DB	#40,#4C,#D2,#62,#4E,#D2,#4E,#00
JapChr233:	DB	#00,#38,#54,#92,#A2,#A2,#44,#00
JapChr234:	DB	#04,#9E,#84,#84,#8C,#96,#4C,#00
JapChr235:	DB	#10,#E4,#26,#44,#44,#48,#30,#00
JapChr236:	DB	#20,#10,#00,#20,#14,#52,#B2,#00
JapChr237:	DB	#00,#00,#20,#50,#88,#04,#02,#00
JapChr238:	DB	#1E,#84,#9E,#84,#8C,#96,#4C,#00
JapChr239:	DB	#10,#FC,#10,#FC,#70,#98,#74,#00
JapChr240:	DB	#70,#10,#14,#7E,#A4,#A4,#48,#00
JapChr241:	DB	#20,#F4,#22,#60,#A2,#62,#1C,#00
JapChr242:	DB	#48,#48,#7C,#AA,#92,#A2,#44,#00
JapChr243:	DB	#20,#F8,#20,#F8,#20,#24,#18,#00
JapChr244:	DB	#48,#5C,#6A,#E2,#24,#10,#10,#00
JapChr245:	DB	#10,#9C,#B2,#D2,#92,#1C,#20,#00
JapChr246:	DB	#10,#1C,#10,#10,#78,#94,#70,#00
JapChr247:	DB	#60,#10,#80,#B8,#C4,#84,#38,#00
JapChr248:	DB	#08,#84,#84,#84,#44,#08,#30,#00
JapChr249:	DB	#78,#10,#38,#44,#B4,#4C,#38,#00
JapChr250:	DB	#20,#2C,#F4,#24,#64,#A4,#26,#00
JapChr251:	DB	#78,#10,#20,#78,#84,#04,#38,#00
JapChr252:	DB	#40,#40,#DC,#62,#42,#C2,#44,#00
JapChr253:	DB	#10,#10,#20,#20,#60,#52,#8C,#00
JapChr254:	DB	#00,#00,#00,#00,#00,#00,#00,#00
JapChr255:	DB	#00,#00,#00,#00,#00,#00,#00,#00
