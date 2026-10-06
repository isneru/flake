// ==UserScript==
// @name         X minimal
// @namespace    notch
// @version      1.0
// @description  Drop the trends rail, view counts and upsells, and centre the timeline.
// @match        *://x.com/*
// @match        *://twitter.com/*
// @run-at       document-start
// @grant        none
// ==/UserScript==


(function () {
    "use strict";

    const CSS = `
[data-testid="sidebarColumn"] {
    display: none !important;
}

[data-testid="primaryColumn"] {
    width: 100% !important;
    max-width: 1000px !important;
    margin: 0 auto !important;
    border-left-width: 1px !important;
    border-right-width: 1px !important;
}

[aria-label="Timeline: Trending now"],
[aria-label="Who to follow"],
[aria-label="Subscribe to Premium"],
[data-testid="premium-signup-tab"],
[data-testid="inlinePrompt"],
[data-testid="pinned-timeline-item"] {
    display: none !important;
}

article a[href$="/analytics"] {
    display: none !important;
}

[data-testid="tweet"] [data-testid="caret"] {
    opacity: 0;
    transition: opacity 120ms ease;
}

[data-testid="tweet"]:hover [data-testid="caret"] {
    opacity: 1;
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
