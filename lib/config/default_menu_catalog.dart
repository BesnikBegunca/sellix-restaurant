import 'package:flutter/material.dart';

/// Menu e paracaktuar me foto nga [assets/images/].
///
/// ID-të fillojnë me [kIdPrefix] — fshihen nga menaxheri (me konfirmim);
/// pas fshirjes nuk ri-shtohen automatikisht.
class DefaultMenuCatalog {
  DefaultMenuCatalog._();

  static const String kIdPrefix = 'default_';

  static bool isBuiltinCategoryId(String id) => id.startsWith(kIdPrefix);
  static bool isBuiltinProductId(String id) => id.startsWith(kIdPrefix);

  static Set<String> get builtinCategoryIds =>
      categories.map((c) => c.id).toSet();

  static Set<String> get builtinProductIds =>
      products.map((p) => p.id).toSet();

  static const List<DefaultCategoryDef> categories = [
    DefaultCategoryDef(
      id: '${kIdPrefix}cat_kafe',
      name: 'Kafe',
      iconCodePoint: Icons.local_cafe_outlined,
      sortOrder: 0,
    ),
    DefaultCategoryDef(
      id: '${kIdPrefix}cat_pije',
      name: 'Pije',
      iconCodePoint: Icons.local_drink_outlined,
      sortOrder: 1,
    ),
    DefaultCategoryDef(
      id: '${kIdPrefix}cat_alkool',
      name: 'Alkoholike',
      iconCodePoint: Icons.liquor_outlined,
      sortOrder: 2,
    ),
    DefaultCategoryDef(
      id: '${kIdPrefix}cat_shots',
      name: 'Shots',
      iconCodePoint: Icons.wine_bar_outlined,
      sortOrder: 3,
    ),
    DefaultCategoryDef(
      id: '${kIdPrefix}cat_cocktails',
      name: 'Cocktails',
      iconCodePoint: Icons.local_bar_outlined,
      sortOrder: 4,
    ),
  ];

