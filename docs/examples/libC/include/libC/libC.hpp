#pragma once

#include <string>

namespace libC {

// Возвращает приветствие с указанием версии — используется в libB и app,
// чтобы визуально проверить, из какой сборки libC пришёл конкретный бинарник.
std::string greet();

} // namespace libC
