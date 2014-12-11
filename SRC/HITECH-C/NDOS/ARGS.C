/*                                            */
/* NUMARGS and GETARG - By Konami Man, 2-2001 */
/*					      */

char* pnt;

int pasaspc();
void pasachar();
int numargs();
int getarg(int, char*);
extern int ngetenv(char*, char*, int);


/* NUMARGS: Devuelve el num. de argumentos */

int numargs()
{
	int nargs=0;
	char itembuf[130];
	pnt = &itembuf;
	ngetenv("PARAMETERS", pnt, 129);
	while(*pnt!=0)
	{
		if(pasaspc()) break;
		pasachar();
		nargs++;
	}
	return nargs;
}

/* GETARG: Coge el argumento especificado */
/* 0 es el propio nombre y ruta del programa */
/* Devuelve su longitud, o 0 si no existe */

int getarg (int numarg, char* bufer)
{
	int curarg=1;
	int lonarg=0;
	char itembuf[130];
	pnt = &itembuf;

	if ((numarg>numargs()) || (numarg<0))
	{
		*bufer=0;
		return 0;
	}

	if (numarg==0)
	{
		int i=0;
		pnt = bufer;
		ngetenv("PROGRAM", pnt, 129);
		while(*pnt++) i++;
		return i;
	}

	pnt = &itembuf;
	ngetenv("PARAMETERS", pnt, 129);

	while(curarg<numarg)
	{
		pasaspc();
		pasachar();
		curarg++;
	}
	pasaspc();

	while(*pnt!=32 && *pnt!=0)
	{
		*bufer++ = *pnt++;
		lonarg++;
	}
	*bufer=0;

	return lonarg;
}


/* PASASPC: Se salta los espacios
   Entrada: pnt apuntando al primer espacio
   Salida:  pnt apuntando al primer no-espacio
	    devuelve TRUE si apunta a un 0
*/

int pasaspc()
{
	while (*pnt==32) pnt++;
	return (*pnt==0);
}


/* PASACHAR: Se salta los caracteres que no son espacio o 0
   Entrada: pnt apuntando al primer caracter
   Salida:  pnt apuntando a un espacio o 0
*/

void pasachar()
{
	while (*pnt!=32 && *pnt!=0) pnt++;
}

