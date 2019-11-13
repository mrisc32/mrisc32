; -*- mode: mr32asm; tab-width: 4; indent-tabs-mode: nil; -*-
; ----------------------------------------------------------------------------
; Copyright (c) 2018-2019 Marcus Geelnard
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
;
; Clobbered scratch registers:
;   s2, s3, s4, s5, s6, s7, v1
; ----------------------------------------------------------------------------

    .text
    .globl  memcpy
memcpy:
    ; Nothing to do?
    bz      s3, exit

    mov     s5, vl          ; Preserve vl (it's a callee-saved register).
    mov     s4, s1          ; s4 = dest (we need to preserve s1)

    ; Is the length long enough to bother with optizations?
    sltu    s7, s3, #24
    bs      s7, slow

    ; Are src and dest equally aligned (w.r.t 4-byte boundaries).
    and     s6, s4, #3
    and     s7, s2, #3
    seq     s7, s6, s7
    bns     s7, slow        ; Use the slow case unless equally aligned.

    ; Do we need to align before the main loop?
    bz      s6, aligned

    ; Align: Do a 1-3 bytes copy via a vector register, and adjust the memory
    ; pointers and the count.
    sub     vl, #4, s6      ; vl = bytes left until aligned.
    sub     s3, s3, vl
    ldb     v1, s2, #1
    add     s2, s2, vl
    stb     v1, s4, #1
    add     s4, s4, vl

aligned:
    ; Vectorized word-copying loop.
    lsr     s7, s3, #2      ; s7 > 0 due to earlier length requirement.
    cpuid   s6, z, z        ; s6 = max vector length.
aligned_loop:
    min     vl, s6, s7
    sub     s7, s7, vl
    ldw     v1, s2, #4
    ldea    s2, s2, vl*4
    stw     v1, s4, #4
    ldea    s4, s4, vl*4
    bnz     s7, aligned_loop

    ; Check how many bytes are remaining.
    and     vl, s3, #3      ; vl = bytes left after the aligned loop.
    bz      vl, done

    ; Tail: Do a 1-3 bytes copy via a vector register.
    ldb     v1, s2, #1
    stb     v1, s4, #1

done:
    ; Post vector-operation: Clear v1 (reg. length optimization).
    ldi     vl, #0
    or      v1, vz, #0

    mov     vl, s5          ; Restore vl.

exit:
    ; At this point s1 should contain it's original value (dest).
    j       lr


; ----------------------------------------------------------------------------
; Slow case
; ----------------------------------------------------------------------------

slow:
    ; Simple vectorized byte-copy loop (this is typically 4x slower than a
    ; word-copy loop).
    cpuid   s6, z, z        ; s6 = max vector length.
slow_loop:
    min     vl, s6, s3
    sub     s3, s3, vl
    ldb     v1, s2, #1
    add     s2, s2, vl
    stb     v1, s4, #1
    add     s4, s4, vl
    bnz     s3, slow_loop

    b       done

