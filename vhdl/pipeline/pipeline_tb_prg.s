; Test program for pipeline_tb.vhd
;
; Compile using asm.py -vv, and copy the instructions (in hex) to the testbench.

main:
  LDI   S1,0x1234
  LDI   S2,0x1111
.loop:
  BEQ   S2,.dont_go_here
  BNE   Z,.dont_go_here
  NOP
  BL    .subroutine
  ADD   S3,S1,S2
  SUB   S4,S1,S2
  ADD   S1,S1,1
  B     .loop

.dont_go_here:
  OR    S1,Z,0xBAD  ; Should not be executed.

.subroutine:
  LDI   S9,0x34543
  NOP
  NOP
  NOP
  J     LR          ; Return from subroutine

