import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ar'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Bazaar'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Your market, your data'**
  String get appTagline;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get tabItems;

  /// No description provided for @tabLists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get tabLists;

  /// No description provided for @tabStores.
  ///
  /// In en, this message translates to:
  /// **'Stores'**
  String get tabStores;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get commonTotal;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonOptional.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get commonOptional;

  /// No description provided for @commonNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonNone;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get commonViewAll;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonError;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get commonUntitled;

  /// No description provided for @commonShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// No description provided for @commonExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get commonExport;

  /// No description provided for @commonImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get commonImport;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get commonCopied;

  /// No description provided for @commonOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get commonOpenSettings;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Bazaar'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan barcodes, track prices across stores — all stored on your device only.'**
  String get welcomeSubtitle;

  /// No description provided for @usernameField.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get usernameField;

  /// No description provided for @usernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name to continue'**
  String get usernameRequired;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @privacyNote.
  ///
  /// In en, this message translates to:
  /// **'No account. No server. No telemetry.'**
  String get privacyNote;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get greetingEvening;

  /// No description provided for @greetingNight.
  ///
  /// In en, this message translates to:
  /// **'Good night'**
  String get greetingNight;

  /// No description provided for @homeKpiLists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get homeKpiLists;

  /// No description provided for @homeKpiItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get homeKpiItems;

  /// No description provided for @homeKpiStores.
  ///
  /// In en, this message translates to:
  /// **'Stores'**
  String get homeKpiStores;

  /// No description provided for @homeRecentLists.
  ///
  /// In en, this message translates to:
  /// **'Recent lists'**
  String get homeRecentLists;

  /// No description provided for @homeStoresByItems.
  ///
  /// In en, this message translates to:
  /// **'Stores by item count'**
  String get homeStoresByItems;

  /// No description provided for @homeTopExpensive.
  ///
  /// In en, this message translates to:
  /// **'Most expensive items'**
  String get homeTopExpensive;

  /// No description provided for @homeCheapest.
  ///
  /// In en, this message translates to:
  /// **'Cheapest'**
  String get homeCheapest;

  /// No description provided for @homeNoLists.
  ///
  /// In en, this message translates to:
  /// **'No lists yet'**
  String get homeNoLists;

  /// No description provided for @homeNoListsHint.
  ///
  /// In en, this message translates to:
  /// **'Create your first shopping list'**
  String get homeNoListsHint;

  /// No description provided for @homeNoItems.
  ///
  /// In en, this message translates to:
  /// **'No items yet'**
  String get homeNoItems;

  /// No description provided for @homeNoItemsHint.
  ///
  /// In en, this message translates to:
  /// **'Scan a barcode or add items manually'**
  String get homeNoItemsHint;

  /// No description provided for @homeNoStores.
  ///
  /// In en, this message translates to:
  /// **'No stores yet'**
  String get homeNoStores;

  /// No description provided for @homeNoStoresHint.
  ///
  /// In en, this message translates to:
  /// **'Add stores to start tracking prices'**
  String get homeNoStoresHint;

  /// No description provided for @homeCreateList.
  ///
  /// In en, this message translates to:
  /// **'Create a list'**
  String get homeCreateList;

  /// No description provided for @homeScanFirst.
  ///
  /// In en, this message translates to:
  /// **'Scan your first barcode'**
  String get homeScanFirst;

  /// No description provided for @itemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get itemsTitle;

  /// No description provided for @searchItems.
  ///
  /// In en, this message translates to:
  /// **'Search items…'**
  String get searchItems;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get addItem;

  /// No description provided for @editItem.
  ///
  /// In en, this message translates to:
  /// **'Edit item'**
  String get editItem;

  /// No description provided for @itemSaved.
  ///
  /// In en, this message translates to:
  /// **'Item saved'**
  String get itemSaved;

  /// No description provided for @itemDeleted.
  ///
  /// In en, this message translates to:
  /// **'Item deleted'**
  String get itemDeleted;

  /// No description provided for @deleteItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this item?'**
  String get deleteItemTitle;

  /// No description provided for @deleteItemMessage.
  ///
  /// In en, this message translates to:
  /// **'“{name}” and its price history will be removed. This cannot be undone.'**
  String deleteItemMessage(String name);

  /// No description provided for @noItems.
  ///
  /// In en, this message translates to:
  /// **'No items yet'**
  String get noItems;

  /// No description provided for @noItemsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add your first item'**
  String get noItemsHint;

  /// No description provided for @sortAndGroup.
  ///
  /// In en, this message translates to:
  /// **'Sort & group'**
  String get sortAndGroup;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get sortNewest;

  /// No description provided for @sortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortName;

  /// No description provided for @sortPriceHigh.
  ///
  /// In en, this message translates to:
  /// **'Price (high → low)'**
  String get sortPriceHigh;

  /// No description provided for @sortPriceLow.
  ///
  /// In en, this message translates to:
  /// **'Price (low → high)'**
  String get sortPriceLow;

  /// No description provided for @groupBy.
  ///
  /// In en, this message translates to:
  /// **'Group by'**
  String get groupBy;

  /// No description provided for @groupNone.
  ///
  /// In en, this message translates to:
  /// **'No grouping'**
  String get groupNone;

  /// No description provided for @groupBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get groupBrand;

  /// No description provided for @groupCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get groupCategory;

  /// No description provided for @uncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get uncategorized;

  /// No description provided for @noBrand.
  ///
  /// In en, this message translates to:
  /// **'No brand'**
  String get noBrand;

  /// No description provided for @generalTab.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get generalTab;

  /// No description provided for @pricesTab.
  ///
  /// In en, this message translates to:
  /// **'Prices'**
  String get pricesTab;

  /// No description provided for @historyTab.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTab;

  /// No description provided for @nameEnField.
  ///
  /// In en, this message translates to:
  /// **'Name (English)'**
  String get nameEnField;

  /// No description provided for @nameArField.
  ///
  /// In en, this message translates to:
  /// **'Name (Arabic)'**
  String get nameArField;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'A name is required'**
  String get nameRequired;

  /// No description provided for @brandField.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get brandField;

  /// No description provided for @noteField.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get noteField;

  /// No description provided for @barcodeField.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get barcodeField;

  /// No description provided for @scanBarcode.
  ///
  /// In en, this message translates to:
  /// **'Scan barcode'**
  String get scanBarcode;

  /// No description provided for @categoryField.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryField;

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get addCategory;

  /// No description provided for @categoryNameEn.
  ///
  /// In en, this message translates to:
  /// **'Category name (English)'**
  String get categoryNameEn;

  /// No description provided for @categoryNameAr.
  ///
  /// In en, this message translates to:
  /// **'Category name (Arabic)'**
  String get categoryNameAr;

  /// No description provided for @deleteCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this category?'**
  String get deleteCategoryTitle;

  /// No description provided for @deleteCategoryMessage.
  ///
  /// In en, this message translates to:
  /// **'Items in it will become uncategorized. This cannot be undone.'**
  String get deleteCategoryMessage;

  /// No description provided for @imageField.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get imageField;

  /// No description provided for @pickImage.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get pickImage;

  /// No description provided for @imageUrlField.
  ///
  /// In en, this message translates to:
  /// **'Image URL'**
  String get imageUrlField;

  /// No description provided for @priceAtStores.
  ///
  /// In en, this message translates to:
  /// **'Prices at stores'**
  String get priceAtStores;

  /// No description provided for @addStorePrice.
  ///
  /// In en, this message translates to:
  /// **'Add a store price'**
  String get addStorePrice;

  /// No description provided for @noStoresForPrice.
  ///
  /// In en, this message translates to:
  /// **'Add a store first to track its prices'**
  String get noStoresForPrice;

  /// No description provided for @priceHistory.
  ///
  /// In en, this message translates to:
  /// **'Price history'**
  String get priceHistory;

  /// No description provided for @noPriceHistory.
  ///
  /// In en, this message translates to:
  /// **'No price changes recorded yet'**
  String get noPriceHistory;

  /// No description provided for @priceInputHint.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get priceInputHint;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save — try again'**
  String get saveFailed;

  /// No description provided for @lookupMethod.
  ///
  /// In en, this message translates to:
  /// **'Lookup method'**
  String get lookupMethod;

  /// No description provided for @listsTitle.
  ///
  /// In en, this message translates to:
  /// **'Shopping lists'**
  String get listsTitle;

  /// No description provided for @newList.
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get newList;

  /// No description provided for @editList.
  ///
  /// In en, this message translates to:
  /// **'Edit list'**
  String get editList;

  /// No description provided for @listNameField.
  ///
  /// In en, this message translates to:
  /// **'List name'**
  String get listNameField;

  /// No description provided for @listNameRequired.
  ///
  /// In en, this message translates to:
  /// **'A list name is required'**
  String get listNameRequired;

  /// No description provided for @noLists.
  ///
  /// In en, this message translates to:
  /// **'No shopping lists yet'**
  String get noLists;

  /// No description provided for @noListsHint.
  ///
  /// In en, this message translates to:
  /// **'Create a list to start shopping'**
  String get noListsHint;

  /// No description provided for @deleteListTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this list?'**
  String get deleteListTitle;

  /// No description provided for @deleteListMessage.
  ///
  /// In en, this message translates to:
  /// **'“{name}” and its items will be removed. This cannot be undone.'**
  String deleteListMessage(String name);

  /// No description provided for @listItemAdded.
  ///
  /// In en, this message translates to:
  /// **'Item added'**
  String get listItemAdded;

  /// No description provided for @itemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No items} =1{1 item} other{{count} items}}'**
  String itemsCount(int count);

  /// No description provided for @checkedCount.
  ///
  /// In en, this message translates to:
  /// **'{count}/{total} done'**
  String checkedCount(int count, int total);

  /// No description provided for @checkedTotal.
  ///
  /// In en, this message translates to:
  /// **'Total (checked)'**
  String get checkedTotal;

  /// No description provided for @listEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'This list is empty'**
  String get listEmptyTitle;

  /// No description provided for @listEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Add items from your catalog or scan a barcode'**
  String get listEmptyHint;

  /// No description provided for @addFromCatalog.
  ///
  /// In en, this message translates to:
  /// **'Add from catalog'**
  String get addFromCatalog;

  /// No description provided for @scanNewItem.
  ///
  /// In en, this message translates to:
  /// **'Scan barcode'**
  String get scanNewItem;

  /// No description provided for @searchItemsToAdd.
  ///
  /// In en, this message translates to:
  /// **'Search your items…'**
  String get searchItemsToAdd;

  /// No description provided for @noItemsToAdd.
  ///
  /// In en, this message translates to:
  /// **'No matching items'**
  String get noItemsToAdd;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get quantity;

  /// No description provided for @decreaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Decrease quantity'**
  String get decreaseQuantity;

  /// No description provided for @increaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Increase quantity'**
  String get increaseQuantity;

  /// No description provided for @markChecked.
  ///
  /// In en, this message translates to:
  /// **'Mark as bought'**
  String get markChecked;

  /// No description provided for @preferredStore.
  ///
  /// In en, this message translates to:
  /// **'Preferred store'**
  String get preferredStore;

  /// No description provided for @noPreferredStore.
  ///
  /// In en, this message translates to:
  /// **'Auto (cheapest)'**
  String get noPreferredStore;

  /// No description provided for @changeStore.
  ///
  /// In en, this message translates to:
  /// **'Change store'**
  String get changeStore;

  /// No description provided for @selectStore.
  ///
  /// In en, this message translates to:
  /// **'Select store'**
  String get selectStore;

  /// No description provided for @removeFromList.
  ///
  /// In en, this message translates to:
  /// **'Remove from list'**
  String get removeFromList;

  /// No description provided for @itemRemovedFromList.
  ///
  /// In en, this message translates to:
  /// **'Removed from list'**
  String get itemRemovedFromList;

  /// No description provided for @storesTitle.
  ///
  /// In en, this message translates to:
  /// **'Stores'**
  String get storesTitle;

  /// No description provided for @newStore.
  ///
  /// In en, this message translates to:
  /// **'New store'**
  String get newStore;

  /// No description provided for @editStore.
  ///
  /// In en, this message translates to:
  /// **'Edit store'**
  String get editStore;

  /// No description provided for @storeNameField.
  ///
  /// In en, this message translates to:
  /// **'Store name'**
  String get storeNameField;

  /// No description provided for @storeNameArField.
  ///
  /// In en, this message translates to:
  /// **'Store name (Arabic)'**
  String get storeNameArField;

  /// No description provided for @storeNameRequired.
  ///
  /// In en, this message translates to:
  /// **'A store name is required'**
  String get storeNameRequired;

  /// No description provided for @websiteField.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get websiteField;

  /// No description provided for @addressField.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get addressField;

  /// No description provided for @noStores.
  ///
  /// In en, this message translates to:
  /// **'No stores yet'**
  String get noStores;

  /// No description provided for @noStoresHint.
  ///
  /// In en, this message translates to:
  /// **'Add a store to track prices'**
  String get noStoresHint;

  /// No description provided for @deleteStoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this store?'**
  String get deleteStoreTitle;

  /// No description provided for @deleteStoreMessage.
  ///
  /// In en, this message translates to:
  /// **'“{name}” and its recorded prices will be removed. This cannot be undone.'**
  String deleteStoreMessage(String name);

  /// No description provided for @storeSaved.
  ///
  /// In en, this message translates to:
  /// **'Store saved'**
  String get storeSaved;

  /// No description provided for @storeDeleted.
  ///
  /// In en, this message translates to:
  /// **'Store deleted'**
  String get storeDeleted;

  /// No description provided for @itemsAtStore.
  ///
  /// In en, this message translates to:
  /// **'Items at this store'**
  String get itemsAtStore;

  /// No description provided for @noItemsAtStore.
  ///
  /// In en, this message translates to:
  /// **'No items linked to this store yet'**
  String get noItemsAtStore;

  /// No description provided for @defaultStoreName.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultStoreName;

  /// No description provided for @scannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan barcode'**
  String get scannerTitle;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get scanning;

  /// No description provided for @cameraPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required to scan barcodes'**
  String get cameraPermissionRequired;

  /// No description provided for @enterManually.
  ///
  /// In en, this message translates to:
  /// **'Type it instead'**
  String get enterManually;

  /// No description provided for @barcodeManualInput.
  ///
  /// In en, this message translates to:
  /// **'Barcode number'**
  String get barcodeManualInput;

  /// No description provided for @scanResultFoundLocally.
  ///
  /// In en, this message translates to:
  /// **'Already in your items'**
  String get scanResultFoundLocally;

  /// No description provided for @scanResultFoundOnline.
  ///
  /// In en, this message translates to:
  /// **'Found online'**
  String get scanResultFoundOnline;

  /// No description provided for @scanResultNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get scanResultNotFound;

  /// No description provided for @scanResultNotFoundHint.
  ///
  /// In en, this message translates to:
  /// **'This barcode isn\'t in your items and couldn\'t be found online. You can fill the details manually.'**
  String get scanResultNotFoundHint;

  /// No description provided for @lookupSource.
  ///
  /// In en, this message translates to:
  /// **'Lookup source'**
  String get lookupSource;

  /// No description provided for @sourceAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto (all sources)'**
  String get sourceAuto;

  /// No description provided for @sourceOpenFoodFacts.
  ///
  /// In en, this message translates to:
  /// **'Open Food Facts'**
  String get sourceOpenFoodFacts;

  /// No description provided for @sourceSearxng.
  ///
  /// In en, this message translates to:
  /// **'SearXNG'**
  String get sourceSearxng;

  /// No description provided for @lookingUp.
  ///
  /// In en, this message translates to:
  /// **'Looking up…'**
  String get lookingUp;

  /// No description provided for @searchingOnline.
  ///
  /// In en, this message translates to:
  /// **'Searching online…'**
  String get searchingOnline;

  /// No description provided for @fillManually.
  ///
  /// In en, this message translates to:
  /// **'Fill manually'**
  String get fillManually;

  /// No description provided for @addToItems.
  ///
  /// In en, this message translates to:
  /// **'Add to items'**
  String get addToItems;

  /// No description provided for @addToList.
  ///
  /// In en, this message translates to:
  /// **'Add to list'**
  String get addToList;

  /// No description provided for @foundAtSource.
  ///
  /// In en, this message translates to:
  /// **'Source: {source}'**
  String foundAtSource(String source);

  /// No description provided for @noPriceFound.
  ///
  /// In en, this message translates to:
  /// **'No price found online — you can add it manually at any store'**
  String get noPriceFound;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsSearch.
  ///
  /// In en, this message translates to:
  /// **'Search & AI'**
  String get settingsSearch;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsData;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @changeUsername.
  ///
  /// In en, this message translates to:
  /// **'Change username'**
  String get changeUsername;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @sarCurrency.
  ///
  /// In en, this message translates to:
  /// **'Saudi Riyal (SAR)'**
  String get sarCurrency;

  /// No description provided for @usdCurrency.
  ///
  /// In en, this message translates to:
  /// **'US Dollar (USD)'**
  String get usdCurrency;

  /// No description provided for @manageCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get manageCategories;

  /// No description provided for @searchAndAiTitle.
  ///
  /// In en, this message translates to:
  /// **'Search & AI'**
  String get searchAndAiTitle;

  /// No description provided for @searchAndAiHint.
  ///
  /// In en, this message translates to:
  /// **'Configure how online barcode lookups work'**
  String get searchAndAiHint;

  /// No description provided for @configComplete.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get configComplete;

  /// No description provided for @configIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Needs configuration'**
  String get configIncomplete;

  /// No description provided for @extractionStrategy.
  ///
  /// In en, this message translates to:
  /// **'Extraction strategy'**
  String get extractionStrategy;

  /// No description provided for @strategySchemaOnly.
  ///
  /// In en, this message translates to:
  /// **'Schema only (fast, free)'**
  String get strategySchemaOnly;

  /// No description provided for @strategySchemaCloud.
  ///
  /// In en, this message translates to:
  /// **'Schema → Cloud LLM'**
  String get strategySchemaCloud;

  /// No description provided for @strategySchemaOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Schema → On-device LLM'**
  String get strategySchemaOnDevice;

  /// No description provided for @strategySchemaCloudOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Schema → Cloud → On-device'**
  String get strategySchemaCloudOnDevice;

  /// No description provided for @strategyCloudOnly.
  ///
  /// In en, this message translates to:
  /// **'Cloud LLM only'**
  String get strategyCloudOnly;

  /// No description provided for @strategyOnDeviceOnly.
  ///
  /// In en, this message translates to:
  /// **'On-device LLM only'**
  String get strategyOnDeviceOnly;

  /// No description provided for @strategyHint.
  ///
  /// In en, this message translates to:
  /// **'Schema parsing reads structured product data directly from store pages. LLM tiers fill in missing fields.'**
  String get strategyHint;

  /// No description provided for @cloudProvider.
  ///
  /// In en, this message translates to:
  /// **'Cloud provider'**
  String get cloudProvider;

  /// No description provided for @providerGemini.
  ///
  /// In en, this message translates to:
  /// **'Google Gemini'**
  String get providerGemini;

  /// No description provided for @providerOpenai.
  ///
  /// In en, this message translates to:
  /// **'OpenAI-compatible'**
  String get providerOpenai;

  /// No description provided for @providerGroq.
  ///
  /// In en, this message translates to:
  /// **'Groq'**
  String get providerGroq;

  /// No description provided for @providerCerebras.
  ///
  /// In en, this message translates to:
  /// **'Cerebras'**
  String get providerCerebras;

  /// No description provided for @providerOllama.
  ///
  /// In en, this message translates to:
  /// **'Ollama (self-hosted)'**
  String get providerOllama;

  /// No description provided for @apiKeyField.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get apiKeyField;

  /// No description provided for @apiKeySet.
  ///
  /// In en, this message translates to:
  /// **'Key saved'**
  String get apiKeySet;

  /// No description provided for @apiKeyMissing.
  ///
  /// In en, this message translates to:
  /// **'No key'**
  String get apiKeyMissing;

  /// No description provided for @apiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Stored in your device\'s secure storage — never uploaded'**
  String get apiKeyHint;

  /// No description provided for @modelField.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get modelField;

  /// No description provided for @modelHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for the default'**
  String get modelHint;

  /// No description provided for @baseUrlField.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get baseUrlField;

  /// No description provided for @searxngUrlField.
  ///
  /// In en, this message translates to:
  /// **'SearXNG server URL'**
  String get searxngUrlField;

  /// No description provided for @searxngUrlHint.
  ///
  /// In en, this message translates to:
  /// **'Your self-hosted SearXNG instance (JSON format enabled)'**
  String get searxngUrlHint;

  /// No description provided for @invalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid http(s) URL'**
  String get invalidUrl;

  /// No description provided for @onDeviceModels.
  ///
  /// In en, this message translates to:
  /// **'On-device model'**
  String get onDeviceModels;

  /// No description provided for @onDeviceHint.
  ///
  /// In en, this message translates to:
  /// **'Runs fully offline on this device. Large download.'**
  String get onDeviceHint;

  /// No description provided for @downloadModel.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadModel;

  /// No description provided for @downloadingModel.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String downloadingModel(int percent);

  /// No description provided for @deleteModel.
  ///
  /// In en, this message translates to:
  /// **'Delete model'**
  String get deleteModel;

  /// No description provided for @modelDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get modelDownloaded;

  /// No description provided for @modelNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded'**
  String get modelNotDownloaded;

  /// No description provided for @autoloadOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Load model automatically on app start'**
  String get autoloadOnDevice;

  /// No description provided for @forgetAllKeys.
  ///
  /// In en, this message translates to:
  /// **'Forget all keys'**
  String get forgetAllKeys;

  /// No description provided for @forgetAllKeysConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove all saved API keys and the on-device model path?'**
  String get forgetAllKeysConfirm;

  /// No description provided for @keysForgotten.
  ///
  /// In en, this message translates to:
  /// **'All keys removed'**
  String get keysForgotten;

  /// No description provided for @pipelineDebugger.
  ///
  /// In en, this message translates to:
  /// **'Pipeline debugger'**
  String get pipelineDebugger;

  /// No description provided for @pipelineDebuggerHint.
  ///
  /// In en, this message translates to:
  /// **'Run a barcode through every lookup tier and inspect what each one returned'**
  String get pipelineDebuggerHint;

  /// No description provided for @runPipeline.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get runPipeline;

  /// No description provided for @pipelineBarcodeField.
  ///
  /// In en, this message translates to:
  /// **'Barcode to test'**
  String get pipelineBarcodeField;

  /// No description provided for @pipelineFinalResult.
  ///
  /// In en, this message translates to:
  /// **'Final result'**
  String get pipelineFinalResult;

  /// No description provided for @pipelineOpenInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Compare in browser'**
  String get pipelineOpenInBrowser;

  /// No description provided for @statusSuccess.
  ///
  /// In en, this message translates to:
  /// **'success'**
  String get statusSuccess;

  /// No description provided for @statusNoData.
  ///
  /// In en, this message translates to:
  /// **'no data'**
  String get statusNoData;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get statusFailed;

  /// No description provided for @statusSkipped.
  ///
  /// In en, this message translates to:
  /// **'skipped'**
  String get statusSkipped;

  /// No description provided for @ollamaBaseUrlField.
  ///
  /// In en, this message translates to:
  /// **'Ollama base URL'**
  String get ollamaBaseUrlField;

  /// No description provided for @backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup & restore'**
  String get backupTitle;

  /// No description provided for @backupHint.
  ///
  /// In en, this message translates to:
  /// **'Full backup of items, stores, lists, categories and price history as a ZIP file you can share or keep.'**
  String get backupHint;

  /// No description provided for @createBackup.
  ///
  /// In en, this message translates to:
  /// **'Create backup'**
  String get createBackup;

  /// No description provided for @creatingBackup.
  ///
  /// In en, this message translates to:
  /// **'Creating backup…'**
  String get creatingBackup;

  /// No description provided for @backupCreated.
  ///
  /// In en, this message translates to:
  /// **'Backup created'**
  String get backupCreated;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup failed'**
  String get backupFailed;

  /// No description provided for @backupPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Encryption passphrase'**
  String get backupPassphrase;

  /// No description provided for @backupPassphraseHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for an unencrypted backup'**
  String get backupPassphraseHint;

  /// No description provided for @restoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get restoreBackup;

  /// No description provided for @selectRestoreItems.
  ///
  /// In en, this message translates to:
  /// **'Choose what to restore'**
  String get selectRestoreItems;

  /// No description provided for @restoreItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get restoreItems;

  /// No description provided for @restoreStores.
  ///
  /// In en, this message translates to:
  /// **'Stores'**
  String get restoreStores;

  /// No description provided for @restoreLists.
  ///
  /// In en, this message translates to:
  /// **'Lists (with their items)'**
  String get restoreLists;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @restoreComplete.
  ///
  /// In en, this message translates to:
  /// **'Restore complete: {items} items, {stores} stores, {lists} lists, {skipped} skipped'**
  String restoreComplete(int items, int stores, int lists, int skipped);

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed'**
  String get restoreFailed;

  /// No description provided for @backupEncryptedPrompt.
  ///
  /// In en, this message translates to:
  /// **'This backup is encrypted. Enter its passphrase:'**
  String get backupEncryptedPrompt;

  /// No description provided for @wrongPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Wrong passphrase or corrupted backup'**
  String get wrongPassphrase;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export & share'**
  String get exportData;

  /// No description provided for @exportItems.
  ///
  /// In en, this message translates to:
  /// **'Export items'**
  String get exportItems;

  /// No description provided for @exportStores.
  ///
  /// In en, this message translates to:
  /// **'Export stores'**
  String get exportStores;

  /// No description provided for @exportList.
  ///
  /// In en, this message translates to:
  /// **'Export list'**
  String get exportList;

  /// No description provided for @importData.
  ///
  /// In en, this message translates to:
  /// **'Import JSON file'**
  String get importData;

  /// No description provided for @importComplete.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} items'**
  String importComplete(int count);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get importFailed;

  /// No description provided for @importTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File is too large'**
  String get importTooLarge;

  /// No description provided for @importUnknownType.
  ///
  /// In en, this message translates to:
  /// **'Unrecognized file format'**
  String get importUnknownType;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About Bazaar'**
  String get aboutTitle;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersion;

  /// No description provided for @aboutPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Zero servers. Zero accounts. Zero telemetry. All data lives in a local database on this device.'**
  String get aboutPrivacy;

  /// No description provided for @aboutSource.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get aboutSource;

  /// No description provided for @aboutLicense.
  ///
  /// In en, this message translates to:
  /// **'Released under the MIT License.'**
  String get aboutLicense;

  /// No description provided for @errorNoInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get errorNoInternet;

  /// No description provided for @errorLookupFailed.
  ///
  /// In en, this message translates to:
  /// **'Lookup failed'**
  String get errorLookupFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
