# 🛡️ NetGuard Pro v4.0 - Enterprise Security Edition

**Professional Network Security Audit Tool | أداة فحص أمان الشبكات الاحترافية**

![Version](https://img.shields.io/badge/version-4.0.0-blue)
![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.24.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)

> **🚀 النسخة المؤسسية مع 15+ أداة فحص حقيقية + IDS + Leak Detection!**

## 🌟 المميزات الجديدة في v4.0

### 🆕 أدوات الأمان المتقدمة:
1. **🛡️ Intrusion Detection System (IDS)** - كشف التسلل في الوقت الفعلي
2. **📡 Packet Capture** - التقاط حزم الشبكة (يتطلب root)
3. **⚠️ Deauth Attack Detector** - كشف هجمات قطع WiFi
4. **🦹 Rogue AP Detector** - كشف نقاط الوصول المزيفة (Evil Twin)
5. **🎭 MAC Spoofing Detector** - كشف تزييف عناوين MAC
6. **🌐 DNS Leak Test** - كشف تسريب DNS
7. **📹 WebRTC Leak Test** - كشف تسريب WebRTC
8. **🔒 Captive Portal Detector** - كشف البوابات الأسيرة
9. **🔥 Firewall Tester** - اختبار جدار الحماية

### ✅ كل أدوات v3.0:
10. **🔓 Local Port Scanner** - فحص بورتات حقيقي
11. **📡 Network Discovery** - كشف أجهزة الشبكة
12. **🌐 DNS Lookup** - فحص DNS records
13. **🏓 Ping & Traceroute** - حقيقي
14. **🔒 SSL/TLS Scanner** - فحص الشهادات
15. **📶 Speed Test** - قياس السرعة
16. **🎯 WPS PIN Calculator** - 8 خوارزميات
17. **🔑 Password Analyzer**
18. **📚 CVE Database**
19. **🗺️ Network Map**
20. **📊 Security Report**

### 🎨 مميزات احترافية:
- **AI-powered Recommendations** - توصيات ذكية باستخدام LLM
- **Network Map Visualization** - رسم بياني للأجهزة
- **Scan History** - سجل كامل لكل الفحوصات
- **Offline Support** - تشتغل بدون إنترنت (الفحوصات المحلية)
- **Bilingual (AR/EN)** - ثنائي اللغة كامل
- **Dark/Light/System Theme** - ثيمات متعددة
- **Premium/IAP** - نظام اشتراكات
- **PWA Ready** - قابل للتثبيت كتطبيق

## 🛠️ التقنيات المستخدمة

### Frontend (Flutter):
| التقنية | الاستخدام |
|---------|-----------|
| Flutter 3.24 | Framework |
| Dart 3.0+ | Language |
| Provider | State Management |
| Dio | HTTP Client + Interceptors |
| Hive | Local Database |
| fl_chart | Charts & Network Map |
| google_mobile_ads | AdMob |
| unity_ads_plugin | Unity Ads |
| pdf | PDF Generation |
| network_info_plus | WiFi Info |
| connectivity_plus | Network Status |
| device_info_plus | Device Info |

### Backend (Next.js):
| التقنية | الاستخدام |
|---------|-----------|
| Next.js 16 | API Routes |
| TypeScript | Type Safety |
| Z.AI SDK | AI Recommendations |
| Cloudflare DoH | DNS-over-HTTPS |

## 📂 هيكل المشروع

```
netguard_flutter/
├── .github/workflows/
│   └── build-flutter.yml          # CI/CD كامل
├── android/app/src/main/
│   └── AndroidManifest.xml        # أذونات شاملة
├── ios/Runner/
│   └── Info.plist                 # iOS permissions
├── lib/
│   ├── main.dart                  # Entry point
│   ├── l10n/                      # ترجمات (عربي/إنجليزي)
│   ├── models/                    # نماذج البيانات
│   ├── providers/                 # State management
│   │   ├── theme_provider.dart
│   │   ├── locale_provider.dart
│   │   ├── premium_provider.dart
│   │   └── history_provider.dart
│   ├── services/
│   │   ├── api_service.dart       # Backend API
│   │   ├── ads_service.dart       # AdMob + Unity
│   │   └── local/                 # ✅ خدمات محلية حقيقية
│   │       ├── port_scanner.dart       # فحص بورتات حقيقي
│   │       ├── network_discovery.dart  # كشف أجهزة الشبكة
│   │       ├── dns_service.dart        # DNS lookup
│   │       ├── ping_service.dart       # Ping & Traceroute
│   │       ├── ssl_scanner.dart        # SSL/TLS فحص
│   │       └── wifi_info_service.dart  # معلومات WiFi
│   ├── storage/
│   │   └── hive_service.dart      # Local database
│   ├── screens/
│   │   ├── main_screen.dart       # Main navigation
│   │   ├── dashboard_screen.dart
│   │   ├── wps_calculator_screen.dart
│   │   ├── port_scanner_screen.dart
│   │   ├── password_analyzer_screen.dart
│   │   ├── cve_database_screen.dart
│   │   ├── router_detector_screen.dart
│   │   ├── signal_analyzer_screen.dart
│   │   ├── report_screen.dart
│   │   ├── settings_screen.dart
│   │   ├── history_screen.dart
│   │   ├── onboarding/
│   │   │   └── onboarding_screen.dart
│   │   └── advanced/              # ✅ شاشات متقدمة
│   │       ├── network_map_screen.dart
│   │       ├── dns_lookup_screen.dart
│   │       ├── ping_screen.dart
│   │       ├── ssl_scanner_screen.dart
│   │       └── speed_test_screen.dart
│   ├── widgets/
│   │   ├── ad_banner_widget.dart
│   │   ├── custom/
│   │   │   ├── glass_card.dart
│   │   │   ├── score_indicator.dart
│   │   │   └── loading_overlay.dart
│   │   └── charts/
│   │       └── network_map.dart   # Network visualization
│   └── utils/
│       ├── theme.dart
│       └── export/
│           └── export_service.dart # PDF/CSV/JSON
├── test/
│   ├── unit/
│   └── widget/
└── pubspec.yaml
```

## 🚀 البدء السريع

### الطريقة 1: البناء المحلي

```bash
# استنساخ المشروع
git clone https://github.com/YOUR_USERNAME/netguard_flutter.git
cd netguard_flutter

# تثبيت الاعتمادات
flutter pub get

# تشغيل في وضع التطوير
flutter run

# بناء APK للإصدار (3 ABIs)
flutter build apk --release --split-per-abi

# بناء AAB للـ Google Play
flutter build appbundle --release
```

### الطريقة 2: البناء السحابي عبر GitHub Actions

1. **ارفع المشروع على GitHub:**
```bash
git init
git add .
git commit -m "NetGuard Pro v3.0 - Advanced Edition"
git push origin main
```

2. **أضف GitHub Secrets** (Settings → Secrets and variables → Actions):
- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEY_PROPERTIES`
- `ADMOB_APP_ID`
- `ADMOB_BANNER_ID`, `ADMOB_INTERSTITIAL_ID`, `ADMOB_REWARDED_ID`
- `UNITY_GAME_ID`
- `TELEGRAM_BOT_TOKEN` (اختياري)

3. **أنشئ Release تلقائياً:**
```bash
git tag v3.0.0
git push origin v3.0.0
```

## 🔧 إعداد Backend (للميزات الإضافية)

التطبيق يحتاج backend للميزات الإضافية (AI recommendations, CVE database):

1. انشر مشروع Next.js على Vercel:
```bash
cd nextjs_backend
vercel --prod
```

2. حدّث رابط الـ API في `lib/services/api_service.dart`:
```dart
static const String baseUrl = 'https://your-app.vercel.app';
```

**ملاحظة:** الفحوصات المحلية (Port Scanner, Network Discovery, DNS, Ping, SSL, Speed Test) تشتغل بدون backend.

## 📢 إعداد الإعلانات

### Google AdMob:
1. سجّل في [apps.admob.com](https://apps.admob.com)
2. أنشئ تطبيق + وحدات إعلانية (Banner, Interstitial, Rewarded)
3. استبدل المعرّفات في:
   - `lib/services/ads_service.dart`
   - `android/app/src/main/AndroidManifest.xml`

### Unity Ads:
1. سجّل في [dashboard.unity3d.com](https://dashboard.unity3d.com)
2. استبدل `_unityGameId` في `lib/services/ads_service.dart`

## 🔐 الصلاحيات المطلوبة

### Android:
- `INTERNET` - للاتصال بالإنترنت
- `ACCESS_NETWORK_STATE` - حالة الشبكة
- `ACCESS_WIFI_STATE` - معلومات WiFi
- `ACCESS_FINE_LOCATION` - لمسح WiFi (Android 6+)
- `LOCAL_NETWORK` - لفحص الشبكة المحلية
- `WAKE_LOCK` - للفحص في الخلفية

### iOS:
- `NSLocationWhenInUseUsageDescription` - للوصول للموقع
- `NSLocalNetworkUsageDescription` - للشبكة المحلية

## 📊 مقارنة النسخ

| الميزة | v1.0 | v2.0 | v3.0 |
|--------|------|------|------|
| **الفحوصات المحلية** | ❌ | ❌ | ✅ |
| **State Management** | بسيط | بسيط | Provider كامل |
| **Offline Support** | ❌ | ❌ | ✅ |
| **AI Recommendations** | ❌ | ❌ | ✅ |
| **Network Map** | ❌ | ❌ | ✅ |
| **PDF/CSV Export** | ❌ | ❌ | ✅ |
| **Tests** | ❌ | ❌ | ✅ |
| **Premium/IAP** | ❌ | ❌ | ✅ |
| **عدد الأدوات** | 5 | 9 | **13** |
| **عدد الملفات** | 22 | 35 | **45+** |

## ⚠️ تنبيه قانوني

```
هذا التطبيق مخصص للأغراض التعليمية وفحص أمان شبكتك الخاصة فقط.
الاستخدام غير المصرّح به لاختبار شبكات الآخرين مخالف للقانون في أغلب الدول.

This app is for educational purposes and auditing your own network only.
Unauthorized testing of others' networks is illegal in most countries.
```

## 📜 الترخيص

MIT License

## 📧 الدعم

- GitHub Issues: [report issues](https://github.com/YOUR_USERNAME/netguard_flutter/issues)

---

**Made with ❤️ using Flutter | صُنع بحب باستخدام Flutter**
