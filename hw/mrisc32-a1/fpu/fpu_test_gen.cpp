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

void fmul(const uint32_t a, const uint32_t b) {
  const auto c = float2raw(raw2float(a) * raw2float(b));
  printf("0x%08x * 0x%08x = 0x%08x\n", a, b, c);
  printf("%.7f * %.7f = %.7f\n",
         raw2float(a), raw2float(b), raw2float(c));
}

int main() {
  fmul(0x40490fdbu, 0x40f8a3d7u);
  fmul(0x7f000000u, 0xff000000u);
  fmul(0x00000000u, 0x7f800000u);
}
