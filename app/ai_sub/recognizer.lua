sub_recognizer = {
    _whisper_path = env.app_path .. '/whisper/main.exe',
    _cuda_whisper_path = env.app_path .. '/whisper/cuda/main.exe',
    _ffmpeg_path = env.app_path .. '/../../../ffmpeg.exe',
    _vad_path = env.app_path .. '/vad/SileroVAD.exe',
    _vad_model_path = env.app_path .. '/vad/silero_vad.onnx',
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
    if kiko.dir.exists(output_file) then
        os.remove(string.encode(output_file, string.CODE_UTF8 ,string.CODE_LOCAL))
    end
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
    local params = {"-i", input_file, "-vn", "-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le", "-f", "wav",  output_file}
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
    srt_file = string.encode(srt_file, string.CODE_UTF8 ,string.CODE_LOCAL)
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

function sub_recognizer:load_timestamp(ts_file)
    local res = {}
    local time_reg = kiko.regex("(\\d+),(\\d+)")
    ts_file = string.encode(ts_file, string.CODE_UTF8 ,string.CODE_LOCAL)
    local new_offset = 0.0
    for line in io.lines(ts_file) do
        local content = string.trim(line)
        local _, _, s, e = time_reg:find(content)
        if s ~= nil and e ~= nil then
            local start_t = tonumber(s)
            local end_t = tonumber(e)
            local offset_end = new_offset + (end_t - start_t)
            table.insert(res, {start_t / 16.0, end_t/ 16.0, new_offset / 16.0, offset_end / 16.0})
            new_offset = offset_end
        end
    end
    return res
end

function sub_recognizer:run_vad(input_wav, options)
    self._cur_msg_callback("开始执行VAD检测...")
    local output_wav_file = self:_get_temp_file_path(input_wav)
    local timestamp_file = self:_get_temp_file_path("timestamp.txt")
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
    local params = {
        "-m", self._vad_model_path, 
        "-f", input_wav, 
        "-t", options.vad_thres, 
        "--timestamp", timestamp_file, 
        "--speech-chunk", output_wav_file,
        "--min_silence", options.vad_min_silence,
        "--min_speech", options.vad_min_speech,
    }
    p:start(self._vad_path, params)
    p:waitfinish()
    local exit_code, exit_status = p:exitstate()
    if exit_code == 0 then
        local timestamp = self:load_timestamp(timestamp_file)
        os.remove(string.encode(timestamp_file, string.CODE_UTF8 ,string.CODE_LOCAL))
        return output_wav_file, timestamp
    else
        return nil, nil
    end
end

function sub_recognizer:adjust_sub_list(sub_list, timestamps)
    local time_reg = kiko.regex("(\\d+):(\\d+):(\\d+).(\\d+)")
    local get_ts_ms = function(time_str)
        local t, e, hh, mm, ss, ms = time_reg:find(time_str)
        if t ~= nil and e ~= nil then
            return tonumber(hh)*3600*1000+tonumber(mm)*60*1000+tonumber(ss)*1000+tonumber(ms)
        end
        return nil
    end
    local encode_ts = function(ts_ms)
        ts_ms = math.modf(ts_ms)
        local ms = ts_ms % 1000
        local hh = ts_ms // 1000 // 3600
        local mm = (ts_ms // 1000 - hh * 3600) // 60
        local ss = ts_ms // 1000 - hh * 3600 - mm * 60
        return string.format("%02d:%02d:%02d,%d", hh, mm, ss, ms)

    end
    for i = 1, #sub_list do
        local raw_start_ms, raw_end_ms = get_ts_ms(sub_list[i].time_start), get_ts_ms(sub_list[i].time_end)
        local new_start_ms, new_end_ms = raw_start_ms, raw_end_ms
        if raw_start_ms ~= nil and raw_end_ms ~= nil then
            for _, ts in ipairs(timestamps) do
                local offset_s, offset_e = ts[3], ts[4]
                if raw_start_ms >= offset_s and raw_start_ms < offset_e then
                    new_start_ms = new_start_ms - offset_s + ts[1]
                    new_end_ms = new_end_ms - offset_s + ts[1]
                    sub_list[i].time_start = encode_ts(new_start_ms)
                    sub_list[i].time_end = encode_ts(new_end_ms)
                    break
                end
            end
        end
    end
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
    if whisper_options.use_vad and (not kiko.dir.exists(self._vad_path) or not kiko.dir.exists(self._vad_model_path)) then
        msg_callback(self:_format_error("SileroVAD.exe或模型文件不存在", self._vad_path .. ", " .. self._vad_model_path))
        return nil
    end
    self._cur_msg_callback = msg_callback
    local wav_file = self:wav_convert(input_file)
    if wav_file == nil then
        msg_callback(self:_format_error("wav音频提取失败", "查看ffmpeg日志确认原因"))
        return nil
    end
    local seg_timestamps = nil
    if whisper_options.use_vad then
        local seg_wav_file, sg_ts = self:run_vad(wav_file, whisper_options)
        os.remove(string.encode(wav_file, string.CODE_UTF8 ,string.CODE_LOCAL))
        if seg_wav_file == nil or sg_ts == nil then
            msg_callback(self:_format_error("VAD检测失败：", "查看日志确认原因"))
            return nil
        end
        wav_file = seg_wav_file
        seg_timestamps = sg_ts
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
            if whisper_options.use_vad then
                self:adjust_sub_list(sub_list, seg_timestamps)
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
