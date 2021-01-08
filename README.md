# FFmpeg for Android AssetFileDescriptor

[English](README_EN.md)

我发现在将Android中的AssetFileDescriptor传递到FFmpeg中并不能正常的读取和编码（mov格式），我尝试使用file协议或pipe协议，但是都存在问题。在stackoverflow上也有类似的问题，但是并没有一个完美的解决方案，所以我尝试阅读源码来解决这个问题。

[How to properly pass an asset FileDescriptor to FFmpeg using JNI in Android](https://stackoverflow.com/questions/24701029/how-to-properly-pass-an-asset-filedescriptor-to-ffmpeg-using-jni-in-android)

最后，我认为这可能是一个bug，avformat_open_Input虽然内部调用了avio_skip函数来跳过指定的skip_initial_bytes，但是当调用av_read_fram函数读取数据时并没有跳过我们指定的skip_initial_ bytes。

### 修复

这只是我的解决方案，如果你有更好的方案，欢迎分享

当前修改的版本是基于4.3.1，其他版本也可能存在同样的问题

* `libavformat/avio.h`

  在`AVIOContext`中添加`skip_initial_bytes`变量，用于向`mov.c`传递`skip_initial_bytes`

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

  在调用了`init_input`函数后，将`AVFormatContext`中的`skip_initial_bytes`赋值给`AVIOContext`中的`skip_initial_bytes`，因为在调用了`init_input`函数后`AVIOContext`才被创建

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

  函数`mov_build_index`参数列表添加`skip_initial_bytes`，在遍历stsc（[Sample-to-Chunk Atoms](https://developer.apple.com/library/archive/documentation/QuickTime/QTFF/QTFFChap2/qtff2.html)）数据时加上`skip_initial_bytes`

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

  通过`mov_read_trak(...)` 函数向`mov_build_index`传递`skip_initial_bytes`

  ```c
  static int mov_read_trak(MOVContext *c, AVIOContext *pb, MOVAtom atom) {
      ...
      //mov_build_index(c, st);
      mov_build_index(c, st, pb->skip_initial_bytes);
      ...
  }
  ```

具体修改可见[755fd0165f61fd779f6601adb4ef2c1605545561](https://github.com/YiChaoLove/FFmpegForAndroidAssetFileDescriptor/commit/755fd0165f61fd779f6601adb4ef2c1605545561)提交

### 编译

你可以使用你自己的编译脚本或者我提供的脚本进行编译，如果你使用`ffmpeg_build_android.sh`脚本进行编译需要修改 NDK的路径和HOST_TAG

```c
HOST_TAG=[mac: darwin-x86_64, linux: linux-x86_64]
NDK=[your-ndk-path]
```

更多有关Android交叉编译的信息可以参考[Use the NDK with other build systems](https://developer.android.com/ndk/guides/other_build_systems).

### 使用

编译后可以正常使用，但是如果你想要用于生产环境，请先经过充分的测试。这里有一个基于WhatTheCodec的demo，基于WhatTheCodec基础之上我还修复了一些其他的问题，以及演示了如何在FFmpeg中使用pipe协议。

感谢 WhatTheCodec: https://github.com/Javernaut/WhatTheCodec

我的Demo:  https://github.com/YiChaoLove/WhatTheCodec

