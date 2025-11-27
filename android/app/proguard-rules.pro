# Keep SLF4J classes
-dontwarn org.slf4j.**
-keep class org.slf4j.** { *; }

# Keep Mercado Pago SDK classes
-keep class com.mercadopago.** { *; }
-dontwarn com.mercadopago.**

# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Keep Google Play Core classes
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Keep Flutter classes
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Keep Gson classes (used by Mercado Pago)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Keep model classes
-keep class * extends com.google.gson.TypeAdapter
-keep class ** {
  @com.google.gson.annotations.SerializedName <fields>;
}

# General Android rules
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
