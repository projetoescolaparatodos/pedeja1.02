# Keep SLF4J classes
-dontwarn org.slf4j.**
-keep class org.slf4j.** { *; }

# Keep Mercado Pago SDK classes
-keep class com.mercadopago.** { *; }
-dontwarn com.mercadopago.**

# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Keep Firebase Auth persistence
-keep class com.google.firebase.auth.** { *; }
-keepclassmembers class com.google.firebase.auth.** { *; }
-keep class com.google.firebase.auth.internal.** { *; }

# Keep SharedPreferences for auth persistence
-keep class androidx.preference.** { *; }
-keep class android.content.SharedPreferences { *; }
-keep class * implements android.content.SharedPreferences { *; }

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

# Keep all Flutter plugin registrant classes
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.embedding.engine.plugins.** { *; }

# Keep Firebase installations and persistence
-keep class com.google.firebase.installations.** { *; }
-keep class com.google.firebase.components.** { *; }
-keep class com.google.firebase.heartbeatinfo.** { *; }
-keep class com.google.firebase.platforminfo.** { *; }

# Keep all serialization for Firebase
-keepclassmembers class * {
  @com.google.firebase.database.PropertyName <methods>;
  @com.google.firebase.database.PropertyName <fields>;
  @com.google.firebase.firestore.PropertyName <methods>;
  @com.google.firebase.firestore.PropertyName <fields>;
}

# Prevent obfuscation of model classes
-keepnames class * extends java.io.Serializable
-keepclassmembers class * extends java.io.Serializable {
  static final long serialVersionUID;
  private static final java.io.ObjectStreamField[] serialPersistentFields;
  !static !transient <fields>;
  private void writeObject(java.io.ObjectOutputStream);
  private void readObject(java.io.ObjectInputStream);
  java.lang.Object writeReplace();
  java.lang.Object readResolve();
}
