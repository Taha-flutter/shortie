import 'package:get/get.dart';
import 'package:shortie/pages/upload_reels_page/controller/upload_reels_controller.dart';

class UploadReelsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<UploadReelsController>(() => UploadReelsController());
  }
}
