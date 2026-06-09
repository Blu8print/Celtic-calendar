# Gson TypeToken – required for googleapis / Google Calendar sync in release builds
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken

# Keep widget classes — R8 must not rename or strip these because they are
# referenced by name in AndroidManifest.xml and from home_widget's MethodChannel.
-keep class nl.blu8print.rootscalendar.RootsDayWidget { *; }
-keep class nl.blu8print.rootscalendar.SolarTimeHelper { *; }
