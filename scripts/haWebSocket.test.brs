' Native bytearray tests; optional local transaction fixture configured in pkg:/websocket-fixture.json.
sub Main()
    crlf = Chr(13) + Chr(10)
    accept = "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
    AssertTrue(HaWsAccept("dGhlIHNhbXBsZSBub25jZQ==") = accept, "native SHA-1/base64 follows RFC handshake vector")
    plainOrigin = HaCameraOrigin("http://ha.local")
    AssertTrue(plainOrigin <> invalid and plainOrigin.port = 80 and plainOrigin.base = "http://ha.local", "native optional regex captures allow omitted port and path")
    header = "HTTP/1.1 101 Switching Protocols" + crlf + "Upgrade: websocket" + crlf + "Connection: keep-alive, Upgrade" + crlf + "Sec-WebSocket-Accept: " + accept + crlf + crlf
    AssertTrue(HaWsHandshakeValid(header, accept), "RFC handshake accept and case-insensitive tokens")
    AssertTrue(not HaWsHandshakeValid(header, "wrong"), "wrong accept rejected")
    AssertTrue(not HaWsHandshakeValid(header.Replace("101", "200"), accept), "non-upgrade status rejected")
    AssertTrue(not HaWsHandshakeValid(header.Replace("Upgrade: websocket", "Upgrade: h2"), accept), "wrong upgrade rejected")
    AssertTrue(not HaWsHandshakeValid(header.Replace(crlf + crlf, crlf + "Sec-WebSocket-Accept: " + accept + crlf + crlf), accept), "duplicate accept rejected")
    AssertTrue(not HaWsHandshakeValid(header.Replace(crlf + crlf, crlf + "Sec-WebSocket-Extensions: permessage-deflate" + crlf + crlf), accept), "unnegotiated extension rejected")

    mask = HexBytes("37fa213d")
    frame = HaWsMaskedFrame(1, HaWsBytes("Hello"), mask)
    AssertTrue(LCase(frame.ToHexString()) = "818537fa213d7f9f4d5158", "RFC 6455 masked Hello vector")
    ctx = Parser("810548656c6c6f")
    got = HaWsNextFrame(ctx)
    AssertTrue(got.kind = "text" and got.payload.ToAsciiString() = "Hello", "server text decoded")
    AssertTrue(HaWsNextFrame(ctx).kind = "need", "consumed frame not replayed")
    ctx = Parser("81054865")
    AssertTrue(HaWsNextFrame(ctx).kind = "need" and ctx.offset = 0, "partial TCP payload retained")
    ctx.buffer.Append(HexBytes("6c6c6f"))
    AssertTrue(HaWsNextFrame(ctx).kind = "text", "split TCP payload completed")
    ctx = Parser("0102486589012180036c6c6f")
    AssertTrue(HaWsNextFrame(ctx).kind = "fragment", "fragment begins")
    got = HaWsNextFrame(ctx)
    AssertTrue(got.kind = "ping" and got.payload.ToAsciiString() = "!", "ping interleaves with fragments")
    got = HaWsNextFrame(ctx)
    AssertTrue(got.kind = "text" and got.payload.ToAsciiString() = "Hello", "continuation completes text")
    ctx = Parser("0101e2800282ac")
    AssertTrue(HaWsNextFrame(ctx).kind = "fragment", "UTF8 can span fragments")
    AssertTrue(HaWsNextFrame(ctx).kind = "text", "split UTF8 decoded only after final fragment")
    for each bad in ["c100", "818000000000", "8000", "8200", "8300", "0900", "887e007e", "880100", "880203ed", "880203ee", "8102c080", "8103eda080", "8104f4908080", "817e0001", "817f000000000000007e", "817f8000000000000000", "817f0000000000010001"]
        AssertTrue(HaWsNextFrame(Parser(bad)).kind = "error", "malformed frame rejected: " + bad)
    end for
    ctx = Parser("010161810162")
    AssertTrue(HaWsNextFrame(ctx).kind = "fragment", "fragment pending")
    AssertTrue(HaWsNextFrame(ctx).kind = "error", "new text cannot interrupt a fragmented message")
    AssertTrue(HaWsNextFrame(Parser("880203e8")).kind = "close", "normal close accepted")
    AssertTrue(HaWsNextFrame(Parser("8a00")).kind = "pong", "unsolicited pong accepted")
    ctx = Parser("817e007e")
    for i = 1 to 126
        ctx.buffer.Push(65)
    end for
    got = HaWsNextFrame(ctx)
    AssertTrue(got.kind = "text" and got.payload.Count() = 126, "16-bit frame length")
    ctx = Parser("817f0000000000010000")
    for i = 1 to 65536
        ctx.buffer.Push(65)
    end for
    got = HaWsNextFrame(ctx)
    AssertTrue(got.kind = "text" and got.payload.Count() = 65536, "bounded 64-bit frame length")
    ctx = Parser("000141")
    ctx.fragment = got.payload
    AssertTrue(HaWsNextFrame(ctx).kind = "error", "fragment aggregate bounded to 64KiB")

    origin = HaCameraOrigin("http://homeassistant.local:8123/")
    AssertTrue(origin <> invalid and origin.port = 8123, "HTTP hostname supported")
    AssertTrue(HaCameraOrigin("http://name:secret@host") = invalid, "URL credentials rejected")
    AssertTrue(HaCameraOrigin("http://host:65536") = invalid, "invalid port rejected")
    AssertTrue(HaCameraOrigin("http://host?token=secret") = invalid, "connection query rejected")
    AssertTrue(HaCameraIdValid("camera.front_door"), "camera entity allowed")
    AssertTrue(not HaCameraIdValid("camera.front/../../other"), "entity traversal rejected")
    AssertTrue(not HearthTokenValid("token" + crlf + "Injected: header"), "header injection rejected")
    AssertTrue(HaCameraStreamUrl(origin, "/api/hls/abc/master.m3u8") = "http://homeassistant.local:8123/api/hls/abc/master.m3u8", "root-relative HA stream resolved")
    AssertTrue(HaCameraStreamUrl(origin, "api/hls/abc/master.m3u8") = "http://homeassistant.local:8123/api/hls/abc/master.m3u8", "relative HA stream resolved")
    prefixed = HaCameraOrigin("http://host:8123/ha/")
    AssertTrue(prefixed.base = "http://host:8123/ha" and prefixed.path = "/ha", "configured base path normalized")
    AssertTrue(HaCameraStreamUrl(prefixed, "api/hls/live.m3u8") = "http://host:8123/ha/api/hls/live.m3u8", "relative stream retains configured base path")
    AssertTrue(HaCameraStreamUrl(prefixed, "/api/hls/live.m3u8") = "http://host:8123/api/hls/live.m3u8", "root-relative stream uses origin not base path")
    AssertTrue(HaCameraStreamUrl(origin, "/api/hls/abc/master_playlist.m3u8") = "http://homeassistant.local:8123/api/hls/abc/playlist.m3u8", "HA master resolves to playable media playlist")
    AssertTrue(HaCameraStreamUrl(origin, "http://homeassistant.local:8123/api/hls/abc/master_playlist.m3u8?token=/master_playlist.m3u8") = "http://homeassistant.local:8123/api/hls/abc/playlist.m3u8?token=/master_playlist.m3u8", "absolute media URL retains query unchanged")
    AssertTrue(HaCameraStreamUrl(origin, "http://evil.example/api/hls/abc/master_playlist.m3u8") = "", "media playlist conversion cannot bypass origin restriction")
    for each url in ["//evil.example/live", "https://evil.example/live", "http://homeassistant.local:8123@evil.example/live", "http://homeassistant.local:8123.evil.example/live", "/" + Chr(92) + "evil.example/live", "javascript:alert(1)"]
        AssertTrue(HaCameraStreamUrl(origin, url) = "", "foreign or ambiguous stream URL rejected")
    end for
    for each url in ["http://ha.local", "HTTP://HA.local:80/base/", "https://ha.local:443/base", "http://192.0.2.1:8123", "https://[::1]/base", "http://ha.local/a@b"]
        AssertTrue(HearthConnectionValid({url: url, token: "test-token"}) and HaCameraOrigin(url) <> invalid, "saved and camera URL policies accept the same supported address")
    end for
    for each url in [invalid, 123, "", "http://user:pass@ha.local", "http://ha.local?query", "http://ha.local/#fragment", "http://ha.local:0", "http://ha.local:65536", "http://-host", "http://host-", "http://.host", "http://host.", "http://ha.local\@evil.example", "http://ha.local" + Chr(10), "http://ha.local/" + String(2048, "a")]
        AssertTrue(not HearthConnectionValid({url: url, token: "test-token"}) and HaCameraOrigin(url) = invalid, "saved and camera URL policies reject unsafe addresses")
    end for
    for each token in [invalid, 123, "", "has space", "has" + Chr(9) + "tab", "nonascii" + Chr(233), String(8193, "a")]
        AssertTrue(not HearthConnectionValid({url: "http://ha.local", token: token}) and not HearthTokenValid(token), "saved and camera token rejection agrees")
    end for
    AssertTrue(HearthTokenValid(String(8192, "a")), "camera token accepts shared length boundary")
    defaultPort = HaCameraOrigin("HTTP://HA.LOCAL:00080/base/")
    AssertTrue(defaultPort.url = "http://ha.local" and defaultPort.base = "http://ha.local/base", "default port and case canonicalized without losing base path")
    AssertTrue(HaCameraStreamUrl(defaultPort, "http://ha.local:80/live.m3u8") = "http://ha.local/live.m3u8", "explicit default port is same origin")
    AssertTrue(HaCameraStreamUrl(defaultPort, "http://ha.local/live.m3u8") = "http://ha.local/live.m3u8", "implicit default port is same origin")
    AssertTrue(HaCameraStreamUrl(defaultPort, "https://ha.local/live.m3u8") = "", "scheme change is not same origin")
    AssertTrue(HaCameraStreamUrl(defaultPort, "http://ha.local:81/live.m3u8") = "", "port change is not same origin")
    AssertTrue(HaCameraStreamUrl(defaultPort, "live.m3u8?token=a@b") = "http://ha.local/base/live.m3u8?token=a@b", "relative stream preserves base and query")
    AssertTrue(HaCameraStreamUrl(defaultPort, "//ha.local/live.m3u8") = "", "scheme-relative stream remains rejected even on same host")
    secureOrigin = HaCameraOrigin("https://HA.LOCAL:443/base")
    AssertTrue(HaCameraStreamUrl(secureOrigin, "https://ha.local/live.m3u8") = "https://ha.local/live.m3u8", "HTTPS default port uses shared same-origin policy")
    ipv6 = HaCameraStream({url: "http://[::1]", token: "test"}, "camera.front")
    AssertTrue(not ipv6.ok and ipv6.url = "", "valid saved IPv6 address remains unsupported by native live transport")
    secure = HaCameraStream({url: "https://homeassistant.local", token: "test"}, "camera.front")
    AssertTrue(not secure.ok and secure.url = "", "HTTPS never opens a plaintext socket")
    sentBytes = CreateObject("roByteArray")
    socket = {bytes: sentBytes, calls: 0, IsWritable: FixtureWritable, eOK: FixtureWritable, Send: FixtureSend}
    sendContext = {socket: socket, port: CreateObject("roMessagePort"), clock: CreateObject("roTimespan")}
    sendContext.clock.Mark()
    AssertTrue(HaWsSend(sendContext, HaWsBytes("partial writes")), "short socket sends complete")
    AssertTrue(socket.calls = 7 and sentBytes.ToAsciiString() = "partial writes", "short sends advance offsets without replay or loss")
    RunWebSocketFixture()
    print "HA_WEBSOCKET_TESTS_PASSED"
