# WIMWitch-tNG

_"Make it so." - Captain Jean-Luc Picard_

![WIMWITCHFK](https://i.imgur.com/WGNLA48.png)

This a forked version of WimWitch by Donna Ryan (TheNotoriousDRR) which was EOL'd in Jan 2023. This is an attempt to keep the tool alive and have the community be able to help maintain and add features to it.

**About the Name:** The "tNG" (the Next Generation) suffix honors Donna Ryan's original Star Trek: The Next Generation theme. Like Captain Picard's Enterprise-D, this represents an evolution while staying true to the original mission.

# Changelog

## 5.0-beta (2026-01-19)

**Major Changes:**
- Complete code documentation: All 111 functions now include comprehensive comment-based help
- PROJECT_CONTEXT.md: 944-line AI development guide
- CHANGELOG.md: Comprehensive tracking of all changes, planned features, and bug fixes
- Transitioning to date-based versioning: Next stable release will use YYYY.M.D format (e.g., 2026.1.1)
- Code signature blocks added to all PowerShell files
- Detailed implementation plans for 8 bug fixes and 4 major features

**Documentation:**
- Added PROJECT_CONTEXT.md with architecture, coding standards, and critical functions
- Added CHANGELOG.md tracking fork history and planned work
- Added TESTING_GUIDE.md and VERBOSE_LOGGING_IMPLEMENTATION.md
- Created 12 detailed implementation plans in .github/prompts/

**Version Strategy:**
- Current: 5.0-beta (pre-release, documentation focus)
- Future: Date-based versioning (YYYY.M.D format)
  - Example: 2026.1.1 = January 2026, patch 1
  - Benefits: Clear release timing, no semantic version confusion

## 4.0.1

- Resolved issue with default paths in Make It So tab

## 4.0.0

- Refactored script into a PowerShell module.
- Added Assets directory and moved appx removal definitions to text files to simplify function structure.
- Added a WorkingDirectory parameter and refactored all functions to use it as WIMWitch-tNG no longer installs itself due to module conversions.
- Added new icon.

## 3.4.9

- Resolved wrong ascii character causing curly bracket imbalance on line 6991. Fix from @chadkerley
- Resolved issue with running wimwitch from command line. Fix from @THH-THC
- Resolved issue with update directories not being correctly parsed when processing updates.

## 3.4.8

- Added Windows 11 23H2 Appx removal list
- Added new Microsoft Backup tool to Appx removal list for Windows 11 23H2
- Resolved dotnet import version number issue

## 3.4.7

- Added support for Windows 11 23H2
