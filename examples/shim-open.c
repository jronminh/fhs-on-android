/* A minimal LD_PRELOAD path shim: prefix every absolute path the program opens
 * with TREE. It is the idea, not a working shim, and the comments name what it
 * does not reach - which is the whole argument of the loader page.
 *
 * build:  cc -shared -fPIC -O2 -o shim-open.so shim-open.c -ldl
 * use:    TREE=/data/local/tmp/tree LD_PRELOAD=$PWD/shim-open.so program
 *
 * Not reached by this file, by construction:
 *   - a static binary (nothing is preloaded into it);
 *   - a raw syscall() from the program;
 *   - reads libc performs inside itself (NSS, gconv, ld.so.cache) before or
 *     around the symbol the program calls.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <limits.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static const char *tree(void)
{
    static char t[PATH_MAX];
    if (!t[0]) {
        const char *e = getenv("TREE");
        if (e) snprintf(t, sizeof t, "%s", e);
    }
    return t;
}

static const char *map(const char *p, char *buf)
{
    if (!p || p[0] != '/' || !tree()[0]) return p;
    if (strlen(tree()) + strlen(p) + 1 > PATH_MAX) return p;
    snprintf(buf, PATH_MAX, "%s%s", tree(), p);
    return buf;
}

int open(const char *path, int flags, ...)
{
    static int (*real)(const char *, int, ...);
    if (!real) real = dlsym(RTLD_NEXT, "open");
    char buf[PATH_MAX];
    mode_t mode = 0;
    if (flags & O_CREAT) {
        va_list ap;
        va_start(ap, flags);
        mode = (mode_t)va_arg(ap, int);
        va_end(ap);
    }
    return real(map(path, buf), flags, mode);
}

int openat(int dirfd, const char *path, int flags, ...)
{
    static int (*real)(int, const char *, int, ...);
    if (!real) real = dlsym(RTLD_NEXT, "openat");
    char buf[PATH_MAX];
    mode_t mode = 0;
    if (flags & O_CREAT) {
        va_list ap;
        va_start(ap, flags);
        mode = (mode_t)va_arg(ap, int);
        va_end(ap);
    }
    return real(dirfd, map(path, buf), flags, mode);
}
