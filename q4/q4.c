#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>

int main() {
    char op[6];          // at most 5 characters + null terminator
    int num1, num2;
    void *handle = NULL; // current library handle

    while (scanf("%5s %d %d", op, &num1, &num2) == 3) {
        // Close previous library to stay within 2GB memory limit
        if (handle != NULL) {
            dlclose(handle);
            handle = NULL;
        }

        // Build library path: "./lib<op>.so"
        char libpath[20]; // "./lib" (5) + op (5) + ".so" (3) + null (1) = 14 max
        snprintf(libpath, sizeof(libpath), "./lib%s.so", op);

        // Dynamically load the shared library
        handle = dlopen(libpath, RTLD_LAZY);
        if (handle == NULL) {
            fprintf(stderr, "Error loading %s: %s\n", libpath, dlerror());
            continue;
        }

        // Clear any existing error
        dlerror();

        // Look up the function symbol
        int (*func)(int, int) = (int (*)(int, int))dlsym(handle, op);
        char *error = dlerror();
        if (error != NULL) {
            fprintf(stderr, "Error finding symbol %s: %s\n", op, error);
            dlclose(handle);
            handle = NULL;
            continue;
        }

        // Call the function and print result
        int result = func(num1, num2);
        printf("%d\n", result);
    }

    // Clean up
    if (handle != NULL) {
        dlclose(handle);
    }

    return 0;
}
