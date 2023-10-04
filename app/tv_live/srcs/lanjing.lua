local parseContent = function(raw_content)
    local lines = string.split(raw_content, "\n", true)
    local group = {}
    local cur_group = nil
    local cur_group_set = nil
    for _, line in ipairs(lines) do
        local line = string.trim(line)
        local seps = string.split(line, ",", true)
        if #seps < 2 then goto continue_skip_line end
        if seps[2] == "#genre#" then
            cur_group = {}
            table.insert(group, {seps[1], cur_group})
            cur_group_set = {}
            goto continue_skip_line
        end
        if cur_group ~= nil then
            local channel = seps[1]
            local urls = string.split(seps[2], "#")
            local channel_urls = cur_group_set[channel]
            if channel_urls == nil then
                channel_urls = {}
                table.insert(cur_group, {channel, channel_urls})
                cur_group_set[channel] = channel_urls
            end
            local init_urls = #channel_urls
            for i, url in ipairs(urls) do
                local item_data = {
                    ["url"] = url
                }
                table.insert(channel_urls, {string.format("线路%d", i + init_urls), item_data})
            end
        end
        ::continue_skip_line::
    end
    return group
end
local src = {
    name = "蓝鲸直播源",
    data = kiko.storage.get("lanjing_srcs") or {},
}
src.refresh = function(cb)
    kiko.net.request({
        method = "get",
        url = "https://raw.githubusercontent.com/Cyril0563/lanjing_live/main/TVbox_Free/LIVE/Free/tvbox_live.txt",
        query = {},
        header = {},
        extra = {src, cb},
        success = function(reply)
            local e = reply:extra()
            e[1].data = parseContent(reply:content())
            kiko.storage.set("lanjing_srcs", e[1].data)
            e[2](nil, e[1].data)
        end,
        error = function(reply)
            local e = reply:extra()
            kiko.log("error: ", reply:error())
            e[2](reply:error(), e[1].data)
        end
    })
end
return src