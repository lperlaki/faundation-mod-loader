-------------------------------------------------------------------------------
-- Decode
-------------------------------------------------------------------------------

local parse

local function create_set(...)
  local res = {}
  for i = 1, select("#", ...) do
    res[ select(i, ...) ] = true
  end
  return res
end

local space_chars   = create_set(" ", "\t", "\r", "\n")
local delim_chars   = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
local escape_chars  = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
local literals      = create_set("true", "false", "null")

local literal_map = {
  [ "true"  ] = true,
  [ "false" ] = false,
  [ "null"  ] = nil,
}


local function next_char(str, idx, set, negate)
  for i = idx, #str do
    if set[str:sub(i, i)] ~= negate then
      return i
    end
  end
  return #str + 1
end


local function decode_error(str, idx, msg)
  local line_count = 1
  local col_count = 1
  for i = 1, idx - 1 do
    col_count = col_count + 1
    if str:sub(i, i) == "\n" then
      line_count = line_count + 1
      col_count = 1
    end
  end
  error( string.format("%s at line %d col %d", msg, line_count, col_count) )
end


local function codepoint_to_utf8(n)
  -- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa
  local f = math.floor
  if n <= 0x7f then
    return string.char(n)
  elseif n <= 0x7ff then
    return string.char(f(n / 64) + 192, n % 64 + 128)
  elseif n <= 0xffff then
    return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
  elseif n <= 0x10ffff then
    return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128,
                       f(n % 4096 / 64) + 128, n % 64 + 128)
  end
  error( string.format("invalid unicode codepoint '%x'", n) )
end


local function parse_unicode_escape(s)
  local n1 = tonumber( s:sub(3, 6),  16 )
  local n2 = tonumber( s:sub(9, 12), 16 )
  -- Surrogate pair?
  if n2 then
    return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
  else
    return codepoint_to_utf8(n1)
  end
end


local function parse_string(str, i)
  local has_unicode_escape = false
  local has_surrogate_escape = false
  local has_escape = false
  local last
  for j = i + 1, #str do
    local x = str:byte(j)

    if x < 32 then
      decode_error(str, j, "control character in string")
    end

    if last == 92 then -- "\\" (escape char)
      if x == 117 then -- "u" (unicode escape sequence)
        local hex = str:sub(j + 1, j + 5)
        if not hex:find("%x%x%x%x") then
          decode_error(str, j, "invalid unicode escape in string")
        end
        if hex:find("^[dD][89aAbB]") then
          has_surrogate_escape = true
        else
          has_unicode_escape = true
        end
      else
        local c = string.char(x)
        if not escape_chars[c] then
          decode_error(str, j, "invalid escape char '" .. c .. "' in string")
        end
        has_escape = true
      end
      last = nil

    elseif x == 34 then -- '"' (end of string)
      local s = str:sub(i + 1, j - 1)
      if has_surrogate_escape then
        s = s:gsub("\\u[dD][89aAbB]..\\u....", parse_unicode_escape)
      end
      if has_unicode_escape then
        s = s:gsub("\\u....", parse_unicode_escape)
      end
      if has_escape then
        s = s:gsub("\\.", escape_char_map_inv)
      end
      return s, j + 1

    else
      last = x
    end
  end
  decode_error(str, i, "expected closing quote for string")
end


local function parse_number(str, i)
  local x = next_char(str, i, delim_chars)
  local s = str:sub(i, x - 1)
  local n = tonumber(s)
  if not n then
    decode_error(str, i, "invalid number '" .. s .. "'")
  end
  return n, x
end


local function parse_literal(str, i)
  local x = next_char(str, i, delim_chars)
  local word = str:sub(i, x - 1)
  if not literals[word] then
    decode_error(str, i, "invalid literal '" .. word .. "'")
  end
  return literal_map[word], x
end


local function parse_array(str, i)
  local res = {}
  local n = 1
  i = i + 1
  while 1 do
    local x
    i = next_char(str, i, space_chars, true)
    -- Empty / end of array?
    if str:sub(i, i) == "]" then
      i = i + 1
      break
    end
    -- Read token
    x, i = parse(str, i)
    res[n] = x
    n = n + 1
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "]" then break end
    if chr ~= "," then decode_error(str, i, "expected ']' or ','") end
  end
  return res, i
end


