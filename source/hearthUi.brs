function HearthLabel(parent as object, text as string, x as float, y as float, width as float, height as float, color as string, size as integer) as object
    node = parent.createChild("Label")
    node.text = text
    node.translation = [x, y]
    node.width = width
    node.height = height
    node.color = color
    node.font = m.theme.fontBody
    node.font.size = size
    return node
end function

function HearthPanel(parent as object, x as float, y as float, width as float, height as float, color as string) as object
    node = parent.createChild("Poster")
    node.translation = [x, y]
    node.width = width
    node.height = height
    node.uri = "pkg:/images/panel.png"
    node.blendColor = color
    node.loadDisplayMode = "scaleToFill"
    return node
end function

function HearthRectangle(parent as object, x as float, y as float, width as float, height as float, color as string) as object
    node = parent.createChild("Rectangle")
    node.translation = [x, y]
    node.width = width
    node.height = height
    node.color = color
    return node
end function

function HearthToggle(parent as object, x as float, y as float) as object
    node = parent.createChild("Group")
    node.translation = [x, y]
    track = HearthPanel(node, 0, 0, 84, 32, m.theme.surfaceAlt)
    track.uri = "pkg:/images/toggle-track.png"
    thumb = HearthPanel(node, 4, 4, 24, 24, m.theme.muted)
    thumb.uri = "pkg:/images/toggle-thumb.png"
    return {node: node, track: track, thumb: thumb}
end function

sub HearthToggleState(toggle as object, state as string)
    toggle.node.visible = state = "on" or state = "off"
    toggle.track.blendColor = m.theme.surfaceAlt
    toggle.thumb.blendColor = m.theme.muted
    toggle.thumb.translation = [4, 4]
    if state = "on"
        toggle.track.blendColor = m.theme.active
        toggle.thumb.blendColor = m.theme.activeText
        toggle.thumb.translation = [56, 4]
    end if
end sub
