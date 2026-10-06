import QtQuick
import "root:/singletons"
import "root:/store"

Text {
    textFormat: Text.RichText
    wrapMode: Text.WordWrap
    font.family: Style.family
    font.pixelSize: Style.body
    color: Style.dim
    linkColor: Theme.accent
    onLinkActivated: link => Moodle.browse(link)
}
