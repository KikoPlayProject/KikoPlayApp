
Updater = {
  -- ls: local script
  -- rs: remote script
  -- btn: update button
  is_download = false,
}

function Updater:new(params)
    o = params or {}
    setmetatable(o, self)
    self.__index = self
    params["btn_default_title"] = params.btn:getopt("title")
    return o
end

function Updater:get_download_filename()
    local p = env.app_path .. "/../../script/" .. self.rs.type
    local tp = ""
    local i = string.lastindexof(self.rs.url, "/")
    if i == nil then
        tp = p .. "/" .. self.rs.id .. ".lua"
    else
        tp = p .. "/" .. string.sub(self.rs.url, i+1)
        if kiko.dir.exists(tp) then
            tp = p .. "/" .. self.rs.id .. ".lua"
        end
    end
    return tp
end

function Updater:save_file(data)
    local c_path = ""
    if self.is_download then
        c_path = self:get_download_filename()
    else
        c_path = self.ls.path
    end
    local l_path = string.encode(c_path, string.CODE_UTF8, string.CODE_LOCAL)
    local ls_tmp_path = l_path .. ".tmp"
    local f = io.open(ls_tmp_path, "wb")
    f:write(data)
    f:close()
    if kiko.dir.exists(l_path) then
        os.remove(l_path)
    end
    os.rename(ls_tmp_path, l_path)
end

function Updater:get_refresh_type()
    if self.is_download then
        return self.rs.type_id
    else
        return self.ls.type
    end
end

function Updater:update()
    self.btn:setopt("enable", false)
    kiko.net.request({
        method = "get",
        url = self.rs.url,
        success = function(reply)
            self:save_file(reply:content())
            kiko.refreshscripts(self:get_refresh_type())
            self.btn:setopt("enable", false)
            local tip = "更新完成"
            if self.is_download then 
                tip = "下载完成" 
            end
            self.btn:setopt("title", tip)
        end,
        error = function(reply)
            local tip = ""
            if self.is_download then 
                tip = string.format("[%s]下载失败: %s", self.rs.name, reply:error())
            else
                tip = string.format("[%s]更新失败: %s", self.ls.name, reply:error())
            end
            app.w:message(tip, kiko.msg.NM_HIDE | kiko.msg.NM_ERROR)
            self.btn:setopt("title", self.btn_default_title)
            self.btn:setopt("enable", true)
        end,
        progress = function(received, total, reply)
            self.btn:setopt("title", string.format("正在下载(%d%)", received / total * 100))
        end
    })
end

return Updater
