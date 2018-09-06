; -*- mode: mr32asm; tab-width: 4; indent-tabs-mode: nil; -*-
; -------------------------------------------------------------------------------------------------
; Test program for pipeline_tb.vhd
;
; This program is compiled using mr32asm.py, and loaded into the testbench.
; -------------------------------------------------------------------------------------------------

boot:
    ; Start by setting up the stack.
    ldi     sp, 0x00020000  ; We grow down from 128KB.

    bl      mandelbrot
    bl      vector_flip
    b       exit


; -------------------------------------------------------------------------------------------------

mandelbrot:
    ldi     s13, 64         ; s13 = coord_step  = 4.0 / 256 = 0.015625
    ldi     s17, 100        ; s17 = max_num_iterations
    ldi     s18, 16384      ; s18 = max_distance^2 = 4.0

    ldi     s14, 0x00008000 ; s14 = pixel_data (NOTE: must be after the program)

    ldi     s2, -8192       ; s2 = im(c) = -2.0
    ldi     s16, 128        ; s16 = loop counter for y

.outer_loop_y:
    ldi     s1, -10240      ; s1 = re(c) = -2.5
    ldi     s15, 256        ; s15 = loop counter for x

.outer_loop_x:
    or      s3, z, z        ; s3 = re(z) = 0.0
    or      s4, z, z        ; s4 = im(z) = 0.0

    ldi     s9, 0           ; Iteration count.

.inner_loop:
    mul     s5, s3, s3
    mul     s6, s4, s4
    mul     s4, s3, s4

    asr     s5, s5, 12      ; s5 = re(z)^2
    asr     s6, s6, 12      ; s6 = im(z)^2
    asr     s4, s4, 11      ; s4 = 2*re(z)*im(z)

    add     s4, s4, s2      ; s4 = 2*re(z)*im(z) + im(c)
    sub     s3, s5, s6
    add     s3, s3, s1      ; s3 = re(z)^2 - im(z)^2 + re(c)

    add     s5, s5, s6      ; s5 = |z|^2
    sub     s5, s5, s18     ; |z|^2 > 4.0?

    add     s9, s9, 1
    sub     s10, s17, s9    ; s9 = max_num_iterations - num_iterations = color

    bgt     s5, .inner_loop_done
    bgt     s10, .inner_loop    ; max_num_iterations no reached yet?

.inner_loop_done:
    lsl     s9, s10, 1      ; x2 for more intense levels

    ; Write color to pixel matrix.
    stb     s9, s14, 0
    add     s14, s14, 1

    ; Increment along the x axis.
    add     s15, s15, -1
    add     s1, s1, s13     ; re(c) = re(c) + coord_step
    bgt     s15, .outer_loop_x

    ; Increment along the y axis.
    add     s16, s16, -1
    add     s2, s2, s13     ; im(c) = im(c) + coord_step
    bgt     s16, .outer_loop_y

    j       lr


; -------------------------------------------------------------------------------------------------

vector_flip:
    cpuid   s12, z, z       ; s12 = max VL
    lsl     s13, s12, 2     ; Vector size in bytes

    ldi     s14, 0x00008000 ; s14 = src
    ldi     s15, 0x00017ffc ; s15 = dst

    ldi     s18, 3          ; s18 = multiplication factor
    shuf    s18, s18, 0     ;       ...per byte

    ldi     s17, 128        ; s17 = loop counter for y

.loop_y:
    ldi     s16, 64         ; s16 = loop counter for x
    add     s17, s17, -1    ; Decrement the y counter

.loop_x:
    min     vl, s12, s16
    sub     s16, s16, vl    ; Decrement the x counter

    ldw     v1, s14, 4
    shuf    v1, v1, 0x53    ; Reverse byte order
    pbmul   v1, v1, s18     ; Multiply by something
    stw     v1, s15, -4     ; Store in reverse word order (stride = -4)

    add     s14, s14, s13   ; Increment src pointer
    sub     s15, s15, s13   ; Decrement dst pointer
    bgt     s16, .loop_x

    bgt     s17, .loop_y

    j       lr


; -------------------------------------------------------------------------------------------------

exit:
    ; Flush the pipeline.
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    ; End the simulation.
    j       z

