;--- Gestor de memoria dinamica
;    Version C

	MACRO	div_hl	;Divide HL por 2
	srl	h
	rr	l
	ENDM

	macro	div_de	;Divide DE por 2
	srl	d
	rr	e
	endm

ENASLT	equ	0024h
EXTBIO	equ	0FFCAh

_OPEN	equ	43h
_CREATE	equ	44h
_CLOSE	equ	45h
_READ	equ	48h
_WRITE	equ	49h
_SEEK	equ	4Ah

	global	csv,cret,_InitMem,_FinishMem,_mmalloc,_mmfree
	global	_GetSegP2,_SetSegP2,_GetSegInfo,KK

	psect	text


;************************************************
;***  RUTINAS DE GESTION DE MEMORIA DINAMICA  ***
;************************************************

;--- INITMEM:  Inicializa el tinglado
;              - Reserva un segmento y lo limpia
;              - Inicializa la tabla de segmentos
;    Entrada:  -
;    Salida:   Cy=1 si no hay ningun segmento libre
;    Regist:   AF, BC, DE, HL

	;Copia la tabla de rutinas del mapeador

INITMEM:	ld	de,0402h
	call	EXTBIO
	ld	de,ALL_SEG
	ld	bc,30h
	ldir

	;Reserva un segmento e inicializa la tabla de idems

	ld	a,(0F344h)
	or	00100000B
	ld	b,a
	xor	a
	call	ALL_SEG
	ret	c

	ld	(TABSEGS+9),a	;El segmento reservado
	ld	a,b	;sera el numero 5 en la tabla de segmentos
	ld	(TABSEGS+8),a
	ld	a,5
	ld	(NUMSEGS),a

	ld	a,(0F344h)	;Rellena las 4 primeras entradas
	ld	(TABSEGS),a	;con los segmentos de TPA
	ld	(TABSEGS+2),a
	ld	(TABSEGS+4),a
	ld	(TABSEGS+6),a
	ld	(CURSLOT2),a
	call	GET_P0
	ld	(TABSEGS+1),a
	call	GET_P1
	ld	(TABSEGS+3),a
	call	GET_P2
	ld	(TABSEGS+5),a
	call	GET_P3
	ld	(TABSEGS+7),a

	ld	a,2
	ld	(CUR_S2),a

	call	GET_S2
	push	af
	ld	a,4
	call	PUT_S2
	call	CLEAN
	pop	af
	call	PUT_S2
	ret

	;Esta subrutina inicializa un segmento
	;Pone los cuatro primeros bytes de MAT a 0xFF,
	;y el resto a 0

CLEAN:	ld	hl,8000h
	ld	de,8001h
	ld	bc,3
	ld	(hl),255
	ldir
	inc	hl
	inc	de
	ld	bc,16384-5
	ld	(hl),0
	ldir
	ret

NUMSEGS:	defb	0	;Num. de segmentos reservados
TABSEGS:	defs	255	;Tabla de segmentos reservados

	;Rutinas de soporte del mapeador

ALL_SEG:	defs	3
FRE_SEG:	defs	3
RD_SEG:	defs	3
WR_SEG:	defs	3
CAL_SEG:	defs	3
CALLS:	defs	3
PUT_PH:	defs	3
GET_PH:	defs	3
PUT_P0:	defs	3
GET_P0:	defs	3
PUT_P1:	defs	3
GET_P1:	defs	3
PUT_P2:	defs	3
GET_P2:	defs	3
PUT_P3:	defs	3
GET_P3:	defs	3


;--- FINISH   Libera toda la memoria reservada
;    Entrada  -
;    Salida   -
;    Regist   AF, BC, DE, HL

FINISH:	ld	c,4
	ld	de,TABSEGS+8
	ld	hl,NUMSEGS

BUC_FM:	ld	a,(de)
	ld	b,a	;B = Slot
	inc	de
	ld	a,(de)	;A = Segmento
	inc	de
	push	bc
	push	de
	push	hl
	call	FRE_SEG
	pop	hl
	pop	de
	pop	bc
	inc	c
	ld	a,c
	cp	(hl)
	jr	nz,BUC_FM

	ret


