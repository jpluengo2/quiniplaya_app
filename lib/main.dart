// === IMPORTACIONES CLAVE ===
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; // === NUEVO: Librería para conexiones a Internet ===

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]).then((_) {
      runApp(const QuiniplayaApp());
    });
  } else {
    runApp(const QuiniplayaApp());
  }
}

class QuiniplayaApp extends StatelessWidget {
  const QuiniplayaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiniplaya Millonaria',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Arial',
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final double altoFijo1 = 340.0; 
  final double altoFijo2 = 485.0; 

  Map<String, dynamic>? jsonData;
  
  // === EXPLICACIÓN: NUEVOS ESTADOS DE CARGA (SPLASH SCREEN) ===
  bool isReady = false; // Controla si mostramos la pantalla de carga o el programa principal
  bool hasError = false; // Controla si hubo un fallo de internet
  String errorMessage = ""; // El mensaje formal de error
  String loadingMessage = "Iniciando sistema..."; // Texto dinámico de la barra
  double loadingProgress = 0.0; // Relleno de la barra de progreso (de 0.0 a 1.0)

  List<String> resultados = List.filled(14, '0');
  late SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    _inicializarAppYDescargar(); // Arrancamos el nuevo motor con internet
  }

  // === EXPLICACIÓN: MOTOR DE DESCARGA DESDE DROPBOX ===
  Future<void> _inicializarAppYDescargar() async {
    // 1. Reseteamos el estado visual al empezar
    String responseBodyForDebugging = "No se llegó a recibir respuesta del servidor.";

    setState(() {
      hasError = false;
      loadingProgress = 0.1;
      loadingMessage = "Estableciendo conexión segura con el servidor...";
    });

    try {
      // Conectamos a la memoria local
      prefs = await SharedPreferences.getInstance();

      // === UX TRICK: MICRO-PAUSAS ===
      // Añadimos pequeñas demoras visuales. Si internet es muy rápido, el usuario 
      // apenas vería los textos y parecería un parpadeo feo. Esto le da elegancia.
      await Future.delayed(const Duration(milliseconds: 800)); 

      setState(() {
        loadingProgress = 0.4;
        loadingMessage = "Descargando datos de la jornada en curso...";
      });

      // === TU ENLACE DE DROPBOX (MODIFICADO dl=1) ===
      //final String urlDropbox = "https://www.dropbox.com/scl/fi/d5bp0vgwuv36eaoug1b6c/jornada.json?rlkey=42wxfnlekmy7bf1vwnyq791bv&st=naitdf0m&dl=1";
      
      // Y esta es su conversión a enlace de contenido directo (sin 'st' ni 'dl' y con el dominio cambiado para evitar errores CORS):
      final String urlDropbox = 'https://dl.dropboxusercontent.com/scl/fi/d5bp0vgwuv36eaoug1b6c/jornada.json?rlkey=42wxfnlekmy7bf1vwnyq791bv';

      // Hacemos la petición GET con un tiempo límite de 15 segundos
      final response = await http.get(Uri.parse(urlDropbox)).timeout(const Duration(seconds: 15));
      responseBodyForDebugging = utf8.decode(response.bodyBytes); // Guardamos el cuerpo para depuración

      if (response.statusCode == 200) {
        // La descarga fue un éxito
        setState(() {
          loadingProgress = 0.7;
          loadingMessage = "Procesando y estructurando la información...";
        });
        
        await Future.delayed(const Duration(milliseconds: 600)); 
        
        final String jsonString = responseBodyForDebugging;
        final data = json.decode(jsonString);

        // Lógica Inteligente de Cambio de Jornada
        String jornadaJson = data['datosGenerales']['numeroJornada'];
        String? jornadaGuardada = prefs.getString('jornadaActual');

        if (jornadaGuardada != jornadaJson) {
          await prefs.setString('jornadaActual', jornadaJson);
          await prefs.remove('resultadosPartidos');
          resultados = List.filled(14, '0');
        } else {
          List<String>? guardados = prefs.getStringList('resultadosPartidos');
          if (guardados != null && guardados.length == 14) {
            resultados = guardados;
          }
        }

        // === FASE DE ÉXITO ===
        setState(() {
          jsonData = data;
          loadingProgress = 1.0; // Barra llena
          loadingMessage = "¡Carga completada satisfactoriamente!";
        });

        // Dejamos que el usuario lea el mensaje de éxito durante 1.5 segundos
        await Future.delayed(const Duration(milliseconds: 1500));

        // Damos paso a la aplicación principal
        setState(() {
          isReady = true; 
        });

        // Saludamos o pedimos el nombre
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _gestionarUsuario();
        });

      } else {
        // Si Dropbox responde pero con un error (ej. Enlace caducado)
        _mostrarError("Se ha producido un error en el servidor (Código: ${response.statusCode}).\n\nContenido recibido:\n$responseBodyForDebugging");
      }
    } on FormatException catch (e, stackTrace) {
      // CAPTURA ESPECÍFICA: El servidor respondió, pero con algo que no es un JSON válido (ej. una página de error HTML)
      log('FormatException: El servidor devolvió un contenido que no es JSON válido.', name: 'DropboxConnection', error: e, stackTrace: stackTrace);
      log('Contenido recibido del servidor:\n$responseBodyForDebugging');
      _mostrarError(
        "Error de Formato: El servidor no devolvió los datos esperados.\n"
        "Esto es lo que se recibió (puede ser una página de error de Dropbox):\n"
        "------------------------------------\n"
        "$responseBodyForDebugging\n"
        "------------------------------------"
      );
    } catch (e, stackTrace) {
      // CAPTURA GENÉRICA: Fallos de red (sin internet, timeout, etc.)
      log('Error detallado durante la descarga:', name: 'DropboxConnection', error: e, stackTrace: stackTrace);

      // Y también mostraremos un mensaje más útil en la pantalla de error.
      _mostrarError("No se ha podido establecer conexión.\nCausa técnica: ${e.runtimeType}\nPor favor, compruebe su acceso a internet y reinicie la app.");
    }
  }

  // Función auxiliar para actualizar la UI con un error
  void _mostrarError(String mensaje) {
    setState(() {
      hasError = true;
      errorMessage = mensaje;
    });
  }

  // === (LÓGICA DE USUARIO Y DIÁLOGOS SIN CAMBIOS) ===
  void _gestionarUsuario() {
    String? nombre = prefs.getString('apodoUsuario');
    if (nombre == null || nombre.isEmpty) {
      _pedirNombreUsuario();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Bienvenido de nuevo a Tu Quiniplaya Millonaria, $nombre!', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF080868), duration: const Duration(seconds: 4), behavior: SnackBarBehavior.floating,
        )
      );
    }
  }

  void _pedirNombreUsuario() {
    TextEditingController nameController = TextEditingController();
    showDialog(
      context: context, barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('¡Bienvenido a La Quiniplaya!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Para ofrecerte una experiencia personalizada, por favor, indícanos tu nombre o apodo:'),
              const SizedBox(height: 15),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  hintText: "Tu apodo aquí...", border: OutlineInputBorder(), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF080868), width: 2)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                String input = nameController.text.trim();
                if (input.isNotEmpty) {
                  Navigator.pop(context); _confirmarNombre(input);
                }
              },
              child: const Text('Siguiente', style: TextStyle(color: Color(0xFF080868), fontWeight: FontWeight.bold)),
            )
          ],
        );
      }
    );
  }

  void _confirmarNombre(String nombre) {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Confirmación de Registro', style: TextStyle(color: Color(0xFF080868), fontWeight: FontWeight.bold)),
          content: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black, fontSize: 16, fontFamily: 'Arial'),
              children: [
                const TextSpan(text: '¿Estás seguro de que quieres utilizar el apodo '),
                TextSpan(text: '"$nombre"', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                const TextSpan(text: '?\n\nTen en cuenta que este apodo quedará registrado de forma permanente en tu dispositivo para saludarte en cada jornada.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () { Navigator.pop(context); _pedirNombreUsuario(); },
              child: const Text('Corregir', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await prefs.setString('apodoUsuario', nombre);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('¡Registro completado! Bienvenido, $nombre.', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), backgroundColor: Colors.green.shade700, behavior: SnackBarBehavior.floating));
              },
              child: const Text('Confirmar y Entrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        );
      }
    );
  }

  void _actualizarResultado(int index, String valor) {
    setState(() { resultados[index] = valor; });
    prefs.setStringList('resultadosPartidos', resultados);
  }

  // === EXPLICACIÓN: CONSTRUCTOR DE LA UI PRINCIPAL ===
  @override
  Widget build(BuildContext context) {
    // 1. ¿Está listo? Si NO, mostramos Pantalla de Carga o Pantalla de Error
    if (!isReady) {
      if (hasError) {
        return Scaffold(body: SafeArea(child: _buildErrorScreen()));
      } else {
        return Scaffold(body: SafeArea(child: _buildLoadingScreen()));
      }
    }

    // 2. Si está listo (isReady == true), construimos el programa general
    bool esFallos = jsonData!['datosGenerales']['tipoJornada'] == "Fallos";
    Map<int, int> recuentoGlobal = {for (int i = 0; i <= 14; i++) i: 0};
    
    List<String> todasLasApuestas = List<String>.from(jsonData!['apuestasBase'] ?? []);
    if (esFallos) { todasLasApuestas.addAll(List<String>.from(jsonData!['apuestasFallos'] ?? [])); }

    for (String apuesta in todasLasApuestas) {
      int aciertos = 0;
      for (int i = 0; i < 14; i++) {
        if (resultados[i] != '0' && i < apuesta.length && apuesta[i] == resultados[i]) aciertos++;
      }
      recuentoGlobal[aciertos] = (recuentoGlobal[aciertos] ?? 0) + 1;
    }

    Widget presentacion = PresentationBox(height: altoFijo1);
    Widget pronosticos = PronosticosBox(
      height: altoFijo2, 
      partidos: List<String>.from(jsonData!['partidos'] ?? []),
      pronosticosBase: List<String>.from(jsonData!['pronosticosBase'] ?? []),
      pronosticosFallos: List<String>.from(jsonData!['pronosticosFallos'] ?? []),
      resultados: resultados, onResultadoChanged: _actualizarResultado, recuentoGlobal: recuentoGlobal, 
    );
    Widget datosBase = GeneralDataBox(height: altoFijo1, datos: jsonData!['datosGenerales']);
    Widget boletoBase = BoletoBox(height: altoFijo2, titulo: 'Carrusel de Boletos Base', apuestas: List<String>.from(jsonData!['apuestasBase'] ?? []), resultados: resultados);

    Widget datosFallos = esFallos ? FallosDataBox(height: altoFijo1, datos: jsonData!['datosFallos']) : const SizedBox.shrink();
    Widget boletoFallos = esFallos ? BoletoBox(height: altoFijo2, titulo: 'Carrusel Boletos con Fallo', apuestas: List<String>.from(jsonData!['apuestasFallos'] ?? []), resultados: resultados) : const SizedBox.shrink();

    return Scaffold(
      body: SafeArea(
        child: kIsWeb 
          ? _buildWebView(esFallos, presentacion, pronosticos, datosBase, boletoBase, datosFallos, boletoFallos) 
          : _buildMobileView(context, esFallos, presentacion, pronosticos, datosBase, boletoBase, datosFallos, boletoFallos),
      ),
    );
  }

  // =====================================================================
  // NUEVO: DISEÑO DE LA PANTALLA DE CARGA (SPLASH SCREEN FORMAL)
  // =====================================================================
  Widget _buildLoadingScreen() {
    // Comprobamos si la carga es total (para pintar la barra de verde)
    bool isComplete = loadingProgress >= 1.0;

    return Center(
      child: Container(
        width: 400, // Ancho fijo y formal para la tarjeta de carga
        padding: const EdgeInsets.all(30.0),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(255, 248, 220, 1),
          borderRadius: BorderRadius.circular(15.0),
          border: Border.all(color: isComplete ? Colors.green : Colors.red, width: 3.0),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 5)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo
            ClipRRect(borderRadius: BorderRadius.circular(8.0), child: Image.asset('assets/dadoqpr.png', height: 80, fit: BoxFit.cover)),
            const SizedBox(height: 20),
            const Text('LA QUINIPLAYA MILLONARIA', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, color: Color.fromRGBO(207, 7, 7, 0.938), fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            
            // Textos de estado
            Text(loadingMessage, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: isComplete ? Colors.green.shade700 : const Color(0xFF080868), fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            
            // Barra de progreso y porcentaje
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: loadingProgress,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade300,
                      color: isComplete ? Colors.green : const Color(0xFF080868),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Transformamos 0.4 a "40%"
                Text("${(loadingProgress * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
              ],
            ),
            if (isComplete) ...[
               const SizedBox(height: 20),
               const Icon(Icons.check_circle, color: Colors.green, size: 40),
            ]
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // DISEÑO DE LA PANTALLA DE ERROR (Con prevención de Overflow)
  // =====================================================================
  Widget _buildErrorScreen() {
    return Center(
      // 1. Envolvemos todo en un Scroll para evitar el Bottom Overflow en pantallas pequeñas
      child: SingleChildScrollView(
        child: Container(
          width: 450,
          margin: const EdgeInsets.symmetric(vertical: 20.0), // Da un poco de aire arriba y abajo
          padding: const EdgeInsets.all(30.0),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 248, 220, 1),
            borderRadius: BorderRadius.circular(15.0),
            border: Border.all(color: Colors.red, width: 3.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 60),
              const SizedBox(height: 15),
              const Text('Fallo de Conexión o Lectura', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, color: Colors.red, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              // 2. Limitamos la altura del mensaje de error por si es un texto gigantesco
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8.0)
                ),
                child: SingleChildScrollView(
                  child: Text(
                    errorMessage, 
                    textAlign: TextAlign.center, 
                    style: const TextStyle(fontSize: 13, color: Color(0xFF080868), fontWeight: FontWeight.bold)
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF080868), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Reintentar Conexión', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: _inicializarAppYDescargar, 
              )
            ],
          ),
        ),
      ),
    );
  }

  // === CÓDIGO ESTRUCTURAL RESPONSIVE (SIN CAMBIOS) ===
  Widget _buildWebView(bool esFallos, Widget p1, Widget p2, Widget d1, Widget d2, Widget f1, Widget f2) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.start, spacing: 10.0, runSpacing: 10.0,
          children: [
            Column(mainAxisSize: MainAxisSize.min, children: [p1, const SizedBox(height: 10), p2]),
            Column(mainAxisSize: MainAxisSize.min, children: [d1, const SizedBox(height: 10), d2]),
            if (esFallos) Column(mainAxisSize: MainAxisSize.min, children: [f1, const SizedBox(height: 10), f2]),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileView(BuildContext context, bool esFallos, Widget p1, Widget p2, Widget d1, Widget d2, Widget f1, Widget f2) {
    List<Widget> paginas = [p1, d1];
    if (esFallos) paginas.add(f1);
    paginas.add(p2);
    paginas.add(d2);
    if (esFallos) paginas.add(f2);
    double availableHeight = MediaQuery.of(context).size.height - 20.0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: paginas.map((recuadro) {
          return Padding(padding: const EdgeInsets.only(right: 15.0), child: SizedBox(height: availableHeight, child: FittedBox(fit: BoxFit.contain, child: recuadro)));
        }).toList(),
      ),
    );
  }
}

