import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Observa pressão de memória do SO e limpa caches de imagem.
///
/// Sem WebViews no projeto, o maior consumidor de RAM são as imagens em
/// cache — este observer as descarta quando o sistema pede.
class MemoryMonitor with WidgetsBindingObserver {
  static final MemoryMonitor _instance = MemoryMonitor._();
  factory MemoryMonitor() => _instance;
  MemoryMonitor._();

  void attach() => WidgetsBinding.instance.addObserver(this);
  void detach() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didHaveMemoryPressure() {
    // Limpa caches de imagem (memória); o disco é gerenciado pelo plugin
    // cached_network_image automaticamente.
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    debugPrint('[MemoryMonitor] pressão de memória: caches de imagem limpos');
  }
}
