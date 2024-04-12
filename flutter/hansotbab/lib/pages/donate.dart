import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:hansotbab/providers/userpreferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Donate extends StatefulWidget {
  final String fridgeName;
  final VoidCallback onSuccessfulSubmit;
  final int _selectedFridge;
  const Donate(this._selectedFridge,
      {super.key, required this.fridgeName, required this.onSuccessfulSubmit});

  @override
  _DonateState createState() => _DonateState();
}

class _DonateState extends State<Donate> {
  final TextEditingController _foodNameController = TextEditingController();
  final TextEditingController _foodQuantityController = TextEditingController();
  final TextEditingController _additionalMessageController =
      TextEditingController();
  final int _charCount = 0;
  final int _selectedQuantity = 1;
  String _selectedCategory = '대분류 선택';
  // String _selectedPreservation = '실온 보관'; // 기본 보관 방법 선택
  final _selectedPreservation = [];
  List<Map<String, dynamic>> extractedData = [];
  final List<String> categories = [
    '대분류 선택',
    '채소',
    '과일',
    '음료',
    '소스/조미료',
    '유제품',
    '축산/계란',
    '간식류',
    '가공식품',
    '쌀/잡곡류',
    '반찬류',
    '기타'
  ];
  final List<int> quantities = [for (var i = 1; i <= 10; i++) i];
  File? _image;

  final ImagePicker picker = ImagePicker(); //ImagePicker 초기화