// =====================================================================
// TODOS LOS DEMÁS FOTOGRAMAS / COMPONENTES QUEDAN EXACTAMENTE IGUAL
// (He condensado esta parte para asegurar la entrega sin cortes, ya que 
// la lógica y diseño de estos bloques no necesitó alteraciones).
// =====================================================================

class GridItemContainer extends StatelessWidget {
  final Widget child; final double? height;
  const GridItemContainer({super.key, required this.child, this.height});
  @override Widget build(BuildContext context) {
    return Container( width: 530.0, height: height, margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 5.0), padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0), decoration: BoxDecoration(color: const Color.fromRGBO(255, 248, 220, 1), border: Border.all(color: Colors.red, width: 2.5)), child: child);
  }
}

class PresentationBox extends StatelessWidget {
  final double height; const PresentationBox({super.key, required this.height});
  @override Widget build(BuildContext context) {
    return GridItemContainer(height: height, child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [const Text('LA QUINIPLAYA MILLONARIA', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, color: Color.fromRGBO(207, 7, 7, 0.938), fontWeight: FontWeight.bold)), const SizedBox(height: 20), ClipRRect(borderRadius: BorderRadius.circular(8.0), child: Image.asset('assets/dadoqpr.png', height: 100, fit: BoxFit.cover)), const SizedBox(height: 20), const Text('Sistema Combinatorio de Alto Rendimiento para Apuestas Deportivas', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Color(0xFF080868), fontWeight: FontWeight.bold))]));
  }
}

