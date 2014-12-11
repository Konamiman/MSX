/*
	NDOS.H: Rutinas y constantes para DOS
*/

#ifndef NDOS_H
#define NDOS_H

#ifndef NULL
#define NULL 0
#endif

#define fhandle int
#define uint unsigned int
#define uchar unsigned char
#define ulong unsigned long

/*** File handles de sistema ***/

#define STDIN  0
#define STDOUT 1
#define STDERR 2
#define AUX    3
#define PRN    4

/*** Modos de apertura de un fichero ***/

#define F_NOWRITE 1
#define F_NOREAD 2
#define F_NOINH 4

/*** Atributos de los ficheros ***/

#define A_RDO 1
#define A_HID 2
#define A_SYS 4
#define A_VOL 8
#define A_DIR 16
#define A_ARC 32
#define A_DEV 128

#define A_NEW 128

/*** Flags para NGETC ***/

#define NOWAIT 1
#define NOECHO 2

/*** Estructuras ***/

typedef struct {
	b0: 1;
	b1: 1;
	b2: 1;
	b3: 1;
	b4: 1;
	b5: 1;
	b6: 1;
	b7: 1;
} flags;

typedef struct {
	uchar phdrive;
	uint  secsize;
	uchar secpclus;
	uint  secrsv;
	uchar fatcopies;
	uint  rootentr;
	uint  sectotal;
	uchar mediaid;
	uchar secpfat;
	uint  firstroot;
	uint  firstdata;
	uint  maxclus;
	uchar dirty;
	ulong volid;
	uint  clustotal;
	uint  clusfree;
	uint  dpbpnt;
	char  unused[2];
} diskparam;

typedef struct {
	char  alwaysff;
	char  fname[13];
	char  attrib;
	uint  time;
	uint  date;
	uint  startclus;
	ulong fsize;
	uchar drive;
	char  internal[38];
} fib;

typedef struct {
	int year;
	int month;
	int day;
	int wday;
} date;

typedef struct {
	int hour;
	int minute;
	int second;
} time;

typedef struct {
	char* termchar;
	char* lastitem;
	int logdrive;
	flags f;
} parsedata;


/*** Rutinas ***/

