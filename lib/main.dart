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
  double _adjustedTotalAmount = 0;
  bool _autoAdjusted = false;

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

  double _findOptimalAmount(double totalAmount) {
    double step = 100; // шаг подбора
    double maxDelta = totalAmount * 0.5; // диапазон +/-50%
    double bestAmount = totalAmount;
    double minDeviation = double.infinity;

    for (double delta = -maxDelta; delta <= maxDelta; delta += step) {
      double testAmount = totalAmount + delta;
      double stocksPart = testAmount * 0.60;

      bool fits = true;
      double totalDeviation = 0;

      for (final ticker in stocksDistribution.keys) {
        final price = stockPrices[ticker];
        if (price == null || price <= 0) {
          fits = false;
          break;
        }

        final lotSize = _stockInfo[ticker]!['lotSize'];
        final minLotCost = price * lotSize;
        final idealAmount = stocksPart * stocksDistribution[ticker]!;

        int lots = (idealAmount / minLotCost).round();
        double actualAmount = lots * minLotCost;
        double deviation = ((idealAmount - actualAmount) / idealAmount).abs();

        totalDeviation += deviation;

        if (lots < 1 || deviation > 0.01) {
          fits = false;
          break;
        }
      }

      if (fits && totalDeviation < minDeviation) {
        minDeviation = totalDeviation;
        bestAmount = testAmount;
      }
    }

    return bestAmount;
  }

  void _calculateOptimalAllocation() {
    FocusScope.of(context).unfocus();
    double totalAmount = double.tryParse(_totalAmountController.text) ?? 0;

    double optimizedAmount = _findOptimalAmount(totalAmount);
    if ((optimizedAmount - totalAmount).abs() >= 1.0) {
      _adjustedTotalAmount = optimizedAmount;
      _autoAdjusted = true;
      totalAmount = optimizedAmount;
    } else {
      _adjustedTotalAmount = totalAmount;
      _autoAdjusted = false;
    }

    double stocksTotal = totalAmount * 0.60;

    setState(() {
      allocationResults = {
        'Акции (60%)': stocksTotal,
        'Облигации (30%)': totalAmount * 0.30,
        'Золото (10%)': totalAmount * 0.10,
      };

      stockLots.clear();
      actualAllocation.clear();
    });

    for (final ticker in stocksDistribution.keys) {
      final price = stockPrices[ticker];
      if (price == null || price <= 0) continue;

      final lotSize = _stockInfo[ticker]!['lotSize'];
      final minLotCost = price * lotSize;
      final idealAmount = stocksTotal * stocksDistribution[ticker]!;

      int lots = (idealAmount / minLotCost).round();
      double actualAmount = lots * minLotCost;

      stockLots[ticker] = lots;
      actualAllocation[ticker] = actualAmount;
    }

    setState(() {});
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
                child: const Text('Рассчитать'),
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
              if (_autoAdjusted)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'Сумма скорректирована до ${_adjustedTotalAmount.toStringAsFixed(2)} руб.',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 20),
              const Text(
                'Основное распределение:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ...allocationResults.entries.map(
                (entry) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  child: ListTile(
                    title: Text(entry.key),
                    trailing: Text(
                      '${entry.value.toStringAsFixed(2)} руб.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Распределение по акциям:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ...stockLots.entries.map((entry) {
                final ticker = entry.key;
                final name = _stockInfo[ticker]!['name'];
                final lots = entry.value;
                final lotSize = _stockInfo[ticker]!['lotSize'];
                final price = stockPrices[ticker] ?? 0;
                final cost = lots * lotSize * price;

                final double stocksTotal = allocationResults['Акции (60%)']!;
                final double idealPercentage =
                    stocksDistribution[ticker]! * 100;
                final double actualPercentage = (cost / stocksTotal) * 100;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  child: ListTile(
                    title: Text(
                      '$name ($lots лотов)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Цена: ${price.toStringAsFixed(2)} руб. (лот: $lotSize шт.)',
                        ),
                        Text(
                          'Задано: ${idealPercentage.toStringAsFixed(1)}% • Факт: ${actualPercentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color:
                                (actualPercentage - idealPercentage).abs() <= 1
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    trailing: Text(
                      '${cost.toStringAsFixed(2)} руб.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
