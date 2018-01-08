// This is a test program.

main:
  ldi    r20, 0         ; r20 is the return code (0 = success, 1 = fail)

  bsr    test_1
  or     r20, r20, r4
  beq    r4, test1_passed
  bsr    test_failed
test1_passed:

  bsr    test_2
  or     r20, r20, r4
  beq    r4, test2_passed
  bsr    test_failed
test2_passed:

  bsr    test_3
  or     r20, r10, r4
  beq    r4, test3_passed
  bsr    test_failed
test3_passed:

  ; exit(r20)
  mov    r4, r20
  bra    _exit


test_failed:
  lea    r4, test_failed_msg
  bra    _puts


test_failed_msg:
  .text  "*** Failed!\0"
  .align 4


; ----------------------------------------------------------------------------
; A loop with a decrementing conunter.

test_1:
  ldi    r12, 0x20
  ldi    r13, 12

loop:
  add    r12, r12, r13
  subi   r13, r13, 1
  bne    r13, loop
  
  ldi    r4, 0
  rts


; ----------------------------------------------------------------------------

test_2:
  subi   sp, sp, 12
  st.w   lr, sp, 0
  st.w   r20, sp, 4
  st.w   r21, sp, 8

  lea    r20, __test_2_data
  ld.w   r4, r20, 0     ; r4 = data[0]
  ld.w   r21, r20, 4
  add    r4, r4, r21    ; r4 += data[1]
  ld.w   r21, r20, 8
  add    r4, r4, r21    ; r4 += data[2]
  mov    r20, r4        ; Save the result for the comparison later
  bsr    _printhex
  ldi    r4, 10
  bsr    _putc

  ldi    r4, 1
  ldi    r12, 0
  ldhi   r13, 0x5f778
  ori    r13, r13, 0x42 ; r13 = 0xbeef0042
  sub    r13, r20, r13
  meq    r4, r13, r12   ; return (r20 == 0xbeef0042) ? 0 : 1

  ld.w   lr, sp, 0
  ld.w   r20, sp, 4
  ld.w   r21, sp, 8
  addi   sp, sp, 12

  rts

__test_2_data:
  .u32   0x40, 1, 0xbeef0001
  .align 4


; ----------------------------------------------------------------------------

test_3:
  subi   sp, sp, 4
  st.w   lr, sp, 0

  lea    r4, hello_world
  bsr    _puts

  ld.w   lr, sp, 0
  addi   sp, sp, 4
  ldi    r4, 0
  rts


hello_world:
  .text  "Hello world!\0"
  .align 4


; ----------------------------------------------------------------------------

float:
  fldpc  f0, flt_pi
  fldpc  f1, flt_two
  fmul   f0, f0, f1

  ldi    r4, 0
  rts


  .align 4
flt_one:
  .u32   0x3f800000
flt_two:
  .u32   0x40000000
flt_pi:
  .u32   0x40490fdb


; ----------------------------------------------------------------------------

  .include "sys.s"

