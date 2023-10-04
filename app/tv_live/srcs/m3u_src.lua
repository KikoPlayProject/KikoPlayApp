local parse_extinf = function(content)
    local reg = kiko.regex("#EXTINF:-?\\d+\\s?(.+),(.+)")
    local _, _, props, name = reg:find(content)
    if name == nil then return nil end
    local preg = kiko.regex("(.*?)=\"(.*?)\"\\s?")
    local tprop = {}
    for _, k, v in preg:gmatch(props) do
        tprop[k] = v
    end
    return name, tprop
end

local parseContent = function(raw_content)
    local lines = string.split(raw_content, "\n", true)
    local group = {}
    local cur_group = nil
    local cur_group_set = {}
    local cur_item = nil
    for _, line in ipairs(lines) do
        local line = string.trim(line)
        if string.startswith(line, "#EXTINF") then
            local name, tags = parse_extinf(line)
            if name == nil then goto continue_skip_line end
            local group_title = tags["group-title"]
            if group_title ~= nil then
                if cur_group_set[group_title] == nil then
                    cur_group = {}
                    table.insert(group, {group_title, cur_group})
                    cur_group_set[group_title] = cur_group
                else
                    cur_group = cur_group_set[group_title]
                end
            else
                cur_group = nil
            end
            cur_item = { name, "" }
        else
            if cur_item ~= nil and string.startswith(line, "http") then
                cur_item[2] = {
                    ["url"] = line
                }
                if cur_group ~= nil then
                    table.insert(cur_group, cur_item)
                else
                    table.insert(group, cur_item)
                end
                cur_item = nil
            end
        end
        ::continue_skip_line::
    end
    return group
end

function make_m3u_src(n, u)
    local surl = string.trim(u)
    if #surl == 0 then return nil end
    local src = {
        name = n,
        url = surl,
        data = kiko.storage.get(surl) or {},
    }
    src.refresh = function(cb)
        kiko.net.request({
            method = "get",
            url = surl,
            query = {},
            header = {},
            extra = {src, cb},
            success = function(reply)
                local e = reply:extra()
                e[1].data = parseContent(reply:content())
                kiko.storage.set(surl, e[1].data)
                e[2](nil, e[1].data)
            end,
            error = function(reply)
                local e = reply:extra()
                e[2](reply:error(), e[1].data)
            end
        })
    end
    return src
end