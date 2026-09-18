import 'package:flutter/widgets.dart';

import 'app_locale_controller.dart';

/// Hand-rolled translation lookup for SafeStep's highest-stakes strings —
/// the ones a student under stress needs to understand correctly (SOS,
/// core navigation, the onboarding/terms safety disclaimer). This is a
/// first phase of multi-language support, not full coverage: the rest of
/// the app's screens still read in English regardless of the selected
/// language until translated.
///
/// IMPORTANT: translations below (af/tn/ve/ts/zu) are a best-effort draft,
/// not verified by a native speaker of each language. Before relying on
/// these for a real user in a real emergency, every string here needs
/// review by a fluent/native speaker — shipping an unverified safety
/// message in the wrong register or with a mistranslation would be worse
/// than staying in English. Flagged here, not hidden, per the project's
/// own "no false confidence" principle (docs/scope.md §8).
const _strings = <String, Map<String, String>>{
  'nav_home': {
    'en': 'Home', 'af': 'Tuis', 'tn': 'Gae', 've': 'Hayani', 'ts': 'Ekaya', 'zu': 'Ekhaya',
  },
  'nav_map': {
    'en': 'Map', 'af': 'Kaart', 'tn': 'Mmapa', 've': 'Bammbo', 'ts': 'Mapa', 'zu': 'Ibalazwe',
  },
  'nav_profile': {
    'en': 'Profile', 'af': 'Profiel', 'tn': 'Porofaele', 've': 'Porofaele', 'ts': 'Phurofayili', 'zu': 'Iphrofayela',
  },
  'sos_hold_label': {
    'en': 'Hold for help',
    'af': 'Hou vas vir hulp',
    'tn': 'Tshwara go bata thuso',
    've': 'Fara u itoda thuso',
    'ts': 'Khoma u lava mpfuno',
    'zu': 'Bamba ufune usizo',
  },
  'sos_help_sent': {
    'en': 'Help request sent',
    'af': 'Hulpversoek gestuur',
    'tn': 'Kopo ya thuso e rometswe',
    've': 'Khumbelo ya thuso yo rumelwa',
    'ts': 'Xikombelo xa mpfuno xi rhumeriwile',
    'zu': 'Isicelo sosizo sithunyelwe',
  },
  'sos_stay_put': {
    'en': 'Stay where you are if it is safe to do so',
    'af': 'Bly waar jy is as dit veilig is',
    'tn': 'Nna fa o leng teng fa go sireletsegile',
    've': 'Sala hune wa vha hone arali zwo tshirwa',
    'ts': 'Tshama laha u nga kona loko swi hlayisekile',
    'zu': 'Hlala lapho ukhona uma kuphephile',
  },
  'sos_end_alert': {
    'en': "I'm safe now — end alert",
    'af': "Ek is nou veilig — beëindig waarskuwing",
    'tn': 'Ke sireletsegile jaanong — khutlisa tlhagiso',
    've': 'Ndi khwaṱhisea zwino — fhedza tsevho',
    'ts': 'Ndzi hlayisekile sweswi — herisa xitsundzuxo',
    'zu': 'Ngiphephile manje — qeda isexwayiso',
  },
  'sos_false_alarm': {
    'en': 'This was accidental — false alarm',
    'af': 'Dit was per ongeluk — vals alarm',
    'tn': 'Se, e ne e le phoso — tlhagiso ya maaka',
    've': 'Yo vha khakhea — tsevho ya mazwifhi',
    'ts': 'Leswi swi endlekile hi ku hlanganisa — xitsundzuxo xa mavunwa',
    'zu': 'Lokhu bekuyingozi — ukuxwayisa okungamanga',
  },
  'danger_zone_label': {
    'en': 'Danger zone',
    'af': 'Gevaarsone',
    'tn': 'Sekgoa sa kotsi',
    've': 'Bammbo ḽa khombo',
    'ts': 'Xifundzha xa khombo',
    'zu': 'Indawo eyingozi',
  },
  'terms_disclaimer': {
    'en': 'SafeStep is a prototype. It does not replace calling real '
        'emergency services. In a genuine emergency, always contact '
        'official campus security or emergency services directly.',
    'af': 'SafeStep is \'n prototipe. Dit vervang nie werklike '
        'nooddienste nie. In \'n regte noodgeval, kontak altyd amptelike '
        'kampussekuriteit of nooddienste direk.',
    'tn': 'SafeStep ke mothale wa tekolo. Ga e emele go leletsa '
        'ditirelo tsa maemo a tshoganyetso tsa nnete. Fa go na le maemo a '
        'tshoganyetso, ikgolaganye ka metlha le tshireletsego ya khamphase '
        'kgotsa ditirelo tsa tshoganyetso ka tlhamalalo.',
    've': 'SafeStep ndi tshiedziswa. A i shandukisi u vhidza vhurangaphanḓa '
        'ha khombo ha vhukuma. Kha khombo ya vhukuma, dzhia phiri na '
        'vhulindi ha yunivesithi kana vhurangaphanḓa ha khombo nga '
        'ndilelo.',
    'ts': 'SafeStep i xikombelo xo kambela. A yi siveli ku vitana '
        'vurhangeri bya xiyimo xa mhaka-kulu bya xiviri. Loko ku ri ni '
        'xiyimo xa mhaka-kulu xa xiviri, tshama u vitana vurhangeri bya '
        'nsirhelelo bya khampasi kumbe vurhangeri bya xiyimo xa mhaka-kulu '
        'hi ku kongoma.',
    'zu': 'I-SafeStep iyisibonelo. Ayifaki esikhundleni sokushayela '
        'izinsizakalo zezimo eziphuthumayo zangempela. Uma kunesimo '
        'esiphuthumayo sangempela, hlala uxhumana ngokuqondile nezokuphepha '
        'zasekhampasi noma izinsizakalo zezimo eziphuthumayo.',
  },
};

/// Looks up [key] in the currently selected app language, falling back to
/// English, then to the raw key if even English is missing (should never
/// happen for a key defined above).
String tr(String key) {
  final locale = AppLocaleController.instance.value?.languageCode ?? 'en';
  final entry = _strings[key];
  if (entry == null) return key;
  return entry[locale] ?? entry['en'] ?? key;
}

/// Convenience for use directly in a `Text(trContext(context, 'key'))`
/// call — rebuilds when the language changes if wrapped in a
/// ValueListenableBuilder on [AppLocaleController.instance], same as
/// theme/font-scale usage elsewhere in the app.
String trContext(BuildContext context, String key) => tr(key);
