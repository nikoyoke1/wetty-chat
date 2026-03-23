# Wetty Chat Mobile (Frontend)

This is a Progressive Web Application (PWA) that supports desktop, mobile platforms
It uses Ionic Framework v8 and React

## Localization

- This project uses `lingui` for localization (i18n) support.
- When writing UI code that include user visible text, we should use `t` or `Trans`
when ever applicable.

## Style Customization
- Use a scss module when possible
- Avoid using inline styles unless it needs to be computed on the fly

## Lint
After making changes, run `npm run verify` and ensure it passes.
`npm run verify` covers both `npm run lint` and `npm run typecheck`.
