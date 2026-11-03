---
title: Welcome
description: How this garden works and which Markdown features are supported.
---

Everything inside the `Vault` folder is published automatically. Frontmatter is optional.

## Wikilinks

Link notes with double brackets: [[Getting Started]], with an alias: [[Basic Commands|Linux commands]], or to a heading: [[Getting Started#First steps]].

## Highlight and underline

This is ==highlighted text== and this is <u>underlined text</u>. A colored highlight looks like ==important=={yellow}.

## Callouts

%%This is an author comment. It is styled as a small editorial note on the website.%%

> [!note] A note
> Callouts work like in Obsidian, with **formatting** inside.

> [!warning]
> Warnings get a warm tint.

## Code

```python
# Variables
name = "Alice"
age = 25
print(f"Name: {name}, Age: {age}")
```

## Equations

Inline math like $E = mc^2$ and display math:

$$
\int_0^1 x^2\,dx = \frac{1}{3}
$$

## Images

Drop an image into the Vault and embed it with `![[image.png]]`, resize with `![[image.png|300]]`, or float it with `![[image.png|right|200]]`.

## More callouts

> [!tip] Tip
> Use `> [!type]` for a callout. Types: note, abstract, info, todo, tip, success, question, warning, failure, danger, bug, example, quote.

> [!success]
> Green means success.

> [!danger]- Foldable and collapsed
> Click the title to open. Use `[!type]-` for collapsed and `[!type]+` for open-by-default.

> [!question]+ Foldable and open
> Click the title to close.

## Task list

- [x] Set up the site
- [ ] Write the first note
- [-] Cancelled item

## Highlight colours

==Default highlight==, <mark style="background: #FF5582A6;">red</mark>, <mark style="background: #BBFABBA6;">green</mark>, <mark style="background: #ADCCFFA6;">blue</mark>.

## Pasted images

Set Obsidian, Files and links, Default location for new attachments to `_attachment` (inside the Vault). Pasted images are published from there.
