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
  String get tabItems => 'المنتجات';

  @override
  String get tabLists => 'قوائم التسوق';

  @override
  String get tabStores => 'المتاجر';

  @override
  String get addItem => 'إضافة منتج';

  @override
  String get editItem => 'تعديل المنتج';

  @override
  String get deleteItem => 'حذف المنتج';

  @override
  String get barcode => 'الباركود';

  @override
  String get scanBarcode => 'مسح الباركود';

  @override
  String get searchOnline => 'بحث على الإنترنت';

  @override
  String get price => 'السعر';

  @override
  String get store => 'المتجر';

  @override
  String get stores => 'المتاجر';

  @override
  String get currency => 'العملة';

  @override
  String get lightTheme => 'فاتح';

  @override
  String get darkTheme => 'داكن';

  @override
  String get backup => 'نسخ احتياطي';

  @override
  String get restore => 'استعادة';

  @override
  String get share => 'مشاركة';

  @override
  String get importData => 'استيراد';

  @override
  String get username => 'اسم المستخدم';

  @override
  String get enterUsername => 'أدخل اسمك للمتابعة';

  @override
  String get continueLabel => 'متابعة';

  @override
  String get sarCurrency => 'ريال سعودي (﷼)';

  @override
  String get usdCurrency => 'دولار أمريكي (\$)';

  @override
  String get quantity => 'الكمية';

  @override
  String get checked => 'تم';

  @override
  String get note => 'ملاحظة';

  @override
  String get searchBarcode => 'ابحث عن الباركود على الإنترنت';

  @override
  String get addList => 'قائمة جديدة';

  @override
  String get editList => 'تعديل القائمة';

  @override
  String get addStore => 'متجر جديد';

  @override
  String get editStore => 'تعديل المتجر';

  @override
  String get nameEn => 'الاسم (إنجليزي)';

  @override
  String get nameAr => 'الاسم (عربي)';

  @override
  String get website => 'الموقع الإلكتروني';

  @override
  String get settings => 'الإعدادات';

  @override
  String get language => 'اللغة';

  @override
  String get theme => 'السمة';

  @override
  String get selectCurrency => 'اختر العملة';

  @override
  String get english => 'English';

  @override
  String get arabic => 'العربية';

  @override
  String get noItems => 'لا توجد منتجات بعد';

  @override
  String get noItemsHint => 'اضغط على زر + لإضافة أول منتج';

  @override
  String get noLists => 'لا توجد قوائم تسوق بعد';

  @override
  String get noListsHint => 'أنشئ قائمة لبدء التسوق';

  @override
  String get noStores => 'لا توجد متاجر بعد';

  @override
  String get noStoresHint => 'أضف متجراً لتتبع الأسعار';

  @override
  String get total => 'الإجمالي';

  @override
  String get totalChecked => 'الإجمالي (المحدد)';

  @override
  String get addItemToList => 'أضف منتجاً إلى القائمة';

  @override
  String get preferredStore => 'المتجر المفضل';

  @override
  String get search => 'بحث';

  @override
  String get searchItems => 'ابحث عن منتجات...';

  @override
  String get cancel => 'إلغاء';

  @override
  String get save => 'حفظ';

  @override
  String get delete => 'حذف';

  @override
  String get confirmDelete => 'تأكيد الحذف؟';

  @override
  String get confirmDeleteMessage => 'لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get scanning => 'جاري المسح...';

  @override
  String get lookingUp => 'جاري البحث عن الباركود...';

  @override
  String get searchingOnline => 'جاري البحث عبر الإنترنت...';

  @override
  String get foundInLocal => 'وُجد في منتجاتك';

  @override
  String get notFoundOnline => 'غير موجود على الإنترنت';

  @override
  String get fillManually => 'أدخل يدوياً';

  @override
  String get itemFound => 'تم العثور على المنتج';

  @override
  String get addToItems => 'أضف إلى منتجاتي';

  @override
  String get addToCurrentList => 'أضف إلى القائمة الحالية';

  @override
  String get backupCreated => 'تم إنشاء النسخة الاحتياطية';

  @override
  String get restoreComplete => 'اكتملت الاستعادة';

  @override
  String get restoreFailed => 'فشلت الاستعادة';

  @override
  String get selectBackupItems => 'اختر ما تريد استعادته';

  @override
  String get importComplete => 'اكتمل الاستيراد';

  @override
  String get importFailed => 'فشل الاستيراد';

  @override
  String get noInternet => 'لا يوجد اتصال بالإنترنت';

  @override
  String get permissionDenied => 'تم رفض الإذن';

  @override
  String get cameraPermissionRequired => 'يلزم إذن الكاميرا لمسح الباركود';

  @override
  String get openSettings => 'افتح الإعدادات';

  @override
  String get exportItems => 'تصدير المنتجات';

  @override
  String get exportList => 'تصدير القائمة';

  @override
  String get exportStores => 'تصدير المتاجر';

  @override
  String get listName => 'اسم القائمة';

  @override
  String get storeName => 'اسم المتجر';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منتج',
      many: '$count منتجاً',
      few: '$count منتجات',
      two: 'منتجان',
      one: 'منتج واحد',
      zero: 'لا توجد منتجات',
    );
    return '$_temp0';
  }

  @override
  String listsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قائمة',
      many: '$count قائمة',
      few: '$count قوائم',
      two: 'قائمتان',
      one: 'قائمة واحدة',
      zero: 'لا توجد قوائم',
    );
    return '$_temp0';
  }

  @override
  String get welcome => 'مرحباً بك في بازار';

  @override
  String get welcomeMessage => 'رفيقك للتسوق المحلي';

  @override
  String get changeUsername => 'تغيير اسم المستخدم';

  @override
  String get currentCurrency => 'العملة الحالية';

  @override
  String get currentLanguage => 'اللغة الحالية';

  @override
  String get currentTheme => 'السمة الحالية';

  @override
  String get dataManagement => 'إدارة البيانات';

  @override
  String get general => 'عام';

  @override
  String get about => 'حول';

  @override
  String get version => 'الإصدار';
}
