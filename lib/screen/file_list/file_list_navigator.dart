import 'package:alist/router.dart';
import 'package:alist/screen/breadcrumb/components/fx_app_navigator_observer.dart';
import 'package:alist/screen/file_list/file_list_screen.dart';
import 'package:alist/widget/alist_will_pop_scope.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FileListNavigator extends StatefulWidget {
  const FileListNavigator({Key? key, required this.isInFileListStack})
      : super(key: key);
  final bool isInFileListStack;

  @override
  State<FileListNavigator> createState() => _FileListNavigatorState();
}

class _FileListNavigatorState extends State<FileListNavigator>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<NavigatorState>? _key =
      Get.nestedKey(AlistRouter.fileListRouterStackId);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AlistWillPopScope(
      onWillPop: () async {
        if (widget.isInFileListStack &&
            _key?.currentState != null &&
            _key?.currentState?.canPop() == true) {
          _key?.currentState?.pop();
          return false;
        }
        return true;
      },
      child: Column(
        children: [
          // 面包屑导航
          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 20),
          //   child: Row(
          //     children: [
          //       Obx(() {
          //         return FxBreadCrumbNavigator.shaped(
          //           key: GlobalKey(),
          //           firstRoute: "/",
          //           breadButtonType: BreadButtonType.shaped,
          //         );
          //       }),
          //     ],
          //   ),
          // ),
          Expanded(
            child: Navigator(
              key: _key,
              observers: [AppNavigatorObserver()],
              onGenerateRoute: (settings) {
                dynamic arguments = settings.arguments;
                return GetPageRoute(
                  settings: settings,
                  page: () => FileListScreen(
                    path: arguments?["path"],
                    sortBy: arguments?["sortBy"],
                    sortByUp: arguments?["sortByUp"],
                    backupPassword: arguments?["backupPassword"],
                    isRootStack: false,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
