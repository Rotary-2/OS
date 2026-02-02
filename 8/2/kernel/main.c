#include "print.h"
#include "init.h"

void main(void) {
    put_str("I am kernel\n");
    init_all();
    ASSERT(1==2);
    while(1);
    return 0;
}