import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hansotbab/widgets/bottomappbar.dart';

class DonatedFood {
  final int? fridgeId;
  final String productName;
  final String productImageUrl;

  // final int productId;
  // final String wishlistContent;
  // final int wishlistLikes;
  // final bool isLikeWishlist;
  // final String boardRegDate;
  final String productModDate;

  DonatedFood({
    required this.fridgeId,
    required this.productName,
    required this.productImageUrl,
    required this.productModDate,
    // required this.wishlistContent,
    // required this.wishlistLikes,
    // required this.isLikeWishlist,
    // required this.boardRegDate,
    // required this.boardModDate,
  });

  factory DonatedFood.fromJson(Map<String, dynamic> json) {
    return DonatedFood(
      productName: json['productName'],
      fridgeId: json['fridgeId'],
      productImageUrl: json['productImageUrl'],
      productModDate: json['productModDate'],
      // wishlistContent: json['wishlistContent'],
    );
  }
}

class MyDonated extends StatefulWidget {
  String? uuid;
  String? accessToken;

  MyDonated({super.key, this.uuid});

  @override
  State<MyDonated> createState() => _MyDonatedState();
}

// 토큰 아이디 불러오기
class _MyDonatedState extends State<MyDonated> {
  List<DonatedFood> donatedList = [];
  late String? uuid;
  late String? accessToken;

  void initializePrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      uuid = prefs.getString('uuid');
      accessToken = prefs.getString('accessToken');
    });
    if (accessToken != null) {
      fetchDonated().then((donated) {
        setState(() {
          donatedList = donated;
        });
      }).catchError((error) {
        print("Error fetching donated food: $error");
      });
    }
  }

  // Future<String?> getUuidFromPrefs() async {
  //   final SharedPreferences prefs = await SharedPreferences.getInstance();
  //   // return prefs.getString('uuid');
  //   uuid = prefs.getString('uuid');
  //   accessToken = prefs.getString('accessToken');
  //   return null;
  // }

  Future<List<DonatedFood>> fetchDonated() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? accessToken = prefs.getString('accessToken');
    if (accessToken == null) throw Exception("Access token not available.");

    final response = await http.get(
      Uri.parse('https://j10b209.p.ssafy.io/api/v1/fridge/donate'),
      headers: {
        "Authorization": "Bearer $accessToken",
        "Content-Type": "application/json",
        // 'uuid': '$uuid'
      },
    );

    if (response.statusCode == 200) {
      var decodedResponse = utf8.decode(response.bodyBytes);
      List<dynamic> data = json.decode(decodedResponse);
      return data.map((json) => DonatedFood.fromJson(json)).toList();
    } else {
      throw Exception(
          "Failed to load donated food, status code: ${response.statusCode}");
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            height: MediaQuery.of(context).size.width * 0.3,
            color: const Color.fromARGB(255, 247, 244, 114),
            padding: const EdgeInsets.fromLTRB(0, 40, 0, 0),
            child: Center(
              child: Image.asset(
                'assets/images/notxt.png',
                width: MediaQuery.of(context).size.width * 0.18,
                height: MediaQuery.of(context).size.height * 0.16,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                child: Text(
                  '내가 기부한 음식들',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Happiness-Sans',
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: FutureBuilder<List<DonatedFood>>(
              future: fetchDonated(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: snapshot.data!.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                    ),
                    itemBuilder: (context, index) {
                      DonatedFood taken = snapshot.data![index];
                      return Card(
                        color: const Color.fromARGB(255, 247, 234, 192),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Expanded(
                            //   flex: 5, // 사진 영역 비율
                            //   child: Center(
                            //     // Center 추가하여 이미지 중앙 정렬
                            //     child: SizedBox(
                            //       height:
                            //           100, // SizedBox의 높이를 지정하면 Expanded의 flex와 충돌할 수 있으니 주의
                            //       child: Image.network(
                            //         taken.productImageUrl,
                            //       ),
                            //     ),
                            //   ),
                            // ),
                            Expanded(
                              flex: 3,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(15),
                                  topRight: Radius.circular(15),
                                ),
                                child: Image.network(
                                  taken.productImageUrl,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2, // 텍스트 영역 비율
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(5.0),
                                    child: Text(
                                      taken.productName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                      maxLines: 1, // 텍스트를 한 줄로 제한
                                      overflow: TextOverflow
                                          .ellipsis, // 긴 텍스트의 끝을 '...'로 표시
                                    ),
                                  ),
                                  // Text를 활성화하려면 아래 주석을 해제하세요.
                                  // Text(
                                  //   '기부한 냉장고: ${taken.fridgeId}',
                                  //   style: const TextStyle(fontWeight: FontWeight.bold),
                                  // ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                } else {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.no_food_rounded,
                            size: 80, color: Colors.grey),
                        SizedBox(height: 20),
                        Text('기부한 음식이 없습니다.',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.grey,
                              fontFamily: 'Happiness-Sans',
                            )),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomAppbar(currentIndex: -1),
    );
  }
}