end sub

sub RunWebSocketFixture()
    text = ReadAsciiFile("pkg:/websocket-fixture.json")
    if text = ""
        print "HA_WEBSOCKET_TRANSACTIONS_SKIPPED: no local fixture configured"
        return
    end if
    config = ParseJson(text)
    AssertTrue(type(config) = "roAssociativeArray", "fixture configuration is JSON")
    origin = HaCameraOrigin(config.url)
    AssertTrue(origin <> invalid, "fixture URL is valid")
    AssertTrue(origin.scheme = "http" and origin.path = "", "fixture uses plain local HTTP without a path")
    for each scenario in ["success", "partial", "auth-rejected", "disconnect", "deadline"]
        clock = CreateObject("roTimespan")
        clock.Mark()
        result = HaCameraStream({url: config.url + "/" + scenario, token: "fixture-only"}, "camera.fixture")
        elapsed = clock.TotalMilliseconds()
        if scenario = "success" or scenario = "partial"
            AssertTrue(result.ok and result.error = "" and result.url = origin.url + "/api/hls/fixture/playlist.m3u8", scenario + ": auth and stream discovery")
        else
            AssertTrue(not result.ok and result.url = "" and result.error <> "", scenario + ": failure without a stream URL")
            if scenario = "auth-rejected" then AssertTrue(Instr(1, result.error, "authentication was rejected") > 0, "auth rejection propagated")
            if scenario = "disconnect" then AssertTrue(Instr(1, result.error, "disconnected") > 0, "midresponse disconnect propagated")
            if scenario = "deadline" then AssertTrue(elapsed >= 9000 and elapsed < 13000 and Instr(1, result.error, "timed out") > 0, "transaction deadline bounds a partial response")
        end if
    end for
    print "HA_WEBSOCKET_TRANSACTIONS_PASSED"
end sub

function FixtureWritable() as boolean
    return true
end function

function FixtureSend(bytes as object, offset as integer, count as integer) as integer
    if count > 2 then count = 2
    for i = offset to offset + count - 1
        m.bytes.Push(bytes[i])
    end for
    m.calls = m.calls + 1
    return count
end function

function HexBytes(hex as string) as object
    bytes = CreateObject("roByteArray")
    bytes.FromHexString(hex)
    return bytes
end function

function Parser(hex as string) as object
    return {buffer: HexBytes(hex), offset: 0, fragment: invalid}
end function

sub AssertTrue(condition as boolean, message as string)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub
