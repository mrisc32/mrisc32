####################################################################################################
# Copyright (c) 2018 Marcus Geelnard
#
# This software is provided 'as-is', without any express or implied warranty. In no event will the
# authors be held liable for any damages arising from the use of this software.
#
# Permission is granted to anyone to use this software for any purpose, including commercial
# applications, and to alter it and redistribute it freely, subject to the following restrictions:
#
#  1. The origin of this software must not be misrepresented; you must not claim that you wrote
#     the original software. If you use this software in a product, an acknowledgment in the
#     product documentation would be appreciated but is not required.
#
#  2. Altered source versions must be plainly marked as such, and must not be misrepresented as
#     being the original software.
#
#  3. This notice may not be removed or altered from any source distribution.
####################################################################################################

AS = mrisc32-as
LD = mrisc32-ld
ELF2BIN = ../tools/elf2bin.py
RM = rm -f

AS_FLAGS =
LD_FLAGS = -s

.PHONY: all clean

default: all

all: super_test.bin \
     graphics.bin \
     mandelbrot.bin \
     test1.bin \
     test2.bin

clean:
	$(RM) *.o *.elf *.bin

%.bin: %.elf
	$(ELF2BIN) $< $@

%.elf: %.o
	$(LD) $(LD_FLAGS) -o $@ $<

%.o: %.s
	$(AS) $(AS_FLAGS) -o $@ $<

