; =============================================================================
; == System library
; =============================================================================

; -----------------------------------------------------------------------------
; exit(int exit_code)
; -----------------------------------------------------------------------------
_exit:
  ; exit routine: 0xffff0000
  ldhi   s9, 0x7FFF8  ; Upper 19 bits = 0b1111111111111111000
  or     s9, s9, 0    ; Lower 13 bits = 0b                   0000000000000
  jmp    s9


; -----------------------------------------------------------------------------
; putc(int c)
; -----------------------------------------------------------------------------
_putc:
  ; putc routine: 0xffff0004
  ldhi   s9, 0x7FFF8  ; Upper 19 bits = 0b1111111111111111000
  or     s9, s9, 4    ; Lower 13 bits = 0b                   0000000000100
  jmp    s9


; -----------------------------------------------------------------------------
; puts(char* s)
; -----------------------------------------------------------------------------
_puts:
  add    sp, sp, -12
  stw    lr, sp, 0
  stw    s16, sp, 4
  stw    s17, sp, 8

  mov    s16, s1
  ldi    s17, 0
.loop:
  ldb    s1, s16, s17
  and    s1, s1, 255
  add    s17, s17, 1
  beq    s1, .eos
  bl     _putc
  b      .loop

.eos:
  ldi    s1, 10
  bl     _putc

  ldw    lr, sp, 0
  ldw    s16, sp, 4
  ldw    s17, sp, 8
  add    sp, sp, 12
  ldi    s1, 1        ; Return a non-negative number
  rts


; -----------------------------------------------------------------------------
; printhex(unsigned x)
; -----------------------------------------------------------------------------
_printhex:
  add    sp, sp, -16
  stw    lr, sp, 0
  stw    s16, sp, 4
  stw    s17, sp, 8
  stw    s18, sp, 12

  lea    s16, .hex_chars
  mov    s17, s1
  ldi    s18, 7
.loop:
  add    s9, s18, s18
  add    s9, s9, s9   ; s9 = s18 * 4
  lsr    s9, s17, s9  ; s9 = x >> (s18 * 4)
  and    s9, s9, 15   ; s9 = (x >> (s18 * 4)) & 15
  ldb    s1, s16, s9  ; s1 = hex_chars[(x >> (s18 * 4)) & 15]
  add    s18, s18, -1
  bl     _putc
  bge    s18, .loop

  ldw    lr, sp, 0
  ldw    s16, sp, 4
  ldw    s17, sp, 8
  ldw    s18, sp, 12
  add    sp, sp, 16
  rts

.hex_chars:
  .ascii "0123456789abcdef"