;--- MAXMIN   Encuentra el bloque libre mas pequenyo
;             de tamanyo igual o superior a uno requerido
;             en un determinado segmento
;    Entrada  HL = Tamanyo requerido
;             Segmento a examinar conectado en pagina 2
;    Salida   HL = Tamanyo del bloque encontrado
;             DE = Direccion del bloque encontrado,
;                  en pagina 2 (con desplazamiento 0x8000)
;             Cy = 1 si no hay bloques libres de al menos
;                  el tamanyo requerido en el segmento
;    Regist   AF, BC, DE, HL

MAXMIN:	ld	(BUSCAR),hl
	ld	a,4	;Empieza por el cuarto byte MAT,
	ld	(BYTE),a	;que apunta a 0x100
	xor	a
	ld	(BIT1),a
	ld	hl,7FFFh
	ld	(MIN_FND),hl

	;Busca un bloque libre

BUSLIB:	ld	a,(BIT1)	;C=Contador de bits de un byte
	ld	c,a
	ld	a,(BYTE)	;L=Contador de bytes
	or	a
	jr	z,BL_FIN
	ld	l,a
	ld	h,80h	;HL=Direccion de ese byte MAT

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
	jr	nz,BL_FIN	;Fin si se llega a 0x8100 (fin de MAT)
	ld	c,0
	ld	b,(hl)
	jr	BUC_BL1	;Siguiente byte si se ha llegado al bit 8

	;Bloque libre encontrado  comprueba tamanyoo

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
	ld	(BIT1),a
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

	;Fin de MAT encontrado	devuelve HL, DE y Cy adecuados

BL_FIN:	ld	hl,(MIN_FND)
	ld	de,7FFFh	;Si DE sigue teniendo el valor inicial
	call	COMP	;0x7FFF, es que no se ha encontrado
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

BUSCAR:	defw	0	;Tamanyo requerido
MIN_FND:	defw	0	;Tamanyo del mejor bloque encontrado
BYTE:	defb	0	;Byte MAT que esta siendo examinado
BIT1:	defb	0	;Bit que esta siendo examinado
BYTE2:	defb	0	;Byte MAT del ultimo bloque libre encontrado
BIT2:	defb	0	;Bit de inicio del ultimo b. libre encontrado
BYTEFND:	defb	0	;Byte MAT del mejor bloque encontrado
BITFND:	defb	0	;Bit de inicio del mejor bloque encontrado


;--- MALLOC   Reserva un bloque de memoria
;    Entrada  HL = Tamanyoo requerido
;    Salida   HL = Direccion, empezando en 0x8000
;             B  = Segmento
;             Cy = 1 si hay error (no queda memoria libre)
;    Regist   AF, BC, DE, HL

MALLOC:	push	ix,iy
	call	MALLOC2
	pop	iy,ix
	ret

MALLOC2:	dec	hl	;Error si el tamanyo requerido
	ld	a,h	;es >16384-256 (0x3F00)
	and	11000000B
	scf
	ret	nz

	;Transforma tamanyo declarado en tamanyo real

	inc	hl
	inc	hl
	inc	hl
	ld	(TAMREQ),hl
	ld	a,l
	and	111B
	jr	z,OKTREAL
	ld	a,l
	and	11111000B
	add	a,8
	ld	l,a
OKTREAL:	ld	(TAMREAL),hl

	;Inicializa algunas variables

	xor	a
	ld	(SEGFND),a
	call	GET_S2
	push	af

	ld	hl,7FFFh
	ld	(TAMFND),hl

	ld	a,(NUMSEGS)
	ld	b,a	;B = Num. de segmentos
	ld	c,4	;C = Seg. actual
	ld	hl,TABSEGS+8

	;Recorre todos los segmentos reservados, buscando
	;el que tiene el menor tamanyo de bloque posible
	;que sea >= que el tamanyo requerido

BUC_MALL:	push	hl,bc
	ld	a,c
	call	PUT_S2

	ld	hl,(TAMREQ)
	call	MAXMIN
	pop	bc
	jr	c,NEXT_MALL

	push	de	;Si el mejor bloque de este segmento
	ld	de,(TAMFND)	;es mas pequenyo que el ultimo mejor
	call	COMP	;bloque encontrado, cambiamos el viejo
	pop	de	;por el nuevo
	jr	c,NEXT_MALL
	ld	(TAMFND),hl
	ld	(DIRFND),de
	ld	a,c
	ld	(SEGFND),a

