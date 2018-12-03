# Common constructs

| Problem | Solution |
|---|---|
| No operation (NOP) | CPUID Z,Z,Z |
| Load full 32-bit immediate | LDI rd,upper\_21\_bits<br>OR rd,rd,$lower\_11\_bits |
| Move register | OR rd,ra,Z |
| Negate value | SUB rd,Z,ra |
| Integer absolute value | SUB rd,Z,ra<br>MAX rd,ra,rd |
| Subtract immediate from register | ADD rd,ra,$-i15 |
| Zero-extend byte to word | SHUF rd,ra,$0x0920 |
| Zero-extend halfword to word | SHUF rd,ra,$0x0b48 |
| Sign-extend byte to word | SHUF rd,ra,$0x1920 |
| Sign-extend halfword to word | SHUF rd,ra,$0x1b48 |
| Swap high and low halfwords | SHUF rd,ra,$0x021a |
| Invert all bits | NOR rd,ra,ra |
| Compare and branch | S[cond] tmp,ra,rb<br>BS tmp,$branch\_target<br>*(or alternatively)*<br>SUB tmp,ra,rb<br>B[cond] tmp,$branch\_target |
| Return from subroutine | J LR |
| Push to stack | ADD SP,SP,$-N<br>STW ra1,SP,$0<br>STW ra2,SP,$4<br>... |
| Pop from stack | LDW rd1,SP,$0<br>LDW rd2,SP,$4<br>...<br>ADD SP,SP,$N |
| 64-bit integer addition: c2:c1 = a2:a1 + b2:b1 | ADD c1,a1,b1<br>ADD c2,a2,b2<br>SLTU carry,c1,a1<br>SUB c2,c2,carry |
| Floating point negation | LDI tmp,$0x80000000<br>XOR rd,ra,tmp<br>*(or alternatively)*<br>FSUB rd,Z,ra |
| Floating point absolute value | LDI tmp,$0x7fffffff<br>AND rd,ra,tmp |
| Floating point compare and branch | FS[cond] tmp,ra,rb<br>BS tmp,$branch\_target |
| Load simple floating point immediate (21 most significant bits) | LDI |
| Bitwise select (1): rd <= (ra & rc) \| (rb & ~rc) | XOR rd,ra,rb<br>AND rd,rd,rc<br>XOR rd,rd,rb |
| Conditional addition | S[cond] re,ra,rb<br>AND re,rc,re<br>ADD re,rd,re |

1: Bitwise select can be used for conditional assignments of integer and floating point scalars, vectors and packed data types, and can be used in conjunction with regular S[cc] compare instructions (to generate a selection bit mask).
