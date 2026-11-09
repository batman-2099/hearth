function HearthTheme(mode as string) as object
    theme = {
        background: "0x151719FF", surface: "0x24282CFF", surfaceAlt: "0x343A40FF"
        text: "0xF4F3EFFF", muted: "0xBEC3C8FF", focus: "0xFFFFFFFF"
        active: "0xF2C66DFF", activeText: "0x242014FF", rule: "0x343A40FF", error: "0xFFB2A8FF"
        success: "0x75D99BFF"
        fontBody: "font:MediumSystemFont", fontBold: "font:MediumBoldSystemFont"
        smallSize: 22, bodySize: 26, headingSize: 32, valueSize: 40
    }
    if mode = "light"
        theme.background = "0xE9E8E3FF"
        theme.surface = "0xFAF9F5FF"
        theme.surfaceAlt = "0xDEDCD5FF"
        theme.text = "0x22272BFF"
        theme.muted = "0x535B62FF"
        theme.focus = "0x263D4BFF"
        theme.rule = "0xD1D1CAFF"
        theme.error = "0x9D2015FF"
        theme.success = "0x14753BFF"
    end if
    return theme
end function
