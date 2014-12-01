; Internestor Suite installer for InterNestor Suite

;=============================

	;--- Instalador de Internestor Suite

	.label	20

;******************************
;***                        ***
;***   MACROS, CONSTANTES   ***
;***                        ***
;******************************

MODULOS:	equ	4	;4 en la version definitiva
ACTIVA_INT:	equ	1	;1 en la version definitiva

nesman:	macro	@f
	ld	c,@f
	ld	de,#2202
	call	#FFCA
	endm

print:	macro	@d
	ld	de,@d
	ld	c,_STROUT
	call	5
	endm

MOD_INIT:	equ	#8003
MOD_DEINIT:	equ	#8006


; Saltos relativos condicionados

jri:	macro	@a	;A = x
	jr	z,@a
	endm

jrni:	macro	@a	;A <> x
	jr	nz,@a
	endm

jrmn:	macro	@a	;A < x
	jr	c,@a
	endm

jrmy:	macro	@a	;A > x
	jr	z,$+4
	jr	nc,@a
	endm

jrmni:	macro	@a	;A <= x
	jr	c,@a
	jr	z,@a
	endm

jrmyi:	macro	@a	;A >= x
	jr	nc,@a
	endm

; Saltos absolutos condicionados

jpi:	macro	@a	;A = x
	jp	z,@a
	endm

jpni:	macro	@a	;A <> x
	jp	nz,@a
	endm

jpmn:	macro	@a	;A < x
	jp	c,@a
	endm

jpmy:	macro	@a	;A > x
	jr	z,$+5
	jp	nc,@a
	endm

jpmni:	macro	@a	;A <= x
	jr	c,@a
	jp	z,@a
	endm

jpmyi:	macro	@a	;A >=x
	jp	nc,@a
	endm

;Funciones del DOS

_STROUT:	equ	#09
_TERM:	equ	#62
_OPEN:	equ	#43
_CLOSE:	equ	#45
_READ:	equ	#48
_PARSE:	equ	#5B
_CHKCHR:	equ	#5D
_EXPLAIN:	equ	#66

ENASLT:	equ	#0024



;******************************
;***                        ***
;***   PROGRAMA PRINCIPAL   ***
;***                        ***
;******************************

	org	#100


;----------------------------------
;---  Comprobaciones iniciales  ---
;----------------------------------

	;--- Comprueba si hay parametros. Si no, muestra
	;    ayuda y termina

	print	PRESEN_S

	ld	a,1
	ld	de,BUFPAR
	call	EXTPAR
	jr	nc,HAYPARS

TERMINFO:	print	INFO_S
	jp	TERMOK2

HAYPARS:	ld	(NUMPARS),a

	;--- Comprueba que NestorMan este instalado, si no
	;    devuelve un error y termina

	xor	a
	nesman	1
	or	a
	jr	nz,OKNMAN1

	print	NONMAN_S	;Esta instalado?
	print	NEEDNMAN_S
	jp	TERMOK2

OKNMAN1:	ld	hl,#0201
	ex	de,hl
	call	COMP
	jr	c,OKNMAN2

	print	BADNMAN_S	;Es al menos version 1.2?
	print	NEEDNMAN_S
	jp	TERMOK2
OKNMAN2:	;

	;--- Obtiene rutinas del mapeador

	ld	de,#0402	;Obtiene rutinas del mapeador
	call	#FFCA
	ld	de,ALL_SEG
	ld	bc,#30
	ldir

	;--- Comprueba la opcion y salta a la rutina adecuada

	ld	a,(BUFPAR)
	or	%00100000
	cp	"i"
	jr	z,OPCION_I
	cp	"u"
	jp	z,OPCION_U
	cp	"p"
	jp	z,OPCION_P
	cp	"r"
	jp	z,OPCION_R
	cp	"s"
	jp	z,OPCION_S

OPDESC:	print	INVOPT_S
	jr	TERMINFO	;Opcion desconocida?


;---------------------
;---  Instalacion  ---
;---------------------

OPCION_I:	;

	;--- Primero comprueba si hay realmente 5 parametros

	ld	a,(NUMPARS)
	cp	MODULOS+1
	jr	z,OK5PARS

	print	INVPAR_S
	jp	TERMINFO
OK5PARS:	;

	;--- Primero comprueba que no este ya instalado

	nesman	32
	or	a
	jr	z,OKNOINS

	print	YAINS_S
	jp	TERMOK
