; -*- mode: mr32asm; tab-width: 4; indent-tabs-mode: nil; -*-
; -------------------------------------------------------------------------------------------------
; This is test program that tries to test as many asptects of the CPU as possible.
; -------------------------------------------------------------------------------------------------

boot:
    ; Start by setting up the stack and clearing the registers.
    ldi     sp, 0x00020000  ; We grow down from 128KB.
    cpuid   vl, z, z
    ldi     s1, 0
    ldi     s2, 0
    ldi     s3, 0
    ldi     s4, 0
    ldi     s5, 0
    ldi     s6, 0
    ldi     s7, 0
    ldi     s8, 0
    ldi     s9, 0
    ldi     s10, 0
    ldi     s11, 0
    ldi     s12, 0
    ldi     s13, 0
    ldi     s14, 0
    ldi     s15, 0
    ldi     s16, 0
    ldi     s17, 0
    ldi     s18, 0
    ldi     s19, 0
    ldi     s20, 0
    ldi     s21, 0
    ldi     s22, 0
    ldi     s23, 0
    ldi     s24, 0
    ldi     s25, 0
    ldi     s26, 0
    ldi     s27, 0
    ldi     s30, 0
    ldi     v1, 0
    ldi     v2, 0
    ldi     v3, 0
    ldi     v4, 0
    ldi     v5, 0
    ldi     v6, 0
    ldi     v7, 0
    ldi     v8, 0
    ldi     v9, 0
    ldi     v10, 0
    ldi     v11, 0
    ldi     v12, 0
    ldi     v13, 0
    ldi     v14, 0
    ldi     v15, 0
    ldi     v16, 0
    ldi     v17, 0
    ldi     v18, 0
    ldi     v19, 0
    ldi     v20, 0
    ldi     v21, 0
    ldi     v22, 0
    ldi     v23, 0
    ldi     v24, 0
    ldi     v25, 0
    ldi     v26, 0
    ldi     v27, 0
    ldi     v28, 0
    ldi     v29, 0
    ldi     v30, 0
    ldi     v31, 0


;--------------------------------------------------------------------------------------------------
; Start of test
;--------------------------------------------------------------------------------------------------

start:
    ldi     s25, 0x10000        ; s20 points to the start of the result output area

    ; Prepare some registers with values to use in the tests.
    ldi     s1, 1234
    ldi     s2, 5678
    ldi     s3, 1
    nop                         ; Use nop:s to skip operand forwarding logic.
    nop
    nop
    nop

;--------------------------------------------------------------------------------------------------
; Instruction tests (scalar)
;
; These tests aim to test the individual instructions.
;--------------------------------------------------------------------------------------------------

test_alu:
    ; CPUID
    cpuid   s4, z, z
    cpuid   s5, z, s3
    cpuid   s6, s3, z
    cpuid   s7, s3, s3

    stw     s4, s25, 0
    stw     s5, s25, 4
    stw     s6, s25, 8
    stw     s7, s25, 12
    add     s25, s25, 16

    ; Bitwise operations
    or      s4, s1, 0x1234
    or      s5, s1, s2
    nor     s6, s1, 0x1234
    nor     s7, s1, s2
    and     s8, s1, 0x1234
    and     s9, s1, s2
    bic     s10, s1, 0x1234
    bic     s11, s1, s2
    xor     s12, s1, 0x1234
    xor     s13, s1, s2

    stw     s4, s25, 0
    stw     s5, s25, 4
    stw     s6, s25, 8
    stw     s7, s25, 12
    stw     s8, s25, 16
    stw     s9, s25, 20
    stw     s10, s25, 24
    stw     s11, s25, 28
    stw     s12, s25, 32
    stw     s13, s25, 36
    add     s25, s25, 40

    ; Arithmetic operations
    ; TODO(m): Implement me!

    ; Compare/set operations
    ; TODO(m): Implement me!

    ; Min/max operations
    ; TODO(m): Implement me!

    ; Shift operations
    ; TODO(m): Implement me!

    ; SHUF
    ; TODO(m): Implement me!

    ; CLZ
    ; TODO(m): Implement me!

    ; REV
    ; TODO(m): Implement me!


test_sau:
    ; Saturating operations
    ; TODO(m): Implement me!

    ; Halving operations
    ; TODO(m): Implement me!


test_mul:
    ; Multiplication operations
    ; TODO(m): Implement me!


test_div:
    ; Division/remainder operations
    ; TODO(m): Implement me!


test_fpu:
    ; TODO(m): Implement me!


test_load_store:
    ; TODO(m): Implement me!


test_branch:
    ; TODO(m): Implement me!


;--------------------------------------------------------------------------------------------------
; Vector tests
;
; These tests aim to test different aspects of the vector functionality.
;--------------------------------------------------------------------------------------------------

test_vector_length:
    ; TODO(m): Implement me!


test_vector_folding:
    ; TODO(m): Implement me!


test_vector_addressing:
    ; TODO(m): Implement me!


;--------------------------------------------------------------------------------------------------
; Operand forwarding tests
;
; Test operand forwarding during different conditions.
;--------------------------------------------------------------------------------------------------

    ; TODO(m): Implement me!




;--------------------------------------------------------------------------------------------------
; End of test
;--------------------------------------------------------------------------------------------------

end:
    nop
    nop
    nop
    nop
    nop
    nop

    j       z       ; End the program

    nop
    nop
    nop
    nop
    nop

