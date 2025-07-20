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
  double _additionalAmountNeeded = 0;

  // Цены акций и размер лота
  final Map<String, Map<String, dynamic>> _stockInfo = {
    'SBER': {'name': 'Сбербанк', 'lotSize': 10},
    'GMKN': {'name': 'Норникель', 'lotSize': 1},
    'PHOR': {'name': 'Фосагро', 'lotSize': 1},
    'SNGSP': {'name': 'Сургутнефтегаз-п', 'lotSize': 10},
    'NVTK': {'name': 'Новатэк', 'lotSize': 1},
    'ALRS': {'name': 'АЛРОСА', 'lotSize': 10},
  };

  Map<String, double?> stockPrices = {};
  Map<String, int> stockLots = {};
  Map<String, double> actualAllocation = {};
  Map<String, double> recommendedAllocation = {};

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
      for (final ticker in _stockInfo.keys) {
        final url = Uri.parse(
          'https://iss.moex.com/iss/engines/stock/markets/shares/securities/$ticker.json',
        );
        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final marketData = data['marketdata']['data'];

          double? lastPrice;

          if (ticker == "SBER") {
            lastPrice = marketData[2][18]?.toDouble();
          } else if (ticker == "GMKN") {
            lastPrice = marketData[0][9]?.toDouble();
          } else if (ticker == "PHOR") {
            lastPrice = marketData[1][12]?.toDouble();
          } else if (ticker == "SNGSP") {
            lastPrice = marketData[0][18]?.toDouble();
          } else if (ticker == "NVTK") {
            lastPrice = marketData[1][12]?.toDouble();
          } else if (ticker == "ALRS") {
            lastPrice = marketData[2][12]?.toDouble();
          }

          setState(() {
            stockPrices[ticker] = lastPrice;
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

  void _calculateOptimalAllocation() {
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

      // Сбрасываем предыдущие расчеты
      stockLots = {};
      actualAllocation = {};
      recommendedAllocation = {};
      _additionalAmountNeeded = 0;

      // Рассчитываем минимальное количество лотов для каждой акции
      double remainingAmount = stocksTotal;
      Map<String, double> tempRecommended = {};

      // Первый проход: распределяем по минимальным лотам
      for (final ticker in stocksDistribution.keys) {
        if (stockPrices[ticker] == null || stockPrices[ticker]! <= 0) continue;

        final lotSize = _stockInfo[ticker]!['lotSize'];
        final minLotCost = stockPrices[ticker]! * lotSize;
        final idealAmount = stocksTotal * stocksDistribution[ticker]!;

        // Определяем минимальное количество лотов
        int lots = (idealAmount / minLotCost).floor();
        if (lots < 1 && minLotCost <= remainingAmount) {
          lots = 1; // Покупаем хотя бы 1 лот, если хватает денег
        }

        if (lots > 0) {
          stockLots[ticker] = lots;
          final actualCost = lots * minLotCost;
          actualAllocation[ticker] = actualCost;
          remainingAmount -= actualCost;
        }
      }

      // Второй проход: распределяем оставшиеся средства
      if (remainingAmount > 0) {
        // Сортируем акции по приоритету (где разница между идеальным и текущим распределением наибольшая)
        final sortedTickers = stocksDistribution.keys.toList()
          ..sort((a, b) {
            final idealA = stocksTotal * stocksDistribution[a]!;
            final idealB = stocksTotal * stocksDistribution[b]!;
            final currentA = actualAllocation[a] ?? 0;
            final currentB = actualAllocation[b] ?? 0;
            final ratioA = (idealA - currentA) / idealA;
            final ratioB = (idealB - currentB) / idealB;
            return ratioB.compareTo(ratioA);
          });

        for (final ticker in sortedTickers) {
          if (stockPrices[ticker] == null || stockPrices[ticker]! <= 0)
            continue;

          final lotSize = _stockInfo[ticker]!['lotSize'];
          final minLotCost = stockPrices[ticker]! * lotSize;

          if (remainingAmount >= minLotCost) {
            final additionalLots = (remainingAmount / minLotCost).floor();
            if (additionalLots > 0) {
              stockLots[ticker] = (stockLots[ticker] ?? 0) + additionalLots;
              final additionalCost = additionalLots * minLotCost;
              actualAllocation[ticker] =
                  (actualAllocation[ticker] ?? 0) + additionalCost;
              remainingAmount -= additionalCost;
            }
          }
        }
      }

      // Рассчитываем рекомендуемое распределение и недостающую сумму
      double totalAllocated = stocksTotal - remainingAmount;
      _additionalAmountNeeded = 0;

      for (final ticker in stocksDistribution.keys) {
        if (stockPrices[ticker] == null || stockPrices[ticker]! <= 0) continue;

        final lotSize = _stockInfo[ticker]!['lotSize'];
        final minLotCost = stockPrices[ticker]! * lotSize;
        final idealAmount = stocksTotal * stocksDistribution[ticker]!;
        final currentAmount = actualAllocation[ticker] ?? 0;

        if (currentAmount < idealAmount) {
          final neededLots = ((idealAmount - currentAmount) / minLotCost)
              .ceil();
          if (neededLots > 0) {
            recommendedAllocation[ticker] = neededLots * minLotCost;
            _additionalAmountNeeded +=
                neededLots * minLotCost - (idealAmount - currentAmount);
          }
        }
      }
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
                onPressed: _calculateOptimalAllocation,
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
                'Практическое распределение по акциям:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (stockLots.isNotEmpty) ...[
                ...stockLots.keys.map((ticker) {
                  final name = _stockInfo[ticker]!['name'];
                  final lotSize = _stockInfo[ticker]!['lotSize'];
                  final price = stockPrices[ticker] ?? 0;
                  final lots = stockLots[ticker]!;
                  final cost = lots * price * lotSize;
                  final idealPercentage = stocksDistribution[ticker]! * 100;
                  final actualPercentage =
                      (cost / allocationResults['Акции (60%)']!) * 100;

                  return Card(
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
                                '$name (${idealPercentage.toStringAsFixed(0)}%)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${cost.toStringAsFixed(2)} руб.',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Цена: ${price.toStringAsFixed(2)} руб. (лот: $lotSize шт.)',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Лотов: $lots (${lots * lotSize} шт.)',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Фактически: ${actualPercentage.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: actualPercentage >= idealPercentage
                                        ? Colors.green
                                        : Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                if (_additionalAmountNeeded > 0)
                  Card(
                    color: Colors.blue[50],
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Рекомендация:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Для более равномерного распределения добавьте ${_additionalAmountNeeded.toStringAsFixed(2)} руб. к общему объему инвестиций.',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...recommendedAllocation.keys.map((ticker) {
                            final name = _stockInfo[ticker]!['name'];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                '$name: +${recommendedAllocation[ticker]!.toStringAsFixed(2)} руб.',
                                style: TextStyle(color: Colors.blue[800]),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
              ],
              if (stockLots.isNotEmpty)
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
}
