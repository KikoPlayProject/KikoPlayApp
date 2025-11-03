app = {}

-- 播放状态
app.playing = false
app.current_index = 0
app.playlist = {}
app.volume = 50
app.is_muted = false
app.playlist_dirty = false  -- 播放列表是否有更新
app.is_seeking = false  -- 是否正在拖动进度条
app.file_loaded = false  -- 当前是否有文件已加载到播放器
app.last_playing_index = 0  -- 上一个播放的索引，用于优化播放标记更新

-- 循环模式：1-列表顺序，2-列表循环，3-列表随机，4-单曲循环
app.loop_mode = 2  -- 默认列表循环
app.shuffle_history = {}  -- 随机播放历史

-- 歌词相关状态
app.current_lyrics = {}  -- 当前歌曲的歌词数据 {time, text} 数组
app.current_lyric_index = 0  -- 当前播放到的歌词行索引
app.lyrics_available = false  -- 是否有可用歌词

-- 播放进度更新定时器
app.progress_timer = nil  -- 播放进度更新定时器

-- 专辑封面缓存
app.album_cover_cache = {}
app.album_cover_cache_size = 0
app.album_cover_cache_max_size = 20  -- 最多缓存20个封面

-- UI元素缓存（避免重复的kiko.ui.get调用）
app.ui = {}
app.ui.playlist_tree = nil
app.ui.song_title = nil
app.ui.song_artist = nil
app.ui.song_album = nil
app.ui.album_cover = nil
app.ui.lyrics_text = nil
app.ui.btn_play_pause = nil
app.ui.status_label = nil
app.ui.progress_slider = nil
app.ui.current_time = nil
app.ui.total_time = nil
app.ui.music_player = nil
app.ui.volume_slider = nil
app.ui.volume_label = nil
app.ui.btn_mute = nil
app.ui.loop_mode = nil

-- HTML转义函数，防止歌词中的特殊字符导致显示问题
local function escape_html(text)
    if not text then return "" end
    return text:gsub("&", "&amp;")
                 :gsub("<", "&lt;")
                 :gsub(">", "&gt;")
                 :gsub("\"", "&quot;")
                 :gsub("'", "&#39;")
end

-- 保存播放列表到kiko.storage
local function save_playlist()
    local playlist_data = {
        version = "1.0",
        songs = app.playlist,
    }
    
    kiko.storage.set("music_player_playlist", playlist_data)
    app.playlist_dirty = false  -- 清除更新标记
    return true
end

local function format_time(seconds)
    if not seconds or seconds <= 0 then
        return "00:00"
    end
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d:%02d", mins, secs)
end

local function get_song_display_title(song, is_current)
    local display_title = song.title or "未知标题"
    if song.artist and song.artist ~= "未知艺术家" and song.artist ~= "" then
        display_title = song.artist .. " - " .. (song.title or "未知标题")
    end

    if song.duration and song.duration > 0 then
        display_title = "[" .. (format_time(song.duration) or "00:00") .. "] " .. display_title
    end
    
    if is_current then
        display_title = "🎧 " .. display_title
    end

    return display_title
end

-- 循环模式切换
app.onLoopModeChanged = function(param)
    local index = param["index"]
    if index and index > 0 and index <= 4 then
        app.loop_mode = index  -- 转换为1-4的模式值
        
        -- 更新循环模式下拉框的标题以反映当前模式
        local mode_names = {"列表顺序", "列表循环", "列表随机", "单曲循环"}
        app.ui.loop_mode:setopt("title", mode_names[app.loop_mode])
        
        -- 保存循环模式设置
        kiko.storage.set("music_player_loop_mode", app.loop_mode)
        
        -- 调试日志
        kiko.log("循环模式切换到: " .. mode_names[app.loop_mode] .. " (模式 " .. app.loop_mode .. ")")
    end
end

-- 从kiko.storage加载播放列表
local function load_playlist()
    local playlist_data = kiko.storage.get("music_player_playlist")
    if not playlist_data or not playlist_data.songs then
        return false
    end
    
    -- 直接加载所有歌曲，无需验证文件是否存在
    app.playlist = playlist_data.songs
    
    if app.current_index == 0 or app.current_index > #app.playlist then
        app.current_index = 0
    end
    
    return #app.playlist > 0
end

