; Test program for pipeline_tb.vhd
;
; This program is compiled using asm.py, and loaded into the testbench.

boot:
    ; Start by setting up the stack.
    LDI   SP, 0x00020000  ; We grow down from 128KB.

main:
    LDI   S9, 4           ; Loop count.
    LDI   S1, 0x1234
    LDI   S2, 0x1111
    MUL   S5, S2, S1
.loop:
    BEQ   S1, .dont_go_here
    BNE   Z, .dont_go_here
    ADD   S5, S1, S1
    BL    .subroutine
    ADD   S3, S1, S2
    SUB   S4, S1, S2
    ADD   S1, S1, 1
    ADD   S9, S9, -1
    BNE   S9, .loop
    B     main

.dont_go_here:
    OR    S1, Z, 0xBAD    ; Should not be executed.
    B     .dont_go_here

.subroutine:
    ADD   SP, SP, -8
    STW   LR, SP, 0
    STW   S9, SP, 4
    LDI   S9, 0x34543
    ADD   S9, S9, 5
    ADD   S9, S9, -4
    AND   S9, S9, 0x00FF
    LDW   LR, SP, 0
    LDW   S9, SP, 4
    ADD   SP, SP, 8
    J     LR              ; Return from subroutine
