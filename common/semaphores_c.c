#include <fcntl.h>
#include <semaphore.h>
#include <stdio.h>
#include <stdlib.h>

sem_t* create_semaphore (const char* name, int parallel) {
  sem_t* r = sem_open (name, O_CREAT | O_EXCL, 0666, parallel);
  if (r == SEM_FAILED) {
    perror("failed to create semaphore");
    exit(1);
  }
  return r;
}
sem_t* open_semaphore (const char* name) {
  sem_t* r = sem_open (name, 0);
  if (r == SEM_FAILED) {
    perror("failed to open semaphore");
    exit(1);
  }
  return r;
}
void close_semaphore (sem_t* s) {
  if (sem_close(s) == -1) {
    perror("failed to close semaphore");
    exit(1);
  }
}
void wait_semaphore (sem_t* s) {
  if (sem_wait(s) == -1) {
    perror("failed to wait for semaphore");
    exit(1);
  }
}
void release_semaphore (sem_t* s) {
  if (sem_post(s) == -1) {
    perror("failed to release semaphore");
    exit(1);
  }
}

void delete_semaphore (const char* name) {
  if (sem_unlink(name) == -1) {
    //  ignore errors of deleting on purpose
  }
}
