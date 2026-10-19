// ==UserScript==
// @name         X minimal
// @namespace    bare
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
[data-testid="sidebarColumn"],
html:not(.x-nav) header[role="banner"] {
    display: none !important;
}

html.x-nav header[role="banner"] {
    position: fixed !important;
    top: 0;
    bottom: 0;
    left: 0;
    padding-left: 0 !important;
    align-items: flex-start !important;
}

main[role="main"] > div {
    width: 100% !important;
    max-width: none !important;
}

[data-testid="primaryColumn"] > div > .r-1ye8kvj {
    max-width: none !important;
}

[data-testid="primaryColumn"] {
    width: 100% !important;
    max-width: 1100px !important;
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

#x-nav-toggle {
    position: fixed;
    top: 12px;
    left: 12px;
    z-index: 1000;
    width: 36px;
    height: 36px;
    border: 1px solid rgba(113, 118, 123, 0.4);
    border-radius: 9999px;
    background: transparent;
    color: rgb(113, 118, 123);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 0;
    cursor: pointer;
}

#x-nav-toggle:hover {
    border-color: rgb(29, 155, 240);
    color: rgb(29, 155, 240);
}
`;

    const style = document.createElement("style");
    style.textContent = CSS;

    const button = document.createElement("button");
    button.id = "x-nav-toggle";
    button.title = "Toggle navigation";
    const SVG = "http://www.w3.org/2000/svg";
    const icon = document.createElementNS(SVG, "svg");
    icon.setAttribute("width", "18");
    icon.setAttribute("height", "18");
    icon.setAttribute("viewBox", "0 0 18 18");
    icon.setAttribute("stroke", "currentColor");
    icon.setAttribute("stroke-width", "1.75");
    icon.setAttribute("stroke-linecap", "round");
    for (const y of [4, 9, 14]) {
        const line = document.createElementNS(SVG, "line");
        line.setAttribute("x1", "3");
        line.setAttribute("x2", "15");
        line.setAttribute("y1", String(y));
        line.setAttribute("y2", String(y));
        icon.appendChild(line);
    }
    button.appendChild(icon);
    button.addEventListener("click", function () {
        document.documentElement.classList.toggle("x-nav");
    });

    function attach() {
        const parent = document.head || document.documentElement;
        if (parent && !style.isConnected) {
            parent.appendChild(style);
        }
        if (document.body && !button.isConnected) {
            document.body.appendChild(button);
        }
        return style.isConnected && button.isConnected;
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
