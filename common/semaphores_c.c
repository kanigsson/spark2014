#ifndef _WIN32

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

#else

#include <stdio.h>
#include <windows.h>

HANDLE create_semaphore (const char* name, int parallel) {
  HANDLE r = CreateSemaphore(NULL, parallel, parallel, name);
  if (r == NULL) {
    printf("failed to create semaphore");
    exit(1);
  }
  return r;
}

HANDLE open_semaphore (const char* name) {
  HANDLE r = OpenSemaphore(SEMAPHORE_ALL_ACCESS, FALSE, name);
  if (r == NULL) {
    printf("failed to open semaphore\n");
    exit(1);
  }
  return r;
}

void close_semaphore (HANDLE s) {
  if (!CloseHandle(s)) {
    printf("failed to close semaphore\n");
    exit(1);
  }
}
void wait_semaphore (HANDLE s) {
  DWORD waitresult = WaitForSingleObject (s, INFINITE);
  if (waitresult != WAIT_OBJECT_0) {
    printf("failed to wait for semaphore: %lu\n", dw);    
    exit(1);
  }
}
void release_semaphore (HANDLE s) {
  if (!ReleaseSemaphore(s,1, NULL)) {
    printf("failed to release semaphore\n");
    exit(1);
  }
}

void delete_semaphore (const char* name) {
  ;
}

#endif
