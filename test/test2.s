;-------------------------------------------------------------------------------
; Test the performance of vector vs scalar.
;-------------------------------------------------------------------------------

main:
  ldi     s4, 1000
  lsl     s9, s4, 2
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

  add     sp, sp, -4
  stw     vl, sp, 0

  add     s4, s4, -1
  ldi     vl, 31
  blt     s4, .done     ; n == 0, nothing to do

  ldhio   s10, 0x7fffffff

.loop:
  add     s9, s4, -32
  mlt     vl, s9, s4    ; vl = min(32, number of elements left) - 1

  ldw     v9, s2, 4
  ldw     v10, s3, 4
  fsub    v9, v10, v9   ; a - b
  and     v9, v9, s10   ; Clear the sign bit
  stw     v9, s1, 4

  or      s4, s9, 0
  add     s1, s1, 128
  add     s2, s2, 128
  add     s3, s3, 128
  bge     s4, .loop

.done:
  ldw     vl, sp, 0
  add     sp, sp, 4
  j       lr



abs_diff_vectors_scalar:
  ; s1 = c
  ; s2 = a
  ; s3 = b
  ; s4 = n

  beq     s4, .done     ; n == 0, nothing to do

  ldhio   s12, 0x7fffffff

  ldi     s11, 0
.loop:
  ldw     s9, s2, s11
  ldw     s10, s3, s11
  fsub    s9, s10, s9   ; a - b
  and     s9, s9, s12   ; Clear the sign bit
  stw     s9, s1, s11

  add     s4, s4, -1
  add     s11, s11, 4
  bne     s4, .loop

.done:
  j       lr


  .include "sys.s"

