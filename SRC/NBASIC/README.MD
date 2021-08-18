## What is NestorBASIC? ##

NestorBASIC is a set of machine code routines, integrated in a single file. It is intended for being used within MSX-BASIC programs. Without losing Turbo-BASIC compatibility, NestorBASIC gives you the following capabilities:

- Full access to all te available memory of the computer (all existing memory in the case of DOS 1, all free memory in the case of DOS 2), up to 4 Mb.
- Access to VRAM, with data block exchange between VRAM and between RAM and VRAM feature.
- Storage of BASIC programs in the mapped RAM, which can be executed without losing the existing variables.
- Access to disk files and direct access to physical sectors, with read/write to RAM/VRAM feature. File search, directory management. 
- Graphic compression and decompression.
- Moonblaster music playback. Samplekit load.
- PSG sound effects playback.
- Execution of machine code routines placed on BIOS, SUB-BIOS, normal BASIC memory, system work area, or a mapped RAM segment.
- Machine code routines execution, from BIOS or from any RAM segment. User defined interrupts.
- NestorMan functions, InterNestor Suite and InterNestor Lite routines execution.

All of these functions are available through a single USR and an integer parameter array, therefore they are fully TurboBASIC compatible. In fact, the TurboBASIC compiler itself is included into the NestorBASIC file, and it is automatically loaded when NestorBASIC is installed.

NestorBASIC is loaded in a RAM segment not used by BASIC, so only a small amount of the BASIC main RAM (aprox. 500 bytes) is needed for a jump routine. The rest of the BASIC main RAM remains available for the BASIC program

## How to build ##

Compile NBASIC.ASM (with the Compass assembler), then concatenate the result with NBASIC.DAT. The `CONCA.BTM` script will do the job (needs COMMAND2.COM v24x).

Do not use the `CONCMUS.BTM` script. It refers to NWAVE.BIN, the MoonBlaster for MoonSound player adapted for NestorBASIC, whose sources were lost in a hard disk crash. The NBASIC.DAT file is a concatenation of the XBASIC ROM and the OPLL and OPL4 players.
