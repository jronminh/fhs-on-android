/* Answer "who am I" without privilege: the symbol layer can say root, and the
 * file system will disagree. This is the lie the identity page describes, made
 * small enough to read - and the comments say which checks still fail.
 *
 * build:  cc -shared -fPIC -O2 -o identity.so identity.c
 * use:    LD_PRELOAD=$PWD/identity.so id
 *
 * Still fails, because these go to the kernel with the real credentials:
 *   setuid()/setgid() as real syscalls, mount(), and any chown performed by a
 *   program that reads the owner back through its own syscall path.
 */
#define _GNU_SOURCE
#include <sys/types.h>
#include <unistd.h>

uid_t getuid(void)  { return 0; }
uid_t geteuid(void) { return 0; }
gid_t getgid(void)  { return 0; }
gid_t getegid(void) { return 0; }

/* Claim success and change nothing: the real owner stays the real uid, so the
 * next reader that goes to the kernel sees a different answer from this one. */
int chown(const char *path, uid_t owner, gid_t group)
{
    (void)path; (void)owner; (void)group;
    return 0;
}
