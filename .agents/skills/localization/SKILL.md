---
name: localization
description: Use this skill to translate localization files
---

## Location
This skill is meant to be run inside `wetty-chat-mobile`

## Adding missing translations
First you should extract anything that needs to be translated by using

```sh
npm run extract
```

Then you should examine translation files in `locales/<language>/messages.po`
`msgstr ""` would indicate an item is missing translation

If a string got commented out after running extract that's likely because it is
not used any more. It is a good idea to remove it.

Fill in the missing translation with appropiate adaptation for the target language.
