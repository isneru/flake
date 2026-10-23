#include "notch.hpp"

#include <algorithm>
#include <cmath>
#include <format>

#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/config/ConfigValue.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/view/Group.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/decorations/DecorationPositioner.hpp>

using namespace Render::GL;

constexpr double BAND  = 4;
constexpr double INSET = 14;
constexpr double PAD   = 6;
constexpr double GAP   = 4;
constexpr float  DIM   = 0.6;
constexpr auto   EDGES = DECORATION_EDGE_TOP | DECORATION_EDGE_BOTTOM | DECORATION_EDGE_LEFT | DECORATION_EDGE_RIGHT;

static CHyprColor color(const SP<Config::Values::CColorValue>& value, float a) {
    CHyprColor c{static_cast<uint64_t>(value->value())};
    c.a *= a;
    return c;
}

static bool blurEnabled() {
    static const auto ENABLED = CConfigValue<Config::BOOL>("decoration:blur:enabled");
    return *ENABLED;
}

static void outline(const CBox& box, double t, const CHyprColor& c, CHyprOpenGLImpl::SRectRenderData data = {}) {
    g_pHyprOpenGL->renderRect({box.x, box.y, box.w, t}, c, data);
    g_pHyprOpenGL->renderRect({box.x, box.y + box.h - t, box.w, t}, c, data);
    g_pHyprOpenGL->renderRect({box.x, box.y + t, t, box.h - 2 * t}, c, data);
    g_pHyprOpenGL->renderRect({box.x + box.w - t, box.y + t, t, box.h - 2 * t}, c, data);
}

CNotch::CNotch(PHLWINDOW window) : IHyprWindowDecoration(window), m_window(window) {}

CNotch::~CNotch() {
    damageEntire();
}

SDecorationPositioningInfo CNotch::getPositioningInfo() {
    SDecorationPositioningInfo info;
    info.policy         = DECORATION_POSITION_STICKY;
    info.reserved       = true;
    info.priority       = 9990;
    info.edges          = EDGES;
    info.desiredExtents = {{BAND, BAND}, {BAND, BAND}};
    return info;
}

void CNotch::onPositioningReply(const SDecorationPositioningReply& reply) {
    m_assigned = reply.assignedGeometry;
}

eDecorationType CNotch::getDecorationType() {
    return DECORATION_CUSTOM;
}

uint64_t CNotch::getDecorationFlags() {
    return DECORATION_PART_OF_MAIN_WINDOW;
}

eDecorationLayer CNotch::getDecorationLayer() {
    return DECORATION_LAYER_OVER;
}

std::string CNotch::getDisplayName() {
    return "athanor-notch";
}

void CNotch::updateWindow(PHLWINDOW) {
    damageEntire();
}

CBox CNotch::frameBox() {
    const auto window    = m_window.lock();
    const auto workspace = window->m_workspace;
    const auto offset    = workspace && !window->m_pinned ? workspace->m_renderOffset->value() : Vector2D{};
    return m_assigned.copy().translate(g_pDecorationPositioner->getEdgeDefinedPoint(EDGES, window)).translate(window->m_floatingOffset + offset);
}

bool CNotch::glass() {
    const auto window = m_window.lock();
    return window && blurEnabled() && !window->m_ruleApplicator->noBlur().valueOrDefault() && CHyprColor{static_cast<uint64_t>(config.bg->value())}.a < 1;
}

bool CNotch::xray() {
    return glass() && g_pHyprRenderer->shouldUseNewBlurOptimizations(nullptr, m_window.lock());
}

CBox CNotch::reach() {
    return frameBox().expand(config.fontSize->value());
}

void CNotch::damageEntire() {
    if (validMapped(m_window))
        g_pHyprRenderer->damageBox(frameBox().expand(config.fontSize->value()));
}

bool CNotch::shown() {
    if (!validMapped(m_window))
        return false;
    const auto window = m_window.lock();
    return window->m_ruleApplicator->decorate().valueOrDefault() && !Fullscreen::controller()->isFullscreen(window);
}

void CNotch::draw(PHLMONITOR, float const& a) {
    if (shown())
        g_pHyprRenderer->m_renderPass.add(makeUnique<CNotchPass>(this, a));
}

