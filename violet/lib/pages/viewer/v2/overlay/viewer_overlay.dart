// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/key.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/locale/locale.dart' as locale;
import 'package:violet/model/article_info.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/article_info/article_info_page.dart';
import 'package:violet/pages/viewer/others/preload_page_view.dart';
import 'package:violet/pages/viewer/tab_panel.dart';
import 'package:violet/pages/viewer/v2/viewer_controller.dart';
import 'package:violet/pages/viewer/view_record_panel.dart';
import 'package:violet/pages/viewer/viewer_page_provider.dart';
import 'package:violet/pages/viewer/viewer_thumbnails.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/variables.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';
import 'package:violet/widgets/toast.dart';

import 'page_label.dart';
import 'viewer_setting_panel.dart';

class ViewerOverlay extends StatefulWidget {
  final String getxId;

  const ViewerOverlay({
    Key? key,
    required this.getxId,
  }) : super(key: key);

  @override
  State<ViewerOverlay> createState() => _ViewerOverlayState();
}

class _ViewerOverlayState extends State<ViewerOverlay> {
  late final ViewerController c;
  late final FToast fToast;

  /// these are used for thumbnail slider
  final ScrollController _thumbController = ScrollController();
  late List<double> _thumbImageWidth;
  late List<double> _thumbImageStartPos;

