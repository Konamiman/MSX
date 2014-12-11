/* DOSCODES.H
   DOS 2 functions and errors names
   by Konami Man, 2-2001
*/

#ifndef DOSCODES_H
#define DOSCODES_H

/* DOS 2 error names */

#define _NCOMP 0xFF
#define _WRERR 0xFE
#define _DISK  0xFD
#define _NRDY  0xFC
#define _VERFY 0xFB
#define _DATA  0xFA
#define _RNF   0xF9
#define _WPROT 0xF8
#define _UFORM 0xF7
#define _NDOS  0xF6
#define _WDISK 0xF5
#define _WFILE 0xF4
#define _SEEKE 0xF3 /* Original is SEEK */
#define _IFAT  0xF2
#define _NOUPB 0xF1
#define _IFORM 0xF0
#define _INTER 0xDF
#define _NORAM 0xDE
#define _IBDOS 0xDC
#define _IDRV  0xDB
#define _IFNM  0xDA
#define _IPATH 0xD9
#define _PLONG 0xD8
#define _NOFIL 0xD7
#define _NODIR 0xD6
#define _DRFUL 0xD5
#define _DKFUL 0xD4
#define _DUPF  0xD3
#define _DIRE  0xD2
#define _FILRO 0xD1
#define _DIRNE 0xD0
#define _IATTR 0xCF
#define _DOT   0xCE
#define _SYSX  0xCD
#define _DIRX  0xCC
#define _FILEX 0xCB
#define _FOPENE 0xCA /* Original is FOPEN */
#define _OV64K 0xC9
#define _FILE  0xC8
#define _EOF   0xC7
#define _ACCV  0xC6
#define _IPROC 0xC5
#define _NHAND 0xC4
#define _IHAND 0xC3
#define _NOPEN 0xC2
#define _IDEV  0xC1
#define _IENV  0xC0
#define _ELONG 0xBF
#define _IDATE 0xBE
#define _ITIME 0xBD
#define _RAMDX 0xBC
#define _NRAMD 0xBB
#define _HDEAD 0xBA
#define _EOL   0xB9
#define _ISBFN 0xB8
#define _STOP  0x9F
#define _CTRLC 0x9E
#define _ABORT 0x9D
#define _OUTERR 0x9C
#define _INERR 0x9B
#define _BADCOM 0x8F
#define _BADCM 0x8E
#define _BUFUL 0x8D
#define _OKCMD 0x8C
#define _IPARM 0x8B
#define _INP   0x8A
#define _NOPAR 0x89
#define _IOPT  0x88
#define _BADNO 0x87
#define _NOHELP 0x86
#define _BADVER 0x85
#define _NOCAT 0x84
#define _BADEST 0x83
#define _COPY  0x82
#define _OVDEST 0x81

/* DOS 2 function names */

#define _TERM0  0x00
#define _CONIN  0x01
#define _CONOUT 0x02
#define _AUXIN  0x03
#define _AUXOUT 0x04
#define _LSTOUT 0x05
#define _DIRIO  0x06
#define _DIRIN  0x07
#define _INNOE  0x08
#define _STROUT 0x09
#define _BUFIN  0x0A
#define _CONST  0x0B
#define _CPMVER 0x0C
#define _DSKRST 0x0D
#define _SELDSK 0x0E
#define _FOPEN  0x0F
#define _FCLOSE 0x10
#define _SFIRST 0x11
#define _SNEXT  0x12
#define _FDEL   0x13
#define _RDSEQ  0x14
#define _WRSEQ  0x15
#define _FMAKE  0x16
#define _FREN   0x17
#define _LOGIN  0x18
#define _CURDRV 0x19
#define _SETDTA 0x1A
#define _ALLOC  0x1B
#define _RDRND  0x21
#define _WRRND  0x22
#define _FSIZE  0x23
#define _SETRND 0x24
#define _WRBLK	0x26
#define _RDBLK  0x27
#define _WRZER  0x28
#define _GDATE  0x2A
#define _SDATE  0x2B
#define _GTIME  0x2C
#define _STIME  0x2D
#define _VERIFY 0x2E
#define _RDABS  0x2F
#define _WRABS  0x30
#define _DPARM  0x31
#define _FFIRST 0x40
#define _FNEXT  0x41
#define _FNEW   0x42
#define _OPEN   0x43
#define _CREATE 0x44
#define _CLOSE  0x45
#define _ENSURE 0x46
#define _DUP    0x47
#define _READ   0x48
#define _WRITE  0x49
#define _SEEK   0x4A
#define _IOCTL  0x4B
#define _HTEST  0x4C
#define _DELETE 0x4D
#define _RENAME 0x4E
#define _MOVE   0x4F
#define _ATTR   0x50
#define _FTIME  0x51
#define _HDELETE 0x52
#define _HRENAME 0x53
#define _HMOVE  0x54
#define _HATTR  0x55
#define _HFTIME 0x56
#define _GETDTA 0x57
#define _GETVFY 0x58
#define _GETCD  0x59
#define _CHDIR  0x5A
#define _PARSE  0x5B
#define _PFILE  0x5C
#define _CHKCHR 0x5D
#define _WPATH	0x5E
#define _FLUSH	0x5F
#define _FORK   0x60
#define _JOIN   0x61
#define _TERM   0x62
#define _DEFAB  0x63
#define _DEFERR 0x64
#define _ERROR  0x65
#define _EXPLAIN 0x66
#define _FORMAT 0x67
#define _RAMD   0x68
#define _BUFFER 0x69
#define _ASSIGN 0x6A
#define _GENV	0x6B
#define _SENV   0x6C
#define _FENV   0x6D
#define _DSKCHK 0x6E
#define _DOSVER 0x6F
#define _REDIR  0x70

#endif
