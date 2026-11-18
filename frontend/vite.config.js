import { defineConfig } from 'vite'
import elmPlugin from 'vite-plugin-elm'

export default defineConfig({
  plugins: [elmPlugin()],
  server: {
    proxy: {
      '/api': 'http://localhost:8000',
    },
  },
})
