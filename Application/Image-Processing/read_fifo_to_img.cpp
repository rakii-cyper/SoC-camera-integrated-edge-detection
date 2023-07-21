#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <opencv2/highgui/highgui.hpp>
#include <iostream>

using namespace std;
using namespace cv;
/* streamread.c -- Demonstrate read from a Xillybus FIFO.
   
This simple command-line application is given one argument: The device
file to read from. The read data is sent to standard output.

This program has no advantage over the classic UNIX 'cat' command. It was
written merely to demonstrate the coding technique.

We don't use allread() here (see memread.c), because if less than the
desired number of bytes arrives, they should be handled immediately.

See http://www.xillybus.com/doc/ for usage examples an information.

*/

void allwrite(int fd, unsigned char *buf, int len);  

int main(int argc, char *argv[]) {

  int fd, rc;
  unsigned char buf[1228800];
  

  if (argc!=2) {
    fprintf(stderr, "Usage: %s devfile\n", argv[0]);
    exit(1);
  }
  
  fd = open(argv[1], O_RDONLY);
  
  if (fd < 0) {
    if (errno == ENODEV)
      fprintf(stderr, "(Maybe %s a write-only file?)\n", argv[1]);

    perror("Failed to open devfile");
    exit(1);
  }

  int cols = 0;
  int rows = 0;
  Mat output = Mat::zeros(Size(640, 480), CV_8UC1);
  while (cols < 640 && rows < 480) {
    int len = 0;
    rc = read(fd, buf, sizeof(buf));
    
    if ((rc < 0) && (errno == EINTR))
      continue;
    
    if (rc < 0) {
      perror("allread() failed to read");
      exit(1);
    }
    
    if (rc == 0) {
      fprintf(stderr, "Reached read EOF.\n");
      exit(0);
    }
    cout << "Number of bytes read: " << rc << endl;
    cout << "Rows index: " << rows << endl;
    cout << "Columns index: " << cols << endl;
    while (len < rc) {
      if ((int) buf[len] == 1) {
          printf("ENDDDDD!");
      }
      output.at<uchar>(rows, cols) = (int) buf[len+1];
      cols++;
      len = len + 4;
      if (cols == 640) {
        cols = 0;
        rows++;

        if (rows == 480) break;
      }
    }
  cout << "Rows index after: " << rows << endl;
  cout << "Columns index after: " << cols << endl;
  imwrite("output.jpg", output);
  }
  imwrite("output1.jpg", output);
  cout << "DONE!";
  exit(0);
}
/* 
   Plain write() may not write all bytes requested in the buffer, so
   allwrite() loops until all data was indeed written, or exits in
   case of failure, except for EINTR. The way the EINTR condition is
   handled is the standard way of making sure the process can be suspended
   with CTRL-Z and then continue running properly.

   The function has no return value, because it always succeeds (or exits
   instead of returning).

   The function doesn't expect to reach EOF either.
*/

void allwrite(int fd, unsigned char *buf, int len) {
  int sent = 0;
  int rc;

  while (sent < len) {
    rc = write(fd, buf + sent, len - sent);
	
    if ((rc < 0) && (errno == EINTR))
      continue;

    if (rc < 0) {
      perror("allwrite() failed to write");
      exit(1);
    }
	
    if (rc == 0) {
      fprintf(stderr, "Reached write EOF (?!)\n");
      exit(1);
    }
 
    sent += rc;
  }
} 