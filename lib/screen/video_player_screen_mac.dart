import 'dart:io';

import 'package:alist/database/alist_database_controller.dart';
import 'package:alist/database/table/file_viewing_record.dart';
import 'package:alist/database/table/video_viewing_record.dart';
import 'package:alist/util/file_utils.dart';
import 'package:alist/util/log_utils.dart';
import 'package:alist/util/proxy.dart';
import 'package:alist/util/string_utils.dart';
import 'package:alist/util/user_controller.dart';
import 'package:dio/dio.dart';
import 'package:floor/floor.dart';
import 'package:flustars/flustars.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Make sure to add following packages to pubspec.yaml:
// * media_kit
// * media_kit_video
// * media_kit_libs_video
import 'package:media_kit/media_kit.dart'; // Provides [Player], [Media], [Playlist] etc.
import 'package:media_kit_video/media_kit_video.dart';

import 'video_player_screen.dart'; // Provides [VideoController] & [Video] etc.

class VideoPlayerScreenMac extends StatefulWidget {
  const VideoPlayerScreenMac({super.key});

  @override
  State createState() => _VideoPlayerScreenMacState();
}

class _VideoPlayerScreenMacState extends State<VideoPlayerScreenMac> {
  final ProxyServer _proxyServer = Get.find();
  final AlistDatabaseController _database = Get.find();
  final UserController _userController = Get.find();
  final CancelToken _cancelToken = CancelToken();

  int _index = Get.arguments["index"] ?? 0;
  final List<VideoItem> _videos = Get.arguments["videos"];

  int _currentPos = 0;
  int _duration = 0;
  final _videoTitle = "".obs;
  VideoViewingRecord? _videoViewingRecord;

  late final _player = Player();
  late final _controller = VideoController(_player);

  @override
  void initState() {
    super.initState();
    // 初始视频状态化监听
    _initListener();

    // 开始播放
    _startPlay();
  }

  // 初始视频状态化监听
  void _initListener() {
    // 视频旋转角度监听
    /*_player.stream.videoParams.listen((event) {
      if (event.rotate != null) {
        if (event.rotate == 0) {
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
              overlays: [SystemUiOverlay.top]);
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
              overlays: []);
        }
      }
    });*/
    // 当前播放进度监听
    _player.stream.position.listen((event) {
      // 如果视频长度未获取到那么不处理
      if (_duration <= 0) {
        return;
      }
      var currentPos = event.inMilliseconds;
      // 如果最后一秒了，删除记录
      if (_currentPos >= _duration - 1000) {
        _deleteViewingRecord();
      } else if (currentPos < 10 * 1000 || (currentPos / 1000) % 10 != 0) {
        _currentPos = currentPos;
      } else {
        LogUtil.e("_currentPos: $_currentPos");
        _saveViewingRecord(currentPos, _duration);
      }
    });
    _player.stream.track.listen((event) async {
      LogUtil.e("object tracks);");
    });
    // 视频长度监听
    _player.stream.duration.listen((event) {
      _duration = event.inMilliseconds;
      LogUtil.e("_duration: $_duration");
    });
    // 当前播放的视频
    _player.stream.playlist.listen((event) {
      _index = event.index;
      _videoTitle.value = _videos[_index].name.substringBeforeLast(".") ?? "";
      _fileViewingRecord(_videos[_index]);
      _findAndCacheViewingRecord(_videos[_index]);
    });
  }

  void _startPlay() async {
    if (_videos.isEmpty) {
      return;
    }
    // 组织播放列表
    var playList = <Media>[];
    _videos.forEach((element) async {
      var url = await FileUtils.makeFileLink(element.remotePath, element.sign);
      if (url != null) {
        if (element.provider == "BaiduNetdisk") {
          playList.add(Media(url,
              httpHeaders: {HttpHeaders.userAgentHeader: "pan.baidu.com"}));
        } else {
          playList.add(Media(url));
        }
      }
    });
    // 播放
    final playable = Playlist(playList, index: _index);
    // _player.setSubtitleTrack(SubtitleTrack.auto());
    await _player.open(playable);
  }

