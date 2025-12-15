import 'package:flutter_modular/flutter_modular.dart';
import 'domain/repositories/ispeed_test_repository.dart';
import 'domain/repositories/inetwork_info_repository.dart';
import 'infrastructure/repositories/speed_test_repository_impl.dart';
import 'infrastructure/repositories/network_info_repository_impl.dart';
import 'domain/usecase/run_speed_test_usecase.dart';
import 'domain/usecase/get_connection_info_usecase.dart';
import 'domain/usecase/test_latency_usecase.dart';
import 'presentation/pages/speed_test_page.dart';
import 'presentation/mobx/speed_test.store.dart';

class SpeedTestModule extends Module {
  @override
  void binds(i) {
    // Repositories
    i.addLazySingleton<ISpeedTestRepository>(SpeedTestRepositoryImpl.new);
    i.addLazySingleton<INetworkInfoRepository>(NetworkInfoRepositoryImpl.new);

    // Use Cases
    i.add<RunSpeedTestUseCase>(
      () => RunSpeedTestUseCase(i<ISpeedTestRepository>()),
    );
    i.add<GetConnectionInfoUseCase>(
      () => GetConnectionInfoUseCase(i<INetworkInfoRepository>()),
    );
    i.add<TestLatencyUseCase>(
      () => TestLatencyUseCase(i<INetworkInfoRepository>()),
    );

    // Stores
    i.addLazySingleton<SpeedTestStore>(
      () => SpeedTestStore(
        i<RunSpeedTestUseCase>(),
        i<GetConnectionInfoUseCase>(),
        i<TestLatencyUseCase>(),
      ),
    );
  }

  @override
  void routes(r) {
    r.child(
      '/',
      child: (_) => SpeedTestPage(
        store: Modular.get<SpeedTestStore>(),
      ),
    );
  }
}
