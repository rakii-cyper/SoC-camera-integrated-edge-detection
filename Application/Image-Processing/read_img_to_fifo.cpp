#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <termio.h>
#include <signal.h>

#include<iostream>
#include<opencv2/highgui/highgui.hpp>

using namespace std;
using namespace cv;

void allwrite(int fd, unsigned char *buf, int len);
void config_console();  

int main(int argc, char *argv[]) {

  int fd, rc;
  int number_of_bytes = 0;
  unsigned char buf[1228800];

  if (argc!=3) {
    fprintf(stderr, "Usage: %s devfile img_name\n", argv[0]);
    exit(1);
  }
  
  fd = open(argv[1], O_WRONLY);
  
  if (fd < 0) {
    if (errno == ENODEV)
      fprintf(stderr, "(Maybe %s a read-only file?)\n", argv[1]);

    perror("Failed to open devfile");
    exit(1);
  }

  // config_console(); // Configure standard input not to wait for CR
   
  Mat image;//taking an image matrix//
  image = imread(argv[2]);//loading an image//
  cout << image.cols << "x" << image.rows << endl;   
  for (int i = 0; i < image.rows; i++) {
     for (int j = 0; j < image.cols; j++) {
        buf[number_of_bytes++] = image.at<Vec3b>(i, j)[0];
        buf[number_of_bytes++] = image.at<Vec3b>(i, j)[1];
        buf[number_of_bytes++] = image.at<Vec3b>(i, j)[2];
        if (i == 0 && j == 0) {
            buf[number_of_bytes++] = (char) 1;
            printf("write (%d) start\n", (int) buf[number_of_bytes-1]);
        }
        else if (i == (image.rows - 2) && j == 0) {
            buf[number_of_bytes++] = (char) 2;
            printf("write (%d) pre\n", (int) buf[number_of_bytes-1]);
        }
        else if (i == (image.rows - 1) && j == 0) {
            buf[number_of_bytes++] = (char) 3;
            printf("write (%d) end\n", (int) buf[number_of_bytes-1]);
        }
        else
            buf[number_of_bytes++] = 0;
	}
  }
  allwrite(fd, buf, number_of_bytes);
  cout << number_of_bytes << endl;
  /* while (1) {
    // Read from standard input = file descriptor 0
    rc = read(0, buf, sizeof(buf));
    
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
    
    allwrite(fd, buf, rc);
  } */
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

/* config_console() does some good-old-UNIX vodoo standard input, so that
   read() won't wait for a carriage-return to get data. It also catches
   CTRL-C and other nasty stuff so it can return the terminal interface to 
   what is was before. In short, a lot of mumbo-jumbo, with nothing relevant 
   to Xillybus.
 */

void config_console() {
  struct termio console_attributes;

  if (ioctl(0, TCGETA, &console_attributes) != -1) {
    // If we got here, we're reading from console

    console_attributes.c_lflag &= ~ICANON; // Turn off canonical mode
    console_attributes.c_cc[VMIN] = 1; // One character at least
    console_attributes.c_cc[VTIME] = 0; // No timeouts

    if (ioctl(0, TCSETAF, &console_attributes) == -1)
      fprintf(stderr, "Warning: Failed to set console to char-by-char\n");    
  }
}
