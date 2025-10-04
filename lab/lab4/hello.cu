#include <stdio.h>

__global__ void hello_kernel()
{
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    printf("Hello from thread %d\n", tid);
}

int main()
{
    hello_kernel<<<2, 4>>>();
    cudaDeviceSynchronize();
    return 0;
}