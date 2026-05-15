import '../../../models/mock_data.dart';

class CartLine {
  CartLine({required this.product});

  final ProductItem product;
  int qty = 1;
}
