#include "libB/libB.hpp"
#include "libC/libC.hpp"

namespace libB {

std::string decorate() {
  return "libB says: [" + libC::greet() + "]";
}

} // namespace libB
