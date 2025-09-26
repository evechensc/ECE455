#include <iostream>
#include <vector>
#include <omp.h>

int main()
{
    const int N = 10000000;
    std::vector<int> data(N, 1); // all ones
    long long sum = 0;

#pragma omp parallel for reduction(+ : sum)
    for (int i = 0; i < N; ++i)
    {
        sum += data[i];
    }

    std::cout << "Sum = " << sum << std::endl;
    return 0;
}