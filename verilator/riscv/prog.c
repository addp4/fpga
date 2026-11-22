#if 0
int memo[32];

int fib(int n) {
  if (n < 2) return 1;
  if (memo[n]) return memo[n];
  int x = fib(n-1) + fib(n-2);
  memo[n] = x;
  return x;
}

int main(int n) {
  return fib(10);
}

#elif 0

int main() {

  asm volatile("addi a0, a0, 1");
  asm volatile("addi a0, a0, 1");
  asm volatile("addi a0, a0, 1");

  int sum = 0;
  for (int i = 0; i < 100; i += 1) {
    sum += i;
    asm volatile("" : "+r"(i));
  }
  return sum;
}

#elif 1

// busybeaver without memory, tape is in a register
// A0	A1	B0	B1	C0	C1	D0	D1	sigma(M)	s(M)
// 1RB	1LB	1LA	0LC	1RH	1LD	1RD	0RA	13	107
int main() {
  unsigned int tape;
  enum { A, B, C, D, H } state = A;
  enum { L, R } dir;
  int count = 0;
  tape = 0;
  int sum = 0;
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
  return count;
}

#elif 1

// busybeaver
// A0	A1	A2	A3	B0	B1	B2	B3	sigma(M)	s(M)
// 1RB	2LA	1RA	1RA	1LB	1LA	3RB	1RH	2,050	3,932,964
#define N 4096
int tape[N];
int main() {
  enum { A, B, C, D, H } state = A;
  enum { L, R } dir;
  int count = 0;
  int pos = N/2;
  while(state != H) {
    count++;
    int sym = tape[pos];
    if      (state == A && sym == 0) { sym = 1; dir = R; state = B; }
    else if (state == A && sym == 1) { sym = 2; dir = L; state = A; }
    else if (state == A && sym == 2) { sym = 1; dir = R; state = A; }
    else if (state == A && sym == 3) { sym = 1; dir = R; state = A; }
    else if (state == B && sym == 0) { sym = 1; dir = L; state = B; }
    else if (state == B && sym == 1) { sym = 1; dir = L; state = A; }
    else if (state == B && sym == 2) { sym = 3; dir = R; state = B; }
    else if (state == B && sym == 3) { sym = 1; dir = R; state = H; }

    tape[pos] = sym;
    pos = (dir == R) ? pos + 1 : pos - 1;
  }
  return count;
}

#elif 1

char buf[4096];

int _start() {
  int sum = 0;
  for (int i = 0; i < sizeof(buf); i++)
    sum += buf[i];
  return sum;
}
#endif
