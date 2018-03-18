; Test program for pipeline_tb.vhd
;
; This program is compiled using asm.py, and loaded into the testbench.

boot:
    ; Start by setting up the stack.
    LDI   SP, 0x00020000  ; We grow down from 128KB.


main:
    LDI   S12, -2
    LSL   S12, S12, 12    ; S12 = start_coord = -2.0
    LDI   S13, 64         ; S13 = coord_step  = 4.0 / 256 = 0.015625
    LDI   S17, 100        ; S17 = max_num_iterations
    LDI   S18, 16384      ; S18 = max_distance^2 = 4.0

    LEA   S14, .pixels    ; S14 = .pixels

    OR    S2, S12, Z      ; S2 = im(c) = -2.0
    LDI   S16, 256        ; S16 = loop counter for y

.outer_loop_y:
    OR    S1, S12, Z      ; S1 = re(c) = -2.0
    LDI   S15, 256        ; S15 = loop counter for x

.outer_loop_x:
    OR    S3, Z, Z        ; S3 = re(z) = 0.0
    OR    S4, Z, Z        ; S4 = im(z) = 0.0

    LDI   S9, 0           ; Iteration count.

.inner_loop:
    MUL   S5, S3, S3
    ASR   S5, S5, 12      ; S5 = re(z)^2
    MUL   S6, S4, S4
    ASR   S6, S6, 12      ; S6 = im(z)^2

    MUL   S4, S3, S4
    ASR   S4, S4, 11
    ADD   S4, S4, S2      ; S4 = 2*re(z)*im(z) + im(c)

    SUB   S3, S5, S6
    ADD   S3, S3, S1      ; S3 = re(z)^2 - im(z)^2 + re(c)

    ADD   S5, S5, S6      ; S5 = |z|^2
    SUB   S5, S5, S18     ; |z|^2 > 4.0?

    ADD   S9, S9, 1
    SUB   S10, S9, S17    ; num_iterations >= max_num_iterations?

    BGT   S5, .inner_loop_done
    BLT   S10, .inner_loop

.inner_loop_done:
    SUB   S9, S17, S9     ; S9 = max_num_iterations - num_iterations = color

    ; Write color to pixel matrix.
    STB   S9, S14, 0
    ADD   S14, S14, 1

    ADD   S15, S15, -1
    ADD   S1, S1, S13     ; re(c) = re(c) + coord_step
    BLT   S15, .outer_loop_x

    ADD   S16, S16, -1
    ADD   S2, S2, S13     ; re(c) = re(c) + coord_step
    BLT   S16, .outer_loop_y

.done:
    B     .done


.pixels:
    .space 65536

