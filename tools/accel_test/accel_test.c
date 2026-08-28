// vim: ts=4:
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/i2c-dev.h>

//
// ACCEL I2C ADDRESS
// You said upper 7 bits = 0x15
// So Linux uses 0x15 directly.
//
#define ACCEL_ADDR 0x15

// Example register map — adjust to your actual accel
#define REG_WHOAMI   0x0F
#define REG_X_L      0x04
#define REG_X_H      0x03
#define REG_Y_L      0x06
#define REG_Y_H      0x05
#define REG_Z_L      0x08
#define REG_Z_H      0x07

// Read one register
int i2c_read_reg(int fd, uint8_t reg)
{
    if (write(fd, &reg, 1) != 1)
        return -1;

    uint8_t val;
    if (read(fd, &val, 1) != 1)
        return -1;

    return val;
}

// Read 16‑bit signed value (low then high)
int16_t read_axis(int fd, uint8_t reg_low)
{
    int lo = i2c_read_reg(fd, reg_low);
    int hi = i2c_read_reg(fd, reg_low - 1);

    if (lo < 0 || hi < 0)
        return 0;

    return (int16_t)((hi << 8) | lo);
}

int main(void)
{
    const char *dev = "/dev/i2c-1";
    int fd = open(dev, O_RDWR);
    if (fd < 0) {
        perror("open");
        return 1;
    }

    if (ioctl(fd, I2C_SLAVE, ACCEL_ADDR) < 0) {
        perror("ioctl");
        return 1;
    }

    // WHOAMI test
    int who = i2c_read_reg(fd, REG_WHOAMI);
    if (who < 0) {
        printf("WHOAMI read failed\n");
    } else {
        printf("WHOAMI = 0x%02X\n", who);
    }

    printf("Reading XYZ continuously...\n");

    while (1) {
        int16_t x = read_axis(fd, REG_X_L);
        int16_t y = read_axis(fd, REG_Y_L);
        int16_t z = read_axis(fd, REG_Z_L);
	x /= 16;
	y /= 16;
	z /= 16;

        printf("X=%6d  Y=%6d  Z=%6d\n", x, y, z);
        usleep(100000); // 100 ms
    }

    close(fd);
    return 0;
}

