import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // اضافه شدن بررسی پلتفرم وب
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'services/location_service.dart';

void main() async {
  // اطمینان از مقداردهی اولیه ویجت‌های فلاتر قبل از اجرای سرویس‌ها
  WidgetsFlutterBinding.ensureInitialized();
  
  // راه‌اندازی سرویس فقط در صورتی که روی وب نباشیم
  if (!kIsWeb) {
    try {
      await initializeBackgroundService();
    } catch (e) {
      debugPrint("Error initializing background service: $e");
    }
  } else {
    debugPrint("برنامه روی وب اجرا شده است. سرویس پس‌زمینه غیرفعال شد.");
  }
  
  runApp(const DriverApp());
}

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'اپلیکیشن راننده',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TrackingScreen(),
    );
  }
}

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  String statusText = "در حال بررسی دسترسی‌ها...";
  bool isRunning = false;

  @override
  void initState() {
    super.initState();
    checkPermissions();
  }

  Future<void> checkPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    // بررسی روشن بودن GPS دستگاه
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => statusText = "لطفاً GPS دستگاه را روشن کنید.");
      return;
    }

    // بررسی مجوز دسترسی به لوکیشن
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => statusText = "دسترسی موقعیت مکانی رد شد.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => statusText = "دسترسی موقعیت مکانی برای همیشه مسدود شده است.");
      return;
    }

    setState(() => statusText = "دسترسی‌ها تأیید شد. آماده تخصیص سفارش.");
  }

  void startTracking() async {
    if (kIsWeb) {
      setState(() => statusText = "سرویس ردیابی روی مرورگر وب پشتیبانی نمی‌شود! لطفا روی اندروید تست کنید.");
      return;
    }

    final service = FlutterBackgroundService();
    var isServiceRunning = await service.isRunning();
    
    if (!isServiceRunning) {
      service.startService();
      setState(() {
        isRunning = true;
        statusText = "در حال ردیابی و ارسال موقعیت به سیستم حسابداری...";
      });
    }
  }

  void stopTracking() async {
    if (kIsWeb) {
      setState(() {
        isRunning = false;
        statusText = "ردیابی متوقف شد.";
      });
      return;
    }

    final service = FlutterBackgroundService();
    service.invoke("stopService");
    setState(() {
      isRunning = false;
      statusText = "ردیابی متوقف شد.";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('پنل راننده'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_on,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 20),
              Text(
                statusText,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: isRunning ? null : startTracking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  'شروع ماموریت (ردیابی)',
                  style: TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: isRunning ? stopTracking : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  'پایان ماموریت (توقف ردیابی)',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
