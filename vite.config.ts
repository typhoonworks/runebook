import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'
import monaco from 'vite-plugin-monaco-editor'

// Temporary wrapper to avoid a crash in vite-plugin-ruby when `this` is
// undefined in the `config` hook under some setups (e.g., Vite 6 / CJS load).
// Ensures a minimal plugin context with `meta` exists before delegating.
function RubyPluginPatched() {
  const plugins = RubyPlugin()
  return plugins.map((p: any) => {
    if (p && typeof p === 'object' && typeof p.config === 'function') {
      const orig = p.config
      return {
        ...p,
        config(this: any, userConfig: any, env: any) {
          const ctx: any = this && typeof this === 'object' ? this : {}
          if (!('meta' in ctx)) ctx.meta = {}
          return orig.call(ctx, userConfig, env)
        },
      }
    }
    return p
  })
}

export default defineConfig({
  plugins: [
    // Spread the Ruby plugin array so Vite sees individual plugins
    ...RubyPluginPatched(),
    monaco({
      languages: ['ruby', 'json', 'markdown'],
    }),
  ],
})
