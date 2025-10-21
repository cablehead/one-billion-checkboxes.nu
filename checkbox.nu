# Nushell module for interacting with checkboxes.andersmurphy.com
#
# This module provides commands to interact with Anders Murphy's
# "One Billion Checkboxes" website, which is built using the
# Hyperlith framework (Clojure + Datastar).
#
# Usage:
#   use checkbox.nu
#   checkbox toggle 100 200
#   checkbox info
#
# Or import all commands:
#   use checkbox.nu *
#   toggle 100 200
#   info

# Helper function to get session credentials (not exported)
def get-session [--verbose] {
    if $verbose {
        print $"🔐 Fetching session cookies..."
    }

    let resp = (http get --full --headers {
        Accept: "text/html",
        "Accept-Encoding": "br, gzip"
    } "https://checkboxes.andersmurphy.com/")

    let cookies = (
        $resp
        | get headers.response
        | where name == "set-cookie"
        | get value
        | each { |cookie| $cookie | parse "{name}={value}; {_}" }
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

# Toggle a checkbox on checkboxes.andersmurphy.com
#
# This command makes authenticated HTTP requests to toggle a checkbox
# on Anders Murphy's "One Billion Checkboxes" website using x,y coordinates.
# The grid is 31,632 × 31,632 checkboxes, organized into 16×16 chunks.
#
# Example:
#   checkbox toggle 0 0           # Toggle top-left checkbox
#   checkbox toggle 100 200       # Toggle checkbox at x=100, y=200
#   checkbox toggle 15000 15000 --verbose  # With detailed output
#   checkbox toggle 100 200 --color orange  # Set color then toggle
export def toggle [
    x: int                      # X coordinate (0-31,631)
    y: int                      # Y coordinate (0-31,631)
    --color: string             # Color name (red, blue, green, orange, etc.)
    --verbose (-v)              # Show detailed output
]: nothing -> record {

    # Validate parameters
    if $x < 0 or $x > 31631 {
        error make {
            msg: $"X coordinate must be between 0 and 31,631, got ($x)"
        }
    }
    if $y < 0 or $y > 31631 {
        error make {
            msg: $"Y coordinate must be between 0 and 31,631, got ($y)"
        }
    }

    # Convert x,y coordinates to chunk and cell
    # Grid is 31,632 × 31,632 = 1,000,782,224 checkboxes
    # Organized into 16×16 chunks (1,977 × 1,977 chunks)
    let chunk_x = ($x // 16)
    let chunk_y = ($y // 16)
    let local_x = ($x mod 16)
    let local_y = ($y mod 16)

    let chunk = ($chunk_y * 1977 + $chunk_x)
    let cell = ($local_y * 16 + $local_x)

    # Get session
    let session = (get-session --verbose=$verbose)
    let cookie_header = $session.cookie_header
    let csrf = $session.csrf

    # Set color if requested (using same session)
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
                label: { text: "valid colors: clear, red, blue, green, orange, pink, maroon, peach, navy, brown, yellow, darkgreen, gray, purple, darkgray" }
            }
        }

        if $verbose {
            print $"🎨 Setting color to ($color) (($color_id))..."
        }

        let color_path = "k7tDX7WolUoWsg_mJCVo61xVPcPNJVtn8"
        let color_resp = (
            http post --full --allow-errors
            --content-type "application/json"
            --headers {
                "Accept-Encoding": "br, gzip",
                "Cookie": $cookie_header
            }
            $"https://checkboxes.andersmurphy.com/($color_path)"
            {
                csrf: $csrf,
                tabid: "nushell-cli",
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
            print $"✅ Color set to ($color)"
        }
    }

    # Action endpoint is a hash of "app.main/handler-check"
    # Calculated as: "/" + base64_url(sha256("app.main/handler-check"))[10..]
    let action_path = "t_rqnpSL_NvK8EJhoBwkc6TNJ4VsLi1Fs"

    if $verbose {
        print $"🎯 Toggling checkbox at ($x), ($y) [chunk ($chunk), cell ($cell)]..."
    }

    # Toggle the checkbox via POST request
    let toggle_resp = (
        http post --full --allow-errors
        --content-type "application/json"
        --headers {
            "Accept-Encoding": "br, gzip",
            "Cookie": $cookie_header
        }
        $"https://checkboxes.andersmurphy.com/($action_path)"
        {
            csrf: $csrf,
            tabid: "nushell-cli",
            targetid: ($cell | into string),
            parentid: ($chunk | into string)
        }
    )

    # Return result
    let status = ($toggle_resp | get status)
    let success = ($status == 204)

    if $verbose {
        if $success {
            print $"✅ SUCCESS - Toggled checkbox at ($x), ($y)"
        } else {
            print $"❌ FAILED - HTTP Status: ($status)"
        }
    }

    {
        success: $success
        status: $status
        x: $x
        y: $y
        chunk: $chunk
        cell: $cell
        message: (if $success {
            "Checkbox toggled successfully"
        } else {
            $"Failed with HTTP status ($status)"
        })
    }
}

# Get information about the checkbox service
#
# Returns metadata about the One Billion Checkboxes service including
# the URL, author, framework details, and structure information.
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
        coordinate_range: "x: 0-31,631, y: 0-31,631"
        endpoints: {
            homepage: "/"
            toggle: "/t_rqnpSL_NvK8EJhoBwkc6TNJ4VsLi1Fs"
        }
    }
}

# Toggle multiple checkboxes in sequence
#
# Accepts a list of records with x and y fields and toggles
# each checkbox in order. Returns a table of results.
# Optional color field per record, or global --color flag.
#
# Example:
#   [{x: 0, y: 0}, {x: 1, y: 0}] | checkbox batch
#   [{x: 0, y: 0, color: "red"}, {x: 1, y: 0, color: "blue"}] | checkbox batch
#   [{x: 0, y: 0}, {x: 1, y: 0}] | checkbox batch --color orange
export def batch [
    --color: string  # Global color for all toggles (can be overridden per item)
    --verbose (-v)   # Show detailed output for each toggle
]: list<record> -> table {
    each { |item|
        let item_color = (if ($item | get -i color) != null {
            $item.color
        } else if $color != null {
            $color
        } else {
            null
        })

        if $item_color != null {
            toggle $item.x $item.y --color $item_color --verbose=$verbose
        } else {
            toggle $item.x $item.y --verbose=$verbose
        }
    }
}
