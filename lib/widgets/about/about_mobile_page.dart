import 'package:aves/widgets/about/app_ref.dart';
import 'package:aves/widgets/about/data_usage.dart';
import 'package:aves/widgets/about/licenses.dart';
import 'package:aves/widgets/common/basic/insets.dart';
import 'package:aves/widgets/common/basic/link_chip.dart';
import 'package:aves/widgets/common/basic/scaffold.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:flutter/material.dart';

class AboutMobilePage extends StatelessWidget {
  const AboutMobilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AvesScaffold(
      appBar: AppBar(
        title: Text(context.l10n.aboutPageTitle),
      ),
      body: GestureAreaProtectorStack(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.only(top: 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      const AppReference(),
                      const Divider(),
                      const AboutDataUsage(),
                      const Divider(),
                      const AboutAntiLoss(),
                      const Divider(),
                    ],
                  ),
                ),
              ),
              const Licenses(),
              const BottomPaddingSliver(),
            ],
          ),
        ),
      ),
    );
  }
}

class AboutAntiLoss extends StatelessWidget {
  const AboutAntiLoss({super.key});

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('防失联', style: titleStyle),
          ),
          LinkChip(
            text: '防失联⑴：https://link3.cc/wei8',
            urlString: 'https://link3.cc/wei8',
          ),
          LinkChip(
            text: '防失联⑵密码1234：https://wei8.ysepan.com/',
            urlString: 'https://wei8.ysepan.com/',
          ),
        ],
      ),
    );
  }
}
