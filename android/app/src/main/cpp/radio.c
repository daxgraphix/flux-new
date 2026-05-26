#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <linux/videodev2.h>
#include <stdint.h>

// Define radio device path
#define RADIO_DEVICE "/dev/radio0"

// Function to open radio device
int open_radio() {
    int fd = open(RADIO_DEVICE, O_RDWR);
    if (fd < 0) {
        perror("Failed to open radio device");
        return -1;
    }
    return fd;
}

// Function to close radio device
void close_radio(int fd) {
    close(fd);
}

// Function to get capabilities
int get_capabilities(int fd, struct v4l2_capability *cap) {
    return ioctl(fd, VIDIOC_QUERYCAP, cap);
}

// Function to get tuner info
int get_tuner(int fd, struct v4l2_tuner *tuner) {
    tuner->index = 0;
    return ioctl(fd, VIDIOC_G_TUNER, tuner);
}

// Function to set tuner
int set_tuner(int fd, struct v4l2_tuner *tuner) {
    tuner->index = 0;
    return ioctl(fd, VIDIOC_S_TUNER, tuner);
}

// Function to get frequency
int get_frequency(int fd, struct v4l2_frequency *freq) {
    freq->tuner = 0;
    return ioctl(fd, VIDIOC_G_FREQUENCY, freq);
}

// Function to set frequency
int set_frequency(int fd, struct v4l2_frequency *freq) {
    freq->tuner = 0;
    return ioctl(fd, VIDIOC_S_FREQUENCY, freq);
}

// Function to start hardware seek
int hw_seek(int fd, struct v4l2_hw_freq_seek *seek) {
    seek->tuner = 0;
    return ioctl(fd, VIDIOC_S_HW_FREQ_SEEK, seek);
}

// Function to get audio control
int get_audio(int fd, struct v4l2_audio *audio) {
    return ioctl(fd, VIDIOC_G_AUDIO, audio);
}

// Function to set audio control (for mute)
int set_audio(int fd, struct v4l2_audio *audio) {
    return ioctl(fd, VIDIOC_S_AUDIO, audio);
}