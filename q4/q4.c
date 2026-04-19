#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>   /* need this for dlopen, dlsym, dlclose - the dynamic loading functions */
int main() 
{
    /* store the operation name (max 5 chars as per the problem), plus some buffer */
    char op[16];
    char lib_name[32];        /* buffer for building the library filename like "./libadd.so" */
    int num1, num2;
    /* keep reading lines until there's no more input (EOF) */
    /* scanf returns the number of items successfully read; if it's not 3, I stop */
    while (scanf("%s %d %d", op, &num1, &num2) == 3)
    {
        /* build the library filename: "lib<op>.so" */
        /* For example, if op is add, build "libadd.so" */
        snprintf(lib_name, sizeof(lib_name), "./lib%s.so", op);
        /* add "./" at the front to make sure it looks in the current directory */
        /* try to open the shared library */
        /* RTLD_LAZY means only load the symbols when I actually need them */
        void *handle = dlopen(lib_name, RTLD_LAZY);
        if (!handle)
        {
            /* If dlopen fails, something is wrong, maybe the library doesn't exist */
            fprintf(stderr, "library dne %s: %s", lib_name, dlerror());
            continue;  /* skip this operation and try the next line */
        }
        /* clear any existing errors before calling dlsym */
        dlerror();
        /* look up the function inside the library */
        /* The function has the same name as the operation (e.g., "add", "mul") */
        /* dlsym returns a void* which I need to cast to a function pointer */
        int (*operation)(int, int);
        *(void **)(&operation) = dlsym(handle, op);
        /* cast it this way to avoid compiler warnings about void* to function pointer */
        /* check if dlsym succeeded */
        char *error = dlerror();
        if (error != NULL)
        {
            fprintf(stderr, "function dne %s: %s", op, error);
            dlclose(handle);  /* close the library before moving on */
            continue;
        }
        /* call the function with my two numbers and get the result */
        int result = operation(num1, num2);
        /* print the result */
        printf("%d\n", result);
        /* close the library since I'm done with it for this operation */
        /* This frees up memory, important since the problem says memory must stay under 2GB */
        dlclose(handle);
    }

    return 0;
}
