---@meta

---@class HyprDispatcher
---@field focus fun(opts: { workspace?: string|integer, direction?: string, monitor?: string }): table
---@field exec_cmd fun(cmd: string): table
---@field window { close: (fun(): table), float: (fun(opts?: { action?: string }): table), drag: (fun(opts?: { mode?: string }): table), resize: (fun(opts?: table): table), move: (fun(opts: { workspace?: string|integer, direction?: string }): table), fullscreen: (fun(opts?: { toggle?: boolean }): table) }
---@field workspace { toggle_special: (fun(name?: string): table) }

---@class HyprLuaGlobal
---@field config fun(cfg: table)
---@field env fun(name: string, value: string)
---@field monitor fun(opts: table)
---@field bind fun(keys: string, dispatcher: table|string, opts?: { locked?: boolean, repeating?: boolean, release?: boolean, mouse?: boolean })
---@field window_rule fun(rule: table)
---@field workspace_rule fun(rule: table)
---@field curve fun(name: string, opts: table)
---@field animation fun(opts: table)
---@field on fun(event: string, callback: fun(...))
---@field exec_cmd fun(cmd: string)
---@field dispatch fun(dispatcher: table|string)
---@field dsp HyprDispatcher
hl = {}
