#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>

/* Analyze a set of simulated sensor readings supplied on the command line. */
#define WARNING_THRESHOLD 30
#define MIN_TEMP -50
#define MAX_TEMP 100
#define MAX_READINGS 20

static int parse_temp(const char *text, int *value) {
    char *end;
    errno = 0;
    long parsed = strtol(text, &end, 10);
    if (errno || end == text || *end != '\0' ||
        parsed < MIN_TEMP || parsed > MAX_TEMP) return 0;
    *value = (int)parsed;
    return 1;
}

int main(int argc, char **argv) {
    if (argc < 2 || argc > MAX_READINGS + 1) {
        fprintf(stderr, "Usage: %s <temp1> [temp2 ... temp20]\n", argv[0]);
        return EXIT_FAILURE;
    }
    int min = MAX_TEMP, max = MIN_TEMP, warnings = 0;
    long total = 0;
    for (int i = 1; i < argc; i++) {
        int temp;
        if (!parse_temp(argv[i], &temp)) {
            fprintf(stderr, "Error: invalid temperature '%s' (allowed: -50 to 100)\n", argv[i]);
            return EXIT_FAILURE;
        }
        if (temp < min) min = temp;
        if (temp > max) max = temp;
        if (temp >= WARNING_THRESHOLD) warnings++;
        total += temp;
    }
    int count = argc - 1;
    printf("Readings: %d\n", count);
    printf("Minimum: %d C\n", min);
    printf("Maximum: %d C\n", max);
    printf("Average: %.1f C\n", (double)total / count);
    printf("Warnings (>= %d C): %d\n", WARNING_THRESHOLD, warnings);
    printf("Status: %s\n", warnings ? "WARNING" : "NORMAL");
    return EXIT_SUCCESS;
}
