; -*- mode: mr32asm; tab-width: 4; indent-tabs-mode: nil; -*-
; ----------------------------------------------------------------------------
; This file contains the common startup code. It defines _start, which does
; some initialization and then calls main.
; ----------------------------------------------------------------------------

STACK_START   = 0x20000     ; We grow down from 128 KB.

    .section .entry
    .globl  _start

    .p2align 2
_start:
    ; ------------------------------------------------------------------------
    ; Boot + process/thread startup.
    ; ------------------------------------------------------------------------

    ; Clear the BSS data.

    ldhi    s2, #__bss_size@hi
    or      s2, s2, #__bss_size@lo
    bz      s2, bss_cleared
    lsr     s2, s2, #2      ; BSS size is always a multiple of 4 bytes.

    ldhi    s1, #__bss_start@hi
    or      s1, s1, #__bss_start@lo
    cpuid   s3, z, z
clear_bss_loop:
    min     vl, s2, s3
    sub     s2, s2, vl
    stw     vz, s1, #4
    ldea    s1, s1, vl*4
    bnz     s2, clear_bss_loop
bss_cleared:

    ; Set all the scalar registers (except Z and PC) to a known state.
    ldi     s1, #0
    ldi     s2, #0
    ldi     s3, #0
    ldi     s4, #0
    ldi     s5, #0
    ldi     s6, #0
    ldi     s7, #0
    ldi     s8, #0
    ldi     s9, #0
    ldi     s10, #0
    ldi     s11, #0
    ldi     s12, #0
    ldi     s13, #0
    ldi     s14, #0
    ldi     s15, #0
    ldi     s16, #0
    ldi     s17, #0
    ldi     s18, #0
    ldi     s19, #0
    ldi     s20, #0
    ldi     s21, #0
    ldi     s22, #0
    ldi     s23, #0
    ldi     s24, #0
    ldi     s25, #0
    ldi     s26, #0
    ldi     s27, #0
    ldi     s28, #0
    ldi     s29, #0
    ldi     s30, #0

    ; Set all the vector registers to a known state: clear all elements.
    cpuid   vl, z, z
    or      v1, vz, #0
    or      v2, vz, #0
    or      v3, vz, #0
    or      v4, vz, #0
    or      v5, vz, #0
    or      v6, vz, #0
    or      v7, vz, #0
    or      v8, vz, #0
    or      v9, vz, #0
    or      v10, vz, #0
    or      v11, vz, #0
    or      v12, vz, #0
    or      v13, vz, #0
    or      v14, vz, #0
    or      v15, vz, #0
    or      v16, vz, #0
    or      v17, vz, #0
    or      v18, vz, #0
    or      v19, vz, #0
    or      v20, vz, #0
    or      v21, vz, #0
    or      v22, vz, #0
    or      v23, vz, #0
    or      v24, vz, #0
    or      v25, vz, #0
    or      v26, vz, #0
    or      v27, vz, #0
    or      v28, vz, #0
    or      v29, vz, #0
    or      v30, vz, #0
    or      v31, vz, #0

    ; Set all the vector register lengths to zero.
    ; NOTE: Register lengths are currently not implemented in the A1, but this
    ; is a fast operation and it does not hurt.
    ldi     vl, #0
    or      v1, vz, #0
    or      v2, vz, #0
    or      v3, vz, #0
    or      v4, vz, #0
    or      v5, vz, #0
    or      v6, vz, #0
    or      v7, vz, #0
    or      v8, vz, #0
    or      v9, vz, #0
    or      v10, vz, #0
    or      v11, vz, #0
    or      v12, vz, #0
    or      v13, vz, #0
    or      v14, vz, #0
    or      v15, vz, #0
    or      v16, vz, #0
    or      v17, vz, #0
    or      v18, vz, #0
    or      v19, vz, #0
    or      v20, vz, #0
    or      v21, vz, #0
    or      v22, vz, #0
    or      v23, vz, #0
    or      v24, vz, #0
    or      v25, vz, #0
    or      v26, vz, #0
    or      v27, vz, #0
    or      v28, vz, #0
    or      v29, vz, #0
    or      v30, vz, #0
    or      v31, vz, #0

    ; The default vector length is the max vector register length.
    cpuid   vl, z, z

    ; Initialize the stack.
    ; TODO(m): Set up the thread and frame pointers too.
    ldi     sp, #STACK_START


    ; ------------------------------------------------------------------------
    ; Call main().
    ; ------------------------------------------------------------------------

    ; s1 = argc
    ldi     s1, #1

    ; s2 = argv
    ldhi    s2, #argv@hi
    add     s2, s2, #argv@lo

    ; Jump to main().
    ldhi    s15, #main@hi
    jl      s15, #main@lo


    ; ------------------------------------------------------------------------
    ; Terminate the program.
    ; ------------------------------------------------------------------------

    ; We use extra nop:s to flush the pipeline.
    nop
    nop
    nop
    nop
    nop

    j       z   ; This traps in the simulator and in the VHDL test bench.

    nop
    nop
    nop
    nop
    nop


    .data
    .p2align 2

argv:
    .word   arg0

arg0:
    ; We provide a fake program name (just to have a valid call to main).
    .asciz  "program"
