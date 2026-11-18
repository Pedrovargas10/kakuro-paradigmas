import { defineConfig } from 'vite'
import elmPlugin from 'vite-plugin-elm'

export default defineConfig({
  plugins: [elmPlugin({ debug: false })],
  server: {
    proxy: {
      '/api': 'http://127.0.0.1:8000',
    },
  },
})
