import 'package:url_launcher/url_launcher.dart';

/// Consulta de medicamentos a una farmacia por WhatsApp. La app solo abre el
/// chat con el mensaje escrito: el usuario decide si lo envía.
abstract class WhatsAppServicio {
  /// Abre el chat de [numero] (591 + celular). Devuelve false si no se pudo.
  Future<bool> abrirChat(String numero, String mensaje);
}

/// Enlace oficial "clic para chatear" de WhatsApp.
Uri enlaceWhatsApp(String numero, String mensaje) =>
    Uri.parse('https://wa.me/$numero?text=${Uri.encodeComponent(mensaje)}');

/// Texto que aparece ya escrito en el chat de la farmacia.
String mensajeCompra(String farmacia, String medicamento) =>
    'Hola, $farmacia. Les escribo desde SaludCerca.\n'
    'Quiero comprar este medicamento: ${medicamento.trim()}.\n'
    '¿Lo tienen disponible y cuál es su precio?';

class UrlWhatsAppServicio implements WhatsAppServicio {
  @override
  Future<bool> abrirChat(String numero, String mensaje) async {
    try {
      return await launchUrl(enlaceWhatsApp(numero, mensaje),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
