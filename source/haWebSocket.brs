' Ephemeral HA camera/stream client; no subscriptions, reconnects or token logging.
' Roku roStreamSocket exposes TCP, not TLS: HTTPS is never downgraded.
' APIs: developer.roku.com/dev/docs/{rostreamsocket,ifsocketasync,ifevpdigest,ifdeviceinfo}
' Protocol: RFC 6455; HA components/camera/__init__.py ws_camera_stream.
function HaCameraStream(connection as dynamic, id as dynamic) as object
    fail = {ok: false, url: "", error: "Camera connection is invalid."}
    if type(connection) <> "roAssociativeArray" then return fail
    origin = HaCameraOrigin(connection.url)
    if origin = invalid or not HaCameraIdValid(id) then return fail
    if not HearthTokenValid(connection.token) then return fail
    if origin.scheme = "https"
        fail.error = "Secure WebSocket is unavailable on Roku native sockets. Showing snapshots; HTTPS was not downgraded."
        return fail
    end if
    ' roSocketAddress supports IPv4 and DNS names, not IPv6.
    if Left(origin.host, 1) = "["
        fail.error = "Native live camera sockets do not support IPv6. Showing snapshots."
        return fail
    end if
    ctx = {socket: CreateObject("roStreamSocket"), port: CreateObject("roMessagePort"), clock: CreateObject("roTimespan"), buffer: CreateObject("roByteArray"), offset: 0, fragment: invalid, error: "", upgraded: false}
    ctx.socket.SetMessagePort(ctx.port)
    ctx.socket.NotifyReadable(true)
    ctx.socket.NotifyWritable(true)
    ctx.socket.NotifyException(true)
    address = CreateObject("roSocketAddress")
    if not address.SetAddress(origin.host + ":" + origin.port.ToStr().Trim())
        ctx.socket.Close()
        return fail
    end if
    ' OS DNS resolution above is synchronous; the bounded socket transaction starts here.
    ctx.clock.Mark()
    ctx.socket.SetSendToAddress(address)
    ctx.socket.Connect()
    while not ctx.socket.IsConnected() and ctx.clock.TotalMilliseconds() < 10000
        if not ctx.socket.eOK() then exit while
        wait(20, ctx.port)
        ' Complete the same non-blocking connect; IsConnected alone retains EINPROGRESS.
        if ctx.socket.IsWritable() then ctx.socket.Connect()
    end while
    if not ctx.socket.IsConnected()
        ctx.socket.Close()
        return {ok: false, url: "", error: "Camera socket could not connect within 10 seconds."}
    end if
    ctx.socket.NotifyWritable(false)
    ctx.scratch = CreateObject("roByteArray")
    ctx.scratch[4095] = 0
    result = HaWsTransaction(ctx, origin, connection.token, id)
    if ctx.upgraded
        closeBytes = CreateObject("roByteArray")
        closeBytes.Push(3)
        closeBytes.Push(232)
        if ctx.error = "" and HaWsSendFrame(ctx, 8, closeBytes)
            ' Finish the peer's close handshake within the original transaction deadline.
            while ctx.clock.TotalMilliseconds() < 10000
                closing = HaWsNextFrame(ctx)
                if closing.kind = "close" or closing.kind = "error" then exit while
                if closing.kind = "need"
                    if not HaWsRead(ctx) then exit while
                end if
            end while
        end if
    end if
    ctx.socket.Close()
    return result
end function

