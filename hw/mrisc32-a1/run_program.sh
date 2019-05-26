#!/bin/bash

####################################################################################################
# Copyright (c) 2019 Marcus Geelnard
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

WORKDIR=out
GHDL=ghdl
GHDLFLAGS="--std=08 --work=work --workdir=${WORKDIR}"

if [ "$1" = "--vcd" ]; then
  VCD=yes
  shift
fi
if [ "$1" = "--wave" ]; then
  WAVE=yes
  shift
fi

# Copy the compiled program so that the VHDL test bench can find it.
cp "$1" out/core_tb_prg.bin

# Run the core_tb test bench.
if [ "x${VCD}" = "xyes" ]; then
  ${GHDL} -r ${GHDLFLAGS} core_tb "--vcd=${WORKDIR}/core_tb.vcd"
elif [ "x${WAVE}" = "xyes" ]; then
  ${GHDL} -r ${GHDLFLAGS} core_tb "--wave=${WORKDIR}/core_tb.ghw"
else
  ${GHDL} -r ${GHDLFLAGS} core_tb
fi
