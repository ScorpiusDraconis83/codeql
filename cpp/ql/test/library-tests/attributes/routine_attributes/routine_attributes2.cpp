#define HIDDEN __attribute__((visibility("hidden")))

#include "routine_attributes2.h"

void HIDDEN a_routine() {
    return;
}
