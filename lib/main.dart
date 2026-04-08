// === IMPORTACIONES CLAVE ===
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]).then((_) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
  final double anchoFijo = kIsWeb ? 560.0 : 720.0; 
  final double altoFijo1 = kIsWeb ? 270.0 : 320.0; 
  // === AJUSTE: Lienzo a 620 para dar margen de seguridad al Escrutinio ===
  final double altoFijo2 = kIsWeb ? 470.0 : 620.0; 

  Map<String, dynamic>? jsonData;
  bool isReady = false; 
  bool hasError = false; 
  String errorMessage = ""; 
  String loadingMessage = "Iniciando sistema..."; 
  double loadingProgress = 0.0; 

  List<String> resultados = List.filled(14, '0');
  late SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    _inicializarAppYDescargar();
  }

  Future<void> _inicializarAppYDescargar() async {
    setState(() { hasError = false; loadingProgress = 0.05; loadingMessage = "Arrancando motor combinatorio..."; });
    await Future.delayed(const Duration(milliseconds: 2500)); 

    try {
      prefs = await SharedPreferences.getInstance();
      setState(() { loadingProgress = 0.25; loadingMessage = "Estableciendo conexión segura..."; });
      await Future.delayed(const Duration(milliseconds: 800)); 

      setState(() { loadingProgress = 0.4; loadingMessage = "Descargando datos de la jornada..."; });

      final String urlDropbox = 'https://dl.dropboxusercontent.com/scl/fi/d5bp0vgwuv36eaoug1b6c/jornada.json?rlkey=42wxfnlekmy7bf1vwnyq791bv';
      final response = await http.get(Uri.parse(urlDropbox)).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        setState(() { loadingProgress = 0.7; loadingMessage = "Procesando información..."; });
        await Future.delayed(const Duration(milliseconds: 600)); 
        
        final String jsonString = utf8.decode(response.bodyBytes);
        final data = json.decode(jsonString);

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

        setState(() { jsonData = data; loadingProgress = 1.0; loadingMessage = "¡Carga completada!"; });
        await Future.delayed(const Duration(milliseconds: 1500));
        setState(() { isReady = true; });

        WidgetsBinding.instance.addPostFrameCallback((_) { _gestionarUsuario(); });
      } else {
        _mostrarError("Se ha producido un error en el servidor (Código: ${response.statusCode}).\nNo ha sido posible acceder a los datos.");
      }
    } catch (e) {
      _mostrarError("No se ha podido establecer conexión.\nPor favor, compruebe su acceso a internet.");
    }
  }

  void _mostrarError(String mensaje) { setState(() { hasError = true; errorMessage = mensaje; }); }

  void _gestionarUsuario() {
    String? nombre = prefs.getString('apodoUsuario');
    if (nombre == null || nombre.isEmpty) { _pedirNombreUsuario(); } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('¡Bienvenido de nuevo a Tu Quiniplaya Millonaria, $nombre!', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFF080868), duration: const Duration(seconds: 4), behavior: SnackBarBehavior.floating));
    }
  }

  void _pedirNombreUsuario() {
    TextEditingController nameController = TextEditingController();
    bool showError = false; 
    showDialog(
      context: context, barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              alignment: Alignment.topCenter, insetPadding: const EdgeInsets.symmetric(horizontal: 50, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(15.0), 
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('¡Bienvenido a La Quiniplaya!', textAlign: TextAlign.center, style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8), const Text('Por favor, indícanos tu nombre o apodo:', textAlign: TextAlign.center, style: TextStyle(fontSize: 13)), const SizedBox(height: 10),
                    TextField(
                      controller: nameController, autofocus: true, textInputAction: TextInputAction.done, 
                      onSubmitted: (value) { if (value.trim().isNotEmpty) { Navigator.pop(context); _confirmarNombre(value.trim()); } else { setStateDialog(() => showError = true); } },
                      decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), hintText: "Tu apodo aquí...", errorText: showError ? "Obligatorio" : null, border: const OutlineInputBorder(), focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF080868), width: 2))),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF080868), padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: () { String input = nameController.text.trim(); if (input.isNotEmpty) { Navigator.pop(context); _confirmarNombre(input); } else { setStateDialog(() { showError = true; }); } },
                      child: const Text('Siguiente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  void _confirmarNombre(String nombre) {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (context) {
        return Dialog(
          alignment: Alignment.topCenter, insetPadding: const EdgeInsets.symmetric(horizontal: 50, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Confirmación de Registro', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 12),
                RichText(text: TextSpan(style: const TextStyle(color: Colors.black, fontSize: 14, fontFamily: 'Arial'), children: [const TextSpan(text: '¿Estás seguro de que quieres utilizar el apodo '), TextSpan(text: '"$nombre"', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)), const TextSpan(text: '?\n\nEste apodo quedará guardado para saludarte en cada jornada.')])), const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () { Navigator.pop(context); _pedirNombreUsuario(); }, child: const Text('Corregir', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))), const SizedBox(width: 10),
                    Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () async { await prefs.setString('apodoUsuario', nombre); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('¡Registro completado! Bienvenido, $nombre.', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), backgroundColor: Colors.green.shade700, behavior: SnackBarBehavior.floating)); }, child: const FittedBox(child: Text('Confirmar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))),
                  ],
                )
              ],
            ),
          ),
        );
      }
    );
  }

  void _actualizarResultado(int index, String valor) {
    setState(() { resultados[index] = valor; });
    prefs.setStringList('resultadosPartidos', resultados);
  }

  @override
  Widget build(BuildContext context) {
    if (!isReady) {
      if (hasError) return Scaffold(body: SafeArea(child: _buildErrorScreen()));
      else return Scaffold(body: SafeArea(child: _buildLoadingScreen()));
    }

    bool esFallos = jsonData!['datosGenerales']['tipoJornada'] == "Fallos";
    Map<int, int> recuentoGlobal = {for (int i = 0; i <= 14; i++) i: 0};
    
    List<String> todasLasApuestas = List<String>.from(jsonData!['apuestasBase'] ?? []);
    if (esFallos) { todasLasApuestas.addAll(List<String>.from(jsonData!['apuestasFallos'] ?? [])); }

    for (String apuesta in todasLasApuestas) {
      int aciertos = 0;
      for (int i = 0; i < 14; i++) { if (resultados[i] != '0' && i < apuesta.length && apuesta[i] == resultados[i]) aciertos++; }
      recuentoGlobal[aciertos] = (recuentoGlobal[aciertos] ?? 0) + 1;
    }

    Widget presentacion = PresentationBox(width: anchoFijo, height: altoFijo1);
    Widget pronosticos = PronosticosBox(width: anchoFijo, height: altoFijo2, partidos: List<String>.from(jsonData!['partidos'] ?? []), pronosticosBase: List<String>.from(jsonData!['pronosticosBase'] ?? []), pronosticosFallos: List<String>.from(jsonData!['pronosticosFallos'] ?? []), resultados: resultados, onResultadoChanged: _actualizarResultado, recuentoGlobal: recuentoGlobal);
    Widget datosBase = GeneralDataBox(width: anchoFijo, height: altoFijo1, datos: jsonData!['datosGenerales']);
    Widget boletoBase = BoletoBox(width: anchoFijo, height: altoFijo2, titulo: 'Carrusel de Boletos Base', apuestas: List<String>.from(jsonData!['apuestasBase'] ?? []), resultados: resultados);
    Widget datosFallos = esFallos ? FallosDataBox(width: anchoFijo, height: altoFijo1, datos: jsonData!['datosFallos']) : const SizedBox.shrink();
    Widget boletoFallos = esFallos ? BoletoBox(width: anchoFijo, height: altoFijo2, titulo: 'Carrusel Boletos con Fallo', apuestas: List<String>.from(jsonData!['apuestasFallos'] ?? []), resultados: resultados) : const SizedBox.shrink();

    return Scaffold(
      body: SafeArea(
        child: kIsWeb 
          ? _buildWebView(esFallos, presentacion, pronosticos, datosBase, boletoBase, datosFallos, boletoFallos) 
          : _buildMobileView(context, esFallos, presentacion, pronosticos, datosBase, boletoBase, datosFallos, boletoFallos),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    bool isComplete = loadingProgress >= 1.0;
    return Center(
      child: SingleChildScrollView(
        child: Container(
          width: kIsWeb ? 400 : 350, 
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20.0), 
          decoration: BoxDecoration(color: const Color.fromRGBO(255, 248, 220, 1), borderRadius: BorderRadius.circular(15.0), border: Border.all(color: isComplete ? Colors.green : Colors.red, width: 3.0), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 5)]), 
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(8.0), child: Image.asset('assets/dadoqpr.png', height: 70, fit: BoxFit.cover)), 
              const SizedBox(height: 15), 
              Text('LA QUINIPLAYA MILLONARIA', textAlign: TextAlign.center, style: TextStyle(fontSize: kIsWeb ? 22 : 18, color: const Color.fromRGBO(207, 7, 7, 0.938), fontWeight: FontWeight.bold)), 
              const SizedBox(height: 20), 
              FittedBox(fit: BoxFit.scaleDown, child: Text(loadingMessage, textAlign: TextAlign.center, style: TextStyle(fontSize: kIsWeb ? 16 : 13, color: isComplete ? Colors.green.shade700 : const Color(0xFF080868), fontWeight: FontWeight.bold))), 
              const SizedBox(height: 15), 
              Row(children: [
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: loadingProgress, minHeight: 10, backgroundColor: Colors.grey.shade300, color: isComplete ? Colors.green : const Color(0xFF080868)))), 
                const SizedBox(width: 10), 
                Text("${(loadingProgress * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))
              ]), 
              if (isComplete) ...[ const SizedBox(height: 15), const Icon(Icons.check_circle, color: Colors.green, size: 30) ]
            ]
          )
        ),
      )
    );
  }

  Widget _buildErrorScreen() {
    return Center(child: SingleChildScrollView(child: Container(width: 450, margin: const EdgeInsets.symmetric(vertical: 20.0), padding: const EdgeInsets.all(30.0), decoration: BoxDecoration(color: const Color.fromRGBO(255, 248, 220, 1), borderRadius: BorderRadius.circular(15.0), border: Border.all(color: Colors.red, width: 3.0)), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 60), const SizedBox(height: 15), const Text('Fallo de Conexión o Lectura', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, color: Colors.red, fontWeight: FontWeight.bold)), const SizedBox(height: 20), Container(constraints: const BoxConstraints(maxHeight: 150), padding: const EdgeInsets.all(8.0), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.red.shade200), borderRadius: BorderRadius.circular(8.0)), child: SingleChildScrollView(child: Text(errorMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFF080868), fontWeight: FontWeight.bold)))), const SizedBox(height: 30), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF080868), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)), icon: const Icon(Icons.refresh, color: Colors.white), label: const Text('Reintentar Conexión', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), onPressed: _inicializarAppYDescargar)]))));
  }

  Widget _buildWebView(bool esFallos, Widget p1, Widget p2, Widget d1, Widget d2, Widget f1, Widget f2) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.start, 
          spacing: 15.0, runSpacing: 5.0, 
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
    List<Widget> paginas = [p1, d1]; if (esFallos) paginas.add(f1); paginas.add(p2); paginas.add(d2); if (esFallos) paginas.add(f2);
    double availableHeight = MediaQuery.of(context).size.height - 10.0;
    return SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0), child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: paginas.map((recuadro) { return Padding(padding: const EdgeInsets.only(right: 20.0), child: SizedBox(height: availableHeight, child: FittedBox(fit: BoxFit.contain, child: recuadro))); }).toList()));
  }
}

