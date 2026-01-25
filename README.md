# Runebook

An interactive notebook application for Ruby.

## About

Runebook lets you write and execute Ruby code in an interactive notebook environment. Combine executable code cells with Markdown documentation to create living documents for prototyping, learning, or exploring ideas.

### Features

- **Code cells** - Write and execute Ruby code with streaming output
- **Markdown cells** - Document your work with rich text formatting
- **Local-first** - Your notebooks live on your machine as plain text files

### Runebook Markdown

Notebooks are persisted in the `.runemd` format—a simple, human-readable Markdown-based format. You can create new notebooks from scratch, or import existing `.runemd` files to pick up where you left off.

## Prerequisites

- Ruby 4.0.1
- Node.js (v18+ recommended)
- Redis

## Getting Started

```bash
git clone https://github.com/typhoonworks/runebook.git
cd runebook
bin/setup
```

Start the development servers in separate terminals:

```bash
bin/rails s
```

```bash
bin/vite dev
```

Visit http://localhost:3000

## Development

- `bin/rails s` - Start Rails server
- `bin/vite dev` - Start Vite dev server
- `rails test` - Run tests
- `bin/rubocop` - Run linter

## Tech Stack

Rails 8, Vite, Hotwire, Monaco Editor, Tailwind CSS

## Acknowledgments

Runebook draws inspiration from [Livebook](https://livebook.dev/), the incredible notebook environment for Elixir.

## License

Apache 2.0
