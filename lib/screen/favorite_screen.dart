import 'dart:async';
import 'dart:io';

import 'package:alist/database/alist_database_controller.dart';
import 'package:alist/database/table/favorite.dart';
import 'package:alist/database/table/file_viewing_record.dart';
import 'package:alist/entity/file_list_resp_entity.dart';
import 'package:alist/l10n/intl_keys.dart';
import 'package:alist/net/dio_utils.dart';
import 'package:alist/screen/audio_player_screen.dart';
import 'package:alist/screen/file_reader_screen.dart';
import 'package:alist/screen/gallery_screen.dart';
import 'package:alist/screen/pdf_reader_screen.dart';
import 'package:alist/screen/video_player_screen.dart';
import 'package:alist/util/constant.dart';
import 'package:alist/util/download/download_manager.dart';
import 'package:alist/util/file_password_helper.dart';
import 'package:alist/util/file_type.dart';
import 'package:alist/util/file_utils.dart';
import 'package:alist/util/markdown_utils.dart';
import 'package:alist/util/named_router.dart';
import 'package:alist/util/nature_sort.dart';
import 'package:alist/util/string_utils.dart';
import 'package:alist/util/user_controller.dart';
import 'package:alist/util/video_player_util.dart';
import 'package:alist/widget/alist_scaffold.dart';
import 'package:alist/widget/file_details_dialog.dart';
import 'package:alist/widget/file_list_item_view.dart';
import 'package:dio/dio.dart';
import 'package:floor/floor.dart';
import 'package:flustars/flustars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({Key? key}) : super(key: key);

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen>
    with AutomaticKeepAliveClientMixin {
  final UserController _userController = Get.find();
  final CancelToken _cancelToken = CancelToken();
  final AlistDatabaseController _databaseController = Get.find();
  final _loading = true.obs;
  final _list = <Favorite>[].obs;
  StreamSubscription? _recordListSubscription;
  StreamSubscription? _userStreamSubscription;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _userController.user.value;
    _userStreamSubscription = _userController.user.stream.listen((event) {
      if (_currentUser?.serverUrl != event.serverUrl ||
          _currentUser?.username != event.username) {
        _list.value = [];
        _currentUser = event;
        _recordListSubscription?.cancel();
        _queryRecents();
      }
    });
    _queryRecents();
  }

  @override
  void dispose() {
    _cancelToken.cancel();
    _userStreamSubscription?.cancel();
    _recordListSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AlistScaffold(
      appbarTitle: Text(Intl.screenName_favorite.tr),
      body: Obx(
        () => !_loading.value && _list.isEmpty
            ? Center(
                child: Text(Intl.recentsScreen_noRecord.tr),
              )
            : _fileListView(),
      ),
    );
  }

  Widget _fileListView() {
    return SlidableAutoCloseBehavior(
      child: ListView.separated(
        itemBuilder: (context, item) {
          var record = _list[item];
          return _fileListItemView(context, record);
        },
        separatorBuilder: (context, item) => const Divider(),
        itemCount: _list.length,
      ),
    );
  }

  Widget _fileListItemView(BuildContext context, Favorite record) {
    var createTime = DateTime.fromMillisecondsSinceEpoch(record.createTime);
    return Slidable(
      key: Key(record.path),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => _showDetailsDialog(context, record),
            backgroundColor: Get.theme.colorScheme.secondary,
            foregroundColor: Colors.white,
            label: Intl.recentsScreen_menu_details.tr,
          ),
          SlidableAction(
            onPressed: (context) => _cancelFavorite(record),
            backgroundColor: const Color(0xFFFE4A49),
            foregroundColor: Colors.white,
            label: Intl.recentsScreen_menu_delete.tr,
          ),
        ],
      ),
      child: FileListItemView(
        icon: FileUtils.getFileIcon(record.isDir, record.name),
        fileName: record.name,
        thumbnail: record.thumb,
        time: FileUtils.getReformatTime(createTime, ""),
        sizeDesc: record.isDir ? null : FileUtils.formatBytes(record.size),
        onTap: () => _onFileTap(context, record, false),
        onMoreIconButtonTap: () => _showBottomMenuDialog(context, record),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  void _queryRecents() {
    var user = _userController.user.value;
    _recordListSubscription = _databaseController.favoriteDao
        .list(user.serverUrl, user.username)
        .listen((list) {
      var newList = list ?? [];
      var originalList = _list.value;
      _tryQueryThumbs(originalList, newList);
      _list.value = newList;
      _loading.value = false;
    });
  }

  Future<void> _onFileTap(
      BuildContext context, Favorite file, bool fromDialog) async {
    FileType fileType = FileUtils.getFileType(file.isDir, file.name);
    if (!file.isDir) {
      _fileViewingRecord(file);
    }

    switch (fileType) {
      case FileType.folder:
        Get.toNamed(
          NamedRouter.fileList,
          arguments: {
            "path": file.path,
          },
        );
        break;
      case FileType.video:
        _gotoVideoPlayer(context, file, fromDialog);
        break;
      case FileType.audio:
        _gotoAudioPlayer(file);
        break;
      case FileType.image:
        _gotoGalleryScreen(file);
        break;
      case FileType.pdf:
        var pdfItem = PdfItem(
          name: file.name,
          remotePath: file.path,
          sign: file.sign,
          provider: file.provider,
          thumb: file.thumb,
        );
        Get.toNamed(
          NamedRouter.pdfReader,
          arguments: {"pdfItem": pdfItem},
        );
        break;
      case FileType.markdown:
        _previewMarkdown(file);
        break;
      case FileType.txt:
      case FileType.word:
      case FileType.excel:
      case FileType.ppt:
      case FileType.code:
      case FileType.apk:
      case FileType.compress:
      default:
        if (await _showDownloadDialog(context)) {
          var fileReaderItem = FileReaderItem(
            name: file.name,
            remotePath: file.path,
            sign: file.sign,
            provider: file.provider,
            thumb: file.thumb,
            fileType: FileUtils.getFileType(false, file.name),
          );
          Get.toNamed(
            NamedRouter.fileReader,
            arguments: {"fileReaderItem": fileReaderItem},
          );
        }
        break;
    }
  }

  Future<bool> _showDownloadDialog(context) async {
    return await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return AlertDialog(
            title: Text(Intl.fileList_menu_download.tr),
            content: Text(Intl.fileList_menu_download.tr),
            actions: [
              TextButton(
                onPressed: () {
                  // SmartDialog.dismiss();
                  Get.back(result: false);
                },
                child: Text(Intl.deleteAccountDialog_btn_cancel.tr),
              ),
              TextButton(
                onPressed: () {
                  // SmartDialog.dismiss();
                  Get.back(result: true);
                },
                child: Text(Intl.deleteAccountDialog_btn_ok.tr),
              ),
            ],
          );
        });
  }

  @transaction
  Future<void> _fileViewingRecord(Favorite file) async {
    var user = _userController.user.value;
    var recordDao = _databaseController.fileViewingRecordDao;
    await recordDao.deleteByPath(user.serverUrl, user.username, file.path);
    await recordDao.insertRecord(FileViewingRecord(
      serverUrl: user.serverUrl,
      userId: user.username,
      remotePath: file.path,
      name: file.name,
      path: file.path,
      size: file.size,
      sign: file.sign,
      thumb: file.thumb,
      modified: file.modified,
      provider: file.provider,
      createTime: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  void _previewMarkdown(Favorite file) async {
    var fileLink = await FileUtils.makeFileLink(file.remotePath, file.sign);
    if (fileLink != null) {
      Get.toNamed(NamedRouter.web, arguments: {
        "url": MarkdownUtil.makePreviewUrl(fileLink),
        "title": file.name
      });
    }
  }

  void _cancelFavorite(Favorite favorite) {
    _databaseController.favoriteDao.deleteRecord(favorite);
  }

  _showDetailsDialog(BuildContext context, Favorite record) {
    var modified = DateTime.fromMillisecondsSinceEpoch(record.modified);
    showModalBottomSheet(
      context: context,
      builder: (context) => FileDetailsDialog(
        name: record.name,
        size: FileUtils.formatBytes(record.size),
        path: record.path,
        modified: FileUtils.getReformatTime(modified, ""),
        thumb: record.thumb,
        provider: record.provider,
      ),
    );
  }

  _showBottomMenuDialog(BuildContext context, Favorite record) {
    var modified = DateTime.fromMillisecondsSinceEpoch(record.modified);
    showModalBottomSheet(
        context: context,
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: SafeArea(
              child: Wrap(
                children: [
                  FileListItemView(
                    icon: FileUtils.getFileIcon(record.isDir, record.name),
                    fileName: record.name,
                    thumbnail: record.thumb,
                    time: FileUtils.getReformatTime(modified, ""),
                    sizeDesc: FileUtils.formatBytes(record.size),
                    onTap: () {
                      Navigator.pop(context);
                      _onFileTap(context, record, true);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.open_in_new),
                    title: Text(Intl.recentsScreen_menu_open.tr),
                    onTap: () {
                      Navigator.pop(context);
                      _onFileTap(context, record, true);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.folder_rounded),
                    title: Text(Intl.recentsScreen_menu_showInFolder.tr),
                    onTap: () {
                      Navigator.pop(context);
                      _openFileDirectory(record);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.link_rounded),
                    title: Text(Intl.fileList_menu_copyLink.tr),
                    onTap: () {
                      Navigator.pop(context);
                      FileUtils.copyFileLink(record.path, record.sign);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.favorite_rounded),
                    title: Text(Intl.fileList_menu_cancel_favorite.tr),
                    onTap: () {
                      Navigator.pop(context);
                      _cancelFavorite(record);
                    },
                  ),
                  if (!record.isDir)
                    ListTile(
                      leading: const Icon(Icons.download_rounded),
                      title: Text(Intl.fileList_menu_download.tr),
                      onTap: () async {
                        Navigator.pop(context);

                        final requestHeaders = <String, dynamic>{};
                        var limitFrequency = 0;
                        if (record.provider == "BaiduNetdisk") {
                          requestHeaders[HttpHeaders.userAgentHeader] =
                              "pan.baidu.com";
                        } else if (record.provider == "AliyundriveOpen") {
                          // 阿里云盘下载请求频率限制为 1s/次
                          limitFrequency = 1;
                        }
                        final task = await DownloadManager.instance.enqueue(
                            name: record.name,
                            remotePath: record.remotePath,
                            sign: record.sign ?? "",
                            thumb: record.thumb,
                            requestHeaders: requestHeaders,
                            limitFrequency: limitFrequency);
                        if (task != null) {
                          var isFirstTimeDownload = SpUtil.getBool(
                            AlistConstant.isFirstTimeDownload,
                            defValue: true,
                          );
                          if (isFirstTimeDownload == true) {
                            SpUtil.putBool(
                                AlistConstant.isFirstTimeDownload, false);
                            _showDownloadTipDialog();
                          } else {
                            SmartDialog.showToast(
                                Intl.downloadManager_tips_addToQueue.tr);
                          }
                        }
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.info),
                    title: Text(Intl.recentsScreen_menu_details.tr),
                    onTap: () {
                      Navigator.pop(context);
                      _showDetailsDialog(context, record);
                    },
                  ),
                ],
              ),
            ),
          );
        });
  }

  void _showDownloadTipDialog() {
    SmartDialog.show(
        clickMaskDismiss: false,
        builder: (context) {
          return AlertDialog(
            title: Text(Intl.downloadManager_downloadTipDialog_title.tr),
            content: Text(Intl.downloadManager_downloadTipDialog_content.tr),
            actions: [
              TextButton(
                onPressed: () {
                  SmartDialog.dismiss();
                },
                child: Text(Intl.downloadManager_downloadTipDialog_iKnow.tr),
              ),
            ],
          );
        });
  }

  void _openFileDirectory(Favorite record) {
    var path = record.path;
    var index = path.lastIndexOf("/");
    if (index >= 0) {
      path = path.substring(0, index);
    }
    LogUtil.d("path=$path index=$index");
    Get.toNamed(
      NamedRouter.fileList,
      arguments: {"path": path},
    );
  }

  Future<List<FileItemVO>?> _loadFilesPrepare(
    String folderPath,
    String filePath,
    FileType fileType,
  ) async {
    // query file's password from database.
    var filePassword = await FilePasswordHelper().fastFindPassword(folderPath);
    String? password;
    if (filePassword != null) {
      password = filePassword;
    }
    return await _loadFiles(folderPath, filePath, password, fileType);
  }

  Future<List<FileItemVO>?> _loadFiles(
    String folderPath,
    String filePath,
    String? password,
    FileType fileType,
  ) async {
    var body = {
      "path": folderPath,
      "password": password ?? "",
      "page": 1,
      "per_page": 0,
      "refresh": false
    };

    List<FileItemVO>? result;
    await DioUtils.instance.requestNetwork<FileListRespEntity>(
        Method.post, "fs/list", cancelToken: _cancelToken, params: body,
        onSuccess: (data) async {
      var files = data?.content
          ?.map((e) => _fileResp2VO(folderPath, data.provider, e))
          .where((element) => element.type == fileType)
          .toList();
      files?.sort((a, b) => NaturalSort.compare(a.name, b.name));
      result = files;
    }, onError: (code, msg) {
      SmartDialog.showToast(msg);
      debugPrint(msg);
    });
    return result;
  }

  FileItemVO _fileResp2VO(
      String path, String provider, FileListRespContent resp) {
    DateTime? modifyTime = resp.parseModifiedTime();
    String? modifyTimeStr = resp.getReformatModified(modifyTime);

    return FileItemVO(
      name: resp.name,
      path: resp.getCompletePath(path),
      size: resp.isDir ? null : resp.size,
      sizeDesc: resp.formatBytes(),
      isDir: resp.isDir,
      modified: modifyTimeStr,
      typeInt: resp.type,
      type: resp.getFileType(),
      thumb: resp.isDir ? "" : resp.thumb,
      sign: resp.sign,
      icon: resp.getFileIcon(),
      modifiedMilliseconds: modifyTime?.millisecondsSinceEpoch ?? -1,
      provider: provider,
    );
  }

  void _gotoVideoPlayer(
      BuildContext context, Favorite file, bool showSelector) async {
    SmartDialog.showLoading();
    var files = await _loadFilesPrepare(
        file.path.substringBeforeLast("/")!, file.path, FileType.video);
    SmartDialog.dismiss();
    if (files == null) {
      return;
    }

    var index = files.lastIndexWhere((element) => element.path == file.path);
    if (index == -1) {
      index = 0;
    }
    var videos = files
        .map(
          (e) => VideoItem(
            name: e.name,
            remotePath: e.path,
            sign: e.sign,
            provider: e.provider,
            thumb: e.thumb,
            size: e.size,
            modifiedMilliseconds: e.modifiedMilliseconds,
          ),
        )
        .toList();
    var password = await FilePasswordHelper().fastFindPassword(file.path);
    if (showSelector) {
      if (context.mounted) {
        VideoPlayerUtil.selectThePlayerToPlay(
            Get.context!, videos, index, password);
      }
    } else {
      VideoPlayerUtil.go(videos, index, password);
    }
  }

  void _gotoAudioPlayer(Favorite file) async {
    SmartDialog.showLoading();
    var files = await _loadFilesPrepare(
        file.path.substringBeforeLast("/")!, file.path, FileType.audio);
    SmartDialog.dismiss();
    if (files == null) {
      return;
    }

    var index = files.lastIndexWhere((element) => element.path == file.path);
    if (index == -1) {
      index = 0;
    }

    var audios = files
        .map(
          (e) => AudioItem(
            name: e.name,
            remotePath: e.path,
            sign: e.sign,
            provider: e.provider,
          ),
        )
        .toList();
    Get.toNamed(
      NamedRouter.audioPlayer,
      arguments: {
        "audios": audios,
        "index": index,
      },
    );
  }

  void _gotoGalleryScreen(Favorite file) async {
    SmartDialog.showLoading();
    var files = await _loadFilesPrepare(
        file.path.substringBeforeLast("/")!, file.path, FileType.image);
    SmartDialog.dismiss();
    if (files == null) {
      return;
    }

    var index = files.lastIndexWhere((element) => element.path == file.path);
    if (index == -1) {
      index = 0;
    }
    var photos = files
        .map(
          (e) => PhotoItem(
            name: e.name,
            remotePath: e.path,
            sign: e.sign,
            provider: e.provider,
          ),
        )
        .toList();
    Get.toNamed(
      NamedRouter.gallery,
      arguments: {
        "files": photos,
        "index": index,
      },
    );
  }

  // 对比之前的列表，查询新增的记录的缩略图并更新
  void _tryQueryThumbs(
      List<Favorite> originalList, List<Favorite> newList) async {
    // 记录当前的user，切换用户时终止查询
    var currentUser = _userController.user.value;

    var originListSet = originalList.map((e) => e.remotePath).toSet();
    Set<String> needQueryPaths = {};

    if (originListSet.isNotEmpty) {
      for (var element in newList) {
        if (!originListSet.contains(element.remotePath)) {
          needQueryPaths.add(element.remotePath.substringBeforeLast("/")!);
        }
      }
    } else {
      needQueryPaths =
          newList.map((e) => e.remotePath.substringBeforeLast("/")!).toSet();
    }

    for (var path in needQueryPaths) {
      var user = _userController.user.value;
      if (currentUser != user) {
        // 切换用户、终止查询
        return;
      }

      var filePassword = await FilePasswordHelper()
          .findPasswordByPath(user.serverUrl, user.username, path);
      String? password;
      if (filePassword != null) {
        password = filePassword;
      }
      var body = {
        "path": path,
        "password": password ?? "",
        "page": 1,
        "per_page": 0,
        "refresh": false
      };
      await DioUtils.instance.requestNetwork<FileListRespEntity>(
          Method.post, "fs/list", cancelToken: _cancelToken, params: body,
          onSuccess: (result) {
        var user = _userController.user.value;
        if (currentUser != user) {
          // 切换用户、终止操作
          return;
        }
        updateThumbs(path, result?.content);
      }, onError: (code, mess) {});
    }
  }

  void updateThumbs(String parent, List<FileListRespContent>? files) {
    if (files == null) {
      return;
    }
    var filesMap = <String, FileListRespContent>{};
    for (var file in files) {
      filesMap[file.name] = file;
    }

    var list = _list.value;
    var needUpdateRecords = <Favorite>[];
    for (var i = 0; i < list.length; i++) {
      var value = list[i];
      if (value.remotePath.substringBeforeLast("/") == parent) {
        FileListRespContent? newFile = filesMap[value.name];
        if (newFile != null &&
            newFile.thumb.isNotEmpty &&
            newFile.thumb != value.thumb) {
          var newRecord = Favorite(
              id: value.id,
              serverUrl: value.serverUrl,
              userId: value.userId,
              remotePath: value.remotePath,
              name: value.name,
              path: value.path,
              size: value.size,
              sign: value.sign,
              thumb: newFile.thumb,
              modified: value.modified,
              provider: value.provider,
              createTime: value.createTime,
              isDir: value.isDir);
          needUpdateRecords.add(newRecord);
        }
      }
    }
    _databaseController.favoriteDao.updateRecords(needUpdateRecords);
  }
}
