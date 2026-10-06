// ==UserScript==
// @name         YouTube declutter
// @namespace    notch
// @version      2.0
// @description  Hide Shorts, merch and donation shelves, and the player ad slot.
// @match        *://www.youtube.com/*
// @match        *://youtube.com/*
// @run-at       document-start
// @grant        none
// ==/UserScript==


(function () {
    "use strict";

    const CSS = `
#items.ytd-grid-renderer > ytd-grid-video-renderer:has(
    ytd-thumbnail-overlay-time-status-renderer[overlay-style="SHORTS"]) {
    display: none;
}

ytd-item-section-renderer:not(:has(ytd-grid-renderer)):has(
    ytd-thumbnail-overlay-time-status-renderer[overlay-style="SHORTS"]) {
    display: none;
}

ytd-reel-shelf-renderer,
ytd-rich-shelf-renderer[is-shorts],
ytd-rich-section-renderer:has(ytd-rich-shelf-renderer[is-shorts]),
ytd-video-renderer:has(a[href^="/shorts/"]),
ytd-rich-item-renderer:has(a[href^="/shorts/"]) {
    display: none !important;
}

ytd-guide-entry-renderer:has(a#endpoint[title="Shorts"]),
ytd-mini-guide-entry-renderer[aria-label="Shorts"] {
    display: none !important;
}

ytd-merch-shelf-renderer,
ytd-donation-shelf-renderer,
#player-ads,
ytd-video-masthead-ad-v3-renderer,
ytd-statement-banner-renderer {
    display: none !important;
}

.ytp-gradient-bottom {
    display: none !important;
}
`;

    const style = document.createElement("style");
    style.textContent = CSS;

    function attach() {
        const parent = document.head || document.documentElement;
        if (!parent) {
            return false;
        }
        parent.appendChild(style);
        return true;
    }

    if (!attach()) {
        const observer = new MutationObserver(function (_records, obs) {
            if (attach()) {
                obs.disconnect();
            }
        });
        observer.observe(document, { childList: true, subtree: true });
    }
})();
