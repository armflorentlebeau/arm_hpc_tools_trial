/* 
   ===============================================================================
   Copyright (C) Arm Limited, 2019 All rights reserved.
   The example code is provided to you as an aid to learning when working
   with Arm-based technology, including but not limited to programming tutorials.
   Arm hereby grants to you, subject to the terms and conditions of this Licence,
   a non-exclusive, non-transferable, non-sub-licensable, free-of-charge licence,
   to use and copy the Software solely for the purpose of demonstration and
   evaluation.
   You accept that the Software has not been tested by Arm therefore the Software
   is provided “as is”, without warranty of any kind, express or implied. In no
   event shall the authors or copyright holders be liable for any claim, damages
   or other liability, whether in action or contract, tort or otherwise, arising
   from, out of or in connection with the Software or the use of Software.
   ===============================================================================
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <mpi.h>
#include <math.h>

#define DEFAULT_FN "res_C.mat"
#define DEFAULT_SIZE 64


void minit(int sz, double *A)
{
  for(int i=0; i<sz; i++)
  {
    for(int j=0; j<sz; j++)
    {
      A[i*sz+j] = i*(j+1);
    }
  }
}


void mwrite(int sz, double *A, char *fn)
{
  FILE *f = fopen(fn, "w+");
  
  for(int i=0; i<sz; i++)
  {
    for(int j=0; j<sz; j++)
    {
      fprintf(f, "%g\t", A[i*sz+j]);
    }
    fprintf(f, "\n");
  }

  fclose(f);
}


void mmult(int sz, int nslices, double *A, double *B, double *C)
{
  for(int i=0; i<sz/nslices; i++)
  {
    for(int j=0; j<sz; j++)
    {
      double res = 0.0;

      for(int k=0; k<sz; k++)
      {
        res += A[i*sz+k]*B[k*sz*j];
      }

      C[i*sz+j] += res;
    }
  }
}


int main(int argc, char *argv[])
{
  int mr, nproc, sz, slice;
  double *mat_a, *mat_b, *mat_c;
  char filename[32];
  int remainder;
  MPI_Status st;

  MPI_Init (&argc, &argv);
  MPI_Comm_rank(MPI_COMM_WORLD, &mr);	// my rank
  MPI_Comm_size(MPI_COMM_WORLD, &nproc); // number of processors

  if(argc > 3 || (argc > 2 && strcmp(argv[1],"-h") == 0) )
  {
    if(mr == 0)
    {
      printf("Usage: ./mmult [-h] SIZE FILENAME\n \
          \t-h: display this help message\n \
          \tSIZE: size of the matrix to compute (default is %d)\n \
          \tFILENAME: output matrix file name (default is %s)\n", DEFAULT_SIZE, DEFAULT_FN);
    }

    return 1;
  }
  else
  {
    if(argc > 1)
      sz = atoi(argv[1]); // set size
    else
      sz = DEFAULT_SIZE;
    
    if(argc == 3)
      strcpy(filename, argv[2]); // set filename
    else
      strcpy(filename, DEFAULT_FN);
  }

  remainder = sz%nproc;

  if(remainder)
  {
    if(mr == 0)
      printf("%d: Info: reducing SIZE (%d) to %d to be a multiple of number of processes (%d)\n", mr, sz, sz-remainder, nproc);

    sz=sz-remainder; // now becomes divisible by the number of processes
  }

  slice = sz*sz/nproc; // set slice size in number of elements

  if(mr == 0)
    printf("%d: Size of the matrices: %dx%d\n", mr, sz, sz);

  if(mr == 0)
  {
    mat_a = (double*)malloc(sz*sz*sizeof(double));
    mat_b = (double*)malloc(sz*sz*sizeof(double));
    mat_c = (double*)malloc(sz*sz*sizeof(double));

    printf("%d: Initializing matrices...\n", mr);

    minit(sz, mat_a);
    minit(sz, mat_b);
    minit(sz, mat_c);

    printf("%d: Sending matrices...\n", mr);

    for(int i=1; i<nproc; i++)
    {
      MPI_Send ( &mat_a[slice*i], slice, MPI_DOUBLE, i, i, MPI_COMM_WORLD );
      MPI_Send ( &mat_b[0], sz*sz, MPI_DOUBLE, i, 100+i, MPI_COMM_WORLD );
      MPI_Send ( &mat_c[slice*i], slice, MPI_DOUBLE, i, 200+i, MPI_COMM_WORLD );
    }
  }
  else
  {
    mat_a = malloc(slice*sizeof(double));
    mat_b = malloc(sz*sz*sizeof(double));
    mat_c = malloc(slice*sizeof(double));

    printf("%d: Receiving matrices...\n", mr);

    MPI_Recv ( &mat_a[0], slice, MPI_DOUBLE, 0, mr, MPI_COMM_WORLD, &st );
    MPI_Recv ( &mat_b[0], sz*sz, MPI_DOUBLE, 0, 100+mr, MPI_COMM_WORLD, &st );
    MPI_Recv ( &mat_c[0], slice, MPI_DOUBLE, 0, 200+mr, MPI_COMM_WORLD, &st );
  }

  printf("%d: Processing...\n", mr);
  
  mmult(sz, nproc, mat_a, mat_b, mat_c);
  
  if(mr == 0)
  {
    printf("%d: Receiving result matrix...\n", mr);

    for(int i=1; i<nproc; i++)
    {
      MPI_Recv ( &mat_c[slice*i], slice, MPI_DOUBLE, i, 500+i, MPI_COMM_WORLD, &st );
    }
  }
  else
  {
    printf("%d: Sending result matrix...\n", mr);
    
    MPI_Send ( &mat_c[0], slice, MPI_DOUBLE, 0, 500+mr, MPI_COMM_WORLD );
  }

  if(mr == 0)
  {
    printf("%d: Writing results...\n", mr);
    mwrite(sz, mat_c, filename );
    printf("%d: Done.\n", mr);
  }

  free(mat_a);
  free(mat_b);
  free(mat_c);

  MPI_Finalize();

  return 0;
}

