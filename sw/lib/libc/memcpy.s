; -*- mode: mr32asm; tab-width: 4; indent-tabs-mode: nil; -*-
; ----------------------------------------------------------------------------
; Copyright (c) 2018 Marcus Geelnard
;
; This software is provided 'as-is', without any express or implied warranty.
; In no event will the authors be held liable for any damages arising from the
; use of this software.
;
; Permission is granted to anyone to use this software for any purpose,
; including commercial applications, and to alter it and redistribute it
; freely, subject to the following restrictions:
;
;  1. The origin of this software must not be misrepresented; you must not
;     claim that you wrote the original software. If you use this software in
;     a product, an acknowledgment in the product documentation would be
;     appreciated but is not required.
;
;  2. Altered source versions must be plainly marked as such, and must not be
;     misrepresented as being the original software.
;
;  3. This notice may not be removed or altered from any source distribution.
; ----------------------------------------------------------------------------

; ----------------------------------------------------------------------------
; void* memcpy(void *dest, const void *src, size_t count)
;
; Arguments:
;   s1: void *dest
;   s2: const void *src
;   s3: size_t count
;
; Return value:
;   s1: Copy of the input argument dest (s1)
; ----------------------------------------------------------------------------

    .text
    .globl  memcpy
memcpy:
    ; Nothing to do?
    bz      s3, done

    mov     s9, s1          ; s9 = dest (we need to preserve s1)

    ; Is the length long enough to bother with optizations?
    sltu    s15, s3, #24
    bs      s15, slow

    ; Are src and dest equally aligned (w.r.t 4-byte boundaries).
    and     s14, s9, #3
    and     s15, s2, #3
    seq     s15, s14, s15
    bns     s15, slow       ; Use the slow case unless equally aligned.

    ; Do we need to do an initial alginment loop?
    bz      s14, aligned

    sub     s14, #4, s14    ; s14 = bytes left until aligned.
    mov     s15, s14
align_loop:
    add     s15, s15, #-1
    ldb     s10, s2, s15
    stb     s10, s9, s15
    bnz     s15, align_loop

    ; Adjust the memory pointers and the count.
    sub     s3, s3, s14
    add     s2, s2, s14
    add     s9, s9, s14

aligned:
    ; Vectorized loop.
    mov     s12, vl         ; Preserve vl (it's a callee-saved register).
    lsr     s15, s3, #2     ; s15 > 0 due to earlier length requirement.
    cpuid   s14, z, z       ; s14 = max vector length.
aligned_loop:
    min     vl, s14, s15
    sub     s15, s15, vl
    ldw     v15, s2, #4
    lsl     s13, vl, #2     ; Possibly do this before the loop.
    stw     v15, s9, #4
    add     s2, s2, s13
    add     s9, s9, s13
    bnz     s15, aligned_loop

    ; Post vector-operation: Clear v15 (reg. length optimization), and check
    ; how many bytes are remaining.
    ldi     vl, #0
    and     s3, s3, #3      ; s3 = bytes left after the algined loop.
    or      v15, vz, #0
    mov     vl, s12         ; Restore vl.
    bz      s3, done

slow:
    ; Naive byte-copy loop.
    ; TODO(m): Vectorize the slow case.
slow_loop:
    add     s3, s3, #-1
    ldb     s10, s2, s3
    stb     s10, s9, s3
    bnz     s3, slow_loop

done:
    ; At this point s1 should contain it's original value (dest).
    j       lr

