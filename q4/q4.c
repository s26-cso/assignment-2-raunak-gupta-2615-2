#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>

int main() {
    // op: stores the operation name (e.g., "add", "mul", "grok", "unc")
    // Size 6 allows at most 5 characters + null terminator as per spec
    char op[6];          // at most 5 characters + null terminator
    
    // num1, num2: the two integer operands for the operation
    int num1, num2;
    
    // handle: pointer to the dynamically loaded shared library
    // Initially NULL because no library is loaded yet
    void *handle = NULL; // current library handle

    // Read input lines until EOF or format mismatch
    // Format: "%5s" limits op to 5 chars (prevents buffer overflow)
    // scanf returns 3 if all three items were successfully read
    while (scanf("%5s %d %d", op, &num1, &num2) == 3) {
        
        // CRITICAL for memory constraint (2GB limit):
        // Each lib<op>.so can be up to 1.5GB. To stay under 2GB total,
        // we cannot have two libraries loaded simultaneously.
        // Therefore, close the previous library before loading a new one.
        if (handle != NULL) {
            dlclose(handle);  // unload the previous shared library
            handle = NULL;    // mark as closed to avoid double-close
        }

        // Build the shared library filename: "./lib<op>.so"
        // Example: if op = "add", libpath becomes "./libadd.so"
        // Size 20 is safe: "./lib" (5) + max op (5) + ".so" (3) + null (1) = 14 bytes max
        char libpath[20]; // "./lib" (5) + op (5) + ".so" (3) + null (1) = 14 max
        snprintf(libpath, sizeof(libpath), "./lib%s.so", op);

        // Dynamically load the shared library at runtime
        // RTLD_LAZY: resolve symbols only when they are actually used (performance optimization)
        // The library is expected to be in the current working directory
        handle = dlopen(libpath, RTLD_LAZY);
        
        // Check if loading failed (e.g., file doesn't exist, wrong architecture)
        if (handle == NULL) {
            // dlerror() returns a human-readable error message
            fprintf(stderr, "Error loading %s: %s\n", libpath, dlerror());
            continue;  // skip to next input line (don't attempt to call function)
        }

        // Clear any existing error from previous dlsym calls
        // This ensures we only detect errors from the upcoming dlsym
        dlerror();

        // Look up the function symbol with the same name as the operation
        // The function signature must be int (*)(int, int) as per spec
        // dlsym returns a void* which we cast to the appropriate function pointer type
        int (*func)(int, int) = (int (*)(int, int))dlsym(handle, op);
        
        // Check if symbol lookup failed (e.g., function not found in library)
        char *error = dlerror();
        if (error != NULL) {
            fprintf(stderr, "Error finding symbol %s: %s\n", op, error);
            dlclose(handle);  // clean up the loaded library
            handle = NULL;    // mark as closed
            continue;         // skip to next input line
        }

        // Call the dynamically loaded function with the two operands
        // The function pointer is now properly typed, so we can call it directly
        int result = func(num1, num2);
        
        // Print the result as required by the specification
        printf("%d\n", result);
    }

    // Clean up: close the last library if it's still open
    // This prevents memory leaks when the program exits
    if (handle != NULL) {
        dlclose(handle);
    }

    return 0;  // exit successfully
}