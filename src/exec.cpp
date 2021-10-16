#include "exec.h"

using namespace godot;

void NativeExec::_register_methods() {
    register_method("exec", &NativeExec::exec);
}

int NativeExec::exec() {
    return 0;
}
