import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortie/pages/privacy_policy_page/controller/privacy_policy_controller.dart';
import 'package:shortie/ui/loading_ui.dart';
import 'package:shortie/ui/simple_app_bar_ui.dart';
import 'package:shortie/utils/color.dart';
import 'package:shortie/utils/enums.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PrivacyPolicyView extends StatelessWidget {
  const PrivacyPolicyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: AppColor.white,
          shadowColor: AppColor.black.withOpacity(0.4),
          flexibleSpace: SimpleAppBarUi(title: EnumLocal.txtPrivacyPolicy.name.tr),
        ),
      ),
      body: GetBuilder<PrivacyPolicyController>(
        id: "onInitializeWebView",
        builder: (controller) => controller.webViewController != null
            ? WebViewWidget(controller: controller.webViewController!)
            : const LoadingUi(),
      ),
    );
  }
}
