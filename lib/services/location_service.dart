import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// آدرس IP سرور بک‌اند خود را جایگزین کنید
// برای شبیه‌ساز اندروید معمولا 10.0.2.2 و برای دستگاه واقعی IP سیستم در شبکه داخلی (مثل 192.168.1.X) است
const String wsUrl = 'ws://YOUR_BACKEND_IP:8000/ws/location';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true, // اجرای سرویس در حالت Foreground
      notificationChannelId: 'location_tracking',
      initialNotificationTitle: 'در حال انجام ماموریت',
      initialNotificationContent: 'موقعیت مکانی شما در حال ارسال است...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // اتصال به وب‌سوکت بک‌اند
  final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

  // تنظیمات دقت و فواصل ارسال موقعیت (مثلاً هر 10 متر جابجایی)
  const LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  );

  // گوش دادن به تغییرات لوکیشن
  StreamSubscription<Position> positionStream = Geolocator.getPositionStream(
    locationSettings: locationSettings,
  ).listen((Position? position) {
    if (position != null) {
      // ساختار دیتای ارسالی
      final data = {
        'driver_id': 1, // این شناسه را بعداً هنگام لاگین راننده پویا می‌کنیم
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // ارسال به سرور
      channel.sink.add(jsonEncode(data));
      print('Location sent: ${position.latitude}, ${position.longitude}');
    }
  });

  // دریافت دستور توقف از اپلیکیشن اصلی
  service.on('stopService').listen((event) {
    positionStream.cancel();
    channel.sink.close();
    service.stopSelf();
  });
}
