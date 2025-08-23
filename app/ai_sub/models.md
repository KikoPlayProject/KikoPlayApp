## Whisper模型


KikoPlay 2.0默认携带了base版本模型，如果追求更好的识别效果，可以手动下载其他尺寸更大的模型，放到`extension\sub_recognizer\model`目录下



| Model               | Size    | 下载地址                                    |
| ------------------- | ------- | ------------------------------------------ |
| tiny                | 75 MiB  | [魔塔](https://www.modelscope.cn/models/cjc1887415157/whisper.cpp/resolve/master/ggml-tiny.bin)  [huggingface](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin?download=true) |
| tiny.en             | 75 MiB  | [魔塔](https://www.modelscope.cn/models/cjc1887415157/whisper.cpp/resolve/master/ggml-tiny.en.bin)  [huggingface](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin?download=true) |
| base                | 142 MiB | [魔塔](https://www.modelscope.cn/models/cjc1887415157/whisper.cpp/resolve/master/ggml-base.bin)  [huggingface](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin?download=true) |
| base.en             | 142 MiB | [魔塔](https://www.modelscope.cn/models/cjc1887415157/whisper.cpp/resolve/master/ggml-base.en.bin)  [huggingface](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin?download=true) |
| small               | 466 MiB | [魔塔](https://www.modelscope.cn/models/cjc1887415157/whisper.cpp/resolve/master/ggml-small.bin)  [huggingface](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin?download=true) |
| small.en            | 466 MiB | [魔塔](https://www.modelscope.cn/models/cjc1887415157/whisper.cpp/resolve/master/ggml-small.en.bin)  [huggingface](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin?download=true) |
| medium              | 1.5 GiB | [魔塔](https://www.modelscope.cn/models/cjc1887415157/whisper.cpp/resolve/master/ggml-medium.bin)  [huggingface](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin?download=true) |
| medium.en           | 1.5 GiB | [魔塔](https://www.modelscope.cn/models/cjc1887415157/whisper.cpp/resolve/master/ggml-medium.en.bin)  [huggingface](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin?download=true) |
| large-v1            | 2.9 GiB | [魔塔](https://www.modelscope.cn/models/cjc1887415157/whisper.cpp/resolve/master/ggml-large-v1.bin)  [huggingface](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v1.bin?download=true) |
| large-v2            | 2.9 GiB | [魔塔](https://www.modelscope.cn/models/cjc1887415157/whisper.cpp/resolve/master/ggml-large-v2.bin)  [huggingface](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v2.bin?download=true) |
| large-v2-q5_0       | 1.1 GiB | [魔塔](https://www.modelscope.cn/models/cjc1887415157/whisper.cpp/resolve/master/ggml-large-v2-q5_0.bin)  [huggingface](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v2-q5_0.bin?download=true) |
| large-v3            | 2.9 GiB | [魔塔](https://www.modelscope.cn/models/cjc1887415157/whisper.cpp/resolve/master/ggml-large-v3.bin)  [huggingface](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin?download=true) |
| large-v3-q5_0       | 1.1 GiB | [魔塔](https://www.modelscope.cn/models/cjc1887415157/whisper.cpp/resolve/master/ggml-large-v3-q5_0.bin)  [huggingface](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-q5_0.bin?download=true) |
| large-v3-turbo      | 1.5 GiB | [魔塔](https://www.modelscope.cn/models/OllmOne/whisper.cpp/resolve/master/ggml-large-v3-turbo.bin)  [huggingface](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin?download=true) |
| large-v3-turbo-q5_0 | 547 MiB | [魔塔](https://www.modelscope.cn/models/OllmOne/whisper.cpp/resolve/master/ggml-large-v3-turbo-q5_0.bin)  [huggingface](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin?download=true) |