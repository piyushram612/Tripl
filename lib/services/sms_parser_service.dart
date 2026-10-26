import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/parsed_sms_transaction.dart';
import '../models/transaction_model.dart';
import 'transaction_service.dart';

/// Service responsible for filtering, parsing, categorizing, and importing
/// financial SMS and bank transaction alerts.
class SmsParserService {
  static const MethodChannel _channel = MethodChannel('com.waypointlattice.tripl/sms');

  // ─────────────────────────────────────────────────────────────────────────
  // SENDER FILTERING
  // ─────────────────────────────────────────────────────────────────────────
  static final RegExp _phoneNumberRegex = RegExp(r'^\+?[\d\s\-()]{7,}$');
  static final RegExp _promotionalSuffixRegex = RegExp(r'-P$', caseSensitive: false);

  /// Cheap sender classification so personal chats and promotional (-P) SMS
  /// never become transactions.
  static bool isAllowedSmsSender(String? sender) {
    final s = sender?.trim() ?? '';
    if (s.isEmpty) return false;
    if (_phoneNumberRegex.hasMatch(s)) return false;
    if (_promotionalSuffixRegex.hasMatch(s)) return false;
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FINANCIAL KEYWORDS & REJECTION PATTERNS
  // ─────────────────────────────────────────────────────────────────────────
  static final List<RegExp> _financialKeywords = [
    r'\bdebited\b', r'\bdebit\b', r'\bcredited\b', r'\bcredit\b', r'\bspent\b', r'\bpaid\b',
    r'\btransferred\b', r'\bsent\b', r'\breceived\b', r'\brefunded\b', r'\bwithdrawn\b',
    r'\bdeposited\b', r'\bdeducted\b', r'\bsent you\b', r'\bpaid you\b',
    r'\bautopay\b', r'\bcharged\b', r'\bused\s+(?:for|at)\b', r'\bpurchase\b',
    r'\bmandate\s+executed\b', r'\btoll\s+plaza\b', r'\bint\.pd\b'
  ].map((p) => RegExp(p, caseSensitive: false)).toList();

  static final List<RegExp> _rejectPatterns = [
    r'\botp\b', r'\bdeclined\b', r'\bfailed\b',
    r'\btotal due\b', r'\bwill be debited\b', r'\bcollect request\b',
    r'\b\d+(?:\.\d+)?\s*(?:gb|mb|tb)\s+data\b',
    r'\bdata\s+(?:credited|added|pack|balance|quota|voucher|loan)\b',
    r'\b(?:vi|jio|airtel|bsnl)\s+a/c\b',
    r'\bvalidity\s*[:-]?\s*\d+\s*(?:days?|hrs?|hours?|months?)\b',
    r'\b(?:reward\s+points?|supercoins?|loyalty\s+points?)\s+(?:credited|added|expiring|worth)\b',
    r'\bonelink\.me\b'
  ].map((p) => RegExp(p, caseSensitive: false)).toList();

  static final RegExp _reversalPattern = RegExp(r'\breversed\b', caseSensitive: false);

  static final RegExp _creditPattern = RegExp(
    r'\b(credit|credited|received|refunded|deposited|added|sent you|paid you|transfer(?:red)? from|int\.pd|interest\s+credited)\b',
    caseSensitive: false,
  );

  static final RegExp _debitPattern = RegExp(
    r'\b(debit|debited|spent|paid(?!\s+you)|deducted|withdrawn|sent(?!\s+you)|transfer(?:red)? to|autopay|charged|used\s+(?:for|at)\s+(?:a\s+)?(?:transaction|purchase|payment)|purchase\s+of|mandate\s+executed)\b',
    caseSensitive: false,
  );

  static final RegExp _creditCardPattern = RegExp(
    r'\bcredit\s*(?:card|limit|line|bill)\b',
    caseSensitive: false,
  );

  static final RegExp _ccAccountDetectPattern = RegExp(
    r'\b(credit\s*card|cc\s+xx|cc\s+ending|onecard|slice\s*card|amex|american\s*express|lazypay|simpl)\b',
    caseSensitive: false,
  );

  static final RegExp _bankAccountOrDebitCardPattern = RegExp(
    r'\b(debit\s*card|atm\s*card|a/c|acct|savings|avl\s*bal|avail\s*bal|available\s*balance)\b',
    caseSensitive: false,
  );

  static final RegExp _ccLimitSignalPattern = RegExp(
    r'\b(?:avl|avail(?:able)?)\.?\s*(?:cr(?:edit)?\.?\s*)?(?:lmt|limit)\b',
    caseSensitive: false,
  );

  static final RegExp _ccBillPattern = RegExp(
    r'\b(credit\s*card\s*(?:no\.?\s*)?[*xX.]*\d*\s*(?:bill|payment|pmt|dues?|repayment)|cc\s*(?:bill\s*)?payment|billdesk\s*cc|(?:towards|for|repay(?:ment)?\s+of)\s+(?:your\s+)?(?:[a-z]+\s+){0,3}credit\s*card)\b',
    caseSensitive: false,
  );

  static final RegExp _selfTransferPattern = RegExp(
    r'\b(self\s*transfer|transfer(?:red)?\s+to\s+self|to\s+own\s+a/c|internal\s+transfer|auto[-\s]?sweep|sweep\s*(?:in|out)|linked\s+a/c)\b',
    caseSensitive: false,
  );

  static final RegExp _refundFlagPattern = RegExp(
    r'\b(refund(?:ed)?|cashback)\b',
    caseSensitive: false,
  );

  static final RegExp _promoPatterns = RegExp(
    r'\b(upgrade\s+today|recharge\s+(?:now|with|for)|plan|validity|per\s+day|days\b|pre-approved|apply\s+now|congrats|congratulations|exclusive\s+offer|special\s+offer|discount|flat\s+(?:rs|inr|₹)|free\s+trial|win\b|hurry|coupon|gift\s+card|promo\s+code|valid\s+till|dial\s+\*|unlimited\s+data|calls\s+for\s+just|bonus)\b',
    caseSensitive: false,
  );

  static final RegExp _bankIndicators = RegExp(
    r'\b(a/c|acct|account|vpa|upi\s*ref|rrn|txn|card\s+xx|avl\s+bal|avail\s+bal|balance|bank)\b',
    caseSensitive: false,
  );

  static final RegExp _disclaimerPattern = RegExp(
    r'\b(?:block\s*(?:a/c|card|upi)|if\s+not\s+(?:done|you|u)|call\s*[-:]?\s*\d+|sms\s+blk|not\s+(?:you|u)\s*\?).*$',
    caseSensitive: false,
    dotAll: true,
  );

  // ─────────────────────────────────────────────────────────────────────────
  // AMOUNT & BALANCE PATTERNS
  // ─────────────────────────────────────────────────────────────────────────
  static final List<RegExp> _amountPatterns = [
    RegExp(r'(?:inr|rs\.?|₹)\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:inr|rs\.?|₹)', caseSensitive: false),
    RegExp(r'(?:amount|amt|spent|paid|for|of|by)\s*(?:of)?\s*(?:inr|rs\.?|₹)?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
  ];

  static final RegExp _balancePattern = RegExp(
    r'(?:final balance|available balance|avail bal|avl bal|bal(?:ance)?)\s*(?:is|:|-)?\s*(?:rs\.?|inr|₹)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _availableLimitValuePattern = RegExp(
    r'\b(?:avl|avail(?:able)?)\.?\s*(?:cr(?:edit)?\.?\s*)?(?:lmt|limit)\b[^0-9]{0,14}([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _quotedNoteRegex = RegExp(r'["“]([^"”\n\r]{2,80})["”]');
  static final RegExp _prefixNoteRegex = RegExp(
    r'''(?:note\s*[:-]\s*|for\s+["']?)([^"'\n\r,]+)(?:["']|\s*(?:using|via|upi|ref|$))''',
    caseSensitive: false,
  );
  static final RegExp _systemNoiseRegex = RegExp(r'(upi ref|transaction id|paid using|bank account|google pay|\d{10,16})', caseSensitive: false);
  static final RegExp _digitOnlyRegex = RegExp(r'^\d{6,16}.*');
  static final RegExp _vpaCleanupRegex = RegExp(r'^(vpa|a/c|acct|upi|account)\s+', caseSensitive: false);
  static final RegExp _smsHeaderRegex = RegExp(r'^[a-z]{2}-[a-z0-9]{4,8}(?:-[a-z0-9]+)?$', caseSensitive: false);
  static final RegExp _bankHeaderRegex = RegExp(r'^[a-z]{3,8}(?:bk|bnk|upi|bank)$', caseSensitive: false);

  static final RegExp _bankAcctNumPattern = RegExp(
    r'(?:a/c|acct|account)(?:\s+no\.?|\s+number|\s+ending(?:\s+in|\s+with)?)?\s*[:-]?\s*[*xX.]*(\d{3,6})\b',
    caseSensitive: false,
  );

  static final RegExp _accountNumPattern = RegExp(
    r'(?:a/c|acct|account|card)(?:\s+no\.?|\s+number|\s+ending(?:\s+in|\s+with)?)?\s*[:-]?\s*[*xX.]*(\d{3,6})\b',
    caseSensitive: false,
  );

  static final RegExp _secondaryTextAccountPattern = RegExp(
    r'(?:a/c|acct|account|card|ending in|ending with)\s*[:-]?\s*[*xX]*(\d{4,})',
    caseSensitive: false,
  );

  static final RegExp _secondaryTextBankPattern = RegExp(
    r'(?:using|via|from(?:\s+your)?)\s+([a-zA-Z\s]{2,25}?)\s+(?:Bank|A/c|Account|Card)\b',
    caseSensitive: false,
  );

  static final RegExp _titleBankRegex = RegExp(
    r'^(?:[A-Z]{2}-)?(HDFC|SBI|ICICI|AXIS|KOTAK|PNB|FEDERAL|FEDBNK|CANARA|UNION|IDFC|INDUSIND|YES|SIBSMS|BOB|BOI|IOB|IDBI|RBL|KVB|CUB|TMB|DBS|HSBC|AMEX|ONECARD|SLICE|AUBANK|EQUITAS|UJJIVAN|IPPB|ESAF)',
    caseSensitive: false,
  );

  // Universal lookahead terminator for Indian bank & UPI SMS payee slots
  static const String _payeeTerminator =
      r'(?=(?:\s*\(|\s+(?:from|on|using|via|ref|rrn|utr|upi|avl|bal|avail|final|umrn|info|chq|thru|not\s+you|if\s+not)|[.,;()]|\s+-|$))';

  static final List<RegExp> _payeePatterns = [
    RegExp(r'(?:^|.*?[\\n:])\s*([A-Za-z0-9\s._\-]{2,35}?)\s+(?:paid|sent)\s+you', caseSensitive: false, multiLine: true),
    RegExp(r'(?:via\s+upi\s+to|upi\s+to|by\s+upi\s+to)\s+([A-Za-z0-9@._\-\s]{2,35}?)' + _payeeTerminator, caseSensitive: false),
    RegExp(r'(?:received(?:\s+[₹Rs\d,.]+)?\s+from)\s+([A-Za-z0-9@._\-\s]{2,35}?)' + _payeeTerminator, caseSensitive: false),
    RegExp(r'(?:by transfer from|transferred from|transfer from|trf from)\s+([A-Za-z0-9@._\-\s]{2,35}?)' + _payeeTerminator, caseSensitive: false),
    RegExp(r'by UPI\s*[:-]\s*([A-Za-z0-9\s._\-]{2,35}?)' + _payeeTerminator, caseSensitive: false),
    RegExp(r'(?:linked to VPA|from VPA|to VPA|vpa[:\s])\s*([A-Za-z0-9@._\-]+)', caseSensitive: false),
    RegExp(r'(?:paid|sent)\s+(?:inr|rs\.?|₹)?\s*[0-9,.]*\s+to\s+([A-Za-z0-9@._\-\s]{2,35}?)' + _payeeTerminator, caseSensitive: false),
    RegExp(r'(?:you\s+paid|you\s+sent)\s+([A-Za-z0-9@._\-\s]{2,35}?)(?=\s+(?:inr|rs\.?|₹|[0-9]))', caseSensitive: false),
    RegExp(r'(?:paid to|transferred to|by transfer to|transfer to|trf to|sent to|credited to)\s+([A-Za-z0-9@._\-\s]{2,35}?)' + _payeeTerminator, caseSensitive: false),
    RegExp(r'(?:debited|debit)\b[^.\n]{0,65}?\bto\s+([A-Za-z0-9@._\-\s]{2,35}?)' + _payeeTerminator, caseSensitive: false),
    RegExp(r'(?:credited|credit)\b[^.\n]{0,65}?\bfrom\s+([A-Za-z0-9@._\-\s]{2,35}?)' + _payeeTerminator, caseSensitive: false),
    RegExp(r'^To\s+([A-Za-z0-9@._\-\s]{2,35}?)' + _payeeTerminator, caseSensitive: false, multiLine: true),
    RegExp(r'\b(?:plaza\s*:\s*|for\s+toll\s+at\s+)([A-Za-z0-9\s._\-]{2,35}?)' + _payeeTerminator, caseSensitive: false),
    RegExp(r'(?:at|towards|info[:/\-\s])\s+([A-Za-z0-9@._\-*\s]{2,45}?)' + _payeeTerminator, caseSensitive: false),
  ];

  static final RegExp _upiSlashPattern = RegExp(
    r'UPI[:/]([A-Za-z0-9/_\-.\s]+?)(?=(?:\s*\(|\s+(?:on|using|via|ref|rrn|utr|avl|bal|avail|final)|[.,;()]|\s+-|$))',
    caseSensitive: false,
  );

  static final List<RegExp> _refIdPatterns = [
    RegExp(r'(?:upi ref(?: no)?|ref no|rrn|txn id|transaction id|umrn)[:\s.]*([0-9a-zA-Z]{9,})', caseSensitive: false),
    RegExp(r'UPI/(?:[A-Za-z0-9]+/)*?([0-9]{10,14})', caseSensitive: false),
    RegExp(r'\b(?=[a-zA-Z]*\d)[a-zA-Z0-9]{9,}\b', caseSensitive: false),
  ];

  static const Set<String> _ignoredIdentifiers = {
    'UPI', 'CR', 'DR', 'P2A', 'P2M', 'REV', 'NA', 'INFO', 'NULL',
    'MERCHANT', 'UPIMERCHANT', 'UPI-MERCHANT', 'PAYEE', 'PAYMENT', 'TRANSFER',
    'COLLECT', 'NODAL', 'SIBL', 'HDFC', 'ICICI', 'SBIN', 'UTIB', 'KKBK',
    'FDRL', 'YESB', 'PAYTM', 'BILLDESK', 'RAZORPAY', 'CCAVENUE', 'AIRP', 'KVB', 'KVBL',
    'FEDBK', 'FEDBNK', 'FEDERAL', 'BARB', 'BKID', 'CBIN', 'IOBA', 'IDIB',
    'AC', 'ACCT', 'ACCOUNT', 'ACNO', 'YOURAC', 'YOURACCOUNT', 'SELF', 'FINAL', 'BALANCE'
  };

  static final RegExp _accountRefNoiseRegex = RegExp(
    r'^(?:your\s+)?(?:a/c|acct|account|card|sb|ca|od)\b.*|^[xX*#.\d\s\-]+$',
    caseSensitive: false,
  );

  static final RegExp _payeeParenthesesRegex = RegExp(r'\(([^)]+)\)');
  static final RegExp _trailingDigitsRegex = RegExp(r'\s*\d+$');
  static final RegExp _webDomainRegex = RegExp(r'\.(com|in|co\.in|net|org)$', caseSensitive: false);
  static final RegExp _corporateNoiseRegex = RegExp(r'\b(pvt ltd|private limited|ltd|limited|inc|technologies|services|order)\b', caseSensitive: false);

  static final List<RegExp> _bankNamePatterns = [
    RegExp(r'-\s*([a-zA-Z\s]+(?:Bank|SBI|Card))\s*$', caseSensitive: false, multiLine: true),
    RegExp(
      r'\b((?:HDFC|SBI|ICICI|Axis|Kotak|PNB|Federal|Canara|Union|IDFC|IndusInd|Yes|South Indian|Bank of Baroda|Bank of India|Indian|Indian Overseas|Central Bank|UCO|Punjab & Sind|IDBI|Bandhan|RBL|Karnataka|Karur Vysya|City Union|Tamilnad Mercantile|Dhanlaxmi|CSB|Saraswat|Kerala|Kerala Gramin|AU Small Finance|Equitas|Ujjivan|Utkarsh|Jana|ESAF|DBS|Standard Chartered|HSBC|Citi|American Express|OneCard|Slice|Jupiter|Fi|Airtel Payments|Jio Payments|India Post|Fino Payments)[\sA-Za-z]*(?:Bank|Card)?)\b',
      caseSensitive: false,
    ),
  ];

  static final List<MapEntry<RegExp, String>> _knownBankAliases = [
    MapEntry(RegExp(r'\bhdfc\b|hdfcbk|hdfcbank', caseSensitive: false), 'HDFC Bank'),
    MapEntry(RegExp(r'\bsbi\b|state\s*bank|sbiinb|sbipsg|sbicrd|yonosbi', caseSensitive: false), 'SBI'),
    MapEntry(RegExp(r'\bicici\b|icicib', caseSensitive: false), 'ICICI Bank'),
    MapEntry(RegExp(r'\baxis\b|axisbk', caseSensitive: false), 'Axis Bank'),
    MapEntry(RegExp(r'\bkotak\b|kotakb', caseSensitive: false), 'Kotak Bank'),
    MapEntry(RegExp(r'\bpnb\b|punjab\s*national|pnbsms', caseSensitive: false), 'PNB'),
    MapEntry(RegExp(r'\bfederal\b|fedbnk|fedbk', caseSensitive: false), 'Federal Bank'),
    MapEntry(RegExp(r'\bcanara\b|canbnk', caseSensitive: false), 'Canara Bank'),
    MapEntry(RegExp(r'\bunion\s*bank\b|\bubin\b|unionb', caseSensitive: false), 'Union Bank'),
    MapEntry(RegExp(r'\bidfc\b|idfcfb', caseSensitive: false), 'IDFC First Bank'),
    MapEntry(RegExp(r'\bindusind\b|indusb', caseSensitive: false), 'IndusInd Bank'),
    MapEntry(RegExp(r'\byes\s*bank\b|yesbnk|yesb', caseSensitive: false), 'Yes Bank'),
    MapEntry(RegExp(r'\bsib\b|south\s*indian|sibsms|sibl', caseSensitive: false), 'South Indian Bank'),
    MapEntry(RegExp(r'\bbob\b|bank\s*of\s*baroda|baroda|bobtxn|bobsms', caseSensitive: false), 'Bank of Baroda'),
    MapEntry(RegExp(r'\bboi\b|bank\s*of\s*india|boisms|boiind', caseSensitive: false), 'Bank of India'),
    MapEntry(RegExp(r'\bindian\s*overseas\b|\biob\b|iobchn|iobsms', caseSensitive: false), 'Indian Overseas Bank'),
    MapEntry(RegExp(r'\bindian\s*bank\b|indbnk|indoasis', caseSensitive: false), 'Indian Bank'),
    MapEntry(RegExp(r'\bcentral\s*bank\b|cbin|centbk', caseSensitive: false), 'Central Bank of India'),
    MapEntry(RegExp(r'\bbank\s*of\s*maharashtra\b|mahabk|bomaha', caseSensitive: false), 'Bank of Maharashtra'),
    MapEntry(RegExp(r'\buco\b|ucobnk', caseSensitive: false), 'UCO Bank'),
    MapEntry(RegExp(r'\bpunjab\s*(?:&|and)\s*sind\b|psbank', caseSensitive: false), 'Punjab & Sind Bank'),
    MapEntry(RegExp(r'\bidbi\b|idbibk', caseSensitive: false), 'IDBI Bank'),
    MapEntry(RegExp(r'\bbandhan\b|bdnbnk', caseSensitive: false), 'Bandhan Bank'),
    MapEntry(RegExp(r'\brbl\b|rblbnk|rblcrd', caseSensitive: false), 'RBL Bank'),
    MapEntry(RegExp(r'\bkarnataka\s*bank\b|ktkbnk|ktkbk', caseSensitive: false), 'Karnataka Bank'),
    MapEntry(RegExp(r'\bkarur\s*vysya\b|\bkvb\b|kvbl|kvbbnk', caseSensitive: false), 'Karur Vysya Bank'),
    MapEntry(RegExp(r'\bcity\s*union\b|\bcub\b|cubank', caseSensitive: false), 'City Union Bank'),
    MapEntry(RegExp(r'\btamilnad\s*mercantile\b|\btmb\b|tmbbnk', caseSensitive: false), 'Tamilnad Mercantile Bank'),
    MapEntry(RegExp(r'\bdhanlaxmi\b|dhlbnk|dlbbnk', caseSensitive: false), 'Dhanlaxmi Bank'),
    MapEntry(RegExp(r'\bcsb\b|catholic\s*syrian|csbbnk', caseSensitive: false), 'CSB Bank'),
    MapEntry(RegExp(r'\bsaraswat\b|srcb', caseSensitive: false), 'Saraswat Bank'),
    MapEntry(RegExp(r'\bkerala\s*gramin\b|klgb|kgbsms', caseSensitive: false), 'Kerala Gramin Bank'),
    MapEntry(RegExp(r'\bkerala\s*bank\b|kscb', caseSensitive: false), 'Kerala Bank'),
    MapEntry(RegExp(r'\bau\s*small\s*finance\b|\baubank\b|aubl', caseSensitive: false), 'AU Small Finance Bank'),
    MapEntry(RegExp(r'\bequitas\b|equitb', caseSensitive: false), 'Equitas Bank'),
    MapEntry(RegExp(r'\bujjivan\b|ujjivn', caseSensitive: false), 'Ujjivan Bank'),
    MapEntry(RegExp(r'\butkarsh\b|utksfb', caseSensitive: false), 'Utkarsh Bank'),
    MapEntry(RegExp(r'\bjana\s*small\s*finance\b|janabk', caseSensitive: false), 'Jana Bank'),
    MapEntry(RegExp(r'\besaf\b|esafbk', caseSensitive: false), 'ESAF Bank'),
    MapEntry(RegExp(r'\bdbs\b|dbsbnk', caseSensitive: false), 'DBS Bank'),
    MapEntry(RegExp(r'\bstandard\s*chartered\b|scbank|\bscb\b', caseSensitive: false), 'Standard Chartered'),
    MapEntry(RegExp(r'\bhsbc\b', caseSensitive: false), 'HSBC'),
    MapEntry(RegExp(r'\bciti\b|citibk', caseSensitive: false), 'Citibank'),
    MapEntry(RegExp(r'\bamex\b|american\s*express', caseSensitive: false), 'American Express'),
    MapEntry(RegExp(r'\bonecard\b|fpl\s*technologies', caseSensitive: false), 'OneCard'),
    MapEntry(RegExp(r'\bslice\b|sliceit', caseSensitive: false), 'Slice'),
    MapEntry(RegExp(r'\bjupiter\b', caseSensitive: false), 'Jupiter'),
    MapEntry(RegExp(r'\bfi\s*money\b|epifi', caseSensitive: false), 'Fi Money'),
    MapEntry(RegExp(r'\bairtel\s*payments?\s*bank\b|airbnk|airp', caseSensitive: false), 'Airtel Payments Bank'),
    MapEntry(RegExp(r'\bjio\s*payments?\s*bank\b|jiopay|jiobnk', caseSensitive: false), 'Jio Payments Bank'),
    MapEntry(RegExp(r'\bindia\s*post\b|\bippb\b|ippbsm', caseSensitive: false), 'India Post Payments Bank'),
    MapEntry(RegExp(r'\bfino\s*payments?\b|finobk', caseSensitive: false), 'Fino Payments Bank'),
    MapEntry(RegExp(r'\bnsdl\s*payments?\b|nsdlpb', caseSensitive: false), 'NSDL Payments Bank'),
    MapEntry(RegExp(r'\bamazon\s*pay\b|amzpay', caseSensitive: false), 'Amazon Pay'),
    MapEntry(RegExp(r'\bpluxee\b|\bsodexo\b', caseSensitive: false), 'Pluxee'),
    MapEntry(RegExp(r'\blazypay\b', caseSensitive: false), 'LazyPay'),
    MapEntry(RegExp(r'\bsimpl\b', caseSensitive: false), 'Simpl'),
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // CATEGORY CLASSIFICATION REGEXES (Mapped to TallyTap categories)
  // ─────────────────────────────────────────────────────────────────────────
  static final Map<String, RegExp> _payeeCategoryMap = {
    'Dining': RegExp(
      r'\b(starbucks|swiggy|zomato|dineout|eazy\s*diner|magicpin|eatsure|rebel foods|faasos|behrouz|oven story|lunchbox|mcdonalds?|kfc|burger|burger king|cafe|restaurant|pizza|pizza hut|subway|dominos?|tea|coffee|bistro|bakery|bakers|hotel|shawarma|biryani|broast|canteen|mess|juice|chai|chaayos|chai point|third wave|blue tokai|ccd|diner|eatery|kitchen|grill|haldirams?|bikanervala|saravana bhavan|rameshwaram cafe|udupi|barbeque nation|taco bell|baskin robbins|naturals ice|theobroma|monginis|dhaba|thali|food court|rolls|snacks|restobar|pub|brewery)\b',
      caseSensitive: false,
    ),
    'Groceries': RegExp(
      r'\b(blinkit|zepto|instamart|bigbasket|bbnow|bb daily|dmart|d-mart|avenue supermarts|grofers|spencer|supermarket|grocery|groceries|vegetables?|veggies|sabzi|fruits?|reliance fresh|reliance smart|jiomart|more supermarket|lulu hypermarket|lulu daily|hypermarket|safal|mother dairy|amul|nandini|milma|licious|freshtohome|star bazaar|spar hypermarket|kirana|provisions?|minimart|general store|dairy|milk|butcher|fish market|poultry)\b',
      caseSensitive: false,
    ),
    'Commute': RegExp(
      r'\b(hpcl|hindustan petroleum|bpcl|bharat petroleum|iocl|indian oil|shell india|nayara|netc fastag|fastag|ihmcl|nhai|toll|uber|ola cabs|rapido|namma yatri|blusmart|kochi metro|delhi metro|namma metro|chennai metro|mumbai metro|bmtc|ksrtc|msrtc)\b',
      caseSensitive: false,
    ),
    'Travel': RegExp(
      r'\b(irctc|indian railways|confirmtkt|redbus|abhibus|makemytrip|goibibo|cleartrip|ixigo|easemytrip|airbnb|indigo|interglobe|air india|vistara|akasa|spicejet)\b',
      caseSensitive: false,
    ),
    'Utilities': RegExp(
      r'\b(myjio|reliance jio|jiofiber|bharti airtel|airtel thanks|vodafone idea|bsnl|act fibernet|tata play|tata sky|sun direct|kseb|ksebl|bescom|tneb|msedcl|adani electricity|indane|bharatgas|hp gas|bwssb|bharat billpay|electricity|water bill|gas bill|recharge)\b',
      caseSensitive: false,
    ),
    'Subscriptions': RegExp(
      r'\b(netflix|hotstar|spotify|amazon prime|youtube premium|sonyliv|jiocinema|zee5|apple music|google play|google one|microsoft 365|chatgpt|openai|claude|anthropic|canva|adobe)\b',
      caseSensitive: false,
    ),
    'Housing': RegExp(
      r'\b(nobroker|mygate|apnacomplex|stanza living|rent|maintenance bill|society maintenance)\b',
      caseSensitive: false,
    ),
    'Shopping': RegExp(
      r'\b(amazon|flipkart|myntra|meesho|ajio|zara|uniqlo|decathlon|croma|reliance digital|vijay sales|poorvika|shoppers stop|tata cliq|zudio|westside|pantaloons|max fashion|ikea|pepperfry|wakefit|tanishq|caratlane|kalyan jewellers|malabar gold|lenskart|firstcry)\b',
      caseSensitive: false,
    ),
    'Health': RegExp(
      r'\b(apollo pharmacy|apollo hospitals|pharmeasy|tata 1mg|netmeds|medplus|lal pathlabs|thyrocare|manipal hospital|fortis|cultfit|healthkart|muscleblaze|clinic|hospital|pharmacy|chemist|dentist)\b',
      caseSensitive: false,
    ),
    'Investments': RegExp(
      r'\b(zerodha|groww|upstox|angel one|paytm money|indmoney|kuvera|smallcase|geojit|cams|kfintech|sbi mf|hdfc mf|parag parikh|jar app|gullak|safegold|mutual fund|stock|sip)\b',
      caseSensitive: false,
    ),
    'Salary': RegExp(
      r'\b(salary|payroll|bonus|incentive|stipend|dividend)\b',
      caseSensitive: false,
    ),
  };

  // ─────────────────────────────────────────────────────────────────────────
  // MAIN PARSE METHOD
  // ─────────────────────────────────────────────────────────────────────────

  /// Parses an SMS text string (with optional sender and timestamp) into a [ParsedSmsTransaction].
  static ParsedSmsTransaction parse(
    String rawText, {
    String? sender,
    DateTime? date,
  }) {
    final combinedText = (sender != null && sender.trim().isNotEmpty && !rawText.startsWith(sender))
        ? '$sender:$rawText'
        : rawText;

    // 1. Run Reject List First (OTPs, failed, declined, future mandates, data promos)
    for (final pattern in _rejectPatterns) {
      if (pattern.hasMatch(combinedText)) {
        return _createRejected(rawText, 'Matched reject pattern: ${pattern.pattern}', sender: sender, date: date);
      }
    }

    final lowerText = combinedText.toLowerCase();
    final hasTransactionVerb = _financialKeywords.any((p) => p.hasMatch(lowerText));
    final isReversal = _reversalPattern.hasMatch(combinedText);
    final detectedType = isReversal ? SmsTransactionType.credit : _detectTransactionType(combinedText);

    if (!hasTransactionVerb && detectedType == null) {
      return _createRejected(rawText, 'No financial keywords found', sender: sender, date: date);
    }

    final isPromo = _promoPatterns.hasMatch(combinedText);
    final hasBankVerification = _bankIndicators.hasMatch(combinedText);

    // 2. Conditional Promo Filter
    if (isPromo && !hasBankVerification) {
      return _createRejected(rawText, 'Matched SMS promo pattern', sender: sender, date: date);
    }

    final cleanedForPayee = combinedText.replaceAll(_disclaimerPattern, '').trim();
    final balancePaise = _extractBalance(combinedText);
    final amountPaise = _extractAmount(combinedText);

    // A message with no monetary amount and no balance is never a financial transaction
    if ((amountPaise == null || amountPaise <= 0) && balancePaise == null) {
      return _createRejected(rawText, 'No monetary amount or balance found', sender: sender, date: date);
    }
    if (isPromo && (amountPaise == null || amountPaise <= 0)) {
      return _createRejected(rawText, 'Promo message without transaction amount', sender: sender, date: date);
    }

    final rawPayee = _extractPayee(cleanedForPayee, sender, detectedType ?? SmsTransactionType.debit);
    final refId = _extractReferenceId(combinedText);
    final isRefund = _refundFlagPattern.hasMatch(combinedText);
    final extractedNote = _extractGPayNote(rawText: rawText, sender: sender);
    final note = extractedNote ?? ((isRefund && detectedType == SmsTransactionType.credit) ? 'Refund / Cashback' : null);

    final rawBankName = _extractBankName(combinedText, sender);
    final hasBankOrDebitContext = _bankAccountOrDebitCardPattern.hasMatch(combinedText);
    final hasCcSignal = _ccAccountDetectPattern.hasMatch(cleanedForPayee) ||
        _ccLimitSignalPattern.hasMatch(combinedText);
    final isCreditCard = hasCcSignal && !hasBankOrDebitContext;
    final normalizedBank = _normalizeBankName(rawBankName);

    final String? bankName;
    if (normalizedBank != null &&
        isCreditCard &&
        !normalizedBank.toLowerCase().contains('card') &&
        !['OneCard', 'Slice', 'American Express', 'LazyPay', 'Simpl'].contains(normalizedBank)) {
      bankName = '$normalizedBank CC';
    } else if (normalizedBank == null && isCreditCard) {
      bankName = 'Credit Card';
    } else {
      bankName = normalizedBank;
    }

    final accountNumber = _normalizeAccountNumber(_extractAccountNumber(combinedText));

    // 3. CC and Self-Transfer Flagging
    final isReversalText = _reversalPattern.hasMatch(combinedText);
    final isCcPaymentReceived = isCreditCard && detectedType == SmsTransactionType.credit && !isRefund && !isReversalText;
    final isCcPayment = _ccBillPattern.hasMatch(combinedText) || isCcPaymentReceived;
    final isSelfTransfer = _selfTransferPattern.hasMatch(combinedText);
    final isTransferFlag = isCcPayment || isSelfTransfer;

    final String? cleanedPayee;
    if (isCcPayment) {
      cleanedPayee = 'Credit Card Bill';
    } else {
      final cleaned = _cleanPayee(rawPayee);
      if (cleaned != null) {
        cleanedPayee = cleaned;
      } else if (isSelfTransfer) {
        cleanedPayee = 'Self Transfer';
      } else {
        cleanedPayee = null;
      }
    }

    final double? amount = amountPaise != null ? amountPaise / 100.0 : null;
    final double? balance = balancePaise != null ? balancePaise / 100.0 : null;
    final int? availableLimitPaise = isCreditCard ? _extractAvailableLimit(combinedText) : null;
    final double? availableLimit = availableLimitPaise != null ? availableLimitPaise / 100.0 : null;

    final resolvedPayee = cleanedPayee ?? inferFallbackPayee(combinedText, detectedType);
    final category = _classifyCategory(resolvedPayee, combinedText, isTransfer: isTransferFlag, type: detectedType);

    return ParsedSmsTransaction(
      isFinancial: true,
      amount: amount,
      amountPaise: amountPaise,
      payee: cleanedPayee,
      type: detectedType,
      referenceId: refId,
      balance: balance,
      balancePaise: balancePaise,
      availableLimit: availableLimit,
      availableLimitPaise: availableLimitPaise,
      note: note,
      bankName: bankName,
      accountNumber: accountNumber,
      rawText: rawText,
      sender: sender,
      currency: 'INR',
      accountType: isCreditCard ? 'CREDIT_CARD' : 'BANK',
      isTransfer: isTransferFlag,
      excludeFromSpend: isCcPayment || isRefund || isSelfTransfer,
      confidence: (detectedType != null && amount != null) ? 1.0 : 0.5,
      category: category,
      date: date ?? DateTime.now(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPER EXTRACTION METHODS
  // ─────────────────────────────────────────────────────────────────────────

  static int? _extractAvailableLimit(String text) {
    final match = _availableLimitValuePattern.firstMatch(text);
    if (match == null) return null;
    final candidate = match.group(1)?.replaceAll(',', '').trim();
    if (candidate == null) return null;
    final parsed = double.tryParse(candidate);
    return parsed != null ? (parsed * 100).round() : null;
  }

  static String inferFallbackPayee(
    String rawText,
    SmsTransactionType? type, {
    String userFallback = 'UPI Payment',
  }) {
    final lower = rawText.toLowerCase();
    final effectiveDefault = (userFallback.trim().isEmpty || userFallback.toLowerCase() == 'bank transfer')
        ? 'UPI Payment'
        : userFallback;

    if (lower.contains('fastag') || lower.contains('toll plaza')) {
      return 'FASTag Toll';
    }
    if (lower.contains('upi')) {
      return type == SmsTransactionType.credit ? 'UPI Received' : effectiveDefault;
    }
    if (lower.contains('atm') || lower.contains('withdrawn')) {
      return 'ATM Withdrawal';
    }
    if (lower.contains('pos ') || lower.contains('debit card') || lower.contains('card ending')) {
      return 'Card Spend';
    }
    if (lower.contains('imps') || lower.contains('neft') || lower.contains('rtgs')) {
      return type == SmsTransactionType.credit ? 'Bank Credit' : 'Bank Transfer';
    }
    if (type == SmsTransactionType.credit) {
      return 'Bank Credit';
    }
    return effectiveDefault;
  }

  static ParsedSmsTransaction _createRejected(
    String rawText,
    String reason, {
    String? sender,
    DateTime? date,
  }) {
    return ParsedSmsTransaction(
      isFinancial: false,
      rawText: rawText,
      sender: sender,
      rejectReason: reason,
      confidence: 0.0,
      date: date,
    );
  }

  static String? _extractGPayNote({required String rawText, String? sender}) {
    final quotedMatch = _quotedNoteRegex.firstMatch(rawText);
    if (quotedMatch != null) {
      final note = quotedMatch.group(1)?.trim();
      if (note != null && !_isSystemNoise(note)) return note;
    }

    final prefixMatch = _prefixNoteRegex.firstMatch(rawText);
    if (prefixMatch != null) {
      final note = prefixMatch.group(1)?.trim();
      if (note != null && !_isSystemNoise(note)) return note;
    }

    final lines = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.length >= 2) {
      final candidate = lines[1];
      if (!_isSystemNoise(candidate) && !_looksLikeBalanceLine(candidate) && candidate.length >= 2 && candidate.length <= 80) {
        return candidate.replaceAll('"', '').replaceAll('“', '').replaceAll('”', '').trim();
      }
    }
    return null;
  }

  static bool _isSystemNoise(String text) => _systemNoiseRegex.hasMatch(text);

  static bool _looksLikeBalanceLine(String text) => _balancePattern.hasMatch(text);

  static int? _extractAmount(String text) {
    final sanitized = text.replaceAll(_balancePattern, '');
    for (final pattern in _amountPatterns) {
      final match = pattern.firstMatch(sanitized);
      if (match != null) {
        final candidate = match.group(1)?.replaceAll(',', '').trim();
        if (candidate != null) {
          final parsed = double.tryParse(candidate);
          if (parsed != null && parsed > 0) {
            return (parsed * 100).round();
          }
        }
      }
    }
    return null;
  }

  static int? _extractBalance(String text) {
    final match = _balancePattern.firstMatch(text);
    if (match != null) {
      final candidate = match.group(1)?.replaceAll(',', '').trim();
      if (candidate != null) {
        final parsed = double.tryParse(candidate);
        if (parsed != null) {
          return (parsed * 100).round();
        }
      }
    }
    return null;
  }

  static String? _extractPayee(String text, String? title, SmsTransactionType type) {
    for (final pattern in _payeePatterns) {
      for (final match in pattern.allMatches(text)) {
        final candidate = match.group(1)?.trim();
        if (candidate != null && candidate.length > 1 && !_isIgnored(candidate)) {
          return candidate;
        }
      }
    }

    final upiMatch = _upiSlashPattern.firstMatch(text);
    if (upiMatch != null) {
      final rawPath = upiMatch.group(1) ?? '';
      final segments = rawPath
          .split('/')
          .map((s) => s.replaceAll(RegExp(r'^[ .,\-:;()]+|[ .,\-:;()]+$'), '').trim())
          .where((segment) =>
              segment.isNotEmpty &&
              !RegExp(r'^\d+$').hasMatch(segment) &&
              segment.length > 1 &&
              !_isIgnored(segment))
          .toList();

      if (segments.isNotEmpty) {
        segments.sort((a, b) => b.length.compareTo(a.length));
        return segments.first;
      }
    }

    if (title != null && title.trim().isNotEmpty && !_isAppNameOrGeneric(title)) {
      return title.trim();
    }

    return null;
  }

  static bool _isIgnored(String candidate) {
    final trimmed = candidate.replaceAll(RegExp(r'^[ .,\-:;()]+|[ .,\-:;()]+$'), '').trim();
    if (trimmed.length < 2) return true;
    final normalized = trimmed.toUpperCase().replaceAll(RegExp(r'[\-_/ ]'), '').trim();
    if (_ignoredIdentifiers.contains(normalized)) return true;

    if (_digitOnlyRegex.hasMatch(trimmed) || _accountRefNoiseRegex.hasMatch(trimmed)) return true;

    final lower = trimmed.toLowerCase();
    if (lower.contains('block') || lower.contains('call') || lower.contains('sms') ||
        lower.contains('toll free') || lower.contains('final balance') || lower.contains('avl bal') ||
        lower.contains('avail bal') || lower.contains('upi ref') || lower.contains('ref no') ||
        lower.contains('credit card') || lower.contains('debit card')) {
      return true;
    }

    return false;
  }

  static bool _isAppNameOrGeneric(String title) {
    final t = title.toLowerCase().trim();
    const genericApps = {
      'google pay', 'gpay', 'phonepe', 'paytm', 'bhim', 'alert',
      'bank', 'credit alert', 'debit alert', 'amazon pay', 'super.money',
      'mobikwik', 'slice', 'navi', 'samsung wallet', 'fi money', 'jupiter', 'freecharge',
      'cred', 'kiwi', 'tata neu', 'fampay', 'whatsapp'
    };
    final isGeneric = genericApps.contains(t);
    final isSmsHeader = _smsHeaderRegex.hasMatch(title) ||
        _bankHeaderRegex.hasMatch(title) ||
        {
          'FEDBK', 'FEDBNK', 'HDFCBK', 'SBIINB', 'ICICIB',
          'AXISBK', 'KOTAKB', 'CANBNK', 'PNBSMS', 'SIBL', 'YESBNK', 'SIBSMS',
          'BOBTXN', 'BOIIND', 'IOBCHN', 'INDBNK', 'CBIN', 'UCOBNK', 'IDBIBK', 'RBLBNK'
        }.contains(title.toUpperCase());
    return isGeneric || isSmsHeader;
  }

  static String? _cleanPayee(String? payee) {
    if (payee == null || payee.trim().isEmpty) return null;
    var cleaned = payee.replaceAll(_vpaCleanupRegex, '').replaceAll(RegExp(r'[ .,\-:]+$'), '').trim();
    if (cleaned.length > 45) {
      cleaned = cleaned.substring(0, 45);
    }

    final parenthesizedMatch = _payeeParenthesesRegex.firstMatch(cleaned);
    if (parenthesizedMatch != null) {
      final inner = parenthesizedMatch.group(1)?.trim();
      if (inner != null && inner.isNotEmpty && !RegExp(r'^\d+$').hasMatch(inner) && !_isIgnored(inner)) {
        cleaned = inner;
      }
    }

    if (cleaned.contains('@')) {
      var username = cleaned.split('@').first.replaceAll(RegExp(r'[._\-]'), ' ').trim();
      username = username.replaceAll(_trailingDigitsRegex, '').trim();
      if (username.length >= 2 && !RegExp(r'^\d+$').hasMatch(username)) {
        cleaned = username;
      }
    }

    cleaned = cleaned.replaceAll(_webDomainRegex, '').trim();
    cleaned = cleaned.replaceAll(_corporateNoiseRegex, '').trim();
    cleaned = cleaned.replaceAll(RegExp(r'^[ .,\-:_]+|[ .,\-:_]+$'), '').trim();

    if (cleaned.isEmpty || _digitOnlyRegex.hasMatch(cleaned) || _isIgnored(cleaned)) {
      return null;
    }

    final titleCased = cleaned
        .toLowerCase()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((word) => word[0].toUpperCase() + (word.length > 1 ? word.substring(1) : ''))
        .join(' ');

    if (titleCased.isEmpty) return null;
    if (titleCased.toLowerCase() == 'google i') return 'Google India';
    return titleCased;
  }

  static String? _extractBankName(String text, String? title) {
    if (title != null && title.trim().isNotEmpty) {
      for (final entry in _knownBankAliases) {
        if (entry.key.hasMatch(title)) return entry.value;
      }
      final titleMatch = _titleBankRegex.firstMatch(title);
      if (titleMatch != null) {
        return '${titleMatch.group(1)!.toUpperCase()} Bank';
      }
    }

    final subtextMatch = _secondaryTextBankPattern.firstMatch(text);
    if (subtextMatch != null) {
      final rawBank = subtextMatch.group(1)?.trim();
      if (rawBank != null && rawBank.length > 2 && rawBank.toLowerCase() != 'upi') {
        return '${rawBank.toUpperCase()} Bank';
      }
    }

    for (final entry in _knownBankAliases) {
      if (entry.key.hasMatch(text)) return entry.value;
    }

    for (final pattern in _bankNamePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final bank = match.group(1)?.trim();
        if (bank != null && bank.isNotEmpty) {
          final normalized = bank.replaceAll(RegExp(r'\s+bank$', caseSensitive: false), ' Bank');
          return normalized[0].toUpperCase() + (normalized.length > 1 ? normalized.substring(1) : '');
        }
      }
    }

    return null;
  }

  static SmsTransactionType? _detectTransactionType(String rawText) {
    final sanitized = rawText.replaceAll(_creditCardPattern, '');
    final hasCredit = _creditPattern.hasMatch(sanitized);
    final hasDebit = _debitPattern.hasMatch(sanitized);

    if (hasCredit && !hasDebit) return SmsTransactionType.credit;
    if (hasDebit && !hasCredit) return SmsTransactionType.debit;
    return null;
  }

  static String? _normalizeBankName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();

    for (final entry in _knownBankAliases) {
      if (entry.key.hasMatch(trimmed)) return entry.value;
    }

    final words = trimmed.replaceAll(RegExp(r'\s+'), ' ').toLowerCase().split(' ');
    final result = words
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : ''))
        .join(' ');
    return result.isNotEmpty ? result : null;
  }

  static String? _normalizeAccountNumber(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final digitsOnly = raw.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) return null;
    return digitsOnly.length >= 4 ? digitsOnly.substring(digitsOnly.length - 4) : digitsOnly;
  }

  static String? _extractReferenceId(String text) {
    for (final pattern in _refIdPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.groupCount > 0 ? match.group(1)?.trim() : match.group(0)?.trim();
      }
    }
    return null;
  }

