/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/views/**/*.{erb,html,html.erb}",
    "./app/helpers/**/*.rb",
    "./app/frontend/**/*.{js,ts,jsx,tsx,vue,css}",
    "./config/initializers/**/*.rb",
  ],
  theme: {
    extend: {},
  },
  plugins: [
    require("@tailwindcss/forms"),
    require("@tailwindcss/typography"),
    require("daisyui"),
  ],
  daisyui: {
    themes: [
      {
        runebook: {
          primary: "#cc0000", // Rails red
          "primary-content": "#ffffff",
          secondary: "#7c3aed",
          accent: "#2563eb",
          neutral: "#1f2937",
          "base-100": "#ffffff",
          "base-200": "#f6f7f9",
          "base-300": "#e5e7eb",
          info: "#0ea5e9",
          success: "#16a34a",
          warning: "#f59e0b",
          error: "#dc2626",
        },
      },
      {
        "runebook-dark": {
          primary: "#ef4444",
          "primary-content": "#1b0a0a",
          secondary: "#a78bfa",
          accent: "#60a5fa",
          neutral: "#111827",
          "base-100": "#0b0f14",
          "base-200": "#0f141b",
          "base-300": "#1f2937",
          info: "#38bdf8",
          success: "#22c55e",
          warning: "#fbbf24",
          error: "#f87171",
        },
      },
      "light",
      "dark",
    ],
  },
};