NEXT_MALL:	pop	hl
	inc	hl
	inc	hl
	inc	c
	ld	a,c
	cp	b
	jr	nz,BUC_MALL

	;Una vez examinados todos los slots, comprobamos si
	;hemos encontrado un bloque libre en alguno de ellos

FND_MALL:	ld	a,(SEGFND)
	or	a
	jr	z,NEW_SEG

	;Actualizamos MAT, ponemos el tamanyo del bloque
	;al principio del mismo y terminamos

	call	PUT_S2	;Conecta segmento encontrado a pag. 2

	ld	de,(TAMREAL)
	ld	hl,(DIRFND)

	ld	a,0C0h
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
	call	PUT_S2	;Restaura segmento original y termina

	or	a
	ret

	;Si no hay ningun bloque libre, reservamos un segmento nuevo.
	;Si no es posible, devolvemos un error.

NEW_SEG:	ld	a,(NUMSEGS)
	cp	255	;Error si ya habia 255 seg. reservados
	jr	z,MALL_ERR

	ld	a,(0F344h)	;Reserva segmento y lo inicializa
	or	00100000B
	ld	b,a
	xor	a
	call	ALL_SEG
	jr	c,MALL_ERR

	ld	e,a	;Registra nuevo segmento
	ld	d,b
	ld	a,(NUMSEGS)
	ld	c,a
	inc	a
	ld	(NUMSEGS),a
	ld	b,0
	ld	hl,TABSEGS
	add	hl,bc
	add	hl,bc
	ld	(hl),d
	inc	hl
	ld	(hl),e

	ld	a,(NUMSEGS)
	dec	a
	call	PUT_S2
	call	CLEAN

	;                        ;Ahora actua como si hubiera encontrado
	ld	(SEGFND),a	;un bloque libre en el segmento
	ld	hl,8100h	;que acabamos de reservar
	ld	(DIRFND),hl
	ld	hl,3F00h
	ld	(TAMFND),hl
	jp	FND_MALL

MALL_ERR:	pop	af	;Terminacion con error
	call	PUT_S2
	or	a
	ret

	;Esta subrutina comprueba si DE es 0

DE_ES_0:	ld	(SAVEA),a
	ld	a,d
	or	e
	ld	a,(SAVEA)
	ret

TAMREQ:	defw	0	;Tamanyo requerido
SEGFND:	defb	0	;Segmento del mejor bloque encontrado
TAMFND:	defw	0	;Tamanyo del mejor bloque encontrado
CURSLOT:	defb	0	;Segmento que esta siendo examinado
DIRFND:	defw	0	;Direccion del mejor bloque encontrado
TAMREAL:	defw	0	;Tamanyo declarado convertido a real
SAVEA:	defb	0


;--- MFREE  Libera un bloque de memoria
;    Entrada  B  = Segmento del bloque
;             HL = Direccion del bloque
;    Salida   -
;    Regist   AF, BC, DE, HL

MFREE:	push	ix,iy
	call	MFREE2
	pop	iy,ix
	ret

MFREE2:	ld	e,b
	call	GET_S2
	push	af
	ld	a,e
	call	PUT_S2

	res	1,l
	ld	e,(hl)
	inc	hl
	ld	d,(hl)	;DE = Tamanyo declarado
	inc	de	;!!!!!!!
	inc	de	;!!!!!!!
	ld	a,e
	and	111B	;Convierte a tamanyo real
	jr	z,OKTRE2
	ld	a,e
	and	11111000B
	add	a,8
	ld	e,a	;Ahora DE = Tamanyo real
OKTRE2:	res	0,l	;HL = Direccion real (multiplo de 8)

	ld	a,80h	;Pone bits de MAT a 0
	call	ADJMAT

	pop	af
	call	PUT_S2
	ret