  static const List<DefaultProductDef> products = [
    // ── Kafe (renditja dhe çmimet nga menu parazgjedhure) ─────────────────
    DefaultProductDef(
      id: '${kIdPrefix}prod_espresso',
      name: 'Espreso',
      categoryId: '${kIdPrefix}cat_kafe',
      price: 1.00,
      emoji: '☕',
      imagePath: 'assets/images/espreso.webp',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_makiato',
      name: 'Makiato',
      categoryId: '${kIdPrefix}cat_kafe',
      price: 1.00,
      emoji: '☕',
      imagePath: 'assets/images/machiato.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_ice_coffe',
      name: 'Ice Coffe',
      categoryId: '${kIdPrefix}cat_kafe',
      price: 1.00,
      emoji: '🧊',
      imagePath: 'assets/images/ice coffe.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_kapuqino',
      name: 'Kapuqino',
      categoryId: '${kIdPrefix}cat_kafe',
      price: 1.00,
      emoji: '☕',
      imagePath: 'assets/images/capuchino.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_latte',
      name: 'Latte Coffe',
      categoryId: '${kIdPrefix}cat_kafe',
      price: 1.00,
      emoji: '☕',
      imagePath: 'assets/images/latte coffe.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_frappe',
      name: 'Frappe',
      categoryId: '${kIdPrefix}cat_kafe',
      price: 1.50,
      emoji: '🥤',
      imagePath: 'assets/images/frappe.png',
    ),

    // ── Pije (renditja dhe çmimet nga menu parazgjedhure) ─────────────────
    DefaultProductDef(
      id: '${kIdPrefix}prod_lengje',
      name: 'Lengje',
      categoryId: '${kIdPrefix}cat_pije',
      price: 1.00,
      emoji: '🧃',
      imagePath: 'assets/images/leng.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_coca_cola',
      name: 'Coca Cola',
      categoryId: '${kIdPrefix}cat_pije',
      price: 1.00,
      emoji: '🥤',
      imagePath: 'assets/images/cocacola.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_coca_cola_zero',
      name: 'Coca Cola Zero',
      categoryId: '${kIdPrefix}cat_pije',
      price: 1.00,
      emoji: '🥤',
      imagePath: 'assets/images/zero.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_fanta',
      name: 'Fanta',
      categoryId: '${kIdPrefix}cat_pije',
      price: 1.00,
      emoji: '🥤',
      imagePath: 'assets/images/fanta.webp',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_sprite',
      name: 'Sprite',
      categoryId: '${kIdPrefix}cat_pije',
      price: 1.00,
      emoji: '🥤',
      imagePath: 'assets/images/sprite.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_schweppes',
      name: 'Schweppes',
      categoryId: '${kIdPrefix}cat_pije',
      price: 1.00,
      emoji: '🥤',
      imagePath: 'assets/images/bitter lemon.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_schweppes_tonic',
      name: 'Tonic',
      categoryId: '${kIdPrefix}cat_pije',
      price: 1.00,
      emoji: '🥤',
      imagePath: 'assets/images/tonic.webp',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_golden_eagle',
      name: 'Golden Eagle',
      categoryId: '${kIdPrefix}cat_pije',
      price: 1.00,
      emoji: '🥤',
      imagePath: 'assets/images/goldeneagle.webp',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_red_bull',
      name: 'Redbull',
      categoryId: '${kIdPrefix}cat_pije',
      price: 3.00,
      emoji: '🥤',
      imagePath: 'assets/images/redbull.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_lemon_soda',
      name: 'Lemon Soda',
      categoryId: '${kIdPrefix}cat_pije',
      price: 1.00,
      emoji: '🥤',
      imagePath: 'assets/images/lemonsoda.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_orange_soda',
      name: 'Orange Soda',
      categoryId: '${kIdPrefix}cat_pije',
      price: 1.00,
      emoji: '🥤',
      imagePath: 'assets/images/orangesoda.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_mojito_soda',
      name: 'Mojito Soda',
      categoryId: '${kIdPrefix}cat_pije',
      price: 1.00,
      emoji: '🥤',
      imagePath: 'assets/images/mojitosoda.png',
    ),

    // ── Alkoholike (renditja dhe çmimet nga menu parazgjedhure) ───────────
    DefaultProductDef(
      id: '${kIdPrefix}prod_peja',
      name: 'Peja',
      categoryId: '${kIdPrefix}cat_alkool',
      price: 1.50,
      emoji: '🍺',
      imagePath: 'assets/images/peja.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_shkup',
      name: 'Shkup',
      categoryId: '${kIdPrefix}cat_alkool',
      price: 1.50,
      emoji: '🍺',
      imagePath: 'assets/images/shkupi.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_tuborg',
      name: 'Tuborg',
      categoryId: '${kIdPrefix}cat_alkool',
      price: 2.00,
      emoji: '🍺',
      imagePath: 'assets/images/tuborg.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_lasko',
      name: 'Lasko',
      categoryId: '${kIdPrefix}cat_alkool',
      price: 2.00,
      emoji: '🍺',
      imagePath: 'assets/images/llashko.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_heineken',
      name: 'Henieken',
      categoryId: '${kIdPrefix}cat_alkool',
      price: 3.00,
      emoji: '🍺',
      imagePath: 'assets/images/heineken.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_corona',
      name: 'Corona',
      categoryId: '${kIdPrefix}cat_alkool',
      price: 4.00,
      emoji: '🍺',
      imagePath: 'assets/images/corona.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_carlsberg',
      name: 'Charlsberg',
      categoryId: '${kIdPrefix}cat_alkool',
      price: 3.00,
      emoji: '🍺',
      imagePath: 'assets/images/carlsberg.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_desperado',
      name: 'Desperado',
      categoryId: '${kIdPrefix}cat_alkool',
      price: 4.00,
      emoji: '🍺',
      imagePath: 'assets/images/desperados.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_vodka_shishe',
      name: 'Vodka',
      categoryId: '${kIdPrefix}cat_alkool',
      price: 3.00,
      emoji: '🍾',
      imagePath: 'assets/images/smirnof.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_gin_shishe',
      name: 'Gin',
      categoryId: '${kIdPrefix}cat_alkool',
      price: 3.00,
      emoji: '🍾',
      imagePath: 'assets/images/gin.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_whiskey_shishe',
      name: 'Whiskey',
      categoryId: '${kIdPrefix}cat_alkool',
      price: 4.00,
      emoji: '🍾',
      imagePath: 'assets/images/jackdaniels.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_scotch_whiskey_shishe',
      name: 'Scotch Whiskey',
      categoryId: '${kIdPrefix}cat_alkool',
      price: 4.00,
      emoji: '🍾',
      imagePath: 'assets/images/redlabel.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_cognac_shishe',
      name: 'Cognac',
      categoryId: '${kIdPrefix}cat_alkool',
      price: 3.00,
      emoji: '🍾',
      imagePath: 'assets/images/hennessy.png',
    ),

    // ── Shots ─────────────────────────────────────────────────────────────
    DefaultProductDef(
      id: '${kIdPrefix}prod_tequila_shot',
      name: 'Tequila',
      categoryId: '${kIdPrefix}cat_shots',
      price: 3.00,
      emoji: '🥃',
      imagePath: 'assets/images/tekilla.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_b52',
      name: 'B52',
      categoryId: '${kIdPrefix}cat_shots',
      price: 3.00,
      emoji: '🥃',
      imagePath: 'assets/images/b52.webp',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_kamikaz',
      name: 'Kamikaz',
      categoryId: '${kIdPrefix}cat_shots',
      price: 3.00,
      emoji: '🥃',
      imagePath: 'assets/images/kamikaze.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_kamikaz_green',
      name: 'Kamikaz Green',
      categoryId: '${kIdPrefix}cat_shots',
      price: 3.00,
      emoji: '🥃',
      imagePath: 'assets/images/kamikazegreen.png',
    ),

    // ── Cocktails (renditja dhe çmimet nga menu parazgjedhure) ──────────────
    DefaultProductDef(
      id: '${kIdPrefix}prod_koktell_me_alkool',
      name: 'Koktell Me alkool',
      categoryId: '${kIdPrefix}cat_cocktails',
      price: 3.00,
      emoji: '🍹',
      imagePath: 'assets/images/mealkool.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_koktell_pa_alkool',
      name: 'Koktell Pa alkool',
      categoryId: '${kIdPrefix}cat_cocktails',
      price: 2.00,
      emoji: '🍹',
      imagePath: 'assets/images/paalkool.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_mojito_cocktail',
      name: 'Mojito',
      categoryId: '${kIdPrefix}cat_cocktails',
      price: 3.00,
      emoji: '🍹',
      imagePath: 'assets/images/mojito.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_sex_on_the_beach',
      name: 'Sex on the beach',
      categoryId: '${kIdPrefix}cat_cocktails',
      price: 3.00,
      emoji: '🍹',
      imagePath: 'assets/images/sexonthebeach.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_whiskey_sour',
      name: 'Whiskey Sour',
      categoryId: '${kIdPrefix}cat_cocktails',
      price: 4.00,
      emoji: '🍸',
      imagePath: 'assets/images/Whiskey Sour.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_blue_lagoon',
      name: 'Blue Lagoon',
      categoryId: '${kIdPrefix}cat_cocktails',
      price: 4.00,
      emoji: '🍹',
      imagePath: 'assets/images/Blue Lagoon.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_long_island',
      name: 'Long Island Ice Tea',
      categoryId: '${kIdPrefix}cat_cocktails',
      price: 3.00,
      emoji: '🍹',
      imagePath: 'assets/images/Long Island Ice tea.png',
    ),
    DefaultProductDef(
      id: '${kIdPrefix}prod_qaj',
      name: 'Qaj',
      categoryId: '${kIdPrefix}cat_kafe',
      price: 1.00,
      emoji: '🍵',
      imagePath: 'assets/images/qaj.png',
    ),
  ];
}

class DefaultCategoryDef {
  const DefaultCategoryDef({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final IconData iconCodePoint;
  final int sortOrder;
}

class DefaultProductDef {
  const DefaultProductDef({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.price,
    required this.emoji,
    required this.imagePath,
  });

  final String id;
  final String name;
  final String categoryId;
  final double price;
  final String emoji;
  final String imagePath;
}
