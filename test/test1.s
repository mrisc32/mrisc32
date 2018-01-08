// This is a test program.

main:
  ldi    r20, 0         ; r20 is the return code (0 = success, 1 = fail)

  bsr    test_1
  or     r20, r20, r4
  beq    r4, .test1_passed
  bsr    .test_failed
.test1_passed:

  bsr    test_2
  or     r20, r20, r4
  beq    r4, .test2_passed
  bsr    .test_failed
.test2_passed:

  bsr    test_3
  or     r20, r10, r4
  beq    r4, .test3_passed
  bsr    .test_failed
.test3_passed:

  bsr    test_4
  or     r20, r10, r4
  beq    r4, .test4_passed
  bsr    .test_failed
.test4_passed:

  ; exit(r20)
  mov    r4, r20
  bra    _exit


.test_failed:
  lea    r4, .fail_msg
  bra    _puts


.fail_msg:
  .asciz "*** Failed!"
  .align 4


; ----------------------------------------------------------------------------
; A loop with a decrementing conunter.

test_1:
  ldi    r12, 0x20
  ldi    r13, 12

.loop:
  add    r12, r12, r13
  subi   r13, r13, 1
  bne    r13, .loop
  
  ldi    r4, 0
  rts


; ----------------------------------------------------------------------------
; Sum elements in a data array.

test_2:
  subi   sp, sp, 12
  st.w   lr, sp, 0
  st.w   r20, sp, 4
  st.w   r21, sp, 8

  lea    r20, .data
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

.data:
  .u32   0x40, 1, 0xbeef0001
  .align 4


; ----------------------------------------------------------------------------
; Call a subroutine that prints hello world.

test_3:
  subi   sp, sp, 4
  st.w   lr, sp, 0

  lea    r4, .hello_world
  bsr    _puts

  ld.w   lr, sp, 0
  addi   sp, sp, 4
  ldi    r4, 0
  rts


.hello_world:
  .asciz "Hello world!"
  .align 4


; ----------------------------------------------------------------------------
; 64-bit arithmetic.

test_4:
  subi   sp, sp, 8
  st.w   lr, sp, 0
  st.w   r20, sp, 4

  ; Load two 64-bit numbers into r14:r13 and r16:r15
  lea    r12, .dword1
  ld.w   r13, r12, 0  ; r13 = low bits
  ld.w   r14, r12, 4  ; r14 = high bits
  lea    r12, .dword2
  ld.w   r15, r12, 0  ; r15 = low bits
  ld.w   r16, r12, 4  ; r16 = high bits

  ; Add the numbers into r4:r20
  add    r20, r13, r15  ; r20 = low bits
  addc   r4, r14, r16   ; r4 = high bits

  bsr    _printhex      ; Print high word
  mov    r4, r20
  bsr    _printhex      ; Print low word
  ldi    r4, 10
  bsr    _putc

  ld.w   lr, sp, 0
  ld.w   r20, sp, 4
  addi   sp, sp, 8

  ldi    r4, 0
  rts

.dword1:
  .u32   0x89abcdef, 0x01234567
.dword2:
  .u32   0xaaaaaaaa, 0x00010000


; ----------------------------------------------------------------------------

float:
  fldpc  f0, .pi
  fldpc  f1, .two
  fmul   f0, f0, f1

  ldi    r4, 0
  rts


.one:
  .u32   0x3f800000
.two:
  .u32   0x40000000
.pi:
  .u32   0x40490fdb


; ----------------------------------------------------------------------------

  .include "sys.s"

