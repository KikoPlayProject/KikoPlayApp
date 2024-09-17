## KikoPlay AI字幕扩展

识别依赖[whisper.cpp](https://github.com/ggerganov/whisper.cpp)，翻译功能需要提供chatgpt api key

windows：开启cuda加速需安装cuda

linux：需要自行编译[whisper.cpp](https://github.com/ggerganov/whisper.cpp)，修改recognizer.lua中的_whisper_path、_cuda_whisper_path以及_ffmpeg_path，确保指向正确的位置