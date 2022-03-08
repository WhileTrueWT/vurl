--[[
    vurl interpreter
    viba, march 2022
    i really dont care what you do with this code
]]--

local mem = {}
local lines
local lp
local branches
local returnStack
local runCode

local commands = {
    set = function(a)
        mem[a[1]] = a[2]
    end,
    
    list = function(a)
        return a
    end,
    insert = function(a)
        table.insert(a[1], a[2], a[3])
    end,
    push = function(a)
        table.insert(a[1], a[2])
    end,
    remove = function(a)
        return table.remove(a[1], a[2]) or ""
    end,
    pop = function(a)
        return table.remove(a[1]) or ""
    end,
    index = function(a)
        return a[1][tonumber(a[2])] or ""
    end,
    replace = function(a)
        a[1][tonumber(a[2])] = a[3]
    end,
    
    add = function(a)
        return tostring(tonumber(a[1]) + tonumber(a[2]))
    end,
    sub = function(a)
        return tostring(tonumber(a[1]) - tonumber(a[2]))
    end,
    mul = function(a)
        return tostring(tonumber(a[1]) * tonumber(a[2]))
    end,
    div = function(a)
        return tostring(tonumber(a[1]) / tonumber(a[2]))
    end,
    mod = function(a)
        return tostring(tonumber(a[1]) % tonumber(a[2]))
    end,
    join = function(a)
        return a[1] .. a[2]
    end,
    len = function(a)
        return #a[1]
    end,
    substr = function(a)
        return string.sub(a[1], a[2], a[3])
    end,
    
    eq = function(a)
        return (a[1] == a[2]) and '1' or '0'
    end,
    
    gt = function(a)
        return (tonumber(a[1]) > tonumber(a[2])) and '1' or '0'
    end,
    
    lt = function(a)
        return (tonumber(a[1]) < tonumber(a[2])) and '1' or '0'
    end,
    
    gte = function(a)
        return (tonumber(a[1]) >= tonumber(a[2])) and '1' or '0'
    end,
    
    lte = function(a)
        return (tonumber(a[1]) <= tonumber(a[2])) and '1' or '0'
    end,
    
    ["and"] = function(a)
        return (a[1]==1 and a[2]==1) and '1' or '0'
    end,
    
    ["or"] = function(a)
        return (a[1]==1 or a[2]==1) and '1' or '0'
    end,
    
    ["not"] = function(a)
        return (a[1]==0) and '1' or '0'
    end,
    
    ["if"] = function(a)
        if a[1]=='0' then
            lp = branches[lp]
        end
    end,
    
    ["while"] = function(a)
        if a[1]=='0' then
            lp = branches[lp]
        end
    end,
    
    define = function(a)
        mem[a[1]] = lp
        lp = branches[lp]
    end,
    
    call = function(a)
        table.insert(returnStack, lp)
        lp = mem[a[1]]
    end,
    
    ["end"] = function(a)
        if branches[lp].type == "while" then
            lp = branches[lp].value - 1
        elseif branches[lp].type == "define" then
            lp = table.remove(returnStack)
        end
    end,
    
    print = function(a)
        print(a[1])
    end,
    input = function(a)
        return io.read()
    end,
}

local function parseLine(line)
    local l = {}
    
    local command, argstring = string.match(line, "^%s*(%S+)%s?(.*)$")
    
    local isInQuotes = false
    local parensLevel = 0
    local args = {}
    local a = ""
    local c = 1
    while c <= #argstring do
        local char = string.sub(argstring, c, c)
        
        if char == '"' then
            isInQuotes = not isInQuotes
            a = a .. char
        elseif char == "(" then
            parensLevel = parensLevel + 1
            a = a .. char
        elseif char == ")" then
            parensLevel = parensLevel - 1
            a = a .. char
        elseif (not isInQuotes) and (parensLevel <= 0) and string.match(char, "%s") then
            table.insert(args, a)
            a = ""
        else
            a = a .. char
        end
        
        c = c + 1
    end
    if #a > 0 then
        table.insert(args, a)
    end
    
    local parsedArgs = {}
    for i, arg in ipairs(args) do
        if string.match(arg, "^%[.+%]$") then
            parsedArgs[i] = {type="var", value=string.sub(arg, 2, -2)}
        elseif string.match(arg, "^%(.+%)$") then
            parsedArgs[i] = {type="cmd", value=parseLine(string.sub(arg, 2, -2))}
        elseif string.match(arg, "^\"(.+)\"$") then
            parsedArgs[i] = {type="lit", value=string.sub(arg, 2, -2)}
        else
            parsedArgs[i] = {type="lit", value=arg}
        end
    end
    
    l.command = command
    l.args = parsedArgs

    return l
end

function run(code)
    lines = {}
    branches = {}
    returnStack = {}
    local branchStack = {}
    
    local lineNumber = 1
    for line in string.gmatch(code, "[^\n]+") do
        if (not string.match(line, "^%s*#%s")) and (not string.match(line, "^%s+$")) then
            local pl = parseLine(line)
            table.insert(lines, pl)

            if pl.command == "if"
            or pl.command == "while"
            or pl.command == "define" then
                table.insert(branchStack, {type=pl.command, value=lineNumber})
            elseif pl.command == "end" then
                local b = table.remove(branchStack)
                branches[lineNumber] = b
                branches[b.value] = lineNumber
            end
            
            lineNumber = lineNumber + 1
        end
    end
    
    local function runLine(line)
        local args = {}
        for i, a in ipairs(line.args) do
            if a.type == "var" then
                args[i] = mem[a.value]
            elseif a.type == "cmd" then
                args[i] = runLine(a.value)
            elseif a.type == "lit" then
                args[i] = a.value
            end
        end
        assert(commands[line.command], "unknown command: " .. line.command)
        local ret = commands[line.command](args)
        return ret
    end
    
    lp = 1
    
    while lp <= #lines do
        local line = lines[lp]
        
        runLine(line)
        
        lp = lp + 1
    end
end

if arg[1] then
    local f = io.open(arg[1], "r")
    code = f:read("a")
    f:close()
    run(code)
else
    print("Usage:")
    print("./vurl.lua [filename]")
end