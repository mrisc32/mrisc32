; =============================================================================
; == System library
; =============================================================================

; -----------------------------------------------------------------------------
; exit(int exit_code)
; -----------------------------------------------------------------------------
_exit:
  ; exit routine: 0xffff0000
  ldhi   r12, 0x7FFF8  ; Upper 19 bits = 0b1111111111111111000
  ori    r12, r12, 0   ; Lower 13 bits = 0b                   0000000000000
  jmp    r12


; -----------------------------------------------------------------------------
; putc(int c)
; -----------------------------------------------------------------------------
_putc:
  ; putc routine: 0xffff0004
  ldhi   r12, 0x7FFF8  ; Upper 19 bits = 0b1111111111111111000
  ori    r12, r12, 4   ; Lower 13 bits = 0b                   0000000000100
  jmp    r12


; -----------------------------------------------------------------------------
; puts(char* s)
; -----------------------------------------------------------------------------
_puts:
  subi   sp, sp, 12
  st.w   lr, sp, 0
  st.w   r20, sp, 4
  st.w   r21, sp, 8

  mov    r20, r4
  ldi    r21, 0
__puts_loop:
  ldx.b  r4, r20, r21
  andi   r4, r4, 255
  addi   r21, r21, 1
  beq    r4, __puts_eos
  bsr    _putc
  bra    __puts_loop

__puts_eos:
  ldi    r4, 10
  bsr    _putc

  ld.w   lr, sp, 0
  ld.w   r20, sp, 4
  ld.w   r21, sp, 8
  addi   sp, sp, 12
  ldi    r4, 1        ; Return a non-negative number
  rts

