---@diagnostic disable: undefined-field, undefined-global
local stargate_Base = peripheral.find("stargate")
local stargate_Battery =  peripheral.find("jsg:stargate_" .. string.lower(stargate_Base.getGateType()) .. "_chevron_block")
local info_Screen = peripheral.find("monitor")

local completion = require("cc.completion")
local cc_Strings = require("cc.strings")

local location_Name = "xxx"
local name_Map = {"xxx", "xxx"}
local address_Map = {
    {"x", "x", "x", "x", "x", "x", "x"}
}

local address_Name_Map = {
    ["xxx"] = 1,
    ["xxx"] = 2
}

-- Booleans for gate control

local incoming_Wormhole = false                -- Is incoming wormhole
local wormhole_Stabilized = false              -- Is wormhole stable
local connection_Achieved = false              -- Is connection achieved
local stargate_Connection_Finished = true      -- Is connection finished
local no_Ack = false
local is_Valid = false
local dialing_Out = false
-- Tables for gate communication

local next_Connection = {}                     -- The next gate we must dial
local chevrons_locked = {{false, false, false}, {false, false, false}, {false, false, false}, {false, false, false}, {false, false, false}, {false, false, false}, {false, false, false}, {false, false, false}, {false, false, false}}

-- Misc Variables
local close_Timer = nil                        -- The timer for how long to keep the gate open before closing it
local ack_Timeout = nil
local time_At_Open = nil 
local time_Till_Close = nil 
local time_At_Last_Try = nil
local next_Try_Timer = nil
local next_Try = true
local caller_Hung_Up = false
local has_Energy = false
-- Event Handler
function StargateEventHandler ()
    local term_X, term_Y = term.getSize()
    local screen_X, screen_Y = info_Screen.getSize()

    -- Neverending Loop
    while 1 do
        -- Fetch the most recent event
        local eventData = {os.pullEvent()}
        -- Did we receive a message from the other gate
        if next_Try == false then
            if eventData[1] == "timer" and eventData[2] == next_Try_Timer then
                next_Try = true
            end
        end
        if eventData[1] == "received_code" then
            -- If so append it to the message queue
            if eventData[3] == "ACK_OPEN" then
                stargate_Base.sendIrisCode("ACK_ISOPEN")
                connection_Achieved = true
                stargate_Base.sendIrisCode("DEST?")
            elseif eventData[3] == "ACK_ISOPEN" then
                os.cancelTimer(ack_Timeout)
                connection_Achieved = true
            elseif eventData[3] == "DEST?" then
                stargate_Base.sendIrisCode("D:" .. next_Connection[1])
            elseif eventData[3]:sub(1, 2) == "D:" then
                if eventData[3]:sub(3, -1) ~= location_Name then
                    table.insert(next_Connection, eventData[3]:sub(3,-1))
                end
            end
        -- Did an entity pass through the gate
        elseif eventData[1] == "stargate_traveler" then
            if incoming_Wormhole == false then
                -- If so and the connection is outgoing then restart the close timer for 5 seconds
                os.cancelTimer(close_Timer)
                close_Timer = os.startTimer(5)
                time_At_Open = os.clock()
                time_Till_Close = 5
            end
        -- Did the wormhole stabilize
        elseif eventData[1] == "stargate_wormhole_stabilized" then
            wormhole_Stabilized = true
            if incoming_Wormhole == false then
                -- If so start the 2 minute close timer
                chevrons_locked[#address_Map[address_Name_Map[next_Connection[1]]]][3] = true
                close_Timer = os.startTimer(120)
                time_At_Open = os.clock()
                time_Till_Close = 120
                ack_Timeout = os.startTimer(5)
                stargate_Base.sendIrisCode("ACK_OPEN")
            end
        -- Did the gate send a incoming wormhole event
        elseif eventData[1] == "stargate_incoming_wormhole" then
            -- If the wormhole is inbound set the bool to represent that
            stargate_Connection_Finished = false
            incoming_Wormhole = true
        -- Did the timer event go off and does it match our close timer id
        elseif eventData[1] == "timer" and eventData[2] == close_Timer and wormhole_Stabilized == true then
            -- If so then close the stargate
            stargate_Base.disengageGate()
        elseif eventData[1] == "timer" and eventData[2] == ack_Timeout and wormhole_Stabilized == true then
            term.setCursorPos(1,3)
            local lines = cc_Strings.wrap("No ACK recived, traversing the wormhole is ill advised", screen_X)
            for i, v in pairs(lines) do
                info_Screen.setCursorPos(1,i+1)
                info_Screen.write(v)
            end
            no_Ack = true
        elseif eventData[1] == "stargate_failed" and eventData[2] == "caller_hung_up" then
            caller_Hung_Up = true
        -- Did the stargate send a wormhole closed event
        elseif eventData[1] == "stargate_wormhole_closed_fully" then
            -- If so set the bool the represent that
            chevrons_locked = {{false, false, false}, {false, false, false}, {false, false, false}, {false, false, false}, {false, false, false}, {false, false, false}, {false, false, false}, {false, false, false}, {false, false, false}}
            if incoming_Wormhole == false then
                time_At_Open = nil
                time_Till_Close = nil
                if caller_Hung_Up == false then
                    table.remove(next_Connection, 1)
                end
                info_Screen.clear()
                caller_Hung_Up = false
            elseif incoming_Wormhole == true and next_Connection[1] ~= nil then
                next_Try_Timer = os.startTimer(60)
                time_At_Last_Try = os.clock()
            end
            stargate_Connection_Finished = true
            no_Ack = false
            incoming_Wormhole = false
            connection_Achieved = false
            wormhole_Stabilized = false
            is_Valid = false
            dialing_Out = false
        elseif eventData[1] ==  "stargate_spin_start" then
            if incoming_Wormhole == false then
                local chevron_Number = eventData[3]
                local chevron_Lock = eventData[4]
                if chevron_Number ~= 0 then
                    chevrons_locked[chevron_Number][3] = true
                end
                chevrons_locked[chevron_Number + 1][1] = true
                if chevron_Lock == true then
                    chevrons_locked[chevron_Number + 1][2] = true
                else
                    chevrons_locked[chevron_Number + 1][2] = false
                end
                
            end
        end
    end
end

function CheckForIncoming ()
    if incoming_Wormhole == true then
        return 1
    end
    return 0
end

function StargateDialingHandler () 
    while 1 do 
        if next_Connection[1] ~= nil and next_Try == true and incoming_Wormhole == false and has_Energy == true then
            local cost_Data = stargate_Base.getEnergyRequiredToDial(address_Map[address_Name_Map[next_Connection[1]]])
            local can_Open, energy_Required_To_Keep_Open, energy_Required_To_Open = cost_Data["canOpen"], cost_Data["keepAlive"], cost_Data["open"]
            local energy_Stored = stargate_Battery.getEnergy()
            local gate_Status = stargate_Base.getGateStatus()
            time_At_Last_Try = os.clock() - 60
            if next_Try_Timer ~= nil then
                os.cancelTimer(next_Try_Timer)
            end

            if can_Open == false then
                time_At_Last_Try = os.clock()
                next_Try_Timer = os.startTimer(60)
                next_Try = false
            else
                if ((energy_Required_To_Keep_Open * 120 * 20) + energy_Required_To_Open) > energy_Stored then
                    time_At_Last_Try = os.clock()
                    next_Try_Timer = os.startTimer(60)
                    next_Try = false
                end

                dialing_Out = true
                for chevron = 1,#address_Map[address_Name_Map[next_Connection[1]]] do
                    local result = CheckForIncoming()
                    if result == 1 then
                        time_At_Last_Try = nil
                        next_Try = false
                        dialing_Out = false
                        break
                    end
                    stargate_Base.engageSymbol(address_Map[address_Name_Map[next_Connection[1]]][chevron])
                    repeat 
                        gate_Status = stargate_Base.getGateStatus()
                        os.sleep(0.5)
                    until gate_Status ~= "dialing_computer"
                    result = CheckForIncoming()
                    if result == 1 then
                        time_At_Last_Try = nil
                        next_Try = false
                        dialing_Out = false
                        break
                    end
                    if gate_Status == "failing" then
                        stargate_Base.abortDialing()
                        time_At_Last_Try = os.clock()
                        next_Try_Timer = os.startTimer(60)
                        next_Try = false
                        break
                    end
                end
                if gate_Status ~= "failing" then
                    stargate_Base.engageGate()
                    stargate_Connection_Finished = false
                    repeat 
                        os.sleep(0.5)
                    until stargate_Connection_Finished == true
                else
                    stargate_Base.abortDialing()
                    time_At_Last_Try = os.clock()
                    next_Try_Timer = os.startTimer(60)
                    next_Try = false

                end
            end
        elseif next_Connection[1] == nil and next_Try == true then
            time_At_Last_Try = nil
        end
        os.sleep(0.5)
    end
end

function GetUserDestination ()
    local term_X, term_Y = term.getSize()
    while 1 do
        if is_Valid == false then
            term.setCursorPos(1, term_Y-1)
            term.clear()
            term.write("Destination: ")

            local user_choice = _G.read(nil, nil, function(text) return completion.choice(text, name_Map) end, nil, nil)
            term.clear()
            for i, v in pairs(name_Map) do
                if v == user_choice then
                    is_Valid = true
                end
            end
            if is_Valid ~= false then
                table.insert(next_Connection, user_choice)
                local lines = cc_Strings.wrap("Scheduled trip to " .. user_choice .. ". Please wait for gate to dial", term_X)
                for i, v in pairs(lines) do
                    term.setCursorPos(1, i)
                    term.write(v)
                end
            end
        end
        os.sleep(20)
    end
end

function ScreenUpdates ()
    while 1 do
        local screen_X, screen_Y = info_Screen.getSize()
        local status = stargate_Base.getGateStatus()
        local cost_Data = {}
        local current_Energy = 0
        local total_Energy = 0
        current_Energy = stargate_Battery.getEnergy()
        total_Energy = stargate_Battery.getEnergyCapacity()
        if next_Connection[1] ~= nil then
            cost_Data = stargate_Base.getEnergyRequiredToDial(address_Map[address_Name_Map[next_Connection[1]]])
        end
        info_Screen.clear()

        info_Screen.setCursorPos(1, 1)
        info_Screen.clearLine()
        info_Screen.write("Status: ")
        if status == "idle" then
            info_Screen.write("Idle")
        elseif status == "dialing_computer" then
            info_Screen.write("Dialing Out")
        elseif status == "incoming" then
            info_Screen.write("Incoming Wormhole")
        elseif (status == "open" and incoming_Wormhole == false and wormhole_Stabilized == false)  or (status == "unstable_opening" and incoming_Wormhole == false) then
            info_Screen.write("Outgoing Wormhole Unstable")
        elseif status == "open" and incoming_Wormhole == false and wormhole_Stabilized == true then
            info_Screen.write("Outgoing Wormhole Stable")
        elseif (status == "open" and incoming_Wormhole == true and wormhole_Stabilized == false) or (status == "unstable_opening" and incoming_Wormhole == true) then
            info_Screen.write("Incoming Wormhole Unstable")
        elseif status == "open" and incoming_Wormhole == true and wormhole_Stabilized == true then
            info_Screen.write("Incoming Wormhole Stable")
        elseif status == "unstable_closing" and incoming_Wormhole == false then
            info_Screen.write("Outgoing Wormhole Closing")
        elseif status == "unstable_closing" and incoming_Wormhole == true then
            info_Screen.write("Incoming Wormhole Closing")
        else
            info_Screen.write(status)
        end


        info_Screen.setCursorPos(screen_X - 21, 1)

        if time_At_Open ~= nil then
            if math.ceil((time_At_Open + time_Till_Close) - os.clock()) < 0 then
                info_Screen.write("Time to shutdown: 0")
            else
                info_Screen.write("Time to shutdown: " .. math.ceil((time_At_Open + time_Till_Close) - os.clock()))
                
            end
        else
            info_Screen.write("Time to shutdown: N/A")
        end
        info_Screen.setCursorPos(1,6)
        info_Screen.clearLine()
        info_Screen.setCursorPos(1, 4)
        info_Screen.clearLine()

        if next_Connection[1] ~= nil then
            info_Screen.write("Next destination: " .. next_Connection[1])
            info_Screen.setCursorPos(1,6)
            if cost_Data ~= nil then
                info_Screen.write("Energy/Energy Required: " .. current_Energy .. "/" .. ((cost_Data["keepAlive"] * 120 * 20) + cost_Data["open"]))
                if ((cost_Data["keepAlive"] * 120 * 20) + cost_Data["open"]) > current_Energy then
                    has_Energy = false
                else
                    has_Energy = true
                end
            end
        else
            info_Screen.write("Next destination: N/A")
            info_Screen.setCursorPos(1,6)
            info_Screen.write("Energy/Total Energy: " .. current_Energy .. "/" .. total_Energy)
        end
        info_Screen.setCursorPos(1, 5)
        info_Screen.clearLine()
        if time_At_Last_Try ~= nil and has_Energy == true then
            if math.ceil((time_At_Last_Try + 60) - os.clock()) < 0 then
                info_Screen.write("Time to dialout attempt: Now")
            else
                info_Screen.write("Time to dialout attempt: " .. math.ceil((time_At_Last_Try + 60) - os.clock()))
            end
        else
            info_Screen.write("Time to dialout attempt: N/A")
        end

        if dialing_Out == true then

            info_Screen.setCursorPos(1, 9)
            info_Screen.write("Number")
            info_Screen.setCursorPos(12, 9)
            info_Screen.write("Name")
            info_Screen.setCursorPos(32, 9)
            info_Screen.write("Locked/Encoded")
            for i=1,9,1 do
                info_Screen.setCursorPos(1, i + 9)
                info_Screen.clearLine()
                if address_Map[address_Name_Map[next_Connection[1]]][i] ~= nil then
                    info_Screen.write("Chevron " .. (i) .. ": " .. address_Map[address_Name_Map[next_Connection[1]]][i])
                    if chevrons_locked[i][3] == true then
                        if chevrons_locked[i][1] == true then
                            if chevrons_locked[i][2] ~= true then
                                info_Screen.setCursorPos(32, i + 9)
                                info_Screen.write("ENCODED")
                            else
                                info_Screen.setCursorPos(32, i + 9)
                                info_Screen.write("LOCKED")
                            end
                        end
                    else
                        if chevrons_locked[i][1] == true then
                            info_Screen.setCursorPos(32, i + 9)
                            info_Screen.write("ENCODING")
                        else
                            info_Screen.setCursorPos(32, i + 9)
                            info_Screen.write("NOT ENCODED")
                        end
                    end
                else
                    info_Screen.write("Chevron " .. (i) .. ": " .. "Not Needed")
                    info_Screen.setCursorPos(32, i + 9)
                    info_Screen.write("NOT ENCODED")
                end
            end
        elseif incoming_Wormhole == true then
            if next_Try_Timer ~= nil then
                os.cancelTimer(next_Try_Timer)
            end
            time_At_Last_Try = nil
            info_Screen.setCursorPos(1,7)
            local lines = cc_Strings.wrap("Outgoing connections paused until incoming wormhole disconnects", screen_X)
            for i, v in pairs(lines) do
                info_Screen.setCursorPos(1, i+4)
                info_Screen.write(v)
            end
        end
        os.sleep(0.1)
    end
end

if stargate_Base.getGateStatus ~= "idle" then
    stargate_Base.disengageGate()
    stargate_Base.abortDialing()
    repeat
        os.sleep(1)
    until stargate_Base.getGateStatus() == "idle"
    wormhole_Stabilized = false
end


info_Screen.setTextScale(0.5)
info_Screen.clear()
parallel.waitForAll(StargateEventHandler, GetUserDestination, StargateDialingHandler, ScreenUpdates)


