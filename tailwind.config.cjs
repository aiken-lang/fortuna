/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./src/**/*.{html,js,svelte,ts}', './node_modules/layerchart/**/*.{svelte,js}'],
  theme: {
    extend: {}
  },
  plugins: [require('@tailwindcss/typography'), require('daisyui')]
};
