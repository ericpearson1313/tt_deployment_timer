// vim: ts=4:#include <stdio.h>
#include <stdio.h>
#include <time.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/i2c-dev.h>

#define I2C_DEV   "/dev/i2c-1"
#define FRAM_ADDR 0x50
#define TEST_ADDR 0x0123

static int fram_write(int fd, uint16_t addr, const uint8_t *buf, size_t len)
{
    uint8_t tmp[2 + len];
    tmp[0] = addr >> 8;
    tmp[1] = addr & 0xFF;
    memcpy(&tmp[2], buf, len);
    return (write(fd, tmp, 2 + len) == (int)(2 + len)) ? 0 : -1;
}

static int fram_read(int fd, uint16_t addr, uint8_t *buf, size_t len)
{
    uint8_t a[2] = { addr >> 8, addr & 0xFF };
    if (write(fd, a, 2) != 2)
        return -1;
    return (read(fd, buf, len) == (int)len) ? 0 : -1;
}

int main(int argc, char **argv)
{
    if (argc != 2) {
        printf("Usage:\n");
        printf("  fram_zero zero # fill mem with 0\n");
        return 1;
    }

    int fd = open(I2C_DEV, O_RDWR);
    if (fd < 0) { perror("open"); return 1; }
    if (ioctl(fd, I2C_SLAVE, FRAM_ADDR) < 0) { perror("ioctl"); return 1; }

    uint8_t buf[8];

    if (!strcmp(argv[1], "zero")) {
	
        for (int i = 0; i < 8; i++)
            buf[i] = 0;

        printf("Writing pattern:\n");
        for (int i = 0; i < 8; i++)
            printf("%02X ", buf[i]);
        printf("\n");

	for( int ss = 0; ss < 4096; ss++ )
        	if (fram_write(fd, ss * 8, buf, sizeof(buf)) < 0) {
            		printf("Write failed\n");
            		return 1;
        	}

        printf("Zerong complete\n");
    }

    close(fd);
    return 0;
}

