; -*- mode: mr32asm; tab-width: 4; indent-tabs-mode: nil; -*-
; -------------------------------------------------------------------------------------------------
; This is a test program that tries to test as many asptects of the CPU as possible.
; -------------------------------------------------------------------------------------------------

    .include    "mrisc32-macros.inc"

PASS_FAIL_CNT = 0x10000     ; Location of the count of passed and failed tests (two words).
PASS_FAIL     = 0x10008     ; Start of memory area where the test pass/fail results are stored.
TEST_OUTPUT   = 0x11000     ; Start of memory area where the test output is stored.

;--------------------------------------------------------------------------------------------------
; Main program / test loop.
;--------------------------------------------------------------------------------------------------

    .text
    .globl  main

main:
    push_all_scalar_callee_saved_regs

    ; Clear the pass/fail counters.
    ldi     s1, #PASS_FAIL_CNT
    stw     z, s1, #0
    stw     z, s1, #4

    ; Prepare some registers with values to use in the tests.
    ldhi    s18, #0x12345678@hi
    or      s18, s18, #0x12345678@lo
    ldhi    s19, #0xfedcba98@hi
    or      s19, s19, #0xfedcba98@lo
    ldi     s20, #1
    ldi     s21, #5678
    ldi     s22, #1234

    ; Loop over all the tests.
    ldi     s25, #TEST_OUTPUT   ; s25 points to the start of the result output area.
    ldi     s24, #PASS_FAIL     ; s24 points to the start of pass/fail results.
    add     s23, pc, #test_list@pc
1$:
    ; Call the next test.
    ldw     s1, s23, #0
    add     s23, s23, #4
    bz      s1, #2$
    jl      s1

    ; Store the pass/fail result.
    stw     s1, s24, #0
    add     s24, s24, #4

    b       #1$

2$:
    ; Return from main() with exit code 0.
    pop_all_scalar_callee_saved_regs
    ldi     s1, #0
    j       lr


test_list:
    .word   test_cpuid
    .word   test_alu_bitiwse
    .word   test_alu_arithmetic
    .word   test_alu_compare
    .word   test_alu_min_max
    .word   test_alu_shift
    .word   test_alu_shuf
    .word   test_alu_clz_rev
    .word   test_sau
    .word   test_mul
    .word   test_div
    .word   test_fpu
    .word   test_load_store
    .word   test_branch
    .word   test_operand_forwarding
    .word   0



;--------------------------------------------------------------------------------------------------
; Check results.
; s1 = correct results (first word is the results count).
; s2 = actual results
;
; Note: We make excessive use of NOP:s to minimize potential pipeline issues (forwarding etc).
;--------------------------------------------------------------------------------------------------

check_results:
    ldw     s3, s1, #0      ; s3 = the results count.
    add     s1, s1, #4
    nop
    nop
    nop
    nop
    ldi     s5, #-1         ; s5 = are all values equal?
    bz      s3, #2$

1$:
    ldw     s6, s1, #0      ; Reference value
    ldw     s7, s2, #0      ; Actual value
    add     s3, s3, #-1
    add     s1, s1, #4
    add     s2, s2, #4
    nop
    seq     s6, s6, s7      ; Equal?
    nop
    nop
    nop
    nop
    and     s5, s5, s6      ; Are all values still equal?
    bnz     s3, #1$

2$:
    nop
    nop
    nop
    nop

    ; Increase the pass/fail counters.
    ldi     s1, #PASS_FAIL_CNT
    nop
    nop
    nop
    nop
    ldw     s2, s1, #0      ; Load pass count.
    ldw     s3, s1, #4      ; Load fail count.
    and     s4, s5, #1      ; s4 = 1 for pass, 0 for fail.
    nop
    nop
    nop
    nop
    add     s2, s2, s4
    xor     s4, s4, #1      ; s4 = 0 for pass, 1 for fail.
    nop
    nop
    nop
    nop
    add     s3, s3, s4
    nop
    nop
    nop
    nop
    stw     s2, s1, #0      ; Update pass count.
    stw     s3, s1, #4      ; Update fail count.

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
    stw     s1, s25, #0
    stw     s2, s25, #4
    stw     s3, s25, #8

    ; Check results.
    add     s1, pc, #test_cpuid_correct_results@pc
    mov     s2, s25
    add     s25, s25, #12
    b       #check_results

