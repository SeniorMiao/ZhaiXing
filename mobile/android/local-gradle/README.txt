若 flutter run 报 Gradle PKIX / SSLHandshakeException：

Gradle 分发包必须放在与 gradle-wrapper.properties 同一目录：
  mobile/android/gradle/wrapper/gradle-8.14-all.zip

1) 浏览器下载后，把文件放到上述路径（文件名必须一致）：
   https://services.gradle.org/distributions/gradle-8.14-all.zip

2) 或在 mobile/android 目录下执行：
   .\local-gradle\download_gradle.ps1
   （脚本会把 zip 下载到 gradle/wrapper/）

3) 再执行 flutter run。