function HaWsTransaction(ctx as object, origin as object, token as string, id as string) as object
    failed = {ok: false, url: "", error: "Camera WebSocket connection failed. Showing snapshots."}
    nonce = HaWsRandomBytes(16)
    if nonce = invalid then return failed
    key = nonce.ToBase64String()
    crlf = Chr(13) + Chr(10)
    request = "GET " + origin.path + "/api/websocket HTTP/1.1" + crlf + "Host: " + origin.authority + crlf + "Upgrade: websocket" + crlf + "Connection: Upgrade" + crlf + "Sec-WebSocket-Key: " + key + crlf + "Sec-WebSocket-Version: 13" + crlf + crlf
    if not HaWsSend(ctx, HaWsBytes(request)) then return failed
    headerEnd = -1
    while headerEnd < 0
        if not HaWsRead(ctx) then return HaWsFailure(ctx)
        for i = 0 to ctx.buffer.Count() - 4
            if ctx.buffer[i] = 13 and ctx.buffer[i + 1] = 10 and ctx.buffer[i + 2] = 13 and ctx.buffer[i + 3] = 10
                headerEnd = i + 4
                exit for
            end if
        end for
        if headerEnd > 8192 or (headerEnd < 0 and ctx.buffer.Count() > 8192)
            ctx.error = "Camera WebSocket handshake exceeded its size limit."
            return HaWsFailure(ctx)
        end if
    end while
    headerBytes = HaWsSlice(ctx.buffer, 0, headerEnd)
    for each value in headerBytes
        if value > 126 or (value < 32 and value <> 9 and value <> 10 and value <> 13) then return failed
    end for
    if not HaWsHandshakeValid(headerBytes.ToAsciiString(), HaWsAccept(key))
        failed.error = "Camera server rejected the WebSocket upgrade. Showing snapshots."
        return failed
    end if
    ctx.upgraded = true
    ctx.offset = headerEnd
    state = 0
    while ctx.clock.TotalMilliseconds() < 10000
        frame = HaWsNextFrame(ctx)
        if frame.kind = "need"
            if not HaWsRead(ctx) then return HaWsFailure(ctx)
        else if frame.kind = "error"
            ctx.error = "Camera server sent an invalid WebSocket frame."
            return HaWsFailure(ctx)
        else if frame.kind = "ping"
            if not HaWsSendFrame(ctx, 10, frame.payload) then return HaWsFailure(ctx)
        else if frame.kind = "close"
            HaWsSendFrame(ctx, 8, frame.payload)
            ctx.upgraded = false
            failed.error = "Camera server closed the live connection. Showing snapshots."
            return failed
        else if frame.kind = "text"
            ' Native ToAsciiString stops at NUL; JSON cannot contain an unescaped NUL.
            for each value in frame.payload
                if value = 0 then return failed
            end for
            message = ParseJson(frame.payload.ToAsciiString())
            if type(message) <> "roAssociativeArray" then return failed
            if message.type = "auth_invalid"
                failed.error = "Camera authentication was rejected. Check the Home Assistant token."
                return failed
            end if
            if state = 0 and message.type = "auth_required"
                if not HaWsSendFrame(ctx, 1, HaWsBytes(FormatJson({type: "auth", access_token: token}))) then return HaWsFailure(ctx)
                state = 1
            else if state = 1 and message.type = "auth_ok"
                if not HaWsSendFrame(ctx, 1, HaWsBytes(FormatJson({id: 1, type: "camera/stream", entity_id: id, format: "hls"}))) then return HaWsFailure(ctx)
                state = 2
            else if state = 2 and message.type = "result" and message.id = 1
                if message.success <> true
                    failed.error = "Home Assistant could not start this camera stream. Showing snapshots."
                    return failed
                end if
                if type(message.result) <> "roAssociativeArray" then return failed
                url = HaCameraStreamUrl(origin, message.result.url)
                if url = ""
                    failed.error = "Camera stream URL was not a safe same-origin HTTP URL. Showing snapshots."
                    return failed
                end if
                return {ok: true, url: url, error: ""}
            else
                failed.error = "Camera server sent an unexpected WebSocket response. Showing snapshots."
                return failed
            end if
        end if
    end while
    ctx.error = "Live camera timed out after 10 seconds. Showing snapshots."
    return HaWsFailure(ctx)
end function

function HaWsFailure(ctx as object) as object
    text = ctx.error
    if text = "" then text = "Camera connection failed. Showing snapshots."
    return {ok: false, url: "", error: text}
end function

function HaWsSend(ctx as object, bytes as object) as boolean
    sent = 0
    while sent < bytes.Count() and ctx.clock.TotalMilliseconds() < 10000
        if ctx.socket.IsWritable()
            count = ctx.socket.Send(bytes, sent, bytes.Count() - sent)
            if count > 0 then sent = sent + count
            if count < 0 and not ctx.socket.eOK() then return false
        else if not ctx.socket.eOK()
            return false
        end if
        if sent < bytes.Count() then wait(10, ctx.port)
    end while
    return sent = bytes.Count()
end function

function HaWsRead(ctx as object) as boolean
    ' Compact consumed bytes once per network read, not once per frame.
    if ctx.offset > 0
        ctx.buffer = HaWsSlice(ctx.buffer, ctx.offset, ctx.buffer.Count())
        ctx.offset = 0
    end if
    while ctx.clock.TotalMilliseconds() < 10000
        if ctx.socket.IsReadable()
            count = ctx.socket.Receive(ctx.scratch, 0, 4096)
            if count > 0
                if ctx.buffer.Count() + count > 73728
                    ctx.error = "Camera WebSocket buffer exceeded its size limit."
                    return false
                end if
                for i = 0 to count - 1
                    ctx.buffer.Push(ctx.scratch[i])
                end for
                return true
            else if count = 0
                ctx.error = "Camera server disconnected. Showing snapshots."
                return false
            else if not ctx.socket.eOK()
                exit while
            end if
        else if not ctx.socket.eOK()
            exit while
        end if
        wait(10, ctx.port)
    end while
    ctx.error = "Live camera connection failed or timed out after 10 seconds. Showing snapshots."
    return false
