# Obsidian + Jekyll + GitHub Pages

## Structure
- `Vault/`: your Obsidian vault (open this folder in Obsidian). **Everything in it is published** automatically: notes, subfolders, images. No config edits needed when you add files.
  - Skipped: names starting with `.` or `_` (e.g. `.obsidian`, `_templates`, `_private`) and notes with `publish: false`.
  - Don't keep private notes in `Vault/`. Put them outside it or in a `_private` folder.
- `portfolio-details/`: `home.md` (Home), `about.md` (About), any other `.md` here is added to the top menu, plus images such as `profile.svg`.
- `site/`: the theme (layouts, CSS, JS, plugin). `_config.yml`: name, description, logo, url, baseurl.

## Run locally
Needs Ruby 3.x and Bundler. From this folder:
```
bundle install        # installs into ./vendor/bundle (preconfigured, no sudo needed)
bundle exec jekyll serve --livereload
```
Open http://127.0.0.1:4000. The site rebuilds when you save in Vault/ or portfolio-details/ (if that ever fails, restart the command).

## Writing features
Wikilinks `[[Note]]`, `[[Note|alias]]`, `[[Note#Heading]]`; embeds `![[img.png]]`, `![[img.png|300]]`, `![[img.png|right|200]]`; callouts `> [!note]`; `==highlight==`; `<u>underline</u>`; math `$x$` and `$$...$$` (KaTeX); code blocks with syntax colors; tables.
Frontmatter (optional): `title`, `description`, `aliases`, `order` (sidebar sort), `publish: false`.
Table of contents: hover the bars at the right edge (click to pin); click a heading to jump.

## Publish (only when you decide)
1. Create a GitHub repo and push this folder (`.gitignore` allow-lists only the site, `Vault/`, `portfolio-details/`). Check `git status` first.
2. Settings, Pages, Source: GitHub Actions.
3. Push to `main`; `.github/workflows/pages.yml` deploys. `baseurl` is set automatically in CI.

## Attachments / pasted images
In Obsidian: Settings, Files and links, "Default location for new attachments", In the folder specified below, `_attachment`. Any `_attachment` (or `_attachments`) folder in the Vault is published for images only and is hidden from the sidebar. Embeds like `![[Pasted image 2025.png]]` are found by file name.

## Theme, callouts, tasks, highlights
- Light/dark button at the top right (remembers your choice; follows the system by default).
- Callouts: all Obsidian types and aliases, `[!type]-` / `[!type]+` foldable.
- Task lists: `- [ ]`, `- [x]`, `- [-]`.
- Highlights: `==text==` (default), or any colour from Highlightr (`<mark style="background:#hex">` or `hltr-*` classes).

This project is licensed under the [MIT License](LICENSE).