  @override
  void initState() {
    super.initState();

    fToast = FToast();
    fToast.init(context);

    c = Get.find(tag: widget.getxId);

    c.page.listen((p0) {
      if (c.provider.useFileSystem && c.overlay.value && c.thumb.value) {
        _thumbAnimateTo(c.page.value);
      }
    });

    c.overlay.listen((p0) {
      if (c.provider.useFileSystem && c.thumb.value) {
        _thumbAnimateTo(c.page.value);
      }
    });

    if (c.provider.useFileSystem) _preprocessImageInfoForFileImage();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageLabel(getxId: widget.getxId),
        Obx(
          () => Visibility(
            visible: c.overlay.value,
            child: Stack(
              children: [
                if (Platform.isIOS) _exitButton(),
                if (c.showSlider.value || !c.appBarToBottom.value)
                  _bottomAppBar(),
                _appBar(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  _exitButton() {
    final statusBarHeight =
        Settings.disableFullScreen ? MediaQuery.of(context).padding.top : 0;
    final height = MediaQuery.of(context).size.height;
    final thumbHeight = [140, 120, 96][c.thumbSize.value];

    return Obx(
      () => AnimatedOpacity(
        opacity: c.opacity.value,
        duration: const Duration(milliseconds: 300),
        child: Container(
          alignment: Alignment.center,
          width: double.infinity,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: EdgeInsets.only(
              top: height -
                  Variables.bottomBarHeight -
                  (48 + 48 + 48 + 32 - 24) -
                  (c.search.value ? 48 : 0) -
                  (c.thumb.value ? thumbHeight : 0) -
                  (c.showSlider.value ? 48.0 : 0) -
                  statusBarHeight,
              bottom: (48 + 48.0 + 32 - 24) +
                  (c.search.value ? 48 : 0) +
                  (c.thumb.value ? thumbHeight : 0) +
                  (c.showSlider.value ? 48.0 : 0),
              left: 48.0,
              right: 48.0,
            ),
            child: CupertinoButton(
              minSize: 48.0,
              color: Colors.black.withOpacity(0.8),
              pressedOpacity: 0.4,
              disabledColor: CupertinoColors.quaternarySystemFill,
              borderRadius: const BorderRadius.all(Radius.circular(8.0)),
              onPressed: () async {
                await c.close();
                Navigator.pop(context, c.page.value);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.arrow_back, size: 20.0),
                  Container(width: 10),
                  const Text('Exit'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _appBar() {
    final statusBarHeight =
        Settings.disableFullScreen ? MediaQuery.of(context).padding.top : 0;
    final height = MediaQuery.of(context).size.height;
    return Obx(
      () => AnimatedOpacity(
        opacity: c.opacity.value,
        duration: const Duration(milliseconds: 300),
        child: Stack(
          children: [
            !Settings.disableFullScreen
                ? Padding(
                    padding: EdgeInsets.only(top: statusBarHeight.toDouble()),
                    child: Container(
                      height: Variables.statusBarHeight,
                      color: Colors.black,
                    ),
                  )
                : Container(),
            Container(
              padding: !c.appBarToBottom.value
                  ? EdgeInsets.only(
                      top: !Settings.disableFullScreen
                          ? Variables.statusBarHeight
                          : 0.0)
                  : EdgeInsets.only(
                      top: height -
                          Variables.bottomBarHeight -
                          (48) -
                          (Platform.isIOS ? 48 - 24 : 0) -
                          statusBarHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: c.appBarToBottom.value
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  Material(
                    color: Colors.black.withOpacity(0.8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _appBarBack(),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _appBarBookmark(),
                                _appBarInfo(),
                                _appBarSearch(),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _appBarTab(),
                            _appBarHistory(),
                            _appBarTimer(),
                            _appBarGallery(),
                            _appBarSettings(),
                          ],
                        ),
                      ],
                    ),
                  ),
                  !Settings.disableFullScreen && c.appBarToBottom.value
                      ? Container(
                          height: Variables.bottomBarHeight +
                              (Platform.isIOS ? 48 - 24 : 0),
                          color: Platform.isIOS
                              ? Colors.black.withOpacity(0.8)
                              : Colors.black,
                        )
                      : Container(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _appBarBack() {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      color: Colors.white,
      onPressed: () async {
        await c.close();
        Navigator.pop(context, c.page.value);
      },
    );
  }

  _appBarBookmark() {
    return IconButton(
      icon: Icon(c.bookmark.value ? MdiIcons.heart : MdiIcons.heartOutline),
      color: Colors.white,
      onPressed: () async {
        c.bookmark.value =
            await (await Bookmark.getInstance()).isBookmark(c.articleId.value);

        if (c.bookmark.value) {
          if (!await showYesNoDialog(context, '북마크를 삭제할까요?', '북마크')) return;
        }

        fToast.showToast(
          child: ToastWrapper(
            icon: c.bookmark.value ? Icons.delete_forever : Icons.check,
            color: c.bookmark.value
                ? Colors.redAccent.withOpacity(0.8)
                : Colors.greenAccent.withOpacity(0.8),
            ignoreDrawer: true,
            reverse: true,
            msg:
                '${c.articleId}${locale.Translations.of(context).trans(!c.bookmark.value ? 'addtobookmark' : 'removetobookmark')}',
          ),
          gravity: ToastGravity.TOP,
          toastDuration: const Duration(seconds: 4),
        );

        c.bookmark.value = !c.bookmark.value;
        if (c.bookmark.value) {
          await (await Bookmark.getInstance()).bookmark(c.articleId.value);
        } else {
          await (await Bookmark.getInstance()).unbookmark(c.articleId.value);
        }
      },
    );
  }

  _appBarInfo() {
    return IconButton(
      icon: const Icon(MdiIcons.information),
      color: Colors.white,
      onPressed: () async {
        final height = MediaQuery.of(context).size.height;

        final search =
            await HentaiManager.idSearch(c.articleId.value.toString());
        if (search.item1.length != 1) return;

        final qr = search.item1[0];

        if (!ProviderManager.isExists(qr.id())) {
          await HentaiManager.getImageProvider(qr).then((value) async {
            ProviderManager.insert(qr.id(), value);
          });
        }

        var prov = await ProviderManager.get(c.articleId.value);
        var thumbnail = await prov.getThumbnailUrl();
        var headers = await prov.getHeader(0);
        ProviderManager.insert(qr.id(), prov);

        var isBookmarked =
            await (await Bookmark.getInstance()).isBookmark(qr.id());

        c.isStaring = false;
        c.stopTimer();

        Provider<ArticleInfo>? cache;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) {
            return DraggableScrollableSheet(
              initialChildSize: 400 / height,
              minChildSize: 400 / height,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, controller) {
                cache ??= Provider<ArticleInfo>.value(
                  value: ArticleInfo.fromArticleInfo(
                    queryResult: qr,
                    thumbnail: thumbnail,
                    headers: headers,
                    heroKey: 'zxcvzxcvzxcv',
                    isBookmarked: isBookmarked,
                    controller: controller,
                    lockRead: true,
                  ),
                  child: const ArticleInfoPage(
                    key: ObjectKey('asdfasdf'),
                  ),
                );
                return cache!;
              },
            );
          },
        ).then((value) {
          c.isStaring = true;
          c.startTimer();
        });
      },
    );
  }

  _appBarSearch() {
    return IconButton(
      icon: const Icon(Icons.search_rounded),
      color: Colors.white,
      onPressed: () async {
        setState(() {
          c.search.value = !c.search.value;
        });
      },
    );
  }

  _appBarTab() {
    final height = MediaQuery.of(context).size.height;
    return IconButton(
      icon: const Icon(MdiIcons.tab),
      color: Colors.white,
      onPressed: () async {
        c.stopTimer();
        c.isStaring = false;
        TabPanel? cache;
        await showModalBottomSheet(
            context: context,
            isScrollControlled: false,
            builder: (context) {
              cache ??= TabPanel(
                articleId: c.articleId.value,
                usableTabList: c.provider.usableTabList,
                height: height,
              );
              return cache!;
            }).then((value) async {
          if (value == null) return;

          c.replace(value as QueryResult);

          // await _savePageRead(_pageInfo.useFileSystem);

          // await (await User.getInstance()).insertUserLog(value.id(), 0);

          // _inactivateSeconds = 0;
          // _startsTime = DateTime.now();

          // if (!Settings.isHorizontal) {
          //   _itemScrollController.scrollTo(
          //     index: 0,
          //     duration: const Duration(microseconds: 1),
          //     alignment: 0.12,
          //   );
          // } else {
          //   _pageController.jumpToPage(0);
          // }
          // _currentPage = 0;
          // _prevPage = 0;
          // _vPrevPage.value = 0;

          // var prov = await ProviderManager.get(value.id());
          // var headers = await prov.getHeader(0);

          // _pageInfo = ViewerPageProvider(
          //   uris: List<String>.filled(prov.length(), ''),
          //   useProvider: true,
          //   provider: prov,
          //   headers: headers,
          //   id: value.id(),
          //   title: value.title(),
          //   usableTabList: _pageInfo.usableTabList,
          // );

          // _report = ViewerReport(
          //   id: _pageInfo.id,
          //   pages: _pageInfo.uris.length,
          //   startsTime: DateTime.now(),
          // );
          // _decisecondPerPages = List.filled(_pageInfo.uris.length, 0);
          // _isImageLoaded = List.filled(_pageInfo.uris.length, false);

          // _headerCache =
          //     List<Map<String, String>?>.filled(_pageInfo.uris.length, null);
          // _urlCache = List<String?>.filled(_pageInfo.uris.length, null);
          // _height = List<double>.filled(_pageInfo.uris.length, 0);
          // _keys = List<GlobalKey>.generate(
          //     _pageInfo.uris.length, (index) => GlobalKey());
          // _estimatedImageHeight = List<double>.filled(_pageInfo.uris.length, 0);
          // _loadingEstimaed = List<bool>.filled(_pageInfo.uris.length, false);
          // _latestIndex = 0;
          // _latestAlign = 0;
          // _onScroll = false;

          // setState(() {});

          // Future.delayed(const Duration(milliseconds: 300))
          //     .then((value) => _checkLatestRead(true));
        });
        c.startTimer();
        c.isStaring = true;
      },
    );
  }

  _appBarHistory() {
    return IconButton(
      icon: const Icon(MdiIcons.history),
      color: Colors.white,
      onPressed: () async {
        c.stopTimer();
        c.isStaring = false;
        ViewRecordPanel? cache;
        final value = await showModalBottomSheet(
          context: context,
          isScrollControlled: false,
          builder: (context) {
            cache ??= ViewRecordPanel(articleId: c.articleId.value);
            return cache!;
          },
        );
        if (value != null) {
          c.jump(value - 1);
        }
        c.startTimer();
        c.isStaring = true;
      },
    );
  }

  _appBarTimer() {
    return IconButton(
      icon: Icon(Settings.enableTimer ? MdiIcons.timer : MdiIcons.timerOff),
      color: Colors.white,
      onPressed: () async {
        setState(() {
          Settings.setEnableTimer(!Settings.enableTimer);
        });
        c.startTimer();
      },
    );
  }

  _appBarGallery() {
    return IconButton(
      icon: const Icon(MdiIcons.folderImage),
      color: Colors.white,
      onPressed: () async {
        c.stopTimer();
        c.isStaring = false;
        FractionallySizedBox? cache;
        final value = await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) {
            cache ??= FractionallySizedBox(
              heightFactor: 0.8,
              child: Provider<ViewerPageProvider>.value(
                value: c.provider,
                child: ViewerThumbnail(
                  viewedPage: c.page.value,
                ),
              ),
            );
            return cache!;
          },
        );
        if (value != null) {
          c.jump(value);
        }
        c.startTimer();
        c.isStaring = true;
      },
    );
  }

  _appBarSettings() {
    return IconButton(
      icon: const Icon(Icons.settings),
      color: Colors.white,
      onPressed: () async {
        c.stopTimer();
        c.isStaring = false;
        ViewerSettingPanel? cache;
        await showModalBottomSheet(
            context: context,
            isScrollControlled: false,
            builder: (context) {
              cache ??= ViewerSettingPanel(
                getxId: widget.getxId,
                viewerStyleChangeEvent: () {
                  print(c.page.value);
                  if (Settings.isHorizontal) {
                    c.horizontalPageController =
                        PreloadPageController(initialPage: c.page.value);
                  } else {
                    c.sliderOnChange = true;
                    Future.delayed(const Duration(milliseconds: 180))
                        .then((value) {
                      c.verticalItemScrollController.scrollTo(
                        index: c.page.value,
                        duration: const Duration(microseconds: 1),
                        alignment: 0.12,
                      );
                      c.sliderOnChange = false;
                    });
                  }
                },
                thumbSizeChangeEvent: () {
                  _preprocessImageInfoForFileImage();
                },
              );
              return cache!;
            });
        c.startTimer();
        c.isStaring = true;
      },
    );
  }

  _bottomAppBar() {
    final statusBarHeight =
        Settings.disableFullScreen ? MediaQuery.of(context).padding.top : 0;
    final height = MediaQuery.of(context).size.height;

    final sliderWidget = SliderTheme(
      data: const SliderThemeData(
        activeTrackColor: Colors.blue,
        inactiveTrackColor: Color(0xffd0d2d3),
        trackHeight: 3,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0),
        // thumbShape: SliderThumbShape(),
      ),
      child: Slider(
        value: c.page.value >= 0
            ? c.page.value < c.maxPage
                ? c.page.value.toDouble() + 1
                : c.maxPage.toDouble()
            : 1,
        max: c.maxPage.toDouble(),
        min: 1,
        label: '${c.page.value + 1}',
        divisions: c.maxPage,
        inactiveColor: Settings.majorColor.withOpacity(0.7),
        activeColor: Settings.majorColor,
        onChangeStart: (value) {
          c.sliderOnChange = true;
        },
        onChangeEnd: (value) {
          Future.delayed(const Duration(milliseconds: 300)).then((value) {
            c.sliderOnChange = false;
          });
          if (c.provider.useFileSystem) {
            c.jump(value.toInt() - 1);
          }
        },
        onChanged: (value) {
          c.page.value = value.toInt() - 1;

          if (!c.provider.useFileSystem) {
            if (!Settings.isHorizontal) {
              c.verticalItemScrollController.jumpTo(
                index: value.toInt() - 1,
                alignment: 0.12,
              );
            } else {
              c.horizontalPageController.jumpToPage(value.toInt() - 1);
            }
          }
        },
      ),
    );

    final leftPageIndicator = SizedBox(
      width: 30.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Obx(() => Text('${c.page.value + 1}',
              style: const TextStyle(color: Colors.white70, fontSize: 16.0))),
        ],
      ),
    );

    final rightPageIndicator = Text(
      '${c.maxPage}',
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 15.0,
      ),
    );

    final thumbBarIndicator = IconButton(
      color: Colors.white,
      icon: const Icon(Icons.keyboard_arrow_up),
      onPressed: () async {
        c.thumb.value = !c.thumb.value;
        await Settings.setEnableThumbSlider(c.thumb.value);
        setState(() {});
      },
    );

    final thumbHeight = [140.0, 120.0, 96.0][c.thumbSize.value];

    return Obx(
      () => AnimatedOpacity(
        opacity: c.opacity.value,
        duration: const Duration(milliseconds: 300),
        child: Stack(
          children: [
            !Settings.disableFullScreen && !c.appBarToBottom.value
                ? Padding(
                    padding: EdgeInsets.only(top: statusBarHeight.toDouble()),
                    child: Container(
                      height: Variables.statusBarHeight,
                      color: Colors.black,
                    ),
                  )
                : Container(),
            AnimatedPadding(
              duration: const Duration(milliseconds: 300),
              padding: EdgeInsets.only(
                  top: MediaQuery.of(context).viewInsets.bottom > 1
                      ? height - MediaQuery.of(context).viewInsets.bottom - 48.0
                      : (height -
                          Variables.bottomBarHeight -
                          (48) -
                          (Platform.isIOS ? 48 - 24 : 0) -
                          (c.thumb.value ? thumbHeight : 0) -
                          (c.search.value ? 48 : 0) -
                          statusBarHeight -
                          (c.appBarToBottom.value ? 48 : 0))),
              curve: Curves.easeInOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                alignment: Alignment.bottomCenter,
                height: MediaQuery.of(context).viewInsets.bottom > 1
                    ? MediaQuery.of(context).viewInsets.bottom + 48
                    : (48 +
                        (c.thumb.value ? thumbHeight : 0) +
                        (c.search.value ? 48 : 0) +
                        (!c.appBarToBottom.value ? 48 : 0)),
                curve: Curves.easeInOut,
                child: Material(
                  color: Colors.black.withOpacity(0.8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      AnimatedOpacity(
                        opacity: c.search.value ? 1.0 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          height: c.search.value ? 48.0 : 0,
                          // child: _searchArea(),
                        ),
                      ),
                      if (c.provider.useFileSystem)
                        AnimatedOpacity(
                          opacity: c.thumb.value ? 1.0 : 0,
                          duration: const Duration(milliseconds: 300),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            height: c.thumb.value ? thumbHeight : 0,
                            child: _thumbArea(),
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (c.provider.useFileSystem) thumbBarIndicator,
                          leftPageIndicator,
                          Expanded(
                            child: sliderWidget,
                          ),
                          rightPageIndicator,
                          Container(
                            width: 16.0,
                          )
                        ],
                      ),
                      if (!Platform.isIOS &&
                          !Settings.disableFullScreen &&
                          !c.appBarToBottom.value)
                        Container(
                          height: Variables.bottomBarHeight,
                          color: Colors.black,
                        )
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _preprocessImageInfoForFileImage() {
    final thumbHeight = [140, 120, 96][c.thumbSize.value];
    c.thumb.value = Settings.enableThumbSlider;

    var imageSizes = c.provider.uris.map((e) {
      final image = File(e);
      if (!image.existsSync()) return null;
      return ImageSizeGetter.getSize(FileInput(image));
    }).toList();

    _thumbImageStartPos = List.filled(imageSizes.length + 1, 0);
    _thumbImageWidth = List.filled(imageSizes.length, 0);

    c.realImgHeight = List.filled(imageSizes.length, 0);

    for (var i = 0; i < imageSizes.length; i++) {
      final sz = imageSizes[i];

      if (sz != null) {
        _thumbImageStartPos[i + 1] =
            (thumbHeight - 14.0) * sz.width / sz.height;
      } else {
        _thumbImageStartPos[i + 1] = (thumbHeight - 14.0) / 36 * 25;
      }

      _thumbImageWidth[i] = _thumbImageStartPos[i + 1];
      _thumbImageStartPos[i + 1] += _thumbImageStartPos[i];

      c.realImgHeight[i] = sz!.height.toDouble();
    }
  }

  _thumbAnimateTo(page) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (c.overlay.value && c.thumb.value) {
        final width = MediaQuery.of(context).size.width;
        final jumpOffset =
            _thumbImageStartPos[page] - width / 2 + _thumbImageWidth[page] / 2;
        _thumbController.animateTo(
          jumpOffset > 0 ? jumpOffset : 0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  _thumbArea() {
    final thumbHeight = [140, 120, 96][c.thumbSize.value];
    final width = MediaQuery.of(context).size.width;

    return ListView.builder(
      controller: _thumbController,
      scrollDirection: Axis.horizontal,
      itemCount: c.maxPage,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.only(top: 4.0, left: 2.0, right: 2.0),
          width: _thumbImageWidth[index],
          child: GestureDetector(
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4.0),
                    child: Image.file(
                      File(c.provider.uris[index]),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      isAntiAlias: true,
                      cacheHeight: (thumbHeight * 2.0).toInt(),
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                Container(height: 2.0),
                Text((index + 1).toString(),
                    style:
                        const TextStyle(color: Colors.white, fontSize: 12.0)),
              ],
            ),
            onTap: () {
              c.jump(index);

              final jumpOffset = _thumbImageStartPos[index] -
                  width / 2 +
                  _thumbImageWidth[index] / 2;
              _thumbController.animateTo(
                jumpOffset > 0 ? jumpOffset : 0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );

              c.page.value = index;
            },
          ),
        );
      },
    );
  }
}
