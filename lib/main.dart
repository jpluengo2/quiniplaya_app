import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // === EXPLICACIÓN: CONTROL DE ORIENTACIÓN ===
  // Si la app NO se ejecuta en un navegador web (es decir, es un móvil nativo Android/iOS),
  // bloqueamos la pantalla en modo horizontal para garantizar el diseño panorámico.
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

// === EXPLICACIÓN: STATEFUL WIDGET PRINCIPAL ===
// MainScreen es el "Cerebro" de nuestra app. Al ser Stateful, tiene la capacidad 
// de guardar variables (estado) y redibujar la pantalla (setState) cuando estas cambian.
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

  // === EXPLICACIÓN: ESTADO CENTRAL DE RESULTADOS ===
  // Esta lista de 14 elementos guarda lo que el usuario elige en los Selects.
  // Inicia llena de '0' (vacío). Cuando se cambie un valor aquí, TODA la app se enterará.
  List<String> resultados = List.filled(14, '0');

  @override
  void initState() {
    super.initState();
    _cargarDatosJson();
  }

  // Lectura asíncrona del archivo JSON local
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

  // === EXPLICACIÓN: FUNCIÓN REACTIVA ===
  // Esta función se le pasa al PronosticosBox. Cuando el usuario cambia un Dropdown,
  // PronosticosBox llama a esta función, actualizamos la lista 'resultados' 
  // y hacemos setState() para obligar a TODA la pantalla a redibujar los colores y premios.
  void _actualizarResultado(int index, String valor) {
    setState(() {
      resultados[index] = valor;
    });
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

    // === EXPLICACIÓN: CÁLCULO GLOBAL DE PREMIOS ===
    // Inicializamos un "diccionario" donde la Clave es el nº de aciertos (de 0 a 14)
    // y el Valor es la cantidad de boletos con ese premio.
    Map<int, int> recuentoGlobal = {for (int i = 0; i <= 14; i++) i: 0};
    
    List<String> todasLasApuestas = List<String>.from(jsonData!['apuestasBase'] ?? []);
    if (esFallos) {
      todasLasApuestas.addAll(List<String>.from(jsonData!['apuestasFallos'] ?? []));
    }

    for (String apuesta in todasLasApuestas) {
      int aciertos = 0;
      for (int i = 0; i < 14; i++) {
        if (resultados[i] != '0' && i < apuesta.length && apuesta[i] == resultados[i]) {
          aciertos++;
        }
      }
      recuentoGlobal[aciertos] = (recuentoGlobal[aciertos] ?? 0) + 1;
    }

    // === INYECCIÓN DE DEPENDENCIAS A LOS RECUADROS ===
    Widget presentacion = PresentationBox(height: altoFijo1);
    
    Widget pronosticos = PronosticosBox(
      height: altoFijo2, 
      partidos: List<String>.from(jsonData!['partidos'] ?? []),
      pronosticosBase: List<String>.from(jsonData!['pronosticosBase'] ?? []),
      pronosticosFallos: List<String>.from(jsonData!['pronosticosFallos'] ?? []),
      resultados: resultados, 
      onResultadoChanged: _actualizarResultado, 
      recuentoGlobal: recuentoGlobal, 
    );
    
    Widget datosBase = GeneralDataBox(height: altoFijo1, datos: jsonData!['datosGenerales']);
    
    Widget boletoBase = BoletoBox(
      height: altoFijo2, 
      titulo: 'Carrusel de Boletos Base', 
      apuestas: List<String>.from(jsonData!['apuestasBase'] ?? []),
      resultados: resultados, 
    );

    Widget datosFallos = esFallos ? FallosDataBox(height: altoFijo1, datos: jsonData!['datosFallos']) : const SizedBox.shrink();
    
    Widget boletoFallos = esFallos ? BoletoBox(
      height: altoFijo2, 
      titulo: 'Carrusel Boletos con Fallo', 
      apuestas: List<String>.from(jsonData!['apuestasFallos'] ?? []),
      resultados: resultados,
    ) : const SizedBox.shrink();

    return Scaffold(
      body: SafeArea(
        child: kIsWeb 
          ? _buildWebView(esFallos, presentacion, pronosticos, datosBase, boletoBase, datosFallos, boletoFallos) 
          : _buildMobileView(context, esFallos, presentacion, pronosticos, datosBase, boletoBase, datosFallos, boletoFallos),
      ),
    );
  }

  // === EXPLICACIÓN: ESTRUCTURA WRAP PARA WEB ===
  // Wrap es el equivalente en Flutter a Flex-Wrap de CSS. 
  // Pone los elementos uno al lado de otro, y si no caben (Overflow), los baja a la siguiente línea.
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

  // === EXPLICACIÓN: ESTRUCTURA DESLIZANTE PARA MÓVIL ===
  // SingleChildScrollView en horizontal nos permite ese efecto de "cinta" continua
  // que el usuario puede arrastrar con el dedo.
  Widget _buildMobileView(BuildContext context, bool esFallos, Widget p1, Widget p2, Widget d1, Widget d2, Widget f1, Widget f2) {
    List<Widget> paginas = [p1, d1];
    if (esFallos) paginas.add(f1);
    paginas.add(p2);
    paginas.add(d2);
    if (esFallos) paginas.add(f2);

    double availableHeight = MediaQuery.of(context).size.height - 20.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal, 
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: paginas.map((recuadro) {
          return Padding(
            padding: const EdgeInsets.only(right: 15.0), 
            child: SizedBox(
              height: availableHeight, 
              child: FittedBox(
                fit: BoxFit.contain, // Escala la tarjeta matemáticamente sin pixelarse
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
// CONTENEDOR Y FOTOGRAMAS INICIALES (Lógica sin cambios)
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
// FOTOGRAMA 4: PRONÓSTICOS (Con Novedades de UI solicitadas)
// =====================================================================
class PronosticosBox extends StatelessWidget {
  final double height;
  final List<String> partidos;
  final List<String> pronosticosBase;
  final List<String> pronosticosFallos;
  final List<String> resultados;
  final Function(int, String) onResultadoChanged;
  final Map<int, int> recuentoGlobal;

  const PronosticosBox({
    super.key, required this.height, required this.partidos, 
    required this.pronosticosBase, required this.pronosticosFallos,
    required this.resultados, required this.onResultadoChanged,
    required this.recuentoGlobal
  });

  @override
  Widget build(BuildContext context) {
    
    // === EXPLICACIÓN: CÁLCULO DEL RECUENTO DE ACIERTOS EN PRONÓSTICOS ===
    // Contamos cuántas veces el resultado introducido coincide con un signo
    // que nosotros hemos jugado en nuestro bloque de pronósticos.
    int totalAciertosPronostico = 0;
    for(int i=0; i<14; i++) {
      String res = resultados[i];
      if(res != '0') {
         String pB = i < pronosticosBase.length ? pronosticosBase[i].padRight(3, ' ') : "   ";
         String pF = i < pronosticosFallos.length ? pronosticosFallos[i].padRight(3, ' ') : "   ";
         if(pB.contains(res) || pF.contains(res)) {
            totalAciertosPronostico++;
         }
      }
    }

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
                
                // === MEJORA: LÍNEA INFERIOR CON ACIERTOS DEL PRONÓSTICO ===
                TableRow(
                  children: [
                    const SizedBox(height: 22), // Hueco bajo los nombres de partido
                    // Letrero dorado con los aciertos totales, ubicado bajo la columna roja
                    Container(
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.amber, border: Border.all(color: const Color(0xFF080868), width: 1)),
                      child: Text("$totalAciertosPronostico Oros", style: const TextStyle(color: Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: 11)),
                    ), 
                    const SizedBox(height: 22), // Hueco bajo los selects
                    // Recuento de Categoría 0
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Row(
                        children: [
                          Expanded(child: _buildBadge('0', isBlue: true)), 
                          const SizedBox(width: 4),
                          Expanded(child: _buildBadge(recuentoGlobal[0].toString(), isBlue: false)),
                        ],
                      ),
                    ),
                  ],
                ),
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
    String resultado = resultados[index];
    int categoria = 14 - index; 

    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 3.5).copyWith(right: 12.0), child: Text(nombrePartido, style: const TextStyle(color: Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: 13))),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.fill,
          child: Container(
            decoration: BoxDecoration(color: Colors.redAccent, border: Border.all(color: Colors.redAccent, width: 0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(child: _buildSignoDin('1', pBase[0], pFallo[0], resultado)), 
                Expanded(child: _buildSignoDin('X', pBase[1], pFallo[1], resultado)),
                Expanded(child: _buildSignoDin('2', pBase[2], pFallo[2], resultado)),
              ],
            ),
          ),
        ),
        
        // === MEJORA: SELECT ESTILIZADO (DROPDOWN MODERNO) ===
        Padding(
          padding: const EdgeInsets.only(left: 12.0, right: 12.0),
          child: Container(
            height: 22, 
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            decoration: BoxDecoration(
              color: Colors.amber, 
              borderRadius: BorderRadius.circular(6.0), // Bordes redondeados exteriores
              border: Border.all(color: Colors.black, width: 1.0)
            ), 
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: resultado,
                isExpanded: true,
                isDense: true, // Reduce los márgenes internos vacíos del componente
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black, size: 16),
                dropdownColor: Colors.white, // Menú flotante con fondo blanco
                borderRadius: BorderRadius.circular(12.0), // Menú flotante redondeado
                alignment: Alignment.center, // Centra el valor elegido
                style: const TextStyle(color: Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: 13),
                items: const [
                  DropdownMenuItem(value: '0', alignment: Alignment.center, child: Text(' ')),
                  DropdownMenuItem(value: '1', alignment: Alignment.center, child: Text('1')),
                  DropdownMenuItem(value: 'X', alignment: Alignment.center, child: Text('X')),
                  DropdownMenuItem(value: '2', alignment: Alignment.center, child: Text('2')),
                ],
                onChanged: (val) {
                  if (val != null) onResultadoChanged(index, val);
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Row(
            children: [
              Expanded(child: _buildBadge(categoria.toString(), isBlue: true)),
              const SizedBox(width: 4),
              Expanded(child: _buildBadge(recuentoGlobal[categoria].toString(), isBlue: false)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignoDin(String texto, String charBase, String charFallo, String resultado) {
    bool isFallo = charFallo != ' ';
    bool isBase = charBase != ' ';
    bool isJugado = isFallo || isBase;
    bool isResultado = (resultado == texto);

    Color bgColor = Colors.white;
    Color textColor = isJugado ? const Color(0xFF080868) : const Color.fromRGBO(255, 180, 180, 1);

    if (resultado == '0') {
      if (isFallo) bgColor = const Color(0xFF6CF114); 
      else if (isBase) bgColor = const Color(0xFF21F0F0); 
    } else {
      if (isResultado) {
        if (isJugado) {
          bgColor = Colors.amber; // ORO: ¡Acierto!
          textColor = const Color(0xFF080868);
        } else {
          bgColor = Colors.grey.shade400; // GRIS: Fue el resultado, pero no lo jugamos
          textColor = const Color(0xFF080868);
        }
      } else {
        if (isJugado) {
          bgColor = Colors.redAccent; // TOMATE: Lo jugamos y fallamos
          textColor = Colors.white;
        } else {
          bgColor = Colors.white; // BLANCO: Ni fu ni fa
        }
      }
    }

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
// FOTOGRAMAS 5 y 6: CARRUSELES DE BOLETOS (Lógica intacta)
// =====================================================================
class BoletoBox extends StatefulWidget {
  final double height;
  final String titulo;
  final List<String> apuestas;
  final List<String> resultados; 
  
  const BoletoBox({super.key, required this.height, required this.titulo, required this.apuestas, required this.resultados});

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

    List<int> aciertosBoletoActual = [];
    for (int i = 0; i < apuestasEnEsteBoleto; i++) {
      String apuesta = widget.apuestas[startIndex + i];
      int count = 0;
      for (int r = 0; r < 14; r++) {
        if (widget.resultados[r] != '0' && r < apuesta.length && apuesta[r] == widget.resultados[r]) count++;
      }
      aciertosBoletoActual.add(count);
    }

    return GridItemContainer(
      height: widget.height,
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque, 
                onTap: () => setState(() => currentTicket = (currentTicket - 1 + totalTickets) % totalTickets),
                child: const Padding(padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0), child: Text('<<', style: TextStyle(fontSize: 28, color: Color(0xFF080868), fontWeight: FontWeight.w900, letterSpacing: -2))),
              ),
              const Spacer(), 
              Text(widget.titulo, style: const TextStyle(fontSize: 22, color: Color.fromRGBO(207, 7, 7, 0.938), fontWeight: FontWeight.bold)),
              const Spacer(), 
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => currentTicket = (currentTicket + 1) % totalTickets),
                child: const Padding(padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0), child: Text('>>', style: TextStyle(fontSize: 28, color: Color(0xFF080868), fontWeight: FontWeight.w900, letterSpacing: -2))),
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
                _buildTopHeaderRow(apuestasEnEsteBoleto, aciertosBoletoActual),
                ...List.generate(14, (index) => _buildBetRow(index + 1, apuestasEnEsteBoleto, startIndex)),
                _buildBottomHeaderRow(apuestasEnEsteBoleto, startIndex), 
              ],
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildTopHeaderRow(int numApuestas, List<int> aciertos) {
    return TableRow(
      children: [
        _buildHeaderText('B${currentTicket + 1}'), 
        ...List.generate(8, (index) {
          if (index >= numApuestas) return _buildHeaderText('');
          int count = aciertos[index];
          return Container(
            height: 22, alignment: Alignment.center,
            color: count > 9 ? Colors.yellow : Colors.transparent,
            child: Text(count.toString(), style: const TextStyle(color: Color(0xFF080868), fontWeight: FontWeight.bold, fontSize: 13)),
          );
        }),
      ],
    );
  }

  TableRow _buildBetRow(int rowNum, int numApuestas, int startIdx) {
    String resultadoPartido = widget.resultados[rowNum - 1];

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

          return _buildBetCell(isOdd: isOdd, markedSymbol: mark, resultadoPartido: resultadoPartido);
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

  Widget _buildBetCell({required bool isOdd, required String markedSymbol, required String resultadoPartido}) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.fill,
      child: Container(
        color: isOdd ? const Color(0xFFFF6347) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSmallSquare('1', isMarked: markedSymbol == '1', isOddColumn: isOdd, resultado: resultadoPartido),
            _buildSmallSquare('X', isMarked: markedSymbol == 'X', isOddColumn: isOdd, resultado: resultadoPartido),
            _buildSmallSquare('2', isMarked: markedSymbol == '2', isOddColumn: isOdd, resultado: resultadoPartido),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallSquare(String text, {required bool isMarked, required bool isOddColumn, required String resultado}) {
    bool isResultado = (resultado == text);

    Color bgColor = Colors.white;
    Color textColor = isMarked ? const Color(0xFF080868) : const Color.fromRGBO(255, 180, 180, 1);

    if (resultado == '0') {
      if (isMarked) bgColor = const Color.fromRGBO(33, 240, 240, 1.0);
    } else {
      if (isResultado) {
         if (isMarked) {
           bgColor = Colors.amber; 
           textColor = const Color(0xFF080868);
         } else {
           bgColor = Colors.grey.shade400; 
           textColor = const Color(0xFF080868);
         }
      } else {
         if (isMarked) {
           bgColor = Colors.redAccent; 
           textColor = Colors.white;
         } else {
           bgColor = Colors.white; 
         }
      }
    }

    Border? border = isOddColumn ? null : Border.all(color: Colors.redAccent, width: 1.0);

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