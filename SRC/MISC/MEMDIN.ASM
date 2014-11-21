;Dynamic memory manager for DOS 2 (MALLOC et al)
;Allocates mapped memory segments as needed

;================================

	;--- Gestor de memoria dinamica


div_hl:	macro		;Divide HL por 2
	srl	h
	rr	l
	endm

div_de:	macro		;Divide DE por 2
	srl	d
	rr	e
	endm

ENASLT:	equ	#0024
EXTBIO:	equ	#FFCA

_OPEN:	equ	#43
_CREATE:	equ	#44
_CLOSE:	equ	#45
_READ:	equ	#48
_WRITE:	equ	#49
_SEEK:	equ	#4A


;************************************************
;***  RUTINAS DE GESTION DE MEMORIA DINAMICA  ***
;************************************************

;--- INITMEM:  Inicializa el tinglado:
;              - Reserva un segmento y lo limpia
;              - Inicializa la tabla de segmentos
;    Entrada:  -
;    Salida:   Cy=1 si no hay ningun segmento libre
;    Regist:   AF, BC, DE, HL

	;Copia la tabla de rutinas del mapeador

INITMEM:	ld	de,#0402
	call	EXTBIO
	ld	de,ALL_SEG
	ld	bc,#30
	ldir

	;Reserva un segmento e inicializa la tabla de idems

	xor	a
	ld	b,0
	call	ALL_SEG
	ret	c

	ld	(TABSEGS),a
	ld	a,1
	ld	(NUMSEGS),a

	call	GET_P2
	push	af
	ld	a,(TABSEGS)
	call	PUT_P2
	call	CLEAN
	pop	af
	call	PUT_P2
	ret

	;Esta subrutina inicializa un segmento:
	;Pone los cuatro primeros bytes de MAT a #FF,
	;y el resto a 0

CLEAN:	ld	hl,#8000
	ld	de,#8001
	ld	bc,3
	ld	(hl),255
	ldir
	inc	hl
	inc	de
	ld	bc,16384-5
	ld	(hl),0
	ldir
	ret

NUMSEGS:	db	0	;Num. de segmentos reservados
TABSEGS:	ds	255	;Tabla de segmentos reservados

	;Rutinas de soporte del mapeador

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


;--- FINISH:  Libera toda la memoria reservada
;    Entrada: -
;    Salida:  -
;    Regist:  AF, BC, DE, HL

FINISH:	ld	a,(NUMSEGS)
	ld	b,a
	ld	hl,TABSEGS

BUC_FM:	push	bc,hl
	ld	a,(hl)
	ld	b,0
	call	FRE_SEG
	pop	hl,bc
	inc	hl
	djnz	BUC_FM

	ret


