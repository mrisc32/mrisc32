# Common constructs

| Problem | Solution |
|---|---|
| No operation (NOP) | or z, z, z |
| Load full 32-bit immediate | ldhi rd,#upper\_20\_bits<br>or rd,rd,#lower\_12\_bits |
| Move register | or rd,z,ra |
| Negate value | sub rd,z,ra |
| Integer absolute value | sub rd,z,ra<br>max rd,ra,rd |
| Subtract immediate from register | add rd,ra,#-immediate |
| Zero-extend byte to word | shuf rd,ra,#0x0920 |
| Zero-extend halfword to word | shuf rd,ra,#0x0b48 |
| Sign-extend byte to word | shuf rd,ra,#0x1920 |
| Sign-extend halfword to word | shuf rd,ra,#0x1b48 |
| Swap high and low halfwords | shuf rd,ra,#0x021a |
| Invert all bits (NOT) | xor rd,ra,#-1 |
| Compare and branch | s[cond] tmp,ra,rb<br>bs tmp,#branch\_target<br>*(or alternatively)*<br>sub tmp,ra,rb<br>b[cond] tmp,#branch\_target |
| Return from subroutine | j lr,#0 |
| Push to stack | add sp,sp,#-N<br>stw ra1,[sp,#0]<br>stw ra2,[sp,#4]<br>... |
| Pop from stack | ldw rd1,[sp,#0]<br>ldw rd2,[sp,#4]<br>...<br>add sp,sp,#N |
| 64-bit integer addition: c2:c1 = a2:a1 + b2:b1 | add c1,a1,b1<br>add c2,a2,b2<br>sltu carry,c1,a1<br>sub c2,c2,carry |
| Floating point negation | xor rd,ra,#0x80000000<br>*(or alternatively)*<br>fsub rd,z,ra |
| Floating point absolute value | and rd,ra,#0x7fffffff |
| Floating point compare and branch | fs[cond] tmp,ra,rb<br>bs tmp,#branch\_target |
| Load simple floating point immediate (20 most significant bits) | ldhi |
| Conditional addition | s[cond] re,ra,rb<br>and re,rc,re<br>add re,rd,re |
| Generic conditional (e.g. division) | s[cond] re,ra,rb<br>div rf,rc,rd<br>sel re,rf,rc |

