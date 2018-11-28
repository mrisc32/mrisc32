; -*- mode: mr32asm; tab-width: 4; indent-tabs-mode: nil; -*-
; -------------------------------------------------------------------------------------------------
; This is test program that tries to test as many asptects of the CPU as possible.
; -------------------------------------------------------------------------------------------------

STACK_START   = 0x20000     ; We grow down from 128KB.
PASS_FAIL_CNT = 0x10000     ; Location of the count of passed and failed tests (two words).
PASS_FAIL     = 0x10008     ; Start of memory area where the test pass/fail results are stored.
TEST_OUTPUT   = 0x11000     ; Start of memory area where the test output is stored.

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
    or      v1, vz, 0
    or      v2, vz, 0
    or      v3, vz, 0
    or      v4, vz, 0
    or      v5, vz, 0
    or      v6, vz, 0
    or      v7, vz, 0
    or      v8, vz, 0
    or      v9, vz, 0
    or      v10, vz, 0
    or      v11, vz, 0
    or      v12, vz, 0
    or      v13, vz, 0
    or      v14, vz, 0
    or      v15, vz, 0
    or      v16, vz, 0
    or      v17, vz, 0
    or      v18, vz, 0
    or      v19, vz, 0
    or      v20, vz, 0
    or      v21, vz, 0
    or      v22, vz, 0
    or      v23, vz, 0
    or      v24, vz, 0
    or      v25, vz, 0
    or      v26, vz, 0
    or      v27, vz, 0
    or      v28, vz, 0
    or      v29, vz, 0
    or      v30, vz, 0
    or      v31, vz, 0


;--------------------------------------------------------------------------------------------------
; Main program / test loop.
;--------------------------------------------------------------------------------------------------

main:
    ; Clear the pass/fail counters.
    ldi     s1, PASS_FAIL_CNT
    stw     z, s1, 0
    stw     z, s1, 4

    ; Prepare some registers with values to use in the tests.
    ldi     s18, 0x12345678
    ldi     s19, 0xfedcba98
    ldi     s20, 1
    ldi     s21, 5678
    ldi     s22, 1234

    ; Loop over all the tests.
    ldi     s25, TEST_OUTPUT    ; s25 points to the start of the result output area.
    ldi     s24, PASS_FAIL      ; s24 points to the start of pass/fail results.
    lea     s23, .test_list
.test_loop:
    ; Call the next test.
    ldw     s1, s23, 0
    add     s23, s23, 4
    bz      s1, .end
    jl      s1

    ; Store the pass/fail result.
    stw     s1, s24, 0
    add     s24, s24, 4

    b       .test_loop

.end:
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


.test_list:
    .u32    test_cpuid
    .u32    test_alu_bitiwse
    .u32    test_alu_arithmetic
    .u32    test_alu_compare
    .u32    test_alu_min_max
    .u32    test_alu_shift
    .u32    test_alu_shuf
    .u32    test_alu_clz_rev
    .u32    test_sau
    .u32    test_mul
    .u32    test_div
    .u32    test_load_store
    .u32    test_branch
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
    ldi     s5, -1          ; s5 = are all values equal?
    bz      s3, .done

.compare_loop:
    ldw     s6, s1, 0       ; Reference value
    ldw     s7, s2, 0       ; Actual value
    add     s3, s3, -1
    add     s1, s1, 4
    add     s2, s2, 4
    nop
    seq     s6, s6, s7      ; Equal?
    nop
    nop
    nop
    nop
    and     s5, s5, s6      ; Are all values still equal?
    bnz     s3, .compare_loop

.done:
    nop
    nop
    nop
    nop

    ; Increase the pass/fail counters.
    ldi     s1, PASS_FAIL_CNT
    nop
    nop
    nop
    nop
    ldw     s2, s1, 0       ; Load pass count.
    ldw     s3, s1, 4       ; Load fail count.
    and     s4, s5, 1       ; s4 = 1 for pass, 0 for fail.
    nop
    nop
    nop
    nop
    add     s2, s2, s4
    xor     s4, s4, 1       ; s4 = 0 for pass, 1 for fail.
    nop
    nop
    nop
    nop
    add     s3, s3, s4
    nop
    nop
    nop
    nop
    stw     s2, s1, 0       ; Update pass count.
    stw     s3, s1, 4       ; Update fail count.

    mov     s1, s5          ; Return pass/fail in s1.
    j       lr


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


;--------------------------------------------------------------------------------------------------
; ALU
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


test_alu_clz_rev:
    ; CLZ
    clz     s1, s20
    clz     s2, s21
    clz     s3, s22

    ; REV
    rev     s4, s20
    rev     s5, s21
    rev     s6, s22

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
    .u32    0x0000001f, 0x00000013, 0x00000015, 0x80000000
    .u32    0x74680000, 0x4b200000


;--------------------------------------------------------------------------------------------------
; SAU
;--------------------------------------------------------------------------------------------------

test_sau:
    ; Saturating operations
    adds    s1, s20, s21
    adds.h  s2, s20, s21
    adds.b  s3, s20, s21
    addsu   s4, s20, s21
    addsu.h s5, s20, s21
    addsu.b s6, s20, s21
    subs    s7, s20, s21
    subs.h  s8, s20, s21
    subs.b  s9, s20, s21
    subsu   s10, s20, s21
    subsu.h s11, s20, s21
    subsu.b s12, s20, s21

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

    ; Halving operations
    addh    s1, s20, s21
    addh.h  s2, s20, s21
    addh.b  s3, s20, s21
    addhu   s4, s20, s21
    addhu.h s5, s20, s21
    addhu.b s6, s20, s21
    subh    s7, s20, s21
    subh.h  s8, s20, s21
    subh.b  s9, s20, s21
    subhu   s10, s20, s21
    subhu.h s11, s20, s21
    subhu.b s12, s20, s21

    ; Store results.
    stw     s1, s25, 48
    stw     s2, s25, 52
    stw     s3, s25, 56
    stw     s4, s25, 60
    stw     s5, s25, 64
    stw     s6, s25, 68
    stw     s7, s25, 72
    stw     s8, s25, 76
    stw     s9, s25, 80
    stw     s10, s25, 84
    stw     s11, s25, 88
    stw     s12, s25, 92

    ; Check results.
    lea     s1, .correct_results
    mov     s2, s25
    add     s25, s25, 96
    b       check_results