end function

function HaWsSendFrame(ctx as object, opcode as integer, payload as object) as boolean
    mask = HaWsRandomBytes(4)
    if mask = invalid then return false
    frame = HaWsMaskedFrame(opcode, payload, mask)
    if frame = invalid then return false
    return HaWsSend(ctx, frame)
end function

function HaWsMaskedFrame(opcode as integer, payload as object, mask as object) as dynamic
    size = payload.Count()
    if size > 65536 or mask.Count() <> 4 then return invalid
    if opcode >= 8 and size > 125 then return invalid
    frame = CreateObject("roByteArray")
    frame.Push(128 + opcode)
    if size < 126
        frame.Push(128 + size)
    else if size < 65536
        frame.Push(254)
        frame.Push(Int(size / 256))
        frame.Push(size mod 256)
    else
        frame.Push(255)
        for i = 0 to 4
            frame.Push(0)
        end for
        frame.Push(1)
        frame.Push(0)
        frame.Push(0)
    end if
    frame.Append(mask)
    for i = 0 to size - 1
        value = payload[i]
        key = mask[i mod 4]
        frame.Push((value or key) and not (value and key))
    end for
    return frame
end function

function HaWsNextFrame(ctx as object) as object
    need = {kind: "need"}
    bad = {kind: "error"}
    bytes = ctx.buffer
    offset = ctx.offset
    if bytes.Count() - offset < 2 then return need
    first = bytes[offset]
    second = bytes[offset + 1]
    if (first and 112) <> 0 or second >= 128 then return bad
    fin = first >= 128
    opcode = first and 15
    if opcode <> 0 and opcode <> 1 and opcode <> 8 and opcode <> 9 and opcode <> 10 then return bad
    length = second
    header = 2
    if length = 126
        if bytes.Count() - offset < 4 then return need
        length = bytes[offset + 2] * 256 + bytes[offset + 3]
        if length < 126 then return bad
        header = 4
    else if length = 127
        if bytes.Count() - offset < 10 then return need
        for i = 2 to 6
            if bytes[offset + i] <> 0 then return bad
        end for
        length = bytes[offset + 7] * 65536 + bytes[offset + 8] * 256 + bytes[offset + 9]
        if length < 65536 then return bad
        header = 10
    end if
    if length > 65536 then return bad
    if opcode >= 8 and (not fin or length > 125) then return bad
    if bytes.Count() - offset < header + length then return need
    payload = HaWsSlice(bytes, offset + header, offset + header + length)
    ctx.offset = offset + header + length
    if opcode = 8
        if length = 1 then return bad
        if length >= 2
            code = payload[0] * 256 + payload[1]
            validCode = (code >= 1000 and code <= 1014 and code <> 1004 and code <> 1005 and code <> 1006) or (code >= 3000 and code <= 4999)
            if not validCode then return bad
            if not HaWsUtf8Valid(payload, 2) then return bad
        end if
        return {kind: "close", payload: payload}
    end if
    if opcode = 9 then return {kind: "ping", payload: payload}
    if opcode = 10 then return {kind: "pong"}
    if opcode = 1
        if ctx.fragment <> invalid then return bad
        ctx.fragment = payload
    else
        if ctx.fragment = invalid then return bad
        if ctx.fragment.Count() + length > 65536 then return bad
        ctx.fragment.Append(payload)
    end if
    if not fin then return {kind: "fragment"}
    message = ctx.fragment
    ctx.fragment = invalid
    if not HaWsUtf8Valid(message, 0) then return bad
    return {kind: "text", payload: message}
end function

function HaWsUtf8Valid(bytes as object, start as integer) as boolean
    i = start
    while i < bytes.Count()
        value = bytes[i]
        count = 0
        low = 128
        high = 191
        if value >= 194 and value <= 223
            count = 1
        else if value >= 224 and value <= 239
            count = 2
            if value = 224 then low = 160
            if value = 237 then high = 159
        else if value >= 240 and value <= 244
            count = 3
            if value = 240 then low = 144
            if value = 244 then high = 143
        else if value > 127
            return false
        end if
        if i + count >= bytes.Count() then return false
        for j = 1 to count
            value = bytes[i + j]
            if value < low or value > high then return false
            low = 128
            high = 191
        end for
        i = i + count + 1
    end while
    return true
end function

