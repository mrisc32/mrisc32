; -*- mode: mr32asm; tab-width: 4; indent-tabs-mode: nil; -*-
; -------------------------------------------------------------------------------------------------
; This is a Mandelbrot fractal generator with a twist.
; -------------------------------------------------------------------------------------------------

    .include    "mrisc32-macros.inc"

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
    .p2align 2

main:
    push_all_scalar_callee_saved_regs

    bl      #init_video
    bl      #mandelbrot
    bl      #vector_flip

    ; Return from main() with exit code 0.
    pop_all_scalar_callee_saved_regs
    ldi     s1, #0
    ret


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

    ret


; -------------------------------------------------------------------------------------------------


mandelbrot:
    ldw     s13, pc, #coord_step@pc
    ldw     s17, pc, #max_num_iterations@pc
    ldw     s18, pc, #max_distance_sqr@pc

    ldi     s14, #VIDEO_MEM ; s14 = pixel_data (NOTE: must be after the program)

    ldw     s2, pc, #min_im@pc
    ldi     s16, #VIDEO_HEIGHT
    lsr     s16, s16, #1    ; s16 = loop counter for y

outer_loop_y:
    ldw     s1, pc, #min_re@pc
    ldi     s15, #VIDEO_WIDTH ; s15 = loop counter for x

outer_loop_x:
    or      s3, z, z        ; s3 = re(z) = 0.0
    or      s4, z, z        ; s4 = im(z) = 0.0

    ldi     s9, #0          ; Iteration count.

inner_loop:
    fmul    s5, s3, s3      ; s5 = re(z)^2
    fmul    s6, s4, s4      ; s6 = im(z)^2
    add     s9, s9, #1
    fmul    s4, s3, s4
    fsub    s3, s5, s6
    fadd    s5, s5, s6      ; s5 = |z|^2
    fadd    s4, s4, s4      ; s4 = 2*re(z)*im(z)
    fadd    s3, s3, s1      ; s3 = re(z)^2 - im(z)^2 + re(c)
    sub     s10, s17, s9    ; s9 = max_num_iterations - num_iterations = color
    fadd    s4, s4, s2      ; s4 = 2*re(z)*im(z) + im(c)
    fslt    s5, s5, s18     ; |z|^2 < 4.0?

    bns     s5, #inner_loop_done
    bgt     s10, #inner_loop   ; max_num_iterations no reached yet?

inner_loop_done:
    lsl     s9, s10, #1      ; x2 for more intense levels

    ; Write color to pixel matrix.
    stb     s9, s14, #0
    add     s14, s14, #1

    ; Increment along the x axis.
    add     s15, s15, #-1
    fadd    s1, s1, s13     ; re(c) = re(c) + coord_step
    bgt     s15, #outer_loop_x

    ; Increment along the y axis.
    add     s16, s16, #-1
    fadd    s2, s2, s13     ; im(c) = im(c) + coord_step
    bgt     s16, #outer_loop_y

    ret


max_num_iterations:
    .word   100

max_distance_sqr:
    .float  4.0

min_re:
    .float  -2.5

min_im:
    .float  -2.0

coord_step:
    .float  0.015625



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

    ret
