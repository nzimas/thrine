-- THRINE: Enhanced 3-track random granulator
-- originally deved by @cfd90
-- extended by @nzimas
--
-- E1 volume
-- K1 long-press random 3
-- K2 randomize 1
-- KEY3 randomize 2
-- ENC2 seek 1
-- ENC3 seek 2 / seek 3 rev

engine.name = "Glut"

local ui_metro
local lfo_metros = {nil, nil, nil}
local random_seek_metros = {nil, nil, nil}

local function setup_ui_metro()
  ui_metro = metro.init()
  ui_metro.time = 1/15
  ui_metro.event = function()
    redraw()
  end
  
  ui_metro:start()
end

local function setup_params()
  params:add_separator("samples")
  
  for i=1,3 do
    params:add_file(i .. "sample", i .. " sample")
    params:set_action(i .. "sample", function(file) engine.read(i, file) end)
    
    params:add_taper(i .. "volume", i .. " volume", -60, 20, 0, 0, "dB")
    params:set_action(i .. "volume", function(value) engine.volume(i, math.pow(10, value / 20)) end)
  
    params:add_taper(i .. "speed", i .. " speed", -400, 400, 0, 0, "%")
    params:set_action(i .. "speed", function(value) engine.speed(i, value / 100) end)
  
    params:add_taper(i .. "jitter", i .. " jitter", 0, 500, 0, 5, "ms")
    params:set_action(i .. "jitter", function(value) engine.jitter(i, value / 1000) end)
  
    params:add_taper(i .. "size", i .. " size", 1, 500, 100, 5, "ms")
    params:set_action(i .. "size", function(value) engine.size(i, value / 1000) end)
  
    params:add_taper(i .. "density", i .. " density", 0, 512, 20, 6, "hz")
    params:set_action(i .. "density", function(value) engine.density(i, value) end)
  
    params:add_taper(i .. "pitch", i .. " pitch", -48, 48, 0, 0, "st")
    params:set_action(i .. "pitch", function(value) engine.pitch(i, math.pow(0.5, -value / 12)) end)
  
    params:add_taper(i .. "spread", i .. " spread", 0, 100, 0, 0, "%")
    params:set_action(i .. "spread", function(value) engine.spread(i, value / 100) end)
    
    params:add_taper(i .. "fade", i .. " att / dec", 1, 9000, 1000, 3, "ms")
    params:set_action(i .. "fade", function(value) engine.envscale(i, value / 1000) end)
    
    params:add_control(i .. "seek", i .. " seek", controlspec.new(0, 100, "lin", 0.1, i == 3 and 100 or 0, "%", 0.1/100))
    params:set_action(i .. "seek", function(value) engine.seek(i, value / 100) end)
    
    params:add_option(i .. "random_seek", i .. " randomize seek", {"off", "on"}, 1)
    params:set_action(i .. "random_seek", function(value)
      if value == 2 then
        if random_seek_metros[i] == nil then
          random_seek_metros[i] = metro.init()
          random_seek_metros[i].event = function()
            params:set(i .. "seek", math.random() * 100)
          end
        end
        random_seek_metros[i]:start(params:get(i .. "random_seek_freq") / 1000)
      else
        if random_seek_metros[i] ~= nil then
          random_seek_metros[i]:stop()
        end
      end
    end)
    
    params:add_control(i .. "random_seek_freq", i .. " random seek freq", controlspec.new(100, 20000, "lin", 100, 1000, "ms", 100/20000))
    params:set_action(i .. "random_seek_freq", function(value)
      if params:get(i .. "random_seek") == 2 and random_seek_metros[i] ~= nil then
        random_seek_metros[i].time = value / 1000
        random_seek_metros[i]:start()
      end
    end)

    params:add_option(i .. "automate_density", i .. " automate density", {"off", "on"}, 1)
    params:add_option(i .. "automate_size", i .. " automate size", {"off", "on"}, 1)
    params:set_action(i .. "automate_density", function(value)
      if value == 2 then
        if lfo_metros[i] == nil then
          lfo_metros[i] = metro.init()
          lfo_metros[i].event = function()
            if params:get(i .. "automate_density") == 2 then
              local min_density = params:get("min_density")
              local max_density = params:get("max_density")
              local lfo_value = (math.sin(util.time() * params:get(i .. "density_lfo") * 2 * math.pi) + 1) / 2
              local density = min_density + (max_density - min_density) * lfo_value
              params:set(i .. "density", density)
            end
            if params:get(i .. "automate_size") == 2 then
              local min_size = params:get("min_size")
              local max_size = params:get("max_size")
              local lfo_value = (math.sin(util.time() * params:get(i .. "size_lfo") * 2 * math.pi) + 1) / 2
              local size = min_size + (max_size - min_size) * lfo_value
              params:set(i .. "size", size)
            end
          end
        end
        lfo_metros[i]:start(1 / 30) -- Update at 30 fps
      else
        if lfo_metros[i] ~= nil then
          lfo_metros[i]:stop()
        end
      end
    end)

    params:set_action(i .. "automate_size", function(value)
      if value == 2 then
        if lfo_metros[i] == nil then
          lfo_metros[i] = metro.init()
          lfo_metros[i].event = function()
            local min_size = params:get("min_size")
            local max_size = params:get("max_size")
            local lfo_value = (math.sin(util.time() * params:get(i .. "size_lfo") * 2 * math.pi) + 1) / 2
            local size = min_size + (max_size - min_size) * lfo_value
            params:set(i .. "size", size)
          end
        end
        lfo_metros[i]:start(1 / 30) -- Update at 30 fps
      else
        if lfo_metros[i] ~= nil then
          lfo_metros[i]:stop()
        end
      end
    end)

    params:add_control(i .. "density_lfo", i .. " density lfo", controlspec.new(0.01, 10, "lin", 0.01, 0.5, "hz", 0.01/10))
    params:add_control(i .. "size_lfo", i .. " size lfo", controlspec.new(0.01, 10, "lin", 0.01, 0.5, "hz", 0.01/10))
    params:set_action(i .. "density_lfo", function(value)
      if params:get(i .. "automate_density") == 2 and lfo_metros[i] ~= nil then
        lfo_metros[i]:start()
      end
    end)
    
    params:hide(i .. "speed")
    params:hide(i .. "jitter")
    params:hide(i .. "size")
    params:hide(i .. "density")
    params:hide(i .. "pitch")
    params:hide(i .. "spread")
    params:hide(i .. "fade")
  end

  params:add_separator("reverb")
  
  params:add_taper("reverb_mix", "* mix", 0, 100, 50, 0, "%")
  params:set_action("reverb_mix", function(value) engine.reverb_mix(value / 100) end)

  params:add_taper("reverb_room", "* room", 0, 100, 50, 0, "%")
  params:set_action("reverb_room", function(value) engine.reverb_room(value / 100) end)

  params:add_taper("reverb_damp", "* damp", 0, 100, 50, 0, "%")
  params:set_action("reverb_damp", function(value) engine.reverb_damp(value / 100) end)
  
  params:add_separator("randomizer")
  
  params:add_taper("min_jitter", "jitter (min)", 0, 500, 0, 5, "ms")
  params:add_taper("max_jitter", "jitter (max)", 0, 500, 500, 5, "ms")
  
  params:add_taper("min_size", "size (min)", 1, 500, 1, 5, "ms")
  params:add_taper("max_size", "size (max)", 1, 500, 500, 5, "ms")
  
  params:add_taper("min_density", "density (min)", 0, 512, 0, 6, "hz")
  params:add_taper("max_density", "density (max)", 0, 512, 40, 6, "hz")
  
  params:add_taper("min_spread", "spread (min)", 0, 100, 0, 0, "%")
  params:add_taper("max_spread", "spread (max)", 0, 100, 100, 0, "%")
  
  params:add_taper("pitch_1", "pitch (1)", -48, 48, -12, 0, "st")
  params:add_taper("pitch_2", "pitch (2)", -48, 48, -5, 0, "st")
  params:add_taper("pitch_3", "pitch (3)", -48, 48, 0, 0, "st")
  params:add_taper("pitch_4", "pitch (4)", -48, 48, 7, 0, "st")
  params:add_taper("pitch_5", "pitch (5)", -48, 48, 12, 0, "st")

  params:bang()