// =====================================================================
// COMPONENTES REUTILIZABLES
// =====================================================================
class GridItemContainer extends StatelessWidget {
  final Widget child; final double width; final double? height;
  final double paddingVertical; final double paddingHorizontal; 

  const GridItemContainer({
    super.key, required this.child, required this.width, this.height,
    this.paddingVertical = 12.0, this.paddingHorizontal = 20.0 
  });

  @override Widget build(BuildContext context) {
    return Container( 
      width: width, height: height, margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 5.0), 
      padding: EdgeInsets.symmetric(vertical: paddingVertical, horizontal: paddingHorizontal), 
      decoration: BoxDecoration(color: const Color.fromRGBO(255, 248, 220, 1), border: Border.all(color: Colors.red, width: 2.5)), 
      child: child
    );
  }
}

class PresentationBox extends StatelessWidget {
  final double width; final double height; const PresentationBox({super.key, required this.width, required this.height});
  @override Widget build(BuildContext context) {
    return GridItemContainer(
      width: width, height: height, paddingVertical: kIsWeb ? 2.0 : 8.0, 
      child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('LA QUINIPLAYA MILLONARIA', textAlign: TextAlign.center, style: TextStyle(fontSize: kIsWeb ? 26 : 30, color: const Color.fromRGBO(207, 7, 7, 0.938), fontWeight: FontWeight.bold)), 
        const SizedBox(height: 20), ClipRRect(borderRadius: BorderRadius.circular(8.0), child: Image.asset('assets/dadoqpr.png', height: 100, fit: BoxFit.cover)), const SizedBox(height: 20), 
        Text('Sistema Combinatorio de Alto Rendimiento para Apuestas Deportivas', textAlign: TextAlign.center, style: TextStyle(fontSize: kIsWeb ? 16 : 18, color: const Color(0xFF080868), fontWeight: FontWeight.bold))
      ])
    );
  }
}