class GeneralDataBox extends StatelessWidget {
  final double height; final Map<String, dynamic> datos;
  const GeneralDataBox({super.key, required this.height, required this.datos});
  @override Widget build(BuildContext context) {
    bool esFallos = datos['tipoJornada'] == 'Fallos';
    return GridItemContainer(height: height, child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [const Text('Datos Generales Jornada en Curso', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, color: Color.fromRGBO(207, 7, 7, 0.938), fontWeight: FontWeight.bold)), const SizedBox(height: 15), Table(columnWidths: const { 0: FlexColumnWidth(4.2), 1: FlexColumnWidth(5.8) }, defaultVerticalAlignment: TableCellVerticalAlignment.middle, children: [_buildDataRow('Número Jornada Actual', datos['numeroJornada']), _buildDataRow('Fecha Jornada Actual', datos['fecha']), _buildDataRow(esFallos ? 'Figuras Base Utilizadas' : 'Figuras Utilizadas', datos['figurasBase']), _buildDataRow(esFallos ? 'Apuestas Base Directas' : 'Total Apuestas Directas', datos['apuestasBaseDirectas']), _buildDataRow(esFallos ? 'Apuestas Base Reducidas' : 'Total Apuestas Reducidas', datos['apuestasBaseReducidas']), _buildDataRow(esFallos ? 'Número de Boletos Base' : 'Número de Boletos', "${datos['numeroBoletosBase']} boletos")])]));
  }
  TableRow _buildDataRow(String label, String value) { return TableRow(children: [Padding(padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0), child: Text(label, textAlign: TextAlign.right, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14))), Padding(padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0), child: Text(value, textAlign: TextAlign.left, style: const TextStyle(color: Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: 14)))]); }
}

