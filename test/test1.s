// This is a test program.

main:
  ldi    r16, 0         ; r16 is the return code (0 = success, 1 = fail)

  bsr    test_1
  or     r16, r16, r1
  beq    r1, .test1_passed
  bsr    .test_failed
.test1_passed:

  bsr    test_2
  or     r16, r16, r1
  beq    r1, .test2_passed
  bsr    .test_failed
.test2_passed:

  bsr    test_3
  or     r16, r16, r1
  beq    r1, .test3_passed
  bsr    .test_failed
.test3_passed:

  bsr    test_4
  or     r16, r16, r1
  beq    r1, .test4_passed
  bsr    .test_failed
.test4_passed:

  bsr    test_5
  or     r16, r16, r1
  beq    r1, .test5_passed
  bsr    .test_failed
.test5_passed:

  bsr    test_6
  or     r16, r16, r1
  beq    r1, .test6_passed
  bsr    .test_failed
.test6_passed:

  ; exit(r16)
  mov    r1, r16
  bra    _exit


.test_failed:
  lea    r1, .fail_msg
  bra    _puts


.fail_msg:
  .asciz "*** Failed!"
  .align 4


; ----------------------------------------------------------------------------
; A loop with a decrementing conunter.

test_1:
  ldi    r9, 0x20
  ldi    r10, 12

.loop:
  add    r9, r9, r10
  subi   r10, r10, 1
  bne    r10, .loop

  ldi    r1, 0
  rts


; ----------------------------------------------------------------------------
; Sum elements in a data array.

test_2:
  subi   sp, sp, 12
  st.w   lr, sp, 0
  st.w   r16, sp, 4
  st.w   r17, sp, 8

  lea    r16, .data
  ld.w   r1, r16, 0     ; r1 = data[0]
  ld.w   r17, r16, 4
  add    r1, r1, r17    ; r1 += data[1]
  ld.w   r17, r16, 8
  add    r1, r1, r17    ; r1 += data[2]
  mov    r16, r1        ; Save the result for the comparison later
  bsr    _printhex
  ldi    r1, 10
  bsr    _putc

  ldi    r1, 1
  ldi    r9, 0
  ldhi   r10, 0x5f778
  ori    r10, r10, 0x42 ; r10 = 0xbeef0042
  sub    r10, r16, r10
  meq    r1, r10, r9   ; return (r16 == 0xbeef0042) ? 0 : 1

  ld.w   lr, sp, 0
  ld.w   r16, sp, 4
  ld.w   r17, sp, 8
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

  lea    r1, .hello_world
  bsr    _puts

  ld.w   lr, sp, 0
  addi   sp, sp, 4
  ldi    r1, 0
  rts


.hello_world:
  .asciz "Hello world!"
  .align 4


; ----------------------------------------------------------------------------
; 64-bit arithmetic.

test_4:
  subi   sp, sp, 8
  st.w   lr, sp, 0
  st.w   r16, sp, 4

  ; Load two 64-bit numbers into r11:r10 and r13:r12
  lea    r9, .dword1
  ld.w   r10, r9, 0  ; r10 = low bits
  ld.w   r11, r9, 4  ; r11 = high bits
  lea    r9, .dword2
  ld.w   r12, r9, 0  ; r12 = low bits
  ld.w   r13, r9, 4  ; r13 = high bits

  ; Add the numbers into r1:r16
  add    r16, r10, r12  ; r16 = low bits
  addc   r1, r11, r13   ; r1 = high bits

  bsr    _printhex      ; Print high word
  mov    r1, r16
  bsr    _printhex      ; Print low word
  ldi    r1, 10
  bsr    _putc

  ld.w   lr, sp, 0
  ld.w   r16, sp, 4
  addi   sp, sp, 8

  ldi    r1, 0
  rts

.dword1:
  .u32   0x89abcdef, 0x01234567
.dword2:
  .u32   0xaaaaaaaa, 0x00010000


; ----------------------------------------------------------------------------
; Floating point arithmetic.

test_5:
  subi   sp, sp, 8
  st.w   lr, sp, 0
  st.w   r16, sp, 4

  ; Calculate 2 * PI
  ldpc.w r9, .pi
  ldpc.w r10, .two
  fmul   r16, r9, r10  ; r16 = 2 * PI

  mov    r1, r16
  bsr    _printhex
  ldi    r1, 10
  bsr    _putc

  ; Was the result 2 * PI?
  ldpc.w r9, .twopi
  fsub   r9, r16, r9  ; r9 = (2 * PI) - .twopi

  ld.w   lr, sp, 0
  ld.w   r16, sp, 4
  addi   sp, sp, 8

  ldi    r1, 1
  ldi    r10, 0
  meq    r1, r9, r10   ; r1 = (result == 2*PI) ? 0 : 1
  rts


.one:
  .u32   0x3f800000
.two:
  .u32   0x40000000
.pi:
  .u32   0x40490fdb
.twopi:
  .u32   0x40c90fdb


; ----------------------------------------------------------------------------
; Vector operations.

test_6:
  subi   sp, sp, 20
  st.w   lr, sp, 0
  st.w   vl, sp, 4
  st.w   r16, sp, 8
  st.w   r17, sp, 12
  st.w   r18, sp, 16

  ; Prepare scalars
  lea    r9, .in
  lea    r16, .result

  ; The vector length is 32
  ldi    vl, 31  ; vl = len - 1 = 31

  ; Load v9 from memory
  vld.w  v9, r9, 4

  ; Initialize v10 to a constant value
  vsldi  v10, 0x1234

  ; Add vectors v9 and v10
  vvadd  v9, v9, v10

  ; Subtract a scalar from v9
  vssubi v9, v9, 8

  ; Store the result to memory
  vst.w  v9, r16, 4

  ; Print the result
  ldi    r17, 0
.print:
  lsli   r9, r17, 2
  ldx.w  r1, r16, r9
  bsr    _printhex
  ldi    r1, 0x2c
  ldi    r9, 10
  addi   r18, r17, -31
  addi   r17, r17, 1
  meq    r1, r18, r9    ; Print comma or newline depending on if this is the last element
  bsr    _putc
  bne    r18, .print

  ld.w   lr, sp, 0
  ld.w   vl, sp, 4
  ld.w   r16, sp, 8
  ld.w   r17, sp, 12
  ld.w   r18, sp, 16
  addi   sp, sp, 20

  ldi    r1, 0
  rts

.in:
  .i32   1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16
  .i32   17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32

.result:
  .space 128

; ----------------------------------------------------------------------------

  .include "sys.s"

