import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/feed_provider.dart';
import '../widgets/feed_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      // Run loadFeed after first frame to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Provider.of<FeedProvider>(context, listen: false).loadFeed();
      });
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedProvider = Provider.of<FeedProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text("Today's Feed")),
      body: feedProvider.loading
          ? Center(child: CircularProgressIndicator())
          : feedProvider.feed.isEmpty
              ? Center(child: Text("No updates found"))
              : RefreshIndicator(
                  onRefresh: () async {
                    await feedProvider.loadFeed();
                  },
                  child: ListView.builder(
                    itemCount: feedProvider.feed.length,
                    itemBuilder: (context, index) {
                      return FeedCard(feedItem: feedProvider.feed[index]);
                    },
                  ),
                ),
    );
  }
}
