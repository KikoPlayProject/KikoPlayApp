# <img src="kikoplay.png" width=24 /> KikoPlay 扩展App开发参考 
2023.09 By Kikyou，本文档适用于KikoPlay 1.0.0及以上版本
 

## 概述
扩展App采用Lua编写，在独立线程中运行。KikoPlay提供了一系列API供App实现各种交互：
 - UI：通过xml描述用户界面元素，同时支持事件监听和响应。 
 - 网络：KikoPlay提供同步/异步HTTP请求API，如果需要实时通信，KikoPlay还提供了WebSocket API。
 - KikoPlay交互：访问KikoPlay的播放器、弹幕、资料库等功能。

app目录下提供的app展示了大部分api的使用方法。

## 文件
全部App位于KikoPlay的extension/app目录，每个App拥有独立的目录，App至少要包含这些文件：
```c++
app.json  // 描述app基本信息
app.xml   // 定义app ui结构
app.lua   // app代码入口
```
### app.json
包含app的基本信息：
```json
{
    "name": "TV Live",   // 名称，必须包含
    "id": "kapp.tv",     // id，必须包含
    "version": 1.0,
    "icon": "app.png"    // app图标
}
```
### app.xml
定义app的ui结构，这个文件必须以`window`为根节点，可以通过`include`节点包含其他文件。
```xml
<window title="App示例" w="450" h="400" content_margin="0,0,0,0" >
    <label title="hello world" />
</window>
```
### app.lua
程序入口，事件响应函数需要放到`app`表内：
```lua
app = {}

app.loaded = function(param)
    local w = param["window"]
    w:show()
end

app.close = function(param)
    return true
end
```

## 生命周期
App的启动过程： 
1. KikoPlay创建新的Lua虚拟机，设置运行环境。
2. 创建新线程，在新线程中装载`app.lua`脚本。
3. 如果脚本装载正确，读取`app.xml`，创建ui。
4. 调用脚本的`app.loaded`函数，App完成启动。

如果用户点击窗口的"x"关闭按钮，KikoPlay会调用脚本的`app.close`函数， 如果返回`true`则结束app。如果用户在App图标的右键菜单中选择终止，`app.close`则不会被调用。


## Api参考
 - [UI交互](api/ui.md)
 - [网络访问](api/net.md)
 - [KikoPlay交互与环境](api/kiko.md)