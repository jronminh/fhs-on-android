/* SPDX-License-Identifier: MIT */
/* Illustrate session detachment, assuming only stdio comes from the shell. */
#define _POSIX_C_SOURCE 200809L
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>

static void fork_and_exit_parent(void)
{
    pid_t child = fork();
    if (child < 0) {
        perror("fork");
        _exit(1);
    }
    if (child > 0)
        _exit(0);
}

int main(int argc, char **argv)
{
    if (argc < 2 || argv[1][0] != '/') {
        fputs("usage: detach /absolute/program [args...]\n", stderr);
        return 2;
    }

    fork_and_exit_parent();
    if (setsid() == -1) {
        perror("setsid");
        _exit(1);
    }
    fork_and_exit_parent();

    if (chdir("/") == -1) {
        perror("chdir");
        _exit(1);
    }
    int null_fd = open("/dev/null", O_RDWR);
    if (null_fd == -1) {
        perror("open /dev/null");
        _exit(1);
    }
    for (int fd = STDIN_FILENO; fd <= STDERR_FILENO; fd++) {
        if (dup2(null_fd, fd) == -1) {
            perror("dup2");
            _exit(1);
        }
    }
    if (null_fd > STDERR_FILENO)
        close(null_fd);

    execv(argv[1], argv + 1);
    _exit(127);
}
