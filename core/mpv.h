#ifndef WALLPAPER_MPV_H
#define WALLPAPER_MPV_H

#include "wallpaper.h"

#define WP_MPV_OPTION_MAX (WP_PATH_MAX + 64)
#define WP_MPV_OPTIONS_MAX 48
#define WP_MPV_COMMAND_MAX (WP_PATH_MAX * 2 + 256)

typedef enum { WP_MPV_LINUX, WP_MPV_WINDOWS } wp_mpv_platform;

typedef struct {
    char items[WP_MPV_OPTIONS_MAX][WP_MPV_OPTION_MAX];
    int count;
} wp_mpv_options;

void wp_mpv_build_options(wp_mpv_options *options, wp_mpv_platform platform, wp_fit fit,
                          double rate, bool paused, const char *ipc, const char *window);
void wp_mpv_encode_options(wp_mpv_options *options, wp_tier target, const char *output);
size_t wp_mpv_command(char *out, size_t size, int request_id, const char *const *argv, int argc);
size_t wp_mpv_set(char *out, size_t size, const char *property, const char *value);
#define WP_MPV_CONCAT_HEADER "ffconcat version 1.0\n"
#define WP_MPV_CONCAT_FORMAT "demuxer-lavf-format=concat"

typedef size_t (*wp_read_fn)(void *context, uint64_t offset, void *buffer, size_t size);
typedef bool (*wp_write_fn)(void *context, const char *data, size_t size);

size_t wp_mpv_loadfile(char *out, size_t size, const char *path, double start, int version, bool concat);
int wp_mpv_concat_write(wp_write_fn write, void *context, const char *path, double duration);
double wp_mp4_duration(wp_read_fn read, void *context, uint64_t length);
int wp_mpv_version(const char *text);
bool wp_json_number(const char *json, const char *key, double *out);
bool wp_json_string(const char *json, const char *key, char *out, size_t size);

#endif
