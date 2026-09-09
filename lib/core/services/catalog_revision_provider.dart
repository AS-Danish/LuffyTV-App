import 'package:flutter_riverpod/flutter_riverpod.dart';

class CatalogRevision extends Notifier<int> {
  @override
  int build() => 0;
  void changed() => state++;
}

final catalogRevisionProvider = NotifierProvider<CatalogRevision, int>(
  CatalogRevision.new,
);