test_cpuid_correct_results:
    .word   3
    .word   0xffffffff, 0xffffffff, 0xffffffff


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
    or      s1, s22, #0x1234
    or      s2, s22, s21
    nor     s3, s22, #0x1234
    nor     s4, s22, s21
    and     s5, s22, #0x1234
    and     s6, s22, s21
    bic     s7, s22, #0x1234
    bic     s8, s22, s21
    xor     s9, s22, #0x1234
    xor     s10, s22, s21

    ; Store results.
    stw     s1, s25, #0
    stw     s2, s25, #4
    stw     s3, s25, #8
    stw     s4, s25, #12
    stw     s5, s25, #16
    stw     s6, s25, #20
    stw     s7, s25, #24
    stw     s8, s25, #28
    stw     s9, s25, #32
    stw     s10, s25, #36

    ; Check results.
    add     s1, pc, #test_alu_bitiwse_correct_results@pc
    mov     s2, s25
    add     s25, s25, #40
    b       #check_results

test_alu_bitiwse_correct_results:
    .word   10
    .word   0x000016f6, 0x000016fe, 0xffffe909, 0xffffe901
    .word   0x00000010, 0x00000402, 0x000004c2, 0x000000d0
    .word   0x000016e6, 0x000012fc


test_alu_arithmetic:
    ; Arithmetic operations
    add     s1, s22, #0x1234
    add     s2, s22, s21
    add.h   s3, s22, s21
    add.b   s4, s22, s21
    sub     s5, #0x1234, s22
    sub     s6, s22, s21
    sub.h   s7, s22, s21
    sub.b   s8, s22, s21
    addpchi s9, #0x98765000
    sub     s9, s9, pc

    ; Store results.
    stw     s1, s25, #0
    stw     s2, s25, #4
    stw     s3, s25, #8
    stw     s4, s25, #12
    stw     s5, s25, #16
    stw     s6, s25, #20
    stw     s7, s25, #24
    stw     s8, s25, #28
    stw     s9, s25, #32

    ; Check results.
    add     s1, pc, #test_alu_arithmetic_correct_results@pc
    mov     s2, s25
    add     s25, s25, #36
    b       #check_results

test_alu_arithmetic_correct_results:
    .word   9
    .word   0x00001706, 0x00001b00, 0x00001b00, 0x00001a00
    .word   0x00000d62, 0xffffeea4, 0x0000eea4, 0x0000eea4
    .word   0x98764ffc


test_alu_compare:
    ; Unpacked compare/set operations
    seq     s1, s22, #-1234
    seq     s2, s22, s21
    sne     s3, s22, #-1234
    sne     s4, s22, s21
    slt     s5, s22, #-1234
    slt     s6, s22, s21
    sltu    s7, s22, #-1234
    sltu    s8, s22, s21
    sle     s9, s22, #-1234
    sle     s10, s22, s21
    sleu    s11, s22, #-1234
    sleu    s12, s22, s21

    ; Store results.
    stw     s1, s25, #0
    stw     s2, s25, #4
    stw     s3, s25, #8
    stw     s4, s25, #12
    stw     s5, s25, #16
    stw     s6, s25, #20
    stw     s7, s25, #24
    stw     s8, s25, #28
    stw     s9, s25, #32
    stw     s10, s25, #36
    stw     s11, s25, #40
    stw     s12, s25, #44

    ; Packed compare/set operations
    seq.h   s1, s22, s21
    seq.b   s2, s22, s21
    sne.h   s3, s22, s21
    sne.b   s4, s22, s21
    slt.h   s5, s22, s21
    slt.b   s6, s22, s21
    sltu.h  s7, s22, s21
    sltu.b  s8, s22, s21
    sle.h   s9, s22, s21
    sle.b   s10, s22, s21
    sleu.h  s11, s22, s21
    sleu.b  s12, s22, s21

    ; Store results.
    stw     s1, s25, #48
    stw     s2, s25, #52
    stw     s3, s25, #56
    stw     s4, s25, #60
    stw     s5, s25, #64
    stw     s6, s25, #68
    stw     s7, s25, #72
    stw     s8, s25, #76
    stw     s9, s25, #80
    stw     s10, s25, #84
    stw     s11, s25, #88
    stw     s12, s25, #92

    ; Check results.
    add     s1, pc, #test_alu_compare_correct_results@pc
    mov     s2, s25
    add     s25, s25, #96
    b       #check_results

