#include <stdio.h>

__global__ void saxpy(int n, float a, float *x, float *y)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n)
        y[i] = a * x[i] + y[i];
}

int main()
{
    int N = 1000000;
    size_t size = N * sizeof(float);
    float *x, *y, *d_x, *d_y;

    x = (float *)malloc(size);
    y = (float *)malloc(size);
    for (int i = 0; i < N; i++)
    {
        x[i] = 1.0f;
        y[i] = 2.0f;
    }

    cudaMalloc(&d_x, size);
    cudaMalloc(&d_y, size);
    cudaMemcpy(d_x, x, size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_y, y, size, cudaMemcpyHostToDevice);

    int threadsPerBlock = 256;
    int blocksPerGrid = (N + threadsPerBlock - 1) / threadsPerBlock;
    saxpy<<<blocksPerGrid, threadsPerBlock>>>(N, 2.0f, d_x, d_y);

    cudaMemcpy(y, d_y, size, cudaMemcpyDeviceToHost);
    printf("y[0] = %f\n", y[0]);

    cudaFree(d_x);
    cudaFree(d_y);
    free(x);
    free(y);
    return 0;
}