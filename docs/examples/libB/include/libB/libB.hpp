#pragma once

#include <string>

namespace libB {

// Оборачивает libC::greet() дополнительным текстом — показывает, что зависимость
// действительно подключена и работает через границу репозиториев.
std::string decorate();

} // namespace libB