class FallosDataBox extends StatelessWidget {
  final double height; final Map<String, dynamic> datos;
  const FallosDataBox({super.key, required this.height, required this.datos});
  @override Widget build(BuildContext context) {
    return GridItemContainer(height: height, child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [const Text('Datos Adicionales Sistema de Fallos', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, color: Color.fromRGBO(207, 7, 7, 0.938), fontWeight: FontWeight.bold)), const SizedBox(height: 15), Table(columnWidths: const { 0: FlexColumnWidth(4.2), 1: FlexColumnWidth(5.8) }, defaultVerticalAlignment: TableCellVerticalAlignment.middle, children: [_buildDataRow('Número de Variantes', datos['numeroVariantes']?.toString() ?? ''), _buildDataRow('Apuestas Directas Cubiertas', datos['apuestasDirectasCubiertas']?.toString() ?? ''), _buildDataRow('Total Figuras Globales', datos['totalFigurasGlobales'] ?? ''), _buildDataRow('Apuestas Directas Fallos', datos['apuestasDirectasFallos'] ?? ''), _buildDataRow('Apuestas Reducidas Fallos', datos['apuestasReducidasFallos'] ?? ''), _buildDataRow('Número de Boletos con Fallo', "${datos['numeroBoletosFallo'] ?? ''} boletos")])]));
  }
  TableRow _buildDataRow(String label, String value) { return TableRow(children: [Padding(padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0), child: Text(label, textAlign: TextAlign.right, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14))), Padding(padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0), child: Text(value, textAlign: TextAlign.left, style: const TextStyle(color: Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: 14)))]); }
}

