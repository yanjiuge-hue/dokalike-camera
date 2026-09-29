# DokaLike Camera R8 混淆规则
# tflite_flutter 通过 FFI (JNI) 访问原生库，保留必要符号
-keep class com.google.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.** { *; }

# ML Kit 人脸检测
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# gal（系统相册写入）
-keep class com.gal.** { *; }
