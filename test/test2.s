;-------------------------------------------------------------------------------
; Test the performance of vector vs scalar.
;-------------------------------------------------------------------------------

main:
  ldi     s4, 1000
  lsli    s9, s4, 2
  ldi     s1, 0
  add     s2, s1, s9
  add     s3, s2, s9

  bl      abs_diff_vectors
  ;bl      abs_diff_vectors_scalar

  ldi     s1, 0
  b       _exit


;-------------------------------------------------------------------------------
; void abs_diff_vectors(float* c, const float* a, const float* b, const int n) {
;   for (int i = 0; i < n; ++i) {
;     c[i] = fabs(a[i] - b[i]);
;   }
; }
;-------------------------------------------------------------------------------

abs_diff_vectors:
  ; s1 = c
  ; s2 = a
  ; s3 = b
  ; s4 = n

  addi    sp, sp, -4
  stw     vl, sp, 0

  addi    s4, s4, -1
  ldi     vl, 31
  blt     s4, .done     ; n == 0, nothing to do

  ldi     s10, -1
  lsri    s10, s10, 1   ; s10 = 0x7fffffff

.loop:
  addi    s9, s4, -32
  mlt     vl, s9, s4    ; vl = min(32, number of elements left) - 1

  vldw    v9, s2, 4
  vldw    v10, s3, 4
  vvfsub  v9, v10, v9   ; a - b
  vsand   v9, v9, s10   ; Clear the sign bit
  vstw    v9, s1, 4

  ori     s4, s9, 0
  addi    s1, s1, 128
  addi    s2, s2, 128
  addi    s3, s3, 128
  bge     s4, .loop

.done:
  ldw     vl, sp, 0
  addi    sp, sp, 4
  jmp     lr



abs_diff_vectors_scalar:
  ; s1 = c
  ; s2 = a
  ; s3 = b
  ; s4 = n

  beq     s4, .done     ; n == 0, nothing to do

  ldi     s12, -1
  lsri    s12, s10, 1   ; s12 = 0x7fffffff

  ldi     s11, 0
.loop:
  ldxw    s9, s2, s11
  ldxw    s10, s3, s11
  fsub    s9, s10, s9   ; a - b
  and     s9, s9, s12   ; Clear the sign bit
  stxw    s9, s1, s11

  addi    s4, s4, -1
  addi    s11, s11, 4
  bne     s4, .loop

.done:
  jmp     lr


  .include "sys.s"