test_alu_compare_correct_results:
    .word   24
    .word   0x00000000, 0x00000000, 0xffffffff, 0xffffffff
    .word   0x00000000, 0xffffffff, 0xffffffff, 0xffffffff
    .word   0x00000000, 0xffffffff, 0xffffffff, 0xffffffff
    .word   0xffff0000, 0xffff0000, 0x0000ffff, 0x0000ffff
    .word   0x0000ffff, 0x0000ffff, 0x0000ffff, 0x0000ff00
    .word   0xffffffff, 0xffffffff, 0xffffffff, 0xffffff00


test_alu_min_max:
    ; Min/max operations
    min     s1, s22, #0x1234
    min     s2, s22, s21
    min.h   s3, s22, s21
    min.b   s4, s22, s21
    max     s5, s22, #-1234
    max     s6, s22, s21
    max.h   s7, s22, s21
    max.b   s8, s22, s21
    minu    s9, s22, #0x1234
    minu    s10, s22, s21
    minu.h  s11, s22, s21
    minu.b  s12, s22, s21
    maxu    s13, s22, #-1234
    maxu    s14, s22, s21
    maxu.h  s15, s22, s21
    maxu.b  s16, s22, s21

    ; Store results.
    stw     s1, s25, #0
    stw     s2, s25, #4
    stw     s3, s25, #8
    stw     s4, s25, #12
    stw     s5, s25, #16
    stw     s6, s25, #20
    stw     s7, s25, #24
    stw     s8, s25, #28
    stw     s9, s25, #32
    stw     s10, s25, #36
    stw     s11, s25, #40
    stw     s12, s25, #44
    stw     s13, s25, #48
    stw     s14, s25, #52
    stw     s15, s25, #56
    stw     s16, s25, #60

    ; Check results.
    add     s1, pc, #test_alu_min_max_correct_results@pc
    mov     s2, s25
    add     s25, s25, #64
    b       #check_results

test_alu_min_max_correct_results:
    .word   16
    .word   0x000004d2, 0x000004d2, 0x000004d2, 0x000004d2
    .word   0x000004d2, 0x0000162e, 0x0000162e, 0x0000162e
    .word   0x000004d2, 0x000004d2, 0x000004d2, 0x0000042e
    .word   0xfffffb2e, 0x0000162e, 0x0000162e, 0x000016d2


test_alu_shift:
    ; Shift operations
    ldi     s15, #0x00000004            ; Shift amount for words
    ldi     s16, #0x00020004            ; Shift amount for half words
    ldhi    s17, #0x01020304@hi         ; Shift amount for bytes
    or      s17, s17, #0x01020304@lo
    asr     s1, s19, #5
    asr     s2, s19, s15
    asr.h   s3, s19, s16
    asr.b   s4, s19, s17
    lsl     s5, s19, #5
    lsl     s6, s19, s15
    lsl.h   s7, s19, s16
    lsl.b   s8, s19, s17
    lsr     s9, s19, #5
    lsr     s10, s19, s15
    lsr.h   s11, s19, s16
    lsr.b   s12, s19, s17

    ; Store results.
    stw     s1, s25, #0
    stw     s2, s25, #4
    stw     s3, s25, #8
    stw     s4, s25, #12
    stw     s5, s25, #16
    stw     s6, s25, #20
    stw     s7, s25, #24
    stw     s8, s25, #28
    stw     s9, s25, #32
    stw     s10, s25, #36
    stw     s11, s25, #40
    stw     s12, s25, #44

    ; Check results.
    add     s1, pc, #test_alu_shift_correct_results@pc
    mov     s2, s25
    add     s25, s25, #48
    b       #check_results

