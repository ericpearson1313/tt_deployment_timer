#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#define TOTAL_WORDS 4096
#define LINES       512
#define WORDS_PER_LINE 8

int main(void)
{
    uint64_t buf[TOTAL_WORDS];
    int idx = 0;

    // --- Read 4096 64-bit hex words from stdin ---
    for (int i = 0; i < LINES; i++) {
        for (int w = 0; w < WORDS_PER_LINE; w++) {
            if (scanf("%lx", &buf[idx]) != 1) {
                fprintf(stderr, "Input parse error at word %d\n", idx);
                return 1;
            }
            idx++;
        }
    }
//	for( int ii = 0; ii < 10; ii++ )
//		printf("%lx\n ", buf[ii]);

    // --- Find first transition of bit 63 ---
    int end = -1;
    for (int i = 1; i < TOTAL_WORDS; i++) {
        int prev = (buf[i-1] >> 63) & 1;
        int curr = (buf[i]   >> 63) & 1;
        if (prev ^ curr) {
            end = i;
            break;
        }
    }

    if (end < 0) {
        fprintf(stderr, "No bit63 transition found, start at zero.\n");
	end = 0;
    }

    // --- Wrap back 2100 samples ---
    int start = end - 2100;
    if (start < 0) start += TOTAL_WORDS;

    // --- Extract 50 X-fields stepping forward by 10 ---
    // X-field = bits [31:20] (example: adjust if your X is elsewhere)
    int count = 50;
    int step  = 10;

    int pos = start;

    printf("ASCII thrust graph (50 samples, step=10)\n");
    printf("Index | Value | Graph\n");
    printf("---------------------------------------------\n");

    for (int i = 0; i < count; i++) {

        uint64_t word = buf[pos];

        // Extract X field (12-bit signed)
        int32_t x = (word >> 44) & 0xFFF;
        if (x & 0x800) x |= ~0xFFF;  // sign extend

        // Scale from +/-2048 to +/-40
        double scaled = (double)x * (40.0 / 2048.0);
        int bar = (int)scaled;

        // Print index and value
        printf("%3d   | %6d | ", i, x);

        // Center axis at column 40
        int center = 40;

        // Draw left side
        if (bar < 0) {
            for (int c = 0; c < center + bar; c++) putchar(' ');
            for (int c = 0; c < -bar; c++) putchar('#');
        } else {
            for (int c = 0; c < center; c++) putchar(' ');
            for (int c = 0; c < bar; c++) putchar('#');
        }

        putchar('\n');

        // Advance with wrap
        pos = (pos + step) % TOTAL_WORDS;
    }

    return 0;
}

