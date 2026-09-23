/// Kur PAGUAJ rrit totalin e kamarierit (PRINTO), dhe kur jo.
bool shouldAddPaymentToPrintTotal({
  required bool tableOccupied,
  required bool hasPrintedOrderLines,
  required bool hasUnprintedCartLines,
}) {
  // Tavolinë e hapur / tashmë e printuar: totali u numërua në PRINTO.
  if (tableOccupied || hasPrintedOrderLines) return false;
  // Porosi e re, pa PRINTO: PAGUAJ e shton llogarinë në total.
  return hasUnprintedCartLines;
}
