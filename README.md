FFmpeg for Android AssetFileDescriptor
=============

I found that passing the android assets file descriptor(mp4) to ffmpeg does not work properly. I have tried the
pipe protocol and file protocol, but none of them worked. There are similar problems on stackoverflow, but
there is no perfect solution, so I try to read the source code to solve this problem.

[How to properly pass an asset FileDescriptor to FFmpeg using JNI in Android](https://stackoverflow.com/questions/24701029/how-to-properly-pass-an-asset-filedescriptor-to-ffmpeg-using-jni-in-android)

In the end, I think this is a bug of ffmpeg. When we call the ``avformat_open_input(...)`` function
after passing the ``skip_initial_bytes`` parameter to ``AVFormatContext``, ``avformat_open_input(...)``
will call the `avio_skip(...)` function to skip the specified number of bytes, but when calling
``av_read_frame(...)``, ``mov_read_packet(...)`` does not skip the specified the number of bytes (offset),
so we can successfully call ``avformat_open_input(...)`` and ``avformat_find_stream_info(...)`` to
obtain the information of the media file, but call ``av_read_frame(...)`` can not correctly obtain the
unencapsulated data.

## FIX
This is just my solution, if you have a better solution, welcome to share. 

The current modification is based on version 4.3.1, other versions may have the same problem.

* `libavformat/avio.h` 
  
  Add `skip_initial_bytes` in `AVIOContext`, we pass `skip_initial_bytes` to `mov.c` through AVIOContext.

```c
typedef struct AVIOContext {
    ...
    /**
     * Fix mov.h mov_build_index(...) function
     * Skip initial bytes when opening stream
     * - encoding: unused
     * - decoding: Set by user
     */
    int64_t skip_initial_bytes;
} AVIOContext;
```
  
* `libavformat/utils.c`  
  
  Assign `skip_initial_bytes` to `AVIOContext` after `init_input()`. `init_input()` will find 
  the file protocol of the url and create an `AVIOContext`.
  
```c
    ...
    if ((ret = init_input(s, filename, &tmp)) < 0)
        goto fail;
    s->probe_score = ret;
    //fix mov.h mov_build_index(...) function
    if (s->pb) {
        s->pb->skip_initial_bytes = s->skip_initial_bytes;
    }
    ...
```
* `libavformat/mov.c`

  `mov_build_index(...)` adds `skip_initial_bytes` parameter. When traversing stsc([Sample-to-Chunk Atoms](https://developer.apple.com/library/archive/documentation/QuickTime/QTFF/QTFFChap2/qtff2.html)),
  we add the corresponding skip_initial_bytes.
  
```c
//static void mov_build_index(MOVContext *mov, AVStream *st){
static void mov_build_index(MOVContext *mov, AVStream *st, int64_t skip_initial_bytes){
    ...
        ...
        //e->pos = current_offset;
        e->pos = current_offset + skip_initial_bytes;
        ...
    ...
}
```
  
* `libavformat/mov.c`
  
  `mov_read_trak(...)` function.

```c
static int mov_read_trak(MOVContext *c, AVIOContext *pb, MOVAtom atom) {
    ...
    //mov_build_index(c, st);
    mov_build_index(c, st, pb->skip_initial_bytes);
    ...
}
```


## Build

You can use your own compilation script or my compilation script to compile, 
if you use `ffmpeg_build_android.sh`, you need to modify the NDK path and HOST_TAG variable.

```c
HOST_TAG=[mac: darwin-x86_64, linux: linux-x86_64]
NDK=[your-ndk-path]
```
For more detailed information, you can refer to [Use the NDK with other build systems](https://developer.android.com/ndk/guides/other_build_systems).

## Usage

After compilation, you can use it directly in your project. If you want to use it in a 
production environment, please test it first. Here is a demo based on WhatTheCodec 
(I think WhatTheCodec is a very good project). On the basis of WhatTheCodec, I fixed 
some problems and demonstrated how to use the pipe protocol in Android to pass media data to ffmpeg.

Thanks Javernaut, WhatTheCodec: https://github.com/Javernaut/WhatTheCodec

My Demo: https://github.com/YiChaoLove/WhatTheCodec