function HaWsHandshakeValid(header as string, accept as string) as boolean
    if accept = "" then return false
    lines = header.Split(Chr(13) + Chr(10))
    if lines.Count() < 4 then return false
    if not CreateObject("roRegex", "^HTTP/1\.1 101( |$)", "").IsMatch(lines[0]) then return false
    fields = {}
    for i = 1 to lines.Count() - 1
        line = lines[i]
        if line <> ""
            colon = Instr(1, line, ":")
            if colon < 2 then return false
            name = LCase(Left(line, colon - 1))
            if not CreateObject("roRegex", "^[a-z0-9!#$%&'*+.^_`|~-]+$", "").IsMatch(name) then return false
            value = Mid(line, colon + 1).Trim()
            if fields.DoesExist(name)
                if name = "sec-websocket-accept" then return false
                fields[name] = fields[name] + "," + value
            else
                fields[name] = value
            end if
        end if
    end for
    if fields["sec-websocket-accept"] <> accept then return false
    if fields.DoesExist("sec-websocket-extensions") or fields.DoesExist("sec-websocket-protocol") then return false
    if not HaWsHeaderToken(fields["upgrade"], "websocket") then return false
    return HaWsHeaderToken(fields["connection"], "upgrade")
end function

function HaWsHeaderToken(value as dynamic, expected as string) as boolean
    if type(value) <> "String" and type(value) <> "roString" then return false
    for each part in value.Split(",")
        if LCase(part.Trim()) = expected then return true
    end for
    return false
end function

function HaWsAccept(key as string) as string
    digest = CreateObject("roEVPDigest")
    if digest.Setup("sha1") <> 0 then return ""
    bytes = CreateObject("roByteArray")
    bytes.FromHexString(digest.Process(HaWsBytes(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")))
    return bytes.ToBase64String()
end function

function HaWsRandomBytes(count as integer) as dynamic
    ' OS-generated UUID v4 randomness, never BrightScript's predictable Rnd().
    ' Omit the fixed version/variant bits when collecting nonce and masking bytes.
    randomHex = ""
    device = CreateObject("roDeviceInfo")
    while Len(randomHex) < count * 2
        uuid = device.GetRandomUUID().Replace("-", "")
        if not CreateObject("roRegex", "^[0-9a-fA-F]{32}$", "").IsMatch(uuid) then return invalid
        randomHex = randomHex + Left(uuid, 12) + Right(uuid, 12)
    end while
    bytes = CreateObject("roByteArray")
    bytes.FromHexString(Left(randomHex, count * 2))
    return bytes
end function

function HaWsBytes(text as string) as object
    bytes = CreateObject("roByteArray")
    bytes.FromAsciiString(text)
    return bytes
end function

function HaWsSlice(bytes as object, first as integer, last as integer) as object
    result = CreateObject("roByteArray")
    for i = first to last - 1
        result.Push(bytes[i])
    end for
    return result
end function

function HaCameraIdValid(id as dynamic) as boolean
    if type(id) <> "String" and type(id) <> "roString" then return false
    return Len(id) <= 255 and CreateObject("roRegex", "^camera\.[a-z0-9_]+$", "").IsMatch(id)
end function

function HaCameraOrigin(url as dynamic) as dynamic
    origin = HearthParseUrl(url)
    if origin = invalid then return invalid
    if Instr(1, url, "?") > 0 then return invalid
    return origin
end function

function HaCameraStreamUrl(origin as object, value as dynamic) as string
    if type(value) <> "String" and type(value) <> "roString" then return ""
    if Len(value) = 0 or Len(value) > 8192 then return ""
    if CreateObject("roRegex", "[\x00-\x20\x7f\\#]", "").IsMatch(value) then return ""
    ' HA has one HLS rendition. Roku stalls on its video-only master; use the media playlist.
    query = ""
    queryStart = Instr(1, value, "?")
    if queryStart > 0
        query = Mid(value, queryStart)
        value = Left(value, queryStart - 1)
    end if
    value = CreateObject("roRegex", "/master_playlist[.]m3u8$", "").Replace(value, "/playlist.m3u8") + query
    if Left(value, 1) = "/"
        if Left(value, 2) = "//" then return ""
        return origin.url + value
    end if
    parts = CreateObject("roRegex", "^(https?://[^/]+)(/.*)$", "i").Match(value)
    if parts.Count() = 0
        if Instr(1, value, ":") > 0 then return ""
        return origin.base + "/" + value
    end if
    target = HaCameraOrigin(parts[1])
    if target = invalid then return ""
    if target.scheme <> origin.scheme or target.host <> origin.host or target.port <> origin.port then return ""
    return target.url + parts[2]
end function
