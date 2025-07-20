import 'package:flutter/material.dart';

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

  // Основное распределение
  Map<String, double> allocationResults = {
    'Акции (60%)': 0,
    'Облигации (30%)': 0,
    'Золото (10%)': 0,
  };

  // Распределение внутри акционной части
  final Map<String, double> stocksDistribution = {
    'АЛРОСА': 0.15,
    'Сургутнефтегаз': 0.15,
    'Новатэк': 0.15,
    'Норникель': 0.20,
    'Сбербанк': 0.15,
    'Фосагро': 0.20,
  };

  // Результаты распределения по акциям
  Map<String, double> stocksAllocation = {};

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
      stocksAllocation = {
        'Фосагро (20%)': stocksTotal * 0.20,
        'Сбербанк (15%)': stocksTotal * 0.15,
        'Норникель (20%)': stocksTotal * 0.20,
        'Новатэк (15%)': stocksTotal * 0.15,
        'Сургутнефтегаз (15%)': stocksTotal * 0.15,
        'АЛРОСА (15%)': stocksTotal * 0.15,
      };
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
                      // Сохраняем удаленные данные для возможной отмены
                      final deletedKey = key;
                      final deletedValue = value;

                      setState(() {
                        stocksAllocation.remove(key);
                      });

                      // Показываем уведомление с возможностью отмены
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(key),
                            Text(
                              '${value.toStringAsFixed(2)} руб.',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
