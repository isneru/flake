// ==UserScript==
// @name         YouTube ad skip
// @namespace    notch
// @version      1.0
// @description  Press the skip button as soon as it appears, and seek past unskippable ads.
// @match        *://*.youtube.com/*
// @match        *://music.youtube.com/*
// @match        *://*.youtube-nocookie.com/*
// @run-at       document-idle
// @grant        none
// ==/UserScript==


(function () {
    "use strict";

    const SKIP = [
        ".ytp-ad-skip-button",
        ".ytp-ad-skip-button-modern",
        ".ytp-skip-ad-button",
        ".videoAdUiSkipButton",
    ].join(",");

    function tick() {
        const player = document.querySelector(".html5-video-player");
        if (!player) {
            return;
        }

        const button = document.querySelector(SKIP);
        if (button) {
            button.click();
            return;
        }

        if (player.classList.contains("ad-showing")) {
            const video = document.querySelector("video.html5-main-video");
            if (video && Number.isFinite(video.duration) && video.duration > 0) {
                video.currentTime = video.duration;
                if (typeof video.play === "function") {
                    video.play();
                }
            }
        }
    }

    setInterval(tick, 300);
})();
