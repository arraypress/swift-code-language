# CodeLanguage

Filename/extension → programming-language detection for 217 languages, with display
metadata and a coarse `HighlightFamily` for fallback syntax highlighting. Pure Swift,
no dependencies, never reads file contents.

## What it does

- **`Language`** — an enum of 217 source, markup, and config languages.
- **Detection** — `Language.detect(for: URL)` / `Language.detect(filename:)` resolve a
  language from the filename alone (special filenames like `Makefile` and `.gitignore`,
  compound extensions like `.d.ts`, plain extensions, and prefix rules like
  `Dockerfile.*` / `.env.*`). Unrecognized files return `.plainText`.
- **Metadata** — `displayName`, `lineCommentToken`, and `blockComment` (a
  `BlockComment` open/close pair) per language.
- **`HighlightFamily`** — a coarse syntax family (`cLike`, `rubyLike`, `shellLike`,
  `markup`, `config`, `sql`, …) via `language.family`, for driving regex-fallback
  highlighting when no dedicated grammar exists.

## Usage

```swift
import CodeLanguage

let lang = Language.detect(for: URL(fileURLWithPath: "/repo/Sources/main.swift"))
// .swift

lang.displayName        // "Swift"
lang.lineCommentToken   // "//"
lang.blockComment       // BlockComment(open: "/*", close: "*/")
lang.family             // .cLike

Language.detect(filename: "Dockerfile.prod")  // .dockerfile
Language.detect(filename: ".env.local")       // .dotenv
Language.detect(filename: ".envrc")           // .bash (direnv script)
Language.detect(filename: "mystery.zzq")      // .plainText
```

## Requirements

- Swift 5.9+
- macOS 10.15+ / iOS 13+ / tvOS 13+ / watchOS 6+ / visionOS 1+

## Installation

```swift
.package(path: "../swift-code-language")  // or your fork's URL
```

Then add `"CodeLanguage"` to your target's dependencies.
