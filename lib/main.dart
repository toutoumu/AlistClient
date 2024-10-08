import 'package:alist/l10n/alist_translations.dart';
import 'package:alist/l10n/intl_keys.dart';
import 'package:alist/router.dart';
import 'package:alist/util/log_utils.dart';
import 'package:alist/util/named_router.dart';
import 'package:alist/util/proxy.dart';
import 'package:alist/util/user_controller.dart';
import 'package:flustars/flustars.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import 'database/alist_database_controller.dart';
import 'generated/color_schemes.g.dart';

const customToolbarHeight = 45.0;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Necessary initialization for package:media_kit.
  MediaKit.ensureInitialized();
  // sp初始化
  SpUtil.getInstance();
  Log.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      initialRoute: NamedRouter.root,
      translations: AlistTranslations(),
      fallbackLocale: const Locale('en', 'US'),
      locale: PlatformDispatcher.instance.locale,
      getPages: AlistRouter.screens,
      builder: _routerBuilder,
      navigatorObservers: [FlutterSmartDialog.observer],
      // defaultTransition: Transition.cupertino,
      title: "ALClient",
      theme: _lightTheme(context),
      darkTheme: _dartTheme(context),
    );
  }

  Widget _routerBuilder(BuildContext context, Widget? widget) {
    final smartDialogInit = FlutterSmartDialog.init();
    Get.put(AlistDatabaseController());
    Get.put(UserController());
    Get.put(ProxyServer());

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaleFactor: 1),
      child: RefreshConfiguration(
          headerBuilder: () {
            return ClassicHeader(
              idleText: Intl.pullRefresh_idleRefreshText.tr,
              releaseText: Intl.pullRefresh_canRefreshText.tr,
              refreshingText: Intl.pullRefresh_refreshingText.tr,
              completeText: Intl.pullRefresh_refreshCompleteText.tr,
              failedText: Intl.pullRefresh_refreshFailedText.tr,
            );
          },
          child: smartDialogInit(context, widget)),
    );
  }

  ThemeData _dartTheme(BuildContext context) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: darkColorScheme,
      dividerTheme: DividerTheme.of(context).copyWith(
        thickness: 0,
        space: 0,
      ),
      appBarTheme: AppBarTheme.of(context).copyWith(
        toolbarHeight: customToolbarHeight,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Color(0xFF1A1C1E),
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      // 启用侧滑返回
      platform: TargetPlatform.iOS,
      // 转场动画
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  ThemeData _lightTheme(BuildContext context) {
    return ThemeData(
      useMaterial3: true,
      hintColor: const Color(0xFFBBBBBB),
      colorScheme: lightColorScheme,
      dividerTheme: DividerTheme.of(context).copyWith(
        thickness: 0,
        space: 0,
      ),
      appBarTheme: AppBarTheme.of(context).copyWith(
        toolbarHeight: customToolbarHeight,
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),
      // 启用侧滑返回
      platform: TargetPlatform.iOS,
      // 转场动画
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
