import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosJson();
  }

  Future<void> _cargarDatosJson() async {
    try {
      final String response = await rootBundle.loadString('assets/jornada.json');
      final data = await json.decode(response);
      setState(() {
        jsonData = data;
        isLoading = false;
      });
    } catch (e) {
      print("Error cargando JSON: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.red)));
    }

    if (jsonData == null) {
      return const Scaffold(body: Center(child: Text("Error: No se encontró el archivo JSON.")));
    }

    bool esFallos = jsonData!['datosGenerales']['tipoJornada'] == "Fallos";

    Widget presentacion = PresentationBox(height: altoFijo1);
    
    Widget pronosticos = PronosticosBox(
      height: altoFijo2, 
      partidos: List<String>.from(jsonData!['partidos'] ?? []),
      pronosticosBase: List<String>.from(jsonData!['pronosticosBase'] ?? []),
      pronosticosFallos: List<String>.from(jsonData!['pronosticosFallos'] ?? []),
    );
    
    Widget datosBase = GeneralDataBox(height: altoFijo1, datos: jsonData!['datosGenerales']);
    Widget boletoBase = BoletoBox(
      height: altoFijo2, 
      titulo: 'Carrusel de Boletos Base', 
      apuestas: List<String>.from(jsonData!['apuestasBase'] ?? [])
    );

    Widget datosFallos = esFallos ? FallosDataBox(height: altoFijo1, datos: jsonData!['datosFallos']) : const SizedBox.shrink();
    Widget boletoFallos = esFallos ? BoletoBox(
      height: altoFijo2, 
      titulo: 'Carrusel Boletos con Fallo', 
      apuestas: List<String>.from(jsonData!['apuestasFallos'] ?? [])
    ) : const SizedBox.shrink();

    return Scaffold(
      body: SafeArea(
        child: kIsWeb 
          ? _buildWebView(esFallos, presentacion, pronosticos, datosBase, boletoBase, datosFallos, boletoFallos) 
          // Pasamos el context para calcular la altura dinámica de la pantalla
          : _buildMobileView(context, esFallos, presentacion, pronosticos, datosBase, boletoBase, datosFallos, boletoFallos),
      ),
    );
  }

  Widget _buildWebView(bool esFallos, Widget p1, Widget p2, Widget d1, Widget d2, Widget f1, Widget f2) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.start,
          spacing: 10.0,
          runSpacing: 10.0,
          children: [
            Column(mainAxisSize: MainAxisSize.min, children: [p1, const SizedBox(height: 10), p2]),
            Column(mainAxisSize: MainAxisSize.min, children: [d1, const SizedBox(height: 10), d2]),
            if (esFallos)
              Column(mainAxisSize: MainAxisSize.min, children: [f1, const SizedBox(height: 10), f2]),
          ],
        ),
      ),
    );
  }

  // === SOLUCIÓN CONTINUA PARA MÓVIL ===
  Widget _buildMobileView(BuildContext context, bool esFallos, Widget p1, Widget p2, Widget d1, Widget d2, Widget f1, Widget f2) {
    List<Widget> paginas = [p1, d1];
    if (esFallos) paginas.add(f1);
    paginas.add(p2);
    paginas.add(d2);
    if (esFallos) paginas.add(f2);

    // Calculamos el espacio vertical disponible para escalar los recuadros
    double availableHeight = MediaQuery.of(context).size.height - 20.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal, // Habilitamos el scroll táctil continuo
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: paginas.map((recuadro) {
          return Padding(
            padding: const EdgeInsets.only(right: 15.0), // Separación justa entre recuadros
            child: SizedBox(
              height: availableHeight, // Forzamos a que toque arriba y abajo de la pantalla
              child: FittedBox(
                fit: BoxFit.contain, // Escala automáticamente sin deformar
                child: recuadro,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// =====================================================================
// CONTENEDORES Y FOTOGRAMA 1
// =====================================================================
class GridItemContainer extends StatelessWidget {
  final Widget child;
  final double? height;
  const GridItemContainer({super.key, required this.child, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 530.0, height: height, 
      margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 5.0),
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      decoration: BoxDecoration(color: const Color.fromRGBO(255, 248, 220, 1), border: Border.all(color: Colors.red, width: 2.5)),
      child: child,
    );
  }
}

class PresentationBox extends StatelessWidget {
  final double height;
  const PresentationBox({super.key, required this.height});
  @override
  Widget build(BuildContext context) {
    return GridItemContainer(
      height: height,
      child: Column(
        mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('LA QUINIPLAYA MILLONARIA', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, color: Color.fromRGBO(207, 7, 7, 0.938), fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ClipRRect(borderRadius: BorderRadius.circular(8.0), child: Image.asset('assets/dadoqpr.png', height: 100, fit: BoxFit.cover)),
          const SizedBox(height: 20),
          const Text('Sistema Combinatorio de Alto Rendimiento para Apuestas Deportivas', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Color(0xFF080868), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// =====================================================================
// FOTOGRAMA 2: DATOS GENERALES 
// =====================================================================
class GeneralDataBox extends StatelessWidget {
  final double height;
  final Map<String, dynamic> datos;
  const GeneralDataBox({super.key, required this.height, required this.datos});

  @override
  Widget build(BuildContext context) {
    bool esFallos = datos['tipoJornada'] == 'Fallos';
    return GridItemContainer(
      height: height,
      child: Column(
        mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Datos Generales Jornada en Curso', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, color: Color.fromRGBO(207, 7, 7, 0.938), fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Table(
            columnWidths: const { 0: FlexColumnWidth(4.2), 1: FlexColumnWidth(5.8) },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              _buildDataRow('Número Jornada Actual', datos['numeroJornada']),
              _buildDataRow('Fecha Jornada Actual', datos['fecha']),
              _buildDataRow(esFallos ? 'Figuras Base Utilizadas' : 'Figuras Utilizadas', datos['figurasBase']),
              _buildDataRow(esFallos ? 'Apuestas Base Directas' : 'Total Apuestas Directas', datos['apuestasBaseDirectas']),
              _buildDataRow(esFallos ? 'Apuestas Base Reducidas' : 'Total Apuestas Reducidas', datos['apuestasBaseReducidas']),
              _buildDataRow(esFallos ? 'Número de Boletos Base' : 'Número de Boletos', "${datos['numeroBoletosBase']} boletos"),
            ],
          ),
        ],
      ),
    );
  }
  TableRow _buildDataRow(String label, String value) {
    return TableRow(children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0), child: Text(label, textAlign: TextAlign.right, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14))),
      Padding(padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0), child: Text(value, textAlign: TextAlign.left, style: const TextStyle(color: Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: 14))),
    ]);
  }
}

// =====================================================================
// FOTOGRAMA 3: DATOS FALLOS 
// =====================================================================
class FallosDataBox extends StatelessWidget {
  final double height;
  final Map<String, dynamic> datos;
  const FallosDataBox({super.key, required this.height, required this.datos});

  @override
  Widget build(BuildContext context) {
    return GridItemContainer(
      height: height,
      child: Column(
        mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Datos Adicionales Sistema de Fallos', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, color: Color.fromRGBO(207, 7, 7, 0.938), fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Table(
            columnWidths: const { 0: FlexColumnWidth(4.2), 1: FlexColumnWidth(5.8) },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              _buildDataRow('Número de Variantes', datos['numeroVariantes']?.toString() ?? ''),
              _buildDataRow('Apuestas Directas Cubiertas', datos['apuestasDirectasCubiertas']?.toString() ?? ''),
              _buildDataRow('Total Figuras Globales', datos['totalFigurasGlobales'] ?? ''),
              _buildDataRow('Apuestas Directas Fallos', datos['apuestasDirectasFallos'] ?? ''),
              _buildDataRow('Apuestas Reducidas Fallos', datos['apuestasReducidasFallos'] ?? ''),
              _buildDataRow('Número de Boletos con Fallo', "${datos['numeroBoletosFallo'] ?? ''} boletos"),
            ],
          ),
        ],
      ),
    );
  }
  TableRow _buildDataRow(String label, String value) {
    return TableRow(children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0), child: Text(label, textAlign: TextAlign.right, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14))),
      Padding(padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0), child: Text(value, textAlign: TextAlign.left, style: const TextStyle(color: Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: 14))),
    ]);
  }
}

