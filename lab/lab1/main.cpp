#include <iostream> 
#include <cstdlib>

int main() {
const char* hostname = std::getenv("HOSTNAME");
std::cout << "Hello from C++ on node: "
<< (hostname ? hostname : "unknown")
<< std::endl;
return 0;
}