void CNotch::drawPass(PHLMONITOR monitor, float a) {
    const auto   window = m_window.lock();
    const double scale  = monitor->m_scale;

    CBox         box = frameBox().translate(-monitor->m_position).scale(scale).round();
    if (box.w < 1 || box.h < 1)
        return;

    const bool focused    = Desktop::focusState()->window() == window;
    const auto inkSetting = focused ? config.active : config.rule;
    const auto ink        = color(inkSetting, a);
    const bool glass      = this->glass();
    auto       paper      = color(config.bg, a);
    if (!glass)
        paper.a = a;
    const auto band       = std::round(BAND * scale);
    const auto line       = std::max(1.0, std::round(scale));

    g_pHyprOpenGL->scissor(nullptr);
    const CHyprOpenGLImpl::SRectRenderData fill = {.blur = glass, .blurA = a, .xray = xray()};
    outline(box, band, paper, fill);
    outline(box, line, ink);
    if (focused)
        outline(box.copy().expand(line - band), line, ink);

    const auto group = window->m_group;
    if (!group && window->m_ruleApplicator->m_tagKeeper.isTagged("notitle"))
        return;

    std::vector<PHLWINDOW> tabs;
    if (group) {
        for (const auto& ref : group->windows())
            if (const auto tab = ref.lock())
                tabs.push_back(tab);
    } else
        tabs.push_back(window);
    if (tabs.empty())
        return;

    const int px       = std::round(config.fontSize->value() * scale);
    const int inset    = std::round(INSET * scale);
    const int pad      = std::round(PAD * scale);
    const int gap      = std::round(GAP * scale);
    const int maxWidth = (box.w - 2 * inset - (tabs.size() - 1) * gap) / tabs.size() - 2 * pad;
    if (maxWidth < px)
        return;

    m_titles.resize(tabs.size());
    double x = box.x + inset;
    for (size_t i = 0; i < tabs.size(); ++i) {
        const auto& tab     = tabs[i];
        const bool  current = tab == window;
        const auto  title   = tab->m_title.empty() && group ? tab->m_class : tab->m_title;
        if (title.empty())
            continue;

        const auto setting      = current ? inkSetting : config.rule;
        const auto key          = std::format("{}\n{}\n{}\n{}\n{:x}", title, px, maxWidth, config.font->value(), setting->value());
        auto& [cached, texture] = m_titles[i];
        if (key != cached || !texture) {
            texture = g_pHyprRenderer->renderText(title, color(setting, 1), px, false, config.font->value(), maxWidth);
            cached  = key;
        }
        if (!texture)
            continue;

        const auto size    = texture->m_size;
        const auto chipInk = color(setting, a);
        CBox       notch   = {x, box.y + std::round(band / 2 - size.y / 2), size.x + 2 * pad, size.y};
        g_pHyprOpenGL->renderRect(notch, paper, fill);
        const double above = box.y + line - notch.y;
        const double below = focused ? box.y + band - line : notch.y;
        g_pHyprOpenGL->renderRect({notch.x, notch.y, notch.w, line}, chipInk, {});
        g_pHyprOpenGL->renderRect({notch.x, notch.y + notch.h - line, notch.w, line}, chipInk, {});
        for (const double side : {notch.x, notch.x + notch.w - line}) {
            g_pHyprOpenGL->renderRect({side, notch.y, line, above}, chipInk, {});
            g_pHyprOpenGL->renderRect({side, below, line, notch.y + notch.h - below}, chipInk, {});
        }
        g_pHyprOpenGL->renderTexture(texture, {notch.x + pad, notch.y, size.x, size.y}, {.a = current ? a : a * DIM});
        x += notch.w + gap;
    }
}

CNotchReach::CNotchReach(PHLWINDOW window) : IHyprWindowDecoration(window) {}

SDecorationPositioningInfo CNotchReach::getPositioningInfo() {
    SDecorationPositioningInfo info;
    info.policy         = DECORATION_POSITION_ABSOLUTE;
    info.edges          = DECORATION_EDGE_TOP;
    info.desiredExtents = {{0.0, BAND / 2 + static_cast<double>(config.fontSize->value())}, {0.0, 0.0}};
    return info;
}

void CNotchReach::onPositioningReply(const SDecorationPositioningReply&) {}

void CNotchReach::draw(PHLMONITOR, float const&) {}

eDecorationType CNotchReach::getDecorationType() {
    return DECORATION_CUSTOM;
}

void CNotchReach::updateWindow(PHLWINDOW) {}

void CNotchReach::damageEntire() {}

uint64_t CNotchReach::getDecorationFlags() {
    return DECORATION_NON_SOLID;
}

eDecorationLayer CNotchReach::getDecorationLayer() {
    return DECORATION_LAYER_BOTTOM;
}

std::string CNotchReach::getDisplayName() {
    return "athanor-reach";
}

CNotchPass::CNotchPass(CNotch* notch, float a) : m_notch(notch), m_a(a) {}

std::vector<UP<IPassElement>> CNotchPass::draw() {
    m_notch->drawPass(g_pHyprRenderer->m_renderData.pMonitor.lock(), m_a);
    return {};
}

bool CNotchPass::needsLiveBlur() {
    return m_notch->glass() && !m_notch->xray();
}

std::optional<CBox> CNotchPass::boundingBox() {
    return m_notch->reach().translate(-g_pHyprRenderer->m_renderData.pMonitor->m_position);
}

bool CNotchPass::needsPrecomputeBlur() {
    return m_notch->xray();
}

const char* CNotchPass::passName() {
    return "CNotchPass";
}

ePassElementType CNotchPass::type() {
    return EK_CUSTOM;
}