test_alu_shift_correct_results:
    .word   12
    .word   0xfff6e5d4, 0xffedcba9, 0xffb7fba9, 0xfff7f7f9
    .word   0xdb975300, 0xedcba980, 0xfb70a980, 0xfc70d080
    .word   0x07f6e5d4, 0x0fedcba9, 0x3fb70ba9, 0x7f371709


test_alu_shuf:
    ; SHUF
    shuf    s1, s22, s21
    shuf    s2, s22, #0b0000000000000    ; 1 x u8 -> 4 x u8
    shuf    s3, s22, #0b1100100100000    ; i8 -> i32
    shuf    s4, s22, #0b0100100100000    ; u8 -> u32
    shuf    s5, s22, #0b0000001010011    ; Reverse byte order

    ; Store results.
    stw     s1, s25, #0
    stw     s2, s25, #4
    stw     s3, s25, #8
    stw     s4, s25, #12
    stw     s5, s25, #16

    ; Check results.
    add     s1, pc, #test_alu_shuf_correct_results@pc
    mov     s2, s25
    add     s25, s25, #20
    b       #check_results

test_alu_shuf_correct_results:
    .word   5
    .word   0x00d20000, 0xd2d2d2d2, 0xffffffd2, 0x000000d2
    .word   0xd2040000


test_alu_clz_rev:
    ; CLZ
    clz     s1, s20
    clz     s2, s21
    clz     s3, s22
    clz.h   s4, s20
    clz.h   s5, s21
    clz.h   s6, s22
    clz.b   s7, s20
    clz.b   s8, s21
    clz.b   s9, s22

    ; Store results.
    stw     s1, s25, #0
    stw     s2, s25, #4
    stw     s3, s25, #8
    stw     s4, s25, #12
    stw     s5, s25, #16
    stw     s6, s25, #20
    stw     s7, s25, #24
    stw     s8, s25, #28
    stw     s9, s25, #32

    ; REV
    rev     s1, s20
    rev     s2, s21
    rev     s3, s22
    rev.h   s4, s20
    rev.h   s5, s21
    rev.h   s6, s22
    rev.b   s7, s20
    rev.b   s8, s21
    rev.b   s9, s22

    ; Store results.
    stw     s1, s25, #36
    stw     s2, s25, #40
    stw     s3, s25, #44
    stw     s4, s25, #48
    stw     s5, s25, #52
    stw     s6, s25, #56
    stw     s7, s25, #60
    stw     s8, s25, #64
    stw     s9, s25, #68

    ; Check results.
    add     s1, pc, #test_alu_clz_rev_correct_results@pc
    mov     s2, s25
    add     s25, s25, #72
    b       #check_results

test_alu_clz_rev_correct_results:
    .word   18
    .word   0x0000001f, 0x00000013, 0x00000015, 0x0010000f
    .word   0x00100003, 0x00100005, 0x08080807, 0x08080302
    .word   0x08080500, 0x80000000, 0x74680000, 0x4b200000
    .word   0x00008000, 0x00007468, 0x00004b20, 0x00000080
    .word   0x00006874, 0x0000204b


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
    stw     s1, s25, #0
    stw     s2, s25, #4
    stw     s3, s25, #8
    stw     s4, s25, #12
    stw     s5, s25, #16
    stw     s6, s25, #20
    stw     s7, s25, #24
    stw     s8, s25, #28
    stw     s9, s25, #32
    stw     s10, s25, #36
    stw     s11, s25, #40
    stw     s12, s25, #44

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
    stw     s1, s25, #48
    stw     s2, s25, #52
    stw     s3, s25, #56
    stw     s4, s25, #60
    stw     s5, s25, #64
    stw     s6, s25, #68
    stw     s7, s25, #72
    stw     s8, s25, #76
    stw     s9, s25, #80
    stw     s10, s25, #84
    stw     s11, s25, #88
    stw     s12, s25, #92

    ; Check results.
    add     s1, pc, #test_sau_correct_results@pc
    mov     s2, s25
    add     s25, s25, #96
    b       #check_results

