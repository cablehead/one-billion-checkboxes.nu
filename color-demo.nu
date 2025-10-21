#!/usr/bin/env nu
# Demo: Setting colors and toggling checkboxes

print "=== Checkbox Color Demo ==="
print ""

use checkbox.nu

# List all available colors
print "1. Available colors:"
checkbox color --list
print ""

# Set color by ID
print "2. Set color to orange (ID 4):"
checkbox color 4 --verbose
print ""

# Set color by name
print "3. Set color to blue by name:"
checkbox color --name blue --verbose
print ""

# Get service info with color details
print "4. Service info (including color information):"
checkbox info | get colors
print ""

print "=== Demo Complete ==="
