# Nushell module for interacting with checkboxes.andersmurphy.com
#
# This module provides commands to interact with Anders Murphy's
# "One Billion Checkboxes" website, which is built using the
# Hyperlith framework (Clojure + Datastar).
#
# Usage:
#   use checkbox.nu
#   checkbox toggle 100 200

def get-session [ --verbose] {
  if $verbose {
    print $"[AUTH] Fetching session cookies..."
  }

  let resp = (
    http get --full --headers {
      Accept: "text/html"
      "Accept-Encoding": "br, gzip"
    } "https://checkboxes.andersmurphy.com/"
  )

  let cookies = (
    $resp
    | get headers.response
    | where name == "set-cookie"
    | get value
    | each {|cookie| $cookie | parse "{name}={value}; {_}" }
    | flatten
  )

  let sid = ($cookies | where name == "__Host-sid" | get value | first)
  let csrf = ($cookies | where name == "__Host-csrf" | get value | first)

  if $verbose {
    print $"   SID: ($sid)"
    print $"   CSRF: ($csrf)"
  }

  {
    sid: $sid
    csrf: $csrf
    cookie_header: $"__Host-sid=($sid); __Host-csrf=($csrf)"
  }
}

# Toggle checkbox at x,y (0-31631 each)
#
# Examples:
#   toggle 0 0
#   toggle 100 200 --color orange
export def toggle [
  x: int # X coordinate (0-31631)
  y: int # Y coordinate (0-31631)
  --color: string # Color name (see `colors` command)
  --verbose (-v) # Show detailed output
]: nothing -> record {

  if $x < 0 or $x > 31631 {
    error make {
      msg: $"X coordinate must be between 0 and 31631, got ($x)"
    }
  }
  if $y < 0 or $y > 31631 {
    error make {
      msg: $"Y coordinate must be between 0 and 31631, got ($y)"
    }
  }

  # Convert x,y to chunk/cell (16x16 chunks)
  let chunk_x = ($x // 16)
  let chunk_y = ($y // 16)
  let local_x = ($x mod 16)
  let local_y = ($y mod 16)

  let chunk = ($chunk_y * 1977 + $chunk_x)
  let cell = ($local_y * 16 + $local_x)

  let session = (get-session --verbose=$verbose)
  let cookie_header = $session.cookie_header
  let csrf = $session.csrf
  if $color != null {
    let colors = {
      clear: 0
      red: 1
      blue: 2
      green: 3
      orange: 4
      pink: 5
      maroon: 6
      peach: 7
      navy: 8
      brown: 9
      yellow: 10
      darkgreen: 11
      gray: 12
      purple: 13
      darkgray: 14
    }

    let color_id = ($colors | get -o $color)
    if $color_id == null {
      error make {
        msg: $"Unknown color name: ($color)"
        label: {text: "valid colors: clear, red, blue, green, orange, pink, maroon, peach, navy, brown, yellow, darkgreen, gray, purple, darkgray"}
      }
    }

    if $verbose {
      print $"[COLOR] Setting color to ($color) (($color_id))..."
    }

    let color_path = "k7tDX7WolUoWsg_mJCVo61xVPcPNJVtn8"
    let color_resp = (
      http post --full --allow-errors
      --content-type "application/json"
      --headers {
        "Accept-Encoding": "br, gzip"
        "Cookie": $cookie_header
      }
      $"https://checkboxes.andersmurphy.com/($color_path)"
      {
        csrf: $csrf
        tabid: "nushell-cli"
        targetid: ($color_id | into string)
      }
    )

    let color_status = ($color_resp | get status)
    if $color_status != 204 {
      error make {
        msg: $"Failed to set color. HTTP status: ($color_status)"
      }
    }

    if $verbose {
      print $"[OK] Color set to ($color)"
    }
  }

  let action_path = "t_rqnpSL_NvK8EJhoBwkc6TNJ4VsLi1Fs"

  if $verbose {
    print $"[TOGGLE] Toggling checkbox at ($x), ($y) [chunk ($chunk), cell ($cell)]..."
  }

  let toggle_resp = (
    http post --full --allow-errors
    --content-type "application/json"
    --headers {
      "Accept-Encoding": "br, gzip"
      "Cookie": $cookie_header
    }
    $"https://checkboxes.andersmurphy.com/($action_path)"
    {
      csrf: $csrf
      tabid: "nushell-cli"
      targetid: ($cell | into string)
      parentid: ($chunk | into string)
    }
  )

  let status = ($toggle_resp | get status)
  let success = ($status == 204)

  if $verbose {
    if $success {
      print $"[OK] SUCCESS - Toggled checkbox at ($x), ($y)"
    } else {
      print $"[ERROR] FAILED - HTTP Status: ($status)"
    }
  }

  {
    success: $success
    status: $status
    x: $x
    y: $y
    chunk: $chunk
    cell: $cell
    message: (
      if $success {
        "Checkbox toggled successfully"
      } else {
        $"Failed with HTTP status ($status)"
      }
    )
  }
}

# List available colors
export def colors []: nothing -> table {
  [
    {id: 0, name: "clear"}
    {id: 1, name: "red"}
    {id: 2, name: "blue"}
    {id: 3, name: "green"}
    {id: 4, name: "orange"}
    {id: 5, name: "pink"}
    {id: 6, name: "maroon"}
    {id: 7, name: "peach"}
    {id: 8, name: "navy"}
    {id: 9, name: "brown"}
    {id: 10, name: "yellow"}
    {id: 11, name: "darkgreen"}
    {id: 12, name: "gray"}
    {id: 13, name: "purple"}
    {id: 14, name: "darkgray"}
  ]
}

# Service metadata
export def info []: nothing -> record {
  {
    service: "One Billion Checkboxes"
    url: "https://checkboxes.andersmurphy.com/"
    author: "Anders Murphy"
    framework: "Hyperlith (Clojure + Datastar)"
    grid_size: "31,632 × 31,632"
    chunk_size: 16
    cells_per_chunk: 256
    total_cells: 1000782224
    description: "A collaborative checkbox grid"
    coordinate_range: "x: 0-31631, y: 0-31631"
    endpoints: {
      homepage: "/"
      toggle: "/t_rqnpSL_NvK8EJhoBwkc6TNJ4VsLi1Fs"
    }
  }
}

# Toggle multiple checkboxes from list of {x, y, ?color} records
#
# Examples:
#   [{x: 0, y: 0}, {x: 1, y: 0}] | batch
#   [{x: 0, y: 0, color: "red"}] | batch
export def batch [
  --color: string # Global color (see `colors` command; can be overridden per item)
  --verbose (-v) # Show detailed output for each toggle
]: list<record> -> table {
  each {|item|
    let item_color = (
      if ($item | get -o color) != null {
        $item.color
      } else if $color != null {
        $color
      } else {
        null
      }
    )

    if $item_color != null {
      toggle $item.x $item.y --color $item_color --verbose=$verbose
    } else {
      toggle $item.x $item.y --verbose=$verbose
    }
  }
}

# List available commands
export def main []: nothing -> table {
  [
    {command: "toggle", description: "Toggle checkbox at x,y coordinates"}
    {command: "batch", description: "Toggle multiple checkboxes from list"}
    {command: "colors", description: "List available colors"}
    {command: "info", description: "Service metadata"}
  ]
}
