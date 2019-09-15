#!/bin/sh

EXECNAME=$1

if [ -z "$EXECNAME" ]; then
  echo "Usage: $0 <executable_name>"
  exit 1
fi

if [ ! -f "$EXECNAME.c" ]; then
  echo "Not found $EXECNAME.c"
  exit 1
fi

rm -f $EXECNAME.com

sdcc --code-loc 0x180 --data-loc 0 -mz80 --disable-warning 196 --no-std-crt0 $SDCC_LIB/crt0_msxdos_advanced.rel $SDCC_LIB/printf.rel $SDCC_LIB/putchar_msxdos.rel asm.lib $EXECNAME.c

if [ -f "$EXECNAME.ihx" ]; then
  hex2bin -e com $EXECNAME.ihx
fi

rm -f $EXECNAME.rel $EXECNAME.asm
rm -f *.ihx *.lk *.lst *.map *.noi *.sym
