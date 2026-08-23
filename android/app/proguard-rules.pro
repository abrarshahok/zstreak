# Crashlytics needs the original file/line info preserved (mapped back
# through the uploaded R8 mapping file) to symbolicate obfuscated
# release stack traces - without this, crash reports are unreadable.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# gRPC (used by cloud_firestore) references a long tail of optional
# annotation/logging classes that are only present on some classpaths.
# R8 treats an unresolvable reference as a hard build error unless told
# it's fine to leave unresolved - these are the standard set for this
# exact stack, not app-specific guesses.
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
-dontwarn io.grpc.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn javax.naming.**
-dontwarn java.lang.management.**

# Play Billing / RevenueCat's own consumer rules cover their internals;
# this just keeps the small amount of app-visible purchase-result surface
# that's inspected by external tooling (Play Console, RevenueCat's own
# debug logs) intact.
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**
