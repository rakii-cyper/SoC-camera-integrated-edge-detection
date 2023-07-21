#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <opencv2/highgui/highgui.hpp>
#include <iostream>
#include <string>
#include <sstream>

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
  int frame_width = 640;
  int frame_height = 480;
  int count_frame = 0;
  VideoWriter video("outcpp.avi", cv::VideoWriter::fourcc('M','J','P','G'), 30, Size(frame_width, frame_height));
  
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

  while (1) {
    int cols = 0;
    int rows = 0;
    int len = 0;
    Mat frame = Mat::zeros(Size(frame_width, frame_height), CV_8UC3);
    while (cols < frame_width && rows < frame_height) {
      len = 0;
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
      
      // cout << "Number of bytes read: " << rc;
      while (len < rc) {
        Vec3b &intensity = frame.at<Vec3b>(rows, cols);
        for(int k = 0; k < 3; k++) {
          intensity.val[k] = int(buf[len + k]);
        }
        // cout << "reading [" << cols << ", " << rows << "]" << endl;
        rows++;
        len = len + 4;
        if (rows == frame_height) {
          rows = 0;
          cols++;

          if (cols == frame_width) break;
        }
      }
    }
    count_frame++;
    // ostringstream convert;
    // convert << count_frame;
    // cout << "Done 1 frame" << endl;

    // string name_frame = "./frame/frame" + convert.str() + ".png";
    // imwrite(name_frame, frame);
    video.write(frame);
  }
  cout << "done with" << count_frame << "frame." << endl;
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
