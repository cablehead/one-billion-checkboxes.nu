# Checkbox.nu - Nushell Module

A Nushell module for interacting with [checkboxes.andersmurphy.com](https://checkboxes.andersmurphy.com/), Anders Murphy's "One Billion Checkboxes" collaborative art project.

## Features

- ✅ Toggle individual checkboxes with type-safe parameters
- 🎨 Set checkbox colors (15 colors available)
- 📦 Batch toggle multiple checkboxes
- 📊 Get service information
- 🔒 Automatic session and CSRF token management
- 📝 Full help documentation
- 🎯 Input/output type signatures for pipeline safety

## Installation

Simply copy `checkbox.nu` to your Nushell modules directory or any location in your `$env.NU_LIB_DIRS`.

## Usage

### Import the module

```nu
use checkbox.nu

# All commands available with namespace
checkbox color --list
checkbox toggle -c 42 -k 100
checkbox info
```

### Or import all commands

```nu
use checkbox.nu *

# Commands available without namespace
color --list
toggle -c 42 -k 100
info
```

## Commands

### `checkbox color`

Set the color for future checkbox toggles. The color persists for the session.

**Parameters:**
- `color_id`: Color ID (0-14, optional positional)
- `--name` / `-n`: Color name (red, blue, green, orange, etc.)
- `--list` / `-l`: List all available colors
- `--verbose` / `-v`: Show detailed output

**Available Colors:**
- 0: clear (black)
- 1: red
- 2: blue  
- 3: green
- 4: orange
- 5: pink
- 6: maroon
- 7: peach
- 8: navy
- 9: brown
- 10: yellow
- 11: darkgreen
- 12: gray
- 13: purple
- 14: darkgray

**Examples:**
```nu
# List all colors with hex codes
checkbox color --list

# Set color by ID
checkbox color 4

# Set color by name
checkbox color --name orange

# Set with verbose output
checkbox color --name blue --verbose
```

### `checkbox toggle`

Toggle a checkbox on the grid.

**Parameters:**
- `--cell` / `-c`: Cell ID within chunk (0-255, default: 0)
- `--chunk` / `-k`: Chunk ID on the board (default: 0)
- `--verbose` / `-v`: Show detailed output

**Returns:** Record with success status, cell, chunk, and message

**Examples:**
```nu
# Toggle with verbose output
checkbox toggle -c 7 -k 5 --verbose

# Silent toggle, extract message
checkbox toggle -c 99 -k 1 | get message

# Use in pipeline
checkbox toggle -c 42 -k 100 | if $in.success { "Done!" } else { "Failed!" }
```

### `checkbox info`

Get metadata about the service including available colors.

**Returns:** Record with service information

**Example:**
```nu
checkbox info
checkbox info | get colors
checkbox info | to json
```

### `checkbox batch`

Toggle multiple checkboxes in sequence.

**Input:** List of records with `cell` and `chunk` fields

**Returns:** Table of results

**Example:**
```nu
[
    {cell: 10, chunk: 1}
    {cell: 11, chunk: 1}
    {cell: 12, chunk: 1}
] | checkbox batch --verbose
```

## Help System

All commands have full help documentation:

```nu
help checkbox
help checkbox color
help checkbox toggle
help checkbox info
help checkbox batch
```

## How It Works

1. **Session Management**: Fetches session cookies from the homepage
2. **CSRF Protection**: Extracts and uses CSRF tokens for authentication  
3. **Hashed Endpoints**: Uses Hyperlith's SHA256-based action paths
4. **Color Persistence**: Colors are stored per session/tab
5. **HTTP/2**: Requires Brotli encoding support (`Accept-Encoding: br, gzip`)

## Technical Details

- **Framework**: Built for Hyperlith (Clojure + Datastar)
- **Grid Structure**: 16x16 chunks, 256 cells per chunk
- **Total Cells**: 1 billion checkboxes
- **Authentication**: Cookie-based sessions with CSRF tokens
- **Action Paths**: 
  - Toggle: `/t_rqnpSL_NvK8EJhoBwkc6TNJ4VsLi1Fs`
  - Color: `/k7tDX7WolUoWsg_mJCVo61xVPcPNJVtn8`

## Example Session

```nu
# Import module
use checkbox.nu

# List available colors
checkbox color --list | first 5
# ╭───┬────────┬────┬─────────╮
# │ # │  name  │ id │   hex   │
# ├───┼────────┼────┼─────────┤
# │ 0 │ clear  │  0 │ #000000 │
# │ 1 │ red    │  1 │ #FF004D │
# │ 2 │ blue   │  2 │ #29ADFF │
# │ 3 │ green  │  3 │ #00E436 │
# │ 4 │ orange │  4 │ #FFA300 │
# ╰───┴────────┴────┴─────────╯

# Set color to orange
checkbox color --name orange --verbose
# => 🔐 Fetching session cookies...
# =>    SID: ...
# =>    CSRF: ...
# => 🎨 Setting color to 4...
# => ✅ Color set to 4

# Toggle a checkbox with the selected color
checkbox toggle -c 42 -k 100 --verbose
# => ✅ SUCCESS - Toggled checkbox 42 in chunk 100

# Batch toggle
let cells = (seq 0 9 | each { {cell: $in, chunk: 0} })
$cells | checkbox batch | where success | length
# => 10
```

## License

This module is provided as-is for educational purposes.

The "One Billion Checkboxes" project is by Anders Murphy.