;--- ADJMAT   Pone a 1 o a 0 los bits MAT correspondientes
;             a un bloque de memoria
;    Entrada  HL = Direccion (ha de ser multiplo de 8)
;             DE = Tamanyo real del bloque
;	A  = 0x80 para poner a 0 (entonces SETMAT_2 sera RES 0,B)
;		0xC0 para poner a 1 (entonces SETMAT_2 sera SET 0,B)
;    Salida   -
;    Regist   AF, BC, DE, HL

ADJMAT:	ld	(SETMAT_2+1),a

	xor	a
KK:	div_hl		;HL = HL / 8
	div_hl
	div_hl

	div_hl		;HL = HL / 8 y resto a A
	rr	a
	div_hl
	rr	a
	div_hl
	rr	a	;Ahora HL = Byte MAT y A = Bit
	ld	h,80h
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

SETMAT_2:	defb	0CBh,0	;Va poniendo a 1/0
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


;--- NOMBRE   COMP
;       Comparacion de HL con DE (16 bits en complemento a 2)
;    Entrada  HL, DE = numeros a comparar
;    Salida    C, NZ si HL > DE
;              C,  Z si HL = DE
;             NC, NZ si HL < DE
;    Regist   AF

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


;--- GET_S2   Devuelve el segmento logico conectado en la pagina 2
;    Entrada  -
;    Salida   A = Segmento en pagina 2
;    Regist   -

GET_S2:	ld	a,(CUR_S2)
	ret

CUR_S2:	defb	0


;--- PUT_S2   Conecta un segmento logico
;    Entrada  A = Numero de segmento
;    Salida   -
;    Regist   -

PUT_S2:	push	af
	push	hl
	push	bc
	ld	(CUR_S2),a
	ld	c,a
	ld	b,0
	ld	hl,TABSEGS
	add	hl,bc
	add	hl,bc
	ld	a,(CURSLOT2)
	ld	b,a
	ld	a,(hl)
	cp	b
	jr	z,PUTS22

	push	af	;Conecta el slot solo si no esta
	push	hl
	push	de
	push	ix
	push	iy
	ld	h,80h	;conectado ya
	call	ENASLT
	pop	iy
	pop	ix
	pop	de
	pop	hl
	pop	af
	ld	(CURSLOT2),a

PUTS22:	inc	hl	;Conecta segmento fisico
	ld	a,(hl)
	call	PUT_P2
	pop	bc
	pop	hl
	pop	af
	ret

CURSLOT2:	defb	0


;***************************
;***  INTERFAZ PARA C  *****
;***************************

;typedef struct mblock
;{  uchar slot;
;   uint address; }

;int InitMem()
;Devuelve -1 si no hay ningun segmento libre, 0 si no hay error

_InitMem:	call	INITMEM
	ld	hl,0
	ret	nc
	ld	hl,-1
	ret

;void FinishMem()

_FinishMem	equ	FINISH

;int mmalloc(mblock*)
;Devuelve -1 si no hay mas memoria libre

_mmalloc:	call	csv
	ld	l,(ix+6)
	ld	h,(ix+7)
	push	hl
	pop	iy	;IY = Puntero a MBLOCK
	ld	l,(iy+1)
	ld	h,(iy+2)
	call	MALLOC
	ex	de,hl
	ld	hl,-1
	jr	c,mmafin
	ld	(iy),b
	ld	(iy+1),e
	ld	(iy+2),d
	ld	hl,0
mmafin:	jp	cret

;void mmfree(mblock*)

_mmfree:	call	csv
	ld	l,(ix+6)
	ld	h,(ix+7)
	push	hl
	pop	ix
	ld	b,(iy)
	ld	l,(iy+1)
	ld	h,(iy+2)
	call	MFREE
	ld	hl,0
	jp	cret

;int GetSegP2()

_GetSegP2:	call	GET_P2
	ld	l,a
	ld	h,0
	ret

;void SetSegP2(int)

_SetSegP2:	call	csv
	ld	a,(ix+6)
	call	PUT_P2
	ld	hl,0
	jp	cret

;char* GetSegInfo()
;Devuelve un puntero "p" tal que
;p[0] = Numero de segmentos reservados
;p[S*2+1] = Slot del segmento logico S
;p[S*2+2] = Segmento fisico del segmento logico S

_GetSegInfo:	ld	hl,NUMSEGS
	ret
