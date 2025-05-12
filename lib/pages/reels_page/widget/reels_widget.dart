import 'dart:io';

import 'package:blurrycontainer/blurrycontainer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:readmore/readmore.dart';
import 'package:shortie/custom/custom_format_number.dart';
import 'package:shortie/custom/custom_share.dart';
import 'package:shortie/pages/bottom_bar_page/controller/bottom_bar_controller.dart';
import 'package:shortie/routes/app_routes.dart';
import 'package:shortie/ui/loading_ui.dart';
import 'package:shortie/ui/preview_network_image_ui.dart';
import 'package:shortie/ui/preview_profile_bottom_sheet_ui.dart';
import 'package:shortie/custom/custom_icon_button.dart';
import 'package:shortie/ui/comment_bottom_sheet_ui.dart';
import 'package:shortie/main.dart';
import 'package:shortie/pages/reels_page/api/reels_like_dislike_api.dart';
import 'package:shortie/pages/reels_page/api/reels_share_api.dart';
import 'package:shortie/pages/reels_page/controller/reels_controller.dart';
import 'package:shortie/ui/report_bottom_sheet_ui.dart';
import 'package:shortie/ui/send_gift_on_video_bottom_sheet_ui.dart';
import 'package:shortie/ui/video_picker_bottom_sheet_ui.dart';
import 'package:shortie/utils/api.dart';
import 'package:shortie/utils/asset.dart';
import 'package:shortie/utils/branch_io_services.dart';
import 'package:shortie/utils/color.dart';
import 'package:shortie/utils/constant.dart';
import 'package:shortie/utils/database.dart';
import 'package:shortie/utils/enums.dart';
import 'package:shortie/utils/font_style.dart';
import 'package:shortie/utils/utils.dart';
import 'package:vibration/vibration.dart';
import 'package:video_player/video_player.dart';

class PreviewReelsView extends StatefulWidget {
  const PreviewReelsView({super.key, required this.index, required this.currentPageIndex});

  final int index;
  final int currentPageIndex;

  @override
  State<PreviewReelsView> createState() => _PreviewReelsViewState();
}

class _PreviewReelsViewState extends State<PreviewReelsView> with SingleTickerProviderStateMixin {
  final controller = Get.find<ReelsController>();

  ChewieController? chewieController;
  VideoPlayerController? videoPlayerController;

  RxBool isPlaying = true.obs;
  RxBool isShowIcon = false.obs;

  RxBool isBuffering = false.obs;
  RxBool isVideoLoading = true.obs;

  RxBool isShowLikeAnimation = false.obs;
  RxBool isShowLikeIconAnimation = false.obs;

  RxBool isReelsPage = true.obs; // This is Use to Stop Auto Playing..

  RxBool isLike = false.obs;

  RxMap customChanges = {"like": 0, "comment": 0}.obs;

  AnimationController? _controller;
  late Animation<double> _animation;

  RxBool isReadMore = false.obs;

  @override
  void initState() {
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    if (_controller != null) {
      _animation = Tween(begin: 0.0, end: 1.0).animate(_controller!);
    }
    initializeVideoPlayer();
    customSetting();
    super.initState();
  }

  @override
  void dispose() {
    _controller?.dispose();
    onDisposeVideoPlayer();
    Utils.showLog("Dispose Method Called Success");
    super.dispose();
  }

