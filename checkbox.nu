# Nushell module for interacting with checkboxes.andersmurphy.com
#
# This module provides commands to interact with Anders Murphy's
# "One Billion Checkboxes" website, which is built using the
# Hyperlith framework (Clojure + Datastar).
#
# Usage:
#   use checkbox.nu
#   checkbox toggle -c 42 -k 100
#   checkbox info
#
# Or import all commands:
#   use checkbox.nu *
#   toggle -c 42 -k 100
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

# Set the color for future checkbox toggles
#
# Colors available: 0 (clear), 1-14 (various colors)
# The color persists for the session and affects subsequent toggles.
#
# Example:
#   checkbox color 4                # Set to orange
#   checkbox color --name red       # Set by name
#   checkbox color --list           # List all colors
export def color [
    color_id?: int          # Color ID (0-14)
    --name (-n): string     # Color name (red, blue, green, etc.)
    --list (-l)             # List all available colors
    --verbose (-v)          # Show detailed output
]: nothing -> any {

    # Color definitions
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

    # If --list, show all colors
    if $list {
        let hex_colors = [
            "#000000" "#FF004D" "#29ADFF" "#00E436" "#FFA300"
            "#FF77A8" "#7E2553" "#FFCCAA" "#1D2B53" "#AB5236"
            "#FFEC27" "#008751" "#C2C3C7" "#83769C" "#5F574F"
        ]
        return ($colors | transpose name id | enumerate | each {|row|
            $row.item | insert hex ($hex_colors | get $row.index)
        })
    }

    # Determine color ID
    let color = (if $name != null {
        let result = ($colors | get -o $name)
        if $result == null {
            error make {
                msg: $"Unknown color name: ($name)"
                label: { text: "valid colors: clear, red, blue, green, orange, pink, maroon, peach, navy, brown, yellow, darkgreen, gray, purple, darkgray" }
            }
        } else {
            $result
        }
    } else if $color_id != null {
        $color_id
    } else {
        1  # Default to red
    })

    # Validate color ID
    if $color < 0 or $color > 14 {
        error make {
            msg: $"Color ID must be between 0 and 14, got ($color)"
        }
    }

    # Get session
    let session = (get-session --verbose=$verbose)

    let action_path = "k7tDX7WolUoWsg_mJCVo61xVPcPNJVtn8"

    if $verbose {
        print $"🎨 Setting color to ($color)..."
    }

    let color_resp = (
        http post --full --allow-errors
        --content-type "application/json"
        --headers {
            "Accept-Encoding": "br, gzip",
            "Cookie": $session.cookie_header
        }
        $"https://checkboxes.andersmurphy.com/($action_path)"
        {
            csrf: $session.csrf,
            tabid: "nushell-cli",
            targetid: ($color | into string)
        }
    )

    let status = ($color_resp | get status)
    let success = ($status == 204)

    if $verbose {
        if $success {
            print $"✅ Color set to ($color)"
        } else {
            print $"❌ FAILED - HTTP Status: ($status)"
        }
    }

    {
        success: $success
        status: $status
        color: $color
        message: (if $success {
            $"Color set to ($color)"
        } else {
            $"Failed with HTTP status ($status)"
        })
    }
}

# Toggle a checkbox on checkboxes.andersmurphy.com
#
# This command makes authenticated HTTP requests to toggle a checkbox
# on Anders Murphy's "One Billion Checkboxes" website. It handles session
# management, CSRF tokens, and the custom hashed action endpoints used
# by the Hyperlith framework.
#
# Example:
#   checkbox toggle -c 42 -k 100              # Toggle cell 42 in chunk 100
#   checkbox toggle -c 5 -k 0                 # Using short flags
#   checkbox toggle --verbose                 # Toggle cell 0, chunk 0 with details
#   checkbox toggle -c 7 -k 5 --color orange  # Set color then toggle
export def toggle [
    --cell (-c): int = 0        # Cell ID within the chunk (0-255)
    --chunk (-k): int = 0       # Chunk ID on the board
    --color: string             # Color name to set before toggling (red, blue, green, orange, etc.)
    --verbose (-v)              # Show detailed output
]: nothing -> record {

    # Validate parameters
    if $cell < 0 or $cell > 255 {
        error make {
            msg: "Cell ID must be between 0 and 255"
        }
    }

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

    # Step 5: Action endpoint is a hash of "app.main/handler-check"
    # Calculated as: "/" + base64_url(sha256("app.main/handler-check"))[10..]
    let action_path = "t_rqnpSL_NvK8EJhoBwkc6TNJ4VsLi1Fs"

    if $verbose {
        print $"🎯 Toggling checkbox cell=($cell) in chunk=($chunk)..."
    }

    # Step 6: Toggle the checkbox via POST request
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

    # Step 7: Return result
    let status = ($toggle_resp | get status)
    let success = ($status == 204)

    if $verbose {
        if $success {
            print $"✅ SUCCESS - Toggled checkbox ($cell) in chunk ($chunk)"
        } else {
            print $"❌ FAILED - HTTP Status: ($status)"
        }
    }

    {
        success: $success
        status: $status
        cell: $cell
        chunk: $chunk
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
        chunk_size: 16
        cells_per_chunk: 256
        total_cells: 1000000000
        description: "A collaborative checkbox grid with 1 billion checkboxes"
        colors: {
            available: 15
            range: "0 (clear) to 14"
            names: ["clear", "red", "blue", "green", "orange", "pink", "maroon", "peach", "navy", "brown", "yellow", "darkgreen", "gray", "purple", "darkgray"]
        }
        endpoints: {
            homepage: "/"
            toggle: "/t_rqnpSL_NvK8EJhoBwkc6TNJ4VsLi1Fs"
            color: "/k7tDX7WolUoWsg_mJCVo61xVPcPNJVtn8"
        }
    }
}

# Toggle multiple checkboxes in sequence
#
# Accepts a list of records with cell and chunk fields and toggles
# each checkbox in order. Returns a table of results.
#
# Example:
#   [{cell: 1, chunk: 0}, {cell: 2, chunk: 0}] | checkbox batch
export def batch [
    --verbose (-v)  # Show detailed output for each toggle
]: list<record> -> table {
    each { |item|
        toggle --cell $item.cell --chunk $item.chunk --verbose=$verbose
    }
}