  static String? _extractAccountNumber(String text) {
    final bankAcctMatch = _bankAcctNumPattern.firstMatch(text);
    if (bankAcctMatch != null) {
      return bankAcctMatch.group(1)?.trim();
    }

    final matcher = _accountNumPattern.firstMatch(text);
    if (matcher != null) {
      return matcher.group(1)?.trim();
    }

    final subtextMatch = _secondaryTextAccountPattern.firstMatch(text);
    if (subtextMatch != null) {
      return subtextMatch.group(1)?.trim();
    }

    return null;
  }

  static String _classifyCategory(
    String payee,
    String rawContent, {
    bool isTransfer = false,
    SmsTransactionType? type,
  }) {
    if (isTransfer) return 'Transfer';
    if (type == SmsTransactionType.credit) {
      if (RegExp(r'\b(salary|payroll|stipend)\b', caseSensitive: false).hasMatch(rawContent) ||
          RegExp(r'\b(salary|payroll|stipend)\b', caseSensitive: false).hasMatch(payee)) {
        return 'Salary';
      }
      return 'Income';
    }

    for (final entry in _payeeCategoryMap.entries) {
      if (entry.value.hasMatch(payee)) {
        return entry.key;
      }
    }

    for (final entry in _payeeCategoryMap.entries) {
      if (entry.value.hasMatch(rawContent)) {
        return entry.key;
      }
    }

    return 'Other';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NATIVE ANDROID SMS RETRIEVAL & INTEGRATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Checks whether READ_SMS permission is granted on Android.
  static Future<bool> hasSmsPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('checkSmsPermission');
      return res ?? false;
    } on PlatformException catch (e) {
      debugPrint('⚠️ [SmsParserService] checkSmsPermission failed: ${e.message}');
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Requests READ_SMS permission on Android.
  static Future<bool> requestSmsPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestSmsPermission');
      return res ?? false;
    } on PlatformException catch (e) {
      debugPrint('⚠️ [SmsParserService] requestSmsPermission failed: ${e.message}');
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Queries the Android SMS Inbox for recent messages.
  static Future<List<Map<String, dynamic>>> fetchInboxSms({
    int limit = 100,
    DateTime? since,
  }) async {
    try {
      final sinceMs = since?.millisecondsSinceEpoch ??
          DateTime.now().subtract(const Duration(days: 90)).millisecondsSinceEpoch;
      final result = await _channel.invokeMethod<List<dynamic>>('getInboxSms', {
        'limit': limit,
        'since': sinceMs,
      });

      if (result == null) return [];
      return result.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } on PlatformException catch (e) {
      debugPrint('⚠️ [SmsParserService] fetchInboxSms failed: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('⚠️ [SmsParserService] unexpected error in fetchInboxSms: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PAYMENT SOURCE MAPPING & PREFERENCES
  // ─────────────────────────────────────────────────────────────────────────

  /// Saves a persistent mapping preference for a bank/card to a specific payment source.
  static Future<void> saveSourcePreference(String bankName, String? accountNumber, String sourceName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'sms_pref_src_${bankName.trim()}_${accountNumber?.trim() ?? ''}';
      await prefs.setString(key, sourceName);
      // Also save generic bankName preference as fallback
      await prefs.setString('sms_pref_src_${bankName.trim()}', sourceName);
    } catch (e) {
      debugPrint('⚠️ [SmsParserService] Error saving source preference: $e');
    }
  }

  /// Loads all saved payment source preferences.
  static Future<Map<String, String>> loadSourcePreferences() async {
    final Map<String, String> result = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (key.startsWith('sms_pref_src_')) {
          final bankKey = key.replaceFirst('sms_pref_src_', '');
          final val = prefs.getString(key);
          if (val != null && val.isNotEmpty) {
            result[bankKey] = val;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [SmsParserService] Error loading source preferences: $e');
    }
    return result;
  }

  /// Intelligently maps a parsed SMS to the user's existing payment sources.
  static String mapToPaymentSource(
    ParsedSmsTransaction sms,
    List<String> availableSources, {
    Map<String, String>? savedPreferences,
  }) {
    if (availableSources.isEmpty) return 'Bank Account';

    final bankName = sms.bankName?.trim() ?? '';
    final acctNum = sms.accountNumber?.trim() ?? '';
    final isCard = sms.accountType == 'CREDIT_CARD';

    // 1. Check saved preferences (previously mapped by user)
    if (savedPreferences != null) {
      if (bankName.isNotEmpty && acctNum.isNotEmpty) {
        final key = '${bankName}_$acctNum';
        if (savedPreferences.containsKey(key) && availableSources.contains(savedPreferences[key])) {
          return savedPreferences[key]!;
        }
      }
      if (bankName.isNotEmpty && savedPreferences.containsKey(bankName) && availableSources.contains(savedPreferences[bankName])) {
        return savedPreferences[bankName]!;
      }
    }

    // 2. Account number match (e.g. source named "HDFC 1234" or "SBI **5678")
    if (acctNum.isNotEmpty) {
      for (final src in availableSources) {
        if (src.contains(acctNum)) {
          return src;
        }
      }
    }

    // 3. Bank name & Account type match
    final bankWords = bankName.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 2 && w != 'bank');

    if (isCard) {
      // 3a. Source containing bank name AND card/cc
      if (bankWords.isNotEmpty) {
        for (final src in availableSources) {
          final srcLower = src.toLowerCase();
          final hasBank = bankWords.any((w) => srcLower.contains(w));
          final hasCard = srcLower.contains('card') || srcLower.contains('cc') || srcLower.contains('credit');
          if (hasBank && hasCard) return src;
        }
        // 3b. Source containing bank name (e.g. OneCard, Slice, Amex)
        for (final src in availableSources) {
          final srcLower = src.toLowerCase();
          if (bankWords.any((w) => srcLower.contains(w))) return src;
        }
      }
      // 3c. Source containing "credit card" or "card"
      for (final src in availableSources) {
        final srcLower = src.toLowerCase();
        if (srcLower == 'credit card' || srcLower.contains('credit card') || srcLower.contains('cc')) {
          return src;
        }
      }
    } else {
      // 3a. BANK ACCOUNT: Source containing bank name and NOT card/cc
      if (bankWords.isNotEmpty) {
        for (final src in availableSources) {
          final srcLower = src.toLowerCase();
          final hasBank = bankWords.any((w) => srcLower.contains(w));
          final hasCard = srcLower.contains('card') || srcLower.contains('cc');
          if (hasBank && !hasCard) return src;
        }
        for (final src in availableSources) {
          final srcLower = src.toLowerCase();
          if (bankWords.any((w) => srcLower.contains(w))) return src;
        }
      }
      // 3b. Exact "Bank Account"
      for (final src in availableSources) {
        if (src.toLowerCase() == 'bank account') return src;
      }
    }

    // 4. Fallback: First non-cash source or first available source
    final nonCash = availableSources.firstWhere(
      (s) => s.toLowerCase() != 'cash',
      orElse: () => availableSources.first,
    );
    return nonCash;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INTELLIGENT DUPLICATE DETECTION & MERGE
  // ─────────────────────────────────────────────────────────────────────────

  /// Compares an incoming parsed SMS against existing ledger transactions
  /// to smartly detect exact duplicates or potential manual duplicates (e.g., from Triple Tap).
  static SmsDuplicateMatch findDuplicateMatch(
    ParsedSmsTransaction sms,
    List<ExpenseTransaction> existingTransactions,
  ) {
    if (!sms.isFinancial || sms.amount == null || sms.amount! <= 0) {
      return const SmsDuplicateMatch(status: DuplicateStatus.none, reason: '');
    }

    final smsRef = sms.referenceId?.trim() ?? '';
    final smsAmount = sms.amount!;
    final smsDate = sms.date ?? DateTime.now();
    final smsPayeeClean = (sms.payee ?? '').toLowerCase().trim();

    // 1. Exact match check: reference ID in existing notes
    if (smsRef.isNotEmpty) {
      for (final tx in existingTransactions) {
        if (tx.notes.contains('Ref: $smsRef')) {
          return SmsDuplicateMatch(
            status: DuplicateStatus.exact,
            matchedTransaction: tx,
            reason: 'Already imported in ledger (Ref: $smsRef)',
          );
        }
      }
    }

    // 2. Potential match check: same amount, type, and close date proximity
    ExpenseTransaction? bestMatch;
    int bestScore = 0;
    String matchReason = '';

    for (final tx in existingTransactions) {
      // Must match income/expense type
      if (tx.isIncome != sms.isIncome) continue;

      // Must match amount within 1 cent/paise
      if ((tx.amount - smsAmount).abs() > 0.01) continue;

      int score = 0;
      final txDate = tx.date;
      final diffMinutes = txDate.difference(smsDate).inMinutes.abs();
      final sameDay = txDate.year == smsDate.year &&
          txDate.month == smsDate.month &&
          txDate.day == smsDate.day;

      // Ignore transactions more than 48 hours away
      if (!sameDay && diffMinutes > 2880) continue;

      // Closeness in time score
      if (diffMinutes <= 60) {
        score += 50; // Within 1 hour
      } else if (diffMinutes <= 360) {
        score += 35; // Within 6 hours
      } else if (sameDay) {
        score += 25; // Same calendar day
      } else {
        score += 10;
      }

      // Merchant / Payee similarity score
      final txMerchantClean = tx.merchant.toLowerCase().trim();
      final txNotesClean = tx.notes.toLowerCase().trim();

      if (smsPayeeClean.isNotEmpty && txMerchantClean.isNotEmpty) {
        if (smsPayeeClean == txMerchantClean) {
          score += 50;
        } else if (smsPayeeClean.contains(txMerchantClean) || txMerchantClean.contains(smsPayeeClean)) {
          score += 40;
        } else {
          final smsWords = smsPayeeClean.split(RegExp(r'\s+')).where((w) => w.length > 2);
          final txWords = txMerchantClean.split(RegExp(r'\s+')).where((w) => w.length > 2);
          if (smsWords.any((w) => txWords.contains(w))) {
            score += 30;
          }
        }
      }

      if (smsPayeeClean.isNotEmpty && txNotesClean.contains(smsPayeeClean)) {
        score += 25;
      }

      // If user typed a generic or quick note (e.g. from Triple Tap quick add)
      const genericMerchants = {'', 'expense', 'unknown', 'quick tap', 'coffee', 'food', 'payment', 'transfer'};
      if (genericMerchants.contains(txMerchantClean) && diffMinutes <= 120) {
        score += 35;
      }

      // Payment method correlation
      if (sms.selectedPaymentSource != null &&
          tx.paymentMethod.toLowerCase() == sms.selectedPaymentSource!.toLowerCase()) {
        score += 20;
      } else if (sms.accountType == 'CREDIT_CARD' &&
          tx.paymentMethod.toLowerCase().contains('card')) {
        score += 15;
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = tx;
        final timeLabel = diffMinutes <= 60
            ? '${diffMinutes}m apart'
            : '${(diffMinutes / 60).toStringAsFixed(1)}h apart';
        matchReason = 'Matches entry: "${tx.merchant}" (₹${tx.amount.toStringAsFixed(2)}, $timeLabel)';
      }
    }

    if (bestMatch != null && bestScore >= 45) {
      return SmsDuplicateMatch(
        status: DuplicateStatus.potential,
        matchedTransaction: bestMatch,
        reason: matchReason,
      );
    }

    return const SmsDuplicateMatch(status: DuplicateStatus.none, reason: '');
  }

  /// Merges a manual entry with official bank SMS verification details.
  static ExpenseTransaction mergeTransaction(
    ExpenseTransaction existing,
    ParsedSmsTransaction sms,
  ) {
    final bankInfoParts = <String>[];
    if (sms.bankName != null) {
      final acct = sms.accountNumber != null ? ' (A/c **${sms.accountNumber})' : '';
      bankInfoParts.add('${sms.bankName}$acct');
    }
    if (sms.referenceId != null && sms.referenceId!.isNotEmpty) {
      bankInfoParts.add('Ref: ${sms.referenceId}');
    }
    if (sms.balance != null) {
      bankInfoParts.add('Bal: ₹${sms.balance!.toStringAsFixed(2)}');
    }

    final bankInfo = bankInfoParts.join(' | ');

    // Enrich existing notes
    String enrichedNotes = existing.notes.trim();
    if (bankInfo.isNotEmpty) {
      if (enrichedNotes.isEmpty) {
        enrichedNotes = bankInfo;
      } else if (!enrichedNotes.contains(bankInfo)) {
        enrichedNotes = '$enrichedNotes | $bankInfo';
      }
    }

    // If manual merchant was generic, upgrade to official SMS payee
    const genericMerchants = {'', 'expense', 'unknown', 'quick tap', 'coffee', 'food', 'payment'};
    String updatedMerchant = existing.merchant;
    if (genericMerchants.contains(existing.merchant.toLowerCase().trim()) &&
        sms.payee != null &&
        sms.payee!.isNotEmpty) {
      updatedMerchant = sms.payee!;
    }

    // Update payment method to mapped source if available
    final updatedPaymentMethod = (sms.selectedPaymentSource != null && sms.selectedPaymentSource!.isNotEmpty)
        ? sms.selectedPaymentSource!
        : existing.paymentMethod;

    return existing.copyWith(
      merchant: updatedMerchant,
      notes: enrichedNotes,
      paymentMethod: updatedPaymentMethod,
      needsVerification: false, // Bank verified!
    );
  }

  /// Fetches SMS messages from the device inbox, filters by allowed senders,
  /// parses all financial transactions, maps them to available payment sources,
  /// and detects duplicates against existing ledger transactions.
  static Future<List<ParsedSmsTransaction>> scanAndParseInbox({
    int limit = 200,
    DateTime? since,
    List<String>? availableSources,
    List<ExpenseTransaction>? existingTransactions,
  }) async {
    final rawMessages = await fetchInboxSms(limit: limit, since: since);
    final savedPrefs = await loadSourcePreferences();
    final results = <ParsedSmsTransaction>[];

    for (final msg in rawMessages) {
      final address = (msg['address'] as String?)?.trim() ?? '';
      final body = (msg['body'] as String?)?.trim() ?? '';
      final dateMs = (msg['date'] as num?)?.toInt();
      final date = dateMs != null ? DateTime.fromMillisecondsSinceEpoch(dateMs) : null;

      if (body.isEmpty) continue;
      if (!isAllowedSmsSender(address)) continue;

      final parsed = parse(body, sender: address, date: date);
      if (parsed.isFinancial && parsed.amount != null && parsed.amount! > 0) {
        // Map to payment source
        final mappedSource = availableSources != null && availableSources.isNotEmpty
            ? mapToPaymentSource(parsed, availableSources, savedPreferences: savedPrefs)
            : parsed.accountType == 'CREDIT_CARD' ? 'Credit Card' : 'Bank Account';

        // Check duplicates
        final duplicateMatch = existingTransactions != null
            ? findDuplicateMatch(parsed, existingTransactions)
            : const SmsDuplicateMatch(status: DuplicateStatus.none, reason: '');

        // Default accept and merge state
        final isAccepted = !duplicateMatch.isExact;
        final mergeWithExisting = duplicateMatch.isPotential;

        results.add(parsed.copyWith(
          selectedPaymentSource: mappedSource,
          duplicateMatch: duplicateMatch,
          isAccepted: isAccepted,
          mergeWithExisting: mergeWithExisting,
        ));
      }
    }

    return results;
  }

  /// Parses an arbitrary batch of raw SMS maps `{ 'address': ..., 'body': ..., 'date': ... }`.
  static List<ParsedSmsTransaction> parseBatch(
    List<Map<String, dynamic>> rawMessages, {
    List<String>? availableSources,
    List<ExpenseTransaction>? existingTransactions,
    Map<String, String>? savedPreferences,
  }) {
    final results = <ParsedSmsTransaction>[];
    for (final msg in rawMessages) {
      final address = (msg['address'] as String?)?.trim() ?? '';
      final body = (msg['body'] as String?)?.trim() ?? '';
      final dateMs = (msg['date'] as num?)?.toInt();
      final date = dateMs != null ? DateTime.fromMillisecondsSinceEpoch(dateMs) : null;

      if (body.isEmpty) continue;
      if (address.isNotEmpty && !isAllowedSmsSender(address)) continue;

      final parsed = parse(body, sender: address.isNotEmpty ? address : null, date: date);
      if (parsed.isFinancial && parsed.amount != null && parsed.amount! > 0) {
        final mappedSource = availableSources != null && availableSources.isNotEmpty
            ? mapToPaymentSource(parsed, availableSources, savedPreferences: savedPreferences)
            : parsed.accountType == 'CREDIT_CARD' ? 'Credit Card' : 'Bank Account';

        final duplicateMatch = existingTransactions != null
            ? findDuplicateMatch(parsed, existingTransactions)
            : const SmsDuplicateMatch(status: DuplicateStatus.none, reason: '');

        final isAccepted = !duplicateMatch.isExact;
        final mergeWithExisting = duplicateMatch.isPotential;

        results.add(parsed.copyWith(
          selectedPaymentSource: mappedSource,
          duplicateMatch: duplicateMatch,
          isAccepted: isAccepted,
          mergeWithExisting: mergeWithExisting,
        ));
      }
    }
    return results;
  }

  /// Imports and merges a list of [ParsedSmsTransaction] into TallyTap database.
  /// Handles both adding new records and merging with existing manual records.
  static Future<int> importTransactions(
    List<ParsedSmsTransaction> parsedList,
    TransactionListNotifier notifier, {
    List<ExpenseTransaction>? existingTransactions,
  }) async {
    if (parsedList.isEmpty) return 0;
    await notifier.ensureLoaded();

    final toAdd = <ExpenseTransaction>[];
    int processedCount = 0;

    for (final parsed in parsedList) {
      if (!parsed.isFinancial || parsed.amount == null || parsed.amount! <= 0) continue;
      if (!parsed.isAccepted) continue; // User rejected this item

      if (parsed.mergeWithExisting && parsed.duplicateMatch?.matchedTransaction != null) {
        // MERGE: Update the existing manual record in-place with bank verification
        final mergedTx = mergeTransaction(parsed.duplicateMatch!.matchedTransaction!, parsed);
        await notifier.updateTransaction(mergedTx);
        processedCount++;
      } else {
        // NEW: Insert as a fresh transaction
        final tx = parsed.toExpenseTransaction();
        toAdd.add(tx);
        processedCount++;
      }
    }

    if (toAdd.isNotEmpty) {
      await notifier.addTransactions(toAdd);
    }
    return processedCount;
  }
}
