@echo off

rem this is a temporary. actual makefile WIP

if not exist "./bin/" mkdir "bin"
if not exist "./obj/" mkdir "obj"

ca65    src/header.s        -o obj/header.o 
ca65    src/chars.s         -o obj/chars.o      --bin-include-dir gfx/
ca65    src/input.s         -o obj/input.o
ca65    src/render.s        -o obj/render.o
ca65    src/playground.s    -o obj/playground.o

ld65 playground.o header.o chars.o input.o render.o --obj-path obj/ -C nes.cfg -o bin/playground.nes