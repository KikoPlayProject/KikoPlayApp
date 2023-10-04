local src = {
    name = "字幕库",
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
        ["q"] = keyword,
        ["chost"] = "zimuku.org",
    }
    local err, reply = kiko.net.httpget("https://zimuku.org/search", q)
    if err ~= nil then return err, {} end
    local content = reply["content"]

    local parser = kiko.htmlparser(content)
    local spos, epos = string.find(content, "<td class=\"first\">")
    local results = {}
    while spos do
        parser:seekto(spos - 1)
        parser:readnext()
        parser:readnext()
        parser:readnext()
        if parser:curnode()=="a" then
            local url = "https:" .. parser:curproperty("href")
            table.insert(results, {
                ["url"]=url,
                ["title"]=unescape(parser:curproperty("title"))
            })
        end
        spos, epos = string.find(content, "<td class=\"first\">", epos)
    end
    return nil, results
end

src.subinfo = function(item)
    local reg = kiko.regex("detail/(\\d+)\\.html")
    local _, _, sub_id = reg:find(item.url)
    if sub_id == nil then return "获取信息失败", {} end

    local download_page_url = string.format("https://zimuku.org/dld/%s.html", sub_id)
    local err, reply = kiko.net.httpget(download_page_url)
    if err ~= nil then return err, {} end
    local content = reply["content"]
    local spos, epos = string.find(content, "<a rel=\"nofollow\"");
    if spos == nil then return "解析内容失败", {} end

    local parser = kiko.htmlparser(content)
    parser:seekto(spos-1)
    parser:readnext()
    if parser:curnode()=="a" then
        local url = "https://zimuku.org" .. parser:curproperty("href")
        return nil, {
            ["url"]=item.url,
            ["download_url"]=url,
            ["title"]=item.title,
            ["filename"]=item.title,
        }
    end
    return "解析内容失败", {}
end

src.download = function(sub, path)
    local err, reply = kiko.net.httpget(sub.download_url)
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