class GeneralDataBox extends StatelessWidget {
  final double width; final double height; final Map<String, dynamic> datos;
  const GeneralDataBox({super.key, required this.width, required this.height, required this.datos});
  @override Widget build(BuildContext context) {
    bool esFallos = datos['tipoJornada'] == 'Fallos';
    return GridItemContainer(
      width: width, height: height, paddingVertical: kIsWeb ? 2.0 : 8.0, 
      child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('Datos Generales Jornada en Curso', textAlign: TextAlign.center, style: TextStyle(fontSize: kIsWeb ? 22 : 24, color: const Color.fromRGBO(207, 7, 7, 0.938), fontWeight: FontWeight.bold)), 
        const SizedBox(height: 15), Table(columnWidths: const { 0: FlexColumnWidth(4.2), 1: FlexColumnWidth(5.8) }, defaultVerticalAlignment: TableCellVerticalAlignment.middle, children: [_buildDataRow('Número Jornada Actual', datos['numeroJornada']), _buildDataRow('Fecha Jornada Actual', datos['fecha']), _buildDataRow(esFallos ? 'Figuras Base Utilizadas' : 'Figuras Utilizadas', datos['figurasBase']), _buildDataRow(esFallos ? 'Apuestas Base Directas' : 'Total Apuestas Directas', datos['apuestasBaseDirectas']), _buildDataRow(esFallos ? 'Apuestas Base Reducidas' : 'Total Apuestas Reducidas', datos['apuestasBaseReducidas']), _buildDataRow(esFallos ? 'Número de Boletos Base' : 'Número de Boletos', datos['numeroBoletosBase']?.toString() ?? '')])
      ])
    );
  }
  TableRow _buildDataRow(String label, String value) { return TableRow(children: [Padding(padding: EdgeInsets.symmetric(vertical: kIsWeb ? 4.0 : 3.0, horizontal: 8.0), child: Text(label, textAlign: TextAlign.right, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: kIsWeb ? 14 : 16))), Padding(padding: EdgeInsets.symmetric(vertical: kIsWeb ? 4.0 : 3.0, horizontal: 8.0), child: FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: Text(value, textAlign: TextAlign.left, style: TextStyle(color: const Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: kIsWeb ? 14 : 16))))]); }
}

