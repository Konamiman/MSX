/*** NTOA - Original code included in Hitech-C distribution ***/
/*** Slightly modified by Konami Man, 2-2001 ***/

/*
 *	Formatted number printing for Z80 printf and debugger
 */
#define NDIG	30		/* max number of digits to be printed */

#define uchar unsigned char
#define ulong unsigned long

/* i: Numero a convertir
   f: Numero total de digitos (los sobrantes se ponen a 0)
   w: Anchura total (se rellena el sobrante con espacios)
   s: 0 si es "unsigned", <>0 si no
*/

char* ntoa (ulong i, char f, char w, uchar s, uchar base, char* buffer)
{
	register char *	cp;
	unsigned char	fw;
	char		buf[NDIG];
	char*		oldbuf;

	oldbuf = buffer;
	if(f > NDIG)
		f = NDIG;

	if(s && (long)i < 0)
		i = -i;
	else
		s = 0;

	if(f == 0 && i == 0)
		f++;

	cp = &buf[NDIG];
	while(i || f > 0) {
		*--cp = "0123456789ABCDEF"[i%base];
		i /= base;
		f--;
	}
	fw = f = (&buf[NDIG] - cp) + s;
	if(fw < w)
		fw = w;
	while(w-- > f)
		*buffer++ = ' ';  /*putch(' ');*/
	if(s) {
		*buffer++ = '-';  /*putch('-');*/
		f--;
	}
	while(f--)
		*buffer++ = *cp++;  /*putch(*cp++);*/
	*buffer = 0;
	return oldbuf; /*return fw;*/
}

