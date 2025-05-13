
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
                    if types == "hint" and subpart.showHint ~= nil then
                        print(" - hint found: " .. tostring(subpart.showHint))
                        return subpart.showHint
                    elseif types == "solution" and subpart.showSolution ~= nil then
                        print(" - Solution found: " .. tostring(subpart.showSolution))
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
    local content = file:read("*all")
    local doc = pandoc.read(content, "markdown").blocks
    file:close()
    for _, block in ipairs(doc) do
        if block.t == "Div" and block.classes:includes("section-" .. section) then
            print("- Section found: " .. section)
          return block.content
        end
    end
    printError("Error: Section " .. section .. " not found in file " .. file_path)
    return nil
end

function instert_content(content, env)
    if env == "hint" then
        if FORMAT == "html5" then
            local summary = pandoc.Plain({pandoc.Str("💡 Astuce")})
            return pandoc.Div(
              {pandoc.RawBlock('html', '<details class="hintbox">'),
               pandoc.RawBlock('html', '<summary>'),
               summary,
               pandoc.RawBlock('html', '</summary>'),
               pandoc.Div(content),
               pandoc.RawBlock('html', '</details>')})
        end
        local result = { pandoc.RawBlock("markdown", "indices : ") }
        for _, block in ipairs(content) do
            table.insert(result, block)
        end
        return result
    elseif env == "solution" then
        if FORMAT == "html5" then
            local summary = pandoc.Plain({pandoc.Str("🧩 Solution")})
            return pandoc.Div(
              {pandoc.RawBlock('html', '<details class="solutionbox">'),
               pandoc.RawBlock('html', '<summary>'),
               summary,
               pandoc.RawBlock('html', '</summary>'),
               pandoc.Div(content),
               pandoc.RawBlock('html', '</details>')})
        end
        local result = { pandoc.RawBlock("markdwon", "solution : ") }
        for _, block in ipairs(content) do
            table.insert(result, block)
        end
        return result
    else
        return content
    end
end

function Div(el)
    local env = el.classes[1]
    local new_elements = {}

    if env == "hint" or env == "solution" then
        local types = env
        local file_path = el.attributes["path"]
        local section = el.attributes["section"]

        if shouldInclude(file_path, section, types) then
            print("include file " .. file_path .. " and section " .. section)

            local content = getSectionInFile(file_path, section)

            if content then
                print("Content found for section " .. section)
                return instert_content(content, types)
            else
                printError("Error: Section " .. section .. " not found in file " .. file_path)
            end
        else
            printError("Skipping include for file " .. file_path .. " and section " .. section)
        end
    end
    return el
end

Div = Div