// =====================================================================
// FOTOGRAMA 4: PRONÓSTICOS
// =====================================================================
class PronosticosBox extends StatelessWidget {
  final double height;
  final List<String> partidos;
  final List<String> pronosticosBase;
  final List<String> pronosticosFallos;

  const PronosticosBox({super.key, required this.height, required this.partidos, required this.pronosticosBase, required this.pronosticosFallos});

  @override
  Widget build(BuildContext context) {
    return GridItemContainer(
      height: height,
      child: Column(
        children: [
          const Text('Pronósticos Resultados Escrutinio', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, color: Color.fromRGBO(207, 7, 7, 0.938), fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Expanded(
            child: Table(
              columnWidths: const { 0: FlexColumnWidth(4.5), 1: FlexColumnWidth(1.8), 2: FlexColumnWidth(1.2), 3: FlexColumnWidth(2.5) },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                const TableRow(children: [SizedBox(height: 22), SizedBox(height: 22), SizedBox(height: 22), SizedBox(height: 22)]),
                ...List.generate(14, (index) => _buildPartidoRow(index, index < partidos.length ? partidos[index] : "Partido ${index+1}")),
                const TableRow(children: [SizedBox(height: 22), SizedBox(height: 22), SizedBox(height: 22), SizedBox(height: 22)]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildPartidoRow(int index, String partido) {
    String nombrePartido = "${(index + 1).toString().padLeft(2, '0')}. $partido";
    String pBase = index < pronosticosBase.length ? pronosticosBase[index].padRight(3, ' ') : "   ";
    String pFallo = index < pronosticosFallos.length ? pronosticosFallos[index].padRight(3, ' ') : "   ";

    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 3.5).copyWith(right: 12.0), child: Text(nombrePartido, style: const TextStyle(color: Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: 13))),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.fill,
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFFFF6347), border: Border.all(color: const Color(0xFFFF6347), width: 0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(child: _buildSignoDin('1', pBase[0], pFallo[0])), 
                Expanded(child: _buildSignoDin('X', pBase[1], pFallo[1])),
                Expanded(child: _buildSignoDin('2', pBase[2], pFallo[2])),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12.0, right: 12.0),
          child: Container(height: 22, decoration: BoxDecoration(color: Colors.amber, border: Border.all(color: Colors.black, width: 1.0)), child: const Icon(Icons.keyboard_arrow_down, color: Colors.black, size: 18)),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Row(
            children: [
              Expanded(child: _buildBadge((14 - index).toString(), isBlue: true)),
              const SizedBox(width: 4),
              Expanded(child: _buildBadge('0', isBlue: false)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignoDin(String texto, String charBase, String charFallo) {
    bool isFallo = charFallo != ' ';
    bool isBase = charBase != ' ';
    bool isJugado = isFallo || isBase;

    Color bgColor = Colors.white;
    if (isFallo) {
      bgColor = const Color(0xFF6CF114); 
    } else if (isBase) {
      bgColor = const Color(0xFF21F0F0); 
    }
    Color textColor = isJugado ? const Color(0xFF080868) : const Color.fromRGBO(255, 180, 180, 1);

    return Container(
      height: 18, margin: const EdgeInsets.symmetric(horizontal: 1.5), alignment: Alignment.center,
      decoration: BoxDecoration(color: bgColor),
      child: Text(texto, textAlign: TextAlign.center, style: TextStyle(color: textColor, fontWeight: isJugado ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
    );
  }

  Widget _buildBadge(String texto, {required bool isBlue}) {
    return Container(
      height: 22, alignment: Alignment.center, decoration: BoxDecoration(color: isBlue ? const Color.fromRGBO(33, 240, 240, 0.8) : Colors.white, border: Border.all(color: const Color(0xFF080868), width: 1.5)),
      child: Text(texto, style: const TextStyle(color: Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

// =====================================================================
// FOTOGRAMAS 5 y 6: CARRUSELES DE BOLETOS 
// =====================================================================
class BoletoBox extends StatefulWidget {
  final double height;
  final String titulo;
  final List<String> apuestas;
  
  const BoletoBox({super.key, required this.height, required this.titulo, required this.apuestas});

  @override
  State<BoletoBox> createState() => _BoletoBoxState();
}

class _BoletoBoxState extends State<BoletoBox> {
  int currentTicket = 0;

  @override
  Widget build(BuildContext context) {
    int totalTickets = (widget.apuestas.length / 8).ceil();
    if (totalTickets == 0) totalTickets = 1;

    int startIndex = currentTicket * 8;
    int apuestasEnEsteBoleto = widget.apuestas.length - startIndex;
    if (apuestasEnEsteBoleto > 8) apuestasEnEsteBoleto = 8;

    return GridItemContainer(
      height: widget.height,
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque, 
                onTap: () => setState(() => currentTicket = (currentTicket - 1 + totalTickets) % totalTickets),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0), 
                  child: Text('<<', style: TextStyle(fontSize: 28, color: Color(0xFF080868), fontWeight: FontWeight.w900, letterSpacing: -2))
                ),
              ),
              const Spacer(), 
              Text(widget.titulo, style: const TextStyle(fontSize: 22, color: Color.fromRGBO(207, 7, 7, 0.938), fontWeight: FontWeight.bold)),
              const Spacer(), 
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => currentTicket = (currentTicket + 1) % totalTickets),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0), 
                  child: Text('>>', style: TextStyle(fontSize: 28, color: Color(0xFF080868), fontWeight: FontWeight.w900, letterSpacing: -2))
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          Expanded(
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(1.0), 2: FlexColumnWidth(1.0), 3: FlexColumnWidth(1.0), 4: FlexColumnWidth(1.0),
                5: FlexColumnWidth(1.0), 6: FlexColumnWidth(1.0), 7: FlexColumnWidth(1.0), 8: FlexColumnWidth(1.0),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                _buildTopHeaderRow(apuestasEnEsteBoleto),
                ...List.generate(14, (index) => _buildBetRow(index + 1, apuestasEnEsteBoleto, startIndex)),
                _buildBottomHeaderRow(apuestasEnEsteBoleto, startIndex), 
              ],
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildTopHeaderRow(int numApuestas) {
    return TableRow(
      children: [
        _buildHeaderText('B${currentTicket + 1}'), 
        ...List.generate(8, (index) => _buildHeaderText(index < numApuestas ? '0' : '')),
      ],
    );
  }

  TableRow _buildBetRow(int rowNum, int numApuestas, int startIdx) {
    return TableRow(
      children: [
        _buildHeaderText(rowNum.toString()),
        ...List.generate(8, (colIndex) {
          if (colIndex >= numApuestas) return const SizedBox(); 

          int betNum = startIdx + colIndex + 1; 
          bool isOdd = betNum % 2 != 0; 
          
          String apuestaCompleta = widget.apuestas[startIdx + colIndex];
          String mark = ' ';
          if(apuestaCompleta.length >= rowNum) mark = apuestaCompleta[rowNum - 1]; 

          return _buildBetCell(isOdd: isOdd, markedSymbol: mark);
        }),
      ],
    );
  }

  TableRow _buildBottomHeaderRow(int numApuestas, int startIdx) {
    return TableRow(
      children: [
        _buildHeaderText('apu.'),
        ...List.generate(8, (index) => _buildHeaderText(index < numApuestas ? (startIdx + index + 1).toString() : '')),
      ],
    );
  }

  Widget _buildHeaderText(String text) {
    return Container(height: 22, alignment: Alignment.center, child: Text(text, style: const TextStyle(color: Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: 13)));
  }

  Widget _buildBetCell({required bool isOdd, required String markedSymbol}) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.fill,
      child: Container(
        color: isOdd ? const Color(0xFFFF6347) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSmallSquare('1', isMarked: markedSymbol == '1', isOddColumn: isOdd),
            _buildSmallSquare('X', isMarked: markedSymbol == 'X', isOddColumn: isOdd),
            _buildSmallSquare('2', isMarked: markedSymbol == '2', isOddColumn: isOdd),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallSquare(String text, {required bool isMarked, required bool isOddColumn}) {
    Color bgColor = isMarked ? const Color.fromRGBO(33, 240, 240, 1.0) : Colors.white;
    Color textColor = isMarked ? const Color(0xFF080868) : const Color.fromRGBO(255, 180, 180, 1);
    Border? border = isOddColumn ? null : Border.all(color: const Color(0xFFFF6347), width: 1.0);

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bgColor, border: border),
        child: Text(text, style: TextStyle(color: textColor, fontWeight: isMarked ? FontWeight.bold : FontWeight.normal, fontSize: 11)),
      ),
    );
  }
}