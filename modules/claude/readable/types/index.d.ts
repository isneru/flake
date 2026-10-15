export type Renders = number

declare module 'claude-code' {
  interface PluginState {
    readable: { renders: Renders }
  }
}
