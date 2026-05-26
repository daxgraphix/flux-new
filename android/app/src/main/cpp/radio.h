#ifndef RADIO_H
#define RADIO_H

#include <linux/videodev2.h>

#ifdef __cplusplus
extern "C" {
#endif

int open_radio();
void close_radio(int fd);
int get_capabilities(int fd, struct v4l2_capability *cap);
int get_tuner(int fd, struct v4l2_tuner *tuner);
int set_tuner(int fd, struct v4l2_tuner *tuner);
int get_frequency(int fd, struct v4l2_frequency *freq);
int set_frequency(int fd, struct v4l2_frequency *freq);
int hw_seek(int fd, struct v4l2_hw_freq_seek *seek);
int get_audio(int fd, struct v4l2_audio *audio);
int set_audio(int fd, struct v4l2_audio *audio);

#ifdef __cplusplus
}
#endif

#endif