end

local function random_float(l, h)
    return l + math.random()  * (h - l);
end

local function randomize(n)
  local jitter = random_float(params:get("min_jitter"), params:get("max_jitter"))
  local size = random_float(params:get("min_size"), params:get("max_size"))
  local density = random_float(params:get("min_density"), params:get("max_density"))
  local spread = random_float(params:get("min_spread"), params:get("max_spread"))
  local pitches = {params:get("pitch_1"), params:get("pitch_2"), params:get("pitch_3"),
                   params:get("pitch_4"), params:get("pitch_5")}
  local pitch_idx = math.random(1, #pitches)
  local pitch = pitches[pitch_idx]
  
  params:set(n .. "jitter", jitter)
  params:set(n .. "size", size)
  params:set(n .. "density", density)
  params:set(n .. "spread", spread)
  params:set(n .. "pitch", pitch)
end

local function setup_engine()
  engine.seek(1, 0)
  engine.gate(1, 1)
  
  engine.seek(2, 0)
  engine.gate(2, 1)
  
  engine.seek(3, 1)
  engine.gate(3, 1)

  randomize(1)
  randomize(2)
  randomize(3)
end

function init()
  setup_ui_metro()
  setup_params()
  setup_engine()
end

function enc(n, d)
  if n == 1 then
    params:delta("1volume", d)
    params:delta("2volume", d)
    params:delta("3volume", d)
  elseif n == 2 then
    params:delta("1seek", d)
  elseif n == 3 then
    params:delta("2seek", d)
    params:delta("3seek", -d)
  elseif n == 4 then
    params:delta("3seek", d)
  end
end

local key1_hold = false

function key(n, z)
  if z == 0 then
    if n == 1 and key1_hold then
      key1_hold = false
    end
    return
  end

  if n == 1 then
    key1_hold = true
    clock.run(function()
      clock.sleep(1) -- long press detection
      if key1_hold then
        randomize(3)
      end
    end)
  elseif n == 2 then
    randomize(1)
  elseif n == 3 then
    randomize(2)
  end
  
  if n == 2 then
    randomize(1)
  elseif n == 3 then
    randomize(2)
  elseif n == 4 then
    randomize(3)
  end
end

function redraw()
  screen.clear()
  screen.move(0, 10)
  screen.level(15)
  screen.text("J:")
  screen.level(5)
  screen.text(params:string("1jitter"))
  screen.level(1)
  screen.text(" / ")
  screen.level(5)
  screen.text(params:string("2jitter"))
  screen.level(1)
  screen.text(" / ")
  screen.level(5)
  screen.text(params:string("3jitter"))
  screen.move(0, 20)
  screen.level(15)
  screen.text("Sz:")
  screen.level(5)
  screen.text(params:string("1size"))
  screen.level(1)
  screen.text(" / ")
  screen.level(5)
  screen.text(params:string("2size"))
  screen.level(1)
  screen.text(" / ")
  screen.level(5)
  screen.text(params:string("3size"))
  screen.move(0, 30)
  screen.level(15)
  screen.text("D:")
  screen.level(5)
  screen.text(params:string("1density"))
  screen.level(1)
  screen.text(" / ")
  screen.level(5)
  screen.text(params:string("2density"))
  screen.level(1)
  screen.text(" / ")
  screen.level(5)
  screen.text(params:string("3density"))
  screen.move(0, 40)
  screen.level(15)
  screen.text("Sp:")
  screen.level(5)
  screen.text(params:string("1spread"))
  screen.level(1)
  screen.text(" / ")
  screen.level(5)
  screen.text(params:string("2spread"))
  screen.level(1)
  screen.text(" / ")
  screen.level(5)
  screen.text(params:string("3spread"))
  screen.move(0, 50)
  screen.level(15)
  screen.text("P:")
  screen.level(5)
  screen.text(params:string("1pitch"))
  screen.level(1)
  screen.text(" / ")
  screen.level(5)
  screen.text(params:string("2pitch"))
  screen.level(1)
  screen.text(" / ")
  screen.level(5)
  screen.text(params:string("3pitch"))
  screen.move(0, 60)
  screen.level(15)
  screen.text("Sk:")
  screen.level(5)
  screen.text(params:string("1seek"))
  screen.level(1)
  screen.text(" / ")
  screen.level(5)
  screen.text(params:string("2seek"))
  screen.level(1)
  screen.text(" / ")
  screen.level(5)
  screen.text(params:string("3seek"))
  screen.update()
end