test_sau_correct_results:
    .word   24
    .word   0x0000162f, 0x0000162f, 0x0000162f, 0x0000162f
    .word   0x0000162f, 0x0000162f, 0xffffe9d3, 0x0000e9d3
    .word   0x0000ead3, 0x00000000, 0x00000000, 0x00000000
    .word   0x00000b17, 0x00000b17, 0x00000b17, 0x00000b17
    .word   0x00000b17, 0x00000b17, 0xfffff4e9, 0x0000f4e9
    .word   0x0000f5e9, 0xfffff4e9, 0x0000f4e9, 0x0000f5e9


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
    stw     s1, s25, #0
    stw     s2, s25, #4
    stw     s3, s25, #8
    stw     s4, s25, #12
    stw     s5, s25, #16
    stw     s6, s25, #20
    stw     s7, s25, #24
    stw     s8, s25, #28
    stw     s9, s25, #32
    stw     s10, s25, #36
    stw     s11, s25, #40
    stw     s12, s25, #44

    ; Check results.
    add     s1, pc, #test_mul_correct_results@pc
    mov     s2, s25
    add     s25, s25, #48
    b       #check_results

test_mul_correct_results:
    .word   12
    .word   0xffd69324, 0xffd6d11d, 0xfff1d09e, 0x35068740
    .word   0x3cb08740, 0xdcb07c40, 0xffeb4992, 0xffebe88e
    .word   0xfff8e8cf, 0x121fa00a, 0x121f3f06, 0x112c3e47


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
    stw     s1, s25, #0
    stw     s2, s25, #4
    stw     s3, s25, #8
    stw     s4, s25, #12
    stw     s5, s25, #16
    stw     s6, s25, #20
    stw     s7, s25, #24
    stw     s8, s25, #28
    stw     s9, s25, #32
    stw     s10, s25, #36
    stw     s11, s25, #40
    stw     s12, s25, #44

    ; Check results.
    add     s1, pc, #test_div_correct_results@pc
    mov     s2, s25
    add     s25, s25, #48
    b       #check_results

test_div_correct_results:
    .word   12
    .word   0xffffc394, 0xfffffff2, 0xffffef02, 0x0034df5f
    .word   0xffff0026, 0xffff2e00, 0xfffffb30, 0xfedcfe14
    .word   0xfedcfef4, 0x000002aa, 0xfedc036c, 0xfedc0298


;--------------------------------------------------------------------------------------------------
; FPU
;--------------------------------------------------------------------------------------------------

test_fpu:
    ; Floating point multiplication
    ldhi    s12,      #0x40490fdb@hi    ; 3.1415927
    or      s12, s12, #0x40490fdb@lo
    ldhi    s13,      #0x40f8a3d7@hi    ; 7.77
    or      s13, s13, #0x40f8a3d7@lo
    ldhi    s14,      #0xc0f8a3d7@hi    ; -7.77
    or      s14, s14, #0xc0f8a3d7@lo
    ldhio   s15,      #0x7fffffff       ; NaN

    ; Arithmetic operations.
    ; TODO(m): Add packed operations once we support that in the simulator too.
    fadd    s1, s12, s13
    fadd    s2, s12, s14
    fsub    s3, s12, s13
    fsub    s4, s12, s14
    fmul    s5, s12, s13
    fmul    s6, s12, s14

    ; Store results.
    stw     s1, s25, #0
    stw     s2, s25, #4
    stw     s3, s25, #8
    stw     s4, s25, #12
    stw     s5, s25, #16
    stw     s6, s25, #20

    ; Comparison operations.
    ; TODO(m): Add packed operations once we support that in the simulator too.
    fseq    s1, s12, s13
    fseq    s2, s12, s12
    fslt    s3, s12, s13
    fslt    s4, s13, s12
    fsle    s5, s13, s14
    fsle    s6, s14, s13
    fsle    s7, s13, s13
    fsnan   s8, s12, s13
    fsnan   s9, s12, s15

    ; Store results.
    stw     s1, s25, #24
    stw     s2, s25, #28
    stw     s3, s25, #32
    stw     s4, s25, #36
    stw     s5, s25, #40
    stw     s6, s25, #44
    stw     s7, s25, #48
    stw     s8, s25, #52
    stw     s9, s25, #56

    ; Min/max operations
    ; TODO(m): Add packed operations once we support that in the simulator too.
    fmin    s1, s12, s13
    fmin    s2, s12, s14
    fmax    s3, s12, s13
    fmax    s4, s12, s14

    ; Store results.
    stw     s1, s25, #60
    stw     s2, s25, #64
    stw     s3, s25, #68
    stw     s4, s25, #72

    ; Integer conversion operations.
    ; TODO(m): Add packed operations once we support that in the simulator too.
    ldi     s5, #0
    itof    s1, s19, s5
    itof    s2, s21, s5
    ldi     s5, #12
    itof    s3, s19, s5
    itof    s4, s21, s5
    itof    s5, z, s5

    ; Store results.
    stw     s1, s25, #76
    stw     s2, s25, #80
    stw     s3, s25, #84
    stw     s4, s25, #88
    stw     s5, s25, #92

    ; Check results.
    add     s1, pc, #test_fpu_correct_results@pc
    mov     s2, s25
    add     s25, s25, #96
    b       #check_results

