// This is a test program.

main:
  ldi    r10, 0         ; r10 is the return code (0 = success, 1 = fail)

  bsr    test_1
  or     r10, r10, r4
  beq    r4, test1_passed
  bsr    test_failed
test1_passed:

  bsr    test_2
  or     r10, r10, r4
  beq    r4, test2_passed
  bsr    test_failed
test2_passed:

  bsr    test_3
  or     r10, r10, r4
  beq    r4, test3_passed
  bsr    test_failed
test3_passed:

  ; exit(r10)
  mov    r4, r10
  bra    _exit


test_failed:
  lea    r4, test_failed_msg
  bra    _puts


test_failed_msg:
  .u8    0x2a, 0x2a, 0x2a, 0x20, 0x46, 0x41, 0x49, 0x4c, 0x21, 0
  .align 4


; ----------------------------------------------------------------------------
; A loop with a decrementing conunter.

test_1:
  ldi    r4, 0x20
  ldi    r5, 12

loop:
  add    r4, r4, r5
  addi   r5, r5, -1
  bne    r5, loop
  
  ldi    r4, 0
  rts


; ----------------------------------------------------------------------------

test_2:
  addi   sp, sp, -8
  st.w   r4, sp, 0
  st.w   r5, sp, 4
  ldpc.w r4, data
  add    r4, r4, r5
  addi   r5, pc, 15
  ld.w   r4, sp, 0
  ld.w   r5, sp, 4
  addi   sp, sp, 8

  ldi    r4, 0
  rts

  .align 4
data:
  .i32   9, 6, 5
  .u32   134987124
  .u8    0xFF,  2
  .i16   1240
  .align 4


; ----------------------------------------------------------------------------

test_3:
  st.w   lr, sp, -4
  subi   sp, sp, 4

  lea    r4, hello_world
  bsr    _puts

  ld.w   lr, sp, 0
  addi   sp, sp, 4
  ldi    r4, 0
  rts


hello_world:
  .u8    0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x20, 0x77, 0x6f, 0x72, 0x6c, 0x64, 0x21, 0
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

