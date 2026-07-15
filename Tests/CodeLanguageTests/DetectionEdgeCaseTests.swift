//
//  DetectionEdgeCaseTests.swift
//  Tests for SwiftCodeLanguage
//
//  Hardened edge cases for filename-based detection and the HighlightFamily
//  fallback table. Note: `Language.detect` is filename-only by design — it
//  never reads file contents, so there is no shebang or content-sniffing
//  detection to test (the API docblock states "Never reads file contents").
//

import XCTest
@testable import CodeLanguage

final class DetectionEdgeCaseTests: XCTestCase {

    // MARK: - Extension collisions (one extension, many plausible languages)

    /// Extensions that are famously contested across ecosystems must resolve to
    /// the curated winner deterministically.
    func testContestedExtensionsResolveToCuratedWinner() {
        let cases: [(String, Language)] = [
            ("vec.h", .c),                 // C header wins over C++/Obj-C
            ("View.m", .objectivec),       // Obj-C wins over MATLAB
            ("Bridge.mm", .objectivecpp),  // Obj-C++ is distinct from .m
            ("cpu.v", .verilog),           // Verilog wins over V/Coq
            ("main.vv", .v),               // V-lang gets its own extension
            ("script.pl", .perl),          // Perl wins over Prolog
            ("facts.pro", .prolog),        // Prolog gets .pro
            ("boot.s", .assembly),         // Assembly wins over multiple
            ("harness.t", .perl),          // Perl test file
            ("stats.r", .r),
            ("clean.do", .stata),          // Stata wins over other .do users
            ("query.q", .hiveql),
            ("worksheet.sc", .scala),
            ("Program.fs", .fsharp),       // F# wins over Forth/GLSL frag
            ("thesis.cls", .latex),        // LaTeX class wins over VBA/Apex
            ("module.pp", .pascal),        // Pascal wins over Puppet
            ("lib.d", .d),                 // D-lang wins over Makefile deps
            ("shader.gs", .glsl),          // GLSL wins over Google Apps Script
            ("types.re", .reason),
            ("Model.st", .smalltalk),
            ("SUB.f", .fortran),
        ]
        for (name, expected) in cases {
            XCTAssertEqual(Language.detect(filename: name), expected, "for \(name)")
        }
    }

    /// The TypeScript-family extensions must never collide with each other
    /// (the classic .ts trap: Qt Linguist / MPEG-TS files also use .ts —
    /// the curated table awards it to TypeScript).
    func testTypeScriptFamilyExtensions() {
        XCTAssertEqual(Language.detect(filename: "app.ts"), .typescript)
        XCTAssertEqual(Language.detect(filename: "app.mts"), .typescript)
        XCTAssertEqual(Language.detect(filename: "app.cts"), .typescript)
        XCTAssertEqual(Language.detect(filename: "App.tsx"), .tsx)
        XCTAssertEqual(Language.detect(filename: "app.js"), .javascript)
        XCTAssertEqual(Language.detect(filename: "app.mjs"), .javascript)
        XCTAssertEqual(Language.detect(filename: "app.cjs"), .javascript)
        XCTAssertEqual(Language.detect(filename: "App.jsx"), .jsx)
    }

    // MARK: - Precedence: filename map > special rules > compound ext > extension map

    /// An exact filename-map hit must beat the plain extension map.
    func testFilenameMapBeatsExtensionMap() {
        // tsconfig.json → JSONC (filename map), while a generic .json stays JSON.
        XCTAssertEqual(Language.detect(filename: "tsconfig.json"), .jsonc)
        XCTAssertEqual(Language.detect(filename: "jsconfig.json"), .jsonc)
        XCTAssertEqual(Language.detect(filename: "devcontainer.json"), .jsonc)
        XCTAssertEqual(Language.detect(filename: "data.json"), .json)

        // requirements.txt → pip requirements, while .txt itself is unmapped.
        XCTAssertEqual(Language.detect(filename: "requirements.txt"), .piprequirements)
        XCTAssertEqual(Language.detect(filename: "requirements-dev.txt"), .piprequirements)
        XCTAssertEqual(Language.detect(filename: "notes.txt"), .plainText)

        // CMakeLists.txt is CMake despite the .txt suffix.
        XCTAssertEqual(Language.detect(filename: "CMakeLists.txt"), .cmake)

        // gradle.properties stays properties; build.gradle is Gradle.
        XCTAssertEqual(Language.detect(filename: "build.gradle"), .gradle)
        XCTAssertEqual(Language.detect(filename: "settings.gradle"), .gradle)
    }

