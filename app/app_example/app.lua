app = {}


app.loaded = function(param)
    app.page = kiko.ui.get("page")
    local w = param["window"]
    app.w = w

    app.widgets = require "pages/page_widgets"
    app.interaction = require "pages/page_interaction"
    app.network = require "pages/page_network"

    w:setstyle(env.app_path .. "/style.qss")
    w:show()
end

app.onPageBtnClick = function(param)
    app.page:setopt("current_index", param["src"]:data("idx"))
end
