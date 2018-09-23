; -*- mode: mr32asm; tab-width: 4; indent-tabs-mode: nil; -*-
; -------------------------------------------------------------------------------------------------
; This is test program that tries to test as many asptects of the CPU as possible.
; -------------------------------------------------------------------------------------------------

STACK_START = 0x00020000  ; We grow down from 128KB.
PASS_CNT = 0x10000        ; Location of the count of passed tests.
PASS_FAIL = 0x10004       ; Start of memory area where the test pass/fail results are stored.
TEST_OUTPUT = 0x11000     ; Start of memory area where the test output is stored.

boot:
    ; Start by setting up the stack and clearing the registers.
    ldi     sp, STACK_START
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
    ldi     s1, PASS_CNT
    stw     z, s1, 0            ; Clear the PASS_CNT counter.

    ; Prepare some registers with values to use in the tests.
    ldi     s22, 1234
    ldi     s21, 5678
    ldi     s20, 1

    ; Loop over all the tests.
    ldi     s25, TEST_OUTPUT    ; s25 points to the start of the result output area.
    ldi     s24, PASS_FAIL      ; s24 points to the start of pass/fail results.
    lea     s23, .test_list
.test_loop:
    ; Call the next test.
    ldw     s1, s23, 0
    add     s23, s23, 4
    bz      s1, end
    jl      s1

    ; Store the pass/fail result.
    stw     s1, s24, 0
    add     s24, s24, 4

    b       .test_loop


.test_list:
    .u32    test_cpuid
    .u32    test_alu_bitiwse
    .u32    test_alu_arithmetic
    .u32    test_alu_compare
    .u32    test_alu_min_max
    .u32    test_alu_shift
    .u32    test_alu_shuf
    .u32    0



;--------------------------------------------------------------------------------------------------
; Check results.
; s1 = correct results (first word is the results count).
; s2 = actual results
;
; Note: We make excessive use of NOP:s to minimize potential pipeline issues (forwarding etc).
;--------------------------------------------------------------------------------------------------

check_results:
    ldw     s3, s1, 0       ; s3 = the results count.
    add     s1, s1, 4
    nop
    nop
    nop
    nop
    ldi     s4, -1
    bz      s3, .done

.compare_loop:
    ldw     s5, s1, 0
    ldw     s6, s2, 0
    add     s3, s3, -1
    add     s1, s1, 4
    add     s2, s2, 4
    nop
    seq     s5, s5, s6
    nop
    nop
    nop
    nop
    and     s4, s4, s5
    bnz     s3, .compare_loop

.done:
    nop
    nop
    nop
    nop

    ; Increase the PASS_CNT counter if the test passed.
    ldi     s1, PASS_CNT
    ldw     s2, s1, 0
    and     s3, s4, 1
    nop
    nop
    nop
    nop
    add     s2, s2, s3
    nop
    nop
    nop
    nop
    stw     s2, s1, 0
.results_mismatch:
    mov     s1, s4
    j       lr


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


;--------------------------------------------------------------------------------------------------
; CPU identification tests.
;--------------------------------------------------------------------------------------------------

test_cpuid:
    ; MaxVectorLength should be 1 << Log2MaxVectorLength
    cpuid   s1, z, z            ; 0x00000000:0x00000000 GetMaxVectorLength
    cpuid   s2, z, s20          ; 0x00000000:0x00000001 GetLog2MaxVectorLength
    lsl     s2, s20, s2         ; s2 = 1 << s2
    seq     s1, s1, s2          ; s1 == s2 ?

    ; BaseFeatures should be != 0
    cpuid   s2, s20, z          ; 0x00000001:0x00000000 GetBaseFeatures
    sne     s2, s2, z           ; s2 != 0 ?

    ; Undefined commands should return zero.
    cpuid   s3, s20, s20        ; 0x00000001:0x00000001 - Undefiend
    cpuid   s4, s21, s20        ; ... Undefiend
    cpuid   s5, s21, s22        ; ... Undefiend
    or      s3, s3, s4
    or      s3, s3, s5
    seq     s3, s3, z           ; s3 == 0 ?

    ; Store results.
    stw     s1, s25, 0
    stw     s2, s25, 4
    stw     s3, s25, 8

    ; Check results.
    lea     s1, .correct_results
    mov     s2, s25
    add     s25, s25, 12
    b       check_results

.correct_results:
    .u32    3
    .u32    0xffffffff, 0xffffffff, 0xffffffff


;--------------------------------------------------------------------------------------------------
; Instruction tests (scalar)
;
; These tests aim to test the individual instructions.
;--------------------------------------------------------------------------------------------------

test_alu_bitiwse:
    ; Bitwise operations
    or      s1, s22, 0x1234
    or      s2, s22, s21
    nor     s3, s22, 0x1234
    nor     s4, s22, s21
    and     s5, s22, 0x1234
    and     s6, s22, s21
    bic     s7, s22, 0x1234
    bic     s8, s22, s21
    xor     s9, s22, 0x1234
    xor     s10, s22, s21

    ; Store results.
    stw     s1, s25, 0
    stw     s2, s25, 4
    stw     s3, s25, 8
    stw     s4, s25, 12
    stw     s5, s25, 16
    stw     s6, s25, 20
    stw     s7, s25, 24
    stw     s8, s25, 28
    stw     s9, s25, 32
    stw     s10, s25, 36

    ; Check results.
    lea     s1, .correct_results
    mov     s2, s25
    add     s25, s25, 40
    b       check_results

