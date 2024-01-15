#include <sys/types.h>
#include <sys/socket.h>  // socket
#include <stdio.h>	 // printf
#include <errno.h>	 // perror
#include <netinet/in.h>	 // bind
#include <arpa/inet.h>	 // inet_addr
#include <string.h>	 // memset
#include <time.h>

void read_forever(int sockfd) {
  char buf[64];
  int count = 0;
  int first_time = time(0);
  int last_time = first_time;
  while (1) {
    int len = recv(sockfd, buf, sizeof(buf), 0);
    count++;
    int now = time(0);
    if (now != last_time) {
      int bytes = count * (64 - 18 + len);
      int bits = bytes * 10;
      int utilization = 100 * bits / 10000000;
      printf("sec=%d pkt/s=%d byte/s=%d utilization=%d  \015",
	     now - first_time,
	     count,
	     bytes,
	     utilization);
      fflush(stdout);
      count = 0;
      last_time = now;
    }
  }
}

int main() {
  int sockfd = socket(AF_INET, SOCK_DGRAM, 0);
  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = inet_addr("192.168.1.2"); // INADDR_ANY;
  addr.sin_port = htons(0x400);
  int rc = bind(sockfd, (struct sockaddr *)&addr, 16);
  if (rc) { perror("bind"); return 1; }
  printf("bind to socket %d ok\n", sockfd);
  read_forever(sockfd);
  return 0;
}
