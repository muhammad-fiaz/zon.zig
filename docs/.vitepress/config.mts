import { defineConfig } from 'vitepress'

export default defineConfig({
  title: "zon.zig",
  description: "A document-based Zig library for reading, writing, and manipulating ZON configuration files — complementary to std.zon. Supports editing, find & replace, merge & clone, arrays, and pretty-printing.",
  base: '/zon.zig/',
  
  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: '/logo.svg' }],
    // Apple touch icon (uses site logo)
    ['link', { rel: 'apple-touch-icon', href: '/logo.svg' }],
    ['link', { rel: 'canonical', href: 'https://muhammad-fiaz.github.io/zon.zig/' }],
    ['meta', { name: 'viewport', content: 'width=device-width, initial-scale=1' }],
    ['meta', { name: 'theme-color', content: '#f7a41d' }],
    ['meta', { name: 'author', content: 'Muhammad Fiaz' }],
    ['meta', { name: 'keywords', content: 'Zig, ZON, zon.zig, std.zon, configuration, parser, serializer, document, DOM, config file, pretty print, merge, clone, find, replace' }],
    ['meta', { name: 'robots', content: 'index,follow' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:site_name', content: 'zon.zig' }],
    ['meta', { property: 'og:title', content: 'zon.zig — Document-based ZON library for Zig' }],
    ['meta', { property: 'og:description', content: 'A document-based Zig library for reading, writing, and manipulating ZON configuration files — complementary to std.zon' }],
    ['meta', { property: 'og:url', content: 'https://muhammad-fiaz.github.io/zon.zig/' }],
    ['meta', { property: 'og:image', content: 'https://muhammad-fiaz.github.io/zon.zig/logo.svg' }],
    ['meta', { name: 'twitter:card', content: 'summary' }],
    ['meta', { name: 'twitter:site', content: '@muhammadfiaz' }],
    ['meta', { name: 'twitter:title', content: 'zon.zig — Document-based ZON library for Zig' }],
    ['meta', { name: 'twitter:description', content: 'A document-based Zig library for reading, writing, and manipulating ZON configuration files — complementary to std.zon' }],
    ['meta', { name: 'twitter:image', content: 'https://muhammad-fiaz.github.io/zon.zig/logo.svg' }],
    ['script', { type: 'application/ld+json' }, '{"@context":"https://schema.org","@type":"SoftwareApplication","name":"zon.zig","url":"https://muhammad-fiaz.github.io/zon.zig/","description":"A document-based Zig library for reading, writing, and manipulating ZON configuration files","applicationCategory":"DeveloperTool","operatingSystem":"Cross-platform","softwareVersion":"0.0.4","author":{"@type":"Person","name":"Muhammad Fiaz"}}']
  ],

  themeConfig: {
    logo: '/logo.svg',
    
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Guide', link: '/guide/getting-started' },
      { text: 'API', link: '/api/' },
      { text: 'Examples', link: '/guide/examples' },
      {
        text: 'v0.0.4',
        items: [
          { text: 'Changelog', link: 'https://github.com/muhammad-fiaz/zon.zig/releases' },
          { text: 'Contributing', link: 'https://github.com/muhammad-fiaz/zon.zig/blob/main/CONTRIBUTING.md' }
        ]
      }
    ],

    sidebar: {
      '/guide/': [
        {
          text: 'Introduction',
          items: [
            { text: 'What is zon.zig?', link: '/guide/' },
            { text: 'Introduction', link: '/guide/introduction' },
            { text: 'Getting Started', link: '/guide/getting-started' },
            { text: 'Installation', link: '/guide/installation' },
            { text: 'Allocators', link: '/guide/allocators' }
          ]
        },
        {
          text: 'Core Usage',
          items: [
            { text: 'Basic Usage', link: '/guide/basic-usage' },
            { text: 'Reading Files', link: '/guide/reading' },
            { text: 'Writing Files', link: '/guide/writing' },
            { text: 'File Operations', link: '/guide/file-operations' },
            { text: 'Nested Paths', link: '/guide/nested-paths' },
            { text: 'Identifier Values', link: '/guide/identifier-values' }
          ]
        },
        {
          text: 'Advanced',
          items: [
            { text: 'Runtime Structs', link: '/guide/runtime-structs' },
            { text: 'Find & Replace', link: '/guide/find-replace' },
            { text: 'Array Operations', link: '/guide/arrays' },
            { text: 'Merge & Clone', link: '/guide/merge-clone' },
            { text: 'Pretty Print', link: '/guide/pretty-print' },
            { text: 'Error Handling', link: '/guide/error-handling' },
            { text: 'Examples', link: '/guide/examples' }
          ]
        }
      ],
      '/api/': [
        {
          text: 'API Reference',
          items: [
            { text: 'Overview', link: '/api/' },
            { text: 'Module Functions', link: '/api/module' },
            { text: 'Document', link: '/api/document' },
            { text: 'Value Types', link: '/api/value' }
          ]
        }
      ]
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/muhammad-fiaz/zon.zig' }
    ],

    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright © 2025 Muhammad Fiaz'
    },

    search: {
      provider: 'local'
    },

    editLink: {
      pattern: 'https://github.com/muhammad-fiaz/zon.zig/edit/main/docs/:path',
      text: 'Edit this page on GitHub'
    }
  }
})
