sub_recognizer = {
    _whisper_path = env.app_path .. '/whisper/main.exe',
    _cuda_whisper_path = env.app_path .. '/whisper/cuda/main.exe',
    _ffmpeg_path = env.app_path .. '/../../../ffmpeg.exe',
    _tmp_counter = 0,
    _cur_msg_callback = nil,
}

function sub_recognizer:_get_temp_file_path(src_file)
    local tmp_path = env.data_path
    local pos = string.lastindexof(src_file, "/")
    if pos == -1 then
        pos = string.lastindexof(src_file, "\\")
    end
    self._tmp_counter = self._tmp_counter + 1
    if pos == -1 then
        return tmp_path .. "/tmp_file_" .. tostring(self._tmp_counter)
    end
    return tmp_path .. "/" .. string.sub(src_file, pos+1) .. "_tmp_" .. tostring(self._tmp_counter)
end

function sub_recognizer:wav_convert(input_file)        
    self._cur_msg_callback("开始提取音频...")
    local output_file = self:_get_temp_file_path(input_file)
    local p = kiko.process.create()
    p:onevent({
        readready = function(channel)
            local msg = ""
            if channel == 1 then
                local err = string.trim(p:readerror())
                msg = string.encode(err, string.CODE_LOCAL, string.CODE_UTF8)
            else
                local output = string.trim(p:readoutput())
                msg = string.encode(output, string.CODE_LOCAL, string.CODE_UTF8)
            end
            self._cur_msg_callback(msg)
        end,
    })
    local params = {"-i", input_file, "-vn", "-ar", "16000", "-f", "wav",  output_file}
    p:start(self._ffmpeg_path, params)
    p:waitfinish()
    local exit_code, exit_status = p:exitstate()
    if exit_code == 0 then
        return output_file
    else
        return nil
    end
end

function sub_recognizer:load_srt(srt_file)
    local res = {}
    local cur_time_start, cur_time_end, cur_content = nil, nil, ""
    local status = 0  -- 0: begin, 1: index 2: time parsed, 3: content
    local time_reg = kiko.regex("(\\d+:\\d+:\\d+.\\d+)\\s+-->\\s+(\\d+:\\d+:\\d+.\\d+)")
    for line in io.lines(srt_file) do
        local content = string.trim(line)
        if #content == 0 then
            if status == 3 then
                table.insert(res, {
                    time_start = cur_time_start,
                    time_end = cur_time_end,
                    content = cur_content,
                })
                cur_time_start, cur_time_end, cur_content = nil, nil, ""
                status = 0
            end
        else
            if status == 0 then
                status = 1
            elseif status == 1 then
                local _, _, s, e = time_reg:find(content)
                if s ~= nil and e ~= nil then
                    cur_time_start, cur_time_end = s, e
                    status = 2
                end
            elseif status == 2 then
                cur_content = content
                status = 3
            elseif status == 3 then
                cur_content = cur_content .. "\n" .. content
            end
        end
    end
    return res
end

function sub_recognizer:_format_error(title, err)
    return string.format('<span style="color:#f10000">%s: </span> %s', title, err)
end

function sub_recognizer:recognize(input_file, whisper_options, msg_callback, finish_callback)
    local model = whisper_options.model
    if model == nil then
        msg_callback(self:_format_error("请在设置中指定whisper模型文件", ".bin模型文件"))
        return nil
    end
    if not kiko.dir.exists(model) then
        msg_callback(self:_format_error("模型文件不存在", model))
        return nil
    end
    if not kiko.dir.exists(self._ffmpeg_path) then
        msg_callback(self:_format_error("ffmpeg不存在", self._ffmpeg_path))
        return nil
    end
    self._cur_msg_callback = msg_callback
    local wav_file = self:wav_convert(input_file)
    if wav_file == nil then
        msg_callback(self:_format_error("wav音频提取失败", "查看ffmpeg日志确认原因"))
        return nil
    end

    local p = kiko.process.create()
    local srt_file = self:_get_temp_file_path(wav_file)
    p:onevent({
        readready = function(channel)
            local msg = ""
            if channel == 1 then
                local err = string.trim(p:readerror())
                msg = string.encode(err, string.CODE_LOCAL, string.CODE_UTF8)
            else
                local output = string.trim(p:readoutput())
                msg = string.encode(output, string.CODE_LOCAL, string.CODE_UTF8)
            end
            self._cur_msg_callback(msg)
        end,
        finished = function(exit_code, exit_status)  -- 进程结束回调
            -- exit_status： 0 正常  1 崩溃
            local sub_list = {}
            if exit_status ~= 0 then
                self._cur_msg_callback(self:_format_error("whisper进程异常", "exit_code=" .. tostring(exit_code)))
            else
                sub_list = self:load_srt(srt_file .. ".srt")
            end
            os.remove(string.encode(wav_file, string.CODE_UTF8 ,string.CODE_LOCAL))
            os.remove(string.encode(srt_file .. ".srt", string.CODE_UTF8 ,string.CODE_LOCAL))
            finish_callback(sub_list)
        end,
    })
    local lang = "auto"
    if whisper_options.lang ~= nil then
        lang = whisper_options.lang
    end
    local params = {"-m", model, "-l", lang, "-f", wav_file, "-osrt", "true", "-of", srt_file}
    local whisper_path = self._whisper_path
    if whisper_options.use_cuda then
        whisper_path = self._cuda_whisper_path
    end
    self._cur_msg_callback("开始识别..." .. whisper_path)
    p:start(whisper_path, params)
end

return sub_recognizer