    /// Extensionless well-known filenames resolve via the filename map.
    func testExtensionlessWellKnownFilenames() {
        let cases: [(String, Language)] = [
            ("Makefile", .makefile), ("GNUmakefile", .makefile),
            ("Gemfile", .ruby), ("Rakefile", .ruby), ("Podfile", .ruby),
            ("Brewfile", .ruby), ("Vagrantfile", .ruby), ("Fastfile", .ruby),
            ("Justfile", .just), ("Caddyfile", .caddyfile),
            ("Jenkinsfile", .groovy), ("Snakefile", .python),
            ("BUILD", .starlark), ("WORKSPACE", .starlark),
            ("BUILD.bazel", .starlark), ("Pipfile", .toml),
            ("go.mod", .gomod), ("crontab", .crontab), ("hosts", .hosts),
            ("nginx.conf", .nginx), ("httpd.conf", .apacheconf),
            ("COMMIT_EDITMSG", .gitcommit), ("MERGE_MSG", .gitcommit),
            ("Package.swift", .swift), ("Cargo.toml", .toml),
            ("Cargo.lock", .toml), ("poetry.lock", .toml),
            ("composer.lock", .json), ("mix.exs", .elixir),
            ("meson.build", .meson), ("flake.nix", .nix),
            ("schema.prisma", .prisma),
        ]
        for (name, expected) in cases {
            XCTAssertEqual(Language.detect(filename: name), expected, "for \(name)")
        }
    }

    /// Compound extensions must beat the plain (last-component) extension.
    func testCompoundExtensionsBeatPlainExtension() {
        XCTAssertEqual(Language.detect(filename: "welcome.blade.php"), .blade)   // not .php
        XCTAssertEqual(Language.detect(filename: "index.php"), .php)             // plain .php intact
        XCTAssertEqual(Language.detect(filename: "layout.html.erb"), .erb)       // not .erb-via-ext? both erb, but must not be .html
        XCTAssertEqual(Language.detect(filename: "partial.erb"), .erb)
    }

    /// The Dockerfile prefix rule: exact name and dotted variants, but not
    /// arbitrary names that merely contain "dockerfile".
    func testDockerfilePrefixRule() {
        XCTAssertEqual(Language.detect(filename: "Dockerfile"), .dockerfile)
        XCTAssertEqual(Language.detect(filename: "Dockerfile.prod"), .dockerfile)
        XCTAssertEqual(Language.detect(filename: "Dockerfile.multi.stage"), .dockerfile)
        XCTAssertEqual(Language.detect(filename: "Containerfile"), .dockerfile)
        XCTAssertEqual(Language.detect(filename: "app.dockerfile"), .dockerfile)  // via extension map
        XCTAssertEqual(Language.detect(filename: "mydockerfile"), .plainText)     // no prefix match
    }

    // MARK: - Dotfiles

    /// The .env family is dotenv — except .envrc, which is a direnv bash script.
    func testDotEnvFamily() {
        XCTAssertEqual(Language.detect(filename: ".env"), .dotenv)
        XCTAssertEqual(Language.detect(filename: ".env.local"), .dotenv)
        XCTAssertEqual(Language.detect(filename: ".env.production"), .dotenv)
        XCTAssertEqual(Language.detect(filename: ".env.staging.backup"), .dotenv) // prefix rule is greedy
        XCTAssertEqual(Language.detect(filename: ".flaskenv"), .dotenv)
        XCTAssertEqual(Language.detect(filename: "secrets.env"), .dotenv)          // .env as an extension
        XCTAssertEqual(Language.detect(filename: ".envrc"), .bash)                 // direnv fix must not regress
        XCTAssertEqual(Language.detect(filename: ".environment"), .plainText)      // no ".env." prefix, unknown ext
    }