class FallosDataBox extends StatelessWidget {
  final double width; final double height; final Map<String, dynamic> datos;
  const FallosDataBox({super.key, required this.width, required this.height, required this.datos});
  @override Widget build(BuildContext context) {
    return GridItemContainer(
      width: width, height: height, paddingVertical: kIsWeb ? 2.0 : 8.0, 
      child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('Datos Adicionales Sistema de Fallos', textAlign: TextAlign.center, style: TextStyle(fontSize: kIsWeb ? 22 : 24, color: const Color.fromRGBO(207, 7, 7, 0.938), fontWeight: FontWeight.bold)), 
        const SizedBox(height: 15), Table(columnWidths: const { 0: FlexColumnWidth(4.2), 1: FlexColumnWidth(5.8) }, defaultVerticalAlignment: TableCellVerticalAlignment.middle, children: [_buildDataRow('Número de Variantes', datos['numeroVariantes']?.toString() ?? ''), _buildDataRow('Apuestas Directas Cubiertas', datos['apuestasDirectasCubiertas']?.toString() ?? ''), _buildDataRow('Total Figuras Globales', datos['totalFigurasGlobales'] ?? ''), _buildDataRow('Apuestas Directas Fallos', datos['apuestasDirectasFallos'] ?? ''), _buildDataRow('Apuestas Reducidas Fallos', datos['apuestasReducidasFallos'] ?? ''), _buildDataRow('Número de Boletos con Fallo', datos['numeroBoletosFallo']?.toString() ?? '')])
      ])
    );
  }
  TableRow _buildDataRow(String label, String value) { return TableRow(children: [Padding(padding: EdgeInsets.symmetric(vertical: kIsWeb ? 4.0 : 3.0, horizontal: 8.0), child: Text(label, textAlign: TextAlign.right, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: kIsWeb ? 14 : 16))), Padding(padding: EdgeInsets.symmetric(vertical: kIsWeb ? 4.0 : 3.0, horizontal: 8.0), child: FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: Text(value, textAlign: TextAlign.left, style: TextStyle(color: const Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: kIsWeb ? 14 : 16))))]); }
}