local function parse_object(str, i)
  local res = {}
  i = i + 1
  while 1 do
    local key, val
    i = next_char(str, i, space_chars, true)
    -- Empty / end of object?
    if str:sub(i, i) == "}" then
      i = i + 1
      break
    end
    -- Read key
    if str:sub(i, i) ~= '"' then
      decode_error(str, i, "expected string for key")
    end
    key, i = parse(str, i)
    -- Read ':' delimiter
    i = next_char(str, i, space_chars, true)
    if str:sub(i, i) ~= ":" then
      decode_error(str, i, "expected ':' after key")
    end
    i = next_char(str, i + 1, space_chars, true)
    -- Read value
    val, i = parse(str, i)
    -- Set
    res[key] = val
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "}" then break end
    if chr ~= "," then decode_error(str, i, "expected '}' or ','") end
  end
  return res, i
end


local char_func_map = {
  [ '"' ] = parse_string,
  [ "0" ] = parse_number,
  [ "1" ] = parse_number,
  [ "2" ] = parse_number,
  [ "3" ] = parse_number,
  [ "4" ] = parse_number,
  [ "5" ] = parse_number,
  [ "6" ] = parse_number,
  [ "7" ] = parse_number,
  [ "8" ] = parse_number,
  [ "9" ] = parse_number,
  [ "-" ] = parse_number,
  [ "t" ] = parse_literal,
  [ "f" ] = parse_literal,
  [ "n" ] = parse_literal,
  [ "[" ] = parse_array,
  [ "{" ] = parse_object,
}


parse = function(str, idx)
  local chr = str:sub(idx, idx)
  local f = char_func_map[chr]
  if f then
    return f(str, idx)
  end
  decode_error(str, idx, "unexpected character '" .. chr .. "'")
end

local json = {}

function json.decode(str)
  if type(str) ~= "string" then
    error("expected argument of type string, got " .. type(str))
  end
  local res, idx = parse(str, next_char(str, 1, space_chars, true))
  idx = next_char(str, idx, space_chars, true)
  if idx <= #str then
    decode_error(str, idx, "trailing garbage")
  end
  return res
end

-------------------------------------------------------------------------------
-- Decode File
-------------------------------------------------------------------------------

function json.decodeFile(path)
  if path then
    local file = io.open(path, "r")
    if file then
      local table = json.decode(file:read("*a"))
      file:close()
      return table
    else
      error("Could not Find file " .. path)
    end
  end
end

-------------------------------------------------------------------------------
-- ls function
-------------------------------------------------------------------------------


local function isWindows()
  return package.config:sub(1,1) ='/'
end

local function listDir( path )
  path = path or '.'
  if isWindows() then
    local file = io.popen('cd ' .. path .. '; dir')
  else
    local file = io.popen('cd ' .. path .. '; ls')
  end
  local arr = {}
  for line in file:lines() do
    table.insert (arr, line);
  end
  file:close()
  return arr
end

local function hasValue (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end



-------------------------------------------------------------------------------
-- RegisterAsset Function
-------------------------------------------------------------------------------

local loader = {
  Name = 'BASE'
}

function loader:log( message, level )
  if self.Mod then
    -- local message = '\t\tLOADER::' .. self.Name .. '\t\t' .. message --message Formating
    if level == 'WARNING' then
      self.Mod:logWarning(message)
    elseif level == 'ERROR' then
      self.Mod:logError(message)
    else
      self.Mod:log(message)
    end
  end
end

function loader:registerAsset(path)
  if self.Mod then
    -- load asset from JSON file
    local asset = json.decodeFile(self.Prefix .. path)
    if asset then
        -- registerAssetIds defined in the Models field of the asset
        if asset.Models then
            for name, path in pairs(asset.Models) do
                self.Mod:registerAssetId(path, name)
            end
            asset.Models = nil
        end
        -- register The asset
        self.Mod:register(asset)
        self:log('added ' .. asset.Id .. ' to the Game')
    else
        self:log('could not load ' .. path, 'ERROR')
    end
  end
end

function loader:checkDependencies()
  if self.Dependencies then
    local mods = listDir('mods')
    for i, v in ipairs(self.Dependencies) do
      if not hasValue(mods, v) then
        self:log('Mod ' .. v .. ' could not be found', 'ERROR')
      end
    end
  end
end



-------------------------------------------------------------------------------
-- Loader
-------------------------------------------------------------------------------

function create( arguments )
  loader.Id = arguments.Id
  loader.Name = arguments.Name
  loader.Author = arguments.Author
  loader.Description = arguments.Description
  loader.Dependencies = arguments.Dependencies
  loader.Prefix = 'Mods/' .. arguments.Id .. '/'
  mod = foundation.createMod({
    Name = loader.Name,
    Author = loader.Author,
    Description = loader.Description
  })
  loader.Mod = mod
  loader:log('Sucessfully Loaded')
  return loader
end

return create
