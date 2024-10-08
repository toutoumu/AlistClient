import 'dart:io';

import 'package:alist/entity/file_info_resp_entity.dart';
import 'package:alist/entity/player_resolve_info_entity.dart';
import 'package:alist/generated/images.dart';
import 'package:alist/l10n/intl_keys.dart';
import 'package:alist/net/dio_utils.dart';
import 'package:alist/screen/video_player_screen.dart';
import 'package:alist/util/alist_plugin.dart';
import 'package:alist/util/constant.dart';
import 'package:alist/util/file_utils.dart';
import 'package:alist/util/named_router.dart';
import 'package:alist/util/proxy.dart';
import 'package:alist/util/string_utils.dart';
import 'package:alist/widget/player_selector_dialog.dart';
import 'package:flustars/flustars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class VideoPlayerUtil {
  static void go(List<VideoItem> videos, int index, String? password) async {
    var videoPlayerRouter =
        SpUtil.getString(AlistConstant.videoPlayerRouter) ?? "";

    if (videoPlayerRouter == "") {
      // 默认使用内置的视频播放器
      _playUrlWithInternalPlayer(videos, index);
    } else {
      // 交给设置的外部的视频播放器处理
      var item = videos[index];
      var playResult = await _playUrlWithExternalPlayer(videoPlayerRouter,
          item.provider, item.localPath, item.remotePath, item.sign, password);
      if (!playResult) {
        // 遇到 Activity Not Found 错误，说明原外部播放器软件已被卸载
        SpUtil.remove(AlistConstant.videoPlayerRouter);
        SpUtil.remove(AlistConstant.videoPlayerName);
        _playUrlWithInternalPlayer(videos, index);
      }
    }
  }

  static void _playUrlWithInternalPlayer(List<VideoItem> videos, int index,
      {String? playerType}) async {
    // 内置播放器全部采用 mpv
    Get.toNamed(
      NamedRouter.videoPlayerMac,
      arguments: {
        "videos": videos,
        "index": index,
      },
    );
    /*if (Platform.isAndroid) {
      var videosParams = <Map<String, String?>>[];
      Map<String, String> headers = {};

      for (var element in videos) {
        var videoParam = <String, String?>{};
        videosParams.add(videoParam);
        videoParam["name"] = element.name;
        videoParam["localPath"] = element.localPath;
        videoParam["remotePath"] = element.remotePath;
        videoParam["sign"] = element.sign;
        videoParam["provider"] = element.provider;
        videoParam["thumb"] = element.thumb;
        videoParam["url"] = await FileUtils.makeFileLink(element.remotePath, element.sign);
        videoParam["modifiedMilliseconds"] = element.modifiedMilliseconds?.toString();
        videoParam["size"] = element.size?.toString();
        if (videoParam["url"] == null || videoParam["url"] == "") {
          return;
        }

        if (element.provider == "BaiduNetdisk") {
          headers["User-Agent"] = "pan.baidu.com";
        }
      }
      playerType ??= SpUtil.getString(AlistConstant.playerType);
      AlistPlugin.playVideoWithInternalPlayer(
          videosParams, index, headers, playerType);
    } else {
      Get.toNamed(
        NamedRouter.videoPlayer,
        arguments: {
          "videos": videos,
          "index": index,
        },
      );
    }*/
  }

  static Future<bool> _playUrlWithExternalPlayer(
      String videoPlayerRouter,
      String? provider,
      String? localPath,
      String remotePath,
      String? sign,
      String? password) async {
    if (localPath != null && localPath != "") {
      var packageName = videoPlayerRouter.substringBeforeLast("/")!;
      if (Platform.isAndroid) {
        // 安卓传递本地文件路径使用FileProvider提供给外部播放器播发
        var activity = videoPlayerRouter.substringAfterLast("/")!;
        return AlistPlugin.playVideoWithExternalPlayer(
            packageName, activity, localPath);
      } else {
        // ios使用本地服务提供url给外部播放器
        ProxyServer proxyServer = Get.find();
        await proxyServer.start();
        var videoUrl = proxyServer.makeFileUri(File(localPath)).toString();
        debugPrint("videoUrl=$videoUrl");
        var uri = Uri.parse("$packageName$videoUrl");
        return launchUrl(uri);
      }
    } else {
      var videoUrl = await FileUtils.makeFileLink(remotePath, sign);
      if (videoUrl == null) {
        return true;
      }

      LogUtil.d("provider=$provider");
      if (provider == "BaiduNetdisk") {
        ProxyServer proxyServer = Get.find();
        await proxyServer.start();
        var uri = proxyServer.makeProxyUrl(videoUrl,
            headers: {HttpHeaders.userAgentHeader: "pan.baidu.com"});
        videoUrl = uri.toString();
      }

      var packageName = videoPlayerRouter.substringBeforeLast("/")!;
      if (!Platform.isAndroid) {
        if (packageName.startsWith("nplayer-")) {
          // nplayer 不支持302跳转播放
          var rawUrl = await requestRawUrl(remotePath, password);
          if (rawUrl != null) {
            var uri = Uri.parse("$packageName$rawUrl");
            return launchUrl(uri);
          } else {
            SmartDialog.showToast(Intl.tips_request_raw_url_failed.tr);
            return false;
          }
        }
        var uri = Uri.parse("$packageName$videoUrl");
        return launchUrl(uri);
      } else {
        var activity = videoPlayerRouter.substringAfterLast("/")!;
        return AlistPlugin.playVideoWithExternalPlayer(
            packageName, activity, videoUrl);
      }
    }
  }

  static Future<List<ExternalPlayerEntity>> loadPlayerResoleInfoList() async {
    List<ExternalPlayerEntity> playerList = [];

    if (!Platform.isAndroid) {
      var aliPlayer = ExternalPlayerEntity();
      aliPlayer.icon = Images.logo;
      aliPlayer.label = "AList Client";
      aliPlayer.activity = "";
      aliPlayer.packageName = "";

      var nPlayer = ExternalPlayerEntity();
      nPlayer.icon = Images.icNplayer;
      nPlayer.label = "nPlayer";
      nPlayer.activity = "";
      nPlayer.packageName = "nplayer-";

      var infuse = ExternalPlayerEntity();
      infuse.icon = Images.icInfuse;
      infuse.label = "Infuse";
      infuse.activity = "";
      infuse.packageName = "infuse://x-callback-url/play?url=";

      var vlc = ExternalPlayerEntity();
      vlc.icon = Images.icVlc;
      vlc.label = "VLC";
      vlc.activity = "";
      vlc.packageName = "vlc://";

      playerList.add(aliPlayer);
      playerList.add(nPlayer);
      playerList.add(infuse);
      playerList.add(vlc);
    } else {
      playerList = await AlistPlugin.loadPlayerResoleInfoList() ?? [];

      var exoplayer = ExternalPlayerEntity();
      exoplayer.icon = Images.logo;
      exoplayer.label = "ExoPlayer\n(AList Client)";
      exoplayer.activity = "";
      exoplayer.packageName = "exoplayer";

      var ijkPlayer = ExternalPlayerEntity();
      ijkPlayer.icon = Images.logo;
      ijkPlayer.label = "IJKPlayer\n(AList Client)";
      ijkPlayer.activity = "";
      ijkPlayer.packageName = "ijkplayer";
      playerList.insert(0, ijkPlayer);
      playerList.insert(0, exoplayer);
    }
    return playerList;
  }

  static void selectThePlayerToPlay(BuildContext context,
      List<VideoItem> videos, int index, String? password) async {
    List<ExternalPlayerEntity> externalPlayerList =
        await loadPlayerResoleInfoList();

    if (!context.mounted) {
      return;
    }

    showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return PlayerSelectorDialog(
            players: externalPlayerList,
            onPlayerClick: (info) {
              var isInternal = info.label.contains("AList Client");
              Navigator.of(context).pop();

              if (isInternal) {
                String? playerType;
                if (Platform.isAndroid) {
                  playerType = info.packageName;
                }
                _playUrlWithInternalPlayer(videos, index,
                    playerType: playerType);
              } else {
                var videoPlayerRouter = "${info.packageName}/${info.activity}";
                var item = videos[index];
                _playUrlWithExternalPlayer(videoPlayerRouter, item.provider,
                    item.localPath, item.remotePath, item.sign, password);
              }
            },
          );
        });
  }

  static Future<String?> requestRawUrl(String path, String? password) async {
    var params = {"path": path, "password": password ?? ""};
    String? rawUrl;
    SmartDialog.showLoading();
    await DioUtils.instance.requestNetwork<FileInfoRespEntity>(
        Method.post, "fs/get",
        params: params, onSuccess: (detail) {
      rawUrl = detail?.rawUrl;
    }, onError: (code, msg) {});
    SmartDialog.dismiss(status: SmartStatus.loading);
    return rawUrl;
  }
}