class PronosticosBox extends StatelessWidget {
  final double width; final double height; final List<String> partidos; final List<String> pronosticosBase; final List<String> pronosticosFallos; final List<String> resultados; final Function(int, String) onResultadoChanged; final Map<int, int> recuentoGlobal;
  const PronosticosBox({super.key, required this.width, required this.height, required this.partidos, required this.pronosticosBase, required this.pronosticosFallos, required this.resultados, required this.onResultadoChanged, required this.recuentoGlobal});

  @override Widget build(BuildContext context) {
    int totalAciertosPronostico = 0;
    for(int i=0; i<14; i++) {
      String res = resultados[i];
      if(res != '0') {
         String pB = i < pronosticosBase.length ? pronosticosBase[i].padRight(3, ' ') : "   "; String pF = i < pronosticosFallos.length ? pronosticosFallos[i].padRight(3, ' ') : "   ";
         if(pB.contains(res) || pF.contains(res)) totalAciertosPronostico++;
      }
    }

    return GridItemContainer(
      width: width, height: height, paddingHorizontal: kIsWeb ? 35.0 : 15.0, paddingVertical: kIsWeb ? 2.0 : 6.0,
      child: Column(children: [
      Text('Pronósticos Resultados Escrutinio', textAlign: TextAlign.center, style: TextStyle(fontSize: kIsWeb ? 22 : 26, color: const Color.fromRGBO(207, 7, 7, 0.938), fontWeight: FontWeight.bold)), 
      const SizedBox(height: 2), 
      Expanded(child: Table(columnWidths: const { 0: FlexColumnWidth(4.3), 1: FlexColumnWidth(2.4), 2: FlexColumnWidth(1.9), 3: FlexColumnWidth(2.4) }, defaultVerticalAlignment: TableCellVerticalAlignment.middle, 
        children: [
          // === SOLUCIÓN: Interlineado mínimo (2.0) ===
          const TableRow(children: [SizedBox(height: 2.0), SizedBox(height: 2.0), SizedBox(height: 2.0), SizedBox(height: 2.0)]), 
          ...List.generate(14, (index) => _buildPartidoRow(index, index < partidos.length ? partidos[index] : "Partido ${index+1}")), 
          const TableRow(children: [SizedBox(height: 2.0), SizedBox(height: 2.0), SizedBox(height: 2.0), SizedBox(height: 2.0)]),
          TableRow(children: [
            const SizedBox(), 
            // === SOLUCIÓN: Oros rebajado a 26 y letra 16 ===
            Container(
              height: kIsWeb ? 22 : 26, 
              alignment: Alignment.center, 
              margin: const EdgeInsets.symmetric(horizontal: 5.0),
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              decoration: BoxDecoration(color: Colors.amber, border: Border.all(color: const Color(0xFF080868), width: 1)), 
              child: FittedBox(
                fit: BoxFit.scaleDown, 
                child: Text("$totalAciertosPronostico Oros", style: TextStyle(color: const Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: kIsWeb ? 12 : 16))
              )
            ), 
            const SizedBox(), 
            Padding(
              padding: const EdgeInsets.only(left: 15.0), 
              child: Row(children: [
                // === SOLUCIÓN: Badges finales rebajados a 28 y letra 17 ===
                Expanded(child: _buildBadge('0', isBlue: true, customHeight: kIsWeb ? 22 : 28, customFontSize: kIsWeb ? 11 : 17)), 
                const SizedBox(width: 4), 
                Expanded(child: _buildBadge(recuentoGlobal[0].toString(), isBlue: false, customHeight: kIsWeb ? 22 : 28, customFontSize: kIsWeb ? 11 : 17))
              ])
            )
          ])
        ]))])
    );
  }