-- 解析LRC歌词文件
local function parse_lrc_lyrics(lrc_content)
    local lyrics = {}
    if not lrc_content or lrc_content == "" then
        return lyrics
    end
    
    -- kiko.log("开始解析LRC歌词, 内容长度: " .. #lrc_content)
    
    -- 按行分割歌词内容
    for line in lrc_content:gmatch("[^\r\n]+") do
        -- kiko.log("解析LRC行: " .. line)
        
        -- 匹配时间标签 [mm:ss.xx] 或 [mm:ss]
        local minutes, seconds, text = line:match("%[(%d+):([%d%.]+)%](.*)")
        if minutes and seconds then
            local minutes_num = tonumber(minutes)
            local seconds_num = tonumber(seconds)
            if minutes_num and seconds_num then
                local time = minutes_num * 60 + seconds_num
                text = text:gsub("^%s*", ""):gsub("%s*$", "") -- 去除首尾空格
                if text ~= "" then
                    table.insert(lyrics, {time = time, text = text})
                end
            else
                kiko.log("解析时间失败: minutes=" .. tostring(minutes) .. ", seconds=" .. tostring(seconds))
            end
        else
            --kiko.log("未匹配到时间标签: " .. line)
        end
    end
    
    -- 按时间排序
    table.sort(lyrics, function(a, b) return a.time < b.time end)
    -- kiko.log("解析完成，共" .. #lyrics .. "行歌词")
    return lyrics
end

-- 从音频文件中获取内嵌歌词
local function get_embedded_lyrics(filepath)
    local player = app.player
    if not player then
        return nil
    end
    
    -- 尝试获取内嵌歌词元数据
    local err_code, content = player:property("metadata/lyrics")
    if err_code == 0 and content and content ~= "" then
        -- kiko.log("成功获取内嵌歌词，内容长度: " .. #content)
        local parsed_lyrics = parse_lrc_lyrics(content)
        -- kiko.log("解析后歌词行数: " .. #parsed_lyrics)
        if #parsed_lyrics > 0 then
            return parsed_lyrics
        end
    end

    -- 尝试其他可能的歌词元数据字段
    local lyric_fields = {"lyrics", "LYRICS", "Lyrics", "unsynced-lyrics", "synced-lyrics", "lyrics-XXX"}
    for _, field in ipairs(lyric_fields) do
        local property = "metadata/" .. field
        local err_code, content = player:property(property)
        -- kiko.log("尝试获取歌词字段 " .. property .. ": err_code=" .. tostring(err_code) .. ", content=" .. tostring(content))
        if err_code == 0 and content and content ~= "" then
            -- kiko.log("成功获取" .. field .. "字段，内容长度: " .. #content)
            local parsed_lyrics = parse_lrc_lyrics(content)
            -- kiko.log("解析后歌词行数: " .. #parsed_lyrics)
            if #parsed_lyrics > 0 then
                return parsed_lyrics
            end
        end
    end
    
    return nil
end

-- 查找同目录下的.lrc歌词文件
local function find_lrc_file(filepath)
    if not filepath then
        return nil
    end
    
    -- 获取文件目录和基础文件名
    local dir = filepath:match("(.+)[/\\]") or ""
    local basename = filepath:match("([^/\\]+)%.[^.]+$") or filepath:match("([^/\\]+)$")
    
    if not basename then
        return nil
    end
    
    -- 尝试查找同名的.lrc文件
    local lrc_filepath = dir .. "/" .. basename .. ".lrc"
    local file = io.open(lrc_filepath, "r")
    if file then
        local content = file:read("*all")
        file:close()
        if content and content ~= "" then
            return parse_lrc_lyrics(content)
        end
    end
    
    return nil
end

-- 加载歌词
local function load_lyrics(filepath)
    local lyrics = {}
    
    -- 首先尝试获取内嵌歌词
    local embedded_lyrics = get_embedded_lyrics(filepath)
    if embedded_lyrics and #embedded_lyrics > 0 then
        lyrics = embedded_lyrics
        -- kiko.log("使用内嵌歌词，共 " .. #lyrics .. " 行")
    else
        -- 如果没有内嵌歌词，尝试查找.lrc文件
        local lrc_lyrics = find_lrc_file(filepath)
        if lrc_lyrics and #lrc_lyrics > 0 then
            lyrics = lrc_lyrics
            -- kiko.log("使用.lrc文件歌词，共 " .. #lyrics .. " 行")
        else
            -- kiko.log("未找到任何歌词")
        end
    end
    
    return lyrics
end

-- 根据当前播放时间获取当前歌词行
local function get_current_lyric(lyrics, current_time)
    if not lyrics or #lyrics == 0 or not current_time then
        return nil, 0
    end
    
    for i, lyric in ipairs(lyrics) do
        if current_time < lyric.time then
            return i > 1 and lyrics[i-1] or nil, i > 1 and i-1 or 0
        end
    end
    
    -- 如果播放到最后，返回最后一句歌词
    return lyrics[#lyrics], #lyrics
end

-- 格式化显示歌词（使用HTML格式美化显示）
local function format_lyrics_for_display(lyrics, current_index)
    if not lyrics or #lyrics == 0 then
        return "<p style='color: #999; text-align: center; font-size: 14px; margin: 20px 0;'>暂无歌词</p>"
    end
    
    -- 如果当前索引为0，显示所有歌词（初始状态）
    if current_index == 0 then
        local html = "<div style='line-height: 1.8; font-size: 14px; padding: 10px;'>"
        for i = 1, math.min(#lyrics, 12) do -- 显示前12行
            html = html .. "<p style='margin: 4px 0; color: #777; font-family: \"Segoe UI\", Arial, sans-serif; '>" .. escape_html(lyrics[i].text) .. "</p>"
        end
        if #lyrics > 12 then
            html = html .. "<p style='color: #999; font-size: 12px; margin: 8px 0; text-align: center; opacity: 0.8;'>... 还有 " .. (#lyrics - 12) .. " 行歌词 ...</p>"
        end
        return html .. "</div>"
    end
    
    local html = "<div style='line-height: 1.8; font-size: 14px; padding: 10px;'>"
    local start_idx = math.max(1, current_index - 2) -- 显示前2行
    local end_idx = math.min(#lyrics, current_index + 5) -- 显示后5行
    
    for i = start_idx, end_idx do
        local text = escape_html(lyrics[i].text)
        
        if i == current_index then
            -- 当前播放的歌词行，高亮显示 - 使用现代渐变和阴影效果
            html = html .. "<p style='margin: 6px 0; padding: 8px 12px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); "
            html = html .. "color: white; font-weight: 600; border-radius: 8px; font-size: 15px; "
            html = html .. "box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4); text-align: center; "
            html = html .. "transform: scale(1.02); transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);'>"
            html = html .. text .. "</p>"
        else
            -- 其他歌词行 - 根据距离调整透明度和大小
            local distance = math.abs(i - current_index)
            local opacity = 0.5 + 0.5 * (1 - distance / 5) -- 增加基础透明度，距离越远透明度越高
            local font_size = 14 - distance * 0.5 -- 距离越远字体越小
            local margin = 4 - distance * 0.3 -- 距离外边距越小
            
            html = html .. "<p style='margin: " .. margin .. "px 0; color: rgba(120, 120, 120, " .. opacity .. "); "
            html = html .. "font-size: " .. font_size .. "px; padding: 4px 8px; "
            html = html .. "font-family: \"Segoe UI\", Arial, sans-serif; "
            html = html .. "transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);'>" .. text .. "</p>"
        end
    end
    
    return html .. "</div>"
end

-- 添加歌曲到播放列表显示
local function add_song_to_tree(tree, song, index)
    -- 构建要添加的数据（只保留一列）
    local item_data = {
        {
            ["text"] = get_song_display_title(song, index == app.current_index),
            ["data"] = tostring(index)
        }
    }
    tree:append({item_data})
end

-- 更新播放列表指定索引项显示
local function update_item_in_tree(tree, song, index)
    -- 使用item方法获取指定索引的项（Lua风格，索引从1开始）
    local item = tree:item(index)  -- 直接使用传入的索引，符合Lua习惯
    if item then
        item:set(1, "text", get_song_display_title(song, index == app.current_index))
    end
end

-- 更新播放列表显示
local function update_playlist_display()
    local tree = app.ui.playlist_tree
    if not tree then
        return
    end
    
    -- 设置列标题（只保留一列）
    tree:setheader({"播放列表"})
    
    tree:clear()
    
    for i, song in ipairs(app.playlist) do
        add_song_to_tree(tree, song, i)
    end
end

-- 刷新播放列表中当前播放标记（优化版本，只更新需要更新的条目）
local function refresh_playlist_current_marker()
    local tree = app.ui.playlist_tree
    if not tree then
        return
    end
    
    -- 获取上一个播放索引（如果没有则初始化为0）
    local last_index = app.last_playing_index or 0
    
    -- 更新上一个播放的条目（移除播放标记）
    if last_index > 0 and last_index <= #app.playlist and last_index ~= app.current_index then
        local last_item = tree:item(last_index)
        if last_item then
            local song = app.playlist[last_index]
            last_item:set(1, "text", get_song_display_title(song, false))
        end
    end
    
    -- 更新当前播放的条目（添加播放标记）
    if app.current_index > 0 and app.current_index <= #app.playlist then
        local current_item = tree:item(app.current_index)
        if current_item then
            local song = app.playlist[app.current_index]
            current_item:set(1, "text", get_song_display_title(song, true))
        end
        
        -- 设置选中状态
        tree:setopt("current_index", app.current_index)
    end
    
    -- 记录当前索引作为下一次的上一个索引
    app.last_playing_index = app.current_index
end

-- 更新音乐信息显示（不包含专辑封面，只在文件加载完成时显示封面）
local function update_song_info(song)
    if not song then
        app.ui.song_title:setopt("title", "未播放")
        app.ui.song_artist:setopt("title", "艺术家: --")
        app.ui.song_album:setopt("title", "专辑: --")
        -- 使用HTML格式显示"未播放"状态
        local no_song_html = "<p style='color: #999; text-align: center; font-size: 14px; margin: 20px 0; opacity: 0.8;'>♪ 等待播放音乐...</p>"
        app.ui.lyrics_text:clear()  -- 先清空内容
        app.ui.lyrics_text:append(no_song_html, true)  -- 使用append方法添加HTML内容
        app.current_lyrics = {}
        app.current_lyric_index = 0
        app.lyrics_available = false
    
        return
    end
    
    app.ui.song_title:setopt("title", song.title or "未知标题")
    app.ui.song_artist:setopt("title", "艺术家: " .. (song.artist or "未知艺术家"))
    app.ui.song_album:setopt("title", "专辑: " .. (song.album or "未知专辑"))
end

-- 专辑封面获取和显示函数（带缓存机制）
local function get_album_cover(audio_file)
    if not audio_file or audio_file == "" then
        return nil
    end
    
    -- 检查缓存
    if app.album_cover_cache[audio_file] then
        return app.album_cover_cache[audio_file]
    end
    
    -- 1. 首先尝试从音频文件提取内嵌封面（使用ffmpeg）
    local cover_path = nil
    
    -- 获取KikoPlay程序目录（应用目录的上三级）
    local kikoplay_dir = env.app_path .. "/../../.."  -- 上三级目录
    local ffmpeg_path = kikoplay_dir .. "/ffmpeg.exe"
    
    -- 检查ffmpeg是否存在
    if kiko.dir.exists(ffmpeg_path) then
        -- 创建临时目录（使用应用数据目录）
        local temp_dir = env.data_path .. "/temp_covers"
        if not kiko.dir.exists(temp_dir) then
            kiko.dir.mkpath(temp_dir)
        end
        
        -- 生成临时封面文件路径
        local _, hash = kiko.hashdata(audio_file, false)
        local cover_file = temp_dir .. "/cover_" .. hash .. ".jpg"

        if kiko.dir.exists(cover_file) then
            kiko.log("发现已存在的封面文件: " .. cover_file)
            cover_path = cover_file
        else
            -- 使用ffmpeg提取封面（尝试提取第一个视频流作为封面）
            local args = {
                "-i", audio_file,
                "-an",  -- 禁用音频
                "-vcodec", "mjpeg",  -- 转换为JPEG格式
                "-vframes", "1",  -- 只提取一帧
                "-y",  -- 覆盖已存在的文件
                cover_file
            }
            
            local success, err_or_result = pcall(function()
                local err, result = kiko.execute(false, ffmpeg_path, args)
                return err, result
            end)
            
            if success and not err_or_result then
                -- kiko.execute返回的第一个参数是错误信息，nil表示成功
                if kiko.dir.exists(cover_file) then
                    cover_path = cover_file
                    kiko.log("成功使用ffmpeg提取封面: " .. cover_file)
                else
                    kiko.log("ffmpeg执行成功但封面文件未生成")
                end
            else
                kiko.log("ffmpeg提取封面失败: " .. tostring(err_or_result))
            end
        end
    else
        kiko.log("ffmpeg未找到，跳过内嵌封面提取: " .. ffmpeg_path)
    end
    
    -- 2. 如果ffmpeg提取失败，尝试查找同目录下的封面图片文件
    if not cover_path then
        -- 获取音频文件所在目录和基本文件名（不含扩展名）
        local last_slash_pos = audio_file:match(".*()/")
        local dir = last_slash_pos and audio_file:sub(1, last_slash_pos - 1) or "."
        local file_name = last_slash_pos and audio_file:sub(last_slash_pos + 1) or audio_file
        local dot_pos = file_name:match(".*()%.")
        local base_name = dot_pos and file_name:sub(1, dot_pos - 1) or file_name
        
        -- 常见的封面文件名模式
        local cover_patterns = {
            "cover.jpg", "cover.png", "cover.jpeg",
            "folder.jpg", "folder.png", "folder.jpeg",
            "album.jpg", "album.png", "album.jpeg",
            base_name .. ".jpg", base_name .. ".png", base_name .. ".jpeg",
            base_name .. "_cover.jpg", base_name .. "_cover.png",
            "front.jpg", "front.png", "artwork.jpg", "artwork.png"
        }
        
        -- 检查同目录下的封面文件
        for _, pattern in ipairs(cover_patterns) do
            local test_path = dir .. "/" .. pattern
            if kiko.dir.exists(test_path) then
                cover_path = test_path
                break
            end
        end
    end
    
    -- 添加到缓存（LRU策略）
    if app.album_cover_cache_size >= app.album_cover_cache_max_size then
        -- 简单的LRU：删除第一个元素（最老的）
        local oldest_key = nil
        for k, _ in pairs(app.album_cover_cache) do
            oldest_key = k
            break
        end
        if oldest_key then
            os.remove(string.encode(app.album_cover_cache[oldest_key], string.CODE_UTF8 ,string.CODE_LOCAL))
            app.album_cover_cache[oldest_key] = nil
            app.album_cover_cache_size = app.album_cover_cache_size - 1
        end
    end
    
    app.album_cover_cache[audio_file] = cover_path
    app.album_cover_cache_size = app.album_cover_cache_size + 1
    
    return cover_path
end

-- 显示默认音乐图标
local function display_default_album_cover()
    if not app.ui.album_cover then
        return
    end
    
    -- 获取默认封面文件路径
    local default_cover_path = env.app_path .. "/default_cover.svg"
    
    -- 检查默认封面文件是否存在
    if kiko.dir.exists(default_cover_path) then
        -- 如果存在，加载默认封面
        app.ui.album_cover:setimg(default_cover_path)
    else
        -- 如果文件不存在，使用CSS样式显示默认图标
        app.ui.album_cover:setimg(nil)  -- 清空图片源
    end
    
    app.ui.album_cover:setopt("visible", true)
end

local function display_album_cover(audio_file)
    if not app.ui.album_cover then
        return
    end
    
    if not audio_file then
        -- 显示默认音乐图标
        display_default_album_cover()
        return
    end
    
    local cover_path = get_album_cover(audio_file)
    
    if cover_path and kiko.dir.exists(cover_path) then
        -- 显示找到的封面图片
        app.ui.album_cover:setimg(cover_path)
        app.ui.album_cover:setopt("visible", true)
    else
        -- 显示默认音乐图标
        display_default_album_cover()
    end
end

-- 更新音乐信息显示（不包含专辑封面和歌词加载，用于onPlayerDurationChanged）
local function update_song_info_display(song)
    if not song then
        app.ui.song_title:setopt("title", "未播放")
        app.ui.song_artist:setopt("title", "艺术家: --")
        app.ui.song_album:setopt("title", "专辑: --")
        return
    end
    
    app.ui.song_title:setopt("title", song.title or "未知标题")
    app.ui.song_artist:setopt("title", "艺术家: " .. (song.artist or "未知艺术家"))
    app.ui.song_album:setopt("title", "专辑: " .. (song.album or "未知专辑"))
end

-- 播放指定索引的歌曲
local function play_song(index)
    if index < 1 or index > #app.playlist then
        return false
    end
    
    app.current_index = index
    local song = app.playlist[index]
    if not song or not song.filepath then
        return false
    end
    
    local player = app.player
    local err = player:command({"loadfile", song.filepath})
    
    if err == 0 then
        -- 设置音量
        player:command({"set", "volume", tostring(app.volume)})
        player:command({"set", "pause", "no"})
        
        app.playing = true
        app.file_loaded = true  -- 标记文件已加载
        update_song_info(song)
        
        -- 启动播放进度更新定时器
        if app.progress_timer then
            kiko.log("启动播放进度更新定时器")
            app.progress_timer:start()
        end
        
        -- 更新播放列表选中状态和高亮标记
        refresh_playlist_current_marker()
        
        app.ui.status_label:setopt("title", "正在播放: " .. (song.title or "未知标题"))
        
        return true
    else
        app.ui.status_label:setopt("title", "播放失败: " .. (song.title or "未知标题"))
        app.file_loaded = false  -- 标记文件未加载
        return false
    end
end

-- 添加文件到播放列表
app.onAddFiles = function(param)
    local files = kiko.dialog.openfile({
        title = "选择音频文件",
        filter = "音频文件 (*.mp3 *.wav *.flac *.aac *.ogg *.m4a);;所有文件 (*.*)",
        multi = true
    })
    
    if files then
        if type(files) == "string" then
            files = {files} -- 单个文件转换为数组
        end
        
        -- 直接添加基础信息，详细的元数据将在播放时更新
        local tree = app.ui.playlist_tree
        print("获取playlist_tree对象: " .. tostring(tree))
        
        if not tree then
            print("错误: 无法获取playlist_tree组件")
            app.ui.status_label:setopt("title", "错误: 播放列表组件未找到")
            return
        end
        
        for _, filepath in ipairs(files) do
            -- 从文件路径中提取文件名作为标题
            local title = filepath:match("([^/\\]+)$") or filepath
            
            local song = {
                filepath = filepath,
                title = title,
                duration = 0
            }
            table.insert(app.playlist, song)
            
            -- 使用专门的函数添加歌曲到播放列表显示，不清空
            add_song_to_tree(tree, song, #app.playlist)
        end
        
        -- 标记播放列表有更新
        app.playlist_dirty = true
        app.ui.status_label:setopt("title", string.format("已添加 %d 个文件", #files))
    end
end

-- 添加文件夹到播放列表
-- 递归扫描文件夹中的音频文件
local function scan_audio_files(folder, audio_files)
    local entries = kiko.dir.entrylist(folder, "*.mp3;*.wav;*.flac;*.aac;*.ogg;*.m4a")
    
    if entries then
        for _, entry in ipairs(entries) do
            local full_path = folder .. "/" .. entry
            local file_info = kiko.dir.fileinfo(full_path)
            
            if file_info then
                if file_info.isFile then
                    -- 检查是否是音频文件
                    local ext = entry:match("%.([^.]+)$")
                    if ext and (ext:lower() == "mp3" or ext:lower() == "wav" or 
                               ext:lower() == "flac" or ext:lower() == "aac" or 
                               ext:lower() == "ogg" or ext:lower() == "m4a") then
                        table.insert(audio_files, full_path)
                    end
                elseif file_info.isDir and entry ~= "." and entry ~= ".." then
                    -- 递归扫描子目录
                    scan_audio_files(full_path, audio_files)
                end
            end
        end
    end
end

app.onAddFolder = function(param)
    local folder = kiko.dialog.selectdir({
        title = "选择音频文件夹"
    })
    
    if folder then
        app.ui.status_label:setopt("title", "正在扫描音频文件...")
        
        -- 扫描音频文件
        local audio_files = {}
        scan_audio_files(folder, audio_files)
        
        if #audio_files > 0 then
            -- 获取播放列表树组件
            local tree = app.ui.playlist_tree
            if not tree then
                app.ui.status_label:setopt("title", "错误: 播放列表组件未找到")
                return
            end
            
            -- 添加音频文件到播放列表
            local added_count = 0
            for _, filepath in ipairs(audio_files) do
                -- 从文件路径中提取文件名作为标题
                local title = filepath:match("([^/\\]+)$") or filepath
                
                local song = {
                    filepath = filepath,
                    title = title,
                    duration = 0
                }
                
                table.insert(app.playlist, song)
                add_song_to_tree(tree, song, #app.playlist)
                added_count = added_count + 1
            end
            
            -- 标记播放列表有更新
            app.playlist_dirty = true
            app.ui.status_label:setopt("title", string.format("已从文件夹添加 %d 首歌曲", added_count))
            
            kiko.log(string.format("从文件夹 %s 添加了 %d 首歌曲", folder, added_count))
        else
            app.ui.status_label:setopt("title", "未找到音频文件")
            kiko.log(string.format("在文件夹 %s 中未找到音频文件", folder))
        end
    end
end

-- 清空播放列表
app.onClearList = function(param)
    -- 如果有文件正在播放，先停止播放
    if app.playing or app.file_loaded then
        local player = app.ui.music_player
        player:command({"stop"})  -- 停止播放
        if app.progress_timer then
            app.progress_timer:stop()  -- 停止进度更新定时器
        end
    end
    
    app.playlist = {}
    app.current_index = 0
    app.playing = false
    app.file_loaded = false  -- 重置文件加载状态
    app.last_playing_index = 0  -- 重置上一个播放索引
    update_playlist_display()
    update_song_info(nil)
    app.ui.btn_play_pause:setopt("title", "播放")
    app.ui.status_label:setopt("title", "播放列表已清空")
    app.playlist_dirty = true  -- 标记播放列表有更新
end

-- 显示/隐藏播放列表
app.onTogglePlaylist = function(param)
    local playlist_panel = app.ui.playlist_panel

    -- 获取当前可见性状态
    local is_visible = playlist_panel:getopt("visible")
    -- 切换可见性
    local new_visible = not is_visible
    if param["force"] ~= nil then
        new_visible = param["force"]
    else
        kiko.storage.set("playlist_visible", new_visible)
    end
    playlist_panel:setopt("visible", new_visible)
    kiko.ui.get("btn_add_files"):setopt("visible", new_visible)
    kiko.ui.get("btn_add_folder"):setopt("visible", new_visible)
    kiko.ui.get("btn_clear_list"):setopt("visible", new_visible)

    -- 更新按钮标题
    local btn = kiko.ui.get("btn_toggle_playlist")
    btn:setopt("title", new_visible and "隐藏播放列表" or "显示播放列表")
end

-- 播放/暂停
app.onPlayPause = function(param)
    if #app.playlist == 0 then
        app.ui.status_label:setopt("title", "播放列表为空")
        return
    end
    
    local player = app.ui.music_player
    
    if app.playing and app.file_loaded then
        player:command({"set", "pause", "yes"})
        app.playing = false
        app.ui.btn_play_pause:setopt("title", "播放")
        app.ui.status_label:setopt("title", "已暂停")
        -- 停止定时器
        if app.progress_timer then
            app.progress_timer:stop()
        end
    else
        if app.current_index == 0 then
            -- 还没有开始播放，从第一首开始
            local success = play_song(1)
            if not success then
                app.ui.status_label:setopt("title", "无法播放第一首歌曲")
                return
            else
                app.ui.btn_play_pause:setopt("title", "暂停")
            end
        else
            -- 检查是否有文件已加载
            if not app.file_loaded then
                -- 没有文件加载，需要先加载当前歌曲
                local success = play_song(app.current_index)
                if not success then
                    app.ui.status_label:setopt("title", "无法加载当前歌曲")
                    return
                else
                    app.ui.btn_play_pause:setopt("title", "暂停")
                end
            else
                -- 有文件已加载，继续播放
                player:command({"set", "pause", "no"})
                app.playing = true
                app.ui.status_label:setopt("title", "继续播放")
                -- 启动定时器
                if app.progress_timer then
                    app.progress_timer:start()
                end
            end
        end
    end
end

-- 上一首
app.onPrevSong = function(param)
    if #app.playlist == 0 then
        return
    end
    
    kiko.log("上一首: 当前模式=" .. app.loop_mode .. ", 当前索引=" .. app.current_index)
    local prev_index
    
    if app.loop_mode == 4 then -- 单曲循环
        kiko.log("上一首: 单曲循环模式，保持当前索引 " .. app.current_index)
        prev_index = app.current_index
    elseif app.loop_mode == 3 then -- 列表随机
        if #app.playlist == 1 then
            kiko.log("上一首: 列表随机模式，只有一首歌曲")
            prev_index = 1
        else
            -- 生成不重复的随机索引
            local available_indices = {}
            for i = 1, #app.playlist do
                if i ~= app.current_index then
                    table.insert(available_indices, i)
                end
            end
            
            kiko.log("上一首: 列表随机模式，可用索引数量=" .. #available_indices)
            
            -- 从可用索引中随机选择一个
            if #available_indices > 0 then
                local random_idx = math.random(1, #available_indices)
                prev_index = available_indices[random_idx]
                kiko.log("上一首: 随机选择索引 " .. random_idx .. " -> 歌曲索引 " .. prev_index)
            else
                kiko.log("上一首: 列表随机模式，没有可用索引，回退到第一首")
                prev_index = 1 -- 回退到第一首
            end
        end
    elseif app.loop_mode == 2 then -- 列表循环
        prev_index = app.current_index - 1
        if prev_index < 1 then
            prev_index = #app.playlist -- 循环到最后一首
        end
        kiko.log("上一首: 列表循环模式，上一首索引 " .. prev_index)
    else -- 列表顺序 (模式1)
        prev_index = app.current_index - 1
        if prev_index < 1 then
            -- 到达列表开头，停止播放
            kiko.log("上一首: 列表顺序模式，到达列表开头，停止播放")
            app.playing = false
            --app.ui.btn_play_pause:setopt("title", "播放")
            app.ui.status_label:setopt("title", "已到列表开头")
            return
        end
        kiko.log("上一首: 列表顺序模式，上一首索引 " .. prev_index)
    end
    
    play_song(prev_index)
end

-- 下一首
app.onNextSong = function(param)
    if #app.playlist == 0 then
        return
    end
    
    kiko.log("下一首: 当前模式=" .. app.loop_mode .. ", 当前索引=" .. app.current_index)
    local next_index
    
    if app.loop_mode == 4 then -- 单曲循环
        kiko.log("下一首: 单曲循环模式，保持当前索引 " .. app.current_index)
        next_index = app.current_index
    elseif app.loop_mode == 3 then -- 列表随机
        if #app.playlist == 1 then
            kiko.log("下一首: 列表随机模式，只有一首歌曲")
            next_index = 1
        else
            -- 生成不重复的随机索引
            local available_indices = {}
            for i = 1, #app.playlist do
                if i ~= app.current_index then
                    table.insert(available_indices, i)
                end
            end
            
            kiko.log("下一首: 列表随机模式，可用索引数量=" .. #available_indices)
            
            -- 从可用索引中随机选择一个
            if #available_indices > 0 then
                local random_idx = math.random(1, #available_indices)
                next_index = available_indices[random_idx]
                kiko.log("下一首: 随机选择索引 " .. random_idx .. " -> 歌曲索引 " .. next_index)
            else
                kiko.log("下一首: 列表随机模式，没有可用索引，回退到第一首")
                next_index = 1 -- 回退到第一首
            end
        end
    elseif app.loop_mode == 2 then -- 列表循环
        next_index = app.current_index + 1
        if next_index > #app.playlist then
            next_index = 1 -- 循环到第一首
        end
        kiko.log("下一首: 列表循环模式，下一首索引 " .. next_index)
    else -- 列表顺序 (模式1)
        next_index = app.current_index + 1
        if next_index > #app.playlist then
            -- 到达列表末尾，停止播放
            kiko.log("下一首: 列表顺序模式，到达列表末尾，停止播放")
            app.playing = false
            --app.ui.btn_play_pause:setopt("title", "播放")
            app.ui.status_label:setopt("title", "播放结束")
            return
        end
        kiko.log("下一首: 列表顺序模式，下一首索引 " .. next_index)
    end
    
    play_song(next_index)
end

-- 进度条拖动事件（用户手动拖动时触发seek）
app.onProgressSliderMoved = function(param)
    local value = param["value"]
    local player = app.ui.music_player
    
    -- 标记正在拖动进度条
    app.is_seeking = true
    
    -- 获取总时长
    local err, duration_str = player:property("duration")
    if err == 0 and duration_str then
        local duration = tonumber(duration_str)
        if duration and duration > 0 then
            local target_pos = (value / 100) * duration
            player:command({"seek", tostring(target_pos), "absolute"})
            app.is_seeking = false  -- 拖动结束，重置标志
        end
    end
end

-- 音量变化
app.onVolumeChanged = function(param)
    app.volume = param["value"]
    app.ui.volume_label:setopt("title", tostring(app.volume) .. "%")
    
    if not app.is_muted then
        local player = app.ui.music_player
        player:command({"set", "volume", tostring(app.volume)})
    end
end

-- 静音切换
app.onMuteToggle = function(param)
    local player = app.ui.music_player
    app.is_muted = not app.is_muted
    
    if app.is_muted then
        player:command({"set", "volume", "0"})
        app.ui.btn_mute:setopt("title", "取消静音")
    else
        player:command({"set", "volume", tostring(app.volume)})
        app.ui.btn_mute:setopt("title", "静音")
    end
end

-- 播放列表双击播放
app.onPlaylistTreeItemDoubleClick = function(param)
    local item = param["item"]
    if item then
        local index = tonumber(item:get(1, "data"))
        if index then
            play_song(index)
        end
    end
end

-- 播放列表右键菜单处理
app.onPlaylistMenuClick = function(param)
    local menu_id = param["id"]
    local tree = app.ui.playlist_tree
    local sels = tree:selection()
    
    if #sels == 0 then
        return
    end
    
    local current_item = sels[1]
    local current_index = tonumber(current_item:get(1, "data"))
    if not current_index or current_index < 1 or current_index > #app.playlist then
        return
    end
    
    if menu_id == "m_remove" then
        -- 删除条目
        table.remove(app.playlist, current_index)
        app.playlist_dirty = true
        
        -- 调整当前播放索引
        if app.current_index == current_index then
            -- 如果删除的是当前播放的歌曲
            if app.playing then
                app.playing = false
                app.ui.status_label:setopt("title", "歌曲已删除")
            end
            app.current_index = 0
        elseif app.current_index > current_index then
            -- 如果删除的歌曲在当前播放歌曲之前，调整索引
            app.current_index = app.current_index - 1
        end
        
        -- 重新显示播放列表
        update_playlist_display()
        
    elseif menu_id == "m_move_up" then
        -- 上移条目
        if current_index > 1 then
            -- 交换当前项和上一项
            app.playlist[current_index], app.playlist[current_index - 1] = 
                app.playlist[current_index - 1], app.playlist[current_index]
            
            -- 调整当前播放索引
            if app.current_index == current_index then
                app.current_index = current_index - 1
            elseif app.current_index == current_index - 1 then
                app.current_index = current_index
            end
            
            app.playlist_dirty = true
            update_playlist_display()
            
            -- 保持选中状态
            tree:setopt("current_index", current_index - 1)
        end
        
    elseif menu_id == "m_move_down" then
        -- 下移条目
        if current_index < #app.playlist then
            -- 交换当前项和下一项
            app.playlist[current_index], app.playlist[current_index + 1] = 
                app.playlist[current_index + 1], app.playlist[current_index]
            
            -- 调整当前播放索引
            if app.current_index == current_index then
                app.current_index = current_index + 1
            elseif app.current_index == current_index + 1 then
                app.current_index = current_index
            end
            
            app.playlist_dirty = true
            update_playlist_display()
            
            -- 保持选中状态
            tree:setopt("current_index", current_index + 1)
        end
    end
end

-- 播放器状态变化
app.onPlayerStateChanged = function(param)
    local state = param["state"]
    -- 控制定时器：播放时启动，暂停/停止时停止
    if state == 0 then -- 播放
        app.playing = true
        if app.file_loaded then
            app.ui.btn_play_pause:setopt("title", "暂停")
            if app.progress_timer then
                app.progress_timer:start()
            end
        else
            app.ui.btn_play_pause:setopt("title", "播放")
        end
    elseif state == 1 then -- 暂停
        app.playing = false
        app.ui.btn_play_pause:setopt("title", "播放")
        if app.progress_timer then
            app.progress_timer:stop()
        end
    elseif state == 2 then -- 播放到结尾，自动处理下一首
        kiko.log("播放器状态变化: state=" .. state .. ", loop_mode=" .. app.loop_mode .. ", current_index=" .. app.current_index .. ", playlist_count=" .. #app.playlist)
        
        if #app.playlist == 0 then
            app.playing = false
            app.ui.btn_play_pause:setopt("title", "播放")
            app.ui.status_label:setopt("title", "播放结束")
            return
        end
        
        if app.loop_mode == 4 then -- 单曲循环
            kiko.log("单曲循环模式: 重新播放当前歌曲 " .. app.current_index)
            -- 单曲循环，重新播放当前歌曲
            if app.current_index > 0 and app.current_index <= #app.playlist then
                -- 使用loadfile重新加载当前歌曲，这样可以确保从头开始播放
                local song = app.playlist[app.current_index]
                if song and song.filepath then
                    local player = app.ui.music_player
                    player:command({"loadfile", song.filepath})
                    player:command({"set", "volume", tostring(app.volume)})
                    player:command({"set", "pause", "no"})
                    kiko.log("单曲循环模式: 已重新加载歌曲 " .. app.current_index)
                end
            end
            return
        end
        
        -- 处理其他循环模式的下一首逻辑
        if app.loop_mode == 1 then -- 列表顺序
            kiko.log("列表顺序模式: 当前索引 " .. app.current_index .. "/" .. #app.playlist)
            if app.current_index < #app.playlist then
                kiko.log("列表顺序模式: 播放下一首 " .. (app.current_index + 1))
                play_song(app.current_index + 1)
            else
                -- 到达列表末尾，停止播放
                kiko.log("列表顺序模式: 到达列表末尾，停止播放")
                app.playing = false
                app.ui.btn_play_pause:setopt("title", "播放")
                app.ui.status_label:setopt("title", "播放结束")
                return -- 重要：确保不再执行后续代码
            end
        elseif app.loop_mode == 2 then -- 列表循环
            local next_index = app.current_index + 1
            if next_index > #app.playlist then
                next_index = 1 -- 循环到第一首
            end
            play_song(next_index)
        elseif app.loop_mode == 3 then -- 列表随机
            kiko.log("列表随机模式: 当前索引 " .. app.current_index .. "/" .. #app.playlist)
            if #app.playlist == 1 then
                kiko.log("列表随机模式: 只有一首歌曲，播放第一首")
                play_song(1)
            else
                -- 生成不重复的随机索引
                local available_indices = {}
                for i = 1, #app.playlist do
                    if i ~= app.current_index then
                        table.insert(available_indices, i)
                    end
                end
                
                kiko.log("列表随机模式: 可用索引数量: " .. #available_indices)
                
                -- 从可用索引中随机选择一个
                if #available_indices > 0 then
                    local random_idx = math.random(1, #available_indices)
                    local next_index = available_indices[random_idx]
                    kiko.log("列表随机模式: 随机选择索引 " .. random_idx .. " -> 歌曲索引 " .. next_index)
                    play_song(next_index)
                else
                    kiko.log("列表随机模式: 没有可用索引，回退到第一首")
                    play_song(1) -- 回退到第一首
                end
            end
        end
    end
end

-- 播放进度更新（定时器版本）
app.updateProgress = function()

    -- 只有在不在拖动进度条且正在播放时才更新
    if app.is_seeking or not app.playing then
        return
    end
    
    local player = app.ui.music_player
    if not player then
        return
    end
    
    -- 获取当前播放位置和时长
    local pos_err, pos = player:property("playback-time")
    local duration_err, duration = player:property("duration")
    
    if pos_err ~= 0 or duration_err ~= 0 or not pos or not duration then
        return
    end

    if duration and duration > 0 then
        local progress = (pos / duration) * 100
        app.ui.progress_slider:setopt("value", progress)
        app.ui.current_time:setopt("title", format_time(pos))
        app.ui.total_time:setopt("title", format_time(duration))
        
        -- 更新歌词显示（如果有歌词）
        if app.lyrics_available and app.current_lyrics and #app.current_lyrics > 0 then
            local current_lyric, lyric_index = get_current_lyric(app.current_lyrics, pos)
            if lyric_index ~= app.current_lyric_index then
                app.current_lyric_index = lyric_index
                local display_text = format_lyrics_for_display(app.current_lyrics, lyric_index)
                app.ui.lyrics_text:clear()  -- 先清空内容
                app.ui.lyrics_text:append(display_text, true)  -- 使用append方法添加HTML内容
                -- 只在调试时输出详细日志
                if lyric_index > 0 and current_lyric then
                    -- kiko.log("歌词: " .. current_lyric.text .. " [" .. format_time(pos) .. "]")
                end
            end
        end
    end
end

-- 播放进度更新（兼容旧的事件监听方式，保持接口不变）
app.onPlayerPosChanged = function(param)
    -- 使用定时器后，这个函数可以留空或者保持兼容
    -- 参数格式：{pos=position, duration=duration}
    if param and param.pos and param.duration then
        -- 如果定时器没有运行，仍然可以处理事件
        if not app.progress_timer or not app.progress_timer:active() then
            -- 手动调用更新函数
            app.updateProgress()
        end
    end
end

-- 播放器时长变化（文件加载完成）
app.onPlayerDurationChanged = function(param)
    local duration = param["duration"]
    
    -- 只有在有当前播放歌曲且时长大于0时才处理
    if app.current_index > 0 and app.current_index <= #app.playlist and duration and duration > 0 then
        local song = app.playlist[app.current_index]
        if song and song.filepath then
            -- 检查元信息是否有更新
            local player = app.ui.music_player
            local has_update = false
            
            -- 更新歌曲时长
            if song.duration ~= duration then
                song.duration = duration
                has_update = true
            end
            
            -- 获取标题
            local meta_err, title = player:property("metadata/title")
            if meta_err == 0 and title and title ~= "" and song.title ~= title then
                song.title = title
                has_update = true
            end
            
            -- 获取艺术家
            local artist_err, artist = player:property("metadata/artist")
            if artist_err == 0 and artist and artist ~= "" and song.artist ~= artist then
                song.artist = artist
                has_update = true
            end
            
            -- 获取专辑
            local album_err, album = player:property("metadata/album")
            if album_err == 0 and album and album ~= "" and song.album ~= album then
                song.album = album
                has_update = true
            end
            
            -- 在文件加载完成时获取歌词（时机最佳，因为此时metadata已经可用）
            local lyrics = load_lyrics(song.filepath)
            app.current_lyrics = lyrics
            app.current_lyric_index = 0
            
            -- 在文件加载完成时显示专辑封面（时机最佳，因为此时文件已完全加载）
            display_album_cover(song.filepath)
            
            if #lyrics > 0 then
                app.lyrics_available = true
                -- 显示所有歌词（使用新的HTML格式）
                local display_text = format_lyrics_for_display(lyrics, 0)
                app.ui.lyrics_text:clear()  -- 先清空内容
                app.ui.lyrics_text:append(display_text, true)  -- 使用append方法添加HTML内容
                kiko.log("找到 " .. #lyrics .. " 行歌词")
            else
                app.lyrics_available = false
                -- 使用HTML格式显示"暂无歌词"
                local no_lyrics_html = "<p style='color: #999; text-align: center; font-size: 14px; margin: 20px 0;'>暂无歌词</p>"
                app.ui.lyrics_text:clear()  -- 先清空内容
                app.ui.lyrics_text:append(no_lyrics_html, true)  -- 使用append方法添加HTML内容
                kiko.log("未找到歌词")
            end
            
            -- 如果有更新，更新显示并标记播放列表已更新
            if has_update then
                app.playlist_dirty = true
                
                -- 更新当前播放信息显示
                if app.playing then
                    update_song_info_display(song)  -- 使用新的函数名，避免重复加载歌词
                    app.ui.status_label:setopt("title", "正在播放: " .. (song.title or "未知标题"))
                end
                
                -- 更新播放列表中当前项的显示
                local tree = app.ui.playlist_tree
                update_item_in_tree(tree, song, app.current_index)
            end
        end
    end
end

-- 初始化
app.loaded = function(param)
    -- 初始化随机数生成器
    math.randomseed(os.time())
    
    local w = param["window"]
    app.w = w
    local window_config = kiko.storage.get("window_config") or {}
    if window_config.w ~= nil then
        w:setopt("w", window_config.w)
    end
    if window_config.h ~= nil then
        w:setopt("h", window_config.h)
    end
    if window_config.pinned ~= nil then
        w:setopt("pinned", window_config.pinned)
    end
    
    -- 缓存所有UI元素引用（避免重复的kiko.ui.get调用）
    app.ui.playlist_tree = kiko.ui.get("playlist_tree")
    app.ui.playlist_panel = kiko.ui.get("playlist_panel")
    app.ui.song_title = kiko.ui.get("song_title")
    app.ui.song_artist = kiko.ui.get("song_artist")
    app.ui.song_album = kiko.ui.get("song_album")
    app.ui.album_cover = kiko.ui.get("album_cover")
    app.ui.lyrics_text = kiko.ui.get("lyrics_text")
    app.ui.btn_play_pause = kiko.ui.get("btn_play_pause")
    app.ui.status_label = kiko.ui.get("status_label")
    app.ui.progress_slider = kiko.ui.get("progress_slider")
    app.ui.current_time = kiko.ui.get("current_time")
    app.ui.total_time = kiko.ui.get("total_time")
    app.ui.music_player = kiko.ui.get("music_player")
    app.ui.volume_slider = kiko.ui.get("volume_slider")
    app.ui.volume_label = kiko.ui.get("volume_label")
    app.ui.btn_mute = kiko.ui.get("btn_mute")
    app.ui.loop_mode = kiko.ui.get("loop_mode")

    -- 恢复音量设置
    app.volume = kiko.storage.get("music_player_volume", 50)
    app.ui.volume_slider:setopt("value", app.volume)
    app.ui.volume_label:setopt("title", tostring(app.volume) .. "%")

    -- 恢复循环模式设置
    app.loop_mode = kiko.storage.get("music_player_loop_mode", 2)
    app.ui.loop_mode:setopt("current_index", app.loop_mode)
    
    -- 恢复当前播放索引
    app.current_index = kiko.storage.get("music_player_current_index", 0)
    
    -- 设置播放列表列头（只保留一列）
    app.ui.playlist_tree:setheader({"播放列表"})
    
    -- 加载播放列表（使用kiko.storage）
    if load_playlist() then
        update_playlist_display()
        app.ui.status_label:setopt("title", string.format("已加载 %d 首歌曲", #app.playlist))
        
        -- 如果有当前播放的歌曲，显示其信息并高亮显示
        if app.current_index > 0 and app.current_index <= #app.playlist then
            local song = app.playlist[app.current_index]
            update_song_info(song)
            -- 高亮显示当前播放的歌曲
            refresh_playlist_current_marker()
        end
    else
        app.ui.status_label:setopt("title", "播放列表为空")
    end
    
    app.player = app.ui.music_player    
    -- 创建播放进度更新定时器（200ms间隔，平衡响应速度和性能）
    app.progress_timer = kiko.timer.create(200)
    app.progress_timer:ontimeout(app.updateProgress)

    if not kiko.storage.get("playlist_visible", true) then
        app.onTogglePlaylist({["force"] = false})
    end
    
    -- 设置样式
    w:setstyle(env.app_path .. "/style.qss")
    w:show()
end

-- 关闭应用
app.close = function(param)
    kiko.storage.set("window_config", {
        w = app.w:getopt("w"),
        h = app.w:getopt("h"),
        pinned = app.w:getopt("pinned"),
    })

    -- 如果播放列表有更新，保存播放列表
    if app.playlist_dirty then
        save_playlist()
    end
    
    -- 保存当前播放索引（无论播放列表是否有修改都保存）
    kiko.storage.set("music_player_current_index", app.current_index)
    
    -- 保存音量设置
    kiko.storage.set("music_player_volume", app.volume)
    
    return true
end