class PronosticosBox extends StatelessWidget {
  final double height; final List<String> partidos; final List<String> pronosticosBase; final List<String> pronosticosFallos; final List<String> resultados; final Function(int, String) onResultadoChanged; final Map<int, int> recuentoGlobal;
  const PronosticosBox({super.key, required this.height, required this.partidos, required this.pronosticosBase, required this.pronosticosFallos, required this.resultados, required this.onResultadoChanged, required this.recuentoGlobal});

  @override Widget build(BuildContext context) {
    int totalAciertosPronostico = 0;
    for(int i=0; i<14; i++) {
      String res = resultados[i];
      if(res != '0') {
         String pB = i < pronosticosBase.length ? pronosticosBase[i].padRight(3, ' ') : "   "; String pF = i < pronosticosFallos.length ? pronosticosFallos[i].padRight(3, ' ') : "   ";
         if(pB.contains(res) || pF.contains(res)) totalAciertosPronostico++;
      }
    }

    return GridItemContainer(height: height, child: Column(children: [const Text('Pronósticos Resultados Escrutinio', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, color: Color.fromRGBO(207, 7, 7, 0.938), fontWeight: FontWeight.bold)), const SizedBox(height: 15), Expanded(child: Table(columnWidths: const { 0: FlexColumnWidth(4.5), 1: FlexColumnWidth(1.8), 2: FlexColumnWidth(1.2), 3: FlexColumnWidth(2.5) }, defaultVerticalAlignment: TableCellVerticalAlignment.middle, children: [const TableRow(children: [SizedBox(height: 22), SizedBox(height: 22), SizedBox(height: 22), SizedBox(height: 22)]), ...List.generate(14, (index) => _buildPartidoRow(index, index < partidos.length ? partidos[index] : "Partido ${index+1}")), TableRow(children: [const SizedBox(height: 22), Container(height: 22, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.amber, border: Border.all(color: const Color(0xFF080868), width: 1)), child: Text("$totalAciertosPronostico Oros", style: const TextStyle(color: Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: 11))), const SizedBox(height: 22), Padding(padding: const EdgeInsets.only(left: 8.0), child: Row(children: [Expanded(child: _buildBadge('0', isBlue: true)), const SizedBox(width: 4), Expanded(child: _buildBadge(recuentoGlobal[0].toString(), isBlue: false))]))])]))]));
  }

  TableRow _buildPartidoRow(int index, String partido) {
    String nombrePartido = "${(index + 1).toString().padLeft(2, '0')}. $partido"; String pBase = index < pronosticosBase.length ? pronosticosBase[index].padRight(3, ' ') : "   "; String pFallo = index < pronosticosFallos.length ? pronosticosFallos[index].padRight(3, ' ') : "   "; String resultado = resultados[index]; int categoria = 14 - index; 

    return TableRow(children: [Padding(padding: const EdgeInsets.symmetric(vertical: 3.5).copyWith(right: 12.0), child: Text(nombrePartido, style: const TextStyle(color: Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: 13))), TableCell(verticalAlignment: TableCellVerticalAlignment.fill, child: Container(decoration: BoxDecoration(color: Colors.redAccent, border: Border.all(color: Colors.redAccent, width: 0.5)), padding: const EdgeInsets.symmetric(horizontal: 4.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [Expanded(child: _buildSignoDin('1', pBase[0], pFallo[0], resultado)), Expanded(child: _buildSignoDin('X', pBase[1], pFallo[1], resultado)), Expanded(child: _buildSignoDin('2', pBase[2], pFallo[2], resultado))]))), Padding(padding: const EdgeInsets.only(left: 12.0, right: 12.0), child: Container(height: 22, padding: const EdgeInsets.symmetric(horizontal: 4.0), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(6.0), border: Border.all(color: Colors.black, width: 1.0)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: resultado, isExpanded: true, isDense: true, icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black, size: 16), dropdownColor: Colors.white, borderRadius: BorderRadius.circular(12.0), alignment: Alignment.center, style: const TextStyle(color: Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: 13), items: const [DropdownMenuItem(value: '0', alignment: Alignment.center, child: Text(' ')), DropdownMenuItem(value: '1', alignment: Alignment.center, child: Text('1')), DropdownMenuItem(value: 'X', alignment: Alignment.center, child: Text('X')), DropdownMenuItem(value: '2', alignment: Alignment.center, child: Text('2'))], onChanged: (val) { if (val != null) onResultadoChanged(index, val); })))), Padding(padding: const EdgeInsets.only(left: 8.0), child: Row(children: [Expanded(child: _buildBadge(categoria.toString(), isBlue: true)), const SizedBox(width: 4), Expanded(child: _buildBadge(recuentoGlobal[categoria].toString(), isBlue: false))]))]);
  }

  Widget _buildSignoDin(String texto, String charBase, String charFallo, String resultado) {
    bool isFallo = charFallo != ' '; bool isBase = charBase != ' '; bool isJugado = isFallo || isBase; bool isResultado = (resultado == texto);
    Color bgColor = Colors.white; Color textColor = isJugado ? const Color(0xFF080868) : const Color.fromRGBO(255, 180, 180, 1);
    if (resultado == '0') { if (isFallo) bgColor = const Color(0xFF6CF114); else if (isBase) bgColor = const Color(0xFF21F0F0); } else { if (isResultado) { if (isJugado) { bgColor = Colors.amber; textColor = const Color(0xFF080868); } else { bgColor = Colors.grey.shade400; textColor = const Color(0xFF080868); } } else { if (isJugado) { bgColor = Colors.redAccent; textColor = Colors.white; } else { bgColor = Colors.white; } } }
    return Container(height: 18, margin: const EdgeInsets.symmetric(horizontal: 1.5), alignment: Alignment.center, decoration: BoxDecoration(color: bgColor), child: Text(texto, textAlign: TextAlign.center, style: TextStyle(color: textColor, fontWeight: isJugado ? FontWeight.bold : FontWeight.normal, fontSize: 12)));
  }

  Widget _buildBadge(String texto, {required bool isBlue}) { return Container(height: 22, alignment: Alignment.center, decoration: BoxDecoration(color: isBlue ? const Color.fromRGBO(33, 240, 240, 0.8) : Colors.white, border: Border.all(color: const Color(0xFF080868), width: 1.5)), child: Text(texto, style: const TextStyle(color: Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: 12))); }
}

