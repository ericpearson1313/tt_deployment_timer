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
#define TEST_ADDR 0x0

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
    int fd = open(I2C_DEV, O_RDWR);
    if (fd < 0) { perror("open"); return 1; }
    if (ioctl(fd, I2C_SLAVE, FRAM_ADDR) < 0) { perror("ioctl"); return 1; }

    uint8_t buf[8];
        printf("Fram Read:\n");
	for (int ll = 0; ll < atoi( argv[1] ); ll++ ) {
		for( int ww = 0; ww < 8; ww++ ) {
    			if (fram_read(fd, 8*ww+64*ll, buf, sizeof(buf)) < 0) {
            			printf("Read failed\n");
            			return 1;
    			}
			for( int bb = 0; bb < 8; bb++ ) {
				printf("%02X", buf[bb] );
			}
			printf(" ");
		}
		printf("\n");
	}

    close(fd);
    return 0;
}

