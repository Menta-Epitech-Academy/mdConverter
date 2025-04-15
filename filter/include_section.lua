
local json = require("dkjson")

local function printError(message)
    print("\27[31m" .. message .. "\27[0m")
end

function load_config()
    local config_file = io.open("config.json", "r")
    if not config_file then
        printError("Error: Could not open config.json")
        return nil
    end

    local config_content = config_file:read("*a")
    config_file:close()

    local config, pos, err = json.decode(config_content, 1, nil)
    if err then
        printError("Error: " .. err .. " at position " .. pos)
        return nil
    end
    print("Config loaded successfully")

    return config
end

local config = load_config()

local function shouldInclude(file_path, section, types)
    for _, part in ipairs(config.parts) do
        for _, subpart in ipairs(part.subparts) do
            if subpart.path then
                local sub_file_path = subpart.path:gsub("-exercice%.md$", "")
                if file_path:find(sub_file_path, 1, true) then
                    print("File path matches: " .. file_path)
                    if types == "tip" and subpart.showHint ~= nil then
                        print("Hint found: " .. tostring(subpart.showHint))
                        return subpart.showHint
                    elseif types == "solution" and subpart.showSolution ~= nil then
                        print("Solution found: " .. tostring(subpart.showSolution))
                        return subpart.showSolution
                    end
                end
            end
        end
    end
    return false
end



function getSectionInFile(file_path, section)
    local file = io.open(file_path, "r")
    if not file then
        printError("Error: Could not open file " .. file_path)
        return nil
    end

    local in_section = false
    local section_content = {}

    for line in file:lines() do
        if line:match('^%s*@section%s+[“"]' .. section .. '[”"]') then
            in_section = true
        elseif line:match("@section") then
            in_section = false
        elseif in_section then
            table.insert(section_content, line)
        end
    end

    file:close()
    if #section_content == 0 then
        print("Warning: Section " .. section .. " not found in file " .. file_path)
        return nil
    end
    return table.concat(section_content, "\n")
end

function Block(elem)
    if elem.t == "Para" then
        local block_text = pandoc.utils.stringify(elem)
        local new_elements = {}

        for file_path, section, types in block_text:gmatch('@include%s+“([^”]+)”%s+section=“([^”]+)”%s+type=“([^”]+)”') do
            print("Include detected: file=" .. file_path .. ", section=" .. section .. " types= " .. types)

            if shouldInclude(file_path, section, types) then
                print("include file " .. file_path .. " and section " .. section)

                local file_content = getSectionInFile(file_path, section)

                if file_content then
                    local parsed_content = pandoc.read(file_content, "markdown").blocks
                    for _, block in ipairs(parsed_content) do
                        table.insert(new_elements, block)
                    end
                else
                    printError("Error: Section " .. section .. " not found in file " .. file_path)
                end
            else
                printError("Skipping include for file " .. file_path .. " and section " .. section)
            end
        end
        if #new_elements > 0 then
            return new_elements
        end
    end
    return elem
end

