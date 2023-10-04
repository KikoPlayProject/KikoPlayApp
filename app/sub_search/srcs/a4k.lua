local src = {
    name = "A4K字幕",
}

local function unescape(str)
    str = string.gsub( str, '&lt;', '<' )
    str = string.gsub( str, '&gt;', '>' )
    str = string.gsub( str, '&quot;', '"' )
    str = string.gsub( str, '&apos;', "'" )
    str = string.gsub( str, '&#(%d+);', function(n) return utf8.char(n) end )
    str = string.gsub( str, '&#x(%x+);', function(n) return utf8.char(tonumber(n,16)) end )
    str = string.gsub( str, '&amp;', '&' ) -- Be sure to do this after all others
    return str
end

src.search = function(keyword)
    local q = {
        ["key"] = keyword
    }
    local err, reply = kiko.net.httpget("https://a4k.net/search", q)
    if err ~= nil then return err, {} end
    local content = reply["content"]
    local _, _, search_res = string.find(content, "<tbody class=\"table%-group%-divider\">(.*)<div class=\"site%-footer\">")
    if search_res == nil then
        return "未找到结果", {}
    end
    local items = {}
    local parser = kiko.htmlparser(search_res)
    while not parser:atend() do
        if parser:curnode()=="td" and parser:start() and parser:curproperty("class")=="views-field views-field-title" then
            parser:readnext()
            if parser:curnode()=="a" then
                local url = "https://a4k.net/" .. parser:curproperty("href")
                table.insert(items, {
                    ["url"]=url,
                    ["title"]=unescape(parser:readcontent())
                })
            end
        end
        parser:readnext()
    end
    return nil, items
end

src.subinfo = function(item)
    local err, reply = kiko.net.httpget(item.url)
    if err ~= nil then return err, {} end
    local content = reply["content"]
    local spos, epos = string.find(content, "<div class=\"site%-content\">")
    if spos == nil then return "解析内容失败", {} end
    local parser = kiko.htmlparser(content)
    local title = nil
    local submit = nil
    local download_url = nil
    local size = nil
    parser:seekto(spos-1)
    while not parser:atend() do
        local node = parser:curnode()
        local is_start = parser:start()
        if node=="div" and is_start and parser:curproperty("id")=="block-yemianbiaoti" then
            parser:readnext()
            parser:readnext()
            title = unescape(parser:readcontent())
        elseif node == "footer" and is_start then
            parser:readnext()
            parser:readnext()
            parser:readnext()
            submit = parser:readuntil("div", false)
            submit = string.gsub(submit, "<.->", "")
            submit = unescape(string.gsub(submit, "[\n\t]", ""))
        elseif node == "span" and is_start and string.startswith(parser:curproperty("class"), "file") then
            parser:readnext()
            download_url = "https://a4k.net/" .. parser:curproperty("href")
            parser:readnext()
            parser:readnext()
            parser:readnext()
            parser:readnext()
            size = parser:readcontent()
            size = string.gsub(size, "<.->", "")
            size = unescape(string.gsub(size, "[\n\t]", ""))
            break
        end
        parser:readnext()
    end
    if title ~= nil and download_url ~= nil then
        return nil, {
            ["title"] = title,
            ["desc"] = string.format("%s\n%s", submit, size),
            ["url"] = download_url
        }
    end
    return "解析内容失败", {}
end

src.download = function(sub, path)
    local err, reply = kiko.net.httpget(sub.url)
    if err ~= nil then return err end
    local content = reply["content"]
    local save_file_path = string.encode(path, string.CODE_UTF8, string.CODE_LOCAL)
    local file = io.open(save_file_path, "wb")
    if file == nil then return "文件创建失败：" .. save_file_path end
    file:write(content)
    file:close()
    return nil
end

return src