.correct_results:
    .u32    10
    .u32    0x000016f6, 0x000016fe, 0xffffe909, 0xffffe901
    .u32    0x00000010, 0x00000402, 0x000004c2, 0x000000d0
    .u32    0x000016e6, 0x000012fc


test_alu_arithmetic:
    ; Arithmetic operations
    add     s1, s22, 0x1234
    add     s2, s22, s21
    sub     s3, 0x1234, s22
    sub     s4, s22, s21

    ; Store results.
    stw     s1, s25, 0
    stw     s2, s25, 4
    stw     s3, s25, 8
    stw     s4, s25, 12

    ; Check results.
    lea     s1, .correct_results
    mov     s2, s25
    add     s25, s25, 16
    b       check_results

.correct_results:
    .u32    4
    .u32    0x00001706, 0x00001b00, 0x00000d62, 0xffffeea4


test_alu_compare:
    ; Compare/set operations
    seq     s1, s22, -1234
    seq     s2, s22, s21
    sne     s3, s22, -1234
    sne     s4, s22, s21
    slt     s5, s22, -1234
    slt     s6, s22, s21
    sltu    s7, s22, -1234
    sltu    s8, s22, s21
    sle     s9, s22, -1234
    sle     s10, s22, s21
    sleu    s11, s22, -1234
    sleu    s12, s22, s21

    ; Store results.
    stw     s1, s25, 0
    stw     s2, s25, 4
    stw     s3, s25, 8
    stw     s4, s25, 12
    stw     s5, s25, 16
    stw     s6, s25, 20
    stw     s7, s25, 24
    stw     s8, s25, 28
    stw     s9, s25, 32
    stw     s10, s25, 36
    stw     s11, s25, 40
    stw     s12, s25, 44

    ; Check results.
    lea     s1, .correct_results
    mov     s2, s25
    add     s25, s25, 48
    b       check_results

.correct_results:
    .u32    12
    .u32    0x00000000, 0x00000000, 0xffffffff, 0xffffffff
    .u32    0xffffffff, 0xffffffff, 0x00000000, 0xffffffff
    .u32    0xffffffff, 0xffffffff, 0x00000000, 0xffffffff


test_alu_min_max:
    ; Min/max operations
    min     s1, s22, 0x1234
    min     s2, s22, s21
    max     s3, s22, -1234
    max     s4, s22, s21
    minu    s5, s22, 0x1234
    minu    s6, s22, s21
    maxu    s7, s22, -1234
    maxu    s8, s22, s21

    ; Store results.
    stw     s1, s25, 0
    stw     s2, s25, 4
    stw     s3, s25, 8
    stw     s4, s25, 12
    stw     s5, s25, 16
    stw     s6, s25, 20
    stw     s7, s25, 24
    stw     s8, s25, 28

    ; Check results.
    lea     s1, .correct_results
    mov     s2, s25
    add     s25, s25, 32
    b       check_results

.correct_results:
    .u32    8
    .u32    0x000004d2, 0x000004d2, 0x000004d2, 0x0000162e
    .u32    0x000004d2, 0x000004d2, 0xfffffb2e, 0x0000162e


test_alu_shift:
    ; Shift operations
    asr     s1, s22, 5
    asr     s2, s22, s21
    lsl     s3, s22, 5
    lsl     s4, s22, s21
    lsr     s5, s22, 5
    lsr     s6, s22, s21

    ; Store results.
    stw     s1, s25, 0
    stw     s2, s25, 4
    stw     s3, s25, 8
    stw     s4, s25, 12
    stw     s5, s25, 16
    stw     s6, s25, 20

    ; Check results.
    lea     s1, .correct_results
    mov     s2, s25
    add     s25, s25, 24
    b       check_results

.correct_results:
    .u32    6
    .u32    0x00000026, 0x00000000, 0x00009a40, 0x01348000
    .u32    0x00000026, 0x00000000


test_alu_shuf:
    ; SHUF
    shuf    s1, s22, s21
    shuf    s2, s22, 0b0000000000000     ; 1 x u8 -> 4 x u8
    shuf    s3, s22, 0b1100100100000     ; i8 -> i32
    shuf    s4, s22, 0b0100100100000     ; u8 -> u32
    shuf    s5, s22, 0b0000001010011     ; Reverse byte order

    ; Store results.
    stw     s1, s25, 0
    stw     s2, s25, 4
    stw     s3, s25, 8
    stw     s4, s25, 12
    stw     s5, s25, 16

    ; Check results.
    lea     s1, .correct_results
    mov     s2, s25
    add     s25, s25, 20
    b       check_results

.correct_results:
    .u32    5
    .u32    0x00d20000, 0xd2d2d2d2, 0xffffffd2, 0x000000d2
    .u32    0xd2040000


test_alu_clz:
    ; CLZ
    ; TODO(m): Implement me!

test_alu_rev:
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

