local chest = peripheral.find("minecraft:chest")

function check_for_sap()
    redstone.setOutput("top", false)
    for i=1, 9*3,1 do
        entry = chest.list()[i]
        if entry ~= nil then
            if entry["name"] == "minecraft:spruce_sapling" then
               if entry["count"] > 16 then
                   redstone.setOutput("top", true)
               else 
                   redstone.setOutput("top", false)
               end
           end
        end 
        
    end
end

while 1 do
    check_for_sap()
    sleep(0.1)
end
