;See BOREHD.ASM for an English version of this file.

;===============================

	;*** RAM-DD: REGISTRO DE ARRANQUE PARA MSX CON DISCO DURO V1.0
	;Por Konami Man. Empezado el 7-12-1.995
	;Fichero de especificaciones: RAMDD.TXT
	;Se ha de agandir el fichero NUMTOASC.ASC al final del listado
	;antes de ensamblarlo.

DOSVER:	EQU	#6F
CONOUT:	EQU	#02
STROUT:	EQU	#09
CHKCHR:	EQU	#5D
TERM:	EQU	#62
GDATE:	EQU	#2A
GTIME:	EQU	#2C
SDATE:	EQU	#2B
DEFER:	EQU	#64
DEFAB:	EQU	#63
OPEN:	EQU	#43
CLOSE:	EQU	#45
WRITE:	EQU	#49
SEEK:	EQU	#4A
GENV:	EQU	#6B
EXPLAIN:	EQU	#66
DIRIN:	EQU	#07

	org	#100

	;*** Comprobamos si estamos bajo DOS 2, si no salimos

CHKIFDOS2:	ld	c,DOSVER
	call	5
	ret	nz
	ld	a,b
	cp	1
	jr	nc,ENDCHK
NODOS2:	ld	de,TITLE
	ld	c,STROUT
	push	bc
	call	5
	pop	bc
	ld	de,NODOS2STR
	ld	c,STROUT
	jp	5
NODOS2STR:	DB	"*** RAM-DD solo funciona bajo DOS 2.",13,10,"$"
ENDCHK:	xor	a
	ld	(FHANDLE),a
	ld	(PARAM),a

	;*** Pasamos la linea de comandos a mayusculas
	;    por si UPPER esta OFF

