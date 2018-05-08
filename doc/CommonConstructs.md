# Common constructs

| Problem | Solution |
|---|---|
| No operation (NOP) | CPUID Z,Z |
| Load full 32-bit immediate | LDHI rd,upper\_19\_bits<br>OR rd,rd,lower\_13\_bits |
| Move register | OR rd,ra,Z |
| Negate value | SUB rd,Z,ra |
| Subtract immediate from register | ADD rd,ra,-i14 |
| Zero-extend byte to word | AND rd,ra,0xff |
| Zero-extend halfword to word | SHUF rd,ra,0x908 |
| Swap high and low halfwords | SHUF rd,ra,0x21a |
| Invert all bits | NOR rd,ra,ra |
| Compare and branch | SUB tmp,ra,rb<br>B[cond] tmp,branch\_target |
| Unconditional branch | BEQ Z,branch\_target |
| Unconditional subroutine branch | BLEQ Z,branch\_target |
| Return from subroutine | J LR |
| Push to stack | ADD SP,SP,-N<br>STW ra1,SP,0<br>STW ra2,SP,4<br>... |
| Pop from stack | LDW rd1,SP,0<br>LDW rd2,SP,4<br>...<br>ADD SP,SP,N |
| 64-bit integer addition: c2:c1 = a2:a1 + b2:b1 | ADD c1,a1,b1<br>ADD c2,a2,b2<br>SLTU carry,c1,a1<br>ADD c2,c2,carry |
| Floating point negation | LDHI tmp,0x80000000<br>XOR rd,ra,tmp<br>*(or alternatively)*<br>fsub rd,Z,ra |
| Floating point absolute value | LDHIO tmp,0x7fffffff<br>AND rd,ra,tmp |
| Floating point compare and branch | FSUB tmp,ra,rb<br>B[cond] tmp,branch\_target |
| Load simple floating point immediate (19 most significant bits) | LDHI/LDHIO |

