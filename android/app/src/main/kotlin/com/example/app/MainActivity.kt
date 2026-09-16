package com.example.app

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity rather than FlutterActivity: the local_auth
// plugin's biometric prompt requires a FragmentActivity host on Android.
class MainActivity : FlutterFragmentActivity()
