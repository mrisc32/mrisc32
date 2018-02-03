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

  beq     s4, .done     ; n == 0, nothing to do

  ldhio   s10, 0x7fffffff

  ; Prepare the vector operation
  cpuid   s11, z       ; s11 is the nax number of vector elements
  lsl     s12, s11, 2  ; s12 is the memory increment per vector operation

.loop:
  cmplt   vl, s4, s11
  sel     vl, s4, s11  ; VL = min(s4, s11)

  sub     s4, s11, s4  ; Decrement the loop counter

  ldw     v9, s2, 4    ; v9  = a
  ldw     v10, s3, 4   ; v10 = b
  fsub    v9, v10, v9  ; v9  = a - b
  and     v9, v9, s10  ; v9  = abs(a - b) (i.e. clear the sign bit)
  stw     v9, s1, 4    ; c   = abs(a - b)

  add     s1, s1, s12  ; Increment the memory pointers
  add     s2, s2, s12
  add     s3, s3, s12
  bgt     s4, .loop

.done:
  ldw     vl, sp, 0
  add     sp, sp, 4
  j       lr



abs_diff_vectors_scalar:
  ; s1 = c
  ; s2 = a
  ; s3 = b
  ; s4 = n

  beq     s4, .done    ; n == 0, nothing to do

  ldhio   s12, 0x7fffffff

  ldi     s11, 0
.loop:
  add     s4, s4, -1   ; Decrement the loop counter

  ldw     s9, s2, s11  ; s9  = a
  ldw     s10, s3, s11 ; s10 = b
  fsub    s9, s10, s9  ; s9  = a - b
  and     s9, s9, s12  ; s9  = abs(a - b) (i.e. clear the sign bit)
  stw     s9, s1, s11  ; c   = abs(a - b)

  add     s11, s11, 4  ; Increment the array offset
  bne     s4, .loop

.done:
  j       lr


  .include "sys.s"

