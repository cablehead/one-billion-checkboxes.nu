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
- **Scroll**: `(hash of app.main/handler-scroll)` - Updates viewport position
- **Resize**: `(hash of app.main/handler-resize)` - Updates viewport dimensions
- **SSE Stream**: POST `/` - Real-time updates via Server-Sent Events

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

## SSE Subscription & Real-time Updates

### How SSE Works in This Application

The application uses **Server-Sent Events (SSE)** to push real-time checkbox updates to connected clients. When any user toggles a checkbox, all connected clients receive the update automatically.

**SSE Endpoint:**
- Method: `POST /`
- Content-Type: `text/event-stream`
- Connection: Keep-alive persistent connection

**Required Headers:**
```
Accept: text/event-stream
Accept-Encoding: br, gzip
Cookie: __Host-sid=<session>; __Host-csrf=<csrf>
```

**Event Format:**
Events are sent as `datastar-patch-elements` with brotli-compressed HTML:
```
event: datastar-patch-elements
id: <hash>
data: elements <html-fragment>
```

The HTML fragments contain updated checkbox states for chunks in your viewport.

### Session & Viewport Management

**Important:** You cannot directly "subscribe to chunk X." Instead, the server tracks your **viewport position** and sends updates for chunks that are visible to you.

**Session State (stored server-side):**
```json
{
  "x": 0,           // Scroll position X (in pixels)
  "y": 0,           // Scroll position Y (in pixels)
  "width": 1000,    // Viewport width
  "height": 800,    // Viewport height
  "color": 1        // Selected color
}
```

**Updating Viewport Position:**
To see specific chunks, you must first update your viewport position:

```json
// POST to scroll handler
{
  "csrf": "<csrf-token>",
  "tabid": "cli",
  "view-x": 0,      // X position in pixels
  "view-y": 0       // Y position in pixels
}
```

```json
// POST to resize handler
{
  "csrf": "<csrf-token>",
  "tabid": "cli",
  "view-h": 800,    // Viewport height
  "view-w": 1000    // Viewport width
}
```

**Viewport to Chunk Calculation:**
- Each chunk is 16×16 cells = 512×512 pixels (at 32px per cell)
- Board size: ~31,623 chunks per dimension (1 billion cells total)
- Viewport shows ~7×7 = 49 chunks at a time (configurable)
- 2 buffer chunks rendered beyond visible edge

### Understanding Chunk Broadcasting

**How Updates Are Broadcast:**

1. **Any database change** triggers a batch update (100ms throttle)
2. Server calls `refresh-all!` which broadcasts to ALL connected SSE clients
3. Each client receives updates for chunks in THEIR viewport only
4. Server renders ~49 chunks (7×7 grid) based on each client's position

**Key Points:**
- All clients share the same data, but receive different views
- You automatically receive updates for any chunk in your viewport
- To monitor different chunks, update your viewport position
- Updates are throttled to max 10 per second (100ms batching)

**Viewing Specific Chunks:**

To monitor chunk #100:
1. Calculate viewport position to include chunk 100
2. Update session viewport via scroll handler
3. Connect to SSE endpoint
4. Receive all updates for chunks around #100

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
