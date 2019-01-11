; -*- mode: mr32asm; tab-width: 4; indent-tabs-mode: nil; -*-
; -------------------------------------------------------------------------------------------------
; This is a Mandelbrot fractal generator with a twist.
; -------------------------------------------------------------------------------------------------

; Memory mapped I/O registers for controlling the GPU.
MMIO_GPU_BASE   = 0x00000100  ; Base address of the GPU MMIO registers.
MMIO_GPU_ADDR   = 0x00        ; Start of the framebuffer memory area.
MMIO_GPU_WIDTH  = 0x04        ; Width of the framebuffer (in pixels).
MMIO_GPU_HEIGHT = 0x08        ; Height of the framebuffer (in pixels).
MMIO_GPU_DEPTH  = 0x0c        ; Number of bits per pixel.

; Video configuration.
VIDEO_MEM    = 0x00008000
VIDEO_WIDTH  = 256
VIDEO_HEIGHT = 256

; -------------------------------------------------------------------------------------------------
; Main program.
; -------------------------------------------------------------------------------------------------

    .text
    .globl  main

main:
    ; Preserve callee-saves registers on the stack. We store them all so that we don't have to keep
    ; track of used registers.
    add     sp, sp, #-52
    stw     s16, sp, #0
    stw     s17, sp, #4
    stw     s18, sp, #8
    stw     s19, sp, #12
    stw     s21, sp, #16
    stw     s22, sp, #20
    stw     s23, sp, #24
    stw     s24, sp, #28
    stw     s25, sp, #32
    stw     fp, sp, #36
    stw     tp, sp, #40
    stw     vl, sp, #44
    stw     lr, sp, #48

    bl      #init_video
    bl      #mandelbrot
    bl      #vector_flip

    ; Restore the saved registers.
    ldw     s16, sp, #0
    ldw     s17, sp, #4
    ldw     s18, sp, #8
    ldw     s19, sp, #12
    ldw     s21, sp, #16
    ldw     s22, sp, #20
    ldw     s23, sp, #24
    ldw     s24, sp, #28
    ldw     s25, sp, #32
    ldw     fp, sp, #36
    ldw     tp, sp, #40
    ldw     vl, sp, #44
    ldw     lr, sp, #48
    add     sp, sp, #52

    ; Return from main() with exit code 0.
    ldi     s1, #0
    j       lr


; -------------------------------------------------------------------------------------------------

init_video:
    ; Set the graphics mode.
    ldi     s10, #MMIO_GPU_BASE
    ldi     s11, #VIDEO_MEM
    stw     s11, s10, #MMIO_GPU_ADDR
    ldi     s11, #VIDEO_WIDTH
    stw     s11, s10, #MMIO_GPU_WIDTH
    ldi     s11, #VIDEO_HEIGHT
    stw     s11, s10, #MMIO_GPU_HEIGHT
    ldi     s11, #8
    stw     s11, s10, #MMIO_GPU_DEPTH

    j       lr


; -------------------------------------------------------------------------------------------------

mandelbrot:
    ldi     s13, #64        ; s13 = coord_step  = 4.0 / 256 = 0.015625
    ldi     s17, #100       ; s17 = max_num_iterations
    ldi     s18, #16384     ; s18 = max_distance^2 = 4.0

    ldi     s14, #VIDEO_MEM ; s14 = pixel_data (NOTE: must be after the program)

    ldi     s2, #-8192      ; s2 = im(c) = -2.0
    ldi     s16, #VIDEO_HEIGHT
    lsr     s16, s16, #1    ; s16 = loop counter for y

outer_loop_y:
    ldi     s1, #-10240     ; s1 = re(c) = -2.5
    ldi     s15, #VIDEO_WIDTH ; s15 = loop counter for x

outer_loop_x:
    or      s3, z, z        ; s3 = re(z) = 0.0
    or      s4, z, z        ; s4 = im(z) = 0.0

    ldi     s9, #0          ; Iteration count.

inner_loop:
    mul     s5, s3, s3
    mul     s6, s4, s4
    mul     s4, s3, s4

    asr     s5, s5, #12     ; s5 = re(z)^2
    asr     s6, s6, #12     ; s6 = im(z)^2
    asr     s4, s4, #11     ; s4 = 2*re(z)*im(z)

    add     s4, s4, s2      ; s4 = 2*re(z)*im(z) + im(c)
    sub     s3, s5, s6
    add     s3, s3, s1      ; s3 = re(z)^2 - im(z)^2 + re(c)

    add     s5, s5, s6      ; s5 = |z|^2
    sub     s5, s5, s18     ; |z|^2 > 4.0?

    add     s9, s9, #1
    sub     s10, s17, s9    ; s9 = max_num_iterations - num_iterations = color

    bgt     s5, #inner_loop_done
    bgt     s10, #inner_loop   ; max_num_iterations no reached yet?

inner_loop_done:
    lsl     s9, s10, #1      ; x2 for more intense levels

    ; Write color to pixel matrix.
    stb     s9, s14, #0
    add     s14, s14, #1

    ; Increment along the x axis.
    add     s15, s15, #-1
    add     s1, s1, s13     ; re(c) = re(c) + coord_step
    bgt     s15, #outer_loop_x

    ; Increment along the y axis.
    add     s16, s16, #-1
    add     s2, s2, s13     ; im(c) = im(c) + coord_step
    bgt     s16, #outer_loop_y

    j       lr


; -------------------------------------------------------------------------------------------------

vector_flip:
    cpuid   s12, z, z       ; s12 = max VL
    lsl     s13, s12, #2    ; Vector size in bytes

    ldi     s14, #VIDEO_MEM ; s14 = src

    ldi     s15, #VIDEO_WIDTH
    ldi     s16, #VIDEO_HEIGHT
    mul     s15, s15, s16
    add     s15, s14, s15
    add     s15, s15, #-4   ; s15 = dst

    ldi     s18, #3         ; s18 = multiplication factor
    shuf    s18, s18, #0    ;       ...per byte

    ldi     s17, #VIDEO_HEIGHT
    lsr     s17, s17, #1     ; s17 = loop counter for y

loop_y:
    ldi     s16, #VIDEO_WIDTH
    lsr     s16, s16, #2    ; s16 = loop counter for x
    add     s17, s17, #-1   ; Decrement the y counter

loop_x:
    min     vl, s12, s16
    sub     s16, s16, vl    ; Decrement the x counter

    ldw     v1, s14, #4
    shuf    v1, v1, #0x53   ; Reverse byte order
    mul.b   v1, v1, s18     ; Multiply by something
    stw     v1, s15, #-4    ; Store in reverse word order (stride = -4)

    add     s14, s14, s13   ; Increment src pointer
    sub     s15, s15, s13   ; Decrement dst pointer
    bgt     s16, #loop_x

    bgt     s17, #loop_y

    j       lr
