#include <iostream> 
#include <thread> 
#include <vector>

void worker(int id) {
std::cout << "Thread " << id
<< " running on CPU core" << std::endl;
}

int main() {
unsigned int n_threads = std::thread::hardware_concurrency();
std::cout << "Launching " << n_threads << " threads...\n";

std::vector<std::thread> threads;
for (unsigned int i = 0; i < n_threads; ++i) {
threads.emplace_back(worker, i);
}

for (auto& t : threads) {
t.join();
}
return 0;

}