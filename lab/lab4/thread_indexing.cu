#include <stdio.h>

__global__ void print_indices()
{
    printf("Block(%d,%d) Thread(%d,%d)\n",
           blockIdx.x, blockIdx.y, threadIdx.x, threadIdx.y);
}
int main()
{
    dim3 blocks(2, 2);
    dim3 threads(2, 3);
    print_indices<<<blocks, threads>>>();
    cudaDeviceSynchronize();
    return 0;
}