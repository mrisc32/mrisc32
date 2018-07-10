; -------------------------------------------------------------------------------------------------
; Test program for pipeline_tb.vhd
;
; This program is compiled using asm.py, and loaded into the testbench.
; -------------------------------------------------------------------------------------------------

boot:
    ; Start by setting up the stack.
    LDI   SP, 0x00020000  ; We grow down from 128KB.

    BL    vector_test
    BL    mandelbrot
    B     exit


; -------------------------------------------------------------------------------------------------

vector_test:
    CPUID S12, Z, Z       ; S12 = max VL
    MIN   S12, S12, 32    ; We only support vector lengths up to 32
    LSL   S13, S12, 2     ; Memory increment (vector size in bytes)

    OR    VL, S12, Z
    NOP                   ; TODO(m): Remove these NOP:s when VL operand forwarding works!
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    LEA   S10, .data
    LDW   V1, S10, 4      ; Load some data into V1

    LDI   S14, 0x00008000 ; S14 = pixel_data (NOTE: must be after the program)

    LDI   S16, 128        ; S16 = loop counter for y

.loop_y:
    LDI   S15, 64         ; S15 = loop counter for x
    ADD   S16, S16, -1    ; Decrement the y counter

.loop_x:
    MIN   VL, S12, S15
    SUB   S15, S15, VL    ; Decrement the x counter

    NOP                   ; TODO(m): Remove these NOP:s when VL operand forwarding works!
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    STW   V1, S14, 4      ; Store vector data to memory

    ADD   V1, V1, S12     ; Vector add

    ADD   S14, S14, S13   ; Increment memory pointer
    BGT   S15, .loop_x

    BGT   S16, .loop_y

    J     LR

.data:
    .u32  1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16
    .u32  17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32


; -------------------------------------------------------------------------------------------------

mandelbrot:
    LDI   S13, 64         ; S13 = coord_step  = 4.0 / 256 = 0.015625
    LDI   S17, 100        ; S17 = max_num_iterations
    LDI   S18, 16384      ; S18 = max_distance^2 = 4.0

    LDI   S14, 0x00010000 ; S14 = pixel_data (NOTE: must be after the program)

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
.done:
    B     .done

