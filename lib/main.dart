import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const InvestmentCalculatorApp());
}

class InvestmentCalculatorApp extends StatelessWidget {
  const InvestmentCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Инвестиционный калькулятор',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const InvestmentCalculatorScreen(),
    );
  }
}

class InvestmentCalculatorScreen extends StatefulWidget {
  const InvestmentCalculatorScreen({super.key});

  @override
  _InvestmentCalculatorScreenState createState() =>
      _InvestmentCalculatorScreenState();
}

class _InvestmentCalculatorScreenState
    extends State<InvestmentCalculatorScreen> {
  final TextEditingController _totalAmountController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  // Цены акций
  final Map<String, String> _tickerNames = {
    'SBER': 'Сбербанк',
    'GMKN': 'Норникель',
    'PHOR': 'Фосагро',
    'SNGSP': 'Сургутнефтегаз',
    'NVTK': 'Новатэк',
    'ALRS': 'АЛРОСА',
  };

  Map<String, double?> stockPrices = {};
  Map<String, int?> stockQuantities = {};

  // Основное распределение
  Map<String, double> allocationResults = {
    'Акции (60%)': 0,
    'Облигации (30%)': 0,
    'Золото (10%)': 0,
  };

  // Распределение внутри акционной части
  final Map<String, double> stocksDistribution = {
    'SBER': 0.15,
    'SNGSP': 0.15,
    'NVTK': 0.15,
    'GMKN': 0.20,
    'PHOR': 0.20,
    'ALRS': 0.15,
  };

  // Результаты распределения по акциям
  Map<String, double> stocksAllocation = {};

  @override
  void initState() {
    super.initState();
    _fetchStockPrices();
  }

  Future<void> _fetchStockPrices() async {
    setState(() {
      _isLoading = true;
      _error = null;
      stockPrices.clear();
    });

    try {
      for (final ticker in _tickerNames.keys) {
        final url = Uri.parse(
          'https://iss.moex.com/iss/engines/stock/markets/shares/securities/$ticker.json',
        );
        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final marketData = data['marketdata']['data'];

          double? lastPrice;

          // Логика извлечения цены для каждого тикера
          if (ticker == "SBER") {
            lastPrice = marketData[2][18]?.toDouble() * 10;
          } else if (ticker == "GMKN") {
            lastPrice = marketData[0][9]?.toDouble() * 10;
          } else if (ticker == "PHOR") {
            lastPrice = marketData[1][12]?.toDouble();
          } else if (ticker == "SNGSP") {
            lastPrice = marketData[0][18]?.toDouble() * 10;
          } else if (ticker == "NVTK") {
            lastPrice = marketData[1][12]?.toDouble();
          } else if (ticker == "ALRS") {
            lastPrice = marketData[2][12]?.toDouble() * 10;
          }

          setState(() {
            stockPrices[ticker] = lastPrice;
            if (lastPrice != null && stocksAllocation.isNotEmpty) {
              final allocation =
                  stocksAllocation[_getAllocationKey(ticker)] ?? 0;
              stockQuantities[ticker] = (allocation / lastPrice).round();
            }
          });
        } else {
          setState(() {
            _error = 'Ошибка сервера: ${response.statusCode}';
          });
          break;
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка сети: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getAllocationKey(String ticker) {
    final name = _tickerNames[ticker];
    final percentage = (stocksDistribution[ticker]! * 100).toInt();
    return '$name ($percentage%)';
  }

  void _calculateAllocation() {
    FocusScope.of(context).unfocus();
    final totalAmount = double.tryParse(_totalAmountController.text) ?? 0;
    final stocksTotal = totalAmount * 0.60;

    setState(() {
      // Основное распределение
      allocationResults = {
        'Акции (60%)': stocksTotal,
        'Облигации (30%)': totalAmount * 0.30,
        'Золото (10%)': totalAmount * 0.10,
      };

      // Распределение внутри акционной части
      stocksAllocation = {};
      stockQuantities = {};

      stocksDistribution.forEach((ticker, percentage) {
        final name = _tickerNames[ticker];
        final key = '$name (${(percentage * 100).toInt()}%)';
        final allocation = stocksTotal * percentage;
        stocksAllocation[key] = allocation;

        // Рассчитываем количество акций
        if (stockPrices[ticker] != null && stockPrices[ticker]! > 0) {
          stockQuantities[ticker] = (allocation / stockPrices[ticker]!).round();
        }
      });
    });
  }

  @override
  void dispose() {
    _totalAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _totalAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Общая сумма инвестиций',
                  border: OutlineInputBorder(),
                  suffixText: 'руб.',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _calculateAllocation,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text(
                  'Рассчитать распределение',
                  style: TextStyle(fontSize: 16),
                ),
              ),

              if (_isLoading) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 30),
              const Text(
                'Основное распределение:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Акции (60%)'),
                          Text(
                            '${allocationResults['Акции (60%)']!.toStringAsFixed(2)} руб.',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Облигации (30%)'),
                          Text(
                            '${allocationResults['Облигации (30%)']!.toStringAsFixed(2)} руб.',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Золото (10%)'),
                          Text(
                            '${allocationResults['Золото (10%)']!.toStringAsFixed(2)} руб.',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Распределение по акциям:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stocksAllocation.length,
                itemBuilder: (context, index) {
                  final key = stocksAllocation.keys.elementAt(index);
                  final value = stocksAllocation[key]!;
                  final ticker = _getTickerFromKey(key);

                  return Dismissible(
                    key: Key(key),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (direction) {
                      final deletedKey = key;
                      final deletedValue = value;

                      setState(() {
                        stocksAllocation.remove(key);
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Акция $deletedKey удалена'),
                          action: SnackBarAction(
                            label: 'ОТМЕНА',
                            textColor: Colors.white,
                            onPressed: () {
                              setState(() {
                                stocksAllocation[deletedKey] = deletedValue;
                              });
                            },
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${value.toStringAsFixed(2)} руб.',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (ticker != null && stockPrices[ticker] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Цена 1 лота: ${stockPrices[ticker]!.toStringAsFixed(2)} руб.',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    if (stockQuantities[ticker] != null)
                                      Text(
                                        'Кол-во: ${stockQuantities[ticker]} шт.',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (stocksAllocation.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: ElevatedButton(
                    onPressed: _fetchStockPrices,
                    child: const Text('Обновить цены акций'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String? _getTickerFromKey(String key) {
    for (final entry in _tickerNames.entries) {
      if (key.contains(entry.value)) {
        return entry.key;
      }
    }
    return null;
  }
}
