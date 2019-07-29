# InterNestor Lite - how to build

The sources of InterNestor Lite are intended to be assembled with the MSX assembler Compass, however you can compile them with <a href="https://github.com/Konamiman/Sjasm/releases/tag/v0.39h">Sjasm 0.39h</a>
using the `-c` switch (which enables the Compass compatibility mode). Example using the Windows command line:

```
sjasm -c inl-tran.asm inl-tran.dat
sjasm -c inl-res.asm inl-res.dat
copy /b inl-tran.dat+inl-res.dat inl.com
```

You need to assemble `inl-tran.asm`, then assemble `inl-res.asm`, then concatenate both. The resulting file is INL.COM, the InterNestor Lite installer and control program, which can be run from the MSX-DOS/Nextor prompt.
