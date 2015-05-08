local framework = require('framework')
local CommandOutputDataSource = framework.CommandOutputDataSource
local MeterDataSource = framework.MeterDataSource
local PollerCollection = framework.PollerCollection
local DataSourcePoller = framework.DataSourcePoller
local Plugin = framework.Plugin
local os = require('os')
local io = require('io')
local table = require('table')
local string = require('string')
local pack = framework.util.pack

local isEmpty = framework.string.isEmpty
local clone = framework.table.clone

local params = framework.params 
params.name = 'Boundary Process CPU/Mem Plugin'
params.version = '1.1'
params.tags = "ps"

local commands = {
  linux = { path = '/bin/ps', args = {'aux'} },
  darwin = { path = '/bin/ps', args = {'aux'} }
}

local ps_command = commands[string.lower(os.type())] 
if ps_command == nil then
  print("_bevent:"..(Plugin.name or params.name)..":"..(Plugin.version or params.version)..":Your platform is not supported.  We currently support Linux, Windows and OSX|t:error|tags:lua,plugin"..(Plugin.tags and framework.string.concat(Plugin.tags, ',') or params.tags))
  process:exit(-1)
end

local function parseOutput(context, output) 
  
  assert(output ~= nil, 'parseOutput expect some data')

  if isEmpty(output) then
    context:emit('error', 'Unable to obtain any output.')
    return
  end

  local items = context.items or {}
  local procs = {}
  local result = {}
  for _, proc in ipairs(framework.string.split(output, '\n')) do
    local fields={}; i=1; columns={}; cmdcol=11
    for field in string.gmatch(proc, "([^ ]+)") do
      table.insert(fields, field)
      i = i + 1
    end
    table.insert(procs, fields)
  end
  for index, proc in ipairs(procs) do
    if index == 1 then
      for ind, val in ipairs(proc) do
        if val == "COMMAND" then cmdcol = ind end
        columns[ind] = val:gsub("%%", ""):lower()
      end
    elseif proc[cmdcol] then
      local process_list_item = {}
      process_list_item.command = proc[cmdcol]
      for i=cmdcol+1, table.getn(proc) do
        process_list_item.command = process_list_item.command .. " " .. proc[i]
      end
      for i=1, cmdcol-1 do
        process_list_item[columns[i]] = proc[i]
      end
      for _, item in ipairs(items) do
        if process_list_item.command:match(item.match) then
          process_list_item.name = item.name or item.match
          table.insert(result, process_list_item)
        end
      end
    end
  end
  return result

end

local meter_data_source = MeterDataSource:new()

function meter_data_source:onFetch(socket)
  socket:write(self:queryMetricCommand({match = 'system.meter'}))
end

local ps_data_source = CommandOutputDataSource:new(ps_command)

local psPlugin = Plugin:new(params, ps_data_source)
psPlugin.items = params.items

function psPlugin:onParseValues(data) 
  local result = {}

  local values = parseOutput(self, data['output'])

  if values then
    for _,v in pairs(values) do
      table.insert(result, pack('CPU_PROCESS', v.cpu/100, nil, psPlugin.source .. "." .. v.name))
      table.insert(result, pack('MEM_PROCESS', v.mem/100, nil, psPlugin.source .. "." .. v.name))
      table.insert(result, pack('RMEM_PROCESS', v.rss*1024, nil, psPlugin.source .. "." .. v.name))
      table.insert(result, pack('VMEM_PROCESS', v.vsz*1024, nil, psPlugin.source .. "." .. v.name))
      if v.time then
        local iM, iS, iPS = string.match(v.time, "(%d+):(%d+)%.(%d+)")
        if iM and iS and iPS then
          table.insert(result, pack('TIME_PROCESS', (iM*60+iS+iPS/100)*1000, nil, psPlugin.source .. "." .. v.name))
        else
          iM, iS = string.match(v.time, "(%d+):(%d+)")
          if iM and iS then
            table.insert(result, pack('TIME_PROCESS', (iM*60+iS)*1000, nil, psPlugin.source .. "." .. v.name))
          else
            io.stderr:write("Time value incorrectly formatted =>" .. v.time)
          end
        end
      end
    end
  else
    psPlugin:printEvent("error", "Parsed [" .. data['output'] .. "] to nil")
  end
  return result
end


params.name = 'Boundary Meter Monitor Plugin'
local meterPlugin = Plugin:new(params, meter_data_source)

function meterPlugin:onParseValues(data)
  local result = {}

  for _, v in ipairs(data) do
    local _, metric = string.match(v.metric, '^(system%.meter%.)(.*)$')
    if (metric == "cpu") then
      table.insert(result, pack('CPU_PROCESS', v.value, v.timestamp, meterPlugin.source .. '.Meter'))
    elseif (metric == "mem.rss") then
      table.insert(result, pack('RMEM_PROCESS', v.value, v.timestamp, meterPlugin.source .. '.Meter'))
    elseif (metric == "mem.size") then
      table.insert(result, pack('VMEM_PROCESS', v.value, v.timestamp, meterPlugin.source .. '.Meter'))
    else
        _, metric, params = string.match(metric, '^(hlm%.time_ms)(.*)|(.*)$')
        if (metric == ".interval") then
          _, metric = string.match(params, '^(metric=)(.*)$')
          table.insert(result, pack('INTERVAL_' .. string.upper(metric), v.value, v.timestamp, meterPlugin.source .. '.Meter'))
        elseif (metric == "" or metric == nil) then
          _, period, _, metric = string.match(params, '^(period=)(.*)%&(metric=)(.*)$')
          table.insert(result, pack(string.upper(metric) .. "_" .. string.upper(period), v.value, v.timestamp, meterPlugin.source .. '.Meter'))
        end
    end
  end

  return result
end

psPlugin:run()
meterPlugin:run()
