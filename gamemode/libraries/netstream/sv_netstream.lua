util.AddNetworkString("VERSE::NetStream")

function netstream.Start(ply, name, ...)
    local recipients = {}
    local bShouldSend = false

    if type(ply) ~= "table" then
        if not ply then
            ply = player.GetAll()
        else
            ply = { ply }
        end
    end

    for k, v in pairs(ply) do
        if IsValid(v) and v:IsPlayer() then
            recipients[#recipients + 1] = v
            bShouldSend = true
        elseif IsValid(k) and k:IsPlayer() then
            recipients[#recipients + 1] = k
            bShouldSend = true
        end
    end

    local dataTable = { ... }
    local encodedData = pon.encode(dataTable)

    if encodedData and #encodedData > 0 and bShouldSend then
        if VERSE and VERSE.Log then
            VERSE.Log:Debug("[NetStream] → '" .. tostring(name) .. "' → " .. #recipients .. " recv | " .. #encodedData .. "b")
        end
        net.Start("VERSE::NetStream")
        net.WriteString(name)
        net.WriteUInt(#encodedData, 32)
        net.WriteData(encodedData, #encodedData)
        net.Send(recipients)
        netstream.stats.sent = netstream.stats.sent + 1
    end
end

net.Receive("VERSE::NetStream", function(_, ply)
    local NS_DS_NAME = net.ReadString()
    local NS_DS_LENGTH = net.ReadUInt(32)
    local NS_DS_DATA = net.ReadData(NS_DS_LENGTH)

    if NS_DS_NAME and NS_DS_DATA and NS_DS_LENGTH and netstream.stored[NS_DS_NAME] then
        local ok, value = pcall(pon.decode, NS_DS_DATA)
        if ok then
            if VERSE and VERSE.Log then
                VERSE.Log:Debug("[NetStream] ← '" .. tostring(NS_DS_NAME) .. "' from " .. (IsValid(ply) and ply:Nick() or "?"))
            end
            netstream.stats.received = netstream.stats.received + 1
            netstream.stored[NS_DS_NAME](ply, unpack(value))
        else
            netstream.stats.errors = netstream.stats.errors + 1
            if VERSE and VERSE.Log then
                VERSE.Log:Error("[NetStream] Ошибка декодирования '" .. tostring(NS_DS_NAME) .. "': " .. tostring(value))
            else
                ErrorNoHalt("NetStream: '" .. tostring(NS_DS_NAME) .. "'\n" .. tostring(value) .. "\n")
            end
        end
    end
end)
