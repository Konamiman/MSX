;A set of routines to manage mapped memory,
;they give an unified interface for both DOS 1 and DOS 2.

;==================================

	;--- RUTINAS PARA MANEJAR LA MEMORIA MAPEADA
	;    Compatibles DOS 1 y DOS 2 
	;    Por Konami Man, 3-97 

; Longitud rutinas de inicializacion: 650 bytes
; Longitud rutinas de gestion de memoria: 678 bytes
; Longitud tabla de segmentos logicos: MAXSEGS * 2

;-----===== MACROS Y CONSTANTES =====-----

;--- Parametros definibles por el usuario

MINSEGS:	equ	8	;Numero minimo de segmentos necesarios
;                                   ;incluyendo los cuatro primeros
MAXSEGS:	equ	#FF	;Numero maximo de segmentos a reservar
;                                   ;incluyendo los cuatro primeros (5-255)
TESTDIR:	equ	#C002	;Bufer de 256 bytes para el test
;                                   ;de memoria DOS 1
;                                   ;NO puede contener estas direcciones:
;                                   ;#0001, #4001, #8000-#BFFF, #C001

;--- Variables/rutinas del sistema

EXPTBL:	equ	#FCC1
ENASLT:	equ	#0024


;-----===== VARIABLES Y ZONAS DE DATOS =====-----

	org	#100
	jp	INICIO	;Preubas

PRIMAP:	db	0	;Slot del mapeador primario
SL_1:	db	0	;Segmento logico conectado a la pagina 1
SLOT_1:	db	0
SEG_1:	db	0
SL_2:	db	0	;Segmento logico conectado a la pagina 2
SLOT_2:	db	0
SEG_2:	db	0
NUMSEGS:	db	0	;Numero de segmentos disponibles
TABSEGS:	ds	MAXSEGS*2	;Parejas slot + segmento


;-----===== DIRECTORIO DE RUTINAS =====-----

;--- Rutinas auxiliares

;GET_Pn:  Obtiene el segmento fisico conectado a la pagina n (0 a 3)
;GET_PH:  Obtiene el segmento fisico conectado a la pagina que contiene
;         la direccion indicada en HL
;PUT_Pn:  Conecta un segmento fisico a la pagina n (0 a 3)
;PUT_PH:  Conecta un segmento fisico a la pagina que contiene la direccion HL
;GET_SF:  Obtiene el slot y el segmento fisico de un segmento logico

;--- Rutinas de usuario

;INITLOG:  Reserva la memoria e inicializa la zona de datos.
;          Solo se debe ejecutar una vez.
;FREESEG:  Libera la memoria reservada (en DOS 1 no hace nada).
;          Se debe ejecutar antes de terminar el programa, a no ser que
;          INITLOG devuelva un error.
;GET_SLT:  Obtiene el slot conectado a la pagina 1 o 2
;PUT_SL1:  Conexion de un segmento logico en la pagina 1
;PUT_SL2:  Conexion de un segmento logico en la pagina 2
;CALL_DB:  Llamada a una subrutina en otro segmento logico (formato DB)
;CALL_LS:  Llamada a una subrutina en otro segmento logico
;READ_SL:  Lectura de un dato en un segmento logico
;WRITE_SL: Escritura de un dato en un sgmento logico
;LDIRSS:   Transfiere un bloque entre dos segmentos logicos


;-----===== RUTINAS DE MANEJO DE SEGMENTOS FISICOS =====-----

;--- Rutinas para establecer segmentos fisicos.
;    En DOS 2 se usan las rutinas del DOS en lugar de estas.

PUT_PH:	PUSH	AF	;Conecta el segmento A en la pagina que
	LD	A,H	;contiene la direccion HL.
	RLA		;El slot del mapeador ha de estar
	RLA		;conectado en la pagina correspondiente.
	RLA		;No modifica ningun registro.
	AND	%00000011
	CP	1
	JR	Z,PP1
	CP	2
	JR	Z,PP2
	CP	3
	JR	Z,PP3
PP0:	POP	AF
	JP	PUT_P0
PP1:	POP	AF
	JP	PUT_P1
PP2:	POP	AF
	JP	PUT_P2
PP3:	POP	AF
	JP	PUT_P3

