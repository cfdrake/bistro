local midi_lib = {}

function midi_lib.init()
  midi_out = nil
  io_prefix = {"MIDI_in", "MIDI_out"} -- we'll set up many parameters which use these two prefixes
    
  params:add_separator("outgoing MIDI") -- separators help keep the PARAMETERS menu UI clean
    
  midi_out = midi.connect(1) -- connect both midi input and output to vport 1
    
  params:add_number("MIDI_out_device", "device", 1, #midi.vports, 1) -- vport selector
  params:set_action("MIDI_out_device", function(x) -- when this parameter changes, peform the following:
    midi_out = midi.connect(x) -- update the script's MIDI input or output device
    midi_lib.update_midi_params() -- update the params to match the newly-selected device
  end)
  
  params:add_text("MIDI_out_name", ">>> device name", midi_out.name) -- display the selected vport's device name
  
  params:add_text("MIDI_out_state", ">>> device connected", tostring(midi_out.connected)) -- display the selected vport's connected state
  
  params:add_number("MIDI_out_channel", "channel", 1, 16, 1)
  params:add_number("MIDI_out_velocity", "velocity", 0, 127, 100)
  
end

function midi_lib.update_midi_params() -- updates info-only parameters, to help user identify port/device pairs
  params:set("MIDI_out_name",midi_out.name)
  params:set("MIDI_out_state",tostring(midi_out.connected))
end

function midi.add() -- this gets called when a MIDI device is registered
  midi_lib.update_midi_params() -- update params
end

function midi.remove() -- this gets called when a MIDI device is removed
  clock.run(
    function()
      clock.sleep(0.25) -- wait a 1/4 second for the device to be released
        midi_lib.update_midi_params() -- update params
    end
  )
end

return midi_lib