  //이미지를 가져오는 함수
  Future getImage(ImageSource imageSource) async {
    //pickedFile에 ImagePicker로 가져온 이미지가 담긴다.
    final XFile? pickedFile = await picker.pickImage(source: imageSource);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path); //가져온 이미지를 _image에 저장
        _uploadImage(_image!);
      });
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    print("이미지 업로드 함수 실행");
    var uri = Uri.parse('http://172.20.10.2:8000/upload-image');
    var request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));
    var response = await request.send();

    print(response.statusCode);
    if (response.statusCode == 200) {
      String responseBody = await response.stream.bytesToString();
      print(responseBody);

      _processResponse(responseBody);
    } else {
      print("업로드 에러");
    }
  }

  void _processResponse(String searchedFood) {
    // 이 부분은 jsonResponse 구조에 맞게 조정하세요
    setState(() {
      String jsonString = searchedFood;
      Map<String, dynamic> jsonData = jsonDecode(jsonString);
      // print(jsonData['name']);
      _foodNameController.text = jsonData['productName'];
      _selectedCategory = jsonData['productCategory'];
    });
  }

  Future<void> _submitFood() async {
    var tokenData = await UserPreferences.getToken();
    String? token = tokenData?['accessToken'];
    // 필수 필드가 입력되었는지 확인
    if (_image == null ||
        _foodNameController.text.isEmpty ||
        _selectedCategory == '대분류 선택' ||
        _foodQuantityController.text.isEmpty ||
        _selectedPreservation.isEmpty) {
      // 사용자에게 경고 표시
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            '경고',
            style: TextStyle(fontFamily: 'Happiness-Sans'),
          ),
          content: const Text(
            '모든 값을 입력해주세요.',
            style: TextStyle(fontFamily: 'Happiness-Sans'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                '확인',
                style: TextStyle(fontFamily: 'Happiness-Sans'),
              ),
            ),
          ],
        ),
      );
      return;
    }

    var uri = Uri.parse(
        "https://j10b209.p.ssafy.io/api/v1/fridge/${widget._selectedFridge}/register");
    var request = http.MultipartRequest('POST', uri);
    String str = _selectedPreservation
        .toString()
        .replaceAll('[', '')
        .replaceAll(']', '');
    request.fields["productName"] = _foodNameController.text;
    request.fields["productCategory"] = _selectedCategory;
    request.fields["productAmount"] = _foodQuantityController.text;
    request.fields["productConditions"] = str;
    request.fields["productMemo"] = _additionalMessageController.text;
    var file = await http.MultipartFile.fromPath(
      "file",
      _image!.path,
    );
    request.files.add(file);
    request.headers['Authorization'] = 'Bearer $token';
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      // 성공적으로 제출되면 냉장고 페이지로 리다이렉트
      var tokenData = await UserPreferences.getToken();
      String? accessToken = tokenData?['accessToken'];

      var fcmurl = Uri.parse(
          "https://j10b209.p.ssafy.io/api/v1/alarm/fridge/${widget._selectedFridge}");
      try {
        var response = await http.post(
          fcmurl,
          headers: {
            "Content-Type": "application/json",
            'Authorization': 'Bearer $accessToken'
          },
        );
        if (response.statusCode == 200) {
          widget.onSuccessfulSubmit();
          Navigator.pop(context);
        } else {
          print("음식 기부 상황시 오류 : ${response.statusCode}");
        }
      } catch (e) {
        print("fcm 오류 : $e");
      }
    } else {
      print("음식 등록 에러 ${response.statusCode}");
      print(response.statusCode);
    }
  }

  List<Map<String, dynamic>> _searchedFoodList = [];

  void _searchFood(String foodName) async {
    var tokenData = await UserPreferences.getToken();
    String? token = tokenData?['accessToken'];

    var uri = Uri.parse(
        'https://j10b209.p.ssafy.io/api/v1/food/search?keyword=$foodName');
    var response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      setState(() {
        List<dynamic> jsonResponse =
            json.decode(utf8.decode(response.bodyBytes));
        List<String> searchedFood =
            jsonResponse.map((item) => item.toString()).toList();
        extractedData = [];

        for (var item in searchedFood) {
          String jsonString = item;
          int nameIndex = jsonString.indexOf('name: ');
          int catIndex = jsonString.indexOf(', cat: ');
          int cat1Index = jsonString.indexOf(', cat1:');
          String name = jsonString.substring(nameIndex + 6, catIndex);
          String cat = jsonString.substring(catIndex + 7, cat1Index);

          extractedData.add({"name": name, "cat": cat});
        }
        _searchedFoodList = extractedData;
      });
    } else {
      setState(() {
        _searchedFoodList.clear();
      });
      print('검색 실패');
    }
  }

  bool _isSearchListVisible = false;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.fridgeName),
        ),
        body: GestureDetector(
          onTap: () {
            setState(() {
              _isSearchListVisible = false;
            });
          },
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      '음식 등록',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Happiness-Sans',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Row(children: [
                    SizedBox(width: 20),
                    Text('음식 사진',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Happiness-Sans',
                        )),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    const SizedBox(width: 20),
                    _image != null
                        ? Container(
                            height: 150,
                            padding: const EdgeInsets.all(
                                4), // 이미지와 테두리 사이에 4px의 간격을 줍니다.
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                  20), // 이미지의 테두리를 둥글게 만듭니다.
                              border: Border.all(
                                  color: Colors.yellow,
                                  width: 2), // 테두리 색상을 노란색으로 설정합니다.
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                  20), // 4px 간격을 고려하여 조정합니다.
                              child: Image.file(
                                  File(_image!.path)), // 가져온 이미지를 화면에 띄워주는 코드
                            ),
                          )
                        : Container(
                            height: 150,
                            width: 150,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: Colors.yellow, width: 2),
                              color: Colors.white,
                            ),
                            child: const Icon(
                              Icons.camera_alt_outlined,
                              size: 70,
                              color: Colors.grey,
                            ),
                          ),
                  ]),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const SizedBox(width: 23),
                      ElevatedButton(
                        onPressed: () {
                          getImage(ImageSource.camera);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 15), // 버튼 내부 padding 설정
                        ),
                        child: const Text(
                          "카메라",
                          style: TextStyle(
                            fontFamily: 'Happiness-Sans',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          getImage(ImageSource.gallery);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 15), // 버튼 내부 padding 설정
                        ),
                        child: const Text(
                          "갤러리",
                          style: TextStyle(
                            fontFamily: 'Happiness-Sans',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Row(children: [
                    SizedBox(width: 20),
                    Text('음식 이름',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Happiness-Sans',
                        )),
                  ]),
                  const SizedBox(height: 5),
                  Container(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.85,
                      child: TextField(
                        controller: _foodNameController,
                        decoration: InputDecoration(
                          hintText: '음식 이름 입력',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 20.0),
                        ),
                        onTap: () {
                          setState(() {
                            _isSearchListVisible = true;
                          });
                        },
                        onChanged: (newValue) {
                          setState(() {
                            _searchFood(newValue);
                          });
                        },
                      ),
                    ),
                  ),
                  Stack(
                    children: [
                      Column(
                        children: [
                          const SizedBox(height: 30),
                          Row(children: [
                            const SizedBox(width: 20),
                            const Text('등록 수량',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Happiness-Sans',
                                )),
                            const SizedBox(width: 30),
                            Expanded(
                                child: TextField(
                                    controller: _foodQuantityController,
                                    keyboardType: TextInputType.number,
                                    onTap: () {
                                      setState(() {
                                        _isSearchListVisible = false;
                                      });
                                    },
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10.0),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 25.0),
                                    ))),
                            const SizedBox(width: 10),
                            const Text('개',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Happiness-Sans',
                                )),
                            const SizedBox(width: 100)
                          ]),
                          const SizedBox(height: 30),
                          Row(
                            children: [
                              const SizedBox(width: 20),
                              const Text('대  분  류',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Happiness-Sans',
                                  )),
                              const SizedBox(width: 30),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10.0),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey, // 아웃라인 색상
                                    width: 1.0, // 아웃라인 두께
                                  ),
                                  borderRadius: BorderRadius.circular(
                                      10.0), // 아웃라인의 모서리를 둥글게 만듦
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    menuMaxHeight: 200,
                                    value: _selectedCategory,
                                    borderRadius: BorderRadius.circular(10),
                                    onChanged: (newValue) {
                                      setState(() {
                                        _selectedCategory = newValue!;
                                      });
                                    },
                                    onTap: () {
                                      setState(() {
                                        _isSearchListVisible = false;
                                      });
                                    },
                                    items: categories
                                        .map<DropdownMenuItem<String>>(
                                            (String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          const Row(children: [
                            SizedBox(width: 20),
                            Text('보관 방법',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Happiness-Sans',
                                )),
                            SizedBox(width: 5),
                            Text('(중복 선택 가능)',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Happiness-Sans',
                                    color: Colors.grey)),
                          ]),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children:
                                ['실온보관', '냉장보관', '냉동보관'].map((String value) {
                              return ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    // _selectedPreservation = value;
                                    _selectedPreservation.contains(value)
                                        ? _selectedPreservation.remove(value)
                                        : _selectedPreservation.add(value);
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _selectedPreservation.contains(value)
                                          ? Colors.yellow
                                          : Colors.white,
                                  textStyle:
                                      const TextStyle(color: Colors.black),
                                  side: const BorderSide(
                                    color: Colors.yellow,
                                    width: 2.0,
                                  ),
                                ),
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 30),
                          const Row(children: [
                            SizedBox(width: 20),
                            Text('남기고 싶은 말',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Happiness-Sans',
                                )),
                          ]),
                          const SizedBox(height: 10),
                          Container(
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width * 0.85,
                                child: TextField(
                                  controller: _additionalMessageController,
                                  decoration: InputDecoration(
                                      hintText: '메세지 입력',
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10.0),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 15, horizontal: 20.0)),
                                  maxLines: 3, // 여러 줄 입력 가능하도록 설정
                                  maxLength: 100,
                                ),
                              )),
                          const SizedBox(height: 20),
                          Center(
                            child: ElevatedButton(
                              onPressed: _submitFood,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.yellow, // 배경색을 노란색으로 지정합니다.
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 30,
                                    vertical:
                                        10), // 가로로 늘리기 위해 minimumSize 속성을 사용합니다.
                              ),
                              child: const Text('음식 등록',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Happiness-Sans',
                                  )),
                            ),
                          ),
                        ],
                      ),
                      _isSearchListVisible && _searchedFoodList.isNotEmpty
                          ? Center(
                              child: Container(
                                  alignment: Alignment.center,
                                  width:
                                      MediaQuery.of(context).size.width * 0.82,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey
                                          .withOpacity(0.5), // 테두리 색상 설정
                                      width: 1.0, // 테두리 두께 설정
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft:
                                          Radius.circular(10.0), // 왼쪽 하단 둥근 경계선
                                      bottomRight: Radius.circular(
                                          10.0), // 오른쪽 하단 둥근 경계선
                                    ), // 테두리 모서리 둥글기 설정
                                  ),
                                  child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10.0),
                                      child: Container(
                                        color: Colors.white,
                                        alignment: Alignment.center,
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: _searchedFoodList.length,
                                          itemBuilder: (context, index) {
                                            return GestureDetector(
                                              onTap: () {
                                                // 선택된 검색 결과 항목을 처리할 수 있습니다.
                                                setState(() {
                                                  _foodNameController.text =
                                                      _searchedFoodList[index]
                                                          ['name'];
                                                  _selectedCategory =
                                                      _searchedFoodList[index]
                                                          ['cat'];
                                                  _isSearchListVisible = false;
                                                });
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 10,
                                                        horizontal: 20),
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    bottom: BorderSide(
                                                      color: Colors.grey
                                                          .withOpacity(0.5),
                                                      width: 0.5,
                                                    ),
                                                  ),
                                                ),
                                                child: Text(
                                                  _searchedFoodList[index]
                                                      ['name'],
                                                  style: const TextStyle(
                                                      fontSize: 16),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ))))
                          : const SizedBox(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}
