// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'بازار';

  @override
  String get appTagline => 'سوقك، بياناتك';

  @override
  String get tabHome => 'الرئيسية';

  @override
  String get tabItems => 'الأصناف';

  @override
  String get tabLists => 'القوائم';

  @override
  String get tabStores => 'المتاجر';

  @override
  String get commonSave => 'حفظ';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonDelete => 'حذف';

  @override
  String get commonEdit => 'تعديل';

  @override
  String get commonAdd => 'إضافة';

  @override
  String get commonRemove => 'إزالة';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonSearch => 'بحث';

  @override
  String get commonTotal => 'الإجمالي';

  @override
  String get commonClose => 'إغلاق';

  @override
  String get commonConfirm => 'تأكيد';

  @override
  String get commonOptional => 'اختياري';

  @override
  String get commonNone => 'بدون';

  @override
  String get commonYes => 'نعم';

  @override
  String get commonNo => 'لا';

  @override
  String get commonViewAll => 'عرض الكل';

  @override
  String get commonError => 'حدث خطأ ما';

  @override
  String get commonLoading => 'جارٍ التحميل…';

  @override
  String get commonUntitled => 'بدون عنوان';

  @override
  String get commonShare => 'مشاركة';

  @override
  String get commonExport => 'تصدير';

  @override
  String get commonImport => 'استيراد';

  @override
  String get commonCopy => 'نسخ';

  @override
  String get commonCopied => 'تم النسخ';

  @override
  String get commonOpenSettings => 'فتح الإعدادات';

  @override
  String get welcomeTitle => 'أهلاً بك في بازار';

  @override
  String get welcomeSubtitle =>
      'امسح الباركود وتتبّع الأسعار في مختلف المتاجر — وكل بياناتك محفوظة على جهازك فقط.';

  @override
  String get usernameField => 'اسمك';

  @override
  String get usernameRequired => 'الرجاء إدخال اسم للمتابعة';

  @override
  String get continueLabel => 'متابعة';

  @override
  String get privacyNote => 'بدون حساب. بدون خادم. بدون تتبع.';

  @override
  String get greetingMorning => 'صباح الخير';

  @override
  String get greetingAfternoon => 'مساء الخير';

  @override
  String get greetingEvening => 'طاب مساؤك';

  @override
  String get greetingNight => 'تصبح على خير';

  @override
  String get homeKpiLists => 'قوائم';

  @override
  String get homeKpiItems => 'أصناف';

  @override
  String get homeKpiStores => 'متاجر';

  @override
  String get homeRecentLists => 'أحدث القوائم';

  @override
  String get homeStoresByItems => 'المتاجر حسب عدد الأصناف';

  @override
  String get homeTopExpensive => 'أعلى الأصناف سعراً';

  @override
  String get homeCheapest => 'الأرخص';

  @override
  String get homeNoLists => 'لا توجد قوائم بعد';

  @override
  String get homeNoListsHint => 'أنشئ أول قائمة تسوق لك';

  @override
  String get homeNoItems => 'لا توجد أصناف بعد';

  @override
  String get homeNoItemsHint => 'امسح باركوداً أو أضف الأصناف يدوياً';

  @override
  String get homeNoStores => 'لا توجد متاجر بعد';

  @override
  String get homeNoStoresHint => 'أضف متاجر لتبدأ بتتبع الأسعار';

  @override
  String get homeCreateList => 'إنشاء قائمة';

  @override
  String get homeScanFirst => 'امسح أول باركود';

  @override
  String get itemsTitle => 'الأصناف';

  @override
  String get searchItems => 'ابحث في الأصناف…';

  @override
  String get addItem => 'إضافة صنف';

  @override
  String get editItem => 'تعديل الصنف';

  @override
  String get itemSaved => 'تم حفظ الصنف';

  @override
  String get itemDeleted => 'تم حذف الصنف';

  @override
  String get deleteItemTitle => 'حذف هذا الصنف؟';

  @override
  String deleteItemMessage(String name) {
    return 'سيتم حذف «$name» وسجل أسعاره. لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String get noItems => 'لا توجد أصناف بعد';

  @override
  String get noItemsHint => 'اضغط + لإضافة أول صنف';

  @override
  String get sortAndGroup => 'الترتيب والتجميع';

  @override
  String get sortBy => 'الترتيب حسب';

  @override
  String get sortNewest => 'الأحدث';

  @override
  String get sortName => 'الاسم';

  @override
  String get sortPriceHigh => 'السعر (الأعلى أولاً)';

  @override
  String get sortPriceLow => 'السعر (الأقل أولاً)';

  @override
  String get groupBy => 'التجميع حسب';

  @override
  String get groupNone => 'بدون تجميع';

  @override
  String get groupBrand => 'الماركة';

  @override
  String get groupCategory => 'الفئة';

  @override
  String get uncategorized => 'غير مصنّف';

  @override
  String get noBrand => 'بدون ماركة';

  @override
  String get generalTab => 'عام';

  @override
  String get pricesTab => 'الأسعار';

  @override
  String get historyTab => 'السجل';

  @override
  String get nameEnField => 'الاسم (إنجليزي)';

  @override
  String get nameArField => 'الاسم (عربي)';

  @override
  String get nameRequired => 'الاسم مطلوب';

  @override
  String get brandField => 'الماركة';

  @override
  String get noteField => 'ملاحظة';

  @override
  String get barcodeField => 'الباركود';

  @override
  String get scanBarcode => 'مسح الباركود';

  @override
  String get categoryField => 'الفئة';

  @override
  String get addCategory => 'إضافة فئة';

  @override
  String get categoryNameEn => 'اسم الفئة (إنجليزي)';

  @override
  String get categoryNameAr => 'اسم الفئة (عربي)';

  @override
  String get deleteCategoryTitle => 'حذف هذه الفئة؟';

  @override
  String get deleteCategoryMessage =>
      'ستصبح الأصناف فيها غير مصنّفة. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get imageField => 'الصورة';

  @override
  String get pickImage => 'اختيار من المعرض';

  @override
  String get imageUrlField => 'رابط الصورة';

  @override
  String get priceAtStores => 'الأسعار في المتاجر';

  @override
  String get addStorePrice => 'إضافة سعر في متجر';

  @override
  String get noStoresForPrice => 'أضف متجراً أولاً لتتبع أسعاره';

  @override
  String get priceHistory => 'سجل الأسعار';

  @override
  String get noPriceHistory => 'لا توجد تغييرات أسعار مسجلة بعد';

  @override
  String get priceInputHint => 'السعر';

  @override
  String get saveFailed => 'تعذّر الحفظ — حاول مجدداً';

  @override
  String get lookupMethod => 'طريقة البحث';

  @override
  String get listsTitle => 'قوائم التسوق';

  @override
  String get newList => 'قائمة جديدة';

  @override
  String get editList => 'تعديل القائمة';

  @override
  String get listNameField => 'اسم القائمة';

  @override
  String get listNameRequired => 'اسم القائمة مطلوب';

  @override
  String get noLists => 'لا توجد قوائم تسوق بعد';

  @override
  String get noListsHint => 'أنشئ قائمة لتبدأ التسوق';

  @override
  String get deleteListTitle => 'حذف هذه القائمة؟';

  @override
  String deleteListMessage(String name) {
    return 'سيتم حذف «$name» مع أصنافها. لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String get listItemAdded => 'تمت إضافة الصنف';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صنف',
      many: '$count صنفاً',
      few: '$count أصناف',
      two: 'صنفان',
      one: 'صنف واحد',
      zero: 'لا أصناف',
    );
    return '$_temp0';
  }

  @override
  String checkedCount(int count, int total) {
    return 'أنجزت $count من $total';
  }

  @override
  String get checkedTotal => 'الإجمالي (المشتراة)';

  @override
  String get listEmptyTitle => 'هذه القائمة فارغة';

  @override
  String get listEmptyHint => 'أضف أصنافاً من فهرسك أو امسح باركوداً';

  @override
  String get addFromCatalog => 'إضافة من الفهرس';

  @override
  String get scanNewItem => 'مسح باركود';

  @override
  String get searchItemsToAdd => 'ابحث في أصنافك…';

  @override
  String get noItemsToAdd => 'لا توجد أصناف مطابقة';

  @override
  String get quantity => 'الكمية';

  @override
  String get decreaseQuantity => 'إنقاص الكمية';

  @override
  String get increaseQuantity => 'زيادة الكمية';

  @override
  String get markChecked => 'تحديد كمشترى';

  @override
  String get preferredStore => 'المتجر المفضّل';

  @override
  String get noPreferredStore => 'تلقائي (الأرخص)';

  @override
  String get changeStore => 'تغيير المتجر';

  @override
  String get selectStore => 'اختر متجراً';

  @override
  String get removeFromList => 'إزالة من القائمة';

  @override
  String get itemRemovedFromList => 'تمت الإزالة من القائمة';

  @override
  String get storesTitle => 'المتاجر';

  @override
  String get newStore => 'متجر جديد';

  @override
  String get editStore => 'تعديل المتجر';

  @override
  String get storeNameField => 'اسم المتجر';

  @override
  String get storeNameArField => 'اسم المتجر (عربي)';

  @override
  String get storeNameRequired => 'اسم المتجر مطلوب';

  @override
  String get websiteField => 'الموقع الإلكتروني';

  @override
  String get addressField => 'العنوان';

  @override
  String get noStores => 'لا توجد متاجر بعد';

  @override
  String get noStoresHint => 'أضف متجراً لتتبع الأسعار';

  @override
  String get deleteStoreTitle => 'حذف هذا المتجر؟';

  @override
  String deleteStoreMessage(String name) {
    return 'سيتم حذف «$name» مع أسعاره المسجلة. لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String get storeSaved => 'تم حفظ المتجر';

  @override
  String get storeDeleted => 'تم حذف المتجر';

  @override
  String get itemsAtStore => 'الأصناف في هذا المتجر';

  @override
  String get noItemsAtStore => 'لا توجد أصناف مرتبطة بهذا المتجر بعد';

  @override
  String get defaultStoreName => 'افتراضي';

  @override
  String get scannerTitle => 'مسح الباركود';

  @override
  String get scanning => 'جارٍ المسح…';

  @override
  String get cameraPermissionRequired => 'إذن الكاميرا مطلوب لمسح الباركود';

  @override
  String get enterManually => 'إدخال يدوي';

  @override
  String get barcodeManualInput => 'رقم الباركود';

  @override
  String get scanResultFoundLocally => 'موجود في أصنافك';

  @override
  String get scanResultFoundOnline => 'وُجد إلكترونياً';

  @override
  String get scanResultNotFound => 'لم يُعثر عليه';

  @override
  String get scanResultNotFoundHint =>
      'هذا الباركود ليس في أصنافك ولم يُعثر عليه إلكترونياً. يمكنك إدخال التفاصيل يدوياً.';

  @override
  String get lookupSource => 'مصدر البحث';

  @override
  String get sourceAuto => 'تلقائي (كل المصادر)';

  @override
  String get sourceOpenFoodFacts => 'أوبن فود فاكتس';

  @override
  String get sourceSearxng => 'سيركس إن جي';

  @override
  String get lookingUp => 'جارٍ البحث…';

  @override
  String get searchingOnline => 'جارٍ البحث إلكترونياً…';

  @override
  String get fillManually => 'إدخال يدوي';

  @override
  String get addToItems => 'إضافة إلى الأصناف';

  @override
  String get addToList => 'إضافة إلى القائمة';

  @override
  String foundAtSource(String source) {
    return 'المصدر: $source';
  }

  @override
  String get noPriceFound =>
      'لم يُعثر على سعر إلكترونياً — يمكنك إضافته يدوياً في أي متجر';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsGeneral => 'عام';

  @override
  String get settingsSearch => 'البحث والذكاء الاصطناعي';

  @override
  String get settingsData => 'البيانات';

  @override
  String get settingsAbout => 'حول';

  @override
  String get username => 'اسم المستخدم';

  @override
  String get changeUsername => 'تغيير اسم المستخدم';

  @override
  String get language => 'اللغة';

  @override
  String get theme => 'المظهر';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get themeSystem => 'النظام';

  @override
  String get currency => 'العملة';

  @override
  String get sarCurrency => 'ريال سعودي (SAR)';

  @override
  String get usdCurrency => 'دولار أمريكي (USD)';

  @override
  String get manageCategories => 'الفئات';

  @override
  String get searchAndAiTitle => 'البحث والذكاء الاصطناعي';

  @override
  String get searchAndAiHint => 'اضبط كيفية عمل البحث الإلكتروني عن الباركود';

  @override
  String get configComplete => 'جاهز';

  @override
  String get configIncomplete => 'يحتاج إعداداً';

  @override
  String get extractionStrategy => 'استراتيجية الاستخراج';

  @override
  String get strategySchemaOnly => 'البنية فقط (سريع ومجاني)';

  @override
  String get strategySchemaCloud => 'البنية ← LLM سحابي';

  @override
  String get strategySchemaOnDevice => 'البنية ← LLM محلي';

  @override
  String get strategySchemaCloudOnDevice => 'البنية ← سحابي ← محلي';

  @override
  String get strategyCloudOnly => 'LLM سحابي فقط';

  @override
  String get strategyOnDeviceOnly => 'LLM محلي فقط';

  @override
  String get strategyHint =>
      'يقرأ تحليل البنية بيانات المنتج المهيكلة مباشرة من صفحات المتاجر، وتكمل طبقات الذكاء الاصطناعي الحقول الناقصة.';

  @override
  String get cloudProvider => 'المزوّد السحابي';

  @override
  String get providerGemini => 'جوجل جيميناي';

  @override
  String get providerOpenai => 'متوافق مع OpenAI';

  @override
  String get providerGroq => 'جروك';

  @override
  String get providerCerebras => 'سيريبراس';

  @override
  String get providerOllama => 'أولاما (محلي)';

  @override
  String get apiKeyField => 'مفتاح الـ API';

  @override
  String get apiKeySet => 'المفتاح محفوظ';

  @override
  String get apiKeyMissing => 'لا يوجد مفتاح';

  @override
  String get apiKeyHint => 'يُحفظ في التخزين الآمن لجهازك — لا يُرسل أبداً';

  @override
  String get modelField => 'الموديل';

  @override
  String get modelHint => 'اتركه فارغاً لاستخدام الافتراضي';

  @override
  String get baseUrlField => 'العنوان الأساسي';

  @override
  String get searxngUrlField => 'عنوان خادم SearXNG';

  @override
  String get searxngUrlHint =>
      'نسختك الذاتية الاستضافة من SearXNG (مع تفعيل صيغة JSON)';

  @override
  String get invalidUrl => 'أدخل عنوان http(s) صالحاً';

  @override
  String get onDeviceModels => 'الموديل المحلي';

  @override
  String get onDeviceHint =>
      'يعمل دون إنترنت بالكامل على هذا الجهاز. حجم التحميل كبير.';

  @override
  String get downloadModel => 'تحميل';

  @override
  String downloadingModel(int percent) {
    return 'جارٍ التحميل… $percent%';
  }

  @override
  String get deleteModel => 'حذف الموديل';

  @override
  String get modelDownloaded => 'تم التحميل';

  @override
  String get modelNotDownloaded => 'لم يتم التحميل';

  @override
  String get autoloadOnDevice => 'تحميل الموديل تلقائياً عند بدء التطبيق';

  @override
  String get forgetAllKeys => 'نسيان جميع المفاتيح';

  @override
  String get forgetAllKeysConfirm =>
      'حذف جميع مفاتيح الـ API المحفوظة ومسار الموديل المحلي؟';

  @override
  String get keysForgotten => 'تمت إزالة جميع المفاتيح';

  @override
  String get pipelineDebugger => 'مُنقّح خط المعالجة';

  @override
  String get pipelineDebuggerHint =>
      'شغّل باركوداً عبر كل طبقات البحث وافحص ما أرجعته كل طبقة';

  @override
  String get runPipeline => 'تشغيل';

  @override
  String get pipelineBarcodeField => 'الباركود المطلوب اختباره';

  @override
  String get pipelineFinalResult => 'النتيجة النهائية';

  @override
  String get pipelineOpenInBrowser => 'مقارنة في المتصفح';

  @override
  String get statusSuccess => 'نجح';

  @override
  String get statusNoData => 'لا بيانات';

  @override
  String get statusFailed => 'فشل';

  @override
  String get statusSkipped => 'تخطّي';

  @override
  String get ollamaBaseUrlField => 'عنوان خادم أولاما';

  @override
  String get backupTitle => 'النسخ الاحتياطي والاستعادة';

  @override
  String get backupHint =>
      'نسخة احتياطية كاملة من الأصناف والمتاجر والقوائم والفئات وسجل الأسعار كملف ZIP يمكنك مشاركته أو الاحتفاظ به.';

  @override
  String get createBackup => 'إنشاء نسخة احتياطية';

  @override
  String get creatingBackup => 'جارٍ إنشاء النسخة الاحتياطية…';

  @override
  String get backupCreated => 'تم إنشاء النسخة الاحتياطية';

  @override
  String get backupFailed => 'فشل إنشاء النسخة الاحتياطية';

  @override
  String get backupPassphrase => 'عبارة تشفير النسخة';

  @override
  String get backupPassphraseHint => 'اتركها فارغة لنسخة غير مشفّرة';

  @override
  String get restoreBackup => 'استعادة من نسخة احتياطية';

  @override
  String get selectRestoreItems => 'اختر ما تريد استعادته';

  @override
  String get restoreItems => 'الأصناف';

  @override
  String get restoreStores => 'المتاجر';

  @override
  String get restoreLists => 'القوائم (مع أصنافها)';

  @override
  String get restore => 'استعادة';

  @override
  String restoreComplete(int items, int stores, int lists, int skipped) {
    return 'اكتملت الاستعادة: $items صنف، $stores متجر، $lists قائمة، $skipped متجاهَل';
  }

  @override
  String get restoreFailed => 'فشلت الاستعادة';

  @override
  String get backupEncryptedPrompt => 'هذه النسخة مشفّرة. أدخل عبارة التشفير:';

  @override
  String get wrongPassphrase => 'عبارة التشفير خاطئة أو النسخة تالفة';

  @override
  String get exportData => 'تصدير ومشاركة';

  @override
  String get exportItems => 'تصدير الأصناف';

  @override
  String get exportStores => 'تصدير المتاجر';

  @override
  String get exportList => 'تصدير القائمة';

  @override
  String get importData => 'استيراد ملف JSON';

  @override
  String importComplete(int count) {
    return 'تم استيراد $count صنف';
  }

  @override
  String get importFailed => 'فشل الاستيراد';

  @override
  String get importTooLarge => 'الملف كبير جداً';

  @override
  String get importUnknownType => 'صيغة ملف غير معروفة';

  @override
  String get aboutTitle => 'حول بازار';

  @override
  String get aboutVersion => 'الإصدار';

  @override
  String get aboutPrivacy =>
      'بلا خوادم. بلا حسابات. بلا تتبع. جميع البيانات في قاعدة بيانات محلية على هذا الجهاز.';

  @override
  String get aboutSource => 'الشيفرة المصدرية';

  @override
  String get aboutLicense => 'منشور تحت رخصة MIT.';

  @override
  String get errorNoInternet => 'لا يوجد اتصال بالإنترنت';

  @override
  String get errorLookupFailed => 'فشل البحث';
}
