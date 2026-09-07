# Bazaar R8 rules
#
# flutter_gemma runs inference through JNI-registered native code and loads
# .task model files via reflection-free paths, but MediaPipe's TaskLibrary
# keeps task-file class names as strings inside the model bundle. Keep the
# whole com.google.mediapipe surface to avoid removeCode breaking inference
# on release builds.

-keep class com.google.mediapipe.** { *; }
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.mediapipe.**

# flutter_secure_storage reads/writes through platform channels — keep its
# plugin classes (dart objects are reconstructed reflectively on the plugin
# side).
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# sqflite-era note: drift on Android uses the bundled sqlite3 (native lib),
# no reflection involved — nothing to keep.

# Flutter default rules (also present in the engine's shipped rules).
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.embedding.**