OKNOINS:	;

	;--- Reserva la memoria

	nesman	30
	jr	nc,RESMEM_OK

	print	NOMEM_S
	jp	TERMOK
RESMEM_OK:	;

	nesman	32
	ld	(INS_SLOT),a
	ld	(LEV1_SEG),bc
	ld	(LEV3_SEG),de

	;--- Instala los modulos

	ld	a,(INS_SLOT)	;Primero conecta el slot en pag. 2
	ld	h,#80
	call	ENASLT

	ld	a,1
	ld	(CUR_MOD),a
	ld	hl,LEV1_SEG
	ld	(LEV_PNT),hl

	ld	b,MODULOS
INST_LOOP:	push	bc
	call	INST_MOD
	pop	bc
	jr	c,TERMERR
	djnz	INST_LOOP

	ld	a,(#F343)	;Instalacion completa
	ld	h,#80
	call	ENASLT
	print	COMPLETE_S

	if	ACTIVA_INT=1
	nesman	32	;Activa interrupcion
	ld	(ix),a
	endif

	jp	TERMOK

	;--- Error: libera memoria y recursos, y termina

TERMERR:	ld	hl,LEV1_SEG
	ld	b,MODULOS
TERM_LOOP:	push	hl,bc
	ld	a,(hl)
	nesman	3
	ld	a,c
	call	PUT_P2
	call	MOD_DEINIT
	pop	bc,hl
	inc	hl
	djnz	TERM_LOOP
	ld	a,(#F343)
	ld	h,#80
	call	ENASLT
	nesman	31
	print	ABORT_S
	jp	TERMOK


	;--- Instalacion de un modulo: lo lee del fichero
	;    y lo inicializa

	;Extrae nombre de fichero y
	;anyade extension si es necesario

INST_MOD:	ld	a,(CUR_MOD)	;Extrae nombre
	inc	a
	ld	de,BUFPAR
	call	EXTPAR

	ld	bc,_PARSE
	ld	de,BUFPAR
	call	5
	bit	4,b
	jr	nz,OKEXT	;Anyade extension si no la tiene
	ld	hl,INSEXT_S
	ld	bc,4
	ldir
OKEXT:	;

	ld	a,"$"
	ld	(de),a
	push	de

	ld	hl,BUFPAR
	ld	d,0
LOOP_UPCASE:	ld	a,(hl)	;Convierte el caracter a mayusculas
	or	a
	jr	z,END_UPCASE
	push	hl
	ld	e,a
	ld	c,_CHKCHR
	call	5
	pop	hl
	ld	(hl),e
	inc	hl
	jr	LOOP_UPCASE
END_UPCASE:	;

	ld	a,(CUR_MOD)	;Muestra "Installing..."
	add	"0"
	ld	(MODN_S),a
	print	MODINS_S
	print	BUFPAR
	print	PUNTOS_S
	pop	de
	xor	a
	ld	(de),a

	;Abre el fichero y termina si hay error

	ld	c,_OPEN
	ld	de,BUFPAR
	xor	a
	call	5
	jp	nz,ERROR_FILE

	ld	a,b
	ld	(FH),a

	;Lee la cabecera del fichero y comprueba si es correcta

	ld	c,_READ
	ld	a,(FH)
	ld	b,a
	ld	de,BUFPAR
	ld	hl,512	;Lee 512 bytes
	call	5
	jp	nz,ERROR_FILE

	xor	a
	ld	b,8
	ld	de,INESUIT_S	;Busca la cadena "INSEUITE"
	ld	hl,BUFPAR+#120
	call	INSTR
	ld	a,b
	or	a
	jr	nz,OKINESUIT
	print	ERRFIL_S
	print	NOINS_S
	jp	ERROR_CLOSE
OKINESUIT:	;

	print	MODNAMIS_S	;Imprime el nombre del modulo
	ld	ix,BUFPAR+#100
	ld	(ix+32),13
	ld	(ix+33),10
	ld	(ix+34),"$"
	print	BUFPAR+#100

	ld	a,(BUFPAR+#12B)	;Comprueba que el modulo es
	ld	b,a	;del nivel adecuado
	ld	a,(CUR_MOD)
	cp	b
	jr	z,OKMODNUM
	add	"0"
	ld	(MODN2_S),a
	print	ERRFIL_S
	print	BADMOD_S
	jp	ERROR_CLOSE
OKMODNUM:	;

	;Lee el fichero y lo copia a su segmento

	ld	a,(FH)
	ld	b,a
	ld	de,#4003	;Lee 16K hacia pagina 1 en TPA
	ld	hl,#4000-3
	ld	c,_READ
	call	5
	jr	nz,ERROR_FILE

	ld	hl,(LEV_PNT)
	ld	a,(hl)	;Copia el modulo a su segmento
	nesman	3
	ld	a,c
	call	PUT_P2
	ld	hl,#4003
	ld	de,#8003
	ld	bc,#4000-3
	ldir

	;Inicializa el modulo

	call	MOD_INIT
	jr	nc,OKMODINIT

	ld	de,BUFPAR	;Si hay error al inicializarlo,
	ld	bc,256	;lo muestra y termina
	ldir
	print	ERRINIT_S
	print	BUFPAR
	jr	ERROR_CLOSE
OKMODINIT:	;

	;Cierra el fichero y termina

	ld	a,(FH)
	ld	b,a
	ld	c,_CLOSE
	call	5

	ld	hl,CUR_MOD
	inc	(hl)
	ld	hl,(LEV_PNT)
	inc	hl
	ld	(LEV_PNT),hl

	print	MODOK_S
	or	a
	ret

	;Terminacion en caso de error A al leer el fichero

ERROR_FILE:	ld	b,a	;Obtiene cadena de error
	ld	de,BUFPAR	;y le anyade "$"
	ld	c,_EXPLAIN
	call	5
	ld	ix,BUFPAR-1
EXPL_LOOP:	inc	ix
	ld	a,(ix)
	or	a
	jr	nz,EXPL_LOOP
	ld	(ix),13
	ld	(ix+1),10
	ld	(ix+2),"$"

	print	ERRFIL_S
	print	BUFPAR

ERROR_CLOSE:	ld	a,(FH)
	or	a
	scf
	ret	z
	ld	c,_CLOSE
	ld	b,a
	call	5

	scf
	ret


;------------------------
;---  Desinstalacion  ---
;------------------------

OPCION_U:	;

	;--- Comprueba si esta instalado, si no, muestra error

	nesman	32
	or	a
	jr	nz,ESTAINS

	print	NOESTA_S
	jp	TERMOK
ESTAINS:	;

	;--- Deshabilita la interrupcion

	ld	(ix),0

	;--- Llama a la rutina de desinstalacion de todos los modulos

	push	af
	ld	a,1
	ld	(CUR_MOD),a
	pop	af
	ld	(INS_SLOT),a
	ld	(LEV1_SEG),bc
	ld	(LEV3_SEG),de

	ld	h,#80
	call	ENASLT
	ld	b,MODULOS
	ld	hl,LEV1_SEG
DEINS_LOOP:	push	hl,bc
	ld	a,(hl)
	nesman	3
	ld	a,c
	ld	iyh,a
	ld	ix,MOD_DEINIT
	call	CAL_SEG
	ld	a,(CUR_MOD)
	add	"0"
	ld	(MODN3_S),a
	print	MODDES_S
	ld	hl,CUR_MOD
	inc	(hl)
	pop	bc,hl
	inc	hl
	djnz	DEINS_LOOP

	ld	a,(#F343)
	ld	h,#80
	call	ENASLT

	;--- Libera los segmentos y termina

	nesman	31

	print	INSDEINS_S
	jp	TERMOK


;---------------
;---  Pausa  ---
;---------------

OPCION_P:	;

	;--- Comprueba si esta instalado, si no, muestra error

	nesman	32
	or	a
	jr	nz,ESTAINS3

	print	NOESTA_S
	jp	TERMOK
ESTAINS3:	;

	;--- Pausa y termina

	nesman	32
	ld	(ix),0
	print	PAUSED_S
	jp	TERMOK


;------------------
;---  Despausa  ---
;------------------

OPCION_R:	;

	;--- Comprueba si esta instalado, si no, muestra error

	nesman	32
	or	a
	jr	nz,ESTAINS2

	print	NOESTA_S
	jp	TERMOK
ESTAINS2:	;

	;--- Despausa y termina

	nesman	32
	ld	(ix),a
	print	RESUMED_S
	jp	TERMOK


;---------------------
;---  Informacion  ---
;---------------------

OPCION_S:	;

	;--- Comprueba si esta instalado, si no, lo dice y termina

	nesman	32
	or	a
	jr	nz,ESTAINS4

	print	NOESTA2_S
	jp	TERMOK
ESTAINS4:	;

	print	ISINS_S
	nesman	32
	ld	a,(ix)
	or	a
	ld	de,PAUSED2_S
	jr	z,OPF_2
	ld	de,ACTIVE_S
OPF_2:	ld	c,_STROUT
	call	5
	jp	TERMOK



;******************************
;***                        ***
;***   RUTINAS AUXILIARES   ***
;***                        ***
;******************************

;--- NOMBRE: COMP
;      Comparacion de HL con DE (16 bits en complemento a 2)
;    ENTRADA:   HL, DE = numeros a comparar
;    SALIDA:     C, NZ si HL > DE
;                C,  Z si HL = DE
;               NC, NZ si HL < DE
;    REGISTROS: -
;    VARIABLES: -
;    LLAMADAS:  -

COMP:	push	hl
	or	a
	sbc	hl,de
	pop	hl
	jp	p,HMAYD
HMEND:	scf
	ccf
	ret
HMAYD:	scf
	ret


;--- NOMBRE: EXTPAR
;      Extraccion de un parametro de la linea de comando
;    ENTRADA:   A  = Parametro a extraer (el primero es el 1)
;               DE = Buffer para dejar el parametro
;    SALIDA:    A  = Numero de parametros
;               CY = 1 -> No existe ese parametro
;                         B indefinido, buffer inalterado
;               CY = 0 -> B = Longitud del parametro (no incluye el 0)
;                         Parametro a partir de DE, acabado en 0
;    REGISTROS: -
;    LLAMADAS:  -
;    VARIABLES: Macros JR

EXTPAR:	or	a	;Volvemos con error si A = 0
	scf
	ret	z

	ld	b,a
	ld	a,(#80)	;Volvemos con error si no hay parametros  
	or	a
	scf
	ret	z
	ld	a,b

	push	hl,de,ix
	ld	ix,0	;IXl: Numero de parametros    
	ld	ixh,a	;IXh: Parametro a extraer    
	ld	hl,#81

PASASPC:	ld	a,(hl)	;Vamos pasando espacios    
	or	a
	jr	z,ENDPNUM
	cp	" "
	inc	hl
	jri	PASASPC

	inc	ix
PASAPAR:	ld	a,(hl)	;Vamos pasando el parametro    
	or	a
	jr	z,ENDPNUM
	cp	" "
	inc	hl
	jri	PASASPC
	jr	PASAPAR

ENDPNUM:	ld	a,ixh	;Error si se el parametro a extraer    
	cp	ixl	;es mayor que el numero de parametros    
	jrmy	EXTPERR	;existentes    

	ld	hl,#81
	ld	b,1	;B = parametro actual    
PASAP2:	ld	a,(hl)	;Pasamos espacios hasta dar    
	cp	" "	;con el siguiente parametro    
	inc	hl
	jri	PASAP2

	ld	a,ixh	;Si es el que buscamos lo extraemos.    
	cp	B	;Si no ...    
	jri	PUTINDE0

	inc	B
PASAP3:	ld	a,(hl)	;... lo pasamos y volvemos a PAPAP2    
	cp	" "
	inc	hl
	jrni	PASAP3
	jr	PASAP2

PUTINDE0:	ld	b,0
	dec	hl
PUTINDE:	inc	b
	ld	a,(hl)
	cp	" "
	jri	ENDPUT
	or	a
	jr	z,ENDPUT
	ld	(de),a	;Ponemos el parametro a partir de (DE)    
	inc	de
	inc	hl
	jr	PUTINDE

ENDPUT:	xor	a
	ld	(de),a
	dec	b

	ld	a,ixl
	or	a
	jr	FINEXTP
EXTPERR:	scf
FINEXTP:	pop	ix,de,hl
	ret

;--- Terminacion OK

TERMOK:	ld	a,(#F343)
	ld	h,#80
	call	ENASLT
	ld	a,1
	call	PUT_P2
TERMOK2:	ld	bc,#0062
	jp	5


;--- NOMBRE: INSTR
;      Busqueda de una cadena incluida en otra
;    ENTRADA:   HL = Inicio cadena principal
;               * A  = 0 -> DE = Inicio cadena buscada, acabada en #00
;                 A <> 0 -> A  = Caracter buscado
;               * B  = 0 -> C  = Caracter de terminacion de la cadena principal
;                 B <> 0 -> B  = Longitud de la cadena principal
;               * CY = 0 -> Distinguir mayusculas y minusculas
;                 CY = 1 -> No distinguir mayusculas y minusculas
;    SALIDA:    B  = 0 -> Cadena buscada no encontrada, HL inalterado
;               B <> 0 -> Cadena buscada encontrada:
;                         B  = Posicion en la cadena principal
;                         HL = Inicio cadena encontrada
;    REGISTROS: F
;    LLAMADAS:  -
;    VARIABLES: -

INSTR:	push	af
	jr	c,NOCASE
SICASE:	ld	a,#ff
	ld	(CASEFLAG),a	;CASEFLAG=0: Distingue may/min
	jr	INSTR0
NOCASE:	xor	a
	ld	(CASEFLAG),a	;CASEFLAG=#FF: No distingue
INSTR0:	pop	af

	or	a
	ld	(CHARA),a
	push	af
	ld	a,c
	push	af,ix,de,hl
CHKIFA:	jr	z,NOCHAR
CHARENA:	ld	de,CHARA+1	;Si hemos pasado un caracter en A 
	xor	a	;lo copiamos en nuestro propio bufer 
	ld	(de),a	;y lo buscamos en modo normal 
	dec	de

NOCHAR:	ld	a,b
	or	a
	jr	nz,BNOCERO
BCERO:	push	hl
	ld	b,-1
BUSFIN:	inc	b	;Si B=0, busca el caracter de terminacion 
	ld	a,(hl)	;y coloca en B la longitud de la cadena 
	inc	hl
	cp	c
	jr	nz,BUSFIN
	pop	hl

BNOCERO:	dec	de	;Mientras la comparacion entre (HL) e (IX 
	push	de
	inc	b	;sea positiva, se incrementa HL e IX y se 
	dec	hl
	ld	c,0

COMPA:	inc	hl
	inc	de
	inc	c
	ld	a,(de)
	or	a
	jr	z,FOUND
	call	COMPRUT	;cp      (hl)
	call	nz,RESETDE
	djnz	COMPA
	jr	NOTF

RESETDE:	pop	ix
	pop	de
	push	de
	push	ix
	ld	a,1
	cp	c
	ld	c,0
	ret	z
	dec	hl
	inc	b
	ret

FOUND:	pop	de	;C=numero de caracteres coincidentes+1 
	dec	c
	ld	b,0
	or	a
	sbc	hl,bc	;HL=principio de la cadena hallada 
	pop	de	;DE=principio de la cadena original 
	push	hl	;(pasado a la subrutina en HL) 
	sbc	hl,de
	ld	b,l	;L=principio respecto inicio 
	inc	b
ENDSTR:	pop	hl,de,ix,af
	ld	c,a
	pop	af
	ret

NOTF:	pop	de,hl
	ld	b,0
	push	hl
	jr	ENDSTR

COMPRUT:	push	af	;Compara A con (HL)
	ld	a,(CASEFLAG)	;Solo modifica las banderas
	inc	a	;Si CASENFLAG=#FF, modifica CY
	jr	z,COMPNOD	;aleatoriamente

COMPD:	pop	af	;Comparacion con distincion may/min
	cp	(hl)
	ret	z
CHKENYMAY:	cp	165	;Enye mayuscula
	jr	nz,CHKESMAY
	dec	a
	cp	(hl)
	ld	a,165
	ret
CHKESMAY:	cp	"A"
	jr	c,RETDIST
	cp	"Z"+1
	jr	c,ESMAY

CHKENYMIN:	cp	164	;Enye minuscula
	jr	nz,CHKESMIN
	inc	a
	cp	(hl)
	ld	a,164
	ret
CHKESMIN:	cp	"z"+1
	jr	nc,RETDIST
	cp	"a"
	jr	c,RETDIST
ESMIN:	and	%11011111	;Convertimos a may. y volvemos a comparar
	cp	(hl)
	ret
ESMAY:	or	%00100000	;Convertimos a min. y volvemos a comparar
	cp	(hl)
	ret

COMPNOD:	pop	af	;Comparacion sin distincion may/min
	cp	(hl)
	ret

RETDIST:	or	a	;Vuelve con Z=0
	ret	nz
	inc	a
	or	a
	ld	a,0
	ret

CASEFLAG:	db	0
CHARA:	db	0


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



;****************************
;***                      ***
;***   DATOS, VARIABLES   ***
;***                      ***
;****************************

PRESEN_S:	db	13,10,"InterNestor Suite installer 0.3",13,10
	db	"By Konami Man, 11-2001",13,10,10,"$"
INFO_S:	db	"Use:",13,10
	db	"* INSINS I <level 1 module file> <level 2 module file>",13,10
	db	"           <level 3 module file> <level 4 module file>",13,10
	db	"Installs InterNestor Suite. Default files extension is .INM",13,10,10
	db	"* INSINS U",13,10
	db	"Uninstalls InterNestor Suite",13,10,10
	db	"* INSINS P",13,10
	db	"Pauses InterNestor Suite (which stills installed but inactive)",13,10
	db	"Pause is achieved by dettaching modules from the timer interrupt hook",13,10,10
	db	"* INSINS R",13,10
	db	"Resumes InterNestor Suite after a pause",13,10,10
	db	"* INSINS S",13,10
	db	"Shows the current status of InterNestor Suite",13,10
	db	"(not installed, active or paused)",13,10,"$"

NONMAN_S:	db	"ERROR: NestorMan not installed!",13,10,"$"
BADNMAN_S:	db	"ERROR: Invalid NestorMan version!",13,10,"$"
NEEDNMAN_S:	db	"NestorMan version 1.21 or higher is needed.",13,10,"$"
INVOPT_S:	db	"ERROR: Invalid option!",13,10,10,"$"
YAINS_S:	db	"ERROR: InterNestor Suite is already installed!",13,10
	db	"To uninstall: INSINS /U",13,10,"$"
INVPAR_S:	db	"ERROR: Invalid parameters!",13,10,10,"$"
NOMEM_S:	db	"ERROR: Not enough memory to install InterNestor Suite!",13,10
	db	"4 free segments are required, all in the same mapper",13,10,"$"
MODINS_S:	db	"* Installing level "
MODN_S:	db	"0 module from file $"
PUNTOS_S:	db	"...",13,10,"$"
ABORT_S:	db	13,10,"Installation aborted!",13,10,"$"
COMPLETE_S:	db	13,10,"Installation complete!",13,10,"$"
ERRFIL_S:	db	"ERROR when reading file:",13,10,"*** $"
NOINS_S:	db	"Invalid file format - not a InterNestor Suite module.",13,10,"$"
BADMOD_S:	db	"Invalid module level - not a level "
MODN2_S:	db	"0 module file.",13,10,"$"
MODNAMIS_S:	db	"Header OK, Module name is: $"
MODOK_S:	db	"Module installed OK.",13,10,10,"$"
NOESTA_S:	db	"ERROR: InterNestor Suite is not installed currently.",13,10,"$"
NOESTA2_S:	db	"InterNestor Suite is not installed currently.",13,10,"$"
INSDEINS_S:	db	13,10,"InterNestor Suite has been uninstalled.",13,10,"$"
PAUSED_S:	db	"InterNestor Suite paused - stills installed but inactive.",13,10,"$"
	db	"To resume: INSINS /R",13,10,"$"
RESUMED_S:	db	"InterNestor Suite resumed - now it is active again.",13,10,"$"
ERRINIT_S:	db	"ERROR when initializing module:",13,10,"*** $"
ISINS_S:	db	"InterNestor Suite is currently installed and $"
ACTIVE_S:	db	"ACTIVE.",13,10,"$"
PAUSED2_S:	db	"PAUSED.",13,10,"$"
MODDES_S:	db	"Level "
MODN3_S:	db	"0 module uninstalled",13,10,"$"

INSEXT_S:	db	".INM"
INESUIT_S:	db	"INESUITE",0

NUMPARS:	db	0
CUR_MOD:	db	0
LEV_PNT:	dw	0
INS_SLOT:	db	0
LEV1_SEG:	db	0
LEV2_SEG:	db	0
LEV3_SEG:	db	0
LEV4_SEG:	db	0
FH:	db	0

BUFPAR:	;
