/* SPDX-License-Identifier: GPL-2.0-or-later */
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>

#include <sys/ioctl.h>

#ifndef TIOCSETD
#define TIOCSETD 0x5423
#endif

#ifndef HCIUARTSETPROTO
#define HCIUARTSETPROTO 0x400455C8
#endif

#define N_HCI 15
#define HCI_UART_BCM 7
#define BT_TTY "/dev/ttyS6"

static int configure_tty(int fd)
{
	struct termios tty;

	if (tcgetattr(fd, &tty) < 0)
		return -errno;

	tty.c_cflag &= ~(CSIZE | PARENB | CSTOPB | CRTSCTS);
	tty.c_cflag |= CS8 | CLOCAL | CREAD;
	tty.c_iflag = 0;
	tty.c_oflag = 0;
	tty.c_lflag = 0;
	tty.c_cc[VMIN] = 1;
	tty.c_cc[VTIME] = 0;

	if (cfsetispeed(&tty, B115200) < 0 ||
	    cfsetospeed(&tty, B115200) < 0)
		return -errno;
	if (tcsetattr(fd, TCSANOW, &tty) < 0)
		return -errno;

	return 0;
}

int main(void)
{
	const int sleep_seconds = 2;
	int fd, ldisc = N_HCI, protocol = HCI_UART_BCM, i;

	for (i = 0; i < 60; i++) {
		fd = open(BT_TTY, O_RDWR | O_NOCTTY);
		if (fd >= 0)
			break;
		if (sleep(sleep_seconds) != 0)
			return 1;
	}
	if (fd < 0) {
		fprintf(stderr, "failed to open %s: %s\n", BT_TTY,
			strerror(errno));
		return 1;
	}

	int ret = configure_tty(fd);
	if (ret < 0) {
		fprintf(stderr, "failed to configure %s: %s\n", BT_TTY,
			strerror(-ret));
		close(fd);
		return 1;
	}
	if (ioctl(fd, TIOCSETD, &ldisc) < 0 ||
	    ioctl(fd, HCIUARTSETPROTO, protocol) < 0) {
		fprintf(stderr, "failed to attach HCI UART BCM: %s\n",
			strerror(errno));
		close(fd);
		return 1;
	}

	fprintf(stderr, "HCI UART BCM attached on %s\n", BT_TTY);
	for (;;)
		pause();
}
