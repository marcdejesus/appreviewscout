import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'data/repositories/app_repository.dart';
import 'data/repositories/project_repository.dart';
import 'data/repositories/review_repository.dart';
import 'data/repositories/scrape_repository.dart';
import 'data/services/api_launcher.dart';
import 'data/services/api_service.dart';
import 'ui/viewmodels/active_project_viewmodel.dart';
import 'ui/viewmodels/app_list_viewmodel.dart';
import 'ui/viewmodels/pinned_reviews_viewmodel.dart';
import 'ui/viewmodels/projects_viewmodel.dart';
import 'ui/viewmodels/review_list_viewmodel.dart';
import 'ui/viewmodels/scrape_viewmodel.dart';
import 'ui/views/shell_view.dart';
import 'ui/widgets/loading_state.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ApiService _apiService;
  late final ApiLauncher _apiLauncher;
  late final Future<void> _startupFuture;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _apiLauncher = ApiLauncher(_apiService);
    _startupFuture = _apiLauncher.ensureRunning();
  }

  @override
  void dispose() {
    _apiLauncher.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: _apiService),
        Provider<AppRepository>(create: (context) => AppRepository(context.read<ApiService>())),
        Provider<ProjectRepository>(create: (context) => ProjectRepository(context.read<ApiService>())),
        Provider<ReviewRepository>(create: (context) => ReviewRepository(context.read<ApiService>())),
        Provider<ScrapeRepository>(create: (context) => ScrapeRepository(context.read<ApiService>())),
        ChangeNotifierProvider<ActiveProjectViewModel>(
          create: (context) => ActiveProjectViewModel(context.read<ProjectRepository>()),
        ),
        ChangeNotifierProvider<AppListViewModel>(
          create: (context) => AppListViewModel(
            context.read<AppRepository>(),
            context.read<ActiveProjectViewModel>(),
          ),
        ),
        ChangeNotifierProvider<ReviewListViewModel>(
          create: (context) => ReviewListViewModel(
            context.read<ReviewRepository>(),
            context.read<ActiveProjectViewModel>(),
          ),
        ),
        ChangeNotifierProvider<PinnedReviewsViewModel>(
          create: (context) => PinnedReviewsViewModel(
            context.read<ReviewRepository>(),
            context.read<ActiveProjectViewModel>(),
          ),
        ),
        ChangeNotifierProvider<ProjectsViewModel>(
          create: (context) => ProjectsViewModel(
            context.read<ProjectRepository>(),
            context.read<ActiveProjectViewModel>(),
          ),
        ),
        ChangeNotifierProvider<ScrapeViewModel>(
          create: (context) => ScrapeViewModel(context.read<ScrapeRepository>()),
        ),
      ],
      child: MaterialApp(
        title: 'AppReviewScout',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: FutureBuilder<void>(
          future: _startupFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(body: LoadingState(label: 'Starting local API...'));
            }
            if (snapshot.hasError) {
              return _StartupErrorView(error: snapshot.error.toString());
            }
            return const ShellView();
          },
        ),
      ),
    );
  }
}

class _StartupErrorView extends StatelessWidget {
  const _StartupErrorView({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Startup Error', style: textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(
                  error,
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'In development, run the FastAPI server manually before launching Flutter.',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