  Future<void> initializeVideoPlayer() async {
    try {
      String videoPath = controller.mainReels[widget.index].videoUrl!;

      videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(Api.baseUrl + videoPath));

      await videoPlayerController?.initialize();

      if (videoPlayerController != null && (videoPlayerController?.value.isInitialized ?? false)) {
        chewieController = ChewieController(
          videoPlayerController: videoPlayerController!,
          looping: true,
          allowedScreenSleep: false,
          allowMuting: false,
          showControlsOnInitialize: false,
          showControls: false,
          maxScale: 1,
        );

        if (chewieController != null) {
          isVideoLoading.value = false;
          (widget.index == widget.currentPageIndex && isReelsPage.value) ? onPlayVideo() : null; // Use => First Time Video Playing...
        } else {
          isVideoLoading.value = true;
        }

        videoPlayerController?.addListener(
          () {
            // Use => If Video Buffering then show loading....
            (videoPlayerController?.value.isBuffering ?? false) ? isBuffering.value = true : isBuffering.value = false;

            if (isReelsPage.value == false) {
              onStopVideo(); // Use => On Change Routes...
            }
          },
        );
      }
    } catch (e) {
      onDisposeVideoPlayer();
      Utils.showLog("Reels Video Initialization Failed !!! ${widget.index} => $e");
    }
  }

  void onStopVideo() {
    isPlaying.value = false;
    videoPlayerController?.pause();
  }

  void onPlayVideo() {
    isPlaying.value = true;
    videoPlayerController?.play();
  }

  void onDisposeVideoPlayer() {
    try {
      onStopVideo();
      videoPlayerController?.dispose();
      chewieController?.dispose();
      chewieController = null;
      videoPlayerController = null;
      isVideoLoading.value = true;
    } catch (e) {
      Utils.showLog(">>>> On Dispose VideoPlayer Error => $e");
    }
  }

  void customSetting() {
    isLike.value = controller.mainReels[widget.index].isLike!;
    customChanges["like"] = int.parse(controller.mainReels[widget.index].totalLikes.toString());
    customChanges["comment"] = int.parse(controller.mainReels[widget.index].totalComments.toString());
  }

  void onClickVideo() async {
    if (isVideoLoading.value == false) {
      videoPlayerController!.value.isPlaying ? onStopVideo() : onPlayVideo();
      isShowIcon.value = true;
      await 2.seconds.delay();
      isShowIcon.value = false;
    }
    if (isReelsPage.value == false) {
      isReelsPage.value = true; // Use => On Back Reels Page...
    }
  }

  void onClickPlayPause() async {
    videoPlayerController!.value.isPlaying ? onStopVideo() : onPlayVideo();
    if (isReelsPage.value == false) {
      isReelsPage.value = true; // Use => On Back Reels Page...
    }
  }

  Future<void> onClickShare() async {
    isReelsPage.value = false;

    Get.dialog(const LoadingUi(), barrierDismissible: false); // Start Loading...

    await BranchIoServices.onCreateBranchIoLink(
      id: controller.mainReels[widget.index].id ?? "",
      name: controller.mainReels[widget.index].caption ?? "",
      image: controller.mainReels[widget.index].videoImage ?? "",
      userId: controller.mainReels[widget.index].userId ?? "",
      pageRoutes: "Video",
    );

    final link = await BranchIoServices.onGenerateLink();

    Get.back(); // Stop Loading...

    if (link != null) {
      CustomShare.onShareLink(link: link);
    }
    await ReelsShareApi.callApi(loginUserId: Database.loginUserId, videoId: controller.mainReels[widget.index].id!);
  }

  Future<void> onClickLike() async {
    if (isLike.value) {
      isLike.value = false;
      customChanges["like"]--;
    } else {
      isLike.value = true;
      customChanges["like"]++;
    }

    isShowLikeIconAnimation.value = true;
    await 500.milliseconds.delay();
    isShowLikeIconAnimation.value = false;

    await ReelsLikeDislikeApi.callApi(
      loginUserId: Database.loginUserId,
      videoId: controller.mainReels[widget.index].id!,
    );
  }

  Future<void> onDoubleClick() async {
    if (isLike.value) {
      isLike.value = false;
      customChanges["like"]--;
    } else {
      isLike.value = true;
      customChanges["like"]++;

      isShowLikeAnimation.value = true;
      Vibration.vibrate(duration: 50, amplitude: 128);
      await 1200.milliseconds.delay();
      isShowLikeAnimation.value = false;
    }
    await ReelsLikeDislikeApi.callApi(
      loginUserId: Database.loginUserId,
      videoId: controller.mainReels[widget.index].id!,
    );
  }

  Future<void> onClickComment() async {
    isReelsPage.value = false;
    customChanges["comment"] = await CommentBottomSheetUi.show(
      context: context,
      commentType: 2,
      commentTypeId: controller.mainReels[widget.index].id!,
      totalComments: customChanges["comment"],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.index == widget.currentPageIndex) {
      // Use => Play Current Video On Scrolling...
      isReadMore.value = false;
      (isVideoLoading.value == false && isReelsPage.value) ? onPlayVideo() : null;
    } else {
      // Restart Previous Video On Scrolling...
      isVideoLoading.value == false ? videoPlayerController?.seekTo(Duration.zero) : null;
      onStopVideo(); // Stop Previous Video On Scrolling...
    }
    return Scaffold(
      body: SizedBox(
        height: Get.height,
        width: Get.width,
        child: Stack(
          children: [
            GestureDetector(
              onTap: onClickVideo,
              onDoubleTap: onDoubleClick,
              child: Container(
                color: AppColor.black,
                height: (Get.height - AppConstant.bottomBarSize),
                width: Get.width,
                child: Obx(
                  () => isVideoLoading.value
                      ? Align(alignment: Alignment.bottomCenter, child: LinearProgressIndicator(color: AppColor.primary))
                      : SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: videoPlayerController?.value.size.width ?? 0,
                              height: videoPlayerController?.value.size.height ?? 0,
                              child: Chewie(controller: chewieController!),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            Positioned(
              // Logo Water Mark Code
              top: MediaQuery.of(context).viewPadding.top + 15,
              left: 20,
              child: Visibility(
                  visible: Utils.isShowWaterMark,
                  child: CachedNetworkImage(
                    imageUrl: Utils.waterMarkIcon,
                    fit: BoxFit.contain,
                    imageBuilder: (context, imageProvider) => Image(
                      image: ResizeImage(imageProvider, width: Utils.waterMarkSize, height: Utils.waterMarkSize),
                      fit: BoxFit.contain,
                    ),
                    placeholder: (context, url) => const Offstage(),
                    errorWidget: (context, url, error) => const Offstage(),
                  )),
            ),
            Align(
              alignment: Alignment.center,
              child: SendGiftOnVideoBottomSheetUi.onShowGift(),
            ),
            Obx(
              () => Visibility(
                visible: isShowLikeAnimation.value,
                child: Align(alignment: Alignment.center, child: Lottie.asset(AppAsset.lottieLike, fit: BoxFit.cover, height: 300, width: 300)),
              ),
            ),
            Obx(
              () => isShowIcon.value
                  ? Align(
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: onClickPlayPause,
                        child: Container(
                          height: 70,
                          width: 70,
                          padding: EdgeInsets.only(left: isPlaying.value ? 0 : 2),
                          decoration: BoxDecoration(color: AppColor.black.withOpacity(0.2), shape: BoxShape.circle),
                          child: Center(
                            child: Image.asset(
                              isPlaying.value ? AppAsset.icPause : AppAsset.icPlay,
                              width: 30,
                              height: 30,
                              color: AppColor.white,
                            ),
                          ),
                        ),
                      ),
                    )
                  : const Offstage(),
            ),
            Positioned(
              bottom: 0,
              child: Obx(
                () => Visibility(
                  visible: (isVideoLoading == false),
                  child: Container(
                    height: Get.height / 4,
                    width: Get.width,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColor.transparent, AppColor.black.withOpacity(0.7)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              child: Container(
                padding: Platform.isAndroid ? EdgeInsets.only(top: 30) : EdgeInsets.only(top: 46),
                height: Get.height,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomIconButton(
                      circleSize: 40,
                      iconSize: 25,
                      icon: AppAsset.icCreate,
                      callback: () {
                        isReelsPage.value = false;
                        VideoPickerBottomSheetUi.show(context: context);
                      },
                    ),
                    5.width,
                    GestureDetector(
                      onTap: () {
                        isReelsPage.value = false;
                        ReportBottomSheetUi.show(context: context, eventId: controller.mainReels[widget.index].id ?? "", eventType: 1);
                      },
                      child: Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.more_vert_rounded,
                          color: AppColor.white,
                          size: 30,
                        ),
                      ),
                    ),
                    8.width,
                  ],
                ),
              ),
            ),
            Positioned(
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(top: 30, bottom: 100),
                height: Get.height,
                child: Column(
                  children: [
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Utils.showLog("Video User Id => ${controller.mainReels[widget.index].userId} => ${Database.loginUserId}");
                        if (controller.mainReels[widget.index].userId != Database.loginUserId) {
                          isReelsPage.value = false;
                          SendGiftOnVideoBottomSheetUi.show(
                            context: context,
                            videoId: controller.mainReels[widget.index].id ?? "",
                          );
                        } else {
                          Utils.showToast(EnumLocal.txtYouCantSendGiftOwnVideo.name.tr);
                        }
                      },
                      child: SizedBox(
                        width: 65,
                        child: Lottie.asset(AppAsset.lottieGift),
                      ),
                    ),
                    10.height,
                    Obx(
                      () => SizedBox(
                        height: 40,
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          height: isShowLikeIconAnimation.value ? 15 : 50,
                          width: isShowLikeIconAnimation.value ? 15 : 50,
                          alignment: Alignment.center,
                          child: CustomIconButton(
                            icon: AppAsset.icLike,
                            callback: onClickLike,
                            iconSize: 34,
                            iconColor: isLike.value ? AppColor.colorRedContainer : AppColor.white,
                          ),
                        ),
                      ),
                    ),
                    Obx(
                      () => Text(
                        CustomFormatNumber.convert(customChanges["like"]),
                        style: AppFontStyle.styleW700(AppColor.white, 14),
                      ),
                    ),
                    15.height,
                    CustomIconButton(icon: AppAsset.icComment, circleSize: 40, callback: onClickComment, iconSize: 34),
                    Obx(
                      () => Text(
                        CustomFormatNumber.convert(customChanges["comment"]),
                        style: AppFontStyle.styleW700(AppColor.white, 14),
                      ),
                    ),
                    15.height,
                    CustomIconButton(
                      circleSize: 40,
                      // circleColor: Colors.pink,
                      icon: AppAsset.icShare,
                      callback: onClickShare,
                      iconSize: 32,
                      iconColor: AppColor.white,
                    ),
                    Text(
                      "",
                      style: AppFontStyle.styleW700(AppColor.white, 14),
                    ),
                    GestureDetector(
                      onTap: () {
                        Utils.showLog("Song Id => ${controller.mainReels[widget.index].songId}");
                        if (controller.mainReels[widget.index].songId != "" && controller.mainReels[widget.index].songId != null) {
                          isReelsPage.value = false;
                          Get.toNamed(AppRoutes.audioWiseVideosPage, arguments: controller.mainReels[widget.index].songId);
                        } else if (controller.mainReels[widget.index].userId != Database.loginUserId) {
                          isReelsPage.value = false;
                          PreviewProfileBottomSheetUi.show(
                            context: context,
                            userId: controller.mainReels[widget.index].userId ?? "",
                          );
                        } else {
                          isReelsPage.value = false;
                          final controller = Get.find<BottomBarController>();
                          controller.onChangeBottomBar(4);
                        }
                      },
                      child: SizedBox(
                        width: 50,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            RotationTransition(turns: _animation, child: Image.asset(AppAsset.icMusicCd)),
                            RotationTransition(
                              turns: _animation,
                              child: Container(
                                width: 30,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(shape: BoxShape.circle),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Image.asset(AppAsset.icProfilePlaceHolder),
                                    PreviewNetworkImageUi(image: controller.mainReels[widget.index].userImage),
                                    Visibility(
                                      visible: controller.mainReels[widget.index].isProfileImageBanned ?? false,
                                      child: AspectRatio(
                                        aspectRatio: 1,
                                        child: Container(
                                          clipBehavior: Clip.antiAlias,
                                          decoration: BoxDecoration(shape: BoxShape.circle),
                                          child: BlurryContainer(
                                            blur: 3,
                                            borderRadius: BorderRadius.circular(50),
                                            color: AppColor.black.withOpacity(0.3),
                                            child: Offstage(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              right: 4,
                              bottom: -4,
                              child: Image.asset(AppAsset.icMusic, width: 20),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 15,
              bottom: 20,
              child: SizedBox(
                height: 400,
                width: Get.width / 1.5,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (controller.mainReels[widget.index].userId != Database.loginUserId) {
                              isReelsPage.value = false;
                              PreviewProfileBottomSheetUi.show(
                                context: context,
                                userId: controller.mainReels[widget.index].userId ?? "",
                              );
                            } else {
                              isReelsPage.value = false;
                              final controller = Get.find<BottomBarController>();
                              controller.onChangeBottomBar(4);
                            }
                          },
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 46,
                                width: 46,
                                clipBehavior: Clip.antiAlias,
                                decoration: const BoxDecoration(shape: BoxShape.circle),
                                child: Stack(
                                  children: [
                                    AspectRatio(aspectRatio: 1, child: Image.asset(AppAsset.icProfilePlaceHolder)),
                                    AspectRatio(aspectRatio: 1, child: PreviewNetworkImageUi(image: controller.mainReels[widget.index].userImage)),
                                    Visibility(
                                      visible: controller.mainReels[widget.index].isProfileImageBanned ?? false,
                                      child: AspectRatio(
                                        aspectRatio: 1,
                                        child: Container(
                                          clipBehavior: Clip.antiAlias,
                                          decoration: BoxDecoration(shape: BoxShape.circle),
                                          child: BlurryContainer(
                                            blur: 3,
                                            borderRadius: BorderRadius.circular(50),
                                            color: AppColor.black.withOpacity(0.3),
                                            child: Offstage(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              10.width,
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: Get.width / 2,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: [
                                        Text(
                                          maxLines: 1,
                                          controller.mainReels[widget.index].name ?? "",
                                          style: AppFontStyle.styleW600(AppColor.white, 16.5),
                                        ),
                                        Visibility(
                                          visible: controller.mainReels[widget.index].isVerified ?? false,
                                          child: Padding(
                                            padding: const EdgeInsets.only(left: 3),
                                            child: Image.asset(AppAsset.icBlueTick, width: 20),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: Get.width / 2,
                                    child: Text(
                                      maxLines: 1,
                                      controller.mainReels[widget.index].userName ?? "",
                                      style: AppFontStyle.styleW500(AppColor.white, 13),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        10.height,
                        Visibility(
                          visible: controller.mainReels[widget.index].caption?.trim().isNotEmpty ?? false,
                          child: ReadMoreText(
                            controller.mainReels[widget.index].caption ?? "",
                            trimMode: TrimMode.Line,
                            trimLines: 3,
                            style: AppFontStyle.styleW500(AppColor.white, 13),
                            colorClickableText: AppColor.primary,
                            trimCollapsedText: ' Show more',
                            trimExpandedText: ' Show less',
                            moreStyle: AppFontStyle.styleW500(AppColor.primary, 13.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// TODO => Use Loading Time Show Image...
// Container(
//                           color: AppColor.black,
//                           height: Get.height,
//                           width: Get.width,
//                           child: Stack(
//                             alignment: Alignment.center,
//                             children: [
//                               SizedBox(
//                                 height: Get.height,
//                                 width: Get.width,
//                                 child: PreviewNetworkImageUi(
//                                   image: controller.mainReels[widget.index].videoImage,
//                                 ),
//                               ),
//                               LoadingUi(color: AppColor.white),
//                             ],
//                           ),
//                         )

// TODO => Old Caption

// Visibility(
//   visible: controller.mainReels[widget.index].hashTag?.isNotEmpty ?? false,
//   child: Column(
//     children: [
//       SizedBox(
//         width: Get.width / 2,
//         child: Text(
//           maxLines: 2,
//           controller.mainReels[widget.index].hashTag?.map((e) => " #$e").join('').toString() ?? "",
//           style: AppFontStyle.styleW500(AppColor.white, 13),
//         ),
//       ),
//       10.height,
//     ],
//   ),
// ),
// Visibility(
//   visible: controller.mainReels[widget.index].caption?.trim().isNotEmpty ?? false,
//   child: Obx(
//     () => GestureDetector(
//       onTap: () => isReadMore.value = !isReadMore.value,
//       child: AnimatedContainer(
//         duration: Duration(milliseconds: 300),
//         curve: Curves.linear,
//         height: isReadMore.value ? 130 : 52,
//         alignment: Alignment.topLeft,
//         width: Get.width / 2,
//         child: SingleChildScrollView(
//           child: Text(
//             (controller.mainReels[widget.index].caption ?? ""),
//             style: AppFontStyle.styleW600(AppColor.white, 13),
//           ),
//         ),
//       ),
//     ),
//   ),
// ),
