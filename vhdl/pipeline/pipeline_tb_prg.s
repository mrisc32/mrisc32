; Test program for pipeline_tb.vhd
;
; Compile using asm.py -vv, and copy the instructions (in hex) to the testbench.

main:
  OR  S1,Z,0x1234
  OR  S2,Z,0x1111
.loop:
  NOP
  BNE Z,.dont_go_here
  NOP
  ADD S3,S1,S2
  SUB S4,S1,S2
  ADD S1,S1,1
  B   .loop

.dont_go_here:
  OR  S1,Z,0xBAD  ; Should not be executed.

