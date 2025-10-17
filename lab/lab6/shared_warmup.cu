#include <iostream>
#include <vector>
#include <random>
#include <cassert>

#define BLOCK_DIM 256
#define N (1 << 16) // 65,536 elements

// ---------- CUDA Error Checking ----------
#define checkCuda(val) check((val), #val, __FILE__, __LINE__)
void check(cudaError_t err, const char *const func, const char *const file,
           const int line)
{
    if (err != cudaSuccess)
    {
        std::cerr << "CUDA Error at " << file << ":" << line << " — "
                  << cudaGetErrorString(err) << " (" << func << ")" << std::endl;
        std::exit(EXIT_FAILURE);
    }
}

// ---------- Random Initialization ----------
template <typename T>
std::vector<T> create_rand_vector(size_t n, T min_val = 0, T max_val = 50)
{
    std::random_device r;
    std::default_random_engine e(r());
    std::uniform_real_distribution<double> dist(min_val, max_val);

    std::vector<T> vec(n);
    for (size_t i = 0; i < n; ++i)
        vec[i] = static_cast<T>(dist(e));
    return vec;
}

// ---------- Shared Memory Warm-up Kernel ----------
template <typename T>
__global__ void square_shared_kernel(const T *in, T *out, size_t sz)
{
    __shared__ T tile[BLOCK_DIM];

    size_t idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= sz)
        return;

    // 1. Load from global to shared memory
    tile[threadIdx.x] = in[idx];
    __syncthreads();

    // 2. Compute in shared memory
    tile[threadIdx.x] = tile[threadIdx.x] * tile[threadIdx.x];
    __syncthreads();

    // 3. Write back to global memory
    out[idx] = tile[threadIdx.x];
}

// ---------- Main ----------
int main()
{
    using T = float;
    std::vector<T> h_in = create_rand_vector<T>(N);
    std::vector<T> h_out(N);

    T *d_in, *d_out;
    checkCuda(cudaMalloc(&d_in, sizeof(T) * N));
    checkCuda(cudaMalloc(&d_out, sizeof(T) * N));
    checkCuda(cudaMemcpy(d_in, h_in.data(), sizeof(T) * N, cudaMemcpyHostToDevice));

    dim3 threadsPerBlock(BLOCK_DIM);
    dim3 blocksPerGrid((N + BLOCK_DIM - 1) / BLOCK_DIM);
    square_shared_kernel<<<blocksPerGrid, threadsPerBlock>>>(d_in, d_out, N);

    checkCuda(cudaMemcpy(h_out.data(), d_out, sizeof(T) * N, cudaMemcpyDeviceToHost));
    checkCuda(cudaFree(d_in));
    checkCuda(cudaFree(d_out));

    // Verify output
    for (size_t i = 0; i < 5; ++i)
        std::cout << "in[" << i << "] = " << h_in[i]
                  << ", out[" << i << "] = " << h_out[i] << std::endl;

    std::cout << "\nSuccess! Computed squares using shared memory.\n";
    return 0;
}