;--- MAXMIN:  Encuentra el bloque libre mas pequenyo
;             de tamanyo igual o superior a uno requerido
;             en un determinado segmento
;    Entrada: HL = Tamanyo requerido
;             Segmento a examinar conectado en pagina 2
;    Salida:  HL = Tamanyo del bloque encontrado
;             DE = Direccion del bloque encontrado,
;                  en pagina 2 (con desplazamiento #8000)
;             Cy = 1 si no hay bloques libres de al menos
;                  el tamanyo requerido en el segmento
;    Regist:  AF, BC, DE, HL

MAXMIN:	ld	(BUSCAR),hl
	ld	a,4	;Empieza por el cuarto byte MAT,
	ld	(BYTE),a	;que apunta a #100
	xor	a
	ld	(BIT),a
	ld	hl,#7FFF
	ld	(MIN_FND),hl

	;Busca un bloque libre

BUSLIB:	ld	a,(BIT)	;C=Contador de bits de un byte
	ld	c,a
	ld	a,(BYTE)	;L=Contador de bytes
	or	a
	jr	z,BL_FIN
	ld	l,a
	ld	h,#80	;HL=Direccion de ese byte MAT

	ld	b,(hl)
	xor	a
BUC_BL0:	cp	c	;Rota B para leer el primer bit
	jr	z,BUC_BL10	;(hace que el primer bit este en la
	srl	b		;posicion 0)
	inc	a
	jr	BUC_BL0

BUC_BL1:	srl	b	;Este bucle va pasando bits
	jr	nc,FREE_FND	;mientras sean 1
	inc	c
BUC_BL10:	bit	3,c
	jr	z,BUC_BL1	;Siguiente bit

	inc	hl
	bit	0,h
	jr	nz,BL_FIN	;Fin si se llega a #8100 (fin de MAT)
	ld	c,0
	ld	b,(hl)
	jr	BUC_BL1	;Siguiente byte si se ha llegado al bit 8

	;Bloque libre encontrado: comprueba tamanyoo

FREE_FND:	ld	a,c
	ld	(BIT2),a
	ld	a,l
	ld	(BYTE2),a
	ld	de,1	;DE=Longitud del bloque en sectores
	jr	BUC_BL20

BUC_BL2:	srl	b	;Va pasando bits mientras sean 0,
	jr	c,OK_FREE	;y mientras incrementa DE
	inc	de
BUC_BL20:	inc	c
	bit	3,c
	jr	z,BUC_BL2	;Siguiente bit

	inc	hl
	bit	0,h
	jr	nz,OK_FREE
	ld	c,0
	ld	b,(hl)
	jr	BUC_BL2	;Siguiente byte si se llega al bit 8

OK_FREE:	ld	a,c
	ld	(BIT),a
	ld	a,l
	ld	(BYTE),a

	call	DEPOR8	;Multiplica DE por 8

	ld	hl,(BUSCAR)	;Si el bloque encontrado es de
	call	COMP	;tamanyo menor al requerido, lo descartamos
	jr	z,OKF2	;y pasamos a buscar el siguiente bloque libre
	jr	c,BUSLIB
OKF2:	;

	;Si el bloque encontrado es de tamanyo >= al requerido,
	;comprueba si es menor que el ultimo bloque encontrado,
	;si es asi sustituye el anterior por el nuevo

	ld	hl,(MIN_FND)
	call	COMP
	jr	z,BUSLIB
	jr	nc,BUSLIB	;Busca siguiente bloque libre

	ld	(MIN_FND),de
	ld	a,(BIT2)
	ld	(BITFND),a
	ld	a,(BYTE2)
	ld	(BYTEFND),a
	jr	BUSLIB	;Busca siguiente bloque libre

	;Fin de MAT encontrado: devuelve HL, DE y Cy adecuados

BL_FIN:	ld	hl,(MIN_FND)
	ld	de,#7FFF	;Si DE sigue teniendo el valor inicial
	call	COMP	;#7FFF, es que no se ha encontrado
	scf		;ningun bloque libre >= al requerido
	ret	z

	ld	a,(BYTEFND)	;Dir = (BYTE * 64) + BIT * 8=
	ld	e,a	;    = ((BYTE * 8) + BIT) * 8
	ld	d,0

	call	DEPOR8	;Multiplica BYTE por 8

	ld	a,(BITFND)	;Suma BIT
	ld	c,a
	ld	b,0
	ex	de,hl
	add	hl,bc
	ex	de,hl

	call	DEPOR8	;Vuelve a multiplicar por 8
	set	7,d

	or	a
	ret

	;Esta subrutina multiplica DE por 8

DEPOR8:	sla	e
	rl	d
	sla	e
	rl	d
	sla	e
	rl	d
	ret

BUSCAR:	dw	0	;Tamanyo requerido
MIN_FND:	dw	0	;Tamanyo del mejor bloque encontrado
BYTE:	db	0	;Byte MAT que esta siendo examinado
BIT:	db	0	;Bit que esta siendo examinado
BYTE2:	db	0	;Byte MAT del ultimo bloque libre encontrado
BIT2:	db	0	;Bit de inicio del ultimo b. libre encontrado
BYTEFND:	db	0	;Byte MAT del mejor bloque encontrado   
BITFND:	db	0	;Bit de inicio del mejor bloque encontrado


;--- MALLOC:  Reserva un bloque de memoria
;    Entrada: HL = Tamanyo requerido
;    Salida:  HL = Direccion, empezando en #8000
;             B  = Segmento
;             Cy = 1 si hay error (no queda memoria libre)
;    Regist:  AF, BC, DE, HL

MALLOC:	inc	hl
	ld	a,h
	cp	#3F
	ccf
	ret	c
	inc	hl

	;Transforma tamanyo declarado en tamanyo real

	ld	(TAMREQ),hl
	ld	a,l
	and	%111
	jr	z,OKTREAL
	ld	a,l
	and	%11111000
	add	8
	ld	l,a
	jr	nc,OKTREAL	;*** ANYADIDO EN 1.22
	inc	h	;***
OKTREAL:	ld	(TAMREAL),hl

	;Inicializa algunas variables

	ld	a,-1
	ld	(SEGFND),a
	call	GET_P2
	push	af

	ld	hl,#7FFF
	ld	(TAMFND),hl

	ld	a,(NUMSEGS)
	ld	b,a	;B = Num. de segmentos
	ld	hl,TABSEGS

	;Recorre todos los segmentos reservados, buscando
	;el que tiene el menor tamanyo de bloque posible
	;que sea >= que el tamanyo requerido

BUC_MALL:	push	hl,bc
	ld	a,(hl)
	ld	(CURSLOT),a
	call	PUT_P2

	ld	hl,(TAMREQ)
	call	MAXMIN
	jr	c,NEXT_MALL

	push	de	;Si el mejor bloque de este segmento
	ld	de,(TAMFND)	;es mas pequenyo que el ultimo mejor
	call	COMP	;bloque encontrado, cambiamos el viejo
	pop	de	;por el nuevo
	jr	c,NEXT_MALL
	ld	(TAMFND),hl
	ld	(DIRFND),de
	ld	a,(CURSLOT)
	ld	(SEGFND),a

NEXT_MALL:	pop	bc,hl
	inc	hl
	djnz	BUC_MALL

	;Una vez examinados todos los slots, comprobamos si
	;hemos encontrado un bloque libre en alguno de ellos

FND_MALL:	ld	a,(SEGFND)
	cp	-1
	jr	z,NEW_SEG

	;Actualizamos MAT, ponemos el tamanyo del bloque
	;al principio del mismo y terminamos

	call	PUT_P2	;Conecta segmento encontrado a pag. 2

	ld	de,(TAMREAL)
	ld	hl,(DIRFND)

	ld	a,#C0
	call	ADJMAT	;Pone los bits adecuados de MAT a 1

	ld	a,(SEGFND)	;Pone el tamanyo del bloque
	ld	b,a	;al principio del mismo
	ld	de,(TAMREQ)
	dec	de
	dec	de
	ld	hl,(DIRFND)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	pop	af
	call	PUT_P2	;Restaura segmento original y termina

	or	a
	ret

	;Si no hay ningun bloque libre, reservamos un segmento nuevo.
	;Si no es posible, devolvemos un error.

NEW_SEG:	ld	a,(NUMSEGS)
	cp	255	;Error si ya habia 255 seg. reservados
	jr	z,MALL_ERR

	ld	a,(#F344)	;Reserva segmento y lo inicializa
	call	ALL_SEG
	ld	b,0
	jr	c,MALL_ERR

	call	PUT_P2
	call	CLEAN

	ld	e,a
	ld	a,(NUMSEGS)
	ld	c,a
	inc	a
	ld	(NUMSEGS),a
	ld	b,0
	ld	hl,TABSEGS
	add	hl,bc
	ld	(hl),e

	ld	a,e	;Ahora actua como si hubiera encontrado
	ld	(SEGFND),a	;un bloque libre en el segmento
	ld	hl,#8100	;que acabamos de reservar
	ld	(DIRFND),hl
	ld	hl,#3F00
	ld	(TAMFND),hl
	jp	FND_MALL

MALL_ERR:	pop	af	;Terminacion con error
	call	PUT_P2
	or	a
	ret

	;Esta subrutina comprueba si DE es 0

DE_ES_0:	ld	(SAVEA),a
	ld	a,d
	or	e
	ld	a,(SAVEA)
	ret

TAMREQ:	dw	0	;Tamanyo requerido
SEGFND:	db	0	;Segmento del mejor bloque encontrado
TAMFND:	dw	0	;Tamanyo del mejor bloque encontrado
CURSLOT:	db	0	;Segmento que esta siendo examinado
DIRFND:	dw	0	;Direccion del mejor bloque encontrado
TAMREAL:	dw	0	;Tamanyo declarado convertido a real
SAVEA:	db	0


;--- MFREE: Libera un bloque de memoria
;    Entrada: A  = Segmento del bloque
;             HL = Direccion del bloque
;    Salida:  -
;    Regist:  AF, BC, DE, HL

MFREE:	ld	e,a
	call	GET_P2
	push	af
	ld	a,e
	call	PUT_P2

	res	1,l
	ld	e,(hl)
	inc	hl
	ld	d,(hl)	;DE = Tamanyo declarado
	inc	de	;!!!!!!!
	inc	de	;!!!!!!!
	ld	a,e
	and	%111	;Convierte a tamanyo real
	jr	z,OKTRE2
	ld	a,e
	and	%11111000
	add	8
	ld	e,a	;Ahora DE = Tamanyo real
	jr	nc,OKTRE2	;*** ANYADIDO EN 1.22
	inc	d
OKTRE2:	res	0,l	;HL = Direccion real (multiplo de 8)

	ld	a,#80	;Pone bits de MAT a 0
	call	ADJMAT

	pop	af
	call	PUT_P2
	ret


;--- ADJMAT:  Pone a 1 o a 0 los bits MAT correspondientes
;             a un bloque de memoria
;    Entrada: HL = Direccion (ha de ser multiplo de 8)
;             DE = Tamanyo real del bloque
;             A  = #80 para poner a 0 (entonces SETMAT_2 sera RES 0,B)
;                  #C0 para poner a 1 (entonces SETMAT_2 sera SET 0,B)
;    Salida:  -
;    Regist:  AF, BC, DE, HL

ADJMAT:	ld	(SETMAT_2+1),a

	xor	a
	div_hl		;HL = HL / 8
	div_hl
	div_hl

	div_hl		;HL = HL / 8 y resto a A
	rr	a
	div_hl
	rr	a
	div_hl
	rr	a	;Ahora HL = Byte MAT y A = Bit
	ld	h,#80
	rlca
	rlca
	rlca

	div_de		;DE = DE / 8 = Num. de bits a poner a 1
	div_de
	div_de

	push	af
	ld	b,(hl)
SETMAT_1:	or	a	;Rota B hasta que el primer bit a modificar
	jr	z,OKMAT_1	;esta en la posicion 0
	rrc	b
	dec	a
	jr	SETMAT_1
OKMAT_1:	pop	af

SETMAT_2:	db	#CB,0	;Va poniendo a 1/0
	rrc	b	;todos los bits necesarios
	dec	de
	call	DE_ES_0
	jr	z,SETMAT_F
	inc	a
	cp	8
	jr	nz,SETMAT_2

	ld	(hl),b	;Siguiente byte
	inc	hl
	ld	b,(hl)
	xor	a
	jr	SETMAT_2

SETMAT_F:	inc	a	;Ajusta el ultimo byte
	cp	8
	jr	z,SETMAT_F2
	rrc	b
	jr	SETMAT_F
SETMAT_F2:	ld	(hl),b

	ret


;--- NOMBRE:  COMP
;       Comparacion de HL con DE (16 bits en complemento a 2)
;    Entrada: HL, DE = numeros a comparar
;    Salida:   C, NZ si HL > DE
;              C,  Z si HL = DE
;             NC, NZ si HL < DE
;    Regist:  AF

COMP:	call	_COMP
	ccf
	ret

_COMP:	ld	a,h
	sub	d
	ret	nz
	ld	a,l
	sub	e
	ret


;**************************************************
;***  RUTINAS DE GESTION DE LISTAS ENCADENADAS  ***
;**************************************************

;* Un elemento de lista consta de:
;- Segmento + direccion del elemento anterior
;- Segmento + direccion del elemento siguiente
;- Datos que forman el elemento

;* El descriptor de una lista es una tabla de 12 bytes con:
;- Segmento + direccion del primer elemento
;- Segmento + direccion del elemento en curso
;- Segmento + direccion del ultimo elemento
;- Numero de elementos (3 bytes)


;--- L_INIT:  Inicializa un descriptor de lista (punteros y num. elems. a 0)
;    Entrada: IX   = Direccion del descriptor de la lista
;    Salida:  -
;    Regist:  F, BC, DE, HL

L_INIT:	push	ix
	pop	hl
	push	hl
	pop	de
	inc	de
	ld	bc,11
	ld	(hl),0
	ldir
	ret


;--- L_PNTS:  Obtiene las direcciones de elemento anterior
;             y posterior de un elemento de lista
;    Entrada: IX   = Direccion del descriptor de la lista
;    Salida:  A-HL = Puntero al elemento anterior
;             B-DE = Puntero al elemento siguiente
;    Regist:  F

L_PNTS:	call	GET_P2
	ld	(LPNTS_A),a
	ld	a,(ix+3)
	call	PUT_P2

	ld	l,(ix+4)
	ld	h,(ix+5)
	push	ix,hl
	pop	ix
	ld	a,(ix)
	ld	l,(ix+1)
	ld	h,(ix+2)
	ld	b,(ix+3)
	ld	e,(ix+4)
	ld	d,(ix+5)

	push	af
	ld	a,(LPNTS_A)
	call	PUT_P2
	pop	af,ix
	ret

LPNTS_A:	db	0


;--- L_FWD:   Avanza el puntero de una lista
;    Entrada: IX = Direccion del descriptor de la tabla
;    Salida:  Cy = 1 si el elemento apuntado previamente era el ultimo
;             A-HL = Nuevo puntero
;    Regist:  AF, HL

L_FWD:	call	L_PNTS
	ld	a,d
	or	e
	scf
	ret	z

	ld	(ix+3),b
	ld	(ix+4),e
	ld	(ix+5),d
	push	bc,de
	pop	hl,af
	or	a
	ret


;--- L_REW:   Retrocede el puntero de una lista
;    Entrada: IX = Direccion del descriptor de la tabla
;    Salida:  Cy = 1 si el elemento apuntado previamente era el primero
;             A-HL = Nuevo puntero
;    Regist:  B, DE

L_REW:	call	L_PNTS
	ld	b,a
	ld	a,h
	or	l
	scf
	ret	z

	ld	(ix+3),b
	ld	(ix+4),l
	ld	(ix+5),h
	ld	a,b
	or	a
	ret


;--- L_SETP:  Establece el puntero de una lista
;    Entrada: IX = Direccion del descriptor de la tabla
;             A-HL = Nuevo puntero
;    Salida:  -
;    Regist:  -

L_SETP:	ld	(ix+3),a
	ld	(ix+4),l
	ld	(ix+5),h
	ret


;--- L_SETPF: Establece el puntero de una lista al primer elemento
;    Entrada: IX = Direccion del descriptor de la tabla
;    Salida:  A-HL = Puntero al primer elemento
;    Regist:  F

L_SETPF:	ld	a,(ix)
	ld	(ix+3),a
	ld	l,(ix+1)
	ld	(ix+4),l
	ld	h,(ix+2)
	ld	(ix+5),h
	ret


;--- L_SETPL: Establece el puntero de una lista al ultimo elemento
;    Entrada: IX = Direccion del descriptor de la tabla
;    Salida:  A-HL = Puntero al primer elemento
;    Regist:  F

L_SETPL:	ld	a,(ix+6)
	ld	(ix+3),a
	ld	l,(ix+7)
	ld	(ix+4),l
	ld	h,(ix+8)
	ld	(ix+5),h
	ret


;--- L_EMPTY: Comprueba si una lista esta vacia
;    Entrada: IX = Direccion del descriptor de la tabla
;    Salida:  Cy = 1 si la lista esta vacia
;    Regist:  -

L_EMPTY:	ld	(LEMPT_A),a
	ld	a,(ix+9)
	or	(ix+10)
	or	(ix+11)
	ld	a,(LEMPT_A)
	scf
	ret	z
	ccf
	ret

LEMPT_A:	db	0


;--- L_SEEK:  Establece el puntero de una lista en un elemento determinado
;    Entrada: IX = Direccion del descriptor de la tabla
;             B-DE = Numero de elemento (el primero es 1)
;    Salida:  Cy = 1 si ese elemento no existe
;    Regist:  A

L_SEEK:	call	L_EMPTY
	ret	c
	ld	c,b
	call	L_SETPF
	ld	b,0	;B-HL = Numero del elemnto actual
	ld	hl,1

LSEEK_B:	ld	a,b
	cp	c
	jr	nz,LSK_NEXT
	call	COMP
	ccf
	ret	z

LSK_NEXT:	push	bc,de,hl
	call	L_FWD
	pop	hl,de,bc
	ret	c
	inc	de
	ld	a,d
	or	e
	jr	nz,LSEEK_B
	inc	b
	jr	LSEEK_B


;--- L_GETF: Obtiene el puntero del primer elmento de una lista
;    Entrada: IX = Direccion del descriptor de la tabla
;    Salida:  A-HL = Puntero del primer elemento
;    Regist:  -

L_GETF:	ld	a,(ix)
	ld	l,(ix+1)
	ld	h,(ix+2)
	ret


;--- L_GETL: Obtiene el puntero del ultimo elemento de una lista
;    Entrada: IX = Direccion del descriptor de la tabla
;    Salida:  A-HL = Puntero del ultimo elemento
;    Regist:  -

L_GETL:	ld	a,(ix+6)
	ld	l,(ix+7)
	ld	h,(ix+8)
	ret


;--- L_GETP: Obtiene el puntero del elemento actual de una lista
;    Entrada: IX = Direccion del descriptor de la tabla
;    Salida:  A-HL = Puntero actual
;    Regist:  -

L_GETP:	ld	a,(ix+3)
	ld	l,(ix+4)
	ld	h,(ix+5)
	ret


;--- L_GETN: Obtiene el numero de elementos de una lista
;    Entrada: IX = Direccion del descriptor de la tabla
;    Salida:  A-HL = Numero de elementos de la lista
;             Cy = 1 si la lista esta vacia
;    Regist:  -

L_GETN:	call	L_EMPTY
	ld	l,(ix+9)
	ld	h,(ix+10)
	ld	a,(ix+11)
	ret


;--- L_GETCE: Obtiene el elemento actualmente apuntado de la lista
;    Entrada: IX = Puntero al descriptor de la tabla
;             DE = Direccion en la que dejar el elemento
;    Salida:  BC = Longitud del elemento
;             Cy = 1 si la lista esta vacia
;    Regist:  AF, HL

L_GETCE:	call	L_GETP
	jp	L_GETE


;--- L_GETE:  Obtiene un elemento de la lista
;    Entrada: A-HL = Puntero al elemento
;             DE = Direccion en la que dejar el elemento
;             IX = Puntero al descriptor de la tabla
;    Salida:  BC = Longitud del elemento
;             Cy = 1 si la lista esta vacia
;    Regist:  AF, HL

L_GETE:	call	L_EMPTY
	ret	c
	push	af
	call	GET_P2
	ld	(LGET_A),a
	pop	af
	call	PUT_P2

	push	de,de
	dec	hl
	ld	d,(hl)
	dec	hl
	ld	e,(hl)	;DE = Longitud incluyendo punteros
	ld	bc,8
	add	hl,bc	;HL = Direccion tras los punteros
	ex	de,hl
	ld	bc,6
	or	a
	sbc	hl,bc
	ex	de,hl
	push	de
	pop	bc	;BC = Longitud sin incluir punteros
	pop	de
	push	bc
	ldir
	pop	bc

	pop	de
	ld	a,(LGET_A)
	call	PUT_P2
	or	a
	ret

LGET_A:	db	0


;--- L_ISF:   Comprueba si el elemento apuntado es el primero de la tabla
;    Entrada: IX = Puntero al descriptor de la tabla
;    Salida:  Cy = 1 si es el primer elemento
;    Regist:  AF

L_ISF:	call	L_EMPTY
	ccf
	ret	nc

	ld	a,(ix)
	cp	(ix+3)
	jr	nz,LISF2
	ld	a,(ix+1)
	cp	(ix+4)
	jr	nz,LISF2
	ld	a,(ix+2)
	cp	(ix+5)
	jr	nz,LISF2
	scf
	ret
LISF2:	or	a
	ret


;--- L_ISL:   Comprueba si el elemento apuntado es el ultimo de la tabla
;    Entrada: IX = Puntero al descriptor de la tabla
;    Salida:  Cy = 1 si es el primer elemento
;    Regist:  AF

L_ISL:	call	L_EMPTY
	ccf
	ret	nc

	ld	a,(ix+6)
	cp	(ix+3)
	jr	nz,LISL2
	ld	a,(ix+7)
	cp	(ix+4)
	jr	nz,LISL2
	ld	a,(ix+8)
	cp	(ix+5)
	jr	nz,LISL2
	scf
	ret
LISL2:	or	a
	ret


;--- L_PUTE:  Introduce un elemento en la lista
;    Entrada: IX = Puntero al descriptor de la tabla
;             A  = Donde insertar el elemento:
;                  0: Despues del elemento actualmente apuntado
;                  1: Antes del elemento actualmente apuntado
;                  2: Antes del primer elemento (al principio de la lista)
;                  3: Despues del ultimo elemento (al final de la lista)
;             BC = Longitud del elemento
;             HL = Direccion del elemento
;    Salida:  Cy = 1 si no hay memoria libre
;    Regist:  AF, BC, DE, HL

L_PUTE:	ld	(LPUT_M),a	;Guarda metodo
	ld	(LPUT_E),hl	;Guarda dir. origen del nuevo elemento
	ld	(LPUT_T),bc	;Guarda tamanyo del bloque sin punt.
	call	GET_P2
	ld	(LPUT_PS),a	;Guarda seg. original en p. 2

	push	bc	;Suma 6 al tamanyo para los punteros
	pop	hl
	ld	bc,6
	add	hl,bc

	push	ix
	call	MALLOC
	pop	ix
	ret	c
	ld	(LPUT_D),hl	;Guarda direccion
	ld	a,b
	ld	(LPUT_S),a	;Guarda segmento

	call	L_EMPTY
	jr	nc,LPUT2

	;--- Actualizacion de punteros si la lista esta vacia
	;    (en este caso, el metodo es irrelevante)

	ld	a,(LPUT_S)
	ld	hl,(LPUT_D)
	ld	(ix),a	;Coloca la dir. del elemento recien
	ld	(ix+1),l	;creado como el primero, actual y ultimo
	ld	(ix+2),h
	ld	(ix+3),a
	ld	(ix+4),l
	ld	(ix+5),h
	ld	(ix+6),a
	ld	(ix+7),l
	ld	(ix+8),h

	xor	a	;Punteros anterior y siguiente a 0
	ld	hl,0
	ld	b,0
	ld	de,0

	jp	LPUT_F

	;--- Si la lista no estaba vacia, comprobamos el metodo

LPUT2:	ld	a,(LPUT_M)
	and	3
	jp	z,LPUT_M0
	dec	a
	jr	z,LPUT_M1
	dec	a
	jp	z,LPUT_M2
	jp	LPUT_M3

	;--- Metodo 0: a continuacion del elemento actual
	;    Pasos a seguir:
	;    - P. anterior (e. nuevo) = d. elem. actual
	;    - P. siguiente (e. nuevo) = d. elem. siguiente al actual
	;    - P. anterior (e. siguiente al actual) = d. elem. nuevo
	;    - P. siguiente (e. actual) = d. elemento nuevo

LPUT_M0:	call	L_ISL	;Si elem. actual = ultimo,
	jp	c,LPUT_M3	;saltamos directamente al metodo 3

	call	L_FWD	;Dir. elem. siguiente a la pila
	call	L_GETP
	push	af,hl
	call	L_REW

	call	L_GETP	;Dir. elem. actual a la pila
	push	af,hl

	call	PUT_P2	;P. siguiente (e. actual) = d. el. nuevo
	inc	hl
	inc	hl
	inc	hl
	ld	a,(LPUT_S)
	ld	de,(LPUT_D)
	ld	(hl),a
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d

	pop	de,bc,hl,af
	push	af,hl,bc,de

	call	PUT_P2	;P. anterior (el. sig.) = d. el. nuevo
	ld	a,(LPUT_S)
	ld	de,(LPUT_D)
	ld	(hl),a
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d

	pop	hl,af	;Recupera dir. antiguo actual
	pop	de,bc	;Recupera dir. antiguo siguiente
	jp	LPUT_F

	;--- Metodo 1: antes del elemento actual
	;    Pasos a seguir:
	;    - P. siguiente (e. nuevo) = d. elem. actual
	;    - P. anterior (e. nuevo) = d. elem. anterior al actual
	;    - P. siguiente (e. anterior al actual) = d. elem. nuevo
	;    - P. anterior (e. actual) = d. elemento nuevo

LPUT_M1:	call	L_ISF	;Si elem. actual = primero,
	jr	c,LPUT_M2	;saltamos directamente al metodo 2

	call	L_REW
	call	L_GETP	;Dir. elem. anterior la pila
	push	af,hl
	call	L_FWD	;Dir. elem. actual a la pila
	call	L_GETP
	push	af,hl

	call	PUT_P2	;P. anterior (e. actual) = d. el. nuevo
	ld	a,(LPUT_S)
	ld	de,(LPUT_D)
	ld	(hl),a
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d

	pop	de,bc,hl,af
	push	af,hl,bc,de

	call	PUT_P2	;P. siguiente (el. ant.) = d. el. nuevo
	inc	hl
	inc	hl
	inc	hl
	ld	a,(LPUT_S)
	ld	de,(LPUT_D)
	ld	(hl),a
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d

	pop	de,bc	;Recupera dir. antiguo actual
	pop	hl,af	;Recupera dir. antiguo anterior
	jr	LPUT_F

	;--- Metodo 2: antes del primer elemento

LPUT_M2:	ld	a,(ix)
	call	PUT_P2
	ld	l,(ix+1)
	ld	h,(ix+2)	;HL = Dir. primer elemento

	push	af,hl
	ld	a,(LPUT_S)	;El puntero al anterior del que
	ld	(hl),a	;antes era el primer antes era 0,
	ld	de,(LPUT_D)	;ahora apunta al nuevo elemento
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d

	ld	a,(LPUT_S)	;El primer elemento es ahora el nuevo
	ld	(ix),a
	ld	hl,(LPUT_D)
	ld	(ix+1),l
	ld	(ix+2),h

	pop	de,bc	;El nuevo elemento tendra como punteros:
	ld	a,0	;Anterior: 0
	ld	hl,0	;Siguiente: el antiguo primer elemento
	jp	LPUT_F

	;--- Metodo 3: despues del ultimo elemento

LPUT_M3:	ld	a,(ix+6)
	call	PUT_P2
	ld	l,(ix+7)
	ld	h,(ix+8)	;HL = Dir. ultimo elemento

	push	af,hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(LPUT_S)	;El puntero al siguiente del que
	ld	(hl),a	;antes era el ultimo antes era 0,
	ld	de,(LPUT_D)	;ahora apunta al nuevo elemento
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d

	ld	a,(LPUT_S)	;El ultimo elemento es ahora el nuevo
	ld	(ix+6),a
	ld	hl,(LPUT_D)
	ld	(ix+7),l
	ld	(ix+8),h

	pop	hl,af	;El nuevo elemento tendra como punteros:
	ld	b,0	;Anterior: el antiguo ultimo elemento
	ld	de,0	;Siguiente: 0
	jp	LPUT_F

	;--- FIN:
	;    - Pone los punteros A-HL y B-DE como anterior y siguiente
	;      en el elemento recien creado
	;    - Copia el elemento recien creado a la memoria reservada
	;    - Incrementa el numero de elementos de la lista
	;    - Restaura el segmento original en pag. 2 y termina

LPUT_F:	push	af
	ld	a,(LPUT_S)
	call	PUT_P2

	pop	af
	push	ix
	ld	ix,(LPUT_D)
	ld	(ix),a
	ld	(ix+1),l
	ld	(ix+2),h
	ld	(ix+3),b
	ld	(ix+4),e
	ld	(ix+5),d
	pop	ix

	ld	de,(LPUT_E)	;Copia el elemento a la memoria reserv.
	ld	hl,(LPUT_D)
	ld	bc,6
	add	hl,bc
	ex	de,hl
	ld	bc,(LPUT_T)
	ldir

	ld	l,(ix+9)	;Incrementa num de elementos
	ld	h,(ix+10)
	inc	hl
	ld	(ix+9),l
	ld	(ix+10),h
	ld	a,h
	or	l
	jr	nz,LPUT_F2
	ld	a,(ix+11)
	inc	a
	ld	(ix+11),a

LPUT_F2:	ld	a,(LPUT_PS)
	call	PUT_P2
	or	a
	ret

LPUT_PS:	db	0	;Segmento original en p. 2
LPUT_S:	db	0	;Seg. del nuevo elemento
LPUT_D:	dw	0	;Dir. del nuevo elemento
LPUT_T:	dw	0	;Tamanyo del nuevo elemento
LPUT_M:	db	0	;Metodo
LPUT_E:	dw	0	;Dir. original del nuevo elemento


;--- L_DELE:  Borra un elemento en la lista
;    Entrada: IX = Puntero al descriptor de la tabla
;             A  = Que elemento borrar:
;                  0: El actual
;                  1: El primero
;                  2: El ultimo
;    Salida:  Cy = 1 si la lista estaba vacia
;             El elemento actual pasa a ser el siguiente
;             (si era el ultimo, apunta al nuevo ultimo)
;    Regist:  AF, BC, DE, HL

L_DELE:	call	L_EMPTY
	ret	c

	ld	(LDEL_M),a	;Guarda metodo
	call	GET_P2
	ld	(LDEL_PS),a
	call	L_PNTS
	ld	(LDEL_SA),a
	ld	(LDEL_DA),hl	;Guarda seg + dir del anterior
	ld	a,b
	ld	(LDEL_SS),a	;Guarda seg + dir del siguiente
	ld	(LDEL_DS),de

	call	L_GETN	;Termina directamente
	or	a	;si solo hay un elemento
	jr	nz,LDEL3
	dec	hl
	ld	a,h
	or	l
	jr	nz,LDEL3
	call	L_GETP
	jp	L_DELF

	;--- Decide que hacer segun el metodo

LDEL3:	ld	a,(LDEL_M)
	and	3
	jr	z,LDEL_M0
	dec	a
	jr	z,LDEL_M1
	jr	LDEL_M2

	;--- Metodo 1: borra el primero

LDEL_M1:	call	L_ISF	;Si el actual era el primero,
	call	c,L_FWD	;hay que avanzarlo

LDEL_M11:	call	L_GETP
	push	af,hl	;Puntero original a la pila
	call	L_SETPF
	push	af,hl	;Puntero a borrar (primero) a la pila
	call	L_FWD

	ld	(ix),a	;El que antes era el segundo es
	ld	(ix+1),l	;ahora el primero
	ld	(ix+2),h
	call	PUT_P2
	ld	(hl),0	;El punt. anterior del nuevo primero
	inc	hl	;es ahora 0
	ld	(hl),0
	inc	hl
	ld	(hl),0
	dec	hl
	dec	hl

LDEL_M12:	pop	de,bc	;Puntero a borrar
	pop	hl,af	;Puntero original
	push	bc,de
	call	L_SETP	;Restablece puntero original
	pop	hl,af
	jr	L_DELF

	;--- Metodo 2: borra el ultimo

LDEL_M2:	call	L_ISL	;Si el actual era el ultimo,
	call	c,L_REW	;hay que retrocederlo

LDEL_M22:	call	L_GETP
	push	af,hl	;Puntero original a la pila
	call	L_SETPL
	push	af,hl	;Puntero a borrar (ultimo) a la pila
	call	L_REW

	ld	(ix+6),a	;El que antes era el penultimo es
	ld	(ix+7),l	;ahora el pultimo
	ld	(ix+8),h
	call	PUT_P2
	push	hl
	inc	hl
	inc	hl
	inc	hl
	ld	(hl),0	;El punt. siguiente del nuevo ultimo
	inc	hl	;es ahora 0
	ld	(hl),0
	inc	hl
	ld	(hl),0
	pop	hl

	jr	LDEL_M12

	;--- Metodo 0: borra el actual

LDEL_M0:	call	L_GETP	;Si el elemento actual es el primero
	call	L_ISF	;o el ultimo, salta directamente al
	jr	c,LDEL_M11	;metodo 1 o el 2
LDELM01:	call	L_ISL
	jr	c,LDEL_M22

	ld	a,(LDEL_SA)	;Ahora el puntero al siguiente del
	call	PUT_P2	;anterior el la dir. del siguiente
	ld	hl,(LDEL_DA)
	inc	hl
	inc	hl
	inc	hl
	ld	a,(LDEL_SS)
	ld	(hl),a
	inc	hl
	ld	de,(LDEL_DS)
	ld	(hl),e
	inc	hl
	ld	(hl),d

	ld	a,(LDEL_SS)	;Ahora el puntero al anterior del
	call	PUT_P2	;siguiente es la dir. del anterior
	ld	hl,(LDEL_DS)
	ld	a,(LDEL_SA)
	ld	(hl),a
	inc	hl
	ld	de,(LDEL_DA)
	ld	(hl),e
	inc	hl
	ld	(hl),d

	call	L_GETP	;El puntero queda apuntando al siguiente
	push	af,hl
	call	L_FWD
	pop	hl,af
	jr	L_DELF

	;FIN:
	;- Borra el elemento A-HL
	;- Decrementa el contador de elementos
	;- Restaura segmento original en pag. 2 y termina

L_DELF:	ld	b,a
	call	MFREE

	call	L_GETN	;Decrementa contador de elementos
	ld	b,a
	ld	a,h
	or	l
	dec	hl
	ld	(ix+9),l
	ld	(ix+10),h
	jr	nz,L_DELF2
	dec	b
	ld	(ix+11),b

	;--- Si solo habia un elemento,
	;    ahora la lista esta vacia y borramos los punteros

L_DELF2:	call	L_EMPTY
	jr	nc,L_DELF3

	call	L_INIT
	jr	L_DELF4

	;--- Si ahora solo hay un elemento,
	;    ponemos puntero actual = primero

L_DELF3:	call	L_GETN
	or	a
	jr	nz,L_DELF4
	dec	hl
	ld	a,h
	or	l
	call	z,L_SETPF

	;--- Restauramos segmento y terminamos

L_DELF4:	ld	a,(LDEL_PS)
	call	PUT_P2
	or	a
	ret

LDEL_PS:	equ	LPUT_PS	;Reciclamos variables
LDEL_M:	equ	LPUT_M
LDEL_SA:	equ	LPUT_S
LDEL_DA:	equ	LPUT_D
LDEL_SS:	equ	LPUT_T
LDEL_DS:	equ	LPUT_E


;--- L_PUSH/L_ENQ:  Inserta un elemento en la lista considerando
;                   que es una pila o una cola (lo inserta al final)
;    Entrada: IX = Puntero al descriptor de la tabla
;             BC = Longitud del elemento
;             HL = Direccion del elemento
;    Salida:  Cy = 1 si no hay memoria libre
;    Regist:  AF, BC, DE, HL

L_PUSH:	ld	a,3
	jp	L_PUTE

L_ENQ:	equ	L_PUSH


;--- L_POP:   Extrae (borra) un elemento de la lista considerando
;             que es una pila (extrae el ultimo)
;    Entrada: IX = Puntero al descriptor de la tabla
;    Salida:  Cy = 1 si la lista estaba vacia
;             El penultimo elemento pasa a ser el ultimo
;    Regist:  AF, BC, DE, HL

L_POP:	ld	a,2
	jp	L_DELE


;--- L_DEQ:   Extrae (borra) un elemento de la lista considerando
;             que es una cola (extrae el primero)
;    Entrada: IX = Puntero al descriptor de la tabla
;    Salida:  Cy = 1 si la lista estaba vacia
;             El segundo elemento pasa a ser el primero
;    Regist:  AF, BC, DE, HL

L_DEQ:	ld	a,1
	jp	L_DELE


;--- L_DEST:  Destruye una lista
;    Entrada: IX = Puntero al descriptor de la tabla
;    Regist:  AF, BC, DE, HL

L_DEST:	call	L_POP
	jr	nc,L_DEST
	ret


;--- L_SAVE:  Guarda una lista en un fichero (requiere DOS 2).
;    Entrada: IX = Puntero al descriptor de la tabla
;             DE = Ruta + nombre del fichero y B=255
;                  (creara ese fichero), o
;             B  = FH de un fichero abierto
;                  (grabara en ese fichero a partir del puntero actual)
;             HL = Bufer de tamanyo = elemento mas grande lista + 2
;    Salida:  Cy = 1 si hay error de disco
;             A  = Error de disco, si lo hay
;             Si B=255, el fichero es cerrado al final
;    Formato del fichero:
;    Num. elementos (3 bytes) + tam. elem (2 bytes) + elem. + ... + 0 + 0
;    Regist:  F, BC, DE, HL

L_SAVE:	ld	(LS_BUFD),hl	;Guarda puntero original de la lista
	call	L_GETP
	push	af,hl

	ld	a,255
	ld	(LSAVFLG),a
	ld	a,b
	cp	255
	jr	nz,LSAVOK1

	;--- Inicializacion del fichero

	xor	a	;Crea y abre fichero
	ld	bc,_CREATE
	call	5
	jr	nz,LSAVE2
	ld	(LSAVFLG),a
	ld	a,b
LSAVOK1:	ld	(FHLS),a

	call	L_GETN	;Escribe num. de elementos en el fichero
	ld	de,(LS_BUFD)
	ex	de,hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	ld	(hl),a
	ld	bc,3
	call	F_WRITE

	call	L_EMPTY	;Termina si la lista esta vacia
	jr	c,LSAV_F
	call	L_SETPF	;Puntero al primer elemento

	;--- Bucle de grabacion de elementos

LSAV_B:	ld	de,(LS_BUFD)	;Pone tamanyo + elemento en (LS_BUFD)
	inc	de	;y lo graba en el fichero
	inc	de
	call	L_GETCE
	dec	de
	ld	a,b
	ld	(de),a
	dec	de
	ld	a,c
	ld	(de),a
	inc	bc
	inc	bc
	call	F_WRITE

	call	L_FWD	;Siguiente elemento, si quedan
	jr	nc,LSAV_B

	;--- Cierre del fichero y finalizacion

LSAV_F:	ld	hl,(LS_BUFD)	;Escribe dos bytes 0 como terminacion
	ld	(hl),0
	inc	hl
	ld	(hl),0
	ld	bc,2
	call	F_WRITE

	ld	a,(LSAVFLG)
	or	a
	jr	nz,LSAVOK2

	ld	a,(FHLS)	;Cierra el fichero si lo habiamos creado
	ld	b,a
	ld	c,_CLOSE
	call	5

LSAVOK2:	pop	hl,af	;Restaura puntero de la lista
	call	L_SETP

	xor	a
	ret

	;--- Error: restaura puntero de la lista y termina

LSAV_E:	push	af
	ld	a,(LSAVFLG)
	or	a
	ld	a,(FHLS)
	ld	b,a
	ld	c,_CLOSE
	call	z,5
	pop	af

LSAVE2:	ld	b,a
	pop	hl,af
	call	L_SETP
	ld	a,b
	scf
	ret

	;--- Subrutina F_WRITE:
	;    Escribe BC bytes desde la dir. (LS_BUFD) en el fichero (FHLS)

F_WRITE:	push	bc
	pop	hl
	ld	a,(FHLS)
	ld	b,a
	ld	c,_WRITE
	ld	de,(LS_BUFD)
	call	5
	ret	z
	pop	de
	jr	LSAV_E

FHLS:	db	0
LS_BUFD:	dw	0
LSAVFLG:	db	0	;0 si hemos creado el fichero, 255 si no


;--- L_LOAD:  Carga una lista desde un fichero (requiere DOS 2).
;    Entrada: IX = Puntero al descriptor de la tabla
;                  (el fichero se anyadira al final de la misma)
;             DE = Ruta + nombre del fichero y B=255
;                  (creara ese fichero), o
;             B  = FH de un fichero abierto
;                  (cargara de ese fichero a partir del puntero actual)
;             HL = Bufer de tamanyo = elemento mas grande lista + 2
;    Salida:  Cy = 1 si hay error de disco
;             A  = Error de disco, si lo hay
;                  1 si el error es que no queda memoria
;                  2 si el error es que el elemento es demasiado grande
;             B-DE = Numero de elementos leidos del fichero si no hay error
;             Si B=255, el fichero es cerrado al final
;    Formato del fichero:
;    Num. elementos (3 bytes) + tam. elem (2 bytes) + elem. + ... + 0 + 0
;    Regist:  F, BC, DE, HL

LLOAFLG:	equ	LSAVFLG

L_LOAD:	ld	(LL_BUFD),hl
	ld	(LL_SP),sp

	ld	a,255
	ld	(LLOAFLG),a
	ld	a,b
	cp	255
	jr	nz,LLOAOK1

	;--- Apertura del fichero

	xor	a	;Abre el fichero
	ld	c,_OPEN
	call	5
	jr	nz,LLOADE2
	ld	(LLOAFLG),a
	ld	a,b
LLOAOK1:	ld	(FHLS),a

	ld	bc,3	;Lee y guarda numero de elementos
	call	F_READ
	push	ix
	ld	ix,(LL_BUFD)
	ld	l,(ix)
	ld	h,(ix+1)
	ld	a,(ix+2)
	ld	(LL_NUM),hl
	ld	(LL_NUM+2),a
	or	h
	or	l
	pop	ix
	jr	z,LLOAD_F	;Termina directamente si no hay elementos

	;--- Bucle de carga de elementos

LLOAD_B:	ld	bc,2
	call	F_READ
	ld	hl,(LL_BUFD)	;Lee el elemento y lo inserta
	push	hl	;al final de la lista
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	a,b	;Fin si es la marca de fin (dos ceros)
	or	c
	jr	z,LLOAD_F
	dec	bc
	inc	b
	ld	a,b
	dec	b
	inc	bc
	and	%11000000	;Error si el elemento es demasiado
	ld	a,2	;grande
	jr	nz,LLOAD_E
	push	bc
	call	F_READ
	pop	bc,hl
	ld	a,3
	call	L_PUTE
	ld	a,1
	jr	c,LLOAD_E
	jr	LLOAD_B	;Siguiente elemento

	;--- Cierre del fichero y finalizacion

LLOAD_F:	ld	a,(LLOAFLG)
	or	a
	ld	a,(FHLS)	;Cierra el fichero si lo habiamos creado
	ld	b,a
	ld	c,_CLOSE
	call	z,5

	ld	de,(LL_NUM)
	ld	a,(LL_NUM+2)
	ld	b,a

	ld	sp,(LL_SP)
	xor	a
	ret

	;--- Error: cierra fichero y termina

LLOAD_E:	push	af
	ld	a,(LLOAFLG)
	or	a
	ld	a,(FHLS)
	ld	b,a
	ld	c,_CLOSE
	call	z,5
	pop	af

LLOADE2:	scf
	ld	sp,(LL_SP)
	ret

	;--- Subrutina F_READ:
	;    Lee BC bytes a la dir. (LS_BUFD) desde el fichero (FHLS)

F_READ:	push	bc
	pop	hl
	ld	a,(FHLS)
	ld	b,a
	ld	c,_READ
	ld	de,(LS_BUFD)
	call	5
	jr	nz,LLOAD_E
	ret

LL_BUFD:	equ	LS_BUFD
LL_NUM:	ds	3
LL_SP:	dw	0

	;--- Preubas

P:	ld	ix,TABLA	;Primero
	ld	a,0
	ld	bc,100
	ld	hl,E1
	call	L_PUTE

	ld	a,2	;Sust. al primero
	ld	bc,100
	ld	hl,E2
	call	L_PUTE

	ld	a,3	;Sust. al ultimo
	ld	bc,100
	ld	hl,E3
	call	L_PUTE

	ld	a,0	;Despues del corriente (el 1)
	ld	bc,100
	ld	hl,E4
	call	L_PUTE

	ld	a,1	;Antes del corriente (el 1)
	ld	bc,100
	ld	hl,E5
	call	L_PUTE

	ld	de,FILERO	;Graba en filamen
	ld	hl,#1000
	ld	ix,TABLA
	ld	b,0
	call	L_SAVE

	ld	ix,TABLA
	call	L_DEST	;A la mierda (muera todo)

	ld	ix,TABLA
	ld	de,FILERO	;Carga del filamen
	ld	hl,#1000
	ld	b,255
	call	L_LOAD

	ds	5

	;---

	xor	a
	call	L_DELE	;Borra el actual

	ld	a,1
	call	L_DELE	;Borra el primero

	ld	a,2
	call	L_DELE	;Borra el ultimo
	ds	34

TABLA:	ds	12

E1:	db	"1 - Pongo este primero (referencia)."
	ds	100
E2:	db	"2 - Pongo este antes del primero."
	ds	100
E3:	db	"3 - Pongo este despues del ultimo."
	ds	100
E4:	db	"4 - Pongo este despues de la referencia."
	ds	100
E5:	db	"5 - Pongo este antes de la referencia."
	ds	100

FILERO:	db	"a:\preuba.pre",0
