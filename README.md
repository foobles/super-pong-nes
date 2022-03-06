# super-pong-nes
Pong game for the NES. Compiles to iNES ROM file. 

This is currently a work in progress! Many features are missing and there will be bugs. Please report them if you happen
to find any! 

## Assembly
This is written for the cc65 development suite, and requires ca65 and ld65 in order to build. 
Simply run `make all` to build the game -- it can be found in `build/bin/super_pong.nes`, along
with `super_pong.dbg` which contains debug symbols that can be loaded into some debuggers (such as Mesen).
`Makefile` currently assumes a Windows-like environment, but this is temporary making it cross-platform is 
a priority. 