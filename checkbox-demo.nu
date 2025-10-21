#!/usr/bin/env nu
# Demo script showing different ways to use the checkbox.nu module

print "=== Checkbox Module Demo ==="
print ""

# Method 1: Import module with namespace
print "Method 1: Using module namespace"
use checkbox.nu

checkbox info | select service author framework
print ""

checkbox toggle -c 15 -k 2
print ""

# Method 2: Import all commands (no namespace)
print "Method 2: Import all commands"
use checkbox.nu *

info | select url description
print ""

toggle -c 16 -k 2 | get message
print ""

# Method 3: Batch operations
print "Method 3: Batch toggle"
[
    {cell: 30, chunk: 3}
    {cell: 31, chunk: 3}
    {cell: 32, chunk: 3}
] | batch | select cell chunk success
print ""

print "=== Demo Complete ==="
