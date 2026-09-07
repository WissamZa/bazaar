// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Bazaar';

  @override
  String get appTagline => 'Your market, your data';

  @override
  String get tabHome => 'Home';

  @override
  String get tabItems => 'Items';

  @override
  String get tabLists => 'Lists';

  @override
  String get tabStores => 'Stores';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonTotal => 'Total';

  @override
  String get commonClose => 'Close';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonOptional => 'optional';

  @override
  String get commonNone => 'None';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonViewAll => 'View all';

  @override
  String get commonError => 'Something went wrong';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonUntitled => 'Untitled';

  @override
  String get commonShare => 'Share';

  @override
  String get commonExport => 'Export';

  @override
  String get commonImport => 'Import';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonCopied => 'Copied';

  @override
  String get commonOpenSettings => 'Open settings';

  @override
  String get welcomeTitle => 'Welcome to Bazaar';

  @override
  String get welcomeSubtitle =>
      'Scan barcodes, track prices across stores — all stored on your device only.';

  @override
  String get usernameField => 'Your name';

  @override
  String get usernameRequired => 'Please enter a name to continue';

  @override
  String get continueLabel => 'Continue';

  @override
  String get privacyNote => 'No account. No server. No telemetry.';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get greetingNight => 'Good night';

  @override
  String get homeKpiLists => 'Lists';

  @override
  String get homeKpiItems => 'Items';

  @override
  String get homeKpiStores => 'Stores';

  @override
  String get homeRecentLists => 'Recent lists';

  @override
  String get homeStoresByItems => 'Stores by item count';

  @override
  String get homeTopExpensive => 'Most expensive items';

  @override
  String get homeCheapest => 'Cheapest';

  @override
  String get homeNoLists => 'No lists yet';

  @override
  String get homeNoListsHint => 'Create your first shopping list';

  @override
  String get homeNoItems => 'No items yet';

  @override
  String get homeNoItemsHint => 'Scan a barcode or add items manually';

  @override
  String get homeNoStores => 'No stores yet';

  @override
  String get homeNoStoresHint => 'Add stores to start tracking prices';

  @override
  String get homeCreateList => 'Create a list';

  @override
  String get homeScanFirst => 'Scan your first barcode';

  @override
  String get itemsTitle => 'Items';

  @override
  String get searchItems => 'Search items…';

  @override
  String get addItem => 'Add item';

  @override
  String get editItem => 'Edit item';

  @override
  String get itemSaved => 'Item saved';

  @override
  String get itemDeleted => 'Item deleted';

  @override
  String get deleteItemTitle => 'Delete this item?';

  @override
  String deleteItemMessage(String name) {
    return '“$name” and its price history will be removed. This cannot be undone.';
  }

  @override
  String get noItems => 'No items yet';

  @override
  String get noItemsHint => 'Tap + to add your first item';

  @override
  String get sortAndGroup => 'Sort & group';

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortNewest => 'Newest';

  @override
  String get sortName => 'Name';

  @override
  String get sortPriceHigh => 'Price (high → low)';

  @override
  String get sortPriceLow => 'Price (low → high)';

  @override
  String get groupBy => 'Group by';

  @override
  String get groupNone => 'No grouping';

  @override
  String get groupBrand => 'Brand';

  @override
  String get groupCategory => 'Category';

  @override
  String get uncategorized => 'Uncategorized';

  @override
  String get noBrand => 'No brand';

  @override
  String get generalTab => 'General';

  @override
  String get pricesTab => 'Prices';

  @override
  String get historyTab => 'History';

  @override
  String get nameEnField => 'Name (English)';

  @override
  String get nameArField => 'Name (Arabic)';

  @override
  String get nameRequired => 'A name is required';

  @override
  String get brandField => 'Brand';

  @override
  String get noteField => 'Note';

  @override
  String get barcodeField => 'Barcode';

  @override
  String get scanBarcode => 'Scan barcode';

  @override
  String get categoryField => 'Category';

  @override
  String get addCategory => 'Add category';

  @override
  String get categoryNameEn => 'Category name (English)';

  @override
  String get categoryNameAr => 'Category name (Arabic)';

  @override
  String get deleteCategoryTitle => 'Delete this category?';

  @override
  String get deleteCategoryMessage =>
      'Items in it will become uncategorized. This cannot be undone.';

  @override
  String get imageField => 'Image';

  @override
  String get pickImage => 'Choose from gallery';

  @override
  String get imageUrlField => 'Image URL';

  @override
  String get priceAtStores => 'Prices at stores';

  @override
  String get addStorePrice => 'Add a store price';

  @override
  String get noStoresForPrice => 'Add a store first to track its prices';

  @override
  String get priceHistory => 'Price history';

  @override
  String get noPriceHistory => 'No price changes recorded yet';

  @override
  String get priceInputHint => 'Price';

  @override
  String get saveFailed => 'Couldn\'t save — try again';

  @override
  String get lookupMethod => 'Lookup method';

  @override
  String get listsTitle => 'Shopping lists';

  @override
  String get newList => 'New list';

  @override
  String get editList => 'Edit list';

  @override
  String get listNameField => 'List name';

  @override
  String get listNameRequired => 'A list name is required';

  @override
  String get noLists => 'No shopping lists yet';

  @override
  String get noListsHint => 'Create a list to start shopping';

  @override
  String get deleteListTitle => 'Delete this list?';

  @override
  String deleteListMessage(String name) {
    return '“$name” and its items will be removed. This cannot be undone.';
  }

  @override
  String get listItemAdded => 'Item added';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String checkedCount(int count, int total) {
    return '$count/$total done';
  }

  @override
  String get checkedTotal => 'Total (checked)';

  @override
  String get listEmptyTitle => 'This list is empty';

  @override
  String get listEmptyHint => 'Add items from your catalog or scan a barcode';

  @override
  String get addFromCatalog => 'Add from catalog';

  @override
  String get scanNewItem => 'Scan barcode';

  @override
  String get searchItemsToAdd => 'Search your items…';

  @override
  String get noItemsToAdd => 'No matching items';

  @override
  String get quantity => 'Qty';

  @override
  String get decreaseQuantity => 'Decrease quantity';

  @override
  String get increaseQuantity => 'Increase quantity';

  @override
  String get markChecked => 'Mark as bought';

  @override
  String get preferredStore => 'Preferred store';

  @override
  String get noPreferredStore => 'Auto (cheapest)';

  @override
  String get changeStore => 'Change store';

  @override
  String get selectStore => 'Select store';

  @override
  String get removeFromList => 'Remove from list';

  @override
  String get itemRemovedFromList => 'Removed from list';

  @override
  String get storesTitle => 'Stores';

  @override
  String get newStore => 'New store';

  @override
  String get editStore => 'Edit store';

  @override
  String get storeNameField => 'Store name';

  @override
  String get storeNameArField => 'Store name (Arabic)';

  @override
  String get storeNameRequired => 'A store name is required';

  @override
  String get websiteField => 'Website';

  @override
  String get addressField => 'Address';

  @override
  String get noStores => 'No stores yet';

  @override
  String get noStoresHint => 'Add a store to track prices';

  @override
  String get deleteStoreTitle => 'Delete this store?';

  @override
  String deleteStoreMessage(String name) {
    return '“$name” and its recorded prices will be removed. This cannot be undone.';
  }

  @override
  String get storeSaved => 'Store saved';

  @override
  String get storeDeleted => 'Store deleted';

  @override
  String get itemsAtStore => 'Items at this store';

  @override
  String get noItemsAtStore => 'No items linked to this store yet';

  @override
  String get defaultStoreName => 'Default';

  @override
  String get scannerTitle => 'Scan barcode';

  @override
  String get scanning => 'Scanning…';

  @override
  String get cameraPermissionRequired =>
      'Camera permission is required to scan barcodes';

  @override
  String get enterManually => 'Type it instead';

  @override
  String get barcodeManualInput => 'Barcode number';

  @override
  String get scanResultFoundLocally => 'Already in your items';

  @override
  String get scanResultFoundOnline => 'Found online';

  @override
  String get scanResultNotFound => 'Not found';

  @override
  String get scanResultNotFoundHint =>
      'This barcode isn\'t in your items and couldn\'t be found online. You can fill the details manually.';

  @override
  String get lookupSource => 'Lookup source';

  @override
  String get sourceAuto => 'Auto (all sources)';

  @override
  String get sourceOpenFoodFacts => 'Open Food Facts';

  @override
  String get sourceSearxng => 'SearXNG';

  @override
  String get lookingUp => 'Looking up…';

  @override
  String get searchingOnline => 'Searching online…';

  @override
  String get fillManually => 'Fill manually';

  @override
  String get addToItems => 'Add to items';

  @override
  String get addToList => 'Add to list';

  @override
  String foundAtSource(String source) {
    return 'Source: $source';
  }

  @override
  String get noPriceFound =>
      'No price found online — you can add it manually at any store';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsSearch => 'Search & AI';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsAbout => 'About';

  @override
  String get username => 'Username';

  @override
  String get changeUsername => 'Change username';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get currency => 'Currency';

  @override
  String get sarCurrency => 'Saudi Riyal (SAR)';

  @override
  String get usdCurrency => 'US Dollar (USD)';

  @override
  String get manageCategories => 'Categories';

  @override
  String get searchAndAiTitle => 'Search & AI';

  @override
  String get searchAndAiHint => 'Configure how online barcode lookups work';

  @override
  String get configComplete => 'Ready';

  @override
  String get configIncomplete => 'Needs configuration';

  @override
  String get extractionStrategy => 'Extraction strategy';

  @override
  String get strategySchemaOnly => 'Schema only (fast, free)';

  @override
  String get strategySchemaCloud => 'Schema → Cloud LLM';

  @override
  String get strategySchemaOnDevice => 'Schema → On-device LLM';

  @override
  String get strategySchemaCloudOnDevice => 'Schema → Cloud → On-device';

  @override
  String get strategyCloudOnly => 'Cloud LLM only';

  @override
  String get strategyOnDeviceOnly => 'On-device LLM only';

  @override
  String get strategyHint =>
      'Schema parsing reads structured product data directly from store pages. LLM tiers fill in missing fields.';

  @override
  String get cloudProvider => 'Cloud provider';

  @override
  String get providerGemini => 'Google Gemini';

  @override
  String get providerOpenai => 'OpenAI-compatible';

  @override
  String get providerGroq => 'Groq';

  @override
  String get providerCerebras => 'Cerebras';

  @override
  String get providerOllama => 'Ollama (self-hosted)';

  @override
  String get apiKeyField => 'API key';

  @override
  String get apiKeySet => 'Key saved';

  @override
  String get apiKeyMissing => 'No key';

  @override
  String get apiKeyHint =>
      'Stored in your device\'s secure storage — never uploaded';

  @override
  String get modelField => 'Model';

  @override
  String get modelHint => 'Leave empty for the default';

  @override
  String get baseUrlField => 'Base URL';

  @override
  String get searxngUrlField => 'SearXNG server URL';

  @override
  String get searxngUrlHint =>
      'Your self-hosted SearXNG instance (JSON format enabled)';

  @override
  String get invalidUrl => 'Enter a valid http(s) URL';

  @override
  String get onDeviceModels => 'On-device model';

  @override
  String get onDeviceHint =>
      'Runs fully offline on this device. Large download.';

  @override
  String get downloadModel => 'Download';

  @override
  String downloadingModel(int percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get deleteModel => 'Delete model';

  @override
  String get modelDownloaded => 'Downloaded';

  @override
  String get modelNotDownloaded => 'Not downloaded';

  @override
  String get autoloadOnDevice => 'Load model automatically on app start';

  @override
  String get forgetAllKeys => 'Forget all keys';

  @override
  String get forgetAllKeysConfirm =>
      'Remove all saved API keys and the on-device model path?';

  @override
  String get keysForgotten => 'All keys removed';

  @override
  String get pipelineDebugger => 'Pipeline debugger';

  @override
  String get pipelineDebuggerHint =>
      'Run a barcode through every lookup tier and inspect what each one returned';

  @override
  String get runPipeline => 'Run';

  @override
  String get pipelineBarcodeField => 'Barcode to test';

  @override
  String get pipelineFinalResult => 'Final result';

  @override
  String get pipelineOpenInBrowser => 'Compare in browser';

  @override
  String get statusSuccess => 'success';

  @override
  String get statusNoData => 'no data';

  @override
  String get statusFailed => 'failed';

  @override
  String get statusSkipped => 'skipped';

  @override
  String get ollamaBaseUrlField => 'Ollama base URL';

  @override
  String get backupTitle => 'Backup & restore';

  @override
  String get backupHint =>
      'Full backup of items, stores, lists, categories and price history as a ZIP file you can share or keep.';

  @override
  String get createBackup => 'Create backup';

  @override
  String get creatingBackup => 'Creating backup…';

  @override
  String get backupCreated => 'Backup created';

  @override
  String get backupFailed => 'Backup failed';

  @override
  String get backupPassphrase => 'Encryption passphrase';

  @override
  String get backupPassphraseHint => 'Leave empty for an unencrypted backup';

  @override
  String get restoreBackup => 'Restore from backup';

  @override
  String get selectRestoreItems => 'Choose what to restore';

  @override
  String get restoreItems => 'Items';

  @override
  String get restoreStores => 'Stores';

  @override
  String get restoreLists => 'Lists (with their items)';

  @override
  String get restore => 'Restore';

  @override
  String restoreComplete(int items, int stores, int lists, int skipped) {
    return 'Restore complete: $items items, $stores stores, $lists lists, $skipped skipped';
  }

  @override
  String get restoreFailed => 'Restore failed';

  @override
  String get backupEncryptedPrompt =>
      'This backup is encrypted. Enter its passphrase:';

  @override
  String get wrongPassphrase => 'Wrong passphrase or corrupted backup';

  @override
  String get exportData => 'Export & share';

  @override
  String get exportItems => 'Export items';

  @override
  String get exportStores => 'Export stores';

  @override
  String get exportList => 'Export list';

  @override
  String get importData => 'Import JSON file';

  @override
  String importComplete(int count) {
    return 'Imported $count items';
  }

  @override
  String get importFailed => 'Import failed';

  @override
  String get importTooLarge => 'File is too large';

  @override
  String get importUnknownType => 'Unrecognized file format';

  @override
  String get aboutTitle => 'About Bazaar';

  @override
  String get aboutVersion => 'Version';

  @override
  String get aboutPrivacy =>
      'Zero servers. Zero accounts. Zero telemetry. All data lives in a local database on this device.';

  @override
  String get aboutSource => 'Source code';

  @override
  String get aboutLicense => 'Released under the MIT License.';

  @override
  String get errorNoInternet => 'No internet connection';

  @override
  String get errorLookupFailed => 'Lookup failed';
}