GET_PH:	PUSH	AF	;Devuelve en A el segmento conectado
	LD	A,H	;a la pagina que contiene la direccion
	RLA		;indicada en HL.
	RLA		;No modifica ningun registro excepto A.
	RLA
	AND	%00000011
	CP	1
	JR	Z,GP1
	CP	2
	JR	Z,GP2
	CP	3
	JR	Z,GP3
GP0:	POP	AF
	JP	GET_P0
GP1:	POP	AF
	JP	GET_P1
GP2:	POP	AF
	JP	GET_P2
GP3:	POP	AF
	JP	GET_P3

PUT_P0:	LD	(GUARDAP0),A	;Conecta el segmento A en la pagina 0.
	OUT	(#FC),A	;El slot del mapeador ha de estar conectado.
	RET		;No modifica ningun registro.

PUT_P1:	LD	(GUARDAP1),A	;Idem para la pagina 1
	OUT	(#FD),A
	RET

PUT_P2:	LD	(GUARDAP2),A	;Idem para la pagina 2
	OUT	(#FE),A
	RET

PUT_P3:	RET		;No se puede cambiar la pagina 3
	DW	0

GET_P0:	LD	A,(GUARDAP0)	;Devuelve en A el segmento conectado
	RET		;en la pagina 0. No modifica registros.

GET_P1:	LD	A,(GUARDAP1)	;Idem para la pagina 1
	RET

GET_P2:	LD	A,(GUARDAP2)	;Idem para la pagina 2
	RET

GET_P3:	LD	A,(GUARDAP3)	;Idem para la pagina 3
	RET

;--- Paginas conectadas (usado en DOS 1)

GUARDAP3:	DB	0
GUARDAP2:	DB	1
GUARDAP1:	DB	2
GUARDAP0:	DB	3


;-----===== RUTINAS DE MANEJO DE SEGMENTOS LOGICOS =====-----

;--- NOMBRE: FREESEG
;      Libera la memoria reservada
;    ENTRADA:   -
;    SALIDA:    -
;    REGISTROS: Todos
;    LLAMADAS:  -
;    VARIABLES: TABSEGS, NUMSEGS

FREESEG:	ld	de,#0402	;No hace nada si DOS 1
	xor	a
	call	#FFCA
	or	a
	ret	z

	inc	hl	;Copia el salto a FRE_SEG
	inc	hl
	inc	hl
	ld	de,FRE_SEG
	ld	bc,3
	ldir

	ld	ix,TABSEGS+8
	ld	a,(NUMSEGS)
	cp	5
	ret	c	;Termina si no hay mas de 4 segmentos
	sub	4	;resevados
	ld	b,a
BUCFRE:	push	bc
	ld	b,(ix)
	ld	a,(ix+1)
	call	FRE_SEG
	inc	ix
	inc	ix
	pop	bc
	djnz	BUCFRE

	ld	a,4	;Ahora solo estan disponibles los
	ld	(NUMSEGS),a	;cuatro primeros segmentos
	ret

FRE_SEG:	scf
	ret
	nop


;--- NOMBRE: GET_SF
;      Obtiene el segmento fisico y el slot
;      correspondientes a un segmento logico
;    ENTRADA:   A = Segmento logico
;    SALIDA:    A = Segmento fisico
;               B = Slot (#FF -> Segmento logico inexistente)
;    REGISTROS: AF, B
;    LLAMADAS:  -
;    VARIABLES: NUMSEGS, TABSEGS

GET_SF:	ld	b,a	;Error si el segmento logico no existe
	ld	a,(NUMSEGS)
	dec	b
	cp	a
	ld	a,b
	ld	b,#FF
	ret	c
	inc	a

	push	hl,bc
	ld	c,a	;Obtiene segmento fisico correspondiente 
	ld	b,0	;a un segmento logico 
	sla	c	;Entrada: A=segmento logico 
	rl	b	;Salida: A=segmento fisico, B=slot 
	ld	hl,TABSEGS	;Modifica AF y B
	add	hl,bc
	ld	a,(hl)
	ld	b,a
	inc	hl
	ld	a,(hl)

	pop	hl	;Recupera C
	ld	c,l
	pop	hl
	ret


;--- NOMBRE: GET_SLT
;      Obtiene el slot conectado a la pagina 1 o 2
;    ENTRADA:   A  = Pagina (1 o 2)
;    SALIDA:    B  = Slot
;    REGISTROS: F, C
;    LLAMADAS:  -
;    VARIABLES: EXPTBL

GET_SLT:	and	%11
	ld	(PG1O2),a
	push	hl
	in	a,(#a8)
	rrca
	rrca
	ld	b,a
	ld	a,(PG1O2)
	cp	1
	ld	a,b
	jr	z,GSLTOK1
	rrca
	rrca

GSLTOK1:	and	%11
	ld	c,a
	ld	b,0
	ld	hl,#FCC1
	add	hl,bc
	ld	a,(hl)
	and	#80
	or	c
	ld	c,a
	inc	hl
	inc	hl
	inc	hl
	inc	hl

	ld	a,(PG1O2)
	cp	1
	ld	a,(hl)
	jr	z,GSLTP1
GSLTP2:	and	%110000
	rrca
	rrca
	jr	GSLTOK2
GSLTP1:	and	%1100
GSLTOK2:	or	c
	ld	b,a
	pop	hl
	ret

PG1O2:	db	0


;--- NOMBRE: PUT_SL1
;      Conecta un segmento logico en la pagina 1
;      Inhabilita las interrupciones
;    ENTRADA:   A  =  Segmento logico
;    SALIDA:    A  =  0  -> Segmento logico conectado
;               A  = #FF -> Segmento logico inexistente
;    REGISTROS: AF, BC, DE, HL
;    LLAMADAS:  GET_SF, ENASLT, PUT_P1
;    VARIABLES: SL_1, SLOT_1, SEG_1

PUT_SL1:	di
	ld	(TEMPSL1),a
	call	GET_SF
	ld	c,a	;C = Segmento fisico
	ld	a,b	;B = Slot
	cp	#FF
	ret	z

	ld	hl,SLOT_1
	cp	(hl)
	jr	z,OKPSL1
	ld	h,#40
	push	ix,iy,bc	;Conecta el slot solo si
	call	ENASLT	;no esta conectado ya
	pop	bc,iy,ix

OKPSL1:	ld	a,c	;Actualiza la zona de datos
	call	PUT_P1
	ld	a,(TEMPSL1)
	ld	(SL_1),a
	ld	a,b
	ld	(SLOT_1),a
	ld	a,c
	ld	(SEG_1),a
	xor	a
	ret

TEMPSL1:	db	0


;--- NOMBRE: PUT_SL2
;      Conecta un segmento logico en la pagina 2
;      Inhabilita las interrupciones
;    ENTRADA:   A  =  Segmento logico
;    SALIDA:    A  =  0  -> Segmento logico conectado
;               A  = #FF -> Segmento logico inexistente
;    REGISTROS: AF, BC, DE, HL
;    LLAMADAS:  GET_SF, ENASLT, PUT_P1
;    VARIABLES: SL_2, SLOT_2, SEG_2

PUT_SL2:	di
	ld	(TEMPSL2),a
	call	GET_SF
	ld	c,a	;C = Segmento fisico 
	ld	a,b	;B = Slot 
	cp	#FF
	ret	z

	ld	hl,SLOT_2
	cp	(hl)
	jr	z,OKPSL2
	ld	h,#80
	push	ix,iy,bc	;Conecta el slot solo si 
	call	ENASLT	;no esta conectado ya 
	pop	bc,iy,ix

OKPSL2:	ld	a,c	;Actualiza la zona de datos
	call	PUT_P2
	ld	a,(TEMPSL2)
	ld	(SL_2),a
	ld	a,b
	ld	(SLOT_2),a
	ld	a,c
	ld	(SEG_2),a
	xor	a
	ret

TEMPSL2:	db	0


;--- NOMBRE: CALL_DB
;      Ejecuta una subrutina en un segmento logico
;      Inhabilita las interrupciones
;      La llamada se debe ejecutar asi:
;         call CALL_DB
;         db   <segmento logico>
;         dw   <direccion> (#4000-#BFFF)
;    ENTRADA:   AF, BC, DE, HL = Parametros para la rutina
;    SALIDA:    AF, BC, DE, HL, IX, IY devueltos por la rutina
;    REGISTROS: Los alternativos y los que la rutina modifique
;    LLAMADAS:  CALL_SL
;    VARIABLES: -

CALL_DB:	di
	ld	iyl,a
	ex	(sp),hl
	ld	a,(hl)
	ld	iyh,a
	inc	hl
	ld	a,(hl)
	ld	ixl,a
	inc	hl
	ld	a,(hl)
	ld	ixh,a
	ld	a,iyl
	inc	hl
	ex	(sp),hl
	jp	CALL_SL


;--- NOMBRE: CALL_SL
;      Ejecuta una subrutina en un segmento logico
;      Inhabilita las interrupciones
;    ENTRADA:   IYh = Segmento logico
;               IX  = Direccion (#4000-#BFFF)
;               AF, BC, DE, HL = Parametros para la rutina
;    SALIDA:    AF, BC, DE, HL, IX, IY = Parametros devueltos por la rutina
;    REGISTROS: Los alternativos y los que la rutina modifique
;    LLAMADAS:  GET_SLT, PUT_SL1, PUT_SL2, ENASLT
;    VARIABLES: SL_1, SL_2

CALL_SL:	di
	push	af
	ld	a,ixh
	and	128
	jr	z,LLAMA1
LLAMA2:	pop	af
	jp	CALL_SL2
LLAMA1:	pop	af
	jp	CALL_SL1

CALL_SL1:	ld	iyl,a	;IYl = Parametro en A
	ld	a,(SL_1)
	push	af	;Guardamos segmento logico actual pag. 1  

	ld	a,iyh	;A = Segmento logico  
	push	af,hl,de,bc
	call	PUT_SL1
	pop	bc,de,hl,af
	ld	a,iyl	;A = Parametro original  
	call	CALLIX	;Llama a la subrutina en IX  

	ld	(SVHLCL),hl
	ld	l,a
	ex	(sp),hl
	ld	a,h	;A = Segmento logico original  

	push	af,bc,de,hl
	call	PUT_SL1	;Reponemos segmento logico original
	pop	hl,de,bc,af

	ex	(sp),hl
	ld	a,l
	ld	hl,(SVHLCL)
	inc	sp
	inc	sp
	ret

CALL_SL2:	ld	iyl,a	;IYl = Parametro en A
	ld	a,(SL_2)
	push	af	;Guardamos segmento logico actual pag. 1 

	ld	a,iyh	;A = Segmento logico 
	push	af,hl,de,bc
	call	PUT_SL2
	pop	bc,de,hl,af
	ld	a,iyl	;A = Parametro original 
	call	CALLIX	;Llama a la subrutina en IX 

	ld	(SVHLCL),hl
	ld	l,a
	ex	(sp),hl
	ld	a,h	;A = Segmento logico original 

	push	af,bc,de,hl
	call	PUT_SL2	;Reponemos segmento logico original
	pop	hl,de,bc,af

	ex	(sp),hl
	ld	a,l
	ld	hl,(SVHLCL)
	inc	sp
	inc	sp
	ret

CALLIX:	jp	(ix)
SVHLCL:	dw	0


;--- NOMBRE: READ_SL
;      Lee un dato de un segmento logico
;      Inhabilita las interrupciones
;    ENTRADA:   A  = Segmento logico
;               HL = Direccion (0-#3FFF)
;    SALIDA:    A  = Dato
;    REGISTROS: F
;    LLAMADAS:  PUT_SL1
;    VARIABLES: OR_SL1

READ_SL:	di
	push	de,bc,hl,af
	ld	a,(SL_2)
	ld	(OR_SL2),a	;Guardamos segmento logico original
	pop	af

	call	PUT_SL2
	pop	hl
	push	hl
	ld	a,h
	and	%00111111
	or	%10000000
	ld	h,a
	ld	a,(hl)

	push	af
	ld	a,(OR_SL2)
	call	PUT_SL2
	pop	af
	pop	hl,de,bc
	ret

OR_SL2:	db	0


;--- NOMBRE: WRITE_SL
;      Lee un dato de un segmento logico
;      Inhabilita las interrupciones
;    ENTRADA:   A  = Segmento logico
;               E  = Dato
;               HL = Direccion (0-#3FFF)
;    SALIDA:    A  = Dato
;    REGISTROS: F
;    LLAMADAS:  PUT_SL1
;    VARIABLES: OR_SL2

WRITE_SL:	di
	push	de,bc,hl,af
	ld	a,(SL_2)
	ld	(OR_SL2),a	;Guardamos segmento logico original
	pop	af

	push	de
	call	PUT_SL2
	pop	de
	pop	hl
	push	hl
	ld	a,h
	and	%00111111
	or	%10000000
	ld	h,a
	ld	(hl),e

	ld	h,a
	ld	a,(OR_SL2)
	call	PUT_SL2
	ld	a,h
	pop	hl,de,bc
	ret


;--- NOMBRE: LDIRSS
;      Realiza una transferencia de un segmento logico a otro
;      Inhabilita las interrupciones
;    ENTRADA:    IXh = Segmento logico fuente
;                IXl = Segmento logico destino
;                HL  = Direccion origen (0..#3FFF)
;                DE  = Direccion destino (0..#3FFF)
;                BC  = Longitud (0..#3FFF)
;     SALIDA:    A   = 0 -> Transferencia realizada
;                A  <> 0 -> Uno de los segmentos logicos no existe
;     REGISTROS: AF, BC, DE, HL
;     LLAMADAS:  PUT_S1, PUT_S2
;     VARIABLES: NUMSEGS

LDIRSS:	di
	ld	a,(SL_1)	;Guardamos segmentos logicos actuales
	ld	(GUSL_1),a
	ld	a,(SL_2)
	ld	(GUSL_2),a

	ld	a,ixh	;Error si alguno de los segmentos
	push	hl	;no existe
	ld	hl,NUMSEGS
	cp	(hl)
	pop	hl
	ld	a,#FF
	ret	nc

	ld	a,ixh
	push	hl
	ld	hl,NUMSEGS
	cp	(hl)
	pop	hl
	ld	a,#FF
	ret	nc

	ld	a,h	;Transformamos HL y DE a
	and	%00111111	;direcciones de las paginas 1 y 2
	or	%01000000
	ld	h,a
	ld	a,d
	and	%00111111
	or	%10000000
	ld	d,a

	push	bc,de,hl	;Conectamos las paginas y realizamos
	ld	a,ixh	;la transferencia
	call	PUT_SL1
	ld	a,ixl
	call	PUT_SL2
	pop	hl,de,bc
	ldir

	ld	a,(GUSL_1)	;Reponemos los segmentos originales
	call	PUT_SL1	;y volvemos
	ld	a,(GUSL_2)
	call	PUT_SL2
	xor	a
	ret

GUSL_1:	db	0
GUSL_2:	db	0


;-----===== RUTINAS DE INICIALIZACION DE LA MEMORIA =====-----
;   (a ejecutar solo una vez mediante una llamada a INITLOG)

;--- PRUEBA: Comprueba la memoria y termina

INICIO:	ld	a,(7)
	cp	#C8	;Exigimos 50K de TPA
	ld	c,9
	ld	de,ERROR1
	jp	c,5

	call	INITLOG	;Esta es la unica llamada a realizar
	cp	1	;para inicializarlo todo
	ld	c,9
	ld	de,ERROR2
	jp	z,5
	cp	2
	ld	de,ERROR3
	jp	z,5
	cp	3
	ld	de,ERROR4
	jp	z,5
	ld	de,BENNE
	call	5	;Aqui ponemos el inicio del mundo
	jp	FREESEG

ERROR1:	db	"ERROR: TPA insuficiente !!",13,10,"$"
ERROR2:	db	"ERROR: Memoria insuficiente !!",13,10,"$"
ERROR3:	db	"ERROR: Memoria libre insuficiente !!",13,10,"$"
ERROR4:	db	"ERROR: Memoria no mapeada !!",13,10,"$"
BENNE:	db	"Que maravillosas son las flores del campo !!",13,10,"$"


;--- Rutina de inicializacion (gestion de segmentos fisicos)
;    Esta rutina inicializa las rutinas de acceso a la memoria mapeada
;    de forma que pueden usarse igualmente en DOS 1 y DOS 2
;    ALL_SEG, FRE_SEG, RD_SEG, WR_SEG, CAL_SEG, CALLS, PUT_PH, GET_PH,
;    PUT_PN y GET_PN.
;    Modifica AF, BC, DE y HL.

INITFIS:	xor	a
	LD	DE,#0402
	CALL	#FFCA
	or	a
	ret	z

	push	ix
	ld	ix,RUTS	;Copia la tabla de salto DOS 2 
	ld	bc,18
	add	hl,bc	;Nos saltamos las 6 primeras rutinas 

	ld	b,16
COPRUT:	push	bc
	ld	e,(ix)
	ld	d,(ix+1)
	ld	bc,3
	ldir
	inc	ix
	inc	ix
	pop	bc
	djnz	COPRUT
	pop	ix
	ret

RUTS:	dw	PUT_PH,GET_PH,PUT_P0,GET_P0,PUT_P1,GET_P1
	dw	PUT_P2,GET_P2,PUT_P3,GET_P3


;--- NOMBRE: INITLOG
;      - Reserva todos los segmentos disponibles, hasta un total de MAXSEGS,
;        devolviendo error si no hay al menos MINSEGS segmentos disponibles
;        Para el test de memoria, usa como bufer TESTDIR
;      - Establece NUMSEGS y PRIMAP, y rellena TABSEGS
;      - Ejecuta INITFIS
;    ENTRADA:   -
;    SALIDA:    A =  0  -> Segmentos reservados
;               A =  1  -> No hay suficiente memoria (DOS 1)
;               A =  2  -> No hay suficientes segmentos libres (DOS 2)
;               A =  3  -> La memoria no esta mapeada (es raro pero puede pasar)
;    REGISTROS: Todos los que puede, y porque no hay mas...
;    LAMADAS:   INITFIS, MEMTEST1, MEMTEST2
;    VARIABLES: TESTDIR, EXPTBL, ENASLT y toda la zona de datos

INITLOG:	call	INITFIS
	xor	a
	ld	(NUMSEGS),a	;Limpiamos tabla de segmentos 
	ld	hl,TABSEGS
	ld	de,TABSEGS+1
	xor	a
	ld	(hl),a
	ld	bc,MAXSEGS*2-1
	ldir
	call	MEMTEST2
	or	a
	jp	z,RESERV1	;Reserva memoria en modo DOS 1

;--- Reserva de segmentos: version DOS 2 -----

RESERV2:	inc	bc	;Anyadimos los cuatro primeros segmentos 
	inc	bc	;a la lista de idems libres 
	inc	bc
	inc	bc

	ld	a,b
	or	a
	jr	nz,SOBRAN	;Si hay mas de 255 segmentos, sobran 

	ld	a,c
	cp	MINSEGS
	ld	a,2
	ret	c	;Si hay menos de MINSEGS, volvemos con error 

	ld	a,c
	cp	MAXSEGS	;Si hay mas de MAXSEGS+1 o MAXSEGS+1, 
	jr	nc,SOBRAN	;sobran 

BASTAN:	ld	(NUMSEGS),a	;NUMSEGS = Numero de segmentos encontrados, 
	jr	OKSEGS1	;o MAXSEGS si hay mas 
SOBRAN:	ld	a,MAXSEGS
	jr	BASTAN

OKSEGS1:	ld	de,#0402	;Cogemos ALL_SEG
	call	#FFCA
	ld	a,b
	ld	(PRIMAP),a	;Slot del mapeador primario 
	ld	de,ALL_SEG
	ld	bc,3
	ldir

	call	RES4PRIM
	ld	a,(NUMSEGS)
	sub	4	;A = Numero de segmentos a reservar   
	ld	b,a

RESBUC2:	push	bc	;Bucle de reserva de los segmentos 
	ld	a,(PRIMAP)
	and	%10001111
	or	%00100000
	ld	b,a
	xor	a
	call	ALL_SEG
	ld	(ix),b
	ld	(ix+1),a
	inc	ix
	inc	ix
	pop	bc
	djnz	RESBUC2

ENDRESV:	ld	ix,TABSEGS	;Actualiza la zona de datos 
	ld	a,(ix+2)
	ld	(SLOT_1),a
	ld	a,(ix+3)
	ld	(SEG_1),a
	ld	a,(ix+4)
	ld	(SLOT_2),a
	ld	a,(ix+5)
	ld	(SEG_2),a
	ld	a,1
	ld	(SL_1),a
	ld	a,2
	ld	(SL_2),a

	xor	a	;Finalizacion sin error 
	ret

;--- Reserva de segmentos: version DOS 1 -----

RESERV1:	ld	hl,TABSEGS
	ld	de,MAXSEGS*2-2
	add	hl,de
	ld	a,#FF	;Ponemos #FF en el espacio para el slot 
	ld	(hl),a	;del ultimo segmento a reservar 
	ld	(ESTESLT),a

	call	RES4PRIM	;Reservamos los cuatro primeros segmentos 
	ld	a,4
	ld	iy,NUMSEGS	;IY = no. de segmentos ya reservados 
	ld	(iy),4

	ld	de,TESTDIR
	call	MEMTEST1
	cp	1
	ld	b,a
	ld	a,3
	ret	z	;Error si la memoria no esta mapeada 
	ld	a,b	;A = No. de segmentos del mapeador primario 

	sub	4	;B = No. de segmentos a colocar en la tabla 
	ld	b,a
	ld	c,4
BUCRES1:	ld	a,(ix)
	push	af
	ld	a,(#F342)
	ld	(ix),a	;Rellena la tabla 
	ld	(ix+1),c
	inc	ix
	inc	ix
	inc	(iy)	;Incrementa no. de segmentos reservados 
	pop	af
	cp	#FF
	jr	z,FINRES1	;Termina si ya se han reservado todos 
	inc	c	;los necesarios 
	djnz	BUCRES1

MASLOTS:	call	SIGSLOT	;Ahora reserva en los siguientes slots 
	ld	c,a
	cp	#FF
	ld	a,0
	jr	z,FINRES1
	ld	a,(#F342)
	cp	c
	jr	z,MASLOTS	;Para no volver a reservar en el primario 

	push	ix,iy	;Conecta el slot en la pagina 2 
	ld	a,c
	ld	h,#80
	call	ENASLT
	pop	iy,ix

	ld	de,TESTDIR
	call	MEMTEST1
	ld	b,a
	or	a
	jr	z,MASLOTS	;Si no es RAM o no esta mapeada, 
	cp	1	;pasamos al siguiente slot. 
	jr	z,MASLOTS
	ld	a,c

	ld	c,0
BUCRES2:	ld	a,(ix)
	push	af
	ld	a,(ESTESLT)
	ld	(ix),a	;Rellena la tabla  
	ld	(ix+1),c
	inc	ix
	inc	ix
	inc	(iy)	;Incrementa no. de segmentos reservados  
	pop	af
	cp	#FF
	ld	a,0	;Termina si ya se han reservado todos  
	jr	z,FINRES1	;los necesarios 
	inc	c
	djnz	BUCRES2

	jr	MASLOTS

FINRES1:	ld	a,(#F342)	;Restauramos slot original pagina 2 
	ld	(PRIMAP),a
	ld	h,#80
	call	ENASLT
	ld	a,(NUMSEGS)	;Cuando ya hemos examinado todos los 
	cp	MINSEGS	;mapeadores, volvemos con error 
	ld	a,1	;si no hay tanta memoria como queriamos. 
	ret	c
	jp	ENDRESV	;Termina actualizando zona de datos 

;--- Subrutina RES4PRIM

RES4PRIM:	ld	ix,TABSEGS	;Coloca los datos de los cuatro 
	ld	a,(#f341)	;segmentos basicos en la tabla 
	ld	(ix),a
	call	GET_P0
	ld	(ix+1),a
	ld	a,(#f342)
	ld	(ix+2),a
	call	GET_P1
	ld	(ix+3),a
	ld	a,(#f343)
	ld	(ix+4),a
	call	GET_P2
	ld	(ix+5),a
	ld	a,(#f344)
	ld	(ix+6),a
	call	GET_P3
	ld	(ix+7),a
	ld	bc,8
	add	ix,bc	;IX = Tabla de segmentos a reservar  
	ret

;--- Subrutina SIGSLOT

SIGSLOT:	ld	a,(ESTESLT)	;Devuelve el siguiente slot, empezando 
	cp	#FF	;por el 0. Si no quedan mas, devuelve #FF. 
	jr	nz,SIGSL1	;Modifica AF, BC, HL. 
	ld	a,(EXPTBL)
	and	%10000000
	ld	(ESTESLT),a
	ret

SIGSL1:	ld	a,(ESTESLT)
	cp	%10001111
	jr	z,NOMASLT
	cp	%00000011
	jr	z,NOMASLT
	bit	7,a
	jr	nz,SLTEXP

SLTSIMP:	and	%00000011
	inc	a
	ld	c,a
	ld	b,0
	ld	hl,EXPTBL
	add	hl,bc
	ld	a,(hl)
	and	%10000000
	or	c
	ld	(ESTESLT),a
	ret

SLTEXP:	ld	c,a
	and	%00001100
	cp	%00001100
	ld	a,c
	jr	z,SLTSIMP
	add	%00000100
	ld	(ESTESLT),a
	ret

NOMASLT:	ld	a,#FF
	ret

ESTESLT:	db	#FF

ALL_SEG:	scf
	ret
	nop


;--- Test de memoria directo (DOS 1)
;    ENTRADA:   DE = Bufer de 256 bytes que NO puede estar en la pagina 2
;                    ni puede contener la direccion #4001
;                    El mapeador ha de estar conectado en la pagina 2
;    SALIDA:    A  = Numero de segmentos
;                    0 -> El slot no contiene RAM
;                    1 -> El slot contiene RAM no mapeada
;    LLAMADAS:  GET_P2, PUT_P2
;    REGISTROS: F, HL, BC, DE

MEMTEST1:	ld	a,(#8001)	;Comprobamos si es ROM   
	ld	h,a
	cpl
	ld	(#8001),a
	ld	a,(#8001)
	cpl
	ld	(#8001),a
	cpl
	cp	h
	ld	a,0
	ret	z

	ld	hl,#8001
	call	GET_P2
	push	af	;A  = Segmento actual en pagina 2   
	push	de	;DE = Bufer   
	ld	b,0

MT1BUC1:	ld	a,b	;Grabamos el primer byte de todas los   
	call	PUT_P2	;segmentos   
	ld	a,(hl)
	ld	(de),a
	ld	a,b
	ld	(hl),a
	inc	de
	inc	b
	ld	a,b
	cp	0
	jr	nz,MT1BUC1

	call	PUT_P2
	ld	a,(hl)
	neg
	ld	(NUMSGS),a	;A = Numero de segmentos encontrados  
	ld	b,0	;    (0 para 256)   
	ld	c,a
	pop	de

MT1BUC2:	ld	a,b
	call	PUT_P2	;Restauramos el primer byte de   
	ld	a,(de)	;todos los segmentos   
	ld	(hl),a
	inc	de
	inc	b
	ld	a,b
	cp	c
	jr	nz,MT1BUC2

	pop	af	;Restauramos segmento original   
	call	PUT_P2
	ld	a,(NUMSGS)
	cp	1
	jr	z,NOMAP1
	or	a
	ret	nz
	ld	a,#FF
	ret
NOMAP1:	xor	a
	ret

NUMSGS:	db	0


;--- Test de memoria DOS 2
;    ENTRADA:   -
;    SALIDA:    A  = Numero de mapeadores encontrados
;                    0 -> No hay rutinas de soporte del mapeador:
;                         hay que ejecutar el test directo
;               HL = Numero total de segmentos encontrados
;               BC = Numero de segmentos libres encontrados
;               DE = Numero de segmentos de sistema
;    REGISTROS: Todos
;    LLAMADAS:  -

MEMTEST2:	ld	a,(#FB20)
	bit	0,a
	ld	a,0
	ret	z
	xor	a
	push	de
	pop	bc
	ld	de,#0401
	call	#FFCA
	or	a
	ret	z

	push	hl
	pop	ix
	ld	b,0
	ld	de,0
	ld	(TOTALSG),de
	ld	(FREESG),de
	ld	(SYSTSG),de
	ld	(TOTALMP),de

MT2BUC1:	ld	a,(ix)
	or	a
	jr	z,MT2END
	inc	b	;Increases number of mappers found   
	ld	a,(ix+1)
	ld	e,a
	ld	hl,(TOTALSG)
	add	hl,de
	ld	(TOTALSG),hl
	ld	a,(ix+2)
	ld	e,a
	ld	hl,(FREESG)
	add	hl,de
	ld	(FREESG),hl
	ld	a,(ix+3)
	Ld	e,a
	ld	hl,(SYSTSG)
	add	hl,de
	ld	(SYSTSG),hl
	ld	e,8
	add	ix,de
	jr	MT2BUC1

MT2END:	ld	a,b
	ld	(TOTALMP),a
	ld	hl,(TOTALSG)
	ld	bc,(FREESG)
	ld	de,(SYSTSG)
	ret

TOTALSG:	dw	0
FREESG:	dw	0
SYSTSG:	dw	0
TOTALMP:	dw	0
