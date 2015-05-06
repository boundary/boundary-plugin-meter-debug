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
      for _, item in ipairs(params.items) do
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

params.name = 'Boundary Meter Monitor Plugin'
local meterPlugin = Plugin:new(params, meter_data_source)

function meterPlugin:onParseValues(data)
  local result = {}
  result['CPU_PROCESS'] = {}
  result['VMEM_PROCESS'] = {}
  result['RMEM_PROCESS'] = {}
    
  for _, v in ipairs(data) do
    local metric = string.match(v.metric, '^(system%.meter%.cpu)$')
    if (metric) then
      table.insert(result['CPU_PROCESS'], { value = v.value/100, source = meterPlugin.source .. '.Meter', timestamp = v.timestamp })
    end
    metric = string.match(v.metric, '^(system%.meter%.mem%.rss)$')
    if (metric) then
      table.insert(result['RMEM_PROCESS'], { value = v.value, source = meterPlugin.source .. '.Meter', timestamp = v.timestamp })
    end
    metric = string.match(v.metric, '^(system%.meter%.mem%.size)$')
    if (metric) then
      table.insert(result['VMEM_PROCESS'], { value = v.value, source = meterPlugin.source .. '.Meter', timestamp = v.timestamp })
    end
  end
    
  return result
end

function psPlugin:onParseValues(data) 
  local result = {}
  result['CPU_PROCESS'] = {}
  result['RMEM_PROCESS'] = {}
  result['VMEM_PROCESS'] = {}
  result['MEM_PROCESS'] = {}
  result['TIME_PROCESS'] = {}

  local values = parseOutput(self, data['output'])
  for _,v in pairs(values) do
    table.insert(result['CPU_PROCESS'], { value = v.cpu/100, source = psPlugin.source .. "." .. v.name })
    table.insert(result['MEM_PROCESS'], { value = v.mem/100, source = psPlugin.source .. "." .. v.name })
    table.insert(result['RMEM_PROCESS'], { value = v.rss, source = psPlugin.source .. "." .. v.name })
    table.insert(result['VMEM_PROCESS'], { value = v.vsz, source = psPlugin.source .. "." .. v.name })
    if v.time then
      local iM, iS, iPS = string.match(v.time, "(%d+):(%d+)%.(%d+)")
      if iM and iS and iPS then
        table.insert(result['TIME_PROCESS'], { value = iM*60+iS+iPS/100, source = psPlugin.source .. "." .. v.name })
      else
        iM, iS = string.match(v.time, "(%d+):(%d+)")
        if iM and iS then
          table.insert(result['TIME_PROCESS'], { value = iM*60+iS, source = psPlugin.source .. "." .. v.name })
        else
          io.stderr:write("Time value incorrectly formatted =>" .. v.time)
        end
      end
    end
  end
  return result
end

meterPlugin:run()
psPlugin:run()