TOMAY:	ld	a,(#80)
	or	a
	jr	z,SHOW	;Si no hay parametros pasamos directamente
	ld	ix,#81	;a mostrar la informacion
	ld	d,0	;Banderas de conversion
BUCTOMAY:	ld	a,(ix)
	or	a
	jr	z,ENDTOMAY
	ld	e,a
	ld	c,CHKCHR
	call	5
	ld	(ix),e
	inc	ix
	jr	BUCTOMAY
ENDTOMAY:

	;*** Comprobamos si se ha pasado /?, en tal caso
	;    mostramos la ayuda y salimos

CHKHLP:	ld	hl,#81
	ld	a,(#80)
	ld	c,a
	ld	b,a
	ld	a,"?"
	call	STRING
	ld	a,b
	or	a
	jp	nz,SHOWHLP	;Si hemos encontrado "?", mostramos ayuda

	;*** Buscamos parametro RESET

CHKRES:	ld	b,c
	xor	a
	ld	de,RESSTR
	call	STRING
	ld	a,b
	or	a
	jp	nz,RESET

	;*** Buscamos parametro BOOT

CHKBOOT:	ld	hl,#81
	ld	b,c
	xor	a
	ld	de,BOOTSTR
	call	STRING
	ld	a,b
	or	a
	jp	nz,BOOT

	;*** Buscamos REF

CHKREF:	ld	hl,#81
	ld	b,c
	xor	a
	ld	de,REFSTR
	call	STRING
	ld	a,b
	or	a
	push	bc
	call	nz,REF
	pop	bc

	;*** Buscamos NUM

CHKNUM:	ld	hl,#81
	ld	b,c
	xor	a
	ld	de,NUMSTR
	call	STRING
	ld	a,b
	or	a
	jp	nz,NUM

	;*** Mostramos informacion

SHOW:	ld	c,GDATE	;Actualizamos fecha y hora actuales
	call	5
	ld	ix,FECHACT
	call	CONVDAT
	ld	c,GTIME
	call	5
	ld	de,HORACT
	call	CONVHOR

	ld	c,CONOUT	;Borramos la pantalla
	ld	e,#c
	call	5
	ld	de,TITLE	;Sacamos titulo
	ld	c,STROUT
	push	bc
	call	5
	ld	de,MENSAJE	;Sacamos toda la informacion
	pop	bc
	call	5

CHKMODE:	ld	a,(PARAM)	;Mostramos modo de ejecucion
	ld	de,MCONSSTR
	or	a
	jr	z,SHOWMODE
	ld	de,MRESSTR
	cp	1
	jr	z,SHOWMODE
	ld	de,MBOOTSTR
	cp	2
	jr	z,SHOWMODE
	ld	de,MACTSTR
SHOWMODE:	ld	c,STROUT
	call	5

	;*** Comprobamos si algun parametro es incorrecto,
	;    en tal caso no actualizamos el registro.

CHKPARERR:	ld	a,(PARAM)
	or	a
	jp	z,ACABOSE	;Finalizacion si no hay parametros
	and	%11000000
	or	a
	jr	z,OKPARAM	;Si b7 y b6 de (PARAM)=0 no hay error
	ld	de,ERPSTR
	ld	c,STROUT
	push	af
	call	5
	pop	af
	ld	de,SOLOREF	;Mostramos el o los parametro(s)
	cp	%10000000	;incorrecto(s)
	jr	z,SHOWERPAR
	ld	de,SOLONUM
	cp	%01000000
	jr	z,SHOWERPAR
	ld	de,REFYNUM
SHOWERPAR:	ld	c,STROUT
	call	5
	ld	de,NOACTSTR
	ld	c,STROUT
	call	5
	jr	ACABOSE
OKPARAM:	;

	;*** Actualizacion del registro

ACTREG:	;
DEFINE:	ld	de,RUTERR	;Definimos rutina de error de disco
	ld	c,DEFER
	call	5
	call	SHOWACT	;Mensaje "Actualizando registro"

OPENREG:	ld	hl,PROGSTR	;Averiguamos el nombre y la ruta
	ld	de,RAMDDNAM	;de RAMDD
	ld	b,64
	ld	c,GENV
	call	5

	xor	a	;Abrimos el fichero
	ld	c,OPEN
	call	5
	push	bc

	xor	a	;Puntero del fichero a la zona de datos
	ld	de,0
	ld	hl,MENSAJE-#100
	ld	c,SEEK
	call	5

	pop	bc	;Reescribimos la zona de datos (actualizada)
	push	bc	;en el fichero
	ld	de,MENSAJE
	ld	hl,ENDDAT-MENSAJE+1
	ld	c,WRITE
	call	5

	pop	bc	;Cerramos el fichero
	ld	c,CLOSE
	call	5

	call	LOCATE	;Mensaje "Registro actualizado"
	ld	de,RACTSTR
	ld	c,STROUT
	push	bc
	call	5
	pop	bc
	ld	de,BLANCO
	call	STROUT

ACABOSE:	ld	de,0
	ld	c,DEFER
	call	5
	ld	c,TERM
	ld	b,0
	jp	5

SHOWACT:	call	LOCATE
	ld	de,ACTSTR
	ld	c,STROUT
	push	bc
	call	5
	pop	bc
	ld	de,BLANCO
	call	5
	ret

ACTSTR:	db	"Actualizando el registro ...                           "
	db	13,10,"$"
BLANCO:	ds	80,32
	db	"$"
RACTSTR:	db	"Registro actualizado OK.                               "
	db	13,10,13,10,"$"
ERRDSKSTR:	db	"Error: "
AQUIERR:	ds	67
OPTSTR:	db	"Reintentar o Cancelar (R/C)? $"
SOLOREF:	db	" REF incorrecto$"
SOLONUM:	db	" NUM incorrecto$"
REFYNUM:	db	"s REF y NUM incorrectos$"
FINSTR:	db	13,10,"$"
ABSTR:	db	"Actualizacion del registro cancelada.             "
	db	13,10,"$"

	;*** Rutina a ejecutar en caso de error de disco

RUTERR:	push	af
	call	LOCATE
	ld	de,BLANCO
	ld	c,STROUT
	call	5
	call	LOCATE

	pop	af	;Obtenemos mensaje de error
	ld	b,a
	ld	de,AQUIERR
	ld	c,EXPLAIN
	call	5

	ld	hl,AQUIERR-1	;Ponemos 10,13,"$" al final de la cadena
BUSFERR:	inc	hl
	ld	a,(hl)
	or	a
	jr	nz,BUSFERR
	ex	de,hl
	ld	hl,FINSTR
	ld	bc,3
	ldir
	ld	de,ERRDSKSTR	;Sacamos "Error: "+cadena de error
	ld	c,STROUT
	push	bc
	call	5

	ld	de,OPTSTR	;Preguntamos si reintentar o cancelar
	pop	bc
	call	5
PREGUNTA:	ld	c,DIRIN
	call	5
	cp	"r"
	jr	z,RETRY
	cp	"R"
	jr	z,RETRY
	cp	"C"
	jr	z,ABORT
	cp	"c"
	jr	z,ABORT
	jr	PREGUNTA

RETRY:	call	SHOWACT	;Reintentar
	ld	a,2
	ret

ABORT:	call	LOCATE
	ld	de,ABSTR	;Cancelar: terminamos el programa.
	ld	c,STROUT
	push	bc
	call	5
	ld	de,BLANCO
	pop	bc
	call	5
	ld	b,0
	ld	c,TERM
	jp	5

	;*** "?" detectado en parametros: sacamos ayuda y terminamos

SHOWHLP:	ld	e,#c
	ld	c,CONOUT
	call	5
	ld	de,TITLE
	ld	c,STROUT
	push	bc
	call	5
	pop	bc
	ld	de,HELPSTR
	call	5
	ld	c,TERM
	ld	b,0
	jp	5

	;*** RESET: arranques a 1 y fecha de referencia la actual

RESET:	ld	a,1
	ld	(ARRANQUES),a	;Numero de arranques a 1
	xor	a	;--> NO INCLUIDO EN VERSION #1.0
	ld	(ARRANQUES+1),a	;--> (CAUSA DEL FALLO EN OPCION RESET)
	ld	ix,NUMARR
	ld	a," "
	ld	(ix),a
	ld	(ix+1),a
	ld	(ix+2),a
	ld	(ix+3),a
	ld	a,"1"
	ld	(ix+4),a

	ld	c,GDATE	;Todas las fechas a la fecha actual
	call	5
	ld	ix,REFDAT
	call	CONVDAT
	ld	ix,ULTDAT
	call	CONVDAT
	ld	ix,ACTDAT
	call	CONVDAT
	ld	c,GTIME	;Todas las horas a la hora actual
	call	5
	ld	de,ULTHOR
	call	CONVHOR
	ld	de,ACTHOR
	call	CONVHOR

	ld	a,1
	ld	(PARAM),a	;PARAM=1 => Se ha pasado RESET
	jp	SHOW

	;*** BOOT: Arranques=arranques+1,
	;          fecha actual arranque => fecha ultimo arranque,
	;          fecha actual => fecha actual arranque

BOOT:	ld	de,(ARRANQUES)
	inc	de
	ld	(ARRANQUES),de	;DE = numero de arranques actualizado
	ld	hl,NUMARR
	ld	bc,#0520
	ld	a,%00011000
	call	NUMTOASC

	ld	hl,ACTDAT	;Actual arranque => ultimo arranque
	ld	de,ULTDAT
	ld	bc,8
	ldir
	ld	hl,ACTHOR
	ld	de,ULTHOR
	ld	bc,5
	ldir

	ld	c,GDATE	;Fecha actual => actual arranque
	call	5
	ld	ix,ACTDAT
	call	CONVDAT
	ld	c,GTIME
	call	5
	ld	de,ACTHOR
	call	CONVHOR

	ld	a,2
	ld	(PARAM),a	;PARAM=2 => se ha pasado BOOT
	jp	SHOW

	;*** REF: comprobamos si se ha pasado REF:NOW

REF:	ld	b,5	;Puntero de la cadena justo despues de REF
TRASREF:	inc	hl
	djnz	TRASREF

	xor	a
	ld	de,NOWSTR	;Comprobamos si NOW esta juesto despues
	pop	ix,bc	;de "/REF:"
	push	bc,ix
	ld	b,c
	call	STRING
	ld	a,b
	cp	1
	jr	nz,REFNUM

REFNOW:	ld	c,GDATE	;Fecha actual => fecha de referencia
	call	5
	ld	ix,REFDAT
	call	CONVDAT
	ld	a,4	;b2 de (PARAM)=1 si se ha pasado REF:NOW
	ld	(PARAM),a
	ret

REFNUM:	ld	a,8
	ld	(PARAM),a	;b3 de (PARAM)=1 si se ha pasado REF:algo
	call	EXTNUM	;extraemos dia
	ld	a,d
	or	a
	jp	z,ERREF	;Error si dia tiene 0 digitos
	cp	3	;(es decir, no es un numero)
	jr	nc,ERREF	;Error si dia tiene mas de 2 digitos
	ld	a,c
	ld	(TMPDIA),a	;Si es correcto, guardamos dia

	ld	a,e
	cp	"-"
	jr	nz,ERREF	;Error si despues del dia no hay un "-"

	ld	c,d
	ld	b,0
	add	hl,bc
	inc	hl	;Pasamos al mes
	call	EXTNUM	;extraemos mes
	ld	a,d
	or	a
	jr	z,ERREF	;Error si mes tiene 0 digitos
	cp	3	;(es decir, no es un numero) 
	jr	nc,ERREF	;Error si mes tiene mas de 2 digitos
	ld	a,c
	ld	(TMPMES),a	;Si es correcto, guardamos dia

	ld	a,e
	cp	"-"
	jr	nz,ERREF	;Error si despues del mes no hay un "-"

	ld	c,d
	ld	b,0
	add	hl,bc
	inc	hl	;Pasamos al agno
	call	EXTNUM	;extraemos agno
	ld	a,d
	or	a
	jr	z,ERREF	;Error si agno tiene 0 digitos
	cp	3	;(es decir, no es un numero)  
	jr	nc,ERREF	;Error si agno tiene mas de 2 digitos
	ld	a,c
	ld	(TMPAGNO),a

CHKDAT:	ld	c,GDATE	;Guardamos fecha actual
	call	5
	push	hl,de
	ld	a,(TMPMES)	;Pasamos el agno a HL, mes a D, dia a E
	ld	d,a	;La fecha tiene la forma dd-mm-yy correcta,
	ld	a,(TMPDIA)	;ahora comprobaremos, con ayuda de
	ld	e,a	;la funcion DOS SDATE, si es correcta.
	ld	bc,1900	;Pasamos agno de 2 cifras a agno de 4 cifras
	ld	a,(TMPAGNO)
	ld	l,a
	ld	h,0
	cp	81
	jr	nc,MENOS2MIL
MAS2MIL:	ld	bc,2000
MENOS2MIL:	add	hl,bc
	ld	c,SDATE
	call	5	;Si la fecha es incorrecta devolvera
	pop	de,hl	;A = #FF
	push	af
	ld	c,SDATE
	call	5	;Restauramos fecha actual
	pop	af
	or	a
	jr	nz,ERREF

	ld	a,(TMPMES)	;La fecha es correcta: pasamos a copiarla
	ld	d,a	;en la fecha de referencia
	ld	a,(TMPDIA)
	ld	e,a
	ld	a,(TMPAGNO)
	ld	l,a
	ld	h,0
	ld	ix,REFDAT
	call	CONVDAT
	ret		;Volvemos, y buscamos parametro NUM

ERREF:	ld	a,(PARAM)
	or	128	;b7 de (PARAM)=1 => error del parametro /REF
	ld	(PARAM),a
	ret		;Volvemos, y buscamos parametro NUM 
NOWSTR:	db	"NOW",0
TMPDIA:	ds	1
TMPMES:	ds	1
TMPAGNO:	ds	2

	;*** NUM: actualizamos numero de arranques sumando, restando o
	;         sustituyendo al numero actual

NUM:	ld	a,(PARAM)	;bit 4 de (PARAM)=1 => NUM existente
	or	16
	ld	(PARAM),a

	ld	b,5	;Puntero justo despues de "/NUM:"
TRASNUM:	inc	hl
	djnz	TRASNUM

	ld	a,(hl)
	cp	"+"
	jr	z,INCNUM
	cp	"-"
	jr	z,DECNUM

SUSTNUM:	call	EXTNUM
	jr	c,ERRNUM	;Error si el numero es mayor que 65535
	or	a
	jr	nz,ERRNUM	;Error si el numero tiene + de 5 digitos
	ld	a,d
	or	a
	jr	z,ERRNUM	;Error si el numero tiene 0 digitos

	ld	(ARRANQUES),bc
	push	bc
	pop	de
	jr	ARRTONUM

INCNUM:	inc	hl	;Incrementamos numero de arranques
	call	EXTNUM	;en la cantidad pasada tras /NUM:
	jr	c,ERRNUM
	or	a
	jr	nz,ERRNUM
	ld	hl,(ARRANQUES)
	add	hl,bc
	ex	de,hl
	jr	ARRTONUM

DECNUM:	inc	hl	;Decrementamos numero de arranques
	call	EXTNUM	;en la cantidad pasada tras /NUM:
	jr	c,ERRNUM
	or	a
	jr	nz,ERRNUM
	ld	hl,(ARRANQUES)
	sbc	hl,bc
	ex	de,hl

ARRTONUM:	ld	hl,NUMARR	;Actualizamos registro de num. de arranques
	ld	bc,#0520
	ld	a,%00011000
	call	NUMTOASC
	jp	SHOW

ERRNUM:	ld	a,(PARAM)	;bit 6 de (PARAM)=1 => parametro tras
	or	64	;/NUM: incorrecto
	ld	(PARAM),a
	jp	SHOW

	;*** Funcin STRING$: comprueba si una cadena contiene a otra
	;*** Entrada: HL = puntero cadena a investigar
	;             A  = 0 y DE = cadena que buscamos+#00, o bien
	;             A  = caracter que buscamos y DE ignorado
	;             B  = longitud de (HL) y C ignorado, o bien
	;             B  = 0 y C=caracter de terminacion de la cadena
	;                      (no se cuenta en la busqueda)
	;*** Salida:  HL = inicio de la cadena encontrada, dir. absoluta
	;             B  = posicion en (HL) de la cadena encontrada
	;                  (1a posicion numerada con 1)
	;             Si no se ha encontrado la cadena,
	;             HL = inicio de la cadena investigada (sin modificar)
	;             B  = 0
	;             DE, A, C, IX, IY y reg. alt. no modificados
	;
STRING:	or	a
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
	cp	(hl)
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

	;*** Funcion EXTNUM: extrae un numero de 5 digitos en formato ASCII
	;*** Entradas: HL = comienzo del numero
	;*** Salidas:  CY-BC = numero de 17 bits
	;              D  = numero de digitos que forman el numero
	;                   El programa da el numero por terminado
	;                   al encontrar un caracter no numerico,
	;                   o cuando ha extraido cinco digitos.
	;              E  = primer caracter incorrecto (o sexto digito)
	;              A  = error:
	;                   0 => sin error
	;                   1 => el numero tiene mas de 5 digitos.
	;                        CY-BC contiene el numero formado por
	;                        los cinco primeros digitos
	;              HL, IX, IY y reg. alt. no modificados
	;
EXTNUM:	push	hl,ix
	ld	ix,ACA
	res	0,(ix)
	set	1,(ix)
	ld	bc,0
	ld	de,0
BUSNUM:	ld	a,(hl)	;Salta a FINEXT si el caracter no es
	ld	e,a	;IXh = ultimo caracter leido por ahora
	cp	"0"	;un numero, o si es el sexto caracter
	jr	c,FINEXT
	cp	"9"+1
	jr	nc,FINEXT
	ld	a,d
	cp	5
	jr	z,FINEXT
	call	POR10

SUMA:	push	hl	;BC = BC + A
	push	bc
	pop	hl
	ld	bc,0
	ld	a,e
	sub	"0"
	ld	c,a
	add	hl,bc
	call	c,BIT17
	push	hl
	pop	bc
	pop	hl

	inc	d
	inc	hl
	jr	BUSNUM

BIT17:	set	0,(ix)
	ret
ACA:	db	0	;b0: num>65535. b1: mas de 5 digitos

FINEXT:	ld	a,e
	cp	"0"
	call	c,NODESB
	cp	"9"+1
	call	nc,NODESB
	ld	a,(ix)
	pop	ix,hl
	srl	a
	ret

NODESB:	res	1,(ix)
	ret

POR10:	push	de,hl	;BC = BC * 10
	push	bc
	push	bc
	pop	hl
	pop	de
	ld	b,3
ROTA:	sla	l
	rl	h
	djnz	ROTA
	call	c,BIT17
	add	hl,de
	call	c,BIT17
	add	hl,de
	call	c,BIT17
	push	hl
	pop	bc
	pop	hl,de
	ret

	;*** Funcion CONVDAT: convierte una fecha tal como la da
	;    la funcion del DOS GET DATE (#2A) en una cadena ASCII de
	;    8 caracteres: dd-mm-yy
	;    Usa la subrutina NUMTOASC
	;*** Entrada: fecha tal como la da GET DATE, es decir
	;             HL = agno, 1980..2079
	;             D  = mes, 1..12 (enero..diciembre)
	;             E  = dia, 1..31
	;             IX = buffer en el que dejar la cadena convertida
	;*** Salida:  cadena dd-mm-yy en (IX)
	;             Esta rutina no detecta fechas incorrectas
	;             Ningun registro modificado
	;
CONVDAT:	push	af,hl,bc,de,de
CONVAGNO:	ex	de,hl	;DE=agno a convertir
	push	ix
	pop	hl
	inc	hl
	inc	hl
	inc	hl	;HL=inicio buffer+3
	inc	hl
	ld	b,4
	ld	a,%00011000
	call	NUMTOASC	;(HL)="xxxxAAAA"
	ld	a,"-"
	inc	hl
	ld	(hl),a	;(HL)="xxxxA-AA"

CONVMES:	pop	de
	push	de
	ld	e,d
	ld	d,0	;DE=mes a convertir
	dec	hl
	dec	hl
	ld	bc,#0230
	ld	a,%00011000
	call	NUMTOASC	;(HL)="xxxMM-AA"
	dec	hl
	ld	a,"-"
	ld	(hl),a	;(HL)="xx-MM-AA"

CONVDIA:	pop	de
	ld	d,0	;DE=dia a convertir
	dec	hl
	dec	hl
	ld	bc,#0230
	ld	a,%00011000
	call	NUMTOASC	;(HL)="DD-MM-AA"

	pop	de,bc,hl,af
	ret

	;*** Funcion CONVHOR: convierte una hora tal como la da
	;    la funcion del DOS GET TIME (#2C) en una cadena ASCII
	;    de 5 caracteres: hh:mm, o h:mm
	;    Usa la funcion NUMTOASC
	;*** Entrada: hora tal como la da GET DATE, es decir
	;             H = horas
	;             L = minutos
	;             DE= buffer para depositar la cadena ASCII
	;*** Salida:  cadena en (DE)
	;             Ningun registro modificado
	;
CONVHOR:	push	af,bc,hl,de,hl
	ex	de,hl	;HL=buffer, DE=hora
	ld	e,d
	ld	d,0
	ld	bc,#0220
	ld	a,%00011000
	push	af
	call	NUMTOASC	;(HL)="HHxxx"

	inc	hl
	inc	hl
	ld	a,":"
	ld	(hl),a	;(HL)="HH:xx"
	inc	hl
	pop	af
	pop	de
	ld	d,0
	ld	bc,#0230
	call	NUMTOASC	;(HL)="HH:MM"

	pop	de,hl,bc,af
	ret

	;*** Funcion LOCATE: pone el cursor en la posicion 0,9
	;
LOCATE:	push	af,bc,de,hl
	ld	de,LOCSTR
	ld	c,STROUT
	call	5
	pop	hl,de,bc,af
	ret
LOCSTR:	db	#1B,"Y",#29,#20,"$"

CHARA:	ds	2
RESSTR:	db	"/RESET",0
BOOTSTR:	db	"/BOOT",0
NUMSTR:	db	"/NUM:",0
REFSTR:	db	"/REF:",0
PROGSTR:	db	"PROGRAM",0

	;*** Zona de mensajes + zona de datos

TITLE:	db	"RAM-DD v1.01: Registro de Arranque para MSX con"
	db	" Disco Duro - (j) Konami Man '95",13,10
	db	"-----------------------------------------------"
	db	"--------------------------------",13,10,13,10,"$"
MENSAJE:	db	"Numero de arranques desde el "
REFDAT:	ds	8,32
	db	" :       "
NUMARR:	ds	5,32
	db	"  |  Fecha: "
FECHACT:	ds	8,32
	db	13,10,"Ultimo arranque efectuado el "
ULTDAT:	ds	8,32
	db	" a las "
ULTHOR:	ds	5,32
	db	" h  | -----------------",13,10
	db	"Arranque actual efectuado el "
ACTDAT:	ds	8,32
	db	" a las "
ACTHOR:	ds	5,32
	db	" h  |  Hora:  "
HORACT:	ds	5,32
	db	" h",13,10,13,10
	db	"Modo de ejecucion: $"
MBOOTSTR:	db	"Arranque del sistema.",13,10,13,10,"$"
MRESSTR:	db	"Inicializacion del registro.",13,10,13,10,"$"
MCONSSTR:	db	"Consulta del registro. "
	db	"RAMDD /? muestra opciones.",13,10,13,10,"$"
MACTSTR:	db	"Actualizacion manual del registro.",13,10,13,10,"$"
ERPSTR:	db	"Error: parametro$"
NOACTSTR:	db	". Registro no actualizado.",13,10,"$"
EXPERR:	ds	65,32
ARRANQUES:	dw	33
ENDDAT:	nop
HELPSTR:	db	#1B,"A  Este programa guarda un registro de la"
	db	"s veces que ha sido arrancado el ordena-"

	db	"dor desde la fecha de referencia dada, a"
	db	"si como la fecha y la hora del ultimo   "

	db	"arranque y del arranque actual. Los dato"
	db	"s se guardan en el propio fichero del   "

	db	"programa, que puede ser renombrado.",13,10,13,10

	db	"  Si se ejecuta sin parametros, RAMDD si"
	db	"mplemente muestra el registro sin actua-"

	db	"lizarlo. Los parametros que admite son:",13,10,13,10

	db	"/RESET => Inicializa el registro: establ"
	db	"ece la fecha actual como fecha de refe- "

	db	"rencia y pone el numero de arranques a uno.",13,10,13,10

	db	"/BOOT  => Modo de arranque: incrementa e"
	db	"l numero de arranques, copia la fecha y "

	db	"hora del campo Arranque actual en el cam"
	db	"po Ultimo arranque, y la fecha y hora   "

	db	"actuales en el primero. Se ha de incluir"
	db	" RAMDD /BOOT en el AUTOEXEC.BAT para    "

	db	"llevar una cuenta de arranques.",13,10,13,10

	db	"/REF:{NOW|<dd-mm-yy>} => Establece la fe"
	db	"cha indicada como fecha de referencia.  "

	db	"Con NOW establece la fecha actual como f"
	db	"echa de referencia.",13,10,13,10

	db	"/NUM:[+|-]<nnnnn> => Establece el numero"
	db	" de arranques en <nnnnn>, maximo 65535. "

	db	"Con + o - suma o resta la cantidad indic"
	db	"ada al numero de arranques.$"

FHANDLE:	ds	1
ERROR:	ds	1
PARAM:	ds	1
RAMDDNAM:	ds	1
