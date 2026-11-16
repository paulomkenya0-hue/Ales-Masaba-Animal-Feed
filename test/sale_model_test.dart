import 'package:flutter_test/flutter_test.dart';
import 'package:ales_masaba_feed/data/models/sale_model.dart';

SaleItemModel _item(String id, double qty, double price) => SaleItemModel(
      productId: id,
      productName: id,
      quantity: qty,
      unitPrice: price,
      subtotal: qty * price,
    );

void main() {
  test('Mfano wa Juma: jumla 60,000, kilicholipwa 50,000, deni 10,000', () {
    final items = [_item('Pumba', 20, 1000), _item('Ufuta', 5, 3000), _item('Karanga', 10, 2500)];
    final total = items.fold<double>(0, (s, i) => s + i.subtotal);
    expect(total, 60000);

    final sale = SaleModel(
      receiptNumber: 'AMAF-20261115-0001',
      totalAmount: total,
      paymentMethod: PayMethod.cash,
      saleDate: DateTime(2026, 11, 15).toIso8601String(),
      items: items,
      amountPaid: 50000,
    );
    expect(sale.balance, 10000);
    expect(sale.hasDebt, isTrue);
    expect(sale.paymentStatus, 'Sehemu');
  });

  test('Mauzo ya zamani bila amount_paid yanasomwa kwa usahihi', () {
    final cash = SaleModel.fromMap({
      'receipt_number': 'A',
      'total_amount': 5000,
      'payment_method': 'Fedha Taslimu',
      'sale_date': '2026-01-01T10:00:00.000',
    });
    expect(cash.amountPaid, 5000);
    expect(cash.balance, 0);

    final credit = SaleModel.fromMap({
      'receipt_number': 'B',
      'total_amount': 5000,
      'payment_method': 'Mkopo',
      'sale_date': '2026-01-01T10:00:00.000',
    });
    expect(credit.amountPaid, 0);
    expect(credit.balance, 5000);
    expect(credit.paymentStatus, 'Deni');
  });

  test('copyWith inahesabu upya jumla ya mstari', () {
    final updated = _item('Pumba', 20, 1000).copyWith(quantity: 25);
    expect(updated.subtotal, 25000);
  });
}
