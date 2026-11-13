import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const LiveApiApp());
}

class LiveApiApp extends StatelessWidget {
  const LiveApiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cloud Product Explorer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF02569B)),
      ),
      home: const ProductExplorerScreen(),
    );
  }
}

class Product {
  final int id;
  final String title;
  final double price;
  final String description;
  final String category;
  final String imageUrl;
  final double rating;
  final int reviewCount;

  const Product({
    required this.id,
    required this.title,
    required this.price,
    required this.description,
    required this.category,
    required this.imageUrl,
    required this.rating,
    required this.reviewCount,
  });

  List<String> get galleryImages => [imageUrl, imageUrl, imageUrl];

  String get deepLink => 'narxoz://store/product/$id';

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawRating = json['rating'];

    final ratingData = rawRating is Map
        ? Map<String, dynamic>.from(rawRating)
        : <String, dynamic>{};

    return Product(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'No title',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String? ?? 'No description',
      category: json['category'] as String? ?? 'General',
      imageUrl: json['image'] as String? ?? '',
      rating: (ratingData['rate'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (ratingData['count'] as num?)?.toInt() ?? 0,
    );
  }
}

final Set<int> addedProductIds = <int>{};

class ProductExplorerScreen extends StatefulWidget {
  const ProductExplorerScreen({super.key});

  @override
  State<ProductExplorerScreen> createState() => _ProductExplorerScreenState();
}

class _ProductExplorerScreenState extends State<ProductExplorerScreen> {
  List<Product> _products = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts({bool showLoading = true}) async {
    if (!mounted) return;

    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final url = Uri.parse('https://fakestoreapi.com/products');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is! List) {
          throw const FormatException('Invalid product list');
        }

        final List<Product> loaded = decoded.map((item) {
          return Product.fromJson(Map<String, dynamic>.from(item as Map));
        }).toList();

        if (!mounted) return;

        setState(() {
          _products = loaded;
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        String message;

        if (response.statusCode == 404) {
          message = '404: Products not found';
        } else if (response.statusCode >= 500) {
          message = '500: Server error. Try again later.';
        } else {
          message = 'HTTP Error: ${response.statusCode}';
        }

        if (!mounted) return;

        setState(() {
          _errorMessage = message;
          _isLoading = false;
        });
      }
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Connection timeout. Please try again.';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'Failed to connect. Check your internet connection.\n$e';
        _isLoading = false;
      });
    }
  }

  void _openDeepLink(String rawUri) {
    final uri = Uri.tryParse(rawUri);

    if (uri == null || uri.pathSegments.isEmpty) {
      return;
    }

    final idString = uri.pathSegments.last;
    final productId = int.tryParse(idString);

    if (productId != null) {
      final index = _products.indexWhere((product) => product.id == productId);

      if (index != -1) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: _products[index]),
          ),
        );
        return;
      }
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Product not found!')));
  }

  Future<void> _showDeepLinkSimulatorDialog() async {
    final controller = TextEditingController(text: 'narxoz://store/product/3');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Simulate Deep Link'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Deep Link URL',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final link = controller.text.trim();
              Navigator.pop(ctx);
              _openDeepLink(link);
            },
            child: const Text('Open Link'),
          ),
        ],
      ),
    );

    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live REST API Store'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: 'Simulate Deep Link',
            onPressed: _showDeepLinkSimulatorDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload Products',
            onPressed: _fetchProducts,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading products from API...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 70, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Network Connection Error',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchProducts,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Connection'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchProducts(showLoading: false),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: _products.length,
        separatorBuilder: (context, index) {
          return const SizedBox(height: 10);
        },
        itemBuilder: (context, index) {
          final product = _products[index];

          return Card(
            elevation: 2,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(product: product),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Hero(
                      tag: 'product_image_${product.id}',
                      child: SizedBox(
                        width: 90,
                        height: 90,
                        child: Image.network(
                          product.imageUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) {
                              return child;
                            }

                            return const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.category.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            product.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '\$${product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 17,
                                  ),
                                  const SizedBox(width: 3),
                                  Text('${product.rating}'),
                                ],
                              ),
                            ],
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
    );
  }
}

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final PageController _pageController = PageController();

  int _currentImageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openShareModal(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.share, size: 40, color: Colors.blueAccent),
                const SizedBox(height: 12),
                const Text(
                  'Share Product via Deep Link',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          product.deepLink,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        tooltip: 'Copy Link',
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: product.deepLink),
                          );

                          if (!sheetContext.mounted) return;

                          Navigator.pop(sheetContext);

                          if (!mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Deep Link copied!')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Copy the link and test it using the '
                  'Deep Link simulator in the catalog.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final images = product.galleryImages;

    final isAdded = addedProductIds.contains(product.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Deep Link',
            onPressed: () => _openShareModal(product),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  SizedBox(
                    height: 280,
                    child: Stack(
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          itemCount: images.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentImageIndex = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            final scale = index == 0
                                ? 1.0
                                : index == 1
                                ? 1.2
                                : 1.4;

                            final imageWidget = ClipRect(
                              child: Container(
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(30),
                                  child: Transform.scale(
                                    scale: scale,
                                    child: Image.network(
                                      images[index],
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stack) {
                                        return const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            size: 60,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            );

                            if (index == 0) {
                              return Hero(
                                tag: 'product_image_${product.id}',
                                child: imageWidget,
                              );
                            }

                            return imageWidget;
                          },
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_currentImageIndex + 1} / ${images.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      images.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 12,
                        ),
                        height: 8,
                        width: _currentImageIndex == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentImageIndex == index
                              ? Colors.blueAccent
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Chip(label: Text(product.category.toUpperCase())),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            '${product.rating} '
                            '(${product.reviewCount} reviews)',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    product.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '\$${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text(
                    'Product Description',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isAdded ? Colors.green : Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                setState(() {
                  if (isAdded) {
                    addedProductIds.remove(product.id);
                  } else {
                    addedProductIds.add(product.id);
                  }
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isAdded ? 'Removed from cart!' : 'Added to cart!',
                    ),
                  ),
                );
              },
              icon: Icon(
                isAdded ? Icons.check_circle : Icons.add_shopping_cart,
              ),
              label: Text(
                isAdded ? 'Remove from Cart' : 'Add to Cart',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
