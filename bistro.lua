-- bistro
-- "press cafe" remake
-- by: @cfd90
-- originally by: @stretta

engine.name = "PolyPerc"

local MusicUtil = require "musicutil"

local g
local clk

local pages = {"PLAY", "PATTERNS", "LENGTHS"}
local page = 1

local tracks = {}

function init()
  g = grid.connect()
  g.key = grid_key
  
  params:add_separator()
  
  cs_AMP = controlspec.new(0,1,'lin',0,0.5,'')
  params:add{type="control",id="amp",controlspec=cs_AMP,
    action=function(x) engine.amp(x) end}

  cs_PW = controlspec.new(0,100,'lin',0,50,'%')
  params:add{type="control",id="pw",controlspec=cs_PW,
    action=function(x) engine.pw(x/100) end}

  cs_REL = controlspec.new(0.1,3.2,'lin',0,1.2,'s')
  params:add{type="control",id="release",controlspec=cs_REL,
    action=function(x) engine.release(x) end}

  cs_CUT = controlspec.new(50,5000,'exp',0,800,'hz')
  params:add{type="control",id="cutoff",controlspec=cs_CUT,
    action=function(x) engine.cutoff(x) end}

  cs_GAIN = controlspec.new(0,4,'lin',0,1,'')
  params:add{type="control",id="gain",controlspec=cs_GAIN,
    action=function(x) engine.gain(x) end}
  
  cs_PAN = controlspec.new(-1,1, 'lin',0,0,'')
  params:add{type="control",id="pan",controlspec=cs_PAN,
    action=function(x) engine.pan(x) end}
  
  params:add_separator()

  params:add_group("note data", 1 + g.cols)
  params:add_number("base_note", "base note", 1, 127, 60)
  
  local start_notes = {0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19, 21, 23, 24}
  
  for i=1,g.cols do
    local note_name = "note_" .. i
    
    params:add_number(note_name, note_name:gsub("_", " "), -24, 24, start_notes[i])
    tracks[i] = { counter = nil, pattern = nil }
  end
  
  params:add_group("pattern data", g.rows + (g.rows * g.cols))
  
  for i=1,g.rows do
    local pattern_len_name = "pattern_" .. i .. "_length"
    
    params:add_number(pattern_len_name, pattern_len_name:gsub("_", " "), 1, g.cols, g.cols)
    params:set_action(pattern_len_name, function(x)
      grid_redraw()
    end)
    
    for j=1,g.cols do
      local trig_name = "pattern_" .. i .. "_trig_" .. j
      
      params:add_number(trig_name, trig_name:gsub("_", " "), 0, 1, math.random() > 0.5 and 1 or 0)
      params:set_action(trig_name, function(x)
        grid_redraw()
      end)
    end
  end
  
  params:bang()
  params:read()
  
  clk = clock.run(tick)
  
  grid_redraw()
end

function cleanup()
  params:write()
end

function tick()
  while true do
    clock.sync(1/4)
    
    grid_redraw()
    
    for i=1,g.cols do
      local track = tracks[i]
      
      if track.pattern ~= nil and track.counter ~= nil then
        -- Play if trigged.
        local p = get_pattern(track.pattern)
        
        if p[track.counter] == 1 then
          local note = get_note(i)
          local freq = MusicUtil.note_num_to_freq(note)
          
          engine.hz(freq)
        end
        
        -- Advance counter.
        local length = get_pattern_length(track.pattern)
        
        track.counter = track.counter + 1
        
        if track.counter > length then
          track.counter = 1
        end
      end
    end
  end
end

function get_note(i)
  return params:get("note_" .. i) + params:get("base_note")
end

function get_pattern_length(i)
  return params:get("pattern_" .. i .. "_length")
end

function set_pattern_length(i, n)
  return params:set("pattern_" .. i .. "_length", n)
end

function set_pattern_trig(i, j, t)
  params:set("pattern_" .. i .. "_trig_" .. j, t)
end

function get_pattern(i)
  local p = {}
  
  for j=1,get_pattern_length(i) do
    table.insert(p, params:get("pattern_" .. i .. "_trig_" .. j))
  end
  
  return p
end

function grid_key(x, y, z)
  if page == 1 then
    -- PLAY
    if z == 1 and tracks[x].counter == nil then
      tracks[x].pattern = y
      tracks[x].counter = 1
    elseif z == 0 then
      tracks[x].pattern = nil
      tracks[x].counter = nil
    end
  elseif page == 2 then
    -- PATTERNS
    if z == 1 then
      local p = get_pattern(y)
      local t = p[x]
      
      set_pattern_trig(y, x, t == 1 and 0 or 1)
    end
  elseif page == 3 then
    -- LENGTH
    if z == 1 then
      set_pattern_length(y, x)
    end
  end
end

function grid_redraw()
  g:all(0)
  
  if page == 1 then
    -- PLAY
    for i=1,g.cols do
      local track = tracks[i]
      
      if track.pattern ~= nil and track.counter ~= nil then
        local pattern = get_pattern(track.pattern)
        local length = get_pattern_length(track.pattern)
        local c = track.counter
        
        if track.counter ~= nil then
          local ti = c
          
          for j=1,g.rows do
            ti = ti + 1
            
            if ti > length then
              ti = 1
            end
            
            local trig = pattern[ti]
            g:led(i, g.rows - j + 1, trig == 1 and 15 or 0)
          end
        end
      end
    end
  elseif page == 2 then
    -- PATTERNS
    for i=1,g.rows do
      local p = get_pattern(i)
      
      for j=1,g.cols do
        local trig = p[j]
        g:led(j, i, trig == 1 and 15 or 0)
      end
    end
  elseif page == 3 then
    -- LENGTHS
    for i=1,g.rows do
      local length = get_pattern_length(i)
      
      for j=1,length do
        g:led(j, i, 15)
      end
    end
  end
  
  g:refresh()
end

function enc(n, d)
  if n == 1 then
    page = util.clamp(page + d, 1, #pages)
  end
  
  grid_redraw()
  redraw()
end

function key(n, z)
  if z == 0 then
    return
  end
  
  if page == 1 then
    -- PLAY
    -- random notes?
  elseif page == 2 then
    -- PATTERNS
    -- random trigs?
  elseif page == 3 then
    -- LENGTH
    -- random lengths?
  end
end

function redraw()
  screen.clear()
  screen.move(0, 10)
  screen.text(pages[page])
  screen.update()
end