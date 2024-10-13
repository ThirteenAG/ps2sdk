/*
# _____     ___ ____     ___ ____
#  ____|   |    ____|   |        | |____|
# |     ___|   |____ ___|    ____| |    \    PS2DEV Open Source Project.
#-----------------------------------------------------------------------
# Copyright 2022, ps2dev - http://www.ps2dev.org
# Licenced under Academic Free License version 2.0
# Review ps2sdk README & LICENSE files for further details.
#
*/

#include <kernel.h>
#include <stdlib.h>
#include <stdio.h>
#include <delaythread.h>

volatile int flag = 0;

int main(int argc, char *argv[])
{
    while (1) {
        DelayThread(350 * 1000);
        printf("Hello there, 350ms tick!\n");
    }

    return 0;
}
