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
  String get tabItems => 'Items';

  @override
  String get tabLists => 'Shopping Lists';

  @override
  String get tabStores => 'Stores';

  @override
  String get addItem => 'Add Item';

  @override
  String get editItem => 'Edit Item';

  @override
  String get deleteItem => 'Delete Item';

  @override
  String get barcode => 'Barcode';

  @override
  String get scanBarcode => 'Scan Barcode';

  @override
  String get searchOnline => 'Search Online';

  @override
  String get price => 'Price';

  @override
  String get store => 'Store';

  @override
  String get stores => 'Stores';

  @override
  String get currency => 'Currency';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get backup => 'Backup';

  @override
  String get restore => 'Restore';

  @override
  String get share => 'Share';

  @override
  String get importData => 'Import';

  @override
  String get username => 'Username';

  @override
  String get enterUsername => 'Enter your name to continue';

  @override
  String get continueLabel => 'Continue';

  @override
  String get sarCurrency => 'Saudi Riyal (﷼)';

  @override
  String get usdCurrency => 'US Dollar (\$)';

  @override
  String get quantity => 'Qty';

  @override
  String get checked => 'Got it';

  @override
  String get note => 'Note';

  @override
  String get searchBarcode => 'Search barcode on the internet';

  @override
  String get addList => 'New List';

  @override
  String get editList => 'Edit List';

  @override
  String get addStore => 'New Store';

  @override
  String get editStore => 'Edit Store';

  @override
  String get nameEn => 'Name (English)';

  @override
  String get nameAr => 'Name (Arabic)';

  @override
  String get website => 'Website';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get selectCurrency => 'Select Currency';

  @override
  String get english => 'English';

  @override
  String get arabic => 'العربية';

  @override
  String get noItems => 'No items yet';

  @override
  String get noItemsHint => 'Tap the + button to add your first item';

  @override
  String get noLists => 'No shopping lists yet';

  @override
  String get noListsHint => 'Create a list to start shopping';

  @override
  String get noStores => 'No stores yet';

  @override
  String get noStoresHint => 'Add a store to track prices';

  @override
  String get total => 'Total';

  @override
  String get totalChecked => 'Total (checked)';

  @override
  String get addItemToList => 'Add item to list';

  @override
  String get preferredStore => 'Preferred Store';

  @override
  String get search => 'Search';

  @override
  String get searchItems => 'Search items...';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get confirmDelete => 'Confirm delete?';

  @override
  String get confirmDeleteMessage => 'This action cannot be undone.';

  @override
  String get scanning => 'Scanning...';

  @override
  String get lookingUp => 'Looking up barcode...';

  @override
  String get searchingOnline => 'Searching online...';

  @override
  String get foundInLocal => 'Found in your items';

  @override
  String get notFoundOnline => 'Not found online';

  @override
  String get fillManually => 'Fill manually';

  @override
  String get itemFound => 'Item found';

  @override
  String get addToItems => 'Add to my items';

  @override
  String get addToCurrentList => 'Add to current list';

  @override
  String get backupCreated => 'Backup created';

  @override
  String get restoreComplete => 'Restore complete';

  @override
  String get restoreFailed => 'Restore failed';

  @override
  String get selectBackupItems => 'Select what to restore';

  @override
  String get importComplete => 'Import complete';

  @override
  String get importFailed => 'Import failed';

  @override
  String get noInternet => 'No internet connection';

  @override
  String get permissionDenied => 'Permission denied';

  @override
  String get cameraPermissionRequired =>
      'Camera permission is required to scan barcodes';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get exportItems => 'Export Items';

  @override
  String get exportList => 'Export List';

  @override
  String get exportStores => 'Export Stores';

  @override
  String get listName => 'List Name';

  @override
  String get storeName => 'Store Name';

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
  String listsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lists',
      one: '1 list',
      zero: 'No lists',
    );
    return '$_temp0';
  }

  @override
  String get welcome => 'Welcome to Bazaar';

  @override
  String get welcomeMessage => 'Your local shopping companion';

  @override
  String get changeUsername => 'Change username';

  @override
  String get currentCurrency => 'Current currency';

  @override
  String get currentLanguage => 'Current language';

  @override
  String get currentTheme => 'Current theme';

  @override
  String get dataManagement => 'Data Management';

  @override
  String get general => 'General';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';
}