class BoletoBox extends StatefulWidget {
  final double height; final String titulo; final List<String> apuestas; final List<String> resultados; 
  const BoletoBox({super.key, required this.height, required this.titulo, required this.apuestas, required this.resultados});
  @override State<BoletoBox> createState() => _BoletoBoxState();
}

class _BoletoBoxState extends State<BoletoBox> {
  int currentTicket = 0;

  @override Widget build(BuildContext context) {
    int totalTickets = (widget.apuestas.length / 8).ceil(); if (totalTickets == 0) totalTickets = 1;
    int startIndex = currentTicket * 8; int apuestasEnEsteBoleto = widget.apuestas.length - startIndex; if (apuestasEnEsteBoleto > 8) apuestasEnEsteBoleto = 8;
    List<int> aciertosBoletoActual = [];
    for (int i = 0; i < apuestasEnEsteBoleto; i++) { String apuesta = widget.apuestas[startIndex + i]; int count = 0; for (int r = 0; r < 14; r++) { if (widget.resultados[r] != '0' && r < apuesta.length && apuesta[r] == widget.resultados[r]) count++; } aciertosBoletoActual.add(count); }
    return GridItemContainer(height: widget.height, child: Column(children: [Row(children: [GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => setState(() => currentTicket = (currentTicket - 1 + totalTickets) % totalTickets), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0), child: Text('<<', style: TextStyle(fontSize: 28, color: Color(0xFF080868), fontWeight: FontWeight.w900, letterSpacing: -2)))), const Spacer(), Text(widget.titulo, style: const TextStyle(fontSize: 22, color: Color.fromRGBO(207, 7, 7, 0.938), fontWeight: FontWeight.bold)), const Spacer(), GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => setState(() => currentTicket = (currentTicket + 1) % totalTickets), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0), child: Text('>>', style: TextStyle(fontSize: 28, color: Color(0xFF080868), fontWeight: FontWeight.w900, letterSpacing: -2))))]), const SizedBox(height: 15), Expanded(child: Table(columnWidths: const { 0: FlexColumnWidth(1.2), 1: FlexColumnWidth(1.0), 2: FlexColumnWidth(1.0), 3: FlexColumnWidth(1.0), 4: FlexColumnWidth(1.0), 5: FlexColumnWidth(1.0), 6: FlexColumnWidth(1.0), 7: FlexColumnWidth(1.0), 8: FlexColumnWidth(1.0) }, defaultVerticalAlignment: TableCellVerticalAlignment.middle, children: [_buildTopHeaderRow(apuestasEnEsteBoleto, aciertosBoletoActual), ...List.generate(14, (index) => _buildBetRow(index + 1, apuestasEnEsteBoleto, startIndex)), _buildBottomHeaderRow(apuestasEnEsteBoleto, startIndex)]))]));
  }

  TableRow _buildTopHeaderRow(int numApuestas, List<int> aciertos) { return TableRow(children: [_buildHeaderText('B${currentTicket + 1}'), ...List.generate(8, (index) { if (index >= numApuestas) return _buildHeaderText(''); int count = aciertos[index]; return Container(height: 22, alignment: Alignment.center, color: count > 9 ? Colors.yellow : Colors.transparent, child: Text(count.toString(), style: const TextStyle(color: Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: 13))); })]); }
  TableRow _buildBetRow(int rowNum, int numApuestas, int startIdx) { String resultadoPartido = widget.resultados[rowNum - 1]; return TableRow(children: [_buildHeaderText(rowNum.toString()), ...List.generate(8, (colIndex) { if (colIndex >= numApuestas) return const SizedBox(); int betNum = startIdx + colIndex + 1; bool isOdd = betNum % 2 != 0; String apuestaCompleta = widget.apuestas[startIdx + colIndex]; String mark = ' '; if(apuestaCompleta.length >= rowNum) mark = apuestaCompleta[rowNum - 1]; return _buildBetCell(isOdd: isOdd, markedSymbol: mark, resultadoPartido: resultadoPartido); })]); }
  TableRow _buildBottomHeaderRow(int numApuestas, int startIdx) { return TableRow(children: [_buildHeaderText('apu.'), ...List.generate(8, (index) => _buildHeaderText(index < numApuestas ? (startIdx + index + 1).toString() : ''))]); }
  Widget _buildHeaderText(String text) { return Container(height: 22, alignment: Alignment.center, child: Text(text, style: const TextStyle(color: Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: 13))); }
  
  Widget _buildBetCell({required bool isOdd, required String markedSymbol, required String resultadoPartido}) { return TableCell(verticalAlignment: TableCellVerticalAlignment.fill, child: Container(color: isOdd ? const Color(0xFFFF6347) : Colors.white, padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.5), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_buildSmallSquare('1', isMarked: markedSymbol == '1', isOddColumn: isOdd, resultado: resultadoPartido), _buildSmallSquare('X', isMarked: markedSymbol == 'X', isOddColumn: isOdd, resultado: resultadoPartido), _buildSmallSquare('2', isMarked: markedSymbol == '2', isOddColumn: isOdd, resultado: resultadoPartido)]))); }

  Widget _buildSmallSquare(String text, {required bool isMarked, required bool isOddColumn, required String resultado}) {
    bool isResultado = (resultado == text); Color bgColor = Colors.white; Color textColor = isMarked ? const Color(0xFF080868) : const Color.fromRGBO(255, 180, 180, 1);
    if (resultado == '0') { if (isMarked) bgColor = const Color.fromRGBO(33, 240, 240, 1.0); } else { if (isResultado) { if (isMarked) { bgColor = Colors.amber; textColor = const Color(0xFF080868); } else { bgColor = Colors.grey.shade400; textColor = const Color(0xFF080868); } } else { if (isMarked) { bgColor = Colors.redAccent; textColor = Colors.white; } else { bgColor = Colors.white; } } }
    Border? border = isOddColumn ? null : Border.all(color: Colors.redAccent, width: 1.0);
    return Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 1.5), alignment: Alignment.center, decoration: BoxDecoration(color: bgColor, border: border), child: Text(text, style: TextStyle(color: textColor, fontWeight: isMarked ? FontWeight.bold : FontWeight.normal, fontSize: 11))));
  }
}