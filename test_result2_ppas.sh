#!/bin/sh
DoExitAsm ()
{ echo "An error occurred while assembling $1"; exit 1; }
DoExitLink ()
{ echo "An error occurred while linking $1"; exit 1; }
echo Assembling program
as --64 -o /tmp/test_result2.o   /tmp/test_result2.s
if [ $? != 0 ]; then DoExitAsm program; fi
rm /tmp/test_result2.s
echo Linking /tmp/test_result2
OFS=$IFS
IFS="
"
ld -b elf64-x86-64 -m elf_x86_64     -s    -L. -o /tmp/test_result2 -T test_result2_link.res -e _start
if [ $? != 0 ]; then DoExitLink /tmp/test_result2; fi
IFS=$OFS
