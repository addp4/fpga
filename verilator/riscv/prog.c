#if 0
int fib(int n);
int _start() { return fib(10); }
int fib(int n) { return n < 2 ? 1 : fib(n-1) + fib(n-2); }
#else

int _start() {
  int sum = 0;
  for (int i = 0; i < 100000; i += 1) {
    sum += i;
    asm volatile("" : "+r"(i));
  }
  return sum;
}

#endif