    func testShellAndEditorDotfiles() {
        let cases: [(String, Language)] = [
            (".bashrc", .bash), (".bash_profile", .bash), (".bash_aliases", .bash),
            (".zshrc", .zsh), (".zprofile", .zsh), (".zshenv", .zsh), (".zlogin", .zsh),
            (".profile", .sh), (".shrc", .sh),
            (".vimrc", .vimscript), (".gvimrc", .vimscript), ("_vimrc", .vimscript),
            (".emacs", .elisp),
            (".gitignore", .gitignore), (".gitattributes", .gitattributes),
            (".gitconfig", .gitconfig), (".gitmodules", .gitconfig),
            (".dockerignore", .gitignore), (".npmignore", .gitignore),
            (".editorconfig", .editorconfig), (".htaccess", .apacheconf),
            (".prettierrc", .json), (".eslintrc.json", .jsonc),
            (".clang-format", .yaml), (".clang-tidy", .yaml),
        ]
        for (name, expected) in cases {
            XCTAssertEqual(Language.detect(filename: name), expected, "for \(name)")
        }
    }

    /// A dotfile whose "name" is a known extension resolves via the extension
    /// map (the leading dot makes the rest the extension). Documented behavior.
    func testBareDotExtensionResolvesViaExtensionMap() {
        XCTAssertEqual(Language.detect(filename: ".swift"), .swift)
        XCTAssertEqual(Language.detect(filename: ".gitignore_global"), .plainText) // not a mapped ext
    }

    // MARK: - Case sensitivity

    func testDetectionIsCaseInsensitiveEverywhere() {
        // Extension map.
        XCTAssertEqual(Language.detect(filename: "README.MD"), .markdown)
        XCTAssertEqual(Language.detect(filename: "Main.SWIFT"), .swift)
        // Filename map.
        XCTAssertEqual(Language.detect(filename: "Makefile"), .makefile)
        XCTAssertEqual(Language.detect(filename: "makefile"), .makefile)
        XCTAssertEqual(Language.detect(filename: "MAKEFILE"), .makefile)
        XCTAssertEqual(Language.detect(filename: "TSConfig.JSON"), .jsonc)
        // Special prefix rules.
        XCTAssertEqual(Language.detect(filename: "DOCKERFILE.PROD"), .dockerfile)
        XCTAssertEqual(Language.detect(filename: ".ENV.LOCAL"), .dotenv)
        // Compound extensions.
        XCTAssertEqual(Language.detect(filename: "Welcome.Blade.PHP"), .blade)
    }

    // MARK: - Degenerate names (must never crash, always fall back)

    func testDegenerateFilenamesFallBackToPlainText() {
        let degenerates = ["", ".", "..", "...", "trailing.", "no_extension", ".hiddennoext", "a"]
        for name in degenerates {
            XCTAssertEqual(Language.detect(filename: name), .plainText, "for \(String(reflecting: name))")
        }
    }

    func testMultiDotNamesUseLastComponent() {
        XCTAssertEqual(Language.detect(filename: "jquery.min.js"), .javascript)
        XCTAssertEqual(Language.detect(filename: "component.test.tsx"), .tsx)
        XCTAssertEqual(Language.detect(filename: "archive.tar.gz"), .plainText)   // .gz unmapped
        XCTAssertEqual(Language.detect(filename: "v1.2.3"), .plainText)
    }

    // MARK: - URL detection

