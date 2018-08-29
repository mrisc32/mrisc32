; -------------------------------------------------------------------------------------------------
; Test program for pipeline_tb.vhd
;
; This program is compiled using mr32asm.py, and loaded into the testbench.
; -------------------------------------------------------------------------------------------------

boot:
    ; Start by setting up the stack.
    LDI   SP, 0x00020000  ; We grow down from 128KB.

    BL    mandelbrot
    BL    vector_flip
    B     exit


; -------------------------------------------------------------------------------------------------

mandelbrot:
    LDI   S13, 64         ; S13 = coord_step  = 4.0 / 256 = 0.015625
    LDI   S17, 100        ; S17 = max_num_iterations
    LDI   S18, 16384      ; S18 = max_distance^2 = 4.0

    LDI   S14, 0x00008000 ; S14 = pixel_data (NOTE: must be after the program)

    LDI   S2, -8192       ; S2 = im(c) = -2.0
    LDI   S16, 128        ; S16 = loop counter for y

.outer_loop_y:
    LDI   S1, -10240      ; S1 = re(c) = -2.5
    LDI   S15, 256        ; S15 = loop counter for x

.outer_loop_x:
    OR    S3, Z, Z        ; S3 = re(z) = 0.0
    OR    S4, Z, Z        ; S4 = im(z) = 0.0

    LDI   S9, 0           ; Iteration count.

.inner_loop:
    MUL   S5, S3, S3
    MUL   S6, S4, S4
    MUL   S4, S3, S4

    ASR   S5, S5, 12      ; S5 = re(z)^2
    ASR   S6, S6, 12      ; S6 = im(z)^2
    ASR   S4, S4, 11      ; S4 = 2*re(z)*im(z)

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
    LSL   S9, S9, 1       ; x2 for more intense levels

    ; Write color to pixel matrix.
    STB   S9, S14, 0
    ADD   S14, S14, 1

    ; Increment along the x axis.
    ADD   S15, S15, -1
    ADD   S1, S1, S13     ; re(c) = re(c) + coord_step
    BGT   S15, .outer_loop_x

    ; Increment along the y axis.
    ADD   S16, S16, -1
    ADD   S2, S2, S13     ; im(c) = im(c) + coord_step
    BGT   S16, .outer_loop_y

    J     LR


; -------------------------------------------------------------------------------------------------

vector_flip:
    CPUID S12, Z, Z       ; S12 = max VL
    LSL   S13, S12, 2     ; Vector size in bytes

    LDI   S14, 0x00008000 ; S14 = src
    LDI   S15, 0x00017FFC ; S15 = dst

    LDI   S18, 3          ; S18 = multiplication factor

    LDI   S17, 128        ; S17 = loop counter for y

.loop_y:
    LDI   S16, 64         ; S16 = loop counter for x
    ADD   S17, S17, -1    ; Decrement the y counter

.loop_x:
    MIN   VL, S12, S16
    SUB   S16, S16, VL    ; Decrement the x counter

    LDW   V1, S14, 4
    SHUF  V1, V1, 0x53    ; Reverse byte order
    MUL   V1, V1, S18     ; Multiply by something
    STW   V1, S15, -4     ; Store in reverse word order (stride = -4)

    ADD   S14, S14, S13   ; Increment src pointer
    SUB   S15, S15, S13   ; Decrement dst pointer
    BGT   S16, .loop_x

    BGT   S17, .loop_y

    J     LR


; -------------------------------------------------------------------------------------------------

exit:
    ; Flush the pipeline.
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; End the simulation.
    J     Z

