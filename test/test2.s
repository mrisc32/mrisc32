;-------------------------------------------------------------------------------
; Test the performance of vector vs scalar.
;-------------------------------------------------------------------------------

main:
  ldi     r4, 1000
  lsli    r9, r4, 2
  ldi     r1, 0
  add     r2, r1, r9
  add     r3, r2, r9

  bsr     abs_diff_vectors
  ;bsr     abs_diff_vectors_scalar

  ldi     r1, 0
  bra     _exit


;-------------------------------------------------------------------------------
; void abs_diff_vectors(float* c, const float* a, const float* b, const int n) {
;   for (int i = 0; i < n; ++i) {
;     c[i] = fabs(a[i] - b[i]);
;   }
; }
;-------------------------------------------------------------------------------

abs_diff_vectors:
  ; r1 = c
  ; r2 = a
  ; r3 = b
  ; r4 = n

  addi    sp, sp, -4
  st.w    vl, sp, 0

  addi    r4, r4, -1
  ldi     vl, 31
  blt     r4, .done     ; n == 0, nothing to do

  ldi     r10, -1
  lsri    r10, r10, 1   ; r10 = 0x7fffffff

.loop:
  addi    r9, r4, -32
  mlt     vl, r9, r4    ; vl = min(32, number of elements left) - 1

  vld.w   v9, r2, 4
  vld.w   v10, r3, 4
  vvfsub  v9, v9, v10   ; a - b
  vsand   v9, v9, r10   ; Clear the sign bit
  vst.w   v9, r1, 4

  ori     r4, r9, 0
  addi    r1, r1, 128
  addi    r2, r2, 128
  addi    r3, r3, 128
  bge     r4, .loop

.done:
  ld.w    vl, sp, 0
  addi    sp, sp, 4
  jmp     lr



abs_diff_vectors_scalar:
  ; r1 = c
  ; r2 = a
  ; r3 = b
  ; r4 = n

  beq     r4, .done     ; n == 0, nothing to do

  ldi     r12, -1
  lsri    r12, r10, 1   ; r12 = 0x7fffffff

  ldi     r11, 0
.loop:
  ldx.w   r9, r2, r11
  ldx.w   r10, r3, r11
  fsub    r9, r9, r10   ; a - b
  and     r9, r9, r12   ; Clear the sign bit
  stx.w   r9, r1, r11

  addi    r4, r4, -1
  addi    r11, r11, 4
  bne     r4, .loop

.done:
  jmp     lr


  .include "sys.s"