test_fpu_correct_results:
    .word   24
    .word   0x412e95e2, 0xc0941bea, 0xc0941bea, 0x412e95e2
    .word   0x41c3480a, 0xc1c3480a
    .word   0x00000000, 0xffffffff, 0xffffffff, 0x00000000
    .word   0x00000000, 0xffffffff, 0xffffffff, 0x00000000
    .word   0xffffffff
    .word   0x40490fdb, 0xc0f8a3d7, 0x40f8a3d7, 0x40490fdb
    .word   0xcb91a2b4, 0x45b17000, 0xc591a2b4, 0x3fb17000
    .word   0x00000000


;--------------------------------------------------------------------------------------------------
; Load/Store
;--------------------------------------------------------------------------------------------------

test_load_store:
    ; Allocate stack space.
    add     sp, sp, #-8

    ; Store data of different types to memory.
    ldi     s10, #-56
    ldi     s11, #-78
    ldi     s12, #-1234
    ldhi    s13, #12345678@hi
    or      s13, s13, #12345678@lo

    ; Immediate offset.
    stb     s10, sp, #0
    stb     s11, sp, #1

    ; Register offset.
    ldi     s10, #2
    ldi     s11, #4
    sth     s12, sp, s10
    stw     s13, sp, s11

    ; Load data of different types from memory.

    ; Immediate offset.
    ldb     s1, sp, #0
    ldb     s2, sp, #1
    ldub    s3, sp, #0
    ldub    s4, sp, #1

    ; Register offset.
    ldi     s10, #2
    ldi     s11, #4
    ldh     s5, sp, s10
    lduh    s6, sp, s10
    ldw     s7, sp, s11

    ; Free stack space.
    add     sp, sp, #8

    ; Store results.
    stw     s1, s25, #0
    stw     s2, s25, #4
    stw     s3, s25, #8
    stw     s4, s25, #12
    stw     s5, s25, #16
    stw     s6, s25, #20
    stw     s7, s25, #24

    ; Check results.
    add     s1, pc, #test_load_store_correct_results@pc
    mov     s2, s25
    add     s25, s25, #28
    b       #check_results


test_load_store_correct_results:
    .word   7
    .word   0xffffffc8, 0xffffffb2, 0x000000c8, 0x000000b2
    .word   0xfffffb2e, 0x0000fb2e, 0x00bc614e


;--------------------------------------------------------------------------------------------------
; Branch
;--------------------------------------------------------------------------------------------------

test_branch:
    ; Speculative instructions are cancelled.
    ldi     s1, #0x1000
    ldw     s2, pc, #5$@pc
    ldw     s3, pc, #6$@pc
    b       #1$
    ldi     s3, #0x2000
    ldi     s3, #0x3000
    ldi     s3, #0x4000
1$:
    ldi     s4, #0x1003

    ; Operand forwarding for conditional branches.
    ldi     s5, #0
    nop
    nop
    nop
    nop
    nop
    add     s5, s5, #0x1004
    bnz     s5, #2$
    ldi     s5, #0x5000

