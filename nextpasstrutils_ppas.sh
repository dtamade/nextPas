#!/bin/sh
DoExitAsm ()
{ echo "An error occurred while assembling $1"; exit 1; }
DoExitLink ()
{ echo "An error occurred while linking $1"; exit 1; }
echo Assembling nextpasstrutils
as --64 -o /home/dtamade/projects/nextPas/packages/strutils/nextpasstrutils.o   /home/dtamade/projects/nextPas/packages/strutils/nextpasstrutils.s
if [ $? != 0 ]; then DoExitAsm nextpasstrutils; fi
rm /home/dtamade/projects/nextPas/packages/strutils/nextpasstrutils.s
