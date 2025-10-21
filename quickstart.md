# One Billion Checkboxes - Quickstart

## TL;DR

```nu
use checkbox.nu
checkbox color --list                    # List colors
checkbox color --name orange             # Set color
checkbox toggle -c 42 -k 100 --verbose   # Toggle checkbox
```

## API Internals

**Framework**: Hyperlith (Clojure + Datastar)  
**Auth**: Cookie-based sessions + CSRF tokens  
**Encoding**: Requires `Accept-Encoding: br, gzip`

### Endpoints

Action paths are SHA256 hashes: `base64_url(sha256(namespace/action))[10..]`

- **Toggle**: `/t_rqnpSL_NvK8EJhoBwkc6TNJ4VsLi1Fs` (`app.main/handler-check`)
- **Color**: `/k7tDX7WolUoWsg_mJCVo61xVPcPNJVtn8` (`app.main/handler-palette`)

### Session Flow

1. GET `/` with brotli encoding → extract `__Host-sid` and `__Host-csrf` cookies
2. POST to action endpoint with JSON:
   ```json
   {
     "csrf": "<csrf-token>",
     "tabid": "session-id",
     "targetid": "cell-or-color-id",
     "parentid": "chunk-id"  // only for toggle
   }
   ```
3. Success = HTTP 204

### Data Structure

- **Grid**: 1 billion cells = many chunks
- **Chunk**: 16×16 = 256 cells (ID: 0-255)
- **Colors**: 15 states (0=clear, 1-14=colors)

### Color Palette

```
0: clear (black)   | 5: pink      | 10: yellow
1: red             | 6: maroon    | 11: darkgreen
2: blue            | 7: peach     | 12: gray
3: green           | 8: navy      | 13: purple
4: orange          | 9: brown     | 14: darkgray
```

## Module Commands

```nu
use checkbox.nu

# Colors
checkbox color --list              # Show all colors with hex codes
checkbox color 4                   # Set by ID
checkbox color --name blue         # Set by name

# Toggle
checkbox toggle -c 7 -k 5          # Toggle cell 7 in chunk 5
checkbox toggle --verbose          # With details

# Batch
[
  {cell: 1, chunk: 0}
  {cell: 2, chunk: 0}
] | checkbox batch

# Info
checkbox info                      # Service metadata
```

## Raw curl Example

```bash
# Get session
curl -c cookies.txt -H 'Accept-Encoding: br, gzip' \
  'https://checkboxes.andersmurphy.com/' > /dev/null

# Extract CSRF
CSRF=$(grep __Host-csrf cookies.txt | awk '{print $7}')

# Set color to orange (4)
curl -X POST \
  -H 'Accept-Encoding: br, gzip' \
  -H 'Content-Type: application/json' \
  -b cookies.txt \
  'https://checkboxes.andersmurphy.com/k7tDX7WolUoWsg_mJCVo61xVPcPNJVtn8' \
  -d "{\"csrf\": \"$CSRF\", \"tabid\": \"cli\", \"targetid\": \"4\"}"

# Toggle checkbox
curl -X POST \
  -H 'Accept-Encoding: br, gzip' \
  -H 'Content-Type: application/json' \
  -b cookies.txt \
  'https://checkboxes.andersmurphy.com/t_rqnpSL_NvK8EJhoBwkc6TNJ4VsLi1Fs' \
  -d "{\"csrf\": \"$CSRF\", \"tabid\": \"cli\", \"targetid\": \"5\", \"parentid\": \"0\"}"
```

## Files

- `checkbox.nu` - Nushell module
- `README.md` - Full documentation
- `checkbox-demo.nu` - Toggle examples
- `color-demo.nu` - Color examples
- `quickstart.md` - This file

## Source

Project: https://checkboxes.andersmurphy.com/  
Author: Anders Murphy  
Code: https://github.com/andersmurphy/hyperlith/blob/master/examples/billion_checkboxes_blob/src/app/main.clj
