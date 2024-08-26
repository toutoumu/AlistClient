import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:alist/entity/app_version_resp.dart';
import 'package:alist/l10n/intl_keys.dart';
import 'package:alist/net/dio_utils.dart';
import 'package:alist/router.dart';
import 'package:alist/screen/file_list/file_list_navigator.dart';
import 'package:alist/screen/recents_screen.dart';
import 'package:alist/screen/settings_screen.dart';
import 'package:alist/util/constant.dart';
import 'package:alist/util/global.dart';
import 'package:alist/widget/bottom_navigation_bar.dart';
import 'package:alist/widget/update_dialog.dart';
import 'package:flustars/flustars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:responsive_builder/responsive_builder.dart';

import 'favorite_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page?.round() ?? 0;
      });
    });
    _httpCheckAppVersion();
  }

  @override
  Widget build(BuildContext context) {
    return _buildResponsive();
    // 原有代码
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: <Widget>[
          FileListNavigator(
            isInFileListStack: _currentPage == 0,
          ),
          const RecentsScreen(),
          const FavoriteScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: AlistBottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.folder_rounded),
            label: Intl.screenName_home.tr,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.timelapse_rounded),
            label: Intl.screenName_recents.tr,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.star_rounded),
            label: Intl.screenName_favorite.tr,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_rounded),
            label: Intl.screenName_settings.tr,
          )
        ],
        currentIndex: _currentPage,
        type: BottomNavigationBarType.fixed,
        onTap: (int idx) => _pageController.jumpToPage(idx),
        onLongPress: (int idx) {
          LogUtil.d("onDoubleTap: $idx");
          if (idx == 0 && _currentPage == 0) {
            Get.until((route) => route.isFirst,
                id: AlistRouter.fileListRouterStackId);
          } else {
            _pageController.jumpToPage(idx);
          }
        },
      ),
    );
  }

  ResponsiveBuilder _buildResponsive() {
    return ResponsiveBuilder(
      builder: (BuildContext context, SizingInformation sizingInformation) {
        return Scaffold(
          body: Row(
            children: [
              if (!sizingInformation.isMobile)
                NavigationRail(
                  selectedIndex: _currentPage,
                  // 设置选中项的索引
                  onDestinationSelected: (int index) {
                    setState(() {
                      _currentPage = index; // 处理目标选中事件
                    });
                  },
                  extended: sizingInformation.isDesktop,
                  leading: sizingInformation.isDesktop
                      ? const Text("AlistClient")
                      : null,
                  // 显示所有标签
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.folder_rounded),
                      label: Text(Intl.screenName_home.tr),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.timelapse_rounded),
                      label: Text(Intl.screenName_recents.tr),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.star_rounded),
                      label: Text(Intl.screenName_favorite.tr),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.settings_rounded),
                      label: Text(Intl.screenName_settings.tr),
                    )
                  ],
                ),
              // 页面内容组件
              Expanded(
                child: IndexedStack(
                  index: _currentPage,
                  children: <Widget>[
                    Column(
                      children: [
                        /*SizedBox(
                          height: customToolbarHeight,
                          child: Row(
                            children: [
                              Obx(() {
                                return FxBreadCrumbNavigator.simple(
                                  key: GlobalKey(),
                                  firstRoute: "/",
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer,
                                  breadButtonType: BreadButtonType.shaped,
                                );
                              }),
                            ],
                          ),
                        ),*/
                        Expanded(
                          child: FileListNavigator(
                            isInFileListStack: _currentPage == 0,
                          ),
                        ),
                      ],
                    ),
                    const RecentsScreen(),
                    const FavoriteScreen(),
                    const SettingsScreen(),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: sizingInformation.isMobile
              ? AlistBottomNavigationBar(
                  items: <BottomNavigationBarItem>[
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.folder_rounded),
                      label: Intl.screenName_home.tr,
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.timelapse_rounded),
                      label: Intl.screenName_recents.tr,
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.star_rounded),
                      label: Intl.screenName_favorite.tr,
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.settings_rounded),
                      label: Intl.screenName_settings.tr,
                    )
                  ],
                  currentIndex: _currentPage,
                  type: BottomNavigationBarType.fixed,
                  onTap: (int idx) {
                    setState(() {
                      _currentPage = idx; // 处理目标选中事件
                    });
                  },
                  onLongPress: (int idx) {
                    LogUtil.d("onDoubleTap: $idx");
                    if (idx == 0 && _currentPage == 0) {
                      Get.until((route) => route.isFirst,
                          id: AlistRouter.fileListRouterStackId);
                    } else {
                      setState(() {
                        _currentPage = idx; // 处理目标选中事件
                      });
                    }
                  },
                )
              : null,
        );
      },
    );
  }

  Future<void> _httpCheckAppVersion() async {
    var packageInfo = await PackageInfo.fromPlatform();
    String version = packageInfo.version;
    String url =
        "https://${Global.configServerHost}/app/version.json?version=$version";
    DioUtils.instance.requestForString(Method.get, url,
        onSuccess: (string) async {
      if (string == null || string.isEmpty) return;
      Map<String, dynamic> json = jsonDecode(string);
      var appVersionResp = AppVersionResp.fromJson(json);
      String respVersion;
      if (Platform.isIOS) {
        respVersion = appVersionResp.ios.version;
      } else {
        respVersion = appVersionResp.android.version;
      }
      if (_version2Int(respVersion) > _version2Int(version)) {
        _showUpdateDialog(appVersionResp);
      }
    });
  }

  int _version2Int(String version) {
    var versionInt = 0;
    var arr = version.split(".");
    for (int i = 0; i < arr.length; i++) {
      versionInt += int.parse(arr[i]) * pow(100, arr.length - i - 1).toInt();
    }
    return versionInt;
  }

  void _showUpdateDialog(AppVersionResp appVersion) {
    String version =
        Platform.isIOS ? appVersion.ios.version : appVersion.android.version;
    String? ignoreVersion = SpUtil.getString(AlistConstant.ignoreAppVersion);
    if (version == ignoreVersion) {
      return;
    }
    SmartDialog.show(
      clickMaskDismiss: false,
      builder: (_) => UpdateDialog(appVersion: appVersion),
    );
  }
}
