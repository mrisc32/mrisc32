; -*- mode: mr32asm; tab-width: 4; indent-tabs-mode: nil; -*-

; Macro for pusing all scalar calle-saved registers.
    .macro  push_all_scalar_callee_saved_regs
    add     sp, sp, #-56
    stw     s16, sp, #0
    stw     s17, sp, #4
    stw     s18, sp, #8
    stw     s19, sp, #12
    stw     s20, sp, #16
    stw     s21, sp, #20
    stw     s22, sp, #24
    stw     s23, sp, #28
    stw     s24, sp, #32
    stw     s25, sp, #36
    stw     fp, sp, #40
    stw     tp, sp, #44
    stw     vl, sp, #48
    stw     lr, sp, #52
    .endm

; Macro for popping all scalar calle-saved registers.
    .macro  pop_all_scalar_callee_saved_regs
    ldw     s16, sp, #0
    ldw     s17, sp, #4
    ldw     s18, sp, #8
    ldw     s19, sp, #12
    ldw     s20, sp, #16
    ldw     s21, sp, #20
    ldw     s22, sp, #24
    ldw     s23, sp, #28
    ldw     s24, sp, #32
    ldw     s25, sp, #36
    ldw     fp, sp, #40
    ldw     tp, sp, #44
    ldw     vl, sp, #48
    ldw     lr, sp, #52
    add     sp, sp, #56
    .endm