extern long seek(fhandle, long, int);
#define nrewind(fh) seek(fh,0,0)
#define forward(fh) seek(fh,0,2)
#define nftell(fh) seek(fh,0,1)
extern int nfprintf(fhandle, char* f, ...);
extern int nprintf(char* f, ...);
extern int nsprintf(char*, char*, ...);
extern int nopen(char*, char);
extern int nclose(fhandle);
extern int nread(fhandle, char*, int);
extern int nwrite(fhandle, char*, int);
extern int create(char*, int, int);
extern int nrename(char*, char*);
extern int eof(fhandle);
extern int fprint(fhandle, char*);
#define print(c) fprint(STDOUT,c)
extern void nexit(int);
extern int ngetenv(char*, char*, int);
extern int nsetenv(char*, char*);
extern int findenv(int, char*, int);
extern int explain(int, char*);
extern int nchdir(char*);
extern int ngetcwd(int, char*);
extern int geterr();
extern int nmkdir(char*);
extern int fileatt(char*, fhandle, int);
#define getfatt(f) fileatt(f,-1,-1)
#define setfatt(f,a) fileatt(f,-1,a)
#define gethatt(fh) fileatt(NULL,fh,-1)
#define sethatt(fh,a) fileatt(NULL,fh,a)
extern int nrmdir(char*);
extern int move(char*, char*);
extern int nfputc(fhandle, char);
#define nputc(c) nfputc(STDOUT,c)
extern int nfgetc(fhandle);
extern char ngetc(int);
#define pausekey() ngetc(NOECHO)
extern void waitkey();
#define newline() print(CR_LF)
#define fnewline(fh) fprint(fh,CR_LF)
extern char* ntoa(unsigned long, char, char, unsigned char, unsigned char, char*);
#define itoa(num,buf) ntoa(num,1,1,1,10,buf)
#define xtoa(num,buf) ntoa(num,1,1,0,16,buf)
#define btoa(num,buf) ntoa(num,1,1,0,2,buf)
extern void mprint(char*, ...);
#define println(s) mprint(s,CR_LF,NULL)
extern int input(char*, int);
extern void mputc(char, ...);
extern void naterror(void*);
extern int getdpar(int, diskparam*);
extern int ffind(char*, int, fib*, int);
extern void setdta(char*);
extern int absec(int, int, int, char*, int);
#define rdsec(d,s,n,a) absec(d,s,n,a,0)
#define wrsec(d,s,n,a) absec(d,s,n,a,1)
extern int getdrv();
extern int verify(int);
extern int getlogv();
extern int setdrv(int);
extern int buffers(int);
extern int assign(int, int);
extern unsigned int dosver(int);
extern int redir(int, int);
#define nclrerr() dosver(0);
extern void gdate(date*);
extern int sdate(date*);
extern void gtime(time*);
extern int stime(time*);
extern int getdta();
extern int ramdisk(int);
extern int natexit(void*);
extern int numargs();
extern int getarg(int, char*);
extern int fork();
extern unsigned int join(int);
extern char* wpath(char*);
extern int flush(int, int);
extern char chkchar(char*, flags*);
extern int parsep(char*, parsedata*);
extern int parsef(char*, char*, parsedata*);
extern int ttoi(time);
extern time itot(uint);
extern uint dtoi(date);
extern date itod(uint);
extern int filedt(char*, fhandle, int, int*, int*);
#define getftime(c,t) filedt(c,-1,0,t,NULL)
#define setftime(c,t) filedt(c,-1,1,t,NULL)
#define getfdate(c,d) filedt(c,-1,0,NULL,d)
#define setfdate(c,d) filedt(c,-1,1,NULL,d)
#define gethtime(fh,t) filedt(NULL,fh,0,t,NULL)
#define sethtime(fh,t) filedt(NULL,fh,1,t,NULL)
#define gethdate(fh,d) filedt(NULL,fh,0,NULL,d)
#define sethdate(fh,d) filedt(NULL,fh,1,NULL,d)
extern int testfh(char*, fhandle);
extern int dupfh(fhandle);
extern int ensurefh(fhandle);
extern int fdelete(char*);
extern int ioctrl(fhandle, int, flags*);

/*** Macros con MPUTC para caracteres de control ***/

#ifndef ESC
#define ESC 0x1B
#endif

#define beep() nputc(0x07)
#define home() nputc(0x0B)
#define cls() nputc(0x0C)
#define curright() nputc(0x1C)
#define curleft() nputc(0x1D)
#define curup() nputc(0x1E)
#define curdown() nputc(0x1F)
#define bs() nputc(0x7F)
#define deltoends() mputc(ESC,'J',NULL)
#define deltoendl() mputc(ESC,'K',NULL)
#define insline() mputc(ESC,'L',NULL)
#define delline() mputc(ESC,'l',NULL)
#define suprline() mputc(ESC,'M',NULL)
#define curblk() mputc(ESC,'x','4',NULL)
#define curoff() mputc(ESC,'x','5',NULL)
#define locate(x,y) mputc(ESC,'Y',x+32,y+32,NULL)
#define curund() mputc(ESC,'y','4',NULL)
#define curon() mputc(ESC,'y','5',NULL)


#ifdef NSTDIO

#define rewind nrewind
#define ftell nftell
#define fprintf nfprintf
#define printf nprintf
#define sprintf nsprintf
#define open nopen
#define close nclose
#define read nread
#define write nwrite
#define rename nrename
#define exit nexit
#define getenv ngetenv
#define setenv nsetenv
#define chdir nchdir
#define getcwd ngetcwd
#define mkdir nmkdir
#define rmdir nrmdir
#define fputc nfputc
#define putc nputc
#define fgetc nfgetc
#define getc ngetc
#define aterror naterror
#define clrerr nclrerr
#define setdta nsetdta
#define atexit natexit

#endif

/* Puntero a "\n\r" para newline() y fnewline() */

extern char* CR_LF;

#endif
