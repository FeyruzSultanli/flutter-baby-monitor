/// Compile-time switches for features that are kept in the code base but not
/// offered to users yet.
library;

/// Multi-camera viewing conflicts with normal pairing (a room accepts a single
/// viewer, see BUGS.md B15 / decision D6). The screen and services stay in the
/// code; only the menu entry is hidden while this is false.
const bool kMultiCameraEnabled = false;
