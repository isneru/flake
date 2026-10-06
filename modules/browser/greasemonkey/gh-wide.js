// ==UserScript==
// @name         GitHub wide layout
// @namespace    notch
// @version      1.0
// @description  Let repo, issue and pull request pages use the full window width.
// @match        *://github.com/*
// @run-at       document-start
// @grant        none
// ==/UserScript==


(function () {
    "use strict";

    const CSS = `
.container-xl,
.container-lg:not(.markdown-body) {
    max-width: none !important;
}

[class*="prc-PageLayout-PageLayoutWrapper"][data-width="xlarge"],
[class*="prc-PageLayout-PageLayoutWrapper"][data-width="large"],
[class*="prc-PageLayout-Content"][data-width="xlarge"],
[class*="prc-PageLayout-Content"][data-width="large"] {
    max-width: 100% !important;
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
