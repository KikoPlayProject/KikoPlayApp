download_list = {
    record = {},
    record_file = env.data_path .. "/records.json",
    record_changed = false,
}

download_list.add_item = function(idx, list_idx)
    local record = download_list.record[idx]
    local view = app.task_list:setview(list_idx, string.format([[
        <hview h_size_policy="min_expand"> 
            <vview content_margin="0,0,0,0" h_size_policy="min_expand">
                <label h_size_policy="ignore" title="&lt;h4&gt;%s&lt;/h4&gt;" tooltip="%s" /> 
                <label h_size_policy="ignore" title="%s - %s" />
            </vview> 
            <button id="browse" title="打开目录" />
            <button id="copy_url" title="复制链接" />
            <button id="remove" title="删除记录" />
        </hview>
    ]], record.title, record.title, record.time, record.src))
    local browse = view:getchild("browse")
    browse:onevent("click", function(param)
        local record = download_list.record[idx]
        kiko.execute(true,  "cmd", {"/c", "start", record.path})
    end)
    local copy_url = view:getchild("copy_url")
    copy_url:onevent("click", function(param) 
        local record = download_list.record[idx]
        kiko.clipboard.settext(record.url)
    end)
    local remove = view:getchild("remove")
    remove:onevent("click", function(param)
        download_list.remove_record(idx)
        app.task_list:remove(list_idx)
    end)
end

download_list.add_record = function(title, url, path, src)
    local time = os.date("%Y-%m-%d %H:%M:%S", os.time())
    local new_recored = {
        title=title, url=url, path=path, time=time, src = src
    }
    table.insert(download_list.record, new_recored)
    if app.record_loaded then
        app.task_list:insert(1, "")
        download_list.add_item(#download_list.record, 1)
    end
    download_list.record_changed = true
end

download_list.remove_record = function(idx)
    table.remove(download_list.record, idx)
    download_list.record_changed = true
end

download_list.load_record = function()
    local f = io.open(download_list.record_file, "r")
    if f == nil then return end
    local data = f:read("a")
    f:close()
    local _, t = kiko.json2table(data)
    download_list.record = t
end

download_list.save_record = function()
    if not download_list.record_changed then return end
    local _, json = kiko.table2json(download_list.record)
    local f = io.open(download_list.record_file, "w")
    f:write(json)
    f:close()
end

download_list.load_list = function()
    local count = #download_list.record
    for i = count, 1, -1 do
        app.task_list:append("")
        download_list.add_item(i, count - i + 1)
    end
end

download_list.load_record()

return download_list