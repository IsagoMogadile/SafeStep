/// Which post-login route a signed-in user should land on.
///
/// Determined by which table the user's row lives in, per scope.md §2 —
/// there is one app binary and one login screen; role is a lookup, not a
/// separate build.
enum AppRole { student, responder, admin }