  TableRow _buildPartidoRow(int index, String partido) {
    String nombrePartido = "${(index + 1).toString().padLeft(2, '0')}. $partido"; String pBase = index < pronosticosBase.length ? pronosticosBase[index].padRight(3, ' ') : "   "; String pFallo = index < pronosticosFallos.length ? pronosticosFallos[index].padRight(3, ' ') : "   "; String resultado = resultados[index]; int categoria = 14 - index; 

    return TableRow(children: [
      Padding(
        // === SOLUCIÓN: Menos padding vertical para comprimir filas (De 3.5 a 2.0) ===
        padding: EdgeInsets.symmetric(vertical: kIsWeb ? 3.5 : 2.0).copyWith(right: 25.0), 
        child: FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Text(nombrePartido, style: TextStyle(color: const Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: kIsWeb ? 13 : 18))
        )
      ), 
      TableCell(verticalAlignment: TableCellVerticalAlignment.fill, child: Container(margin: const EdgeInsets.symmetric(horizontal: 5.0), decoration: BoxDecoration(color: Colors.redAccent, border: Border.all(color: Colors.redAccent, width: 0.5)), padding: const EdgeInsets.symmetric(horizontal: 4.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [Expanded(child: _buildSignoDin('1', pBase[0], pFallo[0], resultado)), Expanded(child: _buildSignoDin('X', pBase[1], pFallo[1], resultado)), Expanded(child: _buildSignoDin('2', pBase[2], pFallo[2], resultado))]))), 
      // === SOLUCIÓN: Altura de Dropdown de 34 a 30 ===
      Padding(padding: const EdgeInsets.symmetric(horizontal: 10.0), child: Container(height: kIsWeb ? 24 : 30, padding: const EdgeInsets.symmetric(horizontal: 4.0), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(6.0), border: Border.all(color: Colors.black, width: 1.0)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: resultado, isExpanded: true, isDense: true, icon: Icon(Icons.keyboard_arrow_down, color: Colors.black, size: kIsWeb ? 18 : 24), dropdownColor: Colors.white, borderRadius: BorderRadius.circular(12.0), alignment: Alignment.center, style: TextStyle(color: const Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: kIsWeb ? 12 : 18), items: const [DropdownMenuItem(value: '0', alignment: Alignment.center, child: Text(' ')), DropdownMenuItem(value: '1', alignment: Alignment.center, child: Text('1')), DropdownMenuItem(value: 'X', alignment: Alignment.center, child: Text('X')), DropdownMenuItem(value: '2', alignment: Alignment.center, child: Text('2'))], onChanged: (val) { if (val != null) onResultadoChanged(index, val); })))), 
      Padding(padding: const EdgeInsets.only(left: 15.0), child: Row(children: [Expanded(child: _buildBadge(categoria.toString(), isBlue: true)), const SizedBox(width: 4), Expanded(child: _buildBadge(recuentoGlobal[categoria].toString(), isBlue: false))]))]);
  }

  Widget _buildSignoDin(String texto, String charBase, String charFallo, String resultado) {
    bool isFallo = charFallo != ' '; bool isBase = charBase != ' '; bool isJugado = isFallo || isBase; bool isResultado = (resultado == texto);
    Color bgColor = Colors.white; Color textColor = isJugado ? const Color(0xFF080868) : const Color.fromRGBO(255, 180, 180, 1);
    if (resultado == '0') { if (isFallo) bgColor = const Color(0xFF6CF114); else if (isBase) bgColor = const Color(0xFF21F0F0); } else { if (isResultado) { if (isJugado) { bgColor = Colors.amber; textColor = const Color(0xFF080868); } else { bgColor = Colors.grey.shade400; textColor = const Color(0xFF080868); } } else { if (isJugado) { bgColor = Colors.redAccent; textColor = Colors.white; } else { bgColor = Colors.white; } } }
    return Container(
      // === SOLUCIÓN: Altura de Signos de 30 a 26 ===
      height: kIsWeb ? 20 : 26, 
      margin: const EdgeInsets.symmetric(horizontal: 3.5), 
      alignment: Alignment.center, 
      decoration: BoxDecoration(color: bgColor), 
      child: Text(texto, textAlign: TextAlign.center, style: TextStyle(color: textColor, fontWeight: isJugado ? FontWeight.bold : FontWeight.normal, fontSize: kIsWeb ? 11 : 17))
    );
  }

  Widget _buildBadge(String texto, {required bool isBlue, double? customHeight, double? customFontSize}) { 
    // === SOLUCIÓN: Altura de Badges de 32 a 28 ===
    return Container(height: customHeight ?? (kIsWeb ? 22 : 28), alignment: Alignment.center, decoration: BoxDecoration(color: isBlue ? const Color.fromRGBO(33, 240, 240, 0.8) : Colors.white, border: Border.all(color: const Color(0xFF080868), width: 1.5)), child: Text(texto, style: TextStyle(color: const Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: customFontSize ?? (kIsWeb ? 11 : 18)))); 
  }
}