  @override
  Widget build(BuildContext context) {
    // 移动端播放器配置
    if (Platform.isAndroid || Platform.isIOS) {
      return _buildMobilePlayer(context);
    }
    // 桌面端播放器配置
    return _buildComputerPlayer(context);
  }

  /// 桌面端播放器配置
  Widget _buildComputerPlayer(BuildContext context) {
    return MaterialDesktopVideoControlsTheme(
      key: const ObjectKey("mac"),
      normal: MaterialDesktopVideoControlsThemeData(
        visibleOnMount: true,
        controlsHoverDuration: const Duration(seconds: 5),
        topButtonBar: [
          MaterialCustomButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            iconSize: IconTheme.of(context).size ?? 14,
            iconColor: Colors.white,
            onPressed: () => Get.back(),
          ),
          Expanded(
            child: Obx(() {
              return Padding(
                padding: const EdgeInsets.only(right: 18.0),
                child: Text(
                  _videoTitle.value,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          )
        ],
      ),
      fullscreen: MaterialDesktopVideoControlsThemeData(
        visibleOnMount: true,
        controlsHoverDuration: const Duration(seconds: 5),
        topButtonBar: [
          MaterialFullscreenButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            iconSize: IconTheme.of(context).size ?? 14,
            iconColor: Colors.white,
          ),
          Expanded(
            child: Obx(() {
              return Padding(
                padding: const EdgeInsets.only(right: 18.0),
                child: Text(
                  _videoTitle.value,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ),
        ],
      ),
      child: PopScope(
        canPop: !isFullscreen(context),
        onPopInvoked: (didPop) {
          if (isFullscreen(context)) {
            exitFullscreen(context);
          }
        },
        child: Scaffold(
          body: Video(
            key: const ObjectKey("video"),
            controller: _controller,
            // controls: CupertinoVideoControls,
            controls: MaterialDesktopVideoControls,
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
          ),
        ),
      ),
    );
  }

  /// 移动端播放器
  Widget _buildMobilePlayer(BuildContext context) {
    return MaterialVideoControlsTheme(
      key: const ObjectKey("mobile"),
      normal: MaterialVideoControlsThemeData(
        seekGesture: true,
        volumeGesture: true,
        brightnessGesture: true,
        seekOnDoubleTap: true,
        speedUpOnLongPress: true,
        verticalGestureSensitivity: 200,
        horizontalGestureSensitivity: 1000,
        controlsHoverDuration: const Duration(seconds: 5),
        bottomButtonBarMargin:
            const EdgeInsets.only(left: 16.0, right: 8.0, bottom: 16),
        seekBarMargin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
        seekBarContainerHeight: 50,
        topButtonBarMargin:
            EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        topButtonBar: [
          MaterialCustomButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            iconSize: IconTheme.of(context).size ?? 14,
            iconColor: Colors.white,
            onPressed: () => Get.back(),
          ),
          Expanded(
            child: Obx(() {
              return Padding(
                padding: const EdgeInsets.only(right: 18.0),
                child: Text(
                  _videoTitle.value,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          )
        ],
        shiftSubtitlesOnControlsVisibilityChange: true,
      ),
      fullscreen: MaterialVideoControlsThemeData(
        seekGesture: true,
        volumeGesture: true,
        brightnessGesture: true,
        seekOnDoubleTap: true,
        speedUpOnLongPress: true,
        verticalGestureSensitivity: 200,
        horizontalGestureSensitivity: 1000,
        controlsHoverDuration: const Duration(seconds: 5),
        bottomButtonBarMargin:
            const EdgeInsets.only(left: 16.0, right: 8.0, bottom: 8),
        seekBarMargin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
        seekBarContainerHeight: 50,
        topButtonBarMargin:
            EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        topButtonBar: [
          MaterialFullscreenButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            iconSize: IconTheme.of(context).size ?? 14,
            iconColor: Colors.white,
          ),
          Expanded(
            child: Obx(() {
              return Padding(
                padding: const EdgeInsets.only(right: 18.0),
                child: Text(
                  _videoTitle.value,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ),
        ],
        shiftSubtitlesOnControlsVisibilityChange: true,
      ),
      child: PopScope(
        canPop: !isFullscreen(context),
        onPopInvoked: (didPop) {
          if (isFullscreen(context)) {
            exitFullscreen(context);
          }
        },
        child: Scaffold(
          body: Video(
            controller: _controller,
            controls: MaterialVideoControls,
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _releasePlayer();
    _cancelToken.cancel();
    if (_duration > 0) {
      _saveViewingRecord(_currentPos, _duration);
    }
    _proxyServer.stop();
    super.dispose();
  }

  void _releasePlayer() {
    _player.dispose();
  }

  // 添加文件打开记录
  @transaction
  Future<void> _fileViewingRecord(VideoItem file) async {
    var user = _userController.user.value;
    AlistDatabaseController databaseController =
        Get.find<AlistDatabaseController>();
    var recordData = databaseController.fileViewingRecordDao;
    await recordData.deleteByPath(
        user.serverUrl, user.username, file.remotePath);
    await recordData.insertRecord(FileViewingRecord(
      serverUrl: user.serverUrl,
      userId: user.username,
      remotePath: file.remotePath,
      name: file.name,
      path: file.remotePath,
      size: file.size ?? 0,
      sign: file.sign,
      thumb: file.thumb,
      modified: file.modifiedMilliseconds ?? 0,
      provider: file.provider ?? "",
      createTime: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  // 查找视频观看记录,并缓存
  Future<void> _findAndCacheViewingRecord(VideoItem file) async {
    final userId = _userController.user().username;
    final baseUrl = _userController.user().baseUrl;
    var record = await _database.videoViewingRecordDao
        .findRecordByPath(baseUrl, userId, file.remotePath);
    if (record != null) {
      Log.d("findAndCacheViewingRecord");
      _videoViewingRecord = record;
      await _controller.waitUntilFirstFrameRendered;
      _player.seek(Duration(milliseconds: record.videoCurrentPosition));
    } else {
      _videoViewingRecord = null;
      Log.d("no findAndCacheViewingRecord");
    }
  }

  // 删除视频观看记录
  Future<void> _deleteViewingRecord() async {
    final userId = _userController.user().username;
    final baseUrl = _userController.user().baseUrl;
    final path = _videos[_index].remotePath;
    var record = await _database.videoViewingRecordDao
        .findRecordByPath(baseUrl, userId, path);
    if (record != null) {
      Log.d("delete record ${record.id}");
      await _database.videoViewingRecordDao.deleteRecord(record);
    }
  }

  // 保存视频观看记录
  Future<void> _saveViewingRecord(int currentPos, int duration) async {
    final userId = _userController.user().username;
    final baseUrl = _userController.user().baseUrl;
    final sign = _videos[_index].sign;
    final path = _videos[_index].remotePath;

    var record = _videoViewingRecord;
    Log.d("record = ${record?.id} ${record?.videoSign} $currentPos $duration");
    if (record == null) {
      var videoViewingRecord = VideoViewingRecord(
          serverUrl: baseUrl,
          userId: userId,
          videoSign: sign ?? "",
          path: path,
          videoCurrentPosition: currentPos,
          videoDuration: duration);
      _database.videoViewingRecordDao
          .insertRecord(videoViewingRecord)
          .then((id) {
        Log.d("insert record id=$id");
        _videoViewingRecord = VideoViewingRecord(
          id: id,
          serverUrl: videoViewingRecord.serverUrl,
          userId: videoViewingRecord.userId,
          videoSign: videoViewingRecord.videoSign,
          path: videoViewingRecord.path,
          videoCurrentPosition: videoViewingRecord.videoCurrentPosition,
          videoDuration: videoViewingRecord.videoDuration,
        );
      });
    } else {
      Log.d("update record");
      _database.videoViewingRecordDao.updateRecord(VideoViewingRecord(
        id: record.id,
        serverUrl: baseUrl,
        userId: userId,
        videoSign: sign ?? "",
        path: path,
        videoCurrentPosition: currentPos,
        videoDuration: duration,
      ));
    }
  }
}
