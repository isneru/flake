// ==UserScript==
// @name         X fixup links
// @namespace    bare
// @version      1.0
// @description  Rewrite copied x.com post links to xfixup.com so they embed.
// @match        *://x.com/*
// @match        *://twitter.com/*
// @run-at       document-start
// @grant        none
// ==/UserScript==


(function () {
    "use strict";

    const LINK = /^https?:\/\/(?:www\.|mobile\.)?(?:x|twitter)\.com\/(\S+)$/;

    function fixup(text) {
        if (typeof text !== "string") {
            return text;
        }
        const match = text.trim().match(LINK);
        return match ? "https://xfixup.com/" + match[1] : text;
    }

    const proto = unsafeWindow.Clipboard.prototype;
    const writeText = proto.writeText;
    proto.writeText = function (text) {
        return writeText.call(this, fixup(text));
    };

    function selectedText() {
        const el = document.activeElement;
        if (el && (el.tagName === "TEXTAREA" || el.tagName === "INPUT")) {
            return el.value.slice(el.selectionStart, el.selectionEnd);
        }
        return String(unsafeWindow.getSelection());
    }

    document.addEventListener(
        "copy",
        function (event) {
            const text = selectedText();
            const fixed = fixup(text);
            if (fixed !== text) {
                event.clipboardData.setData("text/plain", fixed);
                event.preventDefault();
            }
        },
        true,
    );
})();
