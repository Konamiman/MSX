## InterNestor Lite

InterNestor Lite is a TCP/IP stack that works on MSX2/2+/Turbo-R with at least 128K RAM. It supports two kinds of hardware: serial port (RS-232) with modem, and the [Ethernet UNAPI](http://konamiman.com/msx/msx-e.html#unapi).

The sources are intended to be assembled with the MSX assembler Compass, however you can compile them with <a href="https://github.com/Konamiman/Sjasm/releases/tag/v0.39h">Sjasm 0.39h</a>
using the `-c` switch (which enables the Compass compatibility mode). Example using the Windows command line:

```
sjasm -c inl-tran.asm inl-tran.dat
sjasm -c inl-res.asm inl-res.dat
copy /b inl-tran.dat+inl-res.dat inl.com
```

InterNestor Lite implements the [TCP/IP UNAPI specification](http://konamiman.com/msx/msx-e.html#tcpipunapi), therefore you can use it to run the compatible [networking software](../NETWORK).

Binaries, documentation and more resources are available at [Konamiman's MSX page](http://www.konamiman.com#inl2).
