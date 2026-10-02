import 'package:http/http.dart' as http;
import 'package:yvenist/core/config/app_config.dart';
import 'package:yvenist/core/network/api_client.dart';
import 'package:yvenist/core/storage/theme_preference_storage.dart';
import 'package:yvenist/core/storage/token_storage.dart';
import 'package:yvenist/features/admin/data/api_review_repository.dart';
import 'package:yvenist/features/admin/data/in_memory_review_repository.dart';
import 'package:yvenist/features/admin/domain/review_repository.dart';
import 'package:yvenist/features/auth/data/api_auth_repository.dart';
import 'package:yvenist/features/auth/data/in_memory_auth_repository.dart';
import 'package:yvenist/features/auth/domain/repositories/auth_repository.dart';
import 'package:yvenist/features/catalog/data/api_catalog_repository.dart';
import 'package:yvenist/features/catalog/data/in_memory_catalog_repository.dart';
import 'package:yvenist/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:yvenist/features/client/favorites/data/api_favorites_repository.dart';
import 'package:yvenist/features/client/favorites/data/in_memory_favorites_repository.dart';
import 'package:yvenist/features/client/favorites/domain/favorites_repository.dart';
import 'package:yvenist/features/party_maker/data/repositories/api_party_repository.dart';
import 'package:yvenist/features/party_maker/data/repositories/in_memory_party_repository.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/vendor/data/api_vendor_repository.dart';
import 'package:yvenist/features/vendor/data/in_memory_vendor_repository.dart';
import 'package:yvenist/features/vendor/domain/vendor_repository.dart';

/// Raiz de composição: o único lugar que sabe quais implementações existem.
///
/// As telas e os controllers só conhecem os contratos (`AuthRepository`,
/// `CatalogRepository`...). Aqui se decide se eles são atendidos pela API ou
/// pelos dados em memória do modo demonstração.
class AppDependencies {
  AppDependencies({
    required this.config,
    required this.auth,
    required this.catalog,
    required this.favorites,
    required this.parties,
    required this.vendors,
    required this.reviews,
    ThemePreferenceStorage? themePreferences,
    this.apiClient,
  }) : themePreferences = themePreferences ?? InMemoryThemePreferenceStorage();

  /// As dependências do app de verdade: a escolha de tema fica guardada no
  /// aparelho nos dois modos.
  factory AppDependencies.fromConfig(AppConfig config) {
    final themePreferences = DeviceThemePreferenceStorage();
    return config.isDemoMode
        ? AppDependencies.demo(
            config: config,
            themePreferences: themePreferences,
          )
        : AppDependencies.api(config, themePreferences: themePreferences);
  }

  /// Tudo pela API. [httpClient], [tokenStorage] e [themePreferences] existem
  /// para os testes.
  factory AppDependencies.api(
    AppConfig config, {
    http.Client? httpClient,
    TokenStorage? tokenStorage,
    ThemePreferenceStorage? themePreferences,
  }) {
    final tokens = tokenStorage ?? SecureTokenStorage();
    final api = ApiClient(
      baseUrl: config.apiBaseUrl!,
      tokenStorage: tokens,
      httpClient: httpClient,
    );
    return AppDependencies(
      config: config,
      apiClient: api,
      auth: ApiAuthRepository(api, tokens),
      catalog: ApiCatalogRepository(api),
      favorites: ApiFavoritesRepository(api),
      parties: ApiPartyRepository(api),
      vendors: ApiVendorRepository(api),
      reviews: ApiReviewRepository(api),
      themePreferences: themePreferences ?? DeviceThemePreferenceStorage(),
    );
  }

  /// Tudo em memória, sem rede: o app funciona sozinho.
  factory AppDependencies.demo({
    AppConfig config = const AppConfig(),
    bool startSignedIn = true,
    ThemePreferenceStorage? themePreferences,
  }) {
    final auth = InMemoryAuthRepository(startSignedIn: startSignedIn);
    return AppDependencies(
      config: config,
      auth: auth,
      catalog: InMemoryCatalogRepository(),
      favorites: InMemoryFavoritesRepository(
        currentUserId: () => auth.currentUserId,
      ),
      parties: InMemoryPartyRepository(),
      vendors: InMemoryVendorRepository(
        currentUserId: () => auth.currentUserId,
      ),
      reviews: InMemoryReviewRepository(),
      themePreferences: themePreferences,
    );
  }

  final AppConfig config;
  final AuthRepository auth;
  final CatalogRepository catalog;
  final FavoritesRepository favorites;
  final PartyRepository parties;
  final VendorRepository vendors;
  final ReviewRepository reviews;

  /// Onde a escolha de tema fica guardada. Em memória, se nada for informado.
  final ThemePreferenceStorage themePreferences;

  /// Presente só quando o app fala com a API.
  final ApiClient? apiClient;
}
