/* Narrow ABI adapter: Guile's macOS stat binding drops subsecond fields.
 * Keep platform layout details out of Scheme and copy an alignment-safe array.
 */
#ifdef __APPLE__
#define _DARWIN_C_SOURCE 1
#endif
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <stdint.h>
#include <string.h>
#include <sys/stat.h>

int murmur_fingerprint(int fd, unsigned char *out) {
    struct stat s;
    if (fstat(fd, &s) != 0) return errno;
    if (!S_ISREG(s.st_mode)) return EINVAL;
#ifdef __APPLE__
    const struct timespec m = s.st_mtimespec;
    const struct timespec c = s.st_ctimespec;
#else
    const struct timespec m = s.st_mtim;
    const struct timespec c = s.st_ctim;
#endif
    const uint64_t values[7] = {
        (uint64_t)s.st_dev, (uint64_t)s.st_ino, (uint64_t)s.st_size,
        (uint64_t)m.tv_sec, (uint64_t)m.tv_nsec,
        (uint64_t)c.tv_sec, (uint64_t)c.tv_nsec
    };
    memcpy(out, values, sizeof values);
    return 0;
}
