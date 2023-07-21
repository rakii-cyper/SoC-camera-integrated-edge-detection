#define _GNU_SOURCE
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <termio.h>
#include <signal.h>
#include <pthread.h>
#include <string.h>
#include <semaphore.h>
#include <sys/mman.h>

#define NUMBER_OF_FRAME 128

struct arg_struct {
    char *device_name;
    char *file_name;
};

void allwrite(int fd, float *buf, int len);
void *read_from_fifo(void *arg);
void *write_to_fifo(void *arg);

int main(int argc, char *argv[]) {
  pthread_t thread_id[3];
  struct arg_struct arg_0, arg_1;

  if (argc!=6) {
    fprintf(stderr, "Usage: %s read_devfile write_devfile_0 write_devfile_1 input_file_0 input_file_1\n", argv[0]);
    exit(1);
  }

  arg_0.device_name = argv[2];
  arg_1.device_name = argv[3];
  arg_0.file_name = argv[4];
  arg_1.file_name = argv[5];
  // write_to_fifo((void *) &arg);
  if (pthread_create(&thread_id[0], NULL, read_from_fifo, (void *) argv[1])) {
    perror("Failed to create thread");
    exit(1);
  }

  if (pthread_create(&thread_id[1], NULL, write_to_fifo, (void *) &arg_0)) {
    perror("Failed to create thread");
    exit(1);
  }

  if (pthread_create(&thread_id[2], NULL, write_to_fifo, (void *) &arg_1)) {
    perror("Failed to create thread");
    exit(1);
  }

  pthread_join(thread_id[0], NULL);
  pthread_join(thread_id[1], NULL);
  pthread_join(thread_id[2], NULL);
  
  return -1;
}

void allwrite(int fd, float *buf, int len) {
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

void *read_from_fifo(void* arg) {
  char *device_name = (char *) (arg);
  printf("READING %s!!!\n", device_name);
  int fd, rc;
  int counter = 0;
  int read_time_cnt = 1;
  float buf[128];
  
  fd = open(device_name, O_RDONLY);
  
  if (fd < 0) {
    if (errno == ENODEV)
      fprintf(stderr, "(Maybe %s a write-only file?)\n", device_name);

    perror("Failed to open read devfile");
    exit(1);
  }
  while (1) {
    rc = read(fd, buf, sizeof(buf));
    for (int i=0; i < rc/4; i++){
       printf("Value: %f \n", buf[i]);
     }    
  }

  /* while (read_time_cnt < 2) {
     rc = read(fd, buf, sizeof(buf));
     counter += (int) rc / 4;
     if (counter > NUMBER_OF_FRAME) {
       counter = (int) rc / 4;
       read_time_cnt++;
     }
     printf("Read %d bytes.\n", counter);
    
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
 
     for (int i=0; i < counter; i++){
       printf("Value: %f \n", buf[i]);
     }
   }*/
  printf("DONE READING!!!\n");
  return NULL;
}

void *write_to_fifo(void* arg) {
  // initial variables for writing to fifo
  printf("WRITING!!!\n");
  struct arg_struct *arguments = (struct arg_struct *) arg;
  int fd;
  float buf[NUMBER_OF_FRAME+10];

  // initial variables for reading input file
  FILE * fp;
  char * line = NULL;
  size_t len = 0;
  ssize_t read_cnt;
  int counter = 0;

  fp = fopen(arguments->file_name, "r");
  fd = open(arguments->device_name, O_WRONLY);
  
  if (fd < 0) {
    if (errno == ENODEV)
      fprintf(stderr, "(Maybe %s a read-only file?)\n", arguments->device_name);

    perror("Failed to open write devfile");
    exit(1);
  }

  if (fp == NULL) {
    perror("Failed to open input file");
    exit(1);
  }

  while ((read_cnt = getline(&line, &len, fp)) != -1) {
    if (read_cnt != 0) {
      line[strlen(line)-1] = '\0';
      buf[counter++] = (float) atof(line);
    }
  }
  
  allwrite(fd, buf, counter*4);
  printf("number of bytes write to %s: %d\n", arguments->device_name, counter*4);
  
  fclose(fp);
  close(fd);
  if (line)
    free(line);

  printf("DONE WRITING!!!\n");
  return NULL;
}