.correct_results:
    .u32    24
    .u32    0x0000162f, 0x0000162f, 0x0000162f, 0x0000162f
    .u32    0x0000162f, 0x0000162f, 0xffffe9d3, 0x0000e9d3
    .u32    0x0000ead3, 0x00000000, 0x00000000, 0x00000000
    .u32    0x00000b17, 0x00000b17, 0x00000b17, 0x00000b17
    .u32    0x00000b17, 0x00000b17, 0xfffff4e9, 0x0000f4e9
    .u32    0x0000f5e9, 0xfffff4e9, 0x0000f4e9, 0x0000f5e9


;--------------------------------------------------------------------------------------------------
; MUL
;--------------------------------------------------------------------------------------------------

test_mul:
    ; Multiplication operations
    mulq    s1, s18, s19
    mulq.h  s2, s18, s19
    mulq.b  s3, s18, s19
    mul     s4, s18, s19
    mul.h   s5, s18, s19
    mul.b   s6, s18, s19
    mulhi   s7, s18, s19
    mulhi.h s8, s18, s19
    mulhi.b s9, s18, s19
    mulhiu   s10, s18, s19
    mulhiu.h s11, s18, s19
    mulhiu.b s12, s18, s19

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
    .u32    0xffd69324, 0xffd6d11d, 0xfff1d09e, 0x35068740
    .u32    0x3cb08740, 0xdcb07c40, 0xffeb4992, 0xffebe88e
    .u32    0xfff8e8cf, 0x121fa00a, 0x121f3f06, 0x112c3e47


;--------------------------------------------------------------------------------------------------
; DIV
;--------------------------------------------------------------------------------------------------

test_div:
    ; Division/remainder operations
    div     s1, s19, s22
    div.h   s2, s19, s22
    div.b   s3, s19, s22
    divu    s4, s19, s22
    divu.h  s5, s19, s22
    divu.b  s6, s19, s22
    rem     s7, s19, s22
    rem.h   s8, s19, s22
    rem.b   s9, s19, s22
    remu    s10, s19, s22
    remu.h  s11, s19, s22
    remu.b  s12, s19, s22

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
    .u32    0xffffc394, 0xfffffff2, 0xffffef02, 0x0034df5f
    .u32    0xffff0026, 0xffff2e00, 0xfffffb30, 0xfedcfe14
    .u32    0xfedcfef4, 0x000002aa, 0xfedc036c, 0xfedc0298


;--------------------------------------------------------------------------------------------------
; FPU
;--------------------------------------------------------------------------------------------------

test_fpu:
    ; TODO(m): Implement me!


;--------------------------------------------------------------------------------------------------
; Load/Store
;--------------------------------------------------------------------------------------------------

test_load_store:
    ; Allocate stack space.
    add     sp, sp, -8

    ; Store data of different types to memory.
    ldi     s10, -56
    ldi     s11, -78
    ldi     s12, -1234
    ldi     s13, 12345678

    ; Immediate offset.
    stb     s10, sp, 0
    stb     s11, sp, 1

    ; Register offset.
    ldi     s10, 2
    ldi     s11, 4
    sth     s12, sp, s10
    stw     s13, sp, s11

    ; Load data of different types from memory.

    ; Immediate offset.
    ldb     s1, sp, 0
    ldb     s2, sp, 1
    ldub    s3, sp, 0
    ldub    s4, sp, 1

    ; Register offset.
    ldi     s10, 2
    ldi     s11, 4
    ldh     s5, sp, s10
    lduh    s6, sp, s10
    ldw     s7, sp, s11

    ; Free stack space.
    add     sp, sp, 8

    ; Store results.
    stw     s1, s25, 0
    stw     s2, s25, 4
    stw     s3, s25, 8
    stw     s4, s25, 12
    stw     s5, s25, 16
    stw     s6, s25, 20
    stw     s7, s25, 24

    ; Check results.
    lea     s1, .correct_results
    mov     s2, s25
    add     s25, s25, 28
    b       check_results


.correct_results:
    .u32    7
    .u32    0xffffffc8, 0xffffffb2, 0x000000c8, 0x000000b2
    .u32    0xfffffb2e, 0x0000fb2e, 0x00bc614e


;--------------------------------------------------------------------------------------------------
; Branch
;--------------------------------------------------------------------------------------------------

test_branch:
    ; Speculative instructions are cancelled.
    ldi     s1, 0x1000
    ldw     s2, .value1
    ldw     s3, .value2
    b       .skip
    ldi     s3, 0x2000
    ldi     s3, 0x3000
    ldi     s3, 0x4000
.skip:
    ldi     s4, 0x1003

    ; Operand forwarding for conditional branches.
    ldi     s5, 0
    nop
    nop
    nop
    nop
    nop
    add     s5, s5, 0x1004
    bnz     s5, .ofwd_correct
    ldi     s5, 0x5000
.ofwd_correct:

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

.value1:
    .u32    0x1001
.value2:
    .u32    0x1002

.correct_results:
    .u32    5
    .u32    0x1000, 0x1001, 0x1002, 0x1003
    .u32    0x1004



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

