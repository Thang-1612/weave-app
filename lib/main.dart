import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/deep_link.dart';
import 'services/user_prefs.dart';
import 'services/chat_service.dart';

/// Khóa site key reCAPTCHA v3 (khóa công khai, được phép để trong code).
/// Lấy ở trang quản trị reCAPTCHA, sau đó đăng ký trong Firebase Console.
const _recaptchaSiteKey = 'DÁN_SITE_KEY_RECAPTCHA_V3_VÀO_ĐÂY';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // địa chỉ dạng /post/abc thay vì /#/post/abc
  DeepLink.captureInitial();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _activateAppCheck();
  await UserPrefs.instance.loadLocal(); // ngôn ngữ đã chọn trên thiết bị này
  ChatConfig.userNameField = 'displayName';
  runApp(const SocialApp());
}

/// Bật App Check ngay sau khi khởi tạo Firebase, trước khi gọi dịch vụ nào.
/// Lỗi ở đây không được làm app dừng hẳn: ở chế độ theo dõi, app vẫn chạy.
Future<void> _activateAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      providerWeb: ReCaptchaV3Provider(_recaptchaSiteKey),
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (e) {
    debugPrint('[AppCheck] activate lỗi: $e');
  }
}