class BoletoBox extends StatefulWidget {
  final double width; final double height; final String titulo; final List<String> apuestas; final List<String> resultados; 
  const BoletoBox({super.key, required this.width, required this.height, required this.titulo, required this.apuestas, required this.resultados});
  @override State<BoletoBox> createState() => _BoletoBoxState();
}

class _BoletoBoxState extends State<BoletoBox> {
  int currentTicket = 0;

  @override Widget build(BuildContext context) {
    int totalTickets = (widget.apuestas.length / 8).ceil(); if (totalTickets == 0) totalTickets = 1;
    int startIndex = currentTicket * 8; int apuestasEnEsteBoleto = widget.apuestas.length - startIndex; if (apuestasEnEsteBoleto > 8) apuestasEnEsteBoleto = 8;
    List<int> aciertosBoletoActual = [];
    for (int i = 0; i < apuestasEnEsteBoleto; i++) { String apuesta = widget.apuestas[startIndex + i]; int count = 0; for (int r = 0; r < 14; r++) { if (widget.resultados[r] != '0' && r < apuesta.length && apuesta[r] == widget.resultados[r]) count++; } aciertosBoletoActual.add(count); }
    return GridItemContainer(
      width: widget.width, height: widget.height, paddingHorizontal: kIsWeb ? 35.0 : 5.0, paddingVertical: kIsWeb ? 2.0 : 10.0,
      child: Column(children: [Row(children: [GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => setState(() => currentTicket = (currentTicket - 1 + totalTickets) % totalTickets), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0), child: Text('<<', style: TextStyle(fontSize: kIsWeb ? 28 : 38, color: const Color(0xFF080868), fontWeight: FontWeight.w900, letterSpacing: -2)))), const Spacer(), Text(widget.titulo, style: TextStyle(fontSize: kIsWeb ? 22 : 28, color: const Color.fromRGBO(207, 7, 7, 0.938), fontWeight: FontWeight.bold)), const Spacer(), GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => setState(() => currentTicket = (currentTicket + 1) % totalTickets), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0), child: Text('>>', style: TextStyle(fontSize: kIsWeb ? 28 : 38, color: const Color(0xFF080868), fontWeight: FontWeight.w900, letterSpacing: -2))))]), const SizedBox(height: 15), Expanded(child: Table(columnWidths: const { 0: FlexColumnWidth(1.2), 1: FlexColumnWidth(1.0), 2: FlexColumnWidth(1.0), 3: FlexColumnWidth(1.0), 4: FlexColumnWidth(1.0), 5: FlexColumnWidth(1.0), 6: FlexColumnWidth(1.0), 7: FlexColumnWidth(1.0), 8: FlexColumnWidth(1.0) }, defaultVerticalAlignment: TableCellVerticalAlignment.middle, children: [_buildTopHeaderRow(apuestasEnEsteBoleto, aciertosBoletoActual), ...List.generate(14, (index) => _buildBetRow(index + 1, apuestasEnEsteBoleto, startIndex)), _buildBottomHeaderRow(apuestasEnEsteBoleto, startIndex)]))])
    );
  }

  // === SOLUCIÓN: Cabeceras rebajadas en altura (28) para que el carrusel no colapse hacia abajo ===
  TableRow _buildTopHeaderRow(int numApuestas, List<int> aciertos) { return TableRow(children: [_buildHeaderText('B${currentTicket + 1}'), ...List.generate(8, (index) { if (index >= numApuestas) return _buildHeaderText(''); int count = aciertos[index]; return Container(height: kIsWeb ? 22 : 28, alignment: Alignment.center, color: count > 9 ? Colors.yellow : Colors.transparent, child: Text(count.toString(), style: TextStyle(color: const Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: kIsWeb ? 12 : 18))); })]); }
  TableRow _buildBetRow(int rowNum, int numApuestas, int startIdx) { String resultadoPartido = widget.resultados[rowNum - 1]; return TableRow(children: [_buildHeaderText(rowNum.toString()), ...List.generate(8, (colIndex) { if (colIndex >= numApuestas) return const SizedBox(); int betNum = startIdx + colIndex + 1; bool isOdd = betNum % 2 != 0; String apuestaCompleta = widget.apuestas[startIdx + colIndex]; String mark = ' '; if(apuestaCompleta.length >= rowNum) mark = apuestaCompleta[rowNum - 1]; return _buildBetCell(isOdd: isOdd, markedSymbol: mark, resultadoPartido: resultadoPartido); })]); }
  TableRow _buildBottomHeaderRow(int numApuestas, int startIdx) { return TableRow(children: [_buildHeaderText('apu.'), ...List.generate(8, (index) => _buildHeaderText(index < numApuestas ? (startIdx + index + 1).toString() : ''))]); }
  Widget _buildHeaderText(String text) { return Container(height: kIsWeb ? 22 : 28, alignment: Alignment.center, child: Text(text, style: TextStyle(color: const Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: kIsWeb ? 12 : 18))); }
  
  Widget _buildBetCell({required bool isOdd, required String markedSymbol, required String resultadoPartido}) { 
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.fill, 
      child: Container(
        color: isOdd ? const Color(0xFFFF6347) : Colors.white, 
        // === SOLUCIÓN SIMETRÍA: Ahora TODAS las celdas (pares e impares) tienen los mismos padding ===
        padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: kIsWeb ? 2.5 : 1.5), 
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_buildSmallSquare('1', isMarked: markedSymbol == '1', isOddColumn: isOdd, resultado: resultadoPartido), _buildSmallSquare('X', isMarked: markedSymbol == 'X', isOddColumn: isOdd, resultado: resultadoPartido), _buildSmallSquare('2', isMarked: markedSymbol == '2', isOddColumn: isOdd, resultado: resultadoPartido)])
      )
    ); 
  }

  Widget _buildSmallSquare(String text, {required bool isMarked, required bool isOddColumn, required String resultado}) {
    bool isResultado = (resultado == text); Color bgColor = Colors.white; Color textColor = isMarked ? const Color(0xFF080868) : const Color.fromRGBO(255, 180, 180, 1);
    if (resultado == '0') { if (isMarked) bgColor = const Color.fromRGBO(33, 240, 240, 1.0); } else { if (isResultado) { if (isMarked) { bgColor = Colors.amber; textColor = const Color(0xFF080868); } else { bgColor = Colors.grey.shade400; textColor = const Color(0xFF080868); } } else { if (isMarked) { bgColor = Colors.redAccent; textColor = Colors.white; } else { bgColor = Colors.white; } } }
    
    // === SOLUCIÓN SIMETRÍA Y CENTRADO: Border idéntico para todos los cuadraditos de signos (rojos o blancos) ===
    Border? border = isOddColumn ? Border.all(color: Colors.redAccent, width: 1.0) : Border.all(color: Colors.redAccent, width: 1.0);
    
    return Expanded(
      child: Container(
        // === SOLUCIÓN: Margen ensanchado para que la caja "1", "X", "2" se vea con más color rojo ===
        margin: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.0), 
        padding: EdgeInsets.symmetric(vertical: kIsWeb ? 0.0 : 1.0),
        // === SOLUCIÓN CENTRADO: Obliga a centrar el contenido perfectamente ===
        alignment: Alignment.center, 
        decoration: BoxDecoration(color: bgColor, border: border), 
        child: FittedBox(fit: BoxFit.scaleDown, child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: textColor, fontWeight: isMarked ? FontWeight.bold : FontWeight.normal, fontSize: kIsWeb ? 11 : 18)))
      )
    );
  }
}