; =============================================================================
; == System library
; =============================================================================

; -----------------------------------------------------------------------------
; exit(int exit_code)
; -----------------------------------------------------------------------------
_exit:
  ; exit routine: 0xffff0000
  ldhi   r9, 0x7FFF8  ; Upper 19 bits = 0b1111111111111111000
  ori    r9, r9, 0    ; Lower 13 bits = 0b                   0000000000000
  jmp    r9


; -----------------------------------------------------------------------------
; putc(int c)
; -----------------------------------------------------------------------------
_putc:
  ; putc routine: 0xffff0004
  ldhi   r9, 0x7FFF8  ; Upper 19 bits = 0b1111111111111111000
  ori    r9, r9, 4    ; Lower 13 bits = 0b                   0000000000100
  jmp    r9


; -----------------------------------------------------------------------------
; puts(char* s)
; -----------------------------------------------------------------------------
_puts:
  addi   sp, sp, -12
  stw    lr, sp, 0
  stw    r16, sp, 4
  stw    r17, sp, 8

  mov    r16, r1
  ldi    r17, 0
.loop:
  ldxb   r1, r16, r17
  andi   r1, r1, 255
  addi   r17, r17, 1
  beq    r1, .eos
  bl     _putc
  b      .loop

.eos:
  ldi    r1, 10
  bl     _putc

  ldw    lr, sp, 0
  ldw    r16, sp, 4
  ldw    r17, sp, 8
  addi   sp, sp, 12
  ldi    r1, 1        ; Return a non-negative number
  rts


; -----------------------------------------------------------------------------
; printhex(unsigned x)
; -----------------------------------------------------------------------------
_printhex:
  addi   sp, sp, -16
  stw    lr, sp, 0
  stw    r16, sp, 4
  stw    r17, sp, 8
  stw    r18, sp, 12

  lea    r16, .hex_chars
  mov    r17, r1
  ldi    r18, 7
.loop:
  add    r9, r18, r18
  add    r9, r9, r9   ; r9 = r18 * 4
  lsr    r9, r17, r9  ; r9 = x >> (r18 * 4)
  andi   r9, r9, 15   ; r9 = (x >> (r18 * 4)) & 15
  ldxb   r1, r16, r9  ; r1 = hex_chars[(x >> (r18 * 4)) & 15]
  addi   r18, r18, -1
  bl     _putc
  bge    r18, .loop

  ldw    lr, sp, 0
  ldw    r16, sp, 4
  ldw    r17, sp, 8
  ldw    r18, sp, 12
  addi   sp, sp, 16
  rts

.hex_chars:
  .ascii "0123456789abcdef"