    func testDetectForURLUsesLastPathComponentOnly() {
        // A directory named like another language must not influence detection.
        XCTAssertEqual(Language.detect(for: URL(fileURLWithPath: "/src/python/main.rs")), .rust)
        XCTAssertEqual(Language.detect(for: URL(fileURLWithPath: "/deep/path/Makefile")), .makefile)
        XCTAssertEqual(Language.detect(for: URL(fileURLWithPath: "/repo/.env.local")), .dotenv)
        XCTAssertEqual(Language.detect(for: URL(fileURLWithPath: "/repo/Dockerfile.ci")), .dockerfile)
    }

    // MARK: - HighlightFamily fallback table

    /// Every language must resolve to SOME family without hitting the `.plain`
    /// escape hatch by accident (i.e. its metadata row exists and carries a family).
    func testEveryLanguageHasAFamilyBackedByMetadata() {
        for lang in Language.allCases {
            let meta = Language.metadata[lang]
            XCTAssertNotNil(meta, "\(lang.rawValue) has no metadata row — family would silently fall back to .plain")
            XCTAssertEqual(lang.family, meta?.family, "family accessor disagrees with metadata for \(lang.rawValue)")
        }
    }

    /// Representative spot-check across the catalog: each family's flagship
    /// languages map where a fallback highlighter would expect them.
    func testFamilySpotChecks() {
        let cases: [(Language, HighlightFamily)] = [
            // cLike
            (.c, .cLike), (.cpp, .cLike), (.objectivec, .cLike), (.csharp, .cLike),
            (.java, .cLike), (.kotlin, .cLike), (.swift, .cLike), (.go, .cLike),
            (.rust, .cLike), (.javascript, .cLike), (.typescript, .cLike),
            (.scala, .cLike), (.php, .cLike), (.zig, .cLike), (.verilog, .cLike),
            (.protobuf, .cLike),
            // rubyLike
            (.ruby, .rubyLike), (.crystal, .rubyLike), (.elixir, .rubyLike),
            (.python, .rubyLike), (.perl, .rubyLike),
            // lispLike
            (.clojure, .lispLike), (.scheme, .lispLike), (.racket, .lispLike),
            (.commonlisp, .lispLike),
            // mlLike
            (.haskell, .mlLike), (.ocaml, .mlLike), (.elm, .mlLike),
            (.fsharp, .mlLike), (.purescript, .mlLike), (.sml, .mlLike),
            (.nix, .mlLike), (.lua, .mlLike), (.pascal, .mlLike),
            // shellLike
            (.bash, .shellLike), (.zsh, .shellLike), (.fish, .shellLike),
            (.makefile, .shellLike), (.dockerfile, .shellLike),
            (.crontab, .shellLike), (.gitignore, .shellLike),
            (.piprequirements, .shellLike),
            // markup
            (.html, .markup), (.xml, .markup), (.markdown, .markup),
            (.vue, .markup), (.svelte, .markup),
            // config
            (.ini, .config), (.toml, .config), (.yaml, .config),
            (.dotenv, .config), (.nginx, .config), (.terraform, .config),
            (.gitconfig, .config), (.gomod, .config),
            // sql
            (.sql, .sql), (.plsql, .sql), (.hiveql, .sql),
            // tex
            (.latex, .tex), (.bibtex, .tex),
            // data
            (.json, .data), (.jsonc, .data), (.csv, .data),
            // plain (recognized, no distinctive rules)
            (.plainText, .plain), (.log, .plain), (.diff, .plain),
            (.cobol, .plain), (.smalltalk, .plain), (.fortran, .plain),
        ]
        for (lang, expected) in cases {
            XCTAssertEqual(lang.family, expected, "family for \(lang.rawValue)")
        }
    }

    /// Detection composes with the family fallback: a detected file lands in a
    /// family a highlighter can actually use.
    func testDetectionComposesWithFamilyFallback() {
        XCTAssertEqual(Language.detect(filename: "deploy.sh").family, .shellLike)
        XCTAssertEqual(Language.detect(filename: ".env.local").family, .config)
        XCTAssertEqual(Language.detect(filename: ".envrc").family, .shellLike)
        XCTAssertEqual(Language.detect(filename: "unknown.zzq").family, .plain)
    }
}
