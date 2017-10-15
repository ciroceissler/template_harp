#include <iostream>
#include "harp.h"

#define CL 1                 // cache line - bytes
#define NI 64*CL/sizeof(int) // number of itens


int main()
{
  int A[NI];
  int B[NI];

  // initialize
  for (int i = 0; i < NI; i++)
  {
    A[i] = i;
  }

  #pragma omp target device(HARPSIM) map(to: A) map(from: B)
  #pragma omp parallel for use(hrw) module(loopback)
  for (int i = 0; i < NI; i++)
  {
    B[i] = A[i];
  }

  for (int i = 0; i < NI; i++)
  {
    std::cout << " idx = " << i << " : " << B[i] << "\n";
  }

  return 0;
}