3$:
    ; Unconditional pc-relative jump.
    ldi     s6, #0x1005
    b       #4$
    ldi     s7, #0x7000

2$:
    ; Absolute jump to z + offset (program is at a low address so should work).
    j       z, #3$
    ldi     s6, #0x6000

4$:
    ldi     s7, #0x1006

    ; Store results.
    stw     s1, s25, #0
    stw     s2, s25, #4
    stw     s3, s25, #8
    stw     s4, s25, #12
    stw     s5, s25, #16
    stw     s6, s25, #20
    stw     s7, s25, #24

    ; Check results.
    add     s1, pc, #test_branch_correct_results@pc
    mov     s2, s25
    add     s25, s25, #28
    b       #check_results

5$:
    .word   0x1001
6$:
    .word   0x1002

test_branch_correct_results:
    .word   7
    .word   0x1000, 0x1001, 0x1002, 0x1003
    .word   0x1004, 0x1005, 0x1006



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

test_operand_forwarding:
    ; Single cycle ALU operand forwarding.
    ldi     s1, #0x9999     ; Fill registers with incorrect values.
    ldi     s2, #0x9999
    ldi     s3, #0x9999
    ldi     s4, #0x9999
    ldi     s5, #0x9999
    ldi     s6, #0x9999

    nop
    nop
    nop

    add     s1, s18, s18    ; Operation.
    or      s2, s1, s1      ; Operand forwarding...
    or      s3, s1, s1
    or      s4, s1, s1
    or      s5, s1, s1
    or      s6, s1, s1

    nop
    nop
    nop

    ; Store results.
    stw     s1, s25, #0
    stw     s2, s25, #4
    stw     s3, s25, #8
    stw     s4, s25, #12
    stw     s5, s25, #16
    stw     s6, s25, #20

    ; Single cycle FPU operand forwarding.
    ldi     s1, #0x9999     ; Fill registers with incorrect values.
    ldi     s2, #0x9999
    ldi     s3, #0x9999
    ldi     s4, #0x9999
    ldi     s5, #0x9999
    ldi     s6, #0x9999

    nop
    nop
    nop

    fseq    s1, s18, s18    ; Operation.
    or      s2, s1, s1      ; Operand forwarding...
    or      s3, s1, s1
    or      s4, s1, s1
    or      s5, s1, s1
    or      s6, s1, s1

    nop
    nop
    nop

    ; Store results.
    stw     s1, s25, #24
    stw     s2, s25, #28
    stw     s3, s25, #32
    stw     s4, s25, #36
    stw     s5, s25, #40
    stw     s6, s25, #44

    ; Two-cycle SAU operand forwarding.
    ldi     s1, #0x9999     ; Fill registers with incorrect values.
    ldi     s2, #0x9999
    ldi     s3, #0x9999
    ldi     s4, #0x9999
    ldi     s5, #0x9999
    ldi     s6, #0x9999

    nop
    nop
    nop

    addh    s1, s18, s18    ; Operation.
    or      s2, s1, s1      ; Blocking + operand forwarding...
    or      s3, s1, s1
    or      s4, s1, s1
    or      s5, s1, s1
    or      s6, s1, s1

    nop
    nop
    nop

    ; Store results.
    stw     s1, s25, #48
    stw     s2, s25, #52
    stw     s3, s25, #56
    stw     s4, s25, #60
    stw     s5, s25, #64
    stw     s6, s25, #68

    ; Two-cycle FPU (ITOF) operand forwarding.
    ldi     s1, #0x9999     ; Fill registers with incorrect values.
    ldi     s2, #0x9999
    ldi     s3, #0x9999
    ldi     s4, #0x9999
    ldi     s5, #0x9999
    ldi     s6, #0x9999

    nop
    nop
    nop

    itof    s1, s18, z      ; Operation.
    or      s2, s1, s1      ; Blocking + operand forwarding...
    or      s3, s1, s1
    or      s4, s1, s1
    or      s5, s1, s1
    or      s6, s1, s1

    nop
    nop
    nop

    ; Store results.
    stw     s1, s25, #72
    stw     s2, s25, #76
    stw     s3, s25, #80
    stw     s4, s25, #84
    stw     s5, s25, #88
    stw     s6, s25, #92

    ; Three-cycle MUL operand forwarding.
    ldi     s1, #0x9999     ; Fill registers with incorrect values.
    ldi     s2, #0x9999
    ldi     s3, #0x9999
    ldi     s4, #0x9999
    ldi     s5, #0x9999
    ldi     s6, #0x9999

    nop
    nop
    nop

    mul     s1, s18, s18    ; Operation.
    or      s2, s1, s1      ; Blocking + operand forwarding...
    or      s3, s1, s1
    or      s4, s1, s1
    or      s5, s1, s1
    or      s6, s1, s1

    nop
    nop
    nop

    ; Store results.
    stw     s1, s25, #96
    stw     s2, s25, #100
    stw     s3, s25, #104
    stw     s4, s25, #108
    stw     s5, s25, #112
    stw     s6, s25, #116

    ; Three-cycle+ DIV operand forwarding.
    ldi     s1, #0x9999     ; Fill registers with incorrect values.
    ldi     s2, #0x9999
    ldi     s3, #0x9999
    ldi     s4, #0x9999
    ldi     s5, #0x9999
    ldi     s6, #0x9999

    nop
    nop
    nop

    div     s1, s18, s18    ; Operation.
    or      s2, s1, s1      ; Blocking + operand forwarding...
    or      s3, s1, s1
    or      s4, s1, s1
    or      s5, s1, s1
    or      s6, s1, s1

    nop
    nop
    nop

    ; Store results.
    stw     s1, s25, #120
    stw     s2, s25, #124
    stw     s3, s25, #128
    stw     s4, s25, #132
    stw     s5, s25, #136
    stw     s6, s25, #140

    ; Four-cycle FPU operand forwarding.
    ldi     s1, #0x9999     ; Fill registers with incorrect values.
    ldi     s2, #0x9999
    ldi     s3, #0x9999
    ldi     s4, #0x9999
    ldi     s5, #0x9999
    ldi     s6, #0x9999

    nop
    nop
    nop

    fadd    s1, s18, s18    ; Operation.
    or      s2, s1, s1      ; Blocking + operand forwarding...
    or      s3, s1, s1
    or      s4, s1, s1
    or      s5, s1, s1
    or      s6, s1, s1

    nop
    nop
    nop

    ; Store results.
    stw     s1, s25, #144
    stw     s2, s25, #148
    stw     s3, s25, #152
    stw     s4, s25, #156
    stw     s5, s25, #160
    stw     s6, s25, #164

    ; Check results.
    add     s1, pc, #test_operand_forwarding_correct_results@pc
    mov     s2, s25
    add     s25, s25, #168
    b       #check_results

    ; TODO(m): Without these nop:s, somthing goes wrong in the branching logic and the A1 simulation
    ; ends before the program is finished.
    ; See: https://github.com/mbitsnbites/mrisc32/issues/71
    nop
    nop
    nop
    nop

test_operand_forwarding_correct_results:
    .word   42
    ; ALU 1-cycle
    .word   0x2468acf0, 0x2468acf0, 0x2468acf0, 0x2468acf0, 0x2468acf0, 0x2468acf0

    ; FPU 1-cycle
    .word   0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff

    ; SAU 2-cycle
    .word   0x12345678, 0x12345678, 0x12345678, 0x12345678, 0x12345678, 0x12345678

    ; FPU 2-cycle
    .word   0x4d91a2b4, 0x4d91a2b4, 0x4d91a2b4, 0x4d91a2b4, 0x4d91a2b4, 0x4d91a2b4

    ; MUL 3-cycle
    .word   0x1df4d840, 0x1df4d840, 0x1df4d840, 0x1df4d840, 0x1df4d840, 0x1df4d840

    ; DIV 3+-cycle
    .word   0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001, 0x00000001

    ; FPU 4-cycle
    .word   0x12b45678, 0x12b45678, 0x12b45678, 0x12b45678, 0x12b45678, 0x12b45678

