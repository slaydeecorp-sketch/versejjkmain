netstream = netstream or {}
netstream.stored = netstream.stored or {}
netstream.stats = netstream.stats or { sent = 0, received = 0, errors = 0 }

function netstream.Hook(name, Callback)
    if netstream.stored[name] and VERSE and VERSE.Log then
        VERSE.Log:Warn("[NetStream] Перезапись хука: '" .. tostring(name) .. "'")
    end
    netstream.stored[name] = Callback
end
