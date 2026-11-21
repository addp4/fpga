#if 0
int fib(int n);
int _start() { return fib(10); }
int fib(int n) { return n < 2 ? 1 : fib(n-1) + fib(n-2); }

#elif 0

int _start() {

  int n = busybeaver();
  asm volatile("" : "+r"(n));

  int sum = 0;
  asm volatile("addi a0, a0, 1");
  asm volatile("addi a0, a0, 1");
  asm volatile("addi a0, a0, 1");
  asm volatile("addi a0, a0, 1");
  asm volatile("addi a0, a0, 1");
  asm volatile("addi a0, a0, 1");
  asm volatile("addi a0, a0, 1");
  asm volatile("addi a0, a0, 1");
  asm volatile("addi a0, a0, 1");
  asm volatile("addi a0, a0, 1");
  asm volatile("addi a0, a0, 1");
  asm volatile("addi a0, a0, 1");
  asm volatile("addi a0, a0, 1");
  asm volatile("addi a0, a0, 1");
  asm volatile("addi a0, a0, 1");
  for (int i = 0; i < 100000; i += 1) {
    sum += i;
    asm volatile("" : "+r"(i));
  }
  return sum;
}

#else

// A0	A1	B0	B1	C0	C1	D0	D1	sigma(M)	s(M)
// 1RB	1LB	1LA	0LC	1RH	1LD	1RD	0RA	13	107
int _start() {
  unsigned int tape;
  enum { A, B, C, D, H } state = A;
  enum { L, R } dir;
  int count = 0;
  tape = 0;
  while(state != H) {
    count++;
    int sym = tape & 1;
    if (state == A && sym == 0) { sym = 1; dir = R; state = B; }
    else if (state == A && sym == 1) { sym = 1; dir = L; state = B; }
    else if (state == B && sym == 0) { sym = 1; dir = L; state = A; }
    else if (state == B && sym == 1) { sym = 0; dir = L; state = C; }
    else if (state == C && sym == 0) { sym = 1; dir = R; state = H; }
    else if (state == C && sym == 1) { sym = 1; dir = L; state = D; }
    else if (state == D && sym == 0) { sym = 1; dir = R; state = D; }
    else if (state == D && sym == 1) { sym = 0; dir = R; state = A; }

    tape = (tape & ~1) | sym;
    if (dir == R)
      tape = (tape >> 1) | (tape << 31);
    else
      tape = (tape << 1) | (tape >> 31);
  }
  while(1) asm volatile("" : "+r"(count));
  return count;
}

#endif
