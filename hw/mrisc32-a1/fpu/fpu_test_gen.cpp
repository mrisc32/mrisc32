#include <cstdint>
#include <cstring>
#include <cstdio>

float raw2float(const uint32_t x) {
  float y;
  std::memcpy(&y, &x, sizeof(y));
  return y;
}

uint32_t float2raw(const float x) {
  uint32_t y;
  std::memcpy(&y, &x, sizeof(y));
  return y;
}

// Print decomposed.
void pd(const uint32_t x) {
  const auto sign = (x & 0x80000000u) != 0u;
  const auto exp = (x >> 23) & 0xffu;
  const auto significand = (x & 0x7fffffu) | 0x800000u;
  printf("(%s, %02x, %06x)", sign ? "-" : "+", exp, significand);
}

void fmul(const uint32_t a, const uint32_t b) {
  const auto c = float2raw(raw2float(a) * raw2float(b));
  printf("0x%08x * 0x%08x = 0x%08x\n", a, b, c);
  printf("%.8g * %.8g = %.8g\n",
         raw2float(a), raw2float(b), raw2float(c));
  pd(a); printf(" * "); pd(b); printf(" = "); pd(c); printf("\n\n");
}

int main() {
  fmul(0x40490fdbu, 0x40f8a3d7u);
  fmul(0x7f000000u, 0xff000000u);
  fmul(0x00000000u, 0x7f800000u);
  fmul(0x402df854u, 0x3fb504f3u);
  fmul(0x7f555555u, 0x3f8ccccdu);
  fmul(0x7f555555u, 0x3fa66666u);
  fmul(0x00d55555u, 0x3f000000u);
  fmul(0x3fb504f3u, 0x3fb504f3u);
  fmul(0x3fb504f3u, 0x3fb504f4u);
}
